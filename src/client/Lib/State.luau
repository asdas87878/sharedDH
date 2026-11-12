--!strict
-- What the local player is doing, shared between the controllers. Mode mirrors the server's State attribute (Dock,
-- Free, Riding, Jumping, Drowning); our client goes to Jumping at once on the key press, ahead of the server. Jumping
-- is the hop off a fish (the pop, the glide, the drop), with the window to grab the next one.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)

export type DeathCam = { Focus: Vector3, Position: Vector3 }
export type Caught = { Id: string, Tier: string }

local State = {
	Player = Players.LocalPlayer,
	Mode = "Dock",
	Fish = nil :: Model?, -- the fish we ride
	MountedAt = -math.huge, -- os.clock() of the mount
	Speed = 0, -- our speed, for the HUD and camera
	JumpTarget = nil :: Model?, -- the locked fish (Lib/Lock): the one a grab would take; it glows
	Reeling = false, -- in a jump: being pulled onto the fish (its own pose)
	WindowLeft = nil :: number?, -- in a jump: seconds left to grab a fish (nil outside the window), for the HUD
	JumpPhase = nil :: string?, -- in a jump: "Pop", "Glide" or "Drop" (nil outside one), for the pose
	CrashAt = -math.huge, -- os.clock() the server last said we ran into something (the HUD's meter flashes)
	NoTargetAt = -math.huge, -- os.clock() of a grab pressed with no fish locked (the HUD's reticle flashes)
	Heading = 0, -- the way we are going (its yaw): A and D turn it, on a fish, in a jump and floating
	CamYaw = 0, -- where the camera looks (its yaw)
	SideCam = false, -- the sandbox's side view: the camera stands off to the side, and the steering keeps its own heading
	FovPunch = 0, -- extra field of view put on at once, with no easing (the pull-in's zoom, the landing's snap)
	KickVelocity = 0, -- a knock to the camera, studs a second downward: RideController's spring takes it
	JumpReadyAt = 0,
	Zones = {} :: { Zones.Zone },
	Squash = {} :: { [Model]: number }, -- character -> os.clock() of its last landing
	Buck = {} :: { [Model]: number }, -- fish -> os.clock() it began bucking its rider off
	DeathStart = {} :: { [Player]: number }, -- os.clock() each dying player's death began (for the poses)
	DeathThrown = {} :: { [Player]: boolean }, -- and whether a fish threw them off first
	DeathStruggle = {} :: { [Player]: number }, -- and how long they struggle (short after a jump that sank)
	DeathCam = nil :: DeathCam?, -- where the camera goes during a death (it eases there, no cut)
	Fade = 0, -- the black over everything, 0 to 1 (the deaths own it)
	FadeText = "",
	Vignette = 0, -- the screen edges closing in, 0 to 1
	Darken = 0, -- the water going dark, 0 to 1
	ModeChanged = Instance.new("BindableEvent"),
	-- Taming (TameController fills these from the server; the HUD reads them). With taming off they stay nil.
	Tame = nil :: number?, -- 0 to 1: how far the fish under us is from being ours (nil: nothing to show)
	Caught = nil :: { Caught }?, -- what we carry on this dive, oldest first
	Tamed = Instance.new("BindableEvent"), -- fired with the fish's id when the fish under us becomes ours
	Strained = false, -- the fish under us is too strong for us: the meter is emptying at once
}

function State.setMode(mode: string)
	if State.Mode ~= mode then
		local old = State.Mode
		State.Mode = mode
		State.ModeChanged:Fire(mode, old)
	end
end

function State.character(): (Model?, BasePart?, Humanoid?)
	local character = State.Player.Character
	if not character then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid then
		return character, root, humanoid
	end
	return character, nil, nil
end

-- How long a full meter would last on a fish where it swims now (for the HUD's lock plate and name tags): our max
-- Oxygen over what a fish of its rarity takes a second in the land it is in, the way the server counts it. nil when it
-- can't be told yet.
function State.secondsOn(fish: Model): number?
	local root = fish.PrimaryPart
	local tier = fish:GetAttribute("Tier")
	local max = State.Player:GetAttribute("MaxOxygen")
	if not root or type(tier) ~= "string" or type(max) ~= "number" then
		return nil
	end
	local zone = Zones.locate(State.Zones, root.Position)
	return Config.secondsOn(if zone then zone.Index else 1, tier, max)
end

-- Whether landing on that fish where it swims now would be landing on one too strong for us (Oxygen.StrainTime: the
-- meter empties at once and it throws us off). false when it can't be told yet.
function State.tooStrong(fish: Model): boolean
	local root = fish.PrimaryPart
	local tier = fish:GetAttribute("Tier")
	local max = State.Player:GetAttribute("MaxOxygen")
	if not root or type(tier) ~= "string" or type(max) ~= "number" then
		return false
	end
	local zone = Zones.locate(State.Zones, root.Position)
	return Config.strained(if zone then zone.Index else 1, tier, max)
end

function State.dying(): boolean
	return State.Mode == "Drowning"
end

-- Underwater and in play (or dying there): the ride camera is live
function State.inWater(): boolean
	local m = State.Mode
	return m == "Riding" or m == "Free" or m == "Jumping" or State.dying()
end

-- A wild fish nobody is on or heading to (and not ours)
function State.isFreeFish(model: Model): boolean
	return model ~= State.Fish
		and model.Parent ~= nil
		and model.PrimaryPart ~= nil
		and model:GetAttribute("Rider") == 0
		and model:GetAttribute("Reserved") == 0
end

return State
