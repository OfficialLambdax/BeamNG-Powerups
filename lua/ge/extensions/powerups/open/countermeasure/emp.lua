local PowerUps = require("libs/PowerUps")
local Extender = require("libs/PowerUpsExtender")
local Util = require("libs/Util")
local Sets = require("libs/Sets")
local Trait = Extender.Traits
local Sound = require("libs/Sounds")

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
	lib_version = "mp_init",
	
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
	M.activate_sound = Sound(M.file_path .. 'sounds/electrical_shock_zap.ogg', 3)
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id)
	
end

-- When the powerup is activated
M.onActivate = function(vehicle)
	local targets = {}
	local vehicle_id = vehicle:getId()
	for _, target in ipairs(getAllVehicles()) do
		local target_id = target:getId()
		if vehicle_id ~= target_id then
			if Util.dist3d(vehicle:getPosition(), target:getPosition()) < M.effect_radius then
				table.insert(targets, target_id)
			end
		end
	end
	
	M.activate_sound:playVE(vehicle:getId())
	
	if #targets == 0 then targets = nil end
	
	local data = {
		no_target = targets == nil,
		targets = nil,
		sound_played = false
	}
	return data, targets
end

-- only called once
M.onUnload = function(data)

end

-- only called once
M.onLoad = function(data)

end

-- While the powerup is active. Update its render here, detect if it hit something. that kinda stuff
M.whileActive = function(data, origin_id)
	if data.no_target then return 1 end

	-- waiting for target confirmation
	if not data.targets then
		return nil
		
	else -- we got targets!
		return 2, nil, data.targets
	end
end

-- Called once one or multiple targets have been chosen.
-- In a singleplayer scenario this event is called directly.
-- In a multiplayer scenario once the server confirms the targets.
M.onTargetSelect = function(data, targets)
	data.targets = targets
end

-- When the powerup hit another vehicle
M.onTargetHit = function(data, origin_id, target_id)
	-- everything in here is only executed on our end
end

-- When the powerup hit our vehicle. Aka another vehicle with this powerup shoots at our vehicle
-- We are target_id
M.onHit = function(data, origin_id, target_id)
	-- everything in here is executed on our and the remote end
	-- push vehicle away from us
	local set = Sets.getSet(M.set_name):VETarget(target_id)
	if Extender.isPlayerVehicle(target_id) then set:resetBlock() end
	set:exec()
end

-- When the powerup is destroyed. eg when the vehicle is deleted or the powerup ended
M.onDeactivate = function(data)
	
end

return M
