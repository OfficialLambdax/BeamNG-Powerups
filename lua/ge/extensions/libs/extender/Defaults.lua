local Util = require("libs/Util")
local Particle = require("libs/Particles")

local M = {}
--[[
	["shape_path"] = table
		["color point as string"] = Point4F
]]
local NEGATIVE_LIST = {}


-- ------------------------------------------------------------------------------------------------
-- Default powerup creator
M.powerupCreator = function(trigger_obj, shape_path, color_point, is_rendered)
	local pos = trigger_obj:getPosition()
	
	local marker = createObject("TSStatic")
	marker.shapeName = shape_path
	marker.useInstanceRenderData = 1
	marker.instanceColor = color_point
	local rot = QuatF(0, 0, 0, 0)
	rot:setFromEuler(vec3(math.random(), math.random(), math.random()))
	marker:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
	--marker.scale = trigger_obj:getScale()
	marker.scale = vec3(2, 2, 2)
	marker:registerObject("lib_default_powerup_" .. Util.randomName())
	
	if is_rendered == nil then is_rendered = true end
	if is_rendered then
		Particle("DefaultEmitter", vec3(pos.x, pos.y, pos.z - 1))
			:active(true)
			:velocity(5)
			:selfDisable(1000)
			:selfDestruct(3000)
			
	else
		marker:setHidden(true)
	end
	
	if NEGATIVE_LIST[shape_path] == nil then NEGATIVE_LIST[shape_path] = {} end
	NEGATIVE_LIST[shape_path][tostring(color_point)] = color_point
	
	return marker
end

M.powerupRender = function(marker_obj, dt)
	if marker_obj == nil then return end
	local pos = marker_obj:getPosition()
	local rot = marker_obj:getRotation():toEuler()
		
	rot.x = rot.x + (0.5 * dt)
	rot.y = rot.y + (0.5 * dt)
	local new_rot = QuatF(0, 0, 0, 0)
	new_rot:setFromEuler(rot)
	marker_obj:setPosRot(pos.x, pos.y, pos.z, new_rot.x, new_rot.y, new_rot.z, new_rot.w)
end

M.powerupDelete = function(marker_obj)
	if marker_obj then
		marker_obj:delete()
	end
end

-- ------------------------------------------------------------------------------------------------
-- Default charge powerup creator
M.powerupChargeCreator = function(trigger_obj, is_rendered)
	local pos = trigger_obj:getPosition()
	
	local marker = createObject("TSStatic")
	marker.shapeName = "art/shapes/collectible/s_marker_BNG.cdae"
	marker.useInstanceRenderData = 1
	marker.instanceColor = Point4F(
		math.random(),
		math.random(),
		math.random(),
		1
	)
	local rot = QuatF(0, 0, 0, 0)
	rot:setFromEuler(vec3(math.random(), math.random(), math.random()))
	marker:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
	marker.scale = vec3(2, 2, 2)
	marker:registerObject("lib_default_powerup_" .. Util.randomName())
	
	local particle = Particle("DefaultEmitter", vec3(pos.x, pos.y, pos.z + 0.75)):velocity(-3)
	local particle2 = Particle("DefaultEmitter", vec3(pos.x, pos.y, pos.z - 1.1)):velocity(-0.5)
	
	if is_rendered == nil then is_rendered = true end
	if is_rendered then
		particle:active(true)
		particle2:active(true)
	else
		marker:setHidden(true)
		particle:active(false)
		particle2:active(false)
	end

	return {
		step = math.random(1, 6),
		obj = marker,
		particle = particle,
		particle2 = particle2
	}
end

M.powerupChargeLoader = function(marker, state)
	if marker.obj == nil then return end
	
	marker.obj:setHidden(not state)
	marker.particle:active(state)
	marker.particle2:active(state)
end

M.powerupChargeRender = function(marker, dt)
	if marker.obj == nil then return end
	local pos = marker.obj:getPosition()
	local rot = marker.obj:getRotation():toEuler()
	
	rot.x = rot.x + (0.5 * dt)
	rot.y = rot.y + (0.5 * dt)
	local new_rot = QuatF(0, 0, 0, 0)
	new_rot:setFromEuler(rot)
	marker.obj:setPosRot(pos.x, pos.y, pos.z, new_rot.x, new_rot.y, new_rot.z, new_rot.w)
	
	local color = marker.obj.instanceColor
	local change = 1
	
	if marker.step == 1 then -- until g == 1
		color.y = color.y + (change * dt)
		if color.y >= 1 then
			color.y = 1
			marker.step = 2
		end
		
	elseif marker.step == 2 then -- unitl r == 0
		color.x = color.x - (change * dt)
		if color.x <= 0 then
			color.x = 0
			marker.step = 3
		end
		
	elseif marker.step == 3 then -- until b == 1
		color.z = color.z + (change * dt)
		if color.z >= 1 then
			color.z = 1
			marker.step = 4
		end
		
	elseif marker.step == 4 then -- until g == 0
		color.y = color.y - (change * dt)
		if color.y <= 0 then
			color.y = 0
			marker.step = 5
		end
		
	elseif marker.step == 5 then -- until r == 1
		color.x = color.x + (change * dt)
		if color.x >= 1 then
			color.x = 1
			marker.step = 6
		end
		
	elseif marker.step == 6 then -- until b == 0
		color.z = color.z - (change * dt)
		if color.z <= 0 then
			color.z = 0
			marker.step = 1
		end
		
	end
	
	marker.obj.instanceColor = color
end

M.powerupChargeDelete = function(marker)
	if marker.obj then
		marker.obj:delete()
		marker.particle:delete()
		marker.particle2:delete()
		marker.obj = nil
	end
end

-- ------------------------------------------------------------------------------------------------
-- Default negative powerup creator
M.powerupNegativeCreator = function(trigger_obj, is_rendered)
	local pos = trigger_obj:getPosition()
	
	local shape_path, colors = Util.tablePickRandom(NEGATIVE_LIST) or "art/shapes/collectible/s_marker_BNG.cdae", {Point4F(1, 0, 0, 1)}
	
	local _, color_point = Util.tablePickRandom(colors)
	
	local marker = createObject("TSStatic")
	marker.shapeName = shape_path
	marker.useInstanceRenderData = 1
	marker.instanceColor = color_point
	local rot = QuatF(0, 0, 0, 0)
	rot:setFromEuler(vec3(math.random(), math.random(), math.random()))
	marker:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
	marker.scale = vec3(2, 2, 2)
	marker:registerObject("lib_default_powerup_" .. Util.randomName())
	
	local particle = Particle("PWU_Shady", vec3(pos.x, pos.y, pos.z)):velocity(0.2)
	
	if is_rendered == nil then is_rendered = true end
	if is_rendered then
		particle:active(true)
	else
		marker:setHidden(true)
		particle:active(false)
	end

	return {
		obj = marker,
		particle = particle,
	}
end

M.powerupNegativeRender = function(obj, dt)
	if obj.obj == nil then return end
	local pos = obj.obj:getPosition()
	local rot = obj.obj:getRotation():toEuler()
	
	rot.x = rot.x + (0.5 * dt)
	rot.y = rot.y + (0.5 * dt)
	local new_rot = QuatF(0, 0, 0, 0)
	new_rot:setFromEuler(rot)
	obj.obj:setPosRot(pos.x, pos.y, pos.z, new_rot.x, new_rot.y, new_rot.z, new_rot.w)
end

M.powerupNegativeLoader = function(obj, state)
	if obj.obj == nil then return end
	
	obj.obj:setHidden(not state)
	obj.particle:active(state)
end

M.powerupNegativeDelete = function(obj)
	if obj.obj then
		obj.obj:delete()
		obj.particle:delete()
		obj.obj = nil
	end
end

return M
