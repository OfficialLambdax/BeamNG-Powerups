local M = {}

M.Types = {
	--[[
		Will be applied directly on pickup. And cannot have active powerups
		
		Color code: White
	]]
	Charge = "charge",
	
	--[[
		Will be applied directly on pickup. Leveling doesnt matter. Always chooses a random active powerup.
		
		Color code: Black
	]]
	Negative = "negative",
	
	--[[
		Color code: Red
	]]
	Offensive = "offensive",
	
	--[[
		Color code: Blue
	]]
	Defensive = "defensive",
	
	--[[
		Color code: Purple
	]]
	Handicapping = "handicapping",
	
	--[[
		Color code: Green
	]]
	Utility = "utility",
	
	--[[
		Color code: none
	]]
	Undefined = "undefined"
}


return M