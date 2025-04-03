local Particle = require("libs/Particles")
local MathUtil = require("libs/MathUtil")

local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local function routine(target_id)
	local vehicle = getObjectByID(target_id)
	if vehicle == nil then return end
	
	Particle("BNGP_18", vehicle:getPosition())
		:active(true)
		:velocity(3)
		:followC(vehicle, 10000,
			function(self, obj, emitter)
				local veh_dir = obj:getDirectionVector()
				if veh_dir == nil then return end
				
				local veh_pos = obj:getSpawnWorldOOBB():getCenter()
				local new_pos = MathUtil.getPosInFront(veh_pos, veh_dir, -3)
				
				self:velocity(self:getVelocity() + 0.01)
				self:setPosition(new_pos)
				obj:queueLuaCommand('PowerUpExtender.pushForward(0.05)')
			end
		)
		:selfDisable(10000)
		:selfDestruct(15000)
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = false}, "GE", 0, 1, routine, 've_target'},
}

return set