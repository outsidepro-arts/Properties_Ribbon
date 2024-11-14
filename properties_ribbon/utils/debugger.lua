debugger = {}

local function msgToConsole(msg)
	reaper.ShowConsoleMsg(msg)
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

function debugger.output(...)
	local args = {}
	-- Forcedly converting all arguments to string
	for _, arg in ipairs { ... } do
		table.insert(args, arg ~= nil and tostring(arg) or "nil")
	end
	msgToConsole(string.format("%s\n", table.concat(args, '\t')))
end

function debugger.inspectTable(t)
	debugger.output("{")
	for key, value in pairs(t) do
		debugger.output(key, type(value), not (istable(value) or isfunction(value)) and tostring(value) or nil)
		if istable(value) then
			debugger.inspectTable(value)
		end
	end
	debugger.output("}")
end