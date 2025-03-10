local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable, Ui = Extender.defaultImports(1)
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

local M = {
	-- Shown to the user
	clear_name = "Missile",
	
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
	max_len = 180000,
	
	-- TODO
	target_info_descriptor = nil,
	
	-- Configure traits this powerup respects. Required for trait call sync
	respects_traits = {},
	
	-- Auto filled
	-- Contains the dir path to this powerup
	file_path = "",
	
	effect_radius = 60,
	effect_radius_inner = 30,
	
	-- Add extra variables here if needed. Constants only!
	lockon_sound = Sound('art/sounds/ext/missile/missile_lockon.ogg', 1.5),
	
	-- cannot use Sounds lib for any below because these sounds are location bound not vehicle bound
	explosion_sounds = Pot()
		:add('art/sounds/ext/missile/missile_explosion_1.ogg', 1)
		:add('art/sounds/ext/missile/missile_explosion_2.ogg', 1)
		:add('art/sounds/ext/missile/shockwave_heavy.ogg', 1)
		:stir(5),
	
	launch_sounds = Pot()
		:add('art/sounds/ext/missile/missile_launch_1.ogg', 1)
		:add('art/sounds/ext/missile/missile_launch_2.ogg', 1)
		:add('art/sounds/ext/missile/missile_launch_3.ogg', 1)
		:add('art/sounds/ext/missile/missile_launch_4.ogg', 1)
		:stir(5),
	
	fly_sounds = Pot()
		:add('art/sounds/ext/missile/missile_engine_1.ogg', 1)
		:add('art/sounds/ext/missile/missile_engine_2.ogg', 1)
		:stir(5),
}

-- Called once when the powerup is loaded
M.onInit = function(group_defs)
	Extender.loadAssets('art/shapes/pwu/missile/materials.json')
end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

M[Hotkey.TargetChange] = function(data, origin_id, state)
	if state ~= HKeyState.Down then return end
	data.rocket.prefered_target = nil
	return onHKey.TargetInfo({target = {}})
end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	Ui.target(vehicle:getId()).Toast.info("This powerup is Work in progress")
	return onActivate.TargetInfo({
			rocket = nil,
			impact_pos = nil
		},
		{
			spawn = {start_pos = vehicle:getPosition(), start_vel = vehicle:getVelocity()}
		}
	)
end

local function thrustClearName(rocket, thrust)
	if thrust == rocket.thrust_low then
		return "Low"
	elseif thrust == rocket.thrust_high then
		return "High"
	elseif thrust == rocket.thrust_max then
		return "Max"
	end
end

local function altitudeClearName(altitude)
	altitude = math.floor(altitude)
	if altitude >= 0 then
		return '+' .. altitude .. 'm/s'
	end
	return altitude .. 'm/s'
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	local rocket = data.rocket
	if not rocket then return whileActive.Continue() end
	
	local thrust = rocket.thrust_low
	local altitude = math.floor(rocket.pos.z - (MathUtil.surfaceHeight(rocket.pos) or 0))
	local altitude_change = (rocket.pos + (rocket.vel * 1)).z - rocket.pos.z
	
	if not rocket.target_id and rocket.search_timer:stop() > 200 then
		rocket.search_timer:stopAndReset()
		--rocket.dir = vec3(0, 0, 1)
		rocket.dir.z = 0.3
		local launch_or_search = "Searching target\n"
		if rocket.prefered_target == nil then
			if rocket.launch_timer:stop() > 4000 then
				local targets = MathUtil.getVehiclesInsideRadius2d(rocket.pos, 5000, origin_id)
				if #targets > 0 then
					targets = Extender.cleanseTargetsBehindStatics(rocket.pos, targets)
					targets = Extender.cleanseTargetsWithTraits(targets, origin_id, Trait.Ignore)
					
					local _, target_id = Util.tablePickRandom(targets)
					rocket.prefered_target = target_id
				end
			else
				launch_or_search = "Launching sequence\n"
			end
		else
			-- scan for target
			local targets = MathUtil.getVehiclesInsideRadius2d(rocket.pos, 5000, origin_id)
			if #targets > 0 then
				targets = Extender.cleanseTargetsBehindStatics(rocket.pos, targets)
				targets = Extender.cleanseTargetsWithTraits(targets, origin_id, Trait.Ignore)
				targets = Util.tableVToK(targets)
				if targets[rocket.prefered_target] then
					return whileActive.TargetInfo({target = {target_id = Extender.safeIdTransfer(rocket.prefered_target)}})
				end
			end
		end
		Ui.target(origin_id)
			.Msg
			.send(
				launch_or_search ..
				'Speed: ' .. math.floor(MathUtil.velocity(rocket.vel) * 3.6) .. 'kph\n' ..
				'Altitude: ' .. altitude .. 'm ' .. altitudeClearName(altitude_change) .. '\n' ..
				'Fuel left ' .. math.floor((rocket.fuel / 1) * 100) .. ' %\n' ..
				'Thrust: ' .. thrustClearName(rocket, thrust),
				"rocket.target_info." .. origin_id,
				1
			)
		
	elseif rocket.target_id then
		-- see if target is still valid
		local tar_veh = be:getObjectByID(rocket.target_id)
		if not tar_veh or not tar_veh:getActive() then
			return whileActive.TargetInfo({target = {}})
			
		else
			-- check if target is behind static
			local tar_pos = tar_veh:getPosition()
			if MathUtil.raycastAlongSideLine(rocket.pos, tar_pos) then
				return whileActive.TargetInfo({target = {}})
				
			else
				-- reference for later
				-- https://www.codeproject.com/KB/recipes/Missile_Guidance_System.aspx
				
				local tar_vel = tar_veh:getVelocity()
				local dist = Util.dist3d(tar_pos, rocket.pos)
				local dir = (tar_pos - rocket.pos):normalized()
				
				local relative_speed = math.abs(MathUtil.velocity(rocket.vel) - dir:dot(tar_vel))
				local pre_pos = tar_vel * dist / relative_speed
				
				dir = ((tar_pos + pre_pos) - rocket.pos):normalized()
				rocket.facing_dir = dir
				rocket.dir = dir - rocket.vel:normalized() * 0.85
				--debugDrawer:drawSphere(tar_pos + pre_pos, 1, ColorF(1,1,1,1))
				--debugDrawer:drawSphere(tar_pos + pre_pos, 1, ColorF(1,1,1,1))
				--debugDrawer:drawSphere(rocket.pos + rocket.dir, 1, ColorF(1,1,1,1))
				--debugDrawer:drawSphere(rocket.dir, 1, ColorF(1,1,1,1))
				
				local z_dist = rocket.pos.z - tar_pos.z
				--if dist > 1000 and z_dist < 100 then
				--	rocket.dir.z = 0.2
				if dist > 50 and z_dist < 5 then
					rocket.dir.z = 0.6
				end
				if dist > 300 then
					thrust = rocket.thrust_high
				else
					thrust = rocket.thrust_max
				end
				Ui.target(origin_id)
					.Msg
					.send(
						'Target: "' .. Extender.getVehicleOwner(rocket.target_id) .. '"\n' ..
						'Distance: ' .. math.floor(dist) .. 'm\n' ..
						'Speed: ' .. math.floor(MathUtil.velocity(rocket.vel) * 3.6) .. 'kph\n' ..
						'Altitude: ' .. altitude .. 'm ' .. altitudeClearName(altitude_change) .. '\n' ..
						'Fuel left: ' .. math.floor((rocket.fuel / 1) * 100) .. ' %\n' ..
						'Thrust: ' .. thrustClearName(rocket, thrust),
						"rocket.target_info." .. origin_id,
						1
					)
				
				Ui.target(rocket.target_id)
					.Msg
					.send(
						'INCOMING MISSILE\n' ..
						'Distance: ' .. math.floor(dist) .. 'm\n' ..
						'Fuel left ' .. math.floor((rocket.fuel / 1) * 100) .. ' %',
						"rocket.target_info." .. origin_id,
						1
					)
				
			end
		end
	end
	
	if not rocket.target_id then
		if altitude > 3000 then
			return whileActive.Stop()
		end
		if altitude < 30 then
			rocket.dir = vec3(0, 0, 1)
			thrust = rocket.thrust_max
		else
			if altitude_change < -30 then
				thrust = rocket.thrust_max
			elseif altitude_change < -5 then
				thrust = rocket.thrust_high
			end
		end
	end
	
	-- change vel towards target dir
	local acceleration = 0
	if rocket.fuel > 0 then
		acceleration = thrust / rocket.mass
		
		rocket.fuel = rocket.fuel - (0.000015 * thrust * dt)
		if rocket.fuel <= 0 then
			rocket.fuel = 0
			rocket.engine_sound:stop()
		end
	end
	
	-- im sure this wrong but it works
	--vel = vel + (dir * acceleration * dt)
	local factor = 1
	if rocket.target_id then factor = 1.85 end
	rocket.vel = rocket.vel + (rocket.dir * acceleration * factor * dt)
	
	if rocket.fuel == 0 then
		-- gravity influence. this is unrealistic on purpose
		-- allows us to make the missile slower and more playfull
		rocket.vel.z = rocket.vel.z - (9.81 * dt)
	end
	--print(MathUtil.velocity(vel))
	
	-- calc next position given our velocity
	local pos = rocket.pos
	local pre_pos = pos + (rocket.vel * dt)
	--debugDrawer:drawSphere(pre_pos, 1, ColorF(1,1,1,1))
	
	local rot = MathUtil.quatFromQuatAndDir(rocket.obj:getRotation(), rocket.facing_dir)
	rocket.obj:setPosRot(pre_pos.x, pre_pos.y, pre_pos.z, rot.x, rot.y, rot.z, rot.w)
	--rocket.obj:setPosRot(0, 0, 10, rot.x, rot.y, rot.z, rot.w)
	rocket.trail:setRotation(rot):active(rocket.fuel > 0)
	rocket.trail2:setRotation(rot)--:active(rocket.fuel > 0)
	rocket.pos = pre_pos
	
	local targets = MathUtil.getCollisionsAlongSideLine(pos, pre_pos, 3, origin_id)
	local impact_dist = MathUtil.raycastAlongSideLine(pos, pre_pos)
	if impact_dist or #targets > 0 then
		local impact_pos
		if impact_dist then
			impact_pos = MathUtil.getPosInFront(pos, rocket.dir, impact_dist - 5)
		else
			impact_pos = be:getObjectByID(targets[1]):getPosition()
		end
		
		-- get all targets inside a bigger radius and cleanse whoes behind a static
		local targets = MathUtil.getVehiclesInsideRadius(impact_pos, M.effect_radius)
		if #targets > 0 then
			targets = Extender.cleanseTargetsBehindStatics(impact_pos, targets)
		end
		
		if rocket.target_id then
			M.lockon_sound:stopVE(data.rocket.target_id)
		end
		
		Ui.target(origin_id).Toast.info(#targets .. ' targets hit')
		return whileActive.StopAfterExec({impact = impact_pos}, targets)
	end
	
	if rocket.update_timer:stop() > 1000 then
		rocket.update_timer:stopAndReset()
		return whileActive.TargetInfo({update = {
			pos = rocket.pos,
			vel = rocket.vel
		}})
	end
	
	return whileActive.Continue()
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info, origin_id)
	if target_info.spawn then
		local pos = target_info.spawn.start_pos
		local marker = createObject("TSStatic")
		marker.shapeName = "art/shapes/pwu/missile/missile.cdae"
		marker.useInstanceRenderData = 1
		marker.instanceColor = Point4F(0, 0, 0, 1)
		marker:setPosRot(pos.x, pos.y, pos.z + 1, 0, 0, 0, 1)
		marker.scale = vec3(0.5, 0.5, 0.5)
		marker:registerObject("rocket_" .. Util.randomName())
		
		local trail = Particle("BNGP_29", pos)
			:active(true)
			:velocity(-5)
			:follow(marker)
			:bind(marker)
		
		local trail2 = Particle("BNGP_49", pos)
			:active(true)
			:velocity(-5)
			:follow(marker)
			:bind(marker)
		
		Sfx(M.launch_sounds:surprise(), pos)
			:is3D(true)
			:volume(1)
			:follow(marker)
			:bind(marker)
			:minDistance(50)
			:maxDistance(2500)
			:spawn()
		
		local engine_sound = Sfx(M.fly_sounds:surprise(), pos)
			:is3D(true)
			:volume(0.05)
			:follow(marker)
			:bind(marker)
			:minDistance(10)
			:maxDistance(600)
			:isLooping(true)
			:spawnIn(1000)
		
		local rocket = {
			obj = marker,
			trail = trail,
			trail2 = trail2,
			engine_sound = engine_sound,
			target_id = nil,
			prefered_target = nil,
			search_timer = Timer.new(),
			launch_timer = Timer.new(),
			update_timer = Timer.new(),
			pos = vec3(pos.x, pos.y, pos.z + 5),
			vel = vec3(0, 0, 50) + vec3(target_info.spawn.start_vel),
			dir = vec3(0, 0, 1),
			facing_dir = vec3(0, 0, 1),
			fuel = 1,
			mass = 50,
			thrust_low = 500,
			thrust_high = 1000,
			thrust_max = 3000
		}
		
		data.rocket = rocket
		return
		
	elseif target_info.target then
		local target_id = target_info.target.target_id
		if target_id then
			target_id = Extender.safeIdTransfer(nil, target_id)
		end
		
		if data.rocket.target_id and not target_id then
			Ui.target(data.rocket.target_id).Msg.send('Target lost', "rocket.target_info." .. origin_id, 1)
			M.lockon_sound:stopVE(data.rocket.target_id)
		end
		
		data.rocket.target_id = target_id
		if data.rocket.target_id then
			M.lockon_sound:playVE(data.rocket.target_id)
		end
		
	elseif target_info.update then
		if not Extender.isPlayerVehicle(origin_id) then
			data.rocket.pos = vec3(target_info.update.pos)
			data.rocket.vel = vec3(target_info.update.vel)
		end
		
	elseif target_info.impact then
		data.impact_pos = vec3(target_info.impact)
		
		Particle("BNGP_31", data.impact_pos)
			:active(true)
			:velocity(-5)
			:selfDisable(math.random(1000, 3000))
			:selfDestruct(30000)
		Particle("PWU_Explosion", data.impact_pos)
			:active(true)
			:velocity(1)
			:selfDisable(500)
			:selfDestruct(30000)
		Particle("BNGP_32", data.impact_pos)
			:active(true)
			:velocity(1)
			:selfDisable(math.random(1000, 3000))
			:selfDestruct(30000)
		--[[
		Particle("PWU_Explosion", data.impact_pos)
			:active(true)
			:velocity(2)
			:selfDisable(math.random(1000, 3000))
			:selfDestruct(30000)
		Particle("PWU_Explosion", data.impact_pos)
			:active(true)
			:velocity(3)
			:selfDisable(math.random(1000, 3000))
			:selfDestruct(30000)
		]]
			
		Sfx(M.explosion_sounds:surprise(), data.impact_pos)
			:is3D(true)
			:minDistance(100)
			:maxDistance(2500)
			:volume(1)
			:pitch(math.random(8, 10) / 10)
			:selfDestruct(10000)
			:spawnIn(100)
	end
end

-- When a target was hit, only called on players spectating origin_id
M.onTargetHit = function(data, origin_id, target_id) end

-- When a target was hit, called on every client
M.onHit = function(data, origin_id, target_id)
	if Extender.hasTraitCalls(target_id, origin_id, Trait.Consuming, Trait.Breaking) then return end
	local target_vehicle = be:getObjectByID(target_id)
	local pos1 = data.impact_pos
	local pos2 = target_vehicle:getPosition()
	local dist = Util.dist3d(pos2, pos1)
	
	local push = (pos2 - pos1):normalized() * (math.min(M.effect_radius, M.effect_radius - dist) * 1.5)
	target_vehicle:applyClusterVelocityScaleAdd(target_vehicle:getRefNodeId(), 1, push.x, push.y, push.z)
	--target_vehicle:queueLuaCommand("PowerUpExtender.addAngularVelocity(0, 0, 3, 0, 10, 0)")
	
	if dist < M.effect_radius_inner then
		local exec = [[
			fire.explodeVehicle()
			fire.igniteVehicle()
			beamstate.breakAllBreakgroups()
		]]
		target_vehicle:queueLuaCommand(exec)
	end
end

-- When the powerup has ended or is destroyed by any means
M.onDeactivate = function(data, origin_id)
	if data.rocket then
		data.rocket.obj:delete()
		data.rocket.trail:delete()
		data.rocket.trail2:delete()
	end
end

-- Render Distance related
M.onUnload = function(data)
	if data.rocket then
		data.rocket.obj:setHidden(true)
		data.rocket.trail:active(false)
		data.rocket.trail2:active(false)
	end
end

M.onLoad = function(data)
	if data.rocket then
		data.rocket.obj:setHidden(false)
		data.rocket.trail:active(true)
		data.rocket.trail2:active(true)
	end
end


return M
