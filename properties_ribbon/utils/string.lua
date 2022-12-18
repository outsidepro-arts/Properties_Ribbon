function string.split(str, delimiter, mode)
	require "properties_ribbon.utils.conversion"
	str = tostring(str)
	delimiter = tostring(delimiter)
	delimiter = delimiter or "%s"
	mode = nor(mode) or true
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
	local t  = {}
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
	local left, sp, right = orig:match(string.join("^(.+)(", sep, ")(.+)$"))
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

