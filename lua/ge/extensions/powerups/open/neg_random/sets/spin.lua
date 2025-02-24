local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local spin = [[
	local spin = function(strength)
		local up_dir = obj:getDirectionVectorUp():normalized() * strength
		PowerUpExtender.addAngularVelocity(0, 0, 0, up_dir.x, up_dir.y, up_dir.z)
	end;
]]

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = false}, "VE", 0, 1, spin .. 'spin(10)'}
}

return set