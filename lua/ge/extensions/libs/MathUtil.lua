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

M.disperseVec = function(dir_vec, strength)
	dir_vec = dir_vec:normalized()
	dir_vec.x = dir_vec.x + (math.random(0 - strength, 0 + strength) / 100)
	dir_vec.y = dir_vec.y + (math.random(0 - strength, 0 + strength) / 100)
	dir_vec.z = dir_vec.z + (math.random(0 - strength, 0 + strength) / 100)
	return dir_vec
end


return M