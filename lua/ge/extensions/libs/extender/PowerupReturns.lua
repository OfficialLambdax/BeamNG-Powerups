return {
	onActivate = {
		Success = function(data)
			return {IsSuccess = true, data = data or {}}
		end,
		
		Error = function(reason)
			return {IsError = true, reason = tostring(reason) or "No reason given"}
		end,
		
		TargetInfo = function(data, target_info)
			return {IsTargetInfo = true, data = data, target_info = target_info}
		end,
		
		TargetHits = function(target_hits)
			return {IsTargetHits = true, target_hits = target_hits}
		end,
	},
	
	whileActive = {
		Continue = function(target_info, target_hits)
			return {IsContinue = true, target_info = target_info, target_hits = target_hits}
		end,
		
		Stop = function()
			return {IsStop = true}
		end,
		
		StopAfterExec = function(target_info, target_hits)
			return {IsStopAfterExec = true, target_info = target_info, target_hits = target_hits}
		end,
		
		TargetInfo = function(target_info)
			return {IsContinue = true, target_info = target_info}
		end,
		
		TargetHits = function(target_hits)
			return {IsContinue = true, target_hits = target_hits}
		end,
	}
}