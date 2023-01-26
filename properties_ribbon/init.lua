--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]] --

-- Define the script path constant
script_path = select(2, reaper.get_action_context()):match('^.+[\\//]')

-- Patching the loader paths
package.path = string.format("%s;%s%s", package.path, script_path, "?.lua")

-- The script section internal name
script_section = "Properties_Ribbon_script"

-- Including the types check simplifier
require "properties_ribbon.typescheck"

-- Include the configuration provider
config = require "properties_ribbon.config_provider"(script_section)

-- include the functions for converting the specified Reaper values and artisanal functions which either not apsent in the LUA or which work non correctly.
utils = require "properties_ribbon.utils"

-- Including the extended string utilities methods
require "properties_ribbon.utils.string"

-- including the colors module
colors = require "properties_ribbon.colors_provider"
-- Making the get and set internal ExtState more easier
extstate = require "properties_ribbon.wrappers.extstate"(script_section)

-- Including the humanbeing representations metamethods
representation = require "properties_ribbon.representations.representations"

-- The preparation of typed data by an user when sets the custom values using input dialogs
prepareUserData = require "properties_ribbon.representations.preparation"

-- Actions for set methods or some another cases
actions = {
	set = {
		perform = { label = "Perform or toggle", value = "perform" },
		increase = { label = "increase", value = "adjust", direction = 1 },
		decrease = { label = "decrease", value = "adjust", direction = -1 }
	},
	sublayout_next = 0x000001,
	sublayout_prev = 0x000010
}

-- the buttons and buttons sets for reaper.ShowMessageBox method
showMessageBoxConsts = {
	-- Buttons sets
	sets = {
		ok = 0x000000,
		okcancel = 0x000001,
		abortretryignore = 0x000002,
		yesnocancel = 0x000003,
		yesno = 0x000004,
		retrycancel = 0x000005
	},
	-- Buttons constants for checking
	button = {
		ok = 0x000001,
		cancel = 0x000002,
		abort = 0x000003,
		retry = 0x000004,
		ignore = 0x000005,
		yes = 0x000006,
		no = 0x000007
	}
}

undo = {
	-- The undo state contexts
	-- Taken from https://forums.cockos.com/showpost.php?p=2557019&postcount=7
	contexts = {
		any = -1,
		tracks = 1,
		fx = 2,
		items = 4,
		project = 8,
		freeze = 16
		
	}
}

-- REAPER hack to prevent useless undo points creation
reaper.defer(function() end)


-- Little injections
-- Make string type as outputable to OSARA directly
function string:output()
	reaper.osara_outputMessage(self)
end

-- Ad the trap method to the string type to avoid superfluous check writing when we are working with outputMessage metamethod
function string:extract()
	return self
end

-- own metamethods

-- Custom message metamethod
function initOutputMessage()
	local mt = setmetatable({
		-- Optional fields
		-- The object identification string
		objectId = nil,
		-- The property label
		label = nil,
		-- The property value
		value = nil,
		-- The focus position for some cases
		focusIndex = nil,

		-- type prompts initialization method
		-- The type prompts adds the string message set by default to the end of value message.
		-- Parameters:
		-- infinite parameters (string, optional): the prompts messages in supported order.
		-- returns none.
		initType = function(self, ...)
			local args = { ... }
			self.tl = config.getinteger("typeLevel", 1)
			self.tLevels = {}
			for i = 1, #args do
				self.tLevels[i] = args[i]
			end
		end,
		-- Change the type prompts message
		-- Parameters:
		-- str (string): new message.
		-- level (number): the type level which needs to be changed.
		-- returns none.
		changeType = function(self, str, level)
			if level == nil then
				self.tLevels[self.tl] = str
			else
				self.tLevels[level] = str
			end
		end,
		-- Add the next part to type prompts message. The message adds to the end of existing message.
		-- For change the message fuly, use the changeType method.
		-- Parameters:
		-- str (string): the string message which needs to be added.
		-- level (number): the type level which the passed message needs to be added to.
		-- Returns none.
		addType = function(self, str, level)
			if level == nil then
				if self.tLevels[self.tl] ~= nil then
					self.tLevels[self.tl] = self.tLevels[self.tl] .. str
				else
					self.tLevels[self.tl] = str
				end
			else
				if self.tLevels[level] ~= nil then
					self.tLevels[level] = self.tLevels[level] .. str
				else
					self.tLevels[level] = str
				end
			end
		end,

		-- Checking the types initialization
		-- Parameters:
		-- level -- (number, optional): which level should be checked. If omited, the types will be checked fully.
		-- Returns true if specified type (or all types) initialized, false otherwise.
		isTypeInitialized = function(self, level)
			if level then
				if self.tLevels then
					return self.tLevels[level] ~= nil
				end
			else
				return self.tLevels ~= nil and self.tl ~= nil
			end
		end,

		-- Clearing the local message
		-- No parameters. Returns none.
		clearMessage = function(self)
			self.msg = nil
		end,
		-- Clearing the type levels
		-- No parameters. Returns none.
		clearType = function(self)
			self.tLevels, self.tl = nil, nil
		end,
		-- Clearing the object ID extra field
		-- No parameters. Returns none.
		clearObjectId = function(self)
			self.objectId = nil
		end,
		-- Clearing the label extra field
		-- No parameters. Returns none.
		clearLabel = function(self)
			self.label = nil
		end,
		-- Clearing the value extra field
		-- No parameters. Returns none.
		clearValue = function(self)
			self.value = nil
		end,
		-- Output  composed message to OSARA by itself
		-- Parameters:
		-- outputOrder (number, optional):  the output order which supports the following values:
		-- Please note: the msg field will output anyway. It will concatenated at the top of the output message.
		-- Returns no parameters.
		output = function(self, outputOrder)
			local message = self:extract(outputOrder, true)
			if message then
				reaper.osara_outputMessage(message)
			end
		end,
		-- Extract the message composed string
		-- Parameters:
		-- outputOrder (number, optional):  the output order which supports the following values:
		-- 0 (also nil) = all fields are output
		-- 1 = The label and value fields output
		-- 2 = The value field will output only
		-- Please note: the msg field will output anyway. It will concatenated at the top of the output message.
		-- shouldExtractType (boolean, optional):  Should the type prommpt be extracted with composed message. By default is true
		-- Returns composed string. If there are no string, returns nil.
		extract = function(self, outputOrder, shouldExtractType)
			if shouldExtractType == nil then
				shouldExtractType = true
			end
			outputOrder = outputOrder or 0
			local message = {}
			if self.msg then
				table.insert(message, tostring(self.msg))
			end
			if outputOrder == 0 and self.objectId then
				table.insert(message,
					tostring(string.gsub(({ [true] = tostring(self.objectId):gsub("^%u", string.lower), [false] = tostring(self.objectId) }
						)[(#message > 0)], "%s$", " ")))
			end
			if outputOrder <= 1 and self.label then
				table.insert(message,
					({ [true] = tostring(self.label):lower(), [false] = tostring(self.label) })[
					(#message > 0 and string.match(self.label, "^%u%l*.*%u") == nil)])
			end
			if self.value then
				table.insert(message, tostring(string.gsub(self.value, "%s$", "")))
			end
			if self.focusIndex then
				message[#message] = string.format("%s.", message[#message])
				table.insert(message, self.focusIndex)
			end
			if #message == 0 then return end
			if shouldExtractType == true and self.tLevels and self.tl > 0 then
				message[#message] = string.format("%s.", message[#message])
				table.insert(message, self.tLevels[self.tl])
			end
			-- Clearing off the extra spaces
			for _, part in ipairs(message) do
				part = part:gsub("%s%s", " ")
				part = part:gsub("%s$", "")
			end
			return table.concat(message, " ")
		end
	}, {
		-- Redefine the metamethod type
		__type = "output_message",
		-- Make the metamethod more flexible: if it has been called as function, it must be create or concatenate the private field msg
		__call = function(self, obj, shouldCopyTypeLevel)
			shouldCopyTypeLevel = shouldCopyTypeLevel or false
			if istable(obj) then
				if obj.msg then
					if self.msg then
						self.msg = self.msg .. obj.msg
					else
						self.msg = obj.msg
					end
				end
				if obj.objectId then
					if self.objectId then
						self.objectId = self.objectId .. obj.objectId
					else
						self.objectId = obj.objectId
					end
				end
				if obj.label then
					if self.label then
						self.label = self.label .. obj.label
					else
						self.label = obj.label
					end
				end
				if obj.value then
					if self.value then
						self.value = self.value .. obj.value
					else
						self.value = obj.value
					end
				end
				if obj.focusIndex then
					self.focusIndex = obj.focusIndex
				end
				if obj.tLevels then
					if self.tLevels or shouldCopyTypeLevel then
						self.tLevels = obj.tLevels
						self.tl = obj.tl
					end
				end
			else
				if self.msg then
					self.msg = self.msg .. obj
				else
					self.msg = obj
				end
			end
		end,
		-- Concatenating with metatable still doesn't works... Crap!
		__concat = function(str, self)
			if self.msg then
				return str .. self.msg
			else
				return str
			end
		end,
		__len = function(self)
			if self.msg then
				return self.msg:len()
			end
			return 0
		end
	})
	return mt
end

-- The layout initialization
-- The input parameter "str" waits the new class message
function initLayout(str)
	local t = setmetatable({
		name = str,
		section = string.format(utils.removeSpaces(str), ""),
		ofCount = 0,

		-- slID (string) - the ID of sublayout in parent layout
		-- slName (string) - The sub-name of the sublayout which will be reported in main class format name
		registerSublayout = function(self, slID, slName)
			local parentName = self.name
			self[slID] = setmetatable({
				subname = slName,
				section = string.format("%s.%s", utils.removeSpaces(parentName), slID),
				properties = setmetatable({}, {
					__index = function(t, key)
						self.pIndex = #t
						return rawget(t, #t)
					end
				})
			}, {
				__type = "sublayout",
				__index = self })
			self.ofCount = self.ofCount + 1
			self[slID].slIndex = self.ofCount
			for slsn, sls in pairs(self) do
				if istable(sls) then
					if sls.slIndex == self.ofCount - 1 then
						sls.nextSubLayout = slID
						self[slID].previousSubLayout = slsn
					end
				end
			end
			self[slID].registerProperty = self.registerProperty
			-- If a category has been created, the parent registration methods should be unavailable.
			if self.properties then self.properties = nil end
		end,
		destroySublayout = function(self, slID, shouldPatchGlobals)
			local curIndex = self[slID].slIndex
			local prevSub, nextSub
			for sKey, sField in pairs(self) do
				if isSublayout(sField) then
					if sField.slIndex > 0 and sField.slIndex == curIndex - 1 then
						prevSub = sKey
					elseif sField.slIndex <= self.ofCount and sField.slIndex == curIndex + 1 then
						nextSub = sKey
					end
				end
			end
			if self[nextSub] then self[nextSub].previousSubLayout = prevSub end
			if self[prevSub] then self[prevSub].nextSubLayout = nextSub end
			self[slID] = nil
			self.ofCount = self.ofCount - 1
			if shouldPatchGlobals then
				if currentSublayout == slID then
					if prevSub then
						currentSublayout = prevSub
					elseif nextSub then
						currentSublayout = nextSub
					end
				end
			end
			for _, sField in pairs(self) do
				if isSublayout(sField) then
					if sField.slIndex > curIndex then
						sField.slIndex = sField.slIndex - 1
					end
				end
			end
		end,
		properties = setmetatable({}, {
			__index = function(self, key)
				layout.pIndex = #self
				return rawget(self, #self)
			end
		}),
		registerProperty = function(self, property)
			return table.insert(self.properties, property)
		end,
		canProvide = function() return true end
	}, { __type = "layout" })
	return t
end

function initExtendedProperties(str)
	local t = {
		name = str,
		properties = setmetatable({
			{
				get = function(self, parent)
					local message = initOutputMessage()
					message:initType("Perform this property to return back to the properties view.")
					message(string.format("Return to %s properties", layout.subname or layout.name))
					return message
				end,
				set_perform = function(self, parent)
					currentExtProperty = nil
					return true, "", true
				end
			}
		}, {
			__index = function(self, key)
				layout.pIndex = #self
				return rawget(self, #self)
			end
		}),
		registerProperty = function(self, property)
			return table.insert(self.properties, property)
		end,
	}
	return t
end

-- }


function composeSubLayout(shouldReportParentLayout)
	local message = initOutputMessage()
	if shouldReportParentLayout == nil then
		shouldReportParentLayout = true
	end
	if isSublayout(layout) then
		message(layout.subname)
		if shouldReportParentLayout == true then
			message(string.format(" of %s",
				({ [true] = layout.name:lower(), [false] = layout.name })[(string.match(layout.name, "^%u%l*.*%u") == nil)]))
		end
	else
		message(layout.name)
	end
	local cfg = config.getinteger("reportPos", 3)
	if (cfg == 1 or cfg == 3) and (isSublayout(layout)) then
		message(string.format(", %u of %u", layout.slIndex, layout.ofCount))
	end
	message(", ")
	return message:extract()
end

-- Propose an existing Properties Ribbon layout by current REAPER build-in context
-- parameters:
-- optional forced (boolean): should the function return the contextual layout forcedly even if one of context has been set earlier. False or nil: only if one of contextual layouts is set, true - immediately.
function proposeLayout(forced)
	forced = forced or false
	local context, contextLayout, curLayout = reaper.GetCursorContext(), {section = "properties", proposed=true}, extstate.currentLayout
	-- Sometimes REAPER returns bizarre contexts...
	if context == -1 then
		context = extstate.lastKnownContext or context
	end
	if context == 0 then
		if reaper.IsTrackSelected(reaper.GetMasterTrack()) then
			contextLayout.layout = "mastertrack_properties"
		else
			if reaper.CountTracks(0) > 0 then
				contextLayout.layout = "track_properties"
			else
				if (reaper.GetMasterTrackVisibility() & 1) == 1 then
					contextLayout.layout = "mastertrack_properties"
				else
					contextLayout.layout =  "track_properties"
				end
			end
		end
	elseif context == 1 then
		contextLayout.layout = "item_properties"
	elseif context == 2 then
		contextLayout.layout = "envelope_properties"
	end
	if forced or curLayout == "properties//mastertrack_properties" or curLayout == "properties//track_properties" or curLayout == "properties//item_properties" or curLayout == "properties//envelope_properties" then
		return contextLayout
	end
	return nil
end

function setUndoLabel(label)
	if not label then
		g_undoState = ""
	elseif label == "" then
		-- do nothing
	else
		g_undoState = label:extract(0, false)
	end
end

function restorePreviousLayout()
	if config.getboolean("allowLayoutsrestorePrev", true) == true then
		if config.getboolean("automaticLayoutLoading", false) == true then
			local plBuild = proposeLayout(true)
			currentLayout = table.concat({plBuild.section, plBuild.layout}, "//")
			speakLayout = true
			layoutHasReset = true
		else
			if extstate.previousLayout then
				currentLayout = extstate.previousLayout
				speakLayout = true
				layoutHasReset = true
			end
		end
	end
end

-- Immediately load specified layout
-- May be used when you're need to load new layout from your layout directly
-- Parameters:
-- -- newLayout (table): new layout structure which Properties Ribbon should switch to.
-- Returns none
function executeLayout(newLayout)
	script_finish()
	local loadResult = (script_init(newLayout, true) ~= nil)
	if loadResult then
		script_reportOrGotoProperty()
	end
	return loadResult
end

function isHasSublayouts(lt)
	if not lt.properties then
		for _, field in pairs(lt) do
			if isSublayout(field) then
				return true
			end
		end
	end
	return false
end

function findDefaultSublayout(lt)
	for fieldName, field in pairs(lt) do
		if isSublayout(field) then
			if field.slIndex == 1 then
				return fieldName
			end
		end
	end
end

-- Open a path to defined system
-- path (string): the physical or web-address
function openPath(path)
	-- We have to define the operating system to choose needed terminal command.
	local startCmd = nil
	if utils.platform() == "Windows" then
		startCmd = "start"
	else -- We are on another platform, that assumes Unix systems (REAPER builds only for two OS) which implies that's MacOS
		startCmd = "open"
	end
	if startCmd then
		os.execute(string.format("%s %s", startCmd, path))
	end
end

function useMacros(propertiesDir)
	if reaper.file_exists(script_path:joinsep("//", propertiesDir, "macros.lua")) then
		dofile(script_path:joinsep("//", propertiesDir, "macros.lua"))
		return true
	end
	return false
end

function beginUndoBlock()
	if layout.undoContext then
		reaper.Undo_BeginBlock()
	end
end

function getEmbeddedProperties(name)
	if reaper.file_exists(script_path:joinsep("//", "properties_ribbon", "embedded", name:join(".lua"))) then
		return {section = "properties_ribbon//embedded", layout = name }
	end
end

-- Main body

-- Global variables initialization
layout = {}
currentLayout = nil
currentSublayout = nil
SpeakLayout = false
g_undoState = nil
currentExtProperty = nil
layoutHasReset = false
layoutSaid = false

-- The main initialization function
-- shouldSpeakLayout (boolean, optional): option which defines should Properties ribbon say new layout. If it is omited, scripts will decides should report it by itself basing on the previous layout.
function script_init(newLayout, shouldSpeakLayout)
	-- Checking the speech output method existing
	if not reaper.APIExists("osara_outputMessage") then
		if reaper.ShowMessageBox('Seems you haven\'t OSARA installed on this REAPER copy. Please install the OSARA extension which have full accessibility functions and provides the speech output method which Properties Ribbon scripts complex uses for its working.\nWould you like to open the OSARA website where you can download the latest plug-in build?'
			, "Properties Ribbon error", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
			openPath("https://osara.reaperaccessibility.com/snapshots/")
		end
		return nil
	end
	if not reaper.APIExists("CF_GetSWSVersion") == true then
		if reaper.ShowMessageBox('Seems you haven\'t SWS extension installed on this REAPER copy. Please install the SWS extension which has an extra API functions which Properties Ribbon scripts complex uses for its working.\nWould you like to open the SWS extension website where you can download the latest plug-in build?'
			, "Properties Ribbon error", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
			openPath("https://sws-extension.org/")
		end
		return nil
	end
	-- We have to notify you about ReaScript task control window and instructions for.
	if not extstate.reascriptTasksAvoid then
		reaper.ShowMessageBox(
[[Since Properties Ribbon tries to avoid of useless undo points creation, it does some non-trivial things under the hood. Thus when you'll try to execute any Properties Ribbon action extra-fast (for example, you may push adjust action and not release it long time), you may get a window which called "ReaScript task control" where REAPER asks you what would you want to do with newly runnen script while previous defer action isn't finished yet.
You have to allow REAPER only create new instance and not finish previous task. To do this, firstly check the checkbox with label "Remember my answer for this script" then press "New instance" button. After this answer, the window will never open anymore.]],
			"Properties Ribbon warning", showMessageBoxConsts.sets.ok
		)
		extstate._forever.reascriptTasksAvoid = true
	end
	currentExtProperty = extstate.extProperty
	local rememberCFG = config.getinteger("rememberSublayout", 3)
	if newLayout and newLayout ~= extstate.currentLayout then
		if extstate.gotoMode then
			extstate.gotoMode = nil
		end
		newLayout = newLayout.section .. "//" .. newLayout.layout or nil
		if currentExtProperty and newLayout ~= extstate.currentLayout then currentExtProperty = nil end
		if extstate.isTwice and newLayout ~= extstate.currentLayout then extstate.isTwice = nil end
	end
	if newLayout ~= nil then
		currentLayout = newLayout
		if config.getboolean("allowLayoutsrestorePrev", true) == true and newLayout ~= extstate.currentLayout then
			extstate.previousLayout = extstate.currentLayout
		end
		if shouldSpeakLayout == nil then
			if extstate.currentLayout ~= newLayout then
				speakLayout = true
			else
				speakLayout = extstate.speakLayout
			end
		else
			speakLayout = shouldSpeakLayout
		end
		if (rememberCFG ~= 1 and rememberCFG ~= 3) and extstate.currentLayout ~= currentLayout then
			-- Let REAPER do not request the extstate superfluously
			if extstate[newLayout .. "_sublayout"] ~= "" then
				extstate[newLayout .. "_sublayout"] = nil
			end
		end
	else
		currentLayout = extstate.currentLayout
		if shouldSpeakLayout ~= nil then
			speakLayout = shouldSpeakLayout
		else
			speakLayout = extstate.speakLayout
		end
	end
	if currentLayout == nil or currentLayout == "" then
		("Switch one action group first."):output()
		return nil
	end
	-- Some layouts has executes the linear code... Woops...
	currentSublayout = extstate[currentLayout .. "_sublayout"]
	useMacros(currentLayout:match('^(.+)//'))
	layout = dofile(script_path:joinsep("//", currentLayout:join(".lua")))
	if layout == nil then
		reaper.ShowMessageBox(string.format("The properties layout %s couldn't be loaded.", currentLayout),
			"Properties ribbon error", showMessageBoxConsts.sets.ok)
		return nil
	end
	if isHasSublayouts(layout) then
		local sublayout = currentSublayout or layout.defaultSublayout or findDefaultSublayout(layout)
		layout = layout[sublayout]
		currentSublayout = sublayout
	end
	layout.pIndex = extstate[layout.section] or 1
	return (layout)
end

function script_switchSublayout(action)
	if extstate.gotoMode then
		("Goto mode deactivated. "):output()
		extstate.gotoMode = nil
	end
	if layout.canProvide() ~= true then
		(string.format("There are no elements %s be provided for.", layout.name)):output()
		restorePreviousLayout()
		script_finish()
		return
	end
	if isSublayout(layout) then
		if extstate.isTwice then
			extstate.isTwice = nil
		end
	if action == actions.sublayout_next then
			if layout.nextSubLayout then
				extstate[currentLayout .. "_sublayout"] = layout.nextSubLayout
			else
				("No next category."):output()
				script_finish()
				return
			end
		elseif action == actions.sublayout_prev then
			if layout.previousSubLayout then
				extstate[currentLayout .. "_sublayout"] = layout.previousSubLayout
			else
				("No previous category."):output()
				script_finish()
				return
			end
		end
		if not script_init(nil, true) then
			restorePreviousLayout()
			script_finish()
			return
		end
		script_reportOrGotoProperty(nil, nil, false)
	else
		(("The %s layout has no category. "):format(layout.name)):output()
	end
	script_finish()
end

function script_nextProperty()
	local message = initOutputMessage()
	if extstate.gotoMode then
		message("Goto mode deactivated. ")
		extstate.gotoMode = nil
	end
	if extstate.isTwice then
		extstate.isTwice = nil
	end
	local rememberCFG = config.getinteger("rememberSublayout", 3)
	if speakLayout == true then
		if currentExtProperty then
			message(layout.properties[layout.pIndex].extendedProperties.name .. ". ")
		else
			message(composeSubLayout())
		end
		if rememberCFG ~= 2 and rememberCFG ~= 3 then
			layout.pIndex = 0
		end
		speakLayout = false
	end
	local layoutLevel
	if currentExtProperty then
		layoutLevel = layout.properties[layout.pIndex].extendedProperties
	else
		layoutLevel = layout
	end
	local pIndex = ({ [true] = currentExtProperty, [false] = layout.pIndex })[currentExtProperty ~= nil]
	if layout.canProvide() == true then
		if #layoutLevel.properties < 1 then
			(
				string.format("The ribbon of %s is empty.",
					({ [true] = layoutLevel.name, [false] = layoutLevel.subname })[currentExtProperty ~= nil])):output()
			restorePreviousLayout()
			script_finish()
			return
		end
		if pIndex + 1 <= #layoutLevel.properties then
			pIndex = pIndex + 1
		else
			message("Last property. ")
		end
	else
		(string.format("There are no elements %s be provided for.", layout.name)):output()
		restorePreviousLayout()
		script_finish()
		return
	end
	local result = layoutLevel.properties[pIndex]:get(({ [true] = layout.properties[layout.pIndex], [false] = nil })[
		currentExtProperty ~= nil])
	if result:isTypeInitialized() then
		if not result:isTypeInitialized(1) then
			if layoutLevel.properties[pIndex].set_adjust then
				result:addType(string.format("%s or %s this property to adjust its value to appropriate direction.",
					actions.set.decrease.label:gsub("^%w", string.upper), actions.set.increase.label), 1)
			end
			if layoutLevel.properties[pIndex].set_perform then
				if result:isTypeInitialized(1) then
					result:addType(" ", 1)
				end
				result:addType(string.format("%s this property to perform its action.",
					actions.set.perform.label:gsub("^%w", string.upper)), 1)
			end
			if result:isTypeInitialized(1) then
				result:addType(" ", 1)
			end
			result:addType("No any more detailed usability prompt could be provided.", 1)
		end
		if not result:isTypeInitialized(2) then
			if layoutLevel.properties[pIndex].set_adjust then
				result:addType("Adjustable", 2)
			end
			if layoutLevel.properties[pIndex].set_perform then
				if result:isTypeInitialized(2) then
					result:addType(", p", 2)
				else
					result:addType("P", 2)
				end
				result:addType("erformable", 2)
			end
		end
		if layoutLevel.properties[pIndex].extendedProperties then
			if result:isTypeInitialized(1) then
				result:addType(" ", 1)
			end
			if result:isTypeInitialized(2) then
				result:addType(", h", 2)
			else
				result:addType("H", 2)
			end
			result:addType("Perform this property to activate the extended properties for.", 1)
			result:addType("as extended properties", 2)
		end
	end
	local cfg = config.getinteger("reportPos", 3)
	if cfg == 2 or cfg == 3 then
		result({ focusIndex = ("%u of %u"):format(pIndex, #layoutLevel.properties) })
	end
	message(result, true)
	setUndoLabel(message:extract(0, false))
	message:output(({ [true] = nil, [false] = 1 })[config.getboolean("objectsIdentificationWhenNavigating", true)])
	if currentExtProperty then
		currentExtProperty = pIndex
	else
		layout.pIndex = pIndex
	end
	script_finish()
end

function script_previousProperty()
	local message = initOutputMessage()
	local rememberCFG = config.getinteger("rememberSublayout", 3)
	if extstate.gotoMode then
		message("Goto mode deactivated. ")
		extstate.gotoMode = nil
	end
	if extstate.isTwice then
		extstate.isTwice = nil
	end
	local pIndex = ({ [true] = currentExtProperty, [false] = layout.pIndex })[currentExtProperty ~= nil]
	if speakLayout == true then
		if currentExtProperty then
			message(layout.properties[layout.pIndex].extendedProperties.name .. ". ")
		else
			message(composeSubLayout())
		end
		if rememberCFG ~= 2 and rememberCFG ~= 3 then
			pIndex = 2
		end
		speakLayout = false
	end
	local layoutLevel
	if currentExtProperty then
		layoutLevel = layout.properties[layout.pIndex].extendedProperties
	else
		layoutLevel = layout
	end
	if layout.canProvide() == true then
		if #layoutLevel.properties < 1 then
			(string.format("The ribbon of %s is empty.", layout.name:format(layout.subname))):output()
			restorePreviousLayout()
			script_finish()
			return
		end
		if pIndex - 1 > 0 then
			pIndex = pIndex - 1
		else
			message("First property. ")
		end
	else
		(string.format("There are no elements %s be provided for.", layout.name)):output()
		restorePreviousLayout()
		script_finish()
		return
	end
	local result = layoutLevel.properties[pIndex]:get(({ [true] = layout.properties[layout.pIndex], [false] = nil })[
		currentExtProperty ~= nil])
	if result:isTypeInitialized() then
		if not result:isTypeInitialized(1) then
			if layoutLevel.properties[pIndex].set_adjust then
				result:addType(string.format("%s or %s this property to adjust its value to appropriate direction.",
					actions.set.decrease.label:gsub("^%w", string.upper), actions.set.increase.label), 1)
			end
			if layoutLevel.properties[pIndex].set_perform then
				if result:isTypeInitialized(1) then
					result:addType(" ", 1)
				end
				result:addType(string.format("%s this property to perform its action.",
					actions.set.perform.label:gsub("^%w", string.upper)), 1)
			end
			if result:isTypeInitialized(1) then
				result:addType(" ", 1)
			end
			result:addType("No any more detailed usability prompt could be provided.", 1)
		end
		if not result:isTypeInitialized(2) then
			if layoutLevel.properties[pIndex].set_adjust then
				result:addType("Adjustable", 2)
			end
			if layoutLevel.properties[pIndex].set_perform then
				if result:isTypeInitialized(2) then
					result:addType(", p", 2)
				else
					result:addType("P", 2)
				end
				result:addType("erformable", 2)
			end
		end
		if layoutLevel.properties[pIndex].extendedProperties then
			if result:isTypeInitialized(1) then
				result:addType(" ", 1)
			end
			if result:isTypeInitialized(2) then
				result:addType(", h", 2)
			else
				result:addType("H", 2)
			end
			result:addType("Perform this property to activate the extended properties for.", 1)
			result:addType("as extended properties", 2)
		end
	end
	local cfg = config.getinteger("reportPos", 3)
	if cfg == 2 or cfg == 3 then
		result({ focusIndex = ("%u of %u"):format(pIndex, #layoutLevel.properties) })
	end
	message(result, true)
	setUndoLabel(message:extract(0, false))
	message:output(({ [true] = nil, [false] = 1 })[config.getboolean("objectsIdentificationWhenNavigating", true)])
	if currentExtProperty then
		currentExtProperty = pIndex
	else
		layout.pIndex = pIndex
	end
	script_finish()
end

function script_reportOrGotoProperty(propertyNum, gotoModeShouldBeDeactivated, shouldReportParentLayout,
                                     shouldNotResetExtProperty)
	local message = initOutputMessage()
	local cfg_percentageNavigation = config.getboolean("percentagePropertyNavigation", false)
	local gotoMode = extstate.gotoMode
	local propertyNumPassed = propertyNum ~= nil
	if gotoMode and propertyNum then
		if propertyNum == 10 then
			propertyNum = 0
		end
		if gotoMode == 0 then
			gotoMode = tostring(propertyNum)
		else
			gotoMode = tostring(gotoMode) .. tostring(propertyNum)
		end
		(tostring(gotoMode)):output()
		extstate.gotoMode = gotoMode
		return
	elseif gotoMode and propertyNum == nil then
		cfg_percentageNavigation = false
		propertyNum = gotoMode
		extstate.gotoMode = nil
	end
	local rememberCFG = config.getinteger("rememberSublayout", 3)
	local percentageNavigationApplied = false
	if speakLayout == true then
		if currentExtProperty then
			if not shouldNotResetExtProperty then
				currentExtProperty = nil
				message(composeSubLayout(shouldReportParentLayout))
			else
				message(layout.properties[layout.pIndex].extendedProperties.name .. ". ")
			end
		else
			message(composeSubLayout(shouldReportParentLayout))
		end
		if (rememberCFG ~= 2 and rememberCFG ~= 3) and not propertyNum and not currentExtProperty then
			layout.pIndex = 1
		end
		speakLayout = false
		layoutSaid = true
	end
	local layoutLevel
	if currentExtProperty then
		layoutLevel = layout.properties[layout.pIndex].extendedProperties
	else
		layoutLevel = layout
	end
	if layout.canProvide() == true then
		if #layoutLevel.properties < 1 then
			local definedName = layoutLevel.subname or layoutLevel.name
			string.format("The ribbon of %s is empty.", definedName):output()
			restorePreviousLayout()
			script_finish()
			return
		end
		if propertyNum then
			if cfg_percentageNavigation == true and #layoutLevel.properties > 10 then
				if propertyNum > 1 then
					propertyNum = math.floor((#layoutLevel.properties * propertyNum) * 0.1)
					percentageNavigationApplied = true
				end
			end
			if propertyNum <= #layoutLevel.properties then
				if currentExtProperty then
					currentExtProperty = propertyNum
				else
					layout.pIndex = propertyNum
				end
			else
				local message = initOutputMessage()
				message(string.format("No property with number %s in ", propertyNum))
				if currentExtProperty then
					message(string.format("%s extended properties on ", layout.properties[layout.pIndex].extendedProperties.name))
				end
				if isSublayout(layout) then
					message(string.format(" %s category of ", layout.subname))
				end
				message(string.format("%s layout.", layout.name))
				message:output()
				script_finish()
				return
			end
		end
	else
		(string.format("There are no elements %s be provided for.", layout.name)):output()
		restorePreviousLayout()
		script_finish()
		return
	end
	local pIndex
	if currentExtProperty then
		pIndex = currentExtProperty
	else
		pIndex = layout.pIndex
	end
	local result = layoutLevel.properties[pIndex]:get((currentExtProperty ~= nil and layout.properties[layout.pIndex]) or nil)
	if result:isTypeInitialized() then
		if not result:isTypeInitialized(1) then
			if layoutLevel.properties[pIndex].set_adjust then
				result:addType(string.format("%s or %s this property to adjust its value to appropriate direction.",
					actions.set.decrease.label:gsub("^%w", string.upper), actions.set.increase.label), 1)
			end
			if layoutLevel.properties[pIndex].set_perform then
				if result:isTypeInitialized(1) then
					result:addType(" ", 1)
				end
				result:addType(string.format("%s this property to perform its action.",
					actions.set.perform.label:gsub("^%w", string.upper)), 1)
			end
			if result:isTypeInitialized(1) then
				result:addType(" ", 1)
			end
			result:addType("No any more detailed usability prompt could be provided.", 1)
		end
		if not result:isTypeInitialized(2) then
			if layoutLevel.properties[pIndex].set_adjust then
				result:addType("Adjustable", 2)
			end
			if layoutLevel.properties[pIndex].set_perform then
				if result:isTypeInitialized(2) then
					result:addType(", p", 2)
				else
					result:addType("P", 2)
				end
				result:addType("erformable", 2)
			end
		end
		if layoutLevel.properties[pIndex].extendedProperties then
			if result:isTypeInitialized(1) then
				result:addType(" ", 1)
			end
			if result:isTypeInitialized(2) then
				result:addType(", h", 2)
			else
				result:addType("H", 2)
			end
			result:addType("Perform this property to activate the extended properties for.", 1)
			result:addType("as extended properties", 2)
		end
	end
	local cfg = config.getinteger("reportPos", 3)
	if cfg == 2 or cfg == 3 then
		result({ focusIndex = ("%u of %u"):format(pIndex, #layoutLevel.properties) })
	end
	message(result, true)
	if percentageNavigationApplied then
		message = message:extract(({ [true] = 0, [false] = 1 })[config.getboolean("objectsIdentificationWhenNavigating", true)
			], true):gsub("(.+)([.])$", "%1")
		message = message .. string.format(". Percentage navigation has chosen property %u", propertyNum)
	end
	if not propertyNumPassed then if extstate.isTwice then
			extstate.isTwice = nil
	end end
	if extstate.isTwice then if extstate.isTwice ~= pIndex then
			extstate.isTwice = nil
	end end
	local isTwice = config.getboolean("twicePressPerforms", false) and layoutLevel.properties[pIndex].set_perform ~= nil and extstate.isTwice == pIndex
	if isTwice then
		script_ajustProperty(actions.set.perform)
	else
		message:output(({ [true] = 0, [false] = 1 })[config.getboolean("objectsIdentificationWhenNavigating", true)])
		if config.getboolean("twicePressPerforms", false) and layoutLevel.properties[pIndex].set_perform and currentSublayout == extstate[currentLayout .. "_sublayout"] and propertyNumPassed then
			extstate.isTwice = pIndex
		end
	end
	script_finish()
end

function script_ajustProperty(action)
	local gotoMode = extstate.gotoMode
	if gotoMode and action == actions.set.perform then
		script_reportOrGotoProperty()
		return
	end
	if layout.canProvide() == true then
		local retval, msg
		if currentExtProperty == nil then
			if layout.properties[layout.pIndex].extendedProperties and action == actions.set.perform then
				currentExtProperty = 1
				speakLayout = true
				script_reportOrGotoProperty(nil, nil, nil, true)
				return
			end
			if layout.properties[layout.pIndex][string.format("set_%s", action.value)] then
				beginUndoBlock()
				msg = layout.properties[layout.pIndex][string.format("set_%s", action.value)](layout.properties[layout.pIndex],
					action.direction)
				if layout.undoContext then if msg then
						reaper.Undo_EndBlock(msg:extract(0, false), layout.undoContext)
					elseif not msg and g_undoState then
						reaper.Undo_EndBlock(g_undoState, layout.undoContext)
					else
						reaper.Undo_EndBlock(layout.properties[layout.pIndex]:get():extract(0, false), layout.undoContext)
				end end
			else
				string.format("This property does not support the %s action.", action.label):output()
				script_finish()
				return
			end
		elseif currentExtProperty then
			local retval, premsg, getShouldReported
			if layout.properties[layout.pIndex].extendedProperties.properties[currentExtProperty][
				string.format("set_%s", action.value)] then
				beginUndoBlock()
				retval, premsg, getShouldReported = layout.properties[layout.pIndex].extendedProperties.properties[
					currentExtProperty][string.format("set_%s", action.value)](layout.properties[layout.pIndex].extendedProperties.properties
						[currentExtProperty], layout.properties[layout.pIndex], action.direction)
				if layout.undoContext then
					if premsg then
						reaper.Undo_EndBlock(premsg:extract(0, false), layout.undoContext)
					else
						reaper.Undo_EndBlock(g_undoState or layout.properties[layout.pIndex]:get():extract(0, false), layout.undoContext)
					end
				end
			else
				string.format("This property does not support the %s action.", action.label):output()
				script_finish()
				return
			end
			msg = nil
			if premsg then
				msg = premsg:extract(config.getinteger("adjustOutputOrder", 0))
			end
			if retval then
				currentExtProperty = nil
				if premsg then
					if isstring(msg) then if #msg > 0 then
							---@diagnostic disable-next-line: need-check-nil
							if msg:sub(-1, -1) ~= "." then
								msg = msg .. "."
							end
							msg = msg .. " "
						end
					end
					msg = msg .. string.format("Leaving %s. ", layout.properties[layout.pIndex].extendedProperties.name)
				end
				if premsg and getShouldReported then
					msg = msg .. layout.properties[layout.pIndex]:get():extract()
				end
				if premsg then
					if msg then
						msg:output()
					end
				end
				script_finish()
				return
			end
		end
		if not msg then
			script_finish()
			return
		end
		msg:output(config.getinteger("adjustOutputOrder", 0))
	else
		(string.format("There are no element to ajust or perform any action for %s.", layout.name)):output()
	end
	script_finish()
end

function script_reportLayout()
	if layout.canProvide() then
		local message = initOutputMessage()
		if isSublayout(layout) then
			message(string.format("%s category of %s layout", layout.subname, layout.name:gsub("^%w", string.lower)))
		else
			message(string.format("%s layout", layout.name))
		end
		message(" currently loaded, ")
		if isSublayout(layout) then
			if layout.ofCount > 1 then
				message(string.format("its number is %u of all %u categor%s", layout.slIndex, layout.ofCount,
					({ [false] = "y", [true] = "ies" })[(layout.ofCount > 1)]))
			else
				message("This layout has only 1 category")
			end
		end
		if #layout.properties > 0 then
			message(string.format(", here is %u propert%s", #layout.properties,
				({ [false] = "y", [true] = "ies" })[(#layout.properties > 1)]))
		else
			message(", here is no properties")
		end
		message(".")
		if currentExtProperty then
			message(string.format(" You are now in the %s.", layout.properties[layout.pIndex].extendedProperties.name))
		end
		message:output()
	else
		(string.format("The %s layout  cannot provide any interraction here.", layout.name)):output()
	end
end

function script_activateGotoMode()
	local mode = extstate.gotoMode
	if mode == nil then
		("Goto mode activated."):output()
		extstate.gotoMode = 0
	else
		("Goto mode deactivated."):output()
		extstate.gotoMode = nil
	end
end

function script_finish()
	if layout then
		extstate[layout.section] = layout.pIndex
		extstate.currentLayout = currentLayout
		if layoutHasReset ~= true then
			extstate[currentLayout .. "_sublayout"] = currentSublayout or extstate[currentLayout .. "_sublayout"]
		end
		extstate.speakLayout = speakLayout
		extstate.extProperty = currentExtProperty
		if reaper.GetCursorContext() ~= -1 then
			extstate.lastKnownContext = reaper.GetCursorContext()
		end
	end
end
