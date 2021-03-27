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

-- It's just another vision of Properties Ribbon can be applied on

-- Reading the sublayout
local sublayout = extstate[currentLayout.."_sublayout"]
local mrretval, numMarkers, numRegions = reaper.CountProjectMarkers(0)
if mrretval then
if sublayout == nil then
if numMarkers > 0 then
sublayout = "markersLayout"
elseif numRegions > 0 then
sublayout = "regionsLayout"
end
end
end


local parentLayout = initLayout("Time%s selection")

function parentLayout.canProvide()
return (mrretval > 0)
end

if numMarkers > 0 then
parentLayout:registerSublayout("markersLayout", "Markers ")
for i = 0, numMarkers-1 do
local  retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
if retval and not isrgn then
parentLayout.markersLayout:registerProperty({
position = pos,
str = name,
clr = color,
mIndex = markrgnindexnumber,
get = function(self)
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Perform this property to go to the marker position on the time ruller.", "Performable")
message(string.format("Marker %u", self.mIndex))
if self.clr > 0 then
message(string.format(", color %s", colors:getName(reaper.ColorFromNative(self.clr))))
end
if self.str ~= "" then
message(string.format(", %s", self.str))
else
message("unnamed")
end
return message
end,
set = function(self, action)
if action ~= nil then
return "This property is performable only."
end
local message = initOutputMessage()
reaper.SetEditCurPos(self.position, true, true)
message("Moving to")
message(self:get())
return message
end
})
end
end
-- Hack our sublayout a little
setmetatable(parentLayout.markersLayout.properties, {
__index = function(self, key)
if self.pIndex > numMarkers then
self.pIndex = numMarkers
end
return nil
end
})
end


-- Regions loading
if numRegions > 0 then
parentLayout:registerSublayout("regionsLayout", "Regions ")
for i = 0, numRegions-1 do
local  retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
if retval and isrgn then
parentLayout.regionsLayout:registerProperty({
position = pos,
str = name,
clr = color,
rIndex = markrgnindexnumber,
get = function(self)
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Perform this property to go to the specified region start position on the time ruller.", "Performable")
message(string.format("Region %u", self.rIndex))
if self.clr > 0 then
message(string.format(", color %s", colors:getName(reaper.ColorFromNative(self.clr))))
end
if self.str ~= "" then
message(string.format(", %s", self.str))
else
message("unnamed")
end
return message
end,
set = function(self, action)
if action ~= nil then
return "This property is performable only."
end
local message = initOutputMessage()
reaper.SetEditCurPos(self.position, true, true)
message("Moving to")
message(self:get())
return message
end
})
end
end
-- Hack our sublayout a little
setmetatable(parentLayout.regionsLayout.properties, {
__index = function(self, key)
if self.pIndex > numMarkers then
self.pIndex = numMarkers
end
return nil
end
})
end

return parentLayout[sublayout]