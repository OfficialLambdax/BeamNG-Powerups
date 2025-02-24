local insert = table.insert

local function extractNum(string)
	local extract = ""
	for str in string:gmatch("%d") do
		if tonumber(str) ~= nil then extract = extract .. str end
	end
	return extract
end

local function initSeed()
	math.randomseed(os.time() + tonumber(extractNum(tostring({}):sub(8))))
end

local function mathRandom(from, to)
	initSeed()
	return math.random(from, to)
end

local function stir(table) -- consumes input
	local stirred = {}
	while true do
		local max = #table
		if max == 0 then break end
		
		local random = math.random(1, max)
		insert(stirred, table[random])
		
		table[random] = table[max]
		table[max] = nil
	end
	return stirred
end

return function()
	local pot = {int = {
			tickets = {}
		}
	}
	
	function pot:add(item, amount)
		for i = 1, amount, 1 do
			insert(self.int.tickets, item)
		end
		return self
	end
	
	function pot:stir(amount)
		initSeed()
		for i = 1, (amount or 1), 1 do
			self.int.tickets = stir(self.int.tickets)
		end
		return self
	end
	
	function pot:surprise()
		local max = #self.int.tickets
		if max == 0 then return end
		return self.int.tickets[mathRandom(1, max)]
	end
	
	return pot
end