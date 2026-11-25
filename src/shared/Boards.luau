--!strict
-- The hub's leaderboards as tables of plain parts (NULLROOM task l1, Hugo 2026-11-25; docs/design/leaderboards.md): three
-- frames to choose from (Config.Boards.Style) and an emblem for each board. Sums only: BoardController builds them on
-- each player's own machine, tools/boards/picture draws them. Nothing here is uploaded and nothing is in the place.
--   A board's own space: its foot on the floor in the middle, X to the right of someone reading it, Y up, Z towards
--   them. One size for every style: PANEL, the dark glass with the list on it, is 11.2 by 21.2 studs.
--   A piece: Shape (Block, Ball, Cylinder; a cylinder runs along its own X), Size, At, Color, Glow (neon), Clear
--   (transparency), Light (a lamp: how far it reaches, studs), Move ("Emblem": bobs and turns with the emblem;
--   "Bubble": rises and comes round again; nothing: stands).
local Boards = {}

export type Piece = {
	Shape: string,
	Size: Vector3,
	At: CFrame,
	Color: Color3,
	Glow: boolean?,
	Clear: number?,
	Light: number?,
	Move: string?,
}

Boards.Panel = { Width = 11.2, Height = 21.2, Bottom = 2.8, Front = 0.35 } -- the glass: studs; its face in Z
Boards.Emblem = { Y = 29.4 } -- the emblem's middle, over the foot
Boards.Solid = { Width = 13.6, Height = 25.5, Depth = 2.2 } -- the unseen block players bump into
Boards.Bed = { Depth = 7, Height = 0.8, Over = 7.2 } -- the bed all boards of the row stand on; Over past the last middles
Boards.Names = { "Driftwood and rope", "Coral reef and shell", "Sunken brass" }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- The hub kit's own colours (tools/map/hub_kit.py) and what the frames add to them
local WOOD, WOOD_D, WOOD_L = rgb(172, 132, 76), rgb(136, 100, 58), rgb(206, 168, 112)
local ROPE, ROPE_D = rgb(240, 220, 160), rgb(212, 184, 120)
local GOLD, GOLD_L, GOLD_D = rgb(250, 200, 60), rgb(253, 226, 124), rgb(206, 150, 40)
local BRASS, BRASS_D = rgb(232, 184, 74), rgb(176, 130, 48)
local VERDI, VERDI_D, VERDI_L = rgb(62, 150, 138), rgb(40, 106, 104), rgb(110, 196, 176)
local IRON, DARK = rgb(72, 76, 92), rgb(40, 44, 60)
local SAND, SAND_D = rgb(236, 222, 172), rgb(214, 194, 140)
local STONE, STONE_D = rgb(190, 194, 200), rgb(150, 152, 166)
local WHITE, CREAM, PEARL = rgb(250, 248, 240), rgb(250, 244, 226), rgb(246, 236, 244)
local KELP, KELP_D = rgb(84, 168, 92), rgb(52, 116, 74)
local RED, ORANGE, YELLOW = rgb(235, 80, 80), rgb(255, 150, 80), rgb(250, 190, 70)
local TANK = rgb(255, 176, 30)
local BLUE_D, TEAL = rgb(48, 112, 196), rgb(70, 190, 190)
local PINK, PINK_L, CORAL, PURPLE, PURPLE_D =
	rgb(244, 120, 150), rgb(255, 176, 190), rgb(255, 118, 104), rgb(170, 110, 240), rgb(124, 78, 190)
local SEA, SEA_L = rgb(90, 224, 250), rgb(190, 246, 255)
local LAMP = rgb(255, 226, 140)
local GLASS = rgb(16, 40, 66)

-- One board being drawn: pieces go into its list, each placed against `base`
type Pen = { List: { Piece }, Base: CFrame, Move: string? }

local function add(pen: Pen, shape: string, size: Vector3, at: CFrame, color: Color3): Piece
	local piece: Piece = { Shape = shape, Size = size, At = pen.Base * at, Color = color, Move = pen.Move }
	table.insert(pen.List, piece)
	return piece
end

local function box(pen: Pen, x: number, y: number, z: number, w: number, h: number, d: number, color: Color3): Piece
	return add(pen, "Block", Vector3.new(w, h, d), CFrame.new(x, y, z), color)
end

local function ball(pen: Pen, x: number, y: number, z: number, d: number, color: Color3): Piece
	return add(pen, "Ball", Vector3.new(d, d, d), CFrame.new(x, y, z), color)
end

-- A round bar from one point to another
local function rod(pen: Pen, from: Vector3, to: Vector3, d: number, color: Color3): Piece
	local along = to - from
	local right = along.Unit
	local side = if math.abs(right.Y) > 0.95 then Vector3.zAxis else Vector3.yAxis
	local back = right:Cross(side).Unit
	local up = back:Cross(right)
	return add(
		pen,
		"Cylinder",
		Vector3.new(along.Magnitude, d, d),
		CFrame.fromMatrix((from + to) / 2, right, up, back),
		color
	)
end

local function post(pen: Pen, x: number, y: number, z: number, d: number, h: number, color: Color3): Piece
	return rod(pen, Vector3.new(x, y - h / 2, z), Vector3.new(x, y + h / 2, z), d, color)
end

-- A disc facing the reader
local function disc(pen: Pen, x: number, y: number, z: number, d: number, thick: number, color: Color3): Piece
	return rod(pen, Vector3.new(x, y, z - thick / 2), Vector3.new(x, y, z + thick / 2), d, color)
end

-- A box turned in its own place: degrees about X, Y and Z
local function turned(pen: Pen, at: Vector3, size: Vector3, color: Color3, rx: number, ry: number, rz: number): Piece
	return add(pen, "Block", size, CFrame.new(at) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz)), color)
end

local function within(pen: Pen, at: CFrame): Pen
	return { List = pen.List, Base = pen.Base * at, Move = pen.Move }
end

-- The glass the list is on: every style's, its rim in the style's own colour
local function glass(pen: Pen, rim: Color3)
	local p = Boards.Panel
	local middle = p.Bottom + p.Height / 2
	box(pen, 0, middle, -0.35, p.Width + 1.1, p.Height + 1.1, 0.9, rim)
	box(pen, 0, middle, 0, p.Width + 0.3, p.Height + 0.3, 0.6, GLASS)
end

local TOP = Boards.Panel.Bottom + Boards.Panel.Height -- the glass's top edge

----------------------------------------------------------------------------------------------------------------------
-- Style 1: driftwood and rope

local function starfish(pen: Pen, x: number, y: number, z: number, r: number, color: Color3)
	for i = 0, 4 do
		local a = math.rad(90 + i * 72)
		turned(
			pen,
			Vector3.new(x + math.cos(a) * r * 0.5, y + math.sin(a) * r * 0.5, z),
			Vector3.new(r, r * 0.42, 0.4),
			color,
			0,
			0,
			90 + i * 72
		)
	end
	ball(pen, x, y, z + 0.1, r * 0.7, color)
end

local function driftwood(pen: Pen, index: number, last: boolean)
	glass(pen, WOOD_D)
	for _, side in { -1, 1 } do
		-- a leaning, crooked trunk: three lengths that do not quite line up, a broken end, and a stub of a branch
		local x = side * 6.45
		local lean = if (index + side) % 2 == 0 then 0.25 else -0.15
		rod(pen, Vector3.new(x - lean, 0.4, -0.2), Vector3.new(x + lean, 9.4, 0), 1.75, WOOD)
		rod(pen, Vector3.new(x + lean, 8.8, 0), Vector3.new(x - lean, 18, -0.1), 1.6, WOOD_L)
		rod(pen, Vector3.new(x - lean, 17.2, -0.1), Vector3.new(x + side * 0.45, 26.2, -0.1), 1.45, WOOD)
		rod(pen, Vector3.new(x + side * 0.42, 26.0, -0.1), Vector3.new(x + side * 0.46, 26.45, -0.1), 1.05, ROPE)
		-- rope wound where the trunk meets the two beams
		for i = 0, 2 do
			post(pen, x + side * 0.28, 23.9 + i * 0.5, -0.1, 1.95, 0.4, if i == 1 then ROPE_D else ROPE)
			post(pen, x, 1.4 + i * 0.5, -0.15, 2.15, 0.4, if i == 1 then ROPE_D else ROPE)
		end
	end
	rod(pen, Vector3.new(-5.9, 11.2, -0.8), Vector3.new(-8.0, 12.9, -0.7), 0.7, WOOD_L)
	-- the beams: the top one a little off level, with a smaller one lashed on it
	rod(pen, Vector3.new(-7.5, 24.4, 0.1), Vector3.new(7.5, 24.75, 0.1), 1.35, WOOD_L)
	rod(pen, Vector3.new(-4.6, 25.5, -0.2), Vector3.new(4.6, 25.35, -0.2), 0.9, WOOD)
	rod(pen, Vector3.new(-7.3, 2.0, 0.1), Vector3.new(7.3, 1.8, 0.1), 1.3, WOOD_L)
	for _, x in { -3.2, 3.2 } do
		rod(pen, Vector3.new(x - 0.2, 24.95, -0.1), Vector3.new(x + 0.2, 24.95, -0.1), 2.1, ROPE)
	end
	-- a rope hung along the foot
	local before: Vector3? = nil
	for i = 0, 6 do
		local t = i / 6 * 2 - 1
		local at = Vector3.new(t * 5.9, 0.95 + t * t * 0.9, 1.0)
		if before then
			rod(pen, before, at, 0.36, ROPE)
		end
		before = at
	end
	-- a glass float with a light in it, hung in rope from the beam's end (the row's last board has one at each end)
	local ends: { number } = if last then { -1, 1 } else { -1 }
	for _, side in ends do
		local x = side * 6.95
		rod(pen, Vector3.new(x, 24.4, 0.7), Vector3.new(x, 22.6, 1.7), 0.28, ROPE_D)
		local lamp = ball(pen, x, 21.6, 1.75, 2.1, SEA)
		lamp.Glow = true
		lamp.Light = 14
		post(pen, x, 22.55, 1.75, 0.9, 0.35, ROPE)
		post(pen, x, 21.6, 1.75, 2.2, 0.22, ROPE)
		disc(pen, x, 21.6, 1.75, 2.2, 0.22, ROPE)
	end
	-- what the sea left on it: a float, a starfish, coral at the foot
	if index % 2 == 1 then
		post(pen, -6.5, 6.0, 1.15, 1.5, 0.9, RED)
		post(pen, -6.5, 6.75, 1.15, 1.5, 0.6, WHITE)
		post(pen, -6.5, 7.4, 1.15, 1.5, 0.7, RED)
		starfish(pen, 6.4, 15.4, 1.0, 1.15, ORANGE)
	else
		starfish(pen, -6.4, 14.2, 1.0, 1.15, PINK)
		post(pen, 6.5, 6.0, 1.15, 1.5, 0.9, YELLOW)
		post(pen, 6.5, 6.75, 1.15, 1.5, 0.6, WHITE)
		post(pen, 6.5, 7.4, 1.15, 1.5, 0.7, YELLOW)
	end
	rod(pen, Vector3.new(5.6, 0.6, 1.8), Vector3.new(5.0, 2.6, 2.0), 0.6, PINK)
	rod(pen, Vector3.new(5.6, 0.6, 1.8), Vector3.new(6.3, 2.2, 2.1), 0.6, PINK)
	rod(pen, Vector3.new(-5.4, 0.6, 1.9), Vector3.new(-5.9, 2.3, 2.1), 0.55, KELP)
	rod(pen, Vector3.new(-5.4, 0.6, 1.9), Vector3.new(-4.7, 1.8, 2.1), 0.55, KELP_D)
	ball(pen, 4.1, 1.1, 2.3, 0.9, STONE)
end

----------------------------------------------------------------------------------------------------------------------
-- Style 2: coral reef and shell

local function branch(pen: Pen, at: Vector3, lean: number, color: Color3, tip: Color3)
	local mid = at + Vector3.new(lean * 0.5, 1.7, 0.1)
	rod(pen, at, mid, 0.85, color)
	local a = mid + Vector3.new(lean * 1.3, 1.5, 0.1)
	local b = mid + Vector3.new(-lean * 0.35, 1.9, 0)
	rod(pen, mid, a, 0.65, color)
	rod(pen, mid, b, 0.65, color)
	ball(pen, a.X, a.Y, a.Z, 0.8, tip)
	ball(pen, b.X, b.Y, b.Z, 0.8, tip)
end

local function reef(pen: Pen, index: number, _last: boolean)
	local tones = ({
		{ CORAL, PINK, PURPLE },
		{ PINK, PURPLE, TEAL },
		{ ORANGE, CORAL, PINK },
	})[(index - 1) % 3 + 1]
	glass(pen, PINK_L)
	-- the pillars: lumps of coral on a stem, big and small to one side and the other, with sprigs growing out
	local lumps = {
		{ 1.75, 3.2 },
		{ 4.7, 1.9 },
		{ 7.6, 2.9 },
		{ 11.0, 1.7 },
		{ 14.0, 2.8 },
		{ 17.6, 1.8 },
		{ 20.6, 2.5 },
		{ 23.3, 2.9 },
	}
	for _, side in { -1, 1 } do
		post(pen, side * 6.45, 12.4, -0.4, 1.7, 24, tones[2])
		for i, lump in lumps do
			local out = if i % 2 == 0 then 0.65 else 0.1
			local tone = tones[(i + (if side == 1 then 1 else 0)) % 3 + 1]
			ball(pen, side * (6.35 + out), lump[1], (i % 3) * 0.3 - 0.2, lump[2], tone)
		end
		for i, y in { 5.6, 12.2, 18.6 } do
			local from = Vector3.new(side * 6.5, y, 0.4)
			local to = from + Vector3.new(side * 1.25, 1.5, 0.5)
			rod(pen, from, to, 0.7, tones[i])
			ball(pen, to.X, to.Y, to.Z, 0.85, PINK_L)
		end
		branch(pen, Vector3.new(side * 6.7, 23.9, -0.2), side * 0.8, tones[1], PINK_L)
		-- an anemone with lit tips, on the pillar's inner top corner
		local cx, cy = side * 5.2, 24.4
		ball(pen, cx, cy, 0.3, 1.9, PURPLE_D)
		for i = -1, 1 do
			local a = math.rad(90 + i * 48)
			local from = Vector3.new(cx, cy + 0.2, 0.4)
			local to = Vector3.new(cx + math.cos(a) * 1.6, cy + math.sin(a) * 1.6, 0.7)
			rod(pen, from, to, 0.55, PURPLE)
			local tip = ball(pen, to.X, to.Y, to.Z, 1.0, SEA)
			tip.Glow = true
			if i == 0 then
				tip.Light = 14
			end
		end
	end
	-- the crown: a scallop shell, its ribs fanned out behind the emblem
	for i = -4, 4 do
		local a = math.rad(90 + i * 19)
		local from = Vector3.new(math.cos(a) * 0.8, 24.6 + math.sin(a) * 0.8, -0.9)
		local r = 6.6 - math.abs(i) * 0.28
		local to = Vector3.new(math.cos(a) * r, 24.6 + math.sin(a) * r, -1.3)
		local tone = if i % 2 == 0 then PINK_L else PEARL
		rod(pen, from, to, 1.75, tone)
		ball(pen, to.X, to.Y, to.Z, 1.75, tone)
	end
	disc(pen, 0, 24.6, -0.6, 3, 1.2, PINK)
	-- a row of pearls under the crown and along the foot
	rod(pen, Vector3.new(-6.1, TOP + 0.75, 0), Vector3.new(6.1, TOP + 0.75, 0), 0.9, tones[2])
	rod(pen, Vector3.new(-6.1, 2.1, 0), Vector3.new(6.1, 2.1, 0), 0.9, tones[2])
	for i = -2, 2 do
		ball(pen, i * 1.5, TOP + 0.85, 0.35, 0.95, PEARL)
	end
	-- the foot: sand, a small shell, a pebble, a sponge
	for i = -1, 1 do
		rod(
			pen,
			Vector3.new(-3.4, 0.8, 1.8),
			Vector3.new(-3.4 + i * 0.85, 1.9 - math.abs(i) * 0.2, 2.0),
			0.75,
			if i == 0 then PEARL else YELLOW
		)
	end
	post(pen, 3.2, 1.2, 1.9, 1.1, 1.2, YELLOW)
	post(pen, 4.3, 1.5, 1.7, 1.0, 1.8, ORANGE)
	starfish(pen, 0.4, 1.5, 1.2, 0.8, ORANGE)
end

----------------------------------------------------------------------------------------------------------------------
-- Style 3: sunken brass

local function bolt(pen: Pen, x: number, y: number, z: number)
	ball(pen, x, y, z, 0.5, GOLD_L)
end

local function brass(pen: Pen, index: number, _last: boolean)
	glass(pen, BRASS)
	for _, side in { -1, 1 } do
		local x = side * 6.5
		-- a pillar of old green copper in brass bands, with a pipe up its outside
		box(pen, x, 12.6, -0.2, 1.6, 23.6, 1.6, VERDI)
		box(pen, x, 1.6, -0.1, 2.4, 1.8, 2.4, VERDI_D)
		for _, y in { 3.0, 9.6, 16.2, 22.6 } do
			box(pen, x, y, -0.1, 2.0, 0.8, 2.0, BRASS)
			bolt(pen, x, y, 0.95)
		end
		rod(pen, Vector3.new(x + side * 1.0, 4.5, -0.5), Vector3.new(x + side * 1.0, 21.8, -0.5), 0.6, BRASS_D)
		ball(pen, x + side * 1.0, 4.5, -0.5, 1.0, BRASS)
		ball(pen, x + side * 1.0, 21.8, -0.5, 1.0, BRASS)
		-- a lamp in a cage on the pillar's head
		box(pen, x, 24.9, -0.1, 2.5, 0.9, 2.5, BRASS)
		local lamp = ball(pen, x, 26.5, -0.1, 1.8, LAMP)
		lamp.Glow = true
		lamp.Light = 14
		for _, cx in { -0.9, 0.9 } do
			rod(pen, Vector3.new(x + cx, 25.3, 0.5), Vector3.new(x + cx, 27.6, 0.5), 0.26, BRASS_D)
			rod(pen, Vector3.new(x + cx, 25.3, -0.8), Vector3.new(x + cx, 27.6, -0.8), 0.26, BRASS_D)
		end
		post(pen, x, 27.75, -0.1, 2.5, 0.4, BRASS)
		ball(pen, x, 28.05, -0.1, 0.9, BRASS)
	end
	-- the head beam and the foot beam, bolted
	box(pen, 0, 24.7, -0.1, 11.4, 1.3, 1.7, VERDI)
	box(pen, 0, 25.4, -0.1, 12, 0.35, 2.0, BRASS)
	box(pen, 0, 1.75, -0.1, 11.4, 1.5, 1.9, VERDI)
	for i = -2, 2 do
		bolt(pen, i * 2.5, 24.65, 0.8)
	end
	-- portholes in the foot, lit from inside
	for _, x in { -3.4, 0, 3.4 } do
		disc(pen, x, 1.75, 0.95, 1.75, 0.35, BRASS)
		local pane = disc(pen, x, 1.75, 1.08, 1.15, 0.3, SEA)
		pane.Glow = true
	end
	-- a valve wheel or a gauge on the right pillar, by turns (the row's first board has the other one on its left)
	local w = if index % 2 == 1 then 1 else -1
	local vx = w * 6.95
	local wheel, gauge = w == 1 or index == 1, w == -1 or index == 1
	if wheel then
		for i = 0, 7 do
			local a = math.rad(i * 45)
			turned(
				pen,
				Vector3.new(vx + math.cos(a), 12.9 + math.sin(a), 1.35),
				Vector3.new(0.4, 0.9, 0.4),
				RED,
				0,
				0,
				i * 45
			)
		end
		for i = 0, 1 do
			turned(pen, Vector3.new(vx, 12.9, 1.35), Vector3.new(1.9, 0.3, 0.3), RED, 0, 0, 45 + i * 90)
		end
		rod(pen, Vector3.new(vx, 12.9, 0.4), Vector3.new(vx, 12.9, 1.6), 0.6, BRASS)
	end
	if gauge then
		disc(pen, -vx, 12.9, 1.0, 2.1, 0.6, BRASS)
		disc(pen, -vx, 12.9, 1.2, 1.6, 0.4, WHITE)
		turned(pen, Vector3.new(-vx + 0.2, 13.1, 1.45), Vector3.new(0.8, 0.18, 0.1), RED, 0, 0, 50)
	end
	-- weed has got hold of one corner
	for i, lean in { -0.5, 0.25, 0.7 } do
		rod(
			pen,
			Vector3.new(6.0 + i * 0.4, 0.6, 1.6),
			Vector3.new(6.0 + i * 0.4 + lean, 2.2 + (i % 2) * 1.0, 1.9),
			0.5,
			if i % 2 == 0 then KELP else KELP_D
		)
	end
	for i = 0, 2 do
		ball(pen, -7.1 + i * 0.2, 4.1 + i * 0.75, 0.75, 0.7 - i * 0.08, VERDI_L)
	end
end

local FRAMES = { driftwood, reef, brass }

----------------------------------------------------------------------------------------------------------------------
-- The emblems, each about 7 studs across, round its own middle

-- A chunky little fish, its nose to the right
local function fish(pen: Pen, body: Color3, belly: Color3, fin: Color3)
	box(pen, 0, 0, 0, 2.5, 1.7, 1.1, body)
	box(pen, 1.2, -0.1, 0, 0.9, 1.15, 0.95, body)
	box(pen, 0.15, -0.6, 0, 2.2, 0.6, 1.2, belly)
	turned(pen, Vector3.new(-1.75, 0.5, 0), Vector3.new(1.5, 0.75, 0.5), fin, 0, 0, -40)
	turned(pen, Vector3.new(-1.75, -0.5, 0), Vector3.new(1.5, 0.75, 0.5), fin, 0, 0, 40)
	turned(pen, Vector3.new(-0.1, 1.1, 0), Vector3.new(1.4, 0.8, 0.45), fin, 0, 0, 14)
	box(pen, 0.95, 0.3, 0.5, 0.5, 0.55, 0.2, WHITE)
	box(pen, 1.05, 0.3, 0.58, 0.28, 0.35, 0.2, DARK)
	turned(pen, Vector3.new(0, -0.25, 0.62), Vector3.new(0.8, 0.4, 0.15), fin, 0, 0, 25)
end

local emblems: { [string]: (pen: Pen) -> () } = {}

-- Oxygen: a big bubble with a diver's two tanks inside
emblems.Bubble = function(pen: Pen)
	local shell = ball(pen, 0, 0, 0, 7.4, SEA)
	shell.Clear = 0.76
	for _, x in { -0.95, 0.95 } do
		post(pen, x, -0.3, 0, 1.7, 3.2, TANK)
		ball(pen, x, 1.3, 0, 1.7, TANK)
		ball(pen, x, -1.9, 0, 1.7, GOLD_D)
		post(pen, x, 2.3, 0, 0.6, 0.6, IRON)
		post(pen, x, 0.6, 0, 1.85, 0.4, DARK)
		post(pen, x, -1.0, 0, 1.85, 0.4, DARK)
	end
	rod(pen, Vector3.new(-1.1, 2.5, 0), Vector3.new(1.1, 2.5, 0), 0.5, IRON)
	disc(pen, 0, 2.5, 0.2, 1.0, 0.6, RED)
	local shine = ball(pen, -2.05, 2.0, 1.9, 1.0, WHITE)
	shine.Clear = 0.15
	local glint = ball(pen, -2.7, 0.9, 1.9, 0.5, WHITE)
	glint.Clear = 0.15
	for _, b in { { 3.9, -1.6, 0.6, 1.5 }, { -4.0, -2.4, 0.3, 1.1 }, { 3.2, 2.9, 0.4, 0.9 } } do
		local bubble = ball(pen, b[1], b[2], b[3], b[4], SEA_L)
		bubble.Clear = 0.35
		bubble.Move = "Bubble"
	end
end

-- Collectors: our Index open on its pages, a fish jumping out of it
emblems.Book = function(pen: Pen)
	local book = within(pen, CFrame.new(0, -1.7, 0) * CFrame.Angles(math.rad(-24), 0, 0))
	box(book, 0, 0, -0.5, 0.7, 3.6, 0.6, BLUE_D)
	for _, side in { -1, 1 } do
		local half = within(book, CFrame.Angles(0, math.rad(-side * 14), 0))
		box(half, side * 2.05, 0, -0.45, 4.0, 3.9, 0.45, BLUE_D)
		box(half, side * 1.85, 0, 0.0, 3.5, 3.5, 0.6, CREAM)
		local plates: { Color3 } = if side == -1 then { ORANGE, TEAL, PINK, YELLOW } else { TEAL, PINK, YELLOW, ORANGE }
		for i, color in plates do
			local px = side * 1.85 + (if i % 2 == 1 then -0.85 else 0.85)
			local py = if i <= 2 then 0.85 else -0.85
			box(half, px, py, 0.3, 1.45, 1.45, 0.16, color)
			-- (a little fish on each plate: a round body, a tail, an eye)
			disc(half, px + 0.14, py, 0.4, 0.82, 0.14, WHITE)
			turned(half, Vector3.new(px - 0.4, py, 0.4), Vector3.new(0.38, 0.38, 0.12), WHITE, 0, 0, 45)
			box(half, px + 0.28, py + 0.1, 0.47, 0.15, 0.15, 0.08, DARK)
		end
	end
	turned(book, Vector3.new(0.35, -2.2, 0.25), Vector3.new(0.6, 1.7, 0.2), RED, 0, 0, 8)
	local jump = within(pen, CFrame.new(0.2, 2.35, 0.5) * CFrame.Angles(0, math.rad(-12), math.rad(34)))
	local big = within(jump, CFrame.new())
	fish(big, ORANGE, CREAM, CORAL)
	box(big, -0.35, 0.05, 0, 0.5, 1.76, 1.2, WHITE)
	for _, d in { { -1.7, 0.7, 0.7 }, { -2.5, 1.5, 0.5 }, { 1.9, 0.9, 0.6 }, { 2.6, 1.7, 0.45 } } do
		local drop = ball(pen, d[1], d[2], 0.5, d[3], SEA)
		drop.Clear = 0.15
	end
end

-- Earners: a chest of gold, a pearl, and a gold fish on the heap
emblems.Chest = function(pen: Pen)
	local low = within(pen, CFrame.new(0, -2.1, 0))
	box(low, 0, 0, 0, 5.8, 2.5, 3.4, WOOD)
	box(low, 0, 0.1, 1.62, 5.2, 0.28, 0.3, WOOD_D)
	for _, x in { -2.35, 0, 2.35 } do
		box(low, x, 0, 0, 0.8, 2.6, 3.65, GOLD)
	end
	box(low, 0, 1.15, 0, 6.0, 0.5, 3.6, GOLD)
	box(low, 0, 0.75, 1.9, 1.35, 1.35, 0.4, GOLD_L)
	box(low, 0, 0.65, 2.1, 0.4, 0.65, 0.2, DARK)
	-- the lid, thrown back
	local lid = within(low, CFrame.new(0, 1.3, -1.7) * CFrame.Angles(math.rad(-70), 0, 0))
	box(lid, 0, 0.4, 1.7, 5.8, 0.9, 3.4, WOOD)
	box(lid, 0, 1.0, 1.7, 5.8, 0.6, 2.3, WOOD_L)
	for _, x in { -2.35, 0, 2.35 } do
		box(lid, x, 0.6, 1.7, 0.8, 1.5, 3.5, GOLD)
	end
	-- the heap
	for _, g in
		{
			{ -1.8, 1.5, 0.5, 1.7, GOLD },
			{ 1.8, 1.5, 0.5, 1.7, GOLD },
			{ 0, 1.6, 0.4, 2.3, GOLD_L },
			{ -0.95, 1.9, -0.5, 1.7, GOLD_D },
			{ 1.0, 1.9, -0.5, 1.7, GOLD },
		} :: { { any } }
	do
		ball(low, g[1], g[2], g[3], g[4], g[5])
	end
	for _, c in { { -2.3, 1.75, 1.2, 20 }, { 1.1, 1.75, 1.45, -25 }, { -0.9, 1.9, 1.35, 8 } } do
		local coin = within(low, CFrame.new(c[1], c[2], c[3]) * CFrame.Angles(math.rad(-25), math.rad(c[4]), 0))
		disc(coin, 0, 0, 0, 1.15, 0.25, GOLD_L)
		disc(coin, 0, 0, 0.1, 0.75, 0.2, GOLD_D)
	end
	ball(low, 2.35, 2.2, 0.9, 1.1, PEARL)
	local top = within(pen, CFrame.new(0.1, 1.75, 0.4) * CFrame.Angles(0, math.rad(-10), math.rad(18)))
	fish(top, GOLD, GOLD_L, ORANGE)
end

-- Deepest: an anchor on its ring
emblems.Anchor = function(pen: Pen)
	post(pen, 0, 0, 0, 0.95, 5.2, STONE)
	rod(pen, Vector3.new(-1.8, 1.7, 0), Vector3.new(1.8, 1.7, 0), 0.8, STONE_D)
	for _, side in { -1, 1 } do
		ball(pen, side * 1.8, 1.7, 0, 1.0, STONE)
		rod(pen, Vector3.new(0, -2.7, 0), Vector3.new(side * 2.0, -2.1, 0), 0.95, STONE)
		rod(pen, Vector3.new(side * 2.0, -2.1, 0), Vector3.new(side * 2.9, -0.8, 0), 0.9, STONE)
		turned(pen, Vector3.new(side * 2.9, -0.6, 0), Vector3.new(1.3, 1.3, 0.7), STONE_D, 0, 0, 45)
	end
	ball(pen, 0, -2.7, 0, 1.2, STONE_D)
	for i = 0, 7 do
		local a = math.rad(i * 45)
		turned(
			pen,
			Vector3.new(math.cos(a) * 0.85, 3.2 + math.sin(a) * 0.85, 0),
			Vector3.new(0.4, 0.8, 0.5),
			GOLD,
			0,
			0,
			i * 45
		)
	end
	local last: Vector3? = nil
	for i = 0, 6 do
		local at = Vector3.new(math.sin(i * 1.05) * 0.75, 2.2 - i * 0.7, 0.55)
		if last then
			rod(pen, last, at, 0.35, ROPE)
		end
		last = at
	end
end

----------------------------------------------------------------------------------------------------------------------

-- A style's number as it can be used
function Boards.style(value: any): number
	local n = if type(value) == "number" and value == value then math.floor(value + 0.5) else 1
	return if FRAMES[n] then n else 1
end

-- One board: its frame in a style, and its emblem. `index`: which one of the row, `last`: the
-- one at its right end (they are not quite the same)
function Boards.board(style: number, emblem: string, index: number, last: boolean): { Piece }
	local pen: Pen = { List = {}, Base = CFrame.identity }
	FRAMES[Boards.style(style)](pen, index, last)
	local draw = emblems[emblem]
	if draw then
		draw({ List = pen.List, Base = CFrame.new(0, Boards.Emblem.Y, 0), Move = "Emblem" })
	end
	return pen.List
end

-- The bed a row stands on, from the row's own middle. `span`: from the first board's middle to the last one's
function Boards.bed(style: number, span: number): { Piece }
	local pen: Pen = { List = {}, Base = CFrame.identity }
	local b = Boards.Bed
	local top, rim = SAND, SAND_D
	if Boards.style(style) == 3 then
		top, rim = STONE, STONE_D
	end
	local long = span + b.Over * 2 - b.Depth
	box(pen, 0, b.Height / 2, 0, long, b.Height, b.Depth, top)
	box(pen, 0, b.Height * 0.3, 0, long, b.Height * 0.6, b.Depth + 0.5, rim)
	for _, side in { -1, 1 } do
		post(pen, side * long / 2, b.Height / 2, 0, b.Depth, b.Height, top)
		post(pen, side * long / 2, b.Height * 0.3, 0, b.Depth + 0.5, b.Height * 0.6, rim)
	end
	return pen.List
end

-- Where the emblem is at a time, against where it stands: a slow bob and a slow look to each side
function Boards.emblemAt(index: number, t: number): CFrame
	local p = t + index * 1.7
	return CFrame.new(0, math.sin(p * 1.3) * 0.28, 0) * CFrame.Angles(0, math.rad(13) * math.sin(p * 0.6), 0)
end

-- A bubble's rise over where it was drawn, and its size then: up, gone, and from the start again
function Boards.bubbleAt(number: number, t: number): (number, number)
	local p = (t * 0.22 + number * 0.37) % 1
	return -1.2 + p * 4, if p < 0.15 then p / 0.15 elseif p > 0.85 then (1 - p) / 0.15 else 1
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
