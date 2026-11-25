--!strict
-- The twelve auras and the spawn-in (Shared/Auras; Hugo, 2026-11-19, and 2026-11-24: "make sure that we implement
-- auras"). Every machine draws every player's aura round their character from the player's "Aura" attribute (a tier, 1
-- to 12; AuraService), and plays the spawn-in (Auras.SpawnStyle) when any character appears. Nothing here replicates or
-- touches the character's own parts (the spawn-in's fade uses LocalTransparencyModifier, this machine's own, and puts it
-- back).
--
-- Three looks, Config.Aura.Look (read live):
-- 2, round the body in 3D (Hugo, 2026-11-25; docs/design/auras.md; its numbers Shared/AuraVolume, its drawing
--   Lib/AuraAround): it stands in the world round the wearer, on the ground and up round them. On foot it is seen standing
--   still and fades out on the move (swimming is moving), each wearer by their own movement as this machine sees it; riding,
--   it is always seen and goes round the rider and the fish as one. Riding is State "Riding" or "Failing", the hop between
--   fish (Aura.Hop), a land fish, a tank fish and the trainer's seahorse (the weld the rider hangs from: mountOf), and the
--   sub once it has scooped them up (State "Carried"; its model is each machine's own, under the camera).
--   Everyone else's is drawn in less detail further off, past the nearest few, and on a phone (AuraVolume.detail).
--   A sheet that is not uploaded yet (Auras.Sheets) has an engine picture in its place, or its layer is left out.
-- 1, the flame (draft 4; Shared/AuraFlame, Lib/AuraBeams): a flat flame turned to the camera. Without its pictures
--   (Auras.Pictures, or the local copy) it is the old look.
-- 0, the old look (draft 2): each is one wrapping source (a shell round the body that the particles rise from) plus, from
--   tier 3 up, emitters carried round the body on a path.
-- Both flames flare on a landing (tier 7: Net.Fx "Land"), a hop (8: the player's State turns "Jumping") and a speed boost
--   (9: Fx "Eat", "Smash"), run faster while riding (9), and are put on with a burst (10; below it rises): only when the
--   Aura attribute changes on a character already seen, so never on a respawn nor for players here before we joined.
-- The carriers and the emitters' areas are unseen anchored parts in a Folder under workspace "AuraFx", placed every
-- frame round the feet (turned with the character's heading only), in one workspace:BulkMoveTo. An aura far from the
-- camera (Auras.DrawRange) is taken out of the world until it comes back.
--
-- Captures (Studio only): workspace "AuraClock" as a number holds the carriers' clock; with "AuraSlow" too, the clock
-- runs from there at that fraction of real time and every emitter's TimeScale is set to it, so a GIF can be shot at a
-- second a frame. A Model tagged "AuraRig" shows its own "Aura" attribute (sat if its "State" is "Riding"; its "FlareAt", a
-- clock time, flares it then), and its "SpawnAt" (a clock time) plays its
-- "SpawnStyle" from then. tools/studio/aura_capture.py drives it.
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Auras = require(ReplicatedStorage.Shared.Auras)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local AuraVolume = require(ReplicatedStorage.Shared.AuraVolume)
local AuraAround = require(script.Parent.Parent.Lib.AuraAround)
local AuraBeams = require(script.Parent.Parent.Lib.AuraBeams)
local Shop = require(script.Parent.Parent.UI.Shop)
-- (the shop's two pages: each names itself to UI.Shop as it is required)
local AuraShop = require(script.Parent.Parent.UI.AuraShop)
local SellFish = require(script.Parent.Parent.UI.SellFish)

local AuraController = {}

local STUDIO = RunService:IsStudio()
local TEX = {
	-- (forcefield_glow_main is nearly black: the implosion picture is the soft round glow)
	Glow = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	Bubble = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Embers = "rbxasset://textures/particles/explosion01_implosion_main.dds", -- (fire_sparks_main is too faint)
	Square = "rbxasset://textures/particles/SquareParticle.png",
}
local TAU = math.pi * 2
-- the body, feet at y = 0: the shell the particles wrap from
local BODY_Y = 2.9
local BODY = Vector3.new(2.6, 4.4, 2.6)

local slowFrom, slowReal, slowScale = 0, 0, 1
local function slowNow(): number
	if STUDIO then
		local s = workspace:GetAttribute("AuraSlow")
		if type(s) == "number" and type(workspace:GetAttribute("AuraClock")) == "number" then
			return s
		end
	end
	return 1
end

local function now(): number
	if STUDIO then
		local c = workspace:GetAttribute("AuraClock")
		if type(c) == "number" then
			local s = workspace:GetAttribute("AuraSlow")
			if type(s) == "number" then
				if slowFrom ~= c or slowScale ~= s then
					slowFrom, slowReal, slowScale = c, os.clock(), s
				end
				return c + (os.clock() - slowReal) * s
			end
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

local function cseq(...: Color3): ColorSequence
	local c = { ... }
	if #c == 1 then
		return ColorSequence.new(c[1])
	end
	local keys = {}
	for i, col in c do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#c - 1), col))
	end
	return ColorSequence.new(keys)
end

local function hue(h: number, s: number?): Color3
	return Color3.fromHSV(h % 1, s or 0.6, 1)
end

local function flicker(t: number, i: number): number
	return 0.5 + 0.5 * math.sin(t * 13.1 + i * 2.3) * math.sin(t * 7.7 + i)
end

---------------------------------------------------------------------------------------------------------------------
-- The kit: an Fx is one aura or one spawn-in, its unseen carriers, its emitters and its per-frame steps
---------------------------------------------------------------------------------------------------------------------

type Step = (t: number, base: CFrame, fx: Fx) -> ()
export type Fx = {
	Folder: Folder,
	Steps: { Step },
	Moves: { BasePart },
	To: { CFrame },
	Emitters: { ParticleEmitter },
	Data: { [string]: any },
}

local root: Folder

local function newFx(name: string): Fx
	local f = Instance.new("Folder")
	f.Name = name
	return { Folder = f, Steps = {}, Moves = {}, To = {}, Emitters = {}, Data = {} }
end

local function step(fx: Fx, s: Step)
	table.insert(fx.Steps, s)
end

-- Queue a part's place for this frame's BulkMoveTo
local function put(fx: Fx, p: BasePart, cf: CFrame)
	table.insert(fx.Moves, p)
	table.insert(fx.To, cf)
end

local function block(fx: Fx, size: Vector3, color: Color3, alpha: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = alpha or 0
	p.Parent = fx.Folder
	return p
end

-- An unseen part at `offset` from the feet: an emitter's area (its size), or a light's place
local function area(fx: Fx, size: Vector3, offset: CFrame): Part
	local p = block(fx, size, Color3.new(), 1)
	step(fx, function(_t, base)
		put(fx, p, base * offset)
	end)
	return p
end

-- An unseen part carried along path(t) (feet space): its emitters draw a ribbon behind it
local function carrier(fx: Fx, path: (number) -> Vector3): Part
	local p = block(fx, Vector3.new(0.4, 0.4, 0.4), Color3.new(), 1)
	step(fx, function(t, base)
		put(fx, p, base * CFrame.new(path(t)))
	end)
	return p
end

local function emit(fx: Fx, parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	e.LightEmission = 1
	e.Brightness = 2.5
	e.Texture = TEX.Glow
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	table.insert(fx.Emitters, e)
	return e
end

-- The body's shell
local function shell(fx: Fx, scale: number?, y: number?): Part
	return area(fx, BODY * (scale or 1), CFrame.new(0, y or BODY_Y, 0))
end

-- Particles that rise off the body's shell: the one continuous source every tier has
local function wrap(fx: Fx, parent: Instance, props: { [string]: any }): ParticleEmitter
	local base = {
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.4, 1),
		Acceleration = Vector3.new(0, 2.5, 0),
		Lifetime = NumberRange.new(0.9, 1.5),
		SpreadAngle = Vector2.new(10, 10),
	}
	for k, v in props do
		base[k] = v
	end
	return emit(fx, parent, base)
end

-- A ribbon: particles left where the carrier passes, fading as they shrink
local function ribbon(
	fx: Fx,
	parent: Instance,
	color: ColorSequence,
	rate: number,
	size: number,
	life: number,
	props: { [string]: any }?
): ParticleEmitter
	local p = {
		Color = color,
		Rate = rate,
		Lifetime = NumberRange.new(life * 0.8, life),
		Speed = NumberRange.new(0, 0.2),
		Size = seq({ { 0, size * 1.6 }, { 0.5, size * 1.3 }, { 1, 0 } }),
		Transparency = seq({ { 0, 0 }, { 1, 0.85 } }),
		LockedToPart = false,
	}
	for k, v in (props or {}) :: { [string]: any } do
		p[k] = v
	end
	return emit(fx, parent, p)
end

-- (Hugo: no glow on the floor, so nothing here carries a light: a PointLight lights the ground round the player)

-- Round, small glows rising off the body
local function bubbles(fx: Fx, parent: Instance, color: Color3, rate: number, size: number?)
	return wrap(fx, parent, {
		Texture = TEX.Bubble,
		Brightness = 3.5,
		Color = cseq(color),
		Rate = rate,
		Speed = NumberRange.new(0.3, 0.8),
		Acceleration = Vector3.new(0, 3, 0),
		Lifetime = NumberRange.new(1.2, 1.8),
		Size = seq({ { 0, 0 }, { 0.15, size or 0.8 }, { 0.85, (size or 0.8) * 0.9 }, { 1, 0 } }),
		Transparency = seq({ { 0, 0.2 }, { 0.8, 0.4 }, { 1, 1 } }),
	})
end

---------------------------------------------------------------------------------------------------------------------
-- The old look (draft 2, Config.Aura.Look 0): the twelve tiers. Feet at y = 0, a character about 5 studs tall, "forward" -Z. Nothing below the knees but what
-- rises off the legs.
---------------------------------------------------------------------------------------------------------------------

local Build: { (Fx) -> () } = {}

-- 1 Bubble: a few soft bubbles rise off you
Build[1] = function(fx)
	local s = shell(fx)
	bubbles(fx, s, rgb(190, 235, 255), 14)
	wrap(fx, s, {
		Texture = TEX.Spark,
		Color = cseq(rgb(235, 250, 255)),
		Rate = 3,
		Lifetime = NumberRange.new(0.5, 0.8),
		Size = seq({ { 0, 0 }, { 0.5, 0.3 }, { 1, 0 } }),
	})
end

-- 2 Foam: more bubbles, and a white foam haze hugging you
Build[2] = function(fx)
	local s = shell(fx)
	bubbles(fx, s, rgb(225, 248, 255), 18, 0.85)
	wrap(fx, s, {
		Texture = TEX.Smoke,
		Color = cseq(rgb(255, 255, 255), rgb(170, 225, 255)),
		Rate = 14,
		LightEmission = 0.5,
		Speed = NumberRange.new(0.2, 0.5),
		Acceleration = Vector3.new(0, 1.2, 0),
		Lifetime = NumberRange.new(1.2, 1.8),
		Size = seq({ { 0, 0.7 }, { 1, 1.6 } }),
		Transparency = seq({ { 0, 0.45 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-30, 30),
	})
end

-- 3 Tide: a wave of teal light runs round you, rising and falling, cresting white
Build[3] = function(fx)
	local teal, white = rgb(40, 210, 200), rgb(220, 255, 250)
	local s = shell(fx)
	for k = 0, 1 do
		local c = carrier(fx, function(t)
			local a = t * 2.4 + k * math.pi
			return Vector3.new(math.cos(a) * 1.8, BODY_Y + math.sin(a * 2 + t) * 1.6, math.sin(a) * 1.8)
		end)
		ribbon(fx, c, cseq(white, teal, teal), 90, 0.55, 1.1)
	end
	bubbles(fx, s, rgb(170, 255, 240), 8)
end

-- 4 Current: three streaks spiral up round you, and fast lines shoot up your body
Build[4] = function(fx)
	local blue, pale = rgb(40, 170, 255), rgb(190, 245, 255)
	local s = shell(fx)
	for k = 0, 2 do
		local c = carrier(fx, function(t)
			local u = (t / 1.2 + k / 3) % 1
			local a = u * TAU * 1.5 + k * TAU / 3
			local r = 2 - u * 0.5
			return Vector3.new(math.cos(a) * r, 0.6 + u * 5.6, math.sin(a) * r)
		end)
		ribbon(fx, c, cseq(pale, blue), 100, 0.45, 0.6)
	end
	wrap(fx, s, {
		Texture = TEX.Square,
		Color = cseq(pale, blue),
		Rate = 22,
		Speed = NumberRange.new(5, 8),
		Acceleration = Vector3.zero,
		Lifetime = NumberRange.new(0.25, 0.4),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = seq({ { 0, 0.12 }, { 1, 0.06 } }),
		Squash = seq(-2.5),
		Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
	})
end

-- 5 Reef: coral-coloured sparkles twinkle all over you, soft coral glows rise
Build[5] = function(fx)
	local s = shell(fx, 1.1)
	for _, col in { rgb(255, 110, 150), rgb(255, 170, 70), rgb(255, 225, 90), rgb(190, 110, 255) } do
		wrap(fx, s, {
			Texture = TEX.Spark,
			Color = cseq(col),
			Rate = 12,
			Brightness = 3.5,
			Speed = NumberRange.new(0.1, 0.4),
			Acceleration = Vector3.new(0, 0.6, 0),
			Lifetime = NumberRange.new(0.6, 1),
			Size = seq({ { 0, 0 }, { 0.4, 0.85 }, { 1, 0 } }),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-120, 120),
		})
	end
	bubbles(fx, s, rgb(255, 150, 180), 8, 0.45)
	local c = carrier(fx, function(t)
		local a = t * 1.6
		return Vector3.new(math.cos(a) * 1.9, BODY_Y + math.sin(t * 2.2) * 0.8, math.sin(a) * 1.9)
	end)
	ribbon(fx, c, cseq(rgb(255, 120, 170), rgb(255, 210, 90)), 50, 0.4, 0.6)
end

-- 6 Storm: a dark cloud round your head and shoulders, bright crackles all over you, sparks flying
Build[6] = function(fx)
	local yellow = rgb(255, 240, 110)
	local s = shell(fx)
	-- two bolts: carriers that jump from point to point over the body every 0.07 s, drawing jagged bright arcs
	for k = 1, 2 do
		local function point(n: number): Vector3
			local r = Random.new(n * 13 + k * 101)
			local ang = r:NextNumber() * TAU
			local rad = r:NextNumber(1.1, 1.9)
			return Vector3.new(math.cos(ang) * rad, r:NextNumber(1, 6), math.sin(ang) * rad)
		end
		local c = carrier(fx, function(t)
			local n = t / 0.07
			local i = math.floor(n)
			return point(i):Lerp(point(i + 1), n - i)
		end)
		ribbon(fx, c, cseq(rgb(255, 255, 230), yellow), 400, 0.3, 0.2, { Brightness = 5 })
	end
	emit(fx, area(fx, Vector3.new(2.8, 1.2, 2.8), CFrame.new(0, 5.4, 0)), {
		Texture = TEX.Smoke,
		Color = cseq(rgb(120, 130, 185), rgb(70, 78, 120)),
		Rate = 30,
		LightEmission = 0.3,
		Brightness = 1,
		Lifetime = NumberRange.new(1, 1.5),
		Speed = NumberRange.new(0.2, 0.6),
		Size = seq({ { 0, 1.2 }, { 1, 2.2 } }),
		Transparency = seq({ { 0, 0.35 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		Shape = Enum.ParticleEmitterShape.Box,
	})
	wrap(fx, s, {
		Texture = TEX.Spark,
		Color = cseq(rgb(255, 255, 220), yellow),
		Rate = 45,
		Brightness = 5,
		Speed = NumberRange.new(0, 0.2),
		Acceleration = Vector3.zero,
		Lifetime = NumberRange.new(0.08, 0.16),
		Size = seq({ { 0, 2 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
	})
	wrap(fx, s, {
		Texture = TEX.Embers,
		Color = cseq(yellow),
		Rate = 20,
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(70, 70),
		Drag = 4,
		Acceleration = Vector3.new(0, -6, 0),
		Lifetime = NumberRange.new(0.25, 0.45),
		Size = seq({ { 0, 0.4 }, { 1, 0 } }),
	})
end

-- 7 Moon: two silver rings of light turn round you on crossing tilts, a small moon circles your head, starlight
Build[7] = function(fx)
	local silver, lilac = rgb(230, 235, 255), rgb(170, 140, 255)
	local s = shell(fx)
	for k, tilt in { CFrame.Angles(math.rad(35), 0, math.rad(12)), CFrame.Angles(math.rad(-35), 0, math.rad(-12)) } do
		local c = carrier(fx, function(t)
			local a = t * 2.2 * (if k == 1 then 1 else -1)
			return Vector3.new(0, BODY_Y, 0) + tilt * Vector3.new(math.cos(a) * 2.3, 0, math.sin(a) * 2.3)
		end)
		ribbon(fx, c, cseq(silver, lilac), 120, 0.4, 1.3)
	end
	local moon = carrier(fx, function(t)
		local a = t * 0.9
		return Vector3.new(math.cos(a) * 1.2, 6.4 + math.sin(t * 1.3) * 0.15, math.sin(a) * 1.2)
	end)
	ribbon(fx, moon, cseq(rgb(255, 255, 255)), 40, 1.1, 0.2, { Brightness = 3 })
	wrap(fx, s, {
		Texture = TEX.Spark,
		Color = cseq(silver, lilac),
		Rate = 12,
		Speed = NumberRange.new(0, 0.2),
		Acceleration = Vector3.zero,
		Lifetime = NumberRange.new(0.5, 0.9),
		Size = seq({ { 0, 0 }, { 0.5, 0.45 }, { 1, 0 } }),
	})
end

-- 8 Lantern: four warm lanterns of light circle you at different heights, warm motes rise off you
Build[8] = function(fx)
	local gold, orange = rgb(255, 205, 80), rgb(255, 125, 40)
	local s = shell(fx)
	local lamps = {}
	for i = 1, 4 do
		local c = carrier(fx, function(t)
			local a = t * 0.5 + i * TAU / 4
			return Vector3.new(math.cos(a) * 2.3, 1.6 + (i % 2) * 2.6 + math.sin(t * 1.4 + i) * 0.3, math.sin(a) * 2.3)
		end)
		table.insert(lamps, ribbon(fx, c, cseq(rgb(255, 245, 190), gold, orange), 30, 0.95, 0.35, { Brightness = 3 }))
	end
	wrap(fx, s, {
		Color = cseq(gold, orange),
		Rate = 14,
		Lifetime = NumberRange.new(1.4, 2),
		Size = seq({ { 0, 0 }, { 0.2, 0.3 }, { 1, 0 } }),
		Transparency = seq({ { 0, 0.2 }, { 1, 1 } }),
	})
	step(fx, function(t)
		for i, e in lamps do
			e.Brightness = 2.2 + 1.4 * flicker(t, i)
		end
	end)
end

-- 9 Ember: a flame wraps you and rises past your head, embers fly up
Build[9] = function(fx)
	local hot, deep, yellow = rgb(255, 120, 30), rgb(220, 40, 20), rgb(255, 235, 130)
	local s = shell(fx, 0.9, 2.4)
	wrap(fx, s, {
		Color = cseq(yellow, hot, deep),
		Rate = 60,
		Brightness = 3,
		Speed = NumberRange.new(1, 2),
		Acceleration = Vector3.new(0, 7, 0),
		Lifetime = NumberRange.new(0.5, 0.8),
		Size = seq({ { 0, 1.6 }, { 0.6, 1.1 }, { 1, 0.2 } }),
		Transparency = seq({ { 0, 0.2 }, { 0.7, 0.5 }, { 1, 1 } }),
	})
	wrap(fx, s, {
		Texture = TEX.Fire,
		Color = cseq(yellow, hot, deep),
		Rate = 80,
		Brightness = 4,
		Speed = NumberRange.new(1, 2),
		Acceleration = Vector3.new(0, 7, 0),
		Lifetime = NumberRange.new(0.5, 0.8),
		Size = seq({ { 0, 1.1 }, { 0.6, 0.8 }, { 1, 0.2 } }),
		Transparency = seq({ { 0, 0.15 }, { 0.7, 0.4 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
	})
	wrap(fx, s, {
		Texture = TEX.Embers,
		Color = cseq(yellow, hot),
		Rate = 26,
		Speed = NumberRange.new(4, 7),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.zero,
		Lifetime = NumberRange.new(0.8, 1.3),
		Size = seq({ { 0, 0.4 }, { 1, 0 } }),
	})
end

-- 10 Phantom: a ghostly mist rises off you, four wisps swirl round you
Build[10] = function(fx)
	local mint, violet = rgb(110, 255, 190), rgb(175, 110, 255)
	local s = shell(fx)
	wrap(fx, s, {
		Texture = TEX.Smoke,
		Color = cseq(mint, violet),
		Rate = 18,
		LightEmission = 0.7,
		Speed = NumberRange.new(0.3, 0.7),
		Acceleration = Vector3.new(0, 1.5, 0),
		Lifetime = NumberRange.new(1.4, 2),
		Size = seq({ { 0, 0.9 }, { 1, 2.2 } }),
		Transparency = seq({ { 0, 0.55 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	})
	for k = 0, 3 do
		local c = carrier(fx, function(t)
			local a = t * (1.3 + k * 0.15) + k * TAU / 4
			local r = 1.9 + math.sin(t * 1.7 + k) * 0.5
			return Vector3.new(math.cos(a) * r, BODY_Y + math.sin(t * 2.3 + k * 1.3) * 2, math.sin(a) * r)
		end)
		ribbon(fx, c, cseq(if k % 2 == 0 then mint else violet, rgb(255, 255, 255)), 60, 0.45, 0.8)
	end
end

-- 11 Abyss: a dark void smoke wraps you, light is pulled in from all round, a violet halo spins over your head
Build[11] = function(fx)
	local purple, void, bright = rgb(160, 70, 255), rgb(30, 8, 55), rgb(230, 190, 255)
	local s = shell(fx)
	wrap(fx, s, {
		Texture = TEX.Smoke,
		Color = cseq(rgb(70, 25, 120), void),
		Rate = 20,
		LightEmission = 0,
		Brightness = 1,
		Speed = NumberRange.new(0.2, 0.5),
		Acceleration = Vector3.new(0, 1, 0),
		Lifetime = NumberRange.new(1.2, 1.6),
		Size = seq({ { 0, 1 }, { 1, 2 } }),
		Transparency = seq({ { 0, 0.35 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	})
	emit(fx, area(fx, Vector3.new(9, 9, 9), CFrame.new(0, BODY_Y, 0)), {
		Color = cseq(bright, purple),
		Rate = 55,
		Lifetime = NumberRange.new(0.6, 0.75),
		Speed = NumberRange.new(6, 7),
		Size = seq({ { 0, 0.75 }, { 1, 0.1 } }),
		Transparency = seq({ { 0, 1 }, { 0.3, 0.15 }, { 1, 0 } }),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	local halo = carrier(fx, function(t)
		local a = t * 5
		return Vector3.new(math.cos(a) * 1.1, 6.3, math.sin(a) * 1.1)
	end)
	ribbon(fx, halo, cseq(bright, purple), 160, 0.4, 0.9, { Brightness = 3.5 })
	wrap(fx, s, {
		Texture = TEX.Spark,
		Color = cseq(bright, purple),
		Rate = 14,
		Brightness = 4,
		Speed = NumberRange.new(0, 0.2),
		Acceleration = Vector3.zero,
		Lifetime = NumberRange.new(0.08, 0.15),
		Size = seq({ { 0, 1 }, { 1, 0.5 } }),
		Rotation = NumberRange.new(0, 360),
	})
end

-- 12 Leviathan: a rainbow flame wraps you, two rainbow serpents of light coil round you, stars in every colour
Build[12] = function(fx)
	local s = shell(fx, 0.9, 2.4)
	wrap(fx, s, {
		Color = cseq(
			rgb(255, 120, 200),
			rgb(255, 220, 120),
			rgb(130, 255, 170),
			rgb(120, 200, 255),
			rgb(200, 140, 255)
		),
		Rate = 55,
		Brightness = 3,
		Speed = NumberRange.new(1, 2),
		Acceleration = Vector3.new(0, 7, 0),
		Lifetime = NumberRange.new(0.6, 0.9),
		Size = seq({ { 0, 1.4 }, { 0.6, 1 }, { 1, 0.2 } }),
		Transparency = seq({ { 0, 0.25 }, { 0.7, 0.5 }, { 1, 1 } }),
	})
	wrap(fx, s, {
		Texture = TEX.Fire,
		Color = cseq(
			rgb(255, 120, 200),
			rgb(255, 220, 120),
			rgb(130, 255, 170),
			rgb(120, 200, 255),
			rgb(200, 140, 255)
		),
		Rate = 70,
		Brightness = 3.5,
		Speed = NumberRange.new(1, 2),
		Acceleration = Vector3.new(0, 7, 0),
		Lifetime = NumberRange.new(0.6, 0.9),
		Size = seq({ { 0, 1 }, { 0.6, 0.75 }, { 1, 0.2 } }),
		Transparency = seq({ { 0, 0.2 }, { 0.7, 0.45 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
	})
	local snakes = {}
	for k = 0, 1 do
		local c = carrier(fx, function(t)
			local a = t * 2.6 + k * math.pi
			local y = BODY_Y + 0.4 + math.sin(t * 1.7 + k * math.pi) * 2.3
			local r = 2.1 + math.sin(t * 1.1 + k) * 0.3
			return Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		end)
		table.insert(snakes, ribbon(fx, c, cseq(rgb(255, 255, 255)), 130, 0.75, 0.75, { Brightness = 3 }))
	end
	wrap(fx, shell(fx, 1.3), {
		Texture = TEX.Spark,
		Color = cseq(
			rgb(255, 120, 200),
			rgb(255, 220, 120),
			rgb(130, 255, 170),
			rgb(120, 200, 255),
			rgb(200, 140, 255)
		),
		Rate = 24,
		Speed = NumberRange.new(0.1, 0.4),
		Acceleration = Vector3.new(0, 0.5, 0),
		Lifetime = NumberRange.new(0.7, 1.2),
		Size = seq({ { 0, 0 }, { 0.4, 0.55 }, { 1, 0 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
	})
	step(fx, function(t)
		-- each serpent's colour turns as it goes, so its body is a rainbow
		for k, e in snakes do
			e.Color = cseq(hue(t * 0.6 + k * 0.5, 0.55))
		end
	end)
end

---------------------------------------------------------------------------------------------------------------------
-- The spawn-in: three versions, each about 1.5 s, particles only (and Drop's beam of light from above). Built like an
-- aura, but with a start time; the character fades in during it (this machine only).
---------------------------------------------------------------------------------------------------------------------

local SPAWN_TIME = { 1.3, 1.7, 1.5 }

-- fire a burst of particles once, when the clock first passes `at`
local function burstAt(fx: Fx, key: string, at: number, e: ParticleEmitter, n: number)
	step(fx, function(t)
		if t - fx.Data.Start >= at and not fx.Data[key] then
			fx.Data[key] = true
			e:Emit(n)
		end
	end)
end

local Spawn: { (Fx) -> (number) -> number } = {}
-- Each returns how visible the character is at time u (seconds since the start)

-- 1 Splash: you burst out of a splash of bubbles; spray flies up and falls back round you
Spawn[1] = function(fx)
	local aqua, white = rgb(60, 220, 255), rgb(235, 252, 255)
	local body = shell(fx)
	local pop = emit(fx, body, {
		Color = cseq(white, aqua),
		Rate = 0,
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(5, 9),
		Drag = 3,
		Acceleration = Vector3.new(0, 4, 0),
		Size = seq({ { 0, 0.6 }, { 1, 0.15 } }),
		Transparency = seq({ { 0, 0 }, { 1, 1 } }),
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
	})
	local spray = emit(fx, area(fx, Vector3.new(1.6, 0.4, 1.6), CFrame.new(0, 4.5, 0)), {
		Color = cseq(white, aqua),
		Rate = 0,
		Lifetime = NumberRange.new(0.7, 1),
		Speed = NumberRange.new(9, 14),
		SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, -25, 0),
		Size = seq({ { 0, 0.45 }, { 1, 0.15 } }),
		Transparency = seq({ { 0, 0 }, { 1, 1 } }),
		Shape = Enum.ParticleEmitterShape.Disc,
	})
	local foam = emit(fx, body, {
		Texture = TEX.Smoke,
		Color = cseq(white),
		Rate = 0,
		LightEmission = 0.5,
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(1, 2),
		Size = seq({ { 0, 1 }, { 1, 2.2 } }),
		Transparency = seq({ { 0, 0.4 }, { 1, 1 } }),
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	burstAt(fx, "pop", 0.05, pop, 50)
	burstAt(fx, "foam", 0.05, foam, 18)
	burstAt(fx, "spray", 0.15, spray, 40)
	return function(u)
		return math.clamp((u - 0.1) / 0.3, 0, 1)
	end
end

-- 2 Whirlpool: three streams of light wind in round you, tightening and quickening, then burst outward in a flash
-- of sparks as you appear
Spawn[2] = function(fx)
	local teal, white, deep = rgb(40, 230, 220), rgb(240, 255, 255), rgb(30, 120, 255)
	local streams = {}
	for k = 1, 3 do
		local c = carrier(fx, function(t)
			local u = math.clamp(t - fx.Data.Start, 0, 1.15)
			local wind = u / 1.15
			local ang = (wind ^ 1.6 * 3.2 + k / 3) * TAU
			local r = 4.5 - 3.2 * wind
			return Vector3.new(math.cos(ang) * r, 0.8 + wind * 4.8, math.sin(ang) * r)
		end)
		table.insert(streams, ribbon(fx, c, cseq(white, teal, deep), 0, 0.6, 0.45))
	end
	local pop = emit(fx, shell(fx), {
		Texture = TEX.Spark,
		Color = cseq(white, teal),
		Rate = 0,
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(10, 18),
		Drag = 5,
		Size = seq({ { 0, 0.8 }, { 1, 0 } }),
		Rotation = NumberRange.new(0, 360),
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	burstAt(fx, "pop", 1.15, pop, 70)
	step(fx, function(t)
		local u = t - fx.Data.Start
		for _, e in streams do
			e.Rate = if u >= 0 and u < 1.15 then 140 else 0
		end
	end)
	return function(u)
		return math.clamp((u - 0.55) / 0.6, 0, 1)
	end
end

-- 3 Drop: a beam of light drops on the spot, you appear in it, a burst of light and sparks round you
Spawn[3] = function(fx)
	local gold, white = rgb(255, 225, 120), rgb(255, 255, 240)
	local beam = block(fx, Vector3.new(30, 3, 3), white, 0.3)
	beam.Shape = Enum.PartType.Cylinder
	local core = block(fx, Vector3.new(30, 1.2, 1.2), white, 0)
	core.Shape = Enum.PartType.Cylinder
	local body = shell(fx)
	local burst = emit(fx, body, {
		Texture = TEX.Spark,
		Color = cseq(white, gold),
		Rate = 0,
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(10, 16),
		Drag = 5,
		Size = seq({ { 0, 0.9 }, { 1, 0 } }),
		Rotation = NumberRange.new(0, 360),
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	local glow = emit(fx, body, {
		Color = cseq(white, gold),
		Rate = 0,
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(0, 5, 0),
		Size = seq({ { 0, 0.7 }, { 1, 0 } }),
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	burstAt(fx, "burst", 0.45, burst, 60)
	burstAt(fx, "glow", 0.45, glow, 40)
	step(fx, function(t, base)
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
	end)
	return function(u)
		return if u < 0.42 then 0 else math.clamp((u - 0.42) / 0.1, 0, 1)
	end
end

-- Who wears what
---------------------------------------------------------------------------------------------------------------------

type Live = {
	Model: Model,
	Tier: number,
	Fx: Fx,
	Kind: string, -- "Around" (look 2), "Flame" (look 1) or "Old" (look 0)
	Around: AuraAround.Around?,
	Flame: AuraBeams.Flame?,
	Sat: () -> boolean, -- on a fish now (the flame's)
	Who: Instance, -- what says what the wearer does: the player, or a Studio rig
	Ours: boolean,
	Mover: AuraVolume.Mover,
	Mount: Mount?, -- what they rode last frame
	Far: number, -- from the camera, this frame
	Place: number, -- among the others, the nearest first
}
-- What a wearer rides: the part they hang from, and the box of it in that part's space
type Mount = { Part: BasePart, Body: Vector3, Mid: Vector3 }
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
local rigFlareSeen: { [Model]: number } = {}
-- what each character was last seen wearing (0: nothing): a change on one already here is it being put on
local seenWearing: { [Model]: number } = {}
local noPictures = false -- the flame's pictures are not on this machine: the old look

-- Which look is drawn now
local function kindNow(): string
	local look = Config.Aura.Look
	if look >= 2 then
		return "Around"
	elseif look == 1 and not noPictures and (STUDIO or AuraBeams.uploaded()) then
		return "Flame"
	end
	return "Old"
end

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

---- what they ride (look 2)
local WELDS = { RideWeld = true, LandWeld = true, TankRideWeld = true, TrainerWeld = true }

-- The box round a model's parts, in one part's space (what is see-through is not its body: a hit box, a water volume)
local function boxOf(model: Instance, part: BasePart): (Vector3, Vector3)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 then
			local cf = part.CFrame:ToObjectSpace(d.CFrame)
			local h = d.Size / 2
			local half = Vector3.new(
				math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z,
				math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z,
				math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z
			)
			low = low:Min(cf.Position - half)
			high = high:Max(cf.Position + half)
		end
	end
	if low.X > high.X then
		return part.Size, Vector3.zero
	end
	return high - low, (low + high) / 2
end

-- The sub carrying a player, as this machine draws it
local function subOf(userId: number): Model?
	local cam = workspace.CurrentCamera
	if cam then
		for _, m in cam:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("For") == userId then
				return m
			end
		end
	end
	return nil
end

-- What a wearer hangs from now, nil for nothing
local function mountOf(l: Live, hrp: BasePart): Mount?
	local part: BasePart? = nil
	for _, joint in hrp:GetJoints() do
		if WELDS[joint.Name] and joint:IsA("Weld") then
			local other = if joint.Part1 == hrp then joint.Part0 else joint.Part1
			part = if other and other:IsA("BasePart") then other else nil
			break
		end
	end
	local who = l.Who
	if not part and who:IsA("Player") and who:GetAttribute("State") == "Carried" then
		local sub = subOf(who.UserId)
		part = if sub then sub.PrimaryPart else nil
	end
	if not part then
		return nil
	end
	local last = l.Mount
	if last and last.Part == part then
		return last
	end
	local model = part:FindFirstAncestorOfClass("Model")
	local id = model and model:GetAttribute("FishType")
	local kind = if type(id) == "string" then Config.FishById[id] else nil
	local body, mid
	if model and kind and model:GetAttribute("Size") ~= nil then
		body, mid = Config.bodyOf(model, kind), Vector3.zero
	elseif model then
		-- (a tank's or a land fish has no Size attribute, the seahorse and the sub no kind: as they are built)
		body, mid = boxOf(model, part)
	else
		body, mid = part.Size, Vector3.zero
	end
	return { Part = part, Body = body, Mid = mid }
end

-- Where the aura stands on a mount: its middle, its heading, some of its pitch and none of its roll
local function rideOf(l: Live, a: AuraAround.Around, m: Mount, hrp: BasePart): AuraAround.Ride
	local cf = m.Part.CFrame
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local pitch = math.asin(math.clamp(look.Y, -1, 1)) * Config.Aura.RideLean
	local mid = cf:PointToWorldSpace(m.Mid)
	local at = CFrame.lookAt(mid, mid + flat) * CFrame.Angles(pitch, 0, 0)
	local cam = workspace.CurrentCamera
	local eye = if l.Ours and cam then (cam.CFrame.Position - hrp.Position).Magnitude else nil
	-- (the camera moves in and out: a step of it is not a step of the aura)
	local shape = AuraVolume.ride(
		a.Spec,
		m.Body,
		at:PointToObjectSpace(hrp.Position),
		if eye then math.clamp(eye, 10, 40) else nil,
		Config.Aura
	)
	return { At = at, Shape = shape }
end

-- What each model should wear now (0: nothing)
local function wanted(): { [Model]: number }
	local out = {}
	local function want(model: Model, tier: any)
		out[model] = if type(tier) == "number" and Auras.Tiers[tier] then tier else 0
	end
	for _, player in Players:GetPlayers() do
		local c = player.Character
		local tier = player:GetAttribute("Aura")
		if STUDIO and player == Players.LocalPlayer and Auras.Test > 0 then
			tier = Auras.Test
		end
		if c then
			want(c, tier)
		end
	end
	if STUDIO then
		for _, m in CollectionService:GetTagged("AuraRig") do
			if m:IsA("Model") then
				want(m, m:GetAttribute("Aura"))
			end
		end
	end
	return out
end

-- Flare a model's aura, if it has a flame whose tier does that
local function flare(model: Model?, kind: string)
	local l = model and live[model]
	if not l then
		return
	end
	if l.Flame and (l.Flame.Spec :: any)[kind] then
		AuraBeams.flare(l.Flame, now())
	elseif l.Around and (l.Around.Spec :: any)[kind] then
		AuraAround.flare(l.Around, now())
	end
end

local function drop(model: Model)
	local l = live[model]
	if l then
		l.Fx.Folder:Destroy()
		live[model] = nil
	end
end

local function wear(model: Model, tier: number, putOn: boolean)
	drop(model)
	local fx = newFx(model.Name .. "_Aura" .. tier)
	local player = Players:GetPlayerFromCharacter(model)
	local who: Instance = player or model
	local flame: AuraBeams.Flame? = nil
	local around: AuraAround.Around? = nil
	local kind = kindNow()
	if kind == "Around" then
		local a = AuraAround.build(fx.Folder, tier)
		for _, e in AuraAround.emitters(a) do
			table.insert(fx.Emitters, e)
		end
		if putOn then
			AuraAround.putOn(a, now())
		end
		around = a
	elseif kind == "Flame" then
		local f = AuraBeams.build(fx.Folder, tier)
		for _, e in f.Emitters do
			table.insert(fx.Emitters, e)
		end
		if putOn then
			AuraBeams.putOn(f, now())
		end
		flame = f
	else
		Build[tier](fx)
	end
	if not around then
		fx.Folder.Parent = root -- (look 2's comes in with its first frame that is seen)
	end
	live[model] = {
		Model = model,
		Tier = tier,
		Fx = fx,
		Kind = kind,
		Around = around,
		Flame = flame,
		Sat = function()
			return who:GetAttribute("State") == "Riding"
		end,
		Who = who,
		Ours = player == Players.LocalPlayer,
		Mover = AuraVolume.mover(),
		Mount = nil,
		Far = 0,
		Place = 1,
	}
end

local function reconcile()
	local want = wanted()
	local kind = kindNow()
	for model, l in live do
		if want[model] ~= l.Tier or not model.Parent or l.Kind ~= kind then
			drop(model)
		end
	end
	for model in seenWearing do
		if want[model] == nil then
			seenWearing[model] = nil
		end
	end
	for model, tier in want do
		local was = seenWearing[model]
		if tier > 0 and not live[model] then
			wear(model, tier, was ~= nil and was ~= tier)
		end
		seenWearing[model] = tier
	end
	if STUDIO then
		for _, m in CollectionService:GetTagged("AuraRig") do
			local at = m:GetAttribute("FlareAt")
			local l = live[m]
			if l and type(at) == "number" and rigFlareSeen[m] ~= at then
				rigFlareSeen[m] = at
				if l.Flame then
					l.Flame.FlareAt = nil
					AuraBeams.flare(l.Flame, at)
				elseif l.Around then
					l.Around.FlareAt = nil
					AuraAround.flare(l.Around, at)
				end
			end
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

local lastFrame: number? = nil
local order: { Live } = {}

-- How far each 3D aura is from the camera, and their places, the nearest first (ours is not counted)
local function rank(eye: Vector3)
	table.clear(order)
	for model, l in live do
		if l.Around then
			local r = rootOf(model)
			l.Far = if r then (r.Position - eye).Magnitude else math.huge
			l.Place = 0
			if not l.Ours and l.Far < Auras.DrawRange then
				table.insert(order, l)
			end
		end
	end
	table.sort(order, function(x, y)
		return x.Far < y.Far
	end)
	for i, l in order do
		l.Place = i
	end
end

-- A phone or a tablet: what the player has in hand
local function onPhone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- One frame of a 3D aura: whether it is seen, where it stands, how much of it is drawn
local function around(l: Live, a: AuraAround.Around, base: CFrame, t: number, dt: number)
	local c = Config.Aura
	local hrp = rootOf(l.Model) :: BasePart
	local who = l.Who
	local mount = mountOf(l, hrp)
	l.Mount = mount
	local hum = l.Model:FindFirstChildOfClass("Humanoid")
	local state: any = who:GetAttribute("State")
	if hum and hum.Health <= 0 then
		state = "Drowning"
	end
	-- (the weld says where and how big; the attributes say it too, should a weld not be here yet)
	local seated = state ~= "Carried"
		and state ~= "Drowning"
		and (
			mount ~= nil
			or who:GetAttribute("TankRide") ~= nil
			or who:GetAttribute("TrainerRide") ~= nil
			or who:GetAttribute("LandMounted") == true
		)
	local doing = AuraVolume.doing(state, who:GetAttribute("SubPhase"), seated, c)
	local seen = AuraVolume.fade(l.Mover, doing, hrp.Position, dt, c)
	if seen <= 0 or l.Far >= Auras.DrawRange then
		AuraAround.hide(a)
		l.Fx.Folder.Parent = nil
		return
	end
	l.Fx.Folder.Parent = root
	local detail = AuraVolume.detail(l.Far, l.Place, l.Ours, onPhone(), c)
	local ride = if mount and doing == "Ride" then rideOf(l, a, mount, hrp) else nil
	local hold = ride == nil and doing == "Ride" and state == "Jumping"
	AuraAround.step(a, t, base, ride, hold, seen, detail, l.Place <= c.Lights and detail >= 2, function(part, cf)
		put(l.Fx, part, cf)
	end)
end

local function frame()
	local t = now()
	local cam = workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else Vector3.zero
	local moves: { BasePart } = {}
	local to: { CFrame } = {}
	local scale = slowNow()
	local function collect(fx: Fx)
		for _, e in fx.Emitters do
			if e.TimeScale ~= scale then
				e.TimeScale = scale
			end
		end
		for i, p in fx.Moves do
			table.insert(moves, p)
			table.insert(to, fx.To[i])
		end
		table.clear(fx.Moves)
		table.clear(fx.To)
	end
	local dt = math.clamp(t - (lastFrame or t), 0, 0.2)
	lastFrame = t
	rank(eye)
	for model, l in live do
		local base = baseOf(model)
		if not base then
			continue
		end
		local a = l.Around
		if a then
			around(l, a, base, t, dt)
			collect(l.Fx)
			continue
		end
		local near = (base.Position - eye).Magnitude < Auras.DrawRange
		l.Fx.Folder.Parent = if near then root else nil
		if near then
			local flame = l.Flame
			if flame then
				-- the flat way to the camera: the Beams' ends lie across the view
				local away = eye - base.Position
				local flat = Vector3.new(away.X, 0, away.Z)
				if flat.Magnitude < 0.5 and cam then
					local across = cam.CFrame.RightVector
					flat = across:Cross(Vector3.yAxis)
				end
				local toCam = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
				AuraBeams.step(flame, t, base, toCam, l.Sat(), function(part, cf)
					put(l.Fx, part, cf)
				end)
			else
				run(l.Fx, t, base)
			end
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
	player:GetAttributeChangedSignal("State"):Connect(function()
		if player:GetAttribute("State") == "Jumping" then
			flare(player.Character, "FlareHop")
		end
	end)
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

-- The dock's windows for Studio's tests (tools/studio/b2_shop_check.py): open one by name ("Auras", "Sell"; nil
-- closes them), and which is up. What opens them in play is Controllers/StallController (UI review 1, 2026-11-22:
-- Sell and Auras on their stalls' rings, the Shop button its own Shop).
-- Test hook: only the Studio checks call this (tools/studio/b2_shop_check.py).
function AuraController.shop(page: string?)
	Shop.go(page)
end

-- Test hook: only the Studio check calls this (tools/studio/aura_check.py). What is drawn round a model: its tier,
-- "Around", "Flame" or "Old", its Beams and its emitters (Around: those drawn now, at its detail)
function AuraController.drawn(model: Model): (number, string, number, number)
	local l = live[model]
	if not l then
		return 0, "", 0, 0
	end
	if l.Around then
		local b, e = AuraAround.drawn(l.Around)
		return l.Tier, l.Kind, b, e
	end
	local beams = 0
	for _, d in l.Fx.Folder:GetDescendants() do
		if d:IsA("Beam") then
			beams += 1
		end
	end
	return l.Tier, l.Kind, beams, #l.Fx.Emitters
end

-- Test hook: only the Studio checks call this (tools/studio/b2_shop_check.py).
function AuraController.shopOpen(): string?
	return if AuraShop.isOpen() then "Auras" elseif SellFish.isOpen() then "Sell" else nil
end

function AuraController.Start()
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Net.Fx.OnClientEvent:Connect(function(what: any, player: any)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end
		if what == "Land" then
			flare(player.Character, "FlareLand")
		elseif what == "Eat" or what == "Smash" then
			flare(player.Character, "FlareBoost")
		end
	end)
	-- the 3D look's pictures on this PC: without them, the engine's own in their place
	if STUDIO then
		task.spawn(function()
			local address = AuraAround.picture("Wisp")
			if string.sub(address, 1, 10) ~= "rbxasset:/" then
				return
			end
			pcall(function()
				ContentProvider:PreloadAsync({ address } :: { any }, function(_id, status)
					if status == Enum.AssetFetchStatus.Failure then
						AuraAround.Local = false
					end
				end)
			end)
			if not AuraAround.Local then
				for model, l in live do
					if l.Around then
						drop(model) -- (made again, with the stand-ins)
					end
				end
				warn(
					"[AuraController] the auras' pictures are not here (tools/auras/volume_sheets.py --local): the engine's in their place"
				)
			end
		end)
	end
	-- the flame's pictures: without them, the old look
	if STUDIO and not AuraBeams.uploaded() then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(
					{ AuraBeams.picture("Flame"), AuraBeams.picture("Tip") } :: { any },
					function(_id, status)
						if status == Enum.AssetFetchStatus.Failure then
							noPictures = true
						end
					end
				)
			end)
			if noPictures then
				warn(
					"[AuraController] the flame's pictures are not here (tools/auras/flame_pics.py): the old aura look"
				)
			end
		end)
	end
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
