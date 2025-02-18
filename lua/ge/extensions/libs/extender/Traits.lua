--[[
	License: None
	Author: Neverless (discord: neverless.)
]]
local M = {}
local Traits = {
	--[[
		Defensive
		
		This powerup would like to reflect whatever it is hit with.
		Think of a canon ball trying to hit a shield but bouncing off or back. If you say this trait is strong enough to reflect the canonball then handle this trait.
	]]
	Reflective = "onReflective",
	
	--[[
		Defensive
		
		Same as "Reflective" but a stronger alternative. Eg a maxed shield that can withstand a super weapon.
	]]
	StrongReflective = "onStrongReflector",
	
	--[[
		Defensive
		
		This powerup would like to consume what it is hit with. Consume as in, a bullet that hit this vehicle should not do any damage but also not reflect to anything else.
	]]
	Consuming = "onConsuming",
	
	--[[
		Defensive
		
		Same but the stronger variant.
	]]
	StrongConsuming = "onStrongConsuming",
	
	
	--[[
		Defensive
		
		This powerup is ghosting the vehicle, it wants active powerups to pass right through it.
		You can still target this vehicle, but dont have it do any damage
	]]
	Ghosted = "onGhosted",
	
	--[[
		Defensive
		
		This powerup would like the vehicle to be ignored from other powerups target selecting.
		When your powerup chooses a target or the next target ignore this vehicle. If your active powerup has already chosen this target then dont ignore this vehicle. This is supposed to prevent the vehicle to become a new target, not from being already a target.
	]]
	Ignore = "onGhosted",
	
	--[[
		Offensive
		
		This powerup signals that it can be broken with an attack.
	]]
	Breaking = "onBreaking",
	
	--[[
		
		This powerup signals that it can be broken with a strong attack.
	]]
	StrongBreaking = "onStrongBreaking",
}


-- TODO
local TraitBounds = {
	[Traits.Reflective] = {},
	
	[Traits.StrongReflective] = {},
	
	[Traits.Consuming] = {},
	
	[Traits.StrongConsuming] = {},
	
	[Traits.Ghosted] = {},
	
	[Traits.Ignore] = {},
	
	[Traits.Breaking] = {},
	
	[Traits.StrongBreaking] = {},
}

--[[
local TraitResponses = {

}}
]]

M.Traits = Traits
M.TraitBounds = TraitBounds
return M