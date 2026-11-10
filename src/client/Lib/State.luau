--!strict
-- What the local player is doing, shared between the controllers. Mode mirrors the server's State attribute (Dock,
-- Free, Riding, Dashing, Grappling, Eaten, Drowning), with "Aiming" for the server's Hooking (the hook window, which our
-- client opens at once on the key press and shows on its own clock).
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
	DashTarget = nil :: Model?, -- the fish a dash would go to now
	AimTarget = nil :: Model?, -- the hook reticle's fish
	AimEnds = 0, -- os.clock() the hook window closes
	TimeScale = 1, -- the local slow-mo (camera, tweens, our own float)
	FovKick = 0, -- extra field of view that decays (the dash, landings)
	DashReadyAt = 0,
	Zones = {} :: { Zones.Zone },
	Squash = {} :: { [Model]: number }, -- character -> os.clock() of its last landing
	Buck = {} :: { [Model]: number }, -- fish -> os.clock() it began bucking its rider off
	DeathStart = {} :: { [Player]: number }, -- os.clock() each dying player's death began (for the poses)
	DeathThrown = {} :: { [Player]: boolean }, -- and whether a fish threw them off first
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
	return State.Mode == "Eaten" or State.Mode == "Drowning"
end

-- Underwater and in play (or dying there): the ride camera is live
function State.inWater(): boolean
	local m = State.Mode
	return m == "Riding" or m == "Free" or m == "Dashing" or m == "Grappling" or m == "Aiming" or State.dying()
end

-- A camera shake that dies away over `time` (the landing kick, the chomp)
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

-- The best fish in a cone: the smallest angle off the axis scores best, nearer fish winning close calls. With `current`,
-- it's sticky: the current fish stays while it's still in the cone, unless another scores `sticky` better.
function State.bestInCone(
	origin: Vector3,
	axis: Vector3,
	range: number,
	coneDegrees: number,
	nearWeight: number,
	current: Model?,
	sticky: number?
): Model?
	local half = math.rad(coneDegrees / 2)
	local best: Model? = nil
	local bestScore = math.huge
	local currentScore = math.huge
	local folder = workspace:FindFirstChild("Fish")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and State.isFreeFish(model) then
			local root = model.PrimaryPart :: BasePart
			local to = root.Position - origin
			local distance = to.Magnitude
			if distance <= range and distance > 0.5 then
				local angle = math.acos(math.clamp(to.Unit:Dot(axis), -1, 1))
				if angle <= half then
					local score = angle / half + nearWeight * distance / range
					if model == current then
						currentScore = score
					end
					if score < bestScore then
						bestScore = score
						best = model
					end
				end
			end
		end
	end
	if current and currentScore < math.huge and bestScore > currentScore - (sticky or 0) then
		return current
	end
	return best
end

return State
