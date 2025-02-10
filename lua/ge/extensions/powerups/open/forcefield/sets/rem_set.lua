local ForceField = require("libs/ForceField")

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"", {spectate = false}, "GE", 0, 1, ForceField.remVehicle, "ve_target"},
	
}

return set