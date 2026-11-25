-- Every fish's leap off the lip, for the air hop's check (tools/subs/air_check.luau): the dive's own plans
-- (DiveController.planOf, over the map generator's boxes round the lip: tools/dive/world.luau), every kind of Config.Fish
-- at every size, straight out from the lip's middle, and from its sides and at a slant for the kinds at their own size
-- and the biggest. Written as JSON: one row a leap, in the dive check's frame (the lip is z = 0, +z out, x = 0 its middle).
-- usage: python3 tools/dive/lip_boxes.py . /tmp/lip.json; rojo build -o /tmp/place.rbxl
--        lune run tools/subs/air_leaps.luau /tmp/place.rbxl /tmp/lip.json /tmp/leaps.json   (about 2 minutes)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local World = require("../dive/world")

local V3, CF = roblox.Vector3, roblox.CFrame
local world = World.open(process.args[1], process.args[2])
local Config, Dive = world.Config, world.Dive
local FLOOR, OUT = 0.5, V3.new(0, 0, 1)
local N = 13

local rows = {}
local none = 0
local function add(kind: any, tier: string, x: number, slant: number, crouch: boolean)
	local f = World.landFish(world, kind, tier)
	local a = math.rad(slant)
	local heading = V3.new(math.sin(a), 0, math.cos(a))
	local start = V3.new(x, FLOOR + f.height, if crouch then -2.5 else 1)
	local least = math.max(f.size.X, f.size.Y, f.size.Z) * Config.Equip.CameraFrom
	local cam = CF.lookAt(
		start + V3.new(0, 0.3, -0.95) * math.max(math.min(least, Config.Equip.CameraMost), 17),
		start
	)
	local p, _, sums = Dive.planOf(
		start,
		FLOOR,
		heading,
		Config.Equip.LandSpeed,
		crouch,
		cam,
		70,
		{ low = f.low, high = f.high }
	)
	if not p then
		none += 1
		print("no plan", kind.Id, tier, x, slant)
		return
	end
	local tilts = {}
	for i = 0, N - 1 do
		table.insert(tilts, sums.tiltAt(p.crouch + p.air * i / (N - 1) - (if i == N - 1 then 1e-4 else 0)))
	end
	local poses = {} -- the dive's own root, to hold the air hop's sums against
	for i = 0, 8 do
		local cf = sums.frameAt(p.crouch + p.air * i / 8 - (if i == 8 then 1e-4 else 0))
		local l = cf.LookVector
		table.insert(poses, { cf.X, cf.Y, cf.Z, l.X, l.Y, l.Z })
	end
	table.insert(rows, {
		id = kind.Id,
		tier = tier,
		x = x,
		slant = slant,
		crouched = crouch,
		size = { f.size.X, f.size.Y, f.size.Z },
		seat = { f.seat.X, f.seat.Y, f.seat.Z },
		take = { p.takeoff.X, p.takeoff.Y, p.takeoff.Z },
		heading = { p.heading.X, p.heading.Z },
		start = { start.X, start.Y, start.Z },
		cam = { cam.X, cam.Y, cam.Z },
		far = p.far,
		a = p.a,
		c = p.c,
		crouch = p.crouch,
		air = p.air,
		tilts = tilts,
		poses = poses,
	})
end

for _, kind in Config.Fish do
	for _, tier in Config.SizeOrder do
		add(kind, tier, 0, 0, true)
	end
	for _, tier in { "Normal", "Colossal" } do
		for _, at in { { -36, 0 }, { 36, 0 }, { -20, 30 }, { 20, 30 }, { 0, -38 } } do
			add(kind, tier, at[1], at[2], true)
		end
	end
	add(kind, "Normal", 0, 0, false)
end
fs.writeFile(process.args[3], serde.encode("json", rows))
print(#rows .. " leaps, " .. none .. " without a plan")
