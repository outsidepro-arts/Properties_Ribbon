--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]]--

-- Preparing all needed configs which will be used not one time
local multiSelectionSupport = config.getboolean("multiSelectionSupport", true)

-- Prepare the envelopes and its points
local envelope = reaper.GetSelectedEnvelope(0)
local points = nil
if envelope then
local countEnvelopePoints = reaper.CountEnvelopePoints(envelope)
if multiSelectionSupport == true then
points = {}
for i = 0, countEnvelopePoints-1 do
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
local maybePoint = reaper.GetEnvelopePointByTime(envelope, reaper.GetCursorPosition()+0.0001)
if maybePoint >= 0 then
points = maybePoint
end
end
end

-- A few internal functions

local function getPointID(point, shouldNotReturnPrefix)
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

local function composeMultiplePointsMessage(func, states, inaccuracy)
local message = initOutputMessage()
for k = 1, #points do
local state = func(points[k])
local prevState if points[k-1] then prevState = func(points[k-1]) end
local nextState if points[k+1] then nextState = func(points[k+1]) end
if state ~= prevState and state == nextState then
message(string.format("points from %s ", getPointID(points[k], true)))
elseif state == prevState and state ~= nextState then
message(string.format("to %s ", getPointID(points[k], true)))
if inaccuracy and type(state) == "number" then
message(string.format("%s", states[state+inaccuracy]))
else
message(string.format("%s", states[state]))
end
if k < #points then
message(", ")
end
elseif state == prevState and state == nextState then
else
message(string.format("%s ", getPointID(points[k])))
if inaccuracy and type(state) == "number" then
message(string.format("%s", states[state+inaccuracy]))
else
message(string.format("%s", states[state]))
end
if k < #points then
message(", ")
elseif k == #points-1 then
message(" and ")
end
end
end
return message
end

local name = ""
if envelope then
_, name = reaper.GetEnvelopeName(envelope)
end

-- Define with which envelope we are interracting
-- I know about the Envelope_FormatValue, but using this converting method, we cannot get the humanbeing value back versa to raw data.
local envelopeType = 0
local envelopeRepresentation = setmetatable({}, {
__index = function(self, state)
return reaper.Envelope_FormatValue(envelope, state)
end
})
local envelopeFormatCaption = "Type a new raw value for selected points:"
envelopeProcess = function(udata)
if tonumber(udata) then
return udata
end
end
if envelope then
if reaper.GetEnvelopeScalingMode(envelope) == 0 then
if not name:find" / " then
-- This method will not works with non-english REAPER locales
-- I'm waiting for alternative methods for definition
if name:lower():find"volume" then
envelopeType = 1 -- decibels value
envelopeRepresentation = representation.db
envelopeFormatCaption = prepareUserData.db.formatCaption
envelopeProcess = prepareUserData.db.process
elseif name:lower():find"pan" then
envelopeType = 2 -- percentage value
-- Curious REAPER: the pan envelope has inverted values...
envelopeRepresentation = setmetatable({}, {
__index = function(self, state)
return representation.pan[-state]
end
})
envelopeFormatCaption = prepareUserData.pan.formatCaption
envelopeProcess = function(udata, curvalue)
udata = prepareUserData.pan.process(udata, curvalue)
if udata then
return -udata
end
end
elseif name:lower():find"width" then
envelopeType = 6
envelopeRepresentation = setmetatable({}, {
__index = function(self, state)
return string.format("%i%%", utils.numtopercent(state))
end
})
envelopeFormatCaption = prepareUserData.percent.formatCaption
envelopeProcess = prepareUserData.percent.process
elseif name:lower():find"rate" then
envelopeType = 3
envelopeRepresentation = representation.playrate
elseif name:lower():find"pitch" then
envelopeType = 4
envelopeRepresentation = representation.pitch
envelopeFormatCaption = prepareUserData.pitch.formatCaption
envelopeProcess = prepareUserData.pitch.process
elseif name:lower():find"mute" then
envelopeType = 5
end
end
end
end

-- We are ready to fix non-readable name parts
local fxName = ""
do
local prename, preFXName = name:match("(.+)%s[/]%s(.+)")
name = prename or name
if preFXName then
fxName = string.format(" of %s plug-in", preFXName)
end	
end

local envelopePointsLayout = initLayout(string.format("%s envelope points properties%s", name, fxName))

function envelopePointsLayout.canProvide()
return (envelope ~= nil)
end

local addEnvelopePointProperty = {}

function addEnvelopePointProperty:get()
	local message = initOutputMessage()
	message:initType("Perform this property to add new envelope point at current play or edit cursor position for selected envelope.", "Performable")
	message(string.format("Add new %s envelope point at cursor", name))
	return message
end

function addEnvelopePointProperty:set(action)
		if action == actions.set.perform then
			reaper.Main_OnCommand(40915, 0)
	else
		return "This property is performable only."
	end
	return
end

if points ~= nil then
local valueProperty = {}
envelopePointsLayout:registerProperty(valueProperty)

function valueProperty.getValue(point)
return ({reaper.GetEnvelopePoint(envelope, point)})[3]
end

function valueProperty.setValue(point, value)
local _, time = reaper.GetEnvelopePoint(envelope, point)
reaper.SetEnvelopePoint(envelope, point, time, value)
end

function valueProperty:get()
local message = initOutputMessage()
if envelopeType == 5 then
message:initType("Toggle this property to switch the state of envelope point value. ", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of points has been selected, the  state will be set to oposite value depending of moreness envelope points with the same value.", 1)
end
else
message:initType("Adjust this property to set the desired envelope point value. ", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of points has been selected, the relative of previous value will be applied for each point of.", 1)
end
message:addType(" Perform this property to set the raw point value for example coppied from FX parameters.", 1)
end
if type(points) == "table" then
message("Envelope points values:")
message(composeMultiplePointsMessage(self.getValue, envelopeRepresentation))
else
message(string.format("%s value %s", getPointID(points), envelopeRepresentation[self.getValue(points)]))
end
return message
end

function valueProperty:set(action)
local message = initOutputMessage()
if action == actions.set.decrease then
if envelopeType == 1 then
local adjustStep = config.getinteger("dbStep", 0.1)
local maxDBValue = config.getinteger("maxDBValue", 12.0)
if type(points) == "table" then
for _, point in ipairs(points) do
local state = self.getValue(point)
if utils.numtodecibels(state)-adjustStep >= -150 then
self.setValue(point, utils.decibelstonum(utils.numtodecibels(state)-adjustStep))
else
self.setValue(point, utils.decibelstonum(-150.0))
end
end
else
local state = self.getValue(points)
if utils.numtodecibels(state)-adjustStep >= -150 then
self.setValue(points, utils.decibelstonum(utils.numtodecibels(state)-adjustStep))
else
self.setValue(points, utils.decibelstonum(-150.0))
message("Minimum volume.")
end
end
elseif envelopeType == 2 then
-- Remember about strange pan values...
local adjustStep = config.getinteger("percentStep", 1)
if type(points) == "table" then
for _, point in ipairs(points) do
local state = self.getValue(point)
if utils.numtopercent(state)+adjustStep <= 100 then
self.setValue(point, utils.percenttonum(utils.numtopercent(state)+adjustStep))
else
self.setValue(point, utils.percenttonum(100))
end
end
else
local state = self.getValue(points)
if utils.numtopercent(state)+adjustStep <= 100 then
self.setValue(points, utils.percenttonum(utils.numtopercent(state)+adjustStep))
else
self.setValue(points, utils.percenttonum(100))
message("Left boundary.")
end
end
elseif envelopeType == 3 then
local adjustStep = config.getinteger("rateStep", 1)
adjustStep = ({0.6, 6})[adjustStep]
if type(points) == "table" then
for _, point in ipairs(points) do
local state = self.getValue(point)
if utils.numtopercent(state)-adjustStep >= 0 then
self.setValue(point, utils.percenttonum(utils.numtopercent(state)-adjustStep))
else
self.setValue(point, 0.000)
end
end
else
local state = self.getValue(points)
if utils.numtopercent(state)-adjustStep >= 0 then
self.setValue(points, utils.percenttonum(utils.numtopercent(state)-adjustStep))
else
self.setValue(points, 0.000)
message("Minimal rate value.")
end
end
elseif envelopeType == 4 then
local adjustStep = config.getinteger("pitchStep", 1.0)
if type(points) == "table" then
for _, point in ipairs(points) do
local state = self.getValue(point)
self.setValue(point, state-adjustStep)
end
else
local state = self.getValue(points)
self.setValue(points, state-adjustStep)
end
elseif envelopeType == 6 then
local adjustStep = config.getinteger("percentStep", 1)
if type(points) == "table" then
for _, point in ipairs(points) do
local state = self.getValue(point)
if utils.numtopercent(state)-adjustStep >= -100 then
self.setValue(point, utils.percenttonum(utils.numtopercent(state)-adjustStep))
else
self.setValue(point, utils.percenttonum(-100))
end
end
else
local state = self.getValue(points)
if utils.numtopercent(state)-adjustStep >= -100 then
self.setValue(points, utils.percenttonum(utils.numtopercent(state)-adjustStep))
else
self.setValue(points, utils.percenttonum(-100))
message("Minimal width value.")
end
end
else
reaper.Main_OnCommand(42382, 0)
end
elseif action == actions.set.increase then
if envelopeType == 1 then
local adjustStep = config.getinteger("dbStep", 0.1)
local maxDBValue = config.getinteger("maxDBValue", 12.0)
if type(points) == "table" then
for _, point in ipairs(points) do
local state = self.getValue(point)
if utils.numtodecibels(state)+adjustStep <= maxDBValue then
self.setValue(point, utils.decibelstonum(utils.numtodecibels(state)+adjustStep))
else
self.setValue(point, utils.decibelstonum(maxDBValue))
end
end
else
local state = self.getValue(points)
if utils.numtodecibels(state)+adjustStep <= maxDBValue then
self.setValue(points, utils.decibelstonum(utils.numtodecibels(state)+adjustStep))
else
self.setValue(points, utils.decibelstonum(maxDBValue))
message("Maximum volume.")
end
end
elseif envelopeType == 2 then
-- Remember about strange pan values...
local adjustStep = config.getinteger("percentStep", 1)
if type(points) == "table" then
for _, point in ipairs(points) do
local state = self.getValue(point)
if utils.numtopercent(state)-adjustStep >= -100 then
self.setValue(point, utils.percenttonum(utils.numtopercent(state)-adjustStep))
else
self.setValue(point, utils.percenttonum(-100))
end
end
else
local state = self.getValue(points)
if utils.numtopercent(state)-adjustStep >= -100 then
self.setValue(points, utils.percenttonum(utils.numtopercent(state)-adjustStep))
else
self.setValue(points, utils.percenttonum(-100))
message("Right boundary.")
end
end
elseif envelopeType == 3 then
local adjustStep = config.getinteger("rateStep", 1)
adjustStep = ({0.6, 6})[adjustStep]
if type(points) == "table" then
for _, point in ipairs(points) do
self.setValue(point, utils.percenttonum(utils.numtopercent(self.getValue(point))+adjustStep))
end
else
self.setValue(points, utils.percenttonum(utils.numtopercent(self.getValue(points))+adjustStep))
end
elseif envelopeType == 4 then
local adjustStep = config.getinteger("pitchStep", 1.0)
if type(points) == "table" then
for _, point in ipairs(points) do
self.setValue(point, self.getValue(point)+adjustStep)
end
else
self.setValue(points, self.getValue(points)+adjustStep)
end
elseif envelopeType == 6 then
local adjustStep = config.getinteger("percentStep", 1)
if type(points) == "table" then
for _, point in ipairs(points) do
local state = self.getValue(point)
if utils.numtopercent(state)+adjustStep <= 100 then
self.setValue(point, utils.percenttonum(utils.numtopercent(state)+adjustStep))
else
self.setValue(point, utils.percenttonum(100))
end
end
else
local state = self.getValue(points)
if utils.numtopercent(state)+adjustStep <= 100 then
self.setValue(points, utils.percenttonum(utils.numtopercent(state)+adjustStep))
else
self.setValue(points, utils.percenttonum(100))
message("Maximal width value.")
end
end
else
reaper.Main_OnCommand(42381, 0)
end
else
if envelopeType == 5 then
if type(points) == "table" then
local switchedOnPoints, switchedOffPoints = 0, 0
for _, point in ipairs(points) do
local state = utils.round(self.getValue(point), 0)
if state < 0 then state = -state end
if state == 1 then
switchedOnPoints = switchedOnPoints+1
else
switchedOffPoints = switchedOffPoints+1
end
end
adjustingValue = nil
if switchedOnPoints > switchedOffPoints then
adjustingValue = 0
elseif switchedOnPoints < switchedOffPoints then
adjustingValue = 1
else
adjustingValue = 0
end
message(string.format("Switching selected points values to %s. ", envelopeRepresentation[adjustingValue]))
for _, point in ipairs(points) do
self.setValue(point, adjustingValue)
end
else
local state = self.getValue(points)
if state < 0 then state = -state end
self.setValue(points, utils.nor(utils.round(state, 0)))
end
else
local retval, answer, curvalue, oldRepresentation = nil
-- The playrate converting methods aren't written, so we have to do a little substitution the representation metatable to an user was seeing the raw data instead of real representation.
if envelopeType == 3 then
 oldRepresentation = getmetatable(envelopeRepresentation)
envelopeRepresentation = setmetatable({}, {
__index = function(self, key)
return reaper.Envelope_FormatValue(envelope, key)
end
})
envelopeFormatCaption = "Type the REAPER proposed format playrate value:"
end
if type(points) == "table" then
retval, answer = reaper.GetUserInputs(string.format("Change the %u points of %s envelope", #points, name), 1, envelopeFormatCaption, envelopeRepresentation[self.getValue(points[1])])
curvalue = self.getValue(points[1])
else
retval, answer = reaper.GetUserInputs(string.format("Change the %s envelope %s", name, getPointID(points)), 1, envelopeFormatCaption, envelopeRepresentation[self.getValue(points)])
curvalue = self.getValue(points)
end
-- If oldRepresentation contains any metatable, we have to return back this. If do not do this, the get method will report the raw data instead of real representation. The case when the metatable substitutes we already defined.
if oldRepresentation then
envelopeRepresentation = setmetatable({}, oldRepresentation)
end
if retval then
answer = envelopeProcess		(answer, curvalue)
if answer then
if type(points) == "table" then
for _, point in ipairs(points) do
self.setValue(point, answer)
end
else
self.setValue(points, answer)
end
else
reaper.ShowMessageBox("Couldn't convert any specified value.", "Properties Ribbon error", 0)
return
end
else
return
end
end
end
message(self:get())
return message
end

local shapeProperty = {}
envelopePointsLayout:registerProperty(shapeProperty)
shapeProperty.states = setmetatable({
[0] = "linear",
[1] = "square",
[2] = "slow start and end",
[3] = "fast start",
[4] = "fast end",
[5] = "Bezier"
}, {
__index = function(self, key)
return string.format("Unknown shape value with ID %i. Please report this problem to me.", key)
end
})

function shapeProperty.getValue(point)
return ({reaper.GetEnvelopePoint(envelope, point)})[4]
end

function shapeProperty.setValue(point, value)
local _, time = reaper.GetEnvelopePoint(envelope, point)
reaper.SetEnvelopePoint(envelope, point, time, nil, value)
end

function shapeProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to choose the desired point shape.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType((' If the group of points has been selected, the value will enumerate up if selected points have the same value. If one of points has different value, all points will set to "%s" first, then will enumerate up this.'):format(self.states[0]), 1)
end
message:addType(" Perform this property to set the default point shape set in REAPER preferences.", 1)
if type(points) == "table" then
message("Envelope points shapes:")
message(composeMultiplePointsMessage(self.getValue, self.states))
else
message(string.format("%s shape %s", getPointID(points), self.states[self.getValue(points)]))
end
return message
end

function shapeProperty:set(action)
local message = initOutputMessage()
if action == actions.set.increase then
if type(points) == "table" then
local adjustingValue = nil
for idx, point in ipairs(points) do
if idx > 1 then
if self.getValue(points[idx-1]) ~= self.getValue(point) then
adjustingValue = -1
break
end
end
end
local state = nil
if not adjustingValue then
state = self.getValue(points[1])
else
state = -1
end
if (state+1) <= #self.states then
message(string.format("Set selected points shapes to %s. ", self.states[state+1]))
for _, point in ipairs(points) do
self.setValue(point, state+1)
end
else
message"No more next property values. "
end
else
local state = self.getValue(points)
if (state+1) <= #self.states then
self.setValue(points, state+1)
else
message("No more next property values. ")
end
end
elseif action == actions.set.decrease then
if type(points) == "table" then
local adjustingValue = nil
for idx, point in ipairs(points) do
if idx > 1 then
if self.getValue(points[idx-1]) ~= self.getValue(point) then
adjustingValue = -1
break
end
end
end
local state = nil
if not adjustingValue then
state = self.getValue(points[1])
else
state = -1
end
if (state-1) >= 0 then
message(string.format("Set selected points shapes to %s. ", self.states[state-1]))
for _, point in ipairs(points) do
self.setValue(point, state-1)
end
else
message"No more previous property values. "
end
else
local state = self.getValue(points)
if (state-1) >= 0 then
self.setValue(points, state-1)
else
message("No more previous property values. ")
end
end
else
local retval, defShape = reaper.get_config_var_string("deffadeshape")
if retval then
defShape = tonumber(defShape)
if type(points) == "table" then
message(("Reset selected point shapes to %s. "):format(self.states[defShape]))
for _, point in ipairs(points) do
self.setValue(point, defShape)
end
else
message"Reset. "
self.setValue(points, defShape)
end
else
return "The default shape is not set in REAPER preferences."
end
end
message(self:get())
return message
end

local tensionProperty = {}
envelopePointsLayout:registerProperty(tensionProperty)
tensionProperty.states = setmetatable({
[-2] = "unavailable",
[0] = "linear"
}, {
__index = function(self, state)
if state > 0 then
return string.format("%u%% to the next point", utils.numtopercent(state))
elseif state < 0 then
return string.format("%u%% to the previous point", utils.numtopercent(-state))
end
end
})

function tensionProperty.getValue(point)
if shapeProperty.getValue(point) == 5 then
return ({reaper.GetEnvelopePoint(envelope, point)})[5]
else
return -2
end
end

function tensionProperty.setValue(point, value)
if shapeProperty.getValue(point) == 5 then
local _, time = reaper.GetEnvelopePoint(envelope, point)
reaper.SetEnvelopePoint(envelope, point, time, nil, nil, value)
end
end


function tensionProperty:get()
local message = initOutputMessage()
message:initType(string.format("Adjust this property to set the desired curvature of %s tension.", shapeProperty.states[5]), "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of points has been selected, the relative of previous value will be applied for each point of.", 1)
end
message:addType(string.format(" Perform this property to reset the points to %s.", self.states[0]), 1)
if multiSelectionSupport == true then
message:addType(string.format(" Please note: if one of selected points has not %s tension, it will be skipped while adjusting or performing!", shapeProperty.states[5]), 1)
end
if type(points) == "table" then
message("Envelope points bezier tensions:")
message(composeMultiplePointsMessage(self.getValue, self.states))
else
message(string.format("%s bezier tension %s", getPointID(points), self.states[self.getValue(points)]))
if shapeProperty.getValue(points) ~= 5 then
message:changeType(string.format("This property is unavailable right now because the point you're viewing is not %s.", shapeProperty.states[5]), 1)
message:changeType("Unavailable", 2)
end
end
return message
end

function tensionProperty:set(action)
local message = initOutputMessage()
local adjustStep = config.getinteger("percentStep", 1)
if action == actions.set.decrease then
if type(points) == "table" then
for _, point in ipairs(points) do
if shapeProperty.getValue(point) == 5 then
local state = self.getValue(point)
if (state-utils.percenttonum(adjustStep)) >= -1.0 then
self.setValue(point, utils.percenttonum(utils.numtopercent(state)-adjustStep))
else
self.setValue(point, -1.0)
end
end
end
else
if shapeProperty.getValue(points) == 5 then
local state = self.getValue(points)
if (state-utils.percenttonum(adjustStep)) >= -1.0 then
self.setValue(points, utils.percenttonum(utils.numtopercent(state)-adjustStep))
else
message"Maximal curvature to the previous point. "
self.setValue(points, -1.0)
end
else
return string.format("This property is unavailable because the shape of this point is not %s.", shapeProperty.states[5])
end
end
elseif action == actions.set.increase then
if type(points) == "table" then
for _, point in ipairs(points) do
if shapeProperty.getValue(point) == 5 then
local state = self.getValue(point)
if (state+utils.percenttonum(adjustStep)) <= 1.0 then
self.setValue(point, utils.percenttonum(utils.numtopercent(state)+adjustStep))
else
self.setValue(point, 1.0)
end
end
end
else
if shapeProperty.getValue(points) == 5 then
local state = self.getValue(points)
if (state+utils.percenttonum(adjustStep)) <= 1.0 then
self.setValue(points, utils.percenttonum(utils.numtopercent(state)+adjustStep))
else
message"Maximal curvature to the next point. "
self.setValue(points, 1.0)
end
else
return string.format("This property is unavailable because the shape of this point is not %s.", shapeProperty.states[5])
end
end
else
if type(points) == "table" then
message(string.format("Reset selected points to %s. ", self.states[0]))
for _, point in ipairs(points) do
if shapeProperty.getValue(point) == 5 then
self.setValue(point, 0.0)
end
end
else
if shapeProperty.getValue(points) == 5 then
message(string.format("Reset to %s. ", self.states[0]))
self.setValue(points, 0.0)
else
return string.format("This property is unavailable because the shape of this point is not %s.", shapeProperty.states[5])
end
end
end
message(self:get())
return message
end
end

	envelopePointsLayout:registerProperty(addEnvelopePointProperty)

return envelopePointsLayout