" Interface {{{1
fu! cmdline#cycle#vimgrep#install() abort "{{{2
    call cmdline#cycle#main#set('v',
        \ 'noa vim /@/gj ./**/*.<c-r>=expand("%:e")<cr> <bar> cw',
        \ 'noa vim /@/gj <c-r>='.s:snr().'filetype_specific_vimgrep()<cr> <bar> cw',
        \ 'noa vim /@/gj $VIMRUNTIME/**/*.vim <bar> cw',
        \ 'noa vim /@/gj ## <bar> cw',
        \ 'noa vim /@/gj `find . -type f -cmin -60` <bar> cw',
        \ 'noa lvim /@/gj % <bar> lw',
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
" }}}1
" Utilities {{{1
fu! s:snr() "{{{2
    return matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_')
endfu

