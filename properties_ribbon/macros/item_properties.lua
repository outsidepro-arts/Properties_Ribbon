--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2024 outsidepro-arts
License: MIT License

----------
]]
--


-- This file contains a macros for specified solutions. Use this macros at own properties.

item_properties_macros = {}
---@alias item userdata
---@alias take userdata

---Gets all selected items or first selected item (depending on )multiSelectionSupport option)
---@param multiSelectionSupport  boolean defines the multi-selection support
---@return item[] | item either array of selected items or one item object (if there's one only)
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

---retrieves the number of the selected item
---@param item item
---@return integer
function item_properties_macros.getItemNumber(item)
	return reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER") + 1
end

---retrieves the active take number of selected item
---@param item item
---@return integer
function item_properties_macros.getTakeNumber(item)
	return reaper.GetMediaItemInfo_Value(item, "I_CURTAKE") + 1
end

---Composes the formatted item name and its state
---@param item item
---@param shouldSilentColor? boolean should this function omit the color value? (false by default)
---@return string
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

---Composes the formatted name of active take in selected item and its state
---@param item item
---@param shouldSilentColor? boolean should this function omit the color value? (false by default)
---@return string
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

---# Wraper for cases where user has selected more than one items and layout title should present the selected items names (when object identification is off) #
---@param itemObj item | item[]
---@return string
function item_properties_macros.getItemAndTakeIDForTitle(itemObj)
	if istable(itemObj) then
		local itemsIdentifiers = {}
		for index, item in ipairs(itemObj) do
			if index < 5 then
				itemsIdentifiers[#itemsIdentifiers + 1] = string.format("%s of %s",
					item_properties_macros.getTakeID(item), item_properties_macros.getItemID(item, true))
			else
				itemsIdentifiers[#itemsIdentifiers + 1] = string.format("%u items more", #itemObj - 4)
				break
			end
		end
		itemsIdentifiers[#itemsIdentifiers] = itemsIdentifiers[#itemsIdentifiers - 1]:join(" and ",
			itemsIdentifiers[#itemsIdentifiers])
		table.remove(itemsIdentifiers, #itemsIdentifiers - 1)
		return table.concat(itemsIdentifiers, ", ")
	else
		return string.format("%s of %s",
			item_properties_macros.getTakeID(itemObj), item_properties_macros.getItemID(itemObj, true))
	end
end

---Retrieves the item from selected items which currently positiones at the play cursor's position
---@param items item[] | item the result from function getItems
---@return item
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

---Converts the relative position relating the given item to global REAPER position
---@param item item
---@param rel number Position in given item
---@return number
function item_properties_macros.pos_relativeToGlobal(item, rel)
	local itemPosition, takePlayrate = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
		reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE")
	return (itemPosition + rel) / takePlayrate
end

---Converts the global REAPER position to relative relating by given item
---@param item item
---@return number
function item_properties_macros.pos_globalToRelative(item)
	local itemPosition, takePlayrate = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
		reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE")
	return (reaper.GetCursorPosition() - itemPosition) * takePlayrate
end
