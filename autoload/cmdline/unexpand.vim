vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

var oldcmdline: string

augroup ClearCmdlineBeforeExpansion | au!
    au CmdlineLeave : oldcmdline = ''
augroup END

# Interface {{{1
fu cmdline#unexpand#save_oldcmdline(key, cmdline) abort "{{{2
    fu! s:save() abort closure
        if a:key is# "\<c-a>" || a:key is# nr2char(&wcm ? &wcm : &wc)
            let s:oldcmdline = a:cmdline
        endif
    endfu
    au CmdlineChanged : ++once call s:save()
    return a:key
endfu

fu cmdline#unexpand#get_oldcmdline() abort "{{{2
    return get(s:, 'oldcmdline', '')
endfu

fu cmdline#unexpand#clear_oldcmdline() abort "{{{2
    let s:oldcmdline = ''
endfu

