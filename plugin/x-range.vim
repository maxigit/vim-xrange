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

function GetOuterRange(name, create_end=0)
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


function InnerRange(range)
  if empty(a:range)
    return {}
  endif
  return {'start':a:range.start+1, 'end':a:range.end-1 }
endfunction

function DisplayRange(range)
  if empty(a:range)
    throw "Range not found : " . a:range
  else
    return a:range.start ."," .a:range.end
  endif
endfunction

function CreateRange(name, comment=1)
  if empty(GetOuterRange(a:name, 1))
    let block_start = WrapInComment(b:start_prefix . a:name . b:start_suffix, a:comment)
    let block_end = WrapInComment(b:end_prefix . a:name . b:end_suffix, a:comment)
    call append(line('.'), [block_start, block_end])
  endif
endfunction

function WrapInComment(string, comment)
  if a:comment && &commentstring != ""
    return printf(&commentstring, a:string)
  else
    return a:string
  endif
endfunction

function ExecuteLine(line, extract_vim="")
  call s:init()
    " remove zone at the begining
    " allows to write tho code on the same line
  call ExecuteLines(a:line, a:line, a:extract_vim . '\%(' .AnyStartRegex() .'\)\?')
endfunction

function s:executeLine(line, extract_vim)
  call s:init()
  if match(a:line, a:extract_vim) != -1
    let line = substitute(a:line, a:extract_vim, "","")
    let statements = split(substitute(line, a:extract_vim, "",""), ';')
    for statement in statements
      let tokens = SplitRanges(statement)
      call join(map(tokens, function('ExpandZone')), " ")
      execute join(tokens, '')
    endfor
    return line
  endif
 return ""
endfunction
function SplitRanges(line) 
  let matches = matchlist(a:line, '\([^@]*\)\(@[a-zA-Z0-9-_:]\+[$^*%@''<>{}!&-]\)\(.*\)')
  if empty(matches)
    return [a:line]
  else
    return [matches[1], matches[2]]+SplitRanges(matches[3])
  end
endfunction

function ExpandZone(key, token)
      let matches = matchlist(a:token, '^@\([a-zA-Z0-9-_:]\+\)\([$^*%@''<>{}!&-]\)$')
      if empty(matches)
          return a:token
      else
        let name = matches[1]
        let range = GetOuterRange(name)
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
          return range->InnerRange()->DisplayRange()
        elseif mode == '%'
          return range->DisplayRange()
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
          return "call ExecuteRangeByName('".name."')"
        elseif mode == '-'
          call DeleteInnerRange(name)
          return range->InnerRange()->DisplayRange()
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
function ExecuteRangeByName(name, extract_vim="")
  let range = GetOuterRange(a:name)
  if empty(range)
    echoerr "Can't execute range " . a:name
    return 
  endif 
  let first_line = getline(range.start)
  if first_line =~ a:extract_vim . AnyStartRegex() . '\s*\S\+'
    call ExecuteLine(range.start, a:extract_vim)
  else
    let range = InnerRange(range)
    call ExecuteLines(range.start, range.end, a:extract_vim)
  endif
endfunction

function ExecuteLines(start, end, extract_vim="")
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

function ExecuteCurrentRange()
  call FindCurrentRange()->ExecuteRangeByName()
endfunction

function DeleteCurrentRange()
  let range = FindCurrentRange()->DeleteInnerRange()
endfunction

function DeleteRangeUnderCursor()
  let range = DeleteInnerRange(expand("<cword>"))
endfunction

function AnyStartRegex()
  return '^'.b:start_prefix.'\(\f\+\)'.b:start_suffix
endfunction
function FindCurrentRange()
  call s:init()
  let start = search(AnyStartRegex(), "nbWc")
  if start == 0
    return ""
  end
  let matches = matchlist(getline(start),AnyStartRegex())
  return matches[1]
endfunction
      
function DeleteInnerRange(name)
  let range = GetOuterRange(a:name)->InnerRange()
  if !empty(range) && range.end > range.start
    call deletebufline("%",range.start, range.end)
    return 0
  end
  return 1
endfunction

" Create a tmp file and load with the range content if needed
nnoremap <leader>xm :call ExecuteRangeByName("main")<CR>
function s:createFileForRange(name, mode)
  if b:file_dict->has_key(a:name)
    return b:file_dict[a:name].path
  else
  let range = GetOuterRange(a:name, 1)->InnerRange()
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
      call DeleteInnerRange(a:name)
      call s:executeLine('@'.a:name.'^r ' . file.path, "")
      if file.mode == 'error'
        " load the error and adjust the line number
        let range = GetOuterRange(a:name)
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

command -nargs=1 DeleteRange DeleteInnerRange("<args>")

nnoremap <leader>xm :call ExecuteRangeByName("main")<CR>
nnoremap <leader>xx :call ExecuteCurrentRange()<CR>
nnoremap <leader>xe m`:call ExecuteLine('.')<CR>``j
nnoremap <leader>xd :call DeleteCurrentRange()<CR>
nnoremap <leader>xD e:call DeleteRangeUnderCursor()<CR>
nnoremap <leader>xi :echo FindCurrentRange()<CR>
nnoremap <leader>xg e:execute GetOuterRange(expand('<cword>')).start<CR>
nnoremap <leader>x! e:call ExecuteRangeByName(expand('<cword>'))<CR><C-O>

call s:init()

finish
<data>
3
4
10
</data>
<main> @data*w !awk -f @main< > @output> ; @output&; @output*>; @output*>
// {print $1+5}
</main>
<output> @main!
    8
    9
    15
</output>

<sql> !mysql -h127.0.0.1 -uroot -P3308 -pstag fa <@sql< > @output>
select * from 0_gl_trans
limit 50
</sql>

<p>
@data-
@sql*m@data^
