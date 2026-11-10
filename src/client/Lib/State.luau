--!strict
-- What the local player is doing, shared between the controllers. Mode mirrors the server's State attribute (Dock,
-- Free, Riding, Jumping, Drowning); our client goes to Jumping at once on the key press, ahead of the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Zones)

export type DeathCam = { Focus: Vector3, Position: Vector3 }

local State = {
	Player = Players.LocalPlayer,
	Mode = "Dock",
	Fish = nil :: Model?, -- the fish we ride
	MountedAt = -math.huge, -- os.clock() of the mount
	Speed = 0, -- our speed, for the HUD and camera
	JumpTarget = nil :: Model?, -- in a jump: the fish in the ring, the one we'd land on
	Reeling = false, -- in a jump: being pulled onto the fish (its own pose)
	CamYaw = 0, -- where the camera looks (its yaw): the fish and the flight turn to it
	SideCam = false, -- the sandbox's side view: the camera stands off to the side, and the steering keeps its own heading
	FovKick = 0, -- extra field of view that decays (the jump): the camera eases to it
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
	ShakeUntil = 0,
	ShakeStrength = 0,
	ShakeTime = 0.3,
	ModeChanged = Instance.new("BindableEvent"),
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

function State.dying(): boolean
	return State.Mode == "Drowning"
end

-- Underwater and in play (or dying there): the ride camera is live
function State.inWater(): boolean
	local m = State.Mode
	return m == "Riding" or m == "Free" or m == "Jumping" or State.dying()
end

-- A camera shake that dies away over `time` (the landing kick)
function State.shake(strength: number, time: number)
	State.ShakeStrength = strength
	State.ShakeTime = time
	State.ShakeUntil = os.clock() + time
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
