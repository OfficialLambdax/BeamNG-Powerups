-- BeamMP Server only
-- WIP

-- Prevent loading on the client
if not MP and MP.TriggerClientEvent then return end

--[[
	Basically a cheap method of wiping the lua vm to allow for a full reload of a beammp server script. Is very usefull for development sakes. Requires that your script is hotreload safe.
	
	A script is hotreload safe when it can reinstate data assets that are otherwise only known by the call of events. Eg when a player joins your server. Your script must be able to reinstate that player on hotreload if the player is still present. Same goes for vehicles.
	
	___ eg if your script works based on the onPlayerJoin and onVehicleSpawned events ___
	for player_id, player_name in pairs(MP.GetPlayers()) do
		if onPlayerJoin(player_id) == 1 then
			MP.DropPlayer(player_id)
		else
			for vehicle_id, vehicle_data in pairs(MP.GetPlayerVehicles(player_id) or {}) do
				if onVehicleSpawned(player_id, vehicle_id, vehicle_data) == 1 then
					MP.RemoveVehicle(player_id, vehicle_id)
				end
			end
		end
	end
]]
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
	--print("[Powerups] Init [main.lua] > Detected Hotreload")
	LUA_FULL_RESET()
	SCRIPT_HOTRELOADED = true
	--print("[Powerups] Init [main.lua] > Lua has been reset")
end


local MPServerRuntime = require("mp_libs/MPServerRuntime")


function onInit()
	MPServerRuntime.init("utah.prefab.json", "open")
end
