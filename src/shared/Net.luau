--!strict
-- The remotes, in ReplicatedStorage.Remotes. The server makes them; clients wait for them.
-- (The list below is behind the code. Every message as the code has it, with who sends and who listens, is in
-- docs/Code map.md, "Every message". Two more remotes sit in the same folder, made by their own services: Admin
-- (AdminService) and Trainer (TrainService).)
--   Action (client -> server): "Jump" (from Riding or Free: into the hop) | "Grab", fish (the locked fish: the server
--     checks it and keeps it for us) | "CancelGrab" | "Land", fish (the pull-in onto the granted fish has ended) |
--     "Miss" (the window ran out with no fish) | "Place", index, id (put the index-th fish we carry, of kind id, into
--     our tank: AquariumService; refused with Ride "Denied", "Place", "Far")
--   Ride (server -> one client): "Mounted", fish, landing | "Dismounted", reason | "Denied", action, reason |
--     "Respawned" | "Crashed", slow (our fish ran into something: the share of its speed it keeps) |
--     "Tamed", fish, fishId (the fish under us is ours now) | "Caught", ids (what we carry: fish ids, oldest first;
--     an empty list once it is in our tank, or at the dock with no tank) | "Deposited", count, gained, income (that
--     many fish went into our tank: the coins a second gained, what the tank earns now, and the fish's id; AquariumService) | "Boost", kind, by, time, oxygen, count (a passive archetype paid us:
--     kind "Eat" or "Smash", our fish goes `by` times its speed for `time` seconds, `oxygen` of the max meter came
--     back, `count` is the Frenzy's stacks or the boxes knocked loose: Config.Archetype) | "OxygenTick", lost, oxygen,
--     every, kind (the meter dropped by `lost` to `oxygen` at once; the next tick in `every` seconds; kind "Tick" for
--     the drain, Oxygen.Tick, or "Red" for the drop to the red zone's line on mounting a fish too strong, RedDrop)
--   Fx (server -> every client): "Land", player, fish, count (that rider's landings so far) | "Fail", player, fish, kind (out of Oxygen on a fish that does
--     something first: Config.Fail's outcome, played by FailController) | "ThrowOff", player, fish (out of Oxygen: the fish bucks the
--     player off) | "Eat", player, fish, where, stacks (that rider's Predator ate a wild fish there) | "Smash", player,
--     fish, where, boxes (that rider's Breaker was paid for a prop)
--   and for the sandbox's reset only: Ride "SandboxMount", fish (sit on this fish yourself) answered by Action
--     "SandboxSit", fish (we are on its saddle: join us)
--   The submarine (SubService, docs/design/submarine.md): Action "SubBuy" (the next tier) | "SubPick", land, fishKey
--     (where to go, 0: no sub; the tank fish to ride with, "id|size|variant" or "") | "SubLand", fish (the kick has put
--     us on our fish); Ride "SubFish", fish (our fish, beside the sub: drive it there) | "SubDrop", "Fling" or
--     "Kick", fish | "SubDenied", reason ("Coins", "Dock", "Land", "Top") | "SubBought", tier.
--   Sandbox (client -> server, Studio only): "Tune", "Group.Key", number | "Flag", name, boolean | "Reset"
-- Attributes on the Remotes folder, set by the server: Zones (the zones, Zones.encode), LanePath (the lane's
-- centreline as JSON, "" with none) and Dock (the dock spawn's CFrame, when the map has one).
-- Attributes on a fish the server owns (besides FishService's own: FishType, Tier, Variant, Rider, Reserved): Angry
-- (true while its rider's meter is in its red part, Oxygen.AngryAt, or it is too strong for them; nil otherwise:
-- Config.Angry) and AngryStyle (its angry style's name while Angry: "Zigzag", "Drag", "Coil", "Buck", "Flutter",
-- "Balk", "Pulse", "Wobble", "Dig" or "Fade", Shared/AngryStyles; for the animations to come). An angry fish also
-- carries the CollectionService tag "AngryFish" (Config.Angry.Tag). And for the passive archetypes
-- (docs/design/archetypes.md, Animation hooks): Archetype ("" or ids comma-separated), Bite and Smash (each counts
-- up by one with every bite and every paid smash) and Frenzy (1 to 3 while a Frenzy's chain lasts).
-- The map's props (PropService, Config.Props): a box the server has taken out of a prop carries the CollectionService
-- tag "PropOut"; its prop (the Model in Lane/Props) carries BreakAt and BreakVel (Vector3: where it was last hit and
-- the fish's velocity), BreakT and RebuildT (workspace:GetServerTimeNow() of the last hit and the last rebuild).
-- Sandbox also takes "Ride", fishId, variant (Studio only: onto a fish of that kind, put at the start).
-- Workspace attributes in Studio: Sandbox, SandboxNoFail, SandboxEndlessAir (the movement sandbox's switches).
-- Player attributes the server owns: State ("Dock", "Free", "Riding", "Jumping", "Drowning", "Carried": on the
-- submarine), SubTier, SubDest, SubFish, SubPhase, SubTrip (SubService), Tank (AquariumService: the tank's best fish), Oxygen, MaxOxygen,
-- Drain (the Oxygen a second the fish under you takes, as the server counts it; 0 off a fish), Training (true while
-- you stand on the training spot and your max Oxygen is growing), Strained (true while you ride a fish too strong for
-- you: the meter empties in Oxygen.StrainTime), Tame (0 to 1 while you ride: how far the fish under you is from being
-- yours; nil off a fish, on one too strong, or with taming off), Owned (how many creatures you have brought home this
-- session),
-- Coins, Income (coins a second), TankFish (how many their tank holds) and Plot (their plot's name): AquariumService,
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
