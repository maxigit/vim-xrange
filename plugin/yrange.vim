let g:xblock_prefix = '!!' 
let g:xblock_default_ranges = #{
      \  in: #{ mode: 'in', start: '^\s*\n\|\%^' },
      \  data: #{ mode: 'in', start: '\<DATA\>.*\n'},
      \  BOF: #{ mode: 'in', start: '\%^'},
      \  out: #{ mode: 'out'}, 
      \  error: #{ mode: 'error'} }
let g:xblock_default = #{ ranges: g:xblock_default_ranges }
if !exists('g:xblock_commands')
  let g:xblock_commands = {}
endif
let g:xblock_commands['mysql'] = "!mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -P$MYSQL_PORT -h$MYSQL_HOST $MYSQL_DB <@in >@out 2>@error"

nnoremap <silent> <space>xx :call yrange#ExecuteCommandUnderCursor()<CR>


