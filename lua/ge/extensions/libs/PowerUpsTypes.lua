local M = {}

M.Types = {
	--[[
		Will be applied directly on pickup. And cannot have active powerups
	]]
	Charge = "charge",
	
	--[[
		Will be applied directly on pickup. Leveling doesnt matter. Always chooses a random active powerup.
	]]
	Negative = "negative",
	
	Offensive = "offensive",
	
	Defensive = "defensive",
	
	Handicapping = "handicapping",
	
	Utility = "utility",
	
	Undefined = "undefined"
}


return M