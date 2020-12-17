--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020 outsidepro-arts
License: MIT License
]]--


reaper.Undo_BeginBlock()
package.path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')..'engine\\' .. "?.lua"
require "properties_ribbon"
lastLayout = extstate.get("currentLayout")
context = reaper.GetCursorContext()
if context == 0 then
if reaper.IsTrackSelected(reaper.GetMasterTrack()) then
extState = "mastertrack_properties"
else
extState = "track_properties"
end
elseif context == 1 then
extState = "item_properties"
elseif context == 2 then
extState = "envelope_properties"
end
if lastLayout == extState then
shouldSwitch = true
else
extstate.set("currentLayout", extState)
extstate.set("speakLayout", tostring(true))
end
if script_init() then
local message = initOutputMessage()
if shouldSwitch == true then
message(script_switchSublayout())
end
message(script_reportOrGotoProperty())
reaper.osara_outputMessage(tostring(message))
script_finish()
end

reaper.Undo_EndBlock(g_undoState, -1)