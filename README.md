# Overview
X-range is a plugin allowing to execute source code within text documents.
 It can run part of a buffer, process it through an external shell command and inject the result somewhere else in the buffer. It attempts to be an alternative to [Emacs org-babel](https://orgmode.org/worg/org-contrib/babel/).

The main use cases are 
  - to store local macros in a buffer. Such macros can for example, launch tests, and modify the buffer itself, to generate and keep up to date a table of content
  - to use a vim buffer as a REPL by evaluting code in different languages and collecting the results in the same buffer. This is sometimes called [reproductible research'](https://en.wikipedia.org/wiki/Reproducibility#Reproducible_research) as is in [Emacs org-babel](https://orgmode.org/worg/org-contrib/babel/) or [Jupyter Notebook](https://jupyter.org/)


# Todo
- [ ] expand post and pre and options as variable in command line
- [ ] add post and pre to output range (cancel above ?)
- [ ] text-object
- [ ] navigation between ranges [x ]x
- [ ] automark using range mark
- [ ] lookup variable by mark
- [ ] set ranges via @range.parameter:valute
- [ ] debug bug first line not working
- [ ] fix all tests
- [ ] clean vars (not used)
