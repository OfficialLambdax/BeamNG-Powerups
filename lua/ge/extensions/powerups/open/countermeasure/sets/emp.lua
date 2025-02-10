
local empty = [[
	for name, filled in pairs(energyStorage.getStorages()) do
		energyStorage.getStorage(name):setRemainingRatio(0)
	end
]]

local refill = [[
	for name, filled in pairs(energyStorage.getStorages()) do
		energyStorage.getStorage(name):setRemainingRatio(1)
	end
]]


local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"", {spectate = false}, "VE", 500, 1, empty},
	{"", {spectate = false}, "VE", 6000, 1, refill},
}

return set
