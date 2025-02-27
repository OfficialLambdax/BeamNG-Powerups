--[[
	License: None
	Author: Neverless (discord: neverless.)
]]

-- do not import MPUtil, that would cause a stack overflow

local CompileLua = require("mp_libs/CompileLua")

local M = {}
local RANDOM_COUNT = 0

local function extractNum(string)
	local extract = ""
	for str in string:gmatch("%d") do
		if tonumber(str) ~= nil then extract = extract .. str end
	end
	return extract
end

M.dtTimer = function()
	local timer = {
		timer = hptimer()
	}
	function timer:stop()
		return self.timer:stop() / 1000
	end
	function timer:stopAndReset()
		return self.timer:stopAndReset() / 1000
	end
	function timer:dt()
		return self:stopAndReset()
	end
	
	return timer
end

M.mathRandom = function(from, to)
	math.randomseed(os.time() + tonumber(extractNum(tostring({}):sub(8))) + RANDOM_COUNT)
	RANDOM_COUNT = RANDOM_COUNT + 11
	return math.random(from, to)
end

M.randomName = function()
	math.randomseed(os.time() + tonumber(extractNum(tostring({}):sub(8))) + RANDOM_COUNT)
	RANDOM_COUNT = RANDOM_COUNT + 11
	return tostring(math.random())
	--return tostring({}):sub(8)
end

M.mathRound = function(number, decimals)
	return tonumber(string.format("%." .. (decimals or 2) .. "f", number))
end

M.tableVToK = function(table)
	local new_table = {}
	for _, v in pairs(table) do
		new_table[v] = true
	end
	return new_table
end

-- basically just a way to quickly check if a table has any contents without fully counting it
M.tableHasContent = function(table)
	return #({next(table)}) > 0
end

M.tableSize = function(table)
	local size = 0
	for _, _ in pairs(table) do
		size = size + 1
	end
	return size
end

M.tablePickRandom = function(table)
	local size = M.tableSize(table)
	if size == 0 then return nil end
	
	local random_num = M.mathRandom(1, size)
	local index = 1
	for k, v in pairs(table) do
		if index == random_num then
			return k, v
		else
			index = index + 1
		end
	end
end

M.tableMerge = function(into, from)
	for k, v in pairs(from) do
		into[k] = v
	end
end

M.tableArrayMerge = function(into, from)
	for _, v in pairs(from) do
		table.insert(into, v)
	end
end

M.tableReset = function(table)
	for k, _ in pairs(table) do
		table[k] = nil
	end
end

M.tableContains = function(table, this)
	for _, v in ipairs(table) do
		if v == this then return true end
	end
	return false
end

M.dist3d = function(p1, p2)
	return math.sqrt((p2.x - p1.x)^2 + (p2.y - p1.y)^2 + (p2.z - p1.z)^2)
end

M.filePath = function(string)
	local _, pos = string:find(".*/")
	if pos == nil then return nil end
	
	return string:sub(1, pos)
end

M.myPath = function()
	local source_path = debug.getinfo(2).source:gsub("\\", "/")
	if source_path:sub(1, 1) == '@' then return M.filePath(source_path:sub(2)) end
	return M.filePath(source_path)
end

M.fileName = function(string)
	local str = string:sub(1):gsub("\\", "/")
	local _, pos = str:find(".*/")
	if pos == nil then return string end
	return str:sub(pos + 1, -1)
end

M.fileExtension = function(string)
	return string:match("[^.]+$")
end

M.compileLua = CompileLua.compileLua

M.listFiles = function(path)
	if FS.directoryList then -- if game
		local files = {}
		for _, path in pairs(FS:directoryList(path)) do
			if not FS:directoryExists(path) then
				table.insert(files, path)
			end
		end
		
		return files
		
	else
		-- if server
		local files = {}
		for _, file in ipairs(FS.ListFiles(path)) do
			table.insert(files, path .. '/' .. file)
		end
		return files
	end
end

M.split = function(string, delimeter, convert_into)
	local t = {}
	for str in string.gmatch(string, "([^"..delimeter.."]+)") do
		if convert_into == 1 then -- number
			table.insert(t, tonumber(str))
			
		elseif convert_into == 2 then -- bool
			if str:lower() == "false" then
				table.insert(t, false)
			elseif str:lower() == "true" then
				table.insert(t, false)
			end
			
		else -- string
			table.insert(t, str)
		end
	end
	return t
end


return M
