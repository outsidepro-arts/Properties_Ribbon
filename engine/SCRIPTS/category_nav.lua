--[[
Category navigation script for Properties Ribbon
Copyright (C), Outsidepro Arts 2021-2022
License: MIT license
This script written for Properties Ribbon complex] and can be only runnen from this.
]] --


useMacros("properties")

-- The constant for request/set extended data
local scriptExtData = "P_EXT:outsidepro_arts_category_nav"

-- Tracks
local tracks = track_properties_macros.getTracks(config.getboolean("multiSelectionSupport", true))


local categories = setmetatable({}, {
	__index = function(self, idx)
		if isnumber(idx) then
			return extstate._layout[string.format("category%u", idx)]
		end
		error(string.format("Expected key type %s (got %s)", type(1), type(idx)))
	end,
	__newindex = function(self, idx, catID)
		if catID then
			extstate._layout._forever[string.format("category%u", idx)] = catID
		else
			local i = idx
			while extstate._layout[string.format("category%u", i)] do
				if i == idx then
					extstate._layout._forever[string.format("category%u", i)] = nil
				elseif i > idx then
					extstate._layout._forever[string.format("category%u", i - 1)] = extstate._layout[string.format("category%u", i)]
					extstate._layout._forever[string.format("category%u", i)] = nil
				end
				i = i + 1
			end
		end
	end,
	__len = function(self)
		local mCount = 0
		while extstate._layout[string.format("category%u", mCount + 1)] do
			mCount = mCount + 1
		end
		return mCount
	end
})

local function navigateTracks(category, trackFrom, direction)
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
		local retval, data = reaper.GetSetMediaTrackInfo_String(track, scriptExtData, "", false)
		if retval then
			if utils.removeSpaces(category) == data then
-- OSARA shows the selection dialog with text message representation when the same action performs twice in specified time. We absolutely don't need it, so we are forced to hack this.
				-- We have to start hack OSARA here
				local restoreStep, backTrack
				if reaper.GetTrack(0, i-2) then
					restoreStep = -1
					backTrack = reaper.GetTrack(0, i-2)
				elseif reaper.GetTrack(0, i) then
					restoreStep = 1
					backTrack = reaper.GetTrack(0, i)
				end
				reaper.SetOnlyTrackSelected(backTrack)
				return true, restoreStep
			end
		end
	end
end

local function reportFocusAvoidSelectionWindow(direction)
	local curTrackId = reaper.GetMediaTrackInfo_Value(reaper.GetSelectedTrack(0, 0), "IP_TRACKNUMBER")-1
	local cmds = {
		[-1] = 40285, -- Track: Go to next track
		[1] = 40286 -- Track: Go to previous track
	}
	if curTrackId+direction >= 0 and curTrackId+direction < reaper.CountTracks(0) then
		reaper.SetOnlyTrackSelected(reaper.GetTrack(curTrackId-direction))
		reaper.Main_OnCommand(cmds[direction], 0)
	end
end

local catnavLayout = initLayout("Track navigation by category")

function catnavLayout.canProvide()
	return tracks ~= nil
end

-- The category property get/set functions to form this in loop
local function categoryGet(self)
	local message = initOutputMessage()
	message(self.name)
	message:initType("Adjust this property in appropriate direction to move the selection focus to a track which was beeing markqued as belonging for this category.")
	return message
end

local function categorySet_adjust(self, direction)
	local message = initOutputMessage()
	local cmds = {
		[-1] = 40285, -- Track: Go to next track
		[1] = 40286 -- Track: Go to previous track
	}
	local trackFrom = reaper.GetMediaTrackInfo_Value(reaper.GetLastTouchedTrack(), "IP_TRACKNUMBER")
	local retval, step = navigateTracks(self.name, trackFrom+direction, direction)
	if retval then
		-- Keep OSARA hack implementation
		reaper.Main_OnCommand(cmds[step], 0)
	else
		return string.format("No %s track in category %s", ({[-1] = "previous", [1] = "next"})[direction], self.name)
	end
end

local categoryExtendedProperties = initExtendedProperties("Category extended interraction")

categoryExtendedProperties:registerProperty{
	get = function (self, parent)
		local message = initOutputMessage()
		if istable(tracks) then
			message(string.format("Assign %u selected track to this category", #tracks))
		else
			message(string.format("Assign %s to this category", track_properties_macros.getTrackID(tracks, true)))
		end
		message:initType(string.format("Perform this property to assign %s to this category. Please note: if %s already assigned to another category, %s will be re-assigned.",
		({[true] = "selected tracks", [false] = "selected or last touched track"})[istable(tracks)],
		({ [true] = "these tracks", [false] = "this track" })[istable(tracks)],
		({ [true] = "they", [false] = "it" })[istable(tracks)]
		))
		return message
	end,
	set_perform = function (self, parent)
		local message = initOutputMessage()
		if istable(tracks) then
			for _, track in ipairs(tracks) do
				reaper.GetSetMediaTrackInfo_String(track, scriptExtData, utils.removeSpaces(parent.name), true)
			end
			message(string.format("Assign selected tracks to %s category", parent.name))
		else
			message{label=track_properties_macros.getTrackID(tracks, true)}
			local retval = reaper.GetSetMediaTrackInfo_String(tracks, scriptExtData, utils.removeSpaces(parent.name), true)
			if retval then
				message{ value=string.format("Assigned to %s", parent.name) }
			else
				message{value="cannot be assigned to this group"}
			end
		end
		return false, message
	end
}
categoryExtendedProperties:registerProperty{
	get = function (self, parent)
		local message = initOutputMessage()
		if istable(tracks) then
			message(string.format("de-assign %u selected tracks out of this category", #tracks))
		else
			message(string.format("De-assign %s out of this category", track_properties_macros.getTrackID(tracks, true)))
		end
		message:initType(string.format("Perform this property to de-assign %s out of this category.",
		({[true] = "selected tracks", [false] = "selected or last touched track"})[istable(tracks)]
		))
		return message
	end,
	set_perform = function (self, parent)
		local message = initOutputMessage()
		if istable(tracks) then
			for _, track in ipairs(tracks) do
				local _, data = reaper.GetSetMediaTrackInfo_String(track, scriptExtData, "", false)
				if data == utils.removeSpaces(parent.name) then
					reaper.GetSetMediaTrackInfo_String(track, scriptExtData, "", true)
				end
			end
			message(string.format("De-assign selected tracks out of %s category", parent.name))
		else
			message{label=track_properties_macros.getTrackID(tracks, true)}
			local retval, data = reaper.GetSetMediaTrackInfo_String(tracks, scriptExtData, "", false)
			if retval then
				if data == utils.removeSpaces(parent.name) then
					reaper.GetSetMediaTrackInfo_String(tracks, scriptExtData, "", true)
					message{ value = "De-assigned" }
				else
					message{value = "already not in this category"}
				end
			else
				message{ value = "already not in any category"}
			end
		end
		return false, message
	end
}
categoryExtendedProperties:registerProperty{
	get = function (self, parent)
		local message = initOutputMessage()
		message "Rename this category"
		message:initType()
		return message
	end,
	set_perform = function (self, parent)
		local retval, answer = reaper.GetUserInputs("Rename category", 1, "Type new category name:", parent.name)
		if retval then
			if not extstate._layout.renameCategoryNotify then
				reaper.ShowMessageBox("Category navigation script assigns a track to specified category using its name as ID, thus when you'll rename the category, all tracks will be stay at old ID assigned. You will have to re-assign these tracks to new category manualy.", "Please note", showMessageBoxConsts.sets.ok)
				extstate._layout._forever.renameCategoryNotify = true
			end
			if #answer > 0 then
				categories[parent.id] = answer
			else
				reaper.ShowMessageBox("The category name cannot be empty.", "Category rename error", showMessageBoxConsts.sets.ok)
				return false
			end
		end
		return true
	end
}

categoryExtendedProperties:registerProperty{
	get = function (self, parent)
		local message = initOutputMessage()
		message "Delete this category"
		message:initType("Perform this property to delete this category.")
		return message
	end,
	set_perform = function (self, parent)
		if reaper.ShowMessageBox(string.format("Are you sure you want to delete the category %s?", parent.name), "Category deletion confirm", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
			categories[parent.id] = nil
			return true
		end
	end
}

if catnavLayout.canProvide() then
	for i = 1, #categories do
		local catForm = {
			id = i,
			name = categories[i],
			get = categoryGet,
			set_adjust = categorySet_adjust,
			extendedProperties = categoryExtendedProperties
		}
		catnavLayout:registerProperty(catForm)
	end
end

local addNewCategoryProperty = {}
catnavLayout:registerProperty(addNewCategoryProperty)

function addNewCategoryProperty:get()
	local message = initOutputMessage()
	message "Add new category"
	message:initType("Perform this property to create new category.")
	return message
end

function addNewCategoryProperty:set_perform()
	local retval, answer = reaper.GetUserInputs("Create new category", 1, "Type category name:", "")
	if retval then
		if #answer > 0 then
			categories[#categories+1] = answer
		else
			reaper.ShowMessageBox("The category name cannot be empty.", "Category creation error", showMessageBoxConsts.sets.ok)
		end
	end
end

return catnavLayout