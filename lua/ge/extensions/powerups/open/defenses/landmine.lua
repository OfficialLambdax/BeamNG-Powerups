local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable, Ui = Extender.defaultImports(1)
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

local M = {
	-- Shown to the user
	clear_name = "Fetzi",
	
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
	effect_range = 8,
	explosion_sounds = Pot()
		:add('art/sounds/ext/missile/missile_explosion_1.ogg', 1)
		:add('art/sounds/ext/missile/missile_explosion_2.ogg', 1)
		:add('art/sounds/ext/missile/shockwave_heavy.ogg', 1)
		:stir(5),
}

-- Credits to Olrosse
local EXPLOSION = [[
	local explode = function(strength)
		local strength = strength or 1
		
		beamstate.breakAllBreakgroups()
		
		for _, coupler in pairs(controller.getControllersByType("advancedCouplerControl")) do
			coupler.detachGroup()
		end
		
		for _, beam in pairs(v.data.beams) do
			if beam.deformSwitches then
				material.switchBrokenMaterial(beam)
			end
		end
		
		for _, device in pairs(powertrain.getDevices()) do
			if device.onBreak then
				device:onBreak()
			end
		end
		
		local cog = vec3(0, 0, 0)
		local total_mass = 0
		for _, node in pairs(v.data.nodes) do
			local mass = obj:getNodeMass(node.cid)
			cog = cog + (node.pos * mass)
			total_mass = total_mass + mass
		end
		cog = cog / total_mass
		
		local rot = quat(obj:getRotation())
		for _, node in pairs(v.data.nodes) do
			local dir = (node.pos - cog):rotated(rot):normalized()
			obj:applyForceVector(node.cid, dir * 50000 * node.nodeWeight * strength)
		end
		
		local direction = obj:getDirectionVectorUp()
		direction.z = direction.z + 2
		obj:applyClusterLinearAngularAccel(0, direction * 5000 * strength, vec3(0, 0, 0))
	end;
]]

-- Called once when the powerup is loaded
M.onInit = function(group_defs)
	Extender.loadAssets('art/shapes/pwu/mine/materials.json')
end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	return onActivate.Success({ammo = 3, positions = {}})
end

M[Hotkey.Fire] = function(data, origin_id, state)
	if state ~= HKeyState.Down then return end
	
	local vehicle = be:getObjectByID(origin_id)
	if MathUtil.velocity(vehicle:getVelocity()) > 1 then
		Ui.target(origin_id).Toast.info('Must stand still', nil, 2)
		return
	end
	
	local origin_pos = vehicle:getPosition()
	origin_pos = MathUtil.getPosInFront(origin_pos, vehicle:getDirectionVector(), -7)
	origin_pos = MathUtil.alignToSurfaceZ(origin_pos, 3) or origin_pos
	
	if MathUtil.anyPosToClose(origin_pos, data.positions, 8) then
		Ui.target(origin_id).Toast.info('Too close to other mines', nil, 2)
		return
	end
	table.insert(data.positions, origin_pos)
	
	data.ammo = data.ammo - 1
	
	return onHKey.TargetInfo({origin_pos = origin_pos})
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	if data.ammo == 0 then
		Ui.target(origin_id).Msg.send('All placed!', 'banana', 1)
		return whileActive.Stop()
	end
	Ui.target(origin_id).Msg.send(data.ammo .. ' Mines to place left', 'banana', 1)
	return whileActive.Continue()
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info, origin_id)
	local origin_pos = target_info.origin_pos
	
	local marker = createObject("TSStatic")
	marker.shapeName = "art/shapes/pwu/mine/mine.cdae"
	marker.useInstanceRenderData = 1
	marker.instanceColor = Point4F(0, 0, 0, 1)
	marker:setPosRot(origin_pos.x, origin_pos.y, origin_pos.z - 0.1, 0, 0, 0, 1)
	marker.scale = vec3(2.5, 2.5, 2)
	marker:registerObject("banana_" .. Util.randomName())
	
	Placeable(origin_pos, vec3(3, 3, 3))
		:setData({
			mine = marker
		})
		:selfDestruct(180000,
			function(self, data)
				data.mine:delete()
			end
		)
		:onEnter(
			function(self, vehicle, data)
				local mine_pos = self:getPosition()
				local targets = MathUtil.getVehiclesInsideRadius(mine_pos, M.effect_range)
				
				for _, target_id in ipairs(targets) do
					local vehicle = be:getObjectByID(target_id)
					local dist = Util.dist3d(vehicle:getPosition(), mine_pos)
					local push = (vehicle:getPosition() - mine_pos):normalized() * (math.min(M.effect_range, M.effect_range - dist) * 1.2)
					
					vehicle:applyClusterVelocityScaleAdd(vehicle:getRefNodeId(), 1, push.x, push.y, push.z)
					vehicle:queueLuaCommand("PowerUpExtender.addAngularVelocity(0, 0, 3, 0, 1, 0)")
					vehicle:queueLuaCommand('fire.explodeVehicle()')
					vehicle:queueLuaCommand(EXPLOSION .. 'explode(0.7)')
				end
				
				Sfx(M.explosion_sounds:surprise(), vec3(mine_pos.x, mine_pos.y, mine_pos.z + 2))
					:is3D(true)
					:minDistance(100)
					:maxDistance(500)
					:volume(1)
					:pitch(math.random(8, 12) / 10)
					:selfDestruct(10000)
					:spawnIn(100)
					
				Particle("PWU_ExplosionSmall", mine_pos)
					:active(true)
					:selfDisable(200)
					:selfDestruct(25000)
				
				self:delete()
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
