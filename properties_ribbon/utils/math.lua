--[[
	Rounds given number
	parameters:
	num (number): the number which should be rounded
	numDecimalPlaces (number): the decimal digits amount which by should be rounded
	returns a rounded number value.
]] --
function math.round(num, numDecimalPlaces)
	local negative = false
	if num < 0 then
		negative = true
		num = -num
	end
	local mult = 10 ^ (numDecimalPlaces or 0)
	if negative == true then
		return -math.floor(num * mult + 0.5) / mult
	else
		return math.floor(num * mult + 0.5) / mult
	end
end

