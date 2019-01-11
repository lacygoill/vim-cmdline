if exists('g:autoloaded_cmdline#cycle')
    finish
endif
let g:autoloaded_cmdline#cycle = 1

let s:cycles = {}

fu! cmdline#cycle#pass(cycles) abort "{{{1
    for cycle in a:cycles
        call s:install(cycle)
    endfor
endfu

fu! s:install(cycle) abort "{{{1
    let seq = a:cycle[0]
    let cmds = a:cycle[1]
    " cmds = ['cmd1', 'cmd2']

    call map(cmds, {i,v -> {
        \     'cmd': substitute(v, '@', '', ''),
        \     'pos':     stridx(v, '@')+1,
        \ }})
    " cmds = [{'cmd': 'cmd1', 'pos': 12}, {'cmd': 'cmd2', 'pos': 34}]

    call extend(s:cycles, {seq: [0, cmds]})
endfu

fu! cmdline#cycle#set_seq(seq) abort "{{{1
    let s:seq = a:seq
    return ''
endfu

fu! cmdline#cycle#move(is_fwd) abort "{{{1
    let cmdline = getcmdline()

    if getcmdtype() isnot# ':' || !s:is_valid_cycle()
        return cmdline
    endif

    let [idx, cmds] = s:cycles[s:seq]
    let idx = (idx + (a:is_fwd ? 1 : -1)) % len(cmds)
    let pos = cmds[idx].pos
    let new_cmd = cmds[idx].cmd
    let s:cycles[s:seq][0] = idx

    augroup reset_cycle_index
        au!
        au CmdlineLeave : let s:cycles[s:seq][0] = 0
    augroup END

    exe 'cno <plug>(cycle-new-cmd) '.new_cmd.'<c-r>=setcmdpos('.pos.')[-1]<cr>'

    call feedkeys("\<plug>(cycle-new-cmd)", 'i')
    return ''
endfu
" }}}1

" Utilities {{{1
fu! s:is_valid_cycle() abort "{{{2
    return has_key(s:cycles, s:seq)
        \ && type(s:cycles[s:seq]) == type([])
        \ && len(s:cycles[s:seq]) == 2
endfu

