--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2025 outsidepro-arts
License: MIT License
]]
--

-- Module namespace
PropertiesRibbon = {}

-- The script section internal name
PropertiesRibbon.script_section = "Properties_Ribbon_script"

PropertiesRibbon.script_path = nil

-- We will reverse the package.path string because most likely the path pattern may be at the bottom of.
for path in package.path:reverse():gmatch("([^;]+)") do
	if reaper.file_exists(path:reverse():gsub("%?", "properties_ribbon")) then
		PropertiesRibbon.script_path = path:reverse():match("^.+[//\\]"):gsub("%?", "properties_ribbon")
		break
	end
end
package.path = string.format("%s;%s/%s", package.path, PropertiesRibbon.script_path, "?.lua")
package.path = string.format("%s;%s/%s", package.path, PropertiesRibbon.script_path, "?//init.lua")


-- Including the types check simplifier
require "utils.typescheck"

-- Include the configuration provider
config = require "providers.config_provider" (PropertiesRibbon.script_section)

-- include the functions for converting the specified Reaper values and artisanal functions which either not apsent in the LUA or which work non correctly.
utils = require "utils"

-- Including the extended string utilities methods
require "utils.string"

-- including the colors module
colors = require "providers.colors_provider"
-- Making the get and set internal ExtState more easier
extstate = require "providers.extstate_provider" (PropertiesRibbon.script_section)

-- Including the humanbeing representations metamethods
representation = require "representations.representations"

-- The preparation of typed data by an user when sets the custom values using input dialogs
prepareUserData = require "representations.preparation"


-- Actions for set methods or some another cases
actions = {
	set = {
		perform = {
			label = "Perform or toggle",
			value = "perform"
		},
		increase = {
			label = "increase",
			value = "adjust",
			direction = 1
		},
		decrease = {
			label = "decrease",
			value = "adjust",
			direction = -1
		}
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


-- Checking the speech output method existing
if not reaper.APIExists("osara_outputMessage") then
	if reaper.ShowMessageBox(
			'Seems you haven\'t OSARA installed on this REAPER copy. Please install the OSARA extension which have full accessibility functions and provides the speech output method which Properties Ribbon scripts complex uses for its working.\nWould you like to open the OSARA website where you can download the latest plug-in build?',
			"Properties Ribbon error", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
		openPath("https://osara.reaperaccessibility.com/snapshots/")
	end
	return
end

if not swsIsNotRequired then
	goto skipSWSCheck
end

if reaper.APIExists("CF_GetSWSVersion") == true then
	if reaper.ShowMessageBox(
			'Seems you haven\'t SWS extension installed on this REAPER copy. Please install the SWS extension which has an extra API functions which Properties Ribbon scripts complex uses for its working.\nWould you like to open the SWS extension website where you can download the latest plug-in build?',
			"Properties Ribbon error", showMessageBoxConsts.sets.yesno) == showMessageBoxConsts.button.yes then
		openPath("https://sws-extension.org/")
	end
	return
end

::skipSWSCheck::


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

---@enum concatModes
local concatModes = {
	"parts",
	"sentences",
	"phrazes"
}

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
		-- The same value focus position
		valueFocusIndex = nil,
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
		---Sets the focus position and ofcount for some cases
		---@param self table
		---@param index number
		---@param ofCount number
		setFocusIndex = function(self, index, ofCount)
			self.focusIndex = string.format("%u of %u", index, ofCount)
		end,
		---Sets the value focus position and ofcount (if the config allows this)
		---@param self table
		---@param curIndex number|function()
		---@param ofCount number|function()
		setValueFocusIndex = function(self, curIndex, ofCount)
			local funcInfo = debug.getinfo(3)
			local conf = config.getinteger("reportValuePos", 3)
			assert(funcInfo,
				"Error while getting the function level for position reporting. Please report this error to the author.")
			if (conf == 1 and (funcInfo.name == "nextProperty" or funcInfo.name == "previousProperty" or funcInfo.name == "reportOrGotoProperty")) or
				(conf == 2 and funcInfo.name == "?") or
				(conf == 3) then
				self.valueFocusIndex = string.format("%u of %u", isfunction(curIndex) and curIndex() or curIndex,
					isfunction(ofCount) and ofCount() or ofCount)
			end
		end,
		---Clears the value focus position
		---@param self table
		clearValueFocusIndex = function(self)
			if self.valueFocusIndex then
				self.valueFocusIndex = nil
			end
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
			local msg = utils.concatSentence(
				self.msg,
				(self.msg and not self.msg:match("[.?!]%s?$") and self.label and self.value) and ". " or nil,
				outputOrder == 0 and self.objectId or nil,
				(outputOrder == 0 and self.objectId) and " " or nil,
				outputOrder <= 1 and self.label or nil,
				(outputOrder <= 1 and self.label) and string.format("%s ", config.getstring("lvDivider", "")) or nil,
				self.value,
				self.valueFocusIndex and (", "):join(self.valueFocusIndex) or nil,
				(shouldExtractType == true and self.tLevels and self.tl > 0) and (". "):join(self.tLevels[self.tl]) or
				nil,
				self.focusIndex and (". "):join(self.focusIndex)
			)
			return msg
		end
	}, {
		-- Redefine the metamethod type
		__type = "output_message",
		---@
		---Make the metamethod more flexible: if it has been called as function, it must be create or concatenate the private field msg
		---@param self table
		---@param obj table|string|number
		---@param shouldCopyTypeLevel boolean?
		__call = function(self, obj, shouldCopyTypeLevel)
			shouldCopyTypeLevel = shouldCopyTypeLevel or false
			if istable(obj) then
				if obj.msg then
					if self.msg then
						self.msg = self.msg:join(not self.msg:match("[.?!]%s?$") and "." or "",
							not self.msg:match("%s$") and " " or "", obj.msg)
					else
						self.msg = obj.msg
					end
				end
				if obj.objectId then
					if self.objectId then
						self.objectId = self.objectId:join(", ", obj.objectId)
					else
						self.objectId = obj.objectId
					end
				end
				if obj.label then
					if self.label then
						self.label = self.label:join(", ", obj.label)
					else
						self.label = obj.label
					end
				end
				if obj.value then
					if self.value then
						self.value = self.value:join(" ", obj.value)
					else
						self.value = obj.value
					end
				end
				if obj.valueFocusIndex then
					self.valueFocusIndex = obj.valueFocusIndex
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
			local lengthCounter = 0
			if self.msg then
				lengthCounter = lengthCounter + self.msg:len()
			end
			if self.objectId then
				lengthCounter = lengthCounter + self.objectId:len()
			end
			if self.label then
				lengthCounter = lengthCounter + self.label:len()
			end
			if self.value then
				lengthCounter = lengthCounter + self.value:len()
			end
			return lengthCounter
		end
	})
	return mt
end

-- The layout initialization
-- The input parameter "str" waits the new class message
function PropertiesRibbon.initLayout(str)
	local t = setmetatable({
		name = str,
		section = string.format(utils.removeSpaces(str), ""),
		ofCount = 0,
		-- slID (string) - the ID of sublayout in parent layout
		-- slName (string) - The sub-name of the sublayout which will be reported in main class format name
		registerSublayout = function(self, slID, slName)
			local parentName = self.name
			local parentSection = self.section
			self[slID] = setmetatable({
				subname = slName,
				section = string.format("%s.%s", parentSection, slID),
				properties = setmetatable({}, {
					__index = function(t, key)
						self.pIndex = #t
						return rawget(t, #t)
					end
				})
			}, {
				__type = "sublayout",
				__index = self
			})
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
			if self.properties then
				self.properties = nil
			end
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
			if self[nextSub] then
				self[nextSub].previousSubLayout = prevSub
			end
			if self[prevSub] then
				self[prevSub].nextSubLayout = nextSub
			end
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
		registerProperty = function(self, property, performableOnce)
			if performableOnce == true then
				property.performableOnce = performableOnce
			end
			table.insert(self.properties, property)
			return property
		end,
		canProvide = function()
			return true
		end
	}, {
		__type = "layout"
	})
	return t
end

function PropertiesRibbon.initExtendedProperties(str)
	local t = {
		name = str,
		properties = setmetatable({ {
			get = function(self, parent)
				local message = initOutputMessage()
				message:initType("Perform this property to return back to the properties view.")
				message(string.format("Return to %s properties", layout.subname or layout.name))
				return message
			end,
			set_perform = function(self, parent)
				return PropertiesRibbon.leaveExtendedProperties()
			end
		} }, {
			__index = function(self, key)
				layout.pIndex = #self
				return rawget(self, #self)
			end
		}),
		registerProperty = function(self, property)
			return table.insert(self.properties, property)
		end
	}
	return t
end

function PropertiesRibbon.leaveExtendedProperties()
	currentExtProperty = nil
	return true, "", true
end

-- }

function PropertiesRibbon.composeSubLayout(shouldReportParentLayout)
	local message = initOutputMessage()
	if shouldReportParentLayout == nil then
		shouldReportParentLayout = true
	end
	if isSublayout(layout) then
		message(layout.subname)
		if shouldReportParentLayout == true then
			message(string.format(" of %s", ({
				[true] = layout.name:lower(),
				[false] = layout.name
			})[(string.match(layout.name, "^%u%l*.*%u") == nil)]))
		end
	else
		message(layout.name)
	end
	local cfg = config.getinteger("reportPos", 3)
	if (cfg == 1 or cfg == 3) and (isSublayout(layout)) then
		message:setFocusIndex(layout.slIndex, layout.ofCount)
	end
	return message:extract()
end

-- Propose an existing Properties Ribbon layout by current REAPER build-in context
-- parameters:
-- optional forced (boolean): should the function return the contextual layout forcedly even if one of context has been set earlier. False or nil: only if one of contextual layouts is set, true - immediately.
function PropertiesRibbon.proposeLayout(forced)
	forced = forced or false
	local context, contextLayout, curLayout = reaper.GetCursorContext(), "", extstate.currentLayout
	-- Sometimes REAPER returns bizarre contexts...
	if context == -1 then
		context = extstate.lastKnownContext or context
	end
	if (reaper.GetMasterTrackVisibility() & 1) == 1 then
		contextLayout = "Properties Ribbon - Master track properties"
	else
		contextLayout = "Properties Ribbon - Track properties"
	end
	local contexts = {
		[0] = function()
			if reaper.GetSelectedTrack(0, 0) then
				contextLayout = "Properties Ribbon - Track properties"
				return true
			end
		end,
		[1] = function()
			if reaper.GetSelectedMediaItem(0, 0) then
				contextLayout = "Properties Ribbon - Item properties"
				return true
			end
		end,
		[2] = function()
			if reaper.GetSelectedEnvelope(0) then
				contextLayout = "Properties Ribbon - Envelope properties"
				return true
			end
		end
	}
	for i = context, 0, -1 do
		if contexts[context]() then
			break
		end
	end
	if (forced and contextLayout ~= "") or (context ~= "" and curLayout == "masterTrackProperties" or curLayout == "trackProperties" or
			curLayout == "itemAndTakeProperties" or curLayout == "envelopeProperties") then
		return fixPath(contextLayout:join(".lua"))
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

-- Immediately load specified layout
-- May be used when you're need to load new layout from your layout directly
-- Parameters:
-- -- newLayout (string): either absolute or relative path of new layout  which Properties Ribbon should switch to.
-- Returns none
function PropertiesRibbon.executeLayout(newLayoutFile)
	finishScript()
	local lt = nil
	PropertiesRibbon.presentLayout = function(newLayout)
		local rememberCFG = config.getinteger("rememberSublayout", 3)
		if (rememberCFG ~= 1 and rememberCFG ~= 3) then
			-- Let REAPER do not request the extstate superfluously
			if extstate[utils.removeSpaces(layoutFile) .. ".sublayout"] ~= "" then
				extstate[utils.removeSpaces(layoutFile) .. ".sublayout"] = nil
			end
		end
		extstate.gotoMode = nil
		extstate.isTwice = nil
		speakLayout = true
		layoutFile = fixPath(newLayoutFile):join(".lua")
		currentLayout = newLayout.section
		currentSublayout = extstate[utils.removeSpaces(layoutFile) .. ".sublayout"]
		lt = newLayout
	end
	dofile(fixPath(newLayoutFile):join(".lua"))
	finishScript = function()
		if lt.destroy then
			lt.destroy()
		end
		extstate[lt.section] = lt.pIndex
		extstate.currentLayout = lt.section
		extstate.layoutFile = fixPath(newLayoutFile):join(".lua")
		if layoutHasReset ~= true then
			extstate[utils.removeSpaces(layoutFile) .. ".sublayout"] = currentSublayout or
				extstate[utils.removeSpaces(layoutFile) .. ".sublayout"]
		end
		extstate.speakLayout = speakLayout
		extstate.extProperty = nil
		if reaper.GetCursorContext() ~= -1 then
			extstate.lastKnownContext = reaper.GetCursorContext()
		end
	end
	if prepareLayout(lt) then
		PropertiesRibbon.reportOrGotoProperty()
	end
end

function PropertiesRibbon.isHasSublayouts(lt)
	if not lt.properties then
		for _, field in pairs(lt) do
			if isSublayout(field) then
				return true
			end
		end
	end
	return false
end

---Define the default sub-layout in given layout
---@param lt layout
---@return string
function PropertiesRibbon.findDefaultSublayout(lt)
	for fieldName, field in pairs(lt) do
		if isSublayout(field) then
			if field.slIndex == 1 then
				return fieldName
			end
		end
	end
end

---Reset current property focused index
---@param resetTo? number @ Ability to specify which property should be focused. If omited, the focus will be reset to 1.
function PropertiesRibbon.resetPropertyFocus(resetTo)
	layout.pIndex = resetTo or 1
end

---Load specified macros
---@param macrosName string
---@return boolean
function useMacros(macrosName)
	if reaper.file_exists(PropertiesRibbon.script_path:joinsep("//", "macros", macrosName:join(".lua"))) then
		dofile(PropertiesRibbon.script_path:joinsep("//", "macros", macrosName:join(".lua")))
		return true
	end
	return false
end

function beginUndoBlock()
	if layout.undoContext then
		reaper.Undo_BeginBlock()
	end
end

function getUserInputs(title, fields, instruction)
	local captions, defInputs = {}, {}
	local function procFields(field)
		local preparedCaption = tostring(field.caption)
		-- Just light hope that REAPER's comas in CSV can be escaped...
		if preparedCaption:find("[,]") then
			preparedCaption = ('"'):join(preparedCaption, '"')
		end
		local preparedDefInput = tostring(field.defValue or "")
		if preparedDefInput:find("[,]") then
			preparedDefInput = ('"'):join(preparedDefInput, '"')
		end
		table.insert(captions, preparedCaption)
		table.insert(defInputs, preparedDefInput or "")
	end
	if isarray(fields) then
		for _, field in ipairs(fields) do
			procFields(field)
		end
	else
		procFields(fields)
	end
	if instruction then
		procFields {
			caption = "Instructions:",
			defValue = instruction
		}
	end
	local retval, answer =
		reaper.GetUserInputs(title, #captions, table.concat(captions, ","), table.concat(defInputs, ","))
	answer = answer:split(",")
	if instruction then
		table.remove(answer, #answer)
	end
	return retval, #answer > 1 and answer or answer[1] or nil
end

---Message box wrapper to simplify the coding
---@param title string @ Title of the message
---@param message string @ Message
---@param buttons string? @ Button set which contaions in showMessageBoxConsts.sets.
---@return number @ Button index returned from reaper.ShowMessageBox.
function msgBox(title, message, buttons)
	return reaper.ShowMessageBox(message, title, showMessageBoxConsts.sets[buttons or "ok"])
end

function interruptNextOSARAMessage()
	-- It has possible since the OSARA commit b289b432a5f7aac799b4901bcb71cea4a2cc7513
	reaper.Main_OnCommand(reaper.NamedCommandLookup("_OSARA_MUTENEXTMESSAGE"), 0)
end

-- Main body

-- We have to notify you about ReaScript task control window and instructions for.
if not extstate.reascriptTasksAvoid then
	reaper.ShowMessageBox(
		[[Since Properties Ribbon tries to avoid of useless undo points creation, it does some non-trivial things under the hood. Thus when you'll try to execute any Properties Ribbon action extra-fast (for example, you may push adjust action and not release it long time), you may get a window which called "ReaScript task control" where REAPER asks you what would you want to do with newly runnen script while previous defer action isn't finished yet.
You have to allow REAPER only create new instance and not finish previous task. To do this, firstly check the checkbox with label "Remember my answer for this script" then press "New instance" button. After this answer, the window will never open anymore.]],
		"Properties Ribbon warning", showMessageBoxConsts.sets.ok)
	extstate._forever.reascriptTasksAvoid = true
end

-- Global variables initialization
layout = {}
local maybeLayout = nil
local layoutFile
if config.getboolean("allowLayoutsrestorePrev", true) and extstate.oncePerformSuccess then
	layoutFile = extstate.previousLayoutFile or PropertiesRibbon.proposeLayout(true)
	extstate.oncePerformSuccess = false
else
	layoutFile = extstate.layoutFile
end
currentLayout = extstate.currentLayout
currentSublayout = currentLayout and extstate[utils.removeSpaces(layoutFile) .. ".sublayout"]
local SpeakLayout = extstate.speakLayout
local g_undoState = nil
local currentExtProperty = extstate.extProperty
local layoutHasReset = false
local layoutSaid = false

function prepareLayout(newLayout)
	layout = isLayout(newLayout) and newLayout
	if layout == nil then
		reaper.ShowMessageBox(string.format("The properties layout %s couldn't be loaded.", currentLayout),
			"Properties ribbon error", showMessageBoxConsts.sets.ok)
		return false
	end
	if PropertiesRibbon.isHasSublayouts(layout) then
		currentSublayout = (layout[currentSublayout] and currentSublayout) or layout.defaultSublayout or
			PropertiesRibbon.findDefaultSublayout(layout)
		layout = assert(layout[currentSublayout],
			"Broken sublayout has detected: " ..
			string.format("sublayout %s is apsent in %s", currentSublayout, layout.section))
	end
	layout.pIndex = layout.pIndex or extstate[layout.section] or 1
	if layout.init then
		layout.init()
	end
	return layout ~= nil
end

function PropertiesRibbon.presentLayout(lt)
	extstate.gotoMode = nil
	extstate.isTwice = nil
	speakLayout = true
	local rememberCFG = config.getinteger("rememberSublayout", 3)
	currentLayout = lt.section
	layoutFile = select(2, reaper.get_action_context())
	currentSublayout = extstate[utils.removeSpaces(layoutFile) .. ".sublayout"]
	if (rememberCFG ~= 1 and rememberCFG ~= 3) then
		currentSublayout = layout.defaultSublayout or PropertiesRibbon.findDefaultSublayout(layout)
	end
	if rememberCFG ~= 1 and rememberCFG ~= 2 then
		layout.pIndex = 1
	end
	if prepareLayout(lt) then
		PropertiesRibbon.reportOrGotoProperty()
		reaper.runloop(mainLoop)
	end
end

function PropertiesRibbon.initLastLayout(shouldOmitAutomaticLayoutLoading)
	local proposedLayout
	if config.getboolean("automaticLayoutLoading", false) == true and shouldOmitAutomaticLayoutLoading ~= true then
		proposedLayout = PropertiesRibbon.proposeLayout()
		if proposedLayout and proposedLayout ~= layoutFile then
			speakLayout = true
			layoutFile = proposedLayout
			extstate.gotoMode = nil
			currentExtProperty = nil
		end
	end
	if layoutFile == nil or layoutFile == "" then
		("Switch one action group first."):output()
		return
	end
	local lt = nil
	PropertiesRibbon.presentLayout = function(newLayout)
		lt = newLayout
	end
	dofile(layoutFile)
	if lt then
		currentLayout = lt.section
		currentSublayout = extstate[utils.removeSpaces(layoutFile) .. ".sublayout"]
		local retval = prepareLayout(lt)
		reaper.runloop(mainLoop)
		return retval
	end
end

function PropertiesRibbon.initProposedLayout()
	local proposedLayout = PropertiesRibbon.proposeLayout(true)
	if proposedLayout == nil or proposedLayout == "" then
		("Navigate to any supported object first."):output()
		return
	end
	speakLayout = true
	layoutFile = proposedLayout
	extstate.gotoMode = nil
	currentExtProperty = nil
	local lt = nil
	PropertiesRibbon.presentLayout = function(newLayout)
		lt = newLayout
	end
	dofile(layoutFile)
	if lt then
		currentLayout = lt.section
		currentSublayout = extstate[utils.removeSpaces(layoutFile) .. ".sublayout"]
		local rememberCFG = config.getinteger("rememberSublayout", 3)
		if (rememberCFG ~= 1 and rememberCFG ~= 3) then
			currentSublayout = lt.defaultSublayout or PropertiesRibbon.findDefaultSublayout(lt)
		end
		if rememberCFG ~= 1 and rememberCFG ~= 2 then
			lt.pIndex = 1
		end
		local retval = prepareLayout(lt)
		reaper.runloop(mainLoop)
		return retval
	end
end

local function deserializeTable(tstring)
	local t = {}
	for _, field in ipairs(tstring:sub(2, -2):split(",")) do
		local fieldKey, _, fieldValue = field:lpart("=")
		if fieldValue:find("%{") then
			t[fieldKey] = deserializeTable(fieldValue)
		else
			local argType, _, argValue = fieldValue:lpart(":")
			local keyPrepare = string.format("to%s", argType)
			t[fieldKey] = _G[keyPrepare] and _G[keyPrepare](argValue) or argValue
		end
	end
	return t
end

local function exposeCommand(cmd)
	local cmdName = select(1, cmd:lpart("%("))
	local args = {}
	if cmd:find("%(.+%)") then
		for _, arg in ipairs(cmd:sub(cmd:find("%(") + 1, cmd:find("%)") - 1):split("||")) do
			local argType, _, argValue = arg:lpart(":")
			if argType == "table" then
				args[#args + 1] = deserializeTable(argValue)
			else
				local keyPrepare = string.format("to%s", argType)
				args[#args + 1] = _G[keyPrepare] and _G[keyPrepare](argValue) or argValue
			end
		end
	end
	return cmdName, args
end

local isActivated = false
function mainLoop()
	if isActivated == true then
		local cmd = extstate.callCommand
		if cmd then
			local cmdName, args = exposeCommand(cmd)
			if cmdName == "quit" then
				isActivated = false
				string.output("Leaving Properties Ribbon")
				finishScript()
				return
			elseif cmdName == "break" then
				isActivated = false
				finishScript()
				return
			end
			PropertiesRibbon[cmdName](table.unpack(args))
			extstate.callCommand = nil
		end
	else
		isActivated = true
		extstate.callCommand = nil
	end
	reaper.runloop(mainLoop)
end

local function serializeTable(t)
	local s = {}
	for k, v in pairs(t) do
		if istable(v) then
			table.insert(s, serializeTable(v))
		else
			table.insert(s, string.format("%s=%s:%s", k, type(v), v))
		end
	end
	return "table:{" .. table.concat(s, ",") .. "}"
end

function PropertiesRibbon.call(...)
	local args = {}
	for _, arg in ipairswith({ ... }, 1, 2) do
		if istable(arg) then
			table.insert(args, serializeTable(arg))
		else
			table.insert(args, string.format("%s:%s", type(arg), tostring(arg)))
		end
	end
	extstate.callCommand = string.format("%s(%s)", select(1, ...), #args > 0 and table.concat(args, "||") or "")
end

function PropertiesRibbon.switchSublayout(action)
	if extstate.gotoMode then
		("Goto mode deactivated. "):output()
		extstate.gotoMode = nil
	end
	if layout.canProvide() ~= true then
		(string.format("There are no elements %s be provided for.", layout.name)):output()
		finishScript(config.getboolean("allowLayoutsrestorePrev", true))
		return
	end
	if isSublayout(layout) then
		if extstate.isTwice then
			extstate.isTwice = nil
		end
		if action == actions.sublayout_next then
			if layout.nextSubLayout then
				currentSublayout = layout.nextSubLayout
				finishScript()
			else
				("No next category."):output()
				finishScript()
				return
			end
		elseif action == actions.sublayout_prev then
			if layout.previousSubLayout then
				currentSublayout = layout.previousSubLayout
				finishScript()
			else
				("No previous category."):output()
				finishScript()
				return
			end
		end
		if not PropertiesRibbon.initLastLayout() then
			finishScript(config.getboolean("allowLayoutsrestorePrev", true))
			return
		end
		speakLayout = true
		PropertiesRibbon.reportOrGotoProperty(nil, nil, false)
	else
		(("The %s layout has no category. "):format(layout.name)):output()
	end
	finishScript()
end

function PropertiesRibbon.nextProperty()
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
			message(PropertiesRibbon.composeSubLayout())
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
	local pIndex = ({
		[true] = currentExtProperty,
		[false] = layout.pIndex
	})[currentExtProperty ~= nil]
	if layout.canProvide() == true then
		if #layoutLevel.properties < 1 then
			(string.format("The ribbon of %s is empty.", ({
				[true] = layoutLevel.name,
				[false] = layoutLevel.subname
			})[currentExtProperty ~= nil])):output()
			finishScript(config.getboolean("allowLayoutsrestorePrev", true))
			return
		end
		if pIndex + 1 <= #layoutLevel.properties then
			pIndex = pIndex + 1
		else
			message("Last property. ")
		end
	else
		(string.format("There are no elements %s be provided for.", layout.name)):output()
		finishScript(config.getboolean("allowLayoutsrestorePrev", true))
		return
	end
	local result = layoutLevel.properties[pIndex]:get(({
		[true] = layout.properties[layout.pIndex],
		[false] = nil
	})[currentExtProperty ~= nil])
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
				if config.getboolean("allowLayoutsrestorePrev", true) and layoutLevel.properties[pIndex].performableOnce == true then
					result:addType(
						". Please note that this property is performable once, after it will be performed successfully, this layout will be reset to previous.",
						1)
				end
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
				if config.getboolean("allowLayoutsrestorePrev", true) and layoutLevel.properties[pIndex].performableOnce == true then
					result:addType(" once", 2)
				end
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
		result:setFocusIndex(pIndex, #layoutLevel.properties)
	end
	message(result, true)
	setUndoLabel(message:extract(0, false))
	message:output(({
		[true] = nil,
		[false] = 1
	})[config.getboolean("objectsIdentificationWhenNavigating", true)])
	if currentExtProperty then
		currentExtProperty = pIndex
	else
		layout.pIndex = pIndex
	end
	finishScript()
end

function PropertiesRibbon.previousProperty()
	local message = initOutputMessage()
	local rememberCFG = config.getinteger("rememberSublayout", 3)
	if extstate.gotoMode then
		message("Goto mode deactivated. ")
		extstate.gotoMode = nil
	end
	if extstate.isTwice then
		extstate.isTwice = nil
	end
	local pIndex = ({
		[true] = currentExtProperty,
		[false] = layout.pIndex
	})[currentExtProperty ~= nil]
	if speakLayout == true then
		if currentExtProperty then
			message(layout.properties[layout.pIndex].extendedProperties.name .. ". ")
		else
			message(PropertiesRibbon.composeSubLayout())
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
			finishScript(config.getboolean("allowLayoutsrestorePrev", true))
			return
		end
		if pIndex - 1 > 0 then
			pIndex = pIndex - 1
		else
			message("First property. ")
		end
	else
		(string.format("There are no elements %s be provided for.", layout.name)):output()
		finishScript(config.getboolean("allowLayoutsrestorePrev", true))
		return
	end
	local result = layoutLevel.properties[pIndex]:get(({
		[true] = layout.properties[layout.pIndex],
		[false] = nil
	})[currentExtProperty ~= nil])
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
				if config.getboolean("allowLayoutsrestorePrev", true) and layoutLevel.properties[pIndex].performableOnce == true then
					result:addType(
						". Please note that this property is performable once, after it will be performed successfully, this layout will be reset to previous.",
						1)
				end
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
				if config.getboolean("allowLayoutsrestorePrev", true) and layoutLevel.properties[pIndex].performableOnce == true then
					result:addType(" once", 2)
				end
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
		result:setFocusIndex(pIndex, #layoutLevel.properties)
	end
	message(result, true)
	setUndoLabel(message:extract(0, false))
	message:output(({
		[true] = nil,
		[false] = 1
	})[config.getboolean("objectsIdentificationWhenNavigating", true)])
	if currentExtProperty then
		currentExtProperty = pIndex
	else
		layout.pIndex = pIndex
	end
	finishScript()
end

function PropertiesRibbon.reportOrGotoProperty(propertyNum, gotoModeShouldBeDeactivated, shouldReportParentLayout,
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
				message(PropertiesRibbon.composeSubLayout(shouldReportParentLayout))
			else
				message(layout.properties[layout.pIndex].extendedProperties.name .. ". ")
			end
		else
			message(PropertiesRibbon.composeSubLayout(shouldReportParentLayout))
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
			finishScript(true)
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
					message(string.format("%s extended properties on ",
						layout.properties[layout.pIndex].extendedProperties.name))
				end
				if isSublayout(layout) then
					message(string.format(" %s category of ", layout.subname))
				end
				message(string.format("%s layout.", layout.name))
				message:output()
				finishScript()
				return
			end
		end
	else
		(string.format("There are no elements %s be provided for.", layout.name)):output()
		finishScript(true)
		return
	end
	local pIndex
	if currentExtProperty then
		pIndex = currentExtProperty
	else
		pIndex = layout.pIndex
	end
	local result = layoutLevel.properties[pIndex]:get((currentExtProperty ~= nil and layout.properties[layout.pIndex]) or
		nil)
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
				if config.getboolean("allowLayoutsrestorePrev", true) and layoutLevel.properties[pIndex].performableOnce == true then
					result:addType(
						". Please note that this property is performable once, after it will be performed successfully, this layout will be reset to previous.",
						1)
				end
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
			if config.getboolean("allowLayoutsrestorePrev", true) and layoutLevel.properties[pIndex].performableOnce == true then
				result:addType(" once", 2)
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
		result:setFocusIndex(pIndex, #layoutLevel.properties)
	end
	message(result, true)
	if percentageNavigationApplied then
		message = message:extract(({
			[true] = 0,
			[false] = 1
		})[config.getboolean("objectsIdentificationWhenNavigating", true)], true):gsub("(.+)([.])$", "%1")
		message = message .. string.format(". Percentage navigation has chosen property %u", propertyNum)
	end
	if not propertyNumPassed then
		if extstate.isTwice then
			extstate.isTwice = nil
		end
	end
	if extstate.isTwice then
		if extstate.isTwice ~= pIndex then
			extstate.isTwice = nil
		end
	end
	local isTwice =
		config.getinteger("twicePressPerforms", 1) > 1 and
		extstate.isTwice == pIndex
	if isTwice then
		if config.getinteger("twicePressPerforms", 1) == 2 then
			if result.value then
				result.value:output()
			else
				message:output(({
					[true] = 0,
					[false] = 1
				})[config.getboolean("objectsIdentificationWhenNavigating", true)])
				if config.getinteger("twicePressPerforms", 1) > 1 and currentSublayout ==
					extstate[utils.removeSpaces(layoutFile) .. ".sublayout"] and propertyNumPassed then
					extstate.isTwice = pIndex
				end
			end
		elseif config.getinteger("twicePressPerforms", 1) == 3 and layoutLevel.properties[pIndex].set_perform ~= nil then
			PropertiesRibbon.ajustProperty(actions.set.perform)
		end
	else
		::output::
		message:output(({
			[true] = 0,
			[false] = 1
		})[config.getboolean("objectsIdentificationWhenNavigating", true)])
		if config.getinteger("twicePressPerforms", 1) > 1 and currentSublayout ==
			extstate[utils.removeSpaces(layoutFile) .. ".sublayout"] and propertyNumPassed then
			extstate.isTwice = pIndex
		end
	end
	finishScript()
end

function PropertiesRibbon.ajustProperty(action)
	local oncePerformRequested = false
	local gotoMode = extstate.gotoMode
	if gotoMode and action == actions.set.perform then
		PropertiesRibbon.reportOrGotoProperty()
		return
	end
	if layout.canProvide() == true then
		local retval, msg
		if currentExtProperty == nil then
			if layout.properties[layout.pIndex].extendedProperties and action == actions.set.perform then
				currentExtProperty = 1
				speakLayout = true
				PropertiesRibbon.reportOrGotoProperty(nil, nil, nil, true)
				return
			end
			if layout.properties[layout.pIndex][string.format("set_%s", action.value)] then
				beginUndoBlock()
				msg, opt_once = layout.properties[layout.pIndex][string.format("set_%s", action.value)](
					layout.properties[layout.pIndex],
					action.direction)
				opt_once = layout.properties[layout.pIndex].performableOnce and opt_once
				local localUndoContext = layout.properties[layout.pIndex].undoContext
				if layout.undoContext or localUndoContext then
					if msg then
						reaper.Undo_EndBlock(msg:extract(0, false), localUndoContext or layout.undoContext)
					elseif not msg and g_undoState then
						reaper.Undo_EndBlock(g_undoState, localUndoContext or layout.undoContext)
					else
						reaper.Undo_EndBlock(layout.properties[layout.pIndex]:get():extract(0, false),
							localUndoContext or layout
							.undoContext)
					end
				end
				if config.getboolean("allowLayoutsrestorePrev", true) and opt_once == true then
					extstate.oncePerformSuccess = true
					speakLayout = true
				end
			else
				string.format("This property does not support the %s action.", action.label):output()
				finishScript()
				return
			end
		elseif currentExtProperty then
			local retval, premsg, getShouldReported
			if layout.properties[layout.pIndex].extendedProperties.properties[currentExtProperty][string.format("set_%s",
					action.value)] then
				beginUndoBlock()
				retval, premsg, getShouldReported =
					layout.properties[layout.pIndex].extendedProperties.properties[currentExtProperty]
					[string.format("set_%s",
						action.value)](
						layout.properties[layout.pIndex].extendedProperties.properties[currentExtProperty],
						layout.properties[layout.pIndex], action.direction)
				local localUndoContext = layout.properties[layout.pIndex].extendedProperties.properties
					[currentExtProperty].undoContext
				if layout.undoContext or localUndoContext then
					if premsg then
						reaper.Undo_EndBlock(premsg:extract(0, false), localUndoContext or layout.undoContext)
					else
						reaper.Undo_EndBlock(g_undoState or layout.properties[layout.pIndex]:get():extract(0, false),
							localUndoContext or layout.undoContext)
					end
				end
			else
				string.format("This property does not support the %s action.", action.label):output()
				finishScript()
				return
			end
			msg = nil
			if premsg then
				msg = premsg:extract(config.getinteger("adjustOutputOrder", 0))
			end
			if retval then
				currentExtProperty = nil
				if premsg then
					if isstring(msg) then
						if #msg > 0 then
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
				finishScript()
				return
			end
		end
		if not msg then
			finishScript(oncePerformRequested)
			return
		end
		msg:output(config.getinteger("adjustOutputOrder", 0))
	else
		(string.format("There are no element to ajust or perform any action for %s.", layout.name)):output()
	end
	finishScript(oncePerformRequested)
end

function PropertiesRibbon.reportLayout()
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
				message(string.format("its number is %u of all %u categor%s", layout.slIndex, layout.ofCount, ({
					[false] = "y",
					[true] = "ies"
				})[(layout.ofCount > 1)]))
			else
				message("This layout has only 1 category")
			end
		end
		if #layout.properties > 0 then
			message(string.format(", here is %u propert%s", #layout.properties, ({
				[false] = "y",
				[true] = "ies"
			})[(#layout.properties > 1)]))
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

function PropertiesRibbon.activateGotoMode()
	local mode = extstate.gotoMode
	if mode == nil then
		("Goto mode activated."):output()
		extstate.gotoMode = 0
	else
		("Goto mode deactivated."):output()
		extstate.gotoMode = nil
	end
end

-- Actualy, this function should be local, but some functions call this from unusual scopes
function finishScript()
	if layout then
		if layout.destroy then
			layout.destroy()
		end
		extstate.layoutFile = layoutFile
		extstate[layout.section] = layout.pIndex
		extstate.currentLayout = currentLayout
		extstate[utils.removeSpaces(layoutFile) .. ".sublayout"] = currentSublayout
		if config.getboolean("allowLayoutsrestorePrev", true) then
			if layoutFile ~= extstate.layoutFile then
				extstate.previousLayoutFile = layoutFile
			end
		end
		extstate.speakLayout = speakLayout
		extstate.extProperty = currentExtProperty
		extstate.callCommand = nil
		if reaper.GetCursorContext() ~= -1 then
			extstate.lastKnownContext = reaper.GetCursorContext()
		end
	end
end
