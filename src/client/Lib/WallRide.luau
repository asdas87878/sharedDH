--!strict
-- The wall ride (Config.Wall; Hugo, 2026-11-12 and 13; docs/design/riding-feel.md, "The wall ride"). Steered at a
-- wall, or the lane's edge, we are not stopped and we do not hit it: the wall is seen Wall.Look seconds of travel
-- ahead, and from there the way we go is bent onto the wall's own line, a little at first and wholly by the time we
-- are Wall.Gap from it, so we curve along it without touching, like a hoverboard pushing off. We keep our speed but
-- for a share that grows with how square on we are steered (Config.wallKeep), taken as the wall takes us. Dead
-- straight in (inside Wall.HeadOn degrees of square on) there is no slide either way: we slow into the wall and rock
-- up it and back down like a swing, dying away (a damped spring on our height), until we steer off it.
--
-- How: three rays feel for walls (the way we are steered, and Wall.Feelers degrees to each side of it), and the
-- lane's edge is one more wall. For each wall we may close on it no faster than brings us to the gap in about half
-- of Wall.Look (a soft limit: nothing at twice that distance, everything at the gap), and what that takes out of
-- the way we go turns us along the wall. So everything here is a smooth function of where we are and how we are
-- steered: there is no moment of contact, no frame the velocity is thrown round, and holding into a wall settles at
-- the gap instead of flickering between "at the wall" and "not". (Until 2026-11-13 the wall was looked for 0.12 s
-- ahead on one ray and the whole turn was made in the frame it was met; held into a wall at a shallow angle the ray
-- lost and found it again every other frame.)
-- One of these for whatever our own machine moves: the fish we ride (RideController.drive) and the hop
-- (JumpController). It only says which way to go, how much of the speed to keep and how the swing lifts us; what it
-- is given back to (Lib/Course: the floor, a roof, the surface, the lane's edge, and a wall met after all) still has
-- the last word, so nothing here can take us out of the map. It never touches the way we are steering (the yaw A and
-- D and the look turn), so steering off a wall is just steering, and the camera is left alone.
-- No animation is played here. The stand-in is the body turned along the wall, rolled a little away from it, and its
-- nose following the swing; State.Wall ("Slide" or "Swing") and State.WallSide are the hook for authored ones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Course = require(script.Parent.Course)

local WallRide = {}

export type Ride = {
	Touch: boolean, -- a wall is turning us now (it has us from the look-ahead on, well before the gap)
	Taken: number, -- 0 to 1: how much of our way into that wall it has taken (0 far off, 1 riding it at the gap)
	Kept: number, -- the share of our speed we have (eased: it drops as the wall takes us and comes back as we steer off)
	Slide: number, -- 0 to 1: how much of the way along the wall we go (1 off a wall; 0 square on at the wall, the swing)
	Swinging: boolean, -- in the swing
	Lift: number, -- the swing: how far it has us above where we met the wall, studs,
	LiftSpeed: number, -- and how fast that is changing
	Fed: number, -- how much of this swing's push up the wall has been given (it is given as the wall takes our speed)
	Lean: number, -- -1 to 1 (eased): the wall is on our left (-1) or our right (1); 0 off a wall
	Normal: Vector3, -- the wall's own way out, back into the open water (the last one that had us)
	Way: Vector3, -- the way we really went, last step (flat, unit),
	Push: Vector3, -- what the walls add to the way we steer, in shares of our speed (eased),
	Share: number, -- and the share of our speed that leaves us
	Near: number, -- how far its face is, less the gap we keep, studs (for the tests and the sandbox)
	Rest: number, -- seconds since we were last in the swing's part of a wall (a new swing is pushed only after a while)
}

function WallRide.new(): Ride
	return {
		Touch = false,
		Taken = 0,
		Kept = 1,
		Slide = 1,
		Swinging = false,
		Lift = 0,
		LiftSpeed = 0,
		Fed = 0,
		Lean = 0,
		Normal = Vector3.zAxis,
		Way = Vector3.zAxis,
		Push = Vector3.zero,
		Share = 1,
		Near = math.huge,
		Rest = math.huge,
	}
end

function WallRide.reset(ride: Ride)
	ride.Touch = false
	ride.Taken = 0
	ride.Kept = 1
	ride.Slide = 1
	ride.Swinging = false
	ride.Lift = 0
	ride.LiftSpeed = 0
	ride.Fed = 0
	ride.Lean = 0
	ride.Push = Vector3.zero
	ride.Share = 1
	ride.Near = math.huge
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

-- The walls felt this step: each its way out, how far its face is, how much of a wall it is (a step nearly too
-- high to climb is part of one: Course.feel), and whether it is the lane's own edge
local normals: { Vector3 } = {}
local fars: { number } = {}
local shares: { number } = {}
local edges: { boolean } = {}
local gaps: { number } = {} -- (and how far off it we would ride it, worked out each step,
local demands: { number } = {} -- and the most of our way we have asked to close on it with)
local count = 0

local function add(normal: Vector3?, far: number, share: number, edge: boolean)
	if not normal or share <= 0 then
		return
	end
	for i = 1, count do
		-- (the same face met by two rays)
		if edges[i] == edge and normals[i]:Dot(normal) > 0.985 and math.abs(fars[i] - far) < 1.5 then
			if far < fars[i] then
				normals[i], fars[i] = normal, far
			end
			shares[i] = math.max(shares[i], share)
			return
		end
	end
	if count >= 12 then
		return
	end
	count += 1
	normals[count], fars[count], shares[count], edges[count] = normal, far, share, edge
end

-- How fast we may close on a wall, as a share of our speed: `room` is how far we are from where we would ride it,
-- `into` the share of our way that goes into it, `span` the distance the limit works over (our speed for half of
-- Wall.Look). Nothing is taken at twice the distance the plain limit would start at, everything at the gap, with no
-- corner at either end; inside the gap we are let out again, gently.
local function allowed(room: number, into: number, span: number): number
	if room <= 0 then
		return math.max(room / span, -0.15)
	end
	local x = room / (span * into)
	if x >= 2 then
		return into
	end
	return into * (x - x * x / 4)
end

-- A step: we are at `at`, steered the way `yaw` (radians, as CFrame.fromOrientation(0, yaw, 0)), at `speed` studs a
-- second; `long` and `wide` are the body's half length and half width (what must stay clear of the wall: its width
-- riding along it, its length facing it); `steps`: a low step with open water over it is no wall (the ridden fish
-- goes up over it: Course.clearVelocity).
-- Back come the way to really go (flat, unit) and the share of `speed` to go at. The body is turned from `yaw` to
-- that way by ride.Slide; the swing is ride.Lift and ride.LiftSpeed, and how much it counts is 1 - ride.Slide.
function WallRide.step(
	ride: Ride,
	at: Vector3,
	yaw: number,
	speed: number,
	long: number,
	wide: number,
	dt: number,
	steps: boolean?
): (Vector3, number)
	local w = Config.Wall
	local heading = CFrame.fromOrientation(0, yaw, 0).LookVector
	local way = heading
	local keep = 1
	local slide = 1
	local lean = 0
	local taken = 0
	local near = math.huge
	local look = math.max(w.Look, 0.05)
	local span = math.max(speed, 8) * look / 2
	local gap = math.max(w.Gap, 0)
	count = 0
	if w.On ~= 0 then
		local reach = 1.5 * (gap + long) + math.max(speed, 8) * look
		local turn = math.rad(math.clamp(w.Feelers, 10, 80))
		-- what is in the way we are steered, and in the way we really went last (along a wall, that is on along it)
		local n, far, share, n2, far2, share2 = Course.feel(at, heading, reach, steps)
		add(n, far, share, false)
		add(n2, far2, share2, false)
		if ride.Way:Dot(heading) < 0.999 then
			n, far, share, n2, far2, share2 = Course.feel(at, ride.Way, reach, steps)
			add(n, far, share, false)
			add(n2, far2, share2, false)
		end
		-- and what is beside us. A ray to the side only says a wall may be there: a wall counts when it really
		-- stands square across from us (a ray straight at it meets it). The end of a wall's piece that sticks out
		-- beside our way, which we would never reach, does not: it had us braking for nothing where a wall waves.
		for side = -1, 1, 2 do
			local dir = CFrame.fromOrientation(0, yaw + side * turn, 0).LookVector
			local seen, _, _, seen2 = Course.feel(at, dir, reach, steps)
			for pass = 1, 2 do
				local to = if pass == 1 then seen else seen2
				if to then
					n, far, share, n2, far2, share2 = Course.feel(at, -to, reach, steps)
					if n and n:Dot(to) > 0.9 then
						add(n, far, share, false)
					end
					if n2 and n2:Dot(to) > 0.9 then
						add(n2, far2, share2, false)
					end
				end
			end
		end
		n, far = Course.edge(at)
		add(n, far, 1, true)
	end
	-- Where we would ride each wall: the gap, and the body's own reach toward it as it really points (its width
	-- going along the wall, its length facing it in the swing, and between the two in a corner we can't turn out
	-- of. Sized for a body lying along the wall, a fish held nose on to the hub's front by the
	-- mouth's side wall was let up to it, into Lib/Course's hard rule: measured 2026-11-13.)
	local pointed = heading:Lerp(ride.Way, ride.Slide) -- (as the body is turned: from the way we steer to the way we go)
	pointed = if pointed.Magnitude > 0.01 then pointed.Unit else heading
	for i = 1, count do
		if edges[i] then
			gaps[i] = math.max(w.Band, 0)
		else
			local facing = math.clamp(-pointed:Dot(normals[i]), 0, 1)
			gaps[i] = gap + wide * math.sqrt(1 - facing * facing) + long * facing
		end
	end
	-- The wall that has us: the one that takes most of the way we steer. By it: how much of our speed the angle
	-- leaves us, whether we slide or swing, and which way we lean.
	local main, mainBite, mainInto = 0, 1e-4, 0
	for i = 1, count do
		local into = -heading:Dot(normals[i])
		local room = fars[i] - gaps[i]
		demands[i] = math.max(into, 1e-3)
		if into > 1e-3 or room < 0 then
			local bite = (into - allowed(room, demands[i], span)) * shares[i]
			if bite > mainBite then
				main, mainBite, mainInto = i, bite, into
			end
		end
	end
	local alone = heading -- the way we would go with only that wall there
	if main > 0 then
		local normal = normals[main]
		taken = math.clamp(mainBite / math.max(mainInto, 0.05), 0, 1)
		near = fars[main] - gaps[main]
		ride.Normal = normal
		-- the way we are steered, less its part into the wall: along the wall, the side we already lean to
		local off = math.asin(math.clamp((heading + normal * mainInto).Magnitude, 0, 1))
		local turned = Ease.smoothstep(math.rad(w.HeadOn), math.rad(w.HeadOn + math.max(w.Blend, 0.1)), off)
		keep = Ease.lerp(1, Config.wallKeep(math.max(mainInto, 0)), taken)
		slide = Ease.lerp(1, turned, taken)
		lean = (if heading:Cross(Vector3.yAxis):Dot(normal) < 0 then 1 else -1) * turned * taken
		alone = heading + normal * mainBite
	end
	-- The way we go: the way we steer, with what would close on any wall faster than its limit taken out of it.
	-- Every wall is gone over a few times, so where it ends does not hang on their order (taken one after another,
	-- once each, two walls at a corner swapped places from frame to frame and the way we went flicked 20 degrees
	-- each time: measured 2026-11-13 in the corner of the hub's front and the mouth's side). A wall's limit is by
	-- the most we have asked to close on it, so a second time over the same wall changes nothing.
	local go = heading
	for _ = 1, 4 do
		for i = 1, count do
			local normal = normals[i]
			local into = -go:Dot(normal)
			local room = fars[i] - gaps[i]
			if into > 1e-3 or room < 0 then
				if into > demands[i] then
					demands[i] = into
				end
				local let = allowed(room, demands[i], span)
				if into > let then
					go += normal * ((into - let) * shares[i])
				end
			end
		end
	end
	-- How fast: with the one wall, the speed its angle leaves us (more than is left of the way we steer, which
	-- alone would be the old slide at whatever speed is left); with more walls, less by as much as they take.
	ride.Kept = Ease.lerp(ride.Kept, keep, Ease.alpha(w.Ease, dt))
	local pace = ride.Kept * slide / math.max(alone.Magnitude, 0.05)
	go *= math.min(pace, 2)
	-- Other walls took more of it than the one wall would (a corner): by as much, we are square on to the corner.
	-- Steered right into one there is nothing left, and that is the swing, as at a wall met square on.
	slide *= Ease.smoothstep(0, 0.7, go.Magnitude / math.max(ride.Kept * slide, 1e-3))
	ride.Touch = taken > 0.03
	ride.Taken = taken
	ride.Near = near
	-- (what the walls do to us is eased a little, Wall.Soft: a wall seen coming moves all of this slowly anyway, but
	-- one that is suddenly there, close by, would turn us in a frame: a terrace's lip as we sink past the height we
	-- still climb over it at. How we steer is not eased: only what a wall adds to it. Props are never a wall: the
	-- rays leave them out, Lib/Course.)
	local soft = Ease.alpha(math.max(w.Soft, 1), dt)
	slide = Ease.lerp(ride.Slide, slide, soft)
	ride.Slide = slide
	ride.Lean = Ease.lerp(ride.Lean, lean, Ease.alpha(6, dt))
	-- the swing: square on, the speed the wall takes from us goes up it, and we rock there. It is given as it is
	-- taken (over the look-ahead), not all at once at the wall.
	local square = 1 - slide
	if square > 0.02 then
		ride.Swinging = true
		ride.Rest = 0
		if square > ride.Fed then
			local omega = 2 * math.pi * math.max(w.SwingRate, 0.05)
			ride.LiftSpeed += math.min(speed * w.SwingKick, w.SwingMost * omega) * (square - ride.Fed)
			ride.Fed = square
		end
	else
		ride.Rest += dt
		if ride.Rest > 0.15 then
			-- (a wall lost for a frame doesn't end the swing: a ray can miss a seam)
			ride.Swinging = false
		end
		if ride.Rest > 0.4 then
			ride.Fed = 0
		end
	end
	swing(ride, dt)
	-- What the walls add to the way we steer (a push, in shares of our speed): eased, then put back on the way we
	-- steer now. It is eased as a push in the world, where the walls are, not as an angle off our heading: an angle
	-- going from one side to the other passes through straight on, into the wall.
	ride.Push = ride.Push:Lerp(go - heading, soft)
	local went = heading + ride.Push
	local share = went.Magnitude
	if share > 1e-3 then
		way = went / share
		ride.Way = way
	else
		way = ride.Way
	end
	ride.Share = share
	return way, share
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
