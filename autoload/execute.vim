vim9script

export def ForceLoad(): string
  return "execute"
enddef

def ExecuteCommand(com: dict<any>): void
  #if com == {}
  #  return
  #endif
  const cursorPos = getcurpos()

  #SaveVars(com)
  #ApplyVars(com)
  PopulateRanges(com.ranges)
  const command = ReplaceRanges(com.command, com.ranges)
  :execute command
  InjectRanges(com.ranges)
  #RestoreVars(com)
enddef

# create temporary files and set the name to the dict
def PopulateRanges(ranges: dict<dict<any>>): void
  for [name, range] in ranges->items()
    range['tmp'] = tempname()
    #if range.mode != 'in'
    #  continue
    #endif
    # write the content of the range to the temporary file
    var command = get(range, 'write', ':%range write! %file')
    command = substitute(command, '%range', range.range, 'g')
    command = substitute(command, '%file', range.tmp, 'g')
    # :execute  ":" .. range.range .. "write! " .. range.tmp
    execute command
  endfor
enddef

def InjectRanges(ranges: dict<dict<any>>): void
  for [name, range] in ranges->items()
    if range.mode == 'in'
      continue
    endif
    # inject the content of the file to the range
    var command = get(range, 'read', ':%range !cat %file')
    command = substitute(command, '%range', range.range, 'g')
    command = substitute(command, '%file', range.tmp, 'g')
    # :execute ":" .. range.range .. "!cat " .. range.tmp
    execute command
  endfor
enddef

def ReplaceRanges(com: string, ranges: dict<dict<any>>): string
  var command = com
  for [name, range] in ranges->items()
    command = substitute(command, '@' .. name .. '\>', range.tmp, "g") 
  endfor
  return command
enddef

defcompile
