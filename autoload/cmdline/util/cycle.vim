fu! cmdline#util#cycle#find_tabstop(rhs) abort "{{{1
    " Why not simply `return stridx(a:rhs, '@')`?{{{
    "
    " The rhs may contain special sequences such as `<bar>` or `<c-r>`.
    " They need to be translated first.
    "}}}
    exe 'nno <plug>(cycle-find-tabstop) :'.a:rhs
    return stridx(maparg('<plug>(cycle-find-tabstop)'), '@')
endfu

