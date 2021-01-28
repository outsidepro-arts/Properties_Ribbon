--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts
License: MIT License
]]--

-- Include the configuration provider
require "config_provider"
config.section = "Properties_Ribbon_script"

-- include the functions for converting the specified Reaper values and artisanal functions which either not apsent in the LUA or which work non correctly.
require "specfuncs"

-- Including the byte words module
-- SWS has own byte operations, but what if has an user not SWS installed?
require "bytewords"

-- including the colors module
require "colors_provider"
-- These modules usualy uses in properties code


-- own metamethods

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
-- Redefine the metamethod type
__type = "output_message",
-- Make the metamethod more flexible: if it has been called as function, it must be create or concatenate the private field msg
__call = function(self, str)
if type(str) == "table" and str.msg then
if str.msg then
if self.msg then
self.msg = self.msg.." "..str.msg
else
self.msg = str.msg
end
end
if str.tLevels then
if self.tLevels then
self.tLevels = str.tLevels
self.tl = str.tl
end
end
else
if self.msg then
self.msg = self.msg..str
else
self.msg = str
end
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

-- The layout initialization
-- The input parameter "str" waits the new class message
function initLayout(str)
local t = {
name = str,
section = string.format(removeSpaces(str), ""),
ofCount = 0,

-- slID (string) - the ID of sublayout in parent layout
-- slName (string) - The sub-name of the sublayout which will be reported in main class format name
registerSublayout = function(self, slID, slName)
self[slID] = setmetatable({
subname = slName,
section = removeSpaces(string.format(self.name, slName)),
properties = {}
}, {
__index = self})
self.ofCount = self.ofCount+1
self[slID].slIndex = self.ofCount
for slsn, sls in pairs(self) do
if type(sls) == "table" then
if sls.slIndex == self.ofCount-1 then
sls.nextSubLayout = slID
self[slID].previousSubLayout = slsn
end
end
end
self[slID].registerProperty = self.registerProperty
-- If a category has been created, the parent registration methods should be unavailable.
if self.properties then self.properties = nil end
end,
properties = {},
registerProperty = function(self, property)
 return table.insert(self.properties, property)
end
}
return t
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

function extstate.set(key, value, forever)
forever = forever or false
reaper.SetExtState("Properties_Ribbon_script", key, value, forever)
end

function extstate.remove(key, forever)
forever = forever or false
reaper.DeleteExtState("Properties_Ribbon_script", key, forever)
end

-- Main body

layout, currentLayout, SpeakLayout, g_undoState = {}, nil, false, "Unknown Change via Properties Ribbon script"

-- The main initialization function
-- newLayout (string, optional): new layout name which Properties Ribbon should switch to. If it is omited, the last layout will be loaded.
-- shouldSpeakLayout (boolean, optional): option which defines should Properties ribbon say new layout. If it is omited, the value will be true by default. Note  that this option will be taken only if  newLayout will be passed.
function script_init(newLayout, shouldSpeakLayout)
-- Checking the speech output method existing
if not reaper.APIExists("osara_outputMessage") then
reaper.ShowMessageBox("Seems you haven't OSARA installed on this REAPER copy. Please install the OSARA extension which have full accessibility functions and provides the speech output method which Properties Ribbon scripts complex uses for its working.", "Properties Ribbon error", 0)
return nil
end
if newLayout ~= nil then
currentLayout = newLayout
speakLayout = shouldSpeakLayout or true
if config.getboolean("rememberSublayout", true) == false then
-- Let REAPER do not request the extstate superfluously
if  extstate.get(newLayout.."_sublayout") ~= "" then
extstate.remove(newLayout.."_sublayout")
end
end
else
currentLayout = extstate.get("currentLayout")
speakLayout = toboolean(extstate.get("speakLayout"))
end
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
return string.format("There are no element to ajust or perform any action for %s.", layout.name:format(""))
end
end

function script_finish()
if layout then
extstate.set(layout.section, layout.pIndex)
extstate.set("currentLayout", currentLayout)
extstate.set("speakLayout", tostring(speakLayout))
end
end
