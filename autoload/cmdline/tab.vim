fu cmdline#tab#custom(is_fwd = v:true) abort "{{{1
    if getcmdtype() =~# '[?/]'
        return getcmdline() == ''
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
        " Why `feedkeys()`?{{{
        "
        " To make Vim press `S-Tab` as if it didn't come from a mapping.
        " Without  the  `t`  flag  of   `feedkeys()`,  hitting  `S-Tab`  on  the
        " command-line outside  the wildmenu makes  Vim insert the  7 characters
        " `<S-Tab>`, literally.
        " That's not  what `S-Tab` does by  default.  It should simply  open the
        " wildmenu and select its last entry.
        "}}}
        " Why `reg_recording()->empty()`?{{{
        "
        " Without, during a recording, `S-Tab` would be recorded twice:
        "
        "    - once when you press the key interactively
        "    - once when `feedkeys()` writes the key in the typeahead
        "
        " Because of that, the execution of the register would be wrong; `S-Tab`
        " would be  pressed twice.
        "}}}
        "   Wait.  What if I press `S-Tab` during a recording while the wildmenu is not open?{{{
        "
        " Well, it will be broken; i.e. `<S-Tab>` will be inserted on the command-line.
        " I don't know how to fix this, and I don't really care; it's a corner case.
        "}}}
        if !wildmenumode() && reg_recording()->empty()
            call feedkeys("\<s-tab>", 'int')
            return ''
        endif
        return "\<s-tab>"
    endif
endfu

fu cmdline#tab#restore_cmdline_after_expansion() abort "{{{1
    let cmdline_before_expansion = cmdline#unexpand#get_oldcmdline()
    if cmdline_before_expansion == '' | return getcmdline() | endif
    " clear wildmenu
    redraw
    au CmdlineChanged : ++once call cmdline#unexpand#clear_oldcmdline()
    return cmdline_before_expansion
endfu
" }}}1
