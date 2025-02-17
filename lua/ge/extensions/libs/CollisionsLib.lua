--[[
	License: None
	Author: Neverless (discord: neverless.)
]]

--[[
	GE Only atm

	-- Notes
	Contains all "objects" the vehicle is in collision with at this very moment
		GE LUA map.objects[gameVehicleID].objectCollisions
		- This also seems to take deformations into account
		- Might be based on actual node contact
		
		VE LUA mapmgr.objectCollisionIds


	-- has no GC overhead
	for _, veh in pairs(getAllVehicles()) do
		print(veh:getId())
	end
]]

local M = {}
local VEHICLES = {}


local function tick()
	for game_vehicle_id, collisions in pairs(VEHICLES) do
		-- remove no longer existing vehicles
		if map.objects[game_vehicle_id] == nil then
			VEHICLES[game_vehicle_id] = nil
		else
		
			-- remove collisions that are no longer happening
			for collision, _ in pairs(collisions) do
				if map.objects[game_vehicle_id].objectCollisions[collision] == nil then
					collisions[collision] = nil
				end
			end
		end
	end
	
	-- find new collisions and turn 
	for game_vehicle_id, data in pairs(map.objects) do
		VEHICLES[game_vehicle_id] = VEHICLES[game_vehicle_id] or {}
		
		for collision, _ in pairs(map.objects[game_vehicle_id].objectCollisions) do
			-- is true on first contact, turns false if contact continues
			VEHICLES[game_vehicle_id][collision] = VEHICLES[game_vehicle_id][collision] == nil
		end
	end
end


local function isColliding(game_vehicle_id)
	return #({next(VEHICLES[game_vehicle_id])}) > 0 -- hey, it works and might be cheaper then counting
end

local function newColliding(game_vehicle_id)
	local new_colliding = {}
	for colliding, state in pairs(VEHICLES[game_vehicle_id] or {}) do
		if state then
			new_colliding[colliding] = true
		end
	end
	
	return new_colliding
end

local function isCollidingWith(game_vehicle_id, with)
	return VEHICLES[game_vehicle_id][with] ~= nil
end

local function isNewCollidingWith(game_vehicle_id, with)
	return VEHICLES[game_vehicle_id][with] == true
end


M.isColliding = isColliding
M.newColliding = newColliding
M.isCollidingWith = isCollidingWith
M.isNewCollidingWith = isNewCollidingWith
M.tick = tick
return M
