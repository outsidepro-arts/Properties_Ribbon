--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2024 outsidepro-arts
License: MIT License
]]
--

-- REAPER hack to prevent useless undo points creation
reaper.defer(function() end)

contextualActions = setmetatable({
	[0] = {
		"_RS281e717ec90e00117f1fabe94e66cab67483b46a",
		"_RS4c1bcc02859b102d0c590b483d8a454ffb12bcd1"
	},
	[1] = {
		"_RS494478b1fa52f40e1d43ada25d538334f069b0d0"
	},
	[2] = {
		"_RSf75f25d3f38202cfab9a2ebc54a87c7bb04c1916"
	}
}, {
	__index = function(self)
		return self[0]
	end
})

definedAction = contextualActions[0][(reaper.GetMasterTrackVisibility() & 1) == 1 and 2 or 1]

if reaper.GetCursorContext() == 2 or reaper.CountTracks(0) > 0 then
	definedAction = contextualActions[reaper.GetCursorContext()]
	[(reaper.GetCursorContext() == 0 and reaper.GetLastTouchedTrack() == reaper.GetMasterTrack(0)) and 2 or 1]
else
	reaper.SetOnlyTrackSelected(reaper.GetMasterTrack(0), true)
	reaper.SetCursorContext(0)
end

reaper.Main_OnCommand(
	reaper.NamedCommandLookup(definedAction), 0)
