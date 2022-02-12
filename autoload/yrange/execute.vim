vim9script autoload

export def ForceLoad(): string
  return "execute"
enddef

export def ExecuteCommand(com: dict<any>): void
  if com == {}
    return
  endif
  const cursorPos = getcurpos()

  #SaveVars(com)
  #ApplyVars(com)
  final ranges = UsedRanges(com)
  PopulateRanges(ranges)
  const command = ReplaceRanges(com.command, ranges)
  :execute command
  InjectRanges(ranges)
  #RestoreVars(com)
enddef

# create temporary files and set the name to the dict
export def PopulateRanges(ranges: dict<dict<any>>): void
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
#
#  range
#  >>>>> where to insert

export def InjectRanges(ranges: dict<dict<any>>): void
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

# Return the list of ranges which are actually used.
# This allowed to have lots of ranges defined by default
# but only uses the needed ones.
export def UsedRanges(com: dict<any>): dict<dict<any>>
  if !com->has_key('ranges')
    return {}
  endif
  var result = {}
  for [name, range] in com.ranges->items()
    if match(com.command, '@' .. name .. '\>') != -1
      result[name] = range
    endif
  endfor
  return result
enddef

export def DeleteRange(com: dict<any>, rangeName: string): void
  :set nowrapscan
  :silent! :/\%>.l^\S/;/^$/-d
enddef

defcompile
