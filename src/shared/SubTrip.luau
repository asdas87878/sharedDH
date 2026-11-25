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
--   The air hop (Hugo, 2026-11-25; Config.Sub.AirHop): a trip with Air begins with the fish's leap off the lip, the rider
--   jumps off it in the air onto the seat of the sub as it flies in, and it splashes into the run. Its phases are Leap (to
--   the jump) and Hop in the place of Approach and Pickup; everything before the run is Shared/SubAir. The fish goes in
--   by itself and swims up to its place beside the sub (escort). Without Air everything here is as it was.
local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)
local Ease = require(script.Parent.Ease)
local SubAir = require(script.Parent.SubAir)

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
	Right: boolean, -- it swims beside the hull on its right; else ahead of the nose there
	Left: boolean, -- and so on its left. (Both: over the hull, under it or round the nose from the one to the other)
	Side: number, -- its place beside the sub: this far to the right (the pick-up and the kick)
	Low: number, -- the weave's furthest left (negative)
	High: number, -- and right
	Lead: number, -- how far ahead of the sub's middle it clears the nose
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
	Air: SubAir.Air?,
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
-- (`v0`: the speed the run begins at; the air hop's, else from a stand)
function SubTrip.plan(distance: number, v0: number?): (number, number, number, number)
	local c = Config.Sub
	local drop = c.DropSpeed
	local a = math.clamp(c.UpShare, 0.05, 0.45)
	local b = math.clamp(c.DownShare, 0.05, 0.45)
	local d = math.max(distance, 0)
	-- (distance = top * T * (1 - (a + b) / 2) + drop * b * T / 2)
	local cover = 1 - (a + b) / 2
	local top = c.Speed + c.SpeedPer * d
	local first = (v0 or 0) * a / 2
	local time = d / math.max(top * cover + drop * b / 2 + first, 1)
	if time < c.MinRide or time > c.MaxRide then
		time = math.clamp(time, c.MinRide, math.max(c.MaxRide, c.MinRide))
		top = (d / time - drop * b / 2 - first) / cover
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
		then if trip.Air then "Leap" else "Approach"
		elseif t < ride then if trip.Air then "Hop" else "Pickup"
		elseif t < arrive then "Ride"
		elseif t < drop then "Arrive"
		elseif t < finish then "Drop"
		else "Done"
end

-- How far along the path the sub is at `t` seconds from the start (0 until the run), and its speed
function SubTrip.distance(trip: Trip, t: number): (number, number)
	local _, ride = SubTrip.times(trip)
	local u = t - ride
	-- (after the air hop it begins at the path's second point, already under way)
	local from, v0 = 0, 0
	if trip.Air then
		from, v0 = trip.Along[2], Config.Sub.AirRun
	end
	if u <= 0 then
		return from, v0
	end
	local top, drop = trip.Top, trip.Drop
	local a = trip.SpeedUp
	if u < a then
		local v = v0 + (top - v0) * u / a
		return from + (v0 + v) * u / 2, v
	end
	local d = from + (v0 + top) * a / 2
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

-- Half its width as it banks
local function banked(half: Vector3): number
	local bank = math.rad(Config.Sub.EscortBank)
	return half.X * math.cos(bank) + half.Y * math.sin(bank)
end

-- How far out it clears the hull (half as wide as `wide`, banked) from beside it, swimming straight
local function abreast(wide: number, half: Vector3): number
	return wide + math.max(half.X, banked(half)) + Config.Sub.EscortGap
end

-- How far out to the side its place beside the sub is
function SubTrip.escortSide(half: Vector3, tier: number): number
	local hull = SubTrip.Hulls[math.clamp(tier, 1, #SubTrip.Hulls)]
	-- (a long one a little further: its ends swing out in the bends)
	return math.max(Config.Sub.FishSide, hull[1] + half.X + Config.Sub.EscortGap + half.Z * 0.06)
end

-- How far its ends swing out to the side as it turns
function SubTrip.escortSwing(half: Vector3): number
	return half.Z * math.sin(yawMost(half))
end

-- How far out from where the rider went in the sub takes them: far enough that a long fish's tail is out of the gate
function SubTrip.escortOut(half: Vector3, saddle: Vector3): number
	local c = Config.Sub
	local behind = half.Z - saddle.Z -- (its tail, behind its saddle)
	return math.clamp(c.EscortOut + behind * 0.6, c.EscortOut, c.EscortOutMost)
end

-- When it may leave its place beside the sub for the sweeps: as the run begins; after the air hop, once it is nearly back
local function peelAt(trip: Trip): number
	if trip.Air then
		return trip.Air.Back
	end
	local _, rideAt = SubTrip.times(trip)
	return rideAt
end

-- How many times it sweeps left and right again
local function escortTurns(trip: Trip, half: Vector3): number
	local a, b = SubTrip.escortTimes(trip, half)
	return math.max(1, math.floor((b - a) / (Config.Sub.EscortPeriod * math.clamp((half.Z / 10) ^ 0.3, 1, 1.7))))
end

-- A fish `half` big swims beside the hull of sub `tier` this far ahead of its middle (its tail short of the camera), and to
-- clear the nose this far (with the room its tail and fins need as it turns and tips)
local function alongside(half: Vector3): number
	return math.max(Config.Sub.EscortLead + half.Z * 0.5, half.Z - 24)
end
local function leading(half: Vector3, tier: number): number
	local c = Config.Sub
	local swing = half.X * math.sin(yawMost(half)) + half.Y * math.sin(math.rad(c.EscortTip))
	return SubTrip.Hulls[math.clamp(tier, 1, #SubTrip.Hulls)][4] + half.Z + swing + c.EscortGap + c.EscortLead
end

-- The open water either side of the sub's line for a fish held to it (the server): the least of it over the weave, all along
-- the fish. `room(at, way)`: the water left and right of a place, `way` the sub's way there,
-- `i` which place along the fish
function SubTrip.escortRooms(
	trip: Trip,
	tier: number,
	half: Vector3,
	room: (at: Vector3, way: Vector3, i: number) -> (number, number)
): (number, number)
	local c = Config.Sub
	local _, rideAt, _, dropAt = SubTrip.times(trip)
	local a, b = SubTrip.escortTimes(trip, half)
	local quarter = (b - a) / (escortTurns(trip, half) * 4)
	local from = if trip.Air then rideAt else rideAt + c.EscortPeel * slower(half) * 0.45
	local to = dropAt - c.EscortSettle - returning(half) * 0.45
	local left, right = math.huge, math.huge
	local first = alongside(half) - half.Z
	local last = leading(half, tier) + half.Z
	local steps = math.ceil((last - first) / 40)
	local t = from
	while t < to do
		local d, v = SubTrip.distance(trip, t)
		local at = SubTrip.at(trip, d)
		local way = levelOf(SubTrip.way(trip, d, 10 + v * 0.04))
		for i = 0, steps do
			local l, r = room(at + way * (first + (last - first) * i / steps), way, i)
			right = math.min(right, r)
			-- (on the left only where it goes left)
			if t > a + quarter and t < b - quarter then
				left = math.min(left, l)
			end
		end
		t += math.clamp(50 / math.max(v, 1), 0.005, 0.1)
	end
	return left, right
end

-- Plans the escort of a trip (the server). `left` and `right`: the open water either side of the sub's line along the
-- run, the least of it, studs (SubTrip.escortRooms)
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
	local wide = rolled(hull[1], hull[2], hull[3])
	local body = sideways(half)
	local side = SubTrip.escortSide(half, tier)
	-- beside the hull on either side in turn, as close as it banks; on a side with no room for that it swims ahead of the
	-- nose instead
	-- (as far out as the water lets it go, up to EscortWide clear; the nearest is unbanked, hard by the hull. A little for
	-- the bends, where the sub is turned across the lane)
	local bends = half.Z * 0.1 + c.EscortGap + 4
	local tight = math.max(wide + half.X + half.Z * 0.06 + c.EscortGap, side)
	local full = math.max(abreast(wide, half) + c.EscortWide, side)
	local function reach(room: number): (number, boolean)
		local out = math.min(full, room - math.max(half.X, banked(half)) - bends)
		if out < tight and tight + half.X + bends <= room then
			out = tight
		end
		return out, out >= tight
	end
	local outRight, onRight = reach(right)
	local outLeft, onLeft = reach(left)
	local lead = leading(half, tier)
	local wander = wide + body + c.EscortGap + c.EscortWide
	local high = if onRight then outRight else math.max(math.min(wander, right - body - c.EscortGap), 0)
	local low = if onLeft then -outLeft else -math.max(math.min(wander, left - body - c.EscortGap), 0)
	local turns = escortTurns(trip, half)
	if trip.Air then
		local a, b = SubTrip.escortTimes(trip, half)
		if b - a < c.AirWeave then
			-- (no time left for a sweep: beside the sub all along)
			turns, onLeft, low = 0, false, high
		end
	end
	trip.Escort = {
		Half = half,
		Saddle = saddle,
		From = from,
		Way = levelOf(way),
		Wide = hull[1],
		Top = hull[2],
		Bottom = hull[3],
		Nose = hull[4],
		Right = onRight,
		Left = onLeft,
		Side = side,
		Low = low,
		High = high,
		Lead = lead,
		Turns = turns,
	}
end

-- When the weave's sweeps begin and end, seconds into the trip (it peels off a little before and is back a little after)
function SubTrip.escortTimes(trip: Trip, half: Vector3): (number, number)
	local c = Config.Sub
	local _, _, _, dropAt = SubTrip.times(trip)
	return peelAt(trip) + c.EscortPeel * slower(half) * 0.6, dropAt - c.EscortSettle - returning(half) * 0.6
end

-- The height (over the sub's middle, `subY` in the world) that keeps a fish `half` high off the floor and under the
-- surface; one too tall for the water there has as much of it out either way
-- (`under`: how far the floor is below the sub there)
local function fit(y: number, subY: number, half: number, under: number): number
	local low = half + 2 - under
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

-- How freely it can turn, and how freely it can bank, where it is: 0 beside the hull (its tail or its back would go into
-- it), 1 clear of it to the side, over or under it, or ahead of its nose
local function freedom(e: Escort, o: Vector3): (number, number)
	local gap = Config.Sub.EscortGap
	local wide, up, down = rolled(e.Wide, e.Top, e.Bottom)
	local near = wide + sideways(e.Half) + gap
	local hard = math.max(e.Side, wide + e.Half.X + gap)
	local x = (math.abs(o.X) - hard) / math.max(near - hard, 10)
	-- (over or under it: turning takes no more room there, banking does, a wide one's edge comes down)
	local y = (if o.Y > 0 then o.Y - up else -o.Y - down) - gap
	local edge = e.Half.X * math.sin(math.rad(Config.Sub.EscortBank))
	-- (the whole of it past the nose: its tail would swing across it)
	local z = (o.Z - e.Half.Z - e.Nose - gap / 2) / 18
	local turn = math.max(x, (y - e.Half.Y * 0.5) / math.max(e.Half.Y * 0.5, 6), z)
	local bank = math.max(x, (y - e.Half.Y) / math.max(edge, 6), z)
	return math.clamp(turn, 0, 1), math.clamp(bank, 0, 1)
end

-- The way the sub's line goes at `t`, which the fish is held to: the sub's own, coming onto it as the run begins
local function heading(trip: Trip, t: number): Vector3
	local _, rideAt = SubTrip.times(trip)
	local way0 = levelOf(SubTrip.way(trip, 30, 30))
	if t <= rideAt then
		return way0
	end
	local d, v = SubTrip.distance(trip, t)
	return way0:Lerp(SubTrip.way(trip, d, 10 + v * 0.04), Ease.smoothstep(rideAt, rideAt + 0.3, t)).Unit
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
	local z = e.Lead
	if e.Right or e.Left then
		-- from its place on one side to its place on the other, once a half turn: up (or down, or ahead), across, and back
		local k = math.max(math.min(math.floor(turned), e.Turns * 2 - 1), 0)
		local p = turned - k
		local toLeft = k % 2 == 0
		local across = Ease.smoothstep(0.04, 0.38, p) * (1 - Ease.smoothstep(0.62, 0.96, p))
		local beside = alongside(e.Half)
		local _, up, down = rolled(e.Wide, e.Top, e.Bottom)
		-- over it where there is the water (by the water over the sub as that half turn begins: the same on every machine,
		-- and the way down only gets deeper); a small one under it on its way left; else round the nose
		local roof = Config.Oxygen.SurfaceY
			- 2
			- SubTrip.at(trip, (SubTrip.distance(trip, a + (b - a) * k / math.max(e.Turns * 2, 1)))).Y
		local short = e.Right and e.Left and e.Half.Z <= c.EscortLoopLong / 2
		local tall = e.Half.Y + c.EscortGap
		local over = short and roof >= up + tall + e.Half.Y
		local under = short and down + tall + e.Half.Y + 2 <= c.Lift
		local far = if over or under then 0.24 else 0.3
		local crossed = Ease.smoothstep(far, 1 - far, p)
		x = if toLeft then Ease.lerp(e.High, e.Low, crossed) else Ease.lerp(e.Low, e.High, crossed)
		z = beside
		if under and (toLeft or not over) then
			y = Ease.lerp(y, -(down + tall), across)
		elseif over then
			y = Ease.lerp(y, up + tall, across)
		else
			-- (ahead all along on a side with no room beside the hull)
			local here = if p < 0.5 then toLeft else not toLeft -- on the right
			local ahead = if if here then e.Right else e.Left then across else 1
			z = Ease.lerp(z, e.Lead, ahead)
			y = Ease.lerp(y, c.EscortAhead, ahead)
		end
	else
		-- ahead of the nose all along, high enough to be seen over the hull: a lazy rise and fall with the sweeps
		y = c.EscortAhead + math.sin(turned * math.pi) * math.min(c.EscortRise, e.Half.Y)
	end
	-- off its place and back: ahead first, then out and round; and back beside the sub before it falls back to its seat
	-- (so one that sweeps ahead of the nose never cuts across the hull)
	local peel = peelAt(trip)
	local from, to = peel - 0.1, peel - 0.1 + c.EscortPeel * slower(e.Half)
	local home1 = dropAt - c.EscortSettle
	local first, last = if e.Right then 0.45 else 0.58, if e.Right then 0.55 else 0.5
	local out = Ease.smoothstep(Ease.lerp(from, to, first), to, t)
		* (1 - Ease.smoothstep(backFrom, Ease.lerp(backFrom, home1, last), t))
	local on = Ease.smoothstep(from, Ease.lerp(from, to, 0.6), t)
		* (1 - Ease.smoothstep(Ease.lerp(backFrom, home1, last - 0.1 * (if e.Right then 1 else 0)), home1, t))
	local at = Vector3.new(Ease.lerp(home.X, x, out), Ease.lerp(home.Y, y, out), Ease.lerp(home.Z, z, on))
	-- (the dip as the rider pushes off its back)
	if not trip.Air then
		local hop = math.clamp((t - pickupAt - c.EscortHopFrom * trip.Pickup) / 0.45, 0, 1)
		at -= UP * (c.EscortDip * math.sin(hop * math.pi))
	end
	-- (in the water where it is: the sub's line rises and falls under one ahead)
	-- (the line is Lift over the floor, but the pick-up is lower: there the floor is the next stretch's, carried back)
	local bed = subY - c.Lift
	local i = if trip.Air then 3 else 2 -- (the first point on the line that is Lift over the floor)
	if d < trip.Along[i] then
		local second, third = trip.Points[i], trip.Points[i + 1]
		local fall = math.max(second.Y - third.Y, 0) / math.max(trip.Along[i + 1] - trip.Along[i], 1)
		bed = second.Y - c.Lift + fall * (trip.Along[i] - d)
	end
	return Vector3.new(at.X, fit(at.Y, subY + heading(trip, t).Y * at.Z, e.Half.Y, subY - bed), at.Z)
end

-- How far the sub may bank with the fish where it is, radians: hardly at all while it is in its place close beside the hull
-- (banking, the hull's side would come up into it), as far as it likes once the fish is out past that, over or under it, or
-- wholly ahead of the nose
local function bankRoom(e: Escort, o: Vector3): number
	local gap = Config.Sub.EscortGap
	local _, up, down = rolled(e.Wide, e.Top, e.Bottom)
	local y = (if o.Y > 0 then o.Y - up else -o.Y - down) - e.Half.Y
	local z = o.Z - e.Half.Z - e.Nose
	local free = ROLL * math.clamp(math.max(y / gap, (z - gap / 2) / 8), 0, 1)
	-- (its side banked by r reaches wide * cos r + tall * sin r)
	local tall = math.max(e.Top, e.Bottom)
	local room, reach = math.abs(o.X) - e.Half.X - gap / 2, math.sqrt(e.Wide * e.Wide + tall * tall)
	local r = if room >= reach then ROLL else math.atan2(tall, e.Wide) - math.acos(math.max(room, 0) / reach)
	return math.clamp(math.max(r, free), 0, ROLL)
end

-- How much of the way out to its place beside the sub (`to`) it has made, `u` of the way through the approach: off at about
-- the pace it dived at, and slowing to a stop there
local function outward(e: Escort, to: Vector3, u: number, approach: number): number
	local pull = math.min(Config.Sub.EscortStart * approach / math.max((to - e.From).Magnitude, 1), 2.5)
	return u * u * (3 - 2 * u) + pull * u * (1 - u) ^ 2
end

-- How far behind the pick-up the sub is at `t` as it comes in for a rider on their fish: behind the fish's tail until the
-- fish has drawn aside off the sub's line (EscortAside of the way there), then alongside
local function behind(trip: Trip, e: Escort, t: number): number
	local pickupAt = SubTrip.times(trip)
	local c = Config.Sub
	local way0 = levelOf(SubTrip.way(trip, 30, 30))
	local u = math.clamp(t / math.max(pickupAt, 0.01), 0, 1)
	local start = e.From - trip.Points[1]
	local nose = e.Nose + c.EscortGap * 2 + e.Half.Z -- (the sub's middle this far behind the fish's is behind its tail)
	local from = math.max(c.EscortFrom, nose - start:Dot(way0))
	local back = from * (1 - Ease.smoothstep(c.EscortWait, 1, u))
	if start:Dot(way0:Cross(UP)) >= e.Side - c.EscortGap / 2 then
		return back -- (off the sub's line as it is)
	end
	local o = offset(trip, e, t)
	local to = trip.Points[1] + way0 * o.Z + way0:Cross(UP) * o.X + UP * o.Y
	local along = Ease.lerp(start:Dot(way0), o.Z, outward(e, to, u, pickupAt))
	local held = math.max(nose - along, 0) * (1 - Ease.smoothstep(c.EscortAside, 1, u))
	-- (the greater of the two, the corner rounded off)
	return (back + held + math.sqrt((back - held) ^ 2 + (16 * (1 - u)) ^ 2)) / 2
end

-- The sub's place at `t` seconds into the trip, and how fast it goes (studs a second)
function SubTrip.sub(trip: Trip, t: number): (CFrame, number)
	local pickupAt, rideAt, _, dropAt, endAt = SubTrip.times(trip)
	if trip.Air and t < rideAt then
		return SubAir.sub(trip.Air, t)
	end
	local pick = trip.Points[1]
	local way0 = levelOf(SubTrip.way(trip, 30, 30))
	local right = way0:Cross(UP)
	local rest = pick - UP * 8
	if t < pickupAt then
		-- (approachPose) up from behind, below and to the side, slowing as it comes under us
		local u = math.clamp(t / math.max(pickupAt, 0.01), 0, 1)
		local e = 1 - (1 - u) ^ 2
		-- (kept over the floor at the gate: the water there is about 46 deep, and we take the sub 17 under)
		local escort = trip.Escort
		if escort then
			-- (dead straight up the line it takes us on, through the gate and beside the fish, level: nothing of it swings)
			local back = behind(trip, escort, t)
			local at = rest - way0 * back - UP * math.min(back * 0.1, 6)
			return CFrame.lookAt(at, at + way0), 40 * (1 - e) + 10
		end
		local p0 = pick - way0 * 170 - UP * 18 + right * 30
		local p1 = pick - way0 * 50 - UP * 16 + right * 6
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
	if trip.Air then
		-- (the air hop comes in unbanked)
		bank *= Ease.smoothstep(rideAt, rideAt + Config.Sub.AirBankIn, t)
	end
	local e = trip.Escort
	if e then
		local most = bankRoom(e, offset(trip, e, t))
		bank = math.clamp(bank, -most, most)
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

-- After the air hop: the fish from its own splash to its place beside the sub. `cf`: where the trip has it there, `o` that
-- in the sub's frame, `d` the sub along its path. It swims on out of its dive and up the sub's own line, to its side of it
-- first, then forward (so it comes up beside the hull, and beside the camera behind it)
local function joining(trip: Trip, e: Escort, air: SubAir.Air, t: number, cf: CFrame, o: Vector3, d: number): CFrame
	local c = Config.Sub
	local leap = air.Leap
	local entry = SubAir.entry(air)
	local since = t - entry
	local k = math.clamp(since / math.max(SubAir.joining(e.Half), 0.05), 0, 1)
	local start = trip.Points[2]
	local way0 = levelOf(SubTrip.way(trip, 30, 30))
	local side = way0:Cross(UP)
	local went = SubAir.fish(air, entry)
	local from = trip.Along[2]
	-- the water it is in, as `offset` has it, at the place it goes in
	local second, third = trip.Points[3], trip.Points[4]
	local into = from + (went.Position - start):Dot(way0)
	local fall = math.max(second.Y - third.Y, 0) / math.max(trip.Along[4] - trip.Along[3], 1)
	local bed = second.Y - c.Lift + fall * (trip.Along[3] - into)
	local depth = fit(0, Config.Oxygen.SurfaceY - c.EscortUnder, e.Half.Y, Config.Oxygen.SurfaceY - c.EscortUnder - bed)
		+ Config.Oxygen.SurfaceY
		- c.EscortUnder
	local on, y, tilt = SubAir.swim(air, t, depth)
	-- (a slanted leap turns straight down the lane, drifting on to the side a little)
	local turned = math.exp(-since / 0.4)
	local across, ahead = leap.Heading:Dot(side), leap.Heading:Dot(way0)
	local drift = across * leap.Far / leap.Time * 0.4 * (1 - turned)
	local own = into + on * math.max(ahead, 0.3)
	local kx, kz = Ease.smoothstep(0, 0.6, k), Ease.smoothstep(0.1, 1, k)
	local along = Ease.lerp(own, d + o.Z, kz)
	local over = Ease.lerp((went.Position - start):Dot(side) + drift, o.X, kx)
	local line, way
	if along <= from then
		line, way = start + way0 * (along - from), way0
	else
		line, way = SubTrip.at(trip, along), levelOf(SubTrip.way(trip, along, 30))
	end
	local at = line + way:Cross(UP) * over
	at = Vector3.new(at.X, Ease.lerp(y, cf.Y, Ease.smoothstep(0, 0.8, k)), at.Z)
	local yaw = math.atan2(-across, math.max(ahead, 0.01)) * turned
	local turn = CFrame.lookAt(Vector3.zero, way) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-math.rad(tilt), 0, 0)
	local last = Ease.smoothstep(0.6, 1, k)
	return CFrame.new(at:Lerp(cf.Position, last)) * turn:Lerp(cf.Rotation, Ease.smoothstep(0.2, 1, k))
end

-- The fish's root at `t` seconds into the trip (nil: the trip has no escort), and its place in the sub's frame
function SubTrip.escort(trip: Trip, t: number): (CFrame?, Vector3?)
	local e = trip.Escort
	if not e then
		return nil, nil
	end
	local c = Config.Sub
	local air = trip.Air
	if air and t <= SubAir.entry(air) then
		return SubAir.fish(air, t), nil
	end
	local pickupAt = SubTrip.times(trip)
	local d = SubTrip.distance(trip, t)
	local o = offset(trip, e, t)
	-- held to the sub's own line (its place and its heading): at the sub's speed a path round the bends swings from side to
	-- side under one that swims ahead. (Up is straight up: the sub's dive doesn't carry a high one forward.) The room it has
	-- is planned on this same line, SubTrip.escortRooms
	local subWay = heading(trip, t)
	local subAt = SubTrip.at(trip, d)
	local at = subAt + levelOf(subWay):Cross(UP) * o.X + UP * o.Y + subWay * o.Z
	local pose = CFrame.lookAt(at, at + subWay)
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
	local turnFree, bankFree = freedom(e, o)
	yaw, bank = yaw * turnFree, bank * bankFree
	local cf = pose * CFrame.Angles(0, -yaw, 0) * CFrame.Angles(tip, 0, 0)
	cf *= CFrame.Angles(0, 0, bank)
	if air then
		if t < SubAir.entry(air) + SubAir.joining(e.Half) then
			cf = joining(trip, e, air, t, cf, o, d)
		end
	elseif t < pickupAt then
		-- carrying the rider out from where they went in, level by the time it is beside the sub
		local u = math.clamp(t / math.max(pickupAt, 0.01), 0, 1)
		local start = CFrame.lookAt(e.From, e.From + e.Way)
		local k = outward(e, cf.Position, u, pickupAt)
		-- (aside first, to its side of the sub's line: the sub comes in beside it after)
		local aside = Ease.smoothstep(0, c.EscortAside, u)
		local across = levelOf(SubTrip.way(trip, 30, 30)):Cross(UP)
		local go = start.Position:Lerp(cf.Position, k)
		go += across * (cf.Position - start.Position):Dot(across) * (aside - k)
		cf = CFrame.new(go) * start.Rotation:Lerp(cf.Rotation, k)
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

-- The lead-in before the first point of a path the air hop runs into (the run is straight and under way at that point)
function SubTrip.leadIn(first: Vector3, second: Vector3): Vector3
	return first * 2 - second
end

-- A trip from its parts (the server): the run is planned to end at `dropAt` studs along the path
-- (after the air hop: `points` begin with the lead-in, SubTrip.leadIn, and `dropAt` counts it)
function SubTrip.new(
	start: number,
	land: number,
	fish: boolean,
	points: { Vector3 },
	dropAt: number,
	air: SubAir.Air?
): Trip
	local c = Config.Sub
	local trip: Trip = {
		Start = start,
		Land = land,
		Fish = fish,
		Approach = if air then air.HopAt else c.Approach,
		Pickup = if air then air.RideAt - air.HopAt else c.Pickup,
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
		Air = air,
	}
	fill(trip)
	local from = if air then trip.Along[2] else 0
	trip.SpeedUp, trip.Cruise, trip.SlowDown, trip.Top =
		SubTrip.plan(math.max(dropAt - from - c.DropSpeed * c.Arrive, 50), if air then c.AirRun else nil)
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
	local air = trip.Air
	return HttpService:JSONEncode({
		A = if air
			then {
				air.Leap.Take.X,
				air.Leap.Take.Y,
				air.Leap.Take.Z,
				air.Leap.Heading.X,
				air.Leap.Heading.Z,
				air.Leap.Far,
				air.Leap.Rise,
				air.Leap.Fall,
				air.Leap.Crouch,
				air.Leap.Time,
				air.HopAt,
				air.SeatAt,
				air.SplashAt,
				air.RideAt,
				air.Out.X,
				air.Out.Z,
				air.Meet.X,
				air.Meet.Y,
				air.Meet.Z,
				air.Slope,
				air.Fall,
				if air.Over then 1 else 0,
				air.Back,
				air.Eye.Back,
				air.Eye.Pass,
				air.Eye.Cap,
				air.Eye.Gate,
				air.Eye.Line,
				table.unpack(air.Leap.Tilts),
			}
			else nil,
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
				(if e.Right then 1 else 0) + (if e.Left then 2 else 0),
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
		Air = nil,
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
			Right = e[16] % 2 == 1,
			Left = e[16] >= 2,
			Side = e[17],
			Low = e[18],
			High = e[19],
			Lead = e[20],
			Turns = e[21],
		}
	end
	local a = data.A
	if type(a) == "table" and #a >= 30 and trip.Escort and #points >= 4 then
		local air: SubAir.Air = {
			Leap = {
				Take = Vector3.new(a[1], a[2], a[3]),
				Heading = Vector3.new(a[4], 0, a[5]),
				Far = a[6],
				Rise = a[7],
				Fall = a[8],
				Crouch = a[9],
				Time = a[10],
				Tilts = table.move(a, 29, #a, 1, {}),
			},
			Half = trip.Escort.Half,
			Saddle = trip.Escort.Saddle,
			HopAt = a[11],
			SeatAt = a[12],
			SplashAt = a[13],
			RideAt = a[14],
			Out = Vector3.new(a[15], 0, a[16]),
			Meet = Vector3.new(a[17], a[18], a[19]),
			Slope = a[20],
			Fall = a[21],
			Pick = points[2],
			Way = (points[3] - points[2]).Unit,
			Over = a[22] == 1,
			Back = a[23],
			Eye = { Back = a[24], Pass = a[25], Cap = a[26], Gate = a[27], Line = a[28] },
		}
		trip.Air = air
	end
	fill(trip)
	return trip
end

return SubTrip
