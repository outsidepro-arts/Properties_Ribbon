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


local parentLayout = initLayout("%seditor selection")

function parentLayout.canProvide()
-- Just check one of items has been selected
return (reaper.GetSelectedMediaItem(0, 0) ~= nil)
end

parentLayout:registerSublayout("embededLayout", "Build-in ")
parentLayout:registerSublayout("externalLayout", "External ")

local midiEditor = {}
parentLayout.embededLayout:registerProperty(midiEditor)

function midiEditor:get()
local message = initOutputMessage()
message:initType("Perform this property to open the embeded REAPER MIDI-editor.", "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
message("Open in built-in MIDI editor (set default behavior in preferences)")
return message
end

function midiEditor:set(action)
if action == nil then
reaper.Main_OnCommand(40153, 1)
restorePreviousLayout()
setUndoLabel(self:get())
return ""
else
return "This property is performable only."
end
end

local copiesInPrimaryEditor = {}
parentLayout.externalLayout:registerProperty(copiesInPrimaryEditor)

function copiesInPrimaryEditor:get()
local message = initOutputMessage()
message:initType("Perform this property to open copies of selected items to primary editor set in REAPER preferences.", "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
message("Open item copies in primary external editor")
return message
end

function copiesInPrimaryEditor:set(action)
if action == nil then
reaper.Main_OnCommand(40132, 1)
restorePreviousLayout()
return "Opened."
else
return "This property is performable only."
end
end

local itemInPrimaryEditor = {}
parentLayout.externalLayout:registerProperty(itemInPrimaryEditor)

function itemInPrimaryEditor:get()
local message = initOutputMessage()
message:initType("Perform this property to open selected items in primary editor set in REAPER preferences.", "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
message("Open items in primary external editor")
return message
end

function itemInPrimaryEditor:set(action)
if action == nil then
reaper.Main_OnCommand(40109, 1)
restorePreviousLayout()
return "Opened."
else
return "This property is performable only."
end
end


local copiesInSecondaryEditor = {}
parentLayout.externalLayout:registerProperty(copiesInSecondaryEditor)

function copiesInSecondaryEditor:get()
local message = initOutputMessage()
message:initType("Perform this property to open selected items copies to secondary external editor set in REAPER preferences.", "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
message("Open item copies in secondary external editor")
return message
end

function copiesInSecondaryEditor:set(action)
if action == nil then
reaper.Main_OnCommand(40203, 1)
restorePreviousLayout()
return "Opened."
else
return "This property is performable only."
end
end

local itemInSecondaryEditor = {}
parentLayout.externalLayout:registerProperty(itemInSecondaryEditor)

function itemInSecondaryEditor:get()
local message = initOutputMessage()
message:initType("Perform this property to open selected items in secondary external editor set in REAPER preferences.", "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
message("Open items in secondary external editor")
return message
end

function itemInSecondaryEditor:set(action)
if action == nil then
reaper.Main_OnCommand(40202, 1)
restorePreviousLayout()
return "Opened."
else
return "This property is performable only."
end
end


return parentLayout