local Particle = require("libs/Particles")

local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local function spawnConfetti(target_id)
	local vehicle = be:getObjectByID(target_id)
	if vehicle == nil then return end
	
	Particle("BNGP_confetti", vehicle:getPosition())
		:active(true)
		:follow(vehicle, 1000)
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