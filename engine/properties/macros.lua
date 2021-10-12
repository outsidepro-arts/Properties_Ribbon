--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts
License: MIT License

----------
]]--


-- This file contains a macros for properties at this directory.
-- You don't need to include this file. The engine will do it itself.

prepareUserData = {}

function prepareUserData.basic(udata)
udata = udata:lower()
return udata:gsub("%s", "")
end

prepareUserData.db = {
formatCaption = [[
Type the humanbeeing volume value. The following formats are supported:
1.25 dB
-2.36
<3.50db (means relative value i.e. the current volume value will be decreased by this value)
>5 (means relative value i.e. the current volume value will be increased by this value)
inf (will set the infinite negative value means silence)
]]}
-- Please note: avoid the coma symbols (,) using, the reaper.GetUserInputs method is used, so coma means the CSV separation! I don't know what you will trip out this case, but REAPER doesn't proposes any other method to wait the typed value from an user.

function prepareUserData.db.process(udata, curvalue)
udata = prepareUserData.basic(udata)
if udata:find("inf") then
return 0
end
local relative = nil
if udata:match("^[<]") then
relative = 1
elseif udata:match("^[>]") then
relative = 2
end
udata = udata:match("^[<>]?([-+]?%d+[.]?%d*)")
if udata then
if relative == 1 then
return utils.decibelstonum(utils.numtodecibels(curvalue)-udata)
elseif relative == 2 then
return utils.decibelstonum(utils.numtodecibels(curvalue)+udata)
else
return utils.decibelstonum(udata)
end
end
return nil
end

prepareUserData.pan = {
formatCaption = [[
Type the humanbeeing pan value. The following formats are supported:
25% left
30%r
50l
<3% (means relative value i.e. the current volume value will be decreased by this value)
>5 (means relative value i.e. the current volume value will be increased by this value)
center (will set a pan value to center)
c (like in previous case))
]]}

function prepareUserData.pan.process(udata, curvalue)
udata = prepareUserData.basic(udata)
if udata:match("^[c]") then
return 0
end
local relative = nil
if udata:match("^[<]") then
relative = 1
elseif udata:match("^[>]") then
relative = 2
end
local converted = nil
if udata:match("^[<>]?%d+[.]?%d*[lr]?") then
local converted = udata:match("^[-<>]?(%d+)")
if converted == nil then
reaper.ShowMessageBox("Cannot extract  any digits value.", "converting error", 0)
return nil
end
if relative == 1 then
converted = utils.percenttonum(utils.numtopercent(curvalue)-converted)
elseif relative == 2 then
converted = utils.percenttonum(utils.numtopercent(curvalue)+converted)
else
converted = utils.percenttonum(converted)
end
if converted > 1 then
converted = 1
end
if udata:match("^.+([l])") then
converted = -converted
end
if converted then
return utils.round(converted, 3)
end
end
return nil
end

prepareUserData.percent = {
formatCaption = [[
Type the humanbeeing volume value. The following formats are supported:
20%
-50
<30% (means relative value i.e. the current volume value will be decreased by this value)
>5 (means relative value i.e. the current volume value will be increased by this value)
]]}

function prepareUserData.percent.process(udata, curvalue)
udata = prepareUserData.basic(udata)
local relative = nil
if udata:match("^[<]") then
relative = 1
elseif udata:match("^[>]") then
relative = 2
end
udata = udata:gsub("^[<>]", "")
udata = tonumber(udata:match("^([-]?%d+)%%?"))
if udata then
if relative == 1 then
udata = utils.percenttonum(utils.numtopercent(curvalue)-udata)
elseif relative == 2 then
udata = utils.percenttonum(utils.numtopercent(curvalue)+udata)
else
udata = utils.percenttonum(udata)
end
if udata > 1 then
udata = 1
elseif udata < -1 then
udata = -1
end
return udata
end
return nil
end

function prepareUserData.rate(udata, curvalue)
udata = prepareUserData.basic(udata)
udata = udata:match("^(%d+[.]?%d*)")
if udata then
return tonumber(utils.percenttonum(udata))
end
return nil
end

function prepareUserData.pitch(udata, curvalue)
udata = prepareUserData.basic(udata)
local converted = udata:match("^[-+]?%d+$")
if not converted then
converted = udata:match("^([-+]?%d+[.]%d+)")
end
if not converted then
local maybeSemitones, maybeCents = udata:match("^([-+]?%d+)[s][a-z]*(%d+)[c].*")
if maybeSemitones then
converted = tostring(maybeSemitones)
end
if maybeCents then
converted = converted.."."..tostring(maybeCents)
end
end
if converted then
return tonumber(converted)
end
return nil
end

