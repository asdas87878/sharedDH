--!nocheck
-- The moving water (docs/design/water.md). A client script. The sea is ONE huge block of the tutorial's water (four
-- flat mesh layers; white glass on top, so anything standing in the water gets a line of foam round it) that stays
-- under the camera wherever it goes, so no join between blocks is ever in view. Round it, far off, lies a ring of
-- plain water out to the horizon. The picture on it drifts slowly and the water breathes, so the foam lines swell
-- and shrink like small waves lapping.
-- The picture is the water from the tutorial's free pack; the layers are copies of one plain cube mesh.
--
-- Under the surface (2026-11-13, docs/design/water.md "Under the water"): when the camera goes under, the view takes
-- on the colour of the land it is in. Each land's water is its own bright colour (ZONES, from tools/map/water_zones.py):
-- the distance fades into it, the near view is washed with a light tint of it, colours are made a little stronger.
-- Looking up you see the surface from below: a bright sheet with the water's picture moving on it. In the first lands
-- shafts of light stand in the water; everywhere small specks drift past. Only while the game is running.
-- What it changes outside its own folder, on this player's machine: Lighting's FogColor, FogStart and FogEnd, the
-- Atmosphere in Lighting (taken out while under water: Roblox's fog only works without one; put back at the surface),
-- and its own two effects in Lighting, WaterColour and WaterSoft.
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
	-- under the water
	UnderColour = Color3.fromRGB(170, 240, 255), -- the surface seen from below: a bright sheet,
	UnderSee = 0.35, -- this see-through,
	UnderLines = 0.0, -- with the picture's lines this faint on it (0 strongest),
	UnderTile = 96, -- and this big
	Blend = 6, -- how many studs of going under it takes for the look to come fully on
	Border = 260, -- the look changes from one land's to the next over this much lane either side of the border
	Soft = 0.18, -- how soft the distance is under water (0 off)
	ShaftCount = 9, -- shafts of light round the camera,
	ShaftGrid = 78, -- standing this far apart,
	ShaftLong = 190, -- reaching this far down,
	ShaftSee = 0.86, -- this faint at their brightest (1 unseen),
	Specks = 26, -- drifting specks a second
	-- Seeing far (2026-11-13). The water is a veil: it starts FogStart from the camera and has taken a land's own share
	-- of the view ("thick") by that land's distance ("see"); in most lands that is well short of hiding anything.
	FogStart = 80,
	EndAt = 2300, -- where the view ends for good: a ring of the water's colour, past anything the map shows
	-- The deep lands keep a ceiling: the lit water overhead never gets further than this above the camera, so the
	-- best thing about the first lands (bright moving water over your head) goes all the way down
	CeilUp = 520,
	CeilSee = 0.12, -- how see-through that deep ceiling is (the real surface, near the top, is UnderSee)
}
-- each land's water: {s where it begins, water colour, see, tint, extra colour, shafts, specks' colour, thick, ceiling}
local ZONES = {
	--ZONES--
}
-- the lane's line as the map was built: {x, z, s}, so the script knows which land the camera is in
local LINE = {
	--LINE--
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

-- ---------------------------------------------------------------- under the water
local Lighting = game:GetService("Lighting")
local playing = RunService:IsRunning() -- a look in Edit mode never touches the place's Lighting

local under = layer("Under", LOOK.Gap * 3 + 0.6, LOOK.UnderColour, Enum.Material.Neon, 1)
local underPicture = Instance.new("Texture")
underPicture.Texture = LOOK.Picture
underPicture.Face = Enum.NormalId.Bottom
underPicture.StudsPerTileU, underPicture.StudsPerTileV = LOOK.UnderTile, LOOK.UnderTile
underPicture.Transparency = 1
underPicture.Parent = under
-- (it is placed by `underwater`, not with the other layers: deep down it leaves the surface and rides over the camera)

local fx = Instance.new("Part") -- holds the shafts' ends and the specks; rides with the camera
fx.Name = "WaterFx"
fx.Anchored, fx.CanCollide, fx.CanQuery, fx.CanTouch, fx.CastShadow = true, false, false, false, false
fx.Transparency = 1
fx.Size = Vector3.new(180, 90, 180)
fx.Parent = folder
local shafts = {}
for i = 1, LOOK.ShaftCount do
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = fx, fx
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Width0, beam.Width1 = 7, 30
	beam.LightEmission, beam.LightInfluence = 1, 0
	beam.Transparency = NumberSequence.new(1)
	beam.Parent = fx
	shafts[i] = { a0, a1, beam }
end
local specks = Instance.new("ParticleEmitter")
specks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
specks.Rate = 0
specks.Lifetime = NumberRange.new(5, 8)
specks.Speed = NumberRange.new(0.4, 1.8)
specks.SpreadAngle = Vector2.new(180, 180)
specks.Acceleration = Vector3.new(0, 0.5, 0)
specks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.45) })
specks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1) })
specks.LightEmission = 0.7
specks.Parent = fx

-- The end of the view. Roblox's fog doesn't cover the sky, so past the last thing you could see, the sky showed through
-- in its own blue. Four walls and a floor stand round the camera where the view ends: at that distance they are
-- wholly the water's colour, so the water closes in on every side.
local curtain = {}
for i = 1, 16 do
	local p = Instance.new("Part")
	p.Name = "WaterEnd"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = Vector3.new(2048, 2048, 4)
	p.Material = Enum.Material.Neon -- its own colour whatever the light: it is the water, not a wall
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Transparency = 1
	p.Parent = folder
	curtain[i] = p
end

local colour, soft, atmosphere
if playing then
	colour = Instance.new("ColorCorrectionEffect")
	colour.Name = "WaterColour"
	colour.Parent = Lighting
	soft = Instance.new("DepthOfFieldEffect")
	soft.Name = "WaterSoft"
	soft.NearIntensity, soft.FarIntensity = 0, 0
	soft.FocusDistance, soft.InFocusRadius = 50, 140
	soft.Parent = Lighting
end

local function mix(a, b, t)
	return a + (b - a) * t
end

-- where along the lane the camera is: the nearest point of the lane's line
local lastPoint = 1
local function alongLane(eye)
	local best, bestD = lastPoint, math.huge
	for i = math.max(1, lastPoint - 12), math.min(#LINE, lastPoint + 12) do
		local d = (LINE[i][1] - eye.X) ^ 2 + (LINE[i][2] - eye.Z) ^ 2
		if d < bestD then
			best, bestD = i, d
		end
	end
	if bestD > 900 ^ 2 then -- far from where it was last: look along the whole line
		for i = 1, #LINE do
			local d = (LINE[i][1] - eye.X) ^ 2 + (LINE[i][2] - eye.Z) ^ 2
			if d < bestD then
				best, bestD = i, d
			end
		end
	end
	lastPoint = best
	return LINE[best][3]
end

-- the look at a place along the lane: one land's, or two lands' mixed near their border
local function lookAt(at)
	local i = 1
	for k = 1, #ZONES do
		if at >= ZONES[k][1] then
			i = k
		end
	end
	local a = ZONES[i]
	local b, t = a, 0
	if i < #ZONES and at > ZONES[i + 1][1] - LOOK.Border then
		b, t = ZONES[i + 1], 0.5 * (at - (ZONES[i + 1][1] - LOOK.Border)) / LOOK.Border
	elseif i > 1 and at < a[1] + LOOK.Border then
		b, t = ZONES[i - 1], 0.5 - 0.5 * (at - a[1]) / LOOK.Border
	end
	return a[2]:Lerp(b[2], t), mix(a[3], b[3], t), a[4]:Lerp(b[4], t), mix(a[5], b[5], t), mix(a[6], b[6], t), a[7]:Lerp(b[7], t),
		mix(a[8], b[8], t), a[9]:Lerp(b[9], t)
end

local wet = 0 -- 0 above the water, 1 well under it
local function underwater(eye, t, dt, centre)
	local depth = LOOK.Top - eye.Y
	local want = math.clamp((depth - 1) / LOOK.Blend, 0, 1)
	wet = wet + (want - wet) * math.min(1, dt * 8)
	local water, see, tint, vivid, shaft, speck, thick, ceiling = lookAt(alongLane(eye))
	-- the water overhead, seen from below: the real surface while it is near, and deeper down a ceiling of lit water
	-- that stays CeilUp over the camera. Only shown from below, or the hub would lose its view down into the water
	local surfaceY = LOOK.Top - (LOOK.Gap * 3 + 0.6)
	local ceilY = math.min(surfaceY, eye.Y + LOOK.CeilUp)
	local deepness = math.clamp((surfaceY - ceilY) / 200, 0, 1) -- 0 while it is the real surface, 1 well below it
	under.CFrame = CFrame.new(centre.X, ceilY, centre.Z)
	under.Transparency = mix(1, mix(LOOK.UnderSee, LOOK.CeilSee, deepness), wet)
	underPicture.Transparency = mix(1, LOOK.UnderLines, wet)
	underPicture.OffsetStudsU = (t * LOOK.Drift.X * 1.6) % LOOK.UnderTile
	underPicture.OffsetStudsV = (t * LOOK.Drift.Y * 1.6) % LOOK.UnderTile
	-- Near the top it is the bright surface. Deep down it is a sheet of the land's own water, a little lighter: a Neon
	-- part glows about half as bright again as its colour, and a pale one burnt out to a flat glare with no picture
	-- on it and a hard edge against the distance, so the deep one is the water's colour turned down
	under.Color = ceiling:Lerp(Color3.new(water.R * 0.66 + 0.04, water.G * 0.66 + 0.04, water.B * 0.66 + 0.04), deepness)
	-- shafts of light, from that water overhead, in the land's own colour: they stand on a grid in the world, so
	-- swimming past them they stay where they are
	fx.CFrame = CFrame.new(eye)
	local strength = wet * shaft
	local gx, gz = math.floor(eye.X / LOOK.ShaftGrid), math.floor(eye.Z / LOOK.ShaftGrid)
	for i, item in shafts do
		local cx, cz = gx + (i - 1) % 3 - 1, gz + math.floor((i - 1) / 3) - 1
		local h = math.sin(cx * 12.9898 + cz * 78.233) * 43758.5453
		local r1, r2 = h - math.floor(h), (h * 7.13) % 1
		local x, z = (cx + 0.15 + 0.7 * r1) * LOOK.ShaftGrid, (cz + 0.15 + 0.7 * r2) * LOOK.ShaftGrid
		local lean = math.sin(t * 0.25 + r1 * 6) * 12
		item[1].WorldPosition = Vector3.new(x, ceilY - 2, z)
		item[2].WorldPosition = Vector3.new(x + 46 + lean, math.max(ceilY - LOOK.ShaftLong - 260 * deepness, eye.Y - 60), z + 28)
		local see_ = mix(1, LOOK.ShaftSee + 0.08 * r2, strength)
		item[3].Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, see_), NumberSequenceKeypoint.new(0.6, mix(1, 0.95, strength)), NumberSequenceKeypoint.new(1, 1) })
		item[3].Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(ceiling, 0.3 + 0.4 * deepness))
		item[3].Width0, item[3].Width1 = 7 + 10 * deepness, 30 + 30 * deepness
	end
	specks.Rate = LOOK.Specks * wet
	specks.Color = ColorSequence.new(speck)
	-- the end of the view: a ring of sixteen sheets, two rows of eight, kept under the surface
	local low = math.min(eye.Y, LOOK.Top - 12 - 1024)
	for i, p in curtain do
		local a_ = (i - 1) % 8 * math.pi / 4
		local y = low + (i > 8 and 2048 or 0)
		local at = Vector3.new(eye.X + math.cos(a_) * LOOK.EndAt, y, eye.Z + math.sin(a_) * LOOK.EndAt)
		p.CFrame = CFrame.lookAt(at, Vector3.new(eye.X, y, eye.Z))
		p.Color = water
		p.Transparency = (wet > 0.5 and y - 1024 < LOOK.Top - 13) and 0 or 1 -- a row wholly over the surface stays unseen
	end
	if not playing then
		return
	end
	-- the view: the distance fades into the land's water, the near view is washed with it, colours a little stronger
	colour.TintColor = Color3.new(1, 1, 1):Lerp(tint, wet)
	colour.Saturation = vivid * wet
	colour.Contrast = 0.04 * wet
	soft.Enabled = wet > 0.02 and LOOK.Soft > 0
	soft.FarIntensity = LOOK.Soft * wet
	if wet > 0.02 then
		if not atmosphere then
			atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
			if atmosphere then
				atmosphere.Parent = script
			end
		end
		-- the fog has taken `thick` of the view at `see`, and goes on thickening at the same rate beyond it
		Lighting.FogColor = water
		Lighting.FogStart = LOOK.FogStart
		Lighting.FogEnd = mix(100000, LOOK.FogStart + (see - LOOK.FogStart) / math.max(0.05, thick), wet)
	else
		if atmosphere then
			atmosphere.Parent = Lighting
			atmosphere = nil
		end
		Lighting.FogEnd = 100000
		Lighting.FogStart = 0
	end
end

local began = os.clock()
local connection
connection = RunService.Heartbeat:Connect(function(dt)
	local t = os.clock() - began
	if t > SECONDS then
		connection:Disconnect()
		return
	end
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	-- the block follows the camera a whole tile of the picture at a time, so the picture never jumps
	local snap = LOOK.UnderTile -- a step both pictures fit a whole number of times (96 is twice 48)
	local centre = Vector3.new(math.round(eye.X / snap) * snap, 0, math.round(eye.Z / snap) * snap)
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
	underwater(eye, t, dt, centre)
end)
return "water made: one block of " .. LOOK.Size .. " with plain water round it"
