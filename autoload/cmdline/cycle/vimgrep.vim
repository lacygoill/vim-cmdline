vim9script noclear

# Interface {{{1

# Why a wrapper command around `:[l]vim`?{{{
#
# To make it async.
#}}}
# Where did you get the inspiration?{{{
#
# https://github.com/mhinz/vim-grepper/issues/5#issuecomment-260379947
#}}}
# Do *not* give the attribute `-complete=file` to your commands!{{{
#
# It would cause Vim to expand `%` and `#` (possibly others) into the current or
# alternate filename.   This is especially  troublesome for `\%` which  is often
# used  in  regexes,  because  the  backslash would  be  removed  (it  would  be
# interpreted as meaning: "take the following special character as a literal one").
#
#     command -nargs=* -complete=file Cmd echomsg <q-args>
#     Cmd a\%b
#     a%b˜
#}}}
command -nargs=* Vim Vimgrep(<q-args>)
command -nargs=* Lvim Vimgrep(<q-args>, true)

def cmdline#cycle#vimgrep#install()
    # Why don't you add `<Bar> cwindow` in your mappings?{{{
    #
    # `:Vim` is a custom command, which isn't defined with `-bar`.
    # So, if it sees `| cwindow`, it  will wrongly interpret it as being part of
    # its argument.
    # We don't  define `:Vim` with  `-bar` because we might  need to look  for a
    # pattern which contains a bar.
    #}}}
    cmdline#cycle#main#set('v',
        'Vim /§/gj ./**/*.<C-R>=' .. expand('<SID>') .. 'GetExtension()<CR>',
        'Vim /§/gj <C-R>=' .. expand('<SID>') .. 'FiletypeSpecificVimgrep()<CR>',
        'Vim /§/gj $VIMRUNTIME/**/*.vim',
        'Vim /§/gj ##',
        'Vim /§/gj `find . -type f -cmin -60`',
        'Lvim /§/gj %',
    )
enddef
# }}}1
# Core {{{1
def FiletypeSpecificVimgrep(): string #{{{2
    if &filetype == 'dirvish'
        return expand('%:p') .. '**'
    elseif &filetype == 'zsh'
        return '/usr/local/share/zsh/**'
    elseif &filetype =~ '^\%(bash\|sh\)$'
        # TODO: Remove `~/.shrc` once we've integrated it into `~/.zshrc`.
        return  '~/bin/**/*'
            .. ' ~/.{shrc,bashrc,zshrc,zshenv}'
            .. ' ~/.vim/pack/mine/opt/snippets/UltiSnips/sh.snippets'
    else
        # TODO: Once you start writing unit tests, add them.
        # For example, if you use the vader plugin, add `\ .. ' ~/.vim/**/*.vader'`.
        return  '$MYVIMRC'
            .. ' ~/.vim/**/*.vim'
            .. ' ~/.vim/**/*.snippets'
            .. ' ~/.vim/template/**'
    endif
enddef

def Vimgrep(args: string, loclist = false) #{{{2
    var tempvimrc: string = tempname()
    var tempqfl: string = tempname()

    var get_tempfile: list<string> =<< trim END
        var tempqfl: string = expand('%:p')
        if tempqfl !~ '^/tmp/'
            finish
        endif
    END
    # Why do you write the arguments in a file?  Why not passing them as arguments to `vim(1)`?{{{
    #
    # They could contain some quotes.
    # When that happens, I have no idea how to protect them.
    #}}}
    var cdcmd: string = 'cd ' .. getcwd()->fnameescape()
    # Don't we need to also pass `$MYVIMRC`?{{{
    #
    # No.  Apparently, a Vim job inherits the environment of the current Vim instance.
    #
    #     $ENVVAR = 'some environment variable'
    #     job_start([
    #         '/bin/bash',
    #         '-c',
    #         'vim -Nu NONE +''call writefile([$ENVVAR], "/tmp/somefile")'' +quitall!'
    #     ])
    #     echo readfile('/tmp/somefile')
    #     ['some environment variable']˜
    #}}}
    var setcmd: string = printf('set wildignore=%s suffixes=%s %signorecase %ssmartcase',
        &wildignore, &suffixes, &ignorecase ? '' : 'no', &smartcase ? '' : 'no')
    # Why do you expand the arguments?{{{
    #
    # If we didn't provide a pattern (`:Vim // files`), the new Vim process will
    # replace it with the contents of its search register.
    # But there's no  guarantee that the search register of  this Vim process is
    # identical to the one of our current Vim process.
    #
    # Same thing for `%` and `##`.
    #}}}
    var expanded_args: string = Expandargs(args)
    var vimgrepcmd: string = 'noautocmd vimgrep ' .. expanded_args
    # Why `strtrans()`?{{{
    #
    # If the text contains NULs, it could mess up the parsing of `:cgetfile`.
    # Maybe other control characters could cause similar issues.
    #
    # Let's play it  safe; we don't need special characters  to be preserved; we
    # just need to be able to read  them; anything which is not printable should
    # be made printable.
    #}}}
    var getqfl: list<string> =<< trim END
        getqflist()
           ->mapnew((_, v: dict<any>): string => printf('%s:%d:%d:%s',
               bufname(v.bufnr)->fnamemodify(':p'),
               v.lnum,
               v.col,
               v.text->substitute('[^[:print:]]', (m: list<string>): string => strtrans(m[0]), 'g')))
           ->writefile(tempqfl, 's')
        quitall!
    END
    # Make sure that the code contained in `get_tempfile` is run before `vimgrepcmd`{{{
    #
    # `:vimgrep` could  change the current file;  you could also try  to use the
    # `j` flag  unconditionally in the  second Vim instance where  `:vimgrep` is
    # run, but better be safe.
    #}}}
    writefile(['vim9script noclear']
        + get_tempfile
        + [cdcmd, setcmd, vimgrepcmd]
        + getqfl,
        tempvimrc, 's')

    var vimcmd: string = printf('vim -es -Nu NONE -U NONE -i NONE -S %s %s', tempvimrc, tempqfl)
    var title: string = (loclist ? ':Lvim ' : ':Vim ') .. expanded_args
    var arglist: list<any> = [loclist, tempqfl, title]
    var opts: dict<func> = {exit_cb: function(Callback, arglist)}
    split(vimcmd)->job_start(opts)
enddef

def Callback( #{{{2
    loclist: bool,
    tempqfl: string,
    title: string,
    _: job,
    exit: number
)

    if exit != 0
        var pat: string = title[1 :]->matchstr('\(\i\@!\S\)\zs.\{-}\ze\1')
        echohl ErrorMsg
        echomsg 'E480: No match: ' .. pat
        echohl NONE
        return
    endif

    var errorformat_save: string = &l:errorformat
    var bufnr: number = bufnr('%')
    try
        &l:errorformat = '%f:%l:%c:%m'
        if loclist
            execute 'lgetfile ' .. tempqfl
            lwindow
            setloclist(0, [], 'a', {title: title})
        else
            execute 'cgetfile ' .. tempqfl
            cwindow
            setqflist([], 'a', {title: title})
        endif
    finally
        setbufvar(bufnr, '&errorformat', errorformat_save)
    endtry
    # If you were moving in a buffer  while the callback is invoked and open the
    # qf window, some stray characters might be printed in the status line.
    redraw!
enddef
# }}}1
# Utilities {{{1
def GetExtension(): string #{{{2
    var ext: string = expand('%:e')
    if &filetype == 'dirvish' && expand('%:p') =~ '\c/wiki/'
        ext = 'md'
    elseif &filetype == 'dirvish' && expand('%:p') =~ '\c/.vim/'
        ext = 'vim'
    elseif ext == '' && bufname() != ''
        var setf_autocmds: list<string> = execute('autocmd')
            ->split('\n')
            ->filter((_, v: string): bool => v =~ 'setf\%[iletype]\s\+' .. &filetype)
        ext = get(setf_autocmds, 0, '')->matchstr('\*\.\zs\S\+')
    endif
    return ext
enddef

def Expandargs(args: string): string #{{{2
    var pat: string = '^\(\i\@!.\)\1\ze[gj]\{,2}\s\+'
    #                   ├──────────┘
    #                   └ 2 consecutive and identical non-identifier characters
    var rep: string = '/' .. escape(@/, '\/') .. '/'
    #                                    │{{{
    #                                    └ `substitute()` will remove any backslash, because
    #                                       some sequences are special (like `\1` or `\u`);
    #                                       See: :help sub-replace-special
    #
    #                                       If our pattern contains a backslash (like in `\s`),
    #                                       we need it to be preserved.
    #}}}

    # expand `//` into `/last search/`
    return args
        ->substitute(pat, rep, '')
        # expand `%` into `current_file`
        ->substitute('\s\+\zs%\s*$', expand('%:p')->fnameescape(), '')
        # expand `##` into `files_in_arglist`
        ->substitute(
            '\s\+\zs##\s*$',
            argv()
                ->map((_, v: string) => v->fnamemodify(':p')->fnameescape())
                ->join(),
            '')
enddef

