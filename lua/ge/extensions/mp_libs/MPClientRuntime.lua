local MPUtil = require("mp_libs/MPUtil")
local Log = require("libs/Log")

local PowerUps
local Error
local LOCATIONS
local VEHICLES
local POWERUP_DEFS

local M = {}


-- ------------------------------------------------------------------------------------------------
-- To server
M.tryTakePowerup = function(location_name, game_vehicle_id)
	if not MPUtil.isOwn(game_vehicle_id) then return end
	TriggerServerEvent("tryTakePowerup", jsonEncode({
		location_name = location_name,
		server_vehicle_id = MPUtil.gameVehicleIDToServerVehicleID(game_vehicle_id)
	}))
end

M.tryActivatePowerup = function(game_vehicle_id)
	if not MPUtil.isOwn(game_vehicle_id) then return end
	TriggerServerEvent("tryActivatePowerup", MPUtil.gameVehicleIDToServerVehicleID(game_vehicle_id))
end

M.tryDisableActivePowerup = function(game_vehicle_id)
	if not MPUtil.isOwn(game_vehicle_id) then return end
	TriggerServerEvent("tryDisableActivePowerup", MPUtil.gameVehicleIDToServerVehicleID(game_vehicle_id))
end

M.tryTargetInfo = function(game_vehicle_id, target_info)
	if not MPUtil.isOwn(game_vehicle_id) then return end
	TriggerServerEvent("tryTargetInfo", jsonEncode({
		server_vehicle_id = MPUtil.gameVehicleIDToServerVehicleID(game_vehicle_id),
		target_info = target_info
	}))
end

M.tryTargetHit = function(game_vehicle_id, targets, deactivate)
	if not MPUtil.isOwn(game_vehicle_id) then return end
	local converted_targets = {}
	for index, target_id in ipairs(targets) do
		converted_targets[index] = MPUtil.gameVehicleIDToServerVehicleID(target_id)
	end

	TriggerServerEvent("tryTargetHit", jsonEncode({
		server_vehicle_id = MPUtil.gameVehicleIDToServerVehicleID(game_vehicle_id),
		targets = converted_targets,
		deactivate = deactivate
	}))
end

-- ------------------------------------------------------------------------------------------------
-- From server
local function onCompleteReset()
	Log.info("Multiplayer complete reset")
	PowerUps.unload()
	PowerUps.init()
end

local function onTargetInfo(data)
	local data = jsonDecode(data)
	local game_vehicle_id = MPUtil.serverVehicleIDToGameVehicleID(data.server_vehicle_id)
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle == nil then return end
	if vehicle.powerup_active == nil then return end
	
	PowerUps.targetInfoExec(vehicle, data.target_info)
end

local function onTargetHit(data)
	local data = jsonDecode(data)
	local game_vehicle_id = MPUtil.serverVehicleIDToGameVehicleID(data.server_vehicle_id)
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle == nil then return end
	if vehicle.powerup_active == nil then return end
	
	local targets = {}
	for index, server_vehicle_id in ipairs(data.targets) do
		targets[index] = MPUtil.serverVehicleIDToGameVehicleID(server_vehicle_id)
	end
	
	PowerUps.targetHitExec(game_vehicle_id, vehicle, targets, data.deactivate)
end

local function onActivePowerupDisable(server_vehicle_id)
	local game_vehicle_id = MPUtil.serverVehicleIDToGameVehicleID(server_vehicle_id)
	if game_vehicle_id == nil then return end
	
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle == nil then return end
	
	if vehicle.powerup_active == nil then return end
	
	vehicle.powerup_active.onDeactivate(vehicle.powerup_data, game_vehicle_id)
	vehicle.powerup_active = nil
	vehicle.powerup_data = nil
end

local function onPowerupActivate(data)
	local data = jsonDecode(data)
	local game_vehicle_id = MPUtil.serverVehicleIDToGameVehicleID(data.server_vehicle_id)
	if game_vehicle_id == nil then return end
	PowerUps.activatePowerup(game_vehicle_id, true, data.charge_overwrite)
end

local function onLoadPowerupDefs(set_name)
	Log.info('Multiplayer powerup defs: lua/ge/extensions/powerups/' .. set_name)
	PowerUps.loadPowerUpDefs('lua/ge/extensions/powerups/' .. set_name)
end

local function onLoadLocationPrefab(prefab_name)
	Log.info('Multiplayer location prefab: lua/ge/extensions/prefabs/' .. prefab_name)
	PowerUps.loadLocationPrefab('lua/ge/extensions/prefabs/' .. prefab_name)
end

local function onLocationsPowerupUpdate(locations)
	local locations = jsonDecode(locations)
	for _, location_update in ipairs(locations) do
		local location = LOCATIONS[location_update.name]
		if location then
			if location.powerup then location.powerup.onDespawn(location.data) end
			
			location.powerup = POWERUP_DEFS[location_update.powerup_group]
			if location.powerup then
				location.data = location.powerup.onCreate(location.obj)
			end
			
		else
			-- error
		end
	end
end

local function onVehiclesPowerupUpdate(vehicles)
	local vehicles = jsonDecode(vehicles)
	for _, vehicle_update in ipairs(vehicles) do
		local game_vehicle_id = MPUtil.serverVehicleIDToGameVehicleID(vehicle_update.server_vehicle_id)
		
		if game_vehicle_id then
			local vehicle = VEHICLES[game_vehicle_id]
			if vehicle then -- can be the case for disabled traffic vehicles
				vehicle.charge = vehicle_update.charge
			
				if vehicle_update.powerup_group == nil then
					if vehicle.powerup then
						vehicle.powerup.onDrop(vehicle.powerup.data)
						vehicle.powerup = nil
					end
					
				else
					PowerUps.vehicleAddPowerup(
						game_vehicle_id,
						POWERUP_DEFS[vehicle_update.powerup_group],
						LOCATIONS[vehicle_update.location_name] -- can be nil
					)
				end
			end
		else
			-- error
		end
	end
end

-- ------------------------------------------------------------------------------------------------
-- Init
local REGISTERED_EVENTS = false
M.init = function()
	if not REGISTERED_EVENTS then
		AddEventHandler("onCompleteReset", onCompleteReset)
		AddEventHandler("onPowerupActivate", onPowerupActivate)
		AddEventHandler("onActivePowerupDisable", onActivePowerupDisable)
		AddEventHandler("onLoadPowerupDefs", onLoadPowerupDefs)
		AddEventHandler("onLoadLocationPrefab", onLoadLocationPrefab)
		AddEventHandler("onLocationsPowerupUpdate", onLocationsPowerupUpdate)
		AddEventHandler("onVehiclesPowerupUpdate", onVehiclesPowerupUpdate)
		AddEventHandler("onTargetInfo", onTargetInfo)
		AddEventHandler("onTargetHit", onTargetHit)
		
		REGISTERED_EVENTS = true
	end
	
	TriggerServerEvent("onPlayerReady", "")
end

M.updatePowerUpsLib = function(this)
	PowerUps = this
	LOCATIONS = this.locations
	VEHICLES = this.vehicles
	POWERUP_DEFS = this.powerup_defs
	Error = this.Error
end

return M
