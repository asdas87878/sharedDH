--!strict
-- The submarine's trip (docs/design/submarine.md), worked out the same on the server and on every client: its phases
-- by the clock, and where along its path it is. The server makes a trip (SubService) and writes it on the player as
-- JSON (the "SubTrip" attribute); every machine reads it back and moves its own copy of the sub (SubController).
--   Phases, in seconds from the trip's start (server time, workspace:GetServerTimeNow()):
--     Approach: the player swims at the surface while the sub swims in;
--     Pickup: it scoops them onto its seat at the path's first point;
--     Ride: the run, picking up to its top speed, cruising, slowing to the drop speed;
--     Arrive: "NOW ARRIVING", at the drop speed;
--     Drop: the fling, or the fish beside the sub and the kick onto it.
--   The path is a list of points from the pick-up to past the drop point; the sub runs along it by distance.
--   The escort (Hugo, 2026-11-24: "you should also hop from fish to submarine while seeing the fish swim off next to you
--   looping left and right then come back once you arrive"): for a rider who went in on their ride fish, that fish is
--   there for the whole trip. Where it is at any time is SubTrip.escort, worked out from the trip alone, so the server,
--   every machine and the offline check (tools/subs/escort_check.luau) all have it in the same place with no traffic.
local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)
local Ease = require(script.Parent.Ease)

local UP = Vector3.yAxis

-- The fish that swims with the sub (nil in a trip: none). All in studs; the sub's frame is x to its right, y up and z
-- AHEAD of its middle
export type Escort = {
	Half: Vector3, -- half the fish's box: wide, high, long
	Saddle: Vector3, -- its saddle against its root (the root's own axes: -Z ahead)
	From: Vector3, -- its root as the rider went in,
	Way: Vector3, -- and the way it was going, flat
	Wide: number, -- the sub's hull (SubTrip.Hulls): half its width,
	Top: number, -- over its middle,
	Bottom: number, -- under it,
	Nose: number, -- and ahead of it
	Loop: boolean, -- it goes round the hull (over, under); else it sweeps from side to side ahead of the nose
	Side: number, -- its place beside the sub: this far to the right (the pick-up and the kick)
	Low: number, -- the weave's furthest left (negative)
	High: number, -- and right
	Lead: number, -- how far ahead of the sub's middle it weaves
	Turns: number, -- whole sweeps there and back
}

export type Trip = {
	Start: number, -- server time the sub sets off toward the player
	Land: number, -- the land it goes to
	Fish: boolean, -- a fish of the player's swims up for the drop-off (else the fling)
	Approach: number,
	Pickup: number,
	SpeedUp: number,
	Cruise: number,
	SlowDown: number,
	Top: number, -- its top speed on this trip
	Drop: number, -- its speed at the drop
	Arrive: number,
	DropTime: number, -- the drop phase's length (the fling, or the fish's last moment and the kick)
	Points: { Vector3 },
	Along: { number }, -- distance along the path at each point
	Length: number,
	Escort: Escort?,
}

local SubTrip = {}

-- The nine hulls' boxes about the sub's middle, by tier: half the width, up, down, the nose, the tail. Read off
-- art/subs/*/*.glb; tools/subs/escort_check.luau's partner, escort_hulls.py, fails if a model outgrows its row
SubTrip.Hulls = {
	{ 10.5, 11.2, 5.4, 18.3, 21.0 },
	{ 10.5, 14.9, 5.4, 20.1, 21.0 },
	{ 11.5, 15.7, 5.4, 19.8, 22.5 },
	{ 8.3, 15.5, 5.6, 19.2, 21.0 },
	{ 13.2, 11.8, 5.0, 23.8, 23.8 },
	{ 20.7, 11.2, 5.2, 22.9, 28.1 },
	{ 11.0, 14.8, 7.0, 22.8, 24.6 },
	{ 13.1, 11.2, 7.7, 27.7, 21.8 },
	{ 10.0, 15.8, 8.9, 33.5, 26.3 },
} :: { { number } }

-- The rider's seat against the sub's middle, and how far its middle sits under the seat
SubTrip.Seat = CFrame.new(0, 7.4, 5)

local function levelOf(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

-- The run's speeds for a ride of `distance` studs: up to the top speed, cruising, down to the drop speed. The top
-- speed grows with the distance (Sub.Speed + Sub.SpeedPer a stud: task f2, Hugo 2026-11-20, "make travelling faster
-- the further away the destination"), so a far land's run is not much longer than a near one's; the run is then kept
-- between Sub.MinRide and Sub.MaxRide seconds (the top speed worked out again from the time where it is). The
-- speed-up and the slow-down are shares of the run (Sub.UpShare, Sub.DownShare), so a far run's burst is as big.
function SubTrip.plan(distance: number): (number, number, number, number)
	local c = Config.Sub
	local drop = c.DropSpeed
	local a = math.clamp(c.UpShare, 0.05, 0.45)
	local b = math.clamp(c.DownShare, 0.05, 0.45)
	local d = math.max(distance, 0)
	-- (distance = top * T * (1 - (a + b) / 2) + drop * b * T / 2)
	local cover = 1 - (a + b) / 2
	local top = c.Speed + c.SpeedPer * d
	local time = d / math.max(top * cover + drop * b / 2, 1)
	if time < c.MinRide or time > c.MaxRide then
		time = math.clamp(time, c.MinRide, math.max(c.MaxRide, c.MinRide))
		top = (d / time - drop * b / 2) / cover
	end
	if top <= drop then
		-- (a trip too short for even that: straight at the drop speed)
		return 0, d / drop, 0, drop
	end
	return a * time, (1 - a - b) * time, b * time, top
end

-- Seconds from the trip's start at which each phase begins: the pick-up, the run, the arrival, the drop, and the end
function SubTrip.times(trip: Trip): (number, number, number, number, number)
	local pickup = trip.Approach
	local ride = pickup + trip.Pickup
	local arrive = ride + trip.SpeedUp + trip.Cruise + trip.SlowDown
	local drop = arrive + trip.Arrive
	return pickup, ride, arrive, drop, drop + trip.DropTime
end

-- The phase at `t` seconds from the start
function SubTrip.phase(trip: Trip, t: number): string
	local pickup, ride, arrive, drop, finish = SubTrip.times(trip)
	return if t < pickup
		then "Approach"
		elseif t < ride then "Pickup"
		elseif t < arrive then "Ride"
		elseif t < drop then "Arrive"
		elseif t < finish then "Drop"
		else "Done"
end

-- How far along the path the sub is at `t` seconds from the start (0 until the run), and its speed
function SubTrip.distance(trip: Trip, t: number): (number, number)
	local _, ride = SubTrip.times(trip)
	local u = t - ride
	if u <= 0 then
		return 0, 0
	end
	local top, drop = trip.Top, trip.Drop
	local a = trip.SpeedUp
	if u < a then
		local v = top * u / a
		return v * u / 2, v
	end
	local d = top * a / 2
	u -= a
	if u < trip.Cruise then
		return d + top * u, top
	end
	d += top * trip.Cruise
	u -= trip.Cruise
	local b = trip.SlowDown
	if u < b then
		local v = top + (drop - top) * u / math.max(b, 0.01)
		return d + (top + v) / 2 * u, v
	end
	d += (top + drop) / 2 * b
	u -= b
	return d + drop * u, drop
end

-- Where the drop is along the path (the end of Arrive)
function SubTrip.dropDistance(trip: Trip): number
	local _, _, _, drop = SubTrip.times(trip)
	return (SubTrip.distance(trip, drop))
end

-- The point `d` studs along the path, and the way it goes there (smoothed over `look` studs either side)
function SubTrip.at(trip: Trip, d: number): Vector3
	local points, along = trip.Points, trip.Along
	local n = #points
	if n == 0 then
		return Vector3.zero
	end
	if d <= 0 or n == 1 then
		return points[1]
	end
	if d >= along[n] then
		local last = points[n] - points[n - 1]
		return points[n] + (if last.Magnitude > 0 then last.Unit else Vector3.zAxis) * (d - along[n])
	end
	local lo, hi = 1, n
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if along[mid] <= d then
			lo = mid
		else
			hi = mid
		end
	end
	local span = along[hi] - along[lo]
	local u = if span > 0 then (d - along[lo]) / span else 0
	-- (Catmull-Rom through the points either side, so the run has no corners)
	local p0 = points[math.max(lo - 1, 1)]
	local p1, p2 = points[lo], points[hi]
	local p3 = points[math.min(hi + 1, n)]
	local u2, u3 = u * u, u * u * u
	return 0.5 * ((p1 * 2) + (p2 - p0) * u + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * u2 + (p1 * 3 - p0 - p2 * 3 + p3) * u3)
end

function SubTrip.way(trip: Trip, d: number, look: number?): Vector3
	local l = look or 12
	local a, b = SubTrip.at(trip, d - l), SubTrip.at(trip, d + l)
	local way = b - a
	return if way.Magnitude > 0.01 then way.Unit else Vector3.new(0, 0, -1)
end

-- A long fish takes this many times as long to peel off and to come back
local function slower(half: Vector3): number
	return math.clamp((half.Z / 15) ^ 0.35, 1, 1.6)
end

-- How long the rider's fish takes to come back beside the sub, seconds: a longer one longer (Config.Sub.EscortReturn)
local function returning(half: Vector3): number
	return Config.Sub.EscortReturn * slower(half)
end

-- The sub's place at `t` seconds into the trip, and how fast it goes (studs a second)
function SubTrip.sub(trip: Trip, t: number): (CFrame, number)
	local pickupAt, rideAt, _, dropAt, endAt = SubTrip.times(trip)
	local pick = trip.Points[1]
	local way0 = levelOf(SubTrip.way(trip, 30, 30))
	local right = way0:Cross(UP)
	local rest = pick - UP * 8
	if t < pickupAt then
		-- (approachPose) up from behind, below and to the side, slowing as it comes under us
		local u = math.clamp(t / math.max(pickupAt, 0.01), 0, 1)
		local e = 1 - (1 - u) ^ 2
		-- (kept over the floor at the gate: the water there is about 46 deep, and we take the sub 17 under)
		local p0 = pick - way0 * 170 - UP * 18 + right * 30
		local p1 = pick - way0 * 50 - UP * 16 + right * 6
		local escort = trip.Escort
		if escort then
			-- (the rider's fish comes up on the right: the sub comes in on the left of it, further off the wider it is)
			p0 = pick - way0 * 170 - UP * 14 - right * (30 + escort.Side)
			-- (and straight up the last of it, so its nose doesn't swing into the fish)
			p1 = pick - way0 * 50 - UP * 12
		end
		local a, b = p0:Lerp(p1, e), p1:Lerp(rest, e)
		local at = a:Lerp(b, e)
		local dir = b - a
		dir = if dir.Magnitude > 0.1 then dir.Unit else way0
		return CFrame.lookAt(at, at + dir), 40 * (1 - e) + 10
	elseif t < rideAt then
		-- (pickupPose) rising under us to bring its seat to us, then dipping its nose to go
		local u = (t - pickupAt) / math.max(rideAt - pickupAt, 0.01)
		local at = rest:Lerp(pick, Ease.smoothstep(0, 0.55, u))
		local dip = math.rad(-12) * Ease.smoothstep(0.75, 1, u)
		local bob = math.sin(u * math.pi) * math.rad(4)
		return CFrame.lookAt(at, at + way0) * CFrame.Angles(dip + bob, 0, 0), 4
	end
	-- (ridePose, dropPose) along the path
	local d, v = SubTrip.distance(trip, t)
	local at = SubTrip.at(trip, d)
	local way = SubTrip.way(trip, d, 10 + v * 0.04)
	-- banked into the bends, by how the way turns over the next half second
	local ahead = levelOf(SubTrip.way(trip, d + math.max(v * 0.5, 20), 10 + v * 0.04))
	local turn = levelOf(way):Cross(ahead).Y
	local bank = math.clamp(-turn * 3, -0.7, 0.7)
	if trip.Escort then
		-- (level while the fish is beside it, at the start and for the kick: banking, its side would come up into the fish)
		local back = dropAt - Config.Sub.EscortSettle - returning(trip.Escort.Half)
		bank *= Ease.smoothstep(rideAt + 0.2, rideAt + 0.2 + Config.Sub.EscortPeel, t) * (1 - Ease.smoothstep(
			back - 0.4,
			back + 0.2,
			t
		))
	end
	local cf = CFrame.lookAt(at, at + way) * CFrame.Angles(0, 0, bank)
	if t >= dropAt then
		local since = t - dropAt
		if not trip.Fish then
			-- the fling: the nose comes up and drops again
			cf *= CFrame.Angles(math.rad(26) * math.sin(math.clamp(since / 0.7, 0, 1) * math.pi), 0, 0)
		end
		if t >= endAt then
			-- (peeling away) up and to the side (with a fish on its right, to the left: never through it)
			local k = t - endAt
			local side = levelOf(way):Cross(UP) * (if trip.Escort then -1 else 1)
			cf = cf + side * (k * k * 14) + UP * (k * k * 10)
			cf *= CFrame.Angles(
				math.rad(12) * math.min(k, 1),
				0,
				math.rad(if trip.Escort then 25 else -25) * math.min(k, 1)
			)
		end
	end
	return cf, v
end

----------------------------------------------------------------------------------------------------------------------
-- The escort: the rider's own fish for the whole trip (Config.Sub's Escort numbers)

local ROLL = 0.7 -- the sub's bank on the run is up to this much (SubTrip.sub), radians

-- How far each way the hull reaches as it banks
local function rolled(wide: number, top: number, bottom: number): (number, number, number)
	local c, s = math.cos(ROLL), math.sin(ROLL)
	return math.max(wide, wide * c + math.max(top, bottom) * s), wide * s + top * c, wide * s + bottom * c
end

-- How far its nose turns off the sub's way in a sweep: less for a long fish, whose ends swing out as it turns
local function yawMost(half: Vector3): number
	return math.min(
		math.rad(Config.Sub.EscortYaw),
		math.asin(math.min(1, Config.Sub.EscortSwing / math.max(half.Z, 1)))
	)
end

-- The room a fish turning and banking that much takes either side of its middle
local function sideways(half: Vector3): number
	local yaw, bank = yawMost(half), math.rad(Config.Sub.EscortBank)
	local across = math.max(half.X, half.X * math.cos(bank) + half.Y * math.sin(bank))
	return across * math.cos(yaw) + half.Z * math.sin(yaw)
end

-- How far out to the side its place beside the sub is
function SubTrip.escortSide(half: Vector3, tier: number): number
	local hull = SubTrip.Hulls[math.clamp(tier, 1, #SubTrip.Hulls)]
	-- (a long one a little further: its ends swing out in the bends)
	return math.max(Config.Sub.FishSide, hull[1] + half.X + Config.Sub.EscortGap + half.Z * 0.06)
end

-- How far out from where the rider went in the sub takes them: far enough that a long fish's tail is out of the gate
function SubTrip.escortOut(half: Vector3, saddle: Vector3): number
	local c = Config.Sub
	local behind = half.Z - saddle.Z -- (its tail, behind its saddle)
	return math.clamp(c.EscortOut + behind * 0.6, c.EscortOut, c.EscortOutMost)
end

-- Plans the escort of a trip (the server). `left` and `right`: the open water either side of the sub's line along the
-- run, the least of it, studs
function SubTrip.escorted(
	trip: Trip,
	tier: number,
	half: Vector3,
	saddle: Vector3,
	from: Vector3,
	way: Vector3,
	left: number,
	right: number
)
	local c = Config.Sub
	local hull = SubTrip.Hulls[math.clamp(tier, 1, #SubTrip.Hulls)]
	local wide, _, down = rolled(hull[1], hull[2], hull[3])
	local body = sideways(half)
	local side = SubTrip.escortSide(half, tier)
	local reach = wide + body + c.EscortGap
	-- round the hull: only a fish that fits between its keel and the floor, and with the water beside it to come round in
	local out = reach + c.EscortWide
	local loop = down + c.EscortGap + half.Y * 2 + 2 <= c.Lift
		and half.Z <= c.EscortLoopLong / 2
		and out + body <= math.min(left, right)
	-- (ahead of the nose, with the room its tail and fins need as it turns and tips)
	local swing = half.X * math.sin(yawMost(half)) + half.Y * math.sin(math.rad(c.EscortTip))
	local lead = if loop then c.EscortLead else hull[4] + half.Z + swing + c.EscortGap + c.EscortLead
	local high = if loop then out else math.max(math.min(out, right - body - c.EscortGap), 0)
	local low = if loop then -out else -math.max(math.min(out, left - body - c.EscortGap), 0)
	local length = math.max(half.Z * 2, 1)
	local every = c.EscortPeriod * math.clamp((length / 20) ^ 0.3, 1, 1.7)
	local a, b = SubTrip.escortTimes(trip, half)
	trip.Escort = {
		Half = half,
		Saddle = saddle,
		From = from,
		Way = levelOf(way),
		Wide = hull[1],
		Top = hull[2],
		Bottom = hull[3],
		Nose = hull[4],
		Loop = loop,
		Side = side,
		Low = low,
		High = high,
		Lead = lead,
		Turns = math.max(1, math.floor((b - a) / every)),
	}
end

-- When the weave's sweeps begin and end, seconds into the trip (it peels off a little before and is back a little after)
function SubTrip.escortTimes(trip: Trip, half: Vector3): (number, number)
	local c = Config.Sub
	local _, rideAt, _, dropAt = SubTrip.times(trip)
	return rideAt + c.EscortPeel * slower(half) * 0.6, dropAt - c.EscortSettle - returning(half) * 0.6
end

-- The height (over the sub's middle, `subY` in the world) that keeps a fish `half` high off the floor and under the
-- surface; one too tall for the water there has as much of it out either way
local function fit(y: number, subY: number, half: number): number
	local c = Config.Sub
	local low = half + 2 - c.Lift
	local high = Config.Oxygen.SurfaceY - 2 - subY - half
	return if low > high then (low + high) / 2 else math.clamp(y, low, high)
end

-- 0 to 1 over a span at one pace, but for a soft start and end
local function steady(from: number, to: number, t: number): number
	local soft = 0.2
	local u = math.clamp((t - from) / math.max(to - from, 1e-3), 0, 1)
	local peak = 1 / (1 - soft)
	if u < soft then
		return peak * u * u / (2 * soft)
	elseif u > 1 - soft then
		return 1 - peak * (1 - u) * (1 - u) / (2 * soft)
	end
	return peak * (u - soft / 2)
end

-- How freely it can turn and bank where it is: 0 beside the hull (its tail or its back would go into it), 1 clear of it
-- to the side, over or under it, or ahead of its nose
local function freedom(e: Escort, o: Vector3): number
	local gap = Config.Sub.EscortGap
	local wide, up, down = rolled(e.Wide, e.Top, e.Bottom)
	local near = wide + sideways(e.Half) + gap
	local x = (math.abs(o.X) - e.Side) / math.max(near - e.Side, 1)
	local y = ((if o.Y > 0 then o.Y - up else -o.Y - down) - gap) / e.Half.Y
	local z = (o.Z - e.Nose - gap - e.Half.Z * 0.6) / math.max(e.Half.Z * 0.4, 14)
	return math.clamp(math.max(x, y, z), 0, 1)
end

-- Its place in the sub's frame at `t`: to the right, up, ahead
local function offset(trip: Trip, e: Escort, t: number): Vector3
	local c = Config.Sub
	local pickupAt, rideAt, _, dropAt = SubTrip.times(trip)
	local d = SubTrip.distance(trip, t)
	local subY = SubTrip.at(trip, d).Y
	-- beside the sub: at the pick-up with the saddle abreast of the seat and a little over it (the hop's way is across
	-- and down), at the kick level with the sub, a long one further ahead (its tail is not in the camera's way)
	local seat = SubTrip.Seat.Position
	local take = Vector3.new(e.Side, seat.Y + c.EscortOver - e.Saddle.Y, e.Saddle.Z - seat.Z)
	local kick = Vector3.new(e.Side, -2, math.clamp(e.Half.Z - 12, 0, c.EscortKickLead))
	local backFrom = dropAt - c.EscortSettle - returning(e.Half)
	local home = take:Lerp(kick, Ease.smoothstep(rideAt, backFrom, t))
	-- the sweeps
	local a, b = SubTrip.escortTimes(trip, e.Half)
	local turned = e.Turns * 2 * steady(a, b, t) -- (in half turns)
	local x = (e.High + e.Low) / 2 + (e.High - e.Low) / 2 * math.cos(turned * math.pi)
	local y = -2
	if e.Loop then
		-- under the hull from one side to the other, and back over it where there is the water over it
		local wide, up, down = rolled(e.Wide, e.Top, e.Bottom)
		local near = wide + sideways(e.Half) + c.EscortGap
		local across = 1 - Ease.smoothstep(near, math.max(e.High, near + 1), math.abs(x))
		local k = math.min(math.floor(turned), e.Turns * 2 - 1)
		local over = false
		if k % 2 == 1 then
			-- (decided by the water over the sub halfway through that sweep's own time, the same on every machine; the
			-- way down only gets deeper)
			local mid = a + (b - a) * 0.35
			local roof = Config.Oxygen.SurfaceY - 2 - SubTrip.at(trip, (SubTrip.distance(trip, mid))).Y
			over = roof >= up + e.Half.Y * 2 + c.EscortGap
		end
		y = if over
			then Ease.lerp(-2, up + e.Half.Y + c.EscortGap, across)
			else Ease.lerp(-2, -(down + e.Half.Y + c.EscortGap), across)
	else
		-- ahead of the nose: a lazy rise and fall with the sweeps
		y = -2 + math.sin(turned * math.pi) * math.min(c.EscortRise, e.Half.Y)
	end
	-- off its place and back: ahead first, then out and round; and back beside the sub before it falls back to its seat
	-- (so one that sweeps ahead of the nose never cuts across the hull)
	local from, to = rideAt - 0.1, rideAt - 0.1 + c.EscortPeel * slower(e.Half)
	local home1 = dropAt - c.EscortSettle
	local out = Ease.smoothstep(Ease.lerp(from, to, 0.45), to, t)
		* (1 - Ease.smoothstep(backFrom, Ease.lerp(backFrom, home1, 0.55), t))
	local on = Ease.smoothstep(from, Ease.lerp(from, to, 0.6), t)
		* (1 - Ease.smoothstep(Ease.lerp(backFrom, home1, 0.45), home1, t))
	local at = Vector3.new(Ease.lerp(home.X, x, out), Ease.lerp(home.Y, y, out), Ease.lerp(home.Z, e.Lead, on))
	-- (the dip as the rider pushes off its back)
	local hop = math.clamp((t - pickupAt - c.EscortHopFrom * trip.Pickup) / 0.45, 0, 1)
	at -= UP * (c.EscortDip * math.sin(hop * math.pi))
	return Vector3.new(at.X, fit(at.Y, subY, e.Half.Y), at.Z)
end

-- The fish's root at `t` seconds into the trip (nil: the trip has no escort), and its place in the sub's frame
function SubTrip.escort(trip: Trip, t: number): (CFrame?, Vector3?)
	local e = trip.Escort
	if not e then
		return nil, nil
	end
	local c = Config.Sub
	local pickupAt = SubTrip.times(trip)
	local d, v = SubTrip.distance(trip, t)
	local o = offset(trip, e, t)
	local look = math.max(10 + v * 0.04, e.Half.Z)
	-- along the path, so one that swims ahead goes round the bends and not across them
	local base = if d + o.Z >= 0
		then SubTrip.at(trip, d + o.Z)
		else SubTrip.at(trip, 0) + levelOf(SubTrip.way(trip, 30, 30)) * (d + o.Z)
	local way = SubTrip.way(trip, math.max(d + o.Z, 30), look)
	local level = levelOf(way)
	local right = level:Cross(UP)
	local at = Vector3.new(base.X, base.Y + o.Y, base.Z) + right * o.X
	-- it turns, tips and banks by how it moves in the sub's frame, against a pace of its own (at the sub's thousands of
	-- studs a second nothing would show)
	local h = 0.15
	local p0, p1 = offset(trip, e, t - h), offset(trip, e, t + h)
	local vel = (p1 - p0) / (2 * h)
	local acc = (p1 - o * 2 + p0) / (h * h)
	local pace = math.max(c.EscortPace, 1)
	local most = yawMost(e.Half)
	local yaw = most * math.tanh(vel.X / pace / math.max(most, 0.01))
	local tip = math.rad(c.EscortTip) * math.tanh(vel.Y / pace / math.rad(math.max(c.EscortTip, 1)))
	local bank = -math.rad(c.EscortBank) * math.tanh(acc.X / math.max(c.EscortBankAt, 1))
	local free = freedom(e, o)
	yaw, bank = yaw * free, bank * free
	local cf = CFrame.lookAt(at, at + way) * CFrame.Angles(0, -yaw, 0) * CFrame.Angles(tip, 0, 0)
	cf *= CFrame.Angles(0, 0, bank)
	if t < pickupAt then
		-- carrying the rider out from where they went in, level by the time it is beside the sub
		local u = math.clamp(t / math.max(pickupAt, 0.01), 0, 1)
		local k = 1 - (1 - u) ^ 2
		local start = CFrame.lookAt(e.From, e.From + e.Way)
		cf = CFrame.new(start.Position:Lerp(cf.Position, k)) * start.Rotation:Lerp(cf.Rotation, k)
	end
	return cf, o
end

local function fill(trip: Trip)
	local along = { 0 }
	for i = 2, #trip.Points do
		along[i] = along[i - 1] + (trip.Points[i] - trip.Points[i - 1]).Magnitude
	end
	trip.Along = along
	trip.Length = along[#along] or 0
end

-- A trip from its parts (the server): the run is planned to end at `dropAt` studs along the path
function SubTrip.new(start: number, land: number, fish: boolean, points: { Vector3 }, dropAt: number): Trip
	local c = Config.Sub
	local trip: Trip = {
		Start = start,
		Land = land,
		Fish = fish,
		Approach = c.Approach,
		Pickup = c.Pickup,
		SpeedUp = 0,
		Cruise = 0,
		SlowDown = 0,
		Top = c.Speed,
		Drop = c.DropSpeed,
		Arrive = c.Arrive,
		DropTime = if fish then c.Kick else c.Drop,
		Points = points,
		Along = {},
		Length = 0,
		Escort = nil,
	}
	fill(trip)
	trip.SpeedUp, trip.Cruise, trip.SlowDown, trip.Top = SubTrip.plan(math.max(dropAt - c.DropSpeed * c.Arrive, 50))
	return trip
end

function SubTrip.encode(trip: Trip): string
	local flat = table.create(#trip.Points * 3)
	for _, p in trip.Points do
		table.insert(flat, math.floor(p.X * 10 + 0.5) / 10)
		table.insert(flat, math.floor(p.Y * 10 + 0.5) / 10)
		table.insert(flat, math.floor(p.Z * 10 + 0.5) / 10)
	end
	local e = trip.Escort
	return HttpService:JSONEncode({
		E = if e
			then {
				e.Half.X,
				e.Half.Y,
				e.Half.Z,
				e.Saddle.X,
				e.Saddle.Y,
				e.Saddle.Z,
				e.From.X,
				e.From.Y,
				e.From.Z,
				e.Way.X,
				e.Way.Z,
				e.Wide,
				e.Top,
				e.Bottom,
				e.Nose,
				if e.Loop then 1 else 0,
				e.Side,
				e.Low,
				e.High,
				e.Lead,
				e.Turns,
			}
			else nil,
		S = trip.Start,
		L = trip.Land,
		F = trip.Fish,
		T = {
			trip.Approach,
			trip.Pickup,
			trip.SpeedUp,
			trip.Cruise,
			trip.SlowDown,
			trip.Top,
			trip.Drop,
			trip.Arrive,
			trip.DropTime,
		},
		P = flat,
	})
end

function SubTrip.decode(json: string): Trip?
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(data) ~= "table" or type(data.T) ~= "table" or type(data.P) ~= "table" then
		return nil
	end
	local t = data.T
	local points = {}
	for i = 1, #data.P - 2, 3 do
		table.insert(points, Vector3.new(data.P[i], data.P[i + 1], data.P[i + 2]))
	end
	if #points < 2 then
		return nil
	end
	local trip: Trip = {
		Start = data.S,
		Land = data.L,
		Fish = data.F == true,
		Approach = t[1],
		Pickup = t[2],
		SpeedUp = t[3],
		Cruise = t[4],
		SlowDown = t[5],
		Top = t[6],
		Drop = t[7],
		Arrive = t[8],
		DropTime = t[9],
		Points = points,
		Along = {},
		Length = 0,
		Escort = nil,
	}
	local e = data.E
	if type(e) == "table" and #e >= 21 then
		trip.Escort = {
			Half = Vector3.new(e[1], e[2], e[3]),
			Saddle = Vector3.new(e[4], e[5], e[6]),
			From = Vector3.new(e[7], e[8], e[9]),
			Way = Vector3.new(e[10], 0, e[11]),
			Wide = e[12],
			Top = e[13],
			Bottom = e[14],
			Nose = e[15],
			Loop = e[16] == 1,
			Side = e[17],
			Low = e[18],
			High = e[19],
			Lead = e[20],
			Turns = e[21],
		}
	end
	fill(trip)
	return trip
end

return SubTrip
