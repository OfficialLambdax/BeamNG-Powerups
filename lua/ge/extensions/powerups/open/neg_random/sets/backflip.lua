local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local backflip = [[
	local backflip = function(strength)
		local right_dir = obj:getDirectionVectorRight():normalized() * strength
		PowerUpExtender.addAngularVelocity(0, 0, 0, right_dir.x, right_dir.y, right_dir.z)
	end;
]]

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = false}, "VE", 0, 1, 'PowerUpExtender.jump(10)'},
	{"", {spectate = false}, "VE", 500, 1, backflip .. 'backflip(-4.5)'}
}

return set