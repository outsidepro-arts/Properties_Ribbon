--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020 outsidepro-arts
License: MIT License
]]--

reaper.Undo_BeginBlock()

package.path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')..'engine\\' .. "?.lua"
require "properties_ribbon"

if script_init() then
local message = initOutputMessage()
message(script_switchSublayout(true))
message(script_reportOrGotoProperty())
reaper.osara_outputMessage(tostring(message))
script_finish()
end

reaper.Undo_EndBlock(g_undoState, -1)