--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2024 outsidepro-arts
License: MIT License
]] --


-- We have to fix the Properties Ribbon searching path. Currently it places on a up level directory
do
	local uplevelPath = select(2, reaper.get_action_context()):match('^.+[\\//]')
	uplevelPath = uplevelPath:match("(.+)([//\\])(.+)$")
	package.path = uplevelPath .. "//?//init.lua"
end

require "properties_ribbon"

--[[
Category navigation script for Properties Ribbon
Copyright (C), Outsidepro Arts 2021-2022
License: MIT license
This script written for Properties Ribbon complex] and can be only runnen from this.
]]
--

useMacros("track_properties")

-- The constant for request/set extended data
scriptExtData = "P_EXT:outsidepro_arts_category_nav"

-- Tracks
tracks = track_properties_macros.getTracks(config.getboolean("multiSelectionSupport", true))


categories = setmetatable({
	id = "category_nav"
}, {
	__index = function(self, idx)
		if isnumber(idx) then
			return {
				id = extstate[utils.makeKeySequence(self.id, string.format("category%u", idx), "id")],
				name = extstate[utils.makeKeySequence(self.id, string.format("category%u", idx), "name")]
			}
		end
		error(string.format("Expected key type %s (got %s)", type(1), type(idx)))
	end,
	__newindex = function(self, idx, cat)
		if cat then
			extstate._forever[utils.makeKeySequence(self.id, string.format("category%u", idx), "id")] = assert(cat.id,
				"Expected table field 'id'")
			extstate._forever[utils.makeKeySequence(self.id, string.format("category%u", idx), "name")] = assert(cat.name,
				"Expected table field 'name'")
		else
			local i = idx
			while extstate[utils.makeKeySequence(self.id, string.format("category%u", i), "name")] do
				if i == idx then
					extstate._forever[utils.makeKeySequence(self.id, string.format("category%u", i), "name")] = nil
					extstate._forever[utils.makeKeySequence(self.id, string.format("category%u", i), "id")] = nil
				elseif i > idx then
					extstate._forever[utils.makeKeySequence(self.id, string.format("category%u", i - 1), "name")] =
						extstate[utils.makeKeySequence(self.id, string.format("category%u", i), "name")]
					extstate._forever[utils.makeKeySequence(self.id, string.format("category%u", i - 1), "id")] =
						extstate[utils.makeKeySequence(self.id, string.format("category%u", i), "id")]
					extstate._forever[utils.makeKeySequence(self.id, string.format("category%u", i), "name")] = nil
					extstate._forever[utils.makeKeySequence(self.id, string.format("category%u", i), "id")] = nil
				end
				i = i + 1
			end
		end
	end,
	__len = function(self)
		local mCount = 0
		while extstate[utils.makeKeySequence(self.id, string.format("category%u", mCount + 1), "name")] do
			mCount = mCount + 1
		end
		return mCount
	end
})

local function trackCanbeNavigated(track)
	local function diveup(track, lastCheck)
		local parentTrack = reaper.GetParentTrack(track)
		if parentTrack then
			if reaper.GetMediaTrackInfo_Value(parentTrack, "B_SHOWINTCP") == 1 then
				return diveup(parentTrack, true)
			else
				return false
			end
		else
			return lastCheck
		end
	end
	return reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 0 and diveup(track) or true
end

local function navigateTracks(checkFunction, trackFrom, direction)
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
		if trackCanbeNavigated(track) and checkFunction(track) then
			reaper.SetOnlyTrackSelected(track)
			return true
		end
	end
end

local function countSpecifiedTracks(func)
	local result = 0
	for i = 0, reaper.CountTracks(0) - 1 do
		local track = reaper.GetTrack(0, i)
		if trackCanbeNavigated(track) and func(track) then
			result = result + 1
		end
	end
	return result
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

local catnavLayout = PropertiesRibbon.initLayout("Track navigation by category")


catnavLayout:registerSublayout("basic", "Basic")
catnavLayout:registerSublayout("custom", "Custom")

function catnavLayout.canProvide()
	return tracks ~= nil
end

-- Iteration function for checking track in a custom category
local function customCategoryCheck(category)
	return function(track)
		local retval, data = reaper.GetSetMediaTrackInfo_String(track, scriptExtData, "", false)
		if retval then
			if category.id == data then
				return true
			end
		end
	end
end

-- The category property get/set functions to form this in loop
local function categoryGet(self)
	local message = initOutputMessage()
	message(self.category.name)
	message(
		("(%u track%s assigned)")
		:format(countSpecifiedTracks(customCategoryCheck(self.category)),
			(countSpecifiedTracks(customCategoryCheck(self.category)) == 1 and "" or "s")
		):gsub("%(0", "(no")
	)
	message:initType(
		"Adjust this property in appropriate direction to move the selection focus to a track which was beeing markqued as belonging for this category.")
	return message
end

local function categorySet_adjust(self, direction)
	local message = initOutputMessage()
	local trackFrom = reaper.GetMediaTrackInfo_Value(reaper.GetLastTouchedTrack(), "IP_TRACKNUMBER")
	if navigateTracks(customCategoryCheck(self.category), trackFrom + direction, direction) then
		message {
			label = "Focus on",
			value = representation.getFocusLikeOSARA(0)
		}
		return message
	else
		return string.format("No %s track in category %s", ({
			[-1] = "previous",
			[1] = "next"
		})[direction], self.category.name)
	end
end

local categoryExtendedProperties = PropertiesRibbon.initExtendedProperties("Category extended interraction")

categoryExtendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		if istable(tracks) then
			message(string.format("Assign %u selected track to this category", #tracks))
		else
			message(string.format("Assign %s to this category", track_properties_macros.getTrackID(tracks, true)))
		end
		message:initType(string.format(
			"Perform this property to assign %s to this category. Please note: if %s already assigned to another category, %s will be re-assigned.",
			({
				[true] = "selected tracks",
				[false] = "selected or last touched track"
			})[istable(tracks)], ({
				[true] = "these tracks",
				[false] = "this track"
			})[istable(tracks)], ({
				[true] = "they",
				[false] = "it"
			})[istable(tracks)]))
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		if istable(tracks) then
			for _, track in ipairs(tracks) do
				reaper.GetSetMediaTrackInfo_String(track, scriptExtData, parent.category.id, true)
			end
			message(string.format("Assign selected tracks to %s category", parent.category.name))
		else
			message {
				label = track_properties_macros.getTrackID(tracks, true)
			}
			local retval = reaper.GetSetMediaTrackInfo_String(tracks, scriptExtData, parent.category.id, true)
			if retval then
				message {
					value = string.format("Assigned to %s", parent.category.name)
				}
			else
				message {
					value = "cannot be assigned to this group"
				}
			end
		end
		return false, message
	end
}
categoryExtendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		if istable(tracks) then
			message(string.format("de-assign %u selected tracks out of this category", #tracks))
		else
			message(string.format("De-assign %s out of this category", track_properties_macros.getTrackID(tracks, true)))
		end
		message:initType(string.format("Perform this property to de-assign %s out of this category.", ({
			[true] = "selected tracks",
			[false] = "selected or last touched track"
		})[istable(tracks)]))
		return message
	end,
	set_perform = function(self, parent)
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
			message {
				label = track_properties_macros.getTrackID(tracks, true)
			}
			local retval, data = reaper.GetSetMediaTrackInfo_String(tracks, scriptExtData, "", false)
			if retval then
				if data == parent.category.id then
					reaper.GetSetMediaTrackInfo_String(tracks, scriptExtData, "", true)
					message {
						value = "De-assigned"
					}
				else
					message {
						value = "already not in this category"
					}
				end
			else
				message {
					value = "already not in any category"
				}
			end
		end
		return false, message
	end
}
categoryExtendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message "Rename this category"
		message:initType()
		return message
	end,
	set_perform = function(self, parent)
		local retval, answer = getUserInputs("Rename category", {
			caption = "New category name:",
			defValue = parent.category.name
		})
		if retval then
			if #answer > 0 then
				-- Our metatable is not so smart so we have to pass it the full value table
				local category = categories[parent.id]
				category.name = answer
				categories[parent.id] = category
			else
				reaper.ShowMessageBox("The category name cannot be empty.", "Category rename error",
					showMessageBoxConsts.sets.ok)
				return false
			end
		end
		return true
	end
}

categoryExtendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message "Delete this category"
		message:initType("Perform this property to delete this category.")
		return message
	end,
	set_perform = function(self, parent)
		if reaper.ShowMessageBox(string.format("Are you sure you want to delete the category %s?", parent.category.name),
				"Category deletion confirm", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
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
		catnavLayout.custom:registerProperty(catForm)
	end
end

local addNewCategoryProperty = {}
catnavLayout.custom:registerProperty(addNewCategoryProperty)

function addNewCategoryProperty:get()
	local message = initOutputMessage()
	message "Add new category"
	message:initType("Perform this property to create new category.")
	return message
end

function addNewCategoryProperty:set_perform()
	local retval, answer = getUserInputs("Create new category", {
		caption = "Category name:"
	})
	if retval then
		if #answer > 0 then
			local maxLength = 15
			local newID = utils.generateID(10, maxLength)
			while checkExistingCategoryID(newID) do
				maxLength = maxLength + 5
				newID = utils.generateID(10, maxLength)
			end
			categories[#categories + 1] = {
				id = newID,
				name = answer
			}
		else
			reaper.ShowMessageBox("The category name cannot be empty.", "Category creation error",
				showMessageBoxConsts.sets.ok)
		end
	end
end

local function generateGetMethod(label)
	return function(self)
		local message = initOutputMessage()
		message(label:gsub("%stracks$", ""))
		local tracksAmount = countSpecifiedTracks(self.checkFunction)
		message((""):join("(",
			tracksAmount == 0 and "no tracks" or
			string.format("%s track%s", tracksAmount, tracksAmount ~= 1 and "s" or ""), ")"))
		message:initType(string.format("Adjust this property to navigate throughby %s.", label:gsub("^.", string.lower)))
		return message
	end
end

local function generateSetMethod(fmess)
	return function(self, direction)
		local message = initOutputMessage()
		local trackFrom = reaper.GetMediaTrackInfo_Value(reaper.GetLastTouchedTrack(), "IP_TRACKNUMBER")
		if navigateTracks(self.checkFunction, trackFrom + direction, direction) then
			message {
				label = "Focus on",
				value = representation.getFocusLikeOSARA(0)
			}
			return message
		else
			return string.format(fmess, ({
				[-1] = "previous",
				[1] = "next"
			})[direction])
		end
	end
end

local folderNavigator = {}
catnavLayout.basic:registerProperty(folderNavigator)

function folderNavigator.checkFunction(track)
	return reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") > 0
end

folderNavigator.get = generateGetMethod("Folders")
folderNavigator.set_adjust = generateSetMethod("No %s folder")

local mutedTracksNavigator = {}
catnavLayout.basic:registerProperty(mutedTracksNavigator)

function mutedTracksNavigator.checkFunction(track)
	return reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1
end

mutedTracksNavigator.get = generateGetMethod("Muted tracks")
mutedTracksNavigator.set_adjust = generateSetMethod("No %s muted track")

local soloedTracksNavigator = {}
catnavLayout.basic:registerProperty(soloedTracksNavigator)

function soloedTracksNavigator.checkFunction(track)
	return reaper.GetMediaTrackInfo_Value(track, "I_SOLO") > 0
end

soloedTracksNavigator.get = generateGetMethod("Soloed tracks")
soloedTracksNavigator.set_adjust = generateSetMethod("No %s soloed track")

local armedTrackNavigator = {}
catnavLayout.basic:registerProperty(armedTrackNavigator)

function armedTrackNavigator.checkFunction(track)
	return reaper.GetMediaTrackInfo_Value(track, "I_RECARM") ~= 0
end

armedTrackNavigator.get = generateGetMethod("Armed tracks")
armedTrackNavigator.set_adjust = generateSetMethod("No %s armed track")

local instrumentTracksNavigator = {}
catnavLayout.basic:registerProperty(instrumentTracksNavigator)

function instrumentTracksNavigator.checkFunction(track)
	return reaper.TrackFX_GetInstrument(track) > 0
end

instrumentTracksNavigator.get = generateGetMethod("Tracks With instruments")
instrumentTracksNavigator.set_adjust = generateSetMethod("No %s track with an instrument on")

local nonProcessedTracksNavigator = {}
catnavLayout.basic:registerProperty(nonProcessedTracksNavigator)

function nonProcessedTracksNavigator.checkFunction(track)
	return reaper.TrackFX_GetCount(track) == 0 and reaper.GetMediaTrackInfo_Value(track, "D_VOL") ==
		utils.decibelstonum(0.0) and reaper.GetMediaTrackInfo_Value(track, "D_PAN") == utils.percenttonum(0) and
		reaper.GetMediaTrackInfo_Value(track, "D_WIDTH") == utils.percenttonum(100)
end

nonProcessedTracksNavigator.get = generateGetMethod("Tracks which are like as non-processed")
nonProcessedTracksNavigator.set_adjust = generateSetMethod("No %s track which looks like as non-processed")

local soundTracksNavigator = {}
catnavLayout.basic:registerProperty(soundTracksNavigator)

function soundTracksNavigator.checkFunction(track)
	for i = 1, 64 do
		local meter = reaper.Track_GetPeakInfo(track, i)
		if utils.numtodecibels(meter) > -100 then
			return true
		end
	end
end

soundTracksNavigator.get = generateGetMethod("Currently sound")
soundTracksNavigator.set_adjust = generateSetMethod("No %s track which is currently sound")

PropertiesRibbon.presentLayout(catnavLayout)
