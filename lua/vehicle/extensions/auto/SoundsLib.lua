local M = {}

--[[ possible descriptions are:
	AudioDefault3D
	AudioSoft3D
	AudioClose3D
	AudioClosest3D
	AudioMusic3D

	AudioDefaultLoop3D
	AudioCloseLoop3D
	AudioClosestLoop3D
	AudioMusicLoop3D

	Audio2D
	AudioStream2D
	AudioMusic2D

	AudioLoop2D
	AudioStreamLoop2D
]]

--[[
	Format
		["file_path"] = id
]]
local SOUNDS = {}

M.playSound = function(file_path, volume, pitch)
	local id = SOUNDS[file_path]
	if id == nil then
		id = obj:createSFXSource2(file_path, "AudioSoft3D", file_path:gsub("/", "_"), v.data.refNodes[0].ref, -1)
		SOUNDS[file_path] = id
	end
	
	obj:setVolumePitch(id, volume, pitch)
	obj:playSFX(id)
end

M.stopPlaySound = function(file_path, volume, pitch)
	M.stopSound(file_path)
	M.playSound(file_path, volume, pitch)
end

M.stopSound = function(file_path)
	local id = SOUNDS[file_path]
	if id == nil then return end
	obj:cutSFX(id)
	obj:stopSFX(id)
end

M.onReset = function()
	for _, id in pairs(SOUNDS) do
		obj:setVolumePitch(id, 0, 1)
		obj:cutSFX(id)
	end
end

return M
