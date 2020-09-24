" Return the parent ranger (so that the current range
" is can be searched with the subranger of the parent
function yrange#range#parent_ranger(range)
   let parent = yrange#range#parent_range(a:range)
   if empty(parent)
     return {}
   endif
   return parent.ranger
endfunction

function yrange#range#parent_range(range)
  if !has_key(a:range, 'parent')
    let cursor(range.start,0)
    let a:range.parent = yrange#ranger#parent_range(a:range.ranger)
  endif
  return a:range.parent
endfunction
