" A ranger is a dictonary whith functions
" to find a create new range. Rangers can be combined
" to be nested or used as alternative.
"
"
" Search start result
" A dictonary with
" - start : line where the range start
" - name : name of the range
" - search_end function to search for the end

function! yrange#ranger#default(nestable=1)
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
    if a:nestable 
      let result.subranger = yrange#ranger#default(a:nestable)
    endif
    
    function result.search_end(search_flag) closure
      let end_regexp = printf(end_regexp_builder, name)
      return search(end_regexp,a:search_flag)
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

" --------------------------------------------------
"       Ormode
"
function! yrange#ranger#org_header(start_level=1)
  let start_regexp_builder = '^\(\*\{%d,}\) \(%s\)'
  let valid_name = '\S[^:]*'
  let end_regexp_builder = '\%(\n\*\{,%d} \|\%%$\)'
  "                                  ^        ^^     end of file
  "                                  |        +--   double % for printf
  "                                  +-----------   higher level
  let ranger = {'level':a:start_level}

  " --------------------------------------------------
  function ranger.search_start(search_flag,name=valid_name) closure
    let start_regexp = printf(start_regexp_builder, a:start_level, a:name)
    let start = search(start_regexp, a:search_flag)
    if start == 0
      return {}
    endif
    let m = matchlist(getline(start), start_regexp) 
    let name = m[2]
    let level = len(m[1])
    let result = {'start':start, 'name':name, 'subranger':yrange#ranger#org_header(level+1)}
    function result.search_end(search_flag) closure
      let end_regexp = printf(end_regexp_builder, level)
      return search(end_regexp,a:search_flag)
    endfunction

    return result
    
  endfunction
  " --------------------------------------------------
  return ranger
endfunction
