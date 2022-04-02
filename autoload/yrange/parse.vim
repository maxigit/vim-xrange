vim9script

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

export def ParseIdent(): func(string): dict<any>
  return Token('[-a-zA-Z0-9_.]\+')
enddef


export def ParseVarBinding(): func(string): dict<any>

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




