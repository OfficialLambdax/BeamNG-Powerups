local PowerUps = require("libs/PowerUps")
local Extender = require("libs/PowerUpsExtender")
local Util = require("libs/Util")
local Sets = require("libs/Sets")
local Trait = Extender.Traits

local M = {
	-- Clear name of the powerup
	clear_name = "Force Field II",
	
	-- If the camera is to far away from this powerups owner it will not render except this is true
	-- Will prevent whileActive calls
	do_not_unload = false,
	
	max_len = 14000,
	target_info_descriptor = nil,
	
	--[[
		eg. {Trait.Consuming, Trait.Reflective}
	]]
	traits = {Trait.Consuming},
	
	--[[
		eg. {Trait.Consuming, Trait.Reflective}
	]]
	respects_traits = {},
	
	-- This must match the power ups library _NAME or this powerup is rejected.
	-- This name is changed when the api changes, so to not load outdated powerups.
	lib_version = "mp_init",
	
	-- autofilled
	file_path = "",
	
	-- DO NOT treat this is a variable cache.
	-- These are merely definitions. Exceptions are constants.
	
	force_field_set = "force_field_" .. Util.randomName(),
	force_field_sound = "force_field_" .. Util.randomName(),
	force_field_hit_sound = "force_field_hit" .. Util.randomName(),
}


M.onInit = function(group_defs)
	Sets.loadSet(M.file_path .. "sets/forceField 2.lua", M.force_field_set)
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id)
	be:getObjectByID(game_vehicle_id):queueLuaCommand('PowerUpSounds.addSound("' .. M.force_field_sound .. '", "AudioSoft3D", 12, 1, "' .. M.file_path ..'sounds/force_field_normal.ogg")')
	
	be:getObjectByID(game_vehicle_id):queueLuaCommand('PowerUpSounds.addSound("' .. M.force_field_hit_sound .. '", "AudioSoft3D", 12, 1, "' .. M.file_path ..'sounds/shield_hit.ogg")')
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
	
	vehicle:queueLuaCommand('PowerUpSounds.playSound("' .. M.force_field_sound .. '")')

	return {timer = hptimer(), end_in = set:maxTime(), id = id}
end

-- only called once
M.onUnload = function(data)

end

-- only called once
M.onLoad = function(data)

end

-- While the powerup is active. Update its render here, detect if it hit something. that kinda stuff
M.whileActive = function(data)
	if data.timer:stop() < data.end_in then return end
	return 1
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
	be:getObjectByID(origin_id):queueLuaCommand('PowerUpSounds.playSound("' .. M.force_field_hit_sound .. '")')
end

return M
