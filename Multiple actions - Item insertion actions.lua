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
]] --

-- It's just another vision of Properties Ribbon can be applied on

package.path = select(2, reaper.get_action_context()):match('^.+[\\//]') .. "?//init.lua"

require "properties_ribbon"

useMacros("actions")

-- Set the cursor context forced
-- For what? REAPER should set the some actions to track context that user can perform them
reaper.SetCursorContext(1)

local insertionLayout = initLayout("Item insertion actions")

insertionLayout.undoContext = undo.contexts.items


function insertionLayout.canProvide()
	if reaper.CountSelectedTracks() > 0 then
		return true
	end
	return false
end

insertionLayout:registerProperty(composeSimpleProperty(40214))
insertionLayout:registerProperty(composeSimpleProperty(40142))
insertionLayout:registerProperty(composeSimpleProperty(41748))
insertionLayout:registerProperty(composeSimpleProperty(42069))

main_newLayout(insertionLayout)