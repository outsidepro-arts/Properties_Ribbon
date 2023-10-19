--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]]
--

contextualActions = {
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
}

reaper.Main_OnCommand(
	reaper.NamedCommandLookup(contextualActions[reaper.GetCursorContext()]
		[(reaper.GetCursorContext() == 0 and reaper.GetLastTouchedTrack() == reaper.GetMasterTrack(0)) and 2 or 1]), 0)
