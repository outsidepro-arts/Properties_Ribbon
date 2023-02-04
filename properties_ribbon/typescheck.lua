--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]] --


-- The simplified types checking
-- This file will inject its functions to global space, so we have not to store it as module

-- Basic Lua types
function isnumber(var)
	return type(var) == "number"
end

function isstring(var)
	return type(var) == "string"
end

function istable(var)
	return type(var) == "table"
end

function isfunction(var)
	return type(var) == "function"
end

function isuserdata(var)
	return type(var) == "userdata"
end

function isthread(var)
	return type(var) == "thread"
end

function isboolean(var)
	return type(var) == "boolean"
end

-- Some super-simplifies
function isarray(var)
	local lambda = ipairs(var)
	return (lambda(var, 0) ~= nil and true) or false
end

-- Properties Ribbon specific types
-- These types can be defined by metafield __type. Lua does not operates this, but we do.
function isOutputMessage(var)
	if istable(var) then
		local mt = getmetatable(var)
		return mt.__type and mt.__type == "output_message"
	end
end

function isLayout(var)
	if istable(var) then
		local mt = getmetatable(var)
		return mt.__type and mt.__type == "layout"
	end
end

function isSublayout(var)
	if istable(var) then
		local mt = getmetatable(var)
		return mt.__type and mt.__type == "sublayout"
	end
end
