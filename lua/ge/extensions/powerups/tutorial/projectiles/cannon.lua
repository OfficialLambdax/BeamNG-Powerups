local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject = Extender.defaultPowerupVars()

--[[
	This powerup will spawn a non directed cannon ball out of the front of the vehicle and then check if it collides with any other vehicle.
]]

local M = {
	-- Shown to the user
	clear_name = "Cannon",
	
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
	max_len = 2500,
	
	-- TODO
	target_info_descriptor = nil,
	
	-- Configure traits this powerup respects. Required for trait call sync
	respects_traits = {Trait.Ghosted},
	
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
	-- Instead of spawning the cannon ball projectile directly we will for now just get our vehicles position, forward vector and vehicle speed.
	
	local position = vehicle:getPosition()
	local direction = vehicle:getDirectionVector()
	local velocity = MathUtil.velocity(vehicle:getVelocity())
	
	-- Then we give this information into target_info
	local target_info = {
		position = position,
		direction = direction,
		velocity = velocity
	}
	
	-- Next we initilize empty data. we need it moving forward
	local data = {}
	
	-- And return it together
	return onActivate.TargetInfo(data, target_info)
	
	--[[
		The reason we dont spawn the projectile yet is for multiplayer sync.
		target_info is synced across a multiplayer session which means that for everyone the cannon ball will start at the same position, will go the same direction and that with the same speed!
		
		We spawn it in onTargetSelect!
	]]
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info)
	-- The target_info we have returned in onActivate now ends up here!
	-- Either directly (in singleplayer) or once it came from the player executing this powerup.
	-- Now we will inherit the data and spawn the projectile!
	
	-- We merge target_info into data
	Util.tableMerge(data, target_info)
	-- so data now has {position, direction and velocity}
	
	-- lets spawn the projectile. For ease of use were are just going to use a tstatic
	local projectile = createObject("TSStatic")
	projectile.shapeName = "art/shapes/collectible/s_trashbag_collectible.cdae"
	projectile.useInstanceRenderData = 1
	projectile.instanceColor = Point4F(0, 0, 0, 0)
	projectile:setPosRot(data.position.x, data.position.y, data.position.z, 0, 0, 0, 1)
	projectile.scale = vec3(1, 1, 1)
	projectile:registerObject(Util.randomName())
	
	-- and we save it!
	data.projectile = projectile
	
	-- and a timer
	data.life_time = Timer.new()
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	-- while the projectile has not yet been spawned do nothing
	if data.projectile == nil then return end
	
	-- Since the projectile wont move on its own we have to move it!
	
	-- take the current position
	local current_pos = data.projectile:getPosition()
	
	-- and from that we want to move forward by our initial velocity + 100. Never forget to multiply by dt!
	local next_pos = MathUtil.getPosInFront(current_pos, data.direction, (data.velocity + 100) * dt)
	
	-- then we update the tstatics position
	data.projectile:setPosRot(next_pos.x, next_pos.y, next_pos.z, 0, 0, 0, 0)
	
	-- and now we just have to check if the projectile collided with any vehicle along its last position and new
	
	-- From old pos, to new pos, check if in a radius of 3 meters anyone collided, except us!
	local target_hits = MathUtil.getCollisionsAlongSideLine(current_pos, new_pos, 3, origin_id)
	
	-- Next we are going to cleanse the potential target hits of vehicles with powerups that implement the Ghosted trait. We essentially want to fly straight through them
	Extender.cleanseTargetsWithTraits(target_hits, origin_id, Trait.Ghosted)
	
	-- If there have been any hits!
	if #target_hits > 0 then
		
		-- we return the target_hits and essentially say that directly afterwards we want this powerup to quit
		return whileActive.StopAfterExec(nil, target_hits)
		
	elseif data.life_time:stop() > 2500 then
		
		-- The projectiles life time is over, lets quit this powerup
		return whileActive.Stop()
	
	else
		-- we didnt hit anyone, time is still running, lets continue moving the projectile!
		return whileActive.Continue()
	end
end

-- When a target was hit, only called on players spectating origin_id
M.onTargetHit = function(data, origin_id, target_id) end

-- When a target was hit, called on every client
M.onHit = function(data, origin_id, target_id)
	
end

-- When the powerup has ended or is destroyed by any means
M.onDeactivate = function(data, origin_id)
	-- Lastly we despawn the projectile if we got to spawn it!
	if data.projectile then
		data.projectile:delete()
	end
end

-- Render Distance related
M.onUnload = function(data) end

M.onLoad = function(data) end


return M
