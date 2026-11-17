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
local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)

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
}

local SubTrip = {}

-- The run's speeds for a ride of `distance` studs: up to the top speed, cruising, down to the drop speed. A short trip
-- has a lower top speed and no cruise, and is never shorter than Sub.MinRide (it never blinks past).
function SubTrip.plan(distance: number): (number, number, number, number)
	local c = Config.Sub
	local up, down, drop = c.SpeedUp, c.SlowDown, c.DropSpeed
	local top = c.Speed
	local need = top * up / 2 + (top + drop) * down / 2
	if distance >= need and up + down + (distance - need) / top >= c.MinRide then
		local cruise = (distance - need) / top
		if up + cruise + down > c.MaxRide then
			-- a far land: faster, so the run is never longer than MaxRide
			cruise = math.max(c.MaxRide - up - down, 0)
			top = (distance - drop * down / 2) / (up / 2 + cruise + down / 2)
		end
		return up, cruise, down, top
	end
	-- no cruise: the speed-up and the slow-down share the ride's time, at least MinRide
	local k = math.max(1, c.MinRide / math.max(up + down, 0.1))
	up, down = up * k, down * k
	top = math.min(c.Speed, (distance - drop * down / 2) / ((up + down) / 2))
	if top <= drop then
		-- (a trip too short for even that: straight at the drop speed)
		return 0, math.max(distance, 0) / drop, 0, drop
	end
	return up, 0, down, top
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
	return HttpService:JSONEncode({
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
	}
	fill(trip)
	return trip
end

return SubTrip
