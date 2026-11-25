--!strict
-- The hub's leaderboards as tables of plain parts (NULLROOM task l1, Hugo 2026-11-25; docs/design/leaderboards.md): the
-- frame, sunken brass (Hugo's pick of three) with its pipes, valves and lamps, and the flat icon on the slim bar at each
-- board's head. Sums only: BoardController builds them on each player's own machine, tools/boards/picture draws them. Nothing here is uploaded
-- and nothing is in the place.
--   One straight wall (Hugo, 2026-11-25: "straight and continuous with each other without seeing any edges in between"):
--   the boards have no sides of their own. `frame` draws what runs through all of them (the foot bar, the head bar, the
--   back) and one post at each end and between two boards; `board` only what is inside one: the glass's edge, the foot's
--   portholes and valve, the icon.
--   A board's own space: its foot on the floor in the middle, X to the right of someone reading it, Y up, Z towards
--   them; the row's the same, from the middle of the row. PANEL, the dark glass with the list on it, is 11.2 by 21.2 studs.
--   A piece: Shape (Block, Ball, Cylinder; a cylinder runs along its own X), Size, At, Color, Glow (neon), Light (a lamp: how
--   far it reaches, studs). Nothing moves.
local Boards = {}

export type Piece = {
	Shape: string,
	Size: Vector3,
	At: CFrame,
	Color: Color3,
	Glow: boolean?,
	Light: number?,
}

Boards.Panel = { Width = 11.2, Height = 21.2, Bottom = 2.8, Front = 0.35 } -- the glass: studs; its face in Z
Boards.Sign = { Y = 25.5, Z = 1.2, Scale = 0.85 } -- the icon's middle, on the front of the bar, and every size in it times this
Boards.Solid = { Width = 14.3, Height = 25.6, Depth = 3 } -- the unseen block players bump into
Boards.Bed = { Depth = 7, Height = 0.8, Over = 8.4 } -- the kerb all boards of the row stand on; Over past the last middles
Boards.Post = 1.4 -- how wide a post is when the boards stand as close as they can (Boards.pitch)
Boards.Glass = Color3.fromRGB(10, 21, 33)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Old copper, worn brass, and what the signs are drawn in
local COPPER, COPPER_D = rgb(48, 104, 106), rgb(32, 74, 82)
local BRASS, BRASS_D = rgb(200, 160, 88), rgb(148, 114, 60)
local NIGHT, CREAM = rgb(18, 40, 56), rgb(236, 230, 210)
local SEA, SEA_D = rgb(140, 214, 220), rgb(34, 128, 148)
local LAMP, PORT = rgb(255, 218, 150), rgb(120, 220, 224) -- what glows: the lamps, the portholes
local RUST, WOOD = rgb(176, 72, 58), rgb(140, 92, 56) -- the valves and the Index's cover; the chest
local STONE, STONE_D = rgb(158, 164, 172), rgb(124, 130, 142)

-- One board being drawn: pieces go into its list, each placed against `base`
type Pen = { List: { Piece }, Base: CFrame }

local function add(pen: Pen, shape: string, size: Vector3, at: CFrame, color: Color3): Piece
	local piece: Piece = { Shape = shape, Size = size, At = pen.Base * at, Color = color }
	table.insert(pen.List, piece)
	return piece
end

local function box(pen: Pen, x: number, y: number, z: number, w: number, h: number, d: number, color: Color3): Piece
	return add(pen, "Block", Vector3.new(w, h, d), CFrame.new(x, y, z), color)
end

-- A disc facing the reader
local function disc(pen: Pen, x: number, y: number, z: number, d: number, thick: number, color: Color3): Piece
	return add(
		pen,
		"Cylinder",
		Vector3.new(thick, d, d),
		CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(-90), 0),
		color
	)
end

local function ball(pen: Pen, x: number, y: number, z: number, d: number, color: Color3): Piece
	return add(pen, "Ball", Vector3.new(d, d, d), CFrame.new(x, y, z), color)
end

-- A round upright
local function post(pen: Pen, x: number, y: number, z: number, d: number, h: number, color: Color3): Piece
	return add(pen, "Cylinder", Vector3.new(h, d, d), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)), color)
end

-- A space inside a pen's, turned in the plane of the sign
local function within(pen: Pen, x: number, y: number, turn: number): Pen
	return { List = pen.List, Base = pen.Base * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.rad(turn)) }
end

----------------------------------------------------------------------------------------------------------------------
-- The frame

local PIPE = 0.85 -- how far forward a pillar's pipe stands

-- A valve's wheel, facing the reader
local function valve(pen: Pen, x: number, y: number, z: number, d: number)
	local rim = d * 0.15
	local r = (d - rim) / 2
	disc(pen, x, y, z - 0.25, d * 0.34, 0.6, BRASS_D)
	for i = 0, 7 do
		local at = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(i * 45)) * CFrame.new(r, 0, 0)
		add(pen, "Block", Vector3.new(rim, r * 0.9, 0.28), at, RUST)
	end
	for i = 0, 1 do
		local at = CFrame.new(x, y, z - 0.03) * CFrame.Angles(0, 0, math.rad(45 + i * 90))
		add(pen, "Block", Vector3.new(d - rim, rim * 0.9, 0.2), at, RUST)
	end
	disc(pen, x, y, z + 0.05, d * 0.26, 0.4, BRASS)
end

-- A pressure gauge
local function gauge(pen: Pen, x: number, y: number, z: number, d: number)
	disc(pen, x, y, z, d, 0.5, BRASS)
	disc(pen, x, y, z + 0.1, d * 0.74, 0.5, CREAM)
	local at = CFrame.new(x, y, z + 0.36) * CFrame.Angles(0, 0, math.rad(40)) * CFrame.new(d * 0.12, 0, 0)
	add(pen, "Block", Vector3.new(d * 0.42, 0.12, 0.08), at, RUST)
end

-- A ship's lamp: a lit dome on a brass plate, two bars across it
local function lamp(pen: Pen, x: number, y: number)
	box(pen, x, y, 0.65, 1.3, 2.6, 0.3, BRASS_D)
	local dome = box(pen, x, y, 0.85, 0.8, 1.9, 0.5, LAMP)
	dome.Glow = true
	dome.Light = 12
	for _, up in { -0.45, 0.45 } do
		box(pen, x, y + up, 0.9, 1.1, 0.22, 0.6, BRASS)
	end
end

local EDGE = 0.25 -- the glass's brass edge, on every side
local TUCK = 0.1 -- how far that edge goes in behind a post

-- The least there can be from one board's middle to the next one's: the two brass edges tucked in behind one post
function Boards.least(): number
	return Boards.Panel.Width + EDGE * 2 - TUCK * 2 + Boards.Post
end

-- How far apart the boards stand: what is asked for, never less than `least`
function Boards.pitch(asked: number): number
	return math.max(asked, Boards.least())
end

-- What one board has to itself: the glass in a thin brass edge, and in the foot a valve between two lit portholes
local function bay(pen: Pen)
	local p = Boards.Panel
	box(pen, 0, p.Bottom + p.Height / 2, -0.1, p.Width + EDGE * 2, p.Height + EDGE * 2, 0.8, BRASS)
	for _, x in { -3.4, 3.4 } do
		disc(pen, x, 1.7, 0.7, 1.4, 0.3, BRASS)
		local pane = disc(pen, x, 1.7, 0.8, 0.96, 0.3, PORT)
		pane.Glow = true
	end
	valve(pen, 0, 1.7, 1.2, 1.5)
end

-- A post, as wide as the boards leave room for: a pipe up its front to a lamp, in collars and bolted straps
local function upright(pen: Pen, x: number, wide: number, top: number)
	box(pen, x, top / 2, -0.2, wide, top, 1.6, COPPER)
	lamp(pen, x, 21.6)
	post(pen, x, 11.4, PIPE, 0.5, 17.4, BRASS_D)
	for _, y in { 3.1, 20.0 } do
		post(pen, x, y, PIPE, 0.8, 0.6, BRASS)
	end
	for _, y in { 8.28, 15.08 } do -- (between two rows of the list, as the valve is: seen from aside they hide no number)
		box(pen, x, y, 0.05, wide + 0.1, 0.6, 2.2, BRASS)
		for _, out in { -0.5, 0.5 } do
			ball(pen, x + out, y, 1.12, 0.32, CREAM)
		end
	end
end

-- What runs through a whole row, in the row's own space: `count` boards, `asked` from one's middle to the next one's
function Boards.frame(count: number, asked: number): { Piece }
	local pen: Pen = { List = {}, Base = CFrame.identity }
	local p = Boards.Panel
	local top = p.Bottom + p.Height + EDGE
	local pitch = Boards.pitch(asked)
	local wide = pitch - (p.Width + EDGE * 2 - TUCK * 2)
	local long = count * pitch + wide -- from the outside of one end post to the other's
	-- one post at each end, and one where two boards meet: the gauge is of the board on its right, the valve of the one
	-- on its left
	for i = 0, count do
		local x = (i - count / 2) * pitch
		upright(pen, x, wide, top)
		if i < count then
			gauge(pen, x, 5.9, 1.15, 1.55)
		end
		if i > 0 then
			valve(pen, x, 11.68, 1.15, 1.4)
		end
	end
	-- behind it all, so there is never daylight beside a post
	box(pen, 0, top / 2 + 0.2, -0.65, long - 0.4, top - 0.6, 0.5, COPPER_D)
	-- one bar at the foot and one at the head, each with its brass edge, in front of the posts from end to end; and one
	-- row of small lamps on the upper one, evenly along it
	box(pen, 0, 1.6, -0.1, long + 0.2, 1.9, 1.5, COPPER_D)
	box(pen, 0, p.Bottom - EDGE / 2, -0.1, long + 0.4, EDGE, 2.0, BRASS)
	box(pen, 0, top + 0.65, -0.1, long + 0.2, 1.3, 1.8, COPPER)
	box(pen, 0, top + 1.45, -0.1, long + 0.4, 0.3, 2.2, BRASS)
	for i = 1, count do
		local x = (i - (count + 1) / 2) * pitch
		local gap = 1.5 * pitch / Boards.least()
		for _, side in { -1, 1 } do
			for k = 0, 2 do
				local bulb = ball(pen, x + side * (pitch / 2 - gap * (k + 0.5)), top + 0.65, 0.85, 0.55, LAMP)
				bulb.Glow = true
			end
		end
	end
	return pen.List
end

----------------------------------------------------------------------------------------------------------------------
-- The icons: one plain flat shape each, in two or three colours, with nothing round it

-- A fish cut out of one colour, its nose to the right, `long` studs from nose to tail, with an eye
local function fish(pen: Pen, x: number, y: number, long: number, color: Color3, eye: Color3)
	local function diamond(at: number, size: number)
		local turn = CFrame.Angles(0, 0, math.rad(45))
		add(pen, "Block", Vector3.new(size, size, 0.16), CFrame.new(x + at, y, 0) * turn, color)
	end
	disc(pen, x + long * 0.08, y, 0, long * 0.5, 0.16, color)
	diamond(long * 0.22, long * 0.36)
	diamond(-long * 0.1, long * 0.3)
	box(pen, x - long * 0.34, y, 0, long * 0.16, long * 0.4, 0.16, color)
	disc(pen, x + long * 0.22, y + long * 0.07, 0.04, long * 0.11, 0.16, eye)
end

local signs: { [string]: (pen: Pen) -> () } = {}

-- Oxygen: one bubble, and a small one going up
signs.Bubble = function(pen: Pen)
	disc(pen, -0.25, -0.15, 0, 2.3, 0.3, SEA_D)
	disc(pen, -0.25, -0.15, 0.05, 1.96, 0.3, SEA)
	disc(pen, -0.68, 0.3, 0.1, 0.56, 0.3, CREAM)
	disc(pen, 1.15, 0.85, 0, 0.95, 0.3, SEA_D)
	disc(pen, 1.15, 0.85, 0.05, 0.68, 0.3, SEA)
end

-- Collectors: the Index open, a fish on each page
signs.Book = function(pen: Pen)
	box(pen, 0, -0.04, 0, 3.2, 2.2, 0.3, RUST)
	for _, side in { -1, 1 } do
		box(pen, side * 0.74, 0.08, 0.07, 1.4, 2.06, 0.3, CREAM)
		fish({ List = pen.List, Base = pen.Base * CFrame.new(0, 0, 0.16) }, side * 0.74 + 0.06, 0.08, 1.2, NIGHT, CREAM)
	end
end

-- Earners: a shut chest, seen from the front
signs.Chest = function(pen: Pen)
	box(pen, 0, 0.62, 0, 3.0, 0.95, 0.3, WOOD)
	box(pen, 0, -0.5, 0, 3.0, 1.15, 0.3, WOOD)
	box(pen, 0, 0.1, 0.03, 3.1, 0.22, 0.3, NIGHT)
	for _, x in { -1.1, 1.1 } do
		box(pen, x, 0.06, 0.07, 0.4, 2.14, 0.3, BRASS)
	end
	box(pen, 0, 0, 0.12, 0.72, 0.8, 0.3, BRASS)
	box(pen, 0, -0.06, 0.16, 0.2, 0.36, 0.3, NIGHT)
end

-- Deepest: an anchor
signs.Anchor = function(pen: Pen)
	box(pen, 0, 0, 0, 0.45, 2.3, 0.16, CREAM)
	box(pen, 0, 0.6, 0, 1.5, 0.36, 0.16, CREAM)
	disc(pen, 0, 1.2, 0.02, 0.85, 0.16, CREAM)
	disc(pen, 0, 1.2, 0.07, 0.4, 0.16, NIGHT)
	for _, side in { -1, 1 } do
		local arm = within(pen, side * 0.6, -0.95, side * 35)
		box(arm, 0, 0, 0, 1.5, 0.42, 0.16, CREAM)
	end
end

local function sign(pen: Pen, emblem: string)
	local draw = signs[emblem]
	if not draw then
		return
	end
	local s = Boards.Sign
	local from = #pen.List
	draw({ List = pen.List, Base = CFrame.identity })
	for i = from + 1, #pen.List do
		local piece = pen.List[i]
		piece.Size = Vector3.new(piece.Size.X * s.Scale, piece.Size.Y * s.Scale, piece.Size.Z * s.Scale)
		piece.At = CFrame.new(0, s.Y, s.Z) * (piece.At.Rotation + piece.At.Position * s.Scale)
	end
end

----------------------------------------------------------------------------------------------------------------------

-- One board, without what it shares with the rest of the row (Boards.frame)
function Boards.board(emblem: string): { Piece }
	local pen: Pen = { List = {}, Base = CFrame.identity }
	bay(pen)
	sign(pen, emblem)
	return pen.List
end

-- The kerb a row stands on, from the row's own middle. (The round ends are a hair lower than the straight part, which
-- has studs on its top: two tops in one plane flicker, and from afar so do two closer than this.)
function Boards.bed(count: number, asked: number): { Piece }
	local pen: Pen = { List = {}, Base = CFrame.identity }
	local b = Boards.Bed
	local long = (count - 1) * Boards.pitch(asked) + b.Over * 2 - b.Depth
	box(pen, 0, b.Height / 2, 0, long, b.Height, b.Depth, STONE)
	box(pen, 0, b.Height * 0.3, 0, long, b.Height * 0.6, b.Depth + 0.5, STONE_D)
	for _, side in { -1, 1 } do
		post(pen, side * long / 2, b.Height / 2 - 0.05, 0, b.Depth, b.Height, STONE)
		post(pen, side * long / 2, b.Height * 0.3 - 0.05, 0, b.Depth + 0.5, b.Height * 0.6, STONE_D)
	end
	return pen.List
end

-- The middle of each board's foot, from the row's: the first one on the reader's left, all in one line and one plane
function Boards.places(count: number, asked: number): { CFrame }
	local out: { CFrame } = {}
	for i = 1, count do
		out[i] = CFrame.new((i - (count + 1) / 2) * Boards.pitch(asked), 0, 0)
	end
	return out
end

-- The row's own space in the world, from the hub's floor (Dock.HubFloor): x from its middle line, z in from its edge
-- at the sea (the +Z one), facing in degrees (0: the sea)
function Boards.row(floor: CFrame, size: Vector3, x: number, z: number, face: number): CFrame
	local at = floor.Position + Vector3.new(x, size.Y / 2, size.Z / 2 - z)
	return CFrame.new(at) * CFrame.Angles(0, math.rad(face), 0)
end

return Boards
