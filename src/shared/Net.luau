--!strict
-- The remotes, in ReplicatedStorage.Remotes. The server makes them; clients wait for them.
--   Action (client -> server): "Dash", fish | "Grapple", fish | "JumpOff"
--   Ride (server -> one client): "Mounted", fish, landing | "Dismounted", reason | "DashStart", fish, duration |
--     "GrappleStart", fish, flyTime, reelTime | "Denied", action, reason | "PassOut" | "Respawned"
--   Fx (server -> every client): "Dash", player, fish, duration | "Grapple", player, fish, flyTime, reelTime |
--     "Land", player, fish
-- Player attributes the server owns: State ("Dock", "Riding", "Free", "Dashing", "Grappling", "PassedOut"), Oxygen,
-- MaxOxygen, GraceEnds (workspace:GetServerTimeNow() when you pass out, or nil).
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
