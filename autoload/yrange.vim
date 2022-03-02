vim9script
import autoload "yrange/search.vim" as search
import autoload "yrange/execute.vim" as exm

export def CommandUnderCursor(): dict<any>
  const startLine = search.SearchPreviousCommandLine()
  return search.LineToCommand_unsafe(startLine, line('.'))
enddef

export def ExecuteCommandUnderCursor(): void
    exm.ExecuteCommand(yrange#CommandUnderCursor())
enddef

export def CommandByName(name: string): dict<any>
  return search.FindCommandByName(name)
enddef

      
defcompile
