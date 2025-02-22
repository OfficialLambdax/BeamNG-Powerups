local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject = Extender.defaultPowerupVars()

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
	max_len = 20000,
	
	-- TODO
	target_info_descriptor = nil,
	
	-- Configure traits this powerup respects. Required for trait call sync
	respects_traits = {},
	
	-- Auto filled
	-- Contains the dir path to this powerup
	file_path = "",
	
	-- Add extra variables here if needed. Constants only!
	sets = {}, -- [1..n] = {name = name, sound = Sound, delay = time}
	--test = "backwards"
}

-- Called once when the powerup is loaded
M.onInit = function(group_defs)
	-- PowerUps.sets.loadSet("lua/ge/extensions/powerups/open/neg_random/sets/explosion_simple.lua", "test"); PowerUps.sets.getSet("test"):this():exec()
	local try_sets = {
		-- set filenname, sound filename, set delay if sound takes a bit, volume if needed
		{"explosion_simple", "fbi_open_up.mp3", 2600},
		{"ice", "ice_ice_baby.mp3", 0, 5},
		{"moveit", "move_it.mp3", 100, 5},
		{"flashbang", "flashbang.mp3", 2000},
		{"spin", "spin_me_right_round.mp3", 300},
		{"disco", "bad_lil_kiddies.ogg"},
		{"backflip", "do_a_flip.ogg", 5200},
		{"backwards", "burp.ogg", 200, 1},
		{"blind", "legally_blind.ogg", 1000, 5},
		{"jinxed", "gorillaz.ogg", 2600},
		{"change_camera", "underwater_poop.ogg", nil, 2},
		{"explosion_cool", "big_bang.ogg", 8000, 5},
		{"barrelroll_multi", "barrelroll_multi.ogg", 500},
		{"clutch", nil},
		{"gravity_moon", nil},
		{"handbrake", nil},
		{"horn", nil},
		{"ignition", nil},
		{"lights_toggle", nil},
		{"lookback_short", nil},
		{"rotatecam_short", nil},
		{"small_jump", nil},
		{"steer_right", nil},
		{"warning_signal", nil},
		{"barrelroll", nil},
	}
	
	for _, set in ipairs(try_sets) do
		if not Sets.loadSet(M.file_path .. 'sets/' .. set[1] .. '.lua', set[1]) then
			Log.error('Cannot load set file for "' .. set[1] .. '"')
		else
			
			local sound = nil
			if set[2] then
				sound = Sound(M.file_path .. 'sounds/' .. set[2], set[4] or 3)
				if sound == nil then
					Log.error('Cannot load sound for "' .. set[1] .. '"')
				end
			end
			
			table.insert(M.sets, {
				name = set[1],
				sound = sound,
				delay = set[3] or 0
			})
		end
	end
end

-- Called every time a vehicle is spawned or reloaded
M.onVehicleInit = function(game_vehicle_id) end

-- Called once the powerup is activated by a vehicle
-- Vehicle = game vehicle
M.onActivate = function(vehicle)
	local _, set_def = Util.tablePickRandom(M.sets)
	if set_def == nil then
		return onActivate.Error('There are no sets available')
	end
	
	if M.test then
		for _, set in ipairs(M.sets) do
			if set.name == M.test then
				set_def = set
				break
			end
		end
	end
	
	return onActivate.TargetInfo({}, {set_name = set_def.name})
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	if not data.set_name then return whileActive.Continue() end
	
	if not data.running then
		local set_def
		for _, set in ipairs(M.sets) do
			if set.name == data.set_name then
				set_def = set
				break
			end
		end
		if not set_def then return whileActive.Stop() end
		
		local set = Sets.getSet(set_def.name):delayAll(set_def.delay):VETarget(origin_id)
		
		if Extender.isSpectating(origin_id) then
			set:resetBlock(2000)
		end
		
		if set_def.sound then set_def.sound:smart(origin_id) end
		
		set:exec()
		
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
	data.set_name = target_info.set_name
	Log.info('Selected "' .. data.set_name .. '"')
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
