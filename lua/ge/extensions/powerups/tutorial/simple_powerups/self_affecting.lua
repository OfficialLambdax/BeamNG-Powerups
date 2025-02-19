local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles = Extender.defaultPowerupVars()

--[[
	In this powerup example we are going to increase the grip of our vehicle and end it after 1 second.
	While also playing a sound.
]]

local M = {
	-- Shown to the user
	clear_name = "Grip I",
	
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
	max_len = 1000,
	
	-- TODO
	target_info_descriptor = nil,
	
	-- Configure traits this powerup respects. Required for trait call sync
	respects_traits = {},
	
	-- Auto filled
	-- Contains the dir path to this powerup
	file_path = "",
	
	-- Add extra variables here if needed. Constants only!
	activate_sound = nil,
}

-- Called once when the powerup is loaded
M.onInit = function(group_defs)
	-- M.file_path is not known at compile time, so we load the sound hre
	M.activate_sound = Sound(M.file_path .. 'sounds/electrical_shock_zap.ogg')
end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	-- Lets modify our calling vehicle by giving it more grip
	vehicle:queueLuaCommand('PowerUpExtender.setGrip(2)')
	
	-- Then play the sound on the vehicle
	M.activate_sound:playVE(vehicle:getId())
	
	-- Then we want this powerup to end after a certain amount of time, so we need a timer that we can check against in whileActive
	local data = {
		my_timer = Timer.new() -- This creates a timer that can also be paused!
	}
	
	-- And we return the data that we need ongoing
	return onActivate.Success(data)
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	-- We want this effect to only last for 1 second, as long as we are below it we continue keeping this powerup active
	if data.my_timer:stop() < 1000 then
		return whileActive.Continue()
		
	else
		-- We are above the timer, lets stop this powerup.
		-- NOTE how we are not ending the effect(?) This will happen in onDeactivate()!
		return whileActive.Stop()
	end
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info) end

-- When a target was hit, only called on players spectating origin_id
M.onTargetHit = function(data, origin_id, target_id) end

-- When a target was hit, called on every client
M.onHit = function(data, origin_id, target_id) end

-- When the powerup has ended or is destroyed by any means
M.onDeactivate = function(data, origin_id)
	local vehicle = be:getObjectByID(origin_id)
	
	-- In the case the vehicle doesnt exists anymore we dont want todo anything for this powerup
	if vehicle == nil then return end
	
	-- Otherwise we are now going to end the effect
	vehicle:queueLuaCommand('PowerUpExtender.resetGrip()')
	
	-- And we stop the sound just in case its still running
	M.activate_sound:stopVE(origin_id)
	
	--[[
		Why now and not earlier in whileActive?
		Because not just whileActive decides when a powerup has to end. It could also be that this vehicle is removed by the player, or the mod unloaded or another active powerup abrupts it. Then this effect would never end!
		
		Or imagine it like this. You spawn projectiles into the world, now the vehicle is deleted, which causes this event to be called, but since your not cleaning it up here, now the projectiles stay in the world forever! BAD.
	]]
end

-- Render Distance related
M.onUnload = function(data) end

M.onLoad = function(data) end


return M
