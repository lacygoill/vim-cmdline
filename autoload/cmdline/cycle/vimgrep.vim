" Interface {{{1

" Where did you get the inspiration for this `:Vim` command?{{{
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
    let tempfile = tempname()
    let cmd = printf('%s %s %s %s',
        \ $HOME.'/bin/vimgrep.sh ',
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
    exe (a:in_loclist ? 'l' : 'c').'getfile '.a:tempfile
    cw
endfu
" }}}1
" Utilities {{{1
fu! s:snr() "{{{2
    return matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_')
endfu

