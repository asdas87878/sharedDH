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
	Silver = 1.05, -- (2026-11-13: Silver is new and sits under Gold; a stand-in until fish speed is set)
	-- The first speed pass (2026-11-16; the user: "riding feels too slow", "every fish feels alike", "the herd looks
	-- wrong"; docs/design/dive-in.md, part 2). Two dials over Hugo's table (Config.FishStats), which is not touched:
	Ride = 1.6, -- every fish's ridden speed, times. 1: Hugo's table as written. (1.15 for a day; then the user, 2026-11-17: "Everything needs to be faster. Everything. It needs to feel a lot more wild and a lot more like a rodeo")
	Spread = 2, -- how far a fish's speed is from its land's pace (Config.LandPace of its home), times: a slow kind slower, a quick kind quicker, in the order the table has them. 1: as the table has it. (1.5 for a day; the user, 2026-11-17: "needs more variety in speed")
}

-- Each creature's own size, times what the creature chat exported it at (Shared.Creatures; a fish not listed is 1).
-- The user, 2026-11-13: more difference between kinds, most of all in the first lands ("turtle should be a bit bigger
-- and some fish should be smaller and larger"); and then, having seen the first go (0.85 to 1.6): "overall the fish
-- are too small across the board", and too alike at the start. So every kind is bigger (1.2 to 2.6, about 1.75 on
-- average) and the first land's kinds are spread widest: its seven Commons run from 12 to 23 studs long, where they
-- were 8 to 13. The numbers are Claude's, to be judged by eye. A fish's length sets a good deal else: the room it
-- wants in the herd, how high it swims, whether it breaks props (Config.Herd, Config.Spawn), so a change here shows
-- there too.
-- (2026-11-17, the user: "we need an overall size reduction mainly for these common fish in these starter lands,
-- basic fish shouldnt get as big as they are getting ... This applies to the turtle aswell. There should still be
-- variety in size but that variety should be intentional and thought through as to not make basic models look
-- inflated". A plain Sergeant Major was 20 studs long and 13 tall, beside a rider 5 tall; a Sea Turtle 41 wide. The
-- first three lands' Commons, Uncommons and Rares are smaller by a fifth to a third, in a set order: in the Shallows
-- a Blue Chromis 10 long, then Clownfish, Butterflyfish, Boxfish, Sergeant Major and Yellow Tang 13.5, a Pufferfish
-- 15, a Flying Fish 16, a Cuttlefish 19, a Sea Turtle 25, a Stingray 27. The predators and the Legendaries keep
-- their size: they are meant to look big. docs/design/sizes.md.)
-- stylua: ignore
Config.BaseScale = {
	-- land 1: Shallows
	BlueChromis = 1.0, Clownfish = 1.05, Butterflyfish = 1.15, SergeantMajor = 1.05, Boxfish = 1.35, YellowTang = 1.4, Pufferfish = 1.5,
	FlyingFish = 1.3, Stingray = 1.15, Cuttlefish = 1.45, SeaTurtle = 1.75, Seahorse = 1.3, ReefShark = 2.1, Archelon = 1.7, PearlSerpent = 1.8,
	-- land 2: Coral Reef
	Angelfish = 1.1, Lionfish = 1.3, Parrotfish = 1.45, MorayEel = 1.5, Octopus = 1.45, HumpheadWrasse = 1.8, Dunkleosteus = 2, CoralDragon = 1.8,
	-- land 3
	Garibaldi = 1.1, SeaLion = 1.5, GiantSeaBass = 1.65, LeopardShark = 1.5, GreatWhite = 2, StellersSeaCow = 2, Dakosaurus = 1.7, KelpWyrm = 1.8,
	-- land 4
	Barracuda = 1.4, HammerheadShark = 1.8, Sawfish = 1.7, ElectricRay = 1.6, GoliathGrouper = 2, Xiphactinus = 1.7, GalleonWhale = 1.9,
	-- land 5
	Dolphin = 1.7, Swordfish = 1.6, MantaRay = 2.1, Orca = 1.9, Elasmosaurus = 1.6, Helicoprion = 1.7, BlueWhale = 2.2, StormSerpent = 1.8,
	-- land 6
	Viperfish = 1.3, GiantSquid = 1.6, GoblinShark = 1.6, Liopleurodon = 1.7, Shonisaurus = 1.8, LanternLeviathan = 1.7, AuroraJelly = 1.7,
	-- land 7
	Anglerfish = 1.6, FrilledShark = 1.4, Basilosaurus = 1.7, Livyatan = 1.8, Mosasaurus = 1.8, Kraken = 1.9, VoidWhale = 2,
	-- land 8
	GiantIsopod = 1.3, SeaScorpion = 1.6, Anomalocaris = 1.6, BobbitWorm = 1.4, Kronosaurus = 1.7, Megalodon = 1.9, MoltenMegalodon = 2, EmberSerpent = 1.8,
	-- land 9
	GraveRay = 2, GraveTurtle = 1.8, SkullAngler = 1.6, WraithEel = 1.7, BoneLeviathan = 1.8, HalfboneMegalodon = 2, PhantomWhale = 2,
	-- land 10
	BrimstoneEel = 1.7, CinderRay = 2, HellfinShark = 1.8, InfernalAngler = 1.7, AbyssalWatcher = 1.9, Hellmaw = 1.9, TheDevourer = 2.1,
} :: { [string]: number }

export type FishStat = {
	Speed: number, -- studs a second, ridden, no variant
	Archetype: string, -- "" for none; more than one comma-separated; the ids are Config.Archetype's keys
	Breaks: boolean?, -- props: true, a ridden one breaks every prop (slowed by size: Config.propBreak), and a wild one breaks them; false, it breaks only the small ones ridden and none wild; left out: its size (ridden) or Config.breaks (wild) decides
}

-- THE per-fish table (Hugo, 2026-11-12): each creature's ridden speed and its passive archetypes, the single source
-- for both. The why of every row, the rules and the numbers: docs/design/archetypes.md (keep its table in step).
-- Fewer abilities (Hugo, 2026-11-13): most fish have NONE, whatever their rarity (51 of 82); one only where it is the
-- real animal's signature; at most 10 Predators and 8 Breakers; three fish have two, none more. Commons and Uncommons
-- have none. Check with `python tools/creatures/check_archetypes.py`. The server writes a fish's archetypes on its model as the "Archetype" attribute (FishService).
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
	Archelon = { Speed = 62, Archetype = "Tank" }, -- Legendary: a giant turtle: calm to sit on, and the meter barely moves
	PearlSerpent = { Speed = 100, Archetype = "" }, -- Secret: the first Secret: a long quick serpent, quick by its number only
	-- land 2: Coral Reef
	Parrotfish = { Speed = 50, Archetype = "" }, -- Uncommon: an ordinary grazer
	Angelfish = { Speed = 48, Archetype = "" }, -- Uncommon: tall and showy, not quick
	Lionfish = { Speed = 46, Archetype = "" }, -- Uncommon: drifts with its fins spread
	MorayEel = { Speed = 58, Archetype = "" }, -- Rare: a lunging ambusher with two sets of jaws: a plain Rare
	Octopus = { Speed = 54, Archetype = "" }, -- Rare: jets in pulses: a plain Rare
	HumpheadWrasse = { Speed = 60, Archetype = "Breaker" }, -- Epic: it really does crush coral with the bump on its head
	Dunkleosteus = { Speed = 76, Archetype = "Predator" }, -- Legendary: a bite that sheared through bone: the Reef's one eater
	CoralDragon = { Speed = 108, Archetype = "" }, -- Secret: a reef come alive: quick by its number only
	-- land 3: Kelp Forest
	SeaLion = { Speed = 58, Archetype = "" }, -- Uncommon: agile and playful: quick for an Uncommon, by its number only
	Garibaldi = { Speed = 52, Archetype = "" }, -- Uncommon: an ordinary kelp fish
	LeopardShark = { Speed = 62, Archetype = "" }, -- Rare: a small harmless shark: a plain Rare
	GiantSeaBass = { Speed = 54, Archetype = "" }, -- Rare: a heavy, slow, gentle giant: slow by its number, no trait
	GreatWhite = { Speed = 82, Archetype = "Predator" }, -- Epic: the shark
	StellersSeaCow = { Speed = 56, Archetype = "Tank" }, -- Epic: a gentle floating giant: slow, and the meter barely moves
	Dakosaurus = { Speed = 88, Archetype = "" }, -- Legendary: a sea crocodile built for the chase: quick by its number only
	KelpWyrm = { Speed = 112, Archetype = "" }, -- Secret: winds through the kelp: quick by its number only
	-- land 4: Shipwrecks
	Barracuda = { Speed = 64, Archetype = "" }, -- Uncommon: a torpedo: the fastest Uncommon, by its number only
	HammerheadShark = { Speed = 68, Archetype = "" }, -- Rare: a strong schooling shark: a plain Rare
	Sawfish = { Speed = 64, Archetype = "Breaker" }, -- Rare: a saw for a nose
	ElectricRay = { Speed = 62, Archetype = "" }, -- Epic: a sluggish disc that waits: slow by its number, no trait
	GoliathGrouper = { Speed = 60, Archetype = "Predator" }, -- Epic: a heavy lump that gulps fish whole: the slow eater
	Xiphactinus = { Speed = 96, Archetype = "" }, -- Legendary: the fast "bulldog fish": the Shipwrecks' quick one, by its number only
	GalleonWhale = { Speed = 104, Archetype = "Breaker" }, -- Secret: a whale carrying a ship: it rams through whatever is in the way
	-- land 5: Open Blue
	Swordfish = { Speed = 84, Archetype = "Fast" }, -- Rare: one of the fastest fish alive (the small, fast Rare)
	Dolphin = { Speed = 76, Archetype = "Leaper" }, -- Rare: the leaper: small, quick and loved (a trait on a Rare)
	Orca = { Speed = 90, Archetype = "Predator" }, -- Epic: the top hunter: big enough to eat most of what swims by
	MantaRay = { Speed = 78, Archetype = "Leaper" }, -- Epic: a flier: it breaches, and its hop is a long glide
	Helicoprion = { Speed = 92, Archetype = "" }, -- Legendary: the buzz-saw shark: a plain Legendary
	Elasmosaurus = { Speed = 86, Archetype = "" }, -- Legendary: a long-necked, unhurried paddler: a plain Legendary
	BlueWhale = { Speed = 84, Archetype = "Tank,Breaker" }, -- Mythic: the biggest and the calmest: nothing stops it and the meter crawls; the slowest Mythic by far, which is the trade
	StormSerpent = { Speed = 135, Archetype = "Fast" }, -- Secret: lightning: the launch, and nothing else
	-- land 6: Twilight
	Viperfish = { Speed = 70, Archetype = "" }, -- Rare: a deep ambusher, all teeth: a plain Rare
	GiantSquid = { Speed = 86, Archetype = "Fast" }, -- Epic: jet powered
	GoblinShark = { Speed = 78, Archetype = "" }, -- Epic: its jaws shoot out: a plain Epic
	Liopleurodon = { Speed = 98, Archetype = "Predator" }, -- Legendary: the Twilight's big four-flippered hunter
	Shonisaurus = { Speed = 92, Archetype = "" }, -- Legendary: a whale-sized ichthyosaur with no teeth: a plain Legendary
	LanternLeviathan = { Speed = 108, Archetype = "" }, -- Mythic: a long lit serpent: quick by its number only
	AuroraJelly = { Speed = 96, Archetype = "Tank" }, -- Secret: a drifting jelly: slow for a Secret, and the meter barely moves
	-- land 7: Midnight
	FrilledShark = { Speed = 82, Archetype = "" }, -- Epic: an eel of a shark: a plain Epic
	Anglerfish = { Speed = 74, Archetype = "" }, -- Epic: a lure and a mouth: a plain Epic
	Mosasaurus = { Speed = 110, Archetype = "Predator" }, -- Legendary: the star of the deep: the Midnight's eater
	Livyatan = { Speed = 104, Archetype = "" }, -- Legendary: the killer sperm whale: a plain Legendary
	Basilosaurus = { Speed = 102, Archetype = "" }, -- Legendary: a serpent whale: a plain Legendary
	Kraken = { Speed = 104, Archetype = "Breaker" }, -- Mythic: a mass of arms that drags ships down
	VoidWhale = { Speed = 110, Archetype = "Tank" }, -- Secret: a whale, dark and calm: the meter barely moves
	-- land 8: Vents
	SeaScorpion = { Speed = 84, Archetype = "" }, -- Epic: a paddling hunter with claws: a plain Epic
	GiantIsopod = { Speed = 72, Archetype = "" }, -- Epic: an armoured crawler: a plain Epic
	Megalodon = { Speed = 112, Archetype = "Predator,Frenzy" }, -- Legendary: the biggest shark that ever was: every bite makes the next one bigger
	Kronosaurus = { Speed = 108, Archetype = "" }, -- Legendary: huge jaws, strong flippers: a plain Legendary
	Anomalocaris = { Speed = 96, Archetype = "" }, -- Legendary: the first big hunter, flying on its side flaps: a plain Legendary
	BobbitWorm = { Speed = 90, Archetype = "" }, -- Legendary: bursts out of the sand (not in the herd yet)
	MoltenMegalodon = { Speed = 122, Archetype = "" }, -- Mythic: a Megalodon on fire: faster than the Megalodon, but it doesn't eat
	EmberSerpent = { Speed = 138, Archetype = "Fast" }, -- Secret: a serpent of fire: the fastest fish there is, and the launch
	-- land 9: Bone Graveyard
	WraithEel = { Speed = 114, Archetype = "Fast" }, -- Legendary: a quick ghost
	GraveRay = { Speed = 104, Archetype = "Leaper" }, -- Legendary: a ghostly glider
	SkullAngler = { Speed = 98, Archetype = "" }, -- Legendary: an angler, still: a plain Legendary
	GraveTurtle = { Speed = 92, Archetype = "Tank" }, -- Legendary: a turtle, still
	BoneLeviathan = { Speed = 126, Archetype = "" }, -- Mythic: a racing skeleton: the Graveyard's fastest, by its number only
	HalfboneMegalodon = { Speed = 124, Archetype = "" }, -- Mythic: half a Megalodon: quick by its number, and it doesn't eat
	PhantomWhale = { Speed = 120, Archetype = "Breaker" }, -- Secret: a ghost whale: it goes straight through things
	-- land 10: The Underworld
	HellfinShark = { Speed = 118, Archetype = "Predator" }, -- Legendary: a shark from the Underworld: the last land's eater
	BrimstoneEel = { Speed = 116, Archetype = "" }, -- Legendary: an eel of fire: quick by its number only
	CinderRay = { Speed = 108, Archetype = "Leaper" }, -- Legendary: a burning glider
	InfernalAngler = { Speed = 100, Archetype = "" }, -- Legendary: an angler, still: a plain Legendary
	Hellmaw = { Speed = 130, Archetype = "" }, -- Mythic: the last land's monster: the fastest thing in the Underworld, by its number only
	AbyssalWatcher = { Speed = 112, Archetype = "Tank" }, -- Mythic: it watches; it doesn't hurry
	TheDevourer = { Speed = 128, Archetype = "Predator,Frenzy" }, -- Secret: the end of the list: the one that chains bites down there, so it is not also the fastest (was 150)
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
	-- Breaker (Hugo, 2026-11-18): breaks EVERY prop whatever its size, never slowed and never charged (Props.Slow
	-- and Props.Cost don't apply), knocks a wider hole, and each prop broken gives Oxygen to the ride, and a short push.
	Breaker = {
		Reach = 5, -- added to Props.Reach
		Burst = 1.12, -- its speed, times, after breaking a prop,
		BurstTime = 1, -- for this many seconds
		Oxygen = 0.04, -- of max Oxygen back for each prop broken (small ones too: SmallOxygen)
		SmallOxygen = 0.01, -- for each small prop broken (Props.SmallSize: grass, stones), of max Oxygen
		Cooldown = 1.5, -- seconds between two pushes (the breaking and its Oxygen have none)
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
		Air = 1.2, -- the speed the hop leaves at (Config.hopFrom), times
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

-- Variants: the chance that a spawned fish is one, 0 to 1 (the rarest is rolled first). The fish's "Variant" attribute
-- ("", "Silver", "Gold" or "Rainbow"); the look is Shared/Variants; the speed is Config.Speed's (flat for every fish).
-- (2026-11-13, the user: as the reference's Index, which has Normal, Silver, Golden and Rainbow of every dino in six
-- sizes, 24 in all. The chances are the reference's own, worked out from the Index's "1 in N" under each of the 24
-- (the user's screenshot of the Bronto's): every one of them is a size's chance times a colour's, with Silver 1 in 12,
-- Golden 1 in 50 and Rainbow 1 in 250. Hugo's Gold 0.03 and Rainbow 0.008 until then; there was no Silver.)
Config.Variant = {
	Silver = 1 / 12,
	Gold = 1 / 50,
	Rainbow = 1 / 250,
}

-- Sizes (2026-11-13, the user: the reference's six, on every fish, with its odds). A spawned fish is one of six sizes:
-- its "SizeTier" attribute, and "Size", the number its species' size is times (Config.sizeOf, Config.bodyOf: the
-- model, the seat, the lock, the tag and the herd all read that). Rolled apart from the variant, so there are 24 of
-- every fish. The chances are the reference's own, from the same Index page: Tiny 15%, Normal 55%, Big 20%, Giant 7%,
-- Huge 2.5%, Colossal 0.5% (a Rainbow Colossal: 1 in 50,000, as its Index says).
-- The reference's size also raises what a dino needs (measured 2026-11-09: Tiny x0.8, Big x1.2, Giant x1.5), and no
-- doubt what it earns: Config.SizeWorth holds those numbers (Huge and Colossal were never seen there: 2 and 3 are
-- ours). Since 2026-11-16 SizeWorth is what a fish EARNS in a tank, times (Config.incomeOf). It does not change
-- what a fish needs: whether a bigger fish takes more Oxygen to hold is the user's to decide. How much BIGGER each size is can't be read off the reference: SizeScale is ours, to be
-- judged by eye.
-- (Hugo's size roll of 2026-11-12, 0.8 to 1.4 on a curve and speed with it, was taken out the same day. Size does not
-- change speed here: speed is the next thing to be set.)
Config.SizeOrder = { "Tiny", "Normal", "Big", "Giant", "Huge", "Colossal" }
-- (2026-11-17, "the larger sizes should be slightly rarer": Big 0.2, Giant 0.07, Huge 0.025 and Colossal 0.005 until then)
Config.SizeChance = { Tiny = 0.15, Big = 0.17, Giant = 0.055, Huge = 0.018, Colossal = 0.004 } :: { [string]: number } -- Normal: the rest
-- (0.75, 1, 1.25, 1.5, 1.8, 2.2 at first. The user, the same day: the fish looked too alike, and one or two should
-- come through "with a much grander size". The steps are wider, and a Giant is nearly twice its kind.)
Config.SizeScale = { Tiny = 0.7, Normal = 1, Big = 1.35, Giant = 1.8, Huge = 2.3, Colossal = 3 } :: { [string]: number }
-- No fish is longer or wider than this, whatever its size: the biggest kinds' biggest sizes stop here (a Blue Whale
-- is 101 studs long as it is). A lane's neck is about 120 wide.
-- (Width was 130 for one test: a Colossal Sea Turtle came out 124 wide, wider than the first lands' necks.)
Config.SizeLimit = { Length = 200, Width = 96 }
-- Grand fish (the user, 2026-11-13: "there should be 1 or 2 that come through with a much grander size. And that
-- should be coded for to keep there being variety as you walk through the game"). A grand fish is a Giant, a Huge or
-- a Colossal. Left to the odds alone they are one fish in ten, and whole stretches have none. So the stocking counts
-- them: a new fish in a stretch of lane that has fewer than Least grand fish within Span studs IS one (which of the
-- three: by the three shares here, about as the odds have them), and in a stretch that already has Most, a
-- fish that rolls grand is a Big instead. Everywhere you ride there is one or two in sight and never a crowd of them.
-- (It moves the shares off the reference's: measured over 688 fish with the made-grand shares at 0.6, 0.3 and 0.1,
-- one fish in six was grand, where the odds alone give one in ten, and a Colossal was 1 in 75, where they give 1 in
-- 200. So the made-grand shares lean less to the top now. Fewer Normals pay for it.)
-- (The same day, later: one or two in every 400 studs was too many, and too often a Common. Now one in every 800,
-- and a Common is seldom the one made grand: the stretch waits for a rarer fish.)
Config.Grand = {
	Span = 800, -- studs of lane (FishService looks half of it either way; no more than 960)
	Least = 1,
	Most = 1, -- (2 until the user asked for the large sizes to be rarer: with one near, a fish that rolls grand is a Big)
	Common = 0.15, -- the chance that a Common may be the fish made grand, when a stretch wants one
	Giant = 0.72, -- the made-grand fish's size: shares of the three (the odds alone: 0.7, 0.25, 0.05)
	Huge = 0.24,
	Colossal = 0.04,
}
-- How much of a size's growth a fish of each rarity takes (2026-11-17, the user: "basic fish shouldnt get as big as
-- they are getting"). A Giant is 1.8 times its kind and a Colossal 3 times, for every kind: a Colossal Sergeant Major
-- was 59 studs long. Now a basic fish grows by a share of that step: a Common's Big is 1.18, its Giant 1.4, its
-- Colossal 2; a Legendary still takes the whole step. Tiny is the same for all. (1 for every rarity: as it was.)
Config.SizeGrow = {
	Common = 0.5,
	Uncommon = 0.6,
	Rare = 0.75,
	Epic = 0.9,
	Legendary = 1,
	Mythic = 1,
	Secret = 1,
} :: { [string]: number }
Config.SizeWorth = { Tiny = 0.8, Normal = 1, Big = 1.2, Giant = 1.5, Huge = 2, Colossal = 3 } :: { [string]: number }
-- The sizes' chances by rarity (the user, 2026-11-13, having seen every fish on the reference's odds: big sizes were
-- "over prescribed" on the smaller animals and "should be rarer especially among common folk"; "the fish should tend
-- to cluster around the smaller sizes, larger sizes being rarer but still occurring every now and then"). The chances
-- of Big, Giant, Huge and Colossal are times SizeLarge for the fish's rarity, and Tiny's is times SizeSmall; Normal
-- is the rest. A Common: Tiny 21%, Normal 68.5%, Big 7%, Giant 2.5%, Huge 0.9%, Colossal 0.2%. A Legendary: Tiny
-- 16.5%, Big 14%, Giant 4.9%, Huge 1.75%, Colossal 0.35%. (So the reference's Index numbers, one set for every
-- dino, are no longer ours. The first try left Epic and up on the reference's odds, and the deep lands, which are
-- nearly all Epic and up, still had a grand fish in ten.)
Config.SizeLarge = {
	Common = 0.35,
	Uncommon = 0.5,
	Rare = 0.6,
	Epic = 0.7,
	Legendary = 0.7,
	Mythic = 0.8,
	Secret = 0.8,
} :: { [string]: number }
Config.SizeSmall = {
	Common = 1.4,
	Uncommon = 1.3,
	Rare = 1.2,
	Epic = 1.1,
	Legendary = 1.1,
	Mythic = 1,
	Secret = 1,
} :: { [string]: number }

-- The depth gauge (Hugo, 2026-11-19: "every stud is a meter"): the metres on the land strip, the catch screen, the
-- land intros and your best are how far below the sea's surface you are, one metre a stud. A land's border is the
-- depth of the lane's floor where it starts (Zones). Until 2026-11-19 the gauge showed real-ocean depths spread along
-- the lane (Coral Reef 10 m ... The Underworld 6,000 m, the Challenger Deep 10,935 m at the end): docs/design/the-dive.md.
Config.Depth = {
	SurfaceY = 0, -- the sea's surface (tools/map/greybox.py: y = 0); 0 m
	MetresPerStud = 1,
}

-- How deep a point is on the gauge, in metres (never below 0)
function Config.metresAt(y: number): number
	return math.max(0, (Config.Depth.SurfaceY - y) * Config.Depth.MetresPerStud)
end

-- Oxygen is the riding meter, and it is what the design notes call stamina (Decisions, 2026-11-09 and 2026-11-11).
Config.Oxygen = {
	StartMax = 100, -- max Oxygen before any training
	FreeDrain = 4, -- a second while floating off a fish (not in a hop); our guess, so it can't last forever
	FloatSpeed = 6, -- rising while off a fish
	SwimSpeed = 8, -- floating off a fish you drift forward at this, and A and D turn you (never W and S)
	SurfaceY = -3, -- floating stops here
	WaterY = -4, -- below this, a player on the dock counts as in the water
	-- The unit is seconds on a fish (the user, 2026-11-11): your max Oxygen / the fish's drain (Config.drain). A new
	-- player has 5 s on a Shallows Common (RideTime, below), so you have to go fish to fish.
	Refill = 1, -- of max Oxygen, on landing a hop on another fish. 1: every fish starts with the whole meter, as the reference's ring is the time left on this dino (0.25 until 2026-11-11)
	-- What the HUD and a fish's tag show as needed (Config.required): drain x KeepUp / Refill. With Refill 1 that is
	-- the max Oxygen that gives KeepUp seconds on the fish.
	KeepUp = 2, -- seconds on a fish that count as enough (6 until 2026-11-11, when it was the seconds between landings)
	-- A fish too strong for you (the user, 2026-11-12): a landing is never refused. A fish that needs more than your
	-- max Oxygen (Config.required, where you land on it) empties the whole meter in this many seconds, whatever the
	-- fish, and then throws you off. 0: off (the fish's own drain, as before).
	-- (The user, 2026-11-16, from the reference: "you end up getting around 1 second to hop off and get to the next
	-- one. This allows players to sometimes get further than they can handle but they can't get anything real out of
	-- it." So it is a second, and the hop off it is as free as any other (Jump.StrainLock). It is still never tamed,
	-- so nothing is caught there. It was 0.25 with the hop held back for 0.3: a wall.)
	-- (Hugo, 2026-11-18, task r1: "the ticking also goes way too fast when in the red zone". 1 s was 4 ticks at the
	-- 0.25 s floor; now its ticks keep RedTick, below: 1.5 s is three ticks half a second apart, still nothing to
	-- tame and little more than the reference's second.)
	-- (Hugo, 2026-11-19, task o1 of mission 865072de: the red zone "5-7 ticks from entering it to 0", about 2-3 s:
	-- 2.5, so what is left after the 2/3 break-off goes in RedTicks even ticks, as the red zone on any other fish)
	StrainTime = 2.5,
	-- The low, red part of the meter (Hugo, 2026-11-12: "when the bar turns red"): this share of your max Oxygen and
	-- under. One number for both sides: the ring turns red here (HudController, Rings) and the fish under you turns
	-- angry here (Config.Angry, RideService).
	-- (Hugo, 2026-11-18: "the red zone should be hit at about 1/3 of the total stamina left": 0.3 until then.) The
	-- red zone's mark on the ring goes (Hugo, 2026-11-18, task o1/o2: "remove the red zone indicator"); the angry
	-- mode still starts here. A fish too strong no longer drops the meter to this line: BreakOff, below.
	AngryAt = 1 / 3,
	-- The drain in ticks (Hugo, 2026-11-18: "make the oxygen like this, go down in ticks, the more oxygen you have +
	-- the more oxygen required should be linked to how fast the oxygen drains"). The meter never runs down smoothly:
	-- a piece goes at once now and then (RideService; each told to the client, Ride "OxygenTick"). On a fish the
	-- whole meter lasts the seconds on it (Config.secondsOn): seconds = KeepUp x grow(required) x more(max)
	-- x RideTime x pastCap(max); since task o1 every piece is the same 1 / Ticks of the meter and the seconds only
	-- set the gap between them (Ticks, below).
	--   grow: a fish that needs more is ridden longer, (required / the Shallows Common's)^Grow, at most GrowMost
	--   more: having more than it needs gives a little more time, (max / required)^MaxShare, at most MaxMost (max
	--   counted only up to Cap, below)
	-- So the drain a second grows with your max Oxygen (a trained player no longer sits on a Shallows fish for a
	-- minute) and with what the fish needs. Claude's first numbers, 2026-11-18: a new player on a Shallows Common
	-- 2 s (4 ticks), a land-10 Common at exactly its need about 6 s, a Legendary there about 8.
	-- (Hugo, 2026-11-18: "the Oxygen drain is too fast". RideTime 2.5: every fish lasts 2.5 times as long, so a new
	-- player on a Shallows Common 5 s (10 ticks), a land-10 Common at its need about 15 s, a Legendary there about 20.
	-- It was 1, i.e. the numbers above. Only the seconds on a fish: KeepUp stays 2, so what a fish needs (its tag,
	-- taming, coins) does not change; StrainTime, a fish too strong for you, stays 1 s.)
	RideTime = 2.5, -- times the seconds a full meter lasts on a fish (Config.secondsOn)
	-- Same-size ticks (Hugo, 2026-11-18, task o1: "the fade out ticks should all be the same no matter how much oxygen
	-- you have it should just add an extra bar and then slow down the ticks"). READING (the boss's, not confirmed by
	-- Hugo): every tick takes the same share of the meter, 1 / Ticks of your max, whatever the max and whatever the
	-- fish; more seconds on a fish (Config.secondsOn) means the ticks come further apart, never bigger or more pieces.
	-- So the gap between ticks is secondsOn / Ticks (Config.tickEvery): a new player on a Shallows Common 5 s, 10
	-- ticks half a second apart; a land-10 Legendary at twice its need about 4 s apart. Until then the gap was a fixed
	-- Tick and the piece what the seconds allowed (20 small ones on a 10 s fish).
	-- (Ticks and Tick are set from TickSize, below: one switch)
	Ticks = 10, -- pieces in a full meter
	Tick = 0.5, -- the shortest gap between two ticks, seconds (the white piece's fade fits in it: Kit.RingLook.TickFade, shortened to the gap); 0: the old smooth drain
	-- The red part's calm (Hugo, 2026-11-18, task r1: "the ticking also goes way too fast when in the red zone"). In
	-- the red part (the fish angry: under AngryAt, or a fish too strong) no two ticks come closer than this, seconds.
	-- As under Tick, a longer gap takes a bigger piece (the drain a second x the gap), so the seconds on a fish hold;
	-- the struggle's snap to a thrash (AngryStyles.snapGap) only ever lengthens it further. Claude's pick: 0.5, twice
	-- the 30-tick floor (0.25, "slightly fast"), the o1 ring's own floor, and long enough for the ring's whole fade
	-- (Kit.RingLook.TickFade 0.3) and at least one thrash of most struggles. 0: the red part ticks as the rest.
	-- (0.5 until 2026-11-19; now only where RedTime is 0)
	RedTick = 0.4,
	-- The red zone in even ticks (Hugo, 2026-11-19, task o1: "the red zone shows 5-7 ticks from entering it to 0 ...
	-- about 2-3 s on each fish, with even ticks"). From the tick that takes the meter under the red line (AngryAt, a
	-- Tank's lower) what is left goes in RedTicks equal pieces over RedTime seconds, on every fish (RideService;
	-- Config.redTicks). The seconds on a fish hold: the part above the line drains faster to make room
	-- (Config.drainFor). On a fish so short the red part would be most of it, the red part takes at most RedMost of
	-- its seconds (a new player on a Shallows Common: 2.4 of 5.3 s). A fish too strong ends the same way, after its
	-- break-off (StrainTime). 0: the red part ticks as the rest (RedTick, above).
	RedTime = 2.5,
	RedTicks = 6,
	RedMost = 0.45,
	-- Tick sizes (Hugo, 2026-11-18, task s1: "make the increments smaller there should be way more ticks in a circle,
	-- send different sizes for review"): one number picks a row of TickSizes, the options on
	-- docs/attachments/oxygen-tick-sizes-1.png. The gap is secondsOn / Ticks, so more ticks = faster ticks: a new
	-- player on a Shallows Common has 5.3 s, a land-10 Common at its need 16.5 s. Under Tick (the floor) a fish's
	-- ticks merge into fewer, bigger pieces so its seconds hold (Config.tickOf). Hugo picked 3 (30 ticks), 2026-11-18.
	-- (2026-11-19, task o1: "ticks even SHORTER: smaller, more frequent pieces": 5, 60 ticks with a 0.2 s floor. Above
	-- the red line that is 40 ticks; a new player's Shallows Common ticks a piece of 4.6% of the ring every 0.2 s
	-- (it was 6.6% every 0.35), a land-10 Common at its need 1.7% every 0.35 s (it was 3.3% every 0.55))
	TickSize = 5,
	TickSizes = {
		{ Ticks = 10, Tick = 0.5 }, -- (the o1 ring)
		{ Ticks = 20, Tick = 0.2 },
		{ Ticks = 30, Tick = 0.35 }, -- Hugo picked 30 (2026-11-18: "30 ticks but slightly fast"): a slower floor than the rest; 0.25 -> 0.35 (later that day: "the ticks for riding in general, they should be a little slower")
		{ Ticks = 40, Tick = 0.2 },
		{ Ticks = 60, Tick = 0.2 },
		{ Ticks = 80, Tick = 0.2 },
		{ Ticks = 100, Tick = 0.2 },
	} :: { { Ticks: number, Tick: number } },
	Grow = 0.1,
	GrowMost = 4,
	MaxShare = 0.25, -- twice what the fish needs: 1.19 times the seconds; ten times: 1.78
	MaxMost = 2,
	-- The cap (Hugo, 2026-11-18, task o1: "when hitting 500k oxygen, make sure the claiming is slower and the breathing
	-- tick is consistent ... The higher oxygen should also make the oxygen drain slower by a very marginal amount after
	-- capping out"). READING (the boss's): the meter counts your max Oxygen up to Cap for the ticks (MaxShare's "more"
	-- stops growing there), so from the cap on the breathing tick keeps one steady pace on a fish; past it, more
	-- Oxygen only stretches the seconds on a fish (and so the gap between ticks) by at most PastMost, diminishing:
	-- 1 + PastMost x (1 - Cap / max) (Config.pastCap): +2.5% at 1M, +4.5% at 5M, never +5%. Taming at or past the
	-- cap takes Tame.CapSlow times longer. Your max itself is not capped: what a fish needs (its tag, Strained) is
	-- still against the whole of it.
	Cap = 500000,
	PastMost = 0.05,
	FreeSeconds = 25, -- floating off a fish empties the meter in at most this long (and FreeDrain a second at least)
	-- Mounting a fish too strong for you (it needs more than your max; Hugo, 2026-11-18, task o1: "when hopping on a
	-- dino that doesnt have the right amount of stamina make sure it just instantly breaks off 2/3rds of the stamina
	-- with the same fade out animation"): this share of the Oxygen you land with goes at once, as one piece (told to
	-- the client as a tick, Ride "OxygenTick" ... "Break", so the ring fades it like any other), and what is left
	-- empties in StrainTime. 0: it empties from where it is. (It was RedDrop: a drop to the red zone's line, AngryAt.)
	BreakOff = 2 / 3,
	-- The HUD's big ring holds this much Oxygen; past it each further BarSize is a thin ring round it, the outermost
	-- draining first (Hugo, 2026-11-18, task h1: "will all be handled in the progression setup later"; Kit.RingLook)
	-- (2026-11-19, task o1: past BarSize ONE thin ring round the big one, never more (RingsMost 2, the big ring
	-- counted; Hugo, the same day: "i only want 1 extra oxygen ring"); the meter shared EVENLY between the two, so both
	-- tick at the same pace, and the thin ring empties first, the big ring after: Config.ringsOf. Until then the big
	-- ring and the extra ring emptied together.)
	BarSize = 2000,
	RingsMost = 2,
	DockRadius = 165, -- staying surfaced this close (flat) to the dock's spawn puts you back on it (grey-box 15: the spawn is 144 behind the lane's start and the gate's corners are 161 away, so this is the hub, the gate and the first 21 studs of water in the middle; it was 60 studs of water on grey-box 9; grey-box 4 had 120, v4 520)
	DockWait = 2.5, -- seconds at the surface first, so diving in leaves time to hop
	-- Studio only: when above 0, everyone's max Oxygen, to try the deeper zones before training exists. Workspace's
	-- "TestMaxOxygen" attribute overrides it live (0 turns it off).
	StudioMax = 0,
}
do -- the tick size switch (Oxygen.TickSize)
	local size = Config.Oxygen.TickSizes[Config.Oxygen.TickSize]
	if size then
		Config.Oxygen.Ticks = size.Ticks
		Config.Oxygen.Tick = size.Tick
	end
end

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
	-- (Hugo, 2026-11-18: "make sure fishes need longer to be captured as well, the higher stamina ones should have a
	-- longer time since you ride on them for longer"): Time is for a Shallows Common; a fish that needs more takes
	-- longer, by the same grow as the seconds on it (Oxygen.Grow, GrowMost: Config.tameTime). So a player with
	-- exactly what a fish needs still just tames it, at any depth.
	Grow = 1, -- 1: by Oxygen's grow; 0: Time for every fish
	-- (Hugo, 2026-11-18, task o1: "when hitting 500k oxygen, make sure the claiming is slower"): a rider whose max
	-- Oxygen is at or past Oxygen.Cap tames this many times slower (Claude's number; with RideTime 2.5 a fish held at
	-- its need still lasts 5 / 3 of the tame)
	CapSlow = 1.5,
	Carry = 7, -- the most you carry on one dive (the reference's seven slots); a tame past that is not kept
}

-- The aquarium (the user, 2026-11-16: "catches are for depositing in your aquarium, in which they then earn money").
-- AquariumService; docs/design/aquarium.md. Every number here is Claude's first go.
Config.Aquarium = {
	On = 1, -- 0: no aquariums: a catch is only counted at the dock, as before
	Earning = 7, -- how many of a tank's fish earn at once: the best ones (the reference's pen: 7 active)
	Hold = 60, -- the most fish a tank keeps; past it the poorest are let go
	-- What a fish earns: coins a second for each Oxygen it needs at home (Config.required: its land and rarity), times
	-- its size's worth (Config.SizeWorth) and its colour's. A Shallows Common needs 80: 2 coins a second, the
	-- reference's first dino.
	PerRequired = 0.025,
	Silver = 1.5,
	Gold = 3,
	Rainbow = 10,
	Every = 1, -- seconds between payments
	HomeAtTank = 1, -- 1: a player carrying fish wakes on the dock in front of their own tank; 0: at the dock's spawn
	-- the earning fish, shown swimming in the tank: how many, and how long each is shown (a share of its own length,
	-- between two lengths, so a Tiny shows and a Colossal fits)
	Show = 7,
	ShowShare = 0.7,
	ShowLeast = 7,
	ShowMost = 28,
	SwimPace = 5, -- studs a second round its lap
	SeeFrom = 450, -- a client moves a tank's fish only when its camera is this near
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
	GiantLength = 68, -- (40 until the kinds grew, 2026-11-13: the same kinds but for two Secrets) a fish at least this long (studs) is a giant: the slow heavy fade, whatever its body type
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
	RampTime = 0.4, -- idle to ridden speed, easing out (1.2 until 2026-11-16: on a 2.5-second ride that was half the ride spent getting going; the wild herd swims at 0.7 of the land's pace now, so this is the kick of a landing)
	Surge = 1.25, -- the burst on mount
	SurgeTime = 0.5,
	SlowDownTime = 2, -- back to idle once nobody rides it
	-- You always go forward. The way you go follows the camera (the user, 2026-11-11, after playing Movement v3.1: "when
	-- you move the camera the movement should follow, alongside A and D; that's what makes the reference feel better"):
	-- A and D turn the camera, a drag, a stick or the mouse in the hop turn it too, and the fish, the hop and the float
	-- come round to it. CameraSteer 0 is Movement v3.1's way: only A and D steer, and the view is free of the heading.
	-- CameraSteer 2 (the user, 2026-11-16: the reference's steering reads as a byproduct of plain code, ours as a
	-- rule made on purpose) is the plain way, how any Roblox character moves: the keys mean a direction as the
	-- camera sees it. No key: forward, where the camera looks. A and D: the camera's left and right (KeyAngle off its
	-- look). You turn to face it at LookRate (on a fish) or SteerRate (the hop, floating). The keys never turn the
	-- camera and the camera never pulls. 1 is the way before it: A and D turn you and the view like a wheel, and a look
	-- pulls you round.
	CameraSteer = 2,
	KeyAngle = 90, -- with CameraSteer 2: how far off the camera's look A and D point, degrees. 90: straight to its side (Roblox's own); 45: forward and to the side
	-- The control pass (Hugo, 2026-11-12: "the left right is kinda too slow and clunky, it should be smooth but you
	-- should be able to turn faster and you should be able to steer better"). What made it clunky was three lags one
	-- after the other: the key's own ease, then the way you go chasing the view the key had turned (it trailed a held
	-- turn by 16 degrees and went on turning that far after the key was let go), then the fish's own turn spring. Now
	-- A and D turn the way you go directly, and the view by as much; only a look (a drag, a stick, the mouse in the
	-- hop) is chased. The same in the hop and floating (RideController.steer). Measured by script in Studio, before
	-- and after: A held for a second turns you 129 degrees (was 73); the first 10 degrees take 0.12 s (was 0.30); let
	-- go, you turn 9 degrees more (was 23).
	SteerEase = 12, -- in the hop and floating: how quickly the way you go comes round to a look (higher is snappier; 6 until 2026-11-12)
	SteerRate = 220, -- and never faster than this, degrees a second (140 until 2026-11-12)
	-- On a fish the look pulls more gently, and a key held against it holds your line with the view left on the fish's
	-- side (the user, 2026-11-16: the camera's hold on the turn was too strong). Until then a fish used the two numbers
	-- above. Keep LookRate at or under YawRate, or one key can no longer hold the look off.
	LookEase = 5, -- on a fish: how quickly the way you go comes round to a look (the pull is the gap times this, a second)
	LookRate = 135, -- and never faster than this, degrees a second: a key at full press cancels it exactly
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
	StartleSlow = 1, -- its speed for that moment, as a share of its ridden speed (0.6 until 2026-11-12; 0.8 until 2026-11-16, when the dip was taken out: the user wants a landing to feel faster, and a wild fish is at 0.7 already. Below 1 the dip is back)
	StartleHold = 0.12, -- seconds it stays that slow (0.4 until 2026-11-12; 0.3 until 2026-11-16: with no dip there is nothing to hold, and the view's kick and the speed lines that come when it is over now come with the landing)
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
	-- (The user, 2026-11-16: "we need a bit more air time and be pushed further by the hop off the fish". 0.3 s more air:
	-- FloatTime 1.5 to 1.8, with Window and StopTime up by the same and SpeedHalf kept at the same share of the hop; and
	-- more push: Launch 1.15 to 1.25, HopBoost 24 to 30. Off a 46 fish the hop leaves at 88 (77), the pull-in starts by
	-- itself 1.94 s after the press (1.64), 154 studs on (116); off a 75 fish 124, 2.2 s and 243 studs (110, 1.9, 190).)
	Window = 3.5, -- seconds from leaving the fish in which to grab the next one (3.0 until 2026-11-12, 3.2 until 2026-11-16)
	Warn = 0.8, -- the HUD's timer turns red and pulses for this last part
	-- (the user, 2026-11-11: the reference feels more automatic; match its hop one to one. There the pull-in starts by
	-- itself about 1.7 s after the press, and a second press only brings it sooner.)
	AutoGrab = 2, -- 2: the locked fish pulls you in by itself when the glide ends, or as soon as one is locked in the drop (the reference); 1: only at the window's end; 0: never, you must press (Movement v3.1)
	MinFlight = 0.15, -- before a second press counts as a grab (so one press can't do both)
	-- The wait between fish (Hugo, 2026-11-13: "really small; it must not last the whole landing animation, only the
	-- gap between the moment you land and the moment the landing animation starts"). You land when the pull-in ends
	-- (the touch, on your own machine); the landing animation starts when the server's word comes back (it mounts you
	-- and tells every machine: the fish's dip and reaction, your brace). Until that word you are still held in the
	-- hop, so no hop is possible; from it on you can hop at once, and the hop cuts the landing animation short. Cooldown
	-- is the least that gap is ever counted as, from the touch (not from the mount, as it was): with a quick answer
	-- from the server it is all that is left of the lock. The server asks half of it after its own mount. It was 0.3
	-- from the mount, most of the landing's reaction. The second hook stays shut by HopGuard (below), not by this.
	Cooldown = 0.08, -- seconds from the touch (the pull-in's end) before the next hop; 0.3 from the mount until 2026-11-13
	-- (A fish too strong for you had the old wait until 2026-11-16, longer than its meter took to empty, so it could
	-- not be hopped off. The user, from the reference: you get about a second and may hop on. So it is the plain wait
	-- now, and the fish is a stepping stone that gives you nothing to keep: Oxygen.StrainTime.)
	StrainLock = 0.08, -- seconds from the mount before a hop off a fish too strong for you (0.3 until 2026-11-16)
	InputGap = 0.2, -- seconds between JumpRequest repeats that count as a new press
	-- The shape, from the user's side-on recording (2026-11-10): a quick pop up (about 0.3 s), then a long flat glide
	-- lying face down, sinking hardly at all.
	LaunchTime = 0.4, -- the pop up (0.3 in the reference, whose pop is half as high)
	-- Leaving the fish (Hugo, 2026-11-13, after playing the three-part air: "the horizontal movement shouldn't carry
	-- over fully when jumping off a fish, you should get a slight speed boost (a little less than right now)... the
	-- speed is generally a bit too quick"): the hop leaves at Launch x the speed the fish had THEN (a slowed fish,
	-- startled, angry or just off a wall, gives less) + HopBoost. So off a slow fish you leave a little faster than you
	-- rode, off a fast one a little slower, and a fast fish still gives the faster hop. (Launch was 1.6 and HopBoost 18:
	-- the hop left at about twice the fish's speed.)
	-- (Hugo, 2026-11-14: "The Player gets way too little speed when jumping off a fish, it should feel like youre moving
	-- fast but in like a slowmo mode, still faster than right now". Launch 0.85 to 1.15 and HopBoost 15 to 24: the hop
	-- leaves about 40% faster (49 to 70 off a 40 fish, 78 to 109 off a 74, 132 to 183 off a 138) and goes about twice
	-- as far. The "slow-mo" is only on your own screen (Slow, below): nobody's time is changed.)
	Launch = 0.8, -- the share of the fish's speed the hop keeps (1.25 until 2026-11-17, the user: "we need the jump into the air to not keep as much momentum from the fish you're currently riding"; 1.15 until 2026-11-16, 0.85 until 2026-11-14, 1.6 until 2026-11-13; the reference: about 1.3 to 1.8)
	HopBoost = 20, -- studs a second on top of that: the kick off the fish (30 until 2026-11-17, with Launch; 24 until 2026-11-16, 15 until 2026-11-14, 18 until 2026-11-13)
	-- (the least a hop off a fish leaves at: off one standing still or badly slowed there is still a hop worth having)
	AirShare = 0.6, -- the hop never leaves slower than this share of the fish's own ridden speed, plus BoostFloor
	BoostFloor = 8, -- studs a second (with AirShare, above)
	-- The air's speed is ONE curve with no knee (Hugo, the same note: "the falloff doesn't feel right... it should ramp
	-- off slowly then come to a slow stop in a logarithmic-like way"): Config.hopSpeed. From the speed you leave at it
	-- eases off slowly at first, loses speed fastest about halfway, and runs out in a long gentle tail to a stop:
	--   speed = leaving speed x (1 - u ^ a) ^ SpeedTail, u = time / the stop's time,
	-- with a worked out so that half the speed is gone at SpeedHalf. The stop's time is StopTime, longer off a fast fish
	-- and shorter off a slow one by the same seconds as the glide and the window (airtime by speed, below), and
	-- SpeedHalf in proportion. Until this the speed held for the whole glide and was then lost in 0.35 s (FastKeep,
	-- FastCurve, StallTime, StallShare: gone); before that the boost was gone 0.75 s after the press.
	-- (Hugo, 2026-11-14: "make the falloff impact speed with a later delay". SpeedHalf 1.5 to 2.1: nine tenths of the
	-- speed is still there 1.1 to 1.4 s after leaving (0.5 to 0.7 s before), half of it at 1.9 to 2.4 s; and since the
	-- fall comes in by the speed lost, it comes later too. StopTime, SpeedTail, FallSpeed and SinkCurve are unchanged.)
	SpeedHalf = 2.3, -- (2.1 until 2026-11-16) seconds after leaving at which half the speed is gone (later: fast for longer, then lost quicker; 1.5 until 2026-11-14)
	SpeedTail = 2.5, -- how long and gentle the run-out to the stop is (1: the speed runs straight into the stop; higher: more of it is lost before the tail, which is then longer and softer)
	StopTime = 3.5, -- (3.2 until 2026-11-16) seconds after leaving at which you have stopped (with the airtime by speed added); the last fifth of it is under a tenth of the speed
	StopShare = 0.5, -- the share of the leaving speed still there at the stop and after (0 until 2026-11-17: a real stop, in a sea that now swims at 48 and more. From about 2.3 seconds into a hop you were slower than the herd, and every fish ahead of you was getting away while the window ran on. At 0.5 you ease down to about the herd's pace. The fall is unchanged: it comes in as before. 0: a real stop; a little keeps A and D steering to the end)
	-- The fall is blended in along the same curve (Hugo, earlier the same day: "sink way quicker, like a fall, after
	-- losing speed"; and now with no switch): you fall at FallSpeed x (the share of your speed that is gone) ^
	-- SinkCurve (Config.hopSink). Hardly at all while you are fast, a real fall once the speed has nearly gone.
	FallSpeed = 80, -- the fastest you fall, studs a second, with all the speed gone (90 until the one curve)
	SinkCurve = 3, -- how late the fall comes in: 1 sinks in step with the speed lost; higher stays level longer and falls later (but harder)
	-- Airtime by speed (Hugo, 2026-11-12: "the less speed, the less airtime"): the glide, and the window with it, are
	-- longer off a fast fish and shorter off a slow or slowed one, by the speed the fish had as you left
	-- (Config.airOf; the server counts the same). Fair at the slow end: the glide is never under AirLeast, the lock's
	-- reach is by your speed (GrabRange), and the pull-in still starts by itself when the glide ends. From floating: 0.
	AirSlowSpeed = 20, -- a fish this slow or slower as you leave it: AirSlow seconds on the glide
	AirFastSpeed = 130, -- one this fast or faster: AirFast. In between, in proportion (no change at 75 studs a second)
	AirSlow = 0, -- seconds on Jump.FloatTime (and the window) off the slowest fish (-0.5 until 2026-11-17, the sling's day: with AirFast a faster fish gave a LONGER hop, 2.4 s to the pull-in off a fast one against 2.1 off a common one, the reverse of quick. A fast fish's hop now goes further, not longer)
	AirFast = 0, -- and off the fastest (0.5 until 2026-11-17)
	AirLeast = 0.6, -- the glide is never shorter than this, whatever the numbers above
	FreeLaunch = 60, -- the speed of a hop from floating, with no fish under you (78 until 2026-11-13: the air a bit slower)
	-- The height (2026-11-10, the user: the reference has flat ground, we don't): the hop rises this far above where
	-- you left, or above the locked fish if that is higher, so there is always a swoop down onto the fish. It never
	-- leaves the water; where the water is too shallow for it the herd swims lower (Config.herdTop).
	Apex = 20,
	Ceiling = 3, -- the hop stays this far under the surface line (Oxygen.SurfaceY)
	SeatRoom = 5, -- a rider sits about this far above the middle of a fish: the hop's rise is counted from the seat
	FloatTime = 1.8, -- (1.5 until 2026-11-16: more air) the glide at the top, swimming (the rise's last part; the fall is by the speed lost, above). With LaunchTime it ends 1.9 s after the press, when the pull-in begins by itself: 12% more air than the reference's 1.7 s (1.3 until 2026-11-12, Hugo: a little more airtime)
	FloatRise = 1, -- still rising this much through the glide
	-- The drop is the rest of the window (Window - LaunchTime - FloatTime: 1.3 s): by then most of the speed has gone
	-- and the fall is well under way (above); the pull-in begins by itself as it starts (AutoGrab).
	DropTime = 0, -- (worked out in Config.refresh)
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
	-- The sling (the user, 2026-11-17: "it doesnt feel as snappy, quick, and the selection doesnt feel like it grabs
	-- onto what is proper ... the most smooth sick feeling movement ever"; docs/design/sling.md). The pull-in above
	-- began from the fish's own speed, so a press braked you for its first quarter second, and it eased out onto the
	-- saddle, so you landed slowing. With Sling it keeps your own speed and bends it onto the fish, closing fastest
	-- at the touch, as the reference's does ("no slowing at the end ... then it stops dead on the dino").
	Sling = 1, -- 1: the sling; 0: the pull-in as it was (ReelTime, GrabSpeed, ReelMax, ReelCurve)
	SlingCurve = 2, -- the gap closes as time to this power: a creep, then faster and faster to the touch (the reference's two pull-ins fit 1.5 and 2.5)
	SlingBase = 0.14, -- its time with no gap, seconds,
	SlingSpeed = 170, -- and the gap over this, studs a second,
	SlingMax = 0.5, -- never longer than this (the reference's: 0.33 s over its short gap, 0.47 s over its long one; the old pull-in took up to 0.7)
	SlingCarry = 1, -- the share of your own speed carried into it, dying away to nothing by the touch (0: it starts from a standstill)
	-- Sooner (the same day): the hands-off pull-in waited for the glide to end, 2.1 s after the press off a common
	-- fish and 2.4 off a fast one, where the reference's comes at 1.7. With EarlySling the locked fish pulls you in by
	-- itself as soon as it is near enough, from SlingAfter on. The end of the glide is still the latest.
	EarlySling = 1, -- 1: on; 0: only when the glide ends (AutoGrab 2), as before
	SlingAfter = 0.7, -- not before this, seconds after the press (the pop must be seen)
	SlingNear = 30, -- the locked fish within this many studs ACROSS the water (height not counted: it is the fish under you, as the reference's ring takes the dino under it; a straight-line 38 never came true in a test, as the hop floats 20 to 30 studs over the herd), and within the hook's reach,
	SlingBy = 1.3, -- and whatever the distance, by this many seconds after the press (the reference's comes at 1.7): in a test with the view left alone the lock held fish 50 to 90 studs ahead, which never came under you before the glide's end
	SlingSettle = 0.2, -- either way, only once the lock has been on that fish this long (not one it has only just swung onto). Never the fish you just left: that one only when the glide ends, or by a press
	SlingHoldTurn = 90, -- and not while you are turning the view faster than this, degrees a second: you are still choosing (0: never waits)
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
	-- The hook's reach is by your momentum (Hugo, 2026-11-13: a shorter base, and "more horizontal speed = longer
	-- reach, less = shorter"): Config.reachOf, from GrabNear with no speed across the water to GrabRange at
	-- GrabFullSpeed, in proportion between, read every frame of the hop from the speed you really have (a wall that
	-- slows you shortens it; the fall does not lengthen it). So it is longest as you leave and shrinks all the way
	-- down the curve. The lock (and its ring) only ever takes a fish inside the reach you have right then; the ring
	-- thins out as its fish nears the edge of it (RingEdge). The server counts the same rule from its own clock and the
	-- speed it saw the fish leave at (never from what the client says), with Net.RangeSlack and Net.ReachLag for lag.
	-- The numbers are from the herd's spacing, measured again on the partner's new herd and with the slower hop
	-- (docs/playtests/2026-11-13-hop-air-reach.md, "The one curve").
	GrabRange = 95, -- the reach while the hop has most of its speed (GrabFullShare), rider to fish: the longest there is. (105 for an hour of 2026-11-17, then the user: "needs more tolerance on how far it can hook onto now".) (150 until 2026-11-17, the user: "we need a lesser distance to grab onto the next fish when in the air".) 180 at every speed until 2026-11-13
	GrabNear = 55, -- the reach with no speed at all: what is left when you have stopped (and the least there ever is). (45 for the same hour.) (60 until 2026-11-17, with GrabRange)
	GrabFullShare = 0.75, -- the hop has its whole reach while it still has this share of the speed it left with, and less in proportion below that. The reach used to go by a fixed speed (GrabFullSpeed), so every change to how fast fish are, or to how much of their speed a hop keeps, changed the reach as well without anyone meaning it to: with fish 1.6 times faster, the hop keeping 0.8 of their speed and that fixed speed raised to 190, a hop off a 74 fish began with a reach of 70 studs, not the 105 written above, and ended at 45
	GrabFullSpeed = 190, -- (only where the leaving speed isn't known) (120 until 2026-11-17: less bunching: every fish is 1.6 times faster now, so the hop's reach was nearly always at its longest; this puts it back to what it was for a fish of its kind); the speed across the water, studs a second, that gives the whole GrabRange (180 while the hop left at twice the fish's speed)
	AckTime = 1, -- seconds to wait for the server's word on a landing before going back to the hop
	RefusedTime = 0.6, -- a fish the server refused, or that was lost, can't be locked again for this long
	-- The second hook (Hugo, 2026-11-12: "sometimes when you jump onto a fish you are instantly hooked onto ANOTHER
	-- fish"; the cause and the measurements are in docs/design/riding-feel.md, "The second hook").
	RehookGuard = 0.45, -- after a pull-in that was refused or lost, the hands-off pull-in (AutoGrab) waits this long before it may take another fish; a press still grabs at once
	LandWait = 0.5, -- the server gives a landing this long to be seen arriving at the fish before it refuses it (it sees the rider a moment late, most of all after a fast pull-in)
	HopGuard = 0.25, -- Space pressed again DURING a pull-in starts a run of presses that can't hop you off the fish you land on; the run ends at the first gap this long between presses. A hop made on purpose (no press in the pull-in) is untouched. 0: off
	MashMost = 1.5, -- and such a run never holds the hop back longer than this after the landing
	-- A hop pressed a moment too early (the same day): such a press was thrown away, and armed the guard above, so the
	-- next press could be refused too. A press in the second half of a pull-in within Buffer of the touch, or between
	-- the touch and the moment you may hop, is now kept and made the moment you may. Presses early in a pull-in are
	-- still the mash the guard is for.
	Buffer = 0.2, -- seconds (0: dropped, as before)
	Slack = 0.6, -- the server waits this long past the window and the pull-in for the landing (lag)
	LandSlack = 20, -- allows the landing this many studs wider; never widens GrabRange (it sees the player a moment late)
	-- (Hugo, 2026-11-11: the camera felt forced. The view is no longer tilted for you in the hop: it stays where you
	-- have it. Camera.AirRest 1 gives the tilt to CameraPitch back, for as long as you don't move the view.)
	CameraPitch = -30, -- with Camera.AirRest on: where the view rests in the hop, looking down on the herd
	CameraZoom = 1.35, -- how far back the camera sits in the hop, times the riding distance (1.2 until 2026-11-14: pulled back a little more for the slow-mo hop)
	-- The slow-mo look (Hugo, 2026-11-14: "feel like youre moving fast but in like a slowmo mode"). Only on the hopping
	-- player's own screen; the hop's real speed and everyone's clock are untouched (co-op). While most of the leaving
	-- speed is still there: the view held wider, the colours drained a little and the contrast up (a ColorCorrection
	-- under the camera), and a slowed-down, stretched whoosh as you leave. Measured as the share of the leaving speed
	-- still there (Config.hopKept): full above SlowFull, nothing at SlowUntil and under.
	SlowFull = 0.85,
	SlowUntil = 0.45,
	SlowIn = 0.2, -- seconds it takes to come in as you leave
	SlowOut = 0.35, -- and to go once the speed has gone, or at the pull-in (the pull-in has its own zoom)
	SlowFov = 6, -- the view held this much wider (on top of the speed's own widening, Camera.SpeedFov)
	SlowSaturation = -0.22, -- the colours (0: as they are; -1: grey)
	SlowContrast = 0.08,
	SlowTint = rgb(225, 240, 255), -- a faint cold tint (white: none)
	SlowWhoosh = 0.45, -- how loud the stretched whoosh is (0 off),
	SlowWhooshPitch = 0.55, -- how low (the pull-in's is Feel.WhooshPitch 2.2),
	SlowWhooshTime = 1.3, -- and how long, seconds
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
	RingEdge = 0.8, -- the ring thins out as its fish passes this share of the reach you have now, nearly gone at the edge of it (1: never)
	FlyGlow = 0.12, -- how see-through the fish's own glow is in the hop (0.6 until 2026-11-12; the reference's is nearly solid)
	PreviewGlow = 0.85, -- and while you are still on a fish
	GlowFade = 0.3, -- the outline leaves the fish over this, after LandOutline
	LandOutline = 1.5, -- seconds the fish we landed on keeps its black outline, and only the outline: no yellow (the user, 2026-11-17: "when you jump onto a fish the black outline remains from the fish for 1-2 seconds, not the yellow glow. Just the outline". Until then the yellow glow flashed white and faded off in GlowFade)
	FlightTime = 0, -- the longest a hop and its pull-in can last, for the server (worked out in Config.refresh)
}

-- The lock-on. The aim is a thick ray along where the camera looks. Each free fish within Jump.GrabRange
-- gets an allowance: half of Cone, plus the angle AimRadius (and half its own length) covers at its distance, plus
-- FarAim by its distance. Inside its allowance it scores AngleWeight x (how far off the aim) + DistanceWeight x (its
-- distance as a share of the range); the lowest score wins.
-- Hugo, 2026-11-12: the fish you AIM at, far ones as easy to pick as near ones. So being far counts a third of what it
-- did, and a far fish, small on the screen, has a margin round it that counts as on it (FarAim).
-- The hook (HookController; the user, 2026-11-17: "we have the hook mechanic, you can hook onto the next fish, but
-- there's nothing actually doing that ... a harpoon gun or a grappling hook ... something that flails about in the air,
-- something that has very dynamic movements"). A small anchor on a rope in the rider's hand: whirled over the head on
-- a fish, whirled hard in the hop, thrown at the fish as the grab begins, pulled taut for the pull-in. A picture only:
-- nothing here changes the hop, the lock or the grab. Built from plain parts in code, nothing uploaded.
-- The wild ride (the user, 2026-11-17: "making the ride feel proper, like rodeo wild style, because ours is still
-- feeling too tame, even though the speeds is technically correct, the actual feel isn't correct ... really feel
-- more wild, untamed, and interesting, just in the way we manipulate the camera"). Until now a fish was wild for two
-- seconds after a landing and then carried its rider on rails: a still body, a straight line, one speed, a still
-- camera. Amount scales every part of this (0: the ride as it was). In four places:
--   the fish (AnimController): fits while it is ridden, and a bigger beat;
--   the rider (AnimController): one arm up with the rope, the body whipping against the fish's turns;
--   the line and the speed (RideController.drive): it rises, falls and weaves, each beat is a push, a fit checks or
--     bursts the speed;
--   the camera (WildController): a shake for each fit, a loose sway at any riding speed, a roll into turns.
-- The rider being locked to the fish's back is not here: Animation.RiderLock.
Config.Wild = {
	Amount = 1, -- all of it, times (0: off; 2: twice as wild)
	-- the fits: while ridden, the fish throws one of the landing's reactions (a buck, a thrash, a bolt, a wobble, a
	-- shudder, a startle, now and then a barrel roll) again and again. Each client works out the same ones.
	Fits = 1, -- 0: only the landing's own reaction, as before
	FitFirst = 2.6, -- the first comes this long after the landing, seconds,
	FitMin = 2.8, -- and each next one this long after the last began, from
	FitMax = 4.6, -- to
	Fit = 0.75, -- how hard, against the landing's own reaction (Animation.Wild)
	Barrel = 0.3, -- of the barrel rolls drawn, this share are kept (the rest are bucks)
	TameCalm = 0.45, -- your own fish calms by this share as its taming fills: wild when new, steadier when nearly yours
	ByTier = { Common = 0.85, Uncommon = 0.95, Rare = 1.05, Epic = 1.15, Legendary = 1.25, Mythic = 1.3, Secret = 1.35 }, -- the rarer, the wilder
	Body = 1.6, -- a ridden fish's heave, nod, sway and rock each beat, times (Animation.Body is every fish's)
	-- the rider
	Whip = 0.7, -- the rider's body bends against the fish's quick turns by this share of them: the hips are locked to the back, the chest and head are a moment behind (0: stiff)
	WhipEase = 4, -- how quickly the body catches up (lower: it trails longer)
	Rodeo = 1, -- 1: the right arm up, swinging the rope, the left on the fish; 0: both hands down
	RodeoArm = 158, -- how far up, degrees (180: straight up)
	RodeoRate = 0.8, -- the arm circles this many times a second (the hook's own whirl is Hook.RideRate)
	-- the line and the speed (the fish itself moves: the server allows it, Ride.SpeedSlack)
	Porpoise = 3.5, -- its line rises and falls: the nose this far up and down, degrees,
	PorpoiseRate = 0.42, -- this many times a second
	Weave = 2.5, -- and it weaves this far to each side, degrees,
	WeaveRate = 0.27, -- this many times a second
	BeatSurge = 0.035, -- each stroke of the tail is a push: the speed this share up and down
	FitSpeed = 1, -- a fit changes the speed: a bolt gathers (a fifth slower) and lunges (a seventh faster), the others check it by an eighth; 0: not at all
	-- the camera
	Shake = 1, -- each fit's own shake, times (Config.Shake.Presets "Fit...")
	Rumble = 1, -- the loose sway of riding, times ("Ride")
	RumbleFrom = 25, -- it starts at this speed, studs a second,
	RumbleFull = 75, -- and is whole by this
	CamRoll = 4, -- the view leans this far into a full turn, degrees
	CamRollEase = 5, -- how quickly
	BoltFov = 7, -- a bolt kicks the view this much wider, degrees,
	Pull = 0.14, -- and leaves the camera this share further back,
	PullEase = 2.5, -- which it makes up this quickly
	BuckKick = 0.3, -- a buck knocks the view up this far, studs
	BeatKick = 0.03, -- each stroke of the tail knocks it this far (0 off)
	FitBubbles = 10, -- bubbles from the tail at a fit (0 off)
	FitRush = 0.8, -- speed lines at a bolt (0 off)
}

Config.Hook = {
	On = 1, -- 0: no hook at all
	Ride = 1, -- 1: whirled lazily over the head while you ride; 0: put away on a fish, out only in the hop
	-- what it is made of
	Segments = 12, -- cylinders in the rope (more bends smoother and costs a little more)
	Thick = 0.2, -- the rope's thickness, studs (0.45 at first (the user, 2026-11-17: "the model is too bulky and the wire is too bulky ... it flales around in the air too randomly, it should flale but not like a madman"))
	HeadSize = 0.85, -- the anchor's size, times (1: about 2.4 studs long; 1.4 at first, and its pieces were thicker)
	Outline = 1, -- 1: a thin black outline round the anchor, so it reads against the water
	RopeOutline = 0, -- 1: round the rope as well (it was, at first: an outline is as wide on screen however thin the rope, so it was most of the rope's bulk)
	RopeColor = Color3.fromRGB(122, 84, 58), -- (dark, now it has no outline: a pale rope was lost against the pale floors)
	HeadColor = Color3.fromRGB(255, 196, 46),
	HeadDark = Color3.fromRGB(64, 56, 60),
	-- how the rope moves: a chain of points with their own momentum
	Carry = 0.9, -- the rope is carried along with you by this share of your movement; the rest is the water it drags through, so it streams out behind (1: no streaming; 0: it is left behind; 0.8 at first)
	Drag = 5, -- the water takes the rope's own speed away this quickly (higher is calmer, lower whips more; 2.5 at first)
	Sink = 30, -- and it sinks, studs a second gained each second
	Stiff = 9, -- how many times a frame the rope is pulled back to its length (fewer is stretchier; at 5 the hop's rope drew half as long again as its length)
	-- the whirl on a fish
	RideLength = 5.2, -- the rope's length, studs: a little more than from the raised hand to the ring, so it bows without flapping (6.2 with the hand down; 7.5 at first)
	RideRadius = 2.6, -- the ring the anchor goes round, studs across its half (3.4 at first)
	RideRate = 0.8, -- turns a second (1 at first)
	RideLift = 6.5, -- the ring's middle is this far over you, studs (4.5 until the rider's arm went up: Wild.Rodeo)
	-- the whirl in the hop
	HopLength = 8.2, -- (13 at first: half as long again as the ring needed, and all of that spare rope flapped)
	HopRadius = 4.8, -- (7 at first)
	HopRate = 1.6, -- (2.3 at first)
	HopLift = 5,
	Wobble = 0.07, -- the ring breathes in and out by this share, once in about a turn and a half (0: a clean circle; 0.24 at first, and it rocked out of its plane twice a turn as well: that was the madman)
	Tilt = 9, -- the ring's plane is tipped this far, degrees, the tip going slowly round (16 at first)
	HeadSpin = 0.5, -- the anchor rolls about its own length this many times a turn of the whirl (2 at first)
	-- with a fish locked: it winds up
	LockRate = 1.3, -- faster by this (1.4 at first),
	LockRadius = 1.15, -- wider by this,
	LockLean = 24, -- and the ring leans this far toward the fish, degrees
	SpinEase = 5, -- how quickly the whirl changes from one of these to the next (higher is quicker)
	Swish = 0.1, -- a swish each turn in the hop, this loud (0 off)
	-- the throw
	ThrowShare = 0.4, -- the anchor flies to the fish in this share of the pull-in's time (the pull-in creeps at first: Jump.ReelCurve),
	ThrowMin = 0.05, -- never quicker than this, seconds,
	ThrowMost = 0.28, -- nor slower than this
	ThrowArc = 0.07, -- it rises this share of the way on its flight
	ThrowSlack = 1.3, -- the rope is this much longer than the straight line as it leaves (it whips out behind the anchor),
	TautSlack = 1.02, -- and this much once the anchor has bitten (1: dead straight)
	BiteBubbles = 12, -- bubbles where it bites (0 off),
	BiteSound = 1, -- and how loud the tick is, times (0 off)
	Retract = 0.22, -- seconds it takes to come back to the hand's whirl after a landing or a refused grab
}

Config.Lock = {
	Cone = 40, -- full angle round the aim that a far fish must be inside
	AimRadius = 8, -- the aim ray's thickness, studs
	MaxAngle = 80, -- no fish further off the aim than this, however near
	AngleWeight = 1, -- being off the aim
	DistanceWeight = 0.07, -- being far: only close calls go to the nearer fish; 0.07 is a degree and a half of aim over the whole range (0.2 until 2026-11-12, 0.35 before the range went from 85 to 130)
	FarAim = 5, -- degrees round a fish at the full range that count as aimed at it, and that much more allowance (in proportion nearer; 0: a far fish must be aimed at exactly, as before)
	-- The fish you just left swims on right under the middle of the view, so with no penalty it takes nearly every lock.
	LeftPenalty = 2, -- added to its score in the last chance: any other fish in reach wins; with none, a grab takes it back (0.5 until 2026-11-17)
	LeftBack = 1, -- 1: with no other fish to lock, the fish you just left takes the lock, wherever it is round you, so you can hop and hook straight back onto it (the user, 2026-11-17: "its now really hard to hook back onto the previous fish ... a lot of the time you want to hop back onto the same fish to farm the small period of oxygen you have if you have nowhere else to hop"). Any other fish that can be locked takes the lock from it at once; 0: only in the last chance, as before
	LeftBackAfter = 0.4, -- but not in the hop's first moment, seconds: a second press straight after the first doesn't put you back
	LeftBan = 1, -- 1: the fish you just left is not locked at all before the last chance (the user, 2026-11-17: "it still locks onto ur current fish ... too much"); 0: it may be, with LeftPenalty
	Ahead = 8, -- a fish must be this far ahead of you, the way the camera looks across the water, studs: not one under you or behind you (the same day: "or fish near the bottom of ur screen"). Not in the last chance
	AheadLead = 0.6, -- and it is judged where it will be this many seconds on, against you: a slow fish you are about to fly over doesn't count, a fast one coming up from behind does once it will be ahead
	AheadKeep = 25, -- the fish already locked may be this much further back before it is let go, studs
	Assist = 1, -- 1: with no fish under the aim, the lock takes the fish ahead of you nearest to the aim, so there is nearly always a lock while a fish ahead is in reach (2026-11-17: in a thin sea, hops flown without steering the camera found nothing to lock for two seconds and then fell back on the last chance); 0: only a fish you aim at
	AssistAngle = 70, -- and no further off the aim than this, degrees
	AssistPenalty = 1.5, -- added to such a fish's score: any fish that is aimed at beats it
	UpEase = 0.6, -- a fish above the aim counts as this much less off it ("needs to work better for ... ones that are more high up"); 1: up and down alike
	DownHard = 1.8, -- and one below the aim as this much more off it
	Lead = 0.2, -- seconds ahead a fish is aimed at, by its speed against yours ("needs to work better for fish that come by fast"); 0: where it is now
	Linger = 0.45, -- seconds the locked fish keeps the lock after it has left the reach or the aim ("you keep locked onto it for a small window of time to provide slightly more leeway"); 0: it is dropped at once
	LingerReach = 1.12, -- and in that time a grab may take it from this much further than the hook's reach (the server allows Net.RangeSlack)
	-- so the lock doesn't flicker between two fish
	-- 2026-11-11, the user after playing: the lock switched between too many fish too close together. Steadier now:
	-- Sticky 0.2 to 0.35, MinHold 0.3 to 0.45, KeepCone 1.4 to 1.6, and the two new rows below.
	Sticky = 0.35, -- another fish must score this much better to take the lock (with EdgeAim: 0.35 is 7 degrees of aim),
	MinHold = 0.3, -- and never sooner than this after the lock was taken (0.45 until 2026-11-17: "more locked and responsive"),
	KeepCone = 1.6, -- and the locked fish keeps the lock this much further off the aim than it took to win it,
	SwitchTime = 0.1, -- and the better fish must stay the better one this long first (0: at once; 0.15 until 2026-11-17)
	EdgeAim = 1, -- 1: "off the aim" is measured from the fish's nearest edge in degrees (a fish the aim passes through scores 0); 0: from its middle as a share of its own allowance (until 2026-11-11: near fish off to the side took the lock)
	FallbackRadius = 4, -- assumed fish radius if its type has not replicated
	-- The last chance (2026-11-13, with the reach that shrinks: Hugo's standing rule, a hop must still be able to
	-- reach a fish that is near). Once the fast part of a hop is over the lock takes any fish inside the reach you
	-- still have, all round, the one nearest the aim first (so a fish you do aim at still wins, and the fish you left
	-- comes last: LeftPenalty); hands off, the pull-in then takes it. You are about to sink: a fish off to the side
	-- or behind is better than none. Off a slow fish that is often the fish you left, still close behind; a fast
	-- hop has outrun it.
	LastChance = 1, -- 1: on; 0: off (only a fish you aim at, to the end)
	-- (0 since 2026-11-12: in the reference nothing is marked while you ride, with dinos all round; the mark comes on
	-- once you are in the air)
	Preview = 0, -- 1: the lock shows (a fainter glow) while you ride or float, so you see what you could reach; 0: only after leaving
}

-- Wild fish swim as a herd: all the same way, down the lane, at this share of the speed they are ridden at (the
-- reference: riding about 55 m a second, the herd about 46, measured off its distance counter)
Config.Herd = {
	-- The herd's pace, as a share of the land's ride pace (Config.LandPace). 0.85 of each fish's own ridden speed until
	-- 2026-11-16: slower now, so more of the herd goes past a rider and a landing takes the fish from this to its full
	-- speed under you.
	SpeedShare = 0.7,
	Ahead = 60, -- each fish heads for a point this far down the lane, at its own place across it and above the floor
	RideHeight = 12, -- a ridden fish with no dive or climb held settles at this height above the floor: in the herd
	RideHeightGain = 1.6, -- degrees of pitch for each stud it is off that height
	RideHeightPitch = 35, -- at most
	Turn = 2.5, -- how quickly a fish comes round to the way it should be heading (higher is quicker; 1.4 until 2026-11-13)
	-- The herd's own line (2026-11-13, the user: straighter, less minding of obstacles, not all in one line; the study
	-- of the reference's herd is in docs/reference/ride-a-dino.md, the build in src/server/Lib/Stream.luau). The lane's
	-- middle wanders with every bulge of its walls; the herd swims the lane's middle evened out, in a band worked out
	-- once from the built map. The numbers from here to FloorSmooth are read once, when the server starts.
	Smooth = 240, -- the lane's middle is evened out over about this many studs each way: only its long bends are left
	SpineRoom = 150, -- the herd's middle line keeps this far from the edges where the water is wide enough (else it takes the water's middle)
	EdgeGap = 12, -- the band stays this far inside where the seabed ends (a terrace or a wall)
	NeckAhead = 96, -- the band starts to narrow this far before the lane does
	BandSmooth = 120, -- and its width and its middle change no quicker than over about this many studs
	FloorAhead = 96, -- a fish is already above a step in the floor this far before it,
	FloorSmooth = 72, -- and the floor's steps are rounded off over about this many studs
	-- The big things standing in the lane (the map's BigAssets, all props that break): a wild fish collides with
	-- nothing, so its line is bent round each one, starting a long way before it. Never a swerve: nothing is decided
	-- as it swims. Until 2026-11-13 each fish looked 150 studs ahead and moved its place across at 45 studs a second.
	DodgeShare = 0.85, -- how much of a thing's circle a fish goes round (the circle is drawn round the whole thing)
	DodgeGap = 4, -- and the water it leaves between its side and that
	DodgeLength = 10, -- the bend starts this many times further ahead than it is wide (higher: gentler, earlier)
	-- (the lengths here and in Spawn's Big* are a fish's own: its species' size times its size's, Config.SizeScale.
	-- Raised 2026-11-13 with the bigger base sizes: 40 and 24 before)
	SmashLength = 80, -- (60 before the second, bigger go at the sizes) a wild fish at least this long goes round nothing: straight through, breaking it (the reference's big dinos)
	-- (the user, 2026-11-13, after the first build, where every fish under SmashLength went round: "some gentle bends,
	-- some straight through")
	StraightShare = 0.4, -- of the shorter fish, this share also go straight through (decided when the fish is made)
	BreakLength = 40, -- (32 before) a wild fish going through a thing breaks it only if it is at least this long (and its kind breaks props at all: Config.breaks, Props.WildBreaks); a smaller one swims through and leaves it whole
	-- Passing: fish swim at their own speeds, so one catches another up. Both give way a little, slowly, and drift
	-- back once past.
	GiveSide = 30, -- (18 until 2026-11-17: less bunching); the water kept between two fish side by side (6 at first: the user wanted the fish further apart; 14; then, with the bigger fish crowding, 18)
	GiveAlong = 64, -- (44 until 2026-11-17: less bunching); they start giving way when this far apart nose to tail (20 at first, then 36)
	GiveRate = 8, -- (5 until 2026-11-17: less bunching); how fast a fish moves aside, studs a second
	GiveEvery = 0.25, -- seconds between looks
	GiveHeight = 24, -- two fish give way to each other when their bodies are within this far of each other in height, studs (2 until 2026-11-17: only fish at one height did, so a slow fish, a fish of the herd and a fast one could sit one over the other: three fish in one place, which is a clump to a rider looking for the next one)
}

-- How a wild fish swims: its pace (the user, 2026-11-13: "we need it to feel like some zoom past, some go slow, some
-- huge predators come in from above and dart past you, some are slow and clunky"). Until then every wild fish swam at
-- Herd.SpeedShare of its own ridden speed and nothing else, so the herd moved as one block. Now each KIND has a
-- character (Config.FishPace), and a wild fish's speed is its own ridden speed times its character's share, times
-- its own little difference (Own), times its size's (Config.SizePace). Only wild fish: a ridden fish goes at its
-- ridden speed as ever. The swim animation needs nothing told: its beat goes by the fish's speed and its swing by
-- how hard it is speeding up, so a burst shows as one (AnimController).
--   Cruise  the herd's pace, Herd.SpeedShare (0.85: the reference's, measured). Most fish.
--   Plod    slow and clunky: a little over half speed, in lurches. You ride past them.
--   Zoom    faster than it is ridden: it comes past you from behind and goes on ahead.
--   Dart    slower than the herd, then a burst of a second or so at half as fast again, every few seconds.
--   Hunt    a big predator. It cruises high over the herd; when a player is near it stoops down into the herd, runs
--           through it at well over its ridden speed, and climbs away again.
--
-- One pace a land, in layers (2026-11-16; measured first: docs/design/herd-revamp.md). A wild fish's speed was a share
-- of its OWN ridden speed, and one land's fish are ridden at 40 to 100: neighbours closed or parted at up to 40 studs
-- a second, so the room a fish was given when it was made was gone in five seconds. Now a wild fish's speed is a share
-- of the LAND's pace (Config.LandPace), the same for every fish of its character, and each character has its own
-- height (Config.Layer): fish in one layer never close on each other, and the layers slide over one another. A
-- fish's own speed is what you get when you ride it. Hunters kept a share of their own speed until 2026-11-17 (now the land's too): they are an
-- event, high over everything.
Config.Pace = {
	Land = 1.5, -- every land's pace, times: the whole herd faster or slower (1 until 2026-11-17: "everything needs to be faster"; the herd's fish still swim at their shares of it)
	LandBlend = 240, -- the pace changes from one land's to the next over this many studs, half each side of the border
	Own = 0, -- each fish is this much faster or slower than its kind, either way (0.06 until 2026-11-16: any difference inside a layer bunches it)
	Ease = 2.6, -- how fast a fish's share of its speed changes, a second (a burst comes on in about a third of a second)
	Send = 1.5, -- a wild fish's speed is sent to the clients again when it has changed this much, studs a second (0.5 before: bursts and lurches would send far more often)
	CruiseSurge = 0.1, -- a fish of the herd swims this much faster and slower than the herd's pace, either way, in a slow beat of its own: it never gains or loses ground, so the layer does not bunch, but no two fish go at quite one speed (0: every fish of the herd at exactly one pace, as from the morning of 2026-11-16, which the user found looked wrong)
	CruiseBeat = 5, -- seconds a surge and its easing take, about (each fish's own is 0.7 to 1.3 of it)
	-- Swift fish (2026-11-17, the user: "needs more variety in speed with more fast fish and some really fast ones").
	-- Until then a fish was fast only if its KIND was (Config.FishPace: few are). Now any fish of the herd may be
	-- born swift: it swims up in the fast layer at the fast ones' pace, and a few of those are bolts, far faster
	-- still. Riding one is faster too, so the fast ones are worth wrangling. Its Swift attribute says how much.
	FastShare = 0.3, -- of the herd's fish, this share are born fast (they swim at Pace.Zoom, in the fast layer). (0.22 at first: measured, 24 in 100 of the herd were, but only 2 of the 58 fish near a rider, since a fast fish soon swims out of sight)
	BoltShare = 0.1, -- and this share are bolts (0.07 at first)
	Bolt = 1.45, -- a bolt's pace, as a share of the land's (the fast ones': Pace.Zoom, 1.3). (1.8 until later on 2026-11-17, the user: "the super fast fish are still too fast. Impossible to grab when theyre that fast". Measured in land 1, whose pace is 69: the herd swims at 48, a common fish is ridden at 66 and its hop leaves at 73; a bolt at 1.8 and FastVary swam at 105 to 143, so it left a hop behind at 32 to 70 studs a second. Now 96 to 105: 23 to 32 faster than the hop. Before that: 2.4 for an hour; the user, 2026-11-17: "some are really darting past insanely quick")
	FastVary = 0.1, -- each fast fish is this much faster or slower than that, either way (0.15 until 2026-11-17: the fastest of them swam at 103 in land 1, as fast as a bolt; now 81 to 99),
	BoltVary = 0.05, -- and each bolt this much (it was FastVary for both: a bolt could come out 15% over an already fast pace)
	FastRide = 1.2, -- a fish born fast is ridden this much faster than its kind,
	BoltRide = 1.5, -- and a bolt this much
	Plod = 0.45, -- (0.58 of its own speed until 2026-11-16)
	PlodLurch = 0.12, -- and this much either way, as it paddles
	PlodBeat = 2.6, -- seconds a lurch
	Zoom = 1.3, -- (1.12 of its own speed until 2026-11-16)
	-- A darter has a place in the herd like any other. It bursts ahead of it, drifts back to it slower than the herd,
	-- and then swims with the herd until its next burst: it never gains or loses ground for good.
	Dart = 0.5, -- drifting back to its place after a burst
	DartBurst = 1.6,
	DartTime = 1, -- seconds a burst lasts
	DartRise = 7, -- and it lifts this far over its place as it bursts, so it goes over the fish ahead of it, not through
	DartEveryMin = 2.5, -- seconds in its place between bursts, from
	DartEveryMax = 6, -- to
	Hunt = 1.05, -- a hunter's pace, as a share of the LAND's pace like every other fish's (the user, 2026-11-17: "some of the fish go quite fast then stop their fast speed randomly usually when passing by a player. Need that to stop. The shark speed is also too fast to catch normally". It was 0.75 of the hunter's own ridden speed: 114 studs a second for the first land's shark after the speed pass, and 243 on its run, against a hop that leaves at 73. Now 72 there)
	HuntRun = 1.05, -- the stoop and the run through the herd: the same pace, so it no longer sprints at a player and drops back once past them (1.6 of its ridden speed until 2026-11-17). It still comes down through the herd and climbs away
	HuntHigh = 46, -- how far over its place in the herd it cruises, studs (and half its own height; never out of the water)
	HuntFall = 42, -- how fast it comes down, studs a second
	HuntClimb = 20, -- and goes back up
	HuntRunTime = 3.5, -- seconds in the herd before it climbs away
	HuntRunMost = 9, -- but with a player just ahead of it, it runs on until it is past them, this long at most
	HuntPast = 60, -- "past": this far ahead of the player, studs
	HuntEveryMin = 8, -- seconds over the herd before it may stoop again, from
	HuntEveryMax = 16, -- to
	HuntRange = 450, -- it stoops only with a player this near
	HuntApart = 900, -- and not while another hunter within this far is in the herd: one at a time
	-- The visit (the user, 2026-11-13: predators are rare where the game starts, by rarity; "some predators can come
	-- past early as a rarer event"). A player in the water with no hunter anywhere in sight is now and then sent one:
	-- a hunter of the land they are in, put in the water high up and well behind them, which stoops at once, runs
	-- past them and swims on. It is a real fish, to be hooked if you can hold it. In the deep lands a hunter is
	-- nearly always in sight, so the visit is a thing of the first lands without a rule saying so.
	VisitEveryMin = 70, -- seconds between a player's visits, from
	VisitEveryMax = 150, -- to
	VisitRetry = 20, -- seconds before the next look when a hunter was already in sight, or there was no room
	VisitBehind = 260, -- how far behind the player it is put in, studs down the lane
	VisitAside = 45, -- and how far to one side of the player's own line it comes past, at most
}
-- A wild fish's speed by its size: the small ones a little quicker, the grand ones heavy
-- (all 1 since 2026-11-16, for the same reason as Pace.Own; they were 1.08, 1, 0.97, 0.92, 0.88, 0.82)
Config.SizePace = { Tiny = 1, Normal = 1, Big = 1, Giant = 1, Huge = 1, Colossal = 1 } :: { [string]: number }
-- Each land's ride pace, studs a second: about what its middling fish is ridden at (Config.FishStats). The herd swims
-- at shares of this (Herd.SpeedShare, Pace.Plod, Pace.Zoom, the darters' bursts). A land past the list has the last.
Config.LandPace = { 46, 55, 60, 65, 82, 90, 100, 104, 112, 116 } :: { number }
-- The water each character keeps to, studs above the floor in open water, from and to: its whole BODY, belly to
-- back, not its middle. The slow ones low, the herd over them, the fast ones over the herd, with clear water between,
-- so the layers slide over each other without touching. A fish too tall for its layer rests on the layer's floor and
-- stands up out of it. A big fish of the herd or of the fast ones still swims higher by its length (Spawn.BigRise);
-- a plodder doesn't, it would rise into the herd. Hunters have the herd's layer and cruise Pace.HuntHigh over it.
-- (Measured 2026-11-16, with the layers set by the fish's middles and 2 studs between them: no two fish of one layer
-- ever overlapped, and every overlap left was a plodder under a fish of the herd.)
Config.Layer = {
	Plod = { 4, 12 },
	Cruise = { 14, 26 },
	Dart = { 14, 26 },
	Zoom = { 30, 42 },
	Hunt = { 14, 26 },
} :: { [string]: { number } }
export type ShakePreset = {
	Move: { number }, -- right, up, forward: studs at full strength
	Turn: { number }, -- nose, side to side, roll: degrees at full strength
	Rate: number, -- trembles a second: slow reads as heavy, quick as sharp
	In: number, -- seconds coming on,
	Hold: number, -- held,
	Out: number, -- and dying away
	Shape: number, -- how it dies: 1 evenly, 2 quick at first with a long tail
	Knock: { number }?, -- a one-way push that swings back: nose (degrees, + is up), roll (degrees), back (studs)
	KnockRate: number?, -- its swings a second
	KnockDamp: number?, -- how fast it settles (1: no swing back at all)
}

-- Camera shakes (2026-11-16, the user: "professional camera shakes"). Until then there was one shake at a time (a new
-- one replaced the old) and one pattern for all. Now any number run together and add up (src/client/Lib/Shake.luau),
-- and each moment has a character of its own: how far it moves the camera and how far it turns it, how fast it
-- trembles, how it comes on and dies away, and a push one way that swings back (a landing dips the nose). The
-- numbers are Claude's first go, to be judged by playing.
-- stylua: ignore
Config.Shake = {
	Amount = 1, -- every shake, times (0: none)
	Touch = 0.7, -- and on a phone, times this again (the same shake looks harder on a small screen held close)
	MostMove = 2.2, -- all the shakes together never move the camera further than this, studs,
	MostTurn = 5, -- or turn it more than this, degrees
	GrandLength = 60, -- landing on a fish at least this long is the heavy landing (LandBig)
	StrainFrom = 0.35, -- the rumble on a fish too strong for you starts at this strength, and reaches 1 as the meter empties
	SpeedFrom = 78, -- the tremble of speed starts at this many studs a second
	SpeedFull = 135, -- and is at its full by this
	PassRange = 75, -- a hunter or a giant going by within this far of you shakes the water,
	PassSpeed = 22, -- if it is this much faster or slower than you, studs a second,
	PassEvery = 5, -- and the same fish not again for this long, seconds
	Presets = {
		-- a landing: a sharp drop that is over in a third of a second, the nose dipping and coming back
		Land = { Move = { 0.5, 0.75, 0.1 }, Turn = { 0.5, 0.3, 1.2 }, Rate = 15, In = 0, Hold = 0.02, Out = 0.36, Shape = 2, Knock = { -1.2, 0, 0.25 }, KnockRate = 3.2, KnockDamp = 0.5 },
		-- on a giant: bigger, slower, longer: weight
		LandBig = { Move = { 0.7, 1.1, 0.2 }, Turn = { 0.9, 0.4, 1.8 }, Rate = 10, In = 0, Hold = 0.05, Out = 0.6, Shape = 2, Knock = { -2.2, 0, 0.5 }, KnockRate = 2.4, KnockDamp = 0.45 },
		-- the hop off: small and quick, the nose flicking up
		Hop = { Move = { 0.1, 0.18, 0.05 }, Turn = { 0.2, 0.1, 0.4 }, Rate = 22, In = 0, Hold = 0, Out = 0.18, Shape = 2, Knock = { 0.9, 0, -0.2 }, KnockRate = 4, KnockDamp = 0.6 },
		-- running into something: hard, thrown back, rolled
		Crash = { Move = { 1, 0.8, 0.4 }, Turn = { 1.3, 1.2, 2.6 }, Rate = 19, In = 0, Hold = 0.04, Out = 0.5, Shape = 2, Knock = { -1.5, 2.2, 0.8 }, KnockRate = 3, KnockDamp = 0.4 },
		-- thrown off a fish: slow and wide, the world turning over
		Thrown = { Move = { 0.6, 0.6, 0.2 }, Turn = { 1.5, 1, 3.5 }, Rate = 9, In = 0, Hold = 0.08, Out = 0.7, Shape = 1.5, Knock = { 2.5, 3, 0.6 }, KnockRate = 2, KnockDamp = 0.35 },
		-- a hunter or a giant going by: a swell that comes on and goes, low and slow
		Pass = { Move = { 0.3, 0.4, 0.05 }, Turn = { 0.35, 0.25, 0.9 }, Rate = 5.5, In = 0.2, Hold = 0.1, Out = 0.8, Shape = 1.5 },
		-- the fish under you becomes yours: one soft lift
		Tame = { Move = { 0.12, 0.2, 0 }, Turn = { 0.2, 0.1, 0.5 }, Rate = 7, In = 0.08, Hold = 0.05, Out = 0.45, Shape = 1.5, Knock = { 0.6, 0, -0.15 }, KnockRate = 2.5, KnockDamp = 0.5 },
		-- rumbles, held for as long as they last (In, Hold and Out are not used): a fish too strong, and top speed
		Strain = { Move = { 0.14, 0.14, 0.03 }, Turn = { 0.3, 0.25, 0.7 }, Rate = 24, In = 0, Hold = 0, Out = 0.2, Shape = 1 },
		Speed = { Move = { 0.035, 0.035, 0 }, Turn = { 0.06, 0.05, 0.14 }, Rate = 28, In = 0, Hold = 0, Out = 0.2, Shape = 1 },
		-- the wild ride (Config.Wild): one for each fit of the fish under you, and the loose sway of riding
		-- a buck: heavy, up and down, the nose thrown up
		FitBuck = { Move = { 0.25, 0.7, 0.1 }, Turn = { 0.9, 0.3, 0.8 }, Rate = 9, In = 0.05, Hold = 0.12, Out = 0.75, Shape = 1.6, Knock = { 2, 0, 0.3 }, KnockRate = 2.2, KnockDamp = 0.4 },
		-- a startle: a quick flinch
		FitStartle = { Move = { 0.3, 0.4, 0.1 }, Turn = { 0.7, 0.5, 1 }, Rate = 16, In = 0, Hold = 0.1, Out = 0.45, Shape = 2, Knock = { 1.1, 1, 0.2 }, KnockRate = 3, KnockDamp = 0.5 },
		-- a thrash: side to side, rolled over to one side and back
		FitThrash = { Move = { 0.7, 0.2, 0.05 }, Turn = { 0.3, 1.1, 1.6 }, Rate = 11, In = 0.05, Hold = 0.3, Out = 0.8, Shape = 1.4, Knock = { 0, 2.4, 0 }, KnockRate = 2.6, KnockDamp = 0.35 },
		-- a bolt: a buzz, thrown back
		FitBolt = { Move = { 0.15, 0.15, 0.5 }, Turn = { 0.4, 0.3, 0.6 }, Rate = 20, In = 0.1, Hold = 0.25, Out = 0.6, Shape = 1.5, Knock = { 0.8, 0, 0.9 }, KnockRate = 2, KnockDamp = 0.5 },
		-- a wobble (and the barrel roll): slow and wide, the world rocking
		FitWobble = { Move = { 0.4, 0.3, 0 }, Turn = { 0.3, 0.4, 2.2 }, Rate = 4.5, In = 0.15, Hold = 0.5, Out = 0.9, Shape = 1.2, Knock = { 0, 3, 0 }, KnockRate = 1.6, KnockDamp = 0.3 },
		-- a shudder: fine and fast
		FitShudder = { Move = { 0.2, 0.25, 0 }, Turn = { 0.4, 0.3, 0.8 }, Rate = 26, In = 0.05, Hold = 0.5, Out = 0.6, Shape = 1.3 },
		-- riding (a rumble, held): slow and loose, like a camera held by hand on something alive
		Ride = { Move = { 0.16, 0.2, 0.04 }, Turn = { 0.3, 0.26, 0.7 }, Rate = 5, In = 0, Hold = 0, Out = 0.3, Shape = 1 },
	} :: { [string]: ShakePreset },
}

-- The trail a fish leaves in the water (2026-11-16): a soft streak from its tail, as long as it is fast, so a fish's
-- speed and its line can be read from behind, and the herd shows as lines going by. On every wild and ridden fish;
-- not on the fish in a tank.
Config.Wake = {
	On = 1, -- 0: none
	Life = 0.8, -- seconds a streak lasts: its length is this times the fish's speed
	Height = 0.55, -- how tall at the tail, as a share of the fish's height (it narrows to a fifth of that)
	See = 0.65, -- how solid at the tail (0 to 1); it fades to nothing along its length (0.25 could not be seen against the bright water)
}
-- Each kind's character (a kind not listed is "Cruise"). Claude's go, by what the animal is: the round and the
-- armoured plod; the streamlined zoom; the small and the jet-propelled dart; and one or two great hunters a land hunt.
-- (The first list had 19 hunters and 23 plodders: the deep lands are nearly all Legendaries, and a quarter of the whole
-- sea was hunting. A hunter is a thing to see, so there are 12 now, and 15 plodders.)
-- stylua: ignore
Config.FishPace = {
	-- land 1
	BlueChromis = "Dart", Clownfish = "Dart", Cuttlefish = "Dart", Boxfish = "Plod", Pufferfish = "Plod", SeaTurtle = "Plod", Seahorse = "Plod",
	Archelon = "Plod", FlyingFish = "Zoom", PearlSerpent = "Zoom", ReefShark = "Hunt",
	-- land 2
	MorayEel = "Dart", Octopus = "Dart", CoralDragon = "Zoom", Dunkleosteus = "Hunt",
	-- land 3
	Garibaldi = "Dart", SeaLion = "Zoom", KelpWyrm = "Zoom", Dakosaurus = "Zoom", GiantSeaBass = "Plod", StellersSeaCow = "Plod", GreatWhite = "Hunt",
	-- land 4
	Barracuda = "Zoom", Xiphactinus = "Zoom", GoliathGrouper = "Plod", GalleonWhale = "Plod", HammerheadShark = "Hunt",
	-- land 5
	Dolphin = "Zoom", Swordfish = "Zoom", StormSerpent = "Zoom", BlueWhale = "Plod", Orca = "Hunt",
	-- land 6
	Viperfish = "Dart", GiantSquid = "Dart", AuroraJelly = "Plod", Liopleurodon = "Hunt",
	-- land 7
	Anglerfish = "Plod", Mosasaurus = "Hunt",
	-- land 8
	GiantIsopod = "Plod", SeaScorpion = "Dart", BobbitWorm = "Dart", EmberSerpent = "Zoom", Megalodon = "Hunt", MoltenMegalodon = "Hunt",
	-- land 9
	GraveTurtle = "Plod", WraithEel = "Dart", HalfboneMegalodon = "Hunt",
	-- land 10
	InfernalAngler = "Plod", BrimstoneEel = "Dart", Hellmaw = "Zoom", HellfinShark = "Hunt", TheDevourer = "Hunt",
} :: { [string]: string }

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
	-- The glide starts before the wall (Hugo, 2026-11-13: "approaching the wall should instantly glide you off before
	-- you hit it"). A wall is seen Look seconds of travel ahead and the way you go is bent onto its line from there,
	-- gently at first and wholly by the time you are Gap from it, so you curve along it and never touch.
	Look = 0.5, -- seconds of travel ahead a wall starts to turn you (0.12 until 2026-11-13, and the turn was made at once)
	Gap = 5, -- the water kept between your side and a wall you ride, studs (your nose, facing it square on)
	Soft = 14, -- how quickly a wall's turn and its share of your speed come on and go (higher is quicker): only a wall that is suddenly there is slowed by this, one seen coming is slower already
	Feelers = 45, -- a ray looks for walls this many degrees to each side of the way you steer, as well as along it
	Band = 1.5, -- you ride the lane's own edge this far inside it, studs
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

-- Props (Hugo, 2026-11-13; before it, 2026-11-11: every fish broke them; the map's Lane/Props: each a Model of loose
-- boxes). Three things, all here:
--   WHO BREAKS, RIDDEN (Hugo, 2026-11-18, Config.propBreak; before it a Tank, a Breaker or a giant broke every prop):
--   by size. Small things (SmallSize: grass, stones) break for any fish and cost nothing; a bigger prop breaks for
--   a fish bigger than it, which is slowed a lot when only just bigger and hardly at all when far bigger (Slow,
--   ClearRatio); a Breaker breaks everything, never slowed, and gets Oxygen for each. A row of Config.FishStats can
--   say otherwise for one fish (Breaks = true: every prop, by the size slow-down; false: only the small ones).
--   WILD FISH still go by Config.breaks (a Tank, a Breaker or a giant: GiantVolume) and Herd.BreakLength.
--   A FISH NO BIGGER THAN THE PROP GOES THROUGH IT: stunned first (Stun), then no slow-down, no Oxygen. So does every
--   rider in the hop and the glide. A prop in your way looks solid until you touch it (a shake, and it turns see-through while you are in
--   it); a prop you pass close by is see-through while it is close; on your own screen only (PropController).
--   BREAKING: the server decides which boxes are out (PropService: the tag "PropOut" on each) and when the prop is
--   back; every player's own machine throws the boxes, fades them and takes them away. Nothing of it is solid. The
--   prop comes back when no player has been within RegenRadius of it for RegenDelay seconds.
Config.Props = {
	-- who breaks, wild (ridden: SmallSize and on, below)
	GiantVolume = 12000, -- a WILD fish whose box is this many cubic studs or more breaks props, archetype or not
	WildBreaks = 1, -- 1: a wild fish that would break props does, when it is inside one and at least Herd.BreakLength long (0: only ridden fish)
	-- what one hit takes out (the server's)
	Reach = 2, -- boxes this near the fish's nose (past its own half width) are knocked
	Topple = 22, -- boxes of the same prop above the lowest one knocked, and this near across, come down with it
	MaxLoose = 60, -- the most boxes one hit knocks loose
	-- the boxes flying (each player's own machine; nothing here is solid or seen by the riding code)
	Throw = 0.7, -- a box leaves with this share of the fish's speed, along its way (each between half of this and all of it)
	Scatter = 22, -- and this fast outward from where it was hit, studs a second (each between a third and all)
	Pop = 10, -- and up to this fast upward
	Drag = 2.2, -- the water takes its speed away this quickly (higher stops sooner)
	Sink = 26, -- and it sinks, studs a second gained each second
	Spin = 320, -- turning this fast at first, degrees a second
	Hang = 0.5, -- seconds a box is in the water before it starts to fade,
	FadeOut = 0.8, -- and seconds it takes to be gone
	MaxDebris = 160, -- the most flying boxes on one screen at once (the rest just vanish)
	DebrisRange = 500, -- a prop broken further than this from your camera only vanishes, studs
	BreakBubbles = 14, -- bubbles where a prop broke (0 off),
	BreakSound = 0.45, -- and how loud its crunch is (0 off)
	-- the prop coming back (the server's; the fade-in is each machine's)
	RegenRadius = 300, -- no player within this many studs of the prop,
	RegenDelay = 3, -- for this many seconds: then it builds itself back
	RegenEvery = 0.5, -- seconds between the server's looks at the broken props
	RebuildTime = 0.6, -- seconds a box takes to fade back in,
	RebuildStagger = 0.5, -- the boxes starting over this long, not all at once
	-- seeing through props (your own screen only; Hugo, 2026-11-13, in place of the fade from 80 studs off: "it should
	-- stay solid and at full opacity until you collide with the block, at which point the camera shakes and the block
	-- goes transparent", and "when you're passing something it goes transparent if it's close to you")
	FadeTo = 0.65, -- how see-through a prop gets: Roblox Transparency (0.65 = 35% solid: Hugo's pick from the sheet, 2026-11-13; 0.8 before; 0 turns all of it off)
	FadeEase = 9, -- how quickly a prop you pass turns see-through, and how quickly any prop comes back (higher is quicker; it never jumps)
	FadeEvery = 0.1, -- seconds between looks for the props round you
	FadeForBreakers = 0, -- 0: on a fish that breaks props they stay solid-looking (something to smash); 1: they turn see-through for it too
	-- in your way: a prop ahead of you that your body would run into stays SOLID until you touch it
	PathWidth = 2, -- "in your way" is ahead of you and within your body's own half width plus this, studs, each side
	PathSlack = 4, -- and it stays "in your way" until it is this much further out (so it can't flicker at the edge)
	-- the touch: the prop turns see-through quickly while you are in it, with a shake, bubbles and a thud
	TouchEase = 26, -- how quickly the prop you ran into turns see-through (FadeEase brings it back)
	TouchSlack = 3, -- you are out of a prop when your body is this clear of it, studs
	Shake = 0.5, -- the camera is thrown this far, studs, touching a prop at ShakeAt (0 no shake; the landing's is Jump.LandShake 0.9)
	ShakeTime = 0.25, -- seconds until it has died away
	ShakeAt = 60, -- the speed that gives exactly Shake, studs a second,
	ShakeBySpeed = 0.4, -- and how much the speed counts (0 not at all; never under half of Shake nor over 1.6 times it)
	ShakeGap = 0.7, -- seconds before the next shake, so a cluster of props doesn't rattle the camera
	ShakeMin = 10, -- a prop smaller than this across its biggest side gives no shake, bubbles or thud, studs (sea grass, small stones; 0: every prop does)
	TouchBubbles = 8, -- bubbles where you ran into it (0 off),
	TouchSound = 0.5, -- and how loud the thud is (0 off)
	-- the stun (the user, 2026-11-17: "when you run into an object as a smaller fish, instead of the object just fading
	-- out as you ride into it, it needs to stunt you for a moment then fade out"). Riding a fish that doesn't break
	-- props, straight into one that is in your way: the fish is stopped against it, the prop stays solid, and only
	-- then does it turn see-through and let you on. Nothing is taken (no Oxygen). Not in the hop, not for a prop you
	-- were already passing beside (that one was see-through before you touched it), not for small things (ShakeMin).
	Stun = 1, -- 1: on; 0: the prop turns see-through at the touch, as before
	StunTime = 0.4, -- seconds you are held against it, the prop solid,
	StunSlow = 0.05, -- at this share of your speed (0: dead still),
	StunRecover = 0.5, -- and seconds your speed takes to come back after that, as the prop turns see-through
	StunShake = 0.9, -- the crash's shake at this strength, in place of the touch's (0: none)
	StunBubbles = 18, -- bubbles where you hit it (the touch's own are TouchBubbles)
	StunSpeed = 12, -- slower than this it is a nudge: no stun, studs a second
	StunGap = 1.5, -- seconds from one stun before the next can happen, so a cluster of props stops you once
	-- beside you: a prop you pass close to, and not in your way, is see-through while it is close
	SideNear = 12, -- this near your body or nearer, studs,
	SideSlack = 6, -- and it comes back once it is this much further (so it can't flicker at the edge)
	ViewNear = 5, -- a prop this near the line from your camera to you is see-through as well (the one you just went through, now between you and the camera); 0 off
	-- the loose boxes of a broken prop: see-through while they are close to you or between you and the camera
	DebrisNear = 12, -- fully (to FadeTo) this near, studs,
	DebrisFar = 30, -- not at all from this far (0: never)
	-- who breaks what, ridden (Hugo, 2026-11-18; Config.propBreak). A size is the cube root of a box's volume, studs:
	-- a fish's after its kind's BaseScale and its rolled size, a prop's from its bounding box (PropService writes it
	-- on the prop as PropSize). Sizes as measured in Studio (2026-11-18, grey-box 15): floor tiles 3-5, stones 4-7,
	-- sea grass 5-9, table coral 15-21, crates 21-35, anchors, bone pillars and fan corals 22-40, boulders, sea stacks,
	-- pillar and brain corals and tube clusters 26-51, coral trees, anemones, reef walls, masts and kelp 37-91, skulls
	-- and ribs 65-77, the hulls 80-91. Fish, at Normal size (times 0.7 Tiny to 3 Colossal): a Blue Chromis 6, a
	-- Clownfish 8, a Sawfish 17, a Reef Shark 23, a Great White 30, a Megalodon 52, a Blue Whale 59.
	SmallSize = 12, -- a prop this size or smaller (grass, stones, tiles) breaks for any ridden fish, and slows it not at all
	-- a bigger prop breaks for a fish bigger than it. How much of its speed it keeps: Slow when only just bigger,
	-- easing up to all of it when ClearRatio times the prop's size or more (by SlowCurve: higher keeps more sooner)
	Slow = 0.5, -- the rider's speed drops to this share for a fish only just bigger (it comes back over Crash.Recover)
	ClearRatio = 2.5, -- this many times the prop's size and the fish isn't slowed at all
	SlowCurve = 1.5,
	Cost = 0.03, -- of max Oxygen for a fish only just bigger; less as it is bigger, none at ClearRatio
	-- a fish no bigger than a prop goes through it (the stun first: Stun above); a Breaker breaks every prop, never
	-- slowed and paid Oxygen for each (Archetype.Breaker)
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
-- Failing (Hugo, 2026-11-18: "add failing that fades out and sends you back to the start, with all the animals
-- collected"): the drown fades to black, you wake at the dock (at your own tank with fish in hand), and every fish
-- tamed on the dive is kept, as if you had swum home (RideService toDock; AquariumService puts them in the tank).
-- The drown is shorter than before (Struggle 2.5, DrownFade 0.7 until 2026-11-18), so the fade is what you see.
local DROWN = { Throw = 0.8, Struggle = 1.4, MissStruggle = 0.6, Weak = 0.9, Still = 0.6, Tail = 0.2 }
Config.Death = {
	On = 1, -- 0: no failing anywhere: out of Oxygen throws you off and leaves you floating with a full meter (the sandbox's NoFail does this in Studio)
	HoldBlack = 0.5, -- seconds the black holds at the dock before it lifts, so the move home isn't seen
	FadeIn = 0.8, -- seconds the black takes to lift
	-- a jump that sank: the sinking was the struggle, so the drown that follows is short
	MissStruggle = DROWN.MissStruggle,
	MissTime = DROWN.MissStruggle + DROWN.Weak + DROWN.Still + DROWN.Tail,
	-- out of Oxygen: thrown off (when on a fish), then drowning
	Throw = DROWN.Throw,
	ThrowBack = 8, -- studs up and back
	Struggle = DROWN.Struggle, -- flailing, a steady stream of bubbles
	Weak = DROWN.Weak, -- the bubbles thin out
	Still = DROWN.Still, -- still and sinking, the last bubble
	DrownFade = 1.2, -- the fade to black, ending with the drown
	DrownTime = DROWN.Throw + DROWN.Struggle + DROWN.Weak + DROWN.Still + DROWN.Tail, -- less Throw when not thrown
}

-- What a fish does when the meter hits 0 under you (Hugo, 2026-11-19, task e1: "as soon as it hits 0 either getting
-- eaten or thrown off. Be creative for fishes and what they would do. Give low-tier fishes just the throwing off").
-- RideService picks the outcome (Config.failOf), holds the rider on the fish in the "Failing" state for its Time,
-- then ends it: End "Throw" throws you off into the drown above (Config.Death), End "Taken" is the fail itself: you are
-- gone (in a mouth, dragged down, pinned) and it fades to the fail screen and the dock. Every client plays it from the
-- Fx "Fail" (Controllers/FailController): the fish's motion, the rider on it, the camera, and a sound hook (Sound: a
-- name in Lib/Fx's placeholders; Hook: the name the partner's real animation and sound will go by). Stand-ins: the
-- fish's root is moved and the rider slid on its saddle, nothing authored yet. Claude's first numbers, not judged in play.
--   Throw  the low tiers' only one: the plain buck, at once (Time 0), you are flung up and back (Death.Throw)
--   Chomp  turns on you: rears up, you tumble into its mouth, it snaps shut and shakes its head (the jaws close the screen)
--   Gulp   an angler's lure flares and draws the eye, then the mouth opens under it and swallows you
--   Wrap   arms close round you and it dives, dragging you down into the dark
--   Roll   a giant rolls over with a heavy splash and bucks you off its back
--   Flip   a ray flips over and you drop off its back
--   Shell  a turtle tucks in and shakes you off its shell
--   Coil   a serpent coils round itself, faster and faster, and flings you out
--   Pin    a crawler dives to the floor and pins you under it
Config.Fail = {
	On = 1, -- 0: every fish throws you off at once (the old out of Oxygen)
	-- these tiers only ever throw you off (Hugo: "give low-tier fishes just the throwing off")
	LowTiers = { Common = true, Uncommon = true } :: { [string]: boolean },
	-- stylua: ignore
	Outcomes = {
		--         seconds held     how it ends       on the fail screen         placeholder sound   for the real ones
		Throw = { Time = 0,   End = "Throw", Text = "",              Sound = "Splash", Hook = "FailThrow" },
		Chomp = { Time = 1.3, End = "Taken", Text = "EATEN!",        Sound = "Chomp",  Hook = "FailChomp" },
		Gulp  = { Time = 1.5, End = "Taken", Text = "GULPED!",       Sound = "Chomp",  Hook = "FailGulp" },
		Wrap  = { Time = 1.4, End = "Taken", Text = "DRAGGED DOWN!", Sound = "Rumble", Hook = "FailWrap" },
		Roll  = { Time = 1.2, End = "Throw", Text = "",              Sound = "Splash", Hook = "FailRoll" },
		Flip  = { Time = 0.9, End = "Throw", Text = "",              Sound = "Splash", Hook = "FailFlip" },
		Shell = { Time = 1.1, End = "Throw", Text = "",              Sound = "Pop",    Hook = "FailShell" },
		Coil  = { Time = 1.3, End = "Throw", Text = "",              Sound = "Rumble", Hook = "FailCoil" },
		Pin   = { Time = 1.3, End = "Taken", Text = "PINNED!",       Sound = "Rumble", Hook = "FailPin" },
	} :: { [string]: { Time: number, End: string, Text: string, Sound: string, Hook: string } },
	-- "Taken": the fade to the fail screen after Time, then black for Tail before the dock
	TakenFade = 0.7,
	TakenTail = 0.2,
	-- by creature first (Rare and up; a Common or Uncommon here is thrown off all the same)
	-- stylua: ignore
	ByCreature = {
		-- the eaters: every Predator (by its archetype, below), and these with the teeth for it
		MorayEel = "Chomp", HammerheadShark = "Chomp", Viperfish = "Chomp", GoblinShark = "Chomp", FrilledShark = "Chomp",
		Dakosaurus = "Chomp", Helicoprion = "Chomp", Livyatan = "Chomp", Kronosaurus = "Chomp", MoltenMegalodon = "Chomp",
		HalfboneMegalodon = "Chomp", BobbitWorm = "Chomp", Hellmaw = "Chomp",
		-- the swallowers: a lure, or a mouth that takes things whole
		Anglerfish = "Gulp", SkullAngler = "Gulp", InfernalAngler = "Gulp", GoliathGrouper = "Gulp", Xiphactinus = "Gulp",
		-- arms
		Kraken = "Wrap", Octopus = "Wrap", GiantSquid = "Wrap", AuroraJelly = "Wrap",
		-- giants and whales
		BlueWhale = "Roll", GalleonWhale = "Roll", VoidWhale = "Roll", PhantomWhale = "Roll", StellersSeaCow = "Roll",
		Shonisaurus = "Roll", GiantSeaBass = "Roll", HumpheadWrasse = "Roll", Dolphin = "Roll", AbyssalWatcher = "Roll",
		Elasmosaurus = "Roll", Swordfish = "Roll", LeopardShark = "Roll",
		-- rays
		MantaRay = "Flip", ElectricRay = "Flip", GraveRay = "Flip", CinderRay = "Flip",
		-- shells
		Archelon = "Shell", GraveTurtle = "Shell",
		-- serpents
		PearlSerpent = "Coil", KelpWyrm = "Coil", StormSerpent = "Coil", LanternLeviathan = "Coil", Basilosaurus = "Coil",
		EmberSerpent = "Coil", WraithEel = "Coil", BrimstoneEel = "Coil", BoneLeviathan = "Coil", CoralDragon = "Coil",
		-- crawlers
		Anomalocaris = "Pin", GiantIsopod = "Pin", SeaScorpion = "Pin",
	} :: { [string]: string },
	-- then by archetype, then a giant (Angry.GiantLength) rolls, then by body type (Shared/RideStyles' names)
	ByArchetype = { Predator = "Chomp" } :: { [string]: string },
	ByStyle = { Snake = "Coil", Glider = "Flip", Crawler = "Pin", Jetter = "Wrap" } :: { [string]: string },
	Default = "Throw",
}

-- The outcome for a fish (Config.Fail): its name. `style`: its body type's name (RideStyles.nameOf), if known.
function Config.failOf(fish: FishType, style: string?): string
	local f = Config.Fail
	if f.On == 0 or f.LowTiers[fish.Tier] then
		return "Throw"
	end
	local kind = f.ByCreature[fish.Id]
	if not kind then
		for name in string.gmatch(fish.Archetype or "", "[^,%s]+") do
			kind = f.ByArchetype[name]
			if kind then
				break
			end
		end
	end
	if not kind and fish.Size.Z >= Config.Angry.GiantLength then
		kind = "Roll"
	end
	if not kind and style then
		kind = f.ByStyle[style]
	end
	kind = kind or f.Default
	return if f.Outcomes[kind] then kind else "Throw"
end

-- The movement sandbox (Studio only; docs/sandbox.md): for play-testing the ride, the jump and the camera. The flags can
-- be switched in its panel (N) while playing.
-- The feel log (Studio only; the user, 2026-11-17: "How can we go about getting you to understand this the best").
-- Every hop is written to the Output as one "[FeelHop]" line: when the lock first took a fish and how often it changed,
-- how the pull-in began and how long it took, the server's answer, every press and what it did. And a black box of the
-- last few seconds: press M and it is written out ("[FeelMark]"), and numbers come up over the fish near you: press the
-- number of the one you WANTED ("[FeelPick]"; 0: none of them). Controllers/FeelLogController; docs/design/sling.md.
Config.FeelLog = {
	On = 1, -- 0: off (it is never on outside Studio)
	BoxTime = 5, -- seconds the black box keeps
	SampleEvery = 0.1, -- seconds between its samples
	PickTime = 6, -- seconds the numbers stay up after a mark
	PickCount = 6, -- how many fish get a number (the nearest; the locked fish always gets one)
}

Config.Sandbox = {
	On = true, -- in Studio, start with the sandbox on
	-- (both off since 2026-11-18, so the ticks and the fail are seen in Studio; N's panel switches them on again)
	NoFail = false, -- a jump that sinks, or a meter that empties, leaves you floating instead of drowning, and floating never sends you to the dock
	EndlessAir = false, -- Oxygen doesn't drain (turn it on to ride anywhere without the drain)
	StartS = 130, -- R puts you back here: studs down the lane from its start, or further down, at the first place
	StartRoom = 34, -- with this much water above the herd, so a jump has room to rise
}

-- The admin panel for playtesting (key P; AdminService, docs/sandbox.md "The admin panel"). Open to everyone in
-- Studio, and in a live server to the place's owner and these user ids. The server checks it on every action.
Config.Admin = {
	Users = {} :: { number }, -- user ids allowed besides the owner
	Owner = 1, -- 1: the place's owner (a user, or a group's owner) is allowed; 0: only the list
	Maxes = { 200, 500, 2000, 4500, 8000 } :: { number }, -- the max Oxygen buttons (past 2000: the extra thin rings)
	Coins = { 1000, 100000 } :: { number }, -- the coin buttons
}

Config.Net = {
	RangeSlack = 1.3, -- the server allows this much more than the hook's reach (1.2 until 2026-11-17: the lock's leeway, Lock.LingerReach, lets a grab reach 1.12 times as far; it sees the player and the fish a moment apart; 1.1 until 2026-11-11: at the faster air speed a grab at the full 130 studs was refused in Studio)
	ReachLag = 0.2, -- and it reads the hop's speed, for that reach, as it was this long before (the reach shrinks as the hop stalls, and the grab's word arrives late)
}

Config.Camera = {
	Fov = 70,
	SpeedFov = 16, -- extra field of view at top riding speed (14 until 2026-11-16)
	SpeedFovFrom = 25, -- speed where it starts (20)
	SpeedFovTo = 90, -- speed where it's full (100: the first land's fish got 4 degrees of it; now about 7)
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
	SurfaceMargin = 3, -- once dived the camera never comes nearer the surface than this, studs,
	-- and it stays under the lit sheet the water hangs below its layers (the surface seen from below, 8.5 under the
	-- surface in tools/map/water_look.luau; read from the map's own part while it is there). Hugo, 2026-11-13: held
	-- 3 under the surface, the camera sat in that band of layers, over the sheet: "stuck on a thin layer of light".
	LightMargin = 1.5, -- the camera stays this far under that sheet, studs
	FloatAbove = 1, -- 1: floating at the surface (off a fish, over that sheet ourselves) the camera stays above the water instead, where it can see us; 0: under the sheet then too
	AirMargin = 1.5, -- and this far above the water, studs
	SurfaceTime = 0.7, -- seconds the camera takes to be brought under (or above) from where it was, setting off and arriving gently
	SurfaceKnee = 4, -- from this far below its line the camera starts giving up its climb, so it meets the line softly (0: it stops dead at it, as until 2026-11-13)
	LightLayer = 8.5, -- how far under WaterTop the sheet's underside is, where the map's water isn't there to ask
	SurfaceTilt = 0.5, -- 0: the view keeps its tilt (we sit high in the picture); 1: it levels out to keep us in the middle
}

-- The look of the light (Shared/Look puts these on Lighting; Controllers/LookController does it live while playing, so
-- each is a row on the N panel; tools/studio/look_install.luau does it in Studio's Edit mode). From the user's lighting
-- tutorial, 2026-11-11 (docs/design/lighting.md): bright, with a cool ambient, a wide bloom, and strong contrast and
-- saturation; then toned down the same day (the user: too blinded by light, textures hard to see). Colours are three numbers, 0 to 255.
Config.Look = {
	On = 1, -- 0: the place's own lighting, untouched (to compare)
	Brightness = 2.8, -- the sun's strength (Roblox's own start is 3; the tutorial's 4 washed the sand and studs out, 2.4 looked washed out to the user, 3 a touch too bright)
	ShadowSoftness = 0.2, -- 0 hard to 1 soft (it was 1: the user's pick A, 2026-11-16; shadows have a shape)
	ClockTime = 14.5, -- the hour: where the sun stands
	Latitude = 0, -- tilts the sun's path
	Exposure = -0.25, -- the whole picture lighter or darker, in stops
	AmbientR = 118, -- the light in shade (indoors, under things); the tutorial's is 124, 155, 184. Nearly grey now:
	AmbientG = 128, -- a blue shade light turned every green to mint and washed the floor's squares out
	AmbientB = 138,
	OutdoorR = 150, -- the light in shade under the open sky; the tutorial's is 157, 178, 255 (as blue as the sky)
	OutdoorG = 158,
	OutdoorB = 170,
	SunR = 215, -- a colour laid on faces turned to the sun (Roblox's ColorShift_Top); 0, 0, 0 is none, as it was until
	SunG = 190, -- 2026-11-16. The tutorials' warm sun, the user's pick A: the floor goes from mint to green and a lit
	SunB = 135, -- wall parts from a shaded one in colour (docs/design/lighting.md, "The look pass"). A paler one: 232, 222, 160
	EnvDiffuse = 0.35, -- how much the sky tints everything (1 laid the sky's blue over every surface)
	EnvSpecular = 0.25, -- how much the sky shows in shiny things (it was 1: pick A; less of the sky's blue in the floor, so a PC and a phone match)
	BloomIntensity = 0.6, -- the glow round bright things: how strong (the tutorial's is 1),
	BloomSize = 48, -- how wide (Roblox's own start is 24, the tutorial's 56),
	BloomThreshold = 2.2, -- and how bright a thing must be to glow (the tutorial's is 2)
	Contrast = 0.25, -- -1 to 1 (the tutorial's is 0.5)
	Saturation = 0.3, -- -1 to 1: how vivid the colours are (the tutorial's is 0.5)
	ColourBrightness = 0, -- -1 to 1, after everything else
	TintR = 245, -- the whole picture is multiplied by this colour (a faint lilac)
	TintG = 234,
	TintB = 255,
	-- The air above the water (2026-11-17, the user: "could we add the fog from ride a dino to an extent ... base fog
	-- as to obscure the far surroundings"). A plain fog, only while the camera is above the surface: under it the
	-- water's own fog takes over. The hub is about 480 across, so it stays clear and what is far fades.
	AirFog = 1, -- 1: a plain fog, which the lowest quality level still draws; 2: an Atmosphere (tried 2026-11-17 for the sky's horizon: at a haze of 2.4 it wiped the clouds out to one flat blue, at 0.6 it left a dark blue band, and its colour can't be made pale); 0: neither
	AirDensity = 0.36, -- (AirFog 2) how thick the air is, 0 to 1
	AirOffset = 0.2, -- (AirFog 2) how much what is far melts into the sky, 0 to 1
	AirHaze = 2.4, -- (AirFog 2) the haze over the sky's horizon, 0 to 10: this is what brings the sky down to the land
	AirFogStart = 180, -- (AirFog 1) studs from the camera where it begins (220 at first; the user: "slightly thicker fog")
	AirFogEnd = 1100, -- (AirFog 1) and where nothing shows through it (1,500 at first)
	AirFogR = 205, -- its colour: a pale sky blue
	AirFogG = 232,
	AirFogB = 255,
	SkyTilt = 14, -- degrees the sky is tipped toward the lane (0: level). The user, 2026-11-17: the skybox "cuts off in a weird way in the distance ... bring that cloud down". The sky's clouds stop well above its own horizon, with a plain band under them; tipped, they sit down on the far land as you look out of the hub. Behind you they rise by as much, where the hub's wall hides it
	Sky = 2, -- which sky of ReplicatedStorage.Skies, in name order: 1 the place's first sky, 2 the Anime Sky (0: whatever Sky is in Lighting)
}

-- How creatures and riders move beyond the keyed swim. First built 2026-11-11 (docs/design/animation-study.md), then
-- worked over with the user in the Swim Lab preview and carried here 2026-11-12: these are that preview's "Lively,
-- balanced" numbers. Every layer is seen only: it turns or shifts joints, never the Root, so the Saddle, the lock and
-- the server's checks are untouched. The numbers by body type are in Shared/RideStyles. A row at 0 turns its layer off.
-- Judged by the user in the preview, not yet in play.
Config.Animation = {
	Beat = 1.2, -- every fish's swim beat, times, on top of what its speed already gives it (the beat rises with speed by itself). The user, 2026-11-17: keep the animations for now and make them go faster. 1: as it was
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
	RiderLock = 1, -- 1: the rider is fixed to the very part of the fish they sit on and goes wherever it goes, at once and in full (the user, 2026-11-17: "the character clips into and out of the fish it isnt fully locked onto it": with RiderCalm they took half the body's turning, late, and none of its keyed swim, so the back moved through them); 0: the old way, by RiderCalm
	RiderCalm = 1, -- (with RiderLock 0) 1: they take the body's shift eased and at half its turning, so they aren't shaken; 0: exactly
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
	Trail = 70, -- bubbles a second left behind us through the pull-in (0 off); not in the glide since 2026-11-14 (Hugo: "remove the trail of balls when gliding")
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
	-- (2026-11-13: 30, from 24. The 1,000 studs are now real studs down the herd's stream, not the lane's own s, which
	-- runs 28% long on grey-box 15: 30 keeps about as many fish in the sea as 24 did.)
	-- (2026-11-13, later, the user: crowded in places. The fish are far bigger now, and the first lands' band is a
	-- third as wide as the deep lands' for the same number of fish. So where the herd's band is narrower than FullBand
	-- a stretch gets fewer, in proportion, down to ThinLeast of this.)
	FullBand = 300, -- a stretch whose band is at least this wide gets all of PerThousand
	ThinLeast = 0.65, -- and the narrowest gets this share of it
	PerThousand = 20, -- (38 until 2026-11-17: less bunching; 28 was tried first and measured: the fish in reach hardly fell); (2026-11-16, later: 44 until the user, seeing the herd begin at the gate: "decrease the spawn rate a bit". Fewer fish in the sea is the only way fewer come in: what comes in is what swims away.)
	-- before that: wild fish per 1,000 studs of lane (doubled 2026-11-10: a jump needs a fish within its flight; 30 until 2026-11-16. The still sea woke as a rider came and bunched up ahead of them, about twice as thick as it was stocked; the flowing sea is as thick near a rider as anywhere, so it is stocked nearer what a rider used to see)
	Min = 20,
	Max = 170, -- per zone (110 until 2026-11-16)
	-- Fish go in every zone along the whole lane that has a roster (a fish type that can turn up there: today zones 1
	-- to 6, the four homes plus two zones of reach); zones with none stay empty until their fish exist. 12 a 1,000 over
	-- zones 1 to 6 makes about 171; all ten zones would make about 290, so the cap sits above that.
	-- (2026-11-11: the whole ten-land lane is 30,000 studs, which wants about 720. At 480 the deep lands took the lot,
	-- the Shallows were left with 11 fish 90 studs apart, and a jump in a deep land found nothing to land on.)
	MaxTotal = 1100, -- (800 until 2026-11-16)
	Slice = 120,
	BoardSlice = 6, -- (5 for one test of 2026-11-17: the first room was empty before the dive); (2 until 2026-11-16: the first room held about four fish; the user: "fish spawn too far away initially". 8 for an hour, then "decrease the spawn rate a bit". docs/design/dive-in.md)
	Wander = 80, -- a fish wanders this far either way along the lane from its home
	TopUpEvery = 2,
	PerTopUp = 14, -- (6 until 2026-11-16: the whole sea flows now, so each land's first stretches are making fish all the time)
	-- The herd keeps to one layer above the lane's floor (2026-11-10, from 10 to 60): the reference's dinos are all on
	-- the ground, and a jump has to find a fish at about its own depth.
	-- (2026-11-10: lowered from 16 to 30, so that even in the shallows there is water above the herd to jump up into)
	-- (2026-11-13, the user: a little more spread in height, and the bigger fish given room to be seen. The layer is
	-- 8 to 20, and a big fish swims above it by its size: the hop already rises over a higher fish and swoops down.)
	HeightMin = 8, -- above the lane's floor
	HeightMax = 20, -- (16 until 2026-11-13)
	HeightFloor = 6, -- in shallow water the herd is pressed down to leave room for a jump, but never lower than this
	BigLength = 26, -- a fish longer than this swims higher than the layer, (16 and 44 before the bigger sizes of 2026-11-13; 20 and 80 between)
	BigFull = 110, -- by its length, up to this long,
	-- Kinds (the user, 2026-11-13: the fish looked too alike; variety is to be kept up all the way down). A new fish's
	-- kind is the least seen nearby of this many draws from its rarity's kinds. The rarities' shares are untouched.
	KindTries = 3,
	LiveReach = 1500, -- the fish of a land swim on out of sight only while a player is in it or within this far of it along the lane; a land nobody is near stands still
	WrapShare = 20, -- "plain" for WrapHome: a fish of an ordinary size and colour whose rarity is at least this share (of 100) of its own land's fish
	WrapHome = 1, -- 1: a plain fish that swims out of its lands, out of sight, comes in again at the start of its own (the same fish, not a new one made); 0: every such fish is taken away and a new one made
	BigRise = 14, -- by up to this much (each fish between 0.4 and 1 of what its length gives)
	Belly = 4, -- and no fish's belly is nearer the floor than this, whatever its size
	RoofGap = 10, -- under a roof (the map's Path c), fish stay this far below it
	-- Where a new fish goes (2026-11-13: balanced, not bunched and not in a line). Of Tries places in its slice of the
	-- lane, the one with the most room round it, counted in the room each fish wants: Space studs and SpaceByLength of
	-- its own length. So a big fish gets clear water round it and small fish fill in between.
	-- (the user, 2026-11-13, after the first build: "separate the fish from each other a bit more, some to the sides".
	-- More tries and more room wanted; the band wider, BandMax, and nearer the lane's edges, Herd.EdgeGap.)
	Tries = 24, -- (14 until 2026-11-17: less bunching: more places tried, so the emptiest is found); (10 at first)
	Space = 56, -- (32 until 2026-11-17: less bunching: each fish wants more clear water round it); (22 at first)
	LiftRoom = 0.5, -- how much a difference in height counts for, when a new fish's room is measured (2 until 2026-11-17: a place right over another fish counted as far from it)
	SpaceByLength = 1.6, -- (1.2 until 2026-11-17: less bunching); (1 at first)
	LaneFill = 0.95, -- fraction of the open water's half width fish use, inside Herd.EdgeGap (0.7 of the lane's whole half width until 2026-11-13; 0.9 at first)
	-- The herd is never wider than this, however wide the lane (2026-11-11: the lane now widens to 980). Spread over a
	-- lane that wide the fish were too far apart to jump between; kept to a band down the middle, a jump finds one in
	-- every land the way it does in the Shallows.
	-- (2026-11-13: 300, from 200. The hook reaches 180 since 2026-11-12, and at 200 the herd read as one line.)
	-- (the same day, the user: some fish to the sides. 400. A rider in the middle still has every fish inside the hook.)
	BandMax = 400,
	StreamRadius = 700, -- fish further than this from every player are parked (out of Workspace, not simulated)
	AppearClear = 160, -- a new fish is put this far from every player when its slice of the lane has such a place
	-- No fish out of nothing (2026-11-16; measured: 56 new fish within 500 studs of a rider in 58 seconds, the nearest
	-- 76 studs away). The whole sea swims on now, in sight or not, so a stretch near a player is filled by the fish
	-- coming down from upstream, and a new fish is made only where nobody can see it. The one place that can't be so
	-- is the lane's very start, where the herd begins: fish come in there at the gate.
	SightClear = 500, -- no fish is made, and none is taken away, within this far along the lane of a player
	EntryAt = 120, -- at the lane's start, in sight, a new fish comes in within this far of its stretch's start (30 until 2026-11-16: every fish came out of one spot at the gate; the user: "fish spawn point needs to be spread out instead of a fixed singular point")
	EntrySlices = 2, -- and in this many of the lane's first stretches (1 until then): with EntryAt 120, anywhere in the first 240 studs
	Window = 2, -- a stretch is short of fish, or over, by the count of itself and this many stretches each side
	OverBy = 0.3, -- that many are over by this share of what they should hold before one is taken away (and at least two)
	SpawnAtDock = true, -- characters spawn at the dock's Spawn marker when there is one
}

-- The dive-in (2026-11-16, the user: "make the dive in feel the best possible ... fish spawn too far away initially",
-- and, asked whether stepping off the start strip should itself be the first hop onto a fish: "Yes, aim for that".
-- docs/design/dive-in.md). Until then you dropped into 46 studs of water with about four fish in the first room, all
-- swimming away at the herd's pace 17 to 40 studs under you, and floated until you found the button. Now the sea
-- gathers at the gate (slower and higher there, picking up to its pace over the first stretch), stepping in is a hop
-- that takes the nearest fish by itself, and nothing sends a player who has not yet ridden back to the dock or
-- drowns them for missing. Every number is Claude's first go: unmeasured and unplayed.
Config.Dive = {
	AutoHop = 1, -- 1: dropping off the dock into the water starts a hop by itself; 0: you float, as before
	HopDelay = 0.15, -- seconds in the water first: the splash, and the server's word that we are in
	Reach = 110, -- that hop's reach, at least, studs: the dive must find a fish, however short the hop's own reach is made (Jump.GrabRange, GrabNear)
	AutoGrab = 1, -- 1: that hop takes the nearest fish in reach by itself; 0: it waits for a press or the glide's end, as any hop
	GrabAfter = 0.5, -- seconds into the hop before it may (the pop is seen first)
	GateShare = 0.5, -- (0.45 until 2026-11-17; 0.6 was tried and left the first room empty); the sea's pace at the gate, as a share of the land's: fish gather there. 1: no gathering
	RampTo = 220, -- and it is back to the whole pace this far down the stream, studs (0: no gathering, no rise)
	Rise = 0, -- at the gate fish swim this much higher than their place in the herd, studs, sinking to it by RampTo (12 until 2026-11-17, the user: "I don't like how far up you are in the first zone after you dive in". The first fish you land on is now down in the herd, 20 to 30 studs under the surface)
	-- The plunge (the same day: "when you first dive in, some VFX, a few bubbles, your camera follows a certain
	-- direction just for the dive in so that it feels and looks better"). As the dive's hop begins:
	Plunge = 10, -- the dive's hop goes down, not up: this much deeper than where it began, studs. An ordinary hop from floating rises Jump.Apex (20), which took the dive back up to the surface: measured, in at 21 studs under, then up to 12 before the pull-in. That was the "far up"
	PlungeTime = 0.6, -- over this long, seconds
	Splash = 46, -- bubbles thrown out where you went in (0: none),
	SplashReach = 13, -- this far, studs,
	SplashSound = 0.7, -- with a splash this loud
	Trail = 1, -- 1: bubbles stream off you all the way down (an ordinary hop leaves none in its glide)
	Shake = 0.8, -- the landing's shake at this strength, as you hit the water (0: none)
	Fov = 9, -- the view kicks this much wider, degrees
	Camera = 1, -- 1: the view turns to look the way you are going, down the lane, and tips down at the fish below; 0: it stays where you had it
	CameraPitch = -34, -- how far down it tips, degrees (a hop rests at Jump.CameraPitch, -30; riding at Camera.RestPitch, -12)
	FirstDockWait = 20, -- seconds floating at the surface by the dock before a player who has not ridden yet this dive is put back on it (Oxygen.DockWait once they have)
	ForgiveMiss = 1, -- 1: a hop from floating that lands on nothing, before the first ride of a dive, leaves you floating; 0: it drowns you as any miss does
}

-- The submarine (Hugo, 2026-11-17: "you should jump in the water start swimming while the submarine swims in and
-- picks you up, then swims really fast to your destination"; docs/design/submarine.md). Bought tier by tier at the hub:
-- tier N carries you to land N + 1 or any land before it. Every number is a first go, unplayed; the prices are guesses.
Config.Sub = {
	On = 1, -- 0: no sub; stepping off the dock is always the dive-in
	Prices = { 2500, 25e3, 250e3, 2e6, 15e6, 150e6, 1e9, 8e9, 50e9 } :: { number }, -- tier 1 (to land 2) .. tier 9 (to land 10)
	Free = 1, -- 1: every sub costs nothing for now (Hugo, 2026-11-18: "let upgrades be free for now"); the price is still shown
	Near = 30, -- the stand's shop works within this many studs of its ring (Dock.Stations.Sub), studs
	Approach = 2.0, -- seconds swimming at the surface while the sub swims in
	Pickup = 1.2, -- the scoop onto its seat
	Speed = 520, -- its top speed down the lane, studs a second
	SpeedUp = 1.2, -- seconds to reach it
	SlowDown = 1.6, -- seconds to slow from it to DropSpeed
	MinRide = 4, -- the run takes at least this long (a slower top speed for a short trip)
	MaxRide = 10, -- and at most this long: a far land is reached at a higher top speed (the reference's flight is about ten seconds, whatever the zone)
	Stock = 6, -- herd fish put in the water just ahead of the drop point before you arrive, so the fling always has fish to hook
	StockAt = 2.5, -- seconds before the drop
	Arrive = 0.8, -- seconds at DropSpeed with "NOW ARRIVING" before the drop
	DropSpeed = 90, -- its speed as it lets you go: the fling's hop leaves at this (Config.hopFrom)
	Drop = 1.0, -- the fling: the nose comes up and you are thrown; with a fish, its swim up beside the sub
	FishIn = 1.4, -- your fish's swim up beside the sub, seconds (it begins during Arrive)
	Kick = 0.6, -- the kick off the sub onto your fish, seconds
	Into = 150, -- you are dropped this far into the land, studs
	Lift = 34, -- the sub runs this high over the floor, studs (kept under the surface)
	Sample = 60, -- the path's points, this far apart, studs
	FishSide = 16, -- your fish swims this far beside the sub, studs
	Under = 17, -- the sub comes up this far under the surface to take you (its seat is 7 over its middle: you swim about 9 under)
	LandSlack = 40, -- the kick's landing: how far from the fish the server still believes us, studs
	Late = 2.5, -- seconds past the drop with no word from the player's machine before the server lets them go itself
	Shake = 1, -- the pick-up's and the kick's shakes, at this strength (0: none)
	Fov = 18, -- the run's view, this much wider at full speed, degrees
	Distance = 30, -- the camera's distance behind the sub on the run, studs
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
		local size = Vector3.new(rig.Size[1], rig.Size[2], rig.Size[3]) * (Config.BaseScale[id] or 1)
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

-- How many times longer a fish that needs `required` is ridden (and tamed) than a Shallows Common: Oxygen.Grow
function Config.grow(required: number): number
	local o = Config.Oxygen
	local base = math.max(Config.required(1, "Common"), 1)
	return math.clamp((math.max(required, base) / base) ^ o.Grow, 1, math.max(o.GrowMost, 1))
end

-- How much longer a fish lasts for a rider past Oxygen.Cap: 1 up to the cap, then 1 + PastMost x (1 - Cap / max),
-- a very marginal, diminishing slowing of the drain (never quite 1 + PastMost)
function Config.pastCap(max: number): number
	local o = Config.Oxygen
	if o.Cap <= 0 or max <= o.Cap then
		return 1
	end
	return 1 + math.max(o.PastMost, 0) * (1 - o.Cap / max)
end

-- Seconds a full meter lasts on a fish of this rarity in land `zone`, for a rider with this max Oxygen (2026-11-18:
-- the ticks; Oxygen.Ticks). KeepUp x grow(required) x a little more for more max (Oxygen.MaxShare, counted only up
-- to Oxygen.Cap) x RideTime x pastCap(max); longer on a Tank.
-- A fish too strong: StrainTime (from what is left after the break-off, Oxygen.BreakOff).
-- (`fish`: with it, the seconds are this fish's own: longer on a Tank)
function Config.secondsOn(zone: number, tier: string, max: number, fish: FishType?): number
	if Config.strained(zone, tier, max) then
		return Config.Oxygen.StrainTime
	end
	local o = Config.Oxygen
	local required = math.max(Config.required(zone, tier), 1)
	local counted = if o.Cap > 0 then math.min(max, o.Cap) else max
	local more = math.clamp((math.max(counted, required) / required) ^ o.MaxShare, 1, math.max(o.MaxMost, 1))
	local seconds = o.KeepUp * Config.grow(required) * more * math.max(o.RideTime, 0.01) * Config.pastCap(max)
	if fish and Config.hasArchetype(fish, "Tank") then
		seconds /= math.max(Config.Archetype.Tank.Drain, 0.01)
	end
	return seconds
end

-- Seconds the red part lasts on a fish whose whole meter lasts `seconds` (Oxygen.RedTime, at most RedMost of them);
-- 0: the red part ticks as the rest
function Config.redSeconds(seconds: number): number
	local o = Config.Oxygen
	if o.RedTime <= 0 then
		return 0
	end
	return math.min(o.RedTime, math.max(o.RedMost, 0.05) * seconds)
end

-- The Oxygen a second a rider with this max loses on this fish in land `zone` (what each tick takes, a second):
-- the whole meter in Config.secondsOn. With Oxygen.RedTime on, this is the drain above the red line: the red part
-- has its own even ticks (Config.redTicks, RideService), and the two together still last Config.secondsOn
function Config.drainFor(zone: number, fish: FishType, max: number): number
	local seconds = math.max(Config.secondsOn(zone, fish.Tier, max, fish), 0.01)
	local red = Config.redSeconds(seconds)
	if red <= 0 or Config.strained(zone, fish.Tier, max) then
		return max / seconds
	end
	-- (above the red line: what is above it in what the red part leaves, Oxygen.RedTime)
	return max * (1 - Config.angryAt(fish)) / math.max(seconds - red, 0.01)
end

-- The red part's ticks: `left` Oxygen in `seconds`, in Oxygen.RedTicks even pieces (fewer if their gap would be under
-- the floor, Oxygen.Tick). Returns the piece and the gap.
function Config.redTicks(left: number, seconds: number): (number, number)
	local o = Config.Oxygen
	seconds = math.max(seconds, 0.01)
	local most = math.max(1, math.floor(seconds / math.max(o.Tick, 0.01) + 1e-6))
	local count = math.clamp(math.floor(o.RedTicks + 0.5), 1, most)
	return math.max(left, 0.001) / count, seconds / count
end

-- How many rings the HUD shows for this max Oxygen (Oxygen.BarSize, RingsMost): 1 up to BarSize, then 2 (the big
-- ring and one thin ring). The meter is shared evenly between them; the outermost empties first.
function Config.ringsOf(max: number): number
	local o = Config.Oxygen
	local size = o.BarSize or 0
	if size <= 0 then
		return 1
	end
	return math.clamp(math.ceil(max / size - 1e-6), 1, math.max(o.RingsMost or 1, 1))
end

-- One tick's piece and the seconds between ticks (Oxygen.Ticks, the reading of 2026-11-18): the piece is always
-- 1 / Ticks of the max; the gap is what the drain a second (`rate`) makes of it. A gap under Oxygen.Tick (the floor,
-- task s1) takes a bigger piece instead, rate x Tick, so the seconds on the fish hold (until s1 the gap was held at the
-- floor and the fish lasted longer; with 10 ticks and the 0.5 floor no fish ever got there)
function Config.tickOf(max: number, rate: number): (number, number)
	local o = Config.Oxygen
	rate = math.max(rate, 0.001)
	local piece = math.max(math.max(max, 0.001) / math.max(o.Ticks, 1), rate * math.max(o.Tick, 0))
	return piece, piece / rate
end

-- The ticks on a fish too strong, after the break-off: `left` Oxygen in StrainTime. With Oxygen.RedTime on, the red
-- part's even ticks (Config.redTicks); else pieces as near 1 / Ticks of the max as the gap (at least Oxygen.Tick, and
-- RedTick) allows. Returns the piece and the gap.
function Config.strainTicks(max: number, left: number): (number, number)
	local o = Config.Oxygen
	if o.RedTime > 0 then
		return Config.redTicks(left, o.StrainTime)
	end
	local least = math.max(o.Tick, o.RedTick, 0.01)
	local most = math.max(1, math.floor(o.StrainTime / least + 1e-6))
	local count = math.clamp(math.floor(left / (math.max(max, 0.001) / math.max(o.Ticks, 1)) + 0.5), 1, most)
	return math.max(left, 0.001) / count, math.max(o.StrainTime, 0.01) / count
end

-- Seconds on this fish to tame it (Config.Tame): Tame.Time, longer for a fish that needs more (Tame.Grow), and
-- Tame.CapSlow times that for a rider at or past Oxygen.Cap (`max`, when known)
function Config.tameTime(zone: number, tier: string, max: number?): number
	local t = Config.Tame
	local time = math.max(t.Time, 0.05)
	if t.Grow ~= 0 then
		time *= Config.grow(Config.required(zone, tier))
	end
	local cap = Config.Oxygen.Cap
	if max and cap > 0 and max >= cap then
		time *= math.max(t.CapSlow, 0.05)
	end
	return time
end

-- Oxygen a second floating off a fish: FreeDrain, or the whole meter in Oxygen.FreeSeconds if that is faster
function Config.freeDrain(max: number): number
	local o = Config.Oxygen
	return math.max(o.FreeDrain, if o.FreeSeconds > 0 then max / o.FreeSeconds else 0)
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

-- The hop as it leaves (Config.Jump): its speed off the fish, the seconds added to Jump.FloatTime, Jump.Window and
-- Jump.StopTime, and what Jump.Apex is times. `had` is the speed the fish had as we left it and `ridden` that
-- fish's own ridden speed (Config.riddenOf); both nil from floating. `fish` nil: its kind isn't known here. The
-- client flies by these and the server counts the hook's reach from the same.
function Config.hopFrom(had: number?, fish: FishType?, ridden: number?): (number, number, number)
	local j = Config.Jump
	if not had then
		return j.FreeLaunch, 0, 1
	end
	if had ~= had then
		had = 0
	end
	-- less than the fish's whole speed, and a kick on top (a slowed fish gives less)
	local launch = (had :: number) * j.Launch + j.HopBoost
	-- but never a hop not worth having, off a fish standing still
	if fish and ridden then
		launch = math.max(launch, j.AirShare * ridden + j.BoostFloor)
	end
	-- off a Leaper: higher, faster, and longer
	local leapApex, leapAir, leapTime = Config.hopOf(fish)
	-- airtime by speed: a longer hop off a fast fish, a shorter one off a slow or slowed one
	return launch * leapAir, leapTime + Config.airOf(had), leapApex
end

-- The share of the hop's leaving speed still there `t` seconds after leaving (Jump.SpeedHalf, SpeedTail, StopTime,
-- StopShare), `extra` the hop's extra seconds (Config.hopFrom). One curve with no knee: it eases off slowly, loses
-- speed fastest about halfway and runs out in a long gentle tail to the stop.
function Config.hopKept(t: number, extra: number): number
	local j = Config.Jump
	local stop = math.max(j.StopTime + extra, 0.2)
	local rest = math.clamp(j.StopShare, 0, 1)
	local u = math.max(t, 0) / stop
	if u >= 1 then
		return rest
	end
	local tail = math.max(j.SpeedTail, 1)
	-- (half the speed gone at SpeedHalf, as far through this hop as it is through one of StopTime; never a curve
	-- that begins with a drop: a is at least 1)
	local half = math.clamp(j.SpeedHalf / math.max(j.StopTime, 0.2), 0.05, 0.95)
	local a = math.max(1, math.log(1 - 0.5 ^ (1 / tail)) / math.log(half))
	return rest + (1 - rest) * (1 - u ^ a) ^ tail
end

-- The hop's speed across the water `t` seconds after leaving: `launch` and `extra` from Config.hopFrom. The client
-- flies by it and the server counts the hook's reach by it.
function Config.hopSpeed(t: number, launch: number, extra: number): number
	return launch * Config.hopKept(t, extra)
end

-- And how far it has fallen `t` seconds after leaving: the fall comes in along the same curve, at Jump.FallSpeed x
-- (the share of the speed that is gone) ^ Jump.SinkCurve, summed here (Simpson's rule: the same answer at any frame
-- rate, and at any moment the hop is picked up again)
function Config.hopSink(t: number, extra: number): number
	if t <= 0 then
		return 0
	end
	local j = Config.Jump
	local curve = math.max(j.SinkCurve, 0.1)
	local rest = math.clamp(j.StopShare, 0, 1)
	local function rate(at: number): number
		local gone = if rest < 1 then (1 - Config.hopKept(at, extra)) / (1 - rest) else 1
		return math.clamp(gone, 0, 1) ^ curve
	end
	-- (past the stop the fall is steady: only the curve itself is summed)
	local stop = math.max(j.StopTime + extra, 0.2)
	local to = math.min(t, stop)
	local n = 24
	local h = to / n
	local sum = rate(0) + rate(to)
	for i = 1, n - 1 do
		sum += rate(i * h) * (if i % 2 == 1 then 4 else 2)
	end
	return math.max(j.FallSpeed, 0) * (sum * h / 3 + (t - to))
end

-- The hook's reach at a speed across the water (Jump.GrabNear, GrabRange, GrabFullSpeed): the client's lock and the
-- server's check both ask this
function Config.reachOf(speed: number?, launch: number?): number
	local j = Config.Jump
	local near = math.min(j.GrabNear, j.GrabRange)
	if not speed or speed ~= speed then
		return near
	end
	-- (`launch`: the speed this hop left with. The reach is whole while GrabFullShare of that is still there, so it
	-- does not move when the fish's speeds or the hop's are tuned. With no launch given: by a fixed speed, as before.)
	if launch and launch == launch and launch > 0 then
		-- (from the share the hop ends on, Jump.StopShare, where the reach is GrabNear, up to GrabFullShare)
		local rest = math.clamp(j.StopShare, 0, 0.95)
		local share = speed / launch
		local u = (share - rest) / math.max(j.GrabFullShare - rest, 0.05)
		return near + (j.GrabRange - near) * math.clamp(u, 0, 1)
	end
	return near + (j.GrabRange - near) * math.clamp(speed / math.max(j.GrabFullSpeed, 1), 0, 1)
end

-- The wall ride (Config.Wall): the share of our speed kept riding a wall we are steered into, by how square on:
-- `into` is 0 along the wall, 1 dead straight in
function Config.wallKeep(into: number): number
	local w = Config.Wall
	return 1 - math.clamp(w.Loss, 0, 1) * math.clamp(into, 0, 1) ^ math.max(w.Curve, 0.1)
end

-- How big a fish is, for the props: its model's box in cubic studs (width x height x length of the species' one base
-- size, from its mesh.json), and whether that makes it a giant (Props.GiantVolume).
-- (The merge of 2026-11-13: FishType.Size is now that box times the kind's Config.BaseScale. The giants were picked
-- on the exported box (docs/design/archetypes.md: 16 kinds break props), so the scale is taken out again here; left
-- in, 13 more kinds would be giants. Neither BaseScale nor a fish's rolled size changes who breaks.)
function Config.volumeOf(fish: FishType): number
	local k = Config.BaseScale[fish.Id] or 1
	return fish.Size.X * fish.Size.Y * fish.Size.Z / (k * k * k)
end

function Config.giant(fish: FishType): boolean
	return Config.volumeOf(fish) >= Config.Props.GiantVolume
end

-- A size, for the props (Props.SmallSize): the cube root of a box's volume, studs. A ridden fish's box is
-- Config.bodyOf (its kind's BaseScale and its rolled size in); a prop's is its bounding box (its PropSize attribute).
function Config.boxSize(box: Vector3): number
	return math.max(box.X * box.Y * box.Z, 0) ^ (1 / 3)
end

-- Whether a ridden fish of size `fish` breaks a prop of size `prop`, and the share of its speed it keeps doing so
-- (Config.Props; Hugo, 2026-11-18). `kind` (the FishType) brings the Breaker archetype and a FishStats Breaks row.
-- The same answer on the server (PropService.hit) and on the rider's own screen (PropController).
function Config.propBreak(kind: FishType, fish: number, prop: number): (boolean, number)
	local p = Config.Props
	if Config.hasArchetype(kind, "Breaker") then
		return true, 1
	end
	if prop <= p.SmallSize then
		return true, 1
	end
	local stat = Config.FishStats[kind.Id]
	local forced = stat and stat.Breaks
	if forced == false or (forced ~= true and fish <= prop) then
		return false, 1
	end
	local clear = math.max(p.ClearRatio, 1.01)
	local near = math.clamp((clear - fish / math.max(prop, 0.01)) / (clear - 1), 0, 1)
	return true, 1 - (1 - math.clamp(p.Slow, 0, 1)) * near ^ math.max(p.SlowCurve, 0.1)
end

-- Whether a WILD fish breaks the props it swims into (FishService; ridden fish go by Config.propBreak): a Tank, a
-- Breaker or a giant; or what its own row of FishStats says (Breaks). The same answer on the server and every client.
function Config.breaks(fish: FishType): boolean
	local stat = Config.FishStats[fish.Id]
	if stat and stat.Breaks ~= nil then
		return stat.Breaks
	end
	return Config.hasArchetype(fish, "Tank") or Config.hasArchetype(fish, "Breaker") or Config.giant(fish)
end

-- A kind's character as a wild fish (Config.FishPace): "Cruise", "Plod", "Zoom", "Dart" or "Hunt"
function Config.paceOf(fish: FishType): string
	local pace = Config.FishPace[fish.Id]
	return if pace == "Plod" or pace == "Zoom" or pace == "Dart" or pace == "Hunt" then pace else "Cruise"
end

-- A spawned fish's variant, from a roll of 0 to 1 (Config.Variant): "", "Silver", "Gold" or "Rainbow"
function Config.rollVariant(roll: number): string
	local v = Config.Variant
	if roll < v.Rainbow then
		return "Rainbow"
	elseif roll < v.Rainbow + v.Gold then
		return "Gold"
	elseif roll < v.Rainbow + v.Gold + v.Silver then
		return "Silver"
	end
	return ""
end

-- A spawned fish's size, from a roll of 0 to 1 (Config.SizeChance; for a fish of a rarity, by Config.SizeLarge and
-- Config.SizeSmall): one of Config.SizeOrder's names
function Config.rollSize(roll: number, rarity: string?): string
	local chance = Config.SizeChance
	local large = if rarity then Config.SizeLarge[rarity] or 1 else 1
	local small = if rarity then Config.SizeSmall[rarity] or 1 else 1
	for _, tier in { "Colossal", "Huge", "Giant", "Big", "Tiny" } do
		roll -= (chance[tier] or 0) * (if tier == "Tiny" then small else large)
		if roll < 0 then
			return tier
		end
	end
	return "Normal"
end

-- What a size is times the species' size (Config.SizeScale). For a fish of a kind: no more than keeps it inside
-- Config.SizeLimit, and never under 1 for a size that is bigger than Normal.
function Config.sizeScale(tier: string, fish: FishType?): number
	local scale = Config.SizeScale[tier] or 1
	if fish and scale > 1 then
		-- (a basic fish takes only a share of a big size's growth: Config.SizeGrow)
		scale = 1 + (scale - 1) * (Config.SizeGrow[fish.Tier] or 1)
		local limit = Config.SizeLimit
		local most = math.min(limit.Length / math.max(fish.Size.Z, 1), limit.Width / math.max(fish.Size.X, 1))
		scale = math.max(1, math.min(scale, most))
	end
	return scale
end

-- What a fish earns in a tank, coins a second (Config.Aquarium): by what it takes to hold at home, its size's worth
-- and its colour's
function Config.incomeOf(fish: FishType, sizeTier: string, variant: string): number
	local a = Config.Aquarium
	local colour = if variant == "Rainbow"
		then a.Rainbow
		elseif variant == "Gold" then a.Gold
		elseif variant == "Silver" then a.Silver
		else 1
	return Config.required(fish.Home, fish.Tier) * a.PerRequired * Config.sizeWorth(sizeTier) * colour
end

-- A number written short: 950, 1.2K, 34M (for signs made on the server; the HUD has its own, Kit.short)
function Config.shortNumber(value: number): string
	local units = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local unit = 1
	while value >= 1000 and unit < #units do
		value /= 1000
		unit += 1
	end
	local text = if value >= 100 or unit == 1 and value == math.floor(value)
		then string.format("%d", math.floor(value + 0.5))
		else string.format("%.1f", value)
	return text .. units[unit]
end

-- Whether a size is a grand one (Config.Grand)
function Config.isGrand(tier: string): boolean
	return tier == "Giant" or tier == "Huge" or tier == "Colossal"
end

-- What a size needs and is worth, times (Config.SizeWorth)

function Config.sizeWorth(tier: string): number
	return Config.SizeWorth[tier] or 1
end

-- One fish's ridden speed: its species' own (Config.FishStats: RiddenSpeed), by its variant (x Speed.Gold or
-- x Speed.Rainbow, the same for every fish)
function Config.speedOf(fish: FishType, variant: string?): number
	local s = Config.Speed
	local speed = fish.RiddenSpeed
	-- (the speed pass's two dials: its distance from its home land's pace stretched, then all of it scaled)
	local middle = Config.LandPace[fish.Home]
	if middle and s.Spread ~= 1 then
		speed = math.max(middle + (speed - middle) * s.Spread, middle * 0.5)
	end
	speed *= s.Ride
	if variant == "Gold" then
		speed *= s.Gold
	elseif variant == "Rainbow" then
		speed *= s.Rainbow
	elseif variant == "Silver" then
		speed *= s.Silver
	end
	return speed
end

-- A fish model's size and variant (its attributes). "Size" is the number its species' size is times; "SizeTier" is
-- the size's name (Config.SizeOrder; "Normal" for a model that has none).
function Config.sizeOf(model: Instance): number
	local size = model:GetAttribute("Size")
	return if type(size) == "number" and size > 0 then size else 1
end

function Config.sizeTierOf(model: Instance): string
	local tier = model:GetAttribute("SizeTier")
	return if type(tier) == "string" and Config.SizeScale[tier] then tier else "Normal"
end

function Config.variantOf(model: Instance): string
	local variant = model:GetAttribute("Variant")
	return if type(variant) == "string" then variant else ""
end

-- A fish model's own ridden speed and its body's size (width, height, length), from its type and its attributes
function Config.riddenOf(model: Instance, fish: FishType): number
	-- (a fish born swift is ridden faster than its kind: its Swift attribute, Config.Pace.FastRide and BoltRide)
	local swift = model:GetAttribute("Swift")
	return Config.speedOf(fish, Config.variantOf(model)) * (if type(swift) == "number" then swift else 1)
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
	-- (the highest any fish swims in open water: the layer's top and a big fish's rise)
	local most = sp.HeightMax + sp.BigRise
	if top >= most then
		return own
	end
	local share = math.clamp((own - sp.HeightMin) / math.max(most - sp.HeightMin, 1), 0, 1)
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
