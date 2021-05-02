--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts
License: MIT License
]]--


reaper.Undo_BeginBlock()
package.path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')..'engine\\' .. "?.lua"
require "properties_ribbon"

if script_init() then
script_ajustProperty()
script_finish()
end
reaper.Undo_EndBlock(g_undoState, -1)