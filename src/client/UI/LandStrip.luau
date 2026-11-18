--!strict
-- The strip of the ten lands across the top (where the reference has its zone strip): a dark tray of bricks with a
-- thick outline and a shadow, holding ten tiles, each in its own land's colour (the map's), lighter at the top, with a
-- pale line along its top edge. The land you are in is framed in white. Your badge sits on the tiles' lower edge with
-- the metres under it, on a pill in that land's colour; your best is a thin yellow line with a diamond and its metres.
-- On a keyboard the tiles carry the lands' names and the pill only the metres; on a phone the tiles carry numbers and
-- the pill the land's name too.
-- Style 1 (Kit.LandStripStyle, task l1, the game's) is further down: each land a framed picture that colours in as you
-- go, built to Hugo's picks of 2026-11-18.
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

export type Options = {
	Numbers: number,
	Reveal: string,
	Atlas: string,
	Fixed: boolean?,
	-- Best, You, Lock, Line, Numbers: task s2's switches, unread since Hugo picked (task l1). The rest: nil = Kit's
	Best: number?,
	You: number?,
	Lock: number?,
	Line: number?,
	Dark: number?,
	Saturation: number?,
	Blur: number?,
	Tint: Color3?,
	Intro: number?, -- Kit.LandIntroLook
	Font: Enum.Font?, -- Kit.LandMetresFont
}

local buildA: (parent: Instance, options: Options) -> any
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

-- The land intro in use (Kit.LandIntroLook, or in Studio the workspace's "LandIntroLook"); 0 when the strip is not
-- style 1. HudController asks this too, so the old land banner plays exactly when no intro does.
function LandStrip.introLook(): number
	if setting("LandStripStyle", Kit.LandStripStyle) ~= 1 then
		return 0
	end
	return setting("LandIntroLook", Kit.LandIntroLook)
end

function LandStrip.build(parent: Instance)
	if setting("LandStripStyle", Kit.LandStripStyle) == 1 then
		active = buildA(parent, {
			Numbers = 0,
			Reveal = setting("LandReveal", Kit.LandReveal),
			Atlas = (function(): string
				local atlas = setting("LandAtlas", Kit.LandAtlas)
				if atlas == "" and RunService:IsStudio() then
					return Kit.LandAtlasStudio
				end
				return atlas
			end)(),
			Dark = setting("LandDark", Kit.LandLocked.Dark),
			Saturation = setting("LandSaturation", Kit.LandLocked.Saturation),
			Blur = setting("LandBlur", Kit.LandLocked.Blur),
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
-- Style 1: the framed pictures (Hugo, 2026-11-17; built to Hugo's picks of 2026-11-18, task l1, docs/design/ui.md
-- "The land strip, Hugo's picks"). Ten pictures (the generated set G4), each with one even ink border and nothing
-- behind them; the land you are in a size up with a white border. A land you have never reached is locked: its own
-- picture darker and desaturated with a white padlock. The first time your best gets into it the lock cracks, falls
-- and fades (half a second) and never comes back; its colour then fills from the left as your best goes on through it.
-- Under the pictures a thin bar: white to where you are, then a gradient on to gold at your best, where a gold diamond
-- sits on it with "BEST 1,300 m" under it. Your face in a black ring rides under the bar with the metres on a flat
-- black oval. Every number and word is a rarity word (Kit.word) in its land's colour; your best is gold. Entering a
-- land plays its intro (Kit.LandIntroLook).
-- ============================================================================================================

local TweenService = game:GetService("TweenService")

-- How slowly the breaks and intros play (1 the game's; the capture scripts slow them to shoot them frame by frame)
LandStrip.Slow = 1
local function pace(seconds: number): number
	return seconds * LandStrip.Slow
end

local A_TILE = 28
local A_BIG = 32 -- the land you are in
-- the tiles either side of the land you are in move this far away from it, so its bigger picture, white border and
-- ink line never cover their numbers or ticks (Nemu's review, round 1: 2 px of gap was not room for 5.5 px of border)
local A_ROOM = 6
local A_GAP = 2
local A_STEP = A_TILE + A_GAP
local A_WIDE = COUNT * A_TILE + (COUNT - 1) * A_GAP
local A_EDGE = 2 -- every picture's border
local A_RADIUS = 5
local LAND_CELL = 96 -- one picture's square in the atlas (tools/ui/land_icons/atlas.py)
local FACE = 18 -- the avatar's disc
local RAIL_Y = A_TILE + 6 -- the bar's middle, under the pictures
local RAIL_HIGH = 3
local LOCK = 16 -- the padlock's box (a 12 px padlock in it, room for its edge)
local BREAK_TIME = 0.5

-- the lands whose locks are broken this session (by your best; session-only until saving exists)
local brokenLive: { [number]: boolean } = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

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

local function palOfLand(i: number): Kit.Pal
	return Kit.palOf(Kit.Lands[math.clamp(i, 1, COUNT)])
end

-- The white padlock, ink edged, in a 12 px box
local function padlockShape(lock: Instance, z: number)
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
	local box = blob(lock, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(10, 7),
		BackgroundColor3 = Kit.White,
		ZIndex = z + 2,
	}, 2)
	Kit.stroke(box, 1.2, Kit.Ink)
	blob(lock, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(1.5, 3),
		BackgroundColor3 = Kit.Ink,
		ZIndex = z + 3,
	})
end

type Lock = { root: Frame, halves: { CanvasGroup }, flash: Frame, crack: Frame, gone: boolean }

-- The lock: two halves of one padlock (each a canvas, so a half fades as one), so it can crack apart
local function lockOf(parent: Instance, z: number): Lock
	local root = Kit.new("Frame", {
		Name = "Lock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(LOCK, LOCK),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	local halves: { CanvasGroup } = {}
	for side = 0, 1 do
		local half: CanvasGroup = Kit.new("CanvasGroup", {
			Name = if side == 0 then "Left" else "Right",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(LOCK / 4 + side * LOCK / 2, LOCK / 2),
			Size = UDim2.fromOffset(LOCK / 2, LOCK),
			BackgroundTransparency = 1,
			ZIndex = z,
		}, root)
		local whole = Kit.new("Frame", {
			Position = UDim2.fromOffset(2 - side * LOCK / 2, 2),
			Size = UDim2.fromOffset(12, 12),
			BackgroundTransparency = 1,
			ZIndex = z,
		}, half)
		padlockShape(whole, z)
		halves[side + 1] = half
	end
	-- the crack: a dark zigzag down the middle, seen for the first moment of the break
	local crack = blob(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 3),
		Size = UDim2.fromOffset(1.2, 6),
		Rotation = 12,
		BackgroundColor3 = Kit.Ink,
		Visible = false,
		ZIndex = z + 5,
	})
	local flash = blob(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 1,
		ZIndex = z + 6,
	}, 999)
	return { root = root, halves = halves, flash = flash, crack = crack, gone = false }
end

-- Gone at once (a land already reached when the strip is built)
local function lockGone(lock: Lock)
	lock.gone = true
	lock.root.Visible = false
end

-- The break: a white burst and a crack, then the two halves tip apart, fall and fade
local function lockBreak(lock: Lock)
	if lock.gone then
		return
	end
	lock.gone = true
	lock.crack.Visible = true
	lock.flash.BackgroundTransparency = 0.2
	lock.flash.Size = UDim2.fromOffset(6, 6)
	TweenService:Create(
		lock.flash,
		TweenInfo.new(pace(0.22), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1 }
	):Play()
	task.delay(pace(0.07), function()
		lock.crack.Visible = false
		-- they drop at once and slow, and fade late, so the fall is seen
		local fall = TweenInfo.new(pace(BREAK_TIME - 0.07), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local fade = TweenInfo.new(pace(BREAK_TIME - 0.07), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for k, half in lock.halves do
			local side = if k == 1 then -1 else 1
			TweenService:Create(half, fall, {
				Position = half.Position + UDim2.fromOffset(side * 5, 15),
				Rotation = side * 40,
			}):Play()
			TweenService:Create(half, fade, { GroupTransparency = 1 }):Play()
		end
		task.delay(pace(BREAK_TIME), function()
			lock.root.Visible = false
		end)
	end)
end

-- The tick on a land you have been all through: a green disc, white check
local function tick(parent: Instance, z: number): Frame
	local disc = blob(parent, {
		Name = "Tick",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -3, 0, 2),
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
	border: UIStroke,
	outer: Frame,
	clip: Frame,
	colour: ImageLabel,
	edge: Frame,
	lock: Lock,
	tick: Frame,
	number: Kit.Word,
	size: number,
	share: number,
	shown: number,
	lit: boolean?,
	current: boolean,
}

-- In Studio, the font named in the workspace's "LandMetresFont"
local function fontSetting(): Enum.Font
	local name = setting("LandMetresFont", "")
	if name ~= "" then
		local ok, font = pcall(function()
			return (Enum.Font :: any)[name]
		end)
		if ok and font then
			return font
		end
	end
	return Kit.LandMetresFont
end

-- ---- the intros (Kit.LandIntroLook) ----

-- A plate with the chunky treatment: a gradient in the land's colours, a lit top, a thick ink edge, a dark drop
local function plate(parent: Instance, props: { [string]: any }, p: Kit.Pal): Frame
	local z = props.ZIndex or 1
	local shadow = blob(parent, {
		AnchorPoint = props.AnchorPoint,
		Position = (props.Position :: UDim2) + UDim2.fromOffset(0, 4),
		Size = props.Size,
		BackgroundColor3 = Kit.Ink,
		BackgroundTransparency = 0.35,
		ZIndex = z,
	}, 10)
	props.ZIndex = z + 1
	props.BackgroundColor3 = Kit.White
	local face = blob(parent, props, 10)
	Kit.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, p.Mid:Lerp(p.Light, 0.35)),
			ColorSequenceKeypoint.new(0.5, p.Mid:Lerp(p.Dark, 0.35)),
			ColorSequenceKeypoint.new(1, p.Dark:Lerp(p.Deep, 0.4)),
		}),
	}, face)
	Kit.stroke(face, 3, Kit.Ink)
	local gloss = blob(face, {
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, 0.42, 0),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 0.72,
		ZIndex = z + 2,
	}, 7)
	local _ = gloss
	face:GetPropertyChangedSignal("Position"):Connect(function()
		shadow.Position = face.Position + UDim2.fromOffset(0, 4)
	end)
	return face
end

type IntroArgs = { land: number, name: string, metres: number, new: boolean }

local function canvas(parent: Instance, props: { [string]: any }): CanvasGroup
	props.BackgroundTransparency = 1
	props.GroupTransparency = props.GroupTransparency or 1
	return Kit.new("CanvasGroup", props, parent)
end

local function fadeOut(group: CanvasGroup, after: number, time: number, extra: { [string]: any }?)
	task.delay(pace(after), function()
		if not group.Parent then
			return
		end
		local goal: { [string]: any } = { GroupTransparency = 1 }
		if extra then
			for k, v in extra do
				goal[k] = v
			end
		end
		local tween =
			TweenService:Create(group, TweenInfo.new(pace(time), Enum.EasingStyle.Quad, Enum.EasingDirection.In), goal)
		tween.Completed:Once(function()
			group:Destroy()
		end)
		tween:Play()
	end)
end

-- 1 Punch: the name big at the top centre, "LAND 3" over it, NEW LAND in gold the first time
local function introPunch(layer: Instance, a: IntroArgs)
	local p = palOfLand(a.land)
	local glow = Kit.LandGlows[a.land] == true
	local group = canvas(layer, {
		Name = "IntroPunch",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(620, 116),
		ZIndex = 60,
	})
	local scale = Kit.new("UIScale", { Scale = 1.9 }, group)
	local name = Kit.word(group, {
		Text = string.upper(a.name),
		TextSize = 46,
		Pal = p,
		Glow = true,
		Position = UDim2.new(0.5, 0, 0, 74),
		ZIndex = 4,
	})
	local _ = name
	Kit.word(group, {
		Text = "LAND " .. a.land,
		TextSize = 19,
		Pal = p,
		Glow = glow,
		Position = UDim2.new(0.5, 0, 0, 34),
		ZIndex = 4,
	})
	if a.new then
		Kit.word(group, {
			Text = "NEW LAND!",
			TextSize = 15,
			Pal = Kit.GoldPal,
			Glow = true,
			Position = UDim2.new(0.5, 0, 0, 12),
			ZIndex = 4,
		})
	end
	TweenService:Create(group, TweenInfo.new(pace(0.1)), { GroupTransparency = 0 }):Play()
	TweenService
		:Create(scale, TweenInfo.new(pace(0.32), Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	fadeOut(group, 1.5, 0.35)
	task.delay(pace(1.5), function()
		if scale.Parent then
			TweenService:Create(scale, TweenInfo.new(pace(0.35)), { Scale = 1.08 }):Play()
		end
	end)
end

-- 2 Banner: a chunky plate in the land's colours slides in from the left
local function introBanner(layer: Instance, a: IntroArgs)
	local p = palOfLand(a.land)
	local group = canvas(layer, {
		Name = "IntroBanner",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(-320, 138),
		Size = UDim2.fromOffset(300, 74),
		GroupTransparency = 0,
		ZIndex = 60,
	})
	local face = plate(group, {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 58),
		ZIndex = 1,
	}, p)
	local _ = face
	Kit.word(group, {
		Text = (if a.new then "NEW!  " else "") .. "LAND " .. a.land .. " OF 10",
		TextSize = 12,
		Pal = if a.new then Kit.GoldPal else Kit.WhitePal,
		Position = UDim2.new(0.5, 0, 0, 20),
		ZIndex = 5,
	})
	Kit.word(group, {
		Text = string.upper(a.name),
		TextSize = 24,
		Pal = Kit.WhitePal,
		Glow = false,
		Position = UDim2.new(0.5, 0, 0, 42),
		ZIndex = 5,
	})
	TweenService:Create(
		group,
		TweenInfo.new(pace(0.34), Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(14, 138) }
	):Play()
	fadeOut(group, 1.7, 0.3, { Position = UDim2.fromOffset(-320, 138) })
end

-- 3 Fly: the strip's tile pops and flies to the centre, the name under it, then goes back
local function introFly(layer: Instance, a: IntroArgs, from: Vector2, atlas: string)
	local p = palOfLand(a.land)
	local group = canvas(layer, {
		Name = "IntroFly",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(from.X, from.Y),
		Size = UDim2.fromOffset(240, 150),
		GroupTransparency = 0,
		ZIndex = 60,
	})
	local scale = Kit.new("UIScale", { Scale = 0.33 }, group)
	local picture: ImageLabel = Kit.new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(96, 96),
		BorderSizePixel = 0,
		BackgroundColor3 = Kit.Lands[a.land],
		Image = atlas,
		ImageRectOffset = Vector2.new((a.land - 1) * LAND_CELL, 0),
		ImageRectSize = Vector2.new(LAND_CELL, LAND_CELL),
		ZIndex = 2,
	}, group)
	Kit.corner(picture, 14)
	Kit.stroke(picture, 5, Kit.White)
	local word = Kit.word(group, {
		Text = string.upper(a.name),
		TextSize = 26,
		Pal = p,
		Glow = true,
		Position = UDim2.new(0.5, 0, 0, 122),
		ZIndex = 4,
	})
	word.root.Visible = false
	Kit.word(picture, {
		Text = tostring(a.land),
		TextSize = 30,
		Pal = p,
		Glow = Kit.LandGlows[a.land] == true,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 2, 1, 4),
		ZIndex = 6,
	})
	local centre = UDim2.new(0.5, 0, 0, 160)
	-- the pop where it is, then the flight
	TweenService
		:Create(scale, TweenInfo.new(pace(0.12), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.5 })
		:Play()
	task.delay(pace(0.12), function()
		local fly = TweenInfo.new(pace(0.38), Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(group, fly, { Position = centre }):Play()
		TweenService:Create(scale, fly, { Scale = 1 }):Play()
		task.delay(pace(0.3), function()
			word.root.Visible = true
		end)
	end)
	fadeOut(group, 1.7, 0.35, { Position = UDim2.fromOffset(from.X, from.Y) })
	task.delay(pace(1.7), function()
		if scale.Parent then
			TweenService
				:Create(
					scale,
					TweenInfo.new(pace(0.35), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Scale = 0.3 }
				)
				:Play()
		end
	end)
end

-- 4 Subtitle: one line under the strip
local function introSubtitle(layer: Instance, a: IntroArgs, y: number)
	local p = palOfLand(a.land)
	local group = canvas(layer, {
		Name = "IntroSubtitle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y + 8),
		Size = UDim2.fromOffset(520, 30),
		ZIndex = 60,
	})
	local text = "LAND " .. a.land .. "  ·  " .. string.upper(a.name) .. "  ·  " .. grouped(a.metres) .. " m"
	if a.new then
		text = "NEW!  " .. text
	end
	Kit.word(group, {
		Text = text,
		TextSize = 15,
		Pal = p,
		Glow = Kit.LandGlows[a.land] == true,
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 4,
	})
	TweenService:Create(
		group,
		TweenInfo.new(pace(0.25), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0, y) }
	):Play()
	fadeOut(group, 2.0, 0.4)
end

-- 5 Flash: the screen flashes the land's colour, the depth punches in with the name under it
local function introFlash(layer: Instance, a: IntroArgs)
	local p = palOfLand(a.land)
	local flash = blob(layer, {
		Name = "IntroFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = p.Mid,
		BackgroundTransparency = 0.45,
		ZIndex = 58,
	})
	TweenService:Create(flash, TweenInfo.new(pace(0.7), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	task.delay(pace(0.75), function()
		flash:Destroy()
	end)
	local group = canvas(layer, {
		Name = "IntroDepth",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(420, 110),
		GroupTransparency = 0,
		ZIndex = 60,
	})
	local scale = Kit.new("UIScale", { Scale = 2.2 }, group)
	Kit.word(group, {
		Text = grouped(a.metres) .. " m",
		TextSize = 44,
		Font = fontSetting(),
		Pal = if a.new then Kit.GoldPal else Kit.WhitePal,
		Glow = true,
		Position = UDim2.new(0.5, 0, 0, 36),
		ZIndex = 4,
	})
	Kit.word(group, {
		Text = "LAND " .. a.land .. "  ·  " .. string.upper(a.name),
		TextSize = 17,
		Pal = p,
		Glow = Kit.LandGlows[a.land] == true,
		Position = UDim2.new(0.5, 0, 0, 82),
		ZIndex = 4,
	})
	TweenService
		:Create(scale, TweenInfo.new(pace(0.26), Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	fadeOut(group, 1.4, 0.35)
end

buildA = function(parent: Instance, options: Options): any
	local dark = options.Dark or Kit.LandLocked.Dark
	local saturation = options.Saturation or Kit.LandLocked.Saturation
	local blur = math.clamp(math.floor(options.Blur or Kit.LandLocked.Blur), 0, 2)
	local tint = options.Tint or Kit.LandLocked.Tint
	local shade = Color3.new(tint.R * dark, tint.G * dark, tint.B * dark)
	local broken: { [number]: boolean } = if options.Fixed then {} else brokenLive
	local brokeAt: { [number]: number } = {}
	local metresFont = options.Font or fontSetting()

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
		-- one frame the size of the picture; its border is one stroke round it, nothing under it
		local root = Kit.new("Frame", {
			Name = "Land" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((i - 1) * A_STEP + A_TILE / 2, A_TILE / 2),
			Size = UDim2.fromOffset(A_TILE, A_TILE),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, strip)
		Kit.corner(root, A_RADIUS)
		local border = Kit.stroke(root, A_EDGE, Kit.Ink)
		border.LineJoinMode = Enum.LineJoinMode.Round
		-- the land you are in: the white border, and a thin ink line round it so it holds on bright water
		local outer = Kit.new("Frame", {
			Name = "Outer",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 2 * A_EDGE, 1, 2 * A_EDGE),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 2,
		}, root)
		Kit.corner(outer, A_RADIUS + A_EDGE)
		Kit.stroke(outer, 1.5, Kit.Ink)
		local function picture(row: number, into: Instance, z: number, props: { [string]: any }): ImageLabel
			props.Size = UDim2.fromOffset(A_TILE, A_TILE)
			props.BorderSizePixel = 0
			props.Image = options.Atlas
			props.ImageRectOffset = Vector2.new((i - 1) * LAND_CELL, row * LAND_CELL)
			props.ImageRectSize = Vector2.new(LAND_CELL, LAND_CELL)
			props.ScaleType = Enum.ScaleType.Stretch
			props.ZIndex = z
			local image: ImageLabel = Kit.new("ImageLabel", props, into)
			Kit.corner(image, A_RADIUS)
			return image
		end
		-- not reached: the grey copy, the colour one over it at the saturation, both darkened (Kit.LandLocked).
		-- Without the atlas, the land's colour the same way.
		local flat = colour:Lerp(rgb(128, 128, 128), 1 - saturation)
		local grey = picture(1 + blur * 2, root, 3, {
			ImageColor3 = shade,
			BackgroundColor3 = Color3.new(flat.R * shade.R, flat.G * shade.G, flat.B * shade.B),
		})
		grey.Size = UDim2.fromScale(1, 1)
		local over = picture(blur * 2, root, 4, {
			ImageColor3 = shade,
			ImageTransparency = 1 - saturation,
			BackgroundTransparency = 1,
		})
		over.Size = UDim2.fromScale(1, 1)
		-- then the colour picture uncovered from the left
		local clip = Kit.new("Frame", {
			Name = "Reveal",
			Size = UDim2.fromOffset(0, A_TILE),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 5,
		}, root)
		local full = picture(0, clip, 5, { BackgroundColor3 = colour })
		-- the line where the colour meets the grey
		local edge = blob(root, {
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(0, 1, 1, 0),
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = 0.3,
			Visible = false,
			ZIndex = 6,
		})
		local number = Kit.word(root, {
			Name = "Number",
			Text = tostring(i),
			TextSize = if i >= 10 then 11.5 else 13,
			Pal = Kit.LockedPal,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 3),
			ZIndex = 12, -- over the lock (8 to 14 for its burst)
		})
		tiles[i] = {
			root = root,
			border = border,
			outer = outer,
			clip = clip,
			colour = full,
			edge = edge,
			lock = lockOf(root, 8),
			tick = tick(root, 17),
			number = number,
			size = A_TILE,
			share = -1,
			shown = -1,
			lit = nil,
			current = false,
		}
	end

	-- the bar under the pictures: white to you, then the gradient on to gold at your best
	local rail = blob(strip, {
		Name = "Rail",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(0, RAIL_Y),
		Size = UDim2.fromOffset(A_WIDE, RAIL_HIGH),
		BackgroundColor3 = Kit.Deep,
		BackgroundTransparency = 0.2,
		ZIndex = 1,
	}, 999)
	Kit.stroke(rail, 1, Kit.Ink)
	local fill = blob(rail, {
		Name = "Fill",
		Size = UDim2.fromOffset(0, RAIL_HIGH),
		BackgroundColor3 = Kit.White,
		ZIndex = 2,
	}, 999)
	local fillShade: UIGradient = Kit.new("UIGradient", {}, fill)

	-- your best: Mix 3's gold diamond on the bar, BEST and the metres in gold under it
	local best = Kit.new("Frame", {
		Name = "Best",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, RAIL_Y),
		Size = UDim2.fromOffset(8, 8),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
	}, strip)
	local diamond = blob(best, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(7, 7),
		Rotation = 45,
		BackgroundColor3 = Kit.White,
		ZIndex = 21,
	}, 1.5, 1.4)
	Kit.new("UIGradient", { Rotation = 45, Color = Kit.wordFill(Kit.GoldPal) }, diamond)
	local bestWord = Kit.word(strip, {
		Name = "BestWord",
		Text = "BEST",
		TextSize = 11,
		Pal = Kit.GoldPal,
		Glow = true,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, RAIL_Y + 4),
		ZIndex = 22,
	})
	bestWord.root.Visible = false

	-- you: your face in a black ring, the metres on a flat black oval under it
	local marker = Kit.new("Frame", {
		Name = "You",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, RAIL_Y + 3),
		Size = UDim2.fromOffset(FACE, FACE + 14),
		BackgroundTransparency = 1,
		ZIndex = 30,
	}, strip)
	local disc = blob(marker, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(FACE, FACE),
		BackgroundColor3 = rgb(61, 139, 240),
		ZIndex = 34,
	}, 999)
	Kit.stroke(disc, 2, Color3.new(0, 0, 0))
	local headshot: ImageLabel = Kit.new("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 35,
	}, disc)
	Kit.corner(headshot, 999)
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
				headshot.Image = image
			end
		end)
	end
	local OVAL_HIGH = 17
	local oval = blob(marker, {
		Name = "Oval",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, FACE - 1),
		Size = UDim2.fromOffset(30, OVAL_HIGH),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		ZIndex = 31,
	}, 999)
	local metresWord = Kit.word(oval, {
		Name = "Metres",
		Text = "0 m",
		TextSize = 13,
		Font = metresFont,
		Pal = palOfLand(1),
		Position = UDim2.new(0.5, 0, 0.5, 0.5),
		ZIndex = 32,
	})
	local under = FACE - 1 + OVAL_HIGH -- how far under the marker's top it reaches, for the best's words to clear

	local self = {}
	local aLand, aMetres, aX, aBest, aSide, aRail = -1, -1, -1, -1, 0, ""
	local here = 0
	local seen = 0 -- the deepest land this dive (0 on the dock), for the intros
	local built = false
	local phoneScale = 1 -- Kit.LandPhoneScale on a phone (self.place)

	-- where a tile's centre is: its place in the row, moved A_ROOM away from the land you are in
	local function centreOf(i: number, land: number): number
		local x = (i - 1) * A_STEP + A_TILE / 2
		if land >= 1 and land <= COUNT and i ~= land then
			x += if i < land then -A_ROOM else A_ROOM
		end
		return x
	end

	-- a distance in lands (2.6: six tenths through land 3) as x along the strip, on the tiles as they stand
	local function xOf(lands: number): number
		local index = math.clamp(math.floor(lands), 0, COUNT - 1)
		local tile = tiles[index + 1]
		return centreOf(index + 1, aLand) - tile.size / 2 + math.clamp(lands - index, 0, 1) * tile.size
	end

	-- a tile's size (the land you are in is a size up); everything in it follows
	local function sized(tile: Tile, size: number)
		tile.size = size
		tile.root.Size = UDim2.fromOffset(size, size)
		tile.colour.Size = UDim2.fromOffset(size, size)
		tile.shown = -1
	end

	local function reveal(i: number, share: number)
		local tile = tiles[i]
		share = math.clamp(share, 0, 1)
		tile.share = share
		local px = math.floor(share * tile.size * 4 + 0.5) / 4
		if px == tile.shown then
			return
		end
		tile.shown = px
		tile.clip.Size = UDim2.fromOffset(px, tile.size)
		tile.edge.Visible = px > 0 and px < tile.size
		tile.edge.Position = UDim2.fromOffset(px, 0)
		tile.tick.Visible = px >= tile.size
	end

	-- a land's lock and number: reached (by your best) or not; `animate` false on the strip's first update
	local function reached(i: number, yes: boolean, animate: boolean)
		local tile = tiles[i]
		if tile.lit == yes then
			return
		end
		tile.lit = yes
		tile.number.paint(if yes then palOfLand(i) else Kit.LockedPal, yes and Kit.LandGlows[i] == true)
		if yes then
			if not broken[i] then
				broken[i] = true
				brokeAt[i] = os.clock()
			end
			if animate then
				lockBreak(tile.lock)
			else
				lockGone(tile.lock)
			end
		end
	end

	local function railFill(x: number, bx: number)
		local key = x .. ":" .. bx
		if key == aRail then
			return
		end
		aRail = key
		local reach = math.max(x, bx)
		fill.Size = UDim2.fromOffset(reach, RAIL_HIGH)
		if reach <= 0 then
			return
		end
		local you = math.clamp(x / reach, 0.001, 0.998)
		if bx <= x + 0.5 then
			fillShade.Color = ColorSequence.new(Kit.White)
		else
			fillShade.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Kit.White),
				ColorSequenceKeypoint.new(you, Kit.White),
				ColorSequenceKeypoint.new(math.min(you + (1 - you) * 0.25, 0.999), rgb(255, 244, 196)),
				ColorSequenceKeypoint.new(1, Kit.GoldPal.Mid),
			})
		end
	end

	local function intro(land: number, landName: string, metres: number, isNew: boolean)
		local look = options.Intro or LandStrip.introLook()
		if look == 0 or not strip.Parent then
			return
		end
		local layer = strip.Parent :: Instance
		local args: IntroArgs = { land = land, name = landName, metres = metres, new = isNew }
		if look == 2 then
			introBanner(layer, args)
		elseif look == 3 then
			local tile = tiles[land].root
			-- the tile's centre in the layer's own units (the HUD is scaled)
			local layerGui = layer :: GuiObject
			local k = if strip.AbsoluteSize.X > 0 then strip.AbsoluteSize.X / (A_WIDE * phoneScale) else 1
			local at = (tile.AbsolutePosition + tile.AbsoluteSize / 2 - layerGui.AbsolutePosition) / k
			introFly(layer, args, at, options.Atlas)
		elseif look == 4 then
			local y = strip.Position.Y.Offset + RAIL_Y + 3 + under + 14
			introSubtitle(layer, args, y)
		elseif look == 5 then
			introFlash(layer, args)
		else
			introPunch(layer, args)
		end
	end
	self.intro = intro

	-- on a phone the whole strip a size up (Kit.LandPhoneScale), so its numbers and words stay readable at HUD scale 1
	local stripScale = Kit.new("UIScale", {}, strip)
	function self.place(phone: boolean)
		phoneScale = if phone then Kit.LandPhoneScale else 1
		stripScale.Scale = phoneScale
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
		here = if land >= 1 then land - 1 + math.clamp(along, 0, 1) else 0
		if player and not options.Fixed then
			local served = player:GetAttribute("BestLands")
			if typeof(served) == "number" then
				bestLands = served
				bestMetres = (player:GetAttribute("BestMetres") :: number?) or bestMetres
			end
		end
		-- the locks, by your best (not where you are now)
		for i = 1, COUNT do
			local yes = broken[i] == true or bestLands > i - 1
			reached(i, yes, built)
		end
		local reach = if options.Reveal == "Dive" then here else math.max(here, bestLands)
		for i = 1, COUNT do
			reveal(i, reach - (i - 1))
		end
		if land ~= aLand then
			aLand = land
			for i, tile in tiles do
				local now = i == land
				if now ~= tile.current then
					tile.current = now
					sized(tile, if now then A_BIG else A_TILE)
					tile.border.Color = if now then Kit.White else Kit.Ink
					tile.outer.Visible = now
					tile.root.ZIndex = if now then 10 else 2
					reveal(i, tile.share)
				end
				tile.root.Position = UDim2.fromOffset(centreOf(i, land), A_TILE / 2)
			end
			metresWord.paint(palOfLand(at), Kit.LandGlows[at] == true)
			-- the intro: a land deeper than any yet this dive, not the one it starts in
			if land < 1 then
				seen = 0
			elseif seen == 0 or not built then
				seen = land
			elseif land > seen then
				seen = land
				-- new: never reached before (the server's best often catches up a moment after you get there)
				local isNew = not broken[land] or os.clock() - (brokeAt[land] or -10) < 1
				intro(land, landName, metres, isNew)
			end
		end
		built = true
		local whole = math.floor(metres)
		if whole ~= aMetres then
			aMetres = whole
			metresWord.set(grouped(whole) .. " m")
			oval.Size = UDim2.fromOffset(math.max(metresWord.wide + 10, 26), OVAL_HIGH)
		end
		local x = math.floor(xOf(here) * 4 + 0.5) / 4
		if x ~= aX then
			aX = x
			marker.Position = UDim2.fromOffset(x, RAIL_Y + 3)
		end
		local bestWhole = math.floor(bestMetres)
		local bx = math.floor(xOf(bestLands) * 4 + 0.5) / 4
		railFill(x, if bestWhole > 0 then bx else 0)
		-- BEST hangs under the diamond; when you are close to it (on your way to a new best) it hangs under your
		-- metres instead, so the two never cover each other
		local side = if math.abs(x - bx) < 40 then 0 else 1
		if bestWhole ~= aBest or side ~= aSide then
			aBest = bestWhole
			aSide = side
			best.Visible = bestWhole > 0
			bestWord.root.Visible = bestWhole > 0
			bestWord.set("BEST " .. grouped(bestWhole) .. " m")
		end
		if bestWhole > 0 then
			-- the tiles move when the land you are in changes, so the diamond follows every frame it has to
			local diamondAt = UDim2.fromOffset(bx, RAIL_Y)
			if best.Position ~= diamondAt then
				best.Position = diamondAt
			end
			local half = bestWord.wide / 2 + 1
			local wordAt = if side == 0
				then UDim2.fromOffset(math.clamp(x, half, A_WIDE - half), RAIL_Y + 3 + under + 1)
				else UDim2.fromOffset(math.clamp(bx, half, A_WIDE - half), RAIL_Y + 4)
			if bestWord.root.Position ~= wordAt then
				bestWord.root.Position = wordAt
			end
		end
	end

	self.root = strip
	self.place(false)
	return self
end

-- For the option sheets and tests: another strip of style 1 under `parent`, with its own options (its locks its own)
function LandStrip.preview(parent: Instance, options: Options): any
	return buildA(parent, options)
end

return LandStrip
