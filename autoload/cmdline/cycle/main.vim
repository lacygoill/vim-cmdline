if exists('g:autoloaded_cmdline#cycle#main')
    finish
endif
let g:autoloaded_cmdline#cycle#main = 1

" TODO: Maybe we should support multiple tabstops (not just one).{{{
"
" Useful for a command like:
"
"         noa vim //gj `find . -type f -cmin -60` | cw
"                 ^                           ^
"                 tabstop 1                   tabstop 2
"
" The difficulty is how to track  the changes operated on the command-line (like
" the removal of a word by pressing `C-w`).
"
" See here for inspiration:
" https://gist.github.com/lacygoill/c8ccf30dfac6393f737e3fa4efccdf9d
"
" ---
"
" In the previous  example, we could reliably find the  first tabstop by looking
" for `^noa\s*vim\s*/`, and the second tabstop by looking for `-\d*.\s*|\s*cw$`.
"
" ---
"
" We would have to temporarily remap `Tab` and `S-Tab` to a function which jumps
" across the tabstops.
" And `C-g Tab` to a function which presses the original `Tab`.
" The mappings should  probably be local to  the buffer, and be  removed when we
" quit the command-line.
"
" ---
"
" For the  moment, I  don't implement  this feature,  because there  aren't many
" commands which would benefit from it.
" This would rarely be useful, and the amount of saved keystrokes seems dubious,
" while the increased complexity would make the code harder to maintain.
"}}}

let s:cycles = {}

" the installation of cycles takes a few ms (too long)
let s:seq_and_cmds = []
au CmdlineEnter : ++once call s:delay_cycle_install()

" Interface {{{1
fu cmdline#cycle#main#set(seq, ...) abort "{{{2
    let cmds = a:000
    let pos = s:find_tabstop(a:1)
    exe 'nno <unique> <c-g>' .. a:seq
        \ .. ' <cmd>call cmdline#cycle#main#set_seq(' .. string(a:seq) .. ')<cr>'
        \ .. ':' .. substitute(a:1, '§', '', '')
        \ .. '<c-r><c-r>=setcmdpos(' .. pos .. ')[-1]<cr>'
    let s:seq_and_cmds += [[a:seq, cmds]]
endfu

fu cmdline#cycle#main#move(is_fwd) abort "{{{2
    let cmdline = getcmdline()

    if getcmdtype() isnot# ':' || !s:is_valid_cycle()
        return cmdline
    endif

    " extract our index position in the cycle, and the cmds in the latter
    let [idx, cmds] = s:cycles[s:seq]
    " get the new index position
    let idx = (idx + (a:is_fwd ? 1 : -1)) % len(cmds)
    " get the new command, and our initial position on the latter
    let new_cmd = cmds[idx].cmd
    let pos = cmds[idx].pos
    " update the new index position
    let s:cycles[s:seq][0] = idx

    augroup reset_cycle_index | au!
        au CmdlineLeave : let s:cycles[s:seq][0] = 0
    augroup END

    exe 'cno <plug>(cycle-new-cmd) ' .. new_cmd .. '<c-r><c-r>=setcmdpos(' .. pos .. ')[-1]<cr>'

    " If we press `C-g` by accident on  the command-line, and we move forward in
    " the cycle, we should be able to undo and recover the previous command with
    " `C-_`.
    call cmdline#util#undo#emit_add_to_undolist_c()
    call feedkeys("\<plug>(cycle-new-cmd)", 'i')
    return ''
endfu
" }}}1
" Core {{{1
fu s:install(seq, cmds) abort "{{{2
    " cmds = ['cmd1', 'cmd2']
    let cmds = deepcopy(a:cmds)

    let positions = deepcopy(cmds)->map({_, v -> s:find_tabstop(v)})

    call map(cmds, {i, v -> {
        \     'cmd': substitute(v, '§', '', ''),
        \     'pos': positions[i],
        \ }})
    " cmds = [{'cmd': 'cmd1', 'pos': 12}, {'cmd': 'cmd2', 'pos': 34}]

    call extend(s:cycles, {a:seq: [0, cmds]})
endfu

fu s:delay_cycle_install() abort "{{{2
    for [seq, cmds] in s:seq_and_cmds
        call s:install(seq, cmds)
    endfor
endfu
" }}}1
" Utilities {{{1
fu s:find_tabstop(rhs) abort "{{{2
    " Why not simply `return stridx(a:rhs, '§')`?{{{
    "
    " The rhs may contain special sequences such as `<bar>` or `<c-r>`.
    " They need to be translated first.
    "}}}
    exe 'nno <plug>(cycle-find-tabstop) :' .. a:rhs
    " In reality, we should add `1`, but  we don't need to{{{
    "
    " because we've defined the previous  `<plug>` mapping with a leading colon,
    " which is taken into account by `maparg()`.
    "
    " IOW, the output is right because of 2 errors which cancel one another:
    "
    "    - we don't add an offset (`1`) while we should
    "
    "    - we add a leading colon
    "
    "     It's useless, because we never see it when we're cycling.
    "
    "     The `<plug>`  mapping would  *not* be wrong  without `:`,  because its
    "     purpose is not  to be pressed, but to get  the translation of possible
    "     special characters in the rhs.
    "}}}
    return maparg('<plug>(cycle-find-tabstop)')->stridx('§')
endfu

fu s:is_valid_cycle() abort "{{{2
    " We test  the existence of  `s:seq` because it may  not exist, if  we press
    " `C-g` by accident, without having entered a cycle before that.
    return exists('s:seq')
        \ && has_key(s:cycles, s:seq)
        \ && type(s:cycles[s:seq]) == v:t_list
        \ && len(s:cycles[s:seq]) == 2
endfu

fu cmdline#cycle#main#set_seq(seq) abort "{{{2
    let s:seq = a:seq
    return ''
endfu

