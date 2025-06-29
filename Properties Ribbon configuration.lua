--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2025 outsidepro-arts
License: MIT License

----------

Let me say a few word before starts
LUA - is not object oriented programming language, but very flexible. Its flexibility allows to realize OOP easy via metatables. In this scripts the pseudo OOP has been used, therefore we have to understand some terms.
.1 When i'm speaking "Class" i mean the metatable variable with some fields.
2. When i'm speaking "Method" i mean a function attached to a field or submetatable field.
When i was starting write this scripts complex i imagined this as real OOP. But in consequence the scripts structure has been reunderstanded as current structure. It has been turned out more comfort as for writing new properties table, as for call this from main script engine.
After this preambula, let me begin.
]]
--


package.path = select(2, reaper.get_action_context()):match('^.+[\\//]') .. "?//init.lua"

require "properties_ribbon"

useMacros("fx_properties")

-- global pseudoclass initialization
local configLayout = PropertiesRibbon.initLayout("Properties Ribbon configuration")

-- sub-layouts
-- Main sub-layout
configLayout:registerSublayout("main", "General")
configLayout:registerSublayout("stepAdjustment", "Step adjustment")

-- Some specific layout configurations
configLayout:registerSublayout("trackProperties", "Track properties")

--[[
Before the properties list fill get started, let describe this subclass methods:
Method get: gets no one parameter, returns a message string which will be reported in the navigating scripts.
Method set_adjust: the method which will call when user tries to adjust the property. gets parameter action.
direction == actions.set.increase.direction (or 1): the property must changed upward
direction == actions.set.decrease.direction (or -1): the property must changed downward
method set_perform: calls when user tries to perform or toggle the property.
These two methods have to return a output_message object, string or nil. When they return output_message or string, this object will be spoken. When they return nil, nothing will be spoken.

After you finish the methods table you have to return parent class.
No any recomendation more.
Although, no, just one thing:
Try to allow the user to perform actions on both one element and a selected group..
and try to complement any getState message with short type label. I mean what the "ajust" method will perform.
]]
--

-- type level methods
local typeLevelProperty = {}
configLayout.main:registerProperty(typeLevelProperty)
typeLevelProperty.states = {
	[0] = "no prompt for property actions",
	[1] = "detailed prompts for property actions (for beginners)",
	[2] = "short prompts for property actions"
}

function typeLevelProperty:get()
	local message = initOutputMessage()
	local typeLevel = config.getinteger("typeLevel", 1)
	message:initType(
		"Adjust this property to set the desired type prompts level. The type prompts are reports after value message and descripts the appointment of this value.")
	message {
		label = "Types prompts level",
		value = self.states[typeLevel]
	}
	message:setValueFocusIndex(typeLevel + 1, #self.states + 1)
	return message
end

function typeLevelProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("typeLevel", 1)
	if state + direction > #self.states then
		message("No more next property values.")
	elseif state + direction < 0 then
		message("No more previous property values.")
	else
		config.setinteger("typeLevel", state + direction)
	end
	message(self:get())
	return message
end

-- Virtual cursor position reporting methods
local reportPosProperty = {}
configLayout.main:registerProperty(reportPosProperty)
reportPosProperty.states = {
	[0] = "off",
	[1] = "only for categories",
	[2] = "only for properties",
	[3] = "both for categories and properties"
}
function reportPosProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to choose the status of the position reporting when you're navigating through the properties in a ribbon or when you're choose a category in a layout.")
	local state = config.getinteger("reportPos", 3)
	message {
		label = "Reporting navigation position",
		value = self.states[state]
	}
	message:setValueFocusIndex(state + 1, #self.states + 1)
	return message
end

function reportPosProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("reportPos", 3)
	if (state + direction) > #self.states then
		message("No more next property values. ")
	elseif (state + direction) < 0 then
		message("No more previous property values. ")
	else
		config.setinteger("reportPos", state + direction)
	end
	message(self:get())
	return message
end

-- The virtual cursor position for property values
local reportValuePosProperty = configLayout.main:registerProperty {}
reportValuePosProperty.states = {
	[0] = "off",
	[1] = "Only when navigating",
	[2] = "only when adjusting",
	[3] = "Always"
}
function reportValuePosProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to set the position reporting when you're adjusting the discret property values.")
	local state = config.getinteger("reportValuePos", 3)
	message {
		label = "Reporting value position (if available)",
		value = self.states[state]
	}
	message:setValueFocusIndex(state + 1, #self.states + 1)
	return message
end

function reportValuePosProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("reportValuePos", 3)
	if (state + direction) > #self.states then
		message("No more next property values. ")
	elseif (state + direction) < 0 then
		message("No more previous property values. ")
	else
		config.setinteger("reportValuePos", state + direction)
	end
	message(self:get())
	return message
end

-- Remember the last sublayout property
local resetSublayoutProperty = {}
configLayout.main:registerProperty(resetSublayoutProperty)
resetSublayoutProperty.states = {
	[0] = "for not any ",
	[1] = "Only for categories",
	[2] = "Only for properties",
	[3] = "both for categories and properties"
}
function resetSublayoutProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to set the position remembering when you are loading a properties layout which was been loaded earlier.")
	local state = config.getinteger("rememberSublayout", 3)
	message {
		label = "Remember position in layouts when loading",
		value = self.states[state]
	}
	message:setValueFocusIndex(state + 1, #self.states + 1)
	return message
end

function resetSublayoutProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("rememberSublayout", 3)
	if (state + direction) > #self.states then
		message("No more next property values. ")
	elseif (state + direction) < 0 then
		message("No more previous property values. ")
	else
		config.setinteger("rememberSublayout", (state + direction))
	end
	message(self:get())
	return message
end

-- DB step specify methods
local dbStepProperty = {}
configLayout.stepAdjustment:registerProperty(dbStepProperty)

function dbStepProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to set proposed step to either more or less than current value of every step adjustment which works with decibels values like as volume and etc. Perform this property to input needed custom step value manualy.")
	local state = config.getinteger("dbStep", 0.1)
	message {
		label = "Decibel step adjustment",
		value = representation.db[-utils.decibelstonum(state)]
	}
	return message
end

function dbStepProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("dbStep", 0.1)
	local ajustingValue
	if direction == actions.set.increase.direction then
		if state >= 0.01 and state < 0.1 then
			ajustingValue = 0.1
		elseif state >= 0.1 and state < 0.5 then
			ajustingValue = 0.5
		elseif state >= 0.5 and state < 1.0 then
			ajustingValue = 1.0
		else
			return "Maximal step value"
		end
	elseif direction == actions.set.decrease.direction then
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

function dbStepProperty:set_perform()
	local message = initOutputMessage()
	local state = config.getinteger("dbStep", 0.1)
	local ajustingValue
	local result, answer = getUserInputs("Decibel step input", {
		caption = "Step volume value:",
		defValue = representation.db[-utils.decibelstonum(state)]
	}, prepareUserData.db.formatCaption)
	if result == true then
		ajustingValue = utils.numtodecibels(prepareUserData.db.process(answer, utils.numtodecibels(state)))
	else
		return "Canceled."
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
configLayout.stepAdjustment:registerProperty(maxDbProperty)

function maxDbProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to set proposed maximum decibels value  when these properties will be cancel to increase to either more or less than current value Perform this property to input needed custom value manualy.")
	local state = config.getinteger("maxDBValue", 12.0)
	message {
		label = "Maximum decibels value",
		value = representation.db[-utils.decibelstonum(state)]
	}
	return message
end

function maxDbProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("maxDBValue", 12.0)
	local ajustingValue
	if direction == actions.set.increase.direction then
		if state >= 6.0 and state < 12.0 then
			ajustingValue = 12.0
		elseif state >= 12.0 and state < 18.0 then
			ajustingValue = 18.0
		elseif state >= 18.0 and state < 24.0 then
			ajustingValue = 24.0
		else
			return "Maximal value"
		end
	elseif direction == actions.set.decrease.direction then
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
	end
	config.setinteger("maxDBValue", ajustingValue)
	message(self:get())
	return message
end

function maxDbProperty:set_perform()
	local message = initOutputMessage()
	local state = config.getinteger("maxDBValue", 12.0)
	local ajustingValue
	local result, answer = getUserInputs("Maximum decibels value", {
		caption = "Step volume value:",
		defValue = representation.db[-utils.decibelstonum(state)]
	}, prepareUserData.db.formatCaption)
	if result == true then
		ajustingValue = utils.numtodecibels(prepareUserData.db.process(answer, utils.decibelstonum(state)))
	else
		return "Canceled."
	end
	config.setinteger("maxDBValue", ajustingValue)
	message(self:get())
	return message
end

-- Percentage step adjustment methods
local percentagestepProperty = {}
configLayout.stepAdjustment:registerProperty(percentagestepProperty)

function percentagestepProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to set proposed step to either more or less than current value of percentage step which used by properties with percentage values like as pan, width and etc. Perform this property to input needed custom step value manualy.")
	local state = config.getinteger("percentStep", 1)
	message {
		label = "Percent step adjustment",
		value = string.format("%s%%", state)
	}
	return message
end

function percentagestepProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("percentStep", 1)
	local ajustingValue
	if direction == actions.set.increase.direction then
		if state >= 1 and state < 5 then
			ajustingValue = 5
		elseif state >= 5 and state < 10 then
			ajustingValue = 10
		else
			return "Maximal step value"
		end
	elseif direction == actions.set.decrease.direction then
		if state > 10 then
			ajustingValue = 10
		elseif state <= 10 and state > 5 then
			ajustingValue = 5
		elseif state <= 5 and state > 1 then
			ajustingValue = 1
		else
			return "Minimal step value"
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

function percentagestepProperty:set_perform()
	local message = initOutputMessage()
	local state = config.getinteger("percentStep", 1)
	local ajustingValue
	local result, answer = getUserInputs("Percent step input", {
		caption = "Step percent value:",
		defValue = string.format("%u%%", state)
	}, prepareUserData.percent.formatCaption)
	if result == true then
		ajustingValue = utils.numtopercent(prepareUserData.percent.process(answer, utils.percenttonum(state)))
	else
		return "Canceled."
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
configLayout.stepAdjustment:registerProperty(timeStepProperty)

function timeStepProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to set proposed time step to either more or less than current value of time step which used by properties with time values like as fade in and out lengths and etc. Perform this property to input needed custom step value manualy.")
	local state = config.getinteger("timeStep", 0.001)
	message {
		label = "Time step adjustment",
		value = representation.timesec[state]
	}
	return message
end

function timeStepProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("timeStep", 0.001)
	local ajustingValue
	if direction == actions.set.increase.direction then
		if state >= 0.001 and state < 0.010 then
			ajustingValue = 0.010
		elseif state >= 0.010 and state < 0.100 then
			ajustingValue = 0.100
		elseif state >= 0.100 and state < 1.000 then
			ajustingValue = 1.000
		else
			return "Maximal step value"
		end
	elseif direction == actions.set.decrease.direction then
		if state > 1.000 then
			ajustingValue = 1.000
		elseif state <= 1.000 and state > 0.100 then
			ajustingValue = 0.100
		elseif state <= 0.100 and state > 0.010 then
			ajustingValue = 0.010
		elseif state <= 0.010 and state > 0.001 then
			ajustingValue = 0.001
		else
			return "Minimal step value"
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

function timeStepProperty:set_perform()
	local message = initOutputMessage()
	local state = config.getinteger("timeStep", 0.001)
	local ajustingValue
	local result, answer = getUserInputs("Time step input", {
			caption = "Time step value:",
			defValue = state
		},
		'Type the needed step which every property with time value will change per one adjustment in decimal format but no more three digits after decimal separator (0.1, 1.25, 3.201 and etc).')
	if result == true then
		ajustingValue = tonumber(answer)
	else
		return "Canceled."
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
	[1] = "0.6 percent or 10 cents",
	[2] = "6 percent or one semitone"
}

function playrateStepProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to set the desired step to one of values for step which used by properties with play rate values like as take playrate and etc.")
	local state = config.getinteger("rateStep", 1)
	message {
		label = "Play rate step adjustment",
		value = self.states[state]
	}
	return message
end

function playrateStepProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("ratestep", 1)
	if (state + direction) > #self.states then
		return "No more next property values"
	elseif (state + direction) < 1 then
		return "No moreprevious property values"
	else
		state = state + direction
	end
	config.setinteger("rateStep", state)
	message(self:get())
	return message
end

-- Pitch adjustment methods
local pitchStepProperty = {}
configLayout.stepAdjustment:registerProperty(pitchStepProperty)

function pitchStepProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to set proposed pitch step to either more or less than current value of step which used by properties with pitch values like as take pitch and etc. Perform this property to input needed custom step value manualy.")
	local state = math.round(config.getinteger("pitchStep", 1.00), 2)
	message {
		label = "Pitch step adjustment",
		value = representation.pitch[state]
	}
	return message
end

function pitchStepProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = math.round(config.getinteger("pitchStep", 1.00), 2)
	local ajustingValue
	if direction == actions.set.increase.direction then
		if state >= 0.01 and state < 0.50 then
			ajustingValue = 0.50
		elseif state >= 0.50 and state < 1.00 then
			ajustingValue = 1.00
		elseif state >= 1.00 and state < 12.00 then
			ajustingValue = 12.00
		else
			return "Maximal proposed step value"
		end
	elseif direction == actions.set.decrease.direction then
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

function pitchStepProperty:set_perform()
	local message = initOutputMessage()
	local state = math.round(config.getinteger("pitchStep", 1.00), 2)
	local ajustingValue
	local result, answer = getUserInputs("Pitch step input", {
		caption = "Pitch step value:",
		defValue = representation.pitch[state]
	}, prepareUserData.pitch.formatCaption)
	if result == true then
		ajustingValue = prepareUserData.pitch.process(answer, state)
	else
		return "Canceled."
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

local pitchBouncesProperty = {}
configLayout.stepAdjustment:registerProperty(pitchBouncesProperty)

function pitchBouncesProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to set the desired value either more or less than the pitch properties will not adjust. Perform this property to type the custom pitch bounces value manualy.")
	local state = config.getinteger("pitchBounces", 24.0)
	message {
		label = "Pitch bounces",
		value = representation.pitch[state]
	}
	return message
end

function pitchBouncesProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("pitchBounces", 24.0)
	local ajustingValue
	if direction == actions.set.increase.direction then
		if state >= 6.0 and state < 12.0 then
			ajustingValue = 12.0
		elseif state >= 12.0 and state < 18.0 then
			ajustingValue = 18.0
		elseif state >= 18.0 and state < 24.0 then
			ajustingValue = 24.0
		else
			return "Maximal value"
		end
	elseif direction == actions.set.decrease.direction then
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
	end
	config.setinteger("pitchBounces", ajustingValue)
	message(self:get())
	return message
end

function pitchBouncesProperty:set_perform()
	local message = initOutputMessage()
	local state = config.getinteger("pitchBounces", 24.0)
	local ajustingValue
	local result, answer = getUserInputs("Pitch bounces value", {
		caption = "Pitch step value:",
		defValue = representation.pitch[state]
	}, prepareUserData.pitch.formatCaption)
	if result == true then
		ajustingValue = prepareUserData.pitch.process(answer, state)
	else
		return "Canceled."
	end
	config.setinteger("pitchBounces", ajustingValue)
	message(self:get())
	return message
end

-- Multiselection support methods
local multiSelectionSupportProperty = {}
configLayout.main:registerProperty(multiSelectionSupportProperty)
function multiSelectionSupportProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to switch the multi-selection support. When multi-selection support is on, if you select a few tracks or items, Properties Ribbon processes all of them. When this option switched off, the track properties processes last touched track instead of selected track, and item processes  last selected item instead of all.",
		"Toggleable")
	local state = config.getboolean("multiSelectionSupport", true)
	message {
		label = "Multi-selection support",
		value = ({
			[true] = "enabled",
			[false] = "disabled"
		})[state]
	}
	return message
end

function multiSelectionSupportProperty:set_perform()
	local state = nor(config.getboolean("multiSelectionSupport", true))
	config.setboolean("multiSelectionSupport", state)
	local message = initOutputMessage()
	message(self:get())
	return message
end

-- Report name methods
local reportNameProperty = {}
configLayout.main:registerProperty(reportNameProperty)

function reportNameProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to switch the reporting element ID information in properties values which this option are supported.",
		"Toggleable")
	local state = config.getboolean("reportName", false)
	message {
		label = "Report element's",
		value = ({
			[false] = "number only",
			[true] = "name instead of number"
		})[state]
	}
	return message
end

function reportNameProperty:set_perform()
	local message = initOutputMessage()
	config.setboolean("reportName", nor(config.getboolean("reportName", false)))
	message(self:get())
	return message
end

-- Truncate the identification namesby specified symbols length
local truncateIdByProperty = {}
configLayout.main:registerProperty(truncateIdByProperty)
truncateIdByProperty.states = { 5, 10, 25, 50 }

function truncateIdByProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to specify the length for name should be truncated when the report names identification configuration is enabled. Perform this property to specify the custom value for.")
	local depend = config.getboolean("reportName", false)
	if depend == false then
		message:addType(" This property is unavailable right now because the report name configuration isn't set.", 1)
		message:changeType("Unavailable", 2)
	end
	local state = config.getinteger("truncateIdBy", 0)
	message {
		label = "Truncate the names identification"
	}
	if depend then
		if state > 0 then
			message {
				value = string.format("By %u symbols", state)
			}
		else
			message {
				value = "Off"
			}
		end
	else
		message {
			value = "Unavailable"
		}
	end
	return message
end

function truncateIdByProperty:set_adjust(direction)
	local depend = config.getboolean("reportName", false)
	if depend then
		local message = initOutputMessage()
		local state = config.getinteger("truncateIdBy", 0)
		if direction == actions.set.increase.direction then
			if state < 5 then
				config.setinteger("truncateIdBy", 5)
			elseif state >= 5 and state < 10 then
				config.setinteger("truncateIdBy", 10)
			elseif state >= 10 and state < 25 then
				config.setinteger("truncateIdBy", 25)
			elseif state >= 25 and state < 50 then
				config.setinteger("truncateIdBy", 50)
			elseif state >= 50 then
				message("No more next property values.")
			end
		elseif direction == actions.set.decrease.direction then
			if state > 50 then
				config.setinteger("truncateIdBy", 50)
			elseif state <= 50 and state > 25 then
				config.setinteger("truncateIdBy", 25)
			elseif state <= 25 and state > 10 then
				config.setinteger("truncateIdBy", 10)
			elseif state <= 10 and state > 5 then
				config.setinteger("truncateIdBy", 5)
			elseif state <= 5 and state > 0 then
				config.setinteger("truncateIdBy", 0)
			elseif state == 0 then
				message("No more previous property values.")
			end
		end
		message(self:get())
		return message
	end
	return "This property is unavailable right now because the report names option is disabled."
end

function truncateIdByProperty:set_perform()
	local depend = config.getboolean("reportName", false)
	if depend then
		local message = initOutputMessage()
		local state = config.getinteger("truncateIdBy", 0)
		local getValue = self:get()
		local retval, answer = getUserInputs("Truncate value", {
				caption = "Amount of symbols:",
				defValue = getValue:extract(2, false):gsub("By ", "")
			},
			'Type the needed length value the name identification should be truncated. Type \"Off\" to disable the truncation.')
		if not retval then
			return
		end
		answer = prepareUserData.basic(answer)
		if answer:match("^%d+") then
			config.setinteger("truncateIdBy", tonumber(answer:match("^%d+")))
		else
			if answer:find("off") then
				config.setinteger("truncateIdBy", 0)
			else
				msgBox("Properties Ribbon error", "Couldn't extract any expected value.")
			end
		end
		message(self:get())
		return message
	end
	return "This property is unavailable right now because the report names option is disabled."
end

-- Automaticaly propose contextual layouts
local autoProposeLayoutProperty = {}
configLayout.main:registerProperty(autoProposeLayoutProperty)

function autoProposeLayoutProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to set the automatic propose a contextual layout when any navigation script is performed. Please note, that this option is not working when you're adjusting, toggling or performing any selected property, so you can modify any selected property until you select any another one.",
		"Toggleable")
	message {
		label = "Contextual layout when navigating",
		value = ({
			[true] = "proposed automaticaly",
			[false] = "must be switched manualy"
		})[config.getboolean("automaticLayoutLoading", false)]
	}
	return message
end

function autoProposeLayoutProperty:set_perform()
	local message = initOutputMessage()
	config.setboolean("automaticLayoutLoading", nor(config.getboolean("automaticLayoutLoading", false)))
	message(self:get())
	return message
end

-- Can some properties restore previous layout or not
local allowRestorePreviousProperty = {}
configLayout.main:registerProperty(allowRestorePreviousProperty)

function allowRestorePreviousProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to set the permission to restore previous layout either by some properties or another cases which will be try to do this.",
		"Toggleable")
	message {
		label = "Allow for some properties to restore previous layout",
		value = ({
			[true] = "enabled",
			[false] = "disabled"
		})[config.getboolean("allowLayoutsrestorePrev", true)]
	}
	return message
end

function allowRestorePreviousProperty:set_perform()
	local message = initOutputMessage()
	config.setboolean("allowLayoutsrestorePrev", nor(config.getboolean("allowLayoutsrestorePrev", true)))
	message(self:get())
	return message
end

-- Allow some properties to move play cursor when you're navigating to
local allowMoveCursorProperty = {}
configLayout.main:registerProperty(allowMoveCursorProperty)

function allowMoveCursorProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to define can some properties be move the play or edit cursor when you're just navigating them",
		"Toggleable")
	message {
		label = "Allow some properties to move play cursor when you're just navigating them",
		value = ({
			[true] = "enabled",
			[false] = "disabled"
		})[config.getboolean("allowMoveCursorWhenNavigating", true)]
	}
	return message
end

function allowMoveCursorProperty:set_perform()
	local message = initOutputMessage()
	local state = config.getboolean("allowMoveCursorWhenNavigating", true)
	config.setboolean("allowMoveCursorWhenNavigating", nor(state))
	message(self:get())
	return message
end

local clearFileExtsProperty = {}
configLayout.main:registerProperty(clearFileExtsProperty)

function clearFileExtsProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to decide the Properties Ribbon scripts should try to detect the file extensions in names and remove them.",
		"Toggleable")
	local state = config.getboolean("clearFileExts", true)
	message {
		label = "Clear the extensions of filenames when it found somewhere",
		value = ({
			[true] = "enabled",
			[false] = "disabled"
		})[state]
	}
	return message
end

function clearFileExtsProperty:set_perform()
	local message = initOutputMessage()
	local state = config.getboolean("clearFileExts", true)
	config.setboolean("clearFileExts", nor(state))
	message(self:get())
	return message
end

local percentageNavigation = {}
configLayout.main:registerProperty(percentageNavigation)

function percentageNavigation:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to switch the percentage navigation type off or on. When percentage navigation is on, the actions which sets the property by digits will orient by percentage ratio instead of choosing   a property by digists strictly when properties amount more than ten.",
		"Toggleable")
	local state = config.getboolean("percentagePropertyNavigation", false)
	message {
		label = "Percentage navigation",
		value = ({
			[false] = "disabled",
			[true] = "enabled"
		})[state]
	}
	return message
end

function percentageNavigation:set_perform()
	local message = initOutputMessage()
	config.setboolean("percentagePropertyNavigation", nor(config.getboolean("percentagePropertyNavigation", false)))
	message(self:get())
	return message
end

local fxParmstepProperty = {}
configLayout.stepAdjustment:registerProperty(fxParmstepProperty)

function fxParmstepProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to choose needed default step value for FX parameters the adjusting process will search next or previous parameter value. Please note that you also may set the step value for every parameter independently, then this configuration will be omited for.")
	local state = config.getinteger("fxParmStep", 4)
	message {
		label = "FX parameters step adjustment",
		value = fx_properties_macros.stepsList[state].label
	}
	message:setValueFocusIndex(state + 1, #fx_properties_macros.stepsList + 1)
	return message
end

function fxParmstepProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("fxParmStep", 4)
	if (state + direction) > #fx_properties_macros.stepsList then
		message("No more next property values.")
	elseif (state + direction) < 1 then
		message("No more previous property values.")
	else
		config.setinteger("fxParmStep", state + direction)
	end
	message(self:get())
	return message
end

configLayout:registerSublayout("fxPropertiesConfig", "FX properties")

local fxUseNearestParmValueProperty = {}
configLayout.fxPropertiesConfig:registerProperty(fxUseNearestParmValueProperty)

function fxUseNearestParmValueProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to switch the configuration which that FX properties will be search nearest parameter value automatically.",
		"Toggleable")
	local state = config.getboolean("fx_useFindNearestParmValue", true)
	message {
		label = "Automatic searching nearest parameter value when adjusting",
		value = ({
			[true] = "enabled",
			[false] = "disabled"
		})[state]
	}
	return message
end

function fxUseNearestParmValueProperty:set_perform()
	config.setboolean("fx_useFindNearestParmValue", nor(config.getboolean("fx_useFindNearestParmValue", true)))
	local message = initOutputMessage()
	message(self:get())
	return message
end

local reportParmIndexProperty = {}
configLayout.fxPropertiesConfig:registerProperty(reportParmIndexProperty)
reportParmIndexProperty.states = {
	[0] = "off",
	"reports parameter number only",
	"reports parameter prefix and its number"
}

function reportParmIndexProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to choose the report method of the parameter identification prefix when navigating.")
	local state = config.getinteger("reportParmId", 2)
	message {
		label = "Parameter identification when navigating",
		value = self.states[state]
	}
	message:setValueFocusIndex(state + 1, #self.states + 1)
	return message
end

function reportParmIndexProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("reportParmId", 2)
	if (state + direction) > #self.states then
		message("No more next property values.")
	elseif (state + direction) < 0 then
		message("No more previous property values.")
	else
		config.setinteger("reportParmId", state + direction)
	end
	message(self:get())
	return message
end

local reportRealParmValueProperty = {}
configLayout.fxPropertiesConfig:registerProperty(reportRealParmValueProperty)
reportRealParmValueProperty.states = { "incremental as it rendered", "real" }

function reportRealParmValueProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to set the reporting parameter number behavior.")
	local state = config.getinteger("reportParmMethod", 1)
	message {
		label = "Report FX parameter number when navigating as",
		value = self.states[state]
	}
	message:setValueFocusIndex(state + 1, #self.states + 1)
	return message
end

function reportRealParmValueProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("reportParmMethod", 1)
	if (state + direction) > #self.states then
		message("No more next parameter values.")
	elseif (state + direction) < 1 then
		message("No more previous property values.")
	else
		config.setinteger("reportParmMethod", state + direction)
	end
	message(self:get())
	return message
end

configLayout:registerSublayout("fxExcludeList", "FX parameters exclude list")

local fxMaskList = fx_properties_macros.fxMaskList

for i = 1, #fxMaskList do
	local fxExcludeElem = fxMaskList[i]
	local excludeElementProperty = {}
	configLayout.fxExcludeList:registerProperty(excludeElementProperty)
	function excludeElementProperty:get()
		local message = initOutputMessage()
		message:initType("", "")
		message(string.format("FX mask %u %s, parameter mask %s", i, fxExcludeElem.fxMask, fxExcludeElem.paramMask))
		return message
	end

	excludeElementProperty.extendedProperties = PropertiesRibbon.initExtendedProperties("Context actions")
	excludeElementProperty.states = { excludeElementProperty.extendedProperties:registerProperty {
		-- The methods written below get second parameter but Lua allows s to omit this if it's not needed.
		get = function()
			local message = initOutputMessage()
			message:initType("Perform this property to edit this exclude mask.")
			message "Edit"
			return message
		end,
		set_perform = function(self)
			local retval, answer = getUserInputs("Edit exclude mask", { {
					caption = "FX plug-in filename mask:",
					defValue = fxExcludeElem.fxMask
				}, {
					caption = "Parameter mask:",
					defValue = fxExcludeElem.paramMask
				} },
				"Type the condition mask below which parameter should be excluded. The Lua patterns are supported per every field.")
			if retval then
				local newFxMask, newParamMask = table.unpack(answer)
				if newFxMask == nil then
					msgBox("Edit mask error", "The FX mask should be filled.")
					return false
				end
				if newParamMask == nil then
					msgBox("Edit mask error", "The parameter mask should be filled.")
					return false
				end
				fxMaskList[i] = {
					fxMask = newFxMask,
					paramMask = newParamMask
				}
				return true, "", true
			end
			return false
		end
	}, excludeElementProperty.extendedProperties:registerProperty {
		get = function()
			local message = initOutputMessage()
			message:initType("Perform this property to delete this exclude mask.")
			message "Delete"
			return message
		end,
		set_perform = function(self)
			if msgBox("Delete mask", string.format('Are you sure want to delete this mask?\nFX mask: %s\nParameter mask: %s',
					fxExcludeElem.fxMask, fxExcludeElem.paramMask), "yesno") ==
				showMessageBoxConsts.button.yes then
				fxMaskList[i] = nil
				return true, ""
			end
			return false
		end
	} }
end

local addExcludeMaskProperty = {}
configLayout.fxExcludeList:registerProperty(addExcludeMaskProperty)

function addExcludeMaskProperty:get()
	local message = initOutputMessage()
	message:initType("Perform this property to add new exclude mask.")
	message("Add new exclude mask")
	return message
end

function addExcludeMaskProperty:set_perform()
	local retval, answer = getUserInputs("Add new exclude mask", { {
			caption = "FX plug-in filename mask:"
		}, {
			caption = "Parameter mask:"
		} },
		"Type the condition mask below which parameter should be excluded. The Lua patterns are supported per every field.")
	if retval then
		local newFxMask, newParamMask = table.unpack(answer)
		if newFxMask == nil then
			msgBox("Edit mask error", "The FX mask should be filled.")
			return
		end
		if newParamMask == nil then
			msgBox("Edit mask error", "The parameter mask should be filled.")
			return
		end
		fxMaskList[#fxMaskList + 1] = {
			fxMask = newFxMask,
			paramMask = newParamMask
		}
	end
end

local outputOrderProperty = {}
configLayout.main:registerProperty(outputOrderProperty)
outputOrderProperty.states = {
	[0] = "object identification, name and value",
	"label and value",
	"value only"
}

function outputOrderProperty:get()
	local message = initOutputMessage()
	message:initType("Adjust this property to choose needed output order when you're adjusting a property.")
	local state = config.getinteger("adjustOutputOrder", 0)
	message {
		label = "Output when adjusting a property",
		value = self.states[state]
	}
	message:setValueFocusIndex(state + 1, #self.states + 1)
	return message
end

function outputOrderProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("adjustOutputOrder", 0)
	if (state + direction) > #self.states then
		message("No more next property values.")
	elseif (state + direction) < 0 then
		message("No more previous property values.")
	else
		config.setinteger("adjustOutputOrder", state + direction)
	end
	message(self:get())
	return message
end

-- Allow to switch off the identification
local disableIdentificationProperty = {}
configLayout.main:registerProperty(disableIdentificationProperty)

function disableIdentificationProperty:get()
	local message = initOutputMessage()
	message:initType("Toggle this property to switch the object identification when navigating.", "Toggleable")
	local state = config.getboolean("objectsIdentificationWhenNavigating", true)
	message {
		label = "Report objects identification when navigating",
		value = ({
			[true] = "enabled",
			[false] = "disabled"
		})[state]
	}
	return message
end

function disableIdentificationProperty:set_perform()
	local message = initOutputMessage()
	config.setboolean("objectsIdentificationWhenNavigating",
		nor(config.getboolean("objectsIdentificationWhenNavigating", true)))
	message(self:get())
	return message
end

local twicePressPerformProperty = configLayout.main:registerProperty {}
twicePressPerformProperty.states = {
	"Does nothing",
	"Report the property value only",
	"Performs this (if perform action supported)"
}

function twicePressPerformProperty:get()
	local message = initOutputMessage()
	local state = config.getinteger("twicePressPerforms", 1)
	message {
		label = "Twice navigation onto the same property",
		value = self.states[state]
	}
	message:setValueFocusIndex(state + 1, #self.states + 1)
	message:initType(
		"Adjust this property to choose the needed behaviour when you're navigate to the same property twice straightaway.")
	return message
end

function twicePressPerformProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("twicePressPerforms", 1)
	if state + direction > #self.states then
		message("No more next property values.")
	elseif state + direction < 1 then
		message("No more previous property values.")
	else
		config.setinteger("twicePressPerforms", state + direction)
	end
	message(self:get())
	return message
end

local selectFXProperty = {}
configLayout.fxPropertiesConfig:registerProperty(selectFXProperty)
selectFXProperty.states = {
	[false] = "disabled",
	[true] = "enabled"
}

function selectFXProperty:get()
	local message = initOutputMessage()
	local state = config.getboolean("selectFXWhenFocusOn", false)
	message {
		label = "Attempt select focused FX in FX chain",
		value = self.states[state]
	}
	message:initType(
		"Toggle this property the ability FX properties attempt to select an FX which you're working on. Please note that not all of FX can be selected. SWS is used for this operation, but SWS does not support the take FX chains, track input FX chains and monitoring FX chains.")
	return message
end

function selectFXProperty:set_perform()
	local message = initOutputMessage()
	config.setboolean("selectFXWhenFocusOn", nor(config.getboolean("selectFXWhenFocusOn", false)))
	message(self:get())
	return message
end

local excludeEmptyParamsProperty = {}
configLayout.fxPropertiesConfig:registerProperty(excludeEmptyParamsProperty)
excludeEmptyParamsProperty.states = {
	[false] = "disabled",
	[true] = "enabled"
}

function excludeEmptyParamsProperty:get()
	local message = initOutputMessage()
	local state = config.getboolean("ignoreEmptyStringFXParams", true)
	message {
		label = "Ignore the empty and non-letter parameters",
		value = self.states[state]
	}
	message:initType(
		"Toggle this property to switch the option which allows to exclude the parameters which contains no name or its name contains only non-letter characters.",
		"Toggleable"
	)
	return message
end

function excludeEmptyParamsProperty:set_perform()
	local message = initOutputMessage()
	config.setboolean("ignoreEmptyStringFXParams", nor(config.getboolean("ignoreEmptyStringFXParams", true)))
	message(self:get())
	return message
end

local tempoStepProperty = {}
configLayout.stepAdjustment:registerProperty(tempoStepProperty)

function tempoStepProperty:get()
	local message = initOutputMessage()
	local state = config.getinteger("tempoStep", 1.000)
	message {
		label = "Tempo step adjustment",
		value = string.format("%s BPM", math.round(state, 3))
	}
	message:initType(
		"Adjust this property to set proposed step to either more or less than current value of every step adjustment which works with tempo values. Perform this property to input needed custom step value manualy.")
	return message
end

function tempoStepProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = config.getinteger("tempoStep", 1.000)
	local ajustingValue
	if direction == actions.set.increase.direction then
		if state >= 0.100 and state < 0.500 then
			ajustingValue = 0.500
		elseif state >= 0.500 and state < 1.000 then
			ajustingValue = 1.000
		else
			message "Maximal step value."
		end
	elseif direction == actions.set.decrease.direction then
		if state <= 1.000 and state > 0.500 then
			ajustingValue = 0.500
		elseif state <= 0.500 and state > 0.100 then
			ajustingValue = 0.100
		else
			message "Minimal step value."
		end
	end
	if ajustingValue then
		config.setinteger("tempoStep", ajustingValue)
	end
	message(self:get())
	return message
end

function tempoStepProperty:set_perform()
	local state = config.getinteger("tempoStep", 1.000)
	local retval, answer = getUserInputs("Tempo step input", {
		caption = "Tempo step value:",
		defValue = string.format("%.3f BPM", math.round(state, 3))
	}, prepareUserData.tempo.formatCaption)
	if retval then
		local ajustingValue = prepareUserData.tempo.process(answer, state)
		if ajustingValue < 200 and ajustingValue > 0.001 then
			config.setinteger("tempoStep", ajustingValue)
		elseif ajustingValue >= 200 then
			if msgBox("Just one question",
					"Are you sure you want to set the step value more than 200 BPM per one adjustment? Are you seriously? 😦", "yesno") == showMessageBoxConsts.button.yes then
				config.setinteger("tempoStep", ajustingValue)
			end
		elseif ajustingValue < 0.001 then
			msgBox("Tempo step value specify error", "Set the tempo step as less than zero is pointless.")
		end
	end
end

-- The label and value divider setting
local lvDivider = configLayout.main:registerProperty {}
lvDivider.states = {
	{ char = nil, label = "off" },
	{ char = ":", label = "colon" },
	{ char = ".", label = "dot" },
	{ char = ",", label = "coma" }
}

function lvDivider.getValue(char)
	for index, charObj in ipairs(lvDivider.states) do
		if char == charObj.char then
			return index
		end
	end
end

function lvDivider:get()
	local message = initOutputMessage()
	message:initType(
		"Adjust this property to choose a pre-defined character for label and value dividing. Perform this property to type needed character manualy.")
	local state = config.getstring("lvDivider")
	message { label = "Divide the property label and value", }
	if state then
		local charIndex = self.getValue(state)
		if charIndex then
			message { value = string.format("by %s character", self.states[charIndex].label) }
			message:setValueFocusIndex(charIndex + 1, #self.states + 1)
		else
			message { value = string.format("by %s", state) }
		end
	else
		message { value = "off" }
	end
	return message
end

function lvDivider:set_adjust(direction)
	local message = initOutputMessage()
	local state = self.getValue(config.getstring("lvDivider"))
	if state then
		if (state + direction) > #self.states then
			message("No more next property values. ")
		elseif (state + direction) < 1 then
			message("No more previous property values. ")
		else
			config.setstring("lvDivider", self.states[state + direction].char)
		end
	else
		config.setstring("lvDivider", self.states[1].char)
	end
	message(self:get())
	return message
end

function lvDivider:set_perform()
	local retval, answer = getUserInputs("Specify the label and value divider", {
		caption = "Type a new character:",
		defValue = config.getstring("lvDivider")
	})
	if retval then
		config.setstring("lvDivider", answer)
	else
		return "Canceled."
	end
end

local obeyConfigSolo = configLayout.trackProperties:registerProperty {}
obeyConfigSolo.states = {
	[true] = "enabled",
	[false] = "disabled"
}

function obeyConfigSolo:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property if you  want to set up the solo track property has applies the solo using default configuration of solo-in-place set in REAPER preferences instead of last selected mode when adjusted.",
		"Toggleable"
	)
	local state = config.getboolean("obeyConfigSolo", true)
	message {
		label = "use default configuration of solo-in-place set in REAPER preferences when solo property toggles",
		value = self.states[state]
	}
	return message
end

function obeyConfigSolo:set_perform()
	local message = initOutputMessage()
	local state = config.getboolean("obeyConfigSolo", true)
	config.setboolean("obeyConfigSolo", nor(state))
	message(self:get())
	return message
end

local exclusiveSolo = configLayout.trackProperties:registerProperty {}
exclusiveSolo.states = obeyConfigSolo.states

function exclusiveSolo:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to apply the solo mode exclusively when solo property toggles. The solo exclusive means that only selected tracks will soloed, but other tracks will be unsoloed forcedly.",
		"Toggleable"
	)
	local state = config.getboolean("exclusiveSolo", false)
	message {
		label = "Use exclusive solo when solo property toggles",
		value = self.states[state]
	}
	return message
end

function exclusiveSolo:set_perform()
	local message = initOutputMessage()
	local state = config.getboolean("exclusiveSolo", false)
	config.setboolean("exclusiveSolo", nor(state))
	message(self:get())
	return message
end

local exclusiveArm = configLayout.trackProperties:registerProperty {}
exclusiveArm.states = {
	[true] = "enabled",
	[false] = "disabled"
}

function exclusiveArm:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to apply the arm mode exclusively when arm property toggles. The arm exclusive means that only selected tracks will armed, but other tracks will be unarm forcedly.",
		"Toggleable"
	)
	local state = config.getboolean("exclusiveArm", false)
	message {
		label = "Use exclusive arm when arm property toggles",
		value = self.states[state]
	}
	return message
end

function exclusiveArm:set_perform()
	local message = initOutputMessage()
	local state = config.getboolean("exclusiveArm", false)
	config.setboolean("exclusiveArm", nor(state))
	message(self:get())
	return message
end

local donotUseSmallFolderStateProperty = configLayout.trackProperties:registerProperty {}
donotUseSmallFolderStateProperty.states = {
	[true] = "enabled",
	[false] = "disabled"
}

function donotUseSmallFolderStateProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property to switch off the use of small folder state when you're toggling a track folder state property.",
		"Toggleable"
	)
	local state = config.getboolean("donotUseSmallFolderState", false)
	message {
		label = "Don't use small folder state in track folder views",
		value = self.states[state]
	}
	return message
end

function donotUseSmallFolderStateProperty:set_perform()
	local message = initOutputMessage()
	local state = config.getboolean("donotUseSmallFolderState", false)
	config.setboolean("donotUseSmallFolderState", nor(state))
	message(self:get())
	return message
end

-- Set up the step adjustment for FX properties foreverely or per loaded REAPER session
local useForeverStepAdjustmentProperty = configLayout.fxPropertiesConfig:registerProperty {}
useForeverStepAdjustmentProperty.states = {
	[true] = "enabled",
	[false] = "disabled"
}

function useForeverStepAdjustmentProperty:get()
	local message = initOutputMessage()
	message:initType(
		"Toggle this property on to set the step adjustment save foreverely for plug-ins. Toggle this property off to FX properties forget the step adjustment after REAPER closing.",
		"Toggleable")
	local state = config.getboolean("useForeverFXStepAdjustment", false)
	message {
		label = "Save the step adjustment per FX parameters foreverely",
		value = self.states[state]
	}
	return message
end

function useForeverStepAdjustmentProperty:set_perform()
	local message = initOutputMessage()
	local state = config.getboolean("useForeverFXStepAdjustment", false)
	config.setboolean("useForeverFXStepAdjustment", nor(state))
	message(self:get())
	return message
end

PropertiesRibbon.presentLayout(configLayout)
