--[[
	Adds a wrapper for the particle emitter object of the game (ParticleEmitterNode)
]]

local Util = require("libs/Util")
local Log = require("libs/Log")
local TimedTrigger = require("libs/TimedTrigger")
local PauseTimer = require("mp_libs/PauseTimer")

local function selfDestruct(self)
	if self.int.is_deleted then return end
	self.int.obj:delete()
	self.int.is_deleted = true
end

local function selfDisable(self)
	self:active(false)
end

local function follow(trigger_name, timer, for_time, self, obj)
	if timer:stop() >= for_time or self.int.is_deleted then
		TimedTrigger.remove(trigger_name)
		return
	end
	
	self:setPosition(obj:getPosition())
end

local function followCallback(trigger_name, timer, for_time, self, obj, callback)
	if timer:stop() >= for_time or self.int.is_deleted then
		TimedTrigger.remove(trigger_name)
		return
	end
	
	callback(self, vehicle, self.int.obj)
end

return function(emitter_name, pos_vec, rot_quat)
	local pos_vec = pos_vec or vec3(0, 0, 0)
	local rot_quat = rot_quat or QuatF(0, 0, 0, 0)
	
	local obj = createObject("ParticleEmitterNode")
	obj:setField("emitter", 0, emitter_name or "DefaultEmitter")
	if obj.emitter == nil then
		Log.error('Given emitter doesnt exists "' .. tostring(emitter_name) .. '"')
		return
	end
	
	obj.useInstanceRenderData = 1
	obj.scale = vec3(1, 1, 1)
	
	obj:setField("dataBlock", 0, "lightExampleEmitterNodeData1")
	obj:setField("Velocity", 0, 1)
	obj:setPosRot(pos_vec.x, pos_vec.y, pos_vec.z, rot_quat.x, rot_quat.y, rot_quat.z, rot_quat.w)
	obj:registerObject('particle_emitter_' .. Util.randomName())
	
	local particle = {int = {
			obj = obj,
			is_deleted = false
		}
	}
	
	-- obj must have :getPosition() method and return a vec3
	function particle:follow(obj, for_time)
		local trigger_name = 'particle_follow_' .. Util.randomName()
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
				emitter -- the unwrapped emitter
			)
	]]
	function particle:followC(obj, for_time, callback)
		local trigger_name = 'particle_follow_' .. Util.randomName()
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
	
	function particle:delete()
		if self.int.is_deleted then return end
		
		self.int.obj:delete()
		self.int.is_deleted = true
	end
	
	function particle:velocity(velocity)
		if self.int.is_deleted then return end
		
		self.int.obj:setField("Velocity", 0, velocity)
		return self
	end
	
	function particle:active(state)
		if self.int.is_deleted then return end
		
		self.int.obj:setActive(state)
		return self
	end
	
	function particle:setPosition(pos_vec)
		if self.int.is_deleted then return end
		
		self.int.obj:setPosition(pos_vec)
		return self
	end
	
	function particle:setRotation(rot_quat)
		if self.int.is_deleted then return end
		
		local pos_vec = self.int.obj:getPosition()
		self.int.obj:setPosRot(
			pos_vec.x, pos_vec.y, pos_vec.z,
			rot_quat.x, rot_quat.y, rot_quat.z, rot_quat.w
		)
		return self
	end
	
	function particle:selfDisable(after)
		local r = TimedTrigger.new(
			'particle_disable_' .. Util.randomName(),
			after,
			1,
			selfDisable,
			self
		)
		if r == nil then
			Log.error('Could not create disabling timer. Disabling immediatly.')
			self:active(false)
		end
		
		return self
	end
	
	function particle:selfDestruct(after)
		local r = TimedTrigger.new(
			'particle_destruct_' .. Util.randomName(),
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
	
	return particle
end
