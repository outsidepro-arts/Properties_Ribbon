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
reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, 0))
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
if reaper[self._contextPrefix[context]..key] then
return function(...)
if reaper[self._contextPrefix[context]..key] then
 return reaper[self._contextPrefix[context]..key](self._contextObj[context](), ...)
 else
 error(string.format("Contextual API wasn't found method %s", self._contextPrefix[context]..key))
 end
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

local fxLayout = initLayout(string.format("%s FX properties", ({[0]="Track",[1]="Take"})[context]))

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
fxIndex=i,
parmIndex = tonumber(k),
get = function(self)
local message = initOutputMessage()
message:initType("Adjust this property to set necessary value for this parameter.", "Adjustable")
message(string.format("Parameter %u ", self.parmIndex+1))
message(({capi.GetParamName(self.fxIndex, self.parmIndex, "")})[2].." ")
local retval, state = capi.GetFormattedParamValue(self.fxIndex, self.parmIndex, "")
if retval then
message(string.format(" value %s", state))
else
local retval = capi.GetParamNormalized(self.fxIndex, self.parmIndex)
message(string.format(" value %d", utils.round(retval, 5)))
end
return message
end,
set = function(self, action)
local message = initOutputMessage()
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
capi.SetParam(self,fxIndex, self.parmIndex, state+ajustingValue)
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
capi.SetParam(self,fxIndex, self.parmIndex, state-ajustingValue)
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
else
return "This property is adjustable only."
end
message(self:get())
return message
end
})
end
end
end

return fxLayout