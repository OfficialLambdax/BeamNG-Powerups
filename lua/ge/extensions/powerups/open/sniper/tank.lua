local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

local M = {
	-- Shown to the user
	clear_name = "Tank",
	
	-- Turn true to not be affected by the render distance
	do_not_unload = true,
	
	-- Configure traits of this powerup
	-- {Trait.Consuming, Trait.Reflective}
	traits = {},
	
	-- Must match the libs version name. If it doesnt, this powerup group is considered out of date
	-- dump(Lib.getLibVersion())
	lib_version = "enums",
	
	-- Server related below
	
	-- Define the maximum length this powerup is active. The server will end it after this time.
	max_len = 60000,
	
	-- TODO
	target_info_descriptor = nil,
	
	-- Configure traits this powerup respects. Required for trait call sync
	respects_traits = {Trait.Ignore, Trait.Ghosted, Trait.Consuming},
	
	-- Auto filled
	-- Contains the dir path to this powerup
	file_path = "",
	
	-- Add extra variables here if needed. Constants only!
	max_ammo = 3,
	aim_time = 8000,
	aim_range = 1500,
	aim_angle = 500,
	min_precision_error = 0.2,
	projectile_speed = 600,
	projectile_life_time = 3000,
	reload_sound = nil,
	follow_sound = nil,
	ontarget_hit_sound = nil,
	fire_sounds = Pot(),
}

-- Called once when the powerup is loaded
M.onInit = function(group_defs)
	M.reload_sound = Sound('art/sounds/ext/sniper/tank_reload.ogg', 3)
	M.ontarget_hit_sound = Sound('art/sounds/ext/sniper/hit_sound.ogg', 15)
	
	M.fire_sounds:add(Sound('art/sounds/ext/sniper/tank_shot_2.ogg', 3), 1)
	
	M.fire_sounds:stir(5)
end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	return onActivate.Success({
			vehicle = vehicle,
			stand_still_timer = Timer.new(),
			
			-- while selection
			possible_targets = {},
			selected_id = nil,
			is_valid_target = false,
			
			-- while shooting
			ammo = M.max_ammo,
			is_reloading = false,
			charging_timer = Timer.new(),
			projectiles = {}, -- {[1..n] = {obj = markerObj, target_dir = vec3, life_time = timer}]}
		}
	)
end

M[Hotkey.Cancel] = function(data, origin_id, state)
	if state ~= HKeyState.Down then return end
	return onHKey.Stop()
end

M[Hotkey.TargetChange] = function(data, origin_id, state)
	if state ~= HKeyState.Down then return end
	data.selected_id = Extender.targetChange(data.possible_targets, data.selected_id)
	data.stand_still_timer:stopAndReset()
end

local function whileSelecting(data, origin_id, dt)
	local origin_vehicle = be:getObjectByID(origin_id)
	local veh_dir = origin_vehicle:getDirectionVector()
	local veh_pos = origin_vehicle:getSpawnWorldOOBB():getCenter()
	local start_pos = MathUtil.getPosInFront(veh_pos, veh_dir, 2)
	
	local cone = MathUtil.createCone(start_pos, veh_dir, M.aim_range, M.aim_angle)
	local targets = MathUtil.getVehiclesInsideCone(cone, origin_id)
	targets = Extender.cleanseTargetsWithTraits(targets, origin_id, Trait.Ignore)
	targets = Extender.cleanseTargetsBehindStatics(start_pos, targets)
	
	data.possible_targets = targets
	
	if Extender.isSpectating(origin_id) then
		if data.selected_id then
			local target_vehicle = be:getObjectByID(data.selected_id)
			if target_vehicle == nil then
				data.selected_id = nil
				return
			end
			
			data.is_valid_target = Util.tableContains(targets, data.selected_id)
			local color = ColorF(0,1,0,1)
			if not data.is_valid_target then
				color = ColorF(1,0,0,1)
				
				MathUtil.drawConeLikeTarget(cone)
			else
				local stand_still_time = data.stand_still_timer:stop()
				local scope = 90 - math.min((stand_still_time / M.aim_time) * 80, 80)
				
				local target_pos = MathUtil.getPredictedPosition(origin_vehicle, target_vehicle, M.projectile_speed)
				local target_dir = target_pos - veh_pos
				local dist = Util.dist3d(target_pos, veh_pos)
				local cone = MathUtil.createCone(start_pos, target_dir, dist, scope)
				MathUtil.drawConeLikeTarget(cone)
			end
		else
			MathUtil.drawConeLikeTarget(cone)
		end
	end
end

M[Hotkey.Fire] = function(data, origin_id, state)
	if state ~= HKeyState.Down then return end
	
	local origin_vehicle = be:getObjectByID(origin_id)
	if data.charging_timer:stop() < 3000 or data.ammo == 0 or data.stand_still_timer:stop() < 1000 then
		return
	end
	
	local origin_pos = origin_vehicle:getSpawnWorldOOBB():getCenter()
	local target_dir = origin_vehicle:getDirectionVector()
	target_dir.z = target_dir.z + 0.01
	local start_pos = MathUtil.getPosInFront(origin_pos, target_dir, 2)
	
	if data.selected_id and data.is_valid_target then
		local target_vehicle = be:getObjectByID(data.selected_id)
		target_dir = MathUtil.getPredictedPosition(origin_vehicle, target_vehicle, M.projectile_speed) - origin_pos
	end
	
	local stand_still_time = data.stand_still_timer:stop()
	local scope = 3 - math.min((stand_still_time / M.aim_time) * 3, 3)
	scope = scope + M.min_precision_error
	
	data.charging_timer:stopAndReset()
	data.stand_still_timer:stopAndReset()
	data.is_reloading = false
	data.ammo = data.ammo - 1
	
	return onHKey.TargetInfo({
			target_dir = MathUtil.disperseVec(target_dir:normalized(), scope),
			start_pos = start_pos
		}
	)
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info)
	local projectile = {
		target_dir = vec3(target_info.target_dir),
		life_time = Timer.new(),
		obj = nil
	}
	
	local start_pos = target_info.start_pos
	local marker = Extender.fakeProjectile(vec3(start_pos.x, start_pos.y, start_pos.z), 0.1)
	projectile.obj = marker
	
	table.insert(data.projectiles, projectile)
	
	data.vehicle:queueLuaCommand('PowerUpExtender.pushForward(-5)')
	data.vehicle:queueLuaCommand('PowerUpExtender.jump(1.5)')
	
	local blast_dir = quatFromDir(
		data.vehicle:getDirectionVectorUp(),
		projectile.target_dir
	)
	
	local left_blast_dir = quatFromDir(
		data.vehicle:getDirectionVectorUp(),
		projectile.target_dir:cross(data.vehicle:getDirectionVector())
	)
	
	local right_blast_dir = quatFromDir(
		data.vehicle:getDirectionVectorUp(),
		projectile.target_dir:cross(-data.vehicle:getDirectionVector())
	)
	
	M.fire_sounds:surprise():smartSFX2(data.vehicle:getId(), nil, 10000, 50, M.aim_range + 200)
	
	-- forward
	Particle("BNGP_22", start_pos, blast_dir)
		:active(true)
		:velocity(20)
		:selfDisable(500)
		:selfDestruct(3000)
	
	-- sideways
	Particle("BNGP_22", start_pos, left_blast_dir)
		:active(true)
		:velocity(10)
		:selfDisable(250)
		:selfDestruct(3000)
	Particle("BNGP_22", start_pos, right_blast_dir)
		:active(true)
		:velocity(10)
		:selfDisable(250)
		:selfDestruct(3000)
	
	Particle("BNGP_20", vec3(start_pos.x, start_pos.y, start_pos.z - 0.3))
		:active(true)
		:velocity(5)
		:selfDisable(300)
		:selfDestruct(2000)
	
	-- tracer
	Particle("BNGP_29", start_pos, blast_dir)
		:active(true)
		:velocity(-20)
		:bind(marker, 500)
		:follow(marker)
	
	Sfx('art/sounds/ext/sniper/bullet_flying2.ogg', data.start_pos)
		:is3D(true)
		:volume(1)
		:minDistance(30)
		:maxDistance(100)
		:isLooping(true)
		:follow(marker)
		:bind(marker)
		:spawn()
end

local function whileFiring(data, origin_id, dt)
	local target_hits = {}
	for index, projectile in pairs(data.projectiles) do
		local proj_pos = projectile.obj:getPosition()
		local new_pos = MathUtil.getPosInFront(proj_pos, projectile.target_dir, M.projectile_speed * dt)
		projectile.obj:setPosition(new_pos)
		
		local try = MathUtil.getCollisionsAlongSideLine(proj_pos, new_pos, 3, origin_id)
		local try = Extender.cleanseTargetsWithTraits(try, origin_id, Trait.Ghosted)
		local try = Extender.cleanseTargetsBehindStatics(proj_pos, try)
		
		if MathUtil.raycastAlongSideLine(proj_pos, new_pos) or #try > 0 then
			projectile.obj:delete()
			data.projectiles[index] = nil
			
			if #try > 0 then
				Util.tableMerge(target_hits, try)
			end
		elseif projectile.life_time:stop() > M.projectile_life_time then
			projectile.obj:delete()
			data.projectiles[index] = nil
			
		end
	end
	
	if #target_hits > 0 then return target_hits end
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	if not data.is_reloading and data.ammo > 0 and data.charging_timer:stop() > 600 then
		data.is_reloading = true
		M.reload_sound:smart(origin_id)
	end
	
	local origin_vehicle = be:getObjectByID(origin_id)
	if MathUtil.velocity(origin_vehicle:getVelocity()) > 3 then
		data.stand_still_timer:stopAndReset()
	end
	
	whileSelecting(data, origin_id, dt)
	local target_hits = whileFiring(data, origin_id, dt)
	if target_hits then
		return whileActive.TargetHits(target_hits)
	end
	
	if not Util.tableHasContent(data.projectiles) and data.ammo == 0 then
		return whileActive.Stop()
	end
	
	return whileActive.Continue()
end


-- When a target was hit, called on every client
M.onHit = function(data, origin_id, target_id)
	if Extender.hasTraitCalls(target_id, origin_id, Trait.Consuming) then return end
	local origin_vehicle = be:getObjectByID(origin_id)
	local target_vehicle = be:getObjectByID(target_id)
	local exec = [[
		fire.explodeVehicle()
		fire.igniteVehicle()
		beamstate.breakAllBreakgroups()
	]]
	
	local push = (target_vehicle:getPosition() - origin_vehicle:getPosition()):normalized() * 12
	
	target_vehicle:queueLuaCommand(exec)
	target_vehicle:applyClusterVelocityScaleAdd(target_vehicle:getRefNodeId(), 1, push.x, push.y, push.z)
end

-- When the powerup has ended or is destroyed by any means
M.onDeactivate = function(data, origin_id)
	for _, projectile in pairs(data.projectiles) do
		projectile.obj:delete()
	end
end

-- When a target was hit, only called on players spectating origin_id
M.onTargetHit = function(data, origin_id, target_id)
	M.ontarget_hit_sound:play()
end

-- Render Distance related
M.onUnload = function(data) end

M.onLoad = function(data) end

return M
