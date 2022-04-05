vim9script
import autoload "yrange/search.vim" as search
import autoload "yrange/execute.vim" as exm

export def CommandUnderCursor(): dict<any>
  const cursorPos = getcurpos()
  const currentLine = cursorPos[1]
  var result = {}
  while true # to break and restore position
    const startLine = search.SearchPreviousCommandLine()
    var current = search.LineToCommand_unsafe(startLine, currentLine)
    # Check that the current line belongs to the current range + outer + inner
    var range = current->Within(currentLine)
    if range != {}
      current.currentRange = range
      result = current
      break
    endif
    var next = search.LineToCommand_unsafe(search.SearchNextCommandLine(), currentLine)
    range = next->Within(currentLine)
    if range != {}
      next.currentRange = range
      result = next
      break
    endif
    #return next
    break
  endwhile
  setpos('.', cursorPos)
  return result
enddef

export def ExecuteCommandUnderCursor(): void
    exm.ExecuteCommand(yrange#CommandUnderCursor())
enddef

export def CommandByName(name: string): dict<any>
  return search.FindCommandByName(name)
enddef

# Check wether the given line is within the given range
# (including inner and outer ranges)
# Returns the range (startLine, endLine, etc ... }
export def Within(com: dict<any>, line: number): dict<number>
  if com == {}
    return {}
  endif

  if line < com.startLine
    # check for inner ranges
    const inners = search.FindInnerRanges(com, com->exm.UsedRangeNames())
    for inner in inners->values()
      if line >= inner.startLine && line <= inner.endLine
        return {startLine: inner.startLine, endLine: inner.endLine}
      endif
    endfor
    return {}
  elseif line > com.endLine
    # check for outer ranges
    const outer = search.FindOuterRanges(com)
    if outer != {} && line >= outer.rangeStart && line <= outer.rangeEnd
      return {startLine: outer.rangeStart, endLine: outer.rangeEnd}
    endif
    return {}
  else # between start and end
    return {startLine: com.startLine, endLine: com.endLine}
  endif
enddef

# Delete {{{
export def DeleteCommandAndOuterRanges(com: dict<any>): void
  if com == {}
    return
  endif
  com->exm.DeleteOuterRanges()
  com->exm.DeleteCommand()
enddef
      
export def DeleteOuterRanges(com: dict<any>): void
  exm.DeleteOuterRanges(com)
enddef

# Navigation {{{
def GoToLine(line: number): void
  if line <= 0
    return
  endif
  setpos('.', [0, line, 0, 0])
enddef

export def GoToNextCommand(): void
  search.SearchNextCommandLine()->GoToLine()
enddef

export def GoToPreviousCommand(): void
  search.SearchPreviousCommandLine(false)->GoToLine()
enddef



export def GoToCurrentRangeBy(param: string): void
  var command = CommandUnderCursor()
  if command == {}
    return
  endif
  command.currentRange[param]->GoToLine()
enddef
  

export def Print(d: any, indent: string =''): void
  const type = type(d)
  if type == v:t_list
    for item in d
      Print(item, indent .. '- ')
    endfor
  elseif type == v:t_dict
    for [key, val] in d->items()
      if type(val) == v:t_dict
        echo indent .. key .. ':'
        Print(val, indent .. '  ')
      else
        echo indent .. key .. ': ''' .. val .. ''''
      endif
    endfor
  else
    echo indent .. d
  endif
enddef

export def Expand(d: dict<any>): string
  return exm.ExpandCommand(d.command, d.vars)
enddef

export def WithRanges(com: dict<any>): dict<any>
  search.FindInnerRanges(com, exm.UsedRanges(com)->keys())
  return com
enddef

defcompile
