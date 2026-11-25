--!strict
-- What a hub leaderboard says (NULLROOM task l1; docs/design/leaderboards.md): a SurfaceGui on its glass, in the HUD's
-- own letters and colours (UI.Kit, UI.Shop). The header in the board's colour (its name, what it counts, and whether
-- it lists ALL PLAYERS or only THIS SERVER), the list (place, face, name, number; the first three in gold, silver and
-- bronze, your own line ringed), and the foot: your own place and number, and when the next numbers come.
--   The list is a ScrollingFrame that holds only as many rows as show (Config.Boards.Rows and two more): the same rows
--   are written again as it is scrolled, so fifty places cost no more than eight.
--   Faces are Roblox's own head pictures (rbxthumb, which the engine loads once and keeps); a row asks for one only
--   when the player in it changes. Until it is there the first letter of the name shows.
-- Sizes are pixels on the canvas: PX of them to a stud.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boards = require(ReplicatedStorage.Shared.Boards)
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local BoardPanel = {}

local PX = 40 -- pixels to a stud
local FAR = 320 -- studs past which nothing is written
local PAD = 10
local HEAD = 124 -- the header's height
local STEP = 74 -- from one row to the next
local ROW = 68 -- a row's height
local RIM = 4 -- room round the rows for your own line's ring
local FOOT = 92 -- the foot's height
local WATER, DEEP = Color3.fromRGB(30, 92, 138), Color3.fromRGB(9, 28, 54)
local ROW_A, ROW_B = Color3.fromRGB(20, 58, 96), Color3.fromRGB(26, 70, 112)

-- The first three places: the row's two halves and the badge
local MEDALS = {
	{ Color3.fromRGB(255, 206, 60), Color3.fromRGB(232, 160, 24), Color3.fromRGB(255, 240, 150) },
	{ Color3.fromRGB(140, 164, 190), Color3.fromRGB(104, 128, 158), Color3.fromRGB(226, 236, 246) },
	{ Color3.fromRGB(190, 124, 78), Color3.fromRGB(154, 92, 54), Color3.fromRGB(240, 180, 128) },
}

type Row = { Id: number, Name: string, Value: number, Rank: number }
type Line = {
	Frame: Frame,
	Fill: UIGradient,
	Ring: UIStroke,
	Badge: Frame,
	BadgeFill: UIGradient,
	Rank: TextLabel,
	Face: ImageLabel,
	Letter: TextLabel,
	Name: TextLabel,
	Value: TextLabel,
	Shown: number, -- the player whose face is on it
}
export type Panel = {
	Gui: SurfaceGui,
	Def: any,
	Rows: { Row },
	Lines: { Line },
	List: ScrollingFrame,
	Empty: TextLabel,
	Pill: Frame,
	PillWords: TextLabel,
	OwnRank: TextLabel,
	OwnValue: TextLabel,
	Next: TextLabel,
	NextAt: number,
	Near: boolean,
}

-- A number as this board writes it, in the list and at the foot alike: cut to the board's own whole steps first, as
-- the server's are (Lib/BoardSums.mark: the list's numbers have been through it, a player's own at the foot has not),
-- then short, in four figures. Never rounded up
function BoardPanel.number(def: any, value: number): string
	local steps = value * def.Scale
	if steps < 1e15 then
		value = math.floor(steps + 1e-6) / def.Scale
	end
	if def.Money ~= 0 then
		return "$" .. (if value < 100 then Config.rate(value) else Kit.precise(value))
	end
	return if value < 1e6 then Config.wholeNumber(value) else Kit.precise(value)
end

function BoardPanel.canvas(): Vector2
	return Vector2.new(Boards.Panel.Width * PX, Boards.Panel.Height * PX)
end

local function fitted(label: TextLabel, most: number, least: number?)
	label.TextScaled = true
	Kit.new("UITextSizeConstraint", { MaxTextSize = most, MinTextSize = least or 12 }, label)
end

local function line(list: Instance, wide: number): Line
	local frame: Frame = Kit.new("Frame", {
		Name = "Row",
		Size = UDim2.fromOffset(wide, ROW),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Visible = false,
	}, list)
	Kit.corner(frame, 14)
	local fill = Kit.gradient(frame, ROW_B, ROW_A)
	local ring = Kit.stroke(frame, 4, Kit.White)
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Enabled = false
	local badge: Frame = Kit.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(54, 54),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, frame)
	Kit.corner(badge, 27)
	local badgeFill = Kit.gradient(badge, ROW_A, ROW_A)
	local rank = Kit.text({
		Name = "Rank",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(50, 42),
		TextSize = 40,
		ZIndex = 3,
	}, badge)
	fitted(rank, 40)
	local face: ImageLabel = Kit.new("ImageLabel", {
		Name = "Face",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 66, 0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = Color3.fromRGB(150, 222, 244),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, frame)
	Kit.corner(face, 28)
	local letter = Kit.text({
		Name = "Letter",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 66, 0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		TextSize = 34,
		ZIndex = 2,
	}, frame)
	local name = Kit.text({
		Name = "Name",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 128, 0.5, 0),
		Size = UDim2.fromOffset(wide - 128 - 144, 40),
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
	}, frame)
	fitted(name, 34, 18)
	local value = Kit.text({
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(130, 46),
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	}, frame)
	fitted(value, 42)
	return {
		Frame = frame,
		Fill = fill,
		Ring = ring,
		Badge = badge,
		BadgeFill = badgeFill,
		Rank = rank,
		Face = face,
		Letter = letter,
		Name = name,
		Value = value,
		Shown = 0,
	}
end

local function write(panel: Panel, l: Line, row: Row, place: number)
	l.Frame.Visible = true
	l.Frame.Position = UDim2.fromOffset(RIM, RIM + (place - 1) * STEP)
	local medal = MEDALS[row.Rank]
	if medal then
		l.Fill.Color = Shop.halves(medal[1], medal[2])
		l.BadgeFill.Color = ColorSequence.new(medal[3], medal[1])
	else
		local tone = if place % 2 == 0 then ROW_A else ROW_B
		l.Fill.Color = ColorSequence.new(tone)
		l.BadgeFill.Color = ColorSequence.new(Kit.Ink)
	end
	local me = Players.LocalPlayer
	l.Ring.Enabled = me ~= nil and row.Id == me.UserId
	l.Rank.Text = tostring(row.Rank)
	l.Name.Text = row.Name
	l.Value.Text = BoardPanel.number(panel.Def, row.Value)
	l.Value.TextColor3 = if panel.Def.Money ~= 0 and row.Rank ~= 1 then Kit.Cash else Kit.White
	if l.Shown ~= row.Id then
		l.Shown = row.Id
		l.Letter.Text = string.upper(string.match(row.Name, utf8.charpattern) or "?")
		l.Face.Image = if row.Id > 0 then `rbxthumb://type=AvatarHeadShot&id={row.Id}&w=150&h=150` else ""
		l.Face.BackgroundTransparency = 1
		l.Letter.BackgroundTransparency = 1
	end
end

-- The rows that show, written for where the list is scrolled to
local function fill(panel: Panel)
	local first = math.floor(math.max(panel.List.CanvasPosition.Y, 0) / STEP)
	for i, l in panel.Lines do
		-- (a line keeps every #Lines-th place, so a scroll by one row writes one row)
		local place = first + 1 + (i - 1 - first) % #panel.Lines
		local row = panel.Rows[place]
		if row then
			write(panel, l, row, place)
		else
			l.Frame.Visible = false
		end
	end
end

-- Whether the list may be scrolled: by someone near, and only when there is more than shows
local function scrolling(panel: Panel)
	local more = #panel.Rows > Config.Boards.Rows
	local on = panel.Near and more
	panel.List.ScrollingEnabled = on
	panel.List.Active = on
	panel.Gui.Active = on
	panel.List.ScrollBarThickness = if on then 8 else 0
	if not on then
		panel.List.CanvasPosition = Vector2.zero
	end
end

function BoardPanel.near(panel: Panel, near: boolean)
	if panel.Near ~= near then
		panel.Near = near
		scrolling(panel)
		fill(panel)
	end
end

-- Your own place and number
function BoardPanel.own(panel: Panel, value: number)
	local me = Players.LocalPlayer
	local rank: number? = nil
	for _, row in panel.Rows do
		if me and row.Id == me.UserId then
			rank = row.Rank
		end
	end
	panel.OwnRank.Text = if rank then "YOU  #" .. rank else "YOU"
	panel.OwnValue.Text = BoardPanel.number(panel.Def, value)
end

-- The list as the server sent it. nil: it has not yet
function BoardPanel.show(panel: Panel, board: { Global: boolean, Rows: { Row } }?, nextAt: number, own: number)
	panel.Rows = if board then board.Rows else {}
	panel.NextAt = nextAt
	local all = board ~= nil and board.Global
	panel.PillWords.Text = if all then "ALL PLAYERS" else "THIS SERVER"
	panel.Pill.BackgroundColor3 = if all then Color3.fromRGB(40, 170, 90) else Color3.fromRGB(24, 52, 92)
	panel.Empty.Visible = #panel.Rows == 0
	panel.Empty.Text = if board then "Nobody here yet.\nBe the first!" else "..."
	panel.List.CanvasSize = UDim2.fromOffset(0, math.max(#panel.Rows * STEP - (STEP - ROW), 0) + RIM * 2)
	scrolling(panel)
	fill(panel)
	BoardPanel.own(panel, own)
end

-- The words under your own line, once a second
function BoardPanel.tick(panel: Panel, now: number)
	local left = math.ceil(panel.NextAt - now)
	local text = if left > 0 then `new numbers in {left}s` else "new numbers on the way"
	if panel.Next.Text ~= text then
		panel.Next.Text = text
	end
end

-- The panel of one board, on its glass
function BoardPanel.make(def: any, glass: BasePart): Panel
	local size = BoardPanel.canvas()
	local me = Players.LocalPlayer
	local gui: SurfaceGui = Kit.new("SurfaceGui", {
		Name = "Board" .. def.Id,
		Adornee = glass,
		Face = Enum.NormalId.Back,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PX / Config.Boards.Scale,
		LightInfluence = 0,
		Brightness = 1.1,
		MaxDistance = FAR,
		ResetOnSpawn = false,
		Active = false,
		ClipsDescendants = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, me and me:WaitForChild("PlayerGui"))
	local face: Frame = Kit.new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
	}, gui)
	Kit.gradient(face, WATER, DEEP)
	-- bubbles in the glass
	for i, b in { { 0.1, 0.62, 60 }, { 0.82, 0.5, 92 }, { 0.5, 0.78, 46 }, { 0.2, 0.9, 110 }, { 0.9, 0.86, 54 } } do
		local bubble: Frame = Kit.new("Frame", {
			Name = "Bubble" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(b[1], b[2]),
			Size = UDim2.fromOffset(b[3], b[3]),
			BackgroundColor3 = Kit.Aqua,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
		}, face)
		Kit.corner(bubble, b[3] / 2)
	end

	-- the header
	local head: Frame = Kit.new("Frame", {
		Name = "Head",
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.new(1, -PAD * 2, 0, HEAD),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, face)
	Kit.corner(head, 18)
	Kit.gradient(head, Kit.White, Kit.White).Color = Shop.halves(def.Head, Kit.darker(def.Head, 0.12))
	Kit.stroke(head, 4, Kit.Ink).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local title = Kit.text({
		Name = "Title",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 66),
		Text = def.Title,
		TextSize = 62,
		ZIndex = 3,
	}, head, 5)
	fitted(title, 62)
	local counts = Kit.text({
		Name = "Line",
		Position = UDim2.fromOffset(16, 78),
		Size = UDim2.new(1, -16 - 180, 0, 34),
		Text = def.Line,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, head, 3)
	fitted(counts, 26)
	local pill: Frame = Kit.new("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 76),
		Size = UDim2.fromOffset(164, 38),
		BackgroundColor3 = Kit.Navy,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, head)
	Kit.corner(pill, 19)
	local pillWords = Kit.text({
		Name = "Words",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 0, 28),
		TextSize = 24,
		ZIndex = 4,
	}, pill, 2.5)
	fitted(pillWords, 24)

	-- the list
	local wide = size.X - PAD * 2
	local top = PAD + HEAD + 8
	local list: ScrollingFrame = Kit.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(PAD, top),
		Size = UDim2.fromOffset(wide, Config.Boards.Rows * STEP - (STEP - ROW) + RIM * 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarImageColor3 = Kit.Aqua,
		ScrollBarThickness = 0,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		ScrollingEnabled = false,
		Active = false,
		ZIndex = 2,
	}, face)
	local empty = Kit.text({
		Name = "Empty",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, top + 180),
		Size = UDim2.fromOffset(wide, 110),
		Text = "...",
		TextSize = 40,
		ZIndex = 3,
	}, face)
	local lines: { Line } = {}
	for i = 1, Config.Boards.Rows + 2 do
		lines[i] = line(list, wide - RIM * 2)
	end

	-- the foot
	local foot: Frame = Kit.new("Frame", {
		Name = "Foot",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, PAD, 1, -PAD),
		Size = UDim2.new(1, -PAD * 2, 0, FOOT),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, face)
	Kit.corner(foot, 18)
	Kit.gradient(foot, Shop.Body, Kit.Ink)
	Kit.stroke(foot, 4, Kit.Ink).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local ownRank = Kit.text({
		Name = "OwnRank",
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(0.5, -18, 0, 46),
		Text = "YOU",
		TextSize = 40,
		TextColor3 = Kit.Sun,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, foot)
	fitted(ownRank, 40)
	local ownValue = Kit.text({
		Name = "OwnValue",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 8),
		Size = UDim2.new(0.5, -18, 0, 46),
		TextSize = 42,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	}, foot)
	fitted(ownValue, 42)
	local nextWords = Kit.text({
		Name = "Next",
		Position = UDim2.fromOffset(18, 56),
		Size = UDim2.new(1, -36, 0, 28),
		TextSize = 24,
		TextColor3 = Color3.fromRGB(170, 220, 244),
		ZIndex = 3,
	}, foot, 2.5)

	local panel: Panel = {
		Gui = gui,
		Def = def,
		Rows = {},
		Lines = lines,
		List = list,
		Empty = empty,
		Pill = pill,
		PillWords = pillWords,
		OwnRank = ownRank,
		OwnValue = ownValue,
		Next = nextWords,
		NextAt = 0,
		Near = false,
	}
	list:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		fill(panel)
	end)
	BoardPanel.show(panel, nil, 0, 0)
	return panel
end

return BoardPanel
