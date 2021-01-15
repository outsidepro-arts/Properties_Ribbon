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
sublayout = "playbackLayout"
end

-- get the master track
master = reaper.GetMasterTrack(0)

-- global pseudoclass initialization
parentLayout = initLayout("Master track%s properties")

function parentLayout.canProvide()
-- We will check the TCP visibility only
if (reaper.GetMasterTrackVisibility()&1) == 1 then
return true
else
return false
end
end

parentLayout:registerSublayout("playbackLayout", " playback")
parentLayout:registerSublayout("visualLayout", " visual")


-- volume methods
local volumeProperty = {}
parentLayout.playbackLayout:registerProperty( volumeProperty)
function volumeProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired volume value for master track. Perform this property to reset the volume to zero DB.", "adjustable, performable")
local state = reaper.GetMediaTrackInfo_Value(master, "D_VOL")
message(string.format("Master volume %s db", numtodecibels(state)))
return message
end

function volumeProperty:set(action)
local message = initOutputMessage()
if action == nil then
message("reset, ")
end
local ajustStep = config.getinteger("dbStep", 0.1)
local state = reaper.GetMediaTrackInfo_Value(master, "D_VOL")
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
reaper.SetMediaTrackInfo_Value(master, "D_VOL", state)
message(string.format("Master volume %s db", numtodecibels(reaper.GetMediaTrackInfo_Value(master, "D_VOL"))))
return message
end

-- pan methods
local panProperty = {}
parentLayout.playbackLayout:registerProperty(panProperty)

function panProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired pan value for master track. Perform this property to set the pan to center.", "Adjustable, performable")
local state = reaper.GetMediaTrackInfo_Value(master, "D_PAN")
message(string.format("Master pan %s", numtopan(state)))
return message
end

function panProperty:set(action)
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
local state = reaper.GetMediaTrackInfo_Value(master, "D_PAN")
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
reaper.SetMediaTrackInfo_Value(master, "D_PAN", state)
message(string.format("Master pan %s", numtopan(reaper.GetMediaTrackInfo_Value(master, "D_PAN"))))
return message
end

-- Width methods
local widthProperty = {}
parentLayout.playbackLayout:registerProperty(widthProperty)
function widthProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired width value for master track. Perform this property to reset the value to 100 percent.", "Adjustable, performable")
local state = reaper.GetMediaTrackInfo_Value(master, "D_WIDTH")
message(string.format("Master width %s%%", numtopercent(state)))
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
local state = reaper.GetMediaTrackInfo_Value(master, "D_WIDTH")
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
reaper.SetMediaTrackInfo_Value(master, "D_WIDTH", state)
message(string.format("Master width %s%%", numtopercent(reaper.GetMediaTrackInfo_Value(master, "D_WIDTH"))))
return message
end


-- Mute methods
local muteProperty = {}
parentLayout.playbackLayout:registerProperty(muteProperty)
function muteProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to mute or unmute master track.", "Toggleable")
local states = {[0]="not muted", [1]="muted"}
local _, state = reaper.GetTrackUIMute(master)
if state == true then
state = 1
else
state = 0
end
message(string.format("master %s", states[state]))
return message
end

function muteProperty:set(action)
local message = initOutputMessage()
local states = {[0]="not muted", [1]="muted"}
if action ~= nil then
return "This property is toggleable only."
end
local _, state = reaper.GetTrackUIMute(master)
if state == true then
state = 0
else
state = 1
end
reaper.SetMediaTrackInfo_Value(master, "B_MUTE", state)
if ({reaper.GetTrackUIMute(master)})[2] == true then
state = 1
else 
state = 0
end
message(string.format("master %s", states[state]))
return message
end

-- Solo methods
local soloProperty = {}
parentLayout.playbackLayout:registerProperty(soloProperty)
function soloProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to solo or unsolo master track.", "Toggleable")
local states = {[0] = "not soloed", [16] = "soloed"}
local master = reaper.GetMasterTrack(0)
local state = ({reaper.GetTrackState(master)})[2]&16
message(string.format("Master %s", states[state]))
return message
end

function soloProperty:set(action)
if action ~= nil then
return "This property is adjustable only."
end
local message = initOutputMessage()
local soloInConfig = reaper.get_config_var_string("soloip")
if soloInConfig == true then
soloInConfig = 2
else
soloInConfig = 1
end
local states = {[0] = "not soloed", [16] = "soloed"}
local state = ({reaper.GetTrackState(master)})[2]&16
if state > 0 then
state = 0
else
state = soloInConfig
end
reaper.SetMediaTrackInfo_Value(master, "I_SOLO", state)
message(string.format("Master %s", states[({reaper.GetTrackState(master)})[2]&16]))
return message
end

-- FX bypass methods
local masterFXProperty = {}
parentLayout.playbackLayout:registerProperty(masterFXProperty)
function masterFXProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to switch the FX activity of master track.", "Toggleable")
message(string.format("Master FX %s", ({[0] = "active", [1] = "bypassed"})[reaper.GetToggleCommandState(16)]))
return message
end

function masterFXProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
local state = nor(reaper.GetToggleCommandState(16))
reaper.Main_OnCommand(16, state)
message(string.format("Master FX %s", ({[0] = "active", [1] = "bypassed"})[reaper.GetToggleCommandState(16)]))
return message
end

-- Mono/stereo methods
-- This methods is very easy
local monoProperty = {}
parentLayout.playbackLayout:registerProperty(monoProperty)
function monoProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to switch the master track to mono or stereo.", "Toggleable")
message(string.format("Master %s", ({[0] = "stereo", [1] = "mono"})[reaper.GetToggleCommandState(40917)]))
return message
end

function monoProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
local state = nor(reaper.GetToggleCommandState(40917))
reaper.Main_OnCommand(40917, state)
message(string.format("Master %s", ({[0] = "stereo", [1] = "mono"})[reaper.GetToggleCommandState(40917)]))
return message
end

-- Play rate methods
-- It's so easy because there are no deep control. Hmm, either i haven't found this.
local playrateProperty = {}
parentLayout.playbackLayout:registerProperty(playrateProperty)
function playrateProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired master playrate. Perform this property to reset the master playrate to 1.", "adjustable, performable")
local state = reaper.Master_GetPlayRate(0)
message(string.format("Master play rate %s", round(state, 3)))
return message
end

function playrateProperty:set(action)
local message = initOutputMessage()
-- Cockos are surprisingly strange... There are is over two methods to get master playrate but no one method to set this. But we aren't offend!
if action == true then
reaper.Main_OnCommand(40524, 0)
elseif action == false then
reaper.Main_OnCommand(40525, 0)
else
message("Reset, ")
reaper.Main_OnCommand(40521, 0)
end
-- If you can found another method to set this, please let me know!
local state = reaper.Master_GetPlayRate(0)
message(string.format("Master play rate %s", round(state, 3)))
return message
end

-- Preserve pitch when playrate changes methods
-- It's more easy than previous method
local pitchPreserveProperty = {}
parentLayout.playbackLayout:registerProperty(pitchPreserveProperty)
function pitchPreserveProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to switch the preserving pitch of items in the project when playrate changes.", "Toggleable")
message(string.format("Master pitch when playrate changes is %s", ({[0] = "not preserved", [1] = "preserved"})[reaper.GetToggleCommandState(40671)]))
return message
end

function pitchPreserveProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
local state = nor(reaper.GetToggleCommandState(40671))
reaper.Main_OnCommand(40671, state)
message(string.format("Master pitch when playrate changes is %s", ({[0] = "not preserved", [1] = "preserved"})[reaper.GetToggleCommandState(40671)]))
return message
end



-- Master tempo methods
-- Seems, Cockos allows to rest of for programmers 🤣
local tempoProperty = {}
parentLayout.playbackLayout:registerProperty(tempoProperty)
function tempoProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set new master tempo. Perform this property with needed period to tap tempo manualy. Please note: when you'll perform this property, you will hear no any message.", "Adjustable, performable")
local state = reaper.Master_GetTempo()
message(string.format("Master tempo %s BPM", round(state, 3)))
return message
end

function tempoProperty:set(action)
local message = initOutputMessage()
if action == true then
reaper.Main_OnCommand(41129, 0)
elseif action == false then
reaper.Main_OnCommand(41130, 0)
else
reaper.Main_OnCommand(1134, 0)
return ""
end
local state = reaper.Master_GetTempo()
message(string.format("Master tempo %s BPM", round(state, 3)))
return message
end

-- Master visibility methods
-- TCP visibility
local tcpVisibilityProperty = {}
parentLayout.visualLayout:registerProperty(tcpVisibilityProperty)
tcpVisibilityProperty.states = {[false] = "not visible", [true] = "visible"}
function tcpVisibilityProperty.getValue()
local state = reaper.GetMasterTrackVisibility()&1
return (state ~= 0)
end

function tcpVisibilityProperty.setValue(value)
local state = reaper.GetMasterTrackVisibility()
if value == true then
state = ((1)|(state&2))
else
state = ((0)|(state&2))
end
reaper.SetMasterTrackVisibility(state)
end

function tcpVisibilityProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to set the master track control panel visibility. Please note: when you'll hide the master track control panel, the master track will defines as switched off and tracks focus shouldn't not set to. To get it back activate the master track in View menu.", "toggleable")
message(string.format("Master control panel %s", self.states[self.getValue()]))
return message
end

function tcpVisibilityProperty:set(action)
if action ~= nil then
return "This property is toggleable only."
end
local message = initOutputMessage()
local state = self.getValue()
if state == true then
if reaper.ShowMessageBox("You are going to hide the control panel of master track in arange view. It means that master track will be switched off and Properties Ribbon will not be able to get the access to untill you will not switch it back. To switch it on back, please either look at View REAPER menu or activate the status layout in the Properties Ribbon.", "Caution", 1) == 1 then
state = false
end
elseif state == false then
state = true
end
self.setValue(state)
message(string.format("Master control panel %s", self.states[self.getValue()]))
return message
end

-- MCP visibility
local mcpVisibilityProperty = {}
parentLayout.visualLayout:registerProperty(mcpVisibilityProperty)
mcpVisibilityProperty.states = tcpVisibilityProperty.states

function mcpVisibilityProperty.getValue()
local state = reaper.GetMasterTrackVisibility()&2
return (state == 0)
end

function mcpVisibilityProperty.setValue(value)
local state = reaper.GetMasterTrackVisibility()
if value == true then
state = ((state&1)|(0))
else
state = ((state&1)|(2))
end
reaper.SetMasterTrackVisibility(state)
end

function mcpVisibilityProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to set the master track visibility in mixer panel.", "toggleable")
message(string.format("Master %s on mixer panel", self.states[self.getValue()]))
return message
end

function mcpVisibilityProperty:set(action)
if action ~= nil then
return "This property is toggleable only."
end
local message = initOutputMessage()
local state = self.getValue()
if state == true then
state = false
elseif state == false then
state = true
end
self.setValue(state)
message(string.format("Master %s on mixer panel", self.states[self.getValue()]))
return message
end

-- Master track position in mixer panel
local masterTrackMixerPosProperty = {}
parentLayout.visualLayout:registerProperty(masterTrackMixerPosProperty)
masterTrackMixerPosProperty.states = {
"docked window",
"separated window",
"right side"
}

function masterTrackMixerPosProperty.getValue()
local check = reaper.GetToggleCommandState
if check(41610)== 1 then
return 1
elseif check(41636) == 1 then
return 2
elseif check(40389) == 1 then
return 3
end
return 0
end

function masterTrackMixerPosProperty.setValue(value)
local actions = {41610, 41636, 40389}
reaper.Main_OnCommand (actions[value], 1)
end

function masterTrackMixerPosProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose the desired master track position on the mixer panel.", "Adjustable")
message(string.format("Master track in the %s on the mixer panel", self.states[self.getValue()]))
return message
end

function masterTrackMixerPosProperty:set(action)
local message = initOutputMessage()
local state = self.getValue()
if action == true then
if self.states[state+1] then
self.setValue(state+1)
else
message("No more next property values. ")
end
elseif action == false then
if self.states[state-1] then
self.setValue(state-1)
else
message("No more previous property values. ")
end
else
return "This property is adjustable only."
end
message(string.format("Master track in the %s on the mixer panel", self.states[self.getValue()]))
return message
end

return parentLayout[sublayout]