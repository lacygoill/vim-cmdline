vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

const PAT_RANGE: string = '\s*\%([%*]\|[^,]*,[^,]*\)'

# number of times we've transformed the command-line
var transformed: number = -1
var orig_cmdline: string

# Interface {{{1
def cmdline#transform#main(): string #{{{2
    transformed += 1
    au CmdlineLeave /,\?,: ++once transformed = -1 | orig_cmdline = ''

    var cmdtype: string = getcmdtype()
    var cmdline: string = getcmdline()
    # Don't write a guard to prevent multiple transformations on the Ex command-line!{{{
    #
    #     if transformed >= 1 && cmdtype == ':'
    #         return ''
    #     endif
    #
    # It would prevent you from re-applying a transformation, after clearing the
    # command-line (`C-u`) and writing a new command.
    #}}}
    if cmdtype =~ '[/?]'
        if transformed == 0
            orig_cmdline = cmdline
        endif
        cmdline#util#undo#emitAddToUndolistC()
        return "\<c-e>\<c-u>"
            .. (transformed % 2 ? ReplaceWithEquivClass() : SearchOutsideComments(cmdtype))
    elseif cmdtype =~ ':'
        cmdline#util#undo#emitAddToUndolistC()
        cmdline = getcmdline()
        var cmd: string = GuessWhatTheCmdlineIs(cmdline)
        return Transform(cmd, cmdline)
    else
        return ''
    endif
enddef
# }}}1
# Core {{{1
# Ex {{{2
def GuessWhatTheCmdlineIs(cmdline: string): string #{{{3
    if cmdline =~ '^' .. PAT_RANGE .. 's[/:]'
        # a substitution command
        return ':s'
    elseif cmdline =~ '\C^\s*echo'
        return ':echo'
    elseif cmdline =~ '\C^\s*eval'
        return ':eval'
    endif
    return ''
enddef

def Transform(cmd: string, cmdline: string): string #{{{3
    if cmd == ':s'
        return CaptureSubpatterns(cmdline)
    elseif cmd =~ '^:\%(echo\|eval\)$'
        return MapFilter(cmdline)
    endif
    return ''
enddef

def MapFilter(cmdline: string): string #{{{3
    # Purpose:{{{
    #
    #     :echo [1, 2, 3]
    #     :echo [1, 2, 3]->map({_, v -> })~
    #
    #     :echo [1, 2, 3]->map({_, v -> })
    #     :echo [1, 2, 3]->filter({_, v -> })~
    #
    #     :echo [1, 2, 3]->filter({_, v -> v != 2})
    #     :echo [1, 2, 3]->filter({_, v -> v != 2})->map({_, v -> })~
    #}}}
    var new_cmdline: string
    if cmdline =~ '\C^\s*\%(echo\|eval\)\s\+.*->\%(map\|filter\)({[i,_],\s*v\s*->\s*})$'
        new_cmdline = substitute(cmdline,
            '\C^\s*\%(echo\|eval\)\s\+.*->\zs\%(map\|filter\)\ze({[i,_],\s*v\s*->\s*})$',
            '\={"map": "filter", "filter": "map"}[submatch(0)]',
            '')
    else
        new_cmdline = substitute(cmdline, '$', '->map({_, v -> })', '')
    endif

    return "\<c-e>\<c-u>" .. new_cmdline .. "\<left>\<left>"
enddef

def CaptureSubpatterns(cmdline: string): string #{{{3
# Purpose:{{{
#
#     :%s/foo_bar_baz//g
#     :%s/\(foo\)_\(bar\)_\(baz\)//g~
#}}}

    # extract the range, separator and the pattern
    var range: string = matchstr(cmdline, PAT_RANGE)
    var separator: string = matchstr(cmdline, '^' .. PAT_RANGE .. 's\zs.')
    var pat: string = split(cmdline, separator)[1]

    # from the pattern, extract words between underscores or uppercase letters:{{{
    #
    #         'OneTwoThree'   → ['One', 'Two', 'Three']
    #         'one_two_three' → ['one', 'two', 'three']
    #}}}
    var subpatterns: list<string> = split(pat, pat =~ '_' ? '_' : '\ze\u')

    # return the keys to type{{{
    #
    #                              ┌ original pattern, with the addition of parentheses around the subpatterns:
    #                              │
    #                              │          (One)(Two)(Three)
    #                              │    or    (one)_(two)_(three)
    #                              │
    #                              ├────────────────────────────────────────────────────────────────────┐}}}
    var new_cmdline: string =
        range .. 's/'
        .. map(subpatterns, (_, v) => '\(' .. v .. '\)')
            ->join(pat =~ '_' ? '_' : '')
        .. '//g'

    return "\<c-e>\<c-u>" .. new_cmdline .. "\<left>\<left>"
enddef
#}}}2
# Search {{{2
def ReplaceWithEquivClass(): string #{{{3
    return orig_cmdline->substitute('\a', '[[=\0=]]', 'g')
enddef

def SearchOutsideComments(cmdtype: string): string #{{{3
    # we should probably save `cmdline` in  a script-local variable if we want
    # to cycle between several transformations
    if empty(&l:cms)
        return orig_cmdline
    endif
    var cml: string
    if &ft == 'vim'
        cml = '["#]'
    else
        cml = '\V' .. matchstr(&l:cms, '\S*\ze\s*%s')->escape('\' .. cmdtype) .. '\m'
    endif
    return '\%(^\%(\s*' .. cml .. '\)\@!.*\)\@<=\m\%(' .. orig_cmdline .. '\)'
    #                                             ├─┘
    #                                             └ Why?{{{
    # The original pattern may contain several branches.
    # In that  case, we want the  lookbehind to be  applied to all of  them, not
    # just the first one.
    #}}}
enddef

