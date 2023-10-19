--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License

----------
]]
--


-- This file contains a macros for specified solutions. Use this macros at own properties.

track_properties_macros = {}

---@generic track userdata

---# Gets all selected tracks or last touched track (depending on )multiSelectionSupport option) #
---@param multiSelectionSupport boolean Defines the multi-selection support
---@return track[]|track Either array of selected track or one track object (if there's one only)
function track_properties_macros.getTracks(multiSelectionSupport)
	local tracks = nil
	if multiSelectionSupport == true then
		local countSelectedTracks = reaper.CountSelectedTracks(0)
		if countSelectedTracks > 1 then
			tracks = {}
			for i = 0, countSelectedTracks - 1 do
				table.insert(tracks, reaper.GetSelectedTrack(0, i))
			end
		else
			tracks = reaper.GetSelectedTrack(0, 0)
		end
	else
		local lastTouched = reaper.GetLastTouchedTrack()
		if lastTouched ~= reaper.GetMasterTrack(0) then
			tracks = lastTouched
		end
	end
	return tracks
end

---Composes the formatted track name and its state
---@param track track
---@param shouldSilentColor? boolean should this function omit the color value? (false by default)
---@return string
function track_properties_macros.getTrackID(track, shouldSilentColor)
	shouldSilentColor = shouldSilentColor or false
	local message = initOutputMessage()
	local states = {
		[0] = "track ",
		[1] = "folder ",
		[2] = "end of folder ",
		[3] = "end of %u folders"
	}
	local compactStates = {
		[0] = "opened ",
		[1] = "small ",
		[2] = "closed "
	}
	if reaper.GetParentTrack(track) then
		message("child ")
	end
	local state = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
	if state == 0 or state == 1 then
		if state == 1 then
			message:clearMessage()
			local compactState = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
			message(compactStates[compactState])
		end
		message(string.format("%s", states[state]))
	elseif state < 0 then
		message:clearMessage()
		state = -(state - 1)
		if state < 3 then
			message(string.format(" %s", states[state]))
		else
			message(string.format(states[3], state - 1))
		end
	end
	if config.getboolean("reportName", false) == true then
		local retval, name = reaper.GetTrackName(track)
		if retval then
			if name:match("^Track%s%d*$") == nil then
				local truncate = config.getinteger("truncateIdBy", 0)
				if truncate > 0 then
					name = utils.truncateSmart(name, truncate)
				end
			end
			if name:match("^Track%s%d*$") then
				if state == 0 then
					name = name:match("%d+")
				else
					name = "Track " .. name:match("%d+")
				end
			end
			message(name)
		end
	else
		message(string.format("%u", reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")))
	end
	if shouldSilentColor == false then
		local color = reaper.GetTrackColor(track)
		if color ~= 0 then
			message.msg = colors:getName(reaper.ColorFromNative(color)) .. " " .. message.msg:gsub("^%w", string.lower)
		end
		message.msg = message.msg:gsub("^%w", string.upper)
	end
	return message:extract()
end
