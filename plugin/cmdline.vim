if exists('g:loaded_cmdline')
    finish
endif
let g:loaded_cmdline = 1

" Abbreviations {{{1
" Unused_code:{{{
"
"         fu s:strict_abbr(args, cmd) abort
"             let lhs = matchstr(a:args, '^\s*\zs\S\+')
"             let rhs = matchstr(a:args, '^\s*\S\+\s\+\zs.*')
"             if a:cmd
"                 exe printf("cnorea <expr> %s getcmdtype() is# ':' ? '%s' : '%s'", lhs, rhs, lhs)
"             else
"                 exe printf("cnorea <expr> %s getcmdtype() =~ '[/?]' ? '%s' : '%s'", lhs, rhs, lhs)
"             endif
"         endfu
"
"         com -nargs=+ Cab call s:strict_abbr(<q-args>, 1)
"         com -nargs=+ Sab call s:strict_abbr(<q-args>, 0)
"}}}

" fix some typos
cnorea <expr>  \`    getcmdtype() =~# '[/?]'  ? '\t' : '\`'

cnorea <expr>  soù   getcmdtype() =~# ':' && getcmdpos() == 4 ? 'so%' : 'soù'
cnorea <expr>  sl    getcmdtype() is# ':' && getcmdpos() == 3  ? 'ls'             : 'sl'
cnorea <expr>  hg    getcmdtype() is# ':' && getcmdpos() == 3  ? 'helpgrep'       : 'hg'
cnorea <expr>  dig   getcmdtype() is# ':' && getcmdpos() == 4  ? 'verb Digraphs!' : 'dig'
cnorea <expr>  ecoh  getcmdtype() is# ':' && getcmdpos() == 5  ? 'echo'           : 'ecoh'

"         :fbl
"         :FzBLines~
"         :fc
"         :FzCommands~
"         :fl
"         :FzLines~
"         :fs
"         :FzLocate~
cnorea <expr>  fbl   getcmdtype() is# ':'  && getcmdpos() == 4  ?  'FzBLines'      : 'fbl'
cnorea <expr>  fc    getcmdtype() is# ':'  && getcmdpos() == 3  ?  'FzCommands'    : 'fc'
cnorea <expr>  fl    getcmdtype() is# ':'  && getcmdpos() == 3  ?  'FzLines'       : 'fl'
cnorea <expr>  fs    getcmdtype() is# ':'  && getcmdpos() == 3  ?  'FzLocate'      : 'fs'
"              │
"              └ `fl` is already taken for `:FzLines`
"                besides, we can use this mnemonic: in `fs`, `s` is for ’_s_earch’.

cnorea <expr>  ucs   getcmdtype() is# ':' && getcmdpos() == 4  ? 'UnicodeSearch'  : 'ucs'

" Autocmds {{{1

" Do NOT write a bar after a backslash  on an empty line: it would result in
" 2 consecutive bars (empty command). This would print a line of a buffer on
" the command-line, when we change the focused window for the first time.
au CmdlineEnter : ++once sil! call cmdline#auto_uppercase()
    \ |           sil! call cmdline#remember(s:overlooked_commands)
    \ |           unlet! s:overlooked_commands

augroup my_cmdline_chain
    au!
    " Automatically execute  command B when A  has just been executed  (chain of
    " commands). Inspiration:
    " https://gist.github.com/romainl/047aca21e338df7ccf771f96858edb86
    au CmdlineLeave : call cmdline#chain()

    " TODO:
    " The following autocmds are not  handled by `cmdline#chain()`, because they
    " don't execute simple Ex commands.
    " Still, it's a bit  weird to have an autocmd handling  simple commands (+ 2
    " less simple), and a bunch of  other related autocmds handling more complex
    " commands.
    "
    " Try to find a way to consolidate all cases in `cmdline#chain()`.
    " Refactor it, so that when it handles complex commands, the code is readable.
    " No long: `if ... | then ... | elseif ... | ... | elseif ... | ...`.

    " We use a timer to avoid reenabling the editing commands before having left
    " the command-line completely; otherwise `E501`.
    au CmdlineLeave : if getcmdline() =~# '^\s*vi\%[sual]\s*$'
                  \ |     call timer_start(0, {_ -> execute('ToggleEditingCommands 1')})
                  \ | endif

    " sometimes, we type `:h functionz)` instead of `:h function()`
    au CmdlineLeave : if getcmdline() =~# '\C^h\%[elp]\s\+\S\+z)\s*$'
                  \ |     call cmdline#fix_typo('z')
                  \ | endif

    " when we copy a line of vimscript and paste it on the command-line,
    " sometimes the newline gets copied and translated into a literal CR,
    " which raises an error; remove it.
    au CmdlineLeave : if getcmdline() =~# '\r$'
                  \ |     call cmdline#fix_typo('cr')
                  \ | endif
augroup END

" Command {{{1

" Purpose:{{{
" We have several custom mappings in command-line mode.
" Some of them are bound to custom functions.
" They interfere / add noise / bug (`CR`) when we're in debug or Ex mode.
" We install this command so that it can  be used to toggle them when needed, in
" other plugins or in our vimrc.
"}}}
" Usage:{{{
"         ToggleEditingCommands 0  →  disable
"         ToggleEditingCommands 1  →  enable
"}}}
com -bar -nargs=1 ToggleEditingCommands call cmdline#toggle_editing_commands(<args>)

" Mappings {{{1

" Purpose:{{{
"
" By default,  when you search  for a  pattern, C-g and  C-t allow you  to cycle
" through all the matches, without leaving the command-line.
" We remap these commands to Tab and S-Tab on the search command-line.

" Also, on the Ex command-line (:), Tab can expand wildcards.
" But sometimes there are  too many suggestions, and we want to  get back to the
" command-line prior to the expansion, and refine the wildcards.
" We use  our Tab mapping  to save the command-line  prior to an  expansion, and
" install a C-q mapping to restore it.
"}}}
cno <expr><unique> <tab>   cmdline#tab#custom(1)
cno <expr><unique> <s-tab> cmdline#tab#custom(0)
cno       <unique> <c-q>   <c-\>e cmdline#tab#restore_cmdline_after_expansion()<cr>

" In vim-readline, we remap `i_C-a` to a readline motion.
" Here, we restore the default `C-a` command (`:h i^a`) by mapping it to `C-x C-a`.
ino <expr><unique> <c-x><c-a> cmdline#unexpand#save_oldcmdline('<c-a>', getcmdline())

" Same thing with the default `c_C-a` (`:h c^a`).
cno <expr><unique> <c-x><c-a> cmdline#unexpand#save_oldcmdline('<c-a>', getcmdline())

" `c_C-a` dumps all the matches on the command-line; let's define a custom `C-x C-d`
" to capture all of them in the unnamed register.
cno <expr><unique> <c-x><c-d>
    \ '<c-a>'..timer_start(0, {_ -> setreg('"', getcmdline(), 'l') + feedkeys('<c-c>', 'in') })[-1]

" Prevent the function from returning anything if we are not in the pattern field of `:vim`.
" The following mapping transforms the command-line in 2 ways, depending on where we press it:{{{
"
"    - on the search command-line, it translates the pattern so that:
"
"        - it's searched outside comments
"
"        - all alphabetical characters are replaced with their corresponding
"        equivalence class
"
"    - on the Ex command-line, if the latter contains a substitution command,
"      inside the pattern, it captures the words written in snake case or
"      camel case inside parentheses, so that we can refer to them easily
"      with backref in the replacement.
"}}}
cno <expr><unique> <c-s> cmdline#transform#main()

" Cycle through a set of arbitrary commands.
cno <unique> <c-g> <c-\>e cmdline#cycle#main#move(1)<cr>
cno <unique> <m-g> <c-\>e cmdline#cycle#main#move(0)<cr>

xno <unique> <c-g>s :s///g<left><left><left>

fu s:cycles_set() abort
    " populate the arglist with:
    "
    "    - all the files in a directory
    "    - all the files in the output of a shell command
    call cmdline#cycle#main#set('a',
        \ 'sp <bar> args `=filter(glob(''§./**/*'', 0, 1), {_,v -> filereadable(v)})`',
        \ 'sp <bar> sil args `=systemlist(''§'')`')

    "                            ┌ definition
    "                            │
    call cmdline#cycle#main#set('d',
        \ 'Verb nno §',
        \ 'Verb com §',
        \ 'Verb au §',
        \ 'Verb au * <buffer=§>',
        \ 'Verb fu §',
        \ 'Verb fu {''<lambda>§''}')

    call cmdline#cycle#main#set('ee',
        \ 'tabe ~/.vim/vimrc§',
        \ 'e ~/.vim/vimrc§',
        \ 'sp ~/.vim/vimrc§',
        \ 'vs ~/.vim/vimrc§')

    call cmdline#cycle#main#set('em',
        \ 'tabe /tmp/vimrc§',
        \ 'tabe /tmp/vim.vim§')

    " search a file in:{{{
    "
    "    - the working directory
    "    - ~/.vim
    "    - the directory of the current buffer
    "}}}
    call cmdline#cycle#main#set('ef',
        \ 'fin ~/.vim/**/*§',
        \ 'fin *§',
        \ 'fin %:h/**/*§')
    " Why `fin *§`, and not `fin **/*§`?{{{
    "
    " 1. It's useless to add `**` because we already included it inside 'path'.
    "    And `:find` searches in all paths of 'path'.
    "    So, it will use `**` as a prefix.
    "
    " 2. If we used `fin **/*§`, the path of the matches would be relative to
    "    the working directory.
    "    It's too verbose. We just need their name.
    "
    "     Btw, you may wonder what happens when we type `:fin *bar` and press Tab or
    "    C-d,  while  there  are two  files  with  the  same  name `foobar`  in  two
    "    directories in the working directory.
    "
    "     The answer is  simple: for each match, Vim prepends  the previous path
    "    component to  remove the ambiguity. If it's  not enough, it goes  on adding
    "    path components until it's not needed anymore.
    "}}}
    call cmdline#cycle#main#set('es',
        \ 'sf ~/.vim/**/*§',
        \ 'sf *§',
        \ 'sf %:h/**/*§')
    call cmdline#cycle#main#set('ev',
        \ 'vert sf ~/.vim/**/*§',
        \ 'vert sf *§',
        \ 'vert sf %:h/**/*§')
    call cmdline#cycle#main#set('et',
        \ 'tabf ~/.vim/**/*§',
        \ 'tabf *§',
        \ 'tabf %:h/**/*§')

    " `:filter` doesn't support all commands.
    " We install a  wrapper command which emulates `:filter` for  the commands which
    " are not supported.
    call cmdline#cycle#filter#install()

    " populate the qfl with the output of a shell command
    call cmdline#cycle#main#set('g',
    \ 'cgete system("rg 2>/dev/null -LS --vimgrep ''§''")',
    \ 'lgete system("rg 2>/dev/null -LS --vimgrep ''§''")',
    \ )

    " we want a different pattern depending on the filetype
    " we want `:vimgrep` to be run asynchronously
    call cmdline#cycle#vimgrep#install()

    call cmdline#cycle#main#set('p', 'put =execute(''§'')')

    " When should I prefer this over `:WebPageRead`?{{{
    "
    " When you need to download code, or when you want to save the text in a file.
    "
    " Indeed, the buffer created by `:WebPageRead`  is not associated to a file,
    " so you can't save it.
    " I you want to save it, you need to yank the text and paste it in another buffer.
    "
    " Besides, the text  is formatted to not go beyond  100 characters per line,
    " which could break some long line of code.
    "}}}
    call cmdline#cycle#main#set('r', 'exe ''r !curl -s ''..shellescape(''§'', 1)')
    "                                                │
    "                                                └ don't show progress meter, nor error messages

    " we may want a different substitution in  a qf buffer (if the `context` key
    " of the qfl is a dictionary with a `populate` key)
    call cmdline#cycle#substitute#install()
endfu

sil! call s:cycles_set()

" Variable {{{1

" Commented because the messages are annoying.
" I keep it for educational purpose.
"
"     let s:overlooked_commands = [
"         \ {'old': 'vs\%[plit]', 'new': 'C-w v', 'regex': 1},
"         \ {'old': 'sp\%[lit]' , 'new': 'C-w s', 'regex': 1},
"         \ {'old': 'q!'        , 'new': 'ZQ'   , 'regex': 0},
"         \ {'old': 'x'         , 'new': 'ZZ'   , 'regex': 0},
"         \ ]

const s:overlooked_commands = []

