--!strict
-- The hub's leaderboards as tables of plain parts (NULLROOM task l1, Hugo 2026-11-25; docs/design/leaderboards.md): the
-- frame, sunken brass (Hugo's pick of three), and the flat sign that hangs at each board's head. Sums only:
-- BoardController builds them on each player's own machine, tools/boards/picture draws them. Nothing here is uploaded
-- and nothing is in the place.
--   A board's own space: its foot on the floor in the middle, X to the right of someone reading it, Y up, Z towards
--   them. PANEL, the dark glass with the list on it, is 11.2 by 21.2 studs.
--   A piece: Shape (Block, Cylinder; a cylinder runs along its own X), Size, At, Color, Glow (neon), Light (a lamp: how
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
Boards.Sign = { Y = 26.4, Z = 0.95, Width = 4.7 } -- the sign's middle and how wide it is
Boards.Solid = { Width = 13.6, Height = 29, Depth = 2.2 } -- the unseen block players bump into
Boards.Bed = { Depth = 7, Height = 0.8, Over = 7.2 } -- the bed all boards of the row stand on; Over past the last middles
Boards.Glass = Color3.fromRGB(10, 21, 33)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Old copper, worn brass, and what the signs are drawn in
local COPPER, COPPER_D = rgb(48, 104, 106), rgb(32, 74, 82)
local BRASS, BRASS_D = rgb(200, 160, 88), rgb(148, 114, 60)
local NIGHT, CREAM, SEA = rgb(18, 40, 56), rgb(236, 230, 210), rgb(132, 208, 208)
local LAMP = rgb(255, 218, 150)
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

local HEAD = 29.9 -- the head beam's underside

local function frame(pen: Pen)
	local p = Boards.Panel
	local top = p.Bottom + p.Height
	-- the glass, in a thin brass edge
	box(pen, 0, p.Bottom + p.Height / 2, -0.1, p.Width + 0.5, p.Height + 0.5, 0.8, BRASS)
	for _, side in { -1, 1 } do
		local x = side * 6.45
		box(pen, x, HEAD / 2, -0.2, 1.4, HEAD, 1.6, COPPER)
		box(pen, x, 1.5, -0.1, 1.5, 1.8, 2.2, COPPER_D)
		box(pen, x, 2.6, -0.1, 1.48, 0.4, 2.0, BRASS)
		-- a slim lamp let into the pillar
		box(pen, x, 22.2, 0.6, 0.66, 2.7, 0.2, BRASS_D)
		local lamp = box(pen, x, 22.2, 0.72, 0.34, 2.3, 0.2, LAMP)
		lamp.Glow = true
		lamp.Light = 12
	end
	-- the foot, the board behind the sign, and the head beam
	box(pen, 0, 1.7, -0.1, 11.5, 1.7, 1.5, COPPER_D)
	box(pen, 0, (top + 0.25 + HEAD) / 2, -0.35, 11.5, HEAD - top - 0.25, 0.9, COPPER_D)
	box(pen, 0, HEAD + 0.2, 0, 14.2, 0.4, 2.5, BRASS)
	box(pen, 0, HEAD + 0.9, 0, 13.8, 1.0, 2.2, COPPER)
end

----------------------------------------------------------------------------------------------------------------------
-- The signs: a brass-edged roundel on two straps, and one plain shape on it in two or three flat colours

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

-- Oxygen: one bubble, and two small ones going up
signs.Bubble = function(pen: Pen)
	disc(pen, -0.25, -0.3, 0, 2.5, 0.16, SEA)
	disc(pen, -0.25, -0.3, 0.05, 1.95, 0.16, NIGHT)
	disc(pen, -0.7, 0.1, 0.1, 0.5, 0.16, CREAM)
	disc(pen, 1.1, 0.95, 0, 0.9, 0.16, SEA)
	disc(pen, 1.1, 0.95, 0.05, 0.5, 0.16, NIGHT)
end

-- Collectors: the Index open, a fish on each page
signs.Book = function(pen: Pen)
	box(pen, 0, 0, 0, 3.3, 2.3, 0.16, BRASS)
	for _, side in { -1, 1 } do
		box(pen, side * 0.77, 0.04, 0.05, 1.44, 2.04, 0.16, CREAM)
		fish({ List = pen.List, Base = pen.Base * CFrame.new(0, 0, 0.1) }, side * 0.77 + 0.06, 0.04, 1.25, NIGHT, CREAM)
	end
end

-- Earners: a shut chest, seen from the front
signs.Chest = function(pen: Pen)
	box(pen, 0, 0.65, 0, 3.0, 0.95, 0.16, BRASS)
	box(pen, 0, -0.55, 0, 3.0, 1.25, 0.16, BRASS)
	for _, x in { -0.95, 0.95 } do
		box(pen, x, 0.65, 0.05, 0.35, 0.95, 0.16, CREAM)
		box(pen, x, -0.55, 0.05, 0.35, 1.25, 0.16, CREAM)
	end
	box(pen, 0, 0.02, 0.1, 0.7, 0.8, 0.16, CREAM)
	box(pen, 0, -0.05, 0.15, 0.2, 0.36, 0.16, NIGHT)
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
	for _, side in { -1, 1 } do
		box(pen, side * 1.3, (s.Y + HEAD) / 2, s.Z - 0.1, 0.28, HEAD - s.Y, 0.16, BRASS)
	end
	disc(pen, 0, s.Y, s.Z, s.Width, 0.4, BRASS)
	disc(pen, 0, s.Y, s.Z + 0.05, s.Width - 0.5, 0.4, NIGHT)
	draw({ List = pen.List, Base = CFrame.new(0, s.Y, s.Z + 0.28) })
end

----------------------------------------------------------------------------------------------------------------------

-- One board: its frame and its sign
function Boards.board(emblem: string): { Piece }
	local pen: Pen = { List = {}, Base = CFrame.identity }
	frame(pen)
	sign(pen, emblem)
	return pen.List
end

-- The bed a row stands on, from the row's own middle. `span`: from the first board's middle to the last one's
function Boards.bed(span: number): { Piece }
	local pen: Pen = { List = {}, Base = CFrame.identity }
	local b = Boards.Bed
	local long = span + b.Over * 2 - b.Depth
	box(pen, 0, b.Height / 2, 0, long, b.Height, b.Depth, STONE)
	box(pen, 0, b.Height * 0.3, 0, long, b.Height * 0.6, b.Depth + 0.5, STONE_D)
	for _, side in { -1, 1 } do
		post(pen, side * long / 2, b.Height / 2, 0, b.Depth, b.Height, STONE)
		post(pen, side * long / 2, b.Height * 0.3, 0, b.Depth + 0.5, b.Height * 0.6, STONE_D)
	end
	return pen.List
end

-- The middle of each board's foot, from the row's: the first one on the reader's left
function Boards.places(count: number, pitch: number, turn: number): { CFrame }
	local out: { CFrame } = {}
	for i = 1, count do
		out[i] = CFrame.new((i - (count + 1) / 2) * pitch, 0, 0) * CFrame.Angles(0, math.rad(turn), 0)
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
