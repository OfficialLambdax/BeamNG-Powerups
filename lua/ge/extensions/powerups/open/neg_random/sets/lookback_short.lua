local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local function lookback(state)
	if state then
		core_camera.setLookBack(nil, true)
	else
		core_camera.setLookBack(nil, false)
	end
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = true}, "GE", 0, 1, lookback, true},
	{"", {spectate = true}, "GE", 1000, 1, lookback, false},
}

return set