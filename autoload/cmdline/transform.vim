" TODO:
"
"     :echo map(range(65,90)+range(97,122), {i,v -> nr2char(v)})
"     :echo filter(map(range(65,90)+range(97,122), {i,v -> nr2char(v)}), {i,v -> })
"           ^^^^^^^                                                    ^^^^^^^^^^^^
"           create a transformation to automatically add this
"           make it cycle between `filter()` and `map()`

fu! cmdline#transform#main() abort "{{{1
    " number of times we've transformed the command-line
    let s:did_transform = get(s:, 'did_transform', -1) + 1
    augroup reset_did_tweak
        au!
        " TODO:
        " If we empty the command-line without leaving it, the counter is not reset.
        " So,  once  we've  invoked  this   function  once,  it  can't  be  used
        " anymore until we  leave the command-line.
        " Maybe we should inspect the command-line instead.
        au CmdlineLeave  /,\?,:  unlet! s:did_transform s:orig_cmdline
        \ |                      exe 'au! reset_did_tweak' | aug! reset_did_tweak
    augroup END

    let cmdtype = getcmdtype()
    let cmdline = getcmdline()
    if s:did_transform >= 1 && cmdtype is# ':'
        " If  we invoke  this function  twice on  the same  Ex command-line,  it
        " shouldn't do anything the 2nd time.
        " Because we only have one transformation atm (`s:capture_subpatterns()`),
        " and re-applying it doesn't make sense.
        return ''
    endif

    if cmdtype =~# '[/?]'
        if get(s:, 'did_transform', 0) ==# 0
            let s:orig_cmdline = cmdline
        endif
        call cmdline#util#undo#emit_add_to_undolist_c()
        return "\<c-e>\<c-u>"
        \     .(s:did_transform % 2 ? s:replace_with_equiv_class() : s:search_outside_comments())

    elseif cmdtype =~# ':'
        call cmdline#util#undo#emit_add_to_undolist_c()
        return s:capture_subpatterns()
    else
        return ''
    endif
endfu

fu! s:capture_subpatterns() abort "{{{1
    " If  we're on  the  Ex command-line  (`:`),  we try  and  guess whether  it
    " contains a substitution command.
    let cmdline = getcmdline()
    let pat_range = '\%([%*]\|[^,]*,[^,]*\)'

    if cmdline !~# '^'.pat_range.'s[/:]'
        " if there's no substitution command, don't modify the command-line
        return ''
    endif

    " extract the range, separator and the pattern
    let range = matchstr(cmdline, pat_range)
    let separator = matchstr(cmdline, '^'.pat_range.'s\zs.')
    let pat = split(cmdline, separator)[1]

    " from the pattern, extract words between underscores or uppercase letters:{{{
    "
    "         'OneTwoThree'   → ['One', 'Two', 'Three']
    "         'one_two_three' → ['one', 'two', 'three']
    "}}}
    let subpatterns = split(pat, pat =~# '_' ? '_' : '\ze\u')

    " return the keys to type{{{
    "
    "                            ┌ original pattern, with the addition of parentheses around the subpatterns:
    "                            │
    "                            │          (One)(Two)(Three)
    "                            │    or    (one)_(two)_(three)
    "                            │
    "                            ├──────────────────────────────────────────────────────────────────┐}}}
    let new_cmdline = range.'s/'.join(map(subpatterns, {i,v -> '\('.v.'\)'}), pat =~# '_' ? '_' : '') . '//g'

    return "\<c-e>\<c-u>".new_cmdline
    \     ."\<c-b>".repeat("\<right>", strchars(new_cmdline, 1)-2)
    "      ├─────────────────────────────────────────────────────┘{{{
    "      └ position the cursor between the last 2 slashes
    "}}}
endfu

fu! s:replace_with_equiv_class() abort "{{{1
    return substitute(get(s:, 'orig_cmdline', ''), '\a', '[[=\0=]]', 'g')
endfu

fu! s:search_outside_comments() abort "{{{1
    " we should probably save `cmdline` in  a script-local variable if we want
    " to cycle between several transformations
    if empty(&l:cms)
        return get(s:, 'orig_cmdline', '')
    endif
    let cml = '\V'.escape(matchstr(split(&l:cms, '%')[0], '\S*'), '\').'\m'
    return '\%(^\%(\s*'.cml.'\)\@!.*\)\@<=\m\%('.get(s:, 'orig_cmdline', '').'\)'
    "                                       ├─┘
    "                                       └ Why?{{{
    " The original pattern may contain several branches.
    " In that  case, we want the  lookbehind to be  applied to all of  them, not
    " just the first one.
    "}}}
endfu

fu! cmdline#transform#reset() abort "{{{1
    " called by `readline#undo()`
    " necessary to re-perform a transformation we've undone by mistake
    unlet! s:did_transform
endfu

