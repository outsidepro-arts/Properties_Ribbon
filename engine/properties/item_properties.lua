--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020 outsidepro-arts
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
sublayout = extstate.get(currentLayout.."_sublayout")
if sublayout == "" or sublayout == nil then
sublayout = "visualLayout"
end

-- Reading the some config which will be used everyhere
multiSelectionSupport = config.getboolean("multiSelectionSupport", true)
-- For comfort coding, we are making the items array as global

items = nil
do
local countItems = reaper.CountMediaItems(0)
if countItems then
items = {}
for i = 1, countItems do
local item = reaper.GetMediaItem(0,i-1)
		if reaper.IsMediaItemSelected(item) == true then
items[#items+1] = item
if multiSelectionSupport == false then
break
end
end
		end
if #items == 1 then
items = items[#items]
end
end
end

-- I've just tired to write this long call so
local function getItemNumber(item)
return reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")+1
end

-- And another one:
local function getTakeNumber(take)
return reaper.GetMediaItemTakeInfo_Value(take, "IP_TAKENUMBER")
end

-- global pseudoclass initialization
-- We have to fully initialize this because this table will be coppied to main class. Some fields seems uneccessary, but it's not true.
parentLayout = setmetatable({
name = "Item%s properties", -- The main class name, which will be formatted by subclass name
ofCount = 0 -- The full categories count
}, {
-- When new field has been added we just take over the ofCount adding
__newindex = function(self, key, value)
rawset(self, key, value)
if key ~= "canProvide" then
self.ofCount = self.ofCount+1
end
end
})

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
parentLayout.visualLayout = setmetatable({
section = "itemVisualProperties", -- The section in ExtState
subname = " visual", -- the name of class which will set to some messages
slIndex = 1, -- Index of category
nextSubLayout = "itemLayout", -- the next sublayout the switch script will be set to
-- the properties list. It initializes first, then the methods will be added below.
properties = {}
}, {__index = parentLayout}
)
--Item properties
parentLayout.itemLayout = setmetatable({
section = "itemProperties", -- The section in ExtState
subname = "", -- the name of class which will set to some messages
-- This string is empty cuz the layout's name and this sublayout's name is identical
slIndex = 2, -- Index of category
previousSubLayout = "visualLayout", -- the previous sublayout the switch script will be set to
nextSubLayout = "takeLayout", -- the next sublayout the switch script will be set to
-- the properties list. It initializes first, then the methods will be added below.
properties = {}
}, {__index = parentLayout}
)
-- Current take properties
parentLayout.takeLayout = setmetatable({
section = "takeProperties", -- The section in ExtState
subname = " current take", -- the name of class which will set to some messages
slIndex = 3, -- Index of category
previousSubLayout = "itemLayout", -- the previous sublayout the switch script will be set to
-- the properties list. It initializes first, then the methods will be added below.
properties = {}
}, {__index = parentLayout}
)

-- The creating new property macros
local function registerProperty(property, sl)
parentLayout[sl].properties[#parentLayout[sl].properties+1] = setmetatable(property, {__index = parentLayout})
end

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
registerProperty(currentTakeNameProperty, "visualLayout")

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
message:addType(" If the group of items has been selected, new name will applied to all active takes of selected items.", 1)
end
if type(items) == "table" then
message("Items takes names: ")
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
 registerProperty( lockProperty, "itemLayout")
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
message("Items locking state: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(string.format("item %u ", getItemNumber(items[k])))
message(self.states[state])
if k < #items then
message(", ")
end
end
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
message("Locking all selected items.")
elseif lockedItems < notLockedItems then
ajustingValue = 1
message("Unlocking all selected items.")
else
ajustingValue = 0
message("Locking all selected items.")
end
for k = 1, #items do
self.setValue(items[k], ajustingValue)
end
else
local state = self.getValue(items)
if state == 1 then
state = 0
else
state = 1
end
self.setValue(items, state)
state = self.getValue(items)
message(string.format("Item %u %s", getItemNumber(items), self.states[state]))
end
return message
end

-- volume methods
local itemVolumeProperty = {}
registerProperty(itemVolumeProperty, "itemLayout")

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
message("items volume: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(string.format("item %u in ", getItemNumber(items[k])))
message(string.format("%s db", numtodecibels(state)))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
message(string.format("Item %u volume %s db", getItemNumber(items), numtodecibels(state)))
end
return message
end

function itemVolumeProperty:set(action)
local message = initOutputMessage()
if action == nil then
message("reset, ")
end
local ajustStep = config.getinteger("dbStep", 0.1)
if type(items) == "table" then
message("Items volume: ")
for k = 1, #items do
local state = self.getValue(items[k])
if action == true then
if state < decibelstonum(12.0) then
state = decibelstonum(numtodecibels(state)+ajustStep)
else
state = 3.981071705535
end
elseif action == false then
if numtodecibels(state) ~= "-inf" then
state = decibelstonum(numtodecibels(state)-ajustStep)
else
state = 0
end
else
state = 1
end
self.setValue(items[k], state)
state = self.getValue(items[k])
message(string.format("item %u in ", getItemNumber(items[k])))
message(string.format("%s db", numtodecibels(state)))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
if action == true then
if state < decibelstonum(12.0) then
state = decibelstonum(numtodecibels(state, true)+ajustStep)
else
state = decibelstonum(12.0)
message("maximum volume. ")
end
elseif action == false then
if numtodecibels(state) ~= "-inf" then
state = decibelstonum(numtodecibels(state, true)-ajustStep)
else
state = 0
message("Minimum volume. ")
end
else
state = 1
end
self.setValue(items, state)
 state = self.getValue(items)
message(string.format("Item %u volume %s db", getItemNumber(items), numtodecibels(state)))
end
return message
end

-- mute methods
local muteItemProperty = {}
 registerProperty( muteItemProperty, "itemLayout")
muteItemProperty.states = {[0]="not muted", [1]="muted"}

function muteItemProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to mute or unmute selected item.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the mute state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items mute state: ")
for k = 1, #items do
local state = reaper.GetMediaItemInfo_Value(items[k], "B_MUTE")
message(string.format("item %u ", getItemNumber(items[k])))
message(self.states[state])
if k < #items then
message(", ")
end
end
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
message("Unmuting all items.")
elseif mutedItems < notMutedItems then
ajustingValue = 1
message("Muting all items.")
else
ajustingValue = 0
message("Unmuting all items.")
end
for k = 1, #items do
reaper.SetMediaItemInfo_Value(items[k], "B_MUTE", ajustingValue)
end
else
local state = reaper.GetMediaItemInfo_Value(items, "B_MUTE")
if state == 1 then
state = 0
else
state = 1
end
reaper.SetMediaItemInfo_Value(items, "B_MUTE", state)
state = reaper.GetMediaItemInfo_Value(items, "B_MUTE")
message(string.format("Item %u %s", getItemNumber(items), self.states[state]))
end
return message
end

-- Loop source methods
local loopSourceProperty = {}
 registerProperty( loopSourceProperty, "itemLayout")
loopSourceProperty.states = {[0]="not looped", [1]="looped"}

function loopSourceProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to loop or unloop the source of selected item.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the loop source state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items source loop state: ")
for k = 1, #items do
local state = reaper.GetMediaItemInfo_Value(items[k], "B_LOOPSRC")
message(string.format("item %u ", getItemNumber(items[k])))
message(self.states[state])
if k < #items then
message(", ")
end
end
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
message("Set all items sources loop off.")
elseif loopedItems < notLoopedItems then
ajustingValue = 1
message("Looping all items sources.")
else
ajustingValue = 0
message("Set all items sourcess loop off.")
end
for k = 1, #items do
reaper.SetMediaItemInfo_Value(items[k], "B_LOOPSRC", ajustingValue)
end
else
local state = reaper.GetMediaItemInfo_Value(items, "B_LOOPSRC")
if state == 1 then
state = 0
else
state = 1
end
reaper.SetMediaItemInfo_Value(items, "B_LOOPSRC", state)
state = reaper.GetMediaItemInfo_Value(items, "B_LOOPSRC")
message(string.format("Item %u source %s", getItemNumber(items), self.states[state]))
end
return message
end

-- All takes play methods
local itemAllTakesPlayProperty = {}
 registerProperty( itemAllTakesPlayProperty, "itemLayout")
itemAllTakesPlayProperty.states = {[0]="all takes aren't playing", [1]="all takes are playing"}

function itemAllTakesPlayProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Toggle this property to define the playing all takes of selected item.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the playing all takes state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items all takes playing state: ")
for k = 1, #items do
local state = reaper.GetMediaItemInfo_Value(items[k], "B_ALLTAKESPLAY")
message(string.format("item %u ", getItemNumber(items[k])))
message(self.states[state])
if k < #items then
message(", ")
end
end
else
local state = reaper.GetMediaItemInfo_Value(items, "B_ALLTAKESPLAY")
message(string.format("item %u %s", getItemNumber(items), self.states[state]))
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
message("Sett all items takes play off.")
elseif tkPlayItems < tkNotPlayItems then
ajustingValue = 1
message("Set all items takes play on.")
else
ajustingValue = 0
message("Set all items takes play off.")
end
for k = 1, #items do
reaper.SetMediaItemInfo_Value(items[k], "B_ALLTAKESPLAY", ajustingValue)
end
else
local state = reaper.GetMediaItemInfo_Value(items, "B_ALLTAKESPLAY")
if state == 1 then
state = 0
else
state = 1
end
reaper.SetMediaItemInfo_Value(items, "B_ALLTAKESPLAY", state)
state = reaper.GetMediaItemInfo_Value(items, "B_ALLTAKESPLAY")
message(string.format("Item %u %s", getItemNumber(items), self.states[state]))
end
return message
end



-- timebase methods
local timebaseProperty = {}
 registerProperty(timebaseProperty, "itemLayout")
timebaseProperty.states = {
[0] = "track or project default",
[2] = "beats (position, length, rate)",
[3] = "beats (position only)"
}

function timebaseProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose the desired time base mode for selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if all items have the same value. Otherwise, the timebase state will be set to "%s", then will enumerate this.', self.states[0]), 1)
end
if type(items) == "table" then
message("Items timebase state: ")
for k = 1, #items do
local state = reaper.GetMediaItemInfo_Value(items[k], "C_BEATATTACHMODE")
message(string.format("Item %u %s", getItemNumber(items[k]), self.states[state+1]))
if k < #items then
message(", ")
end
end
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
message(string.format("Set all items timebase to %s.", self.states[state+1]))
for k = 1, #items do
reaper.SetMediaItemInfo_Value(items[k], "C_BEATATTACHMODE", state)
end
else
message(string.format("Set all items timebase to %s.", self.states[0]))
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
message(string.format("Item %u timebase is %s", getItemNumber(items), self.states[reaper.GetMediaItemInfo_Value(items, "C_BEATATTACHMODE")+1]))
end
return message
end

-- Auto-stretch methods
local autoStretchProperty = {}
 registerProperty( autoStretchProperty, "itemLayout")
autoStretchProperty.states = {[0]="disabled", [1]="enabled"}

function autoStretchProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), string.format('Toggle this property to enable or disable auto-stretch selected item at project tempo when the item timebase is set to "%s".', timebaseProperty.states[2]), "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the auto-stretch state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items Auto-stretch at project tempo state: ")
for k = 1, #items do
local state = reaper.GetMediaItemInfo_Value(items[k], "C_AUTOSTRETCH")
message(string.format("item %u ", getItemNumber(items[k])))
message(self.states[state])
if k < #items then
message(", ")
end
end
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
message("Switching off the auto-stretch mode for all selected items.")
elseif stretchedItems < notStretchedItems then
ajustingValue = 1
message("Switching on the auto-stretch mode for all selected items.")
else
ajustingValue = 0
message("Switching off the auto-stretch mode for all selected items.")
end
for k = 1, #items do
reaper.SetMediaItemInfo_Value(items[k], "C_AUTOSTRETCH", ajustingValue)
end
else
local state = reaper.GetMediaItemInfo_Value(items, "C_AUTOSTRETCH")
if state == 1 then
state = 0
else
state = 1
end
reaper.SetMediaItemInfo_Value(items, "C_AUTOSTRETCH", state)
state = reaper.GetMediaItemInfo_Value(items, "C_AUTOSTRETCH")
message(string.format("Item %u auto-stretch at project tempo %s", getItemNumber(items), self.states[state]))
end
return message
end

-- Item group methods
-- For now, this property has been registered in visual layout section. Really, it influences on all items in the same group: all controls will be grouped and when an user changes any control slider, all other items changes the value too.
-- Are you Sure? But i'm not. 🤣
local groupingProperty = {}
registerProperty(groupingProperty, "visualLayout")
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
for k = 1, #items do
local state = self.getValue(items[k])
message(string.format("item %u in group %u", getItemNumber(items[k]), self.getValue(items[k])))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
if state == 0 then
message(("Item %u not in a group"):format(getItemNumber(items)))
else
message(("Item %u in group %u"):format(getItemNumber(items), state))
end
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
message(("Set all selected items to group %u."):format(state))
elseif state+ajustingValue == 0 then
state = 0
ajustingValue = 0
message("Removing all selected items from any group.")
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
 registerProperty(fadeinShapeProperty, "itemLayout")
fadeinShapeProperty.states = {
[0] = "Linear",
[1] = "Inverted quadratic",
[2] = "Quadratic",
[3] = "Inverted quartic",
[4] = "Quartic",
[5] = "Cosine S-curve",
[	6] = "Quartic S-curve"
}

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
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if all items have the same value. Otherwise, the shape state will be set to "%s", then will enumerate this.', self.states[0]), 1)
end
if type(items) == "table" then
message("Items fadein shape state: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(string.format("Item %u %s", getItemNumber(items[k]), self.states[state]))
if k < #items then
message(", ")
end
end
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
message(string.format("Set all items fadein shapes to %s.", self.states[state]))
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
message(string.format("Item %u fadein shape %s", getItemNumber(items), self.states[self.getValue(items)]))
end
return message
end

-- Fadein manual length methods
local fadeinLenProperty = {}
registerProperty(fadeinLenProperty, "itemLayout")

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
message("Items fadein length state: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(("Item %u length in %s ms"):format(getItemNumber(items[k]), state))
if k < #items then
message(", ")
end
end
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
message("Items fadein lengths state: ")
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
state = self.getValue(items[k])
message(("item %u %s ms"):format(getItemNumber(items[k]), round(state, 3)))
if k < #items then
message(", ")
end
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
 state = self.getValue(items)
message(string.format("Item %u fadein length %s ms", getItemNumber(items), round(state, 3)))
end
return message
end

-- Fadein curve methods
local fadeinDirProperty = {}
registerProperty( fadeinDirProperty, "itemLayout")

function  fadeinDirProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "D_FADEINDIR")
end

function  fadeinDirProperty.setValue(item,value)
reaper.SetMediaItemInfo_Value(item, "D_FADEINDIR", value)
end

function   fadeinDirProperty.compose(value)
if value >0 then
return ("%s%% to the right"):format(numtopercent(value))
elseif value < 0 then
return ("%s%% to the left"):format(-numtopercent(value))
elseif value == 0 then
return "flat"
end
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
for k = 1, #items do
local state = self.getValue(items[k])
message(("item %u: %s"):format(getItemNumber(items[k]), self.compose(state)))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
message(("Item %u fadein curve %s"):format(getItemNumber(items), self.compose(state)))
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
message("Items fadein curve: ")
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
state = self.getValue(items[k])
message(string.format("Item %u: %s", getItemNumber(items[k]), self.compose(state)))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
if ajustingValue then
state = round((state+ajustingValue), 3)
if state >= 1 then
state = 1
message("Right curve boundary. ")
elseif state <= -1 then
state = -1
message("Left curve boundary. ")
end
else
state = 0.00
message("Reset to flat curve. ")
end
self.setValue(items, state)
 state = self.getValue(items)
message(string.format("Item %u fadein curve %s", getItemNumber(items), self.compose(state)))
end
return message
end

-- Fadeout shape
local fadeoutShapeProperty = {}
 registerProperty(fadeoutShapeProperty, "itemLayout")
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
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if all items have the same value. Otherwise, the shape state will be set to "%s", then will enumerate this.', self.states[0]), 1)
end
if type(items) == "table" then
message("Items fadeout shape state: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(string.format("Item %u %s", getItemNumber(items[k]), self.states[state]))
if k < #items then
message(", ")
end
end
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
message(string.format("Set all items fadeout shapes to %s.", self.states[state]))
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
message(string.format("Item %u fadeout shape %s", getItemNumber(items), self.states[self.getValue(items)]))
end
return message
end

-- fadeout manual length methods
local fadeoutLenProperty = {}
registerProperty(fadeoutLenProperty, "itemLayout")

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
message("Items fadeout length state: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(("Item %u length in %s ms"):format(getItemNumber(items[k]), round(state, 3)))
if k < #items then
message(", ")
end
end
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
message("Items fadeout lengths state: ")
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
state = self.getValue(items[k])
message(("item %u %s ms"):format(getItemNumber(items[k]), round(state, 3)))
if k < #items then
message(", ")
end
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
 state = self.getValue(items)
message(string.format("Item %u fadeout length %s ms", getItemNumber(items), round(state, 3)))
end
return message
end

-- fadeout curve methods
local fadeoutDirProperty = {}
registerProperty( fadeoutDirProperty, "itemLayout")

function  fadeoutDirProperty.getValue(item)
return reaper.GetMediaItemInfo_Value(item, "D_FADEOUTDIR")
end

function  fadeoutDirProperty.setValue(item,value)
reaper.SetMediaItemInfo_Value(item, "D_FADEOUTDIR", value)
end

fadeoutDirProperty.compose =   fadeinDirProperty.compose

function  fadeoutDirProperty:get()
local message = initOutputMessage()
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to set the desired fadeout curvature for selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" Perform this property to reset the value to 0.00.", 1)
if type(items) == "table" then
message("Items fadeout curve: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(("item %u: %s"):format(getItemNumber(items[k]), self.compose(state)))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
message(("Item %u fadeout curve %s"):format(getItemNumber(items), self.compose(state)))
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
message("Items fadeout curve: ")
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
state = self.getValue(items[k])
message(string.format("Item %u: %s", getItemNumber(items[k]), self.compose(state)))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
if ajustingValue then
state = round((state+ajustingValue), 3)
if state >= 1 then
state = 1
message("Right curve boundary. ")
elseif state <= -1 then
state = -1
message("Left curve boundary. ")
end
else
state = 0.00
message("Reset to center curve. ")
end
self.setValue(items, state)
 state = self.getValue(items)
message(string.format("Item %u fadeout curve %s", getItemNumber(items), self.compose(state)))
end
return message
end

-- Fadein automatic length
local fadeinAutoLenProperty = {}
registerProperty(fadeinAutoLenProperty, "itemLayout")

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
message("Items automatic fadein length state: ")
for k = 1, #items do
local state = self.getValue(items[k])
if state >= 0 then
message(("Item %u length in %s ms"):format(getItemNumber(items[k]), state))
else
message(("Item %u automatic fadein off"):format(getItemNumber(items[k])))
end
if k < #items then
message(", ")
end
end
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
message("Items automatic fadein lengths state: ")
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
state = self.getValue(items[k])
if state >= 0 then
message(("item %u %s ms"):format(getItemNumber(items[k]), round(state, 3)))
else
message(("item %u off"):format(getItemNumber(items[k])))
end
if k < #items then
message(", ")
end
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
 state = self.getValue(items)
if state >= 0 then
message(string.format("Item %u automatic fadein length %s ms", getItemNumber(items), round(state, 3)))
else
message(string.format("Item %u automatic fadein off", getItemNumber(items)))
end
end
return message
end

-- Automatic fadeout length methods
local fadeoutAutoLenProperty = {}
registerProperty(fadeoutAutoLenProperty, "itemLayout")

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
message("Items automatic fadeout length state: ")
for k = 1, #items do
local state = self.getValue(items[k])
if state >= 0 then
message(("Item %u length in %s ms"):format(getItemNumber(items[k]), state))
else
message(("Item %u automatic fadein off"):format(getItemNumber(items[k])))
end
if k < #items then
message(", ")
end
end
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
message("Items automatic fadeout lengths state: ")
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
state = self.getValue(items[k])
if state >= 0 then
message(("item %u %s ms"):format(getItemNumber(items[k]), round(state, 3)))
else
message(("item %u off"):format(getItemNumber(items[k])))
end
if k < #items then
message(", ")
end
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
 state = self.getValue(items)
if state >= 0 then
message(string.format("Item %u automatic fadeout length %s ms", getItemNumber(items), round(state, 3)))
else
message(string.format("Item %u automatic fadeout off", getItemNumber(items)))
end
end
return message
end

-- Take volume methods
local takeVolumeProperty = {}
registerProperty(takeVolumeProperty, "takeLayout")

function takeVolumeProperty.getValue(item)
return reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_VOL")
end

function  takeVolumeProperty.setValue(item, value)
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
for k = 1, #items do
local state = self.getValue(items[k])
message(string.format("take of item %u in ", getItemNumber(items[k])))
message(string.format("%s db", numtodecibels(state)))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
message(string.format("Item %u current take volume %s db", getItemNumber(items), numtodecibels(state)))
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
message("takes volume: ")
for k = 1, #items do
if action == true then
local state = self.getValue(items[k])
if state < decibelstonum(12.0) then
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
local state = self.getValue(items[k])
message(string.format("Take of item %u in ", getItemNumber(items[k])))
message(string.format("%s db", numtodecibels(state)))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
if action == true then
if state < decibelstonum(12.0) then
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
 state = self.getValue(items)
message(string.format("Item %u current take volume %s db", getItemNumber(items), numtodecibels(state)))
end
return message
end


-- Take pan methods
local takePanProperty = {}
registerProperty(takePanProperty, "takeLayout")

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
message("items takes pan state: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(string.format("take of item %u in ", getItemNumber(items[k])))
message(string.format("%s", numtopan(state)))
if k < #items then
message(", ")
end
end
else
message(string.format("Item %u current take pan ", getItemNumber(items)))
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
message("items takes pan: ")
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
state = self.getValue(items[k], "D_PAN")
message(string.format("take of item %u in ", getItemNumber(items[k])))
message(string.format("%s", numtopan(state)))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
if ajustingValue then
state = round((state+ajustingValue), 3)
if state >= 1 then
state = 1
message("Right boundary. ")
elseif state <= -1 then
state = -1
message("Left boundary. ")
end
else
state = 0
end
self.setValue(items, state)
state = self.getValue(items)
message(string.format("Item %u current take pan %s", getItemNumber(items), numtopan(state)))
end
return message
end

-- Take channel mode methods
local takeChannelModeProperty = {}
 registerProperty(takeChannelModeProperty, "takeLayout")
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
message:initType(config.getinteger("typeLevel", 1), "Adjust this property to choose the desired channel mode for active take of selected item.", "Adjustable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if all items have the same value. Otherwise, the channel mode state will be set to "%s", then will enumerate this.', self.states[0]), 1)
end
if type(items) == "table" then
message("Items active takes channel mode state: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(string.format("take of item %u %s", getItemNumber(items[k]), self.states[state]))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
message(string.format("Item %u current take channel mode %s", getItemNumber(items), self.states[state]))
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
else
return "This property adjustable only."
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
end
message(string.format("Set all items active takes channel mode to %s.", self.states[state]))
for k = 1, #items do
self.setValue(items[k], state)
end
else
message(string.format("Set all items channel mode to %s.", self.states[0]))
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
end
self.setValue(items, state)
message(string.format("Item %u current take channel mode %s", getItemNumber(items), self.states[self.getValue(items)]))
end
return message
end


-- Take playrate methods
local takePlayrateProperty = {}
registerProperty(takePlayrateProperty, "takeLayout")

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
message("Takes playrate state: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(string.format("take of item %u in ", getItemNumber(items[k])))
message(string.format("%s", round(state, 3)))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
message(string.format("Item %u current take playrate %s", getItemNumber(items), round(state, 3)))
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
message("Items takes playrate state: ")
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
state = self.getValue(items[k])
message(("take of item %u %s"):format(getItemNumber(items[k]), round(state, 3)))
if k < #items then
message(", ")
end
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
 state = self.getValue(items)
message(string.format("Item %u current take playrate %s", getItemNumber(items), round(state, 3)))
end
return message
end

-- Preserve pitch when playrate changes methods
local preserveTakePitchProperty = {}
 registerProperty( preserveTakePitchProperty, "takeLayout")
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
message("Items takes preserve pitch when playrate changes state: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(string.format("item %u ", getItemNumber(items[k])))
message(self.states[state])
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
message(string.format("item %u current take pitch %s when playrate changes", getItemNumber(items), self.states[state]))
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
message("switching off the preserving for all items.")
elseif preservedItems < notpreservedItems then
ajustingValue = 1
message("switching on the preserving for all items.")
else
ajustingValue = 0
message("switching off the preserving for all items.")
end
for k = 1, #items do
self.setValue(items[k], ajustingValue)
end
else
local state = self.getValue(items)
if state == 1 then
state = 0
else
state = 1
end
self.setValue(items, state)
state = self.getValue(items)
message(string.format("Item %u current take pitch %s when playrate changes", getItemNumber(items), self.states[state]))
end
return message
end

-- Take pitch methods
local takePitchProperty = {}
registerProperty(takePitchProperty, "takeLayout")

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
message("Takes pitch state: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(string.format("take of item %u in ", getItemNumber(items[k])))
message(string.format("%s", self.compose(state)))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
message(string.format("Item %u current take pitch %s", getItemNumber(items), self.compose(state)))
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
message("Items takes pitch state: ")
for k = 1, #items do
local state = self.getValue(items[k])
if action == true or action == false then
state = state+ajustingValue
else
state = ajustingValue
end
self.setValue(items[k], state)
state = self.getValue(items[k])
message(("take of item %u %s"):format(getItemNumber(items[k]), self.compose(state)))
if k < #items then
message(", ")
else
message(" semitones")
end
end
else
local state = self.getValue(items)
if action == true or action == false then
state = state+ajustingValue
else
state = ajustingValue
end
self.setValue(items, state)
 state = self.getValue(items)
message(string.format("Item %u current take pitch %s", getItemNumber(items), self.compose(state)))
end
return message
end

-- Pitch shifter methods
local takePitchShifterProperty = {}
registerProperty(takePitchShifterProperty, "takeLayout")
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
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if all items have the same value. Otherwise, the pitch shifter state will be set to "%s", then will enumerate this.', self.states[-1]), 1)
end
message:addType(string.format(" Perform this property to reset the value to %s.", self.states[-1]), 1)
if type(items) == "table" then
message("Items active takes pitch shifter state: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(string.format("take of item %u %s", getItemNumber(items[k]), self.states[state]))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
message(string.format("Item %u current take pitch shifter %s", getItemNumber(items), self.states[state]))
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
state = bytewords.makeLong(bytewords.getLoWord(state), i)
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
state = bytewords.makeLong(bytewords.getLoWord(state), i)
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
message(string.format("Set all items active takes pitch shifter to %s.", self.states[state]))
for k = 1, #items do
self.setValue(items[k], state)
end
else
local state = self.getValue(items)
if action == true then
if state >= 0 then
for i = bytewords.getHiWord(state)+ajustingValue, #self.states+1 do
if self.states[bytewords.makeLong(bytewords.getLoWord(state), i)] then
state = bytewords.makeLong(bytewords.getLoWord(state), i)
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
state = bytewords.makeLong(bytewords.getLoWord(state), i)
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
message(string.format("Item %u current take pitch shifter %s", getItemNumber(items), self.states[self.getValue(items)]))
end
return message
end

-- Active shifter mode methods
local takePitchShifterModeProperty = {}
registerProperty(takePitchShifterModeProperty, "takeLayout")
takePitchShifterModeProperty.states = setmetatable({[-1] = "project default"},
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
message:addType(string.format(" If the group of items has been selected, the value will enumerate only if all items have the same value. Otherwise, the pitch shifter mode will be set to first setting for this shifter, then will enumerate this. Please note: if one of selected items will has pitch shifter set to %s, the adjusting of this property will not available until all shifters will not set to any different.", takePitchShifterProperty.states[-1]), 1)
end
if type(items) == "table" then
message("Items active takes pitch shifter modes: ")
for k = 1, #items do
local state = self.getValue(items[k])
message(string.format("take of item %u %s", getItemNumber(items[k]), self.states[state]))
if k < #items then
message(", ")
end
end
else
local state = self.getValue(items)
message(string.format("Item %u current take sshifter mode %s", getItemNumber(items), self.states[state]))
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
return string.format("The shifter of take item %u is set to %s. Set any otherwise  shifter on this item before  setting up the shifter mode.", getItemNumber(items[k]), takePitchShifterProperty.states[-1])
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
message(string.format("Set all items active takes pitch shifter modes to %s.", self.states[state]))
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
message(string.format("Item %u current take shifter mode %s", getItemNumber(items), self.states[self.getValue(items)]))
end
return message
end

return parentLayout[sublayout]