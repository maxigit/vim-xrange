function! yrange#ranger#default()
  let start_regexp = '^:\S*:'
  let ranger = {}
  function! ranger.search_start(search_flag) closure
    return search(start_regexp, a:search_flag)
  endfunction
  return ranger
endfunction
