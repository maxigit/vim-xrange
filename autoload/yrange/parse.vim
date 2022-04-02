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
  return Token('[-a-zA-Z0-9_.])
enddef


export def ParseVarBinding(): func(string): dict<any>
enddef


