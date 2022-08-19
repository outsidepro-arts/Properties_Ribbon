--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License

----------
]] --


-- This file contains a macros for properties at this directory.
-- You don't need to include this file. The engine will do it itself.

track_properties_macros = {}

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

item_properties_macros = {}

function item_properties_macros.getItems(multiSelectionSupport)
	local items = nil
	if multiSelectionSupport == true then
		local countSelectedItems = reaper.CountSelectedMediaItems(0)
		if countSelectedItems > 1 then
			items = {}
			for i = 0, countSelectedItems - 1 do
				table.insert(items, reaper.GetSelectedMediaItem(0, i))
			end
		else
			items = reaper.GetSelectedMediaItem(0, 0)
		end
	else
		items = reaper.GetSelectedMediaItem(0, 0)
	end
	return items
end

function item_properties_macros.getItemNumber(item)
	return reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER") + 1
end

function item_properties_macros.getTakeNumber(item)
	return reaper.GetMediaItemInfo_Value(item, "I_CURTAKE") + 1
end

function item_properties_macros.getItemID(item, shouldSilentColor)
	shouldSilentColor = shouldSilentColor or false
	local message = initOutputMessage()
	if shouldSilentColor == false then
		local color = reaper.GetDisplayedMediaItemColor(item)
		if color ~= 0 then
			message(colors:getName(reaper.ColorFromNative(color)) .. " ")
		end
	end
	local idmsg = "Item %u"
	if #message > 0 then
		idmsg = idmsg:lower()
	end
	message(idmsg:format(item_properties_macros.getItemNumber(item)))
	return message:extract()
end

function item_properties_macros.getTakeID(item, shouldSilentColor)
	shouldSilentColor = shouldSilentColor or false
	local message = initOutputMessage()
	local cfg = config.getboolean("reportName", false)
	if cfg == true then
		local retval, name = reaper.GetSetMediaItemTakeInfo_String(reaper.GetActiveTake(item), "P_NAME", "", false)
		if retval then
			local truncate = config.getinteger("truncateIdBy", 0)
			if truncate > 0 then
				name = utils.truncateSmart(name, truncate)
			end
			-- Stupid REAPER adds the file extensions to the take's name!
			if config.getboolean("clearFileExts", true) == true then
				name = name:gsub("(.+)[.](%w+)$", "%1")
			end
			message(("take %s"):format(name))
		else
			message(("take %u"):format(item_properties_macros.getTakeNumber(item)))
		end
	else
		message(("take %u"):format(item_properties_macros.getTakeNumber(item)))
	end
	if shouldSilentColor == false then
		local color = reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_CUSTOMCOLOR")
		if color ~= 0 then
			message.msg = colors:getName(reaper.ColorFromNative(color)) .. " " .. message.msg:gsub("^%w", string.lower)
		end
	end
	return message:extract()
end

function item_properties_macros.getSelectedItemAtCursor(items)
	if istable(items) then
		for _, item in ipairs(items) do
			local itemPosition, takePlayrate, itemLength = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
				reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE"),
				reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
			if reaper.GetCursorPosition() >= itemPosition and
				reaper.GetCursorPosition() <= (itemPosition + (itemLength / takePlayrate)) then
				return item
			end
		end
	else
		local itemPosition, takePlayrate, itemLength = reaper.GetMediaItemInfo_Value(items, "D_POSITION"),
			reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(items), "D_PLAYRATE"),
			reaper.GetMediaItemInfo_Value(items, "D_LENGTH")
		if reaper.GetCursorPosition() >= itemPosition and
			reaper.GetCursorPosition() <= (itemPosition + (itemLength / takePlayrate)) then
			return items
		end
	end
end

function item_properties_macros.pos_relativeToGlobal(item, rel)
	local itemPosition, takePlayrate = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
		reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE")
	return (itemPosition + rel) / takePlayrate
end

function item_properties_macros.pos_globalToRelative(item)
	local itemPosition, takePlayrate = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
		reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE")
	return (reaper.GetCursorPosition() - itemPosition) * takePlayrate
end

envelope_properties_macros = {}

function envelope_properties_macros.getPoints(envelope, multiSelectionSupport)
	points = nil
	if envelope then
		local countEnvelopePoints = reaper.CountEnvelopePoints(envelope)
		if multiSelectionSupport == true then
			points = {}
			for i = 0, countEnvelopePoints - 1 do
				local retval, _, _, _, _, selected = reaper.GetEnvelopePoint(envelope, i)
				if retval and selected then
					table.insert(points, i)
				end
			end
			if #points == 1 then
				points = points[1]
			elseif #points == 0 then
				points = nil
			end
		else
			-- As James Teh says, REAPER returns the previous point by time even if any point is set here. I didn't saw that, but will trust of professional developer!
			local maybePoint = reaper.GetEnvelopePointByTime(envelope, reaper.GetCursorPosition() + 0.0001)
			if maybePoint >= 0 then
				points = maybePoint
			end
		end
	end
	return points
end

function envelope_properties_macros.getPointID(point, shouldNotReturnPrefix)
	if point == 0 then
		return "Initial point"
	else
		if shouldNotReturnPrefix == true then
			return tostring(point)
		else
			return string.format("Point %u", point)
		end
	end
end

function composeThreePositionProperty(obj, minRootMax, setMessages, setValueFunc)
	local t = {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Adjust and perform this three-state setter to set the needed value specified in parentheses.")
			message("three-position setter")
			message(string.format(" (%s - %s, ", actions.set.decrease.label, minRootMax.representation[minRootMax.min]))
			message(string.format("%s - %s, ", actions.set.perform.label, minRootMax.representation[minRootMax.rootmean]))
			message(string.format("%s - %s)", actions.set.increase.label, minRootMax.representation[minRootMax.max]))
			return message
		end,
		set_adjust = function(self, parent, direction)
			local message = initOutputMessage()
			vls = { [actions.set.decrease.direction] = minRootMax.min, [actions.set.increase.direction] = minRootMax.max }
			message(string.format(setMessages[istable(obj)], minRootMax.representation[ vls[direction] ]))
			if istable(obj) then
				for _, o in ipairs(obj) do
					setValueFunc(o, vls[direction])
				end
			else
				setValueFunc(obj, vls[direction])
			end
			return true, message
		end,
		set_perform = function(self, parent)
			local message = initOutputMessage()
			local state = minRootMax.rootmean
			message(string.format(setMessages[istable(obj)], minRootMax.representation[state]))
			if istable(obj) then
				for _, o in ipairs(obj) do
					setValueFunc(o, state)
				end
			else
				setValueFunc(obj, state)
			end
			return true, message
		end
	}
	return t
end

fx_properties_macros = {}

function fx_properties_macros.newContextualAPI()
	local capi = setmetatable({
		_context = 0,
		_contextObj = setmetatable({}, {
			-- REAPER generates error when media item is nil so we have to wrap these handles to metatable
			__index = function(self, key)
				if key == 0 then
					local lastTouched = reaper.GetLastTouchedTrack()
					if lastTouched then
						return lastTouched
					else
						if (reaper.GetMasterTrackVisibility() & 1) == 1 then
							return reaper.GetMasterTrack(0)
						end
					end
				elseif key == 1 then
					if reaper.GetSelectedMediaItem(0, 0) then
						return reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, 0))
					end
					return nil
				end
			end
		}),
		_contextPrefix = {
			[0] = "TrackFX_",
			[1] = "TakeFX_"
		}
	}, {
		__index = function(self, key)
			return function(...)
				if reaper.APIExists(self._contextPrefix[self._context] .. key) then
					return reaper[self._contextPrefix[self._context] .. key](self._contextObj[self._context], ...)
				else
					if self._context == 0 and key:find("Envelope") then
						if reaper[key] then
							return reaper[key](self._contextObj[self._context], ...)
						end
					end
					error(string.format("Contextual API wasn't found method %s", self._contextPrefix[self._context] .. key))
				end
			end
		end
	})
	return capi
end

fx_properties_macros.fxMaskList = setmetatable({}, {
	__index = function(self, idx)
		if isnumber(idx) then
			local fxMask = extstate[string.format("fx_properties.excludeMask%u.fx", idx)]
			local parmMask = extstate[string.format("fx_properties.excludeMask%u.param", idx)]
			return { ["fxMask"] = fxMask, ["paramMask"] = parmMask }
		end
		error(string.format("Expected key type %s (got %s)", type(1), type(idx)))
	end,
	__newindex = function(self, idx, maskTable)
		if maskTable then
			assert(istable(maskTable), string.format("Expected key type %s (got %s)", type({}), type(maskTable)))
			assert(maskTable.fxMask, "Expected field fxMask")
			assert(maskTable.paramMask, "Expected field paramMask")
			extstate._forever[string.format("fx_properties.excludeMask%u.fx", idx)] = maskTable.fxMask
			extstate._forever[string.format("fx_properties.excludeMask%u.param", idx)] = maskTable.paramMask
		else
			local i = idx
			while extstate[string.format("fx_properties.excludeMask%u.fx", i)] do
				if i == idx then
					extstate._forever[string.format("fx_properties.excludeMask%u.fx", i)] = nil
					extstate._forever[string.format("fx_properties.excludeMask%u.param", i)] = nil
				elseif i > idx then
					extstate._forever[string.format("fx_properties.excludeMask%u.fx", i - 1)] = extstate._layout[
						string.format("excludeMask%u.fx", i)]
					extstate._forever[string.format("fx_properties.excludeMask%u.param", i - 1)] = extstate._layout[
						string.format("excludeMask%u.param", i)]
					extstate._forever[string.format("fx_properties.excludeMask%u.fx", i)] = nil
					extstate._forever[string.format("fx_properties.excludeMask%u.param", i)] = nil
				end
				i = i + 1
			end
		end
	end,
	__len = function(self)
		local mCount = 0
		while extstate[string.format("fx_properties.excludeMask%u.fx", mCount + 1)] do
			mCount = mCount + 1
		end
		return mCount
	end
})

markers_regions_selection_macros = {}

function markers_regions_selection_macros.isTimeSelectionSet()
	local selectionStart, selectionEnd = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
	return (selectionStart ~= 0 or selectionEnd ~= 0)
end

function markers_regions_selection_macros.isLoopSet()
	local loopStart, loopEnd = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false)
	return (loopStart ~= 0 or loopEnd ~= 0)
end
