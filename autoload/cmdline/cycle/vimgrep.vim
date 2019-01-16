" Interface {{{1

" Why a wrapper command around `:[l]vim`?{{{
"
" To make it async.
"}}}
" Where did you get the inspiration?{{{
"
"     https://github.com/mhinz/vim-grepper/issues/5#issuecomment-260379947
"}}}
com! -nargs=* Vim call s:vimgrep('<args>', 0)
com! -nargs=* Lvim call s:vimgrep('<args>', 1)

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
    let script = $HOME.'/bin/vimgrep.sh'
    if !executable(script)
        echom script . ' is not executable'
        return
    endif
    let tempfile = tempname()
    let cmd = printf('%s %s %s %s',
        \ script,
        \ has('nvim') ? 'nvim' : 'vim',
        \ tempfile,
        \ a:args
        \ )
    if has('nvim')
        call jobstart(cmd, {'on_exit': function('s:handler', [a:in_loclist, tempfile])})
    else
        call job_start(cmd, {'exit_cb': function('s:handler', [a:in_loclist, tempfile])})
    endif
endfu

fu! s:handler(in_loclist, tempfile, ...) abort "{{{2
"                                   │
"                                   └ the handler doesn't receive the same number of arguments in Vim and Neovim{{{
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
endfu
" }}}1
" Utilities {{{1
fu! s:snr() "{{{2
    return matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_')
endfu

