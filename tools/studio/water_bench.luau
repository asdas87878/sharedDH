--!nocheck
-- The water bench (docs/design/water.md): a small pool built the way the user's tutorial builds its water, to be judged
-- in Studio and tuned before it goes on the map.
-- Run in Edit mode: node tools/studio/run_luau.js <studio_id> tools/studio/water_bench.luau [NAME=value ...]
-- Builds Workspace.WaterBench far from the map and touches nothing else.
--
-- The tutorial's recipe: four flat MESHES (not Parts: a SurfaceAppearance only works on a MeshPart), from the top down:
--   Foam    white Glass, 0.15 see-through, with an empty SurfaceAppearance inside it
--   Water1  the water's colour, Neon, 0.5 see-through, with the water picture on its top
--   Water2  black SmoothPlastic, 0.7 see-through
--   Water3  a colour, Neon, 0.5 see-through
-- The glass layer is drawn before the three under it, so they show through it as water; but where something solid
-- stands in the pool it hides the lower layers and only the white glass is left: a line of foam round it.
local SIZE = 96 -- the pool's side
local THICK = 0.4 -- each layer's thickness
local GAP = 1.0 -- from one layer's top to the next
local FOAM = 0.15 -- the glass layer's transparency
local WATER = Color3.fromRGB(40, 120, 235) -- Water1
local DEEP = Color3.fromRGB(70, 190, 255) -- Water3
local PICTURE = "" -- the water picture for Water1's top; "" leaves it off
local TILE = 24 -- studs to one tile of the picture
local APPEARANCE = true -- the SurfaceAppearance in the glass layer (false shows what it does)
local PARTS = false -- true builds the layers from plain Parts, to see the difference
local AT = Vector3.new(9000, 0, 400)

local AssetService = game:GetService("AssetService")
local old = workspace:FindFirstChild("WaterBench")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "WaterBench"

local function box(name, size, at, colour, material, see)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.Size, p.Position, p.Color = name, true, size, AT + at, colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = see or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = root
	return p
end

local function slab(name, top, colour, material, see)
	local p
	if PARTS then
		p = Instance.new("Part")
	else
		local em = AssetService:CreateEditableMesh()
		local v = {}
		for _, c in { Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1), Vector3.new(1, 1, -1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(1, -1, 1), Vector3.new(1, 1, 1), Vector3.new(-1, 1, 1) } do
			table.insert(v, em:AddVertex(c * 0.5))
		end
		for _, f in { { 1, 3, 2 }, { 1, 4, 3 }, { 5, 6, 7 }, { 5, 7, 8 }, { 1, 2, 6 }, { 1, 6, 5 }, { 4, 7, 3 }, { 4, 8, 7 }, { 1, 5, 8 }, { 1, 8, 4 }, { 2, 3, 7 }, { 2, 7, 6 } } do
			em:AddTriangle(v[f[1]], v[f[2]], v[f[3]])
		end
		p = AssetService:CreateMeshPartAsync(Content.fromObject(em))
	end
	p.Name, p.Anchored, p.CanCollide, p.CastShadow = name, true, false, false
	p.Size = Vector3.new(SIZE, THICK, SIZE)
	p.Position = AT + Vector3.new(0, top - THICK / 2, 0)
	p.Color, p.Material, p.Transparency = colour, material, see
	p.Parent = root
	return p
end

-- the pool: a sand floor with a basin, and things standing in the water
local SAND = Color3.fromRGB(242, 214, 128)
box("Floor", Vector3.new(SIZE, 2, SIZE), Vector3.new(0, -9, 0), SAND)
for _, s in { -1, 1 } do
	box("BankX", Vector3.new(24, 10, SIZE + 48), Vector3.new(s * (SIZE / 2 + 12), -4, 0), SAND)
	box("BankZ", Vector3.new(SIZE, 10, 24), Vector3.new(0, -4, s * (SIZE / 2 + 12)), SAND)
end
box("Pillar", Vector3.new(8, 24, 8), Vector3.new(-20, 2, -10), Color3.fromRGB(190, 120, 200))
box("Block", Vector3.new(20, 8, 12), Vector3.new(14, -3, 16), Color3.fromRGB(150, 150, 168)).Orientation = Vector3.new(0, 30, 12)
local ball = box("Ball", Vector3.new(14, 14, 14), Vector3.new(22, -1, -22), Color3.fromRGB(240, 110, 130))
ball.Shape = Enum.PartType.Ball
box("Shallow", Vector3.new(30, 7, 30), Vector3.new(-28, -5.2, 26), SAND).Orientation = Vector3.new(6, 0, 0)

-- the water itself comes from tools/map/water_look.luau, run on this folder: it looks for a flat part named SeaTile
local sea = box("SeaTile", Vector3.new(SIZE, 0.5, SIZE), Vector3.new(0, -0.25, 0), Color3.fromRGB(70, 190, 215), nil, 0.35)
sea.CanCollide = false
root.Parent = workspace
return "water bench built at " .. tostring(AT) .. ": now run tools/map/water_look.luau on it"
