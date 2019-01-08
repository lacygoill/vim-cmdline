if exists('g:autoloaded_cmdline#tab')
    finish
endif
let g:autoloaded_cmdline#tab = 1

augroup my_cmdline_tab
    au!
    au CmdlineLeave : unlet! s:cmdline_before_expansion
augroup END

" Interface {{{1
fu! cmdline#tab#custom(is_fwd) abort "{{{2
    if getcmdtype() =~# '[?/]'
        return empty(getcmdline())
           \ ?     "\<up>"
           \ :     a:is_fwd ? "\<c-g>" : "\<c-t>"
    else
        if a:is_fwd
            return s:save_cmdline_before_expansion()
        endif
        let flags = 'in'.(!wildmenumode() ? 't' : '')
        "                                    │
        "           handle key as if typed,  ┘
        "           otherwise it's  handled as if  coming from a  mapping, which
        "           matters when we  try to open the wildmenu,  or cycle through
        "           its entries

        " Why use `feedkeys()`?{{{
        "
        " If we used this mapping:
        "
        "         cno <expr>  <s-tab>  getcmdtype() =~ '[?/]' ? '<c-t>' : '<s-tab>'
        "
        " When we would hit <s-tab> on the command-line (:) (outside the wildmenu),
        " it would insert the 7 characters '<s-tab>', literally.
        " That's not what `S-Tab` does by default. It should simply open the wildmenu
        " and select its last entry.
        " We need `S-Tab` to be treated as if it wasn't coming from a mapping.
        " We need to pass the `t` flag to `feedkeys()`.
        "}}}
        " Why not pass the `t` flag unconditionally?{{{
        "
        " It breaks the  replay of a macro during which  we've pressed `Tab`
        " or `S-Tab` on the command-line.
        " MWE:
        "         qqq
        "         qq : Tab Tab CR    (should execute `:#`)
        "         q
        "
        "         :nunmap @
        "         @q
        "         should print the current line; does not~
        "}}}
        call feedkeys("\<s-tab>", flags)
        return ''
    endif
endfu

fu! cmdline#tab#restore_cmdline_after_expansion() abort "{{{2
    if !exists('s:cmdline_before_expansion')
        return getcmdline()
    endif
    redraw
    call timer_start(0, {-> execute('unlet! s:cmdline_before_expansion')})
    return get(s:, 'cmdline_before_expansion', getcmdline())
endfu

" Utility {{{1
fu! s:save_cmdline_before_expansion() abort "{{{2
    " The returned  key will  be pressed  from a  mapping while  in command-line
    " mode.
    " We want Vim to start a wildcard expansion.
    " So, we need to return whatever key is stored in 'wcm'.
    let l:key = nr2char(&wcm ? &wcm : &wc)
    if wildmenumode()
        return l:key
    endif
    let cmdline = getcmdline()
    call timer_start(0, {-> s:save_if_wildmenu_is_active(cmdline)})
    return l:key
endfu

fu! s:save_if_wildmenu_is_active(cmdline) abort "{{{2
    if wildmenumode()
        let s:cmdline_before_expansion = a:cmdline
    endif
endfu

