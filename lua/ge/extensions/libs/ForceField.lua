--[[
	License: None
	Author: Neverless (discord: neverless.)
]]

--[[
	Inspired by the game own force field system but a complete rewrite
	Is written around the idea to handle multiple vehicles at once where each force field can be custom in looks and behaviour.
		
	At default a force field marker is rendered around a origin vehicle, when another vehicle enters it it will be pushed away.
		
	All this behaviour can be changed for every vehicle. Imagine powerups and differently working or differently strong defense powerups with different appearances and inner workings. One may just push you away, another maybe flips you.
	
	See DEMO()
]]

local function DEMO()
	-- SIMPLE
	ForceField.addVehicle(game_vehicle_id) -- done, dis it.

	
	-- FULL EXAMPLE
	local my_radius = 7 -- meters
	
	local my_custom_settings = {
		funny_var = 123,
		another_funny_var = "hello world"
	}
	
	-- where origin_vehicle is the force field origin
	-- and target_vehicle the vehicle that entered it
	local function myOnForceFieldEnterEvent(origin_vehicle, target_vehicle, settings)
		print(settings.funny_var)
		
		-- push vehicle away, flip it, hide it, ghost it, what ever you want!
		
		-- returning true will recall this event as long as the target vehicle is inside this force field
		return true
	end
	
	local function myOnForceFieldExitEvent(origin_vehicle, target_vehicle, settings)
		print(settings.another_funny_var)
		
		-- stop whatever you did to that other vehicle if you have to. Ghosted it? unghost now!
		
		-- returning true will keep calling this event after the target vehicle exited the force field. Might be usefull if some mechanic needs more then one call to finish
		return true
	end
	
	-- Note: both events are only called once!
	
	local function myMarkerCreator(radius)
		-- create your cool marker here!
		local marker = {}
		
		-- or!
		-- create multiple
		-- but if you do that also create callbacks for the marker update and destroy functions!
		-- because this lib can only handle one marker by default
		local marker = {"marker 1", "marker 2"}
		
		-- and then return it
		return marker
	end
	
	local function myMarkerUpdater(origin_vehicle, settings)
		-- move the marker to the new position of the vehicle or display effects for the surrounding vehicles!
		-- settings.marker:setPosRot(...)
	end
	
	local function myMarkerDestroy(marker)
		-- destroy it or them!
		marker:delete()
	end
	
	-- All functions ready? now its time to hook into it
	ForceField.addVehicle(
		game_vehicle_id,
		my_radius,
		my_custom_settings,
		myOnForceFieldEnterEvent,
		myOnForceFieldExitEvent,
		myMarkerCreator,
		myMarkerUpdater,
		myMarkerDestroy
	)
end

local Util = require("libs/Util")

local M = {
	_VERSION = 0.1 -- 05.02.2025 DD.MM.YYYY
}

--[[
	Format
		["game_vehicle_id"] = table
			[radius] = int
			[force_multiplier] = int
			[marker] = todo
			[on_callback] = function(origin_vehicle, target_vehicle, settings)
				Called when a vehicle enters the force field ONCE
				Where
					- origin_vehicle is the force fielded vehicle
					- target_vehicle the vehicle that entered the field
					- settings the settings given into addVehicle and/or atleast
						[radius] = int
						[marker] = markerObj
						[on_callback] = function
						[off_callback] = function
						[inside] = table
							[game_vehicle_id] = true
			[off_callback] = function(origin_vehicle, target_vehicle, settings)
				Called when a vehicle leaves the force field
]]
local VEHICLES = {}

local ACTIVE = false
--local MASS = -60000000000000

-- You can overwrite this function for custom markers!
-- if you return more then 1 marker object then also hook into M.updateMarker and M.destroyMarker otherwise this lib wont be able to handle it
local function createMarker(radius, origin_vehicle)
	local half_extends = origin_vehicle:getSpawnWorldOOBB():getHalfExtents()
	
	local marker = createObject("TSStatic")
	marker.shapeName = "art/shapes/interface/checkpoint_marker.dae"
	marker.useInstanceRenderData = 1
	marker.instanceColor = Point4F(1, 0, 0, 1)
	marker:setPosRot(0, 0, 0, 0, 0, 0, 1)
	marker.scale = vec3(half_extends.x + radius, half_extends.y + radius, 2)
	marker:registerObject("ff_marker_" .. Util.randomName())

	return marker
end

-- You can overwrite this function if your marker needs custom handling
local function updateMarker(origin_vehicle, settings)
	local bounding_box = origin_vehicle:getSpawnWorldOOBB()
	local center = bounding_box:getCenter()
	local rot = quatFromDir(
		-vec3(origin_vehicle:getDirectionVector()),
		vec3(origin_vehicle:getDirectionVectorUp())
	)
	settings.marker:setPosRot(center.x, center.y, center.z - 1, rot.x, rot.y, rot.z, rot.w)
end

local function destroyMarker(marker)
	marker:delete()
end

local function dist3d(veh_1, veh_2)
	local v1 = veh_1:getSpawnWorldOOBB():getCenter()
	local v2 = veh_2:getSpawnWorldOOBB():getCenter()
	return math.sqrt((v2.x - v1.x)^2 + (v2.y - v1.y)^2 + (v2.z - v1.z)^2)
end

local function checkDist(veh_1, veh_2)
	local v1 = veh_1:getSpawnWorldOOBB():getCenter()
	local v2 = veh_2:getSpawnWorldOOBB():getCenter()
	-- todo
end

local function onDefaultForceFieldReaction(origin_vehicle, target_vehicle, settings)
	--[[local bounding_box = origin_vehicle:getSpawnWorldOOBB()
	local center = bounding_box:getCenter()
	local half_extends = bounding_box:getHalfExtents()
	local longest_half_extend = math.max(math.max(half_extends.x, half_extends.y), half_extends.y)
	local vehicle_size_factor = longest_half_extend / 3
	
	local command = string.format(
		'obj:setPlanets({%f, %f, %f, %d, %f})',
		center.x,
		center.y,
		center.z,
		settings.radius,
		MASS * vehicle_size_factor * settings.force_multiplier
	)
	
	target_vehicle:queueLuaCommand(command)
	
	return true]]

	local vel1 = origin_vehicle:getVelocity()
	local vel2 = target_vehicle:getVelocity()
	
	local pos1 = origin_vehicle:getPosition()
	local pos2 = target_vehicle:getPosition()
	
	local push = ((vel1 - vel2) * 0.5) + (pos2 - pos1)
	target_vehicle:applyClusterVelocityScaleAdd(target_vehicle:getRefNodeId(), 1, push.x, push.y, push.z)
	
	return true
end

local function offDefaultForceFieldReaction(origin_vehicle, target_vehicle, settings)
	--target_vehicle:queueLuaCommand("obj:setPlanets({})")
end

local function remVehicle(game_vehicle_id)
	if VEHICLES[game_vehicle_id] == nil then return end
	
	for _, target_vehicle in pairs(getAllVehicles()) do
		target_vehicle:queueLuaCommand("obj:setPlanets({})")
	end
	
	VEHICLES[game_vehicle_id].marker_destroy_callback(VEHICLES[game_vehicle_id].marker)
	VEHICLES[game_vehicle_id] = nil
	if #({next(VEHICLES)}) == 0 then ACTIVE = false end
end

-- game_vehicle_id, rest is optional
local function addVehicle(game_vehicle_id, radius, settings, on_callback, off_callback, marker_create_callback, marker_update_callback, marker_destroy_callback)
	if VEHICLES[game_vehicle_id] then remVehicle(game_vehicle_id) end -- prevent marker leaking
	
	local settings = settings or {
		--force_multiplier = force_multiplier or 1
	}
	settings.marker_create_callback = marker_create_callback or createMarker
	settings.marker_update_callback = marker_update_callback or updateMarker
	settings.marker_destroy_callback = marker_destroy_callback or destroyMarker
	settings.on_callback = on_callback or onDefaultForceFieldReaction
	settings.off_callback = off_callback or offDefaultForceFieldReaction
	
	settings.inside = {}
	settings.radius = radius or 5
	settings.marker = settings.marker_create_callback(settings.radius, be:getObjectByID(game_vehicle_id))
	
	VEHICLES[game_vehicle_id] = settings
	ACTIVE = true
end

local function unload()
	for game_vehicle_id, _ in pairs(VEHICLES) do
		remVehicle(game_vehicle_id)
	end
end

local function hasForceField(game_vehicle_id)
	return VEHICLES[game_vehicle_id] ~= nil
end

local function tick()
	if not ACTIVE then return end
	
	local all_vehicles = getAllVehicles()
	for game_vehicle_id, settings in pairs(VEHICLES) do
		local origin_vehicle = be:getObjectByID(game_vehicle_id)
		if origin_vehicle == nil then
			remVehicle(game_vehicle_id) -- vehicle disappeared
			
		else
			settings.marker_update_callback(origin_vehicle, settings)
			
			-- activate force field for close enough vehicles
			for _, target_vehicle in pairs(all_vehicles) do
				if origin_vehicle:getId() ~= target_vehicle:getId() then
					local inside_state = settings.inside[target_vehicle:getId()]
					
					if dist3d(origin_vehicle, target_vehicle) < settings.radius then
						if inside_state == nil or inside_state == true then
							settings.inside[target_vehicle:getId()] = settings.on_callback(origin_vehicle, target_vehicle, settings) or false
						end
						
					else
						if inside_state ~= nil then
							settings.inside[target_vehicle:getId()] = settings.off_callback(origin_vehicle, target_vehicle, settings)
						end
					end
				end
			end
		end
	end
end

M.addVehicle = addVehicle
M.remVehicle = remVehicle
M.unload = unload
M.hasForceField = hasForceField
M.tick = tick
return M
