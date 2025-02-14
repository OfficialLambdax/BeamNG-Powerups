local Col = require("mp_libs/colors")

local M = {}

local function fileName(string)
	local str = string:sub(1):gsub("\\", "/")
	local _, pos = str:find(".*/")
	if pos == nil then return string end
	return str:sub(pos + 1, -1)
end

local function cleanseName(file)
	local file = fileName(file)
	local final, _ = file:find('%.')
	if final then final = final - 1 end
	
	return file:sub(1, final)
end

local function stackTrace(display) -- actually just traces the function calls
	local stack_trace = '\n'
	local index = 3
	while debug.getinfo(index) do
		local get_info = debug.getinfo(index)
		local source = get_info.source or ""
		if source == '=[C]' then source = "builtin" end
		
		local name = get_info.name
		if name == nil then name = '-' else name = Col.ifServer(name .. '()', Col.orange) end
		
		local linedefined = get_info.linedefined
		if linedefined < 1 then linedefined = '-' end
		
		local spacer = ''
		if index > 3 then spacer = ' ^ ' end
		
		stack_trace = stack_trace .. spacer ..
			Col.ifServer(fileName(source), Col.bold) .. '@' .. name .. ':' .. linedefined .. '\n'
		
		index = index + 1
	end
	
	if display then
		if log then
			log(display, '== STACKTRACE ==', stack_trace)
		else
			Col.print(stack_trace, Col.bold('== STACKTRACE =='))
		end
	end
	
	return stack_trace
end

M.error = function(reason, display, stack_trace)
	if stack_trace then stackTrace('E') end
	if display == nil then
		display = cleanseName(debug.getinfo(2).source) .. '@' .. (debug.getinfo(2).name or '-'), Col.bold
	end
	display = Col.ifServer(display, Col.bold) .. ' '
	
	if log then
		log('E', display, reason)
	else
		Col.print(display .. reason, Col.lightRed("ERROR"))
	end
end

M.warn = function(reason, display, stack_trace)
	if stack_trace then stackTrace('W') end
	if display == nil then
		display = cleanseName(debug.getinfo(2).source) .. '@' .. (debug.getinfo(2).name or '-'), Col.bold
	end
	display = Col.ifServer(display, Col.bold) .. ' '
	
	if log then
		log('W', display, reason)
	else
		Col.print(display .. reason, Col.lightYellow("-WARN"))
	end	
end

M.info = function(reason, display, stack_trace)
	if stack_trace then stackTrace('I') end
	if display == nil then
		display = cleanseName(debug.getinfo(2).source) .. '@' .. (debug.getinfo(2).name or '-'), Col.bold
	end
	display = Col.ifServer(display, Col.bold) .. ' '
	
	if log then
		log('I', display, reason)
	else
		Col.print(display .. reason, Col.bold("-INFO"))
	end	
end

return M
