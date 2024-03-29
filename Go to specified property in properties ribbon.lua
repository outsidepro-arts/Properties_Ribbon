--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2024 outsidepro-arts
License: MIT License
]] --


package.path = select(2, reaper.get_action_context()):match('^.+[\\//]') .. "?//init.lua"

require "properties_ribbon"

if PropertiesRibbon.initLastLayout() then
	PropertiesRibbon.activateGotoMode()
end
