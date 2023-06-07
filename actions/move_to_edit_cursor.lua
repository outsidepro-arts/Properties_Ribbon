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
-- Set the cursor context forced
-- For what? REAPER should set the some actions to track context that user can perform them
reaper.SetCursorContext(1)
local thisLayout = initLayout("Move to edit cursor")
thisLayout.undoContext = undo.contexts.items

function thisLayout.canProvide()
	return reaper.GetCursorContext() == 1 and reaper.CountSelectedMediaItems(0) > 0
end

thisLayout:registerProperty(composeSimpleProperty(reaper.NamedCommandLookup("_XENAKIOS_MOVEITEMSTOEDITCURSOR"), "Move selected items to play cursor by left edge"))

-- Neither REAPER nor SWS has no this action, so we will implement own
local snapByRightEdge = {}
thisLayout:registerProperty(snapByRightEdge)

function snapByRightEdge.setValue(item)
	local pos = reaper.GetCursorPosition()
	local itemPosition, takePlayrate, itemLength =
		reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
		reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE"),
		reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
	local newPosition = pos - (itemLength * takePlayrate)
	if newPosition < 0 then
		newPosition = 0.0 -- Start of project
	end
	reaper.SetMediaItemInfo_Value(item, "D_POSITION", newPosition)
end

function snapByRightEdge:get()
	local message = initOutputMessage()
	message "Move selected items to play cursor by right edge"
	message:initType("Perform this property to move all selected items right edges to play or edit cursor.")
	return message
end

function snapByRightEdge:set_perform()
	useMacros("properties")
	local message = initOutputMessage()
	local items = item_properties_macros.getItems(config.getboolean("multiSelectionSupport", true))
	if istable(items) then
		for _, item in ipairs(items) do
			self.setValue(item)
		end
		message(string.format("Moving %u selected items to %s by right edges", #items, representation.defpos[reaper.GetCursorPosition()]))
	else
		self.setValue(items)
		message{objectId = item_properties_macros.getItemID(items, true),
			value = string.format("right edge moved to %s", representation.defpos[reaper.GetCursorPosition()])
		}
	end
	return message
end

return thisLayout