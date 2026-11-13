--!strict
-- Every tuning number for the dive, from docs/design/riding-feel.md (to tune in play). Going fish to fish is Movement
-- v3.1: the hop and glide (the reference's, measured from the user's recordings: docs/reference/ride-a-dino.md) with
-- the lock-on, the window and the spring camera (Jump, Lock, Camera). Going deeper is paid for in Oxygen (ZoneDrain).
-- Speeds in studs a second, times in seconds, angles in degrees.

export type Tier = {
	Idle: number, -- (not used since the herd: a wild fish swims at Herd.SpeedShare of its ridden speed)
	Colour: Color3, -- the tier's colour on markers
}

export type FishType = {
	Id: string,
	Name: string,
	Tier: string,
	Home: number, -- home zone index
	Reach: number, -- how many zones past home it can still turn up in
	Required: number, -- the max Oxygen that keeps up with it in its home land (Config.required): shown on its tag
	IdleSpeed: number,
	RiddenSpeed: number, -- this species, no variant: its own number in Config.FishStats (Config.refresh); one fish's own: Config.speedOf
	Archetype: string, -- its passive archetypes (Config.FishStats): "" for none, more than one comma-separated ("Predator,Breaker")
	Size: Vector3, -- width, height, length (it faces -Z); one fish's own: Config.bodyOf
	Shape: string, -- placeholder body: "Fish" (tall, flat), "Round", "Shark", "Flat" (a ray), "Eel"
	Body: Color3,
	Belly: Color3,
	Fin: Color3,
	Pattern: string?, -- "Stripes", "Bands" or "Tips"
	PatternColour: Color3?,
	PatternCount: number?,
}

local Creatures = require(script.Parent.Creatures)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Config = {}

Config.TierOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Config.Tiers = {
	Common = { Idle = 14, Colour = rgb(200, 200, 200) },
	Uncommon = { Idle = 16, Colour = rgb(90, 220, 90) },
	Rare = { Idle = 18, Colour = rgb(70, 150, 255) },
	Epic = { Idle = 20, Colour = rgb(180, 90, 255) },
	Legendary = { Idle = 22, Colour = rgb(255, 190, 40) },
	Mythic = { Idle = 24, Colour = rgb(255, 70, 90) },
	Secret = { Idle = 26, Colour = rgb(20, 20, 20) },
} :: { [string]: Tier }

-- Speed per fish (Hugo, 2026-11-12, the reset): every fish has ONE speed, set by hand in Config.FishStats below. No
-- rarity formula and no home-land factor (TierMult, SpeciesSpeed, AreaStep and AreaGrow are gone): a deeper or a rarer
-- fish is faster only because its own number says so. The one thing on top is the variant's, the same for every fish.
-- Worked out the same way on the server and on every client (Config.speedOf); the server's is the one that counts
-- (the herd, the speed check). There is no size roll (Hugo, 2026-11-12: "dont do the sizing yet").
Config.Speed = {
	Base = 45, -- studs a second: only for a fish that FishStats doesn't list (it warns), and the fallback with no fish
	Gold = 1.1, -- a Gold fish's speed, times (Hugo, 2026-11-12: "rainbow and gold 1.1x and 1.2x"; read as the rarer
	Rainbow = 1.2, -- Rainbow getting the bigger one. To flip them, swap these two numbers)
}

export type FishStat = {
	Speed: number, -- studs a second, ridden, no variant
	Archetype: string, -- "" for none; more than one comma-separated; the ids are Config.Archetype's keys
}

-- THE per-fish table (Hugo, 2026-11-12): each creature's ridden speed and its passive archetypes, the single source
-- for both. The why of every row, the rules and the numbers: docs/design/archetypes.md (keep its table in step).
-- Commons and Uncommons have no archetype; a Rare may have one; an Epic has one; a Legendary two; a Mythic or a Secret
-- two to four. The server writes a fish's archetypes on its model as the "Archetype" attribute (FishService).
-- stylua: ignore
Config.FishStats = {
	-- land 1: Shallows
	BlueChromis = { Speed = 48, Archetype = "" }, -- Common: a small darting schooling fish: the quick Common, by its number only
	SergeantMajor = { Speed = 46, Archetype = "" }, -- Common: a bold, busy damselfish: the plain first fish
	YellowTang = { Speed = 45, Archetype = "" }, -- Common: a steady reef cruiser
	Butterflyfish = { Speed = 44, Archetype = "" }, -- Common: an ordinary reef fish
	Clownfish = { Speed = 43, Archetype = "" }, -- Common: stays by its anemone, a wobbly swimmer
	Boxfish = { Speed = 40, Archetype = "" }, -- Common: a rigid box paddling with tiny fins
	Pufferfish = { Speed = 40, Archetype = "" }, -- Common: round and slow: the slowest thing in the sea
	FlyingFish = { Speed = 58, Archetype = "" }, -- Uncommon: built to burst out of the water: fast for an Uncommon, by its number only
	Stingray = { Speed = 48, Archetype = "" }, -- Uncommon: glides low over the sand
	Cuttlefish = { Speed = 47, Archetype = "" }, -- Uncommon: hovers on its skirt
	SeaTurtle = { Speed = 44, Archetype = "" }, -- Uncommon: an unhurried glider: slow by its number, no trait
	Seahorse = { Speed = 42, Archetype = "" }, -- Rare: the slowest swimmer there is: the Rare you catch for the tank, not the ride
	ReefShark = { Speed = 70, Archetype = "Predator" }, -- Epic: the Shallows' hunter: the first fish that eats, so the trait is met early
	Archelon = { Speed = 62, Archetype = "Tank,Breaker" }, -- Legendary: a giant turtle: calm to sit on, and its shell goes through anything
	PearlSerpent = { Speed = 100, Archetype = "Fast,Leaper" }, -- Secret: the first Secret: a long quick serpent that throws you far
	-- land 2: Coral Reef
	Parrotfish = { Speed = 50, Archetype = "" }, -- Uncommon: an ordinary grazer
	Angelfish = { Speed = 48, Archetype = "" }, -- Uncommon: tall and showy, not quick
	Lionfish = { Speed = 46, Archetype = "" }, -- Uncommon: drifts with its fins spread
	MorayEel = { Speed = 58, Archetype = "Predator" }, -- Rare: a lunging ambusher with two sets of jaws
	Octopus = { Speed = 54, Archetype = "" }, -- Rare: jets in pulses: a plain Rare
	HumpheadWrasse = { Speed = 60, Archetype = "Breaker" }, -- Epic: it really does crush coral with the bump on its head
	Dunkleosteus = { Speed = 76, Archetype = "Predator,Breaker" }, -- Legendary: armour plate and a bite that sheared through bone
	CoralDragon = { Speed = 108, Archetype = "Breaker,Leaper,Tank" }, -- Secret: a reef come alive: heavy, calm, and it launches you
	-- land 3: Kelp Forest
	SeaLion = { Speed = 58, Archetype = "" }, -- Uncommon: agile and playful: quick for an Uncommon, by its number only
	Garibaldi = { Speed = 52, Archetype = "" }, -- Uncommon: an ordinary kelp fish
	LeopardShark = { Speed = 62, Archetype = "" }, -- Rare: a small harmless shark: a plain Rare
	GiantSeaBass = { Speed = 54, Archetype = "Tank" }, -- Rare: a heavy, slow, gentle giant: the Rare you rest on
	GreatWhite = { Speed = 82, Archetype = "Predator" }, -- Epic: the shark
	StellersSeaCow = { Speed = 56, Archetype = "Tank" }, -- Epic: a gentle floating giant: slow, and the meter barely moves
	Dakosaurus = { Speed = 88, Archetype = "Predator,Fast" }, -- Legendary: a sea crocodile built for the chase
	KelpWyrm = { Speed = 112, Archetype = "Fast,Predator,Leaper" }, -- Secret: winds through the kelp and strikes
	-- land 4: Shipwrecks
	Barracuda = { Speed = 64, Archetype = "" }, -- Uncommon: a torpedo: the fastest Uncommon, by its number only
	HammerheadShark = { Speed = 68, Archetype = "Predator" }, -- Rare: a strong schooling shark
	Sawfish = { Speed = 64, Archetype = "Breaker" }, -- Rare: a saw for a nose
	ElectricRay = { Speed = 62, Archetype = "Tank" }, -- Epic: a sluggish disc that waits: slow and easy on the meter
	GoliathGrouper = { Speed = 60, Archetype = "Predator" }, -- Epic: a heavy lump that gulps fish whole
	Xiphactinus = { Speed = 96, Archetype = "Fast,Predator" }, -- Legendary: the fast "bulldog fish", found with whole fish inside it
	GalleonWhale = { Speed = 104, Archetype = "Breaker,Tank,Leaper" }, -- Secret: a whale carrying a ship: it rams, it lasts, and its back is a launch deck
	-- land 5: Open Blue
	Swordfish = { Speed = 84, Archetype = "Fast" }, -- Rare: one of the fastest fish alive (the small, fast Rare)
	Dolphin = { Speed = 76, Archetype = "Leaper" }, -- Rare: the leaper: small, quick and loved (a trait on a Rare)
	Orca = { Speed = 90, Archetype = "Predator" }, -- Epic: the top hunter: big enough to eat most of what swims by
	MantaRay = { Speed = 78, Archetype = "Leaper" }, -- Epic: a flier: it breaches, and its hop is a long glide
	Helicoprion = { Speed = 92, Archetype = "Predator,Breaker" }, -- Legendary: the buzz-saw shark
	Elasmosaurus = { Speed = 86, Archetype = "Predator,Tank" }, -- Legendary: a long-necked fish catcher, and an unhurried paddler
	BlueWhale = { Speed = 84, Archetype = "Tank,Breaker,Leaper" }, -- Mythic: the biggest and the calmest: nothing stops it, the meter crawls, and it breaches
	StormSerpent = { Speed = 135, Archetype = "Fast,Leaper,Predator" }, -- Secret: lightning
	-- land 6: Twilight
	Viperfish = { Speed = 70, Archetype = "Predator" }, -- Rare: a deep ambusher, all teeth
	GiantSquid = { Speed = 86, Archetype = "Fast" }, -- Epic: jet powered
	GoblinShark = { Speed = 78, Archetype = "Predator" }, -- Epic: its jaws shoot out
	Liopleurodon = { Speed = 98, Archetype = "Predator,Breaker" }, -- Legendary: a big four-flippered hunter
	Shonisaurus = { Speed = 92, Archetype = "Tank,Breaker" }, -- Legendary: a whale-sized ichthyosaur with no teeth: mass, not bite
	LanternLeviathan = { Speed = 108, Archetype = "Fast,Tank,Leaper" }, -- Mythic: a long lit serpent: quick, easy on the meter, a long hop
	AuroraJelly = { Speed = 96, Archetype = "Tank,Leaper" }, -- Secret: a drifting jelly: slow for a Secret, but it floats you far and long
	-- land 7: Midnight
	FrilledShark = { Speed = 82, Archetype = "Predator" }, -- Epic: an eel of a shark that swallows prey whole
	Anglerfish = { Speed = 74, Archetype = "Predator" }, -- Epic: a lure and a mouth
	Mosasaurus = { Speed = 110, Archetype = "Predator,Fast" }, -- Legendary: the star of the deep
	Livyatan = { Speed = 104, Archetype = "Predator,Breaker" }, -- Legendary: the killer sperm whale: a ram for a head
	Basilosaurus = { Speed = 102, Archetype = "Predator,Breaker" }, -- Legendary: a serpent whale that crushed its prey
	Kraken = { Speed = 104, Archetype = "Predator,Breaker,Tank" }, -- Mythic: a mass of arms: it drags fish in and ships down, and it is in no hurry
	VoidWhale = { Speed = 110, Archetype = "Tank,Breaker,Predator" }, -- Secret: a whale, dark and slow, that swallows what it passes
	-- land 8: Vents
	SeaScorpion = { Speed = 84, Archetype = "Predator" }, -- Epic: a paddling hunter with claws
	GiantIsopod = { Speed = 72, Archetype = "Breaker" }, -- Epic: an armoured crawler
	Megalodon = { Speed = 112, Archetype = "Predator,Frenzy" }, -- Legendary: the biggest shark that ever was: every bite makes the next one bigger
	Kronosaurus = { Speed = 108, Archetype = "Predator,Breaker" }, -- Legendary: huge jaws, strong flippers
	Anomalocaris = { Speed = 96, Archetype = "Predator,Leaper" }, -- Legendary: the first big hunter, flying on its side flaps
	BobbitWorm = { Speed = 90, Archetype = "Predator,Breaker" }, -- Legendary: bursts out of the sand (not in the herd yet)
	MoltenMegalodon = { Speed = 122, Archetype = "Predator,Frenzy,Breaker" }, -- Mythic: a Megalodon on fire
	EmberSerpent = { Speed = 138, Archetype = "Fast,Predator,Leaper" }, -- Secret: a serpent of fire
	-- land 9: Bone Graveyard
	WraithEel = { Speed = 114, Archetype = "Fast,Predator" }, -- Legendary: a quick ghost
	GraveRay = { Speed = 104, Archetype = "Leaper,Tank" }, -- Legendary: a ghostly glider
	SkullAngler = { Speed = 98, Archetype = "Predator,Tank" }, -- Legendary: an angler, still: it waits
	GraveTurtle = { Speed = 92, Archetype = "Tank,Breaker" }, -- Legendary: a turtle, still
	BoneLeviathan = { Speed = 126, Archetype = "Fast,Breaker,Leaper" }, -- Mythic: a racing skeleton: nothing to slow it
	HalfboneMegalodon = { Speed = 124, Archetype = "Predator,Frenzy,Tank" }, -- Mythic: half a Megalodon is still a Megalodon, and the dead half needs no air
	PhantomWhale = { Speed = 120, Archetype = "Tank,Breaker,Leaper" }, -- Secret: a ghost whale
	-- land 10: The Underworld
	HellfinShark = { Speed = 118, Archetype = "Predator,Frenzy" }, -- Legendary: a shark from the Underworld
	BrimstoneEel = { Speed = 116, Archetype = "Fast,Predator" }, -- Legendary: an eel of fire
	CinderRay = { Speed = 108, Archetype = "Leaper,Fast" }, -- Legendary: a burning glider
	InfernalAngler = { Speed = 100, Archetype = "Predator,Tank" }, -- Legendary: an angler, still
	Hellmaw = { Speed = 130, Archetype = "Predator,Frenzy,Breaker" }, -- Mythic: the last land's monster
	AbyssalWatcher = { Speed = 112, Archetype = "Tank,Predator,Leaper" }, -- Mythic: it watches; it doesn't hurry
	TheDevourer = { Speed = 150, Archetype = "Predator,Frenzy,Breaker,Fast" }, -- Secret: the end of the list
} :: { [string]: FishStat }

-- The passive archetypes (Hugo, 2026-11-12; docs/design/archetypes.md). All passive: no button, they just happen
-- while you ride. None takes away steering or the hop. Built 2026-11-12: the server decides the eat, the prop reward,
-- the drain and the hop's longer window (RideService); the rider's client plays the speed (RideController), the hop
-- (JumpController) and the feedback (ArchetypeController, Config.ArchetypeFeel). Each id's table is also reachable as
-- Config.<Id> (Config.Predator, ...), which is how the sandbox's panel names its rows.
Config.Archetype = {
	-- Fast: its speed is its own high number in FishStats. On top, the burst on landing (Ride.Surge, SurgeTime) is
	-- bigger and lasts longer, so hopping onto one feels like a launch.
	Fast = {
		-- (On a landing every fish first dips to Ride.StartleSlow. A plain fish then eases back to its speed and no
		-- further; a Fast one goes on past it to this burst as it recovers, and settles over SurgeTime: the launch.)
		Surge = 1.15, -- Ride.Surge, times (1.25 becomes about 1.44)
		SurgeTime = 2, -- Ride.SurgeTime, times (0.5 s becomes 1 s)
	},
	-- Predator: swimming into a smaller wild fish eats it. The fish is gone in a burst of bubbles (the herd's top-up
	-- puts a new one in within seconds, away from players); the rider gets a short burst of speed and some Oxygen.
	-- Never a fish with a rider, never one a player's hop is reserved on, never while the rider is in the air.
	Predator = {
		Prey = 0.7, -- eats a wild fish no longer than this share of its own length
		Reach = 3, -- studs past the predator's nose and half width that count as a bite
		Burst = 1.25, -- its speed, times, after an eat,
		BurstTime = 1.5, -- for this many seconds (it fades out over the last third)
		Oxygen = 0.1, -- of max Oxygen back per eat
		Cooldown = 2.5, -- seconds between two eats, so a predator can't clear the lane of fish to hop to
	},
	-- Frenzy (always with Predator): eats chain. Each eat inside the window adds a stack; the stacks make the burst
	-- bigger and longer, and the cooldown is shorter.
	Frenzy = {
		Window = 6, -- seconds after an eat in which the next one adds a stack
		Stacks = 3, -- at most
		BurstPer = 0.08, -- added to Predator.Burst per stack (three stacks: x1.49)
		TimePer = 0.5, -- seconds added to Predator.BurstTime per stack
		Cooldown = 1.2, -- in place of Predator.Cooldown
	},
	-- Breaker: goes through props for free (no speed lost, no Oxygen: Props.Slow and Props.Cost don't apply), knocks
	-- a wider hole, and each prop broken gives a short push and a little Oxygen.
	Breaker = {
		Reach = 5, -- added to Props.Reach
		Burst = 1.12, -- its speed, times, after breaking a prop,
		BurstTime = 1, -- for this many seconds
		Oxygen = 0.04, -- of max Oxygen back per prop
		Cooldown = 1.5, -- seconds between two rewards (the breaking itself has none)
		Crash = 0.5, -- a crash into a wall costs it this share of the usual speed and Oxygen loss (Crash.Slow, Crash.Cost)
	},
	-- Tank: the calm one. Oxygen drains slower on it, and it never gets angry as early.
	Tank = {
		Drain = 0.65, -- its Oxygen drain, times
		AngryAt = 0.6, -- Oxygen.AngryAt, times (the red part starts at 0.18 of the meter, not 0.3)
	},
	-- Leaper: the hop off it goes higher and further.
	Leaper = {
		Apex = 1.3, -- Jump.Apex, times
		Air = 1.2, -- the glide's speed (Jump.AirShare of this fish's speed), times
		FloatTime = 0.3, -- seconds added to Jump.FloatTime (and to the window, so the drop is as long as it was)
	},
}

for id, numbers in Config.Archetype :: { [string]: any } do
	(Config :: any)[id] = numbers
end

-- What an archetype's moment looks, sounds and feels like (Hugo, 2026-11-12: "make sure it feels good"). All made of
-- what the game already has: the view's kick wider (State.FovPunch), the camera's jolt and shake, speed lines, bubble
-- bursts, the built-in sounds, a word that pops up by the rider, and a line on a fish's tag naming its archetypes.
-- Client only (ArchetypeController, RideController, JumpController); nothing here changes what the server decides.
Config.ArchetypeFeel = {
	-- THE STAND-IN MOTION for a bite and a smash (1 on, 0 off, between: that share): a quick lunge of the nose on a
	-- bite, a shudder on a smash, on the fish's turn spring like Angry.Motion. Set to 0 when the partner's animations
	-- play instead (they hang on the fish's "Bite", "Smash" and "Frenzy" attributes: archetypes.md, Animation hooks).
	Motion = 1,
	Lunge = 9, -- degrees the nose dips and comes back on a bite,
	LungeTime = 0.32, -- over this long
	Shudder = 6, -- degrees it rolls side to side on a smash (three times, dying away),
	ShudderTime = 0.35, -- over this long
	BoostIn = 0.1, -- seconds a burst of speed (an eat's, a smash's) takes to come in: a shove, not a snap
	BoostLines = 0.75, -- speed lines through a burst, 0 to 1 (0 off)
	-- the bite
	EatFov = 6, -- the view kicks this much wider,
	EatKick = 0.3, -- the camera is knocked down this many studs,
	EatBubbles = 28, -- bubbles where the fish was,
	EatReach = 6, -- flying out this far, studs
	EatSound = 0.9, -- how loud the chomp is (0 off)
	FrenzyFov = 2, -- and this much more view for each stack of a Frenzy
	-- the smash (a Breaker's rewarded prop)
	SmashFov = 4,
	SmashShake = 0.7, -- the camera is thrown about this far, studs (the landing's shake, smaller)
	SmashBubbles = 20,
	SmashReach = 8,
	SmashSound = 0.7,
	-- the launch (landing on a Fast fish)
	LaunchFov = 6, -- on top of Feel.BoltFov
	LaunchLines = 1, -- speed lines through the launch
	-- the big hop (off a Leaper)
	LeapFov = 5, -- on top of Feel.PopFov
	LeapBubbles = 16, -- on top of Feel.PopBurst
	-- the word by the rider ("CHOMP!", "SMASH!", "FRENZY x2", "LAUNCH!", "BIG HOP!")
	Words = 1, -- 0: no words
	WordTime = 0.9, -- seconds a word stays
	WordRise = 34, -- and how far it floats up, pixels
	-- the archetypes on a fish's tag and under the ring of the fish you ride
	Tags = 1, -- 0: tags don't name the archetypes
}

-- Variants (Hugo, 2026-11-12): the chance that a spawned fish is one, 0 to 1 (Rainbow is rolled first). The fish's
-- "Variant" attribute ("", "Gold" or "Rainbow"); the look is Shared/Variants; the speed is Speed.Gold and Speed.Rainbow
-- (x1.1 and x1.2, flat for every fish).
Config.Variant = {
	Gold = 0.03,
	Rainbow = 0.008,
}

-- Oxygen is the riding meter, and it is what the design notes call stamina (Decisions, 2026-11-09 and 2026-11-11).
Config.Oxygen = {
	StartMax = 100, -- max Oxygen before any training
	FreeDrain = 4, -- a second while floating off a fish (not in a hop); our guess, so it can't last forever
	FloatSpeed = 6, -- rising while off a fish
	SwimSpeed = 8, -- floating off a fish you drift forward at this, and A and D turn you (never W and S)
	SurfaceY = -3, -- floating stops here
	WaterY = -4, -- below this, a player on the dock counts as in the water
	-- The unit is seconds on a fish (the user, 2026-11-11): your max Oxygen / the fish's drain (Config.drain). A new
	-- player has 2.5 s on a Shallows Common, so you have to go fish to fish.
	Refill = 1, -- of max Oxygen, on landing a hop on another fish. 1: every fish starts with the whole meter, as the reference's ring is the time left on this dino (0.25 until 2026-11-11)
	-- What the HUD and a fish's tag show as needed (Config.required): drain x KeepUp / Refill. With Refill 1 that is
	-- the max Oxygen that gives KeepUp seconds on the fish.
	KeepUp = 2, -- seconds on a fish that count as enough (6 until 2026-11-11, when it was the seconds between landings)
	-- A fish too strong for you (the user, 2026-11-12): a landing is never refused. A fish that needs more than your
	-- max Oxygen (Config.required, where you land on it) empties the whole meter in this many seconds, whatever the
	-- fish, and then throws you off. Shorter than Jump.Cooldown, so it can't be hopped off in time: the number on a
	-- fish's tag is a real bar. 0: off (the fish's own drain, as before).
	StrainTime = 0.25,
	-- The low, red part of the meter (Hugo, 2026-11-12: "when the bar turns red"): this share of your max Oxygen and
	-- under. One number for both sides: the ring turns red here (HudController, Rings) and the fish under you turns
	-- angry here (Config.Angry, RideService). 0.3 of a new player's 2.5 s on a Shallows Common is the last 0.75 s;
	-- of a trained 10 s, the last 3.
	AngryAt = 0.3,
	DockRadius = 165, -- staying surfaced this close (flat) to the dock's spawn puts you back on it (grey-box 15: the spawn is 144 behind the lane's start and the gate's corners are 161 away, so this is the hub, the gate and the first 21 studs of water in the middle; it was 60 studs of water on grey-box 9; grey-box 4 had 120, v4 520)
	DockWait = 2.5, -- seconds at the surface first, so diving in leaves time to hop
	-- Studio only: when above 0, everyone's max Oxygen, to try the deeper zones before training exists. Workspace's
	-- "TestMaxOxygen" attribute overrides it live (0 turns it off).
	StudioMax = 0,
}

-- The progression (Hugo, 2026-11-11): the deeper you are, the more Oxygen the fish under you takes a second. One number
-- a land, for a Common, by the land you are IN (not the fish's home); steep, so each land needs a clearly bigger max
-- Oxygen than the last. A hop is never refused for Oxygen and costs none: at almost nothing you can still go fish to
-- fish, and each landing gives Refill back.
-- The numbers (the tuning chat, 2026-11-11, from the user's "2 to 3 seconds on the first fish, the land is the main
-- cost"; docs/design/progression.md): the starting 100 lasts 2.5 s on a Shallows Common, and each land takes 2.5 to
-- 4 times the land before. The smaller steps (lands 3, 5 and 7) are where the land's commonest fish also goes up a
-- rarity, so what it takes to be at home in a land grows 4 to 8 times a land. Until then: 1, 4, 14, 48, 160, 500,
-- 1500, 4500, 13000, 36000.
Config.ZoneDrain = { 40, 160, 480, 2000, 6000, 24000, 60000, 240000, 1000000, 4000000 }

-- And by the rarity of the fish under you: how many times a Common's Oxygen it takes a second, in any land. One number
-- a rarity, so the curve can be gentle at the bottom and steep toward Legendary and Mythic (the user, 2026-11-11: the
-- land is the main cost, the rarity less so, but hard at the top). Until 2026-11-11 this was a straight line, 0.15 a
-- step (Oxygen.TierDrain: 1, 1.15, 1.3, 1.45, 1.6, 1.75, 1.9).
-- The numbers (the tuning chat, 2026-11-11; docs/design/progression.md): a new player's 2.5 s on a Shallows Common is
-- 2 s on an Uncommon, 1 s on a Rare, half a second on an Epic and next to nothing on a Legendary. Rare to Legendary
-- follow the reference's required stamina in one zone (an Uncommon 50, a Rare 130, an Epic 230, a Legendary 752);
-- Mythic and Secret are guesses.
Config.RarityDrain = {
	Common = 1,
	Uncommon = 1.25,
	Rare = 2.5,
	Epic = 4.5,
	Legendary = 15,
	Mythic = 50,
	Secret = 150,
} :: { [string]: number }

-- Training: the smallest thing that lets the progression be played (the tuning chat's proposal, docs/design/
-- progression.md, "Not built yet"). Standing on the training spot in the hub adds to your max Oxygen every second. Kept
-- for the session only: there are no saves yet. The spot is the map's part named TrainSpot when it has one; until then
-- the server makes a stand-in pad beside the dock's spawn (Right and Ahead of it, in studs, the way the spawn faces).
Config.Train = {
	On = 1, -- 0: no training spot
	Rate = 4, -- max Oxygen a second while you stand on it (the tuning chat's number: the Coral Reef in two minutes)
	-- and this share of your max Oxygen a second on top (the tuning chat, 2026-11-12): each land costs 4 to 8 times the
	-- last, so a steady rate alone stops being useful at the Shipwrecks (the Open Blue after 5 hours of standing). At
	-- 0.004: the Kelp Forest after about 5 minutes, the Open Blue after 17, the last land after 49.
	Share = 0.004,
	Radius = 10, -- studs from the spot's middle that count as on it
	Right = 70, -- the stand-in pad: this far to the right of the dock's spawn,
	Ahead = 24, -- and this far toward the water
}

-- Taming (the dive, decided 2026-11-09: stay on a wild fish long enough and it is yours). Riding a fish you can hold
-- fills its tame; full, it joins what you carry on this dive, and at the dock the dive's catch is added to what you
-- own. Kept for the session only: there are no saves, no tank and no income yet. A fish too strong for you
-- (Oxygen.StrainTime) is never tamed.
Config.Tame = {
	On = 1, -- 0: no taming (the HUD's tame ring, banner and slots stay hidden)
	-- seconds on a fish to make it yours. The tuning chat's proposal (docs/design/progression.md): the 2 seconds the
	-- game already calls enough (Oxygen.KeepUp), so the number on a fish's tag is exactly the Oxygen that tames it.
	Time = 2,
	Carry = 7, -- the most you carry on one dive (the reference's seven slots); a tame past that is not kept
}

-- Angry mode (Hugo, 2026-11-12: "make the fishes pulse red and go into angry mode ... different fishes should have
-- different slowdowns ... when the bar turns red"; the reference's T-rex starts jumping and its bison rocks back and
-- forth: each animal shows in its own way that it wants you off). While you ride with the meter in its red part
-- (Oxygen.AngryAt), or on a fish too strong for you from the touch, the fish under you is angry: it pulses red, for
-- everyone, faster as the Oxygen runs out, and it slows in its body type's own way (Shared/AngryStyles: the shapes
-- and their numbers). The server decides it (RideService: the fish's "Angry" and "AngryStyle" attributes); the
-- slow-down is the ridden speed's own curve (RideController), like the landing's. Steering is untouched and a hop
-- off always works. No authored animation: where a style wants motion it is a sine on the fish's nose, turn and
-- roll (Motion), a stand-in until the partner's animations take its place (they can read "AngryStyle").
Config.Angry = {
	On = 1, -- 0: no angry mode (the ring still turns red at Oxygen.AngryAt)
	-- A fish you have tamed on this dive: 1, it gets angry like any other (taming doesn't change the riding: the
	-- user, 2026-11-10; and it still throws you off at zero); 0, a fish that is yours stays calm.
	Tamed = 1,
	EaseIn = 0.5, -- seconds the slow-down takes to come in,
	EaseOut = 0.4, -- and to go if the Oxygen comes back while you ride
	Floor = 0.3, -- no style, rarity or heat ever slows a fish under this share of its speed: it never stops
	-- How much of a style's slow-down there is where the meter turns red; it is whole when the meter is empty.
	HeatFrom = 0.75,
	GiantLength = 40, -- a fish at least this long (studs) is a giant: the slow heavy fade, whatever its body type
	-- The stand-in motion: 1, each style's small rock, nod or wag (a sine, on the fish's turn spring); 0, none (for
	-- when authored animations play instead); between, that share of it.
	Motion = 1,
	-- The red pulse (a Highlight over the whole fish, so its own colours, a Gold's and a Rainbow's are never touched)
	PulseSlow = 1.2, -- pulses a second where the meter turns red,
	PulseFast = 4, -- and when it is empty (and on a fish too strong)
	PulseLow = 0.12, -- how red it is between pulses, 0 to 1,
	PulseHigh = 0.62, -- and at a pulse's top
	PulseEdge = 0.5, -- the red line round it at a pulse's top, 0 to 1 (0: no line)
	PulseFade = 0.3, -- seconds the red takes to come and go
	Colour = rgb(255, 38, 38),
	Tag = "AngryFish", -- the CollectionService tag an angry fish carries (how the clients find it)
	-- Studio only, for judging the styles with the sandbox's endless air on: above 0, every fish you ride is angry,
	-- as if the meter were this far through its red part (0.01: just turned red; 1: empty).
	Test = 0,
}

-- A rarer fish slows harder: its style's loss of speed is times this (never under Angry.Floor)
Config.AngryTier = {
	Common = 1,
	Uncommon = 1.04,
	Rare = 1.08,
	Epic = 1.12,
	Legendary = 1.18,
	Mythic = 1.24,
	Secret = 1.3,
}

-- On foot in the hub. The reference's players run at about 28 studs a second there (one measurement off its frames, good
-- to about a fifth; Roblox's own speed is 16), which is why its walk to the start is short. The user, 2026-11-10: match it.
Config.Dock = {
	WalkSpeed = 28,
}

Config.Ride = {
	RampTime = 1.2, -- idle to ridden speed, easing out
	Surge = 1.25, -- the burst on mount
	SurgeTime = 0.5,
	SlowDownTime = 2, -- back to idle once nobody rides it
	-- You always go forward. The way you go follows the camera (the user, 2026-11-11, after playing Movement v3.1: "when
	-- you move the camera the movement should follow, alongside A and D; that's what makes the reference feel better"):
	-- A and D turn the camera, a drag, a stick or the mouse in the hop turn it too, and the fish, the hop and the float
	-- come round to it. CameraSteer 0 is Movement v3.1's way: only A and D steer, and the view is free of the heading.
	CameraSteer = 1,
	-- The control pass (Hugo, 2026-11-12: "the left right is kinda too slow and clunky, it should be smooth but you
	-- should be able to turn faster and you should be able to steer better"). What made it clunky was three lags one
	-- after the other: the key's own ease, then the way you go chasing the view the key had turned (it trailed a held
	-- turn by 16 degrees and went on turning that far after the key was let go), then the fish's own turn spring. Now
	-- A and D turn the way you go directly, and the view by as much; only a look (a drag, a stick, the mouse in the
	-- hop) is chased. The same in the hop and floating (RideController.steer). Measured by script in Studio, before
	-- and after: A held for a second turns you 129 degrees (was 73); the first 10 degrees take 0.12 s (was 0.30); let
	-- go, you turn 9 degrees more (was 23).
	SteerEase = 12, -- how quickly the way you go comes round to a look (higher is snappier; 6 until 2026-11-12)
	SteerRate = 220, -- and never faster than this, degrees a second (140 until 2026-11-12)
	YawRate = 135, -- A and D turn you (and the view) at this rate at full press, degrees a second (95 until 2026-11-12)
	TurnEase = 14, -- how quickly a turn comes in and stops (higher is snappier; 10 until 2026-11-12)
	Response = 45, -- how tightly the fish's body follows the way you steer it (its turn spring; 14, the herd's, until 2026-11-12). The limits on its torque and turning speed (Lib/FishModel) are untouched
	LandSteerTime = 0.3, -- after a landing the fish comes round to your look gently: the pull of the view eases in over this long (A and D are at full at once); 0: at once
	MaxPitch = 55, -- the steepest the fish noses up or down by itself to follow the lane
	BankEase = 5, -- response rate for the bank on a fish and in the hop
	Bank = 28, -- roll into turns
	SeatHeight = 1.4, -- the rider's root above the fish's back
	FloorClearance = 3, -- the fish pulls up nearer the floor than this
	Ceiling = 4, -- and stays this far under the surface line
	LaneMargin = -3, -- a ridden fish and a flight stay this far inside the lane's edge (negative: inside). It was 20 past it, but since grey-box 6 the walls are a 1-stud face with a hollow behind, and 20 past the edge is inside that hollow
	SpeedSlack = 1.6, -- the server flags a ridden fish moving faster than its own surge speed (Config.speedOf x Surge) times this
	-- The landing's slow-down (Hugo, 2026-11-12; it came with a rearing "startle", whose look was taken out the same
	-- day on the user's word: every landing plays Animation.LandingMix's reactions again). A fish you land on never
	-- stops: it drops to StartleSlow of its speed for StartleHold seconds, then eases back to full over
	-- StartleRecover. It is the ridden speed's own curve (RideController), never a push: the limits on a fish's force
	-- and torque (Lib/FishModel, 2026-11-12) stay. Only a landing does it, not the sandbox's reset.
	Startle = 1, -- 1: a landing slows the fish for a moment; 0: the old mount (Surge at once)
	StartleBrake = 0.12, -- it comes down to StartleSlow over this long at the touch
	-- (Hugo, 2026-11-12, later: "the startle is too strong make it just slow down by like 0.8x". A wild fish swims at
	-- 0.85 of its speed, so at 0.8 the landing is a short soft dip: 0.9 s in all, was 1.2.)
	StartleSlow = 0.8, -- its speed for that moment, as a share of its ridden speed (0.6 until 2026-11-12)
	StartleHold = 0.3, -- seconds it stays that slow (0.4 until 2026-11-12)
	StartleRecover = 0.6, -- then it eases back to its ridden speed over this long (0.8 until 2026-11-12)
}

-- Going fish to fish, Movement v3.1 (2026-11-11; docs/design/riding-feel.md). The hop is the reference's, as built on
-- 2026-11-10: Space throws you off the fish, up and forward, faster than you rode (the pop); then you glide, flat at
-- the top, swimming at about the herd's pace; then you drop, slowing a little and sinking faster and faster. You always
-- go forward and A and D steer. The whole hop is the window: Window seconds to grab the next fish. The lock-on
-- (Config.Lock) holds the fish you are looking at, which glows; Space, a click or E pulls you onto it (the pull-in).
-- With the window gone and no fish grabbed you have sunk: the short drown.
Config.Jump = {
	-- The window is the hop: the pop, the glide and the drop together. The same at every depth (Hugo, 2026-11-11):
	-- going deeper is paid for in Oxygen (Config.ZoneDrain), never in a shorter window.
	-- (Hugo, 2026-11-12: "more airtime (just a little)". The glide is 0.2 s longer, FloatTime below, and the window
	-- grew by the same, so the drop is as long as it was. Still one window for every land.)
	Window = 3.2, -- seconds from leaving the fish in which to grab the next one (3.0 until 2026-11-12)
	Warn = 0.8, -- the HUD's timer turns red and pulses for this last part
	-- (the user, 2026-11-11: the reference feels more automatic; match its hop one to one. There the pull-in starts by
	-- itself about 1.7 s after the press, and a second press only brings it sooner.)
	AutoGrab = 2, -- 2: the locked fish pulls you in by itself when the glide ends, or as soon as one is locked in the drop (the reference); 1: only at the window's end; 0: never, you must press (Movement v3.1)
	MinFlight = 0.15, -- before a second press counts as a grab (so one press can't do both)
	Cooldown = 0.3, -- after landing, before the next hop
	InputGap = 0.2, -- seconds between JumpRequest repeats that count as a new press
	-- The shape, from the user's side-on recording (2026-11-10): a quick pop up (about 0.3 s), then a long flat glide
	-- lying face down, sinking hardly at all.
	LaunchTime = 0.4, -- the pop up (0.3 in the reference, whose pop is half as high)
	BoostTime = 0.75, -- the pop's extra speed lasts this long (the reference: about 0.75 s)
	Launch = 1.6, -- times the speed you left the fish at (the reference: about 1.3 to 1.8; 1.4 until 2026-11-11)
	-- The hop-off boost (Hugo, 2026-11-12): leaving a fish gives you extra speed on top of the speed the fish had
	-- THEN (a slowed fish, startled, angry or just off a wall, gives less), and it falls off semi-quickly to the
	-- glide's pace: the pop's speed is Launch x the fish's speed + HopBoost, held for BoostHold, gone by BoostTime.
	HopBoost = 18, -- studs a second on top of Launch x the fish's speed
	BoostHold = 0.12, -- the whole boost lasts this long, then it falls off, back at the glide's pace by BoostTime
	BoostFloor = 10, -- the pop is never less than this much faster than the glide (off a slowed fish there is still a kick)
	-- Airtime by speed (Hugo, 2026-11-12: "the less speed, the less airtime"): the glide, and the window with it, are
	-- longer off a fast fish and shorter off a slow or slowed one, by the speed the fish had as you left
	-- (Config.airOf; the server counts the same). Fair at the slow end: the glide is never under AirLeast, the lock's
	-- reach (GrabRange) is the same, and the pull-in still starts by itself when the glide ends. From floating: 0.
	AirSlowSpeed = 20, -- a fish this slow or slower as you leave it: AirSlow seconds on the glide
	AirFastSpeed = 130, -- one this fast or faster: AirFast. In between, in proportion (no change at 75 studs a second)
	AirSlow = -0.5, -- seconds on Jump.FloatTime (and the window) off the slowest fish
	AirFast = 0.5, -- and off the fastest
	AirLeast = 0.6, -- the glide is never shorter than this, whatever the numbers above
	FreeLaunch = 78, -- the pop's speed from floating, with no fish under you (55 until 2026-11-11)
	-- The height (2026-11-10, the user: the reference has flat ground, we don't): the hop rises this far above where
	-- you left, or above the locked fish if that is higher, so there is always a swoop down onto the fish. It never
	-- leaves the water; where the water is too shallow for it the herd swims lower (Config.herdTop).
	Apex = 20,
	Ceiling = 3, -- the hop stays this far under the surface line (Oxygen.SurfaceY)
	SeatRoom = 5, -- a rider sits about this far above the middle of a fish: the hop's rise is counted from the seat
	FloatTime = 1.5, -- the glide at the top, swimming. With LaunchTime it ends 1.9 s after the press, when the pull-in begins by itself: 12% more air than the reference's 1.7 s (1.3 until 2026-11-12, Hugo: a little more airtime)
	FloatRise = 1, -- still rising this much through the glide
	-- (Hugo, 2026-11-11, after playing: the air was too slow. The glide was 38, the herd's pace, and the drop 30.)
	AirSpeed = 54, -- the glide's speed with AirShare 0: well past the herd's pace (38), so a hop gains on the fish ahead
	-- (the user, later the same day: match the reference. Measured there, the rider floats at 0.85 of the speed they
	-- rode at, keeping pace with the herd, so they hang over the fish ahead instead of flying past it.)
	AirShare = 0.85, -- the glide's speed as a share of the ridden speed of the fish you left; 0: AirSpeed, whatever the fish
	FreeAirSpeed = 38, -- and from floating, with no fish left behind (a Common's herd pace)
	-- The drop is the rest of the window (Window - LaunchTime - FloatTime: 1.3 s). It is still swimming, not a fall:
	-- you slow a little and sink, slowly at first.
	DropTime = 0, -- (worked out in Config.refresh)
	Drop = 12, -- by the window's end you are this far below where you left
	DropCurve = 2, -- how the sinking comes in: 1 is steady, 2 starts slow and ends fast, 3 hangs longer still
	DropSpeed = 42, -- the forward speed you have slowed to by the window's end (from AirSpeed)
	Tilt = 78, -- the body lies forward this much through the glide, face down, swimming
	TiltFrom = 0.2, -- it starts to tip at this share of LaunchTime (upright off the fish for a moment)
	TiltTo = 1.2, -- and is flat by this share of it
	DropTilt = 12, -- and noses down this much more in the drop
	DropTiltTime = 0.4, -- over this long
	Bank = 18, -- the body rolls into turns
	FloorClearance = 4, -- the hop stays this far above the sea floor and rocks
	-- The pull-in onto the fish, measured off the reference's distance counter frame by frame (two pull-ins): it takes
	-- 0.33 s over 15 m and 0.47 s over 22 m; it creeps for the first 40% of that time, then accelerates all the way in.
	-- Normalized time is eased (Ease.inOutSine) and raised to ReelCurve, so the moving saddle is met with no snap.
	ReelTime = 0.14, -- the pull-in's time for no distance at all; GrabSpeed adds to it by the distance
	GrabSpeed = 95, -- the pull-in takes this much longer for the distance (studs a second; the reference: about 46 m; 55 until 2026-11-11: snappier)
	ReelMin = 0.05, -- the shortest pull-in, even with the fish beside you
	ReelMax = 0.7, -- the pull-in never takes longer than this, however far the fish
	ReelCurve = 2.3, -- the reference's two pull-ins fit about 1.5 and 2.5; higher creeps longer and arrives faster
	ReelSwoop = 0.9, -- the pull-in comes down later than it comes across (added to ReelCurve for the height): a swoop
	ReelTip = 80, -- the body pitches head first toward the fish, degrees
	ReelTurnEnd = 0.25, -- the share of the pull-in by which the body faces the fish
	ReelSitStart = 0.8, -- the share of the pull-in from which the body settles onto the saddle
	-- The camera through a landing, measured between every pair of frames of the side-on recording (four landings):
	-- the picture grows through the pull-in, then in ONE frame shrinks to 0.79 to 0.81 of its size (the view snaps
	-- wider), and comes back over 0.3 to 0.4 s; with it a short up-and-down jolt of 10 to 17 pixels in 720, gone in
	-- about 0.13 s.
	ReelFov = -10, -- the view narrows by this much as the pull-in speeds up (the zoom in)
	ReelFovCurve = 1.5, -- how that narrowing comes in over the pull-in
	LandFov = 12, -- then snaps this much wider than usual at the landing (0.8 of the picture's size at a 70 degree view)
	LandFovTime = 0.35, -- and settles back over this
	LandKick = 0.45, -- the jolt: the camera is knocked down this many studs
	LandKickRate = 12, -- and springs back, bouncing this many times a second
	LandKickDamp = 0.35, -- dying away (0 never, 1 with no bounce)
	-- The shake as you land on the fish (Hugo, 2026-11-11: a short noticeable shake, not just the dip above). The view
	-- is thrown about, sideways, up and down and a little round its own line, and it dies away over LandShakeTime. A
	-- faster pull-in (a further fish) shakes a little harder.
	LandShake = 0.9, -- how far the camera is thrown, studs, landing at LandShakeAt (0 turns the shake off)
	LandShakeTime = 0.38, -- seconds until it has died away
	LandShakeRate = 16, -- how many times a second it is thrown back and forth
	LandShakeRoll = 2.2, -- and the view rolls this many degrees with it
	LandShakeAt = 80, -- the pull-in's speed (its distance over its time) that gives exactly LandShake
	LandShakeBySpeed = 0.4, -- how much the speed counts: 0 not at all; 0.4 is 1.3 times the shake at 140 st/s, 0.8 at 40
	GrabRange = 180, -- the hard max reach, rider to fish: no lock and no grab beyond it (the server checks it, with Net.RangeSlack for lag). 130 until 2026-11-12 (Hugo: a longer hook)
	AckTime = 1, -- seconds to wait for the server's word on a landing before going back to the hop
	RefusedTime = 0.6, -- a fish the server refused, or that was lost, can't be locked again for this long
	-- The second hook (Hugo, 2026-11-12: "sometimes when you jump onto a fish you are instantly hooked onto ANOTHER
	-- fish"; the cause and the measurements are in docs/design/riding-feel.md, "The second hook").
	RehookGuard = 0.45, -- after a pull-in that was refused or lost, the hands-off pull-in (AutoGrab) waits this long before it may take another fish; a press still grabs at once
	LandWait = 0.5, -- the server gives a landing this long to be seen arriving at the fish before it refuses it (it sees the rider a moment late, most of all after a fast pull-in)
	HopGuard = 0.25, -- Space pressed again DURING a pull-in starts a run of presses that can't hop you off the fish you land on; the run ends at the first gap this long between presses. A hop made on purpose (no press in the pull-in) is untouched. 0: off
	MashMost = 1.5, -- and such a run never holds the hop back longer than this after the landing
	Slack = 0.6, -- the server waits this long past the window and the pull-in for the landing (lag)
	LandSlack = 20, -- allows the landing this many studs wider; never widens GrabRange (it sees the player a moment late)
	-- (Hugo, 2026-11-11: the camera felt forced. The view is no longer tilted for you in the hop: it stays where you
	-- have it. Camera.AirRest 1 gives the tilt to CameraPitch back, for as long as you don't move the view.)
	CameraPitch = -30, -- with Camera.AirRest on: where the view rests in the hop, looking down on the herd
	CameraZoom = 1.2, -- how far back the camera sits in the hop, times the riding distance
	TrailDots = 18, -- yellow dots left along the pull-in (made once at the start: not on the sandbox panel)
	TrailEvery = 0.025, -- seconds between them
	TrailLife = 0.4, -- seconds before one has faded
	Glow = rgb(255, 221, 51), -- the ring round the locked fish
	-- the dots of the pull-in: a deeper yellow with no blue in it, so the bloom of the new lighting (Config.Look) leaves
	-- them yellow (in the ring's colour they bloomed to white blobs)
	DotGlow = rgb(255, 185, 0),
	-- The locked fish itself, as the reference marks its dino (the user's recording of 2026-11-10, 22.9 to 23.7 s): the
	-- whole animal one flat, nearly solid yellow-orange, with a thin black outline (ours was a faint yellow wash with a
	-- pale yellow outline until 2026-11-12).
	GlowFill = rgb(247, 190, 62),
	GlowOutline = rgb(0, 0, 0),
	-- The partner's dashed yellow ring (2026-11-10: it lay flat in the water under you, 20 studs in radius) is back as
	-- the mark on the locked fish (Hugo, 2026-11-11): the same dashes, flat in the water round the fish, a quarter
	-- smaller. It is the main mark; the fish's own glow stays, fainter.
	RingRadius = 15, -- studs (the partner's was 20)
	RingGrow = 40, -- further than this from the camera the dashes are drawn thicker, by the distance, so a far ring still shows (60 until the range went to 180)
	RingFar = 1.5, -- and the ring itself is this many times wider round a fish at the full range (growing with the distance from RingGrow on)
	RingFarFace = 0.8, -- RingFace for a fish at the full range: a far ring is turned nearly square on to the camera, or it is seen edge on
	RingFollow = 14, -- how quickly the ring goes from one locked fish to the next (higher is quicker)
	RingSpin = 25, -- the dashes go round, degrees a second (0: still, as the partner's)
	RingFace = 0.35, -- 0: flat in the water, as the partner's; 1: turned to face the camera; between: tipped that much toward it, so a far fish's ring isn't seen edge on
	RingPreview = 0.55, -- how see-through the ring is while you are still on a fish or floating (solid once you have left)
	FlyGlow = 0.12, -- how see-through the fish's own glow is in the hop (0.6 until 2026-11-12; the reference's is nearly solid)
	PreviewGlow = 0.85, -- and while you are still on a fish
	GlowFade = 0.3, -- the glow leaves the fish over this after the landing
	FlightTime = 0, -- the longest a hop and its pull-in can last, for the server (worked out in Config.refresh)
}

-- The lock-on. The aim is a thick ray along where the camera looks. Each free fish within Jump.GrabRange
-- gets an allowance: half of Cone, plus the angle AimRadius (and half its own length) covers at its distance, plus
-- FarAim by its distance. Inside its allowance it scores AngleWeight x (how far off the aim) + DistanceWeight x (its
-- distance as a share of the range); the lowest score wins.
-- Hugo, 2026-11-12: the fish you AIM at, far ones as easy to pick as near ones. So being far counts a third of what it
-- did, and a far fish, small on the screen, has a margin round it that counts as on it (FarAim).
Config.Lock = {
	Cone = 40, -- full angle round the aim that a far fish must be inside
	AimRadius = 8, -- the aim ray's thickness, studs
	MaxAngle = 80, -- no fish further off the aim than this, however near
	AngleWeight = 1, -- being off the aim
	DistanceWeight = 0.07, -- being far: only close calls go to the nearer fish; 0.07 is a degree and a half of aim over the whole range (0.2 until 2026-11-12, 0.35 before the range went from 85 to 130)
	FarAim = 5, -- degrees round a fish at the full range that count as aimed at it, and that much more allowance (in proportion nearer; 0: a far fish must be aimed at exactly, as before)
	-- The fish you just left swims on right under the middle of the view, so with no penalty it takes nearly every lock.
	LeftPenalty = 0.5, -- added to its score: any other fish near the aim wins; with none, a grab takes it back
	-- so the lock doesn't flicker between two fish
	-- 2026-11-11, the user after playing: the lock switched between too many fish too close together. Steadier now:
	-- Sticky 0.2 to 0.35, MinHold 0.3 to 0.45, KeepCone 1.4 to 1.6, and the two new rows below.
	Sticky = 0.35, -- another fish must score this much better to take the lock (with EdgeAim: 0.35 is 7 degrees of aim),
	MinHold = 0.45, -- and never sooner than this after the lock was taken,
	KeepCone = 1.6, -- and the locked fish keeps the lock this much further off the aim than it took to win it,
	SwitchTime = 0.15, -- and the better fish must stay the better one this long first (0: at once, as before)
	EdgeAim = 1, -- 1: "off the aim" is measured from the fish's nearest edge in degrees (a fish the aim passes through scores 0); 0: from its middle as a share of its own allowance (until 2026-11-11: near fish off to the side took the lock)
	FallbackRadius = 4, -- assumed fish radius if its type has not replicated
	-- (0 since 2026-11-12: in the reference nothing is marked while you ride, with dinos all round; the mark comes on
	-- once you are in the air)
	Preview = 0, -- 1: the lock shows (a fainter glow) while you ride or float, so you see what you could reach; 0: only after leaving
}

-- Wild fish swim as a herd: all the same way, down the lane, at this share of the speed they are ridden at (the
-- reference: riding about 55 m a second, the herd about 46, measured off its distance counter)
Config.Herd = {
	SpeedShare = 0.85,
	Ahead = 60, -- each fish heads for a point this far down the lane, at its own place across it and above the floor
	RideHeight = 12, -- a ridden fish with no dive or climb held settles at this height above the floor: in the herd
	RideHeightGain = 1.6, -- degrees of pitch for each stud it is off that height
	RideHeightPitch = 35, -- at most
	-- The big solid things standing in the lane (the map's BigAssets): a ridden fish is stopped by them; wild fish don't
	-- collide with anything, so they are steered round. A fish that would pass too near one ahead moves its place
	-- across the lane to the side it is already on (the other, if the wall is too near).
	ObstacleLook = 150, -- how far ahead a fish minds one
	ObstacleGap = 12, -- the water it leaves between its side and the obstacle
	ObstacleShift = 45, -- how fast its place across the lane moves, studs a second
	WallGap = 8, -- and how near the lane's edge its middle may come doing so
}

-- Running a ridden fish into something solid (a wall, a step's face, a rock): it never kills (Hugo, 2026-11-11). You
-- lose speed and some Oxygen. The server decides it: a ray along the fish's nose, counted once as the nose comes up
-- against the thing (staying pressed against it costs nothing more).
Config.Crash = {
	Slow = 0.45, -- your speed drops to this share at once,
	Recover = 1.4, -- and comes back over this many seconds
	Cost = 0.1, -- of max Oxygen
	Floor = 1, -- a crash never takes Oxygen below this: it can't be what drowns you
	Cooldown = 1.5, -- seconds before another crash or smash can cost anything
	HeadOn = 0.35, -- how square on it must be (0 any touch, 1 dead straight in): sliding along a wall is not a crash
	MinSpeed = 12, -- slower than this it is a nudge, not a crash
	Reach = 2, -- the nose's ray reaches this far past where the fish's own steering stops it
	Every = 0.1, -- seconds between the server's checks of a ridden fish
	Kick = 0.35, -- the camera's jolt, studs
}

-- The wall ride (Hugo, 2026-11-12; docs/design/riding-feel.md, "The wall ride"): the edge of the map, and any wall,
-- no longer stops you. Steered into one you are turned along it and ride it like a hoverboard pushing off, keeping
-- your speed but for a share that grows with how square on you came: shallow keeps nearly all, steep loses more
-- (Loss, Curve). Dead straight in (inside HeadOn degrees of square on) you don't slide either way: you rock up the
-- wall and back down like a swing, dying away, until you steer off it. On a fish and in the hop alike (Lib/WallRide,
-- on the rider's own machine, as all the steering is); A and D, the look and the hop are untouched. The lane's edge
-- and the floor stay hard limits behind it (Lib/Course), so nothing here can take you out of the map.
Config.Wall = {
	On = 1, -- 0: the old way (slide along a wall at whatever speed is left, stopped dead when square on)
	Loss = 0.5, -- the share of your speed lost riding a wall you are steered square into (just short of the swing)
	Curve = 2, -- how the loss grows with the angle: 2 keeps 97% at 15 degrees, 88% at 30, 75% at 45, 62% at 60
	Ease = 9, -- how quickly your speed takes that share, and gets it back as you steer off (higher is quicker)
	Band = 1.5, -- this near the lane's edge counts as touching it, studs
	HeadOn = 12, -- inside this many degrees of square on: the swing, no slide
	Blend = 12, -- and over this many degrees past it the slide comes in (so there is no edge between the two)
	SwingKick = 0.55, -- the swing: you go up the wall with this share of your speed,
	SwingMost = 22, -- but never further up than this, studs
	SwingRate = 0.45, -- swings a second
	SwingDamp = 0.2, -- dying away (0 never, 1 with no swing back)
	SwingPitch = 50, -- the fish's nose goes up and down with the swing by up to this, degrees (the stand-in motion)
	Lean = 14, -- and the body rolls this much away from the wall it rides, degrees (the stand-in motion)
	EdgeCost = 0, -- of max Oxygen, for running square into the lane's own edge (0: the edge is a wall ride, never a crash; anything standing in the lane is still Config.Crash)
	EdgeBand = 20, -- the server calls a wall the lane's edge when it is this near it or beyond, studs
}

-- Props break (Hugo, 2026-11-11; the map's Lane/Props: each a Model of loose boxes). A fish that swims into one knocks
-- the boxes it touches loose, and those resting on them; they are thrown along its way, hang in the water, and the prop
-- builds itself back after Rebuild seconds. All on the server, so everyone sees the same prop. Breaking gives nothing.
-- For the rider it is a small crash: a little speed, a little Oxygen.
Config.Props = {
	MinLength = 0, -- only a fish at least this long (studs) breaks props; a shorter one crashes into them. 0: every fish
	Reach = 2, -- boxes this near the fish's nose (past its own half width) are knocked
	Topple = 22, -- boxes of the same prop above the lowest one knocked, and this near across, come down with it
	MaxLoose = 60, -- the most boxes one hit knocks loose
	Push = 16, -- how far a box is thrown along the fish's way, studs (each between half of this and all of it)
	Scatter = 7, -- and outward from where it was hit
	Sink = 5, -- and down
	Spin = 70, -- and turned, degrees
	KnockTime = 0.7, -- seconds a box takes to get there
	Rebuild = 8, -- seconds after the last hit before the prop builds itself back
	RebuildTime = 0.9, -- seconds a box takes to fly home
	RebuildStagger = 0.4, -- the boxes set off over this long, not all at once
	Slow = 0.8, -- the rider's speed drops to this share (it comes back over Crash.Recover)
	Cost = 0.03, -- of max Oxygen
	WildEvery = 0.3, -- seconds between a wild fish's checks while it is inside a big thing's circle
}

Config.Switch = {
	HandBack = 1.5, -- the old fish stays with its last rider's client this long, coasting, before the server takes it
}

-- The bubble burst on every landing, for everyone
Config.Burst = {
	Count = 30,
	Time = 0.6,
	Reach = 4, -- studs the bubbles fly out
}

-- Out of Oxygen (and a jump that comes down on nothing, until there is a revive): no input, ends at the dock.
local DROWN = { Throw = 0.8, Struggle = 2.5, MissStruggle = 0.6, Weak = 1.2, Still = 0.8, Tail = 0.2 }
Config.Death = {
	-- a jump that sank: the sinking was the struggle, so the drown that follows is short
	MissStruggle = DROWN.MissStruggle,
	MissTime = DROWN.MissStruggle + DROWN.Weak + DROWN.Still + DROWN.Tail,
	-- out of Oxygen: thrown off (when on a fish), then drowning
	Throw = DROWN.Throw,
	ThrowBack = 8, -- studs up and back
	Struggle = DROWN.Struggle, -- flailing, a steady stream of bubbles
	Weak = DROWN.Weak, -- the bubbles thin out
	Still = DROWN.Still, -- still and sinking, the last bubble
	DrownFade = 0.7, -- the fade to black, ending with the drown
	DrownTime = DROWN.Throw + DROWN.Struggle + DROWN.Weak + DROWN.Still + DROWN.Tail, -- less Throw when not thrown
}

-- The movement sandbox (Studio only; docs/sandbox.md): for play-testing the ride, the jump and the camera. The flags can
-- be switched in its panel (N) while playing.
Config.Sandbox = {
	On = true, -- in Studio, start with the sandbox on
	NoFail = true, -- a jump that sinks leaves you floating instead of drowning, and floating never sends you to the dock
	EndlessAir = true, -- Oxygen doesn't drain (turn it off to judge the drain by land)
	StartS = 130, -- R puts you back here: studs down the lane from its start, or further down, at the first place
	StartRoom = 34, -- with this much water above the herd, so a jump has room to rise
}

Config.Net = {
	RangeSlack = 1.2, -- the server allows this much more than Jump.GrabRange (it sees the player and the fish a moment apart; 1.1 until 2026-11-11: at the faster air speed a grab at the full 130 studs was refused in Studio)
}

Config.Camera = {
	Fov = 70,
	SpeedFov = 14, -- extra field of view at top riding speed
	SpeedFovFrom = 20, -- speed where it starts
	SpeedFovTo = 100, -- speed where it's full
	Distance = 17,
	Height = 5,
	-- The springs: everything the camera does goes through one, so it never snaps between riding, the
	-- swim, the pull-in and the landing. Each number is about how long that spring takes to close a gap (critically
	-- damped: no overshoot); higher is softer.
	FocusTime = 0.12, -- following the rider
	TurnTime = 0.07, -- turning and tilting (your own mouse look goes through it too, so keep it short)
	ZoomTime = 0.3, -- moving in and out (riding to the hop and back, and coming back out from a wall)
	FovTime = 0.2, -- the field of view following speed (the pull-in's zoom and the landing's snap sit on top, unsprung)
	-- Your look wins (Hugo, 2026-11-11: the camera felt forced). The view turns with you when A and D turn you, and
	-- is otherwise left where you put it: nothing pulls it behind the fish after a landing, and nothing tilts it in
	-- the hop. Only after LookBack seconds without you touching it does it drift back behind you, gently.
	AutoRecentre = 1, -- 1: the view drifts back behind you after LookBack seconds left alone; 0: never
	Recentre = 1.2, -- how quickly it drifts back (higher is quicker; 3 until 2026-11-11)
	LookBack = 4, -- seconds after you last moved the view before it does (1.2 until 2026-11-11)
	AirRest = 1, -- 1: in the hop the view tilts to Jump.CameraPitch until you move it, and comes back up at the landing (the reference: the camera lifts to look down from behind; with the lock aimed by the view this is also what puts the near fish under the aim, not ones 100 studs off); 0: it stays (Hugo's feel pass)
	StickSensitivity = 2.6, -- radians of camera look a second with a gamepad's right stick pushed all the way
	MouseSensitivity = 0.004, -- radians of camera look per mouse pixel
	TouchSensitivity = 0.006, -- radians of camera look per touch pixel
	PitchMin = -75, -- lower camera pitch limit, degrees
	PitchMax = 65, -- upper camera pitch limit, degrees
	RestPitch = -12, -- the tilt the view drifts back to with the rest, riding and floating, degrees
	PitchFollow = 1.2, -- how quickly (3 until 2026-11-11)
	AirPitchFollow = 4, -- with AirRest on: how quickly the view tilts in the hop
	FocusHeight = 0.5, -- focus offset as a share of Height
	ArmHeight = 0.3, -- camera arm lift as a share of Height
	WallGap = 0.8, -- camera clearance from solid walls, studs
	WheelStep = 2, -- zoom change per mouse wheel step, studs
	ZoomMin = 8, -- nearest manually selected camera distance, studs
	ZoomMax = 40, -- farthest manually selected camera distance, studs
	AirMouseLook = 1, -- 1: in the hop the mouse aims without a button held (it is locked to the centre); 0: right drag only
	-- The camera stays underwater (Hugo, 2026-11-12: it came out of the water in a hop, most of all in the first land).
	-- Once we have dived, it is kept SurfaceMargin under the water's surface (WaterTop) until we are back on the dock or
	-- respawn: near the surface it swings down behind us instead of rising, and the view gives up SurfaceTilt of the
	-- tilt that costs, so we stay in the picture and the aim hardly moves. The jolt and the shake are held under too.
	Submerge = 1, -- 0: the camera may leave the water, as before
	WaterTop = 0, -- the height of the water's surface (the map's water: tools/map/water_look.luau, Top)
	SurfaceMargin = 3, -- the camera stays this far under it, studs (clear of the water's own breathing layers)
	SurfaceTilt = 0.5, -- 0: the view keeps its tilt (we sit high in the picture); 1: it levels out to keep us in the middle
}

-- The look of the light (Shared/Look puts these on Lighting; Controllers/LookController does it live while playing, so
-- each is a row on the N panel; tools/studio/look_install.luau does it in Studio's Edit mode). From the user's lighting
-- tutorial, 2026-11-11 (docs/design/lighting.md): bright, with a cool ambient, a wide bloom, and strong contrast and
-- saturation; then toned down the same day (the user: too blinded by light, textures hard to see). Colours are three numbers, 0 to 255.
Config.Look = {
	On = 1, -- 0: the place's own lighting, untouched (to compare)
	Brightness = 2.8, -- the sun's strength (Roblox's own start is 3; the tutorial's 4 washed the sand and studs out, 2.4 looked washed out to the user, 3 a touch too bright)
	ShadowSoftness = 1, -- 0 hard to 1 soft
	ClockTime = 14.5, -- the hour: where the sun stands
	Latitude = 0, -- tilts the sun's path
	Exposure = -0.25, -- the whole picture lighter or darker, in stops
	AmbientR = 118, -- the light in shade (indoors, under things); the tutorial's is 124, 155, 184. Nearly grey now:
	AmbientG = 128, -- a blue shade light turned every green to mint and washed the floor's squares out
	AmbientB = 138,
	OutdoorR = 150, -- the light in shade under the open sky; the tutorial's is 157, 178, 255 (as blue as the sky)
	OutdoorG = 158,
	OutdoorB = 170,
	EnvDiffuse = 0.35, -- how much the sky tints everything (1 laid the sky's blue over every surface)
	EnvSpecular = 1, -- how much the sky shows in shiny things
	BloomIntensity = 0.6, -- the glow round bright things: how strong (the tutorial's is 1),
	BloomSize = 48, -- how wide (Roblox's own start is 24, the tutorial's 56),
	BloomThreshold = 2.2, -- and how bright a thing must be to glow (the tutorial's is 2)
	Contrast = 0.25, -- -1 to 1 (the tutorial's is 0.5)
	Saturation = 0.3, -- -1 to 1: how vivid the colours are (the tutorial's is 0.5)
	ColourBrightness = 0, -- -1 to 1, after everything else
	TintR = 245, -- the whole picture is multiplied by this colour (a faint lilac)
	TintG = 234,
	TintB = 255,
	Sky = 2, -- which sky of ReplicatedStorage.Skies, in name order: 1 the place's first sky, 2 the Anime Sky (0: whatever Sky is in Lighting)
}

-- How creatures and riders move beyond the keyed swim. First built 2026-11-11 (docs/design/animation-study.md), then
-- worked over with the user in the Swim Lab preview and carried here 2026-11-12: these are that preview's "Lively,
-- balanced" numbers. Every layer is seen only: it turns or shifts joints, never the Root, so the Saddle, the lock and
-- the server's checks are untouched. The numbers by body type are in Shared/RideStyles. A row at 0 turns its layer off.
-- Judged by the user in the preview, not yet in play.
Config.Animation = {
	-- Effort: the fish works harder when it speeds up, is landed on or fights, and eases when it coasts
	Effort = 1, -- 1: the swing follows the effort; 0: every beat the same
	EffortAccel = 0.03, -- effort gained for each stud a second it speeds up in a second (lost when slowing)
	EffortBeat = 0.1, -- how much of the effort goes into a faster beat (little: the user found changes of fin speed too much)
	LandEffort = 0.35, -- the kick at a landing's touch: this much more effort (half of it when a wild reaction follows),
	LandEffortTime = 0.6, -- dying away over this long
	CrashFlinch = 0.35, -- a crash rears and shakes your fish: this share of the buck (0 off)
	-- The turn layer: the head leads into a turn and the tail comes round late; wild fish bank; the side fins answer
	Turn = 1, -- the whole layer's strength (0 off)
	TurnLead = 0.05, -- the head's bend, radians for each radian a second of turning (it follows quickly)
	TurnBend = 0.04, -- each tail joint's bend the other way (it follows slowly, so it trails)
	TurnMax = 5, -- no joint bends further than this, degrees
	TurnTotal = 28, -- and the joints of one chain no further than this together
	WildBank = 0.2, -- a wild fish's roll into a turn, radians for each radian a second (a ridden fish banks for real)
	WildBankMax = 18, -- at most, degrees
	FinTurn = 1, -- the side fins in a turn (tilt, sweep, a wider stroke outside: RideStyles.Fins); 0 off
	-- The body layer: the heave, nod, sway and rock of the creature's style, each beat
	Body = 1.2, -- its strength (0 off); a small fish and a quick beat show less of it
	Cadence = 1, -- 1: the beat's rate by style; 0: by length alone
	Jaw = 1, -- 1: a jaw hangs nearly shut and opens now and then; 0: it chomps every beat, as keyed
	-- The slow wave (RideStyles.Waves): the stroke, the height, the drift to a side and the lean, on one rhythm
	Wave = 0.8, -- its size (0 off); a small fish shows about half
	-- The landing: the touch, then what a wild animal does about it
	LandDip = 1.2, -- the touch: it sinks this far under the rider, studs, for a mid-sized fish of a style whose Dip is 1 (0 off)
	LandNod = 7, -- and noses down this much, degrees
	LandDipTime = 0.7, -- seconds until that is still
	Wild = 1, -- how hard the reaction is (0: only the dip). A small fish fights less, a mid-sized one hardest
	LandingMix = 2, -- 2: a mix of landing types (the user, 2026-11-12): the body type's own most often, its second often, now and then any of the seven; 1: always its own; 0: none
	-- The rider
	RiderFollow = 1, -- 1: the rider moves with the fish's body; 0: sits still over it
	RiderCalm = 1, -- 1: they take the body's shift eased and at half its turning, so they aren't shaken; 0: exactly
	Brace = 0.45, -- seconds of the landing's brace: arms up, knees folded, then the grab (0 off)
}

-- The rider's own animation (AnimController): poses made in code on the avatar's joints, R15 or R6, blended from one
-- to the next; Roblox's own animations are stopped while we are in the water. Hugo, 2026-11-12: real swimming, a
-- dash and a riding pose.
Config.Pose = {
	Blend = 16, -- how quickly one pose runs into the next (higher is quicker)
	-- swimming: the glide and the drop of a hop are a front crawl, floating is a slow breaststroke; the body lies flat
	CrawlRate = 1.7, -- arm strokes a second in the hop (each arm)
	CrawlKick = 5.5, -- leg kicks a second
	CrawlRoll = 14, -- the body rolls this far to each stroke, degrees
	BreastRate = 0.75, -- strokes a second while floating
	FloatTilt = 62, -- floating, the body lies this far forward, degrees (0: upright, treading water)
	-- the dash: off the fish (the pop) and onto the next (the pull-in)
	PopTuck = 0.09, -- seconds crouched on the fish before the push off (seen only: the hop itself starts at the press)
	Flip = 1, -- forward flips into the seat at the end of the pull-in (0: none)
	FlipStart = 0.45, -- the share of the pull-in at which the tuck and the flip begin (streamlined until then)
	FlipMin = 0.25, -- no flip in a pull-in shorter than this, seconds (onto a fish right beside us: it would be a blur)
	-- riding
	RideCrouch = 26, -- at full speed the rider leans this far forward over the fish, degrees
	RideLean = 14, -- and this far into a turn
	BraceLean = 24, -- on a startled fish: this far forward against the rearing, arms round its back
}

-- The juice (Hugo, 2026-11-12: more satisfying movement): what is added round the hop, the pull-in, the landing and
-- the bolt. Speed lines are drawn on the screen (Lib/Feel); the sounds are the client's own built-in ones, pitched.
Config.Feel = {
	PopFov = 7, -- the pop: the view kicks this much wider at once and settles (as the landing's snap does)
	PopBurst = 16, -- bubbles kicked off where we left
	PopLines = 0.6, -- speed lines through the pop's extra speed, 0 to 1 (0 off)
	ReelLines = 1, -- and through the pull-in, growing as it speeds up
	BoltLines = 0.85, -- and as a fish picks its speed up again after a landing's slow-down
	BoltFov = 3, -- the view kicks this much wider as it does
	LinesFade = 0.3, -- seconds the lines take to die away
	LinesInner = 0.42, -- how near the middle of the screen they reach, as a share of half its diagonal (1: the corners only)
	Trail = 70, -- bubbles a second left behind us through the pop's extra speed and the pull-in (0 off)
	Whoosh = 0.5, -- how loud the pull-in's whoosh is (0 off),
	WhooshPitch = 2.2, -- and how high
	Swish = 0.35, -- the pop's swish
	Splash = 0.55, -- the landing's splash
	SplashCount = 26, -- bubbles thrown out flat round the fish at our own landing,
	SplashReach = 9, -- this far, studs
}

-- How the lock and the window's timer are drawn.
Config.AimHud = {
	RefusedTime = 0.25, -- seconds the reticle flashes red on an empty grab
	FollowRate = 30, -- response rate of the locked fish's screen bracket
	PreviewTransparency = 0.6, -- bracket transparency while riding or floating
	PulsePeriod = 0.2, -- seconds per warning pulse
	PulseWhiten = 0.4, -- amount of white mixed into the red warning pulse
	PulseScale = 0.12, -- warning pulse grows the timer by this fraction
}

Config.Spawn = {
	-- Round 2 spreads fish evenly along the lane's path: cut into Slice-stud slices, every slice keeps at least one fish
	-- (the dive board's keeps BoardSlice), and new fish go into the emptiest slice. The spec's 8 per 1,000 would make
	-- fewer fish than v3 had; the user asked for more in all, so 12 (to tune).
	PerThousand = 24, -- wild fish per 1,000 studs of lane (doubled 2026-11-10: a jump needs a fish within its flight)
	Min = 20,
	Max = 110, -- per zone
	-- Fish go in every zone along the whole lane that has a roster (a fish type that can turn up there: today zones 1
	-- to 6, the four homes plus two zones of reach); zones with none stay empty until their fish exist. 12 a 1,000 over
	-- zones 1 to 6 makes about 171; all ten zones would make about 290, so the cap sits above that.
	-- (2026-11-11: the whole ten-land lane is 30,000 studs, which wants about 720. At 480 the deep lands took the lot,
	-- the Shallows were left with 11 fish 90 studs apart, and a jump in a deep land found nothing to land on.)
	MaxTotal = 800,
	Slice = 120,
	BoardSlice = 2,
	Wander = 80, -- a fish wanders this far either way along the lane from its home
	TopUpEvery = 2,
	PerTopUp = 6,
	-- The herd keeps to one layer above the lane's floor (2026-11-10, from 10 to 60): the reference's dinos are all on
	-- the ground, and a jump has to find a fish at about its own depth.
	-- (2026-11-10: lowered from 16 to 30, so that even in the shallows there is water above the herd to jump up into)
	HeightMin = 8, -- above the lane's floor
	HeightMax = 16,
	HeightFloor = 6, -- in shallow water the herd is pressed down to leave room for a jump, but never lower than this
	RoofGap = 10, -- under a roof (the map's Path c), fish stay this far below it
	LaneFill = 0.7, -- fraction of the lane's half width fish use
	-- The herd is never wider than this, however wide the lane (2026-11-11: the lane now widens to 980). Spread over a
	-- lane that wide the fish were too far apart to jump between; kept to a band down the middle, a jump finds one in
	-- every land the way it does in the Shallows.
	BandMax = 200,
	StreamRadius = 700, -- fish further than this from every player are parked (out of Workspace, not simulated)
	AppearClear = 160, -- a new fish is put this far from every player when its slice of the lane has such a place
	SpawnAtDock = true, -- characters spawn at the dock's Spawn marker when there is one
}

-- Share of spawns by rarity per zone, from the roster's draft weights. A tier with no fish in a zone is skipped.
Config.ZoneMix = {
	{ Common = 74, Uncommon = 22, Rare = 3.2, Epic = 0.6, Legendary = 0.2 },
	{ Common = 10, Uncommon = 60, Rare = 25, Epic = 4, Legendary = 1 },
	{ Uncommon = 40, Rare = 45, Epic = 12, Legendary = 3 },
	{ Uncommon = 15, Rare = 50, Epic = 30, Legendary = 5 },
	{ Uncommon = 3, Rare = 40, Epic = 45, Legendary = 11, Mythic = 1 },
	{ Rare = 20, Epic = 50, Legendary = 28, Mythic = 2 },
	{ Rare = 5, Epic = 42, Legendary = 50, Mythic = 3 },
	{ Epic = 25, Legendary = 70, Mythic = 5 },
	{ Epic = 5, Legendary = 87, Mythic = 8 },
	{ Legendary = 88, Mythic = 12 },
} :: { { [string]: number } }

-- The same ten tables under plain names, for the sandbox panel: MixShallows.Common is ZoneMix[1].Common, and so on.
-- Not a second copy: the same tables, so a share changed on the panel is the share the next spawn uses.
for i, name in
	{
		"MixShallows",
		"MixCoralReef",
		"MixKelpForest",
		"MixShipwrecks",
		"MixOpenBlue",
		"MixTwilight",
		"MixMidnight",
		"MixVents",
		"MixBoneGraveyard",
		"MixUnderworld",
	}
do
	(Config :: any)[name] = Config.ZoneMix[i]
end

-- Weight of a fish by how far from home it is: home, one zone on, two zones on
Config.ReachWeight = { 1, 1 / 3, 1 / 10 }

type FishSpec = {
	Id: string,
	Name: string,
	Tier: string,
	Home: number,
	Reach: number?,
	Size: Vector3,
	Shape: string,
	Body: Color3,
	Belly: Color3?,
	Fin: Color3?,
	Pattern: string?,
	PatternColour: Color3?,
	PatternCount: number?,
	IdleSpeed: number?,
}

-- stylua: ignore
local FISH: { FishSpec } = {
	-- zone 1: Shallows
	{ Id = "SergeantMajor", Name = "Sergeant Major", Tier = "Common", Home = 1, Reach = 1, Size = Vector3.new(3.4, 5, 9), Shape = "Fish", Body = rgb(236, 232, 190), Belly = rgb(250, 250, 240), Fin = rgb(250, 215, 70), Pattern = "Stripes", PatternColour = rgb(25, 25, 30), PatternCount = 5 },
	{ Id = "YellowTang", Name = "Yellow Tang", Tier = "Common", Home = 1, Reach = 1, Size = Vector3.new(3, 5.6, 8.5), Shape = "Fish", Body = rgb(255, 225, 40), Fin = rgb(255, 235, 90) },
	{ Id = "Clownfish", Name = "Clownfish", Tier = "Common", Home = 1, Reach = 1, Size = Vector3.new(3.4, 4.2, 9), Shape = "Fish", Body = rgb(255, 120, 20), Fin = rgb(255, 140, 40), Pattern = "Bands", PatternColour = rgb(255, 255, 255), PatternCount = 3 },
	{ Id = "Pufferfish", Name = "Pufferfish", Tier = "Common", Home = 1, Reach = 1, Size = Vector3.new(5.5, 5.5, 8), Shape = "Round", Body = rgb(215, 190, 120), Belly = rgb(245, 240, 220), Fin = rgb(190, 160, 90), Pattern = "Spots", PatternColour = rgb(110, 85, 50) },
	{ Id = "Stingray", Name = "Stingray", Tier = "Uncommon", Home = 1, Size = Vector3.new(9, 1.6, 11), Shape = "Flat", Body = rgb(150, 130, 105), Belly = rgb(235, 230, 220), Fin = rgb(130, 110, 90) },
	{ Id = "Seahorse", Name = "Seahorse", Tier = "Rare", Home = 1, Size = Vector3.new(2.6, 7, 6.5), Shape = "Fish", Body = rgb(255, 170, 60), Fin = rgb(255, 210, 120), Pattern = "Stripes", PatternColour = rgb(225, 130, 40), PatternCount = 4 },
	{ Id = "ReefShark", Name = "Reef Shark", Tier = "Epic", Home = 1, Size = Vector3.new(3.6, 4, 16), Shape = "Shark", Body = rgb(130, 140, 150), Belly = rgb(240, 240, 240), Fin = rgb(120, 130, 140), Pattern = "Tips", PatternColour = rgb(20, 20, 25) },
	-- zone 2: Coral Reef
	{ Id = "Parrotfish", Name = "Parrotfish", Tier = "Uncommon", Home = 2, Size = Vector3.new(3.6, 5, 10), Shape = "Fish", Body = rgb(40, 200, 170), Fin = rgb(255, 120, 170), Pattern = "Stripes", PatternColour = rgb(255, 150, 60), PatternCount = 2 },
	{ Id = "Lionfish", Name = "Lionfish", Tier = "Uncommon", Home = 2, Size = Vector3.new(3.2, 5, 9), Shape = "Fish", Body = rgb(240, 240, 235), Fin = rgb(200, 40, 40), Pattern = "Stripes", PatternColour = rgb(200, 40, 40), PatternCount = 6 },
	{ Id = "MorayEel", Name = "Moray Eel", Tier = "Rare", Home = 2, Size = Vector3.new(2.6, 3, 18), Shape = "Eel", Body = rgb(70, 130, 60), Fin = rgb(90, 150, 70) },
	{ Id = "HumpheadWrasse", Name = "Humphead Wrasse", Tier = "Epic", Home = 2, Size = Vector3.new(5, 8, 15), Shape = "Fish", Body = rgb(50, 140, 150), Fin = rgb(70, 170, 160) },
}

-- The modelled creatures (Shared.Creatures, from the creature chat's exports) bring their own name, rarity, land and
-- size. One that is also in the table above keeps only its placeholder colours from there; the rest are added. A
-- creature whose land isn't in the map yet simply never spawns. (The five placeholder fish of lands 3 and 4 went
-- 2026-11-12: each has a model now.)
-- A creature here has its template in the game but is kept out of the herd (Reach -1: no land takes it): the Bobbit
-- Worm is not in the roster yet (the creature chat, 2026-11-12). Secrets need no entry: no land's mix has a Secret.
local NO_SPAWN: { [string]: boolean } = { BobbitWorm = true }
do
	local at: { [string]: number } = {}
	for i, spec in FISH do
		at[spec.Id] = i
	end
	for _, id in Creatures.ids() do
		local rig = Creatures.get(id) :: Creatures.Rig
		if not Config.Tiers[rig.Tier] then
			warn("[Config] " .. id .. ": no such rarity as " .. tostring(rig.Tier) .. "; left out")
			continue
		end
		local size = Vector3.new(rig.Size[1], rig.Size[2], rig.Size[3])
		local i = at[id]
		if i then
			local spec = FISH[i]
			spec.Name = rig.Name
			spec.Tier = rig.Tier
			spec.Home = rig.Zone
			spec.Size = size
		else
			table.insert(FISH, {
				Id = id,
				Name = rig.Name,
				Tier = rig.Tier,
				Home = rig.Zone,
				-- a Common swims only one land on, like the four in the table above (the roster: Commons reach the
				-- start of the Coral Reef); the rest take the usual two
				Reach = if rig.Tier == "Common" then 1 else nil,
				Size = size,
				Shape = "Fish",
				Body = rgb(150, 160, 170),
			})
			i = #FISH
		end
		if NO_SPAWN[id] then
			FISH[i].Reach = -1
		end
	end
end

Config.Fish = {} :: { FishType }
Config.FishById = {} :: { [string]: FishType }

-- Oxygen a second on a fish of this rarity, in land number `zone` (past the last land: the last land's)
function Config.drain(zone: number, tier: string): number
	local per = Config.ZoneDrain
	local base = per[math.clamp(zone, 1, #per)]
	return base * (Config.RarityDrain[tier] or 1)
end

-- The max Oxygen that keeps up there: landing a hop every Oxygen.KeepUp seconds, the refills just pay for the drain
function Config.required(zone: number, tier: string?): number
	local o = Config.Oxygen
	return math.ceil(Config.drain(zone, tier or "Common") * o.KeepUp / math.max(o.Refill, 0.01))
end

-- Whether a fish of this rarity, in land number `zone`, is too strong for a rider with this max Oxygen: it needs more
-- than they have (Oxygen.StrainTime)
function Config.strained(zone: number, tier: string, max: number): boolean
	return Config.Oxygen.StrainTime > 0 and max < Config.required(zone, tier)
end

-- Whether a meter at `oxygen` of `max` is in its low, red part (Oxygen.AngryAt): where the ring turns red and the fish
-- under you turns angry
-- Where the red part of the meter starts on this fish, as a share of max Oxygen: Oxygen.AngryAt, and lower on a Tank
function Config.angryAt(fish: FishType?): number
	local at = Config.Oxygen.AngryAt
	if fish and Config.hasArchetype(fish, "Tank") then
		at *= Config.Archetype.Tank.AngryAt
	end
	return at
end

-- (`fish`: the fish under the rider, when there is one: a Tank's red part starts lower)
function Config.low(oxygen: number, max: number, fish: FishType?): boolean
	return oxygen <= math.max(max, 0.001) * Config.angryAt(fish)
end

function Config.heat(oxygen: number, max: number, fish: FishType?): number
	local from = math.max(max, 0.001) * Config.angryAt(fish)
	if from <= 0 then
		return if oxygen <= 0 then 1 else 0
	end
	return math.clamp(1 - oxygen / from, 0, 1)
end

-- The Oxygen a second THIS fish takes in a land: Config.drain for its rarity, and less on a Tank. What it takes to
-- hold a fish at all (Config.required, Config.strained: the number on its tag) is by rarity alone, Tank or not.
function Config.drainOf(zone: number, fish: FishType): number
	local rate = Config.drain(zone, fish.Tier)
	if Config.hasArchetype(fish, "Tank") then
		rate *= Config.Archetype.Tank.Drain
	end
	return rate
end

-- The burst on getting on this fish, and how long it lasts: Ride.Surge and Ride.SurgeTime, bigger and longer on a
-- Fast one. (After a landing only a Fast fish plays it: see Config.Archetype.Fast.)
function Config.surgeOf(fish: FishType?): (number, number)
	local r = Config.Ride
	if fish and Config.hasArchetype(fish, "Fast") then
		local f = Config.Archetype.Fast
		return r.Surge * f.Surge, r.SurgeTime * f.SurgeTime
	end
	return r.Surge, r.SurgeTime
end

-- How much of a burst of speed (an eat's, a smash's) is left `t` seconds in, 0 to 1: whole for the first two
-- thirds of its `time`, fading out over the last
function Config.burstShare(t: number, time: number): number
	if t < 0 or t >= time then
		return 0
	end
	local fadeFrom = time * 2 / 3
	return if t <= fadeFrom then 1 else 1 - (t - fadeFrom) / math.max(time - fadeFrom, 0.001)
end

-- The hop off this fish (nil: from floating): what Jump.Apex and the glide's speed are times, and the seconds added
-- to Jump.FloatTime and Jump.Window. 1, 1, 0 for all but a Leaper.
function Config.hopOf(fish: FishType?): (number, number, number)
	if fish and Config.hasArchetype(fish, "Leaper") then
		local l = Config.Archetype.Leaper
		return l.Apex, l.Air, l.FloatTime
	end
	return 1, 1, 0
end

-- (`fish`: with it, the seconds are this fish's own: longer on a Tank)
function Config.secondsOn(zone: number, tier: string, max: number, fish: FishType?): number
	if Config.strained(zone, tier, max) then
		return Config.Oxygen.StrainTime
	end
	local rate = if fish then Config.drainOf(zone, fish) else Config.drain(zone, tier)
	return max / math.max(rate, 0.001)
end

-- Airtime by speed (Config.Jump.AirSlow...): the seconds added to Jump.FloatTime and Jump.Window for a hop off a
-- fish going `speed` studs a second as we leave it (nil: from floating, nothing). The client flies by it and the
-- server's window is counted with it.
function Config.airOf(speed: number?): number
	if not speed or speed ~= speed then
		return 0
	end
	local j = Config.Jump
	local u = math.clamp((speed - j.AirSlowSpeed) / math.max(j.AirFastSpeed - j.AirSlowSpeed, 1), 0, 1)
	return math.max(j.AirSlow + (j.AirFast - j.AirSlow) * u, j.AirLeast - j.FloatTime)
end

-- The wall ride (Config.Wall): the share of our speed kept riding a wall we are steered into, by how square on:
-- `into` is 0 along the wall, 1 dead straight in
function Config.wallKeep(into: number): number
	local w = Config.Wall
	return 1 - math.clamp(w.Loss, 0, 1) * math.clamp(into, 0, 1) ^ math.max(w.Curve, 0.1)
end

-- Whether a fish breaks the props it swims into (Props.MinLength), or crashes into them
function Config.smashes(fish: FishType): boolean
	return fish.Size.Z >= Config.Props.MinLength
end

-- A spawned fish's variant, from a roll of 0 to 1 (Config.Variant): "", "Gold" or "Rainbow"
function Config.rollVariant(roll: number): string
	local v = Config.Variant
	if roll < v.Rainbow then
		return "Rainbow"
	elseif roll < v.Rainbow + v.Gold then
		return "Gold"
	end
	return ""
end

-- One fish's ridden speed: its species' own (Config.FishStats: RiddenSpeed), by its variant (x Speed.Gold or
-- x Speed.Rainbow, the same for every fish)
function Config.speedOf(fish: FishType, variant: string?): number
	local s = Config.Speed
	local speed = fish.RiddenSpeed
	if variant == "Gold" then
		speed *= s.Gold
	elseif variant == "Rainbow" then
		speed *= s.Rainbow
	end
	return speed
end

-- A fish model's size and variant (its attributes). No fish has a "Size" for now (the size roll is out: Hugo,
-- 2026-11-12), so every fish is 1; the readers of sizeOf and bodyOf stay for when sizing comes back.
function Config.sizeOf(model: Instance): number
	local size = model:GetAttribute("Size")
	return if type(size) == "number" and size > 0 then size else 1
end

function Config.variantOf(model: Instance): string
	local variant = model:GetAttribute("Variant")
	return if type(variant) == "string" then variant else ""
end

-- A fish model's own ridden speed and its body's size (width, height, length), from its type and its attributes
function Config.riddenOf(model: Instance, fish: FishType): number
	return Config.speedOf(fish, Config.variantOf(model))
end

function Config.bodyOf(model: Instance, fish: FishType): Vector3
	return fish.Size * Config.sizeOf(model)
end

-- A fish's passive archetypes as a list ({} for none), and whether it has one (Config.Archetype's keys)
function Config.archetypesOf(fish: FishType): { string }
	return if fish.Archetype == "" then {} else string.split(fish.Archetype, ",")
end

-- (asked every frame by the riding code: the sets are kept, one for each different row of archetypes)
local archetypeSets: { [string]: { [string]: boolean } } = {}
function Config.hasArchetype(fish: FishType, id: string): boolean
	local set = archetypeSets[fish.Archetype]
	if not set then
		set = {}
		for _, name in Config.archetypesOf(fish) do
			set[name] = true
		end
		archetypeSets[fish.Archetype] = set
	end
	return set[id] == true
end

-- A fish model's archetypes as the server wrote them (its "Archetype" attribute): "" for none
function Config.archetypeOf(model: Instance): string
	local archetype = model:GetAttribute("Archetype")
	return if type(archetype) == "string" then archetype else ""
end

for _, spec in FISH do
	local stat = Config.FishStats[spec.Id]
	if not stat then
		warn("[Config] " .. spec.Id .. " has no row in Config.FishStats: Speed.Base and no archetype")
	else
		for _, id in string.split(stat.Archetype, ",") do
			if id ~= "" and not (Config.Archetype :: { [string]: any })[id] then
				warn("[Config] " .. spec.Id .. ": no such archetype as " .. id)
			end
		end
	end
	local speed = if stat then stat.Speed else Config.Speed.Base
	local fish: FishType = {
		Id = spec.Id,
		Name = spec.Name,
		Tier = spec.Tier,
		Home = spec.Home,
		Reach = spec.Reach or 2,
		Required = Config.required(spec.Home, spec.Tier),
		IdleSpeed = spec.IdleSpeed or speed * Config.Herd.SpeedShare,
		RiddenSpeed = speed,
		Archetype = if stat then stat.Archetype else "",
		Size = spec.Size,
		Shape = spec.Shape,
		Body = spec.Body,
		Belly = spec.Belly or spec.Body,
		Fin = spec.Fin or spec.Body,
		Pattern = spec.Pattern,
		PatternColour = spec.PatternColour,
		PatternCount = spec.PatternCount,
	}
	table.insert(Config.Fish, fish)
	Config.FishById[fish.Id] = fish
end

-- The highest the herd swims above a floor at floorY: where the water is shallow it is pressed down, so that a jump has
-- its whole rise (Jump.Apex + Jump.FloatRise) above the rider's seat and still stays under the surface.
function Config.herdTop(floorY: number): number
	local j = Config.Jump
	local room = Config.Oxygen.SurfaceY - j.Ceiling - (j.Apex + j.FloatRise) - j.SeatRoom - floorY
	return math.max(room, Config.Spawn.HeightFloor)
end

-- A herd fish's height above a floor at floorY, from its own height in open water. Pressed down in the shallows, the
-- herd keeps a little of its spread (the top fifth of what room there is).
function Config.herdHeight(own: number, floorY: number): number
	local sp = Config.Spawn
	local top = Config.herdTop(floorY)
	if top >= sp.HeightMax then
		return own
	end
	local share = math.clamp((own - sp.HeightMin) / math.max(sp.HeightMax - sp.HeightMin, 1), 0, 1)
	return math.min(own, top * (0.8 + 0.2 * share))
end

-- The numbers worked out from other numbers. Called here, and again by the sandbox whenever it changes one.
function Config.refresh()
	local j = Config.Jump
	j.DropTime = math.max(0.1, j.Window - j.LaunchTime - j.FloatTime)
	j.FlightTime = j.Window + j.ReelMax
	-- each fish's own speed and archetypes, from Config.FishStats (the sandbox panel may have changed a number)
	for _, fish in Config.Fish do
		local stat = Config.FishStats[fish.Id]
		fish.RiddenSpeed = if stat then stat.Speed else Config.Speed.Base
		fish.Archetype = if stat then stat.Archetype else ""
		fish.IdleSpeed = fish.RiddenSpeed * Config.Herd.SpeedShare
		fish.Required = Config.required(fish.Home, fish.Tier)
	end
end

Config.refresh()

return Config
