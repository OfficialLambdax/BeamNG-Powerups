local function playSound(sound)
	if sound == nil then return end
	sound:play()
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
	{"", {spectate = false}, "VE", 7000, 1, "fire.explodeVehicle()"},
	{"", {spectate = false}, "VE", 7060, 1, explosion .. 'explode(1.2)'},
}

return set