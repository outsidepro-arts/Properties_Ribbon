--[[
module bytewords
Original name LHLib
Written by @Sergey Parshakov
Copyright (C), electrik-spb, 2016
Rewritten from PureBasic for LUA by Denis A. Shishkin
copyright (C), Outsidepro-Arts, 2020
License: MIT License
]]--


local bytewords = {}
-- Please read the functions names carefully.

function bytewords.getLoByte(value)
return ((value)&0xff)
end

function bytewords.getHibyte(value)
return (((Value)&0xFF00)>>8)
end

function bytewords.getBytes(value)
local lo = ((value)&0xff)
local hi = (((Value)&0xFF00)>>8)
return lo, hi
end

function bytewords.getLoWord(value)
return ((value)&0xffff)
end

function bytewords.getHiWord(value)
return (((value)&0xFFFF0000)>>16)
end

function bytewords.getWords(value)
local lo = ((value)&0xffff)
local hi = (((value)&0xFFFF0000)>>16)
return lo, hi
end

function bytewords.makeWord(lo, hi)
return (((lo)&0xff)|((hi)&0xff)<<8)
end

function bytewords.makeLong(lo, hi)
return (((lo)&0xffff)|((hi)&0xffff)<<16)
end

return bytewords