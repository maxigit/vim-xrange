nnoremap <silent> \h :call yrange#moveTo(yrange#current_or_parent_range(),'start')<CR>
nnoremap <silent> \l :call yrange#moveTo(yrange#current_or_parent_range(),'end')<CR>
nnoremap <silent> \n :call yrange#next_range()<CR>
nnoremap <silent> \N :call yrange#previous_range()<CR>
nnoremap <silent> \i :echo yrange#current_or_parent_range()<CR>



