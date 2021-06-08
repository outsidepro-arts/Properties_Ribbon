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

local parentLayout = initLayout("%spreferences actions")

function parentLayout.canProvide()
return true
end

parentLayout:registerSublayout("reaperPrefs", "REAPER ")
parentLayout:registerSublayout("osaraLayout", "OSARA extension")
if reaper.APIExists("ReaPack_AboutInstalledPackage") == true then
parentLayout:registerSublayout("reaPackLayout", "ReaPack extension ")
end
if reaper.APIExists("CF_GetSWSVersion") == true then
parentLayout:registerSublayout("swsLayout", "SWS extension ")
end




-- The properties functions template

local function getUsualProperty(_cmd, _msg)
local usual = {
-- the Main_OnCommand ID
cmd = _cmd,
-- The property label
msg = _msg,
get = function(self)
local message = initOutputMessage()
message:initType(string.format("Perform this property to open the %s dialog.", self.msg), "Performable")
if config.getboolean("allowLayoutsrestorePrev", true) == true then
message:addType(" Please note that this action is onetime, i.e., after action here, the current layout will be closed.", 1)
message:addType(", onetime", 2)
end
message(self.msg)
return message
end,
set = function(self, action)
if action == nil then
reaper.Main_OnCommand(self.cmd, 1)
restorePreviousLayout()
setUndoLabel(self:get())
return ""
else
return "This property is performable only."
end
end
}
return usual
end


-- REAPER preferences
parentLayout.reaperPrefs:registerProperty(getUsualProperty(40016, "Global preferences"))

-- Metronome/Pre-roll setings
parentLayout.reaperPrefs:registerProperty(getUsualProperty(40363, "Show metronome and pre-roll settings"))

-- Snap/Grid settings
parentLayout.reaperPrefs:registerProperty(getUsualProperty(40071, "Show snap and grid settings"))

-- External time synchronization settings
parentLayout.reaperPrefs:registerProperty(getUsualProperty(40619, "Show external timecode synchronization settings"))

-- OSARA configuration
-- We will not check OSARA install status,cuz it's supposet should be installed there
parentLayout.osaraLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_OSARA_CONFIG"), "OSARA configuration"))
parentLayout.osaraLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_OSARA_PEAKWATCHER"), "Peak Watcher"))
parentLayout.osaraLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_OSARA_ABOUT"), "About currently installed OSARA"))

-- ReaPack actions
if parentLayout.reaPackLayout then
parentLayout.reaPackLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_REAPACK_BROWSE"), "Browse packages"))
parentLayout.reaPackLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_REAPACK_IMPORT"), "Import repositories"))
parentLayout.reaPackLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_REAPACK_MANAGE"), "Manage repositories"))
parentLayout.reaPackLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_REAPACK_SYNC"), "Synchronize packages"))
parentLayout.reaPackLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_REAPACK_UPLOAD"), "Upload packages"))
parentLayout.reaPackLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_REAPACK_ABOUT"), "About currently installed ReaPack"))
end

-- SWS actions
if parentLayout.swsLayout then
parentLayout.swsLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_BR_LOUDNESS_PREF"), "Global loudness preferences"))
parentLayout.swsLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_XENAKIOS_DISKSPACECALC"), "Disk space calculator"))
parentLayout.swsLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_AUTORENDER_PREFERENCES"), "Autorender: Global Preferences"))
parentLayout.swsLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_SWS_ABOUT"), "About currently installed SWS extension"))
parentLayout.swsLayout:registerProperty(getUsualProperty(reaper.NamedCommandLookup("_BR_VERSION_CHECK"), "Check for new SWS version"))
end

parentLayout.defaultSublayout = "reaperPrefs"

return parentLayout