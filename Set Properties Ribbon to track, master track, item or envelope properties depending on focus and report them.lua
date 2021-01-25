--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts
License: MIT License
]]--


reaper.Undo_BeginBlock()
package.path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')..'engine\\' .. "?.lua"
require "properties_ribbon"

context = reaper.GetCursorContext()
if context == 0 then
if reaper.IsTrackSelected(reaper.GetMasterTrack()) then
contextLayout = "mastertrack_properties"
else
contextLayout = "track_properties"
end
elseif context == 1 then
contextLayout = "item_properties"
elseif context == 2 then
contextLayout = "envelope_properties"
end

if script_init(contextLayout) then
reaper.osara_outputMessage(script_reportOrGotoProperty())
script_finish()
end

reaper.Undo_EndBlock(g_undoState, -1)