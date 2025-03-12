local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable, Ui = Extender.defaultImports(1)
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

--[[
	When "vtable" is mentioned it means a table where the data is in the v
		local my_table = {}
		table.insert(my_table, data_1)
		table.insert(my_table, data_2)
		
		or
		
		local my_table = {data_1, data_2}
		
		both result in
			print(my_table)
				= [1] = data_1
				= [2] = data_2
				
			for k, >>v<< in ipairs(my_table) do
				print(k .. ' ' .. v)
				-- prints k as 1 and then 2
				-- prints v as data_1 and then data_2
			end
		
	When something is marked as "optional" it means that you give "nil" if you dont want use it
	
	When something is marked as "any" it means that your data can have any format and doesnt have to follow any rules.
]]

local M = {
	-- Shown to the user
	clear_name = "describtor",
	
	-- Turn true to not be affected by the render distance
	do_not_unload = false,
	
	-- Configure traits of this powerup
	--[[
		Traits are defined in /libs/extender/Traits.lua
			Reflective
			StrongReflective
			Consuming
			StrongConsuming
			Ghosted
			Ignore
			Breaking
			StrongBreaking
	]]
	traits = {},
	
	-- Must match the libs version name. If it doesnt, this powerup group is considered out of date
	-- dump(Lib.getLibVersion())
	lib_version = "enums",
	
	-- Server related below
	
	-- Define the maximum length this powerup is active. The server will end it after this time.
	max_len = 1000,
	
	-- TODO
	target_info_descriptor = nil,
	
	-- Configure traits this powerup respects. Required for trait call sync
	respects_traits = {},
	
	-- Auto filled
	-- Contains the dir path to this powerup
	file_path = "",
	
	-- Add extra variables here if needed. Constants only!
	--my_var = 0,
}

-- Called once when the powerup is loaded
M.onInit = function(group_defs) end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	--[[
		Returns are defined in /libs/extender/PowerupReturns.lua
			onActivate.Success(
				data = any
			)
			
			onActivate.Error(
				reason = string - optional
			)
			
			onActivate.TargetInfo(
				data = any,
				target_info = table{any}
			)
			
			onActivate.TargetHits(
				target_hits = vtable{vehicle_id_1, vehicle_id_n} - or empty table
			)
	
	]]
	return onActivate.Error("Powerup has no logic")
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	--[[
		Returns are defined in /libs/extender/PowerupReturns.lua
			whileActive.Continue(
				target_info = table{any}, - optional
				target_hits = vtable{vehicle_id_1, vehicle_id_n} - optional
			)
			
			whileActive.Stop()
			
			whileActive.StopAfterExec(
				target_info = table{any}, - optional
				target_hits = vtable{vehicle_id_1, vehicle_id_n} - optional. will only stop if given
			)
			
			whileActive.TargetInfo(
				target_info = table{any}
			)
			
			whileActive.TargetHits(
				target_hits = vtable{vehicle_id_1, vehicle_id_n}
			)
	]]
	return whileActive.Stop()
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info, origin_id) end

-- When a target was hit, only called on players spectating origin_id
M.onTargetHit = function(data, origin_id, target_id) end

-- When a target was hit, called on every client
M.onHit = function(data, origin_id, target_id) end

-- When the powerup has ended or is destroyed by any means
M.onDeactivate = function(data, origin_id) end

-- Render Distance related
M.onUnload = function(data) end

M.onLoad = function(data) end

-- Hotkeys
--[[
	Available hotkeys and states are defined in /libs/extender/Hotkeys.lua
		Hotkey.Fire
		Hotkey.TargetChange
		Hotkey.Cancel
		Hotkey.Camera
		Hotkey.Action1
		Hotkey.Action2
		Hotkey.Action3
		Hotkey.Action4
		Hotkey.Action5
]]
M[Hotkey.Fire] = function(data, origin_id, state)
	--[[
		HKeyState.Down
		HKeyState.Up
	]]
	if state ~= HKeyState.Down then return end
	
	--[[
		Returns are defined in /libs/extender/PowerupReturns.lua
			onHKey.Stop()
			
			onHKey.StopAfterExec(
				target_info = table{any}, - optional
				target_hits = vtable{vehicle_id_1, vehicle_id_n} - optional. will only stop if given
			)
			
			onHKey.TargetInfo(
				target_info = table{any}
			)
			
			onHKey.TargetHits(
				target_hits = vtable{vehicle_id_1, vehicle_id_n}
			)
	]]
end

return M
