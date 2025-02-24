local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local jump = [[
	PowerUpExtender.addAngularVelocity(0, 0, 10, 0, 0, 0)
]]

local roll_1 = [[
	local newPosition = obj:getDirectionVector():normalized() * -7.5
	PowerUpExtender.addAngularVelocity(0, 0, 0, newPosition.x, newPosition.y, newPosition.z)
]]

local roll_2 = [[
	local newPosition = obj:getDirectionVector():normalized() * 5
	PowerUpExtender.addAngularVelocity(0, 0, 0, newPosition.x, newPosition.y, newPosition.z)
]]


local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
	{"", {spectate = false}, "VE", 0, 1, jump},
	{"", {spectate = false}, "VE", 500, 1, roll_1},
	{"", {spectate = false}, "VE", 700, 1, roll_2},
}

return set
