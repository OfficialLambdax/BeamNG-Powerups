local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = true}, "GE", 0, 1, core_camera.setVehicleCameraByIndexOffset, 0, 1}
}

return set