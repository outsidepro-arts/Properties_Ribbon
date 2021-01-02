--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020 outsidepro-arts
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
sublayout = "visualLayout"
end

-- Preparing all needed configs which will be used not one time
multiSelectionSupport = config.getboolean("multiSelectionSupport", true)

-- For comfort coding, we are making the tracks array as global
tracks = nil
do
if multiSelectionSupport == true then
local countSelectedTracks = reaper.CountSelectedTracks(0)
if countSelectedTracks > 1 then
tracks = {}
for i = 0, countSelectedTracks-1 do
table.insert(tracks, reaper.GetSelectedTrack(0, i))
end
else
tracks = reaper.GetSelectedTrack(0, 0)
end
else
local lastTouched = reaper.GetLastTouchedTrack()
if lastTouched ~= reaper.GetMasterTrack(0) then
tracks = lastTouched
end
end
end

-- global pseudoclass initialization
parentLayout = setmetatable({
name = "Track%s properties", -- The main class name which will be formatted by subclass name
ofCount = 0 -- The full categories count
}, {
-- When new field has been added we just take over the ofCount adding
__newindex = function(self, key, value)
rawset(self, key, value)
if key ~= "canProvide" then
self.ofCount = self.ofCount+1
end
end
})

-- the function which gives green light to call any method from this class
function parentLayout.canProvide()
if tracks then
return true
else
return false
end
end


-- sublayouts
--visual properties
parentLayout.visualLayout = setmetatable({
section = "trackVisualProperties", -- The section in ExtState
subname = " visual", -- the name of class which will set to some messages
slIndex = 1, -- Index of category
nextSubLayout = "playbackLayout", -- the next sublayout the switch script will be set to

-- the properties list. It initializes first, then the methods will be added below.
properties = {}
}, {__index = parentLayout}
)

-- Playback properties
parentLayout.playbackLayout = setmetatable({
section = "trackPlaybackProperties", -- The section in ExtState
subname = " playback", -- the name of class which will set to some messages
slIndex = 2, -- Index of category
previousSubLayout = "visualLayout", -- the previous sublayout the switch script will be set to
nextSubLayout = "recordingLayout", -- the next sublayout the switch script will be set to

-- the properties list. It initializes first, then the methods will be added below.
properties = {}
}, {__index = parentLayout}
)

-- Recording properties
parentLayout.recordingLayout = setmetatable({
section = "trackRecordingProperties", -- The section in ExtState
slIndex = 3, -- The index of category
subname = " recording", -- the name of class which will set to some messages
previousSubLayout = "playbackLayout", -- the previous sublayout the switch script will be set to

-- the properties list. It initializes first, then the methods will be added below.
properties = {}
}, {__index = parentLayout}
)

-- The creating new property macros
local function registerProperty(property, sl)
table.insert(parentLayout[sl].properties, property)
end

--[[
Before the properties list fill get started, let describe this subclass methods:
Method get: gets no one parameter, returns a message string which will be reported in the navigating scripts.
Method set: gets parameter action. Expects false, true or nil.
action == true: the property must changed upward
action == false: the property must changed downward
action == nil: The property must be toggled or performed default action
Returns a message string which will be reported in the navigating scripts.

After you finish the methods table you have to return parent class.
No any recomendation more.
Although, no, just one thing:
Try to allow the user to perform actions on both one element and a selected group..
and try to complement any get message with short type label. I mean what the "ajust" method will perform.
]]--

-- Track name methods
local trackNameProperty = {}
registerProperty(trackNameProperty, "visualLayout")

function trackNameProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Perform this action to rename selected track.", "performable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, new name will applied to all selected tracks.", 1)
end
if type(tracks) == "table" then
message("Track names: ")
for k = 1, #tracks do
local state, name = reaper.GetTrackName(tracks[k])
message(string.format("track %u ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
if state == true then
message(string.format("named as %s", name))
else
message("unnamed")
end
if k < #tracks then
message(", ")
end
end
else
local state, name = reaper.GetTrackName(tracks)
if state == true then
message(string.format("Track %u name %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), name))
else
message(string.format("Track %u unnamed", string.format("track %u is ", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"))))
end
end
return message
end

function trackNameProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is performable only."
end
if type(tracks) == "table" then
local state, answer = reaper.GetUserInputs("Change tracks name", 1, 'Type new tracks name:', "")
if state == true then
for k = 1, #tracks do
reaper.GetSetMediaTrackInfo_String(tracks[k], "P_NAME", answer.." "..k, true)
end
message(string.format("The name %s has been set for %u tracks.", answer, #tracks))
end
else
local nameState, name = reaper.GetTrackName(tracks)
local aState, answer = reaper.GetUserInputs(string.format("Change name for track %u", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER")), 1, 'Type new track name:', name)
if aState == true then
reaper.GetSetMediaTrackInfo_String(tracks, "P_NAME", answer, true)
end
end
return message
end



local folderStateProperty = {}
 registerProperty( folderStateProperty, "visualLayout")
 folderStateProperty.states = {
[0]="track",
[1]="folder",
[2]="end of folder",
[3]="end of %u folders"
}
 folderStateProperty.compactStates = {
[0] = "opened",
[1] = "small",
[2] = "closed"
}

function folderStateProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to switch the folder state of selected tracks.", "Adjustable")
if multiSelectionSupport == true then
message:addType(" This property is adjustable for one track only.", 1)
end
if type(tracks) == "table" then
message("Tracks folder: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_FOLDERDEPTH")
message(string.format("track %u is ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
if state == 0 or state == 1 then
if state == 1 then
local compactState = reaper.GetMediaTrackInfo_Value(tracks[k], "I_FOLDERCOMPACT")
message(self.compactStates[compactState].." ")
end
message(self.states[state])
elseif state < 0 then
state = -(state-1)
if state < 3 then
message(string.format("n %s", self.states[state]))
else
message(string.format("n "..self.states[3], state-1))
end
end
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH")
message(string.format("Track %u is a", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER")))
if state == 0 or state == 1 then
if state == 1 then
local compactState = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERCOMPACT")
if compactState == 0 then
message("n")
end
message(" "..self.compactStates[compactState])
end
message(string.format(" %s", self.states[state]))
if state == 1 then
message:addType(" Toggle this property to set the collaps track state.", 1)
message:addType(", toggleable", 2)
end
elseif state < 0 then
state = -(state-1)
if state < 3 then
message(string.format("n %s", self.states[state]))
else
message(string.format("n "..self.states[3], state-1))
end
end
end
return message
end

function folderStateProperty:set(action)
local message = initOutputMessage()
if type(tracks) == "table"then
return "No group action for this property."
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH")
if action == true then
if state == 0 then
reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH", 1)
elseif state == 1 then
local isParentTrack = reaper.GetParentTrack(tracks)
if isParentTrack then
reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH", -1)
else
message("No more next folder depth. ")
end
elseif state < 0 then
reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH", state-1)
if reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH") == state then
message("No more next folder depth. ")
end
end
elseif action == false then
if state == 0 then
message("No more previous inner state. ")
elseif state == 1 then
reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH", 0)
elseif state == -1 then
reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH", 1)
elseif state < 0 then
reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH", state+1)
end
elseif action == nil then
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH")
if state == 1 then
local compactState = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERCOMPACT")
if compactState == 0 then
reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERCOMPACT", 1)
elseif compactState == 1 then
reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERCOMPACT", 2)
elseif compactState == 2 then
reaper.SetMediaTrackInfo_Value(tracks, "I_FOLDERCOMPACT", 0)
end
else
return "This track is not a folder."
end
end
end
state = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH")
message(string.format("Track %u is a", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER")))
if state == 0 or state == 1 then
if state == 1 then
local compactState = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERCOMPACT")
if compactState == 0 then
message("n")
end
message(" "..self.compactStates[compactState])
end
message(string.format(" %s", self.states[state]))
if state == 1 then
message(". Toggle this property now to control the folder compacted view")
end
elseif state < 0 then
state = -(state-1)
if state < 3 then
message(string.format("n %s", self.states[state]))
else
message(string.format("n "..self.states[3], state-1))
end
end
return message
end

local volumeProperty = {}
registerProperty(volumeProperty, "playbackLayout")
registerProperty(volumeProperty, "recordingLayout")
function volumeProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired volume value for selected track.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of track has been selected, the relative of previous value will be applied for each track of.", 1)
end
message:addType(" Perform this property to reset the volume to zero DB.", 1)
if type(tracks) == "table" then
message("tracks volume: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_VOL")
message(string.format("track %u in ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(string.format("%s db", numtodecibels(state)))
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "D_VOL")
message(string.format("Track %u volume %s db", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), numtodecibels(state)))
end
return message
end

function volumeProperty:set(action)
local message = initOutputMessage()
if action == nil then
message("reset, ")
end
local ajustStep = config.getinteger("dbStep", 0.1)
if type(tracks) == "table" then
message("tracks volume: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_VOL")
if action == true then
if state < 3.981071705535 then
state = decibelstonum(numtodecibels(state)+ajustStep)
else
state = 3.981071705535
end
elseif action == false then
if state > 0 then
state = decibelstonum(numtodecibels(state)-ajustStep)
else
state = 0
end
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks[k], "D_VOL", state)
state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_VOL")
message(string.format("track %u in ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(string.format("%s db", numtodecibels(state)))
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "D_VOL")
if action == true then
if state < decibelstonum(12.0) then
state = decibelstonum(numtodecibels(state, true)+ajustStep)
else
state = decibelstonum(12.0)
message("maximum volume. ")
end
elseif action == false then
if numtodecibels(state) ~= "-inf" then
state = decibelstonum(numtodecibels(state, true)-ajustStep)
else
state = 0
message("Minimum volume. ")
end
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks, "D_VOL", state)
 state = reaper.GetMediaTrackInfo_Value(tracks, "D_VOL")
message(string.format("Track %u volume %s db", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), numtodecibels(state)))
end
return message
end


local panProperty = {}
registerProperty(panProperty, "playbackLayout")
registerProperty(panProperty, "recordingLayout")
function panProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired pan value for selected track.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of track has been selected, the relative of previous value will be applied for each track of.", 1)
end
message:addType(" Perform this property to set the pan to center.", 1)
if type(tracks) == "table" then
message("tracks pan: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_PAN")
message(string.format("track %u in ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(string.format("%s", numtopan(state)))
if k < #tracks then
message(", ")
end
end
else
message(string.format("Track %u pan ", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER")))
local state = reaper.GetMediaTrackInfo_Value(tracks, "D_PAN")
message(string.format("%s", numtopan(state)))
end
return message
end

function panProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("percentStep", 1)
if action == true then
ajustingValue = percenttonum(ajustingValue) or 0.01
elseif action == false then
ajustingValue = -percenttonum(ajustingValue) or -0.01
else
message("reset, ")
ajustingValue = nil
end
if type(tracks) == "table" then
message("tracks pan: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_PAN")
if ajustingValue then
state = round((state+ajustingValue), 3)
if state >= 1 then
state = 1
elseif state <= -1 then
state = -1
end
else
state = 0
end
reaper.SetMediaTrackInfo_Value(tracks[k], "D_PAN", state)
state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_PAN")
message(string.format("Track %u in ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(string.format("%s", numtopan(state)))
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "D_PAN")
if ajustingValue then
state = round((state+ajustingValue), 3)
if state > 1 then
state = 1
message("Right boundary. ")
elseif state < -1 then
state = -1
message("Left boundary. ")
end
else
state = 0
end
reaper.SetMediaTrackInfo_Value(tracks, "D_PAN", state)
state = reaper.GetMediaTrackInfo_Value(tracks, "D_PAN")
message(string.format("Track %u pan %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), numtopan(state)))
end
return message
end

local widthProperty = {}
registerProperty(widthProperty, "playbackLayout")

function widthProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired width value for selected track.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of track has been selected, the relative of previous value will be applied for each track of.", 1)
end
message:addType(" Perform this property to reset the value to 100 percent.", 1)
if type(tracks) == "table" then
message("tracks width: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_WIDTH")
message(string.format("track %u in ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(string.format("%s", numtopercent(state)))
if k < #tracks then
message(", ")
end
end
else
message(string.format("Track %u width ", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER")))
local state = reaper.GetMediaTrackInfo_Value(tracks, "D_WIDTH")
message(string.format("%s%%", numtopercent(state)))
end
return message
end

function widthProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("percentStep", 1)
if action == true then
ajustingValue = percenttonum(ajustingValue)
elseif action == false then
ajustingValue = -percenttonum(ajustingValue)
else
message("reset, ")
ajustingValue = nil
end
if type(tracks) == "table" then
message("tracks width: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_WIDTH")
if ajustingValue then
state = round((state+ajustingValue), 3)
if state >= 1 then
state = 1
elseif state <= -1 then
state = -1
end
else
state = 0
end
reaper.SetMediaTrackInfo_Value(tracks[k], "D_WIDTH", state)
state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_WIDTH")
message(string.format("Track %u in ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(string.format("%s%%", numtopercent(state)))
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "D_WIDTH")
if ajustingValue then
state = round((state+ajustingValue), 3)
if state > 1 then
state = 1
message("Maximum width. ")
elseif state < -1 then
state = -1
message("Minimum width. ")
end
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks, "D_WIDTH", state)
 state = reaper.GetMediaTrackInfo_Value(tracks, "D_WIDTH")
message(string.format("Track %u width %s%%", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), numtopercent(state)))
end
return message
end

local muteProperty = {}
 registerProperty(muteProperty, "playbackLayout")
 muteProperty.states = {[0]="not muted", [1]="muted"}

function muteProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to mute or unmute selected track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the mute state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks mute: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_MUTE")
message(string.format("track %u ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(self.states[state])
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_MUTE")
message(string.format("track %u %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

function muteProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(tracks) == "table" then
local mutedTracks, notMutedTracks = 0, 0
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_MUTE")
if state == 1 then
mutedTracks = mutedTracks+1
else
notMutedTracks = notMutedTracks+1
end
end
local ajustingValue
if mutedTracks > notMutedTracks then
ajustingValue = 0
message("Unmuting all tracks.")
elseif mutedTracks < notMutedTracks then
ajustingValue = 1
message("Muting all tracks.")
else
ajustingValue = 0
message("Unmuting all tracks.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "B_MUTE", ajustingValue)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_MUTE")
if state == 1 then
state = 0
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks, "B_MUTE", state)
state = reaper.GetMediaTrackInfo_Value(tracks, "B_MUTE")
message(string.format("Track %u %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

local soloProperty = {}
 registerProperty(soloProperty, "playbackLayout")
 soloProperty.states = {
[0] = "not soloed",
[1] = "soloed",
[2] = "soloed in place",
[5] = "safe soloed",
[6] = "safe soloed in place"
}

function soloProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to solo or unsolo selected track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the solo state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks solo: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_SOLO")
message(string.format("track %u %s", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER"), self.states[state]))
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_SOLO")
message(string.format("track %u %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

function soloProperty:set(action)
local message = initOutputMessage()
local soloInConfig = reaper.get_config_var_string("soloip")
if soloInConfig == true	 then
soloInConfig = 2
else
soloInConfig = 1
end
if action ~= nil then
return "This property is toggleable only."
end

if type(tracks) == "table" then
local soloedTracks, notSoloedTracks = 0, 0
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_SOLO")
if state > 0 then
soloedTracks = soloedTracks+1
else
notSoloedTracks = notSoloedTracks+1
end
end
local ajustingValue
if soloedTracks > notSoloedTracks then
ajustingValue = 0
message("Unsoloing all tracks.")
elseif soloedTracks < notSoloedTracks then
ajustingValue = soloInConfig
message("Soloing all tracks.")
else
ajustingValue = 0
message("Unsoloing all tracks.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "I_SOLO", ajustingValue)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_SOLO")
if state > 0 then
state = 0
else
state = soloInConfig
end
reaper.SetMediaTrackInfo_Value(tracks, "I_SOLO", state)
message(string.format("track %u %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[reaper.GetMediaTrackInfo_Value(tracks, "I_SOLO")]))
end
return message
end

local recarmProperty = {}
 registerProperty(recarmProperty, "recordingLayout")
 recarmProperty.states = {[0]="not armed", [1]="armed"}

function recarmProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to arm or disarm selected track for record.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the record state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks arm: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECARM")
message(string.format("track %u ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(self.states[state])
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECARM")
message(string.format("track %u %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

function recarmProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(tracks) == "table" then
local armedTracks, notArmedTracks = 0, 0
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECARM")
if state == 1 then
armedTracks = armedTracks+1
else
notArmedTracks = notArmedTracks+1
end
end
local ajustingValue
if armedTracks > notArmedTracks then
ajustingValue = 0
message("Unarming all tracks.")
elseif armedTracks < notArmedTracks then
ajustingValue = 1
message("Arming all tracks.")
else
ajustingValue = 0
message("Unarming all tracks.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "I_RECARM", ajustingValue)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECARM")
if state == 1 then
state = 0
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks, "I_RECARM", state)
state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECARM")
message(string.format("Track %u %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

local recmonitoringProperty = {}
 registerProperty(recmonitoringProperty, "recordingLayout")
 recmonitoringProperty.states = {
[0] = "off",
[1] = "normal",
[2] = "not when playing"
}

function recmonitoringProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose the desired record monitoring state.", "Adjustable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of track has been selected, the value will enumerate only if all tracks have the same value. Otherwise, the record monitoring state will be set to "%s" first, then will enumerate this.', self.states[1]), 1)
end
if type(tracks) == "table" then
message("tracks record monitoring: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECMON")
message(string.format("track %u %s", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER"), self.states[state]))
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMON")
message(string.format("track %u record monitoring %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

function recmonitoringProperty:set(action)
local message = initOutputMessage()
local ajustingValue
if action == true then
ajustingValue = 1
elseif action == false then
ajustingValue = -1
else
return "This property adjustable only."
end
if type(tracks) == "table" then
local st = {0,0,0}
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECMON")
st[state+1] = st[state+1]+1
end
local state
if math.max(st[1], st[2], st[3]) == #tracks then
state = reaper.GetMediaTrackInfo_Value(tracks[1], "I_RECMON")
if self.states[state+ajustingValue] then
state = state+ajustingValue
end
else
state = 1
end
message(string.format("Set all tracks monitoring to %s.", self.states[state]))
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "I_RECMON", state)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMON")
if (state+ajustingValue) > #self.states then
message("No more next property values. ")
elseif (state+ajustingValue) < 0 then
message("No more previous property values. ")
else
state = state+ajustingValue
end
reaper.SetMediaTrackInfo_Value(tracks, "I_RECMON", state)
message(string.format("track %u record monitoring %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[reaper.GetMediaTrackInfo_Value(tracks, "I_RECMON")]))
end
return message
end

-- Record inputs
local recInputsProperty = {}
registerProperty(recInputsProperty, "recordingLayout")

function recInputsProperty.getMIDIInputName(id)
local result, name = reaper.GetMIDIInputName(id, "")
if id == 63 then
result = true
name = "All MIDI-devices"
end
return result, name
end

function recInputsProperty.compose(val)
local message = initOutputMessage()
if val < 0 then
message("no input")
elseif val >= 4096 then
message("MIDI, ")
local channel = getBitValue(val, 1, 5)
if channel == 0 then
message("all channels, ")
else
message(string.format("channel %u, ", channel))
end
if getBitValue(val, 6, 12) == 62 then
message("from Virtual MIDI Keyboard")
elseif getBitValue(val, 6, 12) == 63 then
message("from all devices")
else
local result, name = recInputsProperty.getMIDIInputName(getBitValue(val, 6, 12))
if result == true then
message(string.format("from %s", name))
else
message(string.format("from unknown device with ID %u", getBitValue(val, 6, 12)))
end
end
else
message("audio, ")
local input = getBitValue(val, 1, 11)
if input >= 0 and input <= 1023 then
message("mono, ")
if input < 512 then
message(string.format("from %s", reaper.GetInputChannelName(input)))
elseif input >= 512 then
message(string.format("from REAROUTE/Loopback channel %s", reaper.GetInputChannelName(input)))
end
elseif input >= 1024 and input < 2048 then
local inputs = {}
for i = 0, reaper.GetNumAudioInputs() do
inputs[i+1024] = string.format("%s/%s", reaper.GetInputChannelName(i), reaper.GetInputChannelName(i+1))
end
message(string.format("stereo, %s", inputs[input]))
end
end
return tostring(message)
end

function recInputsProperty.calc(state, action)
if action == true then
if (state+1) >= 0 and (state+1) < 1024 then
if reaper.GetInputChannelName(getBitValue(state+1, 1, 11)) then
return state+1
else
return 1024
end
elseif (state+1) >= 1024 and (state+1) < 2048 then
local inputs = {}
for i = 1, reaper.GetNumAudioInputs()-1 do
inputs[i] = string.format("%s/%s", reaper.GetInputChannelName(i-1), reaper.GetInputChannelName(i))
end
if (state+1) <= (#inputs+1023) then
return state+1
else
for i = 4096, 8192 do
local channel = getBitValue(i, 1, 5)
local result, _ = recInputsProperty.getMIDIInputName(getBitValue(i, 6, 12))
if result == true and channel <= 16 then
return i
end
if i == 8192 then
return i
end
end
end
elseif (state+1) >= 4096 and (state+1) < 8192 then
for i = (state+1), 8192 do
local channel = getBitValue(i, 1, 5)
local result, _ = recInputsProperty.getMIDIInputName(getBitValue(i, 6, 12))
if result == true and channel <= 16 then
return i
end
if i == 8192 then
return i
end
end
else
return 8192
end
elseif action == false then
if (state-1)>= 4096 and (state-1) < 8192 then
for i = (state-1), 4096, -1 do
local channel = getBitValue(i, 1, 5)
local result, _ = recInputsProperty.getMIDIInputName(getBitValue(i, 6, 12))
if result == true and channel <= 16 then
return i
end
if i == 4096 then
local inputs = {}
for i = 1, reaper.GetNumAudioInputs()-1 do
inputs[i] = string.format("%s/%s", reaper.GetInputChannelName(i-1), reaper.GetInputChannelName(i))
end
return #inputs+1023
end
end
elseif (state-1) < 2048 and (state-1) >=1024 then
local inputs = {}
for i = 1, reaper.GetNumAudioInputs()-1 do
inputs[i] = string.format("%s/%s", reaper.GetInputChannelName(i-1), reaper.GetInputChannelName(i))
end
if (state-1) > (#inputs+1023) then
return #inputs+1023
else
return state-1
end
elseif (state-1) < 1024 and (state-1) >= 0 then
if reaper.GetNumAudioInputs() < (state-1) then
return reaper.GetNumAudioInputs()-1
else
return state-1
end
elseif (state-1) < 0 then
return -1
elseif (state-1) < -1 then
return -2
end
else
if state == -1 then
return 0
elseif state >= 0 and state < 512 then
return 1024
elseif state >= 1024 and state < 4096 then
for i = 4096, 8192 do
local channel = getBitValue(i, 1, 5)
local result, _ = recInputsProperty.getMIDIInputName(getBitValue(i, 6, 12))
if result == true and channel <= 16 then
return i
end
if i == 8192 then
return -1
end
end
elseif state > 4096 then
local result, device = recInputsProperty.getMIDIInputName(getBitValue(state, 6, 12))
if result == true then
for i = state, 8192 do
local curResult, curDevice = recInputsProperty.getMIDIInputName(getBitValue(i, 6, 12))
if curResult == true and curDevice ~= device then
return i
end
if i == 8192 then
return -1
end
end
else
return -1
end
end
end
end

function recInputsProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose the desired record input of selected track.", "Adjustable, toggleable")
if multiSelectionSupport == true then
message:addType((' If the group of track has been selected, the value will enumerate up if all tracks have the same value. If one of tracks has different value, all track will set to "%s" first, then will enumerate up this.'):format(self.compose(0)), 1)
end
message:addType(" Toggle this property to quick switch between input categories (mono, stereo or midi).", 1)
if multiSelectionSupport == true then
message:addType(" If the group of track has been selected, the quick switching will aplied for all tracks by first selected track.", 1)
end
if type(tracks) == "table" then
message("Tracks record input: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECINPUT")
message(string.format("track %u: %s", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER"), self.compose(state)))
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECINPUT")
message(string.format("track %u record input %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.compose(state)))
end
return message
end

function recInputsProperty:set(action)
local message = initOutputMessage()
local ajustingValue
if action == true then
ajustingValue = 1
elseif action == false then
ajustingValue = -1
end
if type(tracks) == "table" then
local lastState = reaper.GetMediaTrackInfo_Value(tracks[1], "I_RECINPUT")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECINPUT")
if lastState ~= state then
ajustingValue = 0
break
end
lastState = state
end
local state
if ajustingValue ~= 0 then
state = reaper.GetMediaTrackInfo_Value(tracks[1], "I_RECINPUT")
ajustingValue = self.calc(state, action)
if ajustingValue < 8192 and ajustingValue > -2 then
state = ajustingValue
end
else
state = 0
end
message(string.format("Set all tracks record input to %s.", self.compose(state)))
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "I_RECINPUT", state)
end
else
local state = self.calc(reaper.GetMediaTrackInfo_Value(tracks, "I_RECINPUT"), action)
if action == true then
if state < 8192 then
reaper.SetMediaTrackInfo_Value(tracks, "I_RECINPUT", state)
else
message("No more next property values. ")
end
elseif action == false then
if state >= -1 then
reaper.SetMediaTrackInfo_Value(tracks, "I_RECINPUT", state)
else
message("No more previous property values. ")
end
else
reaper.SetMediaTrackInfo_Value(tracks, "I_RECINPUT", state)
end
state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECINPUT")
message(string.format("track %u record input %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.compose(state)))
end
return message
end

local recmodeProperty = {}
 registerProperty(recmodeProperty, "recordingLayout")
 recmodeProperty.states = setmetatable({
[0] = "input",
[1] = "output (stereo)",
[2] = "none",
[3] = "output (stereo, latency compensated)",
[4] = "midi output",
[5] = "output (mono)",
[6] = "output (mono, latency compensated)",
[7] = "midi overdub",
[8] = "midi replace",
[9] = "MIDI touch replace",
[10] = "output (multichannel",
[11] = "output (multichannel, latency compensated)",
[12] = "input (force mono)",
[13] = "input (force stereo)",
[14] = "input (force multichannel)",
[15] = "input (force MIDI)",
[16] = "MIDI latch replace"
}, {
__index = function(self, key) return "Unknown record mode "..key end
})

function recmodeProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired mode for recording.", "Adjustable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of track has been selected, The value will enumerate only if all tracks have the same value. Otherwise, the record mode state will be set to "%s", then will enumerate this.', self.states[1]), 1)
end
if type(tracks) == "table" then
message("tracks record mode: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECMODE")
message(string.format("track %u %s", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER"), self.states[state]))
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMODE")
-- reaper.ShowMessageBox(state, "debug", 0)
message(string.format("track %u record mode %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

function recmodeProperty:set(action)
local message = initOutputMessage()
local ajustingValue
if action == true then
ajustingValue = 1
elseif action == false then
ajustingValue = -1
else
return "This property adjustable only."
end
if type(tracks) == "table" then
local st = {0,0,0,0,0,0,0,0,0}
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECMODE")
if st[state+1] then
st[state+1] = st[state+1]+1
end
end
local state
if math.max(st[1], st[2], st[3], st[4], st[5], st[6], st[7], st[8], st[9]) == #tracks then
state = reaper.GetMediaTrackInfo_Value(tracks[1], "I_RECMODE")
if self.states[state+ajustingValue] then
state = state+ajustingValue
end
else
state = 0
end
message(string.format("Set all tracks record mode to %s.", self.states[state]))
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "I_RECMODE", state)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMODE")
if (state+ajustingValue) > #self.states then
message("No more next property values. ")
elseif (state+ajustingValue) < 0 then
message("No more previous property values. ")
else
state = state+ajustingValue
end
reaper.SetMediaTrackInfo_Value(tracks, "I_RECMODE", state)
message(string.format("track %u record mode is %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[reaper.GetMediaTrackInfo_Value(tracks, "I_RECMODE")]))
end
return message
end

-- Automation mode methods
local automationModeProperty = {}
 registerProperty(automationModeProperty, "recordingLayout")
 automationModeProperty.states = setmetatable({
[0] = "trim read",
[1] = "read",
[2] = "touch",
[3] = "write",
[4] = "latch"
}, {
__index = function(self, key) return "Unknown automation mode "..key end
})

function automationModeProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired automation mode for selected track.", "Adjustable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of track has been selected, The value will enumerate only if all tracks have the same value. Otherwise, the automation mode state will be set to "%s", then will enumerate this.', self.states[1]), 1)
end
if type(tracks) == "table" then
message("tracks automation mode: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_AUTOMODE")
message(string.format("track %u %s", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER"), self.states[state]))
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_AUTOMODE")
message(string.format("track %u automation mode %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

function automationModeProperty:set(action)
local message = initOutputMessage()
local ajustingValue
if action == true then
ajustingValue = 1
elseif action == false then
ajustingValue = -1
else
return "This property adjustable only."
end
if type(tracks) == "table" then
local st = {0,0,0,0,0}
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_AUTOMODE")
if st[state+1] then
st[state+1] = st[state+1]+1
end
end
local state
if math.max(st[1], st[2], st[3], st[4], st[5]) == #tracks then
state = reaper.GetMediaTrackInfo_Value(tracks[1], "I_AUTOMODE")
if (state+ajustingValue) <= #self.states and (state+ajustingValue) >= 0then
state = state+ajustingValue
end
else
state = 1
end
message(string.format("Set all tracks automation mode to %s.", self.states[state]))
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "I_AUTOMODE", state)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_AUTOMODE")
if (state+ajustingValue) > #self.states then
message("No more next property values. ")
elseif (state+ajustingValue) < 0 then
message("No more previous property values. ")
else
state = state+ajustingValue
end
reaper.SetMediaTrackInfo_Value(tracks, "I_AUTOMODE", state)
message(string.format("track %u automation mode %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[reaper.GetMediaTrackInfo_Value(tracks, "I_AUTOMODE")]))
end
return message
end


local phaseProperty = {}
 registerProperty(phaseProperty, "playbackLayout")
 phaseProperty.states = {[0]="normal", [1]="inverted"}

function phaseProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to set the phase polarity of selected track.", "toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the phase polarity state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks phase: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_PHASE")
message(string.format("track %u ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(self.states[state])
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_PHASE")
message(string.format("track %u phase %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

function phaseProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(tracks) == "table" then
local phasedTracks, notPhasedTracks = 0, 0
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_PHASE")
if state == 1 then
phasedTracks = phasedTracks+1
else
notPhasedTracks = notPhasedTracks+1
end
end
local ajustingValue
if phasedTracks > notPhasedTracks then
ajustingValue = 0
message("Set all track phase to normal.")
elseif phasedTracks < notPhasedTracks then
ajustingValue = 1
message("Inverting all phase tracks.")
else
ajustingValue = 0
message("Set all track phase to normal.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "B_PHASE", ajustingValue)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_PHASE")
if state == 1 then
state = 0
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks, "B_PHASE", state)
message(string.format("track %u phase %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[reaper.GetMediaTrackInfo_Value(tracks, "B_PHASE")]))
end
return message
end

-- Send to parent or master track methods
local mainSendProperty = {}
 registerProperty(mainSendProperty, "playbackLayout")
mainSendProperty.states = {[0]="not sends", [1]="sends"}

function mainSendProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to switch the send state of selected track to parent or master track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the send state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks send to parent or master track: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_MAINSEND")
message(string.format("track %u ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(self.states[state])
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_MAINSEND")
message(string.format("track %u %s to ", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
if reaper.GetParentTrack(tracks) then
message("parent ")
else
message("master ")
end
message("track")
end
return message
end

function mainSendProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(tracks) == "table" then
local sendTracks, notSendTracks = 0, 0
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_MAINSEND")
if state == 1 then
sendTracks = sendTracks+1
else
notSendTracks = notSendTracks+1
end
end
local ajustingValue
if sendTracks > notSendTracks then
ajustingValue = 0
message("Switching off all tracks send to parent or master track.")
elseif sendTracks < notSendTracks then
ajustingValue = 1
message("Switching on all tracks send to parent or master track.")
else
ajustingValue = 0
message("Switching off all tracks send to parent or master track.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "B_MAINSEND", ajustingValue)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_MAINSEND")
if state == 1 then
state = 0
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks, "B_MAINSEND", state)
state = reaper.GetMediaTrackInfo_Value(tracks, "B_MAINSEND")
message(string.format("track %u %s to ", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
if reaper.GetParentTrack(tracks) then
message("parent ")
else
message("master ")
end
message("track")
end
return message
end


-- Free mode methods
local freemodeProperty = {}
 registerProperty(freemodeProperty, "playbackLayout")
freemodeProperty.states = {[0]="disabled", [1]="enabled"}

function freemodeProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to set the free mode of selected track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the free mode state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks free position mode: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_FREEMODE")
message(string.format("track %u ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(self.states[state])
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_FREEMODE")
message(string.format("Track %u free position %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

function freemodeProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(tracks) == "table" then
local freedTracks, notFreedTracks = 0, 0
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_FREEMODE")
if state == 1 then
freedTracks = freedTracks+1
else
notFreedTracks = notFreedTracks+1
end
end
local ajustingValue
if freedTracks > notFreedTracks then
ajustingValue = 0
elseif freedTracks < notFreedTracks then
ajustingValue = 1
else
ajustingValue = 0
end
message(string.format("Set all track free position mode to %s.", self.states[ajustingValue]))
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "B_FREEMODE", ajustingValue)
end
reaper.UpdateTimeline()
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_FREEMODE")
if state == 1 then
state = 0
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks, "B_FREEMODE", state)
reaper.UpdateTimeline()
message(string.format("track %u free position %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[reaper.GetMediaTrackInfo_Value(tracks, "B_FREEMODE")]))
end
return message
end

-- Timebase methods
local timebaseProperty = {}
 registerProperty(timebaseProperty, "playbackLayout")
timebaseProperty.states = setmetatable({
[0] = "project default",
[1] = "time",
[2] = "beats (position, length, rate)",
[3] = "beats (position only)"
}, {
__index = function(self, key) return "Unknown timebase mode "..key end
})

function timebaseProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose the desired time base mode for selected track.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of tracks has been selected, the value will enumerate only if all tracks have the same value. Otherwise, the timebase state will be set to "%s", then will enumerate this.', self.states[0]), 1)
end
if type(tracks) == "table" then
message("Track timebase: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "C_BEATATTACHMODE")
message(string.format("track %u %s", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER"), self.states[state+1]))
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "C_BEATATTACHMODE")
message(string.format("Track %u timebase %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state+1]))
end
return message
end

function timebaseProperty:set(action)
local message = initOutputMessage()
local ajustingValue
if action == true then
ajustingValue = 1
elseif action == false then
ajustingValue = -1
else
ajustingValue = -1
end
if type(tracks) == "table" then
if action then
local st = {0, 0, 0, 0}
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "C_BEATATTACHMODE")
st[state+2] = st[state+2]+1
end
local state
if math.max(st[1], st[2], st[3], st[4]) == #tracks then
state = reaper.GetMediaTrackInfo_Value(tracks[1], "C_BEATATTACHMODE")
if self.states[(state+ajustingValue)+1] then
state = state+ajustingValue
end
else
state = -1
end
message(string.format("Set all tracks timebase to %s.", self.states[state+1]))
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "C_BEATATTACHMODE", state)
end
else
message(string.format("Set all tracks timebase to %s.", self.states[0]))
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "C_BEATATTACHMODE", -1)
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "C_BEATATTACHMODE")
if action == true or action == false then
if state+ajustingValue > #self.states-1 then
message("No more next property values. ")
elseif state+ajustingValue < -1 then
message("No more previous property values. ")
else
state = state+ajustingValue
end
else
state = -1
end
reaper.SetMediaTrackInfo_Value(tracks, "C_BEATATTACHMODE", state)
message(string.format("Track %u timebase is %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[reaper.GetMediaTrackInfo_Value(tracks, "C_BEATATTACHMODE")+1]))
end
return message
end

-- Monitor items while recording methods
local recmonitorItemsProperty = {}
registerProperty( recmonitorItemsProperty, "recordingLayout")
recmonitorItemsProperty.states = {[0]="not monitoring", [1]="monitoring"}

function recmonitorItemsProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property if you want to monitor items while recording or not on selected track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the monitor items state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks monitoring items: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECMONITEMS")
message(string.format("track %u ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(self.states[state])
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMONITEMS")
message(string.format("track %u items while recording is %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

function recmonitorItemsProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(tracks) == "table" then
local monitoredTracks, notMonitoredTracks = 0, 0
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_RECMONITEMS")
if state == 1 then
monitoredTracks = monitoredTracks+1
else
notMonitoredTracks = notMonitoredTracks+1
end
end
local ajustingValue
if monitoredTracks > notMonitoredTracks then
ajustingValue = 0
message("Switching off the monitoring items for all tracks.")
elseif monitoredTracks < notMonitoredTracks then
ajustingValue = 1
message("Switching on the monitoring items for all tracks.")
else
ajustingValue = 0
message("Switching off the monitoring items for all tracks.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "I_RECMONITEMS", ajustingValue)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMONITEMS")
if state == 1 then
state = 0
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks, "I_RECMONITEMS", state)
state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMONITEMS")
message(string.format("Track %u items while recording now is %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

-- Track performance settings: buffering media
local performanceBufferingProperty = {}
 registerProperty(performanceBufferingProperty, "playbackLayout")
performanceBufferingProperty.states = {[0]="buffering", [1]="not buffering"}

function performanceBufferingProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to switch the track performance buffering media of selected track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the buffering media state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks media buffering: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS")&1
message(string.format("track %u ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(self.states[state])
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_PERFFLAGS")&1
message(string.format("track %u media is %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

function performanceBufferingProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(tracks) == "table" then
local bufferedTracks, notBufferedTracks = 0, 0
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS")&1
if state == 1 then
bufferedTracks = bufferedTracks+1
else
notBufferedTracks = notBufferedTracks+1
end
end
local ajustingValue
if bufferedTracks > notBufferedTracks then
ajustingValue = 0
message("Switching off the media buffering for all tracks.")
elseif bufferedTracks < notBufferedTracks then
ajustingValue = 1
message("Switching on the media buffering for all tracks.")
else
ajustingValue = 0
message("Switching off the media buffering for all tracks.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS", ajustingValue&1)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_PERFFLAGS")&1
if state == 1 then
state = 0
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks, "I_PERFFLAGS", state&1)
state = reaper.GetMediaTrackInfo_Value(tracks, "I_PERFFLAGS")&1
message(string.format("Track %u media is %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end


-- Track performance settings: Anticipative FX
local performanceAnticipativeFXProperty = {}
 registerProperty(performanceAnticipativeFXProperty, "playbackLayout")
performanceAnticipativeFXProperty.states = {[0]="anticipative", [2]="non-anticipative"}

function performanceAnticipativeFXProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to switch the track performance FX anticipativeness of selected track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the FX anticipativeness state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks FX anticipativeness: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS")&2
message(string.format("track %u ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(self.states[state])
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_PERFFLAGS")&2
message(string.format("track %u FX is %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

function performanceAnticipativeFXProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(tracks) == "table" then
local anticipatedTracks, notanticipatedTracks = 0, 0
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS")&2
if state == 2 then
anticipatedTracks = anticipatedTracks+1
else
notanticipatedTracks = notanticipatedTracks+1
end
end
local ajustingValue
if anticipatedTracks > notanticipatedTracks then
ajustingValue = 0
message("Switching off the anticipativeness FX for all tracks.")
elseif anticipatedTracks < notanticipatedTracks then
ajustingValue = 2
message("Switching on the anticipativeness FX for all tracks.")
else
ajustingValue = 0
message("Switching off the anticipativeness FX for all tracks.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS", ajustingValue&2)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_PERFFLAGS")&2
if state == 2 then
state = 0
else
state = 2
end
reaper.SetMediaTrackInfo_Value(tracks, "I_PERFFLAGS", state&2)
state = reaper.GetMediaTrackInfo_Value(tracks, "I_PERFFLAGS")&2
message(string.format("Track %u FX is %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

-- Track color methods
local colorProperty = {}
registerProperty(colorProperty, "visualLayout")

function colorProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel"), "Read this property to get the information about track color.", "Read-only")
if type(tracks) == "table" then
message("Tracks color: ")
for k = 1, #tracks do
local state = reaper.GetTrackColor(tracks[k])
message(string.format("track %u ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(colors:getName(reaper.ColorFromNative(state)))
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetTrackColor(tracks)
message(string.format("Track %u color %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), colors:getName(reaper.ColorFromNative(state))))
end
return message
end

function colorProperty:set(action)
return "This property is read only."
end

-- Visibility in Mixer panel
local mixerVisibilityProperty = {}
registerProperty( mixerVisibilityProperty, "visualLayout")
mixerVisibilityProperty.states = {[0]="hidden", [1]="visible"}

function mixerVisibilityProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to switch the visibility of selected track in mixer panel.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the visibility state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks visibility in Mixer panel: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_SHOWINMIXER")
message(string.format("track %u ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(self.states[state])
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINMIXER")
message(string.format("track %u is %s on mixer panel", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

function mixerVisibilityProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(tracks) == "table" then
local visibleTracks, notvisibleTracks = 0, 0
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS")&2
if state == 2 then
visibleTracks = visibleTracks+1
else
notvisibleTracks = notvisibleTracks+1
end
end
local ajustingValue
if visibleTracks > notvisibleTracks then
ajustingValue = 0
message("Hidding all tracks on mixer panel.")
elseif visibleTracks < notvisibleTracks then
ajustingValue = 1
message("Showing all tracks on mixer panel.")
else
ajustingValue = 0
message("Hidding all tracks on mixer panel.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "B_SHOWINMIXER", ajustingValue)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINMIXER")
if state == 1 then
state = 0
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks, "B_SHOWINMIXER", state)
state = reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINMIXER")
message(string.format("Track %u is %s on mixer panel", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

-- Visibility in TCP
local tcpVisibilityProperty = {}
registerProperty( tcpVisibilityProperty, "visualLayout")
tcpVisibilityProperty.states = mixerVisibilityProperty.states

function tcpVisibilityProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to switch the visibility of selected track control panel in arange view.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the visibility state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks control panels visibility: ")
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "B_SHOWINTCP")
message(string.format("track %u ", reaper.GetMediaTrackInfo_Value(tracks[k], "IP_TRACKNUMBER")))
message(self.states[state])
if k < #tracks then
message(", ")
end
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINTCP")
message(string.format("track %u control panel is %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

function tcpVisibilityProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(tracks) == "table" then
local visibleTracks, notvisibleTracks = 0, 0
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS")&2
if state == 2 then
visibleTracks = visibleTracks+1
else
notvisibleTracks = notvisibleTracks+1
end
end
local ajustingValue
if visibleTracks > notvisibleTracks then
ajustingValue = 0
message("Hidding all tracks control panels.")
elseif visibleTracks < notvisibleTracks then
ajustingValue = 1
message("Showing all tracks control panels.")
else
ajustingValue = 0
message("Hidding all tracks control panels.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "B_SHOWINTCP", ajustingValue)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINTCP")
if state == 1 then
state = 0
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks, "B_SHOWINTCP", state)
state = reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINTCP")
message(string.format("Track %u control panel is %s", reaper.GetMediaTrackInfo_Value(tracks, "IP_TRACKNUMBER"), self.states[state]))
end
return message
end

return parentLayout[sublayout]

--[[
Todo:
Report the color
Record inputs (partially made)
]]--