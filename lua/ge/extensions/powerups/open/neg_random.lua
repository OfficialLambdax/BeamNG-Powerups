local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil = Extender.defaultImports()
local Type, onPickup = Extender.defaultGroupVars()

local M = {
	-- Any name eg "ForwardShot". No duplicates with others of this Set.
	-- Create folder of the same name in this directory containing all the powerups
	name = "neg_random",
	
	type = Type.Negative,
	
	-- eg {"ForwardShot1", "ForwardShot2", "ForwardShot3"}
	-- Resolves to the file names in the group folder. Where
	-- eg ForwardShot1 is level 1, ForwardShot2 is level 2 .. etc
	leveling = {"barrelroll", "jinxed", "rem1charge"},
	
	-- The powerup stays visible at default
	-- If the spectator is to far away from it it will not render except this is true
	-- Will prevent whileActive and whilePickup calls
	do_not_unload = false,
	
	probability = 3,
	
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
M.onInit = function()
	
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id)
	
end

-- Spawn the powerup visual. Keep in mind that there can always be multiple
M.onCreate = function(trigger)
	-- Whatever you return here is given to all other callbacks too. So if you need the trigger, then also add that.
	return {
		trigger = trigger,
		marker = Extender.defaultPowerupCreator(trigger, "art/shapes/collectible/s_collect_medikit.cdae", Point4F(0, 0, 0, 0)),
		vehicle = nil
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
M.onPickup = function(data, vehicle)
	data.vehicle = vehicle
	M.onDespawn(data)
	
	return onPickup.IsNegative
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
M.whileActive = function(data, dt)
	Extender.defaultPowerupRender(data.marker, dt)
end

-- When the powerup is removed from the world once and for all
M.onDespawn = function(data)
	Extender.defaultPowerupDelete(data.marker)
	data.marker = nil
end

return M
