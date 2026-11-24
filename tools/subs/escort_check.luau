-- The fish that swims with the submarine (docs/design/submarine.md, "From the fish onto the sub"), checked without
-- Studio: it runs the real Config, SubTrip and SubService against made-up services, on the grey-box's own lane (its Path,
-- tools/studio/greybox/00_start.luau), and looks at every frame of a trip for every fish kind, Normal and Colossal (the
-- biggest), with each of the nine subs.
--   hull      the fish's box against the hull's box, as banked (studs between them; under 0 they overlap)
--   wall      the fish's box against the lane's sides, from the hop on (an estimate: the lane's width round its middle,
--             not the built terraces; Studio measures the real one)
--   gate      how far out of the gate its tail is as the rider hops
--   camera    the fish's box against the line from the camera (as cameraFor eases it) to the rider's seat, from the run on
--   inside    seconds the camera is inside its box on the way out and in the hop (you are on its back)
--   view      the share of it in the picture and not behind the sub or the rider, over the weave (27 points of its box, the
--             sub as cells: escort_hulls.py); plain: the share of the weave with a third of it or more; sideView: view, at
--             either side
--   frame     the share of the weave its middle is in a 16:9 picture
--   water     its box against the floor and the surface at its middle (a fish taller than the water can't clear both)
--   turn      the most its heading changes in a frame, degrees; pace: the most it moves in the sub's frame, studs a second
--   jump      the most a frame's move differs from the frame's before, studs; start: the pace it sets off at
--   home      how far it is from its place as the kick begins
-- and then the server's rules (who gets an escort; the fish given up, unequipped, the player gone: never left, never two).
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/subs/escort_check.luau <the repo> /tmp/place.rbxl [csv out] [which] [cells]
-- (`cells`: what python3 tools/subs/escort_hulls.py <path> wrote; without it nothing is hidden by the sub)
-- (`which`: one fish's Id, or a part of them all as "3/16"; all of them in one go take over ten minutes)
-- (Lune 0.11: ~/.rokit/tool-storage/lune-org/lune/0.11.1/lune on Hugo's PC)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Harness = require("../index/harness")

local ROOT = process.args[1]
local world = Harness.open(process.args[2])
local ok, done = Harness.tally()
local V3, CF = roblox.Vector3, roblox.CFrame
local UP = V3.new(0, 1, 0)

local clock = 1000
world.globals.os = setmetatable({
	clock = function()
		return clock
	end,
}, { __index = os })
world.services.HttpService = {
	JSONEncode = function(_, v)
		return serde.encode("json", v)
	end,
	JSONDecode = function(_, s)
		return serde.decode("json", s)
	end,
}
local workspaceStub = {
	GetServerTimeNow = function()
		return clock
	end,
	FindFirstChild = function()
		return nil
	end,
}
world.services.Workspace = workspaceStub

local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
local SubTrip = world.require(world.find("ReplicatedStorage.Shared.SubTrip"))
local c = Config.Sub

----------------------------------------------------------------------------------------------------------------------
-- The lane: its own path evened out, as the herd's stream is (the real one is read off the built map)

local rows
do
	local text = fs.readFile(ROOT .. "/tools/studio/greybox/00_start.luau")
	local json = string.match(text, 'SetAttribute%("Path", %[==%[(.-)%]==%]%)')
	rows = serde.decode("json", json)
end
local STEP = 24
local X0 = rows[1][2]
local lane = {} -- { x, y, z, width } every STEP studs
for _, r in rows do
	table.insert(lane, { r[2], r[3], r[4], r[5] })
end
local line = {}
do
	local reach = 14
	for i = 1, #lane do
		local x, z, y, n = 0, 0, 0, 0
		for k = math.max(1, i - reach), math.min(#lane, i + reach) do
			local w = reach + 1 - math.abs(k - i)
			x += lane[k][1] * w
			z += lane[k][3] * w
			y += lane[k][2] * w
			n += w
		end
		line[i] = { x / n, if i < reach then lane[i][2] else y / n, z / n }
		line[i][3] = if i < reach then lane[i][3] else line[i][3]
	end
end
local lineS = { 0 }
for i = 2, #line do
	local dx, dz = line[i][1] - line[i - 1][1], line[i][3] - line[i - 1][3]
	lineS[i] = lineS[i - 1] + math.sqrt(dx * dx + dz * dz)
end
local LENGTH = lineS[#lineS]
local function locate(s)
	local lo, hi = 1, #lineS - 1
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if lineS[mid] <= s then
			lo = mid
		else
			hi = mid - 1
		end
	end
	local span = lineS[lo + 1] - lineS[lo]
	return lo, math.clamp(if span > 0 then (s - lineS[lo]) / span else 0, 0, 1)
end
local function streamPoint(s, lift, under)
	s = math.clamp(s, 0, LENGTH)
	local i, t = locate(s)
	local a, b = line[i], line[i + 1]
	local y = a[2] + (b[2] - a[2]) * t
	return V3.new(a[1] + (b[1] - a[1]) * t, math.min(y + lift, Config.Oxygen.SurfaceY - under), a[3] + (b[3] - a[3]) * t)
end
local function streamS(at, near)
	local best, bestD = 0, math.huge
	local first, last = 1, #line - 1
	if near then
		local i = locate(near)
		first, last = math.max(1, i - 8), math.min(last, i + 8)
	end
	for i = first, last do
		local ax, az = line[i][1], line[i][3]
		local bx, bz = line[i + 1][1] - ax, line[i + 1][3] - az
		local l2 = bx * bx + bz * bz
		local u = math.clamp(((at.X - ax) * bx + (at.Z - az) * bz) / l2, 0, 1)
		local dx, dz = at.X - ax - bx * u, at.Z - az - bz * u
		local d = dx * dx + dz * dz
		if d < bestD then
			best, bestD = lineS[i] + (lineS[i + 1] - lineS[i]) * u, d
		end
	end
	return best
end
local function wayAt(s)
	local w = streamPoint(s + 30, 0, 0) - streamPoint(s - 30, 0, 0)
	w = V3.new(w.X, 0, w.Z)
	return w.Unit
end
-- the lane's sides from the line at s (the lane's width round its own middle; a step of the map counts at once)
local function roomAt(s)
	local i, t = locate(math.clamp(s, 0, LENGTH))
	local right = wayAt(s):Cross(UP)
	local function at(k)
		local p, q = lane[k], line[k]
		local off = V3.new(p[1] - q[1], 0, p[3] - q[3]):Dot(right)
		return p[4] / 2 - off, p[4] / 2 + off
	end
	local l1, r1 = at(i)
	local l2, r2 = at(i + 1)
	return l1 + (l2 - l1) * t, r1 + (r2 - r1) * t
end
local function streamRoom(s)
	local left, right = math.huge, math.huge
	for _, d in { -40, 0, 40 } do
		local l, r = roomAt(math.clamp(s + d, 0, LENGTH))
		left, right = math.min(left, l), math.min(right, r)
	end
	return left, right
end

----------------------------------------------------------------------------------------------------------------------
-- The fish: their boxes and saddles, as FishModel and FishService.resize make them

local kinds = {}
for _, f in Config.Fish do
	local path = ROOT .. "/src/shared/Creatures/" .. f.Id .. ".json"
	local seat = nil
	if fs.isFile(path) then
		local rig = serde.decode("json", fs.readFile(path))
		seat = V3.new(rig.Seat[1], rig.Seat[2], rig.Seat[3]) * (f.Size.Z / rig.Size[3])
	else
		seat = V3.new(0, f.Size.Y / 2, -f.Size.Z * 0.04)
	end
	for _, tier in { "Normal", "Colossal" } do
		local scale = Config.sizeScale(tier, f)
		table.insert(kinds, {
			Id = f.Id,
			Size = tier,
			Body = f.Size * scale,
			Saddle = seat * scale + V3.new(0, Config.Ride.SeatHeight, 0),
		})
	end
end
local function fishOf(id, size)
	for _, k in kinds do
		if k.Id == id and k.Size == size then
			return k
		end
	end
	error("no " .. id)
end

----------------------------------------------------------------------------------------------------------------------
-- The services SubService asks, made up

local discarded, spawned = 0, {}
local function signal()
	local fns = {}
	return {
		Connect = function(_, f)
			table.insert(fns, f)
		end,
		fire = function(...)
			for _, f in fns do
				f(...)
			end
		end,
	}
end
local added, removing, heartbeat, actions = signal(), signal(), signal(), signal()
local told = {}
local FishService = {
	zones = function()
		return table.create(10, {})
	end,
	landStart = function(n)
		-- (the lands' lengths: 1000, then 2500 each, along the evened line)
		return if n >= 1 and n <= 10 then (if n == 1 then 0 else 1000 + (n - 2) * 2500) / 23500 * LENGTH else nil
	end,
	streamS = streamS,
	streamPoint = streamPoint,
	streamRoom = streamRoom,
	streamLength = function()
		return LENGTH
	end,
	keepFor = function() end,
	stockNear = function() end,
	discard = function(w)
		if w.Model.Parent then
			w.Model.Parent = nil
			discarded += 1
		end
	end,
	spawnFor = function(id, variant, size, at, dir, player)
		local k = fishOf(id, size)
		local root = {
			Anchored = false,
			CFrame = CF.lookAt(at, at + dir),
			SetNetworkOwner = function() end,
		}
		setmetatable(root, {
			__index = function(t, key)
				return if key == "Position" then rawget(t, "CFrame").Position else nil
			end,
		})
		local attrs = {}
		local w = {
			Root = root,
			Saddle = { Position = k.Saddle },
			Body = k.Body,
			Variant = variant,
			Size = size,
			Id = id,
			Rider = nil,
			Model = {
				Parent = "Fish",
				SetAttribute = function(_, key, value)
					attrs[key] = value
				end,
				GetAttribute = function(_, key)
					return attrs[key]
				end,
			},
		}
		table.insert(spawned, w)
		return w
	end,
}
local state, equipped = "Dock", nil
local flung, seated = 0, 0
local RideService
RideService = {
	equippedOf = function()
		return equipped
	end,
	stateOf = function()
		return state
	end,
	fling = function()
		flung += 1
		state = "Jumping"
		return true
	end,
	seatOn = function(player, w)
		seated += 1
		w.Rider = player
		state = "Riding"
		return true
	end,
	letGo = function()
		state = "Free"
	end,
}
world.stubs["ServerScriptService.Server.Services.FishService"] = FishService
world.stubs["ServerScriptService.Server.Services.RideService"] = RideService
world.stubs["ServerScriptService.Server.Services.AquariumService"] = {
	tankOf = function()
		return {}
	end,
	coinsOf = function()
		return 0
	end,
	spend = function()
		return true
	end,
	give = function() end,
}
world.stubs["ReplicatedStorage.Shared.Net"] = {
	Ride = {
		FireClient = function(_, _, kind, a, b)
			table.insert(told, { kind, a, b })
		end,
	},
	Action = { OnServerEvent = { Connect = actions.Connect } },
}
world.services.Players = {
	PlayerAdded = added,
	PlayerRemoving = removing,
	GetPlayers = function()
		return {}
	end,
}
world.services.RunService = {
	IsStudio = function()
		return false
	end,
	Heartbeat = heartbeat,
}
local delayed = {}
world.globals.task = {
	spawn = function(f)
		f()
	end,
	delay = function(s, f)
		table.insert(delayed, { clock + s, f })
	end,
}
local SubService = world.require(world.find("ServerScriptService.Server.Services.SubService"))
SubService.Init()
SubService.Start()

local entry = V3.zero
local attrs = {}
local player = {
	UserId = 7,
	SetAttribute = function(_, k, v)
		attrs[k] = v
	end,
	GetAttribute = function(_, k)
		return attrs[k]
	end,
	RequestStreamAroundAsync = function() end,
	Character = {
		FindFirstChild = function()
			return {
				IsA = function()
					return true
				end,
				Position = entry,
			}
		end,
	},
}
player.Character.FindFirstChild = function()
	return {
		IsA = function()
			return true
		end,
		Position = entry,
	}
end
added.fire(player)

local function beat(dt)
	clock += dt
	heartbeat.fire(dt)
	for i = #delayed, 1, -1 do
		if delayed[i][1] <= clock then
			delayed[i][2]()
			table.remove(delayed, i)
		end
	end
end

-- Into the water on a fish (nil: on foot); the trip the server wrote, as the clients read it
local function dive(tier, land, kind, mounted, outX, outZ)
	state = "Dock"
	SubService.setSub(player, 9, tier)
	-- (the land: the furthest of that sub's, or nearer by its pick)
	equipped = if kind then { Id = kind.Id, Size = kind.Size, Variant = "" } else nil
	attrs.LandMounted = mounted or nil
	entry = V3.new(X0 + outX, -5, outZ)
	beat(1 / 60)
	actions.fire(player, "SubPick", land, "")
	attrs.LandMounted = nil
	local took = RideService.Diving(player)
	if took then
		state = "Carried"
	end
	local json = attrs.SubTrip
	return took, if json then SubTrip.decode(json) else nil
end
local function home()
	-- (a death or a reset: the server sees the state gone and tidies up)
	if attrs.SubTrip then
		state = "Dock"
		beat(1 / 60)
	end
	for _ = 1, 120 do
		beat(1 / 20)
	end
	state = "Dock"
end

----------------------------------------------------------------------------------------------------------------------
-- The numbers

-- The gap between two boxes turned as they are (separating axes): under 0 they overlap
local function boxGap(a, ha, b, hb)
	local A = { a.RightVector, a.UpVector, a.LookVector }
	local B = { b.RightVector, b.UpVector, b.LookVector }
	local HA, HB = { ha.X, ha.Y, ha.Z }, { hb.X, hb.Y, hb.Z }
	local to = b.Position - a.Position
	local best = -math.huge
	local function try(axis)
		local m = axis.Magnitude
		if m < 1e-4 then
			return
		end
		axis /= m
		local reach = 0
		for i = 1, 3 do
			reach += HA[i] * math.abs(A[i]:Dot(axis)) + HB[i] * math.abs(B[i]:Dot(axis))
		end
		best = math.max(best, math.abs(to:Dot(axis)) - reach)
	end
	for i = 1, 3 do
		try(A[i])
		try(B[i])
		for k = 1, 3 do
			try(A[i]:Cross(B[k]))
		end
	end
	return best
end
local function pointGap(cf, half, p)
	local o = cf:PointToObjectSpace(p)
	local d = V3.new(
		math.max(math.abs(o.X) - half.X, 0),
		math.max(math.abs(o.Y) - half.Y, 0),
		math.max(math.abs(o.Z) - half.Z, 0)
	)
	return d.Magnitude
end

-- The subs as cells (escort_hulls.py), and whether one is in the way of the straight line from a to b
local hullCells = nil
if process.args[5] then
	local data = serde.decode("json", fs.readFile(process.args[5]))
	hullCells = { Cell = data.Cell }
	for tier, list in data.Subs do
		local set = {}
		for _, key in list do
			local x, y, z = string.match(key, "(-?%d+),(-?%d+),(-?%d+)")
			set[(tonumber(x) + 128) * 65536 + (tonumber(y) + 128) * 256 + tonumber(z) + 128] = true
		end
		hullCells[tier] = set
	end
end
local function hidden(tier, sub, a, b)
	local set, cell = hullCells[tier], hullCells.Cell
	local p, q = sub:PointToObjectSpace(a) / cell, sub:PointToObjectSpace(b) / cell
	local px, py, pz = p.X, p.Y, p.Z
	local dx, dy, dz = q.X - px, q.Y - py, q.Z - pz
	local long = math.sqrt(dx * dx + dy * dy + dz * dz)
	-- (only the stretch of it abreast of the sub, 36 studs either way of its middle)
	local u0, u1 = 0, 1
	if math.abs(dz) > 1e-6 then
		local e, f = (-36 / cell - pz) / dz, (36 / cell - pz) / dz
		u0, u1 = math.max(0, math.min(e, f)), math.min(1, math.max(e, f))
	end
	local n = math.ceil((u1 - u0) * long / 0.7)
	for i = 0, n do
		local u = u0 + (u1 - u0) * i / math.max(n, 1)
		local x, y, z = math.floor(px + dx * u), math.floor(py + dy * u), math.floor(pz + dz * u)
		if set[(x + 128) * 65536 + (y + 128) * 256 + z + 128] then
			return true
		end
	end
	return false
end

local FPS = 60
local alpha = world.require(world.find("ReplicatedStorage.Shared.Ease")).alpha
local smooth = world.require(world.find("ReplicatedStorage.Shared.Ease")).smoothstep
-- The rider as SubController.riderAt has them, and the camera as its cameraFor has it, easing and all (but the pull-in
-- off the walls); if either changes, change this
local function riderOf(trip, t, sub, fish, mem)
	local pickupAt, rideAt = SubTrip.times(trip)
	local seat = sub * SubTrip.Seat
	if t >= rideAt then
		return seat.Position
	end
	local u = (t - pickupAt) / math.max(rideAt - pickupAt, 0.01)
	local saddle = fish * CF.new(trip.Escort.Saddle)
	if u <= c.EscortHopFrom then
		return saddle.Position
	end
	mem.from = mem.from or saddle
	local k = smooth(c.EscortHopFrom, c.EscortHopTo, u)
	return mem.from.Position:Lerp(seat.Position, k) + UP * (c.EscortHopUp * math.sin(k * math.pi))
end
local function flat(v)
	local f = V3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else V3.new(0, 0, -1)
end
local function cameraOf(trip, t, sub, speed, rider, mem)
	local pickupAt, rideAt, arriveAt = SubTrip.times(trip)
	local way0 = flat(SubTrip.way(trip, 30, 30))
	local under = math.max(0, rider.Y - sub.Position.Y)
	local goal, focus, rate, wide = nil, nil, 4, 70
	if t < pickupAt then
		rate = 6.4 / math.max(trip.Approach, 0.1)
		local u = math.clamp(t / math.max(pickupAt, 0.01), 0, 1)
		goal = rider - way0 * (10 + 8 * u) + UP * 3
		focus = rider + way0 * 12 - UP * (0.4 * under * smooth(0.3, 1, u))
	elseif t < rideAt then
		local u = (t - pickupAt) / math.max(rideAt - pickupAt, 0.01)
		goal = rider - way0 * (18 + 6 * u) + UP * (3 + 6 * u)
		focus = rider + way0 * 12 - UP * (0.4 * under * (1 - u))
		rate = 4.8 / math.max(trip.Pickup, 0.1)
	elseif t < arriveAt then
		local way = sub.LookVector
		local share = math.clamp(speed / math.max(c.Speed, 1), 0, 1)
		goal = sub.Position - way * (c.Distance + 8 * share) + UP * (10 - 3 * share)
		focus = sub.Position + way * (25 + 20 * share)
		rate = 7
		wide = 70 + c.Fov * share + c.FovFar * math.clamp((speed - c.Speed) / math.max(c.FovFarAt - c.Speed, 1), 0, 1)
	else
		local way = flat(sub.LookVector)
		goal = sub.Position - way * 36 + UP * 9
		focus = sub.Position + way * 10
		wide = 74
	end
	local anchor = if t < rideAt then rider else sub.Position
	local kind = if t < rideAt then "rider" else "sub"
	if mem.kind ~= kind then
		local first = not mem.kind
		mem.pos = if first then goal - anchor else mem.anchor + mem.pos - anchor
		mem.focus = if first then focus - anchor else mem.anchor + mem.focus - anchor
		mem.fov = mem.fov or 70
		mem.kind = kind
	end
	mem.anchor = anchor
	mem.pos = mem.pos:Lerp(goal - anchor, alpha(rate, 1 / FPS))
	mem.focus = mem.focus:Lerp(focus - anchor, alpha(rate * 1.4, 1 / FPS))
	mem.fov += (wide - mem.fov) * alpha(3, 1 / FPS)
	local at, look = anchor + mem.pos, anchor + mem.focus
	at = V3.new(at.X, math.min(at.Y, Config.Oxygen.SurfaceY - 7), at.Z)
	return at, look, mem.fov
end

local function measure(trip, tier, kind)
	local e = trip.Escort
	local pickupAt, rideAt, arriveAt, dropAt, endAt = SubTrip.times(trip)
	local hull = SubTrip.Hulls[tier]
	local hullHalf = V3.new(hull[1], (hull[2] + hull[3]) / 2, (hull[4] + hull[5]) / 2)
	local hullAt = CF.new(0, (hull[2] - hull[3]) / 2, (hull[5] - hull[4]) / 2)
	local out = { hull = math.huge, hullAt = 0, hullIn = math.huge, wall = math.huge, wallAt = 0, gate = 0, camera = math.huge, cameraAt = 0,
		frame = 0, turn = 0, turnAt = 0, pace = 0, home = 0, left = 0, right = 0, floor = math.huge, roof = math.huge, loop = (if e.Right then 1 else 0) + (if e.Left then 2 else 0), turns = e.Turns,
		inside = 0, start = 0, jump = 0, view = 0, plain = 0, sideView = 0, sx0 = 1, sx1 = -1,
		ride = arriveAt - rideAt }
	local a, b = SubTrip.escortTimes(trip, e.Half)
	local seen, of = 0, 0
	local wasRel, wasLook, wasPos, wasSeen = nil, nil, nil, nil
	local near = nil
	local mem = {}
	local views, sides, sideSum, plain = 0, 0, 0, 0
	for k = 0, math.floor((dropAt + c.Kick) * FPS) do
		local t = k / FPS
		local sub, speed = SubTrip.sub(trip, t)
		local fish, o = SubTrip.escort(trip, t)
		local gap = boxGap(fish, e.Half, sub * hullAt, hullHalf)
		if t < pickupAt then
			out.hullIn = math.min(out.hullIn, gap)
		elseif gap < out.hull then
			out.hull, out.hullAt = gap, t
		end
		-- the walls: the box's reach to either side of the lane at its middle and its two ends
		if t >= pickupAt then
			for _, z in { -e.Half.Z, 0, e.Half.Z } do
				local p = (fish * CF.new(0, 0, z)).Position
				near = streamS(p, if near and t > rideAt then near else nil)
				if t <= rideAt then
					near = nil
				end
				local s = near or streamS(p)
				local base = streamPoint(s, 0, 0)
				local right = wayAt(s):Cross(UP)
				local x = (p - base):Dot(right)
				local l, r = roomAt(s)
				local g = math.min(l + x, r - x) - e.Half.X
				if s > 1 and g < out.wall then
					out.wall, out.wallAt = g, t
				end
				if z == 0 and t >= rideAt then
					out.floor = math.min(out.floor, p.Y - e.Half.Y - streamPoint(s, 0, -1e4).Y)
					out.roof = math.min(out.roof, Config.Oxygen.SurfaceY - p.Y - e.Half.Y)
				end
			end
		end
		if math.abs(t - (pickupAt + c.EscortHopFrom * trip.Pickup)) < 0.5 / FPS then
			out.gate = fish.Position.Z - e.Half.Z - rows[1][4]
		end
		-- the camera, from the first frame: on the fish's back it must be out of its body, and from the hop on the fish off
		-- the line from it to the rider's seat
		local rider = riderOf(trip, t, sub, fish, mem)
		local cam, look, fov = cameraOf(trip, t, sub, speed, rider, mem)
		if t < rideAt and pointGap(fish, e.Half, cam) <= 0 then
			out.inside += 1 / FPS
		end
		if t >= rideAt then
			local seat = (sub * SubTrip.Seat).Position
			for i = 0, 8 do
				local g = pointGap(fish, e.Half, cam:Lerp(seat, i / 8))
				if g < out.camera then
					out.camera, out.cameraAt = g, t
				end
			end
		end
		if t >= a and t <= b and k % 4 == 0 then
			-- in the weave: how much of it is in the picture and not behind the sub or the rider (27 points of its box)
			local eye = CF.lookAt(cam, look)
			local tall = math.tan(math.rad(fov / 2))
			local function inPicture(p)
				local v = eye:PointToObjectSpace(p)
				return v.Z < 0 and math.abs(v.Y / v.Z) < tall and math.abs(v.X / v.Z) < tall * 16 / 9, v
			end
			local clear = 0
			for x = -1, 1 do
				for y = -1, 1 do
					for z = -1, 1 do
						local p = (fish * CF.new(e.Half.X * x * 0.8, e.Half.Y * y * 0.8, e.Half.Z * z * 0.8)).Position
						if inPicture(p) and not (hullCells and hidden(tier, sub, cam, p)) then
							clear += 1 / 27
						end
					end
				end
			end
			of += 1
			local inside, v = inPicture(fish.Position)
			if inside then
				seen += 1
			end
			views += clear
			if clear >= 1 / 3 then
				plain += 1
			end
			local sx = v.X / math.max(-v.Z, 1) / (tall * 16 / 9)
			out.sx0, out.sx1 = math.min(out.sx0, sx), math.max(out.sx1, sx)
			if math.min(math.abs(o.X - e.Low), math.abs(o.X - e.High)) < 6 then
				sides += 1
				sideSum += clear
			end
		end
		if t >= rideAt then
			out.left = math.min(out.left, o.X)
			out.right = math.max(out.right, o.X)
		end
		-- moving smoothly: its place and heading in the sub's own level frame
		local level = CF.lookAt(sub.Position, sub.Position + V3.new(sub.LookVector.X, 0, sub.LookVector.Z))
		local look = if t < rideAt then fish.LookVector else level:VectorToObjectSpace(fish.LookVector)
		if wasRel and t > 0 then
			local p = (o - wasRel).Magnitude * FPS
			if t >= rideAt - 0.2 then
				out.pace = math.max(out.pace, p)
			end
			-- (a jump: its place off where it was going, in the sub's frame, or in the world before the run)
			if wasSeen then
				local step = if t < rideAt then fish.Position - wasPos else o - wasRel
				if (t < rideAt or t > rideAt + 1.5 / FPS) and t < dropAt then
					out.jump = math.max(out.jump, (step - wasSeen).Magnitude)
				end
				wasSeen = step
			else
				out.start = (fish.Position - wasPos).Magnitude * FPS
				wasSeen = fish.Position - wasPos
			end
			if math.abs(t - rideAt) < 1.5 / FPS then
				wasSeen = o - wasRel
			end
			local turn = math.deg(math.acos(math.clamp(look:Dot(wasLook), -1, 1)))
			-- (not the frame the run begins: the sub's own nose goes onto the path, an old step of the trip)
			if turn > out.turn and t < dropAt and (t < rideAt or t > rideAt + 1.5 / FPS) then
				out.turn, out.turnAt = turn, t
			end
		end
		wasRel, wasLook, wasPos = o, look, fish.Position
		if math.abs(t - dropAt) < 0.5 / FPS then
			out.home = (o - V3.new(e.Side, o.Y, math.clamp(e.Half.Z - 12, 0, c.EscortKickLead))).Magnitude
		end
	end
	out.frame = if of > 0 then seen / of else 1
	out.view = if of > 0 then views / of else 1
	out.plain = if of > 0 then plain / of else 1
	out.sideView = if sides > 0 then sideSum / sides else 1
	return out
end

local csv = { "kind,size,tier,land,long,wide,high,loop,turns,ride,hullIn,hull,hullAt,wall,wallAt,gate,camera,cameraAt,frame,turn,turnAt,pace,home,left,right,floor,roof,inside,start,jump,view,plain,sideView,sx0,sx1,outX" }
local worst = {}
local function note(key, value, label, low)
	local w = worst[key]
	if not w or (if low then value < w[1] else value > w[1]) then
		worst[key] = { value, label }
	end
end
local function lists()
	return { hull = {}, wall = {}, gate = {}, camera = {}, frame = {}, turn = {}, home = {}, water = {}, jump = {}, plain = {} }
end
local bad, big, ends = lists(), lists(), lists()
local trips = 0
local only = process.args[4]
local part, of = string.match(only or "", "^(%d+)/(%d+)$")
local turn = 0
-- (from the middle of the lip, and with three of the subs from near either end of it, the gate's 96 wide)
local LIP = 30
for tier = 1, 9 do
	for _, land in if tier == 9 then { 10, 5, 2 } elseif tier == 1 then { 2 } else { tier + 1 } do
		local entries = {}
		for _, kind in kinds do
			for _, x in if tier == 1 or tier == 6 or (tier == 9 and land == 10) then { 0, -LIP, LIP } else { 0 } do
				table.insert(entries, { kind, x })
			end
		end
		for _, entry2 in entries do
			local kind, outX = entry2[1], entry2[2]
			if part then
				turn += 1
				if turn % tonumber(of) ~= tonumber(part) - 1 then
					continue
				end
			elseif only and kind.Id ~= only then
				continue
			end
			-- (a long fish's leap goes further out: 35 to 70 studs)
			local outZ = rows[1][4] + math.clamp(34 * math.sqrt(math.clamp(kind.Body.Z / 12, 0.75, 2)), 30, 70)
			local took, trip = dive(tier, land, kind, true, outX, outZ)
			if not took or not trip or not trip.Escort then
				ok(string.format("%s %s tier %d land %d gets its escort", kind.Id, kind.Size, tier, land), false)
				home()
				continue
			end
			trips += 1
			local m = measure(trip, tier, kind)
			local label = string.format("%s %s, sub %d to land %d", kind.Id, kind.Size, tier, land)
			table.insert(csv, string.format("%s,%s,%d,%d,%.0f,%.0f,%.0f,%s,%d,%.1f,%.1f,%.1f,%.2f,%.1f,%.2f,%.0f,%.1f,%.2f,%.2f,%.1f,%.2f,%.0f,%.2f,%.0f,%.0f,%.0f,%.0f,%.2f,%.0f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d",
				kind.Id, kind.Size, tier, land, kind.Body.Z, kind.Body.X, kind.Body.Y, tostring(m.loop), m.turns, m.ride, m.hullIn, m.hull, m.hullAt, m.wall, m.wallAt,
				m.gate, m.camera, m.cameraAt, m.frame, m.turn, m.turnAt, m.pace, m.home, m.left, m.right, m.floor, m.roof,
					m.inside, m.start, m.jump, m.view, m.plain, m.sideView, m.sx0, m.sx1, outX))
			-- (a Normal fish must clear everything. The Colossal are up to 200 long, 96 wide and 147 tall in a gate 96 wide
			-- with 46 of water: what they can't clear is listed, not failed)
			local list = if kind.Size ~= "Normal" then big elseif outX == 0 then bad else ends
			for key, isBad in
				{
					hull = math.min(m.hull, m.hullIn) < 0,
					wall = m.wall < 0,
					gate = m.gate < 0,
					camera = m.camera < 5,
					frame = m.frame < 0.95,
					turn = m.turn > 15,
					jump = m.jump > 3,
					plain = hullCells ~= nil and m.plain < 0.5,
					home = m.home > 0.5,
					water = m.floor < 0 or m.roof < 0,
				}
			do
				if isBad then
					table.insert(list[key], label)
				end
			end
			note("hull", m.hull, label, true)
			note("hullIn", m.hullIn, label, true)
			note("wall", m.wall, label, true)
			note("gate", m.gate, label, true)
			note("camera", m.camera, label, true)
			note("frame", m.frame, label, true)
			note("turn", m.turn, label)
			note("pace", m.pace, label)
			note("home", m.home, label)
			home()
		end
	end
end
print(string.format("%d trips (%d kinds, two sizes)", trips, #kinds / 2))
for key, w in worst do
	print(string.format("  worst %-7s %8.2f  %s", key, w[1], w[2]))
end
local NAMES = {
	hull = "clear of the hull all the way",
	wall = "clear of the lane's sides",
	gate = "out of the gate by the hop",
	camera = "five studs or more off the camera's line",
	frame = "in the picture all the weave",
	turn = "never turns over 15 degrees in a frame",
	home = "in its place for the kick",
	jump = "never jumps (a frame's move within 3 studs of the frame's before)",
}
for key, name in NAMES do
	local list = bad[key]
	ok(string.format("Normal: %s (%d not)", name, #list), #list == 0, table.concat(list, "; ", 1, math.min(3, #list)))
end
ok(
	string.format("Normal, from the lip's ends: clear of the hull, no jumps (%d not)", #ends.hull + #ends.jump),
	#ends.hull + #ends.jump == 0,
	table.concat(ends.hull, "; ")
)
ok(
	"Colossal: in the picture, in its place for the kick, off the camera's line, out of the gate, no jumps",
	#big.frame + #big.home + #big.camera + #big.gate + #big.jump == 0
)
-- (not failed, and not met: read these with the passes)
print(string.format("  EXCEPTION Colossal, into the hull's box: %d, the nearest %.1f", #big.hull, worst.hull[1]))
print(string.format("  EXCEPTION into the lane's sides: Normal from the lip's ends %d, Colossal %d", #ends.wall, #big.wall))
print(string.format("  EXCEPTION taller than the water: Normal %d, Colossal %d", #bad.water + #ends.water, #big.water))
print(string.format("  EXCEPTION Normal, a third of it in view for less than half the weave: %d", #bad.plain + #ends.plain))
if process.args[3] then
	fs.writeFile(process.args[3], table.concat(csv, "\n") .. "\n")
end

----------------------------------------------------------------------------------------------------------------------
-- The server's rules

local clown = fishOf("Clownfish", "Normal")
local OUT = rows[1][4] + 34
local function alive()
	local n = 0
	for _, w in spawned do
		if w.Model.Parent and not w.Rider then
			n += 1
		end
	end
	return n
end
local function fresh()
	home()
	for _, w in spawned do
		w.Model.Parent = nil
	end
	table.clear(spawned)
	table.clear(told)
	flung, seated, discarded = 0, 0, 0
end
local function run(until_, each)
	local trip = SubTrip.decode(attrs.SubTrip)
	while clock - trip.Start < until_(trip) and attrs.SubTrip do
		beat(1 / 60)
		if each then
			each(trip, clock - trip.Start)
		end
	end
end

fresh()
local _, trip = dive(4, 5, nil, false, 0, OUT)
ok("no fish: no escort, nothing spawned", trip and not trip.Escort and #spawned == 0 and not trip.Fish and attrs.SubPhase == "Approach")
run(function(tr)
	local _, _, _, drop = SubTrip.times(tr)
	return drop + 0.2
end)
ok("no fish: the fling", flung == 1 and seated == 0)

fresh()
_, trip = dive(4, 5, clown, false, 0, OUT)
ok("equipped, on foot: no escort, it swims up at the end as before", trip and not trip.Escort and trip.Fish and #spawned == 0)
run(function(tr)
	local _, _, _, drop = SubTrip.times(tr)
	return drop - 0.5
end)
ok("equipped, on foot: one fish, made late", #spawned == 1)

fresh()
_, trip = dive(4, 5, clown, true, 0, OUT)
ok("mounted: the escort, one fish, anchored, the saddle pose", trip and trip.Escort and #spawned == 1 and spawned[1].Root.Anchored and attrs.SubPhase == "Saddle")
local w = spawned[1]
ok("its saddle is where the rider was", (w.Root.CFrame * w.Saddle.Position - entry).Magnitude < 0.01)
local writes, last = 0, w.Root.CFrame
run(function(tr)
	local _, _, arrive = SubTrip.times(tr)
	return arrive - 0.05
end, function()
	if w.Root.CFrame ~= last then
		writes += 1
		last = w.Root.CFrame
	end
end)
ok("the server moves it once before Arrive (no traffic)", writes == 1 and w.Root.Anchored, writes)
run(function(tr)
	local _, _, _, drop = SubTrip.times(tr)
	return drop + 0.1
end)
ok("let go of at Arrive, the kick cued with the same fish, never a second", not w.Root.Anchored and #spawned == 1 and told[#told][1] == "SubDrop" and told[#told][2] == "Kick" and told[#told][3] == w.Model)
ok("where the trip has it as it is let go", (w.Root.Position - entry).Magnitude > 1000)
run(function(tr)
	local _, _, _, drop = SubTrip.times(tr)
	return drop + tr.DropTime + c.Late + 0.2
end)
ok("no word from the machine: seated on it anyway, nothing left over", seated == 1 and w.Rider == player and alive() == 0)
ok("the round trip of the JSON keeps the escort", (function()
	local a2 = trip.Escort
	local again = SubTrip.decode(SubTrip.encode(trip)).Escort
	return again and (again.Half - a2.Half).Magnitude < 0.01 and again.Turns == a2.Turns and again.Right == a2.Right and again.Left == a2.Left and math.abs(again.Low - a2.Low) < 0.01
end)())

for _, when in { 0.4, 1.5, 4 } do
	fresh()
	_, trip = dive(4, 5, clown, true, 0, OUT)
	run(function()
		return when
	end)
	equipped = nil -- (unequipped, or gone from the hands)
	beat(1 / 60)
	ok(string.format("unequipped at %.1f s: the copy is told to leave", when), spawned[1].Model:GetAttribute("SubLeave") ~= nil)
	run(function(tr)
		local _, _, _, drop = SubTrip.times(tr)
		return drop + 0.1
	end)
	ok("  and is gone, never replaced, the fling instead", #spawned == 1 and alive() == 0 and flung == 1 and seated == 0)
end

fresh()
dive(4, 5, clown, true, 0, OUT)
run(function()
	return 2.5
end)
equipped = { Id = clown.Id, Size = clown.Size, Variant = "" } -- (another fish of the very same kind)
beat(1 / 60)
ok("another fish equipped in its place counts as unequipped", spawned[1].Model:GetAttribute("SubLeave") ~= nil)

fresh()
dive(4, 5, clown, true, 0, OUT)
run(function()
	return 2.5
end)
state = "Dock" -- (died, or reset)
beat(1 / 60)
ok("died or reset in the middle: the copy is gone, the trip over", alive() == 0 and attrs.SubTrip == nil and equipped ~= nil)

fresh()
dive(4, 5, clown, true, 0, OUT)
removing.fire(player)
ok("left in the middle: the copy is gone", alive() == 0)
added.fire(player)

fresh()
local held = FishService.streamPoint
FishService.streamPoint = function()
	error("made to fail")
end
local took = dive(4, 5, clown, true, 0, OUT)
FishService.streamPoint = held
ok("a trip that can't be made leaves no fish", took == false and alive() == 0)

fresh()
Config.Sub.Escort = 0
_, trip = dive(4, 5, clown, true, 0, OUT)
ok("Sub.Escort 0: as it was", trip and not trip.Escort and trip.Fish and #spawned == 0)
Config.Sub.Escort = 1
done()
