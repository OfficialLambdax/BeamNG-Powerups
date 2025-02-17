-- BeamMP Server only. Do not load inside client.

local ServerUtil = Util
local Util = require("libs/Util")
local MPUtil = require("mp_libs/MPUtil")
local PowerUps = require("libs/PowerUps")
local TimedTrigger = require("libs/TimedTrigger")
local PowerUpsTraits = require("libs/PowerUpsTraits")
local PowerUpsTypes = require("libs/PowerUpsTypes")
local PauseTimer = require("mp_libs/PauseTimer")
local TriggerClientEvent = require("mp_libs/TriggerClientEvent") -- is_synced when onPlayerReady
local Log = require("libs/Log")
local CompileLua = require("mp_libs/CompileLua")

local Traits = PowerUpsTraits.Traits
local Types = PowerUpsTypes.Types

local LOCATIONS = PowerUps.locations
local VEHICLES = PowerUps.vehicles
local POWERUP_DEFS = PowerUps.powerup_defs


local M = {}

local LOCATION_PREFAB_NAME = ""
local POWERUP_SET_NAME = ""

-- ------------------------------------------------------------------------------------------------
-- Response builer
local Build = {int = {
		players = {},
		event = nil,
		data = nil
	}
}

function Build:new()
	self.int.players = {}
	self.int.event = nil
	self.int.data = nil
	return self
end

function Build:toT(players) -- append method
	for _, player_id in ipairs(players) do
		table.insert(self.int.players, player_id)
	end
	return self
end

function Build:all()
	for player_id, _ in pairs(MP.GetPlayers()) do
		self:to(player_id)
	end
	return self
end

function Build:allExcept(player_id)
	for player_id2, _ in pairs(MP.GetPlayers()) do
		if player_id ~= player_id2 then
			self:to(player_id2)
		end
	end
	return self
end

function Build:to(...)
	self:toT({...})
	return self
end

function Build:send()
	TriggerClientEvent:sendTo(self.int.players, self.int.event, self.int.data)
end

function Build:sendIfData()
	if self.int.data then
		TriggerClientEvent:sendTo(self.int.players, self.int.event, self.int.data)
	end
end

function Build:onCompleteReset()
	self.int.event = "onCompleteReset"
	return self
end

function Build:onTargetInfo(target_info)
	self.int.event = "onTargetInfo"
	self.int.data = target_info
	return self
end

function Build:onTargetHit(targets)
	self.int.event = "onTargetHit"
	self.int.data = targets
	return self
end

function Build:onActivePowerupDisable(server_vehicle_id)
	self.int.event = "onActivePowerupDisable"
	self.int.data = server_vehicle_id
	return self
end

function Build:onPowerupActivate(server_vehicle_id)
	self.int.event = "onPowerupActivate"
	self.int.data = server_vehicle_id
	return self
end

function Build:onPowerupActivate(server_vehicle_id, charge_overwrite)
	self.int.event = "onPowerupActivate"
	self.int.data = {
		server_vehicle_id = server_vehicle_id,
		charge_overwrite = charge_overwrite
	}
	return self
end

function Build:onLoadPowerupDefs(set_name)
	self.int.event = "onLoadPowerupDefs"
	self.int.data = set_name
	return self
end

function Build:onLoadLocationPrefab(prefab_name)
	self.int.event = "onLoadLocationPrefab"
	self.int.data = prefab_name
	return self
end

function Build:onLocationsPowerupUpdate(location_name) -- append_method
	self.int.event = "onLocationsPowerupUpdate"
	if self.int.data == nil then self.int.data = {} end
	table.insert(self.int.data, {
		name = location_name,
		powerup_group = (LOCATIONS[location_name].powerup or {}).name
	})
	return self
end

--[[
	server_vehicle_id = X-Y
	location_name = nil/location_name (if nil then powerup is dropped by player. If given the players inherits the powerup from this location)
	overwrite = nil/powerup_group_name (if given this group is picked up by the player, dropping whatever they may have - if the this powerup group can be picked up)
]]
function Build:onVehiclesPowerupUpdate(server_vehicle_id, location_name, powerup_overwrite) -- append method
	self.int.event = "onVehiclesPowerupUpdate"
	if self.int.data == nil then self.int.data = {} end
	table.insert(self.int.data, {
		server_vehicle_id = server_vehicle_id,
		powerup_group = powerup_overwrite or (VEHICLES[server_vehicle_id].powerup or {}).name,
		location_name = location_name,
		charge = VEHICLES[server_vehicle_id].charge or 1
	})
	return self
end

-- ------------------------------------------------------------------------------------------------
-- Common
local function takePowerup(server_vehicle_id, location_name)
	local location = LOCATIONS[location_name]
	if location == nil or location.powerup == nil then return end
	
	local player_id = MPUtil.getPlayerIDFromServerID(server_vehicle_id)
	
	local vehicle = VEHICLES[server_vehicle_id]
	if vehicle == nil then
		Log.warn('Vehicle of ' .. MP.GetPlayerName(player_id) .. ' is unknown')
		return
	end
	
	local type = location.powerup.type
	if type == Types.Charge then
		vehicle.charge = math.min(vehicle.charge + 1, PowerUps.getMaxCharge())
		Build:new():all():onVehiclesPowerupUpdate(server_vehicle_id, location_name, location.powerup.name):send()
		location.powerup = nil
		location.respawn_timer:stopAndReset()
		
		Log.info(server_vehicle_id .. ' from "' .. MP.GetPlayerName(player_id) .. '" now has ' .. vehicle.charge .. ' charges')
		
	elseif type == Types.Negative then
		-- swap ownership
		vehicle.powerup = location.powerup
		location.powerup = nil
		location.respawn_timer:stopAndReset()
		
		Log.info(server_vehicle_id .. ' from "' .. MP.GetPlayerName(player_id) .. '" picked up negative ' .. vehicle.powerup.name)
		
		Build:new():all():onVehiclesPowerupUpdate(server_vehicle_id, location_name):send()
		tryActivatePowerup(player_id, server_vehicle_id)
		
	else
		-- swap ownership
		vehicle.powerup = location.powerup
		location.powerup = nil
		location.respawn_timer:stopAndReset()
		
		Log.info(server_vehicle_id .. ' from "' .. MP.GetPlayerName(player_id) .. '" picked up ' .. vehicle.powerup.name)
		
		Build:new():all():onVehiclesPowerupUpdate(server_vehicle_id, location_name):send()
	end
end

local function givePowerup(server_vehicle_id, group_name)
	local vehicle = VEHICLES[server_vehicle_id]
	if vehicle == nil then return end
	
	local powerup = POWERUP_DEFS[group_name]
	if powerup == nil then return end
	
	local player_id = MPUtil.getPlayerIDFromServerID(server_vehicle_id)
	
	vehicle.powerup = powerup
	
	Log.info(server_vehicle_id .. ' from "' .. MP.GetPlayerName(player_id) .. '" picked up ' .. vehicle.powerup.name)
	
	Build:new():all():onVehiclesPowerupUpdate(server_vehicle_id):send()
end

local function dropPowerup(server_vehicle_id)
	local vehicle = VEHICLES[server_vehicle_id]
	if vehicle == nil or vehicle.powerup == nil then return end
	
	vehicle.powerup = nil
	Build:new():all():onVehiclesPowerupUpdate(server_vehicle_id, nil, nil):send()
end

local function activatePowerup(server_vehicle_id, charge_overwrite)
	local player_id = MPUtil.getPlayerIDFromServerID(server_vehicle_id)
	
	local vehicle = VEHICLES[server_vehicle_id]
	if vehicle == nil then
		Log.error('Unknown vehicle of ' .. MP.GetPlayerName(player_id))
		return
	end
	
	if vehicle.powerup == nil then
		Log.warn('Vehicle of ' .. MP.GetPlayerName(player_id) .. ' has no powerup')
		return
	end
	
	if vehicle.powerup_active then
		Log.warn('Vehicle of ' .. MP.GetPlayerName(player_id) .. ' already has a active powerup')
		return
	end
	
	local is_negative = vehicle.powerup.type == Types.Negative
	local group_name = vehicle.powerup.name
	
	-- select powerup
	local powerup_active
	local charge
	if is_negative then
		charge = math.random(1, vehicle.powerup.max_levels)
		powerup_active = vehicle.powerup.powerups[charge]
	else
		charge = math.min(vehicle.charge, vehicle.powerup.max_levels)
		powerup_active = vehicle.powerup.powerups[charge]
	end
	
	-- select powerup
	if powerup_active == nil then
		Log.error('Powerup group "' .. vehicle.powerup.name .. '" has no powerups')
		return
	end
	
	vehicle.powerup_active = powerup_active
	vehicle.powerup_active.max_len_timer = PauseTimer.new()
	vehicle.powerup = nil
	
	if not is_negative then
		vehicle.charge = 1
		Build:new():all():onPowerupActivate(server_vehicle_id, charge_overwrite):send()
		
		Log.info(server_vehicle_id .. ' from "' .. MP.GetPlayerName(player_id) .. '" activated ' .. vehicle.powerup_active.internal_name)
	else
		Build:new():all():onPowerupActivate(server_vehicle_id, charge_overwrite or charge):send()
		
		Log.info(server_vehicle_id .. ' from "' .. MP.GetPlayerName(player_id) .. '" activated negative ' .. vehicle.powerup_active.internal_name)
	end
	
	return true
end

local function disableActivePowerup(server_vehicle_id, from_client)
	local player_id = MPUtil.getPlayerIDFromServerID(server_vehicle_id)
	
	local vehicle = VEHICLES[server_vehicle_id]
	if vehicle == nil then
		Log.error('Unknown vehicle of ' .. MP.GetPlayerName(player_id))
		return
	end
	
	if vehicle.powerup_active == nil then
		Log.warn('Vehicle of ' .. MP.GetPlayerName(player_id) .. ' has no active powerup')
		return
	end
	
	Log.info(server_vehicle_id .. ' from "' .. MP.GetPlayerName(player_id) .. '" disabled ' .. vehicle.powerup_active.internal_name .. ' after ' .. Util.mathRound(vehicle.powerup_active.max_len_timer:stop() / 1000, 3) .. ' seconds')
	
	vehicle.powerup_active = nil
	if from_client then
		Build:new():allExcept(player_id):onActivePowerupDisable(server_vehicle_id):send()
	else
		Build:new():all():onActivePowerupDisable(server_vehicle_id):send()
	end
end

-- ------------------------------------------------------------------------------------------------
-- Interface for the PowerUps lib
M.syncLocationUpdate = function(location_name)
	Build:new():all():onLocationsPowerupUpdate(location_name):send()
end

M.syncVehicleUpdate = function(server_vehicle_id, location_name, overwrite)
	Build:new():all():onVehiclesPowerupUpdate(server_vehicle_id, location_name, overwrite):send()
end

-- ------------------------------------------------------------------------------------------------
-- From client
function tryTargetInfo(player_id, target_info)
	local decode = ServerUtil.JsonDecode(target_info)
	local player_id2, vehicle_id = table.unpack(Util.split(decode.server_vehicle_id, '-', 1))
	if player_id ~= player_id2 then
		Log.error('Got unexpected data form ' .. MP.GetPlayerName(player_id))
		return
	end
	
	local vehicle = VEHICLES[decode.server_vehicle_id]
	if vehicle == nil then
		Log.error('Unknown vehicle of ' .. MP.GetPlayerName(player_id))
		return
	end
	
	if not vehicle.powerup_active then
		Log.warn('No active powerup from ' .. MP.GetPlayerName(player_id))
		Build:new():to(player_id):onActivePowerupDisable(decode.server_vehicle_id):send()
		return
	end
	
	Build:new():all():onTargetInfo(target_info):send()
end

function tryTargetHit(player_id, targets)
	local decode = ServerUtil.JsonDecode(targets)
	local player_id2, vehicle_id = table.unpack(Util.split(decode.server_vehicle_id, '-', 1))
	if player_id ~= player_id2 then
		Log.error('Got unexpected data form ' .. MP.GetPlayerName(player_id))
		return
	end
	
	local vehicle = VEHICLES[decode.server_vehicle_id]
	if vehicle == nil then
		Log.error('Unknown vehicle of ' .. MP.GetPlayerName(player_id))
		return
	end
	
	if not vehicle.powerup_active then
		Log.warn('No active powerup from ' .. MP.GetPlayerName(player_id))
		Build:new():to(player_id):onActivePowerupDisable(decode.server_vehicle_id):send()
		return
	end
	
	Build:new():all():onTargetHit(targets):send()
end

function tryDisableActivePowerup(player_id, server_vehicle_id)
	if not player_id == -2 then
		local player_id2, vehicle_id = table.unpack(Util.split(server_vehicle_id, '-', 1))
		if player_id ~= player_id2 then
			Log.error('Got unexpected data from ' .. MP.GetPlayerName(player_id))
			return
		end
	end
	
	disableActivePowerup(server_vehicle_id, true)
end

function tryActivatePowerup(player_id, server_vehicle_id)
	local player_id2, vehicle_id = table.unpack(Util.split(server_vehicle_id, '-', 1))
	if player_id ~= player_id2 then
		Log.error('Got unexpected data from ' .. MP.GetPlayerName(player_id))
		return
	end
	
	if not activatePowerup(server_vehicle_id) then
		Build:new():to(player_id):onActivePowerupDisable(server_vehicle_id):send()
	end
end

function tryTakePowerup(player_id, data)
	local data = ServerUtil.JsonDecode(data)
	
	-- unpack and verify origin 
	local server_vehicle_id = data.server_vehicle_id
	local player_id2, vehicle_id = table.unpack(Util.split(server_vehicle_id, '-', 1))
	if player_id ~= player_id2 then
		Log.warn('Got unexpected data from ' .. MP.GetPlayerName(player_id))
		return
	end
	
	-- try get location
	local location_name = data.location_name
	local location = LOCATIONS[location_name]
	if location == nil then
		Log.warn('Player ' .. MP.GetPlayerName(player_id) .. ' is trying to take a powerup from an unknown location')
		return
	end
	
	if location.powerup == nil then
		Log.warn('Location has no powerup that ' .. MP.GetPlayerName(player_id) .. ' wants to take from')
		return
	end
	
	-- try get vehicle
	local vehicle = VEHICLES[server_vehicle_id]
	if vehicle == nil then
		Log.warn('Vehicle of ' .. MP.GetPlayerName(player_id) .. ' is unknown')
		return
	end
	
	-- verify distance
	if Util.dist3d(MPUtil.getPosition(player_id, vehicle_id), location.obj:getPosition()) > 10 then
		Log.warn('Vehicle from ' .. MP.GetPlayerName(player_id) .. ' is to far away to take this powerup')
		return
	end
	
	takePowerup(server_vehicle_id, location_name)
end

-- ------------------------------------------------------------------------------------------------
-- Routines
local function checkActivePowerups()
	for server_vehicle_id, vehicle in pairs(VEHICLES) do
		if vehicle.powerup_active then
			if vehicle.powerup_active.max_len_timer:stop() > vehicle.powerup_active.max_len then
				Log.warn('Removed overdue ' .. vehicle.powerup_active.internal_name .. ' active powerup from ' .. server_vehicle_id .. ' after ' .. Util.mathRound(vehicle.powerup_active.max_len_timer:stop() / 1000, 3) .. ' seconds')
				
				disableActivePowerup(server_vehicle_id)
			end
		end
	end
end

-- this should rather only be shown on command
local function displayServerState()
	local players = Util.tableSize(MP.GetPlayers())
	if players == 0 then return end
	local mem = Util.mathRound(MP.GetStateMemoryUsage() / 1048576, 2)
	local vehicles = PowerUps.getKnownVehicleCount()
	local triggers = TimedTrigger.count()
	local reuse = TimedTrigger.getReuseCount()
	local spawned = PowerUps.getTotalSpawnedPowerups()
	local owned = PowerUps.getTotalOwnedPowerups()
	local active = PowerUps.getTotalActivePowerups()
	local locations = PowerUps.getTotalLocations()
	local rotation = math.floor(PowerUps.getRotationTime() / 1000)
	local rotation_routine = PowerUps.getRotationRoutineTime()
	local restock = math.floor(PowerUps.getRestockTime() / 1000)
	
	local info = string.format([[

	General   _
		Mem usage       : %s MB
		Triggers        : %s		Reuse   : %s
		Players         : %s		Vehicles: %s
	Locations _
		Total           : %s		Restock Time    : %s s
		Rotation        : %s s		Rotation Routine: %s ms
	Powerups  _
		Spawned         : %s
		Owned           : %s
		Active          : %s
	List      _]],
		mem, triggers, reuse, players, vehicles,
		locations, restock, rotation, rotation_routine,
		spawned, owned, active
	)
	for _, group in ipairs(PowerUps.getPowerupGroups()) do
		local total = PowerUps.getSpawnCountByGroup(group)
		local percentil = math.floor((total / spawned) * 100)
		info = info .. '\n' ..
			'\t\t' .. total .. ' (' .. percentil .. ' %)\t: ' .. group
	end
	
	Log.info(info)
end

-- ------------------------------------------------------------------------------------------------
-- MP Events
function onPlayerReady(player_id) -- called by the client side mod
	if TriggerClientEvent:is_synced(player_id) then return end
	TriggerClientEvent:set_synced(player_id)
	
	--print(MP.GetPlayerName(player_id) .. " is ready")
	Log.info('Player "' .. MP.GetPlayerName(player_id) .. '" signals to be ready')
	
	-- send location prefab
	if LOCATION_PREFAB_NAME:len() > 0 then
		Build:new():to(player_id):onLoadLocationPrefab(LOCATION_PREFAB_NAME):send()
	end
	
	-- send powerup set
	if POWERUP_SET_NAME:len() > 0 then
		Build:new():to(player_id):onLoadPowerupDefs(POWERUP_SET_NAME):send()
	end
	
	-- send locations
	local build = Build:new():to(player_id)
	for location_name, location in pairs(LOCATIONS) do
		build:onLocationsPowerupUpdate(location_name)
	end
	build:sendIfData()
	
	-- dev test
	--local vehicle = VEHICLES["0-0"]
	--vehicle.powerup = POWERUP_DEFS["shockwave"]
	
	-- send which vehicle owns which powerup
	local build = Build:new():to(player_id)
	for server_vehicle_id, vehicle in pairs(VEHICLES) do
		build:onVehiclesPowerupUpdate(server_vehicle_id, nil, (vehicle.powerup or {}).name)
	end
	build:sendIfData()
end

function onVehicleSpawn(player_id, vehicle_id, data)
	Log.info('New vehicle ' .. player_id .. '-' .. vehicle_id .. ' from "' .. MP.GetPlayerName(player_id) .. '"')
	PowerUps.onVehicleSpawned(player_id .. '-' .. vehicle_id)
end

function onVehicleDeleted(player_id, vehicle_id)
	Log.info('Deleted vehicle from "' .. MP.GetPlayerName(player_id) .. '"')
	PowerUps.onVehicleDestroyed(player_id .. '-' .. vehicle_id)
end

function onPlayerDisconnected(player_id)
	Log.info('Player "' .. MP.GetPlayerName(player_id) .. '" disconnected')
	for _, vehicle_id in ipairs(MP.GetPlayerVehicles(player_id) or {}) do
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
-- API
--[[
	Can access this from the same state by simply using
		PowerUpsApi.exec()
	or when from another state
		MP.TriggerGlobalEvent("PowerUpsApi_exec", "0-0", "forcefield", 1)
]]
local A = {}
A.reset = function()
	LOCATION_PREFAB_NAME = ""
	POWERUP_SET_NAME = ""
	PowerUps.unload()
	PowerUps.init()
	for player_id, _ in pairs(MP.GetPlayers()) do
		MP.TriggerClientEvent(player_id, "onCompleteReset", "")
	end
end

A.loadPowerups = function(location_prefab_name, powerup_set_name)
	LOCATION_PREFAB_NAME = location_prefab_name
	POWERUP_SET_NAME = powerup_set_name
	PowerUps.loadLocationPrefab(Util.myPath() .. '../prefabs/' .. location_prefab_name)
	PowerUps.loadPowerUpDefs(Util.myPath() .. '../powerups/' .. powerup_set_name)
	
	Build:new():all():onLoadLocationPrefab(LOCATION_PREFAB_NAME):send()
	Build:new():all():onLoadPowerupDefs(POWERUP_SET_NAME):send()
end

A.exec = function(server_vehicle_id, group_name, level)
	A.givePowerup(server_vehicle_id, group_name)
	A.activatePowerup(server_vehicle_id, level)
end

A.takePowerup = function(server_vehicle_id, location_name)
	takePowerup(server_vehicle_id, location_name)
end

A.givePowerup = function(server_vehicle_id, group_name)
	givePowerup(server_vehicle_id, group_name)
end

A.dropPowerup = function(server_vehicle_id)
	dropPowerup(server_vehicle_id)
end

A.getCharge = function(server_vehicle_id)
	local vehicle = VEHICLES[server_vehicle_id]
	if vehicle == nil then return end
	
	return vehicle.charge
end

-- doesnt sync yet
A.setCharge = function(server_vehicle_id, level)
	local vehicle = VEHICLES[server_vehicle_id]
	if vehicle == nil then return end
	
	vehicle.charge = math.min(level, PowerUps.getMaxCharge())
end

A.getPowerup = function(server_vehicle_id)
	local vehicle = VEHICLES[server_vehicle_id]
	if vehicle == nil then return end
	
	return vehicle.powerup
end

A.activatePowerup = function(server_vehicle_id, charge_overwrite)
	activatePowerup(server_vehicle_id, charge_overwrite)
end

A.disableActivePowerup = function(server_vehicle_id)
	disableActivePowerup(server_vehicle_id)
end

-- ------------------------------------------------------------------------------------------------
-- Entry Point
M.init = function(location_prefab_name, powerup_set_name)
	-- this is the case when another file in this lua state get reloaded and the server is of the opinion to also reinit the ServerSide.lua
	if CompileLua.init == nil then return end
	
	Log.info("Loading")
	
	local my_path = Util.filePath(Util.myPath():sub(1, -2))
	CompileLua.init(
		my_path,
		my_path .. 'libs/TimedTrigger.lua',
		my_path .. 'libs/Sets.lua',
		my_path .. 'mp_libs/CompileLua.lua'
	)
	
	PowerUps.init()
	PowerUps.updateMPServerRuntime(M)
	
	TimedTrigger.new(
		"PowerUps_checkActivePowerups",
		1000,
		0,
		checkActivePowerups
	)
	
	TimedTrigger.new(
		"PowerUps_displayServerState",
		60000,
		0,
		displayServerState
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
	MP.RegisterEvent("onPlayerDisconnect", "onPlayerDisconnected")
	
	-- API
	PowerUpsApi = {} -- global
	API = {} -- temp global
	for api, func in pairs(A) do
		API = func
		load('PowerUpsApi_' .. api .. ' = API')()
		MP.RegisterEvent('PowerUpsApi_' .. api, 'PowerUpsApi_' .. api)
		PowerUpsApi[api] = func
	end
	API = nil
	
	-- hotreload
	for player_id, player_name in pairs(MP.GetPlayers()) do
		Log.info("Hotreloading player: " .. player_name)
		MP.TriggerClientEvent(player_id, "onCompleteReset", "")
		for vehicle_id, data in pairs(MP.GetPlayerVehicles(player_id) or {}) do
			Log.info("Hotreloading vehicle: " .. player_id .. "-" .. vehicle_id)
			onVehicleSpawn(player_id, vehicle_id, data)
		end
	end
	
	Log.info("Loaded")
end

return M
