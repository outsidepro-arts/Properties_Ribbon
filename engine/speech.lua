--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]] --

-- This module implements main speech output method. It can provide both OSARA output use and an alternative speech output engine.
-- As alternative speech output engine the Tolk library might used.
-- You may download the tolk binding for Lua at https://github.com/outsidepro-arts/Tolk4Lua/
-- This module obeys the config setting and proposes needed speech output methods for Properties Ribbon.

local tolk
local speech = {}

speech.availableOutputs = {}

if reaper.APIExists("osara_outputMessage") then
	table.insert(speech.availableOutputs,
	{
		label="OSARA output",
		init = function () return true end,
		isLoaded = function () return true end,
		output = function (str) reaper.osara_outputMessage(str) end
	})
end

if reaper.file_exists(package.cpath:gsub("?", "tolklua")) then
	table.insert(speech.availableOutputs, {
		label = "Tolk library",
		init = function ()
			tolk = require "tolklua"
			return tolk ~= nil
		end,
		isLoaded = function ()
			return tolk ~= nil
		end,
		output = function (str)
			return tolk.output(str, true)
		end
	})
end

local function initSpeech()
	return speech.availableOutputs[config.getinteger("speechEngine", 1)].init()
end

local function isLoaded()
	return speech.availableOutputs[config.getinteger("speechEngine", 1)].isLoaded()
end

function speech.output(str)
	if not isLoaded() then
		initSpeech()
	end
	return speech.availableOutputs[config.getinteger("speechEngine", 1)].output(str)
end

return speech