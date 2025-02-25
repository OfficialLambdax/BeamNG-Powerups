--[[
	Adds a wrapper for the particle emitter object of the game (ParticleEmitterNode)
]]

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
	if (for_time > 0 and timer:stop() >= for_time) or (obj.isDeleted and obj:isDeleted()) or self.int.obj:isDeleted() then
		TimedTrigger.remove(trigger_name)
		return
	end
	
	self:setPosition(obj:getPosition())
end

local function followCallback(trigger_name, timer, for_time, self, obj, callback)
	if (for_time > 0 and timer:stop() >= for_time) or self.int.obj:isDeleted() then
		TimedTrigger.remove(trigger_name)
		return
	end
	
	callback(self, obj, self.int.obj)
end

local function bind(trigger_name, self, obj, delete_after)
	--print(trigger_name)
	if obj:isDeleted() or self.int.obj:isDeleted() then
		--print(self.int.dbg .. '\t' .. tostring(obj:isDeleted()) .. '\t' .. tostring(self.int.obj:isDeleted()))
		TimedTrigger.remove(trigger_name)
		if delete_after > 0 then
			self:active(false)
			self:selfDestruct(delete_after)
		else
			self:delete()
		end
	end
end

local function callbackC(trigger_name, self, callback)
	if self.int.obj:isDeleted() then
		TimedTrigger.remove(trigger_name)
		return
	end
	
	callback(self, self.int.obj)
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
	local obj_name = 'particle_emitter_' .. Util.randomName()
	obj:registerObject(obj_name)
	
	local particle = {int = {
			obj = obj,
			name = emitter_name,
			dbg = obj_name
		}
	}
	
	
	function particle:delete()
		self.int.obj:delete()
	end
	
	function particle:velocity(velocity)
		self.int.obj:setField("Velocity", 0, velocity)
		return self
	end
	
	function particle:getVelocity()
		return self.int.obj.velocity
	end
	
	function particle:active(state)
		self.int.obj:setActive(state)
		return self
	end
	
	function particle:setPosition(pos_vec)
		self.int.obj:setPosition(pos_vec)
		return self
	end
	
	function particle:setRotation(rot_quat)
		local pos_vec = self.int.obj:getPosition()
		self.int.obj:setPosRot(
			pos_vec.x, pos_vec.y, pos_vec.z,
			rot_quat.x, rot_quat.y, rot_quat.z, rot_quat.w
		)
		return self
	end
	
	-- Requires that the obj has the :isDeleted() method.
	-- Vehicles dont have that!
	-- All objects from the ObjectWrapper have it.
	function particle:bind(obj, delete_after)
		local trigger_name = TimedTrigger.getUnused('Particle_bind_' .. self.int.name)
		TimedTrigger.new(
			trigger_name,
			100,
			0,
			bind,
			trigger_name,
			self,
			obj,
			delete_after or 0
		)
		
		return self
	end
	
	-- obj must have :getPosition() method and return a vec3
	function particle:follow(obj, for_time)
		local trigger_name = TimedTrigger.getUnused('Particle_follow_' .. self.int.name)
		TimedTrigger.new(
			trigger_name,
			0,
			0,
			follow,
			trigger_name,
			PauseTimer.new(),
			for_time or 0,
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
		local trigger_name = TimedTrigger.getUnused('Particle_followC_' .. self.int.name)
		TimedTrigger.new(
			trigger_name,
			0,
			0,
			followCallback,
			trigger_name,
			PauseTimer.new(),
			for_time or 0,
			self,
			obj,
			callback
		)
		
		return self
	end
	
	--[[
		Callback can have
			function(
				self,
				emitter
			)
	]]
	function particle:attachC(callback)
		local trigger_name = TimedTrigger.getUnused('Particle_attachC_' .. self.int.name)
		TimedTrigger.new(
			trigger_name,
			0,
			0,
			callbackC,
			trigger_name,
			self,
			callback
		)
		
		return self
	end
	
	function particle:selfDisable(after)
		local r = TimedTrigger.newF(
			'Particle_selfdisable_' .. self.int.name,
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
		local r = TimedTrigger.newF(
			'Particle_selfdestruct_' .. self.int.name,
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
