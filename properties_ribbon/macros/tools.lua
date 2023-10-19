---composes the three-position setter property
---@param obj any
---@param minRootMax any
---|"'min'" # the value which should be set when user decreases the setter
---"'root'" # the value which should be set when user performs the setter
---|"'max'" # the value which should be set when user increases the setter
---@param setMessages string
---"true" # the message when obj is a table
---"false" # the message when obj is not a table
---@param setValueFunc function
---@return table
function composeThreePositionProperty(obj, minRootMax, setMessages, setValueFunc)
	local t = {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType(
				"Adjust and perform this three-state setter to set the needed value specified in parentheses.")
			message("three-position setter")
			message(string.format(" (%s - %s, ", actions.set.decrease.label, minRootMax.representation[minRootMax.min]))
			message(string.format("%s - %s, ", actions.set.perform.label, minRootMax.representation[minRootMax.rootmean]))
			message(string.format("%s - %s)", actions.set.increase.label, minRootMax.representation[minRootMax.max]))
			return message
		end,
		set_adjust = function(self, parent, direction)
			local message = initOutputMessage()
			local vls = {
				[actions.set.decrease.direction] = minRootMax.min,
				[actions.set.increase.direction] = minRootMax.max
			}
			message(string.format(setMessages[istable(obj)], minRootMax.representation[vls[direction]]))
			if istable(obj) then
				for _, o in ipairs(obj) do
					setValueFunc(o, vls[direction])
				end
			else
				setValueFunc(obj, vls[direction])
			end
			return true, message
		end,
		set_perform = function(self, parent)
			local message = initOutputMessage()
			local state = minRootMax.rootmean
			message(string.format(setMessages[istable(obj)], minRootMax.representation[state]))
			if istable(obj) then
				for _, o in ipairs(obj) do
					setValueFunc(o, state)
				end
			else
				setValueFunc(obj, state)
			end
			return true, message
		end
	}
	return t
end


