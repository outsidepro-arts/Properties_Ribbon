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


-- This layout should define current context
local sublayout = nil
if currentSublayout then
sublayout = currentSublayout
else
local context = reaper.GetCursorContext()
if context == 0 then
sublayout = "track"
elseif context == 1 then
sublayout = "item"
else
sublayout = "track"
end
end

-- This layout should have the self-providing service methods

local function getPresets()
-- This function returns the table with presets which positioning at the ipairs and with some methods to control the presets inside. Please call this methods via colon separator instead of dot
local presets = {
-- Updating presets from disk
update = function(self)
if #self > 0 then
for _, v in ipairs(self) do
v = nil
end
end
-- At first run the layout hasn't any selected preset, so we should to have this element
self[0] = {name="choose preset"}
local i = 1
while extstate["colcon_"..sublayout.."_preset"..i.."Value"] do
table.insert(self, {
name = extstate["colcon_"..sublayout.."_preset"..i.."Name"],
value = extstate["colcon_"..sublayout.."_preset"..i.."Value"]
})
i = i+1
end
end,
remove = function(self, index)
local i = 1
local removed = nil
while extstate["colcon_"..sublayout.."_preset"..i.."Value"] do
if i == index then
extstate._forever["colcon_"..sublayout.."_preset"..i.."Name"] = nil
extstate._forever["colcon_"..sublayout.."_preset"..i.."Value"] = nil
elseif i > index then
extstate._forever["colcon_"..sublayout.."_preset"..(i-1).."Name"] = self[i].name
extstate._forever["colcon_"..sublayout.."_preset"..i.."Name"] = nil
extstate._forever["colcon_"..sublayout.."_preset"..(i-1).."Value"] = self[i].value
extstate._forever["colcon_"..sublayout.."_preset"..i.."Value"] = nil
end
i = i+1
end
table.remove(self, index)
self:update()
return 1
end,
rename = function(self, index, str)
if self[index] then
self[index].name = str
extstate._forever["colcon_"..sublayout.."_preset"..index.."Name"] = str
return true
end
return false
end,
change = function(self, index, color)
if self[index] then
self[index].value = color
extstate._forever["colcon_"..sublayout.."_preset"..index.."Value"] = color
return true
end
return false
end,
create = function(self, str, color)
local i = #self+1
self[i] = {name=str, value=color}
extstate._forever["colcon_"..sublayout.."_preset"..i.."Name"] = str
extstate._forever["colcon_"..sublayout.."_preset"..i.."Value"] = color
return i
end
}
presets:update()
return presets
end

local function getColorIndex()
local colorIndex = extstate["colcom_"..sublayout.."_colorIndex"]
if colorIndex == nil then
colorIndex = 1
end
return colorIndex
end

local function getPresetIndex()
local presetIndex = extstate["colcom_"..sublayout.."_presetIndex"]
if presetIndex == nil then
presetIndex = 0
end
return presetIndex
end

local function setColorIndex(value)
extstate["colcom_"..sublayout.."_colorIndex"] = value
end

local function setPresetIndex(value)
extstate["colcom_"..sublayout.."_presetIndex"] = value
end

local function getFilter()
return extstate[("colcom_%s_colorFilter"):format(sublayout)]
end

local function getColor()
local color = extstate[("colcom_%s_curValue"):format(sublayout)]
if color == nil then
color = reaper.ColorToNative(0, 0, 0)
end
return color
end

local function setFilter(filter)
extstate[("colcom_%s_colorFilter"):format(sublayout)] = filter
end

local function setColor(color)
extstate[("colcom_%s_curValue"):format(sublayout)] = color
end




-- global pseudoclass initialization
local parentLayout = initLayout("Color composer")

-- the function which gives green light to call any method from this class
-- The color composer is available always, so we will just return true.
function parentLayout.canProvide()
return true
end


-- sublayouts
-- Track properties
parentLayout:registerSublayout("track", "Tracks")


-- Item properties
parentLayout:registerSublayout("item", " Items")

-- Take sublayout
parentLayout:registerSublayout("take", "Item takes")

-- Markers
parentLayout:registerSublayout("marker", "Markers and regions")

-- The creating new property macros
-- Here a special case, so we will not  use the native layout's methods as is
local function registerProperty(property)
for curClass, _ in pairs(parentLayout) do
if type(parentLayout[curClass]) == "table" then
parentLayout[curClass]:registerProperty(property)
end
end
end

-- presets methods
local presetsProperty = {}
registerProperty(presetsProperty)
presetsProperty.states = getPresets()

function presetsProperty.getValue()
return getPresetIndex()
end

function presetsProperty.setValue(value)
setPresetIndex(value)
end

function presetsProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to choose desired preset created at the past. Perform this property to manage a preset.", "Adjustable, performable")
if #self.states > 0 then
message(string.format("Color preset %s", self.states[self.getValue()].name))
else
message("Color preset empty")
end
return message
end

function presetsProperty:set(action)
local message = initOutputMessage()
local state = self.getValue()
if action == actions.set.increase then
if #self.states > 0 and (state+1) <= #self.states then
state = state+1
else
message("No more next property values. ")
end
elseif action == actions.set.decrease then
if #self.states > 0 and (state-1) > 0 then
state = state-1
else
message("No more previous property values. ")
end
elseif action == nil then
local maybeName = ""
if self.states[state] then
maybeName = self.states[state].name
end
local retval, answer = reaper.GetUserInputs("Preset management", 1, 'Type new preset name to create new preset.\nDo not clear current preset name to change the preset value to new.\nIf current color value will equal with preset value the preset will be renamed.\nType dslash symbol (/) to remove current preset.', maybeName)
if retval == true then
if #self.states > 0 then
if answer == "/" then
rpName = self.states[state].name
local result = self.states:remove(state)
if result then
message(string.format("Preset %s has been removed. ", rpName))
state = result
else
message(string.format("Unable to remove the preset %s. ", rpName))
end
elseif answer == self.states[state].name then
if self.states:change(state, getColor()) then
message(string.format("Preset %s has been updated. ", self.states[state].name))
else
message(string.format("Unable to update preset %s. ", self.states[state].name))
end
elseif answer ~= self.states[state].name and self.states[state].value == getColor() then
local oldName = self.states[state].name
if self.states:rename(state, answer) == true then
message(string.format("Preset %s has been renamed to %s. ", oldName, answer))
else
message(string.format("Unable to rename preset %s. ", self.states[state].name))
end
else
local result = self.states:create(answer, getColor())
if result then
message(string.format("Preset %s has been created.", self.states[result].name))
state = result
else
message("Unable to create new preset.")
end
end
else
local result = self.states:create(answer, getColor())
if result then
message(string.format("Preset %s has been created.", self.states[result].name))
state = result
else
message("Unable to create new preset.")
end
end
end
end
self.setValue(state)
state = self.getValue()
if #self.states > 0 then
setColor(self.states[state].value)
setColorIndex(colors:getColorID(reaper.ColorFromNative(getColor())))
message(string.format("Color preset %s", self.states[self.getValue()].name))
else
message("Color preset empty")
end
return message
end


-- Color shade methods
local shadeProperty = {}
registerProperty(shadeProperty)

function shadeProperty.getValue()
return getColorIndex()
end

function shadeProperty.setValue(value)
setColorIndex(value)
end


function shadeProperty:get()
local message = initOutputMessage()
message:initType(string.format("Adjust this property to choose desired color from list of %u values. Perform this property to set the filter for quick search needed color", #colors.colorList), "Adjustable, performable")
message(string.format("Color %s", colors.colorList[self.getValue()].name))
local filter = getFilter()
if filter then
message(string.format(", filter set to %s", filter))
end
return message
end

function shadeProperty:set(action)
local message = initOutputMessage()
local state = self.getValue()
local filter = getFilter()
if action == actions.set.increase then
if filter then
local somethingFound = false
for i = (state+1), #colors.colorList do
if string.find(colors.colorList[i].name:lower(), filter) then
state = i
somethingFound = true
break
end
end
if somethingFound == true then
message(("Forward by filter %s: "):format(filter))
else
message(string.format("No one color with something similar %s at next direction. ", filter))
end
else
if (state+1) <= #colors.colorList then
state = state+1
else
message("No more next property values. ")
end
end
elseif action == actions.set.decrease then
if filter then
local somethingFound = false
for i = (state-1), 1, -1 do
if string.find(colors.colorList[i].name:lower(), filter) then
state = i
somethingFound = true
break
end
end
if somethingFound == true then
message(("Backward by filter %s: "):format(filter))
else
message(string.format("No one color with something similar %s at previous direction.", filter))
end
else
if (state-1) > 0 then
state = state-1
else
message("No more previous property values. ")
end
end
elseif action == nil then
if filter == nil then filter = "" end
local retval, answer = reaper.GetUserInputs("Set filter", 1, 'Type a part of color name that Properties Ribbon should search.\nClear the edit field to clear the filter and explore all colors.', filter)
if retval == true then
setFilter(answer:lower())
local filter = getFilter()
if filter then
local somethingFound = false
for k, v in ipairs(colors.colorList) do
if string.find(v.name:lower(), filter) then
state = k
somethingFound = true
break
end
end
if somethingFound == false then
message(string.format("No one color with something similar %s. ", filter))
end
else
message("Filter cleared. ")
end
else
return "Canceled."
end
end
self.setValue(state)
setColor(reaper.ColorToNative(colors.colorList[state].r, colors.colorList[state].g, colors.colorList[state].b))
-- Here is old method because we do not want to report the filter superfluously
message(string.format("Color %s", colors.colorList[self.getValue()].name))
return message
end

-- The R value methods
local rgbRProperty = {}
registerProperty(rgbRProperty)

function rgbRProperty.getValue()
local r = reaper.ColorFromNative(getColor())
return r
end

function rgbRProperty.setValue(value)
local r, g, b = reaper.ColorFromNative(getColor())
r = value
setColor(reaper.ColorToNative(r, g, b))
end

function rgbRProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to find nearest  red shade intensity value which belongs to different color.", "Adjustable")
message(string.format("Color red intensity %u", self.getValue()))
return message
end


function rgbRProperty:set(action)
local message = initOutputMessage()
local state = self.getValue()
if action == actions.set.increase then
if state+1 <= 255 then
local oldName = colors:getName(reaper.ColorFromNative(getColor()))
for i = (state+1), 255 do
self.setValue(i)
local newName = colors:getName(reaper.ColorFromNative(getColor()))
if oldName ~= newName then
break
end
end
else
message("No more next property values. ")
end
elseif action == actions.set.decrease then
if state-1 >= 0 then
local oldName = colors:getName(reaper.ColorFromNative(getColor()))
for i = (state-1), 0, -1 do
if i >= 0 then
self.setValue(i)
local newName = colors:getName(reaper.ColorFromNative(getColor()))
if oldName ~= newName then
break
end
end
end
else
message("No more previous property values. ")
end
elseif action == nil then
local retval, answer = reaper.GetUserInputs("Red value input", 1, 'Type the red value intensity (0...255):', state)
if retval == true then
if tonumber(answer) then
self.setValue(tonumber(answer))
else
message("The provided red color value is not a number value. ")
end
end
end
setColorIndex(colors:getColorID(reaper.ColorFromNative(getColor())))
message(string.format("Color red intensity %u, closest color is %s", self.getValue(), colors:getName(reaper.ColorFromNative(getColor()))))
return message
end


-- The g methods
local rgbGProperty = {}
registerProperty(rgbGProperty)

function rgbGProperty.getValue()
local _, g = reaper.ColorFromNative(getColor())
return g
end

function rgbGProperty.setValue(value)
local r, g, b = reaper.ColorFromNative(getColor())
g = value
setColor(reaper.ColorToNative(r, g, b))
end

function rgbGProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to find nearest  blue shade intensity value which belongs to different color.", "Adjustable")
message(string.format("Color green intensity %u", self.getValue()))
return message
end


function rgbGProperty:set(action)
local message = initOutputMessage()
local state = self.getValue()
if action == actions.set.increase then
if state+1 <= 255 then
local oldName = colors:getName(reaper.ColorFromNative(getColor()))
for i = (state+1), 255 do
self.setValue(i)
local newName = colors:getName(reaper.ColorFromNative(getColor()))
if oldName ~= newName then
break
end
end
else
message("No more next property values. ")
end
elseif action == actions.set.decrease then
if state-1 >= 0 then
local oldName = colors:getName(reaper.ColorFromNative(getColor()))
for i = (state-1), 0, -1 do
if i >= 0 then
self.setValue(i)
local newName = colors:getName(reaper.ColorFromNative(getColor()))
if oldName ~= newName then
break
end
end
end
else
message("No more previous property values. ")
end
elseif action == nil then
local retval, answer = reaper.GetUserInputs("Green value input", 1, 'Type the green value intensity (0...255):', state)
if retval == true then
if tonumber(answer) then
self.setValue(tonumber(answer))
else
message("The provided green value is not a number value. ")
end
end
end
setColorIndex(colors:getColorID(reaper.ColorFromNative(getColor())))
message(string.format("Color green intensity %u, closest color is %s", self.getValue(), colors:getName(reaper.ColorFromNative(getColor()))))
return message
end


-- The B methods
local rgbBProperty = {}
registerProperty(rgbBProperty)

function rgbBProperty.getValue()
local _, _, b = reaper.ColorFromNative(getColor())
return b
end

function rgbBProperty.setValue(value)
local r, g, b = reaper.ColorFromNative(getColor())
b = value
setColor(reaper.ColorToNative(r, g, b))
end

function rgbBProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to find nearest  blue shade intensity value which belongs to different color.", "Adjustable")
message(string.format("Color blue intensity %u", self.getValue()))
return message
end


function rgbBProperty:set(action)
local message = initOutputMessage()
local state = self.getValue()
if action == actions.set.increase then
if state+1 <= 255 then
local oldName = colors:getName(reaper.ColorFromNative(getColor()))
for i = (state+1), 255 do
self.setValue(i)
local newName = colors:getName(reaper.ColorFromNative(getColor()))
if oldName ~= newName then
break
end
end
else
message("No more next property values. ")
end
elseif action == actions.set.decrease then
if state-1 >= 0 then
local oldName = colors:getName(reaper.ColorFromNative(getColor()))
for i = (state-1), 0, -1 do
if i >= 0 then
self.setValue(i)
local newName = colors:getName(reaper.ColorFromNative(getColor()))
if oldName ~= newName then
break
end
end
end
else
message("No more previous property values. ")
end
elseif action == nil then
local retval, answer = reaper.GetUserInputs("Blue value input", 1, 'Type the blue value intensity (0...255):', state)
if retval == true then
if tonumber(answer) then
self.setValue(tonumber(answer))
else
message("The provided blue value is not a number value. ")
end
end
end
setColorIndex(colors:getColorID(reaper.ColorFromNative(getColor())))
message(string.format("Color blue intensity %u, closest color is %s", self.getValue(), colors:getName(reaper.ColorFromNative(getColor()))))
return message
end

-- Grabbing a color from an elements methods
local grabColorProperty = {}
registerProperty(grabColorProperty)
grabColorProperty.states = {
["track"] = "last touched track",
["item"] = "first selected item",
["take"] = "active take of selected item",
["marker"] = "marker or region near cursor"
}

function grabColorProperty.getValue()
if sublayout == "track" then
if reaper.GetLastTouchedTrack() then
return reaper.GetMediaTrackInfo_Value(reaper.GetLastTouchedTrack(), "I_CUSTOMCOLOR")
end
return nil
elseif sublayout == "item" then
if reaper.GetSelectedMediaItem(0, 0) then
return reaper.GetMediaItemInfo_Value(reaper.GetSelectedMediaItem(0, 0), "I_CUSTOMCOLOR")
end
return nil
elseif sublayout == "take" then
if reaper.GetSelectedMediaItem(0, 0) then
return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, 0)), "I_CUSTOMCOLOR")
end
return nil
elseif sublayout == "marker" then
local markeridx, regionidx = reaper.GetLastMarkerAndCurRegion(0, reaper.GetCursorPosition())
if markeridx then
local _, _, _, _, _, _, color = reaper.EnumProjectMarkers3(0, markeridx)
return color
elseif regionidx then
local _, _, _, _, _, _, color = reaper.EnumProjectMarkers3(0, regionidx)
return color
elseif markeridx and regionidx then
if reaper.ShowMessageBox('This position contains both a marker and a region. Press \"Yes\" button to grab a color from current marker and \"No\" button for grab a color from region. ', "Make a choice", 4) == 6 then
local _, _, _, _, _, _, color = reaper.EnumProjectMarkers3(0, markeridx)
return color
else
local _, _, _, _, _, _, color = reaper.EnumProjectMarkers3(0, regionidx)
return color
end
end
return nil
end
end

function grabColorProperty.setValue(value)
setColor(value)
setColorIndex(colors:getColorID(reaper.ColorFromNative(getColor())))
end

function grabColorProperty:get()
local message = initOutputMessage()
message:initType(string.format("Perform this property to grab a color from %s. This color will be coppied to this category of color composition layout for following performances.", self.states[sublayout]), "Performable")
if not self.getValue() then
message:addType(" This property unavailable right now because no one element has been selected.", 1)
message:changeType("unavailable", 2)
end
message(string.format("Grab a color from %s", self.states[sublayout]))
return message
end

function grabColorProperty:set(action)
local message = initOutputMessage()
if action == nil then
local state = self.getValue()
if not state then
return "This property is unavailable right now because no one element of this category has been neither touched nor selected."
end
self.setValue(state)
message(string.format("The %s color has been grabbed from %s.", colors:getName(reaper.ColorFromNative(getColor())), self.states[sublayout]))
return message
else
return "This property is performable only."
end
end

parentLayout.defaultSublayout = sublayout

return parentLayout