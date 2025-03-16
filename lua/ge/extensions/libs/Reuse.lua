
return function()
	local reuse = {int = {
			objects = {},
			on_create = nil,
			on_take = nil,
			on_put = nil
		}
	}
	
	function reuse:onCreate(func)
		self.int.on_create = func
		return self
	end
	
	function reuse:onTake(func)
		self.int.on_take = func
		return self
	end
	
	function reuse:onPut(func)
		self.int.on_put = func
		return self
	end
	
	function reuse:take(...)
		local last = #self.int.objects
		local obj = self.int.objects[last]
		if obj then
			self.int.objects[last] = nil
		else
			if self.int.on_create then
				obj = self.int.on_create()
			else
				return nil
			end
		end
		if self.int.on_take then
			self.int.on_take(obj, ...)
		end
		return obj
	end
	
	function reuse:put(obj)
		if self.int.on_put then
			self.int.on_put(obj)
		end
		table.insert(self.int.objects, obj)
	end
	
	function reuse:count()
		return #self.int.objects
	end
	
	return reuse
end
