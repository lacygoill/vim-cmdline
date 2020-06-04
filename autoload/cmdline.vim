if exists('g:autoloaded_cmdline')
    finish
endif
let g:autoloaded_cmdline = 1

fu cmdline#auto_uppercase() abort "{{{1
    " We define  abbreviations in command-line  mode to automatically  replace a
    " custom command name written in lowercase with uppercase characters.

    " Do *not* use `getcompletion()`.{{{
    "
    "     let commands = getcompletion('[A-Z]?*', 'command')
    "
    " You would get the names of the global commands (✔) *and* the ones local to
    " the current buffer (✘); we don't want the latter.
    " Installing  a *global* abbreviation  for a *buffer-local*  command doesn't
    " make sense.
    "}}}
    let commands = map(filter(split(execute('com'), '\n')[1:],
    \ {_,v -> v =~# '^[^bA-Z]*\u\S'}),
    \ {_,v -> matchstr(v, '\u\S*')})

    let pat = '^\%%(\%%(tab\<bar>vert\%%[ical]\)\s\+\)\=%s$\<bar>^\%%(''<,''>\<bar>\*\)%s$'
    for cmd in commands
        let lcmd  = tolower(cmd)
        exe printf('cnorea <expr> %s
            \         getcmdtype() is# '':'' && getcmdline() =~# '..string(pat)..'
            \         ?     %s
            \         :     %s'
            \ , lcmd, lcmd, lcmd, string(cmd), string(tolower(cmd))
            \ )
    endfor
endfu

fu cmdline#c_l() abort "{{{1
    if getcmdtype() isnot# ':' | return "\<c-l>" | endif
    let col = getcmdpos()
    let pat =
        "\ `:123lvimgrepadd!`
        \   '^\m\C[: \t]*\d*l\=vim\%[grepadd]!\=\s\+'
        "\ opening delimiter
        \ ..'\(\i\@!.\)'
        "\ the pattern; stopping at the cursor because it doesn't make sense
        "\ to consider what comes after the cursor during a completion
        \ ..'\zs.\{-}\%'..col..'c\ze.\{-}'
        "\ no odd number of backslashes before the closing delimiter
        \ ..'\%([^\\]\\\%(\\\\\)*\)\@<!'
        "\ closing delimiter
        \ ..'\1'
        "\ flags
        \ ..'[gj]\{,2}\s'
        "\ `:%s/pat/rep/g`
        \ ..'\|s\(\i\@!.\)\zs.\{-}\%'..col..'c\ze.\{-}\2.\{-}\2'
        "\ `:h :s_flags`
        \ ..'[cegn]\{,4}\%($\|\s\||\)'
        "\ `:helpg pat`
        \ ..'\|\%(helpg\%[rep]\|l\%[helpgrep]\)\s\+\zs.*'
    let list = matchlist(getcmdline(), pat)
    " Why don't you return `"\<C-l>"`?{{{
    "
    " I don't like the behavior of the default `C-l`.
    " E.g.,  if your  command-line  contains a  command  substitution, but  your
    " cursor is not inside the pattern field, `C-l` can still insert a character.
    " If I'm not in the pattern field, I don't want `C-l` to insert anything.
    "}}}
    if list == [] | return '' | endif
    let [pat, delim] = list[0:1]
    " Warning: this search is sensitive to the values of `'ignorecase'` and `'smartcase'`
    let [lnum, col] = searchpos(pat, 'n')
    if [lnum, col] == [0, 0] | return '' | endif
    let match = matchstr(getline(lnum), '.*\%'..col..'c\zs.*')
    let suffix = substitute(match, '^'..pat, '', '')
    if suffix is# ''
        return ''
    " escape the same characters as the default `C-l` in an `:s` command
    elseif suffix[0] =~# '[$*.:[\\'..delim..'^~]'
        return '\'..suffix[0]
    else
        return suffix[0]
    endif
endfu
" Why don't you support `:vim pat` (without delimiters)?{{{
"
" It  would be  tricky because  in that case,  Vim updates  the position  of the
" cursor after every inserted character.
"
" MWE:
"
"     $ cat <<'EOF' >/tmp/vim.vim
"     set is
"     cno <expr> <c-l> C_l()
"     fu C_l()
"         echom getpos('.')
"         return ''
"     endfu
"     EOF
"
"     $ vim -Nu NONE -S /tmp/vim.vim /tmp/vim.vim
"     :vim /c/
"     " press C-l while the cursor is right before `c`
"     [0, 2, 1, 0]~
"     " the cursor didn't move
"     :vim c C-l
"     [0, 2, 14, 0]~
"     " the cursor *did* move
"}}}

fu cmdline#chain() abort "{{{1
    " Do *not* write empty lines in this function (`gQ` → E501, E749).
    let cmdline = getcmdline()
    " The boolean flag controls the `'more'` option.
    let pat2cmd = {
        \ '\%(g\|v\).*\%(#\@1<!#\|nu\%[mber]\)' : [''        , v:false],
        \ '\%(ls\|files\|buffers\)!\='          : ['b '      , v:false],
        \ 'chi\%[story]'                        : ['CC '     , v:true],
        \ 'lhi\%[story]'                        : ['LL '     , v:true],
        \ 'marks'                               : ['norm! `' , v:true],
        \ 'old\%[files]'                        : ['e #<'    , v:true],
        \ 'undol\%[ist]'                        : ['u '      , v:true],
        \ 'changes'                             : ["norm! g;\<s-left>"     , v:true],
        \ 'ju\%[mps]'                           : ["norm! \<c-o>\<s-left>" , v:true],
        \ }
    for [pat, cmd] in items(pat2cmd)
        let [keys, nomore] = cmd
        if cmdline =~# '\C^'..pat..'$'
            " when I  execute `:[cl]chi`,  don't populate the  command-line with
            " `:sil [cl]ol` if the qf stack doesn't have at least two qf lists
            if pat is# 'lhi\%[story]' && get(getloclist(0, {'nr': '$'}), 'nr', 0) <= 1
            \ || pat is# 'chi\%[story]' && get(getqflist({'nr': '$'}), 'nr', 0) <= 1
                return
            endif
            if pat is# 'chi\%[story]'
                let pfx = 'c'
            elseif pat is# 'lhi\%[story]'
                let pfx = 'l'
            endif
            if exists('pfx')
                if pfx is# 'c' && get(getqflist({'nr': '$'}), 'nr', 0) <= 1
                \ || pfx is# 'l' && get(getloclist(0, {'nr': '$'}), 'nr', 0) <= 1
                    return
                endif
            endif
            " Why disabling `'more'` for some commands?{{{
            "
            " >     The lists generated by :#, :ls, :ilist, :dlist, :clist, :llist, or
            " >     :marks  are  relatively  short  but  those  generated  by  :jumps,
            " >     :oldfiles,  or  :changes  can  be   100  lines  long  and  require
            " >     paging. This can be really cumbersome, especially considering that
            " >     the  most recent  items are  near the  end of  the list. For  this
            " >     reason,  I chose  to  temporarily  :set nomore  in  order to  jump
            " >     directly to the end  of the list.
            "
            " Source: https://gist.github.com/romainl/047aca21e338df7ccf771f96858edb86#generalizing
            "}}}
            if nomore
                let s:more_save = &more
                " allow Vim's pager to display the full contents of any command,
                " even if it takes more than one screen; don't stop after the first
                " screen to display the message:    -- More --
                set nomore
                au CmdlineLeave * ++once exe 'set '..(s:more_save ? '' : 'no')..'more'
                    \ | unlet! s:more_save
            endif
            return feedkeys(':'..keys, 'in')
        endif
    endfor
    if cmdline =~# '\C^\s*\%(dli\|il\)\%[ist]\s\+'
        call feedkeys(':'..matchstr(cmdline, '\S')..'j  '..split(cmdline, ' ')[1].."\<s-left>\<left>", 'in')
    elseif cmdline =~# '\C^\s*\%(cli\|lli\)'
        call feedkeys(':sil '..repeat(matchstr(cmdline, '\S'), 2)..' ', 'in')
    endif
endfu

fu cmdline#fix_typo(label) abort "{{{1
    let cmdline = getcmdline()
    let keys = {
             \   'cr': "\<bs>\<cr>",
             \   'z' : "\<bs>\<bs>()\<cr>",
             \ }[a:label]
    "                                     ┌ do *not* replace this with `getcmdline()`:
    "                                     │
    "                                     │     when the callback will be processed,
    "                                     │     the old command-line will be lost
    "                                     │
    call timer_start(0, {-> feedkeys(':'..cmdline..keys, 'in')})
    "    │
    "    └ we can't send the keys right now, because the command hasn't been
    "      executed yet; from `:h CmdlineLeave`:
    "
    "          “Before leaving the command-line.“
    "
    "      But it seems we can't modify the command either. Maybe it's locked.
    "      So, we'll reexecute a new fixed command with the timer.
endfu

fu cmdline#hit_enter_prompt_no_recording() abort "{{{1
    " Nvim is a special case.{{{
    "
    " The Vim implementation doesn't work for Nvim.
    "
    " You could replace the `SafeState` autocmd with this:
    "
    "     let q = {}
    "     let q.timer = timer_start(10, {-> mode() isnot# 'r' && q.nunmap()}, {'repeat': -1})
    "     fu q.nunmap() abort dict
    "         call timer_stop(self.timer)
    "         sil! nunmap q
    "     endfu
    "
    " But it would still not work, because,  in Nvim, for some reason, a timer's
    " callback can't be invoked while the hit-enter prompt is visible:
    "
    "     $ nvim -u NONE -S <(cat <<'EOF'
    "         call timer_start(2000, {-> Cb()}, {'repeat': 10})
    "         fu Cb() abort
    "             let g:modes = get(g:, 'modes', []) + [mode(1)]
    "         endfu
    "         echo "a\nb"
    "     EOF
    "     )
    "     " wait for 20s
    "     " run:  :echo g:modes (type the command quickly)
    "     " expected: 10 items in the list, a few of them being 'rm'
    "     " actual: fewer than 10 items in the list, none of them is 'rm'
    "
    " Nvim blocks the  callbacks until the hit-enter prompt  disappears; at that
    " point, it starts the remaining callbacks.
    "
    " From someone on the #neovim irc channel:
    "
    " >     the callback wants  to execute on the main thread,  which is blocked
    " >     until you hit enter
    " >     it's probably just an architecture  difference. I don't know how vim
    " >     handles it but  neovim uses libuv to  run an event loop  on the main
    " >     thread. all the io is via  libuv's async worker threadpools, and you
    " >     can even send jobs  to other threads that way, but the  ui is all on
    " >     the main thread the event loop runs on
    " >     well not all the io. some of it's still blocking, like :write
    "}}}
    if has('nvim')
        " Do *not* use `<nop>` in the rhs. {{{
        "
        " The `q`  mapping would  not be removed  immediately after  leaving the
        " hit-enter prompt by pressing `q`.
        " That's because the timer's callback is not executed until you interact
        " with Nvim (move the cursor, enter insert mode, ...).
        " `<nop>` does not interact with Nvim in any way; `<c-\><c-n>` does.
        "}}}
        nno q <c-\><c-n>
        return timer_start(0, {-> execute('nunmap q', 'silent!')})
    endif

    " if we press `q`, just remove the mapping{{{
    "
    " No  need to  press sth  like  `Esc`; when  the mapping  is processed,  the
    " hit-enter prompt  has already been  closed automatically.  It's  closed no
    " matter which key you press.
    "}}}
    nno <expr> q execute('nunmap q', 'silent!')[-1]
    " if we escape the prompt without pressing `q`, make sure the mapping is still removed
    au SafeState * ++once sil! nunmap q
endfu

fu cmdline#remember(list) abort "{{{1
    augroup remember_overlooked_commands | au!
        let code =<< trim END
            au CmdlineLeave : if getcmdline() %s %s
                exe "au SafeState * ++once echohl WarningMsg | echo %s | echohl NONE"
            endif
        END
        call map(deepcopy(a:list), {_,v -> execute(printf(join(code, '|'),
        \     v.regex ? '=~#' : 'is#',
        \     string(v.regex ? '^'..v.old..'$' : v.old),
        \     string('['..v.new..'] was equivalent')
        \ ))})
    augroup END
endfu

fu cmdline#toggle_editing_commands(enable) abort "{{{1
    try
        if a:enable
            call lg#map#restore(get(s:, 'my_editing_commands', []))
        else
            let lhs_list = split(execute('cno'), '\n')
            " ignore buffer-local mappings
            call filter(lhs_list, {_,v -> v !~# '^[c!]\s\+\S\+\s\+\S*@'})
            " extract lhs
            call map(lhs_list, {_,v -> matchstr(v, '^[c!]\s\+\zs\S\+')})
            let s:my_editing_commands = lg#map#save(lhs_list, 'c')
            cmapclear
        endif
    catch
        return lg#catch()
    endtry
endfu

