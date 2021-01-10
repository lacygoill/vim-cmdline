def cmdline#util#undo#emitAddToUndolistC() #{{{1
    # We want to be able to undo the transformation.
    # We emit  a custom event, so  that we can  add the current line  to our
    # undo list in `vim-readline`.
    if exists('#User#AddToUndolistC')
        do <nomodeline> User AddToUndolistC
    endif
enddef

