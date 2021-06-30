vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

var oldcmdline: string

augroup ClearCmdlineBeforeExpansion | autocmd!
    autocmd CmdlineLeave : oldcmdline = ''
augroup END

# Interface {{{1
def cmdline#unexpand#saveOldcmdline( #{{{2
    cmdline: string,
    key: string
): string

    SaveRef = function(Save, [key, cmdline])
    autocmd CmdlineChanged : ++once SaveRef()
    return key
enddef
var SaveRef: func(string, string)

def Save(key: string, cmdline: string)
    if key == "\<C-A>" || key == nr2char(&wildcharm != 0 ? &wildcharm : &wildchar)
        oldcmdline = cmdline
    endif
enddef

def cmdline#unexpand#getOldcmdline(): string #{{{2
    return oldcmdline
enddef

def cmdline#unexpand#clearOldcmdline() #{{{2
    oldcmdline = ''
enddef

