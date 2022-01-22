--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]]--

local function runPlayer(cmd)
if reaper.file_exists(({reaper.get_action_context()})[2]:match('^.+[\\//]')..'engine\\' .. "utils//windows//properties_ribbon_soundplayer//prsp.exe") then
reaper.ExecProcess(({reaper.get_action_context()})[2]:match('^.+[\\//]')..'engine\\' .. 'utils//windows//properties_ribbon_soundplayer//prsp.exe \"'..cmd..'\"', -1)
end
end

local soundplay = {}

function soundplay.beep(str)
runPlayer(string.format("#%s", str))
end

function soundplay.file(str)
runPlayer(str)
end

return soundplay