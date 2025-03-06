local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable = Extender.defaultImports()
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
	max_len = 15000,
	
	-- TODO
	target_info_descriptor = nil,
	
	-- Configure traits this powerup respects. Required for trait call sync
	respects_traits = {},
	
	-- Auto filled
	-- Contains the dir path to this powerup
	file_path = "",
	
	-- Add extra variables here if needed. Constants only!
	activation_sound = nil,
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
	
	return onActivate.Success({
		placing = placing,
		build_index = 0,
		building = false,
		build_timer = Timer.new()
	})
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	-- if fully build then stop
	if data.build_index == #data.placing and data.building == false then return whileActive.Stop() end
	
	-- while the vehicle is moving dont do anything
	local origin_vehicle = be:getObjectByID(origin_id)
	if MathUtil.velocity(origin_vehicle:getVelocity()) > 1 then
		if data.build_index > 0 then -- except the vehicle was already in the building process then quit
			return whileActive.Stop()
		end
		return whileActive.Continue()
	end
	
	if not data.building then -- build
		data.building = true
		data.build_timer:stopAndReset()
		data.build_index = data.build_index + 1
		return whileActive.TargetInfo({pos = data.placing[data.build_index]})
		
	elseif data.building and data.build_timer:stop() > 2000 then -- if build is done
		data.building = false
		return whileActive.Continue()
		
	else
		return whileActive.Continue()
	end
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
	
	-- spawn building particle
	Particle("BNGP_16", vec3(pos.x, pos.y, pos.z + 0.2))
		:active(true)
		:velocity(1)
		:selfDisable(2000)
		:selfDestruct(3000)
	
	-- create placeable
	local shared = {}
	Placeable(pos, vec3(3, 3, 3))
		:setData({
				bollard = marker,
				target_z = pos.z,
				building = true,
				effect_timers = shared
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
				local veh_id = vehicle:getId()
				if data.effect_timers[veh_id] == nil then
					data.effect_timers[veh_id] = Timer.new()
					if not MathUtil.isMovingTowards(data.bollard:getPosition(), vehicle:getPosition(), vehicle:getVelocity()) then return end
					
					local dir = (data.bollard:getPosition() - vehicle:getPosition()):normalized()
					local vel = -vehicle:getVelocity() - dir
					vehicle:applyClusterVelocityScaleAdd(vehicle:getRefNodeId(), 1, vel.x, vel.y, vel.z)
				end
			end
		)
		:whileInside( -- while any vehicle is inside bounce it back if its close enough
			function(self, vehicle, data)
				if data.building then return end
				local dist = Util.dist3d(vehicle:getPosition(), data.bollard:getPosition())
				local veh_id = vehicle:getId()
				if dist > 2 or data.effect_timers[veh_id]:stop() < 30 then return end
				if not MathUtil.isMovingTowards(data.bollard:getPosition(), vehicle:getPosition(), vehicle:getVelocity()) then return end
				
				local dir = (data.bollard:getPosition() - vehicle:getPosition()):normalized()
				local vel = -vehicle:getVelocity() - dir
				vehicle:applyClusterVelocityScaleAdd(vehicle:getRefNodeId(), 1, vel.x, vel.y, vel.z)
				data.effect_timers[veh_id]:stopAndReset()
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
