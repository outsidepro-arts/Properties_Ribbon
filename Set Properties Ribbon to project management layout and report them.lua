--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]] --


package.path = select(2, reaper.get_action_context()):match('^.+[\\//]') .. 'engine//?.lua'
require "properties_ribbon"

-- We have to execute all Properties Ribbon actions  through defer. We need to do this to prevent REAPER create useless undo points.
-- Yeah, it is  dirty hack, but all ReaScripters do the same untill Cockos provides a special API method to prevent it normaly.
reaper.defer(function ()
	if script_init({ section = "actions", layout = "project_management_actions" }, true) then
		script_reportOrGotoProperty()
	end
end)
