vim9script autoload
import "./search.vim" as search

# Save current values of environment variables
def SaveVars(com: dict<any>): dict<any>
  const env = environ()
  var result = {}
  for vname in com.env->keys()
    if env->has_key(vname)
      result[vname] = env[vname]
    else
      result[vname] = v:none
    endif
  endfor
  return result
enddef

# Set or Unset env variables
def SetEnvs(env: dict<any>): void
  for [vname, value] in env->items()
    if value == v:none
      execute('unlet $' .. vname)
    else
      execute(printf("$%s = '%s'", vname, value))
    endif
  endfor
enddef






export def ExecuteCommand(com: dict<any>): void
  if com == {}
    return
  endif
  const cursorPos = getcurpos()
  cursor(com.endLine, 1)


  const oldEnv = SaveVars(com)
  SetEnvs(com.env)
  final ranges = UsedRanges(com)
  # populate range limits
  search.FindInnerRanges(com, ranges->keys())
  PopulateRanges(ranges)
  const command = ReplaceRanges(com.command, ranges)
  #append('.', " " .. string(com))
  #append('.', "COM " .. command)
  :silent execute command
  DeleteOuterRanges(com)
  InjectRangesInBuffer(com.endLine, ranges)
  SetEnvs(oldEnv)
  setpos('.', cursorPos)
enddef

# create temporary files and set the name to the dict
export def PopulateRanges(ranges: dict<dict<any>>): void
    #append('$', "RANGES " .. " " .. string(ranges))
  for [name, range] in ranges->items()
    range['tmp'] = tempname()
    #append('$', "RANGE " .. name .. " " .. string(range))
    if range.mode != 'in' || !range->has_key('bodyStart')
      continue
    endif
    #append('$', "IN " .. name .. " " .. string(range))
    # write the content of the range to the temporary file
    # var command = get(range, 'write', ':%range write! %file')
    var command = get(range, 'write', ':%range write !envsubst > %file')
    command = substitute(command, '%range', printf("%d,%d", range.bodyStart, range.endLine), 'g')
    command = substitute(command, '%file', range.tmp, 'g')
    # :execute  ":" .. range.range .. "write! " .. range.tmp
    silent execute command
  endfor
enddef
#
#  range
#  >>>>> where to insert

export def InjectRangesInBuffer(insertAfter: number, ranges: dict<dict<any>>): void
  for [name, range] in ranges->items()
    if range.mode == 'in'
      continue
    endif
    # inject the content of the file to the range
    var command = get(range, 'read', ':%range r %file')

    var rangeLine = insertAfter
    # insert header and footer
    var header = get(range, 'header', [])
    if header != []
      rangeLine += len(header)
    endif
    var footer = get(range, 'footer', [])
    append(insertAfter, header + footer->add(b:xblock_prefix .. '^' .. name))
    command = substitute(command, '%range', rangeLine, 'g')
    command = substitute(command, '%file', range.tmp, 'g')
    silent! execute command
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


export def UsedRangeNames(com: dict<any>): list<string>
  return com->UsedRanges()->keys()
enddef
# Delete all ranges starting from the given range
# till the next one or end of file
export def DeleteOuterRanges(com: dict<any>): void
  const range = search.FindOuterRanges(com)
  if range != {}
    deletebufline(bufnr(), range.rangeStart, range.rangeEnd)
  endif
enddef

defcompile


