--[[
	Usage
	
	Ui.target(target_id).Toast.info("My message", "My title", 1000)
]]

local Log = require("libs/Log")

local M = {int = {
		target_id = nil
	},
	
	Toast = {},
	Msg = {}
}

local function isSpectating(target_id)
	local vehicle = getPlayerVehicle(0)
	if vehicle == nil then return end
	return vehicle:getId() == target_id
end

local function checkTarget()
	if M.int.target_id == nil then
		Log.error('No target given to send ui info to')
		return
	end
	local check = isSpectating(M.int.target_id)
	M.int.target_id = nil
	return check
end

local function extractId(vehicle)
	if type(vehicle) == "number" then return vehicle end
	if type(vehicle) == "userdata" then
		if vehicle.getId then
			return vehicle:getId()
		end
	end
	Log.error('Given target is not a number or a vehicle')
	return nil
end

M.target = function(target_id)
	M.int.target_id = extractId(target_id)
	return M
end

M.Toast.success = function(message, title, time)
	if not checkTarget() then return end
	guihooks.trigger('toastrMsg', {type = 'success', title = title or '', msg = message or '', config = {timeOut = time or 5000}})
end

M.Toast.info = function(message, title, time)
	if not checkTarget() then return end
	guihooks.trigger('toastrMsg', {type = 'info', title = title or '', msg = message or '', config = {timeOut = time or 5000}})
end

M.Toast.warn = function(message, title, time)
	if not checkTarget() then return end
	guihooks.trigger('toastrMsg', {type = 'warning', title = title or '', msg = message or '', config = {timeOut = time or 5000}})
end

M.Toast.error = function(message, title, time)
	if not checkTarget() then return end
	guihooks.trigger('toastrMsg', {type = 'error', title = title or '', msg = message or '', config = {timeOut = time or 5000}})
end

M.Msg.send = function(message, ident, time)
	if not checkTarget() then return end
	guihooks.message({txt = message}, time or 1, ident or "notset")
end


return M
