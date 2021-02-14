vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# TEST:
#
# https://unix.stackexchange.com/
# ~/.vim/vimrc
# ~/.vim/vimrc line 123

const URL: string = '\%(https\=\|ftps\=\|www\)://\S\+'

# Interface {{{1
def cmdline#c_l#main(): string #{{{2
    if getcmdtype() != ':'
        return "\<c-l>"
    endif
    if getcmdline()->empty()
        return InteractivePaths()
    endif
    var col: number = getcmdpos()
    # `:123lvimgrepadd!`
    var pat: string = '^\m\C[: \t]*\d*l\=vim\%[grepadd]!\=\s\+'
        # opening delimiter
        .. '\(\i\@!.\)'
        # the pattern; stopping at the cursor because it doesn't make sense
        # to consider what comes after the cursor during a completion
        .. '\zs.\{-}\%' .. col .. 'c\ze.\{-}'
        # no odd number of backslashes before the closing delimiter
        .. '\%([^\\]\\\%(\\\\\)*\)\@<!'
        # closing delimiter
        .. '\1'
        # flags
        .. '[gj]\{,2}\s'
        # `:%s/pat/rep/g`
        .. '\|s\(\i\@!.\)\zs.\{-}\%' .. col .. 'c\ze.\{-}\2.\{-}\2'
        # `:h :s_flags`
        .. '[cegn]\{,4}\%($\|\s\||\)'
        # `:helpg pat`
        .. '\|\%(helpg\%[rep]\|l\%[helpgrep]\)\s\+\zs.*'
    var list: list<string> = getcmdline()->matchlist(pat)
    if list == []
        return "\<c-l>"
    endif
    pat = list[0]
    var delim: string = list[1]
    # Warning: this search is sensitive to the values of `'ignorecase'` and `'smartcase'`
    var pos: list<number> = searchpos(pat, 'n')
    var lnum: number = pos[0]
    col = pos[1]
    if [lnum, col] == [0, 0]
        return ''
    endif
    var match: string = getline(lnum)->matchstr('.*\%' .. col .. 'c\zs.*')
    var suffix: string = substitute(match, '^' .. pat, '', '')
    if suffix == ''
        return ''
    # escape the same characters as the default `C-l` in an `:s` command
    elseif suffix[0] =~ '[$*.:[\\' .. delim .. '^~]'
        return '\' .. suffix[0]
    else
        return suffix[0]
    endif
enddef
# Why don't you support `:vim pat` (without delimiters)?{{{
#
# It  would be  tricky because  in that case,  Vim updates  the position  of the
# cursor after every inserted character.
#
# MWE:
#
#     $ cat <<'EOF' >/tmp/vim.vim
#         set is
#         cno <expr> <c-l> C_l()
#         fu C_l()
#             echom getpos('.')
#             return ''
#         endfu
#     EOF
#
#     $ vim -Nu NONE -S /tmp/vim.vim /tmp/vim.vim
#     :vim /c/
#     " press C-l while the cursor is right before `c`
#     [0, 1, 1, 0]~
#     " the cursor didn't move
#     :vim c C-l
#     [0, 2, 6, 0]~
#     " the cursor *did* move
#}}}
#}}}1
# Core {{{1
def InteractivePaths(): string #{{{2
    var lines: string = Getlines()
    var paths: list<string> = ExtractPaths(lines)
    var urls: list<string> = copy(paths)
        ->filter((_, v) => v =~ URL)
    var paths_with_lnum: list<string> = copy(paths)
        ->filter((_, v) => v !~ URL && v =~ '\s\+line\s\+\d\+$')
    var paths_without_lnum: list<string> = copy(paths)
        ->filter((_, v) => v !~ URL && v =~ '\%\(\s\+line\s\+\d\+\)\@<!$')
    AlignFields(paths_with_lnum)
    var maxwidth: number = mapnew(urls + paths_with_lnum + paths_without_lnum,
        (_, v) => strchars(v, true))->max()
    var what: list<string> = urls
        + (!empty(urls) && !empty(paths_with_lnum) ? [repeat('─', maxwidth)] : [])
        + paths_with_lnum
        + (!empty(paths_with_lnum) && !empty(paths_without_lnum) ? [repeat('─', maxwidth)] : [])
        + paths_without_lnum
    if empty(what)
        return ''
    endif
    Popup = () => popup_menu(what, {
        highlight: 'Normal',
        borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
        maxwidth: maxwidth,
        maxheight: &lines / 2,
        filter: Filter,
        callback: function(Callback, [what]),
        })
    if !empty(paths)
        if mode() =~ 'c'
            redraw
            # Don't use a timer.{{{
            #
            # It would cause too many  weird issues, triggered by mappings which
            # should be ignored, but are not.
            # https://github.com/vim/vim/issues/7011#issuecomment-700981791
            #}}}
            au SafeState * ++once Popup()
        else
            Popup()
        endif
    endif
    return "\<c-\>\<c-n>"
enddef

var Popup: func(): number

def Getlines(): string #{{{2
    var lines: list<string>
    var line: list<string>
    for row in range(1, &lines)
        line = []
        for col in range(1, &columns)
            line += [screenstring(row, col)]
        endfor
        lines += [join(line, '')]
    endfor
    return join(lines, "\n")
enddef

def ExtractPaths(lines: string): list<string> #{{{2
    var paths: list<string>
    var pat: string = URL .. '\|\f\+\%(\s\+line\s\+\d\+\)\='
    var Rep: func = (m: list<string>): string =>
        add(paths, m[0])->string()
    # a side-effect of this substitution is to invoke `add()` to populate `paths`
    substitute(lines, pat, Rep, 'g')
    filter(paths, (_, v) =>
            v =~ '^' .. URL .. '$'
        ||
            v =~ '/'
        &&
            substitute(v, '\s\+line\s\+\d\+$', '', '')
            ->expand()
            ->filereadable()
        )
        ->uniq()
    return paths
enddef

def AlignFields(paths: list<string>) #{{{2
    var path_width: number = mapnew(paths,
            (_, v) => strchars(v, true))
        ->max()
    var lnum_width: number = mapnew(paths,
            (_, v) => matchstr(v, '\s\+line\s\+\zs\d\+$')->strchars(true))
        ->max()
    map(paths, (_, v) => Aligned(v, path_width, lnum_width))
enddef

def Aligned(path: string, path_width: number, lnum_width: number): string #{{{2
    var matchlist: list<string> = matchlist(path, '\(.*\)\s\+line\s\+\(\d\+\)$')
    var actualpath: string = matchlist[1]
    var lnum: number = matchlist[2]->str2nr()
    return printf('%-*s line %*d', path_width, actualpath, lnum_width, lnum)
enddef

def Filter(winid: number, key: string): bool #{{{2
    if key == 'q'
        popup_close(winid, -1)
        return true
    endif
    return popup_filter_menu(winid, key)
enddef

def Callback(paths: list<string>, _w: any, choice: number) #{{{2
    if choice == -1 || paths[choice - 1] =~ '^[-─]\+$'
        return
    endif
    var chosen: string = paths[choice - 1]
    var pat: string = '\(.\{-}\)\%(\s\+line\s\+\(\d\+\)\)\=$'
    var matchlist: list<string> = matchlist(chosen, pat)
    var fpath: string = matchlist[1]
    var lnum: string = matchlist[2]
    if chosen =~ '^' .. URL .. '$'
        system('xdg-open ' .. chosen)
    else
        # Alternative:{{{
        #
        #     exe 'sp ' .. fpath
        #     exe printf('au SafeState * ++once keepj norm! %szvzz',
        #         empty(lnum) ? '' : lnum .. 'G')
        #}}}
        exe printf('sp +exe\ "keepj\ norm!\ %szvzz" %s',
            !empty(lnum) ? lnum .. 'G' : '', fpath)
    endif
enddef

