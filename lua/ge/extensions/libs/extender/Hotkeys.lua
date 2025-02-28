-- Game docs https://documentation.beamng.com/modding/input/actions/
local Log = require("libs/Log")

local M = {}
M.BIND_FILE_PATH = 'lua/ge/extensions/core/input/actions/powerup_mod.json'
M.BINDINGS = {} -- {"event" = title}

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

M.resolveClearName = function(event_name)
	return M.BINDINGS[event_name]
end


local function init()
	local handle = io.open(M.BIND_FILE_PATH, 'r')
	if handle == nil then
		Log.error('Cannot open bindings file in read mode @ "' .. M.BIND_FILE_PATH .. '"')
		return
	end
	
	local bindings = handle:read("*all")
	handle:close()
	
	bindings = jsonDecode(bindings)
	if bindings == nil then
		Log.error('Cannot decode bindings')
		return
	end
	
	for _, hkey in pairs(bindings) do
		local internal_name = hkey.internal_name
		if internal_name and internal_name:len() > 0 then
			M.BINDINGS[internal_name] = hkey.title
		end
	end
end

M.ActivePowerupHotkeys = ActivePowerupHotkeys
M.ActivePowerupHotkeyStates = ActivePowerupHotkeyStates

init()
return M
