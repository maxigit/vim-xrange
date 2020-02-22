# Overview
X-range is a plugin allowing to execute source code within text documents.
 It can run part of a buffer, process it through an external shell command and inject the result somewhere else in the buffer. It attempts to be an alternative to [Emacs org-babel](https://orgmode.org/worg/org-contrib/babel/).

The main use cases are 
  - to store local macros in a buffer. Such macros can for example, launch tests, and modify the buffer itself, to generate and keep up to date a table of content
  - to use a vim buffer as a REPL by evaluting code in different languages and collecting the results in the same buffer. This is sometimes called [reproductible research'](https://en.wikipedia.org/wiki/Reproducibility#Reproducible_research) as is in [Emacs org-babel](https://orgmode.org/worg/org-contrib/babel/) or [Jupyter Notebook](https://jupyter.org/)


# Examples
## Grep mappings
To grep all the mapping commands in this plugin (to update the DOC for examplE)

![grep mappings](grep2.gif)

``` vimscript
:mappings: +ar > +x !git grep noremap > @>
.mappings.
```


## Reading errors
To fill the quickfix list with the result of the grep, we need to replace the output `@>` with `@@`

![grep quickfir](grep-errors.gif)

``` vimscript
:mappings_errors: !git grep noremap > @>
.mappings_errors.
``` 

## Executing  code

# Features
X-range provides function and mappings to 
  - define ranges within a buffer
  - a way to refers to range
  - a way to execute vim and shell command
  - a way to splice range into temporary file
