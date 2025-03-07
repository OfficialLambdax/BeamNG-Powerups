
-- package.loaded["libs/Placeables"] = nil; TEST = require("libs/Placeables")(vec3(0, 0, 0), vec3(3, 3, 3))

local Util = require("libs/Util")
local Log = require("libs/Log")
local TimedTrigger = require("libs/TimedTrigger")
local PauseTimer = require("mp_libs/PauseTimer")
local createObject = require("libs/ObjectWrapper")

--[[
	Format
	["trigger_name"] = ref placables
]]
local PLACEABLES = {}


function onPlaceableTrigger(data)
	local placeable = PLACEABLES[data.triggerName]
	if placeable then
		if data.event == "enter" then
			placeable:_onEnter(data)
		elseif data.event == "exit" then
			placeable:_onExit(data)
		end
	end
end


return function(pos_vec, scale_vec)
	local obj = createObject("BeamNGTrigger")
	obj:setPosition(pos_vec)
	obj:setScale(scale_vec)
	obj:setField("TriggerMode", 0, "Overlaps")
	obj:setField("TriggerTestType", 0, "Bounding box")
	obj:setField("luaFunction", 0, "onPlaceableTrigger")
	--obj:setField("debug", 0, "true")
	
	local name = "Placeable_" .. Util.randomName()
	obj:registerObject(name)
	
	local placeable = {int = {
			obj = obj,
			name = name,
			data = nil,
			vehicles = {},
			on_enter = nil,
			on_exit = nil,
			while_inside = nil,
			del_c = nil
		}
	}
	
	-- ------------------------------------------------------------------
	-- Logic
	-- callback(self, vehicle_obj, data)
	function placeable:onEnter(callback)
		self.int.on_enter = callback
		return self
	end
	
	-- callback(self, vehicle_obj, data)
	function placeable:whileInside(callback)
		self.int.while_inside = callback
		return self
	end
	
	-- callback(self, vehicle_obj, data)
	function placeable:onExit(callback)
		self.int.on_exit = callback
		return self
	end
	
	function placeable:attach(callback)
		TimedTrigger.new(
			'Placeable_attach_' .. self.int.name,
			0,
			0,
			function(self, data, callback)
				if self.int.obj:isDeleted() then
					TimedTrigger.remove('Placeable_attach_' .. self.int.name)
					return
				end
				
				callback(self, data)
			end,
			self,
			self.int.data,
			callback
		)
		return self
	end
	
	function placeable:unAttach()
		TimedTrigger.remove('Placeable_attach_' .. self.int.name)
		return self
	end
	
	function placeable:selfDestruct(life_time, callback)
		self:delC(callback)
		TimedTrigger.new(
			'Placeable_selfDestruct_' .. self.int.name,
			life_time,
			1,
			self.delete,
			self
		)
		return self
	end
	
	function placeable:delC(callback)
		self.int.del_c = callback
	end
	
	-- ------------------------------------------------------------------
	-- Access
	function placeable:setRotation(rot_quat)
		local pos = self.int.obj:getPosition()
		self.int.obj:setPosRot(pos.x, pos.y, pos.z, rot_quat.x, rot_quat.y, rot_quat.z, rot_quat.w)
		return self
	end
	
	function placeable:setData(data)
		self.int.data = data
		return self
	end
	
	function placeable:getData()
		return self.int.data
	end
	
	function placeable:getVehicles()
		return self.int.vehicles
	end
	
	function placeable:delete()
		self.int.obj:delete()
		TimedTrigger.remove('Placeable_whileInside_' .. self.int.name)
		TimedTrigger.remove('Placeable_selfDestruct_' .. self.int.name)
		TimedTrigger.remove('Placeable_attach_' .. self.int.name)
		
		if self.int.del_c then
			self.int.del_c(self, self.int.data)
		end
		PLACEABLES[self.int.name] = nil
	end
	
	--function placeable:deleteObj()
	--	self.int.obj:delete()
	--	return self
	--end
	
	-- ------------------------------------------------------------------
	-- Internal
	function placeable:_onEnter(data)
		self.int.vehicles[data.subjectID] = true
		
		if self.int.while_inside then
			TimedTrigger.new(
				'Placeable_whileInside_' .. self.int.name,
				0,
				0,
				self._whileInside,
				self
			)
		end
		
		if self.int.on_enter then
			self.int.on_enter(self, be:getObjectByID(data.subjectID), self.int.data)
		end
	end
	
	function placeable:_onExit(data)
		self.int.vehicles[data.subjectID] = nil
		
		if not Util.tableHasContent(self.int.vehicles) then
			TimedTrigger.remove('Placeable_whileInside_' .. self.int.name)
		end
		
		if self.int.on_exit then
			self.int.on_exit(self, be:getObjectByID(data.subjectID), self.int.data)
		end
	end
	
	function placeable:_whileInside()
		if self.int.while_inside then
			for vehicle_id, _ in pairs(self.int.vehicles) do
				local vehicle = be:getObjectByID(vehicle_id)
				if vehicle == nil then
					self.int.vehicles[vehicle_id] = nil
				
				else
					self.int.while_inside(
						self,
						vehicle,
						self.int.data
					)
				end
			end
		end
	end
	
	
	PLACEABLES[name] = placeable
	return placeable
end
