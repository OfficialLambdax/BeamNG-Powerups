local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable, Ui = Extender.defaultImports(1)
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

local M = {
	-- Shown to the user
	clear_name = "Barrier",
	
	-- Turn true to not be affected by the render distance
	do_not_unload = false,
	
	-- Configure traits of this powerup
	-- {Trait.Consuming, Trait.Reflective}
	traits = {},
	
	-- Must match the libs version name. If it doesnt, this powerup group is considered out of date
	-- dump(Lib.getLibVersion())
	lib_version = "enums",
	
	-- Server related below
	
	-- Define the maximum length this powerup is active. The server will end it after this time.
	max_len = 30000,
	
	-- TODO
	target_info_descriptor = nil,
	
	-- Configure traits this powerup respects. Required for trait call sync
	respects_traits = {},
	
	-- Auto filled
	-- Contains the dir path to this powerup
	file_path = "",
	
	-- Add extra variables here if needed. Constants only!
	hit_sounds = Pot()
		:add(Sound('art/sounds/ext/defenses/car_hitting_1.ogg', 3), 1)
		:add(Sound('art/sounds/ext/defenses/car_hitting_2.ogg', 3), 1)
		:add(Sound('art/sounds/ext/defenses/hit_1.ogg', 3), 1)
		:add(Sound('art/sounds/ext/defenses/hit_2.ogg', 3), 1)
		:add(Sound('art/sounds/ext/defenses/hit_3.ogg', 3), 1)
		:add(Sound('art/sounds/ext/defenses/hit_4.ogg', 3), 1)
		:add(Sound('art/sounds/ext/defenses/hit_5.ogg', 3), 1)
		:add(Sound('art/sounds/ext/defenses/hit_6.ogg', 3), 1)
		:add(Sound('art/sounds/ext/defenses/hit_7.ogg', 3), 1)
		:add(Sound('art/sounds/ext/defenses/hit_8.ogg', 3), 1)
		:stir(5),
	
	build_sounds = Pot()
		:add('art/sounds/ext/defenses/dirt_digging_1.ogg', 1)
		:add('art/sounds/ext/defenses/dirt_digging_2.ogg', 1)
		:add('art/sounds/ext/defenses/dirt_digging_3.ogg', 1)
		:add('art/sounds/ext/defenses/dirt_digging_4.ogg', 1)
		:stir(5),
}

-- Called once when the powerup is loaded
M.onInit = function(group_defs)
	Extender.loadAssets('art/shapes/pwu/bollard/materials.json')
end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	return onActivate.Success({
		placing = nil,
		build_index = 0,
		building = false,
		build_timer = Timer.new(),
		shared = {}
	})
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	local vehicle = be:getObjectByID(origin_id)
	if data.placing == nil then 
		if MathUtil.velocity(vehicle:getVelocity()) > 1 then
			Ui.target(origin_id).Toast.info('Must stand still', nil, 1000)
			return whileActive.Continue()
		end
		
		local veh_dir = vehicle:getDirectionVector()
		local pos_behind = MathUtil.getPosInFront(vehicle:getSpawnWorldOOBB():getCenter(), veh_dir, -4)
		
		local side_dir = veh_dir:cross(vehicle:getDirectionVectorUp())
		
		local placing = {}
		for index = 8, 2, -2 do
			local pos_1 = MathUtil.alignToSurfaceZ(MathUtil.getPosInFront(pos_behind, side_dir, index), 3)
			local pos_2 = MathUtil.alignToSurfaceZ(MathUtil.getPosInFront(pos_behind, side_dir, -index), 3)
			if pos_1 then table.insert(placing, pos_1) end
			if pos_2 then table.insert(placing, pos_2) end
		end
		table.insert(placing, MathUtil.alignToSurfaceZ(pos_behind, 3))
		
		data.placing = placing
	
	elseif not data.building then
		data.building = true
		data.build_timer:stopAndReset()
		data.build_index = data.build_index + 1
		Ui.target(origin_id).Toast.info('Building ' .. data.build_index .. '/' .. #data.placing, nil, 2000)
		return whileActive.TargetInfo({pos = data.placing[data.build_index]})
		
	elseif data.building and data.build_timer:stop() > 2000 then
		data.building = false
		
		if data.build_index == #data.placing then
			Ui.target(origin_id).Toast.success('Successfully build')
			return whileActive.Stop()
		end
	end
	
	if MathUtil.velocity(vehicle:getVelocity()) > 1 then
		Ui.target(origin_id).Toast.warn('Building aborted', nil, 1000)
		return whileActive.Stop()
	end
	return whileActive.Continue()
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info)
	local pos = target_info.pos
	
	-- spawn bollard in the ground
	local marker = createObject("TSStatic")
	marker.shapeName = "art/shapes/pwu/bollard/bollard.cdae"
	marker.useInstanceRenderData = 1
	marker.instanceColor = Point4F(0, 0, 0, 1)
	marker:setPosRot(pos.x, pos.y, pos.z - 2, 0, 0, 0, 1)
	marker.scale = vec3(3, 3, 3)
	marker:registerObject("bollard_" .. Util.randomName())
	
	Sfx(M.build_sounds:surprise(), pos)
		:is3D(true)
		:minDistance(20)
		:maxDistance(50)
		:volume(math.random(8, 10) / 10)
		:selfDestruct(5000)
		:spawn()
	
	local collision = function(self, vehicle, data)
		local bol_pos = data.bollard:getPosition()
		local veh_pos = vehicle:getPosition()
		local veh_vel = vehicle:getVelocity()
		if not MathUtil.isMovingTowards(bol_pos, veh_pos, veh_vel) then return end
		
		if MathUtil.velocity(veh_vel) > 41 then
			-- play break sound
			M.hit_sounds:surprise():smartSFX2(vehicle:getId(), nil, 2000, 30, 80)
			
			-- unsettle car
			vehicle:queueLuaCommand('PowerUpExtender.jump(2)')
			-- todo
			
			return true
		end
		
		local dir = (bol_pos - veh_pos):normalized()
		local dir_vel = -veh_vel - dir
		vehicle:applyClusterVelocityScaleAdd(vehicle:getRefNodeId(), 1, dir_vel.x, dir_vel.y, dir_vel.z)
		data.effect_timers[vehicle:getId()]:stopAndReset()
	end
	
	-- spawn building particle
	Particle("BNGP_16", vec3(pos.x, pos.y, pos.z + 0.2))
		:active(true)
		:velocity(1)
		:selfDisable(2000)
		:selfDestruct(3000)
	
	-- create placeable
	Placeable(vec3(pos.x, pos.y, pos.z + 1), vec3(3, 3, 3))
		:setData({
				bollard = marker,
				target_z = pos.z,
				building = true,
				effect_timers = data.shared
		}) -- remove after
		:selfDestruct(120000,
			function(self, data)
				data.bollard:delete()
			end
		)
		:attach( -- attach the building routine
			function(self, data)
				local dt = TimedTrigger.lastDt()
				local pos = data.bollard:getPosition()
				pos.z = pos.z + (1 * dt)
				
				if pos.z >= data.target_z then
					pos.z = data.target_z
					data.building = false
					self:unAttach() -- remove once done
				end
				
				data.bollard:setPosition(pos)
			end
		)
		:onEnter( -- once a vehicle enters create the timer
			function(self, vehicle, data)
				--local veh_pos = vehicle:getPosition()
				--TimedTrigger.newF('temp', 0, 1000, function(pos) debugDrawer:drawSphere(pos, 1, ColorF(1,1,1,1)) end, veh_pos)
				--simTimeAuthority.pause(true)
				local veh_id = vehicle:getId()
				if not data.building and data.effect_timers[veh_id] == nil then
					data.effect_timers[veh_id] = Timer.new()
					if collision(self, vehicle, data) then self:delete() end
				end
			end
		)
		:whileInside( -- while any vehicle is inside bounce it back if its close enough
			function(self, vehicle, data)
				if data.building then return end
				local dist = Util.dist3d(vehicle:getPosition(), data.bollard:getPosition())
				local veh_id = vehicle:getId()
				if dist > 2 or data.effect_timers[veh_id]:stop() < 30 then return end
				if collision(self, vehicle, data) then self:delete() end
			end
		)
end

-- When a target was hit, only called on players spectating origin_id
M.onTargetHit = function(data, origin_id, target_id) end

-- When a target was hit, called on every client
M.onHit = function(data, origin_id, target_id) end

-- When the powerup has ended or is destroyed by any means
M.onDeactivate = function(data, origin_id) end

-- Render Distance related
M.onUnload = function(data) end

M.onLoad = function(data) end


return M
