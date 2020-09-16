vim9script

# TEST:
#
# https://unix.stackexchange.com/
# ~/.vim/vimrc
# ~/.vim/vimrc line 123

const! URL = '\%(https\=\|ftps\=\|www\)://\S\+'

# Interface {{{1
def cmdline#c_l#main(): string #{{{2
    if getcmdtype() != ':' | return "\<c-l>" | endif
    if getcmdline()->empty()
        return InteractivePaths()
    endif
    let col = getcmdpos()
    # `:123lvimgrepadd!`
    let pat = '^\m\C[: \t]*\d*l\=vim\%[grepadd]!\=\s\+'
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
    let list = getcmdline()->matchlist(pat)
    if list == [] | return "\<c-l>" | endif
    pat = list[0]
    let delim = list[1]
    # Warning: this search is sensitive to the values of `'ignorecase'` and `'smartcase'`
    let pos = searchpos(pat, 'n')
    let lnum = pos[0]
    col = pos[1]
    if [lnum, col] == [0, 0] | return '' | endif
    let match = getline(lnum)->matchstr('.*\%' .. col .. 'c\zs.*')
    let suffix = substitute(match, '^' .. pat, '', '')
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
#     [0, 2, 1, 0]~
#     " the cursor didn't move
#     :vim c C-l
#     [0, 2, 14, 0]~
#     " the cursor *did* move
#}}}
#}}}1
# Core {{{1
def InteractivePaths(): string #{{{2
    let lines = Getlines()
    let paths = Extract_paths(lines)
    let urls = copy(paths)
        ->filter({_, v -> v =~ URL})
    let paths_with_lnum = copy(paths)
        ->filter({_, v -> v !~ URL && v =~ '\s\+line\s\+\d\+$'})
    let paths_without_lnum = copy(paths)
        ->filter({_, v -> v !~ URL && v =~ '\%\(\s\+line\s\+\d\+\)\@<!$'})
    Align_fields(paths_with_lnum)
    let maxwidth = map(urls + paths_with_lnum + paths_without_lnum,
        {_, v -> strchars(v, 1)})->max()
    let what = urls
        + (!empty(urls) && !empty(paths_with_lnum) ? [repeat('─', maxwidth)] : [])
        + paths_with_lnum
        + (!empty(paths_with_lnum) && !empty(paths_without_lnum) ? [repeat('─', maxwidth)] : [])
        + paths_without_lnum
    if empty(what)
        return ''
    endif
    let Popup = {-> popup_menu(what, #{
        highlight: 'Normal',
        borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
        maxwidth: maxwidth,
        maxheight: &lines / 2,
        filter: Filter,
        callback: function('Callback', [what]),
        })}
    if !empty(paths)
        if mode() =~ 'c'
            redraw
            timer_start(0, Popup)
        else
            Popup()
        endif
    endif
    return "\<c-\>\<c-n>"
enddef

def Getlines(): string #{{{2
    let lines: list<string>
    let line: list<string>
    for row in range(1, &lines)
        line = []
        for col in range(1, &columns)
            line += [screenstring(row, col)]
        endfor
        lines += [join(line, '')]
    endfor
    return join(lines, "\n")
enddef

def Extract_paths(lines: string): list<string> #{{{2
    let paths: list<string>
    let pat = URL .. '\|\f\+\%(\s\+line\s\+\d\+\)\='
    let Rep = {m -> add(paths, m[0])->string()}
    substitute(lines, pat, Rep, 'g')
    filter(paths, {_, v ->
            v =~ '^' .. URL .. '$'
        ||
            v =~ '/'
        &&
            substitute(v, '\s\+line\s\+\d\+$', '', '')
            ->expand()
            ->filereadable()
        })
        ->uniq()
    return paths
enddef

def Align_fields(paths: list<string>) #{{{2
    let path_width = copy(paths)
        ->map({_, v -> strchars(v, 1)})
        ->max()
    let lnum_width = copy(paths)
        ->map({_, v -> matchstr(v, '\s\+line\s\+\zs\d\+$')->strchars(1)})
        ->max()
    map(paths, {_, v -> Aligned(v, path_width, lnum_width)})
enddef

def Aligned(path: string, path_width: number, lnum_width: number): string #{{{2
    let matchlist = matchlist(path, '\(.*\)\s\+line\s\+\(\d\+\)$')
    let actualpath = matchlist[1]
    let lnum = matchlist[2]->str2nr()
    return printf('%-*s line %*d', path_width, actualpath, lnum_width, lnum)
enddef

def Filter(winid: number, key: string): bool #{{{2
    if key == "\e" || key == 'q'
        popup_close(winid, -1)
        return true
    endif
    return popup_filter_menu(winid, key)
enddef

def Callback(paths: list<string>, _w: any, choice: number) #{{{2
    if choice == -1 || paths[choice - 1] =~ '^[-─]\+$'
        return
    endif
    let chosen = paths[choice - 1]
    let pat = '\(.\{-}\)\%(\s\+line\s\+\(\d\+\)\)\=$'
    let matchlist = matchlist(chosen, pat)
    let fpath = matchlist[1]
    let lnum = matchlist[2]
    if chosen =~ '^' .. URL .. '$'
        system('xdg-open ' .. chosen)
    else
        let cmd = printf('sp +exe\ "keepj\ norm!\ %szvzz" %s',
            !empty(lnum) ? lnum .. 'G' : '', fpath)
        exe cmd
    endif
enddef

