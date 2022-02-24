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

local maxDBValue = config.getinteger("maxDBValue", 12.0)


-- get the master track
local master = reaper.GetMasterTrack(0)

-- global pseudoclass initialization
local parentLayout = initLayout("Master track properties")

function parentLayout.canProvide()
-- We will check the TCP visibility only
if (reaper.GetMasterTrackVisibility()&1) == 1 then
return true
else
return false
end
end

parentLayout:registerSublayout("playbackLayout", "Playback")
parentLayout:registerSublayout("visualLayout", "Visualization")


-- volume methods
local volumeProperty = {}
parentLayout.playbackLayout:registerProperty( volumeProperty)
function volumeProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set the desired volume value for master track. Perform this property to input custom value.", "adjustable, performable")
local state = reaper.GetMediaTrackInfo_Value(master, "D_VOL")
message({objectId="Master", label="Volume", value=representation.db[state]})
return message
end

function volumeProperty:set(action)
local message = initOutputMessage()
local ajustStep = config.getinteger("dbStep", 0.1)
local maxDBValue = config.getinteger("maxDBValue", 12.0)
local state = reaper.GetMediaTrackInfo_Value(master, "D_VOL")
if action == actions.set.increase then
if state < utils.decibelstonum(maxDBValue) then
state = utils.decibelstonum(utils.numtodecibels(state)+ajustStep)
else
state = utils.decibelstonum(maxDBValue)
message("maximum volume. ")
end
elseif action == actions.set.decrease then
if utils.numtodecibels(state) ~= "-inf" then
state = utils.decibelstonum(utils.numtodecibels(state)-ajustStep)
else
state = 0
message("Minimum volume. ")
end
elseif action == actions.set.perform then
local retval, answer = reaper.GetUserInputs("Volume for master track", 1, prepareUserData.db.formatCaption, representation.db[state])
if not retval then
return "Canceled"
end
state = prepareUserData.db.process(answer, state)
end
if state then
reaper.SetMediaTrackInfo_Value(master, "D_VOL", state)
else
reaper.ShowMessageBox("Couldn't convert the data to appropriate value.", "Properties Ribbon error", 0)
return
end
message(self:get())
return message
end

-- pan methods
local panProperty = {}
parentLayout.playbackLayout:registerProperty(panProperty)

function panProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set the desired pan value for master track. Perform this property to input custom pan value.", "Adjustable, performable")
local state = reaper.GetMediaTrackInfo_Value(master, "D_PAN")
message({objectId="Master", label="Pan", value=representation.pan[state]})
return message
end

function panProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("percentStep", 1)
if action == actions.set.increase then
ajustingValue = utils.percenttonum(ajustingValue)
elseif action == actions.set.decrease then
ajustingValue = -utils.percenttonum(ajustingValue)
end
local state = reaper.GetMediaTrackInfo_Value(master, "D_PAN")
if action == actions.set.increase or action == actions.set.decrease then
state = utils.round((state+ajustingValue), 3)
if state > 1 then
state = 1
message("Right boundary. ")
elseif state < -1 then
state = -1
message("Left boundary. ")
end
elseif action == actions.set.perform then
local retval, answer = reaper.GetUserInputs("Pan for master track", 1, prepareUserData.pan.formatCaption, representation.pan[state])
if not retval then
return "Canceled"
end
state = prepareUserData.pan.process(answer, state)
end
if state then
reaper.SetMediaTrackInfo_Value(master, "D_PAN", state)
else
reaper.ShowMessageBox("Couldn't convert the data to appropriate value.", "Properties Ribbon error", 0)
return
end
message(self:get())
return message
end

-- Width methods
local widthProperty = {}
parentLayout.playbackLayout:registerProperty(widthProperty)
function widthProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set the desired width value for master track. Perform this property to input custom width value.", "Adjustable, performable")
local state = reaper.GetMediaTrackInfo_Value(master, "D_WIDTH")
message({objectId="Master", label="Width", value=string.format("%s%%", utils.numtopercent(state))})
return message
end

function widthProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("percentStep", 1)
if action == actions.set.increase then
ajustingValue = utils.percenttonum(ajustingValue)
elseif action == actions.set.decrease then
ajustingValue = -utils.percenttonum(ajustingValue)
end
local state = reaper.GetMediaTrackInfo_Value(master, "D_WIDTH")
if action == actions.set.increase or action == actions.set.decrease then
state = utils.round((state+ajustingValue), 3)
if state > 1 then
state = 1
message("Maximum width. ")
elseif state < -1 then
state = -1
message("Minimum width. ")
end
elseif action == actions.set.perform then
local retval, answer = reaper.GetUserInputs("Width for master track", 1, prepareUserData.percent.formatCaption, string.format("%s%%", utils.numtopercent(state)))
if not retval then
return "Canceled"
end
state = prepareUserData.percent.process(answer, state)
end
if state then
reaper.SetMediaTrackInfo_Value(master, "D_WIDTH", state)
else
reaper.ShowMessageBox("Couldn't convert the data to appropriate value.", "Properties Ribbon error", 0)
return
end
message(self:get())
return message
end


-- Mute methods
local muteProperty = {}
parentLayout.playbackLayout:registerProperty(muteProperty)
function muteProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to mute or unmute master track.", "Toggleable")
local states = {[0]="not muted", [1]="muted"}
local _, state = reaper.GetTrackUIMute(master)
if state == true then
state = 1
else
state = 0
end
message({objectId="Master", value=states[state]})
return message
end

function muteProperty:set(action)
local message = initOutputMessage()
local states = {[0]="not muted", [1]="muted"}
if action == actions.set.toggle then
local _, state = reaper.GetTrackUIMute(master)
if state == true then
state = 0
else
state = 1
end
reaper.SetMediaTrackInfo_Value(master, "B_MUTE", state)
message(self:get())
return message
else
return "This property is toggleable only."
end
end

-- Solo methods
local soloProperty = {}
parentLayout.playbackLayout:registerProperty(soloProperty)
function soloProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to solo or unsolo master track.", "Toggleable")
local states = {[0] = "not soloed", [16] = "soloed"}
local master = reaper.GetMasterTrack(0)
local state = ({reaper.GetTrackState(master)})[2]&16
message({objectId="Master", value=states[state]})
return message
end

function soloProperty:set(action)
if action == actions.set.toggle then
local message = initOutputMessage()
local retval, soloInConfig = reaper.get_config_var_string("soloip")
if retval then
soloInConfig = soloInConfig+1
end
local state = ({reaper.GetTrackState(master)})[2]&16
if state > 0 then
state = 0
else
state = soloInConfig
end
reaper.SetMediaTrackInfo_Value(master, "I_SOLO", state)
message(self:get())
return message
else
return "This property is toggleable only."
end
end

-- FX bypass methods
local masterFXProperty = {}
parentLayout.playbackLayout:registerProperty(masterFXProperty)
function masterFXProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to switch the FX activity of master track.", "Toggleable")
message{objectId="Master", label="FX"}
local fxCount = reaper.TrackFX_GetCount(master)
if fxCount > 0 then
message({value=string.format("%s (%u FX in master chain)", ({[0] = "active", [1] = "bypassed"})[reaper.GetToggleCommandState(16)], fxCount)})
else
message{value="empty"}
message:addType(" This property  is unavailable now because the master track FX chain is empty.", 1)
message:changeType("Unavailable", 2)
end
return message
end

function masterFXProperty:set(action)
if action == actions.set.toggle then
local message = initOutputMessage()
if reaper.TrackFX_GetCount(master) > 0 then
local state = utils.nor(reaper.GetToggleCommandState(16))
reaper.Main_OnCommand(16, state)
message(self:get())
else
return "This property  is unavailable nowbecause no one FX in master track FX chain found."
end
return message
else
return "This property is toggleable only."
end
end

-- Mono/stereo methods
-- This methods is very easy
local monoProperty = {}
parentLayout.playbackLayout:registerProperty(monoProperty)
function monoProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to switch the master track to mono or stereo.", "Toggleable")
message{objectId="Master", value=({[0] = "stereo", [1] = "mono"})[reaper.GetToggleCommandState(40917)]}
return message
end

function monoProperty:set(action)
if action == actions.set.toggle then
local state = utils.nor(reaper.GetToggleCommandState(40917))
reaper.Main_OnCommand(40917, state)
-- OSARA reports this state by itself
setUndoLabel(self:get())
return
else
return "This property is toggleable only."
end
end

-- Play rate methods
-- It's so easy because there are no deep control. Hmm, either i haven't found this.
local playrateProperty = {}
parentLayout.playbackLayout:registerProperty(playrateProperty)
function playrateProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set the desired master playrate. Perform this property to reset the master playrate to 1 X which means original rate.", "adjustable, performable")
local state = reaper.Master_GetPlayRate(0)
message{objectId="Master", label="Play rate", value=representation.playrate[state]}
return message
end

function playrateProperty:set(action)
local message = initOutputMessage()
-- Cockos are surprisingly strange... There are is over two methods to get master playrate but no one method to set this. But we aren't offend!
local cmds= {
{[actions.set.decrease]=40525,[actions.set.increase]=40524},
{[actions.set.decrease]=40523, [actions.set.increase]=40522}
}
if action == actions.set.increase or action == actions.set.decrease then
reaper.Main_OnCommand(cmds[config.getinteger("rateStep", 1)][action], 0)
elseif action == actions.set.perform then
message("Reset, ")
reaper.Main_OnCommand(40521, 0)
end
-- If you can found another method to set this, please let me know!
message(self:get())
return message
end

-- Preserve pitch when playrate changes methods
-- It's more easy than previous method
local pitchPreserveProperty = {}
parentLayout.playbackLayout:registerProperty(pitchPreserveProperty)
function pitchPreserveProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to switch the preserving pitch of items in the project when playrate changes.", "Toggleable")
message{objectId="Master", label="Pitch when playrate changes", value=({[0] = "not preserved", [1] = "preserved"})[reaper.GetToggleCommandState(40671)]}
return message
end

function pitchPreserveProperty:set(action)
if action == actions.set.toggle then
local message = initOutputMessage()
local state = utils.nor(reaper.GetToggleCommandState(40671))
reaper.Main_OnCommand(40671, state)
message(self:get())
return message
else
return "This property is toggleable only."
end
end



-- Master tempo methods
-- Seems, Cockos allows to rest of for programmers 🤣
local tempoProperty = {}
parentLayout.playbackLayout:registerProperty(tempoProperty)
function tempoProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set new master tempo. Perform this property with needed period to tap tempo manualy. Please note: when you'll perform this property, you will hear no any message.", "Adjustable, performable")
local state = reaper.Master_GetTempo()
message{objectId="Master", label="Tempo", value=string.format("%s BPM", utils.round(state, 3))}
return message
end

function tempoProperty:set(action)
if action == actions.set.increase then
reaper.Main_OnCommand(41129, 0)
elseif action == actions.set.decrease then
reaper.Main_OnCommand(41130, 0)
elseif action == actions.set.perform then
reaper.Main_OnCommand(1134, 0)
end
-- OSARA provides the state value for tempo
setUndoLabel(self:get())
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
message:initType("Toggle this property to set the master track control panel visibility. Please note: when you'll hide the master track control panel, the master track will defines as switched off and tracks focus shouldn't not set to. To get it back activate the master track in View menu.", "toggleable")
message{objectId="Master", label="Control panel", value=self.states[self.getValue()]}
return message
end

function tcpVisibilityProperty:set(action)
if action == actions.set.toggle then
local message = initOutputMessage()
local state = utils.nor(self.getValue())
if state == false then
if reaper.ShowMessageBox("You are going to hide the control panel of master track in arange view. It means that master track will be switched off and Properties Ribbon will not be able to get the access to untill you will not switch it back. To switch it on back, please either look at View REAPER menu or activate the status layout in the Properties Ribbon.", "Caution", 1) == 1 then
self.setValue(state)
end
end
message(self:get())
return message
else
return "This property is toggleable only."
end
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
message:initType("Toggle this property to set the master track visibility in mixer panel.", "toggleable")
message{objectId="Master", label="Visibility on mixer panel", value=self.states[self.getValue()]}
return message
end

function mcpVisibilityProperty:set(action)
if action == actions.set.toggle then
local message = initOutputMessage()
local state = self.getValue()
self.setValue(utils.nor(state))
message(self:get())
return message
else
return "This property is toggleable only."
end
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
local cmds = {41610, 41636, 40389}
reaper.Main_OnCommand (cmds[value], 1)
end

function masterTrackMixerPosProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to choose the desired master track position on the mixer panel.", "Adjustable")
local state = self.getValue()
message{objectId="Master track", label="Positioned"}
if state == 0 then
message{value="nowhere"}
else
message{value=string.format("in the %s on the mixer panel", self.states[state])}
end
return message
end

function masterTrackMixerPosProperty:set(action)
local message = initOutputMessage()
local state = self.getValue()
if action == actions.set.increase then
if self.states[state+1] then
self.setValue(state+1)
else
message("No more next property values. ")
end
elseif action == actions.set.decrease then
if self.states[state-1] then
self.setValue(state-1)
else
message("No more previous property values. ")
end
else
return "This property is adjustable only."
end
message(self:get())
return message
end

return parentLayout