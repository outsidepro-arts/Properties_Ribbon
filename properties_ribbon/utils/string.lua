function string.split(str, delimiter, mode)
	str = tostring(str)
	delimiter = tostring(delimiter)
	delimiter = delimiter or "%s"
	if type(mode) == "boolean" then
		if mode == true then
			mode = false
		else
			mode = true
		end
	else
		mode = true
	end
	local t, spos = {}, 1
	while string.find(str, delimiter, spos, mode) ~= nil do
		local startFindPos, endFindPos = str:find(delimiter, spos, mode)
		table.insert(t, str:sub(spos, startFindPos - 1))
		spos = endFindPos + 1
	end
	table.insert(t, str:sub(spos))
	return t
end

function string.sequentsep(str, delimiter, mode)
	local t = str:split(delimiter, mode)
	return next, t
end

function string.sequentchar(str)
	local t = {}
	for _, char in utf8.codes(str) do
		table.insert(t, utf8.char(char))
	end
	return ipairs(t)
end

function string.joinsep(orig, sep, ...)
	sep = sep or ""
	local result = {}
	table.insert(result, orig)
	for _, field in ipairs(table.pack(...)) do
		table.insert(result, field)
	end
	return table.concat(result, sep)
end

function string.join(orig, ...)
	return orig:joinsep(nil, ...)
end

function string.lpart(orig, sep)
	local left, sp, right = orig:match(string.join("^(.-)(", sep, ")(.+)"))
	if left and sp and right then
		return left, sp, right
	end
end

function string.rpart(orig, sep)
	local left, sp, right = orig:match(string.join("(.+)(", sep, ")(.+)$"))
	if left and sp and right then
		return left, sp, right
	end
end

-- Simple XOR encryption
---@param str string @The string which should be encrypted
---@param key number @The value which will beused for bit shifting (-128...128 Ascii)
---@return string
function string.xor_encrypt(str, key)
	local encrypted = ""
	for i in str:sequentchar() do
		encrypted = encrypted:join(string.char(bit32.bxor(string.byte(str, i), key)))
	end
	return encrypted
end

-- Simple XOR Decryption
---@param str string @The string which should be decrypted
---@param key number @The value which will beused for bit shifting (-128...128 Ascii)
---@return string
function string.xor_decrypt(str, key)
	local decrypted = ""
	for i = 1, #str do
		decrypted = decrypted:join(string.char(bit32.bxor(string.byte(str, i), key)))
	end
	return decrypted
end

-- Format dictionary
---@param s string @The string which should be formatted
---@param dict table @The table which contains the key which the string might contain and matched value for specified key.
---@return string The formatted string
function string.formatdict(s, dict)
	assert(type(s) == "string", "bad argument #1 to 'formatdict' (string expected, got " .. type(s) .. ")")
	for var in s:gmatch("{(%w+)}") do
		s = s:gsub("{" .. var .. "}", dict[var], nil, true)
	end
	return s
end

local oldformat = string.format
function string.format(s, ...)
	assert(type(s) == "string", "bad argument #1 to 'formatdict' (string expected, got " .. type(s) .. ")")
	local args = {...}
	if s:find("{.+}") then
		if type(args[1]) == "table" then
			s = s:gsub("{(.-)}", function(key)
				return args[1][key]
			end)
			table.remove(args, 1)
		end
		s = s:gsub("{(.-)}", function(key)
			local level, counter = 4, 1
			local varname, varvalue = debug.getlocal(level, counter)
			while varname do
				if varname == key then
					return varvalue
				end
				counter = counter + 1
				varname, varvalue = debug.getlocal(level, counter)
			end
			return _G[key]
		end)
	end
	if s:find("<.+>") then
		local level, counter = 2, 0
		local varname, varvalue = nil
		local lvarsText = ""
		local function divetable(uk, uv, wrapKey)
			lvarsText = oldformat("%s%s = {", lvarsText, wrapKey and oldformat("[%s]", uk) or uk)
			for k, v in pairs(uv) do
				if type(v) == "table" then
					divetable(k, v, true)
				else
					lvarsText = oldformat("%s[%s]=%s,", lvarsText, type(k) == "string" and oldformat('"%s"', k) or k, type(v) == "string" and oldformat('"%s"', v) or v)
				end
			end
			lvarsText = lvarsText:gsub(",$", "")
			lvarsText = lvarsText .. "},"
		end
		repeat
			counter = counter + 1
			varname, varvalue = debug.getlocal(level, counter)
			if (varname and type(varvalue) == "number") and varname:sub(1, 1) ~= "(" then
				lvarsText = oldformat("%slocal %s = %s\n", lvarsText, varname, varvalue)
			elseif (varname and type(varvalue) == "string") and varname:sub(1, 1) ~= "(" then
				lvarsText = oldformat('%slocal %s = "%s"\n', lvarsText, varname, varvalue)
			elseif (varname and type(varvalue) == "table") and varname:sub(1, 1) ~= "(" then
				lvarsText = lvarsText .. "local "
				divetable(varname, varvalue)
				lvarsText = lvarsText:gsub(",$", "")
			end
		until varname == nil
		s = s:gsub("<(.-)>", function(code)
			code = oldformat("%s\n%s", lvarsText, code)
			local chunk, err = load(code)
			if chunk then
				return chunk()
			end
			error(err, 4)
		end)
	end
	s = oldformat(s, table.unpack(args))
	return s
end

function string.noextracaps(s)
	s = assert(type(s) == "string" and s, ("The string is expected (got %s)"):format(type(s)))
	local function is_start_of_sentence(s, index)
		return index == 1 or (s:sub(index - 1, index - 1) == ".")
	end

	local function is_proper_noun_or_abbreviation(word)
		return word:match("^%u[%u%l]*$") or word:match("^[%u]+$")
	end

	local output = ""
	local index = 1
	while index <= #s do
		local char = s:sub(index, index)

		if char:match("%u") then
			local word_start = index
			while index <= #s and s:sub(index, index):match("%w") do
				index = index + 1
			end

			local word = s:sub(word_start, index - 1)
			if is_start_of_sentence(s, word_start) or
				is_proper_noun_or_abbreviation(word) or
				word:match("^[%u][%l]*[%u][%l]*$") then
				output = output .. word
			else
				output = output .. word:lower()
			end
		else
			output = output .. char
			index = index + 1
		end
	end
	return output
end
