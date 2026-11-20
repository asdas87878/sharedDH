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
-- a property is written only when it changes. Upgrading is still the prompt by the ride (E: TrainerController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local UpgradeSign = {}

local EVERY = 0.5
local GOLD = Color3.fromRGB(255, 214, 70)

type Sign = {
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
	Robux: Frame,
	RobuxText: TextLabel,
	Shown: string, -- what it says now, as one key: nothing is rewritten while this holds
	Level: number,
}

local signs: { [Instance]: Sign } = {} -- by plot

-- A flat block in the shop's button look (Shop.button's lit top half, dark edge and scale pattern), not pressable:
-- the sign is read, not clicked
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
	Shop.pattern(frame, "Head", 36, 0.88)
	Kit.new("Frame", {
		Name = "Lip",
		Position = UDim2.new(0, 6, 0, 4),
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
		Size = UDim2.new(0, 0, 1, 0),
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

local function make(plot: Instance, board: BasePart): Sign
	local s = Config.Train.Sign
	local px = s.PixelsPerStud
	local W, H = board.Size.X * px, board.Size.Y * px
	local gui: SurfaceGui = Kit.new("SurfaceGui", {
		Name = "UpgradeSign_" .. plot.Name,
		Adornee = board,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = px,
		LightInfluence = 0,
		Brightness = 1.15,
		MaxDistance = s.Far,
		ResetOnSpawn = false,
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
	Shop.pattern(face, "Body", 48, 0.9)
	Shop.gloss(face, 0.82, 0.08)
	local pop: UIScale = Kit.new("UIScale", {}, face)
	local pad = 16
	local title = Shop.text(face, {
		Name = "Title",
		Position = UDim2.fromOffset(pad, 8),
		Size = UDim2.new(1, -pad * 2, 0, 62),
		TextSize = 54,
		Text = "UPGRADE SEAHORSE",
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
	local icon = Shop.icon(well, "Seahorse", wellSize - 16, {
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
		Robux = robux,
		RobuxText = robuxText,
		Shown = "",
		Level = 0,
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

local function ownerLevel(plot: Instance): number
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Plot") == plot.Name then
			local level = player:GetAttribute("TrainerLevel")
			return if type(level) == "number" then level else 1
		end
	end
	return 1
end

local function write(sign: Sign, level: number)
	local t = Config.Train
	local levels = t.Levels
	local top = #levels
	level = math.clamp(level, 1, top)
	local free = t.Free == 1
	local robux = (t.Robux or {})[level + 1] or 0
	local key = string.format("%d/%s/%d", level, tostring(free), robux)
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
		sign.CashText.Text = if free then "FREE" else Shop.cash(after.Price)
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
	if not first and level ~= sign.Level then
		sign.Pop.Scale = 1.12
		TweenService
			:Create(sign.Pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	sign.Level = level
end

local function look()
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local plots = dock and dock:FindFirstChild("Plots")
	for plot, sign in signs do
		if plot.Parent == nil or sign.Board.Parent == nil then
			sign.Gui:Destroy()
			signs[plot] = nil
		end
	end
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		local board = plot:FindFirstChild("UpgradeBoard")
		if board and board:IsA("BasePart") then
			local sign = signs[plot]
			if sign and sign.Board ~= board then
				sign.Gui:Destroy()
				sign = nil
			end
			if not sign then
				sign = make(plot, board)
				signs[plot] = sign
			end
			write(sign :: Sign, ownerLevel(plot))
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

-- (for captures: rewrite every sign now, e.g. after changing Config.Train.Free on this machine)
function UpgradeSign.refresh()
	for _, sign in signs do
		sign.Shown = "-"
	end
	look()
end

return UpgradeSign
