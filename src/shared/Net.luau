--!strict
-- The remotes, in ReplicatedStorage.Remotes. The server makes them; clients wait for them.
--   Action (client -> server): "Jump" (from Riding or Free: into the flight) | "Land", fish (the fish the flight came
--     down on) | "Miss" (it came down on nothing)
--   Ride (server -> one client): "Mounted", fish, landing | "Dismounted", reason | "Denied", action, reason |
--     "Respawned"
--   Fx (server -> every client): "Jump", player | "Land", player, fish | "ThrowOff", player, fish (out of Oxygen: the
--     fish bucks the player off)
--   Sandbox (client -> server, Studio only): "Tune", "Group.Key", number | "Flag", name, boolean | "Reset"
-- Workspace attributes in Studio: Sandbox, SandboxNoFail, SandboxEndlessAir (the movement sandbox's switches).
-- Player attributes the server owns: State ("Dock", "Free", "Riding", "Jumping", "Drowning"), Oxygen, MaxOxygen,
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
