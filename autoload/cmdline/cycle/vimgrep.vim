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
" https://github.com/mhinz/vim-grepper/issues/5#issuecomment-260379947
"}}}
com -nargs=* -complete=file Vim call s:vimgrep(<q-args>, 0)
com -nargs=* -complete=file Lvim call s:vimgrep(<q-args>, 1)

fu cmdline#cycle#vimgrep#install() abort
    " Why don't you add `<bar> cw` in your mappings?{{{
    "
    " `:Vim` is a custom command, which isn't defined with `-bar`.
    " So, if it sees  `| cw`, it will wrongly interpret it as  being part of its
    " argument.
    " We don't  define `:Vim`  with `-bar`  because we  may need  to look  for a
    " pattern which contains a bar.
    "}}}
    call cmdline#cycle#main#set('v',
        \ 'vim /§/gj ./**/*.<c-r>='..s:snr..'get_extension()<cr>',
        \ 'vim /§/gj <c-r>='..s:snr..'filetype_specific_vimgrep()<cr>',
        \ 'vim /§/gj $VIMRUNTIME/**/*.vim',
        \ 'vim /§/gj ##',
        \ 'vim /§/gj `find . -type f -cmin -60`',
        \ 'lvim /§/gj %',
        \ )
    " TODO: We use the  default `:[l]vim` commands until we  review/fix the code
    " implementing `:[L]Vim`. Once it's done, uppercase the `:[l]vim` again.
endfu
" }}}1
" Core {{{1
fu s:filetype_specific_vimgrep() abort "{{{2
    if &ft is# 'zsh'
        return '/usr/local/share/zsh/**'
    elseif &ft =~# '^\%(bash\|sh\)$'
        " TODO: Remove `~/.shrc` once we've integrated it into `~/.zshrc`.
        return  '~/bin/**/*'
            \ ..' ~/.{shrc,bashrc,zshrc,zshenv}'
            \ ..' ~/.vim/plugged/vim-snippets/UltiSnips/sh.snippets'
    else
        " TODO: Once you start writing unit tests, add them.
        " For example, if you use the vader plugin, add `\ ..' ~/.vim/**/*.vader'`.
        return  ' $MYVIMRC'
            \ ..' ~/.vim/**/*.vim'
            \ ..' ~/.vim/**/*.snippets'
            \ ..' ~/.vim/template/**'
    endif
endfu

fu s:vimgrep(args, in_loclist) abort "{{{2
    let tempfile = tempname()

    " Why do you modify the arguments?{{{
    "
    " If we didn't provide a pattern (`:Vim // files`), the new Vim process will
    " replace it with the contents of its search register.
    " But there's no  guarantee that the search register of  this Vim process is
    " identical to the one of our current Vim process.
    "
    " Same thing for `%` and `##`.
    "}}}
    let args = s:get_modified_args(a:args)

    " Why do you write the arguments in a file?  Why not passing them as arguments to `write_matches()`?{{{
    "
    " They could contain some quotes.
    " When that happens, I have no idea how to protect them.
    "}}}
    call writefile([args], tempfile, 's')

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
    let cmd = [
        \ '/bin/bash', '-c',
        \ ..'vim -Nu NONE -i NONE'
        \ ..' --cmd "set rtp^=~/.vim/plugged/vim-cmdline"'
        \ ..' --cmd "set wig='..&wig..' su='..&suffixes..' ic='..&ic..' scs='..&scs..'"'
        \ ..' -es'
        \ ..' +'..shellescape('cd '..getcwd())
        \ ..' +''call cmdline#cycle#vimgrep#write_matches()'''
        \ ..' +qa! '
        \ ..tempfile
        \ ]
    let title = (a:in_loclist ? ':Lvim ' : ':Vim ')..args
    call job_start(cmd, {'exit_cb': function('s:callback', [a:in_loclist, tempfile, title])})
endfu

fu cmdline#cycle#vimgrep#write_matches() abort "{{{2
    let tempfile = expand('%:p')
    let args = readfile(tempfile)
    if empty(args)
        return
    endif
    exe 'noa vim '..args[0]
    let matches = map(getqflist(),
        \ {_,v -> printf('%s:%d:%d:%s', fnamemodify(bufname(v.bufnr), ':p'), v.lnum, v.col, v.text)})
    call writefile(matches, tempfile, 's')
endfu

fu s:callback(in_loclist, tempfile, title, ...) abort "{{{2
"                                          │
"                                          └ the callback receives 2 arguments{{{
"
" From `:h job-exit_cb`:
"
" >     The arguments are the job and the exit status.
"}}}
    if a:in_loclist
        exe 'lgetfile '..a:tempfile
        lw
        call setloclist(0, [], 'a', {'title': a:title})
    else
        exe 'cgetfile '..a:tempfile
        cw
        call setqflist([], 'a', {'title': a:title})
    endif
    " If you were moving in a buffer  while the callback is invoked and open the
    " qf window, some stray characters may be printed in the status line.
    redraw!
endfu
" }}}1
" Utilities {{{1
fu s:get_extension() abort "{{{2
    let ext = expand('%:e')
    if &ft is# 'dirvish' && expand('%:p') =~? '/wiki/'
        let ext = 'md'
    elseif &ft is# 'dirvish' && expand('%:p') =~? '/.vim/'
        let ext = 'vim'
    elseif ext is# '' && bufname('%') isnot# ''
        let ext = split(execute('au'), '\n')
        call filter(ext, {_,v -> v =~# 'setf\s\+'..&ft})
        let ext = matchstr(get(ext, 0, ''), '\*\.\zs\S\+')
    endif
    return ext
endfu

fu s:get_modified_args(args) abort "{{{2
    let pat = '^\(\i\@!.\)\1\ze[gj]\{,2}\s\+'
    "           ├──────────┘
    "           └ 2 consecutive and identical non-identifier characters
    let rep = '/'..escape(@/, '\/')..'/'
    "                          │{{{
    "                          └ `substitute()` will remove any backslash, because
    "                             some sequences are special (like `\1` or `\u`);
    "                             See: :h sub-replace-special
    "
    "                             If our pattern contains a backslash (like in `\s`),
    "                             we need it to be preserved.
    "}}}
    let args = substitute(a:args, pat, rep, '')

    let args = substitute(args, '\s\+\zs%\s*$', fnameescape(expand('%:p')), '')
    let args = substitute(args, '\s\+\zs##\s*$', join(map(argv(),
        \ {_,v -> fnameescape(fnamemodify(v,':p'))})), '')
    return args
endfu

fu s:snr() "{{{2
    return matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_')
endfu
let s:snr = get(s:, 'snr', s:snr())

