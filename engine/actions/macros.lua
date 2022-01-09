--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License

----------
]]--


-- This file contains a macros for properties at this directory.
-- You don't need to include this file. The engine will do it itself.

function composeSimpleProperty(
-- the Main_OnCommand ID or its list
cmd,
-- The property label
msg
)
local usual = {
get = function(self)
-- If user has SWS installed, omit the msg parameter
if type(cmd) ~= "table" then
if reaper.APIExists("CF_GetCommandText") then
msg = string.match(reaper.CF_GetCommandText(0, cmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, cmd)
msg = msg:gsub("[.]+$", "")
end
end
local message = initOutputMessage()
message:initType(string.format("Perform this property to call the %s action.", msg), "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
message(msg)
return message
end,
set = function(self, action)
if action == actions.set.perform then
local message = initOutputMessage()
restorePreviousLayout()
local oldTracksCount, oldItemsCount = reaper.CountTracks(0), reaper.CountMediaItems(0)
if type(cmd) == "table" then
for _, command in ipairs(cmd) do
reaper.Main_OnCommand(command, 1)
end
else
reaper.Main_OnCommand(cmd, 1)
end
local newTracksCount, newItemsCount = reaper.CountTracks(0), reaper.CountMediaItems(0)
if oldTracksCount < newTracksCount then
message(string.format("%u tracks added", newTracksCount-oldTracksCount))
elseif oldTracksCount > newTracksCount then
message(string.format("%u tracks removed", oldTracksCount-newTracksCount))
end
if oldItemsCount < newItemsCount then
if message:extract() ~= "" then
message(" and ")
end
message(string.format("%u items added", newItemsCount-oldItemsCount))
elseif oldItemsCount > newItemsCount then
if message:extract() ~= "" then
message(" and ")
end
message(string.format("%u items removed", oldItemsCount-newItemsCount))
end
setUndoLabel(self:get())
return message
else
return "This property is performable only."
end
end
}
return usual
end

function composeSimpleDialogOpenProperty(
-- the Main_OnCommand ID
cmd,
-- The property label
msg
)
local usual = {
get = function(self)
local message = initOutputMessage()
message:initType(string.format("Perform this property to open the %s dialog.", msg), "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
message(msg)
return message
end,
set = function(self, action)
if action == actions.set.perform then
reaper.Main_OnCommand(cmd, 1)
restorePreviousLayout()
setUndoLabel(self:get())
return
else
return "This property is performable only."
end
end
}
return usual
end

function composeExtendedSwitcherProperty(states, cmd, msg, types, getFunction, setFunction, shouldBeOnetime)
local shouldBeOnetime = shouldBeOnetime or true
local usual = {
["msg"] = msg,
getValue = function()
return reaper.GetToggleCommandState(cmd)
end,
setValue = function(value)
reaper.Main_OnCommand(cmd, value)
end,
get = getFunction or function(self)
local message = initOutputMessage()
message:initType(types[1], types[2])
if shouldBeOnetime and config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
message(string.format(msg, states[self.getValue()]))
return message
end,
set = setFunction or function(self, action)
if action == actions.set.perform then
local message = initOutputMessage()
local state = utils.nor(self.getValue())
self.setValue(state)
message(self:get())
if shouldBeOnetime then
restorePreviousLayout()
end
return message
else
return "This property is toggleable only."
end
end
}
return usual
end

function composeExtendedProperty(cmd, msg, types, getFunction, setFunction, shouldBeOnetime)
shouldBeOnetime = shouldBeOnetime or true
local usual = {
["msg"] = msg,
get = getFunction or function(self)
-- If user has SWS installed, omit the msg parameter
if type(cmd) ~= "table" then
if reaper.APIExists("CF_GetCommandText") then
msg = string.match(reaper.CF_GetCommandText(0, cmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, cmd)
msg = msg:gsub("[.]+$", "")
end
end
local message = initOutputMessage()
message:initType(types[1], types[2])
if shouldBeOnetime and config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
message(msg)
return message
end,
set = setFunction or function(self, action)
if action == actions.set.perform then
if type(cmd) == "table" then
for _, command in ipairs(cmd) do
reaper.Main_OnCommand(command, 0)
end
else
reaper.Main_OnCommand(cmd, 0)
end
if shouldBeOnetime then
restorePreviousLayout()
end
return
else
return "This property is performable only."
end
end
}
return usual
end
