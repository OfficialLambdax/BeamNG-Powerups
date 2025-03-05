-- WIP

local Toml = require("/mp_libs/toml")
local Util = require("libs/Util")

local M = {}

local SETTINGS_DIR = "mp_settings/"


local function init()
	SETTINGS_DIR = Util.filePath(Util.myPath():sub(1, -2)) .. SETTINGS_DIR
	if not FS.IsDirectory(SETTINGS_DIR) then
		FS.CreateDirectory(SETTINGS_DIR)
	end
end

local function updateSettings(from, into)
	local changes = false
	for k, v in pairs(from) do
		local v_type = type(v)
		
		-- if the key didnt exist or the type has changed then add
		if into[k] == nil or v_type ~= type(into[k]) then
			into[k] = v
			changes = true
		else
			if v_type == "table" then
				changes = updateSettings(from[k], into[k])
			end
		end
	end
	
	-- remove no longer existing keys from in the "from" table from the "into" table
	for k, v in pairs(into) do
		if from[k] == nil then
			into[k] = nil
			changes = true
		end
	end
	return changes
end

--[[
	From
		{
			"key1" = "hello world",
			"key2" = {
				"hello" = "hi",
				"world" = "hi 2"
			}
		}
	
	To
		{
			"settings" = {
				"key1" = "hello world",
			},
			"settings.key2" = {
				"hello" = "hi",
				"world" = "hi 2"
			}
		}
]]
local function prepareSettingDescribtions(settings_describtions, into, path)
	if into[path] == nil then into[path] = {} end
	for setting_name, v in pairs(settings_describtions) do
		if type(v) == "table" then
			prepareSettingDescribtions(v, into, path .. '.' .. setting_name)
		else
			into[path][setting_name] = '# ' .. v:gsub("%\n", "\n# "):gsub("%\r", "\n# ") .. '\n'
		end
	end
	return settings_describtions
end


local function readSettings(settings_name)
	local handle = io.open(SETTINGS_DIR .. settings_name .. ".toml", "r")
	if handle == nil then return nil end
	local data = handle:read("*all")
	handle:close()
	return Toml.parse(data).settings
end

-- consumes the settings table
M.writeSettings = function(settings_name, settings, settings_describtions)
	local new_settings_describtions = {}
	prepareSettingDescribtions(settings_describtions, new_settings_describtions, "settings")
	
	local group = {}
	local new_string = ""
	for line in Toml.encode({settings = settings}):gmatch("[^\r\n]+") do
		if line:sub(1, 1) == "[" then
			group = new_settings_describtions[line:sub(2):sub(1, -2)] or {}
			new_string = new_string .. '# -------------------------------------------\n' .. (group["#"] or "") .. '# -------------------------------------------\n' .. line .. '\n'
		else
			--print(line)
			local setting_name = line:sub(1, ({line:find("=")})[1] - 2) -- extract name ">>mySetting<< = value"
			new_string = new_string .. (group[setting_name] or "") .. line .. '\n\n'
		end
	end
	
	local handle = io.open(SETTINGS_DIR .. settings_name .. ".toml", "w")
	if handle == nil then return nil end
	handle:write(new_string)
	--handle:write(Toml.encode({settings = settings}))
	handle:close()
	return true
end

M.readSettings = function(settings_name, base_settings, base_settings_description)
	local settings = readSettings(settings_name) or {}
	if updateSettings(base_settings, settings) then
		M.writeSettings(settings_name, settings, base_settings_description)
		return readSettings(settings_name) or {}
	end
	return settings
end

local function testing()
	local base_settings = {
		ADMINS = "Player1,Player2,Player3",
		TEST = {
			test = {
				djkfd = "edifug"
			},
			hello = 123,
			world = "hi",
			multi_line = false,
			no_group_describtion = {
				useless_var = false,
			},
		},
		NO_DESCRIBTION = "",
	}
	local base_settings_description = {
		["#"] = "Settings Group Describtion",
		ADMINS = "Add Admins",
		TEST = {
			["#"] = "Test Group Describtion",
			hello = "Something with a 123",
			world = "Something with a hi",
			test = {
				["#"] = "Another group Describtion",
				djkfd = "Funny keyboard headbanger",
			},
			multi_line = "First line\nSecondline\rThirdline",
		},
	}
	
	print(M.readSettings("base", base_settings, base_settings_description))
end

init()
--testing()
return M
