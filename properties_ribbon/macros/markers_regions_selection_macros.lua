--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2024 outsidepro-arts
License: MIT License

----------
]]
--


-- This file contains a macros for specified solutions. Use this macros at own properties.


markers_regions_selection_macros = {}

---Is any time selection set?
---@return boolean
function markers_regions_selection_macros.isTimeSelectionSet()
	local selectionStart, selectionEnd = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
	return (selectionStart ~= 0 or selectionEnd ~= 0)
end

---Is loop points set?
---@return boolean
function markers_regions_selection_macros.isLoopSet()
	local loopStart, loopEnd = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false)
	return (loopStart ~= 0 or loopEnd ~= 0)
end
