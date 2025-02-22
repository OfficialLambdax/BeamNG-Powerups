--[[
	Adds a wrapper for the sfx emitter object of the game (SFXEmitter)
]]

-- package.loaded["libs/Sfx"] = nil; TEST = require("libs/Sfx")("/lua/ge/extensions/powerups/open/boost/sounds/carrevving.ogg", core_camera:getPosition()):minMaxDistance(300):isLooping(true):is3D(false):spawn()

local Util = require("libs/Util")
local Log = require("libs/Log")
local TimedTrigger = require("libs/TimedTrigger")
local PauseTimer = require("mp_libs/PauseTimer")
local createObject = require("libs/ObjectWrapper")

local function selfDestruct(self)
	self.int.obj:delete()
end

local function selfDisable(self)
	self:active(false)
end

local function follow(trigger_name, timer, for_time, self, obj)
	if timer:stop() >= for_time or (obj.isDeleted and obj:isDeleted()) then
		TimedTrigger.remove(trigger_name)
		return
	end
	
	self:setPosition(obj:getPosition())
end

local function followCallback(trigger_name, timer, for_time, self, obj, callback)
	if timer:stop() >= for_time then
		TimedTrigger.remove(trigger_name)
		return
	end
	
	callback(self, obj, self.int.obj)
end

return function(file_path, pos_vec)
	local obj = createObject("SFXEmitter")
	if obj == nil then return nil end
	if not FS:fileExists(file_path) then return end
	
	obj.fileName = file_path
	obj.playOnAdd = true
	obj.isLooping = false
	obj.isStreaming = false
	obj.volume = 1
	obj.is3D = true
	
	obj:setPosition(pos_vec or vec3(0, 0, 0))
	
	local sfx = {int = {
			obj = obj
		}
	}
	
	function sfx:spawn()
		self.int.obj:registerObject("sfx_" .. Util.randomName())
		return self
	end
	
	function sfx:delete()
		self.int.obj:delete()
	end
	
	-- ------------------------------------------------------------------
	-- Needs to be set before spawn, cannot be altered after
	function sfx:is3D(bool)
		self.int.obj.is3D = bool
		return self
	end
	
	function sfx:minMaxDistance(meters)
		self:minDistance(meters)
		self:maxDistance(meters)
		return self
	end
	
	function sfx:isStreaming(bool)
		self.int.obj.isStreaming = bool
		return self
	end
	
	function sfx:minDistance(meters)
		self.int.obj.referenceDistance = meters
		return self
	end
	
	function sfx:maxDistance(meters)
		self.int.obj.maxDistance = meters
		return self
	end
	
	-- ------------------------------------------------------------------
	-- Can be set any time
	function sfx:volume(float)
		self.int.obj.volume = float
		return self
	end
	
	function sfx:pitch(float)
		self.int.obj.pitch = float
		return self
	end
	
	function sfx:isLooping(bool)
		self.int.obj.isLooping = bool
		return self
	end
	
	function sfx:play()
		self.int.obj:play()
		return self
	end
	
	function sfx:stop()
		self.int.obj:stop()
		return self
	end
	
	function sfx:setPosition(pos_vec)
		self.int.obj:setPosition(pos_vec)
		return self
	end
	
	-- ------------------------------------------------------------------
	-- Set and forget stuff
	function sfx:selfDestruct(after)
		local r = TimedTrigger.new(
			'sfx_destruct_' .. Util.randomName(),
			after,
			1,
			selfDestruct,
			self
		)
		if r == nil then
			Log.error('Could not create destruction timer. Deleting immediatly.')
			self:delete()
		end
		
		return self
	end
	
	-- obj must have :getPosition() method and return a vec3
	function sfx:follow(obj, for_time)
		local trigger_name = 'sfx_follow_' .. Util.randomName()
		TimedTrigger.new(
			trigger_name,
			0,
			0,
			follow,
			trigger_name,
			PauseTimer.new(),
			for_time,
			self,
			obj
		)
		
		return self
	end
	
	--[[
		Obj can be any.
		Callback can have
			function(
				self, -- is this class
				obj, -- the given object
				sfx -- the unwrapped emitter
			)
	]]
	function sfx:followC(obj, for_time, callback)
		local trigger_name = 'sfx_follow_' .. Util.randomName()
		TimedTrigger.new(
			trigger_name,
			0,
			0,
			followCallback,
			trigger_name,
			PauseTimer.new(),
			for_time,
			self,
			obj,
			callback
		)
		
		return self
	end
	
	return sfx
end