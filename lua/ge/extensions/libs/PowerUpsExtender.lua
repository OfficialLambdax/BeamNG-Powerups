--[[
	License: None
	Author: Neverless (discord: neverless.)
]]
local PowerUps
local ServerUtil = Util -- only exists on server
local Util = require("libs/Util")
local MPUtil = require("mp_libs/MPUtil")
local TimedTrigger = require("libs/TimedTrigger")
local MathUtil = require("libs/MathUtil")
local Log = require("libs/Log")
local Particle = require("libs/Particles")

local PowerUpsTraits = require("libs/extender/Traits")
local PowerUpsTypes = require("libs/extender/Types")
local GroupReturns = require("libs/extender/GroupReturns")
local PowerupReturns = require("libs/extender/PowerupReturns")
local Hotkeys = require("libs/extender/Hotkeys")
local Defaults = require("libs/extender/Defaults")

local createObject = require("libs/ObjectWrapper")

local M = {}
M.Traits = PowerUpsTraits.Traits
M.TraitsLookup = Util.tableVToK(M.Traits)
--M.TraitBounds = PowerUpsTraits.TraitBounds
M.Types = PowerUpsTypes.Types
M.GroupReturns = GroupReturns
M.PowerupReturns = PowerupReturns
M.ActiveHotkeys = Hotkeys.ActivePowerupHotkeys
M.ActiveHotkeyStates = Hotkeys.ActivePowerupHotkeyStates
M.hotkeyResolveClearName = Hotkeys.resolveClearName

-- to be deprecated
M.defaultPowerupCreator = Defaults.powerupCreator
M.defaultPowerupRender = Defaults.powerupRender
M.defaultPowerupDelete = Defaults.powerupDelete
M.defaultPowerupChargeCreator = Defaults.powerupChargeCreator
M.defaultPowerupChargeRender = Defaults.powerupChargeRender
M.defaultPowerupChargeLoader = Defaults.powerupChargeLoader
M.defaultPowerupChargeDelete = Defaults.powerupChargeDelete

local SUBJECT_SINGLEPLAYER = "!singleplayer"
local SUBJECT_TRAFFIC = "!traffic"
local SUBJECT_UNKNOWN = "!unknown"


M.defaultImports = function() -- do not change order
	-- local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable = Extender.defaultImports()

	return require("libs/PowerUps"), require("libs/Util"), require("libs/Sets"), require("libs/Sounds"), require("libs/MathUtil"), require("libs/Pot"), require("libs/Log"), require("libs/TimedTrigger"), require("libs/CollisionsLib"), require("mp_libs/MPUtil"), require("mp_libs/PauseTimer"), require("libs/Particles"), require("libs/Sfx"), require("libs/Placeables")
	
	--[[
		Lib = libs/PowerUps.lua
			The main framework
		Util = libs/Util.lua
			Adds convenience functions like tableMerge, better math random etc.
		Sets = libs/Sets.lua
			Wrapper for the TimedTrigger lib that allows to configure trigger sets
		Sound = libs/Sounds.lua
			Wrapper for the games sound engine to play sounds in GE or on vehicle targets
		MathUtil = libs/MathUtil.lua
			Adds things like "get me all vehicles inside this radius but not mine", "create a box in front of me and tell me the vehicles inside it", "rotate this vector for me" etc
		Pot = libs/Pot.lua
			Adds probability based randomization
		Log = libs/Log.lua
			Log.info("some info", "name", true/false for stack trace print)
			Log.info("some info")
				will print -> GELua.libs_Log.FileName@FunctionName			Some Info
				eg		   -> GeLua.libs_Log.PowerUps@vehicleAddPowerup		PowerUp: 73534 picked up cannon
		TimedTrigger = libs/TimedTrigger.lua
			Library to que things like routines, things to be run after X time or just for the next frame.
		Collision = libs/Collision.lua
			Can tell you if the given vehicle has a collision with another vehicle. Mostly untested and completly unused so far.
		MPUtil
		
		Timer
		
		Particle
		
		Sfx
			
	]]
end

M.defaultPowerupVars = function(version) -- do not change order
	if version == nil then
		-- local Trait, Type, onActivate, whileActive, getAllVehicles, createObject = Extender.defaultPowerupVars()
		return M.Traits, M.Types, PowerupReturns.onActivate, PowerupReturns.whileActive, M.getAllVehicles, createObject
		
	elseif version == 1 then
		-- local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)
		return M.Traits, M.Types, PowerupReturns.onActivate, PowerupReturns.whileActive, M.getAllVehicles, createObject, M.ActiveHotkeys, M.ActiveHotkeyStates, PowerupReturns.onHKey
	end
end

M.defaultGroupVars = function(version)
	if version == nil then -- enums
		-- local Type, onPickup, createObject = Extender.defaultGroupVars()
		return M.Types, GroupReturns.onPickup, createObject
		
	elseif version == 1 then
		-- local Type, onPickup, createObject, Default = Extender.defaultGroupVars(1)
		return M.Types, GroupReturns.onPickup, createObject, Defaults
	end
end


M.defaultPowerupMaterialPatch = function()
	if true then return end -- DISABLED. "lod_vertcol" is used by alot
	
	local non_emissive_material = scenetree.findObject("lod_vertcol")
	if non_emissive_material == nil then
		Log.error('Patching failed. Cannot find "log_vertcol" material')
		return
	end
	
	if non_emissive_material:getField("version", 0) ~= "1" then return end
	Log.warn('Patching default powerups "lod_vertcol" material to pbr version 1.5 and applying emissive properties.\nThis change is not permanent.\nIf you have weird glowing texture glitches, try disabling the mod and restart the game!')
	
	non_emissive_material:setField("glow", 0, "0") -- according to the materialEditor.lua this must be done!
	non_emissive_material:setField("version", 0, "1.5")
	non_emissive_material:setField("emissiveMap", 0, "/art/shapes/collectible/collectible_sphere_b.color.DDS")
	non_emissive_material:setField("emissiveFactor", 0, "0.5 0.5 0.5")
	non_emissive_material:setField("instanceEmissive", 0, "1")
	non_emissive_material:reload()
	
	Log.info('Patch successfull')
end

M.getTraitName = function(value)
	for name, event in pairs(M.Traits) do
		if value == event then return name end
	end
end

M.getTypeName = function(value)
	for name, event in pairs(M.Types) do
		if value == event then return name end
	end
end

M.getPowerup = function(target_vehicle_id)
	local vehicle = PowerUps.vehicles[target_vehicle_id]
	if vehicle then return vehicle.powerup, vehicle end
end

M.getActivePowerup = function(target_vehicle_id)
	local vehicle = PowerUps.vehicles[target_vehicle_id]
	if vehicle then return vehicle.powerup_active, vehicle end
end

M.getTraits = function(target_vehicle_id)
	local powerup_active = M.getActivePowerup(target_vehicle_id)
	if powerup_active then return Util.tableVToK(powerup_active.traits) end
end

M.hasTrait = function(target_vehicle_id, trait)
	local traits = M.getTraits(target_vehicle_id)
	if traits then
		return traits[trait] == true
	end
end

M.hasTraits = function(target_vehicle_id, ...)
	local traits = M.getTraits(target_vehicle_id)
	if traits then
		local has_actual = {}
		for _, trait in ipairs({...}) do
			has_actual[trait] = traits[trait] == true
		end
		
		return has_actual
	end
end

M.hasAnyTrait = function(target_vehicle_id, ...)
	local traits = M.getTraits(target_vehicle_id)
	if traits then
		for _, trait in ipairs({...}) do
			if traits[trait] == true then return true end
		end
	end
end

M.hasTraitCall = function(target_vehicle_id, trait, origin_vehicle_id)
	return M.callTrait(target_vehicle_id, trait, origin_vehicle_id)
end

-- for multi calling
M.hasTraitCalls = function(target_vehicle_id, origin_vehicle_id, ...)
	local powerup_active, vehicle = M.getActivePowerup(target_vehicle_id)
	if powerup_active then
		-- sync this over multiplayer
		-- todo
		
		local any_trait = false
		for _, trait in ipairs({...}) do
			if powerup_active[trait] then
				powerup_active[trait](vehicle.powerup_data, target_vehicle_id, origin_vehicle_id)
				any_trait = true
			end
		end
		
		return any_trait
	end
end

M.callTrait = function(target_vehicle_id, trait, origin_vehicle_id)
	local powerup_active, vehicle = M.getActivePowerup(target_vehicle_id)
	if powerup_active and powerup_active[trait] then
		-- sync this over multiplayer
		-- todo
		
		powerup_active[trait](vehicle.powerup_data, target_vehicle_id, origin_vehicle_id)
		return true
	end
end

-- also Calls the traits
M.cleanseTargetsWithTraits = function(targets, origin_vehicle_id, ...)
	local new_targets = {}
	for index, target_id in ipairs(targets) do
		targets[index] = nil
		if not M.hasTraitCalls(target_id, origin_vehicle_id, ...) then
			table.insert(new_targets, target_id)
		end
	end
	
	for index, target_id in ipairs(new_targets) do
		targets[index] = target_id
	end
	
	return new_targets
end

M.cleanseTargetsBehindStatics = function(origin_pos, targets)
	local new_targets = {}
	for _, target_id in ipairs(targets) do
		local target_pos = be:getObjectByID(target_id):getPosition()
		if not MathUtil.raycastAlongSideLine(origin_pos, target_pos) then
			table.insert(new_targets, target_id)
		end
	end
	return new_targets
end

M.isPlayerVehicle = function(game_vehicle_id)
	local vehicle = PowerUps.vehicles[game_vehicle_id]
	if vehicle then
		if vehicle.player_name == SUBJECT_SINGLEPLAYER then return true, false end
		local is_traffic = vehicle.player_name == SUBJECT_TRAFFIC
		
		return MPUtil.isOwn(game_vehicle_id) == true, is_traffic
	end
end

M.isSpectating = function(game_vehicle_id)
	local vehicle = getPlayerVehicle(0)
	if vehicle == nil then return end
	return vehicle:getId() == game_vehicle_id
end

M.isActive = function(...)
	for _, vehicle_id in pairs({...}) do
		if not be:getObjectByID(vehicle_id):getActive() then return false end
	end
	return true
end

if not MPUtil.isBeamMPServer() then
	M.getAllVehicles = function(also_disabled)
		local vehicles = {}
		for _, vehicle in ipairs(getAllVehicles()) do
			if vehicle:getActive() or also_disabled then table.insert(vehicles, vehicle) end
		end
		return vehicles
	end

else
	-- we may want to refactor this later to rather track existing vehicles and just return that table to not create new objects every time this is called. but for now its oke, the server isnt as runtime dependent as the game is.
	M.getAllVehicles = function()
		local vehicles = {}
		for player_id, _ in pairs(MP.GetPlayers()) do
			for vehicle_id, _ in pairs(MP.GetPlayerVehicles(player_id) or {}) do
				
				local vehicle = {int = {
						player_id = player_id,
						vehicle_id = vehicle_id
					}
				}
				function vehicle:getId()
					return self.int.player_id .. '-' .. self.int.vehicle_id
				end
				
				function vehicle:getPosition()
					local raw_pos_packet = MP.GetPositionRaw(self.int.player_id, self.int.vehicle_id)
					if not raw_pos_packet then return nil end
					
					local decode = ServerUtil.JsonDecode(raw_pos_packet)
					
					return {x = decode.pos[1], y = decode.pos[2], z = decode.pos[3]}
				end
				
				table.insert(vehicles, vehicle)
			end
		end
		return vehicles
	end
end

M.getVehicleRotation = function(vehicle)
	return quatFromDir(
		-vec3(vehicle:getDirectionVector()),
		vec3(vehicle:getDirectionVectorUp())
	)
end

M.updatePowerUpsLib = function(this)
	PowerUps = this
end

M.ghostVehicleAutoUnghost = function(vehicle, time)
	vehicle:queueLuaCommand('obj:setGhostEnabled(true)')
	vehicle:setMeshAlpha(0.5, "", false)
	
	local trigger_name = TimedTrigger.getUnused('extender_unghost')
	TimedTrigger.new(
		trigger_name,
		time,
		0,
		function(vehicle, trigger_name)
			if #MathUtil.getVehiclesInsideRadius(vehicle:getPosition(), 5, vehicle:getId()) > 0 then
				TimedTrigger.updateTriggerEvery(trigger_name, 100)
				return
			end
			
			vehicle:setMeshAlpha(1, "", false)
			vehicle:queueLuaCommand('obj:setGhostEnabled(false)')
			
			TimedTrigger.remove(trigger_name)
		end,
		vehicle,
		trigger_name
	)
end

M.targetChange = function(possible_targets, current_selected)
	if not possible_targets or #possible_targets == 0 then return nil end
	
	-- if none selected so far choose first valid
	if current_selected == nil then return possible_targets[1] end
	
	-- if one selected before, choose next in the list
	for index, target_id in ipairs(possible_targets) do
		if current_selected == target_id then
			return possible_targets[index + 1] -- or possible_targets[1]
		end
	end
	
	-- couldnt find the previous target in the list? choose first
	return possible_targets[1]
end

-- You may have to reload your game if you have opened the world editor before calling this on a new particle
M.loadParticles = function(particle_data, emitter_data)
	-- game engine function
	loadJsonMaterialsFile(particle_data)
	loadJsonMaterialsFile(emitter_data)
end

return M
