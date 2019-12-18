if exists('g:autoloaded_cmdline')
    finish
endif
let g:autoloaded_cmdline = 1

fu cmdline#auto_uppercase() abort "{{{1
    " We define  abbreviations in command-line  mode to automatically  replace a
    " custom command name written in lowercase with uppercase characters.

    " Do *not* use `getcompletion()`.{{{
    "
    "     let commands = getcompletion('[A-Z]?*', 'command')
    "
    " You would get the names of the global commands (✔) *and* the ones local to
    " the current buffer (✘); we don't want the latter.
    " Installing  a *global* abbreviation  for a *buffer-local*  command doesn't
    " make sense.
    "}}}
    let commands = map(filter(split(execute('com'), '\n')[1:],
    \ {_,v -> v =~# '^[^bA-Z]*\u\S'}),
    \ {_,v -> matchstr(v, '\u\S*')})

    let pat = '^\%%(\%%(tab\<bar>vert\%%[ical]\)\s\+\)\=%s$\<bar>^\%%(''<,''>\<bar>\*\)%s$'
    for cmd in commands
        let lcmd  = tolower(cmd)
        exe printf('cnorea <expr> %s
            \         getcmdtype() is# '':'' && getcmdline() =~# '.string(pat).'
            \         ?     %s
            \         :     %s'
            \ , lcmd, lcmd, lcmd, string(cmd), string(tolower(cmd))
            \ )
    endfor
endfu

fu cmdline#chain() abort "{{{1
    " Do *not* write empty lines in this function (`gQ` → E501, E749).
    let cmdline = getcmdline()
    let pat2cmd = {
        \ '\%(g\|v\).*\%(#\@1<!#\|nu\%[mber]\)' : [''        , 0],
        \ '\%(ls\|files\|buffers\)!\='          : ['b '      , 0],
        \ 'chi\%[story]'                        : ['CC '     , 1],
        \ 'lhi\%[story]'                        : ['LL '     , 1],
        \ 'marks'                               : ['norm! `' , 1],
        \ 'old\%[files]'                        : ['e #<'    , 1],
        \ 'undol\%[ist]'                        : ['u '      , 1],
        \ 'changes'                             : ["norm! g;\<s-left>"     , 1],
        \ 'ju\%[mps]'                           : ["norm! \<c-o>\<s-left>" , 1],
        \ }
    for [pat, cmd] in items(pat2cmd)
        let [keys, nomore] = cmd
        if cmdline =~# '\C^'..pat..'$'
            " when I  execute `:[cl]chi`,  don't populate the  command-line with
            " `:sil [cl]ol` if the qf stack doesn't have at least two qf lists
            if pat is# 'lhi\%[story]' && get(getloclist(0, {'nr': '$'}), 'nr', 0) <= 1
            \ || pat is# 'chi\%[story]' && get(getqflist({'nr': '$'}), 'nr', 0) <= 1
                return
            endif
            if pat is# 'chi\%[story]'
                let pfx = 'c'
            elseif pat is# 'lhi\%[story]'
                let pfx = 'l'
            endif
            if exists('pfx')
                if pfx is# 'c' && get(getqflist({'nr': '$'}), 'nr', 0) <= 1
                \ || pfx is# 'l' && get(getloclist(0, {'nr': '$'}), 'nr', 0) <= 1
                    return
                endif
            endif
            if nomore
                let s:more_save = &more
                " allow Vim's pager to display the full contents of any command,
                " even if it takes more than one screen; don't stop after the first
                " screen to display the message:    -- More --
                set nomore
                au CmdlineLeave * ++once exe 'set '..(s:more_save ? '' : 'no')..'more'
                    \ | unlet! s:more_save
            endif
            return feedkeys(':'..keys, 'in')
        endif
    endfor
    if cmdline =~# '\C^\s*\%(dli\|\il\)\%[ist]\s\+'
        call feedkeys(':'..matchstr(cmdline, '\S')..'j  '..split(cmdline, ' ')[1].."\<s-left>\<left>", 'in')
    elseif cmdline =~# '\C^\s*\%(cli\|lli\)'
        call feedkeys(':sil '..repeat(matchstr(cmdline, '\S'), 2)..' ', 'in')
    endif
endfu

fu cmdline#fix_typo(label) abort "{{{1
    let cmdline = getcmdline()
    let keys = {
             \   'cr': "\<bs>\<cr>",
             \   'z' : "\<bs>\<bs>()\<cr>",
             \ }[a:label]
    "                                       ┌ do *not* replace this with `getcmdline()`:
    "                                       │
    "                                       │     when the callback will be processed,
    "                                       │     the old command-line will be lost
    "                                       │
    call timer_start(0, {_ -> feedkeys(':'..cmdline..keys, 'in')})
    "    │
    "    └ we can't send the keys right now, because the command hasn't been
    "      executed yet; from `:h CmdlineLeave`:
    "
    "          “Before leaving the command-line.“
    "
    "      But it seems we can't modify the command either. Maybe it's locked.
    "      So, we'll reexecute a new fixed command with the timer.
endfu

fu cmdline#remember(list) abort "{{{1
    augroup remember_overlooked_commands
        au!
        for cmd in a:list
            exe printf('
            \            au CmdlineLeave :
            \            if getcmdline() %s %s
            \ |              exe "au SafeState * ++once echohl WarningMsg | echo %s | echohl NONE"
            \ |          endif
            \          ',     cmd.regex ? '=~#' : 'is#',
            \                 string(cmd.regex ? '^'..cmd.old..'$' : cmd.old),
            \                 string('['..cmd.new..'] was equivalent')
            \         )
        endfor
    augroup END
endfu

fu cmdline#toggle_editing_commands(enable) abort "{{{1
    try
        if a:enable
            call lg#map#restore(get(s:, 'my_editing_commands', []))
        else
            let lhs_list = split(execute('cno'), '\n')
            " ignore buffer-local mappings
            call filter(lhs_list, {_,v -> v !~# '^c\s*\S*\s*\S*@'})
            " extract lhs
            call map(lhs_list, {_,v -> matchstr(v, 'c\s\+\zs\S\+')})
            let s:my_editing_commands = lg#map#save('c', 0, lhs_list)
            " TODO: We should be able to replace this `for` block with `:cmapclear`.{{{
            "
            " But in practice, it seems to make a slight difference.
            " Compare the output of `:cno` before/after running:
            "
            "     :ToggleEditingCommands 0
            "     :ToggleEditingCommands 1
            "
            " Then perform the  same comparison after replacing  the `for` block
            " with `:cmapclear`.
            "}}}
            for lhs in lhs_list
                exe 'cunmap '..lhs
            endfor
        endif
    catch
        return lg#catch_error()
    endtry
endfu

