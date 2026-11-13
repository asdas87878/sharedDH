--!strict
-- The wall ride (Config.Wall; Hugo, 2026-11-12; docs/design/riding-feel.md, "The wall ride"). Steered into a wall, or
-- the lane's edge, we are not stopped: we are turned along it and ride it, like a hoverboard pushing off, keeping our
-- speed but for a share that grows with how square on we are steered (Config.wallKeep). Dead straight in (inside
-- Wall.HeadOn degrees of square on) there is no slide either way: we rock up the wall and back down like a swing,
-- dying away (a damped spring on our height), until we steer off it.
-- One of these for whatever our own machine moves: the fish we ride (RideController.drive) and the hop
-- (JumpController). It only says which way to go, how much of the speed to keep and how the swing lifts us; what it
-- is given back to (Lib/Course: the floor, a roof, the surface, the lane's edge) still has the last word, so nothing
-- here can take us out of the map. It never touches the way we are steering (the yaw A and D and the look turn), so
-- steering off a wall is just steering, and the camera is left alone.
-- No animation is played here. The stand-in is the body turned along the wall, rolled a little away from it, and its
-- nose following the swing; State.Wall ("Slide" or "Swing") and State.WallSide are the hook for authored ones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Course = require(script.Parent.Course)

local WallRide = {}

export type Ride = {
	Touch: boolean, -- we are steered into a wall now
	Kept: number, -- the share of our speed we have (eased: it drops at the wall and comes back as we steer off)
	Slide: number, -- 0 to 1: how much of the way along the wall we go (0: square on, the swing)
	Swinging: boolean, -- in the swing
	Lift: number, -- the swing: how far it has us above where we met the wall, studs,
	LiftSpeed: number, -- and how fast that is changing
	Lean: number, -- -1 to 1 (eased): the wall is on our left (-1) or our right (1); 0 off a wall
	Normal: Vector3, -- the wall's own way out, back into the open water (the last one touched)
	Rest: number, -- seconds since we were last in the swing's part of a wall (a new swing is kicked only after a while)
}

function WallRide.new(): Ride
	return {
		Touch = false,
		Kept = 1,
		Slide = 1,
		Swinging = false,
		Lift = 0,
		LiftSpeed = 0,
		Lean = 0,
		Normal = Vector3.zAxis,
		Rest = math.huge,
	}
end

function WallRide.reset(ride: Ride)
	ride.Touch = false
	ride.Kept = 1
	ride.Slide = 1
	ride.Swinging = false
	ride.Lift = 0
	ride.LiftSpeed = 0
	ride.Lean = 0
	ride.Rest = math.huge
end

-- The swing's height, a step on: a damped spring back to where we met the wall (in small steps, so a slow frame can't
-- throw it). Out of the swing it settles without swinging back.
local function swing(ride: Ride, dt: number)
	if ride.Lift == 0 and ride.LiftSpeed == 0 then
		return
	end
	local w = Config.Wall
	local omega = 2 * math.pi * math.max(w.SwingRate, 0.05)
	local damp = if ride.Swinging then math.clamp(w.SwingDamp, 0, 1) else 1
	local steps = math.max(math.ceil(dt * 120), 1)
	local h = dt / steps
	for _ = 1, steps do
		ride.LiftSpeed += (-omega * omega * ride.Lift - 2 * damp * omega * ride.LiftSpeed) * h
		ride.Lift += ride.LiftSpeed * h
	end
	if not ride.Swinging and math.abs(ride.Lift) < 0.05 and math.abs(ride.LiftSpeed) < 0.5 then
		ride.Lift = 0
		ride.LiftSpeed = 0
	end
end

-- A step: we are at `at`, steered the way `yaw` (radians, as CFrame.fromOrientation(0, yaw, 0)), at `speed` studs a
-- second; `reach` is how far ahead of `at` a wall is met (the body's half length, and a moment of travel); `steps`:
-- a low step with open water over it is no wall (the ridden fish goes up over it: Course.clearVelocity).
-- Back come the way to really go (flat, unit) and the share of `speed` to go at. The swing is ride.Lift and
-- ride.LiftSpeed, and how much it counts is 1 - ride.Slide while ride.Swinging.
function WallRide.step(
	ride: Ride,
	at: Vector3,
	yaw: number,
	speed: number,
	reach: number,
	dt: number,
	steps: boolean?
): (Vector3, number)
	local w = Config.Wall
	local heading = CFrame.fromOrientation(0, yaw, 0).LookVector
	local normal = if w.On ~= 0 then Course.wall(at, heading, reach, steps) else nil
	local into = if normal then -heading:Dot(normal) else 0
	local way = heading
	local keep = 1
	local slide = 1
	local lean = 0
	local touch = normal ~= nil and into > 0.02
	if touch and normal then
		ride.Normal = normal
		-- the way we are steered, less its part into the wall: along the wall, the side we already lean to
		local along = heading + normal * into
		local share = along.Magnitude -- (the sine of how far off square on we are)
		local off = math.asin(math.clamp(share, 0, 1))
		slide = Ease.smoothstep(math.rad(w.HeadOn), math.rad(w.HeadOn + math.max(w.Blend, 0.1)), off)
		if share > 1e-3 then
			way = along / share
		end
		keep = Config.wallKeep(into)
		lean = if heading:Cross(Vector3.yAxis):Dot(normal) < 0 then 1 else -1
	end
	ride.Touch = touch
	ride.Slide = slide
	ride.Kept = Ease.lerp(ride.Kept, keep, Ease.alpha(w.Ease, dt))
	ride.Lean = Ease.lerp(ride.Lean, lean * slide, Ease.alpha(6, dt))
	-- the swing: square on, we go up the wall with a share of our speed, and rock there
	local square = touch and slide < 1
	if square then
		if not ride.Swinging then
			ride.Swinging = true
			if ride.Rest > 0.4 then
				local omega = 2 * math.pi * math.max(w.SwingRate, 0.05)
				ride.LiftSpeed = math.max(ride.LiftSpeed, math.min(speed * w.SwingKick, w.SwingMost * omega))
			end
		end
		ride.Rest = 0
	else
		ride.Rest += dt
		if ride.Rest > 0.15 then
			-- (a wall lost for a frame doesn't end the swing: a ray can miss a seam)
			ride.Swinging = false
		end
	end
	swing(ride, dt)
	-- (the slide's share is taken at once, not eased: square on there is no sideways travel from the first frame)
	return way, ride.Kept * slide
end

-- The hook for authored animations (and the stand-in's own word): "Swing", "Slide" or nil off a wall
function WallRide.state(ride: Ride): string?
	if ride.Swinging then
		return "Swing"
	elseif ride.Touch then
		return "Slide"
	end
	return nil
end

return WallRide
