--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts
License: MIT License

----------

Let me say a few word before starts
LUA - is not object oriented programming language, but very flexible. Its flexibility allows to realize OOP easy via metatables. In this scripts the pseudo OOP has been used, therefore we have to understand some terms.
.1 When i'm speaking "Class" i mean the metatable variable with some fields.
2. When i'm speaking "Method" i mean a function attached to a field or submetatable field.
When i was starting write this scripts complex i imagined this as real OOP. But in consequence the scripts structure has been reunderstanded as current structure. It has been turned out more comfort as for writing new properties table, as for call this from main script engine.
After this preambula, let me begin.
]]--

-- global pseudoclass initialization
local configLayout = initLayout("Configuration properties")

-- the function which gives green light to call any method from this class
function configLayout.canProvide()
-- The configs ever available, so let define this always.
return true
end

--[[
Before the properties list fill get started, let describe this subclass methods:
Method get: gets no one parameter, returns a message string which will be reported in the navigating scripts.
Method set: gets parameter action. Expects false, true or nil.
action == true: the property must changed upward
action == false: the property must changed downward
action == nil: The property must be toggled or performed default action
Returns a message string which will be reported in the navigating scripts.

After you finish the methods table you have to return parent class.
No any recomendation more.
Although, no, just one thing:
Try to allow the user to perform actions on both one element and a selected group..
and try to complement any getState message with short type label. I mean what the "ajust" method will perform.
]]--


-- type level methods
local typeLevelProperty = {}
configLayout:registerProperty(typeLevelProperty)
typeLevelProperty.states = {[0] = "no prompt for property actions", [1] = "detailed prompts for property actions (for beginers)",[2] = "short prompts for property actions"}

function typeLevelProperty:get()
local message = initOutputMessage()
local typeLevel = config.getinteger("typeLevel", 1)
message:initType(typeLevel, "Adjust this property to set the desired prompts level.", "Adjustable")
message(string.format("Properties ribbon now provides %s", self.states[typeLevel]))
return message
end

function typeLevelProperty:set(action)
if action == nil then
return "This property is adjustable only."
end
local message = initOutputMessage()
local state = config.getinteger("typeLevel", 1)
if action == true then
if self.states[state+1] then
config.setinteger("typeLevel", state+1)
else
message("No more next property values.")
end
elseif action == false then
if self.states[state-1] then
config.setinteger("typeLevel", state-1)
else
message("No more previous property values.")
end
end
state = config.getinteger("typeLevel")
message(string.format("Properties ribbon now provides %s", self.states[state]))
return message
end

-- Virtual cursor position reporting methods
local reportPosProperty = {}
configLayout:registerProperty( reportPosProperty)
function reportPosProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to set an opposite value for this setting.", "Toggleable")
local state = config.getboolean("reportPos", true)
message(string.format("Properties Ribbon now %s the virtual cursor position", ({[true] = "reports", [false] = "not reports"})[state]))
return message
end

function reportPosProperty:set(action)
if action ~= nil then
return "This property is toggleable only."
end
local state = nor(config.getboolean("reportPos", true))
config.setboolean("reportPos", state)
return string.format("Properties Ribbon now %s the virtual cursor position", ({[true] = "reports", [false] = "not reports"})[state])
end


-- DB step specify methods
local dbStepProperty = {}
configLayout:registerProperty( dbStepProperty)
function dbStepProperty:get()
local message = initOutputMessage()
local typeLevel = config.getinteger("typeLevel", 1)
message:initType(typeLevel, "Adjust this property to set needed step to either more or less than current value. Perform this property to input needed step value manualy.", "adjustable, performable")
local state = config.getinteger("dbStep", 0.1)
message(string.format("The Decibel step adjustment is set to %s", state))
return message
end

function dbStepProperty:set(action)
local message = initOutputMessage()
local state = config.getinteger("dbStep", 0.1)
local ajustingValue
if action == true then
ajustingValue = state+0.01
elseif action == false then
ajustingValue = state-0.01
else
local result, answer = reaper.GetUserInputs("Decibel step input", 1, 'Type the needed step which every property with DB value will change per one adjustment in decimal format but no more two digits after decimal separator (0.1, 1.25 and etc):', state)
if result == true then
ajustingValue = tonumber(answer)
else
return "Canceled."
end
end
if ajustingValue >= 10 then
message("More than 10 db can do bugs and unexpected results. ")
config.setinteger("dbStep", 10.0)
elseif ajustingValue < 0.01 then
message("Set the step to zero DB is pointless. ")
config.setinteger("dbStep", 0.01)
else
config.setinteger("dbStep", ajustingValue)
end
message(string.format("The Decibel step adjustment is set to %s.", config.getinteger("dbStep")))
return message
end

-- Percentage step adjustment methods
local percentagestepProperty = {}
configLayout:registerProperty( percentagestepProperty)

function percentagestepProperty:get()
local message = initOutputMessage()
local typeLevel = config.getinteger("typeLevel", 1)
message:initType(typeLevel, "Adjust this property to set needed step to either more or less than current value. Perform this property to input needed step value manualy.", "adjustable, performable")
local state = config.getinteger("percentStep", 1)
message(string.format("The percent step adjustment is set to %s%%", state))
return message
end

function percentagestepProperty:set(action)
local message = initOutputMessage()
local state = config.getinteger("percentStep", 1)
local ajustingValue
if action == true then
ajustingValue = state+1
elseif action == false then
ajustingValue = state-1
else
local result, answer = reaper.GetUserInputs("Percent step input", 1, 'Type the needed percentage step (2, 45 and etc):', state)
if result == true then
ajustingValue = tonumber(answer)
else
return "Canceled."
end
end
if ajustingValue >= 100 then
message("Percent means number 100 but not more than. ")
config.setinteger("percentStep", 100)
elseif ajustingValue < 1 then
message("Set the step to zero percent is pointless. ")
config.setinteger("percentStep", 1)
else
config.setinteger("percentStep", ajustingValue)
end
message(string.format("The percent step adjustment is set to %s%%.", config.getinteger("percentStep")))
return message
end

-- Time step adjustment methods
local timeStepProperty = {}
configLayout:registerProperty( timeStepProperty)

function timeStepProperty:get()
local message = initOutputMessage()
local typeLevel = config.getinteger("typeLevel", 1)
message:initType(typeLevel, "Adjust this property to set needed time step to either more or less than current value. Perform this property to input needed step value manualy.", "adjustable, performable")
local state = config.getinteger("timeStep", 0.001)
message(string.format("The time step adjustment is set to %s ms", state))
return message
end

function timeStepProperty:set(action)
local message = initOutputMessage()
local state = config.getinteger("timeStep", 0.001)
local ajustingValue
if action == true then
ajustingValue = state+0.001
elseif action == false then
ajustingValue = state-0.001
else
local result, answer = reaper.GetUserInputs("Time step input", 1, 'Type the needed step which every property with time value will change per one adjustment in decimal format but no more three digits after decimal separator (0.1, 1.25, 3.201 and etc):', state)
if result == true then
ajustingValue = tonumber(answer)
else
return "Canceled."
end
end
if ajustingValue <= 0 then
message("Set the step to zero MS is pointless. ")
config.setinteger("timeStep", 0.001)
else
config.setinteger("timeStep", ajustingValue)
end
message(string.format("The time step adjustment is set to %s ms.", config.getinteger("timeStep")))
return message
end

-- Pitch adjustment methods
local pitchStepProperty = {}
configLayout:registerProperty( pitchStepProperty)

function pitchStepProperty:get()
local message = initOutputMessage()
local typeLevel = config.getinteger("typeLevel", 1)
message:initType(typeLevel, "Adjust this property to set desired pitch step to either more or less than current value. Perform this property to input needed step value manualy.", "adjustable, performable")
local state = round(config.getinteger("pitchStep", 1.00), 2)
local fv = splitstring(tostring(state), ".")
message("The pitch step adjustment is set to ")
if tonumber(fv[1]) >= 1 then
message(string.format("%s semitone%s", fv[1], ({[false]="", [true]="s"})[(tonumber(fv[1]) > 1 or tonumber(fv[1]) < -1)]))
if tonumber(fv[2]) > 0 then
message(", ")
end
end
if fv[2] ~= "0" then
message(string.format("%s cent%s", numtopercent(tonumber("0."..fv[2])), ({[false]="", [true]="s"})[(numtopercent(tonumber("0."..fv[2])) > 1)]))
end
return message
end

function pitchStepProperty:set(action)
local message = initOutputMessage()
local state = round(config.getinteger("pitchStep", 1.00), 2)
local ajustingValue
if action == true then
if state == 0.01 then
ajustingValue = 1.0
else
ajustingValue = state+1.0
end
elseif action == false then
if state== 1.00 then
ajustingValue = 0.01
else
ajustingValue = state-1.0
end
else
local result, answer = reaper.GetUserInputs("Pitch step input", 1, 'Type the needed step which every property with pitch value will change per one adjustment in decimal format but no more two digits after decimal separator (0.01=0 semitones, 1 cent), 1.25=1 semitone, 25 cents and etc):', state)
if result == true then
ajustingValue = tonumber(answer)
else
return "Canceled."
end
end
if ajustingValue < 0.01 then
message("Set the step to zero MS is pointless. ")
config.setinteger("pitchStep", 0.01)
else
config.setinteger("pitchStep", ajustingValue)
end
state = config.getinteger("pitchStep")
local fv = splitstring(tostring(state), ".")
message("The pitch step adjustment is set to ")
if tonumber(fv[1]) >= 1 then
message(string.format("%s semitone%s", fv[1], ({[false]="", [true]="s"})[(tonumber(fv[1]) > 1 or tonumber(fv[1]) < -1)]))
if tonumber(fv[2]) > 0 then
message(", ")
end
end
if fv[2] ~= "0" then
message(string.format("%s cent%s", numtopercent(tonumber("0."..fv[2])), ({[false]="", [true]="s"})[(numtopercent(tonumber("0."..fv[2])) > 1)]))
end
return message
end


-- Multiselection support methods
local multiSelectionSupportProperty = {}
configLayout:registerProperty( multiSelectionSupportProperty)
function multiSelectionSupportProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to set an opposite value for this setting.", "Toggleable")
local state = config.getboolean("multiSelectionSupport", true)
message(string.format("Properties Ribbon now %s the multi selection", ({[true] = "supports", [false] = "not supports"})[state]))
return message
end

function multiSelectionSupportProperty:set(action)
if action ~= nil then
return "This property is toggleable only."
end
local state = nor(config.getboolean("multiSelectionSupport", true))
config.setboolean("multiSelectionSupport", state)
return string.format("Properties Ribbon now %s the multi selection", ({[true] = "supports", [false] = "not supports"})[state])
end

return configLayout