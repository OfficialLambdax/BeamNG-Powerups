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
local Placeable = require("libs/Placeables")

local PowerUpsTraits = require("libs/extender/Traits")
local PowerUpsTypes = require("libs/extender/Types")
local GroupReturns = require("libs/extender/GroupReturns")
local PowerupReturns = require("libs/extender/PowerupReturns")
local Hotkeys = require("libs/extender/Hotkeys")
local Defaults = require("libs/extender/Defaults")
local Ui = require("libs/extender/Ui")

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

local LOADED_ASSETS = {} -- ["file_path"] = true


M.defaultImports = function(version) -- do not change order
	if version == nil then -- v0.4
		-- local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable = Extender.defaultImports()
		return require("libs/PowerUps"), require("libs/Util"), require("libs/Sets"), require("libs/Sounds"), require("libs/MathUtil"), require("libs/Pot"), require("libs/Log"), require("libs/TimedTrigger"), require("libs/CollisionsLib"), require("mp_libs/MPUtil"), require("mp_libs/PauseTimer"), require("libs/Particles"), require("libs/Sfx"), require("libs/Placeables")
		
	elseif version == 1 then -- v0.5
		-- local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable, Ui = Extender.defaultImports(1)
		return require("libs/PowerUps"), require("libs/Util"), require("libs/Sets"), require("libs/Sounds"), require("libs/MathUtil"), require("libs/Pot"), require("libs/Log"), require("libs/TimedTrigger"), require("libs/CollisionsLib"), require("mp_libs/MPUtil"), require("mp_libs/PauseTimer"), require("libs/Particles"), require("libs/Sfx"), require("libs/Placeables"), Ui
	end
end

M.defaultPowerupVars = function(version) -- do not change order
	if version == nil then -- v0.4
		-- local Trait, Type, onActivate, whileActive, getAllVehicles, createObject = Extender.defaultPowerupVars()
		return M.Traits, M.Types, PowerupReturns.onActivate, PowerupReturns.whileActive, M.getAllVehicles, createObject
		
	elseif version == 1 then -- v0.5
		-- local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)
		return M.Traits, M.Types, PowerupReturns.onActivate, PowerupReturns.whileActive, M.getAllVehicles, createObject, M.ActiveHotkeys, M.ActiveHotkeyStates, PowerupReturns.onHKey
	end
end

M.defaultGroupVars = function(version)
	if version == nil then -- enums
		-- local Type, onPickup, createObject = Extender.defaultGroupVars()
		return M.Types, GroupReturns.onPickup, createObject
		
	elseif version == 1 then -- v0.5
		-- local Type, onPickup, createObject, Default = Extender.defaultGroupVars(1)
		return M.Types, GroupReturns.onPickup, createObject, Defaults
	end
end

M.init = function()
	Util.tableReset(LOADED_ASSETS) -- necessary todo in case of map swap or hotreload
	
	M.loadAssets(
		"art/shapes/pwu/particles/powerupParticleData.json",
		"art/shapes/pwu/particles/powerupEmitterData.json",
		"art/shapes/pwu/spheres/materials.json"
	)
	
	-- some things need to be loaded in the right order, eg particle data before emitter data
	local files = Util.getFileListRecursive("art/shapes/pwu")
	for _, file in ipairs(files) do
		if Util.fileExtension(file):lower() == "json" then
			M.loadAssets(file:sub(2))
		end
	end
	Defaults.init()
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
		local target_pos = getObjectByID(target_id):getPosition()
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

M.isTraffic = function(game_vehicle_id)
	local vehicle = PowerUps.vehicles[game_vehicle_id]
	if vehicle then
		return vehicle.player_name == SUBJECT_TRAFFIC
	end
end

M.isSpectating = function(game_vehicle_id)
	local vehicle = getPlayerVehicle(0)
	if vehicle == nil then return end
	return vehicle:getId() == game_vehicle_id
end

M.isActive = function(...)
	for _, vehicle_id in pairs({...}) do
		if not getObjectByID(vehicle_id):getActive() then return false end
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
		function(veh_id, trigger_name)
			local vehicle = getObjectByID(veh_id)
			if not vehicle then -- vehicle vanished
				TimedTrigger.remove(trigger_name)
				return
			elseif not vehicle:getActive() then
				return
			end
			if #MathUtil.getVehiclesInsideRadius(vehicle:getPosition(), 5, veh_id) > 0 then
				TimedTrigger.updateTriggerEvery(trigger_name, 100)
				return
			end
			
			vehicle:setMeshAlpha(1, "", false)
			vehicle:queueLuaCommand('obj:setGhostEnabled(false)')
			
			TimedTrigger.remove(trigger_name)
		end,
		vehicle:getId(),
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

M.loadAssets = function(...)
	for _, asset_json in ipairs({...}) do
		if not LOADED_ASSETS[asset_json] then
			-- game engine function
			loadJsonMaterialsFile(asset_json)
			LOADED_ASSETS[asset_json] = true
		end
	end
end

M.fakeProjectile = function(pos_vec, size)
	local projectile = {int = {is_deleted = false, pos = pos_vec, size = size or 0.05}}
	function projectile:delete()
		self.int.is_deleted = true
	end
	function projectile:isDeleted()
		return self.int.is_deleted
	end
	function projectile:setPosition(pos_vec)
		self.int.pos = pos_vec
		debugDrawer:drawSphere(pos_vec, self.int.size, ColorF(0,0,0,1))
	end
	function projectile:getPosition()
		return self.int.pos
	end
	
	return projectile
end

M.getVehicleOwner = function(game_vehicle_id)
	local vehicle = PowerUps.vehicles[game_vehicle_id]
	if not vehicle then return end
	local player_name = vehicle.player_name
	if player_name == SUBJECT_SINGLEPLAYER then
		return "You"
	elseif player_name == SUBJECT_TRAFFIC then
		return getObjectByID(game_vehicle_id):getJBeamFilename() -- there must be a way to get the clear name
	elseif player_name == SUBJECT_UNKNOWN then
		return "Unknown"
	else
		return player_name
	end
end

M.safeIdTransfer = function(game_vehicle_id, server_vehicle_id)
	if game_vehicle_id then
		if not MPUtil.isBeamMPSession() then return game_vehicle_id end
		return MPUtil.gameVehicleIDToServerVehicleID(game_vehicle_id)
	elseif server_vehicle_id then
		if not MPUtil.isBeamMPSession() then return server_vehicle_id end
		return MPUtil.serverVehicleIDToGameVehicleID(server_vehicle_id)
	end
end

return M
