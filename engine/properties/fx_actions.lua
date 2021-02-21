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

local contexts = {
[0]="Current track",
[1]="Selected item take",
[true]="Master track"
}


local context = nil
if reaper.GetLastTouchedTrack() == reaper.GetMasterTrack(0) then
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

local fxActionsLayout = initLayout(("%s FX actions"):format(contexts[context]))

function fxActionsLayout.canProvide()
local context = reaper.GetCursorContext()
if context == 0 or context == 1 or context == true then
return true
end
return false
end


local function getUsualProperty(_cmd, _msg, availableness)
local usual = {
-- the Main_OnCommand ID
cmd = _cmd,
-- The property label
msg = _msg,
get = function(self)
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), string.format("Perform this property to call the %s action.", self.msg), "Performable")
if not availableness then
message:addType(" This action is unavailable right now because there are no FX.", 1)
message:changeType("Unavailable", 2)
end
message(self.msg)
return message
end,
set = function(self, action)
if action == nil then
if availableness then
reaper.Main_OnCommand(self.cmd, 1)
return ""
else
return "This action is unavailable right now because no one FX is set there."
end
else
return "This property is performable only."
end
end
}
return usual
end

if context == 0 then
fxActionsLayout:registerProperty(getUsualProperty(40291, "View FX chain for current track", true))
fxActionsLayout:registerProperty(getUsualProperty(40298, "Toggle FX bypass for  current track", isAvailable()))
elseif context == 1 then
fxActionsLayout:registerProperty(getUsualProperty(40638, "Show FX chain for item take", true))
if reaper.APIExists("CF_GetSWSVersion") == true then
fxActionsLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_S&M_TGL_TAKEFX_BYP"), "Toggle all take FX bypass for selected items", isAvailable()))
end
elseif context == true then
fxActionsLayout:registerProperty(getUsualProperty(40846, "View FX chain for master track", true))
fxActionsLayout:registerProperty(getUsualProperty(16, "Toggle FX bypass for master track", isAvailable()))
end
fxActionsLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_OSARA_FXPARAMS"), ("View OSARA FX parameters for %s"):format(contexts[context]), isAvailable()))

return fxActionsLayout