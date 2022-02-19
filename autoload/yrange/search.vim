vim9script
b:xblock_prefix = '!!' # TODO remove, set by autocommand
b:xblock_default_ranges = { in: { mode: 'in', range: '-' },
                     out: { mode: 'out', range: '+,/!!\^\|\n\|$/' },
                     error: { mode: 'out', range: '+,/!!\^\|\n\|$/' }
                   }
b:xblock_default = { ranges: b:xblock_default_ranges }

def StartRg(): string
  return b:xblock_prefix .. '\f*[!:={]'
enddef

export def ForceLoad(): string
  return "search"
enddef


def EndRg(): string
  return b:xblock_prefix .. '}'
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
  const [_,name,opening;_] = matchlist(getline(line), b:xblock_prefix .. '\(\f*\)[!:=]\?\({\)\?')
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
    var s = substitute(l, b:xblock_prefix .. '[#}].*', '', '')
    # strip right
    s = substitute(s, '^.\{-}' .. b:xblock_prefix, '', '')
    results->add(s)
  endfor
  # on first line, removes name and { if any
  results[0] = substitute(results[0], '^\f*={\?', '', '')
  return results->join(' ')
enddef

def RangeToCommand(range: dict<any>): dict<any>
  # find default
  var result = get(b:, 'xblock_default', {})
  return result->extend(
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
def TextToDict(command: string): dict<any>
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
      var match = matchlist(word, '\(\$\?\)\(\i\+\)=\(.*\)')
      if match != []
        const [_,isEnv,name,value;_] = match
        if isEnv == '$'
          env[name] = value
        else
          vars[name] = value
        endif
      else
        match = matchlist(word, '\(' .. Props .. '\):\(.*\)')
        if match != []
          const [_,prop,value;_] = match
          r[prop] = value
        else
          match = matchlist(word, '&\(\f\+\)')
          if match != []
            # lookup 
            var com2 = FindCommandByName(match[1])
            r->extend(FindCommandByName(match[1]))
            vars->extend(com2.vars)
            env->extend(com2.env)
            r->extend(com2)
            r->extend({vars: vars, env: env})
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
  return r
enddef

def FindCommandLine(name: string): number
   return Search(b:xblock_prefix .. name .. '=', 'cwn')
enddef

def FindCommandByName(name: string): dict<any>
  return FindCommandLine(name)->yrange#search#CommandRangeFromLine_unsafe()->RangeToText()->TextToDict()
enddef

export def LineToCommand_unsafe(line: number, current: number): dict<any>
  if line == 0
    return {}
  else
   return yrange#search#CommandRangeFromLine_unsafe(line, current)
          ->RangeToCommand()
 endif
enddef

# Delete all ranges starting from the given range
# till the next one or end of file
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
  const rangeEnd = Search(b:xblock_prefix .. '^\f\+\>', 'cbwn', com.endLine)
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
