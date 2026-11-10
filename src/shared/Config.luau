--!strict
-- Every tuning number for the dive, from docs/design/riding-feel.md (to tune in play). The jump follows the reference's,
-- read from the user's recordings (docs/reference/ride-a-dino.md).
-- Speeds in studs a second, times in seconds, angles in degrees.

export type Tier = {
	Idle: number, -- (not used since the herd: a wild fish swims at Herd.SpeedShare of its ridden speed)
	Ridden: number, -- speed once ridden
	Seconds: number, -- seconds on it with exactly its Required Oxygen: drain = Required / Seconds
	Colour: Color3, -- the tier's colour on markers
}

export type FishType = {
	Id: string,
	Name: string,
	Tier: string,
	Home: number, -- home zone index
	Reach: number, -- how many zones past home it can still turn up in
	Required: number, -- the Oxygen it takes to ride it for its tier's Seconds
	IdleSpeed: number,
	RiddenSpeed: number,
	Drain: number, -- Oxygen a second while ridden
	Size: Vector3, -- width, height, length (it faces -Z)
	Shape: string, -- placeholder body: "Fish" (tall, flat), "Round", "Shark", "Flat" (a ray), "Eel"
	Body: Color3,
	Belly: Color3,
	Fin: Color3,
	Pattern: string?, -- "Stripes", "Bands" or "Tips"
	PatternColour: Color3?,
	PatternCount: number?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Config = {}

Config.TierOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Config.Tiers = {
	Common = { Idle = 14, Ridden = 45, Seconds = 12, Colour = rgb(200, 200, 200) },
	Uncommon = { Idle = 16, Ridden = 52, Seconds = 10, Colour = rgb(90, 220, 90) },
	Rare = { Idle = 18, Ridden = 60, Seconds = 8, Colour = rgb(70, 150, 255) },
	Epic = { Idle = 20, Ridden = 68, Seconds = 7, Colour = rgb(180, 90, 255) },
	Legendary = { Idle = 22, Ridden = 78, Seconds = 6, Colour = rgb(255, 190, 40) },
	Mythic = { Idle = 24, Ridden = 90, Seconds = 5, Colour = rgb(255, 70, 90) },
	Secret = { Idle = 26, Ridden = 100, Seconds = 5, Colour = rgb(20, 20, 20) },
} :: { [string]: Tier }

-- Required rises about 5 times a zone (the roster) and with rarity (our guess, to tune)
local ZONE_BASE = 10
local ZONE_GROWTH = 5
local TIER_REQUIRED = { Common = 1, Uncommon = 2, Rare = 4, Epic = 8, Legendary = 16, Mythic = 30, Secret = 50 }

Config.Oxygen = {
	StartMax = 100, -- max Oxygen before any training
	FreeDrain = 4, -- a second while floating off a fish (not in a jump); our guess, so it can't last forever
	FloatSpeed = 6, -- rising while off a fish
	SwimSpeed = 8, -- the little steering you get while floating
	SurfaceY = -3, -- floating stops here
	WaterY = -4, -- below this, a player on the dock counts as in the water
	Refill = 0.25, -- of max Oxygen, on landing a jump
	DockRadius = 520, -- staying surfaced this close (flat) to the dock's spawn puts you back on it (map v4: the board ends 111 out, the lagoon is about 950 across)
	DockWait = 2.5, -- seconds at the surface first, so diving in off the board leaves time to jump
	-- Studio only: when above 0, everyone's max Oxygen, to try the deeper zones before training exists. Workspace's
	-- "TestMaxOxygen" attribute overrides it live (0 turns it off).
	StudioMax = 0,
}

Config.Ride = {
	RampTime = 1.2, -- idle to ridden speed, easing out
	Surge = 1.25, -- the burst on mount
	SurgeTime = 0.5,
	SlowDownTime = 2, -- back to idle once nobody rides it
	YawRate = 95, -- A and D turn the camera at this rate, and the fish turns with it
	TurnFollow = 5, -- how quickly the fish turns to where the camera looks (higher is quicker)
	PitchRate = 70,
	MaxPitch = 55,
	Bank = 28, -- roll into turns
	LevelRate = 0.6, -- pitch eases back towards level with no input (fraction a second)
	SeatHeight = 1.4, -- the rider's root above the fish's back
	FloorClearance = 3, -- the fish pulls up nearer the floor than this
	SpeedSlack = 1.6, -- the server flags a ridden fish moving faster than its surge speed times this
}

-- The jump, fish to fish (the reference's, laid over our water; docs/reference/ride-a-dino.md has the measurements).
-- Space throws you off the fish, up and forward, faster than you rode (the launch). Then you float: still rising a
-- little, swimming, steering, at about the herd's pace. Then you drop. A dashed yellow ring lies flat in the water under
-- you; a fish inside it glows yellow, and you come down on it: at the drop, or at once on a second press, pulled in
-- fast (the reel-in). Drop with no fish in the ring and you sink and drown.
Config.Jump = {
	-- The shape, from the user's side-on recording (2026-11-10): a quick pop up (about 0.3 s), then a long flat glide
	-- lying face down, sinking hardly at all, until the pull-in about 1.65 s after the press.
	LaunchTime = 0.3, -- the pop up
	BoostTime = 0.75, -- the launch's extra speed lasts this long (the reference: about 0.75 s)
	Launch = 1.4, -- times the speed you left the fish at (the reference: about 1.3 to 1.8)
	FreeLaunch = 55, -- the launch's speed from floating, with no fish under you
	-- The height (2026-11-10, the user: not high enough; the reference has flat ground, we don't): the jump rises this
	-- far above the highest fish in front of you, or above where you left if that is higher, so there is always a swoop
	-- down onto the fish.
	Apex = 16,
	FloatTime = 1.5, -- the glide at the top, swimming
	FloatRise = 1, -- still rising this much through the glide
	AirSpeed = 38, -- the float's speed: about the herd's pace
	DropTime = 1.3, -- then sinking, faster and faster
	Drop = 12, -- to this far below where you left
	-- The pull-in onto the fish, measured off the reference's distance counter frame by frame (two pull-ins): it takes
	-- 0.33 s over 15 m and 0.47 s over 22 m; it creeps for the first 40% of that time (about 13% of the way), then
	-- accelerates all the way in and arrives at top speed, with no slowing down. The gap closes as time ^ ReelCurve.
	ReelTime = 0.14, -- the pull-in's time for no distance at all; GrabSpeed adds to it by the distance
	ReelCurve = 2.3, -- the reference's two pull-ins fit about 1.5 and 2.5; higher creeps longer and arrives faster
	ReelMax = 0.8, -- the pull-in never takes longer than this, however far the fish
	ReelSwoop = 0.9, -- the pull-in comes down later than it comes across (added to ReelCurve for the height): a swoop
	-- The camera through a landing, measured between every pair of frames of the side-on recording (four landings):
	-- the picture grows through the pull-in, then in ONE frame shrinks to 0.79 to 0.81 of its size (the view snaps
	-- wider), and comes back over 0.3 to 0.4 s; with it a short up-and-down jolt of 10 to 17 pixels in 720, gone in
	-- about 0.13 s.
	ReelFov = -10, -- the view narrows by this much as the pull-in speeds up (the zoom in)
	LandFov = 12, -- then snaps this much wider than usual at the landing (0.8 of the picture's size at a 70 degree view)
	LandFovTime = 0.35, -- and settles back over this
	LandKick = 0.45, -- the jolt: the camera is knocked down this many studs
	LandKickRate = 12, -- and springs back, bouncing this many times a second
	LandKickDamp = 0.35, -- dying away (0 never, 1 with no bounce)
	MinFlight = 0.3, -- before a second press counts
	FloorClearance = 4, -- the flight stays this far above the sea floor and rocks
	SpeedTrim = 0.5, -- W and S speed up and slow the flight by this share
	YawRate = 170, -- A and D turn the camera in the flight, degrees a second
	TurnFollow = 8, -- how quickly the flight turns to where the camera looks (higher is quicker)
	RingRadius = 20, -- the ring under you; a fish whose middle is inside it is the one you land on
	Sticky = 1.3, -- the glowing fish keeps the glow until it is this many radii away
	ReachDown = 45, -- fish this far below you still count
	ReachUp = 25, -- and this far above
	Magnet = 3, -- how strongly the flight is drawn over the glowing fish (a second); 0 turns it off
	MagnetHold = 0.5, -- how much of the flight's speed the magnet takes the moment a fish glows (0 to 1)
	MagnetFull = 0.9, -- and after a second with it; the rest stays with the steering
	-- The fish you are making for (2026-11-10, the user: the closest fish in front, not the nearest any way, and not
	-- the fish you just left): the nearest fish within AheadCone of where the flight is headed and within GrabRange. It
	-- glows from the moment it is picked. With no turn held the flight makes for it: it takes on the fish's speed and
	-- closes the gap (ours: the reference pulls you onto a dino, but how it picks one isn't known). Assist = false
	-- turns that off.
	AheadCone = 140, -- full angle in front of the flight that counts as in front
	TargetKeep = 0.7, -- another fish takes over only when it is this share of the distance, or nearer
	Assist = true,
	AssistClose = 45, -- the speed the gap closes at
	AssistPull = 0.7, -- how much of the flight's speed this takes after the launch (0 to 1)
	-- The pull-in happens when the glide ends, or at once on a second press, onto the fish you are making for, however
	-- far within GrabRange. With no fish in front, it falls back to the nearest fish any way round within AutoGrab,
	-- and only with none of those to the fish you just left.
	GrabRange = 85,
	GrabSpeed = 55, -- the pull-in takes this much longer for the distance (studs a second; the reference: about 46 m)
	AutoGrab = 50,
	Cooldown = 0.3, -- after landing
	Slack = 0.6, -- the server waits this long past the flight for the landing (lag)
	LandSlack = 20, -- and allows the landing this many studs wider (it sees the player a moment late)
	CameraPitch = -32, -- the camera looks down on the flight, degrees
	CameraZoom = 1.3, -- and pulls back by this much
	Glow = rgb(255, 221, 51), -- the fish you will land on
	GlowFade = 0.3, -- the glow leaves the fish over this after the landing
	FlightTime = 0, -- the longest a flight can last, for the server (worked out in Config.refresh)
}

-- Wild fish swim as a herd: all the same way, down the lane, at this share of the speed they are ridden at (the
-- reference: riding about 55 m a second, the herd about 46, measured off its distance counter)
Config.Herd = {
	SpeedShare = 0.85,
	Ahead = 60, -- each fish heads for a point this far down the lane, at its own place across it and above the floor
	RideHeight = 12, -- a ridden fish with no dive or climb held settles at this height above the floor: in the herd
	RideHeightGain = 1.6, -- degrees of pitch for each stud it is off that height
	RideHeightPitch = 35, -- at most
}

Config.Switch = {
	CameraSettle = 0.4, -- the camera settles behind the new fish over this
	HandBack = 1.5, -- the old fish stays with its last rider's client this long, coasting, before the server takes it
}

-- The bubble burst on every landing, for everyone
Config.Burst = {
	Count = 30,
	Time = 0.6,
	Reach = 4, -- studs the bubbles fly out
	Kick = 0.15, -- a little rattle on our own landing, studs (the jolt itself is Jump.LandKick)
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
	EndlessAir = true, -- Oxygen doesn't drain
	StartS = 130, -- R puts you back here: studs down the lane from its start, or further down, at the first place
	StartRoom = 34, -- with this much water above the herd, so a jump has room to rise
}

Config.Net = {
	RangeSlack = 1.2, -- the server allows 20% more range for lag
}

Config.Camera = {
	Fov = 70,
	SpeedFov = 14, -- extra field of view at top riding speed
	SpeedFovFrom = 20, -- speed where it starts
	SpeedFovTo = 100, -- speed where it's full
	Distance = 17,
	Height = 5,
	AimDistance = 9,
	Follow = 8, -- how quickly the camera catches up (higher is stiffer)
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
	MaxTotal = 480,
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
	RoofGap = 10, -- under a roof (the map's Path c), fish stay this far below it
	LaneFill = 0.7, -- fraction of the lane's half width fish use
	StreamRadius = 700, -- fish further than this from every player are parked (out of Workspace, not simulated)
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
	Required: number?,
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
	-- zone 3: Kelp Forest
	{ Id = "Garibaldi", Name = "Garibaldi", Tier = "Uncommon", Home = 3, Size = Vector3.new(3.6, 5.2, 10), Shape = "Fish", Body = rgb(255, 110, 20), Fin = rgb(255, 130, 40) },
	{ Id = "LeopardShark", Name = "Leopard Shark", Tier = "Rare", Home = 3, Size = Vector3.new(3.6, 3.8, 17), Shape = "Shark", Body = rgb(170, 150, 120), Belly = rgb(240, 235, 225), Fin = rgb(150, 130, 100), Pattern = "Spots", PatternColour = rgb(60, 50, 40) },
	{ Id = "GreatWhite", Name = "Great White", Tier = "Epic", Home = 3, Size = Vector3.new(6, 6.5, 24), Shape = "Shark", Body = rgb(110, 120, 135), Belly = rgb(245, 245, 245), Fin = rgb(100, 110, 125) },
	-- zone 4: Shipwrecks
	{ Id = "Barracuda", Name = "Barracuda", Tier = "Uncommon", Home = 4, Size = Vector3.new(2.6, 3, 15), Shape = "Shark", Body = rgb(190, 200, 210), Belly = rgb(240, 245, 250), Fin = rgb(150, 160, 170) },
	{ Id = "Hammerhead", Name = "Hammerhead Shark", Tier = "Rare", Home = 4, Size = Vector3.new(5, 5, 22), Shape = "Shark", Body = rgb(120, 130, 120), Belly = rgb(235, 235, 230), Fin = rgb(110, 120, 110) },
	{ Id = "GoliathGrouper", Name = "Goliath Grouper", Tier = "Epic", Home = 4, Size = Vector3.new(7, 9, 18), Shape = "Fish", Body = rgb(110, 100, 70), Fin = rgb(90, 85, 60), Pattern = "Spots", PatternColour = rgb(60, 55, 40) },
}

Config.Fish = {} :: { FishType }
Config.FishById = {} :: { [string]: FishType }

for _, spec in FISH do
	local tier = Config.Tiers[spec.Tier]
	local required = spec.Required
		or ZONE_BASE * ZONE_GROWTH ^ (spec.Home - 1) * (TIER_REQUIRED :: any)[spec.Tier] :: number
	local fish: FishType = {
		Id = spec.Id,
		Name = spec.Name,
		Tier = spec.Tier,
		Home = spec.Home,
		Reach = spec.Reach or 2,
		Required = required,
		IdleSpeed = spec.IdleSpeed or (spec.RiddenSpeed or tier.Ridden) * Config.Herd.SpeedShare,
		RiddenSpeed = spec.RiddenSpeed or tier.Ridden,
		Drain = required / tier.Seconds,
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

-- The numbers worked out from other numbers. Called here, and again by the sandbox whenever it changes one.
function Config.refresh()
	local j = Config.Jump
	j.FlightTime = j.LaunchTime + j.FloatTime + j.DropTime + j.ReelTime + j.GrabRange / j.GrabSpeed
	for _, fish in Config.Fish do
		fish.IdleSpeed = fish.RiddenSpeed * Config.Herd.SpeedShare
	end
end

Config.refresh()

return Config
