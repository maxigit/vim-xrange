let s:start = '#+BEGIN %s'
let s:end =   '#+END%0.s'
let s:start = '<%s>'
let s:end =   '</%s>'
let s:result = '%s_result'

" Create a setting object
function xrange#createSettings(settings={})
  let settings = {}
  for v in ["start", "end", "result"]
    if(has_key(a:settings, v))
      let settings[v] = a:settings[v]
    else
      let settings[v] = get(b:, "xrange_".v, get(g:, "xrange_".v, get(s:, v)))
    endif
  endfor
  return settings
endfunction

function xrange#getOuterRange(settings, name, create_end=0)
  let block_start = printf(a:settings.start, a:name)
  let block_end = printf(a:settings.end, a:name)
  let start = search('^\M'.block_start, 'cw') " wrap if needed and move cursor
  if start > 0
    let end = search('^\M'.block_end, 'nW') " don't wrap, end should be after start
    let next_block = search(s:anyStartRegex(a:settings) .'\|'. s:anyEndRegex(a:settings), 'nW')
    if end > 0 && end <= next_block
      return {'start':start, 'end':end}
    elseif a:create_end
      if next_block == 0
        let end=line('$')
      else
        let end = next_block-1
      endif
      call append(end, block_end)
      return {'start':start, 'end':end+1}
    endif
  endif
  return {}
endfunction


function xrange#innerRange(range)
  if empty(a:range)
    return {}
  endif
  return {'start':a:range.start+1, 'end':a:range.end-1 }
endfunction

function xrange#displayRange(range)
  if empty(a:range)
    throw "Range not found : " . a:range
  else
    return a:range.start ."," .a:range.end
  endif
endfunction

"
function xrange#executeLine(settings, line, extract_vim="")
    " remove zone at the begining
    " allows to write tho code on the same line
  call xrange#executeLines(a:settings, a:line, a:line, a:extract_vim . '\%(' .s:anyStartRegex(a:settings) .'\)\?')
endfunction

function s:executeLine(settings, line, extract_vim)
  if match(a:line, a:extract_vim) != -1
    let line = substitute(a:line, a:extract_vim, "","")
    let statements = split(substitute(line, a:extract_vim, "",""), ';')
    for statement in statements
      let tokens = xrange#splitRanges(statement)
      call join(map(tokens, function('xrange#expandZone', [a:settings])), " ")
      execute join(tokens, '')
    endfor
    return line
  endif
 return ""
endfunction
function xrange#splitRanges(line) 
  let matches = matchlist(a:line, '\([^@]*\)\(@[a-zA-Z0-9-_:]\+[$^*%@''<>{}!&-]\)\(.*\)')
  if empty(matches)
    return [a:line]
  else
    return [matches[1], matches[2]]+xrange#splitRanges(matches[3])
  end
endfunction

function xrange#expandZone(settings, key, token)
      let matches = matchlist(a:token, '^@\([a-zA-Z0-9-_:]\+\)\([$^*%@''<>{}!&-]\)$')
      if empty(matches)
          return a:token
      else
        let name = matches[1]
        let range = xrange#getOuterRange(a:settings, name)
        if empty(range)
          throw  "Range not found : " . name
        endif
        let mode = matches[2]
        if mode == '^'
          return range.start
        elseif mode == '$'
          return range.end
        elseif mode == '{'
          return range.start+1
        elseif mode == '}'
          return range.end-1
        elseif mode == '*'
          return range->xrange#innerRange()->xrange#displayRange()
        elseif mode == '%'
          return range->xrange#displayRange()
        elseif mode == '<'
          return s:createFileForRange(name, a:settings,  'in')
        elseif mode == '>'
          return s:createFileForRange(name, a:settings,  'out')
        elseif mode == '@'
          return s:createFileForRange(name, a:settings,  'error')
        elseif mode == '&'
          call s:readRange(name, a:settings) " synchronize 
          return ""
        elseif mode == '!'
          " return "call xrange#executeRangeByName('".name."')"
          return xrange#executeRangeByName(name, a:settings)
        elseif mode == '-'
          call xrange#deleteInnerRange(name, a:settings)
          return range->xrange#innerRange()->xrange#displayRange()
        elseif mode == '''' 
          return '@'. name
        endif
      endif
endfunction

" Execute the code in inner range
" unless there is code after the range start
" allow to write how to use the code on the same line
" Example
" <query> @execut_query!
" ...
" </query>
function xrange#executeRangeByName(name, settings, extract_vim="")
  let range = xrange#getOuterRange(a:settings, a:name)
  if empty(range)
    echoerr "Can't execute range " . a:name
    return 
  endif 
  let first_line = getline(range.start)
  if first_line =~ a:extract_vim . s:anyStartRegex(a:settings) . '\s*\S\+'
    call xrange#executeLine(a:settings, range.start, a:extract_vim)
  else
    let range = xrange#innerRange(range)
    call xrange#executeLines(a:settings, range.start, range.end, a:extract_vim)
  endif
endfunction

function xrange#executeLines(settings, start, end, extract_vim="")
  if exists('b:file_dict')
    let recursive = 1
  else 
    let recursive = 0
    let b:file_dict = {}
  endif
  for line in getline(a:start, a:end)
    call s:executeLine(a:settings, line, a:extract_vim)
  endfor
  " update all modified file
  if !recursive
  for range in keys(b:file_dict)
    call s:readRange(range, a:settings)
  endfor
    unlet b:file_dict
  end
  call setpos('.', [0,a:start,0,0])
endfunction

function xrange#executeCurrentRange(settings)
  call xrange#findCurrentRange(a:settings)->xrange#executeRangeByName(a:settings)
endfunction

function xrange#deleteCurrentRange(settings)
  call xrange#findCurrentRange(a:settings)->xrange#deleteInnerRange(a:settings)
endfunction

function xrange#deleteRangeUnderCursor(settings)
  call xrange#deleteInnerRange(a:settings, expand("<cword>"))
endfunction

function xrange#anyStartRegex(settings)
  return s:anyStartRegex(a:settings)
endfunction
function s:anyStartRegex(settings)
  return '^\M'. printf(a:settings.start,'\m\(\f\+\>\)\M') . '\m'
endfunction

function xrange#anyEndRegex(settings) 
  return s:anyEndRegex(a:settings)
endfunction
function s:anyEndRegex(settings) 
  return '^\M'. printf(a:settings.end,'\m\(\f\+\>\)\M') . '\m'
endfunction


function xrange#findCurrentRange(settings)
  let start = search(s:anyStartRegex(a:settings), "nbWc")
  if start == 0
    return ""
  end
  let matches = matchlist(getline(start),s:anyStartRegex(a:settings))
  return matches[1]
endfunction
      
function xrange#deleteInnerRange(name, settings)
  let range = xrange#getOuterRange(a:settings, a:name)->xrange#innerRange()
  if !empty(range) && range.end >= range.start
    call deletebufline("%",range.start, range.end)
    return 0
  end
  return 1
endfunction

function s:createFileForRange(name, settings, mode)
  if b:file_dict->has_key(a:name)
    return b:file_dict[a:name].path
  else
  let range = xrange#getOuterRange(a:settings, a:name, 1)->xrange#innerRange()
  let tmp = tempname()
  if a:mode == 'in' && !empty(range) && range.end >= range.start
    call s:executeLine(a:settings, '@'.a:name.'*w! ' . tmp,"")
  endif
  let b:file_dict[a:name] = {'path':tmp, 'mode':a:mode}
  return tmp
  endif
endfunction

function s:readRange(name, settings)
  if(b:file_dict->has_key(a:name))
    let file = b:file_dict[a:name]
    if file.mode != 'in'
      call xrange#deleteInnerRange(a:name, a:settings)
      call s:executeLine(a:settings, '@'.a:name.'^r ' . file.path, "")
      if file.mode == 'error'
        " load the error and adjust the line number
        let range = xrange#getOuterRange(a:settings, a:name)
        execute "lgetfile " . file.path
        if !empty(range)
          "let offset = range.start
          "let errors = getloclist(0)
          "for e in errors
          "  e.module = a:name
          "  e.lnum += offset
          "endfor
          "call setloclist(0,errors)
        endif
      endif
    endif
    unlet b:file_dict[a:name]
    call delete(file.path)
  endif
endfunction 


function xrange#createRange(name, settings, code='')
  if empty(xrange#getOuterRange(a:settings, a:name, 1))
    call append(line('.'), [printf(a:settings.start, a:name) . a:code, printf(a:settings.end, a:name)])
  endif
  normal j 
endfunction

function xrange#createNewRange()
  call xrange#createRange(input("Range? "))
endfunction


function xrange#createResultRange(settings)
  let name = xrange#findCurrentRange(a:settings)
  let range = xrange#getOuterRange(a:settings, name)
  if !empty(range)
    call setpos('.', [0,range.end,0,0])
    call xrange#createRange(a:settings, xrange#resultName(name), ' @'.name.'!')
  endif
endfunction

function xrange#resultName(name)
    return printf(a:settings.result, a:name)
endfunction
