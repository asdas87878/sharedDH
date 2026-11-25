-- The endless Underworld offline (NULLROOM e1): the game's own herd, lane and sums on the saved place's own parts.
--   rojo build -o /tmp/loop.rbxl && lune run tools/endless/loop_test /tmp/loop.rbxl <census folder> [<place of main>]
-- With a third argument (a place built from main) it also proves that On = 0 is main's game: the same fish, same places.
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local World = require("./world")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local place, folder, other = process.args[1], process.args[2], process.args[3]
local census = World.census(folder)
local KILL = -20000
local ok, done = World.ok()

local function open(path: string, on: number)
	return World.open(path, census, KILL, function(config)
		if config.Endless then
			config.Endless.On = on
		end
	end)
end

-- ============================================================ off: main's own game
print("OFF (Config.Endless.On = 0)")
local function story(path: string): { string }
	local w = open(path, 0)
	local out = { tostring(w.S.Length), tostring(w.S.Count), tostring(w.L.Length) }
	w.run()
	-- down the last land and out past its end, where the loop would be
	local rider = w.player(Vector3.zero)
	local s = w.Service.landStart(10) - 800
	for f = 1, 900 do
		s += 175 / 30
		rider.Root.Position = w.Service.streamPoint(s, 20, 8)
		w.frame(1 / 30)
		if f % 150 == 0 then
			for _, row in w.Service.stats().Fish do
				table.insert(out, string.format("%s %.6f %.6f %.6f %s", row.Id, row.S, row.A, row.Lift, tostring(row.Parked)))
			end
		end
	end
	local made = 0
	for _, m in w.Made do
		made += 1
		table.insert(out, string.format("%d %s %s", m.Id, m.Model.Kind, tostring(m.Model.Attributes.SizeTier)))
	end
	table.insert(out, "rolls " .. w.Random.Rolls)
	return out
end
local mine = story(place)
do
	local w = open(place, 0)
	ok("no laps, and the attribute says 0", w.NetFolder.Attributes.EndlessLaps == 0)
	ok("the lane and the stream end where they did", w.L.Length < 31200 and w.S.Z[w.S.Count] < 23100, w.S.Z[w.S.Count] .. " " .. w.L.Length)
	local e = w.Harness.require(w.Harness.find("ReplicatedStorage.Shared.Endless"))
	local p = Vector3.new(1, 2, 30000)
	ok("fold gives a place back as it is", e.fold(p) == p and e.beside(p, p) == p and e.laps() == 0)
	ok("lane gives the lane back as it is", e.lane(w.L) == w.L)
	local same = true
	for i = 0, 2000 do
		local u = i / 2000
		same = same
			and w.Config.rollVariant(u) == w.Config.rollVariant(u, 1)
			and w.Config.rollSize(u, "Epic") == w.Config.rollSize(u, "Epic", 1)
	end
	ok("the odds are the same odds", same)
end
if other then
	local theirs = story(other)
	local first = nil
	for i = 1, math.max(#mine, #theirs) do
		if mine[i] ~= theirs[i] then
			first = i
			break
		end
	end
	ok(
		string.format("On = 0 is main's game: %d numbers the same over 30 s of riding (fish, kinds, sizes, places, rolls)", #mine),
		first == nil,
		first and (tostring(mine[first]) .. " / " .. tostring(theirs[first]))
	)
end

-- ============================================================ on
print("ON (Config.Endless.On = 1)")
local w = open(place, 1)
local Endless = w.Harness.require(w.Harness.find("ReplicatedStorage.Shared.Endless"))
local Lane, Stream, e = w.Lane, w.Stream, w.Config.Endless
for _, line in w.Log do
	print("      " .. line)
end
for _, line in w.Harness.warnings do
	print("      warning: " .. line)
end
local laps = Endless.laps()
local shift = Endless.shift()
local PERIOD = e.To - e.From
ok(laps .. " laps", laps == e.Laps and w.NetFolder.Attributes.EndlessLaps == laps)
local S = w.S
local lane = Endless.lane(w.L) -- as a client makes it (Course): from the built lane and the attribute

-- the sums
do
	local bad = 0
	local r = World.random(7)
	for _ = 1, 20000 do
		local z = r:NextNumber(0, e.To + PERIOD * laps)
		local p = Vector3.new(r:NextNumber(-9000, 4000), r:NextNumber(-19000, 0), z)
		local base, off = Endless.fold(p)
		local k = math.floor((z - e.From) / PERIOD)
		local inLoop = z >= e.From
		if (base + off - p).Magnitude > 0.02 or (inLoop and (base.Z < e.From - 0.02 or base.Z > e.To + 0.02)) or (not inLoop and base ~= p) then
			bad += 1
		end
		if inLoop and Endless.lapOf(z) ~= math.clamp(k, 0, laps) then
			bad += 1
		end
		if inLoop and (Endless.beside(base, p) - p).Magnitude > 0.02 and math.abs(base.Z - e.From) < PERIOD * 0.49 then
			bad += 1
		end
	end
	ok("fold and back, 20,000 places", bad == 0, bad)
	ok("the odds: nothing in the map, +1% a minute, +10% at most", Endless.odds(-5) == 1 and Endless.odds(0) == 1
		and math.abs(Endless.odds(175 * 60) - 1.01) < 1e-9 and math.abs(Endless.odds(175 * 600) - 1.1) < 1e-9 and Endless.odds(1e7) == 1.1)
	local n = 200000
	local function share(more: number): (number, number, number)
		local colour, large, tiny = 0, 0, 0
		for i = 1, n do
			local u = (i - 0.5) / n
			if w.Config.rollVariant(u, more) ~= "" then
				colour += 1
			end
			local size = w.Config.rollSize(u, "Epic", more)
			if size == "Tiny" then
				tiny += 1
			elseif size ~= "Normal" then
				large += 1
			end
		end
		return colour / n, large / n, tiny / n
	end
	local c0, l0, t0 = share(1)
	local c1, l1, t1 = share(1.1)
	print(string.format("      colours %.4f -> %.4f, sizes over Normal %.4f -> %.4f, Tiny %.4f -> %.4f at the most", c0, c1, l0, l1, t0, t1))
	ok("at the most the colours and the bigger sizes are a tenth more, Tiny the same",
		math.abs(c1 / c0 - 1.1) < 0.01 and math.abs(l1 / l0 - 1.1) < 0.01 and math.abs(t1 - t0) < 1e-4)
end

-- the lane
do
	local worst, jump = 0, 0
	local sb = lane.ZoneEnd[10]
	for i = 2, #lane.Points do
		if lane.S[i] > sb then
			jump = math.max(jump, (lane.Points[i] - lane.Points[i - 1]).Magnitude)
		end
	end
	print(string.format("      the longest piece of the lane past the map: %.0f studs", jump))
	local period = (lane.Length - sb) / laps
	for k = 0, 2000 do
		local s = sb + period * k / 2000
		local a = Lane.at(lane, s)
		for n = 1, laps - 1 do
			worst = math.max(worst, (Lane.at(lane, s + period * n) - a - shift * n).Magnitude)
		end
	end
	ok("no gap in the lane past the map", jump < 110)
	ok("every lap of the lane is the same lap, one shift on", worst < 0.6, worst)
	local turn, step = 0, 0
	local before = nil
	local at, along = Lane.at(lane, sb - 400)
	for s = sb - 400, sb + 900, 4 do
		local p, way = Lane.at(lane, s)
		step = math.max(step, (p - at).Magnitude)
		turn = math.max(turn, math.deg(math.acos(math.clamp(way:Dot(along), -1, 1))))
		at, along, before = p, way, s
	end
	local turnMap, atMap, alongMap = 0, nil, nil
	for s = 18000, sb, 4 do
		local p, way = Lane.at(lane, s)
		if alongMap then
			turnMap = math.max(turnMap, math.deg(math.acos(math.clamp(way:Dot(alongMap), -1, 1))))
		end
		atMap, alongMap = p, way
	end
	print(string.format("      the lane's middle at the joint: at most %.1f degrees turned and %.1f studs gone in 4 studs (in lands 8 to 10: %.1f degrees)", turn, step, turnMap))
	ok("no jump in the lane at a joint", step < 9 and turn <= turnMap + 1)
	ok("the land is the last one, all the way", Lane.zoneAt(lane, lane.Length - 1) == 10)
	local t0 = os.clock()
	for i = 1, 2000 do
		Lane.project(lane, Vector3.new(-3000, -8000, 60000), sb + 30000)
	end
	local near = (os.clock() - t0) / 2000
	t0 = os.clock()
	for i = 1, 200 do
		Lane.project(lane, Vector3.new(-3000, -8000, 60000))
	end
	print(string.format("      where on the lane: %.4f ms with a guess (every frame), %.2f ms without", near * 1000, (os.clock() - t0) / 200 * 1000))
end

-- the herd's water
local loopS, lapS = w.LoopAt, w.LapLength
do
	local function kink(s0: number, s1: number, u: number): (number, number, number)
		local turn, rise, gap = 0, 0, 0
		local last, way = nil, nil
		for s = s0, s1, 12 do
			local p = Stream.point(S, s, Stream.across(S, s, u, 0, 0, 6), 16)
			if last then
				local d = p - last
				local flat = Vector3.new(d.X, 0, d.Z).Unit
				if way then
					turn = math.max(turn, math.deg(math.acos(math.clamp(flat:Dot(way), -1, 1))))
				end
				way = flat
				rise = math.max(rise, math.abs(d.Y))
				gap = math.max(gap, d.Magnitude)
			end
			last = p
		end
		return turn, rise, gap
	end
	for _, u in { -0.8, 0, 0.8 } do
		local t0, r0, g0 = kink(18000, loopS - 400, u)
		local t1, r1, g1 = kink(loopS - 400, loopS + 600, u)
		print(string.format("      line %.1f: at the joint it turns %.1f degrees, steps %.1f up or down, %.1f on in 12 studs (in lands 8 to 10: %.1f, %.1f, %.1f)", u, t1, r1, g1, t0, r0, g0))
		ok("the herd's line is as smooth at the joint as in the map", t1 <= t0 + 0.5 and r1 <= r0 + 0.5 and g1 <= g0 + 1)
	end
	local worst, floor = 0, 0
	for k = 0, 1500 do
		-- (from the middle of the second lap on: up to there the line is the one built off the map)
		local s = loopS + lapS * (1.5 + k / 1500)
		for _, u in { -0.8, 0, 0.8 } do
			local a = Stream.point(S, s, Stream.across(S, s, u, 0, 1, 6), 16)
			for _, n in { 1, 7, laps - 4 } do
				local b = Stream.point(S, s + lapS * n, Stream.across(S, s + lapS * n, u, 0, 1, 6), 16)
				worst = math.max(worst, (b - a - shift * n).Magnitude)
			end
		end
	end
	ok("every lap of the herd's water is the same, round the same things", worst < 1.5, worst)
	-- the first half lap is built off the map: how far to the side of the same line a lap on
	local aside = 0
	for s = loopS, loopS + lapS * 0.5, 24 do
		for _, u in { -0.8, 0, 0.8 } do
			local a = Stream.point(S, s, Stream.across(S, s, u, 0, 1, 6), 16) + shift
			local least = math.huge
			for t = s + lapS - 40, s + lapS + 40, 2 do
				least = math.min(least, (Stream.point(S, t, Stream.across(S, t, u, 0, 1, 6), 16) - a).Magnitude)
			end
			aside = math.max(aside, least)
		end
	end
	print(string.format("      the line of the first half lap is at most %.1f studs to the side of the same half a lap on (water 480 wide and more)", aside))
	ok("the first half lap is the same water", aside < 16, aside)
	-- and over the built floor, as the parts are shown: the seabed under each line, in lap 0's parts
	local under, dry, n = 0, 0, 0
	for s = loopS, loopS + lapS * 3, 12 do
		for _, u in { -0.9, -0.45, 0, 0.45, 0.9 } do
			local across = Stream.across(S, s, u, 0, 0, 6)
			local p, floorY = Stream.point(S, s, across, 16)
			local at, off = Endless.fold(p)
			local hit = w.Workspace:Raycast(at + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0))
			for _ = 1, 8 do
				if not hit or hit.Instance.Folder == "Seabed" then
					break
				end
				hit = w.Workspace:Raycast(hit.Position - Vector3.new(0, 0.1, 0), Vector3.new(0, -200, 0))
			end
			n += 1
			if not hit then
				dry += 1
			elseif hit.Position.Y + off.Y > p.Y - 4 then
				under += 1
			end
		end
	end
	local under0, n0 = 0, 0
	for s = loopS - lapS, loopS - 100, 12 do
		for _, u in { -0.9, -0.45, 0, 0.45, 0.9 } do
			local p = Stream.point(S, s, Stream.across(S, s, u, 0, 0, 6), 16)
			local hit = w.Workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0))
			for _ = 1, 8 do
				if not hit or hit.Instance.Folder == "Seabed" then
					break
				end
				hit = w.Workspace:Raycast(hit.Position - Vector3.new(0, 0.1, 0), Vector3.new(0, -200, 0))
			end
			n0 += 1
			if hit and hit.Position.Y > p.Y - 4 then
				under0 += 1
			end
		end
	end
	print(string.format("      of %d places of laps 1 to 3's herd, %d are within 4 studs of the floor or under it and %d have no floor (in the map's own last land: %d of %d)", n, under, dry, under0, n0))
	ok("the herd swims over the floor as it is shown", under <= under0 + 3 and dry <= 5)
end

-- ============================================================ the parts as a player sees them (EndlessController's sums)
do
	local near, seen, twice, gone = math.huge, 0, 0, 0
	for eye = e.From - 1500, e.To + PERIOD * 5, 10 do
		for z = e.From - 64, e.To + 64, 16 do
			local k = Endless.nearest(eye, z, 0, 1)
			local k2 = Endless.nearest(eye + 10, z, 0, 1)
			if k ~= k2 then
				near = math.min(near, math.abs(z + k * PERIOD - eye), math.abs(z + k2 * PERIOD - eye - 10))
			end
			-- a long part: one of its two is at each of the two laps nearest the camera
			local a, b = Endless.nearest(eye, z, 0, 2), Endless.nearest(eye, z, 1, 2)
			local a2, b2 = Endless.nearest(eye + 10, z, 0, 2), Endless.nearest(eye + 10, z, 1, 2)
			if a ~= a2 then
				seen = math.max(seen, -math.min(math.abs(z + a * PERIOD - eye), math.abs(z + a2 * PERIOD - eye)))
				twice = if twice == 0 then math.abs(z + a * PERIOD - eye) else math.min(twice, math.abs(z + a * PERIOD - eye), math.abs(z + a2 * PERIOD - eye - 10))
			end
			if b ~= b2 then
				twice = if twice == 0 then math.abs(z + b * PERIOD - eye) else math.min(twice, math.abs(z + b * PERIOD - eye), math.abs(z + b2 * PERIOD - eye - 10))
			end
			-- what is near the camera is always there
			for n = 0, 6 do
				if math.abs(z + n * PERIOD - eye) < 1180 and k ~= n then
					gone += 1
				end
				if math.abs(z + n * PERIOD - eye) < 1180 and a ~= n and b ~= n then
					gone += 1
				end
			end
		end
	end
	print(string.format("      a part changes laps at least %.0f studs from the camera down the map, a long one %.0f", near, twice))
	ok("nothing changes nearer than 1,200 (a short part), 2,400 (a long one)", near >= 1200 and twice >= 2400)
	ok("whatever is within 1,180 studs down the map is always standing", gone == 0, gone)
end

-- ============================================================ the fish
print("RIDING (175 studs a second, the game's own herd)")
w.run()
local function ride(from: number, seconds: number, more: { any }?): any
	local rider = w.player(Vector3.zero)
	local s = from
	local result = { Jump = 0, JumpAt = 0, Made = {}, Gone = {}, Count = {}, Near = {}, Most = 0, Rider = rider }
	local was: { [number]: any } = {}
	local parked: { [number]: boolean } = {}
	local madeFrom, goneFrom = #w.Made, #w.Gone
	local frames = math.floor(seconds * 30)
	for f = 1, frames do
		s += 175 / 30
		rider.Root.Position = w.Service.streamPoint(s, 20, 8)
		for _, extra in more or {} do
			extra.S += 175 / 30
			extra.Rider.Root.Position = w.Service.streamPoint(extra.S, 20, 8)
		end
		w.frame(1 / 30)
		local at = rider.Root.Position
		local fresh: { [number]: any } = {}
		local near = 0
		for id, model in w.Fish do
			if model.Parent and model.Parent.Name == "Fish" then
				local p = model.PrimaryPart.Position
				fresh[id] = p
				if (p - at).Magnitude < 500 then
					near += 1
					local before = was[id]
					if before then
						local moved = (p - before).Magnitude
						if moved > result.Jump then
							result.Jump, result.JumpAt = moved, s
						end
					elseif f > 60 then
						-- one that was not there a frame ago, in sight: made, or woken, too near
						table.insert(result.Made, { S = s, Far = (p - at).Magnitude, Woken = parked[id] == true, Kind = model.Kind })
					end
				end
			end
		end
		for id, p in was do
			if not fresh[id] and (p - at).Magnitude < 495 and f > 60 then
				table.insert(result.Gone, { S = s, Far = (p - at).Magnitude })
			end
		end
		was = fresh
		table.clear(parked)
		for id, model in w.Fish do
			parked[id] = model.Parent ~= nil and model.Parent.Name ~= "Fish"
		end
		if f % 15 == 0 then
			local total = 0
			for _ in w.Fish do
				total += 1
			end
			result.Most = math.max(result.Most, total)
			table.insert(result.Count, { S = s, N = near })
		end
	end
	result.MadeRate = (#w.Made - madeFrom) / seconds
	result.GoneRate = (#w.Gone - goneFrom) / seconds
	result.S = s
	return result
end
local function mean(list: { any }, s0: number, s1: number): (number, number)
	local sum, n, least = 0, 0, math.huge
	for _, row in list do
		if row.S >= s0 and row.S < s1 then
			sum += row.N
			n += 1
			least = math.min(least, row.N)
		end
	end
	return sum / math.max(n, 1), least
end
do
	local start = w.Service.landStart(10) - 1200
	local result = ride(start, (loopS + lapS * 2.2 - start) / 175)
	local body, bodyLeast = mean(result.Count, w.Service.landStart(10) + 200, loopS - 700)
	local seam, seamLeast = mean(result.Count, loopS - 500, loopS + 500)
	local lap1, lap1Least = mean(result.Count, loopS + 500, loopS + lapS - 500)
	local lap2, lap2Least = mean(result.Count, loopS + lapS - 500, loopS + lapS * 2.2)
	print(string.format("      fish within 500 studs of the rider (mean, least): the built last land %.1f, %d; across the joint %.1f, %d; lap 1 %.1f, %d; across the next joint and lap 2 %.1f, %d", body, bodyLeast, seam, seamLeast, lap1, lap1Least, lap2, lap2Least))
	print(string.format("      made %.2f a second, taken away %.2f; most in the whole sea %d (cap %d)", result.MadeRate, result.GoneRate, result.Most, w.Config.Spawn.MaxTotal))
	-- (two seconds in, the herd this test dropped the rider into the middle of wakes round them: not counted. Then what
	-- still shows is a hunter or a fast one that swam 200 studs in the two seconds between two lookings, today's game)
	local seen, odd, least = 0, {}, math.huge
	for _, m in result.Made do
		if m.S > start + 1200 then
			seen += 1
			least = math.min(least, m.Far)
			table.insert(odd, string.format("%s %.0f off at %.0f past the joint (%s)", tostring(m.Kind), m.Far, m.S - loopS, if m.Woken then "woken" else "made"))
		end
	end
	print("      of 500 studs, seen to come in late: " .. table.concat(odd, ", "))
	ok("no fish within 470 studs of the rider appears, none within 500 goes", least > 470 and seen <= 2 and #result.Gone == 0, seen .. " made, " .. #result.Gone .. " gone")
	ok("no fish jumps: at most its own speed in a frame", result.Jump < 12, string.format("%.1f at %.0f", result.Jump, result.JumpAt))
	ok("the sea is as full in the laps as in the built last land", math.min(seam, lap1, lap2) >= body * 0.75 and math.min(seamLeast, lap1Least, lap2Least) >= 1)
	ok("the sea stays under its cap", result.Most < w.Config.Spawn.MaxTotal - 100)

	-- two riders: the first goes on to lap 6, the second follows from the last land a minute behind
	local first = result.Rider
	local extra = { S = result.S, Rider = first }
	local second = ride(start, 20, { extra })
	local far = (first.Root.Position - second.Rider.Root.Position).Magnitude
	local here, there = 0, 0
	for _, model in w.Fish do
		if model.Parent and model.Parent.Name == "Fish" then
			local p = model.PrimaryPart.Position
			here += if (p - second.Rider.Root.Position).Magnitude < 700 then 1 else 0
			there += if (p - first.Root.Position).Magnitude < 700 then 1 else 0
		end
	end
	print(string.format("      two riders, laps %d and %d: %.0f studs apart, %d and %d fish round them, made %.2f a second, most in the sea %d", Endless.lapOf(second.Rider.Root.Position.Z), Endless.lapOf(first.Root.Position.Z), far, here, there, second.MadeRate, second.Most))
	ok("two riders laps apart are really that far apart, each with a full sea", far > 2000 and here >= 8 and there >= 8)
	local late = 0
	for _, m in second.Made do
		late += if m.S > start + 1200 and m.Far < 470 then 1 else 0
	end
	ok("nothing appears or goes near either", late == 0 and #second.Gone == 0, late .. " / " .. #second.Gone)

	-- and behind them the laps are emptied
	table.clear(w.Players)
	local last = w.player(Vector3.new(3000, 10, -200))
	for _ = 1, 30 * 12 do
		w.frame(1 / 30)
	end
	local left = 0
	for _, row in w.Service.stats().Fish do
		left += if row.S >= loopS then 1 else 0
	end
	ok("with nobody down there the laps are empty", left == 0, left)
	local want = w.Service.stats().Slices
	local overlap = 0
	for i = 2, #want do
		overlap = math.max(overlap, math.abs(want[i].Start - want[i - 1].End))
	end
	ok("the herd's slices run end to end down the lane, the laps' too", overlap < 0.5, overlap)
end

-- ============================================================ distance, best, depth
do
	local Zones, Config = w.Zones, w.Config
	local zones = Zones.fallback()
	local before, best, down, refused, backwards = nil, 0, 0, 0, 0
	local lastBest = 0
	for s = loopS - 3000, S.Length - 100, 175 * 0.25 do
		local p = w.Service.streamPoint(s, 20, 8)
		local zone, along, metres = Zones.locate(zones, p)
		local lands = zone.Index - 1 + along
		if before and lands - before > 1 then
			refused += 1
		end
		before = lands
		best = math.max(best, math.floor(metres))
		if best - lastBest > 40 then
			backwards += 1
		end
		lastBest = best
	end
	local first = math.floor(select(3, Zones.locate(zones, w.Service.streamPoint(loopS - 3000, 20, 8))))
	print(string.format("      the gauge: %d m at the start of the last land, %d m at the last lap's end; %.1f a lap", first, best, -shift.Y))
	ok("best distance goes on up, and no check refuses it (BestService's rule)", refused == 0 and best > 17000, refused)
	-- the fold the server's rays use: over a whole lap, the floor under a rider is the floor of the built map
	local off = 0
	for s = loopS + lapS * 1.5 + 24, loopS + lapS * 2.5, 40 do
		local far = w.Service.streamPoint(s + lapS * 9, 20, 8)
		local built = w.Service.streamPoint(s, 20, 8)
		off = math.max(off, ((Endless.fold(far)) - (Endless.fold(built))).Magnitude)
	end
	ok("the server asks its own map about the same place whatever the lap (crash, grab, props)", off < 1.5, off)
	ok("the lane's inside is the same in lap 9 as in lap 1", math.abs(w.Service.inside(w.Service.streamPoint(loopS + 1500, 20, 8)) - w.Service.inside(w.Service.streamPoint(loopS + 1500 + lapS * 8, 20, 8))) < 3)
end
done()
