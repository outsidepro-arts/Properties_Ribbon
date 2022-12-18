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

-- Some needfull configs
local multiSelectionSupport = config.getboolean("multiSelectionSupport", true)

-- This layout needs the properties macros
useMacros("properties")

-- This layout should define current context
local sublayout = nil
if currentSublayout then
	sublayout = currentSublayout
else
	local context = reaper.GetCursorContext()
	if context == 0 then
		sublayout = "track"
	elseif context == 1 then
		sublayout = "item"
	else
		sublayout = "track"
	end
end

-- This layout should have the self-providing service methods

local function getPresets()
	local presets = setmetatable({}, {
		__index = function(self, idx)
			if isnumber(idx) then
				local name, value = extstate._layout[utils.makeKeySequence(sublayout, string.format("preset%u", idx), "name")], extstate._layout[utils.makeKeySequence(sublayout, string.format("preset%u", idx), "value")]
				if name and value then
					return {
						name = name,
						value = value
					}
				end
			end
		end,
		__newindex = function (self, idx, preset)
			if preset then
				extstate._layout._forever[utils.makeKeySequence(sublayout, string.format("preset%u", idx), "name")] = assert(preset.name, "Expected table field 'name'")
				extstate._layout._forever[utils.makeKeySequence(sublayout, string.format("preset%u", idx), "value")] = assert(preset.value, "Expected table field 'value'")
			else
				local i = idx
				while extstate._layout[utils.makeKeySequence(sublayout, string.format("preset%u", i), "value")] do
					if i == idx then
						extstate._layout._forever[utils.makeKeySequence(sublayout, string.format("preset%u", i), "name")] = nil
						extstate._layout._forever[utils.makeKeySequence(sublayout, string.format("preset%u", i), "value")] = nil
					elseif i > idx then
						extstate._layout._forever[utils.makeKeySequence(sublayout, string.format("preset%u", i - 1), "name")] = extstate._layout[utils.makeKeySequence(sublayout, string.format("preset%u", i), "name")]
						extstate._layout._forever[utils.makeKeySequence(sublayout, string.format("preset%u", i), "name")] = nil
						extstate._layout._forever[utils.makeKeySequence(sublayout, string.format("preset%u", i - 1), "value")] = extstate._layout[utils.makeKeySequence(sublayout, string.format("preset%u", i), "value")]
						extstate._layout._forever[utils.makeKeySequence(sublayout, string.format("preset%u", i), "value")] = nil
					end
					i = i + 1
				end
			end
		end,
		__len = function (self)
			local mCount = 0
			while extstate._layout[utils.makeKeySequence(sublayout, string.format("preset%u", mCount + 1), "value")] and extstate._layout[utils.makeKeySequence(sublayout, string.format("preset%u", mCount + 1), "name")] do
				mCount = mCount + 1
			end
			return mCount
		end,
		__ipairs = function (self)
			local lambda = function (obj, idx)
				if extstate._layout[utils.makeKeySequence(sublayout, string.format("preset%u", idx+1), "name")] and extstate._layout[utils.makeKeySequence(sublayout, string.format("preset%u", idx + 1), "value")] then
					return idx + 1, {
						name = extstate._layout[utils.makeKeySequence(sublayout, string.format("preset%u", idx + 1), "name")],
						value = extstate._layout[utils.makeKeySequence(sublayout, string.format("preset%u", idx + 1), "value")]
					}
				end
			end
			return self, lambda, 1
		end
	})
	return presets
end

local function getColorIndex()
	return extstate._layout[utils.makeKeySequence(sublayout, "colorIndex")]
end

local function getPresetIndex()
	return extstate._layout[utils.makeKeySequence(sublayout, "presetIndex")]
end

local function setColorIndex(value)
	extstate._layout[utils.makeKeySequence(sublayout, "colorIndex")] = value
end

local function setPresetIndex(value)
	extstate._layout[utils.makeKeySequence(sublayout, "presetIndex")] = value
end

local function getFilter()
	return extstate._layout[utils.makeKeySequence(sublayout, "colorFilter")]
end

local function getColor()
	return extstate._layout[utils.makeKeySequence(sublayout, "curValue")] or reaper.ColorToNative(0, 0, 0)
end

local function setFilter(filter)
	extstate._layout[utils.makeKeySequence(sublayout, "colorFilter")] = filter
end

local function setColor(color)
	extstate._layout[utils.makeKeySequence(sublayout, "curValue")] = color
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
		if istable(parentLayout[curClass]) then
			parentLayout[curClass]:registerProperty(property)
		end
	end
end

-- presets methods
local presetsProperty = {}
registerProperty(presetsProperty)
presetsProperty.states = getPresets()

function presetsProperty.getValue()
	return getPresetIndex()
end

function presetsProperty.setValue(value)
	setPresetIndex(value)
end

function presetsProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to choose desired preset created at the past.")
	message { objectId = "Color", label = "Preset" }
	if #self.states > 0 then
		if self.getValue() then
			message { value = self.states[self.getValue()].name }
		else
			message{ value = "Not selected" }
		end
	else
		message { value = "empty" }
	end
	return message
end

function presetsProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = self.getValue() or 1
	if (state + direction) > #self.states then
		message("No more next property values. ")
	elseif (state + direction) <= 0 then
		message("No more previous property values. ")
	else
		state = state + direction
	end
	self.setValue(state)
	state = self.getValue()
	if #self.states > 0 then
		setColor(self.states[state].value)
		setColorIndex(colors:getColorID(reaper.ColorFromNative(getColor())))
	end
	message(self:get())
	return message
end

presetsProperty.extendedProperties = initExtendedProperties("Preset context actions")

presetsProperty.extendedProperties:registerProperty{
	get = function (self, parent)
		local message = initOutputMessage()
		message "Create new preset"
		message:initType("Perform this property to create new preset based on current color value.")
		return message
	end,
	set_perform = function (self, parent)
		local retval, answer = reaper.GetUserInputs("Create new preset", 1, "Type a name for new preset:", "")
		if retval then
			if answer then
				local exists = false
				for _, preset in ipairs(parent.states) do
					if preset.name == answer then
						exists = true
						break
					end
				end
				if not exists then
					table.insert(parent.states, {
						name = answer,
						value = getColor()
					})
					setPresetIndex(#parent.states)
				else
					reaper.ShowMessageBox(string.format("The preset with name\"%s\" already exists.", answer), "Creation error", showMessageBoxConsts.sets.ok)
					return false
				end
			else
				reaper.ShowMessageBox("The preset name cannot be empty.", "Preset creation error", showMessageBoxConsts.sets.ok)
				return false
			end
		end
		return true
	end
}
if presetsProperty.states[getPresetIndex()] then
	presetsProperty.extendedProperties:registerProperty{
		get = function (self, parent)
			local message = initOutputMessage()
			message "Rename preset"
			message:initType("Perform this property to rename currently selected preset.")
			return message
		end,
		set_perform = function (self, parent)
			local preset = parent.states[parent.getValue()]
			local retval, answer = reaper.GetUserInputs("Rename preset", 1, "Type new preset name:", preset.name)
			if retval then
				if answer then
					preset.name = answer
					parent.states[parent.getValue()] = preset
				else
					reaper.ShowMessageBox("The preset name cannot be empty.", "Preset creation error", showMessageBoxConsts.sets.ok)
					return false
				end
			end
			return true
		end
	}
	presetsProperty.extendedProperties:registerProperty{
		get = function (self, parent)
			local message = initOutputMessage()
			message "Update this preset color"
			message:initType("Perform this property to update the color of selected preset.")
			return message
		end,
		set_perform = function (self, parent)
			local message = initOutputMessage()
			local preset = parent.states[parent.getValue()]
			preset.value = getColor()
			parent.states[parent.getValue()] = preset
			message{ label = parent:get():extract(2, false), value = "Updated" }
			return true, message, true
		end
	}
	presetsProperty.extendedProperties:registerProperty{
		get = function (self, parent)
			local message = initOutputMessage()
			message "Delete selected preset"
			message:initType("Perform this property to delete selected preset.")
			return message
		end,
		set_perform = function (self, parent)
			local preset = parent.states[parent.getValue()]
			if reaper.ShowMessageBox(string.format("Are you sure you want to delete the preset \"%s\"?", preset.name), "Confirm preset deletion", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
				parent.states[parent.getValue()] = nil
				if parent.getValue()-1 > 0 then
					parent.setValue(parent.getValue()-1)
				else
					parent.setValue(nil)
				end
				return true
			end
			return false
		end
	}
end

-- Color shade methods
local shadeProperty = {}
registerProperty(shadeProperty)

function shadeProperty.getValue()
	return getColorIndex()
end

function shadeProperty.setValue(value)
	setColorIndex(value)
end

function shadeProperty:get()
	local message = initOutputMessage()
	message:initType(string.format("Adjust this property to choose desired color from list of %u values. Perform this property to set the filter for quick search needed color"
		, #colors.colorList))
	if getColorIndex() then
		message(string.format("Color %s", colors.colorList[self.getValue()].name))
	else
		message("Color not selected")
	end
	local filter = getFilter()
	if filter then
		message(string.format(", filter set to %s", filter))
	end
	return message
end

function shadeProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = self.getValue() or 0
	local filter = getFilter()
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
	self.setValue(state)
	setColor(reaper.ColorToNative(colors.colorList[state].r, colors.colorList[state].g, colors.colorList[state].b))
	-- Here is old method because we do not want to report the filter superfluously
	message { label = "Color", value = colors.colorList[self.getValue()].name }
	return message
end

function shadeProperty:set_perform()
	local message = initOutputMessage()
	local state = self.getValue()
	local filter = getFilter() or ""
	local retval, answer = reaper.GetUserInputs("Set filter", 1,
		'Type a part of color name that Properties Ribbon should search.\nClear the edit field to clear the filter and explore all colors.'
		, filter)
	if retval == true then
		setFilter(answer:lower())
		local filter = getFilter()
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
	self.setValue(state)
	setColor(reaper.ColorToNative(colors.colorList[state].r, colors.colorList[state].g, colors.colorList[state].b))
	-- Here is old method because we do not want to report the filter superfluously
	message { label = "Color", value = colors.colorList[self.getValue()].name }
	return message
end

-- The R value methods
local rgbRProperty = {}
registerProperty(rgbRProperty)

function rgbRProperty.getValue()
	local r = reaper.ColorFromNative(getColor())
	return r
end

function rgbRProperty.setValue(value)
	local r, g, b = reaper.ColorFromNative(getColor())
	r = value
	setColor(reaper.ColorToNative(r, g, b))
end

function rgbRProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to find nearest  red shade intensity value which belongs to different color.")
	message(string.format("Color red intensity %u", self.getValue()))
	return message
end

function rgbRProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = self.getValue()
	if direction == actions.set.increase.direction then
		if state + 1 <= 255 then
			local oldName = colors:getName(reaper.ColorFromNative(getColor()))
			for i = (state + 1), 255 do
				self.setValue(i)
				local newName = colors:getName(reaper.ColorFromNative(getColor()))
				if oldName ~= newName then
					break
				end
			end
		else
			message("No more next property values. ")
		end
	elseif direction == actions.set.decrease.direction then
		if state - 1 >= 0 then
			local oldName = colors:getName(reaper.ColorFromNative(getColor()))
			for i = (state - 1), 0, -1 do
				if i >= 0 then
					self.setValue(i)
					local newName = colors:getName(reaper.ColorFromNative(getColor()))
					if oldName ~= newName then
						break
					end
				end
			end
		else
			message("No more previous property values. ")
		end
	end
	setColorIndex(colors:getColorID(reaper.ColorFromNative(getColor())))
	message { objectId = "Color", label = "Red intensity",
		value = string.format("%u, closest color is %s", self.getValue(), colors:getName(reaper.ColorFromNative(getColor()))) }
	return message
end

function rgbRProperty:set_perform()
	local message = initOutputMessage()
	local state = self.getValue()
	local retval, answer = reaper.GetUserInputs("Red value input", 1, 'Type the red value intensity (0...255):', state)
	if retval == true then
		if tonumber(answer) then
			self.setValue(tonumber(answer))
		else
			message("The provided red color value is not a number value. ")
		end
	end
	setColorIndex(colors:getColorID(reaper.ColorFromNative(getColor())))
	message { objectId = "Color", label = "Red intensity",
		value = string.format("%u, closest color is %s", self.getValue(), colors:getName(reaper.ColorFromNative(getColor()))) }
	return message
end

-- The g methods
local rgbGProperty = {}
registerProperty(rgbGProperty)

function rgbGProperty.getValue()
	local _, g = reaper.ColorFromNative(getColor())
	return g
end

function rgbGProperty.setValue(value)
	local r, g, b = reaper.ColorFromNative(getColor())
	g = value
	setColor(reaper.ColorToNative(r, g, b))
end

function rgbGProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to find nearest  blue shade intensity value which belongs to different color.")
	message(string.format("Color green intensity %u", self.getValue()))
	return message
end

rgbGProperty.set_adjust = rgbRProperty.set_adjust
function rgbGProperty:set_perform()
	local message = initOutputMessage()
	local state = self.getValue()
	local retval, answer = reaper.GetUserInputs("Green value input", 1, 'Type the green value intensity (0...255):', state)
	if retval == true then
		if tonumber(answer) then
			self.setValue(tonumber(answer))
		else
			message("The provided green value is not a number value. ")
		end
	end
	setColorIndex(colors:getColorID(reaper.ColorFromNative(getColor())))
	message { objectId = "Color", label = "Green intensity",
		value = string.format("%u, closest color is %s", self.getValue(), colors:getName(reaper.ColorFromNative(getColor()))) }
	return message
end

-- The B methods
local rgbBProperty = {}
registerProperty(rgbBProperty)

function rgbBProperty.getValue()
	local _, _, b = reaper.ColorFromNative(getColor())
	return b
end

function rgbBProperty.setValue(value)
	local r, g, b = reaper.ColorFromNative(getColor())
	b = value
	setColor(reaper.ColorToNative(r, g, b))
end

function rgbBProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to find nearest  blue shade intensity value which belongs to different color.")
	message(string.format("Color blue intensity %u", self.getValue()))
	return message
end

rgbBProperty.set_adjust = rgbRProperty.set_adjust

function rgbBProperty:set_perform()
	local message = initOutputMessage()
	local state = self.getValue()
	local retval, answer = reaper.GetUserInputs("Blue value input", 1, 'Type the blue value intensity (0...255):', state)
	if retval == true then
		if tonumber(answer) then
			self.setValue(tonumber(answer))
		else
			message("The provided blue value is not a number value. ")
		end
	end
	setColorIndex(colors:getColorID(reaper.ColorFromNative(getColor())))
	message { objectId = "Color", label = "Blue intensity",
		value = string.format("%u, closest color is %s", self.getValue(), colors:getName(reaper.ColorFromNative(getColor()))) }
	return message
end

-- Apply the cosen color methods
local applyColorProperty = {}
registerProperty(applyColorProperty)
applyColorProperty.states = setmetatable({
	["marker"] = "marker near cursor",
	["region"] = "region near cursor"
}, {
	__index = function(self, key)
		if key == "track" then
			local tracks = track_properties_macros.getTracks(multiSelectionSupport)
			if istable(tracks) then
				return string.format("%u selected tracks", #tracks)
			elseif isuserdata(tracks) then
				return track_properties_macros.getTrackID(tracks, true)
			end
		elseif key == "item" then
			local items = item_properties_macros.getItems(multiSelectionSupport)
			if istable(items) then
				return string.format("%u selected items", #items)
			elseif isuserdata(items) then
				return item_properties_macros.getItemID(items, true)
			end
		elseif key == "take" then
			local items = item_properties_macros.getItems(multiSelectionSupport)
			if istable(items) then
				return string.format("%u active takes in selected items", #items)
			elseif isuserdata(items) then
				return item_properties_macros.getTakeID(items, true)
			end
		end
	end
})

function applyColorProperty.setValue(value)
	if sublayout == "track" then
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
	elseif sublayout == "item" then
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
	elseif sublayout == "take" then
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
	elseif sublayout == "marker" then
		local markeridx, _ = reaper.GetLastMarkerAndCurRegion(0, reaper.GetCursorPosition())
		if markeridx then
			local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, markeridx)
			reaper.SetProjectMarker4(0, markrgnindexnumber, false, pos, 0, name, value | 0x1000000, 0)
			return true
		end
	elseif sublayout == "region" then
		local _, regionidx = reaper.GetLastMarkerAndCurRegion(0, reaper.GetCursorPosition())
		if regionidx then
			local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, regionidx)
			reaper.SetProjectMarker4(0, markrgnindexnumber, true, pos, rgnend, name, value | 0x1000000, 0)
			return true
		end
	end
	return false
end

function applyColorProperty:get()
	local message = initOutputMessage()
	message:initType(string.format("Perform this property to apply composed color to %s.",
		({ track = "last touched track", item = "first selected item", take = "active take of first selected item" })[
		sublayout]))
	local gotState = self.states[sublayout]
	if gotState then
		message(string.format("Apply %s color to %s", colors:getName(reaper.ColorFromNative(getColor())), gotState))
	else
		message:addType(" This property is unavailable right now because no one object is selected.", 1)
		message:changeType("Unavailable", 2)
		message(string.format("Apply the %s color", colors:getName(reaper.ColorFromNative(getColor()))))
	end
	return message
end

function applyColorProperty:set_perform()
	local gotState = self.states[sublayout]
	if gotState then
		local message = initOutputMessage()
		local result = self.setValue(getColor())
		if result then
			message(string.format("%s colorized to %s color.", self.states[sublayout],
				colors:getName(reaper.ColorFromNative(getColor()))))
		else
			message(string.format("Could not colorize any %s.", self.states[sublayout]))
		end
		return message
	end
	return "This properti is unavailable right now cuz no one object is selected."
end

-- Grabbing a color from an elements methods
local grabColorProperty = {}
registerProperty(grabColorProperty)
grabColorProperty.states = setmetatable({
	["marker"] = "marker near cursor",
	["region"] = "region near cursor"
}, {
	__index = function(self, key)
		if key == "track" then
			local track = track_properties_macros.getTracks(false)
			if track then
				return track_properties_macros.getTrackID(track)
			end
		elseif key == "item" then
			local item = item_properties_macros.getItems(false)
			if item then
				return item_properties_macros.getItemID(item, true)
			end
		elseif key == "take" then
			local item = item_properties_macros.getItems(false)
			if item then
				return item_properties_macros.getTakeID(item, true)
			end
		end
	end
})

function grabColorProperty.getValue()
	if sublayout == "track" then
		local track = track_properties_macros.getTracks(false)
		if track then
			return reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")
		end
		return nil
	elseif sublayout == "item" then
		local item = item_properties_macros.getItems(false)
		if item then
			return reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
		end
		return nil
	elseif sublayout == "take" then
		local item = item_properties_macros.getItems(false)
		if item then
			return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_CUSTOMCOLOR")
		end
		return nil
	elseif sublayout == "marker" then
		local markeridx, _ = reaper.GetLastMarkerAndCurRegion(0, reaper.GetCursorPosition())
		if markeridx then
			local _, _, _, _, _, _, color = reaper.EnumProjectMarkers3(0, markeridx)
			return color
		end
	elseif sublayout == "region" then
		local _, regionidx = reaper.GetLastMarkerAndCurRegion(0, reaper.GetCursorPosition())
		if regionidx then
			local _, _, _, _, _, _, color = reaper.EnumProjectMarkers3(0, regionidx)
			return color
		end
		return nil
	end
end

function grabColorProperty.setValue(value)
	setColor(value)
	setColorIndex(colors:getColorID(reaper.ColorFromNative(getColor())))
end

function grabColorProperty:get()
	local message = initOutputMessage()
	message:initType(string.format("Perform this property to grab a color from %s. This color will be coppied to this category of color composition layout for following performances."
		, ({ track = "last touched track", item = "first selected item", take = "active take of first selected item" })[
		sublayout]))
	if self.getValue() then
		message(string.format("Grab a color from %s", self.states[sublayout]))
	else
		message:addType(" This property unavailable right now because no one element has been selected.", 1)
		message:changeType("unavailable", 2)
		message("Grab a color")
	end
	return message
end

function grabColorProperty:set_perform()
	local message = initOutputMessage()
	local state = self.getValue()
	if not state then
		return "This property is unavailable right now because no one element of this category has been neither touched nor selected."
	end
	self.setValue(state)
	message(string.format("The %s color has been grabbed from %s.", colors:getName(reaper.ColorFromNative(state)),
		self.states[sublayout]))
	return message
end

parentLayout.defaultSublayout = sublayout

return parentLayout