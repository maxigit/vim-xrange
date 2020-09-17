function! yrange#settings#default()
  let start_regexp = '^:\S*:'
  let settings = {}
  function! settings.search_start(search_flag) closure
    return search(start_regexp, a:search_flag)
  endfunction
  return settings
endfunction
