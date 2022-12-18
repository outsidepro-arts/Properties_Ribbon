--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]] --


package.path = select(2, reaper.get_action_context()):match('^.+[\\//]') .. "?//init.lua"

require "properties_ribbon"

if config.getboolean("automaticLayoutLoading", false) == true then
	proposedLayout = proposeLayout()
end

if script_init(proposedLayout) then
	script_reportOrGotoProperty(9)
end
