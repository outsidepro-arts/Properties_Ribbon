--[[
REAPER Extstate metatable
Copyright (c) 2020-2021 outsidepro-arts
License: MIT License
Allows to interract with ReaScript Extstate functions such as reaper.GetExtState, reaper.SetExtState and reaper.DeleteExtState like with usual table.
The metatable has two specific fields:
_section: The group section in extstate. First parameter in any ExtState function. You have to assign this field before interract with metatable. This field never resets.
_forever: If you will try to assign any extstate key and value through this field, the it will stored physicaly in respective INI-file. Reading a value through this field will redirected to uplevel table. In other cases this table looks like usual table.
Usualy Extstate values stores  as string type. The metatable tries to convert it to appropriate type before return the value. The metatable supports the following types:
string
number
boolean
nil (when reading from, it means that no any value for this key read. When assigning the table key will be removed from extstate if any value exists there.)
]]--

local extstate = {
_section = "",
_forever ={}
}


function extstate.__index(self, key)
local state = reaper.GetExtState(self._section, key)
if tonumber(state) then
return tonumber(state)
elseif state == "true" or state == "false" then
return ({["true"]=true,["false"]=false})[state]
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

setmetatable(extstate, extstate)
setmetatable(extstate._forever, extstate._forever)

return extstate