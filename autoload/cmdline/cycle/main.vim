vim9script noclear

# TODO: Maybe we should support multiple tabstops (not just one).{{{
#
# Useful for a command like:
#
#     noautocmd vimgrep //gj `find . -type f -cmin -60` | cwindow
#                       ^                           ^
#                       tabstop 1                   tabstop 2
#
# The difficulty is how to track  the changes operated on the command-line (like
# the removal of a word by pressing `C-w`).
#
# See here for inspiration:
# https://gist.github.com/lacygoill/c8ccf30dfac6393f737e3fa4efccdf9d
#
# ---
#
# In  the  previous  example,  we  could reliably  find  the  first  tabstop  by
# looking for `^noautocmd\s*vimgrep\s*/`, and the  second tabstop by looking for
# `-\d*.\s*|\s*cwindow$`.
#
# ---
#
# We would have to temporarily remap `Tab` and `S-Tab` to a function which jumps
# across the tabstops.
# And `C-g Tab` to a function which presses the original `Tab`.
# The mappings should  probably be local to  the buffer, and be  removed when we
# quit the command-line.
#
# ---
#
# For the  moment, I  don't implement  this feature,  because there  aren't many
# commands which would benefit from it.
# This would rarely be useful, and the amount of saved keystrokes seems dubious,
# while the increased complexity would make the code harder to maintain.
#}}}

var cycles: dict<list<any>>
var seq: string

# the installation of cycles takes a few ms (too long)
var seq_and_cmds: list<any>
autocmd CmdlineEnter : ++once DelayCycleInstall()

# Interface {{{1
def cmdline#cycle#main#set(arg_seq: string, ...cmds: list<string>) #{{{2
    var first_cmd: string = cmds[0]
    var pos: number = FindTabstop(first_cmd)
    execute 'nnoremap <unique> <C-G>' .. arg_seq
        .. ' <Cmd>call cmdline#cycle#main#setSeq(' .. string(arg_seq) .. ')<CR>'
        .. ':' .. first_cmd->substitute('§', '', '')
        .. '<C-R>=setcmdpos(' .. pos .. ')[-1]<CR>'
    seq_and_cmds += [[arg_seq, cmds]]
enddef

def cmdline#cycle#main#move(is_fwd = true): string #{{{2
    var cmdline: string = getcmdline()

    if getcmdtype() != ':' || !IsValidCycle()
        return cmdline
    endif

    # extract our index position in the cycle, and the cmds in the latter
    var idx: number
    var cmds: list<dict<any>>
    [idx, cmds] = cycles[seq]
    # get the new index position
    idx = (idx + (is_fwd ? 1 : -1)) % len(cmds)
    # get the new command, and our initial position on the latter
    var new_cmd: string = cmds[idx]['cmd']
    var pos: number = cmds[idx]['pos']
    # update the new index position
    cycles[seq][0] = idx

    augroup ResetCycleIndex | autocmd!
        autocmd CmdlineLeave : cycles[seq][0] = 0
    augroup END

    execute 'cnoremap <Plug>(cycle-new-cmd) ' .. new_cmd .. '<C-R>=setcmdpos(' .. pos .. ')[-1]<CR>'

    # If we press `C-g` by accident on  the command-line, and we move forward in
    # the cycle, we should be able to undo and recover the previous command with
    # `C-_`.
    cmdline#util#undo#emitAddToUndolistC()
    feedkeys("\<Plug>(cycle-new-cmd)", 'i')
    return ''
enddef
# }}}1
# Core {{{1
def Install(arg_seq: string, arg_cmds: list<string>) #{{{2
# cmds = ['cmd1', 'cmd2']
    var positions: list<number> = arg_cmds
        ->mapnew((_, v: string): number => FindTabstop(v))

    var cmds: list<dict<any>> = arg_cmds
        ->mapnew((i: number, v: string) => ({
            cmd: v->substitute('§', '', ''),
            pos: positions[i],
        }))
    # cmds = [{cmd: 'cmd1', pos: 12}, {cmd: 'cmd2', pos: 34}]

    cycles[arg_seq] = [0, cmds]
enddef

def DelayCycleInstall() #{{{2
    for [seq: string, cmds: list<string>] in seq_and_cmds
        Install(seq, cmds)
    endfor
enddef
# }}}1
# Utilities {{{1
def FindTabstop(rhs: string): number #{{{2
    # Why not simply `return stridx(a:rhs, '§')`?{{{
    #
    # The rhs may contain special sequences such as `<Bar>` or `<C-R>`.
    # They need to be translated first.
    #}}}
    execute 'nnoremap <Plug>(cycle-find-tabstop) :' .. rhs
    # In reality, we should add `1`, but  we don't need to{{{
    #
    # because we've defined the previous  `<Plug>` mapping with a leading colon,
    # which is taken into account by `maparg()`.
    #
    # IOW, the output is right because of 2 errors which cancel one another:
    #
    #    - we don't add an offset (`1`) while we should
    #
    #    - we add a leading colon
    #
    #     It's useless, because we never see it when we're cycling.
    #
    #     The `<Plug>`  mapping would  *not* be wrong  without `:`,  because its
    #     purpose is not  to be pressed, but to get  the translation of possible
    #     special characters in the rhs.
    #}}}
    return maparg('<Plug>(cycle-find-tabstop)')->stridx('§')
enddef

def IsValidCycle(): bool #{{{2
    return cycles->has_key(seq)
        && typename(cycles[seq]) =~ '^list'
        && len(cycles[seq]) == 2
enddef

def cmdline#cycle#main#setSeq(arg_seq: string): string #{{{2
    seq = arg_seq
    return ''
enddef

