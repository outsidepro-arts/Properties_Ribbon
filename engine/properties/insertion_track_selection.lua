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

-- Set the cursor context forced
-- For what? REAPER should set the some actions to track context that user can perform them
reaper.SetCursorContext(0)
local insertionLayout = initLayout("Track insertion actions")

function insertionLayout.canProvide()
return true
end

-- The properties functions template

local function getUsualProperty(_cmd, _msg)
local usual = {
-- the Main_OnCommand ID
cmd = _cmd,
-- The property label
msg = _msg,
get = function(self)
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), string.format("Perform this property to call the %s action.", self.msg), "Performable")
message(self.msg)
return message
end,
set = function(self, action)
if action == nil then
local oldTracksCount = reaper.CountTracks(0)
reaper.Main_OnCommand(self.cmd, 1)
local newTracksCount = reaper.CountTracks(0)
if oldTracksCount < newTracksCount then
return string.format("%u tracks added", newTracksCount-oldTracksCount)
elseif oldTracksCount > newTracksCount then
return string.format("%u tracks removed", oldTracksCount-newTracksCount)
end
return ""
else
return "This property is performable only."
end
end
}
return usual
end

insertionLayout:registerProperty(getUsualProperty(40701, "Insert virtual instrument on new track"))
insertionLayout:registerProperty(getUsualProperty(40001, "Insert new track"))
insertionLayout:registerProperty(getUsualProperty(40702, "Insert new track at end of track list"))
insertionLayout:registerProperty(getUsualProperty(46000, "Insert track from template"))
insertionLayout:registerProperty(getUsualProperty(41067, "Insert multiple new tracks"))

return insertionLayout