if exists('g:loaded_cmdline')
    finish
endif
let g:loaded_cmdline = 1

" Variable {{{1

let s:overlooked_commands = [
                          \   { 'old': 'vs\%[plit]', 'new': 'C-w v', 'regex': 1 },
                          \   { 'old': 'sp\%[lit]' , 'new': 'C-w s', 'regex': 1 },
                          \   { 'old': 'q!'        , 'new': 'ZQ'   , 'regex': 0 },
                          \   { 'old': 'x'         , 'new': 'ZZ'   , 'regex': 0 },
                          \ ]

" Autocmds {{{1

augroup lazy_load_reminders
    au!
    au CmdLineEnter * call cmdline#remember(s:overlooked_commands)
                   \| unlet! s:overlooked_commands
                   \| exe 'au! lazy_load_reminders'
                   \| exe 'aug! lazy_load_reminders'
augroup END

augroup my_cmdline
    au!
    " Automatically execute  command B when A  has just been executed  (chain of
    " commands). Inspiration:
    "         https://gist.github.com/romainl/047aca21e338df7ccf771f96858edb86
    au CmdLineLeave : call cmdline#chain()

    " We use a timer to avoid reenabling the editing commands before having left
    " the command-line completely. Otherwise E501.
    au CmdLineLeave : if getcmdline() =~# '\v^\s*vi%[sual]\s*$'
                   \|     call timer_start(0, {-> execute('ToggleEditingCommands 1')})
                   \| endif

    " enable the  item in  the statusline  showing our  position in  the arglist
    " after we execute an `:args` command
    au CmdLineLeave : if getcmdline() =~# '\v\C^%(tab\s+)?ar%[gs]\s+'
                   \|     call timer_start(0, { -> execute('let g:my_stl_list_position = 1 | redraw!') })
                   \| endif

    " sometimes, we type `:h functionz)` instead of `:h function()`
    au CmdLineLeave : if getcmdline() =~# '\v\C^h%[elp]\s+\S+z\)\s*$'
                   \|     call cmdline#fix_typo('z')
                   \| endif

    " when we copy a line of vimscript and paste it on the command line,
    " sometimes the newline gets copied and translated into a literal CR,
    " which raises an error:    remove it
    au CmdLineLeave : if getcmdline() =~# '\r$'
                   \|     call cmdline#fix_typo('cr')
                   \| endif
augroup END

" Command {{{1

" Purpose:{{{
" We have several custom mappings in command-line mode.
" Some of them are bound to custom functions.
" They interfere / add noise / bug (cr) when we're in debug or Ex mode.
" We install this command so that it can be used to toggle them when needed,
" in other plugins/vimrc/….
"}}}
" Usage:{{{
"         ToggleEditingCommands 0  →  disable
"         ToggleEditingCommands 1  →  enable
"}}}
com! -bar -nargs=1 ToggleEditingCommands call cmdline#toggle_editing_commands(<args>)
