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

-- Compose the envelopes control property
-- Since REAPER has no some envelopes activating standard way, here will two functions to compose this.
composeEnvelopeControlProperty = {}

---Composes the envelope control property using chunk name. This is the standard way to get basic envelopes state.
---@param obj userdata|table The object where we are working
---@param envChunks string the envelope chunk names separated by coma.
---@param getfromFunc function(obj) the function which presents the way to get the envelope per one object
---@return table the ready property to register via registerProperty method.
function composeEnvelopeControlProperty.viaChunk(obj, envChunks, getfromFunc)
	local t = {}
	t.states = envChunks and envChunks:split(",", true)
	t.getValue = function(track, envName)
		local env = getfromFunc(track, envName)
		if not isuserdata(env) then
			error("Cannot get the envelope.", 2)
		end
		local active = select(2, reaper.GetSetEnvelopeInfo_String(env, "ACTIVE", "", false))
		local visible = select(2, reaper.GetSetEnvelopeInfo_String(env, "VISIBLE", "", false))
		if active == "0" then
			return 1, env
		elseif visible == "1" then
			return 2, env
		else
			return 3, env
		end
	end
	t.actions = { "Activate", "Hide", "Show" }
	t.get = function(self, parent)
		local message = initOutputMessage()
		message:initType(
			(envChunks and "Adjust this property to choose the needed  envelope type." or
				"") ..
			"Perform this property to perform the available action on" .. (envChunks == nil and " this envelope" or
				"") .. ".")
		if multiSelectionSupport == true then
			message:addType(
				" If the group of tracks or items has been selected, the envelope state will be set to oposite value depending of moreness elements with the same value.",
				1)
		end
		local selectedEnvelope = envChunks and
			(extstate._layout[string.format("%sEnvelopeType", parent:get().label:lower())] or 1)
		if istable(obj) then
			local _, env = self.getValue(obj[1], selectedEnvelope and self.states[selectedEnvelope])
			local state = utils.getMostFrequent(obj, function(o)
				return select(1, self.getValue(o, selectedEnvelope and self.states[selectedEnvelope]))
			end)
			local _, name = reaper.GetEnvelopeName(env)
			message(string.format("%s the %s envelope for %u selected elements", self.actions[state], name, #obj))
		else
			local state, env = self.getValue(obj, selectedEnvelope and self.states[selectedEnvelope])
			local _, name = reaper.GetEnvelopeName(env)
			message(string.format("%s the %s envelope", self.actions[state], name))
		end
		return message
	end
	if envChunks then
		t.set_adjust = function(self, parent, direction)
			local message = initOutputMessage()
			local state = extstate._layout[string.format("%sEnvelopeType", parent:get().label:lower())] or 1
			if self.states[state + direction] then
				extstate._layout[string.format("%sEnvelopeType", parent:get().label:lower())] = state + direction
			else
				message(string.format("No %s property values.", (direction == 1) and "next" or "previous"))
			end
			message(self:get(parent))
			return false, message
		end
	end
	t.set_perform = function(self, parent)
		local selectedEnvelope = envChunks and
			(extstate._layout[string.format("%sEnvelopeType", parent:get().label:lower())] or 1)
		if istable(obj) then
			local successCount = 0
			local action = utils.getMostFrequent(obj, function(o)
				return select(1, self.getValue(o, selectedEnvelope and self.states[selectedEnvelope]))
			end)
			local message = initOutputMessage()
			for _, o in ipairs(obj) do
				local _, envelope = self.getValue(o, selectedEnvelope and self.states[selectedEnvelope])
				if action == 1 then
					if reaper.GetSetEnvelopeInfo_String(envelope, "ACTIVE", "1", true) then
						successCount = successCount + 1
					end
				elseif action == 2 then
					if reaper.GetSetEnvelopeInfo_String(envelope, "VISIBLE", "0", true) then
						successCount = successCount + 1
					end
				elseif action == 3 then
					if reaper.GetSetEnvelopeInfo_String(envelope, "VISIBLE", "1", true) then
						successCount = successCount + 1
					end
				end
			end
			if action == 1 then
				return true, string.format("Activated for %u selected elements", successCount)
			elseif action == 2 then
				return true, string.format("Hid for %u selected elements", successCount)
			else
				return true, string.format("Shown for %u selected elements", successCount)
			end
		else
			local action, envelope = self.getValue(obj, selectedEnvelope and self.states[selectedEnvelope])
			local _, name = reaper.GetEnvelopeName(envelope)
			if action == 1 then
				if reaper.GetSetEnvelopeInfo_String(envelope, "ACTIVE", "1", true) then
					return true, string.format("The %s envelope activated", name)
				else
					return false, string.format("Failed to activate the %s envelope.", name)
				end
			elseif action == 2 then
				if reaper.GetSetEnvelopeInfo_String(envelope, "VISIBLE", "0", true) then
					return true, string.format("The %s envelope hidden", name)
				else
					return false, string.format("Failed to hide the %s envelope.", name)
				end
			elseif action == 3 then
				if reaper.GetSetEnvelopeInfo_String(envelope, "VISIBLE", "1", true) then
					return true, string.format("The %s envelope showed", name)
				else
					return false, string.format("Failed to show the %s envelope.", name)
				end
			end
		end
	end
	return t
end

---Composes the envelope control property using its name and command to work with. This is the rough hack.
---@param obj userdata|table The object where we are working
---@param names string the envelope full name or names separated by coma.
---@param getfromFunc function(obj) the function which presents the way to get the envelope per one object
---@param commands number|[number] the commands to activate the envelopes.	
---@return table the ready property to register via registerProperty method.
function composeEnvelopeControlProperty.viaCommand(obj, names, getfromFunc, commands)
	local t = {}
	t.states = names and names:split(",", true)
	t.getValue = function(track, envName)
		local env = getfromFunc(track, envName)
		if not isuserdata(env) then
			return 0
		end
		local active = select(2, reaper.GetSetEnvelopeInfo_String(env, "ACTIVE", "", false))
		local visible = select(2, reaper.GetSetEnvelopeInfo_String(env, "VISIBLE", "", false))
		if active == "0" then
			return 1, env
		elseif visible == "1" then
			return 2, env
		else
			return 3, env
		end
	end
	t.actions = { "Activate", "Hide", "Show" }
	t.get = function(self, parent)
		local message = initOutputMessage()
		message:initType(
			(names and "Adjust this property to choose the needed  envelope type." or
				"") ..
			"Perform this property to perform the available action on" .. (names == nil and " this envelope" or
				"") .. ".")
		if multiSelectionSupport == true then
			message:addType(
				" If the group of tracks or items has been selected, the envelope state will be set to oposite value depending of moreness elements with the same value.",
				1)
		end
		local selectedEnvelope = names and
			(extstate._layout[string.format("%sEnvelopeType", parent:get().label:lower())] or 1)
		if istable(obj) then
			local _, env = self.getValue(obj[1], selectedEnvelope and self.states[selectedEnvelope])
			local state = utils.getMostFrequent(obj, function(o)
				return select(1, self.getValue(o, selectedEnvelope and self.states[selectedEnvelope]))
			end)
			local name
			if env then
				name = select(2, reaper.GetEnvelopeName(env))
			else
				state = 1
				name = #self.states > 1 and self.states[selectedEnvelope] or names
			end
			message(string.format("%s the %s envelope for %u selected elements", self.actions[state], name, #obj))
		else
			local state, env = self.getValue(obj, selectedEnvelope and self.states[selectedEnvelope])
			local name
			if env then
				name = select(2, reaper.GetEnvelopeName(env))
			else
				state = 1
				name = #self.states > 1 and self.states[selectedEnvelope] or names
			end
			message(string.format("%s the %s envelope", self.actions[state], name))
		end
		return message
	end
	if t.states and #t.states > 1 then
		t.set_adjust = function(self, parent, direction)
			local message = initOutputMessage()
			local state = extstate._layout[string.format("%sEnvelopeType", parent:get().label:lower())] or 1
			if self.states[state + direction] then
				extstate._layout[string.format("%sEnvelopeType", parent:get().label:lower())] = state + direction
			else
				message(string.format("No %s property values.", (direction == 1) and "next" or "previous"))
			end
			message(self:get(parent))
			return false, message
		end
	end
	t.set_perform = function(self, parent)
		local selectedEnvelope = names and
			(extstate._layout[string.format("%sEnvelopeType", parent:get().label:lower())] or 1)
		if istable(obj) then
			local successCount = 0
			local action = utils.getMostFrequent(obj, function(o)
				return select(1, self.getValue(o, selectedEnvelope and self.states[selectedEnvelope]))
			end)
			if action == 0 then
				return false,
					"Cannot activate the envelope: this envelope is non-standard, so it cannot be activate per group of selected elements. Please activate this per every element you need manualy."
			end
			for _, o in ipairs(obj) do
				local _, envelope = self.getValue(o, selectedEnvelope and self.states[selectedEnvelope])
				if action == 2 then
					if reaper.GetSetEnvelopeInfo_String(envelope, "VISIBLE", "0", true) then
						successCount = successCount + 1
					end
				elseif action == 3 then
					if reaper.GetSetEnvelopeInfo_String(envelope, "VISIBLE", "1", true) then
						successCount = successCount + 1
					end
				end
			end
			if action == 1 then
				return true, string.format("Activated for %u selected elements", successCount)
			elseif action == 2 then
				return true, string.format("Hid for %u selected elements", successCount)
			else
				return true, string.format("Shown for %u selected elements", successCount)
			end
		else
			local action, envelope = self.getValue(obj, selectedEnvelope and self.states[selectedEnvelope])
			local _, name = reaper.GetEnvelopeName(envelope)
			if action == 0 then
				reaper.Main_OnCommand(istable(commands) and commands[selectedEnvelope] or commands, 0)
				if self.getValue(obj, selectedEnvelope and self.states[selectedEnvelope]) == 2 then
					return true, string.format("The %s envelope activated", name)
				else
					return true, string.format("Failed to activate the %s envelope.", name), true
				end
			elseif action == 2 then
				if reaper.GetSetEnvelopeInfo_String(envelope, "VISIBLE", "0", true) then
					return true, string.format("The %s envelope hidden", name)
				else
					return true, string.format("Failed to hide the %s envelope.", name), true
				end
			elseif action == 3 then
				if reaper.GetSetEnvelopeInfo_String(envelope, "VISIBLE", "1", true) then
					return true, string.format("The %s envelope showed", name)
				else
					return true, string.format("Failed to show the %s envelope.", name), true
				end
			end
		end
	end
	return t
end
