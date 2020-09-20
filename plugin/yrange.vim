nnoremap <silent> \o :call yrange#moveTo(yrange#current_range(),'start')<CR>
nnoremap <silent> \O :call yrange#moveTo(yrange#current_range(),'end')<CR>
nnoremap <silent> \n :call yrange#next_range()<CR>
nnoremap <silent> \N :call yrange#previous_range()<CR>


