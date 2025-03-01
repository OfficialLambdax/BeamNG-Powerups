local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject = Extender.defaultPowerupVars()

local M = {
	-- Clear name of the powerup
	clear_name = "Teleport",
	
	-- If the camera is to far away from this powerups owner it will not render except this is true
	-- Will prevent whileActive calls
	do_not_unload = false,
	
	max_len = 3000,
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
	
	activate_sound = nil,
	set_name = "teleport_" .. Util.randomName()
}



-- Anything you may want todo before anything is spawned. eg loading sounds in all vehicle vms
M.onInit = function(group_defs)
	Sets.loadSet(M.file_path .. "sets/teleport.lua", M.set_name)
	M.activate_sound = Sound('art/sounds/ext/boost/teleport.ogg', 12)
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id)
	
end

-- When the powerup is activated
M.onActivate = function(vehicle)
	local set = Sets.getSet(M.set_name)
	if not set then return nil, "Teleport set not available" end
	
	local veh_id = vehicle:getId()
	set:VETarget(veh_id)
	set:mod("sound"):args(veh_id, M.activate_sound)
	
	local is_player, is_traffic = Extender.isPlayerVehicle(veh_id)
	if not is_player and not is_traffic then
		set:mod("tp"):state(false) -- tp decision is only to be made for local vehicles
	end
	if Extender.isSpectating(veh_id) then -- if anyone is spectating
		set:resetBlock()
	end
	set:exec()
	
	return onActivate.Success({effect_timer = hptimer()})
end

-- only called once
M.onUnload = function(data)
	
end

-- only called once
M.onLoad = function(data)
	
end

-- While the powerup is active. Update its render here, detect if it hit something. that kinda stuff
M.whileActive = function(data, origin_id)
	if data.effect_timer:stop() > 1000 then return whileActive.Stop() end
	return whileActive.Continue()
end

-- Called once one or multiple targets have been chosen.
-- In a singleplayer scenario this event is called directly.
-- In a multiplayer scenario once the server confirms the targets.
M.onTargetSelect = function(data, targets)
	
end

-- When the powerup hit another vehicle
M.onTargetHit = function(data, origin_id, target_id)

end

-- When the powerup hit our vehicle. Aka another vehicle with this powerup shoots at our vehicle
-- We are target_id
M.onHit = function(data, origin_id, target_id)
	
end

-- When the powerup is destroyed. eg when the vehicle is deleted or the powerup ended
M.onDeactivate = function(data)
	
end

return M
