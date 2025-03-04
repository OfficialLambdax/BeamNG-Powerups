--[[
	This is a wrapper for the engine own objects like TSStatic.
	But it works with any, as it just inherits the entire interface of the object.
	
	So you can work with the returned object as if you do with the actual.
	Difference is that it gives you the option to have it return nil when the object doesnt exist anymore instead of just crashing the game.
	
	local obj = createObject("TSStatic")
	print(obj:getPosition()) -- works
	obj:delete()
	print(obj:getPosition()) -- game crash
	
	But with this wrapper it will just return nil.
	
	Why? Is usefull when multiple systems interact with the same objects and it aint easily possible to tell everyone "hey object gone"
]]

-- package.loaded["libs/ObjectWrapper"] = nil; require("libs/ObjectWrapper")("TSStatic")

local ObjectCleaner = require("libs/ObjectWrapperCleaner")
local Timer = require("mp_libs/PauseTimer")
local TimedTrigger = require("libs/TimedTrigger")
local Util = require("libs/Util")

local OBJ_REUSE_WHITELIST = Util.tableVToK({"TSStatic"}) -- , "ParticleEmitterNode"
--[[
	["obj_name"] = table
		["ref_name"] = object
]]
local OBJ_REUSE = {}

--[[
	["obj_name"] = table
		["ref_name"] = table
			[timer] = timer -- this is crying to fail
			[obj] = object
]]
local OBJ_REUSE_WAIT = {}

-- ----------------------------------------------------------------------------
-- Reuse. WIP
local function reuseCheck()
	for type, objects in pairs(OBJ_REUSE_WAIT) do
		for ref_name, data in pairs(objects) do
			if data.timer:stop() > 60000 then
				OBJ_REUSE[type][ref_name] = data.obj
				objects[ref_name] = nil
			end
		end
	end
end

local function reuseTake(name)
	if not OBJ_REUSE_WHITELIST[name] then return end
	
	local ref_name, object = next(OBJ_REUSE[name])
	if ref_name == nil then return end
	
	OBJ_REUSE[name][ref_name] = nil
	
	object.int.is_pending = false
	object.int.is_deleted = false
	
	dump('Reusing: ' .. name, Util.tableSize(OBJ_REUSE_WAIT[name]), Util.tableSize(OBJ_REUSE[name]))
	return object
end

local function reusePut(object)
	local name = object:getClassName()
	if not OBJ_REUSE_WHITELIST[name] then return end
	
	local ref_name = tostring(object)
	if OBJ_REUSE_WAIT[ref_name] or OBJ_REUSE[ref_name] then return true end
	
	object.int.is_pending = true
	
	--if object.setActive then
	--	object:setActive(false)
	--else
		object:unregisterObject()
	--end
	
	OBJ_REUSE_WAIT[name][ref_name] = {timer = Timer.new(), obj = object}
	return true
end

local function reuseInit()
	for type, _ in pairs(OBJ_REUSE_WHITELIST) do
		OBJ_REUSE_WAIT[type] = {}
		OBJ_REUSE[type] = {}
	end
	
	TimedTrigger.new(
		'ObjectWrapper_check',
		60000,
		0,
		reuseCheck
	)
end
reuseInit()

-- ----------------------------------------------------------------------------
-- Ripperoni from http://github.com/kikito/inspect.lua
-- MIT license
local function rawpairs(t)
  return next, t, nil
end

local function isSequenceKey(k, sequenceLength)
  return type(k) == 'number'
     and 1 <= k
     and k <= sequenceLength
     and math.floor(k) == k
end

local function getSequenceLength(t)
  local len = 1
  local v = rawget(t,len)
  while v ~= nil do
    len = len + 1
    v = rawget(t,len)
  end
  return len - 1
end

local function getNonSequentialKeys(t)
  local keys, keysLength = {}, 0
  local sequenceLength = getSequenceLength(t)
  for k,_ in rawpairs(t) do
    if not isSequenceKey(k, sequenceLength) then
      keysLength = keysLength + 1
      keys[keysLength] = k
    end
  end
  table.sort(keys, sortKeys)
  return keys, keysLength, sequenceLength
end

-- ----------------------------------------------------------------------------
-- Wrapper
return function(name)
	local obj = reuseTake(name)
	if obj then return obj end
	
	local obj = createObject(name)
	if obj == nil then return nil end
	
	local wrapper = {int = {
			obj = obj,
			is_deleted = false,
			is_pending = false
		}
	}
	
	local meta = getmetatable(obj)
	local keys, non_sequential_seys_length, sequence_length = getNonSequentialKeys(meta)
	for index = 1, non_sequential_seys_length, 1 do
		local key = keys[index]
		
		if type(meta[key]) == "function" then
			if key ~= "delete" then
				wrapper[key] = function(self, ...)
					if self.int.is_deleted then return end
					return self.int.obj[key](self.int.obj, ...)
				end
			end
		else
			wrapper[key] = obj[key]
		end
	end
	
	for index = 1, sequence_length, 1 do
		wrapper[index] = obj[index]
	end
	
	function wrapper:delete(total)
		if self.int.is_deleted and not total then return end
		
		if total then
			if not self.int.is_deleted or self.int.is_pending then
				self.int.is_deleted = false
				local name = self:getClassName()
				if OBJ_REUSE_WHITELIST[name] then
					local ref_name = tostring(self)
					OBJ_REUSE_WAIT[name][ref_name] = nil
					OBJ_REUSE[name][ref_name] = nil
				end
				
				self.int.obj:delete()
				self.int.is_deleted = true
				self.int.is_pending = true
			end
		else
			if not reusePut(self) then
				self.int.obj:delete()
				ObjectCleaner.unregister(self)
			end
		end

		self.int.is_deleted = true
	end
	
	function wrapper:isDeleted()
		return self.int.is_deleted
	end
	
	-- could be that we have to inherit more
	setmetatable(wrapper, {
			__newindex = function(self, key, value)
				if self.int.is_deleted then return end
				meta.__newindex(self.int.obj, key, value)
			end,
			
			__index = function(self, key)
				if self.int.is_deleted then return end
				return meta.__index(self.int.obj, key)
			end
		}
	)
	
	ObjectCleaner.register(wrapper)
	return wrapper
end
