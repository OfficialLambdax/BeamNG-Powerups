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
	{"", {spectate = false}, "VE", 0, 1, spin .. 'spin(-2)'},
	{"", {spectate = false}, "VE", 10, 1, spin .. 'spin(-2)'},
	{"", {spectate = false}, "VE", 310, 1, spin .. 'spin(2)'},
	{"", {spectate = false}, "VE", 320, 1, spin .. 'spin(2)'},
	{"", {spectate = false}, "VE", 620, 1, spin .. 'spin(-2)'},
	{"", {spectate = false}, "VE", 630, 1, spin .. 'spin(-2)'},
	{"", {spectate = false}, "VE", 930, 1, spin .. 'spin(2)'},
	{"", {spectate = false}, "VE", 940, 1, spin .. 'spin(2)'},
	{"", {spectate = false}, "VE", 1240, 1, spin .. 'spin(-2)'},
	{"", {spectate = false}, "VE", 1250, 1, spin .. 'spin(-2)'},
	{"", {spectate = false}, "VE", 1550, 1, spin .. 'spin(2)'},
	{"", {spectate = false}, "VE", 1560, 1, spin .. 'spin(2)'},
	{"", {spectate = false}, "VE", 1860, 1, spin .. 'spin(-2)'},
	{"", {spectate = false}, "VE", 1870, 1, spin .. 'spin(-2)'},
	{"", {spectate = false}, "VE", 2170, 1, spin .. 'spin(2)'},
	{"", {spectate = false}, "VE", 2180, 1, spin .. 'spin(2)'},
	{"", {spectate = false}, "VE", 2480, 1, spin .. 'spin(-2)'},
	{"", {spectate = false}, "VE", 2490, 1, spin .. 'spin(-2)'},
	{"", {spectate = false}, "VE", 2790, 1, spin .. 'spin(2)'},
	{"", {spectate = false}, "VE", 2800, 1, spin .. 'spin(2)'},
	{"", {spectate = false}, "VE", 3100, 1, spin .. 'spin(-2)'},
	{"", {spectate = false}, "VE", 3110, 1, spin .. 'spin(-2)'},
	{"", {spectate = false}, "VE", 3410, 1, spin .. 'spin(2)'},
	{"", {spectate = false}, "VE", 3420, 1, spin .. 'spin(2)'}
}

return set