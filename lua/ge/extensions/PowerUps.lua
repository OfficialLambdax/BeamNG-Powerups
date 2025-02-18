--[[
	License: None
	Author: Neverless (discord: neverless.)
]]

--[[
	-- Game side only
	
	For detailed describtions of this mod please see the info folder.
	This mod is a wrapper for the PowerUps library. It loads/unloads the powerups library and a default prefab and powerup set, while also proving an api for addons.
]]

--[[
	This unloader is bad.
	If any other extension uses any of these libs it can cause issues.
	Issue tho is.. if we unload it in modScript.lua.. the issue would be the same :p
	
	So i think this rather should load everything as a module that runs on its own.
	Where you, like with any game own module, you just have it load and then you never "require" it but just do eg TimedTrigger.new() and that module has its own onUpdate hook etc.
	
	Then we never unload it ourselfs and have every module handle its own unload. eg then when map is unloaded. Dunno how exactly the extensions system work at this moment and when what loads/unloads/reloads without full on testing that i tho didnt have time for.
]]

-- prevent this from loading server side
if MP and MP.TriggerClientEvent then
	return
end

-- unload what otherwise would leak to mem
require("libs/ForceField").unload() -- markers will otherwise leak to mem
require("libs/PowerUps").unload()
require("libs/TriggerLoad").unload()

-- force reload of these
package.loaded["libs/TimedTrigger"] = nil
package.loaded["libs/CollisionsLib"] = nil
package.loaded["libs/Sets"] = nil
package.loaded["libs/ForceField"] = nil
package.loaded["libs/PowerUps"] = nil
package.loaded["libs/PowerUpsExtender"] = nil
package.loaded["libs/PowerUpsTraits"] = nil
package.loaded["libs/PowerUpsTypes"] = nil
package.loaded["libs/TriggerLoad"] = nil
package.loaded["libs/MathUtil"] = nil
package.loaded["libs/Util"] = nil
package.loaded["libs/Log"] = nil
package.loaded["libs/Sounds"] = nil
package.loaded["mp_libs/MPUtil"] = nil
package.loaded["mp_libs/MPClientRuntime"] = nil

local TimedTrigger = require("libs/TimedTrigger")
local CollisionsLib = require("libs/CollisionsLib")
local Sets = require("libs/Sets")
local ForceField = require("libs/ForceField")
local PowerUps = require("libs/PowerUps")
local MPUtil = require("mp_libs/MPUtil")

local M = {}
local INITIALIZED = false
local TRIGGER_DEBUG = false
local TRIGGER_ADJUST = false

--[[
	Notes
		extensions.reload("DoNotTouch")
		DoNotTouch.pu.loadPowerUpDefs("lua/ge/extensions/powerups/open")
		DoNotTouch.pu.loadLocationPrefab("lua/ge/extensions/prefabs/test4.prefab.json")
		DoNotTouch.pu.loadLocationPrefab("lua/ge/extensions/prefabs/west_coast_usa.prefab.json")
		DoNotTouch.pu.testExec(29756, "forcefield", 1)
		DoNotTouch.pu.testExec(29761, "forthshot", 1)
		
		-- Collision lib
		local veh = getPlayerVehicle(0)
		if veh then
			local new_colliding = CollisionsLib.newColliding(veh:getId() or 0)
			for game_vehicle_id, _ in pairs(new_colliding) do
				print("New Contact with: " .. game_vehicle_id)
			end
		end
]]

-- ----------------------------------------------------------------------------
-- Init
-- only to be called once a map has been loaded or is already loaded
local function onInit()
	PowerUps.init()
	
	local level_name = core_levels.getLevelName(getMissionFilename())
	local prefab_name = 'lua/ge/extensions/prefabs/' .. level_name .. '.prefab.json'
	
	if not MPUtil.isBeamMPSession() and FS:fileExists(prefab_name) then
		PowerUps.loadLocationPrefab(prefab_name)
		PowerUps.loadPowerUpDefs("lua/ge/extensions/powerups/open")
	end
	
	INITIALIZED = true
end

-- ----------------------------------------------------------------------------
-- Trigger Highlight
local function setTriggerDebug(state)
	for _, name in pairs(scenetree.findClassObjects("BeamNGTrigger")) do
		if name:find("BeamNGTrigger_") then
			scenetree.findObject(name):setField("debug", 0, tostring(state))
		end
	end
end

local function adjustTriggerScale()
	local default_scale = PowerUps.getDefaultTriggerScale()
	for _, name in pairs(scenetree.findClassObjects("BeamNGTrigger")) do
		if name:find("BeamNGTrigger_") then
			scenetree.findObject(name):setScale(default_scale)
		end
	end
end

-- Will highlight all already placed and newly placed triggers that contain the string "BeamNGTrigger" in their name
M.triggerShow = function(state)
	TRIGGER_DEBUG = state
	if not TRIGGER_DEBUG then
		setTriggerDebug(false)
	end
end

-- Will auto adjust all already placed and newly placed triggers that contain the string "BeamNGTrigger" in their name to the powerups default size
M.triggerAdjust = function(state)
	TRIGGER_ADJUST = state
end

-- ----------------------------------------------------------------------------
-- Runtime
M.onUpdate = function(dt_real, dt_sim, dt_raw)
	if not INITIALIZED then return end
	
	TimedTrigger.tick()
	CollisionsLib.tick()
	
	if TRIGGER_DEBUG then
		setTriggerDebug(true)
	end
	if TRIGGER_ADJUST then
		adjustTriggerScale()
	end
end

M.onPreRender = function(dt_real, dt_sim, dt_raw)
	if not INITIALIZED then return end
	ForceField.tick() -- unfortunately doesnt help with the marker rendering
	PowerUps.tick(dt_real, dt_sim, dt_raw)
end

-- ----------------------------------------------------------------------------
-- Internal Mod load/unload
M.onWorldReadyState = function(state)
	if state == 2 then onInit() end
end

M.onExtensionLoaded = function()
	-- if the mod was loaded outside of a map then do nothing
	if core_levels.getLevelName(getMissionFilename()) == nil then return end
	
	onInit()
end

M.onExtensionUnloaded = function()
	M.onClientEndMission()
end

M.onClientEndMission = function()
	PowerUps.unload()
	ForceField.unload()
	INITIALIZED = false
end

M.onLoadingScreenFadeout = function()
	--[[
	if MPUtil.isBeamMPSession() and FS:fileExists("gameplay/tutorials/pages/powerups/content.html") then
		guihooks.trigger('introPopupTutorial', {
				{
					type = "info",
					content = readFile("gameplay/tutorials/pages/powerups/content.html"):gsub("\r\n", ""),
					flavour = "onlyOk",
					isPopup = true
				}
			}
		)	
	end
	]]
end

-- ----------------------------------------------------------------------------
-- Lib specific
M.onBeamNGTrigger = function(...)
	PowerUps.onBeamNGTrigger(...)
end

M.onVehicleSpawned = function(...)
	PowerUps.onVehicleSpawned(...)
end

M.onVehicleDestroyed = function(...)
	PowerUps.onVehicleDestroyed(...)
end

-- ----------------------------------------------------------------------------
-- Dev specific
--M.getSet = Sets.getSet
--M.ff = ForceField
--M.pu = PowerUps

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- API
-- This resets the powerup library
M.reset = function()
	PowerUps.unload()
	PowerUps.init()
end

-- eg
-- prefab_path 		= 'lua/ge/extensions/prefabs/utah.prefab.json'
-- powerup_set_path	= 'lua/ge/extensions/powerups/open'
M.loadPowerups = function(prefab_path, powerup_set_path)
	PowerUps.loadLocationPrefab(prefab_path)
	PowerUps.loadPowerUpDefs(powerup_set_path)
end


-- ----------------------------------------------------------------------------
-- Direct access
M.pu = PowerUps
M.ff = ForceField
M.getSet = Sets.getSet

-- ----------------------------------------------------------------------------
-- Singleplayer Only
-- 		veh_id, group_name, level
-- or.	group_name, level			(then the spectated vehicle is used as vehicle_id)
M.exec = function(vehicle_id, group_name, level)
	if level == nil then
		local vehicle = getPlayerVehicle(0)
		if vehicle == nil then return end
		level = group_name
		group_name = vehicle_id
		vehicle_id = vehicle:getId()
	end
	PowerUps.testExec(vehicle_id, group_name, level)
end

M.takePowerup = function(vehicle_id, location_name)
	PowerUps.takePowerup(vehicle_id, location_name)
end

M.givePowerup = function(vehicle_id, group_name)
	PowerUps.givePowerup(vehicle_id, group_name)
end

M.dropPowerup = function(vehicle_id)
	PowerUps.dropPowerup(vehicle_id)
end

M.getCharge = function(vehicle_id)
	return PowerUps.getCharge(vehicle_id)
end

M.setCharge = function(vehicle_id, level)
	PowerUps.setCharge(vehicle_id, level)
end

-- ----------------------------------------------------------------------------
-- Singleplayer and Multiplayer compatible
M.getPowerup = function(vehicle_id)
	return PowerUps.getPowerup(vehicle_id)
end

-- charge_overwrite is optional
M.activatePowerup = function(vehicle_id, charge_overwrite)
	PowerUps.activatePowerup(vehicle_id, nil, charge_overwrite)
end

M.disableActivePowerup = function(vehicle_id)
	PowerUps.disableActivePowerup(vehicle_id)
end

return M

