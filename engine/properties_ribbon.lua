--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020 outsidepro-arts
License: MIT License
]]--

package.path = ({reaper.get_action_context()})[2]:match('^.+[\\//]') ..'engine\\'.. "?.lua"

-- Include the configuration provider
require "config_provider"
config.section = "Properties_Ribbon_script"

-- include the functions for converting the specified Reaper values and artisanal functions which either not apsent in the LUA or which work non correctly.
require "specfuncs"

-- Including the byte words module
require "bytewords"
-- These modules usualy uses in properties code

-- Custom message metamethod
function initOutputMessage()
local mt = setmetatable({
initType = function(self, level, ...)
local args = {...}
self.tl = level
self.tLevels = {}
for i = 1, #args do
self.tLevels[i] = args[i]
end
end,
-- Change the type message
changeType = function(self, str, level)
if level == nil then
self.tLevels[self.tl] = str
else
self.tLevels[level] = str
end
end,
-- Add the next part to type message
addType = function(self, str, level)
if level == nil then
if self.tLevels[self.tl] ~= nil then
self.tLevels[self.tl] = self.tLevels[self.tl]..str
else
self.tLevels[self.tl] = str
end
else
if self.tLevels[level] ~= nil then
self.tLevels[level] = self.tLevels[level]..str
else
self.tLevels[level] = str
end
end
end,

-- Clearing the local message
clearMessage = function(self)
if self.msg then
self.msg = nil
end
end,
-- Clearing the type levels
clearType = function()
if self.tLevels then
self.tLevels, self.tl = nil
end
end
}, {
-- Make the metamethod more flexible: if it has been called as function, it must be create or concatenate the private field msg
__call = function(self, str)
if self.msg then
self.msg = self.msg..str
else
self.msg = str
end
end,
-- for get full string after concatenating the message, please forcedly convert the metamethod to string
__tostring = function(self)
local message = ""
if self.msg then
message = self.msg
else
return ""
end
if self.tLevels and self.tl > 0 then
message = message..". "..self.tLevels[self.tl]
end
return message
end,
-- Concatenating with metatable still doesn't works... Crap!
__concat = function(str, self)
if self.msg then
return str..self.msg
else
return str
end
end,
})
return mt
end

-- }


function composeSubLayout()
local message = initOutputMessage()
message(string.format("%s, ", (layout.name):format(layout.subname)))
if config.getboolean("reportPos", true) == true and (layout.nextSubLayout or layout.previousSubLayout) then
message(string.format("%u of %u, ", layout.slIndex, layout.ofCount))
end
return tostring(message)
end

-- Making the get and set internal ExtState more easier

extstate = {}

function extstate.get(key)
return reaper.GetExtState("Properties_Ribbon_script", key)
end

function extstate.set(key, value)
reaper.SetExtState("Properties_Ribbon_script", key, value, false)
end

layout, currentLayout, SpeakLayout, g_undoState = {}, nil, false, "Unknown Change via Properties Ribbon script"

function script_init()
currentLayout = extstate.get("currentLayout")
speakLayout = toboolean(extstate.get("speakLayout"))
if currentLayout == nil or currentLayout == "" then
reaper.osara_outputMessage("Switch one action group first.")
return nil
end
layout = dofile (({reaper.get_action_context()})[2]:match('^.+[\\//]') .. 'engine\\properties\\' .. currentLayout..".lua")
if layout == nil then
reaper.ShowMessageBox(string.format("The properties layout %s couldn't be loaded.", currentLayout), "Properties ribbon error", 0)
return nil
end
g_undoState = ("Switch properties layout to %s in Properties Ribbon script"):format((layout.name):format(""))
layout.pIndex = tonumber(extstate.get(layout.section)) or 1
return layout
end

function script_switchSublayout(action)
if layout.canProvide() ~= true then
return string.format("There are no elements %s be provided for.", layout.name:format(""))
end
if layout.nextSubLayout or layout.previousSubLayout then
if (action == true or action == nil) then
if layout.nextSubLayout then
extstate.set(currentLayout.."_sublayout", layout.nextSubLayout)
else
return "No next category. "
end
elseif action == false then
if layout.previousSubLayout then
extstate.set(currentLayout.."_sublayout", layout.previousSubLayout)
else
return "No previous category. "
end
end
layout = dofile (({reaper.get_action_context()})[2]:match('^.+[\\//]') .. 'engine\\properties\\' .. currentLayout..".lua")
if layout == nil then
reaper.ShowMessageBox(string.format("The properties layout %s couldn't be loaded.", currentLayout), "Properties ribbon error", 0)
return
end
g_undoState = ("Switch category to %s in Properties Ribbon script"):format((layout.name):format(layout.subname))
speakLayout = false
layout.pIndex = tonumber(extstate.get(layout.section)) or 1
local message = initOutputMessage()
message(composeSubLayout())
message(script_reportOrGotoProperty())
return tostring(message)
else
return ("The %s layout has no category. "):format(layout.name:format(""))
end
end

function script_nextProperty()
local message = initOutputMessage()
if speakLayout == true then
message(composeSubLayout())
speakLayout = false
end
if layout.canProvide() == true then
if #layout.properties < 1 then
return string.format("The ribbon of %s is empty.", layout.name:format(layout.subname))
end
if layout.pIndex+1 <= #layout.properties then
layout.pIndex = layout.pIndex+1
else
message("last property. ")
end
else
return string.format("There are no elements %s be provided for.", layout.name:format(""))
end
local result = layout.properties[layout.pIndex]:get()
if config.getboolean("reportPos", true) == true then
result((", %u of %u"):format(layout.pIndex, #layout.properties))
end
message(tostring(result))
g_undoState = "Properties Ribbon: "..tostring(message)
return tostring(message)
end

function script_previousProperty()
local message = initOutputMessage()
if speakLayout == true then
message(composeSubLayout())
speakLayout = false
end
if layout.canProvide() == true then
if #layout.properties < 1 then
return string.format("The ribbon of %s is empty.", layout.name:format(layout.subname))
end
if layout.pIndex-1 > 0 then
layout.pIndex = layout.pIndex-1
else
message("first property. ")
end
else
return string.format("There are no elements %s be provided for.", layout.name:format(""))
end
local result = layout.properties[layout.pIndex]:get()
if config.getboolean("reportPos", true) == true then
result((", %u of %u"):format(layout.pIndex, #layout.properties))
end
message(tostring(result))
g_undoState = "Properties Ribbon: "..tostring(message)
return tostring(message)
end

function script_reportOrGotoProperty(propertyNum)
local message = initOutputMessage()
if speakLayout == true then
message(composeSubLayout())
speakLayout = false
end
if layout.canProvide() == true then
if #layout.properties < 1 then
return string.format("The ribbon of %s is empty.", layout.name:format(layout.subname))
end
if propertyNum then
if propertyNum <= #layout.properties then
layout.pIndex = propertyNum
else
return string.format("No property with number %s in %s layout.", propertyNum, layout.name:format(layout.subname))
end
end
else
return string.format("There are no elements %s be provided for.", layout.name:format(""))
end
local result = layout.properties[layout.pIndex]:get()
if config.getboolean("reportPos", true) == true then
result((", %u of %u"):format(layout.pIndex, #layout.properties))
end
message(tostring(result))
return tostring(message)
end

function script_ajustProperty(value)
if layout.canProvide() == true then
local msg = tostring(layout.properties[layout.pIndex]:set(value))
g_undoState = "Properties Ribbon: "..msg
return msg
else
return string.format("There are no element to ajust or perform any action for %s.", layout.name)
end
end

function script_finish()
if layout then
extstate.set(layout.section, layout.pIndex)
extstate.set("currentLayout", currentLayout)
extstate.set("speakLayout", tostring(speakLayout))
end
end
