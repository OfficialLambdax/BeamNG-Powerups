local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = true}, "GE", 0, 1, core_environment.setGravity, -1.62},
	{"", {spectate = true}, "GE", 2000, 1, core_environment.setGravity, -9.81},
}

return set