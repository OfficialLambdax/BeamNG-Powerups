local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject = Extender.defaultPowerupVars()

local M = {
	-- Clear name of the powerup
	clear_name = "Ghost",
	
	-- If the camera is to far away from this powerups owner it will not render except this is true
	-- Will prevent whileActive calls
	do_not_unload = false,
	
	max_len = 30000,
	target_info_descriptor = nil,
	
	--[[
		eg. {Trait.Consuming, Trait.Reflective}
	]]
	traits = {Trait.Ghosted},
	
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
	
	activate_sound = nil,
	effect_length = 9000,
}



-- Anything you may want todo before anything is spawned. eg loading sounds in all vehicle vms
M.onInit = function(group_defs)
	M.activate_sound = Sound(M.file_path .. 'sounds/ghost.ogg', 3)
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id) end

-- When the powerup is activated
M.onActivate = function(vehicle)
	vehicle:queueLuaCommand("obj:setGhostEnabled(true)")
	vehicle:setMeshAlpha(0.5, "", false)
	M.activate_sound:playVE(vehicle:getId())
	return onActivate.Success({end_timer = hptimer()})
end

-- only called once
M.onUnload = function(data) end

-- only called once
M.onLoad = function(data) end

-- While the powerup is active. Update its render here, detect if it hit something. that kinda stuff
M.whileActive = function(data, origin_id)
	if data.end_timer:stop() < M.effect_length then return whileActive.Continue() end
	
	local vehicle = be:getObjectByID(origin_id)
	if #MathUtil.getVehiclesInsideRadius(vehicle:getPosition(), 5, origin_id) > 0 then return whileActive.Continue() end
	
	return whileActive.Stop()
end

-- Called once one or multiple targets have been chosen.
-- In a singleplayer scenario this event is called directly.
-- In a multiplayer scenario once the server confirms the targets.
M.onTargetSelect = function(data, targets) end

-- When the powerup hit another vehicle
M.onTargetHit = function(data, origin_id, target_id) end

-- When the powerup hit our vehicle. Aka another vehicle with this powerup shoots at our vehicle
-- We are target_id
M.onHit = function(data, origin_id, target_id) end

-- When the powerup is destroyed. eg when the vehicle is deleted or the powerup ended
M.onDeactivate = function(data, origin_id)
	local vehicle = be:getObjectByID(origin_id)
	vehicle:setMeshAlpha(1, "", false)
	vehicle:queueLuaCommand("obj:setGhostEnabled(false)")
end

M[Trait.Ghosted] = function(data, origin_id) end

return M
