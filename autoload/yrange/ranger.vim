function! yrange#ranger#default()
  let start_regexp = '^:\S*:'
  let start_regexp = '^.\S*.'
  let ranger = {}

  " --------------------------------------------------
  function! ranger.search_start(search_flag) closure
    return search(start_regexp, a:search_flag)
  endfunction

  " --------------------------------------------------
  function! ranger.search_end(search_flag) closure
    return search(end_regexp, a:search_flag)
  endfunction

  " --------------------------------------------------
  return ranger
endfunction
