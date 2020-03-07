# Overview
X-range is a plugin allowing to execute source code within text documents.
 It can run part of a buffer, process it through an external shell command and inject the result somewhere else in the buffer. It attempts to be an alternative to [Emacs org-babel](https://orgmode.org/worg/org-contrib/babel/).

The main use cases are 
  - to store local macros in a buffer. Such macros can for example, launch tests, and modify the buffer itself, to generate and keep up to date a table of content
  - to use a vim buffer as a REPL by evaluting code in different languages and collecting the results in the same buffer. This is sometimes called [reproductible research'](https://en.wikipedia.org/wiki/Reproducibility#Reproducible_research) as is in [Emacs org-babel](https://orgmode.org/worg/org-contrib/babel/) or [Jupyter Notebook](https://jupyter.org/)


## Examples
### Grep mappings
To grep all the mapping commands in this plugin (to update the DOC for examplE)

![grep mappings](grep2.gif)

``` vimscript
:mappings: +ar > +x !git grep noremap > @>
.mappings.
```

We can jump to actual buffer/line by pressing `gF`.


### Reading errors
To fill the quickfix list with the result of the grep, we need to replace the output `@>` with `@@`

![grep quickfir](grep-errors.gif)

``` vimscript
:mappings_errors: !git grep -n noremap > @@
.mappings_errors.
``` 

### Executing  python code

Here we execute the content of then range `python` and inject the result in the `python:out`.
![python](python.gif)

``` vimscript
:python: !python < @< > @:out@
  for n in range(10):
    print(n)
.python.
```

`!python < @< > @:out@` is actually just vim script.
`@<` and `@:out@` are actually shorthand `@python<` and `@python:out@` which are then replaced by temporary files name.
X-Range take care of creating, writing and reading the temporary files.


# Usage
## Ranges
The core idea behing X-Range are ranges. A range associate a name to continous set of lines and optional tags.
Ranges can be executed, expanded to normal vim range, or read and written from to a temporary file.

### Range defintions
Ranges are delimited with start and end delimeters. The default start delimiter is a name between `:` and the default end delimited is the range name between `.`. For example `:python:` and `.python.` delimits the `python` range.
Range delimiters need to start a line or being just after a sequence of non characters followed by a space.
This allow range to be defined in code comment. Example

```
:A:
This is a valid range (A)
.A.
# :B:
This is another valid range (B)
# .B.


#@#$@#---- :C:
This is another valid range (C)
Note that the "comment" for the start delimiter don't have to match the one used for the end delimiter.
.C.
```

The range delimiters can be customized globally using `g:xrange_start` and `g:xrange_end` or per buffer, using
`b:xrange_start` and `b:xrange_end`.

### Range expansion
The character `@` introduces range expansion. The range expansion form is `@`range_operators_.
If more than one operator is specified the value of the last one will be used.
#### range operators

- `@range%` : outer range (including delimiters)
- `@range*` : outer range (excluding delimiters)
- `@range^` : first line of the outer range (including 
- `@range$` : last line of the outer range
- `@range{` : first line of the inner range
- `@range}` : first line of the inner range

Evaluating

```
:expansion:
  @expansion:out*d " delete inner range
  call append(@expansion:out}, "% => @expansion%")
  call append(@expansion:out}, "* => @expansion*")
  call append(@expansion:out}, "^ => @expansion^")
  call append(@expansion:out}, "$ => @expansion$")
  call append(@expansion:out}, "{ => @expansion{")
  call append(@expansion:out}, "} => @expansion}")
.expansion.
```

produces

```
:expansion:out:
% => 91,99
* => 92,98
^ => 91
$ => 99
{ => 92
} => 98
.expansion:out.
```

#### file operators

- @range< creates an 'in' temporary file containing the text within the range
- @range> creates an 'out' temporary file. The content of the out file will be injected in the buffer between the range at the end of execution of the block.
- @range@ creates an 'error' file. An error file is like an out file but is also parsed for error (and fill the quickfix window).
- @range& load the content of an out file now (without waiting for the end of the block).

### extra operators

- @range- delete the content of a range
- @range+ create the range if it doesn't exist
- @range! execute the range. Can be used to setup dependency
- @range' expand the full range name see (current range)
- @'... escape the @

### Current Range 
If no name or a name starting with `:` is expanded, the name of the current range will be used as prefix.
In the following example, `@:out` is equivalent to `@current:out`.

```
:current:
  @:out- " delete current:out range
  call append(@:out} , "@current}  =  @}")
.current.
:current:out:
139 =  139
.current:out.
```
## Default Mappings
For the following mappings, _current range_ refers to the range containing the cursor, wheras range under cursor refrs to the range which the name is under cursor.
- `<leader>xi` insert a new range
- `<leader>xc` close the current range if needed.
- `<leader>xm` execute the range called `main`
- `<leader>xx` execute the current range
- `<leader>xX` execute range under cursor
- `<leader>xe` execute the current line. Doesn't have to be in a range
- `<leader>xd` delete the content of the current range
- `<leader>xD` delete range any range (prefill with range under cursor, completion works)
- `<leader>xI` echo some debug information relative to the current range
- `<leader>xg` go to the range under cursor
- `<leader>xG` go to range any range (prefill with range under cursor, completion works)
- `<leader>x!` execute range under cursor
- `<leader>xr` create/go to the result range
- `<leader>xn` go to next range
- `<leader>xN` go to previous range

## Range execution
Executing range (by calling `@range!` or by calling the `:ExecuteRange` command) executes the code
between the range delimiter, unless there is some code on the start delimiter itself.
In that case *only* the code on the line will be executed.
Before being executed each line is subject to range expansion and split by `;`. This allow multiple commands to be written in one single line.

For example, executing

```
:execute_range:
 g/range/
.execute_range.
```
calls the `:g` command.

```
:execute_line: echo "g/range/ not executed"
 g/range/
.execute_line.
```
Doesn't execute `g/range/` but echoes `g/range/ not executed`.
The ability to execute the first line of a range allows to combine a command (the start line) and it's body (the inner range) in one range.

Example 

``` vimscript
:python2: !python < @<
for n in range(10):
  print(n)
.python2.
```

Executing the python2 range executes the code `!python < @<` which is equivalent to `!python < @python2<

## Tags
Code on the start line can contains tags. Tags start with a `+` and need to be before the code to execute (if any). 
Can be used to modify the way a range is executed or to define macro.

Example

``` vimscript
:with_tag: +a +b
.with_tag.
```

The range `with_tag` has the tag `a` and `b`.
Tags can also have values. Everything after a tags is a value of this tags.
If a tag is used many times the tag will have as many value
The actual tags of a range can be checked using `<leader>xI`.

Example 

``` vimscript
:tag_with_value: +a  1 +b 2 3 +c 4 +c 5
.tag_with_value.
```

associates `[1]` to `a` , `['2 3']` to `b` (1 value) and `c` to `[4, 5]`(2 values).

### predefined tags
Some tags have a special value and modify the way a range is executed. For example the tag `x` contains the code on the start line. `:range: some code` is equivalent to `:range: +x some code`.

- 'pre' code to execute before copy the range to an out file. 
For example, the following range

```
:pre_fail: !python <  @<

  print("hello")

.pre_fail.
```

fails, because we send `    print "hello"` to the python interpreter. This generate an error because the code is indented. We have two solutions either not indent the range in our buffer, or leave the code indented but find a way to unindent before sending to python. This can be achive by doing

```
:pre_ok: +pre @* < +x !python <  @<

  print("hello")

.pre_ok.
```

`@* <` is just the shift command applied to the current inner range. The `+x` is need to close the `pre` tag and set code to execute.

- `post` code to execute after copy the range to an out file. The opposite of `pre`.
- `sw` execute substitue  on each line of the inner range before writting the out file. Equivalent to `+pre @* s`
- `sr` execute substitue  on each line of the inner range after readin the in file.
- `aw` execute the given command to all line of the inner range before writting the out file. Short for `+pre @*`
- `ar` execute the given command to all line of the inner range after reading the in file. Short for `+post @*`
- `w` shell command to pipe the range through before writting it. Multiple  values will be pipe together.
- `qf` if present the out file will parse the errors in the quickfix list.
- `loc` if present the out file will parse the errors in the location list.
- `efm` set the `errorformat` when parsing error. can be used multiple time
- `compiler` set the `compiler` when parsing error.
- `keep` done remove the temporty file from the disk.

Example


``` vimscript
:w: +w tr h H +w tr o O   +x !python < @<
print("hello")
.w.
```

should print "HellO".

- 'r' shell command to pipe through when reading an out file.

### Macro expansion
Setting all those tags can be cumbersome, so x-range provides a way to define a set of tags and reuse it : macros.
Tag ending with a `+` are macros. They are replaced with the tags defined in  `g:xrange_macros` and `b:xange_macros`.

Example, we would like to execute python code with automatic unindenting of the range and automatic indenting of the result.
This could be done this way

``` vimscript
:full_python: +aw < +x !clear;  !python < @<  > @:out+> ; @:out&* >
  for i in range(1,10):
    print("I should be indented : %d " % i)
.full_python.
```

However, we could create a `+python+` by adding an entry to `b:xrange_macros`.

``` vimscript
   let b:xrange_macros = {"python': {'aw' : '<', 'x': '!clear;  !python < @<  > @:out+> ; @:out&* >'} }
```

Note that executing this line with `<leader>xe` will not work because x-range will try to escape the ranges.
To be able to execute this line in our buffer we need to escape all the ranges reference with `@'`.
`;` are also escaped by x-range so we needed instead to provide a list of commands.

``` vimscript
   let b:xrange_macros = {"python": {"aw" : "<", "x": ["!clear", "!python < @'<  > @':out+>", "@':out&* >"]} }
```

We can use it this way

``` vimscript
:python_with_macro: +python+
  for i in range(1,10):
    print("I should be indented : %d " % i)
.python_with_macro.
```
:python_with_macro:out:  +result+
  I should be indented : 1 
  I should be indented : 2 
  I should be indented : 3 
  I should be indented : 4 
  I should be indented : 5 
  I should be indented : 6 
  I should be indented : 7 
  I should be indented : 8 
  I should be indented : 9 
.python_with_macro:out.


### Special range
3 ranges name have a special meaning.
- `main` can be executed using the `<leader>xm` mapping.
- `auto` this range will be executed automaticaly when the buffer is loaded. Disabled until we found a correct thrust mecanism.
- `auto-confirm` this range will be executed automaticaly when the buffer is loaded but will ask the user for confirmation before using it.

# Todos
TODO replace by saving lines or having a save point ?
TODO create empty line if out file is empty
TODO explain ; in execution
TODO add tag evaluation in command usind t: same with b: and g:
TODO multi line delimiter
TODO extract range from comment , see g:xrange_strip 
TODO add offset to range (using tags ?)
TODO ADD @range[1,-1] notation
TODO add custom end delimiter using tags ?
TODO add conditionnal @range?
TODO modeline
