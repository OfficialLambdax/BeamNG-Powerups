local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = false}, "VE", 0, 1, 'electrics.horn(true)'},
	{"", {spectate = false}, "VE", 1000, 1, 'electrics.horn(false)'},
}

return set