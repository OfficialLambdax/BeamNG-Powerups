return {
	onPickup = {
		Error = function(reason)
			return {IsError = true, reason = tostring(reason) or "No reason given"}
		end,
		Success = function()
			return {IsSuccess = true}
		end,
	}
}