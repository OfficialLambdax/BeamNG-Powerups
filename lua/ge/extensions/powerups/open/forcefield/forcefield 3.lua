local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

local M = {
	-- Clear name of the powerup
	clear_name = "Force Field III",
	
	-- If the camera is to far away from this powerups owner it will not render except this is true
	-- Will prevent whileActive calls
	do_not_unload = false,
	
	max_len = 30000,
	target_info_descriptor = nil,
	
	--[[
		eg. {Trait.Consuming, Trait.Reflective}
	]]
	traits = {Trait.Consuming, Trait.StrongConsuming},
	
	--[[
		eg. {Trait.Consuming, Trait.Reflective}
	]]
	respects_traits = {Trait.Ghosted},
	
	-- This must match the power ups library _NAME or this powerup is rejected.
	-- This name is changed when the api changes, so to not load outdated powerups.
	lib_version = "enums",
	
	-- autofilled
	file_path = "",
	
	-- DO NOT treat this is a variable cache.
	-- These are merely definitions. Exceptions are constants.
	
	force_field_set = "force_field_" .. Util.randomName(),
	force_field_sound = nil,
	force_field_hit_sound = nil,
}


M.onInit = function(group_defs)
	Sets.loadSet(M.file_path .. "sets/forceField 3.lua", M.force_field_set)
	
	M.force_field_sound = Sound('art/sounds/ext/forcefield/forcefield_strong.ogg', 6)
	M.force_field_hit_sound = Sound('art/sounds/ext/forcefield/shield_hit.ogg', 6)
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id)
	
end

-- When the powerup is activated
M.onActivate = function(vehicle)
	local set = Sets.getSet(M.force_field_set)
	if set == nil then return nil, "required set could not be found" end
	
	local id = vehicle:getId()
	set:VETarget(id)
	if Extender.isPlayerVehicle(id) then
		set:resetBlock()
	end
	set:exec()
	
	M.force_field_sound:smart(vehicle:getId())

	return onActivate.Success({timer = hptimer(), end_in = set:maxTime(), id = id})
end

-- only called once
M.onUnload = function(data)

end

-- only called once
M.onLoad = function(data)

end

-- While the powerup is active. Update its render here, detect if it hit something. that kinda stuff
M.whileActive = function(data)
	if data.timer:stop() < data.end_in then return whileActive.Continue() end
	return whileActive.Stop()
end

-- Called once one or multiple targets have been chosen.
-- In a singleplayer scenario this event is called directly.
-- In a multiplayer scenario once the server confirms the targets.
M.onTargetSelect = function(data, targets)

end

-- When the powerup hit another vehicle
M.onTargetHit = function(data)
	
end

-- When the powerup hit our vehicle
M.onHit = function(data)
	
end

-- When the powerup is destroyed. eg when the vehicle is deleted or the powerup ended
M.onDeactivate = function(data)

end

M[Trait.Consuming] = function(data, origin_id, target_id)
	M.force_field_hit_sound:playVE(origin_id)
end

M[Trait.StrongConsuming] = function(data, origin_id, target_id)
	M.force_field_hit_sound:playVE(origin_id)
end

return M
