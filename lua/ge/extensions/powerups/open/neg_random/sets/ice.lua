local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = false}, "VE", 0, 1, 'PowerUpExtender.setGrip(0.1)'},
	{"", {spectate = false}, "VE", 5000, 1, 'PowerUpExtender.resetGrip()'},
}

return set