local ServerUtil = Util
local Util = require("libs/Util")

local M = {}

M.isBeamMPServer = function()
	if not MP then return false end
	if not MP.TriggerClientEvent then return false end
	
	return true
end

-- has beammp and is in a session. never true on server
M.isBeamMPSession = function()
	if MPCoreNetwork then return MPCoreNetwork.isMPSession() end
	return false
end

M.getMyPlayerName = function()
	if not M.isBeamMPSession() then return nil end
	return MPCoreNetwork.getAuthResult().username
end

--M.getOwner = function(game_vehicle_id)
--	if not M.isBeamMPSession() then return nil end
--	return MPVehicleGE.getVehicleByGameID(game_vehicle_id).ownerName
--end

M.isOwn = function(game_vehicle_id)
	if not M.isBeamMPSession() then return nil end
	return MPVehicleGE.isOwn(game_vehicle_id)
end

if not M.isBeamMPServer() then
	M.getPlayerName = function(game_vehicle_id)
		if not M.isBeamMPSession() then return nil end
		return (MPVehicleGE.getVehicleByGameID(game_vehicle_id) or{}).ownerName
	end
	
	M.jsonDecode = jsonDecode

else
	M.getPlayerName = function(game_vehicle_id)
		local player_id = Util.split(game_vehicle_id, '-', 1)
		return MP.GetPlayerName(player_id[1])
	end
	
	M.jsonDecode = ServerUtil.JsonDecode
end

M.getPlayerIDFromServerID = function(server_vehicle_id)
	local _, pos = server_vehicle_id:find('-')
	if pos == nil then return end
	
	return tonumber(server_vehicle_id:sub(1, pos - 1))
end

M.gameVehicleIDToServerVehicleID = function(game_vehicle_id)
	local server_vehicle_id = MPVehicleGE.getServerVehicleID(game_vehicle_id)
	if not server_vehicle_id or server_vehicle_id == -1 then return end
	return server_vehicle_id
end

M.serverVehicleIDToGameVehicleID = function(server_vehicle_id)
	local game_vehicle_id = MPVehicleGE.getGameVehicleID(server_vehicle_id)
	if not game_vehicle_id or game_vehicle_id == -1 then return end
	return game_vehicle_id
end

M.getPosition = function(player_id, vehicle_id)
	local raw_pos_packet = MP.GetPositionRaw(player_id, vehicle_id)
	if not raw_pos_packet then return nil end
	
	--local decode = ServerUtil.JsonDecode(raw_pos_packet)
	local decode = raw_pos_packet
					
	return {x = decode.pos[1], y = decode.pos[2], z = decode.pos[3]}
end


return M
