--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2021 outsidepro-arts
License: MIT License

----------
]]--

-- Search utilities

local searcher = {}

function searcher.simpleSearch(fullString, searchString)
if searchString:find("%u") then
return (fullString:find(searchString))
else
return (fullString:lower():find(searchString:lower()))
end
end

return searcher