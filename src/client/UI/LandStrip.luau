--!strict
-- The strip of the ten lands across the top (where the reference has its zone strip): a dark tray of bricks with a
-- thick outline and a shadow, holding ten tiles, each in its own land's colour (the map's), lighter at the top, with a
-- pale line along its top edge. The land you are in is framed in white. Your badge sits on the tiles' lower edge with
-- the metres under it, on a pill in that land's colour; your best is a thin yellow line with a diamond and its metres.
-- On a keyboard the tiles carry the lands' names and the pill only the metres; on a phone the tiles carry numbers and
-- the pill the land's name too.
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

function LandStrip.build(parent: Instance)
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

return LandStrip
