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

-- Reading the sublayout
sublayout = extstate.get(currentLayout.."_sublayout")
if sublayout == "" or sublayout == nil then
sublayout = "areas"
end

-- global pseudoclass initialization
parentLayout = initLayout("%sstatus properties")

function parentLayout.canProvide() return true end

parentLayout:registerSublayout("options", "Options ")
parentLayout:registerSublayout("areas", "Areas and panels ")
parentLayout:registerSublayout("windows", "Windows ")

-- Usual methods and fields
-- They will be coppied into easy switching methods.
-- Usually, the windows defines through action states. So let me to not write too many code.

local usualOptStates = {[0]="off", [1]="on"}
local usualAreaStates = {[0] = "hidden", [1] = "shown"}
local usualWindowStates = {[0] = "Open", [1] = "Close"}

-- The properties functions template
-- _states (table): a table filled by specified values for getting needed state
-- _cmd (number): an action ID
-- _msg (string): a message formatted by %s which ill be replaced to needed state
-- _type (table): an array of type prompts
-- _get, _set (functions): optional parameters, will change the standart functions
local function getUsualProperty(_states, _cmd, _msg, _type, _get, _set)
local usual = {
states = _states,
msg = _msg,
getValue = function()
return reaper.GetToggleCommandState(_cmd)
end,
setValue = function(value)
reaper.Main_OnCommand(_cmd, value)
end,
get = _get or function(self)
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), _type[1], _type[2])
message(string.format(self.msg, self.states[self.getValue()]))
return message
end,
set = _set or function(self, action)
if action ~= nil then
return "This property is toggleable only."
end
local message = initOutputMessage()
local state = nor(self.getValue())
self.setValue(state)
message(string.format(self.msg, self.states[self.getValue()]))
return message
end
}
return usual
end

local function setWindow(self, action)
if action ~= nil then
return "This property is toggleable only."
end
local message = initOutputMessage()
self.states = {[0] = "closed", [1] = "opened"}
local state = nor(self.getValue())
self.setValue(state)
message(string.format("%s has been %s", self.msg:sub(4), self.states[self.getValue()]))
if self.getValue() == 0 then
return message
end
return ""
end


-- Master track visibility
parentLayout.areas:registerProperty(
getUsualProperty(
usualAreaStates,
40075,
"Master track %s",
{"Toggle this property to show or hide the master track in this project.", "toggleable"}
)
)

-- Mixer visibility
-- Has a problem  while hidding: Set method reports previous state. Seems, the action status changes slowly. Still needs to fix this
-- we need the getValue method from.
local mixerProperty = getUsualProperty(
usualAreaStates,
40078,
"Mixer %s",
{"Toggle this property to show or hide the mixer area. Please note: when the mixer area is hidden, the docker property is not available.", "toggleable"}
)
parentLayout.areas:registerProperty(mixerProperty)

-- Docker visibility
-- if mixer hidden, the docker couldn't be displayed.
if mixerProperty.getValue() == 1 then
local dockerProperty = getUsualProperty(
usualAreaStates,
40313,
"Docker %s",
{"Toggle this property to show or hide the docker area.", "toggleable"}
)
-- Injecting the specific methods call to our template
function dockerProperty.setValue(value)
reaper.Main_OnCommand(40313, value)
reaper.DockWindowRefresh()
end
parentLayout.areas:registerProperty(dockerProperty)
end

-- Transport panel visibility
parentLayout.areas:registerProperty(
getUsualProperty(
usualAreaStates,
40259,
"Transport %s",
{"Toggle this property to show or hide the transport panel.", "toggleable"}
)
)

-- Video window visibility
parentLayout.windows:registerProperty(
getUsualProperty(
usualWindowStates,
50125,
"%s the video window",
{"Toggle this property to open or close the video window.", "toggleable"},
nil,
setWindow
)
)

-- Media explorer window visibility
parentLayout.windows:registerProperty(
getUsualProperty(
usualWindowStates,
50124,
"%s the media explorer",
{"Toggle this property to show or hide the media explorer window.", "toggleable"},
nil,
setWindow
)
)

-- Big clock visibility
-- The same trouble like with mixer area.
parentLayout.areas:registerProperty(
getUsualProperty(
usualAreaStates,
40378,
"Big clock %s",
{"Toggle this property to show or hide the big clock window.", "toggleable"}
)
)

-- Auto-crossfade methods
parentLayout.options:registerProperty(
getUsualProperty(
usualOptStates,
40041,
"Automatic crossfade %s",
{"Toggle this property to switch the automatic crossfade option", "Toggleable"}
)
)

parentLayout.options:registerProperty(
getUsualProperty(
 usualOptStates,
 40912,
 "Automatic crossfade on split %s",
{"Toggle this property to switch the automatic crossfade option which will crossfade items when they splits.","Toggleable"}
)
)

-- Crossfade editor
parentLayout.windows:registerProperty(
getUsualProperty(
usualWindowStates,
41827,
"%s the crossfade editor",
{"Toggle this property to switch the crossfade editor window state.", "Toggleable"},
nil,
setWindow
)
)

-- Repeat option property
parentLayout.options:registerProperty(
getUsualProperty(
usualOptStates,
1068,
"Repeat %s",
{"Toggle this property to switch the repeat action.", "Toggleable"}
)
)

-- Always on top option property
parentLayout.options:registerProperty(
getUsualProperty(
usualOptStates,
40239,
"Allways on top %s",
{"Toggle this property to switch the REAPER window foreground state. When this option is on, the REAPER window will be allways on top.", "Toggleable"}
)
)

-- Full screen option property
parentLayout.options:registerProperty(
getUsualProperty(
usualOptStates,
40346,
"Full screen %s",
{"Toggle this property to switch the REAPER window screen fullness state. When this property is on, the window will be filled full desktop screen.", "Toggleable"}
)
)

-- Region/Marker window state
parentLayout.windows:registerProperty(
getUsualProperty(
usualWindowStates,
40326,
"%s the Region and marker manager",
{"Toggle this property to either open or close the region and marker region manager window.", "Toggleable"},
nil,
setWindow
)
)

-- Screen set window property
parentLayout.windows:registerProperty(
getUsualProperty(
usualWindowStates,
40422,
"%s the screen, track or item sets",
{"Toggle this property to either open or close the sets for screen, items or tracks.", "Toggleable"},
nil,
setWindow
)
)

-- Track manager window
parentLayout.windows:registerProperty(
getUsualProperty(
usualWindowStates,
40906,
"%s the track manager",
{"Toggle this property to either open or close the track manager window.", "Toggleable"},
nil,
setWindow
)
)

-- Undo window
parentLayout.windows:registerProperty(
getUsualProperty(
usualWindowStates,
40072,
"%s the undo history window",
{"Toggle this property to either open or close the undo history window.", "Toggleable"},
nil,
setWindow
)
)


return parentLayout[sublayout]