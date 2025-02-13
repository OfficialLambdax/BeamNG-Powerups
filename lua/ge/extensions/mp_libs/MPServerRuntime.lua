-- BeamMP Server only

local ServerUtil = Util
local Util = require("libs/Util")
local MPUtil = require("mp_libs/MPUtil")
local PowerUps = require("libs/PowerUps")
local Error = PowerUps.Error
local TimedTrigger = require("libs/TimedTrigger")
local PowerUpsTraits = require("libs/PowerUpsTraits")
local PowerUpsTypes = require("libs/PowerUpsTypes")
local PauseTimer = require("mp_libs/PauseTimer")

local Traits = PowerUpsTraits.Traits
local Types = PowerUpsTypes.Types

local LOCATIONS = PowerUps.locations
local VEHICLES = PowerUps.vehicles
local POWERUP_DEFS = PowerUps.powerup_defs


local M = {}

local LOCATION_PREFAB_NAME = ""
local POWERUP_SET_NAME = ""

---------------------------------------------------------------------------------------------
-- Better TriggerClientEvent
--[[ onPlayerReady based
	Format
		[players] = table
			["player_id"] = table
				[is_synced] = bool
]]
local TriggerClientEvent = {}
TriggerClientEvent.players = {}

function TriggerClientEvent:is_synced(player_id)
	return self.players[player_id] or false
end

function TriggerClientEvent:set_synced(player_id)
	self.players[player_id] = true
end

function TriggerClientEvent:remove(player_id)
	self.players[player_id] = nil
end

function TriggerClientEvent:send(player_id, event_name, event_data)
	local send_to = {}
	player_id = tonumber(player_id)
	if player_id ~= -1 then
		table.insert(send_to, player_id)
	else
		for player_id, _ in pairs(MP.GetPlayers()) do
			table.insert(send_to, player_id)
		end
	end
	for _, player_id in pairs(send_to) do
		if not self:is_synced(player_id) then
			--print(MP.GetPlayerName(player_id) .. " is not ready yet to receive event data")
		else
			if type(event_data) == "table" then event_data = ServerUtil.JsonEncode(event_data) end
			MP.TriggerClientEvent(player_id, event_name, tostring(event_data) or "")
		end
	end
end

function TriggerClientEvent:broadcastExcept(player_id, event_name, event_data)
	player_id = tonumber(player_id)
	for player_id_2, _ in pairs(MP.GetPlayers()) do
		if player_id ~= player_id_2 then
			if not self:is_synced(player_id_2) then
				--print(MP.GetPlayerName(player_id_2) .. " is not ready yet to receive event data")
			else
				if type(event_data) == "table" then event_data = Util.JsonEncode(event_data) end
				MP.TriggerClientEvent(player_id_2, event_name, tostring(event_data) or "")			
			end
		end
	end
end

-- ------------------------------------------------------------------------------------------------
-- Interface for the PowerUps lib
M.syncLocationUpdate = function(location_name)
	TriggerClientEvent:send(-1, "onLocationsPowerupUpdate", {{
		name = location_name,
		powerup_group = (LOCATIONS[location_name].powerup or {}).name -- saves us a if check, returns nil anyway
	}})
end

M.syncVehicleUpdate = function(server_vehicle_id, location_name)
	TriggerClientEvent:send(-1, "onVehiclesPowerupUpdate", {{
		server_vehicle_id = server_vehicle_id,
		powerup_group = (VEHICLES[server_vehicle_id].powerup or {}).name,
		charge = VEHICLES[server_vehicle_id].charge,
		location_name = location_name -- can be nil
	}})
end

-- ------------------------------------------------------------------------------------------------
-- From client
function tryTargetInfo(player_id, target_info)
	-- todo
	TriggerClientEvent:send(-1, "onTargetInfo", target_info)
end

function tryTargetHit(player_id, targets)
	-- todo
	print(targets)
	TriggerClientEvent:send(-1, "onTargetHit", targets)
end

function tryDisableActivePowerup(player_id, server_vehicle_id)
	if not player_id == -2 then
		local player_id2, vehicle_id = table.unpack(Util.split(server_vehicle_id, '-', 1))
		if player_id ~= player_id2 then
			Error('TryDisable: Got unexpected data from ' .. MP.GetPlayerName(player_id))
			return
		end
	end
	
	local vehicle = VEHICLES[server_vehicle_id]
	if vehicle == nil then
		Error('TryDisable: Unknown vehicle of ' .. MP.GetPlayerName(player_id))
		return
	end
	
	if vehicle.powerup_active == nil then
		Error('TryDisable: ' .. MP.GetPlayerName(player_id) .. ' has no active powerup')
		return
	end
	
	vehicle.powerup_active = nil
	TriggerClientEvent:send(-1, "onActivePowerupDisable", server_vehicle_id)
end

function tryActivatePowerup(player_id, server_vehicle_id)
	local player_id2, vehicle_id = table.unpack(Util.split(server_vehicle_id, '-', 1))
	if player_id ~= player_id2 then
		Error('TryActivate: Got unexpected data from ' .. MP.GetPlayerName(player_id))
		return
	end
	
	local vehicle = VEHICLES[server_vehicle_id]
	if vehicle == nil then
		Error('TryActivate: Unknown vehicle of ' .. MP.GetPlayerName(player_id))
		return
	end
	
	if vehicle.powerup == nil then
		Error('TryActivate: Vehicle of ' .. MP.GetPlayerName(player_id) .. ' has no powerup')
		return
	end
	
	if vehicle.powerup_active then
		Error('TryActivate: Vehicle of ' .. MP.GetPlayerName(player_id) .. ' already has a active powerup')
		return
	end
	
	-- select powerup
	local charge = math.min(vehicle.charge, vehicle.powerup.max_levels)
	local powerup_active = vehicle.powerup.powerups[charge]
	if powerup_active == nil then
		Error('TryActivate: Powerup group has no powerups')
		return
	end
	
	vehicle.powerup_active = powerup_active
	vehicle.powerup_active.max_len_timer = PauseTimer.new()
	vehicle.powerup = nil
	vehicle.charge = 1
	
	TriggerClientEvent:broadcastExcept(player_id, "onPowerupActivate", server_vehicle_id)
end

function tryTakePowerup(player_id, data)
	local data = ServerUtil.JsonDecode(data)
	
	-- unpack and verify origin 
	local server_vehicle_id = data.server_vehicle_id
	local player_id2, vehicle_id = table.unpack(Util.split(server_vehicle_id, '-', 1))
	if player_id ~= player_id2 then
		Error('TryTake: Got unexpected data from ' .. MP.GetPlayerName(player_id))
		return
	end
	
	-- try get location
	local location_name = data.location_name
	local location = LOCATIONS[location_name]
	if location == nil then
		Error('TryTake: Player ' .. MP.GetPlayerName(player_id) .. ' is trying to take a powerup from an unknown location')
		return
	end
	
	if location.powerup == nil then
		Error('TryTake: Location has no powerup ' .. MP.GetPlayerName(player_id) .. ' that wants to take from')
		return
	end
	
	-- try get vehicle
	local vehicle = VEHICLES[server_vehicle_id]
	if vehicle == nil then
		Error('TryTake: Vehicle of ' .. MP.GetPlayerName(player_id) .. ' is unknown')
		return
	end
	
	-- verify distance
	if Util.dist3d(MPUtil.getPosition(player_id, vehicle_id), location.obj:getPosition()) > 10 then
		Error('TryTake: Vehicle from ' .. MP.GetPlayerName(player_id) .. ' is to far away to take this powerup')
		return
	end
	
	-- swap ownership
	vehicle.powerup = location.powerup
	location.powerup = nil
	location.respawn_timer:stopAndReset()
	
	
	-- accept take
	M.syncVehicleUpdate(server_vehicle_id, location_name)
	-- no need to sync location update as the vehicle sync already consume the location on everyones client
	--M.syncLocationUpdate(
	
	-- special behaviour
	if vehicle.powerup.type == Types.Charge then
		vehicle.charge = vehicle.charge + 1
		
	elseif vehicle.powerup.type == Types.Negative then
		-- immediate exec
		tryActivatePowerup(player_id, server_vehicle_id)
	end
end

-- ------------------------------------------------------------------------------------------------
-- Routines
local function checkActivePowerups()
	for server_vehicle_id, vehicle in pairs(VEHICLES) do
		if vehicle.powerup_active then
			if vehicle.powerup_active.max_len_timer:stop() > vehicle.powerup_active.max_len then
				tryDisableActivePowerup(({Util.split(server_vehicle_id, '-', 1)})[1], server_vehicle_id)
			end
		end
	end
end

-- ------------------------------------------------------------------------------------------------
-- MP Events
function onPlayerReady(player_id) -- called by the client side mod
	--if TriggerClientEvent:is_synced(player_id) then return end
	TriggerClientEvent:set_synced(player_id)
	
	print("is ready")
	
	-- send location prefab
	TriggerClientEvent:send(player_id, "onLoadLocationPrefab", LOCATION_PREFAB_NAME)
	
	-- send powerup set
	TriggerClientEvent:send(player_id, "onLoadPowerupDefs", POWERUP_SET_NAME)

	-- send locations
	local locations = {}
	for location_name, location in pairs(LOCATIONS) do
		table.insert(locations, {
			name = location_name,
			powerup_group = (location.powerup or {}).name
		})
	end
	TriggerClientEvent:send(player_id, "onLocationsPowerupUpdate", locations)
	
	-- send which vehicle owns which powerup
	local vehicles = {}
	for server_vehicle_id, vehicle in pairs(VEHICLES) do
		table.insert(vehicles, {
			server_vehicle_id = server_vehicle_id,
			powerup_group = (vehicle.powerup or {}).name,
			charge = vehicle.charge
		})
	end
	TriggerClientEvent:send(player_id, "onVehiclesPowerupUpdate", vehicles)
end

function onVehicleSpawn(player_id, vehicle_id, data)
	PowerUps.onVehicleSpawned(player_id .. '-' .. vehicle_id)
end

function onVehicleDeleted(player_id, vehicle_id)
	PowerUps.onVehicleDestroyed(player_id .. '-' .. vehicle_id)
end

function onPlayerDisconnected(player_id)
	for _, vehicle_id in ipairs(MP.GetPlayerVehicles() or {}) do
		PowerUps.onVehicleDestroyed(player_id .. '-' .. vehicle_id)
	end
	TriggerClientEvent:remove(player_id)
end

-- ------------------------------------------------------------------------------------------------
-- Base Routine
function baseRoutine()
	TimedTrigger.tick()
	
end

-- ------------------------------------------------------------------------------------------------
-- Entry Point
M.init = function(location_prefab_name, powerup_set_name)
	PowerUps.init()
	PowerUps.updateMPServerRuntime(M)
	
	TimedTrigger.new(
		"powerups_checkactivepowerups",
		1000,
		0,
		checkActivePowerups
	)
	
	LOCATION_PREFAB_NAME = location_prefab_name
	POWERUP_SET_NAME = powerup_set_name
	
	PowerUps.loadLocationPrefab(Util.myPath() .. '../prefabs/' .. location_prefab_name)
	PowerUps.loadPowerUpDefs(Util.myPath() .. '../powerups/' .. powerup_set_name)
	
	-- base routine
	MP.RegisterEvent("mpruntime", "baseRoutine")
	MP.CancelEventTimer("mpruntime")
	MP.CreateEventTimer("mpruntime", 100)
	
	-- custom events
	MP.RegisterEvent("onPlayerReady", "onPlayerReady")
	MP.RegisterEvent("tryTakePowerup", "tryTakePowerup")
	MP.RegisterEvent("tryActivatePowerup", "tryActivatePowerup")
	MP.RegisterEvent("tryDisableActivePowerup", "tryDisableActivePowerup")
	MP.RegisterEvent("tryTargetInfo", "tryTargetInfo")
	MP.RegisterEvent("tryTargetHit", "tryTargetHit")
	
	-- server events
	MP.RegisterEvent("onVehicleSpawn", "onVehicleSpawn")
	MP.RegisterEvent("onVehicleDeleted", "onVehicleDeleted")
	MP.RegisterEvent("onPlayerDisconnected", "onPlayerDisconnected")
	
	-- hotreload
	for player_id, player_name in pairs(MP.GetPlayers()) do
		MP.TriggerClientEvent(player_id, "onCompleteReset", "")
		for vehicle_id, data in pairs(MP.GetPlayerVehicles(player_id) or {}) do
			onVehicleSpawn(player_id, vehicle_id, data)
		end
	end
end

return M
