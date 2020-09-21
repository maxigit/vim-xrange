" Navigation
noremap <silent> \h :call yrange#moveTo(yrange#current_or_parent_range(),'start')<CR>
noremap <silent> \l :call yrange#moveTo(yrange#current_or_parent_range(),'end')<CR>
noremap <silent> \n :call yrange#next_range()<CR>
noremap <silent> \N :call yrange#previous_range()<CR>
noremap <silent> \i :echo yrange#current_or_parent_range()<CR>

" Object operator
vnoremap <silent> ax :<C-U>call yrange#select(yrange#current_range())<CR>
vnoremap <silent> aX :<C-U>call yrange#select(yrange#current_or_parent_range())<CR>
vnoremap <silent> ix :<C-U>call yrange#select(yrange#body(yrange#current_range()))<CR>
onoremap <silent> ax :call yrange#select(yrange#current_range())<CR>
onoremap <silent> Ax :call yrange#select(yrange#current_or_parent_range())<CR>
onoremap <silent> ix :call yrange#select(yrange#body(yrange#current_range()))<CR>


