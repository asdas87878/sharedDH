--!strict
-- The flame auras' numbers (draft 4; Hugo, 2026-11-24: "make sure that we implement auras"; docs/design/auras.md, and
-- the mock they come from: work/auras4/flame.py in the worktree sharedDH-auras). What a tier is made of and how it moves,
-- as plain sums: nothing here makes an Instance, so tools/auras/aura_test.luau checks it offline. Client Lib/AuraBeams
-- builds it, Controllers/AuraController decides who wears it. Studs and seconds; standing, the feet at 0.
-- One family, cumulative: every tier keeps everything of the tiers under it and adds one thing (FROM).
local Auras = require(script.Parent.Auras)

local AuraFlame = {}

export type Tip = { X: number, Foot: number, Top: number, Width: number, Lean: number } -- shares of the width and height
export type Layer = {
	Name: string,
	Picture: string, -- "Flame" or "Streaks"
	Height: number, -- the foot to the tallest tongue's tip
	Width: number, -- the body's own width at its widest; the picture's solid band is 0.62 of it
	Tips: { Tip },
	TipStrength: number, -- the tongues' strength against the body's
	FadeFrom: number, -- the body fades out from this share of the height to its top
	Repeat: number, -- studs of Beam to one repeat of the picture
	Color: Color3,
	Transparency: number, -- where it is strongest
	Emission: number,
	Rate: number, -- repeats a second, upward
	Phase: number,
	Sway: number, -- a tongue's tip wanders this far to each side
	Seed: number,
}
export type Extra = {
	Name: string,
	Picture: string, -- "Lick", "Bubble", "Arc" or "Glow" (the engine's own soft glow)
	Rate: number,
	Life: { number },
	Speed: { number },
	Spread: number,
	Radius: number, -- its cylinder round the body,
	Height: number,
	At: number, -- whose middle is this far over the feet
	Size: { { number } },
	SizeJitter: number,
	Fade: { { number } },
	Color: Color3,
	Emission: number,
	Accel: number,
	Drag: number,
	Upright: boolean,
	Spin: boolean,
	Flare: number, -- let out at once in a flare,
	Burst: number, -- and in the burst
}
export type Spec = {
	Tier: number,
	Scale: number,
	Layers: { Layer }, -- back to front
	Extras: { Extra },
	Pulse: { Every: number, Width: number, Strength: number, Rise: number, Fall: number }?,
	Wave: { Count: number, Share: number, Half: number, Color: Color3, Transparency: number, Emission: number }?,
	FlareLand: boolean,
	FlareHop: boolean,
	FlareBoost: boolean,
	RideFast: number, -- the scroll is this many times as fast while riding
	Burst: boolean,
}
-- What a moment does to the whole flame
export type Moment = { High: number, Wide: number, Strength: number, Seen: number }

-- The tier each thing comes in at
AuraFlame.From = {
	Flame = 1,
	Licks = 2,
	Inner = 3,
	Streaks = 4,
	Pulse = 5,
	Waves = 6,
	Bubbles = 7,
	FlareLand = 7,
	Tongues = 8,
	FlareHop = 8,
	Spray = 9,
	FlareBoost = 9,
	Arcs = 10,
	Burst = 10,
	Core = 11,
	Crown = 12,
}
AuraFlame.Base = 0.25 -- the flame's foot over the feet (the ankles): nothing is drawn below it
AuraFlame.SeatBase = 1.9 -- sat on a fish it starts here, at the hips,
AuraFlame.Seated = 0.65 -- and is this share of its standing height
AuraFlame.Foot = 0.9 -- full strength this far over its foot, times the tier's scale
AuraFlame.Behind = -1.5 -- every Beam is drawn this far behind (ZOffset): the wearer's own body hides it
AuraFlame.BehindFoot = -0.8 -- the lowest of each body: a smaller push, so the floor cuts no line through the foot
AuraFlame.Push = 1.6 -- particles: -(their cylinder's radius + this)
-- the body's outline: shares of the layer's height and of its width. Five Beams between six joints
AuraFlame.Profile = {
	{ 0, 0.8 },
	{ 0.14, 0.944 },
	{ 0.3, 1 },
	{ 0.44, 0.961 },
	{ 0.58, 0.843 },
	{ 0.7, 0.68 },
}
-- (past the body's top a wave narrows with the tongues)
local OUTLINE = table.clone(AuraFlame.Profile)
table.insert(OUTLINE, { 0.86, 0.46 })
table.insert(OUTLINE, { 1, 0.24 })

local function tip(x: number, foot: number, top: number, width: number, lean: number): Tip
	return { X = x, Foot = foot, Top = top, Width = width, Lean = lean }
end

local FIVE = {
	tip(-0.25, 0.36, 0.7, 0.26, -0.035),
	tip(-0.13, 0.42, 0.88, 0.27, -0.02),
	tip(0.01, 0.46, 1, 0.31, 0.01),
	tip(0.14, 0.42, 0.8, 0.27, 0.03),
	tip(0.26, 0.36, 0.64, 0.25, 0.04),
}
local FIVE_TURNED: { Tip } = {} -- the Crown's: the other way round
for _, v in FIVE do
	table.insert(FIVE_TURNED, tip(-v.X, v.Foot, v.Top, v.Width, -v.Lean))
end
local THREE = {
	tip(-0.15, 0.4, 0.82, 0.3, -0.02),
	tip(0.02, 0.46, 1, 0.33, 0),
	tip(0.16, 0.4, 0.86, 0.3, 0.025),
}
local TWO = { tip(-0.07, 0.42, 0.88, 0.4, -0.01), tip(0.06, 0.46, 1, 0.42, 0.01) }

local WHITE = Color3.new(1, 1, 1)

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- `a` at the tier a thing first comes in at, `b` at tier 12
local function ramp(tier: number, first: number, a: number, b: number): number
	return lerp(a, b, (tier - first) / math.max(12 - first, 1))
end

-- Everything one tier is made of
function AuraFlame.spec(tier: number): Spec
	local from = AuraFlame.From
	local k = (tier - 1) / 11
	local s = 1 + 0.24 * k
	local color: Color3 = Auras.Tiers[tier].Main
	local function pale(share: number): Color3
		return color:Lerp(WHITE, share)
	end
	local layers: { Layer } = {}
	local function layer(name: string, wide: number, high: number, props: { [string]: any })
		local l = {
			Name = name,
			Picture = "Flame",
			Height = 7.45 * s * high,
			Width = 6.6 * s * wide,
			Tips = {},
			TipStrength = 1,
			FadeFrom = 0.5,
			Repeat = 3.7 * s * high,
			Color = color,
			Transparency = 0.5,
			Emission = 0.2,
			Rate = 1,
			Phase = 0,
			Sway = lerp(0.16, 0.3, k) * s,
			Seed = 1,
		}
		for key, v in props do
			(l :: any)[key] = v
		end
		table.insert(layers, l)
	end
	if tier >= from.Crown then
		layer("Crown", 1, 1.04, {
			Color = pale(0.15),
			Transparency = 0.66,
			Emission = 0.3,
			Rate = 1.5,
			Phase = 0.37,
			Seed = 5,
			Tips = FIVE_TURNED,
			TipStrength = 0.8,
		})
	end
	layer("Flame", 1, 1, {
		Transparency = lerp(0.42, 0.32, k),
		Rate = lerp(0.62, 1, k),
		Seed = 1,
		Tips = FIVE,
	})
	if tier >= from.Inner then
		layer("Inner", 0.78, 0.88, {
			Color = pale(0.4),
			Transparency = ramp(tier, from.Inner, 0.62, 0.55),
			Emission = 0.3,
			Rate = lerp(0.85, 1.3, k),
			Phase = 0.55,
			Seed = 2,
			Tips = THREE,
			TipStrength = 0.7,
		})
	end
	if tier >= from.Streaks then
		layer("Streaks", 0.85, 1.3, {
			Picture = "Streaks",
			Color = pale(0.65),
			Transparency = ramp(tier, from.Streaks, 0.15, 0.05),
			Emission = 0.5,
			Rate = ramp(tier, from.Streaks, 2.2, 3),
			Phase = 0.1,
			Seed = 4,
			FadeFrom = 0.45,
		})
	end
	if tier >= from.Core then
		layer("Core", 0.6, 0.76, {
			Color = pale(0.8),
			Transparency = ramp(tier, from.Core, 0.55, 0.5),
			Emission = 0.6,
			Rate = 1.7,
			Phase = 0.2,
			Seed = 3,
			Tips = TWO,
			TipStrength = 0.7,
		})
	end

	local extras: { Extra } = {}
	local function extra(name: string, picture: string, props: { [string]: any })
		local e = {
			Name = name,
			Picture = picture,
			Rate = 1,
			Life = { 1, 1 },
			Speed = { 0, 0 },
			Spread = 0,
			Radius = 2 * s,
			Height = 2 * s,
			At = 3 * s,
			Size = { { 0, 1 }, { 1, 1 } },
			SizeJitter = 0,
			Fade = { { 0, 0 }, { 1, 1 } },
			Color = color,
			Emission = 0.2,
			Accel = 0,
			Drag = 0,
			Upright = false,
			Spin = false,
			Flare = 0,
			Burst = 0,
		}
		for key, v in props do
			(e :: any)[key] = v
		end
		table.insert(extras, e)
	end
	if tier >= from.Licks then
		extra("Licks", "Lick", {
			Rate = ramp(tier, from.Licks, 7, 10),
			Life = { 0.5, 0.8 },
			Speed = { 4, 6 },
			Spread = 12,
			Radius = 1.9 * s,
			Height = 2.4 * s,
			At = 3.6 * s,
			Size = { { 0, 1.9 * s }, { 1, 0.4 * s } },
			Fade = { { 0, 1 }, { 0.15, 0.12 }, { 0.7, 0.3 }, { 1, 1 } },
			Upright = true,
			Flare = 5,
			Burst = 10,
		})
	end
	if tier >= from.Bubbles then
		extra("Bubbles", "Bubble", {
			Rate = ramp(tier, from.Bubbles, 11, 15),
			Life = { 0.7, 1.15 },
			Speed = { 1.5, 3 },
			Spread = 25,
			Radius = 2.6 * s,
			Height = 3.6 * s,
			At = 3.9 * s,
			Size = { { 0, 0.42 }, { 0.85, 0.72 }, { 1, 1.05 } },
			Fade = { { 0, 1 }, { 0.1, 0.15 }, { 0.85, 0.25 }, { 1, 1 } },
			Color = pale(0.7),
			Emission = 0.3,
			Accel = 2,
			Drag = 1,
			Flare = 14,
			Burst = 20,
		})
	end
	if tier >= from.Tongues then
		extra("Tongues", "Lick", {
			Rate = ramp(tier, from.Tongues, 4, 5),
			Life = { 0.5, 0.65 },
			Speed = { 3, 4.5 },
			Spread = 8,
			Radius = 1.6 * s,
			Height = 1.6 * s,
			At = 5 * s,
			Size = { { 0, 3 * s }, { 1, 0.6 * s } },
			Fade = { { 0, 1 }, { 0.15, 0.1 }, { 0.7, 0.3 }, { 1, 1 } },
			Color = pale(0.25),
			Emission = 0.25,
			Upright = true,
			Burst = 4,
		})
	end
	if tier >= from.Spray then
		extra("Spray", "Glow", {
			Rate = ramp(tier, from.Spray, 24, 30),
			Life = { 0.4, 0.7 },
			Speed = { 8, 12.5 },
			Spread = 26,
			Radius = 2.3 * s,
			Height = 3 * s,
			At = 3.5 * s,
			Size = { { 0, 1.1 }, { 1, 0.45 } },
			Fade = { { 0, 0 }, { 0.6, 0.15 }, { 1, 1 } },
			Color = pale(0.75),
			Emission = 0.6,
			Drag = 3,
			Flare = 20,
			Burst = 30,
		})
	end
	if tier >= from.Arcs then
		extra("Arcs", "Arc", {
			Rate = ramp(tier, from.Arcs, 12, 15),
			Life = { 0.14, 0.24 },
			Radius = 2.2 * s,
			Height = 2.6 * s,
			At = 4.1 * s,
			Size = { { 0, 1.5 * s }, { 1, 2.2 * s } },
			SizeJitter = 0.35,
			Fade = { { 0, 0.05 }, { 0.7, 0.15 }, { 1, 1 } },
			Color = pale(0.85),
			Emission = 0.8,
			Spin = true,
			Burst = 6,
		})
	end
	return {
		Tier = tier,
		Scale = s,
		Layers = layers,
		Extras = extras,
		Pulse = if tier >= from.Pulse
			then { Every = ramp(tier, from.Pulse, 1.7, 1.25), Width = 0.09, Strength = 0.25, Rise = 0.14, Fall = 0.6 }
			else nil,
		Wave = if tier >= from.Waves
			then { Count = 2, Share = 0.62, Half = 0.2, Color = pale(0.75), Transparency = 0.15, Emission = 0.6 }
			else nil,
		FlareLand = tier >= from.FlareLand,
		FlareHop = tier >= from.FlareHop,
		FlareBoost = tier >= from.FlareBoost,
		RideFast = if tier >= from.FlareBoost then 1.4 else 1,
		Burst = tier >= from.Burst,
	}
end

-- Beams in the whole aura: five to a body, one to a top tongue, and the waves
function AuraFlame.beams(spec: Spec): number
	local n = if spec.Wave then spec.Wave.Count else 0
	for _, l in spec.Layers do
		n += #AuraFlame.Profile - 1 + #l.Tips
	end
	return n
end

-- Particles alive at once, standing still
function AuraFlame.alive(spec: Spec): number
	local n = 0
	for _, e in spec.Extras do
		n += e.Rate * (e.Life[1] + e.Life[2]) / 2
	end
	return n
end

---------------------------------------------------------------------------------------------------------------------
-- How it moves
---------------------------------------------------------------------------------------------------------------------

-- -1..1, smooth, a few wobbles a second
function AuraFlame.wander(t: number, seed: number): number
	return 0.6 * math.sin(t * 5.3 + seed * 1.7)
		+ 0.3 * math.sin(t * 9.1 + seed * 4.1)
		+ 0.1 * math.sin(t * 17.3 + seed * 2.3)
end

-- 0..1: how far into a pulse
function AuraFlame.pulseAt(spec: Spec, t: number): number
	local p = spec.Pulse
	if not p then
		return 0
	end
	local u = t % p.Every
	return if u < p.Rise then u / p.Rise else math.max(0, 1 - (u - p.Rise) / p.Fall) ^ 2
end

-- 0..1, `u` seconds after a hop, a landing or a boost
function AuraFlame.flareAt(u: number): number
	if u < 0 then
		return 0
	end
	return if u < 0.08 then u / 0.08 else math.max(0, 1 - (u - 0.08) / 0.5) ^ 2
end

-- The height's and the width's times and the strength more, `u` seconds after it is put on (tier 10 up)
function AuraFlame.burstAt(u: number): (number, number, number)
	if u < 0 then
		return 0, 0, 0
	elseif u < 0.14 then
		local k = u / 0.14
		return lerp(0.3, 1.42, k), lerp(0.5, 1.5, k), 0.25 * k
	end
	local k = math.max(0, 1 - (u - 0.14) / 0.7) ^ 2
	return 1 + 0.42 * k, 1 + 0.5 * k, 0.25 * k
end

-- The whole flame's moment: `flare` seconds since the last flare, `on` since it was put on (nil: not just now)
function AuraFlame.moment(spec: Spec, t: number, flare: number?, on: number?): Moment
	local high, wide, strength, seen = 1, 1, 0, 1
	local pulse = spec.Pulse
	if pulse then
		local p = AuraFlame.pulseAt(spec, t)
		wide *= 1 + pulse.Width * p
		strength += pulse.Strength * p
	end
	if flare then
		local f = AuraFlame.flareAt(flare)
		wide *= 1 + 0.28 * f
		high *= 1 + 0.22 * f
		strength += 0.2 * f
	end
	if on then
		if spec.Burst then
			local h, w, s = AuraFlame.burstAt(on)
			high *= h
			wide *= w
			strength += s
			seen = if on >= 0 then 1 else 0
		else
			-- below tier 10 it simply rises
			seen = math.clamp(on / 0.3, 0, 1)
			high *= lerp(0.6, 1, seen)
		end
	end
	return { High = high, Wide = wide, Strength = strength, Seen = seen }
end

-- How far a layer's middle line is pushed sideways at a share of its height
function AuraFlame.bend(l: Layer, share: number, t: number): number
	return 0.6 * l.Sway * (math.clamp(share, 0, 1) / 0.7) ^ 1.6 * AuraFlame.wander(t * 0.9, l.Seed + 5)
end

-- A layer's height now: the moment's, the seat's (1 standing, Seated on a fish) and its small bob
function AuraFlame.height(l: Layer, m: Moment, short: number, t: number): number
	return l.Height * m.High * short * (1 + 0.035 * AuraFlame.wander(t * 1.3, l.Seed + 7))
end

-- The outline's width at a share of the height, as a share of the layer's width
function AuraFlame.outline(share: number): number
	local last = OUTLINE[1]
	for _, p in OUTLINE do
		if share <= p[1] then
			local span = p[1] - last[1]
			return if span <= 0 then p[2] else lerp(last[2], p[2], (share - last[1]) / span)
		end
		last = p
	end
	return last[2]
end

-- Top tongue i of a layer: its foot's and its tip's place (across, up) and its width
function AuraFlame.tongue(l: Layer, i: number, wide: number, high: number, t: number): (Vector2, Vector2, number)
	local v = l.Tips[i]
	-- (the mock counts its tongues from 0)
	local n = i - 1
	local bend = AuraFlame.bend(l, v.Foot, t)
	local foot = Vector2.new(v.X * wide + bend, v.Foot * high)
	local flick = 1 + 0.13 * AuraFlame.wander(t * 1.7, l.Seed * 7 + n * 13)
	local top = Vector2.new(
		(v.X + v.Lean) * wide + bend + l.Sway * AuraFlame.wander(t * 1.1, l.Seed + n * 5 + 11),
		foot.Y + (v.Top - v.Foot) * high * flick
	)
	return foot, top, v.Width * wide
end

-- How strong the body is at a share of its height, 0 to 1: clear at the foot, out again where the tongues take over
function AuraFlame.fade(l: Layer, share: number, scale: number): number
	local foot = math.clamp(share * l.Height / (AuraFlame.Foot * scale), 0, 1) ^ 1.2
	local top = AuraFlame.Profile[#AuraFlame.Profile][1]
	return foot * (1 - math.clamp((share - l.FadeFrom) / (top - l.FadeFrom), 0, 1) ^ 1.3)
end

-- A layer's body's strength now (its streaks rush with every pulse from tier 6), and its tongues'
function AuraFlame.strength(spec: Spec, l: Layer, m: Moment, t: number): (number, number)
	local body = 1 - l.Transparency
	if l.Picture == "Flame" then
		body += m.Strength
	elseif spec.Wave then
		body *= 1 + 0.9 * AuraFlame.pulseAt(spec, t)
	end
	local tips = (1 - l.Transparency) * l.TipStrength + m.Strength
	return math.clamp(body, 0, 1) * m.Seen, math.clamp(tips, 0, 1) * m.Seen
end

-- How far a layer's picture has run up, in repeats (`clock`: the seconds it has run, faster while riding)
function AuraFlame.scroll(spec: Spec, l: Layer, clock: number, t: number): number
	local run = l.Rate * clock - l.Phase
	local p = spec.Pulse
	if p and spec.Wave and l.Picture == "Streaks" then
		run += 0.55 * (math.floor(t / p.Every) + math.min(1, (t % p.Every) / (p.Rise + p.Fall)) ^ 0.6)
	end
	return run
end

-- Wave i of tier 6 up: its foot's, middle's and tip's share of the height, or nil while it is out of sight
function AuraFlame.waveAt(spec: Spec, i: number, t: number): (number?, number, number)
	local w, p = spec.Wave, spec.Pulse
	if not w or not p then
		return nil, 0, 0
	end
	local up = ((t + (i - 1) * p.Every / w.Count) % p.Every) / (w.Share * p.Every)
	if up >= 1 then
		return nil, 0, 0
	end
	local middle = -w.Half + (1 + 2 * w.Half) * (1 - (1 - up) ^ 1.3)
	local foot, top = math.max(middle - w.Half, 0), math.min(middle + w.Half, 1)
	if top - foot < 0.02 then
		return nil, 0, 0
	end
	return foot, middle, top
end

-- A wave's strength at a share of the height
function AuraFlame.waveFade(spec: Spec, l: Layer, middle: number, share: number): number
	local w = spec.Wave
	if not w then
		return 0
	end
	local window = math.clamp(1 - math.abs(share - middle) / w.Half, 0, 1) ^ 0.8
	local thin = 1 - math.clamp((share - 0.72) / 0.28, 0, 1) ^ 1.2
	local foot = math.clamp(share * l.Height / (AuraFlame.Foot * spec.Scale), 0, 1) ^ 1.2
	return window * thin * foot * (1 - w.Transparency)
end

return AuraFlame
