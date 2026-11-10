--!strict
-- The remotes, in ReplicatedStorage.Remotes. The server makes them; clients wait for them.
--   Action (client -> server): "Dash", fish | "Grapple", fish or nil (the hook window's one shot) | "JumpOff" (opens
--     the hook window, from Riding or Free)
--   Ride (server -> one client): "Mounted", fish, landing | "Dismounted", reason | "DashStart", fish, duration |
--     "GrappleStart", fish, flyTime, reelTime | "Denied", action, reason | "Respawned"
--   Fx (server -> every client): "Dash", player, fish, duration | "Grapple", player, fish, flyTime, reelTime |
--     "Land", player, fish | "ThrowOff", player, fish (out of Oxygen: the fish bucks the player off)
-- Player attributes the server owns: State ("Dock", "Free", "Riding", "Hooking", "Dashing", "Grappling", "Eaten",
-- "Drowning"), Oxygen, MaxOxygen, HookEnds (workspace:GetServerTimeNow() the hook window shuts, while Hooking),
-- DeathAt (server time the death began, while Eaten or Drowning) and DeathThrown (thrown off a fish first).
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
	for _, name in { "Action", "Ride", "Fx" } do
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

return Net
