--[[
Config provider module
Copyright (c) 2020-2024 outsidepro-arts
License: MIT License
]] --

local config = {}

-- A few local functions
local string2booleanStates = { ["false"] = false, ["true"] = true }

local function toboolean(value)
	if type(value) == "string" then
		return string2booleanStates[value]
	else
		return (value > 0)
	end
end

function config.getboolean(key, defvalue)
	local state = reaper.GetExtState(config.section, "cfg_" .. key)
	if state ~= "" then
		return toboolean(state)
	end
	if defvalue ~= nil then
		return defvalue
	end
	return nil
end

function config.getinteger(key, defvalue)
	local state = reaper.GetExtState(config.section, "cfg_" .. key)
	if tonumber(state) then
		return tonumber(state)
	end
	if defvalue then
		return defvalue
	end
	return nil
end

function config.getstring(key, defvalue)
	local state = reaper.GetExtState(config.section, "cfg_" .. key)
	if state ~= "" then
		return state
	end
	if defvalue then
		return defvalue
	end
	return nil
end

function config.setboolean(key, value)
	reaper.SetExtState(config.section, "cfg_" .. key, ({ [true] = "true", [false] = "false" })[value], true)
end

function config.setinteger(key, value)
	if tonumber(value) then
		reaper.SetExtState(config.section, "cfg_" .. key, tonumber(value), true)
	else
		reaper.SetExtState(config.section, "cfg_" .. key, 0, true)
	end
end

function config.setstring(key, value)
	reaper.SetExtState(config.section, "cfg_" .. key, value and tostring(value) or "", true)
end

-- Initialize the config provider module
---@param section (string): the section where config provider will search al requested keys. Usualy it is first param in reaper.GetExtState/reaper.SetExtState
---@return table @ the namespace of this module already initialized and ready to work.
local function init(section)
	config.section = section
	return config
end

return init