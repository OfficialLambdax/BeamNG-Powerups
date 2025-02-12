local function playSound(game_vehicle_id, sound_name)
	be:getObjectByID(game_vehicle_id):queueLuaCommand('PowerUpSounds.playSound("' .. sound_name .. '")')
end

local function launch(game_vehicle_id)
	local vehicle = be:getObjectByID(game_vehicle_id)
	if vehicle == nil then return end
	
	local towards = vehicle:getDirectionVector():normalized() + vec3(0, 0, 20)
	vehicle:applyClusterVelocityScaleAdd(vehicle:getRefNodeId(), 1, towards.x, towards.y, towards.z)
end

local function launchForward(game_vehicle_id)
	local vehicle = be:getObjectByID(game_vehicle_id)
	if vehicle == nil then return end
	
	local towards = vehicle:getDirectionVector():normalized() * 7
	vehicle:applyClusterVelocityScaleAdd(vehicle:getRefNodeId(), 1, towards.x, towards.y, towards.z)
end

local function throwUp(game_vehicle_id)
	local vehicle = be:getObjectByID(game_vehicle_id)
	if vehicle == nil then return end

	local towards = vehicle:getDirectionVector():normalized() + vec3(0, 0, 100)
	vehicle:applyClusterVelocityScaleAdd(vehicle:getRefNodeId(), 1, towards.x, towards.y, towards.z)
end

local function initScreenFade()
	--scenetree["PostEffectCombinePassObject"]:setField("enableBlueShift", 0, 1)
	--scenetree["PostEffectCombinePassObject"]:setField("blueShiftColor", 0, "0 0 0")
	
	ui_fadeScreen.start()
end

local function tpSafe(game_vehicle_id)
	local vehicle = be:getObjectByID(game_vehicle_id)
	if vehicle == nil then return end
	
	local veh_pos = vehicle:getPosition()
	local pos_dir = gameplay_traffic_trafficUtils.findSafeSpawnPoint(veh_pos, nil, 500, 700, 500)
	local pos, rot = gameplay_traffic_trafficUtils.finalizeSpawnPoint(pos_dir.pos, pos_dir.dir, pos_dir.n1, pos_dir.n2, {legalDirection = false})
	
	-- teleport
	rot = quatFromDir(rot, map.surfaceNormal(pos))
	spawn.safeTeleport(vehicle, pos, rot, true, nil, false)
end

local function remScreenFade()
	--scenetree["PostEffectCombinePassObject"]:setField("enableBlueShift", 0, 0)
	--scenetree["PostEffectCombinePassObject"]:setField("blueShiftColor", 0, "0 0 0")
	
	ui_fadeScreen.stop()
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = false}, "GE", 0, 1, playSound, 've_target'},
	{"", {spectate = false}, "GE", 100, 1, launch, 've_target'},
	{"", {spectate = false}, "GE", 200, 2, launchForward, 've_target'},
	{"", {spectate = true}, "GE", 100, 1, initScreenFade},
	{"", {spectate = false}, "GE", 1500, 1, throwUp, 've_target'},
	{"tp", {spectate = false}, "GE", 2000, 1, tpSafe, 've_target'},
	{"", {spectate = true}, "GE", 2000, 1, remScreenFade},
}

return set