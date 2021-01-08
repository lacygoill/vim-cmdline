vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

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
#     $ vim -Nu NONE -S <(cat <<'EOF'
#         com -nargs=* -complete=file Cmd echom <q-args>
#         Cmd a\%b
#     EOF
#     )
#
#     a%b
#}}}
com -nargs=* Vim Vimgrep(<q-args>)
com -nargs=* Lvim Vimgrep(<q-args>, true)

def cmdline#cycle#vimgrep#install()
    # Why don't you add `<bar> cw` in your mappings?{{{
    #
    # `:Vim` is a custom command, which isn't defined with `-bar`.
    # So, if it sees  `| cw`, it will wrongly interpret it as  being part of its
    # argument.
    # We don't  define `:Vim` with  `-bar` because we might  need to look  for a
    # pattern which contains a bar.
    #}}}
    cmdline#cycle#main#set('v',
        'Vim /§/gj ./**/*.<c-r>=' .. expand('<SID>') .. 'GetExtension()<cr>',
        'Vim /§/gj <c-r>=' .. expand('<SID>') .. 'FiletypeSpecificVimgrep()<cr>',
        'Vim /§/gj $VIMRUNTIME/**/*.vim',
        'Vim /§/gj ##',
        'Vim /§/gj `find . -type f -cmin -60`',
        'Lvim /§/gj %',
        )
enddef
# }}}1
# Core {{{1
def FiletypeSpecificVimgrep(): string #{{{2
    if &ft == 'dirvish'
        return expand('%:p') .. '**'
    elseif &ft == 'zsh'
        return '/usr/local/share/zsh/**'
    elseif &ft =~ '^\%(bash\|sh\)$'
        # TODO: Remove `~/.shrc` once we've integrated it into `~/.zshrc`.
        return  '~/bin/**/*'
            .. ' ~/.{shrc,bashrc,zshrc,zshenv}'
            .. ' ~/.vim/plugged/vim-snippets/UltiSnips/sh.snippets'
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
    var tempvimrc = tempname()
    var tempqfl = tempname()

    var get_tempfile =<< trim END
        var tempqfl = expand('%:p')
        if tempqfl !~ '^/tmp/'
            finish
        endif
    END
    # Why do you write the arguments in a file?  Why not passing them as arguments to `vim(1)`?{{{
    #
    # They could contain some quotes.
    # When that happens, I have no idea how to protect them.
    #}}}
    var cdcmd = 'cd ' .. getcwd()->fnameescape()
    # Don't we need to also pass `$MYVIMRC`?{{{
    #
    # No.  Apparently, a Vim job inherits the environment of the current Vim instance.
    #
    #     :let $ENVVAR = 'some environment variable'
    #     :let job = job_start(['/bin/bash', '-c', 'vim -Nu NONE +''call writefile([$ENVVAR], "/tmp/somefile")'' +qa!'])
    #     :echo readfile('/tmp/somefile')
    #     ['some environment variable']~
    #}}}
    var setcmd = printf('set wildignore=%s suffixes=%s %signorecase %ssmartcase',
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
    var _args = Expandargs(args)
    var vimgrepcmd = 'noa vim ' .. _args
    # Why `strtrans()`?{{{
    #
    # If the text contains NULs, it could mess up the parsing of `:cgetfile`.
    # Maybe other control characters could cause similar issues.
    #
    # Let's play it  safe; we don't need special characters  to be preserved; we
    # just need to be able to read  them; anything which is not printable should
    # be made printable.
    #}}}
    var getqfl =<< trim END
        getqflist()
           ->map((_, v) => printf('%s:%d:%d:%s',
               bufname(v.bufnr)->fnamemodify(':p'),
               v.lnum,
               v.col,
               substitute(v.text, '[^[:print:]]', (m) => strtrans(m[0]), 'g')
               ))
           ->writefile(tempqfl, 's')
        qa!
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

    var vimcmd = printf('vim -es -Nu NONE -U NONE -i NONE -S %s %s', tempvimrc, tempqfl)
    var title = (loclist ? ':Lvim ' : ':Vim ') .. _args
    var arglist = [loclist, tempqfl, title]
    var opts = {exit_cb: function(Callback, arglist)}
    split(vimcmd)->job_start(opts)
enddef

def Callback(loclist: bool, tempqfl: string, title: string, _j: any, _e: any) #{{{2
#                                                           ├──────────────┘
#                                                           └ the callback receives 2 arguments{{{
#
# From `:h job-exit_cb`:
#
#    > The arguments are the job and the exit status.
#}}}

    var efm_save = &l:efm
    var bufnr = bufnr('%')
    try
        setl efm=%f:%l:%c:%m
        if loclist
            exe 'lgetfile ' .. tempqfl
            lw
            setloclist(0, [], 'a', {title: title})
        else
            exe 'cgetfile ' .. tempqfl
            cw
            setqflist([], 'a', {title: title})
        endif
    finally
        setbufvar(bufnr, '&efm', efm_save)
    endtry
    # If you were moving in a buffer  while the callback is invoked and open the
    # qf window, some stray characters might be printed in the status line.
    redraw!
    if loclist && getloclist(0, {size: 0}).size == 0 || getqflist({size: 0}).size == 0
        echohl ErrorMsg
        var pat = matchstr(title[1 :], '\(\i\@!\S\)\zs.\{-}\ze\1')
        echom 'E480: No match: ' .. pat
        echohl NONE
    endif
enddef
# }}}1
# Utilities {{{1
def GetExtension(): string #{{{2
    var ext = expand('%:e')
    if &ft == 'dirvish' && expand('%:p') =~? '/wiki/'
        ext = 'md'
    elseif &ft == 'dirvish' && expand('%:p') =~? '/.vim/'
        ext = 'vim'
    elseif ext == '' && bufname() != ''
        var _ext = execute('au')->split('\n')
        filter(_ext, (_, v) => v =~ 'setf\s\+' .. &ft)
        ext = get(_ext, 0, '')->matchstr('\*\.\zs\S\+')
    endif
    return ext
enddef

def Expandargs(args: string): string #{{{2
    var pat = '^\(\i\@!.\)\1\ze[gj]\{,2}\s\+'
    #           ├──────────┘
    #           └ 2 consecutive and identical non-identifier characters
    var rep = '/' .. escape(@/, '\/') .. '/'
    #                            │{{{
    #                            └ `substitute()` will remove any backslash, because
    #                               some sequences are special (like `\1` or `\u`);
    #                               See: :h sub-replace-special
    #
    #                               If our pattern contains a backslash (like in `\s`),
    #                               we need it to be preserved.
    #}}}

    # expand `//` into `/last search/`
    return substitute(args, pat, rep, '')
        # expand `%` into `current_file`
        ->substitute('\s\+\zs%\s*$', expand('%:p')->fnameescape(), '')
        # expand `##` into `files_in_arglist`
        ->substitute('\s\+\zs##\s*$', argv()
        ->map((_, v) => fnamemodify(v, ':p')->fnameescape())
        ->join(), '')
enddef

