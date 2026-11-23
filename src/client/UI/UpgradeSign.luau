--!strict
-- The seahorse's upgrade sign (NULLROOM task s2, Hugo 2026-11-20: "like the reference": Ride a Dino's "Upgrade Machine"
-- board on a post beside its spring-rider; the layout and feel copied, the look our own, from the shop kit's pieces).
-- A board on a post stands beside each plot's seahorse (the parts UpgradeBoard and UpgradePost: tools/map/hub_kit.py,
-- or TrainService when the map has none). This writes on it, on each machine, with a SurfaceGui in the PlayerGui:
--   the title           UPGRADE SEAHORSE, big white letters with the ink edge
--   the next seahorse   its model in a dark well (the level's own, ReplicatedStorage.TrainerModels.T<n>) and its
--                       level and name in the cash green
--   the stat            "+6 > +10 Oxygen/s": what the ride gives now and after (Config.Train.Levels' Oxygen)
--   the prices          a red cash block (FREE while Train.Free is 1) and a purple Robux block (Train.Robux: shown
--                       only, there is no product yet; no block when the level has no Robux price)
-- At the top level: MAXED, the seahorse you have in gold, what it gives, and one gold MAX LEVEL block.
-- Each plot's sign shows its owner's level (TrainerLevel, the server's; level 1 with no owner), so your own sign is
-- your own level and changes the moment you upgrade (with a little pop). Looked at twice a second: eight plots, and
-- a property is written only when it changes.
-- Upgrading is a click (or a tap) on the cash block of your own sign (task e2, Hugo 2026-11-20: no E): it asks the
-- server for the next level (Remotes.Trainer "Up"), which checks and charges everything (TrainService: your plot, on
-- the dock, within Train.UpgradeNear, not the top level, the price unless Train.Free is 1, one ask at a time). Here
-- only: your own sign, not maxed, near enough (else the block says WALK CLOSER), and one ask at a time (the block says
-- "..." until the server answers, and a press within Train.UpAgain of an ask is the same click). Everyone else's sign, and the Robux block, do nothing when clicked.
-- The plot's sign (task b1, Hugo 2026-11-22: "a second sign in EXACTLY the same style as the seahorse oxygen sign"):
-- the same board, made by the same code, on the part PlotBoard (AquariumService puts it in front of the far-left end
-- of the tank's front). It sells the plot's stages (Config.PlotUpgrades):
--   the title           UPGRADE TANK
--   the next tank       a little tank in the well, as tall as that stage makes it, and "STAGE 2/5" in the cash green
--   the stat            "9 > 11 Earning fish": how many fish may be equipped now and after (Config.earningOf)
--   the prices          the red cash block (the stage's price) and the purple Robux block (PlotUpgrades.Robux: shown
--                       only, as the seahorse's)
-- At the top stage: TANK MAXED!, STAGE 5/5 in gold and one gold MAX STAGE block. It shows its owner's "PlotStage";
-- a click on our own cash block asks Action "Plot", "Up" (AquariumService decides and charges: our plot, on the dock,
-- within PlotUpgrades.SignNear of the board). The server's no is said on the block for a moment (NOT ENOUGH COINS!).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Anim = require(script.Parent.Anim)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local UpgradeSign = {}

local EVERY = 0.5
local WAIT = 3 -- seconds an ask waits for the server's answer before the block is pressable again
local GOLD = Color3.fromRGB(255, 214, 70)

type Sign = {
	Kind: string, -- "Seahorse" (the trainer's levels) or "Plot" (the plot's stages)
	Board: BasePart,
	Gui: SurfaceGui,
	Pop: UIScale,
	Title: TextLabel,
	Name: TextLabel,
	Stat: TextLabel,
	Well: Frame,
	View: ViewportFrame,
	Icon: ImageLabel,
	Cash: Frame,
	CashText: TextLabel,
	CashHit: TextButton, -- the cash block's press (live only on our own sign)
	CashDip: UIScale,
	Robux: Frame,
	RobuxText: TextLabel,
	Shown: string, -- what it says now, as one key: nothing is rewritten while this holds
	Level: number,
	Plot: Instance,
}

local signs: { [Instance]: Sign } = {} -- by board

-- Our asks, one for each kind of sign. Pending: our ask for the next level, while the server has not answered (one at
-- a time: a double click buys one level). AskedAt: when we last asked (a press within UpAgain of it is the same
-- click). Saying: a word on our own cash block for a moment (WALK CLOSER)
type Ask = { Pending: { At: number, Level: number }?, AskedAt: number, Saying: { Text: string, Until: number }? }
local asks: { [string]: Ask } = {
	Seahorse = { Pending = nil, AskedAt = -math.huge, Saying = nil },
	Plot = { Pending = nil, AskedAt = -math.huge, Saying = nil },
}

-- What differs between the two signs: the map's part, its numbers, the owner's attribute and the levels' range
local KINDS: { [string]: { Board: string, Gui: string, Level: string, First: number, Icon: string } } = {
	Seahorse = { Board = "UpgradeBoard", Gui = "UpgradeSign_", Level = "TrainerLevel", First = 1, Icon = "Seahorse" },
	Plot = { Board = "PlotBoard", Gui = "PlotSign_", Level = "PlotStage", First = 0, Icon = "Bubble" },
}

local function numbers(kind: string)
	return if kind == "Plot" then Config.PlotUpgrades.Sign else Config.Train.Sign
end

local function topOf(kind: string): number
	return if kind == "Plot" then #Config.PlotUpgrades.Stages else #Config.Train.Levels
end

local function againOf(kind: string): number
	return if kind == "Plot" then Config.PlotUpgrades.UpAgain else Config.Train.UpAgain
end

-- A flat block in the shop's button look (Shop.button's lit top half, dark edge and scale pattern). The cash block
-- gets a press over it (make); the Robux block never does
local function block(parent: Instance, name: string, kind: string): (Frame, TextLabel, Frame)
	local frame: Frame = Kit.new("Frame", {
		Name = name,
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
	}, parent)
	Kit.corner(frame, 8)
	local pair = (Shop.Kinds :: any)[kind]
	Kit.new("UIGradient", { Rotation = 90, Color = Shop.halves(pair[1], pair[2]) }, frame)
	Kit.stroke(frame, 4, Shop.Edge).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Shop.pattern(frame, "Head", 36)
	Kit.new("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 0, 3),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, frame)
	local words: Frame = Kit.new("Frame", {
		Name = "Words",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, frame)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, words)
	local label = Shop.text(words, {
		Name = "Label",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = 60,
		LayoutOrder = 2,
		ZIndex = 3,
	})
	return frame, label, words
end

-- A block's colours, by a name in Shop.Kinds
local function fill(frame: Frame, kind: string)
	local gradient = frame:FindFirstChildOfClass("UIGradient")
	local pair = (Shop.Kinds :: any)[kind]
	if gradient then
		gradient.Color = Shop.halves(pair[1], pair[2])
	end
end

local function make(plot: Instance, board: BasePart, kind: string): Sign
	local s = numbers(kind)
	local px = s.PixelsPerStud
	local W, H = board.Size.X * px, board.Size.Y * px
	local gui: SurfaceGui = Kit.new("SurfaceGui", {
		Name = KINDS[kind].Gui .. plot.Name,
		Adornee = board,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = px,
		LightInfluence = 0,
		Brightness = 1.15,
		MaxDistance = s.Far,
		ResetOnSpawn = false,
		Active = true, -- (its cash block is pressed: task e2)
		ClipsDescendants = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	-- the board: the shop's dark slate with its bubble pattern and the thick dark border (the part behind is that
	-- border's colour, so the rounded corners sit on it)
	local face: Frame = Kit.new("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundColor3 = Shop.Body,
		BorderSizePixel = 0,
	}, gui)
	Kit.corner(face, 14)
	Kit.stroke(face, 6, Shop.Edge).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Kit.gradient(face, Kit.lighter(Shop.Body, 0.08), Shop.BodyDeep)
	Shop.pattern(face, "Body", 40)
	local pop: UIScale = Kit.new("UIScale", {}, face)
	local pad = 16
	local title = Shop.text(face, {
		Name = "Title",
		Position = UDim2.fromOffset(pad, 8),
		Size = UDim2.new(1, -pad * 2, 0, 62),
		TextSize = 54,
		Text = if kind == "Plot" then "UPGRADE TANK" else "UPGRADE SEAHORSE",
		TextScaled = true,
		ZIndex = 3,
	})
	Kit.new("UITextSizeConstraint", { MaxTextSize = 54 }, title)
	-- the next seahorse: a dark well with its model, beside its name and the stat line
	local wellSize = 124
	local top = 76
	local well = Shop.inset(face, {
		Name = "Well",
		Position = UDim2.fromOffset(pad + 4, top),
		Size = UDim2.fromOffset(wellSize, wellSize),
		ZIndex = 2,
	})
	Kit.gradient(well, Color3.fromRGB(60, 120, 170), Color3.fromRGB(24, 44, 78))
	local view: ViewportFrame = Kit.new("ViewportFrame", {
		Name = "View",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		ZIndex = 3,
	}, well)
	local icon = Shop.icon(well, KINDS[kind].Icon, wellSize - 16, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 3,
		Visible = false,
	})
	local textX = pad + wellSize + 22
	local name = Shop.text(face, {
		Name = "Next",
		Position = UDim2.fromOffset(textX, top + 6),
		Size = UDim2.new(1, -textX - pad, 0, 56),
		TextSize = 50,
		TextColor3 = Shop.Money,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		ZIndex = 3,
	})
	Kit.new("UITextSizeConstraint", { MaxTextSize = 50 }, name)
	local stat = Shop.text(face, {
		Name = "Stat",
		Position = UDim2.fromOffset(textX, top + 68),
		Size = UDim2.new(1, -textX - pad, 0, 44),
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		ZIndex = 3,
	})
	Kit.new("UITextSizeConstraint", { MaxTextSize = 40 }, stat)
	-- the prices, along the foot
	local rowTop = top + wellSize + 14
	local rowHigh = H - rowTop - pad - 4
	local cash, cashText = block(face, "Cash", "Red")
	cash.Position = UDim2.fromOffset(pad + 2, rowTop)
	cash.Size = UDim2.fromOffset(W * 0.6, rowHigh)
	cash.ZIndex = 2
	local robux, robuxText, robuxWords = block(face, "Robux", "Purple")
	robux.AnchorPoint = Vector2.new(1, 0)
	robux.Position = UDim2.new(1, -pad - 2, 0, rowTop)
	robux.Size = UDim2.new(1, -(pad + 2) * 2 - W * 0.6 - 14, 0, rowHigh)
	robux.ZIndex = 2
	robuxText.TextSize = 48
	-- the cash block's press: an invisible button over it, inside its bounds only (the Robux block, apart, has none)
	local cashDip: UIScale = Kit.new("UIScale", {}, cash)
	local cashHit: TextButton = Kit.new("TextButton", {
		Name = "Press",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		ZIndex = 10,
	}, cash)
	Kit.new("ImageLabel", {
		Name = "Sign",
		Size = UDim2.fromOffset(46, 46),
		BackgroundTransparency = 1,
		Image = Shop.Robux,
		ImageColor3 = Kit.White,
		ScaleType = Enum.ScaleType.Fit,
		LayoutOrder = 1,
		ZIndex = 3,
	}, robuxWords)
	return {
		Kind = kind,
		Board = board,
		Gui = gui,
		Pop = pop,
		Title = title,
		Name = name,
		Stat = stat,
		Well = well,
		View = view,
		Icon = icon,
		Cash = cash,
		CashText = cashText,
		CashHit = cashHit,
		CashDip = cashDip,
		Robux = robux,
		RobuxText = robuxText,
		Shown = "",
		Level = 0,
		Plot = plot,
	}
end

-- The level's seahorse in the well, side on, facing right (the reference's portrait); the shop's icon when the
-- level models are not installed
local function portrait(sign: Sign, level: number)
	sign.View:ClearAllChildren()
	local templates = ReplicatedStorage:FindFirstChild("TrainerModels")
	local template = templates and templates:FindFirstChild("T" .. level)
	local toy = template and template:FindFirstChild("Toy")
	if not (toy and toy:IsA("Model")) then
		sign.Icon.Visible = true
		return
	end
	sign.Icon.Visible = false
	local copy = toy:Clone()
	copy.Parent = sign.View
	local at, size = copy:GetBoundingBox()
	-- (the models face their -Z: seen from their +X side the head is on the right)
	local fov = 30
	local reach = math.max(size.Y, size.Z) / 2 / math.tan(math.rad(fov / 2)) * 1.08 + size.X / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(at.Position + at.RightVector * reach, at.Position, at.UpVector)
	camera.Parent = sign.View
	sign.View.CurrentCamera = camera
end

-- A little tank in the well, as tall as a stage makes it (the map's tank in a few boxes: base, sand, water, corner
-- posts and rim). The view is set for the tallest stage, so each stage shows taller than the one before
local TANK_WIDE, TANK_DEEP, TANK_HIGH = 52, 44, 14
local function tankPortrait(sign: Sign, stage: number)
	sign.View:ClearAllChildren()
	sign.Icon.Visible = false
	local p = Config.PlotUpgrades
	local high = TANK_HIGH + p.Taller * stage
	local most = TANK_HIGH + p.Taller * #p.Stages
	local model = Instance.new("Model")
	local function box(size: Vector3, at: Vector3, colour: Color3, clear: number?)
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = size
		part.Position = at
		part.Color = colour
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = clear or 0
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
	end
	local frame = Color3.fromRGB(238, 242, 250)
	box(Vector3.new(TANK_WIDE + 3, 3, TANK_DEEP + 3), Vector3.new(0, 1.5, 0), Color3.fromRGB(70, 82, 110))
	box(Vector3.new(TANK_WIDE, 1.2, TANK_DEEP), Vector3.new(0, 3.6, 0), Color3.fromRGB(240, 220, 160))
	box(Vector3.new(TANK_WIDE, high, TANK_DEEP), Vector3.new(0, 3 + high / 2, 0), Color3.fromRGB(70, 180, 255), 0.45)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			box(
				Vector3.new(3, high + 1, 3),
				Vector3.new(x * TANK_WIDE / 2, 3 + (high + 1) / 2, z * TANK_DEEP / 2),
				frame
			)
		end
		box(Vector3.new(2.4, 2.4, TANK_DEEP), Vector3.new(x * TANK_WIDE / 2, 3 + high, 0), frame)
		box(Vector3.new(TANK_WIDE, 2.4, 2.4), Vector3.new(0, 3 + high, x * TANK_DEEP / 2), frame)
	end
	model.Parent = sign.View
	local fov = 30
	local middle = Vector3.new(0, (most + 4) / 2, 0)
	local reach = math.max(most + 6, TANK_WIDE * 1.25) / 2 / math.tan(math.rad(fov / 2)) * 1.12
	local camera = Instance.new("Camera")
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(middle + Vector3.new(-0.55, 0.32, 1).Unit * reach, middle)
	camera.Parent = sign.View
	sign.View.CurrentCamera = camera
end

-- The level a plot's sign shows: its owner's (the server's attribute), the first with no owner
local function ownerLevel(plot: Instance, kind: string): number
	local k = KINDS[kind]
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Plot") == plot.Name then
			local level = player:GetAttribute(k.Level)
			return if type(level) == "number" then level else k.First
		end
	end
	return k.First
end

-- The plot's sign (task b1): the same blocks, the plot's stages
local function writePlot(sign: Sign, stage: number)
	local p = Config.PlotUpgrades
	local top = #p.Stages
	stage = math.clamp(stage, 0, top)
	local free = p.Free == 1
	local robux = (p.Robux or {})[stage + 1] or 0
	local own = sign.Plot.Name == Players.LocalPlayer:GetAttribute("Plot")
	local ask = asks.Plot
	local word = if own and ask.Pending then "..." elseif own and ask.Saying then ask.Saying.Text else ""
	local key = string.format("%d/%s/%d/%s", stage, tostring(free), robux, word)
	if sign.Shown == key then
		return
	end
	local first = sign.Shown == ""
	sign.Shown = key
	local wide = sign.Board.Size.X * p.Sign.PixelsPerStud
	if stage >= top then
		sign.Title.Text = "TANK MAXED!"
		sign.Name.Text = string.format("STAGE %d/%d", stage, top)
		sign.Name.TextColor3 = GOLD
		sign.Stat.Text = string.format("%d Earning fish", Config.earningOf(stage))
		tankPortrait(sign, stage)
		sign.Robux.Visible = false
		sign.Cash.Size = UDim2.new(1, -36, 0, sign.Cash.Size.Y.Offset)
		fill(sign.Cash, "Gold")
		sign.CashText.Text = "MAX STAGE"
	else
		sign.Title.Text = "UPGRADE TANK"
		sign.Name.Text = string.format("STAGE %d/%d", stage + 1, top)
		sign.Name.TextColor3 = Shop.Money
		sign.Stat.Text = string.format("%d > %d Earning fish", Config.earningOf(stage), Config.earningOf(stage + 1))
		tankPortrait(sign, stage + 1)
		sign.CashText.Text = if word ~= "" then word elseif free then "FREE" else Shop.cash(p.Stages[stage + 1].Price)
		sign.CashText.TextSize = if #sign.CashText.Text > 11 then 34 elseif #sign.CashText.Text > 8 then 44 else 60
		fill(sign.Cash, "Red")
		if robux > 0 then
			sign.Robux.Visible = true
			sign.RobuxText.Text = Kit.short(robux)
			sign.Cash.Size = UDim2.fromOffset(wide * 0.6, sign.Cash.Size.Y.Offset)
		else
			sign.Robux.Visible = false
			sign.Cash.Size = UDim2.new(1, -36, 0, sign.Cash.Size.Y.Offset)
		end
	end
	-- a stage bought: the board pops (not when it is first written)
	if not first and sign.Level >= 0 and stage ~= sign.Level then
		sign.Pop.Scale = 1.12
		TweenService
			:Create(sign.Pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	sign.Level = stage
end

local function write(sign: Sign, level: number)
	if sign.Kind == "Plot" then
		writePlot(sign, level)
		return
	end
	local pending, saying = asks.Seahorse.Pending, asks.Seahorse.Saying
	local t = Config.Train
	local levels = t.Levels
	local top = #levels
	level = math.clamp(level, 1, top)
	local free = t.Free == 1
	local robux = (t.Robux or {})[level + 1] or 0
	local own = sign.Plot.Name == Players.LocalPlayer:GetAttribute("Plot")
	local word = if own and pending then "..." elseif own and saying then saying.Text else ""
	local key = string.format("%d/%s/%d/%s", level, tostring(free), robux, word)
	if sign.Shown == key then
		return
	end
	local first = sign.Shown == ""
	sign.Shown = key
	local now = levels[level]
	if level >= top then
		sign.Title.Text = "SEAHORSE MAXED!"
		sign.Name.Text = string.format("LV %d %s", level, string.upper(now.Name))
		sign.Name.TextColor3 = GOLD
		sign.Stat.Text = string.format("+%s Oxygen/s", Config.wholeNumber(now.Oxygen)) -- (whole: task e1)
		portrait(sign, level)
		sign.Robux.Visible = false
		sign.Cash.Size = UDim2.new(1, -36, 0, sign.Cash.Size.Y.Offset)
		fill(sign.Cash, "Gold")
		sign.CashText.Text = "MAX LEVEL"
	else
		local after = levels[level + 1]
		sign.Title.Text = "UPGRADE SEAHORSE"
		sign.Name.Text = string.format("LV %d %s", level + 1, string.upper(after.Name))
		sign.Name.TextColor3 = Shop.Money
		sign.Stat.Text =
			string.format("+%s > +%s Oxygen/s", Config.wholeNumber(now.Oxygen), Config.wholeNumber(after.Oxygen))
		portrait(sign, level + 1)
		sign.CashText.Text = if word ~= "" then word elseif free then "FREE" else Shop.cash(after.Price)
		local wide = sign.Board.Size.X * t.Sign.PixelsPerStud
		fill(sign.Cash, "Red")
		if robux > 0 then
			sign.Robux.Visible = true
			sign.RobuxText.Text = Kit.short(robux)
			sign.Cash.Size = UDim2.fromOffset(wide * 0.6, sign.Cash.Size.Y.Offset)
		else
			sign.Robux.Visible = false
			sign.Cash.Size = UDim2.new(1, -36, 0, sign.Cash.Size.Y.Offset)
		end
	end
	-- a level up: the board pops (not when it is first written)
	if not first and sign.Level ~= 0 and level ~= sign.Level then
		sign.Pop.Scale = 1.12
		TweenService
			:Create(sign.Pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	sign.Level = level
end

-- Near enough to upgrade, flat: within Train.UpgradeNear of our ride (its TrainerSpot, where the server's coil foot
-- is) or within Train.SignNear of the sign's board (standing in front of it to read it). TrainService checks the same.
-- The plot's sign: within PlotUpgrades.SignNear of its board (AquariumService checks the same)
local function nearOwn(sign: Sign): boolean
	local plot, board = sign.Plot, sign.Board
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local flat = Vector3.new(1, 0, 1)
	local toBoard = ((board.Position - root.Position) * flat).Magnitude
	if sign.Kind == "Plot" then
		return toBoard <= Config.PlotUpgrades.SignNear
	end
	local spot = plot:FindFirstChild("TrainerSpot")
	local toRide = if spot and spot:IsA("BasePart")
		then ((spot.Position - root.Position) * flat).Magnitude
		else math.huge
	return toRide <= Config.Train.UpgradeNear or toBoard <= Config.Train.SignNear
end

-- Would a press on this sign's cash block buy: our own, not at its top, the coins for it, near enough, nothing pending
local function canUp(sign: Sign): boolean
	local me = Players.LocalPlayer
	local level = me:GetAttribute(KINDS[sign.Kind].Level)
	if sign.Plot.Name ~= me:GetAttribute("Plot") or type(level) ~= "number" or level >= topOf(sign.Kind) then
		return false
	end
	local plot = sign.Kind == "Plot"
	local after: any = if plot then Config.PlotUpgrades.Stages[level + 1] else Config.Train.Levels[level + 1]
	local free = (if plot then Config.PlotUpgrades.Free else Config.Train.Free) == 1
	local coins = me:GetAttribute("Coins")
	local paid = free or (after ~= nil and type(coins) == "number" and coins >= after.Price)
	return paid and not asks[sign.Kind].Pending and nearOwn(sign)
end

local function remote(): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local r = remotes and remotes:FindFirstChild("Trainer")
	return if r and r:IsA("RemoteEvent") then r else nil
end

-- A click or tap on a sign's cash block: only our own sign asks, once, while nothing is pending
local function press(sign: Sign)
	local me = Players.LocalPlayer
	local ask = asks[sign.Kind]
	if sign.Plot.Name ~= me:GetAttribute("Plot") or ask.Pending or os.clock() - ask.AskedAt < againOf(sign.Kind) then
		return
	end
	local level = me:GetAttribute(KINDS[sign.Kind].Level)
	local r = remote()
	if type(level) ~= "number" or level >= topOf(sign.Kind) or (sign.Kind == "Seahorse" and not r) then
		return
	end
	sign.CashDip.Scale = 0.94
	task.delay(0.12, function()
		sign.CashDip.Scale = 1
	end)
	if not nearOwn(sign) then
		ask.Saying = { Text = "WALK CLOSER!", Until = os.clock() + 1.6 }
	else
		ask.AskedAt = os.clock()
		ask.Pending = { At = ask.AskedAt, Level = level }
		if sign.Kind == "Plot" then
			Net.Action:FireServer("Plot", "Up")
		elseif r then
			r:FireServer("Up")
		end
	end
	write(sign, level)
end

-- The server's answer ends our ask. The seahorse: Remotes.Trainer "Up", level | "UpNo", why (TrainerController says
-- it in a banner). The plot: Ride "PlotUp", stage | "PlotNo", why, said on the cash block for a moment
local PLOT_NO = {
	Coins = "NOT ENOUGH COINS!",
	Near = "WALK CLOSER!",
	Top = "MAX STAGE",
	Busy = "GET OFF FIRST!",
}
local listening: RemoteEvent? = nil
local listeningPlot = false
local function listen()
	if not listeningPlot then
		listeningPlot = true
		Net.Ride.OnClientEvent:Connect(function(what: string, why: any)
			if what == "PlotUp" then
				asks.Plot.Pending = nil
			elseif what == "PlotNo" then
				asks.Plot.Pending = nil
				asks.Plot.Saying = { Text = PLOT_NO[tostring(why)] or "NOT NOW", Until = os.clock() + 1.8 }
			end
		end)
	end
	local r = remote()
	if not r or r == listening then
		return
	end
	listening = r
	r.OnClientEvent:Connect(function(what: string)
		if what == "Up" or what == "UpNo" then
			asks.Seahorse.Pending = nil
		end
	end)
end

local function look()
	listen()
	local now = os.clock()
	local me = Players.LocalPlayer
	for kind, ask in asks do
		if ask.Pending then
			local level = me:GetAttribute(KINDS[kind].Level)
			if now - ask.Pending.At > WAIT or (type(level) == "number" and level ~= ask.Pending.Level) then
				ask.Pending = nil
			end
		end
		if ask.Saying and now > ask.Saying.Until then
			ask.Saying = nil
		end
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local plots = dock and dock:FindFirstChild("Plots")
	for board, sign in signs do
		if sign.Plot.Parent == nil or sign.Board.Parent == nil then
			sign.Gui:Destroy()
			signs[board] = nil
		end
	end
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		for kind, k in KINDS do
			local board = plot:FindFirstChild(k.Board)
			if board and board:IsA("BasePart") and not (kind == "Plot" and Config.PlotUpgrades.On == 0) then
				local sign = signs[board]
				if not sign then
					local made = make(plot, board, kind)
					made.Level = -1
					made.CashHit.Activated:Connect(function()
						press(made)
					end)
					Anim.shine(made.Cash, 8, function()
						return canUp(made)
					end)
					sign = made
					signs[board] = made
				end
				local s = sign :: Sign
				local level = ownerLevel(plot, kind)
				local live = plot.Name == me:GetAttribute("Plot") and level < topOf(kind)
				if s.CashHit.Active ~= live then
					s.CashHit.Active = live
					s.CashHit.Selectable = live
				end
				write(s, level)
			end
		end
	end
end

function UpgradeSign.start()
	task.spawn(function()
		while true do
			local ok, err = pcall(look)
			if not ok then
				warn("[UpgradeSign]", err)
			end
			task.wait(EVERY)
		end
	end)
end

-- (for Studio's tests: press a sign's cash block as a click does, our own or the named plot's, the seahorse's or with
-- kind "Plot" the plot's; true when there was one)
-- Test hook: only the Studio checks call this (tools/studio/b1_inventory_check.py, e2_click_check.py).
function UpgradeSign.press(plotName: string?, kind: string?): boolean
	local want = plotName or Players.LocalPlayer:GetAttribute("Plot")
	for _, sign in signs do
		if sign.Plot.Name == want and sign.Kind == (kind or "Seahorse") then
			press(sign)
			return true
		end
	end
	return false
end

-- (for captures: rewrite every sign now, e.g. after changing Config.Train.Free on this machine)
-- Test hook: only the Studio checks call this (tools/studio/e2_click_check.py).
function UpgradeSign.refresh()
	for _, sign in signs do
		sign.Shown = "-"
	end
	look()
end

return UpgradeSign
