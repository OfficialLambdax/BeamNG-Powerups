local PowerUps = require("libs/PowerUps")
local Extender = require("libs/PowerUpsExtender")
local Util = require("libs/Util")
local Sets = require("libs/Sets")
local Trait = Extender.Traits

local M = {
	-- Clear name of the powerup
	clear_name = "Push close vehicles",
	
	-- If the camera is to far away from this powerups owner it will not render except this is true
	-- Will prevent whileActive calls
	do_not_unload = false,
	
	--[[
		eg. {Trait.Consuming, Trait.Reflective}
		For each traits defined you MUST also create a callback.
			M[Trait.Consuming] = function(data, vehicle) end
		
		Dont have to have any custom behaviour in it, but it must exist.
		
		It will be called when another active powerup interacts with this one.
		Eg when your force field has the Consuming trait another active powerup that considers you to be hit can add custom behaviour for this trait where it decides "ah ok it got a active powerup with the Consuming trait eg a 'force field', i wont apply my damage to it". With the callback it can let this powerup know about its decision which allows this powerup to for example just play a sound. A sound that for example represents a bullet only hitting a force field.
		
		Exact Trait definitions can be found in the PowerUpsTraits.lua
	]]
	traits = {},
	
	--[[
		If your powerup for example handles other powerups "Consuming" traits then add this here. The powerups lib will merely check if these traits even exists. Its basically just to ensure your powerup is not out of date.
		
		eg. {Trait.Consuming, Trait.Reflective}
	]]
	respects_traits = {},
	
	-- This must match the power ups library _NAME or this powerup is rejected.
	-- This name is changed when the api changes, so to not load outdated powerups.
	lib_version = "init",
	
	-- DO NOT treat this is a variable cache.
	-- These are merely definitions
}



-- Anything you may want todo before anything is spawned. eg loading sounds in all vehicle vms
M.onInit = function(group_defs)
	
end

-- Called for each vehicle
M.onVehicleInit = function(game_vehicle_id)
	be:getObjectByID(game_vehicle_id):queueLuaCommand('PowerUpSounds.addSound("powerup_push1", "AudioSoft3D", 12, 1, "/lua/ge/extensions/powerups/template/push/sounds/push 1.ogg")')
end

-- When the powerup is activated
M.onActivate = function(vehicle)
	print("activate")
	
	local targets = {}
	for _, target in pairs(getAllVehicles()) do
		if vehicle:getId() ~= target:getId() then
			if Util.dist3d(vehicle:getPosition(), target:getPosition()) < 20 then
				table.insert(targets, target:getId())
			end
		end
	end
	
	if #targets == 0 then targets = nil end
	
	--[[
		Return X, Y
		
		X Return values
			nil = Failure. Powerup is dropped, effect not started.
			any = Success. Whatever you return here is given into all other events
		
		Y Return values
			nil = no target
			{} = Return the selected targets as
				{target_id_1, target_id_n}
				
				YOU MUST DO THIS if you have selected a target or multiple !!
				The lib syncs target selections this way with other clients.
	]]
	local data = {
		no_target = targets == nil,
		targets = nil,
		sound_played = false
	}
	return data, targets
end

-- only called once
M.onUnload = function(data)
	print("unload")
end

-- only called once
M.onLoad = function(data)
	print("load")
end

-- While the powerup is active. Update its render here, detect if it hit something. that kinda stuff
M.whileActive = function(data, origin_id)
	--print("while active")
	
	-- no one was close enough to apply our powerup effect to
	if data.no_target then
		if Extender.isPlayerVehicle(origin_id) then
			print("no target found")
			return 1
		else
			return nil
		end
	end
	
	-- waiting for target confirmation
	if not data.targets then
		print("waiting confirmation")
		return nil
		
	else -- we got targets!
		print("we got targets")
		return 2, nil, data.targets
	end
	
	--[[
		General structure on non basic powerups
		Imagine a zap powerup that finds targets around the origin vehicle for 5 seconds and zaps them all one after another. Where the effect only ever just lasts for 500ms and then it looks for the next target to zap.
		
		1. onActivate
			If there are vehicles surrounding our vehicle then you can already
				return {effect_timer, current_target, target_timer}, targets, nil
			Or just if no targets yet
				return {effect_timer, current_target, target_timer}
		
		2. whileActive
			Check if data.current_target and data.target_timer > 500  - aka if we have a target and if we zapped them for more then 500ms
			If not
				find a target
				and
					return nil, {target}, nil
					
				this will trigger onTargetSelect at one point
				M.onTargetSelect(data, targets)
					data.current_target = targets[1]
					data.target_timer:stopAndReset()
				end
				
				If you cant find a target yet and want to wait
					return nil, nil, nil
			
			If yes
				Fly the bullet, display the effect etc
				Once the bullet or zap has hit a target
					return 3, nil, {data.current_target}
				
				This will trigger onTargetHit and onHit at one point
				M.onHit(data, origin_id, target_id) -- called on every client
					-- Do damage
				end
				M.onTargetHit(data, origin_id, target_id) -- only called on our client
					-- So if you modify the target vehicle here, it will not happen on their end
				end
			
			Check if data.effect_timer > 5000   - aka if our powerup time of 5 seconds has ran out
				return 1
				
				Will call onDeactivate
		
		Or otherwise said
			1 Find target -> return nil, {target_id}, nil
			2. Wait for target to be confirmed -> return nil, nil, nil
			3. Fly the projectile if its not instant -> return nil, nil, nil
			4. Once hit -> return 2, nil, {target_id}
	]]
	
	--[[
		Return X, Y, Z
			X = Powerup status
			Y = Target select
			Z = Target hit
	
		X Return values
			nil = This effect is NOT over, just continue calling this powerup
			1 = This effect is over, do nothing but call onDeactivate
			2 = This effect is over, take the target hits from Z and execute
				- whileActive will no longer be run
				- targets are put into a waiting list
					- in singleplayer => executed directly
					- in multiplayer => executed after confirmation from the server
				- once confirmed -> onTargetHit -> onHit -> onDeactivate
				
			3 = This effect is NOT over, but apply effect on the target hits
				- whileActive is continued to be run
				- targets are put into a waiting list -- same behaviour as 2
				- once confirmed -> onTargetHit -> onHit
				
			If the three X return values make no sense yet. Imagine this
				nil = We are waiting for our defensive powerup to finish.
				Or. = We are searching for a target for the next X seconds.
			
				1   = We had a defensive powerup, like a shield, it ran out. done.
				Or. = We tried to find a valid target, but didnt.

				2   = Were a canon, we found a target and have hit it
				
				3   = We are shooting multiple bullets one after another. Our first bullet has found its target
				
		Y Return values
			nil = no target
			{}  = Return the selected targets as
				{target_id_1, target_id_n}
				
				YOU MUST DO THIS if you have selected a target or multiple !!
				The lib syncs target selections this way with other clients.
				
				If this powerup is owned by another player then ours then the returned targets are ignored. As they come from their client.
		
		Z Return value
			nil = did not hit a target
			{}  = Return the hit targets as
				{target_id_1, target_id_n}
				
				YOU MUST DO THIS once your powerup has hit a target or multiple !!
				The lib sync target hits this way with other clients.
				
				The onHit event is called on everyones end.
					Aka if your powerup deals damage then do it here
					
				The onTargetHit event is called on our end with each target.
					If your powerup does something only visible to us then do it here.
					Eg. a funny sound. "Gotya!"
				
				If this powerup is owned by another player then ours then the returned target hits are ignored. As they come from their client.
	]]
end

-- Called once one or multiple targets have been chosen.
-- In a singleplayer scenario this event is called directly.
-- In a multiplayer scenario once the server confirms the targets.
M.onTargetSelect = function(data, targets)
	print("targets !")
	data.targets = targets
end

-- When the powerup hit another vehicle
M.onTargetHit = function(data, origin_id, target_id)
	-- everything in here is only executed on our end
	print("onTargetHit")
end

-- When the powerup hit our vehicle. Aka another vehicle with this powerup shoots at our vehicle
-- We are target_id
M.onHit = function(data, origin_id, target_id)
	-- everything in here is executed on our and the remote end
	print("onHit")
	
	-- push vehicle away from us
	local origin_vehicle = be:getObjectByID(origin_id)
	local target_vehicle = be:getObjectByID(target_id)
	
	local vel1 = origin_vehicle:getVelocity()
	local vel2 = target_vehicle:getVelocity()
	
	local pos1 = origin_vehicle:getPosition()
	local pos2 = target_vehicle:getPosition()
	
	local push = ((vel1 - vel2) * 0.5) + (pos2 - pos1)
	target_vehicle:applyClusterVelocityScaleAdd(target_vehicle:getRefNodeId(), 1, push.x, push.y, push.z)
	
	if not data.sound_played then
		origin_vehicle:queueLuaCommand('PowerUpSounds.playSound("powerup_push1")')
		data.sound_played = true
	end
end

-- When the powerup is destroyed. eg when the vehicle is deleted or the powerup ended
M.onDeactivate = function(data)
	print("deactivate")
	
	-- is better to let sets run out as left over trigger may not trigger otherwise.
	-- eg. you turn the screen black and have a trigger that unblacks it. But if you remove the set then also the unblack trigger. Aka screen stays black.
	--Sets.getSet("powerup_template"):revert(data.id)
end

return M
