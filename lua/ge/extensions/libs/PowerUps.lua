--[[
	License: None
	Author: Neverless (discord: neverless.)
]]
local Extender = require("libs/PowerUpsExtender")
local Traits = Extender.Traits
local Types = Extender.Types
local GroupReturns = Extender.GroupReturns
local PowerupReturns = Extender.PowerupReturns
local TimedTrigger = require("libs/TimedTrigger")
local TriggerLoad = require("libs/TriggerLoad")
local Util = require("libs/Util")
local MPUtil = require("mp_libs/MPUtil")
local MPClientRuntime = require("mp_libs/MPClientRuntime")
local MPServerRuntime -- filled only if loaded on server
local PauseTimer = require("mp_libs/PauseTimer")
local Log = require("libs/Log")
local Sound = require("libs/Sounds")
local Pot = require("libs/Pot")

local M = {
	_VERSION = 0.3, -- 13.02.2025 DD.MM.YYYY
	_BRANCH = "alpha",
	_NAME = "enums"
}
local VEC3 = vec3 or function(x, y, z) return {x = x, y = y, z = z} end -- server compat
local RESPAWN_TIME = 30000
local ROTATION_TIME = 180000
local RENDER_DISTANCE = 500
local PICKUP_DOWNTIME = 500
local MAX_CHARGE = 0 -- updated based on the loaded set

local ROUTINE_LOCATIONS_RESTOCK = 5000
local ROUTINE_LOCATIONS_ROTATION = 5000 -- dynamic (ROTATION_TIME / #LOCATIONS). Max is 5000

local ROUTINE_POWERUPS_CHECK_RENDER_DISTANCE = 1000
local ROUTINE_POWERUPS_CHECK_TRAFFIC = 10000
local ROUTINE_POWERUPS_BASIC_DISPLAY_REFRESH = 5000

-- these vars also exist in the extender. if change then also update there
local SUBJECT_SINGLEPLAYER = "!singleplayer"
local SUBJECT_TRAFFIC = "!traffic"
local SUBJECT_UNKNOWN = "!unknown"

local TEMP_PICKUP_SOUND = Sound("/lua/ge/extensions/powerups/default_powerup_pick_sound.ogg", 3)
local DEFAULT_POWERUP_TRIGGER_SCALE = VEC3(3, 3, 3)

local IS_BEAMMP_SESSION = false

--[[
	Format
	["group_name"] = table
		[leveling] = table
			[1..n] = filename of powerup
		[max_levels] = amount of levels
		[name] = group name
		[do_not_unload] = Will prevent whileActive and whilePickup calls
		[type] = Type
		[onInit] = When the powerup group has been loaded
		[onVehicleInit] = Called for each vehicle
		[onCreate] = Spawn the powerup visual
		[onDespawn] = When the powerup is removed from the world once and for all
		[onDrop] = When the powerup is dropped by a vehicle
		[onPickup] = When the powerup is picked up by a vehicle
		[whileActive] = While the powerup is spawned in the world. As in if you want it to display special effects while its waiting to be picked up. Aka slowly moving up n down.
		[whilePickup] = While the powerup is in someones inventory. Can have it hover above the vehicle or play sounds.
		[powerups] = table
			[1..n] = table
				[internal_name] = matches the file/level name
				[clear_name] = clear powerup name
				[do_not_unload] = Will prevent whileActive calls
				[traits] = Traits
				[respects_traits] = check var
				[max_len] = the max amount of time this active will run
				[max_len_timer] = nil/hptimer (server only)
				[target_info_descriptor] = todo
				[onInit] = When the powerup has been loaded
				[onVehicleInit] = Called for each vehicle
				[onActivate] = When the powerup is activated
				[onDeactivate] = When the powerup is deactivated
				[onHit] = When the powerup hit our vehicle
				[onTargetHit] = When the powerup hit another vehicle
				[whileActive] = While the powerup is active. Update its render here, detect if it hit something. that kinda stuff
]]
local POWERUP_DEFS = {}

--[[
	Format
	["trigger_name"] = table
		[obj] = trigger
		[powerup] = nil/PowerUpGroup reference if a powerup is spawned here
		[data] = nil/Whatever the onCreate function returns us
		[is_rendered] = bool
		[respawn_timer] = hptimer
		[rotation_timer] = hptimer

]]
local LOCATIONS = {}

--[[
	Format
	["game_vehicle_id/playerid-vehicleid"] = table (game/server dependent key value)
		[charge] = 1..n
		[powerup] = nil/PowerUpGroup reference if the vehicle took one
		[data] = nil/Whatever the onCreate function returns us
		[powerup_active] = nil/PowerUp reference if a powerup has been activated
		[powerup_data] = nil/Whatever the onActivate function returns us
		[is_rendered] = bool
		[player_name] = singleplayer/traffic/player_name if multiplayer session, as a player can only have one
		[last_pickup] = hptimer
]]
local VEHICLES = {}

-- ------------------------------------------------------------------------------------------------
-- Very basic powerup display. Shows powerup info depending on which vehicle the player is spectating
local function simplePowerUpDisplay()
	for game_vehicle_id, vehicle in pairs(VEHICLES) do
		local powerup = vehicle.powerup
		if Extender.isSpectating(game_vehicle_id) and powerup then
			local powerup_active = powerup.powerups[math.min(vehicle.charge, powerup.max_levels)]
			if powerup_active == nil then return end
			
			local clear_name = powerup_active.clear_name
			local str = clear_name
			
			guihooks.trigger('toastrMsg', {
				type = "success",
				--label = "", -- ??
				--context = "", -- ??
				title = "",
				msg = str,
				config = {
					timeOut = ROUTINE_POWERUPS_BASIC_DISPLAY_REFRESH - 500,
					--extendedTimeOut = 0, -- ??
				},
			})
		end
	end
end

local function simpleDisplayActivatedPowerup(game_vehicle_id, clear_name, type)
	if not Extender.isSpectating(game_vehicle_id) then return end
	
	local symbol = "success"
	local str = ""
	
	local is_player, is_traffic = Extender.isPlayerVehicle(game_vehicle_id)
	if is_traffic then
		str = 'Traffic '
	elseif is_player then
		str = 'You '
	else
		str = VEHICLES[game_vehicle_id].player_name .. ' '
	end
		
	if type == Types.Charge then
		symbol = "info"
		str = str .. 'picked up '
	elseif type == Types.Negative then
		symbol = "warning"
	else
		str = str .. 'activated '
	end
	
	guihooks.trigger('toastrMsg', {
		type = symbol,
		--label = "", -- ??
		--context = "", -- ??
		title = "",
		msg = str .. clear_name,
		config = {
			timeOut = ROUTINE_POWERUPS_BASIC_DISPLAY_REFRESH - 500,
			--extendedTimeOut = 0, -- ??
		},
	})	
end

-- ------------------------------------------------------------------------------------------------
-- Powerup render que
local function targetInfoExec(vehicle, target_info)
	vehicle.powerup_active.onTargetSelect(vehicle.powerup_data, target_info)
end

local function targetHitExec(game_vehicle_id, vehicle, targets, deactivate)
	local origin_id_is_ours = MPUtil.isOwn(game_vehicle_id) and Extender.isSpectating(game_vehicle_id)
	
	for _, target_id in ipairs(targets) do
		if origin_id_is_ours then -- needs testing
			vehicle.powerup_active.onTargetHit(vehicle.powerup_data, game_vehicle_id, target_id)
		end
		vehicle.powerup_active.onHit(vehicle.powerup_data, game_vehicle_id, target_id)
	end
	
	if deactivate then
		vehicle.powerup_active.onDeactivate(vehicle.powerup_data, game_vehicle_id)
		vehicle.powerup_active = nil
		vehicle.powerup_data = nil
		
		MPClientRuntime.tryDisableActivePowerup(game_vehicle_id)
	end
end

local function tickRenderQue(dt)
	for _, location in pairs(LOCATIONS) do
		if location.is_rendered and location.powerup then
			location.powerup.whileActive(location.data, dt)
		end
	end
	
	--local is_beammp_session = MPUtil.isBeamMPSession()
	
	for game_vehicle_id, vehicle in pairs(VEHICLES) do
		local is_own = MPUtil.isOwn(game_vehicle_id)
		if is_own == nil then is_own = true end -- if singleplayer
	
		if vehicle.is_rendered and Extender.isActive(game_vehicle_id) then
			if vehicle.powerup then
				vehicle.powerup.whilePickup(vehicle.data, game_vehicle_id, dt)
			end
			
			if vehicle.powerup_active then
				local response = vehicle.powerup_active.whileActive(vehicle.powerup_data, game_vehicle_id, dt)
				
				if is_own and response then
					if response.IsStop then
						vehicle.powerup_active.onDeactivate(vehicle.powerup_data, game_vehicle_id)
						vehicle.powerup_active = nil
						vehicle.powerup_data = nil
						
						MPClientRuntime.tryDisableActivePowerup(game_vehicle_id)
						
					else
						if response.target_info then
							if not IS_BEAMMP_SESSION then
								targetInfoExec(vehicle, response.target_info)
							else
								MPClientRuntime.tryTargetInfo(game_vehicle_id, response.target_info)
							end
						end
						
						if response.target_hits then
							if not IS_BEAMMP_SESSION then
								targetHitExec(game_vehicle_id, vehicle, response.target_hits, response.IsStopAfterExec)
							else
								MPClientRuntime.tryTargetHit(game_vehicle_id, response.target_hits, response.IsStopAfterExec)
							end
						end
					end
				end
			end
		end
	end
end

local function checkRenderDistance()
	local camera_position = core_camera.getPosition()
	if camera_position == nil then return end
	local dist3d = Util.dist3d
	
	for _, location in pairs(LOCATIONS) do
		if location.powerup and not location.powerup.do_not_unload then
			
			if dist3d(location.obj:getPosition(), camera_position) < RENDER_DISTANCE then
				if not location.is_rendered then
					location.is_rendered = true
					location.powerup.onLoad(location.data)
				end
				
			else
				if location.is_rendered then
					location.is_rendered = false
					location.powerup.onUnload(location.data)
				end
			end
		end
	end
	
	for game_vehicle_id, vehicle in pairs(VEHICLES) do
		if (vehicle.powerup and not vehicle.powerup.do_not_unload) or (vehicle.powerup_active and not vehicle.powerup_active.do_not_unload) then
			
			if dist3d(be:getObjectByID(game_vehicle_id):getPosition(), camera_position) < RENDER_DISTANCE or not Extender.isActive(game_vehicle_id) then
				if not vehicle.is_rendered then
					vehicle.is_rendered = true
					if vehicle.powerup then vehicle.powerup.onLoad(vehicle.data) end
					if vehicle.powerup_active then vehicle.powerup_active.onLoad(vehicle.powerup_active) end
				end
				
			else
				if vehicle.is_rendered and ((vehicle.powerup and not vehicle.powerup.do_not_unload) or (vehicle.powerup_active and not vehicle.powerup_active.do_not_unload)) then
					vehicle.is_rendered = false
					if vehicle.powerup then vehicle.powerup.onUnload(vehicle.data) end
					if vehicle.powerup_active then vehicle.powerup_active.onUnload(vehicle.powerup_active) end
				end
			end
		end
	end
end

-- ------------------------------------------------------------------------------------------------
-- Vehicles
function onPowerUpVehicleInit(game_vehicle_id)
	if be:getObjectByID(game_vehicle_id) == nil then return end
	for _, group in pairs(POWERUP_DEFS) do
		group.onVehicleInit(game_vehicle_id)
		for _, powerup in pairs(group.powerups) do
			powerup.onVehicleInit(game_vehicle_id)
		end
	end
end

local function onVehicleSpawned(game_vehicle_id)
	VEHICLES[game_vehicle_id] = {
		charge = 1,
		powerup = nil,
		is_rendered = true,
		player_name = MPUtil.getPlayerName(game_vehicle_id) or SUBJECT_SINGLEPLAYER,
		last_pickup = PauseTimer.new()
	}
	
	if not MPUtil.isBeamMPServer() then
		TimedTrigger.new(
			'powerup_vehicle_initer_' .. game_vehicle_id,
			100,
			1,
			onPowerUpVehicleInit,
			game_vehicle_id
		)
	end
	
	return VEHICLES[game_vehicle_id]
end

local function onVehicleDestroyed(game_vehicle_id)
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle == nil then return end
	
	-- drop powerup
	if vehicle.powerup then
		vehicle.powerup.onDrop(vehicle.data)
	end
	
	if vehicle.powerup_active then
		vehicle.powerup_active.onDeactivate(vehicle.data, game_vehicle_id)
		MPClientRuntime.tryDisableActivePowerup(game_vehicle_id)
	end

	VEHICLES[game_vehicle_id] = nil
end

-- ------------------------------------------------------------------------------------------------
-- Traffic vehicle check routine
local function checkIfTraffic()
	local traffic_list = Util.tableVToK(gameplay_traffic.getTrafficList())
	for game_vehicle_id, vehicle in pairs(VEHICLES) do
		if traffic_list[game_vehicle_id] then
			vehicle.player_name = SUBJECT_TRAFFIC
		else
			vehicle.player_name = MPUtil.getPlayerName(game_vehicle_id) or SUBJECT_SINGLEPLAYER
		end
	end
end

-- ------------------------------------------------------------------------------------------------
-- Powerups
local function loadPowerups(set_path, group_path, group)
	if POWERUP_DEFS[group.name] then 
		Log.error('"' .. group.name .. '" from "' .. Util.fileName(group_path) .. '" already exists. Aborting load')
		return
	end
	
	-- check version
	if group.lib_version ~= M._NAME then
		Log.error('"' .. group.name .. '" from "' .. Util.fileName(group_path) .. '" is out of date. Aborting load')
		return
	end
	
	if #group.powerups > 0 then
		Log.error('Group "' .. group.name .. '" has invalid definitions for entry "powerups". Keep it empty. Aborting load')
		return
	end
	
	local group_type = Extender.getTypeName(group.type)
	if group_type == nil then
		Log.error('Group "' .. group.name .. '" has unknown type "' .. tostring(group.type) .. '". Aborting load')
		return
	end
	
	if group.probability == nil or group.probability > 10 then
		Log.error('Group "' .. group.name .. '" has probability outside allowed range. 0 - 10.')
		return
	elseif group.probability < 0 then
		group.probability = 5
	end
	
	Log.info('Loading group "' .. group.name .. '"')

	-- init powerups of the group
	local powerups = {}
	for _, powerup_name in pairs(group.leveling) do
		local file_path = set_path .. '/' .. group.name .. '/' .. powerup_name .. '.lua'
		local powerup, err = Util.compileLua(file_path)
		if powerup == nil then
			Log.error('\tCannot compile "' .. powerup_name .. '" because of "' .. err .. '". Skipping.')
			--return -- abort
		else
			local is_invalid = false
			
			if powerup.lib_version ~= M._NAME then
				Log.error('\t"' .. powerup_name .. '" is out of date. Rejecting powerup')
				
				is_invalid = true
			end
			
			for _, trait in ipairs(powerup.traits or {}) do
				local trait_name = Extender.getTraitName(trait)
				if trait_name == nil then
					Log.error('\tPowerup "' .. powerup_name .. '" lists an unknown "' .. trait .. '" trait')
					is_invalid = true
					
				elseif type(powerup[trait]) ~= "function" then
					Log.error('\tPowerup "' .. powerup_name .. '" lists the "' .. trait_name .. '" trait but doesnt have a callback for it. Skipping.')
					is_invalid = true
				end
			end
			
			for _, trait in ipairs(powerup.respects_traits or {}) do
				local trait_name = Extender.getTraitName(trait)
				if trait_name == nil then
					Log.error('\tPowerup "' .. powerup_name .. '" is listing to respect the "' .. trait .. '" trait, but this trait is unknown')
					is_invalid = true
				end
			end
			
			if powerup.max_len == 0 then
				Log.error('\tPowerup "' .. powerup_name .. '" has no max_len.')
				is_invalid = true
			end
			
			powerup.internal_name = powerup_name
			powerup.file_path = Util.filePath(file_path)
			
			if not is_invalid then
				table.insert(group.powerups, powerup)
				Log.info('\tPowerup check passed for "' .. powerup.internal_name .. '" - "' .. powerup.clear_name .. '"')
			end
		end
	end
	
	group.max_levels = #group.powerups
	group.file_path = Util.filePath(group_path)
	
	if not MPUtil.isBeamMPServer() then
		Log.info('\t(ClientSide) Initializing group and powerups')
		group.onInit()
		for _, powerup in pairs(group.powerups) do
			powerup.onInit()
		end
		for _, vehicle in ipairs(Extender.getAllVehicles()) do
			local veh_id = vehicle:getId()
			group.onVehicleInit(veh_id)
			for _, powerup in pairs(group.powerups) do
				powerup.onVehicleInit(veh_id)
			end
		end
	end
	
	POWERUP_DEFS[group.name] = group
	
	if group.max_levels > MAX_CHARGE then MAX_CHARGE = group.max_levels end
	
	Log.info('\tGroup check passed for "' .. group.name .. '"')
	Log.info('\tType     : ' .. group.type)
	Log.info('\tPowerups : ' .. group.max_levels)
end

local function loadPowerupSet(set_path)
	--MAX_CHARGE = 0
	Log.info('Trying to load powerup set "' .. Util.fileName(set_path) .. '"')
	for _, group_path in pairs(Util.listFiles(set_path)) do
		local group, err = Util.compileLua(group_path)
		if group == nil then
			Log.error('Cannot compile "' .. Util.fileName(group_path) .. '" group because of "' .. tostring(err) .. '"')
			
		else
			loadPowerups(set_path, group_path, group)
		end
	end
	
	if not MPUtil.isBeamMPSession() or MPUtil.isBeamMPServer() then M.restockPowerups(true) end
end

local function selectPowerup()
	if not Util.tableHasContent(POWERUP_DEFS) then return end

	local pot = Pot()
	for _, group in pairs(POWERUP_DEFS) do
		pot:add(group, group.probability)
	end
	
	pot:stir(5)
	return pot:surprise()
end

local function activatePowerup(game_vehicle_id, from_server, charge_overwrite) -- charge overwrite is given by negatives
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle.powerup == nil then
		Log.error('Vehicle owns no powerup')
		return
	end
	if vehicle.powerup_active then
		Log.error('Another powerup is active at this moment')
		return
	end
	
	-- select active powerup
	local charge = charge_overwrite or math.min(vehicle.charge, vehicle.powerup.max_levels)
	local powerup_active = vehicle.powerup.powerups[charge]
	if powerup_active == nil then
		Log.error('Group "' .. vehicle.powerup.name .. '" has no powerups')
		return
	end
	
	local powerup_type = vehicle.powerup.type
	
	-- drop powerup
	vehicle.powerup.onDrop(vehicle.data)
	
	-- consume powerup and charge
	if charge_overwrite == nil then vehicle.charge = 1 end
	vehicle.powerup = nil
	vehicle.data = nil
	
	local response = powerup_active.onActivate(be:getObjectByID(game_vehicle_id))
	if response.IsError then
		Log.error('Powerup "' .. powerup_active.internal_name .. '" failed to activate "' .. response.reason .. '"')
		return
	end
	
	vehicle.powerup_active = powerup_active
	vehicle.powerup_data = response.data -- can be nil
	
	if MPUtil.isOwn(game_vehicle_id) and not from_server then
		MPClientRuntime.tryActivatePowerup(game_vehicle_id)
	end
	
	if response.IsTargetInfo then
		if response.target_info then
			if not IS_BEAMMP_SESSION then
				targetInfoExec(vehicle, response.target_info)
			else
				MPClientRuntime.tryTargetInfo(game_vehicle_id, response.target_info)
			end
		end
	
	elseif response.IsTargetHits then
		if response.target_hits then
			if not IS_BEAMMP_SESSION then
				targetHitExec(game_vehicle_id, vehicle, response.target_hits, true)
			else
				MPClientRuntime.tryTargetHit(game_vehicle_id, response.target_hits, true)
			end
		end
	end
	
	Log.info("Powerup: " .. game_vehicle_id .. " activated " .. powerup_active.internal_name)
	simpleDisplayActivatedPowerup(game_vehicle_id, powerup_active.clear_name, powerup_type)
end

local function vehicleAddPowerup(game_vehicle_id, powerup, location)
	-- is the case when a player joins a server where vehicles already have powerups, in that case there is no powerup to inherit from a location
	local origin_vehicle = be:getObjectByID(game_vehicle_id)
	local is_fake_location = false
	if location == nil then
		local fake_location = {int = {pos = origin_vehicle:getPosition()}}
		function fake_location:getPosition()
			return self.int.pos
		end
		function fake_location:getRotation()
			return QuatF(0, 0, 0, 0)
		end
		function fake_location:getScale()
			return VEC3(3, 3, 3)
		end
		
		location = {
			powerup = powerup,
			data = powerup.onCreate(fake_location),
			respawn_timer = PauseTimer.new()
		}
		
		is_fake_location = true
	end
	
	local vehicle = VEHICLES[game_vehicle_id]
	
	local r, variable = powerup.onPickup(location.data, origin_vehicle)
	if r == nil then
		Log.error('Vehicle cannot pickup "' .. location.powerup.name .. '" - "' .. tostring(variable) .. '"')
		return nil
	
	elseif r == GroupReturns.onPickup.Success then -- success
		if vehicle.powerup then
			Log.info('PowerUP: ' .. game_vehicle_id .. ' dropped ' .. vehicle.powerup.name)
			vehicle.powerup.onDrop(vehicle.data)
		end
		
		-- swap ownership
		vehicle.powerup = location.powerup
		vehicle.data = location.data
		
		Log.info("PowerUp: " .. game_vehicle_id .. " picked up " .. vehicle.powerup.name)
		
	--elseif r == GroupReturns.onPickup.Drop then -- dont pickup new one, drop current and remove the new one
	--	if vehicle.powerup then
	--		Log.info("PowerUp: " .. game_vehicle_id .. " dropped " .. vehicle.powerup.name)
	--		vehicle.powerup.onDrop(vehicle.data)
	--		vehicle.powerup = nil
	--		vehicle.data = nil
	--	end
		
	--	if is_fake_location then location.powerup.onDrop(location.data) end
		
	elseif r == GroupReturns.onPickup.IsCharge then -- reserved for charges
		Log.info("PowerUp: " .. game_vehicle_id .. " picked a charge")
		simpleDisplayActivatedPowerup(game_vehicle_id, "Charge", powerup.type)

	elseif r == GroupReturns.onPickup.IsNegative then -- immediate execute - for negative powerups
		-- check currrent powerup
		if vehicle.powerup then
			Log.info("PowerUp: " .. game_vehicle_id .. " dropped " .. vehicle.powerup.name)
			vehicle.powerup.onDrop(vehicle.data)
		end
				
		-- swap ownership
		vehicle.powerup = location.powerup
		vehicle.data = location.data
		
		Log.info("PowerUp: " .. game_vehicle_id .. " picked up negative " .. vehicle.powerup.name)
		
		if not MPUtil.isBeamMPSession() then
			activatePowerup(game_vehicle_id, nil, math.random(1, vehicle.powerup.max_levels))
		--else
			--MPClientRuntime.tryActivatePowerup(game_vehicle_id) -- server does this already
		end
	else
		Log.error('Unknown return type from powerup action of "' .. location.powerup.name .. '"')
		
		if is_fake_location then location.powerup.onDrop(location.data) end
		return
	end
	
	location.powerup = nil
	location.data = nil
	location.respawn_timer:stopAndReset()
	
	simplePowerUpDisplay()
	
	-- if traffic
	local is_own, is_traffic = Extender.isPlayerVehicle(game_vehicle_id)
	if is_traffic and vehicle.powerup then
		if not MPUtil.isBeamMPSession() then
			vehicle.charge = math.random(1, MAX_CHARGE)
			activatePowerup(game_vehicle_id)
		else
			MPClientRuntime.tryActivatePowerup(game_vehicle_id)
		end
	end
	if Extender.isSpectating(game_vehicle_id) then
		-- temp. the pickup sound will be on the group
		TEMP_PICKUP_SOUND:play()
	end
end

-- game drives into location
local function takePowerupFromLocation(location_name, trigger_data, location)
	local location = location or LOCATIONS[location_name]
	if location == nil then return end
	if location.powerup == nil then return end
	
	local game_vehicle_id = trigger_data.subjectID
	local vehicle = VEHICLES[game_vehicle_id] or onVehicleSpawned(game_vehicle_id)
	
	local is_own, is_traffic = Extender.isPlayerVehicle(game_vehicle_id)
	if not is_own and not is_traffic then return end -- ignore vehicles not owned by us
	
	if vehicle.last_pickup:stop() < PICKUP_DOWNTIME then return end
	vehicle.last_pickup:stopAndReset()
	
	if not MPUtil.isBeamMPSession() then
		vehicleAddPowerup(game_vehicle_id, location.powerup, location)
	else
		-- ask server
		MPClientRuntime.tryTakePowerup(location_name, game_vehicle_id)
	end
end

-- ------------------------------------------------------------------------------------------------
-- Location restock and rotation check routine
local function restockPowerups(instant)
	for location_name, location in pairs(LOCATIONS) do
		if location.powerup == nil and (instant or location.respawn_timer:stop() > RESPAWN_TIME) then
			location.powerup = selectPowerup()
			if location.powerup ~= nil then
				location.rotation_timer:stopAndReset()
				
				if not instant then
					Log.info('Restocked "' .. location_name .. '" with "' .. location.powerup.name .. '"')
				end
				
				if not MPUtil.isBeamMPServer() then
					location.data = location.powerup.onCreate(location.obj)
				else
					MPServerRuntime.syncLocationUpdate(location_name)
				end
			end
		end
	end
end

local function checkLocationRotation()
	for location_name, location in pairs(LOCATIONS) do
		if location.powerup and location.rotation_timer:stop() > ROTATION_TIME then
			if not MPUtil.isBeamMPServer() then location.powerup.onDespawn(location.data) end
			location.powerup = selectPowerup()
			if location.powerup ~= nil then
				location.rotation_timer:stopAndReset()
				
				--Log.info('Restocked "' .. location_name .. '" with "' .. location.powerup.name .. '"')
				
				if not MPUtil.isBeamMPServer() then
					location.data = location.powerup.onCreate(location.obj)
				else
					MPServerRuntime.syncLocationUpdate(location_name)
				end
				
				break
			end
		end
	end
end

-- ------------------------------------------------------------------------------------------------
-- Locations
local function updateLocationRotationCheckTime()
	if not MPUtil.isBeamMPSession() or MPUtil.isBeamMPServer() then
		ROUTINE_LOCATIONS_ROTATION = math.floor(math.min(ROTATION_TIME / Util.tableSize(LOCATIONS), 5000))
		local r = TimedTrigger.new(
			"PowerUps_rotation",
			ROUTINE_LOCATIONS_ROTATION,
			0,
			checkLocationRotation
		)
		if r == nil then
			Log.error('Cannot initialize restock routine')
		end
		
		Log.info("Updated location rotation check time to " .. ROUTINE_LOCATIONS_ROTATION .. " ms")
	end
end

local function loadLocations(triggers)
	local total_loaded = 0
	for trigger_name, trigger in pairs(triggers) do
		if LOCATIONS[trigger_name] then
			Log.error('Location "' .. trigger_name .. '" is already known')
			trigger:delete()
		else
			-- adjust triggers
			local pos = trigger:getPosition()
			local rot = trigger:getRotation()
			
			-- needs testing
			local terrain_height = VEC3(pos.x, pos.y, pos.z)
			terrain_height.z = terrain_height.z + 1
			--local terrain_height = vec3(pos.x, pos.y, 0)
			--terrain_height.z = core_terrain.getTerrainHeight(terrain_height) or (pos.z - 1)
			--if Util.dist3d(pos, terrain_height) < 1 then
			--	terrain_height.z = terrain_height.z + 1
			--end
			
			--terrain_height = terrain_height + 1
			
			trigger:setPosRot(terrain_height.x, terrain_height.y, terrain_height.z, rot.x, rot.y, rot.z, rot.w)
			trigger:setScale(DEFAULT_POWERUP_TRIGGER_SCALE)
			trigger:setField("TriggerMode", 0, "Overlaps")
			trigger:setField("TriggerTestType", 0, "Bounding box")
			trigger:setField("luaFunction", 0, "onBeamNGTrigger")
			
			LOCATIONS[trigger_name] = {
				obj = trigger,
				powerup = nil,
				data = nil,
				is_rendered = true,
				respawn_timer = PauseTimer.new(),
				rotation_timer = PauseTimer.new()
			}
			
			total_loaded = total_loaded + 1
		end
	end
	
	Log.info("Added " .. total_loaded .. " Locations. Total: " .. Util.tableSize(LOCATIONS))
	
	updateLocationRotationCheckTime()
end

-- ------------------------------------------------------------------------------------------------
-- ------------------------------------------------------------------------------------------------
-- ------------------------------------------------------------------------------------------------
-- Interface

-- ------------------------------------------------------------------------------------------------
-- Hotkey
function onPowerUpActivateHotkey()
	local search_for = MPUtil.getMyPlayerName() or SUBJECT_SINGLEPLAYER
	local spectated_vehicle = getPlayerVehicle(0)
	if spectated_vehicle == nil then return end
	for game_vehicle_id, vehicle in pairs(VEHICLES) do
		if vehicle.player_name == search_for and game_vehicle_id == spectated_vehicle:getId() then
			activatePowerup(game_vehicle_id)
			return
		end
	end
end

-- ------------------------------------------------------------------------------------------------
-- Inter lib interface
M.locations = LOCATIONS
M.vehicles = VEHICLES
M.powerup_defs = POWERUP_DEFS
M.Error = Error

M.vehicleAddPowerup = vehicleAddPowerup
M.activatePowerup = activatePowerup
M.targetInfoExec = targetInfoExec
M.targetHitExec = targetHitExec
M.restockPowerups = restockPowerups

M.updateMPServerRuntime = function(this)
	MPServerRuntime = this
end

M.getMaxCharge = function()
	return MAX_CHARGE
end

M.getDefaultTriggerScale = function()
	return DEFAULT_POWERUP_TRIGGER_SCALE
end

-- ------------------------------------------------------------------------------------------------
-- Load/Unload
M.init = function() -- must be called during or after onWorldReadyState == 2
	Extender.updatePowerUpsLib(M)
	MPClientRuntime.updatePowerUpsLib(M)
	
	for _, vehicle in pairs(Extender.getAllVehicles()) do
		onVehicleSpawned(vehicle:getId())
	end
	
	IS_BEAMMP_SESSION = MPUtil.isBeamMPSession()
	
	-- run in singleplayer and on mp server
	if not MPUtil.isBeamMPSession() or MPUtil.isBeamMPServer() then
		local r = TimedTrigger.new(
			"PowerUps_restock",
			ROUTINE_LOCATIONS_RESTOCK,
			0,
			restockPowerups
		)
		if r == nil then
			Log.error('Cannot initialize restock routine')
		end
		
		updateLocationRotationCheckTime()
	end
	
	-- run only ingame, but not matter if mp session or singleplayer
	if not MPUtil.isBeamMPServer() then
		local r = TimedTrigger.new(
			"PowerUps_checkRenderDist",
			ROUTINE_POWERUPS_CHECK_RENDER_DISTANCE,
			0,
			checkRenderDistance
		)
		if r == nil then
			Log.error('Cannot initialize render check routine')
		end
		
		local r = TimedTrigger.new(
			"PowerUps_checkTrafficlist",
			ROUTINE_POWERUPS_CHECK_TRAFFIC,
			0,
			checkIfTraffic
		)
		if r == nil then
			Log.error('Cannot initialize traffic check routine')
		end
		
		local r = TimedTrigger.new(
			"PowerUps_simpleDisplayRefresh",
			ROUTINE_POWERUPS_BASIC_DISPLAY_REFRESH,
			0,
			simplePowerUpDisplay
		)
		if r == nil then
			Log.error('Cannot initialize traffic check routine')
		end
	end
	
	-- hooks event handlers and lets the server know that we are initialized
	-- if the server has the server side plugin it will return us info about the to be loaded locations, prefabs, which location and vehicle has which powerup
	if MPUtil.isBeamMPSession() then
		MPClientRuntime.init()
	end
end

M.unload = function()
	if not MPUtil.isBeamMPServer() then
		-- call destruction events on all powerups, groups and triggers
		for location_name, location in pairs(LOCATIONS) do
			if location.powerup ~= nil then
				location.powerup.onDespawn(location.data)
			end
			location.obj:delete()
		end
		
		for game_vehicle_id, vehicle in pairs(VEHICLES) do
			if vehicle.powerup ~= nil then
				vehicle.powerup.onDespawn(vehicle.data)
			end
			if vehicle.powerup_active ~= nil then
				vehicle.powerup_active.onDeactivate(vehicle.powerup_data, game_vehicle_id)
				MPClientRuntime.tryDisableActivePowerup(game_vehicle_id)
			end
		end
	end
	
	-- remove timed triggers
	TimedTrigger.remove("PowerUps_restock")
	TimedTrigger.remove("PowerUps_rotation")
	TimedTrigger.remove("PowerUps_checkRenderDist")
	TimedTrigger.remove("PowerUps_checkTrafficlist")
	TimedTrigger.remove("PowerUps_simpleDisplayRefresh")
	
	-- wiping the ref clean instead of just var = {} as that would unhook these tables from anything that references them. eg M.vehicles ~= VEHICLES
	Util.tableReset(LOCATIONS)
	Util.tableReset(VEHICLES)
	Util.tableReset(POWERUP_DEFS)
end

-- ------------------------------------------------------------------------------------------------
-- Development
M.testExec = function(game_vehicle_id, group, charge)
	if be:getObjectByID(game_vehicle_id) == nil then
		Log.error('Unknown vehicle')
		return
	end
	local vehicle = VEHICLES[game_vehicle_id] or onVehicleSpawned(game_vehicle_id)
	
	local powerup = POWERUP_DEFS[group]
	if powerup == nil then
		Log.error('Unknown group')
		return nil
	end
	
	-- create fake location
	local location = {
		powerup = powerup,
		data = powerup.onCreate(be:getObjectByID(game_vehicle_id)), -- incorrect, needs a trigger
		respawn_timer = PauseTimer.new()
	}
	
	-- take ownership
	takePowerupFromLocation("testexec", {subjectID = game_vehicle_id}, location)
	
	-- set charge
	vehicle.charge = charge
	
	-- activate
	activatePowerup(game_vehicle_id)
end

-- ------------------------------------------------------------------------------------------------
-- Load locations/powerups
M.loadPowerUpDefs = loadPowerupSet

M.loadLocationPrefab = function(path)
	local triggers, err = TriggerLoad.loadTriggerPrefab(path, false)
	if triggers == nil then
		Log.error(err)
		return
	end
	
	loadLocations(triggers)
	if not MPUtil.isBeamMPSession() or MPUtil.isBeamMPServer() then restockPowerups(true) end
end

-- ------------------------------------------------------------------------------------------------
-- Game events
M.onBeamNGTrigger = function(data)
	--dump(data)
	local location = LOCATIONS[data.triggerName]
	if location and data.event == "enter" then
		-- if beammp then verify with server
		-- todo
		
		takePowerupFromLocation(data.triggerName, data, location)
	end
end

M.onVehicleSpawned = onVehicleSpawned
M.onVehicleDestroyed = onVehicleDestroyed

-- ------------------------------------------------------------------------------------------------
-- Base routine (game only)
M.tick = function(dt)
	tickRenderQue(dt)
end

-- ------------------------------------------------------------------------------------------------
-- PowerUps interface
M.getCharge = function(game_vehicle_id)
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle == nil then return nil end
	return vehicle.charge
end

M.setCharge = function(game_vehicle_id, charge)
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle == nil then return nil end
	
	if not MPUtil.isBeamMPSession() then -- server controls this
		vehicle.charge = charge
	end
end

M.addCharge = function(game_vehicle_id, charge)
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle == nil then return nil end
	
	if not MPUtil.isBeamMPSession() then -- server controls this
		vehicle.charge = math.min(math.max(vehicle.charge + charge, 1), MAX_CHARGE)
	end
	
	Log.info(game_vehicle_id .. " charge is " .. vehicle.charge)
end

M.getTotalSpawnedPowerups = function()
	local total = 0
	for _, location in pairs(LOCATIONS) do
		if location.powerup then total = total + 1 end
	end
	return total
end

M.getTotalOwnedPowerups = function()
	local total = 0
	for _, vehicle in pairs(VEHICLES) do
		if vehicle.powerup then total = total + 1 end
	end
	return total
end

M.getTotalActivePowerups = function()
	local total = 0
	for _, vehicle in pairs(VEHICLES) do
		if vehicle.powerup_active then total = total + 1 end
	end
	return total
end

M.getTotalLocations = function()
	return Util.tableSize(LOCATIONS)
end

M.getKnownVehicleCount = function()
	return Util.tableSize(VEHICLES)
end

M.getRotationTime = function()
	return ROTATION_TIME
end

M.getRotationRoutineTime = function()
	return ROUTINE_LOCATIONS_ROTATION
end

M.getRestockTime = function()
	return RESPAWN_TIME
end

M.getPowerupGroups = function()
	local groups = {}
	for group_name, _ in pairs(POWERUP_DEFS) do
		table.insert(groups, group_name)
	end
	return groups
end

M.getSpawnCountByGroup = function(group_name)
	local total = 0
	for _, location in pairs(LOCATIONS) do
		if location.powerup and location.powerup.name == group_name then
			total = total + 1
		end
	end
	return total
end

M.getPowerup = function(game_vehicle_id)
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle then
		return vehicle.powerup
	end
end

M.takePowerup = function(game_vehicle_id, location_name)
	local location = LOCATIONS[location_name]
	if location == nil then return end
	
	takePowerupFromLocation(location_name, {subjectID = game_vehicle_id}, location)
end

M.givePowerup = function(game_vehicle_id, group_name)
	local powerup = POWERUP_DEFS[group_name]
	if powerup == nil then return end
	
	vehicleAddPowerup(game_vehicle_id, powerup)
end

M.disableActivePowerup = function(game_vehicle_id)
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle == nil or vehicle.powerup_active == nil then return end
	
	vehicle.powerup_active.onDeactivate(vehicle.powerup_data, game_vehicle_id)
	vehicle.powerup_active = nil
	vehicle.powerup_data = nil
	
	MPClientRuntime.tryDisableActivePowerup(game_vehicle_id)
end

M.dropPowerup = function(game_vehicle_id)
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle == nil or vehicle.powerup == nil then return end
	
	vehicle.powerup.onDrop(vehicle.data)
	vehicle.powerup = nil
	vehicle.data = nil
end

M.setRespawnTime = function(time)
	RESPAWN_TIME = time
end

M.setRotationTime = function(time)
	ROTATION_TIME = time
	updateLocationRotationCheckTime()
end

M.setPickupDownTime = function(time)
	PICKUP_DOWNTIME = time
end

M.getPickupDownTime = function()
	return PICKUP_DOWNTIME
end

M.getLibVersion = function()
	return {version = M._VERSION, branch = M._BRANCH, name = M._NAME}
end

return M
