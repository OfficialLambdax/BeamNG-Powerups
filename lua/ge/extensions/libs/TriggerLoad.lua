--[[
	License: None
	Author: Neverless (discord: neverless.)
]]
local M = {
	_VERSION = "0.1" -- 06.02.2025 DD.MM.YYYY
}
local TRACKER = {}



local function fileName(string)
	local str = string:sub(1):gsub("\\", "/")
	local _, pos = str:find(".*/")
	if pos == nil then return string end
	return str:sub(pos + 1, -1)
end

local function cleanseName(file)
	local file = fileName(file)
	local final, _ = file:find('%.')
	if final then final = final - 1 end
	
	return file:sub(1, final)
end

local function splitByNewline(string)
	local lines = {}
	for str in string:gmatch("[^\r\n]+") do
		table.insert(lines, str)
	end
	
	return lines
end

M.loadTriggerPrefab = function(prefab_path, debug)
	local handle = io.open(prefab_path, "r")
	if handle == nil then return nil, "Cannot open file in read mode" end
	
	local trigger_list = handle:read("*all")
	handle:close()
	
	local debug = tostring(debug or false)
	
	local triggers = {}
	for _, v in pairs(splitByNewline(trigger_list)) do
		local decode = jsonDecode(v)
		if decode.class == "BeamNGTrigger" then
			
			local pos = decode.position
			local rot = decode.rotationMatrix
			local scale = decode.scale or {1, 1, 1}
			local name = 'TL_' .. cleanseName(prefab_path) .. '_' .. decode.name
			if TRACKER[name] then TRACKER[name]:delete() end
			local trigger
			
			if createObject then -- game
				local matrix = MatrixF()
				matrix:setColumn(0, vec3(rot[1], rot[2], rot[3]))
				matrix:setColumn(1, vec3(rot[4], rot[5], rot[6]))
				matrix:setColumn(2, vec3(rot[7], rot[8], rot[9]))
				matrix:setColumn(3, vec3(0, 0, 0))
				local quat = matrix:toQuatF()
				
				trigger = createObject("BeamNGTrigger")
				trigger.useInstanceRenderData = 1
				trigger.instanceColor = Point4F(1, 0, 0, 1)
				trigger:setPosRot(pos[1], pos[2], pos[3], quat.x, quat.y, quat.z, quat.w)
				trigger.scale = vec3(scale[1], scale[2], scale[3])
				
				trigger:setField("debug", 0, debug)
				trigger:registerObject(name)
				
			else -- server compat
				trigger = {int = {
						name = name,
						pos = {
							x = pos[1],
							y = pos[2],
							z = pos[3]
						},
						rot = {
							x = 0,
							y = 0,
							z = 0,
							w = 0
						},
						scale = {
							x = scale[1],
							y = scale[2],
							z = scale[3]
						}
					}
				}
				
				function trigger:getName()
					return self.int.name
				end
				
				function trigger:getPosition()
					return self.int.pos
				end
				
				function trigger:getRotation()
					return self.int.rot
				end
				
				function trigger:getScale()
					return self.int.scale
				end
				
				function trigger:setScale(vec)
					self.int.scale = vec
				end
				
				function trigger:setField() end -- does nothing
			end
			
			triggers[name] = trigger
			table.insert(TRACKER, trigger)
		end
	end
	
	return triggers
end

M.destroy = function(triggers)
	for _, trigger in pairs(triggers) do
		trigger:delete()
	end
end

M.unload = function()
	for _, trigger in pairs(TRACKER) do
		--if trigger then trigger:delete() end
	end
end

return M
