--[[
	License: None
	Author: Neverless (discord: neverless.)
]]
local Extender = require("libs/PowerUpsExtender")
local Traits = Extender.Traits
local TimedTrigger = require("TimedTrigger")
local TriggerLoad = require("libs/TriggerLoad")
local Util = require("libs/Util")
local Colors = -1
if not log then
	Colors = require("mp_libs/colors")
end

local M = {
	_VERSION = 0.1, -- 07.02.2025 DD.MM.YYYY
	_BRANCH = "alpha",
	_NAME = "init"
}
local VEC3 = vec3 or function(x, y, z) return {x = x, y = y, z = z} end -- server compat
local RESPAWN_TIME = 5000
local ROTATION_TIME = 120000
local RENDER_DISTANCE = 500
local MAX_CHARGE = 0 -- updated based on the loaded set

local ROUTINE_LOCATIONS_RESTOCK = 5000
local ROUTINE_LOCATIONS_ROTATION = 5000

local ROUTINE_POWERUPS_CHECK_RENDER_DISTANCE = 1000
local ROUTINE_POWERUPS_CHECK_TRAFFIC = 10000
local ROUTINE_POWERUPS_BASIC_DISPLAY_REFRESH = 5000


-- these vars also exist in the extender. if change then also update there
local SUBJECT_SINGLEPLAYER = "!singleplayer"
local SUBJECT_TRAFFIC = "!traffic"
local SUBJECT_UNKNOWN = "!unknown"

--[[
	Format
	["group_name"] = table
		[leveling] = table
			[1..n] = filename of powerup
		[max_levels] = amount of levels
		[name] = group name
		[do_not_unload] = Will prevent whileActive and whilePickup calls
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
	["game_vehicle_id"] = table
		[charge] = 1..n
		[powerup] = nil/PowerUpGroup reference if the vehicle took one
		[data] = nil/Whatever the onCreate function returns us
		[powerup_active] = nil/PowerUp reference if a powerup has been activated
		[powerup_data] = nil/Whatever the onActivate function returns us
		[is_rendered] = bool
		[player_name] = singleplayer/traffic/player_name if multiplayer session, as a player can only have one
]]
local VEHICLES = {}

--[[
	["randomname"] = table
		[powerup_active] = PowerUpGroup reference
		[powerup_data] = data
		[execute] = bool. executed once true
		[targets] = table
			[1..n] = game_vehicle_id
]]
local TARGET_WAIT = {}

--[[
	["randomname"] = table
		[powerup_active] = PowerUpGroup reference
		[powerup_data] = data
		[execute] = bool. executed once true
		[deactivate] = bool
		[origin_id] = origin_id
		[targets] = table
			[1..n] = game_vehicle_id
]]
local TARGET_HIT_WAIT = {}

-- ------------------------------------------------------------------------------------------------
-- Verbose Error propagation
local function Error(reason)
	local insert = function(display_reason, debug_info)
		if debug_info == nil or debug_info.name == nil then return display_reason end
		return display_reason .. Util.fileName(debug_info.source or "") .. '@' .. debug_info.name .. ':' .. debug_info.linedefined .. ' <- '
	end
	
	local display_reason = insert('[', debug.getinfo(2))
	
	local index = 3;
	while debug.getinfo(index) and (debug.getinfo(1).source == debug.getinfo(index).source) do
		display_reason = insert(display_reason, debug.getinfo(index))
		index = index + 1
	end
	display_reason = insert(display_reason, debug.getinfo(index))
	display_reason = display_reason:sub(1, display_reason:len() - 4) .. '] THROWS\n' .. reason

	if log then -- if game
		log("E", "PowerUps", display_reason)
		
	else -- if beammp server
		Colors.print(Colors.bold("PowerUps") .. ' - ' .. display_reason, Colors.lightRed("ERROR"))
	end
end

-- ------------------------------------------------------------------------------------------------
-- Very basic powerup display
local function simplePowerUpDisplay()
	for game_vehicle_id, vehicle in pairs(VEHICLES) do
		local powerup = vehicle.powerup
		if Extender.isSpectating(game_vehicle_id) and powerup then
			local clear_name = powerup.powerups[math.min(vehicle.charge, powerup.max_levels)].clear_name
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

local function simpleDisplayActivatedPowerup(clear_name, type)
	local symbol = "success"
	local str = 'Activated '
	if type == 3 then
		symbol = "info"
		str = 'Picked up '
	elseif type == 4 then
		symbol = "warning"
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
-- Target/TargetHit wait
local function addNewTargets(powerup_active, powerup_data, targets)
	local random_name = Util.randomName()
	TARGET_WAIT[random_name] = {
		powerup_active = powerup_active,
		powerup_data = powerup_data,
		execute = true, -- todo
		targets = targets
	}
	
	-- request mp confirmation
	-- todo
end

local function tickTargetQue()
	for random_name, exec in pairs(TARGET_WAIT) do
		if exec.execute then
			exec.powerup_active.onTargetSelect(exec.powerup_data, exec.targets)
			TARGET_WAIT[random_name] = nil
		end
	end
end

local function addNewTargetHits(powerup_active, powerup_data, targets, origin_id, deactivate)
	local random_name = Util.randomName()
	TARGET_HIT_WAIT[random_name] = {
		powerup_active = powerup_active,
		powerup_data = powerup_data,
		execute = true, -- todo
		deactivate = deactivate,
		origin_id = origin_id,
		targets = targets
	}
	
	-- request mp confirmation
	-- todo
end

local function tickTargetHitQue()
	for random_name, exec in pairs(TARGET_HIT_WAIT) do
		if exec.execute and Extender.isActive(exec.origin_id, target_id) then
			for _, target_id in pairs(exec.targets) do
				exec.powerup_active.onTargetHit(exec.powerup_data, exec.origin_id, target_id)
				exec.powerup_active.onHit(exec.powerup_data, exec.origin_id, target_id)
			end
			
			if exec.deactivate then
				exec.powerup_active.onDeactivate(exec.powerup_data, exec.origin_id)
			end
			TARGET_HIT_WAIT[random_name] = nil
		end
	end
end

-- ------------------------------------------------------------------------------------------------
-- Powerup render que
local function tickRenderQue(dt)
	for _, location in pairs(LOCATIONS) do
		if location.is_rendered and location.powerup then
			location.powerup.whileActive(location.data, dt)
		end
	end
	
	for game_vehicle_id, vehicle in pairs(VEHICLES) do
		if vehicle.is_rendered and Extender.isActive(game_vehicle_id) then
			if vehicle.powerup then
				vehicle.powerup.whilePickup(vehicle.data, game_vehicle_id, dt)
			end
			if vehicle.powerup_active then
				
				local r, targets, target_hits = vehicle.powerup_active.whileActive(vehicle.powerup_data, game_vehicle_id, dt)
				if r == nil then
					if targets then
						-- check if this client is the owner of this vehicle
						-- if not, do nothing. targets will come from their client
						-- todo
						
						addNewTargets(vehicle.powerup_active, vehicle.powerup_data, targets)
					end				
					
				elseif r == 1 then
					-- check if this client is the owner of this vehicle
					-- if not, dont remove. the owner decides when to remove
					-- todo
					
					vehicle.powerup_active.onDeactivate(vehicle.powerup_data, game_vehicle_id)
					VEHICLES[game_vehicle_id].powerup_active = nil
					VEHICLES[game_vehicle_id].powerup_data = nil
					
				elseif r == 2 then
					-- check if this client is the owner of this vehicle
					-- if not, do nothing. target hits come from their client
					-- todo
					if target_hits then
						addNewTargetHits(vehicle.powerup_active, vehicle.powerup_data, target_hits, game_vehicle_id, true)
						
					else
						vehicle.powerup_active.onDeactivate(vehicle.powerup_data, game_vehicle_id)
					end
					VEHICLES[game_vehicle_id].powerup_active = nil
					VEHICLES[game_vehicle_id].powerup_data = nil
					
				elseif r == 3 then
					if target_hits then
						-- check if this client is the owner of this vehicle
						-- if not, do nothing. target hits come from their client
						-- todo
						
						addNewTargetHits(vehicle.powerup_active, vehicle.powerup_data, target_hits, game_vehicle_id, false)
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

M.onVehicleSpawned = function(game_vehicle_id)
	VEHICLES[game_vehicle_id] = {
		charge = 1,
		powerup = nil,
		is_rendered = true,
		player_name = SUBJECT_SINGLEPLAYER -- <<<<-------------//// todo
	}
	
	TimedTrigger.new(
		'powerup_vehicle_initer_' .. game_vehicle_id,
		100,
		1,
		onPowerUpVehicleInit,
		game_vehicle_id
	)
	
	return VEHICLES[game_vehicle_id]
end

M.onVehicleDestroyed = function(game_vehicle_id)
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle == nil then return end
	
	-- drop powerup
	if vehicle.powerup then
		vehicle.powerup.onDrop(vehicle.data)
	end
	
	if vehicle.powerup_active then
		vehicle.powerup_active.onDeactivate(vehicle.data, game_vehicle_id)
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
			vehicle.player_name = SUBJECT_SINGLEPLAYER -- or mp name todo
		end
	end
end

-- ------------------------------------------------------------------------------------------------
-- Powerups
local function loadPowerups(set_path, group_path, group)
	if POWERUP_DEFS[group.name] then 
		Error('"' .. group.name .. '" from "' .. Util.fileName(group_path) .. '" already exists. Aborting load')
		return
	end
	
	-- check version
	if group.lib_version ~= M._NAME then
		Error('"' .. group.name .. '" from "' .. Util.fileName(group_path) .. '" is out of date. Aborting load')
		return
	end
	
	if #group.powerups > 0 then
		Error('Group "' .. group.name .. '" has invalid definitions for entry "powerups". Keep it empty. Aborting load')
		return
	end

	-- init powerups of the group
	local powerups = {}
	for _, powerup_name in pairs(group.leveling) do
		local file_path = set_path .. '/' .. group.name .. '/' .. powerup_name .. '.lua'
		local powerup, err = Util.compileLua(file_path)
		if powerup == nil then
			Error('Cannot compile "' .. powerup_name .. '" because of "' .. err .. '". Skipping.')
			--return -- abort
		else
			if powerup.lib_version ~= M._NAME then
				Error('"' .. powerup_name .. '" of group "' .. group.name .. '" is out of date. Rejecting powerup')
				
			else
				for _, trait in ipairs(powerup.traits or {}) do
					local trait_name = Extender.getTraitName(trait)
					if trait_name == nil then
						Error('Powerup "' .. powerup_name .. '" of group "' .. group.name .. '" lists an unknown "' .. trait .. '" trait')
					elseif type(powerup[trait]) ~= "function" then
						Error('Powerup "' .. powerup_name .. '" of group "' .. group.name .. '" lists the "' .. trait_name .. '" trait but doesnt have a callback for it. Skipping.')
						--return -- abort
					end
				end
				
				for _, trait in ipairs(powerup.respects_traits or {}) do
					local trait_name = Extender.getTraitName(trait)
					if trait_name == nil then
						Error('Powerup "' .. powerup_name .. '" of group "' .. group.name .. '" is listing to respect the "' .. trait .. '" trait, but this trait is unknown')
					end
				end
				
				powerup.internal_name = powerup_name
				powerup.file_path = Util.filePath(file_path)
				table.insert(group.powerups, powerup)
			end
		end
	end
	
	group.max_levels = #group.powerups
	group.file_path = Util.filePath(group_path)
	
	group.onInit()
	for _, vehicle in ipairs(getAllVehicles()) do
		local veh_id = vehicle:getId()
		group.onVehicleInit(veh_id)
		for _, powerup in pairs(group.powerups) do
			powerup.onInit()
			powerup.onVehicleInit(veh_id)
		end
	end
	
	-- something is wrong doing it like this
	--for _, vehicle in pairs(getAllVehicles()) do
		--onPowerUpVehicleInit(vehicle:getId())
	--end
	
	POWERUP_DEFS[group.name] = group
	
	if group.max_levels > MAX_CHARGE then MAX_CHARGE = group.max_levels end
end

local function selectPowerup()
	-- select random group
	local random_group = {}
	for group_name, _ in pairs(POWERUP_DEFS) do
		table.insert(random_group, group_name)
	end
	random_group = random_group[Util.mathRandom(1, #random_group)]
	
	return POWERUP_DEFS[random_group]
end

local function activatePowerup(game_vehicle_id, vehicle, type, charge_overwrite)
	local vehicle = vehicle or VEHICLES[game_vehicle_id]
	if vehicle.powerup == nil then
		Error('Vehicle owns no powerup')
		return
	end
	if vehicle.powerup_active then
		Error('Another powerup is active at this moment')
		return
	end
	
	-- select charge level
	local charge = 0
	if not charge_overwrite then
		charge = vehicle.charge
		if charge > vehicle.powerup.max_levels then charge = vehicle.powerup.max_levels end
	else
		charge = math.random(1, vehicle.powerup.max_levels)
	end
	
	-- select powerup_active
	local powerup_active = vehicle.powerup.powerups[charge]
	if powerup_active == nil then
		Error('Group "' .. vehicle.powerup.name .. '" has no powerups')
		return
	end
	
	-- trigger powerup event
	vehicle.powerup.onDrop(vehicle.data)
	
	-- consume powerup and charge
	if not charge_overwrite then vehicle.charge = 1 end
	vehicle.powerup = nil
	vehicle.data = nil
	
	-- add active powerup
	local r, targets = powerup_active.onActivate(be:getObjectByID(game_vehicle_id))
	if r == nil then
		Error('Powerup "' .. powerup_active.internal_name .. '" failed to activate "' .. tostring(targets) .. '"')
		return
	end
	if targets then
		addNewTargets(powerup_active, r, targets)
	end
	vehicle.powerup_active = powerup_active
	vehicle.powerup_data = r
	
	print("Powerup: " .. game_vehicle_id .. " activated " .. powerup_active.internal_name)
	if Extender.isSpectating(game_vehicle_id) then
		simpleDisplayActivatedPowerup(powerup_active.clear_name, type)
	end
end

local function takePowerup(location, trigger_data)
	--[[
		trigger_data
		[event] = "enter/exit"
		[subjectID] = game_vehicle_id
		[triggerName] = trigger name
	]]
	
	if location.powerup == nil then return end -- no powerup to grab available
	
	local game_vehicle_id = trigger_data.subjectID
	local vehicle = VEHICLES[game_vehicle_id] or M.onVehicleSpawned(game_vehicle_id) -- reload fix
	
	--dump(VEHICLES)
	
	-- see if the vehicle owner bothers us or not
	local is_own, is_traffic = Extender.isPlayerVehicle(game_vehicle_id)
	if not is_own and not is_traffic then return end -- we dont care
	
	-- now ask beammp server first for if we are allowed to pick this powerup up
	-- it will then give us an event back that lets us call this
	-- todo
	
	-- call event
	local r, variable = location.powerup.onPickup(location.data, be:getObjectByID(game_vehicle_id))
	if r == nil then -- error. wont pickup new and wont drop current
		Error('Vehicle cannot pickup "' .. location.powerup.name .. '" - "' .. tostring(variable) .. '"')
		return nil
		
	elseif r == 1 then -- success
		-- check currrent powerup
		if vehicle.powerup then
			print("PowerUp: " .. game_vehicle_id .. " dropped " .. vehicle.powerup.name)
			vehicle.powerup.onDrop(vehicle.data)
		end
				
		-- swap ownership
		vehicle.powerup = location.powerup
		vehicle.data = location.data
		
		print("PowerUp: " .. game_vehicle_id .. " picked up " .. vehicle.powerup.name)
	
	elseif r == 2 then -- dont pickup new one, drop current and remove the new one
		if vehicle.powerup then
			print("PowerUp: " .. game_vehicle_id .. " dropped " .. vehicle.powerup.name)
			vehicle.powerup.onDrop(vehicle.data)
			vehicle.powerup = nil
			vehicle.data = nil
		end
	
	elseif r == 3 then
		print("PowerUp: " .. game_vehicle_id .. " picked a charge")
		simpleDisplayActivatedPowerup("Charge", 3)
	
	elseif r == 4 then -- immediate execute - for negative powerups
		-- check currrent powerup
		if vehicle.powerup then
			print("PowerUp: " .. game_vehicle_id .. " dropped " .. vehicle.powerup.name)
			vehicle.powerup.onDrop(vehicle.data)
		end
				
		-- swap ownership
		vehicle.powerup = location.powerup
		vehicle.data = location.data
		
		print("PowerUp: " .. game_vehicle_id .. " picked up negative " .. vehicle.powerup.name)
		
		activatePowerup(game_vehicle_id, vehicle, r, variable)
		
	else
		Error('Unknown return type from powerup action of "' .. location.powerup.name .. '"')
		return
	end
	
	location.powerup = nil
	location.data = nil
	location.respawn_timer:stopAndReset()
	
	simplePowerUpDisplay()
	
	-- if traffic
	if is_traffic and vehicle.powerup then
		vehicle.charge = math.random(1, MAX_CHARGE)
		activatePowerup(game_vehicle_id, vehicle, r)
		
	elseif is_own and Extender.isSpectating(game_vehicle_id) then
		-- temp. the pickup sound will be on the group
		Engine.Audio.playOnce('AudioGui', "/lua/ge/extensions/powerups/default_powerup_pick_sound.ogg", {volume = 3, channel = 'Music'})
	end
end

-- ------------------------------------------------------------------------------------------------
-- Locations
local function loadLocations(triggers)
	for trigger_name, trigger in pairs(triggers) do
		if LOCATIONS[trigger_name] then
			Error('Location "' .. trigger_name .. '" is already known')
			trigger:delete()
		else
			-- adjust triggers
			local pos = trigger:getPosition()
			local rot = trigger:getRotation()
			
			-- needs testing
			local terrain_height = vec3(pos.x, pos.y, pos.z)
			terrain_height.z = terrain_height.z + 1
			--local terrain_height = vec3(pos.x, pos.y, 0)
			--terrain_height.z = core_terrain.getTerrainHeight(terrain_height) or (pos.z - 1)
			--if Util.dist3d(pos, terrain_height) < 1 then
			--	terrain_height.z = terrain_height.z + 1
			--end
			
			--terrain_height = terrain_height + 1
			
			trigger:setPosRot(terrain_height.x, terrain_height.y, terrain_height.z, rot.x, rot.y, rot.z, rot.w)
			trigger:setScale(VEC3(3, 3, 3))
			trigger:setField("TriggerMode", 0, "Overlaps")
			trigger:setField("TriggerTestType", 0, "Bounding box")
			trigger:setField("luaFunction", 0, "onBeamNGTrigger")
			
			LOCATIONS[trigger_name] = {
				obj = trigger,
				powerup = nil,
				data = nil,
				is_rendered = true,
				respawn_timer = hptimer(),
				rotation_timer = hptimer()
			}
		end
	end
end

local function restockPowerups(instant)
	for location_name, location in pairs(LOCATIONS) do
		if location.powerup == nil and (instant or location.respawn_timer:stop() > RESPAWN_TIME) then
			location.powerup = selectPowerup()
			if location.powerup ~= nil then
				location.data = location.powerup.onCreate(location.obj)
				location.rotation_timer:stopAndReset()
			end
		end
	end
end

-- ------------------------------------------------------------------------------------------------
-- Location rotation check routine
local function checkLocationRotation()
	for location_name, location in pairs(LOCATIONS) do
		if location.powerup and location.rotation_timer:stop() > ROTATION_TIME then
			location.powerup.onDespawn(location.data)
			location.powerup = selectPowerup()
			if location.powerup ~= nil then
				location.data = location.powerup.onCreate(location.obj)
				location.rotation_timer:stopAndReset()
			end
		end
	end
end

-- ------------------------------------------------------------------------------------------------
-- Hotkey
function onPowerUpActivateHotkey()
	local search_for = SUBJECT_SINGLEPLAYER -- or player_name if multiplayer -- todo
	local spectated_vehicle = getPlayerVehicle(0)
	if spectated_vehicle == nil then return end
	for game_vehicle_id, vehicle in pairs(VEHICLES) do
		if vehicle.player_name == search_for and game_vehicle_id == spectated_vehicle:getId() then
			activatePowerup(game_vehicle_id, vehicle)
			return
		end
	end
end

-- ------------------------------------------------------------------------------------------------
-- Interface
M.locations = LOCATIONS
M.vehicles = VEHICLES
M.powerup_defs = POWERUP_DEFS

M.testExec = function(game_vehicle_id, group, charge)
	if be:getObjectByID(game_vehicle_id) == nil then
		Error('Unknown vehicle')
		return
	end
	local vehicle = VEHICLES[game_vehicle_id] or M.onVehicleSpawned(game_vehicle_id)
	--location.data = location.powerup.onCreate(location.obj)
	
	local powerup = POWERUP_DEFS[group]
	if powerup == nil then
		Error('Unknown group')
		return nil
	end
	
	-- create fake location
	local location = {
		powerup = powerup,
		data = powerup.onCreate(be:getObjectByID(game_vehicle_id)), -- incorrect, needs a trigger
		respawn_timer = hptimer()
	}
	
	-- take ownership
	takePowerup(location, {subjectID = game_vehicle_id})
	
	-- set charge
	vehicle.charge = charge
	
	-- activate
	activatePowerup(game_vehicle_id, vehicle)
end


M.getCharge = function(game_vehicle_id)
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle == nil then return nil end
	return vehicle.charge
end

M.setCharge = function(game_vehicle_id, charge)
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle == nil then return nil end
	vehicle.charge = charge
end

M.addCharge = function(game_vehicle_id, charge)
	local vehicle = VEHICLES[game_vehicle_id]
	if vehicle == nil then return nil end
	vehicle.charge = math.min(math.max(vehicle.charge + charge, 1), MAX_CHARGE)
	
	print(game_vehicle_id .. " charge is " .. vehicle.charge)
end

M.loadPowerUpDefs = function(set_path)
	MAX_CHARGE = 0
	for _, group_path in pairs(Util.listFiles(set_path)) do
		local group, err = Util.compileLua(group_path)
		if group == nil then
			Error('Cannot compile "' .. Util.fileName(group_path) .. '" group because of "' .. err .. '"')
			
		else
			loadPowerups(set_path, group_path, group)
		end
	end
	
	restockPowerups(true)
end

M.loadLocationPrefab = function(path)
	local triggers, err = TriggerLoad.loadTriggerPrefab(path, false)
	if triggers == nil then
		Error(err)
		return
	end
	
	loadLocations(triggers)
	restockPowerups(true)
end

M.init = function()
	Extender.updatePowerUpsLib(M)

	-- if multiplayer then dont set some of these if not none of them
	-- todo
	
	local r = TimedTrigger.new(
		"PowerUps_restock",
		ROUTINE_LOCATIONS_RESTOCK,
		0,
		restockPowerups
	)
	if r == nil then
		Error('Cannot initialize restock routine')
	end
	
	local r = TimedTrigger.new(
		"PowerUps_rotation",
		ROUTINE_LOCATIONS_ROTATION,
		0,
		checkLocationRotation
	)
	if r == nil then
		Error('Cannot initialize restock routine')
	end
	
	local r = TimedTrigger.new(
		"PowerUps_checkRenderDist",
		ROUTINE_POWERUPS_CHECK_RENDER_DISTANCE,
		0,
		checkRenderDistance
	)
	if r == nil then
		Error('Cannot initialize render check routine')
	end
	
	local r = TimedTrigger.new(
		"PowerUps_checkTrafficlist",
		ROUTINE_POWERUPS_CHECK_TRAFFIC,
		0,
		checkIfTraffic
	)
	if r == nil then
		Error('Cannot initialize traffic check routine')
	end
	
	local r = TimedTrigger.new(
		"PowerUps_simpleDisplayRefresh",
		ROUTINE_POWERUPS_BASIC_DISPLAY_REFRESH,
		0,
		simplePowerUpDisplay
	)
	if r == nil then
		Error('Cannot initialize traffic check routine')
	end
	
	for _, vehicle in pairs(getAllVehicles()) do
		M.onVehicleSpawned(vehicle:getId())
	end
end

M.unload = function()
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

M.onBeamNGTrigger = function(data)
	--dump(data)
	local location = LOCATIONS[data.triggerName]
	if location and data.event == "enter" then
		-- if beammp then verify with server
		-- todo
		
		takePowerup(location, data)
	end
end

M.tick = function(dt)
	-- the order matters
	tickTargetQue()
	tickRenderQue(dt)
	tickTargetHitQue()
end


return M
