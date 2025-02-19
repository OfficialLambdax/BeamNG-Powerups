--[[
	License: None
	Author: Neverless (discord: neverless.)
]]
local PowerUps
local ServerUtil = Util -- only exists on server
local Util = require("libs/Util")
local MPUtil = require("mp_libs/MPUtil")
local PowerUpsTraits = require("libs/extender/Traits")
local PowerUpsTypes = require("libs/extender/Types")
local GroupReturns = require("libs/extender/GroupReturns")
local PowerupReturns = require("libs/extender/PowerupReturns")

local M = {}
M.Traits = PowerUpsTraits.Traits
M.TraitsLookup = Util.tableVToK(M.Traits)
--M.TraitBounds = PowerUpsTraits.TraitBounds
M.Types = PowerUpsTypes.Types
M.GroupReturns = GroupReturns
M.PowerupReturns = PowerupReturns

local SUBJECT_SINGLEPLAYER = "!singleplayer"
local SUBJECT_TRAFFIC = "!traffic"
local SUBJECT_UNKNOWN = "!unknown"


M.defaultImports = function() -- do not change order
	-- local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer = Extender.defaultImports()

	return require("libs/PowerUps"), require("libs/Util"), require("libs/Sets"), require("libs/Sounds"), require("libs/MathUtil"), require("libs/Pot"), require("libs/Log"), require("libs/TimedTrigger"), require("libs/CollisionsLib"), require("mp_libs/MPUtil"), require("mp_libs/PauseTimer")
end

M.defaultPowerupVars = function() -- do not change order
	-- local Trait, Type, onActivate, whileActive, getAllVehicles = Extender.defaultPowerupVars()
	
	return M.Traits, M.Types, PowerupReturns.onActivate, PowerupReturns.whileActive, M.getAllVehicles
end

M.defaultGroupVars = function()
	-- local Type, onPickup = Extender.defaultGroupVars()
	
	return M.Types, GroupReturns.onPickup
end

M.defaultPowerupCreator = function(trigger_obj, shape_path, color_point)
	local pos = trigger_obj:getPosition()

	local marker = createObject("TSStatic")
	marker.shapeName = shape_path
	marker.useInstanceRenderData = 1
	marker.instanceColor = color_point
	local rot = QuatF(0, 0, 0, 0)
	rot:setFromEuler(vec3(math.random(), math.random(), math.random()))
	marker:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
	--marker.scale = trigger_obj:getScale()
	marker.scale = vec3(2, 2, 2)
	
	marker:registerObject("my_powerup_" .. Util.randomName())
	
	return marker
end

M.defaultPowerupRender = function(marker_obj, dt)
	if marker_obj == nil then return end
	local pos = marker_obj:getPosition()
	local rot = marker_obj:getRotation():toEuler()
		
	rot.x = rot.x + (0.5 * dt)
	rot.y = rot.y + (0.5 * dt)
	local new_rot = QuatF(0, 0, 0, 0)
	new_rot:setFromEuler(rot)
	marker_obj:setPosRot(pos.x, pos.y, pos.z, new_rot.x, new_rot.y, new_rot.z, new_rot.w)
end

M.defaultPowerupDelete = function(marker_obj)
	if marker_obj then marker_obj:delete() end
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

M.updatePowerUpsLib = function(this)
	PowerUps = this
end


return M
