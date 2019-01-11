fu! cmdline#util#undo#emit_add_to_undolist_c() abort "{{{1
    " We want to be able to undo the transformation.
    " We emit  a custom event, so  that we can  add the current line  to our
    " undo list in `vim-readline`.
    if exists('#User#add_to_undolist_c')
        do <nomodeline> User add_to_undolist_c
    endif
endfu

