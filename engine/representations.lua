--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts
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
return string.format("%s%% right", math.floor(key/(1/100)))
elseif key < 0 then
return string.format("%s%% left", math.floor(-key/(1/100)))
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

representation.pitch = setmetatable({},
{__index = function(self, key)
local prepitch = utils.splitstring(string.format("%.2f", key), ".")
local s, c = tonumber(prepitch[1]), tonumber(prepitch[2])
local msg = ""
if s == 0 and c == 0 then
return "original"
end
if s < 0 then
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

return representation