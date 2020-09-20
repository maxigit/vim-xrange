" A ranger is a dictonary whith functions
" to find a create new range. Rangers can be combined
" to be nested or used as alternative.
" - search_start
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
  function ranger.search_start(search_flag,name=valid_name, stopline=v:none) closure
    let start_regexp = printf(start_regexp_builder, a:name)
    let start = search(start_regexp, a:search_flag,a:stopline)
    if start == 0
      return {}
    endif
    let m = matchlist(getline(start), start_regexp) 
    let name = m[1]
    let result = {'start':start, 'name':name}
    if a:nestable 
      let result.subranger = yrange#ranger#default(a:nestable)
    endif
    
    function result.search_end(search_flag, stopline=v:none) closure
      let end_regexp = printf(end_regexp_builder, name)
      return search(end_regexp,a:search_flag, a:stopline)
    endfunction

    return result
    
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
  function ranger.search_start(search_flag,name=valid_name,stopline=v:none) closure
    let start_regexp = printf(start_regexp_builder, a:start_level, a:name)
    let start = search(start_regexp, a:search_flag, a:stopline)
    if start == 0
      return {}
    endif
    let m = matchlist(getline(start), start_regexp) 
    let name = m[2]
    let level = len(m[1])
    let result = {'start':start, 'name':name, 'subranger':yrange#ranger#org_header(level+1)}
    function result.search_end(search_flag, stopline=v:none) closure
      let end_regexp = printf(end_regexp_builder, level)
      return search(end_regexp,a:search_flag, a:stopline)
    endfunction

    return result
    
  endfunction
  " --------------------------------------------------
  return ranger
endfunction

" --------------------------------------------------
"  Common ranger function
"  Find a range, its start and end if possible
function yrange#ranger#search_range(ranger, search_flag, name=v:none,stopline=v:none)
  let start = a:ranger.search_start(a:search_flag,a:name,a:stopline)
  if empty(start)
    return {}
  endif
  " Look for the end
  let end_line = start.search_end('Wn')
  if end_line == 0
    return start
  end
  " no wrap don't move
  " try next sibling
  call cursor(start.start+1,0)
  let next = yrange#ranger#search_range(a:ranger,'Wn', v:none, end_line)
  if empty(next)
    let start.end = end_line
    return start
  endif
  if !has_key(next,'end')
      let start.end = end_line
      return start
  endif
  " let's try to find an end after the range
  call cursor(next.end+1,0)
  let new_end = start.search_end('Wn')
  if new_end == 0
    " no other end let's use the first one
    let start.end = end_line
    return start
  else
    let start.end = new_end
    return start
  endif
  return {}
endfunction


function yrange#ranger#current_range(ranger,stopline=v:none)
  let save_cursor = getcurpos()
  let current_line = save_cursor[1]
  let range=  yrange#ranger#search_range(a:ranger,'cbW',v:none, a:stopline)
  "                                         ^  backward, match cursor
  while 1
    if empty(range)
      break
    endif
    if has_key(range,'end')
       if range.end >= current_line
         " found, check for nested range
         call setpos('.', save_cursor)
         if 0
           " has_key(range, 'subranger')
           let sub = yrange#ranger#current_range(range.subranger,v:none,range.start+1)
           if !empty(sub)
             let range= sub
           endif
         endif
         break
       else " range too small
         " start searching above it
         if range.start>1
           call cursor(range.start-1,0)
           let range = yrange#ranger#search_range(a:ranger,'cbW',v:none,a:stopline)
         else " can't go up give up
           let range={}
           break
         endif
       endif
    else " not found search for parent
       let range={}
       break
    endif
  endwhile

  call setpos('.', save_cursor)
  return range
endfunction
