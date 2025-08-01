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
]]
--

package.path = select(2, reaper.get_action_context()):match('^.+[\\//]') .. "?//init.lua"

require "properties_ribbon"

useMacros("track_properties")
useMacros("tools")

-- Preparing all needed configs which will be used not one time
multiSelectionSupport = config.getboolean("multiSelectionSupport", true)

-- For comfort coding, we are making the tracks array as global
tracks = track_properties_macros.getTracks(multiSelectionSupport)

-- These redirections made especially to not rewrite many code
-- We have to define the track reporting by configuration. This function has contained in properties macros.
local getTrackID = track_properties_macros.getTrackID

local parentLayout = PropertiesRibbon.initLayout("Track properties")

-- We have to change the name without patching the section value, so we will change this after layout initializing
if config.getboolean("objectsIdentificationWhenNavigating", true) == false and tracks then
	parentLayout.name = parentLayout.name:join(" for ", track_properties_macros.getTrackIDForTitle(tracks))
end


-- Define the tracks undo context
parentLayout.undoContext = undo.contexts.tracks


-- sublayouts
--Track management properties
parentLayout:registerSublayout("managementLayout", "Management")

-- Playback properties
parentLayout:registerSublayout("playbackLayout", "Playback")

-- Recording properties
parentLayout:registerSublayout("recordingLayout", "Recording")

-- Metering information properties
parentLayout:registerSublayout("meteringLayout", "Metering")



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
]]
--

-- Track name methods
local trackNameProperty = {}
parentLayout.managementLayout:registerProperty(trackNameProperty)

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
parentLayout.managementLayout:registerProperty(folderStateProperty)
folderStateProperty.states = {
	[0] = "track",
	[1] = "folder",
	[2] = "end of folder %s"
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
		message(composeMultipleTrackMessage(function(track)
				return table.concat(
					{
						tostring(reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")),
						tostring(reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")),
						reaper.GetParentTrack(track) and select(2, reaper.GetTrackName(reaper.GetParentTrack(track), ""))
					}, "|")
			end,
			setmetatable({},
				{
					__index = function(self, key)
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
							msg = msg .. string.format(states[2], key:split("|")[3])
						end
						return msg
					end
				})
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
			-- We have to search the track which this end of folder closes
			local isParentTrack = tracks
			for _ = -1, state, -1 do
				isParentTrack = reaper.GetParentTrack(isParentTrack)
				if not isParentTrack then
					break
				end
			end
			message { value = string.format(self.states[2], select(2, reaper.GetTrackName(isParentTrack, ""))) }
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
		if compactState == 0 and not config.getboolean("donotUseSmallFolderState", false) then
			reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERCOMPACT", 1)
		elseif compactState <= 1 then
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

local osaraParamsProperty = {}
parentLayout.managementLayout:registerProperty(osaraParamsProperty)

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
parentLayout.managementLayout:registerProperty(routingViewProperty)

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
parentLayout.managementLayout:registerProperty(contextMenusProperty)
contextMenusProperty.states = {
	[1] = { label = "Main", cmd = "_OSARA_CONTEXTMENU2" },
	[2] = { label = "Recording", cmd = "_OSARA_CONTEXTMENU1" },
	[3] = { label = "Routing", cmd = "_OSARA_CONTEXTMENU3" }
}

function contextMenusProperty:get()
	local message = initOutputMessage()
	local state = extstate._layout.contextMenuSelector or 1
	local track = reaper.GetLastTouchedTrack()
	message { value = string.format("%s context menu", self.states[state].label) }
	message:setValueFocusIndex(state, #self.states)
	message:initType("Adjust this property to choose the needed context menu. Perform this property to pop selected up.")
	if track then
		message { objectId = getTrackID(track) }
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
		extstate._layout.contextMenuSelector = state + direction
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

local volumeProperty = {}
parentLayout.playbackLayout:registerProperty(volumeProperty)
parentLayout.recordingLayout:registerProperty(volumeProperty)

function volumeProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired volume value for selected track.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of track has been selected, the relative of previous value will be applied for each track of."
			, 1)
	end
	message({ label = "volume" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "D_VOL") end,
			representation.db))
	else
		message({
			objectId = getTrackID(tracks),
			value = representation.db
				[reaper.GetMediaTrackInfo_Value(tracks, "D_VOL")]
		})
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

volumeProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Volume extended interraction")

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
			message:addType(
				" If the group of track has been selected, the input value will be applied for each track of.", 1)
		end
		message("Type custom volume value")
		return message
	end,
	set_perform = function(self, parent)
		if istable(tracks) then
			local retval, answer = getUserInputs(string.format("Volume for %u selected tracks", #tracks),
				{
					caption = "New volume value:",
					defValue = representation.db
						[reaper.GetMediaTrackInfo_Value(tracks[1], "D_VOL")]
				},
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

volumeProperty.extendedProperties:registerProperty(composeEnvelopeControlProperty.viaChunk(tracks,
	"VOLENV2,VOLENV,MUTEENV",
	function(track, envName)
		return reaper.GetMediaTrackInfo_Value(track, string.format("P_ENV:<%s", envName))
	end))

local panProperty = {}
parentLayout.playbackLayout:registerProperty(panProperty)
parentLayout.recordingLayout:registerProperty(panProperty)

function panProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired pan value for selected track.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of track has been selected, the relative of previous value will be applied for each track of."
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

panProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Pan extended interraction")

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
			message:addType(
				" If the group of track has been selected, the input value will be applied for each track of.", 1)
		end
		message("Type custom pan value")
		return message
	end,
	set_perform = function(self, parent, action)
		if istable(tracks) then
			local retval, answer = getUserInputs(string.format("Pan for %u selected tracks", #tracks),
				{
					caption = "New pan value:",
					defValue = representation.pan
						[reaper.GetMediaTrackInfo_Value(tracks[1], "D_PAN")]
				},
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

if multiSelectionSupport then
	panProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType(
				"Perform this property to set the sequential pan values for selected tracks."
			)
			if not istable(tracks) then
				message:addType(
					"This property is currently unavailable because you need to select at least two tracks.",
					1)
				message:changeType("unavailable", 2)
			end
			message "Set sequential pan values"
			if istable(tracks) then
				message(string.format(" for %u selected tracks", #tracks))
			end
			return message
		end,
		set_perform = function(self, parent)
			if istable(tracks) then
				local retval, answer = getUserInputs(string.format("Sequential Pan for %u selected tracks", #tracks),
					{
						{
							caption = "Pan value without direction:",
							defValue = representation.pan[reaper.GetMediaTrackInfo_Value(tracks[1], "D_PAN")]:match(
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
				for _, track in ipairs(tracks) do
					local curPanValue = utils.percenttonum(panValue)
					if dirs[dirField] == "l" then
						curPanValue = -curPanValue
					elseif dirs[dirField] == "c" then
						curPanValue = 0
					end
					reaper.SetMediaTrackInfo_Value(track, "D_PAN", curPanValue)
					if dirField < #dirs then
						dirField = dirField + 1
					else
						dirField = 1
					end
				end
				setUndoLabel(parent:get())
				return true
			end
			return false, "You need to select at least two tracks to perform this action."
		end
	}
end

panProperty.extendedProperties:registerProperty(composeEnvelopeControlProperty.viaChunk(tracks, "PANENV2,PANENV",
	function(track, envName)
		return reaper.GetMediaTrackInfo_Value(track, string.format("P_ENV:<%s", envName))
	end))

local widthProperty = {}
parentLayout.playbackLayout:registerProperty(widthProperty)

function widthProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired width value for selected track.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of track has been selected, the relative of previous value will be applied for each track of."
			, 1)
	end
	message({ label = "Width" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "D_WIDTH") end,
			setmetatable({},
				{ __index = function(self, state) return string.format("%s%%", utils.numtopercent(state)) end })))
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

widthProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Width extended interraction")

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
					caption  = "New width value:",
					defValue = string.format("%s%%",
						utils.numtopercent(reaper.GetMediaTrackInfo_Value(tracks[1], "D_WIDTH")))
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

widthProperty.extendedProperties:registerProperty(composeEnvelopeControlProperty.viaChunk(tracks, "WIDTHENV2,WIDTHENV",
	function(track, envName)
		return reaper.GetMediaTrackInfo_Value(track, string.format("P_ENV:<%s", envName))
	end))

local muteProperty = {}
parentLayout.playbackLayout:registerProperty(muteProperty)
muteProperty.states = { [0] = "not muted", [1] = "muted" }

function muteProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to mute or unmute selected track.", "Toggleable")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of tracks has been selected, the mute state will be set to oposite value depending of moreness tracks with the same value."
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
		local ajustingValue = nor(utils.getMostFrequent(tracks, function(track)
			return reaper.GetMediaTrackInfo_Value(track, "B_MUTE")
		end))
		if ajustingValue == 0 then
			message("Unmuting selected tracks.")
		elseif ajustingValue == 1 then
			message("Muting selected tracks.")
		else
			ajustingValue = 0
			message("Unmuting selected tracks.")
		end
		local nonactionable = {}
		for k = 1, #tracks do
			local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_MUTE")
			reaper.SetMediaTrackInfo_Value(tracks[k], "B_MUTE", ajustingValue)
			if state ~= ajustingValue and reaper.GetMediaTrackInfo_Value(tracks[k], "B_MUTE") == state then
				nonactionable[#nonactionable + 1] = getTrackID(tracks[k], true)
			end
		end
		if #nonactionable > 0 then
			message(string.format("%u tracks could not be %s: %s.", #nonactionable, self.states[ajustingValue],
				table.concat(nonactionable, ", ")))
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "B_MUTE")
		reaper.SetMediaTrackInfo_Value(tracks, "B_MUTE", nor(state))
		if reaper.GetMediaTrackInfo_Value(tracks, "B_MUTE") == state then
			message {
				objectId = getTrackID(tracks),
				value = ("Could not be %s."):format(state == 1 and "unmuted" or "muted")
			}
		end
	end
	message(self:get())
	return message
end

local soloProperty = parentLayout.playbackLayout:registerProperty {}
soloProperty.states = {
	[0] = "not soloed",
	[1] = "soloed",
	[2] = "soloed in place",
	[5] = "safe soloed",
	[6] = "safe soloed in place"
}

function soloProperty.getValue(obj)
	return reaper.GetMediaTrackInfo_Value(obj, "I_SOLO")
end

function soloProperty.setValue(obj, value)
	reaper.SetMediaTrackInfo_Value(obj, "I_SOLO", value)
end

function soloProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to choose needed solo mode for selected tracks. "
		, "Adjustable, toggleable")
	if multiSelectionSupport == true then
		message:addType(
			string.format(
				' If the group of tracks has been selected, the value will enumerate only if selected tracks have the same value. Otherwise, the solo state will be set to "%s", then will enumerate this.'
				, self.states[0]), 1)
	end
	message:addType(" Toggle this property to solo or unsolo selected track ", 1)
	if config.getboolean("obeyConfigSolo", true) then
		message:addType("using default configuration of solo-in-place set in REAPER preferences", 1)
	else
		message:addType("by selected mode via adjusting", 1)
	end
	if config.getboolean("exclusiveSolo", false) then
		message:addType(" exclusively, i.e. only selected track will be soloed", 1)
	end
	message:addType(".", 1)
	if multiSelectionSupport == true then
		message:addType(
			" If the group of tracks has been selected, the solo state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
		if config.getboolean("exclusiveSolo", false) then
			message:addType(" The exclusive mode also applies for group of selected tracks.", 1)
		end
	end
	if istable(tracks) then
		message({ label = "Solo" })
		message(composeMultipleTrackMessage(self.getValue, self.states))
	else
		local state = self.getValue(tracks)
		message({ objectId = getTrackID(tracks), value = self.states[state] })
		message:setValueFocusIndex(state + 1, #self.states + 1)
	end
	return message
end

function soloProperty:set_perform()
	local message = initOutputMessage()
	local soloMode
	if config.getboolean("obeyConfigSolo", true) then
		local retval, soloInConfig = reaper.get_config_var_string("soloip")
		if retval then
			soloMode = tonumber(soloInConfig) + 1
		else
			soloMode = 1
		end
	else
		soloMode = extstate.lastSoloMode or 1
	end
	local isExclusiveSolo = config.getboolean("exclusiveSolo", false)
	local checkedTrackslist = {}
	if istable(tracks) then
		local ajustingValue = utils.getMostFrequent(tracks, self.getValue)
		if ajustingValue > 0 then
			ajustingValue = 0
			message("Unsoloing selected tracks.")
		elseif ajustingValue == 0 then
			ajustingValue = soloMode
			message("Soloing selected tracks.")
			if isExclusiveSolo then
				for i = 0, reaper.CountTracks(0) - 1 do
					local track = reaper.GetTrack(0, i)
					if not table.containsv(istable(tracks) and tracks or { tracks }, track) then
						if self.getValue(track) ~= 0 then
							table.insert(checkedTrackslist, track)
						end
					end
				end
			end
		else
			ajustingValue = 0
			message("Unsoloing selected tracks.")
		end
		for k = 1, #tracks do
			self.setValue(tracks[k], ajustingValue)
		end
	else
		local state = self.getValue(tracks)
		if state > 0 then
			state = 0
		else
			state = soloMode
			if isExclusiveSolo then
				for i = 0, reaper.CountTracks(0) - 1 do
					local track = reaper.GetTrack(0, i)
					if not table.containsv(istable(tracks) and tracks or { tracks }, track) then
						if self.getValue(track) ~= 0 then
							table.insert(checkedTrackslist, track)
						end
					end
				end
			end
		end
		self.setValue(tracks, state)
	end
	message(self:get())
	message:clearValueFocusIndex()
	if isExclusiveSolo and #checkedTrackslist > 0 then
		message { value = " exclusive" }
		reaper.PreventUIRefresh(1)
		for _, track in ipairs(checkedTrackslist) do
			self.setValue(track, 0)
		end
		reaper.PreventUIRefresh(-1)
	end
	return message
end

function soloProperty:set_adjust(direction)
	local message = initOutputMessage()
	if istable(tracks) then
		local allIsSame = true
		for idx, track in ipairs(tracks) do
			local state = self.getValue(track)
			if idx > 1 then
				local prevstate = self.getValue(tracks[idx - 1])
				if state ~= prevstate then
					allIsSame = false
					break
				end
			end
		end
		local state = nil
		if allIsSame == true then
			state = self.getValue(tracks[1])
			if (state + direction) >= 0 and (state + direction) <= #self.states then
				state = state + direction
			end
		else
			state = 0
		end
		message(string.format("Set all selected tracks solo to %s.", self.states[state]))
		for _, track in ipairs(tracks) do
			self.setValue(track, state)
		end
		if state ~= 0 then
			extstate.lastSoloMode = state
		end
	else
		local state = self.getValue(tracks)
		if state + direction > #self.states then
			message "No more next property values. "
		elseif state + direction < 0 then
			message "No more previous property values. "
		else
			state = state + direction
		end
		self.setValue(tracks, state)
		if state ~= 0 then
			extstate.lastSoloMode = state
		end
	end
	message(self:get())
	return message
end

local recarmProperty = parentLayout.recordingLayout:registerProperty {}
recarmProperty.states = { [0] = "not armed", [1] = "armed" }

function recarmProperty.getValue(track)
	return reaper.GetMediaTrackInfo_Value(track, "I_RECARM")
end

function recarmProperty.setValue(track, state)
	reaper.SetMediaTrackInfo_Value(track, "I_RECARM", state)
end

function recarmProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to arm or disarm selected track for record", "Toggleable")
	if config.getboolean("exclusiveArm", false) then
		message:addType(" exclusively, i.e. only selected track will be soloed", 1)
	end
	message:addType(".", 1)
	if multiSelectionSupport == true then
		message:addType(
			" If the group of tracks has been selected, the record state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
		if config.getboolean("exclusiveSolo", false) then
			message:addType(" The exclusive mode also applies for group of selected tracks.", 1)
		end
	end
	if istable(tracks) then
		message({ label = "Arm" })
		message(composeMultipleTrackMessage(self.getValue, self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECARM")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
	end
	return message
end

function recarmProperty:set_perform()
	local message = initOutputMessage()
	local isExclusiveArm = config.getboolean("exclusiveArm", false)
	local checkedTrackslist = {}
	if istable(tracks) then
		local ajustingValue = utils.getMostFrequent(tracks, self.getValue)
		if ajustingValue == 1 then
			ajustingValue = 0
			message("Unarming selected tracks.")
		elseif ajustingValue == 0 then
			ajustingValue = 1
			message("Arming selected tracks.")
			if isExclusiveArm then
				for i = 0, reaper.CountTracks(0) - 1 do
					local track = reaper.GetTrack(0, i)
					if not table.containsv(istable(tracks) and tracks or { tracks }, track) then
						if self.getValue(track) ~= 0 then
							table.insert(checkedTrackslist, track)
						end
					end
				end
			end
		else
			ajustingValue = 0
			message("Unarming selected tracks.")
		end
		for k = 1, #tracks do
			self.setValue(tracks[k], ajustingValue)
		end
	else
		local state = nor(self.getValue(tracks))
		self.setValue(tracks, state)
		if state ~= 0 and isExclusiveArm then
			for i = 0, reaper.CountTracks(0) - 1 do
				local track = reaper.GetTrack(0, i)
				if not table.containsv(istable(tracks) and tracks or { tracks }, track) then
					if self.getValue(track) ~= 0 then
						table.insert(checkedTrackslist, track)
					end
				end
			end
		end
	end
	message(self:get())
	if isExclusiveArm and #checkedTrackslist > 0 then
		message { value = " exclusive" }
		reaper.PreventUIRefresh(1)
		for _, track in ipairs(checkedTrackslist) do
			self.setValue(track, 0)
		end
		reaper.PreventUIRefresh(-1)
	end
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
		message:addType(
			string.format(
				' If the group of track has been selected, the value will enumerate only if selected tracks have the same value. Otherwise, the record monitoring state will be set to "%s" first, then will enumerate this.'
				, self.states[1]), 1)
	end
	message({ label = "Record monitoring" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECMON") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMON")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
		message:setValueFocusIndex(state + 1, #self.states + 1)
	end
	return message
end

function recmonitoringProperty:set_adjust(direction)
	local message = initOutputMessage()
	if istable(tracks) then
		if utils.isAllTheSame(tracks, function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECMON") end) then
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
		local channel = bitwise.getRange(val, 1, 5)
		if channel == 0 then
			message("all channels, ")
		else
			message(string.format("channel %u, ", channel))
		end
		if bitwise.getRange(val, 6, 12) == 62 then
			message("from Virtual MIDI Keyboard")
		elseif bitwise.getRange(val, 6, 12) == 63 then
			message("from all devices")
		else
			local result, name = recInputsProperty.getMIDIInputName(bitwise.getRange(val, 6, 12))
			if result == true then
				message(string.format("from %s", name))
			else
				message(string.format("from unknown device with ID %u", bitwise.getRange(val, 6, 12)))
			end
		end
	else
		message("audio, ")
		local input = bitwise.getRange(val, 1, 11)
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
				inputs[i + 1024] = string.format("%s/%s", reaper.GetInputChannelName(i),
					reaper.GetInputChannelName(i + 1))
			end
			message(string.format("stereo, %s", inputs[input]))
		end
	end
	return message:extract()
end

function recInputsProperty.calc(state, action)
	if action == 1 then
		if (state + 1) >= 0 and (state + 1) < 1024 then
			if reaper.GetInputChannelName(bitwise.getRange(state + 1, 1, 11)) then
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
					local channel = bitwise.getRange(i, 1, 5)
					local result, _ = recInputsProperty.getMIDIInputName(bitwise.getRange(i, 6, 12))
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
				local channel = bitwise.getRange(i, 1, 5)
				local result, _ = recInputsProperty.getMIDIInputName(bitwise.getRange(i, 6, 12))
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
				local channel = bitwise.getRange(i, 1, 5)
				local result, _ = recInputsProperty.getMIDIInputName(bitwise.getRange(i, 6, 12))
				if result == true and channel <= 16 then
					return i
				end
				if i == 4096 then
					local inputs = {}
					for i = 1, reaper.GetNumAudioInputs() - 1 do
						inputs[i] = string.format("%s/%s", reaper.GetInputChannelName(i - 1),
							reaper.GetInputChannelName(i))
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
				local channel = bitwise.getRange(i, 1, 5)
				local result, _ = recInputsProperty.getMIDIInputName(bitwise.getRange(i, 6, 12))
				if result == true and channel <= 16 then
					return i
				end
				if i == 8192 then
					return -1
				end
			end
		elseif state > 4096 then
			local result, device = recInputsProperty.getMIDIInputName(bitwise.getRange(state, 6, 12))
			if result == true then
				for i = state, 8192 do
					local curResult, curDevice = recInputsProperty.getMIDIInputName(bitwise.getRange(i, 6, 12))
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
	message:initType("Adjust this property to choose the desired record input of selected track.",
		"Adjustable, toggleable")
	if multiSelectionSupport == true then
		message:addType((
			' If the group of track has been selected, the value will enumerate up if selected tracks have the same value. If one of tracks has different value, all track will set to "%s" first, then will enumerate up this.'
		):format(self.compose(0)), 1)
	end
	message:addType(" Toggle this property to quick switch between input categories (mono, stereo or midi).", 1)
	if multiSelectionSupport == true then
		message:addType(
			" If the group of track has been selected, the quick switching will aplied for selected tracks by first selected track."
			, 1)
	end
	message({ label = "record input" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(
			function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECINPUT") end,
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
		ajustingValue = utils.isAllTheSame(tracks, function(track)
			return reaper.GetMediaTrackInfo_Value(track, "I_RECINPUT")
		end) and ajustingValue or 0
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
		message:addType(
			string.format(
				' If the group of track has been selected, The value will enumerate only if selected tracks have the same value. Otherwise, the record mode state will be set to "%s", then will enumerate this.'
				, self.states[1]), 1)
	end
	message({ label = "Record mode" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(
			function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECMODE") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMODE")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
		message:setValueFocusIndex(state + 1, #self.states + 1)
	end
	return message
end

function recmodeProperty:set_adjust(direction)
	local message = initOutputMessage()
	if istable(tracks) then
		local state
		if utils.isAllTheSame(tracks, function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECMODE") end) then
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
		message:addType(
			string.format(
				' If the group of track has been selected, The value will enumerate only if selected tracks have the same value. Otherwise, the automation mode state will be set to "%s", then will enumerate this.'
				, self.states[1]), 1)
	end
	message({ label = "Automation mode" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(
			function(track) return reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE") end,
			self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "I_AUTOMODE")
		message({ objectId = getTrackID(tracks), value = self.states[state] })
		message:setValueFocusIndex(state + 1, #self.states + 1)
	end
	return message
end

function automationModeProperty:set_adjust(direction)
	local message = initOutputMessage()
	if istable(tracks) then
		local state
		if utils.isAllTheSame(tracks, function(track) return reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE") end) then
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
		message:addType(
			" If the group of tracks has been selected, the phase polarity state will be set to oposite value depending of moreness tracks with the same value."
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
		local ajustingValue = nor(utils.getMostFrequent(tracks,
			function(track) return reaper.GetMediaTrackInfo_Value(track, "B_PHASE") end))
		if ajustingValue == 0 then
			message("Set all track phase to normal.")
		elseif ajustingValue == 1 then
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
		message:addType(
			" If the group of tracks has been selected, the send state will be set to oposite value depending of moreness tracks with the same value."
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
		local ajustingValue = nor(utils.getMostFrequent(tracks, function(track)
			return reaper.GetMediaTrackInfo_Value(track, "B_MAINSEND")
		end))
		if ajustingValue == 0 then
			message("Switching off selected tracks send to parent or master track.")
		elseif ajustingValue == 1 then
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
		message:addType(
			" If the group of tracks has been selected, the free mode state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message({ label = "Free position" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(
			function(track) return reaper.GetMediaTrackInfo_Value(track, "B_FREEMODE") end,
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
		local ajustingValue = nor(utils.getMostFrequent(tracks, function(track)
			return reaper.GetMediaTrackInfo_Value(track, "B_FREEMODE")
		end))
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
		message:addType(
			string.format(
				' If the group of tracks has been selected, the value will enumerate only if selected tracks have the same value. Otherwise, the timebase state will be set to "%s", then will enumerate this.'
				, self.states[0]), 1)
	end
	message({ label = "Timebase" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(
			function(track) return reaper.GetMediaTrackInfo_Value(track, "C_BEATATTACHMODE") end
			, self.states, 1))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "C_BEATATTACHMODE")
		message({ objectId = getTrackID(tracks), value = self.states[state + 1] })
		message:setValueFocusIndex(state + 2, #self.states + 1)
	end
	return message
end

function timebaseProperty:set_adjust(direction)
	local message = initOutputMessage()
	if istable(tracks) then
		local state
		if utils.isAllTheSame(tracks, function(track) return reaper.GetMediaTrackInfo_Value(track, "C_BEATATTACHMODE") end) then
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
		message:addType(
			" If the group of tracks has been selected, the monitor items state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message({ label = "Items monitoring while recording" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(
			function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECMONITEMS") end,
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
		local ajustingValue = nor(utils.getMostFrequent(tracks, function(track)
			return reaper.GetMediaTrackInfo_Value(track, "I_RECMONITEMS")
		end))
		if ajustingValue == 0 then
			message("Switching off the monitoring items for selected tracks.")
		elseif ajustingValue == 1 then
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
	message:initType("Toggle this property to switch the track performance buffering media of selected track.",
		"Toggleable")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of tracks has been selected, the buffering media state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message({ label = "Media buffering" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(
			function(track) return reaper.GetMediaTrackInfo_Value(track, "I_PERFFLAGS") & 1 end
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
		local ajustingValue = nor(utils.getMostFrequent(tracks, function(track)
			return reaper.GetMediaTrackInfo_Value(track, "I_PERFFLAGS") & 1
		end))
		if ajustingValue == 1 then
			message("Switching off the media buffering for selected tracks.")
		elseif ajustingValue == 0 then
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
		message:addType(
			" If the group of tracks has been selected, the FX anticipativeness state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message({ label = "FX anticipative" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(
			function(track) return reaper.GetMediaTrackInfo_Value(track, "I_PERFFLAGS") & 2 end
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
		local ajustingValue = utils.getMostFrequent(tracks, function(track)
			return reaper.GetMediaTrackInfo_Value(track, "I_PERFFLAGS") & 2
		end) == 2 and 0 or 2
		if ajustingValue == 2 then
			message("Switching off the anticipativeness FX for selected tracks.")
		elseif ajustingValue == 0 then
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

-- Posibility to marque tracks for solo defeat property
local soloDefeatProperty = {}
parentLayout.managementLayout:registerProperty(soloDefeatProperty)
soloDefeatProperty.states = { [0] = "not defeated", [1] = "defeated" }

function soloDefeatProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to switch the solo defeat state of selected track.", "Toggleable")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of tracks has been selected, the defeat state will be set to oposite value depending of moreness tracks with the same value.",
			1)
	end
	message { label = "Solo" }
	if istable(tracks) then
		message(composeMultipleTrackMessage(
			function(track) return reaper.GetMediaTrackInfo_Value(track, "B_SOLO_DEFEAT") end
			, self.states))
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "B_SOLO_DEFEAT")
		message { objectId = getTrackID(tracks), value = self.states[state] }
	end
	return message
end

function soloDefeatProperty:set_perform()
	local message = initOutputMessage()
	if istable(tracks) then
		local ajustingValue = nor(utils.getMostFrequent(tracks, function(track)
			return reaper.GetMediaTrackInfo_Value(track, "B_SOLO_DEFEAT")
		end))
		if ajustingValue == 1 then
			message("Switching on the solo defeat state for selected tracks.")
		elseif ajustingValue == 0 then
			message("Switching off the solo defeat state for selected tracks.")
		else
			ajustingValue = 0
			message("Switching off the solo defeat state for selected tracks.")
		end
		for k = 1, #tracks do
			reaper.SetMediaTrackInfo_Value(tracks[k], "B_SOLO_DEFEAT", ajustingValue)
		end
	else
		local state = reaper.GetMediaTrackInfo_Value(tracks, "B_SOLO_DEFEAT")
		reaper.SetMediaTrackInfo_Value(tracks, "B_SOLO_DEFEAT", state ~ 1)
	end
	message(self:get())
	return message
end

-- Visibility in Mixer panel
local mixerVisibilityProperty = {}
parentLayout.managementLayout:registerProperty(mixerVisibilityProperty)
mixerVisibilityProperty.states = { [0] = "hidden", [1] = "visible" }

function mixerVisibilityProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to switch the visibility of selected track in mixer panel.", "Toggleable")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of tracks has been selected, the visibility state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message({ label = "Visibility on mixer panel" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(
			function(track) return reaper.GetMediaTrackInfo_Value(track, "B_SHOWINMIXER") end,
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
		local ajustingValue = nor(utils.getMostFrequent(tracks, function(track)
			return reaper.GetMediaTrackInfo_Value(track, "B_SHOWINMIXER")
		end))
		if ajustingValue == 0 then
			message("Hidding selected tracks on mixer panel.")
		elseif ajustingValue == 1 then
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
parentLayout.managementLayout:registerProperty(tcpVisibilityProperty)
tcpVisibilityProperty.states = mixerVisibilityProperty.states

function tcpVisibilityProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to switch the visibility of selected track control panel in arange view.",
		"Toggleable")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of tracks has been selected, the visibility state will be set to oposite value depending of moreness tracks with the same value."
			, 1)
	end
	message({ label = "Visibility on tracks control panel" })
	if istable(tracks) then
		message(composeMultipleTrackMessage(
			function(track) return reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") end,
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
		local ajustingValue = nor(utils.getMostFrequent(tracks, function(track)
			return reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP")
		end))
		if ajustingValue == 0 then
			message("Hidding selected tracks control panels.")
		elseif ajustingValue == 1 then
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

-- Track loudness meter
local loudnessHoldMeterProperty = parentLayout.meteringLayout:registerProperty {}
loudnessHoldMeterProperty.states = setmetatable({}, {
	__index = function(self, value)
		if value <= -1.50 then
			return "INF"
		else
			return string.format("%.2f", value / 0.01)
		end
	end
})

function loudnessHoldMeterProperty.meterIsEnabled(track)
	return reaper.GetMediaTrackInfo_Value(track, "I_VUMODE") & 1 ~= 1
end

function loudnessHoldMeterProperty.getMode(track)
	local modeStruct = {}
	local curmode = reaper.GetMediaTrackInfo_Value(track, "I_VUMODE") & 30
	modeStruct.id = curmode
	if curmode == 0 then
		modeStruct.name = "Stereo peaks"
		modeStruct.channels = {
			{ id = 0, name = "left" },
			{ id = 1, name = "right" }
		}
	elseif curmode == 2 then
		modeStruct.name = "Multi-channel peaks"
		modeStruct.channels = {}
		for i = 0, reaper.GetMediaTrackInfo_Value(track, "I_NCHAN") - 1 do
			table.insert(modeStruct.channels,
				{ id = i, name = string.format("channel %u", i + 1) }
			)
		end
	elseif curmode == 4 then
		modeStruct.name = "Stereo RMS"
		modeStruct.channels = {
			{ id = 1024, name = "left" },
			{ id = 1025, name = "right" }
		}
	elseif curmode == 8 then
		modeStruct.name = "Combined RMS"
		modeStruct.channels = {
			{ id = 1024, name = "" }
		}
	elseif curmode == 12 then
		modeStruct.name = "Loudness momentary"
		modeStruct.channels = {
			{ id = 1024, name = "" }
		}
	elseif curmode == 16 then
		modeStruct.name = "Loudness short-term (max)"
		modeStruct.channels = {
			{ id = 1024, name = "" }
		}
	elseif curmode == 20 then
		modeStruct.name = "Loudness short-term (current)"
		modeStruct.channels = {
			{ id = 1024, name = "" }
		}
	end
	return modeStruct
end

function loudnessHoldMeterProperty:get()
	local message = initOutputMessage()
	message:initType("Read this property to inquire the hold peak or loudness meter value of selected track.")
	if multiSelectionSupport == true then
		message:addType(
			" If the group of tracks selected, it will report all tracks values.", 1
		)
	end
	message:addType(" Adjust this property to choose needed channel for watching.", 1)
	message:addType(" Perform this property to reset the peak values for selected channels.", 1)
	local curChannel = extstate._layout.meterChannel or 1
	if istable(tracks) then
		message { label = "Tracks held meters" }
		message(composeMultipleTrackMessage(
			function(track)
				local mode = self.getMode(track)
				local submessage = initOutputMessage()
				if self.meterIsEnabled(track) then
					submessage(mode.name:join(": "))
					if curChannel > 1 then
						local channel = mode.channels[curChannel - 1] or mode.channels[#mode.channels - 1]
						submessage(string.format("%s%s %s", channel.name and channel.name .. " " or "",
							self.states[reaper.Track_GetPeakHoldDB(track, channel.id, false)],
							mode.id < 10 and "dB" or "LU"))
					else
						for _, channel in ipairs(mode.channels) do
							submessage(string.format("%s%s %s, ", channel.name and channel.name .. " " or "",
								self.states[reaper.Track_GetPeakHoldDB(track, channel.id, false)],
								mode.id < 10 and "dB" or "LU"))
						end
						-- Clearing off the extra coma chars
						submessage.msg = submessage.msg:sub(1, -2)
					end
				else
					submessage "Meter disabled"
				end
				return submessage:extract(false)
			end,
			setmetatable({}, {
				__index = function(self, key)
					return key
				end
			})
		))
	else
		message { objectId = getTrackID(tracks) }
		local mode = self.getMode(tracks)
		if self.meterIsEnabled(tracks) then
			message { label = string.format("Hold meter %s", mode.name) }
			if curChannel > 1 then
				local channel = mode.channels[curChannel - 1] or mode.channels[#mode.channels - 1]
				message { value = string.format("%s%s %s", channel.name and channel.name .. " " or "", self.states[reaper.Track_GetPeakHoldDB(tracks, channel.id, false)], mode.id < 10 and "dB" or "LU") }
			else
				for _, channel in ipairs(mode.channels) do
					message { value = string.format("%s%s %s, ", channel.name and channel.name .. " " or "", self.states[reaper.Track_GetPeakHoldDB(tracks, channel.id, false)], mode.id < 10 and "dB" or "LU") }
				end
				-- Clearing off the extra coma chars
				message.value = message.value:sub(1, -2)
			end
			if mode.id < 5 then
				message:setValueFocusIndex(curChannel, #mode.channels + 1)
			end
		else
			message { label = "Meter", value = "Disabled" }
		end
	end
	return message
end

function loudnessHoldMeterProperty:set_adjust(direction)
	local message = initOutputMessage()
	local curChannel = extstate._layout.meterChannel or 1
	if curChannel + direction == 1 then
		message "All channels"
		curChannel = 1
	elseif curChannel + direction ~= 1 then
		local mode = self.getMode(tracks)
		if #mode.channels > 1 then
			if curChannel + direction > #mode.channels + 1 then
				message "No more channels in this meter mode. "
				curChannel = #mode.channels + 1
			elseif curChannel + direction <= 0 then
				curChannel = 1
				message "No more previous property values. "
			else
				curChannel = curChannel + direction
			end
		end
	end
	extstate._layout.meterChannel = curChannel
	message(self:get())
	return message
end

function loudnessHoldMeterProperty:set_perform()
	local message = initOutputMessage()
	local curChannel = extstate._layout.meterChannel or 1
	if istable(tracks) then
		for _, track in ipairs(tracks) do
			local mode = self.getMode(track)
			if curChannel == 1 then
				for _, channel in ipairs(mode.channels) do
					reaper.Track_GetPeakHoldDB(track, channel.id, true)
				end
			else
				local channel = mode.channels[curChannel - 1] or mode.channels[#mode.channels - 1]
				reaper.Track_GetPeakHoldDB(track, channel.id, true)
			end
		end
		message "Reset for all selected tracks."
	else
		local mode = self.getMode(tracks)
		if curChannel == 1 then
			for _, channel in ipairs(mode.channels) do
				reaper.Track_GetPeakHoldDB(tracks, channel.id, true)
			end
		else
			local channel = mode.channels[curChannel - 1] or mode.channels[#mode.channels - 1]
			reaper.Track_GetPeakHoldDB(tracks, channel.id, true)
		end
	end
	message "Reset."
	message(self:get())
	return message
end

-- Sends/receives/hardware outputs realisation
local shrCats = { 1, 0, -1 }
local shrCatNames = {
	[-1] = "Receive",
	[0] = "Send",
	[1] = "Hardware output"
}
for _, track in ipairs(istable(tracks) and tracks or { tracks }) do
	for _, category in ipairs(shrCats) do
		for i = 0, reaper.GetTrackNumSends(track, category) - 1 do
			local _, shrName = ({
				[0] = reaper.GetTrackSendName,
				[-1] = reaper.GetTrackReceiveName,
				[1] = reaper.GetTrackSendName
			})[category](track, i + (category == 0 and reaper.GetTrackNumSends(track, 1) or 0))
			local shrID = string.format("%s%u_track%u", utils.removeSpaces(shrCatNames[category]), i,
				reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
			local shrLabel = shrCatNames[category]
			if istable(tracks) then
				shrLabel = shrLabel:joinsep(" ", "from",
					category < 0 and shrName or select(2, reaper.GetTrackName(track, "")),
					"to",
					category < 0 and select(2, reaper.GetTrackName(track, "")) or shrName)
			else
				shrLabel = shrLabel:joinsep(" ", category >= 0 and "to" or "from", shrName)
			end
			parentLayout:registerSublayout(shrID, shrLabel)
			local shrVolumeProperty = parentLayout[shrID]:registerProperty {
				track = track,
				idx = i,
				type = category,
				typeName = shrCatNames[category]
			}
			function shrVolumeProperty:get()
				local message = initOutputMessage()
				message:initType(string.format(
					"Adjust this property to set the desired volume value for this %s.", self.typeName))
				message { objectId = self.typeName, label = "Volume" }
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "D_VOL")
				message { value = representation.db[state] }
				return message
			end

			function shrVolumeProperty:set_adjust(direction)
				local message = initOutputMessage()
				local ajustStep = config.getinteger("dbStep", 0.1)
				local maxDBValue = config.getinteger("maxDBValue", 12.0)
				if direction == actions.set.decrease.direction then
					ajustStep = -ajustStep
				end
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "D_VOL")
				state = utils.decibelstonum(utils.numtodecibels(state) + ajustStep)
				if utils.numtodecibels(state) < -150.0 then
					state = utils.decibelstonum(-150.0)
					message("Minimum volume. ")
				elseif utils.numtodecibels(state) > maxDBValue then
					state = utils.decibelstonum(maxDBValue)
					message("maximum volume. ")
				end
				reaper.SetTrackSendInfo_Value(self.track, self.type, self.idx, "D_VOL", state)
				message(self:get())
				return message
			end

			shrVolumeProperty.extendedProperties = PropertiesRibbon.initExtendedProperties(
				"Volume extended interraction")

			shrVolumeProperty.extendedProperties:registerProperty(composeThreePositionProperty(
				i,
				{
					representation = representation.db,
					min = utils.decibelstonum("-inf"),
					rootmean = utils.decibelstonum(0.00),
					max = utils.decibelstonum(config.getinteger("maxDBValue", 12.0))
				},
				tpMessages,
				function(obj, value)
					reaper.SetTrackSendInfo_Value(track, category, obj, "D_VOL",
						value)
				end
			))

			shrVolumeProperty.extendedProperties:registerProperty {
				get = function(self, parent)
					local message = initOutputMessage()
					message:initType("Perform this property to type the volume value manualy.")
					message("Type custom volume value")
					return message
				end,
				set_perform = function(self, parent)
					local state = reaper.GetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "D_VOL")
					local retval, answer = getUserInputs(string.format("Volume for %s",
							string.format("send%s to%s",
								istable(tracks) and string.format(" from %s", select(2, reaper.GetTrackName(track, ""))) or
								"", shrName)),
						{ caption = "New volume value:", defValue = representation.db[state] },
						prepareUserData.db.formatCaption)
					if not retval then
						return false
					end
					state = prepareUserData.db.process(answer, state)
					if state then
						reaper.SetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "D_VOL", state)
						setUndoLabel(parent:get())
						return true
					end
				end
			}

			shrVolumeProperty.extendedProperties:registerProperty(composeEnvelopeControlProperty.viaChunk(i,
				"VOLENV,MUTEENV",
				function(shr, envName)
					return reaper.GetTrackSendInfo_Value(track, category, shr,
						string.format("P_ENV:<%s", envName))
				end))

			local shrPanProperty = parentLayout[shrID]:registerProperty {
				track = track,
				idx = i,
				type = category,
				typeName = shrCatNames[category]
			}

			function shrPanProperty:get()
				local message = initOutputMessage()
				message:initType(string.format("Adjust this property to set the desired pan value for this %s.",
					self.typeName))
				message { label = "Pan", objectId = self.typeName }
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "D_PAN")
				message({ value = representation.pan[state] })
				return message
			end

			function shrPanProperty:set_adjust(direction)
				local message = initOutputMessage()
				local ajustingValue = config.getinteger("percentStep", 1)
				ajustingValue = utils.percenttonum(ajustingValue)
				if direction == actions.set.decrease.direction then
					ajustingValue = -ajustingValue
				end
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "D_PAN")
				state = math.round((state + ajustingValue), 3)
				if state < -1 then
					state = -1
					message("Left boundary. ")
				elseif state > 1 then
					state = 1
					message("Right boundary. ")
				end
				reaper.SetTrackSendInfo_Value(self.track, self.type, self.idx, "D_PAN", state)
				message(self:get())
				return message
			end

			shrPanProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Pan extended interraction")

			shrPanProperty.extendedProperties:registerProperty(composeThreePositionProperty(
				i,
				{
					representation = representation.pan,
					min = utils.percenttonum(-100),
					rootmean = utils.percenttonum(0),
					max = utils.percenttonum(100)
				},
				tpMessages,
				function(obj, value)
					reaper.SetTrackSendInfo_Value(track, category, obj, "D_PAN", value)
				end
			))

			shrPanProperty.extendedProperties:registerProperty({
				get = function(self, parent)
					local message = initOutputMessage()
					message:initType("Perform this property to type the custom pan value.")
					message("Type custom pan value")
					return message
				end,
				set_perform = function(self, parent, action)
					local state = reaper.GetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "D_PAN")
					local retval, answer = getUserInputs(string.format("Pan for %s",
							string.format("send%s to%s",
								istable(tracks) and string.format(" from %s", select(2, reaper.GetTrackName(track, ""))) or
								"", shrName)),
						{ caption = "New pan value:", defValue = representation.pan[state] },
						prepareUserData.pan.formatCaption)
					if not retval then
						return false
					end
					state = prepareUserData.pan.process(answer, state)
					if state then
						reaper.SetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "D_PAN", state)
						setUndoLabel(parent:get())
						return true
					end
				end
			})

			shrPanProperty.extendedProperties:registerProperty(composeEnvelopeControlProperty.viaChunk(i,
				"PANENV",
				function(shr, envName)
					return reaper.GetTrackSendInfo_Value(track, category, shr,
						string.format("P_ENV:<%s", envName))
				end))

			shrMuteProperty = parentLayout[shrID]:registerProperty {
				track = track,
				idx = i,
				type = category,
				typeName = shrCatNames[category]
			}

			function shrMuteProperty:get()
				local message = initOutputMessage()
				message:initType(string.format("Toggle this property to mute or unmute this %s.", self.typeName),
					"Toggleable")
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "B_MUTE")
				message({ objectId = self.typeName, value = muteProperty.states[state] })
				return message
			end

			function shrMuteProperty:set_perform()
				local message = initOutputMessage()
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "B_MUTE")
				reaper.SetTrackSendInfo_Value(self.track, self.type, self.idx, "B_MUTE", nor(state))
				message(self:get())
				return message
			end

			local shrPhaseProperty = parentLayout[shrID]:registerProperty {
				track = track,
				idx = i,
				type = category,
				typeName = shrCatNames[category]
			}

			function shrPhaseProperty:get()
				local message = initOutputMessage()
				message:initType(("Toggle this property to set the phase polarity of this %s."):format(self.typeName),
					"toggleable")
				message({ label = "Phase" })
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "B_PHASE")
				message({ objectId = self.typeName, value = phaseProperty.states[state] })
				return message
			end

			function shrPhaseProperty:set_perform()
				local message = initOutputMessage()
				local state = nor(reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "B_PHASE"))
				reaper.SetTrackSendInfo_Value(self.track, self.type, self.idx, "B_PHASE", state)
				message(self:get())
				return message
			end

			local shrMonoProperty = parentLayout[shrID]:registerProperty {
				track = track,
				idx = i,
				type = category,
				typeName = shrCatNames[category]
			}

			function shrMonoProperty:get()
				local message = initOutputMessage()
				message:initType(("Toggle this property to set the mono state of this %s."):format(self.typeName),
					"toggleable")
				message({ label = "Mono" })
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "B_MONO")
				message({ objectId = self.typeName, value = state == 1 and "On" or "Off" })
				return message
			end

			function shrMonoProperty:set_perform()
				local message = initOutputMessage()
				local state = nor(reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "B_MONO"))
				reaper.SetTrackSendInfo_Value(self.track, self.type, self.idx, "B_MONO", state)
				message(self:get())
				return message
			end

			local shrSendModeProperty = parentLayout[shrID]:registerProperty {
				track = track,
				idx = i,
				type = category,
				typeName = shrCatNames[category],
				states = {
					[0] = "Post-Fader (Post-Pan)",
					[1] = "Pre-Fader (Pre-FX)",
					[2] = "", -- This key should be assigned so Lua will be able to get the table length correctly
					[3] = "Pre-Fader (Post-FX)"
				}
			}

			function shrSendModeProperty:get()
				local message = initOutputMessage()
				message:initType(("Adjust this property to set the mode of this %s."):format(self.typeName))
				message({ label = "Mode" })
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_SENDMODE")
				message({ objectId = self.typeName, value = self.states[state] })
				message:setValueFocusIndex(state < 3 and state + 1 or state, #self.states)
				return message
			end

			function shrSendModeProperty:set_adjust(direction)
				local message = initOutputMessage()
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_SENDMODE")
				local maybeState = nil
				for i = (state + direction), direction == actions.set.increase.direction and #self.states or 0, direction do
					if #self.states[i] > 0 then
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
				reaper.SetTrackSendInfo_Value(self.track, self.type, self.idx, "I_SENDMODE", state)
				message(self:get())
				return message
			end

			local shrSourceAudioChannelsProperty = parentLayout[shrID]:registerProperty {
				track = track,
				idx = i,
				type = category,
				typeName = shrCatNames[category]
			}
			shrSourceAudioChannelsProperty.states = setmetatable({
				[-1] = "Disabled"
			}, {
				__index = function(self, fullState)
					local channels = bitwise.getTo(fullState, 10)
					local chansCount = bitwise.getFrom(fullState, 10)
					if chansCount == 0 then
						return string.format("Stereo channels from %u to %u", channels + 1, channels + 2)
					elseif chansCount == 1 then
						return string.format("Mono channel %u", channels + 1)
					else
						return string.format("%u channels from %u to %u", chansCount * 2, channels + 1,
							channels + (chansCount * 2))
					end
				end
			})
			function shrSourceAudioChannelsProperty:get()
				local message = initOutputMessage()
				message:initType(("Adjust this property to set the source channels for this %s."):format(self.typeName))
				message({ label = "Source audio" })
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_SRCCHAN")
				message({ objectId = self.typeName, value = self.states[state] })
				do
					local channels, channelsCount = bitwise.getTo(state, 10), bitwise.getFrom(state, 10)
					local trackChans = reaper.GetMediaTrackInfo_Value(self.track, "I_NCHAN")
					message:setValueFocusIndex(channels + 1,
						(channelsCount == 0 and trackChans - 1) or
						(channelsCount == 1 and trackChans) or
						trackChans - (channelsCount * 2) + 1
					)
				end
				return message
			end

			function shrSourceAudioChannelsProperty:set_adjust(direction)
				local message = initOutputMessage()
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_SRCCHAN")
				local channels, channelsCount = bitwise.getTo(state, 10), bitwise.getFrom(state, 10)
				local trackChans = reaper.GetMediaTrackInfo_Value(self.track, "I_NCHAN")
				if state == -1 then
					return "The audio send is disabled. You have to switch it on first."
				end
				if direction == actions.set.increase.direction then
					if channelsCount == 0 then
						if (channels + direction) + 2 <= trackChans then
							channels = channels + direction
						else
							message("No more next property values.")
						end
					elseif channelsCount == 1 then
						if (channels + direction) + 1 <= trackChans then
							channels = channels + direction
						else
							message("No more next property values.")
						end
					elseif channelsCount > 1 then
						if (channels + direction) + (channelsCount * 2) <= trackChans then
							channels = channels + direction
						else
							message("No more next property values.")
						end
					end
				elseif direction == actions.set.decrease.direction then
					if (channels + direction) >= 0 then
						channels = channels + direction
					else
						message("No more previous property values.")
					end
				end
				reaper.SetTrackSendInfo_Value(self.track, self.type, self.idx, "I_SRCCHAN",
					bitwise.setTo(state, 10, channels))
				message(self:get())
				return message
			end

			shrSourceAudioChannelsProperty.extendedProperties = PropertiesRibbon.initExtendedProperties(
				"Channels extended interraction")

			shrSourceAudioChannelsProperty.extendedProperties:registerProperty {
				states = setmetatable({ [0] = "Stereo", [1] = "Mono" }, {
					__index = function(self, key)
						return string.format("%u channels", key * 2)
					end
				}),
				get = function(self, parent)
					local message = initOutputMessage()
					message { label = "Channels" }
					local state = reaper.GetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "I_SRCCHAN")
					local channelsCount = bitwise.getFrom(state, 10)
					message { value = state == -1 and "Audio disabled" or self.states[channelsCount] }
					if state >= 0 then
						local trackChans = reaper.GetMediaTrackInfo_Value(parent.track, "I_NCHAN")
						message:setValueFocusIndex(bitwise.getFrom(state, 10) + 1,
							(trackChans / 2) + 1)
					end
					message:initType(
						"Adjust this property to choose the channels mode for source channels. Toggle this property to switch the audio state.",
						"Adjustable, toggleable")
					return message
				end,
				set_adjust = function(self, parent, direction)
					local message = initOutputMessage()
					local state = reaper.GetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "I_SRCCHAN")
					local channelsCount = state == -1 and -1 or bitwise.getFrom(state, 10)
					local trackChans = reaper.GetMediaTrackInfo_Value(parent.track, "I_NCHAN")
					if (channelsCount + direction) * 2 <= trackChans and (channelsCount + direction) >= 0 then
						state = bitwise.concat(10, 0, channelsCount + direction)
					else
						message(string.format("No %s property values.", (direction == 1) and "next" or "previous"))
					end
					reaper.SetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "I_SRCCHAN", state)
					message(self:get(parent))
					return false, message
				end,
				set_perform = function(self, parent)
					local message = initOutputMessage()
					local state = reaper.GetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "I_SRCCHAN")
					state = state == -1 and 0 or -1
					reaper.SetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "I_SRCCHAN",
						state)
					message(string.format("Audio %s.", state == -1 and "disabled" or "enabled"))
					if state ~= -1 then
						message(self:get(parent))
						return false, message
					else
						return true, message, true
					end
				end
			}

			shrSourceAudioChannelsProperty.extendedProperties:registerProperty {
				get = function(self, parent)
					local message = initOutputMessage()
					message { label = "Source track channels" }
					local state = reaper.GetMediaTrackInfo_Value(parent.track, "I_NCHAN")
					message { value = string.format("%u", state) }
					message:setValueFocusIndex(state / 2, 64)
					message:initType(
						"Adjust this property to set the new channels count for source track. This property repeats the track channels dropdown list in routing window.")
					return message
				end,
				set_adjust = function(self, parent, direction)
					local message = initOutputMessage()
					local state = reaper.GetMediaTrackInfo_Value(parent.track, "I_NCHAN")
					local ajustingValue = nil
					if direction > 0 then
						ajustingValue = 2
					else
						ajustingValue = -2
					end
					if (state + ajustingValue) <= 128 and (state + ajustingValue) >= 2 then
						state = state + ajustingValue
					else
						message(string.format("No %s property values.",
							direction == actions.set.increase.direction and "next" or "previous"))
					end
					reaper.SetMediaTrackInfo_Value(parent.track, "I_NCHAN", state)
					local srcState = reaper.GetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "I_SRCCHAN")
					local srcChannels, srcChannelsCount = bitwise.getParts(srcState, 10, 2)
					if srcChannelsCount == 0 then
						if (srcChannels + 2) > state then
							reaper.SetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "I_SRCCHAN",
								bitwise.setTo(srcState, 10, state - 2))
						end
					elseif srcChannelsCount == 1 then
						if srcChannels + 1 > state then
							reaper.SetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "I_SRCCHAN",
								bitwise.setTo(srcState, 10, state - 1))
						end
					elseif srcChannelsCount > 1 then
						if srcChannelsCount * 2 > state then
							reaper.SetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "I_SRCCHAN",
								bitwise.concat(10, 0, state / 2))
						end
					end
					message(self:get(parent))
					return false, message
				end
			}

			if category < 1 then
				local shrDestinationAudioChannelsProperty = parentLayout[shrID]:registerProperty {
					track = track,
					idx = i,
					type = category,
					typeName = shrCatNames[category]
				}

				function shrDestinationAudioChannelsProperty:get()
					local message = initOutputMessage()
					message { objectId = self.typeName, label = "Destination audio" }
					message:initType(
						"Adjust this property to choose the destination audio channels.")
					local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_DSTCHAN")
					local channels = bitwise.getTo(state, 10)
					local isMono = bitwise.getBit(state, 10)
					local srcState = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_SRCCHAN")
					if srcState >= 0 then
						local srcChannelsCode = bitwise.getFrom(srcState, 10)
						local sourceChannels = srcChannelsCode == 0 and 2
							or srcChannelsCode == 1 and 1
							or srcChannelsCode * 2
						local destTrack = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "P_DESTTRACK")
						local destTrackChans = reaper.GetMediaTrackInfo_Value(destTrack, "I_NCHAN") or 0
						local sendChannels = isMono and 1 or sourceChannels
						local endChannel = math.min(channels + sendChannels, destTrackChans)
						if isMono then
							message { value = string.format("Mono channel %u", channels + 1) }
						else
							message { value = string.format("%s from %u to %u",
								(sendChannels == 1 and "Mono channel") or (sendChannels == 2 and "Stereo channels") or sendChannels .. " channels",
								channels + 1,
								endChannel) }
						end
						message:setValueFocusIndex(
							bitwise.getTo(state, 10) + 1,
							isMono and destTrackChans or (destTrackChans - sendChannels) + 1)
					else
						message { value = "Disabled" }
						message:addType(
							" This property is unavailable because the source audio channels are disabled.", 1)
						message:changeType("Unavailable", 2)
					end
					return message
				end

				function shrDestinationAudioChannelsProperty:set_adjust(direction)
					local message = initOutputMessage()
					local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_DSTCHAN")
					local channels, isMono = bitwise.getTo(state, 10),
						bitwise.getBit(state, 10) -- Получаем смещение (0-9 биты) и флаг моно (10 бит)
					local srcState = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_SRCCHAN")
					if srcState == -1 then
						return "Turn on the audio sending first."
					end
					local srcChannelsCode = bitwise.getFrom(srcState, 10)
					local sourceChannels = srcChannelsCode == 0 and 2
						or srcChannelsCode == 1 and 1
						or srcChannelsCode * 2
					local destTrack = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "P_DESTTRACK")
					local destTrackChans = reaper.GetMediaTrackInfo_Value(destTrack, "I_NCHAN") or 0
					local sendChannels = isMono and 1 or sourceChannels
					if direction == actions.set.increase.direction then
						local newChannels = channels + direction
						if newChannels >= 0 and (newChannels + sendChannels) <= destTrackChans then
							state = bitwise.setBit(newChannels, 10, isMono)
						else
							message("No more next property values.")
						end
					elseif direction == actions.set.decrease.direction then
						local newChannels = channels + direction
						if newChannels >= 0 then
							state = bitwise.setBit(newChannels, 10, isMono)
						else
							message("No more previous property values.")
						end
					end
					reaper.SetTrackSendInfo_Value(self.track, self.type, self.idx, "I_DSTCHAN", state)
					message(self:get())
					return message
				end

				if reaper.GetTrackSendInfo_Value(track, category, i, "I_SRCCHAN") >= 0 then
					shrDestinationAudioChannelsProperty.extendedProperties = PropertiesRibbon.initExtendedProperties(
						"Channels extended interraction")

					shrDestinationAudioChannelsProperty.extendedProperties:registerProperty {
						get = function(self, parent)
							local message = initOutputMessage()
							message { label = "Channels mode" }
							local state = reaper.GetTrackSendInfo_Value(parent.track, parent.type, parent.idx,
								"I_DSTCHAN")
							local isMono = bitwise.getBit(
								reaper.GetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "I_DSTCHAN"), 10)
							message { value = isMono and "mono" or "original channels" }
							message:initType(
								"Toggle this property to switch the channels set (either original channels or mono).",
								"Toggleable")
							return message
						end,
						set_perform = function(self, parent)
							local message = initOutputMessage()
							local state = reaper.GetTrackSendInfo_Value(parent.track, parent.type, parent.idx,
								"I_DSTCHAN")
							local isMono = bitwise.getBit(state, 10)
							reaper.SetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "I_DSTCHAN",
								bitwise.setBit(0, 10, nor(isMono)))
							return true, string.format("Set to %s.", isMono and "original channels" or "mono"), true
						end
					}

					shrDestinationAudioChannelsProperty.extendedProperties:registerProperty {
						get = function(self, parent)
							local message = initOutputMessage()
							message { label = "Destination track channels" }
							local destTrack = reaper.GetTrackSendInfo_Value(parent.track, parent.type, parent.idx,
								"P_DESTTRACK")
							local state = reaper.GetMediaTrackInfo_Value(destTrack, "I_NCHAN")
							message { value = string.format("%u", state) }
							message:setValueFocusIndex(state / 2, 64)
							message:initType(
								"Adjust this property to set the new channels count for destination track. This property repeats the track channels dropdown list in routing window.")
							return message
						end,
						set_adjust = function(self, parent, direction)
							local message = initOutputMessage()
							local destTrack = reaper.GetTrackSendInfo_Value(parent.track, parent.type, parent.idx,
								"P_DESTTRACK")
							local prevChanCount = reaper.GetMediaTrackInfo_Value(destTrack, "I_NCHAN")
							local newChanCount = prevChanCount + (direction > 0 and 2 or -2)
							newChanCount = math.min(math.max(newChanCount, 2), 128)
							if newChanCount == prevChanCount then
								message(string.format("No %s property values.", direction == 1 and "next" or "previous"))
							end
							reaper.SetMediaTrackInfo_Value(destTrack, "I_NCHAN", newChanCount)
							local dstState = reaper.GetTrackSendInfo_Value(parent.track, parent.type, parent.idx,
								"I_DSTCHAN")
							local dstOffset = bitwise.getTo(dstState, 10)
							local isMono = bitwise.getBit(dstState, 10)
							local srcState = reaper.GetTrackSendInfo_Value(parent.track, parent.type, parent.idx,
								"I_SRCCHAN")
							local srcChannels = srcState == -1 and 0 or
								(bitwise.getFrom(srcState, 10) == 0 and 2 or bitwise.getFrom(srcState, 10) == 1 and 1 or bitwise.getFrom(srcState, 10) * 2)
							local sendWidth = isMono and 1 or srcChannels
							local maxAllowedOffset = math.max(0, newChanCount - sendWidth)
							if dstOffset > maxAllowedOffset then
								local newDstState = bitwise.setTo(dstState, 10, maxAllowedOffset)
								reaper.SetTrackSendInfo_Value(parent.track, parent.type, parent.idx, "I_DSTCHAN",
									newDstState)
							end
							message(self:get(parent))
							return false, message
						end
					}
				end

				local shrSourceMidiChannelsProperty = parentLayout[shrID]:registerProperty {
					track = track,
					idx = i,
					type = category,
					typeName = shrCatNames[category]
				}

				shrSourceMidiChannelsProperty.states = setmetatable({
					[0] = "All channels",
					[31] = "Disabled"
				}, {
					__index = function(self, state)
						return string.format("Channel %u", state)
					end
				})

				function shrSourceMidiChannelsProperty:get()
					local message = initOutputMessage()
					local state = bitwise.getTo(
						reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_MIDIFLAGS"), 5)
					message { objectId = self.typeName, label = "Source MIDI", value = self.states[state] }
					local channels = bitwise.getTo(state, 5)
					message:setValueFocusIndex(channels ~= 31 and channels + 1 or 1,
						channels ~= 31 and 17 or 1)
					message:initType(
						"Adjust this property to choose the source MIDI channel. Toggle this property to switch the MIDI sending state.",
						"Adjustable, toggleable"
					)
					return message
				end

				function shrSourceMidiChannelsProperty:set_adjust(direction)
					local message = initOutputMessage()
					local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_MIDIFLAGS")
					local channels = bitwise.getTo(state, 5)
					if (channels + direction) >= 0 and (channels + direction) <= 16 then
						channels = channels + direction
					else
						message(string.format("No more %s property values.",
							direction == actions.set.increase.direction and "next" or "previous"))
					end
					reaper.SetTrackSendInfo_Value(self.track, self.type, self.idx, "I_MIDIFLAGS",
						bitwise.setTo(state, 5, channels))
					message(self:get())
					return message
				end

				function shrSourceMidiChannelsProperty:set_perform()
					local message = initOutputMessage()
					local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_MIDIFLAGS")
					local channels = bitwise.getTo(state, 5)
					reaper.SetTrackSendInfo_Value(self.track, self.type, self.idx, "I_MIDIFLAGS",
						bitwise.setTo(state, 5, channels ~= 31 and 31 or 0))
					message(self:get())
					return message
				end

				local shrDestinationMidiChannelsProperty = parentLayout[shrID]:registerProperty {
					track = track,
					idx = i,
					type = category,
					typeName = shrCatNames[category]
				}

				shrDestinationMidiChannelsProperty.states = shrSourceMidiChannelsProperty.states

				function shrDestinationMidiChannelsProperty:get()
					local message = initOutputMessage()
					message { objectId = self.typeName, label = "Destination MIDI" }
					local state = bitwise.getRange(
						reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_MIDIFLAGS"), 6, 10)
					local srcState = bitwise.getTo(
						reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_MIDIFLAGS"), 5)
					message:initType(
						"Adjust this property to choose the destination MIDI channel."
					)
					if srcState == 31 then
						message { value = "disabled" }
						message:addType(
							" This property is unavailable right now because the source MIDI channels is disabled.", 1)
						message:changeType("Unavailable", 2)
					else
						message { value = self.states[state] }
						message:setValueFocusIndex(state + 1, 17)
					end
					return message
				end

				function shrDestinationMidiChannelsProperty:set_adjust(direction)
					local message = initOutputMessage()
					local srcState = bitwise.getTo(
						reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_MIDIFLAGS"), 5)
					local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_MIDIFLAGS")
					local channels = bitwise.getRange(state, 6, 10)
					if srcState ~= 31 and (channels + direction) >= 0 and (channels + direction) <= 16 then
						channels = channels + direction
					else
						message(string.format("No more %s property values.",
							direction == actions.set.increase.direction and "next" or "previous"))
					end
					reaper.SetTrackSendInfo_Value(self.track, self.type, self.idx, "I_MIDIFLAGS",
						bitwise.setRange(state, 6, 10, channels))
					message(self:get())
					return message
				end

				local shr_MidiFaderModeProperty = parentLayout[shrID]:registerProperty {
					track = track,
					idx = i,
					type = category,
					typeName = shrCatNames[category]
				}

				function shr_MidiFaderModeProperty:get()
					local message = initOutputMessage()
					local state = bitwise.getBit(
						reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_MIDIFLAGS"), 10)
					message { objectId = self.typeName, label = "MIDI faders volume and pan", value = state and "Enabled" or "Disabled" }
					message:initType("Toggle this property to switch the MIDI faders volume and pan state.", "Toggleable")
					return message
				end

				function shr_MidiFaderModeProperty:set_perform()
					local message = initOutputMessage()
					local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_MIDIFLAGS")
					reaper.SetTrackSendInfo_Value(self.track, self.type, self.idx, "I_MIDIFLAGS",
						bitwise.setBit(state, 10, not bitwise.getBit(state, 10)))
					message(self:get())
					return message
				end
			end

			shrAutomationModeProperty = parentLayout[shrID]:registerProperty {
				track = track,
				idx = i,
				type = category,
				typeName = shrCatNames[category],
				states = {
					[-1] = "Track automation default",
					[0] = "Trim off",
					[1] = "Read",
					[2] = "Touch",
					[3] = "Write",
					[4] = "Latch"
				},
			}

			function shrAutomationModeProperty:get()
				local message = initOutputMessage()
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_AUTOMODE")
				message { objectId = self.typeName, label = "Automation mode", value = self.states[state] }
				message:setValueFocusIndex(state + 2, #self.states + 2)
				message:initType("Adjust this property to choose the needed automation mode for this send automation.")
				return message
			end

			function shrAutomationModeProperty:set_adjust(direction)
				local message = initOutputMessage()
				local state = reaper.GetTrackSendInfo_Value(self.track, self.type, self.idx, "I_AUTOMODE")
				if (state + direction) >= -1 and (state + direction) <= #self.states then
					reaper.SetTrackSendInfo_Value(self.track, self.type, self.idx, "I_AUTOMODE", state + direction)
				else
					message(string.format("No more %s property values.",
						direction == actions.set.increase.direction and "next" or "previous"))
				end
				message(self:get())
				return message
			end

			local shrRemoveProperty = parentLayout[shrID]:registerProperty {
				track = track,
				idx = i,
				type = category,
				typeName = shrCatNames[category]
			}

			function shrRemoveProperty:get()
				local message = initOutputMessage()
				message(string.format("Remove this %s", self.typeName))
				message:initType(("Perform this property to remove this %s."):format(self.typeName))
				return message
			end

			function shrRemoveProperty:set_perform()
				if reaper.RemoveTrackSend(self.track, self.type, self.idx) then
					return string.format("%s has been removed.", self.typeName)
				else
					return "Removing error"
				end
			end
		end
	end
end

parentLayout.defaultSublayout = "playbackLayout"

PropertiesRibbon.presentLayout(parentLayout)
