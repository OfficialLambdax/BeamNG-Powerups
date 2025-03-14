local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable = Extender.defaultImports()
local Type, onPickup, createObject, Default = Extender.defaultGroupVars(1)

local M = {
	-- Name of this group. Must be unique in this Set.
	name = "banana",
	
	-- Define general type of this group. Decides over where this powerup is spawned in the world.
	type = Type.Defensive,
	
	-- Define the level hirachy of this group
	-- {"powerup 1", "powerup N"}
	leveling = {"banana 1", "banana 2"},
	
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
M.onCreate = function(trigger, is_rendered)
	return {
		marker = Extender.defaultPowerupCreator(
			trigger,
			"art/shapes/pwu/spheres/banana.cdae",
			Point4F(1, 1, 1, 1),
			is_rendered
		)
	}
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, dt)
	Extender.defaultPowerupRender(data.marker, dt)
end

-- Vehicle that wants to pick this powerup up
M.onPickup = function(data, vehicle, is_rendered)
	if is_rendered then
		Particle("BNGP_waterfallspray", data.marker:getPosition())
			:active(true)
			:velocity(0)
			:selfDisable(1000)
			:selfDestruct(3000)
	end
	M.onDespawn(data)
	return onPickup.Success()
end

-- Hooked to the onPreRender tick
M.whilePickup = function(data, origin_id, dt) end

M.onDespawn = function(data)
	data.marker = Extender.defaultPowerupDelete(data.marker)
end

-- When the vehicle drops the powerup. Eg because it picked up another
M.onDrop = function(data, origin_id, is_rendered) end

-- Render Distance related
M.onUnload = function(data)
	if data.marker then data.marker:setHidden(true) end
end

M.onLoad = function(data)
	if data.marker then data.marker:setHidden(false) end
end

return M
