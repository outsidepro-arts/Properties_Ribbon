--[[
This file is part of script complex Properties Ribbon
Copyright (c) 2020-2024 outsidepro-arts
License: MIT License

----------
]]
--


-- This file contains a macros for specified solutions. Use this macros at own properties.


function composeSimpleProperty(
	-- the Main_OnCommand ID or its list
	cmd,
	-- The property label (optional)
	msg
	)
		local usual = {
			get = function(self)
				local message = initOutputMessage()
				message:initType()
				if msg then
					message(msg)
				else
					if istable(cmd) then
						message:changeType(string.format("Perform this property to execute these %u actions by queued order: ", #cmd), 1)
						message("Multiple actions: ")
						for id, ccmd in ipairs(cmd) do
							local premsg = string.match(reaper.CF_GetCommandText(0, ccmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, ccmd)
							premsg = premsg:gsub("[.]+$", "")
							message(premsg)
							if id < #cmd - 1 then
								message(", ")
							elseif id == #cmd - 1 then
								message(" and ")
							end
						end
					else
						local premsg = string.match(reaper.CF_GetCommandText(0, cmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, cmd)
						premsg = premsg:gsub("[.]+$", "")
						message(premsg)
					end
				end
				return message
			end,
			set_perform = function(self)
				local message = initOutputMessage()
				local oldTracksCount, oldItemsCount = reaper.CountTracks(0), reaper.CountMediaItems(0)
				if istable(cmd) then
					for _, command in ipairs(cmd) do
						reaper.Main_OnCommand(command, 1)
					end
				else
					reaper.Main_OnCommand(cmd, 1)
				end
				local newTracksCount, newItemsCount = reaper.CountTracks(0), reaper.CountMediaItems(0)
				if oldTracksCount < newTracksCount then
					message(string.format("%u tracks added", newTracksCount - oldTracksCount))
				elseif oldTracksCount > newTracksCount then
					message(string.format("%u tracks removed", oldTracksCount - newTracksCount))
				end
				if oldItemsCount < newItemsCount then
					if #message > 0 then
						message(" and ")
					end
					message(string.format("%u items added", newItemsCount - oldItemsCount))
				elseif oldItemsCount > newItemsCount then
					if #message > 0 then
						message(" and ")
					end
					message(string.format("%u items removed", oldItemsCount - newItemsCount))
				end
				if #message > 0 then
					return message, true
				end
				return nil, true
			end
		}
		return usual
	end
	
	function composeSimpleDialogOpenProperty(
	-- the Main_OnCommand ID
	cmd,
	-- The property label (optional)
	msg
	)
		local usual = {
			get = function(self)
				local message = initOutputMessage()
				message:initType("Perform this property to open the specified window.", "Performable")
				if msg then
					message(msg)
				else
					local premsg = string.match(reaper.CF_GetCommandText(0, cmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, cmd)
					premsg = premsg:gsub("[.]+$", "")
					message(premsg)
				end
				return message
			end,
			set_perform = function(self, action)
				reaper.Main_OnCommand(cmd, 1)
				setUndoLabel(self:get())
				return nil, true
			end
		}
		return usual
	end
	
	function composeExtendedSwitcherProperty(states, cmd, msg, types, getFunction, setFunction, shouldBeOnetime)
		shouldBeOnetime = shouldBeOnetime or true
		local usual = {
			["msg"] = msg,
			getValue = function()
				return reaper.GetToggleCommandState(cmd)
			end,
			setValue = function(value)
				reaper.Main_OnCommand(cmd, value)
			end,
			get = getFunction or function(self)
				local message = initOutputMessage()
				message:initType(types[1], types[2])
				if msg then
					message(string.format(msg, states[self.getValue()]))
				else
					local premsg = string.match(reaper.CF_GetCommandText(0, cmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, cmd)
					premsg = premsg:gsub("[.]+$", "")
					message { label = premsg }
					message { value = states[self.getValue()] }
				end
				return message
			end,
			set_perform = setFunction or function(self)
				local message = initOutputMessage()
				local state = nor(self.getValue())
				self.setValue(state)
				message(self:get())
				return message, true
			end
		}
		return usual
	end
	
	function composeExtendedProperty(cmd, msg, types, getFunction, setFunction)
		local usual = {
			["msg"] = msg,
			get = getFunction or function(self)
				-- If user has SWS installed, omit the msg parameter
				if type(cmd) ~= "table" then
					if reaper.APIExists("CF_GetCommandText") then
						msg = string.match(reaper.CF_GetCommandText(0, cmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, cmd)
						msg = msg:gsub("[.]+$", "")
					end
				end
				local message = initOutputMessage()
				message:initType(types[1], types[2])
				if msg then
					message(msg)
				else
					local premsg = string.match(reaper.CF_GetCommandText(0, cmd), "^.+:%s(.+)") or reaper.CF_GetCommandText(0, cmd)
					premsg = premsg:gsub("[.]+$", "")
					message(premsg)
				end
				return message
			end,
			set_perform = setFunction or function(self, action)
				if istable(cmd) then
					for _, command in ipairs(cmd) do
						reaper.Main_OnCommand(command, 0)
					end
				else
					reaper.Main_OnCommand(cmd, 0)
				end
				return nil, true
			end
		}
		return usual
	end
	