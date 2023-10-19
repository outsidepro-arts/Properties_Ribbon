--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License

----------

Let me say a few word before starts
LUA - is not object oriented programming language, but very flexible. Its flexibility allows to realize OOP easy via metatables. In this scripts the pseudo OOP has been used, therefore we have to understand some terms.
.1 When i'm speaking "Class" i mean the metatable variable with some fields.
2. When i'm speaking "Method" i mean a function attached to a field or submetatable field.
When i was starting write this scripts complex i imagined this as real OOP. But in consequence the scripts structure has been reunderstanded as current structure. It has been turned out more comfort as for writing new properties table, as for call this from main script engine.
After this preambula, let me begin.
]] --

package.path = select(2, reaper.get_action_context()):match('^.+[\\//]') .. "?//init.lua"

require "properties_ribbon"


-- We need the actions macros
useMacros("actions")

-- global pseudoclass initialization
local parentLayout = initLayout("State management")

parentLayout.undoContext = undo.contexts.any

parentLayout:registerSublayout("options", "Options")
parentLayout:registerSublayout("areas", "Areas and panels")
parentLayout:registerSublayout("windows", "Windows")

-- Usual methods and fields
-- They will be coppied into easy switching methods.
-- Usually, the windows defines through action states. So let me to not write too many code.

local usualOptStates = { [0] = "off", [1] = "on" }
local usualAreaStates = { [0] = "hidden", [1] = "shown" }
local usualWindowStates = { [0] = "Open", [1] = "Close" }

local function setWindow(self, action)
	if action ~= nil then
		return "This property is toggleable only."
	end
	local message = initOutputMessage()
	states = { [0] = "closed", [1] = "opened" }
	local state = nor(self.getValue())
	self.setValue(state)
	local label = self:get():extract(false)
	message(string.format("%s has been %s", label:match("^%w+%s(.+)"), states[self.getValue()]))
	if self.getValue() == 0 then
		return message
	end
	setUndoLabel(message)
	return ""
end

-- Master track visibility
parentLayout.areas:registerProperty(
	composeExtendedSwitcherProperty(
		usualAreaStates,
		40075,
		"Master track %s",
		{ "Toggle this property to show or hide the master track in this project.", "toggleable" }
	)
)

-- Mixer visibility
-- Has a problem  while hidding: Set method reports previous state. Seems, the action status changes slowly. Still needs to fix this
-- we need the getValue method from.
local mixerProperty = composeExtendedSwitcherProperty(
	usualAreaStates,
	40078,
	"Mixer %s",
	{ "Toggle this property to show or hide the mixer area. Please note: when the mixer area is hidden, the docker property is not available.",
		"toggleable" }
)
parentLayout.areas:registerProperty(mixerProperty)

-- Docker visibility
-- if mixer hidden, the docker couldn't be displayed.
if mixerProperty.getValue() == 1 then
	local dockerProperty = composeExtendedSwitcherProperty(
		usualAreaStates,
		40313,
		"Docker %s",
		{ "Toggle this property to show or hide the docker area.", "toggleable" }
	)
	-- Injecting the specific methods call to our template
	function dockerProperty.setValue(value)
		reaper.Main_OnCommand(40313, value)
		reaper.DockWindowRefresh()
	end

	parentLayout.areas:registerProperty(dockerProperty)
end

-- Transport panel visibility
parentLayout.areas:registerProperty(
	composeExtendedSwitcherProperty(
		usualAreaStates,
		40259,
		"Transport %s",
		{ "Toggle this property to show or hide the transport panel.", "toggleable" }
	)
)

-- FX browser window
parentLayout.windows:registerProperty(
	composeExtendedSwitcherProperty(
		usualWindowStates,
		40271,
		"%s the FX browser",
		{ "Toggle this property to either open or close the FX browser window.", "Toggleable" },
		nil,
		setWindow
	)
)

-- Video window visibility
parentLayout.windows:registerProperty(
	composeExtendedSwitcherProperty(
		usualWindowStates,
		50125,
		"%s the video window",
		{ "Toggle this property to open or close the video window.", "toggleable" },
		nil,
		setWindow
	)
)

-- Media explorer window visibility
parentLayout.windows:registerProperty(
	composeExtendedSwitcherProperty(
		usualWindowStates,
		50124,
		"%s the media explorer",
		{ "Toggle this property to show or hide the media explorer window.", "toggleable" },
		nil,
		setWindow
	)
)

-- Big clock visibility
-- The same trouble like with mixer area.
parentLayout.areas:registerProperty(
	composeExtendedSwitcherProperty(
		usualAreaStates,
		40378,
		"Big clock %s",
		{ "Toggle this property to show or hide the big clock window.", "toggleable" }
	)
)

-- Auto-crossfade methods
parentLayout.options:registerProperty(
	composeExtendedSwitcherProperty(
		usualOptStates,
		40041,
		nil,
		{ "Toggle this property to switch the automatic crossfade option", "Toggleable" }
	)
)

parentLayout.options:registerProperty(
	composeExtendedSwitcherProperty(
		usualOptStates,
		40912,
		nil,
		{ "Toggle this property to switch the automatic crossfade option which will crossfade items when they splits.",
			"Toggleable" }
	)
)

-- Virtual MIDI keyboard
parentLayout.windows:registerProperty(
	composeExtendedSwitcherProperty(
		usualWindowStates,
		40377,
		"%s the virtual MIDI keyboard",
		{ "Toggle this property to open or close the virtual MIDI keyboard window.", "Toggleable" },
		nil,
		setWindow
	)
)

-- Crossfade editor
parentLayout.windows:registerProperty(
	composeExtendedSwitcherProperty(
		usualWindowStates,
		41827,
		"%s the crossfade editor",
		{ "Toggle this property to switch the crossfade editor window state.", "Toggleable" },
		nil,
		setWindow
	)
)


-- Move envelope points with items
parentLayout.options:registerProperty(
	composeExtendedSwitcherProperty(
		usualOptStates,
		40070,
		nil,
		{ "Toggle this property to switch the movement an envelope points with items on these position when they are coppied, cutted or moved.",
			"Toggleable" }
	)
)

-- Ripple switching
local rippleSwitcherProperty = {}
parentLayout.options:registerProperty(rippleSwitcherProperty)
rippleSwitcherProperty.states = {
	{ cmd = 40309, label = "off"},
	{cmd = 40310, label = "per track"},
	{ cmd = 40311, label = "per all tracks"}
}

function rippleSwitcherProperty.getValue()
	for index, state in ipairs(rippleSwitcherProperty.states) do
		if reaper.GetToggleCommandState(state.cmd) == 1 then
			return index
		end
	end
	return 1
end

function rippleSwitcherProperty.setValue(index)
	reaper.Main_OnCommand(rippleSwitcherProperty.states[index].cmd, 1)
end

function rippleSwitcherProperty:get()
	local message  = initOutputMessage()
	message{label = "Ripple editing", value = self.states[self.getValue()].label}
	message:initType("Adjust this property to choose the needed ripple editing mode.")
	return message
end

function rippleSwitcherProperty:set_adjust(direction)
	local message = initOutputMessage()
	local state = self.getValue()
	if state+direction > #self.states then
		message "No more next property values."
	elseif state+direction < 1 then
		message "No more previous property values."
	else
		self.setValue(state+direction)
	end
	message(self:get())
	return message
end

-- Repeat option property
parentLayout.options:registerProperty(
	composeExtendedSwitcherProperty(
		usualOptStates,
		1068,
		nil,
		{ "Toggle this property to switch the repeat action.", "Toggleable" }
	)
)

-- Always on top option property
parentLayout.options:registerProperty(
	composeExtendedSwitcherProperty(
		usualOptStates,
		40239,
		nil,
		{ "Toggle this property to switch the REAPER window foreground state. When this option is on, the REAPER window will be allways on top.",
			"Toggleable" }
	)
)

-- Full screen option property
parentLayout.options:registerProperty(
	composeExtendedSwitcherProperty(
		usualOptStates,
		40346,
		nil,
		{ "Toggle this property to switch the REAPER window screen fullness state. When this property is on, the window will be filled full desktop screen.",
			"Toggleable" }
	)
)

-- Region/Marker window state
parentLayout.windows:registerProperty(
	composeExtendedSwitcherProperty(
		usualWindowStates,
		40326,
		"%s the Region and marker manager",
		{ "Toggle this property to either open or close the region and marker region manager window.", "Toggleable" },
		nil,
		setWindow
	)
)

-- Screen set window property
parentLayout.windows:registerProperty(
	composeExtendedSwitcherProperty(
		usualWindowStates,
		40422,
		"%s the screen, track or item sets",
		{ "Toggle this property to either open or close the sets for screen, items or tracks.", "Toggleable" },
		nil,
		setWindow
	)
)

-- Track manager window
parentLayout.windows:registerProperty(
	composeExtendedSwitcherProperty(
		usualWindowStates,
		40906,
		"%s the track manager",
		{ "Toggle this property to either open or close the track manager window.", "Toggleable" },
		nil,
		setWindow
	)
)

-- Undo window
parentLayout.windows:registerProperty(
	composeExtendedSwitcherProperty(
		usualWindowStates,
		40072,
		"%s the undo history window",
		{ "Toggle this property to either open or close the undo history window.", "Toggleable" },
		nil,
		setWindow
	)
)

-- Threshold sensitivity adjusting window
-- From the recent time this dialog is focusable and accessible, so let me add here
parentLayout.windows:registerProperty(
	composeExtendedSwitcherProperty(
		usualWindowStates,
		41208,
		"%s the Transient detection sensitivity and threshold adjusting window",
		{ "Toggle this property to either open or close the Transient detection sensitivity and threshold adjusting window.",
			"Toggleable" },
		nil,
		setWindow
	)
)

parentLayout.defaultSublayout = "areas"

main_newLayout(parentLayout)