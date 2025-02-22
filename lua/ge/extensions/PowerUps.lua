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
package.loaded["libs/extender/PowerUpsTraits"] = nil
package.loaded["libs/extender/PowerUpsTypes"] = nil
package.loaded["libs/extender/GroupReturns"] = nil
package.loaded["libs/extender/PowerupReturns"] = nil
package.loaded["libs/TriggerLoad"] = nil
package.loaded["libs/MathUtil"] = nil
package.loaded["libs/Util"] = nil
package.loaded["libs/Log"] = nil
package.loaded["libs/Sounds"] = nil
package.loaded["libs/Particles"] = nil
package.loaded["mp_libs/MPUtil"] = nil
package.loaded["mp_libs/MPClientRuntime"] = nil

local TimedTrigger = require("libs/TimedTrigger")
local CollisionsLib = require("libs/CollisionsLib")
local Sets = require("libs/Sets")
local ForceField = require("libs/ForceField")
local PowerUps = require("libs/PowerUps")
local MPUtil = require("mp_libs/MPUtil")
local PauseTimer = require("mp_libs/PauseTimer")
local Log = require("libs/Log")
local Util = require("libs/Util")

local M = {}
local INITIALIZED = false
local TRIGGER_DEBUG = false
local TRIGGER_ADJUST = false

--[[
	Notes
		extensions.reload("PowerUps")
		PowerUps.pu.loadPowerUpDefs("lua/ge/extensions/powerups/open")
		PowerUps.pu.loadLocationPrefab("lua/ge/extensions/prefabs/test4.prefab.json")
		PowerUps.pu.loadLocationPrefab("lua/ge/extensions/prefabs/west_coast_usa.prefab.json")
		PowerUps.pu.testExec(29756, "forcefield", 1)
		PowerUps.pu.testExec(29761, "forthshot", 1)
		
		PowerUps.sets.loadSet("lua/ge/extensions/sets/test.lua", "test"); PowerUps.sets.getSet("test"):this():exec()
		
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
-- Runtime Measurement
local MEASURE_TIMER = PauseTimer.new()
local MEASURE_BUFFER, MEASURE_INDEX = {}, 1
local MEASURE_PRINT = false
local function measure()
	MEASURE_BUFFER[MEASURE_INDEX] = MEASURE_TIMER:stop()
	MEASURE_INDEX = MEASURE_INDEX + 1
	if MEASURE_INDEX > 99 then MEASURE_INDEX = 1 end
end

local function measureAverage()
	local total = 0
	for i = 0, 100, 1 do
		total = total + (MEASURE_BUFFER[i] or 0)
	end
	local avg = total / 100
	
	--if avg > 5 then
	--	Log.warn('PowerUps runtime is taking alot of time! Average: ' .. Util.mathRound(avg, 3) .. ' ms\nIf you are experiencing heavy lag, this might be why')
	--end
	
	if MEASURE_PRINT then
		Log.info('Current average runtime: ' .. Util.mathRound(avg, 3) .. ' ms\t with: ' .. PowerUps.getRenderedLocationsCount() .. ' rendered locations.')
	end
end

-- ----------------------------------------------------------------------------
-- Delta time Measurement for auto frame skipping
local MEASURE_DT_BUFFER, MEASURE_DT_INDEX = {}, 1

local FRAME_SKIPPING = false
local FRAME_SKIPPING_DT = 0
local FRAME_SKIPPING_COUNT = 0
local FRAME_SKIPPING_LIMIT = 1

local function measureDt(dt)
	MEASURE_DT_BUFFER[MEASURE_INDEX] = dt
	MEASURE_DT_INDEX = MEASURE_DT_INDEX + 1
	if MEASURE_DT_INDEX > 99 then MEASURE_DT_INDEX = 1 end
end

local function measureDtAverage()
	local total = 0
	for i = 0, 100, 1 do
		total = total + (MEASURE_DT_BUFFER[i] or 0)
	end
	local avg = (total / 100) * 1000
	
	-- enables frame skipping when <30 fps
	if not FRAME_SKIPPING and avg > 30 then -- ~30fps
		FRAME_SKIPPING = true
		
		Log.warn('Detected low average FPS. Enabled frame skipping')
	
	-- disables once >60fps again
	elseif FRAME_SKIPPING and avg < 17 then -- ~60fps
		FRAME_SKIPPING = false
		FRAME_SKIPPING_LIMIT = 1
		
		Log.warn('FPS recovered. Disabled frame skipping')
		
	elseif FRAME_SKIPPING then
		local frame_step = math.min(math.ceil(math.max((avg / 30) * 1.75, 1)), 5)
		if frame_step ~= FRAME_SKIPPING_LIMIT then
			FRAME_SKIPPING_LIMIT = frame_step
			Log.warn('Skipping: ' .. frame_step .. ' frames')
		end
	end
	
	--Log.info('Current average delta time: ' .. Util.mathRound(avg, 3) .. ' ms')
end

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
	
	TimedTrigger.new("powerups_measurement", 10000, 0, measureAverage)
	TimedTrigger.new("powerups_dt_measurement", 1000, 0, measureDtAverage)
	
	INITIALIZED = true
end

-- ----------------------------------------------------------------------------
-- Runtime
M.onPreRender = function(dt_real) -- , dt_sim, dt_raw
	if not INITIALIZED then return end
	
	local dt = dt_real
	if FRAME_SKIPPING then
		FRAME_SKIPPING_DT = FRAME_SKIPPING_DT + dt_real
		FRAME_SKIPPING_COUNT = FRAME_SKIPPING_COUNT + 1
		if FRAME_SKIPPING_COUNT < FRAME_SKIPPING_LIMIT then
			measureDt(dt_real)
			return
		end
		
		dt = FRAME_SKIPPING_DT
	end
	
	MEASURE_TIMER:stopAndReset()
	
	-- order matters. timed trigger before powerups as powerups may que anything for the next frame
	TimedTrigger.tick()
	CollisionsLib.tick()
	ForceField.tick()
	PowerUps.tick(dt)
	
	if TRIGGER_DEBUG then
		M.setTriggerDebug(true)
	end
	if TRIGGER_ADJUST then
		M.autoAdjustTriggerScale()
	end
	
	FRAME_SKIPPING_DT = 0
	FRAME_SKIPPING_COUNT = 0
	
	measure()
	measureDt(dt_real)
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

--[[
M.onLoadingScreenFadeout = function()
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
end
]]

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
-- Convenience stuff
M.setTriggerDebug = function(state)
	for _, name in pairs(scenetree.findClassObjects("BeamNGTrigger")) do
		if name:find("BeamNGTrigger_") then
			scenetree.findObject(name):setField("debug", 0, tostring(state))
		end
	end
end

M.autoAdjustTriggerScale = function()
	local default_scale = PowerUps.getDefaultTriggerScale()
	for _, name in pairs(scenetree.findClassObjects("BeamNGTrigger")) do
		if name:find("BeamNGTrigger_") then
			scenetree.findObject(name):setScale(default_scale)
		end
	end
end

-- Will highlight all already placed and newly placed triggers that contain the string "BeamNGTrigger" in their name
M.setTriggerDebug = function(state)
	TRIGGER_DEBUG = state
	if not TRIGGER_DEBUG then
		M.setTriggerDebug(false)
	end
end

-- Will auto adjust all already placed and newly placed triggers that contain the string "BeamNGTrigger" in their name to the powerups default size
M.autoAdjustTriggerScale = function(state)
	TRIGGER_ADJUST = state
end

M.autoPrintRoutineMeasurement = function(state)
	MEASURE_PRINT = state
end

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- API
-- This resets the powerup library. And it removes all powerups from each and everything and also all locations. Its as if the mod was just loaded but powerups and locations arent reinstated
M.reset = function()
	PowerUps.unload()
	PowerUps.init()
end

-- eg
-- prefab_path 		= 'lua/ge/extensions/prefabs/utah.prefab.json'
-- powerup_set_path	= 'lua/ge/extensions/powerups/open'
-- PowerUps.loadPowerups('lua/ge/extensions/prefabs/smallgrid_perftest.prefab.json', 'lua/ge/extensions/powerups/open')
M.loadPowerups = function(prefab_path, powerup_set_path)
	PowerUps.loadLocationPrefab(prefab_path)
	PowerUps.loadPowerUpDefs(powerup_set_path)
end

-- ----------------------------------------------------------------------------
-- Direct access
M.pu = PowerUps
M.ff = ForceField
M.sets = Sets

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

-- This affects stationary, picked up and active powerup rendering
-- If you set this to low active powerups may break because their physics renderer isnt ran anymore
M.setRenderDistance = function(distance) -- in meters
	PowerUps.setRenderDistance(distance)
end

-- You generally only want to increase the routine if you set the overall render distance lower
M.setRenderDistanceRoutineTime = function(time) -- in ms
	PowerUps.setRenderDistanceRoutineTime(time)
end

return M

