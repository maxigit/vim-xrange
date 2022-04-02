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

export def Map(Parser: func(string): dict<any>, F: func): func(string): dict<any>
  var Parse = (input: string) => {
    var parsed = Parser(input)
    if parsed == {}
      return {}
    endif
    parsed.token = F(parsed.token)
    return parsed
    }
  return Parse
enddef

# Specific {{{1

export def ParseIdent(): func(string): dict<any>
  return Token('[-a-zA-Z0-9_.]\+')
enddef


export def ParseVarBinding(): func(string): dict<any>
  return Sequence[Ident, Token('='), ParseValue()]->Map((ident,_, value) => {ident: ident, value: value})
enddef


export def ParseValue(): func(string): dict<any>
  var pairs: list<func(string): dict<any>> =
        [ParseInPair('()')->Map((s) => s[1 : -2]), 
         ParseInPair('[]'),
         ParseInPair('{}')
         ParseInPair('""')
         ParseInPair('''''')
        ]
  return Any(pairs + [ParseNonSpaces()])
enddef

export def ParseInPair(pair: string): func(string): dict<any>
  return Token(printf('%s.\{-}\\\@<!%s', pair[0], pair[1]))->Map((token) => token->substitute('\\\ze' .. pair[1], '', 'g'))
enddef


export def ParseNonSpaces(): func(string): dict<any>
  return Token('\%(\\\s\|\S\)\+')->Map((token) => token->substitute('\\\ze[^\\]', '', 'g'))
enddef
