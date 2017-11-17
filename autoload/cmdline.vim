if exists('g:autoloaded_cmdline')
    finish
endif
let g:autoloaded_cmdline = 1

" Functions {{{1
fu! cmdline#auto_uppercase() abort "{{{2

" We define abbreviations in command-line mode to automatically replace
" a custom command name written in lowercase with uppercase characters.

    let commands = getcompletion('[A-Z]?*', 'command') + s:fugitive_commands

    for cmd in commands
        let lcmd  = tolower(cmd)
        exe printf('cnorea <expr> %s
        \               getcmdtype() == '':'' && getcmdline() =~# ''\v^%(%(tab<Bar>vert%[ical])\s+)?%s$''
        \               ?     %s
        \               :     %s
        \          ', lcmd, lcmd, string(cmd), string(tolower(cmd))
        \         )
    endfor
endfu

fu! cmdline#chain() abort "{{{2
    " Do NOT write empty lines in this function (gQ → E501, E749).
    let cmdline = getcmdline()
    let pat2cmd = {
                \  '(g|v).*(#@<!#|nu%[mber])' : [ ''         , 0 ],
                \  '(ls|files|buffers)!?'     : [ 'b '       , 0 ],
                \  'chi%[story]'              : [ 'sil col ' , 1 ],
                \  'lhi%[story]'              : [ 'sil lol ' , 1 ],
                \  'marks'                    : [ 'norm! `'  , 1 ],
                \  'old%[files]'              : [ 'e #<'     , 1 ],
                \  'undol%[ist]'              : [ 'u '       , 1 ],
                \  'changes'                  : [ "norm! g;\<s-left>"     , 1 ],
                \  'ju%[mps]'                 : [ "norm! \<c-o>\<s-left>" , 1 ],
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

fu! cmdline#fix_typo(label) abort "{{{2
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

fu! cmdline#install_fugitive_commands() abort "{{{2
    " In vimrc,  we postpone  the loading  of `fugitive`  after Vim  has started
    " (through a timer).

    " It could  be an issue  in the  future, if we  install a custom  mapping to
    " execute a  fugitive command, and  we press it  before the plugin  has been
    " loaded.
    "
    " Also, when we:
    "
    "         • start Vim  with a file to open as an argument
    "         • the file is in a git repo
    "         • type `:Glog`
    "
    " … it fails.
    "
    " This  is because  fugitive listens  to  certain events  like `BufReadPost`  to
    " detect  whether the  current file  is inside  a  git repo,  and if  it is,  it
    " installs its buffer-local commands.
    " Even if `fugitive` is correctly lazy-loaded  AFTER Vim has started reading the
    " file, it wasn't loaded at the time the  file was read.  So, we need to re-emit
    " `BufReadPost` so that fugitive properly installs its commands.
    augroup my_install_fugitive_commands
        au!
        " Do NOT make this autocmd a fire-once autocmd.
        " There may be more than 1 file which were opened when Vim started.
        " The autocmd needs to be there for all of them.
        au CmdUndefined * if index(s:fugitive_commands, expand('<afile>')) >= 0
                       \|     sil! doautocmd fugitive BufReadPost
                       \| endif
    augroup END
endfu

fu! cmdline#remember(list) abort "{{{2
    augroup remember_overlooked_commands
        au!
        for cmd in a:list
            exe printf('
            \            au CmdlineLeave :
            \            if getcmdline() %s %s
            \|               call timer_start(0, {-> execute("echohl WarningMsg | echo %s | echohl NONE", "")})
            \|           endif
            \          ',     cmd.regex ? '=~#' : '==#',
            \                 string(cmd.regex ? '^'.cmd.old.'$' : cmd.old),
            \                 string('['.cmd.new .'] was equivalent')
            \         )
        endfor
    augroup END
endfu

fu! cmdline#toggle_editing_commands(enable) abort "{{{2
    try
        if a:enable
            call my_lib#map_restore(get(s:, 'my_editing_commands', []))
        else
            let lhs_list = map(split(execute('cno'), '\n'), 'matchstr(v:val, ''\vc\s+\zs\S+'')')
            call filter(lhs_list, '!empty(v:val)')
            let s:my_editing_commands = my_lib#map_save(lhs_list, 'c', 1)

            for lhs in lhs_list
                exe 'cunmap '.lhs
            endfor
        endif

    catch
        return 'echoerr '.string(v:exception)
    endtry
endfu
" Variable {{{1

let s:fugitive_commands = [
\                           'Gblame',
\                           'Gbrowse',
\                           'Gcd',
\                           'Gcommit',
\                           'Gdelete',
\                           'Gdiff',
\                           'Ge',
\                           'Gedit',
\                           'Gfetch',
\                           'Ggrep',
\                           'Git',
\                           'Glcd',
\                           'Glgrep',
\                           'Gllog',
\                           'Glog',
\                           'Gmerge',
\                           'Gmove',
\                           'Gpedit',
\                           'Gpull',
\                           'Gpush',
\                           'Gread',
\                           'Gremove',
\                           'Gsdiff',
\                           'Gsplit',
\                           'Gstatus',
\                           'Gtabedit',
\                           'Gvdiff',
\                           'Gvsplit',
\                           'Gw',
\                           'Gwq',
\                           'Gwrite',
\                         ]

