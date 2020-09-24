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


function! Ranger(nestable=1)
  let first = {'valid_name': '[A-Z]'}
  function first.start_regexp_builder(args)
    return printf('^\s*:\(%s\):\(.*\)',a:args.name)
  endfunction
  function first.end_regexp_builder(args)
    return printf('^\s*.\(%s\).\(.*\)',a:args.name)
  endfunction
  let second = extend({'valid_name':'[a-z]'},first, 'keep')
  let third = extend({'valid_name':'[0-9]'},first, 'keep')
  " throw string(third)
  let second.subranger = yrange#ranger#make_from_pattern(third)
  let first.subranger = yrange#ranger#make_from_pattern(second)
  let second.subranger.ranger_name = "third"
  let first.subranger.ranger_name = "second"
   return yrange#ranger#make_from_pattern(first)
endfunction
" nested : .. * .. +
