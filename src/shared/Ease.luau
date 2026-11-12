--!strict
-- Small maths for movement and feel.
local Ease = {}

function Ease.clamp01(t: number): number
	return math.clamp(t, 0, 1)
end

function Ease.outQuad(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) * (1 - t)
end

function Ease.inQuad(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t
end

function Ease.inOutSine(t: number): number
	t = math.clamp(t, 0, 1)
	return -(math.cos(math.pi * t) - 1) / 2
end

function Ease.smoothstep(a: number, b: number, x: number): number
	if b == a then
		-- (no width: a step. Dividing gave NaN when x was the same number too, and a NaN CFrame loses the character)
		return if x >= b then 1 else 0
	end
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Frame-rate independent approach: the fraction to move this frame at the given rate
function Ease.alpha(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

function Ease.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Shortest-way lerp between two angles in radians
function Ease.lerpAngle(a: number, b: number, t: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * t
end

-- The ridden speed curve: idle to ridden over RampTime, easing out, times the mount surge
function Ease.rideSpeed(
	startSpeed: number,
	ridden: number,
	t: number,
	rampTime: number,
	surge: number,
	surgeTime: number
): number
	local base = startSpeed + (ridden - startSpeed) * Ease.outQuad(t / rampTime)
	local surgeAmount = 1 - Ease.smoothstep(surgeTime * 0.6, surgeTime * 1.4, t)
	return base * (1 + (surge - 1) * surgeAmount)
end

return Ease
