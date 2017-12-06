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

" fix some typos
cnorea <expr>  \`    getcmdtype() =~# '[/?]'  ? '\t' : '\`'
cnorea <expr>  soù   getcmdtype() =~# ':' && getcmdline() ==# 'soù' ? 'so%' : 'soù'


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

"         :pc    →    :sil! PlugClean
cnorea <expr>  pc    getcmdtype() ==# ':'  && getcmdpos() == 3  ? 'sil! PlugClean' : 'pc'

" Autocmds {{{1

augroup my_lazy_loaded_cmdline
    au!
    " Do NOT write a bar after a backslash  on an empty line: it would result in
    " 2 consecutive bars (empty command). This would print a line of a buffer on
    " the command line, when we change the focused window for the first time.
    au CmdlineEnter : call cmdline#auto_uppercase()
    \
    \|                call cmdline#install_fugitive_commands()
    \
    \|                call cmdline#remember(s:overlooked_commands)
    \|                unlet! s:overlooked_commands
    \
    \|                call cmdline#pass_and_install_cycles(s:cycles)
    \|                unlet! s:cycles
    \
    \|                exe 'au! my_lazy_loaded_cmdline'
    \|                exe 'aug! my_lazy_loaded_cmdline'
augroup END

augroup my_cmdline_chain
    au!
    " Automatically execute  command B when A  has just been executed  (chain of
    " commands). Inspiration:
    "         https://gist.github.com/romainl/047aca21e338df7ccf771f96858edb86
    au CmdlineLeave : call cmdline#chain()

    " TODO:
    " The following autocmds are not  handled by `cmdline#chain()`, because they
    " don't  execute simple  Ex commands. Still,  it's a  bit weird  to have  an
    " autocmd handling simple  commands (+ 2 less simple), and  a bunch of other
    " related autocmds handling more complex commands.
    "
    " Try to find a way to consolidate all cases in `cmdline#chain()`.
    " Refactor it, so that when it handles complex commands, the code is readable.
    " No long    if … | then … | elseif … | … | elseif … | …

    " We use a timer to avoid reenabling the editing commands before having left
    " the command-line completely. Otherwise E501.
    au CmdlineLeave : if getcmdline() =~# '\v^\s*vi%[sual]\s*$'
                   \|     call timer_start(0, {-> execute('ToggleEditingCommands 1')})
                   \| endif

    " enable the  item in  the statusline  showing our  position in  the arglist
    " after we execute an `:args` command
    au CmdlineLeave : if getcmdline() =~# '\v\C^%(tab\s+)?ar%[gs]\s+'
                   \|     call timer_start(0, { -> execute('let g:my_stl_list_position = 1 | redraw!') })
                   \| endif

    " sometimes, we type `:h functionz)` instead of `:h function()`
    au CmdlineLeave : if getcmdline() =~# '\v\C^h%[elp]\s+\S+z\)\s*$'
                   \|     call cmdline#fix_typo('z')
                   \| endif

    " when we copy a line of vimscript and paste it on the command line,
    " sometimes the newline gets copied and translated into a literal CR,
    " which raises an error:    remove it
    au CmdlineLeave : if getcmdline() =~# '\r$'
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
com! -bar -nargs=1 ToggleEditingCommands exe cmdline#toggle_editing_commands(<args>)

" Mappings {{{1

" The following mapping transforms the command line in 2 ways, depending on where we press it:{{{
"
"     • on the search command-line, it translates the pattern so that:
"
"           - it's searched outside comments
"
"           - all alphabetical characters are replaced with their corresponding
"             equivalence class
"
"     • on the Ex command-line, if the latter contains a substitution command,
"       inside the pattern, it captures the words written in snake case or
"       camel case inside parentheses, so that we can refer to them easily
"       with backref in the replacement.
"}}}
cno <expr><unique>  <c-s>  cmdline#transform()

" Cycle through a set of arbitrary commands.
" Each cycle is installed with `:CycleInstall` in:
"
"         ~/.vim/plugged/vim-cmdline/autoload/cmdline.vim
cno <unique>  <c-z>   <c-\>ecmdline#cycle(1)<cr>
cno <unique>  <m-z>   <c-\>ecmdline#cycle(0)<cr>

xno <unique>  <c-z>s  :s/\v//g<left><left><left>

"   ┌─ need this variable to pass the commands that are in each cycle we're going to configure,
"   │  to the autoload/ script, where the bulk of the code installing cycles reside
"   │
let s:cycles = []
fu! s:cycle_configure(key, ...) abort
    exe 'nno <unique> <c-z>'.a:key
    \              .' :<c-u>'.substitute(a:1, '@', '', '')
    \              .'<c-b>'.repeat('<right>', stridx(a:1, '@'))
    let s:cycles += [ a:000 ]
endfu

" populate command-line with a substitution command
call s:cycle_configure('s', '%s/\v@//g', '%s/\v@//gc')
"                       │         │
"                       │         └ where we want the cursor to be
"                       │
"                       └ key to press in normal mode, after `C-z`, to populate the command line
"                         with the 1st command in the cycle

" populate command-line with a `:vimgrep` command
call s:cycle_configure('v',
\                      'vim /@/gj ~/.vim/**/*.vim ~/.vim/vimrc',
\                      'vim /@/gj $VIMRUNTIME/**/*.vim',
\                      'vim /@/gj ##',
\                      'lvim /@/gj %')
" TODO: `:[l]vim[grep]` is not asynchronous.
" Add an async command (using  &grepprg?).

" Variable {{{1

let s:overlooked_commands = [
                          \   { 'old': 'vs\%[plit]', 'new': 'C-w v', 'regex': 1 },
                          \   { 'old': 'sp\%[lit]' , 'new': 'C-w s', 'regex': 1 },
                          \   { 'old': 'q!'        , 'new': 'ZQ'   , 'regex': 0 },
                          \   { 'old': 'x'         , 'new': 'ZZ'   , 'regex': 0 },
                          \ ]
