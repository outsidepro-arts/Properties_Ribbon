--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2025 outsidepro-arts
License: MIT License

----------

Let me say a few word before starts
LUA - is not object oriented programming language, but very flexible. Its flexibility allows to realize OOP easy via metatables. In this scripts the pseudo OOP has been used, therefore we have to understand some terms.
.1 When i'm speaking "Class" i mean the metatable variable with some fields.
2. When i'm speaking "Method" i mean a function attached to a field or submetatable field.
When i was starting write this scripts complex i imagined this as real OOP. But in consequence the scripts structure has been reunderstanded as current structure. It has been turned out more comfort as for writing new properties table, as for call this from main script engine.
After this preambula, let me begin.
]] --

-- It's just another vision of Properties Ribbon can be applied on

-- We have to fix the Properties Ribbon searching path. Currently it places on a up level directory
do
	local uplevelPath = select(2, reaper.get_action_context()):match('^.+[\\//]')
	uplevelPath = uplevelPath:match("(.+)([//\\])(.+)$")
	package.path = uplevelPath .. "//?//init.lua"
end

require "properties_ribbon"

useMacros("actions")

-- Set the cursor context forced
-- For what? REAPER should set the some actions to track context that user can perform them
reaper.SetCursorContext(0)
local insertionLayout = PropertiesRibbon.initLayout("Track insertion actions")
insertionLayout.undoContext = undo.contexts.tracks

insertionLayout:registerProperty(composeSimpleProperty(40701), true)
insertionLayout:registerProperty(composeSimpleProperty(40001), true)
insertionLayout:registerProperty(composeSimpleProperty({ 40001, 40696 }, "Insert new track with specified name"), true)
insertionLayout:registerProperty(composeSimpleProperty(40702), true)
insertionLayout:registerProperty(composeSimpleProperty(46000), true)
insertionLayout:registerProperty(composeSimpleProperty(41067), true)

PropertiesRibbon.presentLayout(insertionLayout)
