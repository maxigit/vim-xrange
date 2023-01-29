let g:xblock_prefix = '!!' 
let g:xblock_default_ranges = #{
      \  in: #{ mode: 'in', start: '^\s*\n\|\%^', default:1 },
      \  data: #{ mode: 'in', start: '\<DATA\>.*\n'},
      \  query: #{ mode: 'in', start: '\<QUERY\>.*\n'},
      \  in2: #{ mode: 'in', start: '^===.*\n'},
      \  last: #{mode: 'in', start: '!!\i*[!:=&{].*\n', force: '1', end: '\n!!^[[:ident:].]'},
      \  BOF: #{ mode: 'in', start: '\%^', force: '1'},
      \  out: #{ mode: 'out'}, 
      \  error: #{ mode: 'error', clearEmpty: 1} }
let g:xblock_default = #{ ranges: g:xblock_default_ranges,
                        \ env: #{last: '?.*\ze\n.*!!^[[:ident:].]*out'
                        \       ,last0: '^out'
                        \       } 
                        \ }
if !exists('g:xblock_commands')
  let g:xblock_commands = {}
endif
let g:xblock_commands['o'] = "!:{ECHO?echo:}: :exe: :{post?%| %s}: >@out 2>@error"
let g:xblock_commands['io'] = "!:{ECHO?echo:}: :exe: <@in :{post?%| %s}: >@out 2>@error"
let g:xblock_commands['i'] = "!:{ECHO?echo:}: :exe: :{post?%| %s}:  @in >@out 2>@error"
let g:xblock_commands['mysql'] = '&io exe:[mysql :OPTIONS: :{unsafe?:--i-am-a-dummy}: :{limit?%--select-limit=%s}: :{t?--table:}: :{e?-E:}: -u$MYSQL_USER -p$MYSQL_PASSWORD -P$MYSQL_PORT -h$MYSQL_HOST $MYSQL_DB] @error.lineNumberFormat:[at line zs\d\+]'
for limit in [1,2, 5, 10,20, 50, 100, 200, 500, 1000]
  let g:xblock_commands['t' .. limit] = '@out.post:tail\ -' .. limit
  let g:xblock_commands['h' .. limit] = '@out.post:head\ -' .. limit
endfor

nnoremap <silent> <space>xx :call yrange#ExecuteCommandUnderCursor()<CR>
nnoremap <silent> <space>xd :call yrange#CommandUnderCursor()->yrange#DeleteOuterRanges()<CR>
nnoremap <silent> <space>xD :call yrange#CommandUnderCursor()->yrange#DeleteCommandAndOuterRanges()<CR>
nnoremap <silent> <space>xn :call yrange#GoToNextCommand()<CR>
nnoremap <silent> <space>xN :call yrange#GoToPreviousCommand()<CR>

" info
nnoremap <silent> <space>xi :call yrange#CommandUnderCursor()->yrange#WithRanges()->yrange#Print()<CR>
nnoremap <silent> <space>xI :echo yrange#CommandUnderCursor()->yrange#Expand()<CR>


nnoremap <silent> [x -:call yrange#GoToCurrentRangeBy('startLine')<CR>
nnoremap <silent> ]x +:call yrange#GoToCurrentRangeBy('endLine')<CR>

