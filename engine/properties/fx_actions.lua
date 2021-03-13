--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts
License: MIT License

----------

Let me say a few word before starts
LUA - is not object oriented programming language, but very flexible. Its flexibility allows to realize OOP easy via metatables. In this scripts the pseudo OOP has been used, therefore we have to understand some terms.
.1 When i'm speaking "Class" i mean the metatable variable with some fields.
2. When i'm speaking "Method" i mean a function attached to a field or submetatable field.
When i was starting write this scripts complex i imagined this as real OOP. But in consequence the scripts structure has been reunderstanded as current structure. It has been turned out more comfort as for writing new properties table, as for call this from main script engine.
After this preambula, let me begin.
]]--

-- It's just another vision of Properties Ribbon can be applied on

local sublayout = extstate[currentLayout.."_sublayout"] or "mainLayout"

local contexts = {
[0]="Current track",
[1]="Selected item take",
[true]="Master track"
}


local context = nil
if not reaper.GetLastTouchedTrack() or reaper.GetLastTouchedTrack() == reaper.GetMasterTrack(0) then
context = true
else
context = reaper.GetCursorContext()
end

-- Checking availableness of context perform
local function isAvailable()
if (context == 0 and reaper.TrackFX_GetCount(reaper.GetLastTouchedTrack()) > 0) or (context == 1 and reaper.TakeFX_GetCount(reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, 0))) > 0) or (context == true and reaper.TrackFX_GetCount(reaper.GetMasterTrack()) > 0) then
return true
end
return false
end

local fxActionsLayout = nil
-- We should check the monitoring section FX count to solve create a sublayouts or not
if reaper.TrackFX_GetRecCount(reaper.GetMasterTrack()) == 0 then
fxActionsLayout = initLayout(("%s FX actions"):format(contexts[context]))
else
fxActionsLayout = initLayout("%sFX actions")
fxActionsLayout:registerSublayout("mainLayout", contexts[context])
fxActionsLayout:registerSublayout("monitoringLayout", "Monitoring")
end


function fxActionsLayout.canProvide()
local context = reaper.GetCursorContext()
if reaper.GetLastTouchedTrack() then
return (context == 0 or context == 1 or context == true)
end
return false
end

-- Registering properties macros
-- We need this because it forces us check a sublayout existing each time
local function registerProperty(sl, property)
if fxActionsLayout[sl] then
fxActionsLayout[sl]:registerProperty(property)
else
fxActionsLayout:registerProperty(property)
end
end

-- FX chain action
registerProperty("mainLayout", {
get = function(self)
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), ("Perform this property to show the %s FX chain."):format(contexts[context]), "Performable")
message(("View FX chain for %s"):format(contexts[context]))
return message
end,
set = function(self, action)
local commands = {
[0]=40291,
[1]=40638,
[true]=40846
}
if action == nil then
reaper.Main_OnCommand(commands[context], 0)
return ""
else
return "This property is performable only."
end
end
})

-- Bypass all FX action
-- It must not be created if context is items and SWS is not installed
if context ~= 1 or (context == 1 and reaper.APIExists("CF_GetSWSVersion")) then
registerProperty("mainLayout", {
states = {
[0]="Activate",
[1]="Bypass"
},
commands = {
[0]=40298,
[1]=reaper.NamedCommandLookup("_S&M_TGL_TAKEFX_BYP"),
[true]=16
},
get = function(self)
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), ("Toggle this property to bypass or activate the %s FX chain."):format(contexts[context]), "Toggleable")
if not isAvailable() then
message:addType(" This action is unavailable right now because there are no FX.", 1)
message:changeType("Unavailable", 2)
end
 local state = reaper.GetMediaTrackInfo_Value(reaper.GetLastTouchedTrack(), "I_FXEN")
message(("%s all %s FX"):format(self.states[state], contexts[context]))
return message
end,
set = function(self, action)
if action == nil then
if isAvailable() then
local state = reaper.GetMediaTrackInfo_Value(reaper.GetLastTouchedTrack(), "I_FXEN")
reaper.Main_OnCommand(self.commands[context], nor(state))
return ""
else
return "This action is unavailable right now because no one FX is set there."
end
else
return "This property is performable only."
end
end
})
end

-- OSARA FX parameters action
registerProperty("mainLayout", {
get = function(self)
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), ("Perform this property to show the %s FX parameters using OSARA."):format(contexts[context]), "Performable")
if context == true and reaper.TrackFX_GetRecCount(reaper.GetMasterTrack()) > 0 then
message:addType(" The FX which have being added to monitoring section will display also here.", 1)
elseif context == 0 and reaper.TrackFX_GetRecCount(reaper.GetLastTouchedTrack()) > 0 then
message:addType(" The FX which have being added to track input FX chain will display also here.", 1)
end
local available = (isAvailable() or (context == true and reaper.TrackFX_GetRecCount(reaper.GetMasterTrack()) > 0) or (context == 0 and reaper.TrackFX_GetRecCount(reaper.GetLastTouchedTrack()) > 0))
if not available then
message:addType(" This action is unavailable right now because there are no FX.", 1)
message:changeType("Unavailable", 2)
end
message(("View OSARA FX parameters for %s"):format(contexts[context]))
if context == true and reaper.TrackFX_GetRecCount(reaper.GetMasterTrack()) > 0 then
message(" and monitoring section")
elseif context == 0 and reaper.TrackFX_GetRecCount(reaper.GetLastTouchedTrack()) > 0 then
message(" and input FX chain")
end
return message
end,
set = function(self, action)
if action == nil then
local available = (isAvailable() or (context == true and reaper.TrackFX_GetRecCount(reaper.GetMasterTrack()) > 0) or (context == 0 and reaper.TrackFX_GetRecCount(reaper.GetLastTouchedTrack()) > 0))
if available then
reaper.Main_OnCommand(reaper.NamedCommandLookup("_OSARA_FXPARAMS"), 0)
return ""
else
return "This action is unavailable right now because no one FX is set there."
end
else
return "This property is performable only."
end
end
})

-- Monitoring FX actions
-- To these action will be available, an user should activate the monitoring FX chain from the appropriated menu and set some there, so anyone shouldn't see the superfluous sublayouts.
 if reaper.TrackFX_GetRecCount(reaper.GetMasterTrack()) > 0 then
-- Monitoring FX chain
registerProperty("monitoringLayout", {
get = function(self)
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Perform this property to show the monitoring FX chain.", "Performable")
message("View FX chain for monitoring FX")
return message
end,
set = function(self, action)
if action == nil then
reaper.Main_OnCommand(41882, 0)
return ""
else
return "This property is performable only."
end
end
})

-- Monitoring bypass
registerProperty("monitoringLayout", {
states = {
[0]="Bypass",
[1]="Activate"
},
get = function(self)
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to bypass or activate all monitoring FX.", "Toggleable")
local state = reaper.GetToggleCommandState(41884)
message(("%s all monitoring FX"):format(self.states[state]))
return message
end,
set = function(self, action)
if action == nil then
local state = reaper.GetToggleCommandState(41884)
reaper.Main_OnCommand(41884, nor(state))
return ""
else
return "This property is performable only."
end
end
})

return fxActionsLayout[sublayout]
end


return fxActionsLayout