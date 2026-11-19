--!strict
-- The twelve auras and the spawn-in (Shared/Auras; Hugo, 2026-11-19). DRAFT 1, task a1: drawn but not bought yet.
-- Every machine draws every player's aura round their character from the player's "Aura" attribute (a tier, 1 to 12),
-- and plays the spawn-in (Auras.SpawnStyle) when any character appears. Nothing here replicates or touches the
-- character's own parts (the spawn-in's fade uses LocalTransparencyModifier, this machine's own, and puts it back).
--
-- How it is drawn: each aura is a few client-side Parts (chunky blocks, like the creatures; Neon where it glows),
-- particle emitters, trails and a light, in a Folder under workspace "AuraFx". The blocks are anchored and placed
-- every frame round the character's feet (turned with the character's heading only, so a tilting fish doesn't tip
-- the rings), all in one workspace:BulkMoveTo. An aura far from the camera (Auras.DrawRange) is taken out of the
-- world until it comes back. Each tier's look is its own builder below; they add up in what they show: bubbles,
-- foam, a wave, currents, coral, a storm, rings, lanterns, fire, ghosts, a void, a serpent.
--
-- Captures (Studio only): workspace "AuraClock" as a number holds the animation's clock (particles still run in real
-- time); a Model tagged "AuraRig" shows its own "Aura" attribute, and its "SpawnAt" (a clock time) plays its
-- "SpawnStyle" from then. tools/studio/aura_capture.py drives it.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Auras = require(game:GetService("ReplicatedStorage").Shared.Auras)

local AuraController = {}

local STUDIO = RunService:IsStudio()
local TEX = {
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Embers = "rbxasset://textures/particles/fire_sparks_main.dds",
	Implode = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	Square = "rbxasset://textures/particles/SquareParticle.png",
}
local TAU = math.pi * 2

local function now(): number
	if STUDIO then
		local c = workspace:GetAttribute("AuraClock")
		if type(c) == "number" then
			return c
		end
	end
	return os.clock()
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- A NumberSequence from a number or from {time, value} pairs
local function seq(v: any): NumberSequence
	if type(v) == "number" then
		return NumberSequence.new(v)
	end
	local keys = {}
	for _, k in v do
		table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2]))
	end
	return NumberSequence.new(keys)
end

local function cseq(a: Color3, b: Color3?): ColorSequence
	return ColorSequence.new(a, b or a)
end

---------------------------------------------------------------------------------------------------------------------
-- The kit: an Fx is one aura or one spawn-in, its parts and its per-frame steps
---------------------------------------------------------------------------------------------------------------------

type Step = (t: number, base: CFrame, fx: Fx) -> ()
export type Fx = {
	Folder: Folder,
	Steps: { Step },
	Moves: { BasePart },
	To: { CFrame },
	Data: { [string]: any },
}

local root: Folder

local function newFx(name: string): Fx
	local f = Instance.new("Folder")
	f.Name = name
	return { Folder = f, Steps = {}, Moves = {}, To = {}, Data = {} }
end

local function step(fx: Fx, s: Step)
	table.insert(fx.Steps, s)
end

-- Queue a part's place for this frame's BulkMoveTo
local function put(fx: Fx, p: BasePart, cf: CFrame)
	table.insert(fx.Moves, p)
	table.insert(fx.To, cf)
end

local function block(fx: Fx, size: Vector3, color: Color3, material: Enum.Material?, alpha: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Transparency = alpha or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = fx.Folder
	return p
end

-- An unseen part that rides with the feet at `offset`: emitters (its size is their area) and lights live on it
local function area(fx: Fx, size: Vector3, offset: CFrame): Part
	local p = block(fx, size, Color3.new(), Enum.Material.SmoothPlastic, 1)
	step(fx, function(_t: number, base: CFrame)
		put(fx, p, base * offset)
	end)
	return p
end

local function emit(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	e.LightEmission = 1
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function light(fx: Fx, color: Color3, brightness: number, range: number, height: number): PointLight
	local a = area(fx, Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, height, 0))
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = a
	return l
end

-- A ring of blocks round the feet. o: n, radius, height, speed (turns a second), size, color (or colorAt(i, t)),
-- tilt (a CFrame turning the ring's plane), bob (studs), spin (block turns a second), alpha, material, wave (a
-- function(i, a, t) -> y offset, scale)
local function ring(fx: Fx, o: { [string]: any }): { Part }
	local parts = {}
	for _ = 1, o.n do
		local c = if o.color then o.color else rgb(255, 255, 255)
		table.insert(parts, block(fx, o.size, c, o.material, o.alpha))
	end
	local tilt: CFrame = o.tilt or CFrame.identity
	local phase = o.phase or 0
	step(fx, function(t: number, base: CFrame)
		for i, p in parts do
			local a = (i - 1) / o.n * TAU + t * (o.speed or 0) * TAU + phase
			local y = o.height
			local scale = 1
			if o.bob then
				y += math.sin(t * 2.2 + i * 1.7) * o.bob
			end
			if o.wave then
				local dy, s = o.wave(i, a, t)
				y += dy
				scale = s or 1
			end
			local r = o.radius
			if o.radiusAt then
				r = o.radiusAt(i, t)
			end
			local spin = (o.spin or 0) * t * TAU
			local at = tilt * Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local cf = base * CFrame.new(at + Vector3.new(0, y, 0)) * CFrame.Angles(spin * 0.7, -a + spin, spin * 0.4)
			put(fx, p, cf)
			if scale ~= 1 then
				p.Size = o.size * scale
			end
			if o.colorAt then
				p.Color = o.colorAt(i, t)
			end
			if o.alphaAt then
				p.Transparency = o.alphaAt(i, t)
			end
		end
	end)
	return parts
end

-- Blocks that rise from the feet and fade out at the top, each on its own phase. o: n, radius, from, to, period,
-- size, color, alpha, wobble, spin
local function riser(fx: Fx, o: { [string]: any }): { Part }
	local parts = {}
	local rnd = Random.new(o.seed or 7)
	local info = {}
	for i = 1, o.n do
		table.insert(parts, block(fx, o.size, o.color, o.material, o.alpha))
		table.insert(info, {
			a = rnd:NextNumber() * TAU,
			r = o.radius * (0.6 + rnd:NextNumber() * 0.5),
			ph = (i - 1) / o.n + rnd:NextNumber() * 0.08,
			s = 0.7 + rnd:NextNumber() * 0.5,
		})
	end
	step(fx, function(t: number, base: CFrame)
		for i, p in parts do
			local k = info[i]
			local u = (t / o.period + k.ph) % 1
			local y = o.from + (o.to - o.from) * u
			local w = (o.wobble or 0.3) * math.sin(t * 3 + i)
			local a = k.a + (o.swirl or 0) * u * TAU
			local cf = base
				* CFrame.new(math.cos(a) * (k.r + w), y, math.sin(a) * (k.r + w))
				* CFrame.Angles(t * (o.spin or 1) + i, t * 0.8 * (o.spin or 1), 0)
			put(fx, p, cf)
			local fade = if u > 0.7 then (u - 0.7) / 0.3 else (if u < 0.08 then 1 - u / 0.08 else 0)
			p.Transparency = (o.alpha or 0) + (1 - (o.alpha or 0)) * fade
			p.Size = o.size * k.s * (1 - 0.4 * u)
			if o.colorAt then
				p.Color = o.colorAt(i, u, t)
			end
		end
	end)
	return parts
end

-- A trail drawn by a carrier moving along path(t) -> Vector3 (feet space)
local function trailer(
	fx: Fx,
	path: (number) -> Vector3,
	color: ColorSequence,
	width: number,
	life: number,
	alpha: any?
)
	local c = block(fx, Vector3.new(0.2, 0.2, 0.2), Color3.new(), Enum.Material.SmoothPlastic, 1)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = c
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = c
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Color = color
	tr.Lifetime = life
	tr.LightEmission = 1
	tr.LightInfluence = 0
	tr.FaceCamera = true
	tr.Transparency = seq(alpha or { { 0, 0.1 }, { 1, 1 } })
	tr.WidthScale = seq({ { 0, 1 }, { 1, 0.2 } })
	tr.Parent = c
	step(fx, function(t: number, base: CFrame)
		put(fx, c, base * CFrame.new(path(t)))
	end)
	return c
end

-- Lightning: jagged bolts of thin Neon blocks, a new shape every `every` seconds, shown `duty` of the time.
-- o: bolts, segs, from(rnd) -> Vector3, to(rnd) -> Vector3, color, width, every, duty, jag
local function lightning(fx: Fx, o: { [string]: any })
	local bolts = {}
	for b = 1, o.bolts do
		local segs = {}
		for _ = 1, o.segs do
			table.insert(segs, block(fx, Vector3.new(o.width, o.width, 1), o.color))
		end
		bolts[b] = segs
	end
	step(fx, function(t: number, base: CFrame)
		local tick = math.floor(t / o.every)
		for b, segs in bolts do
			local rnd = Random.new(tick * 31 + b * 7 + (o.seed or 0))
			local on = rnd:NextNumber() < o.duty
			local p0: Vector3 = o.from(rnd)
			local p1: Vector3 = o.to(rnd)
			local last = p0
			for s, part in segs do
				local u = s / #segs
				local p = p0:Lerp(p1, u)
				if s < #segs then
					p += Vector3.new(rnd:NextNumber(-1, 1), rnd:NextNumber(-0.5, 0.5), rnd:NextNumber(-1, 1)) * o.jag
				end
				local mid = (last + p) / 2
				local len = (p - last).Magnitude
				part.Size = Vector3.new(o.width, o.width, math.max(len, 0.05))
				part.Transparency = if on then 0 else 1
				put(fx, part, base * CFrame.lookAt(mid, p))
				last = p
			end
		end
	end)
end

local function flicker(t: number, i: number): number
	return 0.5 + 0.5 * math.sin(t * 13.1 + i * 2.3) * math.sin(t * 7.7 + i)
end

---------------------------------------------------------------------------------------------------------------------
-- The twelve tiers. Feet at y = 0, a character about 5 studs tall, "forward" -Z.
---------------------------------------------------------------------------------------------------------------------

local function bubbles(fx: Fx, n: number, color: Color3, size: number?, speedy: number?)
	riser(fx, {
		n = n,
		radius = 2.2,
		from = 0.2,
		to = 6.6,
		period = 3.4 / (speedy or 1),
		size = Vector3.one * (size or 0.42),
		color = color,
		alpha = 0.35,
		wobble = 0.35,
		material = Enum.Material.Neon,
		seed = n,
	})
end

local function motes(parent: Instance, color: ColorSequence, rate: number, size: number?, tex: string?)
	return emit(parent, {
		Texture = tex or TEX.Glow,
		Color = color,
		Rate = rate,
		Lifetime = NumberRange.new(1.4, 2.4),
		Speed = NumberRange.new(0.6, 1.6),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
		Size = seq({ { 0, 0 }, { 0.2, size or 0.35 }, { 1, 0 } }),
		Transparency = seq({ { 0, 0.3 }, { 1, 1 } }),
		Acceleration = Vector3.new(0, 1.2, 0),
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
end

local Build: { (Fx) -> () } = {}

-- 1 Bubble: bubbles drift up round you
Build[1] = function(fx: Fx)
	bubbles(fx, 8, rgb(190, 235, 255))
	motes(area(fx, Vector3.new(4, 4, 4), CFrame.new(0, 2.5, 0)), cseq(rgb(220, 245, 255)), 3, 0.25)
end

-- 2 Foam: a ring of foam lapping at the feet, more bubbles
Build[2] = function(fx: Fx)
	bubbles(fx, 10, rgb(225, 248, 255))
	ring(fx, {
		n = 14,
		radius = 2.6,
		height = 0.2,
		speed = 0.06,
		size = Vector3.new(0.9, 0.3, 0.9),
		color = rgb(240, 252, 255),
		bob = 0.12,
		alpha = 0.15,
	})
	emit(area(fx, Vector3.new(5.4, 0.2, 5.4), CFrame.new(0, 0.2, 0)), {
		Texture = TEX.Smoke,
		Color = cseq(rgb(255, 255, 255)),
		Rate = 10,
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(0.2, 0.5),
		Size = seq({ { 0, 0.4 }, { 1, 1.1 } }),
		Transparency = seq({ { 0, 0.55 }, { 1, 1 } }),
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		LightEmission = 0.4,
	})
end

-- 3 Tide: a wave's crest runs round the feet, teal going white at the top
Build[3] = function(fx: Fx)
	local teal, white = rgb(40, 210, 200), rgb(220, 255, 250)
	ring(fx, {
		n = 22,
		radius = 2.8,
		height = 0.25,
		speed = 0,
		size = Vector3.new(0.8, 0.5, 0.8),
		color = teal,
		wave = function(_i: number, a: number, t: number)
			local crest = math.max(0, math.cos(a - t * 3.2)) ^ 3
			return crest * 1.6, 1 + crest * 0.6
		end,
		colorAt = function(i: number, t: number)
			local a = (i - 1) / 22 * TAU
			local crest = math.max(0, math.cos(a - t * 3.2)) ^ 3
			return teal:Lerp(white, crest)
		end,
	})
	bubbles(fx, 8, rgb(170, 255, 240))
	emit(area(fx, Vector3.new(5.6, 0.2, 5.6), CFrame.new(0, 0.4, 0)), {
		Texture = TEX.Glow,
		Color = cseq(white, teal),
		Rate = 14,
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(20, 20),
		Acceleration = Vector3.new(0, -9, 0),
		Size = seq({ { 0, 0.3 }, { 1, 0.1 } }),
		Transparency = seq({ { 0, 0.2 }, { 1, 1 } }),
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
end

-- 4 Current: three streaks spiral up round you, a fast ring under them
Build[4] = function(fx: Fx)
	local blue, pale = rgb(40, 170, 255), rgb(190, 245, 255)
	for k = 0, 2 do
		trailer(fx, function(t: number)
			local u = (t / 1.5 + k / 3) % 1
			local a = u * TAU * 1.6 + k * TAU / 3
			local r = 2.6 - u * 0.8
			return Vector3.new(math.cos(a) * r, 0.2 + u * 6.2, math.sin(a) * r)
		end, cseq(pale, blue), 0.45, 0.45)
	end
	ring(fx, {
		n = 12,
		radius = 2.7,
		height = 0.2,
		speed = 0.6,
		size = Vector3.new(0.9, 0.25, 0.35),
		color = blue,
		alpha = 0.1,
	})
	bubbles(fx, 6, pale, 0.35, 1.8)
	motes(area(fx, Vector3.new(4, 5, 4), CFrame.new(0, 2.5, 0)), cseq(pale, blue), 8, 0.3)
end

-- 5 Reef: coral blocks orbit the waist, a small reef ring turns the other way, sparkles
Build[5] = function(fx: Fx)
	local coral = { rgb(255, 110, 150), rgb(255, 160, 70), rgb(255, 220, 90), rgb(190, 110, 255) }
	local parts = ring(fx, {
		n = 6,
		radius = 2.9,
		height = 2.6,
		speed = 0.18,
		size = Vector3.new(0.75, 0.75, 0.75),
		bob = 0.45,
		spin = 0.35,
		material = Enum.Material.Neon,
	})
	for i, p in parts do
		p.Color = coral[(i - 1) % #coral + 1]
	end
	local low = ring(fx, {
		n = 9,
		radius = 2.1,
		height = 0.45,
		speed = -0.12,
		size = Vector3.new(0.5, 0.9, 0.5),
		bob = 0.15,
	})
	for i, p in low do
		p.Color = coral[(i + 1) % #coral + 1]
		p.Material = Enum.Material.SmoothPlastic
	end
	emit(area(fx, Vector3.new(5, 5, 5), CFrame.new(0, 2.6, 0)), {
		Texture = TEX.Spark,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 130, 170)),
			ColorSequenceKeypoint.new(1, rgb(255, 225, 100)),
		}),
		Rate = 12,
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(0.3, 0.8),
		Size = seq({ { 0, 0 }, { 0.3, 0.5 }, { 1, 0 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		Shape = Enum.ParticleEmitterShape.Sphere,
	})
	bubbles(fx, 5, rgb(255, 200, 220), 0.35)
end

-- 6 Storm: a dark cloud over your head, lightning to the ground, sparks
Build[6] = function(fx: Fx)
	local yellow, cloud = rgb(255, 240, 110), rgb(60, 70, 110)
	local puffs = ring(fx, {
		n = 7,
		radius = 1.1,
		height = 7,
		speed = 0.05,
		size = Vector3.new(1.4, 0.9, 1.4),
		color = cloud,
		material = Enum.Material.SmoothPlastic,
		bob = 0.2,
	})
	for i, p in puffs do
		p.Color = cloud:Lerp(rgb(110, 120, 160), (i % 3) / 3)
	end
	emit(area(fx, Vector3.new(3.4, 0.6, 3.4), CFrame.new(0, 7.2, 0)), {
		Texture = TEX.Smoke,
		Color = cseq(rgb(70, 80, 120), rgb(40, 45, 70)),
		Rate = 14,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(0.1, 0.4),
		Size = seq({ { 0, 1.2 }, { 1, 2.2 } }),
		Transparency = seq({ { 0, 0.45 }, { 1, 1 } }),
		LightEmission = 0,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	lightning(fx, {
		bolts = 2,
		segs = 6,
		width = 0.18,
		color = yellow,
		every = 0.09,
		duty = 0.45,
		jag = 0.55,
		from = function(r: Random)
			return Vector3.new(r:NextNumber(-1, 1), 6.7, r:NextNumber(-1, 1))
		end,
		to = function(r: Random)
			local a = r:NextNumber() * TAU
			local d = r:NextNumber(2.4, 3.4)
			return Vector3.new(math.cos(a) * d, 0.1, math.sin(a) * d)
		end,
	})
	emit(area(fx, Vector3.new(6, 0.2, 6), CFrame.new(0, 0.2, 0)), {
		Texture = TEX.Embers,
		Color = cseq(yellow, rgb(255, 255, 255)),
		Rate = 18,
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(50, 50),
		Acceleration = Vector3.new(0, -14, 0),
		Size = seq({ { 0, 0.35 }, { 1, 0 } }),
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	local l = light(fx, yellow, 0, 14, 4)
	step(fx, function(t: number)
		l.Brightness = if math.floor(t / 0.09) % 3 == 0 then 3 else 0.3
	end)
end

-- 7 Moon: two silver rings turn on tilted axes like a gyroscope, a little moon circles your head, starlight
Build[7] = function(fx: Fx)
	local silver, lilac = rgb(225, 230, 255), rgb(165, 135, 255)
	for k, tiltDeg in { 32, -32 } do
		ring(fx, {
			n = 16,
			radius = 3.2,
			height = 2.8,
			speed = if k == 1 then 0.22 else -0.22,
			size = Vector3.new(0.5, 0.5, 0.5),
			tilt = CFrame.Angles(math.rad(tiltDeg), 0, math.rad(tiltDeg * 0.4)),
			colorAt = function(i: number, t: number)
				return silver:Lerp(lilac, 0.5 + 0.5 * math.sin(i * 0.8 + t * 2 + k))
			end,
		})
	end
	local moon = block(fx, Vector3.new(1.1, 1.1, 1.1), rgb(245, 245, 255))
	moon.Shape = Enum.PartType.Ball
	step(fx, function(t: number, base: CFrame)
		local a = t * 0.9
		put(fx, moon, base * CFrame.new(math.cos(a) * 1.6, 6.8 + math.sin(t * 1.3) * 0.2, math.sin(a) * 1.6))
	end)
	emit(area(fx, Vector3.new(7, 7, 7), CFrame.new(0, 3, 0)), {
		Texture = TEX.Spark,
		Color = cseq(silver, lilac),
		Rate = 16,
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(0, 0.2),
		Size = seq({ { 0, 0 }, { 0.5, 0.45 }, { 1, 0 } }),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	light(fx, lilac, 1.5, 12, 3)
end

-- 8 Lantern: four glowing lanterns circle you at different heights, warm motes, a warm ring
Build[8] = function(fx: Fx)
	local gold, orange = rgb(255, 205, 80), rgb(255, 125, 40)
	local lanterns: { any } = {}
	for i = 1, 4 do
		local body = block(fx, Vector3.new(0.85, 1, 0.85), gold)
		local cap = block(fx, Vector3.new(1, 0.25, 1), rgb(90, 50, 30), Enum.Material.SmoothPlastic)
		local foot = block(fx, Vector3.new(1, 0.2, 1), rgb(90, 50, 30), Enum.Material.SmoothPlastic)
		table.insert(lanterns, { body, cap, foot, i } :: { any })
	end
	step(fx, function(t: number, base: CFrame)
		for _, l in lanterns do
			local i = l[4]
			local a = t * 0.35 + i * TAU / 4
			local y = 1.6 + (i % 2) * 2.4 + math.sin(t * 1.4 + i) * 0.35
			local cf = base
				* CFrame.new(math.cos(a) * 3.3, y, math.sin(a) * 3.3)
				* CFrame.Angles(0, -a * 2, math.sin(t * 2 + i) * 0.15)
			put(fx, l[1], cf)
			put(fx, l[2], cf * CFrame.new(0, 0.62, 0))
			put(fx, l[3], cf * CFrame.new(0, -0.6, 0))
			l[1].Color = gold:Lerp(rgb(255, 245, 190), flicker(t, i) * 0.6)
		end
	end)
	ring(fx, {
		n = 12,
		radius = 2.4,
		height = 0.15,
		speed = 0.05,
		size = Vector3.new(0.45, 0.2, 0.45),
		color = orange,
		alphaAt = function(i: number, t: number)
			return 0.1 + 0.5 * flicker(t, i)
		end,
	})
	motes(area(fx, Vector3.new(6, 4, 6), CFrame.new(0, 2, 0)), cseq(gold, orange), 14, 0.4)
	local lt = light(fx, gold, 2, 16, 3)
	step(fx, function(t: number)
		lt.Brightness = 1.6 + 0.6 * flicker(t, 0)
	end)
end

-- 9 Ember: fire rising from the feet, sparks, a ring of hot blocks, embers drifting up
Build[9] = function(fx: Fx)
	local hot, deep, yellow = rgb(255, 120, 30), rgb(220, 40, 20), rgb(255, 235, 130)
	local floor = area(fx, Vector3.new(4.8, 0.2, 4.8), CFrame.new(0, 0.2, 0))
	emit(floor, {
		Texture = TEX.Fire,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, yellow),
			ColorSequenceKeypoint.new(0.4, hot),
			ColorSequenceKeypoint.new(1, deep),
		}),
		Rate = 40,
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(3, 5),
		SpreadAngle = Vector2.new(8, 8),
		Size = seq({ { 0, 1 }, { 0.5, 0.8 }, { 1, 0 } }),
		Transparency = seq({ { 0, 0.4 }, { 0.6, 0.6 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	emit(floor, {
		Texture = TEX.Embers,
		Color = cseq(yellow, hot),
		Rate = 22,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(20, 20),
		Size = seq({ { 0, 0.3 }, { 1, 0 } }),
		Shape = Enum.ParticleEmitterShape.Disc,
	})
	ring(fx, {
		n = 12,
		radius = 2.8,
		height = 0.5,
		speed = 0.25,
		size = Vector3.new(0.6, 0.6, 0.6),
		spin = 0.6,
		bob = 0.25,
		colorAt = function(i: number, t: number)
			return hot:Lerp(yellow, flicker(t, i))
		end,
	})
	riser(fx, {
		n = 10,
		radius = 2.3,
		from = 0.5,
		to = 7.5,
		period = 2.2,
		size = Vector3.one * 0.35,
		color = hot,
		swirl = 0.4,
		seed = 9,
		colorAt = function(_i: number, u: number)
			return yellow:Lerp(deep, u)
		end,
	})
	local lt = light(fx, hot, 2, 16, 2)
	step(fx, function(t: number)
		lt.Brightness = 1.6 + 1.2 * flicker(t, 3)
	end)
end

-- 10 Phantom: ghost wisps swirl round you, ghost blocks flicker in and out, a pale mist
Build[10] = function(fx: Fx)
	local mint, violet = rgb(110, 255, 190), rgb(175, 110, 255)
	for k = 0, 3 do
		trailer(fx, function(t: number)
			local a = t * (1.1 + k * 0.15) + k * TAU / 4
			local r = 2.4 + math.sin(t * 1.7 + k) * 0.7
			return Vector3.new(math.cos(a) * r, 2.8 + math.sin(t * 2.3 + k * 1.3) * 2.2, math.sin(a) * r)
		end, cseq(if k % 2 == 0 then mint else violet, rgb(255, 255, 255)), 0.6, 0.9, { { 0, 0.15 }, { 1, 1 } })
	end
	ring(fx, {
		n = 10,
		radius = 3.4,
		height = 3,
		speed = -0.12,
		size = Vector3.new(0.6, 0.6, 0.6),
		spin = 0.2,
		wave = function(i: number, _a: number, t: number)
			return math.sin(t * 1.5 + i * 0.9) * 1.6
		end,
		colorAt = function(i: number, t: number)
			return mint:Lerp(violet, 0.5 + 0.5 * math.sin(t + i))
		end,
		alphaAt = function(i: number, t: number)
			return 0.15 + 0.85 * (1 - flicker(t * 0.6, i)) ^ 2
		end,
	})
	emit(area(fx, Vector3.new(5, 0.4, 5), CFrame.new(0, 0.5, 0)), {
		Texture = TEX.Smoke,
		Color = cseq(mint, violet),
		Rate = 10,
		Lifetime = NumberRange.new(1.6, 2.4),
		Speed = NumberRange.new(0.5, 1.2),
		Size = seq({ { 0, 0.8 }, { 1, 2.4 } }),
		Transparency = seq({ { 0, 0.7 }, { 1, 1 } }),
		Shape = Enum.ParticleEmitterShape.Disc,
	})
	motes(area(fx, Vector3.new(5, 6, 5), CFrame.new(0, 3, 0)), cseq(mint), 10, 0.3)
	light(fx, mint, 1.5, 12, 3)
end

-- 11 Abyss: a void halo over your head, three dark rings on crossing axes, light pulled in, violet arcs, a pulse
Build[11] = function(fx: Fx)
	local purple, void, bright = rgb(160, 70, 255), rgb(25, 5, 45), rgb(230, 190, 255)
	ring(fx, {
		n = 12,
		radius = 1.3,
		height = 6.6,
		speed = 0.5,
		size = Vector3.new(0.35, 0.35, 0.35),
		colorAt = function(i: number, t: number)
			return purple:Lerp(bright, 0.5 + 0.5 * math.sin(t * 4 + i))
		end,
	})
	for k, tilt in
		{
			CFrame.Angles(math.rad(70), 0, 0),
			CFrame.Angles(0, 0, math.rad(70)),
			CFrame.Angles(math.rad(25), 0, math.rad(-25)),
		}
	do
		local parts = ring(fx, {
			n = 18,
			radius = 3.4,
			height = 3,
			speed = 0.15 * (if k == 2 then -1 else 1) * (1 + k * 0.2),
			size = Vector3.new(0.45, 0.45, 0.45),
			tilt = tilt,
		})
		for i, p in parts do
			p.Color = if i % 3 == 0 then purple else void
			p.Material = if i % 3 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
	emit(area(fx, Vector3.new(11, 11, 11), CFrame.new(0, 3, 0)), {
		Texture = TEX.Glow,
		Color = cseq(bright, purple),
		Rate = 30,
		Lifetime = NumberRange.new(0.7, 0.9),
		Speed = NumberRange.new(6, 7),
		Size = seq({ { 0, 0.5 }, { 1, 0 } }),
		Transparency = seq({ { 0, 1 }, { 0.3, 0.2 }, { 1, 0 } }),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	lightning(fx, {
		bolts = 2,
		segs = 5,
		width = 0.14,
		color = bright,
		every = 0.11,
		duty = 0.5,
		jag = 0.45,
		seed = 11,
		from = function(r: Random)
			local a = r:NextNumber() * TAU
			return Vector3.new(math.cos(a) * 3.4, r:NextNumber(1, 5), math.sin(a) * 3.4)
		end,
		to = function(r: Random)
			local a = r:NextNumber() * TAU
			return Vector3.new(math.cos(a) * 1.3, 6.6, math.sin(a) * 1.3)
		end,
	})
	-- a pulse along the floor every 1.6 s
	ring(fx, {
		n = 20,
		radius = 1,
		height = 0.1,
		speed = 0,
		size = Vector3.new(0.6, 0.2, 0.6),
		color = purple,
		radiusAt = function(_i: number, t: number)
			return 1 + ((t / 1.6) % 1) * 6
		end,
		alphaAt = function(_i: number, t: number)
			return (t / 1.6) % 1
		end,
	})
	light(fx, purple, 2.5, 16, 3)
end

-- 12 Leviathan: a rainbow serpent coils up round you, two rainbow rings turn against each other, pillars of light,
-- stars in every colour
Build[12] = function(fx: Fx)
	local function hue(h: number, s: number?): Color3
		return Color3.fromHSV(h % 1, s or 0.6, 1)
	end
	local body = {}
	local N = 28
	for i = 1, N do
		local s = if i == 1 then 0.95 else 0.75 - (i / N) * 0.4
		table.insert(body, block(fx, Vector3.one * s, Color3.new(1, 1, 1)))
	end
	-- the head's eyes and fins
	local eyes = {
		block(fx, Vector3.new(0.18, 0.18, 0.18), rgb(20, 0, 30)),
		block(fx, Vector3.new(0.18, 0.18, 0.18), rgb(20, 0, 30)),
	}
	local function along(t: number, u: number): Vector3
		-- u = 0 head to 1 tail; the coil climbs and falls, turning round the player
		local a = t * 1.3 - u * TAU * 1.7
		local y = 3.4 + math.sin(t * 0.8 - u * 3) * 2.6
		local r = 3 + math.sin(t * 0.6 + u * 4) * 0.5
		return Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
	end
	step(fx, function(t: number, base: CFrame)
		for i, p in body do
			local u = (i - 1) / (N - 1) * 0.9
			local here = along(t, u)
			local ahead = along(t, u - 0.02)
			local cf = CFrame.lookAt(here, ahead)
			put(fx, p, base * cf)
			p.Color = hue(t * 0.15 + u * 1.2)
			if i == 1 then
				put(fx, eyes[1], base * cf * CFrame.new(0.3, 0.2, -0.3))
				put(fx, eyes[2], base * cf * CFrame.new(-0.3, 0.2, -0.3))
			end
		end
	end)
	for k, h in { 0.3, 7.2 } do
		ring(fx, {
			n = 20,
			radius = if k == 1 then 3.2 else 1.6,
			height = h,
			speed = if k == 1 then 0.2 else -0.35,
			size = Vector3.new(0.5, if k == 1 then 0.3 else 0.4, 0.5),
			colorAt = function(i: number, t: number)
				return hue(i / 20 + t * 0.2 * (if k == 1 then 1 else -1))
			end,
		})
	end
	local pillars = {}
	for _ = 1, 4 do
		table.insert(pillars, block(fx, Vector3.new(0.3, 9, 0.3), Color3.new(1, 1, 1), nil, 0.4))
	end
	step(fx, function(t: number, base: CFrame)
		for i, p in pillars do
			local a = i * TAU / 4 + t * 0.25 + math.pi / 4
			put(fx, p, base * CFrame.new(math.cos(a) * 4.3, 4.5, math.sin(a) * 4.3))
			p.Transparency = 0.25 + 0.6 * (0.5 + 0.5 * math.sin(t * 3 + i * 1.6))
			p.Color = hue(t * 0.15 + i / 4, 0.35)
		end
	end)
	trailer(
		fx,
		function(t: number)
			return along(t, 0.92)
		end,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, hue(0)),
			ColorSequenceKeypoint.new(0.33, hue(0.33)),
			ColorSequenceKeypoint.new(0.66, hue(0.66)),
			ColorSequenceKeypoint.new(1, hue(0.99)),
		}),
		0.4,
		0.6
	)
	emit(area(fx, Vector3.new(8, 8, 8), CFrame.new(0, 3.5, 0)), {
		Texture = TEX.Spark,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 120, 200)),
			ColorSequenceKeypoint.new(0.25, rgb(255, 220, 120)),
			ColorSequenceKeypoint.new(0.5, rgb(130, 255, 170)),
			ColorSequenceKeypoint.new(0.75, rgb(120, 200, 255)),
			ColorSequenceKeypoint.new(1, rgb(200, 140, 255)),
		}),
		Rate = 26,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(0.2, 0.6),
		Size = seq({ { 0, 0 }, { 0.4, 0.55 }, { 1, 0 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
		Shape = Enum.ParticleEmitterShape.Sphere,
	})
	local lt = light(fx, Color3.new(1, 1, 1), 2.5, 18, 3.5)
	step(fx, function(t: number)
		lt.Color = hue(t * 0.15, 0.4)
	end)
end

---------------------------------------------------------------------------------------------------------------------
-- The spawn-in: three versions, each about 1.6 s. Built like an aura, but with a start time; the character fades in
-- during it (this machine only).
---------------------------------------------------------------------------------------------------------------------

local SPAWN_TIME = { 1.3, 1.7, 1.5 }

-- fire a burst of particles once, when the clock first passes `at`
local function burstAt(fx: Fx, key: string, at: number, e: ParticleEmitter, n: number)
	step(fx, function(t: number)
		if t >= at and not fx.Data[key] then
			fx.Data[key] = true
			e:Emit(n)
		end
	end)
end

local Spawn: { (Fx) -> (number) -> number } = {}
-- Each returns how visible the character is at time u (seconds since the start)

-- 1 Splash: a column of bubbles shoots up, a ring of water blocks bursts out across the floor, spray
Spawn[1] = function(fx: Fx)
	local aqua, white = rgb(60, 220, 255), rgb(235, 252, 255)
	local col: { any } = {}
	local rnd = Random.new(3)
	for _ = 1, 14 do
		table.insert(
			col,
			{
				block(fx, Vector3.one * rnd:NextNumber(0.35, 0.7), white:Lerp(aqua, rnd:NextNumber())),
				rnd:NextNumber() * TAU,
				rnd:NextNumber(0.3, 1.4),
				rnd:NextNumber(0, 0.25),
			} :: { any }
		)
	end
	local wave = {}
	for _ = 1, 18 do
		table.insert(wave, block(fx, Vector3.new(0.9, 0.9, 0.9), aqua))
	end
	local spray = emit(area(fx, Vector3.new(2, 0.2, 2), CFrame.new(0, 0.3, 0)), {
		Texture = TEX.Glow,
		Color = cseq(white, aqua),
		Rate = 0,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -25, 0),
		Size = seq({ { 0, 0.5 }, { 1, 0.1 } }),
		Transparency = seq({ { 0, 0 }, { 1, 1 } }),
		Shape = Enum.ParticleEmitterShape.Disc,
	})
	burstAt(fx, "spray", 0.12, spray, 45)
	step(fx, function(t: number, base: CFrame)
		local u = t - fx.Data.Start
		for _, c in col do
			local p, a, r, delay = c[1], c[2], c[3], c[4]
			local k = math.clamp((u - delay) / 0.7, 0, 1)
			put(
				fx,
				p,
				base * CFrame.new(math.cos(a) * r, -0.5 + k * 8, math.sin(a) * r) * CFrame.Angles(u * 4, u * 3, 0)
			)
			p.Transparency = if k <= 0 then 1 else k ^ 2
		end
		local k = math.clamp((u - 0.1) / 0.9, 0, 1)
		local e = 1 - (1 - k) ^ 3
		for i, p in wave do
			local a = (i - 1) / #wave * TAU
			local r = 0.8 + e * 6.5
			local y = math.sin(k * math.pi) * 1.2
			put(fx, p, base * CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * CFrame.Angles(0, -a, k * 2))
			p.Transparency = if u < 0.1 then 1 else k ^ 1.5
			p.Size = Vector3.new(0.9, 0.9 + (1 - k) * 0.8, 0.9) * (1 - k * 0.5)
		end
	end)
	return function(u: number)
		return math.clamp((u - 0.1) / 0.3, 0, 1)
	end
end

-- 2 Whirlpool: three arms of glowing blocks wind up round you, tightening and quickening, then burst outward in a
-- flash of sparks as you appear
Spawn[2] = function(fx: Fx)
	local teal, white, deep = rgb(40, 230, 220), rgb(240, 255, 255), rgb(30, 120, 255)
	local arms: { any } = {}
	for k = 1, 3 do
		for i = 1, 9 do
			table.insert(arms, { block(fx, Vector3.one * 0.55, teal), k, i } :: { any })
		end
	end
	local pop = emit(area(fx, Vector3.new(2, 5, 2), CFrame.new(0, 2.6, 0)), {
		Texture = TEX.Spark,
		Color = cseq(white, teal),
		Rate = 0,
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(10, 18),
		Drag = 5,
		Size = seq({ { 0, 0.8 }, { 1, 0 } }),
		Rotation = NumberRange.new(0, 360),
		Shape = Enum.ParticleEmitterShape.Sphere,
	})
	burstAt(fx, "pop", 1.15, pop, 60)
	local flash = light(fx, white, 0, 18, 2.6)
	step(fx, function(t: number, base: CFrame)
		local u = t - fx.Data.Start
		local wind = math.clamp(u / 1.15, 0, 1)
		local after = math.clamp((u - 1.15) / 0.5, 0, 1)
		for _, a in arms do
			local p, k, i = a[1], a[2], a[3]
			local s = (i - 1) / 8
			local turn = wind ^ 1.6 * 3.2 + k / 3 - s * 0.35
			local ang = turn * TAU
			local r = (5.5 - 4 * wind) * (1 - s * 0.3) + after * 7
			local y = s * 6 * math.min(1, wind * 1.6) + 0.1
			put(fx, p, base * CFrame.new(math.cos(ang) * r, y, math.sin(ang) * r) * CFrame.Angles(u * 6, -ang, 0))
			p.Color = deep:Lerp(white, wind * (1 - s * 0.5))
			local show = math.clamp(u / 0.15 - s, 0, 1)
			p.Transparency = 1 - show + after
		end
		flash.Brightness = if u > 1.1 then math.max(0, 6 * (1 - (u - 1.15) / 0.4)) else 0
	end)
	return function(u: number)
		return math.clamp((u - 0.55) / 0.6, 0, 1)
	end
end

-- 3 Drop: a beam of light drops on the spot, you land in it, a shockwave of blocks jumps up across the floor, dust
Spawn[3] = function(fx: Fx)
	local gold, white = rgb(255, 225, 120), rgb(255, 255, 240)
	local beam = block(fx, Vector3.new(30, 3, 3), white, nil, 0.3)
	beam.Shape = Enum.PartType.Cylinder
	local core = block(fx, Vector3.new(30, 1.2, 1.2), white, nil, 0)
	core.Shape = Enum.PartType.Cylinder
	local tiles: { any } = {}
	for ringN = 1, 3 do
		local n = 8 + ringN * 6
		for i = 1, n do
			table.insert(tiles, { block(fx, Vector3.new(0.9, 0.5, 0.9), gold), ringN, (i - 1) / n * TAU } :: { any })
		end
	end
	local dust = emit(area(fx, Vector3.new(4, 0.2, 4), CFrame.new(0, 0.2, 0)), {
		Texture = TEX.Smoke,
		Color = cseq(white, gold),
		Rate = 0,
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(80, 5),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 4,
		Size = seq({ { 0, 1 }, { 1, 2.4 } }),
		Transparency = seq({ { 0, 0.3 }, { 1, 1 } }),
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	burstAt(fx, "dust", 0.45, dust, 30)
	local flash = light(fx, gold, 0, 20, 2)
	step(fx, function(t: number, base: CFrame)
		local u = t - fx.Data.Start
		-- the beam: thin, widens as it lands, then narrows away
		local k = math.clamp(u / 0.45, 0, 1)
		local out = math.clamp((u - 0.45) / 0.5, 0, 1)
		local w = (0.3 + 2.7 * k) * (1 - out)
		local up = CFrame.Angles(0, 0, math.rad(90))
		beam.Size = Vector3.new(30, math.max(w, 0.05), math.max(w, 0.05))
		core.Size = Vector3.new(30, math.max(w * 0.4, 0.05), math.max(w * 0.4, 0.05))
		local top = 15 + (1 - k) * 30
		put(fx, beam, base * CFrame.new(0, top, 0) * up)
		put(fx, core, base * CFrame.new(0, top, 0) * up)
		beam.Transparency = if w <= 0.06 then 1 else 0.35 + out * 0.65
		core.Transparency = if w <= 0.06 then 1 else out
		-- the shockwave: each ring jumps as the wave passes it
		local wave = math.max(0, u - 0.45)
		for _, tl in tiles do
			local p, rn, a = tl[1], tl[2], tl[3]
			local r = 1.2 + rn * 1.7
			local reach = wave * 14 - r
			local jump = if reach > 0 and reach < 3 then math.sin(reach / 3 * math.pi) * 1.2 else 0
			put(
				fx,
				p,
				base * CFrame.new(math.cos(a) * r, 0.1 + jump, math.sin(a) * r) * CFrame.Angles(0, -a, jump * 0.5)
			)
			p.Transparency = if u < 0.45 then 1 else 0.1 + math.clamp((u - 0.8) / 0.7, 0, 1) * 0.9
			p.Color = gold:Lerp(white, jump / 1.2)
		end
		flash.Brightness = if u >= 0.45 then math.max(0, 8 * (1 - (u - 0.45) / 0.35)) else 0
	end)
	return function(u: number)
		return if u < 0.42 then 0 else math.clamp((u - 0.42) / 0.1, 0, 1)
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Who wears what
---------------------------------------------------------------------------------------------------------------------

type Live = {
	Model: Model,
	Tier: number,
	Fx: Fx,
}
type Show = {
	Model: Model,
	Fx: Fx,
	Style: number,
	Start: number,
	Seen: (number) -> number,
}

local live: { [Model]: Live } = {}
local shows: { [Model]: Show } = {}
local rigSpawnSeen: { [Model]: number } = {}

local function rootOf(model: Model): BasePart?
	local r = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	return if r and r:IsA("BasePart") then r else nil
end

-- The feet, turned to the character's heading only
local function baseOf(model: Model): CFrame?
	local r = rootOf(model)
	if not r then
		return nil
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local down = r.Size.Y / 2 + 2
	if hum and hum.RigType == Enum.HumanoidRigType.R15 then
		down = r.Size.Y / 2 + hum.HipHeight
	end
	local look = r.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	local p = r.Position - Vector3.new(0, down, 0)
	return CFrame.lookAt(p, p + flat.Unit)
end

-- What each model should wear now
local function wanted(): { [Model]: number }
	local out = {}
	for _, player in Players:GetPlayers() do
		local c = player.Character
		local tier = player:GetAttribute("Aura")
		if STUDIO and player == Players.LocalPlayer and Auras.Test > 0 then
			tier = Auras.Test
		end
		if c and type(tier) == "number" and Build[tier] then
			out[c] = tier
		end
	end
	if STUDIO then
		for _, m in CollectionService:GetTagged("AuraRig") do
			local tier = m:GetAttribute("Aura")
			if m:IsA("Model") and type(tier) == "number" and Build[tier] then
				out[m] = tier
			end
		end
	end
	return out
end

local function drop(model: Model)
	local l = live[model]
	if l then
		l.Fx.Folder:Destroy()
		live[model] = nil
	end
end

local function wear(model: Model, tier: number)
	drop(model)
	local fx = newFx(model.Name .. "_Aura" .. tier)
	Build[tier](fx)
	fx.Folder.Parent = root
	live[model] = { Model = model, Tier = tier, Fx = fx }
end

local function reconcile()
	local want = wanted()
	for model, l in live do
		if want[model] ~= l.Tier or not model.Parent then
			drop(model)
		end
	end
	for model, tier in want do
		if not live[model] then
			wear(model, tier)
		end
	end
	if STUDIO then
		for _, m in CollectionService:GetTagged("AuraRig") do
			local at = m:GetAttribute("SpawnAt")
			if m:IsA("Model") and type(at) == "number" and rigSpawnSeen[m] ~= at then
				rigSpawnSeen[m] = at
				local style = m:GetAttribute("SpawnStyle")
				AuraController.spawnIn(m, if type(style) == "number" then style else Auras.SpawnStyle, at)
			end
		end
	end
end

local function fade(model: Model, seen: number)
	local hidden = 1 - seen
	for _, d in model:GetDescendants() do
		if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = hidden
		end
	end
end

-- Play spawn-in `style` round a model, from clock time `start` (now by default)
function AuraController.spawnIn(model: Model, style: number?, start: number?)
	local s = style or Auras.SpawnStyle
	if not Spawn[s] then
		return
	end
	local old = shows[model]
	if old then
		old.Fx.Folder:Destroy()
	end
	local fx = newFx(model.Name .. "_Spawn" .. s)
	fx.Data.Start = start or now()
	local seen = Spawn[s](fx)
	fx.Folder.Parent = root
	shows[model] = { Model = model, Fx = fx, Style = s, Start = fx.Data.Start, Seen = seen }
	fade(model, seen(0))
end

local function run(fx: Fx, t: number, base: CFrame)
	for _, s in fx.Steps do
		s(t, base, fx)
	end
end

local function frame()
	local t = now()
	local cam = workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else Vector3.zero
	local moves: { BasePart } = {}
	local to: { CFrame } = {}
	local function collect(fx: Fx)
		for i, p in fx.Moves do
			table.insert(moves, p)
			table.insert(to, fx.To[i])
		end
		table.clear(fx.Moves)
		table.clear(fx.To)
	end
	for model, l in live do
		local base = baseOf(model)
		if not base then
			continue
		end
		local near = (base.Position - eye).Magnitude < Auras.DrawRange
		l.Fx.Folder.Parent = if near then root else nil
		if near then
			run(l.Fx, t, base)
			collect(l.Fx)
		end
	end
	for model, s in shows do
		local base = baseOf(model)
		local u = t - s.Start
		if not base or not model.Parent or u > SPAWN_TIME[s.Style] + 0.6 or u < -5 then
			s.Fx.Folder:Destroy()
			shows[model] = nil
			if model.Parent then
				fade(model, 1)
			end
			continue
		end
		run(s.Fx, t, base)
		collect(s.Fx)
		fade(model, s.Seen(u))
	end
	if #moves > 0 then
		workspace:BulkMoveTo(moves, to, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function arrived(c: Model)
	if Auras.SpawnStyle > 0 then
		task.spawn(function()
			c:WaitForChild("HumanoidRootPart", 5)
			if c.Parent then
				AuraController.spawnIn(c)
			end
		end)
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(arrived)
	-- our own first character is often there before Start
	if player == Players.LocalPlayer and player.Character then
		arrived(player.Character)
	end
end

function AuraController.Init()
	root = Instance.new("Folder")
	root.Name = "AuraFx"
	root.Parent = workspace
end

function AuraController.Start()
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	local lastCheck = 0
	RunService.RenderStepped:Connect(function()
		local c = os.clock()
		if c - lastCheck > 0.2 then
			lastCheck = c
			reconcile()
		end
		frame()
	end)
end

return AuraController
