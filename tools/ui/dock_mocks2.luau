-- Two mock-ups after the user's pick of 2026-11-16 (docs/design/ui.md, "After the pick"): looks only, stand-in words
-- and numbers, nothing behind them. Run in Studio's Edit mode with WHICH:
--   "sidebar"  your tank's panel as a narrow sidebar at the right, so the aquarium stays in view while it is open
--              (it replaces the wide tank panel of tools/ui/panel_mocks.luau);
--   "upgrade"  the trainer's sign with its level and the next ride's price on it, coins and Robux side by side
--              (it replaces the trainer panel: the upgrade lives on the model);
--   ""         takes both away.
-- It makes StarterGui.UiPanelMock, Workspace.UiOptions and "UiMock" signs on Plot2's board, none of which may be
-- saved with the place.
-- (The pictures of 2026-11-16 in docs/attachments, ui8-tank-sidebar.jpg and ui8-trainer-upgrade.jpg, are these two
-- as Studio drew them, laid over a capture of the hub: Studio was drawing no 3D at the time.)
local WHICH = "sidebar"

local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local INK = Color3.fromRGB(16, 36, 63)
local DEEP = Color3.fromRGB(10, 24, 44)
local CARD = Color3.fromRGB(22, 46, 82)
local WHITE = Color3.new(1, 1, 1)
local PALE = Color3.fromRGB(170, 200, 236)
local GOLD = Color3.fromRGB(255, 196, 44)
local GREEN = Color3.fromRGB(72, 200, 84)
local AQUA = Color3.fromRGB(51, 200, 240)
local RED = Color3.fromRGB(232, 62, 62)
local BLUE = Color3.fromRGB(30, 140, 255)
local STUDS = "rbxassetid://124244361010023" -- the map's stud tile, uploaded long ago
local ROBUX = utf8.char(0xE002)
local RARITY = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 90),
	Rare = Color3.fromRGB(70, 150, 255),
}

local plot = workspace.ClaudeBlockout.Dock.Plots.Plot2
for _, name in { "UiPanelMock" } do
	local old = StarterGui:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local oldWorld = workspace:FindFirstChild("UiOptions")
if oldWorld then
	oldWorld:Destroy()
end
for _, d in plot:GetDescendants() do
	if d.Name == "UiMock" then
		d:Destroy()
	end
end
if WHICH == "" then
	return "removed"
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function lighter(c, a)
	return c:Lerp(WHITE, a)
end
local function darker(c, a)
	return c:Lerp(Color3.new(0, 0, 0), a)
end
local function box(parent, x, y, w, h, colour, see, round, z)
	local f = new(
		"Frame",
		{
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			BackgroundColor3 = colour,
			BackgroundTransparency = see or 0,
			BorderSizePixel = 0,
			ZIndex = z or 1,
		},
		parent
	)
	new("UICorner", { CornerRadius = UDim.new(round or 0.1, 0) }, f)
	return f
end
local function text(parent, x, y, w, h, words, colour, edge, align, z, font)
	local label = new(
		"TextLabel",
		{
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			Font = font or Enum.Font.FredokaOne,
			Text = words,
			TextColor3 = colour or WHITE,
			TextScaled = true,
			TextXAlignment = align or Enum.TextXAlignment.Center,
			ZIndex = z or 3,
		},
		parent
	)
	if edge ~= 0 then
		new("UIStroke", { Thickness = edge or 2, Color = INK, LineJoinMode = Enum.LineJoinMode.Round }, label)
	end
	return label
end
local function studs(parent, tile)
	new(
		"ImageLabel",
		{
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = STUDS,
			ImageTransparency = 0.6,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromScale(tile, 1),
			ZIndex = 2,
		},
		parent
	)
end
local function button(parent, x, y, w, h, colour, words, font)
	box(parent, x, y + h * 0.1, w, h, darker(colour, 0.5), 0, 0.28, 2)
	local b = box(parent, x, y, w, h, colour, 0, 0.28, 3)
	new("UIGradient", { Color = ColorSequence.new(lighter(colour, 0.3), colour), Rotation = 90 }, b)
	new("UIStroke", { Thickness = 2.5, Color = INK }, b)
	local clip = new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3 },
		b
	)
	new("UICorner", { CornerRadius = UDim.new(0.28, 0) }, clip)
	studs(clip, 0.16)
	text(b, 0.06, 0.16, 0.88, 0.68, words, WHITE, 2.2, nil, 4, font)
	return b
end
local function picture(parent, x, y, w, h, id)
	local view = new(
		"ViewportFrame",
		{
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(190, 195, 205),
			LightDirection = Vector3.new(0.5, -1, 0.4),
			ZIndex = 3,
		},
		parent
	)
	local folder = ReplicatedStorage:FindFirstChild("FishModels")
	local source = folder and folder:FindFirstChild(id)
	if not source then
		return view
	end
	local model = source:Clone()
	model:PivotTo(CFrame.new())
	model.Parent = view
	local at, size = model:GetBoundingBox()
	local camera = new("Camera", { FieldOfView = 22 }, view)
	local away = (size.Magnitude / 2) / math.tan(math.rad(11)) * 0.9
	camera.CFrame = CFrame.lookAt(at.Position + Vector3.new(-1, 0.3, -0.55).Unit * away, at.Position)
	view.CurrentCamera = camera
	return view
end

-- the tank's own sign as it is in the game since the pick (style B), so the pictures show the hub as it will be
local board = plot:FindFirstChild("SignBoard")
if board then
	for _, side in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = new(
			"SurfaceGui",
			{
				Name = "UiMock",
				Face = side,
				SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
				PixelsPerStud = 24,
				LightInfluence = 0,
			},
			board
		)
		local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLUE, BorderSizePixel = 0 }, gui)
		local band =
			new("Frame", { Size = UDim2.fromScale(1, 0.3), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, root)
		new(
			"TextLabel",
			{
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.03, 0.08),
				Size = UDim2.fromScale(0.94, 0.84),
				Font = Enum.Font.LuckiestGuy,
				Text = "YOUR TANK",
				TextScaled = true,
				TextColor3 = BLUE,
			},
			band
		)
		text(root, 0.03, 0.34, 0.94, 0.6, "$31.6 a second", WHITE, 3, nil, 2, Enum.Font.LuckiestGuy)
	end
end

if WHICH == "sidebar" then
	local gui = new("ScreenGui", { Name = "UiPanelMock", ResetOnSpawn = false }, StarterGui)
	-- narrow, at the right edge, as tall as the screen allows: its shape is held, so its width follows its height
	local holder = new(
		"Frame",
		{
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.988, 0.5),
			Size = UDim2.fromScale(0.34, 0.9),
			BackgroundTransparency = 1,
		},
		gui
	)
	new("UIAspectRatioConstraint", { AspectRatio = 0.52, DominantAxis = Enum.DominantAxis.Height }, holder)
	box(holder, 0, 0.012, 1, 1, darker(DEEP, 0.55), 0.25, 0.06)
	local body = box(holder, 0, 0, 1, 1, DEEP, 0.08, 0.06, 2)
	new("UIStroke", { Thickness = 3.5, Color = INK }, body)
	local head = box(body, 0.03, 0.012, 0.94, 0.075, GOLD, 0, 0.3, 2)
	new("UIGradient", { Color = ColorSequence.new(lighter(GOLD, 0.3), darker(GOLD, 0.1)), Rotation = 90 }, head)
	new("UIStroke", { Thickness = 2.5, Color = INK }, head)
	local clip = new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2 },
		head
	)
	new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, clip)
	studs(clip, 0.14)
	text(head, 0.05, 0.14, 0.7, 0.72, "YOUR TANK", WHITE, 2.6, Enum.TextXAlignment.Left)
	local close = box(head, 0.84, 0.12, 0.13, 0.76, RED, 0, 0.3, 3)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, close)
	new("UIStroke", { Thickness = 2.5, Color = INK }, close)
	text(close, 0.15, 0.1, 0.7, 0.8, "X", WHITE, 2, nil, 4)
	-- what it earns, and the collect button
	local earn = box(body, 0.03, 0.1, 0.94, 0.165, CARD, 0.1, 0.1, 2)
	new("UIStroke", { Thickness = 2, Color = INK }, earn)
	text(earn, 0.05, 0.07, 0.4, 0.2, "EARNING", PALE, 1.4, Enum.TextXAlignment.Left)
	text(earn, 0.4, 0.05, 0.56, 0.26, "$31.6 a second", GOLD, 2, Enum.TextXAlignment.Right)
	button(earn, 0.05, 0.4, 0.9, 0.46, GREEN, "COLLECT $1,204")
	-- the fish, one a row, the best earner first
	text(body, 0.05, 0.278, 0.5, 0.03, "4 of 8 fish", PALE, 1.4, Enum.TextXAlignment.Left)
	local FISH = {
		{ "Seahorse", "Rare", "Seahorse", "$18.0" },
		{ "Stingray", "Uncommon", "Stingray", "$8.4" },
		{ "YellowTang", "Common", "Yellow Tang", "$2.8" },
		{ "Boxfish", "Common", "Boxfish", "$2.4" },
	}
	for i = 1, 5 do
		local fish = FISH[i]
		local y = 0.315 + (i - 1) * 0.094
		local row = box(body, 0.03, y, 0.94, 0.086, CARD, if fish then 0.1 else 0.55, 0.16, 2)
		new("UIStroke", { Thickness = 2, Color = INK }, row)
		if fish then
			local colour = RARITY[fish[2]]
			local tile = box(row, 0.015, 0.07, 0.24, 0.86, colour, 0.05, 0.16, 3)
			new(
				"UIGradient",
				{ Color = ColorSequence.new(lighter(colour, 0.45), darker(colour, 0.1)), Rotation = 90 },
				tile
			)
			picture(tile, 0.04, 0.02, 0.92, 0.96, fish[1])
			text(row, 0.29, 0.12, 0.42, 0.42, fish[3], WHITE, 1.8, Enum.TextXAlignment.Left)
			text(
				row,
				0.29,
				0.56,
				0.42,
				0.3,
				string.upper(fish[2]),
				lighter(colour, 0.25),
				1.2,
				Enum.TextXAlignment.Left
			)
			text(row, 0.66, 0.14, 0.31, 0.44, fish[4], GOLD, 1.8, Enum.TextXAlignment.Right)
			text(row, 0.66, 0.58, 0.31, 0.26, "a second", PALE, 1.2, Enum.TextXAlignment.Right)
		else
			text(row, 0.1, 0.26, 0.8, 0.48, "4 empty places", PALE, 0)
		end
	end
	button(body, 0.03, 0.795, 0.94, 0.062, AQUA, "KEEP THE BEST")
	text(body, 0.05, 0.873, 0.9, 0.03, "More room, 12 fish:", PALE, 1.4, Enum.TextXAlignment.Left)
	button(body, 0.03, 0.912, 0.45, 0.062, GOLD, "$9,000")
	button(body, 0.52, 0.912, 0.45, 0.062, GREEN, ROBUX .. " 79")
elseif WHICH == "upgrade" then
	-- the trainer's sign as it would read with the upgrade: today's two lines, then the level and the next ride
	local spot = plot:FindFirstChild("TrainerSpot")
	local folder = new("Folder", { Name = "UiOptions" }, workspace)
	local gui = new(
		"BillboardGui",
		{
			Name = "TrainUpgrade",
			Adornee = spot,
			Size = UDim2.fromScale(19, 13.5),
			StudsOffsetWorldSpace = Vector3.new(0, 24.5, 0),
			MaxDistance = 220,
			LightInfluence = 0,
		},
		folder
	)
	local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	box(root, 0, 0.04, 1, 0.96, darker(BLUE, 0.6), 0, 0.06)
	local face = box(root, 0, 0, 1, 0.96, BLUE, 0, 0.06, 2)
	new("UIStroke", { Thickness = 4, Color = WHITE }, face)
	new("UIGradient", { Color = ColorSequence.new(lighter(BLUE, 0.18), darker(BLUE, 0.12)), Rotation = 90 }, face)
	local lucky = Enum.Font.LuckiestGuy
	text(face, 0.06, 0.04, 0.88, 0.26, "TRAIN", WHITE, 3, nil, 3, lucky)
	text(face, 0.06, 0.3, 0.88, 0.09, "stand on it: more Oxygen", Color3.fromRGB(214, 234, 255), 1.5, nil, 3, lucky)
	local level = box(face, 0.05, 0.43, 0.9, 0.13, WHITE, 0, 0.3, 3)
	text(level, 0.04, 0.12, 0.92, 0.76, "LEVEL 1: +1 A SECOND", BLUE, 0, nil, 4, lucky)
	text(face, 0.06, 0.6, 0.88, 0.1, "NEXT, LEVEL 2: +3 A SECOND", WHITE, 1.8, nil, 3, lucky)
	button(face, 0.05, 0.74, 0.43, 0.19, GOLD, "$1,200", lucky)
	button(face, 0.52, 0.74, 0.43, 0.19, GREEN, ROBUX .. " 29", lucky)
end
return "built " .. WHICH
