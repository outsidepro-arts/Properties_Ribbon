--[[
Cleans up the project removing unnecessary FX, items and tracks.
Copyright (C), Outsidepro Arts 2026
License: MIT license
This script written for Properties Ribbon complex] and can be only runnen from this.
]] --

-- We have to fix the Properties Ribbon searching path. Currently it places on a up level directory
do
	local uplevelPath = select(2, reaper.get_action_context()):match('^.+[\\//]')
	uplevelPath = uplevelPath:match("(.+)([//\\])(.+)$")
	package.path = uplevelPath .. "//?//init.lua"
end

require "properties_ribbon"


local layout = PropertiesRibbon.initLayout("Cleanup the project data")

local function getLayoutQuery(k, defV)
	local v = extstate._layout[k]
	if type(defV) ~= "nil" then
		-- The ternary operators are not work WITH boolean values... Cr*p!
		if type(v) == "nil" then
			v = defV
		end
	end
	return v
end

local function setLayoutQuery(k, v)
	extstate._layout[k] = v
end

-- The configuration properties generator
local function generateConfigProperty(stringObjects, getsetFunction)
	local futureProperty = {}
	if stringObjects.states then
		futureProperty.states = stringObjects.states
	end
	assert(stringObjects.tip, "The string object tip is expected.")
	assert(stringObjects.label, "The string object label is expected.")
	assert(getsetFunction, "The get/set function is expected.")
	function futureProperty:get()
		local message = initOutputMessage()
		message:initType(stringObjects.tip, self.states == nil and "Toggleable" or nil)
		message { label = stringObjects.label }
		if self.states then
			message { value = self.states[getsetFunction()] }
		else
			message { value = getsetFunction() and "enabled" or "disabled" }
		end
		return message
	end

	if futureProperty.states then
		function futureProperty:set_adjust(direction)
			local message = initOutputMessage()
			local state = getsetFunction()
			if self.states[state + direction] then
				getsetFunction(state + direction)
			else
				message(string.format("No more %s property values.", (direction == 1) and "next" or "previous"))
			end
			message(self:get())
			return message
		end
	else
		function futureProperty:set_perform()
			local message = initOutputMessage()
			getsetFunction(nor(getsetFunction()))
			message(self:get())
			return message
		end
	end
	return futureProperty
end

-- Where the script will process the data

local function getsetObjects(state)
	if state then
		setLayoutQuery("cleanObjects", state)
	else
		return getLayoutQuery("cleanObjects", 1)
	end
end

layout:registerProperty(generateConfigProperty(
	{
		tip = "Adjust this property to choose where the script will perform the cleanup process.",
		label = "What the script will clean",
		states = {
			"both tracks and items",
			"tracks only",
			"items only"
		}
	},
	getsetObjects
))

-- Should include the master track?

local function getsetIncludeMaster(state)
	-- Since the boolean is expected we cannot use the just-nil-check.
	if type(state) ~= "nil" then
		setLayoutQuery("includeMaster", state)
	else
		return getLayoutQuery("includeMaster", true)
	end
end

layout:registerProperty(generateConfigProperty(
	{
		tip = "Toggle this property to define whether the master track should be included in the cleanup process.",
		label = "Include master track"
	},
	getsetIncludeMaster
))

-- Remove bypassed FX?

local function getsetBypassedFX(state)
	if type(state) ~= "nil" then
		setLayoutQuery("removeBypassedFX", state)
	else
		return getLayoutQuery("removeBypassedFX", true)
	end
end

layout:registerProperty(generateConfigProperty(
	{
		tip = "Toggle this property to define whether the bypassed FX should be removed.",
		label = "Remove bypassed FX"
	},
	getsetBypassedFX
))

-- Remove offline FX?

local function getsetOfflineFX(state)
	if type(state) ~= "nil" then
		setLayoutQuery("removeOfflineFX", state)
	else
		return getLayoutQuery("removeOfflineFX", true)
	end
end

layout:registerProperty(generateConfigProperty(
	{
		tip = "Toggle this property to define whether the offline FX should be removed.",
		label = "Remove offline FX"
	},
	getsetOfflineFX
))

-- Do not remove instruments?

local function getsetDontRemoveInstruments(state)
	if type(state) ~= "nil" then
		setLayoutQuery("dontRemoveInstruments", state)
	else
		return getLayoutQuery("dontRemoveInstruments", false)
	end
end

layout:registerProperty(generateConfigProperty(
	{
		tip = "Toggle this property to define whether the plug-ins which set as instruments should not be removed.",
		label = "Do not remove instruments"
	},
	getsetDontRemoveInstruments
))

-- Remove muted tracks?

local function getsetMutedTracks(state)
	if type(state) ~= "nil" then
		setLayoutQuery("removeMutedTracks", state)
	else
		return getLayoutQuery("removeMutedTracks", true)
	end
end

layout:registerProperty(generateConfigProperty(
	{
		tip = "Toggle this property to define whether the muted tracks should be removed.",
		label = "Remove muted tracks"
	},
	getsetMutedTracks
))

-- Do not remove muted track if they have hardware outputs (may mean that this is a reference track)

local function getsetDontRemoveMutedTrackWithHWO(state)
	if type(state) ~= "nil" then
		setLayoutQuery("dontRemoveMutedTrackWithHWO", state)
	else
		return getLayoutQuery("dontRemoveMutedTrackWithHWO", false)
	end
end

layout:registerProperty(generateConfigProperty(
	{
		tip =
		"Toggle this property to define whether the muted tracks with hardware outputs should not be removed. May mean that this is a reference track.",
		label = "Do not remove muted track if they have hardware outputs"
	},
	getsetDontRemoveMutedTrackWithHWO
))

-- Remove empty tracks which have no items or have no sends/receives?

local function getsetEmptyTracks(state)
	if type(state) ~= "nil" then
		setLayoutQuery("removeEmptyTracks", state)
	else
		return getLayoutQuery("removeEmptyTracks", true)
	end
end

layout:registerProperty(generateConfigProperty(
	{
		tip =
		"Toggle this property to define whether the empty tracks should be removed. Empty track mean the tracks which have no items and have no sends or receives.",
		label = "Remove empty tracks"
	},
	getsetEmptyTracks
))

-- Remove muted items?

local function getsetMutedItems(state)
	if type(state) ~= "nil" then
		setLayoutQuery("removeMutedItems", state)
	else
		return getLayoutQuery("removeMutedItems", true)
	end
end

layout:registerProperty(generateConfigProperty(
	{
		tip = "Toggle this property to define whether the muted items should be removed.",
		label = "Remove muted items"
	},
	getsetMutedItems
))


-- Remove empty take lanes?

local function getsetEmptyTakeLanes(state)
	if type(state) ~= "nil" then
		setLayoutQuery("removeEmptyTakeLanes", state)
	else
		return getLayoutQuery("removeEmptyTakeLanes", false)
	end
end

layout:registerProperty(generateConfigProperty(
	{
		tip = "Toggle this property to define whether the empty take lanes should be removed.",
		label = "Remove empty take lanes"
	},
	getsetEmptyTakeLanes
))



-- Start the process

local function process()
	-- Get all pre-defined configs
	local cleanObjects, includeMaster, removeBypassedFX, removeOfflineFX, removeMutedTracks, removeEmptyTracks, removeMutedItems, dontRemoveMutedTrackWithHWO, removeEmptyTakeLanes, dontRemoveInstruments =
		getsetObjects(), getsetIncludeMaster(), getsetBypassedFX(), getsetOfflineFX(), getsetMutedTracks(),
		getsetEmptyTracks(), getsetMutedItems(), getsetDontRemoveMutedTrackWithHWO(), getsetEmptyTakeLanes(),
		getsetDontRemoveInstruments()
	local tracks, items = {}, {}
	local statistic = setmetatable({
		__data = {},
		hasData = function(self)
			for _, _ in pairs(self) do
				return true
			end
			return false
		end
	}, {
		__index = function(self, key)
			return self.__data[key] or 0
		end,
		__newindex = function(self, key, value)
			self.__data[key] = self[key] + value
		end,
		__pairs = function(self)
			return pairs(self.__data)
		end,
		__tostring = function(self)
			local accumulator = {}
			for key, value in pairs(self) do
				table.insert(accumulator, string.format("%s: %u", key, value))
			end
			return table.concat(accumulator, "\n")
		end
	})
	if includeMaster then
		table.insert(tracks, reaper.GetMasterTrack(0))
	end
	if cleanObjects == 1 or cleanObjects == 2 then
		for i = 0, reaper.CountTracks(0) - 1 do
			table.insert(tracks, reaper.GetTrack(0, i))
		end
	end
	if cleanObjects == 1 or cleanObjects == 3 then
		for i = 0, reaper.CountMediaItems(0) - 1 do
			table.insert(items, reaper.GetMediaItem(0, i))
		end
	end
	if msgBox("Start the clean up process", "The clean up process is ready to go. Continue?", "yesno") ~= showMessageBoxConsts.button.yes then
		return
	end
	for _, item in ipairs(items) do
		if removeMutedItems and reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1 then
			-- Since we cannot remove item directly, we have to remove this using its parent track.
			local parentTrack = reaper.GetMediaItemInfo_Value(item, "P_PARTRACK")
			if reaper.DeleteTrackMediaItem(parentTrack, item) then
				statistic["muted items removed"] = 1
			end
		else
			-- REAPER does not snapshots the state per Reascript Run, so we will go by unsafe plan
			local i = 0
			while i < reaper.CountTakes(item) do
				local take = reaper.GetTake(item, i)
				if take then
					local j = 0
					while j < reaper.TakeFX_GetCount(take) do
						if removeBypassedFX and not reaper.TakeFX_GetEnabled(take, j) then
							if reaper.TakeFX_Delete(take, j) then
								statistic["bypassed FX removed"] = 1
								goto continueJ
							end
						elseif removeOfflineFX and reaper.TakeFX_GetOffline(take, j) then
							if reaper.TakeFX_Delete(take, j) then
								statistic["offline FX removed"] = 1
								goto continueJ
							end
						end
						j = j + 1
						::continueJ::
					end
				else
					if removeEmptyTakeLanes then
						if reaper.NF_DeleteTakeFromItem(item, i) then
							statistic["empty take lanes removed"] = 1
						end
					end
				end
				i = i + 1
				::ContinueI::
			end
		end
	end
	for _, track in ipairs(tracks) do
		if removeMutedTracks and reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 and reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 0 then
			if dontRemoveMutedTrackWithHWO and reaper.GetTrackNumSends(track, 1) > 0 then
				goto continue
			end
			reaper.DeleteTrack(track)
			if not pcall(reaper.GetTrackName, track) then
				statistic["muted tracks removed"] = 1
			end
			::continue::
		elseif removeEmptyTracks and reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 0 and reaper.CountTrackMediaItems(track) == 0 and reaper.TrackFX_GetCount(track) == 0 and reaper.GetTrackNumSends(track, -1) == 0 and reaper.GetTrackNumSends(track, 0) == 0 then
			reaper.DeleteTrack(track)
			if not pcall(reaper.GetTrackName, track) then
				statistic["empty tracks removed"] = 1
			end
		else
			-- REAPER does not snapshots the state per Reascript Run, so we will go by unsafe plan
			local trackInstrument = nil
			if dontRemoveInstruments then
				trackInstrument = reaper.TrackFX_GetInstrument(track)
			end
			local i = 0
			while i < reaper.TrackFX_GetCount(track) do
				if removeBypassedFX and not reaper.TrackFX_GetEnabled(track, i) and trackInstrument ~= i then
					if reaper.TrackFX_Delete(track, i) then
						statistic["bypassed FX removed"] = 1
						goto continue
					end
				elseif removeOfflineFX and reaper.TrackFX_GetOffline(track, i) and trackInstrument ~= i then
					if reaper.TrackFX_Delete(track, i) then
						statistic["offline FX removed"] = 1
						goto continue
					end
				end
				i = i + 1
				::continue::
			end
		end
	end
	local msg = "Cleaning up complete."
	if statistic:hasData() then
		msg = msg .. " The following operations have been performed:\n" .. tostring(statistic)
	else
		msg = msg .. " No actions have been performed."
	end
	msgBox("Success", msg, "ok")
end

local startProperty = layout:registerProperty {}
startProperty.undoContext = undo.contexts.project

function startProperty:get()
	local message = initOutputMessage()
	message:initType("Perform this property to start the cleanup process with specified parameters.")
	message "start the process"
	return message
end

function startProperty:set_perform()
	process()
end

PropertiesRibbon.presentLayout(layout)
