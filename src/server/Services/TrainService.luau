--!strict
-- The training spot: ride the toy on your plot and your max Oxygen grows (Config.Train). It is the smallest thing that
-- lets the progression be played: more max Oxygen is more seconds on a fish, so deeper lands (docs/design/
-- progression.md). The gain is RideService's to give (RideService.train: only on the dock) and lasts the session; there
-- are no saves yet.
-- Where (since 2026-11-16, with the hub's models): on your own plot, at its toy ride. Every plot has a `TrainerSpot`
-- with a `TrainerRide` on it (the seahorse). A player with no plot (more players than plots) may use any free plot's.
-- Only a map with no such plots gets the old stand-in: the map's part named TrainSpot under the hub, or a pad made once
-- beside the dock's spawn, where standing is training. The player's "Training" attribute is true while they are
-- gaining, for the HUD and the ride.
-- The ride (Hugo, 2026-11-19, task h1, docs/design/trainer.md): the kit's square pad, block and post are taken away at
-- start, and the seahorse goes on a real grey coil (RideStyles.Trainer, RideStyles.coil) from the middle of its body's
-- underside down to a small round red pad. Walk up to it, or jump onto it, and you are seated on it (a weld to its
-- body; every machine plays the hop up and rocks the toy, and the rider with it: TrainerController); jump or walk off
-- and you hop off. Only a seated rider trains, and every half second they are told what they gained ("Gain"), for the
-- "+n" pops. The remote is Remotes.Trainer: client "Off" (let me off); server "On", ride | "Off", ride, reason |
-- "Gain", amount. The ride model carries Rider (the user id on it), SpringBase, SpringTop and Seat (CFrames at rest).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RideService = require(script.Parent.RideService)
local RideStyles = require(ReplicatedStorage.Shared.RideStyles)

local TrainService = {}

local EVERY = 0.25 -- seconds between checks: the gain is given in steps this long
local PAD_COLOUR = Color3.fromRGB(90, 220, 255)

-- The trainer's sign, in the hub's sign style (the user's pick of 2026-11-16, "B": the gate's sign; docs/design/
-- ui.md): a blue board with a white rim and a darker copy under it, "TRAIN" in white letters with a dark edge, and
-- one line saying what it does. It is sized in studs, so it keeps its size in the world, and is not drawn past 220
-- studs. Only what is true today is on it: the ride's level and the next ride's price come with the upgrade.
-- Every plot's ride has one. Each player's own machine hides the others' (Client.UI.HubSigns), so a player sees the
-- sign once, over their own ride; nothing here sets Enabled after the sign is made.
local SIGN_BLUE = Color3.fromRGB(30, 140, 255)
local SIGN_INK = Color3.fromRGB(16, 36, 63)

local function trainSign(parent: BasePart, lift: number, riding: boolean?)
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromScale(17, 6.4)
	sign.StudsOffsetWorldSpace = Vector3.new(0, lift, 0)
	sign.MaxDistance = 220
	sign.LightInfluence = 0
	sign.AlwaysOnTop = false
	local shadow = Instance.new("Frame")
	shadow.Position = UDim2.fromScale(0, 0.08)
	shadow.Size = UDim2.fromScale(1, 0.92)
	shadow.BackgroundColor3 = SIGN_BLUE:Lerp(Color3.new(0, 0, 0), 0.6)
	shadow.BorderSizePixel = 0
	shadow.Parent = sign
	local board = Instance.new("Frame")
	board.Name = "Board"
	board.Size = UDim2.fromScale(1, 0.92)
	board.BackgroundColor3 = SIGN_BLUE
	board.BorderSizePixel = 0
	board.ZIndex = 2
	board.Parent = sign
	for _, frame in { shadow, board } do
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.1, 0)
		corner.Parent = frame
	end
	local rim = Instance.new("UIStroke")
	rim.Thickness = 4
	rim.Color = Color3.new(1, 1, 1)
	rim.Parent = board
	local function line(name: string, text: string, y: number, high: number, colour: Color3, edge: number)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.06, y)
		label.Size = UDim2.fromScale(0.88, high)
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = colour
		label.Text = text
		label.ZIndex = 3
		label.Parent = board
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = edge
		stroke.Color = SIGN_INK
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = label
	end
	line("Title", "TRAIN", 0.1, 0.56, Color3.new(1, 1, 1), 3)
	line("What", if riding then "ride it: more Oxygen" else "stand on it: more Oxygen", 0.7, 0.2, Color3.fromRGB(214, 234, 255), 1.5)
	sign.Parent = parent
end

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
	trainSign(pad, 12)
	pad.Parent = workspace
	return pad
end

-- A sign over a plot's ride. The ride stands in front of the right end of its tank's sign (SignBoard: 4 studs tall,
-- its top 26 studs up), and at 21 studs the trainer's board lay across that sign's end as seen from the front of
-- the plot, cutting off its words. Its foot is now above the tank sign's top, and the ride is nearer the viewer than
-- the tank's sign, so from the front the two are clear of each other at any distance: the tank's sign, and the
-- trainer's above its end.
local function label(spot: BasePart)
	if spot:FindFirstChild("Sign") then
		return
	end
	trainSign(spot, 30.5, true)
end

-- The plots' own training pads, by the plot's name (none on a map without them)
local function plotSpots(): { [string]: BasePart }
	local spots: { [string]: BasePart } = {}
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local hub = blockout and blockout:FindFirstChild("Dock")
	local plots = hub and hub:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			local spot = plot:FindFirstChild("TrainerSpot")
			if spot and spot:IsA("BasePart") then
				spots[plot.Name] = spot
				label(spot)
			end
		end
	end
	return spots
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
	local spots = plotSpots()
	local spot: BasePart? = nil
	if next(spots) == nil then
		spot = findSpot()
		if not spot then
			warn("[TrainService] no training spot: the map has no plots, no TrainSpot and no dock spawn to put one by")
			return
		end
	end
	local training: { [Player]: boolean } = {}
	Players.PlayerRemoving:Connect(function(player)
		training[player] = nil
	end)
	while true do
		local dt = task.wait(EVERY)
		local t = Config.Train
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local on = false
			if root and root:IsA("BasePart") then
				-- where this player trains: their own plot's pad; with no plot, the nearest plot's; on a map with
				-- no plots, the one stand-in
				local here: BasePart? = spot
				local reach = t.Radius
				if not here then
					local own = player:GetAttribute("Plot")
					here = if type(own) == "string" then spots[own] else nil
					if not here then
						local best = math.huge
						for _, other in spots do
							local far = (other.Position - root.Position).Magnitude
							if far < best then
								best, here = far, other
							end
						end
					end
					if here then
						-- (the pad is square: a little past its half width counts)
						reach = math.max(here.Size.X, here.Size.Z) / 2 + 2
					end
				end
				local middle = if here then here.Position else root.Position + Vector3.new(0, 1000, 0)
				local away = (root.Position - middle) * Vector3.new(1, 0, 1)
				if away.Magnitude <= reach and math.abs(root.Position.Y - middle.Y) < 12 then
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
