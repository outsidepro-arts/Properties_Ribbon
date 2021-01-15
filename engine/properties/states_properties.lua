--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts
License: MIT License

----------

Let me say a few word before starts
LUA - is not object oriented programming language, but very flexible. Its flexibility allows to realize OOP easy via metatables. In this scripts the pseudo OOP has been used, therefore we have to understand some terms.
.1 When i'm speaking "Class" i mean the metatable variable with some fields.
2. When i'm speaking "Method" i mean a function attached to a field or submetatable field.
When i was starting write this scripts complex i imagined this as real OOP. But in consequence the scripts structure has been reunderstanded as current structure. It has been turned out more comfort as for writing new properties table, as for call this from main script engine.
After this preambula, let me begin.
]]--

-- global pseudoclass initialization
statesLayout = initLayout("Status properties")

function statesLayout.canProvide() return true end

-- Usual methods and fields
-- They will be coppied into easy switching methods.
-- Usually, the windows defines through action states. So let me to not write too many code.
usualStates = {[0] = "hidden", [1] = "shown"}

local function usualGet(self)
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), self.type[1], self.type[2])
message(string.format(self.msg, self.states[self.getValue()]))
return message
end

local function usualSet(self, action)
if action ~= nil then
return "This property is toggleable only."
end
local message = initOutputMessage()
local state = nor(self.getValue())
self.setValue(state)
message(string.format(self.msg, self.states[self.getValue()]))
return message
end


-- Master track visibility
statesLayout:registerProperty({
states = usualStates,
type = {
[1] = "Toggle this property to show or hide the master track in this project.",
[2]= "toggleable"
},
msg = "Master track %s",
getValue = function()
return reaper.GetToggleCommandState(40075)
end,
setValue = function(value)
reaper.Main_OnCommand(40075, value)
end,
get = usualGet,
set = usualSet
})

-- Mixer visibility
-- Has a problem  while hidding: Set method reports previous state. Seems, the action status changes slowly.
-- we need the getValue method from.
local mixerProperty = {
states = usualStates,
type = {
[1] = "Toggle this property to show or hide the mixer area. Please note: when the mixer area is hidden, the docker property is not available.",
[2]= "toggleable"
},
msg = "Mixer %s",
getValue = function()
return reaper.GetToggleCommandState(40078)
end,
setValue = function(value)
reaper.Main_OnCommand(40078, value)
end,
get = usualGet,
set = usualSet
}
statesLayout:registerProperty(mixerProperty)

-- Docker visibility
-- if mixer hidden, the docker couldn't be displayed.
if mixerProperty.getValue() == 1 then
statesLayout:registerProperty({
states = usualStates,
type = {
[1] = "Toggle this property to show or hide the docker area.",
[2]= "toggleable"
},
msg = "Docker %s",
getValue = function()
return reaper.GetToggleCommandState(40313)
end,
setValue = function(value)
reaper.Main_OnCommand(40313, value)
reaper.DockWindowRefresh()
end,
get = usualGet,
set = usualSet
})
end

-- Transport panel visibility
statesLayout:registerProperty({
states = usualStates,
type = {
[1] = "Toggle this property to show or hide the transport panel.",
[2]= "toggleable"
},
msg = "Transport %s",
getValue = function()
return reaper.GetToggleCommandState(40259)
end,
setValue = function(value)
reaper.Main_OnCommand(40259, value)
end,
get = usualGet,
set = usualSet
})

-- Video window visibility
statesLayout:registerProperty({
states = usualStates,
type = {
[1] = "Toggle this property to show or hide the video window.",
[2]= "toggleable"
},
msg = "Video window %s",
getValue = function()
return reaper.GetToggleCommandState(50125)
end,
setValue = function(value)
reaper.Main_OnCommand(50125, value)
end,
get = usualGet,
set = usualSet
})

-- Media explorer window visibility
statesLayout:registerProperty({
states = usualStates,
type = {
[1] = "Toggle this property to show or hide the media explorer window.",
[2]= "toggleable"
},
msg = "Media explorer %s",
getValue = function()
return reaper.GetToggleCommandState(50124)
end,
setValue = function(value)
reaper.Main_OnCommand(50124, value)
end,
get = usualGet,
set = usualSet
})

-- Big clock visibility
-- The same trouble like with mixer area.
statesLayout:registerProperty({
states = usualStates,
type = {
[1] = "Toggle this property to show or hide the big clock window.",
[2]= "toggleable"
},
msg = "Big clock %s",
getValue = function()
return reaper.GetToggleCommandState(40378)
end,
setValue = function(value)
reaper.Main_OnCommand(40378, value)
end,
get = usualGet,
set = usualSet
})

return statesLayout