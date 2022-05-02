--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License

----------
]]--


prepareUserData = {}

-- Basic user typed data preparation
-- Parameters:
-- udata (string): user typed data.
-- Returns cleared off the string value. The string will be lowered and cleared off spaces.
function prepareUserData.basic(udata)
udata = udata:lower()
return udata:gsub("%s([%d])", ".%1")
end


-- The macro for prepare the values with decibels values.
prepareUserData.db = {
-- These fields are format prompt captions. You may assign the third parameter in reaper.GetUserInputs method by these fields.
-- Please note: avoid the coma symbols (,) using, the reaper.GetUserInputs method is used, so coma means the CSV separation! I don't know what you will trip out this case, but REAPER doesn't proposes any other method to wait the typed value from an user.
formatCaption = [[
Type the humanbeeing volume value. The following formats are supported:
1 25 dB
-2.36
<3.50db (means relative value i.e. the current volume value will be decreased by this value)
>5 (means relative value i.e. the current volume value will be increased by this value)
inf (will set the infinite negative value means silence)
Please note: these format may be combined with eachother.
]]}

-- The methods like method below prepares the appropriate humanbeeing user typed data to REAPER's  values.
-- Parameters:
-- udata (string): user typed data.
-- curvalue (number): The current num value which currently set. Needs when user uses the relative commands.
-- Returns values which REAPER waits in appropriate elements or nil if couldn't get any.
-- Please note: all that methods below have the same destination, so I'll not comment every method of.
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

-- The macro for prepare the values with pan values.
prepareUserData.pan = {
formatCaption = [[
Type the humanbeeing pan value. The following formats are supported:
25% left
30%r
50l
<3% (means relative value i.e. the current pan value will be decreased by this value)
>5 (means relative value i.e. the current pan value will be increased by this value)
center (will set a pan value to center)
c (like in previous case))
Please note: these format may be combined with eachother.
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
if relative then
converted = string.match(udata, "^[<>](%d*)")
if converted then
if relative == 1 then
return utils.percenttonum(utils.numtopercent(curvalue)-converted)
elseif relative == 2 then
return utils.percenttonum(utils.numtopercent(curvalue)+converted)
end
end
return nil
else
if udata:find("[lr]") == nil then
reaper.ShowMessageBox('The pan direction is not set. You have to set the pan direction like \"left\" or \"right\" or \"l\" or \"r\".', "Converting error", showMessageBoxConsts.sets.ok)
return nil
end
if udata:match("^[<>]?%d+[%%]?%s?[lr]") then
converted = udata:match("^[-<>]?(%d+)")
if converted == nil then
reaper.ShowMessageBox("Cannot extract  any digits value.", "converting error", showMessageBoxConsts.sets.ok)
return nil
end
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

-- The macro for prepare the values with percentage values.
prepareUserData.percent = {
formatCaption = [[
Type the humanbeeing percentage value. The following formats are supported:
20%
-50
<30% (means relative value i.e. the current percent value will be decreased by this value)
>5 (means relative value i.e. the current percent value will be increased by this value)
Please note: these format may be combined with eachother.
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

-- The macro for prepare the values with pitch values.
prepareUserData.pitch = {
formatCaption = [[
Type the humanbeeing pitch value. The following formats are supported:
2 semitones 34 cents
-3s2c
1.25
<3s (means relative value i.e. the current pitch value will be decreased by this value)
>5 (means relative value i.e. the current pitch value will be increased by this value)
original [or orig or o] (will set a pitch value to original pitch)
Please note: these format may be combined with eachother.
]]}

function prepareUserData.pitch.process(udata, curvalue)
udata = prepareUserData.basic(udata)
if udata:find("^[o]%w*") then
return 0.0
end
local relative = nil
if udata:match("^[<]") then
relative = 1
udata = udata:gsub("^[<]", "")
elseif udata:match("^[>]") then
relative = 2
udata = udata:gsub("^[>]", "")
end
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
if relative == 1 then
return curvalue-tonumber(converted)
elseif relative == 2 then
return curvalue+tonumber(converted)
else
return tonumber(converted)
end
end
return nil
end

return prepareUserData