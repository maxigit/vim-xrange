let g:xblock_prefix = '!!' 
let g:xblock_default_ranges = #{
      \  in: #{ mode: 'in', start: '^\s*\n\|\%^' },
      \  data: #{ mode: 'in', start: '\<DATA\>.*\n'},
      \  BOF: #{ mode: 'in', start: '\%^'},
      \  out: #{ mode: 'out'}, 
      \  error: #{ mode: 'error'} }
let g:xblock_default = #{ ranges: g:xblock_default_ranges,
                        \ env: #{last: '?.*\ze\n.*!!^[[:ident:].]*out'
                        \       ,last0: '^out'
                        \       } 
                        \ }
if !exists('g:xblock_commands')
  let g:xblock_commands = {}
endif
let g:xblock_commands['mysql'] = "pre= post= options= !$pre mysql $options -u$MYSQL_USER -p$MYSQL_PASSWORD -P$MYSQL_PORT -h$MYSQL_HOST $MYSQL_DB $post <@in >@out 2>@error"
let g:xblock_commands['mysql'] = "pre= post= options= !$pre mysql $options -u$MYSQL_USER -p$MYSQL_PASSWORD -P$MYSQL_PORT -h$MYSQL_HOST $MYSQL_DB $post <@in >@out 2>@error"

nnoremap <silent> <space>xx :call yrange#ExecuteCommandUnderCursor()<CR>
nnoremap <silent> <space>xd :call yrange#CommandUnderCursor()->yrange#DeleteOuterRanges()<CR>
nnoremap <silent> <space>xD :call yrange#CommandUnderCursor()->yrange#DeleteCommandAndOuterRanges()<CR>
nnoremap <silent> <space>xn :call yrange#GoToNextCommand()<CR>
nnoremap <silent> <space>xN :call yrange#GoToPreviousCommand()<CR>


