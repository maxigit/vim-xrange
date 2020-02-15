<!-- <auto-confirm>
  match Error /TODO/
  </auto-confirm>
-->
# Overview
X-Range is a plugin allowing to execute source code of any language within any text documents in a similar way to emacs org-babel.
This can be used to add local macro to a buffer, generate portion of code, or just a "within buffer REPL".
It does so by helping the manipulation and execution of section of buffer called ranges.
Ranges are lines between range delimiters. By default, range  delimiters are line starting with `<`range`>` and ending with `</` range '>'. 

For example,  executing the `<toc>` range by typing `<leader>xx` when the cursor in on the `<toc>` line will
fill the `<toc>` range with all the lines starting with a `#`. Executing the `<ls>` range will fill the `<ls>` range with the content of the current directory.

To delete the content of the range just press `<leader>xd`


!-- <toc> @toc-; g/^#/t @toc}; @toc*g/./m@toc^
</toc>

<ls> !ls -l > @ls>
</ls>

The first example inspect the vim buffer itself and copy the line to the last line of the `toc` range (`@toc}`) and reverse the lines.
The second example execute a shell command and redirect it to file which is then injected in the range itself.

# Executing Range
Executing a range just execute the content of the range as vim `:` commands with range references expanded.
Also, if there is code on the same line as the range start tag itself this code (and only this code) will be executed. Otherwise the content of the inner range will be executed.
It is also possible to execute many statements on the same line by separating them with `;`.


Example

<online> match Search /range/
</online>

<clear> match
</clear>

will execute `match Search /range/` and  not use the content of the range itself.

Executing 

<code>
  match IncSearch /range/
  2match Search /<[^>]*>/
</code>
<clear> match ; 2match
</clear>

Will execute the code between <code> and </code>.
You can clear the matches by pressing <leader>xe on the next line (execute the line under cursor)
match; 2match

## Range expension
Range names can be expended to either vim address, range or filename. Expanding to a filename have the side effect of either writing the content of the range to the file or reading the file to the current buffer itself.
Outer range refers to the range including the range delimiters themselves wereas inner range to the line
between the range delimiters.

  - @range% outer range
  - @range^ first line of the outer range
  - @range$ last line of the outer range
  - @range* inner range
  - @range{ first line of the inner range
  - @range} last line of the inner range
  - @range- inner range but delete the content of the range first

  - @range< file open in readmode (the content of the range is copied to the file)
  - @range> file open in writemode (the content of the file will be injected in the inner range)
  - @range@ as @range> but load the result in the location list
  - @range& synchronize the content of a file open in writemode but now, allowing the rest of the code
            to operate on the range itself.
 
  - @range! execute the range, can be use to update dependencies, etc ...
 

## Complexe examples

### SQL query

this example execute the sql query in the sql range and display the result in sql_result
<sql> @sql*w !mysql -host<host>  > @sql_result>
 ... you query
</sql>
<sql_result> @sql!
</sql_result>

Note that the `@sql!` on the first lin of the `sql_result` range allows the result range to be refreshed by executing the range itself.


### Awk
Awk is a good example of how to use multiple files. It can be used to generate code with a buffer itself.
<colors>
red,#ff000
blue,#00ff00
green,#0000ff
</colors>
<awk> @colors*w !awk -F, -f @awk< >@awk_result> ; @awk_result&; @awk_result*>
BEGIN {print "colors=[];" }
// {printf("colors['%s']='%s'\n",$1,$2)}
</awk>
<awk_result> @awk!
</awk_result>

Note that `@awk_result&; @awk_result_` is only there to indent the result

# Default Mappings
	- <leader>xm execute `main` range
	- <leader>xx execute range containing cursor
	- <leader>xe execute line under cursor
	- <leader>xd delete inner range containing cursor
	- <leader>xD delete inner ranger under cursor
	- <leader>xi echo range under cursor name
	- <leader>xg go to range under cursor
	- <leader>x! execute range under cursor

# Todos
- DONE change getOuterRange create optoins to create at the end of file or next line, etc
- DONE replace s:init by context dictionary
- TODO autocommand to set option by filetype
- TODO expand range name to use current range
- TODO list current ranges
  - [ ] X command with completion
- DONE extract vim (part of dictionary ?)
   - DONE remove second substitute ?
- TODO rename range
- TODO expand abbreviation
 - to get mysql parameters for example
- TODO custom modeline
  - add pre hook
- TODO change block in README
- DONE fix bugs when start regex match end ex <tag> </tag>
- Chain range operator, example @range-<
- TODO how to set variable m4 ?
- TODO block paramters range key=value? (or := ?)
- TODO all mappings
- TODO disable mapping and autocmd with global settings
