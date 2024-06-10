local module = {}
local translationDirectory = "translation"
local language = nil
local stringsCache = {}
local pluralFormsFunction = nil

function module.setLanguage(newLang)
	language = newLang
end

function module.init(filename)
	filename = filename or select(2, reaper.get_action_context())
	local f = io.open(filename:match("^.+[//\\]"):joinsep("/", translationDirectory, language, filename:match("[//\\].+$")), "r")
	if io.type(f) =="file" then
		local allData = f:read("*a")
		allData = "return " .. allData
		local data = loadstring(allData)()
		pluralFormsFunction = data.pluralForms
		data.pluralForms = nil
		for key, value in pairs(data) do
			stringsCache[key] = value
		end
		f:close()
		return true
	end
	return false
end

function module.getREAPERLanguage()
	local retval, lang = reaper.get_config_var_string("langpack")
	return retval and select(1, lang:rpart("."))
end

function module.caseStringByNum(fstring, num, ...)
	return pluralFormsFunction(fstring, num, ...)
end

function t(str)
	return stringsCache[str] or str
end

return module