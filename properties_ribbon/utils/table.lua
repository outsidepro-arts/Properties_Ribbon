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
		k = (type(k) == 'table') and table.deepcopy(k, seen) or k
		v = (type(v) == 'table') and table.deepcopy(v, seen) or v
	
		no[k] = v
	end
	return no
end

---Check contains the given table specified key in
---@param t table @ The table where function should check
---@param key any @ The key which should be checked
---@return boolean @ If the given table contains this key returns true. Otherwise, returns false.,
function table.containsk(t, key)
	return t[key] and true or false
end

---Check contains the given table specified value in
---@param t table @ The table where function should checked
---@param value any @ The value which should be checked
---@return any @ If the given table contains this value returns its key. Otherwise, returns nil.
function table.containsv(t, value)
	for k, v in pairs(t) do
		if v == value then
			return k
		end
	end
	return nil
end