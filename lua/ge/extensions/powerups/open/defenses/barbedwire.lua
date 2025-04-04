local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable, Ui = Extender.defaultImports(1)
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

local M = {
	-- Shown to the user
	clear_name = "Spike Strip",
	
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
M.onInit = function(group_defs)
	Extender.loadAssets('art/shapes/pwu/barbedwire/materials.json')
	Extender.loadAssets('art/shapes/pwu/signs/materials.json')
end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	if Extender.isTraffic(vehicle:getId()) then return onActivate.Error('Traffic is not supported yet') end
	return onActivate.Success({
		selected = false,
		building = false,
		placeable = nil
	})
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	local vehicle = getObjectByID(origin_id)
	
	if not data.selected then
		if MathUtil.velocity(vehicle:getVelocity()) > 1 then
			Ui.target(origin_id).Toast.info('Must stand still', nil, 1000)
			return whileActive.Continue()
		end
		local veh_dir = vehicle:getDirectionVector()
		local pos_behind = MathUtil.getPosInFront(vehicle:getSpawnWorldOOBB():getCenter(), veh_dir, -4)
		local pos_behind = MathUtil.alignToSurfaceZ(pos_behind, 3)
		if pos_behind == nil then return whileActive.Stop() end
		data.selected = true
		return whileActive.TargetInfo({
			build_pos = pos_behind,
			build_dir = quatFromDir(vehicle:getDirectionVectorUp(), vehicle:getDirectionVector()),
			sign_dir = quatFromDir(vehicle:getDirectionVectorUp():cross(-vehicle:getDirectionVector()))
		})
		
	elseif data.building then
		if data.placeable:getData().building then return whileActive.Continue() end
		Ui.target(origin_id).Toast.success('Wire placed', nil, 1000)
		return whileActive.Stop()
	end
	
	return whileActive.Continue()
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info)
	local pos = target_info.build_pos
	local dir = target_info.build_dir
	local sign_dir = target_info.sign_dir
	data.building = true
	
	local marker = createObject("TSStatic")
	marker.shapeName = "art/shapes/pwu/barbedwire/barbedwire_2.cdae"
	marker.useInstanceRenderData = 1
	marker.instanceColor = Point4F(0, 0, 0, 1)
	marker:setPosRot(pos.x, pos.y, pos.z + 0.35, dir.x, dir.y, dir.z, dir.w)
	marker.scale = vec3(0, 1, 1)
	marker:registerObject("barbedwire_" .. Util.randomName())
	
	local sign = createObject("TSStatic")
	sign.shapeName = "art/shapes/pwu/signs/road_spikes2.cdae"
	sign.useInstanceRenderData = 1
	sign.instanceColor = Point4F(0, 0, 0, 1)
	sign:setPosRot(pos.x, pos.y, pos.z + 5, sign_dir.x, sign_dir.y, sign_dir.z, sign_dir.w)
	sign.scale = vec3(3, 3, 3)
	sign:registerObject("signs_" .. Util.randomName())
	sign:setHidden(true)
	
	data.placeable = Placeable(vec3(pos.x, pos.y, pos.z + 0.5), vec3(14, 2, 1.5))
		:setRotation(dir)
		:setData({
			wire = marker,
			sign = sign,
			building = true,
			target_size = 2.5
		})
		:selfDestruct(180000,
			function(self, data)
				data.wire:delete()
				data.sign:delete()
			end
		)
		:attach(
			function(self, data)
				local dt = TimedTrigger.lastDt()
				local pos = data.wire:getPosition()
				local scale = data.wire:getScale()
				
				scale.x = scale.x + (0.5 * dt)
				if scale.x >= data.target_size then
					scale.x = data.target_size
					data.building = false
					data.sign:setHidden(false)
					self:unAttach()
				end
				
				data.wire:setScale(scale)
			end
		)
		:onEnter(
			function(self, vehicle, data)
				if data.building then return end
				vehicle:queueLuaCommand('beamstate.deflateRandomTire()')
			end
		)
		:onExit(
			function(self, vehicle, data)
				if data.building then return end
				vehicle:queueLuaCommand('beamstate.deflateRandomTire()')
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
