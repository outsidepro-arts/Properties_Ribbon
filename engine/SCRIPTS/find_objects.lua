--[[
Find specified objects script for Properties Ribbon
Copyright (C), Outsidepro Arts 2021-2022
License: MIT license
This script written for Properties Ribbon complex] and can be only runnen from this.
]]--

local function searchTracks(searchString, trackFrom)
trackFrom = trackFrom or 0
local countTracks = reaper.CountTracks(0)
for i = trackFrom, countTracks-1 do
local track = reaper.GetTrack(0, i)
local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
if trackName then
if utils.simpleSearch(trackName, searchString) then
reaper.SetOnlyTrackSelected(track)
setUndoLabel("Set focus to found  track with specified name")
return true
end
end
end
reaper.ShowMessageBox(string.format("Couldn't find any track with %s in its name.", searchString), "No search results", showMessageBoxConsts.sets.ok)
end


local function searchPluginsInTracks(searchString, trackFrom)
trackFrom = trackFrom or 0
local countTracks = reaper.CountTracks(0)
for i = trackFrom, countTracks-1 do
local track = nil
if i < 0 then
track = reaper.GetMasterTrack(0)
else
track = reaper.GetTrack(0,i)
end
local countFX = reaper.TrackFX_GetCount(track)
if countFX > 0 then
for k = 0, countFX-1 do
  local retval, buf = reaper.TrackFX_GetFXName(track, k, "")
if retval then
if utils.simpleSearch(buf, searchString) then
reaper.SetOnlyTrackSelected(track)
setUndoLabel("Set focus to found  track with plug-in contained specified name")
return true
end
end
end
end
end
reaper.ShowMessageBox(string.format("Couldn't find any track with plug-in which holds %s in its name.", searchString), "No search results", showMessageBoxConsts.sets.ok)
return false
end

local function searchItems(searchString, itemFrom)
itemFrom = itemFrom or 0
local countItems = reaper.CountMediaItems(0)
for i = itemFrom, countItems-1 do
local item = reaper.GetMediaItem(0,i)
local take = reaper.GetActiveTake(item)
local _, takeName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
if takeName then
if utils.simpleSearch(takeName, searchString) then
reaper.SelectAllMediaItems(0, false)
local newCursorPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
reaper.SetEditCurPos(newCursorPos,true,true)
reaper.SetMediaItemSelected(item, true)
setUndoLabel("Set focus to found  item with specified name")
return true
end
end
end
reaper.ShowMessageBox(string.format("Couldn't find any item which holds %s in its name.", searchString), "No search results", showMessageBoxConsts.sets.ok)
return false
end

local function searchPluginsInTakes(searchString, itemFrom)
itemFrom = itemFrom or 0
local countItems = reaper.CountMediaItems(0)
for i = itemFrom, countItems-1 do
local item = reaper.GetMediaItem(0,i)
local take = reaper.GetActiveTake(item)
local countFX = reaper.TakeFX_GetCount(take)
if countFX > 0 then
local found = false
for k = 0, countFX-1 do
local retval, buf = reaper.TakeFX_GetFXName(take, k, "")
if retval then
if utils.simpleSearch(buf, searchString) then
reaper.SelectAllMediaItems(0, false)
local newCursorPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
reaper.SetEditCurPos(newCursorPos,true,true)
reaper.SetMediaItemSelected(item, true)
setUndoLabel("Set focus to found  item with plug-in contained specified name")
return true
end
end
end
end
end
reaper.ShowMessageBox(string.format("Couldn't find any item with plug-in which holds %s in its name.", searchString), "No search results", showMessageBoxConsts.sets.ok)
return false
end

local context = reaper.GetCursorContext()

local searchLayout = initLayout(({[0]="Search in tracks",[1]="Search in items"})[context])

function searchLayout.canProvide()
if context == 0 then
return (reaper.CountTracks(0) > 0)
elseif context == 1 then
return (reaper.CountMediaItems(0) > 0)
end
return false
end


local searchinAction = {}
searchLayout:registerProperty(searchinAction)
searchinAction.objStrings = {
[0]="track",
[1]="item"
}
searchinAction.searchProcesses = {
[0]=searchTracks,
[1]=searchItems
}

function searchinAction:get()
local message = initOutputMessage()
message:initType(string.format("Perform this action to search a %s by specified query.", self.objStrings[context]), "Performable")
message(string.format("Search a specified %s", self.objStrings[context]))
return message
end

function searchinAction:set_perform()
local prevQuery = extstate.searchScript_lastQuery or ""
local retval, answer = reaper.GetUserInputs(string.format("Search specified %s", self.objStrings[context]), 1, string.format("Type a part or full %s name which you wish to find. For case sensetive search Type your query with appropriated case:", self.objStrings[context]), prevQuery)
if retval then
local fromPosition = 0
if context == 0 then
fromPosition = reaper.GetMediaTrackInfo_Value(reaper.GetLastTouchedTrack(), "IP_TRACKNUMBER")
if fromPosition < 0 then -- Master track suddenly selected
fromPosition = 0
end
elseif context == 1 then
fromPosition = reaper.GetMediaItemInfo_Value(reaper.GetSelectedMediaItem(0, 0), "IP_ITEMNUMBER")
end
if self.searchProcesses[context](answer, fromPosition) then
reaper.Main_OnCommand(reaper.NamedCommandLookup("_OSARA_REPORTSEL"), 0)
extstate.searchScript_lastQuery= answer
end
end
end

local searchbyPluginsAction = {}
searchLayout:registerProperty(searchbyPluginsAction)
searchbyPluginsAction.objStrings = {
[0]="tracks",
[1]="active takes in items"
}
searchbyPluginsAction.searchProcesses = {
[0]=searchPluginsInTracks,
[1]=searchPluginsInTakes
}

function searchbyPluginsAction:get()
local message = initOutputMessage()
message:initType(string.format("Perform this action to search a plug-in in %s by specified query.", self.objStrings[context]), "Performable")
message(string.format("Search a specified plug-in in %s", self.objStrings[context]))
return message
end

function searchbyPluginsAction:set_perform()
local prevQuery = extstate.searchScript_lastQuery or ""
local retval, answer = reaper.GetUserInputs(string.format("Search specified plug-in %s", self.objStrings[context]), 1, "Type a part or full plug-in name which you wish to find. Type your query with appropriated case:", prevQuery)
if retval then
local fromPosition = 0
if context == 0 then
fromPosition = reaper.GetMediaTrackInfo_Value(reaper.GetLastTouchedTrack(), "IP_TRACKNUMBER")
elseif context == 1 then
fromPosition = reaper.GetMediaItemInfo_Value(reaper.GetSelectedMediaItem(0, 0), "IP_ITEMNUMBER")
end
if self.searchProcesses[context](answer, fromPosition) then
reaper.Main_OnCommand(reaper.NamedCommandLookup("_OSARA_REPORTSEL"), 0)
extstate.searchScript_lastQuery= answer
end
end
end

return searchLayout