--[[
	Deep table copy
	Grabbed of https://ask-dev.ru/info/107146/how-do-you-copy-a-lua-table-by-value#content
	Parameters:
	o (table): the table which needs be coppied.
	Returns new table which differents of passed table.
]] --
function table.deepcopy(o, seen)
	seen = seen or {}
	if o == nil then return nil end
	if seen[o] then return seen[o] end


	local no = {}
	seen[o] = no
	setmetatable(no, table.deepcopy(getmetatable(o), seen))

	for k, v in next, o, nil do
		k = (type(k) == 'table') and k:deepcopy(seen) or k
		v = (type(v) == 'table') and v:deepcopy(seen) or v
		no[k] = v
	end
	return no
end
