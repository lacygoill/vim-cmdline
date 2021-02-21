vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# Init {{{1

# `:Filter /pat/ cmd` should just run the built-in `:filter` if it can filter `:cmd`.
# We need to teach `:Filter` which commands should not be tampered with.
const FILTERABLE_COMMANDS: list<string> =<< trim END
    #
    l\%[ist]
    nu\%[mber]
    p\%[rint]
    buffers
    lli\%[st]
    files
    hi\%[ghlight]
    ju\%[mps]
    let
    ls
    nm\%[ap]
    vm\%[ap]
    xm\%[ap]
    smap
    om\%[ap]
    map!
    im\%[ap]
    lm\%[ap]
    cm\%[ap]
    tma\%[p]
    no\%[remap]
    nn\%[oremap]
    vn\%[oremap]
    xn\%[oremap]
    snor\%[emap]
    ono\%[remap]
    no\%[remap]!
    ino\%[remap]
    ln\%[oremap]
    cno\%[remap]
    tno\%[remap]
    norea\%[bbrev]
    ca\%[bbrev]
    cnorea\%[bbrev]
    ia\%[bbrev]
    inorea\%[bbrev]
    old\%[files]
    scr\%[iptnames]
    se\%[t]
    set[lg]
    sig\%[n]
END

cmdline#cycle#main#set('f', 'Verb Filter /\c§/ ')
# }}}1
# Interface {{{1
def cmdline#cycle#filter#install() #{{{2
    com -bang -nargs=+ -complete=custom,FilterCompletion Filter Filter(<q-args>, <bang>0)
enddef

def FilterCompletion(...l: any): string #{{{2
    var matches: list<string> =<< trim END
        %#
        ab
        chi
        com
        hi
        let
        ls
        map
        mess
        old
        scr
        set
    END
    return join(matches, "\n")
enddef
# }}}1
# Core {{{1
def Filter(arg_cmd: string, bang: bool) #{{{2
    var pat: string = matchstr(arg_cmd, '/\zs.\{-}\ze/')

    var cmd: string = matchstr(arg_cmd, '/.\{-}/\s*\zs.*')
    var first_word: string = matchstr(cmd, '\a*\|#')
    if IsFilterable(first_word)
        if pat == ''
            exe 'filter' .. (bang ? '!' : '') .. ' '
                .. substitute(arg_cmd, '/\zs.\{-}\ze/', @/, '')
        else
            exe 'filter' .. (bang ? '!' : '') .. ' ' .. arg_cmd
        endif
        return
    endif

    var output: list<string> = cmd == 'args'
        ?     argv()
        :     execute(cmd)->split('\n')
    echo output
        ->filter((_, v: string): bool => bang ? v !~ pat : v =~ pat)
        ->join("\n")
enddef
# }}}1
# Utilities {{{1
def IsFilterable(first_word: string): bool #{{{2
    for cmd in FILTERABLE_COMMANDS
        if first_word =~ '^\C' .. cmd .. '$'
            return true
        endif
    endfor
    return false
enddef

