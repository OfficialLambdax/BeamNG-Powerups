local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

local M = {
	-- Shown to the user
	clear_name = "Sniper I",
	
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
	max_len = 1000,
	
	-- TODO
	target_info_descriptor = nil,
	
	-- Configure traits this powerup respects. Required for trait call sync
	respects_traits = {Trait.Ignore, Trait.Ghosted},
	
	-- Auto filled
	-- Contains the dir path to this powerup
	file_path = "",
	
	-- Add extra variables here if needed. Constants only!
	reload_sound = nil,
	follow_sound = nil,
	fire_sounds = Pot(),
}

-- Called once when the powerup is loaded
M.onInit = function(group_defs)
	M.reload_sound = Sound(M.file_path .. 'sounds/sniper_reload_1.ogg', 3)
	--M.follow_sound = Sound(M.file_path .. 'sounds/bullet_flying2.ogg', 3)
	
	M.fire_sounds:add(Sound(M.file_path .. 'sounds/sniper_shot_1.ogg', 3), 1)
	M.fire_sounds:add(Sound(M.file_path .. 'sounds/sniper_shot_2.ogg', 3), 1)
	M.fire_sounds:add(Sound(M.file_path .. 'sounds/sniper_shot_3.ogg', 3), 1)
	M.fire_sounds:add(Sound(M.file_path .. 'sounds/sniper_shot_4.ogg', 3), 1)
	M.fire_sounds:add(Sound(M.file_path .. 'sounds/sniper_shot_5.ogg', 3), 1)
	M.fire_sounds:add(Sound(M.file_path .. 'sounds/sniper_shot_6.ogg', 3), 1)
	M.fire_sounds:add(Sound(M.file_path .. 'sounds/sniper_shot_7.ogg', 3), 1)
	M.fire_sounds:add(Sound(M.file_path .. 'sounds/sniper_shot_8.ogg', 3), 1)
	M.fire_sounds:add(Sound(M.file_path .. 'sounds/sniper_shot_9.ogg', 3), 1)
	
	M.fire_sounds:stir(5)
end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	return onActivate.Success({
			vehicle = vehicle,
			-- while selection
			possible_targets = {},
			selected_id = nil,
			is_valid_target = false,
			
			-- while shooting
			ammo = 5,
			is_reloading = false,
			charging_timer = Timer.new(),
			projectiles = {}, -- {[1..n] = {obj = markerObj, target_dir = vec3, life_timer = timer}]}
		}
	)
end

M[Hotkey.TargetChange] = function(data, origin_id, state)
	if state ~= HKeyState.Down then return end
	data.selected_id = Extender.targetChange(data.possible_targets, data.selected_id)
end

local function whileSelecting(data, origin_id, dt)
	local origin_vehicle = be:getObjectByID(origin_id)
	local veh_dir = origin_vehicle:getDirectionVector()
	local veh_pos = origin_vehicle:getPosition()
	local start_pos = MathUtil.getPosInFront(veh_pos, veh_dir, 2)
	
	local box_center = MathUtil.getPosInFront(veh_pos, veh_dir, 550)
	local box = MathUtil.createBox(box_center, veh_dir, 500, 40, 300)
	
	local targets = MathUtil.getVehiclesInsideBox(box, origin_id) or {}
	targets = Extender.cleanseTargetsWithTraits(targets, origin_id, Trait.Ignore)
	targets = Extender.cleanseTargetsBehindStatics(start_pos, targets)
	
	MathUtil.drawBox(box)
	
	data.possible_targets = targets
	
	if data.selected_id and Extender.isSpectating(origin_id) then
		local target_vehicle = be:getObjectByID(data.selected_id)
		if target_vehicle == nil then
			data.selected_id = nil
			return
		end
		
		data.is_valid_target = Util.tableContains(targets, data.selected_id)
		local color = ColorF(0,1,0,1)
		if not data.is_valid_target then
			color = ColorF(1,0,0,1)
		end
		
		local target_pos = target_vehicle:getSpawnWorldOOBB():getCenter()
		target_pos.z = target_pos.z + 2
		debugDrawer:drawSphere(target_pos, 1, color)
	end
end

M[Hotkey.Fire] = function(data, origin_id, state)
	if state ~= HKeyState.Down then return end
	
	if data.charging_timer:stop() < 2000 or data.ammo == 0 then
		return
	end
	
	data.charging_timer:stopAndReset()
	data.is_reloading = false
	data.ammo = data.ammo - 1
	
	local origin_vehicle = be:getObjectByID(origin_id)
	local origin_pos = origin_vehicle:getPosition()
	local target_dir = origin_vehicle:getDirectionVector()
	local start_pos = MathUtil.getPosInFront(origin_pos, target_dir, 2)
	
	if data.selected_id and data.is_valid_target then
		local target_vehicle = be:getObjectByID(data.selected_id)
		target_dir = target_vehicle:getPosition() - origin_pos
	end
	
	return onHKey.TargetInfo({
			target_dir = target_dir,
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
	
	local marker = createObject("TSStatic")
	marker.shapeName = "art/shapes/collectible/s_trashbag_collectible.cdae"
	marker.useInstanceRenderData = 1
	marker.instanceColor = Point4F(0, 0, 0, 1)
	marker:setPosRot(start_pos.x, start_pos.y, start_pos.z, 0, 0, 0, 1)
	marker.scale = vec3(0.1, 0.1, 0.1)
	
	marker:registerObject("my_powerup_" .. Util.randomName())
	projectile.obj = marker
	
	table.insert(data.projectiles, projectile)
	
	data.vehicle:queueLuaCommand('PowerUpExtender.pushForward(-1)')
	
	local blast_dir = quatFromDir(
		data.vehicle:getDirectionVectorUp(),
		data.target_dir
	)
	
	local sound = M.fire_sounds:surprise()
	if Extender.isSpectating(data.vehicle:getId()) then
		sound:play()
	else
		Sfx(sound:getFilePath(), data.vehicle:getPosition())
			:minDistance(50)
			:maxDistance(1000)
			:is3D(true)
			:volume(1)
			:selfDestruct(5000)
			:spawn()
	end
	
	Particle("BNGP_51", start_pos, blast_dir)
		:active(true)
		:followC(data.vehicle, nil, 
			function(self, obj, emitter)
				self:setPosition(MathUtil.getPosInFront(obj:getPosition(), obj:getDirectionVector(), 3))
				self:velocity(MathUtil.velocity(obj:getVelocity()) * 1.5)
			end
		)
		:selfDisable(math.random(200, 400))
		:selfDestruct(10000)
	
	Particle("BNGP_26", start_pos, blast_dir)
		:active(true)
		:velocity(-20)
		:bind(marker, 500)
		:follow(marker)
	
	
	Sfx(M.file_path .. 'sounds/bullet_flying2.ogg', data.start_pos)
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
		local new_pos = MathUtil.getPosInFront(proj_pos, projectile.target_dir, 800 * dt)
		projectile.obj:setPosition(new_pos)
		
		local try = MathUtil.getCollisionsAlongSideLine(proj_pos, new_pos, 3, origin_id)
		Extender.cleanseTargetsWithTraits(try, origin_id, Trait.Ghosted)
		
		if MathUtil.raycastAlongSideLine(proj_pos, new_pos) or projectile.life_time:stop() > 5000 then
			projectile.obj:delete()
			data.projectiles[index] = nil
			
		else
			if #try > 0 then
				Util.tableMerge(target_hits, try) -- this could create multiple hits on the same target. but ok. got hit by multiple bullets
				projectile.obj:delete()
				data.projectiles[index] = nil
			end
		end
	end
	
	if #target_hits > 0 then return target_hits end
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	if not data.is_reloading and data.charging_timer:stop() > 600 then
		data.is_reloading = true
		M.reload_sound:smart(origin_id)
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
	local target_vehicle = be:getObjectByID(target_id)
	target_vehicle:queueLuaCommand('beamstate.deflateRandomTire()')
end

-- When the powerup has ended or is destroyed by any means
M.onDeactivate = function(data, origin_id)
	if data.projectile then
		data.projectile.projectile:delete()
	end
end

-- When a target was hit, only called on players spectating origin_id
M.onTargetHit = function(data, origin_id, target_id) end

-- Render Distance related
M.onUnload = function(data) end

M.onLoad = function(data) end

return M
