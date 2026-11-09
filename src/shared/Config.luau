--!strict
-- Every tuning number for the dive's first playable draft, from docs/design/riding-feel.md (starting numbers, to tune in
-- play). Speeds in studs a second, times in seconds, angles in degrees.

export type Tier = {
	Idle: number, -- idle swim speed of a wild fish
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
	FreeDrain = 4, -- a second while off a fish (floating, aiming); our guess, so floating can't last forever
	Grace = 3, -- seconds at zero Oxygen before you pass out
	FloatSpeed = 6, -- rising while off a fish
	SwimSpeed = 8, -- the little steering you get while floating
	SurfaceY = -3, -- floating stops here
	WaterY = -4, -- below this, a player on the dock counts as in the water
	Refill = 0.25, -- of max Oxygen, on landing a dash or grapple
	PassOutFade = 1.2, -- the fade before waking at the dock
	DockRadius = 160, -- surfacing this close to the dock puts you back on it
}

Config.Ride = {
	RampTime = 1.2, -- idle to ridden speed, easing out
	Surge = 1.25, -- the burst on mount
	SurgeTime = 0.5,
	SlowDownTime = 2, -- back to idle once nobody rides it
	YawRate = 95, -- turn rate at full stick
	PitchRate = 70,
	MaxPitch = 55,
	Bank = 28, -- roll into turns
	LevelRate = 0.6, -- pitch eases back towards level with no input (fraction a second)
	SeatHeight = 1.4, -- the rider's root above the fish's back
	FloorClearance = 8, -- the fish pulls up nearer the floor than this
	SpeedSlack = 1.6, -- the server flags a ridden fish moving faster than its surge speed times this
}

Config.Dash = {
	Range = 30,
	Cone = 60, -- full angle, ahead of the fish (or the camera while floating)
	Duration = 0.45,
	Spins = 2,
	SpiralRadius = 2,
	ArcHeight = 4, -- the path bows up by this much at most
	FovKick = 8,
	Cooldown = 0.3, -- after landing
	Snap = 0.08, -- the last part of the move snaps onto the saddle
}

Config.Grapple = {
	AimTime = 1.2, -- the aim window, real seconds
	TimeScale = 0.3, -- local slow-mo while aiming
	Range = 90,
	Cone = 20, -- full angle round the camera's aim
	FlyTime = 0.12, -- the rope flying out
	ReelTime = 0.6, -- reeling yourself in, speeding up
	Cooldown = 1, -- after firing, before the next aim window
	Pop = 10, -- the little hop up when you jump off
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
	ActiveZones = 4, -- the first version ships the first four zones
	PerThousand = 10, -- wild fish per 1,000 studs of lane
	Min = 12,
	Max = 40, -- per zone
	MaxTotal = 140,
	TopUpEvery = 2,
	PerTopUp = 4,
	HeightMin = 10, -- above the lane's floor
	HeightMax = 60,
	LaneFill = 0.4, -- fraction of the lane's half width fish use
	StartCluster = 6, -- extra fish kept in the lane's first StartLength studs, in reach of the dive board
	StartLength = 160,
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
		IdleSpeed = spec.IdleSpeed or tier.Idle,
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

return Config
