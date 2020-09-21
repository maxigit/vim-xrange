function yrange#header#default(start, headline)
  let header_regexp = '^\s*|\s*\(.*\)'
  let lines = []
  if !empty(a:headline)
    call add(lines, a:headline)
  endif
  let lnum = a:start
  while  1
    let lnum+=1
    let m = matchlist(getline(lnum), header_regexp)
    if empty(m)
      break
    else
      call add(lines, m[1])
    endif
  endwhile
  return {'header': lines, 'end':lnum -1}
endfunction
