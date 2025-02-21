local Particle = require("libs/Particles")

local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local function spawnTrail(target_id)
	local vehicle = be:getObjectByID(target_id)
	if vehicle == nil then return end
	
	Particle("BNGP_Fire_Huge", vehicle:getPosition())
		:velocity(-20)
		:active(true)
		:follow(vehicle, 5000)
		:selfDisable(5000)
		:selfDestruct(10000)
		
	Particle("BNGP_confetti", vehicle:getPosition())
		:velocity(-5)
		:active(true)
		:follow(vehicle, 5000)
		:selfDisable(5000)
		:selfDestruct(10000)
end

local function spawnMini(target_id)
	local vehicle = be:getObjectByID(target_id)
	if vehicle == nil then return end
	
	Particle("BNGP_29", vehicle:getPosition())
		:velocity(-5)
		:active(true)
		:follow(vehicle, 200)
		:selfDisable(200)
		:selfDestruct(10000)
end

local function finalSmoke(target_id)
	local vehicle = be:getObjectByID(target_id)
	if vehicle == nil then return end
	
	Particle("BNGP_32", vehicle:getPosition())
		:active(true)
		:follow(vehicle, 2000)
		:selfDisable(2000)
		:selfDestruct(15000)
end

-- Credits to Olrosse
local explosion = [[
	local explode = function(strength)
		local strength = strength or 1
		
		beamstate.breakAllBreakgroups()
		
		for _, coupler in pairs(controller.getControllersByType("advancedCouplerControl")) do
			coupler.detachGroup()
		end
		
		for _, beam in pairs(v.data.beams) do
			if beam.deformSwitches then
				material.switchBrokenMaterial(beam)
			end
		end
		
		for _, device in pairs(powertrain.getDevices()) do
			if device.onBreak then
				device:onBreak()
			end
		end
		
		local cog = vec3(0, 0, 0)
		local total_mass = 0
		for _, node in pairs(v.data.nodes) do
			local mass = obj:getNodeMass(node.cid)
			cog = cog + (node.pos * mass)
			total_mass = total_mass + mass
		end
		cog = cog / total_mass
		
		local rot = quat(obj:getRotation())
		for _, node in pairs(v.data.nodes) do
			local dir = (node.pos - cog):rotated(rot):normalized()
			obj:applyForceVector(node.cid, dir * 50000 * node.nodeWeight * strength)
		end
		
		local direction = obj:getDirectionVectorUp()
		direction.z = direction.z + 2
		obj:applyClusterLinearAngularAccel(0, direction * 5000 * strength, vec3(0, 0, 0))
	end;
]]

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = true}, "GE", 0, 1, core_camera.cameraZoom, 0.01},
	{"", {spectate = false}, "VE", 0, 1, "PowerUpExtender.jump(80)"},
	{"", {spectate = false}, "GE", 0, 1, spawnTrail, 've_target'},
	{"", {spectate = false}, "GE", 1800, 1, spawnMini, 've_target'},
	{"", {spectate = false}, "GE", 2400, 1, spawnMini, 've_target'},
	{"", {spectate = false}, "GE", 2800, 1, spawnMini, 've_target'},
	--{"", {spectate = false}, "GE", 3200, 1, spawnMini, 've_target'},
	--{"", {spectate = false}, "GE", 3600, 1, spawnMini, 've_target'},
	{"", {spectate = false}, "GE", 4800, 1, spawnMini, 've_target'},
	{"", {spectate = false}, "VE", 7000, 1, "fire.explodeVehicle()"},
	{"", {spectate = false}, "VE", 7060, 1, explosion .. 'explode(1.2)'},
	{"", {spectate = false}, "GE", 7200, 1, spawnMini, 've_target'},
	{"", {spectate = false}, "GE", 7460, 1, finalSmoke, 've_target'},
}

return set