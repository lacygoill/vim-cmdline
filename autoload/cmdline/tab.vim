fu cmdline#tab#custom(is_fwd) abort "{{{1
    if getcmdtype() =~# '[?/]'
        return getcmdline() is# ''
           \ ?     "\<up>"
           \ :     a:is_fwd ? "\<c-g>" : "\<c-t>"
    endif
    if a:is_fwd
        " The returned key will be pressed from a mapping while in command-line mode.
        " We want Vim to start a wildcard expansion.
        " So, we need to return whatever key is stored in 'wcm'.
        let key = nr2char(&wcm ? &wcm : &wc)
        return wildmenumode() ? key : cmdline#unexpand#save_oldcmdline(key, getcmdline())
    else
        " Why the `t` flag?{{{
        "
        " To handle  `S-Tab` as if  it was typed,  otherwise it's handled  as if
        " coming from a mapping, which matters when we try to open the wildmenu,
        " or cycle through its entries
        "}}}
        let flags = 'in'..(wildmenumode() ? '' : 't')
        " Why use `feedkeys()`?{{{
        "
        " If we used this mapping:
        "
        "     cno <expr>  <s-tab>  getcmdtype() =~ '[?/]' ? '<c-t>' : '<s-tab>'
        "
        " When we would hit `S-Tab`  on the command-line (outside the wildmenu),
        " it would insert the 7 characters `<s-tab>`, literally.
        " That's not  what `S-Tab`  does by default. It  should simply  open the
        " wildmenu and select its last entry.
        " We need `S-Tab` to be treated as if it wasn't coming from a mapping.
        " We need to pass the `t` flag to `feedkeys()`.
        "}}}
        " Why not pass the `t` flag unconditionally?{{{
        "
        " It breaks the  replay of a macro during which  we've pressed `Tab`
        " or `S-Tab` on the command-line.
        "
        " MWE:
        "
        "     qqq
        "     qq : Tab Tab CR    (should execute `:#`)
        "     q
        "
        "     :nunmap @
        "     @q
        "     " should print the current line; does not
        "}}}
        call feedkeys("\<s-tab>", flags)
        return ''
    endif
endfu

fu cmdline#tab#restore_cmdline_after_expansion() abort "{{{1
    let cmdline_before_expansion = cmdline#unexpand#get_oldcmdline()
    if cmdline_before_expansion is# '' | return getcmdline() | endif
    redraw
    au CmdlineChanged : ++once call cmdline#unexpand#clear_oldcmdline()
    return cmdline_before_expansion
endfu
" }}}1
