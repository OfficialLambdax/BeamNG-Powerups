local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = true}, "GE", 0, 1, core_camera.rotate_yaw_left, 1},
	{"", {spectate = true}, "GE", 1000, 1, core_camera.rotate_yaw_left, 0},
}

return set