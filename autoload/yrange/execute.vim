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
def SetEnvs(env: dict<any>, vars: dict<any>): void
  for [vname, value] in env->items()
    if value == v:none
      execute('unlet $' .. vname)
    else
      execute(printf("$%s = '%s'", vname, Eval(ExpandCommand(value, vars))))
    endif
  endfor
enddef

export def Eval(value: string): string
      var result = value
      const [_,prefix,command;_] = matchlist(value, '\([:^@?$]\?\)\(.*\)')
      if prefix == ':'
        const r: any  = eval(command) #->string()
        if type(r) != v:t_string
          result = string(r)
        else
          result = r
        endif
      elseif prefix == '$' # env variables
        result = eval(value) #->string()
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
  SetEnvs(com.env, com.vars)
  final ranges = UsedRanges(com)
  # populate range limits
  search.FindInnerRanges(com, ranges->keys())
  PopulateRanges(ranges)
  #for v in com.vars->keys()
  #  com.vars[v] = ExpandCommand(com.vars[v], com.vars)
  #endfor
  const command = ReplaceRanges(com.command, ranges)->ExpandCommand(com.vars)
  #append('.', " " .. string(com))
  #append('.', "COM " .. command)
  :silent execute command
  DeleteOuterRanges(com)
  InjectRangesInBuffer(com->get('name', ''), com.endLine, ranges)
  SetEnvs(oldEnv, com.vars)
  setpos('.', cursorPos)
enddef

# create temporary files and set the name to the dict
export def PopulateRanges(ranges: dict<dict<any>>): void #append('$', "RANGES " .. " " .. string(ranges))
  for [name, range] in ranges->items()
    range['tmp'] = tempname()
    echomsg range
    #append('$', "RANGE " .. name .. " " .. string(range))
    if range.mode != 'in' || !range->has_key('bodyStart')
      continue
    endif
    const vars = {write:  ':range: write !:{trimLeft?% sed ''s/^%s//''|}::{preenv?% %s|}: :envsubst: :{postenv?%|%s}:  > :tmp:',
                 envsubst: 'envsubst'
                 }->extend(deepcopy(range))->extend({range: printf("%d,%d", range.bodyStart, range.endLine)})
    # execute vim code on the given range
    # to strip comments or indentation for example
    # To do so, we execute the command on the buffer itself
    # and then undo it.
    const undo_pos = undotree().seq_cur
    if range->has_key('pre') && range.bodyStart <= range.endLine
      setpos('.', [0, range.bodyStart, 0 0])
      var pre = ExpandCommand(range.pre, vars)
      echomsg ":::" pre ":::"
      execute pre
    endif
    # write the content of the range to the temporary file
    # var command = get(range, 'write', ':%range write! %file')
    var command = ':' .. ExpandCommand(vars.write, vars)
    echomsg '[<' command '>]'
    silent execute command
    execute "undo" undo_pos
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
    var command = get(range, 'read', '::range: r :{post?%!%s<}: :tmp:')
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
    const lastLineBefore = line('$')
    var vars = deepcopy(range)->extend({range: rangeLine})
    command = ExpandCommand(command, vars)
    echomsg '[>' command '<]'
    silent! execute command
    const lastLineAfter = line('$')
    # cancel if output is empty according to range options
    const numberOfNewLine = lastLineAfter - lastLineBefore
    const firstInserted = insertAfter + 1
    const lastInserted = firstInserted + numberOfNewLine
    if lastLineBefore == lastLineAfter && !!range->get('clearEmpty', false)
      # deletebufline("%", insertAfter + 1, insertAfter + 1 + lastLineAfter - lastLineBefore)
      deletebufline("%", firstInserted, lastInserted)
    elseif range.mode == 'error'
      #
      # replace reference to <tmp file>:line with current file adjusted line
      # number
      const currentFile = expand('%')
      for [iname, irange] in ranges->items()
        if !irange->has_key('tmp')
          continue
        endif
        if irange->has_key('bodyStart')
          execute(printf(':%d,%ds#%s:\zs\d\+\ze#\=submatch(0)->str2nr() + %d#ge', firstInserted, lastInserted, fnameescape(irange.tmp), irange.bodyStart - 1))
        endif
        execute(printf(':%d,%ds#%s#%s#ge', firstInserted, lastInserted, fnameescape(irange.tmp), fnameescape(currentFile)))
      endfor
    endif
  endfor
enddef

def ReplaceRanges(com: string, ranges: dict<dict<any>>): string
  var command = com
  for [name, range] in ranges->items()
    command = substitute(command, '@' .. name .. '\>', range.tmp, "g") 
  endfor
  return command
enddef

# Expand ':variable:' and ':{code}:' in a string
# see test for full syntax

export def ExpandCommand(com: string, vars: dict<any>): string
  var current = com
  var new = ExpandCommand_(current, vars)
  while new != current
    current = new
    new = ExpandCommand_(new, vars)
  endwhile
  return new
enddef

def ExpandCommand_(com: string, vars: dict<any>): string
  const matchProp = matchlist(com, '\(.\{-}\):\(\i\+\):\(.*\)')
  if matchProp != []
    const [_,before,varname,after;_] = matchProp
    return before .. vars->get(varname, '') .. ExpandCommand(after, vars)
  endif
  const matchLambda8 = matchlist(com, '\(.\{-}\):\({\(\i\+\)\s*->.\{-}}\):\(.*\)')
  if matchLambda8 != []
    const [_,before, lambda, varname, after;_] = matchLambda8
    const F = <func>Eval8(lambda)
    return before .. F(vars->get(varname, '')) .. ExpandCommand(after, vars)
  endif
  const matchLambda9 = matchlist(com, '\(.\{-}\):{\((\(\i\+\))\s*=>.\{-}\)}:\(.*\)')
  if matchLambda9 != []
    const [_,before, lambda, varname, after;_] = matchLambda9
    const F = <func>eval(lambda)
    return before .. F(vars->get(varname, '')) .. ExpandCommand(after, vars)
  endif
  const matchIf = matchlist(com, '\(.\{-}\):{\(\i\+\)??\(.\{-}\)}:\(.*\)')
  if matchIf != []
    const [_,before,varname, default, after;_] = matchIf
    return before .. vars->get(varname, default) .. ExpandCommand(after, vars)
  endif
  const matchFormatIf = matchlist(com, '\(.\{-}\):{\(\i\+\)?%\(.\{-}\)}:\(.*\)')
  if matchFormatIf != []
    const [_,before,varname, format, after;_] = matchFormatIf
    var formated = ''
    if vars->get(varname, '') != ''
      formated = printf(format, vars[varname])
    endif
    return before .. formated .. ExpandCommand(after, vars)
  endif
  const matchIfElse = matchlist(com, '\(.\{-}\):{\(\i\+\)?\([^:]\{-}\):\(.\{-}\)}:\(.*\)')
  if matchIfElse != []
    const [_,before,varname, then_, else_, after;_] = matchIfElse
    const value = vars->get(varname, '') != '' ? then_ : else_
    return before .. value .. ExpandCommand(after, vars)
  endif
  const match8 = matchlist(com, '\(.\{-}\):{\(.\{-}\)}:\(.*\)')
  if match8 != []
    const [_,before, code, after;_] = match8
    const F = <func>Eval8(printf("{ vars -> %s }", code))
    return before .. F(vars) .. ExpandCommand(after, vars)
  endif
  return com
enddef

function Eval8(command)
  echomsg a:command
  return eval(a:command)
endfunction

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

export def DeleteCommand(com: dict<any>): void
  if com == {}
    return
  endif
  deletebufline(bufnr(), com.startLine, com.endLine)
enddef

defcompile


