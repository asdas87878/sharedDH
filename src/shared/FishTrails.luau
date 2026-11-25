--!strict
-- The trail behind a fish: haze and bubbles, cooler the more power the fish has (the user, 2026-11-25;
-- docs/design/fish-trails.md). Numbers only, read by Controllers/FishTrailController and Lib/FishTrailRig on each
-- player's own machine; the server has no part in it.
-- In this file: the switch, power and its steps, who gets a trail and what all may cost, speed and colour, the view, and each
-- step's layers.
local FishTrails = {}

FishTrails.On = 1 -- 1: these trails; 0: the old white wake alone (Config.Wake). In Studio workspace's "FishTrails" (0 or 1) wins, and T flips it

----------------------------------------------------------------------------------------------------------------------
-- Power: points by size, rarity and real length, and the steps (tools/trails/step_shares.py reads these four tables)

FishTrails.SizePoints = { Tiny = -1, Normal = 0, Big = 1, Giant = 2, Huge = 3, Colossal = 4 } :: { [string]: number }
FishTrails.RarityPoints =
	{ Common = 0, Uncommon = 0.5, Rare = 1, Epic = 1.5, Legendary = 2, Mythic = 4, Secret = 5.5 } :: { [string]: number }
FishTrails.LengthPoints = { 60, 0.5, 110, 1 } -- pairs: from this length, studs, this many points; shortest first
FishTrails.StepFrom = { -10, 1, 2, 3, 4, 5.5 } -- points a step starts at
FishTrails.StepName = { "Wisp", "Stream", "Plume", "Surge", "Storm", "Titan" }

function FishTrails.points(sizeTier: string, rarity: string, length: number): number
	local long = 0
	for i = 1, #FishTrails.LengthPoints, 2 do
		if length >= FishTrails.LengthPoints[i] then
			long = FishTrails.LengthPoints[i + 1]
		end
	end
	return (FishTrails.SizePoints[sizeTier] or 0) + (FishTrails.RarityPoints[rarity] or 0) + long
end

function FishTrails.step(points: number): number
	local step = 1
	for i, from in FishTrails.StepFrom do
		if points >= from then
			step = i
		end
	end
	return step
end

----------------------------------------------------------------------------------------------------------------------
-- Who gets one, and what all of them may cost together

FishTrails.Look = 0.25 -- seconds between looks at who should have a trail
FishTrails.Keep = 18 -- a fish that has one counts as this much nearer, studs (two fish don't swap back and forth)
FishTrails.StepNear = 22 -- and each power step as this much nearer
FishTrails.OffScreen = 0.35 -- none for a fish this far out of the view (the cosine of its angle off the middle: 0.35 is 70 degrees),
FishTrails.OffNear = 30 -- but one whose body is nearer than this, studs, is never off it
FishTrails.SurfaceGap = 2 -- no trail for a fish whose middle is nearer the sea's surface than this, studs, or over it

export type Level = { Rigs: number, Far: number, Particles: number, Draws: number, Most: number, Rate: number }
FishTrails.Levels = {
	-- Rigs: trails at once. Far: none past this, studs. Particles and Draws: the most in all, worked out (a step is taken off the
	-- last of them until it fits; Draws counts one for each emitter, ribbon and front sheet). Most: the top step.
	-- Rate: times every emitter's rate.
	Full = { Rigs = 8, Far = 180, Particles = 260, Draws = 48, Most = 6, Rate = 1 },
	Lite = { Rigs = 4, Far = 110, Particles = 60, Draws = 16, Most = 3, Rate = 0.5 },
} :: { [string]: Level }

-- Lite is picked by the saved graphics level (this or lower), by a phone or tablet (Kit.touch) whatever its level, or after SlowFor seconds
-- under SlowFps (back to Full after FastFor over FastFps). In Studio workspace's "FishTrailsLevel" ("Full" or "Lite") wins.
FishTrails.LiteLevel = 3
FishTrails.LiteTouch = 1
FishTrails.SlowFps = 40
FishTrails.SlowFor = 3
FishTrails.FastFps = 52
FishTrails.FastFor = 20

----------------------------------------------------------------------------------------------------------------------
-- Speed, size and colour

FishTrails.SpeedNone = 8 -- no trail at or under this, studs a second
FishTrails.SpeedFull = 45 -- the whole of it from here
FishTrails.SpeedLeast = 0.35 -- the share of it there is just over SpeedNone
-- a puff's size, studs: PuffBase x (the body's width x height) ^ PuffGrow, so a whale's are not 50 times a clownfish's
FishTrails.PuffBase = 1
FishTrails.PuffGrow = 0.35
FishTrails.PuffMost = 12
FishTrails.BurstAt = 45 -- a fish gaining speed faster than this, studs a second a second, throws bubbles,
FishTrails.BurstEvery = 0.9 -- no more often than this, seconds,
FishTrails.BurstShare = 0.5 -- this share of what its bubbles have alive
FishTrails.Water = 0.3 -- how far the white haze is toward the land's water (its fog colour),
FishTrails.WaterDark = 0.4 -- and this much more in black water (white would shine there)

----------------------------------------------------------------------------------------------------------------------
-- The view: never in the way

FishTrails.NearFade = 10 -- another fish whose haze (its live part) comes this near the camera goes see-through,
FishTrails.NearGone = 4 -- wholly from here, studs
-- our own fish: its haze and bubbles are sent on with it at this share of its speed (so they drift back slowly, beside it), and
-- last this share as long
FishTrails.OwnCarry = 0.7
FishTrails.OwnLife = 0.6
FishTrails.OwnRate = 0.7
FishTrails.OwnSee = 0.6 -- times how solid they are
FishTrails.OwnAt = 0.3 -- it starts no further back than this share of the way to the camera (a long fish's tail is behind us)
FishTrails.OwnClear = 0.25 -- and is gone this share of the rest of the way before it
FishTrails.OwnPuff = 4.5 -- no puff size over this, studs
FishTrails.OwnTail = 0.35 -- times how solid its middle ribbon is (straight down the view)

----------------------------------------------------------------------------------------------------------------------
-- The layers of each step. One that isn't there is off.
-- See: how solid at its most (0 to 1). Life: seconds. Rate: a second at whole speed. From, To: a puff's size, times the fish's
-- puff size.

export type Puff = { Rate: number, Life: number, See: number, From: number, To: number }
export type Ribbon = { Life: number, See: number, Wide: number, Twist: number, Round: number }
export type Recipe = {
	Ribbon: Ribbon, -- the soft streak off the tail. Wide: a share of the body's width
	Bubbles: Puff,
	Haze: Puff?, -- low behind the tail
	Roll: Puff?, -- out to the sides, off the fins
	Curl: Ribbon?, -- a pair off the fin tips. Twist: turns a second; Round: how wide the corkscrew is, a share of the body's width
	CurlGlow: Ribbon?, -- and a second pair in the glow colour, half a turn round
	Front: { See: number, Wide: number }?, -- the pressure front: a sheet of water either side of the head
	Storm: Puff?, -- bubbles off the whole body
	Glow: Puff?, -- the fish's own light in the haze
	Rings: Puff?, -- vapour rings left behind
	Own: number, -- how far the haze is toward the fish's own colour
}

FishTrails.Recipes = {
	{ -- 1 Wisp: one thin ribbon and a few bubbles
		Ribbon = { Life = 0.55, See = 0.3, Wide = 0.28, Twist = 0, Round = 0 },
		Bubbles = { Rate = 7, Life = 0.8, See = 0.8, From = 0.12, To = 0.26 },
		Own = 0,
	},
	{ -- 2 Stream: small soft puffs
		Ribbon = { Life = 0.65, See = 0.34, Wide = 0.34, Twist = 0, Round = 0 },
		Bubbles = { Rate = 8, Life = 0.9, See = 0.8, From = 0.14, To = 0.3 },
		Haze = { Rate = 10, Life = 0.8, See = 0.5, From = 0.45, To = 1.05 },
		Own = 0.1,
	},
	{ -- 3 Plume: a wide haze, and two ribbons straight off the fins
		Ribbon = { Life = 0.75, See = 0.36, Wide = 0.38, Twist = 0, Round = 0 },
		Bubbles = { Rate = 10, Life = 1, See = 0.85, From = 0.14, To = 0.34 },
		Haze = { Rate = 13, Life = 1, See = 0.55, From = 0.55, To = 1.35 },
		Curl = { Life = 0.7, See = 0.4, Wide = 0.16, Twist = 0, Round = 0 },
		Own = 0.2,
	},
	{ -- 4 Surge: the ribbons twist into corkscrews, and the haze rolls outward
		Ribbon = { Life = 0.8, See = 0.36, Wide = 0.4, Twist = 0, Round = 0 },
		Bubbles = { Rate = 12, Life = 1.05, See = 0.85, From = 0.16, To = 0.38 },
		Haze = { Rate = 13, Life = 1.1, See = 0.58, From = 0.6, To = 1.55 },
		Roll = { Rate = 10, Life = 0.9, See = 0.45, From = 0.4, To = 1.2 },
		Curl = { Life = 0.95, See = 0.55, Wide = 0.2, Twist = 2.1, Round = 0.1 },
		Own = 0.28,
	},
	{ -- 5 Storm: the pressure front, bubbles off the whole body, its own light
		Ribbon = { Life = 0.85, See = 0.3, Wide = 0.42, Twist = 0, Round = 0 },
		Bubbles = { Rate = 12, Life = 1.1, See = 0.9, From = 0.16, To = 0.42 },
		Haze = { Rate = 13, Life = 1.2, See = 0.6, From = 0.65, To = 1.7 },
		Roll = { Rate = 11, Life = 1, See = 0.5, From = 0.45, To = 1.35 },
		Curl = { Life = 1.1, See = 0.65, Wide = 0.24, Twist = 2.3, Round = 0.12 },
		Front = { See = 0.55, Wide = 0.5 },
		Storm = { Rate = 18, Life = 0.9, See = 0.85, From = 0.1, To = 0.4 },
		Glow = { Rate = 9, Life = 0.55, See = 0.5, From = 1.1, To = 0.4 },
		Own = 0.36,
	},
	{ -- 6 Titan: vapour rings, and a second pair of curls that shine
		Ribbon = { Life = 0.9, See = 0.28, Wide = 0.45, Twist = 0, Round = 0 },
		Bubbles = { Rate = 13, Life = 1.1, See = 0.9, From = 0.16, To = 0.46 },
		Haze = { Rate = 14, Life = 1.3, See = 0.62, From = 0.7, To = 1.85 },
		Roll = { Rate = 13, Life = 1.1, See = 0.52, From = 0.5, To = 1.5 },
		Curl = { Life = 1.3, See = 0.75, Wide = 0.26, Twist = 2.3, Round = 0.14 },
		CurlGlow = { Life = 1, See = 0.8, Wide = 0.14, Twist = 2.3, Round = 0.14 },
		Front = { See = 0.75, Wide = 0.65 },
		Storm = { Rate = 26, Life = 1, See = 0.9, From = 0.1, To = 0.46 },
		Glow = { Rate = 12, Life = 0.7, See = 0.6, From = 1.5, To = 0.4 },
		Rings = { Rate = 1.7, Life = 1.3, See = 0.75, From = 1.6, To = 3.2 },
		Own = 0.45,
	},
} :: { Recipe }

-- A Silver, a Gold or a Rainbow: its own colours in place of the kind's, and glints
FishTrails.Variants = {
	Silver = { Main = Color3.fromRGB(205, 220, 235), Glow = Color3.fromRGB(140, 215, 255) },
	Gold = { Main = Color3.fromRGB(255, 206, 43), Glow = Color3.fromRGB(255, 222, 110) },
	Rainbow = { Main = Color3.fromRGB(255, 255, 255), Glow = Color3.fromRGB(255, 255, 255) },
} :: { [string]: { Main: Color3, Glow: Color3 } }
FishTrails.VariantOwn = 0.5 -- how far its haze is toward that colour (or the step's own, if that is more)
FishTrails.Glints = { Rate = 6, Life = 0.8, See = 1, From = 0.35, To = 0.05 } :: Puff
FishTrails.Rainbow = {
	Color3.fromRGB(255, 70, 95),
	Color3.fromRGB(255, 150, 40),
	Color3.fromRGB(255, 225, 60),
	Color3.fromRGB(90, 225, 110),
	Color3.fromRGB(60, 205, 245),
	Color3.fromRGB(110, 120, 255),
	Color3.fromRGB(225, 90, 235),
}

-- What an archetype does to its trail
export type Change = {
	Life: number?, -- times its ribbons' life
	Wide: number?, -- times its ribbons' width
	Haze: number?, -- times its haze's size
	Curls: number?, -- no curls under this step
	Front: number?, -- a pressure front from this step
	Jet: number?, -- its bubbles are thrown up this hard, studs a second
	Edge: Color3?, -- its curls' colour
	Twist: number?, -- times its curls' turns
}
FishTrails.Archetypes = {
	Fast = { Life = 1.5, Wide = 0.75 },
	Tank = { Haze = 1.3, Curls = 5 },
	Breaker = { Front = 4 },
	Leaper = { Jet = 14 },
	Predator = { Edge = Color3.fromRGB(255, 120, 110), Wide = 0.8, Twist = 1.3 },
} :: { [string]: Change }

----------------------------------------------------------------------------------------------------------------------
-- What a step costs

-- Particles alive at whole speed, worked out (rate x life), and how many things are drawn
function FishTrails.cost(step: number): (number, number)
	local r = FishTrails.Recipes[step]
	local alive, draws = 0, 1
	local puffs: { Puff? } = { r.Bubbles }
	for _, key in { "Haze", "Roll", "Storm", "Glow", "Rings" } do
		local puff = (r :: any)[key]
		if puff then
			table.insert(puffs, puff)
		end
	end
	for _, puff in puffs :: { any } do
		alive += puff.Rate * puff.Life
		draws += 1
	end
	draws += (if r.Roll then 1 else 0) + (if r.Curl then 2 else 0) + (if r.CurlGlow then 2 else 0) + (if r.Front
		then 2
		else 0)
	return alive, draws
end

return FishTrails
