local ForceField = require("libs/ForceField")

local function randomName()
	return tostring({}):sub(8) -- dont ask, its quick n easy to just use a memory address xD
end

local function createMarker(radius, origin_vehicle)
	local half_extends = origin_vehicle:getSpawnWorldOOBB():getHalfExtents()
	
	local marker = createObject("TSStatic")
	marker.shapeName = "art/shapes/interface/checkpoint_marker.cdae"
	marker.useInstanceRenderData = 1
	marker.instanceColor = Point4F(1, 0, 0, 1)
	marker:setPosRot(0, 0, 0, 0, 0, 0, 1)
	marker.scale = vec3(half_extends.x + radius, half_extends.y + radius, 2)
	--marker:setInternalName(randomName())
	marker:registerObject("ff_marker_" .. tostring({}):sub(8))
	
	return marker
end

-- You can overwrite this function if your marker needs custom handling
local function updateMarker(origin_vehicle, settings)
	local bounding_box = origin_vehicle:getSpawnWorldOOBB()
	local center = bounding_box:getCenter()
	local rot = quatFromDir(
		-vec3(origin_vehicle:getDirectionVector()),
		vec3(origin_vehicle:getDirectionVectorUp())
	)
	settings.marker:setPosRot(center.x, center.y, center.z - 1, rot.x, rot.y, rot.z, rot.w)
	
	if settings.timer == nil then
		settings.timer = hptimer()
		settings.state_change = hptimer()
	end
	
	local diff = settings.time - settings.timer:stop()
	local stop = settings.state_change:stop()
	local step = settings.step
	
	if step == 0 and diff < 10000 and stop > 500 then
		settings.state = not settings.state
		settings.marker:setHidden(settings.state)
		settings.state_change:stopAndReset()
		if diff < 5000 then settings.step = 1 end
		
	elseif step == 1 and diff < 5000 and stop > 250 then
		settings.state = not settings.state
		settings.marker:setHidden(settings.state)
		settings.state_change:stopAndReset()
		if diff < 5000 then settings.step = 1 end
	end

end

local function destroyMarker(marker)
	marker:delete()
end

local function onDefaultForceFieldReaction(origin_vehicle, target_vehicle, settings)
	local vel1 = origin_vehicle:getVelocity()
	local vel2 = target_vehicle:getVelocity()
	
	local pos1 = origin_vehicle:getPosition()
	local pos2 = target_vehicle:getPosition()
	
	local push = ((vel1 - vel2) * 0.5) + (pos2 - pos1)
	target_vehicle:applyClusterVelocityScaleAdd(target_vehicle:getRefNodeId(), 1, push.x, push.y, push.z)
	
	return true
end

local function offDefaultForceFieldReaction(origin_vehicle, target_vehicle, settings)
	-- none atm
end

local set = {
	{"name", "settings", "type", "trigger after", "trigger for", "exec", "args"},
	{"", {spectate = false}, "GE", 0, 1, ForceField.addVehicle, "ve_target", 5, {timer = nil, time = 14000, state = true, state_change = nil, step = 0}, onDefaultForceFieldReaction, offDefaultForceFieldReaction, createMarker, updateMarker, destroyMarker},
	{"", {spectate = false}, "GE", 14000, 1, ForceField.remVehicle, "ve_target"},
	
}

return set