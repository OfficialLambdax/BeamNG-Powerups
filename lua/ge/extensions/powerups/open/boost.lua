local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable = Extender.defaultImports()
local Type, onPickup, createObject, Default = Extender.defaultGroupVars(1)

local M = {
	-- Any name eg "ForwardShot". No duplicates with others of this Set.
	-- Create folder of the same name in this directory containing all the powerups
	name = "boost",
	
	type = Type.Utility,
	
	-- eg {"ForwardShot1", "ForwardShot2", "ForwardShot3"}
	-- Resolves to the file names in the group folder. Where
	-- eg ForwardShot1 is level 1, ForwardShot2 is level 2 .. etc
	leveling = {"boost 1", "boost 2", "teleport"},
	
	-- The powerup stays visible at default
	-- If the spectator is to far away from it it will not render except this is true
	-- Will prevent whileActive and whilePickup calls
	do_not_unload = false,
	
	probability = 5,
	
	-- This must match the power ups library _NAME or this powerup is rejected.
	-- This name is changed when the api changes, so to not load outdated powerups.
	lib_version = "enums",
	
	-- Max levels. autofilled
	max_levels = 0,
	
	-- autofilled
	powerups = {},
	
	-- DO NOT treat this is a variable cache.
	-- These are merely definitions
}

-- Anything you may want todo before anything is spawned
M.onInit = function() end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id) end

-- Spawn the powerup visual. Keep in mind that there can always be multiple
M.onCreate = function(trigger, is_rendered)
	-- Whatever you return here is given to all other callbacks too. So if you need the trigger, then also add that.
	return {
		marker = Extender.defaultPowerupCreator(trigger, "art/shapes/collectible/s_collect_machine_part.cdae", Point4F(0, 1, 0, 1), is_rendered)
	}
end

-- only called once
M.onUnload = function(data)
	if data.marker then
		data.marker:setHidden(true)
	end
end

-- only called once
M.onLoad = function(data)
	if data.marker then
		data.marker:setHidden(false)
	end
end

-- When the powerup is picked up by a vehicle
M.onPickup = function(data, vehicle, is_rendered)
	if is_rendered then
		Particle("BNGP_waterfallspray", data.marker:getPosition())
			:active(true)
			:velocity(0)
			:selfDisable(1000)
			:selfDestruct(3000)
	end
	
	--data.marker:setScale(vec3(0.5, 0.5, 0.5))
	--data.degrees = 0
	
	M.onDespawn(data)
	return onPickup.Success()
end

-- While the powerup is in someones inventory. Can have it hover above the vehicle or play sounds.
M.whilePickup = function(data, origin_id, dt)
	--[[
	local origin_vehicle = be:getObjectByID(origin_id)
	local pos = origin_vehicle:getSpawnWorldOOBB():getCenter()
	pos.z = pos.z + 1
	data.marker:setPosition(pos)
	
	if true then return end
	
	local origin_vehicle = be:getObjectByID(origin_id)
	local up_dir = origin_vehicle:getDirectionVectorUp()
	local for_dir = origin_vehicle:getDirectionVector()
	local next_dir = MathUtil.rotateVectorByDegrees(for_dir, up_dir, data.degrees)
	data.degrees = data.degrees + 0.465 * dt
	
	local pos = origin_vehicle:getSpawnWorldOOBB():getCenter()
	local pos = MathUtil.getPosInFront(pos, next_dir, 3)
	
	data.marker:setPosition(pos)
	]]
end

-- When the powerup is dropped by a vehicle. Happens once the powerup is activated, swapped or if it looses the powerup through any other means
M.onDrop = function(data, origin_id, is_rendered) end

-- While the powerup is spawned in the world. As in if you want it to display special effects while its waiting to be picked up. Aka slowly moving up n down.
M.whileActive = function(data, dt)
	Extender.defaultPowerupRender(data.marker, dt)
end

-- When the powerup is removed from the world once and for all
M.onDespawn = function(data)
	Extender.defaultPowerupDelete(data.marker)
	data.marker = nil
end

return M
