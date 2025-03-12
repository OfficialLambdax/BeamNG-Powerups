--[[
	License: None
	Author: Neverless (discord: neverless.)
]]
local Util = require("libs/Util")

local M = {}

local GAME_GETALLVEHICLES = getAllVehicles

-- overwrites the game own getAllVehicles() function in the scope of this file
local function getAllVehicles(also_disabled)
	local vehicles = {}
	for _, vehicle in ipairs(GAME_GETALLVEHICLES()) do
		if vehicle:getActive() or also_disabled then table.insert(vehicles, vehicle) end
	end
	return vehicles
end

M.getPosInFront = function(pos_vec, dir_vec, distance)
	return pos_vec + (dir_vec:normalized() * distance)
end

M.createCone = function(start_vec, dir_vec, len, radius)
	local dir_vec = dir_vec:normalized()
	local m90 = vec3(-dir_vec.y, dir_vec.x, dir_vec.z)
	local cone_center = M.getPosInFront(start_vec, dir_vec, len)
	
	local cone = {
		start = start_vec,
		center = cone_center,
		
		c_b = vec3(cone_center.x, cone_center.y, cone_center.z - radius),
		c_t = vec3(cone_center.x, cone_center.y, cone_center.z + radius),
		
		c_r = (start_vec + (dir_vec * len)) - (m90 * radius),
		c_l = (start_vec + (dir_vec * len)) + (m90 * radius),
	}
	--dump(cone)
	return cone
end

M.drawCone = function(cone, no_start)
	debugDrawer:drawSphere(cone.center, 1, ColorF(0,1,1,1))
	debugDrawer:drawText(cone.center, "c", ColorF(0,0,0,1))
	if not no_start then
		debugDrawer:drawSphere(cone.start, 1, ColorF(0,1,1,1))
		debugDrawer:drawText(cone.start, "s", ColorF(0,0,0,1))
	end
	for name, pos in pairs(cone) do
		if name ~= "center" and name ~= "start" then
			debugDrawer:drawSphere(pos, 1, ColorF(1,1,1,1))
			debugDrawer:drawText(pos, name, ColorF(0,0,0,1))
		end
	end
end

M.drawConeLikeTarget = function(cone)
	debugDrawer:drawText(cone.center, "x", ColorF(0,0,0,1))
	debugDrawer:drawText(cone.c_b, "|", ColorF(0,0,0,1))
	debugDrawer:drawText(cone.c_t, "|", ColorF(0,0,0,1))
	debugDrawer:drawText(cone.c_r, "-", ColorF(0,0,0,1))
	debugDrawer:drawText(cone.c_l, "-", ColorF(0,0,0,1))
end

M.getVehiclesInsideCone = function(cone, ...)
	local blacklist = Util.tableVToK({...})
	local cone_axis = cone.center - cone.start
	local cone_axis_length = cone_axis:length()
	
	local vehicles = {}
	for _, vehicle in ipairs(getAllVehicles()) do
		if not blacklist[vehicle:getId()] then
		
			local vector_to_check = vehicle:getPosition() - cone.start
			local projection_length = vector_to_check:dot(cone_axis) / cone_axis_length
			if projection_length > 0 and projection_length < cone_axis_length then
				local check_projection = vec3(
					cone_axis.x * (projection_length / cone_axis_length),
					cone_axis.y * (projection_length / cone_axis_length),
					cone_axis.z * (projection_length / cone_axis_length)
				)
				
				local cone_radius_at_projection = (projection_length / cone_axis_length) * (cone.c_l - cone.center):length()
				if (vector_to_check - check_projection):length() <= cone_radius_at_projection then
					table.insert(vehicles, vehicle:getId())
				end
			end
		end
	end
	
	return vehicles
end
	
M.createBox = function(center_vec, dir_vec, len, wide, height)
	local dir_vec = dir_vec:normalized()
	local m90 = vec3(-dir_vec.y, dir_vec.x, dir_vec.z)
	local p_dir = center_vec + (dir_vec * len)
	local m_dir = center_vec + (dir_vec * -len)
	local p_ang = m90 * wide
	local m_ang = m90 * -wide
	local height_vec = vec3(0, 0, height / 2)
	
	local box = {
		center = center_vec,
		
		b_x1 = p_dir + p_ang - height_vec,
		b_x2 = m_dir + p_ang - height_vec,
		b_y1 = p_dir + m_ang - height_vec,
		b_y2 = m_dir + m_ang - height_vec,
		
		t_x1 = p_dir + p_ang + height_vec,
		t_x2 = m_dir + p_ang + height_vec,
		t_y1 = p_dir + m_ang + height_vec,
		t_y2 = m_dir + m_ang + height_vec
	}
	--dump(box)
	return box
end

M.drawBox = function(box)
	debugDrawer:drawSphere(box.center, 1, ColorF(0,1,1,1))
	for name, pos in pairs(box) do
		if name ~= "center" then
			debugDrawer:drawSphere(pos, 1, ColorF(1,1,1,1))
			debugDrawer:drawText(pos, name, ColorF(0,0,0,1))
		end
	end
end

-- Error prone as this doesnt care about the boxes angle at all
--[[_________
   |     /\  |
   |    /  \ |
   |   /    \|   y
   |  /     /|
   | /     / |
   |/     /  |
   |\    /   |
   | \  /  x |  Imagine the X as the vehicle. It would be detected. While the y would not.
   |  \/     |
]]
M.getVehiclesInsideBoxCheap = function(box, ...)
	local blacklist = Util.tableVToK({...})
	local box_min = {
		x = math.min(box.b_x1.x, box.b_x2.x, box.b_y1.x, box.b_y2.x, box.t_x1.x, box.t_x2.x, box.t_y1.x, box.t_y2.x),
		y = math.min(box.b_x1.y, box.b_x2.y, box.b_y1.y, box.b_y2.y, box.t_x1.y, box.t_x2.y, box.t_y1.y, box.t_y2.y),
		z = math.min(box.b_x1.z, box.b_x2.z, box.b_y1.z, box.b_y2.z, box.t_x1.z, box.t_x2.z, box.t_y1.z, box.t_y2.z)
	}
			
	local box_max = {
		x = math.max(box.b_x1.x, box.b_x2.x, box.b_y1.x, box.b_y2.x, box.t_x1.x, box.t_x2.x, box.t_y1.x, box.t_y2.x),
		y = math.max(box.b_x1.y, box.b_x2.y, box.b_y1.y, box.b_y2.y, box.t_x1.y, box.t_x2.y, box.t_y1.y, box.t_y2.y),
		z = math.max(box.b_x1.z, box.b_x2.z, box.b_y1.z, box.b_y2.z, box.t_x1.z, box.t_x2.z, box.t_y1.z, box.t_y2.z)
	}
	
	local vehicles = {}
	for _, vehicle in pairs(getAllVehicles()) do
		local veh_id = vehicle:getId()
		if not blacklist[veh_id] then
			local pos = vehicle:getPosition()
			if
				pos.x >= box_min.x and pos.x <= box_max.x and
				pos.y >= box_min.y and pos.y <= box_max.y and
				pos.z >= box_min.z and pos.z <= box_max.z
			then
				
				table.insert(vehicles, veh_id)
			end
		end
	end
	
	return vehicles
end

M.getVehiclesInsideBox = function(box, ...)
	local blacklist = Util.tableVToK({...})
	local vertices = {box.b_x1, box.b_x2, box.b_y1, box.b_y2, box.t_x1, box.t_x2, box.t_y1, box.t_y2}
	local edges = {
		box.b_x2 - box.b_x1,
		box.b_y1 - box.b_x1,
		box.t_x1 - box.b_x1
	}
	local axes = {}
	for i = 1, 3 do
		for j = i + 1, 3 do
			table.insert(axes, edges[i]:cross(edges[j]))
		end
	end
	
	local dist3d = Util.dist3d
	local radius = dist3d(box.center, box.b_x1)
	
	local vehicles = {}
	for _, vehicle in ipairs(getAllVehicles()) do
		local veh_id = vehicle:getId()
		if not blacklist[veh_id] then
			local veh_pos = vehicle:getPosition()
			if dist3d(veh_pos, box.center) < radius then -- if vehicle is not even close then no point checking
				local is_inside = true
				for _, axis in ipairs(axes) do
					local min, max = math.huge, -math.huge
					local point_projection = veh_pos:dot(axis)
					
					for _, vertex in ipairs(vertices) do
						local projection = vertex:dot(axis)
						min = math.min(min, projection)
						max = math.max(max, projection)
					end
					
					if not (point_projection >= min and point_projection <= max) then
						is_inside = false
						break
					end
				end
				
				if is_inside then table.insert(vehicles, veh_id) end
			end
		end
	end
	
	return vehicles
end

M.getVehiclesInsideRadius = function(pos_vec, radius, ...)
	local blacklist = Util.tableVToK({...})
	local vehicles = {}
	for _, vehicle in ipairs(getAllVehicles()) do
		local veh_id = vehicle:getId()
		if not blacklist[veh_id] then
			if Util.dist3d(pos_vec, vehicle:getPosition()) < radius then
				table.insert(vehicles, veh_id)
			end
		end
	end
	return vehicles
end

M.getVehiclesInsideRadius2d = function(pos_vec, radius, ...)
	local blacklist = Util.tableVToK({...})
	local vehicles = {}
	for _, vehicle in ipairs(getAllVehicles()) do
		local veh_id = vehicle:getId()
		if not blacklist[veh_id] then
			if Util.dist2d(pos_vec, vehicle:getPosition()) < radius then
				table.insert(vehicles, veh_id)
			end
		end
	end
	return vehicles
end

M.velocity = function(vel_vec)
	return math.sqrt(vel_vec.x^2 + vel_vec.y^2 + vel_vec.z^2)
end

-- Usefull for high speed projectiles or high dt values where lag induces imprecision
M.getCollisionsAlongSideLine = function(from_vec, to_vec, radius, ...)
	local dist3d = Util.dist3d
	local distance = dist3d(from_vec, to_vec)
	local dir_vec = (to_vec - from_vec):normalized()
	local current_pos = from_vec
	while true do
		-- check from_vec first
		local vehicles = M.getVehiclesInsideRadius(current_pos, radius, ...)
		if #vehicles > 0 then return vehicles end
		
		-- step by radius
		current_pos = current_pos + (dir_vec * radius)
		
		-- if we overshot then break
		if dist3d(current_pos, to_vec) > distance then break end
	end
	
	-- check to_vec last (just in case we overshot it)
	return M.getVehiclesInsideRadius(to_vec, radius, ...)
end

-- for collisions with statics
M.raycastAlongSideLine = function(from_vec, to_vec)
	-- castRayStatic(cornerPos, dirTemp, dirLength)
	local dir_vec = (to_vec - from_vec):normalized()
	local length = Util.dist3d(from_vec, to_vec)
	
	local hit_dist = castRayStatic(from_vec, dir_vec, length)
	if hit_dist < length then
		return hit_dist
	end
end

M.rotateVectorByDegrees = function(for_vec, up_vec, degrees) -- where degree is 
	local a = for_vec
	local b = up_vec
	local q = degrees
	local c = a:cross(b)
	
	local term1 = a * math.cos(q)
	return vec3(
		term1.x + (c.x * math.sin(q)),
		term1.y + (c.y * math.sin(q)),
		term1.z + (c.z * math.sin(q))
	)
end

M.getPredictedPosition = function(origin_vehicle, target_vehicle, proj_speed)
	local org_pos = origin_vehicle:getSpawnWorldOOBB():getCenter()
	
	local tar_pos = target_vehicle:getSpawnWorldOOBB():getCenter()
	local tar_vel = target_vehicle:getVelocity()
	
	local dist = Util.dist3d(org_pos, tar_pos)
	local time = dist / proj_speed
	
	local new_pos = tar_pos + (tar_vel * time)
	--debugDrawer:drawSphere(new_pos, 1, ColorF(1,1,1,1))
	
	return new_pos
end

M.getPredictedPositionRaw = function(org_pos, tar_pos, tar_vel, proj_speed)
	local dist = Util.dist3d(org_pos, tar_pos)
	local time = dist / proj_speed
	
	local new_pos = tar_pos + (tar_vel * time)
	--debugDrawer:drawSphere(new_pos, 1, ColorF(1,1,1,1))
	
	return new_pos
end

M.isMovingTowards = function(our_pos, tar_pos, tar_vel_vec)
	-- calculating a previous position and looking if that was further away then the current is better then calculating forward. Because if our_pos is very close to tar_pos the ahead calc may calculate a position behind our_pos
	local cur_dist = Util.dist3d(our_pos, tar_pos)
	local pre_dist = Util.dist3d(our_pos, tar_pos + (tar_vel_vec * -0.1))
	return pre_dist > cur_dist
end

M.disperseVec = function(dir_vec, strength)
	dir_vec = dir_vec:normalized()
	dir_vec.x = dir_vec.x + (math.random(0 - strength, 0 + strength) / 100)
	dir_vec.y = dir_vec.y + (math.random(0 - strength, 0 + strength) / 100)
	dir_vec.z = dir_vec.z + (math.random(0 - strength, 0 + strength) / 100)
	return dir_vec
end

M.inRange = function(num1, num2, range)
	return (num1 - num2) < range
end

M.alignToSurfaceZ = function(pos_vec, max)
	local pos_z = be:getSurfaceHeightBelow(vec3(pos_vec.x, pos_vec.y, pos_vec.z + 2))
	if pos_z < -1e10 then return end -- "the function returns -1e20 when the raycast fails"
	if max and math.abs(pos_vec.z - pos_z) > max then return end
	
	return vec3(pos_vec.x, pos_vec.y, pos_z)
end

M.surfaceHeight = function(pos_vec)
	local pos_z = be:getSurfaceHeightBelow(vec3(pos_vec.x, pos_vec.y, pos_vec.z + 2))
	if pos_z < -1e10 then return end -- "the function returns -1e20 when the raycast fails"
	return pos_z
end

-- This isnt fully functional
-- https://www.gamedev.net/forums/topic/56471-extracting-direction-vectors-from-quaternion/
M.quatFromQuatAndDir = function(rot_quat, dir_vec)
	--print(rot_quat)
	local up_vec = vec3(
		2 * (rot_quat.x * rot_quat.y - -rot_quat.w * rot_quat.z),
		1 - 2 * (rot_quat.x * rot_quat.x + rot_quat.z * rot_quat.z),
		2 * (rot_quat.y * rot_quat.z + -rot_quat.w * rot_quat.x)
	)
	--dump(2 * (rot_quat.x * rot_quat.y - -rot_quat.w * rot_quat.z))
	--dump(up_vec)
	return quatFromDir(up_vec, dir_vec)
	
	--local up_vec = vec3(2 - dir_vec.x, 2 - dir_vec.y, 2 - dir_vec.z):normalized()
	--print(dir_vec:normalized())
	--return quatFromDir(up_vec, dir_vec)
	
	--[[
	local for_vec = vec3(
		2 * (rot_quat.x * rot_quat.z + rot_quat.w * rot_quat.y),
		2 * (rot_quat.y * rot_quat.z - rot_quat.w * rot_quat.x),
		1 - 2 * (rot_quat.x * rot_quat.x + rot_quat.y * rot_quat.y)
	)
	return quatFromDir(for_vec, dir_vec)
	]]
	
	--[[
	local left_vec = vec3(
		1 - 2 * (rot_quat.y * rot_quat.y + rot_quat.z * rot_quat.z),
		2 * (rot_quat.x * rot_quat.y + rot_quat.w * rot_quat.z),
		2 * (rot_quat.w * rot_quat.z - rot_quat.w * rot_quat.y)
	)
	return quatFromDir(left_vec, dir_vec)
	]]
end

-- This isnt fully functional
-- https://gamedev.stackexchange.com/questions/69649/using-atan2-to-calculate-angle-between-two-vectors
M.dirAngle = function(dir_vec1, dir_vec2)
	--return math.acos(dir_vec1:dot(dir_vec2))
	return math.abs(math.atan2(dir_vec1.y, dir_vec1.x) - math.atan2(dir_vec2.y, dir_vec2.x))
	--return math.acos(dir_vec1:dot(dir_vec2) / (dir_vec1:length() * dir_vec2:length()))
end

return M