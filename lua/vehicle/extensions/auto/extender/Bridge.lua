
--local TimedTrigger = require("lua/ge/extensions/libs/TimedTrigger")

local M = {}

local function callFunc(name, func)
	
end

local function compile(func_ser)
	local func = deserialize(func_ser)
	if func == nil then return end
	if type(func) ~= "string" then return end
	
	local func, err = load(func)
	if func == nil then return end
	
	return func
end

M.runOnInit = function(name, func_ser)
	local func = compile(func_ser)
	if func == nil then return end
	
	callFunc(name, func)
end

M.addRoutine = function(name, func_ser, trigger_every)
	local func = compile(func_ser)
	if func == nil then return end
	
	TimedTrigger.new(
		'PowerUps_Bridge_' .. name,
		trigger_every,
		0,
		callFunc,
		name,
		func
	)
end




return M
