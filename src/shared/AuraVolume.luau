--!strict
-- The 3D auras' numbers (look 2; Hugo, 2026-11-25: "Make auras surround the player, not be a constant silhouette
-- following the players camera view ... Make auras cooler and bigger through progression, should start off less
-- noticeable"; docs/design/auras.md). What a tier is made of, how big it stands round a body or a fish, when it shows,
-- and what each detail level draws, as plain sums: nothing here makes an Instance, so tools/auras/volume_test.luau
-- checks it offline and tools/auras/volume_shots.py draws it. Client Lib/AuraAround builds it, AuraController decides
-- who wears it and where. Studs and seconds; on foot the feet are at 0.
--
-- It is a volume in the world, never a card turned to the camera: every layer has its place round the body (a band on
-- the ground, the column of air inside it, its wall, its top), so some of it is in front of the wearer, some behind,
-- and the engine's own depth hides what the body is in front of (no ZOffset, nothing pushed back).
-- One family, cumulative: every tier keeps what the tiers under it have, bigger, and adds one thing (From).
local Auras = require(script.Parent.Auras)

local AuraVolume = {}

export type Keys = { { number } } -- { time 0 to 1, value }

-- One ParticleEmitter (one draw call)
export type Layer = {
	Name: string,
	Picture: string, -- a sheet of art/ui/aura_volume (Auras.Sheets)
	-- where it is let out, and so which way:
	--   "Band"  a flat band on the ground round the feet, upward     (Disc, Volume, ShapePartial)
	--   "Flat"  a point on the ground, lying flat                    (an Attachment, VelocityPerpendicular)
	--   "Air"   anywhere in the column round the body                (Cylinder, Volume)
	--   "Wall"  the column's side, outward                           (Cylinder, Surface, Outward)
	--   "Foot"  the column's side at the ground only, outward        (the same, low)
	--   "Top"   a band over the head, upward                         (Disc, Volume, ShapePartial)
	Place: string,
	Wide: number, -- its place's radius, a share of the aura's,
	Band: number, -- and for a band how much of the middle is left out (0 all of it, 1 the rim only)
	Facing: string, -- "Upright" (turns about the upright only), "Flat", "Along" (its own way), "Round" (a soft round one)
	Rate: number,
	Life: { number },
	Speed: { number },
	Spread: number,
	Accel: number, -- upward
	Drag: number,
	Size: Keys,
	Jitter: number,
	Fade: Keys, -- transparency over its life
	Color: Color3, -- at its start,
	Color2: Color3, -- and at its end
	Emission: number,
	Bright: number,
	Turn: number, -- degrees a second, either way (0: it does not turn)
	AnyTurn: boolean, -- starts turned at random
	Spin: number, -- its place goes round this fast on foot, radians a second, and the particles with it
	Grid: number, -- the sheet's frames a side (1: a still)
	Mode: string, -- "OneShot" over its life, "Loop" or "Random" at Fps
	Fps: number,
	Flare: number, -- let out at once in a flare,
	Burst: number, -- in the burst when it is put on,
	Warm: number, -- and as it fades in (so the ground has its light at once)
	Keep: number, -- still drawn at this detail level and over (1: even far away; 3: near only)
	Across: boolean, -- it stands across our own view on the ride: not drawn for its own rider
}
-- One ribbon round the body: Beams end to end along a spiral (one draw call a Beam)
export type Strand = {
	Name: string,
	Beams: number,
	Turns: number, -- how far round it goes, whole turns
	From: number, -- where it starts, turns,
	Spin: number, -- and how fast it goes round, radians a second (minus: the other way)
	Low: number, -- its foot and its head, shares of the aura's height,
	High: number,
	WideLow: number, -- and its radius there, shares of the aura's
	WideHigh: number,
	Width: { number }, -- of the ribbon at its foot, middle and head
	Color: Color3,
	Head: Color3, -- at its head
	Transparency: number,
	Emission: number,
	Repeat: number, -- of the picture along one Beam
	Flow: number, -- repeats a second, foot to head
	Wave: number, -- it bobs up and down by this share of the height
	Seed: number,
	Keep: number,
}
export type Spec = {
	Tier: number,
	Radius: number, -- on foot,
	Height: number,
	Strength: number, -- 0 to 1, all of it
	Layers: { Layer },
	Strands: { Strand },
	Light: { Range: number, Bright: number, Color: Color3 }?,
	Pulse: { Every: number, Strength: number, Rise: number, Fall: number }?,
	FlareLand: boolean,
	FlareHop: boolean,
	FlareBoost: boolean,
	RideFast: number,
	Burst: boolean,
}
-- How it stands: about a frame whose middle is `At` in the mount's own space (on foot: the feet)
export type Shape = {
	X: number, -- half wide,
	Z: number, -- half long,
	Height: number,
	At: Vector3, -- the middle of its foot
	Grow: number, -- its particles are this many times as big
	Own: boolean, -- round our own ride: we look through it
}

-- The tier each thing comes in at
AuraVolume.From = {
	Wisps = 1,
	Sweeps = 2,
	Ring = 3,
	Light = 3,
	Ribbon = 4,
	Glow = 5,
	Pulse = 5,
	Flames = 6,
	Ribbon2 = 6,
	Shafts = 7,
	FlareLand = 7,
	Embers = 8,
	FlareHop = 8,
	Spray = 9,
	FlareBoost = 9,
	Arcs = 10,
	Shock = 10,
	Burst = 10,
	Pillar = 11,
	Serpents = 12,
	Crown = 12,
}

-- What each tier adds, in a few words (the note's table, the shop's line)
AuraVolume.Adds = {
	"faint wisps rise round your feet",
	"thin strokes whip out over the ground",
	"a turning ring of light on the ground",
	"a ribbon winds up round you",
	"an inner glow that breathes",
	"a ring of flames, and a second ribbon",
	"tall shafts of light; flares on a landing",
	"embers spiral up; flares on a hop",
	"spray bursts out at the foot; flares on a boost",
	"arcs crackle, shock rings; a burst when put on",
	"a towering pillar of light",
	"two great serpents and a crown of flames",
}

AuraVolume.Avatar = 2.1 -- an avatar's own half width, studs: a mount is measured against it
AuraVolume.Steps = 14 -- a fade is written in this many steps

local WHITE = Color3.new(1, 1, 1)

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- Everything one tier is made of
function AuraVolume.spec(tier: number): Spec
	local from = AuraVolume.From
	local k = (tier - 1) / 11
	local color: Color3 = Auras.Tiers[tier].Main
	local function pale(share: number): Color3
		return color:Lerp(WHITE, share)
	end
	-- `a` at the tier a thing comes in, `b` at tier 12
	local function ramp(first: number, a: number, b: number): number
		return lerp(a, b, (tier - first) / math.max(12 - first, 1))
	end
	local radius = lerp(1.9, 4.3, k)
	local height = lerp(3, 12.5, k ^ 1.1)
	-- (the faint ones are faint by their own transparency, the strong ones by number: this is the last word on both)
	local strength = lerp(0.62, 1, math.min(k * 1.5, 1))

	local layers: { Layer } = {}
	local function layer(name: string, picture: string, place: string, props: { [string]: any })
		local l = {
			Name = name,
			Picture = picture,
			Place = place,
			Wide = 1,
			Band = 0.7,
			Facing = "Upright",
			Rate = 1,
			Life = { 1, 1 },
			Speed = { 0.02, 0.02 },
			Spread = 0,
			Accel = 0,
			Drag = 0,
			Size = { { 0, 1 }, { 1, 1 } },
			Jitter = 0,
			Fade = { { 0, 0 }, { 1, 1 } },
			Color = color,
			Color2 = color,
			Emission = 0.6,
			Bright = 1,
			Turn = 0,
			AnyTurn = false,
			Spin = 0,
			Grid = 4,
			Mode = "OneShot",
			Fps = 16,
			Flare = 0,
			Burst = 0,
			Warm = 0,
			Keep = 1,
			Across = false,
		}
		for key, v in props do
			(l :: any)[key] = v
		end
		table.insert(layers, l)
	end
	local strands: { Strand } = {}
	local function strand(name: string, props: { [string]: any })
		local s = {
			Name = name,
			Beams = 2,
			Turns = 1,
			From = 0,
			Spin = 1.6,
			Low = 0.02,
			High = 0.6,
			WideLow = 1.05,
			WideHigh = 0.85,
			Width = { 0.1, 0.8, 0.15 },
			Color = color,
			Head = pale(0.5),
			Transparency = 0.3,
			Emission = 0.6,
			Repeat = 1,
			Flow = 0.9,
			Wave = 0.03,
			Seed = 1,
			Keep = 1,
		}
		for key, v in props do
			(s :: any)[key] = v
		end
		table.insert(strands, s)
	end

	---- on the ground
	if tier >= from.Glow then
		local w = radius * ramp(from.Glow, 3, 2.8)
		layer("Pool", "Glow", "Flat", {
			Facing = "Flat",
			Rate = 1.6,
			Life = { 1.8, 1.8 },
			Size = { { 0, w }, { 1, w } },
			Fade = { { 0, 1 }, { 0.5, ramp(from.Glow, 0.75, 0.84) }, { 1, 1 } },
			Grid = 1,
			Warm = 2,
			Keep = 2,
		})
	end
	if tier >= from.Ring then
		local w = radius * ramp(from.Ring, 2.5, 3)
		layer("Ring", "Ring", "Flat", {
			Facing = "Flat",
			Rate = 1.25,
			Life = { 2.4, 2.4 },
			Size = { { 0, w * 0.9 }, { 0.5, w }, { 1, w * 1.05 } },
			Fade = { { 0, 1 }, { 0.35, ramp(from.Ring, 0.5, 0.12) }, { 0.65, ramp(from.Ring, 0.5, 0.12) }, { 1, 1 } },
			Color = pale(0.25),
			Emission = 0.7,
			Turn = 0,
			AnyTurn = true,
			Mode = "Loop",
			Fps = lerp(14, 22, k),
			Warm = 2,
			Keep = 1,
		})
	end
	if tier >= from.Sweeps then
		local w = radius * ramp(from.Sweeps, 3.2, 3.4)
		layer("Sweeps", "Sweep", "Flat", {
			Facing = "Flat",
			Rate = ramp(from.Sweeps, 3.2, 3.6),
			Life = { 0.8, 1.15 },
			Size = { { 0, w * 0.75 }, { 1, w * 1.15 } },
			Jitter = 0.15,
			Fade = { { 0, 0.1 }, { 0.7, ramp(from.Sweeps, 0.2, 0.1) }, { 1, 1 } },
			Color = pale(0.4),
			Emission = 0.6,
			AnyTurn = true,
			Flare = 2,
			Burst = 4,
			Keep = 2,
		})
	end
	if tier >= from.Shock then
		local w = radius * 5
		layer("Shock", "Shock", "Flat", {
			Facing = "Flat",
			Rate = 0, -- (one with each pulse: Lib/AuraAround)
			Life = { 0.8, 0.8 },
			Size = { { 0, w }, { 1, w } },
			Fade = { { 0, 0.1 }, { 0.6, 0.3 }, { 1, 1 } },
			Color = pale(0.4),
			Emission = 0.8,
			AnyTurn = true,
			Flare = 1,
			Burst = 2,
			Keep = 2,
		})
	end
	if tier >= from.Spray then
		layer("Spray", "Jet", "Foot", {
			Wide = 0.85,
			Facing = "Along",
			Rate = ramp(from.Spray, 14, 20),
			Life = { 0.4, 0.65 },
			Speed = { 4, 7 },
			Spread = 12,
			Accel = 1.5,
			Drag = 2.5,
			Size = { { 0, 2.6 + 1.2 * k }, { 1, 3.4 + 1.8 * k } },
			Jitter = 0.2,
			Fade = { { 0, 0.15 }, { 0.6, 0.25 }, { 1, 1 } },
			Color = pale(0.6),
			Color2 = color,
			Emission = 0.6,
			Flare = 10,
			Burst = 18,
			Keep = 2,
		})
	end

	---- round the body
	layer("Wisps", "Wisp", "Band", {
		Wide = lerp(0.95, 1.15, k),
		Band = 0.55,
		Rate = lerp(7, 10, k),
		Life = { 0.9, 1.4 },
		Accel = lerp(0.6, 2.2, k),
		Size = { { 0, lerp(2, 4.6, k) }, { 1, lerp(2.5, 6, k) } },
		Jitter = 0.25,
		Fade = { { 0, 1 }, { 0.15, lerp(0.15, 0.1, k) }, { 0.7, lerp(0.3, 0.25, k) }, { 1, 1 } },
		Color = pale(0.2),
		Color2 = color,
		Emission = 0.45,
		Spin = 0.5,
		Grid = 8,
		Flare = 4,
		Burst = 8,
		Warm = 3,
	})
	if tier >= from.Glow then
		layer("Haze", "Haze", "Air", {
			Wide = 0.6,
			Facing = "Round",
			Rate = ramp(from.Glow, 3, 5),
			Life = { 1.1, 1.6 },
			Accel = 0.8,
			Size = { { 0, 2.2 + 1.6 * k }, { 1, 3.4 + 2.6 * k } },
			Fade = { { 0, 1 }, { 0.4, ramp(from.Glow, 0.9, 0.86) }, { 1, 1 } },
			Color = pale(0.2),
			Color2 = color,
			Emission = 0.8,
			Turn = 30,
			AnyTurn = true,
			Mode = "Loop",
			Fps = 12,
			Keep = 3,
			Across = true,
		})
	end
	if tier >= from.Flames then
		layer("Flames", "Flame", "Band", {
			Wide = 1.05,
			Band = 0.82,
			Rate = ramp(from.Flames, 12, 11),
			Life = { 0.6, 0.95 },
			Accel = ramp(from.Flames, 3, 6),
			Size = {
				{ 0, ramp(from.Flames, 2.6, 5) },
				{ 0.4, ramp(from.Flames, 3.2, 7) },
				{ 1, ramp(from.Flames, 3, 6.6) },
			},
			Jitter = 0.35,
			Fade = { { 0, 1 }, { 0.12, 0.05 }, { 0.75, 0.15 }, { 1, 1 } },
			Color = pale(0.12),
			Color2 = color,
			Emission = 0.4,
			Spin = 0.35,
			Grid = 8,
			Flare = 8,
			Burst = 14,
			Keep = 1,
		})
	end
	if tier >= from.Shafts then
		layer("Shafts", "Shaft", "Band", {
			Wide = 1.2,
			Band = 0.75,
			Rate = ramp(from.Shafts, 4, 7),
			Life = { 0.9, 1.4 },
			Speed = { 0.02, 0.02 },
			Accel = 6,
			Size = { { 0, height * 0.5 }, { 1, height * 0.8 } },
			Jitter = 0.15,
			Fade = { { 0, 1 }, { 0.3, ramp(from.Shafts, 0.3, 0.3) }, { 1, 1 } },
			Color = pale(0.55),
			Emission = 0.85,
			Mode = "Loop",
			Fps = 16,
			Flare = 3,
			Burst = 6,
			Keep = 2,
		})
	end
	if tier >= from.Embers then
		layer("Embers", "Mote", "Air", {
			Wide = 1.15,
			Facing = "Along",
			Rate = ramp(from.Embers, 14, 22),
			Life = { 0.8, 1.2 },
			Speed = { 1, 2.5 },
			Spread = 20,
			Accel = 7,
			Size = { { 0, 0.8 }, { 0.3, 1.5 + 0.4 * k }, { 1, 0.4 } },
			Jitter = 0.3,
			Fade = { { 0, 0.4 }, { 0.2, 0 }, { 0.7, 0.1 }, { 1, 1 } },
			Color = pale(0.85),
			Color2 = pale(0.2),
			Emission = 0.9,
			Bright = 1.7,
			Spin = 2.2,
			Mode = "Loop",
			Fps = 18,
			Flare = 10,
			Burst = 20,
			Keep = 3,
		})
	end
	if tier >= from.Arcs then
		layer("Arcs", "Arc", "Wall", {
			Wide = 0.95,
			Facing = "Round",
			Rate = ramp(from.Arcs, 9, 14),
			Life = { 0.2, 0.34 },
			Size = { { 0, 3 + 1.6 * k }, { 1, 3.6 + 2 * k } },
			Jitter = 0.4,
			Fade = { { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } },
			Color = pale(0.8),
			Emission = 0.9,
			Bright = 1.5,
			AnyTurn = true,
			Mode = "Random",
			Fps = 20,
			Flare = 3,
			Burst = 8,
			Keep = 3,
		})
	end
	if tier >= from.Pillar then
		layer("Pillar", "Shaft", "Air", {
			Wide = 0.7,
			Rate = 3.2,
			Life = { 1.2, 1.7 },
			Accel = 1,
			Size = { { 0, height * 1.35 }, { 1, height * 1.6 } },
			Jitter = 0.1,
			Fade = { { 0, 1 }, { 0.4, 0.5 }, { 1, 1 } },
			Color = pale(0.3),
			Color2 = color,
			Emission = 0.9,
			Mode = "Loop",
			Fps = 14,
			Warm = 2,
			Keep = 1,
			Across = true,
		})
	end
	if tier >= from.Crown then
		layer("Crown", "Flame", "Top", {
			Wide = 0.38,
			Band = 0.8,
			Rate = 14,
			Life = { 0.5, 0.8 },
			Accel = 4,
			Size = { { 0, 1.8 }, { 0.4, 2.6 }, { 1, 2 } },
			Jitter = 0.4,
			Fade = { { 0, 1 }, { 0.15, 0.2 }, { 0.6, 0.35 }, { 1, 1 } },
			Color = pale(0.8),
			Color2 = color,
			Emission = 0.7,
			Grid = 8,
			Burst = 8,
			Keep = 3,
		})
	end

	---- the ribbons
	if tier >= from.Ribbon then
		strand("Ribbon", {
			Color = pale(0.3),
			High = ramp(from.Ribbon, 0.75, 0.5),
			Width = { 0.05, ramp(from.Ribbon, 0.75, 1.1), 0.05 },
			Transparency = ramp(from.Ribbon, 0.35, 0.15),
			Spin = ramp(from.Ribbon, 1.5, 2.4),
		})
	end
	if tier >= from.Ribbon2 then
		strand("Ribbon2", {
			From = 0.5,
			Color = pale(0.4),
			Low = 0.12,
			High = ramp(from.Ribbon2, 0.95, 0.65),
			WideLow = 0.95,
			WideHigh = 1.05,
			Width = { 0.05, ramp(from.Ribbon2, 0.5, 0.8), 0.05 },
			Transparency = ramp(from.Ribbon2, 0.35, 0.2),
			Spin = -ramp(from.Ribbon2, 1.2, 2),
			Flow = 1.2,
			Seed = 2,
			Keep = 2,
		})
	end
	if tier >= from.Serpents then
		for i = 1, 2 do
			strand("Serpent" .. i, {
				From = i / 2 + 0.2,
				Beams = 3,
				Turns = 1.35,
				Color = color,
				Head = pale(0.9),
				Low = 0.04,
				High = 0.98,
				WideLow = 1.6,
				WideHigh = 0.8,
				Width = { 0.1, 2.1, 0.9 },
				Transparency = 0.05,
				Emission = 0.5,
				Spin = 1.9,
				Flow = 1.4,
				Wave = 0.06,
				Seed = 3 + i,
				Keep = if i == 1 then 2 else 3,
			})
		end
	end

	return {
		Tier = tier,
		Radius = radius,
		Height = height,
		Strength = strength,
		Layers = layers,
		Strands = strands,
		Light = if tier >= from.Light
			then { Range = ramp(from.Light, 8, 20), Bright = ramp(from.Light, 0.4, 1), Color = pale(0.15) }
			else nil,
		Pulse = if tier >= from.Pulse
			then { Every = ramp(from.Pulse, 1.9, 1.3), Strength = ramp(from.Pulse, 0.25, 0.5), Rise = 0.16, Fall = 0.7 }
			else nil,
		FlareLand = tier >= from.FlareLand,
		FlareHop = tier >= from.FlareHop,
		FlareBoost = tier >= from.FlareBoost,
		RideFast = if tier >= from.FlareBoost then 1.4 else 1,
		Burst = tier >= from.Burst,
	}
end

---------------------------------------------------------------------------------------------------------------------
-- What it costs
---------------------------------------------------------------------------------------------------------------------

-- The detail levels: 3 near, 2 further (or a phone), 1 far. What is kept, and the emitters' share of their rates
AuraVolume.Rates = { 0.5, 0.65, 1 }

-- Draw calls (measured 2026-11-25: one an emitter, one a Beam)
function AuraVolume.draws(spec: Spec, detail: number): number
	local n = 0
	for _, l in spec.Layers do
		n += if l.Keep <= detail then 1 else 0
	end
	for _, s in spec.Strands do
		n += if s.Keep <= detail then s.Beams else 0
	end
	return n
end

-- Particles alive at once, standing still (the shock rings: one a pulse)
function AuraVolume.alive(spec: Spec, detail: number): number
	local n = 0
	for _, l in spec.Layers do
		if l.Keep <= detail then
			local rate = l.Rate
			if l.Name == "Shock" and spec.Pulse then
				rate = 1 / spec.Pulse.Every
			end
			n += rate * AuraVolume.Rates[detail] * (l.Life[1] + l.Life[2]) / 2
		end
	end
	return n
end

-- Which detail an aura gets: how far it is from the camera, its place among the nearest (1 first), ours or not, a phone
function AuraVolume.detail(far: number, place: number, ours: boolean, phone: boolean, c: { [string]: any }): number
	if ours then
		return if phone then c.PhoneOwn else 3
	end
	local level = if far > c.FewFrom then 1 elseif far > c.WholeTo then 2 else 3
	if place > c.Full + c.Half then
		level = 1
	elseif place > c.Full then
		level = math.min(level, 2)
	end
	return if phone then math.min(level, c.PhoneMost) else level
end

-- Whether it gives light. place: 0 our own, then 1 the nearest other, and so on
function AuraVolume.lit(place: number, detail: number, c: { [string]: any }): boolean
	return place < c.Lights and detail >= 2
end

---------------------------------------------------------------------------------------------------------------------
-- When it shows
---------------------------------------------------------------------------------------------------------------------

export type Mover = { Last: Vector3?, Speed: number, Still: number, Moving: boolean, Seen: number }

function AuraVolume.mover(): Mover
	-- (not seen until its wearer has stood still: a character that has just appeared is falling)
	return { Last = nil, Speed = 0, Still = 0, Moving = true, Seen = 0 }
end

-- What the wearer does, from what the server says of them: "Ride" (always seen), "Move" (swimming, drowning: never),
-- or "Foot" (by their own movement). state: RideService's; phase: the sub's; seated: on a trainer, a tank fish or a land
-- fish
function AuraVolume.doing(state: any, phase: any, seated: boolean, c: { [string]: any }): string
	if seated or state == "Riding" or state == "Failing" then
		return "Ride"
	elseif state == "Jumping" then
		-- the hop from fish to fish is part of the ride (or it would go out and come back every other second)
		return if c.Hop ~= 0 then "Ride" else "Move"
	elseif state == "Carried" then
		-- the sub: swimming while it comes; scooped up, seated and thrown off it is the ride
		return if phase == "Approach" then "Move" else "Ride"
	elseif state == "Dock" or state == nil then
		return "Foot"
	end
	return "Move" -- "Free" (swimming), "Drowning"
end

-- One frame of a wearer's fade, 0 unseen to 1 seen. at: their root
function AuraVolume.fade(m: Mover, doing: string, at: Vector3, dt: number, c: { [string]: any }): number
	local last = m.Last
	m.Last = at
	if last and dt > 0 then
		local speed = (at - last).Magnitude / dt
		-- (smoothed over a moment: another player's place comes in steps)
		local k = 1 - math.exp(-dt / math.max(c.SpeedOver, 1e-3))
		m.Speed += (math.min(speed, 60) - m.Speed) * k
	end
	if m.Speed > c.MoveAt then
		m.Moving = true
		m.Still = 0
	elseif m.Speed < c.StillAt then
		m.Still += dt
		if m.Still >= c.StillFor then
			m.Moving = false
		end
	end
	local want = if doing == "Ride" then 1 elseif doing == "Move" or m.Moving then 0 else 1
	if want > m.Seen then
		m.Seen = math.min(1, m.Seen + dt / math.max(c.FadeIn, 1e-3))
	elseif want < m.Seen then
		m.Seen = math.max(0, m.Seen - dt / math.max(c.FadeOut, 1e-3))
	end
	return m.Seen
end

-- A fade as it is written: in few steps, eased
function AuraVolume.step(seen: number): number
	local n = AuraVolume.Steps
	return math.floor(seen * n + 0.5) / n
end

---------------------------------------------------------------------------------------------------------------------
-- How it stands
---------------------------------------------------------------------------------------------------------------------

function AuraVolume.foot(spec: Spec): Shape
	return { X = spec.Radius, Z = spec.Radius, Height = spec.Height, At = Vector3.zero, Grow = 1, Own = false }
end

-- Round a rider and what they ride as one. body: its width, height and length about its own middle; seat: where the
-- rider's root is in its space; eye: our own camera's distance when the rider is us (the camera sits a few studs behind
-- the rider whatever they ride, so our own aura never reaches back to it), nil for anyone else
function AuraVolume.ride(spec: Spec, body: Vector3, seat: Vector3, eye: number?, c: { [string]: any }): Shape
	if c.EyeCalm < 1 then
		eye = nil -- (our own is as everyone sees it)
	end
	local half = body / 2
	local more = (spec.Radius - 1.9) * 0.7
	local x = math.clamp(half.X * 0.85 + 1.1 + more, 2.4, c.RideWide)
	local z = math.clamp(half.Z * 0.82 + 1.1 + more, 2.4, c.RideLong)
	if eye then
		x = math.min(x, math.max(eye * c.EyeShare * 1.3, 2.4))
		z = math.min(z, math.max(eye * c.EyeShare, 2.4))
	end
	local deep = lerp(math.min(4, c.RideDeep), c.RideDeep, math.min((spec.Tier - 1) / 5, 1))
	local low = math.max(-half.Y, seat.Y - deep)
	-- (a body wider than the aura may be would hide its foot inside it: it stands on that one's back, round the rider)
	local inside = math.clamp((half.X * 0.85 + 1.1 - x) / (x * 0.4), 0, 1)
	low = lerp(low, math.max(low, seat.Y - 2.4), inside)
	local top = math.max(math.min(half.Y, seat.Y + c.RideDeep), seat.Y + 3)
	-- (a body longer than the aura: it is round the rider, not round the fish's middle)
	local slack = math.max(half.Z - z, 0)
	local at = Vector3.new(
		math.clamp(seat.X, -math.max(half.X - x, 0), math.max(half.X - x, 0)),
		low,
		math.clamp(seat.Z, -slack, slack)
	)
	local grow = math.clamp(((x + z) / 2 / AuraVolume.Avatar) ^ 0.7, 1, c.RideGrow)
	if eye then
		grow = math.min(grow, c.EyeGrow)
	end
	-- as tall as the two together, and over them by what the tier's own height is over an avatar
	local tall = (top - low) + math.max(spec.Height - 5.2, 0) * 0.6 * math.min(grow, 1.6)
	return { X = x, Z = z, Height = math.max(tall, 3), At = at, Grow = grow, Own = eye ~= nil }
end

-- Between two ways of standing (0 the first, 1 the second)
function AuraVolume.between(a: Shape, b: Shape, k: number): Shape
	return {
		X = lerp(a.X, b.X, k),
		Z = lerp(a.Z, b.Z, k),
		Height = lerp(a.Height, b.Height, k),
		At = a.At:Lerp(b.At, k),
		Grow = lerp(a.Grow, b.Grow, k),
		Own = if k < 0.5 then a.Own else b.Own,
	}
end

-- How strong it is drawn there (our own calmer one, Aura.EyeCalm: the less the higher its tier)
function AuraVolume.strong(spec: Spec, s: Shape, c: { [string]: any }): number
	return if s.Own then lerp(1, c.EyeStrength, (spec.Tier - 1) / 11) else 1
end

-- How many of a layer are let out a second
function AuraVolume.rate(l: Layer, s: Shape, detail: number, c: { [string]: any }): number
	if s.Own and l.Across then
		return 0
	end
	local rate = l.Rate * math.clamp(s.Grow, 1, c.RideMore)
	if l.Name == "Wisps" and s.Grow > 1 then
		rate = math.max(rate, c.RideWisps) -- (round a whole fish the first tiers' few would be lost)
	end
	return rate * AuraVolume.Rates[detail]
end

-- The place of a layer in a shape: its middle over the foot, and its size
function AuraVolume.place(l: Layer, s: Shape): (number, Vector3)
	local wide = Vector3.new(2 * s.X * l.Wide, 0, 2 * s.Z * l.Wide)
	if l.Place == "Band" then
		-- (its pictures stand on the ground: let out half a picture up)
		return l.Size[1][2] * s.Grow * 0.42, wide + Vector3.new(0, 0.2, 0)
	elseif l.Place == "Flat" then
		return 0.12, Vector3.new(0.2, 0.2, 0.2)
	elseif l.Place == "Foot" then
		return 0.6 * s.Grow, wide + Vector3.new(0, 0.5 * s.Grow, 0)
	elseif l.Place == "Top" then
		return s.Height * 0.54, wide + Vector3.new(0, 0.2, 0)
	elseif l.Name == "Pillar" then
		return s.Height * 0.62, wide + Vector3.new(0, 1, 0)
	elseif l.Place == "Wall" then
		return s.Height * 0.36, wide + Vector3.new(0, s.Height * 0.55, 0)
	end
	return s.Height * 0.3, wide + Vector3.new(0, s.Height * 0.5, 0)
end

-- -1..1, smooth, a few wobbles a second
function AuraVolume.wander(t: number, seed: number): number
	return 0.6 * math.sin(t * 2.3 + seed * 1.7) + 0.3 * math.sin(t * 4.1 + seed * 4.1) + 0.1 * math.sin(t * 7.3 + seed)
end

-- Point i of a strand (1 to Beams + 1) now: its place and its way on (a unit vector), and how long a curve's handle
-- is there (a Beam is a cubic curve: a spiral of up to half a turn is one, to about 2%)
function AuraVolume.strandAt(s: Strand, shape: Shape, i: number, clock: number, t: number): (Vector3, Vector3, number)
	local u = (i - 1) / s.Beams
	local angle = (s.From + s.Turns * u) * 2 * math.pi + s.Spin * clock
	local sign = if s.Spin < 0 then -1 else 1
	angle = if sign < 0 then -(s.From + s.Turns * u) * 2 * math.pi + s.Spin * clock else angle
	local wide = lerp(s.WideLow, s.WideHigh, u) * (1 + 0.05 * AuraVolume.wander(t, s.Seed + i * 3))
	local x, z = shape.X * wide, shape.Z * wide
	local y = (lerp(s.Low, s.High, u) + s.Wave * AuraVolume.wander(t * 0.8, s.Seed + i * 5) * u) * shape.Height
	local swept = s.Turns * 2 * math.pi / s.Beams -- of one Beam
	local rise = (s.High - s.Low) * shape.Height / s.Beams
	local handle = 4 / 3 * math.tan(swept / 4)
	-- the way on: d(place)/d(u of one Beam), as the cubic wants it (its handle is a third of that, near enough)
	local along = Vector3.new(-math.sin(angle) * x * sign * handle, rise / 3, math.cos(angle) * z * sign * handle)
	local long = along.Magnitude
	return Vector3.new(math.cos(angle) * x, y, math.sin(angle) * z),
		if long > 1e-4 then along / long else Vector3.yAxis,
		long
end

-- A strand's strength along its whole length, 0 to 1: clear at its foot, solid to its head, where it thins out
function AuraVolume.strandFade(u: number): number
	local foot = math.clamp(u / 0.35, 0, 1)
	local head = math.clamp((1 - u) / 0.22, 0, 1)
	return foot * foot * (3 - 2 * foot) * head
end

-- A ribbon's width at a share of its length
function AuraVolume.strandWidth(s: Strand, u: number): number
	local w = s.Width
	return if u < 0.7 then lerp(w[1], w[2], u / 0.7) else lerp(w[2], w[3], (u - 0.7) / 0.3)
end

---------------------------------------------------------------------------------------------------------------------
-- How it moves
---------------------------------------------------------------------------------------------------------------------

-- 0..1: how far into a pulse, and which pulse this is
function AuraVolume.pulseAt(spec: Spec, t: number): (number, number)
	local p = spec.Pulse
	if not p then
		return 0, 0
	end
	local n = math.floor(t / p.Every)
	local u = t - n * p.Every
	return (if u < p.Rise then u / p.Rise else math.max(0, 1 - (u - p.Rise) / p.Fall) ^ 2), n
end

-- 0..1, `u` seconds after a hop, a landing or a boost
function AuraVolume.flareAt(u: number): number
	if u < 0 then
		return 0
	end
	return if u < 0.08 then u / 0.08 else math.max(0, 1 - (u - 0.08) / 0.6) ^ 2
end

-- How much bigger everything stands `u` seconds after it is put on: a burst (tier 10 up), or it rises
function AuraVolume.putOn(spec: Spec, u: number): number
	if u < 0 then
		return 0.3
	elseif spec.Burst then
		if u < 0.14 then
			return lerp(0.3, 1.4, u / 0.14)
		end
		return 1 + 0.4 * math.max(0, 1 - (u - 0.14) / 0.7) ^ 2
	end
	return lerp(0.6, 1, math.clamp(u / 0.3, 0, 1))
end

-- The moment: how much wider the ribbons are, and how much brighter the light and the ribbons
function AuraVolume.moment(spec: Spec, t: number, flare: number?): (number, number)
	local p = AuraVolume.pulseAt(spec, t)
	local f = if flare then AuraVolume.flareAt(flare) else 0
	local strong = if spec.Pulse then spec.Pulse.Strength else 0
	return 1 + 0.35 * strong * p + 0.5 * f, 1 + strong * p + 0.8 * f
end

return AuraVolume
