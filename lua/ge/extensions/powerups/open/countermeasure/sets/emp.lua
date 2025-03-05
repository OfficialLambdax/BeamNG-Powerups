
local start = [[
	for name, filled in pairs(energyStorage.getStorages()) do
		energyStorage.getStorage(name):setRemainingRatio(0)
	end
	electrics.setIgnitionLevel(0)
	input.event("brake", 1, "FILTER_AI")
]]

local stop = [[
	for name, filled in pairs(energyStorage.getStorages()) do
		energyStorage.getStorage(name):setRemainingRatio(1)
	end
	electrics.setIgnitionLevel(3)
	input.event("brake", 0, "FILTER_AI")
]]

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"", {spectate = false}, "VE", 500, 1, start},
	{"", {spectate = false}, "VE", 6000, 1, stop},
}

return set
