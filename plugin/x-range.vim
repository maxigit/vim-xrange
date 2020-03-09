" command -nargs=1 DeleteRange :call xrange#deleteInnerRange("<args>")

nnoremap <leader>xm :call xrange#executeRangeByName("main", xrange#createSettings({}), 0, '')<CR>
nnoremap <leader>xx :call xrange#executeCurrentRange(xrange#createSettings({}))<CR>
nnoremap <leader>xe m`:call xrange#executeLine(xrange#createSettings({}),'.', 0)<CR>``j
nnoremap <leader>xd :call xrange#deleteCurrentRange(xrange#createSettings({}))<CR>
nnoremap <leader>xI :echo xrange#currentRangeInfo(xrange#createSettings({}))<CR>
nnoremap <leader>xg :call xrange#gotoUnderCursor(xrange#createSettings({}))<CR>
nnoremap <leader>x! e:call xrange#executeUnderCursor(xrange#createSettings({}))<CR>

" insert new range
nnoremap <leader>xi :call xrange#createNewRange(xrange#createSettings({}))<CR>
nnoremap <leader>xc ::call xrange#closeCurrentRange(xrange#createSettings({}))<CR>
" insert new result range
nnoremap <leader>xr :call xrange#createResultRange(xrange#createSettings({}))<CR>
" go to result range
nnoremap <leader>xn ^/<C-R>=xrange#anyStartRegex(xrange#createSettings({}))<CR><CR>
nnoremap <leader>xN ^?<C-R>=xrange#anyStartRegex(xrange#createSettings({}))<CR><CR>

function s:executeAuto(name, mode)
  let settings = xrange#createSettings({})
  call xrange#executeRangeByName(a:name, settings, settings.trim_left, a:mode)
endfunction

function s:completeRanges(A,L,P)
  let ranges =  xrange#createSettings({})->xrange#rangeList()
  return join(ranges, "\n")
endfunction


command -nargs=1 -complete=custom,s:completeRanges ExecuteRange :call xrange#executeRangeByName("<args>", xrange#createSettings({}), 0, '')
command -nargs=1 -complete=custom,s:completeRanges DeleteRange :call xrange#deleteInnerRange("<args>", xrange#createSettings({}))
command -nargs=1 -complete=custom,s:completeRanges GotoRange :execute xrange#createSettings({})->xrange#getOuterRange("<args>",'').start
nnoremap <leader>xX :ExecuteRange <C-R>=xrange#rangeUnderCursor(xrange#createSettings({}))<CR>
nnoremap <leader>xD :DeleteRange <C-R>=xrange#rangeUnderCursor(xrange#createSettings({}))<CR>
nnoremap <leader>xG :GotoRange <C-R>=xrange#rangeUnderCursor(xrange#createSettings({}))<CR>

nnoremap <leader>xo :echo xrange#rangeUnderCursor(xrange#createSettings({}))<CR>
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
