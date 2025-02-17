--[[
	This performs a pattern search on powerup files and all its imports to find potentially malicious code.
	Server side only
]]

local M = {}

local IS_BEAMMP_SERVER = type(MP) == "table" and type(MP.TriggerClientEvent) == "function"
local BAD_KEYWORDS = {"load", "pcall", "xpcall", "loadstring"}
local SPACES = {" ", "\t", "\n", "\r"}
local VALID_CHARS = {" ", "\t", "\n", "\r", "{", "}", ";", "=", ",", "(", ")"}
local FILE_INDEX
local WHITELISTED = {}

local function init()
	local reverse = {}
	for _, v in ipairs(SPACES) do
		reverse[v] = true
	end
	SPACES = reverse
	
	local reverse = {}
	for _, v in ipairs(VALID_CHARS) do
		reverse[v] = true
	end
	VALID_CHARS = reverse
	
	local reverse = {}
	for _, v in ipairs(WHITELISTED) do
		reverse[v] = true
	end
	WHITELISTED = reverse
end

local function tableConcat(into, from)
	for _, v in pairs(from) do
		table.insert(into, v)
	end
	return into
end

local function indexFilesRecursive(path)
	local all_files = {}
	local dir_contents = tableConcat(FS.ListDirectories(path), FS.ListFiles(path))
	for index, v in ipairs(dir_contents) do
		dir_contents[index] = path .. '/' .. v
		if FS.IsDirectory(dir_contents[index]) then
			tableConcat(all_files, indexFilesRecursive(dir_contents[index]))
		else
			table.insert(all_files, path .. '/' .. v)
		end
	end
	return all_files
end


local function findRequireInIndex(path)
	local finds = {}
	local path_lower = path:lower() .. '.lua'
	local len = path_lower:len() - 1
	for _, file in pairs(FILE_INDEX) do
		local file_len = file:len()
		local file_lower = file:lower()
		if file_lower:sub(file_len - len, file_len) == path_lower then
			table.insert(finds, file)
		end
	end
	return finds
end

local function encloseKeyword(contents, keyword)
	local enclosures = {}
	local last_pos = 1
	while true do
		
		local found_enclosure = false
		
		_, last_pos = contents:find(keyword, last_pos)
		if last_pos == nil then break end
		last_pos = last_pos + 1
		
		local char_before = contents:sub(last_pos - keyword:len() - 1, last_pos - keyword:len() - 1)
		local char_after = contents:sub(last_pos, last_pos)
		if VALID_CHARS[char_before] and VALID_CHARS[char_after] then
			-- find '(' after keyword
			local find_next = 0
			while true do
				local pos = last_pos + find_next
				local char = contents:sub(pos, pos)
				if char == nil then break end
				--[[
					Anything not a space makes this a potential function call.
						eg
						load(
						load (
						load	(
						load 
							(
				]]
				if not SPACES[char] then
					if char == '(' then
						local start = pos
						-- find ')' after '('
						while true do
							local pos = last_pos + find_next
							local char = contents:sub(pos, pos)
							if char == nil then break end
							--[[
								eg
								load()
								load(123)
								load(
									""
								)
							]]
							if char == ')' then
								local insert, _ = contents:sub(start + 1, pos - 1):gsub('%"', '')
								if insert:len() > 0 then
									table.insert(enclosures, insert)
									found_enclosure = true
								end
								break
							end
							find_next = find_next + 1
						end
					end
					break
				end
				
				find_next = find_next + 1
			end
			
			-- check if keyword is assigned. eg local my_var = keyword
			-- also check if keyword is apart of a table. eg {keyword}
			if not found_enclosure and VALID_CHARS[contents:sub(last_pos, last_pos)] then
				local find_before = 1
				while true do
					local pos = last_pos - keyword:len() - find_before
					local char = contents:sub(pos, pos)
					if char == nil then break end
					
					if not SPACES[char] then
						if char == '=' then
							return nil, 'Keyword "' .. keyword .. '" is assigned to a variable'
						elseif char == '{' or char == ',' then
							return nil, 'Keyword "' .. keyword .. '" is apart of a table'
						end
						break
					end
					
					find_before = find_before + 1
				end
			end
		end
	end
	return enclosures
end

local function checkFile(file_path)
	if WHITELISTED[file_path] then return "" end
	
	local handle = io.open(file_path, "r")
	if handle == nil then return nil, 'Cannot open file in read mode "' .. file_path .. '"' end
	
	local contents = handle:read("*all")
	handle:close()
	
	if not IS_BEAMMP_SERVER then return contents end
	
	for _, keyword in ipairs(BAD_KEYWORDS) do
		local enclosures, bad_keyword = encloseKeyword(contents, keyword)
		if enclosures == nil then
			return nil, bad_keyword
			
		elseif #enclosures > 0 then
			return nil, '"' .. keyword .. '" is used'
		end
	end
	
	local enclosures, bad_keyword = encloseKeyword(contents, 'require')
	if enclosures == nil then
		return nil, bad_keyword
		
	elseif #enclosures > 0 then
		for _, import in ipairs(enclosures) do
			local possible_imports = findRequireInIndex(import)
			if #possible_imports == 0 then
				return nil, 'Cannot resolve import "' .. import .. '"'
				
			else
				for _, possible_import in ipairs(possible_imports) do
					if file_path ~= possible_import then
						local contents, bad_keyword = checkFile(possible_import)
						if contents == nil then
							return nil, 'Import "' .. import .. '" throws error ' .. bad_keyword
						end
					end
				end
			end
		end
	end
	
	return contents
end

M.compileLua = function(file_path)
	local contents, err = checkFile(file_path)
	if contents == nil then return nil, err end
	
	local lua, err = load(contents)
	if err then return nil, err end
	
	local ok, code = pcall(lua)
	if not ok then return nil, code end
	
	return code
end

M.init = function(script_path, ...)
	FILE_INDEX = indexFilesRecursive(script_path:sub(1, -2))
	
	for _, include in ipairs({...}) do
		WHITELISTED[include] = true
	end
	
	os.execute = nil -- force remove
	M.init = nil
end

init()
return M
