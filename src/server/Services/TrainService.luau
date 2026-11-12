--!strict
-- The training spot: stand on it in the hub and your max Oxygen grows (Config.Train). It is the smallest thing that
-- lets the progression be played: more max Oxygen is more seconds on a fish, so deeper lands (docs/design/
-- progression.md). The gain is RideService's to give (RideService.train: only on the dock) and lasts the session; there
-- are no saves yet. The spot is the map's part named TrainSpot under the hub when it has one; until the map has it, a
-- stand-in pad is made once, beside the dock's spawn. The player's "Training" attribute is true while they are gaining,
-- for the HUD.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RideService = require(script.Parent.RideService)

local TrainService = {}

local EVERY = 0.25 -- seconds between checks: the gain is given in steps this long
local PAD_COLOUR = Color3.fromRGB(90, 220, 255)

local function standIn(dock: CFrame): BasePart
	local t = Config.Train
	local pad = Instance.new("Part")
	pad.Name = "TrainSpot"
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.6, t.Radius * 2, t.Radius * 2)
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanQuery = false
	pad.Material = Enum.Material.SmoothPlastic
	pad.Color = PAD_COLOUR
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	local at = dock.Position + dock.RightVector * t.Right + dock.LookVector * t.Ahead
	-- (a cylinder's round faces are along its X: stood on end, just above the hub's floor)
	pad.CFrame = CFrame.new(at.X, dock.Position.Y - 0.6, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromOffset(220, 60)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	sign.MaxDistance = 220
	sign.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 24
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = "TRAIN OXYGEN\nstand here"
	label.Parent = sign
	sign.Parent = pad
	pad.Parent = workspace
	return pad
end

local function findSpot(): BasePart?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local hub = blockout and blockout:FindFirstChild("Dock")
	local found = hub and hub:FindFirstChild("TrainSpot", true)
	if found and found:IsA("BasePart") then
		return found
	end
	-- the dock's spawn, published by RideService when it starts (it may start after us)
	local dock = Net.Folder:GetAttribute("Dock")
	local waited = 0
	while typeof(dock) ~= "CFrame" and waited < 10 do
		waited += task.wait(0.25)
		dock = Net.Folder:GetAttribute("Dock")
	end
	if typeof(dock) == "CFrame" then
		return standIn(dock)
	end
	return nil
end

function TrainService.Start()
	if Config.Train.On <= 0 then
		return
	end
	local spot = findSpot()
	if not spot then
		warn("[TrainService] no training spot: the map has no TrainSpot and no dock spawn to put one by")
		return
	end
	local training: { [Player]: boolean } = {}
	Players.PlayerRemoving:Connect(function(player)
		training[player] = nil
	end)
	while true do
		local dt = task.wait(EVERY)
		local t = Config.Train
		local middle = spot.Position
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local on = false
			if root and root:IsA("BasePart") then
				local away = (root.Position - middle) * Vector3.new(1, 0, 1)
				if away.Magnitude <= t.Radius and math.abs(root.Position.Y - middle.Y) < 12 then
					local max = player:GetAttribute("MaxOxygen")
					local share = if type(max) == "number" then max * t.Share else 0
					on = RideService.train(player, (t.Rate + share) * dt)
				end
			end
			if training[player] ~= on then
				training[player] = on
				player:SetAttribute("Training", on)
			end
		end
	end
end

return TrainService
