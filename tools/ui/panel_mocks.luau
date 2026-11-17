-- The dock's panels as looks only (docs/design/ui.md, "The dock's panels", 2026-11-16): the shop (auras), the tank,
-- the trainer and the Index, with stand-in words and numbers. Nothing is behind them. Run in Studio's Edit mode with
-- WHICH "auras", "tank", "trainer" or "index"; "" takes the mock away. It makes one ScreenGui, StarterGui.UiPanelMock,
-- which must never be saved with the place.
-- The rules it is built by (docs/Findings.md): a dark blue panel, a little see-through, never black; a darker copy
-- nudged down as its shadow; studs on the header and the buttons only; every size a share of the panel, and the
-- panel's shape held by an aspect-ratio constraint, so a phone gets the same panel smaller; a price on the thing it
-- buys, coins and Robux side by side; a ladder shown as your next step only.
local WHICH = "auras"

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
local STUDS = "rbxassetid://124244361010023" -- the map's stud tile, uploaded long ago
local ROBUX = utf8.char(0xE002)
local FONT = Enum.Font.FredokaOne
local RARITY = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 90),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
}

local old = StarterGui:FindFirstChild("UiPanelMock")
if old then
	old:Destroy()
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
local function text(parent, x, y, w, h, words, colour, edge, align, z)
	local label = new(
		"TextLabel",
		{
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			Font = FONT,
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
-- a button: its colour lighter at the top, studs, a darker copy under it
local function button(parent, x, y, w, h, colour, words)
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
	text(b, 0.06, 0.16, 0.88, 0.68, words, WHITE, 2.2, nil, 4)
	return b
end
-- both prices, side by side, on the thing they buy: coins and Robux
local function prices(parent, x, y, w, h, coins, robux)
	button(parent, x, y, w * 0.48, h, GOLD, "$" .. coins)
	button(parent, x + w * 0.52, y, w * 0.48, h, GREEN, ROBUX .. " " .. robux)
end
-- a creature's picture: its own model in a small window (no upload)
local function picture(parent, x, y, w, h, id, hidden)
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
	if hidden then
		view.ImageColor3 = Color3.new(0, 0, 0)
		view.ImageTransparency = 0.45
	end
	return view
end

local gui = new("ScreenGui", { Name = "UiPanelMock", ResetOnSpawn = false }, StarterGui)

-- the panel: a share of the screen, its shape held, a darker copy under it, a header in its station's colour
local function panel(title, colour, sub)
	local holder = new(
		"Frame",
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.78),
			BackgroundTransparency = 1,
		},
		gui
	)
	new("UIAspectRatioConstraint", { AspectRatio = 1.45 }, holder)
	box(holder, 0, 0.025, 1, 1, darker(DEEP, 0.55), 0.25, 0.05)
	local body = box(holder, 0, 0, 1, 1, DEEP, 0.08, 0.05, 2)
	new("UIStroke", { Thickness = 3.5, Color = INK }, body)
	local head = box(body, 0.015, 0.02, 0.97, 0.135, colour, 0, 0.3, 2)
	new("UIGradient", { Color = ColorSequence.new(lighter(colour, 0.3), darker(colour, 0.1)), Rotation = 90 }, head)
	new("UIStroke", { Thickness = 2.5, Color = INK }, head)
	local clip = new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2 },
		head
	)
	new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, clip)
	studs(clip, 0.06)
	text(head, 0.03, 0.12, 0.5, 0.76, title, WHITE, 3, Enum.TextXAlignment.Left)
	if sub then
		text(head, 0.42, 0.3, 0.44, 0.44, sub, lighter(colour, 0.8), 1.8, Enum.TextXAlignment.Right)
	end
	local close = box(head, 0.905, 0.12, 0.075, 0.76, RED, 0, 0.3, 3)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, close)
	new("UIStroke", { Thickness = 2.5, Color = INK }, close)
	text(close, 0.15, 0.1, 0.7, 0.8, "X", WHITE, 2, nil, 4)
	return body
end
local function card(body, x, y, w, h)
	local c = box(body, x, y, w, h, CARD, 0.1, 0.07, 2)
	new("UIStroke", { Thickness = 2, Color = INK }, c)
	return c
end

if WHICH == "auras" then
	local body = panel("AURAS", Color3.fromRGB(186, 72, 232), "ride every fish for longer")
	-- what you have now
	local now = card(body, 0.03, 0.19, 0.29, 0.6)
	text(now, 0.06, 0.04, 0.88, 0.11, "YOU HAVE", PALE, 1.5)
	local orb = box(now, 0.27, 0.2, 0.46, 0.4, Color3.fromRGB(120, 200, 255), 0.25, 0.5, 3)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, orb)
	new("UIStroke", { Thickness = 3, Color = WHITE, Transparency = 0.3 }, orb)
	text(now, 0.06, 0.63, 0.88, 0.14, "Bubble Aura", WHITE, 2)
	text(now, 0.06, 0.8, 0.88, 0.13, "x1.5 Oxygen", AQUA, 1.8)
	text(body, 0.32, 0.4, 0.06, 0.14, ">", GOLD, 2.5)
	-- the next step, and only the next
	local nxt = card(body, 0.38, 0.19, 0.59, 0.6)
	new("UIStroke", { Thickness = 3, Color = GOLD }, nxt)
	text(nxt, 0.04, 0.04, 0.5, 0.11, "NEXT", GOLD, 1.5, Enum.TextXAlignment.Left)
	local orb2 = box(nxt, 0.06, 0.2, 0.3, 0.44, Color3.fromRGB(190, 110, 255), 0.15, 0.5, 3)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, orb2)
	new("UIStroke", { Thickness = 3, Color = WHITE, Transparency = 0.2 }, orb2)
	text(nxt, 0.4, 0.19, 0.56, 0.16, "Foam Aura", WHITE, 2.2, Enum.TextXAlignment.Left)
	text(nxt, 0.4, 0.37, 0.56, 0.13, "x2 Oxygen", AQUA, 1.8, Enum.TextXAlignment.Left)
	text(nxt, 0.4, 0.51, 0.56, 0.09, "holds an Uncommon in the Reef", PALE, 1.4, Enum.TextXAlignment.Left)
	prices(nxt, 0.05, 0.71, 0.9, 0.21, "2,500", "49")
	text(body, 0.03, 0.83, 0.94, 0.06, "After Foam: Tide Aura, x3 Oxygen. One step at a time.", PALE, 1.4)
	text(body, 0.03, 0.905, 0.94, 0.055, "You have $1,870", GOLD, 1.5)
elseif WHICH == "tank" then
	local body = panel("YOUR TANK", GOLD, "4 of 8 fish")
	local earn = card(body, 0.03, 0.19, 0.94, 0.2)
	text(earn, 0.03, 0.12, 0.3, 0.3, "EARNING", PALE, 1.5, Enum.TextXAlignment.Left)
	text(earn, 0.03, 0.42, 0.42, 0.46, "$31.6 a second", GOLD, 2.4, Enum.TextXAlignment.Left)
	button(earn, 0.56, 0.16, 0.41, 0.6, GREEN, "COLLECT $1,204")
	local FISH = {
		{ "Seahorse", "Rare", "$18.0" },
		{ "Stingray", "Uncommon", "$8.4" },
		{ "YellowTang", "Common", "$2.8" },
		{ "Boxfish", "Common", "$2.4" },
	}
	for i = 1, 8 do
		local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
		local x, y = 0.03 + col * 0.2375, 0.42 + row * 0.215
		local fish = FISH[i]
		local tile =
			box(body, x, y, 0.2275, 0.2, if fish then RARITY[fish[2]] else CARD, if fish then 0.1 else 0.5, 0.1, 2)
		new("UIStroke", { Thickness = 2, Color = INK }, tile)
		if fish then
			new(
				"UIGradient",
				{
					Color = ColorSequence.new(lighter(RARITY[fish[2]], 0.45), darker(RARITY[fish[2]], 0.1)),
					Rotation = 90,
				},
				tile
			)
			picture(tile, 0.02, 0.02, 0.6, 0.96, fish[1])
			text(tile, 0.58, 0.14, 0.4, 0.3, fish[3], WHITE, 2, Enum.TextXAlignment.Right)
			text(tile, 0.58, 0.5, 0.4, 0.2, "a second", WHITE, 1.4, Enum.TextXAlignment.Right)
		else
			text(tile, 0.3, 0.2, 0.4, 0.6, "+", PALE, 0)
		end
	end
	button(body, 0.03, 0.87, 0.3, 0.095, AQUA, "KEEP THE BEST")
	text(body, 0.36, 0.875, 0.25, 0.085, "More room, 12 fish:", PALE, 1.4, Enum.TextXAlignment.Right)
	prices(body, 0.63, 0.87, 0.34, 0.095, "9,000", "79")
elseif WHICH == "trainer" then
	local body = panel("TRAINER", AQUA, "stand on it to train")
	local stat = card(body, 0.03, 0.19, 0.94, 0.2)
	text(stat, 0.03, 0.12, 0.3, 0.3, "YOUR OXYGEN", PALE, 1.5, Enum.TextXAlignment.Left)
	local bubble = box(stat, 0.03, 0.44, 0.06, 0.44, Color3.fromRGB(127, 227, 255), 0, 0.5, 3)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, bubble)
	new("UIStroke", { Thickness = 2.5, Color = INK }, bubble)
	text(stat, 0.1, 0.42, 0.2, 0.48, "100", WHITE, 2.4, Enum.TextXAlignment.Left)
	text(stat, 0.34, 0.2, 0.63, 0.26, "The Reef's fish need 320", RED:Lerp(WHITE, 0.35), 1.6, Enum.TextXAlignment.Right)
	local bar = box(stat, 0.34, 0.56, 0.63, 0.22, darker(DEEP, 0.3), 0, 0.5, 3)
	new("UIStroke", { Thickness = 2, Color = INK }, bar)
	box(bar, 0, 0, 0.31, 1, AQUA, 0, 0.5, 4)
	local now = card(body, 0.03, 0.42, 0.29, 0.42)
	text(now, 0.06, 0.05, 0.88, 0.13, "YOU HAVE", PALE, 1.5)
	picture(now, 0.15, 0.2, 0.7, 0.42, "Seahorse")
	text(now, 0.06, 0.64, 0.88, 0.15, "Seahorse ride", WHITE, 2)
	text(now, 0.06, 0.81, 0.88, 0.14, "+1 a second", AQUA, 1.8)
	text(body, 0.32, 0.56, 0.06, 0.14, ">", GOLD, 2.5)
	local nxt = card(body, 0.38, 0.42, 0.59, 0.42)
	new("UIStroke", { Thickness = 3, Color = GOLD }, nxt)
	text(nxt, 0.04, 0.05, 0.5, 0.13, "NEXT", GOLD, 1.5, Enum.TextXAlignment.Left)
	picture(nxt, 0.03, 0.18, 0.36, 0.46, "SeaTurtle")
	text(nxt, 0.4, 0.2, 0.57, 0.18, "Turtle ride", WHITE, 2.2, Enum.TextXAlignment.Left)
	text(nxt, 0.4, 0.4, 0.57, 0.15, "+3 a second", AQUA, 1.8, Enum.TextXAlignment.Left)
	prices(nxt, 0.05, 0.69, 0.9, 0.25, "1,200", "29")
	text(body, 0.03, 0.87, 0.6, 0.085, "Train twice as fast, for good:", PALE, 1.4, Enum.TextXAlignment.Right)
	button(body, 0.65, 0.87, 0.32, 0.095, GREEN, ROBUX .. " 199")
elseif WHICH == "index" then
	local body = panel("INDEX", Color3.fromRGB(240, 164, 36), "7 of 82 found")
	local LANDS = { "Shallows", "Reef", "Kelp", "Wrecks", "Blue" }
	local TINT = {
		Color3.fromRGB(242, 214, 128),
		Color3.fromRGB(244, 148, 152),
		Color3.fromRGB(120, 172, 92),
		Color3.fromRGB(160, 148, 124),
		Color3.fromRGB(90, 124, 176),
	}
	for i, name in LANDS do
		local on = i == 1
		local tab = box(
			body,
			0.03 + (i - 1) * 0.19,
			0.185,
			0.18,
			0.085,
			if on then TINT[i] else CARD,
			if on then 0 else 0.2,
			0.3,
			2
		)
		new("UIStroke", { Thickness = 2, Color = if on then WHITE else INK }, tab)
		text(tab, 0.08, 0.18, 0.84, 0.64, name, if on then WHITE else PALE, if on then 2 else 1.4)
	end
	local LIST = {
		{ "YellowTang", "Common", "Yellow Tang", true },
		{ "SergeantMajor", "Common", "Sergeant Major", true },
		{ "BlueChromis", "Common", "Blue Chromis", true },
		{ "Boxfish", "Common", "Boxfish", true },
		{ "Butterflyfish", "Common", "Butterflyfish", true },
		{ "SeaTurtle", "Uncommon", "Sea Turtle", true },
		{ "Stingray", "Uncommon", "Stingray", true },
		{ "Seahorse", "Rare", "???", false },
		{ "Barracuda", "Epic", "???", false },
		{ "Anglerfish", "Legendary", "???", false },
	}
	for i, fish in LIST do
		local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
		local x, y = 0.03 + col * 0.19, 0.295 + row * 0.265
		local found = fish[4]
		local colour = RARITY[fish[2]]
		local tile = box(body, x, y, 0.18, 0.245, if found then colour else CARD, if found then 0.1 else 0.25, 0.08, 2)
		new("UIStroke", { Thickness = 2, Color = if found then INK else darker(colour, 0.2) }, tile)
		if found then
			new(
				"UIGradient",
				{ Color = ColorSequence.new(lighter(colour, 0.45), darker(colour, 0.1)), Rotation = 90 },
				tile
			)
		end
		picture(tile, 0.08, 0.04, 0.84, 0.62, fish[1], not found)
		text(tile, 0.04, 0.66, 0.92, 0.17, fish[3], WHITE, 1.8)
		text(tile, 0.04, 0.83, 0.92, 0.13, string.upper(fish[2]), if found then INK else colour, 0)
	end
	local reward = card(body, 0.03, 0.835, 0.94, 0.135)
	text(
		reward,
		0.02,
		0.1,
		0.5,
		0.36,
		"Find every fish of the Shallows: +10% coins",
		WHITE,
		1.6,
		Enum.TextXAlignment.Left
	)
	local bar = box(reward, 0.02, 0.56, 0.72, 0.3, darker(DEEP, 0.3), 0, 0.5, 3)
	new("UIStroke", { Thickness = 2, Color = INK }, bar)
	box(bar, 0, 0, 0.7, 1, GOLD, 0, 0.5, 4)
	text(reward, 0.76, 0.2, 0.22, 0.6, "7 / 10", GOLD, 2.2)
end
return "built " .. WHICH
