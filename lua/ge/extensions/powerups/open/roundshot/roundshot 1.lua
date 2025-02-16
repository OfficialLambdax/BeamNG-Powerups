local PowerUps = require("libs/PowerUps")
local Extender = require("libs/PowerUpsExtender")
local Util = require("libs/Util")
local MathUtil = require("libs/MathUtil")
local Sets = require("libs/Sets")
local Trait = Extender.Traits
local Sound = require("libs/Sounds")

local M = {
	-- Clear name of the powerup
	clear_name = "Roundshot I",
	
	-- If the camera is to far away from this powerups owner it will not render except this is true
	-- Will prevent whileActive calls
	do_not_unload = false,
	
	max_len = 5000,
	target_info_descriptor = nil,
	
	--[[
		eg. {Trait.Consuming, Trait.Reflective}
	]]
	traits = {},
	
	--[[
		eg. {Trait.Consuming, Trait.Reflective}
	]]
	respects_traits = {Trait.Consuming, Trait.Ghosted},
	
	-- This must match the power ups library _NAME or this powerup is rejected.
	-- This name is changed when the api changes, so to not load outdated powerups.
	lib_version = "mp_init",
	
	-- autofilled
	file_path = "",
	
	-- DO NOT treat this is a variable cache.
	-- These are merely definitions
	
	activate_sound = nil,
	hit_sound = nil,
	
	max_projectiles = 28,
	shoot_downtime = 125,
}



-- Anything you may want todo before anything is spawned. eg loading sounds in all vehicle vms
M.onInit = function(group_defs)
	M.activate_sound = Sound(M.file_path .. 'sounds/roundshot_1_double.ogg', 3)
	M.hit_sound = Sound(M.file_path .. 'sounds/energy_bullet_hit.ogg', 3)
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id)
	
end

-- When the powerup is activated
M.onActivate = function(vehicle)
	M.activate_sound:playVE(vehicle:getId())
	return {
		projectiles = {},
		shoot_timer = hptimer(),
		shot_projectiles = 0,
		degrees = 0
	}
end

-- only called once
M.onUnload = function(data)

end

-- only called once
M.onLoad = function(data)

end

-- While the powerup is active. Update its render here, detect if it hit something. that kinda stuff
M.whileActive = function(data, origin_id, dt)
	if data.shot_projectiles < M.max_projectiles and #data.projectiles < M.max_projectiles and data.shoot_timer:stop() > M.shoot_downtime then
		local origin_vehicle = be:getObjectByID(origin_id)
		
		local up_dir = origin_vehicle:getDirectionVectorUp()
		local for_dir = origin_vehicle:getDirectionVector()
		local next_dir = MathUtil.rotateVectorByDegrees(for_dir, up_dir, data.degrees)
		data.degrees = data.degrees + 0.465
		data.shoot_timer:stopAndReset()
		
		local pos = origin_vehicle:getPosition()
		pos.z = pos.z + 0.5
		local target_info = {
			target_dir = next_dir,
			start_pos = MathUtil.getPosInFront(pos, next_dir, 3),
			init_vel = MathUtil.velocity(origin_vehicle:getVelocity())
		}
		
		return nil, target_info
	end
	
	local target_hits = {}
	for index, projectile in pairs(data.projectiles) do
		local proj_pos = projectile.projectile:getPosition()
		local new_pos = MathUtil.getPosInFront(proj_pos, projectile.target_dir, (100 + projectile.init_vel) * dt)
		
		projectile.projectile:setPosRot(new_pos.x, new_pos.y, new_pos.z, 0, 0, 0, 0)
		
		-- check collision
		local new_hit = MathUtil.getCollisionsAlongSideLine(proj_pos, new_pos, 3, origin_id)
		Extender.cleanseTargetsWithTraits(new_hit, origin_id, Trait.Ghosted)
		if #new_hit > 0 then
			Util.tableArrayMerge(target_hits, new_hit)
			projectile.projectile:delete()
			data.projectiles[index] = nil
		
		elseif projectile.life_time:stop() > 2500 then
			projectile.projectile:delete()
			data.projectiles[index] = nil
		end
	end
	
	-- return new hits
	if #target_hits > 0 then return 3, nil, target_hits end
	
	if Util.tableHasContent(data.projectiles) then return end
	if data.shot_projectiles == M.max_projectiles then return 1 end
end

-- Called once one or multiple targets have been chosen.
-- In a singleplayer scenario this event is called directly.
-- In a multiplayer scenario once the server confirms the targets.
M.onTargetSelect = function(data, target_info)
	target_info.life_time = hptimer()
	target_info.target_dir = vec3(target_info.target_dir)
	
	-- spawn projectile
	local marker = createObject("TSStatic")
	marker.shapeName = "art/shapes/collectible/s_trashbag_collectible.cdae"
	marker.useInstanceRenderData = 1
	marker.instanceColor = Point4F(0, 0, 0, 0)
	marker:setPosRot(target_info.start_pos.x, target_info.start_pos.y, target_info.start_pos.z, 0, 0, 0, 1)
	marker.scale = vec3(0.25, 0.25, 0.25)
	
	local test = "my_powerup_" .. Util.randomName()
	marker:registerObject(test)
	
	target_info.projectile = marker
	table.insert(data.projectiles, target_info)
	
	data.shot_projectiles = data.shot_projectiles + 1	
end

-- When the powerup hit another vehicle
M.onTargetHit = function(data, origin_id, target_id)
	-- everything in here is only executed on our end
end

-- When the powerup hit our vehicle. Aka another vehicle with this powerup shoots at our vehicle
-- We are target_id
M.onHit = function(data, origin_id, target_id)
	-- everything in here is executed on our and the remote end
	local target_vehicle = be:getObjectByID(target_id)
	M.hit_sound:playVE(target_id)
	if Extender.hasTraitCalls(target_id, origin_id, Trait.Consuming) then return end

	local origin_vehicle = be:getObjectByID(origin_id)
	local position = target_vehicle:getPosition()
	
	local origin_pos = origin_vehicle:getPosition()
	local target_pos = target_vehicle:getPosition()
	
	local push = (target_pos - origin_pos):normalized() * 8
	target_vehicle:applyClusterVelocityScaleAdd(target_vehicle:getRefNodeId(), 1, push.x, push.y, push.z)
	target_vehicle:queueLuaCommand("PowerUpExtender.addAngularVelocity(0, 0, 1, 0, 0.5, 0)")
end

-- When the powerup is destroyed. eg when the vehicle is deleted or the powerup ended
M.onDeactivate = function(data)
	for _, projectile in pairs(data.projectiles) do
		projectile.projectile:delete()
	end
end

return M
