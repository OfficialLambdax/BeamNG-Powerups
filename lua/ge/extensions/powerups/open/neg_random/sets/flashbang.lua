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
	{"", {spectate = true}, "GE", 0, 1, setRGB, "86 86 86"},
	{"", {spectate = true}, "GE", 500, 1, setRGB, "64 64 64"},
	{"", {spectate = true}, "GE", 1000, 1, setRGB, "32 32 32"},
	{"", {spectate = true}, "GE", 2000, 1, disableRGB},
}

return set