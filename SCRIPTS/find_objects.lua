--[[
Find specified objects script for Properties Ribbon
Copyright (C), Outsidepro Arts 2021-2022
License: MIT license
This script written for Properties Ribbon complex] and can be only runnen from this.
]] --

useMacros("properties")

local function searchTracks(options, trackFrom, direction)
	local startRange, endRange
	if direction >= actions.set.increase.direction then
		startRange = trackFrom
		endRange = reaper.CountTracks(0)
	elseif direction <= actions.set.decrease.direction then
		startRange = trackFrom
		endRange = 1
	end
	for i = startRange, endRange, direction do
		local track = reaper.GetTrack(0, i - 1)
		local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
		if trackName then
			if utils.extendedSearch(trackName, options.query, options.caseSensetive, options.usePatterns) then
				reaper.SetOnlyTrackSelected(track)
				return true
			end
		end
	end
end

local function searchPluginsInTracks(options, trackFrom, direction)
	local startRange, endRange
	if direction >= actions.set.increase.direction then
		startRange = trackFrom
		endRange = reaper.CountTracks(0)
	elseif direction <= actions.set.decrease.direction then
		startRange = trackFrom
		endRange = 1
	end
	for i = startRange, endRange, direction do
		local track = nil
		if i < 0 then
			track = reaper.GetMasterTrack(0)
		else
			track = reaper.GetTrack(0, i)
		end
		local countFX = reaper.TrackFX_GetCount(track)
		if countFX > 0 then
			for k = 0, countFX - 1 do
				local retval, buf = reaper.TrackFX_GetFXName(track, k, "")
				if retval then
					if utils.extendedSearch(buf, options.query, options.caseSensetive, options.usePatterns) then
						reaper.SetOnlyTrackSelected(track)
						return true
					end
				end
			end
		end
	end
end

local function searchItems(options, itemFrom, direction)
	local startRange, endRange
	if direction >= actions.set.increase.direction then
		startRange = itemFrom
		endRange = reaper.CountMediaItems(0) - 1
	elseif direction <= actions.set.decrease.direction then
		startRange = itemFrom
		endRange = 0
	end
	for i = startRange, endRange, direction do
		local item = reaper.GetMediaItem(0, i)
		local take = reaper.GetActiveTake(item)
		local _, takeName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
		if takeName then
			if utils.extendedSearch(takeName, options.query, options.caseSensetive, options.usePatterns) then
				reaper.SelectAllMediaItems(0, false)
				local newCursorPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
				reaper.SetEditCurPos(newCursorPos, true, true)
				reaper.SetMediaItemSelected(item, true)
				return true
			end
		end
	end
end

local function searchPluginsInTakes(options, itemFrom, direction)
	local startRange, endRange
	if direction >= actions.set.increase.direction then
		startRange = itemFrom
		endRange = reaper.CountMediaItems(0) - 1
	elseif direction <= actions.set.decrease.direction then
		startRange = itemFrom
		endRange = 0
	end
	for i = startRange, endRange, direction do
		local item = reaper.GetMediaItem(0, i)
		local take = reaper.GetActiveTake(item)
		local countFX = reaper.TakeFX_GetCount(take)
		if countFX > 0 then
			local found = false
			for k = 0, countFX - 1 do
				local retval, buf = reaper.TakeFX_GetFXName(take, k, "")
				if retval then
					if utils.extendedSearch(buf, options.query, options.caseSensetive, options.usePatterns) then
						reaper.SelectAllMediaItems(0, false)
						local newCursorPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
						reaper.SetEditCurPos(newCursorPos, true, true)
						reaper.SetMediaItemSelected(item, true)
						return true
					end
				end
			end
		end
	end
end

local context = reaper.GetCursorContext()

local searchLayout = initLayout(({ [0] = "Search in tracks", [1] = "Search in items" })[context])

function searchLayout.canProvide()
	if context == 0 then
		return (reaper.CountTracks(0) > 0)
	elseif context == 1 then
		return (reaper.CountMediaItems(0) > 0)
	end
	return false
end

local searchinAction = {}
searchLayout:registerProperty(searchinAction)
searchinAction.objStrings = {
	[0] = "track",
	[1] = "item"
}
searchinAction.searchProcesses = {
	[0] = searchTracks,
	[1] = searchItems
}
searchinAction.options = setmetatable({}, {
	__index = function(self, key)
		return extstate._layout[
			string.format("searchinAction.%s.%s", utils.removeSpaces(searchinAction.objStrings[context]), key)]
	end,
	__newindex = function(self, key, value)
		extstate._layout[string.format("searchinAction.%s.%s", utils.removeSpaces(searchinAction.objStrings[context]), key)] = value
	end
})

function searchinAction:get()
	local message = initOutputMessage()
	message:initType(string.format("Adjust this action to search a %s by specified options on approppriate direction.",
		self.objStrings[context]))
	message(string.format("Search a specified %s", self.objStrings[context]))
	message(string.format(" (%s - forward, %s - backward)", actions.set.increase.label, actions.set.decrease.label))
	return message
end

function searchinAction:set_adjust(direction)
	local message = initOutputMessage()
	local query = self.options.query
	if query then
		local fromPosition = 0
		local objectId
		if context == 0 then
			fromPosition = reaper.GetMediaTrackInfo_Value(reaper.GetLastTouchedTrack(), "IP_TRACKNUMBER")
			getId = track_properties_macros.getTrackID
			objectId = function() return reaper.GetSelectedTrack(0, 0) end
			if fromPosition < 0 then -- Master track suddenly selected
				fromPosition = 0
			end
		elseif context == 1 then
			fromPosition = reaper.GetMediaItemInfo_Value(reaper.GetSelectedMediaItem(0, 0), "IP_ITEMNUMBER")
			getId = function(obj) return string.format("%s with take %s", item_properties_macros.getItemID(obj),
				item_properties_macros.getTakeID(obj)) end
			objectId = function() return reaper.GetSelectedMediaItem(0) end
		end
		if self.searchProcesses[context](self.options, fromPosition + direction, direction) then
			message{
				label="Focus set to",
				value=representation.getFocusLikeOSARA(context)
			}
		else
			message(string.format("No any %s with setting up search criteria at this direction.", self.objStrings[context]))
		end
	else
		message("You have to set up the search criteria.")
	end
	return message
end

searchinAction.extendedProperties = initExtendedProperties("Search setting up")
searchinAction.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message("Specify search query ")
		local curQuery = parent.options.query
		if curQuery then
			message(string.format("(currently set as %s)", curQuery))
		else
			message(" (must set)")
		end
		message:initType("Perform this property to specify a search query.")
		return message
	end,
	set_adjust = function (self, parent, direction)
		return false, parent:set_adjust(direction)
	end,
	set_perform = function(self, parent)
		local curQuery = parent.options.query or ""
		local retval, answer = reaper.GetUserInputs(string.format("Search specified %s", parent.objStrings[context]), 1,
			string.format("Type a part or full %s name which you wish to find:", parent.objStrings[context]), tostring(curQuery))
		if retval then
			parent.options.query = answer
		end
	end
}
searchinAction.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		local state = parent.options.caseSensetive or false
		message { label = "Case sensetive", value = ({ [true] = "enabled", [false] = "disabled" })[state] }
		message:initType("Toggle this property to specify should search process be case sensetive or not.", "Toggleable")
		return message
	end,
	set_adjust = function (self, parent, direction)
		return false, parent:set_adjust(direction)
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		parent.options.caseSensetive = nor(parent.options.caseSensetive or false)
		message(self:get(parent))
		return false, message
	end
}
searchinAction.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		local state = parent.options.usePatterns or false
		message { label = "Use Lua patterns", value = ({ [true] = "enabled", [false] = "disabled" })[state] }
		message:initType("Toggle this property to enable or disable the Lua patterns in search queries. The Lua patterns like RegExp patterns, so your search query can be more powerfull."
			, "Toggleable")
		return message
	end,
	set_adjust = function (self, parent, direction)
		return false, parent:set_adjust(direction)
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		parent.options.usePatterns = nor(parent.options.usePatterns or false)
		message(self:get(parent))
		return false, message
	end
}
local searchbyPluginsAction = {}
searchLayout:registerProperty(searchbyPluginsAction)
searchbyPluginsAction.objStrings = {
	[0] = "plug-in in tracks",
	[1] = "plug-in in active takes of items"
}
searchbyPluginsAction.searchProcesses = {
	[0] = searchPluginsInTracks,
	[1] = searchPluginsInTakes
}

searchbyPluginsAction.options = setmetatable({}, {
	__index = function(self, key)
		return extstate._layout[
			string.format("searchbyPluginsAction.%s.%s", utils.removeSpaces(searchinAction.objStrings[context]), key)]
	end,
	__newindex = function(self, key, value)
		extstate._layout[
			string.format("searchbyPluginsAction.%s.%s", utils.removeSpaces(searchinAction.objStrings[context]), key)] = value
	end
})

function searchbyPluginsAction:get()
	local message = initOutputMessage()
	message:initType(string.format("Adjust this action to search a  %s by specified query at approppriate direction.",
		self.objStrings[context]))
	message(string.format("Search a specified %s", self.objStrings[context]))
	message(string.format(" (%s - forward, %s - backward)", actions.set.increase.label, actions.set.decrease.label))
	return message
end

searchbyPluginsAction.set_adjust = searchinAction.set_adjust
searchbyPluginsAction.extendedProperties = searchinAction.extendedProperties


return searchLayout