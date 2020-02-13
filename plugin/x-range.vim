command -nargs=1 DeleteRange :call xrange#deleteInnerRange("<args>")

nnoremap <leader>xm :call xrange#executeRangeByName("main")<CR>
nnoremap <leader>xx :call xrange#executeCurrentRange()<CR>
nnoremap <leader>xe m`:call xrange#executeLine('.')<CR>``j
nnoremap <leader>xd :call xrange#deleteCurrentRange()<CR>
nnoremap <leader>xD e:call xrange#deleteRangeUnderCursor()<CR>
nnoremap <leader>xI :echo xrange#findCurrentRange()<CR>
nnoremap <leader>xg e:execute xrange#getOuterRange(expand('<cword>')).start<CR>
nnoremap <leader>x! e:call xrange#executeRangeByName(expand('<cword>'))<CR><C-O>

" insert new range
nnoremap <leader>xi :call xrange#createNewRange()<CR>
" insert new result range
nnoremap <leader>xR :call xrange#createResultRange()<CR>
" go to result range
nnoremap <leader>xn /<C-R>=xrange#anyStartRegex()<CR><CR>
nnoremap <leader>xN ?<C-R>=xrange#anyStartRegex()<CR><CR>

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
