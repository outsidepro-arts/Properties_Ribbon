--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts & other contributors
License: MIT License
]] --

-- Here are some functions which I have been grabbed from some sources and opensource projects. Some of was needed to be rewritten for LUA, but some of already being presented as is also.
-- Unfortunately, not all functions written here I remembered where grabbed, because I wrote it at the start of complex coding and did not planned to git this..
-- If you outraged of, please let me know about via issues in the repository.

local utils = {}

function utils.round(num, numDecimalPlaces)
	local negative = false
	if num < 0 then
		negative = true
		num = -num
	end
	local mult = 10 ^ (numDecimalPlaces or 0)
	if negative == true then
		return -math.floor(num * mult + 0.5) / mult
	else
		return math.floor(num * mult + 0.5) / mult
	end
end

-- These two functions have been based on project WDL (https://github.com/justinfrankel/WDL)
function utils.numtodecibels(num)
	local v = 0
	if num < 0.0000000298023223876953125 then
		return -150.0
	end
	v = math.log(num) * 8.6858896380650365530225783783321
	if v < -150 then
		return -150.0
	else
		return utils.round(v, 2)
	end
end

function utils.decibelstonum(db)
	if db == "-inf" then
		return 0
	end
	return math.exp(db * 0.11512925464970228420089957273422)
end

-- .

-- This function originaly written by @electrik-spb in PureBasic and rewritten by me for LUA.
function utils.numtopercent(num)
	return math.floor(num / (1 / 100))
end

-- This function based on previous function but just reversed.
function utils.percenttonum(perc)
	return perc / (1 * 100)
end

function utils.toboolean(value)
	if isstring(value) then
		return ({ ["false"] = false, ["true"] = true })[value]
	else
		return (value > 0)
	end
end

-- This function written by @electrik-spb in PureBasic and rewritten by me for LUA.
-- Thank you for help with, Sergey!
function utils.getBitValue(value, first, last)
	return ((value & ((1 << last) - 1)) >> (first - 1))
end

function utils.delay(ms)
	local curTime = os.clock() / 0.001
	while (os.clock() / 0.001 - curTime) <= ms do math.pow(2, 64) end
end

-- The math.pow method is removed from ReaScript platform
-- This realization is very simple, but takes a CPU loading. We use this method nowhere else that in delay function to decelerate the waiting.
function math.pow(a, b)
	local r = 1
	for i = 1, b do
		r = r * a
	end
	return r
end

function utils.removeSpaces(str)
	str = tostring(str)
	preproc = str:gsub("%s.", string.upper):gsub("%s", ""):gsub("%W", "_")
	return preproc:gsub("^.", string.lower)
end

function utils.nor(state)
	if isnumber(state) then
		if state <= 1 then
			state = state ~ 1
		end
	elseif isboolean(state) then
		if state == true then
			state = false
		elseif state == false then
			state = true
		end
	end
	return state
end

function debug(...)
local args = {}
	-- Forcedly converting all arguments to string
	for _, arg in ipairs{...} do
		table.insert(args, tostring(arg))
	end
	reaper.ShowConsoleMsg(string.format("%s\n", table.concat(args, '\t')))
	-- WIN32 functions are exist only in Windows
	if utils.platform() == "Windows" then
		-- ReaConsole does not takes the focus by itself, so we have to make it forcedly.
		if select(2,
			reaper.BR_Win32_GetWindowText(
				reaper.BR_Win32_GetParent(
					reaper.BR_Win32_GetFocus()
				)
			)
		) ~= "ReaScript console output" then
			local consoleWindow = reaper.BR_Win32_FindWindowEx(
				reaper.BR_Win32_HwndToString(
					reaper.BR_Win32_GetParent(
						reaper.BR_Win32_GetMainHwnd()
					)
				), "0", "#32770", "ReaScript console output", true, true)
			reaper.BR_Win32_SetFocus(consoleWindow)
		end
	end
end

function utils.simpleSearch(fullString, searchString, delimiter)
	fullString = tostring(fullString)
	searchString = tostring(searchString)
	local searchParts
	if delimiter then
		searchParts = searchString:split(delimiter, false)
	else
		searchParts = {searchString}
	end
	for _, sBlock in ipairs(searchParts) do
		if sBlock:find("%u") then
			if fullString:find(sBlock) then
				return true
			end
		else
			if fullString:lower():find(sBlock:lower()) then
				return true
			end
		end
	end
end

function utils.extendedSearch(fullString, searchString, caseSensetive, luaPatterns, delimiter)
	assert(fullString, "source string did not provided")
	fullString = tostring(fullString)
	assert(searchString, "The search string did not provided")
	searchString = tostring(searchString)
	caseSensetive = caseSensetive or false
	luaPatterns = luaPatterns or false
	local searchParts
	if delimiter then
		searchParts = searchString:split(delimiter)
	else
		searchParts = {searchString}
	end
	for _, sBlock in ipairs(searchParts) do
		if caseSensetive then
			if fullString:find(sBlock, nil, luaPatterns) then
				return true
			end
		else
			if fullString:lower():find(sBlock:lower(), nil, luaPatterns) then
				return true
			end
		end
	end
end

-- The multibyte strings cannot be processed by the Lua String library correctly.
function utils.exposeUTF8Chars(utfString)
	local result = {}
	for _, character in utf8.codes(utfString) do
		table.insert(result, utf8.char(character))
	end
	return result
end

function utils.truncateSmart(stringShouldbeTruncated, truncateLength)
	local truncatedString = stringShouldbeTruncated
	-- We will not work with string as usual cuz REAPER may provide us the multibyte UTF8 strings.
	-- But Lua provides us the raw UTF8 processing, so we will attempt to solve this trouble like that.
	if utf8.len(stringShouldbeTruncated) > truncateLength then
		truncatedString = nil
		local strTable = utils.exposeUTF8Chars(stringShouldbeTruncated)
		local lastChunkLeft = 0
		for i = truncateLength, 1, -1 do
			local char = utf8.codepoint(strTable[i])
			-- The char code is more comfort for checking
			if char == 32 or char == 45 or char == 95 then
				lastChunkLeft = i
				break
			end
		end
		local lastChunkRight = 0
		for i = truncateLength + 1, #strTable do
			local char = utf8.codepoint(strTable[i])
			if char == 32 or char == 45 or char == 95 then
				lastChunkRight = i
				break
			end
		end
		if lastChunkLeft > 0 and lastChunkRight > 0 then
			truncatedString = table.concat(strTable, "", 1, lastChunkLeft - 1)
			if (lastChunkRight - truncateLength) > (truncateLength - lastChunkLeft) then
				truncatedString = truncatedString .. table.concat(strTable, "", lastChunkLeft, lastChunkRight - 1)
			end
			truncatedString = truncatedString .. "..."
		elseif lastChunkLeft == 0 and lastChunkRight > 0 then
			truncatedString = table.concat(strTable, "", 1, lastChunkRight - 1) .. "..."
		elseif lastChunkLeft > 0 and lastChunkRight == 0 then
			truncatedString = table.concat(strTable, "", 1, lastChunkLeft - 1) .. "..."
		elseif lastChunkLeft == 0 and lastChunkRight == 0 then
			if (#strTable - truncateLength) < truncateLength then
				truncatedString = table.concat(strTable, "") .. "..."
			end
		end
		if not truncatedString then
			truncatedString = table.concat(strTable, "", 1, truncateLength) .. "..."
		end
	end
	return truncatedString
end

function utils.generateID(minLength, maxLength)
	local result = ""
	local base = "abcdefghijklmnopqrstuvwxyz" .. os.date():gsub("%D", "")
	for i = 1, math.random(minLength, maxLength) do
		local charIndex = math.random(#base)
		result = result .. ({ [1] = base:sub(charIndex, charIndex):lower(), [2] = base:sub(charIndex, charIndex):upper() })[math.random(1, 2)]
	end
	return result
end

function utils.makeKeySequence(...)
	return table.concat(table.pack(...), ".")
end

-- Returns the platform name based on REAPER's runnen version
function utils.platform()
	local platform = reaper.GetAppVersion():match("/([a-zA-Z]+)%W?%d?")
	if not platform or (platform and string.len(platform) < 3) then
		platform = "Windows"
	end
	return platform
end

return utils