local Particle = require("libs/Particles")
local MathUtil = require("libs/MathUtil")

local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local function spawnConfetti(target_id)
	local vehicle = getObjectByID(target_id)
	if vehicle == nil then return end
	
	Particle("BNGP_confetti", vehicle:getPosition())
		:active(true)
		:velocity(5)
		:followC(vehicle, 1000,
			function(self, obj, emitter)
				local veh_dir = obj:getDirectionVector()
				if veh_dir == nil then return end
				
				local veh_pos = obj:getPosition()
				local new_pos = MathUtil.getPosInFront(veh_pos, veh_dir, 3)
				
				self:setPosition(new_pos)
			end
		)
		:selfDisable(1000)
		:selfDestruct(5000)
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = false}, "GE", 0, 1, spawnConfetti, 've_target'},
	{"", {spectate = false}, "VE", 0, 1, 'PowerUpExtender.pushForward(-10)'},
}

return set