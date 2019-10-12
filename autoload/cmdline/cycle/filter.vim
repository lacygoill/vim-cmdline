if exists('g:autoloaded_cmdline#cycle#filter')
    finish
endif
let g:autoloaded_cmdline#cycle#filter = 1

" Init {{{1

" `:Filter /pat/ cmd` should just run the built-in `:filter` if it can filter `:cmd`.
" We need to teach `:Filter` which commands should not be tampered with.
const s:FILTERABLE_COMMANDS =<< trim END
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

call cmdline#cycle#main#set('f', 'Verb Filter /§/ ')
" }}}1
" Interface {{{1
fu cmdline#cycle#filter#install() abort "{{{2
    com -bang -complete=custom,s:filter_completion -nargs=+ Filter  call s:filter(<q-args>, <bang>0)
endfu

fu s:filter_completion(_arglead, cmdline, pos) abort "{{{2
    let matches =<< trim END
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
endfu
" }}}1
" Core {{{1
fu s:filter(cmd, bang) abort "{{{2
    let pat = matchstr(a:cmd, '/\zs.\{-}\ze/')

    let cmd = matchstr(a:cmd, '/.\{-}/\s*\zs.*')
    let first_word = matchstr(cmd, '\a*\|#')
    if s:is_filterable(first_word)
        if pat is# ''
            exe 'filter'.(a:bang ? '!': '').' '.substitute(a:cmd, '/\zs.\{-}\ze/', @/, '')
        else
            exe 'filter'.(a:bang ? '!': '').' '.a:cmd
        endif
        return
    endif

    let output = cmd is# 'args'
        \ ?     argv()
        \ :     split(execute(cmd), '\n')
    " useful if we re-execute a second `:Filter` without leaving the command-line
    redraw
    echo join(filter(output, {_,v -> a:bang ? v !~# pat : v =~# pat}), "\n")
endfu
" }}}1
" Utilities {{{1
fu s:is_filterable(first_word) abort "{{{2
    for cmd in s:FILTERABLE_COMMANDS
        if a:first_word =~# '^\C'.cmd.'$'
            return 1
        endif
    endfor
    return 0
endfu

