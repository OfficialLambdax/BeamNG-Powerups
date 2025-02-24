local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local function setRGB(color)
	scenetree["PostEffectCombinePassObject"]:setField("enableBlueShift", 0, 1)
	scenetree["PostEffectCombinePassObject"]:setField("blueShiftColor", 0, color)
end

local function disableRGB()
	scenetree["PostEffectCombinePassObject"]:setField("enableBlueShift", 0, 0)
	scenetree["PostEffectCombinePassObject"]:setField("blueShiftColor", 0, "0 0 0")
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = true}, "GE", 0, 1, setRGB, '0 0 0'},
	{"", {spectate = true}, "GE", 6500, 1, disableRGB},
}

return set