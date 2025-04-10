--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2024 outsidepro-arts
License: MIT License

----------

Let me say a few word before starts
LUA - is not object oriented programming language, but very flexible. Its flexibility allows to realize OOP easy via metatables. In this scripts the pseudo OOP has been used, therefore we have to understand some terms.
.1 When i'm speaking "Class" i mean the metatable variable with some fields.
2. When i'm speaking "Method" i mean a function attached to a field or submetatable field.
When i was starting write this scripts complex i imagined this as real OOP. But in consequence the scripts structure has been reunderstanded as current structure. It has been turned out more comfort as for writing new properties table, as for call this from main script engine.
After this preambula, let me begin.
]]
--

package.path = select(2, reaper.get_action_context()):match('^.+[\\//]') .. "?//init.lua"

require "properties_ribbon"

useMacros("item_properties")
useMacros("tools")
useMacros("actions")

-- Reading the some config which will be used everyhere
local multiSelectionSupport = config.getboolean("multiSelectionSupport", true)

-- For comfort coding, we are making the items array as global
local items = item_properties_macros.getItems(multiSelectionSupport)

-- I've just tired to write this long call so
local getItemNumber = item_properties_macros.getItemNumber

-- And another one:
local getTakeNumber = item_properties_macros.getTakeNumber


-- We should obey the configuration to report the take's name
local getItemID, getTakeID = item_properties_macros.getItemID, item_properties_macros.getTakeID

-- The macros for compose when group of items selected
local function composeMultipleItemMessage(func, states, inaccuracy)
	inaccuracy = inaccuracy or 0
	local message = initOutputMessage()
	for k = 1, #items do
		local state = func(items[k])
		local prevState
		if items[k - 1] then prevState = func(items[k - 1]) end
		local nextState
		if items[k + 1] then nextState = func(items[k + 1]) end
		if state ~= prevState and state == nextState then
			message { value = string.format("items from %s ", getItemID(items[k]):gsub("Item ", "")) }
		elseif state == prevState and state ~= nextState then
			message { value = string.format("to %s ", getItemID(items[k]):gsub("Item ", "")) }
			if inaccuracy and isnumber(state) then
				message { value = string.format("%s", states[state + inaccuracy]) }
			else
				message { value = string.format("%s", states[state]) }
			end
			if k < #items then
				message { value = ", " }
			end
		elseif state == prevState and state == nextState then
		else
			message { value = string.format("%s ", getItemID(items[k])) }
			if inaccuracy and isnumber(state) then
				message { value = string.format("%s", states[state + inaccuracy]) }
			else
				message { value = string.format("%s", states[state]) }
			end
			if k < #items then
				message { value = ", " }
			end
		end
	end
	return message
end

local function composeMultipleTakeMessage(func, states, inaccuracy)
	local message = initOutputMessage()
	for k = 1, #items do
		local state, takeIDX = func(items[k]), getTakeNumber(items[k])
		local prevState, prevTakeIDX
		if items[k - 1] then prevState, prevTakeIDX = func(items[k - 1]), getTakeNumber(items[k - 1]) end
		local nextState, nextTakeIDX
		if items[k + 1] then nextState, nextTakeIDX = func(items[k + 1]), getTakeNumber(items[k + 1]) end
		if (state ~= prevState and state == nextState) and (takeIDX ~= prevTakeIDX and takeIDX == nextTakeIDX) then
			message { value = string.format("takes from %s of %s ", getTakeID(items[k]):gsub("take ", ""),
				getItemID(items[k])) }
		elseif (state == prevState and state ~= nextState) and (takeIDX == prevTakeIDX and takeIDX ~= nextTakeIDX) then
			message { value = string.format("to %s of %s ", getTakeID(items[k]):gsub("take ", ""), getItemID(items[k])) }
			if inaccuracy and isnumber(state) then
				message { value = string.format("%s", states[state + inaccuracy]) }
			else
				message { value = string.format("%s", states[state]) }
			end
			if k < #items then
				message { value = ", " }
			end
		elseif (state == prevState and state == nextState) and (takeIDX == prevTakeIDX and takeIDX == nextTakeIDX) then
		else
			message { value = string.format("%s of %s ", getTakeID(items[k]), getItemID(items[k])) }
			if inaccuracy and isnumber(state) then
				message { value = string.format("%s", states[state + inaccuracy]) }
			else
				message { value = string.format("%s", states[state]) }
			end
			if k < #items then
				message { value = ", " }
			end
		end
	end
	return message
end

local getSelectedItemAtCursor = item_properties_macros.getSelectedItemAtCursor
local pos_relativeToGlobal = item_properties_macros.pos_relativeToGlobal
local pos_globalToRelative = item_properties_macros.pos_globalToRelative



-- global pseudoclass initialization

local parentLayout = PropertiesRibbon.initLayout("Item and take properties")

-- We have to change the name without patching the section value, so we will change this after layout initializing
if config.getboolean("objectsIdentificationWhenNavigating", true) == false and items then
	parentLayout.name = parentLayout.name:join(" for ", item_properties_macros.getItemAndTakeIDForTitle(items))
end

parentLayout.undoContext = undo.contexts.items

-- the function which gives green light to call any method from this class
function parentLayout.canProvide()
	-- We do not support the empty lanes
	local itemsCount = reaper.CountSelectedMediaItems(0)
	local isEmptyLanes = false
	for i = 0, itemsCount - 1 do
		if reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, i)) == nil then
			if not extstate._layout.emptyLanesNotify then
				msgBox("Empty lane",
					"Seems you trying to interract with take, which is empty lane. Properties Ribbon does not supports the empty lanes, because there are no possibility to interract with, but processing of cases with takes more time of developing. You may switch off the empty lanes selection to not catch this message again or switch this item take manualy before load this layout.")
				extstate._layout.emptyLanesNotify = true
			end
			isEmptyLanes = true
			break
		end
	end
	return (itemsCount > 0 and isEmptyLanes == false)
end

-- sublayouts
--visual properties
parentLayout:registerSublayout("managementLayout", "Management")

--Item properties
parentLayout:registerSublayout("itemLayout", "Item")

-- Item Position and length management properties
parentLayout:registerSublayout("positionAndLength", "Item position and length management")

-- Current take properties
parentLayout:registerSublayout("takeLayout", "Current take")



--[[
Before the properties list fill get started, let describe this subclass methods:
Method get: gets no one parameter, returns a message string which will be reported in the navigating scripts.
Method set: gets parameter action. Expects false, true or nil.
action == actions.set.increase: the property must changed upward
action == actions.set.decrease: the property must changed downward
action == actions.set.perform: The property must be toggled or performed default action
Returns a outputMessage custom metamethod which will be reported in the navigating scripts.

After you finish the methods table you have to return parent class.
No any recomendation more.
Although, no, just one thing:
Try to allow the user to perform actions on both one element and a selected group..
and try to complement any getState message with short type label. I mean what the "ajust" method will perform.
]]
--

local osaraParamsProperty = parentLayout.managementLayout:registerProperty {}

function osaraParamsProperty:get()
	local message = initOutputMessage()
	message:initType("Perform this property to view the OSARA parameters window for selected item.")
	-- This property will obey the one selected item cuz the OSARA action works with that only.
	if multiSelectionSupport == true then
		message:addType(" If the group of items selected, OSARA parameters will show for first selected item.", 1)
	end
	message { label = "OSARA parameters" }
	local item = istable(items) and items[1] or items
	message { objectId = getItemID(item) }
	return message
end

function osaraParamsProperty:set_perform()
	reaper.SetCursorContext(1, nil)
	reaper.Main_OnCommand(reaper.NamedCommandLookup("_OSARA_PARAMS"), 0)
end

local itemPropertiesProperty = {}
parentLayout.managementLayout:registerProperty(itemPropertiesProperty)

function itemPropertiesProperty:get()
	local message = initOutputMessage()
	message:initType("Perform this property to open the item properties window.")
	if istable(items) then
		message { objectId = "Selected items" }
	else
		message { objectId = getItemID(items) }
	end
	message { label = "Properties" }
	return message
end

function itemPropertiesProperty:set_perform()
	reaper.Main_OnCommand(40009, 0)
end

-- Item source property
-- Lock item methods
local lockProperty = {}
parentLayout.itemLayout:registerProperty(lockProperty)
lockProperty.states = { [0] = "Unlocked", [1] = "locked" }

function lockProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "C_LOCK")
end

function lockProperty.setValue(item, value)
	reaper.SetMediaItemInfo_Value(item, "C_LOCK", value)
end

function lockProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to lock or unlock selected item for any changes.", "Toggleable")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the lock state will be set to oposite value depending of moreness items with the same value."
			, 1)
	end
	if istable(items) then
		message { label = "lock" }
		message(composeMultipleItemMessage(self.getValue, self.states))
	else
		local state = self.getValue(items)
		message { objectId = getItemID(items), value = self.states[state] }
	end
	return message
end

function lockProperty:set_perform()
	local message = initOutputMessage()
	if istable(items) then
		local ajustingValue = nor(utils.getMostFrequent(items, self.getValue))
		if ajustingValue == 0 then
			message("Unlocking selected items.")
		elseif ajustingValue == 1 then
			message("Locking selected  items.")
		else
			ajustingValue = 0
			message("Unlocking selected items.")
		end
		for k = 1, #items do
			self.setValue(items[k], ajustingValue)
		end
	else
		self.setValue(items, nor(self.getValue(items)))
	end
	message(self:get())
	return message
end

-- volume methods
local itemVolumeProperty = {}
parentLayout.itemLayout:registerProperty(itemVolumeProperty)

function itemVolumeProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "D_VOL")
end

function itemVolumeProperty.setValue(item, value)
	reaper.SetMediaItemInfo_Value(item, "D_VOL", value)
end

function itemVolumeProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired volume value for selected item.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the relative of previous value will be applied for each item of."
			, 1)
	end
	message { label = "Volume" }
	if istable(items) then
		message(composeMultipleItemMessage(self.getValue, representation.db))
	else
		local state = self.getValue(items)
		message { objectId = getItemID(items), value = representation.db[state] }
	end
	return message
end

function itemVolumeProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustStep = config.getinteger("dbStep", 0.1)
	local maxDBValue = config.getinteger("maxDBValue", 12.0)
	if direction == actions.set.decrease.direction then
		ajustStep = -ajustStep
	end
	if istable(items) then
		for _, item in ipairs(items) do
			local state = self.getValue(item)
			state = utils.decibelstonum(utils.numtodecibels(state) + ajustStep)
			if utils.numtodecibels(state) < -150.0 then
				state = utils.decibelstonum(-150.0)
			elseif utils.numtodecibels(state) > utils.numtodecibels(maxDBValue) then
				state = utils.numtodecibels(maxDBValue)
			end
			self.setValue(item, state)
		end
	else
		local state = self.getValue(items)
		state = utils.decibelstonum(utils.numtodecibels(state) + ajustStep)
		if utils.numtodecibels(state) < -150.0 then
			state = utils.decibelstonum(-150.0)
			message("Minimum volume. ")
		elseif utils.numtodecibels(state) > maxDBValue then
			state = utils.decibelstonum(maxDBValue)
			message("maximum volume. ")
		end
		self.setValue(items, state)
	end
	message(self:get())
	return message
end

itemVolumeProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Volume extended interraction")

itemVolumeProperty.extendedProperties:registerProperty(composeThreePositionProperty(
	items,
	{
		representation = representation.db,
		min = utils.decibelstonum("-inf"),
		rootmean = utils.decibelstonum(0.0),
		max = utils.decibelstonum(config.getinteger("maxDBValue", 12.0))
	},
	{
		[true] = "Set selected items to %s. ",
		[false] = "Set to %s. "
	},
	itemVolumeProperty.setValue
))

itemVolumeProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to specify a custom volume value manualy.")
		message("Type custom volume")
		return message
	end,
	set_perform = function(self, parent)
		if istable(items) then
			local retval, answer = getUserInputs(string.format("Volume for %u selected  items", #items),
				{ caption = "New volume value:", defValue = representation.db[parent.getValue(items[1])] }
				, prepareUserData.db.formatCaption)
			if not retval then
				return "Canceled"
			end
			for k = 1, #items do
				local state = parent.getValue(items[k])
				state = prepareUserData.db.process(answer, state)
				if state then
					parent.setValue(items[k], state)
				end
			end
		else
			local state = parent.getValue(items)
			local retval, answer = getUserInputs(string.format("Volume for %s",
					getItemID(items, true):gsub("^%w", string.lower)),
				{ caption = "New volume value:", defValue = representation.db[parent.getValue(items)] },
				prepareUserData.db.formatCaption)
			if not retval then
				return false
			end
			state = prepareUserData.db.process(answer, state)
			if state then
				parent.setValue(items, state)
			else
				return false
			end
		end
		setUndoLabel(parent:get())
		return true
	end
}

-- mute methods
local muteItemProperty = {}
parentLayout.itemLayout:registerProperty(muteItemProperty)
muteItemProperty.states = { [0] = "not muted", [1] = "muted" }

function muteItemProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to mute or unmute selected item.", "Toggleable")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the mute state will be set to oposite value depending of moreness items with the same value."
			, 1)
	end
	if istable(items) then
		message { label = "Mute" }
		message(composeMultipleItemMessage(function(item) return reaper.GetMediaItemInfo_Value(item, "B_MUTE") end,
			self.states))
	else
		local state = reaper.GetMediaItemInfo_Value(items, "B_MUTE")
		message { objectId = getItemID(items), value = self.states[state] }
	end
	return message
end

function muteItemProperty:set_perform()
	local message = initOutputMessage()
	if istable(items) then
		local ajustingValue = nor(utils.getMostFrequent(items,
			function(item) return reaper.GetMediaItemInfo_Value(item, "B_MUTE") end))
		if ajustingValue == 0 then
			message("Unmuting selected items.")
		elseif ajustingValue == 1 then
			message("Muting selected items.")
		else
			ajustingValue = 0
			message("Unmuting selected items.")
		end
		for k = 1, #items do
			reaper.SetMediaItemInfo_Value(items[k], "B_MUTE", ajustingValue)
		end
	else
		local state = nor(reaper.GetMediaItemInfo_Value(items, "B_MUTE"))
		reaper.SetMediaItemInfo_Value(items, "B_MUTE", state)
		state = reaper.GetMediaItemInfo_Value(items, "B_MUTE")
	end
	message(self:get())
	return message
end

-- Loop source methods
local loopSourceProperty = {}
parentLayout.itemLayout:registerProperty(loopSourceProperty)
loopSourceProperty.states = { [0] = "not looped", [1] = "looped" }

function loopSourceProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to loop or unloop the source of selected item.", "Toggleable")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the loop source state will be set to oposite value depending of moreness items with the same value."
			, 1)
	end
	if istable(items) then
		message { label = "Source loop" }
		message(composeMultipleItemMessage(function(item) return reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC") end,
			self.states))
	else
		local state = reaper.GetMediaItemInfo_Value(items, "B_LOOPSRC")
		message { label = "Source", objectId = getItemID(items), value = self.states[state] }
	end
	return message
end

function loopSourceProperty:set_perform()
	local message = initOutputMessage()
	if istable(items) then
		local ajustingValue = nor(utils.getMostFrequent(items,
			function(item) return reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC") end))
		if ajustingValue == 0 then
			message("Set selected items sources loop off.")
		elseif ajustingValue == 1 then
			message("Looping selected items sources.")
		else
			ajustingValue = 0
			message("Set selected items sourcess loop off.")
		end
		for k = 1, #items do
			reaper.SetMediaItemInfo_Value(items[k], "B_LOOPSRC", ajustingValue)
		end
	else
		local state = nor(reaper.GetMediaItemInfo_Value(items, "B_LOOPSRC"))
		reaper.SetMediaItemInfo_Value(items, "B_LOOPSRC", state)
	end
	message(self:get())
	return message
end

-- All takes play methods
local itemAllTakesPlayProperty = {}
parentLayout.itemLayout:registerProperty(itemAllTakesPlayProperty)
itemAllTakesPlayProperty.states = { [0] = "not playing", [1] = "playing" }

function itemAllTakesPlayProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to define the playing all takes of selected item.", "Toggleable")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the playing all takes state will be set to oposite value depending of moreness items with the same value."
			, 1)
	end
	if istable(items) then
		message { label = "Playing all takes" }
		message(composeMultipleItemMessage(
			function(item) return reaper.GetMediaItemInfo_Value(item, "B_ALLTAKESPLAY") end,
			self.states))
	else
		local state = reaper.GetMediaItemInfo_Value(items, "B_ALLTAKESPLAY")
		message { label = "All takes are", objectId = getItemID(items), value = self.states[state] }
	end
	return message
end

function itemAllTakesPlayProperty:set_perform()
	local message = initOutputMessage()
	if istable(items) then
		local ajustingValue = nor(utils.getMostFrequent(items,
			function(item) return reaper.GetMediaItemInfo_Value(item, "B_ALLTAKESPLAY") end))
		if ajustingValue == 0 then
			message("Sett all Takes of selected items play off.")
		elseif ajustingValue == 1 then
			message("Set all takes of selected items play on.")
		else
			ajustingValue = 0
			message("Sett all Takes of selected items play off.")
		end
		for k = 1, #items do
			reaper.SetMediaItemInfo_Value(items[k], "B_ALLTAKESPLAY", ajustingValue)
		end
	else
		local state = nor(reaper.GetMediaItemInfo_Value(items, "B_ALLTAKESPLAY"))
		reaper.SetMediaItemInfo_Value(items, "B_ALLTAKESPLAY", state)
	end
	message(self:get())
	return message
end

-- timebase methods
local timebaseProperty = {}
parentLayout.itemLayout:registerProperty(timebaseProperty)
timebaseProperty.states = setmetatable({
	[0] = "track or project default",
	[1] = "time",
	[2] = "beats (position, length, rate)",
	[3] = "beats (position only)"
}, {
	__index = function(self, key)
		return string.format("Unknown item timebase mode %u, please report about via Github issue.", key)
	end
})

function timebaseProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "C_BEATATTACHMODE")
end

function timebaseProperty.setValue(item, state)
	reaper.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", state)
end

function timebaseProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to choose the desired time base mode for selected item.")
	if multiSelectionSupport == true then
		message:addType(
			string.format(
				' If the group of items has been selected, the value will enumerate only if these items have the same value. Otherwise, the timebase state will be set to "%s", then will enumerate this.'
				, self.states[0]), 1)
	end
	message { label = "Timebase" }
	if istable(items) then
		message(composeMultipleItemMessage(
			function(item) return reaper.GetMediaItemInfo_Value(item, "C_BEATATTACHMODE") end,
			self.states, 1))
	else
		local state = self.getValue(items)
		message { objectId = getItemID(items), value = self.states[state + 1] }
	end
	return message
end

function timebaseProperty:set_adjust(direction)
	local message = initOutputMessage()
	if istable(items) then
		local allIdentical, prevState = true, nil
		for k = 1, #items do
			local state = self.getValue(items[k])
			if prevState and prevState ~= state then
				allIdentical = false
				break
			end
			prevState = state
		end
		local state
		if allIdentical then
			state = self.getValue(items[1])
			if state + direction < #self.states and state + direction >= -1 then
				state = state + direction
			else
				message(string.format("No more %s property values.", ({ [1] = "next", [-1] = "previous" })[direction]))
			end
		else
			state = -1
		end
		message(string.format("Set selected tracks timebase to %s.", self.states[state + 1]))
		for _, item in ipairs(items) do
			self.setValue(item, state)
		end
	else
		local state = self.getValue(items)
		if state + direction < -1 then
			message("No more previous property values. ")
		elseif state + direction > #self.states - 1 then
			message("No more next property values. ")
		else
			state = state + direction
		end
		self.setValue(items, state)
	end
	message(self:get())
	return message
end

-- Auto-stretch methods
local autoStretchProperty = {}
parentLayout.itemLayout:registerProperty(autoStretchProperty)
autoStretchProperty.states = { [0] = "disabled", [1] = "enabled" }

function autoStretchProperty:get()
	local message = initOutputMessage()
	message:initType(
		string.format(
			'Toggle this property to enable or disable auto-stretch selected item at project tempo when the item timebase is set to "%s".'
			, timebaseProperty.states[2]), "Toggleable")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the auto-stretch state will be set to oposite value depending of moreness items with the same value."
			, 1)
	end
	message { label = "Auto-stretch at project tempo" }
	if istable(items) then
		message(composeMultipleItemMessage(
			function(item) return reaper.GetMediaItemInfo_Value(item, "C_AUTOSTRETCH") end,
			self.states))
	else
		local state = reaper.GetMediaItemInfo_Value(items, "C_AUTOSTRETCH")
		message { objectId = getItemID(items), value = self.states[state] }
	end
	return message
end

function autoStretchProperty:set_perform()
	local message = initOutputMessage()
	if istable(items) then
		local ajustingValue = nor(utils.getMostFrequent(items,
			function(item) return reaper.GetMediaItemInfo_Value(item, "C_AUTOSTRETCH") end))
		if ajustingValue == 0 then
			message("Switching off the auto-stretch mode for selected items.")
		elseif ajustingValue == 1 then
			message("Switching on the auto-stretch mode for  selected items.")
		else
			ajustingValue = 0
			message("Switching off the auto-stretch mode for  selected items.")
		end
		for k = 1, #items do
			reaper.SetMediaItemInfo_Value(items[k], "C_AUTOSTRETCH", ajustingValue)
		end
	else
		local state = nor(reaper.GetMediaItemInfo_Value(items, "C_AUTOSTRETCH"))
		reaper.SetMediaItemInfo_Value(items, "C_AUTOSTRETCH", state)
	end
	message(self:get())
	return message
end

-- Snap offset methods
local itemSnapOffsetProperty = {}
parentLayout.itemLayout:registerProperty(itemSnapOffsetProperty)

function itemSnapOffsetProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
end

function itemSnapOffsetProperty.setValue(item, value)
	reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", value)
end

function itemSnapOffsetProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired snap offset time.")
	if multiSelectionSupport == true then
		message:addType(
			" This property does not supports the group of selected items."
			, 1)
	end
	message:addType(" Perform this property to remove snap offset time.", 1)
	message { label = "Snap offset" }
	if istable(items) then
		message:addType(" Currently this property is unavailable because a few items are selected.", 1)
		message:changeType("Unavailable", 2)
		message(composeMultipleItemMessage(self.getValue, representation.timesec))
	else
		local state = self.getValue(items)
		message { objectId = getItemID(items), value = representation.timesec[math.round(state, 3)] }
	end
	return message
end

if not istable(items) then
	function itemSnapOffsetProperty:set_adjust(direction)
		local message = initOutputMessage()
		local ajustingValue = config.getinteger("timeStep", 0.001)
		if direction == actions.set.decrease.direction then
			ajustingValue = -ajustingValue
		end
		local state = self.getValue(items)
		if (state + ajustingValue) >= 0.000 then
			state = state + ajustingValue
		else
			state = 0.000
			message("Minimum snap offset time. ")
		end
		self.setValue(items, state)
		message(self:get())
		return message
	end

	itemSnapOffsetProperty.extendedProperties = PropertiesRibbon.initExtendedProperties(
		"Item snap offset extended interraction")


	itemSnapOffsetProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to set the snap offset time to edit cursor..")
			message("Set snap offset to cursor")
			return message
		end,
		set_perform = function(self, parent)
			reaper.Main_OnCommand(40541, 0) -- Item: Set snap offset to cursor
			return true, "Set snap offset", true
		end
	}
	itemSnapOffsetProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to remove snap offset time.")
			message("Remove snap offset time")
			return message
		end,
		set_perform = function(self, parent)
			reaper.SetMediaItemInfo_Value(items, "D_SNAPOFFSET", 0.000)
			local message = initOutputMessage()
			message(self:get())
			return true, message, true
		end
	}
end

-- Item group methods
-- For now, this property has been registered in visual layout section. Really, it influences on all items in the same group: all controls will be grouped and when an user changes any control slider, all other items changes the value too.
-- Are you Sure? But i'm not. 🤣
local groupingProperty = {}
parentLayout.managementLayout:registerProperty(groupingProperty)
groupingProperty.states = setmetatable({
	[0] = "not in a group"
}, {
	__index = function(self, key)
		return ("in group %u"):format(tostring(key))
	end
})

function groupingProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
end

function groupingProperty.setValue(item, value)
	reaper.SetMediaItemInfo_Value(item, "I_GROUPID", value)
end

function groupingProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set up the desired group number for selected item.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the group will be set to 1 first, then will begins enumerate up of."
			, 1)
	end
	if istable(items) then
		message { label = "Items groups" }
		message(composeMultipleItemMessage(self.getValue, self.states))
	else
		local state = self.getValue(items)
		message { objectId = getItemID(items), value = self.states[state] }
	end
	return message
end

function groupingProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = direction
	if istable(items) then
		local state = self.getValue(items[1])
		if state + ajustingValue > 0 then
			state = state + ajustingValue
			ajustingValue = 0
			message(("Set selected  items to group %u."):format(state))
		elseif state + ajustingValue == 0 then
			state = 0
			ajustingValue = 0
			message("Removing  selected items from any group.")
		else
			message("No more groups in this direction.")
		end
		if ajustingValue == 0 then
			for k = 1, #items do
				self.setValue(items[k], state)
			end
		end
	else
		local state = self.getValue(items)
		message(self:get())
		if state + ajustingValue > 0 then
			self.setValue(items, state + ajustingValue)
			message:clearLabel()
			message:clearValue()
			message { label = "Set to group", value = string.format("%u", self.getValue(items)) }
		elseif state + ajustingValue == 0 then
			self.setValue(items, 0)
			message:clearLabel()
			message:clearValue()
			message { value = "Not in a group" }
		elseif state + ajustingValue < 0 then
			message("No more group in this direction. ")
		end
	end
	return message
end

-- Item edges
-- It not works with multiselected items yet
local leftEdgeProperty = {}
parentLayout.positionAndLength:registerProperty(leftEdgeProperty)

function leftEdgeProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "D_POSITION")
end

function leftEdgeProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to grow or shrink the left item edge. Perform this property to trim left item edge to edit or play cursor.")
	if multiSelectionSupport then
		message:addType(" This property doesn't work with group of selected items.", 1)
	end
	message { label = "left edge" }
	if istable(items) then
		message { value = "unavailable" }
	else
		message { objectId = getItemID(items) }
		message { value = representation.defpos[self.getValue(items)] }
	end
	return message
end

if type(items) ~= "table" then
	function leftEdgeProperty:set_adjust(direction)
		local message = initOutputMessage()
		if direction == actions.set.decrease.direction then
			reaper.Main_OnCommand(40225, 0) -- Item edit: Grow left edge of items
		elseif direction == actions.set.increase.direction then
			reaper.Main_OnCommand(40226, 0) -- Item edit: Shrink left edge of items
		end
		message(self:get())
		return message
	end

	leftEdgeProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Left edge extended interraction")

	leftEdgeProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to move the play or edit cursor to left item edge position.")
			message("Go to left item edge position")
			return message
		end,
		set_perform = function(self, parent)
			local message = initOutputMessage()
			reaper.SetEditCurPos(parent.getValue(items), true, true)
			message { label = "Move to", value = representation.defpos[parent.getValue(items)] }
			return true, message
		end
	}
	leftEdgeProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to trim left item edge to edit or play cursor.")
			message("Trim left item edge to here")
			return message
		end,
		set_perform = function(self, parent)
			reaper.Main_OnCommand(41305, 0) -- Item edit: Trim left edge of item to edit cursor
			return true, "Trim left item edge", true
		end
	}
end

-- Item position in timeline
local positionProperty = {}
parentLayout.positionAndLength:registerProperty(positionProperty)

positionProperty.getValue = leftEdgeProperty.getValue

function positionProperty:get()
	local message = initOutputMessage()
	if istable(items) then
		message { label = "Items position" }
		message(composeMultipleItemMessage(self.getValue, representation.defpos))
	else
		message { objectId = getItemID(items) }
		message { label = "Position" }
		message { value = representation.defpos[self.getValue(items)] }
	end
	message:initType("Adjust this property to move the item on time ruler", "Adjustable")
	if multiSelectionSupport then
		message:addType(" If the group of items has been selected, these items will move every relative its position.", 1)
	end
	return message
end

function positionProperty:set_adjust(direction)
	local message = initOutputMessage()
	local cmds = {
		[-1] = 40120, -- Item edit: Move items/envelope points left
		[1] = 40119 -- Item edit: Move items/envelope points right
	}
	reaper.Main_OnCommand(cmds[direction], 0)
	message(self:get())
	return
end

positionProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Position extended interraction")

positionProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType(
			"Perform this property to move selected items to edit cursor position so that left edge will be positioned here..")
		message("Move to edit cursor by left edge")
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		reaper.Main_OnCommand(41205, 1)
		message("Moved to new position")
		return true, message, true
	end
}


positionProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType(
			"Perform this property to move selected items to edit cursor position so that right edge will be positioned here..")
		message("Move to edit cursor by right edge")
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		for _, item in ipairs(istable(items) and items or { items }) do
			---@todo These computations still need to be checked because sometimes they're useless and give strange results
			local takePlayrate, itemLength = reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE"),
				reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
			reaper.SetMediaItemInfo_Value(item, "D_POSITION", reaper.GetCursorPosition() - itemLength)
		end
		message("Moved to new position")
		return true, message, true
	end
}

positionProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message "Move items by grid"
		message:initType(
			"Adjust this property to move selected items by set grid in the project timeline."
		)
		return message
	end,
	set_adjust = function(self, parent, direction)
		local message = initOutputMessage()
		local cmds = {
			[-1] = 40793, -- Item edit: Move items/envelope points left by grid size
			[1] = 40794 -- Item edit: Move items/envelope points right by grid size
		}
		reaper.Main_OnCommand(cmds[direction], 0)
		message(parent:get())
		return false, message
	end
}

-- Right item edge
local rightEdgeProperty = {}
parentLayout.positionAndLength:registerProperty(rightEdgeProperty)

function rightEdgeProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "D_POSITION") + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
end

function rightEdgeProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to shrink or grow the right item edge.")
	if multiSelectionSupport then
		message:addType(" This property doesn't work with group of selected items.", 1)
	end
	message { label = "Right edge" }
	if istable(items) then
		message { value = "unavailable" }
	else
		message { objectId = getItemID(items) }
		message { value = representation.defpos[self.getValue(items)] }
	end
	return message
end

if type(items) ~= "table" then
	function rightEdgeProperty:set_adjust(direction)
		local message = initOutputMessage()
		if direction == actions.set.decrease.direction then
			reaper.Main_OnCommand(40227, 0) -- Item edit: Shrink right edge of items
		elseif direction == actions.set.increase.direction then
			reaper.Main_OnCommand(40228, 0) -- Item edit: Grow right edge of items
		end
		message(self:get())
		return message
	end

	rightEdgeProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Right edge extended interraction")

	rightEdgeProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to move the play or edit cursor to right item edge position.")
			message("Go to right item edge position")
			return message
		end,
		set_perform = function(self, parent)
			local message = initOutputMessage()
			reaper.SetEditCurPos(parent.getValue(items), true, true)
			message { label = "Move to", value = representation.defpos[parent.getValue(items)] }
			return true, message
		end
	}
	rightEdgeProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to trim right item edge to edit or play cursor.")
			message("Trim right item edge to here")
			return message
		end,
		set_perform = function(self, parent)
			reaper.Main_OnCommand(41311, 0) -- Item edit: Trim right edge of item to edit cursor
			return true, "Trim right item edge. ", true
		end
	}
end

-- Fade methods
-- Fadein shape
local fadeinShapeProperty = {}
parentLayout.itemLayout:registerProperty(fadeinShapeProperty)
fadeinShapeProperty.states = setmetatable({
	[0] = "Linear",
	[1] = "Inverted quadratic",
	[2] = "Quadratic",
	[3] = "Inverted quartic",
	[4] = "Quartic",
	[5] = "Cosine S-curve",
	[6] = "Quartic S-curve",
	[7] = "Equal power"
}, {
	__index = function(self, key)
		return string.format(
			"Unknown fade type %s. Please create an issue with this fade type on the properties Ribbon github repository."
			, tostring(key))
	end
})

function fadeinShapeProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "C_FADEINSHAPE")
end

function fadeinShapeProperty.setValue(item, value)
	reaper.SetMediaItemInfo_Value(item, "C_FADEINSHAPE", value)
end

function fadeinShapeProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to choose the desired shape mode for fadein in selected item.")
	if multiSelectionSupport == true then
		message:addType(
			string.format(
				' If the group of items has been selected, the value will enumerate only if these items have the same value. Otherwise, the shape state will be set to "%s", then will enumerate this.'
				, self.states[0]), 1)
	end
	message { label = "Fade-in shape" }
	if istable(items) then
		message(composeMultipleItemMessage(self.getValue, self.states))
	else
		local state = self.getValue(items)
		message { objectId = getItemID(items), value = self.states[state] }
	end
	return message
end

function fadeinShapeProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = direction
	if istable(items) then
		local state = 1
		if utils.isSameValue(items, self.getValue) then
			state = self.getValue(items[1])
			if state + ajustingValue <= #self.states and state + ajustingValue >= 0 then
				state = state + ajustingValue
			else
				message(string.format("No more %s property values.", ({ [1] = "next", [-1] = "previous" })[direction]))
			end
		end
		for k = 1, #items do
			self.setValue(items[k], state)
		end
	else
		local state = self.getValue(items)
		if state + ajustingValue > #self.states then
			message("No more next property values. ")
		elseif state + ajustingValue < 0 then
			message("No more previous property values. ")
		else
			state = state + ajustingValue
		end
		self.setValue(items, state)
	end
	message(self:get())
	return message
end

-- Fadein manual length methods
local fadeinLenProperty = {}
parentLayout.itemLayout:registerProperty(fadeinLenProperty)

function fadeinLenProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN")
end

function fadeinLenProperty.setValue(item, value)
	reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", value)
end

function fadeinLenProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to setup desired fadein length for selected item.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the relative of previous value will be applied for each item of."
			, 1)
	end
	message { label = "Fade-in length" }
	if istable(items) then
		message(composeMultipleItemMessage(self.getValue, representation.timesec))
	else
		message { objectId = getItemID(items), value = representation.timesec[self.getValue(items)] }
	end
	return message
end

function fadeinLenProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = config.getinteger("timeStep", 0.001)
	if direction == actions.set.decrease.direction then
		ajustingValue = -ajustingValue
	end
	if istable(items) then
		for k = 1, #items do
			local state = self.getValue(items[k])
			if (state + ajustingValue) >= 0 then
				state = state + ajustingValue
			else
				state = 0.000
			end
			self.setValue(items[k], state)
		end
	else
		local state = self.getValue(items)
		if (state + ajustingValue) >= 0.000 then
			state = state + ajustingValue
		else
			state = 0.000
			message("Minimum length. ")
		end
		self.setValue(items, state)
	end
	message(self:get())
	return message
end

fadeinLenProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Fade length extended interraction")
fadeinLenProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message("Fade in this item to cursor")
		message:initType("Perform this property to fade in the selected item to play or edit cursor.")
		return message
	end,
	set_perform = function(self, parent)
		reaper.Main_OnCommand(40509, 0) -- Item: Fade items in to cursor
		return true, "", true
	end
}
fadeinLenProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message(string.format("Set %s (off the fade)", representation.timesec[0.000]))
		message:initType(
			"Perform this property to set the minimal length value that means the fade will be not applied.")
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		local label = parent:get().label
		if istable(items) then
			for _, item in ipairs(items) do
				parent.setValue(item, 0)
			end
			message(string.format("Set selected items %s to %s", label, representation.timesec[0.000]))
		else
			parent.setValue(items, 0)
			message { label = label, value = string.format("set to %s", representation.timesec[0.000]) }
		end
		return true, message, true
	end
}
-- We will use the default value restore in other cases independently
local restoreFadeDefaultsEProperty = {}
if reaper.get_config_var_string("deffadelen") then
	fadeinLenProperty.extendedProperties:registerProperty(restoreFadeDefaultsEProperty)
	function restoreFadeDefaultsEProperty:get(parent)
		local message = initOutputMessage()
		local _, str = reaper.get_config_var_string("deffadelen")
		message(string.format("Restore default value (%s)", representation.timesec[tonumber(str)]))
		return message
	end

	function restoreFadeDefaultsEProperty:set_perform(parent)
		local message = initOutputMessage()
		local _, str = reaper.get_config_var_string("deffadelen")
		local ajustingValue = math.round(tonumber(str), 3)
		message("Restore default value, ")
		if istable(items) then
			for k = 1, #items do
				parent.setValue(items[k], ajustingValue)
			end
		else
			parent.setValue(items, ajustingValue)
		end
		return true, message, true
	end
end

-- Fadein curve methods
local fadeinDirProperty = {}
parentLayout.itemLayout:registerProperty(fadeinDirProperty)
fadeinDirProperty.states = setmetatable({
	[0] = "flat"
}, {
	__index = function(self, key)
		if key > 0 then
			return ("%s%% to the right"):format(utils.numtopercent(key))
		elseif key < 0 then
			return ("%s%% to the left"):format(-utils.numtopercent(key))
		end
	end
})

function fadeinDirProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "D_FADEINDIR")
end

function fadeinDirProperty.setValue(item, value)
	reaper.SetMediaItemInfo_Value(item, "D_FADEINDIR", value)
end

function fadeinDirProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired fadein curvature for selected item.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the relative of previous value will be applied for each item of."
			, 1)
	end
	message:addType(" Perform this property to reset the value to 0.00.", 1)
	message { label = "Fade-in curve" }
	if istable(items) then
		message(composeMultipleItemMessage(self.getValue, self.states))
	else
		local state = self.getValue(items)
		message { objectId = getItemID(items), value = self.states[state] }
	end
	return message
end

function fadeinDirProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = config.getinteger("percentStep", 1)
	if direction == actions.set.increase.direction then
		ajustingValue = utils.percenttonum(ajustingValue)
	elseif direction == actions.set.decrease.direction then
		ajustingValue = -utils.percenttonum(ajustingValue)
	end
	if istable(items) then
		for k = 1, #items do
			local state = self.getValue(items[k])
			state = math.round((state + ajustingValue), 3)
			if state >= 1 then
				state = 1
			elseif state <= -1 then
				state = -1
			end
			self.setValue(items[k], state)
		end
	else
		local state = self.getValue(items)
		state = math.round((state + ajustingValue), 3)
		if state > 1 then
			state = 1
			message("Right curve boundary. ")
		elseif state < -1 then
			state = -1
			message("Left curve boundary. ")
		end
		self.setValue(items, state)
	end
	message(self:get())
	return message
end

function fadeinDirProperty:set_perform()
	local message = initOutputMessage()
	message(string.format("Reset to %s. ", self.states[0]))
	if istable(items) then
		for _, item in ipairs(items) do
			self.setValue(item, 0)
		end
	else
		self.setValue(items, 0)
	end
	message(self:get())
	return message
end

-- Fadeout shape
local fadeoutShapeProperty = {}
parentLayout.itemLayout:registerProperty(fadeoutShapeProperty)
fadeoutShapeProperty.states = fadeinShapeProperty.states

function fadeoutShapeProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "C_FADEOUTSHAPE")
end

function fadeoutShapeProperty.setValue(item, value)
	reaper.SetMediaItemInfo_Value(item, "C_FADEOUTSHAPE", value)
end

function fadeoutShapeProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to choose the desired shape mode for fadeout in selected item.")
	if multiSelectionSupport == true then
		message:addType(
			string.format(
				' If the group of items has been selected, the value will enumerate only if these items have the same value. Otherwise, the shape state will be set to "%s", then will enumerate this.'
				, self.states[0]), 1)
	end
	message { label = "Fade-out shape" }
	if istable(items) then
		message(composeMultipleItemMessage(self.getValue, self.states))
	else
		local state = self.getValue(items)
		message { objectId = getItemID(items), value = self.states[state] }
	end
	return message
end

fadeoutShapeProperty.set_adjust = fadeinShapeProperty.set_adjust

-- fadeout manual length methods
local fadeoutLenProperty = {}
parentLayout.itemLayout:registerProperty(fadeoutLenProperty)

function fadeoutLenProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
end

function fadeoutLenProperty.setValue(item, value)
	reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", value)
end

function fadeoutLenProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to setup desired fadeout length for selected item.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the relative of previous value will be applied for each item of."
			, 1)
	end
	message { label = "Fade-out length" }
	if istable(items) then
		message(composeMultipleItemMessage(self.getValue, representation.timesec))
	else
		message { objectId = getItemID(items), value = representation.timesec[self.getValue(items)] }
	end
	return message
end

fadeoutLenProperty.set_adjust = fadeinLenProperty.set_adjust
fadeoutLenProperty.extendedProperties = PropertiesRibbon.initExtendedProperties(fadeinLenProperty.extendedProperties
	.name)
-- We have to make a hack: copy all extended properties from fade-in length but without first property
-- Remember that really, extended properties start from 2 but not from 1: 1 is return back
-- We will not use the iterators factory cuz the changed metatable will make the infinite cycle there
for i = 1, #fadeinLenProperty.extendedProperties.properties do
	if i == 2 then
		fadeoutLenProperty.extendedProperties.properties[i] = {
			get = function(self, parent)
				local message = initOutputMessage()
				message("Fade out this item from cursor")
				message:initType("Perform this property to fade out the selected item from play or edit cursor to.")
				return message
			end,
			set_perform = function(self, parent)
				reaper.Main_OnCommand(40510, 0) -- Item: Fade items out from cursor
				return true, "", true
			end
		}
	else
		fadeoutLenProperty.extendedProperties.properties[i] = fadeinLenProperty.extendedProperties.properties[i]
	end
end

-- fadeout curve methods
local fadeoutDirProperty = {}
parentLayout.itemLayout:registerProperty(fadeoutDirProperty)
fadeoutDirProperty.states = fadeinDirProperty.states

function fadeoutDirProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "D_FADEOUTDIR")
end

function fadeoutDirProperty.setValue(item, value)
	reaper.SetMediaItemInfo_Value(item, "D_FADEOUTDIR", value)
end

function fadeoutDirProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired fadeout curvature for selected item.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the relative of previous value will be applied for each item of."
			, 1)
	end
	message:addType(" Perform this property to reset the value to flat.", 1)
	message { label = "Fade-out curve" }
	if istable(items) then
		message(composeMultipleItemMessage(self.getValue, self.states))
	else
		local state = self.getValue(items)
		message { objectId = getItemID(items), value = self.states[state] }
	end
	return message
end

fadeoutDirProperty.set_adjust = fadeinDirProperty.set_adjust
fadeoutDirProperty.set_perform = fadeinDirProperty.set_perform

-- Fadein automatic length
local fadeinAutoLenProperty = {}
parentLayout.itemLayout:registerProperty(fadeinAutoLenProperty)

function fadeinAutoLenProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO")
end

function fadeinAutoLenProperty.setValue(item, value)
	reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", value)
end

function fadeinAutoLenProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to setup desired automatic fadein length for selected item.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the relative of previous value will be applied for each item of."
			, 1)
	end
	message { label = "Automatic fade-in length" }
	if istable(items) then
		message(composeMultipleItemMessage(self.getValue, setmetatable({}, {
			__index = function(self, state)
				if state >= 0 then
					return representation.timesec[state]
				else
					return "automatic fadein off"
				end
			end
		})))
	else
		message { objectId = getItemID(items) }
		local state = self.getValue(items)
		if state >= 0 then
			message { value = representation.timesec[state] }
		else
			message { value = "off" }
		end
	end
	return message
end

fadeinAutoLenProperty.set_adjust = fadeinLenProperty.set_adjust
fadeinAutoLenProperty.extendedProperties = PropertiesRibbon.initExtendedProperties(
	"Automatic fade length extended interraction")

fadeinAutoLenProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		local label = parent:get().label
		if istable(items) then
			message(string.format("Switch off %s for selected items", label))
		else
			message(string.format("Switch off %s for this item", label))
		end
		return message
	end,
	set_perform = function(self, parent)
		local label = parent:get().label
		if istable(items) then
			for _, item in ipairs(items) do
				parent.setValue(item, -1)
			end
			return true, string.format("Switching off the %s for selected items", label), true
		else
			parent.setValue(items, -1)
			return true, string.format("Switching off the %s", label), true
		end
	end
}
if restoreFadeDefaultsEProperty then
	fadeinAutoLenProperty.extendedProperties:registerProperty(restoreFadeDefaultsEProperty)
end


-- Automatic fadeout length methods
local fadeoutAutoLenProperty = {}
parentLayout.itemLayout:registerProperty(fadeoutAutoLenProperty)

function fadeoutAutoLenProperty.getValue(item)
	return reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO")
end

function fadeoutAutoLenProperty.setValue(item, value)
	reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", value)
end

function fadeoutAutoLenProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to setup desired automatic fadeout length for selected item.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the relative of previous value will be applied for each item of."
			, 1)
	end
	message { label = "Automatic fade-out length" }
	if istable(items) then
		message(composeMultipleItemMessage(self.getValue, setmetatable({}, {
			__index = function(self, state)
				if state >= 0 then
					return representation.timesec[state]
				else
					return "automatic fade-out off"
				end
			end
		})))
	else
		message { objectId = getItemID(items) }
		local state = self.getValue(items)
		if state >= 0 then
			message { value = representation.timesec[state] }
		else
			message { value = "off" }
		end
	end
	return message
end

fadeoutAutoLenProperty.set_adjust = fadeinAutoLenProperty.set_adjust
fadeoutAutoLenProperty.extendedProperties = fadeinAutoLenProperty.extendedProperties


-- active take methods
local activeTakeProperty = {}
parentLayout.takeLayout:registerProperty(activeTakeProperty)

function activeTakeProperty.getValue(item)
	return reaper.GetActiveTake(item)
end

function activeTakeProperty.setValue(item, take)
	reaper.SetActiveTake(take)
end

function activeTakeProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to switch the desired  active take of selected item.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the relative of previous value will be applied for each item of."
			, 1)
	end
	if istable(items) then
		message { label = "Takes:" }
		-- Here is non-standart case, so we will not use our macros
		for k = 1, #items do
			local state, IDX = self.getValue(items[k]), getTakeNumber(items[k])
			local prevState, prevIDX
			if items[k - 1] then prevState, prevIDX = self.getValue(items[k - 1]), getTakeNumber(items[k - 1]) end
			local nextState, nextIDX
			if items[k + 1] then nextState, nextIDX = self.getValue(items[k + 1]), getTakeNumber(items[k + 1]) end
			if IDX ~= prevIDX and IDX == nextIDX then
				message { value = string.format("items from %s ", getItemID(items[k])) }
			elseif IDX == prevIDX and IDX ~= nextIDX then
				message { value = string.format("to %s ", getItemID(items[k])) }
				local _, name = reaper.GetSetMediaItemTakeInfo_String(self.getValue(items[k]), "P_NAME", "", false)
				message { value = string.format("%u, %s", getTakeNumber(items[k]), name) }
				if k < #items then
					message { value = ", " }
				end
			elseif IDX == prevIDX and IDX == nextIDX then
			else
				message { value = string.format("%s ", getItemID(items[k])) }
				local _, name = reaper.GetSetMediaItemTakeInfo_String(self.getValue(items[k]), "P_NAME", "", false)
				message { value = string.format("%u, %s", getTakeNumber(items[k]), name) }
				if k < #items then
					message { value = ", " }
				end
			end
		end
	else
		local state = self.getValue(items)
		local retval, name = reaper.GetSetMediaItemTakeInfo_String(state, "P_NAME", "", false)
		message { objectId = getItemID(items), label = getTakeID(items), value = name }
	end
	return message
end

function activeTakeProperty:set_adjust(direction)
	local message = initOutputMessage()
	if istable(items) then
		for k = 1, #items do
			local state = self.getValue(items[k])
			local idx = reaper.GetMediaItemTakeInfo_Value(state, "IP_TAKENUMBER")
			if direction == actions.set.increase.direction then
				local takesCount = reaper.CountTakes(items[k])
				for i = idx + 1, takesCount do
					local curTake = reaper.GetTake(items[k], i)
					if curTake then
						state = curTake
						break
					end
					if i + 1 >= takesCount then
						if curTake then
							state = curTake
						end
						break
					end
				end
			elseif direction == actions.set.decrease.direction then
				for i = idx - 1, -1, -1 do
					local curTake = reaper.GetTake(items[k], i)
					if curTake then
						state = curTake
						break
					end
					if i - 1 <= -1 then
						if curTake then
							state = curTake
						end
						break
					end
				end
			end
			self.setValue(items[k], state)
		end
	else
		local state = self.getValue(items)
		local idx = reaper.GetMediaItemTakeInfo_Value(state, "IP_TAKENUMBER")
		if direction == actions.set.increase.direction then
			local takesCount = reaper.CountTakes(items)
			for i = idx + 1, takesCount do
				local curTake = reaper.GetTake(items, i)
				if curTake then
					state = curTake
					break
				end
				if i + 1 >= takesCount then
					message("No more next property values. ")
					if curTake then
						state = curTake
					end
					break
				end
			end
		elseif direction == actions.set.decrease.direction then
			for i = idx - 1, -1, -1 do
				local curTake = reaper.GetTake(items, i)
				if curTake then
					state = curTake
					break
				end
				if i - 1 <= -1 then
					message("No more previous property values. ")
					if curTake then
						state = curTake
					end
					break
				end
			end
		end
		self.setValue(items, state)
	end
	message(self:get())
	return message
end

activeTakeProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Active take extended interraction")
activeTakeProperty.extendedProperties:registerProperty {
	getValue = function(item)
		return ({ reaper.GetSetMediaItemTakeInfo_String(reaper.GetActiveTake(item), "P_NAME", "", false) })[2]
	end,
	setValue = function(item, value)
		reaper.GetSetMediaItemTakeInfo_String(reaper.GetActiveTake(item), "P_NAME", value, true)
	end,
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to rename the active take of item.")
		if multiSelectionSupport then
			message:addType(
				" If the group of item has been selected, the every take of will get new specified name with ordered number."
				, 1)
		end
		if istable(items) then
			message("Rename active takes of selected items")
		else
			message("Rename this take")
		end
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		if istable(items) then
			local state, answer = getUserInputs("Change name active takes of selected items",
				{ caption = "New take name:" }
			)
			if state == true then
				for k = 1, #items do
					self.setValue(items[k], answer .. " " .. k)
				end
				message(string.format("The name %s has been set for %u items.", answer, #items))
			end
		else
			local name = self.getValue(items)
			local aState, answer = getUserInputs(
				string.format("Change active take name for item %u", getItemNumber(items)),
				{ caption = 'New item name:', defValue = name }
			)
			if aState == true then
				self.setValue(items, answer)
				message(string.format("The take %s renamed to %s", name, answer))
			else
				return false
			end
		end
		return true, message, true
	end
}
activeTakeProperty.extendedProperties:registerProperty {
	get = function(self, parent, shouldExtractFilenameOnly)
		local message = initOutputMessage()
		if istable(items) then
			message { label = "Selected items takes sources" }
			message(composeMultipleTakeMessage(
				function(item)
					return reaper.GetMediaItemTake_Source(parent.getValue(item))
				end, setmetatable({}, {
					__index = function(self, key)
						return (shouldExtractFilenameOnly and select(3, reaper.GetMediaSourceFileName(key):rpart("[//\\]"))) or
							reaper.GetMediaSourceFileName(key)
					end
				})
			))
		else
			local state = reaper.GetMediaItemTake_Source(parent.getValue(items))
			message {
				label = "Take source",
				value = (shouldExtractFilenameOnly and select(3, reaper.GetMediaSourceFileName(state):rpart("[//\\]"))) or
					reaper.GetMediaSourceFileName(state)
			}
		end
		message:initType("Adjust this property to choose new take source by respective file in the same folder.")
		if multiSelectionSupport then
			message:addType(
				" If the group of items has been selected, the take sources will be switched for each selected take respectively.",
				1)
		end
		message:addType(" Perform this property to choose new source for take by using \"Open as\" dialog.", 1)
		return message
	end,
	set_adjust = function(self, parent, direction)
		local message = initOutputMessage()
		local cmds = {
			[-1] = reaper.NamedCommandLookup("_XENAKIOS_SISFTPREVIF"), -- Xenakios/SWS: Switch item source file to previous in folder
			[1] = reaper.NamedCommandLookup("_XENAKIOS_SISFTNEXTIF") -- Xenakios/SWS: Switch item source file to next in folder
		}
		reaper.Main_OnCommand(cmds[direction], 0)
		message(self:get(parent, true))
		return false, message
	end,
	set_perform = function(self, parent)
		return reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_CHANGESOURCEFILE"), 0) == 1
	end
}
activeTakeProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to delete active take of selected item.")
		if multiSelectionSupport then
			message:addType(" If the group of items has been selected, every active take of will be deleted.", 1)
		end
		if istable(items) then
			message("Delete active takes of selected items")
		else
			message("Delete this take")
		end
		return message
	end,
	set_perform = function(self, parent)
		reaper.Main_OnCommand(40130, 0) --
		return true, nil, true
	end
}

-- Take volume methods
local takeVolumeProperty = {}
parentLayout.takeLayout:registerProperty(takeVolumeProperty)

function takeVolumeProperty.getValue(item)
	local state = reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_VOL")
	if state < 0 then
		state = -state
	end
	return state
end

function takeVolumeProperty.setValue(item, value)
	local state = reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_VOL")
	if state < 0 then
		value = -value
	end
	reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_VOL", value)
end

function takeVolumeProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired volume value for active take of selected item.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the relative of previous value will be applied for each item take of."
			, 1)
	end
	message { label = "Volume" }
	if istable(items) then
		message(composeMultipleTakeMessage(self.getValue, representation.db))
	else
		local state = self.getValue(items)
		message { objectId = string.format("%s %s", getItemID(items), getTakeID(items)), value = representation.db
			[state] }
	end
	return message
end

takeVolumeProperty.set_adjust = itemVolumeProperty.set_adjust
takeVolumeProperty.extendedProperties = PropertiesRibbon.initExtendedProperties(itemVolumeProperty.extendedProperties
	.name)
takeVolumeProperty.extendedProperties:registerProperty(composeThreePositionProperty(
	items,
	{
		representation = representation.db,
		min = utils.decibelstonum("-inf"),
		rootmean = utils.decibelstonum(0.0),
		max = utils.decibelstonum(config.getinteger("maxDBValue", 12.0))
	},
	{
		[true] = "Set selected items takes to %s. ",
		[false] = "Set to %s. "
	},
	takeVolumeProperty.setValue
))

takeVolumeProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to specify a custom vvolume value manualy.")
		message("Type custom volume")
		return message
	end,
	set_perform = function(self, parent)
		if istable(items) then
			local retval, answer = getUserInputs(string.format("Volume for active takes of %u selected items", #items),
				{ caption = "New volume name:", defValue = representation.db[parent.getValue(items[1])] },
				prepareUserData.db.formatCaption
			)
			if not retval then
				return false, "Canceled"
			end
			for k = 1, #items do
				local state = parent.getValue(items[k])
				state = prepareUserData.db.process(answer, state)
				if state then
					parent.setValue(items[k], state)
				end
			end
		else
			local state = parent.getValue(items)
			local retval, answer = getUserInputs(string.format("Volume for %s of %s",
					getTakeID(items, true):gsub("^%w", string.lower), getItemID(items, true):gsub("^%w", string.lower)),
				{ caption = "New volume value:", defValue = representation.db[parent.getValue(items)] },
				prepareUserData.db.formatCaption)
			if not retval then
				return false, "Canceled"
			end
			state = prepareUserData.db.process(answer, state)
			if state then
				parent.setValue(items, state)
			else
				return false
			end
		end
		setUndoLabel(parent:get())
		return true
	end
}
takeVolumeProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to use normalize items option.")
		if istable(items) then
			message(string.format("Normalize takes of %u selected items", #items))
		else
			message("Normalize item take")
		end
		return message
	end,
	set_perform = function(self, parent)
		reaper.Main_OnCommand(42460, 0)
		return true
	end
}

takeVolumeProperty.extendedProperties:registerProperty(composeEnvelopeControlProperty.viaCommand(items, "Volume,Mute",
	function(item, envName)
		return reaper.GetTakeEnvelopeByName(reaper.GetActiveTake(item), string.format("%s", envName))
	end, { 40693, 40695 }))

-- Take pan methods
local takePanProperty = {}
parentLayout.takeLayout:registerProperty(takePanProperty)

function takePanProperty.getValue(item)
	return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PAN")
end

function takePanProperty.setValue(item, value)
	reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PAN", value)
end

function takePanProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired current take pan value for selected item.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the relative of previous value will be applied for each item active take of."
			, 1)
	end
	message { label = "Pan" }
	if istable(items) then
		message(composeMultipleTakeMessage(self.getValue, representation.pan))
	else
		message { objectId = string.format("%s %s", getItemID(items), getTakeID(items)) }
		local state = self.getValue(items)
		message { value = representation.pan[state] }
	end
	return message
end

function takePanProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = config.getinteger("percentStep", 1)
	if direction == actions.set.increase.direction then
		ajustingValue = utils.percenttonum(ajustingValue) or 0.01
	elseif direction == actions.set.decrease.direction then
		ajustingValue = -utils.percenttonum(ajustingValue) or -0.01
	end
	if istable(items) then
		for k = 1, #items do
			local state = self.getValue(items[k])
			state = math.round((state + ajustingValue), 3)
			if state >= 1 then
				state = 1
			elseif state <= -1 then
				state = -1
			end
			self.setValue(items[k], state)
		end
	else
		local state = self.getValue(items)
		state = math.round((state + ajustingValue), 3)
		if state > 1 then
			state = 1
			message("Right boundary. ")
		elseif state < -1 then
			state = -1
			message("Left boundary. ")
		end
		self.setValue(items, state)
	end
	message(self:get())
	return message
end

takePanProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Pan exttended interraction")
takePanProperty.extendedProperties:registerProperty(composeThreePositionProperty(
	items,
	{
		representation = representation.pan,
		min = -1,
		rootmean = 0,
		max = 1
	},
	{
		[true] = "Set selected items takes to %s. ",
		[false] = "Set to %s. "
	},
	takePanProperty.setValue
))

takePanProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to specify a custom pan value manualy.")
		message("Type custom pan")
		return message
	end,
	set_perform = function(self, parent)
		if istable(items) then
			local retval, answer = getUserInputs(string.format("Pan for active takes of %u selected items", #items),
				{ caption = "New pan value:", defValue = representation.pan[parent.getValue(items[1])] },
				prepareUserData.pan.formatCaption)
			if not retval then
				return false, "Canceled"
			end
			for k = 1, #items do
				local state = parent.getValue(items[k])
				state = prepareUserData.pan.process(answer, state)
				if state then
					parent.setValue(items[k], state)
				end
			end
		else
			local state = parent.getValue(items)
			local retval, answer = getUserInputs(string.format("Pan for %s of %s",
					getTakeID(items, true):gsub("^%w", string.lower), getItemID(items, true):gsub("^%w", string.lower)),
				{ caption = "New pan value:", defValue = representation.pan[state] },
				prepareUserData.pan.formatCaption)
			if not retval then
				return false, "Canceled"
			end
			state = prepareUserData.pan.process(answer, state)
			if state then
				parent.setValue(items, state)
			else
				return false
			end
		end
		setUndoLabel(parent:get())
		return true
	end
}

if multiSelectionSupport then
	takePanProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType(
				"Perform this property to set the sequential pan values for active takes of selected items."
			)
			if not istable(items) then
				message:addType(
					"This property is currently unavailable because you need to select at least two items.",
					1)
				message:changeType("unavailable", 2)
			end
			message "Set sequential pan values"
			if istable(items) then
				message(string.format(" for active takes of %u selected items", #items))
			end
			return message
		end,
		set_perform = function(self, parent)
			if istable(items) then
				local retval, answer = getUserInputs(
					string.format("Sequential Pan for takes of %u selected items", #items),
					{
						{
							caption = "Pan value without direction:",
							defValue = representation.pan[parent.getValue(items[1])]:match(
								"%d*"
							)
						},
						{
							caption = "Directions pattern:",
							defValue = "Left Right"
						}
					},
					"First field expects the pan value without any direction specify. Second field expects the direction pattern which will be aplied to selected tracks sequentially (LR means that every two tracks will be panned to left and right respectively, LLRR means that two tracks will be panned to left then two tracks to right). Besides there Center or c can be used to set track to center."
				)
				if not retval then
					return false, "Canceled"
				end
				local panValue = answer[1]
				if panValue == "" then
					msgBox("Error", "the pan value cannot be empty.")
					return
				end
				if not tonumber(panValue) then
					msgBox("Error", "the pan value must be a number.")
					return
				end
				if tonumber(panValue) > 100 then
					msgBox("Error", "the pan value must be less than 100.")
					return
				end
				if not answer[2] then
					msgBox("Error", "the direction pattern cannot be empty.")
					return
				end
				if not answer[2]:lower():find("l") or not answer[2]:lower():find("r") then
					msgBox("Error",
						'The direction pattern must contain at least one "Left" (or "l"), optional "Center" (or "c") and one "Right" (or "r").')
					return
				end
				local dirs = {}
				for _, char in answer[2]:lower():sequentchar() do
					if char:match("l") then
						table.insert(dirs, "l")
					elseif char:match("c") then
						table.insert(dirs, "c")
					elseif char:match("r") then
						table.insert(dirs, "r")
					end
				end
				local dirField = 1
				for _, item in ipairs(items) do
					local curPanValue = utils.percenttonum(panValue)
					if dirs[dirField] == "l" then
						curPanValue = -curPanValue
					elseif dirs[dirField] == "c" then
						curPanValue = 0
					end
					parent.setValue(item, curPanValue)
					if dirField < #dirs then
						dirField = dirField + 1
					else
						dirField = 1
					end
				end
				setUndoLabel(parent:get())
				return true
			end
			return false, "You need to select at least two items to perform this action."
		end
	}
end

takePanProperty.extendedProperties:registerProperty(composeEnvelopeControlProperty
	.viaCommand(items, "Pan",
		function(item, envName)
			return reaper.GetTakeEnvelopeByName(reaper.GetActiveTake(item), envName)
		end, 40694))

-- Take phase methods
local takePhaseProperty = {}
parentLayout.takeLayout:registerProperty(takePhaseProperty)
takePhaseProperty.states = { [0] = "normal", [1] = "inverted" }

-- Cockos made the phase inversion via negative volume value.
function takePhaseProperty.getValue(item)
	local state = reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_VOL")
	if state < 0 then
		return 1
	elseif state >= 0 then
		return 0
	end
end

function takePhaseProperty.setValue(item, value)
	local state = reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_VOL")
	if value == 1 then
		if state > 0 then
			state = -state
		end
	elseif value == 0 then
		if state < 0 then
			state = -state
		end
	end
	reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_VOL", state)
end

function takePhaseProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to set the phase polarity for take of selected item.", "toggleable")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the phase polarity state will be set to oposite value depending of moreness takes of items with the same value."
			, 1)
	end
	message { label = "Phase" }
	if istable(items) then
		message(composeMultipleTakeMessage(self.getValue, self.states))
	else
		local state = self.getValue(items)
		message { objectId = string.format("%s %s", getItemID(items), getTakeID(items)), value = self.states[state] }
	end
	return message
end

function takePhaseProperty:set_perform()
	local message = initOutputMessage()
	if istable(items) then
		local ajustingValue = nor(utils.getMostFrequent(items, self.getValue))
		if ajustingValue == 0 then
			message("Normalizing the phase for selected items takes.")
		elseif ajustingValue == 1 then
			message("Inverting the phase for selected items takes.")
		else
			ajustingValue = 0
			message("Normalizing the phase for selected items takes.")
		end
		for k = 1, #items do
			self.setValue(items[k], ajustingValue)
		end
	else
		self.setValue(items, nor(self.getValue(items)))
	end
	message(self:get())
	return message
end

-- Take channel mode methods
local takeChannelModeProperty = {}
parentLayout.takeLayout:registerProperty(takeChannelModeProperty)
takeChannelModeProperty.states = setmetatable({
	[0] = "normal",
	[1] = "reverse stereo",
	[2] = "mono (downmix)",
	[3] = "mono (left)",
	[4] = "mono (right)"
}, {
	__index = function(self, key)
		if key <= 66 then
			return ("mono %u"):format(key - 2)
		else
			return ("stereo %u/%u"):format(key - 66, key - 65)
		end
	end,
	__len = function(self)
		return 129
	end
})

function takeChannelModeProperty.getValue(item)
	return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_CHANMODE")
end

function takeChannelModeProperty.setValue(item, value)
	reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_CHANMODE", value)
end

function takeChannelModeProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to choose the desired channel mode for active take of selected item.",
		"Adjustable, toggleable")
	if multiSelectionSupport == true then
		message:addType(
			string.format(
				' If the group of items has been selected, the value will enumerate only if selected items have the same value. Otherwise, the channel mode state will be set to "%s", then will enumerate this.'
				, self.states[0]), 1)
	end
	message:addType(" Toggle this property to switch between channel mode categories.", 1)
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the category will define by first selected item take and next category will be switch for selected selected items."
			, 1)
	end
	message { label = "Channel mode" }
	if istable(items) then
		message(composeMultipleTakeMessage(self.getValue, self.states))
	else
		local state = self.getValue(items)
		message { objectId = string.format("%s %s", getItemID(items), getTakeID(items)), value = self.states[state] }
	end
	return message
end

function takeChannelModeProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = direction
	if istable(items) then
		local state = utils.isAllTheSame(items, self.getValue) and ajustingValue or 0
		if ajustingValue ~= 0 then
			state = self.getValue(items[1])
			if (state + ajustingValue) >= 0 and self.states[(state + ajustingValue)] then
				state = state + ajustingValue
			end
		else
			state = 0
		end
		for k = 1, #items do
			self.setValue(items[k], state)
		end
	else
		local state = self.getValue(items)
		if (state + ajustingValue) > #self.states then
			message("No more next property values. ")
		elseif state + ajustingValue < 0 then
			message("No more previous property values. ")
		else
			state = state + ajustingValue
		end
		self.setValue(items, state)
	end
	message(self:get())
	return message
end

function takeChannelModeProperty:set_perform()
	local message = initOutputMessage()
	if istable(items) then
		state = self.getValue(items[1])
		if state >= 0 and state < 5 then
			state = 5
		elseif state >= 5 and state < 67 then
			state = 67
		elseif state >= 67 then
			state = 0
		end
		for k = 1, #items do
			self.setValue(items[k], state)
		end
	else
		local state = self.getValue(items)
		if state >= 0 and state < 5 then
			state = 5
		elseif state >= 5 and state < 67 then
			state = 67
		elseif state >= 67 then
			state = 0
		end
		self.setValue(items, state)
	end
	message(self:get())
	return message
end

-- Take playrate methods
local takePlayrateProperty = {}
parentLayout.takeLayout:registerProperty(takePlayrateProperty)

function takePlayrateProperty.getValue(item)
	return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE")
end

function takePlayrateProperty.setValue(item, value)
	reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE", value)
end

function takePlayrateProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired playrate value for active take of selected item.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the relative of previous value will be applied for each item take of."
			, 1)
	end
	message:addType(" Perform this property to reset  playrate to 1 X for.", 1)
	message { label = "Play rate" }
	if istable(items) then
		message(composeMultipleTakeMessage(self.getValue, representation.playrate))
	else
		local state = self.getValue(items)
		message { objectId = string.format("%s %s", getItemID(items), getTakeID(items)), value = representation.playrate
			[state
			] }
	end
	return message
end

-- I still didn't came up with any algorhythm for encounting the needed step rate, so we will use the REAPER actions.
-- Seems it's the lightest method for all time of :)
function takePlayrateProperty:set_adjust(direction)
	local message = initOutputMessage()
	local cmds = {
		{ [actions.set.decrease.direction] = 40520, [actions.set.increase.direction] = 40519 },
		{ [actions.set.decrease.direction] = 40518, [actions.set.increase.direction] = 40517 }
	}
	reaper.Main_OnCommand(cmds[config.getinteger("rateStep", 1)][direction], 0)
	message(self:get())
	return message
end

takePlayrateProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Take play rate extended interraction")
takePlayrateProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to reset the play rate to original.")
		message(string.format("Reset play rate to %s", representation.playrate[1.0]))
		return message
	end,
	set_perform = function(self, parent)
		reaper.Main_OnCommand(40652, 0)
		local item = nil
		if istable(items) then
			item = items[1]
		else
			item = items
		end
		return true, string.format("Reset to %s", representation.playrate[parent.getValue(item)]), true
	end
}
takePlayrateProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to type a custom play rate value.")
		message("Type custom play rate")
		return message
	end,
	set_perform = function(self, parent)
		if istable(items) then
			local retval, answer = getUserInputs(string.format("Playrate for active takes of %u selected items", #items),
				{ caption = "New playrate value:", defValue = representation.playrate[parent.getValue(items[1])] },
				prepareUserData.rate.formatCaption)
			if not retval then return false end
			for _, item in ipairs(items) do
				local state = parent.getValue(item)
				state = prepareUserData.rate.process(answer, state)
				if state then
					parent.setValue(item, state)
				end
			end
			setUndoLabel(parent:get())
			return true
		else
			local retval, answer = getUserInputs(string.format("Play rate for %s of %s",
					getTakeID(items, true):gsub("^%w", string.lower), getItemID(items, true):gsub("^%w", string.lower)),
				{ caption = "New playrate value:", defValue = representation.playrate[parent.getValue(items)] },
				prepareUserData.rate.formatCaption)
			if retval then
				local state = prepareUserData.rate.process(answer, parent.getValue(items))
				if state then
					parent.setValue(items, state)
					setUndoLabel(parent:get())
					return true
				end
			end
		end
	end
}

-- Preserve pitch when playrate changes methods
local preserveTakePitchProperty = {}
parentLayout.takeLayout:registerProperty(preserveTakePitchProperty)
preserveTakePitchProperty.states = { [0] = "not preserved", [1] = "preserved" }

function preserveTakePitchProperty.getValue(item)
	return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "B_PPITCH")
end

function preserveTakePitchProperty.setValue(item, value)
	reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "B_PPITCH", value)
end

function preserveTakePitchProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to set the switch status of preserving current take pitch when play rate changes of selected item."
		, "Toggleable")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the preserve state will be set to oposite value depending of moreness items with the same value."
			, 1)
	end
	message { label = "pitch when playrate changes" }
	if istable(items) then
		message { label = " for" }
		message(composeMultipleTakeMessage(self.getValue, self.states))
	else
		local state = self.getValue(items)
		message { objectId = string.format("%s %s", getItemID(items), getTakeID(items)), value = self.states[state] }
	end
	return message
end

function preserveTakePitchProperty:set_perform()
	local message = initOutputMessage()
	if istable(items) then
		local ajustingValue = nor(utils.getMostFrequent(items, self.getValue))
		if ajustingValue == 0 then
			message("switching off the preserving for selected items.")
		elseif ajustingValue == 1 then
			message("switching on the preserving for selected items.")
		else
			ajustingValue = 0
			message("switching off the preserving for selected items.")
		end
		for k = 1, #items do
			self.setValue(items[k], ajustingValue)
		end
	else
		self.setValue(items, nor(self.getValue(items)))
	end
	message(self:get())
	return message
end

-- Take pitch methods
local takePitchProperty = {}
parentLayout.takeLayout:registerProperty(takePitchProperty)

function takePitchProperty.getValue(item)
	return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PITCH")
end

function takePitchProperty.setValue(item, value)
	reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PITCH", value)
end

function takePitchProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired pitch value for active take of selected item.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of items has been selected, the relative of previous value will be applied for each item take of."
			, 1)
	end
	message:addType(" Perform this property to specify the pitch value manualy.", 1)
	message { label = "Pitch" }
	if istable(items) then
		message(composeMultipleTakeMessage(self.getValue, representation.pitch))
	else
		local state = self.getValue(items)
		message { objectId = string.format("%s %s", getItemID(items), getTakeID(items)), value = representation.pitch
			[state] }
	end
	return message
end

function takePitchProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = config.getinteger("pitchStep", 1)
	local bounce = config.getinteger("pitchBounces", 24.0)
	if direction == actions.set.decrease.direction then
		ajustingValue = -ajustingValue
	end
	if istable(items) then
		for k = 1, #items do
			local state = self.getValue(items[k])
			if ajustingValue > 0 then
				if state + ajustingValue <= bounce then
					state = state + ajustingValue
				else
					state = bounce
				end
			elseif ajustingValue < 0 then
				if state + ajustingValue >= -bounce then
					state = state + ajustingValue
				else
					state = -bounce
				end
			end
			self.setValue(items[k], state)
		end
	else
		local state = self.getValue(items)
		if state + ajustingValue <= bounce and state + ajustingValue >= -bounce then
			self.setValue(items, state + ajustingValue)
		elseif state + ajustingValue > bounce then
			self.setValue(items, bounce)
			message("No more next property values.")
		elseif state + ajustingValue < -bounce then
			self.setValue(items, -bounce)
			message("No more previous property values.")
		end
	end
	message(self:get())
	return message
end

takePitchProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Pitch extended interraction")
takePitchProperty.extendedProperties:registerProperty(composeThreePositionProperty(
	items,
	{
		representation = representation.pitch,
		min = -config.getinteger("pitchBounces", 24.0),
		rootmean = 0,
		max = config.getinteger("pitchBounces", 24.0)
	},
	{
		[true] = "Set selected items takes to %s. ",
		[false] = "Set to %s. "
	},
	takePitchProperty.setValue
))
takePitchProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to specify a custom pitch value manualy.")
		message("Type custom pitch")
		return message
	end,
	set_perform = function(self, parent)
		if istable(items) then
			local retval, answer = getUserInputs(string.format("Pitch for active takes of %u selected items", #items),
				{
					caption = "New pitch value:",
					defValue = representation.pitch[self.getValue(items[1])]:gsub("Minus ", "-"):gsub(",", "")
				},
				prepareUserData.pitch.formatCaption)
			if not retval then
				return false, "Canceled"
			end
			for k = 1, #items do
				local state = parent.getValue(items[k])
				state = prepareUserData.pitch.process(answer, state)
				if state then
					parent.setValue(items[k], state)
				end
			end
		else
			local state = parent.getValue(items)
			local retval, answer = getUserInputs(string.format("Pitch for %s of %s",
					getTakeID(items, true):gsub("^%w", string.lower), getItemID(items, true):gsub("^%w", string.lower)),
				{ caption = "New pitch value:", defValue = representation.pitch[state]:gsub("Minus ", "-"):gsub(",", "") },
				prepareUserData.pitch.formatCaption)
			if not retval then
				return false, "Canceled"
			end
			state = prepareUserData.pitch.process(answer, state)
			if state then
				parent.setValue(items, state)
			else
				return false
			end
		end
		setUndoLabel(parent:get())
		return true, "", true
	end
}

takePitchProperty.extendedProperties:registerProperty(composeEnvelopeControlProperty.viaCommand(items, "Pitch",
	function(item, envName)
		return reaper.GetTakeEnvelopeByName(reaper.GetActiveTake(item), envName)
	end, 41612))

-- Pitch shifter methods
local takePitchShifterProperty = {}
parentLayout.takeLayout:registerProperty(takePitchShifterProperty)
takePitchShifterProperty.states = setmetatable({ [-1] = "project default" },
	{
		__index = function(self, key)
			if tonumber(key) and key >= 0 then
				key = reaper.BR_Win32_HIWORD(key)
				local retval, name = reaper.EnumPitchShiftModes(key)
				if retval == true then
					return name
				end
			end
			return nil
		end,
		__len = function(self)
			local i = 0
			while ({ reaper.EnumPitchShiftModes(i) })[1] == true do
				i = i + 1
			end
			return i
		end
	})

function takePitchShifterProperty.getValue(item)
	return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_PITCHMODE")
end

function takePitchShifterProperty.setValue(item, value)
	reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_PITCHMODE", value)
end

function takePitchShifterProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to choose the desired pitch shifter (i.e., pitch algorhythm) for active take of selected item.")
	if multiSelectionSupport == true then
		message:addType(
			string.format(
				' If the group of items has been selected, the value will enumerate only if selected items have the same value. Otherwise, the pitch shifter state will be set to "%s", then will enumerate this.'
				, self.states[-1]), 1)
	end
	message { label = "Pitch shifter" }
	if istable(items) then
		message(composeMultipleTakeMessage(self.getValue, self.states))
	else
		local state = self.getValue(items)
		message { objectId = string.format("%s %s", getItemID(items), getTakeID(items)), value = self.states[state] }
	end
	return message
end

function takePitchShifterProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = direction
	if istable(items) then
		local state
		local lastState = self.getValue(items[1])
		for k = 1, #items do
			local state = self.getValue(items[k])
			if lastState ~= state then
				ajustingValue = 0
				break
			end
			lastState = state
		end
		state = self.getValue(items[1])
		if ajustingValue > 0 then
			if state >= 0 then
				for i = reaper.BR_Win32_HIWORD(state) + ajustingValue, #self.states + 1 do
					if self.states[reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state), i)] then
						state = reaper.BR_Win32_MAKELONG(0, i)
						break
					end
				end
			else
				state = reaper.BR_Win32_MAKELONG(0, 0)
			end
		elseif ajustingValue < 0 then
			if state >= 0 then
				for i = reaper.BR_Win32_HIWORD(state) + ajustingValue, -2, -1 do
					if i >= 0 then
						if self.states[reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state), i)] then
							state = reaper.BR_Win32_MAKELONG(0, i)
							break
						end
					else
						if self.states[i] then
							state = i
						end
					end
				end
			end
		elseif ajustingValue == 0 then
			state = -1
		end
		message(string.format("Set selected items active takes pitch shifter to %s.", self.states[state]))
		for k = 1, #items do
			self.setValue(items[k], state)
		end
	else
		local state = self.getValue(items)
		if direction == actions.set.increase.direction then
			if state >= 0 then
				for i = reaper.BR_Win32_HIWORD(state) + ajustingValue, #self.states + 1 do
					if self.states[reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state), i)] then
						state = reaper.BR_Win32_MAKELONG(0, i)
						break
					end
					if i == #self.states then
						message("No more next property values. ")
					end
				end
			else
				state = reaper.BR_Win32_MAKELONG(0, 0)
			end
		elseif direction == actions.set.decrease.direction then
			if state >= 0 then
				for i = reaper.BR_Win32_HIWORD(state) + ajustingValue, -2, -1 do
					if i >= 0 then
						if self.states[reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state), i)] then
							state = reaper.BR_Win32_MAKELONG(0, i)
							break
						end
					else
						if self.states[i] then
							state = i
						end
					end
				end
			else
				message("No more previous property values. ")
			end
		end
		self.setValue(items, state)
	end
	message(self:get())
	return message
end

takePitchShifterProperty.extendedProperties = PropertiesRibbon.initExtendedProperties(
	"Pitch shifter extended properties")

takePitchShifterProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message("Reset to default project shifter")
		message:initType("Perform this property to reset the pitch shifter to project default.")
		if multiSelectionSupport then
			message:addType(" If the group of items has been selected, the project shifter will be set for every take.",
				1)
		end
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		message(string.format("Reset to %s. ", parent.states[-1]))
		if istable(items) then
			for k = 1, #items do
				parent.setValue(items[k], -1)
			end
		else
			parent.setValue(items, -1)
		end
		return true, message, true
	end,
}
takePitchShifterProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message("Search for specified shifter")
		if extstate._layout.query_shifter then
			message(string.format(" (current query %s)", extstate._layout.query_shifter))
		end
		message:initType(
			"Perform this property to set the searching query and find first matching shifter for. Adjust this property to search for matching shifter at next or previous direction.")
		if multiSelectionSupport then
			message:addType(" If the group of items has been selected, the shifter will be set for every take.", 1)
		end
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		local retval, answer = getUserInputs("Search for pitch shifter",
			{
				caption = "Searching pattern:",
				defValue = extstate._layout.query_shifter or
					parent.states[parent.getValue(istable(items) and items[1] or items)],
			}, "Type either the part of shifter name or full name. The Lua patterns are supported.")
		if retval then
			if answer == "" then
				extstate._layout.query_shifter = nil
				return false, "Clearing off the shifter query"
			end
			for i = 0, #parent.states - 1 do
				local shifter = parent.states[reaper.BR_Win32_MAKELONG(0, i)]
				if shifter then
					if utils.simpleSearch(shifter, answer, ";") then
						extstate._layout.query_shifter = answer
						if istable(items) then
							message(string.format("Set the %s shifter for %u selected items", shifter, #items))
							for _, item in ipairs(items) do
								parent.setValue(item, reaper.BR_Win32_MAKELONG(0, i))
							end
						else
							message(string.format("Set the %s shifter for %s of %s", shifter, getTakeID(items),
								getItemID(items)))
							parent.setValue(items, reaper.BR_Win32_MAKELONG(0, i))
						end
						return false, message
					end
				end
			end
			return false, ("No shifter found by query %s."):format(answer)
		end
		return false
	end,
	set_adjust = function(self, parent, direction)
		local message = initOutputMessage()
		local ajustingValue = direction
		local query = extstate._layout.query_shifter
		if not query then return false, "Set the searching query first." end
		if istable(items) then
			local state
			local lastState = parent.getValue(items[1])
			for k = 1, #items do
				local state = parent.getValue(items[k])
				if lastState ~= state then
					ajustingValue = 0
					break
				end
				lastState = state
			end
			state = parent.getValue(items[1])
			if ajustingValue > 0 then
				if state >= 0 then
					for i = reaper.BR_Win32_HIWORD(state) + ajustingValue, #parent.states + 1 do
						if parent.states[reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state), i)] then
							state = reaper.BR_Win32_MAKELONG(0, i)
							break
						end
					end
				else
					state = reaper.BR_Win32_MAKELONG(0, 0)
				end
			elseif ajustingValue < 0 then
				if state >= 0 then
					for i = reaper.BR_Win32_HIWORD(state) + ajustingValue, -2, -1 do
						if i >= 0 then
							if parent.states[reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state), i)] and utils.simpleSearch(parent.states[reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state), i)], query, ";") then
								state = reaper.BR_Win32_MAKELONG(0, i)
								break
							end
						else
							if parent.states[i] then
								state = i
							end
						end
					end
				end
			elseif ajustingValue == 0 then
				state = -1
			end
			message(string.format("Set selected items active takes pitch shifter to %s.", parent.states[state]))
			for k = 1, #items do
				parent.setValue(items[k], state)
			end
		else
			local state = parent.getValue(items)
			if direction == actions.set.increase.direction then
				for i = reaper.BR_Win32_HIWORD(state) + ajustingValue, #parent.states + 1 do
					if parent.states[reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state), i)] and utils.simpleSearch(parent.states[reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state), i)], query) then
						state = reaper.BR_Win32_MAKELONG(0, i)
						break
					end
					if i == #parent.states then
						message(("No more next shifter matched by %s. "):format(query))
					end
				end
			elseif direction == actions.set.decrease.direction then
				for i = reaper.BR_Win32_HIWORD(state) + ajustingValue, -1, -1 do
					if parent.states[reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state), i)] and utils.simpleSearch(parent.states[reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state), i)], query) then
						state = reaper.BR_Win32_MAKELONG(0, i)
						break
					end
					if i == -1 then
						message(("No more previous shifter matched by %s. "):format(query))
					end
				end
			end
			parent.setValue(items, state)
		end
		message(parent:get())
		return false, message
	end
}

-- Active shifter mode methods
local takePitchShifterModeProperty = {}
parentLayout.takeLayout:registerProperty(takePitchShifterModeProperty)
takePitchShifterModeProperty.states = setmetatable({ [-1] = "unavailable" },
	{
		__index = function(self, key)
			key = tonumber(key)
			if key then
				return reaper.EnumPitchShiftSubModes(reaper.BR_Win32_HIWORD(key), reaper.BR_Win32_LOWORD(key))
			end
			return nil
		end
	})

takePitchShifterModeProperty.getValue, takePitchShifterModeProperty.setValue = takePitchShifterProperty.getValue,
	takePitchShifterProperty.setValue


function takePitchShifterModeProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to choose the desired mode for active shifter  of active take on selected item.")
	if multiSelectionSupport == true then
		message:addType(
			string.format(
				" If the group of items has been selected, the value will enumerate only if selected items have the same value. Otherwise, the pitch shifter mode will be set to first setting for this shifter, then will enumerate this. Please note: if one of selected items will has pitch shifter set to %s, the adjusting of this property will not available until selected shifters will not set to any different."
				, takePitchShifterProperty.states[-1]), 1)
	end
	message { label = "Pitch shifter mode" }
	if istable(items) then
		message(composeMultipleTakeMessage(self.getValue, self.states))
	else
		local state = self.getValue(items)
		message { objectId = string.format("%s %s", getItemID(items), getTakeID(items)), value = self.states[state] }
		if state == -1 then
			message:changeType(
				string.format(
					"The Property is unavailable right now, because the shifter has been set to %s. Set the specified shifter before setting it up."
					, takePitchShifterProperty.states[-1]), 1)
			message:changeType("unavailable", 2)
		end
	end
	return message
end

function takePitchShifterModeProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = direction
	if istable(items) then
		local state
		local lastState = self.getValue(items[1])
		for k = 1, #items do
			local state = self.getValue(items[k])
			if state == -1 then
				return string.format(
					"The shifter of take %u %s is set to %s. Set any otherwise  shifter on this take before  setting up the shifter mode."
					, getTakeNumber(items[k]), getItemID(items[k]), takePitchShifterProperty.states[-1])
			end
			if lastState ~= state then
				ajustingValue = 0
				break
			end
			lastState = state
		end
		state = self.getValue(items[1])
		if ajustingValue ~= 0 then
			if direction == actions.set.increase.direction then
				local futureState = reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state) + 1,
					reaper.BR_Win32_HIWORD(state))
				if self.states[futureState] then
					state = futureState
				end
			elseif direction == actions.set.decrease.direction then
				if reaper.BR_Win32_LOWORD(state) - 1 >= 0 then
					state = reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state) - 1, reaper.BR_Win32_HIWORD(state))
				end
			end
		elseif ajustingValue == 0 then
			state = reaper.BR_Win32_MAKELONG(0, reaper.BR_Win32_HIWORD(state))
		end
		message(string.format("Set selected items active takes pitch shifter modes to %s.", self.states[state]))
		for k = 1, #items do
			self.setValue(items[k], state)
		end
	else
		local state = self.getValue(items)
		if state == -1 then
			return string.format(
				"The property is unavailable right now, because the shifter has been set to %s. Set the specified shifter before setting it up."
				, takePitchShifterProperty.states[-1])
		end
		if direction == actions.set.increase.direction then
			local futureState = reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state) + 1, reaper.BR_Win32_HIWORD(state))
			if self.states[futureState] then
				state = futureState
			else
				message("No more next property values. ")
			end
		elseif direction == actions.set.decrease.direction then
			if reaper.BR_Win32_LOWORD(state) - 1 >= 0 then
				state = reaper.BR_Win32_MAKELONG(reaper.BR_Win32_LOWORD(state) - 1, reaper.BR_Win32_HIWORD(state))
			else
				message("No more previous property values. ")
			end
		end
		self.setValue(items, state)
	end
	message(self:get())
	return message
end

local takeStretchModeProperty = parentLayout.takeLayout:registerProperty {}
takeStretchModeProperty.states = {
	[0] = "Project default",
	[1] = "Balanced",
	[2] = "Tonal optimized",
	[4] = "Transient optimized",
	[5] = "No pre-echo reduction"
}

function takeStretchModeProperty.getValue(item)
	return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_STRETCHFLAGS")
end

function takeStretchModeProperty.setValue(item, value)
	reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_STRETCHFLAGS", value)
end

function takeStretchModeProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to choose the needed stretch mode.")
	if multiSelectionSupport == true then
		message:addType(
			string.format(
				' If the group of items has been selected, the value will enumerate only if takes of selected items have the same value. Otherwise, the stretch mode state will be set to "%s", then will enumerate this.'
				, self.states[0]), 1)
	end
	message:addType(string.format(" Perform this property to reset the mode to %s.", self.states[0]), 1)
	message { label = "Stretch mode" }
	if istable(items) then
		message(composeMultipleTakeMessage(self.getValue, self.states))
	else
		local state = self.getValue(items)
		message { objectId = string.format("%s %s", getItemID(items), getTakeID(items)), value = self.states[state] }
	end
	return message
end

function takeStretchModeProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = direction
	if istable(items) then
		local state
		local lastState = self.getValue(items[1])
		for k = 1, #items do
			local state = self.getValue(items[k])
			if lastState ~= state then
				ajustingValue = 0
				break
			end
			lastState = state
		end
		state = self.getValue(items[1])
		if ajustingValue ~= 0 then
			local maybeState = nil
			for i = (state + direction), direction == actions.set.increase.direction and #self.states or 0, direction do
				if self.states[i] then
					maybeState = i
					break
				end
			end
			if maybeState then
				state = maybeState
			else
				message(string.format("No more %s property values.",
					direction == actions.set.increase.direction and "next" or "previous"))
			end
		else
			state = 0
		end
		message(string.format("Set selected items active takes stretch mode to %s.", self.states[state]))
		for k = 1, #items do
			self.setValue(items[k], state)
		end
	else
		local state = self.getValue(items)
		local maybeState = nil
		for i = (state + direction), direction == actions.set.increase.direction and #self.states or 0, direction do
			if self.states[i] then
				maybeState = i
				break
			end
		end
		if maybeState then
			state = maybeState
		else
			message(string.format("No more %s property values.",
				direction == actions.set.increase.direction and "next" or "previous"))
		end
		self.setValue(items, state)
	end

	message(self:get())
	return message
end

function takeStretchModeProperty:set_perform()
	local message = initOutputMessage()
	if istable(items) then
		message(string.format("Set stretch mode for takes of selected items to %s", self.states[0]))
		for k = 1, #items do
			self.setValue(items[k], 0)
		end
	else
		message(string.format("Reset to %s.", self.states[0]))
		self.setValue(items, 0)
	end
	message(self:get())
	return message
end

local contextMenuProperty = parentLayout.managementLayout:registerProperty {}

function contextMenuProperty:get()
	local message = initOutputMessage()
	message:initType("Perform this property to open the context menu for selected items.")
	if istable(items) then
		message(string.format("Context menu for %u selected items", #items))
	else
		message {
			objectId = getItemID(items),
			label = "Context menu"
		}
	end
	return message
end

function contextMenuProperty:set_perform()
	reaper.Main_OnCommand(reaper.NamedCommandLookup("_OSARA_CONTEXTMENU1"), 0)
end

parentLayout.defaultSublayout = "itemLayout"

PropertiesRibbon.presentLayout(parentLayout)
