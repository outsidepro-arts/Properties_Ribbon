--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2024 outsidepro-arts
License: MIT License

----------

Let me say a few word before starts
LUA - is not object oriented programming language, but very flexible. Its flexibility allows to realize OOP easy via metatables. In this scripts the pseudo OOP has been used, therefore we have to understand some terms.
.1 When i'm speaking "Class" i mean the metatable variable with some fields.
2. When i'm speaking "Method" i mean a function attached to a field or submetatable field.
When i was starting write this scripts complex i imagined this as real OOP. But in consequence the scripts structure has been reunderstanded as current structure. It has been turned out more comfort as for writing new properties table, as for call this from main script engine.
After this preambula, let me begin.
]]
--

-- It's just another vision of Properties Ribbon can be applied on

-- We have to fix the Properties Ribbon searching path. Currently it places on a up level directory
do
	local uplevelPath = select(2, reaper.get_action_context()):match('^.+[\\//]')
	uplevelPath = uplevelPath:match("(.+)([//\\])(.+)$")
	package.path = uplevelPath .. "//?//init.lua"
end

require "properties_ribbon"

useMacros("actions")

local parentLayout = PropertiesRibbon.initLayout("preferences actions")

parentLayout:registerSublayout("propertiesRibbonPrefs", "Properties ribbon")
parentLayout:registerSublayout("reaperPrefs", "REAPER")
parentLayout:registerSublayout("osaraLayout", "OSARA extension")
parentLayout:registerSublayout("swsLayout", "SWS extension")
if reaper.APIExists("ReaPack_AboutInstalledPackage") == true then
	parentLayout:registerSublayout("reaPackLayout", "ReaPack extension")
end


-- Properties ribbon configuration
local prConfigProperty = {}
parentLayout.propertiesRibbonPrefs:registerProperty(prConfigProperty)

function prConfigProperty:get()
	local message = initOutputMessage()
	message:initType("Perform this property to load the Properties Ribbon configuration layout.")
	message("Configure Properties Ribbon")
	return message
end

function prConfigProperty:set_perform()
	PropertiesRibbon.executeLayout("Properties Ribbon configuration")
end

-- The repository page of Properties Ribbon on Github
local prHomepageProperty = {}
parentLayout.propertiesRibbonPrefs:registerProperty(prHomepageProperty)

function prHomepageProperty:get()
	local message = initOutputMessage()
	-- I'll separate Github by space" for synthesizer report the brand's name correctly
	message:initType("Perform this property to go to the Properties Ribbon home page on Git hub.")
	message("Properties ribbon home page on Git hub")
	return message
end

function prHomepageProperty:set_perform()
	openPath("https://github.com/outsidepro-arts/properties_ribbon")
end

-- Download the latest Main branch archive
local prDownloadArchiveProperty = {}
parentLayout.propertiesRibbonPrefs:registerProperty(prDownloadArchiveProperty)

function prDownloadArchiveProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Perform this property to download the latest Main branch archive contained the Properties Ribbon from Git hub.")
	message("Download the latest Properties Ribbon scripts complex")
	return message
end

function prDownloadArchiveProperty:set_perform()
	openPath("https://github.com/outsidepro-arts/Properties_Ribbon/archive/main.zip")
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
parentLayout.osaraLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_OSARA_CONFIG"),
	"OSARA configuration"))
parentLayout.osaraLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_OSARA_ABOUT"),
	"About currently installed OSARA"))
if reaper.NamedCommandLookup("_OSARA_UPDATE") then
	parentLayout.osaraLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_OSARA_UPDATE"),
		"Check for OSARA updates"))
end

-- ReaPack actions
if parentLayout.reaPackLayout then
	parentLayout.reaPackLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup(
		"_REAPACK_BROWSE")))
	parentLayout.reaPackLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup(
		"_REAPACK_IMPORT")))
	parentLayout.reaPackLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup(
		"_REAPACK_MANAGE")))
	parentLayout.reaPackLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup(
		"_REAPACK_SYNC")))
	parentLayout.reaPackLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup(
		"_REAPACK_UPLOAD")))
	parentLayout.reaPackLayout:registerProperty(composeSimpleDialogOpenProperty(
		reaper.NamedCommandLookup("_REAPACK_ABOUT")
		, "About currently installed ReaPack"))
end

-- SWS actions
parentLayout.swsLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_BR_LOUDNESS_PREF")))
parentLayout.swsLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup(
	"_XENAKIOS_DISKSPACECALC")))
parentLayout.swsLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup(
	"_AUTORENDER_PREFERENCES")))
parentLayout.swsLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_SWS_ABOUT"),
	"About currently installed SWS extension"))
parentLayout.swsLayout:registerProperty(composeSimpleDialogOpenProperty(reaper.NamedCommandLookup("_BR_VERSION_CHECK")))

PropertiesRibbon.presentLayout(parentLayout)
