--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2025 outsidepro-arts & other contributors
License: MIT License
]]
--

require "utils.conversion"
require "utils.iters"
require "utils.math"
require "utils.string"
require "utils.table"
require "utils.debugger"
bitwise = require "utils.bitwisewraps"

-- Here are some functions which I have been grabbed from some sources and opensource projects. Some of was needed to be rewritten for LUA, but some of already being presented as is also.
-- Unfortunately, not all functions written here I remembered where grabbed, because I wrote it at the start of complex coding and did not planned to git this..
-- If you outraged of, please let me know about via issues in the repository.

local utils = {}

function math.round(num, numDecimalPlaces)
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
		return math.round(v, 2)
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
	local preproc = str:gsub("%s.", string.upper):gsub("%s", ""):gsub(":", ""):gsub("%W", "_")
	return preproc:gsub("^.", string.lower)
end

function nor(state)
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

function utils.simpleSearch(fullString, searchString, delimiter)
	fullString = tostring(fullString)
	searchString = tostring(searchString)
	local searchParts
	if delimiter then
		searchParts = searchString:split(delimiter, false)
	else
		searchParts = { searchString }
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
		searchParts = { searchString }
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

function utils.truncateSmart(stringShouldbeTruncated, truncateLength)
	local truncatedString = stringShouldbeTruncated
	-- We will not work with string as usual cuz REAPER may provide us the multibyte UTF8 strings.
	-- But Lua provides us the raw UTF8 processing, so we will attempt to solve this trouble like that.
	if utf8.len(stringShouldbeTruncated) > truncateLength then
		truncatedString = nil
		-- There is utility function which allows us to iterate the string by character. It also uses UTF8 method for saving the characters. So, we;re gonna steal the iteration object for our purposes!
		local strTable = select(2, stringShouldbeTruncated:sequentchar())
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
		result = result ..
			({ [1] = base:sub(charIndex, charIndex):lower(), [2] = base:sub(charIndex, charIndex):upper() })
			[math.random(1, 2)]
	end
	return result
end

function utils.makeKeySequence(...)
	local args = {}
	for _, arg in ipairs(table.pack(...)) do
		if istable(arg) then
			for _, subarg in ipairs(arg) do
				table.insert(args, subarg)
			end
		else
			table.insert(args, arg)
		end
	end
	return table.concat(args, ".")
end

-- Returns the platform name based on REAPER's runnen version
function utils.platform()
	local platform = reaper.GetAppVersion():match("/([a-zA-Z]+)%W?%d?")
	if not platform or (platform and string.len(platform) < 3) then
		platform = "Windows"
	end
	return platform
end

function openPath(path)
	-- We have to define the operating system to choose needed terminal command.
	local startCmd = nil
	if utils.platform() == "Windows" then
		startCmd = "start"
	else -- We are on another platform, that assumes Unix systems (REAPER builds only for two OS) which implies that's MacOS
		startCmd = "open"
	end
	if startCmd then
		os.execute(string.format("%s %s", startCmd, path))
	end
end

function fixPath(path)
	path = assert(isstring(path) and path, ("The string is expected (got %s)"):format(type(path)))
	if path:match("^%u:") then
		return path
	else
		return select(1, PropertiesRibbon.script_path:rpart(package.config:sub(1, 1))):joinsep(package.config:sub(1, 1),
			path)
	end
end

--- Escaping Lua pattern
-- @param s string The string to escaped
-- @return string The escaped string
function utils.escapeLuaPatternChars(s)
	s = assert(isstring(s) and s, ("The string is expected (got %s)"):format(type(s)))
	local prohibitedChars = setmetatable(
		{
			["%"] = "%%",
			["."] = "%.",
			["+"] = "%+",
			["-"] = "%-",
			["*"] = "%*",
			["?"] = "%?",
			["["] = "%[",
			["]"] = "%]",
			["^"] = "%^",
			["$"] = "%$",
			["("] = "%(",
			[")"] = "%)",
		}, {
			__index = function(self, key)
				return key
			end
		}
	)
	local ns = ""
	for _, char in s:sequentchar() do
		ns = ns:join(prohibitedChars[char])
	end
	return ns
end

---Returns the most frequent numerical value of the array
---@param arr [number]|[any] either array of numbers or array of objects to check
---@param getFunc? function(value) If a passed array contains not number types, this function should process every item in this array.
---@return number The most frequent value in the passed array.
function utils.getMostFrequent(arr, getFunc)
	local counts = {}
	local firstOccurrence = {}
	for i, value in ipairs(arr) do
		value = getFunc and getFunc(value)
		if counts[value] == nil then
			counts[value] = 1
			firstOccurrence[value] = i
		else
			counts[value] = counts[value] + 1
		end
	end
	local maxCount = -math.huge
	local candidates = {}
	for key, count in pairs(counts) do
		if count > maxCount then
			maxCount = count
			candidates = { key }
		elseif count == maxCount then
			table.insert(candidates, key)
		end
	end
	local result
	local min_index = math.huge
	for _, candidate in ipairs(candidates) do
		if firstOccurrence[candidate] < min_index then
			min_index = firstOccurrence[candidate]
			result = candidate
		end
	end
	return result
end

---Returns true if all values in the array are the same
---@param arr [any] array of objects to check
---@param getFunc? function(value) If this parameter is not passed, all elements will check just simple comparison. Otherwise, every element will be processed by this function before comparison.
---@return boolean
function utils.isAllTheSame(arr, getFunc)
	local state = nil
	for i, value in ipairs(arr) do
		value = getFunc and getFunc(value)
		if state == nil then
			state = value
		elseif state ~= value then
			return false
		end
	end
	return true
end

---Concatenates the passed strings into one sentence
---@param ... string|number
---@return string
function utils.concatSentence(...)
	local res = {}
	local endSentence = false
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		if arg then
			arg = assert((arg and (isstring(arg) or isnumber(arg)) and arg) and tostring(arg),
				("The string or number is expected (got %s)"):format(type(arg)))
			if not endSentence and arg:match("^%u%l+%A") then
				res[#res + 1] = arg:gsub("^%a-", string.lower)
			else
				res[#res + 1] = arg
			end
			if arg:match("[.!?]%s?$") then
				endSentence = true
			else
				endSentence = false
			end
		end
	end
	return table.concat(res, "")
end

return utils
