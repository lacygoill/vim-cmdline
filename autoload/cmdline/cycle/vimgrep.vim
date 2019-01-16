if exists('g:autoloaded_cmdline#cycle#vimgrep')
    finish
endif
let g:autoloaded_cmdline#cycle#vimgrep = 1

" Interface {{{1

" Why a wrapper command around `:[l]vim`?{{{
"
" To make it async.
"}}}
" Where did you get the inspiration?{{{
"
"     https://github.com/mhinz/vim-grepper/issues/5#issuecomment-260379947
"}}}
com! -nargs=* Vim call s:vimgrep(<q-args>, 0)
com! -nargs=* Lvim call s:vimgrep(<q-args>, 1)

fu! cmdline#cycle#vimgrep#install() abort
    call cmdline#cycle#main#set('v',
        \ 'noa Vim /@/gj ./**/*.<c-r>=expand("%:e")<cr> <bar> cw',
        \ 'noa Vim /@/gj <c-r>='.s:snr().'filetype_specific_vimgrep()<cr> <bar> cw',
        \ 'noa Vim /@/gj $VIMRUNTIME/**/*.vim <bar> cw',
        \ 'noa Vim /@/gj ## <bar> cw',
        \ 'noa Vim /@/gj `find . -type f -cmin -60` <bar> cw',
        \ 'noa Lvim /@/gj % <bar> lw',
        \ )
endfu
" }}}1
" Core {{{1
fu! s:filetype_specific_vimgrep() abort "{{{2
    if &ft is# 'zsh'
        return '/usr/share/zsh/**'
    elseif &ft =~# '^\%(bash\|sh\)$'
        " TODO: Remove `~/.shrc` once we've integrated this file into `~/.zshrc`.
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

fu! s:vimgrep(args, in_loclist) abort "{{{2
    let tempfile = tempname()
    let title = (a:in_loclist ? ':Lvim ' : ':Vim ').a:args
    " Why do you write the arguments in a file?  Why not passing them as arguments to `write_matches()`?{{{
    "
    " They could contain some quotes.
    " When that happens, I have no idea how to protect them.
    "}}}
    call writefile([a:args], tempfile, 's')
    " Why don't you start Vim directly?  Why start a new shell?{{{
    "
    " A (Neo)Vim job started directly from a Vim instance doesn't work as expected:
    "
    "     $ vim
    "     :let job = job_start('vim +''call writefile(["test"], "/tmp/log")'' +qa!')
    "     " wait a few seconds
    "     :echo job
    "     process 1234 dead~
    "     :!cat /tmp/log
    "     ∅
    "     ✘
    "
    " If we start (Neo)Vim from a shell, the issue disappears.
    "
    "     :let job = job_start(['/bin/bash', '-c', 'vim +''call writefile(["test"], "/tmp/log")'' +qa!'])
    "}}}
    " Why do you call `write_matches()`?{{{
    "
    " To get a  file which the callback will be able  to parse with `:cgetfile`,
    " and get back the qfl.
    "}}}
    " TODO: We should write `has('nvim') ? 'nvim' : 'vim'` instead of `vim`.{{{
    "
    " We don't, because for some reason a Neovim job started from Neovim doesn't exit.
    "
    "     $ nvim
    "     :call jobstart('nvim +''call writefile(["test"], "/tmp/log", "s")'' +qa!')
    "     ✘               ^
    "
    " The job is in an interruptible sleep:
    "
    "     :let job = jobstart('nvim +''call writefile(["test"], "/tmp/log", "s")'' +qa!')
    "     :exe '!ps aux | grep '.jobpid(job)
    "     user  1234  ... Ss  ...  nvim +call writefile(["test"], "/tmp/log") +qa!~
    "                     ^✘
    "
    " The issue disappears if we start a Vim job:
    "
    "     $ nvim
    "     :call jobstart('vim +''call writefile(["test"], "/tmp/log")'' +qa!')
    "     ✔               ^
    "}}}
    let cmd = [
    \ '/bin/bash', '-c',
    \  'vim'
    \ . ' +''call cmdline#cycle#vimgrep#write_matches()'''
    \ . ' +qa! '
    \ . tempfile
    \ ]
    let title = (a:in_loclist ? ':Lvim ' : ':Vim ').a:args
    if has('nvim')
        call jobstart(cmd,
        \ {'on_exit': function('s:handler', [a:in_loclist, tempfile, title])})
    else
        call job_start(cmd,
        \ {'exit_cb': function('s:handler', [a:in_loclist, tempfile, title])})
    endif
endfu

fu! cmdline#cycle#vimgrep#write_matches() abort "{{{2
    let args = readfile(expand('%:p'))
    if empty(args)
        return
    endif
    exe 'noa vim '.args[0]
    let matches = map(getqflist(),
        \ {i,v -> printf('%s:%d:%d:%s', bufname(v.bufnr), v.lnum, v.col, v.text)})
    call writefile(matches, expand('%:p'))
endfu

fu! s:handler(in_loclist, tempfile, title, ...) abort "{{{2
"                                          │
"                                          └ the handler doesn't receive the same number of arguments{{{
"                                            in Vim and Neovim
"
" In Vim, it receives 2 arguments.
" From `:h job-exit_cb`:
"
" > The arguments are the job and the exit status.
"
" In Neovim, it receives 3 arguments: `job_id`, `data` and `event`.
" See `:h job-control-usage`
"}}}
    exe (a:in_loclist ? 'l' : 'c').'getfile '.a:tempfile
    cw
    call setqflist([], 'a', {'title': a:title})
    " If you were moving in a buffer  while the callback is invoked and open the
    " qf window, some stray characters may be printed in the status line.
    redraw!
endfu
" }}}1
" Utilities {{{1
fu! s:snr() "{{{2
    return matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_')
endfu

