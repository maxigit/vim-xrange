vim9script
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
      execute(printf("$%s = '%s'", vname, Eval(value)))
    endif
  endfor
enddef

export def Eval(value: string): string
      var result = value
      const [_,prefix,command;_] = matchlist(value, '\([:^@?]\?\)\(.*\)')
      if prefix == ':'
        const r: any  = eval(command) #->string()
        if type(r) != v:t_string
          result = string(r)
        else
          result = r
        endif
      elseif prefix == '?'
        # lookup value by regex
        const regex = command->substitute('\\z[se]', '', 'g')
        const start = search.Search(regex, 'nbW')
        if start == 0
          result = ''
        else
          const end = search.Search(regex, 'nebW')
          # clean \zs and \ze which interfere with the line number
          const lines = getline(start, end)
          const line = lines->join("\n")
          # result = string({start: start, end: end, line: line, match: matchstr(line, command), r: regex})
          result = matchstr(line, command)
        endif
      elseif prefix == '^'
        # lookup var=value or var:value 
        result = Eval(printf('?.*\ze\n.*%s^%s', g:xblock_prefix, escape(command, '.')))
      elseif prefix == '@'
        # lookup var=value or var:value 
        result = Eval(printf('?\<%s\>\s*[=:]\s*\zs.*', escape(command, '.')))
      endif
      return result
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
  InjectRangesInBuffer(com->get('name', ''), com.endLine, ranges)
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

export def InjectRangesInBuffer(comName: string, insertAfter: number, ranges: dict<dict<any>>): void
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
    var fullName = name
    if comName != ""
      fullName = comName .. '.' .. name
    endif
    append(insertAfter, header + footer->add(g:xblock_prefix .. '^' .. fullName))
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


