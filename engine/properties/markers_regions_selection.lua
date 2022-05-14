--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
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


-- Before define which sublayout we will load when no sublayout found, just load all marker/regions data.
-- Also, it will be used in other cases
local mrretval, numMarkers, numRegions = reaper.CountProjectMarkers(0)


-- Reading the color from color composer specified section
local function getMarkersComposedColor()
return extstate.colcom_marker_curValue
end

-- Main class initialization
local parentLayout = initLayout("Markers and regions management")

-- This layout is available always because here creating markers/regions property is.

parentLayout:registerSublayout("markersLayout", "Markers")

local markersActionsProperty = {}
parentLayout.markersLayout:registerProperty(markersActionsProperty)

function markersActionsProperty:get()
local message = initOutputMessage()
message:initType("", "")
message("Markers operations")
return message
end

markersActionsProperty.extendedProperties = initExtendedProperties(markersActionsProperty:get():extract(nil, false))

markersActionsProperty.extendedProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Perform this property to add new marker at play or edit cursor position.", "Performable")
message("Insert marker at current position")
return message
end,
set_perform = function(self, parent)
reaper.Main_OnCommand(40157, 0)
-- OSARA reports the marker creation events
setUndoLabel(self:get())
return false
end
}

markersActionsProperty.extendedProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("")
message("Insert and edit marker at current position")
return message
end,
set_perform = function(self, parent)
reaper.Main_OnCommand(40171, 0)
-- OSARA reports the marker creation events
setUndoLabel(self:get())
return false
end
}
markersActionsProperty.extendedProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Perform this property to renumber all marker in project timeline. Please note: the standart REAPER action used here, so all regions will be renumbered aswell.", "Performable")
message("Renumber all markers in timeline order")
return message
end,
set_perform = function(self, parent)
if numMarkers > 0 then
if reaper.ShowMessageBox("Since the main action for renumbering is used, all regions will be renumbered aswell. Would you like to continue?", "Please note", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
reaper.Main_OnCommand(40898, 0)
return true, "All markers were renumbered."
else
return false, "Canceled."
end
end
return false, "There are no markers which to be renumbered."
end
}
markersActionsProperty.extendedProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Perform this property to remove all markers in time selection.", "performable")
message("Remove all markers from time selection")
return message
end,
set_perform = function(self, parent)
reaper.Main_OnCommand(40420, 0)
setUndoLabel(self:get())
return true, nil, true
end
}
markersActionsProperty.extendedProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Perform this property to remove all markers in the project.", "Performable")
message("Clear all markers")
return message
end,
set_perform = function (self, parent)
local countDeletedMarkers = 0
for i = 0, numMarkers do
if reaper.DeleteProjectMarker(0, i, false) then
countDeletedMarkers = countDeletedMarkers+1
end
end
if countDeletedMarkers > 0 then
return true, string.format("%u markers has been deleted.", countDeletedMarkers)
else
return false, "There are no markers to delete."
end
end
}

markerActions = initExtendedProperties("Marker actions")

markerActions:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to move the play or edit cursor to the marker's position.", "Performable")
message("Go to marker position")
return message
end,
set_perform = function (self, parent)
local message = initOutputMessage()
reaper.GoToMarker(0, parent.mIndex, true)
message("Jumping to")
message{value=representation.defpos[reaper.GetCursorPosition()]}
return true, message
end
}
markerActions:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to edit this marker.", "Performable")
message("Edit marker")
return message	
end,
set_perform = function (self, parent)
-- There is no any different method to show the standart dialog window for user
local prevPosition = reaper.GetCursorPosition()
reaper.SetEditCurPos(self.position, false, false)
reaper.Main_OnCommand(40614, 0)
reaper.SetEditCurPos(prevPosition, false, false)
setUndoLabel(self:get())
return true
end
}
markerActions:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to delete this marker.", "Performable")
message("Delete marker")
return message
end,
set_perform = function (self, parent)
reaper.DeleteProjectMarker(0, parent.mIndex, false)
return true, string.format("Marker %u has been deleted.", parent.mIndex)
end
}


if numMarkers > 0 then
for i = 0, (numMarkers+numRegions)-1 do
local  retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
if retval and not isrgn then
parentLayout.markersLayout:registerProperty({
position = pos,
str = name,
clr = color,
mIndex = markrgnindexnumber,
extendedProperties = markerActions,
get = function(self)
local message = initOutputMessage()
message:initType("", "")
if self.clr > 0 then
message{objectId=colors:getName(reaper.ColorFromNative(self.clr))}
end
message{label=string.format("Marker %u", self.mIndex)}
if self.str ~= "" then
message{label=string.format(", %s", self.str)}
end
return message
end
})
end
end
end


-- Regions loading
parentLayout:registerSublayout("regionsLayout", "Regions")
local regionsActionsProperty = {}
parentLayout.regionsLayout:registerProperty(regionsActionsProperty)

function regionsActionsProperty:get()
local message = initOutputMessage()
message:initType("", "")
message("Regions operations")
return message
end

regionsActionsProperty.extendedProperties = initExtendedProperties(regionsActionsProperty:get():extract(nil, false))

regionsActionsProperty.extendedProperties:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to insert new region from time selection.", "Performable")
message("Insert region from time selection")
return message
end,
set_perform = function (self, parent)
reaper.Main_OnCommand(40174, 0)
setUndoLabel(self:get())
return false
end
}
regionsActionsProperty.extendedProperties:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to insert new region from time selection and edit it.", "Performable")
message("Insert region from time selection and edit")
return message
end,
set_perform = function (self, parent)
reaper.Main_OnCommand(40306, 0)
return true
end
}
regionsActionsProperty.extendedProperties:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to insert new region from selected items.", "Performable")
message("Insert region from selected items")
return message
end,
set_perform = function (self, parent)
reaper.Main_OnCommand(40348, 0)
setUndoLabel(self:get())
return true, nil, true
end
}
regionsActionsProperty.extendedProperties:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to create new region from selected items then edit it.", "Performable")
message("Insert region from selected items and edit")
return message
end,
set_perform = function (self, parent)
reaper.Main_OnCommand(40348, 0)
return true, nil, true
end
}
regionsActionsProperty.extendedProperties:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to create separate region for each selected item.", "Performable")
message("Insert separate regions for each selected item")
return message
end,
set_perform = function (self, parent)
reaper.Main_OnCommand(41664, 0)
return true, nil, true
end
}
regionsActionsProperty.extendedProperties:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to renumber all regions in project timeline. Please note: the standart REAPER action used here, so all markers will be renumbered aswell.", "Performable")
message("Renumber all markers and regions in timeline order")
return message
end,
set_perform = function (self, parent)
if numRegions > 0 then
if reaper.ShowMessageBox("Since the main action for renumbering is used, all markers will be renumbered aswell. Would you like to continue?", "Please note", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
reaper.Main_OnCommand(40898, 0)
return true, "All markers and regions were renumbered."
else
return false, "Canceled."
end
else
return false, "There are no regions which to be renumbered."
end
end
}
regionsActionsProperty.extendedProperties:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to clear all regions in this project.", "Performable")
message("Clear all regions")
return message
end,
set_perform = function (self, parent)
local countDeletedRegions = 0
for i = 0, (numMarkers+numRegions) do
if reaper.DeleteProjectMarker(0, i, true) then
countDeletedRegions = countDeletedRegions+1
end
end
if countDeletedRegions > 0 then
return true, string.format("%u regions deleted. ", countDeletedRegions)
else
return false, "There are no regions to delete."
end
end
}
local regionActions = initExtendedProperties("Region actions")

regionActions:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to smooth seek to the region position after currently region finishes playing..", "Performable")
message("Smooth seek to the region")
return message
end,
set_perform = function (self, parent)
local message = initOutputMessage()
reaper.GoToRegion(0, parent.rIndex, true)
message("Smooth seek to")
message{value=representation.defpos[reaper.GetCursorPosition()]}
return false, message
end
}
regionActions:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to move the play or edit cursor to the timestamp when this region starts.", "Performable")
message("Immediately jump to start of this region")
return message
end,
set_perform = function (self, parent)
local message = initOutputMessage()
reaper.SetEditCurPos(parent.position, true, true)
message{label="Jumping to"}
message{value=representation.defpos[reaper.GetCursorPosition()]}
return false, message
end
}
regionActions:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to move the play or edit cursor to the timestamp when this region ends.", "Performable")
message("Immediately jump to end of this region")
return message
end,
set_perform = function (self, parent)
local message = initOutputMessage()
reaper.SetEditCurPos(parent.endPosition, true, true)
message{label="Jumping to"}
message{value=representation.defpos[reaper.GetCursorPosition()]}
return message
end
}
regionActions:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to edit this region.", "Performable")
message("Edit region")
return message
end,
set_perform = function (self, parent)
-- There is no any different method to show the standart dialog window for user
local prevPosition = reaper.GetCursorPosition()
reaper.SetEditCurPos(self.position, false, false)
reaper.Main_OnCommand(40616, 0)
reaper.SetEditCurPos(prevPosition, false, false)
return true
end
}
regionActions:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to delete this marker.", "Performable")
message("Delete region")
return message
end,
set_perform = function (self, parent)
reaper.DeleteProjectMarker(0, parent.rIndex, true)
return true, string.format("Region %u deleted.", parent.rIndex)
end
}

if numRegions > 0 then
for i = 0, (numMarkers+numRegions)-1 do
local  retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
if retval and isrgn then
parentLayout.regionsLayout:registerProperty({
position = pos,
endPosition = rgnend,
str = name,
clr = color,
rIndex = markrgnindexnumber,
get = function(self)
local message = initOutputMessage()
message:initType("", "")
if shouldSaveAnAction  and  extstate.mrkregLayout_rgnstate then
message(self.states[extstate.mrkregLayout_rgnstate])
--message:addType(string.format(" Perform this property to %sthis region.", self.states[lastAction]), 1)
else
--message:addType(" Perform this property to go to this region after previously region finishes playing (also as known as smooth seek).", 1)
extstate.mrkregLayout_rgnstate = nil
end
if self.clr > 0 then
message{objectId=colors:getName(reaper.ColorFromNative(self.clr))}
end
message{label=string.format("Region %u", self.rIndex)}
if self.str ~= "" then
message{value=self.str}
end
return message
end,
extendedProperties = regionActions
})
end
end
end


return parentLayout