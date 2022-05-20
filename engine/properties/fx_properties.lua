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
]]--

-- This is the alternative of OSARA FX parameters, but more flexible. I wrote this layout because the proposed by OSARA is not satisfied me by a few reasons.


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
local whichFXCanbeLoaded = extstate._layout.loadFX

-- Steps list for adjusting (will be defined using configuration)
local stepsList = {
{label="smallest",value=0.000001}, -- less smallest step causes the REAPER freezes
{label="small",value=0.00001},
{label="medium",value=0.0001},
{label="big",value=0.001},
{label="biggest",value=0.01},
{label="huge",value=0.1}
}

-- This table contains known plugins names or its masks which work assynchronously. When we know that one of known plugins works that, we have to decelerate the set parameter values to let the plugin to apply a new value. We have not to do this at other cases to not make our code too many slow.
local knownAssyncPlugins = {
{name="M%u%w+[.].+",delay=6},
{name="Pulsar",delay=2},
{name="Replika", delay=5}
}


-- API simplification to make calls as contextual
-- capi stands for "contextual API"
local capi = setmetatable({
_contextObj = setmetatable({}, {
-- REAPER generates error when media item is nil so we have to wrap these handles to metatable
__index = function(self, key)
if key == 0 then
	local lastTouched = reaper.GetLastTouchedTrack()
	if lastTouched then
	return lastTouched
	else
		if (reaper.GetMasterTrackVisibility()&1) == 1 then
			return reaper.GetMasterTrack(0)
		end
		end
elseif key == 1 then
if reaper.GetSelectedMediaItem(0, 0) then
return reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, 0))
end
return nil
end
end
}),
_contextPrefix = {
[0]="TrackFX_",
[1]="TakeFX_"
}
}, {
__index = function(self, key)
return function(...)
if reaper.APIExists(self._contextPrefix[context]..key) then
return reaper[self._contextPrefix[context]..key](self._contextObj[context], ...)
else
if context == 0 and key:find("Envelope") then
 if reaper[key] then
 return reaper[key](self._contextObj[context], ...)
end 
end
 error(string.format("Contextual API wasn't found method %s", self._contextPrefix[context]..key))
 end
end
end
})
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
]]--



-- Some internal functions
-- Exclude masks metatable
local fxMaskList = setmetatable({}, {
__index=function(self, idx)
if type(idx) == "number" then
local fxMask = extstate._layout[string.format("excludeMask%u.fx", idx)]
local parmMask = extstate[string.format("fx_properties.excludeMask%u.param", idx)]
return {["fxMask"]=fxMask,["paramMask"]=parmMask}
end
error(string.format("Expected key type %s (got %s)", type(1), type(idx)))
end,
__newindex=function(self, idx, maskTable)
if maskTable then
assert(type(maskTable) == "table", string.format("Expected key type %s (got %s)", type({}), type(maskTable)))
assert(maskTable.fxMask, "Expected field fxMask")
assert(maskTable.paramMask, "Expected field paramMask")
extstate._layout._forever[string.format("excludeMask%u.fx", idx)] = maskTable.fxMask
extstate._layout._forever[string.format("excludeMask%u.param", idx)] = maskTable.paramMask
else
local i = idx
while extstate._layout[string.format("excludeMask%u.fx", i)] do
if i == idx then
extstate._layout._forever[string.format("excludeMask%u.fx", i)] = nil
extstate._layout._forever[string.format("excludeMask%u.param", i)] = nil
elseif i > idx then
extstate._layout._forever[string.format("excludeMask%u.fx", i-1)] = extstate._layout[string.format("excludeMask%u.fx", i)]
extstate._layout._forever[string.format("excludeMask%u.param", i-1)] = extstate._layout[string.format("excludeMask%u.param", i)]
extstate._layout._forever[string.format("excludeMask%u.fx", i)] = nil
extstate._layout._forever[string.format("excludeMask%u.param", i)] = nil
end
i = i+1
end
end
end,
__len=function(self)
local mCount = 0
while extstate._layout[string.format("excludeMask%u.fx", mCount+1)] do
mCount = mCount+1
end
return mCount
end
})

local pluginsFilenames = {}
local function getPluginFilename(fxId)
-- The SWS authors set the own prefix on the  top of function name, so we cannot use capi metatable
-- These functions works slow, so we will cache plugin names
if not pluginsFilenames[fxId] then
pluginsFilenames[fxId] = {}
if context == 0 then
pluginsFilenames[fxId].retval, pluginsFilenames[fxId].str = reaper.BR_TrackFX_GetFXModuleName(capi._contextObj[0], fxId)
elseif context == 1 then
pluginsFilenames[fxId].retval, pluginsFilenames[fxId].str = reaper.NF_TakeFX_GetFXModuleName(reaper.GetMediaItemTake_Item(capi._contextObj[1]), fxId)
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
return extstate._layout["fx."..uniqueKey..".parmStep"]
end
return extstate._layout["fx."..uniqueKey..".parmStep"] or config.getinteger("fxParmStep", 4)
end

local function setStep(uniqueKey, value)
extstate._layout._forever["fx."..uniqueKey..".parmStep"] = value
end

local function getFindNearestConfig(uniqueKey, notRelyConfig)
	if notRelyConfig then
		return extstate._layout["fx."..uniqueKey..".useFindNearestParmValue"]
	end
	-- The boolean value false and value nil are equivalent in Lua
	local result = extstate._layout["fx."..uniqueKey..".useFindNearestParmValue"]
	if result == nil then
		result = config.getboolean("fx_useFindNearestParmValue", true)
	end
	return  result
end

local function setFindNearestConfig(uniqueKey, value)
	extstate._layout._forever["fx."..uniqueKey..".useFindNearestParmValue"] = value
end

local function getFilter(sid)
return extstate._layout[string.format("%s.parmFilter", sid)]
end

local function setFilter(sid, filter)
extstate._layout[string.format("%s.parmFilter", sid)] = filter
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
buf = tostring(utils.numtopercent(capi.GetParamNormalized(fxId, parmId))).."%"
return buf, (retval and buf ~= "")
end

local function setParmValue(fxId, parmId, value)
local fxValue = capi.GetParam(fxId, parmId)
local result = capi.SetParam(fxId, parmId, value)
-- Some plugins works assynchronously, so we have to decelerate our code
local retval, fxDelay = checkKnownAssyncPlugin(fxId)
if retval then
-- break the deceleration process when a value has changed prematurely
local ms = fxDelay*0.001
local curTime = os.clock()
while (os.clock()-curTime) <= ms do
if fxValue ~= capi.GetParam(fxId, parmId)then
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
local startPos = fxName:find(":")+2
local endPos = fxName:find("[(].+$")
if endPos then
endPos = endPos-2
end
fxName = fxName:sub(startPos, endPos)
end
return fxName
end
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
end

local fxLayout = initLayout("FX properties")

function fxLayout.canProvide()
local result = false
if context == 0 then
result = (capi.GetCount() > 0 or capi.GetRecCount() > 0)
elseif context == 1 then
result = (capi.GetCount() > 0)
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
for i = 0, (fxCount-1)+(fxRecCount+1)-1 do
local fxInaccuracy = 0
if i >= fxCount then
fxInaccuracy = 0x1000000
end
-- Ah this beautifull prefixes and postfixes
local fxName = getFormattedFXName(i+fxInaccuracy)
if fxName then
local sid = capi.GetFXGUID(i+fxInaccuracy):gsub("%W", "")..tostring(fxInaccuracy)
local fxPrefix = contextPrompt.." "
if context == 0 then
if fxInaccuracy == 0 and capi.GetInstrument() == i then
fxPrefix = "Instrument "
else
if fxInaccuracy == 0x1000000 then
if contextPrompt:find("Master") then
fxPrefix = "Monitoring "
else
fxPrefix = fxPrefix.."input "
end
end
end
end
if not fxPrefix:find("Instrument") then
fxPrefix = fxPrefix.."FX "
end
fxName = fxName..({[true]="",[false]=" (bypassed)"})[capi.GetEnabled(i+fxInaccuracy)]
fxName = fxName..({[false]="",[true]=" (offline)"})[capi.GetOffline(i+fxInaccuracy)]
fxLayout:registerSublayout(sid, fxPrefix..fxName)
local firstExtendedFXProperties = {}
firstExtendedFXProperties = initExtendedProperties("FX operation")
firstExtendedFXProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Perform this property to set the filter for filtering the FX parameters list. If you want to remove a filter, set the empty string there.", "Performable")
message("Filter parameters")
if getFilter(sid) then
message(string.format(" (currently is set to %s", getFilter(sid)))
end
return message
end,
set_perform = function(self, parent)
local curFilter = getFilter(sid) or ""
local retval, answer = reaper.GetUserInputs("Filter parameters by", 1, "Type either full parameter name or a part of (Lua patterns supported):", curFilter)
if retval then
if answer ~= "" then
setFilter(sid, answer)
else
setFilter(sid, nil)
end
end
return true
end
}
firstExtendedFXProperties:registerProperty{
get = function (self, parent)
local message = initOutputMessage()
message:initType("Perform this property to set current FX either offline or online.", "Performable")
message("Set FX ")
if capi.GetOffline(i+fxInaccuracy) then
message("online")
else
message("offline")
end
return message
end,
set_perform = function(self, parent)
local state = capi.GetOffline(parent.fxIndex)
capi.SetOffline(parent.fxIndex, utils.nor(state))
-- The state returns with some delay
return false, string.format("Fx is %s", ({[true]="offline",[false]="online"})[utils.nor(state)])
end
}
firstExtendedFXProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Perform this property to start the drag and drop process. Short instruction how to use it: start the drag process by performing this property. Then, navigate to needed FX category, go to FX extended properties and finish the drag and drop process by performing this property again. At any time this property will signal you that started the drag and drop process or not. If you want to cancel the drag and drop process after you start the process, just drop dragged FX on itself.", "Performable")
if extstate._layout.fxDrag then
message("Drop previously dragged FX here")
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
set_perform = function(self, parent )
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
firstExtendedFXProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Perform this property to delete current FX from FX chain. You will not get any questions, but you can undo this action at anytime.", "Performable")
message("Delete FX")
return message
end,
set_perform = function(self, parent)
local fxName = getFormattedFXName(parent.fxIndex)
if capi.Delete(parent.fxIndex) then
-- Is this FX not dragged?
if extstate._layout.fxDrag then if extstate._layout.fxDrag == parent.fxIndex then
extstate._layout.fxDrag = nil
end end	
return true, string.format("%s has been deleted.", fxName)
else
return false, string.format("%s cannot be deleted.", fxName)
end
end	
}
fxLayout[sid]:registerProperty({
fxIndex = i+fxInaccuracy,
extendedProperties = firstExtendedFXProperties,
get = function(self)
local message = initOutputMessage()
-- The extended properties notify will be added by the main script side
message:initType("", "")
message("FX operations")
return message
end
}
)
local fxParmsCount  = capi.GetNumParams(i+fxInaccuracy)
if extstate._layout.lastObjectId then
if currentSublayout and currentSublayout ~= sid then
fxParmsCount = 0
end
end
if capi.GetOffline(i+fxInaccuracy) == true then
fxParmsCount = 0
end
for k = 0, fxParmsCount-1 do
local extendedFXProperties = {}
extendedFXProperties = initExtendedProperties("Parameter actions")

-- Here is non-standart case, so we will write our three-position setter
extendedFXProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Adjust and perform this three-state setter to set the needed value specified in parentheses.", "Adjustable, performable")
message("three-position setter")
message(string.format(" (%s - %s, ", actions.set.decrease.label, "minimal parameter value"))
message(string.format("%s - %s, ", actions.set.perform.label, "root-mean parameter value"))
message(string.format("%s - %s)", actions.set.increase.label, "maximal parameter value"))
return message
end,
set_adjust = function(self, parent, direction)
local message = initOutputMessage()
local _, minState, maxState = capi.GetParam(parent.fxIndex, parent.parmIndex)
vls = {[actions.set.decrease.direction]=minState,[actions.set.increase.direction]=maxState}
setParmValue(parent.fxIndex, parent.parmIndex, vls[direction])
endParmEdit(parent.fxIndex, parent.parmIndex)
message(string.format("Set to %s", getStringParmValue(parent.fxIndex, parent.parmIndex)))
return true, message
end,
set_perform = function(self, parent)
local message = initOutputMessage()
local state, minState, maxState = capi.GetParam(parent.fxIndex, parent.parmIndex)
local maybeState = maxState/2
maybeState = minState+maybeState
setParmValue(parent.fxIndex, parent.parmIndex, maybeState)
endParmEdit(parent.fxIndex, parent.parmIndex)
message(string.format("Set to %s", getStringParmValue(parent.fxIndex, parent.parmIndex)))
return true, message
end
}

extendedFXProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Perform this property to specify a raw VST parameter data", "Performable")
message("Type raw parameter data")
return message
end,
set_perform=function(self, parent)
local state = capi.GetParamNormalized(parent.fxIndex, parent.parmIndex)
local retval, answer = reaper.GetUserInputs("Set parameter value", 1, "Type raw parameter value:", tostring(utils.round(state, 5)))
if retval then
if tonumber(answer) then
setParmValue(parent.fxIndex, parent.parmIndex, tonumber(answer))
endParmEdit(parent.fxIndex, parent.parmIndex)
else
reaper.ShowMessageBox("Seems it is not a raw data.", "Raw data error", showMessageBoxConsts.sets.ok)
return false
end
end
return true
end
}

extendedFXProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Perform this property to search the specified parameter value.", "Performable")
message("Search for parameter value")
if checkKnownAssyncPlugin(parent.fxIndex) then
message(" (use with caution here)")
end
return message
end,
set_perform=function(self, parent)
if checkKnownAssyncPlugin(parent.fxIndex) then
if reaper.ShowMessageBox("This FX known as assynchronously working. It means that search process may work extra slow and REAPER may crash due no-response. Are you really sure that you want to continue start the search process?", "Caution", showMessageBoxConsts.sets.yesno) ~= showMessageBoxConsts.button.yes then return true end
end
local retval, curValue = capi.GetFormattedParamValue(parent.fxIndex, parent.parmIndex, "")
if retval then
local retval, answer = reaper.GetUserInputs("Search for parameter value", 1, "Type either a part of value string or full string:", curValue)
if retval then
if not extstate._layout._forever.searchProcessNotify then
reaper.ShowMessageBox("REAPER has no any method to get quick list of all values in FX parameters, so search method works using simple brute force with set the step by default of all values in VST scale range on selected parameter. It means that search process may be take long time of. While the search process is active, you will think that REAPER is overloaded, got a freeze and your system may report that REAPER no responses. That's not true. The search process works in main stream, therefore it might be seem like that. Please wait for search process been finished. If no one value found, Properties Ribbon will restore the value was been set earlier, so you will not lost the your unique value.", "Note before searching process starts", showMessageBoxConsts.sets.ok)
extstate._layout._forever.searchProcessNotify = true
end
local searchMode = 0
if answer:match("^.") == "<" then
searchMode = 1
answer = answer:sub(2)
elseif answer:match("^.") == ">" then
searchMode = 2
answer = answer:sub(2)
end
local state, minState, maxState = capi.GetParam(parent.fxIndex, parent.parmIndex)
local retvalStep, defStep, _, _, isToggle = capi.GetParameterStepSizes(parent.fxIndex, parent.parmIndex)
local searchState = nil
if searchMode > 0 then
searchState = state
else
searchState = minState
end
local ajustingValue = stepsList[getStep(makeUniqueKey(parent.fxIndex, parent.parmIndex))].value
if retvalStep and defStep > 0.0 then
	if isToggle then
		reaper.ShowMessageBox("This parameter is toggle. It means it has only two states, therefore here is no point to search something.", "Searching in toggle parameter", showMessageBoxConsts.sets.ok)
		return true
	end
ajustingValue = defStep
end
while searchState <= maxState and searchState >= minState do
if searchMode == 1 then
searchState = searchState-ajustingValue
else
searchState = searchState+ajustingValue
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
stringForm = stringForm.." relative from previously set value to the left"
elseif searchMode == 2 then
stringForm = stringForm.." relative from previously set value to the right"
end
stringForm = stringForm.." with %s adjusting step. If you're sure that this value exists in this parameter, you may set less adjusting step value for this parameter and run the search process again."
reaper.ShowMessageBox(string.format(stringForm, answer, stepsList[getStep(makeUniqueKey(parent.fxIndex, parent.parmIndex))].label), "No results", showMessageBoxConsts.sets.ok)
setParmValue(parent.fxIndex, parent.parmIndex, state)
endParmEdit(parent.fxIndex, parent.parmIndex)
return true
end
end
else
return false, "This setting is currently cannot be performed because here's no string  value."
end
return true
end
}

extendedFXProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Perform this property to create an envelope with this parameter on an object where this plugin set.", "Performable")
message("Create envelope with this parameter")
return message
end,
set_perform=function(parent)
local createEnvelope = nil
if context == 0 then
createEnvelope = reaper.GetFXEnvelope
elseif context == 1 then
createEnvelope = reaper.TakeFX_GetEnvelope
end
local fxParmName = ({capi.GetParamName(parent.fxIndex, parent.parmIndex, "")})[2]
local newEnvelope = createEnvelope(capi._contextObj[context], parent.fxIndex, parent.parmIndex, true)
if newEnvelope then
local name
if context == 0 then
name = track_properties_macros.getTrackID(reaper.GetEnvelopeInfo_Value(newEnvelope, "P_TRACK"), true)
elseif context == 1 then
name = item_properties_macros.getTakeID(reaper.GetEnvelopeInfo_Value(newEnvelope, "P_ITEM"), true)
end
setUndoLabel(parent:get(true))
-- We have to leave the setting mode, and get method resets this when called without any parameters.
return true, string.format("The envelope for %s created on %s. ", fxParmName, name:lower())..parent:get()
else
return false, "This parameter cannot be added to envelopes. "
end
end
}
extendedFXProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Perform this property to specify the new filter based on this parameter name. When you use this property, the new filer query input will be opened where the name of this parameter will be filled.", "Performable")
message("Compose filter based on this parameter")
return message
end,
set_perform = function (self, parent)
local _, fxParam = capi.GetParamName(parent.fxIndex, parent.parmIndex)
local retval, answer = reaper.GetUserInputs("Filter parameters by", 1, "Type either full parameter name or a part of (Lua patterns supported):", fxParam)
if retval then
if answer ~= "" then
setFilter(sid, answer)
else
reaper.ShowMessageBox("You should type any value here. If you wish to clear a filter query, please interract with appropriate property with category actions. Usualy, it is first property anywhere.", "Set filter error", showMessageBoxConsts.sets.ok)
return false
end
end
return true
end
}
extendedFXProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Adjust this property to choose the needed step for this parameter. Perform this property to reset the parameter step to default configured step.", "Adjustable, performable")
message{label="Set adjusting step for this parameter"}
if getStep(makeUniqueKey(parent.fxIndex, parent.parmIndex)) then
message{value=stepsList[getStep(makeUniqueKey(i, k))].label}
else
message{value="default value"}
end
return message
end,
set_adjust=function(self, parent, direction)
local message = initOutputMessage()
	local curStepIndex = getStep(makeUniqueKey(parent.fxIndex, parent.parmIndex), true) or config.getinteger("fxParmStep", 4)
if (curStepIndex+direction) > #stepsList then
message("No more next property values. ")
elseif (curStepIndex+direction) < 1 then
message("No more previous property values. ")
else
curStepIndex = curStepIndex+direction
end
setStep(makeUniqueKey(parent.fxIndex, parent.parmIndex), curStepIndex)
message(self:get(parent))
return false, message
end,
set_perform = function(self, parent)
setStep(makeUniqueKey(parent.fxIndex, parent.parmIndex), nil)
return false, "Reset to default step adjustment"
end
}
extendedFXProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Toggle this property to switch the configuration for searching for nearest value for this parameter only.", "Toggleable")
message{label="Use find nearest parameter value method for this parameter"}
message{value=({[false]="disabled",[true]="enabled"})[getFindNearestConfig(makeUniqueKey(i, k))]}
return message
end,
set_perform=function(self, parent)
local message = initOutputMessage()
local cfg= getFindNearestConfig(makeUniqueKey(parent.fxIndex, parent.parmIndex), true)
if cfg == false then
cfg = true
elseif cfg == true then
setFindNearestConfig(makeUniqueKey(parent.fxIndex, parent.parmIndex), nil)
message("Set to default value")
elseif cfg == nil then
cfg = false
end
setFindNearestConfig(makeUniqueKey(parent.fxIndex, parent.parmIndex), cfg)
message(self:get(parent))
return false, message
end
}
extendedFXProperties:registerProperty{
get = function(self, parent)
local message = initOutputMessage()
message:initType("Perform this property to create new exclude mask based on this FX and its parameter data.", "Performable")
message("Add exclude mask based on this parameter")
return message
end,
set_perform=function(self, parent)
local _, fxName = getPluginFilename(parent.fxIndex)
local _, parmName = capi.GetParamName(parent.fxIndex, parent.parmIndex, "")
local retval, answer = reaper.GetUserInputs("Add new exclude mask", 3, "FX plug-in filename mask:,Parameter mask:", "Type the condition mask below which parameter should be excluded. The Lua patterns are supported per every field.,"..string.format("%s,%s", fxName, parmName))
if retval then
local newFxMask, newParamMask = answer:match("^.+[,](.+)[,](.+)")
if newFxMask == nil then
reaper.ShowMessageBox("The FX mask should be filled.", "Edit mask error", showMessageBoxConsts.sets.ok)
return false
end
if newParamMask == nil then
reaper.ShowMessageBox("The parameter mask should be filled.", "Edit mask error", showMessageBoxConsts.sets.ok)
return false
end
fxMaskList[#fxMaskList+1] = {
fxMask = newFxMask,
paramMask=newParamMask
}
end
return true
end
}
local retval, fxParmName = capi.GetParamName(i+fxInaccuracy, k, "")
-- Let allow to render three last parameters for comfort always
if k < (fxParmsCount-3) then
if getFilter(sid) == nil then
goto skipFilter
end
if retval then
if not utils.simpleSearch(fxParmName, getFilter(sid)) then
goto continue
end
else
goto continue
end
::skipFilter::
if shouldBeExcluded(i+fxInaccuracy, k) then
goto continue
end
end	
fxLayout[sid]:registerProperty({
extendedProperties = extendedFXProperties,
parmNum = #fxLayout[sid].properties,
fxIndex=i+fxInaccuracy,
parmIndex = k,
get = function(self)
local message = initOutputMessage()
message:initType("Adjust this property to set necessary value for this parameter.", "Adjustable")
-- Define the host native parameters
if self.parmIndex > fxParmsCount-4 then
message{objectId="Host "}
end
local parmIdentification = config.getinteger("reportParmId", 2)
if parmIdentification > 0 then
if parmIdentification == 2 then
message({objectId="Parameter "})
end
-- Exclude the parm enumeration when this parm is native
if self.parmIndex < fxParmsCount-3 then
local reportMethod = config.getinteger("reportParmMethod", 1)
if reportMethod == 1 then
message({objectId=self.parmNum})
elseif reportMethod == 2 then
message({objectId=self.parmIndex+1})
end
end
end
message({label=({capi.GetParamName(self.fxIndex, self.parmIndex)})[2], value=getStringParmValue(self.fxIndex, self.parmIndex)})
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
local retvalStep, defStep, smallStep, largeStep, isToggle = capi.GetParameterStepSizes(self.fxIndex, self.parmIndex)
local deltaExists = 0
do
local retval, parmName = capi.GetParamName(self.fxIndex, capi.GetNumParams(self.fxIndex)-1)
if retval then
if parmName == "Delta" then
deltaExists = 1
end
end
end
if self.parmIndex == (fxParmsCount-2-deltaExists) or (deltaExists == 1 and self.parmIndex == (fxParmsCount-1)) then
retvalStep, isToggle = true, true
end
if direction == actions.set.increase.direction then
	if retvalStep and defStep > 0.0 then
	if (state+defStep) <= maxState then
setParmValue(self.fxIndex, self.parmIndex, state+defStep)
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
state = state+ajustingValue
setParmValue(self.fxIndex, self.parmIndex, state)
local wfxValue, wretval = getStringParmValue(self.fxIndex, self.parmIndex)
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
if (state+ajustingValue) <= maxState then
setParmValue(self.fxIndex, self.parmIndex, state+ajustingValue)
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
if (state-defStep) >= minState then
setParmValue(self.fxIndex, self.parmIndex, state-defStep)
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
state = state-ajustingValue
setParmValue(self.fxIndex, self.parmIndex, state)
local wfxValue, wretval = getStringParmValue(self.fxIndex, self.parmIndex)
if wretval then
if fxValue ~= wfxValue then
endParmEdit(self.fxIndex, self.parmIndex)
break
end
else
break
end
end
if state-ajustingValue < minState then
setParmValue(self.fxIndex, self.parmIndex, minState)
endParmEdit(self.fxIndex, self.parmIndex)
end
else
message("No more previous parameter values.")
setParmValue(self.fxIndex, self.parmIndex, minState)
endParmEdit(self.fxIndex, self.parmIndex)
end
else
if state-ajustingValue >= minState then
setParmValue(self.fxIndex, self.parmIndex, state-ajustingValue)
endParmEdit(self.fxIndex, self.parmIndex)
else
message("No more previous parameter values.")
setParmValue(self.fxIndex, self.parmIndex, minState)
endParmEdit(self.fxIndex, self.parmIndex)
end
end
end
end
message(self:get(true))
return message
end
end
})
::continue::
end
end
end

if fxLayout[currentSublayout] == nil then
currentSublayout = findDefaultSublayout(fxLayout)
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

return fxLayout