-- BeamMP Server only
-- WIP

-- lua reset all includes of this script, to guarantee a full reload
if SCRIPT_LOADED == nil then -- this block runs when the this script is loaded for the first time
	SCRIPT_LOADED = true
	SCRIPT_EXCEPTIONS = {}
	SCRIPT_HOTRELOADED = false
	for k, _ in pairs(package.loaded) do SCRIPT_EXCEPTIONS[k] = true end
	function LUA_FULL_RESET()
		for k, _ in pairs(package.loaded) do
			if SCRIPT_EXCEPTIONS[k] == nil then package.loaded[k] = nil end
		end
	end
else -- this block runs when the lua is hot reloaded
	print("[Powerups] Init [main.lua] > Detected Hotreload")
	LUA_FULL_RESET()
	SCRIPT_HOTRELOADED = true
	print("[Powerups] Init [main.lua] > Lua has been reset")
end

local MPServerRuntime = require("mp_libs/MPServerRuntime")



function onInit()
	MPServerRuntime.init("west_coast_usa.prefab.json", "open")
end
