vim9script

def StartRg(): string
  return g:xblock_prefix .. '\i*[!:=&{]'
enddef

export def ForceLoad(): string
  return "search"
enddef


def EndRg(): string
  return g:xblock_prefix .. '}'
enddef

const Props = ["syntax", "<", ">"]->join('\|')
# !!!ls
# Search the next command. Start on next line
# to avoid finding the current line
export def SearchNextCommandLine(): number
  return Search('\n\zs.*' .. StartRg(), 'Wn')
  #                ^  ^
  #                |  |
  #                |  +------ return the line number of startRg ex
  #                |          excluding the previous line
  #                +----------start the search on the next line
enddef

# assume we are on the line of the command itself
export def SearchEndOfCurrentCommandLine(): number
  return Search(EndRg(), 'Wnc', SearchNextCommandLine())
enddef

export def SearchPreviousCommandLine(): number
  return Search(StartRg(), 'Wnbc')
enddef

# Doesn't check that the line is on the start of a range
# However it check that the end line is NOT BEFORE the current
export def CommandRangeFromLine_unsafe(line: number, current: number=0): dict<any>
  if line == 0
    return {}
  endif
  const cursorPos = getcurpos()
  cursor(line, 1)
  # check if the command is multiline
  const [_,name,opening;_] = matchlist(getline(line), g:xblock_prefix .. '\(\i*\)[!:=]\?\({\)\?')
  var result: dict<any> = {name: name}
    # on line
  if opening == "{"
    const endLine = yrange#search#SearchEndOfCurrentCommandLine()
    if endLine > 0 && endLine >= current
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
def RangeToText(range: dict<any>): string
  const lines = getline(range.startLine, range.endLine)
  var results = []
  for l in lines
    # remove "comment" strip right
    var s = substitute(l, g:xblock_prefix .. '[#}].*', '', '')
    # strip right
    s = substitute(s, '^.\{-}' .. g:xblock_prefix, '', '')
    results->add(s)
  endfor
  # on first line, removes name and { if any
  results[0] = substitute(results[0], '^\%(\i*=\)\?{\?', '', '')
  return results->join(' ')
enddef

# Extend command recursively
def ExtendCommand(com1: dict<any>, com2: dict<any>): dict<any>
  for key in com2->keys()
    if com1->has_key(key)
      var value = com1[key]
      if type(value) == v:t_dict
        value->ExtendCommand(com2[key])
      else
        com1[key] = com2[key]
      endif
    else
        com1[key] = com2[key]
    endif
  endfor
  return com1
enddef

def RangeToCommand(range: dict<any>): dict<any>
  # find default
  var result = get(g:, 'xblock_default', {})
  if type(result) == v:t_string
    result = TextToDict(result)
  endif
  var command = range->RangeToText()
  if range->get('name', '') != 'default'
    var default = yrange#search#FindCommandByName('default')
    if default->has_key('name')
      unlet default.name
    endif
    result->ExtendCommand(default)
  endif
  return result->ExtendCommand(
                range->RangeToText()
                  ->TextToDict()
                  ->extend(range) # set ranges and name
              )
enddef

# Parses and extract variable/properties declaration from command
# a command should have have the following format
# stmt ::= [bindings ] command
# bindings ::= binding [ ' ' bindings ]
# binding ::= dict | var=value + prop:value
def TextToDict(command_: string): dict<any>
  # extract the prefix !, : etc ...
  const [_, prefix, command;_] = matchlist(command_, '^\([!:]\?\)\s*\(.*\)')
  # split on space (but not '\ '
  const words = split(command, '[^\\]\zs\s\+')
  var vars: dict<string> = {} # variables
  var env: dict<string> = {} # env variables
  var r: dict<any> = {vars: vars, env: env}
  var coms = []
  for w in words 
    const word = substitute(w, '\ ', ' ', 'g')
    # if the command itself is started to be parsed
    # skip the binding parsing
    if coms != []
      coms->add(word)
    else
      var match = matchlist(word, '\(\i\+\)=\(.*\)')
      if match != []
        const [_,name,value;_] = match
        env[name] = value
      else
        match = matchlist(word, '\(' .. Props .. '\):\(.*\)')
        if match != []
          const [_,prop,value;_] = match
          r[prop] = value
        else
          match = matchlist(word, '&\(\i\+\)')
          if match != []
            # lookup 
            var com2 = yrange#search#FindCommandByName(match[1])
            if com2 == {}
              const com3: any = get(g:xblock_commands, match[1], {})
              if type(com3) == v:t_string
                com2 = TextToDict(com3)
              else
                com2 = com3
              endif
            endif
            #append('$', match[1] .. " " .. string(com2))
            r->ExtendCommand(com2)
           else # command
             coms->add(word)
           endif
        endif
      endif
    endif
  endfor
  if coms != []
    r.command = coms->join(' ')
  endif
  if prefix == "!"
    r.command = "!" .. r.command
  endif
  return r
enddef

def FindCommandLine(name: string): number
   return Search(g:xblock_prefix .. name .. '=', 'cwn')
enddef

export def FindCommandByName(name: string): dict<any>
  const line = FindCommandLine(name)
  if line == 0
    return {}
  endif
  var command = line->yrange#search#CommandRangeFromLine_unsafe()
                    ->RangeToText()
                    ->TextToDict()
  command.name = name
  return command
enddef

export def LineToCommand_unsafe(line: number, current: number): dict<any>
  if line == 0
    return {}
  else
   return yrange#search#CommandRangeFromLine_unsafe(line, current)
          ->RangeToCommand()
 endif
enddef

# Find range above !!^name finishing at next one
export def FindOuterRange(com: dict<any>, name: string): dict<any>
  const cursorPos = getcurpos()
  cursor(com.endLine, 1)
  var last = SearchNextCommandLine()
  const endRange = Search(g:xblock_prefix .. '^' .. name, 'wn', last)
  var result = {}
  if endRange != 0
    # find the end of another range or the end of the range itself
    cursor(endRange, 1)
    var previousEnd = Search(g:xblock_prefix .. '^\i\+\>', 'bwn', com.endLine)
    if previousEnd == 0
      # use current range end
      previousEnd = cursorPos[1]
    endif
    result = {rangeStart: previousEnd + 1, rangeEnd: endRange}
  endif
  setpos('.', cursorPos)
  return result
enddef

# Update command and the start and end line to all inner ranges
# return the updated ranges
# Only check for the given range names (to avoid finding 
# default ranges  not used in the present command
export def FindInnerRanges(com: dict<any>, used: list<string>): dict<any>
  const cursorPos = getcurpos()
  if (com.startLine == 1)
    return {}
  endif

  cursor(com.startLine - 1, 1)
  var first = SearchPreviousCommandLine()
  var foundRanges: list<list<any> > = []
  # find all ranges and sort them 
  # so that each start of a range marks the end of the previous one
  for name in  com.ranges->keys()
    var range = com.ranges[name]
    if used->index(name) == -1 || range.mode != 'in'
      continue
    endif
    const rangeStart = Search(range.start, 'bwn', first)
    #append('$', 'Find ' .. name .. ' ' .. string(range) .. ' ' .. rangeStart)
    if rangeStart > 0
      com.ranges[name]['startLine'] = rangeStart
      # find the end of the match. in case the match matches multiple line.
      com.ranges[name]['bodyStart'] = Search(printf('\%(%s\)\zs', range.start), 'bwn', first)
      foundRanges->add([rangeStart, name])
    endif
  endfor
  final result = {}
  if foundRanges != []
    foundRanges->sort()->reverse()
    var last = com.startLine - 1
    for [line, name] in foundRanges 
      com.ranges[name]['endLine'] = last
      last = line - 1
      result[name] = com.ranges[name]
    endfor
  endif
  setpos('.', cursorPos)
  return result
enddef

# Find all ranges starting from the given range
# till the next one or end of file, regardless
# of if ther are used or not. (this allow
# to delete all ranges even though some are not used anymore.
export def FindOuterRanges(com: dict<any>): dict<any>
  const cursorPos = getcurpos()
  cursor(com.endLine, 1)
  # find the last end of range marker 
  # before the next range
  var last = SearchNextCommandLine()
  if last == 0
    cursor(line('$'), 1)
  endif
  cursor(last, 1)
  # find backward until the end 
  const rangeEnd = Search(g:xblock_prefix .. '^\i\+\>', 'cbwn', com.endLine)
  setpos('.', cursorPos)
  if rangeEnd >= com.endLine + 1
    return {rangeStart: com.endLine + 1, rangeEnd: rangeEnd}
  else
    return {}
  end
enddef

# !!main={
# !! This  (1)
# before comment (2)!!#  Not that
# !! in between (3)
# !!}

# Like search but make sure the search ignore user and fold settings
def Search(...args: list<any>): number
  const ignorecase = &ignorecase
  const smartcase = &smartcase
  const magic = &magic
  const foldenable = &foldenable
  setl noignorecase
  setl nosmartcase
  setl nomagic
  setl foldenable
  const l = call("search", args)
  &ignorecase = ignorecase
  &smartcase = smartcase
  &magic = magic
  &foldenable = foldenable
  return l
enddef
defcompile
