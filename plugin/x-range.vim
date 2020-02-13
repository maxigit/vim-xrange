" Create a tmp file and load with the range content if needed
nnoremap <leader>xm :call xrange#executeRangeByName("main")<CR>

command -nargs=1 DeleteRange xrange#deleteInnerRange("<args>")

nnoremap <leader>xm :call xrange#executeRangeByName("main")<CR>
nnoremap <leader>xx :call xrange#executeCurrentRange()<CR>
nnoremap <leader>xe m`:call xrange#executeLine('.')<CR>``j
nnoremap <leader>xd :call xrange#deleteCurrentRange()<CR>
nnoremap <leader>xD e:call xrange#deleteRangeUnderCursor()<CR>
nnoremap <leader>xi :echo xrange#findCurrentRange()<CR>
nnoremap <leader>xg e:execute xrange#getOuterRange(expand('<cword>')).start<CR>
nnoremap <leader>x! e:call xrange#executeRangeByName(expand('<cword>'))<CR><C-O>

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
