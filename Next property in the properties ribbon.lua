--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]] --


package.path = select(2, reaper.get_action_context()):match('^.+[\\//]') .. 'engine//?.lua'
require "properties_ribbon"

local proposedLayout
if config.getboolean("automaticLayoutLoading", false) == true then
	proposedLayout = proposeLayout()
end
if script_init(proposedLayout) then
	script_nextProperty()
end
