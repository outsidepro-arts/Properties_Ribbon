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
local configLayout = initLayout("%sConfiguration properties")

-- the function which gives green light to call any method from this class
function configLayout.canProvide()
-- The configs ever available, so let define this always.
return true
end

-- sub-layouts
-- Main sub-layout
configLayout:registerSublayout("main", "general ")
configLayout:registerSublayout("stepAdjustment", "Step adjustment ")

--[[
Before the properties list fill get started, let describe this subclass methods:
Method get: gets no one parameter, returns a message string which will be reported in the navigating scripts.
Method set: gets parameter action. Expects false, true or nil.
action == actions.set.increase: the property must changed upward
action == actions.set.decrease: the property must changed downward
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
configLayout.main:registerProperty(typeLevelProperty)
typeLevelProperty.states = {[0] = "no prompt for property actions", [1] = "detailed prompts for property actions (for beginers)",[2] = "short prompts for property actions"}

function typeLevelProperty:get()
local message = initOutputMessage()
local typeLevel = config.getinteger("typeLevel", 1)
message:initType("Adjust this property to set the desired type prompts level. The type prompts are reports after value message and descripts the appointment of this value.", "Adjustable")
message(string.format("Types prompts level %s", self.states[typeLevel]))
return message
end

function typeLevelProperty:set(action)
if action == nil then
return "This property is adjustable only."
end
local message = initOutputMessage()
local state = config.getinteger("typeLevel", 1)
if action == actions.set.increase then
if self.states[state+1] then
config.setinteger("typeLevel", state+1)
else
message("No more next property values.")
end
elseif action == actions.set.decrease then
if self.states[state-1] then
config.setinteger("typeLevel", state-1)
else
message("No more previous property values.")
end
end
message(self:get())
return message
end

-- Virtual cursor position reporting methods
local reportPosProperty = {}
configLayout.main:registerProperty( reportPosProperty)
reportPosProperty.states = {
[0] = "off",
[1] = "only for categories",
[2] = "only for properties",
[3] = "both for categories and properties"
}
function reportPosProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to choose the status of the position reporting when you're navigating through the properties in a ribbon or when you're choose a category in a layout.", "Adjustable")
local state = config.getinteger("reportPos", 3)
message(string.format("Reporting navigation position %s", self.states[state]))
return message
end

function reportPosProperty:set(action)
if action == nil then
return "This property is adjustable only."
end
local message = initOutputMessage()
local state = config.getinteger("reportPos", 3)
if action == actions.set.increase then
if (state+1) <= #self.states then
config.setinteger("reportPos", state+1)
else
message("No more next property values. ")
end
elseif action == actions.set.decrease then
if (state-1) >= 0 then
config.setinteger("reportPos", state-1)
else
message("No more previous property values. ")
end
end
message(self:get())
return message
end

-- Remember the last sublayout property
local resetSublayoutProperty = {}
configLayout.main:registerProperty( resetSublayoutProperty)
resetSublayoutProperty.states = {
[0]="for not any ",
[1]="Only for categories",
[2]="Only for properties",
[3]="both for categories and properties"
}
function resetSublayoutProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set the position remembering when you are loading a properties layout which was been loaded earlier.", "Adjustable")
local state = config.getinteger("rememberSublayout", 3)
message(string.format("Remember position in layouts when loading %s", self.states[state]))
return message
end

function resetSublayoutProperty:set(action)
local message = initOutputMessage()
if action == nil then
return "This property is adjustable only."
end
local state = config.getinteger("rememberSublayout", 3)
if action == actions.set.increase then
if (state+1) <= #self.states then
config.setinteger("rememberSublayout", (state+1))
else
message("No more next property values. ")
end
elseif action == actions.set.decrease then
if (state-1) >= 0 then
config.setinteger("rememberSublayout", (state-1))
else
message("No more previous property values. ")
end
end
message(self:get())
return message
end



-- DB step specify methods
local dbStepProperty = {}
configLayout.stepAdjustment:registerProperty( dbStepProperty)

function dbStepProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set proposed step to either more or less than current value of every step adjustment which works with decibels values like as volume and etc. Perform this property to input needed custom step value manualy.", "adjustable, performable")
local state = config.getinteger("dbStep", 0.1)
message(string.format("Decibel step adjustment %s", representation.db[-utils.decibelstonum(state)]))
return message
end

function dbStepProperty:set(action)
local message = initOutputMessage()
local state = config.getinteger("dbStep", 0.1)
local ajustingValue
if action == actions.set.increase then
if state >= 0.01 and state < 0.1 then
ajustingValue = 0.1
elseif state >= 0.1 and state < 0.5 then
ajustingValue = 0.5
elseif state >= 0.5 and state < 1.0 then
ajustingValue = 1.0
else
return "Maximal step value"
end
elseif action == actions.set.decrease then
if state > 1.0 then
ajustingValue = 1.0
elseif state <= 1.0 and state > 0.5 then
ajustingValue = 0.5
elseif state <= 0.5 and state > 0.1 then
ajustingValue = 0.1
elseif state <= 0.1 and state > 0.01 then
ajustingValue = 0.01
else
return "Minimal step value"
end
else
local result, answer = reaper.GetUserInputs("Decibel step input", 1, prepareUserData.db.formatCaption, representation.db[-utils.decibelstonum(state)])
if result == true then
ajustingValue = utils.numtodecibels(prepareUserData.db.process(answer, utils.numtodecibels(state)))
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
message(self:get())
return message
end

-- Maximum decibels value
local maxDbProperty = {}
configLayout.stepAdjustment:registerProperty( maxDbProperty)

function maxDbProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set proposed maximum decibels value  when these properties will be cancel to increase to either more or less than current value Perform this property to input needed custom value manualy.", "adjustable, performable")
local state = config.getinteger("maxDBValue", 12.0)
message(string.format("Maximum decibels value %s", representation.db[-utils.decibelstonum(state)]))
return message
end

function maxDbProperty:set(action)
local message = initOutputMessage()
local state = config.getinteger("maxDBValue", 12.0)
local ajustingValue
if action == actions.set.increase then
if state >= 6.0 and state < 12.0 then
ajustingValue = 12.0
elseif state >= 12.0 and state < 18.0 then
ajustingValue = 18.0
elseif state >= 18.0 and state < 24.0 then
ajustingValue = 24.0
else
return "Maximal value"
end
elseif action == actions.set.decrease then
if state > 24.0 then
ajustingValue = 24.0
elseif state <= 24.0 and state > 18.0 then
ajustingValue = 18.0
elseif state <= 18.0 and state > 12.0 then
ajustingValue = 12.0
elseif state <= 12.0 and state > 6.0 then
ajustingValue = 6.0
else
return "Minimal value"
end
else
local result, answer = reaper.GetUserInputs("Maximum decibels value", 1, prepareUserData.db.formatCaption, representation.db[-utils.decibelstonum(state)])
if result == true then
ajustingValue = utils.numtodecibels(prepareUserData.db.process(answer, utils.decibelstonum(state)))
else
return "Canceled."
end
end
config.setinteger("maxDBValue", ajustingValue)
message(self:get())
return message
end

-- Percentage step adjustment methods
local percentagestepProperty = {}
configLayout.stepAdjustment:registerProperty( percentagestepProperty)

function percentagestepProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set proposed step to either more or less than current value of percentage step which used by properties with percentage values like as pan, width and etc. Perform this property to input needed custom step value manualy.", "adjustable, performable")
local state = config.getinteger("percentStep", 1)
message(string.format("Percent step adjustment  %s%%", state))
return message
end

function percentagestepProperty:set(action)
local message = initOutputMessage()
local state = config.getinteger("percentStep", 1)
local ajustingValue
if action == actions.set.increase then
if state >= 1 and state < 5 then
ajustingValue = 5
elseif state >= 5 and state < 10 then
ajustingValue = 10
else
return "Maximal step value"
end
elseif action == actions.set.decrease then
if state > 10 then
ajustingValue = 10
elseif state <= 10 and state > 5 then
ajustingValue = 5
elseif state <= 5 and state >1 then
ajustingValue = 1
else
return "Minimal step value"
end
else
local result, answer = reaper.GetUserInputs("Percent step input", 1, prepareUserData.percent.formatCaption, string.format("%u%%", state))
if result == true then
ajustingValue = utils.numtopercent(prepareUserData.percent.process(answer, utils.percenttonum(state)))
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
message(self:get())
return message
end

-- Time step adjustment methods
local timeStepProperty = {}
configLayout.stepAdjustment:registerProperty( timeStepProperty)

function timeStepProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set proposed time step to either more or less than current value of time step which used by properties with time values like as fade in and out lengths and etc. Perform this property to input needed custom step value manualy.", "adjustable, performable")
local state = config.getinteger("timeStep", 0.001)
message(string.format("Time step adjustment %s", representation.timesec[state]))
return message
end

function timeStepProperty:set(action)
local message = initOutputMessage()
local state = config.getinteger("timeStep", 0.001)
local ajustingValue
if action == actions.set.increase then
if state >= 0.001 and state < 0.010 then
ajustingValue = 0.010
elseif state >= 0.010 and state < 0.100 then
ajustingValue = 0.100
elseif state >= 0.100 and state < 1.000 then
ajustingValue = 1.000
else
return "Maximal step value"
end
elseif action == actions.set.decrease then
if state > 1.000 then
ajustingValue = 1.000
elseif state <= 1.000 and state > 0.100 then
ajustingValue = 0.100
elseif state <= 0.100 and state> 0.010 then
ajustingValue = 0.010
elseif state <= 0.010 and state > 0.001 then
ajustingValue = 0.001
else
return "Minimal step value"
end
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
message(self:get())
return message
end

-- Playrate adjustment methods
local playrateStepProperty = {}
configLayout.stepAdjustment:registerProperty(playrateStepProperty)
playrateStepProperty.states = {
[1]="0.6 percent or 10 cents",
[2]="6 percent or one semitone"
}

function playrateStepProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set the desired step to one of values for step which used by properties with play rate values like as take playrate and etc.", "adjustable")
local state = config.getinteger("rateStep", 1)
message(string.format("Play rate step adjustment %s", self.states[state]))
return message
end

function playrateStepProperty:set(action)
local message = initOutputMessage()
local state = config.getinteger("ratestep", 1)
if action == actions.set.increase then
if (state+1) <= #self.states then
state = state+1
else
return "No more next property values"
end
elseif action == actions.set.decrease then
if state > #self.states then
state = #self.states
end
if (state-1) >= 1 then
state = state-1
else
return "No moreprevious property values"
end
else
return "This property adjustable only."
end
config.setinteger("rateStep", state)
message(self:get())
return message
end

-- Pitch adjustment methods
local pitchStepProperty = {}
configLayout.stepAdjustment:registerProperty( pitchStepProperty)

function pitchStepProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set proposed pitch step to either more or less than current value of step which used by properties with pitch values like as take pitch and etc. Perform this property to input needed custom step value manualy.", "adjustable, performable")
local state = utils.round(config.getinteger("pitchStep", 1.00), 2)
message(string.format("Pitch step adjustment %s", representation.pitch[state]))
return message
end

function pitchStepProperty:set(action)
local message = initOutputMessage()
local state = utils.round(config.getinteger("pitchStep", 1.00), 2)
local ajustingValue
if action == actions.set.increase then
if state >= 0.01 and state < 0.50 then
ajustingValue = 0.50
elseif state >= 0.50 and state < 1.00 then
ajustingValue = 1.00
elseif state >= 1.00 and state < 12.00 then
ajustingValue = 12.00
else
return "Maximal proposed step value"
end
elseif action == actions.set.decrease then
if state > 12.00 then
ajustingValue = 12.00
elseif state <= 12.00 and state > 1.00 then
ajustingValue = 1.00
elseif state <= 1.00 and state > 0.50 then
ajustingValue = 0.50
elseif state <= 0.50 and state > 0.01 then
ajustingValue = 0.01
else
return "Minimal proposed step value"
end
else
local result, answer = reaper.GetUserInputs("Pitch step input", 1, prepareUserData.pitch.formatCaption, representation.pitch[state])
if result == true then
ajustingValue = prepareUserData.pitch.process(answer, state)
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
message(self:get())
return message
end


-- Multiselection support methods
local multiSelectionSupportProperty = {}
configLayout.main:registerProperty( multiSelectionSupportProperty)
function multiSelectionSupportProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to switch the multi-selection support. When multi-selection support is on, if you select a few tracks or items, Properties Ribbon processes all of them. When this option switched off, the track properties processes last touched track instead of selected track, and item processes  last selected item instead of all.", "Toggleable")
local state = config.getboolean("multiSelectionSupport", true)
message(string.format("Multi-selection support %s", ({[true] = "enabled", [false] = "disabled"})[state]))
return message
end

function multiSelectionSupportProperty:set(action)
if action ~= nil then
return "This property is toggleable only."
end
local state = utils.nor(config.getboolean("multiSelectionSupport", true))
config.setboolean("multiSelectionSupport", state)
local message = initOutputMessage() message(self:get())
return message
end

-- Report name methods
local reportNameProperty = {}
configLayout.main:registerProperty(reportNameProperty)

function reportNameProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to switch the reporting element ID information in properties values which this option are supported. If this configuration enabled, a property will report the name of. If this configuration disabled, a property will reportits number only.", "Toggleable")
local state = config.getboolean("reportName", false)
message(string.format("Report element's %s", ({[false]="number only",[true]="name instead of number"})[state]))
return message
end

function reportNameProperty:set(action)
local message = initOutputMessage()
config.setboolean("reportName", utils.nor(config.getboolean("reportName", false)))
message(self:get())
return message
end

-- Automaticaly propose contextual layouts
local autoProposeLayoutProperty = {}
configLayout.main:registerProperty(autoProposeLayoutProperty)

function autoProposeLayoutProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to set the automatic propose a contextual layout when any navigation script is performed. Please note, that this option is not working when you're adjusting, toggling or performing any selected property, so you can modify any selected property until you select any another one.", "Toggleable")
message(string.format("%s contextual layout when navigating", ({[true]="Automaticaly propose",[false]="Switch manualy"})[config.getboolean("automaticLayoutLoading", false)]))
return message
end

function autoProposeLayoutProperty:set(action)
local message = initOutputMessage()
if action == nil then
config.setboolean("automaticLayoutLoading", utils.nor(config.getboolean("automaticLayoutLoading", false)))
message(self:get())
return message
else
return "This property is toggleable only."
end
end

-- Can some properties restore previous layout or not
local allowRestorePreviousProperty = {}
configLayout.main:registerProperty(allowRestorePreviousProperty)

function allowRestorePreviousProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to set the permission to restore previous layout either by some properties or another cases which will be try to do this.", "Toggleable")
message(("%s for some properties to restore previous layout"):format(({[true]="Allow",[false]="Disallow"})[config.getboolean("allowLayoutsrestorePrev", true)]))
return message
end

function allowRestorePreviousProperty:set(action)
if action == nil then
local message = initOutputMessage()
config.setboolean("allowLayoutsrestorePrev", utils.nor(config.getboolean("allowLayoutsrestorePrev", true)))
message(self:get())
return message
else
return "This property is toggleable only."
end
end

local clearFileExtsProperty = {}
configLayout.main:registerProperty(clearFileExtsProperty)

function clearFileExtsProperty:get()
local message = initOutputMessage()
message:initType("Toggle this property to decide the Properties Ribbon scripts should try to detect the file extensions in names and remove them.", "Toggleable")
local state = config.getboolean("clearFileExts", true)
message(string.format("Properties Ribbon should %s to clear a file extensions in some names", ({[true]="try",[false]="not try"})[state]))
return message
end

function clearFileExtsProperty:set(action)
if action == nil then
local message = initOutputMessage()
local state = config.getboolean("clearFileExts", true)
config.setboolean("clearFileExts", utils.nor(state))
message(self:get())
return message
else
return "This property is toggleable only."
end
end

local percentageNavigation = {}
configLayout.main:registerProperty(percentageNavigation)

function percentageNavigation:get()
local message = initOutputMessage()
message:initType("Toggle this property to switch the percentage navigation type off or on. When percentage navigation is on, the actions which sets the property by digits will orient by percentage ratio instead of choosing   a property by digists strictly when properties amount more than ten.", "Toggleable")
local state = config.getboolean("percentagePropertyNavigation", false)
message(string.format("Percentage navigation %s", ({[false]="disabled",[true]="enabled"})[state]))
return message
end

function percentageNavigation:set(action)
local message = initOutputMessage()
config.setboolean("percentagePropertyNavigation", utils.nor(config.getboolean("percentagePropertyNavigation", false)))
message(self:get())
return message
end

return configLayout