--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts
License: MIT License
]]--

-- Include the configuration provider
config = require "config_provider"
config.section = "Properties_Ribbon_script"

-- include the functions for converting the specified Reaper values and artisanal functions which either not apsent in the LUA or which work non correctly.
utils = require "utils"

-- Including the byte words module
-- SWS has own byte operations, but what if has an user not SWS installed?
bytewords = require "bytewords"

-- including the colors module
colors = require "colors_provider"
-- Making the get and set internal ExtState more easier
extstate = require "reaper_extstate"
extstate._section = config.section

-- Including the humanbeing representations metamethods
representation = require "representations"


-- Little injections
-- Make string type as outputable to OSARA directly
function string:output()
reaper.osara_outputMessage(self)
end

-- Ad the trap method to the string type to avoid superfluous check writing when we are working with outputMessage metamethod
function string:extract()
return self
end


-- own metamethods

-- Custom message metamethod
function initOutputMessage()
local mt = setmetatable({
-- type prompts initialization method
-- The type prompts adds the string message set by default to the end of value message.
-- Parameters:
-- infinite parameters (string): the prompts messages in supported order.
-- returns none.
initType = function(self, ...)
local args = {...}
self.tl = config.getinteger("typeLevel", 1)
self.tLevels = {}
for i = 1, #args do
self.tLevels[i] = args[i]
end
end,
-- Change the type prompts message
-- Parameters:
-- str (string): new message.
-- level (number): the type level which needs to be changed.
-- returns none.
changeType = function(self, str, level)
if level == nil then
self.tLevels[self.tl] = str
else
self.tLevels[level] = str
end
end,
-- Add the next part to type prompts message. The message adds to the end of existing message.
-- For change the message fuly, use the changeType method.
-- Parameters:
-- str (string): the string message which needs to be added.
-- level (number): the type level which the passed message needs to be added to.
-- Returns none.
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
-- No parameters. Returns none.
clearMessage = function(self)
if self.msg then
self.msg = nil
end
end,
-- Clearing the type levels
-- No parameters. Returns none.
clearType = function(self)
if self.tLevels then
self.tLevels, self.tl = nil
end
end,
-- Output  composed message to OSARA by itself
-- No parameters takes. Returns no parameters.
output = function(self)
local message = ""
if self.msg then
message = self.msg
else
return
end
if self.tLevels and self.tl > 0 then
message = message..". "..self.tLevels[self.tl]
end
reaper.osara_outputMessage(message)
end,
-- Extract the message composed string
-- Parameters:
-- shouldExtractType (boolean, optional):  Should the type prommpt be extracted with composed message. By default is true
-- Returns composed string without type prompt. If there are no string, returns nil.
extract = function(self, shouldExtractType)
if shouldExtractType== nil then
shouldExtractType = true
end
if shouldExtractType == true then
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
else
return self.msg or nil
end
end
}, {
-- Redefine the metamethod type
__type = "output_message",
-- Make the metamethod more flexible: if it has been called as function, it must be create or concatenate the private field msg
__call = function(self, str, shouldCopyTypeLevel)
shouldCopyTypeLevel = shouldCopyTypeLevel or false
if type(str) == "table" and str.msg then
if str.msg then
if self.msg then
self.msg = self.msg.." "..str.msg
else
self.msg = str.msg
end
end
if str.tLevels then
if self.tLevels or shouldCopyTypeLevel then
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
section = string.format(utils.removeSpaces(str), ""),
ofCount = 0,

-- slID (string) - the ID of sublayout in parent layout
-- slName (string) - The sub-name of the sublayout which will be reported in main class format name
registerSublayout = function(self, slID, slName)
self[slID] = setmetatable({
subname = slName,
section = utils.removeSpaces(string.format(self.name, slName)),
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
local cfg = config.getinteger("reportPos", 3)
if (cfg == 1 or cfg == 3) and (layout.nextSubLayout or layout.previousSubLayout) then
message(string.format("%u of %u, ", layout.slIndex, layout.ofCount))
end
return message:extract()
end

-- Propose an existing Properties Ribbon layout by current REAPER build-in context
-- parameters:
-- optional forced (boolean): should the function return the contextual layout forcedly even if one of context has been set earlier. False or nil: only if one of contextual layouts is set, true - immediately.
function proposeLayout(forced)
forced = forced or false
local context, contextLayout, curLayout = reaper.GetCursorContext(), nil, extstate.currentLayout
-- Sometimes REAPER returns bizarre contexts...
if context == -1 then
context = extstate.lastKnownContext or context
end
if context == 0 then
if reaper.IsTrackSelected(reaper.GetMasterTrack()) then
contextLayout = "properties//mastertrack_properties"
else
if reaper.CountTracks(0) > 0 then
contextLayout = "properties//track_properties"
else
if (reaper.GetMasterTrackVisibility()&1) == 1 then
contextLayout = "properties//mastertrack_properties"
else
contextLayout = "properties//track_properties"
end
end
end
elseif context == 1 then
contextLayout = "properties//item_properties"
elseif context == 2 then
contextLayout = "properties//envelope_properties"
end
if forced == true or curLayout == "properties//mastertrack_properties" or curLayout == "properties//track_properties" or curLayout == "properties//item_properties" or curLayout == "properties//envelope_properties" then
return contextLayout
end
return nil
end

function setUndoLabel(label)
if not label then
g_undoState = ""
elseif label == "" then
-- do nothing
else
g_undoState = string.format("Properties Ribbon: %s", label:extract(false))
end
end

function restorePreviousLayout()
if config.getboolean("allowLayoutsrestorePrev", true) == true then
if config.getboolean("automaticLayoutLoading", false) == true then
currentLayout = proposeLayout(true)
speakLayout = true
else
if extstate.previousLayout then
currentLayout = extstate.previousLayout
speakLayout = true
end
end
end
end

function isHasSublayouts(lt)
if not lt.properties then
for _, field in pairs(lt) do
if type(field) == "table" then
if (field.nextSubLayout or field.previousSubLayout) and field.properties then
return true
end
end
end
end
return false
end



function findDefaultSublayout(lt)
for fieldName, field in pairs(lt) do
if type(field) == "table" then
if field.properties then
if not field.previousSubLayout and field.nextSubLayout then
return fieldName
end
end
end
end
end




-- Main body

layout, currentLayout, currentSublayout, SpeakLayout, g_undoState = {}, nil, nil, false, "Unknown Change via Properties Ribbon script"

-- The main initialization function
-- newLayout (string, optional): new layout name which Properties Ribbon should switch to. If it is omited, the last layout will be loaded.
-- shouldSpeakLayout (boolean, optional): option which defines should Properties ribbon say new layout. If it is omited, scripts will decides should report it by itself basing on the previous layout.
function script_init(newLayout, shouldSpeakLayout)
-- Checking the speech output method existing
if not reaper.APIExists("osara_outputMessage") then
reaper.ShowMessageBox("Seems you haven't OSARA installed on this REAPER copy. Please install the OSARA extension which have full accessibility functions and provides the speech output method which Properties Ribbon scripts complex uses for its working.", "Properties Ribbon error", 0)
return nil
end
if newLayout then
if type(newLayout) == "table" then
newLayout = newLayout.section.."//"..newLayout.layout or nil
end
end
if newLayout ~= nil then
currentLayout = newLayout
if config.getboolean("allowLayoutsrestorePrev", true) == true and newLayout ~= extstate.currentLayout then
extstate.previousLayout = extstate.currentLayout
end
if shouldSpeakLayout == nil then
if extstate.currentLayout ~= newLayout then
speakLayout = true
else
speakLayout = extstate.speakLayout
end
else
speakLayout = shouldSpeakLayout
end
if config.getboolean("rememberSublayout", true) == false and extstate.currentLayout ~= currentLayout then
-- Let REAPER do not request the extstate superfluously
if  extstate[newLayout.."_sublayout"] ~= "" then
extstate[newLayout.."_sublayout"] = nil
end
end
else
currentLayout = extstate.currentLayout
if shouldSpeakLayout ~= nil then
speakLayout = shouldSpeakLayout
else
speakLayout = extstate.speakLayout
end
end
if currentLayout == nil or currentLayout == "" then
("Switch one action group first."):output()
return nil
end
-- Some layouts has executes the linear code... Woops...
currentSublayout = extstate[currentLayout.."_sublayout"]
local mcr = io.open(package.path:gsub("?", currentLayout:match('^(.+)//').."//macros"), "r")
if mcr then
dofile(package.path:gsub("?", currentLayout:match('^(.+)//').."//macros"))
mcr:close()
end
layout = dofile(package.path:gsub("?", currentLayout))
if layout == nil then
reaper.ShowMessageBox(string.format("The properties layout %s couldn't be loaded.", currentLayout), "Properties ribbon error", 0)
return nil
end
if isHasSublayouts(layout) then
local sublayout = currentSublayout or layout.defaultSublayout or findDefaultSublayout(layout)
layout = layout[sublayout]
currentSublayout = sublayout
end
setUndoLabel(("Switch properties layout to %s"):format((layout.name):format("")))
layout.pIndex = extstate[layout.section] or 1
return layout
end

function script_switchSublayout(action)
if layout.canProvide() ~= true then
(string.format("There are no elements %s be provided for.", layout.name:format(""))):output()
restorePreviousLayout()
script_finish()
return
end
if layout.nextSubLayout or layout.previousSubLayout then
if (action == true or action == nil) then
if layout.nextSubLayout then
extstate[currentLayout.."_sublayout"] = layout.nextSubLayout
else
("No next category."):output()
script_finish()
return
end
elseif action == false then
if layout.previousSubLayout then
extstate[currentLayout.."_sublayout"] = layout.previousSubLayout
else
("No previous category."):output()
script_finish()
return
end
end
if not script_init(nil, true) then
restorePreviousLayout()
script_finish()
return
end
script_reportOrGotoProperty()
else
(("The %s layout has no category. "):format(layout.name:format(""))):output()
end
script_finish()
end

function script_nextProperty()
local message = initOutputMessage()
if speakLayout == true then
message(composeSubLayout())
speakLayout = false
end
if layout.canProvide() == true then
if #layout.properties < 1 then
(string.format("The ribbon of %s is empty.", layout.name:format(layout.subname))):output()
restorePreviousLayout()
script_finish()
return
end
if layout.pIndex+1 <= #layout.properties then
layout.pIndex = layout.pIndex+1
else
message("last property. ")
end
else
(string.format("There are no elements %s be provided for.", layout.name:format(""))):output()
restorePreviousLayout()
script_finish()
return
end
local result = layout.properties[layout.pIndex]:get()
local cfg = config.getinteger("reportPos", 4)
if cfg == 2 or cfg == 3 then
result((", %u of %u"):format(layout.pIndex, #layout.properties))
end
message(result, true)
setUndoLabel(message:extract(false))
message:output()
script_finish()
end

function script_previousProperty()
local message = initOutputMessage()
if speakLayout == true then
message(composeSubLayout())
speakLayout = false
end
if layout.canProvide() == true then
if #layout.properties < 1 then
(string.format("The ribbon of %s is empty.", layout.name:format(layout.subname))):output()
restorePreviousLayout()
script_finish()
return
end
if layout.pIndex-1 > 0 then
layout.pIndex = layout.pIndex-1
else
message("first property. ")
end
else
(string.format("There are no elements %s be provided for.", layout.name:format(""))):output()
restorePreviousLayout()
script_finish()
return
end
local result = layout.properties[layout.pIndex]:get()
local cfg = config.getinteger("reportPos", 4)
if cfg == 2 or cfg == 3 then
result((", %u of %u"):format(layout.pIndex, #layout.properties))
end
message(result, true)
setUndoLabel(message:extract(false))
message:output()
script_finish()
end

function script_reportOrGotoProperty(propertyNum)
local message = initOutputMessage()
if speakLayout == true then
message(composeSubLayout())
speakLayout = false
end
if layout.canProvide() == true then
if #layout.properties < 1 then
(string.format("The ribbon of %s is empty.", layout.name:format(layout.subname))):output()
restorePreviousLayout()
script_finish()
return
end
if propertyNum then
if propertyNum <= #layout.properties then
layout.pIndex = propertyNum
else
(string.format("No property with number %s in %s layout.", propertyNum, layout.name:format(layout.subname))):output()
script_finish()
return
end
end
else
(string.format("There are no elements %s be provided for.", layout.name:format(""))):output()
restorePreviousLayout()
script_finish()
return
end
local result = layout.properties[layout.pIndex]:get()
local cfg = config.getinteger("reportPos", 4)
if cfg == 2 or cfg == 3 then
result((", %u of %u"):format(layout.pIndex, #layout.properties))
end
message(result, true)
message:output()
script_finish()
end

function script_ajustProperty(value)
if layout.canProvide() == true then
local msg = layout.properties[layout.pIndex]:set(value)
setUndoLabel(msg:extract(false))
msg:output()
else
(string.format("There are no element to ajust or perform any action for %s.", layout.name:format(""))):output()
end
script_finish()
end

function script_reportLayout()
(composeSubLayout()):output()
end

function script_finish()
if layout then
extstate[layout.section] = layout.pIndex
extstate.currentLayout = currentLayout
extstate.speakLayout = speakLayout
if reaper.GetCursorContext() ~= -1 then 
extstate.lastKnownContext = reaper.GetCursorContext()
end
end
end
