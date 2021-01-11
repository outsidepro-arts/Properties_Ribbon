--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts & other contributors
License: MIT License
]]--


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

function numtodecibels(num, noString)
local v = 0
if num < 0.0000000298023223876953125 then
if noString == true then
return -150.0
else
return "-inf"
end
end
v = math.log(num)*8.6858896380650365530225783783321
if v < -150 then
if noString == true then
return -150.0
else
return "-inf"
end
else
if nostring == true then
return round(v, 2)
else
if round(v, 2) > 0 then
return "+"..round(v, 2)
else
return round(v, 2)
end
end
end
end

function decibelstonum(db)
if db == "-inf" then
return 0
end
return math.exp(db*0.11512925464970228420089957273422)
end

function numtopan(num)
if num == 0 then
return "center"
elseif num > 0 then
num = num/(1/100)
return string.format("%s%% right", math.floor(num))
elseif num < 0 then
num = -num/(1/100)
return string.format("%s%% left", math.floor(num))
end
end


function numtopercent(num)
return math.floor(num/(1/100))
end

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

function getBitValue(value, first, last)
return ((value & ((1<<last)-1)) >> (first-1))
end

function splitstring(string, delimiter)
if delimiter == nil then
delimiter = "%s"
end
local t={}
for str in string.gmatch(string, "([^"..delimiter.."]+)") do
table.insert(t, str)
end
return t
end

function delay(ms)
ms = ms*0.001
local curTime = os.clock()
while (os.clock()-curTime) <= ms do end
end

-- This function grabbed of https://stackoverflow.com/questions/10460126/how-to-remove-spaces-from-a-string-in-lua/10460780
function removeSpaces(str)
  return str:match"^%s*(.*)":match"(.-)%s*$"
end
