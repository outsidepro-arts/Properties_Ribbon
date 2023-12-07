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

package.path = select(2, reaper.get_action_context()):match('^.+[\\//]') .. "?//init.lua"

require "properties_ribbon"

useMacros("track_properties")
useMacros("tools")

local parentLayout = initLayout("Track properties")

-- Define the tracks undo context
parentLayout.undoContext = undo.contexts.tracks


-- sublayouts
--visual properties
parentLayout:registerSublayout("visualLayout", "Visualisation")

-- Playback properties
parentLayout:registerSublayout("playbackLayout", "Playback")

-- Recording properties
parentLayout:registerSublayout("recordingLayout", "Recording")


-- Preparing all needed configs which will be used not one time
multiSelectionSupport = config.getboolean("multiSelectionSupport", true)

-- For comfort coding, we are making the tracks array as global
tracks = track_properties_macros.getTracks(multiSelectionSupport)

-- These redirections made especially to not rewrite many code
-- We have to define the track reporting by configuration. This function has contained in properties macros.
getTrackID = track_properties_macros.getTrackID

-- Default messages set for threeposition setters
tpMessages = {
	[true] = "Set selected tracks to %s. ",
	[false] = "Set to %s. "
}

-- The macros for compose when group of items selected
-- func (function)): the function for getting specific value
-- states (table): the list of states which represents the value for reporting
-- inaccuracy (number): the inaccuracy for specific cases which values will be considered in the states representation
function composeMultipleTrackMessage(func, states, inaccuracy)
	local message = initOutputMessage()
	for k = 1, #tracks do
		local state = func(tracks[k])
		local prevState
		if tracks[k - 1] then prevState = func(tracks[k - 1]) end
		local nextState
		if tracks[k + 1] then nextState = func(tracks[k + 1]) end
		if state ~= prevState and state == nextState then
			message({ value = string.format("tracks from %s ", getTrackID(tracks[k]):gsub("Track ", "")) })
		elseif state == prevState and state ~= nextState then
			message({ value = string.format("to %s ", getTrackID(tracks[k]):gsub("Track ", "")) })
			if inaccuracy and isnumber(state) then
				message({ value = string.format("%s", states[state + inaccuracy]) })
			else
				message({ value = string.format("%s", states[state]) })
			end
			if k < #tracks then
				message({ value = ", " })
			end
		elseif state == prevState and state == nextState then
		else
			message({ value = string.format("%s ", getTrackID(tracks[k])) })
			if inaccuracy and isnumber(state) then
				message({ value = string.format("%s", states[state + inaccuracy]) })
			else
				message({ value = string.format("%s", states[state]) })
			end
			if k < #tracks then
				message({ value = ", " })
			elseif k == #tracks - 1 then
				message({ value = " and " })
			end
		end
	end
	return message
end

-- global pseudoclass initialization

-- the function which gives green light to call any method from this class
function parentLayout.canProvide()
	return tracks ~= nil
end

--[[
Before the properties list fill get started, let describe this subclass methods:
Method get: gets no one parameter, returns a message string which will be reported in the navigating scripts.
Method set: gets parameter action. Expects false, true or nil.
action == actions.set.increase: the property must changed upward
action == actions.set.decrease: the property must changed downward
action == nil: The property must be toggled or performed default action
Returns a message string which will be reported in the navigating scripts.

After you finish the methods table you have to return parent class.
No any recomendation more.
Although, no, just one thing:
Try to allow the user to perform actions on both one element and a selected group..
and try to complement any get message with short type label. I mean what the "ajust" method will perform.
]] --

-- Track name methods
local trackNameProperty = {}
parentLayout.visualLayout:registerProperty(trackNameProperty)

function trackNameProperty:get()
	local message = initOutputMessage()
	message:initType("Perform this action to rename selected track.")
	if multiSelectionSupport == true then
		message:addType(" If the group of tracks has been selected, new name will applied to all selected tracks.", 1)
	end
	message({ label = "name" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track)
			local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
			if name ~= "" then
				return name
			else
				return "unnamed"
			end
		end,
			setmetatable({}, { __index = function(self, key) return key end })))
	else
		message({ objectId = getTrackID(tracks) })
		local _, name = reaper.GetSetMediaTrackInfo_String(tracks, "P_NAME", "", false)
		if name ~= "" then
			message({ value = name })
		else
			message({ value = "unnamed" })
		end
	end
	return message
end

function trackNameProperty:set_perform()
	local message = initOutputMessage()
	if istable(tracks) then
		local state, answer = getUserInputs("Change tracks name", { caption = 'new tracks name:' })
		if state == true then
			for k = 1, #tracks do
				reaper.GetSetMediaTrackInfo_String(tracks[k], "P_NAME", answer .. " " .. k, true)
			end
			message(string.format("The name %s has been set for %u tracks.", answer, #tracks))
		end
	else
		local nameState, name = reaper.GetTrackName(tracks)
		local aState, answer = getUserInputs(string.format("Change name for track %s", getTrackID(tracks)),
			{ caption = 'New track name:', defValue = name })
		if aState == true then
			reaper.GetSetMediaTrackInfo_String(tracks, "P_NAME", answer, true)
		end
	end
	message(self:get())
	return message
end

local folderStateProperty = {}
parentLayout.visualLayout:registerProperty(folderStateProperty)
folderStateProperty.states = {
	[0] = "track",
	[1] = "folder",
	[2] = "end of folder",
	[3] = "end of %u folders"
}
folderStateProperty.compactStates = {
	[0] = "opened ",
	[1] = "small ",
	[2] = "closed "
}

function folderStateProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to switch the folder state of selected tracks.")
	if multiSelectionSupport == true then
		message:addType(" This property is adjustable for one track only.", 1)
	end
	message({ label = "folder state" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return tostring(reaper.GetMediaTrackInfo_Value(track,
			"I_FOLDERDEPTH")) .. "|" .. tostring(reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")) end,
			setmetatable({},
				{ __index = function(self, key)
					local msg = ""
					local states = folderStateProperty.states
					local compactStates = folderStateProperty.compactStates
					local state = tonumber(key:split("|")[1])
					if state == 0 or state == 1 then
						if state == 1 then
							local compactState = tonumber(key:split("|")[2])
							msg = msg .. compactStates[compactState] .. " "
						end
						msg = msg .. states[state]
					elseif state < 0 then
						state = -(state - 1)
						if state < 3 then
							msg = msg .. string.format("%s", states[state])
						else
							msg = msg .. string.format(states[3], state - 1)
						end
					end
					return msg
				end })
		))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH")
		message({ objectId = getTrackID(tracks) })
		if state == 0 or state == 1 then
			if state == 1 then
				local compactState = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERCOMPACT")
				message({ value = self.compactStates[compactState] })
			end
			message({ value = self.states[state] })
			if state == 1 then
				message:addType(" Toggle this property to set the collaps track state.", 1)
				message:addType(", toggleable", 2)
			end
		elseif state < 0 then
			state = -(state - 1)
			if state < 3 then
				message({ value = self.states[state] })
			else
				message({ value = string.format(self.states[3], state - 1) })
			end
		end
	end
	return message
end

function folderStateProperty:set_adjust(direction)
	if istable(tracks) then
		return "No group action for this property."
	end
	local message = initOutputMessage()
	local state = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH")
	if direction == actions.set.increase.direction then
		if state == 0 then
			reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH", 1)
		elseif state == 1 then
			local isParentTrack = reaper.GetParentTrack(tracks)
			if isParentTrack then
				reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH", -1)
			else
				message("No more next folder depth. ")
			end
		elseif state < 0 then
			reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH", state - 1)
			if reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH") == state then
				message("No more next folder depth. ")
			end
		end
	elseif direction == actions.set.decrease.direction then
		if state == 0 then
			message("No more previous inner state. ")
		elseif state == 1 then
			reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH", 0)
		elseif state == -1 then
			reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH", 1)
		elseif state < 0 then
			reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH", state + 1)
		end
	end
	message(self:get())
	state = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH")
	if state == 1 then
		message({ value = ". Toggle this property now to control the folder compacted view" })
	end
	return message
end

function folderStateProperty:set_perform()
	if istable(tracks) then
		return "No group action for this property."
	end
	local message = initOutputMessage()
	local state = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH")
	if state == 1 then
		local compactState = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERCOMPACT")
		if compactState == 0 then
			reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERCOMPACT", 1)
		elseif compactState == 1 then
			reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERCOMPACT", 2)
		elseif compactState == 2 then
			reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERCOMPACT", 0)
		end
	else
		return "This track is not a folder."
	end
	message(self:get())
	return message
end

local volumeProperty = {}
parentLayout.playbackLayout:registerProperty(volumeProperty)
parentLayout.recordingLayout:registerProperty(volumeProperty)

function volumeProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired volume value for selected track.")
	if multiSelectionSupport == true then
		message:addType(" If the group of track has been selected, the relative of previous value will be applied for each track of."
			, 1)
	end
	message({ label = "volume" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "D_VOL") end,
			representation.db))
	else
		message({ objectId = getTrackID(tracks), value = representation.db[reaper.GetMediaTrackInfo_Value(tracks, "D_VOL")] })
	end
	return message
end

function volumeProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustStep = config.getinteger("dbStep", 0.1)
	local maxDBValue = config.getinteger("maxDBValue", 12.0)
	if direction == actions.set.decrease.direction then
		ajustStep = -ajustStep
	end
	if istable(tracks) then
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_VOL")
			state = utils.decibelstonum(utils.numtodecibels(state) + ajustStep)
			if utils.numtodecibels(state) < -150.0 then
				state = utils.decibelstonum(-150.0)
			elseif utils.numtodecibels(state) > utils.numtodecibels(maxDBValue) then
				state = utils.numtodecibels(maxDBValue)
			end
			reaper.SetMediaTrackInfo_Value(tracks[k], "D_VOL", state)
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "D_VOL")
		state = utils.decibelstonum(utils.numtodecibels(state) + ajustStep)
		if utils.numtodecibels(state) < -150.0 then
			state = utils.decibelstonum(-150.0)
			message("Minimum volume. ")
		elseif utils.numtodecibels(state) > maxDBValue then
			state = utils.decibelstonum(maxDBValue)
			message("maximum volume. ")
		end
		reaper.SetMediaTrackInfo_Value(tracks, "D_VOL", state)
	end
	message(self:get())
	return message
end

volumeProperty.extendedProperties = initExtendedProperties("Volume extended interraction")

volumeProperty.extendedProperties:registerProperty(composeThreePositionProperty(
	tracks,
	{
		representation = representation.db,
		min = utils.decibelstonum("-inf"),
		rootmean = utils.decibelstonum(0.00),
		max = utils.decibelstonum(config.getinteger("maxDBValue", 12.0))
	},
	tpMessages,
	function(obj, value)
		reaper.SetMediaTrackInfo_Value(obj, "D_VOL", value)
	end
))

volumeProperty.extendedProperties:registerProperty({
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to type the volume value manualy.")
		if multiSelectionSupport == true then
			message:addType(" If the group of track has been selected, the input value will be applied for each track of.", 1)
		end
		message("Type custom volume value")
		return message
	end,
	set_perform = function(self, parent)
		if istable(tracks) then
			local retval, answer = getUserInputs(string.format("Volume for %u selected tracks", #tracks),
				{ caption = "New volume value:", defValue = representation.db[reaper.GetMediaTrackInfo_Value(tracks[1], "D_VOL")] },
				prepareUserData.db.formatCaption)
			if not retval then
				return "Canceled"
			end
			for _, track in ipairs(tracks) do
				local state = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
				state = prepareUserData.db.process(answer, state)
				if state then
					reaper.SetMediaTrackInfo_Value(track, "D_VOL", state)
				end
			end
			setUndoLabel(parent:get())
			return true
		else
			local state = reaper.GetMediaTrackInfo_Value(tracks, "D_VOL")
			local retval, answer = getUserInputs(string.format("Volume for %s",
				getTrackID(tracks, true):gsub("^%w", string.lower)),
				{ caption = "New volume value:", defValue = representation.db[state] },
				prepareUserData.db.formatCaption)
			if not retval then
				return false
			end
			state = prepareUserData.db.process(answer, state)
			if state then
				reaper.SetMediaTrackInfo_Value(tracks, "D_VOL", state)
				setUndoLabel(parent:get())
				return true
			end
		end
	end
})


local panProperty = {}
parentLayout.playbackLayout:registerProperty(panProperty)
parentLayout.recordingLayout:registerProperty(panProperty)

function panProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired pan value for selected track.")
	if multiSelectionSupport == true then
		message:addType(" If the group of track has been selected, the relative of previous value will be applied for each track of."
			, 1)
	end
	message({ label = "Pan" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "D_PAN") end,
			representation.pan))
	else
		message({ objectId = getTrackID(tracks) })
		local state = reaper.GetMediaTrackInfo_Value(tracks, "D_PAN")
		message({ value = representation.pan[state] })
	end
	return message
end

function panProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = config.getinteger("percentStep", 1)
	ajustingValue = utils.percenttonum(ajustingValue)
	if direction == actions.set.decrease.direction then
		ajustingValue = -ajustingValue
	end
	if istable(tracks) then
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_PAN")
			state = math.round((state + ajustingValue), 3)
			if state <= -1 then
				state = -1
			elseif state > 1 then
				state = 1
			end
			reaper.SetMediaTrackInfo_Value(tracks[k], "D_PAN", state)
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "D_PAN")
		state = math.round((state + ajustingValue), 3)
		if state < -1 then
			state = -1
			message("Left boundary. ")
		elseif state > 1 then
			state = 1
			message("Right boundary. ")
		end
		reaper.SetMediaTrackInfo_Value(tracks, "D_PAN", state)
	end
	message(self:get())
	return message
end

panProperty.extendedProperties = initExtendedProperties("Pan extended interraction")

panProperty.extendedProperties:registerProperty(composeThreePositionProperty(
	tracks,
	{
		representation = representation.pan,
		min = utils.percenttonum(-100),
		rootmean = utils.percenttonum(0),
		max = utils.percenttonum(100)
	},
	tpMessages,
	function(obj, value)
		reaper.SetMediaTrackInfo_Value(obj, "D_PAN", value)
	end
))

panProperty.extendedProperties:registerProperty({
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to type the custom pan value.")
		if multiSelectionSupport == true then
			message:addType(" If the group of track has been selected, the input value will be applied for each track of.", 1)
		end
		message("Type custom pan value")
		return message
	end,
	set_perform = function(self, parent, action)
		if istable(tracks) then
			local retval, answer = getUserInputs(string.format("Pan for %u selected tracks", #tracks)
				{ caption = "New pan value:", defValue = representation.pan[reaper.GetMediaTrackInfo_Value(tracks[1], "D_PAN")] },
				prepareUserData.pan.formatCaption)
			if not retval then
				return false
			end
			for _, track in ipairs(tracks) do
				local state = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
				state = prepareUserData.pan.process(answer, state)
				if state then
					reaper.SetMediaTrackInfo_Value(track, "D_PAN", state)
				end
			end
			setUndoLabel(parent:get())
			return true
		else
			local state = reaper.GetMediaTrackInfo_Value(tracks, "D_PAN")
			local retval, answer = getUserInputs(string.format("Pan for %s",
				getTrackID(tracks, true):gsub("^%w", string.lower)),
				{ caption = "New pan value:", defValue = representation.pan[state] },
				prepareUserData.pan.formatCaption)
			if not retval then
				return false
			end
			state = prepareUserData.pan.process(answer, state)
			if state then
				reaper.SetMediaTrackInfo_Value(tracks, "D_PAN", state)
				setUndoLabel(parent:get())
				return true
			end
		end
	end
})


local widthProperty = {}
parentLayout.playbackLayout:registerProperty(widthProperty)

function widthProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired width value for selected track.")
	if multiSelectionSupport == true then
		message:addType(" If the group of track has been selected, the relative of previous value will be applied for each track of."
			, 1)
	end
	message({ label = "Width" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "D_WIDTH") end,
			setmetatable({}, { __index = function(self, state) return string.format("%s%%", utils.numtopercent(state)) end })))
	else
		message({ objectId = getTrackID(tracks) })
		local state = reaper.GetMediaTrackInfo_Value(tracks, "D_WIDTH")
		message({ value = string.format("%s%%", utils.numtopercent(state)) })
	end
	return message
end

function widthProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = config.getinteger("percentStep", 1)
	if direction == actions.set.decrease.direction then
		ajustingValue = -utils.percenttonum(ajustingValue)
	elseif direction == actions.set.increase.direction then
		ajustingValue = utils.percenttonum(ajustingValue)
	end
	if istable(tracks) then
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_WIDTH")
			state = math.round((state + ajustingValue), 3)
			if state < -1 then
				state = -1
			elseif state > 1 then
				state = 1
			end
			reaper.SetMediaTrackInfo_Value(tracks[k], "D_WIDTH", state)
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "D_WIDTH")
		state = math.round((state + ajustingValue), 3)
		if state < -1 then
			state = -1
			message("Minimum width. ")
		elseif state > 1 then
			state = 1
			message("Maximum width. ")
		end
		reaper.SetMediaTrackInfo_Value(tracks, "D_WIDTH", state)
	end
	message(self:get())
	return message
end

widthProperty.extendedProperties = initExtendedProperties("Width extended interraction")

widthProperty.extendedProperties:registerProperty(composeThreePositionProperty(
	tracks,
	{
		representation = setmetatable({},
			{ __index = function(self, state) return string.format("%s%%", utils.numtopercent(state)) end }),
		min = -1,
		rootmean = 0,
		max = 1
	},
	tpMessages,
	function(obj, value)
		reaper.SetMediaTrackInfo_Value(obj, "D_WIDTH", value)
	end
))
widthProperty.extendedProperties:registerProperty({
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to specify a custom width value.")
		message("Type custom width value")
		return message
	end,
	set_perform = function(self, parent)
		if istable(tracks) then
			local retval, answer = getUserInputs(string.format("Width for %u selected tracks", #tracks),
				{
					caption = "New width value:",
					defValue  = string.format("%s%%", utils.numtopercent(reaper.GetMediaTrackInfo_Value(tracks[1], "D_WIDTH")))
				},
				prepareUserData.percent.formatCaption)
			if not retval then
				return false, "Canceled"
			end
			for k = 1, #tracks do
				local state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_WIDTH")
				state = prepareUserData.percent.process(answer, state)
				if state then
					reaper.SetMediaTrackInfo_Value(tracks[k], "D_WIDTH", state)
				end
			end
		else
			local state = reaper.GetMediaTrackInfo_Value(tracks, "D_WIDTH")
			local retval, answer = getUserInputs(string.format("Width for %s",
				getTrackID(tracks, true):gsub("^%w", string.lower)),
				{
					caption = "New width value:",
					defValue = string.format("%s%%", utils.numtopercent(state))
				},
				prepareUserData.percent.formatCaption)
			if not retval then
				return false, "Canceled"
			end
			state = prepareUserData.percent.process(answer, state)
			if state then
				reaper.SetMediaTrackInfo_Value(tracks, "D_WIDTH", state)
			else
				return false
			end
		end
		setUndoLabel(parent:get())
		return true
	end
})

local muteProperty = {}
parentLayout.playbackLayout:registerProperty(muteProperty)
muteProperty.states = { [0] = "not muted", [1] = "muted" }

function muteProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to mute or unmute selected track.", "Toggleable")
	if multiSelectionSupport == true then
		message:addType(" If the group of tracks has been selected, the mute state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	if istable(tracks) then
		message({ label = "Mute" })
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "B_MUTE") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "B_MUTE")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function muteProperty:set_perform()
	local message = initOutputMessage()
	if istable(tracks) then
		local mutedTracks, notMutedTracks = 0, 0
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_MUTE")
			if state == 1 then
				mutedTracks = mutedTracks + 1
			else
				notMutedTracks = notMutedTracks + 1
			end
		end
		local ajustingValue
		if mutedTracks > notMutedTracks then
			ajustingValue = 0
			message("Unmuting selected tracks.")
		elseif mutedTracks < notMutedTracks then
			ajustingValue = 1
			message("Muting selected tracks.")
		else
			ajustingValue = 0
			message("Unmuting selected tracks.")
		end
		local nonactionable = {}
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_MUTE")
			reaper.SetMediaTrackInfo_Value(tracks[k], "B_MUTE", ajustingValue)
			if reaper.GetMediaTrackInfo_Value(tracks[k], "B_MUTE") == state then
				nonactionable[#nonactionable + 1] = getTrackID(tracks[k], true)
			end
		end
		if #nonactionable > 0 then
			message(string.format("%u tracks could not be %s: %s.", #nonactionable, self.states[ajustingValue], table.concat(nonactionable, ", ")))
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "B_MUTE")
		reaper.SetMediaTrackInfo_Value(tracks, "B_MUTE", nor(state))
		if reaper.GetMediaTrackInfo_Value(tracks, "B_MUTE") == state then
			message{
				objectId = getTrackID(tracks),
				value = ("Could not be %s."):format(state == 1 and "unmuted" or "muted")
			}
		end
	end
	message(self:get())
	return message
end

local soloProperty = {}
parentLayout.playbackLayout:registerProperty(soloProperty)
soloProperty.states = {
	[0] = "not soloed",
	[1] = "soloed",
	[2] = "soloed in place",
	[5] = "safe soloed",
	[6] = "safe soloed in place"
}

function soloProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to solo or unsolo selected track using default configuration of solo-in-place set in REAPER preferences."
		, "Toggleable, adjustable")
	if multiSelectionSupport == true then
		message:addType(" If the group of tracks has been selected, the solo state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message:addType(" Adjust this property to choose needed solo mode for selected tracks.", 1)
	if multiSelectionSupport == true then
		message:addType(string.format(' If the group of tracks has been selected, the value will enumerate only if selected tracks have the same value. Otherwise, the solo state will be set to "%s", then will enumerate this.'
			, self.states[0]), 1)
	end
	if istable(tracks) then
		message({ label = "Solo" })
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_SOLO") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_SOLO")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function soloProperty:set_perform()
	local message = initOutputMessage()
	local retval, soloInConfig = reaper.get_config_var_string("soloip")
	if retval then
		soloInConfig = tonumber(soloInConfig) + 1
	else
		soloInConfig = 1
	end
	if istable(tracks) then
		local soloedTracks, notSoloedTracks = 0, 0
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_SOLO")
			if state > 0 then
				soloedTracks = soloedTracks + 1
			else
				notSoloedTracks = notSoloedTracks + 1
			end
		end
		local ajustingValue
		if soloedTracks > notSoloedTracks then
			ajustingValue = 0
			message("Unsoloing selected tracks.")
		elseif soloedTracks < notSoloedTracks then
			ajustingValue = soloInConfig
			message("Soloing selected tracks.")
		else
			ajustingValue = 0
			message("Unsoloing selected tracks.")
		end
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "I_SOLO", ajustingValue)
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_SOLO")
		if state > 0 then
			state = 0
		else
			state = soloInConfig
		end
		reaper.SetMediaTrackInfo_Value(tracks, "I_SOLO", state)
	end
	message(self:get())
	return message
end

function soloProperty:set_adjust(direction)
	local message = initOutputMessage()
	if istable(tracks) then
		local allIsSame = true
		for idx, track in ipairs(tracks) do
			local state = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
			if idx > 1 then
				local prevstate = reaper.GetMediaTrackInfo_Value(tracks[idx - 1], "I_SOLO")
				if state ~= prevstate then
					allIsSame = false
					break
				end
			end
		end
		local state = nil
		if allIsSame == true then
			state = reaper.GetMediaTrackInfo_Value(tracks[1], "I_SOLO")
			if (state + direction) >= 0 and (state + direction) <= #self.states then
				state = state + direction
			end
		else
			state = 0
		end
		message(string.format("Set all selected tracks solo to %s.", self.states[state]))
		for _, track in ipairs(tracks) do
			reaper.SetMediaTrackInfo_Value(track, "I_SOLO", state)
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_SOLO")
		if state + direction > #self.states then
			message "No more next property values. "
		elseif state + direction < 0 then
			message "No more previous property values. "
		else
			state = state + direction
		end
		reaper.SetMediaTrackInfo_Value(tracks, "I_SOLO", state)
	end
	message(self:get())
	return message
end

local recarmProperty = {}
parentLayout.recordingLayout:registerProperty(recarmProperty)
recarmProperty.states = { [0] = "not armed", [1] = "armed" }

function recarmProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to arm or disarm selected track for record.", "Toggleable")
	if multiSelectionSupport == true then
		message:addType(" If the group of tracks has been selected, the record state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	if istable(tracks) then
		message({ label = "Arm" })
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECARM") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECARM")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function recarmProperty:set_perform()
	local message = initOutputMessage()
	if istable(tracks) then
		local armedTracks, notArmedTracks = 0, 0
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECARM")
			if state == 1 then
				armedTracks = armedTracks + 1
			else
				notArmedTracks = notArmedTracks + 1
			end
		end
		local ajustingValue
		if armedTracks > notArmedTracks then
			ajustingValue = 0
			message("Unarming selected tracks.")
		elseif armedTracks < notArmedTracks then
			ajustingValue = 1
			message("Arming selected tracks.")
		else
			ajustingValue = 0
			message("Unarming selected tracks.")
		end
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "I_RECARM", ajustingValue)
		end
	else
		local state = nor(reaper.GetMediaTrackInfo_Value(tracks, "I_RECARM"))
		reaper.SetMediaTrackInfo_Value(tracks, "I_RECARM", state)
	end
	message(self:get())
	return message
end

local recmonitoringProperty = {}
parentLayout.recordingLayout:registerProperty(recmonitoringProperty)
recmonitoringProperty.states = {
	[0] = "off",
	[1] = "normal",
	[2] = "not when playing"
}

function recmonitoringProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to choose the desired record monitoring state.")
	if multiSelectionSupport == true then
		message:addType(string.format(' If the group of track has been selected, the value will enumerate only if selected tracks have the same value. Otherwise, the record monitoring state will be set to "%s" first, then will enumerate this.'
			, self.states[1]), 1)
	end
	message({ label = "Record monitoring" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECMON") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMON")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function recmonitoringProperty:set_adjust(direction)
	local message = initOutputMessage()
	if istable(tracks) then
		local st = { 0, 0, 0 }
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECMON")
			st[state + 1] = st[state + 1] + 1
		end
		local state
		if math.max(st[1], st[2], st[3]) == #tracks then
			state = reaper.GetMediaTrackInfo_Value(tracks[1], "I_RECMON")
			if self.states[state + direction] then
				state = state + direction
			end
		else
			state = 1
		end
		message(string.format("Set selected tracks monitoring to %s.", self.states[state]))
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "I_RECMON", state)
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMON")
		if (state + direction) < 0 then
			message("No more previous property values. ")
		elseif (state + direction) > #self.states then
			message("No more next property values. ")
		else
			state = state + direction
		end
		reaper.SetMediaTrackInfo_Value(tracks, "I_RECMON", state)
	end
	message(self:get())
	return message
end

-- Record inputs
local recInputsProperty = {}
parentLayout.recordingLayout:registerProperty(recInputsProperty)

function recInputsProperty.getMIDIInputName(id)
	local result, name = reaper.GetMIDIInputName(id, "")
	if id == 63 then
		result = true
		name = "All MIDI-devices"
	end
	return result, name
end

function recInputsProperty.compose(val)
	local message = initOutputMessage()
	if val < 0 then
		message("no input")
	elseif val >= 4096 then
		message("MIDI, ")
		local channel = utils.getBitValue(val, 1, 5)
		if channel == 0 then
			message("all channels, ")
		else
			message(string.format("channel %u, ", channel))
		end
		if utils.getBitValue(val, 6, 12) == 62 then
			message("from Virtual MIDI Keyboard")
		elseif utils.getBitValue(val, 6, 12) == 63 then
			message("from all devices")
		else
			local result, name = recInputsProperty.getMIDIInputName(utils.getBitValue(val, 6, 12))
			if result == true then
				message(string.format("from %s", name))
			else
				message(string.format("from unknown device with ID %u", utils.getBitValue(val, 6, 12)))
			end
		end
	else
		message("audio, ")
		local input = utils.getBitValue(val, 1, 11)
		if input >= 0 and input <= 1023 then
			message("mono, ")
			if input < 512 then
				message(string.format("from %s", reaper.GetInputChannelName(input)))
			elseif input >= 512 then
				message(string.format("from REAROUTE/Loopback channel %s", reaper.GetInputChannelName(input)))
			end
		elseif input >= 1024 and input < 2048 then
			local inputs = {}
			for i = 0, reaper.GetNumAudioInputs() do
				inputs[i + 1024] = string.format("%s/%s", reaper.GetInputChannelName(i), reaper.GetInputChannelName(i + 1))
			end
			message(string.format("stereo, %s", inputs[input]))
		end
	end
	return message:extract()
end

function recInputsProperty.calc(state, action)
	if action == 1 then
		if (state + 1) >= 0 and (state + 1) < 1024 then
			if reaper.GetInputChannelName(utils.getBitValue(state + 1, 1, 11)) then
				return state + 1
			else
				return 1024
			end
		elseif (state + 1) >= 1024 and (state + 1) < 2048 then
			local inputs = {}
			for i = 1, reaper.GetNumAudioInputs() - 1 do
				inputs[i] = string.format("%s/%s", reaper.GetInputChannelName(i - 1), reaper.GetInputChannelName(i))
			end
			if (state + 1) <= (#inputs + 1023) then
				return state + 1
			else
				for i = 4096, 8192 do
					local channel = utils.getBitValue(i, 1, 5)
					local result, _ = recInputsProperty.getMIDIInputName(utils.getBitValue(i, 6, 12))
					if result == true and channel <= 16 then
						return i
					end
					if i == 8192 then
						return i
					end
				end
			end
		elseif (state + 1) >= 4096 and (state + 1) < 8192 then
			for i = (state + 1), 8192 do
				local channel = utils.getBitValue(i, 1, 5)
				local result, _ = recInputsProperty.getMIDIInputName(utils.getBitValue(i, 6, 12))
				if result == true and channel <= 16 then
					return i
				end
				if i == 8192 then
					return i
				end
			end
		else
			return 8192
		end
	elseif action == -1 then
		if (state - 1) >= 4096 and (state - 1) < 8192 then
			for i = (state - 1), 4096, -1 do
				local channel = utils.getBitValue(i, 1, 5)
				local result, _ = recInputsProperty.getMIDIInputName(utils.getBitValue(i, 6, 12))
				if result == true and channel <= 16 then
					return i
				end
				if i == 4096 then
					local inputs = {}
					for i = 1, reaper.GetNumAudioInputs() - 1 do
						inputs[i] = string.format("%s/%s", reaper.GetInputChannelName(i - 1), reaper.GetInputChannelName(i))
					end
					return #inputs + 1023
				end
			end
		elseif (state - 1) < 2048 and (state - 1) >= 1024 then
			local inputs = {}
			for i = 1, reaper.GetNumAudioInputs() - 1 do
				inputs[i] = string.format("%s/%s", reaper.GetInputChannelName(i - 1), reaper.GetInputChannelName(i))
			end
			if (state - 1) > (#inputs + 1023) then
				return #inputs + 1023
			else
				return state - 1
			end
		elseif (state - 1) < 1024 and (state - 1) >= 0 then
			if reaper.GetNumAudioInputs() < (state - 1) then
				return reaper.GetNumAudioInputs() - 1
			else
				return state - 1
			end
		elseif (state - 1) < 0 then
			return -1
		elseif (state - 1) < -1 then
			return -2
		end
	else
		if state == -1 then
			return 0
		elseif state >= 0 and state < 512 then
			return 1024
		elseif state >= 1024 and state < 4096 then
			for i = 4096, 8192 do
				local channel = utils.getBitValue(i, 1, 5)
				local result, _ = recInputsProperty.getMIDIInputName(utils.getBitValue(i, 6, 12))
				if result == true and channel <= 16 then
					return i
				end
				if i == 8192 then
					return -1
				end
			end
		elseif state > 4096 then
			local result, device = recInputsProperty.getMIDIInputName(utils.getBitValue(state, 6, 12))
			if result == true then
				for i = state, 8192 do
					local curResult, curDevice = recInputsProperty.getMIDIInputName(utils.getBitValue(i, 6, 12))
					if curResult == true and curDevice ~= device then
						return i
					end
					if i == 8192 then
						return -1
					end
				end
			else
				return -1
			end
		end
	end
end

function recInputsProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to choose the desired record input of selected track.", "Adjustable, toggleable")
	if multiSelectionSupport == true then
		message:addType((
			' If the group of track has been selected, the value will enumerate up if selected tracks have the same value. If one of tracks has different value, all track will set to "%s" first, then will enumerate up this.'
			):format(self.compose(0)), 1)
	end
	message:addType(" Toggle this property to quick switch between input categories (mono, stereo or midi).", 1)
	if multiSelectionSupport == true then
		message:addType(" If the group of track has been selected, the quick switching will aplied for selected tracks by first selected track."
			, 1)
	end
	message({ label = "record input" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECINPUT") end,
			setmetatable({}, { __index = function(self, state) return recInputsProperty.compose(state) end })))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECINPUT")
		message({ objectId = getTrackID(tracks), value = self.compose(state) })
	end
	return message
end

function recInputsProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = direction
	if istable(tracks) then
		local lastState = reaper.GetMediaTrackInfo_Value(tracks[1], "I_RECINPUT")
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECINPUT")
			if lastState ~= state then
				ajustingValue = 0
				break
			end
			lastState = state
		end
		local state
		if ajustingValue ~= 0 then
			state = reaper.GetMediaTrackInfo_Value(tracks[1], "I_RECINPUT")
			ajustingValue = self.calc(state, direction)
			if ajustingValue < 8192 and ajustingValue > -2 then
				state = ajustingValue
			end
		else
			state = 0
		end
		message(string.format("Set selected tracks record input to %s.", self.compose(state)))
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "I_RECINPUT", state)
		end
	else
		-- The standart method boundaries check when you decrease the record input doesn't works here. Crap!
		local state, oldState = self.calc(reaper.GetMediaTrackInfo_Value(tracks, "I_RECINPUT"), direction),
			reaper.GetMediaTrackInfo_Value(tracks, "I_RECINPUT")
		if direction == actions.set.decrease.direction then
			if state ~= oldState then
				reaper.SetMediaTrackInfo_Value(tracks, "I_RECINPUT", state)
			else
				message("No more previous property values. ")
			end
		elseif direction == actions.set.increase.direction then
			if state < 8192 then
				reaper.SetMediaTrackInfo_Value(tracks, "I_RECINPUT", state)
			else
				message("No more next property values. ")
			end
		end
	end
	message(self:get())
	return message
end

function recInputsProperty:set_perform()
	local message = initOutputMessage()
	local ajustingValue
	if istable(tracks) then
		local lastState = reaper.GetMediaTrackInfo_Value(tracks[1], "I_RECINPUT")
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECINPUT")
			if lastState ~= state then
				ajustingValue = 0
				break
			end
			lastState = state
		end
		local state
		if ajustingValue ~= 0 then
			state = reaper.GetMediaTrackInfo_Value(tracks[1], "I_RECINPUT")
			ajustingValue = self.calc(state)
			state = ajustingValue
		else
			state = 0
		end
		message(string.format("Set selected tracks record input to %s.", self.compose(state)))
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "I_RECINPUT", state)
		end
	else
		local state = self.calc(reaper.GetMediaTrackInfo_Value(tracks, "I_RECINPUT"))
		reaper.SetMediaTrackInfo_Value(tracks, "I_RECINPUT", state)
	end
	message(self:get())
	return message
end

local recmodeProperty = {}
parentLayout.recordingLayout:registerProperty(recmodeProperty)
recmodeProperty.states = setmetatable({
	[0] = "input",
	[1] = "output (stereo)",
	[2] = "none",
	[3] = "output (stereo, latency compensated)",
	[4] = "midi output",
	[5] = "output (mono)",
	[6] = "output (mono, latency compensated)",
	[7] = "midi overdub",
	[8] = "midi replace",
	[9] = "MIDI touch replace",
	[10] = "output (multichannel",
	[11] = "output (multichannel, latency compensated)",
	[12] = "input (force mono)",
	[13] = "input (force stereo)",
	[14] = "input (force multichannel)",
	[15] = "input (force MIDI)",
	[16] = "MIDI latch replace"
}, {
	__index = function(self, key) return "Unknown record mode " .. key end
})

function recmodeProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired mode for recording.")
	if multiSelectionSupport == true then
		message:addType(string.format(' If the group of track has been selected, The value will enumerate only if selected tracks have the same value. Otherwise, the record mode state will be set to "%s", then will enumerate this.'
			, self.states[1]), 1)
	end
	message({ label = "Record mode" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECMODE") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMODE")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function recmodeProperty:set_adjust(direction)
	local message = initOutputMessage()
	if istable(tracks) then
		local st = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECMODE")
			if st[state + 1] then
				st[state + 1] = st[state + 1] + 1
			end
		end
		local state
		if math.max(st[1], st[2], st[3], st[4], st[5], st[6], st[7], st[8], st[9]) == #tracks then
			state = reaper.GetMediaTrackInfo_Value(tracks[1], "I_RECMODE")
			-- We have to patch our states metatable to avoid always existing values
			self.states = setmetatable(self.states, {})
			if self.states[state + direction] then
				state = state + direction
			end
		else
			state = 0
		end
		message(string.format("Set selected tracks record mode to %s.", self.states[state]))
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "I_RECMODE", state)
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMODE")
		if (state + direction) < 0 then
			message("No more previous property values. ")
		elseif (state + direction) > #self.states then
			message("No more next property values. ")
		else
			state = state + direction
		end
		reaper.SetMediaTrackInfo_Value(tracks, "I_RECMODE", state)
	end
	message(self:get())
	return message
end

-- Automation mode methods
local automationModeProperty = {}
parentLayout.recordingLayout:registerProperty(automationModeProperty)
automationModeProperty.states = setmetatable({
	[0] = "trim read",
	[1] = "read",
	[2] = "touch",
	[3] = "write",
	[4] = "latch"
}, {
	__index = function(self, key) return "Unknown automation mode " .. key end
})

function automationModeProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired automation mode for selected track.")
	if multiSelectionSupport == true then
		message:addType(string.format(' If the group of track has been selected, The value will enumerate only if selected tracks have the same value. Otherwise, the automation mode state will be set to "%s", then will enumerate this.'
			, self.states[1]), 1)
	end
	message({ label = "Automation mode" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_AUTOMODE")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function automationModeProperty:set_adjust(direction)
	local message = initOutputMessage()
	if istable(tracks) then
		local st = { 0, 0, 0, 0, 0 }
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_AUTOMODE")
			if st[state + 1] then
				st[state + 1] = st[state + 1] + 1
			end
		end
		local state
		if math.max(st[1], st[2], st[3], st[4], st[5]) == #tracks then
			state = reaper.GetMediaTrackInfo_Value(tracks[1], "I_AUTOMODE")
			-- We have to patch our states metatable to avoid always existing values
			self.states = setmetatable(self.states, {})
			if self.states[state + direction] then
				state = state + direction
			end
		else
			state = 1
		end
		message(string.format("Set selected tracks automation mode to %s.", self.states[state]))
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "I_AUTOMODE", state)
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_AUTOMODE")
		if (state + direction) < 0 then
			message("No more previous property values. ")
		elseif (state + direction) > #self.states then
			message("No more next property values. ")
		else
			state = state + direction
		end
		reaper.SetMediaTrackInfo_Value(tracks, "I_AUTOMODE", state)
	end
	message(self:get())
	return message
end

local phaseProperty = {}
parentLayout.playbackLayout:registerProperty(phaseProperty)
phaseProperty.states = { [0] = "normal", [1] = "inverted" }

function phaseProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to set the phase polarity of selected track.", "toggleable")
	if multiSelectionSupport == true then
		message:addType(" If the group of tracks has been selected, the phase polarity state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message({ label = "Phase" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "B_PHASE") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "B_PHASE")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function phaseProperty:set_perform()
	local message = initOutputMessage()
	if istable(tracks) then
		local phasedTracks, notPhasedTracks = 0, 0
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_PHASE")
			if state == 1 then
				phasedTracks = phasedTracks + 1
			else
				notPhasedTracks = notPhasedTracks + 1
			end
		end
		local ajustingValue
		if phasedTracks > notPhasedTracks then
			ajustingValue = 0
			message("Set all track phase to normal.")
		elseif phasedTracks < notPhasedTracks then
			ajustingValue = 1
			message("Inverting all phase tracks.")
		else
			ajustingValue = 0
			message("Set all track phase to normal.")
		end
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "B_PHASE", ajustingValue)
		end
	else
		local state = nor(reaper.GetMediaTrackInfo_Value(tracks, "B_PHASE"))
		reaper.SetMediaTrackInfo_Value(tracks, "B_PHASE", state)
	end
	message(self:get())
	return message
end

-- Send to parent or master track methods
local mainSendProperty = {}
parentLayout.playbackLayout:registerProperty(mainSendProperty)
mainSendProperty.states = { [0] = "not sends", [1] = "sends" }

function mainSendProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to switch the send state of selected track to parent or master track.",
		"Toggleable")
	if multiSelectionSupport == true then
		message:addType(" If the group of tracks has been selected, the send state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	if istable(tracks) then
		message("tracks send to parent or master track: ")
		message(composeMultipleTrackMessage(function(track)
			local masterOrParent
			if reaper.GetParentTrack(track) then masterOrParent = true else masterOrParent = false end
			return tostring(reaper.GetMediaTrackInfo_Value(track, "B_MAINSEND")) .. "|" .. tostring(masterOrParent)
		end,
			setmetatable({}, {
				__index = function(self, key)
					local msg, state, masterOrParent = "", tonumber(key:split("|")[1]),
						utils.toboolean(key:split("|")[2])
					msg = mainSendProperty.states[state] .. " to "
					if masterOrParent then
						msg = msg .. "parent"
					else
						msg = msg .. "master"
					end
					return msg
				end
			})))
	else
		message({ objectId = getTrackID(tracks) })
		local state = reaper.GetMediaTrackInfo_Value(tracks, "B_MAINSEND")
		message({ value = string.format("%s to ", self.states[state]) })
		if reaper.GetParentTrack(tracks) then
			message({ value = "parent " })
		else
			message({ value = "master " })
		end
		message({ value = "track" })
	end
	return message
end

function mainSendProperty:set_perform()
	local message = initOutputMessage()
	if istable(tracks) then
		local sendTracks, notSendTracks = 0, 0
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_MAINSEND")
			if state == 1 then
				sendTracks = sendTracks + 1
			else
				notSendTracks = notSendTracks + 1
			end
		end
		local ajustingValue
		if sendTracks > notSendTracks then
			ajustingValue = 0
			message("Switching off selected tracks send to parent or master track.")
		elseif sendTracks < notSendTracks then
			ajustingValue = 1
			message("Switching on selected tracks send to parent or master track.")
		else
			ajustingValue = 0
			message("Switching off selected tracks send to parent or master track.")
		end
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "B_MAINSEND", ajustingValue)
		end
	else
		local state = nor(reaper.GetMediaTrackInfo_Value(tracks, "B_MAINSEND"))
		reaper.SetMediaTrackInfo_Value(tracks, "B_MAINSEND", state)
	end
	message(self:get())
	return message
end

-- Free mode methods
local freemodeProperty = {}
parentLayout.playbackLayout:registerProperty(freemodeProperty)
freemodeProperty.states = { [0] = "disabled", [1] = "enabled" }

function freemodeProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to set the free mode of selected track.", "Toggleable")
	if multiSelectionSupport == true then
		message:addType(" If the group of tracks has been selected, the free mode state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message({ label = "Free position" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "B_FREEMODE") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "B_FREEMODE")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function freemodeProperty:set_perform()
	local message = initOutputMessage()
	if istable(tracks) then
		local freedTracks, notFreedTracks = 0, 0
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_FREEMODE")
			if state == 1 then
				freedTracks = freedTracks + 1
			else
				notFreedTracks = notFreedTracks + 1
			end
		end
		local ajustingValue
		if freedTracks > notFreedTracks then
			ajustingValue = 0
		elseif freedTracks < notFreedTracks then
			ajustingValue = 1
		else
			ajustingValue = 0
		end
		message(string.format("Set all track free position mode to %s.", self.states[ajustingValue]))
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "B_FREEMODE", ajustingValue)
		end
		reaper.UpdateTimeline()
	else
		local state = nor(reaper.GetMediaTrackInfo_Value(tracks, "B_FREEMODE"))
		reaper.SetMediaTrackInfo_Value(tracks, "B_FREEMODE", state)
		reaper.UpdateTimeline()
	end
	message(self:get())
	return message
end

-- Timebase methods
local timebaseProperty = {}
parentLayout.playbackLayout:registerProperty(timebaseProperty)
timebaseProperty.states = setmetatable({
	[0] = "project default",
	[1] = "time",
	[2] = "beats (position, length, rate)",
	[3] = "beats (position only)"
}, {
	__index = function(self, key) return "Unknown timebase mode " .. key end
})

function timebaseProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to choose the desired time base mode for selected track.")
	if multiSelectionSupport == true then
		message:addType(string.format(' If the group of tracks has been selected, the value will enumerate only if selected tracks have the same value. Otherwise, the timebase state will be set to "%s", then will enumerate this.'
			, self.states[0]), 1)
	end
	message({ label = "Timebase" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "C_BEATATTACHMODE") end
			, self.states, 1))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "C_BEATATTACHMODE")
		message({ objectId = getTrackID(tracks), value = self.states[state + 1] })
	end
	return message
end

function timebaseProperty:set_adjust(direction)
	local message = initOutputMessage()
	if istable(tracks) then
		local st = { 0, 0, 0, 0 }
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "C_BEATATTACHMODE")
			st[state + 2] = st[state + 2] + 1
		end
		local state
		if math.max(st[1], st[2], st[3], st[4]) == #tracks then
			state = reaper.GetMediaTrackInfo_Value(tracks[1], "C_BEATATTACHMODE")
			if state + direction >= -1 and state + direction < #self.states then
				state = state + direction
			end
		else
			state = -1
		end
		message(string.format("Set selected tracks timebase to %s.", self.states[state + 1]))
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "C_BEATATTACHMODE", state)
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "C_BEATATTACHMODE")
		if state + direction < -1 then
			message("No more previous property values. ")
		elseif state + direction > #self.states - 1 then
			message("No more next property values. ")
		else
			state = state + direction
		end
		reaper.SetMediaTrackInfo_Value(tracks, "C_BEATATTACHMODE", state)
	end
	message(self:get())
	return message
end

function timebaseProperty:set_perform()
	local message = initOutputMessage()
	if istable(tracks) then
		message(string.format("Set selected tracks timebase to %s.", self.states[0]))
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "C_BEATATTACHMODE", -1)
		end
	else
		reaper.SetMediaTrackInfo_Value(tracks, "C_BEATATTACHMODE", -1)
	end
	message(self:get())
	return message
end

-- Monitor items while recording methods
local recmonitorItemsProperty = {}
parentLayout.recordingLayout:registerProperty(recmonitorItemsProperty)
recmonitorItemsProperty.states = { [0] = "off", [1] = "on" }

function recmonitorItemsProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property if you want to monitor items while recording or not on selected track.",
		"Toggleable")
	if multiSelectionSupport == true then
		message:addType(" If the group of tracks has been selected, the monitor items state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message({ label = "Items monitoring while recording" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECMONITEMS") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMONITEMS")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function recmonitorItemsProperty:set_perform()
	local message = initOutputMessage()
	if istable(tracks) then
		local monitoredTracks, notMonitoredTracks = 0, 0
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECMONITEMS")
			if state == 1 then
				monitoredTracks = monitoredTracks + 1
			else
				notMonitoredTracks = notMonitoredTracks + 1
			end
		end
		local ajustingValue
		if monitoredTracks > notMonitoredTracks then
			ajustingValue = 0
			message("Switching off the monitoring items for selected tracks.")
		elseif monitoredTracks < notMonitoredTracks then
			ajustingValue = 1
			message("Switching on the monitoring items for selected tracks.")
		else
			ajustingValue = 0
			message("Switching off the monitoring items for selected tracks.")
		end
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "I_RECMONITEMS", ajustingValue)
		end
	else
		local state = nor(reaper.GetMediaTrackInfo_Value(tracks, "I_RECMONITEMS"))
		reaper.SetMediaTrackInfo_Value(tracks, "I_RECMONITEMS", state)
	end
	message(self:get())
	return message
end

-- Track performance settings: buffering media
local performanceBufferingProperty = {}
parentLayout.playbackLayout:registerProperty(performanceBufferingProperty)
performanceBufferingProperty.states = { [0] = "enabled", [1] = "disabled" }

function performanceBufferingProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to switch the track performance buffering media of selected track.", "Toggleable")
	if multiSelectionSupport == true then
		message:addType(" If the group of tracks has been selected, the buffering media state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message({ label = "Media buffering" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_PERFFLAGS") & 1 end
			, self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_PERFFLAGS") & 1
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function performanceBufferingProperty:set_perform()
	local message = initOutputMessage()
	if istable(tracks) then
		local bufferedTracks, notBufferedTracks = 0, 0
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS") & 1
			if state == 1 then
				notBufferedTracks = notBufferedTracks + 1
			else
				bufferedTracks = bufferedTracks + 1
			end
		end
		local ajustingValue
		if bufferedTracks > notBufferedTracks then
			ajustingValue = 1
			message("Switching off the media buffering for selected tracks.")
		elseif bufferedTracks < notBufferedTracks then
			ajustingValue = 0
			message("Switching on the media buffering for selected tracks.")
		else
			ajustingValue = 0
			message("Switching on the media buffering for selected tracks.")
		end
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS")
			if ajustingValue == 0 then
				reaper.SetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS", state & ~1)
			elseif ajustingValue == 1 then
				reaper.SetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS", state | 1)
			end
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_PERFFLAGS")
		reaper.SetMediaTrackInfo_Value(tracks, "I_PERFFLAGS", state ~ 1)
	end
	message(self:get())
	return message
end

-- Track performance settings: Anticipative FX
local performanceAnticipativeFXProperty = {}
parentLayout.playbackLayout:registerProperty(performanceAnticipativeFXProperty)
performanceAnticipativeFXProperty.states = { [0] = "enabled", [2] = "disabled" }

function performanceAnticipativeFXProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to switch the track performance FX anticipativeness of selected track.",
		"Toggleable")
	if multiSelectionSupport == true then
		message:addType(" If the group of tracks has been selected, the FX anticipativeness state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message({ label = "FX anticipative" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_PERFFLAGS") & 2 end
			, self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_PERFFLAGS") & 2
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function performanceAnticipativeFXProperty:set_perform()
	local message = initOutputMessage()
	if istable(tracks) then
		local anticipatedTracks, notanticipatedTracks = 0, 0
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS") & 2
			if state == 2 then
				notanticipatedTracks = notanticipatedTracks + 1
			else
				anticipatedTracks = anticipatedTracks + 1
			end
		end
		local ajustingValue
		if anticipatedTracks > notanticipatedTracks then
			ajustingValue = 2
			message("Switching off the anticipativeness FX for selected tracks.")
		elseif anticipatedTracks < notanticipatedTracks then
			ajustingValue = 0
			message("Switching on the anticipativeness FX for selected tracks.")
		else
			ajustingValue = 0
			message("Switching on the anticipativeness FX for selected tracks.")
		end
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS")
			if ajustingValue == 0 then
				reaper.SetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS", state & ~2)
			elseif ajustingValue == 2 then
				reaper.SetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS", state | 2)
			end
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_PERFFLAGS")
		reaper.SetMediaTrackInfo_Value(tracks, "I_PERFFLAGS", state ~ 2)
	end
	message(self:get())
	return message
end

-- Visibility in Mixer panel
local mixerVisibilityProperty = {}
parentLayout.visualLayout:registerProperty(mixerVisibilityProperty)
mixerVisibilityProperty.states = { [0] = "hidden", [1] = "visible" }

function mixerVisibilityProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to switch the visibility of selected track in mixer panel.", "Toggleable")
	if multiSelectionSupport == true then
		message:addType(" If the group of tracks has been selected, the visibility state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message({ label = "Visibility on mixer panel" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "B_SHOWINMIXER") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINMIXER")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function mixerVisibilityProperty:set_perform()
	local message = initOutputMessage()
	if istable(tracks) then
		local visibleTracks, notvisibleTracks = 0, 0
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS") & 2
			if state == 2 then
				visibleTracks = visibleTracks + 1
			else
				notvisibleTracks = notvisibleTracks + 1
			end
		end
		local ajustingValue
		if visibleTracks > notvisibleTracks then
			ajustingValue = 0
			message("Hidding selected tracks on mixer panel.")
		elseif visibleTracks < notvisibleTracks then
			ajustingValue = 1
			message("Showing selected tracks on mixer panel.")
		else
			ajustingValue = 0
			message("Hidding selected tracks on mixer panel.")
		end
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "B_SHOWINMIXER", ajustingValue)
		end
	else
		local state = nor(reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINMIXER"))
		reaper.SetMediaTrackInfo_Value(tracks, "B_SHOWINMIXER", state)
	end
	message(self:get())
	return message
end

-- Visibility in TCP
local tcpVisibilityProperty = {}
parentLayout.visualLayout:registerProperty(tcpVisibilityProperty)
tcpVisibilityProperty.states = mixerVisibilityProperty.states

function tcpVisibilityProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to switch the visibility of selected track control panel in arange view.",
		"Toggleable")
	if multiSelectionSupport == true then
		message:addType(" If the group of tracks has been selected, the visibility state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message({ label = "Visibility on tracks control panel" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINTCP")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function tcpVisibilityProperty:set_perform()
	local message = initOutputMessage()
	if istable(tracks) then
		local visibleTracks, notvisibleTracks = 0, 0
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS") & 2
			if state == 2 then
				visibleTracks = visibleTracks + 1
			else
				notvisibleTracks = notvisibleTracks + 1
			end
		end
		local ajustingValue
		if visibleTracks > notvisibleTracks then
			ajustingValue = 0
			message("Hidding selected tracks control panels.")
		elseif visibleTracks < notvisibleTracks then
			ajustingValue = 1
			message("Showing selected tracks control panels.")
		else
			ajustingValue = 0
			message("Hidding selected tracks control panels.")
		end
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "B_SHOWINTCP", ajustingValue)
		end
	else
		local state = nor(reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINTCP"))
		reaper.SetMediaTrackInfo_Value(tracks, "B_SHOWINTCP", state)
	end
	message(self:get())
	return message
end

local osaraParamsProperty = {}
parentLayout.visualLayout:registerProperty(osaraParamsProperty)

function osaraParamsProperty:get()
	local message = initOutputMessage()
	message:initType("Perform this property to view the OSARA parameters window for last touched track.")
	-- This property will obey the last touched track cuz the OSARA action works with that only.
	if istable(tracks) then
		message { objectId = "Last touched " }
	end
	message { label = "OSARA parameters" }
	if reaper.GetLastTouchedTrack() then
		message { objectId = getTrackID(reaper.GetLastTouchedTrack()) }
	else
		message { label = " (unavailable)" }
	end
	return message
end

function osaraParamsProperty:set_perform()
	if reaper.GetLastTouchedTrack() then
		reaper.SetCursorContext(0, nil)
		reaper.Main_OnCommand(reaper.NamedCommandLookup("_OSARA_PARAMS"), 0)
		return
	end
	return "This property is unavailable right now because no track touched."
end

local routingViewProperty = {}
parentLayout.visualLayout:registerProperty(routingViewProperty)

function routingViewProperty:get()
	local message = initOutputMessage()
	message:initType("Perform this property to view the routing and input/output options for last touched track")
	local track = reaper.GetLastTouchedTrack()
	if track then
		message { objectId = getTrackID(track) }
	else
		message { value = "(unavailable)" }
	end
	message { label = "Routing and inputs or outputs" }
	return message
end

function routingViewProperty:set_perform()
	if reaper.GetLastTouchedTrack() then
		reaper.Main_OnCommand(40293, 0)
	end
end

local contextMenusProperty = {}
parentLayout.visualLayout:registerProperty(contextMenusProperty)
contextMenusProperty.states = {
	[1] = { label = "Main", cmd = "_OSARA_CONTEXTMENU2"},
	[2] = {label = "Recording", cmd = "_OSARA_CONTEXTMENU1"},
	[3] = {label = "Routing", cmd = "_OSARA_CONTEXTMENU3"}
}

function contextMenusProperty:get()
	local message = initOutputMessage()
	local state = extstate._layout.contextMenuSelector or 1
	local track = reaper.GetLastTouchedTrack()
	message{ value = string.format("%s context menu", self.states[state].label) }
	message:initType("Adjust this property to choose the needed context menu. Perform this property to pop selected up.")
	if track then
		message{ objectId = getTrackID(track) }
	else
		message:addType(" This property is unavailable right now because no track has touched.", 1)
		message:changeType("Unavailable", 2)
	end
	return message
end

function contextMenusProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = extstate._layout.contextMenuSelector or 1
	if self.states[state + direction] then
		extstate._layout.contextMenuSelector = state +direction
	else
		message(string.format("No %s property values.", (direction == 1) and "next" or "previous"))
	end
	message(self:get())
	return message
end

if reaper.GetLastTouchedTrack() then
	function contextMenusProperty:set_perform()
		local state = extstate._layout.contextMenuSelector or 1
		reaper.Main_OnCommand(reaper.NamedCommandLookup(self.states[state].cmd), 0)
	end
end

parentLayout.defaultSublayout = "playbackLayout"

PropertiesRibbon.presentLayout(parentLayout)
