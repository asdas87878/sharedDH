--!strict
-- What a hub leaderboard says (NULLROOM task l1; docs/design/leaderboards.md): a SurfaceGui on its glass. One dark face,
-- few colours, flat words with no outline but the title's: at the top its name (TOP small in brass between two lines,
-- the rest big under it, shaded in the board's own colour), who it lists (ALL PLAYERS or only THIS SERVER) and what it
-- counts, over a thin rule; then the list (place, face, name over user name, number over what it is; the first place
-- in gold, the next two edged in silver and bronze, your own edged in white); at the foot your own place and number, and
-- when the next numbers come.
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

local BoardPanel = {}

local PX = 40 -- pixels to a stud
local FAR = 320 -- studs past which nothing is written
local PAD = 16
local TOP = 156 -- where the list starts
local STEP = 68 -- from one row to the next
local ROW = 62 -- a row's height
local RIM = 3 -- room round the rows for their edges
local TITLE = Enum.Font.DenkOne -- the title's letters: tall and plain, as a ship's name plate
local BOLD, HEAVY = Enum.Font.BuilderSansBold, Enum.Font.BuilderSansExtraBold

-- the title's second word, its light top and its foot, by the icon the board carries; TOP and the lines by it in brass
local ACCENTS: { [string]: { Color3 } } = {
	Bubble = { Color3.fromRGB(206, 250, 246), Color3.fromRGB(58, 178, 196) },
	Book = { Color3.fromRGB(255, 226, 206), Color3.fromRGB(232, 116, 92) },
	Chest = { Color3.fromRGB(255, 240, 190), Color3.fromRGB(232, 164, 58) },
	Anchor = { Color3.fromRGB(226, 238, 248), Color3.fromRGB(112, 152, 190) },
}
local BRASS_L, BRASS = Color3.fromRGB(255, 232, 176), Color3.fromRGB(200, 152, 76)
local DROP = Color3.fromRGB(3, 8, 14)
local FILL, EDGE = Color3.fromRGB(19, 43, 58), Color3.fromRGB(34, 68, 84)
local CREAM, MUTED = Color3.fromRGB(242, 238, 224), Color3.fromRGB(138, 162, 176)
local SEA, GOLD = Color3.fromRGB(120, 218, 208), Color3.fromRGB(244, 198, 98)
-- the first three places: the row, its edge, and its place's number
local MEDALS = {
	{ Color3.fromRGB(70, 58, 32), Color3.fromRGB(178, 140, 66), GOLD },
	{ FILL, Color3.fromRGB(124, 142, 156), Color3.fromRGB(200, 212, 222) },
	{ FILL, Color3.fromRGB(140, 98, 66), Color3.fromRGB(214, 154, 110) },
}

type Row = { Id: number, Name: string, User: string, Value: number, Rank: number }
type Line = {
	Frame: Frame,
	Edge: UIStroke,
	Rank: TextLabel,
	Face: ImageLabel,
	Letter: TextLabel,
	Name: TextLabel,
	User: TextLabel,
	Value: TextLabel,
	Unit: TextLabel,
	Shown: number, -- the player whose face is on it
}
export type Panel = {
	Gui: SurfaceGui,
	Def: any,
	Rows: { Row },
	Lines: { Line },
	List: ScrollingFrame,
	Empty: TextLabel,
	Who: TextLabel,
	Own: TextLabel,
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

-- Plain words, as big as their box holds up to `most`
local function words(props: { [string]: any }, parent: Instance, most: number, least: number?): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or BOLD
	props.TextColor3 = props.TextColor3 or CREAM
	props.Text = props.Text or ""
	props.TextScaled = true
	local label: TextLabel = Kit.new("TextLabel", props, parent)
	Kit.new("UITextSizeConstraint", { MaxTextSize = most, MinTextSize = least or 12 }, label)
	return label
end

local function line(list: Instance, wide: number, unit: string): Line
	local frame: Frame = Kit.new("Frame", {
		Name = "Row",
		Size = UDim2.fromOffset(wide, ROW),
		BackgroundColor3 = FILL,
		BorderSizePixel = 0,
		Visible = false,
	}, list)
	Kit.corner(frame, 6)
	local edge = Kit.stroke(frame, 2, EDGE)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local rank = words({
		Name = "Rank",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(42, 36),
		Font = HEAVY,
	}, frame, 30)
	local letter = words({
		Name = "Letter",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 50, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		TextColor3 = MUTED,
		ZIndex = 2,
	}, frame, 30)
	local face: ImageLabel = Kit.new("ImageLabel", {
		Name = "Face",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 50, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, frame)
	Kit.corner(face, 6)
	local right = 128 -- what is kept for the number
	local name = words({
		Name = "Name",
		Position = UDim2.fromOffset(106, 5),
		Size = UDim2.fromOffset(wide - 106 - right - 8, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, frame, 28, 18)
	local user = words({
		Name = "User",
		Position = UDim2.fromOffset(106, 38),
		Size = UDim2.fromOffset(wide - 106 - right - 8, 18),
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, frame, 17, 14)
	local value = words({
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 3),
		Size = UDim2.fromOffset(right - 12, 38),
		Font = HEAVY,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, frame, 34)
	local what = words({
		Name = "Unit",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 39),
		Size = UDim2.fromOffset(right - 12, 17),
		Text = unit,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, frame, 16)
	return {
		Frame = frame,
		Edge = edge,
		Rank = rank,
		Face = face,
		Letter = letter,
		Name = name,
		User = user,
		Value = value,
		Unit = what,
		Shown = 0,
	}
end

local function write(panel: Panel, l: Line, row: Row, place: number)
	l.Frame.Visible = true
	l.Frame.Position = UDim2.fromOffset(RIM, RIM + (place - 1) * STEP)
	local medal = MEDALS[row.Rank]
	local me = Players.LocalPlayer
	local mine = me ~= nil and row.Id == me.UserId
	l.Frame.BackgroundColor3 = if medal then medal[1] else FILL
	l.Edge.Color = if mine then CREAM elseif medal then medal[2] else EDGE
	l.Rank.TextColor3 = if medal then medal[3] else MUTED
	l.Value.TextColor3 = if row.Rank == 1 then GOLD else SEA
	l.Rank.Text = tostring(row.Rank)
	l.Name.Text = row.Name
	l.User.Text = if row.User ~= "" then "@" .. row.User else ""
	l.Value.Text = BoardPanel.number(panel.Def, row.Value)
	if l.Shown ~= row.Id then
		l.Shown = row.Id
		l.Letter.Text = string.upper(string.match(row.Name, utf8.charpattern) or "?")
		l.Face.Image = if row.Id > 0 then `rbxthumb://type=AvatarHeadShot&id={row.Id}&w=150&h=150` else ""
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
	panel.List.ScrollBarThickness = if on then 6 else 0
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
	local number = BoardPanel.number(panel.Def, value)
	panel.Own.Text = if rank then `YOU  #{rank}   {number}` else `YOU   {number}`
end

-- The list as the server sent it. nil: it has not yet
function BoardPanel.show(panel: Panel, board: { Global: boolean, Rows: { Row } }?, nextAt: number, own: number)
	panel.Rows = if board then board.Rows else {}
	panel.NextAt = nextAt
	panel.Who.Text = if board ~= nil and board.Global then "ALL PLAYERS" else "THIS SERVER"
	panel.Empty.Visible = #panel.Rows == 0
	panel.Empty.Text = if board then "Nobody here yet" else "..."
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
		BackgroundColor3 = Boards.Glass,
		BorderSizePixel = 0,
	}, gui)
	local wide = size.X - PAD * 2
	-- one line of words across the middle
	local function across(name: string, y: number, high: number, most: number, props: { [string]: any }): TextLabel
		props.Name = name
		props.Position = UDim2.fromOffset(PAD, y)
		props.Size = UDim2.fromOffset(wide, high)
		return words(props, face, most)
	end
	local function rule(y: number)
		Kit.new("Frame", {
			Name = "Rule",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.fromOffset(wide - RIM * 2, 2),
			BackgroundColor3 = Color3.fromRGB(128, 104, 62),
			BorderSizePixel = 0,
		}, face)
	end

	-- the title: its first word small in brass between two lines, the rest big under it in the board's own colour
	local first, rest = string.match(def.Title, "^(%S+)%s+(.+)$")
	local small: string, big: string = first or "", rest or def.Title
	local accent = ACCENTS[def.Emblem] or ACCENTS.Anchor
	local function lettering(
		name: string,
		text: string,
		y: number,
		high: number,
		most: number,
		top: Color3,
		foot: Color3
	)
		local deep = math.max(2, math.floor(most / 18))
		local under = across(name .. "Drop", y + deep, high, most, { Text = text, Font = TITLE, TextColor3 = DROP })
		Kit.stroke(under, 3, DROP)
		local over = across(name, y, high, most, {
			Text = text,
			Font = TITLE,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 2,
		})
		Kit.stroke(over, 2, DROP)
		Kit.gradient(over, top, foot)
	end
	lettering("Small", small, 2, 46, 43, BRASS_L, BRASS)
	lettering("Title", big, 39, 76, 74, accent[1], accent[2])
	for _, side in { -1, 1 } do
		if small ~= "" then
			local line: Frame = Kit.new("Frame", {
				Name = "Line" .. side,
				AnchorPoint = Vector2.new(if side < 0 then 1 else 0, 0.5),
				Position = UDim2.new(0.5, side * 62, 0, 25),
				Size = UDim2.fromOffset(120, 3),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
			}, face)
			-- (brass by the word, gone at its outer end)
			Kit.new("UIGradient", {
				Color = ColorSequence.new(BRASS),
				Transparency = NumberSequence.new(if side < 0 then 1 else 0, if side < 0 then 0 else 1),
			}, line)
			Kit.new("Frame", {
				Name = "Stud" .. side,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, side * 62, 0, 25),
				Size = UDim2.fromOffset(11, 11),
				Rotation = 45,
				BackgroundColor3 = BRASS,
				BorderSizePixel = 0,
			}, face)
		end
	end
	-- who it lists and what it counts, on one line
	local under: Frame = Kit.new("Frame", {
		Name = "Under",
		Position = UDim2.fromOffset(PAD, 113),
		Size = UDim2.fromOffset(wide, 26),
		BackgroundTransparency = 1,
	}, face)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, under)
	local function said(name: string, order: number, text: string, color: Color3): TextLabel
		return Kit.new("TextLabel", {
			Name = name,
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			BackgroundTransparency = 1,
			Font = BOLD,
			TextSize = 22,
			TextColor3 = color,
			Text = text,
		}, under)
	end
	local who = said("Who", 1, "", GOLD)
	said("Dot", 2, "•", MUTED)
	said("What", 3, def.Line, SEA)
	rule(146)

	local list: ScrollingFrame = Kit.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(PAD, TOP),
		Size = UDim2.fromOffset(wide, Config.Boards.Rows * STEP - (STEP - ROW) + RIM * 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarImageColor3 = SEA,
		ScrollBarThickness = 0,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		ScrollingEnabled = false,
		Active = false,
	}, face)
	local empty = across("Empty", TOP + 180, 60, 34, { TextColor3 = MUTED })
	local lines: { Line } = {}
	for i = 1, Config.Boards.Rows + 2 do
		lines[i] = line(list, wide - RIM * 2, def.Unit)
	end

	local foot = TOP + Config.Boards.Rows * STEP + 12
	rule(foot)
	local own = across("Own", foot + 22, 42, 36, { Font = HEAVY, TextColor3 = GOLD })
	local nextWords = across("Next", foot + 72, 26, 22, { TextColor3 = MUTED })

	local panel: Panel = {
		Gui = gui,
		Def = def,
		Rows = {},
		Lines = lines,
		List = list,
		Empty = empty,
		Who = who,
		Own = own,
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
