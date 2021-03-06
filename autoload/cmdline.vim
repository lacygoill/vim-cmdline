vim9script noclear

import Catch from 'lg.vim'
import {
    MapSave,
    MapRestore,
} from 'lg/map.vim'

def cmdline#autoUppercase() #{{{1
    # We define  abbreviations in command-line  mode to automatically  replace a
    # custom command name written in lowercase with uppercase characters.

    # Do *not* use `getcompletion()`.{{{
    #
    #     let commands = getcompletion('[A-Z]?*', 'command')
    #
    # You would get the names of the global commands (✔) *and* the ones local to
    # the current buffer (✘); we don't want the latter.
    # Installing  a *global* abbreviation  for a *buffer-local*  command doesn't
    # make sense.
    #}}}
    var commands: list<string> = execute('command')
        ->split('\n')[1 :]
        ->filter((_, v: string): bool => v =~ '^[^bA-Z]*\u\S')
        ->map((_, v: string) => v->matchstr('\u\S*'))

    var pat: string = '^\%%(\%%(tab\<Bar>vert\%%[ical]\)\s\+\)\=%s$\<Bar>^\%%(''<,''>\<Bar>\*\)%s$'
    for cmd: string in commands
        var lcmd: string = cmd->tolower()
        execute printf('cnoreabbrev <expr> %s getcmdtype() == '':'' && getcmdline() =~ '
                    .. string(pat) .. ' ? %s : %s',
            lcmd, lcmd, lcmd, cmd->string(), cmd->tolower()->string())
    endfor
enddef

def cmdline#chain() #{{{1
    var cmdline: string = getcmdline()

    # The boolean flag controls the `'more'` option.
    var pat2cmd: dict<list<any>> = {
        '\%(g\|v\).*\%(#\@1<!#\|nu\%[mber]\)': ['', false],
        '\%(ls\|files\|buffers\)!\=': ['b ', false],
        'chi\%[story]': ['CC ', true],
        'lhi\%[story]': ['LL ', true],
        'marks':        ['normal! `', true],
        'old\%[files]': ['edit #<', true],
        'undol\%[ist]': ['undo ', true],
        'changes':      ["normal! g;\<S-Left>", true],
        'ju\%[mps]':    ["normal! \<C-O>\<S-Left>", true],
    }

    for [pat: string, cmd: list<any>] in pat2cmd->items()
        var keys: string
        var nomore: bool
        [keys, nomore] = cmd
        if cmdline =~ '\C^' .. pat .. '$'
            # when I  execute `:[cl]chistory`,  don't populate the  command-line with
            # `:silent [cl]older` if the qf stack doesn't have at least two qf lists
            if pat == 'lhi\%[story]' && getloclist(0, {nr: '$'})->get('nr', 0) <= 1
            || pat == 'chi\%[story]' && getqflist({nr: '$'})->get('nr', 0) <= 1
                return
            endif
            var pfx: string
            if pat == 'chi\%[story]'
                pfx = 'c'
            elseif pat == 'lhi\%[story]'
                pfx = 'l'
            endif
            if pfx != ''
                if pfx == 'c' && getqflist({nr: '$'})->get('nr', 0) <= 1
                || pfx == 'l' && getloclist(0, {nr: '$'})->get('nr', 0) <= 1
                    return
                endif
            endif
            # Why disabling `'more'` for some commands?{{{
            #
            #    > The lists generated by :#, :ls, :ilist, :dlist, :clist, :llist, or
            #    > :marks  are  relatively  short  but  those  generated  by  :jumps,
            #    > :oldfiles,  or  :changes  can  be   100  lines  long  and  require
            #    > paging. This can be really cumbersome, especially considering that
            #    > the  most recent  items are  near the  end of  the list. For  this
            #    > reason,  I chose  to  temporarily  :set nomore  in  order to  jump
            #    > directly to the end  of the list.
            #
            # Source: https://gist.github.com/romainl/047aca21e338df7ccf771f96858edb86#generalizing
            #}}}
            if nomore
                more_save = &more
                # allow Vim's pager to display the full contents of any command,
                # even if it takes more than one screen; don't stop after the first
                # screen to display the message:    -- More --
                &more = false
                autocmd CmdlineLeave * ++once if more_save
                    |     &more = true
                    | else
                    |     &more = false
                    | endif
            endif
            feedkeys(':' .. keys, 'in')
            return
        endif
    endfor

    if cmdline =~ '\C^\s*\%(dli\|il\)\%[ist]\s\+'
        feedkeys(':'
            .. cmdline->matchstr('\S') .. 'j  '
            .. cmdline->split(' ')[1] .. "\<S-Left>\<Left>", 'in')
    elseif cmdline =~ '\C^\s*\%(cli\|lli\)'
        feedkeys(':silent ' .. cmdline->matchstr('\S')->repeat(2) .. ' ', 'in')
    endif
enddef
var more_save: bool

def cmdline#fixTypo(label: string) #{{{1
    var cmdline: string = getcmdline()
    var keys: string = {
          cr: "\<BS>\<CR>",
          z: "\<BS>\<BS>()\<CR>",
        }[label]
    # We can't send the keys right now, because the command hasn't been executed yet.{{{
    #
    # From `:help CmdlineLeave`:
    #
    #    > Before leaving the command-line.
    #
    # But it seems we can't modify the command either.  Maybe it's locked.
    # So, we'll reexecute a new fixed command with a little later.
    #}}}
    RerunFixedCmd = () => feedkeys(':' .. cmdline .. keys, 'in')
    #                                     │{{{
    #                                     └ do *not* replace this with `getcmdline()`:
    #                                       when the callback will be processed,
    #                                       the old command-line will be lost
    #}}}
    autocmd SafeState * ++once RerunFixedCmd()
enddef
var RerunFixedCmd: func

def cmdline#hitEnterPromptNoRecording() #{{{1
    # if we press `q`, just remove the mapping{{{
    #
    # No  need to  press sth  like  `Esc`; when  the mapping  is processed,  the
    # hit-enter prompt  has already been  closed automatically.  It's  closed no
    # matter which key you press.
    #}}}
    nnoremap q <Cmd>silent! nunmap q<CR>
    # if we escape the prompt without pressing `q`, make sure the mapping is still removed
    autocmd SafeState * ++once silent! nunmap q
enddef

def cmdline#remember(list: list<dict<any>>) #{{{1
    augroup RememberOverlookedCommands | autocmd!
        var code: list<string> =<< trim END
            autocmd CmdlineLeave : if getcmdline() %s %s
                execute "autocmd SafeState * ++once echohl WarningMsg | echo %s | echohl NONE"
            endif
        END
        for d: dict<any> in list
            var cmd: string = printf(
                code->join('|'),
                d.regex ? '=~' : '==',
                string(d.regex ? '^' .. d.old .. '$' : d.old),
                string('[' .. d.new .. '] was equivalent')
            )
            execute cmd
        endfor
    augroup END
enddef

def cmdline#vim9Abbrev(): string #{{{1
    if getcmdtype() != ':'
        return 'v'
    endif

    var cmdline: string = getcmdline()
    var pos: number = getcmdpos()
    var before_cursor: string = cmdline->matchstr('.*\%' .. pos .. 'c')
    # expand `v` into `vim9` at the start of a line
    if before_cursor == 'v'
    # and after a bar
    || before_cursor =~ '|\s*v$'
        return 'vim9'
    else
        return 'v'
    endif
enddef

