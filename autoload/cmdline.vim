if exists('g:autoloaded_cmdline')
    finish
endif
let g:autoloaded_cmdline = 1

fu! cmdline#chain() abort "{{{1
    " Do NOT write empty lines in this function (gQ → E501, E749).
    let cmdline = getcmdline()
    let pat2cmd = {
                \  '(g|v).*(#|nu%[mber])' : [ '# '       , 0 ],
                \  '(ls|files|buffers)!?' : [ 'b '       , 0 ],
                \  'chi%[story]'          : [ 'sil col ' , 1 ],
                \  'lhi%[story]'          : [ 'sil lol ' , 1 ],
                \  'marks'                : [ 'norm! `'  , 1 ],
                \  'old%[files]'          : [ 'e #<'     , 1 ],
                \  'undol%[ist]'          : [ 'u '       , 1 ],
                \  'changes'              : [ "norm! g;\<s-left>"     , 1 ],
                \  'ju%[mps]'             : [ "norm! \<c-o>\<s-left>" , 1 ],
                \ }
    for [pat, cmd ] in items(pat2cmd)
        let [ keys, nomore ] = cmd
        if cmdline =~# '\v\C^'.pat.'$'
            if nomore
                let more_save = &more
                " allow Vim's pager to display the full contents of any command,
                " even if it takes more than one screen; don't stop after the first
                " screen to display the message:    -- More --
                set nomore
                call timer_start(0, {-> execute('set '.(more_save ? '' : 'no').'more')})
            endif
            return feedkeys(':'.keys, 'in')
        endif
    endfor
    if cmdline =~# '\v\C^(dli|il)%[ist]\s+'
        call feedkeys(':'.cmdline[0].'j  '.split(cmdline, ' ')[1]."\<s-left>\<left>", 'in')
    elseif cmdline =~# '\v\C^(cli|lli)'
        call feedkeys(':sil '.repeat(cmdline[0], 2).' ', 'in')
    endif
endfu
fu! cmdline#fix_typo(label) abort "{{{1
    let cmdline = getcmdline()
    let keys = {
             \   'cr': "\<bs>\<cr>",
             \   'z' : "\<bs>\<bs>()\<cr>",
             \ }[a:label]
    "                                    ┌─ do NOT replace this with `getcmdline()`:
    "                                    │
    "                                    │      when the callback will be processed,
    "                                    │      the old command line will be lost
    "                                    │
    call timer_start(0, {-> feedkeys(':'.cmdline.keys, 'in')})
    "    │
    "    └─ we can't send the keys right now, because the command hasn't been
    "       executed yet; from `:h CmdWinLeave`:
    "
    "               “Before leaving the command line.“
    "
    "       But it seems we can't modify the command either. Maybe it's locked.
    "       So, we'll reexecute a new fixed command with the timer.
endfu

fu! cmdline#remember(list) abort "{{{1
    augroup remember_overlooked_commands
        au!
        for cmd in a:list
            exe printf('
                      \  au CmdLineLeave :
                      \  if getcmdline() %s %s
                      \|     call timer_start(0, {-> execute("echohl WarningMsg | echo %s | echohl NONE", "")})
                      \| endif
                      \',     cmd.regex ? '=~#': '==#' , string(cmd.old), string('['.cmd.new .'] was equivalent')
                      \  )
        endfor
    augroup END
endfu

fu! cmdline#toggle_editing_commands(enable) abort "{{{1
    if a:enable
        call tmp_mappings#restore(get(s:, 'my_editing_commands', []))
    else
        let lhs_list = map(split(execute('cno'), '\n'), 'matchstr(v:val, ''\vc\s+\zs\S+'')')
        let s:my_editing_commands = tmp_mappings#save(lhs_list, 'c', 1)

        for lhs in lhs_list
            exe 'cunmap '.lhs
        endfor
    endif
endfu
