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
"                 exe printf("cnorea <expr> %s getcmdtype() is# ':' ? '%s' : '%s'", l:lhs, l:rhs, l:lhs)
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
cnorea <expr>  soù   getcmdtype() =~# ':' && getcmdpos() ==# 4 ? 'so%' : 'soù'


cnorea <expr>  sl    getcmdtype() is# ':' && getcmdpos() ==# 3  ? 'ls'             : 'sl'
cnorea <expr>  hg    getcmdtype() is# ':' && getcmdpos() ==# 3  ? 'helpgrep'       : 'hg'
cnorea <expr>  dig   getcmdtype() is# ':' && getcmdpos() ==# 4  ? 'verb Digraphs!' : 'dig'
cnorea <expr>  ecoh  getcmdtype() is# ':' && getcmdpos() ==# 5  ? 'echo'           : 'ecoh'

"         :fbl
"         :FzBLines~
"         :fc
"         :FzCommands~
"         :fl
"         :FzLines~
"         :fs
"         :FzLocate~
cnorea <expr>  fbl   getcmdtype() is# ':'  && getcmdpos() ==# 4  ?  'FzBLines'      : 'fbl'
cnorea <expr>  fc    getcmdtype() is# ':'  && getcmdpos() ==# 3  ?  'FzCommands'    : 'fc'
cnorea <expr>  fl    getcmdtype() is# ':'  && getcmdpos() ==# 3  ?  'FzLines'       : 'fl'
cnorea <expr>  fs    getcmdtype() is# ':'  && getcmdpos() ==# 3  ?  'FzLocate'      : 'fs'
"              │
"              └─ `fl` is already taken for `:FzLines`
"                 besides, we can use this mnemonic: in `fs`, `s` is for ’_s_earch’.

cnorea <expr>  ucs   getcmdtype() is# ':' && getcmdpos() ==# 4  ? 'UnicodeSearch'  : 'ucs'

"     :pc
"     :sil! PlugClean~
cnorea <expr>  pc    getcmdtype() is# ':'  && getcmdpos() ==# 3  ? 'sil! PlugClean' : 'pc'

" Autocmds {{{1

augroup my_lazy_loaded_cmdline
    au!
    " Do NOT write a bar after a backslash  on an empty line: it would result in
    " 2 consecutive bars (empty command). This would print a line of a buffer on
    " the command-line, when we change the focused window for the first time.
    au CmdlineEnter : call cmdline#auto_uppercase()
    \
    \ |               call cmdline#remember(s:overlooked_commands)
    \ |               unlet! s:overlooked_commands
    \
    \ |               call cmdline#cycle#pass(s:cycles)
    \ |               unlet! s:cycles
    \
    \ |               exe 'au! my_lazy_loaded_cmdline'
    \ |               aug! my_lazy_loaded_cmdline
augroup END

augroup my_cmdline_chain
    au!
    " Automatically execute  command B when A  has just been executed  (chain of
    " commands). Inspiration:
    "         https://gist.github.com/romainl/047aca21e338df7ccf771f96858edb86
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
                  \ |     call timer_start(0, {-> execute('ToggleEditingCommands 1')})
                  \ | endif

    " enable the  item in  the statusline  showing our  position in  the arglist
    " after we execute an `:args` command
    au CmdlineLeave : if getcmdline() =~# '\C^\%(tab\s\+\)\=ar\%[gs]\s+'
                  \ |     call timer_start(0, {-> execute('let g:my_stl_list_position = 2 | redraw!')})
                  \ | endif

    " sometimes, we type `:h functionz)` instead of `:h function()`
    au CmdlineLeave : if getcmdline() =~# '\C^h\%[elp]\s\+\S\+z)\s*$'
                  \ |     call cmdline#fix_typo('z')
                  \ | endif

    " when we copy a line of vimscript and paste it on the command-line,
    " sometimes the newline gets copied and translated into a literal CR,
    " which raises an error:    remove it
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
com! -bar -nargs=1 ToggleEditingCommands call cmdline#toggle_editing_commands(<args>)

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
cno  <expr>  <tab>    cmdline#tab#custom(1)
cno  <expr>  <s-tab>  cmdline#tab#custom(0)
cno          <c-q>    <c-\>ecmdline#tab#restore_cmdline_after_expansion()<cr>

" The following mapping transforms the command-line in 2 ways, depending on where we press it:{{{
"
"    • on the search command-line, it translates the pattern so that:
"
"        - it's searched outside comments
"
"        - all alphabetical characters are replaced with their corresponding
"        equivalence class
"
"    • on the Ex command-line, if the latter contains a substitution command,
"      inside the pattern, it captures the words written in snake case or
"      camel case inside parentheses, so that we can refer to them easily
"      with backref in the replacement.
"}}}
cno  <expr><unique>  <c-s>  cmdline#transform#main()

" Cycle through a set of arbitrary commands.
cno  <unique>  <c-g>  <c-\>ecmdline#cycle#move(1)<cr>
cno  <unique>  <m-g>  <c-\>ecmdline#cycle#move(0)<cr>

xno  <unique>  <c-g>s  :s///g<left><left><left>

"   ┌ need  this variable to  pass the commands that  are in each  cycle we're
"   │ going to configure, to the `autoload/`  script, where the bulk of the code
"   │ installing cycles reside
"   │
let s:cycles = []
fu! s:cycle_configure(seq, ...) abort
    let cmds = a:000
    exe 'nno  <unique>  <c-g>'.a:seq
        \ . ' :<c-u><c-r>=cmdline#cycle#set_seq('.string(a:seq).')<cr>'
        \ . substitute(a:1, '@', '', '')
        \ .   '<c-b>'.repeat('<right>', stridx(cmds[0], '@'))
    let s:cycles += [[a:seq, cmds]]
endfu

" populate the arglist with:
"
"    • all the files in a directory
"    • all the files in the output of a shell command
call s:cycle_configure('a',
\                      'sp <bar> args `=filter(glob(''@./**/*'', 0, 1), {i,v -> filereadable(v)})` <bar> let g:my_stl_list_position = 2',
\                      'sp <bar> sil args `=systemlist(''@'')` <bar> let g:my_stl_list_position = 2')

" populate the qfl with the output of a shell command
" Why not using `:cexpr`?{{{
"
" It suffers from an issue regarding a possible pipe in the shell command.
" You have to escape it, which is  inconsistent with how a bar is interpreted by
" Vim in other contexts.
" I don't want to remember this quirk.
"}}}
call s:cycle_configure('c',
\                      'sil call system(''grep -RHIinos @ . >/tmp/.vim_cfile'') <bar> cgetfile /tmp/.vim_cfile')

"                       ┌ definition
"                       │
call s:cycle_configure('d',
\                      'Verb nno @',
\                      'Verb com @',
\                      'Verb au @',
\                      'Verb au * <buffer=@>',
\                      'Verb fu @',
\                      'Verb fu {''<lambda>@''}')

call s:cycle_configure('ee',
\                      'tabe $MYVIMRC@',
\                      'e $MYVIMRC@',
\                      'sp $MYVIMRC@',
\                      'vs $MYVIMRC@')

call s:cycle_configure('em',
\                      'tabe /tmp/vimrc@',
\                      'tabe /tmp/vim.vim@')

" search a file in:{{{
"
"         • the working directory
"         • ~/.vim
"         • the directory of the current buffer
"}}}
call s:cycle_configure('ef',
\                      'fin ~/.vim/**/*@',
\                      'fin *@',
\                      'fin %:h/**/*@')
" Why `fin *@`, and not `fin **/*@`?{{{
"
" 1. It's useless to add `**` because we already included it inside 'path'.
"    And `:find` searches in all paths of 'path'.
"    So, it will use `**` as a prefix.
"
" 2. If we used `fin **/*@`, the path of the candidates would be relative to
"    the working directory.
"    It's too verbose. We just need their name.
"
"     Btw, you may wonder what happens when we type `:fin *bar` and press Tab or
"    C-d,  while  there  are two  files  with  the  same  name `foobar`  in  two
"    directories in the working directory.
"
"     The answer is  simple: for each candidate, Vim prepends  the previous path
"    component to  remove the ambiguity. If it's  not enough, it goes  on adding
"    path components until it's not needed anymore.
"}}}

call s:cycle_configure('es',
\                      'sf ~/.vim/**/*@',
\                      'sf *@',
\                      'sf %:h/**/*@')

call s:cycle_configure('ev',
\                      'vert sf ~/.vim/**/*@',
\                      'vert sf *@',
\                      'vert sf %:h/**/*@')

call s:cycle_configure('et',
\                      'tabf ~/.vim/**/*@',
\                      'tabf *@',
\                      'tabf %:h/**/*@')

" TODO:
" `:filter` doesn't support all commands.
" Maybe we  could install a wrapper  command (`:Filter`) which would  do the job
" for the commands which are not supported.
" See `:h  :index`, and  search for  all the commands  which could  benefit from
" `:filter`:
"
"         :args
"         :autocmd
"         :augroup
"         :changes
"         :ilist (:dlist, :isearch?, :dsearch?)
"         :history
"         :reg
"         :tags

com! -bang -complete=command -nargs=+ Filter  call s:filter(<q-args>, <bang>0)
fu! s:filter(cmd, bang) abort
    let pat = matchstr(a:cmd, '/\zs.\{-}\ze/')

    let cmd = matchstr(a:cmd, '/.\{-}/\s*\zs.*')
    let first_word = matchstr(cmd, '\S*')
    if s:is_filterable(first_word)
        if pat is# ''
            exe 'filter'.(a:bang ? '!': '').' '.substitute(a:cmd, '/\zs.\{-}\ze/', @/, '')
        else
            exe 'filter'.(a:bang ? '!': '').' '.a:cmd
        endif
        return
    endif

    let output = split(execute(cmd), '\n')
    echo join(filter(output, {i,v -> a:bang ? v !~# pat : v =~# pat}), "\n")
endfu

let s:FILTERABLE_COMMANDS = [
    \ '%\=#',
    \ 'ab\%[breviate]',
    \ 'buffers',
    \ 'chi\%[story]',
    \ 'cl\%[ist]',
    \ 'com\%[mand]',
    \ 'files',
    \ 'hi\%[ghlight]',
    \ 'ju\%[mps]',
    \ 'l\%[ist]',
    \ 'let',
    \ 'lli\%[st]',
    \ 'ls',
    \ 'map',
    \ 'mes\%[sages]',
    \ 'old\%[files]',
    \ 'scr\%[iptnames]',
    \ 'se\%[t]',
    \ ]
fu! s:is_filterable(first_word) abort
    for cmd in s:FILTERABLE_COMMANDS
        if a:first_word =~# '^\C'.cmd.'$'
            return 1
        endif
    endfor
    return 0
endfu

call s:cycle_configure('f',
\                      'Verb Filter /@/ map',
\                      'Verb Filter /@/ ab',
\                      'Verb Filter /@/ %#',
\                      'Verb Filter /@/ com',
\                      'Verb Filter /@/ old',
\                      'Verb Filter /@/ chi',
\                      'Verb Filter /@/ mess',
\                      'Verb Filter /@/ scr',
\                      'Verb Filter /@/ let',
\                      'Verb Filter /@/ set',
\                      'Verb Filter /@/ hi',
\                      'Verb Filter /@/ ls')

call s:cycle_configure('p',
\                      'put =execute(''@'')')

call s:cycle_configure('s', '%s/@//g', '%s/@//gc', '%s/@//gn', '%s/`.\{-}\zs''/`/gc')

fu! s:snr()
    return matchstr(expand('<sfile>'), '<SNR>\d\+_')
endfu
fu! s:filetype_specific_vimgrep() abort
    if &ft is# 'zsh'
        return '/usr/share/zsh/**'
    elseif &ft =~# '^\%(bash\|sh\)$'
        return  '~/bin/**/*.sh'
            \ . ' ~/.shrc'
            \ . ' ~/.bashrc'
            \ . ' ~/.zshrc'
            \ . ' ~/.zshenv'
            \ . ' ~/.vim/plugged/vim-snippets/UltiSnips/sh.snippets'
    else
        return  '~/.vim/**/*.vim'
            \ . ' ~/.vim/**/*.snippets'
            \ . ' ~/.vim/template/**'
            \ . ' ~/.vim/vimrc'
    endif
endfu
call s:cycle_configure('v',
\                      'noa vim /@/gj ./**/*.<c-r>=expand("%:e")<cr> <bar> cw',
\                      'noa vim /@/gj <c-r>='.s:snr().'filetype_specific_vimgrep()<cr> <bar> cw',
\                      'noa vim /@/gj $VIMRUNTIME/**/*.vim <bar> cw',
\                      'noa vim /@/gj ## <bar> cw',
\                      'noa vim /@/gj `find . -type f -cmin -60` <bar> cw',
\                      'noa lvim /@/gj % <bar> lw',
\ )

" TODO: Remove `~/.shrc` from the last cycle once we've integrated this file into `~/.zshrc`.

" TODO: `:[l]vim[grep]` is not asynchronous.
" Add an async command (using  `&grepprg`?).
" For inspiration:
"
"     https://github.com/mhinz/vim-grepper/issues/5#issuecomment-260379947

com! -bar Redraw call cmdline#redraw()
call s:cycle_configure('!',
\                      'Redraw <bar> sil !sr wref @')

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

let s:overlooked_commands = []

