/'
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
'/'

#define unicode
#include "windows.bi"
#include "win/mmsystem.bi"

Enum Modes
MODE_SYSTEMBEEP
MODE_FILE
end enum

var cmd = Command()
dim mode as long = MODE_FILE
if Left(cmd, 1) = "#" then
mode = MODE_SYSTEMBEEP
cmd = ltrim(cmd, "#")
cmd = LCase(cmd)
end if

select case mode
case MODE_SYSTEMBEEP
select case cmd
case "hand"
MessageBeep(MB_ICONHAND)
case "question"
MessageBeep(MB_ICONQUESTION)
case "exclamation"
messageBeep(MB_ICONEXCLAMATION)
case "asterisk"
MessageBeep(MB_ICONASTERISK)
case "warning"
MessageBeep(MB_ICONWARNING)
case "error"
MessageBeep(MB_ICONERROR)
case "information"
MessageBeep(MB_ICONINFORMATION)
case "beep"
MessageBeep(MB_OK)
end select
case MODE_FILE
PlaySound(cmd, NULL, SND_FILENAME)
end select
