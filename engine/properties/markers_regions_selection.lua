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

local markerActionsProperty = {}
parentLayout.markersLayout:registerProperty(markerActionsProperty)
markerActionsProperty.states = {
[0] = "Insert marker at current position",
[1] = "Insert and edit marker at current position",
[2] = "Renumber all markers in timeline order",
[3] = "Remove all markers from time selection",
[4] = "Clear all markers"
}

function markerActionsProperty:get(shouldSaveAnAction)
local message = initOutputMessage()
message:initType("Adjust this property to choose aproppriate action. Perform this property to apply chosen action. Please note, a chosen action stores only when you're adjusting this, when you're navigating through, the action will be reset.", "Adjustable, performable")
if extstate.mrkregLayout_mrkstate and not shouldSaveAnAction then
extstate.mrkregLayout_mrkstate = nil
end
message(self.states[extstate.mrkregLayout_mrkstate or 0])
return message
end

function markerActionsProperty:set(action)
local message = initOutputMessage()
local state = extstate.mrkregLayout_mrkstate or 0
if action == actions.set.increase then
if (state+1) <= #self.states then
extstate.mrkregLayout_mrkstate = state+1
else
message("No more next property values. ")
end
elseif action == actions.set.decrease then
if (state-1) >= 0 then
extstate.mrkregLayout_mrkstate = state-1
else
message("No more previous property values. ")
end
elseif action == nil then
if state == 1 then
reaper.Main_OnCommand(40171, 0)
-- OSARA reports the marker creation events
setUndoLabel(self:get(true))
return
elseif state == 2 then
if numMarkers > 0 then
if reaper.ShowMessageBox("Since the main action for renumbering is used, all regions will be renumbered aswell. Would you like to continue?", "Please note", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
reaper.Main_OnCommand(40898, 0)
return "All markers were renumbered."
else
return "Canceled."
end
else
return "There are no markers which to be renumbered."
end
elseif state == 3 then
reaper.Main_OnCommand(40420, 0)
-- OSARA reports the marker creation events
setUndoLabel(self:get(true))
return
elseif state == 4 then
local countDeletedMarkers = 0
for i = 0, numMarkers do
if reaper.DeleteProjectMarker(0, i, false) then
countDeletedMarkers = countDeletedMarkers+1
end
end
if countDeletedMarkers > 0 then
return string.format("%u markers has been deleted.", countDeletedMarkers)
else
return"There are no markers to delete."
end
else
reaper.Main_OnCommand(40157, 0)
-- OSARA reports the marker creation events
setUndoLabel(self:get(true))
return
end
end
message(self:get(true))
return message
end

if numMarkers > 0 then
for i = 0, (numMarkers+numRegions)-1 do
local  retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
if retval and not isrgn then
parentLayout.markersLayout:registerProperty({
states = setmetatable({
[1] = "Edit",
[2] = "Colorize",
[3] = "Delete"
}, {
__index = function(self, action)
return
end
}),
position = pos,
str = name,
clr = color,
mIndex = markrgnindexnumber,
get = function(self, shouldSaveAnAction)
local message = initOutputMessage()
message:initType("Adjust this marker property to choose one of actions for. Perform this marker property to either set the edit or play cursor on its position if no action has been chosen, or apply chosen action.", "Adjustable, performable")
if shouldSaveAnAction and extstate.mrkregLayout_mrkstate then
message(self.states[extstate.mrkregLayout_mrkstate])
--message:addType(string.format(" Perform this property to %sthis marker.", self.states[lastAction]), 1)
else
--message:addType(" Perform this property to move the edit cursor to the marker position.", 1)
extstate.mrkregLayout_mrkstate = nil
end
if self.clr > 0 then
message{objectId=colors:getName(reaper.ColorFromNative(self.clr))}
end
message{label=string.format("Marker %u", self.mIndex)}
if self.str ~= "" then
message{label=string.format(", %s", self.str)}
end
return message
end,
set = function(self, action)
local message = initOutputMessage()
local lastAction = extstate.mrkregLayout_mrkstate or 0
if action == actions.set.increase then
if (lastAction+1) <= #self.states then
extstate.mrkregLayout_mrkstate = lastAction+1
else
message("No more next marker actions.")
end
elseif action == actions.set.decrease then
if (lastAction-1) > 0 then
extstate.mrkregLayout_mrkstate = lastAction-1
elseif (lastAction-1) == 0 then
extstate.mrkregLayout_mrkstate = nil
message("Jump to")
else
message("No more previous marker actions.")
end
elseif action == actions.set.perform then
if lastAction == 1 then
-- There is no any different method to show the standart dialog window for user
local prevPosition = reaper.GetCursorPosition()
reaper.SetEditCurPos(self.position, false, false)
reaper.Main_OnCommand(40614, 0)
reaper.SetEditCurPos(prevPosition, false, false)
setUndoLabel(self:get(true))
return
elseif lastAction == 2 then
local precolor = getMarkersComposedColor()
if precolor then
reaper.SetProjectMarker4(0, self.mIndex, false, self.position, 0, self.str, precolor|0x1000000, 0)
return string.format("Marker %u colorized to %s color.", self.mIndex, colors:getName(reaper.ColorFromNative(precolor)))
else
return "Compose any color for markers or regions first."
end
elseif lastAction == 3 then
reaper.DeleteProjectMarker(0, self.mIndex, false)
return string.format("Marker %u has been deleted.", self.mIndex)
else
reaper.GoToMarker(0, self.mIndex, true)
message("Jumping to")
end
end
message(self:get(true))
return message
end
})
end
end
end


-- Regions loading
parentLayout:registerSublayout("regionsLayout", "Regions")
local regionActionsProperty = {}
parentLayout.regionsLayout:registerProperty(regionActionsProperty)
regionActionsProperty.states = {
[0] = "Insert region from time selection",
[1] = "Insert region from time selection and edit",
[2] = "Insert region from selected items",
[3] = "Insert region from selected items and edit",
[4] = "Insert separate regions for each selected item",
[5] = "Renumber all markers and regions in timeline order",
[6] = "Clear all regions"
}

function regionActionsProperty:get(shouldSaveAnAction)
local message = initOutputMessage()
message:initType("Adjust this property to choose aproppriate action. Perform this property to apply chosen action. Please note, a chosen action stores only when you're adjusting this, when you're navigating through, the action will be reset.", "Adjustable, performable")
if extstate.mrkregLayout_rgnstate and not shouldSaveAnAction then
extstate.mrkregLayout_rgnstate = nil
end
message(self.states[extstate.mrkregLayout_rgnstate or 0])
return message
end

function regionActionsProperty:set(action)
local message = initOutputMessage()
local state = extstate.mrkregLayout_rgnstate or 0
if action == actions.set.increase then
if (state+1) <= #self.states then
extstate.mrkregLayout_rgnstate = state+1
else
message("No more next property values. ")
end
elseif action == actions.set.decrease then
if (state-1) >= 0 then
extstate.mrkregLayout_rgnstate = state-1
else
message("No more previous property values. ")
end
elseif action == nil then
if state == 1 then
reaper.Main_OnCommand(40306, 0)
-- OSARA reports the marker creation events
setUndoLabel(self:get(true))
return
elseif state == 2 then
reaper.Main_OnCommand(40348, 0)
elseif state == 3 then
reaper.Main_OnCommand(40393, 0)
-- OSARA reports the marker creation events
setUndoLabel(self:get(true))
return
elseif state == 4 then
reaper.Main_OnCommand(41664, 0)
elseif state == 5 then
if numRegions > 0 then
if reaper.ShowMessageBox("Since the main action for renumbering is used, all markers will be renumbered aswell. Would you like to continue?", "Please note", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
reaper.Main_OnCommand(40898, 0)
return "All markers and regions were renumbered."
else
return "Canceled."
end
else
return "There are no regions which to be renumbered."
end
elseif state == 6 then
local countDeletedRegions = 0
for i = 0, (numMarkers+numRegions) do
if reaper.DeleteProjectMarker(0, i, true) then
countDeletedRegions = countDeletedRegions+1
end
end
if countDeletedRegions == 0 then
return"There are no regions to delete."
end
else
reaper.Main_OnCommand(40174, 0)
-- OSARA reports the marker creation events
return
end
end
local _, _, newNumRegions = reaper.CountProjectMarkers(0)
if numRegions < newNumRegions then
return string.format("%u region%s inserted.", (newNumRegions-numRegions), ({[true] = "s", [false] = ""})[((newNumRegions-numRegions) ~= 1)])
elseif numRegions > newNumRegions then
return string.format("%u region%s deleted.", (numRegions-newNumRegions), ({[true] = "s", [false] = ""})[((newNumRegions-numRegions) ~= 1)])
end
message(self:get(true))
return message
end

if numRegions > 0 then
for i = 0, (numMarkers+numRegions)-1 do
local  retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
if retval and isrgn then
parentLayout.regionsLayout:registerProperty({
states = setmetatable({
[1] = "Immediately jump to start of",
[2]="Immediately jump to end of",
[3] = "Edit",
[4] = "Colorize",
[5] = "Delete"
}, {
__index = function(self, action)
return
end
}),
position = pos,
endPosition = rgnend,
str = name,
clr = color,
rIndex = markrgnindexnumber,
get = function(self, shouldSaveAnAction)
local message = initOutputMessage()
message:initType("Adjust this region property to choose one of actions for. Perform this region property to either set the edit or play cursor on its position if no action has been chosen, or apply chosen action.", "Adjustable, performable")
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
set = function(self, action)
local message = initOutputMessage()
local lastAction = extstate.mrkregLayout_rgnstate or 0
if action == actions.set.increase then
if (lastAction+1) <= #self.states then
extstate.mrkregLayout_rgnstate = lastAction+1
else
message("No more next region actions.")
end
elseif action == actions.set.decrease then
if (lastAction-1) > 0 then
extstate.mrkregLayout_rgnstate = lastAction-1
elseif (lastAction-1) == 0 then
extstate.mrkregLayout_rgnstate = nil
message("Smooth seek to")
else
message("No more previous region actions.")
end
elseif action == nil then
if lastAction == 1 then
reaper.SetEditCurPos(self.position, true, true)
elseif lastAction == 2 then
reaper.SetEditCurPos(self.endPosition, true, true)
elseif lastAction == 3 then
-- There is no any different method to show the standart dialog window for user
local prevPosition = reaper.GetCursorPosition()
reaper.SetEditCurPos(self.position, false, false)
reaper.Main_OnCommand(40616, 0)
reaper.SetEditCurPos(prevPosition, false, false)
setUndoLabel(self:get(true))
return
elseif lastAction == 4 then
local precolor = getMarkersComposedColor()
if precolor then
reaper.SetProjectMarker4(0, self.rIndex, true, self.position, self.endPosition, self.str, precolor|0x1000000, 0)
return string.format("Region %u colorized to %s color.", self.rIndex, colors:getName(reaper.ColorFromNative(precolor)))
else
return "Compose any color for markers or regions first."
end
elseif lastAction == 5 then
reaper.DeleteProjectMarker(0, self.rIndex, true)
return string.format("Region %u deleted.", self.rIndex)
else
reaper.GoToRegion(0, self.rIndex, true)
message("Smooth seek to")
end
end
message(self:get(true))
return message
end
})
end
end
end


return parentLayout