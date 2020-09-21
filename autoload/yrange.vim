
" ==================================================
"            Settings
" ==================================================
" Create initial settings needed
" to call any function
" settings can be nested
" allowing range syntax to change depending on the contect
" a settings is a dict which must contains the following field
" - ranger
"

" Create settings from buffer or global settings
function! yrange#create_setting()
  return {'ranger':yrange#ranger#default()}
endfunction

" create settings if necessary
function! yrange#get_settings(settings)
  if a:settings == {} 
    return yrange#create_setting()
  else
    return a:settings
  endif
endfunction

" ==================================================
"                Range
" ==================================================
" A range corresponds to a ranger of lines
" in text. It is represented a dictionary with the following 
" attributes.
" - name  (if any)
" - header
" - start (first line, including header)
" - end (last line, including footer)
" -  body_start
" -  body_end
" - properties/tag
" - parent
" - children
" - executable ???
" - nestable ???
" - syntax
" - settings (if any) 
"
"   If no range is found {} is return
function! yrange#current_range(settings={})
  let settings = yrange#get_settings(a:settings)
  return yrange#ranger#current_range(settings.ranger)
endfunction


function! yrange#next_range(settings={})
  let range = yrange#ranger#next_range(yrange#get_settings(a:settings).ranger)
  call yrange#moveTo(range, 'start')
endfunction

function! yrange#previous_range(settings={})
  let range = yrange#ranger#previous_range(yrange#get_settings(a:settings).ranger)
  call yrange#moveTo(range, 'start')
endfunction


function! yrange#current_or_parent_range(settings={})
    let save_cursor = getcurpos()
    let ranger = yrange#get_settings(a:settings).ranger
    let current = yrange#ranger#current_range(ranger)
    if empty(current)
      return current
    endif
    let lnum = save_cursor[1]
    if current.start ==  lnum || get(current,'end',0) == lnum
      let parent = yrange#ranger#parent_range(ranger)
      if empty(parent)
        call setpos ('.', save_cursor)
        return current
      else
        return parent
      endif
    endif
    " check  if current line is on the edge
    return current
endfunction
" ================================================== 
"  Operation on range
" ================================================== 
function! yrange#moveTo(range, key)
  let lnum = get(a:range, a:key, 0)
  if empty(lnum)
    return
  else
    call cursor(lnum,0)
  endif
endfunction

function yrange#select(range)
  if !empty(a:range)
    call setpos("'<", [0, a:range.start, 0, 0])
    call setpos("'>", [0, a:range.end, len(getline(a:range.end)), 0])
    normal! gv
  endif
endfunction

" return a range corresponding to the body of a range
"
function yrange#body(range)
  if empty(a:range)
    return {}
  endif
  if !has_key(a:range, 'body_start') && has_key(a:range,'_header')
    call a:range._header()
  endif
  let r = copy(a:range)
  let r.start = get(a:range, 'body_start', a:range.start+1)
  let r.end = a:range.end - 1
  if r.start > r.end
    return {}
  else
    return r
  endif
endfunction
