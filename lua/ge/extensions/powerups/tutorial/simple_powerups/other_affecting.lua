local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles = Extender.defaultPowerupVars()

--[[
	In this powerup we are going to put all close cars on ice for 5 seconds!
	But we are going to ignore vehicles that have an active powerup with the Consuming trait
]]

local M = {
	-- Shown to the user
	clear_name = "Freeze",
	
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
	respects_traits = {Trait.Consuming},
	
	-- Auto filled
	-- Contains the dir path to this powerup
	file_path = "",
	
	-- Add extra variables here if needed. Constants only!
	activate_sound = nil,
}

-- Called once when the powerup is loaded
M.onInit = function(group_defs)
	-- Lets initialize a sound!
	M.activate_sound = Sound(M.file_path .. 'sounds/freezing.ogg')
end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	-- The mathlib provides a function to get all vehicles in a radius to us, but we need to prepare a few variables
	local position = vehicle:getPosition() -- our position
	local radius = 10
	local origin_id = vehicle:getId()
	
	-- From our position, in a 10 meter radius get all vehicles, except our vehicle!
	local target_vehicles = MathUtil.getVehiclesInsideRadius(position, radius, origin_id)
	
	-- Now we have all targets in our close proximity. But dont apply any effect on them yet!
	-- We will do that in onHit! This is required for synchronization. So for now all we do is to return the targets
	
	-- Returning the TargetHits enum will trigger the onHit event on every given vehicle to be called and then afterwards the onDeactivate event
	-- table format [1..n] = game_vehicle_id
	--           eg {123, 456, 789}
	-- Dont worry about returning an empty table!
	return onActivate.TargetHits(target_vehicles)
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt) end -- WILL NOT BE CALLED IN THIS POWERUP SETUP

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info) end

-- When a target was hit, only called on players spectating origin_id
M.onTargetHit = function(data, origin_id, target_id) end

-- When a target was hit, called on every client
M.onHit = function(data, origin_id, target_id)
	-- We want out effect to not be applied to vehicles that have a active powerup with either the consuming or strong consuming trait
	if Extender.hasTrait(target_id, Trait.Consuming) then
		
		-- If it does then we call it, to let that powerup know about this interaction
		-- That for example allows the powerup to play sounds. eg a bullet hitting a shield sound
		Extender.callTrait(target_id, Trait.Consuming, origin_id)
		return
	end
	
	-- What we just did can also be simplified like this
	if Extender.hasTraitCall(target_id, Trait.Consuming, origin_id) then return end
	
	-- lets apply the freezing effect on this target by reducing the grip to a minimum
	local vehicle = be:getObjectByID(target_id)
	vehicle:queueLuaCommand('PowerUpExtender.setGrip(0.5)')
	
	-- then we play our freezing sound on that vehicle
	M.activate_sound:playVE(target_id)
	
	-- and since we cant wait for the effect to end before we quit our powerup, lets keep it simple and create a simple timer that unfreezes the car for us!
	
	-- Choose a unique trigger name because we could accidentially overwrite another!
	local trigger_name = Util.randomName()
	local trigger_in = 5000
	local trigger_once = 1
	local trigger_code = 'PowerUpExtender.resetGrip()'
	
	-- This will execute in 5 seconds (:
	TimedTrigger.newVE(
		trigger_name,
		target_id,
		trigger_in,
		trigger_once,
		trigger_code
	)
end

-- When the powerup has ended or is destroyed by any means
M.onDeactivate = function(data, origin_id) end

-- Render Distance related
M.onUnload = function(data) end

M.onLoad = function(data) end


return M
