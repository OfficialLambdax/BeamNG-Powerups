
local PowerUps = require("libs/PowerUps")
local Util = require("libs/Util")

local M = {
	-- Any name eg "ForwardShot". No duplicates with others of this Set.
	-- Create folder of the same name in this directory containing all the powerups
	name = "push",
	
	-- eg {"ForwardShot1", "ForwardShot2", "ForwardShot3"}
	-- Resolves to the file names in the group folder. Where
	-- eg ForwardShot1 is level 1, ForwardShot2 is level 2 .. etc
	leveling = {"push 1"},
	
	-- The powerup stays visible at default
	-- If the spectator is to far away from it it will not render except this is true
	-- Will prevent whileActive and whilePickup calls
	do_not_unload = false,
	
	-- This must match the power ups library _NAME or this powerup is rejected.
	-- This name is changed when the api changes, so to not load outdated powerups.
	lib_version = "init",
	
	-- Max levels. autofilled
	max_levels = 0,
	
	-- autofilled
	powerups = {},
	
	-- DO NOT treat this is a variable cache.
	-- These are merely definitions
}

-- Anything you may want todo before anything is spawned
M.onInit = function()
	
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id)
	
end

-- Spawn the powerup visual. Keep in mind that there can always be multiple
M.onCreate = function(trigger)
	local pos = trigger:getPosition()
	local rot = trigger:getRotation()
	local scale = trigger:getScale()

	local marker = createObject("TSStatic")
	marker.shapeName = "art/shapes/collectible/s_collect_machine_part.cdae"
	marker.useInstanceRenderData = 1
	marker.instanceColor = Point4F(0, 0, 1, 1)
	--marker:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
	marker:setPosRot(pos.x, pos.y, pos.z, 0, 0, 0, 1)
	marker.scale = vec3(scale.x, scale.y, scale.z)
	
	local test = "my_powerup_" .. Util.randomName()
	marker:registerObject(test)
	
	-- Whatever you return here is given to all other callbacks too. So if you need the trigger, then also add that.
	return {trigger = trigger, marker = marker, vehicle = nil}
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
M.onPickup = function(data, vehicle)
	data.vehicle = vehicle
	M.onDespawn(data)
	
	return 1
	--[[
		Return Values
			nil = pickup fails. current powerup wont be dropped, this one not picked up
			1 = success
			2 = will drop the current powerup, consume this one but not pick it up
			3 = Reserved for charges
	]]
end

-- While the powerup is in someones inventory. Can have it hover above the vehicle or play sounds.
M.whilePickup = function(data)
	--print("while pickup")
end

-- When the powerup is dropped by a vehicle. Happens once the powerup is activated, swapped or if it looses the powerup through any other means
M.onDrop = function(data)
	--print("drop")
end

-- While the powerup is spawned in the world. As in if you want it to display special effects while its waiting to be picked up. Aka slowly moving up n down.
-- Routine is 100ms
M.whileActive = function(data)
	--print("while active")
	--local pos = data.marker:getPosition()
	--local rot = data.marker:getRotation()
	
	--data.z = (data.z or rot.z) + 0.01
	--if data.z >= 1 then data.z = 0 end
	--print(data.z)
	--data.marker:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, data.z, rot.w)
end

-- When the powerup is removed from the world once and for all
M.onDespawn = function(data)
	if data.marker then
		data.marker:delete()
		data.marker = nil
	end
end

return M
