debugger = {}

function debugger.focusToConsole()
	-- WIN32 functions are exist only in Windows
	if utils.platform() == "Windows" then
		-- ReaConsole does not takes the focus by itself, so we have to make it forcedly.
		if select(2,
				reaper.BR_Win32_GetWindowText(
					reaper.BR_Win32_GetParent(
						reaper.BR_Win32_GetFocus()
					)
				)
			) ~= "ReaScript console output" then
			local consoleWindow = reaper.BR_Win32_FindWindowEx(
				reaper.BR_Win32_HwndToString(
					reaper.BR_Win32_GetParent(
						reaper.BR_Win32_GetMainHwnd()
					)
				), "0", "#32770", "ReaScript console output", true, true)
			reaper.BR_Win32_SetFocus(consoleWindow)
		end
	end
end

local function msgToConsole(msg, show)
	show = isboolean(show) and show or true
	reaper.ShowConsoleMsg(string.format("%s%s", show and "!show:" or "", msg))
	if show then
		debugger.focusToConsole()
	end
end

local function processArgs(...)
	-- Forcedly converting all arguments to string
	local args = {}
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		table.insert(args, arg ~= nil and tostring(arg) or "nil")
	end
	return table.concat(args, '\t')
end

function debugger.output(...)
	local args = processArgs(...)
	msgToConsole(string.format("%s\n", processArgs(...)), true)
end

function debugger.add(...)
	local args = processArgs(...)
	msgToConsole(string.format("%s\n", processArgs(...)), false)
end

function debugger.showConsole(state)
	state = assert(type(state) == "boolean", "Expected boolean, got " .. type(state))
	reaper.Main_OnCommand(42663, state and 1 or 0) -- ReaScript: Show ReaScript console
	if state then
		debugger.focusToConsole()
	end
end

function debugger.inspectTable(t, iteration)
	debugger.add(not iteration and "Table inspection" or "" .. "{")
	for key, value in pairs(t) do
		debugger.add(key, type(value), not (istable(value) or isfunction(value)) and tostring(value) or nil)
		if istable(value) then
			debugger.inspectTable(value, true)
		end
	end
	debugger[iteration == true and "add" or "output"]("}")
end
