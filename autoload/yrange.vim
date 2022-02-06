vim9script 
b:xblock_prefix = '!!' # TODO remove, set by autocommand
def s:startRg(): string
  return b:xblock_prefix .. '\f*[!#:={]'
enddef


def s:endRg(): string
  return b:xblock_prefix .. '}'
enddef

# Search the next command
def SearchNextCommand(): number
  return s:search(s:startRg(), 'Wn')
enddef

# assume we are on the line of the command itself
def SearchEndOfCurrentCommand(): number
  return s:search(s:endRg(), 'Wnc', SearchNextCommand())
enddef

def SearchCurrentCommand(): dict<number>
  const currenLine = line('.')
  const cursorPos = getcurpos()
  const cursorLine = cursorPos[1]
  const startLine = s:search(s:startRg(), 'Wbc')
  # check if the command is multiline
  if match(getline(cursorLine), b:xblock_prefix .. "\f*[!#:=]\?{") == -1
    # on line
    if startLine == cursorLine
      return {startLine: startLine, endLine: startLine}
    else
      return {}
    endif
  else #multiline
    const endLine = SearchEndOfCurrentCommand()
    if endLine >= cursorLine
      return {startLine: startLine, endLine: endLine}
    else
      return {}
    endif
  endif
enddef

# !!main={
#    echo 1+2
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
echomsg SearchNextCommand()
:20
echomsg SearchNextCommand()
defcompile
