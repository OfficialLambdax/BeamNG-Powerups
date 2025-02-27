-- Game docs https://documentation.beamng.com/modding/input/actions/

local M = {}

-- For active powerups
local ActivePowerupHotkeys = {
	Fire = "onHKeyFire",
	TargetChange = "onHKeyTargetChange",
	--TargetAim = "onHKeyTargetAim", -- TODO
	
	Action1 = "onHKeyAction1",
	Action2 = "onHKeyAction2",
	Action3 = "onHKeyAction3",
	Action4 = "onHKeyAction4",
	Action5 = "onHKeyAction5",
}

local ActivePowerupHotkeyStates = {
	-- "runs when the controller position changes. Supports: keys/buttons and axes"
	--Change = 1, -- game bug. doesnt work when running together with the other events
	
	-- "runs when a key/button is pressed down. Supports: keys/buttons"
	Down = 2,
	
	-- "runs when a key/button is lifted up. Supports: keys/buttons"
	Up = 3,
	
	-- "runs when holding the right mouse button and moving the mouse (don’t use unless you know what you’re doing)"
	--Relative = 4,
}

-- For powerup groups
-- TODO
local PowerupHotKeys = {}

M.ActivePowerupHotkeys = ActivePowerupHotkeys
M.ActivePowerupHotkeyStates = ActivePowerupHotkeyStates
--M.PowerupHotKeys = PowerupHotKeys
return M
