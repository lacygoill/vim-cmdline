" Interface {{{1
fu! cmdline#cycle#substitute#install() abort "{{{2
    call cmdline#cycle#main#set('s',
        \ '<c-r>='.s:snr().'filetype_specific_substitute()<cr>@',
        \ '%s/`.\{-}\zs''/`/gc',
        \ )
endfu
" }}}1
" Core {{{1
fu! s:filetype_specific_substitute() abort "{{{2
    if &bt is# 'quickfix' && get(b:, 'qf_is_loclist', 0)
        if type(getloclist(0, {'context': 0}).context) == type({})
        \ && has_key(getloclist(0, {'context': 0}).context, 'populate')
            return getloclist(0, {'context': 0}).context.populate
        endif
    elseif &bt is# 'quickfix' && !get(b:, 'qf_is_loclist', 0)
        if type(getqflist({'context': 0}).context) == type({})
        \ && has_key(getqflist({'context': 0}).context, 'populate')
            return getqflist({'context': 0}).context.populate
        endif
    endif
    return '%s///g'
endfu
" }}}1
" Utilities {{{1
fu! s:snr() abort "{{{2
    return matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_')
endfu

