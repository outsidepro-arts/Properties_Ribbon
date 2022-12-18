--[[
	Converts any value to boolean
	Parameters:
	@param value (any): the value which should be converted
	@return A boolean value based on passed parameter
]]
function toboolean(value)
	if type(value) == "string" then
		if value:lower() == "true" or value:lower() == "false" then
			return ({ ["false"] = false, ["true"] = true })[value]
		else
			return #value > 0
		end
	elseif type(value) == "number" then
		return (value > 0)
	else
		return value ~= nil
	end
end

--[[
	Converts the passed value to opposite value
	Parameters:
	@param state (number or boolean): the value which should be converted
	@return an opposite value of passed
]]
function nor(state)
	if type(state) =="number" then
		if state <= 1 then
			state = state ~ 1
		end
	elseif type(state) =="boolean" then
		if state == true then
			state = false
		elseif state == false then
			state = true
		end
	end
	return state
end
