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

-- It's just another vision of Properties Ribbon can be applied on

local parentLayout = initLayout("preferences actions")

parentLayout:registerSublayout("reaperPrefs", "REAPER")
parentLayout:registerSublayout("osaraLayout", "OSARA extension")
parentLayout:registerSublayout("swsLayout", "SWS extension")
if reaper.APIExists("ReaPack_AboutInstalledPackage") == true then
parentLayout:registerSublayout("reaPackLayout", "ReaPack extension")
end



-- REAPER preferences
parentLayout.reaperPrefs:registerProperty(composeSimpleDialogOpenProperty(40016, "Global preferences"))

-- Metronome/Pre-roll setings
parentLayout.reaperPrefs:registerProperty(composeSimpleDialogOpenProperty(40363))

-- Snap/Grid settings
parentLayout.reaperPrefs:registerProperty(composeSimpleDialogOpenProperty(40071))

-- External time synchronization settings
parentLayout.reaperPrefs:registerProperty(composeSimpleDialogOpenProperty(40619))

-- OSARA configuration
-- We will not check OSARA install status,cuz it's supposet should be installed there
parentLayout.osaraLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_OSARA_CONFIG"), "OSARA configuration"))
parentLayout.osaraLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_OSARA_PEAKWATCHER")))
parentLayout.osaraLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_OSARA_ABOUT"), "About currently installed OSARA"))

-- ReaPack actions
if parentLayout.reaPackLayout then
parentLayout.reaPackLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_REAPACK_BROWSE")))
parentLayout.reaPackLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_REAPACK_IMPORT")))
parentLayout.reaPackLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_REAPACK_MANAGE")))
parentLayout.reaPackLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_REAPACK_SYNC")))
parentLayout.reaPackLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_REAPACK_UPLOAD")))
parentLayout.reaPackLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_REAPACK_ABOUT"), "About currently installed ReaPack"))
end

-- SWS actions
parentLayout.swsLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_BR_LOUDNESS_PREF")))
parentLayout.swsLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_XENAKIOS_DISKSPACECALC")))
parentLayout.swsLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_AUTORENDER_PREFERENCES")))
parentLayout.swsLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_SWS_ABOUT"), "About currently installed SWS extension"))
parentLayout.swsLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_BR_VERSION_CHECK")))

return parentLayout