--!nocheck
-- The moving water (docs/design/water.md). A client script. The sea is ONE huge block of the tutorial's water (four
-- flat mesh layers; white glass on top, so anything standing in the water gets a line of foam round it) that stays
-- under the camera wherever it goes, so no join between blocks is ever in view. Round it, far off, lies a ring of
-- plain water out to the horizon. The picture on it drifts slowly and the water breathes, so the foam lines swell
-- and shrink like small waves lapping.
-- The picture is the water from the tutorial's free pack; the layers are copies of one plain cube mesh.
-- Installed by tools/map/water_luau.py as ClaudeBlockout.Surface.WaterLook (a Script that runs on the client).
-- For a look in Edit mode: node tools/studio/run_luau.js <id> tools/map/water_look.luau 'SECONDS=60'
local ROOT = script.Parent -- the folder that holds the plain SeaTile parts (they are turned unseen)
local SECONDS = math.huge -- how long to keep it moving (Edit-mode looks set a number)
local SLAB = ROOT:WaitForChild("WaterKit"):WaitForChild("Slab") -- the box mesh every layer is a copy of. It sits in a
-- model marked Persistent, so it reaches every player however far away it is (the map streams in by distance)

local LOOK = {
	Top = 0, -- the height of the water's surface
	Size = 2048, -- the block's side: the biggest a part can be
	Thick = 0.1, -- each layer's thickness: thin, so a layer at the camera's own height is only a hairline
	Gap = 2.6, -- from one layer's top to the next: more is wider steps (the white band, then the next, then the next)
	Foam = Color3.fromRGB(250, 252, 255), -- the glass layer on top
	FoamSee = 0.35, -- the tutorial's is 0.15; higher lets the floor and the walls show through the water
	Water = Color3.fromRGB(70, 160, 250), -- the water's colour (Neon)
	WaterSee = 0.76,
	Shade = Color3.fromRGB(0, 20, 40), -- the dark layer under it
	ShadeSee = 0.78,
	Deep = Color3.fromRGB(32, 58, 86), -- the bottom layer: the tutorial's is this dark "Earth blue", Neon. Each layer down
	-- darkens the water a step, which is what makes the steps at an edge show
	DeepSee = 0.85,
	Far = Color3.fromRGB(40, 176, 244), -- the plain water round the block, far off
	FarSee = 0.1,
	-- the picture: pale lines round cells, ONE layer of it as in the tutorial. This is the water from the free pack
	-- the tutorial uses (Creator Store asset 6127206197). Our own drawing (tools/art/water_texture.py) can go here
	-- once it is uploaded.
	Picture = "rbxassetid://6126332496",
	Tile = 48, -- studs to one tile of the picture: bigger is bigger cells
	See = 0.6, -- how faint the picture is (0 strongest; the tutorial's lines are soft)
	Drift = Vector2.new(1.6, 0.7), -- how fast it slides, studs a second
	-- breathing: the three lower layers rise and fall, two slow waves of different lengths added together
	Breath = 0.32, -- studs up and down
	Periods = { 5.3, 8.9 }, -- seconds
	Sway = 0.5, -- the picture also swings a little with the breath, in studs
}

local RunService = game:GetService("RunService")

for _, old in ROOT:GetChildren() do
	if old.Name == "WaterLayers" then
		old:Destroy()
	end
end
local folder = Instance.new("Folder")
folder.Name = "WaterLayers"

local function hide(sea) -- the map's own plain sea tiles stay for anything that looks for them, unseen
	if sea:IsA("BasePart") and sea.Name == "SeaTile" then
		sea.Transparency = 1
	end
end
for _, sea in ROOT:GetChildren() do
	hide(sea)
end
ROOT.ChildAdded:Connect(hide) -- they arrive as the player travels (the map streams in by distance)

local function layer(name, down, colour, material, see)
	local p = SLAB:Clone()
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = Vector3.new(LOOK.Size, LOOK.Thick, LOOK.Size)
	p.CFrame = CFrame.new(0, LOOK.Top - down - LOOK.Thick / 2, 0)
	p.Color, p.Material, p.Transparency = colour, material, see
	p.Parent = folder
	return p
end

local foam = layer("Foam", 0, LOOK.Foam, Enum.Material.Glass, LOOK.FoamSee)
Instance.new("SurfaceAppearance").Parent = foam
local water = layer("Water1", LOOK.Gap, LOOK.Water, Enum.Material.Neon, LOOK.WaterSee)
local shade = layer("Water2", LOOK.Gap * 2, LOOK.Shade, Enum.Material.SmoothPlastic, LOOK.ShadeSee)
local deep = layer("Water3", LOOK.Gap * 3, LOOK.Deep, Enum.Material.Neon, LOOK.DeepSee)
local picture = Instance.new("Texture")
picture.Texture = LOOK.Picture
picture.Face = Enum.NormalId.Top
picture.StudsPerTileU, picture.StudsPerTileV = LOOK.Tile, LOOK.Tile
picture.Transparency = LOOK.See
picture.Parent = water

local parts = { { foam, 0 }, { water, LOOK.Gap }, { shade, LOOK.Gap * 2 }, { deep, LOOK.Gap * 3 } } -- part, how far down, breathes
local ring = {} -- the plain water round the block: eight flat parts, each the block's size
for dx = -1, 1 do
	for dz = -1, 1 do
		if dx ~= 0 or dz ~= 0 then
			local p = Instance.new("Part")
			p.Name = "FarWater"
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Size = Vector3.new(LOOK.Size, LOOK.Thick, LOOK.Size)
			p.Color, p.Material, p.Transparency = LOOK.Far, Enum.Material.SmoothPlastic, LOOK.FarSee
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Parent = folder
			table.insert(ring, { p, Vector3.new(dx, 0, dz) * LOOK.Size })
		end
	end
end
folder.Parent = ROOT

local began = os.clock()
local connection
connection = RunService.Heartbeat:Connect(function()
	local t = os.clock() - began
	if t > SECONDS then
		connection:Disconnect()
		return
	end
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	-- the block follows the camera a whole tile of the picture at a time, so the picture never jumps
	local centre = Vector3.new(math.round(eye.X / LOOK.Tile) * LOOK.Tile, 0, math.round(eye.Z / LOOK.Tile) * LOOK.Tile)
	local breath = (math.sin(t * 2 * math.pi / LOOK.Periods[1]) + 0.6 * math.sin(t * 2 * math.pi / LOOK.Periods[2] + 1.3)) / 1.6
	for i, item in parts do
		local lift = i == 1 and 0 or breath * LOOK.Breath -- the glass on top stays put; the three under it breathe
		item[1].CFrame = CFrame.new(centre.X, LOOK.Top - item[2] - LOOK.Thick / 2 + lift, centre.Z)
	end
	for _, item in ring do
		item[1].CFrame = CFrame.new(centre + item[2] + Vector3.new(0, LOOK.Top - LOOK.Thick / 2, 0))
	end
	local sway = breath * LOOK.Sway
	picture.OffsetStudsU = (t * LOOK.Drift.X + sway) % LOOK.Tile
	picture.OffsetStudsV = (t * LOOK.Drift.Y - sway) % LOOK.Tile
end)
return "water made: one block of " .. LOOK.Size .. " with plain water round it"
