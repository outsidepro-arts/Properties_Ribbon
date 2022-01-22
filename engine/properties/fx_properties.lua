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
{name="MeldaProduction",delay=6},
{name="Pulsar",delay=2},
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
extstate._forever._layout[string.format("excludeMask%u.fx", idx)] = maskTable.fxMask
extstate._forever._layout[string.format("excludeMask%u.param", idx)] = maskTable.paramMask
else
local i = idx
while extstate._layout[string.format("excludeMask%u.fx", i)] do
if i == idx then
extstate._forever._layout[string.format("excludeMask%u.fx", i)] = nil
extstate._forever._layout[string.format("excludeMask%u.param", i)] = nil
elseif i > idx then
extstate._forever._layout[string.format("excludeMask%u.fx", i-1)] = extstate._layout[string.format("excludeMask%u.fx", i)]
extstate._forever._layout[string.format("excludeMask%u.param", i-1)] = extstate._layout[string.format("excludeMask%u.param", i)]
extstate._forever._layout[string.format("excludeMask%u.fx", i)] = nil
extstate._forever._layout[string.format("excludeMask%u.param", i)] = nil
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


local function makeUniqueKey(fxID, fxParm)
local firstPart, lastPart = nil
local retval, fxName = capi.GetFXName(fxID, "")
if retval then
firstPart = utils.removeSpaces(fxName)
end
local retval, parmName = capi.GetParamName(fxID, fxParm, "")
if retval then
secondPart = utils.removeSpaces(parmName)
end
return string.format("%s.%s", firstPart, secondPart)
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
local retval, fxName = capi.GetFXName(fxId, "")
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
local _, fxName = capi.GetFXName(fxId, "")
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
utils.delay(fxDelay)
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

-- One FX parms rendering implementation
-- We have to know the currently rendering FX list has the same sublayouts or not
if extstate._layout.lastObjectId and extstate._layout.lastObjectId ~= getCurrentObjectId() then
extstate._layout.lastObjectId = nil
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
local retval, fxName = capi.GetFXName(i+fxInaccuracy, "")
if retval then
-- Ah this beautifull prefixes and postfixes
if fxName:find(":") and fxName:find(": ") then
local startPos = fxName:find(":")+2
local endPos = fxName:find("[(].+$")
if endPos then
endPos = endPos-2
end
fxName = fxName:sub(startPos, endPos)
else
if extstate._layout.renameNotify then
reaper.ShowMessageBox("Seems you have renamed the FX which Properties Ribbon tries to load. Note that FX properties defines many process enhancements using real FX name because REAPER does not provide other method to do that. If you're renaming FX which FX properties interract with, the exclude specified parameters and assynchronous plugins definition cannot be work To keep these options working, please leave the original fX name at any string part.", "FX renamed", 0)
extstate._layout.renameNotify = true
end
end
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
fxLayout[sid]:registerProperty({
states = {
string.format("Filter parameters%s", ({[false]="",[true]=string.format(" (currently is set to %s", getFilter(sid))})[(getFilter(sid) ~= nil)]),
},
get = function(self, shouldSaveSetting)
local message = initOutputMessage()
message:initType("Adjust this property to choose needed setting applied for all parameters in this category. Perform this property when you're chosed any of to perform this.", "Adjustable, performable")
local setting = extstate._layout.settingIndex
if not shouldSaveSetting then
setting= nil
extstate._layout.settingIndex = nil
end
setting = setting or 1
message(self.states[setting])
return message
end,
set = function(self, action)
local message = initOutputMessage()
local setting = extstate._layout.settingIndex or 1
if action == actions.set.increase then
if (setting+1) <= #self.states then
extstate._layout.settingIndex = setting+1
else
message("No more next property values.")
end
elseif action == actions.set.decrease then
if (setting-1) >= 1 then
extstate._layout.settingIndex = setting-1
else
message("No more previous property values.")
end
elseif action == actions.set.perform then
if setting == 1 then
local curFilter = getFilter(sid) or ""
local retval, answer = reaper.GetUserInputs("Filter parameters by", 1, "Type either full parameter name or a part of (Lua patterns supported):", curFilter)
if retval then
if answer ~= "" then
setFilter(sid, answer)
else
setFilter(sid, nil)
end
end
end
end
message(self:get(true))
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
local retval, fxParmName = capi.GetParamName(i+fxInaccuracy, k, "")
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
fxLayout[sid]:registerProperty({
settingModes = {
{
label="Switch to adjusting mode",
proc = function(obj)
-- The setting mode will be reset if get method called without any parameters.
return true, obj:get()
end
},
{
label="Set minimal parameter value",
proc=function(obj)
local state, minState, maxState = capi.GetParam(obj.fxIndex, obj.parmIndex)
setParmValue(obj.fxIndex, obj.parmIndex, minState)
endParmEdit(obj.fxIndex, obj.parmIndex)
local retval, curValue = capi.GetFormattedParamValue(obj.fxIndex, obj.parmIndex, "")
local message = initOutputMessage()
message("Set minimal parameter value.")
message(obj:get())
return true, message
end
},
{
label="Set maximal parameter value",
proc=function(obj)
local state, minState, maxState = capi.GetParam(obj.fxIndex, obj.parmIndex)
setParmValue(obj.fxIndex, obj.parmIndex, maxState)
endParmEdit(obj.fxIndex, obj.parmIndex)
local retval, curValue = capi.GetFormattedParamValue(obj.fxIndex, obj.parmIndex, "")
local message = initOutputMessage()
message("Set maximal parameter value.")
message(obj:get())
return true, message
end
},
{
label="Type raw parameter data",
proc=function(obj)
local state = capi.GetParamNormalized(obj.fxIndex, obj.parmIndex)
local retval, answer = reaper.GetUserInputs("Set parameter value", 1, "Type raw parameter value:", tostring(utils.round(state, 5)))
if retval then
if tonumber(answer) then
setParmValue(obj.fxIndex, obj.parmIndex, tonumber(answer))
endParmEdit(obj.fxIndex, obj.parmIndex)
else
reaper.ShowMessageBox("Seems it is not a raw data.", "Raw data error", 0)
return true
end
end
return true, obj:get()
end
},
-- Temporarelly hidden
{
label=string.format("Search for parameter value%s", ({[false]="",[true]=" (use with caution here)"})[checkKnownAssyncPlugin(i)]),
proc=function(obj)
if checkKnownAssyncPlugin(obj.fxIndex) then
if reaper.ShowMessageBox("This FX known as assynchronously working. It means that search process may work extra slow and REAPER may crash due no-response. Are you really sure that you want to keep start the search process?", "Caution", 4) ~= 6 then return false end
end
local retval, curValue = capi.GetFormattedParamValue(obj.fxIndex, obj.parmIndex, "")
if retval then
local retval, answer = reaper.GetUserInputs("Search for parameter value", 1, "Type either a part of value string or full string:", curValue)
if retval then
if not extstate._layout._forever.searchProcessNotify then
reaper.ShowMessageBox("REAPER has no any method to get quick list of all values in FX parameters, so search method works using simple brute force with set the step by default of all values in VST scale range on selected parameter. It means that search process may be take long time of. While the search process is active, you will think that REAPER is overloaded, got a freeze and your system may report that REAPER no responses. That's not true. The search process works in main stream, therefore it might be seem like that. Please wait for search process been finished. If no one value found, Properties Ribbon will restore the value was been set earlier, so you will not lost the your unique value.", "Note before searching process starts", 0)
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
local state, minState, maxState = capi.GetParam(obj.fxIndex, obj.parmIndex)
local retvalStep, defStep, _, _, isToggle = capi.GetParameterStepSizes(obj.fxIndex, obj.parmIndex)
local searchState = nil
if searchMode > 0 then
searchState = state
else
searchState = minState
end
local ajustingValue = stepsList[getStep(makeUniqueKey(obj.fxIndex, obj.parmIndex))].value
if retvalStep and defStep > 0.0 then
	if isToggle then
		reaper.ShowMessageBox("This parameter is toggle. It means it has only two states, therefore here is no point to search something.", "Searching in toggle parameter", 0)
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
setParmValue(obj.fxIndex, obj.parmIndex, searchState)
local wfxValue = getStringParmValue(obj.fxIndex, obj.parmIndex)
if utils.simpleSearch(wfxValue, answer) then
state = searchState
endParmEdit(obj.fxIndex, obj.parmIndex)
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
reaper.ShowMessageBox(string.format(stringForm, answer, stepsList[getStep(makeUniqueKey(obj.fxIndex, obj.parmIndex))].label), "No results", 0)
setParmValue(obj.fxIndex, obj.parmIndex, state)
endParmEdit(obj.fxIndex, obj.parmIndex)
return true
end
end
else
return true, "This setting is currently cannot be performed because here's no string  value."
end
return true, obj:get()
end
},
{
label="Create envelope with this parameter",
proc=function(obj)
local createEnvelope = nil
if context == 0 then
createEnvelope = reaper.GetFXEnvelope
elseif context == 1 then
createEnvelope = reaper.TakeFX_GetEnvelope
end
if createEnvelope(capi._contextObj[context], obj.fxIndex, obj.parmIndex, true) then
local fxParmName = ({capi.GetParamName(obj.fxIndex, obj.parmIndex, "")})[2]
local cobj = capi._contextObj[context]
local name = nil
if context == 0 then
local retval, buf = reaper.GetTrackName(cobj)
if retval then
name = buf
end
elseif context == 1 then
local retval, buf = reaper.GetSetMediaItemTakeInfo_String(cobj, "P_NAME", "", false)
if retval then
name = buf
end
end
setUndoLabel(obj:get(true))
-- We have to leave the setting mode, and get method resets this when called without any parameters.
return true, string.format("The envelope for %s created on %s %s. ", fxParmName, contextPrompt:lower(), name)..obj:get()
else
return true, "This parameter cannot be added to envelopes. "..obj:get()
end
end
},
{
label="Compose filter based on this parameter",
proc = function (obj)
local _, fxParam = capi.GetParamName(obj.fxIndex, obj.parmIndex)
local retval, answer = reaper.GetUserInputs("Filter parameters by", 1, "Type either full parameter name or a part of (Lua patterns supported):", fxParam)
if retval then
if answer ~= "" then
setFilter(sid, answer)
else
reaper.ShowMessageBox("You should type any value here. If you wish to clear a filter query, please interract with appropriate property with category actions. Usualy, it is first property anywhere.", "Set filter error", 0)
end
end
return true
end
},
{
	label=string.format("Set adjusting step for this parameter (currently %s)", stepsList[getStep(makeUniqueKey(i, k))].label),
	proc=function(obj)
	local curStepIndex = getStep(makeUniqueKey(obj.fxIndex, obj.parmIndex), true) or 0
	if (curStepIndex+1) <= #stepsList then
	curStepIndex = curStepIndex+1
	elseif (curStepIndex+1) > #stepsList then
	setStep(makeUniqueKey(obj.fxIndex, obj.parmIndex), nil)
	return true, "Reset to default step adjustment"
	end
	setStep(makeUniqueKey(obj.fxIndex, obj.parmIndex), curStepIndex)
	return true, stepsList[curStepIndex].label
	end
	},
	{
		label=string.format("Use find nearest parameter value method for this parameter (currently %s)", ({[false]="disabled",[true]="enabled"})[getFindNearestConfig(makeUniqueKey(i, k))]),
		proc=function(obj)
		local cfg= getFindNearestConfig(makeUniqueKey(obj.fxIndex, obj.parmIndex), true)
		if cfg == false then
			cfg = true
		elseif cfg == true then
			setFindNearestConfig(makeUniqueKey(obj.fxIndex, obj.parmIndex), nil)
			return true, "Set to default value"
		elseif cfg == nil then
			cfg = false
		end
		setFindNearestConfig(makeUniqueKey(obj.fxIndex, obj.parmIndex), cfg)
		return true, ({[false]="Disabled",[true]="Enabled"})[cfg]
		end
		},
		{
label="Add exclude mask based on this parameter",
proc=function(obj)
local _, fxName = capi.GetFXName(obj.fxIndex, "")
local _, parmName = capi.GetParamName(obj.fxIndex, obj.parmIndex, "")
local retval, answer = reaper.GetUserInputs("Add new exclude mask", 3, "FX mask:,Parameter mask:", "Type the condition mask below which parameter should be excluded. The Lua patterns are supported per every field.,"..string.format("%s,%s", fxName, parmName))
if retval then
local newFxMask, newParamMask = answer:match("^.+[,](.+)[,](.+)")
if newFxMask == nil then
reaper.ShowMessageBox("The FX mask should be filled.", "Edit mask error", 0)
return true
end
if newParamMask == nil then
reaper.ShowMessageBox("The parameter mask should be filled.", "Edit mask error", 0)
return true
end
fxMaskList[#fxMaskList+1] = {
fxMask = newFxMask,
paramMask=newParamMask
}
end
return true
end
}
},
parmNum = #fxLayout[sid].properties,
fxIndex=i+fxInaccuracy,
parmIndex = k,
get = function(self, shouldSaveMode)
local message = initOutputMessage()
local mode = extstate._layout.fxParmMode
shouldSaveMode = shouldSaveMode or false
if shouldSaveMode == false then
if mode and mode > 0 then
message("Adjusting mode. ")
extstate._layout.fxParmMode = nil
mode = nil
end
end
mode = mode or 0
if mode > 0 then
message:initType("Adjust this property to choose needed setting mode for this parameter. Perform this property to activate selected setting.", "Adjustable, performable")
message(self.settingModes[mode].label)
elseif mode == 0 then
message:initType("Adjust this property to set necessary value for this parameter. Toggle this property to switch the setting mode for this property.", "Adjustable, toggleable")
local parmIdentification = config.getinteger("reportParmId", 2)
if parmIdentification > 0 then
if parmIdentification == 2 then
message("Parameter ")
end
local reportMethod = config.getinteger("reportParmMethod", 1)
if reportMethod == 1 then
	message(self.parmNum)
elseif reportMethod == 2 then
	message(self.parmIndex+1)
end
message(" ")
end
message(string.format("%s: %s", ({capi.GetParamName(self.fxIndex, self.parmIndex)})[2], getStringParmValue(self.fxIndex, self.parmIndex)))
end
return message
end,
set = function(self, action)
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
if action == actions.set.increase then
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
elseif action == actions.set.decrease then
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
elseif action == actions.set.toggle then
message("Setting mode.")
extstate._layout.fxParmMode = 1
message(self:get(true), true)
return message
end
message(self:get())
return message
elseif mode > 0 then
if action == actions.set.increase then
if (mode+1) <= #self.settingModes then
extstate._layout.fxParmMode = mode+1
else
message("No more next parameter settings.")
end
elseif action == actions.set.decrease then
if (mode-1) > 0 then
extstate._layout.fxParmMode = mode-1
else
message("No more previous parameter settings.")
end
elseif action == actions.set.perform then
local result, str = self.settingModes[mode].proc(self)
if result == true then
return str
else
message(str)
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