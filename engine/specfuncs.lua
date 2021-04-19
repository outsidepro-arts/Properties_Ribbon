--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts & other contributors
License: MIT License
]]--

-- Here are some functions which I have been grabbed from some sources and opensource projects. Some of was needed to be rewritten for LUA, but some of already being presented as is also.
-- Unfortunately, not all functions written here I remembered where grabbed, because I wrote it at the start of complex coding and did not planned to git this..
-- If you outraged of, please let me know about via issues in the repository.

function round(num, numDecimalPlaces)
local negative = false
if num < 0 then
negative = true
num = -num
end
  local mult = 10^(numDecimalPlaces or 0)
if negative == true then
  return -math.floor(num * mult + 0.5) / mult
else
  return math.floor(num * mult + 0.5) / mult
end
end

-- These two functions have been based on project WDL (https://github.com/justinfrankel/WDL)
function numtodecibels(num)
local v = 0
if num < 0.0000000298023223876953125 then
return -150.0
end
v = math.log(num)*8.6858896380650365530225783783321
if v < -150 then
return -150.0
else
return round(v, 2)
end
end

function decibelstonum(db)
if db == "-inf" then
return 0
end
return math.exp(db*0.11512925464970228420089957273422)
end
-- .

-- This function originaly written by @electrik-spb in PureBasic and rewritten by me for LUA.
function numtopercent(num)
return math.floor(num/(1/100))
end

-- This function based on previous function but just reversed.
function percenttonum(perc)
return perc/(1*100)
end

function toboolean(value)
if type(value) == "string" then
return ({["false"] = false, ["true"] = true})[value]
else
return (value > 0)
end
end

-- This function written by @electrik-spb in PureBasic and rewritten by me for LUA.
-- Thank you for help with, Sergey!
function getBitValue(value, first, last)
return ((value & ((1<<last)-1)) >> (first-1))
end

function splitstring(str, delimiter, mode)
delimiter = delimiter or "%s"
mode = nor(mode) or true
local t, spos = {}, 1
while string.find(str, delimiter, spos, mode) ~= nil do
local startFindPos, endFindPos = str:find(delimiter, spos, mode)
table.insert(t, str:sub(spos, startFindPos-1))
spos = endFindPos+1
end
table.insert(t, str:sub(spos))
return t
end

function delay(ms)
ms = ms*0.001
local curTime = os.clock()
while (os.clock()-curTime) <= ms do end
end

function removeSpaces(str)
preproc = str:gsub("%s.", string.upper):gsub("%s", "")
  return  preproc:gsub("^.", string.lower)
end

function nor(state)
if type(state) == "number" then
if state <= 1 then
state = state~1
end
elseif type(state) == "boolean" then
if state == true then
state = false
elseif state == false then
state = true
end
end
return state
end

function debug(str)
reaper.ShowMessageBox(str, "Debug", 0)
end

function getScriptPath()
return ({reaper.get_action_context()})[2]:match('^.+[\\//]').."engine\\"
end
