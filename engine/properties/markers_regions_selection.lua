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

-- It's just another vision of Properties Ribbon can be applied on

-- Preloading some configs
local allowMove, allowMoveConfig = config.getboolean("allowMoveCursorWhenNavigating", true), config.getboolean("allowMoveCursorWhenNavigating", true)
-- Extended check
do
	local currentAndPreviousEqual
	if extstate.currentLayout then
		currentAndPreviousEqual = currentSublayout == extstate[extstate.currentLayout .. "_sublayout"]
	end
	allowMove = allowMove == true and currentAndPreviousEqual == true and currentExtProperty == nil
end

-- Before define which sublayout we will load when no sublayout found, just load all marker/regions data.
-- Also, it will be used in other cases
local mrretval, numMarkers, numRegions = reaper.CountProjectMarkers(0)

-- We need items to realize the stretch and take markers
local items = item_properties_macros.getItems(config.getboolean("multiSelectionSupport", true))
-- Reading the color from color composer specified section
local function getMarkersComposedColor()
	return extstate.colcom_marker_curValue
end

-- Main class initialization
local parentLayout = initLayout("Markers and regions management")

-- This layout is available always because here creating markers/regions property is.

parentLayout:registerSublayout("markersLayout", "Markers")

local markersActionsProperty = {}
parentLayout.markersLayout:registerProperty(markersActionsProperty)

function markersActionsProperty:get()
	local message = initOutputMessage()
	message:initType("", "")
	message("Markers operations")
	return message
end

markersActionsProperty.extendedProperties = initExtendedProperties(markersActionsProperty:get():extract(nil, false))

markersActionsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to add new marker at play or edit cursor position.")
		message("Insert marker at current position")
		return message
	end,
	set_perform = function(self, parent)
		reaper.Main_OnCommand(40157, 0)
		-- OSARA reports the marker creation events
		setUndoLabel(self:get())
		return false
	end
}

markersActionsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to create new marker and edit it.")
		message("Insert and edit marker at current position")
		return message
	end,
	set_perform = function(self, parent)
		reaper.Main_OnCommand(40171, 0)
		-- OSARA reports the marker creation events
		setUndoLabel(self:get())
		return false
	end
}
markersActionsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to renumber all marker in project timeline. Please note: the standart REAPER action used here, so all regions will be renumbered aswell.")
		message("Renumber all markers in timeline order")
		return message
	end,
	set_perform = function(self, parent)
		if numMarkers > 0 then
			if reaper.ShowMessageBox("Since the main action for renumbering is used, all regions will be renumbered aswell. Would you like to continue?"
				, "Please note", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
				reaper.Main_OnCommand(40898, 0)
				return true, "All markers were renumbered."
			else
				return false, "Canceled."
			end
		end
		return false, "There are no markers which to be renumbered."
	end
}
markersActionsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to remove all markers in time selection.")
		message("Remove all markers from time selection")
		return message
	end,
	set_perform = function(self, parent)
		reaper.Main_OnCommand(40420, 0)
		setUndoLabel(self:get())
		return true, nil, true
	end
}
markersActionsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to remove all markers in the project.")
		message("Clear all markers")
		return message
	end,
	set_perform = function(self, parent)
		local countDeletedMarkers = 0
		for i = 0, numMarkers do
			if reaper.DeleteProjectMarker(0, i, false) then
				countDeletedMarkers = countDeletedMarkers + 1
			end
		end
		if countDeletedMarkers > 0 then
			return true, string.format("%u markers has been deleted.", countDeletedMarkers)
		else
			return false, "There are no markers to delete."
		end
	end
}

markerActions = initExtendedProperties("Marker actions")

if allowMoveConfig == false then
	markerActions:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to move the play or edit cursor to the marker's position.")
			message("Go to marker position")
			return message
		end,
		set_perform = function(self, parent)
			local message = initOutputMessage()
			reaper.GoToMarker(0, parent.mIndex, true)
			message("Jumping to")
			message { value = representation.defpos[reaper.GetCursorPosition()] }
			return true, message
		end
	}
end
markerActions:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to edit this marker.")
		message("Edit marker")
		return message
	end,
	set_perform = function(self, parent)
		-- There is no any different method to show the standart dialog window for user
		local prevPosition = reaper.GetCursorPosition()
		reaper.SetEditCurPos(parent.position, false, false)
		reaper.Main_OnCommand(40614, 0)
		reaper.SetEditCurPos(prevPosition, false, false)
		setUndoLabel(self:get())
		return true
	end
}
markerActions:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to delete this marker.")
		message("Delete marker")
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		message(parent:get())
		reaper.DeleteProjectMarker(0, parent.mIndex, false)
		message:clearValue()
		message { value = "deleted" }
		return true, message
	end
}


if numMarkers > 0 then
	for i = 0, (numMarkers + numRegions) - 1 do
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
		if retval and not isrgn then
			parentLayout.markersLayout:registerProperty({
				position = pos,
				str = name,
				clr = color,
				mIndex = markrgnindexnumber,
				extendedProperties = markerActions,
				get = function(self)
					local message = initOutputMessage()
					message:initType("", "")
					if self.clr > 0 then
						message { objectId = colors:getName(reaper.ColorFromNative(self.clr)) }
					end
					message { label = string.format("Marker %u", self.mIndex) }
					if self.str ~= "" then
						message { label = string.format(", %s", self.str) }
					end
					if allowMove then
						reaper.GoToMarker(0, self.mIndex, true)
						message { value = representation.defpos[self.position] }
					end
					return message
				end
			})
		end
	end
end


-- Regions loading
parentLayout:registerSublayout("regionsLayout", "Regions")
local regionsActionsProperty = {}
parentLayout.regionsLayout:registerProperty(regionsActionsProperty)

function regionsActionsProperty:get()
	local message = initOutputMessage()
	message:initType("", "")
	message("Regions operations")
	return message
end

regionsActionsProperty.extendedProperties = initExtendedProperties(regionsActionsProperty:get():extract(nil, false))

regionsActionsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to insert new region from time selection.")
		message("Insert region from time selection")
		return message
	end,
	set_perform = function(self, parent)
		if markers_regions_selection_macros.isTimeSelectionSet() then
			reaper.Main_OnCommand(40174, 0)
			setUndoLabel(self:get())
			return false
		end
		return false, "No time selection set."
	end
}
regionsActionsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to insert new region from time selection and edit it.")
		message("Insert region from time selection and edit")
		return message
	end,
	set_perform = function(self, parent)
		if markers_regions_selection_macros.isTimeSelectionSet() then
			reaper.Main_OnCommand(40306, 0)
			return true
		end
		return false, "No time selection set."
	end
}
regionsActionsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to insert new region from selected items.")
		message("Insert region from selected items")
		return message
	end,
	set_perform = function(self, parent)
		reaper.Main_OnCommand(40348, 0)
		setUndoLabel(self:get())
		return true, nil, true
	end
}
regionsActionsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to create new region from selected items then edit it.")
		message("Insert region from selected items and edit")
		return message
	end,
	set_perform = function(self, parent)
		reaper.Main_OnCommand(40348, 0)
		return true, nil, true
	end
}
regionsActionsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to create separate region for each selected item.")
		message("Insert separate regions for each selected item")
		return message
	end,
	set_perform = function(self, parent)
		reaper.Main_OnCommand(41664, 0)
		return true, nil, true
	end
}
regionsActionsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to renumber all regions in project timeline. Please note: the standart REAPER action used here, so all markers will be renumbered aswell.")
		message("Renumber all markers and regions in timeline order")
		return message
	end,
	set_perform = function(self, parent)
		if numRegions > 0 then
			if reaper.ShowMessageBox("Since the main action for renumbering is used, all markers will be renumbered aswell. Would you like to continue?"
				, "Please note", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
				reaper.Main_OnCommand(40898, 0)
				return true, "All markers and regions were renumbered."
			else
				return false, "Canceled."
			end
		else
			return false, "There are no regions which to be renumbered."
		end
	end
}
regionsActionsProperty.extendedProperties:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to clear all regions in this project.")
		message("Clear all regions")
		return message
	end,
	set_perform = function(self, parent)
		local countDeletedRegions = 0
		for i = 0, (numMarkers + numRegions) do
			if reaper.DeleteProjectMarker(0, i, true) then
				countDeletedRegions = countDeletedRegions + 1
			end
		end
		if countDeletedRegions > 0 then
			return true, string.format("%u regions deleted. ", countDeletedRegions)
		else
			return false, "There are no regions to delete."
		end
	end
}
local regionActions = initExtendedProperties("Region actions")

if allowMoveConfig == false then
	regionActions:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to smooth seek to the region position after currently region finishes playing..")
			message("Smooth seek to the region")
			return message
		end,
		set_perform = function(self, parent)
			local message = initOutputMessage()
			reaper.GoToRegion(0, parent.rIndex, true)
			message("Smooth seek to")
			message { value = representation.defpos[reaper.GetCursorPosition()] }
			return false, message
		end
	}
end
regionActions:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to move the play or edit cursor to the timestamp when this region starts.")
		message("Immediately jump to start of this region")
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		reaper.SetEditCurPos(parent.position, true, true)
		message { label = "Jumping to" }
		message { value = representation.defpos[reaper.GetCursorPosition()] }
		return true, message
	end
}
regionActions:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to move the play or edit cursor to the timestamp when this region ends.")
		message("Immediately jump to end of this region")
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		reaper.SetEditCurPos(parent.endPosition, true, true)
		message { label = "Jumping to" }
		message { value = representation.defpos[reaper.GetCursorPosition()] }
		return true, message
	end
}
regionActions:registerProperty{
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to set the project selection by this region range.")
		message("Set selection by this region")
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		if reaper.GetSet_LoopTimeRange(true, false, parent.position, parent.endPosition, true) then
			message("Selection set.")
		end
		return true, message, true
	end
}
regionActions:registerProperty{
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to set the project loop points by this region range.")
		message("Set loop points by this region")
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		if reaper.GetSet_LoopTimeRange(true, true, parent.position, parent.endPosition, true) then
			message("Loop points set.")
		end
		return true, message, true
	end
}
regionActions:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to edit this region.")
		message("Edit region")
		return message
	end,
	set_perform = function(self, parent)
		-- There is no any different method to show the standart dialog window for user
		local prevPosition = reaper.GetCursorPosition()
		reaper.SetEditCurPos(parent.position, false, false)
		reaper.Main_OnCommand(40616, 0)
		reaper.SetEditCurPos(prevPosition, false, false)
		return true
	end
}
regionActions:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to delete this region.")
		message("Delete region")
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		message(parent:get())
		reaper.DeleteProjectMarker(0, parent.rIndex, true)
		message:clearValue()
		message { value = "deleted" }
		return true, message
	end
}

if numRegions > 0 then
	for i = 0, (numMarkers + numRegions) - 1 do
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
		if retval and isrgn then
			parentLayout.regionsLayout:registerProperty({
				position = pos,
				endPosition = rgnend,
				str = name,
				clr = color,
				rIndex = markrgnindexnumber,
				get = function(self)
					local message = initOutputMessage()
					message:initType("", "")
					if self.clr > 0 then
						message { objectId = colors:getName(reaper.ColorFromNative(self.clr)) }
					end
					message { label = string.format("Region %u", self.rIndex) }
					if self.str ~= "" then
						message { value = self.str }
					end
					if allowMove then
						reaper.GoToRegion(0, self.rIndex, true)
						message { value = representation.defpos[self.position] }
					end
					return message
				end,
				extendedProperties = regionActions
			})
		end
	end
end

-- Moved code from item properties
-- We need the greenlight function of item properties below, but Properties ribbon does not allow to call a layouts as isolated code yet.
function canWorkWithItems()
	-- We do not support the empty lanes
	local itemsCount = reaper.CountSelectedMediaItems(0)
	local isEmptyLanes = false
	for i = 0, itemsCount - 1 do
		if reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, i)) == nil then
			if not extstate._layout.emptyLanesNotify then
				reaper.ShowMessageBox("Seems you trying to interract with take, which is empty lane. Properties Ribbon does not supports the empty lanes, because there are no possibility to interract with, but processing of cases with takes more time of developing. You may switch off the empty lanes selection to not catch this message again or switch this item take manualy before load this layout."
					, "Empty lane", showMessageBoxConsts.sets.ok)
				extstate._layout.emptyLanesNotify = true
			end
			isEmptyLanes = true
			break
		end
	end
	return (itemsCount > 0 and isEmptyLanes == false)
end

-- Stretch markers realisation

-- Some pre-defined properties and extended properties
local stretchMarkerActions = {}

function stretchMarkerActions:get()
	local message = initOutputMessage()
	message:initType("", "")
	message("Stretch markers operations")
	return message
end

stretchMarkerActions = initExtendedProperties("Stretch marker actions")

if allowMoveConfig == false then
	stretchMarkerActions:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to move the play or edit cursor to stretch marker position.")
			message("Go to stretch marker position")
			return message
		end,
		set_perform = function(self, parent)
			local message = initOutputMessage()
			reaper.SetEditCurPos(item_properties_macros.pos_relativeToGlobal(parent.marker.item, parent.marker.pos), true, true)
			message { label = "Moving to", value = representation.defpos[reaper.GetCursorPosition()] }
			return true, message
		end
	}
end
stretchMarkerActions:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to pull this stretch marker to play or edit cursor position.")
		message("Pull stretch marker")
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		local curpos = reaper.GetCursorPosition()
		local itemPosition, takePlayrate, itemLength = reaper.GetMediaItemInfo_Value(parent.marker.item, "D_POSITION"),
			reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(parent.marker.item), "D_PLAYRATE"),
			reaper.GetMediaItemInfo_Value(parent.marker.item, "D_LENGTH")
		reaper.SetTakeStretchMarker(reaper.GetActiveTake(parent.marker.item), parent.marker.idx,
			((curpos - itemPosition) * takePlayrate))
		message(parent:get())
		message:clearValue()
		message { value = string.format("pulled onto %s.", representation.defpos[curpos]) }
		return true, message, true
	end
}
stretchMarkerActions:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to edit this stretch marker.")
		message("Edit stretch marker")
		return message
	end,
	set_perform = function(self, parent)
		local curpos = reaper.GetCursorPosition()
		reaper.SetEditCurPos(item_properties_macros.pos_relativeToGlobal(parent.marker.item, parent.marker.pos), false, false)
		reaper.Main_OnCommand(41988, 0)
		reaper.SetEditCurPos(curpos, false, false)
		setUndoLabel(self:get(true))
		return true
	end
}
stretchMarkerActions:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to delete this stretch marker.")
		message("Delete stretch marker")
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		message(parent:get())
		reaper.DeleteTakeStretchMarkers(reaper.GetActiveTake(parent.marker.item), parent.marker.idx)
		message:clearValue()
		message { label = " has been", value = "deleted" }
		return true, message
	end
}

parentLayout:registerSublayout("stretchMarkersLayout", "Take stretch markers")

local function formStretchMarkerProperties(item)
	if not canWorkWithItems() then
		return
	end
	for i = 0, reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(item)) do
		local stretchMarker = {}
		stretchMarker.item = item
		stretchMarker.idx = i
		stretchMarker.retval, stretchMarker.pos, stretchMarker.srcpos = reaper.GetTakeStretchMarker(reaper.GetActiveTake(item)
			, i)
		if stretchMarker.retval ~= -1 then
			parentLayout.stretchMarkersLayout:registerProperty({
				marker = stretchMarker,
				get = function(self)
					local message = initOutputMessage()
					message:initType("", "")
					local markerPulled = false
					-- The srcpos which returns a stretch marker relies the original file's length
					do
						local src = reaper.GetMediaItemTake_Source(reaper.GetActiveTake(self.marker.item))
						-- There is two return arguments but we using only one right now. I not understood which case will changes the length to another format, so it is checking based on that fact that we get time always.
						local srcLength = reaper.GetMediaSourceLength(src)
						local itemPosition, takePlayrate, itemLength = reaper.GetMediaItemInfo_Value(self.marker.item, "D_POSITION"),
							reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(self.marker.item), "D_PLAYRATE"),
							reaper.GetMediaItemInfo_Value(self.marker.item, "D_LENGTH")
						-- TODO: Clarify the symbols amount by which the values should be rounded. Also clarify whether the playrate should be used
						markerPulled = (
							utils.round(self.marker.pos, 6) ~= utils.round((self.marker.srcpos - ((srcLength - itemLength) * takePlayrate)), 6)
							)
					end
					message { label = string.format("%stretch marker %u of %s %s", ({ [false] = "S", [true] = "Pulled s" })[
						markerPulled], self.marker.idx + 1, item_properties_macros.getItemID(self.marker.item),
						item_properties_macros.getTakeID(self.marker.item)) }
					if allowMove then
						reaper.SetEditCurPos(item_properties_macros.pos_relativeToGlobal(self.marker.item, self.marker.pos), true, true)
						message { value = representation.defpos[
							item_properties_macros.pos_relativeToGlobal(self.marker.item, self.marker.pos)] }
					end
					return message
				end,
				extendedProperties = stretchMarkerActions
			})
		end
	end
end

-- Take markers
parentLayout:registerSublayout("takeMarkersLayout", "Take markers")
-- Take markers pre-defined actions
local takeMarkerActions = initExtendedProperties("Take marker actions")
if allowMoveConfig == false then
	takeMarkerActions:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to move the play or edit cursor to take marker position.")
			message("Go to take marker")
			return message
		end,
		set_perform = function(self, parent)
			local message = initOutputMessage()
			reaper.SetEditCurPos(item_properties_macros.pos_relativeToGlobal(parent.marker.item, parent.marker.pos), true, true)
			message { label = "Move to", value = representation.defpos[reaper.GetCursorPosition()] }
			return true, message
		end
	}
end
takeMarkerActions:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to edit this take marker.")
		message("Edit take marker")
		return message
	end,
	set_perform = function(self, parent)
		local curpos = reaper.GetCursorPosition()
		reaper.SetEditCurPos(item_properties_macros.pos_relativeToGlobal(parent.marker.item, parent.marker.pos), false, false)
		reaper.Main_OnCommand(42385, 0)
		reaper.SetEditCurPos(curpos, false, false)
		setUndoLabel(self:get(true))
		return true
	end
}
takeMarkerActions:registerProperty {
	get = function(self, parent)
		local message = initOutputMessage()
		message:initType("Perform this property to delete this take marker.")
		message("Delete take marker")
		return message
	end,
	set_perform = function(self, parent)
		local message = initOutputMessage()
		message(parent:get())
		message:clearValue()
		if reaper.DeleteTakeMarker(reaper.GetActiveTake(parent.marker.item), parent.marker.idx) then
			message { label = " has been", value = "deleted" }
		else
			message { value = "cannot be deleted" }
		end
		return true, message
	end
}

local function formTakeMarkersProperties(item)
	if not canWorkWithItems() then
		return
	end
	-- REAPER doesn't sort the take markers and not provides any method to get the ordered list even with non-sorted indexes. So, we will sort this manualy.
	local takeMarkers = {}
	for i = 0, reaper.GetNumTakeMarkers(reaper.GetActiveTake(item)) do
		local takeMarker = {}
		takeMarker.item = item
		takeMarker.idx = i
		takeMarker.pos, takeMarker.name, takeMarker.color = reaper.GetTakeMarker(reaper.GetActiveTake(item), i)
		if takeMarker.retval ~= -1 then
			table.insert(takeMarkers, takeMarker)
		end
	end
	table.sort(takeMarkers,
		function(a, b)
			if a.pos < b.pos then
				return true
			end
			return false
		end
	)
	for i, val in ipairs(takeMarkers) do
		val.num = i - 1
	end
	-- Clearing off the start take marker cuz it just start point
	table.remove(takeMarkers, 1)
	for _, takeMarker in ipairs(takeMarkers) do
		parentLayout.takeMarkersLayout:registerProperty({
			marker = takeMarker,
			get = function(self)
				local message = initOutputMessage()
				message:initType("", "")
				if self.marker.color > 0 then
					message { objectId = colors:getName(reaper.ColorFromNative(self.marker.color)) }
				end
				if self.marker.num == 0 then
					message { label = "Start take marker" }
				else
					message { label = string.format("Take marker %u", self.marker.num) }
				end
				if self.marker.name then
					message { label = string.format(", %s", self.marker.name) }
				end
				message { label = string.format(" in %s of %s", item_properties_macros.getTakeID(self.marker.item),
					item_properties_macros.getItemID(self.marker.item)) }
				if allowMove then
					reaper.SetEditCurPos(self.marker.pos, true, true)
					message { value = representation.defpos[self.marker.pos] }
				end
				return message
			end,
			extendedProperties = takeMarkerActions
		})
	end
end

-- Main stretch markers actions
local stretchMarkersActionsProperty = {}
parentLayout.stretchMarkersLayout:registerProperty(stretchMarkersActionsProperty)

function stretchMarkersActionsProperty:get()
	local message = initOutputMessage()
	if canWorkWithItems() then
		message:initType("", "")
	else
		message:initType("This property is unavailable right now because Properties Ribbon cannot work with items.",
			"Unavailable")
	end
	message("Stretch markers operations")
	return message
end

if canWorkWithItems() then
	stretchMarkersActionsProperty.extendedProperties = initExtendedProperties(stretchMarkersActionsProperty:get():extract(nil
		, false))
	stretchMarkersActionsProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to insert a stretch marker at the play or edit cursor position.")
			message("Add stretch marker at cursor")
			return message
		end,
		set_perform = function(self, parent)
			local item = item_properties_macros.getSelectedItemAtCursor(items)
			if item then
				local prevMarkersCount = reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(item))
				reaper.Main_OnCommand(41842, 0)
				local newMarkersCount = reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(item))
				if prevMarkersCount < newMarkersCount then
					return false, "Stretch marker added."
				else
					return false, "No stretch markers created."
				end
			else
				return false, "No item selected at this position"
			end
		end
	}
	stretchMarkersActionsProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to add a stretch markers at the edges of the time selection.")
			message("Add stretch markers at time selection")
			return message
		end,
		set_perform = function()
			if not markers_regions_selection_macros.isTimeSelectionSet() then
				return false, "No time selection set."
			end
			local item = item_properties_macros.getSelectedItemAtCursor(items)
			if item then
				local prevMarkersCount = reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(item))
				reaper.Main_OnCommand(41843, 0)
				local newMarkersCount = reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(item))
				if prevMarkersCount < newMarkersCount then
					return false, "Stretch markers added by time selection."
				else
					return false, "No stretch markers created."
				end
			else
				return false, "No item selected at this position"
			end
		end
	}
	stretchMarkersActionsProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to add a stretch marker at the play or edit cursor and edit it right now")
			message("Add stretch marker at cursor and edit")
			return message
		end,
		set_perform = function(self, parent)
			reaper.Main_OnCommand(41842, 0)
			reaper.Main_OnCommand(41988, 0)
			return false
		end
	}
	stretchMarkersActionsProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to delete all stretch markers in selected items takes.")
			message("Delete all stretch markers")
			return message
		end,
		set_perform = function(self, parent)
			local item = item_properties_macros.getSelectedItemAtCursor(items)
			if item then
				local prevMarkersCount = reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(item))
				reaper.Main_OnCommand(41844, 0)
				local newMarkersCount = reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(item))
				if prevMarkersCount > newMarkersCount then
					return true, "All Stretch markers deleted."
				else
					return true, "No stretch markers deleted."
				end
			else
				return false, "No item selected at this position"
			end
		end
	}
end

-- creating the stretch markers properties by the items list
if istable(items) then
	for _, item in ipairs(items) do
		formStretchMarkerProperties(item)
	end
else
	formStretchMarkerProperties(items)
end

local takeMarkersActionsProperty = {}
parentLayout.takeMarkersLayout:registerProperty(takeMarkersActionsProperty)

function takeMarkersActionsProperty:get()
	local message = initOutputMessage()
	if canWorkWithItems() then
		message:initType("", "")
	else
		message:initType("This property is unavailable right now because Properties Ribbon cannot work with items.",
			"Unavailable")
	end
	message("Take markers operations")
	return message
end

if canWorkWithItems() then
	takeMarkersActionsProperty.extendedProperties = initExtendedProperties(takeMarkersActionsProperty:get():extract(nil,
		false))

	takeMarkersActionsProperty.extendedProperties:registerProperty {
		get = function(self, parentLayout)
			local message = initOutputMessage()
			message:initType("Perform this property to create a take marker at the play or edit cursor position.")
			message("Create take marker at current position")
			return message
		end,
		set_perform = function(self, parent)
			local item = item_properties_macros.getSelectedItemAtCursor(items)
			if item then
				local prevTakeMarkersCount = reaper.GetNumTakeMarkers(reaper.GetActiveTake(item))
				reaper.Main_OnCommand(42390, 0)
				local newTakeMarkersCount = reaper.GetNumTakeMarkers(reaper.GetActiveTake(item))
				return false, string.format("%u take markers created", (newTakeMarkersCount - prevTakeMarkersCount))
			else
				return false, "No item selected at this position"
			end
		end
	}
	takeMarkersActionsProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to create a take marker at play or edit cursor position and edit it.")
			message("Create take marker at current position and edit it")
			return message
		end,
		set_perform = function(self, parent)
			reaper.Main_OnCommand(42385, 0)
			return true
		end
	}
	takeMarkersActionsProperty.extendedProperties:registerProperty {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType("Perform this property to delete all stretch markers.")
			message("Delete all take markers")
			return message
		end,
		set_perform = function(self, parent)
			reaper.Main_OnCommand(42387, 0)
			return true
		end
	}
end

-- creating the take markers properties by the items list
if istable(items) then
	for _, item in ipairs(items) do
		formTakeMarkersProperties(item)
	end
else
	formTakeMarkersProperties(items)
end

return parentLayout