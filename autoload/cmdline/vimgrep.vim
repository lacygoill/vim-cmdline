fu! cmdline#vimgrep#install() abort
    call cmdline#cycle#set('v',
        \ 'noa vim /@/gj ./**/*.<c-r>=expand("%:e")<cr> <bar> cw',
        \ 'noa vim /@/gj <c-r>='.s:snr().'filetype_specific_vimgrep()<cr> <bar> cw',
        \ 'noa vim /@/gj $VIMRUNTIME/**/*.vim <bar> cw',
        \ 'noa vim /@/gj ## <bar> cw',
        \ 'noa vim /@/gj `find . -type f -cmin -60` <bar> cw',
        \ 'noa lvim /@/gj % <bar> lw',
        \ )
endfu

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

