-- "More flavour" (the user, 2026-11-16; docs/design/ui.md, "More flavour"): the Auras shop in three strengths, and
-- the catch banner and the end of a dive with the same devices. Looks only: stand-in words and numbers, nothing
-- behind them. Run in Studio's Edit mode with WHICH "shop1", "shop2", "shop3" or "moments"; "" takes it away. It
-- makes one ScreenGui, StarterGui.UiPanelMock, which must never be saved with the place.
-- Everything is Roblox's own pieces and the stud tile that was uploaded long ago: no new upload. The signs (coin,
-- bubble, star, rays) are made of frames; a drawn icon set would be an upload and is not here.
local WHICH = "shop2"

local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local INK = Color3.fromRGB(16, 36, 63)
local DEEP = Color3.fromRGB(10, 24, 44)
local CARD = Color3.fromRGB(22, 46, 82)
local WHITE = Color3.new(1, 1, 1)
local PALE = Color3.fromRGB(170, 200, 236)
local GOLD = Color3.fromRGB(255, 196, 44)
local SUN = Color3.fromRGB(255, 226, 80)
local GREEN = Color3.fromRGB(72, 200, 84)
local AQUA = Color3.fromRGB(51, 200, 240)
local RED = Color3.fromRGB(232, 62, 62)
local PURPLE = Color3.fromRGB(186, 72, 232)
local PINK = Color3.fromRGB(255, 92, 170)
local RARE = Color3.fromRGB(70, 150, 255)
local STUDS = "rbxassetid://124244361010023"
local ROBUX = utf8.char(0xE002)
local FONT = Enum.Font.FredokaOne

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
local function square(frame)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, frame)
end
-- words with a dark edge; drop: a dark copy under them, moved down by that share of their height
local function text(parent, x, y, w, h, words, colour, edge, align, z, drop)
	z = z or 3
	local function one(dy, tint, zz)
		local label = new(
			"TextLabel",
			{
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(x, y + dy),
				Size = UDim2.fromScale(w, h),
				Font = FONT,
				Text = words,
				TextColor3 = tint,
				TextScaled = true,
				RichText = true,
				TextXAlignment = align or Enum.TextXAlignment.Center,
				ZIndex = zz,
			},
			parent
		)
		if edge ~= 0 then
			new("UIStroke", { Thickness = edge or 2, Color = INK, LineJoinMode = Enum.LineJoinMode.Round }, label)
		end
		return label
	end
	if drop then
		-- (the copy says the same words in the dark colour; rich-text colours are taken out of it)
		local plain = string.gsub(words, "<[^>]+>", "")
		local under = one(h * drop, INK, z - 1)
		under.Text = plain
	end
	return one(0, colour or WHITE, z)
end
local function studs(parent, tile, see)
	new(
		"ImageLabel",
		{
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = STUDS,
			ImageTransparency = see or 0.6,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromScale(tile, 1),
			ZIndex = 2,
		},
		parent
	)
end
-- the signs, made of frames
local function coin(parent, x, y, h, z)
	local c = box(parent, x, y, h, h, SUN, 0, 0.5, z or 4)
	square(c)
	new("UIStroke", { Thickness = 2, Color = INK }, c)
	local ring = box(c, 0.22, 0.22, 0.56, 0.56, SUN, 1, 0.5, (z or 4) + 1)
	new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(240, 160, 24) }, ring)
	return c
end
local function bubble(parent, x, y, h, z)
	local b = box(parent, x, y, h, h, Color3.fromRGB(127, 227, 255), 0, 0.5, z or 4)
	square(b)
	new("UIStroke", { Thickness = 2, Color = INK }, b)
	box(b, 0.2, 0.16, 0.3, 0.22, WHITE, 0, 0.5, (z or 4) + 1)
	return b
end
-- an eight-pointed star: two squares, one turned; words on it
local function burst(parent, x, y, h, colour, words, turn, z)
	z = z or 6
	local holder = new(
		"Frame",
		{
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(h, h),
			BackgroundTransparency = 1,
			Rotation = turn or -12,
			ZIndex = z,
		},
		parent
	)
	square(holder)
	for _, r in { 0, 45 } do
		local s = new(
			"Frame",
			{
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.74, 0.74),
				Rotation = r,
				BackgroundColor3 = colour,
				BorderSizePixel = 0,
				ZIndex = z,
			},
			holder
		)
		new("UICorner", { CornerRadius = UDim.new(0.12, 0) }, s)
		new("UIStroke", { Thickness = 2.5, Color = INK }, s)
	end
	local fill = new(
		"Frame",
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = z + 1,
		},
		holder
	)
	new("UICorner", { CornerRadius = UDim.new(0.12, 0) }, fill)
	local fill2 = new(
		"Frame",
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			Rotation = 45,
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = z + 1,
		},
		holder
	)
	new("UICorner", { CornerRadius = UDim.new(0.12, 0) }, fill2)
	text(holder, 0.1, 0.27, 0.8, 0.46, words, WHITE, 2, nil, z + 2)
	return holder
end
-- a ribbon: a tilted pill with words, hanging over a corner
local function ribbon(parent, x, y, w, h, colour, words, turn, z)
	z = z or 6
	local r = new(
		"Frame",
		{
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			Rotation = turn or -8,
			ZIndex = z,
		},
		parent
	)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, r)
	new("UIStroke", { Thickness = 2.5, Color = INK }, r)
	new("UIGradient", { Color = ColorSequence.new(lighter(colour, 0.35), colour), Rotation = 90 }, r)
	text(r, 0.08, 0.14, 0.84, 0.72, words, WHITE, 2, nil, z + 1)
	return r
end
-- rays behind the thing on offer: bars through one point, see-through at their ends. In the game the holder turns
-- slowly (one number tweened); here it stands still. The plate they are on is a CanvasGroup, which cuts them off at
-- its edge (a plain frame does not cut off a turned child)
local function rays(parent, x, y, size, count, see)
	local holder = new(
		"Frame",
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(size, size),
			BackgroundTransparency = 1,
			ZIndex = 2,
		},
		parent
	)
	square(holder)
	for i = 1, count do
		local bar = new(
			"Frame",
			{
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 0.09),
				Rotation = (i - 1) * 180 / count,
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				ZIndex = 2,
			},
			holder
		)
		new(
			"UIGradient",
			{
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.3, see),
					NumberSequenceKeypoint.new(0.5, see + 0.1),
					NumberSequenceKeypoint.new(0.7, see),
					NumberSequenceKeypoint.new(1, 1),
				}),
			},
			bar
		)
	end
	return holder
end
-- a button. gloss: a pale band across its upper half; sign: "coin" or "robux" at its left; mark: a red "!" on its corner
local function button(parent, x, y, w, h, colour, words, opt)
	opt = opt or {}
	box(parent, x, y + h * 0.1, w, h, darker(colour, 0.5), 0, 0.28, 2)
	local b = box(parent, x, y, w, h, colour, 0, 0.28, 3)
	new("UIGradient", { Color = ColorSequence.new(lighter(colour, 0.3), colour), Rotation = 90 }, b)
	new("UIStroke", { Thickness = opt.edge or 2.5, Color = INK }, b)
	local clip = new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3 },
		b
	)
	new("UICorner", { CornerRadius = UDim.new(0.28, 0) }, clip)
	studs(clip, 0.16)
	if opt.gloss then
		box(b, 0.03, 0.08, 0.94, 0.4, WHITE, 0.74, 0.5, 3)
	end
	local tx, tw = 0.06, 0.88
	if opt.sign == "coin" then
		coin(b, 0.08, 0.2, 0.6, 4)
		tx, tw = 0.36, 0.58
	end
	text(b, tx, 0.16, tw, 0.68, words, WHITE, 2.2, nil, 4)
	if opt.mark then
		local m = box(b, 0.9, -0.22, 0.16, 0.6, RED, 0, 0.5, 6)
		square(m)
		new("UIStroke", { Thickness = 2, Color = WHITE }, m)
		text(m, 0.2, 0.08, 0.6, 0.84, "!", WHITE, 0, nil, 7)
	end
	return b
end
local function picture(parent, x, y, w, h, id, z)
	local view = new(
		"ViewportFrame",
		{
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(190, 195, 205),
			LightDirection = Vector3.new(0.5, -1, 0.4),
			ZIndex = z or 4,
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
-- an aura, drawn: a ring of light round a clear middle, a bright corner
local function orb(parent, x, y, h, colour, z)
	z = z or 4
	local o = box(parent, x, y, h, h, colour, 0.2, 0.5, z)
	square(o)
	new("UIStroke", { Thickness = 4, Color = lighter(colour, 0.7), Transparency = 0.1 }, o)
	new("UIGradient", { Color = ColorSequence.new(lighter(colour, 0.6), darker(colour, 0.15)), Rotation = 60 }, o)
	box(o, 0.18, 0.14, 0.3, 0.2, WHITE, 0.25, 0.5, z + 1)
	box(o, 0.24, 0.24, 0.52, 0.52, WHITE, 0.82, 0.5, z + 1)
	return o
end

-- (Sibling: a child is drawn over its parent, as the game's own HUD is set; a new ScreenGui is Global otherwise)
local gui = new(
	"ScreenGui",
	{ Name = "UiPanelMock", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling },
	StarterGui
)

-- the panel, in a strength: 1 today's with small touches, 2 the genre's devices, 3 as loud as they go
local function panel(strength, title, colour, sub)
	local holder = new(
		"Frame",
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.44, 0.47),
			Size = UDim2.fromScale(0.62, 0.78),
			BackgroundTransparency = 1,
		},
		gui
	)
	new("UIAspectRatioConstraint", { AspectRatio = 1.45 }, holder)
	box(holder, 0, 0.025, 1, 1, darker(DEEP, 0.55), 0.25, 0.05)
	local body = box(holder, 0, 0, 1, 1, DEEP, 0.08, 0.05, 2)
	new("UIStroke", { Thickness = if strength >= 2 then 4.5 else 3.5, Color = INK }, body)
	-- a pattern in the body, faint
	local clipBody = new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2 },
		body
	)
	new("UICorner", { CornerRadius = UDim.new(0.05, 0) }, clipBody)
	studs(clipBody, 0.05, if strength >= 3 then 0.86 else 0.93)
	if strength >= 2 then
		-- a pale line inside the edge, brighter at the top: the bevel
		local inner = box(body, 0.006, 0.009, 0.988, 0.982, WHITE, 1, 0.05, 2)
		local line = new("UIStroke", { Thickness = 2, Color = WHITE, Transparency = 0.55 }, inner)
		new("UIGradient", { Transparency = NumberSequence.new(0.3, 1), Rotation = 90 }, line)
	end
	local head = new(
		"CanvasGroup",
		{
			Position = UDim2.fromScale(0.015, 0.02),
			Size = UDim2.fromScale(0.97, 0.135),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = 3,
		},
		body
	)
	new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, head)
	new("UIGradient", { Color = ColorSequence.new(lighter(colour, 0.35), darker(colour, 0.12)), Rotation = 90 }, head)
	studs(head, 0.06)
	if strength >= 2 then
		-- shine streaks across the header
		-- (a slanted gradient on a frame the header's own shape, so nothing has to be clipped)
		local shine = box(head, 0, 0, 1, 1, WHITE, 0, 0.3, 3)
		new(
			"UIGradient",
			{
				Rotation = 12,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.52, 1),
					NumberSequenceKeypoint.new(0.53, 0.72),
					NumberSequenceKeypoint.new(0.58, 0.72),
					NumberSequenceKeypoint.new(0.59, 1),
					NumberSequenceKeypoint.new(0.61, 1),
					NumberSequenceKeypoint.new(0.62, 0.8),
					NumberSequenceKeypoint.new(0.64, 0.8),
					NumberSequenceKeypoint.new(0.65, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			},
			shine
		)
		box(head, 0.01, 0.08, 0.98, 0.34, WHITE, 0.8, 0.5, 3)
	end
	local edge = box(body, 0.015, 0.02, 0.97, 0.135, colour, 1, 0.3, 4)
	new("UIStroke", { Thickness = 2.5, Color = INK }, edge)
	local tx = 0.03
	if strength >= 2 then
		-- the station's own sign, hanging over the header's end
		orb(body, -0.035, -0.035, 0.24, colour, 6)
		tx = 0.15
	end
	text(
		edge,
		tx,
		0.1,
		0.5,
		0.8,
		title,
		WHITE,
		if strength >= 2 then 3.5 else 3,
		Enum.TextXAlignment.Left,
		5,
		if strength >= 1 then 0.1 else nil
	)
	if sub then
		text(edge, 0.42, 0.3, 0.44, 0.44, sub, lighter(colour, 0.8), 1.8, Enum.TextXAlignment.Right, 5)
	end
	-- the close button: on the header, or from strength 2 hanging over the panel's corner
	local close
	if strength >= 2 then
		close = box(body, 0.945, -0.045, 0.085, 0.16, RED, 0, 0.3, 7)
	else
		close = box(edge, 0.905, 0.12, 0.075, 0.76, RED, 0, 0.3, 5)
	end
	square(close)
	new("UIStroke", { Thickness = 3, Color = INK }, close)
	new("UIGradient", { Color = ColorSequence.new(lighter(RED, 0.3), RED), Rotation = 90 }, close)
	text(close, 0.15, 0.1, 0.7, 0.8, "X", WHITE, 2, nil, 8)
	return body
end
local function card(body, x, y, w, h)
	local c = box(body, x, y, w, h, CARD, 0.1, 0.07, 3)
	new("UIStroke", { Thickness = 2, Color = INK }, c)
	return c
end

local function shop(strength)
	local body = panel(strength, "AURAS", PURPLE, "ride every fish for longer")
	local gloss = strength >= 1
	-- what you have
	local now = card(body, 0.03, 0.19, 0.27, 0.6)
	text(now, 0.06, 0.04, 0.88, 0.1, "YOU HAVE", PALE, 1.5, nil, 4)
	orb(now, 0.25, 0.19, 0.42, Color3.fromRGB(120, 200, 255), 4)
	text(now, 0.06, 0.63, 0.88, 0.14, "Bubble Aura", WHITE, 2, nil, 4)
	text(now, 0.06, 0.8, 0.88, 0.13, "x1.5 Oxygen", AQUA, 1.8, nil, 4)
	text(body, 0.3, 0.41, 0.07, 0.14, ">", GOLD, 2.5, nil, 4, if strength >= 2 then 0.08 else nil)

	-- the next step
	local nxt
	if strength == 1 then
		nxt = card(body, 0.37, 0.19, 0.6, 0.6)
		new("UIStroke", { Thickness = 3, Color = GOLD }, nxt)
		orb(nxt, 0.06, 0.22, 0.42, PURPLE, 4)
		text(nxt, 0.4, 0.17, 0.56, 0.16, "Foam Aura", WHITE, 2.2, Enum.TextXAlignment.Left, 4, 0.08)
		text(nxt, 0.4, 0.35, 0.56, 0.13, "x2 Oxygen", AQUA, 1.8, Enum.TextXAlignment.Left, 4)
		text(nxt, 0.4, 0.5, 0.56, 0.09, "holds an Uncommon in the Reef", PALE, 1.4, Enum.TextXAlignment.Left, 4)
		ribbon(body, 0.345, 0.165, 0.13, 0.075, GOLD, "NEXT", -8, 6)
	else
		-- the offer as a banner in the aura's own colours, rays behind the aura
		local group = new(
			"CanvasGroup",
			{
				Position = UDim2.fromScale(0.37, 0.19),
				Size = UDim2.fromScale(0.6, 0.6),
				BackgroundColor3 = PURPLE,
				BorderSizePixel = 0,
				ZIndex = 3,
			},
			body
		)
		new("UICorner", { CornerRadius = UDim.new(0.07, 0) }, group)
		new(
			"UIGradient",
			{
				Color = ColorSequence.new(
					if strength >= 3 then Color3.fromRGB(80, 120, 255) else Color3.fromRGB(120, 80, 240),
					PINK
				),
				Rotation = 25,
			},
			group
		)
		rays(group, 0.209, 0.34, 1.6, if strength >= 3 then 9 else 7, if strength >= 3 then 0.55 else 0.7)
		box(group, 0, 0.62, 1, 0.38, DEEP, 0.45, 0, 2)
		nxt = box(body, 0.37, 0.19, 0.6, 0.6, WHITE, 1, 0.07, 4)
		new("UIStroke", { Thickness = 3, Color = INK }, nxt)
		local inner = box(nxt, 0.008, 0.012, 0.984, 0.976, WHITE, 1, 0.07, 4)
		new("UIStroke", { Thickness = 2, Color = WHITE, Transparency = 0.5 }, inner)
		orb(nxt, 0.07, 0.14, 0.4, PURPLE, 5)
		text(
			nxt,
			0.42,
			0.06,
			if strength >= 3 then 0.43 else 0.55,
			0.15,
			"FOAM AURA",
			SUN,
			2.6,
			Enum.TextXAlignment.Left,
			5,
			0.1
		)
		-- what it does, as the genre writes it: the old number, an arrow, the new number bigger and brighter
		text(nxt, 0.42, 0.24, 0.16, 0.16, "x1.5", WHITE, 2.4, Enum.TextXAlignment.Left, 5, 0.08)
		text(nxt, 0.585, 0.25, 0.06, 0.14, ">", WHITE, 2, nil, 5)
		text(nxt, 0.65, 0.2, 0.2, 0.24, "x2", SUN, 3, Enum.TextXAlignment.Left, 5, 0.08)
		local chip = box(nxt, 0.42, 0.455, 0.53, 0.115, DEEP, 0.25, 0.4, 5)
		new("UIStroke", { Thickness = 2, Color = INK }, chip)
		bubble(chip, 0.035, 0.14, 0.72, 6)
		text(chip, 0.17, 0.18, 0.8, 0.64, "holds an Uncommon in the Reef", WHITE, 1.4, Enum.TextXAlignment.Left, 6)
		ribbon(
			body,
			0.335,
			0.155,
			0.17,
			0.085,
			if strength >= 3 then RED else GOLD,
			if strength >= 3 then "NEXT UP!" else "NEXT",
			-8,
			7
		)
		if strength >= 3 then
			burst(body, 0.895, 0.1, 0.17, RED, "x2!", 14, 7)
			-- sparkles
			for _, s in { { 0.39, 0.235, 0.03 }, { 0.6, 0.5, 0.02 }, { 0.43, 0.59, 0.024 }, { 0.945, 0.6, 0.018 } } do
				local d = new(
					"Frame",
					{
						Position = UDim2.fromScale(s[1], s[2]),
						Size = UDim2.fromScale(s[3], s[3]),
						Rotation = 45,
						BackgroundColor3 = WHITE,
						BackgroundTransparency = 0.1,
						BorderSizePixel = 0,
						ZIndex = 6,
					},
					body
				)
				square(d)
			end
		end
	end
	-- both prices on it, side by side
	if strength == 1 then
		button(nxt, 0.05, 0.71, 0.432, 0.21, GOLD, "$2,500", { gloss = gloss, sign = "coin" })
		button(nxt, 0.518, 0.71, 0.432, 0.21, GREEN, ROBUX .. " 49", { gloss = gloss })
	else
		button(nxt, 0.05, 0.69, 0.432, 0.23, GOLD, "$2,500", { gloss = true, sign = "coin", edge = 3 })
		button(nxt, 0.518, 0.69, 0.432, 0.23, GREEN, ROBUX .. " 49", { gloss = true, edge = 3 })
	end
	-- how near you are: your coins against the price, as a bar (the reference marks what you can afford with a red
	-- "!"; this says how far off you are when you can't)
	if strength >= 2 then
		local strip = card(body, 0.03, 0.825, 0.94, 0.135)
		coin(strip, 0.02, 0.2, 0.6, 5)
		text(strip, 0.095, 0.14, 0.29, 0.38, "$1,870 of $2,500", WHITE, 1.6, Enum.TextXAlignment.Left, 5)
		text(strip, 0.095, 0.56, 0.29, 0.3, "after Foam: Tide Aura, x3", PALE, 1.2, Enum.TextXAlignment.Left, 5)
		local bar = box(strip, 0.4, 0.3, 0.44, 0.4, darker(DEEP, 0.3), 0, 0.5, 5)
		new("UIStroke", { Thickness = 2, Color = INK }, bar)
		local fill = box(bar, 0, 0, 0.75, 1, GOLD, 0, 0.5, 6)
		new("UIGradient", { Color = ColorSequence.new(SUN, Color3.fromRGB(255, 150, 30)), Rotation = 90 }, fill)
		box(fill, 0.03, 0.12, 0.94, 0.3, WHITE, 0.65, 0.5, 7)
		text(strip, 0.855, 0.2, 0.13, 0.6, "75%", GOLD, 2, nil, 5)
	else
		text(body, 0.03, 0.83, 0.94, 0.06, "After Foam: Tide Aura, x3 Oxygen. One step at a time.", PALE, 1.4, nil, 4)
		local chip = box(body, 0.37, 0.9, 0.26, 0.07, CARD, 0.1, 0.5, 3)
		new("UIStroke", { Thickness = 2, Color = INK }, chip)
		coin(chip, 0.05, 0.16, 0.68, 5)
		text(chip, 0.26, 0.16, 0.7, 0.68, "You have $1,870", GOLD, 1.5, nil, 5)
	end
end

local function token(parent, x, y, h, colour, id, z)
	local t = box(parent, x, y, h, h, colour, 0, 0.5, z)
	square(t)
	new("UIStroke", { Thickness = 2.5, Color = WHITE }, t)
	new("UIGradient", { Color = ColorSequence.new(lighter(colour, 0.5), darker(colour, 0.15)), Rotation = 90 }, t)
	picture(t, 0.08, 0.08, 0.84, 0.84, id, z + 1)
	return t
end

if WHICH == "shop1" then
	shop(1)
elseif WHICH == "shop2" then
	shop(2)
elseif WHICH == "shop3" then
	shop(3)
elseif WHICH == "moments" then
	-- the catch banner: tilted at the left, in the fish's rarity colours, rays behind its picture
	local catch = new(
		"Frame",
		{
			Position = UDim2.fromScale(0.02, 0.18),
			Size = UDim2.fromScale(0.36, 0.3),
			BackgroundTransparency = 1,
			Rotation = -6,
		},
		gui
	)
	new("UIAspectRatioConstraint", { AspectRatio = 2.3 }, catch)
	text(
		catch,
		0.04,
		-0.02,
		0.6,
		0.15,
		"NICE CATCH!",
		Color3.fromRGB(255, 176, 87),
		2,
		Enum.TextXAlignment.Left,
		5,
		0.1
	)
	box(catch, 0, 0.2, 1, 0.62, darker(RARE, 0.65), 0, 0.14, 1)
	local plate = new(
		"CanvasGroup",
		{
			Position = UDim2.fromScale(0, 0.16),
			Size = UDim2.fromScale(1, 0.62),
			BackgroundColor3 = RARE,
			BorderSizePixel = 0,
			ZIndex = 2,
		},
		catch
	)
	new("UICorner", { CornerRadius = UDim.new(0.14, 0) }, plate)
	new(
		"UIGradient",
		{ Color = ColorSequence.new(lighter(RARE, 0.15), Color3.fromRGB(40, 70, 200)), Rotation = 25 },
		plate
	)
	rays(plate, 0.17, 0.5, 1.5, 7, 0.68)
	studs(plate, 0.08, 0.86)
	box(plate, 0.01, 0.05, 0.98, 0.36, WHITE, 0.86, 0.3, 2)
	local frame = box(catch, 0, 0.16, 1, 0.62, WHITE, 1, 0.14, 3)
	new("UIStroke", { Thickness = 4, Color = INK }, frame)
	local inner = box(frame, 0.008, 0.03, 0.984, 0.94, WHITE, 1, 0.14, 3)
	new("UIStroke", { Thickness = 2, Color = WHITE, Transparency = 0.45 }, inner)
	picture(frame, 0.02, -0.12, 0.3, 1.2, "Seahorse", 5)
	text(frame, 0.33, 0.06, 0.63, 0.58, "TAMED!", SUN, 3.5, Enum.TextXAlignment.Left, 5, 0.09)
	local chip = box(frame, 0.33, 0.66, 0.44, 0.27, DEEP, 0.3, 0.5, 5)
	new("UIStroke", { Thickness = 2, Color = INK }, chip)
	coin(chip, 0.04, 0.14, 0.72, 6)
	text(chip, 0.2, 0.16, 0.76, 0.68, "+$18.0 a second", SUN, 1.5, Enum.TextXAlignment.Left, 6)
	text(catch, 0.04, 0.82, 0.2, 0.15, "RARE", lighter(RARE, 0.4), 2, Enum.TextXAlignment.Left, 5, 0.1)
	text(catch, 0.25, 0.81, 0.5, 0.17, "Seahorse", WHITE, 2.2, Enum.TextXAlignment.Left, 5, 0.1)
	burst(catch, 0.84, -0.02, 0.44, RED, "NEW!", 12, 7)

	-- the end of a dive: the title with a drop shadow, the catch as round tokens, what it brought as chips
	local done = new(
		"Frame",
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.66, 0.2),
			Size = UDim2.fromScale(0.5, 0.4),
			BackgroundTransparency = 1,
		},
		gui
	)
	new("UIAspectRatioConstraint", { AspectRatio = 2.6 }, done)
	local streak = new(
		"Frame",
		{
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 0.4),
			Rotation = -2.5,
			BackgroundColor3 = DEEP,
			BorderSizePixel = 0,
			ZIndex = 1,
		},
		done
	)
	local ends = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.22, 0.08),
		NumberSequenceKeypoint.new(0.78, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	new("UIGradient", { Transparency = ends }, streak)
	for _, y in { 0, 1 } do
		local line = new(
			"Frame",
			{
				AnchorPoint = Vector2.new(0, y),
				Position = UDim2.fromScale(0, y),
				Size = UDim2.new(1, 0, 0.05, 0),
				BackgroundColor3 = SUN,
				BorderSizePixel = 0,
				ZIndex = 2,
			},
			streak
		)
		new("UIGradient", { Transparency = ends }, line)
	end
	local title = text(streak, 0.1, 0.08, 0.8, 0.84, "GREAT DIVE!", WHITE, 4, nil, 4, 0.08)
	new(
		"UIGradient",
		{ Color = ColorSequence.new(Color3.fromRGB(255, 246, 180), Color3.fromRGB(255, 160, 30)), Rotation = 90 },
		title
	)
	burst(done, 0.86, -0.2, 0.4, RED, "BEST!", 14, 6)
	-- the catch: one round token a fish, in its rarity's colours, and the count in words
	local pill = box(done, 0.14, 0.47, 0.72, 0.25, DEEP, 0.1, 0.5, 2)
	new("UIStroke", { Thickness = 3, Color = SUN }, pill)
	token(pill, 0.02, 0.08, 0.84, RARE, "Seahorse", 3)
	token(pill, 0.115, 0.08, 0.84, Color3.fromRGB(90, 220, 90), "Stingray", 3)
	token(pill, 0.21, 0.08, 0.84, Color3.fromRGB(200, 200, 200), "YellowTang", 3)
	text(
		pill,
		0.33,
		0.2,
		0.63,
		0.6,
		'You caught <font color="#FFE250">3</font> fish!',
		WHITE,
		2,
		Enum.TextXAlignment.Left,
		4
	)
	-- what the dive brought: how deep, and what the catch will earn
	local deep = box(done, 0.2, 0.78, 0.28, 0.2, DEEP, 0.1, 0.5, 2)
	new("UIStroke", { Thickness = 2.5, Color = INK }, deep)
	bubble(deep, 0.06, 0.16, 0.68, 4)
	text(deep, 0.26, 0.16, 0.7, 0.68, "48 m deep", WHITE, 1.8, Enum.TextXAlignment.Left, 4)
	local earn = box(done, 0.52, 0.78, 0.28, 0.2, DEEP, 0.1, 0.5, 2)
	new("UIStroke", { Thickness = 2.5, Color = INK }, earn)
	coin(earn, 0.06, 0.16, 0.68, 4)
	text(earn, 0.26, 0.16, 0.7, 0.68, "+$29.2 a second", SUN, 1.8, Enum.TextXAlignment.Left, 4)
end
return "built " .. WHICH
