--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2022 outsidepro-arts
License: MIT License
]]--


-- Proposed humanbeing representations

 local representation = {}
representation.db = setmetatable({},
{__index = function(self, key)
local shouldsilencePositive = false
if key < 0 then
key = -key
shouldsilencePositive = true
end
local v = 0
if key < 0.0000000298023223876953125 then
key = "-inf"
else
v = math.log(key)*8.6858896380650365530225783783321
if v < -150 then
key =  "-inf"
else
key = utils.round(v, 2)
end
end
if not tonumber(key)then return key end
local predb = utils.splitstring(string.format("%.2f", key), ".")
local udb, ddb = tonumber(predb[1]), tonumber(predb[2])
local msg = ""
if tonumber(key) < 0 then
msg = msg.."-"
udb = -udb
elseif tonumber(key) > 0 and shouldsilencePositive == false then
msg = msg.."+"
end
 msg = msg..string.format("%u", udb)
if ddb > 0 then
msg = msg..string.format(" %u", ddb)
end
msg = msg.." dB"
return msg
end
})

representation.pan = setmetatable({},
{__index = function(self, key)
if key == 0 then
return "center"
elseif key > 0 then
return string.format("%u%% right", utils.round(key/(1/100), 0))
elseif key < 0 then
return string.format("%u%% left", utils.round(-key/(1/100), 0))
end
end
})

representation.timesec = setmetatable({},
{__index = function(self, key)
local pretime = utils.splitstring(string.format("%.3f", key), ".")
local s, ms = tonumber(pretime[1]), tonumber(pretime[2])
local msg = ""
if s == 0 and ms == 0 then
return "0 seconds"
end
if s > 0 then
msg = msg..string.format("%u second%s, ", s, ({[true]="s",[false]=""})[(s ~= 1)])
end
if ms > 0 then
msg = msg..string.format("%u millisecond%s", ms, ({[true]="s",[false]=""})[(ms ~= 1)])
else
msg = msg:gsub(", ", "")
end
return msg
end
})

representation.pitch = setmetatable({
[0.00]="original"
},
{__index = function(self, key)
local prepitch = utils.splitstring(string.format("%.2f", key), ".")
local s, c = tonumber(prepitch[1]), tonumber(prepitch[2])
local msg = ""
if tonumber(key) < 0 then
msg = msg.."Minus "
s = -s
end
if s > 0  then
msg = msg..string.format("%u semitone%s, ", s, ({[true]="s",[false]=""})[(s ~= 1)])
end
if c > 0 then
msg = msg..string.format("%u cent%s", c, ({[true]="s",[false]=""})[(c ~= 1)])
else
msg = msg:gsub(", ", "")
end
return msg
end
})

representation.playrate = setmetatable({
[1.000]="original"
}, {
__index = function(self, key)
local preproc = utils.splitstring(tostring(key), ".")
local msg = tostring(preproc[1])
if tonumber(preproc[2]) ~= 0 then
msg = msg..string.format(" %u", tonumber(tostring(utils.round(tonumber("0."..preproc[2]), 3)):match("^%d+[.](%d+)")))
end
msg = msg.." X"
return msg
end
})

representation.pos = {
[0] = setmetatable({}, {
__index = function(self, pos)
local data = reaper.format_timestr_pos(pos, "", 0)
local form = ""
local minute, second, fraction = string.match(data, "(%d*):(%d*)[.](%d*)")
if tonumber(minute) > 0 then
form = form..string.format("%u minute%s", tonumber(minute), ({[true]="s",[false]=""})[(tonumber(minute) ~= 1)])
end
if tonumber(second) > 0 then
form = form..string.format(" %u second%s", tonumber(second), ({[true]="s",[false]=""})[(tonumber(second) ~= 1)])
end
if tonumber(fraction) > 0 then
form = form..string.format(" %u milli-second%s", tonumber(fraction), ({[true]="s",[false]=""})[(tonumber(fraction) ~= 1)])
end
form = form:gsub("^%s", "")
return form
end
}),
[1]=setmetatable({}, {
__index = function(self, pos)
local data = reaper.format_timestr_pos(pos, "", 1)
local form = ""
local measure, beat, fraction = string.match(data, "(%d+)[.](%d+)[.](%d+)")
if tonumber(measure) > 0 then
form = form..string.format("%u measure", tonumber(measure))
end
if tonumber(beat) > 0 then
form = form..string.format(" %u beat", tonumber(beat))
end
if tonumber(fraction) > 0 then
form = form..string.format(" %u percent", tonumber(fraction))
end
form = form:gsub("^%s", "")
return form
end
}),
[2]=setmetatable({}, {
__index = function(self, pos)
local data = reaper.format_timestr_pos(pos, "", 2)
local form = ""
local measure, beat, fraction = string.match(data, "(%d+)[.](%d+)[.](%d+)")
if tonumber(measure) > 0 then
form = form..string.format("%u measure", tonumber(measure))
end
if tonumber(beat) > 0 then
form = form..string.format(" %u beat", tonumber(beat))
end
if tonumber(fraction) > 0 then
form = form..string.format(" %u percent", tonumber(fraction))
end
form = form:gsub("^%s", "")
return form
end
}),
[3] = setmetatable({}, {
__index = function(self, pos)
local data = reaper.format_timestr_pos(pos, "", 3)
return representation.timesec[data]
end
}),
[4]=setmetatable({}, {
__index = function(self, pos)
local data = reaper.format_timestr_pos(pos, "", 4)
return string.format("%s samples", data)
end
})
}

representation.defpos = setmetatable({}, {
__index = function(self, pos)
-- OSARA uses the same method for current time formatting definition
local tfDefinition = 2 -- we will always use the measures formatting by default
if reaper.GetToggleCommandState(40365) == 1 then
tfDefinition = 0
elseif reaper.GetToggleCommandState(40368) == 1 then
tfDefinition = 3
elseif reaper.GetToggleCommandState(40369) == 1 then
tfDefinition = 4
end
return representation.pos[tfDefinition][pos]
end
})

return representation