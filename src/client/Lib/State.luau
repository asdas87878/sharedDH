--!strict
-- What the local player is doing, shared between the controllers. Mode mirrors the server's State attribute (Dock,
-- Riding, Free, Dashing, Grappling, PassedOut) plus "Aiming", the client's own grapple aim window.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Zones)

local State = {
	Player = Players.LocalPlayer,
	Mode = "Dock",
	Fish = nil :: Model?, -- the fish we ride
	MountedAt = 0, -- os.clock() of the mount
	Speed = 0, -- our speed, for the HUD and camera
	DashTarget = nil :: Model?, -- the fish a dash would go to now
	AimTarget = nil :: Model?, -- the grapple reticle's fish
	AimEnds = 0, -- os.clock() the aim window closes
	TimeScale = 1, -- the local slow-mo (camera, tweens, our own float)
	FovKick = 0, -- extra field of view that decays (the dash)
	DashReadyAt = 0,
	GrappleReadyAt = 0,
	Zones = {} :: { Zones.Zone },
	Squash = {} :: { [Model]: number }, -- character -> os.clock() of its last landing
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

-- Underwater and in play: the dash, grapple and the ride camera are live
function State.inWater(): boolean
	local m = State.Mode
	return m == "Riding" or m == "Free" or m == "Dashing" or m == "Grappling" or m == "Aiming"
end

-- A wild fish nobody is on or heading to (and not ours)
function State.isFreeFish(model: Model): boolean
	return model ~= State.Fish
		and model.Parent ~= nil
		and model.PrimaryPart ~= nil
		and model:GetAttribute("Rider") == 0
		and model:GetAttribute("Reserved") == 0
end

-- The best fish in a cone: the smallest angle off the axis scores best, nearer fish winning close calls
function State.bestInCone(
	origin: Vector3,
	axis: Vector3,
	range: number,
	coneDegrees: number,
	nearWeight: number
): Model?
	local half = math.rad(coneDegrees / 2)
	local best: Model? = nil
	local bestScore = math.huge
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
					if score < bestScore then
						bestScore = score
						best = model
					end
				end
			end
		end
	end
	return best
end

return State
