--!strict
-- The saddles (NULLROOM tasks s1 and s2; docs/design/saddles.md): what each looks like and how it fits each fish. Plain
-- sums, no Instances: a saddle here is a list of parts, each with its place from the fish's back under the rider (x
-- across, y up, z to the tail). A land's saddle is one entry in Config.Saddles.Land; a player owns it once the land's
-- whole set is claimed in the Index (IndexService). SaddleController puts the worn one on the fish.
-- A fit is per kind and size (Fits), measured offline on the models; a few designs leave a piece out or shrink one on a
-- fish that would cut it (Adjust). Both, and Designs, are written by tools/saddles/to_luau.py; `frames` and `build` are
-- tools/saddles/fit.py's and saddles.py's, and tools/saddles/saddle_test.luau holds every part against theirs.
local Config = require(script.Parent.Config)
local Designs = require(script.Designs) :: any
local Data = require(script.Fits) :: any

local Saddles = {}

-- One part of a saddle: its place is from the back point; `What` is the pad, a flap, the strap, "trim", "cushion", or
-- the anchor its piece hangs on
export type Part = {
	What: string,
	Shape: string, -- "box", "wedge", "cylinder" (along its x) or "ball"
	Size: Vector3,
	At: CFrame,
	Colour: Color3,
	Neon: boolean,
}

type Row = { number } -- a panel: length, angle, sink, rise, z0, z1
export type Fit = {
	Joint: string, -- the fish's part it is welded to
	Grow: number,
	Front: number,
	Back: number,
	Half: number,
	Slot: number,
	Top: number,
	Base: number,
	Pad: number,
	Yf: number,
	Yb: number,
	Pommel: boolean,
	Cantle: string, -- "f" full, "s" split, "n" none
	Flaps: { Row },
	Strap: Row?,
	Shelf: Row?, -- z0, z1, y, half width
}

type Piece = {
	Anchor: string,
	Shape: string,
	At: Vector3,
	Size: Vector3,
	Colour: Color3,
	Turn: CFrame,
	Neon: boolean,
	Both: boolean,
	Mid: boolean,
}
export type Design = {
	Key: string,
	Land: number,
	Name: string,
	Main: Color3,
	Flap: Color3,
	Trim: Color3,
	TrimNeon: boolean,
	Cushion: Color3,
	Cushion2: Color3,
	Strap: Color3,
	Pieces: { Piece },
}

type Frame = {
	Name: string,
	Side: number,
	At: Vector3, -- the hinge
	U: Vector3, -- down the panel
	N: Vector3, -- out of it
	Length: number,
	Sink: number,
	Rise: number,
	Z0: number,
	Z1: number,
}

-- (fit.py's: the rider's room ahead of the back point and behind it, a panel's thickness, the cushion's top)
local POCKET_FRONT, POCKET_BACK, THICK, SEAT_TOP = 0.95, 0.72, 0.16, 0.38
local SIZES = { "Tiny", "Normal", "Big", "Giant", "Huge", "Colossal" }

local function numbers(text: string): { number }
	local out: { number } = {}
	for word in string.gmatch(text, "[^,]+") do
		table.insert(out, tonumber(word) :: number)
	end
	return out
end

local function vector(text: string): Vector3
	local n = numbers(text)
	return Vector3.new(n[1], n[2], n[3])
end

----------------------------------------------------------------------------------------------------------------------
-- The designs

local designs: { [string]: Design } = {}

local function readPiece(row: string): Piece
	local words = string.split(row, " ")
	local piece: Piece = {
		Anchor = words[1],
		Shape = words[2],
		At = vector(words[3]),
		Size = vector(words[4]),
		Colour = Color3.fromHex(words[5]),
		Turn = CFrame.identity,
		Neon = false,
		Both = false,
		Mid = false,
	}
	for i = 6, #words do
		local word = words[i]
		if string.sub(word, 1, 2) == "r=" then
			local turn = vector(string.sub(word, 3))
			piece.Turn = CFrame.Angles(math.rad(turn.X), math.rad(turn.Y), math.rad(turn.Z))
		elseif word == "neon" then
			piece.Neon = true
		elseif word == "both" then
			piece.Both = true
		elseif word == "mid" then
			piece.Mid = true
		end
	end
	return piece
end

-- A design by its key ("1B"), nil for one there is not
function Saddles.design(key: string): Design?
	local known = designs[key]
	if known then
		return known
	end
	local raw = Designs[key]
	if not raw then
		return nil
	end
	local pieces: { Piece } = {}
	for _, row in raw.Pieces do
		table.insert(pieces, readPiece(row))
	end
	local design: Design = {
		Key = key,
		Land = raw.Land,
		Name = raw.Name,
		Main = Color3.fromHex(raw.Main),
		Flap = Color3.fromHex(raw.Flap),
		Trim = Color3.fromHex(raw.Trim),
		TrimNeon = raw.TrimNeon,
		Cushion = Color3.fromHex(raw.Cushion),
		Cushion2 = Color3.fromHex(raw.Cushion2),
		Strap = Color3.fromHex(raw.Strap),
		Pieces = pieces,
	}
	designs[key] = design
	return design
end

-- A land's saddle: nil while saddles are off, or where its entry names no design
function Saddles.ofLand(land: number): Design?
	local key = if Config.Saddles.On ~= 0 then Config.Saddles.Land[land] else nil
	return if key then Saddles.design(key) else nil
end

-- What a land's saddle is called, "" for a land with none
function Saddles.nameOf(land: number): string
	local design = Saddles.ofLand(land)
	return if design then design.Name .. " Saddle" else ""
end

----------------------------------------------------------------------------------------------------------------------
-- The fits

local fits: { [string]: { [string]: Fit } } = {}

local function readFit(text: string): Fit
	local f = string.split(text, "|")
	local n = numbers(f[2])
	local flaps: { Row } = {}
	for row in string.gmatch(f[5], "[^/]+") do
		table.insert(flaps, numbers(row))
	end
	return {
		Joint = f[1],
		Grow = n[1],
		Front = n[2],
		Back = n[3],
		Half = n[4],
		Slot = n[5],
		Top = n[6],
		Base = n[7],
		Pad = n[8],
		Yf = n[9],
		Yb = n[10],
		Pommel = f[3] == "1",
		Cantle = f[4],
		Flaps = flaps,
		Strap = if f[6] ~= "" then numbers(f[6]) else nil,
		Shelf = if f[7] ~= "" then numbers(f[7]) else nil,
	}
end

-- The fit on a kind at a size, nil for a kind with none (a stand-in fish, the kinds kept out of the herd)
function Saddles.fit(kind: string, size: string): Fit?
	local known = fits[kind]
	if not known then
		local rows: { [string]: Fit } = {}
		local text = Data.Fits[kind]
		if text then
			for i, row in string.split(text, ";") do
				rows[SIZES[i]] = readFit(row)
			end
		end
		fits[kind], known = rows, rows
	end
	return (known :: { [string]: Fit })[size]
end

-- What a design changes on a kind at a size: anchor -> 0 (left out) or the factor its pieces are shrunk by; split -> 1
local function adjustOf(kind: string, size: string, key: string): { [string]: number }
	local text = Data.Adjust[kind]
	local out: { [string]: number } = {}
	if text then
		for row in string.gmatch(text, "[^;]+") do
			local words = string.split(row, " ")
			if words[1] == size and words[2] == key then
				for what, by in string.gmatch(words[3], "(%w+)=([%d%.]+)") do
					out[what] = tonumber(by) :: number
				end
			end
		end
	end
	return out
end

-- A fit with nothing in its way, for a saddle shown by itself (the Index)
local PLAIN: Fit = {
	Joint = "",
	Grow = 1.25,
	Front = 1.6,
	Back = 1.45,
	Half = 0.95,
	Slot = 0,
	Top = 0.16,
	Base = 0,
	Pad = 0.12,
	Yf = 0.16,
	Yb = 0.16,
	Pommel = true,
	Cantle = "f",
	Flaps = { { 1, 42, 0.1, 0.16, -1.5, 1.35 }, { 0.95, 74, 0.1, 0.16, -1.4, 1.25 } },
	Strap = { 0.85, 80, 0.06, 0.12, -0.25, 0.45 },
	Shelf = nil,
}

----------------------------------------------------------------------------------------------------------------------
-- The builder

-- The panels, each a box from `Sink` under its plane to `Rise` over it
local function frames(fit: Fit): { Frame }
	local out: { Frame } = {}
	local function add(
		name: string,
		side: number,
		at: Vector3,
		u: Vector3,
		n: Vector3,
		length: number,
		sink: number,
		rise: number,
		z0: number,
		z1: number
	)
		table.insert(out, {
			Name = name,
			Side = side,
			At = at,
			U = u,
			N = n,
			Length = length,
			Sink = sink,
			Rise = rise,
			Z0 = z0,
			Z1 = z1,
		})
	end
	local x, up = Vector3.xAxis, Vector3.yAxis
	local rise = fit.Top - fit.Base
	if fit.Slot ~= 0 then -- a ridge of the fish's own comes up through the middle: two halves beside it
		for _, side in { -1, 1 } do
			local at = Vector3.new(side * fit.Slot, fit.Base, 0)
			add("pad", side, at, x * side, up, fit.Half - fit.Slot, fit.Pad, rise, -fit.Front, fit.Back)
		end
	else
		add("pad", 0, Vector3.new(-fit.Half, fit.Base, 0), x, up, 2 * fit.Half, fit.Pad, rise, -fit.Front, fit.Back)
	end
	local shelf = fit.Shelf
	if shelf then
		add("shelf", 0, Vector3.new(-shelf[4], shelf[3], 0), x, up, 2 * shelf[4], 0.08, THICK, shelf[1], shelf[2])
	end
	local rows = table.clone(fit.Flaps)
	if fit.Strap then
		table.insert(rows, fit.Strap)
	end
	for _, side in { -1, 1 } do
		local at = Vector3.new(side * fit.Half, fit.Base, 0)
		for i, row in rows do
			-- (the names go by place, as fit.py's: with fewer than two panels the strap is named as the next one)
			local name = if i == 3 then "strap" else "flap" .. i
			local r = math.rad(row[2])
			local u = Vector3.new(side * math.cos(r), -math.sin(r), 0)
			local n = Vector3.new(side * math.sin(r), math.cos(r), 0)
			add(name, side, at, u, n, row[1], row[3], row[4], row[5], row[6])
			at += u * row[1]
		end
	end
	return out
end

-- A place turned over to the other side (x to -x)
local function mirror(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

local function assemble(design: Design, fit: Fit, adjust: { [string]: number }): { Part }
	local out: { Part } = {}
	local k = math.min(fit.Grow, 1.4)
	local function put(what: string, shape: string, size: Vector3, at: CFrame, colour: Color3, neon: boolean)
		if math.min(size.X, size.Y, size.Z) > 0.015 then
			table.insert(out, { What = what, Shape = shape, Size = size, At = at, Colour = colour, Neon = neon })
		end
	end

	-- the blanket
	local t = 0.16 * k
	local list = frames(fit)
	local last: { [number]: { Frame: Frame, Turn: CFrame } } = {}
	local lastOrder: { number } = {}
	for _, fr in list do
		local u, n = fr.U, fr.N
		-- (the left side's own axes are turned about its normal, so z always runs to the tail)
		local turn = if fr.U:Cross(fr.N).Z > 0
			then CFrame.fromMatrix(Vector3.zero, u, n, Vector3.zAxis)
			else CFrame.fromMatrix(Vector3.zero, -u, n, Vector3.zAxis)
		local middle = fr.At + u * (fr.Length / 2)
		local midZ = Vector3.new(0, 0, (fr.Z0 + fr.Z1) / 2)
		local flat = fr.Name == "pad" or fr.Name == "shelf"
		local long = fr.Length + (if flat then 0 else 0.06) -- (a hinge's small overlap)
		local colour = if fr.Name == "strap" then design.Strap elseif flat then design.Main else design.Flap
		put(
			fr.Name,
			"box",
			Vector3.new(long, fr.Rise + fr.Sink, fr.Z1 - fr.Z0),
			turn + (middle + n * ((fr.Rise - fr.Sink) / 2) + midZ),
			colour,
			false
		)
		if fr.Name == "flap1" or fr.Name == "flap2" then
			if not last[fr.Side] then
				table.insert(lastOrder, fr.Side)
			end
			last[fr.Side] = { Frame = fr, Turn = turn }
		end
		if fr.Name ~= "strap" then -- the hem along its front and back ends
			for _, z in { fr.Z0 + t / 2 - 0.03, fr.Z1 - t / 2 + 0.03 } do
				put(
					"trim",
					"box",
					Vector3.new(long + (if fr.Name == "pad" then 0.04 else 0.02), 0.24, t),
					turn + (middle + n * (fr.Rise - 0.075) + Vector3.new(0, 0, z)),
					design.Trim,
					design.TrimNeon
				)
			end
		end
	end
	for _, side in lastOrder do -- and along the lowest edge
		local fr, turn = last[side].Frame, last[side].Turn
		local at = fr.At
			+ fr.U * (fr.Length - t / 2 + 0.05)
			+ fr.N * (fr.Rise - 0.07)
			+ Vector3.new(0, 0, (fr.Z0 + fr.Z1) / 2)
		put("trim", "box", Vector3.new(t, 0.25, fr.Z1 - fr.Z0 + 0.08), turn + at, design.Trim, design.TrimNeon)
	end
	if #lastOrder == 0 then -- no flaps: the hem runs along the pad's own sides
		for _, side in { -1, 1 } do
			local at = Vector3.new(side * (fit.Half - t / 2 + 0.03), fit.Top - 0.075, (fit.Back - fit.Front) / 2)
			local size = Vector3.new(t, 0.24, fit.Front + fit.Back + 0.06)
			put("trim", "box", size, CFrame.new(at), design.Trim, design.TrimNeon)
		end
	end

	-- the cushion: the rider's own size, whatever the fish's
	local h = SEAT_TOP - fit.Top
	if fit.Slot == 0 and h > 0.02 then
		local z1 = math.min(0.7, fit.Back - 0.06)
		local z0 = math.max(-0.15, -fit.Front + 0.04)
		local w = math.min(1.5, 2 * fit.Half - 0.08)
		local y = fit.Top + h / 2 - 0.03
		local at = CFrame.new(0, y, (z0 + z1) / 2)
		put("cushion", "box", Vector3.new(w, h + 0.06, z1 - z0), at, design.Cushion, false)
		local zf = math.max(-0.88, -fit.Front + 0.08)
		if z0 - zf > 0.15 then
			local front = CFrame.new(0, y, (z0 + zf) / 2 + 0.025)
			local size = Vector3.new(math.min(0.76, w), h + 0.03, z0 - zf + 0.05)
			put("cushion", "box", size, front, design.Cushion2, false)
		end
	end

	-- the pieces
	local function panel(name: string): Frame?
		for _, fr in list do
			if fr.Side == 1 and fr.Name == name then
				return fr
			end
		end
		return nil
	end
	local cantleZ = math.max(POCKET_BACK + 0.02, math.min(fit.Back - 0.42, 0.95))
	for _, piece in design.Pieces do
		local a = piece.Anchor
		local by = adjust[a] or 1
		if by == 0 then
			continue
		end
		local onSide = a == "flap" or a == "low" or a == "hem"
		if not onSide then
			if a == "pom" and not fit.Pommel then
				continue
			elseif a == "can" then
				if fit.Cantle == "n" or (piece.Mid and (fit.Cantle == "s" or adjust.split == 1)) then
					continue
				end
			end
			local base = if a == "pom" then CFrame.new(0, fit.Yf, -POCKET_FRONT) else CFrame.new(0, fit.Yb, cantleZ)
			local kk = by
				* (if a == "pom" then math.min(k, 1.15) else math.min(k, 1.2, math.max(0.64, fit.Half + 0.25)))
			local at = CFrame.new(piece.At * kk) * piece.Turn
			put(a, piece.Shape, piece.Size * kk, base * at, piece.Colour, piece.Neon)
			if piece.Both then
				put(a, piece.Shape, piece.Size * kk, base * mirror(at), piece.Colour, piece.Neon)
			end
			continue
		end
		-- on the side: the panel asked for; the upper one may fall back on a wide pad's own side
		local fr: Frame?
		if a == "hem" then
			fr = panel("flap2") or panel("flap1")
		else
			fr = panel(if a == "flap" then "flap1" else "flap2")
		end
		if not fr and a ~= "low" and fit.Half > 1.45 and fit.Slot == 0 then
			local from = math.max(1, fit.Half * 0.55)
			fr = {
				Name = "pad",
				Side = 1,
				At = Vector3.new(from, fit.Base, 0),
				U = Vector3.xAxis,
				N = Vector3.yAxis,
				Length = fit.Half - from,
				Sink = 0,
				Rise = fit.Top - fit.Base,
				Z0 = -fit.Front,
				Z1 = fit.Back,
			}
		end
		if not fr or fr.Length < 0.4 then
			continue
		end
		local ks = math.min(k, fr.Length / 0.8, math.max(fr.Z1, 0.5) / 0.9)
		local along = if a ~= "hem" then fr.Length * piece.At.X else fr.Length + piece.At.X * ks
		local z = (if piece.At.Z >= 0 then fr.Z1 else -fr.Z0) * piece.At.Z
		local place = fr.At + fr.U * along + fr.N * (fr.Rise + piece.At.Y * ks) + Vector3.new(0, 0, z)
		local at = CFrame.fromMatrix(place, fr.U, fr.N, Vector3.zAxis) * piece.Turn
		put(a, piece.Shape, piece.Size * ks, at, piece.Colour, piece.Neon)
		put(a, piece.Shape, piece.Size * ks, mirror(at), piece.Colour, piece.Neon)
	end
	return out
end

local built: { [string]: { Part } } = {}

-- The parts of a design on a kind at a size, nil where there is no fit. Made once and kept: never change the list.
function Saddles.build(kind: string, size: string, key: string): { Part }?
	local id = kind .. "|" .. size .. "|" .. key
	local known = built[id]
	if known then
		return known
	end
	local design, fit = Saddles.design(key), Saddles.fit(kind, size)
	if not design or not fit then
		return nil
	end
	local parts = assemble(design, fit, adjustOf(kind, size, key))
	built[id] = parts
	return parts
end

-- The parts of a design by itself (a picture of it)
function Saddles.alone(key: string): { Part }?
	local id = "|" .. key
	local known = built[id]
	if known then
		return known
	end
	local design = Saddles.design(key)
	if not design then
		return nil
	end
	local parts = assemble(design, PLAIN, {})
	built[id] = parts
	return parts
end

return Saddles
