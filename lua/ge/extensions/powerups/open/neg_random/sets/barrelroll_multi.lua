local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local roll = [[
	local roll = function(strength)
		local new_position = obj:getDirectionVector():normalized() * strength
		PowerUpExtender.addAngularVelocity(0, 0, 0, new_position.x, new_position.y, new_position.z)
	end;
]]

local step_by = 0
local function step(small)
	if small then
		step_by = step_by + 300
	else
		step_by = step_by + 700
	end
	return step_by
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = false}, "VE", 0, 1, "PowerUpExtender.jump(60)"},
	{"", {spectate = false}, "VE", step(), 1, roll .. 'roll(-7.5)'},
	{"", {spectate = false}, "VE", step(true), 1, roll .. 'roll(5)'},
	{"", {spectate = false}, "VE", step(), 1, roll .. 'roll(-7.5)'},
	{"", {spectate = false}, "VE", step(true), 1, roll .. 'roll(5)'},
	--{"", {spectate = false}, "VE", step_by, 1, jump},
	{"", {spectate = false}, "VE", step(), 1, roll .. 'roll(-7.5)'},
	{"", {spectate = false}, "VE", step(true), 1, roll .. 'roll(5)'},
	{"", {spectate = false}, "VE", step(), 1, roll .. 'roll(-7.5)'},
	{"", {spectate = false}, "VE", step(true), 1, roll .. 'roll(5)'},
	--{"", {spectate = false}, "VE", step_by, 1, jump},
	{"", {spectate = false}, "VE", step(), 1, roll .. 'roll(-7.5)'},
	{"", {spectate = false}, "VE", step(true), 1, roll .. 'roll(5)'},
	{"", {spectate = false}, "VE", step(), 1, roll .. 'roll(-7.5)'},
	{"", {spectate = false}, "VE", step(true), 1, roll .. 'roll(5)'},
	--{"", {spectate = false}, "VE", step_by, 1, jump},
	{"", {spectate = false}, "VE", step(), 1, roll .. 'roll(-7.5)'},
	{"", {spectate = false}, "VE", step(true), 1, roll .. 'roll(5)'},
	{"", {spectate = false}, "VE", step(), 1, roll .. 'roll(-7.5)'},
	{"", {spectate = false}, "VE", step(true), 1, roll .. 'roll(5)'},
	--{"", {spectate = false}, "VE", step_by, 1, jump},
	{"", {spectate = false}, "VE", step(), 1, roll .. 'roll(-7.5)'},
	{"", {spectate = false}, "VE", step(true), 1, roll .. 'roll(5)'},
	{"", {spectate = false}, "VE", step(), 1, roll .. 'roll(-7.5)'},
	{"", {spectate = false}, "VE", step(true), 1, roll .. 'roll(5)'},
}

return set
