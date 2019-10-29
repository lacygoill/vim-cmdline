let s:PAT_RANGE = '\s*\%([%*]\|[^,]*,[^,]*\)'

" Interface {{{1
fu cmdline#transform#main() abort "{{{2
    " number of times we've transformed the command-line
    let s:did_transform = get(s:, 'did_transform', -1) + 1
    au CmdlineLeave /,\?,: ++once unlet! s:did_transform s:orig_cmdline

    let cmdtype = getcmdtype()
    let cmdline = getcmdline()
    " Don't write a guard to prevent multiple transformations on the Ex command-line!{{{
    "
    "     if s:did_transform >= 1 && cmdtype is# ':'
    "         return ''
    "     endif
    "
    " It would prevent you from re-applying a transformation, after clearing the
    " command-line (`C-u`) and writing a new command.
    "}}}
    if cmdtype =~# '[/?]'
        if get(s:, 'did_transform', 0) == 0
            let s:orig_cmdline = cmdline
        endif
        call cmdline#util#undo#emit_add_to_undolist_c()
        return "\<c-e>\<c-u>"
        \ ..(s:did_transform % 2 ? s:replace_with_equiv_class() : s:search_outside_comments())
    elseif cmdtype =~# ':'
        call cmdline#util#undo#emit_add_to_undolist_c()
        let cmdline = getcmdline()
        let cmd = s:guess_what_the_cmdline_is(cmdline)
        return s:transform(cmd, cmdline)
    else
        return ''
    endif
endfu
" }}}1
" Core {{{1
" Ex {{{2
fu s:guess_what_the_cmdline_is(cmdline) abort "{{{3
    if a:cmdline =~# '^'..s:PAT_RANGE..'s[/:]'
        " a substitution command
        return ':s'
    elseif a:cmdline =~# '\C^\s*echo'
        return ':echo'
    endif
endfu

fu s:transform(cmd, cmdline) abort "{{{3
    if a:cmd is# ':s'
        return s:capture_subpatterns(a:cmdline)
    elseif a:cmd is# ':echo'
        return s:map_filter(a:cmdline)
    endif
    return ''
endfu

fu s:map_filter(cmdline) abort "{{{3
    " Purpose:{{{
    "
    "     :echo [1,2,3]
    "     :echo map([1,2,3], {_,v -> })~
    "
    "     :echo map([1,2,3], {_,v -> })
    "     :echo filter([1,2,3], {_,v -> })~
    "
    "     :echo filter([1,2,3], {_,v -> v != 2})
    "     :echo map(filter([1,2,3], {_,v -> v != 2}), {_,v -> })~
    "}}}

    if !has('nvim')
        if a:cmdline =~# '\C^\s*echo\s\+.*->\%(map\|filter\)({[i,_],v\s*->\s*})$'
            let new_cmdline = substitute(a:cmdline,
                \ '\C^\s*echo\s\+.*->\zs\%(map\|filter\)\ze({[i,_],v\s*->\s*})$',
                \ '\={"map": "filter", "filter": "map"}[submatch(0)]',
                \ '')
        else
            let new_cmdline = substitute(a:cmdline, '$', '->map({_,v -> })', '')
        endif
    else
        " if `map()`/`filter()` is used, with an empty lambda, toggle it
        if a:cmdline =~# '\C^\s*echo\s\+\%(map\|filter\)(.*,\s*{[_i],v\s*->\s*})'
            let new_cmdline = substitute(a:cmdline,
                \ '^\s*echo\s\+\zs\%(map\|filter\)\ze(',
                \ '\={"map": "filter", "filter": "map"}[submatch(0)]',
                \ '')
        else
            " otherwise, add a new `map()`/`filter()`
            let new_cmdline = substitute(a:cmdline, '^\s*echo\s\+\zs', 'map(', '')
            let new_cmdline = substitute(new_cmdline, '$', ', {_,v -> })', '')
        endif
    endif

    return "\<c-e>\<c-u>"..new_cmdline.."\<left>\<left>"
endfu

fu s:capture_subpatterns(cmdline) abort "{{{3
    " Purpose:{{{
    "
    "     :%s/foo_bar_baz//g
    "     :%s/\(foo\)_\(bar\)_\(baz\)//g~
    "}}}

    " extract the range, separator and the pattern
    let range = matchstr(a:cmdline, s:PAT_RANGE)
    let separator = matchstr(a:cmdline, '^'..s:PAT_RANGE..'s\zs.')
    let pat = split(a:cmdline, separator)[1]

    " from the pattern, extract words between underscores or uppercase letters:{{{
    "
    "         'OneTwoThree'   → ['One', 'Two', 'Three']
    "         'one_two_three' → ['one', 'two', 'three']
    "}}}
    let subpatterns = split(pat, pat =~# '_' ? '_' : '\ze\u')

    " return the keys to type{{{
    "
    "                              ┌ original pattern, with the addition of parentheses around the subpatterns:
    "                              │
    "                              │          (One)(Two)(Three)
    "                              │    or    (one)_(two)_(three)
    "                              │
    "                              ├────────────────────────────────────────────────────────────────────┐}}}
    let new_cmdline = range..'s/'..join(map(subpatterns, {_,v -> '\('..v..'\)'}), pat =~# '_' ? '_' : '')..'//g'

    return "\<c-e>\<c-u>"..new_cmdline.."\<left>\<left>"
endfu
"}}}2
" Search {{{2
fu s:replace_with_equiv_class() abort "{{{3
    return substitute(get(s:, 'orig_cmdline', ''), '\a', '[[=\0=]]', 'g')
endfu

fu s:search_outside_comments() abort "{{{3
    " we should probably save `cmdline` in  a script-local variable if we want
    " to cycle between several transformations
    if empty(&l:cms)
        return get(s:, 'orig_cmdline', '')
    endif
    let cml = '\V'..escape(matchstr(split(&l:cms, '%')[0], '\S*'), '\')..'\m'
    return '\%(^\%(\s*'..cml..'\)\@!.*\)\@<=\m\%('..get(s:, 'orig_cmdline', '')..'\)'
    "                                         ├─┘
    "                                         └ Why?{{{
    " The original pattern may contain several branches.
    " In that  case, we want the  lookbehind to be  applied to all of  them, not
    " just the first one.
    "}}}
endfu

