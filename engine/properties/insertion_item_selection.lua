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
reaper.SetCursorContext(1)

local insertionLayout = initLayout("Item insertion actions")

function insertionLayout.canProvide()
if reaper.CountSelectedTracks() > 0 then
return true
end
return false
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
message:initType(string.format("Perform this property to call the %s action.", self.msg), "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
message(self.msg)
return message
end,
set = function(self, action)
if action == nil then
restorePreviousLayout()
local oldItemsCount = reaper.CountMediaItems(0)
reaper.Main_OnCommand(self.cmd, 1)
local newItemsCount = reaper.CountMediaItems(0)
if oldItemsCount < newItemsCount then
return string.format("%u items added", newItemsCount-oldItemsCount)
elseif oldItemsCount > newItemsCount then
return string.format("%u items removed", oldItemsCount-newItemsCount)
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

insertionLayout:registerProperty(getUsualProperty(40214, "Insert new MIDI item"))
insertionLayout:registerProperty(getUsualProperty(40142, "Insert empty item"))
insertionLayout:registerProperty(getUsualProperty(41748, "Insert time on tracks and paste items"))
insertionLayout:registerProperty(getUsualProperty(42069, "Insert or extend MIDI items to fill time selection"))

return insertionLayout