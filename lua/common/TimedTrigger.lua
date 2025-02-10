--[[
	License: None
	Author: Neverless (discord: neverless.)
]]

--[[
	This lib follows the philosophy of "why code something multiple times if you can code it once and be done?". As such this library is compatible with all BeamNG lua environments. That includes the General Lua VM, the Vehicle VM and the BeamMP Server VM.
	
	The lib provides extra functionalities for the GE Lua VM to pass trigger executions into Vehicle VMs.
		
	Motivation
		
	
	Requirements
		This lib ONLY requires two additional libs IF its used on a BeamMP Server.
			- PauseTimer lib
			- Colors lib
			both inside a "libs" folder of your main script directory
	
	Usage
		local TimedTriggers = require("libs/TimedTrigger")
		
		TimedTriggers:new(
				Trigger name,
				Trigger after this amount of time,
				Trigger limit (eg 0/nil for infinite, 1..n for that amount of times repeatably),
				Function or String to execute,
				Arg1, -- optional
				Arg2, -- optional
				ArgN -- optional
		)
		
		TimedTriggers:new("my ge trigger", 1000, 1, "print(123)")
		TimedTriggers:new("my ge trigger 2", 1000, 1, print, 123, 456, 789)
		TimedTriggers:new("my ge trigger 3", 1000, 1, "return function(arg1, arg2) print(arg1, arg2) end", 123, 456)
		
		TimedTriggers:newVE("my ve trigger", gameVehicleID, 1000, 1, "beamstate.deflateRandomTire()")
		
		TimedTriggers:newVEAll("my ve all trigger", 0, 1, "trolling.doBackflip()")
		
		TimedTriggers:newVEAllExcept("my ve all except trigger", gameVehicleID, 0, 1, "trolling.flyTowardsCar(" .. gameVehicleID .. ")")
		
		M.onUpdate = function()
			TimedTriggers:tick()
		end
		
		If a trigger function returns 1 it will be removed. Usefull for continues triggers that only exists to wait for something. Eg waiting for it to be safe to unghost a vehicle.
		
	Optimizations
		- Optimized for rapid trigger adding and removing by remembering the next table index to add to
		Imagine we remove Trigger 2. For that we replace it with Trigger 5 and then nullify pos 4 afterwards
			Before
				NEXT_POS = 5
				[0] = Trigger 1
				[1] = Trigger 2 <-
				[2] = Trigger 3  |
				[3] = Trigger 4	 |
				[4] = Trigger 5 ->
			
			After
				NEXT_POS = 4
				[0] = Trigger 1
				[1] = Trigger 5
				[2] = Trigger 3
				[3] = Trigger 4
				[4] = nil
				
			This is more efficient then using table.insert()
			
		- Automatically swaps to a chunk parse method if #TRIGGERS is > CHUNK_CHECK_SIZE * 3
			This lib rather delays trigger execution then to delay the tick this lib is hooked to (eg graphics tick, as that would significantly reduce fps). This comes with the drawback that the more triggers it handles the more it will delay individual trigger executions (simply takes alot longer to chunk parse a list then it it so completly parse it every tick).
			
			This behaviour can be disabled
			local TimedTriggers = require("libs/TimedTriggers").setLargeListOptimization(true/false).setLargeListOptimizationLock(true/false)
			
			Note to myself: This provides an issue if this lib is loaded in GE lua and multiple extensions use this lib in different modes (because require() only loads a file once)
		
		- Basic GC Optimization
			This lib reuses previously created trigger objects
]]

-- Try GE timer, try VE timer, try MP Server timer
local PrecisionTimer = hptimer or HighPerfTimer or require("mp_libs/PauseTimer").new
-- BeamMP server only requirement
-- Only loaded in init if this library has been loaded on the BeamMP Server where no log() is present
local Colors = -1


local M = {
	VERSION = 0.1 -- 04.02.2025 (DD.MM.YYYY)
}
local ID_LOOKUP = {}
local TRIGGERS = {}
local NEXT_POS = 0
local REUSE_TRIGGERS = {}
local REUSE_NEXT_POS = 0
local REUSE_MAX_SIZE = 10000
local CHUNK_CHECK = 0
local CHUNK_CHECK_SIZE = 300
local LARGE_LIST_OPT = false
local LARGE_LIST_OPT_FORCED = false
local TICK_TIMER = PrecisionTimer()
local UNPACK = unpack or table.unpack


-- ------------------------------------------------------------------------------------------------
-- Lib Dev tests
local function devTests()
	if true then return end

	--local trigger = M.newTriggerClass("test", {target_env = 0}, 1000, 1, print, 123, 456)
	--local trigger = M.newTriggerClass("test", {target_env = 0}, 1000, 2, "return function(...) print(...) end", 123, 456)
	
	--M.new("test", 1000, 10, print, 123, 456)
	--M.remove("test")
	--M.new("test 2", 1000, 1, "")
	--M:new("test1", 1100, 1, "return function(...) print(...) end", 123)
	--M:new("test2", 1200, 1, "print(123)")
	
	
	--for i = 1, 100000, 1 do
	--	M.new("test" .. i, 1000 + (i * 1000), 1, "")
	--end
	
	--[[
		Stress test results
			@ BeamMP Server - Windows - Lua 5.4.6
			With 20 consecutive adds and 20 removes every 25 ms
			= ~3200 Triggers at any given time
			= Without large list opt
			= avg runtime: 1.5 - 1.8ms
			= With large list opt
			= avg runtime: 0.8 - 1.3ms
			
		LuaJit did this same test with 0.02ms smt results wtf
	]]
	
	--if true then return end
	
	--M.setLargeListOptimization(true).setLargeListOptimizationLock(true)
	M.setChunkCheckSize(300)

	local measure = PrecisionTimer()
	function update()
		measure:start()
		for i = 1, 20, 1 do
			M.new("test" .. math.random(), 50, 1, "")
		end
		M.tick()
		print("Total: " .. M:count() .. "\tChunk: " .. math.floor((CHUNK_CHECK / NEXT_POS) * 100) .. "%\tReuse: " .. REUSE_NEXT_POS .. "\tTime: " .. measure:stop())
	end
	
	MP.RegisterEvent("update", "update")
	MP.CancelEventTimer("update")
	MP.CreateEventTimer("update", 25)
end

-- ------------------------------------------------------------------------------------------------
-- Basics
local function fileName(string)
	local str = string:sub(1):gsub("\\", "/")
	local _, pos = str:find(".*/")
	return str:sub(pos + 1, -1)
end

-- ------------------------------------------------------------------------------------------------
-- Verbose Error propagation
local function Error(reason)
	local insert = function(display_reason, debug_info)
		if debug_info == nil or debug_info.name == nil then return display_reason end
		return display_reason .. fileName(debug_info.source) .. '@' .. debug_info.name .. ':' .. debug_info.linedefined .. ' <- '
	end
	
	local display_reason = insert('[', debug.getinfo(2))
	
	local index = 3;
	while debug.getinfo(index) and (debug.getinfo(1).source == debug.getinfo(index).source) do
		display_reason = insert(display_reason, debug.getinfo(index))
		index = index + 1
	end
	display_reason = insert(display_reason, debug.getinfo(index))
	display_reason = display_reason:sub(1, display_reason:len() - 4) .. '] THROWS\n' .. reason

	if log then -- if game
		log("E", "TimedTriggers", display_reason)
		
	else -- if beammp server
		Colors.print(Colors.bold("TimedTriggers") .. ' - ' .. display_reason, Colors.lightRed("ERROR"))
	end
end

-- ------------------------------------------------------------------------------------------------
-- Init
local function init()
	if not log then
		Colors = require("mp_libs/colors")
	end
	
	local is_game_ge_vm = false
	if core_vehicles then
		is_game_ge_vm = true
	end
	
	if not is_game_ge_vm then
		local from_wrong_env_call = function()
			Error("This function is not available in this environment")
		end
		
		M.newVE = from_wrong_env_call
		M.newVEAll = from_wrong_env_call
		M.newVEAllExcept = from_wrong_env_call
	end
end

-- ------------------------------------------------------------------------------------------------
-- TriggerClass

-- call self:update() to fill the obj
local function newTriggerClass() -- name, target_env, trigger_every, trigger_for, exec, ...
	local trigger = {int = {
			name = "",
			timer_manual = 0, -- as int for "manual" count
			timer = PrecisionTimer(), -- much slower then "manual" counting, but allows chunk checking
			trigger_every = 0, -- ms
			trigger_count = 0,
			trigger_for = 0, -- for this total amount
			
			-- 0 = GE
			-- 1 = VE ve_target
			-- 2 = VE all
			-- 3 = VE all except ve_target
			target_env = 0,
			ve_target = nil, -- gameVehicleID
			
			-- in GE = string or func
			-- in VE = string only
			exec = "",
			
			-- GE only
			args = {},
		}
	}
	
	-- target_env = {target_env = 0..3, ve_target = nil/gameVehicleID}
	function trigger:update(name, target_env, trigger_every, trigger_for, exec, ...)
		if type(exec) ~= "string" and type(exec) ~= "function" then
			return nil, "Exec must either be a string or function"
			
		elseif type(exec) == "string" then
			local func, err = load(exec)
			if func == nil then return nil, err end
			
		elseif target_env.target_env ~= 0 and type(exec) == "function" then
			return nil, "Must give a string into exec for non GE based triggers"
		end
		
		if target_env.target_env > 0 then
			if type(target_env.ve_target) ~= "number" or be:getObjectByID(target_env.ve_target) == nil then
				return nil, "Given vehicle target doesnt exist"
			end
		end
		
		self.int.name = name
		self.int.timer_manual = 0
		self.int.timer:stopAndReset()
		self.int.trigger_every = trigger_every
		self.int.trigger_count = 0
		self.int.trigger_for = trigger_for or 0
		self.int.target_env = target_env.target_env
		self.int.ve_target = target_env.ve_target
		self.int.exec = exec
		self.int.args = {...}
		
		return self
	end
	
	function trigger:name() return self.int.name end
	function trigger:getTime() return self.int.timer:stop() end
	function trigger:resetTime() self.int.timer:stopAndReset() end
	function trigger:setTimerManual(ms) self.int.timer_manual = ms end
	
	-- returns true once trigger_count >= trigger_for to let the caller know that the trigger can be removed
	function trigger:check()
		local int = self.int
		if int.timer:stop() >= int.trigger_every then
			local r = self:exec()
			self.int.timer:stopAndReset()
			
			if r == 1 then return true end
				
			if int.trigger_for > 0 then
				int.trigger_count = int.trigger_count + 1
				if int.trigger_count >= int.trigger_for then
					return true
				end
			end
		end
		return false
	end
	
	function trigger:check_manual(ms)
		local int = self.int
		int.timer_manual = int.timer_manual + ms
		if int.timer_manual >= int.trigger_every then
			local r = self:exec()
			self.int.timer_manual = 0
			self.int.timer:stopAndReset() -- !
			
			if r == 1 then return true end
			
			if int.trigger_for > 0 then
				int.trigger_count = int.trigger_count + 1
				if int.trigger_count >= int.trigger_for then
					return true
				end
			end
		end
		return false
	end
	
	function trigger:exec()
		if self.int.target_env == 0 then
			local r
			if type(self.int.exec) == "function" then
				r = self.int.exec(UNPACK(self.int.args))
			else
				r = self:compileAndRun()
			end
			
			return r
			
		elseif self.int.target_env == 1 then
			local veh = be:getObjectByID(self.int.ve_target)
			if not veh then
				Error("Vehicle target doesnt exist")
				return
			end
			
			veh:queueLuaCommand(self.int.exec)
		
		elseif self.int.target_env == 2 then
			be:queueAllObjectLua(self.int.exec)
			
		elseif self.int.target_env == 3 then
			be:queueAllObjectLuaExcept(self.int.exec, self.int.ve_target)
		
		end
	end
	
	function trigger:compileAndRun()
		local func, err = load(self.int.exec)
		if err ~= nil then
			Error(err)
			return
		end
		
		local args = UNPACK(self.int.args)
		local success, r = pcall(func, args)
		if not success then
			Error(r)
			return
		end
		
		if type(r) == "function" then
			r = r(args)
		end
		
		return r
	end
	
	--return trigger:update(name, target_env, trigger_every, trigger_for, exec, ...)
	return trigger
end

-- ------------------------------------------------------------------------------------------------
-- Reuse group
local function reusePut(trigger)
	if REUSE_NEXT_POS == REUSE_MAX_SIZE then return end
	REUSE_TRIGGERS[REUSE_NEXT_POS] = trigger
	REUSE_NEXT_POS = REUSE_NEXT_POS + 1
end

local function reuseTake()
	local trigger = REUSE_TRIGGERS[0]
	if trigger == nil then return nil end
	
	REUSE_NEXT_POS = REUSE_NEXT_POS - 1
	REUSE_TRIGGERS[0] = REUSE_TRIGGERS[REUSE_NEXT_POS]
	REUSE_TRIGGERS[REUSE_NEXT_POS] = nil
	
	return trigger
end

-- ------------------------------------------------------------------------------------------------
-- Trigger group
-- eg. local TimedTriggers = require("libs/TimedTriggers"):setLargeListOptimization(true/false)
-- Will fail if this setting is locked.
local function setLargeListOptimization(state)
	if LARGE_LIST_OPT_FORCED then return M end
	if LARGE_LIST_OPT == state then return M end
	
	CHUNK_CHECK = 0
	
	LARGE_LIST_OPT = state
	if not state then
		for index, trigger in pairs(TRIGGERS) do
			trigger:setTimerManual(trigger:getTime())
		end
	end
	return M
end

-- Locks the largelist optimization setting
local function setLargeListOptimizationLock(state)
	LARGE_LIST_OPT_FORCED = state
	setLargeListOptimization(state)
	return M
end

local function find(name)
	local index = ID_LOOKUP[name]
	if index == nil then return nil end
	return TRIGGERS[index], index
end

local function findIndex(name)
	return ID_LOOKUP[name]
end

local function removeByIndex(index, name) -- [opt: name]
	if index == nil then return end
	
	reusePut(TRIGGERS[index])
	
	local name = name or TRIGGERS[index]:name()
	NEXT_POS = NEXT_POS - 1
	TRIGGERS[index] = TRIGGERS[NEXT_POS]
	ID_LOOKUP[TRIGGERS[index]:name()] = index
	
	ID_LOOKUP[name] = nil
	TRIGGERS[NEXT_POS] = nil
	
	if NEXT_POS < CHUNK_CHECK_SIZE * 2 then
		setLargeListOptimization(false)
	end
	return true
end

local function remove(name)
	return removeByIndex(findIndex(name), name)
end

local function accept(trigger)
	local index = findIndex(trigger:name())
	if index then
		TRIGGERS[index] = trigger
	else
		TRIGGERS[NEXT_POS] = trigger
		ID_LOOKUP[trigger:name()] = NEXT_POS
		NEXT_POS = NEXT_POS + 1
	end

	--[[
		This combats an issue with the chunk check method. Where if there are more additions and removals then the chunk check size is big. It would result in the total amount of triggers rising and rising into infinity because it can never complete a single full check and rather just endsup checking just added triggers. So we reset the chunk check back to 0 and build ontop of the trigger swap system that replaces to be removed triggers with just created triggers.
	]]
	if (CHUNK_CHECK / NEXT_POS) > math.max(0.1, 1 - (NEXT_POS / 100000)) then CHUNK_CHECK = 0 end
	
	if NEXT_POS > CHUNK_CHECK_SIZE * 3 then
		if NEXT_POS < 100000 then
			setLargeListOptimization(true)
		else -- OVERFLOW. Disabling chunk checking to prevent ram overload. Game will start to stutter really bad
			setLargeListOptimization(false):setLargeListOptimizationLock(true)
		end
	end
	
end

local function new(name, trigger_every, trigger_for, exec, ...)
	local trigger, err = (reuseTake() or newTriggerClass()):update(
					name,
					{
						target_env = 0
					},
					trigger_every,
					trigger_for,
					exec,
					...
	)
	
	
	if not trigger then
		-- display error
		Error(err)
		
		return nil
	end
	
	accept(trigger)
	return trigger
end

local function newVE(name, ve_target, trigger_every, trigger_for, exec, ...)
	local trigger, err = (reuseTake() or newTriggerClass()):update(
					name,
					{
						target_env = 1,
						ve_target = ve_target,
					},
					trigger_every,
					trigger_for,
					exec,
					...
	)
	
	if not trigger then
		-- display error
		Error(err)
		
		return nil
	end
	
	accept(trigger)
	return trigger
end

local function newVEAll(name, trigger_every, trigger_for, exec, ...)
	local trigger, err = (reuseTake() or newTriggerClass()):update(
					name,
					{
						target_env = 2
					},
					trigger_every,
					trigger_for,
					exec,
					...
	)
	
	if not trigger then
		-- display error
		Error(err)
		
		return nil
	end
	
	accept(trigger)
	return trigger
end

local function newVEAllExcept(name, except, trigger_every, trigger_for, exec, ...)
	local trigger, err = (reuseTake() or newTriggerClass()):update(
					name,
					{
						target_env = 3,
						ve_target = except
					},
					trigger_every,
					trigger_for,
					exec,
					...
	)
	
	if not trigger then
		-- display error
		Error(err)
		
		return nil
	end
	
	accept(trigger)
	return trigger
end

-- must be hooked to eg updateGFX
local function tick()
	local dt = TICK_TIMER:stopAndReset()
	
	if LARGE_LIST_OPT then
		if NEXT_POS == 0 then return end
		while CHUNK_CHECK < NEXT_POS do
			if TRIGGERS[CHUNK_CHECK]:check() then
				removeByIndex(CHUNK_CHECK, TRIGGERS[CHUNK_CHECK]:name())
			end
			
			CHUNK_CHECK = CHUNK_CHECK + 1
			if CHUNK_CHECK % CHUNK_CHECK_SIZE == 0 then break end
		end
		if CHUNK_CHECK >= NEXT_POS then CHUNK_CHECK = 0 end
	
	else
		-- pairs is slow, ipairs starts at 0, NEXT_POS is dynamic.. soo our own while loop it is
		local index = 0
		while index < NEXT_POS do
			local trigger = TRIGGERS[index]
			if trigger:check_manual(dt) then
				removeByIndex(index, trigger:name())
			end
			index = index + 1
		end
	end
end

local function count() return NEXT_POS end
local function getChunk() return CHUNK_CHECK end
local function getReuseCount() return REUSE_NEXT_POS end

local function getTriggerList()
	local trigger_list = {}
	for i = 0, NEXT_POS - 1, 1 do
		table.insert(trigger_list, TRIGGERS[i]:name())
	end
	
	return trigger_list
end

local function setChunkCheckSize(check_size)
	CHUNK_CHECK_SIZE = check_size
end


M.new = new
M.newVE = newVE
M.newVEAll = newVEAll
M.newVEAllExcept = newVEAllExcept
M.count = count
M.getChunk = getChunk
M.getReuseCount = getReuseCount
M.tick = tick
M.setLargeListOptimization = setLargeListOptimization
M.setLargeListOptimizationLock = setLargeListOptimizationLock
M.remove = remove
M.removeByIndex = removeByIndex
M.find = find
M.findIndex = findIndex
M.setChunkCheckSize = setChunkCheckSize
M.getTriggerList = getTriggerList

init()
devTests()
return M
