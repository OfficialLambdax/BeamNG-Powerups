local Particle = require("libs/Particles")
local MathUtil = require("libs/MathUtil")

local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local function spawnConfetti(target_id, time)
	local vehicle = be:getObjectByID(target_id)
	if vehicle == nil then return end
	
	Particle("BNGP_confetti", vehicle:getPosition())
		:active(true)
		:velocity(3)
		:followC(vehicle, time,
			function(self, obj, emitter)
				local veh_dir = obj:getDirectionVector()
				if veh_dir == nil then return end
				
				local veh_pos = obj:getPosition()
				local new_pos = MathUtil.getPosInFront(veh_pos, veh_dir, 3)
				
				self:setPosition(new_pos)
			end
		)
		:selfDisable(time - 50)
		:selfDestruct(5000)
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = false}, "GE", 0, 1, spawnConfetti, 've_target', 300},
	{"", {spectate = false}, "VE", 0, 1, 'PowerUpExtender.pushForward(-6)'},
	{"", {spectate = false}, "GE", 1510, 1, spawnConfetti, 've_target', 300},
	{"", {spectate = false}, "VE", 1510, 1, 'PowerUpExtender.pushForward(-8)'},
	{"", {spectate = false}, "GE", 4200, 1, spawnConfetti, 've_target', 700},
	{"", {spectate = false}, "VE", 4200, 1, 'PowerUpExtender.pushForward(-20)'},
}

return set