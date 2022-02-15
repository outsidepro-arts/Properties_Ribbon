--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
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
local parentLayout = initLayout("State management")

parentLayout:registerSublayout("options", "Options")
parentLayout:registerSublayout("areas", "Areas and panels")
parentLayout:registerSublayout("windows", "Windows")

-- Usual methods and fields
-- They will be coppied into easy switching methods.
-- Usually, the windows defines through action states. So let me to not write too many code.

local usualOptStates = {[0]="off", [1]="on"}
local usualAreaStates = {[0] = "hidden", [1] = "shown"}
local usualWindowStates = {[0] = "Open", [1] = "Close"}

-- The properties functions template
-- states (table): a table filled by specified values for getting needed state
-- cmd (number): an action ID
-- msg (string): a message formatted by %s which will be replaced to needed state
-- type (table): an array of type prompts
-- getFunction, setFunction (functions): optional parameters, will change the standart functions
local function getUsualProperty(states, cmd, msg, type, getFunction, setFunction)
local usual = {
["msg"] = msg,
getValue = function()
return reaper.GetToggleCommandState(cmd)
end,
setValue = function(value)
reaper.Main_OnCommand(cmd, value)
end,
get = getFunction or function(self)
local message = initOutputMessage()
message:initType(type[1], type[2])
if msg:find("[%%]") then
message(string.format(msg, states[self.getValue()]))
else
message{label=msg, value=states[self.getValue()]}
end
return message
end,
set = setFunction or function(self, action)
if action ~= nil then
return "This property is toggleable only."
end
local message = initOutputMessage()
local state = utils.nor(self.getValue())
self.setValue(state)
message(self:get())
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
states = {[0] = "closed", [1] = "opened"}
local state = utils.nor(self.getValue())
self.setValue(state)
local label = self:get():extract(false)
message(string.format("%s has been %s", label:match("^%w+%s(.+)"), states[self.getValue()]))
if self.getValue() == 0 then
return message
end
setUndoLabel(message)
return ""
end


-- Master track visibility
parentLayout.areas:registerProperty(
getUsualProperty(
usualAreaStates,
40075,
"Master track",
{"Toggle this property to show or hide the master track in this project.", "toggleable"}
)
)

-- Mixer visibility
-- Has a problem  while hidding: Set method reports previous state. Seems, the action status changes slowly. Still needs to fix this
-- we need the getValue method from.
local mixerProperty = getUsualProperty(
usualAreaStates,
40078,
"Mixer",
{"Toggle this property to show or hide the mixer area. Please note: when the mixer area is hidden, the docker property is not available.", "toggleable"}
)
parentLayout.areas:registerProperty(mixerProperty)

-- Docker visibility
-- if mixer hidden, the docker couldn't be displayed.
if mixerProperty.getValue() == 1 then
local dockerProperty = getUsualProperty(
usualAreaStates,
40313,
"Docker",
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
"Transport",
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
"Big clock",
{"Toggle this property to show or hide the big clock window.", "toggleable"}
)
)

-- Auto-crossfade methods
parentLayout.options:registerProperty(
getUsualProperty(
usualOptStates,
40041,
"Automatic crossfade",
{"Toggle this property to switch the automatic crossfade option", "Toggleable"}
)
)

parentLayout.options:registerProperty(
getUsualProperty(
 usualOptStates,
 40912,
 "Automatic crossfade on split",
{"Toggle this property to switch the automatic crossfade option which will crossfade items when they splits.","Toggleable"}
)
)

-- Virtual MIDI keyboard
parentLayout.windows:registerProperty(
getUsualProperty(
usualWindowStates,
40377,
"%s the virtual MIDI keyboard",
{"Toggle this property to open or close the virtual MIDI keyboard window.", "Toggleable"},
nil,
setWindow
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


-- Move envelope points with items
parentLayout.options:registerProperty(
getUsualProperty(
 usualOptStates,
 40070,
 "Move envelope points with media items and razor edits",
{"Toggle this property to switch the movement an envelope points with items on these position when they are coppied, cutted or moved.","Toggleable"}
)
)


-- Repeat option property
parentLayout.options:registerProperty(
getUsualProperty(
usualOptStates,
1068,
"Repeat",
{"Toggle this property to switch the repeat action.", "Toggleable"}
)
)

-- Always on top option property
parentLayout.options:registerProperty(
getUsualProperty(
usualOptStates,
40239,
"Allways on top",
{"Toggle this property to switch the REAPER window foreground state. When this option is on, the REAPER window will be allways on top.", "Toggleable"}
)
)

-- Full screen option property
parentLayout.options:registerProperty(
getUsualProperty(
usualOptStates,
40346,
"Full screen",
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

-- Threshold sensitivity adjusting window
-- From the recent time this dialog is focusable and accessible, so let me add here
parentLayout.windows:registerProperty(
getUsualProperty(
usualWindowStates,
41208,
"%s the Transient detection sensitivity and threshold adjusting window",
{"Toggle this property to either open or close the Transient detection sensitivity and threshold adjusting window.", "Toggleable"},
nil,
setWindow
)
)

parentLayout.defaultSublayout = "areas"

return parentLayout