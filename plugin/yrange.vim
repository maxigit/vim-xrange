function s:initBuffer()
  let b:xblock_prefix = '!!' 
  let b:xblock_default_ranges = #{ in: #{ mode: 'in', start: '^\n\|\%^' },
        \  data: #{ mode: 'in', start: 'DATA'},
        \  BOF: #{ mode: 'in', start: '\%^'},
        \  out: #{ mode: 'out'}, 
        \  error: #{ mode: 'error'} }
  let b:xblock_default = #{ ranges: b:xblock_default_ranges }
endfunction

augroup yrange
   autocmd BufNewFile,BufCreate * call s:initBuffer()
augroup END


nnoremap <silent> <space>xx :call yrange#ExecuteCommandUnderCursor()


