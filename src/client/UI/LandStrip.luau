--!strict
-- The strip of the ten lands across the top (where the reference has its zone strip): a dark tray of bricks with a
-- thick outline and a shadow, holding ten tiles, each in its own land's colour (the map's), lighter at the top, with a
-- pale line along its top edge. The land you are in is framed in white. Your badge sits on the tiles' lower edge with
-- the metres under it, on a pill in that land's colour; your best is a thin yellow line with a diamond and its metres.
-- On a keyboard the tiles carry the lands' names and the pill only the metres; on a phone the tiles carry numbers and
-- the pill the land's name too.
-- Style 1 (Kit.LandStripStyle, task l1) is further down: each land a framed picture that colours in as you go.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Kit = require(script.Parent.Kit)

local LandStrip = {}

local TILE = 28
local GAP = 1
local COUNT = 10
local WIDE = COUNT * TILE + (COUNT - 1) * GAP

local holder: Frame
local faces: { Frame } = {}
local edges: { Frame } = {}
local grounds: { Frame } = {}
local numbers: { TextLabel } = {}
local names: { TextLabel } = {}
local cursor: Frame
local badge: Frame
local pill: Frame
local pillLook: Kit.Dressed
local pillLand: TextLabel
local pillMetres: TextLabel
local bestLine: Frame
local bestMark: Frame
local bestText: TextLabel

local shownLand = -1
local shownMetres = -1
local shownX = -1
local shownBest = -1
local touch = false

local function paint(land: number)
	for i = 1, COUNT do
		local colour = Kit.Lands[i]
		local body = if i > land then colour:Lerp(Color3.fromRGB(40, 60, 96), 0.4) else colour
		faces[i].BackgroundColor3 = body
		grounds[i].BackgroundColor3 = Kit.darker(body, 0.18)
		edges[i].BackgroundColor3 = if i == land then Kit.lighter(colour, 0.6) else Kit.darker(colour, 0.4)
		numbers[i].TextTransparency = if i > land then 0.25 else 0
	end
	cursor.Visible = land >= 1
	if land >= 1 then
		cursor.Position = UDim2.fromOffset((math.min(land, COUNT) - 1) * (TILE + GAP), 0)
	end
	local colour = Kit.Lands[math.clamp(land, 1, COUNT)]
	pillLook.paint(Kit.darker(colour, 0.38), Kit.darker(colour, 0.72))
end

-- top to bottom over a tile's own colour: full at the top, a little darker at its foot
local SHADE = ColorSequence.new(Kit.White, Color3.fromRGB(176, 176, 190))

local buildA: (parent: Instance, options: { Numbers: number, Reveal: string, Atlas: string, Fixed: boolean? }) -> any
local active: any = nil -- style 1's strip, when it is the one in use

local function setting(name: string, default: any): any
	if RunService:IsStudio() then
		local forced = workspace:GetAttribute(name)
		if forced ~= nil and typeof(forced) == typeof(default) then
			return forced
		end
	end
	return default
end

function LandStrip.build(parent: Instance)
	if setting("LandStripStyle", Kit.LandStripStyle) == 1 then
		active = buildA(parent, {
			Numbers = setting("LandNumbers", Kit.LandNumbers),
			Reveal = setting("LandReveal", Kit.LandReveal),
			Atlas = setting("LandAtlas", Kit.LandAtlas),
		})
		return
	end
	holder = Kit.new("Frame", {
		Name = "LandStrip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(COUNT * TILE + (COUNT - 1) * GAP, TILE + 32),
		BackgroundTransparency = 1,
	}, parent)
	local tray: Kit.Style = table.clone(Kit.Themes.Navy)
	tray.Radius = Kit.Radius.Tile
	Kit.panel(holder, {
		Name = "Tray",
		Position = UDim2.fromOffset(-3, -3),
		Size = UDim2.new(1, 6, 0, TILE + 6),
		ZIndex = 0,
	}, tray)
	for i = 1, COUNT do
		-- three frames a tile: the hairline, the land's border, the face
		local tile = Kit.new("Frame", {
			Position = UDim2.fromOffset((i - 1) * (TILE + GAP), 0),
			Size = UDim2.fromOffset(TILE, TILE),
			BackgroundColor3 = Kit.Ink,
			BorderSizePixel = 0,
		}, holder)
		local edge = Kit.new("Frame", {
			Position = UDim2.fromOffset(1, 1),
			Size = UDim2.new(1, -2, 1, -2),
			BorderSizePixel = 0,
		}, tile)
		local face = Kit.new("Frame", {
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, edge)
		local ground = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0.42),
			BorderSizePixel = 0,
		}, face)
		Kit.new("UIGradient", { Color = SHADE, Rotation = 90 }, face)
		Kit.new("UIGradient", { Color = SHADE, Rotation = 90 }, ground)
		Kit.new("Frame", {
			Size = UDim2.new(1, 0, 0, 1.5),
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
		}, face)
		edges[i] = edge
		faces[i] = face
		grounds[i] = ground
		numbers[i] = Kit.text({
			Size = UDim2.fromScale(1, 1),
			TextSize = 11,
			Text = tostring(i),
			ZIndex = 2,
		}, face)
		names[i] = Kit.text({
			Size = UDim2.new(1, 0, 0, 9),
			TextSize = if #Kit.LandShort[i] > 6 then 5.5 else 7,
			Text = Kit.LandShort[i],
			Visible = false,
			ZIndex = 2,
		}, face)
	end

	-- the white frame on the land you are in
	cursor = Kit.new("Frame", {
		Size = UDim2.fromOffset(TILE, TILE),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3,
	}, holder)
	Kit.stroke(cursor, 2, Kit.White).LineJoinMode = Enum.LineJoinMode.Miter

	bestLine = Kit.new("Frame", {
		Size = UDim2.fromOffset(1.5, TILE * 0.3),
		BackgroundColor3 = Kit.Sun,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
	}, holder)
	bestMark = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(5, 5),
		Rotation = 45,
		BackgroundColor3 = Kit.Sun,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
	}, holder)
	Kit.stroke(bestMark, 1, Kit.Ink)
	bestText = Kit.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(70, 10),
		TextSize = 7.5,
		TextColor3 = Kit.Sun,
		Visible = false,
		ZIndex = 3,
	}, holder)

	badge = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, TILE - 6),
		Size = UDim2.fromOffset(13, 13),
		BackgroundColor3 = Color3.fromRGB(61, 139, 240),
		ZIndex = 4,
	}, holder)
	Kit.corner(badge, 999)
	Kit.stroke(badge, 2.5, Kit.Good)

	pill = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, TILE + 12),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 13),
		ZIndex = 4,
	}, holder)
	-- no pattern or inner line on it: its words are laid out in a row, and those would join the row
	pillLook = Kit.dress(pill, {
		Top = Kit.Navy,
		Bottom = Kit.Ink,
		Outline = Kit.Outline.Thin,
		Radius = Kit.Radius.Round,
		Bevel = false,
	})
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, pill)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, pill)
	pillLand = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 12),
		TextSize = 8,
		LayoutOrder = 1,
		ZIndex = 5,
	}, pill)
	pillMetres = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 12),
		TextSize = 10,
		Text = "0 m",
		LayoutOrder = 2,
		ZIndex = 5,
	}, pill)
	paint(1)
end

-- The phone layout (numbers on the tiles, the land's name in the pill) or the keyboard one (names on the tiles)
function LandStrip.place(onTouch: boolean)
	if active then
		active.place(onTouch)
		return
	end
	touch = onTouch
	for i = 1, COUNT do
		numbers[i].Visible = onTouch
		names[i].Visible = not onTouch
	end
	pillLand.Visible = onTouch
	pillMetres.TextSize = if onTouch then 10 else 8
	shownBest = -1
end

-- land: 1 to 10 (0 on the dock); along: 0 to 1 through that land; best: how many lands deep the best dive got
-- (2.6 is six tenths through the third), with its metres
function LandStrip.update(
	land: number,
	landName: string,
	along: number,
	metres: number,
	best: number,
	bestMetres: number
)
	if active then
		active.update(land, landName, along, metres, best, bestMetres)
		return
	end
	holder.Visible = true
	local at = math.max(land, 1)
	if land ~= shownLand then
		shownLand = land
		paint(land)
		pillLand.Text = string.upper(landName)
		pillLand.TextColor3 = Kit.lighter(Kit.Lands[math.clamp(at, 1, COUNT)], 0.35)
	end
	local whole = math.floor(metres)
	if whole ~= shownMetres then
		shownMetres = whole
		pillMetres.Text = whole .. " m"
	end
	local x = math.floor(((at - 1) * (TILE + GAP) + math.clamp(along, 0, 1) * TILE) * 4 + 0.5) / 4
	if land < 1 then
		x = 0
	end
	if x ~= shownX then
		shownX = x
		badge.Position = UDim2.fromOffset(x, TILE - 6)
		pill.Position = UDim2.fromOffset(x, TILE + 12)
	end
	local bestWhole = math.floor(bestMetres)
	if bestWhole ~= shownBest then
		shownBest = bestWhole
		local has = bestWhole > 0
		bestLine.Visible = has
		bestMark.Visible = has
		bestText.Visible = has
		if has then
			local index = math.clamp(math.floor(best), 0, COUNT - 1)
			local bx = index * (TILE + GAP) + math.clamp(best - index, 0, 1) * TILE
			bestLine.Position = UDim2.fromOffset(bx - 0.75, TILE * 0.64)
			bestMark.Position = UDim2.fromOffset(bx, TILE)
			bestText.Text = "BEST " .. bestWhole .. " m"
			-- across the tile on a keyboard; just under the strip on a phone, clear of the tiles' numbers. Kept
			-- inside the strip either way (a best in the last land ran off its right end)
			if not touch then
				bestText.AnchorPoint = Vector2.new(0.5, 0.5)
				bestText.TextXAlignment = Enum.TextXAlignment.Center
				bestText.Position = UDim2.fromOffset(math.clamp(bx, 26, WIDE - 26), TILE * 0.52)
			elseif bx > WIDE - 60 then
				bestText.AnchorPoint = Vector2.new(1, 0.5)
				bestText.TextXAlignment = Enum.TextXAlignment.Right
				bestText.Position = UDim2.fromOffset(bx - 6, TILE + 5)
			else
				bestText.AnchorPoint = Vector2.new(0, 0.5)
				bestText.TextXAlignment = Enum.TextXAlignment.Left
				bestText.Position = UDim2.fromOffset(bx + 6, TILE + 5)
			end
		end
	end
end

-- ============================================================================================================
-- Style 1: the framed pictures (Hugo, 2026-11-17; task l1, docs/design/ui.md "The land strip, style A").
-- Treatment A of the options sheet (docs/attachments/land-icons-options-1.png) without its inner band: a rounded
-- square, one thick ink frame, the land's picture filling it. A land not reached is its grey locked picture with a
-- padlock; the colour picture is uncovered over it from left to right, in step with how far you have got through
-- that land (Kit.LandReveal: this dive, or your furthest). The land you are in is a size up with a white rim. Each
-- land's number is drawn in that land's own style (Kit.LandNumbers). Under the strip your avatar's face in a round
-- frame slides along with you, the metres on a small bar under it. Your furthest ever (the server's, BestService)
-- is a yellow dashed line through the strip with "BEST 1,240 m" hanging from its foot.
-- ============================================================================================================

local A_TILE = 28
local A_GAP = 2
local A_FRAME = 2.5 -- the ink frame's width
local A_INNER = A_TILE - 2 * A_FRAME
local A_WIDE = COUNT * A_TILE + (COUNT - 1) * A_GAP
local A_POP = 1.18 -- the land you are in
local LAND_CELL = 96 -- one picture's square in the atlas (tools/ui/land_icons/atlas.py)
local FACE = 18 -- the avatar's disc
local LOCKED_TOP = Color3.fromRGB(226, 230, 238)
local LOCKED_BOTTOM = Color3.fromRGB(140, 148, 164)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- keypoints { position, colour }
local function sequence(keys: { { any } }): ColorSequence
	local list = {}
	for _, key in keys do
		table.insert(list, ColorSequenceKeypoint.new(key[1], key[2]))
	end
	return ColorSequence.new(list)
end

-- N2, Material: each land's own stuff in its number. Rotation 90 runs top to bottom, 0 left to right.
-- stylua: ignore
local MATERIAL: { { Keys: { { any } }, Rotation: number, Edge: Color3, Glow: Color3? } } = {
	-- 1 Shallows: sun on sand, a white glint along the top
	{ Keys = { { 0, rgb(255, 255, 236) }, { 0.3, rgb(255, 236, 140) }, { 1, rgb(226, 162, 52) } }, Rotation = 90, Edge = rgb(94, 56, 18) },
	-- 2 Coral Reef: coral pink, banded like a branch
	{ Keys = { { 0, rgb(255, 214, 200) }, { 0.45, rgb(255, 128, 132) }, { 0.5, rgb(236, 84, 110) }, { 0.55, rgb(255, 150, 120) }, { 1, rgb(230, 76, 96) } }, Rotation = 90, Edge = rgb(104, 18, 56) },
	-- 3 Kelp Forest: kelp ribs, light and dark green stripes across the letters
	{ Keys = { { 0, rgb(170, 240, 100) }, { 0.3, rgb(170, 240, 100) }, { 0.32, rgb(66, 150, 56) }, { 0.45, rgb(66, 150, 56) }, { 0.47, rgb(170, 240, 100) }, { 0.7, rgb(150, 226, 88) }, { 0.72, rgb(66, 150, 56) }, { 1, rgb(80, 164, 60) } }, Rotation = 10, Edge = rgb(16, 56, 22) },
	-- 4 Shipwrecks: old planks, a dark seam through the middle
	{ Keys = { { 0, rgb(222, 176, 116) }, { 0.46, rgb(176, 122, 72) }, { 0.5, rgb(92, 58, 36) }, { 0.54, rgb(186, 132, 80) }, { 1, rgb(128, 84, 50) } }, Rotation = 90, Edge = rgb(40, 22, 12) },
	-- 5 Open Blue: water, pale at the top, deep at the foot
	{ Keys = { { 0, rgb(214, 250, 255) }, { 0.35, rgb(90, 190, 255) }, { 1, rgb(30, 86, 210) } }, Rotation = 90, Edge = rgb(8, 30, 84) },
	-- 6 Twilight: the last light, pink over violet
	{ Keys = { { 0, rgb(255, 190, 236) }, { 0.5, rgb(186, 126, 255) }, { 1, rgb(96, 62, 196) } }, Rotation = 90, Edge = rgb(40, 18, 84) },
	-- 7 Midnight: dark letters with a glowing edge, as a lure
	{ Keys = { { 0, rgb(96, 110, 196) }, { 1, rgb(30, 34, 92) } }, Rotation = 90, Edge = rgb(10, 14, 40), Glow = rgb(90, 244, 255) },
	-- 8 Vents: lava, yellow to red
	{ Keys = { { 0, rgb(255, 246, 140) }, { 0.4, rgb(255, 156, 40) }, { 1, rgb(214, 44, 26) } }, Rotation = 90, Edge = rgb(70, 10, 6), Glow = rgb(255, 120, 40) },
	-- 9 Bone Graveyard: bone, pale with a worn grey foot
	{ Keys = { { 0, rgb(255, 252, 236) }, { 0.6, rgb(232, 224, 200) }, { 1, rgb(176, 168, 148) } }, Rotation = 90, Edge = rgb(58, 52, 44) },
	-- 10 The Underworld: crimson to near black, an ember edge
	{ Keys = { { 0, rgb(255, 110, 100) }, { 0.45, rgb(206, 30, 56) }, { 1, rgb(84, 8, 24) } }, Rotation = 90, Edge = rgb(30, 4, 10), Glow = rgb(255, 84, 50) },
}

local function grouped(value: number): string
	local text = tostring(math.floor(value))
	local out = text
	while true do
		local next, count = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
		out = next
		if count == 0 then
			return out
		end
	end
end

-- A small shape made of frames (the N3 badges, the padlock, the tick)
local function blob(parent: Instance, props: { [string]: any }, radius: number?, edge: number?): Frame
	props.BorderSizePixel = 0
	local frame: Frame = Kit.new("Frame", props, parent)
	if radius then
		Kit.corner(frame, radius)
	end
	if edge then
		Kit.stroke(frame, edge, Kit.Ink)
	end
	return frame
end

-- N3, Badge: a small sign of the land behind its number, built of frames. Returns the parts to grey out when locked.
local function signOf(parent: Instance, land: number, z: number): { Frame }
	local colour = Kit.Lands[land]
	local parts: { Frame } = {}
	local function part(props: { [string]: any }, radius: number?, edge: number?): Frame
		props.ZIndex = props.ZIndex or z
		props.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
		local frame = blob(parent, props, radius, edge)
		table.insert(parts, frame)
		return frame
	end
	local mid = UDim2.fromScale(0.5, 0.5)
	if land == 1 then -- a sun: a disc with a ring of rays (a turned square behind it)
		part(
			{ Position = mid, Size = UDim2.fromOffset(13, 13), Rotation = 45, BackgroundColor3 = rgb(255, 200, 70) },
			2,
			1.2
		)
		part({ Position = mid, Size = UDim2.fromOffset(12, 12), BackgroundColor3 = rgb(255, 226, 110) }, 999, 1.2)
	elseif land == 2 then -- a coral head: three bumps on a disc
		for _, dx in { -4, 0, 4 } do
			part(
				{ Position = UDim2.new(0.5, dx, 0.5, -4), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = colour },
				999,
				1.2
			)
		end
		part({ Position = mid, Size = UDim2.fromOffset(14, 11), BackgroundColor3 = colour }, 999, 1.2)
	elseif land == 3 then -- a kelp leaf: a turned rounded square with a rib
		part({ Position = mid, Size = UDim2.fromOffset(11, 11), Rotation = 45, BackgroundColor3 = colour }, 5, 1.2)
		part({
			Position = mid,
			Size = UDim2.fromOffset(1.5, 13),
			Rotation = 45,
			BackgroundColor3 = Kit.darker(colour, 0.35),
		})
	elseif land == 4 then -- a porthole: a brass ring round dark glass
		part({ Position = mid, Size = UDim2.fromOffset(14, 14), BackgroundColor3 = rgb(214, 160, 70) }, 999, 1.2)
		part({ Position = mid, Size = UDim2.fromOffset(8, 8), BackgroundColor3 = rgb(40, 70, 90) }, 999, 1)
	elseif land == 5 then -- a bubble with its shine
		part({ Position = mid, Size = UDim2.fromOffset(14, 14), BackgroundColor3 = rgb(110, 190, 255) }, 999, 1.2)
		part({
			Position = UDim2.new(0.5, -3, 0.5, -3),
			Size = UDim2.fromOffset(4, 4),
			BackgroundColor3 = Kit.White,
			ZIndex = z + 1,
		}, 999)
	elseif land == 6 then -- a star: two squares turned against each other
		part({ Position = mid, Size = UDim2.fromOffset(11, 11), BackgroundColor3 = colour }, 2, 1.2)
		part({ Position = mid, Size = UDim2.fromOffset(11, 11), Rotation = 45, BackgroundColor3 = colour }, 2, 1.2)
	elseif land == 7 then -- a lure: a glowing orb
		local orb = part({ Position = mid, Size = UDim2.fromOffset(13, 13), BackgroundColor3 = rgb(70, 230, 255) }, 999)
		Kit.stroke(orb, 2, rgb(160, 255, 255), 0.35)
	elseif land == 8 then -- a flame: a tall diamond with a yellow heart
		part({
			Position = UDim2.new(0.5, 0, 0.5, -1),
			Size = UDim2.fromOffset(11, 11),
			Rotation = 45,
			BackgroundColor3 = rgb(255, 110, 40),
		}, 3, 1.2)
		part({
			Position = UDim2.new(0.5, 0, 0.5, 1),
			Size = UDim2.fromOffset(5, 5),
			Rotation = 45,
			BackgroundColor3 = rgb(255, 230, 90),
		}, 1)
	elseif land == 9 then -- a bone: a bar with knobs at both ends
		for _, dx in { -6, 6 } do
			for _, dy in { -2, 2 } do
				part({
					Position = UDim2.new(0.5, dx, 0.5, dy),
					Size = UDim2.fromOffset(5, 5),
					BackgroundColor3 = rgb(240, 234, 214),
				}, 999, 1.2)
			end
		end
		part({ Position = mid, Size = UDim2.fromOffset(13, 4), BackgroundColor3 = rgb(240, 234, 214) }, 1)
	else -- 10: horns on a dark disc
		for _, side in { -1, 1 } do
			part({
				Position = UDim2.new(0.5, side * 5, 0.5, -5),
				Size = UDim2.fromOffset(4, 8),
				Rotation = side * 30,
				BackgroundColor3 = rgb(250, 236, 220),
			}, 2, 1)
		end
		part({ Position = mid, Size = UDim2.fromOffset(13, 13), BackgroundColor3 = rgb(180, 30, 52) }, 999, 1.2)
	end
	return parts
end

type Number = {
	label: TextLabel,
	gradient: UIGradient,
	stroke: UIStroke,
	glow: UIStroke?,
	parts: { Frame },
	colours: { Color3 },
	set: (boolean) -> (),
}

-- The land's number at the tile's lower left, in style 1 Metal, 2 Material or 3 Badge. `set(true)` shows it in its
-- land's look, `set(false)` greyed as the land's picture is.
local function number(parent: Instance, land: number, style: number, z: number): Number
	local colour = Kit.Lands[land]
	local box = Kit.new("Frame", {
		Name = "Number",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -2, 1, 3),
		Size = UDim2.fromOffset(15, 15),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	local parts: { Frame } = if style == 3 then signOf(box, land, z) else {}
	local colours: { Color3 } = {}
	for i, frame in parts do
		colours[i] = frame.BackgroundColor3
	end
	local label: TextLabel = Kit.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = tostring(land),
		TextSize = if land >= 10 then (if style == 3 then 8.5 else 10.5) else (if style == 3 then 10 else 12.5),
		TextColor3 = Kit.White,
		ZIndex = z + 2,
	}, box)
	local stroke = Kit.stroke(label, if style == 3 then 1.4 else 1.8, Kit.Ink)
	local gradient: UIGradient = Kit.new("UIGradient", { Rotation = 90 }, label)
	local material = MATERIAL[land]
	local glow: UIStroke? = nil
	if style == 2 and material.Glow then
		-- a second, wider and see-through edge round the ink one: the glow (a label takes one stroke, so it sits on a
		-- copy of the letters under the first)
		local under: TextLabel = label:Clone()
		under.ZIndex = z + 1
		for _, child in under:GetChildren() do
			child:Destroy()
		end
		under.TextColor3 = material.Glow
		under.Parent = box
		glow = Kit.stroke(under, 2.6, material.Glow :: Color3, 0.5)
	end
	local function set(lit: boolean)
		if not lit then
			gradient.Color = ColorSequence.new(LOCKED_TOP, LOCKED_BOTTOM)
			gradient.Rotation = 90
			stroke.Color = Kit.Ink
			if glow then
				glow.Enabled = false
				(glow.Parent :: TextLabel).Visible = false
			end
			for _, frame in parts do
				local _, s, v = frame.BackgroundColor3:ToHSV()
				frame.BackgroundColor3 = Color3.fromHSV(0.62, math.min(s, 0.08), math.clamp(v * 0.75, 0.35, 0.8))
			end
			return
		end
		if style == 1 then
			gradient.Color = sequence({
				{ 0, Kit.lighter(colour, 0.65) },
				{ 0.5, Kit.lighter(colour, 0.15) },
				{ 1, Kit.darker(colour, 0.15) },
			})
			gradient.Rotation = 90
		elseif style == 2 then
			gradient.Color = sequence(material.Keys)
			gradient.Rotation = material.Rotation
			stroke.Color = material.Edge
			if glow then
				glow.Enabled = true
				(glow.Parent :: TextLabel).Visible = true
			end
		else
			gradient.Color = ColorSequence.new(Kit.White, rgb(226, 232, 242))
			gradient.Rotation = 90
		end
		for i, frame in parts do
			frame.BackgroundColor3 = colours[i]
		end
	end
	set(true)
	return {
		label = label,
		gradient = gradient,
		stroke = stroke,
		glow = glow,
		parts = parts,
		colours = colours,
		set = set,
	}
end

-- The padlock on a land not reached: a white body and its shackle, ink edged
local function padlock(parent: Instance, z: number): Frame
	local lock = Kit.new("Frame", {
		Name = "Lock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 2, 0.5, -1),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	local shackle = blob(lock, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(7, 9),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, 999)
	Kit.stroke(shackle, 3.4, Kit.Ink)
	local inner = blob(shackle, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z + 1 }, 999)
	Kit.stroke(inner, 1.6, Kit.White)
	blob(lock, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(10, 7),
		BackgroundColor3 = Kit.White,
		ZIndex = z + 2,
	}, 2, 1.2)
	blob(lock, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(1.5, 3),
		BackgroundColor3 = Kit.Ink,
		ZIndex = z + 3,
	})
	return lock
end

-- The tick on a land you have been all through: a green disc, white check
local function tick(parent: Instance, z: number): Frame
	local disc = blob(parent, {
		Name = "Tick",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -1, 0, 1),
		Size = UDim2.fromOffset(9, 9),
		BackgroundColor3 = rgb(60, 190, 70),
		ZIndex = z,
	}, 999, 1.2)
	blob(disc, {
		Position = UDim2.fromOffset(1.6, 4.2),
		Size = UDim2.fromOffset(3.2, 1.6),
		Rotation = 45,
		BackgroundColor3 = Kit.White,
		ZIndex = z + 1,
	})
	blob(disc, {
		Position = UDim2.fromOffset(3.2, 3.4),
		Size = UDim2.fromOffset(5, 1.6),
		Rotation = -50,
		BackgroundColor3 = Kit.White,
		ZIndex = z + 1,
	})
	return disc
end

type Tile = {
	root: Frame,
	scale: UIScale,
	rim: UIStroke,
	clip: Frame,
	edge: Frame,
	lock: Frame,
	tick: Frame,
	number: Number,
	shown: number,
	current: boolean,
}

buildA = function(parent: Instance, options: { Numbers: number, Reveal: string, Atlas: string, Fixed: boolean? }): any
	local strip = Kit.new("Frame", {
		Name = "LandStrip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(A_WIDE, A_TILE + 40),
		BackgroundTransparency = 1,
	}, parent)
	local tiles: { Tile } = {}
	for i = 1, COUNT do
		local colour = Kit.Lands[i]
		local root = blob(strip, {
			Name = "Land" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((i - 1) * (A_TILE + A_GAP) + A_TILE / 2, A_TILE / 2),
			Size = UDim2.fromOffset(A_TILE, A_TILE),
			BackgroundColor3 = Kit.Ink,
			ZIndex = 2,
		}, 6)
		local scale = Kit.new("UIScale", {}, root)
		local rim = Kit.stroke(root, 2, Kit.White)
		rim.Enabled = false
		-- the grey picture, then the colour one over it in a frame that grows from the left
		local function picture(row: number, into: Instance, z: number): ImageLabel
			local image: ImageLabel = Kit.new("ImageLabel", {
				Position = UDim2.fromOffset(if row == 0 then 0 else A_FRAME, if row == 0 then 0 else A_FRAME),
				Size = UDim2.fromOffset(A_INNER, A_INNER),
				-- the land's colour (or its grey) shows until the pictures are uploaded
				BackgroundColor3 = if row == 0 then colour else colour:Lerp(rgb(96, 104, 124), 0.75),
				BorderSizePixel = 0,
				Image = options.Atlas,
				ImageRectOffset = Vector2.new((i - 1) * LAND_CELL, row * LAND_CELL),
				ImageRectSize = Vector2.new(LAND_CELL, LAND_CELL),
				ScaleType = Enum.ScaleType.Stretch,
				ZIndex = z,
			}, into)
			Kit.corner(image, 3.5)
			return image
		end
		picture(1, root, 3)
		local clip = Kit.new("Frame", {
			Name = "Reveal",
			Position = UDim2.fromOffset(A_FRAME, A_FRAME),
			Size = UDim2.fromOffset(0, A_INNER),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 4,
		}, root)
		picture(0, clip, 4)
		-- the line where the colour meets the grey
		local edge = blob(root, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(A_FRAME, A_FRAME),
			Size = UDim2.fromOffset(1.5, A_INNER),
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = 0.25,
			Visible = false,
			ZIndex = 5,
		})
		-- a pale shine along the picture's top
		blob(root, {
			Position = UDim2.fromOffset(A_FRAME + 3, A_FRAME + 1),
			Size = UDim2.fromOffset(A_INNER - 6, 1.2),
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = 0.5,
			ZIndex = 6,
		})
		tiles[i] = {
			root = root,
			scale = scale,
			rim = rim,
			clip = clip,
			edge = edge,
			lock = padlock(root, 7),
			tick = tick(root, 7),
			number = number(root, i, options.Numbers, 8),
			shown = -1,
			current = false,
		}
	end

	-- your best: a yellow dashed line through the strip, "BEST 1,240 m" hanging from its foot
	local best = Kit.new("Frame", {
		Name = "Best",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(6, A_TILE + 14),
		Position = UDim2.fromOffset(0, -4),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
	}, strip)
	local DASH, SPACE = 3.5, 2.5
	local y = 0
	while y < A_TILE + 10 do
		blob(best, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.fromOffset(2, DASH),
			BackgroundColor3 = Kit.Sun,
			ZIndex = 20,
		}, nil, 1)
		y += DASH + SPACE
	end
	local bestTag = Kit.new("Frame", {
		Name = "Tag",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 12),
		BackgroundColor3 = Kit.Deep,
		BackgroundTransparency = 0.1,
		ZIndex = 20,
	}, best)
	Kit.corner(bestTag, 999)
	Kit.stroke(bestTag, 1.5, Kit.Sun)
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, bestTag)
	local bestWords: TextLabel = Kit.new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 12),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 8,
		TextColor3 = Kit.Sun,
		Text = "BEST",
		ZIndex = 21,
	}, bestTag)
	Kit.stroke(bestWords, 1.2, Kit.Ink)

	-- you: your avatar's face in a round frame, a notch pointing up at the strip, the metres on a bar under it
	local marker = Kit.new("Frame", {
		Name = "You",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, A_TILE + 4),
		Size = UDim2.fromOffset(FACE, FACE + 16),
		BackgroundTransparency = 1,
		ZIndex = 30,
	}, strip)
	blob(marker, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(6, 6),
		Rotation = 45,
		BackgroundColor3 = Kit.White,
		ZIndex = 30,
	}, 1, 1.5)
	local disc = blob(marker, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(FACE, FACE),
		BackgroundColor3 = Kit.White,
		ZIndex = 31,
	}, 999, 2)
	local face: ImageLabel = Kit.new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = rgb(61, 139, 240),
		BorderSizePixel = 0,
		ZIndex = 32,
	}, disc)
	Kit.corner(face, 999)
	local player = Players.LocalPlayer
	if player then
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(
					math.max(player.UserId, 1),
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size48x48
				)
			end)
			if ok then
				face.Image = image
			end
		end)
	end
	local bar = Kit.new("Frame", {
		Name = "Metres",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, FACE + 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 12),
		ZIndex = 31,
	}, marker)
	local barLook = Kit.dress(bar, {
		Top = Kit.Navy,
		Bottom = Kit.Ink,
		Outline = Kit.Outline.Thin,
		Radius = Kit.Radius.Round,
		Bevel = false,
	})
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, bar)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)
	local barLand: TextLabel = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 12),
		TextSize = 7.5,
		LayoutOrder = 1,
		Visible = false,
		ZIndex = 32,
	}, bar)
	local barText: TextLabel = Kit.new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 12),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 8.5,
		TextColor3 = Kit.White,
		Text = "0 m",
		LayoutOrder = 2,
		ZIndex = 32,
	}, bar)
	Kit.stroke(barText, 1.3, Kit.Ink)

	local self = {}
	local aLand, aMetres, aX, aBest, aSide = -1, -1, -1, -1, 0

	local function xOf(lands: number): number
		local index = math.clamp(math.floor(lands), 0, COUNT - 1)
		return index * (A_TILE + A_GAP) + math.clamp(lands - index, 0, 1) * A_TILE
	end

	local function reveal(i: number, share: number)
		local tile = tiles[i]
		share = math.clamp(share, 0, 1)
		local px = math.floor(share * A_INNER * 4 + 0.5) / 4
		if px == tile.shown then
			return
		end
		local was = tile.shown
		tile.shown = px
		tile.clip.Size = UDim2.fromOffset(px, A_INNER)
		tile.edge.Visible = px > 0 and px < A_INNER
		tile.edge.Position = UDim2.fromOffset(A_FRAME + px, A_FRAME)
		tile.lock.Visible = px <= 0
		tile.tick.Visible = px >= A_INNER
		if (was <= 0) ~= (px <= 0) or was < 0 then
			tile.number.set(px > 0)
		end
	end

	function self.place(phone: boolean)
		barLand.Visible = phone
		aBest = -1
	end

	-- the same arguments as LandStrip.update; the best comes from the server (BestLands, BestMetres) when it is there
	function self.update(
		land: number,
		landName: string,
		along: number,
		metres: number,
		bestLands: number,
		bestMetres: number
	)
		strip.Visible = true
		local at = math.max(land, 1)
		local here = if land >= 1 then land - 1 + math.clamp(along, 0, 1) else 0
		if player and not options.Fixed then
			local served = player:GetAttribute("BestLands")
			if typeof(served) == "number" then
				bestLands = served
				bestMetres = (player:GetAttribute("BestMetres") :: number?) or bestMetres
			end
		end
		local reach = if options.Reveal == "Best" then math.max(here, bestLands) else here
		for i = 1, COUNT do
			reveal(i, reach - (i - 1))
		end
		if land ~= aLand then
			aLand = land
			for i, tile in tiles do
				local now = i == land
				if now ~= tile.current then
					tile.current = now
					tile.scale.Scale = if now then A_POP else 1
					tile.rim.Enabled = now
					tile.root.ZIndex = if now then 10 else 2
				end
			end
			local colour = Kit.Lands[math.clamp(at, 1, COUNT)]
			barLook.paint(Kit.darker(colour, 0.38), Kit.darker(colour, 0.72))
			barLand.Text = string.upper(landName)
			barLand.TextColor3 = Kit.lighter(colour, 0.35)
		end
		local whole = math.floor(metres)
		if whole ~= aMetres then
			aMetres = whole
			barText.Text = grouped(whole) .. " m"
		end
		local x = math.floor(xOf(here) * 4 + 0.5) / 4
		if x ~= aX then
			aX = x
			marker.Position = UDim2.fromOffset(x, A_TILE + 4)
		end
		local bestWhole = math.floor(bestMetres)
		local bx = xOf(bestLands)
		-- the tag hangs on the side away from you, so the two never cover each other; when you are at the line (on
		-- your way to a new best) it hangs centred under your metres instead
		local side = if math.abs(x - bx) < 48 then 0 elseif x > bx then -1 else 1
		if bestWhole ~= aBest or side ~= aSide then
			aBest = bestWhole
			aSide = side
			best.Visible = bestWhole > 0
			best.Position = UDim2.fromOffset(bx, -4)
			bestWords.Text = "BEST " .. grouped(bestWhole) .. " m"
			local drop = if side == 0 then FACE + 16 else 0
			-- kept inside the strip at its two ends
			if side == 0 then
				local shift = math.clamp(bx, 34, A_WIDE - 34) - bx
				bestTag.AnchorPoint = Vector2.new(0.5, 0)
				bestTag.Position = UDim2.new(0.5, shift, 1, drop)
			elseif side < 0 or bx > A_WIDE - 50 then
				bestTag.AnchorPoint = Vector2.new(1, 0)
				bestTag.Position = UDim2.new(0.5, 3, 1, drop)
			else
				bestTag.AnchorPoint = Vector2.new(0, 0)
				bestTag.Position = UDim2.new(0.5, -3, 1, drop)
			end
		end
	end

	self.root = strip
	self.place(false)
	return self
end

-- For the options sheets and tests: another strip of style 1 under `parent`, with its own options
function LandStrip.preview(
	parent: Instance,
	options: { Numbers: number, Reveal: string, Atlas: string, Fixed: boolean? }
): any
	return buildA(parent, options)
end

return LandStrip
