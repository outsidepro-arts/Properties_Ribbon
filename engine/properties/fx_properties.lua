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

-- This is the alternative of OSARA FX parameters, but more flexible. I wrote this layout because the proposed by OSARA is not satisfied me by a few reasons.


-- get current navigation context
local context = reaper.GetCursorContext()

-- API simplification to make calls as contextual
-- capi stands for "contextual API"
local capi = setmetatable({
_contextObj = {
-- REAPER generates error when media item is nil so we have to wrap these handles to function
[0]=function() return reaper.GetLastTouchedTrack() end,
[1]=function()
if reaper.GetSelectedMediaItem(0, 0) then
return reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, 0))
end
return nil
end
},
_contextPrefix = {
[0]="TrackFX_",
[1]="TakeFX_"
}
}, {
__index = function(self, key)
return function(...)
if reaper.APIExists(self._contextPrefix[context]..key) then
return reaper[self._contextPrefix[context]..key](self._contextObj[context](), ...)
else
if context == 0 and key:find("Envelope") then
 if reaper[key] then
 return reaper[key](self._contextObj[context](), ...)
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

-- Find the appropriated context prompt for newly created layout
local contextPrompt = nil
if context == 0 then
if reaper.GetLastTouchedTrack() == reaper.GetMasterTrack() then
contextPrompt = "Master track"
else
contextPrompt = "Track"
end
elseif context == 1 then
contextPrompt = "Take"
end

local fxLayout = initLayout(string.format("%s FX properties", contextPrompt))

function fxLayout.canProvide()
if context == 0 or context == 1 then
return (capi.GetCount() > 0)
end
return false
end


-- Creating the sublayouts with plug-ins and properties with parameters
local fxCount = capi.GetCount()
for i = 0, fxCount-1 do
local retval, fxName = capi.GetFXName( i, "")
if retval then
-- Ah this beautifull prefixes and postfixes
fxName = fxName:match("^.+[:]%s(.+)%s?[(]?")
local sid = capi.GetFXGUID(i):gsub("%W", "")
fxLayout:registerSublayout(sid, fxName)
local fxParmsCount = capi.GetNumParams(i)
for k = 0, fxParmsCount-1 do
fxLayout[sid]:registerProperty({
sm_labels = {
"Switch to adjusting mode",
"Set minimal parameter value",
"Set maximal parameter value",
"Type raw parameter data",
"Search for parameter value",
"Create envelope with this parameter"
},
fxIndex=i,
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
message(self.sm_labels[mode])
elseif mode == 0 then
message:initType("Adjust this property to set necessary value for this parameter. Toggle this property to switch the setting mode for this property.", "Adjustable, toggleable")
message(string.format("Parameter %u ", self.parmIndex+1))
message(({capi.GetParamName(self.fxIndex, self.parmIndex, "")})[2].." ")
local retval, state = capi.GetFormattedParamValue(self.fxIndex, self.parmIndex, "")
if retval then
message(state)
else
local retval = capi.GetParamNormalized(self.fxIndex, self.parmIndex)
message(tostring(utils.round(retval, 5)))
end
end
return message
end,
set = function(self, action)
local message = initOutputMessage()
local mode = extstate._layout.fxParmMode or 0
if mode == 0 then
local ajustingValue = config.getinteger("fxParmStep", 0.00001)
local state, minState, maxState = capi.GetParam(self.fxIndex, self.parmIndex)
local retvalStep, defStep, _, _, isToggle = capi.GetParameterStepSizes(self.fxIndex, self.parmIndex)
if action == actions.set.increase then
if not isToggle then
local retval, fxValue = capi.GetFormattedParamValue(self.fxIndex, self.parmIndex, "")
if retval then
while state < maxState do
state = state+ajustingValue
capi.SetParam(self.fxIndex, self.parmIndex, state)
local wretval, wfxValue = capi.GetFormattedParamValue(self.fxIndex, self.parmIndex)
if wretval then
if fxValue ~= wfxValue then
capi.EndParamEdit(self.fxIndex, self.parmIndex)
break
end
else
break
end
end
if state+ajustingValue > maxState then
message("No more next parameter values.")
end
else
if state+ajustingValue <= maxState then
capi.SetParam(self.fxIndex, self.parmIndex, state+ajustingValue)
capi.EndParamEdit(self.fxIndex, self.parmIndex)
else
message("No more next parameter values.")
end
end
else
if state ~= maxState then
capi.SetParam(self.fxIndex, self.parmIndex, maxState)
capi.EndParamEdit(self.fxIndex, self.parmIndex)
else
message("No more next parameter values.")
end
end
elseif action == actions.set.decrease then
if not isToggle then
local retval, fxValue = capi.GetFormattedParamValue(self.fxIndex, self.parmIndex, "")
if retval then
while state > minState do
state = state-ajustingValue
capi.SetParam(self.fxIndex, self.parmIndex, state)
local wretval, wfxValue = capi.GetFormattedParamValue(self.fxIndex, self.parmIndex)
if wretval then
if fxValue ~= wfxValue then
capi.EndParamEdit(self.fxIndex, self.parmIndex)
break
end
else
break
end
end
if state-ajustingValue < minState then
message("No more previous parameter values.")
end
else
if state-ajustingValue <= minState then
capi.SetParam(self.fxIndex, self.parmIndex, state-ajustingValue)
capi.EndParamEdit(self.fxIndex, self.parmIndex)
else
message("No more previous parameter values.")
end
end
else
if state ~= minState then
capi.SetParam(self.fxIndex, self.parmIndex, minState)
capi.EndParamEdit(self.fxIndex, self.parmIndex)
else
message("No more previous parameter values.")
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
if (mode+1) <= #self.sm_labels then
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
if mode == 1 then
message("Adjusting mode. ")
extstate._layout.fxParmMode = 0
message(self:get())
return message
elseif mode == 2 then
local state, minState, maxState = capi.GetParam(self.fxIndex, self.parmIndex)
capi.SetParam(self.fxIndex, self.parmIndex, minState)
capi.EndParamEdit(self.fxIndex, self.parmIndex)
local retval, curValue = capi.GetFormattedParamValue(self.fxIndex, self.parmIndex, "")
message(string.format("%s is set", curValue))
elseif mode == 3 then
local state, minState, maxState = capi.GetParam(self.fxIndex, self.parmIndex)
capi.SetParam(self.fxIndex, self.parmIndex, maxState)
capi.EndParamEdit(self.fxIndex, self.parmIndex)
local retval, curValue = capi.GetFormattedParamValue(self.fxIndex, self.parmIndex, "")
message(string.format("%s is set", curValue))
elseif mode == 4 then
local state = capi.GetParamNormalized(self.fxIndex, self.parmIndex)
local retval, answer = reaper.GetUserInputs("Set parameter value", 1, "Type raw parameter value:", tostring(utils.round(state, 5)))
if retval then
capi.SetParam(self.fxIndex, self.parmIndex, tonumber(answer))
capi.EndParamEdit(self.fxIndex, self.parmIndex)
end
elseif mode == 5 then
local retval, curValue = capi.GetFormattedParamValue(self.fxIndex, self.parmIndex, "")
if retval then
local retval, answer = reaper.GetUserInputs("Search parameter value", 1, "Type either a part of value string or full string:", curValue)
if retval then
if not extstate._layout._forever.searchProcessNotify then
reaper.ShowMessageBox("REAPER has no any method to get quick list of all values in FX parameters, so search method works using simple brute force with smallest step of all values in VST scale range on selected parameter. It means that search process may be take long time of. While the search process is active, you will think that REAPER is overloaded, got a freeze and your system may report that REAPER no responses. That's not true. The search process works in main stream, therefore it might be seem like that. Please wait for search process been finished. If no one value found, Properties Ribbon will restore the value was been set earlier, so you will not lost the your unique value.", "Note before searching process starts", 0)
extstate._layout._forever.searchProcessNotify = true
end
local state, minState, maxState = capi.GetParam(self.fxIndex, self.parmIndex)
local retvalStep, defStep, _, _, isToggle = capi.GetParameterStepSizes(self.fxIndex, self.parmIndex)
local searchState = minState
while searchState < maxState do
searchState = searchState+0.000001
capi.SetParam(self.fxIndex, self.parmIndex, searchState)
local wretval, wfxValue = capi.GetFormattedParamValue(self.fxIndex, self.parmIndex)
if wretval then
if searcher.simpleSearch(wfxValue, answer) then
state = searchState
capi.EndParamEdit(self.fxIndex, self.parmIndex)
break
end
else
reaper.ShowMessageBox("The parameter values suddenly have lost any string representation.", "Search error", 0)
break
end
end
if searchState ~= state then
reaper.ShowMessageBox(string.format("No any parameter value with %s query.", answer), "No results", 0)
capi.SetParam(self.fxIndex, self.parmIndex, state)
capi.EndParamEdit(self.fxIndex, self.parmIndex)
return
end
end
else
return "This setting is currently cannot be performed because here's no string  value."
end
elseif mode == 6 then
if capi.GetFXEnvelope(self.fxIndex, self.parmIndex, true) then
local fxParmName = ({capi.GetParamName(self.fxIndex, self.parmIndex, "")})[2]
local obj = capi._contextObj[context]()
local name = nil
if context == 0 then
local retval, buf = reaper.GetTrackName(obj)
if retval then
name = buf
end
elseif context == 1 then
local retval, buf = reaper.GetSetMediaItemTakeInfo_String(obj, "P_NAME", "", false)
if retval then
name = buf
end
end
setUndoLabel(self:get(true))
return string.format("The envelope for %s created on %s %s.", fxParmName, contextPrompt:lower(), name)
end
end
end
message(self:get(true))
return message
end
end
})
end
-- Since the sublayouts and its properties are dynamical at this case, we have to make a little hack with to avoid the call of not existing properties and sublayouts.
setmetatable(fxLayout[sid].properties, {
__index = function(self, key)
fxLayout.pIndex = #fxLayout[sid].properties
return fxLayout[sid].properties[#fxLayout[sid].properties]
end
})
end
end

if fxLayout.canProvide() then
if fxLayout[currentSublayout] == nil then
currentSublayout = findDefaultSublayout(fxLayout)
end
end

return fxLayout