local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

local M = {
	-- Clear name of the powerup
	clear_name = "EMP",
	
	-- If the camera is to far away from this powerups owner it will not render except this is true
	-- Will prevent whileActive calls
	do_not_unload = false,
	
	max_len = 1000,
	target_info_descriptor = nil,
	
	--[[
		eg. {Trait.Consuming, Trait.Reflective}
	]]
	traits = {},
	
	--[[
		eg. {Trait.Consuming, Trait.Reflective}
	]]
	respects_traits = {},
	
	-- This must match the power ups library _NAME or this powerup is rejected.
	-- This name is changed when the api changes, so to not load outdated powerups.
	lib_version = "enums",
	
	-- autofilled
	file_path = "",
	
	-- DO NOT treat this is a variable cache.
	-- These are merely definitions
	
	set_name = "emp_" .. Util.randomName(),
	activate_sound = nil,
	effect_radius = 20,
}



-- Anything you may want todo before anything is spawned. eg loading sounds in all vehicle vms
M.onInit = function(group_defs)
	Sets.loadSet(M.file_path .. "sets/emp.lua", M.set_name)
	M.activate_sound = Sound('art/sounds/ext/countermeasure/electrical_shock_zap.ogg', 6)
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id) end

-- When the powerup is activated
M.onActivate = function(vehicle)
	M.activate_sound:playVE(vehicle:getId())
	
	return onActivate.TargetHits(
		MathUtil.getVehiclesInsideRadius(vehicle:getPosition(), M.effect_radius, vehicle:getId())
	)
end

-- only called once
M.onUnload = function(data) end

-- only called once
M.onLoad = function(data) end

-- While the powerup is active. Update its render here, detect if it hit something. that kinda stuff
M.whileActive = function(data, origin_id) end

-- Called once one or multiple targets have been chosen.
-- In a singleplayer scenario this event is called directly.
-- In a multiplayer scenario once the server confirms the targets.
M.onTargetSelect = function(data, targets)
	data.targets = targets
end

-- When the powerup hit another vehicle
M.onTargetHit = function(data, origin_id, target_id) end

-- When the powerup hit our vehicle. Aka another vehicle with this powerup shoots at our vehicle
-- We are target_id
M.onHit = function(data, origin_id, target_id)
	-- everything in here is executed on our and the remote end
	-- push vehicle away from us
	local set = Sets.getSet(M.set_name):VETarget(target_id)
	if set == nil then return end
	if Extender.isPlayerVehicle(target_id) then set:resetBlock() end
	set:exec()
end

-- When the powerup is destroyed. eg when the vehicle is deleted or the powerup ended
M.onDeactivate = function(data) end

return M
