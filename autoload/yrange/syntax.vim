vim9script 

import autoload './search.vim' as search

#   !!abc= option:value2 var=value2 +opt !cat <@in >@out
#   
#   XXXXX  bbbbbbbbbbbb  b                     RRR  RRR
#   rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr
#
export def InstallSyntax()
  if !hlexists("XRangeX")
    hi link XRangeX Underlined
    hi link XRangeRange SpellRare
    # hi link XRangeStart SpellCap
    hi link XRangeDel SpellBad
  endif
  
  if exists("b:xblock_matches")
     return
  endif

  # All line
  :execute 'syntax match' 'XRangeX' ('/' .. g:xblock_prefix .. '\i*[!:=&][^{].*/') 

  # Range
  :execute 'syntax region' 'XRangeX' ('start=/' .. g:xblock_prefix .. '\i*{/') ('end=/' .. g:xblock_prefix .. '}/')

  # End of Range
  :execute 'syntax match XRangeDel' ('/' .. g:xblock_prefix .. '^[[:ident:].]*/')
  :execute 'syntax match' 'XRangeRange' '/@\i\+/' 'containedin=XRangeX' 'contained'
  # :execute 'syntax match XRangeStart' ('/' .. g:xblock_prefix .. '\i*[!:=&{]/') 'containedin=XRangeX contained'
  # :execute 'syntax match XRangeStart' ('/' .. g:xblock_prefix .. '}/') 'containedin=XRangeX contained'

enddef
