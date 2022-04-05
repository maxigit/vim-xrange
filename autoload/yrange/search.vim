vim9script
import './parse.vim' as parse

def StartRg(): string
  return g:xblock_prefix .. '\i*[!:=&{]'
enddef

export def ForceLoad(): string
  return "search"
enddef


def EndRg(): string
  return g:xblock_prefix .. '}'
enddef

const Props = ["root", "ranges", "syntax", "compiler", "efm", "qf"]->join('\|')
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

export def SearchPreviousCommandLine(matchCurrent: bool=true): number
  var flags = 'Wnb'
  if matchCurrent
    flags = flags .. 'c'
  endif
  return Search(StartRg(), flags)
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
      result->extend({startLine: line, endLine: line})
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

# Convert a Range to a Command
# Do so, by expanding the given range
# to a dictionary but also prepend
# the the previous command, the buffer default
# or the global default (by priority).
# Defaulting to can be preventing by setting
# an empty lookup ('&') (or setting 'root:1')
def RangeToCommand(range: dict<any>): dict<any>
  var rangeDict = range->RangeToText()->TextToDict()
  var base: dict<any>
  if range->get('name', '') == 'default'
    # default range
    # use global default as a base
    # unless root is set
    base = rangeDict->has_key('root') ? {} : GetGlobalDefault()
  else
    # normal range
    # uses previous range
    #  or default
    if rangeDict->has_key('root')
      base = FindCommandByName('default')
    else
      # use previous range if any
      base = FindCommandAbove(range.startLine)
    endif
    base = base ?? GetGlobalDefault()
  endif
  return base->deepcopy()->ExtendCommand(rangeDict)->extend(range)
enddef

def GetGlobalDefault(): dict<any>
  const glob = get(g:, 'xblock_default', {})
  if type(glob) == v:t_string
    return TextToDict(glob)
  endif
  return glob
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
  const tokens = parse.ParseInput(command)
  var vars: dict<string> = {} # variables
  var env: dict<string> = {} # env variables
  var r: dict<any> = {vars: vars, env: env, ranges: {}}
  for token_ in tokens 
    var token = token_
    # pre processing of shorthand
    if token.tag == 'ref' && token.value == ''
      token = {tag: 'var', ident: 'root', value: '1'}
    elseif token.tag == 'unset'
      token = {tag: 'var', ident: token.value, value: '' }
    elseif token.tag == 'set'
      token = {tag: 'var', ident: token.value, value: '1' }
    endif
    # processing
    const tag = token.tag
    if tag == 'env'
      env[token.ident] = token.value
    elseif tag == 'var'
        const prop = token.ident
        const value = token.value
        var target = r
        if prop[0] == '@' 
          target = r.ranges
        elseif match(prop, Props) == -1
          target = vars
        endif
        # set  and creates dict if needed
        # example a.b.c =2 =>  {a:{b:{c:2}}}
        var keys = split(prop, '\.')
        const lastKey = keys->remove(-1)
        for key in keys
          if !target->has_key(key)
            target[key] = {}
          endif
          target = target[key]
        endfor
        target[lastKey] = value
    elseif tag == 'ref'
        # lookup 
        var com2 = yrange#search#FindCommandByName(token.value)
        if com2 == {}
          const com3: any = get(g:xblock_commands, token.value, {})
          if type(com3) == v:t_string
            com2 = TextToDict(com3)
          else
            com2 = com3
          endif
        endif
        #append('$', match[1] .. " " .. string(com2))
        r->ExtendCommand(com2)
    elseif tag == 'command' # command
      r.command = token.value
    else
      throw token.tag .. ' not implemented'
    endif
  endfor
  if prefix == "!" && r->has_key('command')
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
                    ->RangeToCommand()
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

export def FindCommandAbove(line: number): dict<any>
  setpos('.', [0, line, 0, 0])
  const start = SearchPreviousCommandLine(false)
  if start == 0
    return {}
  endif
  return CommandRangeFromLine_unsafe(start)
           ->RangeToCommand()
           #->RangeToText()
           #->TextToDict()
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

  cursor(com.startLine, 1)
  var first = SearchPreviousCommandLine(false) + 1
  var foundRanges: list<list<any> > = []
  # find all ranges and sort them 
  # so that each start of a range marks the end of the previous one
  for name in  com.ranges->keys()
    var range = com.ranges[name]
    if used->index(name) == -1 || range.mode != 'in'
      continue
    endif
    const rangeStart = Search(printf('\%(%s\)\%%<.l', range.start), 'bWn', first)
    #append('$', 'Find ' .. name .. ' ' .. string(range) .. ' ' .. rangeStart)
    if rangeStart > 0
      com.ranges[name]['startLine'] = rangeStart
      # find the end of the match. in case the match matches multiple line.
      com.ranges[name]['bodyStart'] = Search(printf('\%(%s\)\%%<.l\zs', range.start), 'bWn', first)
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
export def Search(...args: list<any>): number
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
