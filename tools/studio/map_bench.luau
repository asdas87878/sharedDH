--!nocheck
-- The map's structure bench (docs/design/map-structure.md): one curved, two-tier wall and a patch of floor, built the
-- way the reference builds its walls, to be judged against the user's screenshot of it and changed pass by pass.
-- Run in Edit mode: node tools/studio/run_luau.js <studio_id> tools/studio/map_bench.luau [NAME=value ...]
-- Builds Workspace.MapBench far from the map and touches nothing else. Every number is a `local NAME = ` line below,
-- so a pass can change one from the command line. When the bench is right, the same numbers go into
-- tools/map/greybox.py.
--
-- How the reference's walls are made, read from the screenshot (research/ride-a-dino/ref_hub_wall_checker.webp):
--   * the wall is short straight pieces, each a whole number of squares long, so the squares follow the curve
--   * the face has squares in two close greys, about as tall as a player, with about 8 studs across each
--   * the grass is a thick slab, a whole square thick, lying on the wall and standing a little proud of its face
--   * a wall's top goes up and down in whole squares
--   * low down there is a terrace: a short wall, a few squares deep, with its own grass, before the tall wall
local SQUARE = 5 -- studs to a square: about a player's height
local PIECE = 2 -- squares to a piece of wall along the curve
local RADIUS = 150 -- of the low wall's face
local SWEEP = 110 -- degrees of arc
local LOW = 3 -- the low wall's height in squares, to the underside of its grass
local LEDGE = 3 -- how deep the terrace is, in squares
local HIGH = 9 -- the tall wall's height in squares, to the underside of its grass
local CAP = 1 -- the grass's thickness, in squares
local PROUD = 1 -- how far the grass stands out past the face, in studs
local BACK = 4 -- how deep the top grass is, in squares
local WAVE = 5 -- pieces between changes of height
local STUDS = "native" -- "native": Roblox's own studs on every part; "none": smooth
local CHECK = "" -- the squares picture (two squares to a tile, clear and a shade of black); "" leaves the squares off
local SHADE = 0.0 -- extra: darken every other piece's colour by this share, a zero-upload way to see columns
local FACE = Color3.fromRGB(198, 214, 204)
local GRASS = Color3.fromRGB(120, 172, 92)
local FLOOR = Color3.fromRGB(96, 148, 76)
local AT = Vector3.new(9000, 0, 0)

local old = workspace:FindFirstChild("MapBench")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "MapBench"
local tile = SQUARE * 2
local count = 0

local function picture(part, face, offsetU, offsetV)
	if CHECK ~= "" then
		local t = Instance.new("Texture")
		t.Texture = CHECK
		t.Face = face
		t.StudsPerTileU = tile
		t.StudsPerTileV = tile
		t.OffsetStudsU = offsetU or 0
		t.OffsetStudsV = offsetV or 0
		t.Parent = part
	end
end

local function box(name, cf, size, colour, dark)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Material = Enum.Material.Plastic
	p.Color = if dark and SHADE > 0 then colour:Lerp(Color3.new(0, 0, 0), SHADE) else colour
	local surface = if STUDS == "native" then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	p.TopSurface = surface
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.FrontSurface = surface
	p.BackSurface = Enum.SurfaceType.Smooth
	p.LeftSurface = Enum.SurfaceType.Smooth
	p.RightSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Parent = root
	count += 1
	return p
end

-- the floor: one flat piece, its squares on the world's grid
local floor = box("Floor", CFrame.new(AT + Vector3.new(0, -1, 0)), Vector3.new(RADIUS * 2 + 120, 2, RADIUS * 2 + 120), FLOOR)
picture(floor, Enum.NormalId.Top)

-- the wall: pieces along the arc, each PIECE squares long on the low wall's face, facing the middle
local long = PIECE * SQUARE
local step = 2 * math.asin(long / 2 / RADIUS)
local pieces = math.floor(math.rad(SWEEP) / step)
local function heightAt(i, base, salt)
	local block = math.floor(i / WAVE)
	local v = math.sin(block * 12.9898 + salt * 78.233) * 43758.5453
	return base + math.floor((v - math.floor(v)) * 3) - 1 -- one square down, level, or one up
end
local lows, highs = {}, {}
for i = -1, pieces do
	lows[i] = heightAt(i, LOW, 1) * SQUARE
	highs[i] = math.max(heightAt(i, HIGH, 2) * SQUARE, lows[i] + (CAP + 2) * SQUARE)
end
for i = 0, pieces - 1 do
	local a = -math.rad(SWEEP) / 2 + (i + 0.5) * step
	local out = Vector3.new(math.sin(a), 0, -math.cos(a)) -- from the middle to the wall
	local face = CFrame.lookAt(AT + out * RADIUS, AT) -- on the low wall's face, looking at the middle (Front faces it)
	local dark = i % 2 == 1
	local low, high = lows[i], highs[i]
	local ledge = LEDGE * SQUARE
	local cap = CAP * SQUARE
	local reach = RADIUS + ledge -- the tall wall's face
	-- A flat piece on a curve can only meet its neighbours along one line. So what you see is made exact: each
	-- face is as wide as the curve needs AT THAT FACE, and each grass slab as wide as its own front edge needs.
	-- Behind them, a plain core a hair lower and a little wider fills the thin wedges that open toward the back.
	-- Where a neighbour is lower, this piece's end shows: there the face is a whole block, not a thin slab, and the
	-- core stops inside it, so the corner is one clean flat side (the user saw a small step there, 2026-11-11).
	local function across(r)
		return 2 * r * math.tan(step / 2)
	end
	local deep = BACK * SQUARE
	-- a core from one side to the other: `seen` is the piece in front of it; the part's +X is toward piece i - 1
	local function core(name, y0, y1, z0, z1, wideAt, seenWide, mine, before, after, colour)
		local left = if before < mine then seenWide / 2 - 0.05 else wideAt / 2
		local right = if after < mine then seenWide / 2 - 0.05 else wideAt / 2
		box(name, face * CFrame.new((left - right) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(left + right, y1 - y0, z1 - z0), colour)
	end
	-- the low wall and its grass
	local lowEnd = lows[i - 1] < low or lows[i + 1] < low
	local faceDeep = if lowEnd then ledge else 1
	local w = box("LowFace", face * CFrame.new(0, low / 2, faceDeep / 2), Vector3.new(across(RADIUS), low, faceDeep), FACE, dark)
	picture(w, Enum.NormalId.Front, 0, low % tile)
	core("LowCore", 0, low - 0.05, 1, ledge, across(reach) + 0.1, across(RADIUS), low, lows[i - 1], lows[i + 1], FACE)
	local g = box("LowGrass", face * CFrame.new(0, low + cap / 2, (ledge - PROUD) / 2), Vector3.new(across(RADIUS - PROUD), cap, ledge + PROUD), GRASS, dark)
	picture(g, Enum.NormalId.Top)
	picture(g, Enum.NormalId.Front)
	core("LowGrassCore", low, low + cap - 0.05, 0.2, ledge, across(reach) + 0.1, across(RADIUS - PROUD), low, lows[i - 1], lows[i + 1], GRASS)
	-- the tall wall and its grass
	local highEnd = highs[i - 1] < high or highs[i + 1] < high
	local highDeep = if highEnd then deep else 1
	local t = box("HighFace", face * CFrame.new(0, high / 2, ledge + highDeep / 2), Vector3.new(across(reach), high, highDeep), FACE, dark)
	picture(t, Enum.NormalId.Front, 0, high % tile)
	core("HighCore", 0, high - 0.05, ledge + 1, ledge + deep, across(reach + deep) + 0.1, across(reach), high, highs[i - 1], highs[i + 1], FACE)
	local tg = box("HighGrass", face * CFrame.new(0, high + cap / 2, ledge + (deep - PROUD) / 2), Vector3.new(across(reach - PROUD), cap, deep + PROUD), GRASS, dark)
	picture(tg, Enum.NormalId.Top)
	picture(tg, Enum.NormalId.Front)
	core("HighGrassCore", high, high + cap - 0.05, ledge + 0.2, ledge + deep, across(reach + deep) + 0.1, across(reach - PROUD), high, highs[i - 1], highs[i + 1], GRASS)
end
-- a player, for scale, at the foot of the wall
local man = box("Player", CFrame.new(AT + Vector3.new(0, 2.5, -(RADIUS - 6))), Vector3.new(2, 5, 1), Color3.fromRGB(90, 170, 230))
man.TopSurface = Enum.SurfaceType.Smooth
man.FrontSurface = Enum.SurfaceType.Smooth
root.Parent = workspace
local eye = AT + Vector3.new(RADIUS * 0.25, 62, RADIUS * 0.35)
local look = AT + Vector3.new(-RADIUS * 0.1, 18, -RADIUS)
return string.format("MapBench: %d parts, %d pieces of wall; capture from %.0f, %.0f, %.0f looking at %.0f, %.0f, %.0f", count, pieces, eye.X, eye.Y, eye.Z, look.X, look.Y, look.Z)
