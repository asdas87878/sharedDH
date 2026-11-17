--!strict
-- The aquarium (the user, 2026-11-16: "catches are for depositing in your aquarium, in which they then earn money").
-- The other half of the loop (docs/design/core-loop.md, docs/design/aquarium.md): what a dive catches goes into the
-- player's own tank on the dock, and the best fish in it earn coins every second.
--   A plot each: the map's Dock.Plots.PlotN (TankWater, Pad, CollectPad, SignBoard). A player takes the first free one
--   as they join and gives it up as they leave. With more players than plots, the rest have none: their catch is only
--   counted, as before.
--   Coming home: a player who is carrying fish wakes on the dock at their own tank (RideService.Home), not at the
--   dock's spawn. Standing on their plot with fish in hand, the fish go in (RideService.carried, RideService.deposited).
--   Earning: each fish earns by what it takes to hold at home, its size and its colour (Config.incomeOf). The best
--   Aquarium.Earning of them earn; the rest are kept and wait their turn. Coins are the player's "Coins" attribute (the
--   HUD's coin row shows itself when it is there), "Income" what the tank earns a second, "TankFish" how many it holds.
--   Seen: the earning fish swim in the tank, small. The server puts each in its place, anchored, with the tag
--   "TankFish" and the numbers of its lap; every client moves them round itself (AquariumController), so they cost no
--   traffic. They are not in Workspace.Fish, so nothing can lock on to one, tag it or ride it.
-- For the session only: there are no saves yet.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Variants = require(ReplicatedStorage.Shared.Variants)
local FishModel = require(script.Parent.Parent.Lib.FishModel)
local RideService = require(script.Parent.RideService)

type Entry = { Id: string, Size: string, Variant: string, Income: number }
type Tank = {
	Player: Player,
	Plot: Model,
	Fish: { Entry }, -- everything in the tank, the best earner first
	Coins: number,
	Income: number, -- coins a second: the best Aquarium.Earning of them
	Shown: Folder?,
}

local AquariumService = {}

AquariumService.Tag = "TankFish"

local EVERY = 0.25 -- seconds between looks at who is standing where
local plots: { Model } = {}
local tanks: { [Player]: Tank } = {}
local owners: { [Model]: Player } = {}

local function part(plot: Model, name: string): BasePart?
	local found = plot:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

-- The plot's sign, in the hub's sign style (the user's pick of 2026-11-16, "B": the gate's sign; docs/design/ui.md):
-- a blue board, a white band across its top with the owner's name in blue, and under it what the tank earns in white
-- letters with a dark edge. A free tank says so, paler, with no band.
-- Each player's own machine writes "YOUR TANK" over its own tank's band (Client.UI.HubSigns shows the label "Mine"
-- and hides "Owner"), so nothing here sets those two labels' Visible after they are made.
local SIGN_BLUE = Color3.fromRGB(30, 140, 255)
local SIGN_INK = Color3.fromRGB(16, 36, 63)
local SIGN_PALE = Color3.fromRGB(196, 224, 255)
local SIGN_FONT = Enum.Font.LuckiestGuy

local function signFace(board: BasePart, name: string, face: Enum.NormalId): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	local root = Instance.new("Frame")
	root.Name = "Board"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = SIGN_BLUE
	root.BorderSizePixel = 0
	root.Parent = gui
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.Size = UDim2.fromScale(1, 0.3)
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.BorderSizePixel = 0
	band.Parent = root
	for _, which in { "Owner", "Mine" } do
		local label = Instance.new("TextLabel")
		label.Name = which
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.03, 0.08)
		label.Size = UDim2.fromScale(0.94, 0.84)
		label.Font = SIGN_FONT
		label.TextScaled = true
		label.TextColor3 = SIGN_BLUE
		label.Text = if which == "Mine" then "YOUR TANK" else ""
		label.Visible = which == "Owner"
		label.Parent = band
	end
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Font = SIGN_FONT
	text.TextScaled = true
	text.Parent = root
	local edge = Instance.new("UIStroke")
	edge.Thickness = 3
	edge.Color = SIGN_INK
	edge.LineJoinMode = Enum.LineJoinMode.Round
	edge.Parent = text
	gui.Parent = board
	return gui
end

local function sign(plot: Model, tank: Tank?)
	local board = part(plot, "SignBoard")
	if not board then
		return
	end
	local owner = if tank then tank.Player.DisplayName else ""
	local text = if not tank
		then "FREE TANK"
		elseif tank.Income > 0 then string.format("$%s a second", Config.shortNumber(tank.Income))
		else "no fish yet"
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local name = "Sign" .. face.Name
		local gui = board:FindFirstChild(name)
		if gui and not gui:FindFirstChild("Board") then
			gui:Destroy() -- (a sign of the old build)
			gui = nil
		end
		local root = (gui or signFace(board, name, face)):FindFirstChild("Board")
		local band = root and root:FindFirstChild("Band")
		local ownerLabel = band and band:FindFirstChild("Owner")
		local label = root and root:FindFirstChild("Text")
		if
			band
			and band:IsA("Frame")
			and ownerLabel
			and ownerLabel:IsA("TextLabel")
			and label
			and label:IsA("TextLabel")
		then
			band.Visible = tank ~= nil
			ownerLabel.Text = owner
			label.Text = text
			label.TextColor3 = if tank then Color3.new(1, 1, 1) else SIGN_PALE
			label.Position = if tank then UDim2.fromScale(0.03, 0.34) else UDim2.fromScale(0.05, 0.2)
			label.Size = if tank then UDim2.fromScale(0.94, 0.6) else UDim2.fromScale(0.9, 0.6)
		end
	end
end

-- The tank's earning fish, put in the water for everyone to see: small, anchored, each with the numbers of its lap
local function show(tank: Tank)
	local a = Config.Aquarium
	if tank.Shown then
		tank.Shown:Destroy()
		tank.Shown = nil
	end
	local water = part(tank.Plot, "TankWater")
	if not water or #tank.Fish == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "TankFish"
	local count = math.min(#tank.Fish, a.Show)
	local half = water.Size / 2
	for i = 1, count do
		local entry = tank.Fish[i]
		local kind = Config.FishById[entry.Id]
		if kind then
			local model = FishModel.build(kind)
			CollectionService:RemoveTag(model, FishModel.Tag)
			Variants.apply(model, entry.Variant)
			-- its size in the tank: its own size, a share of it, kept between two lengths so a Tiny shows and a
			-- Colossal fits
			local own = kind.Size.Z * Config.sizeScale(entry.Size, kind)
			local shown = math.clamp(own * a.ShowShare, a.ShowLeast, a.ShowMost)
			model:ScaleTo(model:GetScale() * shown / math.max(kind.Size.Z, 0.1))
			local root = model.PrimaryPart
			if root then
				for _, d in root:GetChildren() do
					-- (its movers, and its wake: a tank's fish leaves none)
					if d:IsA("Constraint") or d:IsA("Trail") then
						d:Destroy()
					end
				end
				root.Anchored = true
				-- a lap of its own: the big ones wide and slow in the middle of the water, the small ones nearer the
				-- glass, each at its own height
				local u = (i - 0.5) / count
				local rx = math.max(half.X - shown / 2 - 4, 4) * (0.45 + 0.5 * u)
				local rz = math.max(half.Z - shown / 2 - 4, 4) * (0.45 + 0.5 * u)
				local y = water.Position.Y - half.Y + 5 + (water.Size.Y - 10) * ((i * 0.618034) % 1)
				model:SetAttribute("TankCentre", Vector3.new(water.Position.X, y, water.Position.Z))
				model:SetAttribute("TankReach", Vector3.new(rx, math.min(2, half.Y / 6), rz))
				model:SetAttribute("TankPhase", (i * 2.399963) % (math.pi * 2))
				model:SetAttribute("TankPace", a.SwimPace / math.max((rx + rz) / 2, 1) * (if i % 2 == 0 then 1 else -1))
				model:SetAttribute("SizeTier", entry.Size)
				model:SetAttribute("Variant", entry.Variant)
				model:PivotTo(CFrame.new(water.Position.X + rx, y, water.Position.Z))
				CollectionService:AddTag(model, AquariumService.Tag)
				model.Parent = folder
			else
				model:Destroy()
			end
		end
	end
	folder.Parent = tank.Plot
	tank.Shown = folder
end

local function tell(tank: Tank)
	tank.Player:SetAttribute("Coins", math.floor(tank.Coins))
	tank.Player:SetAttribute("Income", tank.Income)
	tank.Player:SetAttribute("TankFish", #tank.Fish)
end

-- What the tank earns: its best Aquarium.Earning fish (the list is kept best first)
local function count(tank: Tank)
	table.sort(tank.Fish, function(x, y)
		return x.Income > y.Income
	end)
	local income = 0
	for i = 1, math.min(#tank.Fish, Config.Aquarium.Earning) do
		income += tank.Fish[i].Income
	end
	tank.Income = income
end

-- The fish in the player's hands go into their tank
local function deposit(tank: Tank)
	local carried = RideService.carried(tank.Player)
	if #carried == 0 then
		return
	end
	local before = tank.Income
	local added = 0
	for _, c in carried do
		local kind = Config.FishById[c.Id]
		if kind then
			table.insert(
				tank.Fish,
				{ Id = c.Id, Size = c.Size, Variant = c.Variant, Income = Config.incomeOf(kind, c.Size, c.Variant) }
			)
			added += 1
		end
	end
	-- (a tank is not endless: past Aquarium.Hold the poorest are let go)
	count(tank)
	while #tank.Fish > Config.Aquarium.Hold do
		table.remove(tank.Fish)
	end
	count(tank)
	RideService.deposited(tank.Player)
	tell(tank)
	show(tank)
	sign(tank.Plot, tank)
	Net.Ride:FireClient(tank.Player, "Deposited", added, tank.Income - before, tank.Income)
end

local function join(player: Player)
	if tanks[player] then
		return
	end
	for _, plot in plots do
		if not owners[plot] then
			local tank: Tank = { Player = player, Plot = plot, Fish = {}, Coins = 0, Income = 0, Shown = nil }
			owners[plot] = player
			tanks[player] = tank
			plot:SetAttribute("Owner", player.UserId)
			player:SetAttribute("Plot", plot.Name)
			tell(tank)
			sign(plot, tank)
			return
		end
	end
end

local function leave(player: Player)
	local tank = tanks[player]
	if not tank then
		return
	end
	tanks[player] = nil
	owners[tank.Plot] = nil
	if tank.Shown then
		tank.Shown:Destroy()
	end
	tank.Plot:SetAttribute("Owner", nil)
	sign(tank.Plot, nil)
end

-- Whether a place is on a plot (over its pad, near the ground)
local function onPlot(plot: Model, at: Vector3): boolean
	local pad = part(plot, "Pad")
	if not pad then
		return false
	end
	local offset = pad.CFrame:PointToObjectSpace(at)
	return math.abs(offset.X) <= pad.Size.X / 2
		and math.abs(offset.Z) <= pad.Size.Z / 2
		and offset.Y > -4
		and offset.Y < 30
end

-- Where a player comes home to: in front of their own tank, facing it, when they carry fish
local function home(player: Player): CFrame?
	local tank = tanks[player]
	if not tank or Config.Aquarium.HomeAtTank == 0 or #RideService.carried(player) == 0 then
		return nil
	end
	local spot = part(tank.Plot, "CollectPad")
	local water = part(tank.Plot, "TankWater")
	if not spot or not water then
		return nil
	end
	local at = spot.Position + Vector3.new(0, 1, 0)
	local toward = Vector3.new(water.Position.X, at.Y, water.Position.Z)
	return if (toward - at).Magnitude > 1 then CFrame.lookAt(at, toward) else CFrame.new(at)
end

-- Studio and other services: what a player's tank holds (nil with no tank)
function AquariumService.tankOf(player: Player): { Entry }?
	local tank = tanks[player]
	return if tank then tank.Fish else nil
end

function AquariumService.Init()
	if Config.Aquarium.On == 0 then
		return
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local folder = dock and dock:FindFirstChild("Plots")
	if folder then
		for _, plot in folder:GetChildren() do
			if plot:IsA("Model") and part(plot, "TankWater") and part(plot, "Pad") then
				table.insert(plots, plot)
			end
		end
	end
	if #plots == 0 then
		print("[AquariumService] the map has no plots (Dock.Plots.PlotN with a TankWater and a Pad): no aquariums")
		return
	end
	-- the nearest to the dock's spawn first, so the first players are the shortest walk from the gate
	local spawn = dock and dock:FindFirstChild("DockSpawn")
	local from = if spawn and spawn:IsA("BasePart") then spawn.Position else Vector3.zero
	table.sort(plots, function(x, y)
		local dx, dy = (x:GetPivot().Position - from).Magnitude, (y:GetPivot().Position - from).Magnitude
		return if dx ~= dy then dx < dy else x.Name < y.Name
	end)
	for _, plot in plots do
		sign(plot, nil)
	end
	RideService.Keeps = function(player: Player): boolean
		return tanks[player] ~= nil
	end
	RideService.Home = home
end

function AquariumService.Start()
	if #plots == 0 then
		return
	end
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(leave)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	local paidAt = os.clock()
	while true do
		task.wait(EVERY)
		local now = os.clock()
		local pay = now - paidAt >= Config.Aquarium.Every
		for player, tank in tanks do
			if pay and tank.Income > 0 then
				tank.Coins += tank.Income * (now - paidAt)
				player:SetAttribute("Coins", math.floor(tank.Coins))
			end
			-- home with fish in hand, on their own plot: in they go
			if RideService.stateOf(player) == "Dock" and #RideService.carried(player) > 0 then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and onPlot(tank.Plot, root.Position) then
					deposit(tank)
				end
			end
		end
		if pay then
			paidAt = now
		end
	end
end

return AquariumService
