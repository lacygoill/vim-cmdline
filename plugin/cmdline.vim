vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

import MapMeta from 'lg/map.vim'

# Abbreviations {{{1
# Unused_code:{{{
#
#         def StrictAbbr(args: string, search_cmdline = false)
#             var lhs = matchstr(a:args, '^\s*\zs\S\+')
#             var rhs = matchstr(a:args, '^\s*\S\+\s\+\zs.*')
#             if search_cmdline
#                 exe printf("cnorea <expr> %s getcmdtype() =~ '[/?]' ? '%s' : '%s'", lhs, rhs, lhs)
#             else
#                 exe printf("cnorea <expr> %s getcmdtype() == ':' ? '%s' : '%s'", lhs, rhs, lhs)
#             endif
#         enddef
#
#         com -nargs=+ Cab StrictAbbr(<q-args>)
#         com -nargs=+ Sab StrictAbbr(<q-args>, true)
#}}}

# fix some typos
cnorea <expr>  \` getcmdtype() =~ '[/?]' ? '\t' : '\`'

cnorea <expr> soù getcmdtype() =~ ':' && getcmdpos() == 4 ? 'so%' : 'soù'
cnorea <expr> sl getcmdtype() == ':' && getcmdpos() == 3 ? 'ls' : 'sl'
cnorea <expr> hg getcmdtype() == ':' && getcmdpos() == 3 ? 'helpgrep' : 'hg'
cnorea <expr> dig getcmdtype() == ':' && getcmdpos() == 4 ? 'verb Digraphs!' : 'dig'
cnorea <expr> ecoh getcmdtype() == ':' && getcmdpos() == 5 ? 'echo' : 'ecoh'

#         :fbl
#         :FzBLines~
#         :fc
#         :FzCommands~
#         :fl
#         :FzLines~
#         :fs
#         :FzLocate~
cnorea <expr> fbl getcmdtype() == ':' && getcmdpos() == 4 ? 'FzBLines' : 'fbl'
cnorea <expr> fc getcmdtype() == ':' && getcmdpos() == 3 ? 'FzCommands' : 'fc'
cnorea <expr> fl getcmdtype() == ':' && getcmdpos() == 3 ? 'FzLines' : 'fl'
cnorea <expr> fs getcmdtype() == ':' && getcmdpos() == 3 ? 'FzLocate' : 'fs'
#             │
#             └ `fl` is already taken for `:FzLines`
#               besides, we can use this mnemonic: in `fs`, `s` is for ’_s_earch’.

cnorea <expr> ucs getcmdtype() == ':' && getcmdpos() == 4 ? 'UnicodeSearch' : 'ucs'

# Autocmds {{{1

# Do *not* write  a bar after a backslash  on an empty line: it  would result in
# two consecutive bars (empty command).  This would  print a line of a buffer on
# the command-line, when we change the focused window for the first time.
au CmdlineEnter : ++once cmdline#autoUppercase()
    | cmdline#remember(OVERLOOKED_COMMANDS)

augroup HitEnterPrompt | au!
    # Problem: Pressing `q` at the hit-enter prompt quits the latter (✔) and starts a recording (✘).
    # Solution: Install a temporary `q` mapping which presses Escape to quit the prompt.
    # the guard suppresses `E454`; https://github.com/vim/vim/issues/6209
    # Don't use `mode(1)`!{{{
    #
    # When you've run  a command with an output longer  than the current visible
    # screen, and `-- more --` is printed at the bottom, `mode(1)` is `rm`, *not* `r`.
    # By using `mode()` instead of `mode(1)`,  we make sure that our `q` mapping
    # is installed even after executing a command with a long output.
    #}}}
    au CmdlineLeave : if getcmdline() !~ '^\s*fu\%[nction]$'
        |    timer_start(0, () => mode() == 'r' && cmdline#hitEnterPromptNoRecording())
        | endif
augroup END

augroup MyCmdlineChain | au!
    # Automatically execute  command B when A  has just been executed  (chain of
    # commands).  Inspiration:
    # https://gist.github.com/romainl/047aca21e338df7ccf771f96858edb86
    au CmdlineLeave : cmdline#chain()

    # TODO:
    # The following autocmds are not  handled by `cmdline#chain()`, because they
    # don't execute simple Ex commands.
    # Still, it's a bit  weird to have an autocmd handling  simple commands (+ 2
    # less simple), and a bunch of  other related autocmds handling more complex
    # commands.
    #
    # Try to find a way to consolidate all cases in `cmdline#chain()`.
    # Refactor it, so that when it handles complex commands, the code is readable.
    # No long: `if ... | then ... | elseif ... | ... | elseif ... | ...`.

    # sometimes, we type `:h functionz)` instead of `:h function()`
    au CmdlineLeave : if getcmdline() =~ '\C^h\%[elp]\s\+\S\+z)\s*$'
        |     cmdline#fix_typo('z')
        | endif

    # when we copy a line of vimscript and paste it on the command-line,
    # sometimes the newline gets copied and translated into a literal CR,
    # which raises an error; remove it.
    au CmdlineLeave : if getcmdline() =~ '\r$'
        |     cmdline#fix_typo('cr')
        | endif
augroup END

# Command {{{1

# Purpose:{{{
#
# We have several custom mappings in command-line mode.
# Some of them are bound to custom functions.
# They interfere / add noise / bug (`CR`) when we're in debug mode.
# We install this command so that it can  be used to toggle them when needed, in
# other plugins or in our vimrc.
#}}}
# Usage:{{{
#
#     ToggleEditingCommands 0  →  disable
#     ToggleEditingCommands 1  →  enable
#}}}
com -bar -nargs=1 ToggleEditingCommands cmdline#toggleEditingCommands(<args>)

# Mappings {{{1

# Purpose:{{{
#
# By default,  when you search  for a  pattern, C-g and  C-t allow you  to cycle
# through all the matches, without leaving the command-line.
# We remap these commands to Tab and S-Tab on the search command-line.

# Also, on the Ex command-line (:), Tab can expand wildcards.
# But sometimes there are  too many suggestions, and we want to  get back to the
# command-line prior to the expansion, and refine the wildcards.
# We use  our Tab mapping  to save the command-line  prior to an  expansion, and
# install a C-q mapping to restore it.
#}}}
cno <expr><unique> <tab>   cmdline#tab#custom()
cno <expr><unique> <s-tab> cmdline#tab#custom(v:false)
cno       <unique> <c-q>   <c-\>e cmdline#tab#restore_cmdline_after_expansion()<cr>

# Purpose:{{{
#
# - extend `:h c^l` to `:vimgrep` and `:s`
# - capture all paths (files or urls) displayed on the screen in an interactive popup window
#}}}
cno <expr> <c-l> cmdline#c_l#main()

# In vim-readline, we remap `i_C-a` to a readline motion.
# Here, we restore the default `C-a` command (`:h i^a`) by mapping it to `C-x C-a`.
# Same thing with the default `c_C-a` (`:h c^a`).
noremap! <expr><unique> <c-x><c-a> cmdline#unexpand#save_oldcmdline('<c-a>', getcmdline())

# `c_C-a` dumps all the matches on the command-line; let's define a custom `C-x C-d`
# to capture all of them in the unnamed register.
cno <unique> <c-x><c-d> <c-a><cmd>call setreg('"', [getcmdline()], 'l')<cr><c-c>

# Prevent the function from returning anything if we are not in the pattern field of `:vim`.
# The following mapping transforms the command-line in 2 ways, depending on where we press it:{{{
#
#    - on the search command-line, it translates the pattern so that:
#
#        - it's searched outside comments
#
#        - all alphabetical characters are replaced by their corresponding
#        equivalence class
#
#    - on the Ex command-line, if the latter contains a substitution command,
#      inside the pattern, it captures the words written in snake case or
#      camel case inside parentheses, so that we can refer to them easily
#      with backref in the replacement.
#}}}
cno <expr><unique> <c-s> cmdline#transform#main()

# Cycle through a set of arbitrary commands.
cno <unique> <c-g> <c-\>e cmdline#cycle#main#move()<cr>
sil! MapMeta('g', '<c-\>e cmdline#cycle#main#move(v:false)<cr>', 'c', 'u')

xno <unique> <c-g>s :s///g<left><left><left>

def CyclesSet()
    # populate the arglist with:
    #
    #    - all the files in a directory
    #    - all the files in the output of a shell command
    cmdline#cycle#main#set('a',
        'sp <bar> args `=glob(''§./**/*'', 0, 1)->filter({_, v -> filereadable(v)})`',
        'sp <bar> sil args `=systemlist(''§'')`')

    #                       ┌ definition
    #                       │
    cmdline#cycle#main#set('d',
        'Verb nno §',
        'Verb com §',
        'Verb au §',
        'Verb au * <buffer=§>',
        'Verb fu §',
        'Verb fu {''<lambda>§''}')

    cmdline#cycle#main#set('ee',
        'tabe $MYVIMRC§',
        'e $MYVIMRC§',
        'sp $MYVIMRC§',
        'vs $MYVIMRC§')

    cmdline#cycle#main#set('em',
        'tabe /tmp/vimrc§',
        'tabe /tmp/vim.vim§')

    # search a file in:{{{
    #
    #    - the working directory
    #    - ~/.vim
    #    - the directory of the current buffer
    #}}}
    cmdline#cycle#main#set('ef',
        'fin ~/.vim/**/*§',
        'fin *§',
        'fin %:h/**/*§')
    # Why `fin *§`, and not `fin **/*§`?{{{
    #
    # 1. It's useless to add `**` because we already included it inside 'path'.
    #    And `:find` searches in all paths of 'path'.
    #    So, it will use `**` as a prefix.
    #
    # 2. If we used `fin **/*§`, the path of the matches would be relative to
    #    the working directory.
    #    It's too verbose.  We just need their name.
    #
    #     Btw, you may wonder what happens when we type `:fin *bar` and press Tab or
    #    C-d,  while  there  are two  files  with  the  same  name `foobar`  in  two
    #    directories in the working directory.
    #
    #     The answer is  simple: for each match, Vim prepends  the previous path
    #    component to  remove the ambiguity.  If it's  not enough, it goes  on adding
    #    path components until it's not needed anymore.
    #}}}
    cmdline#cycle#main#set('es',
        'sf ~/.vim/**/*§',
        'sf *§',
        'sf %:h/**/*§')
    cmdline#cycle#main#set('ev',
        'vert sf ~/.vim/**/*§',
        'vert sf *§',
        'vert sf %:h/**/*§')
    cmdline#cycle#main#set('et',
        'tabf ~/.vim/**/*§',
        'tabf *§',
        'tabf %:h/**/*§')

    # `:filter` doesn't support all commands.
    # We install a  wrapper command which emulates `:filter` for  the commands which
    # are not supported.
    cmdline#cycle#filter#install()

    # populate the qfl with the output of a shell command
    # Don't merge `-L` and `-S` into `-LS`.{{{
    #
    # It could trigger a bug:
    #
    #     \rg -LS foobar /etc
    #     error: The argument '--follow' was provided more than once, but cannot be used multiple times~
    #}}}
    cmdline#cycle#main#set('g',
        'cgete system("rg 2>/dev/null -L -S --vimgrep ''§''")',
        'lgete system("rg 2>/dev/null -L -S --vimgrep ''§''")',
        )

    # we want a different pattern depending on the filetype
    # we want `:vimgrep` to be run asynchronously
    cmdline#cycle#vimgrep#install()

    cmdline#cycle#main#set('p', 'new<bar>0pu=execute(''§'')')

    # When should I prefer this over `:WebPageRead`?{{{
    #
    # When you need to download code, or when you want to save the text in a file.
    #
    # Indeed, the buffer created by `:WebPageRead`  is not associated to a file,
    # so you can't save it.
    # I you want to save it, you need to yank the text and paste it in another buffer.
    #
    # Besides, the text  is formatted to not go beyond  100 characters per line,
    # which could break some long line of code.
    #}}}
    cmdline#cycle#main#set('r', 'exe ''r !curl -s '' .. shellescape(''§'', 1)')
    #                                           │
    #                                           └ don't show progress meter, nor error messages

    # What's this `let list = ...`?{{{
    #
    # Suppose you have this text:
    #
    #     pat1
    #     text
    #     pat2
    #     text
    #     pat3
    #     text
    #
    #     foo
    #     bar
    #     baz
    #
    # And you want to move `foo`, `bar` and `baz` after `pat1`, `pat2` and `pat3`.
    #
    #    1. yank the `foo`, `bar`, `baz` block
    #
    #    2. visually select the `pat1`, `pat2`, `pat3` block,
    #       then leave to get back to normal mode
    #
    #    3. invoke the substitution command, write `pat\d` at the start of the pattern field, and validate
    #}}}
    # If you think you can merge the two backticks substitutions, try your solution against these texts:{{{
    #
    #     example, ‘du --exclude='*.o'’ excludes files whose names end in
    #
    #     A block size  specification preceded by ‘'’ causes output  sizes to be displayed
    #}}}
    cmdline#cycle#main#set('s',
        '%s/§//g',
        '%s/`\(.\{-}\)''/`\1`/gce <bar> %s/‘\(.\{-}\)’/`\1`/gce',
        'let list = split(@", "\n") <bar> *s/§\zs/\=remove(list, 0)/'
        )
enddef

CyclesSet()

# Variable {{{1

# Commented because the messages are annoying.
# I keep it for educational purpose.

#     const OVERLOOKED_COMMANDS = [
#         {old: 'vs\%[plit]', new: 'C-w v', regex: true},
#         {old: 'sp\%[lit]', new: 'C-w s', regex: true},
#         {old: 'q!', new: 'ZQ', regex: false},
#         {old: 'x', new: 'ZZ', regex: false},
#         ]

const OVERLOOKED_COMMANDS = []

