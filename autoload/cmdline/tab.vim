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
        " Why `feedkeys()`?{{{
        "
        " To make Vim press `S-Tab` as if it didn't come from a mapping.
        " Without  `feedkeys()`  and  the  `t`  flag,  hitting  `S-Tab`  on  the
        " command-line outside the  wildmenu, makes Vim insert  the 7 characters
        " `<S-Tab>`, literally.
        " That's not  what `S-Tab` does by  default.  It should simply  open the
        " wildmenu and select its last entry.
        " We need `S-Tab` to be treated as if it wasn't coming from a mapping.
        " We need to pass the `t` flag to `feedkeys()`.
        "}}}
        " Why don't you pass the `t` flag unconditionally?{{{
        "
        " During a recording, `S-Tab` would be recorded twice.
        "
        "    - once when you pressed the key interactively
        "    - once when `feedkeys()` wrote the key in the typeahead
        "
        " Because of that, the execution of the register would be wrong; `S-Tab`
        " would be  pressed twice.
        "
        " Solution: Don't use the `t` flag when a register is being executed, so
        " that the first `S-Tab` has no effect.
        "}}}
        let flags = 'in'..(empty(reg_executing()) ? '' : 't')
        " TODO: Why is the `i` flag necessary here?{{{
        "
        " Hint: Without,  the replay  of the  previous macro  does not  give the
        " expected result; why?
        "
        " Answer: When you replay the macro, here's what happens:
        "
        "     typeahead       | executed
        "     --------------------------
        "     @q              |
        "     :^I^I^I<80>kB^M |
        "      ^I^I^I<80>kB^M | :
        "        ^I^I<80>kB^M | :^I
        "          ^I<80>kB^M | :^I^I
        "            <80>kB^M | :^I^I^I
        "                  ^M | :^I^I^I<80>kB
        "                              ^^^^^^
        "                              S-Tab typed interactively;
        "                              it's going to feed another S-Tab via `feedkeys()`
        "
        " When this function is invoked, a CR is still in the typeahead.
        " Without  the `i`  flag, `S-Tab`  is  appended, which  means that  it's
        " executed  *after* whatever  Ex command  is currently  selected in  the
        " wildmenu.  It  turns out that the  Ex command which is  selected after
        " you open the wildmenu and press Tab twice is `:&`.
        " In any  case, `S-Tab` is  executed too late;  it should have  made Vim
        " select `:#` (which is the previous entry before `:&`).
        "
        " But wait.  Does this mean that we should *always* use `i`?
        "
        " Similar issue:
        " https://github.com/tpope/vim-repeat/issues/23
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
