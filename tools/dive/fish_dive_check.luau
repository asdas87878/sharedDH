-- Every fish dives off the lip (docs/design/dive-in.md, "The leap on a fish"; task d1, Hugo 2026-11-24). Offline, in
-- Lune, on the game's own DiveController and Config (tools/dive/world.luau): all the kinds in Config.Fish, at every
-- size tier (capped by rarity and by SizeLimit as in the game; a colour never changes a size). The lip and its gate are
-- the map GENERATOR's own boxes (tools/dive/lip_boxes.py), not the saved place's parts, and nothing here is drawn or
-- run by the engine: it is sums, no play.
--   1 the plan: each kind and size straight out from the middle of the lip at the land pace (does it dive, on which arc
--     of FISH_TRIES, does its rider go under WaterY, how deep its box cuts the floor, what the film shows of it);
--   2 everywhere: five places along the lip, three ways of running, half and full pace, and gone over the edge already;
--   3 the steps: walked at the line and through the real body and camera steps, with the server's swap under WaterY:
--     begun at the line, nothing broken, let go to the ride, no jump of the body or the view;
--   4 the fish's own motion: its joints as the land hook writes them, a frame at a time;
--   5 with a sub's trip: "Carried" under WaterY lets everything go on that frame.
-- usage: python3 tools/dive/lip_boxes.py . /tmp/lip.json
--        rojo build -o /tmp/place.rbxl
--        lune run tools/dive/fish_dive_check.luau /tmp/place.rbxl /tmp/lip.json [out.json] [parts, 12345] [paths.json]
--        (part 2 is the long one, ten to fifteen minutes; "1345" is half a minute. paths.json: what tools/dive/dive_picture.py draws)
-- It prints FAIL lines and a count at the end, and exits 1 on any.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local World = require("./world")

local V3, CF = roblox.Vector3, roblox.CFrame
local world = World.open(process.args[1], process.args[2])
local Config, Dive = world.Config, world.Dive
local FLOOR, OUT = 0.5, V3.new(0, 0, 1)
local PACE = Config.Equip.LandSpeed
local PARTS = process.args[4] or "12345" -- (which of the five to run)
local fails = 0
local function fail(text: string)
	fails += 1
	if fails <= 60 then
		print("FAIL " .. text)
	end
end

-- the fish's ends: the middle of each face of its box (its nose, tail, sides, back and belly; the box's corners are
-- further out than any fish)
local function tipsOf(f: any)
	local m = (f.low + f.high) / 2
	return {
		V3.new(0, m.Y, f.low.Z),
		V3.new(0, m.Y, f.high.Z),
		V3.new(f.low.X, m.Y, m.Z),
		V3.new(f.high.X, m.Y, m.Z),
		V3.new(0, f.low.Y, m.Z),
		V3.new(0, f.high.Y, m.Z),
	}
end

-- where a point is in the view, in half-heights up and half-widths across (inside: both within -1..1), 16:9
local function seen(view: any, fov: number, at: any): (number, number)
	local p = view:PointToObjectSpace(at)
	local tan = math.tan(math.rad(fov) / 2)
	if p.Z > -0.05 then
		return 9, 9
	end
	return math.abs(p.Y / (-p.Z * tan)), math.abs(p.X / (-p.Z * tan * 16 / 9))
end

type Row = { [string]: any }
local results: { Row } = {}
-- (where the land camera is behind a rider: EquipController keeps it as far as the fish is big)
local function camBack(f: any): any
	local least = math.max(f.size.X, f.size.Y, f.size.Z) * Config.Equip.CameraFrom
	return V3.new(0, 0.3, -0.95) * math.max(math.min(least, Config.Equip.CameraMost), 17)
end
local function planAt(f: any, x: number, heading: any, speed: number, crouch: boolean, z: number?, y: number?)
	local start = V3.new(x, FLOOR + f.height + (y or 0), z or -2.5)
	local cam = CF.lookAt(start + camBack(f), start)
	return Dive.planOf(start, FLOOR, heading, speed, crouch, cam, 70, { low = f.low, high = f.high })
end

local function film(f: any, p: any, sums: any): Row
	local tips = tipsOf(f)
	local row: Row =
		{ outAt = {}, rider = 0, fish = 0, fishAt = 0, inBox = 0, pulled = 1, wall = 0, frames = 0, out = 0 }
	local t = 0.3
	while t <= p.tFollow do
		local at = sums.frameAt(t)
		local view, fov = sums.viewAt(t)
		local ry, rx = seen(view, fov, at.Position + V3.new(0, 1, 0))
		row.rider = math.max(row.rider, ry, rx)
		row.frames += 1
		if t < p.tEntry then
			local worst = 0
			for _, c in tips do
				local cy, cx = seen(view, fov, at * c)
				worst = math.max(worst, cy, cx)
			end
			if worst > 1 then
				row.out += 1
				table.insert(row.outAt, t)
			end
			if worst > row.fish then
				row.fish, row.fishAt = worst, t
			end
		end
		-- the camera in the fish's box
		local inner = at:PointToObjectSpace(view.Position)
		if
			inner.X > f.low.X
			and inner.X < f.high.X
			and inner.Y > f.low.Y
			and inner.Y < f.high.Y
			and inner.Z > f.low.Z
			and inner.Z < f.high.Z
		then
			row.inBox += 1
			row.inBoxAt = row.inBoxAt or t
		end
		-- walls between it and the fish (the camera step pulls it in to them)
		local anchor = at.Position + V3.new(0, 0.6, 0)
		local arm = view.Position - anchor
		local hit, part = world.cast(anchor, arm, 0)
		if hit and not (p.aloft and t < p.tEntry) then
			row.wall += 1
			local n = part.Name
			row.walls = row.walls or {}
			row.walls[n] = (row.walls[n] or 0) + 1
			row.pulled = math.min(row.pulled, hit)
		end
		t += 1 / 30
	end
	return row
end

-- how deep the fish's box goes into the floor it leaves, over the lip's line (studs)
local function floorCut(f: any, p: any, sums: any): number
	local worst = 0
	local t = 0
	while t <= p.tEntry do
		local at = sums.frameAt(t)
		for i = 0, 12 do
			local z = f.low.Z + (f.high.Z - f.low.Z) * i / 12
			local point = at * V3.new(0, f.low.Y, z)
			if point.Z < 0 then
				worst = math.max(worst, FLOOR - point.Y)
			end
		end
		t += 1 / 30
	end
	return worst
end

-- how much of the fish, studs of its length, is still back of the lip as the rider goes under (the swap), and how deep its
-- box is in the dock by then (its tail goes down through the dock: nothing stops a body there)
local function dockAtSwap(f: any, p: any, sums: any): (number, number)
	local at = sums.frameAt(p.tUnder)
	local tailZ, deep = 0, 0
	for i = 0, 24 do
		local z = f.low.Z + (f.high.Z - f.low.Z) * i / 24
		local point = at * V3.new(0, f.low.Y, z)
		if point.Z < 0 then
			tailZ = math.max(tailZ, -point.Z)
			deep = math.max(deep, FLOOR - point.Y)
		end
	end
	return tailZ, deep
end

print(`{#Config.Fish} kinds, {#Config.SizeOrder} sizes; LeapMounted {Config.Dive.LeapMounted}`)

------------------------------------------------------------------------------------------------------------------ 1, 2
local byTry: { [number]: number } = {}
local places, dived = 0, 0
for _, kind in Config.Fish do
	for _, tier in Config.SizeOrder do
		local f = World.landFish(world, kind, tier)
		local name = `{kind.Id} {tier}`
		local p, why, sums = planAt(f, 0, OUT, PACE, true)
		local row: Row = {
			kind = kind.Id,
			tier = tier,
			length = f.size.Z,
			width = f.size.X,
			height = f.size.Y,
			dives = p ~= nil,
			tries = #why + 1,
			why = why,
		}
		if not p then
			fail(`{name}: no dive: {table.concat(why, " | ")}`)
		else
			byTry[#why + 1] = (byTry[#why + 1] or 0) + 1
			local last = sums.frameAt(p.tEntry + p.sink + 0.1)
			row.endY = last.Y
			row.under = p.tUnder
			row.high, row.far, row.air = p.a * p.a / (4 * p.c), p.far, p.air
			row.camScale, row.aloft = p.camScale, p.aloft
			row.pace = p.far / p.air
			row.cut = floorCut(f, p, sums)
			row.back, row.deep = dockAtSwap(f, p, sums)
			row.film = film(f, p, sums)
			if last.Y > Config.Oxygen.WaterY - 1 then
				fail(`{name}: ends at {last.Y}, not under WaterY`)
			end
			if p.far / p.air > PACE * Config.Equip.PaceRoom then
				fail(`{name}: {p.far / p.air} studs/s across, over the land pace check`)
			end
			if row.back > 0.25 * f.size.Z then
				fail(`{name}: {row.back} studs of it still back of the lip at the swap, in the dock`)
			end
			if row.film.rider > 1 then
				fail(`{name}: the rider goes out of the view ({row.film.rider})`)
			end
			if row.film.inBox > 0 then
				fail(
					`{name}: the camera is inside the fish's box for {row.film.inBox} frames of 30 a second, from {row.film.inBoxAt} s of {p.tEntry}`
				)
			end
			-- the swap: how far the body jumps when the server puts the water fish under the rider (its Root at the land
			-- fish's against where SubService.diveFish makes it now: 4 ahead of the rider's root and 3 under)
			local at = sums.frameAt(p.tUnder)
			local landRoot = (at * CF.new(-f.seat)).Position
			row.swap = (landRoot - (at.Position + OUT * 4 - V3.new(0, 3, 0))).Magnitude
			local saddled = (CF.lookAt(at.Position, at.Position + OUT) * CF.new(-f.seat)).Position
			row.swapSaddled = (landRoot - saddled).Magnitude
			row.tiltUnder = sums.tiltAt(p.tUnder)
		end
		table.insert(results, row)
		for _, x in if string.find(PARTS, "2") then { -44, -25, 0, 25, 44 } else {} do
			for _, turn in { -40, 0, 40 } do
				for _, speed in { 10, PACE } do
					local way = CF.fromAxisAngle(V3.new(0, 1, 0), math.rad(turn)) * OUT
					places += 1
					if planAt(f, x, way, speed, true) or planAt(f, x, OUT, speed, true) then
						dived += 1
					else
						fail(`{name}: no dive at x {x}, {turn} degrees, {speed} studs/s`)
					end
				end
			end
			-- over the edge already, falling
			for _, y in { 0, -2 } do
				places += 1
				if planAt(f, x, OUT, 5, false, 1.5, y) then
					dived += 1
				else
					fail(`{name}: no dive from over the edge at x {x}, {y}`)
				end
			end
		end
	end
end
local tries = {}
for n, count in byTry do
	table.insert(tries, `arc {n}: {count}`)
end
print(`1 the plan: {#results} of {78 * 6}; ` .. table.concat(tries, ", "))
print(`2 everywhere: {dived} of {places} dive`)
local worst: { [string]: { any } } = {}
local function most(key: string, value: number, text: string)
	if not worst[key] or value > worst[key][1] then
		worst[key] = { value, text }
	end
end
for _, r in results do
	if r.film then
		local name = `{r.kind} {r.tier} ({math.floor(r.length)} long)`
		most("the rider furthest from the view's middle (1: the edge)", r.film.rider, name)
		most("the fish's end furthest out (1: the edge; in the air)", r.film.fish, `{name} at {r.film.fishAt}`)
		most("frames with an end of it out of view (share)", r.film.out / r.film.frames, name)
		most("the camera pulled in (share of its distance lost)", 1 - r.film.pulled, name)
		most("its box into the floor it leaves, studs", r.cut, name)
		most("its box into the floor, share of its height", r.cut / r.height, name)
		most("across the ground, studs/s", r.pace, name)
		most("the swap onto the water fish now, studs", r.swap, name)
		most("the swap if put by its saddle, studs", r.swapSaddled, name)
		most("its tilt at the swap, degrees", math.abs(r.tiltUnder), name)
	end
end
for key, w in worst do
	print(`   most {key}: {math.floor(w[1] * 100) / 100} ({w[2]})`)
end

--------------------------------------------------------------------------------------------------------------------- 3
-- walked at the line and through the real steps. `water`: what the server says under WaterY ("Riding" or "Carried")
local camera = world.space.CurrentCamera
local function run(kind: any, tier: string, water: string, spy: ((number, any) -> ())?): Row
	local f = World.landFish(world, kind, tier)
	local root, model = World.mount(world, kind, f, V3.new(3, FLOOR + f.height, -20))
	world.clock += 10
	camera.CFrame = CF.lookAt(root.Position + camBack(f), root.Position)
	camera.FieldOfView = 70
	local row: Row = { name = `{kind.Id} {tier}`, length = f.size.Z }
	local wasAt, wasView = root.Position, camera.CFrame
	local swapAt: number? = nil
	for i = 1, 60 * 8 do
		world.clock += 1 / 60
		local began = world.State.Leaping
		if not began and not row.began then
			-- walked on, 32 studs a second; off the edge it would fall
			root.CFrame = CF.lookAt(root.Position, root.Position + OUT) + OUT * (PACE / 60)
			root.AssemblyLinearVelocity = OUT * PACE
		end
		world.steps.DiveBody(1 / 60)
		if world.anim.LandHook and not swapAt then
			row.moved = world.anim.LandHook(model, "Cruiser", 0, 0)
		end
		world.steps.DiveCamera(1 / 60)
		local log = Dive.log()
		if log.active and not row.began then
			row.began = root.Position.Z
			row.beganAt = world.clock
			row.plan = log.plan
		end
		if row.began then
			local t = world.clock - row.beganAt
			row.step = math.max(row.step or 0, (root.Position - wasAt).Magnitude)
			if log.filming and t > 0.05 then
				local moved = (camera.CFrame.Position - wasView.Position).Magnitude
				if moved > (row.viewStep or 0) then
					row.viewStep, row.viewStepAt = moved, t
				end
				local turned = math.deg(math.acos(math.clamp(camera.CFrame.LookVector:Dot(wasView.LookVector), -1, 1)))
				if turned > (row.viewTurn or 0) then
					row.viewTurn, row.viewTurnAt = turned, t
				end
			end
			if spy then
				spy(t, model)
			end
		end
		wasAt, wasView = root.Position, camera.CFrame
		if log.active and not swapAt and root.Position.Y < Config.Oxygen.WaterY then
			-- (a tenth of a second later the word comes)
			swapAt = world.clock + 0.1
		end
		if swapAt and world.clock >= swapAt and world.State.Mode == "Dock" then
			world.me.attributes.LandMounted = false
			world.me.attributes.State = water
			world.State.Mode = water
			world.land = nil
			row.swapped = world.clock - row.beganAt
		end
		if row.began and not log.active then
			row.over = world.clock - row.beganAt
			break
		end
	end
	local log = Dive.log()
	row.broken = log.broken
	row.events = {}
	for _, e in log.events do
		table.insert(row.events, e.what or e.name or e[1] or "?")
		if (e.what or e.name) == "release" then
			row.release = e.why
		end
	end
	row.log = log
	return row
end

-- a diver's own, to hold the fish's against
local diver: Row
do
	local root =
		World.mount(world, Config.Fish[1], World.landFish(world, Config.Fish[1], "Normal"), V3.new(3, FLOOR + 3, -20))
	world.me.attributes.LandMounted = nil
	world.me.humanoid.HipHeight = 2
	diver = { began = false }
	camera.CFrame = CF.lookAt(root.Position + V3.new(0, 6, -17), root.Position)
	local wasView, at = camera.CFrame, 0
	for _ = 1, 60 * 4 do
		world.clock += 1 / 60
		if not world.State.Leaping then
			root.CFrame = CF.lookAt(root.Position, root.Position + OUT) + OUT * (16 / 60)
			root.AssemblyLinearVelocity = OUT * 16
		elseif not diver.began then
			diver.began = root.Position.Z
			at = world.clock
		end
		world.steps.DiveBody(1 / 60)
		world.steps.DiveCamera(1 / 60)
		if diver.began and Dive.log().filming and world.clock - at > 0.05 and world.State.Leaping then
			local turned = math.deg(math.acos(math.clamp(camera.CFrame.LookVector:Dot(wasView.LookVector), -1, 1)))
			if turned > (diver.turn or 0) then
				diver.turn, diver.turnAt = turned, world.clock - at
			end
		end
		wasView = camera.CFrame
	end
	Dive.hold(nil)
	print(
		`   (a diver on foot: begun at z {diver.began}, the view turns at most {diver.turn} degrees in a frame, at {diver.turnAt} s)`
	)
end

local ran, stepsFine = 0, 0
local firstZ: { number } = {}
for _, kind in Config.Fish do
	for _, tier in { Config.SizeOrder[1], "Normal", Config.SizeOrder[#Config.SizeOrder] } do
		local before = fails
		local r = run(kind, tier, "Riding")
		ran += 1
		if r.broken then
			fail(`{r.name}: the steps broke: {table.concat(world.warnings, " / ")}`)
			break
		elseif not r.began then
			fail(`{r.name}: walked over the line and no dive began ({table.concat(Dive.log().whyNot, " | ")})`)
		else
			table.insert(firstZ, r.began)
			if not r.swapped then
				fail(`{r.name}: never under WaterY`)
			end
			if not r.over then
				fail(`{r.name}: the dive never ended`)
			end
			if not r.moved then
				fail(`{r.name}: its joints were not moved`)
			end
			if (r.step or 0) > 2.5 then
				fail(`{r.name}: the body jumps {r.step} studs in a frame`)
			end
			if (r.viewTurn or 0) > 1.35 * diver.turn then
				fail(`{r.name}: the view turns {r.viewTurn} degrees in a frame at {r.viewTurnAt} s`)
			end
		end
		most("body's step in a frame, studs", r.step or 0, r.name)
		most("view's step in a frame, studs", r.viewStep or 0, `{r.name} at {r.viewStepAt}`)
		most("view's turn in a frame, degrees", r.viewTurn or 0, `{r.name} at {r.viewTurnAt}`)
		if fails == before then
			stepsFine += 1
		end
	end
end
print(
	`3 the steps: {stepsFine} of {ran} run whole; begun at z {math.min(table.unpack(firstZ))} to {math.max(
		table.unpack(firstZ)
	)} (the lip is 0)`
)
for _, key in { "body's step in a frame, studs", "view's step in a frame, studs", "view's turn in a frame, degrees" } do
	print(`   most {key}: {math.floor(worst[key][1] * 100) / 100} ({worst[key][2]})`)
end

--------------------------------------------------------------------------------------------------------------------- 4
local still, popped, mostTurn = 0, 0, 0
local popText = ""
for _, kind in Config.Fish do
	local was: { [string]: any } = {}
	local movedBy = 0
	run(kind, "Normal", "Riding", function(_t: number, model: any)
		for name, motor in model.motors do
			local now = motor.Transform
			local before = was[name]
			if before then
				local _, angle = (before:Inverse() * now):ToAxisAngle()
				angle = math.deg(math.abs(angle))
				movedBy += angle
				if angle > mostTurn then
					mostTurn, popText = angle, `{kind.Id} {name}`
				end
			end
			was[name] = now
		end
	end)
	if movedBy < 5 then
		still += 1
		fail(`{kind.Id}: its joints hardly move in the dive ({movedBy} degrees in all)`)
	end
	if popped > 0 then
		fail(`{kind.Id}: pops`)
	end
end
print(
	`4 its own motion: {#Config.Fish - still} of {#Config.Fish} kinds move their joints; most in a frame {math.floor(
		mostTurn * 10
	) / 10} degrees ({popText})`
)
if mostTurn > 25 then
	fail(`a joint turns {mostTurn} degrees in one frame ({popText})`)
end

--------------------------------------------------------------------------------------------------------------------- 5
local handed = 0
for _, id in { "SergeantMajor", "GreatWhite", "BlueWhale" } do
	local kind = Config.FishById[id]
	local r = run(kind, "Normal", "Carried")
	local hand = Dive.handOver()
	if not r.over or not hand or hand.why ~= "Carried" then
		fail(`{id}: not handed over at Carried`)
	elseif r.over - r.swapped > 1 / 30 then
		fail(`{id}: handed over {r.over - r.swapped} s after Carried`)
	else
		handed += 1
		print(
			string.format(
				"   %s: handed over on the Carried frame at %.2f s, root y %.1f, %.0f studs/s, the view %.0f over the water",
				id,
				r.over,
				hand.position.Y,
				hand.velocity.Magnitude,
				hand.view.Y
			)
		)
	end
end
print(`5 with a sub: {handed} of 3 handed over`)
for _, text in world.warnings do
	print("warning: " .. text)
end
if process.args[3] then
	for _, r in results do
		r.why = table.concat(r.why, " | ")
	end
	fs.writeFile(process.args[3], serde.encode("json", results))
end
if process.args[5] then
	-- three dives from the side, a frame at a time (the body's box in its own frame, where the middle of it is)
	local paths = {}
	for _, pick in { { "SergeantMajor", "Tiny" }, { "GreatWhite", "Normal" }, { "BlueWhale", "Colossal" } } do
		local kind = Config.FishById[pick[1]]
		local f = World.landFish(world, kind, pick[2])
		local frames: { Row } = {}
		local r = run(kind, pick[2], "Riding", function(t: number)
			local at = world.me.root.CFrame
			local middle = at * ((f.low + f.high) / 2)
			table.insert(frames, {
				t = t,
				z = at.Position.Z,
				y = at.Position.Y,
				mz = middle.Z,
				my = middle.Y,
				lz = at.LookVector.Z,
				ly = at.LookVector.Y,
			})
		end)
		table.insert(paths, {
			name = pick[1],
			tier = pick[2],
			length = f.size.Z,
			height = f.size.Y,
			frames = frames,
			swap = r.swapped,
			over = r.over,
			entry = r.plan and r.plan.tEntry,
		})
	end
	fs.writeFile(process.args[5], serde.encode("json", { floor = FLOOR, waterY = Config.Oxygen.WaterY, paths = paths }))
end
print(if fails == 0 then "ALL PASS" else `{fails} FAILS`)
process.exit(if fails == 0 then 0 else 1)
