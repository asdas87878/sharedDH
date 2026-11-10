--!strict
-- The dive lane as one path: its centreline on the floor from the dive board down, with the lane's width, measured in
-- studs along it (s). Built from the map's exact centreline when the dive folder has one (blockout v3's "Path" attribute,
-- JSON { s, x, y, z, w, c } in world space, c the room above the floor under a roof, 0 open; "LanePath" is read too), else from the zones' straight chords end to end (v2).
-- Each zone gets the stretch of s it covers, so the fish can be spread over the whole lane, zone by zone.
local HttpService = game:GetService("HttpService")

local Zones = require(script.Parent.Zones)

export type Lane = {
	Points: { Vector3 }, -- the centreline on the floor
	Widths: { number },
	Clearance: { number }, -- room above the floor under an arch or roof at each point (0 = open water)
	S: { number }, -- distance along the path at each point
	Length: number,
	ZoneStart: { number }, -- s where each zone begins (by zone index)
	ZoneEnd: { number },
}

local Lane = {}

local function fromJson(json: string): ({ Vector3 }?, { number }?, { number }?)
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(data) ~= "table" then
		return nil, nil, nil
	end
	local points, widths, clearance = {}, {}, {}
	for _, row in data do
		if type(row) == "table" and type(row[2]) == "number" and type(row[5]) == "number" then
			table.insert(points, Vector3.new(row[2], row[3], row[4]))
			table.insert(widths, row[5])
			table.insert(clearance, if type(row[6]) == "number" then row[6] else 0)
		end
	end
	if #points < 2 then
		return nil, nil, nil
	end
	return points, widths, clearance
end

-- The zones' chords end to end, sampled every 250 studs
local function fromZones(zones: { Zones.Zone }): ({ Vector3 }, { number })
	local points, widths = {}, {}
	for _, zone in zones do
		local steps = math.max(1, math.ceil(zone.Length / 250))
		for i = 0, steps do
			if i > 0 or #points == 0 then
				table.insert(points, Zones.point(zone, 0, 0, -zone.Length / 2 + zone.Length * i / steps))
				table.insert(widths, zone.Width)
			end
		end
	end
	return points, widths
end

-- The last point at or before s (binary search)
local function indexAt(lane: Lane, s: number): number
	local S = lane.S
	local lo, hi = 1, #S - 1
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if S[mid] <= s then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return lo
end

-- The nearest point on the path: its s and how far off the path it is. With `near` (an s the position is known to be
-- close to, such as last frame's), only the stretch of path round it is searched: for callers that ask every frame.
function Lane.project(lane: Lane, position: Vector3, near: number?): (number, number)
	local bestS, bestD = 0, math.huge
	local points = lane.Points
	local first, last = 1, #points - 1
	if near then
		local i = indexAt(lane, math.clamp(near, 0, lane.Length))
		first, last = math.max(first, i - 6), math.min(last, i + 6)
	end
	for i = first, last do
		local a, b = points[i], points[i + 1]
		local ab = b - a
		local len2 = ab:Dot(ab)
		local u = if len2 > 0 then math.clamp((position - a):Dot(ab) / len2, 0, 1) else 0
		local d = (a + ab * u - position).Magnitude
		if d < bestD then
			bestD = d
			bestS = lane.S[i] + (lane.S[i + 1] - lane.S[i]) * u
		end
	end
	return bestS, bestD
end

-- The floor's centre at s, the way down the lane there (flattened), and the lane's width
function Lane.at(lane: Lane, s: number): (Vector3, Vector3, number)
	local points, S = lane.Points, lane.S
	s = math.clamp(s, 0, lane.Length)
	local i = indexAt(lane, s)
	local a, b = points[i], points[i + 1]
	local span = S[i + 1] - S[i]
	local u = if span > 0 then (s - S[i]) / span else 0
	local flat = (b - a) * Vector3.new(1, 0, 1)
	local along = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, 1)
	return a:Lerp(b, u), along, lane.Widths[i] + (lane.Widths[i + 1] - lane.Widths[i]) * u
end

-- A point x across the lane (from the centre, to the right going down) and h above its floor, at s
function Lane.point(lane: Lane, s: number, x: number, h: number): Vector3
	local centre, along = Lane.at(lane, s)
	local right = along:Cross(Vector3.yAxis)
	return centre + right * x + Vector3.new(0, h, 0)
end

-- The room above the floor at s under a roof (the lower of the two samples either side), or nil in open water
function Lane.clearanceAt(lane: Lane, s: number): number?
	local S, C = lane.S, lane.Clearance
	local best: number? = nil
	for i = 1, #S do
		if math.abs(S[i] - s) <= 100 and C[i] and C[i] > 0 then
			best = if best then math.min(best, C[i]) else C[i]
		end
	end
	return best
end

-- The zone index at s (the last one past the end)
function Lane.zoneAt(lane: Lane, s: number): number
	for i = #lane.ZoneStart, 1, -1 do
		if s >= lane.ZoneStart[i] then
			return i
		end
	end
	return 1
end

function Lane.build(zones: { Zones.Zone }, pathJson: string?): Lane
	local points, widths, clearance
	if pathJson then
		local p, w, c = fromJson(pathJson)
		if p and w and c then
			points, widths, clearance = p, w, c
		else
			warn("[Lane] the dive's Path attribute doesn't read, using the zones' chords")
		end
	end
	if not points or not widths then
		points, widths = fromZones(zones)
		clearance = {}
	end
	local S = { 0 }
	for i = 2, #points do
		S[i] = S[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	local lane: Lane = {
		Points = points,
		Widths = widths,
		Clearance = clearance :: { number },
		S = S,
		Length = S[#S],
		ZoneStart = {},
		ZoneEnd = {},
	}
	-- each zone from where its chord starts to where the next one's does
	for i, zone in zones do
		local start = Zones.point(zone, 0, 0, -zone.Length / 2)
		lane.ZoneStart[i] = if i == 1 then 0 else (Lane.project(lane, start))
	end
	for i in zones do
		local nextStart = lane.ZoneStart[i + 1]
		lane.ZoneEnd[i] = if nextStart then nextStart else lane.Length
	end
	return lane
end

return Lane
