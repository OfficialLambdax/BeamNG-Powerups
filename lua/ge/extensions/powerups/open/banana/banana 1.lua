local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

local M = {
	-- Shown to the user
	clear_name = "Banana I",
	
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
	M.activation_sound = Sound('/art/sounds/ext/banana/minion_laugh.ogg', 3)
	Extender.loadAssets('art/shapes/pwu/banana/materials.json')
end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	local origin_pos = vehicle:getPosition()
	local origin_pos = MathUtil.getPosInFront(origin_pos, vehicle:getDirectionVector(), -7)
	
	return onActivate.TargetInfo({}, {origin_pos = origin_pos})
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	return whileActive.Stop()
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info)
	local origin_pos = target_info.origin_pos
	
	local marker = createObject("TSStatic")
	marker.shapeName = "art/shapes/pwu/banana/banana_peel.cdae"
	marker.useInstanceRenderData = 1
	marker.instanceColor = Point4F(0, 0, 0, 1)
	marker:setPosRot(origin_pos.x, origin_pos.y, origin_pos.z + 0.2, 0, 0, 0, 1)
	marker.scale = vec3(8, 8, 8)
	marker:registerObject("banana_" .. Util.randomName())
	
	Placeable(origin_pos, vec3(4, 4, 4))
		:setData({
			target_id = nil,
			target_dir = nil,
			act_timer = nil,
			marker = marker,
		})
		:selfDestruct(180000,
			function(self, data)
				data.marker:delete()
			end
		)
		:onEnter(
			function(self, vehicle, data)
				if data.target_id == nil then
					data.target_id = vehicle:getId()
				else
					return
				end
				
				M.activation_sound:smartSFX2(data.target_id, nil, 5000, 20, 60)
				
				-- remove banana
				data.marker:delete()
				
				-- perform spin
				local target_vel = vehicle:getVelocity()
				local reduced_vel = -(target_vel * 0.5)
				vehicle:applyClusterVelocityScaleAdd(vehicle:getRefNodeId(), 1, reduced_vel.x, reduced_vel.y, reduced_vel.z)
				
				local spin = vehicle:getDirectionVectorUp():normalized() * 9
				vehicle:queueLuaCommand(string.format("PowerUpExtender.addAngularVelocity(0, 0, 0, %d, %d, %d)", spin.x, spin.y, spin.z))
				
				-- safe necessary data for the counter spin
				data.target_dir = vehicle:getDirectionVector()
				data.act_timer = Timer.new()
				
				-- attach a routine to the trigger
				self:delete()
				--[[
				self:attach(
					function(self, data)
						if data.act_timer:stop() < 200 then return end -- after this
						local vehicle = be:getObjectByID(data.target_id)
						
						-- check if vehicle is back to original rotation
						local target_dir = vehicle:getDirectionVector()
						if MathUtil.isDirInRange(target_dir, data.target_dir, 0.1) then
							
							-- if so, perform counter spin
							local spin = vehicle:getDirectionVectorUp():normalized() * -6
							vehicle:queueLuaCommand(
								string.format(
									"PowerUpExtender.addAngularVelocity(0, 0, 0, %d, %d, %d)",
									spin.x, spin.y, spin.z
								)
							)
							
							self:delete()
						end
					end
				)
				]]
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
