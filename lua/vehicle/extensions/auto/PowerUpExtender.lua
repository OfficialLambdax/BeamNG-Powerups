local M = {}

M.jump = function(strength)
	obj:applyClusterLinearAngularAccel(
		v.data.refNodes[0].ref,
		vec3(0, 0, strength) * obj:getPhysicsFPS(),
		vec3(0, 0, 0)
	)
end

M.pushForward = function(strength)
	local direction = vec3(obj:getDirectionVector():normalized()) * strength
	M.addAngularVelocity(direction.x, direction.y, direction.z, 0, 0, 0)
end

M.addAngularVelocity = function(x, y, z, pitchAV, rollAV, yawAV)
	local refNode = v.data.refNodes[0].ref
	local rot = quatFromDir(-vec3(obj:getDirectionVector()), vec3(obj:getDirectionVectorUp()))
	local cog = (vec3(0, 0 ,0)):rotated(rot)
	
	local vel = vec3(x, y, z) - cog:cross(vec3(pitchAV, rollAV, yawAV))
	local physicsFPS = obj:getPhysicsFPS()
	local velMulti = 1
			
	obj:applyClusterLinearAngularAccel(
		refNode,
		vel * physicsFPS * velMulti,
		-vec3(pitchAV, rollAV, yawAV) * physicsFPS
	)
end

M.setGrip = function(grip_level)
	for _, wheel in ipairs(wheels.wheels) do
		wheel.obj:setFrictionThermalSensitivity(
					-300,
					1e7,
					1e-10,
					1e-10,
					10,
					grip_level,
					grip_level,
					grip_level
		)
	end
end

M.resetGrip = function()
	M.setGrip(1)
end

local function init()
	obj:queueGameEngineLua("onPowerUpVehicleInit("..obj:getID()..")")
end

init()
return M
