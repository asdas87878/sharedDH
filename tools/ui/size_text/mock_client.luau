--!nonstrict
-- The size text on fish tags, as options only (task u2, 2026-11-17; Hugo: "The size text still looks really bad,
-- give me some versions that match the rarity style more"). NOT the game's code: a temporary LocalScript put into
-- StarterPlayer.StarterPlayerScripts as "ZZSizeMock" by install.luau for one playtest, and taken out after.
-- It hides the game's own fish tags and draws copies of the three-line tag (look 7, rarity word style 5, as in
-- src/client/UI/Tags.luau on 2026-11-17) with the size drawn in one of the versions below. Driven by
-- ReplicatedStorage attributes (set from the server context by drive.luau):
--   SizeMock       "" off, else the version: "Now", "S1" ... "S8"
--   SizeMockMode   "scene": tags pinned on the real fish in view, at the game's own size and distance rules
--                  "grid": every size (columns) for four rarities (rows), zoomed by SizeMockZoom, over the game
--   SizeMockClock  a number holds every animation at that time (for frames); nil runs it
--   SizeMockCam    a CFrame: the camera is held there (nil: the game's camera)
--   SizeMockSet    which list of rarities and sizes the scene's fish get ("near", "crowd", "far", "dark")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Archetypes = require(RS:WaitForChild("Shared"):WaitForChild("Archetypes"))

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(16, 36, 63)
local DEEP = Color3.fromRGB(10, 24, 44)
local WHITE = Color3.new(1, 1, 1)
local GOOD = Color3.fromRGB(141, 240, 106)
local FONT = Enum.Font.FredokaOne
local BLACK = Enum.Font.GothamBlack
local rgb = Color3.fromRGB

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end
local function lighter(c, a)
	return c:Lerp(WHITE, a)
end
local function darker(c, a)
	return c:Lerp(Color3.new(0, 0, 0), a)
end
local function corner(p, r)
	new("UICorner", { CornerRadius = if r >= 999 then UDim.new(0.5, 0) else UDim.new(0, r) }, p)
end
local function stroke(p, th, c, tr)
	return new(
		"UIStroke",
		{ Thickness = th, Color = c, Transparency = tr or 0, LineJoinMode = Enum.LineJoinMode.Round },
		p
	)
end
local function seq(points)
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, ColorSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return ColorSequence.new(keys)
end
local function lineSeq(t, at, half)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(math.clamp(at - half, 0.001, 0.997), 1),
		NumberSequenceKeypoint.new(math.clamp(at, 0.002, 0.998), t),
		NumberSequenceKeypoint.new(math.clamp(at + half, 0.003, 0.999), 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end
local function measure(text, size, font)
	return TextService:GetTextSize(text, size, font, Vector2.new(2000, 200))
end

-- the rarities' tones and the word's style 5 (copied from Tags.luau: PAL, FAMILIES[5])
local RAINBOW = seq({
	0,
	rgb(255, 96, 120),
	0.18,
	rgb(255, 176, 70),
	0.36,
	rgb(255, 240, 100),
	0.54,
	rgb(100, 236, 140),
	0.72,
	rgb(90, 190, 255),
	0.88,
	rgb(170, 120, 255),
	1,
	rgb(255, 96, 200),
})
local PAL = {
	Common = { Light = rgb(252, 253, 255), Mid = rgb(198, 206, 218), Dark = rgb(128, 140, 160), Deep = rgb(58, 66, 84) },
	Uncommon = { Light = rgb(222, 255, 180), Mid = rgb(104, 224, 84), Dark = rgb(34, 160, 64), Deep = rgb(14, 80, 40) },
	Rare = { Light = rgb(200, 238, 255), Mid = rgb(76, 168, 255), Dark = rgb(36, 94, 226), Deep = rgb(18, 40, 124) },
	Epic = { Light = rgb(244, 210, 255), Mid = rgb(186, 98, 255), Dark = rgb(118, 46, 216), Deep = rgb(58, 18, 120) },
	Legendary = {
		Light = rgb(255, 252, 200),
		Mid = rgb(255, 208, 48),
		Dark = rgb(238, 128, 16),
		Deep = rgb(122, 52, 6),
	},
	Mythic = { Light = rgb(255, 210, 180), Mid = rgb(255, 72, 98), Dark = rgb(192, 22, 106), Deep = rgb(92, 8, 56) },
	Secret = {
		Light = rgb(255, 255, 255),
		Mid = rgb(200, 140, 255),
		Dark = rgb(110, 60, 200),
		Deep = rgb(26, 14, 46),
		Fill = RAINBOW,
	},
}
local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
local GROW = { 0, 0, 1, 1.5, 2.5, 3, 3.5 }
local GLOW = { nil, nil, { 3.5, 0.74 }, { 4.5, 0.64 }, { 5.5, 0.52 }, { 6, 0.46 }, { 6.5, 0.42 } }

local function metal(p)
	return seq({ 0, lighter(p.Light, 0.5), 0.48, p.Light:Lerp(p.Mid, 0.35), 0.52, p.Mid, 1, p.Mid:Lerp(p.Dark, 0.55) })
end
-- the same metal, paler (a tint of the rarity's colours)
local function paleMetal(p, a)
	return seq({
		0,
		lighter(p.Light, 0.6 + a * 0.3),
		0.48,
		lighter(p.Light:Lerp(p.Mid, 0.35), a),
		0.52,
		lighter(p.Mid, a),
		1,
		lighter(p.Mid:Lerp(p.Dark, 0.55), a * 0.8),
	})
end
local function paleRainbow(a)
	local keys = {}
	for _, k in RAINBOW.Keypoints do
		table.insert(keys, ColorSequenceKeypoint.new(k.Time, lighter(k.Value, a)))
	end
	return ColorSequence.new(keys)
end

local function rarityWord(tier)
	local r = RANK[tier]
	local p = PAL[tier]
	local secret = r == 7
	return {
		Text = string.upper(tier),
		Font = BLACK,
		Size = 15.5 + GROW[r],
		Fill = if secret then RAINBOW else metal(p),
		FillTurn = if secret then 0 else 90,
		Edge = INK,
		EdgeThick = 2.4,
		Drops = 1,
		DropColour = darker(p.Deep, 0.2),
		DropStep = Vector2.new(0, 1.6),
		Glow = GLOW[r],
		GlowColour = if secret then rgb(200, 140, 255) else p.Mid,
		Shine = if r >= 4 then 0.12 else nil,
		Sweep = r >= 5,
		Sparks = r >= 5,
		Anim = if r == 5 then "gold" elseif r == 6 then "ember" elseif r == 7 then "prism" else nil,
	}
end

-- A word built the way the rarity word is (putArt): a glow copy, one darker copy under it, the letters in a
-- gradient with an ink edge, a white line across it (still, or sweeping). Returns its frame, its parts, its width.
local function makeWord(parent, w, order)
	local m = measure(w.Text, w.Size, w.Font)
	local wide = m.X + 2
	local high = w.High or math.max(math.ceil(w.Size + 8), 12)
	local frame = new("Frame", {
		Size = UDim2.fromOffset(wide, high),
		BackgroundTransparency = 1,
		LayoutOrder = order or 0,
	}, parent)
	local function layer(z)
		return new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = w.Font,
			TextSize = w.Size,
			Text = w.Text,
			TextColor3 = WHITE,
			ZIndex = z,
		}, frame)
	end
	local parts = { Frame = frame, Wide = wide, High = high, W = w }
	if w.Glow then
		local g = layer(3)
		g.TextTransparency = 0.3
		g.TextColor3 = w.GlowColour
		parts.GlowEdge = stroke(g, w.Glow[1], w.GlowColour, w.Glow[2])
		parts.Glow = g
	end
	for i = 1, (w.Drops or 0) do
		local d = layer(8 - i)
		d.TextColor3 = w.DropColour
		d.Position = UDim2.new(0.5, w.DropStep.X * i, 0.5, w.DropStep.Y * i)
		stroke(d, w.EdgeThick, w.DropEdge or INK)
	end
	local main = layer(10)
	parts.Main = main
	parts.Fill = new("UIGradient", { Color = w.Fill, Rotation = w.FillTurn or 90 }, main)
	local edge = stroke(main, w.EdgeThick, w.Edge or INK)
	if w.EdgeFill then
		edge.Color = WHITE
		new("UIGradient", { Color = w.EdgeFill, Rotation = 0 }, edge)
	end
	if w.Shine then
		local s = layer(12)
		if w.Sweep then
			parts.ShineFill = new(
				"UIGradient",
				{ Rotation = 25, Transparency = lineSeq(w.Shine, 0.5, 0.08), Offset = Vector2.new(-1.5, 0) },
				s
			)
		else
			new("UIGradient", { Rotation = 90, Transparency = lineSeq(w.Shine, 0.3, 0.05) }, s)
		end
	end
	return parts
end

local function spark(parent, size, colour, order)
	local f = new("Frame", {
		Size = UDim2.fromOffset(size, size),
		Rotation = 45,
		BackgroundColor3 = colour,
		LayoutOrder = order,
	}, parent)
	corner(f, 2)
	stroke(f, 1.5, INK)
	return f
end

-- the rarity word's own motion (Tags.luau liveWord), and a sweep in step with it for the size words that share it
local EMBER_HOT = rgb(255, 150, 60)
local function every(anim)
	return if anim == "gold" then 2.6 elseif anim == "ember" then 1.7 elseif anim == "prism" then 1.5 else 2.6
end
local function sweepAt(t, rare, anim)
	local u = ((t + rare * 0.37) % every(anim)) / 0.8
	return if u < 1 then -1.2 + 2.4 * u else 1.5
end
local function liveWord(parts, sparks, rare, t)
	local w = parts.W
	local anim = w.Anim
	if not anim then
		return
	end
	local glow = w.Glow or { 5, 0.5 }
	if parts.ShineFill then
		parts.ShineFill.Offset = Vector2.new(sweepAt(t, rare, anim), 0)
	end
	if anim == "gold" then
		local b = math.sin(t * 2.4)
		parts.GlowEdge.Transparency = glow[2] + b * 0.1
		local tw = 0.5 + 0.5 * math.sin(t * 5)
		if sparks[1] then
			sparks[1].Rotation = 45 + tw * 45
			sparks[2].Rotation = 90 - tw * 45
			sparks[1].BackgroundTransparency = 0.35 * (1 - tw)
			sparks[2].BackgroundTransparency = 0.35 * tw
		end
	elseif anim == "ember" then
		local b = 0.5 + 0.5 * math.sin(t * 4.2)
		parts.Fill.Offset = Vector2.new(0, (math.sin(t * 3.1) * 0.6 + math.sin(t * 7.3) * 0.4) * 0.09)
		parts.GlowEdge.Transparency = glow[2] + 0.14 - b * 0.24
		local c = w.GlowColour:Lerp(EMBER_HOT, b)
		parts.GlowEdge.Color = c
		parts.Glow.TextColor3 = c
		local spin = (t * 120) % 360
		if sparks[1] then
			sparks[1].Rotation = 45 + spin
			sparks[2].Rotation = 45 - spin
		end
	else
		parts.Fill.Rotation = (t * 80) % 360
		local c = Color3.fromHSV((t * 0.18) % 1, 0.55, 1)
		parts.GlowEdge.Color = c
		parts.Glow.TextColor3 = c
		parts.GlowEdge.Transparency = glow[2] + math.sin(t * 3) * 0.08
		local spin = (t * 200) % 360
		if sparks[1] then
			sparks[1].Rotation = 45 + spin
			sparks[2].Rotation = 45 - spin
			local sc = Color3.fromHSV((t * 0.18 + 0.5) % 1, 0.35, 1)
			sparks[1].BackgroundColor3 = sc
			sparks[2].BackgroundColor3 = sc
		end
	end
end

------------------------------------------------------------------------------------------------------------------------
-- The sizes
local SIZES = { "Tiny", "Normal", "Big", "Giant", "Huge", "Colossal" }
local SR = { Tiny = 1, Big = 2, Giant = 3, Huge = 4, Colossal = 5 }
-- Now's colours (Tags.luau SIZE_HUE)
local HUE = {
	Tiny = rgb(150, 178, 204),
	Big = rgb(84, 226, 190),
	Giant = rgb(80, 182, 255),
	Huge = rgb(255, 160, 48),
	Colossal = rgb(255, 72, 80),
}
-- the size ladder as four tones each, like a rarity's (S2, S3, S6, S8): cool and quiet to hot and loud
local LADDER = {
	Tiny = { Light = rgb(238, 242, 248), Mid = rgb(170, 184, 202), Dark = rgb(118, 132, 152), Deep = rgb(50, 58, 74) },
	Big = { Light = rgb(214, 255, 240), Mid = rgb(80, 224, 186), Dark = rgb(22, 158, 138), Deep = rgb(8, 74, 66) },
	Giant = { Light = rgb(206, 244, 255), Mid = rgb(60, 196, 255), Dark = rgb(20, 120, 220), Deep = rgb(10, 46, 110) },
	Huge = { Light = rgb(255, 238, 186), Mid = rgb(255, 162, 40), Dark = rgb(230, 96, 12), Deep = rgb(112, 42, 4) },
	Colossal = { Light = rgb(255, 220, 200), Mid = rgb(255, 64, 76), Dark = rgb(196, 14, 52), Deep = rgb(92, 4, 28) },
}

local ROW_HIGH, ROW_GAP, ICON = 20, 6, 18

-- Now: r4's Glass chip (Tags.chipLook style 1, putStack)
local function nowChip(parent, size, order)
	local r = SR[size]
	local hue = HUE[size]
	local textSize = ({ 10.5, 11, 11.5, 12, 12.5 })[r]
	local high = 15 + math.ceil(r / 2)
	local word = string.upper(size)
	local textWide = measure(word, textSize, BLACK).X + 2
	local pillWide = textWide + 12
	local side = if r == 5 then 10 else 0
	local slot = new("Frame", {
		Size = UDim2.fromOffset(pillWide + side * 2, ROW_HIGH),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	local halo = if r == 5 then 0.45 elseif r == 4 then 0.62 else nil
	if halo then
		for i = 1, 2 do
			local grow = if i == 1 then 10 else 5
			local h = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(pillWide + grow, high + grow),
				BackgroundColor3 = hue,
				BackgroundTransparency = if i == 1 then (1 + halo) / 2 else halo,
				BorderSizePixel = 0,
				ZIndex = i,
			}, slot)
			corner(h, 999)
		end
	end
	local pill = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(pillWide, high),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, slot)
	corner(pill, 999)
	new("UIGradient", { Color = ColorSequence.new(DEEP:Lerp(hue, 0.16 + 0.06 * r), DEEP), Rotation = 90 }, pill)
	stroke(pill, if r <= 2 then 1.5 else 2, if r == 1 then hue:Lerp(DEEP, 0.4) else hue)
	local gloss = if r == 5 then 0.72 elseif r >= 3 then 0.8 else nil
	if gloss then
		local g = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(pillWide - 4, high - 3),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, slot)
		corner(g, 999)
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, gloss),
				NumberSequenceKeypoint.new(0.44, math.min(gloss + 0.2, 1)),
				NumberSequenceKeypoint.new(0.5, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, g)
	end
	local label = new("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, side + 6, 0.5, 0),
		Size = UDim2.fromOffset(textWide, high),
		BackgroundTransparency = 1,
		Font = BLACK,
		TextSize = textSize,
		Text = word,
		TextColor3 = WHITE,
		ZIndex = 6,
	}, slot)
	stroke(label, 1.5, INK)
	new("UIGradient", {
		Color = if r == 1
			then ColorSequence.new(rgb(214, 226, 238), rgb(164, 182, 202))
			else ColorSequence.new(lighter(hue, 0.5), hue),
		Rotation = 90,
	}, label)
	if r == 5 then
		for i = 1, 2 do
			local g = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(if i == 1 then 0 else 1, if i == 1 then 4 else -4, 0.5, 0),
				Size = UDim2.fromOffset(6, 6),
				Rotation = 45,
				BackgroundColor3 = lighter(hue, 0.45),
				BorderSizePixel = 0,
				ZIndex = 6,
			}, slot)
			corner(g, 1)
			stroke(g, 1.5, INK)
		end
	end
	return slot, pillWide + side * 2
end

-- S1: the size as a smaller word in a paler tint of the rarity's own metal, built like the rarity word
local function s1Spec(tier, size)
	local r, sr, p = RANK[tier], SR[size], PAL[tier]
	local glow = GLOW[r]
	return {
		Text = string.upper(size),
		Font = BLACK,
		Size = ({ 11, 11.5, 12, 12.5, 13 })[sr],
		Fill = if r == 7 then paleRainbow(0.35) else paleMetal(p, 0.35),
		FillTurn = if r == 7 then 0 else 90,
		EdgeThick = 1.9,
		Drops = 1,
		DropColour = darker(p.Deep, 0.2),
		DropStep = Vector2.new(0, 1.2),
		Glow = if glow and sr >= 3 then { glow[1] * 0.6, math.min(glow[2] + 0.12, 0.9) } else nil,
		GlowColour = if r == 7 then rgb(200, 140, 255) else p.Mid,
		Shine = if sr >= 4 then 0.15 else nil,
		Sweep = sr >= 4 and r >= 5,
		High = ROW_HIGH,
	}
end

-- S2 (and S3, S6, S8): the size word in its own ladder, built like the rarity word, louder as it grows
local function ladderSpec(size, scaleBy)
	local sr, p = SR[size], LADDER[size]
	return {
		Text = string.upper(size),
		Font = BLACK,
		Size = ({ 10.5, 11.5, 12.5, 13.5, 14.5 })[sr] * (scaleBy or 1),
		Fill = metal(p),
		FillTurn = 90,
		EdgeThick = ({ 1.7, 1.8, 2, 2.1, 2.2 })[sr],
		Drops = 1,
		DropColour = darker(p.Deep, 0.2),
		DropStep = Vector2.new(0, if sr >= 4 then 1.4 else 1.2),
		Glow = if sr == 5 then { 4.5, 0.55 } elseif sr == 4 then { 3.5, 0.68 } else nil,
		GlowColour = p.Mid,
		Shine = if sr >= 3 then 0.15 else nil,
		Sweep = sr == 5,
		Anim = if sr == 5 then "gold" else nil, -- the sweep's rhythm
		High = ROW_HIGH,
	}
end

-- S7: quiet small words to Giant; Huge and Colossal a full treatment of their own
local function s7Spec(tier, size)
	local sr = SR[size]
	if sr <= 3 then
		local s = s1Spec(tier, size)
		s.Glow = nil
		s.Shine = nil
		s.Sweep = false
		s.Size = 11
		local p = PAL[tier]
		s.Fill = if RANK[tier] == 7 then paleRainbow(0.55) else paleMetal(p, 0.55)
		return s
	end
	local p = LADDER[size]
	return {
		Text = string.upper(size),
		Font = BLACK,
		Size = if sr == 5 then 15.5 else 14,
		Fill = metal(p),
		FillTurn = 90,
		EdgeThick = 2.3,
		Drops = 1,
		DropColour = darker(p.Deep, 0.2),
		DropStep = Vector2.new(0, 1.5),
		Glow = if sr == 5 then { 5.5, 0.48 } else { 4.5, 0.58 },
		GlowColour = p.Mid,
		Shine = 0.1,
		Sweep = true,
		Sparks = true,
		High = ROW_HIGH + 2,
	}
end

------------------------------------------------------------------------------------------------------------------------
-- The tag: RARITY / the size and the icons / Name / Required: n and the bubble (Tags.luau makeStack, putStack)
local NAMES = {
	Common = "Clownfish",
	Uncommon = "Cuttlefish",
	Rare = "Reef Shark",
	Epic = "Swordfish",
	Legendary = "Megalodon",
	Mythic = "Kraken",
	Secret = "The Devourer",
}

local function hlist(parent, pad, valign)
	return new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = valign or Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, pad),
	}, parent)
end

local function textLabel(props, parent, outline)
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	local l = new("TextLabel", props, parent)
	stroke(l, outline, INK)
	return l
end

local WIDE = 340
-- spec = { Tier, Size, Icons, Need, Mark }; version = "Now", "S1" ...; returns the tag frame and its animation
local function buildTag(parent, spec, version)
	local tier, size = spec.Tier, spec.Size
	local r = RANK[tier]
	local hasSize = size ~= "Normal"
	local mark = spec.Mark
	local root = new("Frame", {
		Name = "MockTag",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(WIDE, 150),
		BackgroundTransparency = 1,
	}, parent)
	local scale = new("UIScale", {}, root)
	new("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	}, root)
	local anims = {}
	local wspec = rarityWord(tier)
	-- line 1
	local top = new("Frame", { Size = UDim2.fromOffset(WIDE, 24), BackgroundTransparency = 1, LayoutOrder = 1 }, root)
	hlist(top, 5)
	local sparks = {}
	local sparkColour = lighter(wspec.GlowColour, 0.55)
	if wspec.Sparks then
		sparks[1] = spark(top, 7, sparkColour, 1)
		sparks[2] = spark(top, 7, sparkColour, 9)
	end
	local lineSize = hasSize and (version == "S3")
	if lineSize then
		-- S3: the size and the rarity on one line, the size first, a step smaller, in its own ladder
		local s = ladderSpec(size, 0.82 + 0.04 * (r - 1) / 6)
		s.Size = math.max(s.Size, 11.5)
		s.High = nil
		makeWord(top, s, 2)
	end
	local word = makeWord(top, wspec, 3)
	top.Size = UDim2.fromOffset(WIDE, word.High)
	table.insert(anims, function(t)
		liveWord(word, sparks, r, t)
	end)
	if hasSize and version == "S8" then
		-- S8: a sticker on the word's top-left corner, turned
		local s = ladderSpec(size, 0.9)
		s.High = nil
		local st = makeWord(word.Frame, s, 0)
		st.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
		st.Frame.Position = UDim2.new(0, 2, 0, 1)
		st.Frame.Rotation = -12
		st.Frame.ZIndex = 20
		for _, d in st.Frame:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 20
			end
		end
	end
	local order = 2
	-- a line just under the word (S4 the ribbon, S5 the spaced letters)
	if hasSize and not mark and (version == "S4" or version == "S5") then
		local sr = SR[size]
		local p = PAL[tier]
		local span = math.max(word.Wide - 2, 0)
		local line = new("Frame", {
			Size = UDim2.fromOffset(WIDE, if version == "S4" then 15 else 12),
			BackgroundTransparency = 1,
			LayoutOrder = order,
		}, root)
		order += 1
		if version == "S4" then
			-- S4: a slim bar each side in the rarity's metal, the size word between them, inside the rarity's glow
			local s = {
				Text = string.upper(size),
				Font = BLACK,
				Size = ({ 10, 10.5, 11, 11.5, 12 })[sr],
				Fill = seq({ 0, WHITE, 0.55, lighter(p.Light, 0.3), 1, p.Light }),
				FillTurn = 90,
				EdgeThick = 1.8,
				Drops = 1,
				DropColour = darker(p.Deep, 0.2),
				DropStep = Vector2.new(0, 1.1),
				Glow = if GLOW[r] then { GLOW[r][1] * 0.55, math.min(GLOW[r][2] + 0.1, 0.9) } else nil,
				GlowColour = wspec.GlowColour,
				High = 15,
			}
			local wordWide = measure(s.Text, s.Size, BLACK).X + 2
			local barWide = math.max(math.floor((span - wordWide) / 2) - 6, 8 + sr)
			local barHigh = ({ 2, 2.5, 3, 3.5, 4 })[sr]
			hlist(line, 5)
			for i = 1, 2 do
				local holder = new("Frame", {
					Size = UDim2.fromOffset(barWide, 15),
					BackgroundTransparency = 1,
					LayoutOrder = if i == 1 then 1 else 3,
				}, line)
				if GLOW[r] then
					local h = new("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(barWide + 4, barHigh + 5),
						BackgroundColor3 = wspec.GlowColour,
						BackgroundTransparency = math.min(GLOW[r][2] + 0.12, 0.9),
						BorderSizePixel = 0,
					}, holder)
					corner(h, 999)
				end
				local bar = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(barWide, barHigh),
					BackgroundColor3 = WHITE,
					BorderSizePixel = 0,
					ZIndex = 2,
				}, holder)
				corner(bar, 999)
				stroke(bar, 1.2, INK)
				-- the bar fades toward its outer end
				new("UIGradient", {
					Color = if r == 7 then RAINBOW else metal(p),
					Rotation = if r == 7 then 0 else 90,
				}, bar)
				if sr >= 4 then
					local cap = new("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(if i == 1 then 0 else 1, 0, 0.5, 0),
						Size = UDim2.fromOffset(5 + (sr - 4), 5 + (sr - 4)),
						Rotation = 45,
						BackgroundColor3 = lighter(wspec.GlowColour, 0.5),
						BorderSizePixel = 0,
						ZIndex = 3,
					}, holder)
					corner(cap, 1)
					stroke(cap, 1.2, INK)
				end
			end
			makeWord(line, s, 2)
		else
			-- S5: small capitals spaced out to the rarity word's own width
			local text = string.upper(size)
			local ts = ({ 9.5, 10, 10, 10.5, 11 })[sr]
			local widths, total = {}, 0
			for i = 1, #text do
				local cw = measure(string.sub(text, i, i), ts, BLACK).X
				widths[i] = cw
				total += cw
			end
			local gap = math.clamp((span - 8 - total) / math.max(#text - 1, 1), 2.5, 9)
			local wideAll = total + gap * (#text - 1)
			local x = (WIDE - wideAll) / 2
			local fill = if r == 7
				then paleRainbow(if sr >= 3 then 0.3 else 0.6)
				elseif sr >= 3 then paleMetal(p, 0.25)
				else seq({ 0, WHITE, 1, lighter(p.Light, 0.25):Lerp(p.Mid, 0.15) })
			local glow = if GLOW[r] and sr >= 4 then { GLOW[r][1] * 0.5, math.min(GLOW[r][2] + 0.12, 0.9) } else nil
			for i = 1, #text do
				local holder = new("Frame", {
					Position = UDim2.fromOffset(x, 0),
					Size = UDim2.fromOffset(widths[i], 12),
					BackgroundTransparency = 1,
				}, line)
				local function letter(z)
					return new("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Font = BLACK,
						TextSize = ts,
						Text = string.sub(text, i, i),
						TextColor3 = WHITE,
						ZIndex = z,
					}, holder)
				end
				if glow then
					local g = letter(1)
					g.TextColor3 = wspec.GlowColour
					g.TextTransparency = 0.3
					stroke(g, glow[1], wspec.GlowColour, glow[2])
				end
				local d = letter(2)
				d.Position = UDim2.fromOffset(0, 1)
				d.TextColor3 = darker(p.Deep, 0.2)
				stroke(d, 1.6, INK)
				local l = letter(3)
				stroke(l, 1.6, INK)
				new("UIGradient", { Color = fill, Rotation = if r == 7 then 0 else 90 }, l)
				x += widths[i] + gap
			end
			-- a thin rule either side on the two biggest, the width of the word
			if sr >= 4 then
				for i = 1, 2 do
					local rule = new("Frame", {
						AnchorPoint = Vector2.new(if i == 1 then 1 else 0, 0.5),
						Position = UDim2.new(
							0,
							if i == 1 then (WIDE - wideAll) / 2 - 5 else (WIDE + wideAll) / 2 + 5,
							0.5,
							0
						),
						Size = UDim2.fromOffset(sr * 3, 2),
						BackgroundColor3 = lighter(wspec.GlowColour, 0.3),
						BorderSizePixel = 0,
					}, line)
					stroke(rule, 1, INK)
				end
			end
		end
	end
	-- the row: the size (Now, S1, S2, S6, S7) and the icons
	if not mark then
		local icons = spec.Icons or ""
		local rowSize = hasSize
			and (version == "Now" or version == "S1" or version == "S2" or version == "S6" or version == "S7")
		if rowSize or icons ~= "" then
			local row = new("Frame", {
				Size = UDim2.fromOffset(
					WIDE,
					if version == "S7" and hasSize and SR[size] >= 4 then ROW_HIGH + 2 else ROW_HIGH
				),
				BackgroundTransparency = 1,
				LayoutOrder = order,
			}, root)
			order += 1
			hlist(row, ROW_GAP)
			if rowSize then
				if version == "Now" then
					nowChip(row, size, 1)
				elseif version == "S1" then
					local w = makeWord(row, s1Spec(tier, size), 1)
					if w.W.Sweep then
						table.insert(anims, function(t)
							w.ShineFill.Offset = Vector2.new(sweepAt(t, r, wspec.Anim), 0)
						end)
					end
				elseif version == "S2" then
					local w = makeWord(row, ladderSpec(size), 1)
					if w.ShineFill then
						table.insert(anims, function(t)
							w.ShineFill.Offset = Vector2.new(sweepAt(t, 0, "gold"), 0)
						end)
					end
				elseif version == "S6" then
					-- S6: the ladder word on a soft dark plate with no edge, fading out at its ends
					local s = ladderSpec(size)
					s.Glow = nil
					local holder = new("Frame", { BackgroundTransparency = 1, LayoutOrder = 1 }, row)
					local w = makeWord(holder, s, 1)
					local pw = w.Wide + 26
					holder.Size = UDim2.fromOffset(pw, ROW_HIGH)
					w.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
					w.Frame.Position = UDim2.fromScale(0.5, 0.5)
					local plate = new("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(pw, 17),
						BackgroundColor3 = DEEP:Lerp(LADDER[size].Deep, 0.4),
						BackgroundTransparency = 0,
						BorderSizePixel = 0,
						ZIndex = 0,
					}, holder)
					corner(plate, 999)
					new("UIGradient", {
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(0.22, 0.42),
							NumberSequenceKeypoint.new(0.78, 0.42),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}, plate)
					if w.ShineFill then
						table.insert(anims, function(t)
							w.ShineFill.Offset = Vector2.new(sweepAt(t, 0, "gold"), 0)
						end)
					end
				elseif version == "S7" then
					local s = s7Spec(tier, size)
					local holder = new("Frame", { BackgroundTransparency = 1, LayoutOrder = 1 }, row)
					hlist(holder, 3)
					local sp = {}
					if s.Sparks then
						local c = lighter(s.GlowColour, 0.5)
						sp[1] = spark(holder, 5, c, 1)
						sp[2] = spark(holder, 5, c, 3)
					end
					local w = makeWord(holder, s, 2)
					holder.Size = UDim2.fromOffset(w.Wide + (if s.Sparks then 2 * (5 + 3) + 2 else 0), w.High)
					if s.Sweep then
						-- in step with the rarity word: the same clock and rhythm (gold's, for words that don't move)
						table.insert(anims, function(t)
							w.ShineFill.Offset = Vector2.new(sweepAt(t, r, wspec.Anim), 0)
							w.GlowEdge.Transparency = s.Glow[2] + math.sin(t * 2.4) * 0.1
							local tw = 0.5 + 0.5 * math.sin(t * 5)
							sp[1].Rotation = 45 + tw * 45
							sp[2].Rotation = 90 - tw * 45
						end)
					end
				end
			end
			if icons ~= "" then
				local box = new("Frame", {
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, ICON),
					BackgroundTransparency = 1,
					LayoutOrder = 2,
				}, row)
				new("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, ROW_GAP),
				}, box)
				Archetypes.icons(box, icons, ICON)
			end
		end
		textLabel(
			{ Size = UDim2.fromOffset(WIDE, 19), TextSize = 16, Text = NAMES[tier], LayoutOrder = order },
			root,
			3
		)
		order += 1
	end
	-- Required: n and the bubble
	local reqRow =
		new("Frame", { Size = UDim2.fromOffset(WIDE, 18), BackgroundTransparency = 1, LayoutOrder = order }, root)
	local chip = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		BackgroundTransparency = 1,
	}, reqRow)
	hlist(chip, 4)
	if not mark then
		textLabel({
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 18),
			TextSize = 12,
			Text = "Required:",
			TextColor3 = rgb(226, 238, 255),
			LayoutOrder = 1,
		}, chip, 2)
	end
	textLabel({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		TextSize = 14,
		Text = tostring(spec.Need or 80),
		TextColor3 = GOOD,
		LayoutOrder = 2,
	}, chip, 2.4)
	local bubble = new("Frame", { Size = UDim2.fromOffset(13, 13), BackgroundColor3 = WHITE, LayoutOrder = 3 }, chip)
	corner(bubble, 999)
	stroke(bubble, 1.5, INK)
	new("UIGradient", { Color = ColorSequence.new(rgb(176, 240, 255), rgb(72, 188, 250)), Rotation = 90 }, bubble)
	local shine = new("Frame", {
		Position = UDim2.fromScale(0.2, 0.16),
		Size = UDim2.fromScale(0.3, 0.22),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, bubble)
	corner(shine, 999)
	return root, scale, function(t)
		for _, a in anims do
			a(t)
		end
	end
end

------------------------------------------------------------------------------------------------------------------------
-- What each scene's fish get, nearest first
local SETS = {
	near = {
		{ Tier = "Legendary", Size = "Colossal", Icons = "Predator,Frenzy", Need = 240 },
		{ Tier = "Rare", Size = "Huge", Icons = "Fast", Need = 120 },
		{ Tier = "Common", Size = "Tiny", Icons = "", Need = 40 },
		{ Tier = "Secret", Size = "Giant", Icons = "Tank", Need = 420 },
		{ Tier = "Common", Size = "Big", Icons = "", Need = 45 },
		{ Tier = "Epic", Size = "Normal", Icons = "Leaper", Need = 160 },
	},
	crowd = {
		{ Tier = "Common", Size = "Giant", Icons = "", Need = 50 },
		{ Tier = "Uncommon", Size = "Big", Icons = "Fast", Need = 70 },
		{ Tier = "Common", Size = "Tiny", Icons = "", Need = 38 },
		{ Tier = "Rare", Size = "Colossal", Icons = "Breaker", Need = 130 },
		{ Tier = "Common", Size = "Huge", Icons = "", Need = 55 },
		{ Tier = "Legendary", Size = "Big", Icons = "Predator", Need = 230 },
		{ Tier = "Common", Size = "Normal", Icons = "", Need = 40 },
		{ Tier = "Uncommon", Size = "Tiny", Icons = "", Need = 66 },
	},
	far = {
		{ Tier = "Rare", Size = "Huge", Icons = "Fast", Need = 120 },
		{ Tier = "Legendary", Size = "Giant", Icons = "", Need = 240 },
		{ Tier = "Common", Size = "Colossal", Icons = "", Need = 52 },
		{ Tier = "Secret", Size = "Big", Icons = "Tank", Need = 420 },
		{ Tier = "Epic", Size = "Tiny", Icons = "", Need = 150 },
	},
	dark = {
		{ Tier = "Mythic", Size = "Huge", Icons = "Predator", Need = 330 },
		{ Tier = "Common", Size = "Big", Icons = "", Need = 60 },
		{ Tier = "Secret", Size = "Colossal", Icons = "Tank,Breaker", Need = 420 },
		{ Tier = "Rare", Size = "Tiny", Icons = "Leaper", Need = 140 },
		{ Tier = "Legendary", Size = "Giant", Icons = "", Need = 250 },
		{ Tier = "Epic", Size = "Big", Icons = "", Need = 170 },
	},
}

local gui = new("ScreenGui", {
	Name = "ZZSizeMockGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 50,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, pg)

local tagJail = new("ScreenGui", { Name = "ZZTagJail", Enabled = false, ResetOnSpawn = false }, pg)
local built = "" -- what is drawn now
local live = {} -- { root, scale, anim, fish }

local function clearAll()
	for _, c in gui:GetChildren() do
		c:Destroy()
	end
	table.clear(live)
end

local function hudScale(cam)
	return math.clamp(cam.ViewportSize.Y / 560, 1, 2.2)
end

local function buildGrid(version, zoom, cam)
	local tiers = { "Common", "Rare", "Legendary", "Secret" }
	local icons = { Common = "", Rare = "Fast", Legendary = "Predator,Frenzy", Secret = "Tank" }
	local vp = cam.ViewportSize
	local cellW, cellH = vp.X / 6, (vp.Y - 30) / 4
	for row, tier in tiers do
		for col, size in SIZES do
			local root, scale, anim =
				buildTag(gui, { Tier = tier, Size = size, Icons = icons[tier], Need = 80 + row * 40 }, version)
			scale.Scale = zoom
			root.Position = UDim2.fromOffset((col - 0.5) * cellW, 30 + row * cellH - 8)
			table.insert(live, { root = root, anim = anim })
		end
	end
	-- the column heads
	for col, size in SIZES do
		textLabel({
			Position = UDim2.fromOffset((col - 1) * cellW, 4),
			Size = UDim2.fromOffset(cellW, 22),
			TextSize = 18,
			Text = if size == "Normal" then "Normal (no size)" else size,
			TextColor3 = rgb(255, 255, 255),
		}, gui, 2)
	end
end

local function fishRoot(model)
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local frozen = nil -- a local copy of the fish (and the rider) at one moment, so every version shows the same scene
local frozenCam = nil
local frozenAt = 0

local function hideLive(on)
	local folder = workspace:FindFirstChild("Fish")
	local list = {}
	if folder then
		for _, d in folder:GetDescendants() do
			table.insert(list, d)
		end
	end
	if player.Character then
		for _, d in player.Character:GetDescendants() do
			table.insert(list, d)
		end
	end
	for _, d in list do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = if on then 1 else 0
		end
	end
end

local function freeze(cam)
	if frozen then
		frozen:Destroy()
	end
	frozen = Instance.new("Folder")
	frozen.Name = "ZZFrozen"
	local fishCopies = Instance.new("Folder")
	fishCopies.Name = "Fish"
	fishCopies.Parent = frozen
	local eye = cam.CFrame.Position
	local folder = workspace:FindFirstChild("Fish")
	if folder then
		for _, m in folder:GetChildren() do
			local root = fishRoot(m)
			if m:IsA("Model") and root and (root.Position - eye).Magnitude < 400 then
				m.Archivable = true
				local c = m:Clone()
				if c then
					for _, d in c:GetDescendants() do
						if d:IsA("BasePart") then
							d.Anchored = true
							d.CanCollide = false
							d.LocalTransparencyModifier = 0
						elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Constraint") then
							d:Destroy()
						end
					end
					c.Parent = fishCopies
				end
			end
		end
	end
	local char = player.Character
	if char then
		char.Archivable = true
		local c = char:Clone()
		if c then
			for _, d in c:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.LocalTransparencyModifier = 0
				elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Humanoid") then
					d:Destroy()
				end
			end
			c.Name = "Rider"
			c.Parent = frozen
		end
	end
	frozen.Parent = workspace
	frozenCam = cam.CFrame
end

local function unfreeze()
	if frozen then
		frozen:Destroy()
		frozen = nil
	end
	frozenCam = nil
	hideLive(false)
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

local function buildScene(version, set, cam)
	local folder = if frozen then frozen:FindFirstChild("Fish") else workspace:FindFirstChild("Fish")
	if not folder then
		return
	end
	local eye = cam.CFrame.Position
	-- the ridden fish has no tag (as in the game): the one under the rider
	local rider = if frozen then frozen:FindFirstChild("Rider") else player.Character
	local riderAt = rider and rider:FindFirstChild("HumanoidRootPart")
	local cands = {}
	for _, m in folder:GetChildren() do
		if m:IsA("Model") then
			local root = fishRoot(m)
			if root then
				local p = cam:WorldToViewportPoint(root.Position)
				local d = (root.Position - eye).Magnitude
				local vp = cam.ViewportSize
				local ridden = riderAt and (root.Position - riderAt.Position).Magnitude < 14
				if not ridden and p.Z > 0 and p.X > 40 and p.X < vp.X - 40 and p.Y > 60 and p.Y < vp.Y and d < 260 then
					table.insert(cands, { m = m, d = d })
				end
			end
		end
	end
	-- nearest first, but the fish that will be drawn whole before the far ones, so the list's sizes land on them
	table.sort(cands, function(a, b)
		local fa, fb = a.d >= 110, b.d >= 110
		if fa ~= fb then
			return fb
		end
		return a.d < b.d
	end)
	local list = SETS[set] or SETS.near
	-- a whole tag that would overlap one drawn is crowded and drawn as the mark (as the game); a mark that would
	-- overlap anything is left out here, so the pictures stay readable
	local placed = {}
	local n = 0
	for _, c in cands do
		if n >= #list then
			break
		end
		local spec = table.clone(list[n + 1])
		spec.Mark = c.d >= 110
		local root0 = fishRoot(c.m)
		local ext = c.m:GetExtentsSize()
		local p = cam:WorldToViewportPoint(root0.Position + Vector3.new(0, ext.Y * 0.55 + 1.5, 0))
		local s = (if c.d < 60 then 1 else 0.86) * hudScale(cam)
		local function hits(w, h)
			for _, q in placed do
				if math.abs(p.X - q[1]) < (w + q[3]) / 2 and p.Y - h < q[2] and q[2] - q[4] < p.Y then
					return true
				end
			end
			return false
		end
		local w, h = 150 * s, (if spec.Size ~= "Normal" or spec.Icons ~= "" then 112 else 90) * s
		if not spec.Mark and hits(w, h) then
			spec.Mark = true
		end
		local ok = true
		if spec.Mark then
			local big = if RANK[spec.Tier] >= 5 then 1.3 else 1
			w, h = 110 * s * big, 48 * s * big
			ok = not hits(w, h)
		end
		if ok then
			table.insert(placed, { p.X, p.Y, w, h })
			n += 1
			local root, scale, anim = buildTag(gui, spec, version)
			local size = if c.d < 60 then 1 else 0.86
			if spec.Mark and RANK[spec.Tier] >= 5 then
				size *= 1.3
			end
			scale.Scale = size * hudScale(cam)
			table.insert(live, { root = root, anim = anim, fish = c.m, spec = spec })
		end
	end
end

-- the client's own asks: onto a fish (the sandbox's reset), and freezing the scene
local Net = require(RS.Shared:WaitForChild("Net"))
local rideStamp = RS:GetAttribute("SizeMockRide") or 0
RS:GetAttributeChangedSignal("SizeMockRide"):Connect(function()
	local v = RS:GetAttribute("SizeMockRide") or 0
	if v ~= rideStamp then
		rideStamp = v
		Net.Sandbox:FireServer("Reset")
	end
end)

-- per frame: the game's tags hidden, ours placed and moved
local hiddenGuis = {}
RunService:BindToRenderStep("ZZSizeMock", Enum.RenderPriority.Last.Value + 60, function()
	local version = RS:GetAttribute("SizeMock")
	local cam = workspace.CurrentCamera
	local cf = RS:GetAttribute("SizeMockCam")
	if typeof(cf) == "CFrame" and version and version ~= "" then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = cf
		cam.FieldOfView = 70
	end
	local fz = RS:GetAttribute("SizeMockFreeze") or 0
	if fz ~= frozenAt then
		frozenAt = fz
		if fz == 0 then
			unfreeze()
		else
			freeze(cam)
		end
		built = "" -- tags again, on the copies
	end
	if frozenCam then
		cam.CameraType = Enum.CameraType.Scriptable
		local back = RS:GetAttribute("SizeMockBack") or 0
		cam.CFrame = frozenCam * CFrame.new(0, back * 0.2, back)
		hideLive(true)
	end
	if type(version) ~= "string" or version == "" then
		if built ~= "" then
			clearAll()
			built = ""
		end
		for g, was in hiddenGuis do
			g.Enabled = was
		end
		table.clear(hiddenGuis)
		return
	end
	local mode = RS:GetAttribute("SizeMockMode") or "scene"
	local set = RS:GetAttribute("SizeMockSet") or "near"
	local zoom = RS:GetAttribute("SizeMockZoom") or 2
	local stamp = RS:GetAttribute("SizeMockStamp") or 0 -- bump to rebuild with the fish in view now
	local key = version .. mode .. set .. zoom .. stamp
	-- the game's own tags out of sight; in the grid the whole HUD too
	-- (the game writes their Visible every frame, so they are moved into a switched-off holder, where it keeps
	-- updating them unseen)
	for _, d in pg:GetDescendants() do
		if d.Name == "FishTag" and d:IsA("GuiObject") and not d:IsDescendantOf(tagJail) then
			d.Parent = tagJail
		end
	end
	for _, g in pg:GetChildren() do
		if g:IsA("ScreenGui") and g ~= gui then
			if mode == "grid" or RS:GetAttribute("SizeMockNoHud") then
				if hiddenGuis[g] == nil then
					hiddenGuis[g] = g.Enabled
				end
				g.Enabled = false
			elseif hiddenGuis[g] ~= nil then
				g.Enabled = hiddenGuis[g]
				hiddenGuis[g] = nil
			end
		end
	end
	if key ~= built then
		clearAll()
		built = key
		if mode == "grid" then
			buildGrid(version, zoom, cam)
		else
			buildScene(version, set, cam)
		end
	end
	local clock = RS:GetAttribute("SizeMockClock")
	local t = if type(clock) == "number" then clock else os.clock()
	local hs = hudScale(cam)
	for _, l in live do
		l.anim(t)
		if l.fish then
			local root = fishRoot(l.fish)
			if root and l.fish.Parent then
				-- the tag's foot just over the fish (the game puts it over the model's top)
				local ext = l.fish:GetExtentsSize()
				local p = cam:WorldToViewportPoint(root.Position + Vector3.new(0, ext.Y * 0.55 + 1.5, 0))
				l.root.Visible = p.Z > 0
				l.root.Position = UDim2.fromOffset(p.X, p.Y)
			else
				l.root.Visible = false
			end
		end
	end
	local _ = hs
end)
