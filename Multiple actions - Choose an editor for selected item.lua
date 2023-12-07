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

package.path = select(2, reaper.get_action_context()):match('^.+[\\//]') .. "?//init.lua"

require "properties_ribbon"

useMacros("actions")

local parentLayout = initLayout("Editor selection")
parentLayout.undoContext = undo.contexts.items

function parentLayout.canProvide()
-- Just check one of items has been selected
return (reaper.GetSelectedMediaItem(0, 0) ~= nil)
end

parentLayout:registerSublayout("embededLayout", "Build-in")
parentLayout:registerSublayout("externalLayout", "External")

parentLayout.embededLayout:registerProperty(composeExtendedProperty(
40153,
nil,
{"Perform this property to open the embedded REAPER MIDI-editor.", "Performable"}
))

parentLayout.externalLayout:registerProperty(composeExtendedProperty(
40132,
nil,
{"Perform this property to open copies of selected items to primary editor set in REAPER preferences.", "Performable"}
))

parentLayout.externalLayout:registerProperty(composeExtendedProperty(
40109,
nil,
{"Perform this property to open selected items in primary editor set in REAPER preferences.", "Performable"}
))

parentLayout.externalLayout:registerProperty(composeExtendedProperty(
40203,
nil,
{"Perform this property to open selected items copies to secondary external editor set in REAPER preferences.", "Performable"}
))

parentLayout.externalLayout:registerProperty(composeExtendedProperty(
40202,
nil,
{"Perform this property to open selected items in secondary external editor set in REAPER preferences.", "Performable"}
))



PropertiesRibbon.newLayout(parentLayout)