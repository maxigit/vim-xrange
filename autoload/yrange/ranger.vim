function! yrange#ranger#default()
  let start_regexp = '^:\(\S*\):'
  let end_regexp = '^\.\S*\.'
  let ranger = {}

  " --------------------------------------------------
  function! ranger.search_start(search_flag) closure
    let start = search(start_regexp, a:search_flag)
    if start == 0
      return {}
    endif
    let m = matchlist(getline(start), start_regexp) 
    return {'start':start, 'name':m[1]}
    
  endfunction

  " --------------------------------------------------
  function! ranger.search_end(search_flag) closure
    return search(end_regexp, a:search_flag)
  endfunction

  " --------------------------------------------------
  return ranger
endfunction
