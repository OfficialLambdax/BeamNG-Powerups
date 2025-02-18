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
local Util = require("libs/Util")
local Log = require("libs/Log")
local Settings = require("mp_libs/Settings")

local IS_LOADED = false -- changes in the same state would also let to the server retriggering a reload here. Lets prevent that


local function getSettings()
	local base_settings = {
		General = {
			AutoLoad = true,
			Locations = "",
			PowerupSet = "",
		},
		PowerUps = {
			RespawnTime = 30000,
			RotationTime = 180000,
		}
	}
	
	local base_settings_desc = {
		["#"] = "Multiplayer only settings",
		General = {
			["#"] = "General Server Settings",
			AutoLoad = "If you want the Server to auto load locations and a powerup set on startup",
			Locations = 'The name of the location file found in /prefabs.\nAs eg "utah". This will results in utah.prefab.json\nIf left empty it will auto select a prefab that is available for the loaded map',
			PowerupSet = 'The name of the Powerup set found in /powerups.\nIf left empty it will auto load the "open" set',
		},
		PowerUps = {
			["#"] = "This defines Powerup Settings",
			RespawnTime = "How long it takes for a powerup to respawn once it has been picked up. In miliseconds",
			RotationTime = "How long a powerup stays in the world before its rotated to another",
		}
	}
	
	return Settings.readSettings("multiplayer.server", base_settings, base_settings_desc)
end

local function getMapName()
	local map_name = ""
	if MP.Get then
		_, map_name, _ = table.unpack(Util.split(MP.Get(MP.Settings.Map), '/'))
	else
		-- MP.Get was introduced somewhen after 3.4.1.. bleh
		local map_path = require("mp_libs/ServerConfig").Get("General", "Map")
		_, map_name, _ = table.unpack(Util.split(map_path, '/'))
	end
	return map_name
end

function onInit()
	if IS_LOADED then return end
	IS_LOADED = true
	
	local settings = getSettings()
	local general, powerups = settings.General, settings.PowerUps
	
	MPServerRuntime.init()
	
	MPServerRuntime.api.setRespawnTime(powerups.RespawnTime)
	MPServerRuntime.api.setRotationTime(powerups.RotationTime)
	
	if general.AutoLoad then
		local location = general.Locations
		if location:len() == 0 then
			location = getMapName()
		end
		
		local powerup_set = general.PowerupSet
		if powerup_set:len() == 0 then
			powerup_set = "open"
		end
		
		if not FS.Exists(Util.myPath() .. 'prefabs/' .. location .. '.prefab.json') then
			Log.error('The selected location prefab file doesnt exists "' .. location .. '"')
			
		else
			MPServerRuntime.setLocation(location)
		end
		
		if not FS.Exists(Util.myPath() .. 'powerups/' .. powerup_set) then
			Log.error('The selected powerup set doesnt exists "' .. powerup_set .. '"')
			
		else
			MPServerRuntime.setPowerupSet(powerup_set)
		end
	end
	
	MPServerRuntime.hotreload()
	MPServerRuntime.displayServerState(true)
end
