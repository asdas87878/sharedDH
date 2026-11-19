-- Task u1 (one metre a stud): a temporary LocalScript for the still docs/attachments/meters-1.png. Installed into
-- StarterPlayer.StarterPlayerScripts by tools/ui/meters/capture.sh and removed after.
-- It asks the admin panel's remote for endless air and a ride into land LAND, then, when the server job sets
-- Workspace's "MetersShow", plays the catch screen with the gauge's own number for where the character is.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LAND = 5

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart") :: BasePart
local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local State = require(client.Lib.State)
local Banners = require(client.UI.Banners)
local Zones = require(ReplicatedStorage.Shared.Zones)
local admin = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Admin") :: RemoteEvent

task.wait(4)
admin:FireServer("EndlessAir", true)
admin:FireServer("NoFail", true)
task.wait(0.5)
admin:FireServer("Land", LAND)

while not workspace:GetAttribute("MetersShow") do
	task.wait(0.1)
end
local zone, _, metres = Zones.locate(State.Zones, root.Position)
print(
	string.format(
		"[Meters] y %.1f -> %.1f m, land %s (border %s m)",
		root.Position.Y,
		metres,
		zone and zone.Name or "-",
		zone and tostring(math.floor(zone.Metres)) or "-"
	)
)
Banners.greatDive(metres, true, {
	{ Id = "Clownfish", Tier = "Common" },
	{ Id = "Lionfish", Tier = "Uncommon" },
	{ Id = "Dolphin", Tier = "Rare" },
})
