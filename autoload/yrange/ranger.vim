" A ranger is a dictonary with functions
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
  let params = { 'valid_name': '\S*' } " empty names are allowed }
  function  params.start_regexp_builder(args)
    return printf('^:\(%s\):\%%( \+\(.*\)\)\?', a:args.name)
  endfunction
  function params.end_regexp_builder(args)
    return printf('^\.%s\.',a:args.name)
  endfunction
  if a:nestable
    let params.subranger='self'
  endif
  return yrange#ranger#make_from_pattern(params)
endfunction

function! yrange#ranger#make_from_pattern(args)
  let ranger = {}
  " --------------------------------------------------
  function ranger.search_start(search_flag,name=a:args.valid_name, stopline=v:none) closure
    let params = {'name': a:name }
    let start_regexp = a:args.start_regexp_builder(params)
    let start = search(start_regexp, a:search_flag,a:stopline)
    if start == 0
      return {}
    endif
    let m = matchlist(getline(start), start_regexp) 
    let name = m[get(a:args, 'name_index',1)]
    let headline = m[get(a:args, 'header_index',2)]
    let result = {'start':start, 'name':name,'headline':headline}

    if has_key(a:args, 'subranger')
      let subranger = a:args.subranger
      if type(subranger) == type('') && subranger == 'self'
        let result.subranger = ranger
      else
        let result.subranger = subranger " (result)
      endif
    endif

    function result.search_end(search_flag, stopline=v:none) closure
      let end_params = {'name': name, 'start':start}
      let end_regexp = a:args.end_regexp_builder(end_params)
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
"  Don't look within subranger
function yrange#ranger#search_range(ranger, search_flag, name=v:none,stopline=v:none)
  let start = a:ranger.search_start(a:search_flag,a:name,a:stopline)
  if empty(start)
    return {}
  endif
  let start.ranger = a:ranger
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


" Find the most nested range under cursor
function yrange#ranger#current_range(ranger,stopline=v:none,current_line=line('.'))
  let save_cursor = getcurpos()
  let range=  yrange#ranger#search_range(a:ranger,'cbW',v:none, a:stopline)
  "                                         ^  backward, match cursor
  while 1
    if empty(range)
      break
    endif
    if has_key(range,'end')
       if range.end >= a:current_line
         " found, check for nested range
         call setpos('.', save_cursor)
         if has_key(range, 'subranger')
           let sub = yrange#ranger#current_range(range.subranger,range.start+1,a:current_line)
           if !empty(sub)
             " The sub range can be deeply nested
             " so we can't not just set its parent
             "  we need to find instead the direct child
             "  of the current ranger
             let top_sub = sub
             while has_key(top_sub,'parent')
               let top_sub = top_sub.parent
             endwhile
             let top_sub.parent = range
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

function yrange#ranger#parent_range(ranger,stopline=v:none)
  let current = yrange#ranger#current_range(a:ranger,a:stopline)
  if empty(current)
    return {}
  endif

  let lnum = current.start
  if lnum==1
    return {}
  else
  call cursor(lnum-1,0)
  return yrange#ranger#current_range(a:ranger, a:stopline, lnum)
endfunction


" Find next most nested range next to cursor
function yrange#ranger#next_range(ranger,stopline=v:none, search_nested=1)
  let save_cursor = getcurpos()
  let next = yrange#ranger#search_range(a:ranger,'',v:none, a:stopline) " use default wrapscan options
  " check if there is a nested one
  if a:search_nested 
    " set to 0 avoid infinite recursion. We only search one nested
    " any way the next level of nested would be after
    " the beginning nesting region.
    call setpos('.',save_cursor)
    let current = yrange#ranger#current_range(a:ranger)
    while !empty(current)
      if has_key(current,'subranger') 
        call setpos('.',save_cursor)
        let next_sub = yrange#ranger#next_range(current.subranger, get(current,'end', v:none), 0)
        " check if the next sub if before or after then next one
        if has_key(next_sub, 'start')
          if next_sub.start < next.start || next.start <= save_cursor[1]
            "                                wrapped so in theory after
            return next_sub
          endif
        endif
      endif
      let current = yrange#range#parent_range(current)
    endwhile
  endif
  return next
endfunction

function yrange#ranger#previous_range(ranger, stopline=v:none, search_nested=1)
  let save_cursor = getcurpos()
  let previous = yrange#ranger#search_range(a:ranger,'b',v:none, a:stopline,) " use default wrapscan options

  " check if there is a nested one
  if !empty(previous) 
    " && previous.start < save_cursor[1] " not wrapped
    let previous_is_wrapped = previous.start >= save_cursor[1]
    let ranger = previous
  else
    let wrapped = 1
    let ranger ={}
  endif
  while has_key(ranger,'subranger')
    let ranger = ranger.subranger
    call setpos('.', save_cursor)
    let stop= previous.start+1
    if previous_is_wrapped 
      let stop = v:none
    end
    let next_nested = yrange#ranger#previous_range(ranger,stop)
    " echoe ranger save_cursor next_nested
    if empty(next_nested)
      break
    endif
    let nest_is_wrapped = next_nested.start >= save_cursor[1] 
    "    nested/previous | not wrapped | wrapped
    "    --------------------------------------
    "    not wrapped     | greatest    | nested
    "    wrapped         | previous    | greatest
    "    gerates is always nested, so previous
    "    is only use in not_wrapped wrapped
    "
    if previous_is_wrapped || !nest_is_wrapped
      let previous = next_nested
    endif
  endwhile
  return previous
endfunction


