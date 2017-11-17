if exists('g:autoloaded_cmdline')
    finish
endif
let g:autoloaded_cmdline = 1

" Functions {{{1
fu! cmdline#auto_uppercase() abort "{{{2

" We define abbreviations in command-line mode to automatically replace
" a custom command name written in lowercase with uppercase characters.

    let commands = getcompletion('[A-Z]?*', 'command') + s:fugitive_commands

    for cmd in commands
        let lcmd  = tolower(cmd)
        exe printf('cnorea <expr> %s
        \               getcmdtype() == '':'' && getcmdline() =~# ''\v^%(%(tab<Bar>vert%[ical])\s+)?%s$''
        \               ?     %s
        \               :     %s
        \          ', lcmd, lcmd, string(cmd), string(tolower(cmd))
        \         )
    endfor
endfu

fu! cmdline#chain() abort "{{{2
    " Do NOT write empty lines in this function (gQ → E501, E749).
    let cmdline = getcmdline()
    let pat2cmd = {
    \              '(g|v).*(#@<!#|nu%[mber])' : [ ''         , 0 ],
    \              '(ls|files|buffers)!?'     : [ 'b '       , 0 ],
    \              'chi%[story]'              : [ 'sil col ' , 1 ],
    \              'lhi%[story]'              : [ 'sil lol ' , 1 ],
    \              'marks'                    : [ 'norm! `'  , 1 ],
    \              'old%[files]'              : [ 'e #<'     , 1 ],
    \              'undol%[ist]'              : [ 'u '       , 1 ],
    \              'changes'                  : [ "norm! g;\<s-left>"     , 1 ],
    \              'ju%[mps]'                 : [ "norm! \<c-o>\<s-left>" , 1 ],
    \             }
    for [pat, cmd ] in items(pat2cmd)
        let [ keys, nomore ] = cmd
        if cmdline =~# '\v\C^'.pat.'$'
            if nomore
                let more_save = &more
                " allow Vim's pager to display the full contents of any command,
                " even if it takes more than one screen; don't stop after the first
                " screen to display the message:    -- More --
                set nomore
                call timer_start(0, {-> execute('set '.(more_save ? '' : 'no').'more')})
            endif
            return feedkeys(':'.keys, 'in')
        endif
    endfor
    if cmdline =~# '\v\C^(dli|il)%[ist]\s+'
        call feedkeys(':'.cmdline[0].'j  '.split(cmdline, ' ')[1]."\<s-left>\<left>", 'in')
    elseif cmdline =~# '\v\C^(cli|lli)'
        call feedkeys(':sil '.repeat(cmdline[0], 2).' ', 'in')
    endif
endfu

fu! cmdline#cycle(fwd) abort "{{{2
    let cmdline = getcmdline()

    " try to find the cycle to which the current command line belongs
    let i = 1
    while i <= s:nb_cycles
        if has_key(s:cycle_{i}, cmdline)
            break
        endif
        let i += 1
    endwhile
    " now `i` stores, either:
    "
    "     • the index of the cycle to which the command line belong
    " OR
    "     • a number greater than the number of installed cycles
    "
    "       if this  is the case,  since there's no  cycle to use,  we'll simply
    "       return the default command stored in `s:default_cmd`

    if a:fwd
        call setcmdpos(
        \               i <= s:nb_cycles
        \               ?    s:cycle_{i}[cmdline].pos
        \               :    s:default_cmd.pos
        \             )
        return i <= s:nb_cycles
        \?         s:cycle_{i}[cmdline].new_cmd
        \:         s:default_cmd.cmd
    else
        if i <= s:nb_cycles
            " get the previous command in the cycle,
            " and the position of the cursor on the latter
            let prev_cmd = keys(filter(deepcopy(s:cycle_{i}), 'v:val.new_cmd ==# '.string(cmdline)))[0]
            let prev_pos = s:cycle_{i}[prev_cmd].pos
            call setcmdpos(prev_pos)
            return prev_cmd
        else
            call setcmdpos(s:default_cmd.pos)
            return s:default_cmd.cmd
        endif
    endif
endfu

fu! s:cycle_install(...) abort "{{{2
    let s:nb_cycles = get(s:, 'nb_cycles', 0) + 1
    " It's important to make a copy of the arguments, otherwise{{{
    " we   would   get   a   weird    result   in   the   next   invocation   of
    " `map()`. Specifically, in the  last item of the  transformed list. This is
    " probably  because the  same list  (a:000) would  be mentioned  in the  1st
    " argument of `map()`, but also in the 2nd one.
    "}}}
    let cmds = deepcopy(a:000)

    " Goal:{{{
    " Produce a dictionary whose keys are the commands in a cycle (a:000),
    " and whose values are sub-dictionaries.
    " Each one of the latter contains 2 keys:
    "
    "         • new_cmd: the new command which should replace the current one
    "         • pos:     the position on the latter
    "
    " The final dictionary should be stored in a variable such as `s:cycle_42`,
    " where 42 is the number of cycles installed so far.
    "}}}
    " Why do it?{{{
    " This dictionary will be used as a FSM to transit from the current command
    " to a new one.
    "}}}
    " How do we achieve it?{{{
    " 2 steps:
    "
    "     1. transform the list of commands into a list of sub-dictionaries
    "        (with the keys `new_cmd` and `pos`) through an invocation of
    "        `map()`
    "
    "     2. progressively build the dictionary `s:cycle_42` with a `for`
    "        loop, using the previous sub-dictionaries as values, and the
    "        original commands as keys
    "}}}
    " Alternative:{{{
    " (a little slower)
    "
    "         let s:cycle_{s:nb_cycles} = {}
    "         let i = 0
    "         for cmd in cmds
    "             let key      = substitute(cmd, '@', '', '')
    "             let next_cmd = a:000[(i+1)%len(a:000)]
    "             let pos      = match(next_cmd, '@')+1
    "             let value    = {'cmd': substitute(next_cmd, '@', '', ''), 'pos': pos}
    "             call extend(s:cycle_{s:nb_cycles}, {key : value})
    "             let i += 1
    "         endfor
    "}}}
    call map(cmds, '{ substitute(v:val, "@", "", "") :
    \                     { "new_cmd" : substitute(a:000[(v:key+1)%len(a:000)], "@", "", ""),
    \                       "pos"     :      match(a:000[(v:key+1)%len(a:000)], "@")+1},
    \               }')
    let s:cycle_{s:nb_cycles} = {}
    for dict in cmds
        call extend(s:cycle_{s:nb_cycles}, dict)
    endfor
endfu

fu! cmdline#fix_typo(label) abort "{{{2
    let cmdline = getcmdline()
    let keys = {
             \   'cr': "\<bs>\<cr>",
             \   'z' : "\<bs>\<bs>()\<cr>",
             \ }[a:label]
    "                                    ┌─ do NOT replace this with `getcmdline()`:
    "                                    │
    "                                    │      when the callback will be processed,
    "                                    │      the old command line will be lost
    "                                    │
    call timer_start(0, {-> feedkeys(':'.cmdline.keys, 'in')})
    "    │
    "    └─ we can't send the keys right now, because the command hasn't been
    "       executed yet; from `:h CmdWinLeave`:
    "
    "               “Before leaving the command line.“
    "
    "       But it seems we can't modify the command either. Maybe it's locked.
    "       So, we'll reexecute a new fixed command with the timer.
endfu

fu! cmdline#install_fugitive_commands() abort "{{{2
    " In vimrc,  we postpone  the loading  of `fugitive`  after Vim  has started
    " (through a timer).

    " It could  be an issue  in the  future, if we  install a custom  mapping to
    " execute a  fugitive command, and  we press it  before the plugin  has been
    " loaded.
    "
    " Also, when we:
    "
    "         • start Vim  with a file to open as an argument
    "         • the file is in a git repo
    "         • type `:Glog`
    "
    " … it fails.
    "
    " This  is because  fugitive listens  to  certain events  like `BufReadPost`  to
    " detect  whether the  current file  is inside  a  git repo,  and if  it is,  it
    " installs its buffer-local commands.
    " Even if `fugitive` is correctly lazy-loaded  AFTER Vim has started reading the
    " file, it wasn't loaded at the time the  file was read.  So, we need to re-emit
    " `BufReadPost` so that fugitive properly installs its commands.
    augroup my_install_fugitive_commands
        au!
        " Do NOT make this autocmd a fire-once autocmd.
        " There may be more than 1 file which were opened when Vim started.
        " The autocmd needs to be there for all of them.
        au CmdUndefined * if index(s:fugitive_commands, expand('<afile>')) >= 0
                       \|     sil! doautocmd fugitive BufReadPost
                       \| endif
    augroup END
endfu

fu! cmdline#remember(list) abort "{{{2
    augroup remember_overlooked_commands
        au!
        for cmd in a:list
            exe printf('
            \            au CmdlineLeave :
            \            if getcmdline() %s %s
            \|               call timer_start(0, {-> execute("echohl WarningMsg | echo %s | echohl NONE", "")})
            \|           endif
            \          ',     cmd.regex ? '=~#' : '==#',
            \                 string(cmd.regex ? '^'.cmd.old.'$' : cmd.old),
            \                 string('['.cmd.new .'] was equivalent')
            \         )
        endfor
    augroup END
endfu

fu! cmdline#toggle_editing_commands(enable) abort "{{{2
    try
        if a:enable
            call my_lib#map_restore(get(s:, 'my_editing_commands', []))
        else
            let lhs_list = map(split(execute('cno'), '\n'), 'matchstr(v:val, ''\vc\s+\zs\S+'')')
            call filter(lhs_list, '!empty(v:val)')
            let s:my_editing_commands = my_lib#map_save(lhs_list, 'c', 1)

            for lhs in lhs_list
                exe 'cunmap '.lhs
            endfor
        endif

    catch
        return 'echoerr '.string(v:exception)
    endtry
endfu

fu! cmdline#tweak_search_or_substitution() abort "{{{2
    if getcmdtype() =~ '[?/]'
        return substitute(getcmdline(), '\a', '[[=\0=]]', 'g')

    elseif getcmdtype() =~ ':'
        " If  we're on  the Ex  command-line (:),  we try  and guess  whether it
        " contains a substitution command.
        let cmdline   = getcmdline()
        let range     = matchstr(cmdline, '[%*]\|[^,]*,[^,]*\zes')
        let cmdline   = substitute(cmdline, '^\V'.escape(range, '\').'\vs.\zs\\v', '', '')
        let separator = cmdline =~# 's/' ? '/' : 's:' ? ':' : ''

        " If there's no substitution command we don't modify the command-line.
        if empty(separator)
            return ''
        endif

        " If there's one, we extract the pattern.
        let pat = split(cmdline, separator)[1]

        " If  the pattern  contains  word  boundaries (\<,  \>),  we remove  the
        " backslash,  because we're  going to  enable the  very magic  mode.  We
        " could have  word boundaries when  we hit * on  a word in  normal mode,
        " then insert the search register in the pattern field.
        if pat =~# '^\\<\|\\>'
            let pat = substitute(pat, '^\\<', '<', 'g')
            let pat = substitute(pat, '\\>', '>', 'g')
        endif

        " Then,  we  extract  from  the pattern  words  between  underscores  or
        " uppercase letters; e.g.:
        "
        "         'OneTwoThree'   → ['One', 'Two', 'Three']
        "         'one_two_three' → ['one', 'two', 'three']
        let subpatterns = split(pat, pat =~# '_' ? '_' : '\ze\u')

        " Finally we return the keys to type.
        "
        "         join(map(subpatterns, '…'), '…')
        "
        " … evaluates to  the original pattern,  with the addition  of parentheses
        " around the subpatterns:
        "
        "            (One)(Two)(Three)
        "      or    (one)_(two)_(three)
        let new_cmdline = range.'s/\v'.join(map(subpatterns, '"(" . v:val . ")"'), pat =~# '_' ? '_' : '') . '//g'

        " Before returning the  keys, we position the cursor between  the last 2
        " slashes.
        call setcmdpos(strchars(new_cmdline)-1)
        return new_cmdline

    else
        return ''
    endif
endfu

" Commands {{{1

" Warning:
" Do not move  the execution of a `:CycleInstall` command  before the definition
" of `s:cycle_install()`.

" Advice:
" For each  “cycle“ (set of  commands) you  install, create a  mapping which
" populates the command  line with a command  in it. This will give  you an easy
" entry in the cycle. Otherwise the smallest  typo will prevent you from getting
" the  next command  in the  cycle. Instead, you  will get  the default  command
" (`s:default_cmd`).

com! -bar -nargs=+ CycleInstall call s:cycle_install(<args>)

CycleInstall '%s/\v@//g', '%s/\v@//gc'
"                  │
"                  └─ indicates where we want the cursor to be

" search  inside `~/.vim`,  the arglist,  or the  current buffer
CycleInstall  'vim /@/gj ~/.vim/**/*.vim',  'lvim /@/gj %',  'vim /@/gj ##'

" TODO: `:[l]vim[grep]` is not asynchronous.
" Add an async command (using  &grepprg?).

" Variables {{{1

let s:default_cmd = { 'cmd' : 'vim //gj ~/.vim/**/*.vim', 'pos' : 6 }

let s:fugitive_commands = [
\                           'Gblame',
\                           'Gbrowse',
\                           'Gcd',
\                           'Gcommit',
\                           'Gdelete',
\                           'Gdiff',
\                           'Ge',
\                           'Gedit',
\                           'Gfetch',
\                           'Ggrep',
\                           'Git',
\                           'Glcd',
\                           'Glgrep',
\                           'Gllog',
\                           'Glog',
\                           'Gmerge',
\                           'Gmove',
\                           'Gpedit',
\                           'Gpull',
\                           'Gpush',
\                           'Gread',
\                           'Gremove',
\                           'Gsdiff',
\                           'Gsplit',
\                           'Gstatus',
\                           'Gtabedit',
\                           'Gvdiff',
\                           'Gvsplit',
\                           'Gw',
\                           'Gwq',
\                           'Gwrite',
\                         ]

