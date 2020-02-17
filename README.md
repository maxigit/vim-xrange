<!-- <auto>
 match Error /TODO/
</auto>
-->
# Overview
X-Range is a plugin allowing to execute source code of any language within any text documents in a similar way to emacs org-babel.
This can be used to add local macro to a buffer, generate portion of code, or just a "within buffer REPL".
It does so by helping the manipulation and execution of section of buffer called ranges.
Ranges are lines between range delimiters. By default, range  delimiters are line starting with `<`range`>` and ending with `</` range '>'. 

For example,  executing the `<toc>` range by typing `<leader>xx` when the cursor in on the `<toc>` line will
fill the `<toc>` range with all the lines starting with a `#`. Executing the `<ls>` range will fill the `<ls>` range with the content of the current directory.

To delete the content of the range just press `<leader>xd`


<toc> g/^#/t @-}; @*g/./m@^
# Overview
# Executing Range
## Range expension
## Complexe examples
### SQL query
### Awk
# Default Mappings
# Todos
</toc>

<ls> +comment+ +x !ls -l > @>
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

this example execute the sql query in the sql range and display the result in sql:out
<sql> @sql*w !mysql -host<host>  > @sql:out>
 ... you query
</sql>
<sql:out> @sql!
</sql:out>

Note that the `@sql!` on the first lin of the `sql:out` range allows the result range to be refreshed by executing the range itself.


### Awk
Awk is a good example of how to use multiple files. It can be used to generate code with a buffer itself.
<colors>
red,#ff000
blue,#00ff00
green,#0000ff
</colors>
<awk> @colors*w !awk -F, -f @awk< > @:out> ; @:out&* >
  BEGIN {print "colors=[];" }
  // {printf("colors['%s']='%s'\n",$1,$2)}
</awk>
<awk:out> @awk!
</awk:out>

Note that `@awk:out&; @awk:out_` is only there to indent the result

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
- DONE expand range name to use current range
- DONE list current ranges
- DONE extract vim (part of dictionary ?)
   - DONE remove second substitute ?
- DONE change mapping upper case complete
  better if there is a range under cursor prefill it
  so @> got to current_range output
- DONE create output range if needed
- DONE debug AWK
- DONE change +s to +pre and +post +s> +s<
- DONE expand tags
 - to get mysql parameters for example
- DONE merge  tags from initial settings
- DONE add result tag -- to setup defualt to result
- DONE macros work with list or string
- TODO expand tags recursively
- TODO check error correct line
- DONE show tags (in information
- DONE +tag- clear it
- TODO change block in README
- TODO mecanism to authorize and remember auto
- DONE custom modeline
  - via add pre hook
- DONE fix bugs when start regex match end ex <tag> </tag>
- DONE Chain range operator, example @range-<
- TODO doc all mappings
- TODO disable mapping and autocmd with global settings
- TODO complete with fzf ?
- TODO rename range
- DONE expand range under cursor
- TODO autocommand to set option by filetype
- TODO +keep tag
  - TODO refactor getRange to return info
