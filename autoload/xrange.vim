let s:start = '#+BEGIN %s'
let s:end =   '#+END%0.s'
let s:start = '<%s>'
let s:end =   '</%s>'
let s:result = '%s:out'
let s:strip = '\%(^\s*[#*/"!:<>-]\+\s\+\|^\)' " something followed with a space or nothing
let s:macros = {'comment': {'sw': '/^-- //e', 'sr': '/^/-- /e'}}

" Create a setting object
function xrange#createSettings(settings={})
  let settings = {'ranges':[]}
  for v in ['start', 'end', 'result', 'strip', 'macros']
    if(has_key(a:settings, v))
      let settings[v] = a:settings[v]
    else
      let settings[v] = get(b:, "xrange_".v, get(g:, "xrange_".v, get(s:, v)))
    endif
  endfor
  return settings
endfunction

" Get a range by name and creates it's end if needed.
" create_end can be either '$' (end of file or next block)
" or '}' just after beginin
" or '.' current line
" or '' don't create
function xrange#getOuterRange(settings, name, create_end='')
  let current_line = line('.')
  let block_start = printf(a:settings.start, a:name)
  let block_end = printf(a:settings.end, a:name)
  let start = search(a:settings.strip.'\M'.block_start, 'cw') " wrap if needed and move cursor
  if start > 0
    let end = search(a:settings.strip.'\M'.block_end, 'nW') " don't wrap, end should be after start
    let next_block = search(s:anyStartRegex(a:settings) .'\|'. s:anyEndRegex(a:settings), 'nW')
    if end > 0 && end <= next_block
      return {'start':start, 'end':end}
    elseif a:create_end != ''
      if a:create_end == '}'
        let end = start
      elseif a:create_end == '.'
        let end = current_line
      elseif next_block == ''
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
function xrange#executeLine(settings, line, strip=a:settings.strip)
    " remove zone at the begining
    " allows to write tho code on the same line
  call xrange#executeLines(a:settings, a:line, a:line, a:strip . '\%(' .s:anyStartRegex(a:settings, '') .'\)\?')
endfunction

function s:executeLine(settings, line, strip)
  if match(a:line, a:strip) != -1
    let line = substitute(a:line, a:strip, "","")
    let statements = split(line, ';')
    for statement in statements
      let tokens = xrange#splitRanges(statement)
      call join(map(tokens, function('xrange#expandZone', [a:settings])), " ")
      execute join(tokens, '')
    endfor
    return line
  endif
 return ""
endfunction
let s:operators = '[$^*%@''<>{}!&-]'
function xrange#splitRanges(line) 
  let matches = matchlist(a:line, '\([^@]*\)\(@[a-zA-Z0-9-_:]\{-}+\?'.s:operators.'\+\)\(.*\)')
  if empty(matches)
    return [a:line]
  else
    return [matches[1], matches[2]]+xrange#splitRanges(matches[3])
  end
endfunction

function xrange#expandZone(settings, key, token)
      let current_range = get(a:settings.ranges, 0 , "")
      let matches = matchlist(a:token, '^@\([a-zA-Z0-9_:<>-]\{-}\)\(+\?\)\('.s:operators.'\+\)$')
      if empty(matches)
          return a:token
      else
        let name = matches[1]
        let modes = matches[3]
        " expand name if needed
        if name[0] == ':'
          let name = current_range . name
        elseif name == ''
          let name = current_range
        endif

        let range = xrange#getOuterRange(a:settings, name)
        if empty(range)
          if matches[2] == '+'
            call xrange#createRange(a:settings, name)
            let range = xrange#getOuterRange(a:settings, name)
          else
            throw  "Range not found : " . name
          endif
        endif
        let result = ''
        for mode in split(modes, '\zs')
          if mode == '^'
            return range.start
          elseif mode == '$'
            let result =  range.end
          elseif mode == '{'
            let result = range.start+1
          elseif mode == '}'
            let result = range.end-1
          elseif mode == '*'
            let result = range->xrange#innerRange()->xrange#displayRange()
          elseif mode == '%'
            let result = range->xrange#displayRange()
          elseif mode == '<'
            let result = s:createFileForRange(name, a:settings,  'in')
          elseif mode == '>'
            let result = s:createFileForRange(name, a:settings,  'out')
          elseif mode == '@'
            let result = s:createFileForRange(name, a:settings,  'error')
          elseif mode == '&'
            call s:readRange(name, a:settings) " synchronize 
            let range = xrange#getOuterRange(a:settings, name, 1)
            let result = ""
          elseif mode == '!'
            " let result = "call xrange#executeRangeByName('".name."')"
            let result = xrange#executeRangeByName(name, a:settings)
          elseif mode == '-'
            call xrange#deleteInnerRange(name, a:settings)
            " update range
            let range = xrange#getOuterRange(a:settings, name)
            let result = range->xrange#innerRange()->xrange#displayRange()
          elseif mode == '''' 
            let result = '@'. name
          endif
        endfor
        return result
      endif
endfunction

" Execute the code in inner range
" unless there is code after the range start
" allow to write how to use the code on the same line
" Example
" <query> @execut_query!
" ...
" </query>
"  mode can be
"    confirm : ask confirmation (implies silent)
"    silent: don't throw an error if not present
function xrange#executeRangeByName(name, settings, strip=a:settings.strip, mode='')
  let range = xrange#getOuterRange(a:settings, a:name, '}')
  if empty(range)
    if a:mode == ''
      echoerr "Can't execute range " . a:name
    endif
    return 
  endif 
  if a:mode == 'confirm'
    if input("Execute xrange: ". a:name . "[y/n]?") !~ '\cy\(es\)\?'
      return
    endif
  endif
  " add range to ranges stack
  call insert(a:settings.ranges, a:name)
  let first_line = substitute(getline(range.start), a:strip . s:anyStartRegex(a:settings, '') . '\s*', '', '')
  let tags = xrange#extractTags(first_line, a:settings.macros)
  if tags.x != ''
    call xrange#executeRawLines(a:settings, [tags.x], a:strip) 
  else
    let range = xrange#innerRange(range)
    call xrange#executeLines(a:settings, range.start, range.end, a:strip)
  endif
  call remove(a:settings.ranges,0)
endfunction

function xrange#executeLines(settings, start, end, strip=a:settings.strip)
  return xrange#executeRawLines(a:settings, getline(a:start, a:end), a:strip)
endfunction
function xrange#executeRawLines(settings, lines, strip=a:settings.strip)
  let pos = getpos('.')
  if exists('b:file_dict')
    let recursive = 1
  else 
    let recursive = 0
    let b:file_dict = {}
  endif
  for line in a:lines
    call s:executeLine(a:settings, line, a:strip)
  endfor
  " update all modified file
  if !recursive
  for range in keys(b:file_dict)
    call s:readRange(range, a:settings)
  endfor
    unlet b:file_dict
  end
  call setpos('.', pos)
endfunction

function xrange#executeCurrentRange(settings)
  call xrange#findCurrentRange(a:settings)->xrange#executeRangeByName(a:settings)
endfunction

function xrange#deleteCurrentRange(settings)
  call xrange#findCurrentRange(a:settings)->xrange#deleteInnerRange(a:settings)
endfunction

function xrange#deleteRangeUnderCursor(settings)
  call xrange#deleteInnerRange(expand("<cword>"), a:settings)
endfunction

function xrange#anyStartRegex(settings)
  return s:anyStartRegex(a:settings)
endfunction
function s:anyStartRegex(settings, start=a:settings.strip)
  return a:start . '\M'. printf(a:settings.start,'\m\([a-zA-Z0-9_.:-]*\>\)\M') . '\m'
endfunction

function xrange#anyEndRegex(settings) 
  return s:anyEndRegex(a:settings)
endfunction
function s:anyEndRegex(settings, start=a:settings.strip) 
  return a:start . '\M'. printf(a:settings.end,'\m\([a-zA-Z0-9_.:-]*\>\)\M') . '\m'
endfunction


function xrange#findCurrentRange(settings)
  let current_line = line('.')
  let start = search(s:anyStartRegex(a:settings), "nbWc") " don't move, backaward, no wrap accept curors
  let end = search(s:anyEndRegex(a:settings), "nbW")
  if start == 0
    return ""
  elseif end != 0 && start < end " we are not within a range
    " the start we found has an end we are outside
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
    call xrange#createRange(a:settings, a:name, '')
    let range = xrange#getOuterRange(a:settings, a:name, '}')->xrange#innerRange()
    let tmp = tempname()
    if a:mode == 'in' " && !empty(range) && range.end >= range.start
      call s:saveRange(a:name, tmp, a:settings)
      " call s:executeLine(a:settings, 'silent @'.a:name.'*w! ' . tmp,"")
    endif
    let b:file_dict[a:name] = {'path':tmp, 'mode':a:mode}
    return tmp
  endif
endfunction

" Write the content of the range to a file
" preprocess it depending on the value of the tags
" pre: vim code to execute first
" shell: shell command to run through
function s:saveRange(name, file,  settings)
  let range = xrange#getOuterRange(a:settings, a:name, '}')->xrange#innerRange()
  if empty(range)
    return 
  endif
  let line = substitute(getline(range.start-1), a:settings.strip . s:anyStartRegex(a:settings, '') . '\s*', '', '')
  let tags = xrange#extractTags(line, a:settings.macros)

  let do_undo = 0
  if has_key(tags, 'pre')
    " execute the code and undo it afterward
    if range.end > range.start
      let do_undo = 1
      for pre in tags.pre
        call s:executeLine(a:settings, pre, '')
      endfor
    endif
  endif

      echomsg "TAG" tags
  if has_key(tags, 'sw')
    " execute the code and undo it afterward
    if range.end > range.start
      let do_undo = 1
      for s in tags.sw
        execute range.start "," range.end " s" s
      endfor
    endif
  endif
  if has_key(tags, 'aw') " all
    " execute the code and undo it afterward
    if range.end > range.start
      let do_undo = 1
      for s in tags.aw
        execute range.start "," range.end s
      endfor
    endif
  endif

  let commands = ['cat']
  if has_key(tags, 'w')
    for w in tags.w
      call add(commands, w)
    endfor
  endif

  let command = printf("silent %d,%dw !%s > %s", range.start, range.end, join(commands, ' | '), a:file)

  "call s:executeLine(a:settings, command, '')
  execute l:command
  if do_undo
    undo
  endif

endfunction

function s:readRange(name, settings, keep=0)
  if(b:file_dict->has_key(a:name))
    let file = b:file_dict[a:name]
    if file.mode == 'out'  || file.mode == 'error'
      call xrange#deleteInnerRange(a:name, a:settings)
      let range = xrange#getOuterRange(a:settings, a:name)
      let first_line = substitute(getline(range.start), a:settings.strip . s:anyStartRegex(a:settings, '') . '\s*', '', '')
      let tags = xrange#extractTags(first_line, a:settings.macros)


      let commands = []
      if has_key(tags, 'r')
        for r in tags.r
          call add(commands, tags.r)
        endfor
      endif
      if empty(commands)
        call s:executeLine(a:settings, 'silent @'.a:name.'^r ' . file.path, "")
      else
        call s:executeLine(a:settings, 'silent @'.a:name.'^r !cat ' . file.path . " | " . join(commands, '|'), "")
      endif
      let inner = xrange#getOuterRange(a:settings, a:name)->xrange#innerRange()

      if has_key(tags, 'sr')
        " execute the code and undo it afterward
        if inner.end > inner.start
          for s in tags.sr
            execute inner.start "," inner.end " s" s
          endfor
        endif
      endif
      if has_key(tags, 'ar')
        " execute the code and undo it afterward
        if inner.end > inner.start
          for s in tags.ar
            execute inner.start "," inner.end s
          endfor
        endif
      endif
      if has_key(tags, 'post')
        " execute the code and undo it afterward
        for post in tags.post
          call s:executeLine(a:settings, post, '')
        endfor
      endif

      if file.mode == 'error'
        " load the error and adjust the line number
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
    if  a:keep
      let file.mode = 'done'
    else
      unlet b:file_dict[a:name]
      call delete(file.path)
    endif
  endif
endfunction 


function xrange#createRange(settings, name, code='')
  if empty(xrange#getOuterRange(a:settings, a:name, '}'))
    " find next space outside a range
    " so that ranges are not nested
     let current_range = xrange#getOuterRange(a:settings, xrange#findCurrentRange(a:settings))
     while !empty(current_range)
       execute current_range.end+1
       let current_range = xrange#getOuterRange(a:settings, xrange#findCurrentRange(a:settings))
     endwhile
      call append(line('.'), [printf(a:settings.start, a:name) . a:code, printf(a:settings.end, a:name)])
  endif
  normal j 
endfunction

function xrange#createNewRange(settings)
  call xrange#createRange(a:settings, input("Range? "))
endfunction


function xrange#createResultRange(settings)
  let name = xrange#findCurrentRange(a:settings)
  let range = xrange#getOuterRange(a:settings, name)
  if !empty(range)
    call setpos('.', [0,range.end,0,0])
    call xrange#createRange(a:settings, xrange#resultName(a:settings, name), ' @'.name.'!')
  endif
endfunction

function xrange#resultName(settings, name)
    return printf(a:settings.result, a:name)
endfunction

function xrange#closeCurrentRange(settings)
  let name = xrange#findCurrentRange(a:settings)
  let range = xrange#getOuterRange(a:settings, name, '.')
  execute range.end
endfunction

function xrange#rangeList(settings)
  let pos = getpos('.')
  let results = []
  let last_range = ''
  execute '0' 
  while 1
    let match = search(xrange#anyStartRegex(a:settings), 'W')
    let range = xrange#findCurrentRange(a:settings)
    if range == '' || range == last_range
      break
    endif
    let last_range = range
    call add(results, range)
  endwhile
  call setpos('.', pos)
  return results
endfunction


" check if word under cursor is a valid range and 
" expand it if necessary
function xrange#rangeUnderCursor(settings, check=1)
  let pos = getpos('.')
  let full_word = expand('<cWORD>')
  let word = expand('<cword>')
  " expand short hand for @: and @ etc ...
  if full_word =~ '@\W'
    let current_range = xrange#findCurrentRange(a:settings)
    let range_name = substitute(full_word, '^@', current_range,'')
  else
    let range_name = substitute(full_word, '^@', '', '')
  endif
  "clean  end
  let range = substitute(range_name, s:operators.'.*$', '', '')
  " check the range exists
  if a:check && empty(xrange#getOuterRange(a:settings, range))
    let range = word
    if empty(xrange#getOuterRange(a:settings, range))
      let range = ''
    endif
  endif
  call setpos('.', pos)
  return range
endfunction

function xrange#gotoUnderCursor(settings)
  let range = xrange#rangeUnderCursor(a:settings)
  if empty(range)
    return
  endif
  execute xrange#getOuterRange(a:settings, range).start
endfunction

function xrange#executeUnderCursor(settings)
  let range = xrange#rangeUnderCursor(a:settings)
  if empty(range)
    return
  endif
  execute xrange#executeRangeByName(range, a:settings)
endfunction

" Extracts a dictionary of tag starting with +
"  if no tags is provided the left over will be assigned to the +code tag.
"  Tags can be repeated
"  The syntax is the following
"  +tag a b +tag c +tag2 d +tag3+ x code
"  Will generate
"  { tag: ["a b", "c"]
"  , tag2: ["d"]
"  , tag3: [] not value
"  , x: 'code'
"  }
function xrange#extractTags(line, macros)
  if match(a:line, '^\s*+') == -1
    " not tags
    return {'x': substitute(a:line, '^\s*', '', '')}
  endif
  let result = {'x':[]}
  let tags = split(a:line, '\s\+\ze+')
  for tag_value in tags
    let matches = matchlist(tag_value, '^+\(\i\+\)\([+-]\?\)\s*\(.*\)')
    if matches == []
      " no tag
      let result.x.= tag
    else
      let tag = matches[1]
      let closed = matches[2]
      let value = matches[3]
      if closed == '+'
        " the tag has no value
        call add(result.x, value)
        " expand macro
        let macro = get(a:macros, tag, {})
        let result[tag] = []
        for m in keys(macro)
          if has_key(result, m)
            call add(result[m], macro[m])
          else
            let result[m] = [macro[m]]
          endif
        endfor
      elseif closed == '-'
        " the tag has no value
        call add(result.x, value)
        if has_key(result,tag)
          unlet result[tag]
        endif
      else
        if has_key(result, tag)
          call add(result[tag], value)
        else
          let result[tag]=[value]
        endif
      endif
    endif
  endfor
  let result.x = join(result.x, ' ; ')
  return result
endfunction

function xrange#currentRangeInfo(settings)
  let name = xrange#findCurrentRange(a:settings)
  let range= xrange#getOuterRange(a:settings, name)
  if !empty(range)
    let first_line = substitute(getline(range.start), a:settings.strip . s:anyStartRegex(a:settings, '') . '\s*', '', '')
    let tags = xrange#extractTags(first_line, a:settings.macros)
    return {'name':name, 'range':range, 'tags':tags}
  endif
endfunction
