-- The 3D auras (look 2), checked offline (NULLROOM, 2026-11-25 a1): the tier ladder, what each tier costs, the fade rules,
-- how it stands round a rider and their fish, and that it is a volume and not a card. Shared/AuraVolume's sums, the sheets
-- on disk, and the two client files as text. What only Studio can say (the picture itself) is not here.
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/auras/volume_test.luau /tmp/place.rbxl
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Harness = require("../index/harness")

local world = Harness.open(process.args[1] or "/tmp/place.rbxl")
local ok, done = Harness.tally()
local V = world.require(world.find("ReplicatedStorage.Shared.AuraVolume"))
local Auras = world.require(world.find("ReplicatedStorage.Shared.Auras"))
local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
local Vector3: any = roblox.Vector3
local c = Config.Aura
local controller: string = world.find("StarterPlayer.StarterPlayerScripts.Client.Controllers.AuraController").Source

local specs = {}
for tier = 1, 12 do
	specs[tier] = V.spec(tier)
end

print("The ladder")
ok("twelve tiers, twelve lines of what each adds", #Auras.Tiers == 12 and #V.Adds == 12)
local taller, wider, more, stronger, kept, adds = true, true, true, true, true, true
for tier = 2, 12 do
	local a, b = specs[tier - 1], specs[tier]
	taller = taller and b.Height > a.Height * 1.03
	wider = wider and b.Radius > a.Radius * 1.02
	more = more and V.alive(b, 3) > V.alive(a, 3) and V.draws(b, 3) >= V.draws(a, 3)
	stronger = stronger and b.Strength >= a.Strength
	local has, n = {}, 0
	for _, l in b.Layers do
		has[l.Name] = true
		n += 1
	end
	for _, s in b.Strands do
		has[s.Name] = true
		n += 1
	end
	for _, l in a.Layers do
		kept = kept and has[l.Name] == true
		n -= 1
	end
	for _, s in a.Strands do
		kept = kept and has[s.Name] == true
		n -= 1
	end
	local light = (b.Light ~= nil) ~= (a.Light ~= nil) or (b.Pulse ~= nil) ~= (a.Pulse ~= nil)
	adds = adds and (n > 0 or light)
end
ok("every tier is taller than the one before", taller)
ok("and wider", wider)
ok("and has more in the air, and no fewer draw calls", more)
ok("and is no weaker", stronger)
ok("every tier keeps all the one before has", kept)
ok("every tier adds a layer, a ribbon, a light or a pulse", adds)
ok(
	"tier 1 is wisps and nothing else",
	#specs[1].Layers == 1 and specs[1].Layers[1].Name == "Wisps" and #specs[1].Strands == 0 and not specs[1].Light
)
ok("tier 12 stands over twice a character", specs[12].Height > 10.4, specs[12].Height)
local coloured = true
for tier, spec in specs do
	local main = Auras.Tiers[tier].Main
	for _, l in spec.Layers do
		for _, k in { "R", "G", "B" } do
			-- (the shop's colour, or that toward white: never a channel under it)
			coloured = coloured and (l :: any).Color[k] >= main[k] - 1e-3 and (l :: any).Color2[k] >= main[k] - 1e-3
		end
	end
end
ok("every layer is its tier's own colour, the shop card's, or that toward white", coloured)
ok(
	"flares: a landing from 7, a hop from 8, a boost from 9, a burst from 10",
	not specs[6].FlareLand
		and specs[7].FlareLand
		and not specs[7].FlareHop
		and specs[8].FlareHop
		and not specs[8].FlareBoost
		and specs[9].FlareBoost
		and not specs[9].Burst
		and specs[10].Burst
)

print("What it costs")
ok("tier 1: at most 5 draw calls", V.draws(specs[1], 3) <= 5, V.draws(specs[1], 3))
ok("tier 12: at most 25", V.draws(specs[12], 3) <= 25, V.draws(specs[12], 3))
local fewer, few, cap, capRide = true, true, true, true
for tier, spec in specs do
	fewer = fewer
		and V.draws(spec, 1) <= V.draws(spec, 2)
		and V.draws(spec, 2) <= V.draws(spec, 3)
		and V.draws(spec, 1) >= 1
	few = few and V.draws(spec, 1) <= 7 and V.alive(spec, 1) <= 45
	cap = cap and V.alive(spec, 3) <= 125
	local shape = V.ride(spec, Vector3.new(90, 60, 200), Vector3.new(0, 20, 0), nil, c)
	local alive = 0
	for _, l in spec.Layers do
		alive += V.rate(l, shape, 3, c) * (l.Life[1] + l.Life[2]) / 2
	end
	capRide = capRide and alive <= 190
end
ok("less at each detail level, never nothing", fewer)
ok("far away: at most 7 draw calls and 45 particles", few)
ok("near: at most 125 particles on foot", cap)
ok("and 190 round the biggest fish", capRide)
ok("ours is whole, on a phone two thirds", V.detail(0, 0, true, false, c) == 3 and V.detail(0, 0, true, true, c) == 2)
ok(
	"others: by distance",
	V.detail(20, 1, false, false, c) == 3
		and V.detail(c.WholeTo + 1, 1, false, false, c) == 2
		and V.detail(c.FewFrom + 1, 1, false, false, c) == 1
)
ok(
	"others: the nearest few whole, then less",
	V.detail(5, c.Full, false, false, c) == 3
		and V.detail(5, c.Full + 1, false, false, c) == 2
		and V.detail(5, c.Full + c.Half + 1, false, false, c) == 1
)
ok("others on a phone: a few pieces", V.detail(5, 1, false, true, c) == 1)
local function lights(most: number, detail: number, from: number): number
	local cc = table.clone(c)
	cc.Lights = most
	local n = 0
	for place = from, 20 do
		n += if V.lit(place, detail, cc) then 1 else 0
	end
	return n
end
ok("lights: as many as Aura.Lights, our own among them", lights(4, 3, 0) == 4 and lights(c.Lights, 3, 0) == c.Lights)
ok("... never more where ours is not there, none where little is drawn", lights(4, 3, 1) <= 4 and lights(4, 1, 0) == 0)
ok(
	"... 1 is our own only; 0 is none, not our own either",
	lights(1, 3, 0) == 1 and lights(1, 3, 1) == 0 and lights(0, 3, 0) == 0
)
ok("the controller asks that", string.find(controller, "AuraVolume.lit(l.Place, detail, c)", 1, true) ~= nil)
local total = V.draws(specs[12], 3)
for place = 1, 30 do
	total += V.draws(specs[12], V.detail(10, place, false, false, c))
end
ok("31 players all in tier 12, side by side: under 340 draw calls", total < 340, total)

print("When it shows")
-- walk: a speed a step, at so many steps a second (another player's place moves in jumps: hz of them)
local function run(m: any, doing: string, speed: number, seconds: number, hz: number?): number
	local at = m.At or Vector3.new(0, 0, 0)
	local dt, moved, last = 1 / 60, 0, 0
	for i = 1, math.floor(seconds * 60 + 0.5) do
		moved += speed * dt
		if not hz or i * dt - last >= 1 / hz then
			last = i * dt
			at += Vector3.new(0, 0, moved)
			moved = 0
		end
		V.fade(m.M, doing, at, dt, c)
	end
	m.At = at
	return m.M.Seen
end
local function new(): any
	return { M = V.mover(), At = nil }
end
local m = new()
ok("standing still: none of it at once", run(m, "Foot", 0, 0.1) < 0.05)
ok("seen within FadeIn and the still wait", run(m, "Foot", 0, c.FadeIn + c.StillFor + 0.05) == 1)
run(m, "Foot", 16, 0.1)
ok("walking: fading", m.M.Seen < 1 and m.M.Seen > 0, m.M.Seen)
ok("gone within 0.35 s of starting to walk", run(m, "Foot", 16, 0.25) == 0)
ok("walking on: never seen", run(m, "Foot", 16, 2) == 0)
ok("standing again: not all seen yet at 0.3 s", run(m, "Foot", 0, 0.3) < 0.7)
ok("all seen by 0.9 s", run(m, "Foot", 0, 0.6) == 1)
ok("the fade in is 0.5 s, the fade out 0.25 s", c.FadeIn == 0.5 and c.FadeOut == 0.25)
local far = new()
run(far, "Foot", 0, 2)
ok(
	"another player, 20 steps a second: walking is moving all along",
	run(far, "Foot", 16, 0.6, 20) == 0 and run(far, "Foot", 16, 2, 20) == 0
)
ok("10 steps a second: the same", run(far, "Foot", 16, 2, 10) < 0.02)
ok("and standing still is seen", run(far, "Foot", 0, 1, 20) == 1)
ok("a breath of drift (0.3 studs a second) is standing still", run(far, "Foot", 0.3, 1, 20) == 1)
run(far, "Foot", 12, 0.5)
ok("falling or jumping up is moving (its whole speed counts)", far.M.Seen == 0)
local swim = new()
run(swim, "Foot", 0, 2)
ok("swimming: gone, even floating still", run(swim, "Move", 0, 0.3) == 0 and run(swim, "Move", 0, 3) == 0)
local ride = new()
ok("riding: seen, at any speed", run(ride, "Ride", 300, 0.55) == 1 and run(ride, "Ride", 300, 5) == 1)
ok("off the fish and swimming: gone", run(ride, "Move", 20, 0.3) == 0)
local slow = new()
run(slow, "Foot", 0, 2)
V.fade(slow.M, "Foot", slow.At, 0, c)
ok("a frame of no time changes nothing", slow.M.Seen == 1)

print("Who rides")
ok(
	"a fish, and thrown about on it",
	V.doing("Riding", nil, false, c) == "Ride" and V.doing("Failing", nil, false, c) == "Ride"
)
ok("the trainer, a tank fish, a land fish (seated, on the dock)", V.doing("Dock", nil, true, c) == "Ride")
ok(
	"the hop between fish is the ride (Aura.Hop)",
	V.doing("Jumping", nil, false, c) == "Ride" and V.doing("Jumping", nil, false, { Hop = 0 }) == "Move"
)
ok(
	"the sub: swimming to it, then the ride",
	V.doing("Carried", "Approach", false, c) == "Move" and V.doing("Carried", "Saddle", false, c) == "Ride"
)
ok(
	"swimming and drowning are moving",
	V.doing("Free", nil, false, c) == "Move" and V.doing("Drowning", nil, false, c) == "Move"
)
ok(
	"the dock is by their own movement",
	V.doing("Dock", nil, false, c) == "Foot" and V.doing(nil, nil, false, c) == "Foot"
)

print("How it stands")
local foot = V.foot(specs[12])
ok("on foot: a circle on the ground", foot.X == foot.Z and foot.At == Vector3.new(0, 0, 0) and foot.Grow == 1)
local function fish(id: string, scale: number, tier: number, eye: number?): (any, any, any)
	local body = Config.FishById[id].Size * scale
	local seat = Vector3.new(0, body.Y * 0.1 + 2, -body.Z * 0.1)
	return V.ride(specs[tier], body, seat, eye, c), body, seat
end
local calm = table.clone(c)
calm.EyeCalm = 1
local whole = table.clone(c)
whole.EyeCalm = 0
local function same(x: any, y: any): boolean
	return x.X == y.X and x.Z == y.Z and x.Height == y.Height and x.At == y.At and x.Grow == y.Grow and x.Own == y.Own
end
local round, capped, rider, clear, bigger, ours = true, true, true, true, true, true
for id in Config.FishById do
	for _, scale in { 1, 3 } do
		for _, tier in { 1, 6, 12 } do
			local s, body, seat = fish(id, scale, tier, nil)
			capped = capped and s.X <= c.RideWide and s.Z <= c.RideLong and s.Grow <= c.RideGrow and s.Height < 60
			-- (round it: wider than its body, unless that is over the most; a long one's middle is the rider)
			round = round and (s.X >= math.min(body.X * 0.425 + 1, c.RideWide - 0.01))
			rider = rider
				and math.abs(seat.Z - s.At.Z) <= s.Z
				and s.At.Y <= seat.Y
				and s.At.Y + s.Height >= seat.Y + 2.5
			local mine = V.ride(specs[tier], body, seat, 17.7, whole)
			ours = ours and same(mine, s) and V.strong(specs[tier], mine, whole) == 1
			for _, l in specs[tier].Layers do
				ours = ours and V.rate(l, mine, 3, whole) == V.rate(l, s, 3, whole)
			end
			local own = V.ride(specs[tier], body, seat, 17.7, calm)
			clear = clear
				and own.Z <= 17.7 * c.EyeShare + 0.01
				and own.X <= 17.7 * c.EyeShare * 1.3 + 0.01
				and own.Grow <= c.EyeGrow
			bigger = bigger and s.X > V.foot(specs[1]).X
		end
	end
end
ok("round every fish's sides, small to Colossal, up to the most", round)
ok("never past its most", capped)
ok("the rider is always inside it", rider)
ok("our own riding is as everyone sees it: the fish's size, every layer, whole strength", ours and c.EyeCalm == 0)
ok("with Aura.EyeCalm 1 our own never reaches our camera", clear)
local faint = V.ride(specs[1], Vector3.new(6, 5, 18), Vector3.new(0, 2, 0), 17.7, calm)
ok(
	"... and is calmer the higher the tier, tier 1's whole",
	V.strong(specs[1], faint, calm) == 1 and math.abs(V.strong(specs[12], faint, calm) - c.EyeStrength) < 1e-9
)
ok("bigger than on foot at tier 1", bigger)
local whale, _, seat = fish("BlueWhale", 3, 12, nil)
ok(
	"a body too wide for it: it stands on the back, under the rider",
	whale.At.Y > seat.Y - 3 and whale.At.Y < seat.Y,
	whale.At.Y - seat.Y
)

print("A volume, not a card")
local shape = V.foot(specs[12])
local front, behind, left, right, closeBy = 0, 0, 0, 0, true
for i = 1, 48 do
	local clock = i / 48 * 2 * math.pi / 1.9
	for _, s in specs[12].Strands do
		for j = 1, s.Beams + 1 do
			local p = V.strandAt(s, shape, j, clock, 0)
			front += if p.Z < -1 then 1 else 0
			behind += if p.Z > 1 then 1 else 0
			left += if p.X < -1 then 1 else 0
			right += if p.X > 1 then 1 else 0
			closeBy = closeBy
				and math.abs(p.X) < shape.X * 1.7
				and math.abs(p.Z) < shape.Z * 1.7
				and p.Y >= -0.5
				and p.Y < shape.Height * 1.15
		end
	end
end
local least, most = math.min(front, behind, left, right), math.max(front, behind, left, right)
ok("the ribbons go round: as much in front as behind and beside", least > most * 0.8, `{front} {behind} {left} {right}`)
ok("and stay round the wearer", closeBy)
-- a Beam is a cubic curve: it stays on the spiral
local off = 0
for _, s in specs[12].Strands do
	local still = table.clone(s)
	still.Wave = 0
	for i = 1, s.Beams do
		local p0, d0, h0 = V.strandAt(still, shape, i, 0, 0)
		local p3, d3, h3 = V.strandAt(still, shape, i + 1, 0, 0)
		local p1, p2 = p0 + d0 * h0, p3 - d3 * h3
		for k = 0, 10 do
			local u = k / 10
			local p = p0 * (1 - u) ^ 3 + p1 * (3 * u * (1 - u) ^ 2) + p2 * (3 * u * u * (1 - u)) + p3 * u ^ 3
			local r = math.sqrt(p.X ^ 2 + p.Z ^ 2) / shape.X
			local want = V.strandAt(still, shape, i, 0, 0)
			local r0 = math.sqrt(want.X ^ 2 + want.Z ^ 2) / shape.X
			local r3 = math.sqrt(p3.X ^ 2 + p3.Z ^ 2) / shape.X
			off = math.max(off, math.abs(r - (r0 + (r3 - r0) * u)))
		end
	end
end
ok("every Beam stays within a tenth of the radius of its spiral", off < 0.1, off)
local turned = 0
for _, s in specs[12].Strands do
	turned = math.max(turned, s.Turns / s.Beams)
end
ok("no Beam takes more than half a turn", turned <= 0.5001, turned)
local spread = true
for _, spec in specs do
	for _, l in spec.Layers do
		local _, size = V.place(l, V.foot(spec))
		spread = spread and size.X == size.Z and size.X > 0 and size.Y > 0
	end
end
ok("every place is round the wearer, the same on all sides", spread)
local lib: string = world.find("StarterPlayer.StarterPlayerScripts.Client.Lib.AuraAround").Source
local pushed = 0
for _, id in { "Clownfish", "BlueWhale" } do
	local at = fish(id, 1, 12, nil)
	for _, l in specs[12].Layers do
		pushed += V.behind(l.Name, l.Wide, at) + V.behind(l.Name, l.Wide, shape)
	end
end
ok("nothing of it is pushed toward or behind the camera (Aura.Small 0)", pushed == 0 and c.Small == 0)
ok(
	"nothing of it is turned to the camera as a whole",
	not string.find(lib, "CurrentCamera", 1, true) and not string.find(lib, "toCam", 1, true)
)
ok("everything goes with the wearer (LockedToPart)", string.find(lib, "e.LockedToPart = true", 1, true) ~= nil)

print("The pictures")
local names, wants = {}, true
for name in Auras.Sheets do
	names[name] = true
end
local usedGrid = {}
for _, spec in specs do
	for _, l in spec.Layers do
		wants = wants and names[l.Picture] == true
		usedGrid[l.Picture] = l.Grid
	end
end
ok("every layer's picture is in Auras.Sheets", wants and names.Ribbon)
local sized, count = true, 0
for name in Auras.Sheets do
	count += 1
	local path = `art/ui/aura_volume/{string.lower(name)}.png`
	if not fs.isFile(path) then
		ok(`{path} is there`, false)
		sized = false
		continue
	end
	local head = buffer.fromstring(string.sub(fs.readFile(path), 1, 24))
	local w = bit32.byteswap(buffer.readu32(head, 16))
	local h = bit32.byteswap(buffer.readu32(head, 20))
	local grid = usedGrid[name] or 1
	sized = sized and w % grid == 0 and h % grid == 0 and w <= 1024 and h <= 1024
end
ok("twelve pictures, at most 1024 px, a whole number of frames", sized and count == 12, count)
-- (by the picture's file, as the old look's table says which it drew as a bubble, a spark)
local bad = 0
local oldPictures = string.match(controller, "local TEX = (%b{})") or ""
for name, file in string.gmatch(oldPictures, '(%w+) = "rbxasset://textures/particles/([%w_]+)') do
	if name == "Bubble" or name == "Spark" then
		bad += 1
		ok(`the old look's {name} picture stands in for none of ours`, string.find(lib, file, 1, true) == nil, file)
	end
end
ok("(both found)", bad == 2, bad)
local blank = true
for _, id in Auras.Sheets do
	blank = blank and (id == "" or string.match(id, "^rbxassetid://%d+$") ~= nil)
end
ok("each is empty (not uploaded) or an id", blank)

print("The switch")
ok("Config.Aura.Look is 2, and Flame is gone", c.Look == 2 and c.Flame == nil)
ok(
	"the old looks are still there (1 and 0)",
	string.find(controller, "AuraBeams.build", 1, true) ~= nil
		and string.find(controller, "Build[tier](fx)", 1, true) ~= nil
		and string.find(controller, "Config.Aura.Flame", 1, true) == nil
)
local known = true
for service, names_ in
	{
		RideService = { "RideWeld", "LandWeld" },
		TankRideService = { "TankRideWeld" },
		TrainService = { "TrainerWeld" },
	}
do
	local source: string = world.find(`ServerScriptService.Server.Services.{service}`).Source
	for _, name in names_ do
		-- (the name the server gives the weld, and the one the controller looks for)
		known = known
			and string.find(source, `weld.Name = "{name}"`, 1, true) ~= nil
			and string.find(controller, `{name} = true`, 1, true) ~= nil
	end
end
ok("every weld a rider hangs from is known by the name its service gives it", known)
local seats = true
for name, service in { TankRide = "TankRideService", TrainerRide = "TrainService", LandMounted = "RideService" } do
	local source: string = world.find(`ServerScriptService.Server.Services.{service}`).Source
	seats = seats
		and string.find(source, `SetAttribute("{name}"`, 1, true) ~= nil
		and string.find(controller, `GetAttribute("{name}")`, 1, true) ~= nil
end
ok("and so are the seats' attributes", seats)
ok(
	"the hop holds the aura as it stood on the last fish",
	string.find(controller, 'state == "Jumping"', 1, true) ~= nil
		and string.find(lib, "hold and a.Ridden", 1, true) ~= nil
)
local theirs, theirBody, theirSeat = fish("HammerheadShark", 1, 12, nil)
local own = V.ride(specs[12], theirBody, theirSeat, 17.7, calm)
local through, allOfIt = true, true
for _, l in specs[12].Layers do
	through = through and (not l.Across or V.rate(l, own, 3, c) == 0)
	allOfIt = allOfIt and (l.Name == "Shock" or V.rate(l, theirs, 3, c) > 0)
end
ok("with EyeCalm 1 nothing of ours stands across our view; theirs is whole", through and allOfIt)

print("Smaller, less apparent (Config.Aura.Small)")
ok("off in the file, three to choose from: A, B, C", c.Small == 0 and #c.Smalls == 3 and c.Smalls[2].Name == "B")
local lastOut, lastSolid, lastFoot = {}, {}, {}
for i, set in c.Smalls do
	local cc = table.clone(c)
	cc.Small = i
	local function riding(tier: number, body: any, at: any, eye: number?): any
		return V.ride(specs[tier], body, at, eye, cc)
	end
	local hugs, alike, grows, cut, seen, less, named = true, true, true, true, true, true, true
	local far, near, gone, through = true, true, true, true
	local last: any = nil
	for tier = 1, 12 do
		local spec = specs[tier]
		local low, high = riding(tier, Vector3.new(3, 4, 8), Vector3.new(0, 2, 0), nil), nil
		for id in Config.FishById do
			for _, scale in { 1, 3 } do
				local body = Config.FishById[id].Size * scale
				local at = Vector3.new(0, body.Y * 0.1 + 2, -body.Z * 0.1)
				high = riding(tier, body, at, 17.7)
				alike = alike
					and high.X == low.X
					and high.Z == low.Z
					and high.Height == low.Height
					and high.Grow == low.Grow
					and not high.Own
				hugs = hugs
					and high.At.X == at.X
					and high.At.Z == at.Z
					and math.abs(high.At.Y - (at.Y - V.Saddle + set.Lift)) < 1e-3
			end
		end
		hugs = hugs and low.X >= 2 and low.X <= 3.6 and low.Height <= 4.3
		local foot0, foot = V.foot(spec), V.foot(spec, cc)
		less = less
			and foot.X < foot0.X
			and foot.Height < foot0.Height
			and foot.Grow < 1
			and V.strong(spec, foot, cc) < 1
			and V.strong(spec, low, cc) < 1
		local now = { Wide = low.X, High = low.Height, Alive = 0, Wisp = 0, Foot = foot.X, FootHigh = foot.Height }
		for _, l in spec.Layers do
			local rate = V.rate(l, low, 3, cc)
			now.Alive += rate * (l.Life[1] + l.Life[2]) / 2
			for _, name in { "Pool", "Ring", "Sweeps", "Shock", "Haze", "Pillar" } do
				-- (what lies on the ground, fills the air or stands as a column is not on the ride)
				cut = cut and (l.Name ~= name or (rate == 0 and not V.there(l.Name, low, cc)))
			end
			if l.Name == "Wisps" then
				seen = seen and rate >= 18 and V.part("Wisps", low, cc) > 0.8 and V.rate(l, low, 1, cc) >= 9
				now.Wisp = l.Size[1][2] * low.Grow
			end
			named = named and V.there(l.Name, foot, cc)
			if V.there(l.Name, low, cc) then
				-- (its near side is drawn behind the rider's middle)
				near = near and V.behind(l.Name, l.Wide, low) >= low.X * l.Wide + 0.5
			end
			far = far and V.behind(l.Name, l.Wide, foot) == 0
		end
		cut = cut and V.part("Light", low, cc) == 0
		for _, s in spec.Strands do
			for j = 1, s.Beams + 1 do
				for step = 0, 24 do
					local p = V.strandAt(s, low, j, step * 0.4, step * 0.3)
					through = through and math.sqrt(p.X ^ 2 + p.Z ^ 2) <= low.X * V.Hug * 1.06
					if set.Low[s.Name] then
						through = through and p.Y <= set.Low[s.Name] * 1.1
					end
				end
			end
			near = near and (set.Low[s.Name] ~= nil or V.behind(s.Name, V.Hug, low) > low.X * V.Hug)
		end
		if last then
			grows = grows
				and now.Wide > last.Wide
				and now.High > last.High
				and now.Wisp > last.Wisp
				and now.Alive >= last.Alive * 0.97
				and now.Foot > last.Foot
				and now.FootHigh > last.FootHigh
		end
		last = now
		-- half-way onto a fish it is between the two, never past either
		local half = V.between(foot, low, 0.5)
		gone = gone and half.Ride == 0.5 and half.Small == set and half.X <= math.max(foot.X, low.X)
		if i > 1 then
			less = less
				and low.X < lastOut[tier]
				and V.strong(spec, low, cc) < lastSolid[tier]
				and foot.X < lastFoot[tier]
		end
		lastOut[tier], lastSolid[tier], lastFoot[tier] = low.X, V.strong(spec, low, cc), foot.X
	end
	local n = set.Name
	ok(`{n}: riding, round the rider only, the same on every fish and for every eye`, hugs and alike)
	ok(`{n}: less than it was, standing and riding, and less than the letter before`, less)
	ok(`{n}: bigger by tier, standing and riding`, grows and last.Alive > 18)
	ok(`{n}: riding, no ground ring, pool, strokes, shock, haze, pillar or light`, cut)
	ok(`{n}: riding, tier 1 up is always seen, far away and on a phone too`, seen)
	ok(`{n}: standing, no tier loses a piece, nothing is pushed behind`, named and far)
	ok(`{n}: riding, all but the low ribbon is drawn behind the rider`, near)
	ok(`{n}: riding, the ribbons keep close, the low one under the chest`, through)
	ok(`{n}: on and off a fish it goes over smoothly`, gone)
	local known = {}
	for _, l in specs[12].Layers do
		known[l.Name] = true
	end
	for _, s in specs[12].Strands do
		known[s.Name] = true
	end
	known.Light = true
	local real = true
	for _, list in { set.Foot, set.Ride, set.Low } do
		for name, share in list do
			real = real and known[name] == true and share >= 0
		end
	end
	ok(`{n}: every piece it names is one there is`, real)
end
ok(
	"turning the switch makes the auras worn again",
	string.find(controller, "small ~= Config.Aura.Small", 1, true) ~= nil
)
ok(
	"a piece the ride leaves out lets nothing out in a flare, a burst or a pulse",
	string.find(lib, "AuraVolume.there(p.Layer.Name, s, c)", 1, true) ~= nil
		and string.find(lib, 'AuraVolume.there("Shock", shape, c)', 1, true) ~= nil
)
done()
