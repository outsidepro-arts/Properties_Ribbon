function ipairswith(t, step, startFrom)
	if step and not startFrom then
		if step > 0 then
			startFrom = 1
		elseif step < 0 then
			startFrom = #t
		else
			error("Step should be greater or less than zero.", 2)
		end
	elseif not step and not startFrom then
		return ipairs(t)
	end
	local lambda = function(t, i)
		if not i then
			i = startFrom
		else
			i = i + step
		end
		if t[i] then
			return i, t[i]
		end
	end
	return lambda, t
end
