--!strict
-- Critically damped springs, for the camera: a value closes on its goal as fast as it can without
-- overshooting, and its speed never jumps, so nothing snaps when the goal does. `time` is about how long it takes to
-- close a gap. Each call takes the value and its speed now and returns both for the next frame.
local Spring = {}

local function terms(time: number, dt: number): (number, number)
	local omega = 2 / math.max(time, 1e-4)
	local x = omega * dt
	return omega, 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
end

function Spring.number(current: number, goal: number, velocity: number, time: number, dt: number): (number, number)
	local omega, decay = terms(time, dt)
	local change = current - goal
	local temp = (velocity + omega * change) * dt
	return goal + (change + temp) * decay, (velocity - omega * temp) * decay
end

function Spring.vector(current: Vector3, goal: Vector3, velocity: Vector3, time: number, dt: number): (Vector3, Vector3)
	local omega, decay = terms(time, dt)
	local change = current - goal
	local temp = (velocity + change * omega) * dt
	return goal + (change + temp) * decay, (velocity - temp * omega) * decay
end

-- An angle in radians, the shortest way round
function Spring.angle(current: number, goal: number, velocity: number, time: number, dt: number): (number, number)
	local near = current + ((goal - current + math.pi) % (2 * math.pi) - math.pi)
	return Spring.number(current, near, velocity, time, dt)
end

return Spring
