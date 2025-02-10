local jump_up = [[
	PowerUpExtender.addAngularVelocity(0, 0, 20, 0, 0, 0)
]]

local drop_down = [[
	PowerUpExtender.addAngularVelocity(0, 0, -40, 0, 0, 0)
]]


local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"", {spectate = false}, "VE", 0, 1, jump_up},
	{"", {spectate = false}, "VE", 500, 1, drop_down},
}

return set
