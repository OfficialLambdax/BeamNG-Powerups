--[[
	Sounds in this game are buggy. I am not sure how to properly handle them. Sometimes they act like this, other times like that, sometimes they just dont play. Then they like to be louder or quiter or you cant hear them any further away then 5 meters. Oh and they also randomly like to just start playing when you reset your vehicle.. huh... bruh.
	
	This must clearly be my fault. Please make a tutorial game devs
]]

local M = {}
local SOUNDS = {}

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

M.addSound = function(name, describtor, volume, pitch, file_path)
	if SOUNDS[name] then
		--print('PowerUpSounds Error: Sound "' .. name .. '" already exists')
		M.setVolumePitch(name, volume, pitch)
		return
	end
	
	SOUNDS[name] = {
		--id = obj:createSFXSource2(file_path, describtor, name, 0, -1),
		id = obj:createSFXSource2(file_path, describtor, name, v.data.refNodes[0].ref, 0),
		volume = volume,
		pitch = pitch
	}
	M.stopSound(name)
end

M.setVolumePitch = function(name, volume, pitch)
	if SOUNDS[name] then
		SOUNDS[name].volume = volume
		SOUNDS[name].pitch = pitch
		obj:setVolumePitch(SOUNDS[name].id, volume, pitch)
	end
end

M.playSound = function(name)
	if SOUNDS[name] then
		M.stopSound(name)
		obj:setVolumePitch(SOUNDS[name].id, SOUNDS[name].volume, SOUNDS[name].pitch)
		obj:playSFX(SOUNDS[name].id)
		
		--print(SOUNDS[name].id)
	else
		log("E", "PowerupSound", "Error: Unknown sound: " .. name)
	end
end

M.stopSound = function(name)
	if SOUNDS[name] then
		obj:cutSFX(SOUNDS[name].id)
		obj:stopSFX(SOUNDS[name].id)
	end
end

M.onReset = function()
	for _, sound in pairs(SOUNDS) do
		obj:cutSFX(sound.id)
	end
end

return M