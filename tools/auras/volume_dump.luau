-- The 3D auras' own numbers for the offline pictures (tools/auras/volume_shots.py): Shared/AuraVolume's spec, places and
-- ribbons, written as JSON, so a picture is drawn from what the game draws.
-- usage: lune run tools/auras/volume_dump.luau <place.rbxl> <out.json> <times, comma separated> [Config.Aura.Small]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Harness = require("../index/harness")

local world = Harness.open(process.args[1])
local V = world.require(world.find("ReplicatedStorage.Shared.AuraVolume"))
local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
local Vector3: any = roblox.Vector3
local small = tonumber(process.args[4] or "0") :: number

local function xyz(v: any): { number }
	return { v.X, v.Y, v.Z }
end
local function rgb(v: any): { number }
	return { v.R, v.G, v.B }
end

local times: { number } = {}
for n in string.gmatch(process.args[3] or "6", "[%d%.]+") do
	table.insert(times, tonumber(n) :: number)
end

-- the mounts of the pictures: a fish kind's own size, the rider where its saddle is (FishModel)
local function mount(id: string): any
	local body = Config.FishById[id].Size
	local rig = serde.decode("json", fs.readFile(`src/shared/Creatures/{id}.json`))
	local k = body.Z / rig.Size[3]
	local at = rig.Seat
	return { Id = id, Body = body, Seat = Vector3.new(at[1] * k, at[2] * k + Config.Ride.SeatHeight, at[3] * k) }
end
local scenes: { any } = {}
for tier = 1, 12 do
	table.insert(scenes, { Name = `foot{tier}`, Tier = tier })
end
for _, id in { "Clownfish", "HammerheadShark", "Livyatan" } do
	for _, tier in { 1, 6, 12 } do
		-- (as another player sees it, and as its rider does)
		table.insert(scenes, { Name = `{id}{tier}`, Tier = tier, Mount = mount(id) })
		table.insert(scenes, { Name = `{id}{tier}own`, Tier = tier, Mount = mount(id), Eye = 17.7 })
		table.insert(scenes, { Name = `{id}{tier}calm`, Tier = tier, Mount = mount(id), Eye = 17.7, Calm = true })
	end
end

local out = {}
for _, scene in scenes do
	local spec = V.spec(scene.Tier)
	local m = scene.Mount
	local c = table.clone(Config.Aura)
	c.Small = small
	c.EyeCalm = if scene.Calm then 1 else c.EyeCalm
	local shape = if m then V.ride(spec, m.Body, m.Seat, scene.Eye, c) else V.foot(spec, c)
	local layers = {}
	for _, l in spec.Layers do
		local up, size = V.place(l, shape)
		local row: { [string]: any } = {}
		for key, v in l :: any do
			row[key] = if key == "Color" or key == "Color2" then rgb(v) else v
		end
		row.Up = up
		row.Rate = V.rate(l, shape, 3, c)
		row.Box = xyz(size)
		row.Part = V.part(l.Name, shape, c)
		row.There = V.there(l.Name, shape, c)
		row.Behind = V.behind(l.Name, l.Wide, shape)
		table.insert(layers, row)
	end
	local frames = {}
	for _, t in times do
		local clock = t * (if m then spec.RideFast else 1)
		local wide, bright = V.moment(spec, t, nil)
		local strands = {}
		for _, s in spec.Strands do
			local joints = {}
			for i = 1, s.Beams + 1 do
				local pos, along, handle = V.strandAt(s, shape, i, clock, t)
				table.insert(joints, {
					At = xyz(pos),
					Along = xyz(along),
					Handle = handle,
					Width = V.strandWidth(s, (i - 1) / s.Beams) * wide * shape.Grow,
				})
			end
			local fade = {}
			for i = 0, s.Beams * 4 do
				table.insert(
					fade,
					V.strandFade(i / (s.Beams * 4))
						* (1 - s.Transparency)
						* spec.Strength
						* V.strong(spec, shape, c)
						* V.part(s.Name, shape, c)
				)
			end
			table.insert(strands, {
				Name = s.Name,
				There = V.there(s.Name, shape, c),
				Behind = V.behind(s.Name, V.Hug, shape),
				Joints = joints,
				Fade = fade,
				Color = rgb(s.Color),
				Head = rgb(s.Head),
				Emission = s.Emission,
				Offset = (clock * s.Flow) % 1,
			})
		end
		table.insert(frames, { T = t, Clock = clock, Wide = wide, Bright = bright, Strands = strands })
	end
	table.insert(out, {
		Name = scene.Name,
		Tier = scene.Tier,
		Mount = if m then { Id = m.Id, Body = xyz(m.Body), Seat = xyz(m.Seat) } else nil,
		Shape = { X = shape.X, Z = shape.Z, Height = shape.Height, At = xyz(shape.At), Grow = shape.Grow },
		Strength = spec.Strength * V.strong(spec, shape, c),
		Layers = layers,
		Frames = frames,
		Light = if spec.Light
			then {
				Range = spec.Light.Range,
				Bright = spec.Light.Bright * V.part("Light", shape, c),
				Color = rgb(spec.Light.Color),
			}
			else nil,
		Pulse = if spec.Pulse then spec.Pulse.Every else nil,
		Small = small,
		Draws = { V.draws(spec, 1), V.draws(spec, 2), V.draws(spec, 3) },
		Alive = { V.alive(spec, 1), V.alive(spec, 2), V.alive(spec, 3) },
	})
end
fs.writeFile(process.args[2], serde.encode("json", out))
for tier = 1, 12 do
	local d = out[tier]
	print(tier, table.concat(d.Draws, " "), string.format("%.0f %.0f %.0f", d.Alive[1], d.Alive[2], d.Alive[3]))
end
