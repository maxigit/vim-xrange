function! yrange#ranger#default()
  let start_regexp_builder = '^:\(%s\):'
  let valid_name = '\S*'
  let end_regexp_builder = '^\.%s\.'
  let ranger = {}

  " --------------------------------------------------
  function ranger.search_start(search_flag,name=valid_name) closure
    let start_regexp = printf(start_regexp_builder, a:name)
    let start = search(start_regexp, a:search_flag)
    if start == 0
      return {}
    endif
    let m = matchlist(getline(start), start_regexp) 
    let name = m[1]
    let result = {'start':start, 'name':name}
    function result.search_end() closure
      let end_regexp = printf(end_regexp_builder, name)
      call setpos('.', [0, start, 0,0] )
      return search(end_regexp,'n')
    endfunction

    return result
    
  endfunction

  " --------------------------------------------------
  function! ranger.search_end(search_flag, name=valid_name) closure
    let end_regexp = printf(end_regexp_builder, a:name)
    return search(end_regexp, a:search_flag)
  endfunction

  " --------------------------------------------------
  return ranger
endfunction
