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


-- Reading the some config which will be used everyhere
local multiSelectionSupport = config.getboolean("multiSelectionSupport", true)

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

-- We should obey the configuration to report the take's name
local function getItemID(item)
local message = initOutputMessage()
local color = reaper.GetDisplayedMediaItemColor(item)
if color ~= 0 then
message(colors:getName(reaper.ColorFromNative(color)).." ")
end
local idmsg = "Item %u"
if #message > 0 then
idmsg = idmsg:lower()
end
message(idmsg:format(getItemNumber(item)))
return message:extract()
end

local function getTakeID(item)
local message = initOutputMessage()
local cfg = config.getboolean("reportName", false)
if cfg == true then
local retval, name = reaper.GetSetMediaItemTakeInfo_String(reaper.GetActiveTake(item), "P_NAME", "", false)
if retval then
-- Stupid REAPER adds the file extensions to the take's name!
if config.getboolean("clearFileExts", true) == true then
name = name:gsub("(.+)[.](%w+)$", "%1")
end
message(("take %s"):format(name))
else
message(("take %u"):format(getTakeNumber(item)))
end
else
message(("take %u"):format(getTakeNumber(item)))
end
local color = reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "I_CUSTOMCOLOR")
if color ~= 0 then
message.msg = colors:getName(reaper.ColorFromNative(color)).." "..message.msg:gsub("^%w", string.lower)
end
return message:extract()
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
message(string.format("items from %s ", getItemID(items[k]):gsub("Item ", "")))
elseif state == prevState and state ~= nextState then
message(string.format("to %s ", getItemID(items[k]):gsub("Item ", "")))
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
message(string.format("%s ", getItemID(items[k])))
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
message(string.format("takes from %s of %s ", getTakeID(items[k]):gsub("take ", ""), getItemID(items[k])))
elseif (state == prevState and state ~= nextState) and (takeIDX == prevTakeIDX and takeIDX ~= nextTakeIDX) then
message(string.format("to %s of %s ", getTakeID(items[k]):gsub("take ", ""), getItemID(items[k])))
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
message(string.format("%s of %s ", getTakeID(items[k]), getItemID(items[k])))
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


local function getSelectedItemAtCursor()
if type(items) == "table" then
for _, item in ipairs(items) do
local itemPosition, takePlayrate, itemLength = reaper.GetMediaItemInfo_Value(item, "D_POSITION"), reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE"), reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
if reaper.GetCursorPosition() >= itemPosition and reaper.GetCursorPosition() <= (itemPosition+(itemLength/takePlayrate)) then
return item
end
end
else
local itemPosition, takePlayrate, itemLength = reaper.GetMediaItemInfo_Value(items, "D_POSITION"), reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(items), "D_PLAYRATE"), reaper.GetMediaItemInfo_Value(items, "D_LENGTH")
if reaper.GetCursorPosition() >= itemPosition and reaper.GetCursorPosition() <= (itemPosition+(itemLength/takePlayrate)) then
return items
end
end
end

local function pos_relativeToGlobal(item, rel)
local itemPosition, takePlayrate = reaper.GetMediaItemInfo_Value(item, "D_POSITION"), reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE")
return (itemPosition+rel)/takePlayrate
end

local function pos_globalToRelative(item)
local itemPosition, takePlayrate = reaper.GetMediaItemInfo_Value(item, "D_POSITION"), reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(item), "D_PLAYRATE")
return (reaper.GetCursorPosition()-itemPosition)*takePlayrate
end



-- global pseudoclass initialization
local parentLayout = initLayout("Item%s properties")

-- the function which gives green light to call any method from this class
function parentLayout.canProvide()
return (reaper.CountSelectedMediaItems(0) > 0)
end

-- sublayouts
--visual properties
parentLayout:registerSublayout("visualLayout", " visual")

--Item properties
-- The second parameter is empty string cuz the parent layout's name and this sublayout's name is identical
parentLayout:registerSublayout("itemLayout", "")

-- Current take properties
parentLayout:registerSublayout("takeLayout", " current take")

-- Stretch markers
parentLayout:registerSublayout("stretchMarkersLayout", " take stretch markers")

-- Take markers
-- Currently is not finaly written, so  now it is commented at this time.
--parentLayout:registerSublayout("takeMarkersLayout", " take markers")


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
message:initType("Perform this action to rename selected item current take.", "performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, new name will applied to selected active takes of selected items.", 1)
end
if type(items) == "table" then
message("Takes names: ")
for k = 1, #items do
local name = self.getValue(items[k])
message(string.format("Take of %s ", getItemID(items[k])))
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
message(string.format("%s current take name %s", getItemID(items), name))
else
message(string.format("%s current take unnamed", getItemID(items)))
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
local aState, answer = reaper.GetUserInputs(string.format("Change active take name for item %u", getItemID(items)), 1, 'Type new item name:', name)
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
message:initType("Toggle this property to lock or unlock selected item for any changes.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the lock state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items locking: ")
message(composeMultipleItemMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("%s %s", getItemID(items), self.states[state]))
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
self.setValue(items, utils.nor(self.getValue(items)))
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
message:initType("Adjust this property to set the desired volume value for selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" Perform this property to input custom volume value.", 1)
if type(items) == "table" then
message("items volume:")
message(composeMultipleItemMessage(self.getValue, representation.db))
else
local state = self.getValue(items)
message(string.format("%s volume %s", getItemID(items), representation.db[state]))
end
return message
end

function itemVolumeProperty:set(action)
local message = initOutputMessage()
local ajustStep = config.getinteger("dbStep", 0.1)
local maxDBValue = config.getinteger("maxDBValue", 12.0)
if type(items) == "table" then
local retval, answer = nil
if action == nil then
retval, answer = reaper.GetUserInputs(string.format("Volume for %u selected items", #items), 1, prepareUserData.db.formatCaption, representation.db[self.getValue(items[1])])
if not retval then
return "Canceled"
end
end
for k = 1, #items do
local state = self.getValue(items[k])
if action == true then
if state < utils.decibelstonum(maxDBValue) then
self.setValue(items[k], utils.decibelstonum(utils.numtodecibels(state)+ajustStep))
else
self.setValue(items[k], utils.decibelstonum(maxDBValue))
end
elseif action == false then
if utils.numtodecibels(state) ~= "-inf" then
self.setValue(items[k], utils.decibelstonum(utils.numtodecibels(state, true)-ajustStep))
else
self.setValue(items[k], 0)
end
else
state = prepareUserData.db.process(answer, state)
if state then
self.setValue(items[k], state)
end
end
end
message(self:get())
else
local state = self.getValue(items)
if action == true then
if state < utils.decibelstonum(maxDBValue) then
self.setValue(items, utils.decibelstonum(utils.numtodecibels(state)+ajustStep))
else
self.setValue(items, utils.decibelstonum(maxDBValue))
message("maximum volume.")
end
elseif action == false then
if utils.numtodecibels(state) ~= "-inf" then
self.setValue(items, utils.decibelstonum(utils.numtodecibels(state)-ajustStep))
else
self.setValue(items, 0)
message("Minimum volume.")
end
else
local retval, answer = reaper.GetUserInputs(string.format("Volume for %s", getItemID(items)), 1, prepareUserData.db.formatCaption, representation.db[self.getValue(items)])
if not retval then
return "Canceled"
end
state = prepareUserData.db.process(answer, state)
if state then
self.setValue(items, state)
else
reaper.ShowMessageBox("Couldn't convert the data to appropriate value.", "Properties Ribbon error", 0)
return ""
end
end
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
message:initType("Toggle this property to mute or unmute selected item.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the mute state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items mute:")
message(composeMultipleItemMessage(function(item) return reaper.GetMediaItemInfo_Value(item, "B_MUTE") end, self.states))
else
local state = reaper.GetMediaItemInfo_Value(items, "B_MUTE")
message(string.format("%s %s", getItemID(items), self.states[state]))
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
local state = utils.nor(reaper.GetMediaItemInfo_Value(items, "B_MUTE"))
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
message:initType("Toggle this property to loop or unloop the source of selected item.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the loop source state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items source loop: ")
message(composeMultipleItemMessage(function(item) return reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC") end, self.states))
else
local state = reaper.GetMediaItemInfo_Value(items, "B_LOOPSRC")
message(string.format("%s source %s", getItemID(items), self.states[state]))
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
local state = utils.nor(reaper.GetMediaItemInfo_Value(items, "B_LOOPSRC"))
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
message:initType("Toggle this property to define the playing all takes of selected item.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the playing all takes state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items all takes playing: ")
message(composeMultipleItemMessage(function(item) return reaper.GetMediaItemInfo_Value(item, "B_ALLTAKESPLAY") end, self.states))
else
local state = reaper.GetMediaItemInfo_Value(items, "B_ALLTAKESPLAY")
message(string.format("%s all takes %s", getItemID(items), self.states[state]))
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
local state = utils.nor(reaper.GetMediaItemInfo_Value(items, "B_ALLTAKESPLAY"))
reaper.SetMediaItemInfo_Value(items, "B_ALLTAKESPLAY", state)
end
message(self:get())
return message
end



-- timebase methods
local timebaseProperty = {}
 parentLayout.itemLayout:registerProperty(timebaseProperty)
timebaseProperty.states = setmetatable({
[0] = "track or project default",
[1] = "time",
[2] = "beats (position, length, rate)",
[3] = "beats (position only)"
}, {
__index = function(self, key)
return string.format("Unknown item timebase mode %u, please report about via Github issue.", key)
end
})

function timebaseProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to choose the desired time base mode for selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if these items have the same value. Otherwise, the timebase state will be set to "%s", then will enumerate this.', self.states[0]), 1)
end
if type(items) == "table" then
message("Items timebase: ")
message(composeMultipleItemMessage(function(item) return reaper.GetMediaItemInfo_Value(item, "C_BEATATTACHMODE") end, self.states, 1))
else
local state = reaper.GetMediaItemInfo_Value(items, "C_BEATATTACHMODE")
message(string.format("%s timebase %s", getItemID(items), self.states[state+1]))
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
message:initType(string.format('Toggle this property to enable or disable auto-stretch selected item at project tempo when the item timebase is set to "%s".', timebaseProperty.states[2]), "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the auto-stretch state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Items Auto-stretch at project tempo: ")
message(composeMultipleItemMessage(function(item) return reaper.GetMediaItemInfo_Value(item, "C_AUTOSTRETCH") end, self.states))
else
local state = reaper.GetMediaItemInfo_Value(items, "C_AUTOSTRETCH")
message(string.format("%s auto-stretch at project tempo %s", getItemID(items), self.states[state]))
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
local state = utils.nor(reaper.GetMediaItemInfo_Value(items, "C_AUTOSTRETCH"))
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
message:initType("Adjust this property to set the desired snap offset time.", "Adjustable, performable")
if multiSelectionSupport == ttrue then
message:addType(" If the group of items has selected, the relative depending on previous value will be set for each selected item.", 1)
end
message:addType(" Perform this property to remove snap offset time.", 1)
if type(items) == "table" then
message("Items snap offset:")
message(composeMultipleItemMessage(self.getValue, representation.timesec))
else
local state = self.getValue(items)
message(string.format("%s snap offset %s", getItemID(items), representation.timesec[utils.round(state, 3)]))
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
message:initType("Adjust this property to set up the desired group number for selected item.", "Adjustable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the group will be set to 1 first, then will begins enumerate up of.", 1)
end
if type(items) == "table" then
message("Items group numbers: ")
message(composeMultipleItemMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(("%s %s"):format(getItemID(items), self.states[state]))
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
message(("%s  set to group %u"):format(getItemID(items), self.getValue(items)))
elseif state+ajustingValue == 0 then
self.setValue(items, 0)
message(("%s not in a group"):format(getItemID(items)))
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
message:initType("Adjust this property to choose the desired shape mode for fadein in selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if these items have the same value. Otherwise, the shape state will be set to "%s", then will enumerate this.', self.states[0]), 1)
end
if type(items) == "table" then
message("Items fadein shape: ")
message(composeMultipleItemMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("%s fadein shape %s", getItemID(items), self.states[state]))
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
message:initType("Adjust this property to setup desired fadein length for selected item.", "Adjustable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" Perform this property to reset the length value to default in preferences.", 1)
if type(items) == "table" then
message("Items fadein length: ")
message(composeMultipleItemMessage(self.getValue, representation.timesec))
else
message(("%s fadein length %s"):format(getItemID(items), representation.timesec[self.getValue(items)]))
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
ajustingValue = utils.round(tonumber(str), 3)
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
return ("%s%% to the right"):format(utils.numtopercent(key))
elseif key < 0 then
return ("%s%% to the left"):format(-utils.numtopercent(key))
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
message:initType("Adjust this property to set the desired fadein curvature for selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" Perform this property to reset the value to 0.00.", 1)
if type(items) == "table" then
message("Items fadein curve: ")
message(composeMultipleItemMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(("%s fadein curve %s"):format(getItemID(items), self.states[state]))
end
return message
end

function  fadeinDirProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("percentStep", 1)
if action == true then
ajustingValue = utils.percenttonum(ajustingValue)
elseif action == false then
ajustingValue = -utils.percenttonum(ajustingValue)
else
message("reset, ")
ajustingValue = nil
end
if type(items) == "table" then
for k = 1, #items do
local state = self.getValue(items[k])
if ajustingValue then
state = utils.round((state+ajustingValue), 3)
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
state = utils.round((state+ajustingValue), 3)
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
message:initType("Adjust this property to choose the desired shape mode for fadeout in selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if these items have the same value. Otherwise, the shape state will be set to "%s", then will enumerate this.', self.states[0]), 1)
end
if type(items) == "table" then
message("Items fadeout shape: ")
message(composeMultipleItemMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("%s fadeout shape %s", getItemID(items), self.states[state]))
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
message:initType("Adjust this property to setup desired fadeout length for selected item.", "Adjustable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" Perform this property to reset the length value to default in preferences.", 1)
if type(items) == "table" then
message("Items fadeout length: ")
message(composeMultipleItemMessage(self.getValue, representation.timesec))
else
message(("%s fadeout length %s"):format(getItemID(items), representation.timesec[self.getValue(items)]))
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
ajustingValue = utils.round(tonumber(str), 3)
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
message:initType("Adjust this property to set the desired fadeout curvature for selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" Perform this property to reset the value to flat.", 1)
if type(items) == "table" then
message("Items fadeout curve: ")
message(composeMultipleItemMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(("%s fadeout curve %s"):format(getItemID(items), self.states[state]))
end
return message
end

function  fadeoutDirProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("percentStep", 1)
if action == true then
ajustingValue = utils.percenttonum(ajustingValue)
elseif action == false then
ajustingValue = -utils.percenttonum(ajustingValue)
else
message("reset, ")
ajustingValue = nil
end
if type(items) == "table" then
for k = 1, #items do
local state = self.getValue(items[k])
if ajustingValue then
state = utils.round((state+ajustingValue), 3)
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
state = utils.round((state+ajustingValue), 3)
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
message:initType("Adjust this property to setup desired automatic fadein length for selected item.", "Adjustable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" If you want to switch off automatic fadein, set the value less than 0.000 MS. Perform this property to reset the length value to default in preferences.", 1)
if type(items) == "table" then
message("Items automatic fadein length: ")
message(composeMultipleItemMessage(self.getValue, setmetatable({}, {__index = function(self, state)
if state >= 0 then
return representation.timesec[state]
else
return "automatic fadein off"
end
end
})))
else
local state = self.getValue(items)
if state >= 0 then
message(("%s automatic fadein length %s"):format(getItemID(items), representation.timesec[state]))
else
message(("%s automatic fadein off"):format(getItemID(items)))
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
ajustingValue = utils.round(tonumber(str), 3)
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
message:initType("Adjust this property to setup desired automatic fadeout length for selected item.", "Adjustable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item of.", 1)
end
message:addType(" If you want to switch off automatic fadeout, set the value less than 0.000 MS. Perform this property to reset the length value to default in preferences.", 1)
if type(items) == "table" then
message("Items automatic fadeout length: ")
message(composeMultipleItemMessage(self.getValue, setmetatable({}, {__index = function(self, state)
if state >= 0 then
return representation.timesec[state]
else
return "automatic fadeout off"
end
end
})))
else
local state = self.getValue(items)
if state >= 0 then
message(("%s automatic fadeout length %s"):format(getItemID(items), representation.timesec[state]))
else
message(("%s automatic fadeout off"):format(getItemID(items)))
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
ajustingValue = utils.round(tonumber(str), 3)
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
message:initType("Adjust this property to switch the desired  active take of selected item.", "Adjustable, performable")
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
message(string.format("items from %s ", getItemID(items[k])))
elseif IDX == prevIDX and IDX ~= nextIDX then
message(string.format("to %s ", getItemID(items[k])))
message(string.format("%u, %s", getTakeNumber(items[k]), currentTakeNameProperty.getValue(items[k])))
if k < #items then
message(", ")
end
elseif IDX == prevIDX and IDX == nextIDX then
else
message(string.format("%s ", getItemID(items[k])))
message(string.format("%u, %s", getTakeNumber(items[k]), currentTakeNameProperty.getValue(items[k])))
if k < #items then
message(", ")
end
end
end
else
local state = self.getValue(items)
local retval, name = reaper.GetSetMediaItemTakeInfo_String(state, "P_NAME", "", false)
message(string.format("%s %s, %s", getItemID(items), getTakeID(items), name))
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
message:initType("Adjust this property to set the desired volume value for active take of selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item take of.", 1)
end
message:addType(" Perform this property to input custom volume value or some proposed commands.", 1)
if type(items) == "table" then
message("Takes volume: ")
message(composeMultipleTakeMessage(self.getValue, representation.db))
else
local state = self.getValue(items)
message(string.format("%s %s volume %s", getItemID(items), getTakeID(items), representation.db[state]))
end
return message
end

function takeVolumeProperty:set(action)
local message = initOutputMessage()
local ajustStep = config.getinteger("dbStep", 0.1)
local maxDBValue = config.getinteger("maxDBValue", 12.0)
if type(items) == "table" then
local retval, answer = nil
if action == nil then
retval, answer = reaper.GetUserInputs(string.format("Volume for active takes of %u selected items", #items), 1, prepareUserData.db.formatCaption..'normalize (or n) - will normalize items to maximum volume per every active take of selected item.\nnormalize common gain (or ncg or nc) - will normalize active takes of selected items to common gain.', representation.db[self.getValue(items[1])])
if not retval then
return "Canceled"
end
local normCmdExecuted = false
if prepareUserData.basic(answer):find("^[n]%w*[c]%w*[g]?%w*") then
message("Normalizing item takes to common gain, ")
reaper.Main_OnCommand(40254, 0)
normCmdExecuted = true
elseif prepareUserData.basic(answer):find("^[n]") then
message("Normalize items takes volume")
reaper.Main_OnCommand(40108, 0)
normCmdExecuted = true
end
end
for k = 1, #items do
if action == true then
local state = self.getValue(items[k])
if state < utils.decibelstonum(maxDBValue) then
state = utils.decibelstonum(utils.numtodecibels(state)+ajustStep)
else
state = utils.decibelstonum(maxDBValue)
end
self.setValue(items[k], state)
elseif action == false then
local state = self.getValue(items[k])
if utils.numtodecibels(state) ~= -150 then
state = utils.decibelstonum(utils.numtodecibels(state)-ajustStep)
else
state = 0
end
self.setValue(items[k], state)
elseif action == nil then
if not normCmdExecuted then
local state = self.getValue(items[k])
state = prepareUserData.db.process(answer, state)
if state then
self.setValue(items[k], state)
end
end
end
end
else
local state = self.getValue(items)
if action == true then
if state < utils.decibelstonum(maxDBValue) then
state = utils.decibelstonum(utils.numtodecibels(state)+ajustStep)
else
state = utils.decibelstonum(maxDBValue)
message("maximum volume. ")
end
self.setValue(items, state)
elseif action == false then
if utils.numtodecibels(state) ~= -150.00 then
state = utils.decibelstonum(utils.numtodecibels(state)-ajustStep)
else
state = 0
message("Minimum volume. ")
end
self.setValue(items, state)
else
local retval, answer = reaper.GetUserInputs(string.format("Volume for %s of %s", getTakeID(items), getItemID(items)), 1, prepareUserData.db.formatCaption..'normalize (or n) - will normalize items to maximum volume for active take of selected item.', representation.db[self.getValue(items)])
if not retval then
return "Canceled"
end
if prepareUserData.basic(answer):find("^[n]") then
message("Normalize item take volume")
reaper.Main_OnCommand(40108, 0)
else
state = prepareUserData.db.process(answer, state)
if state then
self.setValue(items, state)
else
reaper.ShowMessageBox("Couldn't convert the data to appropriate value.", "Properties Ribbon error", 0)
return ""
end
end
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
message:initType("Adjust this property to set the desired current take pan value for selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item active take of.", 1)
end
message:addType(" Perform this property to input custom take pan value.", 1)
if type(items) == "table" then
message("Takes pan: ")
message(composeMultipleTakeMessage(self.getValue, representation.pan))
else
message(string.format("%s %s pan ", getItemID(items), getTakeID(items)))
local state = self.getValue(items)
message(string.format("%s", representation.pan[state]))
end
return message
end

function takePanProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("percentStep", 1)
if action == true then
ajustingValue = utils.percenttonum(ajustingValue) or 0.01
elseif action == false then
ajustingValue = -utils.percenttonum(ajustingValue) or -0.01
end
if type(items) == "table" then
local retval, answer = nil
if action == nil then
retval, answer = reaper.GetUserInputs(string.format("Pan for active takes of %u selected items", #items), 1, prepareUserData.pan.formatCaption, representation.pan[self.getValue(items[1])])
if not retval then
return "Canceled"
end
end
for k = 1, #items do
local state = self.getValue(items[k])
if action == true or action == false then
state = utils.round((state+ajustingValue), 3)
if state >= 1 then
state = 1
elseif state <= -1 then
state = -1
end
else
state = prepareUserData.pan.process(answer, state)
end
if state then
self.setValue(items[k], state)
end
end
else
local state = self.getValue(items)
if action == true or action == false then
state = utils.round((state+ajustingValue), 3)
if state > 1 then
state = 1
message("Right boundary. ")
elseif state < -1 then
state = -1
message("Left boundary. ")
end
else
local retval, answer = reaper.GetUserInputs(string.format("Pan for %s of %s", getTakeID(items), getItemID(items)), 1, prepareUserData.pan.formatCaption, representation.pan[state])
if not retval then
return "Canceled"
end
state = prepareUserData.pan.process(answer, state)
end
if state then
self.setValue(items, state)
else
reaper.ShowMessageBox("Couldn't convert the data to appropriate value.", "Properties Ribbon error", 0)
return ""
end
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
message:initType("Toggle this property to set the phase polarity for take of selected item.", "toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the phase polarity state will be set to oposite value depending of moreness takes of items with the same value.", 1)
end
if type(items) == "table" then
message("Takes phase: ")
message(composeMultipleTakeMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("%s %s phase %s", getItemID(items), getTakeID(items), self.states[state]))
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
self.setValue(items, utils.nor(self.getValue(items)))
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
message:initType("Adjust this property to choose the desired channel mode for active take of selected item.", "Adjustable, toggleable")
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
message(string.format("%s %s channel mode %s", getItemID(items), getTakeID(items), self.states[state]))
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
message:initType("Adjust this property to set the desired playrate value for active take of selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item take of.", 1)
end
message:addType(" Perform this property to reset  playrate to 1 X for.", 1)
if type(items) == "table" then
message("Takes playrate: ")
message(composeMultipleTakeMessage(self.getValue, representation.playrate))
else
local state = self.getValue(items)
message(string.format("%s %s playrate %s", getItemID(items), getTakeID(items), representation.playrate[state]))
end
return message
end

-- I still didn't came up with any algorhythm for encounting the needed step rate, so we will use the REAPER actions.
-- Seems it's the lightest method for all time of :)
function takePlayrateProperty:set(action)
local message = initOutputMessage()
local actions= {
{[false]=40520,[true]=40519},
{[false]=40518, [true]=40517}
}
if action == true or action == false then
reaper.Main_OnCommand(actions[config.getinteger("rateStep", 1)][action], 0)
else
message("Reset,")
reaper.Main_OnCommand(40652, 0)
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
message:initType("Toggle this property to set the switch status of preserving current take pitch when play rate changes of selected item.", "Toggleable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the preserve state will be set to oposite value depending of moreness items with the same value.", 1)
end
if type(items) == "table" then
message("Takes preserve pitch when playrate changes: ")
message(composeMultipleTakeMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("%s %s pitch %s when playrate changes", getItemID(items), getTakeID(items), self.states[state]))
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
self.setValue(items, utils.nor(self.getValue(items)))
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

function takePitchProperty:get()
local message = initOutputMessage()
message:initType("Adjust this property to set the desired pitch value for active take of selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(" If the group of items has been selected, the relative of previous value will be applied for each item take of.", 1)
end
message:addType(" Perform this property to reset  pitch to 0.", 1)
if type(items) == "table" then
message("Takes pitch: ")
message(composeMultipleTakeMessage(self.getValue, representation.pitch))
else
local state = self.getValue(items)
message(string.format("%s %s pitch %s", getItemID(items), getTakeID(items), representation.pitch[state]))
end
return message
end

function takePitchProperty:set(action)
local message = initOutputMessage()
local ajustingValue = config.getinteger("pitchStep", 1)
if action == false then
ajustingValue = -ajustingValue
end
if type(items) == "table" then
local retval, answer = nil
if action == nil then
retval, answer = reaper.GetUserInputs(string.format("Pitch for active takes of %u selected items", #items), 1, prepareUserData.pitch.formatCaption, representation.pitch[self.getValue(items[1])]:gsub("Minus ", "-"):gsub(",", ""))
if not retval then
return "Canceled"
end
end
for k = 1, #items do
local state = self.getValue(items[k])
if action == true or action == false then
state = state+ajustingValue
else
state = prepareUserData.pitch.process(answer, state)
end
if state then
self.setValue(items[k], state)
end
end
else
local state = self.getValue(items)
if action == true or action == false then
state = state+ajustingValue
else
local retval, answer = reaper.GetUserInputs(string.format("Pitch for %s of %s", getTakeID(items), getItemID(items)), 1, prepareUserData.pitch.formatCaption, representation.pitch[state]:gsub("Minus ", "-"):gsub(",", ""))
if not retval then
return "Canceled"
end
state = prepareUserData.pitch.process(answer, state)
end
if state then
self.setValue(items, state)
else
reaper.ShowMessageBox("Couldn't convert the data to appropriate value.", "Properties Ribbon error", 0)
return ""
end
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
message:initType("Adjust this property to choose the desired pitch shifter (i.e., pitch algorhythm) for active take of selected item.", "Adjustable, performable")
if multiSelectionSupport == true then
message:addType(string.format(' If the group of items has been selected, the value will enumerate only if selected items have the same value. Otherwise, the pitch shifter state will be set to "%s", then will enumerate this.', self.states[-1]), 1)
end
message:addType(string.format(" Perform this property to reset the value to %s.", self.states[-1]), 1)
if type(items) == "table" then
message("Takes pitch shifter: ")
message(composeMultipleTakeMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("%s %s pitch shifter %s", getItemID(items), getTakeID(items), self.states[state]))
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
message:initType("Adjust this property to choose the desired mode for active shifter  of active take on selected item.", "Adjustable")
if multiSelectionSupport == true then
message:addType(string.format(" If the group of items has been selected, the value will enumerate only if selected items have the same value. Otherwise, the pitch shifter mode will be set to first setting for this shifter, then will enumerate this. Please note: if one of selected items will has pitch shifter set to %s, the adjusting of this property will not available until selected shifters will not set to any different.", takePitchShifterProperty.states[-1]), 1)
end
if type(items) == "table" then
message("Takes pitch shifter modes: ")
message(composeMultipleTakeMessage(self.getValue, self.states))
else
local state = self.getValue(items)
message(string.format("%s %s shifter mode %s", getItemID(items), getTakeID(items), self.states[state]))
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
return string.format("The shifter of take %u %s is set to %s. Set any otherwise  shifter on this take before  setting up the shifter mode.", getTakeNumber(items[k]), getItemID(items[k]), takePitchShifterProperty.states[-1])
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
message:initType("Read this property to get the information about item color. Perform this property to apply composed color in the items category.", "performable")
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
local raw = utils.splitstring(key, "|")
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
message(string.format("%s color %s", getItemID(items), colors:getName(reaper.ColorFromNative(state))))
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
message(string.format("%s colorized to %s", getItemID(items), colors:getName(reaper.ColorFromNative(state))))
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
message:initType("Read this property to get the information about active item take color. Perform this property to apply composed color in the takes category.", "performable")
if multiSelectionSupport == true then
message:addType(" If the group of items have been selected, this color will be applied for selected its active takes.", 1)
end
if type(items) == "table" then
message("Take  color:")
message(composeMultipleTakeMessage(self.getValue, setmetatable({}, {__index = function(self, state) return colors:getName(reaper.ColorFromNative(state)) end})))
else
local state = self.getValue(items)
message(string.format("%s %s color %s", getItemID(items), getTakeID(items), colors:getName(reaper.ColorFromNative(state))))
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
message(string.format("%s %s colorized to %s", getItemID(items), getTakeID(items), colors:getName(reaper.ColorFromNative(state))))
end
else
message("Compose a color in color composer first.")
end
else
message("This property is performable only.")
end
return message
end

-- Stretch markers realisation
local function formStretchMarkerProperties(item)
if not parentLayout.canProvide() then
return
end
for i = 0, reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(item)) do
local stretchMarker = {}
stretchMarker.item = item
stretchMarker.idx = i
stretchMarker.retval, stretchMarker.pos, stretchMarker.srcpos = reaper.GetTakeStretchMarker(reaper.GetActiveTake(item), i)
if stretchMarker.retval ~= -1 then
parentLayout.stretchMarkersLayout:registerProperty({
states = {
[0] = "Jump to ",
[1] = "Pull ",
[2] = "Edit ",
[3] = "Delete "
},
marker = stretchMarker,
get = function (self, shouldSaveAction)
local message = initOutputMessage()
message:initType("Adjust this stretch marker property to choose aproppriate action for. Perform this stretch marker property to either jump to its position or apply chosen earlier action on.", "Adjustable, performable")
if extstate.itemProperties_smrkaction and not shouldSaveAction then
extstate.itemProperties_smrkaction = nil
else
message(self.states[extstate.itemProperties_smrkaction])
end
message(string.format("Stretch marker %u of %s %s", self.marker.idx+1, getItemID(self.marker.item), getTakeID(self.marker.item)))
return message
end,
set = function(self, action)
local message = initOutputMessage()
local maction = extstate.itemProperties_smrkaction or 0
if action == true then
if (maction+1) <= #self.states then
maction = maction+1
extstate.itemProperties_smrkaction = maction
else
message("No more next stretch marker actions. ")
end
elseif action == false then
if (maction-1) >= 0 then
maction = maction-1
extstate.itemProperties_smrkaction = maction
else
message("No more previous stretch marker actions. ")
end
elseif action == nil then
if maction == 1 then
local curpos = reaper.GetCursorPosition()
local itemPosition, takePlayrate, itemLength = reaper.GetMediaItemInfo_Value(self.marker.item, "D_POSITION"), reaper.GetMediaItemTakeInfo_Value(reaper.GetActiveTake(self.marker.item), "D_PLAYRATE"), reaper.GetMediaItemInfo_Value(self.marker.item, "D_LENGTH")
--if curpos >= itemPosition and curpos <= (itemPosition+itemLength) then
reaper.SetTakeStretchMarker(reaper.GetActiveTake(self.marker.item), self.marker.idx, ((curpos-itemPosition)*takePlayrate))
message(self:get())
message("pulled onto new position.")
--else
--return "You're trying to pull the stretch marker which belongs to defined item through out the edges of this item."
--end
elseif maction == 2 then
local curpos = reaper.GetCursorPosition()
reaper.SetEditCurPos(pos_relativeToGlobal(self.marker.item, self.marker.pos), false, false)
reaper.Main_OnCommand(41988, 0)
reaper.SetEditCurPos(curpos, false, false)
setUndoLabel(self:get(true))
return ""
elseif maction == 3 then
message(self:get())
reaper.DeleteTakeStretchMarkers(reaper.GetActiveTake(self.marker.item), self.marker.idx)
message("has been deleted.")
return message
else
reaper.SetEditCurPos(pos_relativeToGlobal(self.marker.item, self.marker.pos), true, true)
message(self.states[0])
end
end
message(self:get(true))
return message
end
})
end
end
end
 
 local function formTakeMarkersProperties(item)
 for i = 0, reaper.GetNumTakeMarkers(reaper.GetActiveTake(item)) do
 local takeMarker = {}
takeMarker.item = item
takeMarker.idx = i
takeMarker.retval, takeMarker.name, takeMarker.color = reaper.GetTakeMarker(reaper.GetActiveTake(item), i)
if takeMarker.retval ~= -1 then
parentLayout.takeMarkersLayout:registerProperty({
marker = takeMarker,
get = function(self)
local message = initOutputMessage()
message:initType("Adjust this take marker property to choose aproppriate action to be performed. Perform this take marker to either jump to its position or to perform chosen earlier action on.", "Adjustable, performable")
message(string.format("%s %s take marker %u", getItemNumber(self.marker.item), getTakeID(self.marker.item), self.marker.idx+1))
if self.marker.color > 0 then
message(string.format(", color %s", colors:getName(reaper.ColorFromNative(self.marker.color))))
end
if self.marker.name then
message(string.format(", %s", self.marker.name))
else
message(", unnamed")
end
return message
end,
set = function(self, action)
return "Doesn't supported yet" 
end
})
end
end
end

-- Main stretch markers actions
local stretchMarkerActionsProperty = {}
parentLayout.stretchMarkersLayout:registerProperty(stretchMarkerActionsProperty)
stretchMarkerActionsProperty.states = {
[1] = "Add stretch marker at cursor",
[2] = "Add stretch markers at time selection",
[3] = "Add stretch marker at cursor and edit",
[4] = "Delete all stretch markers"
}

function stretchMarkerActionsProperty:get(shouldSaveAction)
local message = initOutputMessage()
message:initType("Adjust this property to choose needed action for stretch markers. Perform this property to apply chosen action.", "Adjustable, performable")
if extstate.itemsProperty_smrkaction and not shouldSaveAction then
extstate.itemsProperty_smrkaction = nil
end
local state = extstate.itemsProperty_smrkaction
if not state then
state = 1
end
message(self.states[state])
return message
end

function stretchMarkerActionsProperty:set(action)
local message = initOutputMessage()
local state = extstate.itemsProperty_smrkaction
if not state then
state = 1
end
if action == true then
if (state+1) <= #self.states then
extstate.itemsProperty_smrkaction = state+1
else
message("No more next property values. ")
end
elseif action == false then
if (state-1) > 0 then
extstate.itemsProperty_smrkaction = state-1
else
message("No more previous property values. ")
end
elseif action == nil then
if state == 2 then
local prevMarkersCount = reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(getSelectedItemAtCursor()))
reaper.Main_OnCommand(41843, 0)
local newMarkersCount = reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(getSelectedItemAtCursor()))
if prevMarkersCount < newMarkersCount then
return "Stretch markers added by time selection."
else
return "No stretch markers created."
end
elseif state == 3 then
reaper.Main_OnCommand(41842, 0)
reaper.Main_OnCommand(41988, 0)
elseif state == 4 then
local prevMarkersCount = reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(getSelectedItemAtCursor()))
reaper.Main_OnCommand(41844, 0)
local newMarkersCount = reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(getSelectedItemAtCursor()))
if prevMarkersCount > newMarkersCount then
return "All Stretch markers deleted."
else
return "No stretch markers deleted."
end
else
local prevMarkersCount = reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(getSelectedItemAtCursor()))
reaper.Main_OnCommand(41842, 0)
local newMarkersCount = reaper.GetTakeNumStretchMarkers(reaper.GetActiveTake(getSelectedItemAtCursor()))
if prevMarkersCount < newMarkersCount then
return "Stretch marker added."
else
return "No stretch markers created."
end
end
end
message(self:get(true))
return message
end

-- creating the stretch markers properties by the items list
if type(items) == "table" then
for _, item in ipairs(items) do
formStretchMarkerProperties(item)
end
else
formStretchMarkerProperties(items)
end
-- Hack our sublayout a little to avoid the engine to call  not existing properties
setmetatable(parentLayout.stretchMarkersLayout.properties, {
__index = function(self, key)
parentLayout.pIndex = #parentLayout.stretchMarkersLayout.properties
return parentLayout.stretchMarkersLayout.properties[#parentLayout.stretchMarkersLayout.properties]
end
})

--[[
local takeMarkersActionsProperty = {}
parentLayout.takeMarkersLayout:registerProperty(takeMarkersActionsProperty)
takeMarkersActionsProperty.states = {
[1] = "Create take marker at current position",
[2] = "Create take marker at current position and colorize it",
[3] = "Create take marker at current position and edit it",
[4] = "Delete all take markers"
}

function takeMarkersActionsProperty:get(shouldSaveAction)
local message = initOutputMessage()
message:initType("Adjust this property to choose needed action for take markers. Perform this property to apply chosen action.", "Adjustable, performable")
if extstate.itemsProperty_tmrkaction and not shouldSaveAction then
extstate.itemsProperty_tmrkaction = nil
end
local state = extstate.itemsProperty_tmrkaction
if not state then
state = 1
end
message(self.states[state])
return message
end

function takeMarkersActionsProperty:set(action)
local message = initOutputMessage()
local state = extstate.itemsProperty_tmrkaction
if not state then
state = 1
end
if action == true then
if (state+1) <= #self.states then
extstate.itemsProperty_tmrkaction = state+1
else
message("No more next property values. ")
end
elseif action == false then
if (state-1) > 0 then
extstate.itemsProperty_tmrkaction = state-1
else
message("No more previous property values. ")
end
elseif action == nil then
if state == 2 then
local suitableItem = getItemAtCursor()
if suitableItem then
local retval = reaper.SetTakeMarker(suitableItem, -1, "", time_globalToRelative(suitableItem), getTakeComposedColor())
if retval >= 0 then
message(string.format("Take marker %u has been added.", retval))
end
end
elseif state == 3 then
reaper.Main_OnCommand(41842, 0)
reaper.Main_OnCommand(41988, 0)
elseif state == 4 then
reaper.Main_OnCommand(41844, 0)
else
reaper.Main_OnCommand(42390, 0)
end
end
message(self:get(true))
return message
end

-- creating the take markers properties by the items list
if type(items) == "table" then
for _, item in ipairs(items) do
formTakeMarkersProperties(item)
end
else
formTakeMarkersProperties(items)
end
-- Hack our sublayout a little to avoid the engine to call  not existing properties
setmetatable(parentLayout.takeMarkersLayout.properties, {
__index = function(self, key)
parentLayout.pIndex = #parentLayout.takeMarkersLayout.properties
return parentLayout.takeMarkersLayout.properties[#parentLayout.takeMarkersLayout.properties]
end
})
]]--

parentLayout.defaultSublayout = "itemLayout"

return parentLayout