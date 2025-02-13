--[[
	License: None
	Author: Neverless (discord: neverless.)
]]

--[[
	GE Only
	With some extra compat for BeamMP Server
	
	Typical usage
		-- exec. if ve triggers are contained exec for game_vehicle_id
		Sets.getSet("mySet"):VETarget(game_vehicle_id):exec()
		
		-- can also take the veh object
		Sets.getSet("mySet"):VETarget(getPlayerVehicle(0)):exec()
		
		-- this() refers to to getPlayerVehicle(0)
		Sets.getSet("mySet"):this():exec()
		
		-- block reset until last trigger has ran out
		Sets.getSet("mySet"):this():resetBlock():exec()
		
		-- ghost vehile until last trigger has ran out
		Sets.getSet("mySet"):this():ghost():exec()
		
		-- block reset and ghost ..
		Sets.getSet("mySet"):this():rbg():exec()
		
		-- modding individual triggers
		local set = Sets.getSet("mySet")
		set:mod("dont run this trigger"):state(true/false)
		set:exec()
		
		-- locks future execs for this vehicle. auto unlocks after set has been played
		Sets.getSet("mySet"):this():exec():lock()
		
		
	Design issue with this lib that produce gc overhead.
		
		Sets.addSet() <- Raw Set table
		   ^
		   	---- Sets.newSet() <- Into Set Class
					^
					 -------- local set = Sets.getSet()
		
		If a set in this case contains a table as a arg thats given to the exec and this set is executed multiple times at the same time, then multiple executions edit the same table. THATS BAD
		
		So eg if a set execs a function with a table that edits the table
		local function(table)
			table.num = table.num + 1
		end
		
		then this change is now also present in the other set exec.
		
		To combat this a set is deep copied when Sets.newSet() is called. This is the GC overhead.
		
]]

local Util = require("libs/Util")
local TimedTrigger = require("libs/TimedTrigger")

-- BeamMP server only requirement
-- Only loaded in init if this library has been loaded on the BeamMP Server where no log() is present
local Colors = -1
if not log then
	Colors = require("mp_libs/colors")
end

local M = {
	_VERSION = "0.1" -- 06.02.2025 DD.MM.YYYY
}
local SETS = {}
local UNPACK = unpack or table.unpack
local ADAPTER
local LOCKS = {} -- game_vehicle_id = true

if core_input_actionFilter then
	-- not sure why this doesnt work
	--core_input_actionFilter.setGroup("setlib_limiter", core_input_actionFilter.createActionTemplate({"vehicleTeleporting", "vehicleMenues", "physicsControls"}))

	-- so lets use this for the moment
	core_input_actionFilter.setGroup("setlib_limiter", {"reset_physics","recover_vehicle","recover_vehicle_alt","nodegrabberAction","nodegrabberGrab","nodegrabberRender","editorToggle","editorSafeModeToggle","toggleWalkingMode","dropPlayerAtCamera","dropPlayerAtCameraNoReset","loadHome","reload_all_vehicles","recover_to_last_road","forceField","funBoom","funBreak","funExtinguish","funFire","funHinges","funTires","funRandomTire","toggleBigMap","couplersLock","couplersToggle","couplersUnlock","pause","slower_motion","faster_motion","toggle_slow_motion","toggleTraffic","toggleAITraffic","reset_all_physics","reload_vehicle","vehicle_selector","parts_selector"})
	core_input_actionFilter.addAction(0, "setlib_limiter", false)
end

-- ------------------------------------------------------------------------------------------------
-- Basics
local function fileName(string)
	local str = string:sub(1):gsub("\\", "/")
	local _, pos = str:find(".*/")
	if pos == nil then return string end
	return str:sub(pos + 1, -1)
end

-- require() but not require()
local function compileLua(path)
	local handle = io.open(path, "r")
	if handle == nil then return nil, 'Cannot open file "' .. path .. '"' end
	
	local lua = handle:read("*all")
	handle:close()
	
	local lua, err = load(lua)
	if err then return nil, err end
	local ok, code = pcall(lua)
	if not ok then return nil, code end
	return code
end

local function splitStringToTable(string, delimeter, convert_into)
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

local function tableCopy(tbl)
	local new_tbl = {}
	for key,value in pairs(tbl) do
		local value_type = type(value)
		local new_value
		if value_type == "function" then
			-- Problems may occur if the function has upvalues.
			--new_value = load(string.dump(value))
			new_value = value
		elseif value_type == "table" then
			new_value = tableCopy(value)
		else
			new_value = value
		end
		new_tbl[key] = new_value
	end
	return new_tbl
end

local function dist3d(veh_1, veh_2)
	local v1 = veh_1:getSpawnWorldOOBB():getCenter()
	local v2 = veh_2:getSpawnWorldOOBB():getCenter()
	return math.sqrt((v2.x - v1.x)^2 + (v2.y - v1.y)^2 + (v2.z - v1.z)^2)
end


local function remLock(game_vehicle_id)
	LOCKS[game_vehicle_id] = nil
end

local function unghost(game_vehicle_id, timer, max_time)
	local veh = be:getObjectByID(game_vehicle_id)
	if veh == nil then return 1 end
	
	if timer:stop() < max_time then return end
	
	-- Needs to change
	-- if were closer then 5 meters to anyone else then dont unghost yet
	for _, vehicle in pairs(getAllVehicles()) do
		if vehicle:getId() ~= game_vehicle_id then
			if dist3d(veh, vehicle) < 5 then return end
		end
	end
	
	veh:queueLuaCommand("obj:setGhostEnabled(false)")
	veh:setMeshAlpha(1, "", false)
	
	return 1
end

-- ------------------------------------------------------------------------------------------------
-- Verbose Error propagation
local function Error(reason)
	local insert = function(display_reason, debug_info)
		if debug_info == nil or debug_info.name == nil then return display_reason end
		return display_reason .. fileName(debug_info.source or "") .. '@' .. debug_info.name .. ':' .. debug_info.linedefined .. ' <- '
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
		log("E", "Sets", display_reason)
		
	else -- if beammp server
		Colors.print(Colors.bold("Sets") .. ' - ' .. display_reason, Colors.lightRed("ERROR"))
	end
end

-- ------------------------------------------------------------------------------------------------
-- SetClass
local function newSet(name, set_array)
	local set = {set = {}, ve_target = nil, adapted = false}
	
	--[[
		[1] = name
		[2] = settings
		[3] = type
		[4] = trigger after
		[5] = trigger for
		[6] = exec
		[7] = args
	]]
	function set:add(name, trigger_array)
		local trigger_name = trigger_array[1]
		if trigger_name:len() == 0 then trigger_name = name end
		local trigger_settings = trigger_array[2]
		local trigger_type = trigger_array[3]
		local trigger_after = trigger_array[4]
		local trigger_for = trigger_array[5]
		local trigger_exec = trigger_array[6]
		local trigger_args = trigger_array[7]
	
		-- checks
		if type(trigger_name) ~= "string" or trigger_name:len() == 0 then
			return Error('"' .. trigger_name .. '" has invalid name')
		end
		
		if self.set[trigger_name] ~= nil then
			return Error('"' .. trigger_name .. '" already exists')
		end
		
		local type_convert = {
			GE = 0,
			VE = 1,
			VEAll = 2,
			VEAllExcept = 3
		}
		if type_convert[trigger_type] == nil then
			return Error('"' .. trigger_name .. '" has wrong type')
		end
		
		if type(trigger_after) ~= "number" then
			return Error('"' .. trigger_name .. '" has wrong "trigger after" var')
		end
		
		if type(trigger_for) ~= "number" then
			return Error('"' .. trigger_name .. '" has wrong "trigger for" var')
		end
		
		--if type(trigger_exec) ~= "string" then
		--	return Error('"' .. trigger_name .. '" exec var cannot be function yet!')
		--end
		
		if type(trigger_exec) == "string" then
			local func, err = load(trigger_exec)
			if func == nil then
				return Error('"' .. trigger_name .. '" Exec error ' .. err)
			end
		end
		
		if trigger_args == nil then
			trigger_args = {}
			
		else
			local index = 7
			trigger_args = {}
			while trigger_array[index] ~= nil do
				table.insert(trigger_args, trigger_array[index])
				index = index + 1
			end
		end
		
		local trigger = {
			trigger_type = type_convert[trigger_type],
			trigger_name = trigger_name,
			trigger_settings = trigger_settings,
			trigger_after = trigger_after,
			trigger_for = trigger_for,
			trigger_exec = trigger_exec,
			trigger_args = trigger_args,
			trigger_ve_target = nil,
			trigger_enabled = true
		}
		
		if trigger_array[1]:len() > 0 then trigger_name = trigger_array[1] end
		self.set[trigger_name] = trigger
		return true
	end
	
	function set:addMulti(name, set_array)
		local name_index = 1
		for _, trigger_array in pairs(set_array) do
			if self:add(name .. '_' .. name_index, trigger_array) == nil then
				return nil
			end
			name_index = name_index + 1
		end
		
		return self
	end
	
	function set:adapt(set) -- adapt from
		self.set = {}
		self.adapted = true
		
		for trigger_name, trigger in pairs(set.set) do
			--local trigger = {
			--	trigger_type = trigger.trigger_type,
			--	trigger_name = trigger.trigger_name,
			--	trigger_after = trigger.trigger_after,
			--	trigger_for = trigger.trigger_for,
			--	trigger_exec = trigger.trigger_exec,
			--	trigger_args = tableCopy(trigger.trigger_args), -- must be copied!
			--	trigger_ve_target = nil
			--}
			
			local trigger = tableCopy(trigger)
			
			function trigger:state(state)
				self.trigger_enabled = state
			end
			
			function trigger:args(...)
				self.trigger_args = {...}
				return self
			end
			
			function trigger:exec(exec)
				self.trigger_exec = exec
				return self
			end
			
			function trigger:VETarget(ve_target)
				if self.trigger_type ~= 0 then
					self.trigger_ve_target = ve_target
				end
				--self.trigger_args = self.trigger_args:gsub("ve_target", ve_target)
				for index, arg in pairs(self.trigger_args) do
					if type(arg) == "string" and arg == "ve_target" then
						self.trigger_args[index] = ve_target
					end
				end
				return self
			end			
			
			self.set[trigger_name] = trigger
		end
		
		return self
	end
	
	-- sets the same ve target to all arrays
	function set:VETarget(game_vehicle_id)
		if game_vehicle_id == nil then
			return Error('Invalid game vehicle id given to execute')
		elseif type(game_vehicle_id) == "userdata" then
		
			game_vehicle_id = game_vehicle_id:getId()
		elseif map.objects[game_vehicle_id] == nil then
		
			return Error('Invalid game vehicle id given to execute')
		end
		
		self.ve_target = game_vehicle_id
		
		-- add ve target to entire set
		for _, trigger in pairs(self.set) do
			trigger:VETarget(game_vehicle_id)
		end
		
		return self
	end
	
	-- dev only function. selects the spectated vehicle as the ve target
	function set:this()
		local veh = getPlayerVehicle(0)
		if veh == nil then
			Error('Not spectating a vehicle')
			return self
		end
		self:VETarget(veh:getId())
		
		return self
	end
	
	function set:mod(name)
		return self.set[name]
	end
	
	function set:maxTime()
		local max_time = 0
		for _, trigger in pairs(self.set) do
			if trigger.trigger_after > max_time then
				max_time = trigger.trigger_after
			end
		end
		
		return max_time
	end
	
	function set:rbg(plus_time)
		self:resetBlock(plus_time)
		self:ghost(plus_time)
		return self
	end
	
	function set:resetBlock(plus_time)
		local r = TimedTrigger.new(
			"setlib_limiter_" .. Util.randomName(),
			self:maxTime() + (plus_time or 0),
			1,
			core_input_actionFilter.addAction,
			0,
			"setlib_limiter",
			false
		)
		if r == nil then
			Error('Could not create reset block trigger')
			return self
		end
		core_input_actionFilter.addAction(0, "setlib_limiter", true)
		
		return self
	end
	
	function set:ghost(plus_time, ve_target)
		local ve_target = ve_target or self.ve_target
		if ve_target == nil then
			Error('No ve_target to ghost')
			return self
		end
		
		local r = TimedTrigger.new(
			"setlib_unghost_" .. Util.randomName(),
			1000,
			0,
			unghost,
			ve_target,
			hptimer(),
			self:maxTime() + (plus_time or 0)
		)
		if r == nil then
			Error('Could not create unghost trigger')
			return
		end
		
		local veh = be:getObjectByID(ve_target)
		veh:queueLuaCommand("obj:setGhostEnabled(true)")
		veh:setMeshAlpha(0.5, "", false)
		
		return self
	end
	
	function set:exec(postfix)
		if self.adapted == false then
			Error('Can only exec adapted sets')
			return
		end
		
		if self.ve_target and LOCKS[self.ve_target] then
			-- vehicle is locked
			return
		end
		
		local postfix = postfix or Util.randomName()
		
		for trigger_name, trigger in pairs(self.set) do
			if trigger.trigger_enabled then
				-- if either the spectate option is false or when it is enable then check if the ve target is what we are spectating
				if not trigger.trigger_settings.spectate or (trigger.trigger_settings.spectate and self.ve_target == getPlayerVehicle(0):getId()) then
					local trigger_name = 'set_' .. trigger_name .. postfix
					local type = trigger.trigger_type
					if type == 0 then -- GE
						local r = TimedTrigger.new(
									trigger_name,
									trigger.trigger_after,
									trigger.trigger_for,
									trigger.trigger_exec,
									UNPACK(trigger.trigger_args)
						)
						if r == nil then
							self:revert(postfix)
							Error('Set loading aborted')
							break
						end
						
						
					elseif type == 1 then -- VE
						local r = TimedTrigger.newVE(
									trigger_name,
									trigger.trigger_ve_target,
									trigger.trigger_after,
									trigger.trigger_for,
									trigger.trigger_exec,
									UNPACK(trigger.trigger_args)
						)
						if r == nil then
							self:revert(postfix)
							Error('Set loading aborted')
							break
						end
					
					elseif type == 2 then -- VEAll
						local r = TimedTrigger.newVEAll(
									trigger_name,
									trigger.trigger_after,
									trigger.trigger_for,
									trigger.trigger_exec,
									UNPACK(trigger.trigger_args)
						)
						if r == nil then
							self:revert(postfix)
							Error('Set loading aborted')
							break
						end
					
					elseif type == 3 then -- VEAllExcept
						local r = TimedTrigger.newVEAllExcept(
									trigger_name,
									trigger.trigger_ve_target,
									trigger.trigger_after,
									trigger.trigger_for,
									trigger.trigger_exec,
									UNPACK(trigger.trigger_args)
						)
						if r == nil then
							self:revert(postfix)
							Error('Set loading aborted')
							break
						end
					end
				end
			end
		end
		
		return self
	end
	
	function set:revert(postfix)
		for trigger_name, _ in pairs(self.set) do
			local trigger_name = 'set_' .. trigger_name .. postfix
			TimedTrigger.remove(trigger_name)
		end
	end
	
	function set:lock()
		if self.ve_target == nil then return end
		local r = TimedTrigger.new(
			"setlib_unlock_" .. Util.randomName(),
			self:maxTime(),
			1,
			remLock,
			self.ve_target
		)
		if r == nil then
			Error('Cannot create unlock trigger')
			return
		end
		LOCKS[self.ve_target] = true
	end
	
	if type(name) == "table" and name.exec ~= nil then
		return set:adapt(name)
	else
		return set:addMulti(name, set_array)
	end
end

-- ------------------------------------------------------------------------------------------------
-- Set builder
-- for manual dev
local function setBuilder()
	if true then return end
	--M.loadSets("./Resources/Server/LibDev/sets")
	
	--[[
		Types
			GE
			VE
			VEAll
			VEAllExcept
			
		ve_target is added during adaption.
		exec function literal can only be added during adaption.
	]]
	
	local exec = [[
		local func = function(x, y, z, pitchAV, rollAV, yawAV)
			local refNode = v.data.refNodes[0].ref
			local rot = quatFromDir(-vec3(obj:getDirectionVector()), vec3(obj:getDirectionVectorUp()))
			local cog = (vec3(0, 0 ,0)):rotated(rot)
			local vel = vec3(x, y, z) - cog:cross(vec3(pitchAV, rollAV, yawAV))
			local physicsFPS = obj:getPhysicsFPS()
			local velMulti = 1
			
			obj:applyClusterLinearAngularAccel(
				refNode,
				vel * physicsFPS * velMulti,
				-vec3(pitchAV, rollAV, yawAV) * physicsFPS
			)
		end
		func(0, 0, 20, 0, 0, 0)
	]]
	
	local set = {
		{"type", "trigger after", "trigger for", "exec", "args"},
		{"", 0, 0, "", ""},
		{"GE", 0, 1, "print(123)"},
		{"VE", 0, 1, 'DoNotTouch.jump(0, 0, 20, 0, 0, 0)'},
		{"VE", 500, 1, 'DoNotTouch.jump(0, 0, -40, 0, 0, 0)'},
	}
	
	set[1] = nil
	set[2] = nil
	local set = newSet("test", set)

	--set:VETarget(getPlayerVehicle(0)):exec()
	--dump(set)
	
	--function update()
	--	TimedTrigger.tick()
	--end
	
	--MP.RegisterEvent("update", "update")
	--MP.CancelEventTimer("update")
	--MP.CreateEventTimer("update", 25)
	
	--print(set)
end


-- ------------------------------------------------------------------------------------------------
-- Interface
M.addSet = function(name, set)
	SETS[name] = newSet(name, set)
end

M.getSet = function(name)
	--return SETS[name]
	
	if SETS[name] == nil then return end
	return ADAPTER:adapt(SETS[name])
end

M.loadSet = function(file_path, name)
	local cleanse_name = function(file)
		local file = fileName(file)
		local final, _ = file:find('%.')
		if final then final = final - 1 end
		
		return file:sub(1, final)
	end
	
	local set, err = compileLua(file_path)
	local file_path = cleanse_name(file_path)
	if set == nil then
		Error('Cannot compile "' .. file_path .. '" because "' .. (err or 'doesnt return a set') .. '"')
		
	else
		set[1] = nil
		M.addSet(name or file_path, set)
			
		--print(file_path)
	end	
end

M.loadSets = function(sets_path)
	local sets = {}
	if FS.ListFiles then -- server
		sets = FS.ListFiles(sets_path)
	else -- game
		sets = FS:directoryList(sets_path)
	end
	
	if sets == nil then
		Error('Given sets path is empty')
		return
	end
	
	for _, file_path in pairs(sets) do
		M.loadSet(file_path)
	end
end

ADAPTER = newSet("adapter", {})
setBuilder()
return M
