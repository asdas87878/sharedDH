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

function RideStyles.of(id: string): Style
	return RideStyles.Styles[RideStyles.nameOf(id)]
end

return RideStyles
