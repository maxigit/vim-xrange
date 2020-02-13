let s:start_prefix = "<"
let s:start_suffix = ">"
let s:end_prefix = "</"
let s:end_suffix = ">"

" Make sure all buffer variables are initialed
function s:init()
  if(!exists("b:embed_done"))
    for v in ["start_prefix", "end_prefix", "start_suffix", "end_suffix"]
      if(exists("g:embed_".v))
        let b:{v} = g:embed_{v}
      else
        let b:{v} = s:{v}
      endif
    endfor
  endif
endfunction

function xrange#getOuterRange(name, create_end=0)
  call s:init()
  let block_start = b:start_prefix . a:name . b:start_suffix
  let block_end = b:end_prefix . a:name . b:end_suffix
  let start = search('^'.block_start, 'cw') " wrap if needed and move cursor
  if start > 0
    let end = search('^'.block_end, 'nW') " don't wrap, end should be after start
    let next_block = search('^'.b:start_prefix.'\|'.b:end_prefix.'$', 'nW')
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
function xrange#executeLine(line, extract_vim="")
  call s:init()
    " remove zone at the begining
    " allows to write tho code on the same line
  call xrange#executeLines(a:line, a:line, a:extract_vim . '\%(' .xrange#anyStartRegex() .'\)\?')
endfunction

function s:executeLine(line, extract_vim)
  call s:init()
  if match(a:line, a:extract_vim) != -1
    let line = substitute(a:line, a:extract_vim, "","")
    let statements = split(substitute(line, a:extract_vim, "",""), ';')
    for statement in statements
      let tokens = xrange#splitRanges(statement)
      call join(map(tokens, function('xrange#expandZone')), " ")
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

function xrange#expandZone(key, token)
      let matches = matchlist(a:token, '^@\([a-zA-Z0-9-_:]\+\)\([$^*%@''<>{}!&-]\)$')
      if empty(matches)
          return a:token
      else
        let name = matches[1]
        let range = xrange#getOuterRange(name)
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
          return s:createFileForRange(name, 'in')
        elseif mode == '>'
          return s:createFileForRange(name, 'out')
        elseif mode == '@'
          return s:createFileForRange(name, 'error')
        elseif mode == '&'
          call s:readRange(name) " synchronize 
          return ""
        elseif mode == '!'
          return "call xrange#executeRangeByName('".name."')"
        elseif mode == '-'
          call xrange#deleteInnerRange(name)
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
function xrange#executeRangeByName(name, extract_vim="")
  let range = xrange#getOuterRange(a:name)
  if empty(range)
    echoerr "Can't execute range " . a:name
    return 
  endif 
  let first_line = getline(range.start)
  if first_line =~ a:extract_vim . xrange#anyStartRegex() . '\s*\S\+'
    call xrange#executeLine(range.start, a:extract_vim)
  else
    let range = xrange#innerRange(range)
    call xrange#executeLines(range.start, range.end, a:extract_vim)
  endif
endfunction

function xrange#executeLines(start, end, extract_vim="")
  call s:init()
  if exists('b:file_dict')
    let recursive = 1
  else 
    let recursive = 0
    let b:file_dict = {}
  endif
  for line in getline(a:start, a:end)
    call s:executeLine(line, a:extract_vim)
  endfor
  " update all modified file
  if !recursive
  for range in keys(b:file_dict)
    call s:readRange(range)
  endfor
    unlet b:file_dict
  end
  call setpos('.', [0,a:start,0,0])
endfunction

function xrange#executeCurrentRange()
  call xrange#findCurrentRange()->xrange#executeRangeByName()
endfunction

function xrange#deleteCurrentRange()
  let range = xrange#findCurrentRange()->xrange#deleteInnerRange()
endfunction

function xrange#deleteRangeUnderCursor()
  let range = xrange#deleteInnerRange(expand("<cword>"))
endfunction

function xrange#anyStartRegex()
  return '^'.b:start_prefix.'\(\f\+\)'.b:start_suffix
endfunction
function xrange#findCurrentRange()
  call s:init()
  let start = search(xrange#anyStartRegex(), "nbWc")
  if start == 0
    return ""
  end
  let matches = matchlist(getline(start),xrange#anyStartRegex())
  return matches[1]
endfunction
      
function xrange#deleteInnerRange(name)
  let range = xrange#getOuterRange(a:name)->xrange#innerRange()
  if !empty(range) && range.end > range.start
    call deletebufline("%",range.start, range.end)
    return 0
  end
  return 1
endfunction

function s:createFileForRange(name, mode)
  if b:file_dict->has_key(a:name)
    return b:file_dict[a:name].path
  else
  let range = xrange#getOuterRange(a:name, 1)->xrange#innerRange()
  let tmp = tempname()
  if a:mode == 'in' && !empty(range) && range.end >= range.start
    call s:executeLine('@'.a:name.'*w! ' . tmp,"")
  endif
  let b:file_dict[a:name] = {'path':tmp, 'mode':a:mode}
  return tmp
  endif
endfunction

function s:readRange(name)
  if(b:file_dict->has_key(a:name))
    let file = b:file_dict[a:name]
    if file.mode != 'in'
      call xrange#deleteInnerRange(a:name)
      call s:executeLine('@'.a:name.'^r ' . file.path, "")
      if file.mode == 'error'
        " load the error and adjust the line number
        let range = xrange#getOuterRange(a:name)
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
