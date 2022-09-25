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
			return {
				id = extstate._layout[utils.makeKeySequence(string.format("category%u", idx), "id")],
				name = extstate._layout[utils.makeKeySequence(string.format("category%u", idx), "name")]
			}
		end
		error(string.format("Expected key type %s (got %s)", type(1), type(idx)))
	end,
	__newindex = function(self, idx, cat)
		if cat then
			extstate._layout._forever[utils.makeKeySequence(string.format("category%u", idx), "id")] = assert(cat.id, "Expected table field 'id'")
			extstate._layout._forever[utils.makeKeySequence(string.format("category%u", idx), "name")] = assert(cat.name, "Expected table field 'name'")
		else
			local i = idx
			while extstate._layout[utils.makeKeySequence(string.format("category%u", i), "name")] do
				if i == idx then
					extstate._layout._forever[utils.makeKeySequence(string.format("category%u", i), "name")] = nil
					extstate._layout._forever[utils.makeKeySequence(string.format("category%u", i), "id")] = nil
				elseif i > idx then
					extstate._layout._forever[utils.makeKeySequence(string.format("category%u", i - 1), "name")] = extstate._layout[utils.makeKeySequence(string.format("category%u", i), "name")]
					extstate._layout._forever[utils.makeKeySequence(string.format("category%u", i - 1), "id")] = extstate._layout[utils.makeKeySequence(string.format("category%u", i), "id")]
					extstate._layout._forever[utils.makeKeySequence(string.format("category%u", i), "name")] = nil
					extstate._layout._forever[utils.makeKeySequence(string.format("category%u", i), "id")] = nil
				end
				i = i + 1
			end
		end
	end,
	__len = function(self)
		local mCount = 0
		while extstate._layout[utils.makeKeySequence(string.format("category%u", mCount + 1), "name")] do
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
			if category.id == data then
				reaper.SetOnlyTrackSelected(track)
				return true
			end
		end
	end
end

local function checkExistingCategoryID(id)
	for i = 1, #categories do
		local category = categories[i]
		if category.id == id then
			return true
		end
	end
	return false
end

local catnavLayout = initLayout("Track navigation by category")

function catnavLayout.canProvide()
	return tracks ~= nil
end

-- The category property get/set functions to form this in loop
local function categoryGet(self)
	local message = initOutputMessage()
	message(self.category.name)
	message:initType("Adjust this property in appropriate direction to move the selection focus to a track which was beeing markqued as belonging for this category.")
	return message
end

local function categorySet_adjust(self, direction)
	local message = initOutputMessage()
	local trackFrom = reaper.GetMediaTrackInfo_Value(reaper.GetLastTouchedTrack(), "IP_TRACKNUMBER")
	if navigateTracks(self.category, trackFrom+direction, direction) then
		message{
			label = "Focus on",
			value = representation.getFocusLikeOSARA(0)
		}
		return message
	else
		return string.format("No %s track in category %s", ({[-1] = "previous", [1] = "next"})[direction], self.category.name)
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
				reaper.GetSetMediaTrackInfo_String(track, scriptExtData, parent.category.id, true)
			end
			message(string.format("Assign selected tracks to %s category", parent.category.name))
		else
			message{label=track_properties_macros.getTrackID(tracks, true)}
			local retval = reaper.GetSetMediaTrackInfo_String(tracks, scriptExtData, parent.category.id, true)
			if retval then
				message{ value=string.format("Assigned to %s", parent.category.name) }
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
				if data == parent.category.id then
					reaper.GetSetMediaTrackInfo_String(track, scriptExtData, "", true)
				end
			end
			message(string.format("De-assign selected tracks out of %s category", parent.category.name))
		else
			message{label=track_properties_macros.getTrackID(tracks, true)}
			local retval, data = reaper.GetSetMediaTrackInfo_String(tracks, scriptExtData, "", false)
			if retval then
				if data == parent.category.id then
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
		local retval, answer = reaper.GetUserInputs("Rename category", 1, "Type new category name:", parent.category.name)
		if retval then
			if #answer > 0 then
				-- Our metatable is not so smart so we have to pass it the full value table
				local category = categories[parent.id]
				 category.name = answer
				 categories[parent.id] = category
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
		if reaper.ShowMessageBox(string.format("Are you sure you want to delete the category %s?", parent.category.name), "Category deletion confirm", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
			categories[parent.id] = nil
			return true
		end
	end
}

if catnavLayout.canProvide() then
	for i = 1, #categories do
		local catForm = {
			id = i,
			category = categories[i],
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
		local maxLength = 15
		local newID = utils.generateID(10, maxLength)
		while checkExistingCategoryID(newID) do
			maxLength = maxLength + 5
			newID = utils.generateID(10, maxLength)
		end
			categories[#categories+1] = {
				id = newID,
				name = answer
			}
		else
			reaper.ShowMessageBox("The category name cannot be empty.", "Category creation error", showMessageBoxConsts.sets.ok)
		end
	end
end

return catnavLayout