vim9script

# Generic combinator {{{1
export def Token(regexp: string): func(string): dict<any>
  var Parse = (input: string) => {
    const [matched, start, end] = matchstrpos(input, '^' .. regexp)
    if start == -1
      return {}
    endif
    return {token: matched, leftover: input->slice(end) }
    }
  return Parse
enddef

export def Sequence(parsers: list<func(string): dict<any>>): func(string): dict<any>
  var Parse = (input: string) => {
    var leftover = input
    var tokens = []
    for Parser in parsers
        const parsed = Parser(leftover)
        if parsed == {}
          return {}
        endif
        tokens->add(parsed.token)
        leftover = parsed.leftover
    endfor
    return {token: tokens, leftover: leftover}
  }
  return Parse
enddef

export def Any(parsers: list<func(string): dict<any>>): func(string): dict<any>
  var Parse = (input: string) => {
    for Parser in parsers
      const parsed = Parser(input)
      if parsed != {}
        return parsed
      endif
    endfor
    return {}
    }
  return Parse
enddef

export def Join(parsers: list<func(string): dict<any>>): func(string): dict<any>
  return Sequence(parsers)->Map((l) => l->join(''))
enddef

export def SkipFirst(Toskip: func(string): dict<any>, Parser: func(string): dict<any>): func(string): dict<any>
  return Sequence([Toskip, Parser])->Map((l) => l[1])
enddef

export def Map(Parser: func(string): dict<any>, F: func(any): any): func(string): dict<any>
  var Parse = (input: string) => {
    const parsed = Parser(input)
    if parsed == {}
      return {}
    endif
    return {leftover: parsed.leftover, token: F(parsed.token)}
    }
  return Parse
enddef

export def Tag(Parser: func(string): dict<any>, tag: string): func(string): dict<any>
  return Map(Parser, (token) => {
    if type(token) == v:t_dict
      return {tag: tag}->extend(token, 'keep')
    else
      return {value: token, tag: tag}
      
    endif
    })
enddef

# Specific {{{1

export def ParseIdent(): func(string): dict<any>
  return Token('[-a-zA-Z0-9_.]\+')
enddef

export def ParseVarName(): func(string): dict<any>
  return Join([Token('@\?'), ParseIdent()])
enddef

export def ParseEnvBinding(): func(string): dict<any>
  return Sequence([ParseIdent(), Token('\s*=\s*'), ParseValue()])->Map((l) => ({'ident': l[0], 'value': l[2]}))
enddef

export def ParseVarBinding(): func(string): dict<any>
  return Sequence([ParseVarName(), Token('\s*:\s*'), ParseValue()])->Map((l) => ({'ident': l[0], 'value': l[2]}))
enddef

# Parse things between pairs like (...) '...' etc
# un remove them unless it start with a backslash
export def ParseValue(): func(string): dict<any>
  const pairs: list<func(string): dict<any>> =
        [ParseInPair('()'), 
         ParseInPair('[]'),
         ParseInPair('{}'),
         ParseInPair('""'),
         ParseInPair('''''')
        ]
  const InPairs = Any(pairs)->Map((s) => s[1 : -2])
  # if start with a backslash
  const OutPairs = Sequence([Token('\\'), Any(pairs)])->Map((l) => l[1])
  # starts with : keep it
  const WithColon = Sequence([Token(':'),
                             InPairs,
                             Token(':\?')]
                             )->Map((l) => printf(':{%s}:', l[1])
                             )
  return Any([InPairs, OutPairs, WithColon, ParseNonSpaces()])
enddef

export def ParseInPair(pair: string): func(string): dict<any>
  var open = pair[0]
  if open == '['
    open = '\' .. open
  endif
  const close = pair[1]
  return Token(printf('%s.\{-}\\\@<!%s', open, close))->Map((token) => token->substitute('\\\ze' .. close, '', 'g'))
enddef

export def ParseReference(): func(string): dict<any>
  return Any([SkipFirst(Token('&'), ParseIdent()), Token('&\ze[&[:space:]]')->Map((_) => '')])
enddef

export def ParseNonSpaces(): func(string): dict<any>
  return Token('\%(\\\s\|\S\)\+')->Map((token) => token->substitute('\\\ze[[:space:]]', '', 'g')->substitute('\\\\', '\', 'g'))
enddef

# Terminal {{{1
export def ParseStatement(): func(string):  dict<any>
  return SkipFirst(Token('\s*'), Any([ParseReference()->Tag('ref'),
           ParseVarBinding()->Tag('var'),
           ParseEnvBinding()->Tag('env'),
           SkipFirst(Token('-'), ParseIdent())->Tag('unset'),
           SkipFirst(Token('+'), ParseIdent())->Tag('set'),
         ]))
enddef

export def ParseInput(input_: string): list<dict<any>>
  var input = input_
  var tokens = []
  while true
    const parsed = ParseStatement()(input)
    if parsed == {}
      const command = input->trim()
      if !!command
        tokens->add({'tag': 'command', 'value': command})
      endif
      break
    else
      tokens->add(parsed.token)
      input = parsed.leftover
    endif
  endwhile
  return tokens
enddef
