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
-- get the master track
master = reaper.GetMasterTrack(0)

-- global pseudoclass initialization
masterLayout = {
section = "masterTrackProperties",
name = "Master track properties",


properties = {}
}


function masterLayout.canProvide()
if reaper.GetMasterTrackVisibility() == 1 then
return true
else
return false
end
end

local function registerProperty(property)
masterLayout.properties[#masterLayout.properties+1] = property
end

-- volume methods
local volumeProperty = {}
registerProperty( volumeProperty)
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
registerProperty(panProperty)

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
if state >= 1 then
state = 1
message("Right boundary. ")
elseif state <= -1 then
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
registerProperty(widthProperty)
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
if state >= 1 then
state = 1
message("Maximum width. ")
elseif state <= -1 then
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
registerProperty(muteProperty)
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
registerProperty(soloProperty)
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
-- Mono/stereo methods
-- This methods is very easy
local monoProperty = {}
registerProperty(monoProperty)
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
local state = reaper.GetToggleCommandState(40917)
if state == 0 then
state = 1
elseif state == 1 then
state = 0
end
reaper.Main_OnCommand(40917, state)
message(string.format("Master %s", ({[0] = "stereo", [1] = "mono"})[reaper.GetToggleCommandState(40917)]))
return message
end

-- Play rate methods
-- It's so easy because there are no deep control. Hmm, either i haven't found this.
local playrateProperty = {}
registerProperty(playrateProperty)
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
registerProperty(pitchPreserveProperty)
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
local state = reaper.GetToggleCommandState(40671)
if state == 0 then
state = 1
elseif state == 1 then
state = 0
end
reaper.Main_OnCommand(40671, state)
message(string.format("Master pitch when playrate changes is %s", ({[0] = "not preserved", [1] = "preserved"})[reaper.GetToggleCommandState(40671)]))
return message
end



-- Master tempo methods
-- Seems, Cockos allows to rest of for programmers 🤣
local tempoProperty = {}
registerProperty(tempoProperty)
function tempoProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set new master tempo. Perform this property with needed period to tap tempo manualy. Please note: when you'll perform this property, you will hear no any message.", "Adjustable, performable")
local state = reaper.Master_GetTempo()
message(string.format("Master tempo %s", round(state, 3)))
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
message(string.format("Master tempo %s", round(state, 3)))
return message
end

return masterLayout