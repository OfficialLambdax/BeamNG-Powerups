local Util = require("libs/Util")
local Extender = require("libs/PowerUpsExtender")

local length = 7
local jump_strength = 1.4
local jump = 'PowerUpExtender.jump(1.4)'
local step_this = 480
local color_1 = "1 1 1"
local color_2 = "1 0.5 1"
local color_3 = "0.5 1 0.5"


local function playSound(sound)
	if sound == nil then return end
	sound:play()
end

local function setRGB(color)
	scenetree["PostEffectCombinePassObject"]:setField("enableBlueShift", 0, 0.5)
	scenetree["PostEffectCombinePassObject"]:setField("blueShiftColor", 0, color)
end

local function disableRGB()
	scenetree["PostEffectCombinePassObject"]:setField("enableBlueShift", 0, 0)
	scenetree["PostEffectCombinePassObject"]:setField("blueShiftColor", 0, "0 0 0")
end

local function color(target_id, color)
	local vehicle = be:getObjectByID(target_id)
	if vehicle == nil then return end
	
	local spectator = core_camera:getPosition()
	local dist = Util.dist3d(vehicle:getPosition(), spectator)
	if dist > 30 then return
		disableRGB()
	end
	
	local strength = math.min((10 / dist) * (1 * 2), 1)

	scenetree["PostEffectCombinePassObject"]:setField("enableBlueShift", 0, strength)
	scenetree["PostEffectCombinePassObject"]:setField("blueShiftColor", 0, color)
end

local function onJump(target_id)
	local target_vehicle = be:getObjectByID(target_id)
	if target_vehicle == nil then return end
	
	for _, vehicle in ipairs(Extender.getAllVehicles()) do
		local dist = Util.dist3d(target_vehicle:getPosition(), vehicle:getPosition())
		if dist < 30 then
			local strength = math.min((10 / dist) * (jump_strength * 2), jump_strength)
			vehicle:queueLuaCommand('PowerUpExtender.jump(' .. strength .. ')')
		end
	end
end

local step_by = 0
local function step()
	step_by = step_by + step_this
	return step_by
end

local jump_step_by = 0
local function jumpStep()
	jump_step_by = jump_step_by + step_this
	return jump_step_by
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"sound", {spectate = true}, "GE", 0, 1, playSound},
}

for index = 1, length, 1 do
	table.insert(set, {"", {spectate = false}, "GE", jumpStep(), 1, onJump, 've_target'})
	table.insert(set, {"", {spectate = false}, "GE", jumpStep(), 1, onJump, 've_target'})
	table.insert(set, {"", {spectate = false}, "GE", step(), 1, color, 've_target', color_1})
	table.insert(set, {"", {spectate = false}, "GE", step(), 1, color, 've_target', color_2})
	table.insert(set, {"", {spectate = false}, "GE", jumpStep(), 1, onJump, 've_target'})
	table.insert(set, {"", {spectate = false}, "GE", jumpStep(), 1, onJump, 've_target'})
	table.insert(set, {"", {spectate = false}, "GE", step(), 1, color, 've_target', color_1})
	table.insert(set, {"", {spectate = false}, "GE", step(), 1, color, 've_target', color_2})
	table.insert(set, {"", {spectate = false}, "GE", jumpStep(), 1, onJump, 've_target'})
	table.insert(set, {"", {spectate = false}, "GE", jumpStep(), 1, onJump, 've_target'})
	table.insert(set, {"", {spectate = false}, "GE", step(), 1, color, 've_target', color_1})
	table.insert(set, {"", {spectate = false}, "GE", step(), 1, color, 've_target', color_3})
	table.insert(set, {"", {spectate = false}, "GE", jumpStep(), 1, onJump, 've_target'})
	table.insert(set, {"", {spectate = false}, "GE", jumpStep(), 1, onJump, 've_target'})
	table.insert(set, {"", {spectate = false}, "GE", step(), 1, color, 've_target', color_1})
	table.insert(set, {"", {spectate = false}, "GE", step(), 1, color, 've_target', color_3})
end
table.insert(set, {"", {spectate = false}, "GE", step(), 1, disableRGB})

return set