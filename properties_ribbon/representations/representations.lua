--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]]
--


-- Proposed humanbeing representations

local representation = {}
representation.db = setmetatable({},
	{
		__index = function(self, key)
			local shouldsilencePositive = false
			if key < 0 then
				key = -key
				shouldsilencePositive = true
			end
			local v = 0
			if key < 0.0000000298023223876953125 then
				key = "-inf"
			else
				v = math.log(key) * 8.6858896380650365530225783783321
				if v < -150 then
					key = "-inf"
				else
					key = math.round(v, 2)
				end
			end
			if not tonumber(key) then return key end
			local predb = string.format("%.2f", key):split(".")
			local udb, ddb = tonumber(predb[1]), tonumber(predb[2])
			local msg = ""
			if tonumber(key) < 0 then
				msg = msg .. "-"
				udb = -udb
			elseif tonumber(key) > 0 and shouldsilencePositive == false then
				msg = msg .. "+"
			end
			msg = msg .. string.format("%u", udb)
			if ddb > 0 then
				msg = msg .. string.format(" %u", ddb)
			end
			msg = msg .. " dB"
			return msg
		end
	})

representation.pan = setmetatable({},
	{
		__index = function(self, key)
			if key == 0 then
				return "center"
			elseif key > 0 then
				return string.format("%u%% right", math.round(key / (1 / 100), 0))
			elseif key < 0 then
				return string.format("%u%% left", math.round(-key / (1 / 100), 0))
			end
		end
	})

representation.timesec = setmetatable({},
	{
		__index = function(self, key)
			local pretime = string.format("%.3f", key):split(".")
			local s, ms = tonumber(pretime[1]), tonumber(pretime[2])
			local msg = ""
			if s == 0 and ms == 0 then
				return "0 seconds"
			end
			if s > 0 then
				msg = msg .. string.format("%u second%s, ", s, ({ [true] = "s", [false] = "" })[(s ~= 1)])
			end
			if ms > 0 then
				msg = msg .. string.format("%u millisecond%s", ms, ({ [true] = "s", [false] = "" })[(ms ~= 1)])
			else
				msg = msg:gsub(", ", "")
			end
			return msg
		end
	})

representation.pitch = setmetatable({
		[0.00] = "original"
	},
	{
		__index = function(self, key)
			local prepitch = string.format("%.2f", key):split(".")
			local s, c = tonumber(prepitch[1]), tonumber(prepitch[2])
			local msg = ""
			if tonumber(key) < 0 then
				msg = msg .. "Minus "
				s = -s
			end
			if s > 0 then
				msg = msg .. string.format("%u semitone%s, ", s, ({ [true] = "s", [false] = "" })[(s ~= 1)])
			end
			if c > 0 then
				msg = msg .. string.format("%u cent%s", c, ({ [true] = "s", [false] = "" })[(c ~= 1)])
			else
				msg = msg:gsub(", ", "")
			end
			return msg
		end
	})

representation.playrate = setmetatable({
	[1.000] = "original"
}, {
	__index = function(self, key)
		local preproc = tostring(key):split(".")
		local msg = tostring(preproc[1])
		if tonumber(preproc[2]) ~= 0 then
			msg = msg ..
				string.format(" %u",
					tonumber(tostring(math.round(tonumber("0." .. preproc[2]), 3)):match("^%d+[.](%d+)")))
		end
		msg = msg .. " X"
		return msg
	end
})

representation.tempo = setmetatable({}, {
	__index = function(self, tempo)
		local tempoLeft, tempoRight = string.format("%.3f", tempo):match("^(%d*)%.(%d*)")
		return table.concat({ tempoLeft, tonumber(tempoRight) > 0 and tempoRight or nil }, " "):join(" BPM")
	end
}
)

representation.pos = {
	[0] = setmetatable({}, {
		__index = function(self, pos)
			return function(getFunc)
				local data = getFunc(pos, 0)
				local form = {}
				local minute, second, fraction = string.match(data, "(%d*):(%d*)[.](%d*)")
				if tonumber(minute) > 0 then
					table.insert(form, string.format("%u minute%s", tonumber(minute), ({ [true] = "s", [false] = "" })[
					(tonumber(minute) ~= 1)]))
				end
				table.insert(form, string.format(" %u second%s", tonumber(second), ({ [true] = "s", [false] = "" })[
				(tonumber(second) ~= 1)]))
				if tonumber(fraction) > 0 then
					table.insert(form,
						string.format(" %u milli-second%s", tonumber(fraction),
							({ [true] = "s", [false] = "" })[(tonumber(fraction) ~= 1)]))
				end
				return table.concat(form, ", ")
			end
		end
	}),
	[1] = setmetatable({}, {
		__index = function(self, pos)
			return function(getFunc)
				local data = getFunc(pos, 1)
				local form = {}
				local measure, beat, fraction = string.match(data, "(%d+)[.](%d+)[.](%d+)")
				if tonumber(measure) > 0 then
					table.insert(form, string.format("%u measure", tonumber(measure)))
				end
				if tonumber(beat) > 0 then
					table.insert(form, string.format(" %u beat", tonumber(beat)))
				end
				if tonumber(fraction) > 0 then
					table.insert(form, string.format(" %u percent", tonumber(fraction)))
				end
				return table.concat(form, ", ")
			end
		end
	}),
	[2] = setmetatable({}, {
		__index = function(self, pos)
			return function(getFunc)
				local data = getFunc(pos, 2)
				local form = {}
				local measure, beat, fraction = string.match(data, "(%d+)[.](%d+)[.](%d+)")
				if tonumber(measure) > 0 then
					table.insert(form, string.format("%u measure", tonumber(measure)))
				end
				if tonumber(beat) > 0 then
					table.insert(form, string.format(" %u beat", tonumber(beat)))
				end
				if tonumber(fraction) > 0 then
					table.insert(form, string.format(" %u percent", tonumber(fraction)))
				end
				return table.concat(form, ", ")
			end
		end
	}),
	[3] = setmetatable({}, {
		__index = function(self, pos)
			return function(getFunc)
				local data = getFunc(pos, 3)
				return representation.timesec[data]
			end
		end
	}),
	[4] = setmetatable({}, {
		__index = function(self, pos)
			return function(getFunc)
				local data = getFunc(pos, 4)
				return string.format("%s samples", data)
			end
		end
	}),
	[5] = setmetatable({}, {
		__index = function(self, pos)
			return function(getFunc)
				local data = getFunc(pos, 5)
				local hours, minutes, seconds, fractions = string.match(data, "(%d*):(%d*):(%d*):(%d*)")
				local form = {}
				if tonumber(hours) > 0 then
					table.insert(form, string.format("%u hours", hours))
				end
				if tonumber(minutes) > 0 then
					table.insert(form, string.format("%u minutes", minutes))
				end
				table.insert(form, string.format("%u seconds", seconds))
				if tonumber(fractions) > 0 then
					table.insert(form, string.format("%u milliseconds", fractions))
				end
				return table.concat(form, ", ")
			end
		end
	})
}

representation.defpos = setmetatable({}, {
	__index = function(self, pos)
		-- OSARA uses the same method for current time formatting definition
		local tfDefinition = 2 -- we will always use the measures formatting by default
		if reaper.GetToggleCommandState(40365) == 1 then
			tfDefinition = 0
		elseif reaper.GetToggleCommandState(40368) == 1 then
			tfDefinition = 3
		elseif reaper.GetToggleCommandState(40369) == 1 then
			tfDefinition = 4
		elseif reaper.GetToggleCommandState(40370) == 1 then
			tfDefinition = 5
		end
		return representation.pos[tfDefinition][pos](function(pos, mode)
			return reaper.format_timestr_pos(pos, "", mode)
		end)
	end
})

-- This is the similar metatable but it calculates a lengths of.
representation.deflen = setmetatable({}, {
	__index = function(self, len)
		-- OSARA uses the same method for current time formatting definition
		local tfDefinition = 2 -- we will always use the measures formatting by default
		if reaper.GetToggleCommandState(40365) == 1 then
			tfDefinition = 0
		elseif reaper.GetToggleCommandState(40368) == 1 then
			tfDefinition = 3
		elseif reaper.GetToggleCommandState(40369) == 1 then
			tfDefinition = 4
		elseif reaper.GetToggleCommandState(40370) == 1 then
			tfDefinition = 5
		end
		return representation.pos[tfDefinition][len](function(len, mode)
			return reaper.format_timestr_len(len, "", 0.0, mode)
		end)
	end
})

function representation.getFocusLikeOSARA(context, opTrack)
	context = context or reaper.GetCursorContext()
	local contexts = {
		[0] = function()
			local tracks = opTrack or track_properties_macros.getTracks(config.getboolean("multiSelectionSupport", true))
			if not istable(tracks) then
				tracks = { tracks }
			end
			local msgCalculator = {}
			for _, track in ipairs(tracks) do
				local parts = {}
				do
					local trackPrefix = {}
					if reaper.GetTrackColor(track) ~= 0 then
						table.insert(trackPrefix, colors:getName(reaper.ColorFromNative(reaper.GetTrackColor(track))))
					end
					table.insert(trackPrefix,
						string.format("%u", reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")))
					local states = {
						[0] = "track",
						[1] = "folder",
						[2] = "end of folder",
						[3] = "end of %u folders"
					}
					local compactStates = {
						[0] = "opened",
						[1] = "small",
						[2] = "closed"
					}
					local state = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
					if state == 0 or state == 1 then
						if state == 1 then
							local compactState = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
							local nested = reaper.GetParentTrack(track) ~= nil
							table.insert(trackPrefix, compactStates[compactState])
							if nested then
								table.insert(trackPrefix, "nested")
							end
						end
						table.insert(trackPrefix, states[state])
					elseif state < 0 then
						state = -(state - 1)
						if state < 3 then
							table.insert(trackPrefix, states[state])
						else
							table.insert(trackPrefix, string.format(states[3], state - 1))
						end
					end
					if reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 then
						table.insert(trackPrefix, "muted")
					end
					if reaper.GetMediaTrackInfo_Value(track, "I_SOLO") > 0 then
						table.insert(trackPrefix, "soloed")
					end
					local trackName = select(2, reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false))
					if #trackName > 0 then
						table.insert(trackPrefix, trackName)
					end
					table.insert(parts, table.concat(trackPrefix, " "))
				end
				if reaper.CountTrackMediaItems(track) > 0 then
					table.insert(parts, string.format("%u item%s",
						reaper.CountTrackMediaItems(track),
						({ [true] = "", [false] = "s" })[reaper.CountTrackMediaItems(track) == 1]
					))
				end
				if reaper.TrackFX_GetCount(track) > 0 then
					local fxForm = {}
					for i = 0, reaper.TrackFX_GetCount(track) - 1 do
						local retval, fxName = reaper.TrackFX_GetFXName(track, i, "")
						if retval then
							if fxName:find(":") and fxName:find(": ") then
								local startPos = fxName:find(":") + 2
								local endPos = fxName:find("[(].+$")
								if endPos then
									endPos = endPos - 2
								end
								fxName = fxName:sub(startPos, endPos)
							end
						end
						table.insert(fxForm, fxName)
					end
					table.insert(parts, string.format("FX: %s", table.concat(fxForm, ", ")))
				end
				table.insert(msgCalculator, table.concat(parts, "; "))
			end
			return table.concat(msgCalculator, '.\n')
		end,
		[1] = function()
			local items = item_properties_macros.getItems(config.getboolean("multiSelectionSupport", true))
			if not istable(items) then
				items = { items }
			end
			local msgCalculator = {}
			for _, item in ipairs(items) do
				local parts = {}
				do
					local takePrefix = {}
					if reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_CUSTOMCOLOR") ~= 0 then
						table.insert(takePrefix,
							colors:getName(
								reaper.ColorFromNative(
									reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_CUSTOMCOLOR")
								)
							)
						)
					end
					table.insert(takePrefix, item_properties_macros.getTakeNumber(item))
					if reaper.GetSetMediaItemTakeInfo_String(reaper.GetActiveTake(item), "P_NAME", "", false) then
						table.insert(takePrefix,
							select(2,
								reaper.GetSetMediaItemTakeInfo_String(reaper.GetActiveTake(item), "P_NAME", "", false)))
					end
					table.insert(parts, table.concat(takePrefix, " "))
				end
				if reaper.TakeFX_GetCount(reaper.GetActiveTake(item)) > 0 then
					local fxForm = {}
					for i = 0, reaper.TakeFX_GetCount(reaper.GetActiveTake(item)) - 1 do
						local retval, fxName = reaper.TakeFX_GetFXName(reaper.GetactiveTake(item), i, "")
						if retval then
							if fxName:find(":") and fxName:find(": ") then
								local startPos = fxName:find(":") + 2
								local endPos = fxName:find("[(].+$")
								if endPos then
									endPos = endPos - 2
								end
								fxName = fxName:sub(startPos, endPos)
							end
						end
						table.insert(fxForm, fxName)
					end
					table.insert(parts, string.format("FX: %s", table.concat(fxForm, ", ")))
				end
				table.insert(msgCalculator, table.concat(parts, "; "))
			end
			return table.concat(msgCalculator, '.\n')
		end
	}
	return contexts[context]()
end

return representation
