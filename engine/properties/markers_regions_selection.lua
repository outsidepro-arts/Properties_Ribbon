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

-- Reading the sublayout
local sublayout = extstate[currentLayout.."_sublayout"]
local mrretval, numMarkers, numRegions = reaper.CountProjectMarkers(0)

-- Just a few internal functions
local function checkMarkerAction()
local state = extstate.mrkregLayout_mrkstate
if state then
state = splitstring(state)
return tonumber(state[1]), tonumber(state[2])
end
return nil
end

local function checkRegionAction()
local state = extstate.mrkregLayout_rgnstate
if state then
state = splitstring(state)
return tonumber(state[1]), tonumber(state[2])
end
return nil
end

local function clearMarkerAction()
extstate.mrkregLayout_mrkstate = nil
end

local function setMarkerAction(mrkid, mrkaction)
extstate.mrkregLayout_mrkstate = ("%u %u"):format(mrkid, mrkaction)
end

local function setRegionAction(rgnid, rgnaction)
extstate.mrkregLayout_rgnstate = ("%u %u"):format(rgnid, rgnaction)
end

local function clearRegionAction()
extstate.mrkregLayout_rgnstate = nil
end


-- Main class initialization
local parentLayout = initLayout("Time%s selection")

function parentLayout.canProvide()
return (mrretval > 0)
end

if numMarkers > 0 then
parentLayout:registerSublayout("markersLayout", "Markers ")
for i = 0, numMarkers-1 do
local  retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
if retval and not isrgn then
parentLayout.markersLayout:registerProperty({
states = setmetatable({
[1] = "Edit ",
[2] = "Delete "
}, {
__index = function(self, action)
return ""
end
}),
position = pos,
str = name,
clr = color,
mIndex = markrgnindexnumber,
get = function(self)
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose one of actions for marker on.", "Adjustable, performable")
local lastID, lastAction = checkMarkerAction()
if (lastID and lastAction) and (lastID == self.mIndex) then
message(self.states[lastAction])
message:addType(string.format(" Perform this property to %sthis marker.", self.states[lastAction]), 1)
else
message:addType(" Perform this property to move the edit cursor to the marker position.", 1)
clearMarkerAction()
end
message(string.format("Marker %u", self.mIndex))
if self.clr > 0 then
message(string.format(", color %s", colors:getName(reaper.ColorFromNative(self.clr))))
end
if self.str ~= "" then
message(string.format(", %s", self.str))
else
message("unnamed")
end
return message
end,
set = function(self, action)
local message = initOutputMessage()
local _, lastAction = checkMarkerAction()
if action == true then
if lastAction == nil then
lastAction = 0
end
if (lastAction+1) <= #self.states then
setMarkerAction(self.mIndex, lastAction+1)
else
message("No more next marker actions.")
end
elseif action == false then
if lastAction == nil then
lastAction = 0
end
if (lastAction-1) > 0 then
setMarkerAction(self.mIndex, lastAction-1)
elseif (lastAction-1) == 0 then
clearMarkerAction()
message("Move to")
else
message("No more previous marker actions.")
end
elseif action == nil then
if lastAction == 1 then
-- There is no any different method to show the standart dialog window for user
message("Editing the")
reaper.SetEditCurPos(self.position, true, true)
reaper.Main_OnCommand(40614, 0)
elseif lastAction == 2 then
if reaper.ShowMessageBox(string.format("Are you sure you want to delete the marker %u?", self.mIndex), "Delete marker", 4) == 6 then
message(self:get())
reaper.DeleteProjectMarker(0, self.mIndex, false)
return message
else
return "Canceled"
end
else
reaper.SetEditCurPos(self.position, true, true)
message("Moving to")
end
end
message(self:get())
return message
end
})
end
end
-- Hack our sublayout a little to avoid the engine to call  not existing properties
setmetatable(parentLayout.markersLayout.properties, {
__index = function(self, key)
parentLayout.pIndex = #parentLayout.markersLayout.properties
return parentLayout.markersLayout.properties[#parentLayout.markersLayout.properties]
end
})
end


-- Regions loading
if numRegions > 0 then
parentLayout:registerSublayout("regionsLayout", "Regions ")
for i = 0, numRegions-1 do
local  retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
if retval and isrgn then
parentLayout.regionsLayout:registerProperty({
states = setmetatable({
[1] = "Move to end of ",
[2] = "Edit ",
[3] = "Delete "
}, {
__index = function(self, action)
return ""
end
}),
position = pos,
endPosition = rgnend,
str = name,
clr = color,
rIndex = markrgnindexnumber,
get = function(self)
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose one of actions for the region on.", "Adjustable, performable")
local lastID, lastAction = checkRegionAction()
if (lastID and lastAction) and (lastID == self.rIndex) then
message(self.states[lastAction])
message:addType(string.format(" Perform this property to %sthis region.", self.states[lastAction]), 1)
else
message:addType(" Perform this property to move the edit cursor to the start position of this region.", 1)
clearRegionAction()
end
message(string.format("Region %u", self.rIndex))
if self.clr > 0 then
message(string.format(", color %s", colors:getName(reaper.ColorFromNative(self.clr))))
end
if self.str ~= "" then
message(string.format(", %s", self.str))
else
message("unnamed")
end
return message
end,
set = function(self, action)
local message = initOutputMessage()
local _, lastAction = checkRegionAction()
if action == true then
if lastAction == nil then
lastAction = 0
end
if (lastAction+1) <= #self.states then
setRegionAction(self.rIndex, lastAction+1)
else
message("No more next region actions.")
end
elseif action == false then
if lastAction == nil then
lastAction = 0
end
if (lastAction-1) > 0 then
setRegionAction(self.rIndex, lastAction-1)
elseif (lastAction-1) == 0 then
clearRegionAction()
message("Move to start of")
else
message("No more previous region actions.")
end
elseif action == nil then
if lastAction == 1 then
reaper.SetEditCurPos(self.endPosition, true, true)
elseif lastAction == 2 then
-- There is no any different method to show the standart dialog window for user
message("Editing the")
reaper.SetEditCurPos(self.position, true, true)
reaper.Main_OnCommand(40616, 0)
elseif lastAction == 3 then
if reaper.ShowMessageBox(string.format("Are you sure you want to delete the region %u?", self.rIndex), "Delete region", 4) == 6 then
message(self:get())
reaper.DeleteProjectMarker(0, self.rIndex, true)
return message
else
return "Canceled"
end
else
reaper.SetEditCurPos(self.position, true, true)
message("Moving to")
end
end
message(self:get())
return message
end
})
end
end
-- Hack our sublayout a little to avoid the engine to call  not existing properties
setmetatable(parentLayout.regionsLayout.properties, {
__index = function(self, key)
parentLayout.pIndex = #parentLayout.regionsLayout.properties
return parentLayout.regionsLayout.properties[#parentLayout.regionsLayout.properties]
end
})
end

-- Dynamic sublayouts still have bugs... Crap!
if parentLayout[sublayout] then
return parentLayout[sublayout]
else
if numMarkers > 0 then
 return parentLayout["markersLayout"]
elseif numRegions > 0 then
return parentLayout["regionsLayout"]
end
end
