local Log = require("libs/Log")
local Util = require("libs/Util")
local Sfx = require("libs/Sfx")

local VALID_EXTENSIONS = Util.tableVToK({"wav", "mp3", "ogg"}) -- not sure what it all accepts yet

return function(file_path, volume, pitch)
	local file_path = tostring(file_path)
	local volume = tonumber(volume or 1)
	local pitch = tonumber(pitch or 1)
	if file_path == nil or (FS.fileExists and not FS:fileExists(file_path)) then
		Log.error("Not sound available at " .. file_path)
		return nil
	end
	
	if not VALID_EXTENSIONS[(Util.fileExtension(file_path) or ''):lower()] then
		Log.error("Given sound has invalid sound format " .. file_path)
		return nil
	end
	
	if volume == nil then
		Log.error("Invalid volume given for sound " .. Util.fileName(file_path))
		return nil
	end
	
	if pitch == nil then
		Log.error("Invalid pitch given for sound " .. Util.fileName(file_path))
		return nil
	end
	
	local sound = {int = {
			file_path = file_path,
			volume = volume,
			pitch = pitch
		}
	}
	
	-- plays the sound in GE if vehicle is spectated, otherwise in VE
	function sound:smart(target_id, volume, pitch)
		local spectated = getPlayerVehicle(0)
		if (spectated and spectated:getId() == target_id) and
		(Util.dist3d(spectated:getPosition(), core_camera:getPosition()) < 30) then
			self:play(volume)
		else
			self:playVE(target_id, volume, pitch)
		end
	end
	
	-- 50 to 250 meter is the default sound effect distance
	function sound:smartSFX(target_id, volume, distance, max_time)
		local spectated = getPlayerVehicle(0)
		if (spectated and spectated:getId() == target_id) and
		(Util.dist3d(spectated:getPosition(), core_camera:getPosition()) < 30) then
			self:play(volume or self.int.volume)
		else
			local target_vehicle = getObjectByID(target_id)
			Sfx(self.int.file_path, target_vehicle:getPosition())
				:minDistance(distance or 50)
				:maxDistance((distance or 150) + 100)
				:is3D(true)
				:volume(1)
				:follow(target_vehicle, max_time or 10000)
				:selfDestruct(max_time or 10000)
				:spawn()
		end
	end
	
	-- 50 to 250 meter is the default sound effect distance
	function sound:smartSFX2(target_id, volume, max_time, min_distance, max_distance)
		local spectated = getPlayerVehicle(0)
		if (spectated and spectated:getId() == target_id) and
		(Util.dist3d(spectated:getPosition(), core_camera:getPosition()) < 30) then
			self:play(volume or self.int.volume)
		else
			local target_vehicle = getObjectByID(target_id)
			Sfx(self.int.file_path, target_vehicle:getPosition())
				:minDistance(min_distance or 50)
				:maxDistance(max_distance or 250)
				:is3D(true)
				:volume(1)
				:follow(target_vehicle, max_time or 10000)
				:selfDestruct(max_time or 10000)
				:spawn()
		end
	end
	
	function sound:play(volume)
		Engine.Audio.playOnce(
			--'AudioGui',
			'AudioMaster',
			self.int.file_path,
			{
				volume = volume or self.int.volume,
				channel = 'Other'
			}
		)
	end
	
	function sound:playVE(target_id, volume, pitch)
		local veh = getObjectByID(target_id)
		if not veh then return end
		veh:queueLuaCommand(
			string.format(
				'SoundsLib.stopPlaySound("%s", %f, %f)',
				self.int.file_path,
				volume or self.int.volume,
				pitch or self.int.pitch
			)
		)
	end
	
	function sound:playVEAll(volume, pitch)
		local lua = string.format(
			'SoundsLib.stopPlaySound("%s", %f, %f)',
			self.int.file_path,
			volume or self.int.volume,
			pitch or self.int.pitch
		)
		
		for _, veh in ipairs(getAllVehicles()) do
			veh:queueLuaCommand(lua)
		end
	end
	
	function sound:stopVE(target_id)
		local veh = getObjectByID(target_id)
		if not veh then return end
		veh:queueLuaCommand(
			string.format(
				'SoundsLib.stopSound("%s")',
				self.int.file_path
			)
		)
	end
	
	function sound:stopVEAll()
		local lua = string.format(
			'SoundsLib.stopSound("%s")',
			self.int.file_path
		)
		
		for _, veh in ipairs(getAllVehicles()) do
			veh:queueLuaCommand(lua)
		end
	end
	
	function sound:getFilePath()
		return self.int.file_path
	end
	
	return sound
end
