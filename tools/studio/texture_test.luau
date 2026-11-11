--!nocheck
-- A small test patch for the map's surfaces (docs/design/map-method.md, "Squares everywhere, and Roblox's own studs").
-- Run in Edit mode: node tools/studio/run_luau.js <studio_id> tools/studio/texture_test.luau
-- Builds Workspace.MapTextureTest, 400 studs behind the hub and 60 up, and touches nothing else. Delete it after.
-- It answers two things that can only be seen in Roblox:
--   1. Do Roblox's own studs (a part's Studs surface) still draw, and on which material?
--   2. If several turned pieces are joined into one (a union), does one picture run across them unbroken, lined up
--      with the world's grid? That is what squares on the terrace tops need.
local FLOOR = "rbxassetid://128656252103676" -- art/map/textures.json: squares of 10 with studs (20 studs to a tile)
local SAND = Color3.fromRGB(242, 214, 128)
local at = Vector3.new(3000, 60, -600)
local old = workspace:FindFirstChild("MapTextureTest")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "MapTextureTest"
local notes = {}
local function slab(name, cf, size, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Color = SAND
	p.Material = material
	p.Size = size
	p.CFrame = cf
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end
-- 1. Roblox's own studs, on two materials
for i, material in { Enum.Material.Plastic, Enum.Material.SmoothPlastic } do
	local p = slab("NativeStuds_" .. material.Name, CFrame.new(at + Vector3.new(-90 + i * 50, 0, 0)), Vector3.new(40, 2, 40), material)
	p.TopSurface = Enum.SurfaceType.Studs
	p.Parent = root
end
-- 2. three pieces turned like a terrace top, each with the picture on its own (how the map is built today)
local turns = { -14, 0, 16 }
for i, deg in turns do
	local p = slab("Loose" .. i, CFrame.new(at + Vector3.new(40 + i * 38, 0, 60)) * CFrame.Angles(0, math.rad(deg), 0), Vector3.new(44, 2, 30), Enum.Material.SmoothPlastic)
	local t = Instance.new("Texture")
	t.Texture = FLOOR
	t.Face = Enum.NormalId.Top
	t.StudsPerTileU = 20
	t.StudsPerTileV = 20
	t.Parent = p
	p.Parent = root
end
-- 3. the same three joined into one, starting from a piece that isn't turned, with one picture on top
local pieces = {}
for i, deg in turns do
	table.insert(pieces, slab("Piece" .. i, CFrame.new(at + Vector3.new(40 + i * 38, 0, 0)) * CFrame.Angles(0, math.rad(deg), 0), Vector3.new(44, 2, 30), Enum.Material.SmoothPlastic))
end
local seed = slab("Seed", CFrame.new(at + Vector3.new(40 + 2 * 38, 0, 0)), Vector3.new(4, 2, 4), Enum.Material.SmoothPlastic)
local ok, result = pcall(function()
	return seed:UnionAsync(pieces)
end)
if ok and result then
	result.Name = "Joined"
	result.Anchored = true
	result.UsePartColor = true
	result.Color = SAND
	local t = Instance.new("Texture")
	t.Texture = FLOOR
	t.Face = Enum.NormalId.Top
	t.StudsPerTileU = 20
	t.StudsPerTileV = 20
	t.Parent = result
	result.Parent = root
	local x, y, z = result.CFrame:ToOrientation()
	table.insert(notes, string.format("joined: size %s, turned %.1f %.1f %.1f degrees (0 0 0 = lined up with the world)", tostring(result.Size), math.deg(x), math.deg(y), math.deg(z)))
else
	table.insert(notes, "joining failed: " .. tostring(result))
end
root.Parent = workspace
return "MapTextureTest built at " .. tostring(at) .. "; look from " .. tostring(at + Vector3.new(60, 90, 150)) .. ". " .. table.concat(notes, "; ")
