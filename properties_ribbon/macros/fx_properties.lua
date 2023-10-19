--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License

----------
]]
--


-- This file contains a macros for specified solutions. Use this macros at own properties.

fx_properties_macros = {}

---Initializes the contextual API instance
---@return table When you're using the FX API methods which have the TrackFX_ or TakeFX_ prefix through this table, you don't have to call them with these prefixes. This metatable does it itself relating on REAPER cursor context.
function fx_properties_macros.newContextualAPI()
	local capi = setmetatable({
		_context = 0,
		_contextObj = setmetatable({}, {
			-- REAPER generates error when media item is nil so we have to wrap these handles to metatable
			__index = function(self, key)
				if key == 0 then
					local lastTouched = reaper.GetLastTouchedTrack()
					if lastTouched then
						return lastTouched
					else
						if (reaper.GetMasterTrackVisibility() & 1) == 1 then
							return reaper.GetMasterTrack(0)
						end
					end
				elseif key == 1 then
					if reaper.GetSelectedMediaItem(0, 0) then
						return reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, 0))
					end
					return nil
				end
			end
		}),
		_contextPrefix = {
			[0] = "TrackFX_",
			[1] = "TakeFX_"
		}
	}, {
		__index = function(self, key)
			return function(...)
				if reaper.APIExists(self._contextPrefix[self._context] .. key) then
					return reaper[self._contextPrefix[self._context] .. key](self._contextObj[self._context], ...)
				else
					if self._context == 0 and key:find("Envelope") then
						if reaper[key] then
							return reaper[key](self._contextObj[self._context], ...)
						end
					end
					error(string.format("Contextual API wasn't found method %s",
						self._contextPrefix[self._context] .. key))
				end
			end
		end
	})
	return capi
end

fx_properties_macros.fxMaskList = setmetatable({}, {
	__index = function(self, idx)
		if isnumber(idx) then
			local fxMask = extstate[string.format("fx_properties.excludeMask%u.fx", idx)]
			local parmMask = extstate[string.format("fx_properties.excludeMask%u.param", idx)]
			return { ["fxMask"] = fxMask,["paramMask"] = parmMask }
		end
		error(string.format("Expected key type %s (got %s)", type(1), type(idx)))
	end,
	__newindex = function(self, idx, maskTable)
		if maskTable then
			assert(istable(maskTable), string.format("Expected key type %s (got %s)", type({}), type(maskTable)))
			assert(maskTable.fxMask, "Expected field fxMask")
			assert(maskTable.paramMask, "Expected field paramMask")
			extstate._forever[string.format("fx_properties.excludeMask%u.fx", idx)] = maskTable.fxMask
			extstate._forever[string.format("fx_properties.excludeMask%u.param", idx)] = maskTable.paramMask
		else
			local i = idx
			while extstate[string.format("fx_properties.excludeMask%u.fx", i)] do
				if i == idx then
					extstate._forever[string.format("fx_properties.excludeMask%u.fx", i)] = nil
					extstate._forever[string.format("fx_properties.excludeMask%u.param", i)] = nil
				elseif i > idx then
					extstate._forever[string.format("fx_properties.excludeMask%u.fx", i - 1)] = extstate._layout[
					string.format("excludeMask%u.fx", i)]
					extstate._forever[string.format("fx_properties.excludeMask%u.param", i - 1)] = extstate._layout[
					string.format("excludeMask%u.param", i)]
					extstate._forever[string.format("fx_properties.excludeMask%u.fx", i)] = nil
					extstate._forever[string.format("fx_properties.excludeMask%u.param", i)] = nil
				end
				i = i + 1
			end
		end
	end,
	__len = function(self)
		local mCount = 0
		while extstate[string.format("fx_properties.excludeMask%u.fx", mCount + 1)] do
			mCount = mCount + 1
		end
		return mCount
	end
})

-- Steps list for adjusting (will be defined using configuration)
fx_properties_macros.stepsList = {
	{ label = "smallest", value = 0.000001 }, -- less smallest step causes the REAPER freezes
	{ label = "small",    value = 0.00001 },
	{ label = "medium",   value = 0.0001 },
	{ label = "big",      value = 0.001 },
	{ label = "biggest",  value = 0.01 },
	{ label = "huge",     value = 0.1 }
}

