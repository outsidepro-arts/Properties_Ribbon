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


-- Reading the sublayout
sublayout = extstate.get(currentLayout.."_sublayout")
if sublayout == "" or sublayout == nil then
-- This layout should define current context
context = reaper.GetCursorContext()
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
while extstate.get("colcon_"..sublayout.."_preset"..i.."Value") ~= "" do
table.insert(self, {
name = extstate.get("colcon_"..sublayout.."_preset"..i.."Name"),
value = extstate.get("colcon_"..sublayout.."_preset"..i.."Value")
})
i = i+1
end
end,
remove = function(self, index)
local i = 1
local removed = nil
while extstate.get("colcon_"..sublayout.."_preset"..i.."Value") ~= "" do
if i == index then
extstate.remove("colcon_"..sublayout.."_preset"..i.."Name", true)
extstate.remove("colcon_"..sublayout.."_preset"..i.."Value", true)
elseif i > index then
extstate.set("colcon_"..sublayout.."_preset"..(i-1).."Name", self[i].name, true)
extstate.remove("colcon_"..sublayout.."_preset"..i.."Name", true)
extstate.set("colcon_"..sublayout.."_preset"..(i-1).."Value", self[i].value, true)
extstate.remove("colcon_"..sublayout.."_preset"..i.."Value", true)
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
extstate.set("colcon_"..sublayout.."_preset"..index.."Name", str, true)
return true
end
return false
end,
change = function(self, index, color)
if self[index] then
self[index].value = color
extstate.set("colcon_"..sublayout.."_preset"..index.."Value", color, true)
return true
end
return false
end,
create = function(self, str, color)
local i = #self+1
self[i] = {name=str, value=color}
extstate.set("colcon_"..sublayout.."_preset"..i.."Name", str, true)
extstate.set("colcon_"..sublayout.."_preset"..i.."Value", color, true) 
return i
end
}
presets:update()
return presets
end

local function getColorIndex()
local colorIndex = extstate.get("colcom_"..sublayout.."_colorIndex")
if colorIndex == "" or colorIndex == nil then
colorIndex = 1
else
colorIndex = tonumber(colorIndex)
end
return colorIndex
end

local function getPresetIndex()
local presetIndex = extstate.get("colcom_"..sublayout.."_presetIndex")
if presetIndex == "" or presetIndex == nil then
presetIndex = 0
else
presetIndex = tonumber(presetIndex)
end
return presetIndex
end

local function setColorIndex(value)
extstate.set("colcom_"..sublayout.."_colorIndex", tostring(value), false)
end

local function setPresetIndex(value)
extstate.set("colcom_"..sublayout.."_presetIndex", tostring(value), false)
end

local function getFilter()
local filter = extstate.get(("colcom_%s_colorFilter"):format(sublayout))
if filter ~= "" then
return filter
end
return nil
end

local function getColor()
local color = extstate.get(("colcom_%s_curValue"):format(sublayout))
if color == "" or color == nil then
color = reaper.ColorToNative(0, 0, 0)
end
return tonumber(color)
end

local function setFilter(filter)
extstate.set(("colcom_%s_colorFilter"):format(sublayout), filter)
end

local function setColor(color)
extstate.set(("colcom_%s_curValue"):format(sublayout), tostring(color))
end

-- global pseudoclass initialization
parentLayout = setmetatable({
name = "Color composer%s", -- The main class name which will be formatted by subclass name
ofCount = 0 -- The full categories count
}, {
-- When new field has been added we just take over the ofCount adding
__newindex = function(self, key, value)
rawset(self, key, value)
if key ~= "canProvide" then
self.ofCount = self.ofCount+1
end
end
})

-- the function which gives green light to call any method from this class
-- The color composer is available always, so we will just return true.
function parentLayout.canProvide()
return true
end


-- sublayouts
-- Track properties
parentLayout.track = setmetatable({
section = "trackPropertiesComposer",
subname = " for tracks",
slIndex = 1, 
nextSubLayout = "item",
properties = {}
}, {__index = parentLayout}
)


-- Item properties
parentLayout.item = setmetatable({
section = "itemColorComposer",
subname = " for items",
slIndex = 2, 
previousSubLayout = "track",
nextSubLayout = "take",
properties = {}
}, {__index = parentLayout}
)

-- Take sublayout
parentLayout.take = setmetatable({
section = "takePropertiesComposer",
subname = " for item takes",
slIndex = 3, 
previousSubLayout = "item",
properties = {}
}, {__index = parentLayout}
)


-- The creating new property macros
local function registerProperty(property)
for curClass, _ in pairs(parentLayout) do
if type(parentLayout[curClass]) == "table" then
table.insert(parentLayout[curClass].properties, property)
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
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose desired preset created at the past. Perform this property to manage a preset.", "Adjustable, performable")
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
if action == true then
if #self.states > 0 and (state+1) <= #self.states then
state = state+1
else
message("No more next property values. ")
end
elseif action == false then
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
elseif self.states[state].value == getColor() then
local oldName = self.states[state].name
if self.states:rename(state, answer) == true then
Message(string.format("Preset %s has been renamed to %s. ", oldName, answer))
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
message:initType(config.getinteger("typeLevel", 1), string.format("Adjust this property to choose desired color from list of %u values. Perform this property to set the filter for quick search needed color", #colors.colorList), "Adjustable, performable")
message(string.format("Color %s", colors.colorList[self.getValue()].name))
return message
end

function shadeProperty:set(action)
local message = initOutputMessage()
local state = self.getValue()
local filter = getFilter()
if action == true then
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
elseif action == false then
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
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to find nearest  red shade intensity value which belongs to different color.", "Adjustable")
message(string.format("Color red intensity %u", self.getValue()))
return message
end


function rgbRProperty:set(action)
local message = initOutputMessage()
local state = self.getValue()
if action == true then
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
elseif action == false then
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
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to find nearest  blue shade intensity value which belongs to different color.", "Adjustable")
message(string.format("Color green intensity %u", self.getValue()))
return message
end


function rgbGProperty:set(action)
local message = initOutputMessage()
local state = self.getValue()
if action == true then
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
elseif action == false then
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
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to find nearest  blue shade intensity value which belongs to different color.", "Adjustable")
message(string.format("Color blue intensity %u", self.getValue()))
return message
end


function rgbBProperty:set(action)
local message = initOutputMessage()
local state = self.getValue()
if action == true then
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
elseif action == false then
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

return parentLayout[sublayout]