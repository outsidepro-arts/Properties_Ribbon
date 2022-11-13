--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]] --


package.path = ({ reaper.get_action_context() })[2]:match('^.+[\\//]') .. 'engine//?.lua'
require "properties_ribbon"

if script_init({ section = "properties", layout = "fx_properties" }, true) then
	script_reportOrGotoProperty()
end
