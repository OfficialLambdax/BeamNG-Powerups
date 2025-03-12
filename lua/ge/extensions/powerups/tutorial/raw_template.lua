local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable, Ui = Extender.defaultImports(1)
local Type, onPickup, createObject, Default = Extender.defaultGroupVars(1)

local M = {
	-- Name of this group. Must be unique in this Set.
	name = "raw_template",
	
	-- Define general type of this group. Decides over where this powerup is spawned in the world.
	type = Type.Undefined,
	
	-- Define the level hirachy of this group
	-- {"powerup 1", "powerup N"}
	leveling = {"raw_template"},
	
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
		marker = Default.powerupCreator(
			trigger,
			"art/shapes/collectible/s_collect_machine_part.cdae",
			Point4F(0, 1, 0, 1),
			is_rendered
		)
	}
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, dt)
	Default.powerupRender(data.marker, dt)
end

-- Vehicle that wants to pick this powerup up
M.onPickup = function(data, vehicle, is_rendered)
	M.onDespawn(data)
	return onPickup.Success()
end

-- Hooked to the onPreRender tick
M.whilePickup = function(data, origin_id, dt) end

M.onDespawn = function(data)
	data.marker = Default.powerupDelete(data.marker)
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
