if exists('g:loaded_cmdline')
    finish
endif
let g:loaded_cmdline = 1

" Abbreviations {{{1
" Unused_code:{{{
"
"         fu! s:strict_abbr(args, cmd) abort
"             let l:lhs = matchstr(a:args, '^\s*\zs\S\+')
"             let l:rhs = matchstr(a:args, '^\s*\S\+\s\+\zs.*')
"             if a:cmd
"                 exe printf("cnorea <expr> %s getcmdtype() ==# ':' ? '%s' : '%s'", l:lhs, l:rhs, l:lhs)
"             else
"                 exe printf("cnorea <expr> %s getcmdtype() =~ '[/?]' ? '%s' : '%s'", l:lhs, l:rhs, l:lhs)
"             endif
"         endfu
"
"         com! -nargs=+ Cab call s:strict_abbr(<q-args>, 1)
"         com! -nargs=+ Sab call s:strict_abbr(<q-args>, 0)
"}}}

" When I want to search for tab characters, I often type \` by accident fix this
" automatically.
cnorea <expr>  \`    getcmdtype() =~# '[/?]'  ? '\t' : '\`'

cnorea <expr>  sl    getcmdtype() ==# ':' && getcmdpos() == 3  ? 'ls'             : 'sl'
cnorea <expr>  hg    getcmdtype() ==# ':' && getcmdpos() == 3  ? 'helpgrep'       : 'hg'
cnorea <expr>  dig   getcmdtype() ==# ':' && getcmdpos() == 4  ? 'verb Digraphs!' : 'dig'
cnorea <expr>  ecoh  getcmdtype() ==# ':' && getcmdpos() == 5  ? 'echo'           : 'ecoh'

"         :fbl    →    :FzBLines
"         :fc     →    :FzCommands
"         :fl     →    :FzLines
"         :fs     →    :FzLocate
cnorea <expr>  fbl   getcmdtype() ==# ':'  && getcmdpos() == 4  ?  'FzBLines'      : 'fbl'
cnorea <expr>  fc    getcmdtype() ==# ':'  && getcmdpos() == 3  ?  'FzCommands'    : 'fc'
cnorea <expr>  fl    getcmdtype() ==# ':'  && getcmdpos() == 3  ?  'FzLines'       : 'fl'
cnorea <expr>  fs    getcmdtype() ==# ':'  && getcmdpos() == 3  ?  'FzLocate'      : 'fs'
"              │
"              └─ `fl` is already taken for `:FzLines`
"                 besides, we can use this mnemonics: in `fs`, `s` is for ’_s_earch’.

cnorea <expr>  ucs   getcmdtype() ==# ':' && getcmdpos() == 4  ? 'UnicodeSearch'  : 'ucs'

cnorea <expr>  pc    getcmdtype() ==# ':'  && getcmdpos() == 3  ? 'sil! PlugClean' : 'pc'

"         :pc    →    :sil! PlugClean
"
" NOTE:
"
" if we try to clean the plugins with `PlugClean`, while having a modified plugin,
" the modifications not being committed, we have this error:
"
"     /home/user/Dropbox/conf/vim/autoload/plug.vim|2082| <SNR>4_clean[13]
"     /home/user/Dropbox/conf/vim/autoload/plug.vim|2039| <SNR>4_git_validate[36]
"     || E688: More targets than List items
"
" Solution:
" When you want to modify a plugin, do it on a cloned version.
" This way, you can commit your changes, and `Vim-Plug` won't complain.
" Besides, it's better because your modifications are backed up on github.
"
" The only downside is that, if you use a clone of a plugin, when you do an
" update, you're not being informed when the author of a plugin adds a new
" feature, or fixes a bug.
" So, only clone if the plugin is old, or inactive since a long time, or it's
" a really simple one. Otherwise, try to submit a PR.

" Autocmds {{{1

augroup my_lazy_loaded_cmdline
    au!
    au CmdLineEnter * call cmdline#auto_uppercase()
                   \| call cmdline#remember(s:overlooked_commands)
                   \| unlet! s:overlooked_commands
                   \| exe 'au! my_lazy_loaded_cmdline'
                   \| exe 'aug! my_lazy_loaded_cmdline'
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

" Variable {{{1

let s:overlooked_commands = [
                          \   { 'old': 'vs\%[plit]', 'new': 'C-w v', 'regex': 1 },
                          \   { 'old': 'sp\%[lit]' , 'new': 'C-w s', 'regex': 1 },
                          \   { 'old': 'q!'        , 'new': 'ZQ'   , 'regex': 0 },
                          \   { 'old': 'x'         , 'new': 'ZZ'   , 'regex': 0 },
                          \ ]
