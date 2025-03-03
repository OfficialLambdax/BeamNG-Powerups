local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

local M = {
	-- Clear name of the powerup
	clear_name = "Power Blast",
	
	-- If the camera is to far away from this powerups owner it will not render except this is true
	-- Will prevent whileActive calls
	do_not_unload = false,
	
	max_len = 2000,
	target_info_descriptor = nil,
	
	--[[
		eg. {Trait.Consuming, Trait.Reflective}
	]]
	traits = {},
	
	--[[
		eg. {Trait.Consuming, Trait.Reflective}
	]]
	respects_traits = {Trait.StrongConsuming},
	
	-- This must match the power ups library _NAME or this powerup is rejected.
	-- This name is changed when the api changes, so to not load outdated powerups.
	lib_version = "enums",
	
	-- autofilled
	file_path = "",
	
	-- DO NOT treat this is a variable cache.
	-- These are merely definitions
	
	activate_sound = nil,
	effect_radius = 30,
}



-- Anything you may want todo before anything is spawned. eg loading sounds in all vehicle vms
M.onInit = function(group_defs)
	M.activate_sound = Sound('art/sounds/ext/shockwave/shockwave_heavy.ogg', 7)
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id) end

-- When the powerup is activated
M.onActivate = function(vehicle)
	local vehicle_id = vehicle:getId()
	M.activate_sound:smartSFX(vehicle_id)
	
	Particle("BNGP_32", vehicle:getPosition())
		:active(true)
		:follow(vehicle, 2000)
		:selfDisable(2000)
		:selfDestruct(15000)
		
	vehicle:queueLuaCommand('PowerUpExtender.jump(5)')
	
	local targets = MathUtil.getVehiclesInsideRadius(vehicle:getPosition(), M.effect_radius, vehicle_id)
	targets = Extender.cleanseTargetsBehindStatics(vehicle:getPosition(), targets)
	
	return onActivate.TargetHits(targets)
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
M.onTargetSelect = function(data, targets) end

-- When the powerup hit another vehicle
M.onTargetHit = function(data, origin_id, target_id) end

-- When the powerup hit our vehicle. Aka another vehicle with this powerup shoots at our vehicle
-- We are target_id
M.onHit = function(data, origin_id, target_id)
	if Extender.hasTraitCall(target_id, Trait.StrongConsuming, origin_id) then return end
	-- push vehicle away from us
	local origin_vehicle = be:getObjectByID(origin_id)
	local target_vehicle = be:getObjectByID(target_id)
	
	local vel1 = origin_vehicle:getVelocity()
	local vel2 = target_vehicle:getVelocity()
	
	local pos1 = origin_vehicle:getPosition()
	local pos2 = target_vehicle:getPosition()
	
	local push = (pos2 - pos1):normalized() * (math.min(M.effect_radius, M.effect_radius - Util.dist3d(pos2, pos1)) * 2)
	target_vehicle:applyClusterVelocityScaleAdd(target_vehicle:getRefNodeId(), 1, push.x, push.y, push.z)
	target_vehicle:queueLuaCommand("PowerUpExtender.addAngularVelocity(0, 0, 3, 0, 10, 0)")
end

-- When the powerup is destroyed. eg when the vehicle is deleted or the powerup ended
M.onDeactivate = function(data) end

return M
