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
local sublayout = extstate[currentLayout.."_sublayout"] or "playbackLayout"

-- Preparing all needed configs which will be used not one time
local multiSelectionSupport = config.getboolean("multiSelectionSupport", true)

-- For comfort coding, we are making the tracks array as global
local tracks = nil
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

-- Reading the color from color composer specified section
local function getTrackComposedColor()
return extstate.colcom_track_curValue
end


-- We have to define the track reporting by configuration
local function getTrackID(track)
local message = initOutputMessage()
local states = {
[0]="track",
[1]="folder",
[2]="end of folder",
[3]="end of %u folders"
}
local compactStates = {
[0] = "opened",
[1] = "small",
[2] = "closed"
}
if reaper.GetParentTrack(track) then
message("Child ")
end
local state = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
if state == 0 or state == 1 then
if state == 1 then
message:clearMessage()
local compactState = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
message(compactStates[compactState])
end
message(string.format(" %s", states[state]))
elseif state < 0 then
message:clearMessage()
state = -(state-1)
if state < 3 then
message(string.format(" %s", states[state]))
else
message(string.format(states[3], state-1))
end
end
local cfg = config.getboolean("reportName", false)
if cfg == true then
local retval, name = reaper.GetTrackName(track)
if retval then
if  name:find("Track") and name:match("%d+") then
if state == 0 then
name = name:match("%d+")
else
name = "Track "..name:match("%d+")
end
end
message(name)
end
else
message(string.format("%u", reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")))
end
return message:extract()
end

-- The macros for compose when group of items selected
local function composeMultipleTrackMessage(func, states, inaccuracy)
local message = initOutputMessage()
for k = 1, #tracks do
local state = func(tracks[k])
local prevState if tracks[k-1] then prevState = func(tracks[k-1]) end
local nextState if tracks[k+1] then nextState = func(tracks[k+1]) end
if state ~= prevState and state == nextState then
message(string.format("tracks from %s ", getTrackID(tracks[k])))
elseif state == prevState and state ~= nextState then
message(string.format("to %s ", getTrackID(tracks[k])))
if inaccuracy and type(state) == "number" then
message(string.format("%s", states[state+inaccuracy]))
else
message(string.format("%s", states[state]))
end
if k < #tracks then
message(", ")
end
elseif state == prevState and state == nextState then
else
message(string.format("%s ", getTrackID(tracks[k])))
if inaccuracy and type(state) == "number" then
message(string.format("%s", states[state+inaccuracy]))
else
message(string.format("%s", states[state]))
end
if k < #tracks then
message(", ")
elseif k == #tracks-1 then
message(" and ")
end
end
end
return message
end

-- global pseudoclass initialization
local parentLayout = initLayout("Track%s properties")

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
parentLayout:registerSublayout("visualLayout", " visual")

-- Playback properties
parentLayout:registerSublayout("playbackLayout", " playback")

-- Recording properties
parentLayout:registerSublayout("recordingLayout", " recording")

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
parentLayout.visualLayout:registerProperty(trackNameProperty)

function trackNameProperty:get()
local message = initOutputMessage()
message:initType("Perform this action to rename selected track.", "performable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, new name will applied to all selected tracks.", 1)
end
if type(tracks) == "table" then
message("Track names: ")
message(composeMultipleTrackMessage(function(track)
local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
if name ~= "" then
return name
else
return "unnamed"
end
end,
setmetatable({}, {__index = function(self, key) return key end})))
else
local _, name = reaper.GetSetMediaTrackInfo_String(tracks, "P_NAME", "", false)
if  name ~= "" then
message(string.format("%s name %s", getTrackID(tracks), name))
else
message(string.format("%s unnamed", getTrackID(tracks)))
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
local aState, answer = reaper.GetUserInputs(string.format("Change name for track %s", getTrackID(tracks)), 1, 'Type new track name:', name)
if aState == true then
reaper.GetSetMediaTrackInfo_String(tracks, "P_NAME", answer, true)
end
end
message(self:get())
return message
end



local folderStateProperty = {}
parentLayout.visualLayout:registerProperty( folderStateProperty)
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
message:initType("Adjust this property to switch the folder state of selected tracks.", "Adjustable")
if multiSelectionSupport == true then
message:addType(" This property is adjustable for one track only.", 1)
end
if type(tracks) == "table" then
message("Tracks folder: ")
message(composeMultipleTrackMessage(function(track) return tostring(reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")).."|"..tostring(reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")) end,
setmetatable({},
{__index = function(self, key)
local msg = ""
local states = folderStateProperty.states
local compactStates = folderStateProperty.compactStates
local state = tonumber(utils.splitstring(key, "|")[1])
if state == 0 or state == 1 then
if state == 1 then
local compactState = tonumber(utils.splitstring(key, "|")[2])
msg = msg..compactStates[compactState].." "
end
msg = msg..states[state]
elseif state < 0 then
state = -(state-1)
if state < 3 then
msg = msg..string.format("%s", states[state])
else
msg = msg..string.format(states[3], state-1)
end
end
return msg
end})
))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_FOLDERDEPTH")
message(string.format("%s is a", getTrackID(tracks)))
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
message(string.format("%s is a", getTrackID(tracks)))
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
parentLayout.playbackLayout:registerProperty(volumeProperty)
parentLayout.recordingLayout:registerProperty(volumeProperty)
function volumeProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set the desired volume value for selected track.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of track has been selected, the relative of previous value will be applied for each track of.", 1)
end
message:addType(" Perform this property to reset the volume to zero DB.", 1)
if type(tracks) == "table" then
message("tracks volume:")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "D_VOL") end, representation.db))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "D_VOL")
message(string.format("%s volume %s", getTrackID(tracks), representation.db[state]))
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
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_VOL")
if action == true then
if state < 3.981071705535 then
state = utils.decibelstonum(utils.numtodecibels(state)+ajustStep)
else
state = 3.981071705535
end
elseif action == false then
if state > 0 then
state = utils.decibelstonum(utils.numtodecibels(state)-ajustStep)
else
state = 0
end
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks[k], "D_VOL", state)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "D_VOL")
if action == true then
if state < utils.decibelstonum(12.0) then
state = utils.decibelstonum(utils.numtodecibels(state)+ajustStep)
else
state = utils.decibelstonum(12.0)
message("maximum volume. ")
end
elseif action == false then
if utils.numtodecibels(state) ~= "-inf" then
state = utils.decibelstonum(utils.numtodecibels(state)-ajustStep)
else
state = 0
message("Minimum volume. ")
end
else
state = 1
end
reaper.SetMediaTrackInfo_Value(tracks, "D_VOL", state)
 end
 message(self:get())
return message
end


local panProperty = {}
parentLayout.playbackLayout:registerProperty(panProperty)
parentLayout.recordingLayout:registerProperty(panProperty)

function panProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set the desired pan value for selected track.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of track has been selected, the relative of previous value will be applied for each track of.", 1)
end
message:addType(" Perform this property to set the pan to center.", 1)
if type(tracks) == "table" then
message("tracks pan: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "D_PAN") end, representation.pan))
else
message(string.format("%s pan ", getTrackID(tracks)))
local state = reaper.GetMediaTrackInfo_Value(tracks, "D_PAN")
message(string.format("%s", representation.pan[state]))
end
return message
end

function panProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("percentStep", 1)
if action == true then
ajustingValue = utils.percenttonum(ajustingValue) or 0.01
elseif action == false then
ajustingValue = -utils.percenttonum(ajustingValue) or -0.01
else
message("reset, ")
ajustingValue = nil
end
if type(tracks) == "table" then
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_PAN")
if ajustingValue then
state = utils.round((state+ajustingValue), 3)
if state >= 1 then
state = 1
elseif state <= -1 then
state = -1
end
else
state = 0
end
reaper.SetMediaTrackInfo_Value(tracks[k], "D_PAN", state)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "D_PAN")
if ajustingValue then
state = utils.round((state+ajustingValue), 3)
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
end
message(self:get())
return message
end

local widthProperty = {}
parentLayout.playbackLayout:registerProperty(widthProperty)

function widthProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set the desired width value for selected track.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of track has been selected, the relative of previous value will be applied for each track of.", 1)
end
message:addType(" Perform this property to reset the value to 100 percent.", 1)
if type(tracks) == "table" then
message("tracks width: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "D_WIDTH") end, setmetatable({}, {__index = function(self, state) return string.format("%s%%", utils.numtopercent(state)) end})))
else
message(string.format("%s width ", getTrackID(tracks)))
local state = reaper.GetMediaTrackInfo_Value(tracks, "D_WIDTH")
message(string.format("%s%%", utils.numtopercent(state)))
end
return message
end

function widthProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("percentStep", 1)
if action == true then
ajustingValue = utils.percenttonum(ajustingValue)
elseif action == false then
ajustingValue = -utils.percenttonum(ajustingValue)
else
message("reset, ")
ajustingValue = nil
end
if type(tracks) == "table" then
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "D_WIDTH")
if ajustingValue then
state = utils.round((state+ajustingValue), 3)
if state >= 1 then
state = 1
elseif state <= -1 then
state = -1
end
else
state = 0
end
reaper.SetMediaTrackInfo_Value(tracks[k], "D_WIDTH", state)
end
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "D_WIDTH")
if ajustingValue then
state = utils.round((state+ajustingValue), 3)
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
 end
 message(self:get())
return message
end

local muteProperty = {}
 parentLayout.playbackLayout:registerProperty(muteProperty)
 muteProperty.states = {[0]="not muted", [1]="muted"}

function muteProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to mute or unmute selected track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the mute state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks mute: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "B_MUTE") end, self.states))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_MUTE")
message(string.format("%s %s", getTrackID(tracks), self.states[state]))
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
message("Unmuting selected tracks.")
elseif mutedTracks < notMutedTracks then
ajustingValue = 1
message("Muting selected tracks.")
else
ajustingValue = 0
message("Unmuting selected tracks.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "B_MUTE", ajustingValue)
end
else
local state = utils.nor(reaper.GetMediaTrackInfo_Value(tracks, "B_MUTE"))
reaper.SetMediaTrackInfo_Value(tracks, "B_MUTE", state)
end
message(self:get())
return message
end

local soloProperty = {}
parentLayout.playbackLayout:registerProperty(soloProperty)
 soloProperty.states = {
[0] = "not soloed",
[1] = "soloed",
[2] = "soloed in place",
[5] = "safe soloed",
[6] = "safe soloed in place"
}

function soloProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to solo or unsolo selected track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the solo state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks solo: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_SOLO") end, self.states))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_SOLO")
message(string.format("%s %s", getTrackID(tracks), self.states[state]))
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
message("Unsoloing selected tracks.")
elseif soloedTracks < notSoloedTracks then
ajustingValue = soloInConfig
message("Soloing selected tracks.")
else
ajustingValue = 0
message("Unsoloing selected tracks.")
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
end
message(self:get())
return message
end

local recarmProperty = {}
 parentLayout.recordingLayout:registerProperty(recarmProperty)
 recarmProperty.states = {[0]="not armed", [1]="armed"}

function recarmProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to arm or disarm selected track for record.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the record state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks arm: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECARM") end, self.states))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECARM")
message(string.format("%s %s", getTrackID(tracks), self.states[state]))
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
message("Unarming selected tracks.")
elseif armedTracks < notArmedTracks then
ajustingValue = 1
message("Arming selected tracks.")
else
ajustingValue = 0
message("Unarming selected tracks.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "I_RECARM", ajustingValue)
end
else
local state = utils.nor(reaper.GetMediaTrackInfo_Value(tracks, "I_RECARM"))
reaper.SetMediaTrackInfo_Value(tracks, "I_RECARM", state)
end
message(self:get())
return message
end

local recmonitoringProperty = {}
 parentLayout.recordingLayout:registerProperty(recmonitoringProperty)
 recmonitoringProperty.states = {
[0] = "off",
[1] = "normal",
[2] = "not when playing"
}

function recmonitoringProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to choose the desired record monitoring state.", "Adjustable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of track has been selected, the value will enumerate only if selected tracks have the same value. Otherwise, the record monitoring state will be set to "%s" first, then will enumerate this.', self.states[1]), 1)
end
if type(tracks) == "table" then
message("tracks record monitoring: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECMON") end, self.states))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMON")
message(string.format("%s record monitoring %s", getTrackID(tracks), self.states[state]))
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
message(string.format("Set selected tracks monitoring to %s.", self.states[state]))
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
end
message(self:get())
return message
end

-- Record inputs
local recInputsProperty = {}
parentLayout.	recordingLayout:registerProperty(recInputsProperty)

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
local channel = utils.getBitValue(val, 1, 5)
if channel == 0 then
message("all channels, ")
else
message(string.format("channel %u, ", channel))
end
if utils.getBitValue(val, 6, 12) == 62 then
message("from Virtual MIDI Keyboard")
elseif utils.getBitValue(val, 6, 12) == 63 then
message("from all devices")
else
local result, name = recInputsProperty.getMIDIInputName(utils.getBitValue(val, 6, 12))
if result == true then
message(string.format("from %s", name))
else
message(string.format("from unknown device with ID %u", utils.getBitValue(val, 6, 12)))
end
end
else
message("audio, ")
local input = utils.getBitValue(val, 1, 11)
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
return message:extract()
end

function recInputsProperty.calc(state, action)
if action == true then
if (state+1) >= 0 and (state+1) < 1024 then
if reaper.GetInputChannelName(utils.getBitValue(state+1, 1, 11)) then
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
local channel = utils.getBitValue(i, 1, 5)
local result, _ = recInputsProperty.getMIDIInputName(utils.getBitValue(i, 6, 12))
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
local channel = utils.getBitValue(i, 1, 5)
local result, _ = recInputsProperty.getMIDIInputName(utils.getBitValue(i, 6, 12))
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
local channel = utils.getBitValue(i, 1, 5)
local result, _ = recInputsProperty.getMIDIInputName(utils.getBitValue(i, 6, 12))
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
local channel = utils.getBitValue(i, 1, 5)
local result, _ = recInputsProperty.getMIDIInputName(utils.getBitValue(i, 6, 12))
if result == true and channel <= 16 then
return i
end
if i == 8192 then
return -1
end
end
elseif state > 4096 then
local result, device = recInputsProperty.getMIDIInputName(utils.getBitValue(state, 6, 12))
if result == true then
for i = state, 8192 do
local curResult, curDevice = recInputsProperty.getMIDIInputName(utils.getBitValue(i, 6, 12))
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
message:initType("Adjust this property to choose the desired record input of selected track.", "Adjustable, toggleable")
if multiSelectionSupport == true then
message:addType((' If the group of track has been selected, the value will enumerate up if selected tracks have the same value. If one of tracks has different value, all track will set to "%s" first, then will enumerate up this.'):format(self.compose(0)), 1)
end
message:addType(" Toggle this property to quick switch between input categories (mono, stereo or midi).", 1)
if multiSelectionSupport == true then
message:addType(" If the group of track has been selected, the quick switching will aplied for selected tracks by first selected track.", 1)
end
if type(tracks) == "table" then
message("Tracks record inputs: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECINPUT") end, setmetatable({}, {__index = function(self, state) return recInputsProperty.compose(state) end})))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECINPUT")
message(string.format("%s record input %s", getTrackID(tracks), self.compose(state)))
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
message(string.format("Set selected tracks record input to %s.", self.compose(state)))
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
end
message(self:get())
return message
end

local recmodeProperty = {}
 parentLayout.recordingLayout:registerProperty(recmodeProperty)
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
message:initType("Adjust this property to set the desired mode for recording.", "Adjustable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of track has been selected, The value will enumerate only if selected tracks have the same value. Otherwise, the record mode state will be set to "%s", then will enumerate this.', self.states[1]), 1)
end
if type(tracks) == "table" then
message("tracks record mode: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECMODE") end, self.states))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMODE")
-- reaper.ShowMessageBox(state, "debug", 0)
message(string.format("%s record mode %s", getTrackID(tracks), self.states[state]))
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
message(string.format("Set selected tracks record mode to %s.", self.states[state]))
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
end
message(self:get())
return message
end

-- Automation mode methods
local automationModeProperty = {}
parentLayout.recordingLayout: registerProperty(automationModeProperty)
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
message:initType("Adjust this property to set the desired automation mode for selected track.", "Adjustable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of track has been selected, The value will enumerate only if selected tracks have the same value. Otherwise, the automation mode state will be set to "%s", then will enumerate this.', self.states[1]), 1)
end
if type(tracks) == "table" then
message("tracks automation mode: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE") end, self.states))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_AUTOMODE")
message(string.format("%s automation mode %s", getTrackID(tracks), self.states[state]))
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
message(string.format("Set selected tracks automation mode to %s.", self.states[state]))
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
end
message(self:get())
return message
end


local phaseProperty = {}
 parentLayout.playbackLayout:registerProperty(phaseProperty)
 phaseProperty.states = {[0]="normal", [1]="inverted"}

function phaseProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to set the phase polarity of selected track.", "toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the phase polarity state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks phase: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "B_PHASE") end, self.states))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_PHASE")
message(string.format("%s phase %s", getTrackID(tracks), self.states[state]))
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
local state = utils.nor(reaper.GetMediaTrackInfo_Value(tracks, "B_PHASE"))
reaper.SetMediaTrackInfo_Value(tracks, "B_PHASE", state)
end
message(self:get())
return message
end

-- Send to parent or master track methods
local mainSendProperty = {}
parentLayout.playbackLayout:registerProperty(mainSendProperty)
mainSendProperty.states = {[0]="not sends", [1]="sends"}

function mainSendProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to switch the send state of selected track to parent or master track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the send state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks send to parent or master track: ")
message(composeMultipleTrackMessage(function(track)
local masterOrParent if reaper.GetParentTrack(track) then masterOrParent = true else masterOrParent = false end
return tostring(reaper.GetMediaTrackInfo_Value(track, "B_MAINSEND")).."|"..tostring(masterOrParent)
end,
setmetatable({}, {
__index = function(self, key)
local msg, state, masterOrParent = "", tonumber(utils.splitstring(key, "|")[1]), utils.toboolean(utils.splitstring(key, "|")[2])
msg = mainSendProperty.states[state].." to "
if masterOrParent then
msg = msg.."parent"
else
msg = msg.."master"
end
return msg
end
})))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_MAINSEND")
message(string.format("%s %s to ", getTrackID(tracks), self.states[state]))
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
message("Switching off selected tracks send to parent or master track.")
elseif sendTracks < notSendTracks then
ajustingValue = 1
message("Switching on selected tracks send to parent or master track.")
else
ajustingValue = 0
message("Switching off selected tracks send to parent or master track.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "B_MAINSEND", ajustingValue)
end
else
local state = utils.nor(reaper.GetMediaTrackInfo_Value(tracks, "B_MAINSEND"))
reaper.SetMediaTrackInfo_Value(tracks, "B_MAINSEND", state)
end
message(self:get())
return message
end


-- Free mode methods
local freemodeProperty = {}
parentLayout.playbackLayout:registerProperty(freemodeProperty)
freemodeProperty.states = {[0]="disabled", [1]="enabled"}

function freemodeProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to set the free mode of selected track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the free mode state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks free position mode: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "B_FREEMODE") end, self.states))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_FREEMODE")
message(string.format("%s free position %s", getTrackID(tracks), self.states[state]))
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
local state = utils.nor(reaper.GetMediaTrackInfo_Value(tracks, "B_FREEMODE"))
reaper.SetMediaTrackInfo_Value(tracks, "B_FREEMODE", state)
reaper.UpdateTimeline()
end
message(self:get())
return message
end

-- Timebase methods
local timebaseProperty = {}
 parentLayout.playbackLayout:registerProperty(timebaseProperty)
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
message:initType("Adjust this property to choose the desired time base mode for selected track.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of tracks has been selected, the value will enumerate only if selected tracks have the same value. Otherwise, the timebase state will be set to "%s", then will enumerate this.', self.states[0]), 1)
end
if type(tracks) == "table" then
message("Track timebase: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "C_BEATATTACHMODE") end, self.states, 1))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "C_BEATATTACHMODE")
message(string.format("%s timebase %s", getTrackID(tracks), self.states[state+1]))
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
if action == true or action == false then
local st = {0, 0, 0, 0}
for k = 1, #tracks do
local state = reaper.GetMediaTrackInfo_Value(tracks[k], "C_BEATATTACHMODE")
st[state+2] = st[state+2]+1
end
local state
if math.max(st[1], st[2], st[3], st[4]) == #tracks then
state = reaper.GetMediaTrackInfo_Value(tracks[1], "C_BEATATTACHMODE")
if (state+ajustingValue) < #self.states and (state+ajustingValue) >= -1 then
state = state+ajustingValue
end
else
state = -1
end
message(string.format("Set selected tracks timebase to %s.", self.states[state+1]))
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "C_BEATATTACHMODE", state)
end
else
message(string.format("Set selected tracks timebase to %s.", self.states[0]))
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
end
message(self:get())
return message
end

-- Monitor items while recording methods
local recmonitorItemsProperty = {}
parentLayout.recordingLayout:registerProperty( recmonitorItemsProperty)
recmonitorItemsProperty.states = {[0]="not monitoring", [1]="monitoring"}

function recmonitorItemsProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property if you want to monitor items while recording or not on selected track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the monitor items state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks monitoring items: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_RECMONITEMS") end, self.states))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_RECMONITEMS")
message(string.format("%s items while recording is %s", getTrackID(tracks), self.states[state]))
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
message("Switching off the monitoring items for selected tracks.")
elseif monitoredTracks < notMonitoredTracks then
ajustingValue = 1
message("Switching on the monitoring items for selected tracks.")
else
ajustingValue = 0
message("Switching off the monitoring items for selected tracks.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "I_RECMONITEMS", ajustingValue)
end
else
local state = utils.nor(reaper.GetMediaTrackInfo_Value(tracks, "I_RECMONITEMS"))
reaper.SetMediaTrackInfo_Value(tracks, "I_RECMONITEMS", state)
end
message(self:get())
return message
end

-- Track performance settings: buffering media
local performanceBufferingProperty = {}
parentLayout.playbackLayout: registerProperty(performanceBufferingProperty)
performanceBufferingProperty.states = {[0]="buffering", [1]="not buffering"}

function performanceBufferingProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to switch the track performance buffering media of selected track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the buffering media state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks media buffering: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_PERFFLAGS")&1 end, self.states))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_PERFFLAGS")&1
message(string.format("%s media is %s", getTrackID(tracks), self.states[state]))
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
notBufferedTracks = notBufferedTracks+1
else
bufferedTracks = bufferedTracks+1
end
end
local ajustingValue
if bufferedTracks > notBufferedTracks then
ajustingValue = 1
message("Switching off the media buffering for selected tracks.")
elseif bufferedTracks < notBufferedTracks then
ajustingValue = 0
message("Switching on the media buffering for selected tracks.")
else
ajustingValue = 0
message("Switching on the media buffering for selected tracks.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "I_PERFFLAGS", ajustingValue&1)
end
else
local state = utils.nor(reaper.GetMediaTrackInfo_Value(tracks, "I_PERFFLAGS")&1)
reaper.SetMediaTrackInfo_Value(tracks, "I_PERFFLAGS", state&1)
end
message(self:get())
return message
end


-- Track performance settings: Anticipative FX
local performanceAnticipativeFXProperty = {}
 parentLayout.playbackLayout:registerProperty(performanceAnticipativeFXProperty)
performanceAnticipativeFXProperty.states = {[0]="anticipative", [2]="non-anticipative"}

function performanceAnticipativeFXProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to switch the track performance FX anticipativeness of selected track.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the FX anticipativeness state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks FX anticipativeness: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "I_PERFFLAGS")&2 end, self.states))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "I_PERFFLAGS")&2
message(string.format("%s FX is %s", getTrackID(tracks), self.states[state]))
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
notanticipatedTracks = notanticipatedTracks+1
else
anticipatedTracks = anticipatedTracks+1
end
end
local ajustingValue
if anticipatedTracks > notanticipatedTracks then
ajustingValue = 2
message("Switching off the anticipativeness FX for selected tracks.")
elseif anticipatedTracks < notanticipatedTracks then
ajustingValue = 0
message("Switching on the anticipativeness FX for selected tracks.")
else
ajustingValue = 0
message("Switching on the anticipativeness FX for selected tracks.")
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
end
message(self:get())
return message
end

-- Track color methods
local colorProperty = {}
parentLayout.visualLayout:registerProperty(colorProperty)

function colorProperty.getValue(track)
return reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR"), reaper.GetTrackColor(track)
end

function colorProperty.setValue(track, value)
reaper.SetTrackColor(track, value)
end

function colorProperty:get()
local message = initOutputMessage()
message:initType("Read this property to get the information about track color. Perform this property to apply composed color in the track category.", "performable")
if multiSelectionSupport == true then
message:addType(" If the group of track have been selected, this color will be applied for all this tracks.", 1)
end
if type(tracks) == "table" then
message("Tracks color: ")
message(composeMultipleTrackMessage(function(track) return table.concat(({self.getValue(track)}), "|") end, setmetatable({}, {
__index = function(self, key)
state, visualApplied = tonumber(utils.splitstring(key, "|")[1]), tonumber(utils.splitstring(key, "|")[2])
msg = colors:getName(reaper.ColorFromNative(state))
if state ~= visualApplied then
if visualApplied == 0 then
msg = msg..", but visually not applied"
else
msg = msg..string.format(", but visually displayed as %s", colors:getName(reaper.ColorFromNative(visualApplied)))
end
end
return msg
end
})))
else
local state, visualApplied = self.getValue(tracks)
message(string.format("%s color %s", getTrackID(tracks), colors:getName(reaper.ColorFromNative(state))))
if visualApplied == 0 then
if visualApplied == 0 then
message(", but visually not applied")
else
message(string.format(", but visually displayed as %s", colors:getName(reaper.ColorFromNative(visualApplied))))
end
end
end
return message
end

function colorProperty:set(action)
local message = initOutputMessage()
if action == nil then
local state = getTrackComposedColor()
if state then
if type(tracks) == "table" then
message(string.format("All selected tracks colorized to %s.", colors:getName(reaper.ColorFromNative(state))))
for _, track in ipairs(tracks) do
self.setValue(track, state)
end
else
self.setValue(tracks, state)
message(self:get())
end
else
if type(tracks) == "table" then
local fixed = 0
for _, track in ipairs(tracks) do
local curColor, visualApplied = self.getValue(track)
if curColor ~= visualApplied then
self.setValue(track, curColor)
fixed = fixed+1
end
end
if fixed > 0 then
message(string.format("The non-visual color has been applied for %u tracks.", fixed))
message(self:get())
else
message("There are no tracks to fix non-visual color.")
end
else
local curColor, visualApplied = self.getValue(tracks)
if curColor ~= visualApplied then
self.setValue(tracks, curColor)
message("Fixing the non-visual color.")
message(self:get())
else
message("This track is not requires for fix.")
end
end
end
else
message("This property is performable only.")
end
return message
end

-- Visibility in Mixer panel
local mixerVisibilityProperty = {}
parentLayout.visualLayout:registerProperty( mixerVisibilityProperty)
mixerVisibilityProperty.states = {[0]="hidden", [1]="visible"}

function mixerVisibilityProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to switch the visibility of selected track in mixer panel.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the visibility state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks visibility in Mixer panel: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "B_SHOWINMIXER") end, self.states))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINMIXER")
message(string.format("%s is %s on mixer panel", getTrackID(tracks), self.states[state]))
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
message("Hidding selected tracks on mixer panel.")
elseif visibleTracks < notvisibleTracks then
ajustingValue = 1
message("Showing selected tracks on mixer panel.")
else
ajustingValue = 0
message("Hidding selected tracks on mixer panel.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "B_SHOWINMIXER", ajustingValue)
end
else
local state = utils.nor(reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINMIXER"))
reaper.SetMediaTrackInfo_Value(tracks, "B_SHOWINMIXER", state)
end
message(self:get())
return message
end

-- Visibility in TCP
local tcpVisibilityProperty = {}
parentLayout.visualLayout:registerProperty( tcpVisibilityProperty)
tcpVisibilityProperty.states = mixerVisibilityProperty.states

function tcpVisibilityProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to switch the visibility of selected track control panel in arange view.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of tracks has been selected, the visibility state will be set to oposite value depending of moreness tracks with the same value.", 1)
end
if type(tracks) == "table" then
message("tracks control panels visibility: ")
message(composeMultipleTrackMessage(function(track) return reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") end, self.states))
else
local state = reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINTCP")
message(string.format("%s control panel is %s", getTrackID(tracks), self.states[state]))
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
message("Hidding selected tracks control panels.")
elseif visibleTracks < notvisibleTracks then
ajustingValue = 1
message("Showing selected tracks control panels.")
else
ajustingValue = 0
message("Hidding selected tracks control panels.")
end
for k = 1, #tracks do
reaper.SetMediaTrackInfo_Value(tracks[k], "B_SHOWINTCP", ajustingValue)
end
else
local state = utils.nor(reaper.GetMediaTrackInfo_Value(tracks, "B_SHOWINTCP"))
reaper.SetMediaTrackInfo_Value(tracks, "B_SHOWINTCP", state)
end
message(self:get())
return message
end

return parentLayout[sublayout]