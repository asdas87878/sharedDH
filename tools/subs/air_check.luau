-- The air hop (docs/design/submarine.md, "The air hop"), checked without Studio: the part of tools/subs/escort_check.luau
-- that a build with Config.Sub.AirHop runs in the old hop's place (it makes the world; its head says how). The leaps are
-- the dive's own (tools/subs/air_leaps.luau: every kind at every size, along the lip and slanted), each told to the real
-- SubService as the rider's machine tells it, with each of the nine subs; the trip is read back as the clients read it.
-- Every frame, 60 a second, from the leap's start until the fish is beside the sub:
--   hull     the fish's box against the hull's box, as turned, studs (under 0 they overlap): before the fish's own splash,
--            and after it (joining). cells: seconds one of the sub's own cells is in the fish's box
--   boxes    seconds the sub's cells are in a box of the map (tools/dive/lip_boxes.py: the gate, the hub, the cove's sides),
--            while it is in sight; the same for the rider (a point) in the hop, and the camera
--   lane     the sub's corners and the fish's box inside the lane's sides (an estimate, as in escort_check), the fish off the
--            floor
--   water    how often the sub's middle goes through the surface (once, down), when, how steep
--   camera   off the rider's line to the side; the most its move and its turn change from one frame to the next; seconds in
--            the sub, the fish, a box; seconds the sub or the fish is between it and the rider; the rider in the picture
--   rider    the most their move changes from one frame to the next (the push off and the landing left out), how far off
--            the seat they are as they land, seconds in the sub's cells on the way
--            (over 80 studs behind the sub, out of the rider's sight: farJump, not judged)
--   fish     how far from the dive's own pose it is until the jump (so the swap can't be seen), then the most its move and
--            heading change in a frame, over its splash and as it comes up beside the sub, into the sweeps
--   time     the jump to the seat, the lip to the splash, the lip to the run
-- and then the run with the fish beside the sub (escort_check's own numbers), and the server's rules.
-- usage: lune run tools/subs/escort_check.luau . place.rbxl out.csv 3/11 cells.json leaps.json lip.json
--   ("3/11": a part of all of them; "rules": the server's rules alone; a kind's Id: that one)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local V3, CF = roblox.Vector3, roblox.CFrame
local UP = V3.new(0, 1, 0)
local FPS = 60

return function(x)
	local Config, SubTrip, SubAir = x.Config, x.SubTrip, x.SubAir
	local ok, c = x.ok, Config.Sub
	local Ease = x.world.require(x.world.find("ReplicatedStorage.Shared.Ease"))
	local which = x.args.which or "1/1"
	local part, of = string.match(which, "^(%d+)/(%d+)$")
	part, of = tonumber(part), tonumber(of)
	local leaps = serde.decode("json", fs.readFile(x.args.leaps))

	------------------------------------------------------------------------------------------------------------------
	-- The map's boxes by where they are along the lane, and the sub's cells

	local bins = {}
	do
		for _, b in serde.decode("json", fs.readFile(x.args.boxes)).boxes do
			local reach = {}
			for i = 1, 3 do
				reach[i] = (math.abs(b.x[i]) * b.s[1] + math.abs(b.y[i]) * b.s[2] + math.abs(b.z[i]) * b.s[3]) / 2
			end
			if math.abs(b.p[1]) - reach[1] > 75 or b.p[2] + reach[2] < 1 or b.k == "barrier" then
				continue -- (out of any sub's way; the lane under water is checked by its sides)
			end
			local box = {
				Name = b.n,
				CF = CF.fromMatrix(
					V3.new(b.p[1] + x.X0, b.p[2], b.p[3]),
					V3.new(b.x[1], b.x[2], b.x[3]),
					V3.new(b.y[1], b.y[2], b.y[3]),
					V3.new(b.z[1], b.z[2], b.z[3])
				),
				Half = V3.new(b.s[1], b.s[2], b.s[3]) / 2,
				At = V3.new(b.p[1] + x.X0, b.p[2], b.p[3]),
				Reach = reach,
			}
			for i = math.floor((b.p[3] - reach[3]) / 20), math.floor((b.p[3] + reach[3]) / 20) do
				bins[i] = bins[i] or {}
				table.insert(bins[i], box)
			end
		end
	end
	local function near(at, room, each)
		local seen = {}
		for i = math.floor((at.Z - room) / 20), math.floor((at.Z + room) / 20) do
			for _, box in bins[i] or {} do
				if
					not seen[box]
					and math.abs(at.X - box.At.X) < box.Reach[1] + room
					and math.abs(at.Y - box.At.Y) < box.Reach[2] + room
				then
					seen[box] = true
					if each(box) then
						return true
					end
				end
			end
		end
		return false
	end
	local function inBox(cf, half, p, room)
		local o = cf:PointToObjectSpace(p)
		return math.abs(o.X) < half.X + room and math.abs(o.Y) < half.Y + room and math.abs(o.Z) < half.Z + room
	end
	local function boxAt(p, room)
		local name = nil
		near(p, room, function(box)
			if inBox(box.CF, box.Half, p, room) then
				name = box.Name
				return true
			end
			return false
		end)
		return name
	end
	local cellLists = {} -- the cells' middles, in the hull's frame
	for tier, list in serde.decode("json", fs.readFile(x.args.cells)).Subs do
		local out = {}
		for _, key in list do
			local a, b, d = string.match(key, "(-?%d+),(-?%d+),(-?%d+)")
			table.insert(out, V3.new(tonumber(a) + 0.5, tonumber(b) + 0.5, tonumber(d) + 0.5) * x.hullCells.Cell)
		end
		cellLists[tier] = out
	end
	local function cellsIn(tier, sub, cf, half)
		local rel = cf:Inverse() * sub
		for _, p in cellLists[tier] do
			local o = rel * p
			if math.abs(o.X) < half.X and math.abs(o.Y) < half.Y and math.abs(o.Z) < half.Z then
				return true
			end
		end
		return false
	end
	local function inCells(tier, sub, p)
		local set, o = x.hullCells[tier], sub:PointToObjectSpace(p) / x.hullCells.Cell
		return set[(math.floor(o.X) + 128) * 65536 + (math.floor(o.Y) + 128) * 256 + math.floor(o.Z) + 128] == true
	end
	-- the sub's cells at a point, but for those round the seat itself (the rider sits in them)
	local SEAT = SubAir.Seat.Position
	local function inHull(tier, sub, p)
		return (sub:PointToObjectSpace(p) - SEAT).Magnitude > 5 and inCells(tier, sub, p)
	end
	-- is the rider out of sight behind the sub? (their head and their middle both, to 4 studs of them)
	local function hid(tier, sub, eye, at)
		for _, p in { at + UP * 2.5, at + UP * 0.5 } do
			if not x.hidden(tier, sub, eye, p + (eye - p).Unit * 4) then
				return false
			end
		end
		return true
	end
	local function lineIn(cf, half, a, b)
		for i = 0, 12 do
			if inBox(cf, half, a:Lerp(b, i / 12), 0) then
				return true
			end
		end
		return false
	end

	------------------------------------------------------------------------------------------------------------------
	-- A leap told to the server

	for _, f in Config.Fish do
		for _, tier in { "Tiny", "Big", "Giant", "Huge" } do
			local base = x.fishOf(f.Id, "Normal")
			local scale = Config.sizeScale(tier, f) / Config.sizeScale("Normal", f)
			table.insert(x.kinds, {
				Id = f.Id,
				Size = tier,
				Body = base.Body * scale,
				Saddle = (base.Saddle - V3.new(0, Config.Ride.SeatHeight, 0)) * scale + V3.new(0, Config.Ride.SeatHeight, 0),
			})
		end
	end
	local function leapOf(row, start)
		return {
			Take = V3.new(row.take[1] + x.X0, row.take[2], row.take[3]),
			Heading = V3.new(row.heading[1], 0, row.heading[2]),
			Far = row.far,
			Rise = row.a,
			Fall = row.c,
			Crouch = row.crouch,
			Time = row.air,
			Tilts = row.tilts,
			Start = start,
		}
	end
	local function ready(row, tier, land)
		x.set({
			state = "Dock",
			onLand = true,
			health = 100,
			equipped = { Id = row.id, Size = row.tier, Variant = "" },
			entry = V3.new(row.start[1] + x.X0, row.start[2], row.start[3]),
		})
		x.SubService.setSub(x.player, 9, tier)
		x.beat(1 / 60)
		x.actions.fire(x.player, "SubPick", land, "")
	end
	local function leap(row, tier, land, late)
		ready(row, tier, land)
		x.actions.fire(x.player, "SubLeap", leapOf(row, x.clock() - (late or 0)))
		local json = x.attrs.SubTrip
		return if json then SubTrip.decode(json) else nil, json
	end
	-- the dive's own pose of a leap, row.poses: the root at nine moments of the arc
	local function divePose(row, i)
		local p = row.poses[i]
		local at = V3.new(p[1] + x.X0, p[2], p[3])
		return CF.lookAt(at, at + V3.new(p[4], p[5], p[6]))
	end

	------------------------------------------------------------------------------------------------------------------
	-- The flight, frame by frame

	local FIELDS = {
		"hop", "splash", "run", "hull", "join", "cells", "subBox", "riderBox", "camBox", "lane", "fishLane", "floor",
		"surface", "nose", "side", "camJump", "camTurn", "camSub", "camFish", "hidSub", "hidSeat", "hidFish", "riderOut", "riderJump",
		"seatOff", "riderIn", "swap", "swapTurn", "fishJump", "fishOver", "farJump", "jumpAt", "fishTurn", "splashJump", "over", "rise", "apart", "behind",
	}
	local traced = process.env.AIR_TRACE -- ("Giant,5,0,0": the size, the sub, x and the slant to print frame by frame)
	local function flight(trip, tier, row)
		local trace = row.crouched and traced == string.format("%s,%d,%d,%d", row.tier, tier, row.x, row.slant)
		local air, e = trip.Air, trip.Escort
		local _, rideAt = SubTrip.times(trip)
		local entry = SubAir.entry(air)
		local joined = entry + SubAir.joining(e.Half)
		local hull = SubTrip.Hulls[tier]
		local hullHalf = V3.new(hull[1], (hull[2] + hull[3]) / 2, (hull[4] + hull[5]) / 2)
		local hullAt = CF.new(0, (hull[2] - hull[3]) / 2, (hull[5] - hull[4]) / 2)
		local m = { where = {} }
		for _, f in FIELDS do
			m[f] = 0
		end
		m.hull, m.join, m.lane, m.fishLane, m.floor, m.behind = 1e3, 1e3, 1e3, 1e3, 1e3, 1e3
		m.hop = air.SeatAt - air.HopAt
		m.splash = air.SplashAt - air.Leap.Crouch
		m.run = rideAt - air.Leap.Crouch
		m.over = if air.Over then 1 else 0
		m.rise = air.Meet.Y
		m.apart = (SubAir.middle(air, air.SplashAt) - SubAir.fish(air, entry).Position):Dot(air.Out)
		-- (the dive's own poses, until the jump)
		for i = 1, #row.poses do
			local t = row.crouch + row.air * (i - 1) / (#row.poses - 1)
			if t <= air.HopAt + 0.05 then
				-- (the poses are the rider's root's: the saddle)
				local a, b = SubAir.fish(air, t) * CF.new(e.Saddle), divePose(row, i)
				-- (the dip as the rider pushes off is the hop's own)
				a += UP * (if t > air.HopAt then b.Position.Y - a.Position.Y else 0)
				m.swap = math.max(m.swap, (a.Position - b.Position).Magnitude)
				m.swapTurn = math.max(m.swapTurn, math.deg(math.acos(math.clamp(a.LookVector:Dot(b.LookVector), -1, 1))))
			end
		end
		local mem = {}
		local last = {}
		local subNear, fishNear = nil, nil
		local crossings, wasY = 0, nil
		local from0 = V3.new(row.cam[1] + x.X0, row.cam[2], row.cam[3]) - V3.new(row.start[1] + x.X0, row.start[2], row.start[3])
		for k = 0, math.ceil((joined + 0.35) * FPS) do
			local t = k / FPS
			local sub, speed = SubTrip.sub(trip, t)
			local fish = SubTrip.escort(trip, t)
			local onSub = t >= rideAt
			local rider = if onSub then sub * SubTrip.Seat else SubAir.rider(air, t)
			-- the fish and the hull
			local inSight = t >= air.SeatAt - 1 and (air.Meet - SubAir.middle(air, math.min(t, air.SeatAt))).Magnitude <= c.AirFrom
			local gap = if inSight then x.boxGap(fish, e.Half, sub * hullAt, hullHalf) else 1e3
			if t <= entry then
				m.hull = math.min(m.hull, gap)
			else
				m.join = math.min(m.join, gap)
			end
			if gap < 0 and cellsIn(tier, sub, fish, e.Half) then
				m.cells += 1 / FPS
			end
			-- the sub and the map
			if inSight and t <= air.SplashAt then
				local middle = (sub * hullAt).Position
				if
					near(middle, hullHalf.Magnitude, function(box)
						if
							SubAir.meets(sub * hullAt, hullHalf, box.CF, box.Half)
							and cellsIn(tier, sub, box.CF, box.Half)
						then
							m.where[box.Name] = true
							return true
						end
						return false
					end)
				then
					m.subBox += 1 / FPS
				end
			end
			-- the lane: from the gate on, the sub's corners; after its splash the fish
			if t >= air.SplashAt and sub.Position.Z > x.rows[1][4] then
				for _, corner in { { -1, -hull[4] }, { 1, -hull[4] }, { -1, hull[5] }, { 1, hull[5] } } do
					local p = (sub * CF.new(corner[1] * hull[1], 0, corner[2])).Position
					subNear = x.streamS(p, if onSub then subNear else nil)
					local off = (p - x.streamPoint(subNear, 0, 0)):Dot(x.wayAt(subNear):Cross(UP))
					local l, r = x.roomAt(subNear)
					m.lane = math.min(m.lane, l + off, r - off)
				end
			end
			if t > entry then
				for _, z in { -e.Half.Z, 0, e.Half.Z } do
					local p = (fish * CF.new(0, 0, z)).Position
					local s = x.streamS(p, if onSub then fishNear else nil)
					fishNear = s
					local g
					if s <= 1 then
						g = x.rows[1][5] / 2 - math.abs(p.X - x.X0) - e.Half.X
					else
						local off = (p - x.streamPoint(s, 0, 0)):Dot(x.wayAt(s):Cross(UP))
						local l, r = x.roomAt(s)
						g = math.min(l + off, r - off) - e.Half.X
					end
					m.fishLane = math.min(m.fishLane, g)
					if z == 0 then
						m.floor = math.min(m.floor, p.Y - e.Half.Y - x.streamPoint(s, 0, -1e4).Y)
					end
				end
			end
			-- the water
			if wasY and (wasY > 0) ~= (sub.Position.Y > 0) then
				crossings += 1
				m.surface = t
				m.nose = -math.deg(math.asin(sub.LookVector.Y))
			end
			wasY = sub.Position.Y
			-- the camera
			local eye, look, fov
			if not onSub then
				eye, look = SubAir.eye(air, t)
				fov = 70
				local w = Ease.smoothstep(0, c.AirCamIn, t)
				if w < 1 then
					local a, b = from0, eye - rider.Position
					local turn = Ease.lerpAngle(math.atan2(a.X, a.Z), math.atan2(b.X, b.Z), w)
					local far = Ease.lerp(V3.new(a.X, 0, a.Z).Magnitude, V3.new(b.X, 0, b.Z).Magnitude, w)
					eye = rider.Position + V3.new(math.sin(turn) * far, Ease.lerp(a.Y, b.Y, w), math.cos(turn) * far)
				end
				mem.kind, mem.anchor, mem.pos, mem.focus, mem.fov = "sub", sub.Position, eye - sub.Position, look - sub.Position, 74
			else
				eye, look, fov = x.cameraOf(trip, t, sub, speed, rider.Position, mem)
			end
			local dir = (look - eye).Unit
			local settled = t >= c.AirCamIn
			if settled then
				local across = air.Out:Cross(UP)
				if t <= air.SeatAt then
					m.side = math.max(m.side, math.abs((eye - rider.Position):Dot(across)))
					m.behind = math.min(m.behind, (rider.Position - eye):Dot(air.Out))
				elseif not onSub and t >= air.SplashAt then
					m.behind = math.min(m.behind, (sub.Position - eye):Dot(air.Out))
				end
				if inSight and x.pointGap(sub * hullAt, hullHalf, eye) <= 0 and inCells(tier, sub, eye) then
					m.camSub += 1 / FPS
				end
				if x.pointGap(fish, e.Half, eye) <= 0 then
					m.camFish += 1 / FPS
				end
				local head = rider.Position + UP
				if k % 2 == 0 and not onSub then
					if inSight and hid(tier, sub, eye, rider.Position) then
						if t <= air.SeatAt then
							m.hidSub += 2 / FPS
						elseif not hid(tier, sub, sub * V3.new(0, 9, 37), (sub * SubTrip.Seat).Position) then
							-- (two subs hide a seated rider from the run's own camera, always have: not the hop's)
							m.hidSeat += 2 / FPS
						end
					end
					if lineIn(fish, e.Half * 0.8, eye, head + UP) then
						m.hidFish += 2 / FPS
					end
					if lineIn(CF.new(), V3.zero, eye, head) == false then
						local behind = false
						for i = 1, 9 do
							behind = behind or boxAt(eye:Lerp(head, i / 10), 0) ~= nil
						end
						if behind then
							m.camBox += 2 / FPS
							m.where.camera = boxAt(eye, 0.5) or "between"
						end
					end
				end
				if not onSub then
					local o = CF.lookAt(eye, look):PointToObjectSpace(head)
					local tall = math.tan(math.rad(fov / 2))
					if o.Z > -1 or math.abs(o.Y / o.Z) > tall or math.abs(o.X / o.Z) > tall * 16 / 9 then
						m.riderOut += 1 / FPS
					end
				end
				-- (the rush of the run itself is the sub's: from there, against the sub)
				local step = if last.eye then (if onSub then (eye - sub.Position) - last.eyeRel else eye - last.eye) else nil
				if step and last.camStep and last.onSub == onSub then
					m.camJump = math.max(m.camJump, (step - last.camStep).Magnitude)
				end
				if last.dir then
					m.camTurn = math.max(m.camTurn, math.deg(math.acos(math.clamp(dir:Dot(last.dir), -1, 1))))
				end
				last.camStep = step
			end
			-- the rider
			if t < rideAt then
				local step = if last.rider then rider.Position - last.rider else nil
				local push = math.abs(t - air.HopAt) < 2.1 / FPS or math.abs(t - air.SeatAt) < 2.1 / FPS
				if step and last.riderStep and not push then
					m.riderJump = math.max(m.riderJump, (step - last.riderStep).Magnitude)
				end
				last.riderStep = step
				if t > air.HopAt and t < air.SeatAt - 0.05 then
					if inHull(tier, sub, rider.Position) or inHull(tier, sub, rider.Position - UP * 2) then
						m.riderIn += 1 / FPS
					end
				end
				if t > air.HopAt and boxAt(rider.Position, 1.5) then
					m.riderBox += 1 / FPS
				end
			end
			-- the fish: its move and its turn, frame to frame (in the world; nearly beside the sub, against the sub)
			local rel = sub:PointToObjectSpace(fish.Position)
			if last.fish then
				local step, relStep = fish.Position - last.fish, rel - last.rel
				if last.fishStep then
					local jump = math.min((step - last.fishStep).Magnitude, (relStep - last.relStep).Magnitude)
					if math.abs(t - entry) < 2.5 / FPS then
						m.splashJump = math.max(m.splashJump, jump)
					end
					if math.abs(t - rideAt) > 2.5 / FPS then
						local key = if t > entry and rel.Z > 80 then "farJump" else "fishJump"
						if key == "fishJump" then
							-- (at thousands of studs a second: against a twelfth of what the sub itself moves in a frame)
							m.fishOver = math.max(m.fishOver, jump / math.max(1, speed / FPS / 12))
						end
						if jump > m[key] then
							m[key] = jump
							m.jumpAt = t - entry
						end
					end
				end
				last.fishStep, last.relStep = step, relStep
				m.fishTurn = math.max(m.fishTurn, math.deg(math.acos(math.clamp(fish.LookVector:Dot(last.fishLook), -1, 1))))
			end
			if trace then
				local jumps = string.format("cam %5.2f turn %5.2f pass %.2f seat %.2f splash %.2f ride %.2f entry %.2f", if last.camStep and last.camWas then (last.camStep - last.camWas).Magnitude else 0, if last.dirWas and last.dir then math.deg(math.acos(math.clamp(dir:Dot(last.dirWas), -1, 1))) else 0, air.Eye.Pass, air.SeatAt, air.SplashAt, rideAt, entry)
				print(string.format("%5.3f sub %7.1f %6.1f %7.1f v%6.0f | rider %6.1f %6.1f %7.1f | eye %6.1f %6.1f %7.1f | fish %6.1f %6.1f %7.1f look %5.2f %5.2f %5.2f gap %6.1f | %s %s",
					t, sub.X - x.X0, sub.Y, sub.Z, speed, rider.X - x.X0, rider.Y, rider.Z, eye.X - x.X0, eye.Y, eye.Z, fish.X - x.X0, fish.Y, fish.Z,
					fish.LookVector.X, fish.LookVector.Y, fish.LookVector.Z, gap, jumps,
					(if t > air.HopAt and inHull(tier, sub, rider.Position) then "INCELL " else "") .. (if inHull(tier, sub, rider.Position - UP * 2) then "FEET " else "") .. (if not onSub and hid(tier, sub, eye, rider.Position) then "HID" else "")))
			end
			last.camWas, last.dirWas = last.camStep, dir
			last.fish, last.rel, last.fishLook = fish.Position, rel, fish.LookVector
			last.eye, last.eyeRel, last.dir, last.rider, last.onSub = eye, eye - sub.Position, dir, rider.Position, onSub
		end
		m.crossings = crossings
		m.seatOff = (SubAir.rider(air, air.SeatAt).Position - (SubTrip.sub(trip, air.SeatAt) * SubTrip.Seat).Position).Magnitude
		return m
	end

	------------------------------------------------------------------------------------------------------------------
	-- Every leap with every sub

	-- what fails: more (or less) than this
	local LIMITS = {
		{ "hop", "from the saddle to the seat in 0.6 s", function(m) return m.hop > 0.605 end },
		{ "splash", "from the lip to the splash in 2.1 s (asked: 1.3 to 1.6)", function(m) return m.splash > 2.1 end },
		{ "run", "from the lip to the run in 3 s", function(m) return m.run > 3 end },
		{ "hull", "the fish clear of the hull until its splash", function(m) return m.hull < 0 and m.cells > 0 end },
		{ "join", "and as it swims up beside the sub", function(m) return m.join < 0 and m.cells > 0 end },
		{ "subBox", "the sub clear of the gate and the map", function(m) return m.subBox > 0 end },
		{ "riderBox", "the rider clear of the gate and the map in the hop", function(m) return m.riderBox > 0 end },
		{ "lane", "the sub inside the lane", function(m) return m.lane < 0 end },
		{ "water", "through the surface once, nose first", function(m) return m.crossings ~= 1 or m.nose < 15 end },
		{ "side", "the camera on the rider's line", function(m) return m.side > 0.05 end },
		{ "behind", "and behind them", function(m) return m.behind < 10 end },
		{ "camJump", "the camera never jumps (a frame's move within 2.5 studs of the last's)", function(m) return m.camJump > 2.5 end },
		{ "camTurn", "nor turns over 6 degrees in a frame", function(m) return m.camTurn > 6 end },
		{ "camSub", "the camera out of the sub", function(m) return m.camSub > 0 end },
		{ "camFish", "and of the fish (0.1 s of it at most)", function(m) return m.camFish > 0.1 end },
		{ "hidSub", "the sub between it and the rider 0.3 s of the hop at most", function(m) return m.hidSub > 0.3 end },
		{ "hidSeat", "and 0.3 s of the fall (where the run's own camera would see them)", function(m) return m.hidSeat > 0.3 end },
		{ "camBox", "the gate or the map 0.4 s at most", function(m) return m.camBox > 0.4 end },
		{ "riderOut", "the rider in the picture (all but 0.1 s)", function(m) return m.riderOut > 0.1 end },
		{ "riderJump", "the rider never jumps (a frame's move within 2.5 studs of the last's)", function(m) return m.riderJump > 2.5 end },
		{ "seatOff", "they land on the seat", function(m) return m.seatOff > 0.1 end },
		{ "riderIn", "never through the sub on the way (0.1 s of it, as it sweeps by)", function(m) return m.riderIn > 0.1 end },
		{ "swap", "the trip's fish is where the dive's is, within 0.5 studs and 3 degrees", function(m) return m.swap > 0.5 or m.swapTurn > 3 end },
		{ "fishOver", "the fish never jumps (a frame's move within 3 studs of the last's, or a quarter of the sub's own)", function(m) return m.fishOver > 3 end },
		{ "fishTurn", "nor turns over 12 degrees in a frame", function(m) return m.fishTurn > 12 end },
	}
	local function alike(a, b)
		if type(a) ~= "table" or type(b) ~= "table" then
			return if type(a) == "number" and type(b) == "number" then math.abs(a - b) < 1e-3
				elseif type(a) == "userdata" and type(b) == "userdata" then (a - b).Magnitude < 1e-2
				else a == b
		end
		for k, v in a do
			if not alike(v, b[k]) then
				return false
			end
		end
		for k in b do
			if a[k] == nil then
				return false
			end
		end
		return true
	end
	local csv = { "kind,size,tier,x,slant,crouched," .. table.concat(FIELDS, ",") .. ",where" }
	local lists, stats, none, total = {}, {}, {}, 0
	local coded = 0
	if which ~= "rules" then
		local turn = 0
		for _, row in leaps do
			for tier = 1, 9 do
				turn += 1
				if traced and traced ~= string.format("%s,%d,%d,%d", row.tier, tier, row.x, row.slant) then
					continue
				end
				if of and turn % of ~= part - 1 or not of and row.id ~= which then
					continue
				end
				local land = math.min(tier + 1, 10)
				local trip, json = leap(row, tier, land)
				local label = string.format("%s %s sub %d x%d slant %d%s", row.id, row.tier, tier, row.x, row.slant, if row.crouched then "" else " uncrouched")
				total += 1
				if not trip or not trip.Air then
					table.insert(none, label)
					x.home()
					continue
				end
				-- (what the clients read is what the server has, and written again the same)
				if not alike(SubTrip.decode(SubTrip.encode(trip)), trip) then
					coded += 1
				end
				local m = flight(trip, tier, row)
				for _, limit in LIMITS do
					if limit[3](m) then
						lists[limit[1]] = lists[limit[1]] or {}
						table.insert(lists[limit[1]], label)
					end
				end
				local cells = { row.id, row.tier, tier, row.x, row.slant, tostring(row.crouched) }
				for _, f in FIELDS do
					table.insert(cells, string.format("%.3f", m[f]))
					local key = row.tier .. " " .. f
					stats[key] = stats[key] or {}
					table.insert(stats[key], m[f])
				end
				local where = {}
				for name in m.where do
					table.insert(where, if name == "camera" then "camera:" .. m.where.camera else name)
				end
				table.insert(cells, table.concat(where, "+"))
				table.insert(csv, table.concat(cells, ","))
				x.home()
			end
		end
		print(string.format("%d leaps told, %d got no air hop", total, #none))
		for _, name in none do
			print("  NONE " .. name)
		end
		for _, limit in LIMITS do
			local list = lists[limit[1]] or {}
			print(string.format("COUNT %s %d %d", limit[1], #list, total))
			ok(string.format("%s (%d of %d not)", limit[2], #list, total), #list == 0, table.concat(list, "; ", 1, math.min(3, #list)))
		end
		ok("the trip's text says all of it (written, read, written the same)", coded == 0, coded)
		if x.args.csv then
			fs.writeFile(x.args.csv, table.concat(csv, "\n") .. "\n")
		end
	end

	------------------------------------------------------------------------------------------------------------------
	-- The run, the fish beside the sub: escort_check's own numbers from where the fish has come up to it

	if which ~= "rules" then
		local runs = { hull = {}, wall = {}, camera = {}, frame = {}, turn = {}, jump = {}, home = {}, water = {}, plain = {}, sub = {} }
		local turn, count = 0, 0
		for tier = 1, 9 do
			for _, land in if tier == 9 then { 10, 5, 2 } elseif tier == 1 then { 2 } else { tier + 1 } do
				for _, row in leaps do
					if row.x ~= 0 or row.slant ~= 0 or not row.crouched or (row.tier ~= "Normal" and row.tier ~= "Colossal") then
						continue
					end
					turn += 1
					if of and turn % of ~= part - 1 or not of and row.id ~= which then
						continue
					end
					local trip = leap(row, tier, land)
					if not trip or not trip.Air then
						x.home()
						continue
					end
					count += 1
					local m = x.measure(trip, tier, nil)
					local label = string.format("%s %s, sub %d to land %d", row.id, row.tier, tier, land)
					local e = trip.Escort
					local noRoom = not e.Right and not e.Left
					for key, isBad in
						{
							hull = m.hull < 0,
							wall = m.wall < 0,
							sub = m.subRun < 0,
							camera = m.camera < 5,
							frame = m.frame < 0.95,
							turn = m.turn > 12,
							jump = m.jump > 3,
							home = m.home > 0.5,
							water = m.floor < 0 or m.roof < 0,
							plain = not noRoom and m.turns > 0 and m.plain < 0.5,
						}
					do
						if isBad then
							table.insert(runs[key], { label, row.tier })
						end
					end
					x.home()
				end
			end
		end
		print(string.format("%d runs", count))
		for key, list in runs do
			local names, normal = {}, 0
			for _, one in list do
				normal += if one[2] == "Normal" then 1 else 0
				table.insert(names, one[1])
			end
			print(string.format("RUN %s %d Normal %d Colossal of %d: %s", key, normal, #list - normal, count, table.concat(names, "; ", 1, math.min(4, #names))))
		end
	end

	------------------------------------------------------------------------------------------------------------------
	-- The server's rules

	if which ~= "rules" and part ~= 1 then
		return
	end
	local row = nil
	for _, r in leaps do
		if r.id == "Clownfish" and r.tier == "Normal" and r.x == 0 and r.slant == 0 and r.crouched then
			row = r
		end
	end
	local function alive()
		local n = 0
		for _, w in x.spawned do
			if w.Model.Parent and not w.Rider then
				n += 1
			end
		end
		return n
	end
	local function fresh()
		x.home()
		for _, w in x.spawned do
			w.Model.Parent = nil
		end
		table.clear(x.spawned)
		table.clear(x.told)
		x.zero()
	end
	local function run(trip, until_)
		while x.clock() - trip.Start < until_ and x.attrs.SubTrip do
			x.beat(1 / 60)
		end
	end
	local function dives()
		-- (they reach the water on the land fish, as RideService has it)
		local took = x.diving(true)
		if took then
			x.set({ state = "Carried", onLand = false })
		end
		return took
	end

	fresh()
	local trip = leap(row, 4, 5)
	ok("a leap told: the trip is the air hop's, its start the leap's", trip and trip.Air and trip.Start == x.clock())
	ok("one fish, out of sight on its rider's fish until the jump", #x.spawned == 1 and x.spawned[1].Root.Anchored and x.spawned[1].Model:GetAttribute("SubAir") == true)
	ok("its saddle is where the rider was", (x.spawned[1].Root.CFrame * x.spawned[1].Saddle.Position - V3.new(row.start[1] + x.X0, row.start[2], row.start[3])).Magnitude < 0.01)
	run(trip, trip.Approach - 0.05)
	ok("still on the land fish before the jump", x.get().state == "Dock" and x.get().onLand and x.get().carriedOff == 0)
	ok("going into the water by then gives no second trip", dives() == false and alive() == 1)
	x.set({ state = "Dock", onLand = true })
	run(trip, trip.Approach + 0.05)
	ok("off it at the jump, once", x.get().state == "Carried" and not x.get().onLand and x.get().carriedOff == 1 and x.attrs.SubPhase == "Hop", x.attrs.SubPhase)
	local _, rideAt, arriveAt, dropAt = SubTrip.times(trip)
	run(trip, rideAt + 0.1)
	ok("the run follows", x.attrs.SubPhase == "Ride" or x.attrs.SubPhase == "Run", x.attrs.SubPhase)
	run(trip, arriveAt + 0.2)
	run(trip, dropAt + 0.1)
	ok("the kick with that same fish, never a second", not x.spawned[1].Root.Anchored and #x.spawned == 1 and x.told[#x.told][1] == "SubDrop" and x.told[#x.told][2] == "Kick" and x.told[#x.told][3] == x.spawned[1].Model)
	run(trip, dropAt + trip.DropTime + c.Late + 0.2)
	ok("seated on it, nothing left over", x.get().seated == 1 and alive() == 0 and x.get().carriedOff == 1)

	for _, late in { 0.1, 0.25 } do
		fresh()
		trip = leap(row, 4, 5, late)
		ok(string.format("word %.2f s late: still made, from the leap's own start", late), trip and trip.Air and math.abs(x.clock() - trip.Start - late) < 1e-6)
	end
	fresh()
	trip = leap(row, 4, 5, 0.6)
	ok("word after the moment to jump: no trip, no fish left", trip == nil and alive() == 0 and x.get().state == "Dock")
	ok("  and the hop under water as they go in", dives() and x.attrs.SubPhase == "Saddle" and alive() == 1 and SubTrip.decode(x.attrs.SubTrip).Air == nil)
	fresh()
	trip = leap(row, 4, 5, 2)
	ok("word far too late: refused", trip == nil and alive() == 0)

	local function refused(name, change)
		fresh()
		ready(row, 4, 5)
		local said = leapOf(row, x.clock())
		change(said)
		x.actions.fire(x.player, "SubLeap", said)
		ok("refused: " .. name, x.attrs.SubTrip == nil and alive() == 0)
	end
	refused("a leap from somewhere else", function(said) said.Take += V3.new(0, 0, 80) end)
	refused("backwards", function(said) said.Heading = V3.new(0, 0, -1) end)
	refused("far too fast", function(said) said.Far = 800 end)
	refused("not a number", function(said) said.Time = 0 / 0 end)
	refused("no tilts", function(said) said.Tilts = {} end)
	refused("a word in the future", function(said) said.Start += 1 end)
	refused("not a leap at all", function(said) for k in said do said[k] = nil end end)
	refused("not on the land fish", function() x.set({ onLand = false }) end)
	refused("dead", function() x.set({ health = 0 }) end)
	refused("unequipped", function() x.set({ equipped = false }) end)
	fresh()
	ready(row, 4, 5)
	x.actions.fire(x.player, "SubPick", 0, "")
	x.actions.fire(x.player, "SubLeap", leapOf(row, x.clock()))
	ok("no land picked: nothing", x.attrs.SubTrip == nil and alive() == 0)
	fresh()
	ready(row, 4, 5)
	x.actions.fire(x.player, "SubLeap", leapOf(row, x.clock()))
	local first = x.attrs.SubTrip
	x.beat(1.1)
	x.actions.fire(x.player, "SubLeap", leapOf(row, x.clock()))
	ok("a second leap told at once: the first trip stands", x.attrs.SubTrip == first and #x.spawned == 1)

	-- before the jump: the plain dive goes on
	for name, change in
		{
			["died"] = { health = 0 },
			["unequipped"] = { equipped = false },
			["off the fish"] = { onLand = false },
		}
	do
		fresh()
		trip = leap(row, 4, 5)
		run(trip, 0.2)
		x.set(change)
		x.beat(1 / 60)
		ok(name .. " before the jump: the trip is over, the copy gone, never carried", x.attrs.SubTrip == nil and alive() == 0 and x.get().carriedOff == 0)
		x.set({ health = 100 })
	end
	-- after it
	for _, when in { 0.15, 0.9, 2.5 } do
		fresh()
		trip = leap(row, 4, 5)
		run(trip, trip.Approach + when)
		x.set({ equipped = false })
		x.beat(1 / 60)
		local after = SubTrip.decode(x.attrs.SubTrip)
		ok(string.format("unequipped %.2f s after the jump: the copy leaves, the trip goes on to a fling", when),
			x.spawned[1].Model:GetAttribute("SubLeave") ~= nil and after and after.Air ~= nil and not after.Fish and after.Start == trip.Start)
		run(trip, dropAt + 0.1)
		ok("  flung, nothing left", #x.spawned == 1 and alive() == 0 and x.get().flung == 1 and x.get().seated == 0)
		fresh()
		trip = leap(row, 4, 5)
		run(trip, trip.Approach + when)
		x.set({ state = "Dock" }) -- (died, or reset)
		x.beat(1 / 60)
		ok(string.format("died or reset %.2f s after the jump: the trip is over, the copy gone", when), x.attrs.SubTrip == nil and alive() == 0)
	end
	for _, when in { 0.1, 0.6, 1.2 } do
		fresh()
		trip = leap(row, 4, 5)
		run(trip, when)
		x.removing.fire(x.player)
		ok(string.format("left the game at %.1f s: the copy is gone", when), alive() == 0)
		x.added.fire(x.player)
	end
	fresh()
	trip = leap(row, 4, 5)
	run(trip, 0.2)
	x.beat(3) -- (the server stands still for three seconds: it catches up)
	ok("a server hitch over the jump: carried off then, once", x.get().carriedOff == 1 and x.get().state == "Carried" and #x.spawned == 1)
	-- a second trip at once after the first
	fresh()
	trip = leap(row, 4, 5)
	run(trip, trip.Approach + 1)
	x.set({ state = "Dock" })
	x.beat(1 / 60)
	x.beat(1)
	trip = leap(row, 4, 5)
	ok("a second trip right after the first was given up", trip and trip.Air and alive() == 1)
	-- a trip that can't be made
	fresh()
	local held = x.FishService.streamPoint
	x.FishService.streamPoint = function()
		error("made to fail")
	end
	trip = leap(row, 4, 5)
	x.FishService.streamPoint = held
	ok("a trip that can't be made leaves no fish", trip == nil and alive() == 0)
	-- the switch
	fresh()
	Config.Sub.AirHop = 0
	trip = leap(row, 4, 5)
	ok("AirHop 0: a leap told is nothing", trip == nil and alive() == 0)
	ok("  and the hop under water is as it was", dives() and x.attrs.SubPhase == "Saddle" and SubTrip.decode(x.attrs.SubTrip).Air == nil and x.attrs.SubTrip:find('"A":') == nil)
	Config.Sub.AirHop = 1
	fresh()
	ready(row, 4, 5)
	ok("AirHop 1, no leap told (stepped off): the hop under water", dives() and x.attrs.SubPhase == "Saddle" and alive() == 1)
	fresh()
	x.set({ equipped = false, state = "Dock" })
	ok("on foot: as it was", x.diving(false) and x.attrs.SubPhase == "Approach" and alive() == 0)
	fresh()
end
