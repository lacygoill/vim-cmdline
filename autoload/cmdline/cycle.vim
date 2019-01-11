if exists('g:autoloaded_cmdline#cycle')
    finish
endif
let g:autoloaded_cmdline#cycle = 1

fu! cmdline#cycle#pass(cycles) abort "{{{1
    for cycle in a:cycles
        call s:install(cycle)
    endfor
endfu

fu! s:install(cmds) abort "{{{1
    let s:nb_cycles = get(s:, 'nb_cycles', 0) + 1
    " It's important to make a copy of the arguments, otherwise{{{
    " we   would   get   a   weird    result   in   the   next   invocation   of
    " `map()`. Specifically, in the  last item of the  transformed list. This is
    " probably  because the  same list  (a:cmds) would  be mentioned  in the  1st
    " argument of `map()`, but also in the 2nd one.
    "}}}
    let cmds = deepcopy(a:cmds)

    " Goal:{{{
    " Produce a dictionary whose keys are the commands in a cycle (a:cmds),
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
    " 1. transform  the list of commands  into a list of  sub-dictionaries (with
    " the keys `new_cmd` and `pos`) through an invocation of `map()`
    "
    " 2. progressively  build the  dictionary `s:cycle_123`  with a  `for` loop,
    " using the previous  sub-dictionaries as values, and  the original commands
    " as keys
    "}}}
    " Alternative:{{{
    " (a little slower)
    "
    "         let s:cycle_{s:nb_cycles} = {}
    "         let i = 0
    "         for cmd in cmds
    "             let key      = substitute(cmd, '@', '', '')
    "             let next_cmd = a:cmds[(i+1)%len(a:cmds)]
    "             let pos      = stridx(next_cmd, '@')+1
    "             let value    = {'cmd': substitute(next_cmd, '@', '', ''), 'pos': pos}
    "             call extend(s:cycle_{s:nb_cycles}, {key : value})
    "             let i += 1
    "         endfor
    "}}}

    call map(cmds, {i,v -> {substitute(v, '@', '', '') : {
        \ 'new_cmd': substitute(a:cmds[(i+1)%len(a:cmds)], '@', '', ''),
        \ 'pos'    :     stridx(a:cmds[(i+1)%len(a:cmds)], '@')+1},
        \ }})

    let s:cycle_{s:nb_cycles} = {}
    for dict in cmds
        call extend(s:cycle_{s:nb_cycles}, dict)
    endfor
endfu

fu! cmdline#cycle#move(is_fwd) abort "{{{1
    let cmdline = getcmdline()

    if getcmdtype() isnot# ':'
        return cmdline
    endif

    " try to find the cycle to which the current command-line belongs
    let i = 1
    while i <= s:nb_cycles
        if has_key(s:cycle_{i}, cmdline)
            break
        endif
        let i += 1
    endwhile
    " now `i` stores, either:
    "
    "    • the index of the cycle to which the command-line belong
    "
    "    • a number greater than the number of installed cycles;
    "    in that case, we'll try to return the command of the last used cycle

    if i <= s:nb_cycles
        let s:last_cycle = {
            \ 'pos': s:cycle_{i}[cmdline].pos,
            \ 'cmdline': substitute(s:cycle_{i}[cmdline].new_cmd, '\m\c<c-r>=\(.\{-}\)<cr>', '\=eval(submatch(1))', ''),
            \ }
            " \ 'cmdline': s:cycle_{i}[cmdline].new_cmd,
    endif
    if i > s:nb_cycles
        call setcmdpos(get(get(s:, 'last_cycle', {}), 'pos', 1))
        return get(get(s:, 'last_cycle', {}), 'cmdline', '')
    elseif a:is_fwd
        call setcmdpos(s:cycle_{i}[cmdline].pos)
        return substitute(s:cycle_{i}[cmdline].new_cmd, '\m\c<c-r>=\(.\{-}\)<cr>', '\=eval(submatch(1))', '')
        " return s:cycle_{i}[cmdline].new_cmd
    else
        " get the previous command in the cycle,
        " and the position of the cursor on the latter
        let prev_cmd =   keys(filter(deepcopy(s:cycle_{i}), { k,v -> v.new_cmd is# cmdline }))[0]
        let prev_pos = values(filter(deepcopy(s:cycle_{i}), { k,v -> v.new_cmd is# prev_cmd }))[0].pos
        call setcmdpos(prev_pos)
        return prev_cmd
    endif
endfu

