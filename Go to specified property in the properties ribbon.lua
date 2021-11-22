--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts
License: MIT License
]]--


reaper.Undo_BeginBlock()
package.path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')..'engine\\' .. "?.lua"
require "properties_ribbon"

if script_init() then
local lastQuery = extstate.lastPropertynumQuery or ""
local retval, answer = reaper.GetUserInputs("Go to property", 1, "Type the specified property number:", lastQuery)
if retval then
if tonumber(answer) == nil then
reaper.ShowMessageBox("Please type a numeric value.", "Properties Ribbon error", 0)
return
end
if tonumber(answer) > #layout.properties then
reaper.ShowMessageBox("There is no such properties.", "PropertiesRibbon error", 0)
return
end
 script_reportOrGotoProperty(tonumber(answer))
 extstate.lastPropertynumQuery = answer
 end
end
reaper.Undo_EndBlock(g_undoState, -1)