--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]]--

-- Preparing all needed configs which will be used not one time
local multiSelectionSupport = config.getboolean("multiSelectionSupport", true)

-- Prepare the envelopes and its points
local envelope = reaper.GetSelectedEnvelope(0)
local points = envelope_properties_macros.getPoints(envelope, multiSelectionSupport)

-- A few internal functions
local getPointID = envelope_properties_macros.getPointID

local function composeMultiplePointsMessage(func, states, inaccuracy)
local message = initOutputMessage()
for k = 1, #points do
local state = func(points[k])
local prevState if points[k-1] then prevState = func(points[k-1]) end
local nextState if points[k+1] then nextState = func(points[k+1]) end
if state ~= prevState and state == nextState then
message({value=string.format("points from %s ", getPointID(points[k], true))})
elseif state == prevState and state ~= nextState then
message({value=string.format("to %s ", getPointID(points[k], true))})
if inaccuracy and isnumber(state) then
message({value=string.format("%s", states[state+inaccuracy])})
else
message({value=string.format("%s", states[state])})
end
if k < #points then
message({value=", "})
end
elseif state == prevState and state == nextState then
else
message({value=string.format("%s ", getPointID(points[k]))})
if inaccuracy and isnumber(state) then
message({value=string.format("%s", states[state+inaccuracy])})
else
message({value=string.format("%s", states[state])})
end
if k < #points then
message({value=", "})
elseif k == #points-1 then
message({value=" and "})
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
	message:initType("Perform this property to add new envelope point at current play or edit cursor position for selected envelope.")
	message(string.format("Add new %s envelope point at cursor", name))
	return message
end

function addEnvelopePointProperty:set_perform()
reaper.Main_OnCommand(40915, 0)
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
message:initType("Adjust this property to set the desired envelope point value. ")
if multiSelectionSupport == true then
message:addType(" If the group of points has been selected, the relative of previous value will be applied for each point of.", 1)
end
message:addType(" Perform this property to set the raw point value for example coppied from FX parameters.", 1)
end
message({label="Value"})
if istable(points) then
message(composeMultiplePointsMessage(self.getValue, envelopeRepresentation))
else
message({objectId=getPointID(points), value=envelopeRepresentation[self.getValue(points)]})
end
return message
end

function valueProperty:set_adjust(direction)
local message = initOutputMessage()
if direction == actions.set.decrease.direction then
if envelopeType == 1 then
local adjustStep = config.getinteger("dbStep", 0.1)
local maxDBValue = config.getinteger("maxDBValue", 12.0)
if istable(points) then
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
if istable(points) then
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
if istable(points) then
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
local bounce = config.getinteger("pitchBounces", 24.0)
if istable(points) then
for _, point in ipairs(points) do
local state = self.getValue(point)
if state-adjustStep >= -bounce then
state = state-adjustStep
else
state = -bounce
end
self.setValue(point, state)
end
else
local state = self.getValue(points)
if state-adjustStep >= -bounce then
self.setValue(points, state-adjustStep)
else
self.setValue(points, -bounce)
message("No more previous property values.")
end
end
elseif envelopeType == 6 then
local adjustStep = config.getinteger("percentStep", 1)
if istable(points) then
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
elseif direction == actions.set.increase.direction then
if envelopeType == 1 then
local adjustStep = config.getinteger("dbStep", 0.1)
local maxDBValue = config.getinteger("maxDBValue", 12.0)
if istable(points) then
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
if istable(points) then
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
if istable(points) then
for _, point in ipairs(points) do
self.setValue(point, utils.percenttonum(utils.numtopercent(self.getValue(point))+adjustStep))
end
else
self.setValue(points, utils.percenttonum(utils.numtopercent(self.getValue(points))+adjustStep))
end
elseif envelopeType == 4 then
local adjustStep = config.getinteger("pitchStep", 1.0)
local bounce = config.getinteger("pitchBounces", 24.0)
if istable(points) then
for _, point in ipairs(points) do
local state = self.getValue(point)
if state-adjustStep <= bounce then
state = state+adjustStep
else
state = bounce
end
self.setValue(point, state)
end
else
local state = self.getValue(points)
if state+adjustStep <= bounce then
self.setValue(points, state+adjustStep)
else
self.setValue(points, bounce)
message("No more next property values.")
end
end
elseif envelopeType == 6 then
local adjustStep = config.getinteger("percentStep", 1)
if istable(points) then
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
end
message(self:get())
return message
end

function valueProperty:set_perform()
if envelopeType == 5 then
if istable(points) then
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
local retval, answer, curvalue, oldRepresentation
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
if istable(points) then
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
if istable(points) then
for _, point in ipairs(points) do
self.setValue(point, answer)
end
else
self.setValue(points, answer)
end
else
reaper.ShowMessageBox("Couldn't convert any specified value.", "Properties Ribbon error", showMessageBoxConsts.sets.ok)
return
end
else
return
end
end
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
message:initType("Adjust this property to choose the desired point shape.")
if multiSelectionSupport == true then
message:addType((' If the group of points has been selected, the value will enumerate up if selected points have the same value. If one of points has different value, all points will set to "%s" first, then will enumerate up this.'):format(self.states[0]), 1)
end
message:addType(" Perform this property to set the default point shape set in REAPER preferences.", 1)
message({label="shape"})
if istable(points) then
message(composeMultiplePointsMessage(self.getValue, self.states))
else
message({objectId=getPointID(points), value=self.states[self.getValue(points)]})
end
return message
end

function shapeProperty:set_adjust(direction)
local message = initOutputMessage()
if istable(points) then
local allIsSame = true
for idx, point in ipairs(points) do
if idx > 1 then
if self.getValue(points[idx-1]) ~= self.getValue(point) then
allIsSame = false
break
end
end
end
local state = nil
if allIsSame then
state = self.getValue(points[1])
if self.states[state+direction] then
state = state+direction
end
else
state = -1
end
message(string.format("Set selected points shapes to %s. ", self.states[state]))
for _, point in ipairs(points) do
self.setValue(point, state)
end
else
local state = self.getValue(points)
if (state+direction) > #self.states then
message("No more next property values. ")
elseif (state+direction) < 0 then
message("No more previous property values. ")
else
self.setValue(points, state+direction)
end
end
message(self:get())
return message
end

function shapeProperty:set_perform()
local message = initOutputMessage()
local retval, defShape = reaper.get_config_var_string("deffadeshape")
if retval then
defShape = tonumber(defShape)
if istable(points) then
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
message:initType(string.format("Adjust this property to set the desired curvature of %s tension.", shapeProperty.states[5]))
if multiSelectionSupport == true then
message:addType(" If the group of points has been selected, the relative of previous value will be applied for each point of.", 1)
end
message:addType(string.format(" Perform this property to reset the points to %s.", self.states[0]), 1)
if multiSelectionSupport == true then
message:addType(string.format(" Please note: if one of selected points has not %s tension, it will be skipped while adjusting or performing!", shapeProperty.states[5]), 1)
end
message({label="Bezier tension"})
if istable(points) then
message(composeMultiplePointsMessage(self.getValue, self.states))
else
message({objectId=getPointID(points), value=self.states[self.getValue(points)]})
if shapeProperty.getValue(points) ~= 5 then
message:changeType(string.format("This property is unavailable right now because the point you're viewing is not %s.", shapeProperty.states[5]), 1)
message:changeType("Unavailable", 2)
end
end
return message
end

function tensionProperty:set_adjust(direction)
local message = initOutputMessage()
local adjustStep = config.getinteger("percentStep", 1)
adjustStep = utils.percenttonum(adjustStep)
if direction == actions.set.decrease.direction then
adjustStep = -utils.percenttonum(adjustStep)
end
if istable(points) then
for _, point in ipairs(points) do
if shapeProperty.getValue(point) == 5 then
local state = self.getValue(point)
if (state+adjustStep) > utils.percenttonum(100) then
state = utils.percenttonum(100)
elseif (state+adjustStep) < utils.percenttonum(-100) then
state = utils.percenttonum(-100)
else
state = state+direction
end
self.setValue(point, utils.percenttonum(utils.numtopercent(state)-adjustStep))
end
end
else
if shapeProperty.getValue(points) == 5 then
local state = self.getValue(points)
if (state+adjustStep) > utils.percenttonum(100) then
message"Maximal curvature to the next point. "
state = utils.percenttonum(100)
elseif (state+adjustStep) < utils.percenttonum(-100) then
message"Maximal curvature to the previous point. "
state = utils.percenttonum(-100)
else
state = state+adjustStep
end
self.setValue(points, state)
else
return string.format("This property is unavailable because the shape of this point is not %s.", shapeProperty.states[5])
end
end
message(self:get())
return message
end

function tensionProperty:set_perform()
local message = initOutputMessage()
if istable(points) then
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
message(self:get())
return message
end

end


if points ~= nil then
local gotoPositionProperty = {}
envelopePointsLayout:registerProperty(gotoPositionProperty)

function gotoPositionProperty:get()
local message = initOutputMessage()
message:initType("Perform this property to move the play or edit cursor to timeline position where this point has positioned.")
if multiSelectionSupport then
message:addType(" If the group of points has been selected, the cursor will set to first selected point position.", 1)
end
if istable(points) then
message(string.format("Go to %s position", getPointID(points[1])))
else
message(string.format("Go to %s position", getPointID(points)))
end
return message
end

function gotoPositionProperty:set_perform()
local message = initOutputMessage()
local point = nil
if istable(points) then
point = points[1]
else
point = points
end
local retval, time = reaper.GetEnvelopePoint(envelope, point)
if retval then
reaper.SetEditCurPos(time, true, true)
message(string.format("Moved the edit cursor to %s", representation.defpos[time]))
end
return message
end

end

if points ~= nil then
local deletePointsProperty = {}
envelopePointsLayout:registerProperty(deletePointsProperty)

function deletePointsProperty:get()
local message = initOutputMessage()
message:initType("Perform this property to delete the envelope point.")
if multiSelectionSupport then
message:addType(" If the group of points has been selected, all these points will be deleted.", 1)
end	
if istable(points) then
message(string.format("Delete %u selected %s points", #points, name))
else	
message(string.format("Delete %s", getPointID(points)))
end
return message
end

function deletePointsProperty:set_perform()
setUndoLabel(self:get())
reaper.Main_OnCommand(40333, 0) -- Envelope: Delete all selected points
if reaper.CountEnvelopePoints(envelope) > 0 then
if reaper.GetEnvelopePoint(envelope, reaper.CountEnvelopePoints(envelope)-1) then
reaper.SetEnvelopePoint(envelope, reaper.CountEnvelopePoints(envelope)-1, nil, nil, nil, nil, true)
end
end
end
end

	envelopePointsLayout:registerProperty(addEnvelopePointProperty)

return envelopePointsLayout