--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License

==========

Attempt to implement the sound events support
This is temporary decision till I didn't found another legal method to play any sound through REAPER. It will works only for Windows. If somebody knows how to implement this via another cross-platform methods, please contribute this here!
]]--

local function runPlayer(cmd)
-- We have to define which operating system is used.
local osDelim = string.sub(package.config, 1, 1)
if osDelim == "\\" then -- We are on Windows
if reaper.file_exists(({reaper.get_action_context()})[2]:match('^.+[\\//]')..'engine//utils//windows//properties_ribbon_soundplayer//prsp.exe') then
reaper.ExecProcess(({reaper.get_action_context()})[2]:match('^.+[\\//]')..'engine//utils//windows//properties_ribbon_soundplayer//prsp.exe \"'..cmd..'\"', -1)
end
end
-- We cannot play sounds in other systems yet.
end

local soundplay = {}

function soundplay.beep(str)
assert(str, "The beep icon should be passed")
runPlayer(string.format("#%s", str))
end

function soundplay.file(str)
assert(str, "The file path should be passed")
runPlayer(({reaper.get_action_context()})[2]:match('^.+[\\//]')..'engine//sounds' ..str)
end

return soundplay