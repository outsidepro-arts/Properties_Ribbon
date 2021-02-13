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

-- Reading the sublayout
local sublayout = extstate[currentLayout.."_sublayout"] or "itemLayout"

-- Reading the some config which will be used everyhere
local multiSelectionSupport = config.getboolean("multiSelectionSupport", true)
local maxDBValue = config.getinteger("maxDBValue", 12.0)

-- For comfort coding, we are making the items array as global

local items = nil
do
if multiSelectionSupport == true then
local countSelectedItems = reaper.CountSelectedMediaItems(0)
if countSelectedItems > 1 then
items = {}
for i = 0, countSelectedItems-1 do
table.insert(items, reaper.GetSelectedMediaItem(0, i))
end
else
items = reaper.GetSelectedMediaItem(0, 0)
end
else
items = reaper.GetSelectedMediaItem(0, 0)
end
end

-- I've just tired to write this long call so
local function getItemNumber(item)
return reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")+1
end

-- And another one:
local function getTakeNumber(item)
return  reaper.GetMediaItemInfo_Value(item, "I_CURTAKE")+1
end

-- Reading the color from color composer specified section
local function getItemComposedColor()
return extstate.colcom_item_curValue
end

local function getTakeComposedColor()
return extstate.colcom_take_curValue
end

-- The macros for compose when group of items selected
local function composeMultipleItemMessage(func, states, inaccuracy)
inaccuracy = inaccuracy or 0
local message = initOutputMessage()
for k = 1, #items do
local state = func(items[k])
local prevState if items[k-1] then prevState = func(items[k-1]) end
local nextState if items[k+1] then nextState = func(items[k+1]) end
if state ~= prevState and state == nextState then
message(string.format("items from %u ", getItemNumber(items[k])))
elseif state == prevState and state ~= nextState then
message(string.format("to %u ", getItemNumber(items[k])))
if inaccuracy and type(state) == "number" then
message(string.format("%s", states[state+inaccuracy]))
else
message(string.format("%s", states[state]))
end
if k < #items then
message(", ")
end
elseif state == prevState and state == nextState then
else
message(string.format("item %u ", getItemNumber(items[k])))
if inaccuracy and type(state) == "number" then
message(string.format("%s", states[state+inaccuracy]))
else
message(string.format("%s", states[state]))
end
if k < #items then
message(", ")
end
end
end
return message
end

local function composeMultipleTakeMessage(func, states, inaccuracy)
local message = initOutputMessage()
for k = 1, #items do
local state, takeIDX = func(items[k]), getTakeNumber(items[k])
local prevState, prevTakeIDX if items[k-1] then prevState, prevTakeIDX = func(items[k-1]), getTakeNumber(items[k-1]) end
local nextState, nextTakeIDX if items[k+1] then nextState, nextTakeIDX = func(items[k+1]), getTakeNumber(items[k+1]) end
if (state ~= prevState and state == nextState) and (takeIDX ~= prevTakeIDX and takeIDX == nextTakeIDX) then
message(string.format("take %u of items from %u ", getTakeNumber(items[k]), getItemNumber(items[k])))
elseif (state == prevState and state ~= nextState) and (takeIDX == prevTakeIDX and takeIDX ~= nextTakeIDX) then
message(string.format("to %u ", getItemNumber(items[k])))
if inaccuracy and type(state) == "number" then
message(string.format("%s", states[state+inaccuracy]))
else
message(string.format("%s", states[state]))
end
if k < #items then
message(", ")
end
elseif (state == prevState and state == nextState) and (takeIDX == prevTakeIDX and takeIDX == nextTakeIDX) then
else
message(string.format("take %u of item %u ", getTakeNumber(items[k]), getItemNumber(items[k])))
if inaccuracy and type(state) == "number" then
message(string.format("%s", states[state+inaccuracy]))
else
message(string.format("%s", states[state]))
end
if k < #items then
message(", ")
end
end
end
return message
end


-- global pseudoclass initialization
local parentLayout = initLayout("Item%s properties")

-- the function which gives green light to call any method from this class
function parentLayout.canProvide()
if reaper.CountSelectedMediaItems(0) > 0 then
return true
else
return false
end
end

-- sublayouts
--visual properties
parentLayout:registerSublayout("visualLayout", " visual")

--Item properties
-- The second parameter is empty string cuz the parent layout's name and this sublayout's name is identical
parentLayout:registerSublayout("itemLayout", "")

-- Current take properties
parentLayout:registerSublayout("takeLayout", " current take")


--[[
Before the properties list fill get started, let describe this subclass methods:
Method get: gets no one parameter, returns a message string which will be reported in the navigating scripts.
Method set: gets parameter action. Expects false, true or nil.
action == true: the property must changed upward
action == false: the property must changed downward
action == nil: The property must be toggled or performed default action
Returns a outputMessage custom metamethod which will be reported in the navigating scripts.

After you finish the methods table you have to return parent class.
No any recomendation more.
Although, no, just one thing:
Try to allow the user to perform actions on both one element and a selected group..
and try to complement any getState message with short type label. I mean what the "ajust" method will perform.
]]--

-- Take name methods
local currentTakeNameProperty = {}
parentLayout.visualLayout:registerProperty(currentTakeNameProperty)

function currentTakeNameProperty.getValue(item)
return ({reaper.GetSetMediaItemTakeInfo_String(reaper.GetActiveTake(item), "P_NAME", "", false)})[2]
end

function currentTakeNameProperty.setValue(item, value)
reaper.GetSetMediaItemTakeInfo_String(reaper.GetActiveTake(item), "P_NAME", value, true)
end

function currentTakeNameProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Perform this action to rename selected item current take.", "performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, new name will applied to selected active takes of selected items.", 1)
end
if type(items) == "table" then
message("Takes names: ")
for k = 1, #items do
local name = self.getValue(items[k])
message(string.format("Take of item %u ", getItemNumber(items[k])))
if name and name ~= "" then
message(string.format("named as %s", name))
else
message("unnamed")
end
if k < #items then
message(", ")
end
end
else
local name = self.getValue(items)
if name and name ~= "" then
message(string.format("Item %u current take name %s", getItemNumber(items), name))
else
message(string.format("Item %u current take unnamed", getItemNumber(items)))
end
end
return message
end

function currentTakeNameProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is performable only."
end
if type(items) == "table" then
local state, answer = reaper.GetUserInputs("Change name active takes of selected items", 1, 'Type new take name:', "")
if state == true then
for k = 1, #items do
self.setValue(items[k], answer.." "..k)
end
message(string.format("The name %s has been set for %u items.", answer, #items))
end
else
local name = self.getValue(items)
local aState, answer = reaper.GetUserInputs(string.format("Change active take name for item %u", getItemNumber(items)), 1, 'Type new item name:', name)
if aState == true then
self.setValue(items, answer)
end
end
return message
end

-- Lock item methods
local lockProperty = {}
 parentLayout.itemLayout:registerProperty( lockProperty)
lockProperty.states = {[0]="Unlocked", [1]="locked"}

function lockProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "C_LOCK")
end

function lockProperty.setValue(item, value)
reaper.SetMediaItemInfo_Value(item, "C_LOCK", value)
end

function lockProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to lock or unlock selected item for any changes.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the lock state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items locking: ")
message(composeMultipleItemMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("item %u %s", getItemNumber(items), self.states[state]))
end
return message
end

function lockProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(items) == "table" then
local lockedItems, notLockedItems = 0, 0
for k = 1, #items do
local state = self.getValue(items[k])
if state == 1 then
lockedItems = lockedItems+1
else
notLockedItems = notLockedItems+1
end
end
local ajustingValue
if lockedItems > notLockedItems then
ajustingValue = 0
message("Locking selected items.")
elseif lockedItems < notLockedItems then
ajustingValue = 1
message("Unlocking selected  items.")
else
ajustingValue = 0
message("Locking selected selected items.")
end
for k = 1, #items do
self.setValue(items[k], ajustingValue)
end
else
self.setValue(items, nor(self.getValue(items)))
end
message(self:get())
return message
end

-- volume methods
local itemVolumeProperty = {}
parentLayout.itemLayout:registerProperty(itemVolumeProperty)

function itemVolumeProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "D_VOL")
end

function  itemVolumeProperty.setValue(item, value)
reaper.SetMediaItemInfo_Value(item, "D_VOL", value)
end

function itemVolumeProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired volume value for selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" Perform this property to reset the volume to zero DB.", 1)
if type(items) == "table" then
message("items volume:")
message(composeMultipleItemMessage(self.getValue, setmetatable({}, {__index = function(self, key) return string.format("%s dB", numtodecibels(key)) end})))
else
local state = self.getValue(items)
message(string.format("Item %u volume %s db", getItemNumber(items), numtodecibels(state)))
end
return message
end

function itemVolumeProperty:set(action)
local message = initOutputMessage()
if action == nil then
message("reset,")
end
local ajustStep = config.getinteger("dbStep", 0.1)
if type(items) == "table" then
for k = 1, #items do
local state = self.getValue(items[k])
if action == true then
if state < decibelstonum(12.0) then
self.setValue(items[k], decibelstonum(numtodecibels(state)+ajustStep))
else
self.setValue(items[k], decibelstonum(maxDBValue))
end
elseif action == false then
if numtodecibels(state) ~= "-inf" then
self.setValue(items[k], decibelstonum(numtodecibels(state, true)-ajustStep))
else
self.setValue(items[k], 0)
end
else
self.setValue(items[k], 1)
end
end
message(self:get())
else
local state = self.getValue(items)
if action == true then
if state < decibelstonum(12.0) then
self.setValue(items, decibelstonum(numtodecibels(state, true)+ajustStep))
else
self.setValue(items, decibelstonum(12.0))
message("maximum volume.")
end
elseif action == false then
if numtodecibels(state) ~= "-inf" then
self.setValue(items, decibelstonum(numtodecibels(state, true)-ajustStep))
else
self.setValue(items, 0)
message("Minimum volume.")
end
else
self.setValue(items, 1)
end
--message(string.format("Item %u volume %s db", getItemNumber(items), numtodecibels(self.getValue(items))))
message(self:get())
end
return message
end

-- mute methods
local muteItemProperty = {}
 parentLayout.itemLayout:registerProperty( muteItemProperty)
muteItemProperty.states = {[0]="not muted", [1]="muted"}

function muteItemProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to mute or unmute selected item.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the mute state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items mute:")
message(composeMultipleItemMessage(function(item) return reaper.GetMediaItemInfo_Value(item, "B_MUTE") end, self.states))
else
local state = reaper.GetMediaItemInfo_Value(items, "B_MUTE")
message(string.format("item %u %s", getItemNumber(items), self.states[state]))
end
return message
end

function muteItemProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(items) == "table" then
local mutedItems, notMutedItems = 0, 0
for k = 1, #items do
local state = reaper.GetMediaItemInfo_Value(items[k], "B_MUTE")
if state == 1 then
mutedItems = mutedItems+1
else
notMutedItems = notMutedItems+1
end
end
local ajustingValue
if mutedItems > notMutedItems then
ajustingValue = 0
message("Unmuting selected items.")
elseif mutedItems < notMutedItems then
ajustingValue = 1
message("Muting selected items.")
else
ajustingValue = 0
message("Unmuting selected items.")
end
for k = 1, #items do
reaper.SetMediaItemInfo_Value(items[k], "B_MUTE", ajustingValue)
end
else
local state = nor(reaper.GetMediaItemInfo_Value(items, "B_MUTE"))
reaper.SetMediaItemInfo_Value(items, "B_MUTE", state)
state = reaper.GetMediaItemInfo_Value(items, "B_MUTE")
end
message(self:get())
return message
end

-- Loop source methods
local loopSourceProperty = {}
 parentLayout.itemLayout:registerProperty( loopSourceProperty)
loopSourceProperty.states = {[0]="not looped", [1]="looped"}

function loopSourceProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to loop or unloop the source of selected item.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the loop source state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items source loop: ")
message(composeMultipleItemMessage(function(item) return reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC") end, self.states))
else
local state = reaper.GetMediaItemInfo_Value(items, "B_LOOPSRC")
message(string.format("item %u source %s", getItemNumber(items), self.states[state]))
end
return message
end

function loopSourceProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(items) == "table" then
local loopedItems, notLoopedItems = 0, 0
for k = 1, #items do
local state = reaper.GetMediaItemInfo_Value(items[k], "B_LOOPSRC")
if state == 1 then
loopedItems = loopedItems+1
else
notLoopedItems = notLoopedItems+1
end
end
local ajustingValue
if loopedItems > notLoopedItems then
ajustingValue = 0
message("Set selected items sources loop off.")
elseif loopedItems < notLoopedItems then
ajustingValue = 1
message("Looping selected items sources.")
else
ajustingValue = 0
message("Set selected items sourcess loop off.")
end
for k = 1, #items do
reaper.SetMediaItemInfo_Value(items[k], "B_LOOPSRC", ajustingValue)
end
else
local state = nor(reaper.GetMediaItemInfo_Value(items, "B_LOOPSRC"))
reaper.SetMediaItemInfo_Value(items, "B_LOOPSRC", state)
end
message(self:get())
return message
end

-- All takes play methods
local itemAllTakesPlayProperty = {}
 parentLayout.itemLayout:registerProperty( itemAllTakesPlayProperty)
itemAllTakesPlayProperty.states = {[0]="aren't playing", [1]="are playing"}

function itemAllTakesPlayProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to define the playing all takes of selected item.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the playing all takes state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items all takes playing: ")
message(composeMultipleItemMessage(function(item) return reaper.GetMediaItemInfo_Value(item, "B_ALLTAKESPLAY") end, self.states))
else
local state = reaper.GetMediaItemInfo_Value(items, "B_ALLTAKESPLAY")
message(string.format("item %u all takes %s", getItemNumber(items), self.states[state]))
end
return message
end

function itemAllTakesPlayProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(items) == "table" then
local tkPlayItems, tkNotPlayItems = 0, 0
for k = 1, #items do
local state = reaper.GetMediaItemInfo_Value(items[k], "B_ALLTAKESPLAY")
if state == 1 then
tkPlayItems = tkPlayItems+1
else
tkNotPlayItems = tkNotPlayItems+1
end
end
local ajustingValue
if tkPlayItems > tkNotPlayItems then
ajustingValue = 0
message("Sett all Takes of selected items play off.")
elseif tkPlayItems < tkNotPlayItems then
ajustingValue = 1
message("Set all takes of selected items play on.")
else
ajustingValue = 0
message("Sett all Takes of selected items play off.")
end
for k = 1, #items do
reaper.SetMediaItemInfo_Value(items[k], "B_ALLTAKESPLAY", ajustingValue)
end
else
local state = nor(reaper.GetMediaItemInfo_Value(items, "B_ALLTAKESPLAY"))
reaper.SetMediaItemInfo_Value(items, "B_ALLTAKESPLAY", state)
end
message(self:get())
return message
end



-- timebase methods
local timebaseProperty = {}
 parentLayout.itemLayout:registerProperty(timebaseProperty)
timebaseProperty.states = {
[0] = "track or project default",
[2] = "beats (position, length, rate)",
[3] = "beats (position only)"
}

function timebaseProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose the desired time base mode for selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if these items have the same value. Otherwise, the timebase state will be set to "%s", then will enumerate this.', self.states[0]), 1)
end
if type(items) == "table" then
message("Items timebase: ")
message(composeMultipleItemMessage(function(item) return reaper.GetMediaItemInfo_Value(item, "C_BEATATTACHMODE") end, self.states, 1))
else
local state = reaper.GetMediaItemInfo_Value(items, "C_BEATATTACHMODE")
message(string.format("Item %u timebase %s", getItemNumber(items), self.states[state+1]))
end
return message
end

function timebaseProperty:set(action)
local message = initOutputMessage()
local ajustingValue
if action == true then
ajustingValue = 1
elseif action == false then
ajustingValue = -1
else
ajustingValue = -1
end
if type(items) == "table" then
if action then
local st = {0, 0, 0, 0}
for k = 1, #items do
local state = reaper.GetMediaItemInfo_Value(items[k], "C_BEATATTACHMODE")
st[state+2] = st[state+2]+1
end
local state
if math.max(st[1], st[2], st[3], st[4]) == #items then
state = reaper.GetMediaItemInfo_Value(items[1], "C_BEATATTACHMODE")
if self.states[(state+ajustingValue)+1] and state ~= 0 then
state = state+ajustingValue
elseif state== 0 then
state = state+ajustingValue
state = state+ajustingValue
end
else
state = 0
end
message(string.format("Set selected items timebase to %s.", self.states[state+1]))
for k = 1, #items do
reaper.SetMediaItemInfo_Value(items[k], "C_BEATATTACHMODE", state)
end
else
message(string.format("Set selected items timebase to %s.", self.states[0]))
for k = 1, #items do
reaper.SetMediaItemInfo_Value(items[k], "C_BEATATTACHMODE", -1)
end
end
else
local state = reaper.GetMediaItemInfo_Value(items, "C_BEATATTACHMODE")
if action == true or action == false then
if state+ajustingValue == 0 then
state = state+ajustingValue
state = state+ajustingValue
-- LUA doesn't defines the non-ordered arrays, so the method like in Tracks willn't works
elseif state+ajustingValue > 2 then
message("No more next property values. ")
elseif state+ajustingValue < -1 then
message("No more previous property values. ")
else
state = state+ajustingValue
end
else
state = -1
end
reaper.SetMediaItemInfo_Value(items, "C_BEATATTACHMODE", state)
end
message(self:get())
return message
end

-- Auto-stretch methods
local autoStretchProperty = {}
 parentLayout.itemLayout:registerProperty( autoStretchProperty)
autoStretchProperty.states = {[0]="disabled", [1]="enabled"}

function autoStretchProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), string.format('Toggle this property to enable or disable auto-stretch selected item at project tempo when the item timebase is set to "%s".', timebaseProperty.states[2]), "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the auto-stretch state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items Auto-stretch at project tempo: ")
message(composeMultipleItemMessage(function(item) return reaper.GetMediaItemInfo_Value(item, "C_AUTOSTRETCH") end, self.states))
else
local state = reaper.GetMediaItemInfo_Value(items, "C_AUTOSTRETCH")
message(string.format("item %u auto-stretch at project tempo %s", getItemNumber(items), self.states[state]))
end
return message
end

function autoStretchProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(items) == "table" then
local stretchedItems, notStretchedItems = 0, 0
for k = 1, #items do
local state = reaper.GetMediaItemInfo_Value(items[k], "C_AUTOSTRETCH")
if state == 1 then
stretchedItems = stretchedItems+1
else
notStretchedItems = notStretchedItems+1
end
end
local ajustingValue
if stretchedItems > notStretchedItems then
ajustingValue = 0
message("Switching off the auto-stretch mode for selected items.")
elseif stretchedItems < notStretchedItems then
ajustingValue = 1
message("Switching on the auto-stretch mode for  selected items.")
else
ajustingValue = 0
message("Switching off the auto-stretch mode for  selected items.")
end
for k = 1, #items do
reaper.SetMediaItemInfo_Value(items[k], "C_AUTOSTRETCH", ajustingValue)
end
else
local state = nor(reaper.GetMediaItemInfo_Value(items, "C_AUTOSTRETCH"))
reaper.SetMediaItemInfo_Value(items, "C_AUTOSTRETCH", state)
end
message(self:get())
return message
end

-- Snap offset methods
local itemSnapOffsetProperty  = {}
parentLayout.itemLayout:registerProperty(itemSnapOffsetProperty)

function itemSnapOffsetProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
end

function itemSnapOffsetProperty.setValue(item, value)
reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", value)
end


function itemSnapOffsetProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel"), "Adjust this property to set the desired snap offset time.", "Adjustable, performable")
if multiSelectionSupport == ttrue then
message:addType(" If the group of items has selected, the relative depending on previous value will be set for each selected item.", 1)
end
message:addType(" Perform this property to remove snap offset time.", 1)
if type(items) == "table" then
message("Items snap offset:")
message(composeMultipleItemMessage(self.getValue, setmetatable({}, {__index = function(self, state) return string.format("%s ms", round(state, 3)) end})))
else
local state = self.getValue(items)
message(string.format("Item %u snap offset %s ms", getItemNumber(items), round(state, 3)))
end
return message
end

function itemSnapOffsetProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("timeStep", 0.001)
if action == false then
ajustingValue = -ajustingValue
elseif action == nil then
message("Remove the snap offset.")
end
if type(items) == "table" then
for k = 1, #items do
local state = self.getValue(items[k])
if action == true or action == false then
if (state+ajustingValue) >= 0 then
state = state+ajustingValue
else
state = 0.000
end
else
state = 0.000
end
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if action == true or action == false then
if (state+ajustingValue) >= 0.000 then
state = state+ajustingValue
else
state = 0.000
message("Minimum snap offset time. ")
end
else
state = 0.000
end
self.setValue(items, state)
end
message(self:get())
return message
end


-- Item group methods
-- For now, this property has been registered in visual layout section. Really, it influences on all items in the same group: all controls will be grouped and when an user changes any control slider, all other items changes the value too.
-- Are you Sure? But i'm not. 🤣
local groupingProperty = {}
parentLayout.visualLayout:registerProperty(groupingProperty)
groupingProperty.states = setmetatable({
[0] = "not in a group"
}, {
__index = function(self, key)
return ("in group %u"):format(tostring(key))
end
})

function groupingProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
end

function groupingProperty.setValue(item, value)
reaper.SetMediaItemInfo_Value(item, "I_GROUPID", value)
end

function groupingProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set up the desired group number for selected item.", "Adjustable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the group will be set to 1 first, then will begins enumerate up of.", 1)
end
if type(items) == "table" then
message("Items group numbers: ")
message(composeMultipleItemMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(("Item %u %s"):format(getItemNumber(items), self.states[state]))
end
return message
end

function groupingProperty:set(action)
local message = initOutputMessage()
local ajustingValue
if action == true then
ajustingValue = 1
elseif action == false then
ajustingValue = -1
else
return "This property adjustable only."
end
if type(items) == "table" then
local state = self.getValue(items[1])
if state+ajustingValue > 0 then
state = state+ajustingValue
ajustingValue = 0
message(("Set selected  items to group %u."):format(state))
elseif state+ajustingValue == 0 then
state = 0
ajustingValue = 0
message("Removing  selected items from any group.")
else
message("No more groups in this direction.")
end
if ajustingValue == 0 then
for k = 1, #items do
self.setValue(items[k], state)
end
end
else
local state = self.getValue(items)
if state+ajustingValue > 0 then
self.setValue(items, state+ajustingValue)
message(("Item %u  set to group %u"):format(getItemNumber(items), self.getValue(items)))
elseif state+ajustingValue == 0 then
self.setValue(items, 0)
message(("Item %u not in a group"):format(getItemNumber(items)))
elseif state+ajustingValue < 0 then
message("No more group in this direction")
end
end
return message
end

-- Fade methods
-- Fadein shape
local fadeinShapeProperty = {}
 parentLayout.itemLayout:registerProperty(fadeinShapeProperty)
fadeinShapeProperty.states = setmetatable({
[0] = "Linear",
[1] = "Inverted quadratic",
[2] = "Quadratic",
[3] = "Inverted quartic",
[4] = "Quartic",
[5] = "Cosine S-curve",
[	6] = "Quartic S-curve",
[7] = "Equal power"
}, {
__index = function(self, key)
return string.format("Unknown fade type %s. Please create an issue with this fade type on the properties Ribbon github repository.", tostring(key))
end
})

function fadeinShapeProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "C_FADEINSHAPE")
end

function fadeinShapeProperty.setValue(item, value)
reaper.SetMediaItemInfo_Value(item, "C_FADEINSHAPE", value)
end

function fadeinShapeProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose the desired shape mode for fadein in selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if these items have the same value. Otherwise, the shape state will be set to "%s", then will enumerate this.', self.states[0]), 1)
end
if type(items) == "table" then
message("Items fadein shape: ")
message(composeMultipleItemMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("Item %u fadein shape %s", getItemNumber(items), self.states[state]))
end
return message
end

function fadeinShapeProperty:set(action)
if action == nil then
return "This property adjustable only."
end
local message = initOutputMessage()
local ajustingValue
if action == true then
ajustingValue = 1
elseif action == false then
ajustingValue = -1
end
if type(items) == "table" then
local st = {0, 0, 0, 0, 0, 0, 0}
for k = 1, #items do
local state = self.getValue(items[k])
st[state+1] = st[state+1]+1
end
local state
if math.max(st[1], st[2], st[3], st[4], st[5], st[6], st[7]) == #items then
state = self.getValue(items[1])
if self.states[(state+ajustingValue)] then
state = state+ajustingValue
end
else
state = 1
end
message(string.format("Set selected items fadein shapes to %s.", self.states[state]))
for k = 1, #items do
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if action == true or action == false then
if state+ajustingValue > 6 then
message("No more next property values. ")
elseif state+ajustingValue < 0 then
message("No more previous property values. ")
else
state = state+ajustingValue
end
end
self.setValue(items, state)
end
message(self:get())
return message
end

-- Fadein manual length methods
local fadeinLenProperty = {}
parentLayout.itemLayout:registerProperty(fadeinLenProperty)

function  fadeinLenProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN")
end

function  fadeinLenProperty.setValue(item, value)
reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", value)
end

function  fadeinLenProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to setup desired fadein length for selected item.", "Adjustable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" Perform this property to reset the length value to default in preferences.", 1)
if type(items) == "table" then
message("Items fadein length: ")
message(composeMultipleItemMessage(self.getValue, setmetatable({}, {__index = function(self, key) return key end})))
else
message(("Item %u fadein length %s ms"):format(getItemNumber(items), round(self.getValue(items), 3)))
end
return message
end

function  fadeinLenProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("timeStep", 0.001)
if action == false then
ajustingValue = -ajustingValue
elseif action == nil then
local result, str = reaper.get_config_var_string("deffadelen")
if result == true then
ajustingValue = round(tonumber(str), 3)
message("Restore default value, ")
else
return "No default fade length value has read in preferences."
end
end
if type(items) == "table" then
for k = 1, #items do
local state = self.getValue(items[k])
if action == true or action == false then
if (state+ajustingValue) >= 0 then
state = state+ajustingValue
else
state = 0.000
end
else
state = ajustingValue
end
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if action == true or action == false then
if (state+ajustingValue) >= 0.000 then
state = state+ajustingValue
else
state = 0.000
message("Minimum length. ")
end
else
state = ajustingValue
end
self.setValue(items, state)
end
message(self:get())
return message
end

-- Fadein curve methods
local fadeinDirProperty = {}
parentLayout.itemLayout:registerProperty( fadeinDirProperty)
fadeinDirProperty.states = setmetatable({
[0] = "flat"
}, {
__index = function(self, key)
if key >0 then
return ("%s%% to the right"):format(numtopercent(key))
elseif key < 0 then
return ("%s%% to the left"):format(-numtopercent(key))
end
end
})

function  fadeinDirProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "D_FADEINDIR")
end

function  fadeinDirProperty.setValue(item,value)
reaper.SetMediaItemInfo_Value(item, "D_FADEINDIR", value)
end

function  fadeinDirProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired fadein curvature for selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" Perform this property to reset the value to 0.00.", 1)
if type(items) == "table" then
message("Items fadein curve: ")
message(composeMultipleItemMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(("Item %u fadein curve %s"):format(getItemNumber(items), self.states[state]))
end
return message
end

function  fadeinDirProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("percentStep", 1)
if action == true then
ajustingValue = percenttonum(ajustingValue)
elseif action == false then
ajustingValue = -percenttonum(ajustingValue)
else
message("reset, ")
ajustingValue = nil
end
if type(items) == "table" then
for k = 1, #items do
local state = self.getValue(items[k])
if ajustingValue then
state = round((state+ajustingValue), 3)
if state >= 1 then
state = 1
elseif state <= -1 then
state = -1
end
else
state = 0
end
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if ajustingValue then
state = round((state+ajustingValue), 3)
if state > 1 then
state = 1
message("Right curve boundary. ")
elseif state < -1 then
state = -1
message("Left curve boundary. ")
end
else
state = 0.00
end
self.setValue(items, state)
end
message(self:get())
return message
end

-- Fadeout shape
local fadeoutShapeProperty = {}
 parentLayout.itemLayout:registerProperty(fadeoutShapeProperty)
fadeoutShapeProperty.states =  fadeinShapeProperty.states

function fadeoutShapeProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "C_FADEOUTSHAPE")
end

function fadeoutShapeProperty.setValue(item, value)
reaper.SetMediaItemInfo_Value(item, "C_FADEOUTSHAPE", value)
end

function fadeoutShapeProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose the desired shape mode for fadeout in selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if these items have the same value. Otherwise, the shape state will be set to "%s", then will enumerate this.', self.states[0]), 1)
end
if type(items) == "table" then
message("Items fadeout shape: ")
message(composeMultipleItemMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("Item %u fadeout shape %s", getItemNumber(items), self.states[state]))
end
return message
end

function fadeoutShapeProperty:set(action)
if action == nil then
return "This property adjustable only."
end
local message = initOutputMessage()
local ajustingValue
if action == true then
ajustingValue = 1
elseif action == false then
ajustingValue = -1
end
if type(items) == "table" then
local st = {0, 0, 0, 0, 0, 0, 0}
for k = 1, #items do
local state = self.getValue(items[k])
st[state+1] = st[state+1]+1
end
local state
if math.max(st[1], st[2], st[3], st[4], st[5], st[6], st[7]) == #items then
state = self.getValue(items[1])
if self.states[(state+ajustingValue)] then
state = state+ajustingValue
end
else
state = 1
end
message(string.format("Set selected items fadeout shapes to %s.", self.states[state]))
for k = 1, #items do
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if action == true or action == false then
if state+ajustingValue > 6 then
message("No more next property values. ")
elseif state+ajustingValue < 0 then
message("No more previous property values. ")
else
state = state+ajustingValue
end
end
self.setValue(items, state)
end
message(self:get())
return message
end

-- fadeout manual length methods
local fadeoutLenProperty = {}
parentLayout.itemLayout:registerProperty(fadeoutLenProperty)

function  fadeoutLenProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
end

function  fadeoutLenProperty.setValue(item, value)
reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", value)
end

function  fadeoutLenProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to setup desired fadeout length for selected item.", "Adjustable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" Perform this property to reset the length value to default in preferences.", 1)
if type(items) == "table" then
message("Items fadeout length: ")
message(composeMultipleItemMessage(self.getValue, setmetatable({}, {__index = function(self, key) return round(key, 3) end})))
else
message(("Item %u fadeout length %s ms"):format(getItemNumber(items), round(self.getValue(items), 3)))
end
return message
end

function  fadeoutLenProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("timeStep", 0.001)
if action == false then
ajustingValue = -ajustingValue
elseif action == nil then
local result, str = reaper.get_config_var_string("deffadelen")
if result == true then
ajustingValue = round(tonumber(str), 3)
message("Restore default value, ")
else
return "No default fade length value has read in preferences."
end
end
if type(items) == "table" then
for k = 1, #items do
local state = self.getValue(items[k])
if action == true or action == false then
if (state+ajustingValue) >= 0 then
state = state+ajustingValue
else
state = 0.000
end
else
state = ajustingValue
end
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if action == true or action == false then
if (state+ajustingValue) >= 0.000 then
state = state+ajustingValue
else
state = 0.000
message("Minimum length. ")
end
else
state = ajustingValue
end
self.setValue(items, state)
 end
message(self:get())
return message
end

-- fadeout curve methods
local fadeoutDirProperty = {}
parentLayout.itemLayout:registerProperty( fadeoutDirProperty)
fadeoutDirProperty.states = fadeinDirProperty.states

function  fadeoutDirProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "D_FADEOUTDIR")
end

function  fadeoutDirProperty.setValue(item,value)
reaper.SetMediaItemInfo_Value(item, "D_FADEOUTDIR", value)
end

function  fadeoutDirProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired fadeout curvature for selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" Perform this property to reset the value to flat.", 1)
if type(items) == "table" then
message("Items fadeout curve: ")
message(composeMultipleItemMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(("Item %u fadeout curve %s"):format(getItemNumber(items), self.states[state]))
end
return message
end

function  fadeoutDirProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("percentStep", 1)
if action == true then
ajustingValue = percenttonum(ajustingValue)
elseif action == false then
ajustingValue = -percenttonum(ajustingValue)
else
message("reset, ")
ajustingValue = nil
end
if type(items) == "table" then
for k = 1, #items do
local state = self.getValue(items[k])
if ajustingValue then
state = round((state+ajustingValue), 3)
if state >= 1 then
state = 1
elseif state <= -1 then
state = -1
end
else
state = 0
end
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if ajustingValue then
state = round((state+ajustingValue), 3)
if state > 1 then
state = 1
message("Right curve boundary. ")
elseif state < -1 then
state = -1
message("Left curve boundary. ")
end
else
state = 0.00
end
self.setValue(items, state)
end
message(self:get())
return message
end

-- Fadein automatic length
local fadeinAutoLenProperty = {}
parentLayout.itemLayout:registerProperty(fadeinAutoLenProperty)

function  fadeinAutoLenProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO")
end

function  fadeinAutoLenProperty.setValue(item, value)
reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", value)
end

function  fadeinAutoLenProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to setup desired automatic fadein length for selected item.", "Adjustable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" If you want to switch off automatic fadein, set the value less than 0.000 MS. Perform this property to reset the length value to default in preferences.", 1)
if type(items) == "table" then
message("Items automatic fadein length: ")
message(composeMultipleItemMessage(self.getValue, setmetatable({}, {__index = function(self, state)
if state >= 0 then
return ("%s ms"):format(tostring(state))
else
return "automatic fadein off"
end
end
})))
else
local state = self.getValue(items)
if state >= 0 then
message(("Item %u automatic fadein length %s ms"):format(getItemNumber(items), round(state, 3)))
else
message(("Item %u automatic fadein off"):format(getItemNumber(items)))
end
end
return message
end

function  fadeinAutoLenProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("timeStep", 0.001)
if action == false then
ajustingValue = -ajustingValue
elseif action == nil then
local result, str = reaper.get_config_var_string("defsplitxfadelen")
if result == true then
ajustingValue = round(tonumber(str), 3)
message("Restore default value, ")
else
return "No default fade length value has read in preferences."
end
end
if type(items) == "table" then
for k = 1, #items do
local state = self.getValue(items[k])
if action == false then
if (state+ajustingValue) >= 0 then
state = state+ajustingValue
elseif (state+ajustingValue) < 0 then
state = -1
elseif state< -1 then
state = -1
message("Minimum length. ")
end
elseif action == true then
if (state+ajustingValue) < 0 then
state = 0.000
else
state = state+ajustingValue
end
else
state = ajustingValue
end
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if action == false then
if (state+ajustingValue) >= 0 then
state = state+ajustingValue
elseif (state+ajustingValue) < 0 then
state = -1
elseif state< -1 then
state = -1
message("Minimum length. ")
end
elseif action == true then
if (state+ajustingValue) < 0 then
state = 0.000
else
state = state+ajustingValue
end
else
state = ajustingValue
end
self.setValue(items, state)
end
message(self:get())
return message
end

-- Automatic fadeout length methods
local fadeoutAutoLenProperty = {}
parentLayout.itemLayout:registerProperty(fadeoutAutoLenProperty)

function  fadeoutAutoLenProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO")
end

function  fadeoutAutoLenProperty.setValue(item, value)
reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", value)
end

function  fadeoutAutoLenProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to setup desired automatic fadeout length for selected item.", "Adjustable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" If you want to switch off automatic fadeout, set the value less than 0.000 MS. Perform this property to reset the length value to default in preferences.", 1)
if type(items) == "table" then
message("Items automatic fadeout length: ")
message(composeMultipleItemMessage(self.getValue, setmetatable({}, {__index = function(self, state)
if state >= 0 then
return ("%s ms"):format(tostring(state))
else
return "automatic fadeout off"
end
end
})))
else
local state = self.getValue(items)
if state >= 0 then
message(("Item %u automatic fadeout length %s ms"):format(getItemNumber(items), round(state, 3)))
else
message(("Item %u automatic fadeout off"):format(getItemNumber(items)))
end
end
return message
end

function  fadeoutAutoLenProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("timeStep", 0.001)
if action == false then
ajustingValue = -ajustingValue
elseif action == nil then
local result, str = reaper.get_config_var_string("defsplitxfadelen")
if result == true then
ajustingValue = round(tonumber(str), 3)
message("Restore default value, ")
else
return "No default fade length value has read in preferences."
end
end
if type(items) == "table" then
message("Items automatic fadeout lengths: ")
for k = 1, #items do
local state = self.getValue(items[k])
if action == false then
if (state+ajustingValue) >= 0 then
state = state+ajustingValue
elseif (state+ajustingValue) < 0 then
state = -1
elseif state< -1 then
state = -1
end
elseif action == true then
if (state+ajustingValue) < 0 then
state = 0.000
else
state = state+ajustingValue
end
else
state = ajustingValue
end
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if action == false then
if (state+ajustingValue) >= 0 then
state = state+ajustingValue
elseif (state+ajustingValue) < 0 then
state = -1
elseif state< -1 then
state = -1
message("Minimum length. ")
end
elseif action == true then
if (state+ajustingValue) < 0 then
state = 0.000
else
state = state+ajustingValue
end
else
state = ajustingValue
end
self.setValue(items, state)
end
message(self:get())
return message
end

-- active take methods
local activeTakeProperty = {}
parentLayout.takeLayout:registerProperty(activeTakeProperty)

function activeTakeProperty.getValue(item)
return reaper.GetActiveTake(item)
end

function  activeTakeProperty.setValue(item, take)
reaper.SetActiveTake(take)
end

function activeTakeProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to switch the desired  active take of selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
if type(items) == "table" then
message("Takes: ")
-- Here is non-standart case, so we will not use our macros
for k = 1, #items do
local state, IDX = self.getValue(items[k]), getTakeNumber(items[k])
local prevState, prevIDX  if items[k-1] then prevState, prevIDX = self.getValue(items[k-1]), getTakeNumber(items[k-1]) end
local nextState, nextIDX if items[k+1] then nextState, nextIDX = self.getValue(items[k+1]), getTakeNumber(items[k+1]) end
if IDX ~= prevIDX and IDX == nextIDX then
message(string.format("items from %u ", getItemNumber(items[k])))
elseif IDX == prevIDX and IDX ~= nextIDX then
message(string.format("to %u ", getItemNumber(items[k])))
message(string.format("%u, %s", getTakeNumber(items[k]), currentTakeNameProperty.getValue(items[k])))
if k < #items then
message(", ")
end
elseif IDX == prevIDX and IDX == nextIDX then
else
message(string.format("item %u ", getItemNumber(items[k])))
message(string.format("%u, %s", getTakeNumber(items[k]), currentTakeNameProperty.getValue(items[k])))
if k < #items then
message(", ")
end
end
end
else
local state = self.getValue(items)
local retval, name = reaper.GetSetMediaItemTakeInfo_String(state, "P_NAME", "", false)
message(string.format("Item %u take %u, %s", getItemNumber(items), getTakeNumber(items), name))
end
return message
end

function activeTakeProperty:set(action)
local message = initOutputMessage()
if action == nil then
return "This property is adjustable only."
end
if type(items) == "table" then
message("Takes: ")
for k = 1, #items do
local state = self.getValue(items[k])
local idx = reaper.GetMediaItemTakeInfo_Value(state, "IP_TAKENUMBER")
if action == true then
if idx+1 < reaper.CountTakes(items[k]) then
state = reaper.GetTake(items[k], idx+1)
end
elseif action == false then
if idx-1 >= 0 then
state = reaper.GetTake(items[k], idx-1)
end
end
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
local idx = reaper.GetMediaItemTakeInfo_Value(state, "IP_TAKENUMBER")
if action == true then
if idx+1 < reaper.CountTakes(items) then
state = reaper.GetTake(items, idx+1)
else
message("No more next property values. ")
end
elseif action == false then
if idx-1 >= 0 then
state = reaper.GetTake(items, idx-1)
else
message("No more previous property values. ")
end
end
self.setValue(items, state)
end
message(self:get())
return message
end

-- Take volume methods
local takeVolumeProperty = {}
parentLayout.takeLayout:registerProperty(takeVolumeProperty)

function takeVolumeProperty.getValue(item)
local state = reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_VOL")
if state < 0 then
state = -state
end
return state
end

function  takeVolumeProperty.setValue(item, value)
local state = reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_VOL")
if state < 0 then
value = -value
end
reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_VOL", value)
end

function takeVolumeProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired volume value for active take of selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item take of.", 1)
end
message:addType(" Perform this property to normalize the volume for.", 1)
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, normalize to common gain will be applied.", 1)
end
if type(items) == "table" then
message("Takes volume: ")
message(composeMultipleTakeMessage(self.getValue, setmetatable({}, {__index = function(self, state) return string.format("%s dB", numtodecibels(state)) end})))
else
local state = self.getValue(items)
message(string.format("Item %u take %u volume %s db", getItemNumber(items), getTakeNumber(items), numtodecibels(state)))
end
return message
end

function takeVolumeProperty:set(action)
local message = initOutputMessage()
local ajustStep = config.getinteger("dbStep", 0.1)
if type(items) == "table" then
if action == nil then
message("Normalizing item takes to common gain, ")
reaper.Main_OnCommand(40254, 0)
end
for k = 1, #items do
if action == true then
local state = self.getValue(items[k])
if state < decibelstonum(maxDBValue) then
state = decibelstonum(numtodecibels(state)+ajustStep)
else
state = decibelstonum(12.0)
end
self.setValue(items[k], state)
elseif action == false then
local state = self.getValue(items[k])
if numtodecibels(state) ~= "-inf" then
state = decibelstonum(numtodecibels(state)-ajustStep)
else
state = 0
end
self.setValue(items[k], state)
end
end
else
local state = self.getValue(items)
if action == true then
if state < decibelstonum(maxDBValue) then
state = decibelstonum(numtodecibels(state, true)+ajustStep)
else
state = decibelstonum(12.0)
message("maximum volume. ")
end
self.setValue(items, state)
elseif action == false then
if numtodecibels(state) ~= "-inf" then
state = decibelstonum(numtodecibels(state, true)-ajustStep)
else
state = 0
message("Minimum volume. ")
end
self.setValue(items, state)
else
message("Normalize item take volume")
reaper.Main_OnCommand(40108, 0)
end
end
message(self:get())
return message
end


-- Take pan methods
local takePanProperty = {}
parentLayout.takeLayout:registerProperty(takePanProperty)

function takePanProperty.getValue(item)
return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PAN")
end

function takePanProperty.setValue(item, value)
reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PAN", value)
end

function takePanProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired current take pan value for selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item active take of.", 1)
end
message:addType(" Perform this property to set the take pan to center.", 1)
if type(items) == "table" then
message("Takes pan: ")
message(composeMultipleTakeMessage(self.getValue, setmetatable({}, {__index = function(self, state) return numtopan(state) end})))
else
message(string.format("Item %u take %u pan ", getItemNumber(items), getTakeNumber(items)))
local state = self.getValue(items)
message(string.format("%s", numtopan(state)))
end
return message
end

function takePanProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("percentStep", 1)
if action == true then
ajustingValue = percenttonum(ajustingValue) or 0.01
elseif action == false then
ajustingValue = -percenttonum(ajustingValue) or -0.01
else
message("reset, ")
ajustingValue = nil
end
if type(items) == "table" then
for k = 1, #items do
local state = self.getValue(items[k])
if ajustingValue then
state = round((state+ajustingValue), 3)
if state >= 1 then
state = 1
elseif state <= -1 then
state = -1
end
else
state = 0
end
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if ajustingValue then
state = round((state+ajustingValue), 3)
if state > 1 then
state = 1
message("Right boundary. ")
elseif state < -1 then
state = -1
message("Left boundary. ")
end
else
state = 0
end
self.setValue(items, state)
end
message(self:get())
return message
end

-- Take phase methods
local takePhaseProperty = {}
 parentLayout.takeLayout:registerProperty( takePhaseProperty)
takePhaseProperty.states = {[0]="normal", [1]="inverted"}

-- Cockos made the phase inversion via negative volume value.
function takePhaseProperty.getValue(item)
local state = reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_VOL")
if state < 0 then
return 1
elseif state >= 0 then
return 0
end
end

function  takePhaseProperty.setValue(item, value)
local state = reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_VOL")
if value == 1 then
if state > 0 then
state = -state
end
elseif value == 0 then
if state < 0 then
state = -state
end
end
reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_VOL", state)
end

function takePhaseProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to set the phase polarity for take of selected item.", "toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the phase polarity state will be set to oposite value depending of moreness takes of items with the same value.", 1)
end
if type(items) == "table" then
message("Takes phase: ")
message(composeMultipleTakeMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("item %u take %u phase %s", getItemNumber(items), getTakeNumber(items), self.states[state]))
end
return message
end

function takePhaseProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(items) == "table" then
local phasedItems, notphasedItems = 0, 0
for k = 1, #items do
local state = self.getValue(items[k])
if state == 1 then
phasedItems = phasedItems+1
else
notphasedItems = notphasedItems+1
end
end
local ajustingValue
if phasedItems > notphasedItems then
ajustingValue = 0
message("Normalizing the phase for selected items takes.")
elseif phasedItems < notphasedItems then
ajustingValue = 1
message("Inverting the phase for selected items takes.")
else
ajustingValue = 0
message("Normalizing the phase for selected items takes.")
end
for k = 1, #items do
self.setValue(items[k], ajustingValue)
end
else
self.setValue(items, nor(self.getValue(items)))
end
message(self:get())
return message
end

-- Take channel mode methods
local takeChannelModeProperty = {}
 parentLayout.takeLayout:registerProperty(takeChannelModeProperty)
takeChannelModeProperty.states = setmetatable({
[0] = "normal",
[1] = "reverse stereo",
[2] = "mono (downmix)",
[3] = "mono (left)",
[4] = "mono (right)"
}, {
__index = function(self,key)
if key <= 66 then
return ("mono %u"):format(key-2)
else
return ("stereo %u/%u"):format(key-66, key-65)
end
end,
__len = function(self)
return 129
end
})

function takeChannelModeProperty.getValue(item)
return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_CHANMODE")
end

function takeChannelModeProperty.setValue(item, value)
reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_CHANMODE", value)
end


function takeChannelModeProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose the desired channel mode for active take of selected item.", "Adjustable, toggleable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if selected items have the same value. Otherwise, the channel mode state will be set to "%s", then will enumerate this.', self.states[0]), 1)
end
message:addType(" Toggle this property to switch between channel mode categories.", 1)
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the category will define by first selected item take and next category will be switch for selected selected items.", 1)
end
if type(items) == "table" then
message("Takes channel mode: ")
message(composeMultipleTakeMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("Item %u take %u channel mode %s", getItemNumber(items), getTakeNumber(items), self.states[state]))
end
return message
end

function takeChannelModeProperty:set(action)
local message = initOutputMessage()
local ajustingValue
if action == true then
ajustingValue = 1
elseif action == false then
ajustingValue = -1
end
if type(items) == "table" then
if action ~= nil then
local lastState = self.getValue(items[1])
for k = 1, #items do
local state = self.getValue(items[k])
if lastState ~= state then
ajustingValue = 0
break
end
lastState = state
end
local state
if ajustingValue ~= 0 then
state = self.getValue(items[1])
if (state+ajustingValue) >= 0 and self.states[(state+ajustingValue)] then
state = state+ajustingValue
end
else
if state >= 0 and state < 5 then
state = 5
elseif state >= 5 and state < 67 then
state = 67
elseif state >= 67 then
state = 0
end
end
message(string.format("Set selected items active takes channel mode to %s.", self.states[state]))
for k = 1, #items do
self.setValue(items[k], state)
end
else
message(string.format("Set selected Takes channel mode to %s.", self.states[0]))
for k = 1, #items do
self.setValue(items[k], 0)
end
end
else
local state = self.getValue(items)
if action == true or action == false then
if (state+ajustingValue) > #self.states then
message("No more next property values. ")
elseif state+ajustingValue < 0 then
message("No more previous property values. ")
else
state = state+ajustingValue
end
else
if state >= 0 and state < 5 then
state = 5
elseif state >= 5 and state < 67 then
state = 67
elseif state >= 67 then
state = 0
end
end
self.setValue(items, state)
end
message(self:get())
return message
end


-- Take playrate methods
local takePlayrateProperty = {}
parentLayout.takeLayout:registerProperty(takePlayrateProperty)

function takePlayrateProperty.getValue(item)
return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE")
end

function  takePlayrateProperty.setValue(item, value)
reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE", value)
end

function takePlayrateProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired playrate value for active take of selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item take of.", 1)
end
message:addType(" Perform this property to reset  playrate to 1.000 for.", 1)
if type(items) == "table" then
message("Takes playrate: ")
message(composeMultipleTakeMessage(self.getValue, setmetatable({}, {__index = function(self, state) return string.format("%-5f ms", state) end})))
else
local state = self.getValue(items)
message(string.format("Item %u take %u playrate %s", getItemNumber(items), getTakeNumber(items), round(state, 3)))
end
return message
end

function takePlayrateProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("timeStep", 0.001)
if action == false then
ajustingValue = -ajustingValue
elseif action == nil then
message("Reset,")
ajustingValue = 1.000
end
if type(items) == "table" then
message("Takes playrate: ")
for k = 1, #items do
local state = self.getValue(items[k])
if action == true or action == false then
if (state+ajustingValue) >= 0 then
state = state+ajustingValue
end
else
state = ajustingValue
end
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if action == true or action == false then
if (state+ajustingValue) >= 0.000 then
state = state+ajustingValue
else
state = 0.000
message("Minimum playrate. ")
end
else
state = ajustingValue
end
self.setValue(items, state)
 end
 message(self:get())
return message
end

-- Preserve pitch when playrate changes methods
local preserveTakePitchProperty = {}
 parentLayout.takeLayout:registerProperty( preserveTakePitchProperty)
preserveTakePitchProperty.states = {[0]="not preserved", [1]="preserved"}

function preserveTakePitchProperty.getValue(item)
return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "B_PPITCH")
end

function  preserveTakePitchProperty.setValue(item, value)
reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "B_PPITCH", value)
end

function preserveTakePitchProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to set the switch status of preserving current take pitch when play rate changes of selected item.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the preserve state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Takes preserve pitch when playrate changes: ")
message(composeMultipleTakeMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("item %u take %u pitch %s when playrate changes", getItemNumber(items), getTakeNumber(items), self.states[state]))
end
return message
end

function preserveTakePitchProperty:set(action)
local message = initOutputMessage()
if action ~= nil then
return "This property is toggleable only."
end
if type(items) == "table" then
local preservedItems, notpreservedItems = 0, 0
for k = 1, #items do
local state = self.getValue(items[k])
if state == 1 then
preservedItems = preservedItems+1
else
notpreservedItems = notpreservedItems+1
end
end
local ajustingValue
if preservedItems > notpreservedItems then
ajustingValue = 0
message("switching off the preserving for selected items.")
elseif preservedItems < notpreservedItems then
ajustingValue = 1
message("switching on the preserving for selected items.")
else
ajustingValue = 0
message("switching off the preserving for selected items.")
end
for k = 1, #items do
self.setValue(items[k], ajustingValue)
end
else
self.setValue(items, nor(self.getValue(items)))
end
message(self:get())
return message
end

-- Take pitch methods
local takePitchProperty = {}
parentLayout.takeLayout:registerProperty(takePitchProperty)

function takePitchProperty.getValue(item)
return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PITCH")
end

function  takePitchProperty.setValue(item, value)
reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PITCH", value)
end

function takePitchProperty.compose(num)
local message = initOutputMessage()
num = round(num, 2)
if num == 0 then
return "original"
else
local fv = splitstring(tostring(round(num, 2)), ".")
if num < 0 then
message("-")
end
if tonumber(fv[1]) ~= 0 then
message(string.format("%s semitone%s", fv[1], ({[false]="", [true]="s"})[(tonumber(fv[1]) > 1 or tonumber(fv[1]) < -1)]))
if tonumber(fv[2]) > 0 then
message(", ")
end
end
if fv[2] ~= "0" then
message(string.format("%s cent%s", numtopercent(tonumber("0."..fv[2])), ({[false]="", [true]="s"})[(numtopercent(tonumber("0."..fv[2])) > 1)]))
end
end
return tostring(message)
end

function takePitchProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired pitch value for active take of selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item take of.", 1)
end
message:addType(" Perform this property to reset  pitch to 0.", 1)
if type(items) == "table" then
message("Takes pitch: ")
message(composeMultipleTakeMessage(self.getValue, setmetatable({}, {__index = function(self, state) return takePitchProperty.compose(state) end})))
else
local state = self.getValue(items)
message(string.format("Item %u  take %u pitch %s", getItemNumber(items), getTakeNumber(items), self.compose(state)))
end
return message
end

function takePitchProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("pitchStep", 1)
if action == false then
ajustingValue = -ajustingValue
elseif action == nil then
message("Reset,")
ajustingValue = 0
end
if type(items) == "table" then
message("Takes pitch: ")
for k = 1, #items do
local state = self.getValue(items[k])
if action == true or action == false then
state = state+ajustingValue
else
state = ajustingValue
end
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if action == true or action == false then
state = state+ajustingValue
else
state = ajustingValue
end
self.setValue(items, state)
end
message(self:get())
return message
end

-- Pitch shifter methods
local takePitchShifterProperty = {}
parentLayout.takeLayout:registerProperty(takePitchShifterProperty)
takePitchShifterProperty.states = setmetatable({[-1] = "project default"},
{
__index = function(self, key)
if tonumber(key) and key >= 0 then
key = bytewords.getHiWord(key)
local retval, name = reaper.EnumPitchShiftModes(key)
if retval == true then
return name
end
end
return nil
end,
__len = function(self)
local i = 0
while ({reaper.EnumPitchShiftModes(i)})[1] == true do
i = i+1
end
return i
end
})

function takePitchShifterProperty.getValue(item)
return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_PITCHMODE")
end

function  takePitchShifterProperty.setValue(item, value)
reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_PITCHMODE", value)
end


function takePitchShifterProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose the desired pitch shifter (i.e., pitch algorhythm) for active take of selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if selected items have the same value. Otherwise, the pitch shifter state will be set to "%s", then will enumerate this.', self.states[-1]), 1)
end
message:addType(string.format(" Perform this property to reset the value to %s.", self.states[-1]), 1)
if type(items) == "table" then
message("Takes pitch shifter: ")
message(composeMultipleTakeMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("Item %u take %u pitch shifter %s", getItemNumber(items), getTakeNumber(items), self.states[state]))
end
return message
end

function   takePitchShifterProperty:set(action)
local message = initOutputMessage()
local ajustingValue
if action == true then
ajustingValue = 1
elseif action == false then
ajustingValue = -1
end
if type(items) == "table" then
local state
if action ~= nil then
local lastState = self.getValue(items[1])
for k = 1, #items do
local state = self.getValue(items[k])
if lastState ~= state then
ajustingValue = 0
break
end
lastState = state
end
state = self.getValue(items[1])
if ajustingValue > 0 then
if state >= 0 then
for i = bytewords.getHiWord(state)+ajustingValue, #self.states+1 do
if self.states[bytewords.makeLong(bytewords.getLoWord(state), i)] then
state = bytewords.makeLong(0, i)
break
end
end
else
state = bytewords.makeLong(0, 0)
end
elseif ajustingValue < 0 then
if state >= 0 then
for i = bytewords.getHiWord(state)+ajustingValue, -2, -1 do
if i >= 0 then
if self.states[bytewords.makeLong(bytewords.getLoWord(state), i)] then
state = bytewords.makeLong(0, i)
break
end
else
if self.states[i] then
state = i
end
end
end
end
elseif ajustingValue == 0 then
state = -1
end
elseif action  == nil then
state = -1
end
message(string.format("Set selected items active takes pitch shifter to %s.", self.states[state]))
for k = 1, #items do
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if action == true then
if state >= 0 then
for i = bytewords.getHiWord(state)+ajustingValue, #self.states+1 do
if self.states[bytewords.makeLong(bytewords.getLoWord(state), i)] then
state = bytewords.makeLong(0, i)
break
end
if i == #self.states then
message("No more next property values. ")
end
end
else
state = bytewords.makeLong(0, 0)
end
elseif action == false then
if state >= 0 then
for i = bytewords.getHiWord(state)+ajustingValue, -2, -1 do
if i >= 0 then
if self.states[bytewords.makeLong(bytewords.getLoWord(state), i)] then
state = bytewords.makeLong(0, i)
break
end
else
if self.states[i] then
state = i
end
end
end
else
message("No more previous property values. ")
end
else
state = -1
message("Reset, ")
end
self.setValue(items, state)
end
message(self:get())
return message
end

-- Active shifter mode methods
local takePitchShifterModeProperty = {}
parentLayout.takeLayout:registerProperty(takePitchShifterModeProperty)
takePitchShifterModeProperty.states = setmetatable({[-1] = "unavailable"},
{
__index = function(self, key)
key = tonumber(key)
if key then
return reaper.EnumPitchShiftSubModes(bytewords.getHiWord(key), bytewords.getLoWord(key))
end
return nil
end
})

takePitchShifterModeProperty.getValue, takePitchShifterModeProperty.setValue = takePitchShifterProperty.getValue, takePitchShifterProperty.setValue
 

function takePitchShifterModeProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose the desired mode for active shifter  of active take on selected item.", "Adjustable")
if multiSelectionSupport == true then
message:addType(string.format(" If the group of items has been selected, the value will enumerate only if selected items have the same value. Otherwise, the pitch shifter mode will be set to first setting for this shifter, then will enumerate this. Please note: if one of selected items will has pitch shifter set to %s, the adjusting of this property will not available until selected shifters will not set to any different.", takePitchShifterProperty.states[-1]), 1)
end
if type(items) == "table" then
message("Takes pitch shifter modes: ")
message(composeMultipleTakeMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("Item %u take %u shifter mode %s", getItemNumber(items), getTakeNumber(items), self.states[state]))
if state == -1 then
message:changeType(string.format("The Property is unavailable right now, because the shifter has been set to %s. Set the specified shifter before setting it up.", takePitchShifterProperty.states[-1]), 1)
message:changeType("unavailable", 2)
end
end
return message
end

function   takePitchShifterModeProperty:set(action)
local message = initOutputMessage()
local ajustingValue
if action == true then
ajustingValue = 1
elseif action == false then
ajustingValue = -1
else
return "This property adjustable only."
end
if type(items) == "table" then
local state
if action ~= nil then
local lastState = self.getValue(items[1])
for k = 1, #items do
local state = self.getValue(items[k])
if state == -1 then
return string.format("The shifter of take %u item %u is set to %s. Set any otherwise  shifter on this take before  setting up the shifter mode.", getTakeNumber(items[k]), getItemNumber(items[k]), takePitchShifterProperty.states[-1])
end
if lastState ~= state then
ajustingValue = 0
break
end
lastState = state
end
state = self.getValue(items[1])
if ajustingValue ~= 0 then
if action == true then
local futureState = bytewords.makeLong(bytewords.getLoWord(state)+1, bytewords.getHiWord(state))
if self.states[futureState] then
state = futureState
end
elseif action == false then
if bytewords.getLoWord(state)-1 >= 0 then
state = bytewords.makeLong(bytewords.getLoWord(state)-1, bytewords.getHiWord(state))
end
end
elseif ajustingValue == 0 then
state = bytewords.makeLong(0, bytewords.getHiWord(state))
end
message(string.format("Set selected items active takes pitch shifter modes to %s.", self.states[state]))
for k = 1, #items do
self.setValue(items[k], state)
end
end
else
local state = self.getValue(items)
if state == -1 then
return string.format("The property is unavailable right now, because the shifter has been set to %s. Set the specified shifter before setting it up.", takePitchShifterProperty.states[-1])
end
if action == true then
local futureState = bytewords.makeLong(bytewords.getLoWord(state)+1, bytewords.getHiWord(state))
if self.states[futureState] then
state = futureState
else
message("No more next property values. ")
end
elseif action == false then
if bytewords.getLoWord(state)-1 >= 0 then
state = bytewords.makeLong(bytewords.getLoWord(state)-1, bytewords.getHiWord(state))
else
message("No more previous property values. ")
end
end
self.setValue(items, state)
end
message(self:get())
return message
end

-- Items color methods
local itemColorProperty = {}
parentLayout.visualLayout:registerProperty(itemColorProperty)

function itemColorProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR"), reaper.GetDisplayedMediaItemColor(item)
end

function itemColorProperty.setValue(item, value)
reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", value|0x100000)
end

function itemColorProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel"), "Read this property to get the information about item color. Perform this property to apply composed color in the items category.", "performable")
if multiSelectionSupport == true then
message:addType(" If the group of items have been selected, this color will be applied for selected this items.", 1)
end
if type(items) == "table" then
message("Items color:")
message(composeMultipleItemMessage(function(item)
local state, visualApplied = self.getValue(item)
return string.format("%s|%s", state, visualApplied)
end,
setmetatable({}, {
__index = function(self, key)
local msg = ""
local raw = splitstring(key, "|")
local state = tonumber(raw[1])
local visualApplied = tonumber(raw[2])
msg = colors:getName(reaper.ColorFromNative(state))
if state ~= visualApplied then
msg = msg..string.format(", but visually looks as %s", colors:getName(reaper.ColorFromNative(visualApplied)))
end
return msg
end
})))
else
local state, visualApplied = self.getValue(items)
message(string.format("Item %u color %s", getItemNumber(items), colors:getName(reaper.ColorFromNative(state))))
if state ~= visualApplied then
message(string.format(", but visually looks as %s", colors:getName(reaper.ColorFromNative(visualApplied))))
end
end
return message
end

function itemColorProperty:set(action)
local message = initOutputMessage()
if action == nil then
local state = getItemComposedColor()
if state then
if type(items) == "table" then
message(string.format("All selected items colorized to %s.", colors.getName(reaper.ColorFromNative(state))))
for _, item in ipairs(items) do
self.setValue(item, state)
end
else
self.setValue(items, state)
local state, visualApplied = self.getValue(items)
message(string.format("Item %u colorized to %s", getItemNumber(items), colors:getName(reaper.ColorFromNative(state))))
if state ~= visualApplied then
message(string.format(", but visually displayed as %s", colors:getName(reaper.ColorFromNative(visualApplied))))
end
end
else
message("Compose a color in color composer first.")
end
else
message("This property is performable only.")
end
return message
end

-- Item current take color methods
local itemTakeColorProperty = {}
parentLayout.visualLayout:registerProperty(itemTakeColorProperty)

function itemTakeColorProperty.getValue(item)
return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_CUSTOMCOLOR")
end

function  itemTakeColorProperty.setValue(item, value)
reaper.SetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_CUSTOMCOLOR", value|0x100000)
end

function itemTakeColorProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel"), "Read this property to get the information about active item take color. Perform this property to apply composed color in the takes category.", "performable")
if multiSelectionSupport == true then
message:addType(" If the group of items have been selected, this color will be applied for selected its active takes.", 1)
end
if type(items) == "table" then
message("Take  color:")
message(composeMultipleTakeMessage(self.getValue, setmetatable({}, {__index = function(self, state) return colors:getName(reaper.ColorFromNative(state)) end})))
else
local state = self.getValue(items)
message(string.format("Item %u take %u color %s", getItemNumber(items), getTakeNumber(items), colors:getName(reaper.ColorFromNative(state))))
end
return message
end

function itemTakeColorProperty:set(action)
local message = initOutputMessage()
if action == nil then
local state = getTakeComposedColor()
if state then
if type(items) == "table" then
message(string.format("All active takes of selected items colorized to %s.", colors.getName(reaper.ColorFromNative(state))))
for _, item in ipairs(items) do
self.setValue(item, state)
end
else
self.setValue(items, state)
local state = self.getValue(items)
message(string.format("Item %u take %u colorized to %s", getItemNumber(items), getTakeNumber(items), colors:getName(reaper.ColorFromNative(state))))
end
else
message("Compose a color in color composer first.")
end
else
message("This property is performable only.")
end
return message
end

return parentLayout[sublayout]