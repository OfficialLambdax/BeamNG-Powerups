local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

local M = {
	-- Clear name of the powerup
	clear_name = "Cannon II",
	
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
	respects_traits = {Trait.Consuming, Trait.Breaking, Trait.Ghosted, Trait.Ignore},
	
	-- This must match the power ups library _NAME or this powerup is rejected.
	-- This name is changed when the api changes, so to not load outdated powerups.
	lib_version = "enums",
	
	-- autofilled
	file_path = "",
	
	-- DO NOT treat this is a variable cache.
	-- These are merely definitions
	
	activate_sound = nil,
	hit_sound = nil,
	
	max_projectiles = 5,
	shoot_downtime = 500,
	follow_sound = 'art/sounds/ext/cannon/cannonball_flying.ogg',
}



-- Anything you may want todo before anything is spawned. eg loading sounds in all vehicle vms
M.onInit = function(group_defs)
	M.activate_sound = Sound('art/sounds/ext/cannon/cannon_light.ogg', 3)
	M.hit_sound = Sound('art/sounds/ext/cannon/hit.ogg', 6)
	Extender.loadAssets('art/shapes/pwu/cannonball/materials.json')
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id)

end

-- When the powerup is activated
M.onActivate = function(vehicle)
	return onActivate.Success({projectiles = {}, shoot_timer = hptimer(), shot_projectiles = 0, vehicle = vehicle})
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
		local veh_dir = origin_vehicle:getDirectionVector()
		veh_dir.z = veh_dir.z + 0.01
		
		local veh_pos = origin_vehicle:getPosition()
		veh_pos.z = veh_pos.z + 0.5
		
		local start_pos = MathUtil.getPosInFront(veh_pos, veh_dir, 2)
		
		local veh_id = origin_vehicle:getId()
		local cone = MathUtil.createCone(start_pos, veh_dir, 300, 200)
		local targets = MathUtil.getVehiclesInsideCone(cone, origin_id)
		targets = Extender.cleanseTargetsWithTraits(targets, origin_id, Trait.Ignore)
		targets = Extender.cleanseTargetsBehindStatics(start_pos, targets)
		local projectile_speed = MathUtil.velocity(origin_vehicle:getVelocity()) + 100
		
		local target_dir = veh_dir
		local _, target_id = Util.tablePickRandom(targets)
		if target_id then
			local target_vehicle = be:getObjectByID(target_id)
			local pos1 = origin_vehicle:getPosition()
			local pos2 = MathUtil.getPredictedPosition(origin_vehicle, target_vehicle, projectile_speed)
			
			target_dir = pos2 - pos1
		end
		
		local target_info = {
			target_dir = target_dir,
			start_pos = start_pos,
			init_vel = projectile_speed
		}
		
		data.shoot_timer:stopAndReset()
		
		M.activate_sound:smartSFX(origin_id)
		
		origin_vehicle:queueLuaCommand('PowerUpExtender.pushForward(-5)')
		
		-- need to return now as we cant give target_info and target_hits back at once
		return whileActive.Continue(target_info)
	end
	
	local target_hits = {}
	for index, projectile in pairs(data.projectiles) do
		local proj_pos = projectile.projectile:getPosition()
		local new_pos = MathUtil.getPosInFront(proj_pos, projectile.target_dir, projectile.init_vel * dt)
		
		projectile.projectile:setPosRot(new_pos.x, new_pos.y, new_pos.z, 0, 0, 0, 0)
		
		local try = MathUtil.getCollisionsAlongSideLine(proj_pos, new_pos, 3, origin_id)
		local try = Extender.cleanseTargetsWithTraits(try, origin_id, Trait.Ghosted)
		local try = Extender.cleanseTargetsBehindStatics(proj_pos, try)
			
		if MathUtil.raycastAlongSideLine(proj_pos, new_pos) or #try > 0 then
			projectile.projectile:delete()
			data.projectiles[index] = nil
			
			if #try > 0 then
				Util.tableArrayMerge(target_hits, try)
			end
		elseif projectile.life_time:stop() > 2500 then
			projectile.projectile:delete()
			data.projectiles[index] = nil
		end
	end
	
	if #target_hits > 0 then
		return whileActive.TargetHits(target_hits)
	else
		if Util.tableHasContent(data.projectiles) then
			return whileActive.Continue()
		elseif data.shot_projectiles == M.max_projectiles then
			return whileActive.Stop()
		end
	end
end

-- Called once one or multiple targets have been chosen.
-- In a singleplayer scenario this event is called directly.
-- In a multiplayer scenario once the server confirms the targets.
M.onTargetSelect = function(data, target_info)
	target_info.life_time = hptimer()
	target_info.target_dir = vec3(target_info.target_dir)
	
	-- spawn projectile
	local marker = createObject("TSStatic")
	marker.shapeName = "art/shapes/pwu/cannonball/cannonball.cdae"
	marker.useInstanceRenderData = 1
	marker.instanceColor = Point4F(0, 0, 0, 1)
	marker:setPosRot(target_info.start_pos.x, target_info.start_pos.y, target_info.start_pos.z, 0, 0, 0, 1)
	marker.scale = vec3(2.5, 2.5, 2.5)
	
	local test = "my_powerup_" .. Util.randomName()
	marker:registerObject(test)
	
	local blast_dir = quatFromDir(
		data.vehicle:getDirectionVectorUp(),
		target_info.target_dir
	)
	
	Particle("BNGP_51", data.start_pos, blast_dir)
		:active(true)
		:followC(data.vehicle, nil, 
			function(self, obj, emitter)
				self:setPosition(MathUtil.getPosInFront(obj:getPosition(), obj:getDirectionVector(), 3))
				self:velocity(MathUtil.velocity(obj:getVelocity()) * 1.5)
			end
		)
		:selfDisable(math.random(200, 400))
		:selfDestruct(10000)
	
	local life_time = math.random(500, 1000)
	Particle("BNGP_26", data.start_pos, blast_dir)
		:active(true)
		:velocity(-5)
		:follow(marker, life_time)
		:bind(marker, 500)
		:selfDisable(life_time)
		:selfDestruct(life_time + 500)
	
	Sfx(M.follow_sound, target_info.start_pos)
		:is3D(true)
		:volume(1)
		:minDistance(30)
		:maxDistance(100)
		:isLooping(true)
		:follow(marker)
		:bind(marker)
		:spawn()
	
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
	if Extender.hasTraitCalls(target_id, origin_id, Trait.Consuming, Trait.Breaking) then return end

	local origin_vehicle = be:getObjectByID(origin_id)
	local target_vehicle = be:getObjectByID(target_id)
	
	local origin_pos = origin_vehicle:getPosition()
	local target_pos = target_vehicle:getPosition()
	local push = (target_pos - origin_pos):normalized() * 15
	target_vehicle:applyClusterVelocityScaleAdd(target_vehicle:getRefNodeId(), 1, push.x, push.y, push.z)
	
	local spin = target_vehicle:getDirectionVectorUp():normalized() * 5
	target_vehicle:queueLuaCommand(string.format("PowerUpExtender.addAngularVelocity(0, 0, 0, %d, %d, %d)", spin.x, spin.y, spin.z))
	
	M.hit_sound:playVE(target_id)
end

-- When the powerup is destroyed. eg when the vehicle is deleted or the powerup ended
M.onDeactivate = function(data)
	for _, projectile in pairs(data.projectiles) do
		projectile.projectile:delete()
	end
end

return M
