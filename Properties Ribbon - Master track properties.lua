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

useMacros("tools")

-- get the master track
local master = reaper.GetMasterTrack(0)
local tpMessages = {
	[false] = "Set to %s. "
}

-- global pseudoclass initialization
local parentLayout = PropertiesRibbon.initLayout("Master track properties")

parentLayout.undoContext = undo.contexts.tracks

function parentLayout.canProvide()
	-- We will check the TCP visibility only
	if (reaper.GetMasterTrackVisibility() & 1) == 1 then
		return true
	else
		return false
	end
end

parentLayout:registerSublayout("managementLayout", "Management")
parentLayout:registerSublayout("playbackLayout", "Playback")
parentLayout:registerSublayout("meteringLayout", "Metering")

local osaraParamsProperty = {}
parentLayout.managementLayout:registerProperty(osaraParamsProperty)

function osaraParamsProperty:get()
	local message = initOutputMessage()
	message:initType("Perform this property to view the OSARA parameters window for master track.")
	message { objectId = "Master ", label = "OSARA parameters" }
	return message
end

function osaraParamsProperty:set_perform()
	-- Ensure the master track has been touched
	local lastSelection = {}
	if reaper.GetLastTouchedTrack() ~= master then
		local selectedTracksCount = reaper.CountSelectedTracks(0)
		for i = 0, selectedTracksCount - 1 do
			table.insert(lastSelection, reaper.GetSelectedTrack(0, i))
		end
		reaper.SetMediaTrackInfo_Value(master, "I_SELECTED", 1)
	end
	reaper.SetCursorContext(0, nil)
	reaper.Main_OnCommand(reaper.NamedCommandLookup("_OSARA_PARAMS"), 0)
	if #lastSelection > 0 then
		for _, track in ipairs(lastSelection) do
			reaper.SetTrackSelected(track, true)
		end
		reaper.SetMediaTrackInfo_Value(master, "I_SELECTED", 0)
	end
end

local routingProperty = parentLayout.managementLayout:registerProperty {}

function routingProperty:get()
	local message = initOutputMessage()
	message:initType("Perform this property to view the routing and input/output options for master track")
	message { objectId = "Master", label = "Routing and inputs or outputs" }
	return message
end

function routingProperty:set_perform()
	reaper.Main_OnCommand(42235, 0) -- Track: View routing and I/O for master track
end

-- volume methods
local volumeProperty = parentLayout.playbackLayout:registerProperty {}

function volumeProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired volume value for master track.")
	local state = reaper.GetMediaTrackInfo_Value(master, "D_VOL")
	message({ objectId = "Master", label = "Volume", value = representation.db[state] })
	return message
end

function volumeProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustStep = config.getinteger("dbStep", 0.1)
	local maxDBValue = config.getinteger("maxDBValue", 12.0)
	if direction == actions.set.decrease.direction then
		ajustStep = -ajustStep
	end
	local state = reaper.GetMediaTrackInfo_Value(master, "D_VOL")
	state = utils.decibelstonum(utils.numtodecibels(state) + ajustStep)
	if state > utils.decibelstonum(maxDBValue) then
		state = utils.decibelstonum(maxDBValue)
		message("maximum volume. ")
	elseif state < utils.decibelstonum(-150.0) then
		state = utils.decibelstonum("-inf")
		message("Minimum volume. ")
	end
	reaper.SetMediaTrackInfo_Value(master, "D_VOL", state)
	message(self:get())
	return message
end

volumeProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Volume extended interraction")
volumeProperty.extendedProperties:registerProperty(composeThreePositionProperty(
	master,
	{
		representation = representation.db,
		min = utils.decibelstonum("-inf"),
		rootmean = utils.decibelstonum(0.0),
		max = utils.decibelstonum(config.getinteger("maxDBValue", 12.0))
	},
	tpMessages,
	function(obj, state)
		reaper.SetMediaTrackInfo_Value(obj, "D_VOL", state)
	end
))

volumeProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to specify a custom volume value manualy.")
		message("Type custom volume")
		return message
	end,
	set_perform = function(self, parent)
		local state = reaper.GetMediaTrackInfo_Value(master, "D_VOL")
		local retval, answer = getUserInputs("Volume for master track",
			{ caption = "New volume value:", defValue = representation.db[state] },
			prepareUserData.db.formatCaption)
		if not retval then
			return false, "Canceled"
		end
		state = prepareUserData.db.process(answer, state)
		if state then
			reaper.SetMediaTrackInfo_Value(master, "D_VOL", state)
		else
			return false
		end
		setUndoLabel(parent:get())
		return true
	end
}

volumeProperty.extendedProperties:registerProperty(composeEnvelopeControlProperty.viaChunk(master, "VOLENV2,VOLENV",
	function(_, envName)
		return reaper.GetMediaTrackInfo_Value(master, string.format("P_ENV:<%s", envName))
	end))

-- pan methods
local panProperty = parentLayout.playbackLayout:registerProperty {}

function panProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired pan value for master track.")
	local state = reaper.GetMediaTrackInfo_Value(master, "D_PAN")
	message({ objectId = "Master", label = "Pan", value = representation.pan[state] })
	return message
end

function panProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = config.getinteger("percentStep", 1)
	if direction == actions.set.increase.direction then
		ajustingValue = utils.percenttonum(ajustingValue)
	elseif direction == actions.set.decrease.direction then
		ajustingValue = -utils.percenttonum(ajustingValue)
	end
	local state = reaper.GetMediaTrackInfo_Value(master, "D_PAN")
	state = math.round((state + ajustingValue), 3)
	if state > 1 then
		state = 1
		message("Right boundary. ")
	elseif state < -1 then
		state = -1
		message("Left boundary. ")
	end
	reaper.SetMediaTrackInfo_Value(master, "D_PAN", state)
	message(self:get())
	return message
end

panProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Pan extended interraction")

panProperty.extendedProperties:registerProperty(composeThreePositionProperty(
	master,
	{
		representation = representation.pan,
		min = -1,
		rootmean = 0,
		max = 1
	},
	tpMessages,
	function(obj, state)
		reaper.SetMediaTrackInfo_Value(obj, "D_PAN", state)
	end
))

panProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to specify a custom pan value manualy")
		message("Type custom pan")
		return message
	end,
	set_perform = function(self, parent)
		local state = reaper.GetMediaTrackInfo_Value(master, "D_PAN")
		local retval, answer = getUserInputs("Pan for master track",
			{ caption = "New pan value:", defValue = representation.pan[state] },
			prepareUserData.pan.formatCaption)
		if not retval then
			return false, "Canceled"
		end
		state = prepareUserData.pan.process(answer, state)
		if state then
			reaper.SetMediaTrackInfo_Value(master, "D_PAN", state)
			setUndoLabel(parent:get())
			return true
		end
		return false
	end
}

panProperty.extendedProperties:registerProperty(composeEnvelopeControlProperty.viaChunk(master, "PANENV2,PANENV",
	function(_, envName)
		return reaper.GetMediaTrackInfo_Value(master, string.format("P_ENV:<%s", envName))
	end))

-- Width methods
local widthProperty = parentLayout.playbackLayout:registerProperty {}

function widthProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the desired width value for master track.")
	local state = reaper.GetMediaTrackInfo_Value(master, "D_WIDTH")
	message({ objectId = "Master", label = "Width", value = string.format("%s%%", utils.numtopercent(state)) })
	return message
end

function widthProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustingValue = config.getinteger("percentStep", 1)
	if direction == actions.set.increase.direction then
		ajustingValue = utils.percenttonum(ajustingValue)
	elseif direction == actions.set.decrease.direction then
		ajustingValue = -utils.percenttonum(ajustingValue)
	end
	local state = reaper.GetMediaTrackInfo_Value(master, "D_WIDTH")
	state = math.round((state + ajustingValue), 3)
	if state > 1 then
		state = 1
		message("Maximum width. ")
	elseif state < -1 then
		state = -1
		message("Minimum width. ")
	end
	reaper.SetMediaTrackInfo_Value(master, "D_WIDTH", state)
	message(self:get())
	return message
end

widthProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Width extended interraction")
widthProperty.extendedProperties:registerProperty(composeThreePositionProperty(
	master,
	{
		representation = setmetatable({},
			{ __index = function(self, key) return string.format("%s%%", utils.numtopercent(key)) end }),
		min = -1,
		rootmean = 0,
		max = 1
	},
	tpMessages,
	function(obj, state)
		reaper.SetMediaTrackInfo_Value(obj, "D_WIDTH", state)
	end
))
widthProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to specify a custom width value manualy.")
		message("Type custom width")
		return message
	end,
	set_perform = function(self, parent)
		local state = reaper.GetMediaTrackInfo_Value(master, "D_WIDTH")
		local retval, answer = getUserInputs("Width for master track",
			{ caption = "New width value:", defValue = string.format("%s%%", utils.numtopercent(state)) },
			prepareUserData.percent.formatCaption)
		if not retval then
			return false, "Canceled"
		end
		state = prepareUserData.percent.process(answer, state)
		if state then
			reaper.SetMediaTrackInfo_Value(master, "D_WIDTH", state)
			setUndoLabel(parent:get())
			return true
		end
		return false
	end
}

widthProperty.extendedProperties:registerProperty(composeEnvelopeControlProperty.viaChunk(master, "WIDTHENV2,WIDTHENV",
	function(_, envName)
		return reaper.GetMediaTrackInfo_Value(master, string.format("P_ENV:<%s", envName))
	end))

-- Mute methods
local muteProperty = parentLayout.playbackLayout:registerProperty {}

function muteProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to mute or unmute master track.", "Toggleable")
	local states = { [0] = "not muted", [1] = "muted" }
	local _, state = reaper.GetTrackUIMute(master)
	if state == true then
		state = 1
	else
		state = 0
	end
	message({ objectId = "Master", value = states[state] })
	return message
end

function muteProperty:set_perform()
	local message = initOutputMessage()
	local states = { [0] = "not muted", [1] = "muted" }
	local _, state = reaper.GetTrackUIMute(master)
	if state == true then
		state = 0
	else
		state = 1
	end
	reaper.SetMediaTrackInfo_Value(master, "B_MUTE", state)
	message(self:get())
	return message
end

-- Solo methods
local soloProperty = parentLayout.playbackLayout:registerProperty {}

function soloProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to solo or unsolo master track.", "Toggleable")
	local states = { [0] = "not soloed", [16] = "soloed" }
	local state = ({ reaper.GetTrackState(master) })[2] & 16
	message({ objectId = "Master", value = states[state] })
	return message
end

function soloProperty:set_perform()
	local message = initOutputMessage()
	local retval, soloInConfig = reaper.get_config_var_string("soloip")
	if retval then
		soloInConfig = soloInConfig + 1
	end
	local state = ({ reaper.GetTrackState(master) })[2] & 16
	if state > 0 then
		state = 0
	else
		state = soloInConfig
	end
	reaper.SetMediaTrackInfo_Value(master, "I_SOLO", state)
	message(self:get())
	return message
end

-- FX bypass methods
local masterFXProperty = parentLayout.playbackLayout:registerProperty {}

function masterFXProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to switch the FX activity of master track.", "Toggleable")
	message { objectId = "Master", label = "FX" }
	local fxCount = reaper.TrackFX_GetCount(master)
	if fxCount > 0 then
		message({
			value = string.format("%s (%u FX in master chain)",
				({ [0] = "active", [1] = "bypassed" })[reaper.GetToggleCommandState(16)], fxCount)
		})
	else
		message { value = "empty" }
		message:addType(" This property  is unavailable now because the master track FX chain is empty.", 1)
		message:changeType("Unavailable", 2)
	end
	return message
end

function masterFXProperty:set_perform()
	local message = initOutputMessage()
	if reaper.TrackFX_GetCount(master) > 0 then
		local state = nor(reaper.GetToggleCommandState(16))
		reaper.Main_OnCommand(16, state)
		message(self:get())
	else
		return "This property  is unavailable nowbecause no one FX in master track FX chain found."
	end
	return message
end

-- Mono/stereo methods
-- This methods is very easy
local monoProperty = parentLayout.playbackLayout:registerProperty {}

function monoProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to switch the master track to mono or stereo.", "Toggleable")
	message { objectId = "Master", value = ({ [0] = "stereo", [1] = "mono" })[reaper.GetToggleCommandState(40917)] }
	return message
end

function monoProperty:set_perform()
	local state = nor(reaper.GetToggleCommandState(40917))
	reaper.Main_OnCommand(40917, state)
	-- OSARA reports this state by itself
	setUndoLabel(self:get())
end

-- Play rate methods
-- It's so easy because there are no deep control. Hmm, either i haven't found this.
local playrateProperty = parentLayout.playbackLayout:registerProperty {}

function playrateProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to set the desired master playrate. Perform this property to reset the master playrate to 1 X which means original rate.")
	local state = reaper.Master_GetPlayRate(0)
	message { objectId = "Master", label = "Play rate", value = representation.playrate[state] }
	return message
end

function playrateProperty:set_adjust(direction)
	local message = initOutputMessage()
	-- Cockos are surprisingly strange... There are is over two methods to get master playrate but no one method to set this. But we aren't offend!
	local cmds = {
		{ [actions.set.decrease.direction] = 40525, [actions.set.increase.direction] = 40524 },
		{ [actions.set.decrease.direction] = 40523, [actions.set.increase.direction] = 40522 }
	}
	reaper.Main_OnCommand(cmds[config.getinteger("rateStep", 1)][direction], 0)
	-- If you can found another method to set this, please let me know!
	message(self:get())
	return message
end

playrateProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Play rate extended interraction")

playrateProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to reset the master play rate to original value")
		message("Reset the play rate")
		return message
	end,
	set_perform = function()
		reaper.Main_OnCommand(40521, 0)
		return true, "Reset", true
	end,
}

-- Preserve pitch when playrate changes methods
-- It's more easy than previous method
local pitchPreserveProperty = parentLayout.playbackLayout:registerProperty {}

function pitchPreserveProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to switch the preserving pitch of items in the project when playrate changes.",
		"Toggleable")
	message { objectId = "Master", label = "Pitch when playrate changes",
		value = ({ [0] = "not preserved", [1] = "preserved" })[reaper.GetToggleCommandState(40671)] }
	return message
end

function pitchPreserveProperty:set_perform()
	local message = initOutputMessage()
	local state = nor(reaper.GetToggleCommandState(40671))
	reaper.Main_OnCommand(40671, state)
	message(self:get())
	return message
end

-- Master tempo methods
-- Seems, Cockos allows to rest of for programmers 🤣
local tempoProperty = parentLayout.playbackLayout:registerProperty {}
function tempoProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set new master tempo.")
	local state = reaper.Master_GetTempo()
	message { objectId = "Master", label = "Tempo", value = representation.tempo[state] }
	return message
end

function tempoProperty:set_adjust(direction)
	local message = initOutputMessage()
	local ajustStep = config.getinteger("tempoStep", 1.0)
	local state = reaper.Master_GetTempo()
	if direction == actions.set.increase.direction then
		reaper.CSurf_OnTempoChange(state + ajustStep)
	elseif direction == actions.set.decrease.direction then
		if (state - ajustStep) > 0 then
			reaper.CSurf_OnTempoChange(state - ajustStep)
		else
			message "Unable to set the tempo less than zero"
		end
	end
	message(self:get())
	return message
end

tempoProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Tempo extended interraction")
tempoProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message "Tap tempo"
		message:initType(
			"Perform this property with needed period to tap tempo manualy. Please note: when you'll perform this property, you will hear no any message.")
		return message
	end,
	set_perform = function(self, parent)
		reaper.Main_OnCommand(1134, 0)
		-- OSARA provides the state value for tempo
		return false
	end
}

tempoProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message "Type custom tempo"
		message:initType("Perform this property to type new custom project tempo.")
		return message
	end,
	set_perform = function(self, parent)
		local retval, answer = getUserInputs("Specify project tempo",
			{ caption = "New tempo value:", defValue = parent:get():extract(2, false) },
			prepareUserData.tempo.formatCaption)
		if retval then
			local newTempo = prepareUserData.tempo.process(answer, reaper.Master_GetTempo())
			if newTempo then
				reaper.CSurf_OnTempoChange(newTempo)
				setUndoLabel(parent:get())
				return true, "", true
			end
		end
		return false
	end
}

tempoProperty.extendedProperties:registerProperty(composeEnvelopeControlProperty.viaCommand(master, "Tempo map",
	function(_, envName)
		return reaper.GetTrackEnvelopeByName(master, envName)
	end, 41046))

-- Master visibility methods
-- TCP visibility
local tcpVisibilityProperty = parentLayout.managementLayout:registerProperty {
	states = { [false] = "not visible", [true] = "visible" }
}

function tcpVisibilityProperty.getValue()
	local state = reaper.GetMasterTrackVisibility() & 1
	return (state ~= 0)
end

function tcpVisibilityProperty.setValue(value)
	local state = reaper.GetMasterTrackVisibility()
	if value == true then
		state = ((1) | (state & 2))
	else
		state = ((0) | (state & 2))
	end
	reaper.SetMasterTrackVisibility(state)
end

function tcpVisibilityProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to set the master track control panel visibility. Please note: when you'll hide the master track control panel, the master track will defines as switched off and tracks focus shouldn't not set to. To get it back activate the master track in View menu."
		, "toggleable")
	message { objectId = "Master", label = "Control panel", value = self.states[self.getValue()] }
	return message
end

function tcpVisibilityProperty:set_perform()
	local message = initOutputMessage()
	local state = nor(self.getValue())
	if state == false then
		if msgBox("Caution", "You are going to hide the control panel of master track in arange view. It means that master track will be switched off and Properties Ribbon will not be able to get the access to untill you will not switch it back. To switch it on back, please either look at View REAPER menu or activate the status layout in the Properties Ribbon.", "okcancel") == showMessageBoxConsts.button.ok then
			self.setValue(state)
		end
	end
	message(self:get())
	return message
end

-- MCP visibility
local mcpVisibilityProperty = parentLayout.managementLayout:registerProperty {
	states = tcpVisibilityProperty.states
}

function mcpVisibilityProperty.getValue()
	local state = reaper.GetMasterTrackVisibility() & 2
	return (state == 0)
end

function mcpVisibilityProperty.setValue(value)
	local state = reaper.GetMasterTrackVisibility()
	if value == true then
		state = ((state & 1) | (0))
	else
		state = ((state & 1) | (2))
	end
	reaper.SetMasterTrackVisibility(state)
end

function mcpVisibilityProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to set the master track visibility in mixer panel.", "toggleable")
	message { objectId = "Master", label = "Visibility on mixer panel", value = self.states[self.getValue()] }
	return message
end

function mcpVisibilityProperty:set_perform()
	local message = initOutputMessage()
	local state = self.getValue()
	self.setValue(nor(state))
	message(self:get())
	return message
end

-- Master track position in mixer panel
local masterTrackMixerPosProperty = parentLayout.managementLayout:registerProperty {}
masterTrackMixerPosProperty.states = {
	"docked window",
	"separated window",
	"right side"
}

function masterTrackMixerPosProperty.getValue()
	local check = reaper.GetToggleCommandState
	if check(41610) == 1 then
		return 1
	elseif check(41636) == 1 then
		return 2
	elseif check(40389) == 1 then
		return 3
	end
	return 0
end

function masterTrackMixerPosProperty.setValue(value)
	local cmds = { 41610, 41636, 40389 }
	reaper.Main_OnCommand(cmds[value], 1)
end

function masterTrackMixerPosProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to choose the desired master track position on the mixer panel.")
	local state = self.getValue()
	message { objectId = "Master track", label = "Positioned" }
	if state == 0 then
		message { value = "nowhere" }
	else
		message { value = string.format("in the %s on the mixer panel", self.states[state]) }
	end
	return message
end

function masterTrackMixerPosProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = self.getValue()
	state = state + direction
	if state > #self.states then
		state = #self.states
		message("No more next property values. ")
	elseif state < 1 then
		state = 1
		message("No more previous property values. ")
	end
	self.setValue(state)
	message(self:get())
	return message
end

-- Metering property
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
	message:initType("Read this property to inquire the hold peak or loudness meter value of master track.")
	message:addType(" Adjust this property to choose needed channel for watching.", 1)
	local curChannel = extstate._layout.meterChannel or 1
	message { objectId = "Master" }
	local mode = self.getMode(master)
	if self.meterIsEnabled(master) then
		message { label = string.format("Hold meter %s", mode.name) }
		if curChannel > 1 then
			local channel = mode.channels[curChannel - 1] or mode.channels[#mode.channels - 1]
			message { value = string.format("%s%s %s", channel.name and channel.name .. " " or "", self.states[reaper.Track_GetPeakHoldDB(master, channel.id, false)], mode.id < 10 and "dB" or "LU") }
		else
			for _, channel in ipairs(mode.channels) do
				message { value = string.format("%s%s %s, ", channel.name and channel.name .. " " or "", self.states[reaper.Track_GetPeakHoldDB(master, channel.id, false)], mode.id < 10 and "dB" or "LU") }
			end
			-- Clearing off the extra coma chars
			message.value = message.value:sub(1, -2)
		end
	else
		message { label = "Meter", value = "Disabled" }
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
		local mode = self.getMode(master)
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

loudnessHoldMeterProperty.extendedProperties =
	PropertiesRibbon.initExtendedProperties("Metering interraction")

loudnessHoldMeterProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message "Reset the peak values"
		message:initType(
			"Perform this property to reset the peak values. Adjust this property to use channels adjustment like you're in parent property.")
		return message
	end,
	set_adjust = function(self, parent, direction)
		return false, parent:set_adjust(direction)
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		local curChannel = extstate._layout.meterChannel or 1
		local mode = parent.getMode(master)
		if curChannel == 1 then
			for _, channel in ipairs(mode.channels) do
				reaper.Track_GetPeakHoldDB(master, channel.id, true)
			end
		else
			local channel = mode.channels[curChannel - 1] or mode.channels[#mode.channels - 1]
			reaper.Track_GetPeakHoldDB(master, channel.id, true)
		end
		message "Reset."
		return true, message, true
	end
}

loudnessHoldMeterProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message { label = "Metering" }
		local state = parent.meterIsEnabled(master)
		message { value = state and "Enabled" or "Disabled" }
		message:initType("Toggle this property to switch the meter state.", "Toggleable")
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		local state = reaper.GetMediaTrackInfo_Value(master, "I_VUMODE")
		reaper.SetMediaTrackInfo_Value(master, "I_VUMODE", state ~ 1)
		message(self:get(parent))
		return false, message
	end
}

loudnessHoldMeterProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message { label = "Meter mode" }
		local mode = parent.getMode(master)
		message { value = mode.name }
		message:initType("Adjust this property to choose the needed meter mode for master track.")
		return message
	end,
	set_adjust = function(self, parent, direction)
		local message = initOutputMessage()
		local modeStates = { 0, 2, 4, 8, 12, 16, 20 }
		local curMode = nil
		local mode = parent.getMode(master)
		for i, m in ipairs(modeStates) do
			if m == mode.id then
				curMode = i
			end
		end
		if curMode + direction > #modeStates then
			message "No more next property values. "
			curMode = #modeStates
		elseif curMode + direction < 1 then
			message "No more previous property values. "
			curMode = 1
		else
			curMode = curMode + direction
		end
		local state = reaper.GetMediaTrackInfo_Value(master, "I_VUMODE")
		-- Thanks to @electrik-spb for the hexadecimal bitmask solution
		reaper.SetMediaTrackInfo_Value(master, "I_VUMODE", (state & 0x60) | modeStates[curMode])
		message(self:get(parent))
		return false, message
	end
}

local contextMenuProperty = parentLayout.managementLayout:registerProperty {}

function contextMenuProperty:get()
	local message = initOutputMessage()
	message:initType("Perform this property to open the context menu for master track.")
	message { objectId = "Master", label = "Outputs Context menu" }
	return message
end

function contextMenuProperty:set_perform()
	reaper.Main_OnCommand(reaper.NamedCommandLookup("_OSARA_CONTEXTMENU3"), 0)
end

parentLayout.defaultSublayout = "playbackLayout"

PropertiesRibbon.presentLayout(parentLayout)
