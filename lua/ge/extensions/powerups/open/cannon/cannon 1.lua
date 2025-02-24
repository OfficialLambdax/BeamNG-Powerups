local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject = Extender.defaultPowerupVars()

local M = {
	-- Clear name of the powerup
	clear_name = "Cannon I",
	
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
	respects_traits = {Trait.Consuming, Trait.Breaking, Trait.Ghosted},
	
	-- This must match the power ups library _NAME or this powerup is rejected.
	-- This name is changed when the api changes, so to not load outdated powerups.
	lib_version = "enums",
	
	-- autofilled
	file_path = "",
	
	-- DO NOT treat this is a variable cache.
	-- These are merely definitions
	
	activate_sound = nil,
	hit_sound = nil,
	follow_sound = 'sounds/cannonball_flying.ogg',
}



-- Anything you may want todo before anything is spawned. eg loading sounds in all vehicle vms
M.onInit = function(group_defs)
	M.activate_sound = Sound(M.file_path .. 'sounds/cannon_light.ogg', 3)
	M.hit_sound = Sound(M.file_path .. 'sounds/hit.ogg', 6)
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id)

end

-- When the powerup is activated
M.onActivate = function(vehicle)
	local veh_dir = vehicle:getDirectionVector()
	veh_dir.z = veh_dir.z + 0.01
	
	local veh_pos = vehicle:getPosition()
	veh_pos.z = veh_pos.z + 0.5
	
	local veh_id = vehicle:getId()
	local box_center = MathUtil.getPosInFront(veh_pos, veh_dir, 70)
	local box = MathUtil.createBox(box_center, veh_dir, 60, 30, 40)
	local targets = MathUtil.getVehiclesInsideBox(box, veh_id) or {}
	
	local target_dir = veh_dir
	local _, target_id = Util.tablePickRandom(targets)
	if target_id then
		local target_vehicle = be:getObjectByID(target_id)
		local pos1 = vehicle:getPosition()
		local pos2 = target_vehicle:getPosition()
		
		target_dir = pos2 - pos1
	end
	
	local data = {
		target_dir = nil,
		start_pos = nil,
		projectile = nil,
		life_time = nil,
		init_vel = nil
	}
	
	local target_info = {
		target_dir = target_dir,
		start_pos = MathUtil.getPosInFront(veh_pos, veh_dir, 3),
		init_vel = MathUtil.velocity(vehicle:getVelocity())
	}
	
	M.activate_sound:smartSFX(vehicle:getId())
	
	vehicle:queueLuaCommand('PowerUpExtender.pushForward(-5)')
	
	return onActivate.TargetInfo(data, target_info)
end

-- only called once
M.onUnload = function(data)

end

-- only called once
M.onLoad = function(data)

end

-- While the powerup is active. Update its render here, detect if it hit something. that kinda stuff
M.whileActive = function(data, origin_id, dt)
	if not data.target_dir then return nil end
	
	local proj_pos = data.projectile:getPosition()
	local new_pos = MathUtil.getPosInFront(proj_pos, data.target_dir, (100 + data.init_vel) * dt)
	
	data.projectile:setPosRot(new_pos.x, new_pos.y, new_pos.z, 0, 0, 0, 0)
	
	-- check collision
	local target_hits = MathUtil.getCollisionsAlongSideLine(proj_pos, new_pos, 3, origin_id)
	Extender.cleanseTargetsWithTraits(target_hits, origin_id, Trait.Ghosted)
	
	if #target_hits > 0 then
		return whileActive.StopAfterExec(nil, target_hits)
	elseif data.life_time:stop() > 2500 then
		return whileActive.Stop()
	else
		return whileActive.Continue()
	end
end

-- Called once one or multiple targets have been chosen.
-- In a singleplayer scenario this event is called directly.
-- In a multiplayer scenario once the server confirms the targets.
M.onTargetSelect = function(data, target_info)
	Util.tableMerge(data, target_info)
	data.target_dir = vec3(data.target_dir)
	data.life_time = hptimer()
	
	-- spawn projectile
	local marker = createObject("TSStatic")
	marker.shapeName = "art/shapes/collectible/s_trashbag_collectible.cdae"
	marker.useInstanceRenderData = 1
	marker.instanceColor = Point4F(0, 0, 0, 0)
	marker:setPosRot(data.start_pos.x, data.start_pos.y, data.start_pos.z, 0, 0, 0, 1)
	marker.scale = vec3(1, 1, 1)
	
	local test = "my_powerup_" .. Util.randomName()
	marker:registerObject(test)
	
	Particle("BNGP_51", data.start_pos)
		:active(true)
		:selfDisable(math.random(100, 300))
		:selfDestruct(10000)
	
	Particle("BNGP_51", data.start_pos)
		:active(true)
		:follow(marker, 100)
		:selfDisable(80)
		:selfDestruct(10000)
	
	local life_time = math.random(500, 1000)
	Particle("BNGP_26", data.start_pos)
		:active(true)
		:velocity(0)
		:follow(marker, life_time)
		:bind(marker, 500)
		:selfDisable(life_time)
		:selfDestruct(life_time + 500)
	
	Sfx(M.file_path .. M.follow_sound, data.start_pos)
		:is3D(true)
		:volume(1)
		:minDistance(30)
		:maxDistance(100)
		:isLooping(true)
		:follow(marker)
		:bind(marker)
		:spawn()
	
	data.projectile = marker
end

-- When the powerup hit another vehicle
M.onTargetHit = function(data, origin_id, target_id)
	-- everything in here is only executed on our end
end

-- When the powerup hit our vehicle. Aka another vehicle with this powerup shoots at our vehicle
-- We are target_id
M.onHit = function(data, origin_id, target_id)
	-- everything in here is executed on our and the remote end
	if Extender.hasTraitCalls(target_id, origin_id, Trait.Consuming, Trait.Breaking) then return end

	local origin_vehicle = be:getObjectByID(origin_id)
	local target_vehicle = be:getObjectByID(target_id)
	
	local origin_pos = origin_vehicle:getPosition()
	local target_pos = target_vehicle:getPosition()
	
	local push = (target_pos - origin_pos):normalized() * 12
	target_vehicle:applyClusterVelocityScaleAdd(target_vehicle:getRefNodeId(), 1, push.x, push.y, push.z)
	
	local spin = target_vehicle:getDirectionVectorUp():normalized() * 5
	target_vehicle:queueLuaCommand(string.format("PowerUpExtender.addAngularVelocity(0, 0, 0, %d, %d, %d)", spin.x, spin.y, spin.z))
	
	M.hit_sound:playVE(target_id)
end

-- When the powerup is destroyed. eg when the vehicle is deleted or the powerup ended
M.onDeactivate = function(data)
	-- is better to let sets run out as left over trigger may not trigger otherwise.
	-- eg. you turn the screen black and have a trigger that unblacks it. But if you remove the set then also the unblack trigger. Aka screen stays black.
	--Sets.getSet("powerup_template"):revert(data.id)
	
	if data.projectile then
		data.projectile:delete()
	end
end

return M
