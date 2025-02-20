local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = false}, "VE", 0, 1, 'input.event("clutch", 1, "FILTER_AI")'},
	{"", {spectate = false}, "VE", 2000, 1, 'input.event("clutch", 0, "FILTER_AI")'},
}

return set