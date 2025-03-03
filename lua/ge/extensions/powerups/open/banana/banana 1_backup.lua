local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

local M = {
	-- Shown to the user
	clear_name = "Banana",
	
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
	--my_var = 0,
}

-- Called once when the powerup is loaded
M.onInit = function(group_defs) end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	local origin_pos = vehicle:getPosition()
	local origin_pos = MathUtil.getPosInFront(origin_pos, vehicle:getDirectionVector(), -3)
	
	return onActivate.TargetInfo({
			obj = nil,
			life_time = Timer.new(),
			target_id = nil,
			act_timer = nil,
		},
		{
			origin_pos = origin_pos
		}
	)
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	if data.obj == nil then -- while proj hasnt been spawned yet
		return whileActive.Continue()
	
	elseif data.obj:isDeleted() and data.target_id then -- after proj has been deleted and target chosen
		local target_vehicle = be:getObjectByID(data.target_id)
		if target_vehicle == nil then return whileActive.Stop() end
		
		if data.act_timer:stop() < 200 then return whileActive.Continue() end
		
		local target_dir = target_vehicle:getDirectionVector()
		if MathUtil.isDirInRange(target_dir, data.target_dir, 0.1) then
			local spin = target_vehicle:getDirectionVectorUp():normalized() * -6
			target_vehicle:queueLuaCommand(string.format("PowerUpExtender.addAngularVelocity(0, 0, 0, %d, %d, %d)", spin.x, spin.y, spin.z))
			
			return whileActive.Stop()
		end
	
	elseif data.life_time:stop() < M.max_len and not data.obj:isDeleted() then -- while proj exists and life time is below max
		
		local proj_pos = data.obj:getPosition()
		local targets = MathUtil.getVehiclesInsideRadius(proj_pos, 4, origin_id)
		local targets = Extender.cleanseTargetsWithTraits(targets, origin_id, Trait.Ghosted)
		local targets = Extender.cleanseTargetsBehindStatics(proj_pos, targets)
		
		if #targets > 0 then
			data.obj:delete()
			return whileActive.TargetHits(targets)
		end
		return whileActive.Continue()
		
	else -- after proj has been deleted and target been resettled
		return whileActive.Stop()
	end
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info)
	local origin_pos = target_info.origin_pos
	
	local marker = createObject("TSStatic")
	marker.shapeName = "art/shapes/banana/banana_peel.dae"
	marker.useInstanceRenderData = 1
	marker.instanceColor = Point4F(0, 0, 0, 1)
	marker:setPosRot(origin_pos.x, origin_pos.y, origin_pos.z + 0.2, 0, 0, 0, 1)
	marker.scale = vec3(8, 8, 8)
	marker:registerObject("banana_" .. Util.randomName())
	
	data.obj = marker
end

-- When a target was hit, only called on players spectating origin_id
M.onTargetHit = function(data, origin_id, target_id) end

-- When a target was hit, called on every client
M.onHit = function(data, origin_id, target_id)
	local target_vehicle = be:getObjectByID(target_id)
	local target_vel = target_vehicle:getVelocity()
	
	data.target_id = target_id
	data.target_dir = target_vehicle:getDirectionVector()
	data.act_timer = Timer.new()
	
	local reduced_vel = -(target_vel * 0.5)
	target_vehicle:applyClusterVelocityScaleAdd(target_vehicle:getRefNodeId(), 1, reduced_vel.x, reduced_vel.y, reduced_vel.z)
	
	local spin = target_vehicle:getDirectionVectorUp():normalized() * 9
	target_vehicle:queueLuaCommand(string.format("PowerUpExtender.addAngularVelocity(0, 0, 0, %d, %d, %d)", spin.x, spin.y, spin.z))
end

-- When the powerup has ended or is destroyed by any means
M.onDeactivate = function(data, origin_id)
	if data.obj then
		data.obj:delete()
	end
end

-- Render Distance related
M.onUnload = function(data) end

M.onLoad = function(data) end


return M
