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
-- The property label (optional)
msg
)
local usual = {
get = function(self)
local message = initOutputMessage()
message:initType("Perform this property to execute the specified action.", "Performable")
if msg then
message(msg)
else
if type(cmd) == "table" then
message:changeType(string.format("Perform this property to execute these %u actions by queued order: ", #cmd),1 )
message("Multiple actions: ")
for id, ccmd in ipairs(cmd) do
local premsg = string.match(reaper.CF_GetCommandText(0, ccmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, ccmd)
premsg = premsg:gsub("[.]+$", "")
message(premsg)
if id < #cmd-1 then
message(", ")
elseif id == #cmd-1 then
message(" and ")
end
end
else
local premsg = string.match(reaper.CF_GetCommandText(0, cmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, cmd)
premsg = premsg:gsub("[.]+$", "")
message(premsg)
end
end
if config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
return message
end,
set_perform = function(self)
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
if #message > 0 then
message(" and ")
end
message(string.format("%u items added", newItemsCount-oldItemsCount))
elseif oldItemsCount > newItemsCount then
if #message > 0 then
message(" and ")
end
message(string.format("%u items removed", oldItemsCount-newItemsCount))
end
return message	
end
}
return usual
end

function composeSimpleDialogOpenProperty(
-- the Main_OnCommand ID
cmd,
-- The property label (optional)
msg
)
local usual = {
get = function(self)
local message = initOutputMessage()
message:initType("Perform this property to open the specified window.", "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
if msg then
message(msg)
else
local premsg = string.match(reaper.CF_GetCommandText(0, cmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, cmd)
premsg = premsg:gsub("[.]+$", "")
message(premsg)
end
return message
end,
set_perform = function(self, action)
reaper.Main_OnCommand(cmd, 1)
restorePreviousLayout()
setUndoLabel(self:get())
return
end
}
return usual
end

function composeExtendedSwitcherProperty(states, cmd, msg, types, getFunction, setFunction, shouldBeOnetime)
shouldBeOnetime = shouldBeOnetime or true
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
if msg then
message(string.format(msg, states[self.getValue()]))
else
local premsg = string.match(reaper.CF_GetCommandText(0, cmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, cmd)
premsg = premsg:gsub("[.]+$", "")
message{label=premsg}
message{value=states[self.getValue()]}
end
return message
end,
set_perform = setFunction or function(self)
local message = initOutputMessage()
local state = utils.nor(self.getValue())
self.setValue(state)
message(self:get())
if shouldBeOnetime then
restorePreviousLayout()
end
return message
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
if msg then
message(msg)
else
local premsg = string.match(reaper.CF_GetCommandText(0, cmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, cmd)
premsg = premsg:gsub("[.]+$", "")
message(premsg)
end
return message
end,
set_perform = setFunction or function(self, action)
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
end
}
return usual
end
