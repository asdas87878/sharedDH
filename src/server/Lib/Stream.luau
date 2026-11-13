--!strict
-- The stream: the water the herd swims down, worked out once from the lane and the built map (2026-11-13).
--
-- Why: the lane's own centre line is the middle between its two walls, and the walls swell out into rooms and pinch in
-- to necks, one side at a time. So that middle wanders from side to side: on grey-box 15 it turns 40 degrees for every
-- 100 studs, with kinks of up to 100 degrees where a wall steps. The herd used to follow it, each fish at its own
-- distance across, and wove down the lane with it. In the reference the herd runs dead straight through rooms that
-- swell and pinch round it (docs/reference/ride-a-dino.md, "The herd").
--
-- So the herd has its own line:
--   * the spine: the lane's middle evened out over Herd.Smooth studs each way, so only the lane's long bends are left,
--     and then let find its own way through the open water. The open water is read off the built map (rays dropped on
--     a grid: seabed is water, ground that has stepped up into a terrace or a wall is not). ROUNDS times over, every
--     point of the line that has an edge nearer than the herd's band is wide is pushed away from it, and the line is
--     evened out again. Where the map's own middle swings across a terrace (grey-box 15 has one, 400 studs sideways in
--     100), the spine goes round by the water instead;
--   * the band: the part of the open water either side of the spine that the herd uses: as wide as Spawn.BandMax,
--     narrower where the lane is (Spawn.LaneFill), and it starts to narrow well before a neck;
--   * the floor: the seabed under five lines of the band (the floor is not level across the lane), with every step and
--     drop-off rounded off, so fish glide down over the terraces instead of bobbing at each one;
--   * the big things standing in the lane (the map's BigAssets): a fish's line bends round each one, a long way ahead
--     of it and back again after, worked out from where the thing stands and never from what the fish "sees". Lines
--     either side of a thing are pressed apart, never onto one another, so the herd doesn't end up in single file
--     through the gaps (as it did when each fish shifted itself over and stayed there).
-- A fish's place is then three numbers: U (its share of the band's width on its own side, -1 to 1) and its lift above the floor,
-- which never change as it swims, and how far along the stream it is.
-- "How far along" is measured down the stream itself, in studs (every `s` in this file). It is not the lane's own s:
-- that is measured along the wandering middle, which on grey-box 15 is 28% longer than the way a fish swims, and by
-- different amounts in different places. Stream.laneS and Stream.fromLane go between the two.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lane = require(ReplicatedStorage.Shared.Lane)

local Stream = {}

local STEP = 24 -- studs of stream between samples
local FINE = 8 -- the lane's own line is read this often (studs of lane s) before it is evened out
local UNTANGLE = 120 -- and evened out over this many studs of lane s first, so that distance along it means something
local CELL = 20 -- the open water is read off the map on a grid of this many studs
local ABOVE = 300 -- a ray starts this far above the lane's floor (never above the water)
local BELOW = 200 -- and looks this far below it
local EDGE_RISE = 10 -- something this far above the seabed that isn't seabed or a prop is the lane's edge
local SCAN = 240 -- the open water is looked for this far either side of the spine
local ROUNDS = 14 -- times the spine is pushed off the edges and evened out
local RELAX = 96 -- studs it is evened out over, each round
local PUSH = 0.5 -- the share of the way off an edge it is moved, each round
local MIN_HALF = 8 -- the band is never narrower than this each side
local COLUMNS = { -1, -0.5, 0, 0.5, 1 } -- the lines of the band the floor is kept for (shares of its half width)
local BUCKET = 200 -- the big things are looked up by where they stand along the lane, in stretches this long
local DODGE_REACH = 600 -- a fish never starts round a thing further ahead than this
local EASE = 12 -- a line comes up to the open water's edge over this many studs

export type Obstacle = {
	S: number,
	A: number,
	HalfLeft: number,
	HalfRight: number,
	Radius: number,
	X: number,
	Z: number,
}

export type Stream = {
	Count: number,
	Length: number, -- studs down the stream to the last sample
	LaneS: { number }, -- the lane's own s at each sample
	X: { number }, -- the band's middle, on the flat
	Z: { number },
	RX: { number }, -- the way across the lane there (to the right going down), a unit vector on the flat
	RZ: { number },
	HalfLeft: { number }, -- how wide the band is to the left of its middle (going down the lane),
	HalfRight: { number }, -- and to the right
	Left: { number }, -- how far a line may be pushed out of the band, from its middle (Left is negative): the open
	Right: { number }, -- water's edges, less the gap, evened out as the band is
	Floor: { { number } }, -- by column, then by sample
	Obstacles: { Obstacle },
	Buckets: { [number]: { Obstacle } },
	Report: string,
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- A list evened out: each value becomes the weighted mean of those within about 3 x sigma samples of it
local function smooth(values: { number }, sigma: number): { number }
	if sigma < 0.05 then
		return table.clone(values)
	end
	local radius = math.ceil(sigma * 3)
	local kernel: { number } = {}
	local total = 0
	for d = -radius, radius do
		local k = math.exp(-d * d / (2 * sigma * sigma))
		kernel[d + radius + 1] = k
		total += k
	end
	local n = #values
	local out = table.create(n, 0)
	for i = 1, n do
		local sum = 0
		for d = -radius, radius do
			sum += values[math.clamp(i + d, 1, n)] * kernel[d + radius + 1]
		end
		out[i] = sum / total
	end
	return out
end

-- The highest (or lowest) of the values within `reach` samples of each
local function extreme(values: { number }, reach: number, highest: boolean): { number }
	local n = #values
	local out = table.create(n, 0)
	for i = 1, n do
		local best = values[i]
		for j = math.max(1, i - reach), math.min(n, i + reach) do
			local v = values[j]
			if (highest and v > best) or (not highest and v < best) then
				best = v
			end
		end
		out[i] = best
	end
	return out
end

local function isSeabed(part: Instance): boolean
	return part.Name == "Seabed" or part:FindFirstAncestor("Seabed") ~= nil
end

-- The open water, read off the map as it is asked about and kept: the seabed's height at each point of a CELL-stud
-- grid, or that there is none there (outside the map, or on the lane's edge: ground that has stepped up into a terrace
-- or a wall). Props are looked through, and so is anything lying low on the seabed.
type Water = {
	Floor: { [number]: number },
	Shut: { [number]: boolean },
	Params: RaycastParams,
	Overlap: OverlapParams,
	Named: boolean,
	Read: number,
}

local function newWater(): Water
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	local overlap = OverlapParams.new()
	overlap.RespectCanCollide = true
	local props = workspace:FindFirstChild("Props", true)
	if props then
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = { props }
	end
	return {
		Floor = {},
		Shut = {},
		Params = params,
		Overlap = overlap,
		Named = workspace:FindFirstChild("Seabed", true) ~= nil,
		Read = 0,
	}
end

-- The seabed under a place, or nil: one look at the map. `floorY` is the lane's floor thereabouts: only where the ray
-- starts from.
local function probe(water: Water, x: number, z: number, floorY: number): number?
	water.Read += 1
	local top = math.max(math.min(floorY + ABOVE, Config.Oxygen.SurfaceY - 1), floorY + 6)
	-- (a ray that starts inside a wall taller than that doesn't see the wall: ask first)
	if #workspace:GetPartBoundsInRadius(Vector3.new(x, top, z), 0.5, water.Overlap) > 0 then
		return nil
	end
	local from = Vector3.new(x, top, z)
	local reach = top - (floorY - BELOW)
	local edge: number? = nil -- the top of the first thing met that is neither seabed nor a prop
	for _ = 1, 6 do
		local hit = workspace:Raycast(from, Vector3.new(0, -reach, 0), water.Params)
		if not hit then
			return nil
		end
		local part = hit.Instance
		if not water.Named or isSeabed(part) then
			return if not edge or edge - hit.Position.Y < EDGE_RISE then hit.Position.Y else nil
		end
		if not edge and part:FindFirstAncestor("Props") == nil then
			edge = hit.Position.Y
		end
		reach -= (from.Y - hit.Position.Y) + 0.1
		from = hit.Position - Vector3.new(0, 0.1, 0)
		if reach <= 0 then
			return nil
		end
	end
	return nil
end

-- The seabed at a point of the grid, or nil: looked at once and kept
local function readCell(water: Water, ix: number, iz: number, floorY: number): number?
	local key = (ix + 32768) * 65536 + (iz + 32768)
	local known = water.Floor[key]
	if known then
		return known
	elseif water.Shut[key] then
		return nil
	end
	local found = probe(water, ix * CELL, iz * CELL, floorY)
	if found then
		water.Floor[key] = found
	else
		water.Shut[key] = true
	end
	return found
end

-- The seabed under a place (the nearest point of the grid), or nil where there is no open water
local function seabedAt(water: Water, x: number, z: number, floorY: number): number?
	return readCell(water, math.floor(x / CELL + 0.5), math.floor(z / CELL + 0.5), floorY)
end

-- The open water either side of a place, along the way across (nx, nz): how far it is open to the left (negative) and
-- to the right, looking no further than `reach` studs. From the nearest open water if the place itself is on an edge;
-- nil when there is none within reach. With `fine`, each edge is then looked for between the grid's last open point and
-- its first shut one, to an eighth of a cell.
local function openSpan(
	water: Water,
	x: number,
	z: number,
	nx: number,
	nz: number,
	floorY: number,
	reach: number,
	fine: boolean
): (number?, number?)
	local steps = math.ceil(reach / CELL)
	local start: number? = nil
	if seabedAt(water, x, z, floorY) then
		start = 0
	else
		for j = 1, steps do
			for side = -1, 1, 2 do
				local offset = side * j * CELL
				if not start and seabedAt(water, x + nx * offset, z + nz * offset, floorY) then
					start = offset
				end
			end
			if start then
				break
			end
		end
	end
	if not start then
		return nil, nil
	end
	local low, high = start, start
	while low - CELL >= -reach and seabedAt(water, x + nx * (low - CELL), z + nz * (low - CELL), floorY) do
		low -= CELL
	end
	while high + CELL <= reach and seabedAt(water, x + nx * (high + CELL), z + nz * (high + CELL), floorY) do
		high += CELL
	end
	if fine then
		for side = -1, 1, 2 do
			local open = if side < 0 then low else high
			if math.abs(open + side * CELL) <= reach then
				local shut = open + side * CELL
				for _ = 1, 3 do
					local middle = (open + shut) / 2
					if probe(water, x + nx * middle, z + nz * middle, floorY) then
						open = middle
					else
						shut = middle
					end
				end
				if side < 0 then
					low = open
				else
					high = open
				end
			end
		end
	end
	return low, high
end

-- The seabed's height under any place, between the grid's points (nil with no open water at any of the four round it)
local function floorUnder(water: Water, x: number, z: number, floorY: number): number?
	local fx, fz = x / CELL, z / CELL
	local ix, iz = math.floor(fx), math.floor(fz)
	local tx, tz = fx - ix, fz - iz
	local sum, weight = 0, 0
	for dx = 0, 1 do
		for dz = 0, 1 do
			local y = readCell(water, ix + dx, iz + dz, floorY)
			if y then
				local w = (if dx == 1 then tx else 1 - tx) * (if dz == 1 then tz else 1 - tz) + 0.001
				sum += y * w
				weight += w
			end
		end
	end
	return if weight > 0 then sum / weight else nil
end

-- The way across a line at each of its points: to the right going down it (the way down, crossed with up, as
-- Lane.point has it)
local function acrossOf(xs: { number }, zs: { number }): ({ number }, { number })
	local n = #xs
	local rx, rz = table.create(n, 0), table.create(n, 0)
	for k = 1, n do
		local a, b = math.max(1, k - 1), math.min(n, k + 1)
		local tx, tz = xs[b] - xs[a], zs[b] - zs[a]
		local length = math.sqrt(tx * tx + tz * tz)
		if length < 0.01 then
			tx, tz, length = 0, 1, 1
		end
		rx[k], rz[k] = -tz / length, tx / length
	end
	return rx, rz
end

-- A line on the flat (with the lane's s at each of its points) sampled again every STEP studs along itself
local function resample(xs: { number }, zs: { number }, ss: { number }): ({ number }, { number }, { number })
	local ox, oz, ol = { xs[1] }, { zs[1] }, { ss[1] }
	local want = STEP -- how far past the last point given out the next one is
	for i = 2, #xs do
		local ax, az = xs[i - 1], zs[i - 1]
		local dx, dz = xs[i] - ax, zs[i] - az
		local length = math.sqrt(dx * dx + dz * dz)
		local done = 0
		while length - done >= want do
			done += want
			local t = done / length
			table.insert(ox, ax + dx * t)
			table.insert(oz, az + dz * t)
			table.insert(ol, lerp(ss[i - 1], ss[i], t))
			want = STEP
		end
		want -= length - done
	end
	return ox, oz, ol
end

-- The sample at or before s, and how far toward the next one s is (0 to 1)
local function locate(stream: Stream, s: number): (number, number)
	local f = math.clamp(s, 0, stream.Length) / STEP
	local i = math.min(math.floor(f), stream.Count - 2)
	return i + 1, f - i
end

function Stream.build(lane: Lane.Lane, bigAssets: { { number } }): Stream
	local started = os.clock()
	local herd, spawn = Config.Herd, Config.Spawn

	-- the lane's own middle, read finely and evened out a little: enough to take the zigzags out, so that the next
	-- steps can work in real distance
	local fineCount = math.max(2, math.floor(lane.Length / FINE) + 1)
	local fx, fz, fs = table.create(fineCount, 0), table.create(fineCount, 0), table.create(fineCount, 0)
	for k = 1, fineCount do
		local centre = Lane.at(lane, (k - 1) * FINE)
		fx[k], fz[k], fs[k] = centre.X, centre.Z, (k - 1) * FINE
	end
	local ux, uz, us = resample(smooth(fx, UNTANGLE / FINE), smooth(fz, UNTANGLE / FINE), fs)
	-- the spine: that, evened out over Herd.Smooth real studs each way, and sampled evenly along itself
	local sigma = math.max(herd.Smooth, 0) / STEP
	local sx, sz, laneS = resample(smooth(ux, sigma), smooth(uz, sigma), us)

	-- and let find its own way through the open water: pushed off every edge nearer than the band is wide, evened out
	-- again, ROUNDS times (its two ends stay where they are)
	local water = newWater()
	local margin = math.min(spawn.BandMax / 2, herd.SpineRoom) + herd.EdgeGap
	for round = 1, ROUNDS do
		local n = #sx
		local nx, nz = acrossOf(sx, sz)
		for k = 2, n - 1 do
			local floorY = (Lane.at(lane, laneS[k])).Y
			local low, high = openSpan(water, sx[k], sz[k], nx[k], nz[k], floorY, margin + CELL, false)
			if low and high then
				local room = math.min(margin, (high - low) / 2)
				local want = math.clamp(0, low + room, high - room)
				sx[k] += nx[k] * want * PUSH
				sz[k] += nz[k] * want * PUSH
			end
		end
		local x1, z1, xn, zn = sx[1], sz[1], sx[n], sz[n]
		sx, sz = smooth(sx, RELAX / STEP), smooth(sz, RELAX / STEP)
		sx[1], sz[1], sx[n], sz[n] = x1, z1, xn, zn
		if round % 4 == 0 or round == ROUNDS then
			sx, sz, laneS = resample(sx, sz, laneS)
		end
	end
	local count = #sx
	local rx, rz = acrossOf(sx, sz)

	-- the open water either side of it, and the lane's floor there
	local cy = table.create(count, 0)
	local low, high = table.create(count, 0), table.create(count, 0) -- the open water's edges, from the spine
	local shut = 0
	for k = 1, count do
		cy[k] = (Lane.at(lane, laneS[k])).Y
		local l, h = openSpan(water, sx[k], sz[k], rx[k], rz[k], cy[k], SCAN, true)
		if l and h then
			low[k], high[k] = l, h
		else
			-- no open water anywhere near (the map has no floor here): a narrow band where the spine is
			shut += 1
			low[k], high[k] = -MIN_HALF, MIN_HALF
		end
	end

	-- the band: inside the open water with a gap, narrowing ahead of a neck. Its middle is the spine (moved only where
	-- the spine itself is at an edge), and its two sides are fitted one by one: each as wide as the water on its own
	-- side allows, up to half of Spawn.BandMax. So a fish near the middle swims the spine's straight line whatever
	-- the walls do, and only the fish out at the sides follow a room's shape. (Fitted as one width about a middle that
	-- moved to keep it in the water, a band 400 wide turned every line half as much again.)
	-- (The edges were found to an eighth of a cell, so that is added to the gap.)
	local gap = herd.EdgeGap + CELL / 8
	local reach = math.max(1, math.floor(herd.NeckAhead / STEP + 0.5))
	local even = math.max(herd.BandSmooth, 0) / STEP
	local mid = table.create(count, 0)
	for k = 1, count do
		local l, h = low[k] + gap + MIN_HALF, high[k] - gap - MIN_HALF
		mid[k] = if l < h then math.clamp(0, l, h) else (low[k] + high[k]) / 2
	end
	mid = smooth(mid, even)
	local roomLeft, roomRight = table.create(count, 0), table.create(count, 0)
	for k = 1, count do
		roomLeft[k], roomRight[k] = mid[k] - (low[k] + gap), (high[k] - gap) - mid[k]
	end
	local trimmed = 0
	-- one side's width: what the water allows from here to NeckAhead on, evened out; and where that leaves a corner
	-- of it over the gap, made narrower round there and evened out again (never cut off square: a cut is a corner in
	-- every line near the band's side)
	local function fit(room: { number }): { number }
		local ahead = extreme(room, reach, false)
		local wide = table.create(count, 0)
		for k = 1, count do
			wide[k] = math.max(MIN_HALF, math.min(ahead[k] * spawn.LaneFill, spawn.BandMax / 2))
		end
		local half = smooth(wide, even)
		for _ = 1, 5 do
			local over = table.create(count, 0)
			local any = false
			for k = 1, count do
				local most = math.max(room[k], MIN_HALF)
				if half[k] > most + 0.5 then
					over[k] = half[k] - most
					any = true
				end
			end
			if not any then
				break
			end
			local spread = extreme(over, reach * 2, true)
			for k = 1, count do
				if spread[k] > 0 then
					trimmed += 1
					wide[k] = math.max(MIN_HALF, wide[k] - spread[k] * 1.25)
				end
			end
			half = smooth(wide, even)
		end
		return half
	end
	local halfLeft, halfRight = fit(roomLeft), fit(roomRight)
	-- how far out of the band a line may be pushed (round a big thing): to the open water's edge, less the gap
	local left = smooth(extreme(roomLeft, reach, false), even)
	local right = smooth(extreme(roomRight, reach, false), even)

	local stream: Stream = {
		Count = count,
		Length = (count - 1) * STEP,
		LaneS = laneS,
		X = table.create(count, 0),
		Z = table.create(count, 0),
		RX = rx,
		RZ = rz,
		HalfLeft = halfLeft,
		HalfRight = halfRight,
		Left = table.create(count, 0),
		Right = table.create(count, 0),
		Floor = {},
		Obstacles = {},
		Buckets = {},
		Report = "",
	}
	for k = 1, count do
		stream.X[k] = sx[k] + rx[k] * mid[k]
		stream.Z[k] = sz[k] + rz[k] * mid[k]
		stream.Left[k] = -math.max(left[k], halfLeft[k])
		stream.Right[k] = math.max(right[k], halfRight[k])
	end

	-- the floor under each line of the band: evened out, and where that dips under the real floor (ahead of a step
	-- up, behind a drop-off) lifted by as much, from FloorAhead before to FloorAhead after. On a steady slope it is
	-- the floor itself. (The highest floor within FloorAhead, evened out, was tried first: on the lane's steady 9%
	-- slope that alone put every fish 11 studs higher than its number.)
	local rise = math.max(1, math.floor(herd.FloorAhead / STEP + 0.5))
	local floorSigma = math.max(herd.FloorSmooth, 0) / STEP
	for c, share in COLUMNS do
		local column = table.create(count, 0)
		for k = 1, count do
			local offset = mid[k] + share * (if share < 0 then halfLeft[k] else halfRight[k])
			column[k] = floorUnder(water, sx[k] + rx[k] * offset, sz[k] + rz[k] * offset, cy[k]) or cy[k]
		end
		local level = smooth(column, floorSigma)
		local under = table.create(count, 0)
		for k = 1, count do
			under[k] = math.max(0, column[k] - level[k])
		end
		local lift = smooth(extreme(under, rise, true), math.max(floorSigma / 2, 1))
		for k = 1, count do
			level[k] += lift[k] * 1.1
		end
		stream.Floor[c] = level
	end

	-- the big things: where each stands along the stream and across the band
	for _, row in bigAssets do
		local x, z, radius = row[1], row[2], row[3]
		if type(x) == "number" and type(z) == "number" and type(radius) == "number" then
			local best, bestD = 1, math.huge
			for k = 1, count do
				local dx, dz = x - stream.X[k], z - stream.Z[k]
				local d = dx * dx + dz * dz
				if d < bestD then
					best, bestD = k, d
				end
			end
			local dx, dz = x - stream.X[best], z - stream.Z[best]
			-- (down the lane is the way across turned a quarter: (rz, -rx))
			local along = dx * rz[best] - dz * rx[best]
			local obstacle: Obstacle = {
				S = math.clamp((best - 1) * STEP + along, 0, stream.Length),
				A = dx * rx[best] + dz * rz[best],
				HalfLeft = halfLeft[best],
				HalfRight = halfRight[best],
				Radius = radius,
				X = x,
				Z = z,
			}
			table.insert(stream.Obstacles, obstacle)
			for b = math.floor((obstacle.S - DODGE_REACH) / BUCKET), math.floor((obstacle.S + DODGE_REACH) / BUCKET) do
				stream.Buckets[b] = stream.Buckets[b] or {}
				table.insert(stream.Buckets[b], obstacle)
			end
		end
	end

	stream.Report = string.format(
		"%d studs long (the lane's own line: %d), %d samples every %d studs, the map read at %d places, %d obstacles, in %.0f ms; the band was pulled in from the edge at %d samples, and %d had no open water near",
		(count - 1) * STEP,
		lane.Length,
		count,
		STEP,
		water.Read,
		#stream.Obstacles,
		(os.clock() - started) * 1000,
		trimmed,
		shut
	)
	return stream
end

-- The share of the band's width (-1 to 1, on its own side of the middle) a place `across` studs from the middle is at
function Stream.share(stream: Stream, s: number, across: number): number
	local i, t = locate(stream, s)
	local side = if across < 0 then stream.HalfLeft else stream.HalfRight
	return math.clamp(across / math.max(lerp(side[i], side[i + 1], t), 1), -1, 1)
end

-- The way down the stream at s, on the flat
function Stream.along(stream: Stream, s: number): Vector3
	local i = locate(stream, s)
	local flat = Vector3.new(stream.X[i + 1] - stream.X[i], 0, stream.Z[i + 1] - stream.Z[i])
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
end

-- The lane's own s at a place s studs down the stream
function Stream.laneS(stream: Stream, s: number): number
	local i, t = locate(stream, s)
	return lerp(stream.LaneS[i], stream.LaneS[i + 1], t)
end

-- How far down the stream the lane's own s is
function Stream.fromLane(stream: Stream, laneS: number): number
	local list = stream.LaneS
	local low, high = 1, stream.Count - 1
	while low < high do
		local middle = (low + high + 1) // 2
		if list[middle] <= laneS then
			low = middle
		else
			high = middle - 1
		end
	end
	local span = list[low + 1] - list[low]
	local t = if span > 0 then math.clamp((laneS - list[low]) / span, 0, 1) else 0
	return (low - 1 + t) * STEP
end

-- A fish's place across the band at s, in studs from its middle: U of the half width, plus what it is giving way by,
-- bent round the big things near s (`dodge` 1: all the way round; 0: straight through), and kept in the open water.
function Stream.across(stream: Stream, s: number, u: number, give: number, dodge: number, body: number): number
	local i, t = locate(stream, s)
	local width = if u < 0 then stream.HalfLeft else stream.HalfRight
	local a = u * lerp(width[i], width[i + 1], t) + give
	if dodge > 0 then
		local list = stream.Buckets[math.floor(s / BUCKET)]
		if list then
			local herd = Config.Herd
			for _, o in list do
				-- how far round: most of its circle (the circle is drawn round the whole thing) and the fish's own
				-- half width, with a little water between
				local clear = (o.Radius * herd.DodgeShare + body + herd.DodgeGap) * dodge
				local length = math.clamp(clear * herd.DodgeLength, 100, DODGE_REACH)
				local p = (s - o.S) / length
				if p > -1 and p < 1 then
					-- which side, and how near its line passes, are settled by where the fish's line is as it
					-- passes the thing, whatever s is: so the push is the same one all the way past, it comes in
					-- and goes out with no corner, and the pushes of two things near each other just add up
					local d = u * (if u < 0 then o.HalfLeft else o.HalfRight) - o.A
					local side = if d > 0 then 1 elseif d < 0 then -1 elseif u >= 0 then 1 else -1
					local k = 1 - p * p
					local r = clear * k * k
					a += side * (math.sqrt(d * d + r * r) - math.abs(d))
				end
			end
		end
	end
	local left = lerp(stream.Left[i], stream.Left[i + 1], t) + body
	local right = lerp(stream.Right[i], stream.Right[i + 1], t) - body
	if right - left < EASE * 2 then
		return (left + right) / 2
	end
	-- eased in to the edge, not stopped dead at it: a line pressed against the edge has no corner in it
	if a > right - EASE then
		return right - EASE * math.exp(-(a - (right - EASE)) / EASE)
	elseif a < left + EASE then
		return left + EASE * math.exp(-((left + EASE) - a) / EASE)
	end
	return a
end

-- The floor at s under a place `across` studs from the band's middle
function Stream.floor(stream: Stream, s: number, across: number): number
	local i, t = locate(stream, s)
	local width = if across < 0 then stream.HalfLeft else stream.HalfRight
	local half = math.max(lerp(width[i], width[i + 1], t), 1)
	-- which two of the band's lines it is between
	local f = (math.clamp(across / half, -1, 1) + 1) / 2 * (#COLUMNS - 1)
	local c = math.min(math.floor(f), #COLUMNS - 2)
	local e = f - c
	local a, b = stream.Floor[c + 1], stream.Floor[c + 2]
	return lerp(lerp(a[i], a[i + 1], t), lerp(b[i], b[i + 1], t), e)
end

-- The point of the stream at s, `across` studs from the band's middle, for a fish that swims `lift` above the floor
-- in open water (pressed down in the shallows: Config.herdHeight). Also returns the floor there.
function Stream.point(stream: Stream, s: number, across: number, lift: number): (Vector3, number)
	local i, t = locate(stream, s)
	local floorY = Stream.floor(stream, s, across)
	return Vector3.new(
		lerp(stream.X[i], stream.X[i + 1], t) + lerp(stream.RX[i], stream.RX[i + 1], t) * across,
		floorY + Config.herdHeight(lift, floorY),
		lerp(stream.Z[i], stream.Z[i + 1], t) + lerp(stream.RZ[i], stream.RZ[i + 1], t) * across
	),
		floorY
end

-- Where a position is in the stream: s along it, and how far across from the band's middle. With `near` (an s it is
-- known to be close to) only that stretch is searched.
function Stream.project(stream: Stream, position: Vector3, near: number?): (number, number)
	local first, last = 1, stream.Count - 1
	if near then
		local i = locate(stream, near)
		first, last = math.max(first, i - 4), math.min(last, i + 4)
	end
	local bestI, bestU, bestD = first, 0, math.huge
	for i = first, last do
		local ax, az = stream.X[i], stream.Z[i]
		local bx, bz = stream.X[i + 1] - ax, stream.Z[i + 1] - az
		local length2 = bx * bx + bz * bz
		local u = if length2 > 0
			then math.clamp(((position.X - ax) * bx + (position.Z - az) * bz) / length2, 0, 1)
			else 0
		local dx, dz = position.X - (ax + bx * u), position.Z - (az + bz * u)
		local d = dx * dx + dz * dz
		if d < bestD then
			bestI, bestU, bestD = i, u, d
		end
	end
	local x = lerp(stream.X[bestI], stream.X[bestI + 1], bestU)
	local z = lerp(stream.Z[bestI], stream.Z[bestI + 1], bestU)
	local across = (position.X - x) * lerp(stream.RX[bestI], stream.RX[bestI + 1], bestU)
		+ (position.Z - z) * lerp(stream.RZ[bestI], stream.RZ[bestI + 1], bestU)
	return (bestI - 1 + bestU) * STEP, across
end

-- The big thing whose circle a place is inside, if any (s: about where along the lane the place is)
function Stream.inside(stream: Stream, s: number, x: number, z: number): Obstacle?
	local list = stream.Buckets[math.floor(s / BUCKET)]
	if list then
		for _, o in list do
			local dx, dz = x - o.X, z - o.Z
			if dx * dx + dz * dz < o.Radius * o.Radius then
				return o
			end
		end
	end
	return nil
end

return Stream
