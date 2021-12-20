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

-- It's just another vision of Properties Ribbon can be applied on


local contexts = {
[0]="Current track",
[1]="Selected item take",
[2] = "Unsupported"
}

local function getStringPluginsCount(where)
local preproc = setmetatable({}, {
__index = function(self, key)
if tonumber(key) ~= 0 then
return string.format("%s", key)
else
return "no one"
end
end
})
local result = nil
if type(where) == "function" then
result = where()
else
result = where
end
return ("%s plugin%s"):format(preproc[result], ({[true] = "s", [false] = ""})[(result ~= 1)])
end

local context = reaper.GetCursorContext()
if context == -1 then
context = extstate.lastKnownContext or context
end

local function getCurrentChainAction()
local result = extstate._sublayout["currentAction"] or 1
return result
end

local function setCurrentChainAction(action)
extstate._sublayout["currentAction"] = action
end


local fxActionsLayout = initLayout("FX actions")
fxActionsLayout:registerSublayout("contextLayout", contexts[context])
if reaper.GetMasterTrackVisibility()&1 == 1 then
fxActionsLayout:registerSublayout("masterTrackLayout", "Master track")
end
fxActionsLayout:registerSublayout("monitoringLayout", "Monitoring")
if reaper.GetLastTouchedTrack() == reaper.GetMasterTrack() or reaper.GetLastTouchedTrack() == nil and (reaper.GetMasterTrackVisibility()&1) == 1 then
    fxActionsLayout:destroySublayout("contextLayout")
    fxActionsLayout.contextLayout = fxActionsLayout.masterTrackLayout
    fxActionsLayout.masterTrackLayout.previousSublayout = nil
end


function fxActionsLayout.canProvide()
if reaper.GetLastTouchedTrack() then
if context == 0 then return true
elseif context == 1 then
return (reaper.GetSelectedMediaItem(0,0) ~= nil)
end
end
if reaper.GetLastTouchedTrack() == nil and (reaper.GetMasterTrackVisibility()&1) == 1 then
return true
end
return false
end

-- Contextual FX chain action
local contextualFXChain = {}
if reaper.GetLastTouchedTrack() ~= reaper.GetMasterTrack() and reaper.GetLastTouchedTrack() ~= nil then
fxActionsLayout.contextLayout:registerProperty(contextualFXChain)
end

contextualFXChain.actions = {
"View FX chain for %s with %s",
"View input FX chain for %s with %s"
}

function contextualFXChain.getValue()
if context == 0 then
return reaper.TrackFX_GetCount(reaper.GetLastTouchedTrack()), reaper.TrackFX_GetRecCount(reaper.GetLastTouchedTrack())
elseif context == 1 then
return reaper.TakeFX_GetCount(reaper.GetActiveTake(reaper.GetSelectedMediaItem(0,0)))
end
end

function contextualFXChain:get()
local message = initOutputMessage()
message:initType(("Adjust this property to choose which %s FX chain you wish to open. Perform this property to show the chosen FX chain."):format(contexts[context]), "Adjustable, performable")
if config.getboolean("allowLayoutsrestorePrev", true) then
message:addType(" Please note that this property is onetime, i.e., after its performing the previous actual layout will be restored.", 1)
message:addType(", onetime", 2)
end
local state = nil
if context == 0 then
state = getCurrentChainAction()
else
state = 1
end
message(self.actions[state]:format(contexts[context], getStringPluginsCount(({self.getValue()})[state])))
return message
end

function contextualFXChain:set(action)
local message = initOutputMessage()
local commands = {
[0]=40291,
[1]=40638
}
if action == nil then
local curAction = nil
if context == 0 then
curAction = getCurrentChainAction()
else
curAction = 1
end
if curAction == 1 then
reaper.Main_OnCommand(commands[context], 0)
else
reaper.Main_OnCommand(40844, 0)
end
restorePreviousLayout()
setUndoLabel(self:get())
return
elseif action == actions.set.increase then
if context == 0 then
local curAction = getCurrentChainAction()
if (curAction+1) <= #self.actions then
setCurrentChainAction(curAction+1)
else
message("No more next action.")
end
else
return ("The %s has not any extended actions."):format(contexts[context])
end
elseif action == actions.set.decrease then
if context == 0 then
local curAction = getCurrentChainAction()
if (curAction-1) >= 1 then
setCurrentChainAction(curAction-1)
else
message("No more previous action.")
end
else
return ("The %s has not any extended actions."):format(contexts[context])
end
end
message(self:get())
return message
end

-- FX chain for master track
local masterTrackFXChain = {}
if fxActionsLayout.masterTrackLayout then
fxActionsLayout.masterTrackLayout:registerProperty(masterTrackFXChain)
end

function masterTrackFXChain.getValue()
return reaper.TrackFX_GetCount(reaper.GetMasterTrack()), reaper.TrackFX_GetRecCount(reaper.GetMasterTrack())
end

function masterTrackFXChain:get()
local message = initOutputMessage()
message:initType("Perform this action to view the FX chain of master track.", "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) then
message:addType(" Please note that this property is onetime, i.e., after its performing the previous actual layout will be restored.", 1)
message:addType(", onetime", 2)
end
message(string.format("View FX chain of master track with %s", getStringPluginsCount(self.getValue)))
return message
end

function masterTrackFXChain:set(action)
if action == nil then
reaper.Main_OnCommand(40846, 0)
restorePreviousLayout()
setUndoLabel(self:get())
return
else
return "This property is performable only."
end
end


-- Bypass all FX action for contextual case
if reaper.GetLastTouchedTrack() ~= reaper.GetMasterTrack() and reaper.GetLastTouchedTrack() ~= nil then
fxActionsLayout.contextLayout:registerProperty{
states = {
[0]="Activate",
[1]="Bypass",
[2]="Bypass or activate"
},
commands = {
[0]=40298,
[1]=reaper.NamedCommandLookup("_S&M_TGL_TAKEFX_BYP")
},
getValue = contextualFXChain.getValue,
get = function(self)
local message = initOutputMessage()
message:initType(("Toggle this property to bypass or activate the FX chain of %s."):format(contexts[context]), "Toggleable")
if config.getboolean("allowLayoutsrestorePrev", true) then
message:addType(" Please note that this property is onetime, i.e., after its performing the previous actual layout will be restored.", 1)
message:addType(", onetime", 2)
end
if context == 1 and not reaper.APIExists("CF_GetSWSVersion") then
return string.format("The bypass property for %s is unavailable because no SWS installed.", contexts[context])
end
if self.getValue() == 0 then
message:addType(" This action is unavailable right now because there are no FX.", 1)
message:changeType("Unavailable", 2)
end
local state = nil
if context == 0 then
state = reaper.GetMediaTrackInfo_Value(reaper.GetLastTouchedTrack(), "I_FXEN")
elseif context == 1 then
state = 2
end
message(("%s %s for %s"):format(self.states[state], getStringPluginsCount(self.getValue), contexts[context]))
return message
end,
set = function(self, action)
if action == nil then
if context == 1 and not reaper.APIExists("CF_GetSWSVersion") then
return string.format("The bypass property for %s is unavailable because no SWS installed.", contexts[context])
end
if self.getValue() == 0 then
return "This property is unavailable because no plugin is set there."
end
local state = nil
if context == 0 then
state = utils.nor(reaper.GetMediaTrackInfo_Value(reaper.GetLastTouchedTrack(), "I_FXEN"))
else
state = 0
end
reaper.Main_OnCommand(self.commands[context], state)
restorePreviousLayout()
setUndoLabel(self:get())
return
else
return "This property is performable only."
end
end
}
end

if fxActionsLayout.masterTrackLayout then
fxActionsLayout.masterTrackLayout:registerProperty{
states = {
[0]="Activate",
[1]="Bypass"
},
getValue = masterTrackFXChain.getValue,
get = function(self)
local message = initOutputMessage()
message:initType("Toggle this property to bypass or activate all FX of master track.", "Toggleable")
if config.getboolean("allowLayoutsrestorePrev", true) then
message:addType(" Please note that this property is onetime, i.e., after its performing the previous actual layout will be restored.", 1)
message:addType(", onetime", 2)
end
if self.getValue() == 0 then
message:addType(" This action is unavailable right now because there are no FX.", 1)
message:changeType("Unavailable", 2)
end
local state = reaper.GetMediaTrackInfo_Value(reaper.GetMasterTrack(), "I_FXEN")
message(string.format("%s %s for master track", self.states[state], getStringPluginsCount(self.getValue)))
return message
end,
set = function(self, action)
if action == nil then
if self.getValue() > 0 then
local state = reaper.GetMediaTrackInfo_Value(reaper.GetMasterTrack(), "I_FXEN")
reaper.Main_OnCommand(16, utils.nor(state))
restorePreviousLayout()
setUndoLabel(self:get())
return
else
return "This property is unavailable because there is no plugins."
end
else
return "This property is toggleable only."
end
end
}
end

-- Contextual Properties Ribbon FX parameters layout
-- If this script is not installed, we should omit this property rendering
if reaper.NamedCommandLookup("_RS4e4bbd4cecce51a391e9f9b3b829c6d8144f237a") then
if reaper.GetLastTouchedTrack() ~= reaper.GetMasterTrack() and reaper.GetLastTouchedTrack() ~= nil then
fxActionsLayout.contextLayout:registerProperty{
getValue = contextualFXChain.getValue,
get = function(self)
local message = initOutputMessage()
message:initType(("Perform this property to work with %s FX properties."):format(contexts[context]), "Performable")
local chainCount, inputCount = self.getValue()
if context == 0 and inputCount > 0 then
message:addType(" The FX which have being added to track input FX chain will display also here.", 1)
end
if chainCount == 0 then
message:addType(" This action is unavailable right now because there are no FX.", 1)
message:changeType("Unavailable", 2)
end
message(("FX properties of %s with %s"):format(contexts[context], getStringPluginsCount(self.getValue)))
if context == 0 and inputCount > 0 then
message(string.format(" and input FX chain with %s", getStringPluginsCount(inputCount)))
end
return message
end,
set = function(self, action)
if action == actions.set.perform then
local chainCount, inputCount = self.getValue()
if chainCount > 0 or (inputCount and inputCount > 0) then
script_finish()
extstate["fx_properties.loadFX"] = nil
if script_init({section="properties",layout="fx_properties"}, true) then
script_reportOrGotoProperty()
return
end
else
return "This action is unavailable right now because no one FX is set there."
end
else
return "This property is performable only."
end
end
}
end
end


-- Contextual OSARA FX parameters action
if reaper.GetLastTouchedTrack() ~= reaper.GetMasterTrack() and reaper.GetLastTouchedTrack() ~= nil then
fxActionsLayout.contextLayout:registerProperty{
getValue = contextualFXChain.getValue,
get = function(self)
local message = initOutputMessage()
message:initType(("Perform this property to show the %s FX parameters using OSARA."):format(contexts[context]), "Performable")
local chainCount, inputCount = self.getValue()
if context == 0 and inputCount > 0 then
message:addType(" The FX which have being added to track input FX chain will display also here.", 1)
end
if chainCount == 0 then
message:addType(" This action is unavailable right now because there are no FX.", 1)
message:changeType("Unavailable", 2)
end
message(("View OSARA FX parameters for %s with %s"):format(contexts[context], getStringPluginsCount(self.getValue)))
if context == 0 and inputCount > 0 then
message(string.format(" and input FX chain with %s", getStringPluginsCount(inputCount)))
end
return message
end,
set = function(self, action)
if action == nil then
local chainCount, inputCount = self.getValue()
if chainCount > 0 or (inputCount and inputCount > 0) then
reaper.Main_OnCommand(reaper.NamedCommandLookup("_OSARA_FXPARAMS"), 0)
restorePreviousLayout()
setUndoLabel(self:get())
return
else
return "This action is unavailable right now because no one FX is set there."
end
else
return "This property is performable only."
end
end
}
end

-- FX properties for master track
-- If this script is not installed, we should omit this property rendering
local fxPropertiesForMasterTrack = {}
if fxActionsLayout.masterTrackLayout and reaper.NamedCommandLookup("_RS4e4bbd4cecce51a391e9f9b3b829c6d8144f237a") then
fxActionsLayout.masterTrackLayout:registerProperty(fxPropertiesForMasterTrack)
end

fxPropertiesForMasterTrack.getValue = masterTrackFXChain.getValue

function fxPropertiesForMasterTrack:get()
local message = initOutputMessage()
message:initType("Perform this property to work with FX parameters for master track.", "Performable")
local chainCount = self.getValue()
if chainCount == 0 then
message:addType(" This action is unavailable right now because there are no FX.", 1)
message:changeType("Unavailable", 2)
end
message(("FX properties of master track with %s"):format(getStringPluginsCount(self.getValue)))
return message
end

function fxPropertiesForMasterTrack:set(action)
if action == actions.set.perform then
local chainCount = self.getValue()
if chainCount > 0 then
script_finish()
extstate["fx_properties.loadFX"] = "master"
if script_init({section="properties",layout="fx_properties"}, true) then
script_reportOrGotoProperty()
end
return
else
return "This action is unavailable right now because no one FX is set there."
end
else
return "This property is performable only."
end
end



-- OSARA FX parameters for master track
local osaraMasterFXParametersProperty = {}
if fxActionsLayout.masterTrackLayout then
fxActionsLayout.masterTrackLayout:registerProperty(osaraMasterFXParametersProperty)
end

osaraMasterFXParametersProperty.getValue = masterTrackFXChain.getValue

function osaraMasterFXParametersProperty:get()
local message = initOutputMessage()
message:initType("Perform this property to show the FX parameters for master track using OSARA.", "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) then
message:addType(" Please note that this property is onetime, i.e., after its performing the previous actual layout will be restored.", 1)
message:addType(", onetime", 2)
end
local chainCount, monitoringCount = self.getValue()
if monitoringCount > 0 then
message:addType(" The FX which have being added to monitoring FX chain will display also here.", 1)
end
if chainCount == 0 and monitoringCount == 0 then
message:addType(" This action is unavailable right now because there are no FX.", 1)
message:changeType("Unavailable", 2)
end
message(("View OSARA FX parameters for master track with %s"):format(getStringPluginsCount(self.getValue)))
if monitoringCount > 0 then
message((" and monitoring section with %s"):format(getStringPluginsCount(monitoringCount)))
end
return message
end

function osaraMasterFXParametersProperty:set(action)
if action == nil then
local chainCount, monitoringCount = self.getValue()
if chainCount > 0 or monitoringCount > 0 then
reaper.Main_OnCommand(reaper.NamedCommandLookup("_OSARA_FXPARAMSMASTER"), 0)
restorePreviousLayout()
setUndoLabel(self:get())
return
else
return "This action is unavailable right now because no one FX is set there."
end
else
return "This property is performable only."
end
end


-- Monitoring FX actions
-- Monitoring FX chain
local monitorFXChainAction = {}
fxActionsLayout.monitoringLayout:registerProperty(monitorFXChainAction)

function monitorFXChainAction.getValue()
return reaper.TrackFX_GetRecCount(reaper.GetMasterTrack())
end

function monitorFXChainAction:get()
local message = initOutputMessage()
message:initType("Perform this property to show the monitoring FX chain.", "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) then
message:addType(" Please note that this property is onetime, i.e., after its performing the previous actual layout will be restored.", 1)
message:addType(", onetime", 2)
end
message(("View FX chain for monitoring FX with %s"):format(getStringPluginsCount(self.getValue)))
return message
end

function monitorFXChainAction:set(action)
if action == nil then
reaper.Main_OnCommand(41882, 0)
restorePreviousLayout()
setUndoLabel(self:get())
return
else
return "This property is performable only."
end
end


-- Monitoring bypass
fxActionsLayout.monitoringLayout:registerProperty{
states = {
[0]="Bypass",
[1]="Activate"
},
getValue = monitorFXChainAction.getValue,
get = function(self)
local message = initOutputMessage()
message:initType("Toggle this property to bypass or activate all monitoring FX.", "Toggleable")
if config.getboolean("allowLayoutsrestorePrev", true) then
message:addType(" Please note that this property is onetime, i.e., after its performing the previous actual layout will be restored.", 1)
message:addType(", onetime", 2)
end
if self.getValue() == 0 then
message:addType(" This action is unavailable right now because there are no FX.", 1)
message:changeType("Unavailable", 2)
end
local state = reaper.GetToggleCommandState(41884)
message(("%s %s in monitoring section"):format(self.states[state], getStringPluginsCount(self.getValue)))
return message
end,
set = function(self, action)
if action == nil then
if self.getValue() > 0 then
local state = reaper.GetToggleCommandState(41884)
reaper.Main_OnCommand(41884, utils.nor(state))
restorePreviousLayout()
setUndoLabel(self:get())
return
else
return "This property is unavailable because no plugins is set there."
end
else
return "This property is performable only."
end
end
}

-- Monitoring FX properties
local fxPropertiesForMonitoring = {}
fxActionsLayout.monitoringLayout:registerProperty(fxPropertiesForMonitoring)

fxPropertiesForMonitoring.getValue = masterTrackFXChain.getValue

function fxPropertiesForMonitoring:get()
local message = initOutputMessage()
message:initType("Perform this property to work with FX parameters for monitoring section.", "Performable")
local _, monitoringCount = self.getValue()
if monitoringCount == 0 then
message:addType(" This action is unavailable right now because there are no FX.", 1)
message:changeType("Unavailable", 2)
end
message(("FX properties of monitoring section with %s"):format(getStringPluginsCount(monitoringCount)))
return message
end

function fxPropertiesForMonitoring:set(action)
if action == actions.set.perform then
local _, monitoringCount = self.getValue()
if monitoringCount > 0 then
script_finish()
extstate["fx_properties.loadFX"] = "monitoring"
if script_init({section="properties",layout="fx_properties"}, true) then
script_reportOrGotoProperty()
end
return
else
return "This action is unavailable right now because no one FX is set there."
end
else
return "This property is performable only."
end
end


-- The monitoring sections has not the OSARA proposed FX parameters. I think that the decision about has dictated by using the TrackFX_GetRecCount both on a track and on a master track. Therefore we just copy this property to monitoring section also.
fxActionsLayout.monitoringLayout:registerProperty(osaraMasterFXParametersProperty)


return fxActionsLayout