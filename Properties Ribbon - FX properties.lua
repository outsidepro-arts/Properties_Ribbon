--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2024 outsidepro-arts
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

-- This is the alternative of OSARA FX parameters, but more flexible. I wrote this layout because the proposed by OSARA is not satisfied me by a few reasons.
package.path = select(2, reaper.get_action_context()):match('^.+[\\//]') .. "?//init.lua"

require "properties_ribbon"

useMacros("fx_properties")
useMacros("track_properties")
useMacros("item_properties")

local fxLayout = PropertiesRibbon.initLayout("FX properties")

fxLayout.undoContext = undo.contexts.fx

-- get current navigation context
local context = reaper.GetCursorContext()
-- Fixing the unexpected items context
if context == 1 and reaper.GetLastTouchedTrack() == nil then
	context = 0
	-- Remember of unexpected contexts
elseif context < 0 then
	context = extstate.lastKnownContext
end

-- FX section split needs
local whichFXCanbeLoaded = extstate["fx_properties.loadFX"]

-- Steps list for adjusting (will be defined using configuration)
local stepsList = fx_properties_macros.stepsList

-- This table contains known plugins names or its masks which work assynchronously. When we know that one of known plugins works that, we have to decelerate the set parameter values to let the plugin to apply a new value. We have not to do this at other cases to not make our code too many slow.
local knownAssyncPlugins = {
	{ name = "M%u%w+[.].+",    delay = 6 },
	{ name = "Pulsar",         delay = 2 },
	{ name = "Replika",        delay = 5 },
	{ name = "SynthMasterOne", delay = 10 }
}


-- API simplification to make calls as contextual
-- capi stands for "contextual API"
local capi = fx_properties_macros.newContextualAPI()
capi._context = context
--[[
All done! Now we can call an FX API without needs to think about a context every our step.
For example, instead of TakeFX_GetParamName and TrackFX_GetParamName we can call it as GetParamName through new capi metatable.
Also, please note that we don't need to pass a handle to an object where we searching for FX. The metatable do it itself. We have to pass only params which related to FX only.
For example, instead of coding as:
```lua
local obj = nil
if context == 0 then
obj = reaper.GetLastTouchedTrack()
elseif context == 1 then
obj = reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, 0))
end
capi.GetParamName(obj, fxIndex, parmIndex)
```
you can code it as:
```lua
capi.GetParamName(fxIndex, parmIndex)
```
]]
--



-- Some internal functions
-- Exclude masks metatable
local fxMaskList = fx_properties_macros.fxMaskList

local pluginsFilenames = {}
local function getPluginFilename(fxId)
	-- The SWS authors set the own prefix on the  top of function name, so we cannot use capi metatable
	-- These functions works slow, so we will cache plugin names
	if not pluginsFilenames[fxId] then
		pluginsFilenames[fxId] = {}
		if context == 0 then
			local retval, str = reaper.BR_TrackFX_GetFXModuleName(capi._contextObj[0], fxId)
			-- SWS does not knows some FX chains, so we have to get at least something
			if not retval then
				retval, str = reaper.TrackFX_GetFXName(capi._contextObj[0], fxId)
			end
			pluginsFilenames[fxId].retval, pluginsFilenames[fxId].str = retval, str
		elseif context == 1 then
			pluginsFilenames[fxId].retval, pluginsFilenames[fxId].str = reaper.NF_TakeFX_GetFXModuleName(
				reaper.GetMediaItemTake_Item(capi
					._contextObj[1]), fxId)
		end
	end
	return pluginsFilenames[fxId].retval, pluginsFilenames[fxId].str
end

local function makeUniqueKey(fxID, fxParm)
	local firstPart, lastPart
	local retval, fxName = getPluginFilename(fxID)
	if retval then
		firstPart = utils.removeSpaces(fxName)
	end
	local retval, parmName = capi.GetParamName(fxID, fxParm, "")
	if retval then
		lastPart = utils.removeSpaces(parmName)
	end
	return string.format("%s.%s", firstPart, lastPart)
end

local function getStep(uniqueKey, notRelyConfig)
	if notRelyConfig then
		return extstate._layout["fx." .. uniqueKey .. ".parmStep"]
	end
	return extstate._layout["fx." .. uniqueKey .. ".parmStep"] or config.getinteger("fxParmStep", 4)
end

local function setStep(uniqueKey, value)
	extstate._layout._forever["fx." .. uniqueKey .. ".parmStep"] = value
end

local function getFindNearestConfig(uniqueKey, notRelyConfig)
	if notRelyConfig then
		return extstate._layout["fx." .. uniqueKey .. ".useFindNearestParmValue"]
	end
	-- The boolean value false and value nil are equivalent in Lua
	local result = extstate._layout["fx." .. uniqueKey .. ".useFindNearestParmValue"]
	if result == nil then
		result = config.getboolean("fx_useFindNearestParmValue", true)
	end
	return result
end

local function setFindNearestConfig(uniqueKey, value)
	extstate._layout._forever["fx." .. uniqueKey .. ".useFindNearestParmValue"] = value
end

local function getFilter(sid)
	local retval = extstate._layout[string.format("%s.parmFilter", sid)]
	if retval ~= nil then
		return tostring(retval)
	end
end

local function setFilter(sid, filter)
	extstate._layout[string.format("%s.parmFilter", sid)] = filter
end

local function getTheBestValue(fxId, parmId)
	return extstate._layout[utils.makeKeySequence(makeUniqueKey(fxId, parmId), "bestValue")]
end

local function setTheBestValue(fxId, parmId, value)
	extstate._layout[utils.makeKeySequence(makeUniqueKey(fxId, parmId), "bestValue")] = value
end

local function shouldBeExcluded(fxId, parmId)
	local retval, fxName = getPluginFilename(fxId)
	if retval == false then
		return false
	end
	local retval, fxParmName = capi.GetParamName(fxId, parmId, "")
	if retval == false then
		return false
	end
	for i = 1, #fxMaskList do
		local maskElement = fxMaskList[i]
		if utils.simpleSearch(fxName, maskElement.fxMask) then
			if utils.simpleSearch(fxParmName, maskElement.paramMask) then
				return true
			end
		end
	end
	return false
end

local function checkKnownAssyncPlugin(fxId)
	local _, fxName = getPluginFilename(fxId)
	for _, plugin in ipairs(knownAssyncPlugins) do
		if utils.simpleSearch(fxName, plugin.name) then
			return true, plugin.delay
		end
	end
	return false
end

local function getStringParmValue(fxId, parmId)
	local fxValue = capi.GetParam(fxId, parmId)
	local retval, buf = capi.FormatParamValue(fxId, parmId, fxValue, "")
	if retval and buf ~= "" then
		return buf, retval
	end
	retval, buf = capi.GetFormattedParamValue(fxId, parmId, "")
	if retval and buf ~= "" then
		return buf, retval
	end
	buf = tostring(utils.numtopercent(capi.GetParamNormalized(fxId, parmId))) .. "%"
	return buf, (retval and buf ~= "")
end

local function setParmValue(fxId, parmId, value)
	local fxValue = capi.GetParam(fxId, parmId)
	local result = capi.SetParam(fxId, parmId, value)
	-- Some plugins works assynchronously, so we have to decelerate our code
	local retval, fxDelay = checkKnownAssyncPlugin(fxId)
	if retval then
		-- break the deceleration process when a value has changed prematurely
		local ms = fxDelay * 0.001
		local curTime = os.clock()
		while (os.clock() - curTime) <= ms do
			if fxValue ~= capi.GetParam(fxId, parmId) then
				break
			end
		end
	end
	return result
end

local function endParmEdit(fxId, parmId)
	capi.EndParamEdit(fxId, parmId)
end

local function getCurrentObjectId()
	local guid = nil
	if context == 0 then
		_, guid = reaper.GetSetMediaTrackInfo_String(capi._contextObj[0], "GUID", "", false)
	elseif context == 1 then
		_, guid = reaper.GetSetMediaItemTakeInfo_String(capi._contextObj[1], "GUID", "", false)
	end
	return guid
end

local function getFormattedFXName(fxId)
	local retval, fxName = capi.GetFXName(fxId, "")
	if retval then
		if fxName:find(":") and fxName:find(": ") then
			local startPos = fxName:find(":") + 2
			local endPos = fxName:find("[(].+$")
			if endPos then
				endPos = endPos - 2
			end
			fxName = fxName:sub(startPos, endPos)
		end
		return fxName
	end
end

local function selectFXInChain(fxId)
	if config.getboolean("selectFXWhenFocusOn", false) then
		if context == 0 and fxId >= capi.GetCount() then
			return reaper.CF_SelectTrackFX(capi._contextObj[0], fxId)
		end
	end
	return false
end

-- One FX parms rendering implementation
-- We have to know the currently rendering FX list has the same sublayouts or not
if extstate._layout.lastObjectId and extstate._layout.lastObjectId ~= getCurrentObjectId() and not whichFXCanbeLoaded then
	extstate._layout.lastObjectId = nil
	-- Let's take a chance and reset the drag
	extstate._layout.fxDrag = nil
end

-- Find the appropriated context prompt for newly created layout
local contextPrompt = nil
if context == 0 then
	if reaper.GetLastTouchedTrack() == reaper.GetMasterTrack() or reaper.GetLastTouchedTrack() == nil then
		contextPrompt = "Master track"
	else
		contextPrompt = "Track"
	end
elseif context == 1 then
	contextPrompt = "Take"
end

-- Keeping split FX implementation
if whichFXCanbeLoaded then
	capi._contextObj[0] = reaper.GetMasterTrack(0)
	contextPrompt = "Master track"
	context = 0
	capi._context = 0
end


function fxLayout.canProvide()
	local result = false
	if context == 0 then
		result = (capi.GetCount() > 0 or capi.GetRecCount() > 0) and capi._contextObj[0] ~= nil
	elseif context == 1 then
		result = capi.GetCount() > 0 and capi._contextObj[1] ~= nil
	end
	return result
end

-- We have to abort the linear code executing if canProvide return false
if fxLayout.canProvide() then
	-- Creating the sublayouts with plug-ins and properties with parameters
	local fxCount = capi.GetCount()
	local fxRecCount = 0
	if context == 0 then
		fxRecCount = capi.GetRecCount()
	end
	if whichFXCanbeLoaded == "monitoring" then
		fxCount = 0
	elseif whichFXCanbeLoaded == "master" then
		fxRecCount = 0
	end
	for i = 0, (fxCount - 1) + (fxRecCount + 1) - 1 do
		local fxInaccuracy = 0
		if i >= fxCount then
			fxInaccuracy = 0x1000000
		end
		-- Ah this beautifull prefixes and postfixes
		local fxName = getFormattedFXName(i + fxInaccuracy)
		if fxName then
			local sid = capi.GetFXGUID(i + fxInaccuracy):gsub("%W", "") .. tostring(fxInaccuracy)
			local fxPrefix = contextPrompt .. " "
			if context == 0 then
				if fxInaccuracy == 0 and capi.GetInstrument() == i then
					fxPrefix = "Instrument "
				else
					if fxInaccuracy == 0x1000000 then
						if contextPrompt and contextPrompt:find("Master") then
							fxPrefix = "Monitoring "
						else
							fxPrefix = fxPrefix .. "input "
						end
					end
				end
			end
			if not fxPrefix:find("Instrument") then
				fxPrefix = fxPrefix .. "FX "
			end
			fxName = fxName .. ({ [true] = "", [false] = " (bypassed)" })[capi.GetEnabled(i + fxInaccuracy)]
			fxName = fxName .. ({ [false] = "", [true] = " (offline)" })[capi.GetOffline(i + fxInaccuracy)]
			fxLayout:registerSublayout(sid, fxPrefix .. fxName)
			local firstExtendedFXProperties = {}
			firstExtendedFXProperties = PropertiesRibbon.initExtendedProperties("FX operations")
			firstExtendedFXProperties:registerProperty {
				get = function(self, parent)
					local message = initOutputMessage()
					message:initType(string.format(
						"Adjust this property to switch the presets for this FX  if one (%s - forward, %s - backward). Perform this property to set a preset by its ID."
						, actions.set.increase.label, actions.set.decrease.label))
					message { label = "Preset" }
					local retval, presetname = capi.GetPreset(parent.fxIndex)
					if retval then
						message { value = presetname }
					else
						message { value = "unavailable" }
					end
					return message
				end,
				set_adjust = function(self, parent, direction)
					local message = initOutputMessage()
					presetIndex, numberOfPresets = capi.GetPresetIndex(parent.fxIndex)
					if presetIndex + direction < 0 then
						message("No more previous property values.")
					elseif presetIndex + direction >= numberOfPresets then
						message("No more next property values.")
					else
						if not capi.SetPresetByIndex(parent.fxIndex, presetIndex + direction) then
							return false, "Could not switch the presets"
						end
					end
					message(self:get(parent))
					return false, message
				end,
				set_perform = function(self, parent)
					local presetIndex, numberOfPresets = capi.GetPresetIndex(parent.fxIndex)
					local retval, answer = getUserInputs("Specify preset",
						{ caption = "Type a preset index:", defValue = presetIndex + 1 })
					if retval then
						if tonumber(answer) then
							if tonumber(answer) <= numberOfPresets and tonumber(answer) > 0 then
								if capi.SetPresetByIndex(parent.fxIndex, answer - 1) then
									return true
								else
									msgBox("Preset specify error",
										string.format("Unable to set a preset with ID %u.", answer))
								end
							else
								msgBox("Preset specify error",
									string.format(
										'You\'re attempting to set a preset which does not exists in.\nYou specified preset: %s, available %s',
										answer,
										numberOfPresets > 1 and ("presets range: from 1 to %u"):format(numberOfPresets) or
										"only 1"))
							end
						elseif utils.simpleSearch(answer, "default") then
							if capi.SetPresetByIndex(parent.fxIndex, -1) then
								return true
							else
								msgBox("Preset specify error", "Unable to set default preset in this FX.")
							end
						elseif utils.simpleSearch(answer, "factory") then
							if capi.SetPresetByIndex(parent.fxIndex, -2) then
								return true
							else
								msgBox("Preset specify error", "Unable to set the factory preset.")
							end
						else
							msgBox("Preset specify error", "Please enter a valid preset ID")
						end
					end
					return false
				end
			}
			-- We have to check some conditions because here's local variable with
			local fxChainOpenEP = {}
			firstExtendedFXProperties:registerProperty(fxChainOpenEP)
			function fxChainOpenEP:get()
				local message = initOutputMessage()
				message "Open FX chain with this FX"
				message:initType("Perform this property to open the FX chain where this FX will be selected.")
				if fxInaccuracy ~= 0 or context ~= 0 then
					message:addType(
						string.format(
							" This property currently unavailable because you're on %s chain., This FX chain is not supported.",
							fxPrefix:gsub("^u", string.lower)), 1)
					message:addType("Unavailable", 2)
				end
				return message
			end

			-- Unfortunately we can only select FX in a track and only with main chains (no input FX chain or monitoring FX).
			if fxInaccuracy == 0 and context == 0 then
				function fxChainOpenEP:set_perform(parent)
					if fxCount > 1 then
						reaper.CF_SelectTrackFX(capi._contextObj[0], parent.fxIndex)
					end
					if capi._contextObj[0] == reaper.GetMasterTrack(0) then
						reaper.Main_OnCommand(40846, 1) -- Track: View FX chain for master track
					else
						reaper.Main_OnCommand(40291, 1) -- Track: View FX chain for current/last touched track
					end
					return true
				end
			end

			firstExtendedFXProperties:registerProperty {
				get = function(self, parent)
					local message = initOutputMessage()
					message:initType("Perform this property to set current FX either offline or online.")
					message("Set FX ")
					if capi.GetOffline(parent.fxIndex) then
						message("online")
					else
						message("offline")
					end
					return message
				end,
				set_perform = function(self, parent)
					local state = capi.GetOffline(parent.fxIndex)
					capi.SetOffline(parent.fxIndex, nor(state))
					-- The state returns with some delay
					return false, string.format("Fx is %s", ({ [true] = "offline", [false] = "online" })[nor(state)])
				end
			}
			firstExtendedFXProperties:registerProperty {
				get = function(self, parent)
					local message = initOutputMessage()
					message:initType(
						"Perform this property to start the drag and drop process. Short instruction how to use it: start the drag process by performing this property. Then, navigate to needed FX category, go to FX extended properties and finish the drag and drop process by performing this property again. At any time this property will signal you that started the drag and drop process or not. If you want to cancel the drag and drop process after you start the process, just drop dragged FX on itself.")
					if extstate._layout.fxDrag then
						if extstate._layout.fxDrag == parent.fxIndex then
							message("Cancel drag")
						else
							message("Drop previously dragged FX here")
						end
					else
						message("Drag FX")
					end
					if fxCount > 1 or fxRecCount > 1 then
						-- I don't know why the expected condition like "if fxCount < 2 or fxRecCount < 2 then" not works, so do nothing here.
					else
						message(" (unavailable)")
					end
					return message
				end,
				set_perform = function(self, parent)
					if fxCount > 1 or fxRecCount > 1 then
						local message = initOutputMessage()
						if extstate._layout.fxDrag then
							if extstate._layout.fxDrag ~= parent.fxIndex then
								-- CopyToTrack and CopyToTake cannot called on our capi metatable directly
								local reorder = nil
								if context == 0 then
									reorder = capi.CopyToTrack
								elseif context == 1 then
									reorder = capi.CopyToTake
								end
								if reorder then
									local srcName = getFormattedFXName(extstate._layout.fxDrag)
									local destName = getFormattedFXName(parent.fxIndex)
									reorder(extstate._layout.fxDrag, capi._contextObj[context], parent.fxIndex, true)
									message(string.format("%s has been dropped to %s", srcName, destName))
									extstate._layout.fxDrag = nil
								else
									message("Error: couldn't define the context focus.")
								end
							else
								extstate._layout.fxDrag = nil
								message("Drag canceled.")
							end
						else
							extstate._layout.fxDrag = parent.fxIndex
							message(string.format("%s has been dragged.", getFormattedFXName(parent.fxIndex)))
						end
						return true, message
					else
						return false, "Here is only one FX."
					end
				end
			}
			firstExtendedFXProperties:registerProperty {
				get = function(self, parent)
					local message = initOutputMessage()
					message:initType("Perform this property to delete current FX from FX chain.")
					message("Delete FX")
					return message
				end,
				set_perform = function(self, parent)
					local fxName = getFormattedFXName(parent.fxIndex)
					if msgBox("Delete FX", string.format('Are you sure you want to delete the FX \"%s\" from %s?',
							fxName,
							fxPrefix:gsub("^%u", string.lower)
							:gsub("%s$", "")), "yesno") == showMessageBoxConsts.button.yes then
						if capi.Delete(parent.fxIndex) then
							-- Is this FX not dragged?
							if extstate._layout.fxDrag then
								if extstate._layout.fxDrag == parent.fxIndex then
									extstate._layout.fxDrag = nil
								end
							end
							return true, string.format("%s has been deleted.", fxName)
						else
							return false, string.format("%s cannot be deleted.", fxName)
						end
					else
						return false
					end
				end
			}
			fxLayout[sid]:registerProperty {
				get = function(self)
					local message = initOutputMessage()
					message:initType(
						"Perform this property to set the filter for filtering the FX parameters list. If you want to remove a filter, set the empty string there. Adjust this property to increase or decrease found number and digits in query to they are matched with existing parameters.")
					message("Filter parameters")
					if getFilter(sid) then
						message(string.format(" (currently is set to %s", getFilter(sid)))
					end
					return message
				end,
				set_perform = function(self)
					local curFilter = getFilter(sid) or ""
					local retval, answer = getUserInputs("Filter parameters by",
						{ caption = "Query:", defValue = curFilter },
						"Type either full parameter name or a part of (Lua patterns supported):")
					if retval then
						if answer ~= "" then
							setFilter(sid, answer)
						else
							setFilter(sid, nil)
						end
					end
					return
				end,
				set_adjust = function(self, direction)
					local curFilter = getFilter(sid)
					if not curFilter or curFilter == "" then
						return "No query is set"
					end
					if not curFilter:find("%d") then
						return "The query contains no digits data"
					end
					local params = {}
					for k = 0, capi.GetNumParams(i + fxInaccuracy) - 1 do
						table.insert(params, select(2, capi.GetParamName(i + fxInaccuracy, k)))
					end
					for num in curFilter:gmatch("%d+") do
						for _, param in ipairs(params) do
							local startPos, endPos = curFilter:find(num)
							local maybeFilter = curFilter:sub(1, startPos - 1) ..
							num + direction .. curFilter:sub(endPos + 1)
							if utils.simpleSearch(param, maybeFilter) then
								setFilter(sid, maybeFilter)
								local message = initOutputMessage()
								message { label = "Current filter", value = maybeFilter }
								return message
							end
						end
					end
					return string.format("No any digits %s matched with parameters.",
						({ [-1] = "decreasion", [1] = "increasion" })[direction])
				end
			}
			if not getFilter(sid) then
				fxLayout[sid]:registerProperty({
					fxIndex = i + fxInaccuracy,
					extendedProperties = firstExtendedFXProperties,
					get = function(self)
						local message = initOutputMessage()
						-- The extended properties notify will be added by the main script side
						message:initType()
						message("FX operations")
						if extstate._layout.fxDrag then
							message("drag and drop process started")
						end
						return message
					end
				}
				)
			end
			local fxParmsCount = capi.GetNumParams(i + fxInaccuracy)
			if extstate._layout.lastObjectId then
				if currentSublayout and currentSublayout ~= sid then
					fxParmsCount = 0
				end
			end
			if capi.GetOffline(i + fxInaccuracy) == true then
				fxParmsCount = 0
			end
			for k = 0, fxParmsCount - 1 do
				local extendedFXProperties = {}
				extendedFXProperties = PropertiesRibbon.initExtendedProperties(string.format("%s parameter actions",
					select(2, capi.GetParamName(i + fxInaccuracy, k))))

				-- Here is non-standart case, so we will write our three-position setter
				extendedFXProperties:registerProperty {
					get = function(self, parent)
						local message = initOutputMessage()
						message:initType(
							"Adjust and perform this three-state setter to set the needed value specified in parentheses.")
						message("three-position setter")
						message(string.format(" (%s - %s, ", actions.set.decrease.label, "minimal parameter value"))
						message(string.format("%s - %s, ", actions.set.perform.label, "root-mean parameter value"))
						message(string.format("%s - %s)", actions.set.increase.label, "maximal parameter value"))
						return message
					end,
					set_adjust = function(self, parent, direction)
						-- We have to fix jumping focus
						extstate._layout.lastRealParmID = parent.parmIndex
						local message = initOutputMessage()
						local _, minState, maxState = capi.GetParam(parent.fxIndex, parent.parmIndex)
						vls = { [actions.set.decrease.direction] = minState, [actions.set.increase.direction] = maxState }
						setParmValue(parent.fxIndex, parent.parmIndex, vls[direction])
						endParmEdit(parent.fxIndex, parent.parmIndex)
						message(string.format("Set to %s", getStringParmValue(parent.fxIndex, parent.parmIndex)))
						return true, message
					end,
					set_perform = function(self, parent)
						-- We have to fix jumping focus
						extstate._layout.lastRealParmID = parent.parmIndex
						local message = initOutputMessage()
						local state, minState, maxState = capi.GetParam(parent.fxIndex, parent.parmIndex)
						local maybeState = maxState / 2
						maybeState = minState + maybeState
						setParmValue(parent.fxIndex, parent.parmIndex, maybeState)
						endParmEdit(parent.fxIndex, parent.parmIndex)
						message(string.format("Set to %s", getStringParmValue(parent.fxIndex, parent.parmIndex)))
						return true, message
					end
				}

				extendedFXProperties:registerProperty {
					get = function(self, parent)
						local message = initOutputMessage()
						message:initType("Perform this property to specify a raw VST parameter data")
						message("Type raw parameter data")
						return message
					end,
					set_perform = function(self, parent)
						local state = capi.GetParamNormalized(parent.fxIndex, parent.parmIndex)
						local retval, answer = getUserInputs("Set parameter",
							{ caption = "Raw parameter value:", defValue = tostring(math.round(state, 5)) },
							"Type raw parameter value:"
						)
						if retval then
							if tonumber(answer) then
								setParmValue(parent.fxIndex, parent.parmIndex, tonumber(answer))
								endParmEdit(parent.fxIndex, parent.parmIndex)
							else
								msgBox("Raw data error", "Seems it is not a raw data.")
								return false
							end
						end
						return true
					end
				}

				extendedFXProperties:registerProperty {
					get = function(self, parent)
						local message = initOutputMessage()
						message:initType("Perform this property to search the specified parameter value.")
						message("Search for parameter value")
						if checkKnownAssyncPlugin(parent.fxIndex) then
							message(" (use with caution here)")
						end
						return message
					end,
					set_perform = function(self, parent)
						if checkKnownAssyncPlugin(parent.fxIndex) then
							if msgBox("Caution", "This FX known as assynchronously working. It means that search process may work extra slow and REAPER may crash due no-response. Are you really sure that you want to continue start the search process?", "yesno") ~= showMessageBoxConsts.button.yes then
								return true
							end
						end
						local retval, curValue = capi.GetFormattedParamValue(parent.fxIndex, parent.parmIndex, "")
						if retval then
							local retval, answer = getUserInputs("Search for parameter value",
								{ caption = "Search query:", defValue = curValue },
								"Type either a part of value string or full string:"
							)
							if retval then
								if not extstate._layout._forever.searchProcessNotify then
									msgBox("Note before searching process starts",
										"REAPER has no any method to get quick list of all values in FX parameters, so search method works using simple brute force with set the step by default of all values in VST scale range on selected parameter. It means that search process may be take long time of. While the search process is active, you will think that REAPER is overloaded, got a freeze and your system may report that REAPER no responses. That's not true. The search process works in main stream, therefore it might be seem like that. Please wait for search process been finished. If no one value found, Properties Ribbon will restore the value was been set earlier, so you will not lost the your unique value.")
									extstate._layout._forever.searchProcessNotify = true
								end
								local searchMode = 0
								if tostring(answer):match("^.") == "<" then
									searchMode = 1
									answer = tostring(answer):sub(2)
								elseif tostring(answer):match("^.") == ">" then
									searchMode = 2
									answer = tostring(answer):sub(2)
								end
								local state, minState, maxState = capi.GetParam(parent.fxIndex, parent.parmIndex)
								local retvalStep, defStep, _, _, isToggle = capi.GetParameterStepSizes(parent.fxIndex,
									parent.parmIndex)
								local searchState = nil
								if searchMode > 0 then
									searchState = state
								else
									searchState = minState
								end
								local ajustingValue = stepsList
									[getStep(makeUniqueKey(parent.fxIndex, parent.parmIndex))].value
								if retvalStep and defStep > 0.0 then
									if isToggle then
										msgBox("Searching in toggle parameter",
											"This parameter is toggle. It means it has only two states, therefore here is no point to search something.")
										return true
									end
									ajustingValue = defStep
								end
								while searchState <= maxState and searchState >= minState do
									if searchMode == 1 then
										searchState = searchState - ajustingValue
									else
										searchState = searchState + ajustingValue
									end
									setParmValue(parent.fxIndex, parent.parmIndex, searchState)
									local wfxValue = getStringParmValue(parent.fxIndex, parent.parmIndex)
									if utils.simpleSearch(wfxValue, answer) then
										state = searchState
										endParmEdit(parent.fxIndex, parent.parmIndex)
										break
									end
								end
								if searchState ~= state then
									local stringForm = 'No any parameter value with \"%s\" query'
									if searchMode == 1 then
										stringForm = stringForm .. " relative from previously set value to the left"
									elseif searchMode == 2 then
										stringForm = stringForm .. " relative from previously set value to the right"
									end
									stringForm = stringForm ..
										" with %s adjusting step. If you're sure that this value exists in this parameter, you may set less adjusting step value for this parameter and run the search process again."
									msgBox("No results", string.format(stringForm, answer,
										stepsList[getStep(makeUniqueKey(parent.fxIndex, parent.parmIndex))].label))
									setParmValue(parent.fxIndex, parent.parmIndex, state)
									endParmEdit(parent.fxIndex, parent.parmIndex)
									return true
								end
							end
						else
							return false,
								"This setting is currently cannot be performed because here's no string  value."
						end
						return true
					end
				}

				extendedFXProperties:registerProperty {
					get = function(self, parent)
						local message = initOutputMessage()
						message:initType()
						if getTheBestValue(parent.fxIndex, parent.parmIndex) then
							message "Revert the best value of this parameter"
							message:addType(
								"Perform this property to revert the previously committed  best value back into this parameter.",
								1)
						else
							message "Commit current parameter value as the best value"
							message:addType(
								"Perform this property to commit current parameter value as the best value. When a best parameter committed, you always may revert it back when you're not satisfied any   adjustment results.",
								1)
						end
						return message
					end,
					set_perform = function(self, parent)
						local message = initOutputMessage()
						local state = getTheBestValue(parent.fxIndex, parent.parmIndex)
						if state then
							setParmValue(parent.fxIndex, parent.parmIndex, state)
							endParmEdit(parent.fxIndex, parent.parmIndex)
							setTheBestValue(parent.fxIndex, parent.parmIndex, nil)
							message { label = "The best parameter value", value = "Reverted" }
						else
							setTheBestValue(parent.fxIndex, parent.parmIndex,
								math.round(capi.GetParam(parent.fxIndex, parent.parmIndex), 4))
							message { label = "The best parameter value is ", value = string.format("Committed as %s", getStringParmValue(parent.fxIndex, parent.parmIndex)) }
						end
						return true, message, true
					end
				}

				extendedFXProperties:registerProperty {
					get = function(self, parent)
						local message = initOutputMessage()
						message:initType(
							"Perform this property to create an envelope with this parameter on an object where this plugin set.")
						message("Create envelope with this parameter")
						return message
					end,
					set_perform = function(self, parent)
						local createEnvelope = nil
						if context == 0 then
							createEnvelope = reaper.GetFXEnvelope
						elseif context == 1 then
							createEnvelope = reaper.TakeFX_GetEnvelope
						end
						local fxParmName = select(2, capi.GetParamName(parent.fxIndex, parent.parmIndex, ""))
						---@diagnostic disable-next-line: need-check-nil
						local newEnvelope = createEnvelope(capi._contextObj[context], parent.fxIndex, parent.parmIndex,
							true)
						if newEnvelope then
							local name
							if context == 0 then
								name = track_properties_macros.getTrackID(
									reaper.GetEnvelopeInfo_Value(newEnvelope, "P_TRACK"), true)
							elseif context == 1 then
								name = item_properties_macros.getTakeID(
									reaper.GetEnvelopeInfo_Value(newEnvelope, "P_ITEM"), true)
							end
							setUndoLabel(parent:get(true))
							-- We have to leave the setting mode, and get method resets this when called without any parameters.
							return true,
								string.format("The envelope for %s created on %s. ", fxParmName, name:lower()) ..
								parent:get()
						else
							return false, "This parameter cannot be added to envelopes. "
						end
					end
				}
				extendedFXProperties:registerProperty {
					get = function(self, parent)
						local message = initOutputMessage()
						message:initType(
							"Perform this property to specify the new filter based on this parameter name. When you use this property, the new filer query input will be opened where the name of this parameter will be filled.")
						message("Compose filter based on this parameter")
						return message
					end,
					set_perform = function(self, parent)
						local _, fxParam = capi.GetParamName(parent.fxIndex, parent.parmIndex)
						local retval, answer = getUserInputs("Filter parameters by",
							{ caption = "Filter query:", defValue = fxParam },
							"Type either full parameter name or a part of (Lua patterns supported):"
						)
						if retval then
							if answer ~= "" then
								setFilter(sid, answer)
							else
								msgBox("Set filter error",
									"You should type any value here. If you wish to clear a filter query, please interract with appropriate property with category actions. Usualy, it is first property anywhere.")
								return false
							end
						end
						return true
					end
				}
				extendedFXProperties:registerProperty {
					get = function(self, parent)
						local message = initOutputMessage()
						message:initType(
							"Adjust this property to choose the needed step for this parameter. Perform this property to reset the parameter step to default configured step.")
						message { label = "Set adjusting step for this parameter" }
						message { value = stepsList[getStep(makeUniqueKey(parent.fxIndex, parent.parmIndex))].label }
						if getStep(makeUniqueKey(parent.fxIndex, parent.parmIndex), true) == nil then
							message { value = " (by default)" }
						end
						return message
					end,
					set_adjust = function(self, parent, direction)
						local message = initOutputMessage()
						local curStepIndex = getStep(makeUniqueKey(parent.fxIndex, parent.parmIndex), true) or
							config.getinteger("fxParmStep", 4)
						if (curStepIndex + direction) > #stepsList then
							message("No more next property values. ")
						elseif (curStepIndex + direction) < 1 then
							message("No more previous property values. ")
						else
							curStepIndex = curStepIndex + direction
						end
						setStep(makeUniqueKey(parent.fxIndex, parent.parmIndex), curStepIndex)
						message(self:get(parent))
						return false, message
					end,
					set_perform = function(self, parent)
						setStep(makeUniqueKey(parent.fxIndex, parent.parmIndex), nil)
						return true, "Reset to default step adjustment"
					end
				}
				extendedFXProperties:registerProperty {
					get = function(self, parent)
						local message = initOutputMessage()
						message:initType(
							"Adjust this property to switch the configuration for searching for nearest value for this parameter only. Perform this property to reset this parameter to default value by Properties Ribbon configuration.")
						message { label = "Use find nearest parameter value method for this parameter" }
						message { value = ({ [false] = "disabled", [true] = "enabled" })[
						getFindNearestConfig(makeUniqueKey(parent.fxIndex, parent.parmIndex))] }
						if getFindNearestConfig(makeUniqueKey(parent.fxIndex, parent.parmIndex), true) == nil then
							message { value = " (by default)" }
						end
						return message
					end,
					set_adjust = function(self, parent, direction)
						local message = initOutputMessage()
						local cfg = getFindNearestConfig(makeUniqueKey(parent.fxIndex, parent.parmIndex), true)
						if direction == actions.set.decrease.direction then
							if cfg ~= false then
								cfg = false
							else
								message("No more previous property values.")
							end
						elseif direction == actions.set.increase.direction then
							if cfg ~= true then
								cfg = true
							else
								message("No more next property values.")
							end
						end
						setFindNearestConfig(makeUniqueKey(parent.fxIndex, parent.parmIndex), cfg)
						message(self:get(parent))
						return false, message
					end,
					set_perform = function(self, parent)
						local message = initOutputMessage()
						setFindNearestConfig(makeUniqueKey(parent.fxIndex, parent.parmIndex), nil)
						message("Set to default value.")
						message(self:get(parent))
						return true, message
					end
				}
				extendedFXProperties:registerProperty {
					get = function(self, parent)
						local message = initOutputMessage()
						message:initType(
							"Perform this property to create new exclude mask based on this FX and its parameter data.")
						message("Add exclude mask based on this parameter")
						return message
					end,
					set_perform = function(self, parent)
						local _, fxName = getPluginFilename(parent.fxIndex)
						local _, parmName = capi.GetParamName(parent.fxIndex, parent.parmIndex, "")
						local retval, answer = getUserInputs("Add new exclude mask", {
								{ caption = "FX plug-in filename mask:", defValue = fxName },
								{ caption = "Parameter mask:",           defValue = parmName }
							},
							"Type the condition mask below which parameter should be excluded. The Lua patterns are supported per every field.,"
						)
						if retval then
							---@diagnostic disable-next-line: param-type-mismatch
							local newFxMask, newParamMask = table.unpack(answer)
							if newFxMask == nil then
								msgBox("Edit mask error", "The FX mask should be filled.")
								return false
							end
							if newParamMask == nil then
								msgBox("Edit mask error", "The parameter mask should be filled.")
								return false
							end
							fxMaskList[#fxMaskList + 1] = {
								fxMask = newFxMask,
								paramMask = newParamMask
							}
						end
						return true
					end
				}
				local retval, fxParmName = capi.GetParamName(i + fxInaccuracy, k, "")
				-- Let allow to render three last parameters for comfort always
				if k < (fxParmsCount - 3) then
					if getFilter(sid) == nil then
						goto skipFilter
					end
					if retval then
						if not utils.simpleSearch(fxParmName, getFilter(sid), ";") then
							goto continue
						end
					else
						goto continue
					end
					::skipFilter::
					if shouldBeExcluded(i + fxInaccuracy, k) then
						goto continue
					end
				end
				fxLayout[sid]:registerProperty({
					extendedProperties = extendedFXProperties,
					parmNum = #fxLayout[sid].properties,
					fxIndex = i + fxInaccuracy,
					parmIndex = k,
					get = function(self)
						local message = initOutputMessage()
						message:initType("Adjust this property to set necessary value for this parameter.")
						-- Define the host native parameters
						if self.parmIndex > fxParmsCount - 4 then
							message { objectId = "Host " }
						end
						local parmIdentification = config.getinteger("reportParmId", 2)
						if parmIdentification > 0 then
							if parmIdentification == 2 then
								message({ objectId = "Parameter " })
							end
							-- Exclude the parm enumeration when this parm is native
							if self.parmIndex < fxParmsCount - 3 then
								local reportMethod = config.getinteger("reportParmMethod", 1)
								if reportMethod == 1 then
									message({ objectId = self.parmNum })
								elseif reportMethod == 2 then
									message({ objectId = self.parmIndex + 1 })
								end
							end
						end
						message({
							label = ({ capi.GetParamName(self.fxIndex, self.parmIndex) })[2],
							value = getStringParmValue(self.fxIndex, self.parmIndex)
						})
						if getTheBestValue(self.fxIndex, self.parmIndex) then
							if getTheBestValue(self.fxIndex, self.parmIndex) ~= math.round(capi.GetParam(self.fxIndex, self.parmIndex), 4) then
								message { value = " (is not the best value)" }
							end
						end
						-- Select current FX in FX chain because we can't make this by another way
						selectFXInChain(self.fxIndex)
						return message
					end,
					set_adjust = function(self, direction)
						-- We have to fix jumping focus
						extstate._layout.lastRealParmID = self.parmIndex
						local message = initOutputMessage()
						local mode = extstate._layout.fxParmMode or 0
						if mode == 0 then
							local stepDefinition = getStep(makeUniqueKey(self.fxIndex, self.parmIndex))
							local ajustingValue = stepsList[stepDefinition].value
							local state, minState, maxState = capi.GetParam(self.fxIndex, self.parmIndex)
							local retvalStep, defStep, smallStep, largeStep, isToggle = capi.GetParameterStepSizes(
								self.fxIndex,
								self.parmIndex)
							local deltaExists = 0
							do
								local retval, parmName = capi.GetParamName(self.fxIndex,
									capi.GetNumParams(self.fxIndex) - 1)
								if retval then
									if parmName == "Delta" then
										deltaExists = 1
									end
								end
							end
							if self.parmIndex == (fxParmsCount - 2 - deltaExists) or (deltaExists == 1 and self.parmIndex == (fxParmsCount - 1
								)) then
								retvalStep, isToggle = true, true
							end
							if direction == actions.set.increase.direction then
								if retvalStep and defStep > 0.0 then
									if (state + defStep) <= maxState then
										setParmValue(self.fxIndex, self.parmIndex, state + defStep)
										endParmEdit(self.fxIndex, self.parmIndex)
									else
										message("No more next parameter values.")
										setParmValue(self.fxIndex, self.parmIndex, maxState)
										endParmEdit(self.fxIndex, self.parmIndex)
									end
								elseif retvalStep and isToggle then
									if state ~= maxState then
										setParmValue(self.fxIndex, self.parmIndex, maxState)
										endParmEdit(self.fxIndex, self.parmIndex)
									else
										message("No more next parameter values.")
									end
								else
									local fxValue, retval = getStringParmValue(self.fxIndex, self.parmIndex)
									local cfg = getFindNearestConfig(makeUniqueKey(self.fxIndex, self.parmIndex))
									if retval and cfg then
										if state < maxState then
											while state <= maxState do
												state = state + ajustingValue
												setParmValue(self.fxIndex, self.parmIndex, state)
												local wfxValue, wretval = getStringParmValue(self.fxIndex, self
													.parmIndex)
												if fxValue ~= wfxValue then
													endParmEdit(self.fxIndex, self.parmIndex)
													break
												end
											end
											if state > maxState then
												setParmValue(self.fxIndex, self.parmIndex, maxState)
												endParmEdit(self.fxIndex, self.parmIndex)
											end
										else
											message("No more next parameter values.")
											setParmValue(self.fxIndex, self.parmIndex, maxState)
											endParmEdit(self.fxIndex, self.parmIndex)
										end
									else
										if (state + ajustingValue) <= maxState then
											setParmValue(self.fxIndex, self.parmIndex, state + ajustingValue)
											endParmEdit(self.fxIndex, self.parmIndex)
										else
											message("No more next parameter values.")
											setParmValue(self.fxIndex, self.parmIndex, maxState)
											endParmEdit(self.fxIndex, self.parmIndex)
										end
									end
								end
							elseif direction == actions.set.decrease.direction then
								if retvalStep and defStep > 0 then
									if (state - defStep) >= minState then
										setParmValue(self.fxIndex, self.parmIndex, state - defStep)
										endParmEdit(self.fxIndex, self.parmIndex)
									else
										message("No more previous parameter values.")
										setParmValue(self.fxIndex, self.parmIndex, minState)
										endParmEdit(self.fxIndex, self.parmIndex)
									end
								elseif retvalStep and isToggle then
									if state ~= minState then
										setParmValue(self.fxIndex, self.parmIndex, minState)
										endParmEdit(self.fxIndex, self.parmIndex)
									else
										message("No previous parameter values.")
									end
								else
									local fxValue, retval = getStringParmValue(self.fxIndex, self.parmIndex)
									local cfg = getFindNearestConfig(makeUniqueKey(self.fxIndex, self.parmIndex))
									if retval and cfg then
										if state > minState then
											while state >= minState do
												state = state - ajustingValue
												setParmValue(self.fxIndex, self.parmIndex, state)
												local wfxValue, wretval = getStringParmValue(self.fxIndex, self
													.parmIndex)
												if wretval then
													if fxValue ~= wfxValue then
														endParmEdit(self.fxIndex, self.parmIndex)
														break
													end
												else
													break
												end
											end
											if state - ajustingValue < minState then
												setParmValue(self.fxIndex, self.parmIndex, minState)
												endParmEdit(self.fxIndex, self.parmIndex)
											end
										else
											message("No more previous parameter values.")
											setParmValue(self.fxIndex, self.parmIndex, minState)
											endParmEdit(self.fxIndex, self.parmIndex)
										end
									else
										if state - ajustingValue >= minState then
											setParmValue(self.fxIndex, self.parmIndex, state - ajustingValue)
											endParmEdit(self.fxIndex, self.parmIndex)
										else
											message("No more previous parameter values.")
											setParmValue(self.fxIndex, self.parmIndex, minState)
											endParmEdit(self.fxIndex, self.parmIndex)
										end
									end
								end
							end
							message(self:get())
							return message
						end
					end
				})
				::continue::
			end
		end
	end

	if fxLayout[currentSublayout] == nil then
		currentSublayout = PropertiesRibbon.findDefaultSublayout(fxLayout)
	end

	-- Here is main jumping focus fix code
	local realParmID = extstate._layout.lastRealParmID
	if realParmID then
		for i = 1, #fxLayout[currentSublayout].properties do
			local v = fxLayout[currentSublayout].properties[i]
			if v.parmIndex then
				if v.parmIndex == realParmID then
					extstate[fxLayout[currentSublayout].section] = i
					extstate._layout.lastRealParmID = nil
				end
			end
		end
	end
end

-- Finishing the one parm FX rendering implementation
-- After all rendering cases you have to store current object to next rendering will be fast
extstate._layout.lastObjectId = getCurrentObjectId()

PropertiesRibbon.presentLayout(fxLayout)
