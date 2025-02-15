local M = {}

--[[
	Format
		["file_path"] = id
]]
local SOUNDS = {}

M.playSound = function(file_path, volume, pitch)
	local id = SOUNDS[file_path]
	if id == nil then
		id = obj:createSFXSource2(file_path, "AudioSoft3D", 0, v.data.refNodes[0].ref, 0)
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
		obj:cutSFX(id)
	end
end

return M
