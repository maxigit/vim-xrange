" command -nargs=1 DeleteRange :call xrange#deleteInnerRange("<args>")

nnoremap <leader>xm :call xrange#executeRangeByName("main", xrange#createSettings())<CR>
nnoremap <leader>xx :call xrange#createSettings()->xrange#executeCurrentRange()<CR>
nnoremap <leader>xe m`:call xrange#createSettings()->xrange#executeLine('.')<CR>``j
nnoremap <leader>xd :call xrange#createSettings()->xrange#deleteCurrentRange()<CR>
nnoremap <leader>xD e:call xrange#createSettings()->xrange#deleteRangeUnderCursor()<CR>
nnoremap <leader>xI :echo xrange#createSettings()->xrange#findCurrentRange()<CR>
nnoremap <leader>xg e:execute xrange#createSettings()->xrange#getOuterRange(expand('<cword>')).start<CR>
nnoremap <leader>x! e:call xrange#createSettings()->xrange#executeRangeByName(expand('<cword>'))<CR><C-O>

" insert new range
nnoremap <leader>xi :call xrange#createSettings()->xrange#createNewRange()<CR>
nnoremap <leader>xc ::call xrange#createSettings()->xrange#closeCurrentRange()<CR>
" insert new result range
nnoremap <leader>xR :call xrange#createSettings()->xrange#createResultRange()<CR>
" go to result range
nnoremap <leader>xn ^/<C-R>=xrange#createSettings()->xrange#anyStartRegex()<CR><CR>
nnoremap <leader>xN ^?<C-R>=xrange#createSettings()->xrange#anyStartRegex()<CR><CR>

function s:executeAuto(name, mode)
  let settings = xrange#createSettings()
  call xrange#executeRangeByName(a:name, settings, settings.strip, a:mode)
endfunction

function s:completeRanges(A,L,P)
  let ranges =  xrange#createSettings()->xrange#rangeList()
  return join(ranges, "\n")
endfunction
command -nargs=1 -complete=custom,s:completeRanges ExecuteRange :call xrange#executeRangeByName("<args>", xrange#createSettings())
command -nargs=1 -complete=custom,s:completeRanges DeleteRange :call xrange#deleteInnerRange("<args>", xrange#createSettings())
command -nargs=1 -complete=custom,s:completeRanges GotoRange :execute xrange#createSettings()->xrange#getOuterRange("<args>").start
nnoremap <leader>Xx :ExecuteRange<space><C-D> 
nnoremap <leader>Xd :DeleteRange<space><C-D> 
nnoremap <leader>Xg :GotoRange<space><C-D> 

augroup xrange
  au BufReadPost * call s:executeAuto("auto", "silent")
  au BufReadPost * call s:executeAuto("auto-confirm", "confirm")
augroup END
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
