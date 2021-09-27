--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts
License: MIT License

----------
]]--


-- This file contains a macros for properties at this directory.
-- You don't need to include this file. The engine will do it itself.

function getUsualProperty(
-- the Main_OnCommand ID
cmd,
-- The property label
msg
)
local usual = {
get = function(self)
local message = initOutputMessage()
message:initType(string.format("Perform this property to call the %s action.", msg), "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
-- If user has SWS installed, omit the msg parameter
if reaper.APIExists("CF_GetCommandText") then
msg = string.match(reaper.CF_GetCommandText(0, cmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, cmd)
msg = msg:gsub("[.]+$", "")
end
message(msg)
return message
end,
set = function(self, action)
if action == nil then
restorePreviousLayout()
local oldTracksCount = reaper.CountTracks(0)
reaper.Main_OnCommand(cmd, 1)
local newTracksCount = reaper.CountTracks(0)
if oldTracksCount < newTracksCount then
return string.format("%u tracks added", newTracksCount-oldTracksCount)
elseif oldTracksCount > newTracksCount then
return string.format("%u tracks removed", oldTracksCount-newTracksCount)
end
setUndoLabel(self:get())
return ""
else
return "This property is performable only."
end
end
}
return usual
end
