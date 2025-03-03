local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx, Placeable = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

--[[
	Quite alot of negative effects have been inspired by JulianStaps StreamerVsChat mod!
	https://github.com/SaltySnail/BeamMP-StreamersVsChat
	
	Check him out on twitch!
	https://www.twitch.tv/julianstap
]]

local M = {
	-- Shown to the user
	clear_name = "????",
	
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
	sets = {}, -- [1..n] = ~
	pot = Pot(),
	--test = "backwards",
}

-- Called once when the powerup is loaded
M.onInit = function(group_defs)
	package.loaded[M.file_path .. 'defs/all'] = nil -- required to reload
	local randoms = require(M.file_path .. 'defs/all')
	for _, set_def in ipairs(randoms) do
		if set_def.file ~= nil then
			Sets.loadSet(M.file_path .. 'sets/' .. set_def.file .. '.lua', set_def.file)
			if set_def.sound then
				set_def.sound = Sound('art/sounds/ext/neg_random/' .. set_def.sound, set_def.volume)
			end
			
			M.sets[set_def.file] = set_def
			M.pot:add(set_def, set_def.probability)
		end
	end
end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	local set_def = M.sets[M.test] or M.pot:stir(5):surprise()
	if set_def == nil then return onActivate.Error('There are no sets available') end
	
	return onActivate.TargetInfo({}, {file = set_def.file})
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	if data.set_def == nil then return whileActive.Continue() end
	
	if not data.running then
		local set_def = data.set_def
		local set = Sets.getSet(set_def.file):VETarget(origin_id)
		if set == nil then return whileActive.Stop() end
		
		if set_def.delay then set:delayAll(set_def.delay) end
		if set_def.block_reset and Extender.isSpectating(origin_id) then set:resetBlock(2000) end
		if set_def.ghost then set:ghost(2000) end
		set:exec()
		
		if set_def.sound then
			if Extender.isSpectating(origin_id) then
				set_def.sound:play()
				
			else
				local origin_vehicle = be:getObjectByID(origin_id)
				Sfx(set_def.sound:getFilePath(), origin_vehicle:getPosition())
					:minDistance(set_def.minDistance)
					:maxDistance(set_def.maxDistance)
					:is3D(true)
					:volume(1)
					:follow(origin_vehicle, 30000)
					:selfDestruct(30000)
					:spawn()
			end
		end
		
		data.running = true
		data.timer = Timer.new()
		data.len = set:maxTime()
		
	elseif data.timer:stop() < data.len then
		return whileActive.Continue()
		
	else
		return whileActive.Stop()
	end
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info)
	local set_def = M.sets[target_info.file]
	if set_def == nil then return end
	
	data.set_def = set_def
	Log.info('Selected "' .. set_def.file .. '"')
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
