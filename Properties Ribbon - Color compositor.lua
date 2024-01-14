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

useMacros "color_presets"

-- This layout should have the self-providing service methods

local function getColorIndex(section)
	return extstate._layout[utils.makeKeySequence(section, "colorIndex")]
end

local function getPresetIndex(section)
	return extstate._layout[utils.makeKeySequence(section, "presetIndex")]
end

local function setColorIndex(section, value)
	extstate._layout[utils.makeKeySequence(section, "colorIndex")] = value
end

local function setPresetIndex(section, value)
	extstate._layout[utils.makeKeySequence(section, "presetIndex")] = value
end

local function getFilter(section)
	return extstate._layout[utils.makeKeySequence(section, "colorFilter")]
end

local function getColor(section)
	return extstate._layout[utils.makeKeySequence(section, "curValue")] or reaper.ColorToNative(0, 0, 0)
end

local function setFilter(section, filter)
	extstate._layout[utils.makeKeySequence(section, "colorFilter")] = filter
end

local function setColor(section, color)
	extstate._layout[utils.makeKeySequence(section, "curValue")] = color
end

-- global pseudoclass initialization
local parentLayout = initLayout("Color composer")

parentLayout.undoContext = undo.contexts.tracks | undo.contexts.items | undo.contexts.project

-- sublayouts
-- Track properties
parentLayout:registerSublayout("track", "Tracks")

-- Item properties
parentLayout:registerSublayout("item", " Items")

-- Take sublayout
parentLayout:registerSublayout("take", "Item takes")

-- Markers
parentLayout:registerSublayout("marker", "Markers")

-- Regions
parentLayout:registerSublayout("region", "Regions")

-- The creating new property macros
-- Here a special case, so we will not  use the native layout's methods as is
local function registerProperty(property)
	for curClass, _ in pairs(parentLayout) do
		if isSublayout(parentLayout[curClass]) then
			local newProperty = parentLayout[curClass]:registerProperty(table.deepcopy(property))
			newProperty.objName = curClass
		end
	end
end

-- presets methods
local presetsProperty = {}

function presetsProperty:getValue()
	return getPresetIndex(self.objName)
end

function presetsProperty:setValue(value)
	setPresetIndex(self.objName, value)
end

function presetsProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to choose desired preset created at the past.")
	local presets = colorPresets.init(self.objName)
	message {
		objectId = "Color",
		label = "Preset"
	}
	if #presets > 0 then
		if self:getValue() then
			message {
				value = presets[self:getValue()].name
			}
		else
			message {
				value = "Not selected"
			}
		end
	else
		message {
			value = "empty"
		}
	end
	return message
end

function presetsProperty:set_adjust(direction)
	local message = initOutputMessage()
	local presets = colorPresets.init(self.objName)
	local state = self:getValue() or 1
	if (state + direction) > #presets then
		message("No more next property values. ")
	elseif (state + direction) <= 0 then
		message("No more previous property values. ")
	else
		state = state + direction
	end
	self:setValue(state)
	state = self:getValue()
	if #presets > 0 then
		setColor(self.objName, presets[state].value)
		setColorIndex(self.objName, colors:getColorID(reaper.ColorFromNative(getColor(self.objName))))
	end
	message(self:get())
	return message
end

presetsProperty.extendedProperties = initExtendedProperties("Preset context actions")

presetsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message "Create new preset"
		message:initType("Perform this property to create new preset based on current color value.")
		return message
	end,
	set_perform = function(self, parent)
		local presets = colorPresets.init(parent.objName)
		local retval, answer = getUserInputs("Create new preset", {
			caption = "New preset name:"
		})
		if retval then
			if answer then
				local exists = false
				for _, preset in ipairs(presets) do
					if preset.name == answer then
						exists = true
						break
					end
				end
				if not exists then
					table.insert(presets, {
						name = answer,
						value = getColor(parent.objName)
					})
					setPresetIndex(parent.objName, #presets)
				else
					reaper.ShowMessageBox(string.format("The preset with name\"%s\" already exists.", answer),
						"Creation error",
						showMessageBoxConsts.sets.ok)
					return false
				end
			else
				reaper.ShowMessageBox("The preset name cannot be empty.", "Preset creation error",
					showMessageBoxConsts.sets.ok)
				return false
			end
		end
		return true
	end
}
presetsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message "Rename preset"
		message:initType("Perform this property to rename currently selected preset.")
		if #colorPresets.init(parent.objName) == 0 and not getPresetIndex(parent.objName) then
			message:addType(" This property is currently unavailable because no preset selected.", 1)
			message:changeType("Unavailable", 2)
		end
		return message
	end,
	set_perform = function(self, parent)
		local presets = colorPresets.init(parent.objName)
		if #presets == 0 and not getPresetIndex(parent.objName) then
			return false, "Select a preset first"
		end
		local preset = presets[parent:getValue()]
		local retval, answer = getUserInputs("Rename preset", {
			caption = "New preset name:",
			defValue = preset.name
		})
		if retval then
			if answer then
				preset.name = answer
				presets[parent:getValue()] = preset
			else
				reaper.ShowMessageBox("The preset name cannot be empty.", "Preset creation error",
					showMessageBoxConsts.sets.ok)
				return false
			end
		end
		return true
	end
}
presetsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message "Update this preset color"
		message:initType("Perform this property to update the color of selected preset.")
		if #colorPresets.init(parent.objName) == 0 and not getPresetIndex(parent.objName) then
			message:addType(" This property is currently unavailable because no preset selected.", 1)
			message:changeType("Unavailable", 2)
		end
		return message
	end,
	set_perform = function(self, parent)
		local presets = colorPresets.init(parent.objName)
		if #presets == 0 and not getPresetIndex(parent.objName) then
			return false, "Select a preset first"
		end
		local message = initOutputMessage()
		local preset = presets[parent:getValue()]
		preset.value = getColor(parent.objName)
		presets[parent:getValue()] = preset
		message {
			label = parent:get():extract(2, false),
			value = "Updated"
		}
		return true, message, true
	end
}
presetsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message "Delete selected preset"
		message:initType("Perform this property to delete selected preset.")
		if #colorPresets.init(parent.objName) == 0 and not getPresetIndex(parent.objName) then
			message:addType(" This property is currently unavailable because no preset selected.", 1)
			message:changeType("Unavailable", 2)
		end
		return message
	end,
	set_perform = function(self, parent)
		local presets = colorPresets.init(parent.objName)
		if #presets == 0 and not getPresetIndex(parent.objName) then
			return false, "Select a preset first"
		end
		local preset = presets[parent:getValue()]
		if reaper.ShowMessageBox(string.format("Are you sure you want to delete the preset \"%s\"?", preset.name),
				"Confirm preset deletion", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
			presets[parent:getValue()] = nil
			if parent:getValue() - 1 > 0 then
				parent:setValue(parent:getValue() - 1)
			else
				parent:setValue(nil)
			end
			return true
		end
		return false
	end
}
registerProperty(presetsProperty)

-- Color shade methods
local shadeProperty = {}

function shadeProperty:getValue()
	return getColorIndex(self.objName)
end

function shadeProperty:setValue(value)
	setColorIndex(self.objName, value)
end

function shadeProperty:get()
	local message = initOutputMessage()
	message:initType(string.format(
		"Adjust this property to choose desired color from list of %u values. Perform this property to set the filter for quick search needed color",
		#colors.colorList))
	message { label = "Color" }
	local state = self:getValue()
	if state and state > 0 then
		message { value = colors.colorList[self:getValue()].name }
	else
		message { value = "Not selected" }
	end
	local filter = getFilter(self.objName)
	if filter then
		message { value = string.format(", filter set to %s", filter) }
	end
	return message
end

function shadeProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = self:getValue() or 0
	local filter = getFilter(self.objName)
	if direction == actions.set.increase.direction then
		if filter then
			local somethingFound = false
			for i = (state + 1), #colors.colorList do
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
			if (state + 1) <= #colors.colorList then
				state = state + 1
			else
				message("No more next property values. ")
			end
		end
	elseif direction == actions.set.decrease.direction then
		if filter then
			local somethingFound = false
			for i = (state - 1), 1, -1 do
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
			if (state - 1) > 0 then
				state = state - 1
			else
				message("No more previous property values. ")
			end
		end
	end
	self:setValue(state)
	local c = colors.colorList[state]
	setColor(self.objName,
		reaper.ColorToNative(c.r, c.g, c.b))
	-- Here is old method because we do not want to report the filter superfluously
	message(self:get())
	message.value = colors.colorList[self:getValue()].name
	return message
end

function shadeProperty:set_perform()
	local message = initOutputMessage()
	local state = self:getValue()
	local filter = getFilter(self.objName)
	local retval, answer = getUserInputs("Set filter", {
			caption = "Filter query:",
			defValue = filter
		},
		'Type a part of color name that Properties Ribbon should search. Clear the edit field to clear the filter and explore all colors.')
	if retval == true then
		setFilter(self.objName, answer:lower())
		local filter = getFilter(self.objName)
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
	self:setValue(state)
	setColor(self.objName,
		reaper.ColorToNative(colors.colorList[state].r, colors.colorList[state].g, colors.colorList[state].b))
	message(self:get())
	message.value = colors.colorList[self:getValue()].name
	return message
end

registerProperty(shadeProperty)

-- The R value methods
local rgbRProperty = {}

function rgbRProperty:getValue()
	return select(1, reaper.ColorFromNative(getColor(self.objName)))
end

function rgbRProperty:setValue(value)
	local r, g, b = reaper.ColorFromNative(getColor(self.objName))
	setColor(self.objName, reaper.ColorToNative(value, g, b))
end

function rgbRProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to find nearest  red shade intensity value which belongs to different color.")
	message {
		objectId = "Color",
		label = "Red intensity",
		value = self:getValue()
	}
	return message
end

function rgbRProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = self:getValue()
	if direction == actions.set.increase.direction then
		if state + 1 <= 255 then
			local oldName = colors:getName(reaper.ColorFromNative(getColor(self.objName)))
			for i = (state + 1), 255 do
				self:setValue(i)
				local newName = colors:getName(reaper.ColorFromNative(getColor(self.objName)))
				if oldName ~= newName then
					break
				end
			end
		else
			message("No more next property values. ")
		end
	elseif direction == actions.set.decrease.direction then
		if state - 1 >= 0 then
			local oldName = colors:getName(reaper.ColorFromNative(getColor(self.objName)))
			for i = (state - 1), 0, -1 do
				if i >= 0 then
					self:setValue(i)
					local newName = colors:getName(reaper.ColorFromNative(getColor(self.objName)))
					if oldName ~= newName then
						break
					end
				end
			end
		else
			message("No more previous property values. ")
		end
	end
	setColorIndex(self.objName, colors:getColorID(reaper.ColorFromNative(getColor(self.objName))))
	message {
		objectId = "Color",
		label = "Red intensity",
		value = string.format("%u, closest color is %s", self:getValue(), colors:getName(reaper.ColorFromNative(getColor(self.objName))))
	}
	return message
end

function rgbRProperty:set_perform()
	local message = initOutputMessage()
	local label = self:get().label
	local state = self:getValue()
	local retval, answer = getUserInputs(string.format("%s input", label), {
		caption = string.format('Type the %s (0...255):', label),
		defValue = state
	})
	if retval == true then
		if tonumber(answer) then
			self:setValue(tonumber(answer))
		else
			message(("The provided %s value is not a number value. "):format(label))
		end
	end
	setColorIndex(self.objName, colors:getColorID(reaper.ColorFromNative(getColor(self.objName))))
	message(self:get())
	message { value = string.format(", closest color is %s", colors:getName(reaper.ColorFromNative(getColor(self.objName)))) }
	return message
end

registerProperty(rgbRProperty)

-- The g methods
local rgbGProperty = {}

function rgbGProperty:getValue()
	return select(2, reaper.ColorFromNative(getColor(self.objName)))
end

function rgbGProperty:setValue(value)
	local r, g, b = reaper.ColorFromNative(getColor(self.objName))
	setColor(self.objName, reaper.ColorToNative(r, value, b))
end

function rgbGProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to find nearest  blue shade intensity value which belongs to different color.")
	message {
		objectId = "Color",
		label = "Green intensity",
		value = self:getValue()
	}
	return message
end

rgbGProperty.set_adjust = rgbRProperty.set_adjust
rgbGProperty.set_perform = rgbRProperty.set_perform

registerProperty(rgbGProperty)

-- The B methods
local rgbBProperty = {}

function rgbBProperty:getValue()
	return select(3, reaper.ColorFromNative(getColor(self.objName)))
end

function rgbBProperty:setValue(value)
	local r, g, b = reaper.ColorFromNative(getColor(self.objName))
	setColor(self.objName, reaper.ColorToNative(r, g, value))
end

function rgbBProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to find nearest  blue shade intensity value which belongs to different color.")
	message {
		objectId = "Color", label = "Blue intensity", value = self:getValue()
	}
	return message
end

rgbBProperty.set_adjust = rgbRProperty.set_adjust
rgbBProperty.set_perform = rgbRProperty.set_perform

registerProperty(rgbBProperty)

-- Apply the cosen color methods
local applyColorProperty = {}
applyColorProperty.states = setmetatable({
	["marker"] = "marker near cursor",
	["region"] = "region near cursor"
}, {
	__index = function(self, key)
		if key == "track" then
			useMacros "track_properties"
			local tracks = track_properties_macros.getTracks(multiSelectionSupport)
			if istable(tracks) then
				return string.format("%u selected tracks", #tracks)
			elseif isuserdata(tracks) then
				return track_properties_macros.getTrackID(tracks, true)
			end
		elseif key == "item" then
			useMacros "item_properties"
			local items = item_properties_macros.getItems(multiSelectionSupport)
			if istable(items) then
				return string.format("%u selected items", #items)
			elseif isuserdata(items) then
				return item_properties_macros.getItemID(items, true)
			end
		elseif key == "take" then
			useMacros "item_properties"
			local items = item_properties_macros.getItems(multiSelectionSupport)
			if istable(items) then
				return string.format("%u active takes in selected items", #items)
			elseif isuserdata(items) then
				return item_properties_macros.getTakeID(items, true)
			end
		end
	end
})

applyColorProperty.setValue = {
	track = function(value)
		local tracks = track_properties_macros.getTracks(multiSelectionSupport)
		if istable(tracks) then
			for _, track in ipairs(tracks) do
				reaper.SetTrackColor(track, value)
			end
			return true
		elseif isuserdata(tracks) then
			reaper.SetTrackColor(tracks, value)
			return true
		end
	end,
	item = function(value)
		local items = item_properties_macros.getItems(multiSelectionSupport)
		if istable(items) then
			for _, item in ipairs(items) do
				reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", value | 0x100000)
			end
			return true
		elseif isuserdata(items) then
			reaper.SetMediaItemInfo_Value(items, "I_CUSTOMCOLOR", value | 0x100000)
			return true
		end
	end,
	take = function(value)
		local items = item_properties_macros.getItems(multiSelectionSupport)
		if istable(items) then
			for _, item in ipairs(items) do
				reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_CUSTOMCOLOR", value | 0x100000)
			end
			return true
		elseif isuserdata(items) then
			reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(items), "I_CUSTOMCOLOR", value | 0x100000)
			return true
		end
	end,
	marker = function(value)
		local markeridx, _ = reaper.GetLastMarkerAndCurRegion(0, reaper.GetCursorPosition())
		if markeridx then
			local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, markeridx)
			reaper.SetProjectMarker4(0, markrgnindexnumber, false, pos, 0, name, value | 0x1000000, 0)
			return true
		end
	end,
	region = function(value)
		local _, regionidx = reaper.GetLastMarkerAndCurRegion(0, reaper.GetCursorPosition())
		if regionidx then
			local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, regionidx)
			reaper.SetProjectMarker4(0, markrgnindexnumber, true, pos, rgnend, name, value | 0x1000000, 0)
			return true
		end
	end
}


function applyColorProperty:get()
	local message = initOutputMessage()
	message:initType(string.format("Perform this property to apply composed color to %s.", ({
		track = "last touched track",
		item = "first selected item",
		take = "active take of first selected item"
	})[self.objName]))
	local gotState = self.states[self.objName]
	message(string.format("Apply %s color", colors:getName(reaper.ColorFromNative(getColor(self.objName)))))
	if gotState then
		message(string.format(" to %s", gotState))
	else
		message:addType(" This property is unavailable right now because no one object is selected.", 1)
		message:changeType("Unavailable", 2)
	end
	return message
end

function applyColorProperty:set_perform()
	local gotState = self.states[self.objName]
	if gotState then
		local message = initOutputMessage()
		local result = self.setValue[self.objName](getColor(self.objName))
		if result then
			message(string.format("%s colorized to %s color.", self.states[self.objName],
				colors:getName(reaper.ColorFromNative(getColor(self.objName)))))
		else
			message(string.format("Could not colorize any %s.", self.states[self.objName]))
		end
		return message
	end
	return "This properti is unavailable right now cuz no one object is selected."
end

registerProperty(applyColorProperty)

-- Grabbing a color from an elements methods
local grabColorProperty = {}
grabColorProperty.states = applyColorProperty.states

grabColorProperty.getValue = {
	track  = function()
		useMacros "track_properties"
		local track = track_properties_macros.getTracks(false)
		if track then
			return reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")
		end
		return nil
	end,
	item   = function()
		useMacros "item_properties"
		local item = item_properties_macros.getItems(false)
		if item then
			return reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
		end
		return nil
	end,
	take   = function()
		useMacros "item_properties"
		local item = item_properties_macros.getItems(false)
		if item then
			return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_CUSTOMCOLOR")
		end
		return nil
	end,
	marker = function()
		useMacros "markers_regions_selection_macros"
		local markeridx, _ = reaper.GetLastMarkerAndCurRegion(0, reaper.GetCursorPosition())
		if markeridx then
			local _, _, _, _, _, _, color = reaper.EnumProjectMarkers3(0, markeridx)
			return color
		end
		return nil
	end,
	region = function()
		useMacros "markers_regions_selection_macros"
		local _, regionidx = reaper.GetLastMarkerAndCurRegion(0, reaper.GetCursorPosition())
		if regionidx then
			local _, _, _, _, _, _, color = reaper.EnumProjectMarkers3(0, regionidx)
			return color
		end
		return nil
	end
}

function grabColorProperty:setValue(value)
	setColor(self.objName, value)
	setColorIndex(self.objName, colors:getColorID(reaper.ColorFromNative(getColor(self.objName))))
end

function grabColorProperty:get()
	local message = initOutputMessage()
	message:initType(string.format(
		"Perform this property to grab a color from %s. This color will be coppied to this category of color composition layout for following performances.",
		({
			track = "last touched track",
			item = "first selected item",
			take = "active take of first selected item"
		})[self.objName]))
	message("Grab a color")
	if self.getValue[self.objName]() then
		message(string.format(" from %s", self.states[self.objName]))
	else
		message:addType(" This property unavailable right now because no one element has been selected.", 1)
		message:changeType("unavailable", 2)
	end
	return message
end

function grabColorProperty:set_perform()
	local message = initOutputMessage()
	local state = self.getValue[self.objName]()
	if not state then
		return
		"This property is unavailable right now because no one element of this category has been neither touched nor selected."
	end
	self:setValue(state)
	message(string.format("The %s color has been grabbed from %s.", colors:getName(reaper.ColorFromNative(state)),
		self.states[self.objName]))
	return message
end

registerProperty(grabColorProperty)

PropertiesRibbon.presentLayout(parentLayout)
