--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2024 outsidepro-arts
License: MIT License

----------
]]
--


-- This file contains a macros for specified solutions. Use this macros at own properties.


envelope_properties_macros = {}
---@alias envelope userdata
---@alias envelope_point integer

---Gets all selected envelope points
---@param envelope envelope
---@param multiSelectionSupport boolean defines the multi-selection support
---@return envelope_point[] | envelope_point either array of selected envelope points or one envelope point object (if there's one only)
function envelope_properties_macros.getPoints(envelope, multiSelectionSupport)
	points = nil
	if envelope then
		local countEnvelopePoints = reaper.CountEnvelopePoints(envelope)
		if multiSelectionSupport == true then
			points = {}
			for i = 0, countEnvelopePoints - 1 do
				local retval, _, _, _, _, selected = reaper.GetEnvelopePoint(envelope, i)
				if retval and selected then
					table.insert(points, i)
				end
			end
			if #points == 1 then
				points = points[1]
			elseif #points == 0 then
				points = nil
			end
		else
			-- As James Teh says, REAPER returns the previous point by time even if any point is set here. I didn't saw that, but will trust of professional developer!
			local maybePoint = reaper.GetEnvelopePointByTime(envelope, reaper.GetCursorPosition() + 0.0001)
			if maybePoint >= 0 then
				points = maybePoint
			end
		end
	end
	return points
end

---Composes the envelope point identification label
---@param point envelope_point
---@param shouldNotReturnPrefix? boolean should the prefix "point" be removed? (false by default)
---@return string
function envelope_properties_macros.getPointID(point, shouldNotReturnPrefix)
	if point == 0 then
		return "Initial point"
	else
		if shouldNotReturnPrefix == true then
			return tostring(point)
		else
			return string.format("Point %u", point)
		end
	end
end
