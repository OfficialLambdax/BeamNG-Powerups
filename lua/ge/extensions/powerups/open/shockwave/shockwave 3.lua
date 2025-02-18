local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles = Extender.defaultPowerupVars()

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
	M.activate_sound = Sound(M.file_path .. 'sounds/shockwave_heavy.ogg', 20)
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id)
	
end

-- When the powerup is activated
M.onActivate = function(vehicle)
	local targets = {}
	local vehicle_id = vehicle:getId()
	for _, target in pairs(getAllVehicles()) do
		local target_id = target:getId()
		if vehicle_id ~= target_id then
			if Util.dist3d(vehicle:getPosition(), target:getPosition()) < M.effect_radius then
				if Extender.hasAnyTrait(target_id, Trait.StrongConsuming) then
					Extender.callTrait(target_id, Trait.Consuming, vehicle_id)
				else
					table.insert(targets, target_id)
				end
			end
		end
	end
	
	if #targets == 0 then targets = nil end
	
	local data = {
		no_target = targets == nil,
		targets = nil,
		sound_played = false
	}
	return onActivate.TargetInfo(data, targets)
end

-- only called once
M.onUnload = function(data)

end

-- only called once
M.onLoad = function(data)

end

-- While the powerup is active. Update its render here, detect if it hit something. that kinda stuff
M.whileActive = function(data, origin_id)
	-- no one was close enough to apply our powerup effect to
	if data.no_target then
		--if Extender.isPlayerVehicle(origin_id) then
			M.activate_sound:playVE(origin_id)
			return whileActive.Stop()
		--else
			--return nil
		--end
	end
	
	-- waiting for target confirmation
	if not data.targets then
		return whileActive.Continue()
		
	else -- we got targets!
		return whileActive.StopAfterExec(nil, data.targets)
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
	local origin_vehicle = be:getObjectByID(origin_id)
	local target_vehicle = be:getObjectByID(target_id)
	
	local vel1 = origin_vehicle:getVelocity()
	local vel2 = target_vehicle:getVelocity()
	
	local pos1 = origin_vehicle:getPosition()
	local pos2 = target_vehicle:getPosition()
	
	local push = (pos2 - pos1):normalized() * (math.min(M.effect_radius, M.effect_radius - Util.dist3d(pos2, pos1)) * 2)
	target_vehicle:applyClusterVelocityScaleAdd(target_vehicle:getRefNodeId(), 1, push.x, push.y, push.z)
	target_vehicle:queueLuaCommand("PowerUpExtender.addAngularVelocity(0, 0, 3, 0, 10, 0)")
	
	if not data.sound_played then
		M.activate_sound:playVE(origin_id)
		data.sound_played = true
	end
end

-- When the powerup is destroyed. eg when the vehicle is deleted or the powerup ended
M.onDeactivate = function(data)
	-- is better to let sets run out as left over trigger may not trigger otherwise.
	-- eg. you turn the screen black and have a trigger that unblacks it. But if you remove the set then also the unblack trigger. Aka screen stays black.
	--Sets.getSet("powerup_template"):revert(data.id)
end

return M
