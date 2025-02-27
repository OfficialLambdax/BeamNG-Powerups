local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject = Extender.defaultPowerupVars()

local M = {
	-- Shown to the user
	clear_name = "Invinsible",
	
	-- Turn true to not be affected by the render distance
	do_not_unload = false,
	
	-- Configure traits of this powerup
	-- {Trait.Consuming, Trait.Reflective}
	traits = {Trait.Ignore},
	
	-- Must match the libs version name. If it doesnt, this powerup group is considered out of date
	-- dump(Lib.getLibVersion())
	lib_version = "enums",
	
	-- Server related below
	
	-- Define the maximum length this powerup is active. The server will end it after this time.
	max_len = 10000,
	
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
	if MPUtil.isBeamMPSession() then
		-- disable nametag of this vehicle.
		-- todo
		-- someone removed the api in beammp todo that omg
	end
	return onActivate.Success({timer = Timer.new()})
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	if data.timer:stop() < M.max_len then
		local origin_vehicle = be:getObjectByID(origin_id)
		if Extender.isSpectating(origin_id) then
			origin_vehicle:setMeshAlpha(0.5, "", false)
		else
			origin_vehicle:setMeshAlpha(0, "", false)
		end
		
		return whileActive.Continue()
	end
	
	return whileActive.Stop()
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info) end

-- When a target was hit, only called on players spectating origin_id
M.onTargetHit = function(data, origin_id, target_id) end

-- When a target was hit, called on every client
M.onHit = function(data, origin_id, target_id) end

-- When the powerup has ended or is destroyed by any means
M.onDeactivate = function(data, origin_id)
	local origin_vehicle = be:getObjectByID(origin_id)
	if origin_vehicle == nil then return end
	
	origin_vehicle:setMeshAlpha(1, "", false)
	
	if MPUtil.isBeamMPSession() then
		-- reenable nametag of this vehicle
		-- todo
	end
end

-- Render Distance related
M.onUnload = function(data) end

M.onLoad = function(data) end

M[Trait.Ignore] = function() end

return M
