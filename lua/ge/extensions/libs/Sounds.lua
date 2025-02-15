local Log = require("libs/Log")
local Util = require("libs/Util")

local VALID_EXTENSIONS = Util.tableVToK({"wav", "mp3", "ogg"}) -- not sure what it all accepts yet

return function(file_path, volume, pitch)
	local file_path = tostring(file_path)
	local volume = tonumber(volume)
	local pitch = tonumber(pitch)
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
	
	function sound:play(volume)
		Engine.Audio.playOnce(
			'AudioGui',
			self.int.file_path,
			{
				volume = volume or self.int.volume,
				channel = 'Music'
			}
		)
	end
	
	function sound:playVE(target_id, volume, pitch)
		local veh = be:getObjectByID(target_id)
		if not veh then return end
		veh:queueLuaCommand(
			string.format(
				'SoundsLib.stopPlaySound("%s", %n, %n)',
				self.int.file_path,
				volume or self.int.volume,
				pitch or self.int.pitch
			)
		)
	end
	
	function sound:playVEAll(volume, pitch)
		local lua = string.format(
			'SoundsLib.stopPlaySound("%s", %n, %n)',
			self.int.file_path,
			volume or self.int.volume,
			pitch or self.int.pitch
		)
		
		for _, veh in ipairs(getAllVehicles()) do
			veh:queueLuaCommand(lua)
		end
	end
	
	function sound:stopVE(target_id)
		local veh = be:getObjectByID(target_id)
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
	
	return sound
end
