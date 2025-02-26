local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx = Extender.defaultImports()
local Type, onPickup, createObject = Extender.defaultGroupVars()

local M = {
	-- Name of this group. Must be unique in this Set.
	name = "repair",
	
	-- Define general type of this group. Decides over where this powerup is spawned in the world.
	type = Type.Utility,
	
	-- Define the level hirachy of this group
	-- {"powerup 1", "powerup N"}
	leveling = {"repair 1", "repair 2"},
	
	-- Turn true to not be affected by the render distance
	do_not_unload = false,
	
	-- Define spawn chance between 0 and 10. Where 0 is none and 10 max.
	-- Default is 5
	probability = 5,
	
	-- Must match the libs version name. If it doesnt, this powerup group is considered out of date
	-- dump(Lib.getLibVersion())
	lib_version = "enums",
	
	-- Autofilled.
	max_levels = 0,
	powerups = {},
	
	-- Contains the dir path to this powerup
	file_path = "",
	
	-- Add extra variables here if needed. Constants only!
	--my_var = 0,
}

-- Called once when the group is loaded
M.onInit = function() end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Trigger: lua trigger
M.onCreate = function(trigger)
	return {
		marker = Extender.defaultPowerupCreator(
			trigger,
			"art/shapes/collectible/s_collect_medikit.cdae",
			Point4F(0, 1, 0, 1)
		)
	}
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, dt)
	Extender.defaultPowerupRender(data.marker, dt)
end

-- When the powerup is picked up by a vehicle
M.onPickup = function(data, vehicle)
	data.vehicle = vehicle
	
	Particle("BNGP_waterfallspray", data.marker:getPosition())
		:active(true)
		:velocity(0)
		:selfDisable(1000)
		:selfDestruct(3000)
	
	M.onDespawn(data)
	return onPickup.Success()
end

-- Hooked to the onPreRender tick
M.whilePickup = function(data) end

M.onDespawn = function(data)
	data.marker = Extender.defaultPowerupDelete(data.marker)
end

-- When the vehicle drops the powerup. Eg because it picked up another
M.onDrop = function(data) end

-- Render Distance related
M.onUnload = function(data)
	if data.marker then data.marker:setHidden(true) end
end

M.onLoad = function(data)
	if data.marker then data.marker:setHidden(false) end
end

return M
