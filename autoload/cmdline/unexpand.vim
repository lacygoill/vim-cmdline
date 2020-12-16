if exists('g:autoloaded_cmdline#unexpand')
    finish
endif
let g:autoloaded_cmdline#unexpand = 1

let s:oldcmdline = ''

augroup ClearCmdlineBeforeExpansion | au!
    au CmdlineLeave : let s:oldcmdline = ''
augroup END

" Interface {{{1
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

