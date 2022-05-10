--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]]--


reaper.Undo_BeginBlock()
package.path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')..'engine//?.lua'
require "properties_ribbon"

if script_init({section="embedded", layout="color_composer"}, true) then
script_reportOrGotoProperty()
end
reaper.Undo_EndBlock(g_undoState, -1)