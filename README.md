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

- @range% : outer range (including delimiters)
- @range* : outer range (excluding delimiters)
- @range^ : first line of the outer range (including 
- @range$ : last line of the outer range
- @range{ : first line of the inner range
- @range} : first line of the inner range

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

### extra operator
- @range- delete the content of a range
- @range+ create the range if it doesn't exist
- @range! execute the range. Can be used to setup dependency
- @range' expande to `@range` (escape or delay the range expansion)
### Current Range 
If no name or a name starting with `:` is expanded, the name of the current range will be used as prefix.
In the following example, `@:out` is equivalent to `@current:out`.

```
:current:
  @:out- " delete current:out range
  call append(@:out} , "@'} =>  @}")
.current.
:current:out:
@} =>  137
.current:out.
```

### Range execution
TODO
## Tags
### Tags
TODO
### Tags expansion
TODO
 
## Default Mappings
TODO
# Configuration
TODO
##  auto exec
## main
