--[[
REAPER Extstate metatable
Copyright (c) 2020-2024 outsidepro-arts
License: MIT License
Allows to interract with ReaScript Extstate functions such as reaper.GetExtState, reaper.SetExtState and reaper.DeleteExtState like with usual table.
The metatable has two specific fields:
_section: The group section in extstate. First parameter in any ExtState function. You have to assign this field before interract with metatable. This field never resets.
_forever: If you will try to assign any extstate key and value through this field, the it will stored physicaly in respective INI-file. Reading a value through this field will redirected to uplevel table. In other cases this table looks like usual table.
_layout: This is a copy of uplevel table, but it especialized for layouts use. This table calls the uplevel metatable methods and passes there specified unique string key, which differents the values from layout to layout. Please note: you have to layout or sublayout initialized to use this field.

Usualy Extstate values stores  as string type. The metatable tries to convert it to appropriate type before return the value. The metatable supports the following types:
string
number
boolean
nil (when reading from, it means that no any value for this key read. When assigning the table key will be removed from extstate if any value exists there.)
]] --

local extstate = {
	_section = "",
	_forever = {},
	_layout = {
		_forever = {}
	},
	_sublayout = {
		_forever = {}
	}
}


function extstate.__index(self, key)
	local state = reaper.GetExtState(self._section, key)
	if tonumber(state) then
		return tonumber(state)
	elseif state == "true" or state == "false" then
		return ({ ["true"] = true, ["false"] = false })[state]
	elseif state == "" then
		return nil
	else
		return state
	end
end

function extstate.__newindex(self, key, value)
	if value == nil then
		reaper.DeleteExtState(self._section, key, false)
	else
		reaper.SetExtState(self._section, key, tostring(value), false)
	end
end

extstate._forever = {}
extstate._forever.__index = extstate

function extstate._forever.__newindex(self, key, value)
	if value == nil then
		reaper.DeleteExtState(self._section, key, true)
	else
		reaper.SetExtState(self._section, key, tostring(value), true)
	end
end

function extstate._layout.__index(self, key)
	return extstate[string.format("%s.%s", currentLayout, key)]
end

function extstate._layout.__newindex(self, key, value)
	extstate[string.format("%s.%s", currentLayout, key)] = value
end

extstate._layout._forever.__index = extstate._layout

function extstate._layout._forever.__newindex(self, key, value)
	extstate._forever[string.format("%s.%s", currentLayout, key)] = value
end

function extstate._sublayout.__index(self, key)
	return extstate[string.format("%s.%s", layout.section, key)]
end

function extstate._sublayout.__newindex(self, key, value)
	extstate[string.format("%s.%s", layout.section, key)] = value
end

extstate._sublayout._forever.__index = extstate._sublayout

function extstate._sublayout._forever.__newindex(self, key, value)
	extstate._forever[string.format("%s.%s", layout.section, key)] = value
end

setmetatable(extstate, extstate)
setmetatable(extstate._forever, extstate._forever)
setmetatable(extstate._layout, extstate._layout)
setmetatable(extstate._layout._forever, extstate._layout._forever)
setmetatable(extstate._sublayout, extstate._sublayout)
setmetatable(extstate._sublayout._forever, extstate._sublayout._forever)

-- Initialize the config provider module
---@param section (string): the section where config provider will search al requested keys. Usualy it is first param in reaper.GetExtState/reaper.SetExtState
---@return table @ the namespace of this module already initialized and ready to work.
local function init(section)
	extstate._section = section
	return extstate
end

return init