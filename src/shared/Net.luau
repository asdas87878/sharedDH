--!strict
-- The remotes, in ReplicatedStorage.Remotes. The server makes them; clients wait for them.
-- Every message is a name first, then its arguments. Who sends and who listens, file by file: docs/Code map.md,
-- "Every message".
--   Action (client -> server):
--     the hop (RideService): "Jump" (from Riding or Free: into the hop) | "Grab", fish (the locked fish: the server
--       checks it and keeps it for us) | "CancelGrab" | "Land", fish (the pull-in onto the granted fish has ended) |
--       "Miss" (the window ran out with no fish)
--     a tank fish ridden on land (RideService): "RideEquip" | "RideUnequip" | "RideMount"
--     the sandbox's and the admin panel's reset (RideService): "SandboxSit", fish (we are on its saddle: join us; the
--       answer to Ride "SandboxMount")
--     the tank (AquariumService): "Hold", index, id (hold that carried fish over the head; 0: put it down) |
--       "Tank", "PutIn", hand, id | "Tank", "TakeOut" or "Equip" or "Unequip", key | "Tank", "Best" |
--       "Tank", "PutAll" | "Sell", "Hand", hand, id | "Sell", "Tank", key | "Plot", "Up" (our plot's next stage)
--     riding a fish inside our tank (TankRideService): "TankRide", "On", fish | "TankRide", "Off"
--     the submarine (SubService, docs/design/submarine.md): "SubBuy" (the next tier) | "SubEquip", n | "SubPick", land,
--       fishKey (where to go, 0: no sub; the tank fish to ride with, "id|size|variant" or "") | "SubLand", fish (the
--       kick has put us on our fish)
--     not finished: "AuraBuy", tierId is sent by the aura stall (UI/AuraShop) and no server code listens for it.
--       "Place", index, id (the old click to put a carried fish in the tank) still has its handler in AquariumService,
--       but no client sends it; only tools/studio/e2_click_check.py knows it.
--   Ride (server -> one client):
--     RideService: "Mounted", fish, landing | "Dismounted", reason | "Denied", action, reason | "Crashed", slow (our
--       fish ran into something: the share of its speed it keeps) | "Tamed", fish, fishId (the fish under us is ours
--       now) | "Caught", ids (what we carry: fish ids, oldest first; an empty list once it is in our tank, or at the
--       dock with no tank) | "Boost", kind, by, time, oxygen, count (a passive archetype paid us: kind "Eat" or
--       "Smash", our fish goes `by` times its speed for `time` seconds, `oxygen` of the max meter came back, `count`
--       is the Frenzy's stacks or the boxes knocked loose: Config.Archetype) | "OxygenTick", lost, oxygen, every, kind
--       (the meter dropped by `lost` to `oxygen` at once; the next tick in `every` seconds; kind "Tick" for the
--       drain, or "Break" for the drop on a fish too strong) | "SandboxMount", fish (sit on this fish yourself) |
--       "Respawned" (sent on the way back to the dock; no client listens for it)
--     AquariumService: "Deposited", count, gained, income, id (that many fish went into our tank: the coins a second
--       gained, what the tank earns now, and the fish's id) | "Sold", id, coins | "TankDenied", why | "PlotUp", stage |
--       "PlotNo", why ("Near", "Top", "Coins", "Dead", "Busy") | "Denied", "Hold", why
--     TankRideService: "TankMounted", model, box, half | "TankDismounted"
--     SubService: "SubFish", fish (our fish, beside the sub: drive it there) | "SubDrop", "Fling" or "Kick", fish |
--       "SubDenied", reason ("Coins", "Dock", "Land", "Top") | "SubBought", tier
--   Fx (server -> every client, all from RideService): "Land", player, fish, count (that rider's landings so far) |
--     "Fail", player, fish, kind (out of Oxygen on a fish that does something first: Config.Fail's outcome, played by
--     FailController) | "Ragdoll", player, fish or nil, kind (that player's body has gone loose) | "ThrowOff", player,
--     fish (out of Oxygen: the fish bucks the player off) | "Eat", player, fish, where, stacks (that rider's Predator
--     ate a wild fish there) | "Smash", player, fish, where, boxes (that rider's Breaker was paid for a prop)
--   Sandbox (client -> server, Studio only: SandboxService): "Tune", "Group.Key", number | "Flag", name, boolean |
--     "Reset" | "Ride", fishId, variant (onto a fish of that kind, put at the start)
--   Two more remotes sit in the same folder, made by their own services:
--     Admin (AdminService; the owner's panel, both ways): the client sends what it wants ("Coins", "Fish", "Subs",
--       "Max", "Land", "NoFail", "EndlessAir", "Fail"); the server answers "Done", text or "Refused", text
--     Trainer (TrainService, both ways): the client sends "Off" or "Up"; the server sends "On", fish | "Off", fish,
--       reason | "Gain", amount | "Up", level, name | "UpNo", why
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
-- Workspace attributes in Studio: Sandbox, SandboxNoFail, SandboxEndlessAir (the movement sandbox's switches).
-- Player attributes the server owns: State ("Dock", "Free", "Riding", "Jumping", "Drowning", "Carried": on the
-- submarine), SubTier, SubDest, SubFish, SubPhase, SubTrip (SubService), Tank (AquariumService: the tank's best fish), Oxygen, MaxOxygen,
-- Drain (the Oxygen a second the fish under you takes, as the server counts it; 0 off a fish), Training (true while
-- you stand on the training spot and your max Oxygen is growing), Strained (true while you ride a fish too strong for
-- you: the meter empties in Oxygen.StrainTime), Tame (0 to 1 while you ride: how far the fish under you is from being
-- yours; nil off a fish, on one too strong, or with taming off),
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
