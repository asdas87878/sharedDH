--!strict
-- Every tuning number for the dive, from docs/design/riding-feel.md (to tune in play). Going fish to fish is Movement
-- v3.1: the hop and glide (the reference's, measured from the user's recordings: docs/reference/ride-a-dino.md) with
-- the lock-on, the window and the spring camera (Jump, Lock, Camera). Going deeper is paid for in Oxygen (ZoneDrain).
-- Speeds in studs a second, times in seconds, angles in degrees.

export type Tier = {
	Idle: number, -- (not used since the herd: a wild fish swims at Herd.SpeedShare of its ridden speed)
	Ridden: number, -- speed once ridden, for a species of base 1 at size 1 (worked out: Speed.Base x TierMult)
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
	RiddenSpeed: number, -- this species at size 1, no variant (worked out: Config.refresh); one fish's own: Config.speedOf
	Size: Vector3, -- width, height, length (it faces -Z), at size 1; one fish's own: Config.bodyOf
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

-- (Ridden is worked out in Config.refresh from Config.Speed.Base and Config.TierMult, below: change it there)
Config.Tiers = {
	Common = { Idle = 14, Ridden = 45, Colour = rgb(200, 200, 200) },
	Uncommon = { Idle = 16, Ridden = 52, Colour = rgb(90, 220, 90) },
	Rare = { Idle = 18, Ridden = 60, Colour = rgb(70, 150, 255) },
	Epic = { Idle = 20, Ridden = 68, Colour = rgb(180, 90, 255) },
	Legendary = { Idle = 22, Ridden = 78, Colour = rgb(255, 190, 40) },
	Mythic = { Idle = 24, Ridden = 90, Colour = rgb(255, 70, 90) },
	Secret = { Idle = 26, Ridden = 100, Colour = rgb(20, 20, 20) },
} :: { [string]: Tier }

-- Speed per fish (Hugo, 2026-11-12): speed = Speed.Base x SpeciesSpeed[species] x TierMult[rarity] x the size's factor
-- x the variant's. Every fish has its own, worked out the same way on the server and on every client from the fish's
-- attributes (Config.speedOf); the server's is the one that counts (the herd, the speed check).
Config.Speed = {
	Base = 45, -- studs a second ridden: a Common of species base 1, size 1, no variant
	-- size barely matters (Hugo, 2026-11-12): the smallest roll (Size.Min) is x1, the biggest (Size.Max) x(1 + SizeBonus),
	-- in a straight line between; a fish is never slowed by being small
	SizeBonus = 0.2,
	Gold = 1.2, -- a Gold fish's speed, times (Hugo, 2026-11-12)
	Rainbow = 1.5, -- a Rainbow's (Hugo, 2026-11-12)
}

-- By rarity: a higher rarity is clearly faster on average. Each step is about 1.15 times the last, which lands on the
-- ridden speeds measured in the game before this (Handoff, 2026-11-12: 60, 68, 78, 90 on a Rare, Epic, Legendary and
-- Mythic; with Base 45 these make 45, 52, 60, 68, 78, 90, 100). The steps (15%) are wider than the whole spread of
-- species inside a rarity (8% either way), so the fastest of one rarity is about level with the slowest of the next.
Config.TierMult = {
	Common = 1,
	Uncommon = 1.16,
	Rare = 1.33,
	Epic = 1.51,
	Legendary = 1.73,
	Mythic = 2,
	Secret = 2.22,
} :: { [string]: number }

-- By species: the cooler, more impressive animal is a little faster inside its rarity, 0.92 to 1.08, with why. A
-- species not listed is 1.
-- stylua: ignore
Config.SpeciesSpeed = {
	-- Common
	BlueChromis = 1.05, -- a small darting schooling fish: the quick Common
	Boxfish = 0.92, -- a rigid box that paddles with tiny fins
	Butterflyfish = 1.0, -- an ordinary reef fish
	Clownfish = 0.97, -- stays by its anemone, a wobbly swimmer
	Pufferfish = 0.92, -- round and slow, the slowest thing in the sea
	SergeantMajor = 1.03, -- a bold, busy damselfish
	YellowTang = 1.02, -- a steady cruiser
	-- Uncommon
	Cuttlefish = 0.96, -- hovers on its skirt
	FlyingFish = 1.08, -- built to burst out of the water
	SeaTurtle = 0.95, -- an unhurried glider
	Stingray = 0.98, -- glides low over the sand
	Angelfish = 0.97, -- tall and showy, not quick
	Lionfish = 0.93, -- drifts with its fins spread
	Parrotfish = 1.0, -- an ordinary grazer
	Garibaldi = 1.0, -- an ordinary kelp fish
	SeaLion = 1.05, -- agile and playful
	Barracuda = 1.08, -- a torpedo: the fastest Uncommon
	-- Rare
	Seahorse = 0.92, -- the slowest swimmer there is
	MorayEel = 0.96, -- a lurker in holes
	Octopus = 0.95, -- jets in pulses
	GiantSeaBass = 0.95, -- a heavy, slow giant
	LeopardShark = 1.0, -- a small, ordinary shark
	HammerheadShark = 1.04, -- a strong schooling shark
	Sawfish = 0.99, -- big, but a bottom cruiser
	Dolphin = 1.06, -- fast and loved
	Swordfish = 1.08, -- one of the fastest fish alive
	Viperfish = 1.0, -- a deep ambusher: average
	-- Epic
	ReefShark = 1.02, -- a sleek hunter
	HumpheadWrasse = 0.94, -- a bulky grazer
	GreatWhite = 1.07, -- the shark
	StellersSeaCow = 0.92, -- a gentle floating giant
	ElectricRay = 0.95, -- a sluggish disc
	GoliathGrouper = 0.93, -- a heavy lump of a fish
	MantaRay = 1.03, -- a graceful flier
	Orca = 1.08, -- the top hunter, and fast
	GiantSquid = 1.02, -- jet powered
	GoblinShark = 0.97, -- slow and odd
	Anglerfish = 0.93, -- a floating lure
	FrilledShark = 0.98, -- an eel of a shark
	GiantIsopod = 0.92, -- an armoured crawler
	SeaScorpion = 1.0, -- a paddling hunter: average
	-- Legendary
	Archelon = 0.93, -- a giant turtle
	Dunkleosteus = 0.98, -- armour is heavy
	Dakosaurus = 1.04, -- a sea crocodile built for the chase
	Xiphactinus = 1.06, -- the fast "bulldog fish"
	Elasmosaurus = 0.97, -- a long-necked paddler
	Helicoprion = 1.02, -- the buzz-saw shark
	Liopleurodon = 1.04, -- a big four-flippered hunter
	Shonisaurus = 1.0, -- a whale-sized ichthyosaur: average
	Basilosaurus = 1.02, -- a serpent whale
	Livyatan = 1.05, -- the killer sperm whale
	Mosasaurus = 1.08, -- the star of the deep
	Anomalocaris = 0.95, -- an ancient paddler
	BobbitWorm = 0.92, -- a worm
	Kronosaurus = 1.05, -- huge jaws, strong flippers
	Megalodon = 1.07, -- the biggest shark that ever was
	GraveRay = 0.98, -- a ghostly glider
	GraveTurtle = 0.93, -- a turtle, still
	SkullAngler = 0.94, -- an angler, still
	WraithEel = 1.02, -- a quick ghost
	BrimstoneEel = 1.03, -- an eel of fire
	CinderRay = 1.0, -- a burning glider: average
	HellfinShark = 1.07, -- a shark from the Underworld
	InfernalAngler = 0.95, -- an angler, still
	-- Mythic
	BlueWhale = 0.94, -- the biggest and the calmest
	LanternLeviathan = 1.0, -- a long lit serpent: average
	Kraken = 0.97, -- a mass of arms
	MoltenMegalodon = 1.06, -- a Megalodon on fire
	BoneLeviathan = 1.02, -- a racing skeleton
	HalfboneMegalodon = 1.04, -- half a Megalodon is still a Megalodon
	AbyssalWatcher = 0.96, -- it watches; it doesn't hurry
	Hellmaw = 1.08, -- the last land's monster
	-- Secret
	PearlSerpent = 1.0, -- the first Secret: average
	CoralDragon = 1.03, -- a dragon
	KelpWyrm = 0.98, -- winds through the kelp
	GalleonWhale = 0.93, -- a whale carrying a ship
	StormSerpent = 1.08, -- lightning
	AuroraJelly = 0.92, -- a drifting jelly
	VoidWhale = 0.97, -- a whale, dark and slow
	EmberSerpent = 1.05, -- a serpent of fire
	PhantomWhale = 1.0, -- a ghost whale: average
	TheDevourer = 1.08, -- the end of the list
} :: { [string]: number }

-- The size roll (Hugo, 2026-11-12): every spawned fish is Min to Max times its species' size, most of them near 1 and
-- the extremes rare. The roll is a number 0 to 1 raised to Curve and laid on either side of 1: at Curve 2.5 half the
-- fish are within 7% of 1 above (3% below), and about one in twenty is over x1.3. It scales the model, the seat, what
-- counts as the fish's body (the lock, the landing, crashes) and its speed (Speed.SizeBonus, only up to x1.2); the fish's "Size"
-- attribute, shown on its tag as "x1.23".
Config.Size = {
	On = 1, -- 0: every fish x1
	Min = 0.8,
	Max = 1.4,
	Curve = 2.5, -- 1: evenly spread between Min and Max; higher: more of them near 1
}

-- Variants (Hugo, 2026-11-12): the chance that a spawned fish is one, 0 to 1 (Rainbow is rolled first). The fish's
-- "Variant" attribute ("", "Gold" or "Rainbow"); the look is Shared/Variants; the speed is Speed.Gold and Speed.Rainbow.
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
	DockRadius = 165, -- staying surfaced this close (flat) to the dock's spawn puts you back on it (grey-box 9: the spawn is 104 behind the lane's start and the mouth is 248 wide, so this is the hub, the mouth's corners and the first 60 studs of water in the middle; grey-box 4 had 120, v4 520)
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
	SteerEase = 6, -- how quickly the way you go comes round to the view (higher is snappier)
	SteerRate = 140, -- and never faster than this, degrees a second
	YawRate = 95, -- A and D turn the view (and with CameraSteer off, you) at this rate at full press, degrees a second
	TurnEase = 10, -- how quickly a turn comes in and stops (higher is snappier)
	MaxPitch = 55, -- the steepest the fish noses up or down by itself to follow the lane
	BankEase = 5, -- response rate for the bank on a fish and in the hop
	Bank = 28, -- roll into turns
	SeatHeight = 1.4, -- the rider's root above the fish's back
	FloorClearance = 3, -- the fish pulls up nearer the floor than this
	Ceiling = 4, -- and stays this far under the surface line
	LaneMargin = -3, -- a ridden fish and a flight stay this far inside the lane's edge (negative: inside). It was 20 past it, but since grey-box 6 the walls are a 1-stud face with a hollow behind, and 20 past the edge is inside that hollow
	SpeedSlack = 1.6, -- the server flags a ridden fish moving faster than its own surge speed (Config.speedOf x Surge) times this
	-- The startle (Hugo, 2026-11-12): a fish you land on is shocked for about a second, like a horse rearing. Its nose
	-- jerks up and it rears back, shaking, its tail thrashing, a "!" over its head, the rider braced. It never stops
	-- (Hugo, later the same day: the stall and the bolt went): it drops to StartleSlow of its speed for StartleHold
	-- seconds, then eases back to full over StartleRecover. The rearing is seen only (AnimController turns the fish's
	-- joints, never its Root); the dip is the ridden speed's own curve (RideController), never a push: the limits on a
	-- fish's force and torque (Lib/FishModel, 2026-11-12) stay. Only a landing startles, not the sandbox's reset.
	Startle = 1, -- 1: a landing startles the fish; 0: the old mount (Surge at once, and Animation.LandingMix's reactions)
	StartleTime = 0.8, -- seconds it rears and shakes (the look only: AnimController)
	StartleBrake = 0.12, -- it comes down to StartleSlow over this long at the touch
	StartleSlow = 0.6, -- its speed while it is startled, as a share of its ridden speed
	StartleHold = 0.4, -- seconds it stays that slow
	StartleRecover = 0.8, -- then it eases back to its ridden speed over this long
	StartleRear = 34, -- how far the nose goes up, degrees (a big creature rears a little less)
	StartleShake = 7, -- the shake while it is reared: degrees of roll each way,
	StartleShakeRate = 9, -- and how many times a second
	StartleCoil = 9, -- the nose dips this far under level just before the bolt, degrees
	StartleLunge = 1.2, -- the body lunges this far ahead of itself as it bolts, studs, for a mid-sized fish
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
	Window = 3.0, -- seconds from leaving the fish in which to grab the next one
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
	FreeLaunch = 78, -- the pop's speed from floating, with no fish under you (55 until 2026-11-11)
	-- The height (2026-11-10, the user: the reference has flat ground, we don't): the hop rises this far above where
	-- you left, or above the locked fish if that is higher, so there is always a swoop down onto the fish. It never
	-- leaves the water; where the water is too shallow for it the herd swims lower (Config.herdTop).
	Apex = 20,
	Ceiling = 3, -- the hop stays this far under the surface line (Oxygen.SurfaceY)
	SeatRoom = 5, -- a rider sits about this far above the middle of a fish: the hop's rise is counted from the seat
	FloatTime = 1.3, -- the glide at the top, swimming (1.4 until 2026-11-11: with LaunchTime it ends 1.7 s after the press, when the reference's pull-in begins)
	FloatRise = 1, -- still rising this much through the glide
	-- (Hugo, 2026-11-11, after playing: the air was too slow. The glide was 38, the herd's pace, and the drop 30.)
	AirSpeed = 54, -- the glide's speed with AirShare 0: well past the herd's pace (38), so a hop gains on the fish ahead
	-- (the user, later the same day: match the reference. Measured there, the rider floats at 0.85 of the speed they
	-- rode at, keeping pace with the herd, so they hang over the fish ahead instead of flying past it.)
	AirShare = 0.85, -- the glide's speed as a share of the ridden speed of the fish you left; 0: AirSpeed, whatever the fish
	FreeAirSpeed = 38, -- and from floating, with no fish left behind (a Common's herd pace)
	-- The drop is the rest of the window (Window - LaunchTime - FloatTime: 1.2 s). It is still swimming, not a fall:
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
	BoltLines = 0.85, -- and as a startled fish picks its speed up again
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
	Mark = 1, -- the "!" over a startled fish (0 off)
	MarkTime = 0.6, -- seconds it shows
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
	RiddenSpeed: number?,
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

-- How long a full meter of `max` lasts on that fish, in seconds
function Config.secondsOn(zone: number, tier: string, max: number): number
	if Config.strained(zone, tier, max) then
		return Config.Oxygen.StrainTime
	end
	return max / math.max(Config.drain(zone, tier), 0.001)
end

-- Whether a fish breaks the props it swims into (Props.MinLength), or crashes into them
function Config.smashes(fish: FishType): boolean
	return fish.Size.Z >= Config.Props.MinLength
end

-- A spawned fish's size, from two rolls of 0 to 1 (Config.Size): `side` says bigger or smaller, `roll` by how much
function Config.rollSize(side: number, roll: number): number
	local z = Config.Size
	if z.On <= 0 then
		return 1
	end
	local t = math.clamp(roll, 0, 1) ^ math.max(z.Curve, 0.01)
	local size = if side < 0.5 then 1 + t * (z.Max - 1) else 1 - t * (1 - z.Min)
	return math.floor(size * 100 + 0.5) / 100
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

-- The size's factor on speed: x1 at Size.Min up to x(1 + Speed.SizeBonus) at Size.Max
function Config.sizeSpeed(size: number): number
	local lo, hi = Config.Size.Min, Config.Size.Max
	local t = if hi > lo then math.clamp((size - lo) / (hi - lo), 0, 1) else 0
	return 1 + Config.Speed.SizeBonus * t
end

-- One fish's ridden speed: its species' (base x rarity), by its size and its variant
function Config.speedOf(fish: FishType, size: number?, variant: string?): number
	local s = Config.Speed
	local speed = fish.RiddenSpeed * Config.sizeSpeed(size or 1)
	if variant == "Gold" then
		speed *= s.Gold
	elseif variant == "Rainbow" then
		speed *= s.Rainbow
	end
	return speed
end

-- A fish model's size roll and variant (its attributes, written by the server at the spawn)
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
	return Config.speedOf(fish, Config.sizeOf(model), Config.variantOf(model))
end

function Config.bodyOf(model: Instance, fish: FishType): Vector3
	return fish.Size * Config.sizeOf(model)
end

-- a fish with a ridden speed of its own (RiddenSpeed in the table above) keeps it when the rarities' speeds change
local OWN_SPEED: { [string]: number } = {}

for _, spec in FISH do
	local tier = Config.Tiers[spec.Tier]
	if spec.RiddenSpeed then
		OWN_SPEED[spec.Id] = spec.RiddenSpeed
	end
	local fish: FishType = {
		Id = spec.Id,
		Name = spec.Name,
		Tier = spec.Tier,
		Home = spec.Home,
		Reach = spec.Reach or 2,
		Required = Config.required(spec.Home, spec.Tier),
		IdleSpeed = spec.IdleSpeed or (spec.RiddenSpeed or tier.Ridden) * Config.Herd.SpeedShare,
		RiddenSpeed = spec.RiddenSpeed or tier.Ridden,
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
	-- the rarities' speeds, and each species' (the sandbox panel may have changed Speed.Base or a TierMult)
	for name, tier in Config.Tiers do
		tier.Ridden = Config.Speed.Base * (Config.TierMult[name] or 1)
	end
	for _, fish in Config.Fish do
		local tier = Config.Tiers[fish.Tier]
		fish.RiddenSpeed = OWN_SPEED[fish.Id]
			or (if tier then tier.Ridden else Config.Speed.Base) * (Config.SpeciesSpeed[fish.Id] or 1)
		fish.IdleSpeed = fish.RiddenSpeed * Config.Herd.SpeedShare
		fish.Required = Config.required(fish.Home, fish.Tier)
	end
end

Config.refresh()

return Config
