vim9script
import autoload "yrange/search.vim" as search
import autoload "yrange/execute.vim" as exm

export def CommandUnderCursor(): dict<any>
  const currentLine = line('.')
  const startLine = search.SearchPreviousCommandLine()
  var current = search.LineToCommand_unsafe(startLine, currentLine)
  # Check that the current line belongs to the current range + outer + inner
  if current->Within(currentLine)
    return current
  endif
  var next = search.LineToCommand_unsafe(search.SearchNextCommandLine(), currentLine)
  if next->Within(currentLine)
    return next
  endif
  return next
enddef

export def ExecuteCommandUnderCursor(): void
    exm.ExecuteCommand(yrange#CommandUnderCursor())
enddef

export def CommandByName(name: string): dict<any>
  return search.FindCommandByName(name)
enddef

# Check wether the given line is within the given range
# (including inner and outer ranges)
def Within(com: dict<any>, line: number): bool
  if com == {}
    return false
  endif

  if line < com.startLine
    # check for inner ranges
    const inners = search.FindInnerRanges(com, com->exm.UsedRangeNames())
    for inner in inners->values()
      if line >= inner.startLine && line <= inner.endLine
        return true
      endif
    endfor
    return false
  elseif line > com.endLine
    # check for outer ranges
    const outer = search.FindOuterRanges(com)
    if outer != {} && line >= outer.rangeStart && line <= outer.rangeEnd
      return true
    endif
    return false
  else # between start and end
    return true
  endif
enddef
      
defcompile
