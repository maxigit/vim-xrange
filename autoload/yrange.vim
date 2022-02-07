vim9script 
b:xblock_prefix = '!!' # TODO remove, set by autocommand
def s:startRg(): string
  return b:xblock_prefix .. '\f*[!:={]'
enddef


def s:endRg(): string
  return b:xblock_prefix .. '}'
enddef

# !!!ls
# Search the next command. Start on next line
# to avoid finding the current line
def SearchNextCommandLine(): number
  return s:search('\n\zs.*' .. s:startRg(), 'Wn')
  #                ^  ^
  #                |  |
  #                |  +------ return the line number of startRg ex
  #                |          excluding the previous line
  #                +----------start the search on the next line
enddef

# assume we are on the line of the command itself
def SearchEndOfCurrentCommandLine(): number
  return s:search(s:endRg(), 'Wnc', SearchNextCommandLine())
enddef

def SearchPreviousCommandLine(): number
  return s:search(s:startRg(), 'Wnbc')
enddef

# Doesn't check that the line 
def CommandFromLineUnsafe(line: number): dict<any>
  const cursorPos = getcurpos()
  cursor(line, 1)
  # check if the command is multiline
  const [_,name,opening;_] = matchlist(getline(line), b:xblock_prefix .. '\(\f*\)[!:=]\?\({\)\?')
  var result: dict<any> = {name: name}
    # on line
  if opening == "{"
    const endLine = SearchEndOfCurrentCommandLine()
    if endLine > 0
      result->extend({startLine: line, endLine: endLine})
    endif
  else
      result = {startLine: line, endLine: line}
    endif
  setpos('.', cursorPos)
  return result
enddef

# Extract the "interesting part" of each line for the given range
# ie between <prefix> and <prefix># if presents
# This allow to insert command within comment but also have comment
# 
# Example:
#      This
#      Not this !! but this
#      Not this !! but this !!# and not that
#      This !!# but not that
def s:extractCommandText(range: dict<any>): string
  const lines = getline(range.startLine, range.endLine)
  var results = []
  for l in lines
    # remove "comment" strip right
    var s = substitute(l, b:xblock_prefix .. '[#}].*', '', '')
    # strip right
    s = substitute(s, '^.\{-}' .. b:xblock_prefix, '', '')
    results->add(s)
  endfor
  # on first line, removes name and { if any
  results[0] = substitute(results[0], '^\f*={\?', '', '')
  return results->join(' ')
enddef

# !!main={
# !! This  (1)
# before comment (2)!!#  Not that
# !! in between (3)
# !!}

# Like search but make sure the search ignore user and fold settings
def s:search(...args: list<any>): number
  const ignorecase = &ignorecase
  const smartcase = &smartcase
  const magic = &magic
  const foldenable = &foldenable
  set noignorecase
  set nosmartcase
  set nomagic
  set foldenable
  const l = call("search", args)
  &ignorecase = ignorecase
  &smartcase = smartcase
  &magic = magic
  &foldenable = foldenable
  return l
enddef

:2
echomsg line('.') "==>" SearchNextCommandLine()
echomsg "Range" line('.') "==>" SearchNextCommandLine()->CommandFromLineUnsafe()
echomsg "Text" line('.') "==>" SearchNextCommandLine()->CommandFromLineUnsafe()->s:extractCommandText()
:20
echomsg line('.') "==>" SearchNextCommandLine()
echomsg "Range" line('.') "==>" SearchNextCommandLine()->CommandFromLineUnsafe()
echomsg "Text" line('.') "==>" SearchNextCommandLine()->CommandFromLineUnsafe()->s:extractCommandText()
defcompile
