--!strict
-- How each kind of body moves, beyond its own keyed swim (docs/design/animation-study.md, section 4): nine loose styles,
-- a few numbers each, and which creature has which. A style is a starting row: any creature may be given another, or a
-- row of its own. The client's AnimController plays them (Config.Animation scales each layer, 0 turns it off); all of
-- it is seen only, on the fish's first joint, so the Root, the Saddle and the lock never move.
--   Cadence: the beat's rate against what the length alone gives (a turtle strokes slowly, a darter is quick)
--   Heave: up and down each beat, studs.  Nod: nose up and down each beat, degrees.
--   Sway: the whole body's yaw each beat, degrees.  Rock: its roll each beat, degrees.
--   Dip: how far it sinks under a rider's landing, against the usual
-- First guesses, 2026-11-11, not judged in play.
local RideStyles = {}

export type Style = { Cadence: number, Heave: number, Nod: number, Sway: number, Rock: number, Dip: number }

local function style(cadence: number, heave: number, nod: number, sway: number, rock: number, dip: number): Style
	return { Cadence = cadence, Heave = heave, Nod = nod, Sway = sway, Rock = rock, Dip = dip }
end

RideStyles.Styles = {
	Darter = style(1.0, 0.15, 1, 3, 2, 1.6), -- light, twitchy
	Cruiser = style(0.9, 0.1, 0, 2, 1, 0.8), -- level, heavy head
	Snake = style(1.0, 0, 0, 5, 4, 0.6), -- S-curves, the tail late
	Galloper = style(0.7, 0.9, 4, 0, 0, 0.4), -- a rolling up and down
	Glider = style(0.5, 0.6, 2, 0, 0, 1.0), -- sails
	Paddler = style(0.6, 0.5, 3, 0, 3, 0.7), -- a stroke, then a glide
	Jetter = style(0.45, 0.3, 0, 0, 0, 0.8), -- a pulse and a coast
	Bobber = style(0.9, 0.3, 2, 4, 5, 1.4), -- waddles and wobbles
	Crawler = style(0.8, 0.2, 1, 0, 2, 0.6), -- a level raft, rippling
} :: { [string]: Style }

local MEMBERS: { [string]: { string } } = {
	Darter = {
		"SergeantMajor",
		"Clownfish",
		"BlueChromis",
		"Butterflyfish",
		"YellowTang",
		"Angelfish",
		"Garibaldi",
		"Parrotfish",
		"Lionfish",
		"FlyingFish",
		"Viperfish",
	},
	Cruiser = {
		"ReefShark",
		"LeopardShark",
		"GreatWhite",
		"HammerheadShark",
		"GoblinShark",
		"Sawfish",
		"Swordfish",
		"Barracuda",
		"Helicoprion",
		"HellfinShark",
		"Megalodon",
		"MoltenMegalodon",
		"HalfboneMegalodon",
		"Dunkleosteus",
		"Hellmaw",
		"TheDevourer",
		"Xiphactinus",
		"HumpheadWrasse",
		"GiantSeaBass",
		"GoliathGrouper",
		"Mosasaurus",
		"Dakosaurus",
		"Shonisaurus",
	},
	Snake = {
		"MorayEel",
		"FrilledShark",
		"BrimstoneEel",
		"WraithEel",
		"BobbitWorm",
		"PearlSerpent",
		"StormSerpent",
		"EmberSerpent",
		"CoralDragon",
		"LanternLeviathan",
		"BoneLeviathan",
	},
	Galloper = {
		"Dolphin",
		"Orca",
		"SeaLion",
		"StellersSeaCow",
		"Basilosaurus",
		"Livyatan",
		"BlueWhale",
		"GalleonWhale",
		"PhantomWhale",
		"VoidWhale",
		"KelpWyrm",
	},
	Glider = { "Stingray", "MantaRay", "ElectricRay", "CinderRay", "GraveRay" },
	Paddler = { "SeaTurtle", "Archelon", "GraveTurtle", "Elasmosaurus", "Kronosaurus", "Liopleurodon" },
	Jetter = { "Octopus", "Kraken", "GiantSquid", "Cuttlefish", "AuroraJelly" },
	Bobber = { "Pufferfish", "Boxfish", "Seahorse", "Anglerfish", "InfernalAngler", "SkullAngler", "AbyssalWatcher" },
	Crawler = { "Anomalocaris", "GiantIsopod", "SeaScorpion" },
}

-- The slow wave every creature rides on (the user, 2026-11-11: wavy and rhythmic, not separate moves; tried in the
-- Swim Lab preview). One wave is T seconds for a mid-sized animal. On its rise the stroke widens (Effort) and the beat
-- quickens a little (Beat); the body rises after it (Lift, studs for a 14-stud animal); it drifts to one side over one
-- wave and back over the next (Side, degrees) and leans with it (Lean, degrees). Skew makes the push quicker than
-- the glide (a turtle's stroke, a squid's pulse).
export type Wave = { T: number, Effort: number, Beat: number, Lift: number, Side: number, Lean: number, Skew: number }

local function wave(
	t: number,
	effort: number,
	beat: number,
	lift: number,
	side: number,
	lean: number,
	skew: number
): Wave
	return { T = t, Effort = effort, Beat = beat, Lift = lift, Side = side, Lean = lean, Skew = skew }
end

RideStyles.Waves = {
	Darter = wave(3.2, 0.091, 0.03, 0.375, 2.56, 2.4, 0.2),
	Cruiser = wave(5.0, 0.104, 0.03, 0.5, 2.24, 4, 0.1),
	Snake = wave(4.2, 0.091, 0.03, 0.375, 4.16, 4, 0),
	Galloper = wave(6.0, 0.13, 0.04, 1.38, 0.96, 4, 0.1),
	Glider = wave(7.0, 0.13, 0.05, 1, 1.28, 8, 0.2),
	Paddler = wave(4.5, 0.182, 0.05, 0.625, 0.96, 4, 0.45),
	Jetter = wave(3.6, 0.208, 0.06, 0.5, 0.64, 2.4, 0.6),
	Bobber = wave(4.0, 0.078, 0.02, 0.5, 1.92, 6.4, 0),
	Crawler = wave(5.5, 0.078, 0.02, 0.375, 1.6, 1.6, 0),
} :: { [string]: Wave }

-- What the side fins (flippers, wings, legs) do in a turn, each body type in its own mix. Tilt: they bank further than
-- the body, the inner one down (degrees). Sweep: the inner one swings back and the outer one reaches forward, a moment
-- late (degrees). Row: the outer one strokes wider and the inner one less (a share).
export type Fins = { Tilt: number, Sweep: number, Row: number }

local function fins(tilt: number, sweep: number, row: number): Fins
	return { Tilt = tilt, Sweep = sweep, Row = row }
end

RideStyles.Fins = {
	Darter = fins(3.6, 4.8, 0.15),
	Cruiser = fins(4.8, 2.4, 0.06),
	Snake = fins(1.8, 1.8, 0.06),
	Galloper = fins(4.2, 3.6, 0.09),
	Glider = fins(6, 1.2, 0.18),
	Paddler = fins(2.4, 6, 0.21),
	Jetter = fins(1.8, 3.6, 0.06),
	Bobber = fins(3, 4.8, 0.18),
	Crawler = fins(1.8, 2.4, 0.15),
} :: { [string]: Fins }

-- What a wild animal does when a rider lands on it: its usual reaction, then its second. Config.Animation.LandingMix
-- picks between them (and now and then any of the seven: the user wants a mix of landing types).
RideStyles.Landings = {
	Darter = { "startle", "bolt" },
	Cruiser = { "thrash", "buck" },
	Snake = { "thrash", "barrel" },
	Galloper = { "buck", "shudder" },
	Glider = { "wobble", "bolt" },
	Paddler = { "buck", "wobble" },
	Jetter = { "bolt", "startle" },
	Bobber = { "wobble", "startle" },
	Crawler = { "shudder", "thrash" },
} :: { [string]: { string } }
RideStyles.AllLandings = { "startle", "buck", "thrash", "bolt", "wobble", "shudder", "barrel" }

local byId: { [string]: string } = {}
for name, ids in MEMBERS do
	for _, id in ids do
		byId[id] = name
	end
end

-- The style's name for a creature's Id ("Cruiser" for one not listed)
function RideStyles.nameOf(id: string): string
	return byId[id] or "Cruiser"
end

function RideStyles.waveOf(id: string): Wave
	return RideStyles.Waves[RideStyles.nameOf(id)]
end

function RideStyles.finsOf(id: string): Fins
	return RideStyles.Fins[RideStyles.nameOf(id)]
end

function RideStyles.landingsOf(id: string): { string }
	return RideStyles.Landings[RideStyles.nameOf(id)]
end

function RideStyles.of(id: string): Style
	return RideStyles.Styles[RideStyles.nameOf(id)]
end

-- The trainer on every plot (Hugo, 2026-11-19, task h1: "a real spring on a small red pad; ride it"): the toy Seahorse
-- on a short grey coil, from the middle of its body's underside down to a small round red pad. The server builds it
-- (TrainService) and seats the rider; every machine rocks it, and the rider with it (TrainerController). Kept here,
-- not in Config, so both sides read the same shape. Claude's numbers, 2026-11-19, judged on captures only.
RideStyles.Trainer = {
	-- the spring
	Length = 4.2, -- studs from the pad's top to the body's underside
	Radius = 1.25, -- from the coil's axis to the middle of its wire
	Wire = 0.5, -- the wire's square side: chunky
	Turns = 3.5,
	PerTurn = 12, -- straight pieces a turn
	Colour = Color3.fromRGB(176, 184, 198),
	CapColour = Color3.fromRGB(128, 136, 152), -- the two round plates the coil is fixed to
	-- the pad: just wider than the coil
	PadRadius = 2.05,
	PadHigh = 0.7,
	PadColour = Color3.fromRGB(226, 62, 62),
	-- the rock: nose down and up about the pad, a little dip at each end of the swing
	Beat = 0.95, -- swings (forward and back) a second
	Swing = 11, -- degrees each way
	Dip = 0.22, -- studs the spring gives at each end of a swing
	Ease = 2.2, -- how quickly the rock grows when a rider sits and dies away when they leave (a second)
	-- a hop's landing on it: the spring gives, then bounces back
	Bounce = 0.7, -- studs
	BounceDamp = 5,
	BounceRate = 2.6, -- bounces a second
	-- riding it
	Reach = 5.5, -- studs from the coil's axis (flat) inside which walking up seats you
	OnTop = 3.6, -- a jump that comes down within this of the axis, above the body's underside, seats you anywhere
	Seat = Vector3.new(0, 2.3, -0.9), -- where the rider's root sits: from the body's middle, along its up and forward
	HopOn = 0.42, -- seconds of the hop up onto the seat
	HopArc = 3.2, -- studs the hop rises over the straight line
	OffTime = 0.5, -- seconds of the hop off
	OffReach = 8, -- studs it carries you away (the way you steer, or off the toy's side)
	OffRise = 3.4, -- studs it rises over the straight line
	Every = 0.5, -- seconds between the "+n" Oxygen pops
}

export type TrainerShape = typeof(RideStyles.Trainer)

-- The coil's pieces between a base frame (on the pad's top, its up along the coil) and a top frame (at the body's
-- underside), each a CFrame and a length (along its Z). Bent: the coil's middle follows a curve that leaves the base
-- straight up and meets the top along the top's own up, so a rocking toy bends it rather than tearing it.
export type Piece = { At: CFrame, Length: number }

function RideStyles.coil(base: CFrame, top: CFrame): { Piece }
	local t = RideStyles.Trainer
	local p0, p3 = base.Position, top.Position
	local reach = (p3 - p0).Magnitude / 3
	local p1, p2 = p0 + base.UpVector * reach, p3 - top.UpVector * reach
	local count = math.floor(t.Turns * t.PerTurn + 0.5)
	local points = table.create(count + 1)
	local ups = table.create(count + 1)
	for k = 0, count do
		local s = k / count
		local u = 1 - s
		local middle = p0 * (u * u * u) + p1 * (3 * u * u * s) + p2 * (3 * u * s * s) + p3 * (s * s * s)
		local turn = base:Lerp(top, s).Rotation
		local a = s * t.Turns * math.pi * 2
		points[k + 1] = middle + turn:VectorToWorldSpace(Vector3.new(math.cos(a) * t.Radius, 0, math.sin(a) * t.Radius))
		ups[k + 1] = turn.UpVector
	end
	local pieces: { Piece } = table.create(count)
	for k = 1, count do
		local a, b = points[k], points[k + 1]
		local length = (b - a).Magnitude
		-- (a little longer than the gap, so the outer corners of two pieces meet)
		pieces[k] = { At = CFrame.lookAt((a + b) / 2, b, ups[k]), Length = length + t.Wire * 0.55 }
	end
	return pieces
end

return RideStyles
