--[[
Config provider module
Copyright (c) 2020-2021 outsidepro-arts
License: MIT License
]]--

-- Before use this module, please fill the config.section by your unique name which should set to ExtState

local config = {}

-- A few local functions
local function toboolean(value)
if type(value) == "string" then
return ({["false"] = false, ["true"] = true})[value]
else
return (value > 0)
end
end


function config.getboolean(key, defvalue)
local state = reaper.GetExtState(config.section, "cfg_"..key)
if state ~= "" then
return toboolean(state)
end
if defvalue ~= nil then
return defvalue
end
return nil
end

function config.getinteger(key, defvalue)
local state = reaper.GetExtState(config.section, "cfg_"..key)
if tonumber(state) then
return tonumber(state)
end
if defvalue then
return defvalue
end
return nil
end

function config.getstring(key, defvalue)
local state =  reaper.GetExtState(config.section, "cfg_"..key)
if state ~= "" then
return state
end
if defvalue then
return defvalue
end
return nil
end

function config.setboolean(key, value)
reaper.SetExtState(config.section, "cfg_"..key, ({[true] = "true", [false] = "false"})[value], true)
end

function config.setinteger(key, value)
if tonumber(value) then
reaper.SetExtState(config.section, "cfg_"..key, tonumber(value), true)
else
reaper.SetExtState(config.section, "cfg_"..key, 0, true)
end
end

function config.setstring(key, value)
reaper.SetExtState(config.section, "cfg_"..key, tostring(value), true)
end

return config