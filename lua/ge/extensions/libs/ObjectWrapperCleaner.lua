
local Util = require("libs/Util")

local M = {}
local OBJECTS = {}


M.register = function(obj)
	OBJECTS[tostring(obj)] = obj
end

M.unregister = function(obj)
	OBJECTS[tostring(obj)] = nil
end

M.destroyAll = function()
	for index, obj in pairs(OBJECTS) do
		obj:delete()
		OBJECTS[index] = nil
	end
end

M.count = function() return Util.tableSize(OBJECTS) end

return M
