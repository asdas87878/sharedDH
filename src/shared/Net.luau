--!strict
-- The remotes, in ReplicatedStorage.Remotes. The server makes them; clients wait for them.
--   Action (client -> server): "Jump" (from Riding or Free: into the hop) | "Grab", fish (the locked fish: the server
--     checks it and keeps it for us) | "CancelGrab" | "Land", fish (the pull-in onto the granted fish has ended) |
--     "Miss" (the window ran out with no fish)
--   Ride (server -> one client): "Mounted", fish, landing | "Dismounted", reason | "Denied", action, reason |
--     "Respawned" | "Crashed", slow (our fish ran into something: the share of its speed it keeps) |
--     "Tamed", fish, fishId (the fish under us is ours now) | "Caught", ids (what we carry on this dive: fish ids,
--     oldest first; an empty list at the dock)
--   Fx (server -> every client): "Land", player, fish, count (that rider's landings so far) | "ThrowOff", player, fish (out of Oxygen: the fish bucks the
--     player off)
--   and for the sandbox's reset only: Ride "SandboxMount", fish (sit on this fish yourself) answered by Action
--     "SandboxSit", fish (we are on its saddle: join us)
--   Sandbox (client -> server, Studio only): "Tune", "Group.Key", number | "Flag", name, boolean | "Reset"
-- Attributes on the Remotes folder, set by the server: Zones (the zones, Zones.encode), LanePath (the lane's
-- centreline as JSON, "" with none) and Dock (the dock spawn's CFrame, when the map has one).
-- Attributes on a fish the server owns (besides FishService's own: FishType, Tier, Variant, Rider, Reserved): Angry
-- (true while its rider's meter is in its red part, Oxygen.AngryAt, or it is too strong for them; nil otherwise:
-- Config.Angry) and AngryStyle (its angry style's name while Angry: "Zigzag", "Drag", "Coil", "Buck", "Flutter",
-- "Balk", "Pulse", "Wobble", "Dig" or "Fade", Shared/AngryStyles; for the animations to come). An angry fish also
-- carries the CollectionService tag "AngryFish" (Config.Angry.Tag).
-- Workspace attributes in Studio: Sandbox, SandboxNoFail, SandboxEndlessAir (the movement sandbox's switches).
-- Player attributes the server owns: State ("Dock", "Free", "Riding", "Jumping", "Drowning"), Oxygen, MaxOxygen,
-- Drain (the Oxygen a second the fish under you takes, as the server counts it; 0 off a fish), Training (true while
-- you stand on the training spot and your max Oxygen is growing), Strained (true while you ride a fish too strong for
-- you: the meter empties in Oxygen.StrainTime), Tame (0 to 1 while you ride: how far the fish under you is from being
-- yours; nil off a fish, on one too strong, or with taming off), Owned (how many creatures you have brought home this
-- session),
-- DeathAt (server time the drowning began), DeathThrown (thrown off a fish first) and DeathQuick (after a jump that
-- sank: a short drown).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in { "Action", "Ride", "Fx", "Sandbox" } do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

Net.Folder = folder
Net.Action = folder:WaitForChild("Action") :: RemoteEvent
Net.Ride = folder:WaitForChild("Ride") :: RemoteEvent
Net.Fx = folder:WaitForChild("Fx") :: RemoteEvent
Net.Sandbox = folder:WaitForChild("Sandbox") :: RemoteEvent

return Net
