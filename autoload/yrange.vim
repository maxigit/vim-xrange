
" ==================================================
"            Settings
" ==================================================
" Create initial settings needed
" to call any function
" settings can be nested
" allowing range syntax to change depending on the contect
" a settings is a dict which must contains the following field
" - ranger
"

" Create settings from buffer or global settings
function! yrange#create_setting()
  return {ranger.yrange#ranger#default()}
endfunction

" create settings if necessary
function! yrange#get_settings(settings)
  if a:settings == {} 
    return yrange#create_setting()
  else
    return a:settings
  endif
endfunction

" ==================================================
"                Range
" ==================================================
" A range corresponds to a ranger of lines
" in text. It is represented a dictionary with the following 
" attributes.
" - name  (if any)
" - header
" - start (first line, including header)
" - end (last line, including footer)
" -  body_start
" -  body_end
" - properties/tag
" - parent
" - children
" - executable ???
" - nestable ???
" - syntax
" - settings (if any) 
"
"   If no range is found {} is return
function! yrange#find_current(settings={})
  let settings = yrange#get_settings(a:settings)

  return settings.find_start('cnW')
endfunction

