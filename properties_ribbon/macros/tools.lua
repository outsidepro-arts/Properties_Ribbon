---composes the three-position setter property
---@param obj any
---@param minRootMax table
---|"'min'" # the value which should be set when user decreases the setter
---"'root'" # the value which should be set when user performs the setter
---|"'max'" # the value which should be set when user increases the setter
---@param setMessages string
---"true" # the message when obj is a table
---"false" # the message when obj is not a table
---@param setValueFunc function
---@param checkAbilityFunc function
---@return table
function composeThreePositionProperty(obj, minRootMax, setMessages, setValueFunc, checkAbilityFunc)
	checkAbilityFunc = checkAbilityFunc or function()
		return true
	end
	local t = {
		get = function(self, parent)
			local message = initOutputMessage()
			message:initType(
				"Adjust and perform this three-state setter to set the needed value specified in parentheses.")
			message("three-position setter")
			if not istable(obj) then
				if not checkAbilityFunc(obj) then
					message:addType(
						" This property is unavailable now because this object reports that it cannot be changed.", 1)
					message:changeType("Unavailable", 2)
					return message
				end
			end
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
					if checkAbilityFunc(o) then
						setValueFunc(o, vls[direction])
					end
				end
			else
				if checkAbilityFunc(obj) then
					setValueFunc(obj, vls[direction])
				else
					return false, "This property is unavailable for this object"
				end
			end
			return true, message, true
		end,
		set_perform = function(self, parent)
			local message = initOutputMessage()
			local state = minRootMax.rootmean
			message(string.format(setMessages[istable(obj)], minRootMax.representation[state]))
			if istable(obj) then
				for _, o in ipairs(obj) do
					if checkAbilityFunc(o) then
						setValueFunc(o, state)
					end
				end
			else
				if checkAbilityFunc(obj) then
					setValueFunc(obj, state)
				else
					return false, "This property is unavailable for this object"
				end
			end
			return true, message, true
		end
	}
	return t
end
