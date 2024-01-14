--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2024 outsidepro-arts
License: MIT License

----------
]]
--


-- This file contains a macros for specified solutions. Use this macros at own properties.

colorPresets = {}

function colorPresets.init(obj)
	local presets = setmetatable({
		__obj = obj
	}, {
		__index = function(self, idx)
			if isnumber(idx) then
				local name, value = extstate[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", idx), "name")],
								extstate[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", idx), "value")]
				if name and value then
					return {
						name = name,
						value = value
					}
				end
			end
		end,
		__newindex = function(self, idx, preset)
			if preset then
				extstate._forever[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", idx), "name")] = assert(
								preset.name, "Expected table field 'name'")
				extstate._forever[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", idx), "value")] = assert(
								preset.value, "Expected table field 'value'")
			else
				local i = idx
				while extstate[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", i), "value")] do
					if i == idx then
						extstate._forever[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", i), "name")] = nil
						extstate._forever[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", i), "value")] = nil
					elseif i > idx then
						extstate._forever[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", i - 1), "name")] =
										extstate[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", i), "name")]
						extstate._forever[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", i), "name")] = nil
						extstate._forever[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", i - 1), "value")] =
										extstate[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", i), "value")]
						extstate._forever[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", i), "value")] = nil
					end
					i = i + 1
				end
			end
		end,
		__len = function(self)
			local mCount = 0
			while extstate[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", mCount + 1), "value")] and
							extstate[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", mCount + 1), "name")] do
				mCount = mCount + 1
			end
			return mCount
		end,
		__ipairs = function(self)
			local lambda = function(obj, idx)
				if extstate[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", idx + 1), "name")] and
								extstate[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", idx + 1), "value")] then
					return idx + 1, {
						name = extstate[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", idx + 1), "name")],
						value = extstate[utils.makeKeySequence("colorpresets", self.__obj, string.format("preset%u", idx + 1), "value")]
					}
				end
			end
			return self, lambda, 1
		end
	})
	return presets
end

