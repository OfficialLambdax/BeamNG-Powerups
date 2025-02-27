local Extender = require("libs/PowerUpsExtender")
local Lib, Util, Sets, Sound, MathUtil, Pot, Log, TimedTrigger, Collision, MPUtil, Timer, Particle, Sfx = Extender.defaultImports()
local Trait, Type, onActivate, whileActive, getAllVehicles, createObject, Hotkey, HKeyState, onHKey = Extender.defaultPowerupVars(1)

local M = {
	-- Shown to the user
	clear_name = "Sniper I",
	
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
	respects_traits = {Trait.Ignore},
	
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
	return onActivate.Success({
			possible_targets = {},
			selected_id = nil,
			is_valid_target = false,
			fire = false,
		}
	)
end

-- Hooked to the onPreRender tick
M.whileActive = function(data, origin_id, dt)
	local origin_vehicle = be:getObjectByID(origin_id)
	local veh_dir = origin_vehicle:getDirectionVector()
	local veh_pos = origin_vehicle:getPosition()
	local start_pos = MathUtil.getPosInFront(veh_pos, veh_dir, 2)
	
	local box_center = MathUtil.getPosInFront(veh_pos, veh_dir, 550)
	local box = MathUtil.createBox(box_center, veh_dir, 500, 20, 200)
	
	local targets = MathUtil.getVehiclesInsideBox(box, origin_id) or {}
	targets = Extender.cleanseTargetsWithTraits(targets, origin_id, Trait.Ignore)
	targets = Extender.cleanseTargetsBehindStatics(start_pos, targets)
	
	MathUtil.drawBox(box)
	
	data.possible_targets = targets
	
	if data.selected_id and Extender.isSpectating(origin_id) then
		local target_vehicle = be:getObjectByID(data.selected_id)
		if target_vehicle == nil then
			data.selected_id = nil
			return nil
		end
		
		data.is_valid_target = Util.tableContains(targets, data.selected_id)
		local color = ColorF(0,1,0,1)
		if not data.is_valid_target then
			color = ColorF(1,0,0,1)
		end
		
		local target_pos = target_vehicle:getSpawnWorldOOBB():getCenter()
		target_pos.z = target_pos.z + 2
		debugDrawer:drawSphere(target_pos, 1, color)
	end
	
	--print(data.is_valid_target)
	
	--local targets = MathUtil.getVehiclesInsideBox(box, origin_id) or {}
	--targets = Extender.cleanseTargetsBehindStatics(start_pos, targets)
	
	return whileActive.Continue()
end

-- When the powerup selected one or multiple targets or just shared target_info
M.onTargetSelect = function(data, target_info) end

-- When a target was hit, only called on players spectating origin_id
M.onTargetHit = function(data, origin_id, target_id) end

-- When a target was hit, called on every client
M.onHit = function(data, origin_id, target_id) end

-- When the powerup has ended or is destroyed by any means
M.onDeactivate = function(data, origin_id) end

-- Render Distance related
M.onUnload = function(data) end

M.onLoad = function(data) end

M[Hotkey.TargetChange] = function(data, state)
	if state ~= HKeyState.Down then return end
	data.selected_id = Extender.targetChange(data.possible_targets, data.selected_id)
end

M[Hotkey.Fire] = function(data, state)
	if state ~= HKeyState.Down then return end
	
	
end

return M
