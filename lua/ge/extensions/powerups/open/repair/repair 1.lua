local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject = Extender.defaultPowerupVars()

local M = {
	-- Shown to the user
	clear_name = "Repair I",
	
	-- Turn true to not be affected by the render distance
	do_not_unload = false,
	
	-- Configure traits of this powerup
	-- {Trait.Consuming, Trait.Reflective}
	traits = {Trait.Ghosted},
	
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
	sounds = {},
	pot = Pot(),
}

-- Called once when the powerup is loaded
M.onInit = function(group_defs)
	local sounds = {
		-- file, volume, probability
		{"awhwhwhwww.ogg", 5, 1},
		{"hexhex.ogg", 4, 3},
		{"repairing.ogg", 4, 5},
	}
	
	for _, sound in ipairs(sounds) do
		local soundObj = Sound(M.file_path .. 'sounds/' .. sound[1], sound[2])
		if soundObj then
			M.sounds[sound[1]] = soundObj
			M.pot:add(sound[1], sound[3])
		end
	end
end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	local pos = vehicle:getPosition()
	local rot = Extender.getVehicleRotation(vehicle)
	vehicle:setPositionRotation(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
	
	Extender.ghostVehicleAutoUnghost(vehicle, 5000)
	
	return onActivate.TargetInfo(
		{played = false, origin_id = vehicle:getId()},
		{sound_name = M.pot:stir(5):surprise()}
	)
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	if data.played then return whileActive.Stop() end
	return whileActive.Continue()
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info)
	data.played = true
	
	local sound = M.sounds[target_info.sound_name]
	if sound then
		sound:smart(data.origin_id)
	end
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
