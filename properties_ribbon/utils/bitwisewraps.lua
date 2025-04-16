local bitwise = {}

---Returns the state of specified bit
---@param value number The value where a bit should be checked
---@param bit number The bit which needs to get
---@return boolean true if the bit is set
function bitwise.getBit(value, bit)
	return value & (1 << bit) ~= 0
end

---Extracts the value in the range of specified bits
---@param value number the value the range should be extracted
---@param bstart number the start of range in bits
---@param bend number the end of range in bits
---@return number extracted value in specified range
function bitwise.getRange(value, bstart, bend)
	return ((value & ((1 << bend) - 1)) >> (bstart - 1))
end

---Extract the value till the specified bit
---@param value number the value the range should be extracted
---@param bdivider number the divider bit
---@return number extracted value
function bitwise.getTo(value, bdivider)
	return value & ((1 << bdivider) - 1)
end

---Extract the data starting from the specified bit
---@param value number the value the range should be extracted
---@param bdivider number The divider bit
---@return number extracted value
function bitwise.getFrom(value, bdivider)
	return value >> bdivider
end

---Sets the state of specified bit
---@param value number The value where a bit should be set
---@param bit number The bit which needs to be set
---@param state boolean The state of the bit
---@return number updated value
function bitwise.setBit(value, bit, state)
	local mask = (1 << bit)
	return value | (state == true and mask or 0)
end

---Sets the value in the range of specified bits
---@param value number The value where the range should be set
---@param bstart number The start of range
---@param bend number The end of range
---@param newValue number The new value
---@return number updated value
function bitwise.setRange(value, bstart, bend, newValue)
	return value & ~(((1 << bend) - 1) << (bstart - 1)) | (newValue << (bstart - 1))
end

---Sets the data till the specified bit
---@param value number The value where the range should be set
---@param bdivider number The divider bit of the range
---@param newValue number The new value
---@return number updated value
function bitwise.setTo(value, bdivider, newValue)
	return value & ~((1 << bdivider) - 1) | (newValue & ((1 << bdivider) - 1))
end

---Sets the data starting from the specified bit
---@param value number The value where the range should be set
---@param bdivider number The divider bit
---@param newValue number The new value
---@return number updated value
function bitwise.setFrom(value, bdivider, newValue)
	return value & ~(((1 << bdivider) - 1)) | (newValue << (bdivider - 1))
end

---Concatenates a bunch of values with specified divider
---@param bdivider number The divider bit
---@param ...? number The values which should be concatenated. If one of values is nil, this position will be set as 0.
---@return number concatenated value
function bitwise.concat(bdivider, ...)
	local newValue = 0
	local shift = 0
	for _, value in ipairs({ ... }) do
		if value then
			newValue = newValue | (value << shift)
		end
		shift = shift + bdivider
	end
	return newValue
end

---Returns the specified amount of part divided by specified bit.
---@param value number The value which should be processed
---@param bdivider number the bit divider
---@param parts number the amount of parts which should be returned
---@return ... number the parts which has been specified. The last part is all part of variable on the right.
function bitwise.getParts(value, bdivider, parts)
	local parr = {}
	local startShift = 0
	for i = 1, parts do
		local endShift = startShift + bdivider
		if i == parts then
			parr[i] = bitwise.getFrom(value, startShift - 1)
		else
			parr[i] = bitwise.getRange(value, startShift + 1, endShift)
		end
		startShift = endShift + 1
	end
	return table.unpack(parr)
end

return bitwise
