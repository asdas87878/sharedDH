--!strict
-- Claude's blockout of Ride a Fish (docs/blockout.md). v3, 2026-11-09: a much bigger dock island with a real plot per
-- player (a big show tank, a sign, a kiddie-ride trainer spot, a collect pad), and a dive lane that sweeps diagonally across
-- X/Z as it goes down: nearly straight inside each zone, bending gently at each border. The seabed is built in short
-- segments along that curve, so the floor, the banks and the colours blend from zone to zone, and v2's cliffs became steep
-- ramps. v2's depth profile and zone lengths are kept. The zones are dressed with the prop kit's props (art/props/props.json)
-- as placeholder Models: chunky part stand-ins, each Model named and tagged (attributes PropName, PropScale, PropSize and
-- PropBase, the world CFrame of its base, which is also its pivot) so the imported meshes can be swapped in 1:1.
-- v2 (the long gradual dive, straight down +Z) is in git history.
--
-- Run in Edit mode through the Studio connector, or offline in Lune (docs/blockout.md, "Building offline").
-- Rebuilds Workspace.ClaudeBlockout; touches nothing else. Returns the zones and the lane's path as JSON
-- (tools/art/map_plot.py draws the top and side views from it).
-- Axes: the sea surface is y = 0, the island is centred on the origin, and the dive leaves along +Z, then bends toward +X.
-- For the game code (src/shared/Zones.luau): Dive.<NN_NAME>.Floor is an invisible marker per zone, the straight chord from
-- the zone's start to its end (+Z down the lane, top surface on the chord, Size.X the lane's width); the Dive folder's
-- "Path" attribute is the exact centreline as JSON, { s, x, y, z, w } every PATH_SAMPLE studs in world space.

local HttpService = game:GetService("HttpService")

local ORIGIN = CFrame.new(3000, 0, 0) -- off the baseplate, which would hide everything under the sea
local PLAYER = 5 -- a player is about 5 studs tall
local TILE = 2048 -- the largest a part can be

-- the island
local DECK_Y = 4 -- top of the boardwalks and plot pads
local ISLAND_RADIUS = 300 -- the sandy top
local ISLAND_SHELF = 340 -- the mound under it, just under the water
local ISLAND_TOP = 3
local PLAZA_RADIUS = 95 -- the boardwalk round the spawn
local PLOT_RADIUS = 205 -- from the centre to the middle of a plot
local PLOT_ANGLES = { 54, 90, 126, 162, 198, 234, 270, 306 } -- degrees from +Z; the open side (0) faces the pier
local PLOT_SIZE = Vector2.new(100, 84) -- width, depth
local TANK_SIZE = Vector3.new(76, 30, 40) -- room for several big fish (the Reef Shark is 12 x 9 x 23)
local PIER_END = 430
local LAGOON_Y = -30 -- the lagoon's sandy floor round the island
local LAGOON_RADIUS = 950 -- the ring reef round the lagoon
local RING_GAP = 25 -- degrees either side of +Z left open where the dive leaves the lagoon
local DEEP_PLANE_Y = -300 -- under the open sea near the island, so it reads deep blue from above

-- the dive
local LANE_START = 450 -- along +Z, where the lane begins, just past the dive board
local BEND = 900 -- the bend between two zones' headings, centred on the border
local BLEND = 600 -- widths, heights and colours blend over this much either side of a border
local RAMP_DEGREES = 35 -- a zone's drop-off is a ramp this steep on average (v2: a cliff)
local SEG = 300 -- the seabed's segment length on the straights
local SEG_FINE = 150 -- and in the bends and on the ramps
local SLAB = 40 -- the banks' thickness
local PATH_SAMPLE = 250
local PAD_TIER = 60 -- a flat shelf added when blending into a zone with more terraces

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

type Zone = {
	Name: string,
	Label: string, -- the name props.json uses
	Metres: number, -- the real-ocean depth the gauge shows where the zone begins
	Length: number, -- along the lane
	Heading: number, -- degrees from +Z toward +X, on the zone's straight
	Slope: number, -- degrees down inside the zone
	Drop: number, -- the ramp down at the zone's start
	Lane: number, -- the lane's width
	Floor: Color3,
	Rock: Color3,
	Tiers: { { number } }, -- banks stepping out from the lane: { width, height above the floor at its outer edge }
	Dress: string, -- the zone's own set pieces
	Props: { [string]: number }, -- prop clusters per group (see GROUPS)
}

-- stylua: ignore
local ZONES: { Zone } = {
	{ Name = "SHALLOWS", Label = "Shallows", Metres = 0, Length = 1000, Heading = 0, Slope = 1.5, Drop = 0, Lane = 260, Floor = rgb(236, 222, 172), Rock = rgb(214, 196, 150), Tiers = { { 120, 8 }, { 200, 20 } }, Dress = "None", Props = { grass = 9, rock = 5, coral = 5, shell = 3 } },
	{ Name = "CORAL REEF", Label = "Coral Reef", Metres = 10, Length = 2500, Heading = 20, Slope = 2, Drop = 20, Lane = 220, Floor = rgb(226, 205, 150), Rock = rgb(235, 140, 150), Tiers = { { 80, 30 }, { 140, 50 }, { 220, 68 } }, Dress = "None", Props = { coral = 16, rock = 7, grass = 4, arch = 2, kelp = 2, shell = 3 } },
	{ Name = "KELP FOREST", Label = "Kelp Forest", Metres = 40, Length = 2500, Heading = 40, Slope = 2, Drop = 40, Lane = 240, Floor = rgb(110, 115, 80), Rock = rgb(90, 120, 100), Tiers = { { 100, 60 }, { 160, 140 }, { 240, 240 } }, Dress = "None", Props = { kelp = 16, rock = 7, spire = 3, arch = 1, grass = 4 } },
	{ Name = "SHIPWRECKS", Label = "Shipwrecks", Metres = 80, Length = 2500, Heading = 55, Slope = 2, Drop = 40, Lane = 260, Floor = rgb(150, 140, 120), Rock = rgb(120, 110, 100), Tiers = { { 120, 50 }, { 180, 120 } }, Dress = "Wrecks", Props = { rock = 7, coral = 5, kelp = 4, spire = 2, dock = 3 } },
	{ Name = "OPEN BLUE", Label = "Open Blue", Metres = 150, Length = 2500, Heading = 40, Slope = 2, Drop = 150, Lane = 400, Floor = rgb(80, 110, 150), Rock = rgb(70, 100, 140), Tiers = { { 200, 25 } }, Dress = "None", Props = { rock = 6, coral = 4, arch = 2, spire = 2 } },
	{ Name = "TWILIGHT", Label = "Twilight", Metres = 200, Length = 2500, Heading = 55, Slope = 2, Drop = 80, Lane = 200, Floor = rgb(60, 60, 100), Rock = rgb(55, 50, 95), Tiers = { { 80, 90 }, { 160, 200 }, { 260, 340 } }, Dress = "Arches", Props = { rock = 7, coral = 5, shell = 2 } },
	{ Name = "MIDNIGHT", Label = "Midnight", Metres = 1000, Length = 2500, Heading = 40, Slope = 2, Drop = 80, Lane = 240, Floor = rgb(35, 35, 60), Rock = rgb(30, 30, 55), Tiers = { { 120, 70 }, { 200, 160 } }, Dress = "Jellies", Props = { rock = 7, arch = 2 } },
	{ Name = "VENTS", Label = "Vents", Metres = 2000, Length = 2500, Heading = 25, Slope = 2, Drop = 80, Lane = 220, Floor = rgb(40, 32, 32), Rock = rgb(30, 25, 25), Tiers = { { 90, 80 }, { 150, 180 }, { 240, 300 } }, Dress = "Chimneys", Props = { rock = 5, spire = 4, arch = 1 } },
	{ Name = "BONE GRAVEYARD", Label = "Bone Graveyard", Metres = 4000, Length = 2500, Heading = 40, Slope = 2, Drop = 80, Lane = 320, Floor = rgb(70, 70, 80), Rock = rgb(60, 60, 70), Tiers = { { 160, 40 }, { 260, 90 } }, Dress = "Bones", Props = { rock = 6, spire = 3, arch = 2 } },
	{ Name = "THE UNDERWORLD", Label = "The Underworld", Metres = 6000, Length = 2500, Heading = 55, Slope = 2, Drop = 200, Lane = 140, Floor = rgb(30, 20, 30), Rock = rgb(25, 15, 25), Tiers = { { 60, 260 }, { 120, 520 } }, Dress = "Cracks", Props = { rock = 5, spire = 4 } },
}
local BOTTOM_METRES = 10935 -- the Challenger Deep, shown at the bottom of the Underworld

-- The prop kit's props (art/props/props.json, rebuilt by tools/blender/prop_kit.py): name, category, size in studs at
-- scale 1 (x, y up, z), the zones it suits
-- stylua: ignore
local PROPS: { { any } } = {
	{ "rock_boulder_a_reef", "rock", 8.35, 7.09, 10.55, "Dock|Shallows|Coral Reef|Kelp Forest|Shipwrecks" },
	{ "rock_boulder_b_reef", "rock", 13.27, 5.43, 12.18, "Shallows|Coral Reef|Kelp Forest|Shipwrecks|Open Blue" },
	{ "rock_cluster_reef", "rock", 6.80, 2.69, 5.43, "Shallows|Coral Reef|Kelp Forest|Shipwrecks|Open Blue|Dock" },
	{ "rock_arch_reef", "rock", 30.69, 19.18, 9.18, "Coral Reef|Kelp Forest|Open Blue" },
	{ "rock_slab_stack_reef", "rock", 12.88, 7.69, 10.67, "Shallows|Coral Reef|Shipwrecks|Open Blue" },
	{ "rock_spire_reef", "rock", 9.17, 23.81, 9.80, "Kelp Forest|Shipwrecks|Open Blue" },
	{ "rock_boulder_a_deep", "rock", 8.35, 7.09, 10.55, "Twilight|Midnight|Vents|Bone Graveyard|The Underworld" },
	{ "rock_boulder_b_deep", "rock", 13.27, 5.43, 12.18, "Twilight|Midnight|Vents|Bone Graveyard|The Underworld" },
	{ "rock_cluster_deep", "rock", 6.80, 2.69, 5.43, "Twilight|Midnight|Vents|Bone Graveyard|The Underworld" },
	{ "rock_arch_deep", "rock", 30.69, 19.18, 9.18, "Midnight|Vents|Bone Graveyard" },
	{ "rock_slab_stack_deep", "rock", 12.88, 7.69, 10.67, "Twilight|Midnight|The Underworld" },
	{ "rock_spire_deep", "rock", 9.17, 23.81, 9.80, "Vents|Bone Graveyard|The Underworld" },
	{ "coral_branch_pink", "coral", 4.07, 6.09, 5.20, "Shallows|Coral Reef" },
	{ "coral_brain_pink", "coral", 6.04, 3.46, 5.03, "Shallows|Coral Reef" },
	{ "coral_fan_pink", "coral", 8.90, 7.88, 3.50, "Shallows|Coral Reef" },
	{ "coral_tube_pink", "coral", 4.30, 5.47, 3.74, "Shallows|Coral Reef" },
	{ "coral_table_pink", "coral", 11.16, 4.10, 12.09, "Shallows|Coral Reef|Open Blue" },
	{ "coral_branch_orange", "coral", 4.07, 6.09, 5.20, "Shallows|Coral Reef|Shipwrecks" },
	{ "coral_brain_orange", "coral", 6.04, 3.46, 5.03, "Shallows|Coral Reef|Shipwrecks" },
	{ "coral_fan_orange", "coral", 8.90, 7.88, 3.50, "Shallows|Coral Reef|Shipwrecks" },
	{ "coral_tube_orange", "coral", 4.30, 5.47, 3.74, "Shallows|Coral Reef|Shipwrecks" },
	{ "coral_table_orange", "coral", 11.16, 4.10, 12.09, "Shallows|Coral Reef|Shipwrecks|Open Blue" },
	{ "coral_branch_purple", "coral", 4.07, 6.09, 5.20, "Coral Reef|Shipwrecks|Open Blue|Twilight" },
	{ "coral_brain_purple", "coral", 6.04, 3.46, 5.03, "Coral Reef|Shipwrecks|Open Blue|Twilight" },
	{ "coral_fan_purple", "coral", 8.90, 7.88, 3.50, "Coral Reef|Shipwrecks|Open Blue|Twilight" },
	{ "coral_tube_purple", "coral", 4.30, 5.47, 3.74, "Coral Reef|Shipwrecks|Open Blue|Twilight" },
	{ "coral_table_purple", "coral", 11.16, 4.10, 12.09, "Coral Reef|Shipwrecks|Open Blue|Twilight" },
	{ "kelp_tall", "kelp", 9.09, 41.46, 8.96, "Kelp Forest" },
	{ "kelp_short", "kelp", 6.30, 20.40, 7.20, "Kelp Forest|Coral Reef|Shipwrecks" },
	{ "sea_grass_clump", "kelp", 4.03, 3.39, 4.10, "Dock|Shallows|Coral Reef" },
	{ "sea_grass_patch", "kelp", 4.80, 2.86, 6.89, "Dock|Shallows|Kelp Forest" },
	{ "shell_scallop", "shell", 2.03, 0.54, 1.31, "Dock|Shallows|Coral Reef" },
	{ "shell_conch", "shell", 3.43, 2.07, 2.31, "Shallows|Coral Reef|Shipwrecks" },
	{ "starfish", "shell", 2.48, 0.42, 2.46, "Dock|Shallows|Coral Reef|Shipwrecks" },
	{ "sea_urchin", "shell", 3.43, 2.61, 3.12, "Coral Reef|Kelp Forest|Twilight" },
	{ "crate", "dock", 4.00, 4.00, 4.00, "Dock|Shipwrecks" },
	{ "crate_stack", "dock", 8.39, 7.20, 4.49, "Dock|Shipwrecks" },
	{ "dock_post", "dock", 2.04, 10.00, 2.04, "Dock" },
	{ "buoy", "dock", 3.60, 4.95, 3.60, "Dock" },
	{ "rope_coil", "dock", 3.82, 1.36, 2.63, "Dock|Shipwrecks" },
	{ "barrel", "dock", 2.86, 3.50, 2.86, "Dock|Shipwrecks" },
	{ "lifebuoy", "dock", 3.64, 3.64, 0.73, "Dock" },
}

-- How the dressing uses each group: where across the valley (Band), props per cluster, the scale range, the spread
type Group = { Band: string, Count: { number }, Scale: { number }, Spread: number }
-- stylua: ignore
local GROUPS: { [string]: Group } = {
	grass = { Band = "lane", Count = { 5, 8 }, Scale = { 2, 3.5 }, Spread = 35 },
	coral = { Band = "edge", Count = { 4, 7 }, Scale = { 1.8, 3.2 }, Spread = 40 },
	rock = { Band = "bank", Count = { 3, 5 }, Scale = { 2.5, 5 }, Spread = 45 },
	kelp = { Band = "edge", Count = { 4, 6 }, Scale = { 1.5, 2.6 }, Spread = 40 },
	shell = { Band = "lane", Count = { 3, 5 }, Scale = { 1.5, 2.5 }, Spread = 25 },
	arch = { Band = "centre", Count = { 1, 1 }, Scale = { 2.4, 3.2 }, Spread = 0 },
	spire = { Band = "bank", Count = { 1, 3 }, Scale = { 2, 4 }, Spread = 40 },
	dock = { Band = "lane", Count = { 3, 5 }, Scale = { 1.2, 1.8 }, Spread = 20 },
}

local rng = Random.new(20261109)

---------------------------------------------------------------- helpers
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	props: { [string]: any }?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then -- before Size, so a Shape change doesn't reshape it
		for key, value in props do
			(p :: any)[key] = value
		end
	end
	p.Size = size
	p.CFrame = ORIGIN * cf
	p.Parent = parent
	return p
end

local function comma(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local replaced, count = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
		s = replaced
		if count == 0 then
			return s
		end
	end
end

-- A sign: a board with big text on its front (the board's -Z face, the way its CFrame looks)
local function sign(
	parent: Instance,
	text: string,
	cf: CFrame,
	width: number,
	height: number,
	colour: Color3,
	name: string?
): BasePart
	local board = part(parent, name or "Sign", Vector3.new(width, height, 1), cf, colour)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(width * 25, height * 25)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = board
	return board
end

local function folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	if parent then
		f.Parent = parent
	end
	return f
end

-- A stand-in player: a block figure, PLAYER studs tall, standing on the given point
local function figure(parent: Instance, at: CFrame)
	part(parent, "PlayerScale", Vector3.new(2, PLAYER, 1), at * CFrame.new(0, PLAYER / 2, 0), rgb(240, 200, 60))
end

local function cylinder(
	parent: Instance,
	name: string,
	height: number,
	diameter: number,
	at: CFrame,
	colour: Color3,
	extra: { [string]: any }?
): BasePart
	local props: { [string]: any } = { Shape = Enum.PartType.Cylinder }
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	-- a cylinder's axis is its X: stand it up
	return part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		at * CFrame.Angles(0, 0, math.pi / 2),
		colour,
		props
	)
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- A light shaft from the surface down to a floor point, leaning with the sun
local function lightShaft(anchor: BasePart, top: Vector3, bottom: Vector3, width: number)
	local a0 = Instance.new("Attachment")
	a0.Position = anchor.CFrame:PointToObjectSpace((ORIGIN * CFrame.new(top)).Position)
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Position = anchor.CFrame:PointToObjectSpace((ORIGIN * CFrame.new(bottom)).Position)
	a1.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = width
	beam.Width1 = width * 1.6
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(rgb(255, 255, 240), rgb(180, 240, 255))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.84),
		NumberSequenceKeypoint.new(0.7, 0.92),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Parent = anchor
end

---------------------------------------------------------------- props: placeholder Models for the prop kit's meshes
local propByName: { [string]: { any } } = {}
for _, row in PROPS do
	propByName[row[1]] = row
end

local function groupOf(row: { any }): string
	local name: string = row[1]
	if string.find(name, "^sea_grass") then
		return "grass"
	elseif string.find(name, "^rock_arch") then
		return "arch"
	elseif string.find(name, "^rock_spire") then
		return "spire"
	end
	return row[2]
end

local function suits(row: { any }, label: string): boolean
	for z in string.gmatch(row[6], "[^|]+") do
		if z == label then
			return true
		end
	end
	return false
end

local function propColour(name: string): Color3
	if string.find(name, "_deep$") then
		return rgb(95, 75, 140)
	elseif string.find(name, "^rock") then
		return rgb(125, 140, 155)
	elseif string.find(name, "pink") then
		return rgb(255, 120, 160)
	elseif string.find(name, "orange") then
		return rgb(255, 150, 70)
	elseif string.find(name, "purple") then
		return rgb(170, 100, 230)
	elseif string.find(name, "^kelp") then
		return rgb(70, 150, 70)
	elseif string.find(name, "^sea_grass") then
		return rgb(110, 190, 90)
	elseif name == "starfish" then
		return rgb(255, 130, 60)
	elseif name == "sea_urchin" then
		return rgb(60, 30, 80)
	elseif string.find(name, "^shell") then
		return rgb(245, 215, 185)
	elseif name == "buoy" or name == "lifebuoy" then
		return rgb(235, 60, 50)
	elseif name == "dock_post" or name == "barrel" then
		return rgb(120, 85, 55)
	elseif name == "rope_coil" then
		return rgb(215, 190, 130)
	end
	return rgb(170, 125, 75) -- crates
end

-- A placeholder Model for one prop: pivot at its base (as the kit's meshes), chunky stand-in parts inside
local function prop(parent: Instance, name: string, base: CFrame, scale: number): Model
	local row = propByName[name]
	local size = Vector3.new(row[3], row[4], row[5]) * scale
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("PropName", name)
	m:SetAttribute("PropScale", math.floor(scale * 100 + 0.5) / 100)
	m:SetAttribute("PropSize", size)
	local c = propColour(name)
	local x, y, z = size.X, size.Y, size.Z
	local function block(n: string, s: Vector3, at: CFrame, colour: Color3?)
		part(m, n, s, base * at, colour or c)
	end
	if string.find(name, "^rock_arch") then
		local leg = x * 0.22
		for side = -1, 1, 2 do
			block("Leg", Vector3.new(leg, y * 0.85, z), CFrame.new(side * (x - leg) / 2, y * 0.85 / 2, 0))
		end
		block("Top", Vector3.new(x, y * 0.3, z), CFrame.new(0, y * 0.85, 0))
	elseif string.find(name, "^rock_spire") then
		block("Spire", Vector3.new(x * 0.8, y, z * 0.8), CFrame.new(0, y / 2, 0) * CFrame.Angles(0, 0.4, 0.05))
	elseif string.find(name, "^rock_slab_stack") then
		block("Slab", Vector3.new(x, y * 0.55, z), CFrame.new(0, y * 0.275, 0))
		block(
			"Slab",
			Vector3.new(x * 0.7, y * 0.45, z * 0.7),
			CFrame.new(x * 0.08, y * 0.775, 0) * CFrame.Angles(0, 0.5, 0)
		)
	elseif string.find(name, "^rock") then
		block("Rock", Vector3.new(x, y, z), CFrame.new(0, y / 2, 0) * CFrame.Angles(0.08, 0.3, -0.06))
	elseif string.find(name, "^coral_table") then
		cylinder(m, "Stem", y * 0.7, x * 0.2, base * CFrame.new(0, y * 0.35, 0), c)
		cylinder(m, "Top", y * 0.3, x, base * CFrame.new(0, y * 0.85, 0), c)
	elseif string.find(name, "^coral_fan") then
		block("Fan", Vector3.new(x, y, z * 0.3), CFrame.new(0, y / 2, 0))
	elseif string.find(name, "^coral_brain") then
		block("Brain", Vector3.new(x, y, z), CFrame.new(0, y / 2, 0) * CFrame.Angles(0, 0.6, 0))
	elseif string.find(name, "^coral") then -- branch, tube: two stalks
		block("Stalk", Vector3.new(x * 0.4, y, z * 0.4), CFrame.new(-x * 0.2, y / 2, 0))
		block("Stalk", Vector3.new(x * 0.35, y * 0.7, z * 0.35), CFrame.new(x * 0.25, y * 0.35, z * 0.15))
	elseif string.find(name, "^kelp") then
		block("Stalk", Vector3.new(x * 0.35, y, z * 0.35), CFrame.new(0, y / 2, 0) * CFrame.Angles(0, 0, 0.04))
	elseif name == "buoy" then
		part(m, "Buoy", Vector3.new(x, x, x), base * CFrame.new(0, y / 2, 0), c, { Shape = Enum.PartType.Ball })
	elseif name == "dock_post" or name == "barrel" or name == "rope_coil" then
		cylinder(m, "Body", y, x, base * CFrame.new(0, y / 2, 0), c)
	elseif name == "lifebuoy" then
		part(
			m,
			"Ring",
			Vector3.new(z, x, x),
			base * CFrame.new(0, y / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
			c,
			{ Shape = Enum.PartType.Cylinder }
		)
	else -- grass, shells, crates
		block("Body", Vector3.new(x, y, z), CFrame.new(0, y / 2, 0))
	end
	m.WorldPivot = ORIGIN * base
	m:SetAttribute("PropBase", ORIGIN * base) -- the same, kept where a saved file won't drop it
	m.Parent = parent
	return m
end

---------------------------------------------------------------- the lane's path: where it runs, how deep, how wide
local starts: { number } = {} -- each zone's start along the lane (s = 0 at LANE_START)
local ramps: { number } = {} -- each zone's ramp length
local tops: { number } = {} -- the floor's height where each zone begins (the top of its ramp)
local TOTAL = 0
do
	local y = LAGOON_Y
	for i, zone in ZONES do
		starts[i] = TOTAL
		ramps[i] = if i > 1 then zone.Drop / math.tan(math.rad(RAMP_DEGREES)) else 0
		tops[i] = y
		TOTAL += zone.Length
		y -= zone.Length * math.tan(math.rad(zone.Slope)) + (if i > 1 then zone.Drop else 0)
	end
end

local function zoneAt(s: number): number
	for i = #ZONES, 1, -1 do
		if s >= starts[i] then
			return i
		end
	end
	return 1
end

local function headingAt(s: number): number
	local h = ZONES[1].Heading
	for i = 2, #ZONES do
		h += (ZONES[i].Heading - ZONES[i - 1].Heading) * smooth((s - starts[i] + BEND / 2) / BEND)
	end
	return math.rad(h)
end

local function floorY(s: number): number
	local i = zoneAt(s)
	local zone = ZONES[i]
	local t = s - starts[i]
	local drop = if i > 1 and ramps[i] > 0 then zone.Drop * smooth(t / ramps[i]) else 0
	return tops[i] - t * math.tan(math.rad(zone.Slope)) - drop
end

-- the centreline, integrated along the heading every STEP studs
local STEP = 10
local cx: { number } = {}
local cz: { number } = {}
do
	local x, z = 0, LANE_START
	for k = 0, math.ceil(TOTAL / STEP) + 1 do
		cx[k] = x
		cz[k] = z
		local h = headingAt((k + 0.5) * STEP)
		x += math.sin(h) * STEP
		z += math.cos(h) * STEP
	end
end

local function centre(s: number): Vector3
	s = math.clamp(s, 0, TOTAL + STEP)
	local k = math.floor(s / STEP)
	local f = s / STEP - k
	return Vector3.new(lerp(cx[k], cx[k + 1], f), floorY(s), lerp(cz[k], cz[k + 1], f))
end

local function direction(s: number): Vector3
	local h = headingAt(s)
	return Vector3.new(math.sin(h), 0, math.cos(h))
end

-- across the lane: the same as the X axis of the frames below
local function across(s: number): Vector3
	local h = headingAt(s)
	return Vector3.new(math.cos(h), 0, -math.sin(h))
end

-- A level frame on the centreline: +Z down the lane, +X across it, +Y up
local function pathFrame(s: number): CFrame
	local p = centre(s)
	return CFrame.lookAt(p, p - direction(s))
end

type Shape = { Lane: number, Tiers: { { number } }, Floor: Color3, Rock: Color3 }

local function padded(tiers: { { number } }, count: number): { { number } }
	local out = table.clone(tiers)
	while #out < count do
		table.insert(out, { PAD_TIER, out[#out][2] })
	end
	return out
end

-- The valley's cross-section at s: the zone's own, blended with its neighbour's near a border
local function shapeAt(s: number): Shape
	local i = zoneAt(s)
	local a = ZONES[i]
	local other: Zone? = nil
	local u = 1
	if i > 1 and s < starts[i] + BLEND / 2 then
		other = ZONES[i - 1]
		u = smooth(0.5 + (s - starts[i]) / BLEND)
	elseif i < #ZONES and s > starts[i] + a.Length - BLEND / 2 then
		other = ZONES[i + 1]
		u = smooth(0.5 + (starts[i] + a.Length - s) / BLEND)
	end
	if not other or u >= 1 then
		return { Lane = a.Lane, Tiers = a.Tiers, Floor = a.Floor, Rock = a.Rock }
	end
	local b = other :: Zone
	local n = math.max(#a.Tiers, #b.Tiers)
	local ta, tb = padded(a.Tiers, n), padded(b.Tiers, n)
	local tiers = {}
	for k = 1, n do
		tiers[k] = { lerp(tb[k][1], ta[k][1], u), lerp(tb[k][2], ta[k][2], u) }
	end
	return {
		Lane = lerp(b.Lane, a.Lane, u),
		Tiers = tiers,
		Floor = b.Floor:Lerp(a.Floor, u),
		Rock = b.Rock:Lerp(a.Rock, u),
	}
end

-- The height of the valley's surface above the lane's floor, at distance d from the centreline
local function bankHeight(shape: Shape, d: number): number
	local x0, h0 = shape.Lane / 2, 0
	if d <= x0 then
		return 0
	end
	for _, tier in shape.Tiers do
		local x1, h1 = x0 + tier[1], tier[2]
		if d <= x1 then
			return lerp(h0, h1, (d - x0) / tier[1])
		end
		x0, h0 = x1, h1
	end
	return h0
end

-- A point on the seabed: s along the lane, x across it (the valley's banks included)
local function ground(s: number, x: number): Vector3
	return centre(s) + across(s) * x + Vector3.new(0, bankHeight(shapeAt(s), math.abs(x)), 0)
end

local root = folder("ClaudeBlockout")

---------------------------------------------------------------- the surface: sea tiles and the deep plane
local function buildSurface(): Folder
	local f = folder("Surface") -- tools/studio/depth_look_test.luau restyles the sea tiles for the underwater looks
	local cells: { [string]: Vector2 } = {}
	local function cover(x: number, z: number, reach: number)
		for i = math.floor((x - reach) / TILE + 0.5), math.floor((x + reach) / TILE + 0.5) do
			for j = math.floor((z - reach) / TILE + 0.5), math.floor((z + reach) / TILE + 0.5) do
				cells[i .. "," .. j] = Vector2.new(i, j)
			end
		end
	end
	cover(0, 0, LAGOON_RADIUS + 600)
	for s = 0, TOTAL, PATH_SAMPLE do
		local p = centre(s)
		cover(p.X, p.Z, 900)
	end
	local list = {}
	for _, cell in cells do
		table.insert(list, cell)
	end
	table.sort(list, function(a, b)
		return if a.X == b.X then a.Y < b.Y else a.X < b.X
	end)
	for _, cell in list do
		part(
			f,
			"SeaTile",
			Vector3.new(TILE, 1, TILE),
			CFrame.new(cell.X * TILE, -0.5, cell.Y * TILE),
			rgb(40, 140, 200),
			{ Transparency = 0.35, CanCollide = false, CastShadow = false }
		)
	end
	local deep = folder("DeepPlane", f)
	for x = -1, 1 do
		for z = -1, 0 do
			part(
				deep,
				"Deep",
				Vector3.new(TILE, 4, TILE),
				CFrame.new(x * TILE, DEEP_PLANE_Y - 2, z * TILE + TILE / 2 - 1024),
				rgb(10, 40, 90),
				{ CastShadow = false }
			)
		end
	end
	return f
end

---------------------------------------------------------------- the lagoon and its ring reef
local function buildLagoon(): Folder
	local f = folder("Lagoon")
	local sand = rgb(236, 222, 172)
	local laneHalf = ZONES[1].Lane / 2
	-- the sandy floor: a disc inside the ring reef (the lane's first stretch runs under it and comes out at the ring)
	cylinder(f, "Floor", 4, LAGOON_RADIUS * 2, CFrame.new(0, LAGOON_Y - 2, 0), sand)
	-- the ring reef: rocks and coral heads round the lagoon, some breaking the surface, open toward the dive
	for degrees = -176, 180, 8 do
		if math.abs(degrees) > RING_GAP then
			local a = math.rad(degrees + rng:NextNumber(-2, 2))
			local r = LAGOON_RADIUS + rng:NextNumber(-40, 40)
			local top = if rng:NextNumber() < 0.6 then rng:NextNumber(4, 40) else rng:NextNumber(-12, -3)
			local width = rng:NextNumber(110, 170)
			local face = CFrame.lookAt(Vector3.new(math.sin(a) * r, 0, math.cos(a) * r), Vector3.zero)
				* CFrame.Angles(0, math.rad(rng:NextNumber(-15, 15)), 0)
			local height = top - (LAGOON_Y - 40)
			part(
				f,
				"Reef",
				Vector3.new(width, height, rng:NextNumber(60, 100)),
				face + Vector3.new(0, LAGOON_Y - 40 + height / 2, 0),
				rgb(150, 140, 120)
			)
			if top > 0 then
				part(
					f,
					"Surf",
					Vector3.new(width + 10, 1, 12),
					face * CFrame.new(0, 0.6, 50),
					rgb(255, 255, 255),
					{ Transparency = 0.25, CanCollide = false }
				)
			end
		end
	end
	-- the lagoon's own dressing: sea grass, shells and starfish on the sand
	local dressing = folder("Props", f)
	local grass = { "sea_grass_clump", "sea_grass_patch" }
	local small = { "shell_scallop", "starfish", "rock_cluster_reef", "rock_boulder_a_reef" }
	for n = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(ISLAND_SHELF + 20, LAGOON_RADIUS - 80)
		local at = Vector3.new(math.sin(a) * r, LAGOON_Y, math.cos(a) * r)
		if math.abs(at.X) > laneHalf + 20 or at.Z < LANE_START then
			local name = if n % 3 == 0 then small[rng:NextInteger(1, #small)] else grass[rng:NextInteger(1, 2)]
			prop(
				dressing,
				name,
				CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				rng:NextNumber(2, 3.5)
			)
		end
	end
	return f
end

---------------------------------------------------------------- the island: plaza, plots, stations, pier
local PLOT_COLOURS = {
	rgb(120, 200, 230),
	rgb(240, 160, 90),
	rgb(150, 210, 120),
	rgb(230, 130, 170),
	rgb(170, 140, 230),
	rgb(240, 210, 90),
	rgb(110, 200, 180),
	rgb(230, 110, 100),
}

local function buildPlot(parent: Instance, index: number, degrees: number)
	local a = math.rad(degrees)
	local at = Vector3.new(math.sin(a) * PLOT_RADIUS, DECK_Y, math.cos(a) * PLOT_RADIUS)
	local face = CFrame.lookAt(at, Vector3.new(0, DECK_Y, 0)) -- local -Z toward the plaza: the plot's front
	local f = folder("Plot" .. index, parent)
	f:SetAttribute("PlotIndex", index)
	local colour = PLOT_COLOURS[index]
	local w, d = PLOT_SIZE.X, PLOT_SIZE.Y
	part(f, "Pad", Vector3.new(w, 1, d), face * CFrame.new(0, -0.5, 0), colour:Lerp(rgb(255, 255, 255), 0.45))
	for side = -1, 1, 2 do -- a low kerb round the pad
		part(f, "Kerb", Vector3.new(2, 1.5, d), face * CFrame.new(side * (w / 2 - 1), 0.75, 0), colour)
	end
	part(f, "Kerb", Vector3.new(w, 1.5, 2), face * CFrame.new(0, 0.75, d / 2 - 1), colour)
	-- the show tank at the back
	local tz = d / 2 - TANK_SIZE.Z / 2 - 4
	part(f, "TankBase", Vector3.new(TANK_SIZE.X + 4, 2, TANK_SIZE.Z + 4), face * CFrame.new(0, 1, tz), rgb(70, 70, 80))
	part(
		f,
		"Glass",
		TANK_SIZE,
		face * CFrame.new(0, 2 + TANK_SIZE.Y / 2, tz),
		rgb(190, 230, 255),
		{ Material = Enum.Material.Glass, Transparency = 0.7, CanCollide = false }
	)
	part(
		f,
		"TankWater",
		TANK_SIZE - Vector3.new(1, 3, 1),
		face * CFrame.new(0, 2 + (TANK_SIZE.Y - 3) / 2, tz),
		rgb(40, 140, 220),
		{ Transparency = 0.5, CanCollide = false, CanQuery = false }
	)
	part(
		f,
		"TankSand",
		Vector3.new(TANK_SIZE.X - 1, 1.5, TANK_SIZE.Z - 1),
		face * CFrame.new(0, 2.75, tz),
		rgb(236, 222, 172)
	)
	-- several big fish on show: two shark-sized, three middling
	local fish = {
		{ Vector3.new(6, 9, 23), Vector3.new(-18, 14, -4), rgb(120, 130, 150) },
		{ Vector3.new(6, 9, 23), Vector3.new(14, 22, 6), rgb(120, 130, 150) },
		{ Vector3.new(6, 9, 12), Vector3.new(26, 9, -8), rgb(255, 220, 90) },
		{ Vector3.new(6, 6, 11), Vector3.new(-2, 8, 8), rgb(250, 150, 80) },
		{ Vector3.new(7, 7, 9), Vector3.new(-28, 24, 8), rgb(240, 230, 150) },
	}
	for _, spec in fish do
		part(
			f,
			"ShowFish",
			spec[1],
			face
				* CFrame.new(spec[2].X, 2 + spec[2].Y, tz + spec[2].Z)
				* CFrame.Angles(0, math.rad(90 + rng:NextNumber(-20, 20)), 0),
			spec[3],
			{ CanCollide = false }
		)
	end
	-- the owner's sign above the tank's front
	part(
		f,
		"SignPost",
		Vector3.new(2, 10, 2),
		face * CFrame.new(-22, 2 + TANK_SIZE.Y + 5, tz - TANK_SIZE.Z / 2),
		rgb(90, 70, 55)
	)
	part(
		f,
		"SignPost",
		Vector3.new(2, 10, 2),
		face * CFrame.new(22, 2 + TANK_SIZE.Y + 5, tz - TANK_SIZE.Z / 2),
		rgb(90, 70, 55)
	)
	sign(
		f,
		"PLAYER " .. index,
		face * CFrame.new(0, 2 + TANK_SIZE.Y + 9, tz - TANK_SIZE.Z / 2 - 1.5),
		50,
		9,
		colour,
		"SignBoard"
	)
	-- the kiddie-ride trainer's spot, front left: a pad, the coin box and a toy fish on a spring
	local trainer = face * CFrame.new(-w / 2 + 18, 0, -d / 2 + 18)
	cylinder(f, "TrainerSpot", 1, 20, trainer * CFrame.new(0, 0.5, 0), rgb(255, 230, 120))
	part(f, "TrainerBase", Vector3.new(8, 3, 10), trainer * CFrame.new(0, 2.5, 0), rgb(230, 90, 90))
	part(f, "TrainerSpring", Vector3.new(1, 3, 1), trainer * CFrame.new(0, 5.5, 0), rgb(200, 200, 210))
	part(
		f,
		"TrainerToy",
		Vector3.new(4, 4, 9),
		trainer * CFrame.new(0, 9, 0) * CFrame.Angles(0, math.rad(90), 0),
		rgb(90, 200, 230)
	)
	part(f, "CoinBox", Vector3.new(3, 5, 3), trainer * CFrame.new(7, 3.5, -2), rgb(250, 210, 40))
	-- where the owner collects the tank's earnings, front right
	part(
		f,
		"CollectPad",
		Vector3.new(12, 1, 12),
		face * CFrame.new(w / 2 - 18, 0.5, -d / 2 + 18),
		rgb(90, 230, 120),
		{ Material = Enum.Material.Neon }
	)
	-- the boardwalk from the plaza to the plot's front
	local walk = PLOT_RADIUS - d / 2 - PLAZA_RADIUS + 4
	part(f, "Walk", Vector3.new(18, 1, walk), face * CFrame.new(0, -0.5, -d / 2 - walk / 2 + 2), rgb(160, 120, 80))
end

local function buildDock(): Folder
	local dock = folder("Dock")
	-- the island: a sandy top on a mound that runs out just under the water
	cylinder(
		dock,
		"Shelf",
		ISLAND_TOP - LAGOON_Y - 4,
		ISLAND_SHELF * 2,
		CFrame.new(0, (LAGOON_Y + ISLAND_TOP - 4) / 2, 0),
		rgb(220, 200, 150)
	)
	cylinder(dock, "Island", 4, ISLAND_RADIUS * 2, CFrame.new(0, ISLAND_TOP - 2, 0), rgb(240, 226, 178))
	cylinder(dock, "Plaza", 1, PLAZA_RADIUS * 2, CFrame.new(0, DECK_Y - 0.5, 0), rgb(160, 120, 80))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = ORIGIN * CFrame.new(0, DECK_Y + 0.5, 0)
	spawn.Enabled = false -- a marker only: players keep spawning on the place's own spawn
	spawn.Color = rgb(255, 255, 255)
	spawn.Parent = dock
	figure(dock, CFrame.new(10, DECK_Y, 0))

	local plots = folder("Plots", dock)
	for index, degrees in PLOT_ANGLES do
		buildPlot(plots, index, degrees)
	end

	local function station(name: string, degrees: number, radius: number, size: Vector3, colour: Color3): CFrame
		local a = math.rad(degrees)
		local at = Vector3.new(math.sin(a) * radius, DECK_Y, math.cos(a) * radius)
		local face = CFrame.lookAt(at, Vector3.new(0, DECK_Y, 0))
		local f = folder(name, dock)
		part(f, "Stall", size, face * CFrame.new(0, size.Y / 2, 0), colour)
		sign(f, name, face * CFrame.new(0, size.Y + 4, -size.Z / 2), math.max(size.X, 16), 5, colour)
		return face
	end
	station("SELL", -32, 125, Vector3.new(18, 9, 10), rgb(230, 170, 50))
	station("AURAS", -14, 135, Vector3.new(18, 9, 10), rgb(150, 90, 220))
	station("INDEX", 14, 135, Vector3.new(18, 9, 10), rgb(60, 160, 230))
	station("FUSE", 32, 125, Vector3.new(18, 9, 10), rgb(90, 200, 120))
	station("TOP EARNERS", 180, 60, Vector3.new(30, 18, 2), rgb(30, 30, 40))

	-- palms between the plots, along the rim
	for k = 0, 7 do
		local a = math.rad(PLOT_ANGLES[1] + 18 + k * 36)
		if k < 7 then
			local at = Vector3.new(math.sin(a) * 270, ISLAND_TOP, math.cos(a) * 270)
			local lean = CFrame.new(at)
				* CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), 0, math.rad(rng:NextNumber(-10, 10)))
			part(dock, "PalmTrunk", Vector3.new(3, 34, 3), lean * CFrame.new(0, 17, 0), rgb(140, 100, 60))
			part(
				dock,
				"PalmCrown",
				Vector3.new(22, 4, 22),
				lean * CFrame.new(0, 34, 0) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
				rgb(80, 180, 80)
			)
		end
	end

	-- the pier out to the dive board
	local pierStart = ISLAND_RADIUS - 10
	local pierLength = PIER_END - pierStart
	part(
		dock,
		"Pier",
		Vector3.new(24, 2, pierLength),
		CFrame.new(0, DECK_Y - 1, pierStart + pierLength / 2),
		rgb(160, 120, 80)
	)
	for z = ISLAND_RADIUS + 10, PIER_END, 30 do
		for side = -1, 1, 2 do
			part(
				dock,
				"Stilt",
				Vector3.new(3, DECK_Y - LAGOON_Y, 3),
				CFrame.new(side * 11, (DECK_Y + LAGOON_Y) / 2, z),
				rgb(110, 80, 55)
			)
		end
	end
	local gateZ = 360
	for side = -1, 1, 2 do
		part(dock, "GatePost", Vector3.new(3, 20, 3), CFrame.new(side * 13, DECK_Y + 10, gateZ), rgb(240, 240, 240))
	end
	sign(dock, "DIVE", CFrame.new(0, DECK_Y + 22, gateZ), 30, 6, rgb(230, 60, 60))
	part(
		dock,
		"DiveBoard",
		Vector3.new(6, 1, 20),
		CFrame.new(0, DECK_Y + 3, PIER_END + 8) * CFrame.Angles(math.rad(-8), 0, 0),
		rgb(240, 240, 240)
	)
	figure(dock, CFrame.new(0, DECK_Y + 4, PIER_END + 14))
	part(dock, "SubJetty", Vector3.new(14, 2, 60), CFrame.new(28, DECK_Y - 1, ISLAND_RADIUS + 30), rgb(160, 120, 80))
	part(dock, "Sub", Vector3.new(10, 8, 22), CFrame.new(44, 1, ISLAND_RADIUS + 30), rgb(250, 210, 40))
	sign(dock, "SUB", CFrame.new(28, DECK_Y + 6, ISLAND_RADIUS + 2), 10, 3, rgb(250, 210, 40))

	-- dock props: posts and buoys along the pier, crates, barrels and rope by the jetty and the stations
	local props = folder("Props", dock)
	for z = ISLAND_RADIUS + 25, PIER_END, 45 do
		for side = -1, 1, 2 do
			prop(props, "dock_post", CFrame.new(side * 12, DECK_Y, z), 1)
		end
	end
	for k = 1, 6 do
		local side = if k % 2 == 0 then -1 else 1
		prop(props, "buoy", CFrame.new(side * rng:NextNumber(40, 90), 0, ISLAND_RADIUS + 40 + k * 22), 1.6)
	end
	prop(props, "lifebuoy", CFrame.new(-12.5, DECK_Y + 2, gateZ + 6) * CFrame.Angles(0, math.pi / 2, 0), 1.5)
	prop(props, "lifebuoy", CFrame.new(12.5, DECK_Y + 2, gateZ + 6) * CFrame.Angles(0, math.pi / 2, 0), 1.5)
	local stacks = {
		{ "crate_stack", Vector3.new(30, DECK_Y, ISLAND_RADIUS + 55) },
		{ "crate", Vector3.new(24, DECK_Y, ISLAND_RADIUS + 45) },
		{ "barrel", Vector3.new(33, DECK_Y, ISLAND_RADIUS + 10) },
		{ "rope_coil", Vector3.new(22, DECK_Y, ISLAND_RADIUS + 20) },
		{ "crate_stack", Vector3.new(-60, ISLAND_TOP, 150) },
		{ "barrel", Vector3.new(-50, ISLAND_TOP, 140) },
		{ "barrel", Vector3.new(60, ISLAND_TOP, 150) },
		{ "crate", Vector3.new(68, ISLAND_TOP, 140) },
		{ "rope_coil", Vector3.new(-6, DECK_Y, ISLAND_RADIUS + 70) },
		{ "crate", Vector3.new(-40, ISLAND_TOP, -60) },
		{ "barrel", Vector3.new(40, ISLAND_TOP, -60) },
	}
	for _, spec in stacks do
		prop(props, spec[1], CFrame.new(spec[2]) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), 1.4)
	end
	for _ = 1, 16 do -- starfish and shells on the beach
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(ISLAND_RADIUS - 30, ISLAND_RADIUS - 5)
		local names = { "starfish", "shell_scallop", "shell_conch", "sea_grass_clump" }
		prop(
			props,
			names[rng:NextInteger(1, 4)],
			CFrame.new(math.sin(a) * r, ISLAND_TOP, math.cos(a) * r) * CFrame.Angles(0, a, 0),
			1.6
		)
	end
	return dock
end

---------------------------------------------------------------- the dive
-- The seabed between sa and sb: the floor slab and the banks either side, each a slab tilted from one terrace's edge to the
-- next, so the valley's sides are faceted slopes rather than boxy steps
local function seabed(f: Instance, sa: number, sb: number)
	local pa, pb = centre(sa), centre(sb)
	local mid = (pa + pb) / 2
	local frame = CFrame.lookAt(mid, pb) * CFrame.Angles(0, math.pi, 0) -- +Z down the lane, +X across (as across())
	local length = (pb - pa).Magnitude
	local turn = math.abs(headingAt(sb) - headingAt(sa)) + math.abs(math.atan((pa.Y - pb.Y) / length)) * 0.5
	local shape = shapeAt((sa + sb) / 2)
	local half = shape.Lane / 2
	part(
		f,
		"Seabed",
		Vector3.new(shape.Lane + 8, 6, length + half * turn + 6),
		frame * CFrame.new(0, -3, 0),
		shape.Floor
	)
	-- each bank slab spans its two edges, which run down the lane (pitched) with world-vertical heights between them
	local d = frame.ZVector
	local side0 = frame.XVector
	local x0, h0 = half, 0
	for k, tier in shape.Tiers do
		local x1, h1 = x0 + tier[1], tier[2]
		local colour = shape.Rock:Lerp(Color3.new(1, 1, 1), (k - 1) * 0.08)
		for side = -1, 1, 2 do
			local v = side0 * side * (x1 - x0) + Vector3.new(0, h1 - h0, 0) -- inner edge to outer edge
			local along = v:Dot(d)
			local xAxis = (v - d * along).Unit
			local yAxis = d:Cross(xAxis)
			if yAxis.Y < 0 then
				yAxis = -yAxis
			end
			local centreAt = mid + side0 * side * (x0 + x1) / 2 + Vector3.new(0, (h0 + h1) / 2, 0)
			part(
				f,
				"Bank" .. k,
				Vector3.new((v - d * along).Magnitude + 2, SLAB, length + x1 * turn + math.abs(along) + 6),
				CFrame.fromMatrix(centreAt - yAxis * SLAB / 2, xAxis, yAxis, xAxis:Cross(yAxis)),
				colour
			)
		end
		x0, h0 = x1, h1
	end
end

local function randomS(i: number, margin: number): number
	return rng:NextNumber(starts[i] + margin, starts[i] + ZONES[i].Length - margin)
end

-- A random point across the valley for a band: "lane" the floor, "edge" the lane's sides and the first bank, "bank" the
-- banks, "centre" the middle of the lane
local function bandX(shape: Shape, band: string): number
	local half = shape.Lane / 2
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local first = shape.Tiers[1][1]
	if band == "lane" then
		return rng:NextNumber(-half * 0.9, half * 0.9)
	elseif band == "edge" then
		return side * rng:NextNumber(half * 0.5, half + first * 0.7)
	elseif band == "bank" then
		local reach = first + (if shape.Tiers[2] then shape.Tiers[2][1] * 0.8 else 0)
		return side * rng:NextNumber(half * 0.75, half + reach)
	end
	return rng:NextNumber(-half * 0.1, half * 0.1)
end

-- The zone's props: clusters of the prop kit's props that suit it, per GROUPS
local function dressProps(f: Folder, i: number)
	local zone = ZONES[i]
	local groupNames = {}
	for g in zone.Props do
		table.insert(groupNames, g)
	end
	table.sort(groupNames)
	for _, g in groupNames do
		local group = GROUPS[g]
		local pool = {}
		for _, row in PROPS do
			if groupOf(row) == g and suits(row, zone.Label) then
				table.insert(pool, row[1])
			end
		end
		if #pool > 0 then
			for _ = 1, zone.Props[g] do
				local s = randomS(i, 60)
				local shape = shapeAt(s)
				local x = bandX(shape, group.Band)
				for _ = 1, rng:NextInteger(group.Count[1], group.Count[2]) do
					local ps = s + rng:NextNumber(-group.Spread, group.Spread)
					local px = x + rng:NextNumber(-group.Spread, group.Spread)
					local name = pool[rng:NextInteger(1, #pool)]
					local scale = rng:NextNumber(group.Scale[1], group.Scale[2])
					local yaw = if g == "arch" then 0 else rng:NextNumber(0, math.pi * 2)
					local frame = pathFrame(ps)
					local at = ground(ps, px)
					local sink = propByName[name][4] * scale * 0.12 -- settle into slopes
					prop(
						f,
						name,
						CFrame.new(at - Vector3.new(0, sink, 0)) * (frame - frame.Position) * CFrame.Angles(0, yaw, 0),
						scale
					)
				end
			end
		end
	end
end

-- The zone's own set pieces (v2's, now along the curve)
local function dress(f: Folder, i: number)
	local zone = ZONES[i]
	local function anywhere(margin: number): (Vector3, number)
		local s = randomS(i, 40)
		local half = shapeAt(s).Lane / 2
		return ground(s, rng:NextNumber(-half + margin, half - margin)), s
	end
	local function onBank(): Vector3
		local s = randomS(i, 40)
		local shape = shapeAt(s)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		return ground(s, side * (shape.Lane / 2 + rng:NextNumber(10, shape.Tiers[1][1] - 10)))
	end
	local kind = zone.Dress
	if kind == "Wrecks" then
		for n = 1, 4 do
			local at = if n <= 3 then anywhere(50) else onBank()
			local hull = CFrame.new(at + Vector3.new(0, 8, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-25, 25)))
			part(f, "Hull", Vector3.new(36, 26, 110), hull, rgb(110, 80, 60))
			part(
				f,
				"Mast",
				Vector3.new(3, 70, 3),
				hull * CFrame.new(0, 45, -15) * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), 0, 0),
				rgb(90, 70, 55)
			)
		end
	elseif kind == "Arches" then
		for k = 1, 4 do
			local s = starts[i] + k * zone.Length / 5
			local frame = pathFrame(s)
			local half = shapeAt(s).Lane / 2
			for side = -1, 1, 2 do
				part(f, "ArchLeg", Vector3.new(18, 110, 18), frame * CFrame.new(side * (half - 12), 55, 0), zone.Rock)
			end
			part(f, "ArchTop", Vector3.new(half * 2, 20, 18), frame * CFrame.new(0, 115, 0), zone.Rock)
		end
	elseif kind == "Jellies" then
		for _ = 1, 30 do
			local s = rng:NextNumber(4, 10)
			part(
				f,
				"Jelly",
				Vector3.new(s, s, s),
				CFrame.new(anywhere(10) + Vector3.new(0, rng:NextNumber(20, 150), 0)),
				rgb(80, 240, 255),
				{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Transparency = 0.2 }
			)
		end
	elseif kind == "Chimneys" then
		for n = 1, 14 do
			local at = if n <= 9 then anywhere(20) else onBank()
			local h = rng:NextNumber(30, 90)
			local w = rng:NextNumber(12, 20)
			part(
				f,
				"Chimney",
				Vector3.new(w, h + 10, w),
				CFrame.new(at + Vector3.new(0, h / 2 - 5, 0)),
				rgb(25, 20, 20)
			)
			part(
				f,
				"Glow",
				Vector3.new(w * 0.7, 2, w * 0.7),
				CFrame.new(at + Vector3.new(0, h + 1, 0)),
				rgb(255, 120, 30),
				{ Material = Enum.Material.Neon }
			)
			part(
				f,
				"Smoke",
				Vector3.new(w * 0.8, 80, w * 0.8),
				CFrame.new(at + Vector3.new(0, h + 41, 0)),
				rgb(20, 20, 20),
				{ Transparency = 0.6, CanCollide = false, CastShadow = false }
			)
		end
	elseif kind == "Bones" then
		for _ = 1, 2 do
			local spine = CFrame.new(anywhere(70) + Vector3.new(0, 3, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			part(f, "Spine", Vector3.new(6, 6, 140), spine, rgb(235, 230, 215))
			part(f, "Skull", Vector3.new(26, 14, 34), spine * CFrame.new(0, 4, -82), rgb(235, 230, 215))
			for k = -5, 5 do
				for side = -1, 1, 2 do
					part(
						f,
						"Rib",
						Vector3.new(3, 40, 3),
						spine * CFrame.new(side * 10, 16, k * 11) * CFrame.Angles(0, 0, math.rad(side * -30)),
						rgb(235, 230, 215)
					)
				end
			end
		end
	elseif kind == "Cracks" then
		-- glowing red cracks running up the steep banks
		for _ = 1, 24 do
			local s = randomS(i, 40)
			local shape = shapeAt(s)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local w1, h1 = shape.Tiers[1][1], shape.Tiers[1][2]
			local d = rng:NextNumber(0.15, 0.85)
			local at = ground(s, side * (shape.Lane / 2 + w1 * d))
			local angle = math.atan2(h1, w1)
			local frame = pathFrame(s)
			part(
				f,
				"Crack",
				Vector3.new(rng:NextNumber(20, 60), 1, rng:NextNumber(2, 5)),
				CFrame.new(at)
					* (frame - frame.Position)
					* CFrame.Angles(0, 0, side * angle)
					* CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0),
				rgb(255, 50, 40),
				{ Material = Enum.Material.Neon }
			)
		end
		-- the Megalodon at the end, coming up the trench toward the rider
		local endS = starts[i] + zone.Length
		local meg = pathFrame(endS - 140) * CFrame.new(0, 45, 0) -- its front (-Z) up the lane
		part(f, "Megalodon", Vector3.new(18, 16, 64), meg, rgb(70, 75, 90))
		part(f, "Fin", Vector3.new(2, 16, 14), meg * CFrame.new(0, 15, 4), rgb(70, 75, 90))
		part(f, "Tail", Vector3.new(2, 24, 10), meg * CFrame.new(0, 0, 36), rgb(70, 75, 90))
		-- the end of the dive: the trench closes in a wall, the Megalodon's lair
		local width = zone.Lane
		for _, tier in zone.Tiers do
			width += tier[1] * 2
		end
		part(f, "EndWall", Vector3.new(width + 200, 900, 20), pathFrame(endS) * CFrame.new(0, 400, 10), zone.Rock)
	end
end

-- Huge shapes far off in the open water either side: what makes the ocean feel big, seen through the haze
local function silhouettes(f: Folder, i: number)
	local zone = ZONES[i]
	local count = if i == 1 then 2 else 4
	for n = 1, count do
		local side = if n % 2 == 0 then -1 else 1
		local s = randomS(i, 0)
		local base = centre(s) + across(s) * side * rng:NextNumber(700, 1400)
		if zone.Name == "OPEN BLUE" then -- whales cruising far off
			local body = CFrame.new(base + Vector3.new(0, rng:NextNumber(120, 300), 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			part(f, "Whale", Vector3.new(50, 44, 190), body, rgb(60, 80, 110))
			part(f, "Fluke", Vector3.new(70, 6, 26), body * CFrame.new(0, 0, 110), rgb(60, 80, 110))
		elseif zone.Name == "KELP FOREST" then -- giant kelp towers
			local h = rng:NextNumber(300, 520)
			part(
				f,
				"KelpTower",
				Vector3.new(30, h, 30),
				CFrame.new(base + Vector3.new(0, h / 2 - 40, 0)),
				rgb(60, 120, 60)
			)
		else -- seamounts and rock towers
			local h = rng:NextNumber(250, 650)
			local w = rng:NextNumber(120, 260)
			part(
				f,
				"Seamount",
				Vector3.new(w, h, w * rng:NextNumber(0.6, 1.2)),
				CFrame.new(base + Vector3.new(0, h / 2 - 150, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				zone.Rock:Lerp(Color3.new(0, 0, 0), 0.25)
			)
		end
	end
end

local function nearBorder(s: number): boolean
	for i = 2, #ZONES do
		if math.abs(s - starts[i]) < BEND / 2 or (s >= starts[i] and s < starts[i] + ramps[i]) then
			return true
		end
	end
	return false
end

local function buildZone(index: number, dive: Folder): Folder
	local zone = ZONES[index]
	local s0, s1 = starts[index], starts[index] + zone.Length
	local f = folder(string.format("%02d_%s", index, zone.Name))
	f:SetAttribute("ZoneName", zone.Name)
	f:SetAttribute("Metres", zone.Metres)

	-- the marker the game code reads: the straight chord from the zone's start to its end, invisible
	local a, b = centre(s0), centre(s1)
	local chordMid = (a + b) / 2
	part(
		f,
		"Floor",
		Vector3.new(zone.Lane, 1, (b - a).Magnitude),
		CFrame.lookAt(chordMid, chordMid - (b - a).Unit) * CFrame.new(0, -0.5, 0),
		zone.Floor,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
	)

	-- the seabed, segment by segment along the curve
	local bed = folder("Seabed", f)
	local s = s0
	while s < s1 - 0.5 do
		local step = if nearBorder(s) then SEG_FINE else SEG
		local nextS = math.min(s + step, s1)
		if s1 - nextS < step * 0.4 then -- no sliver at the zone's end
			nextS = s1
		end
		seabed(bed, s, nextS)
		s = nextS
	end

	-- the gate and sign at the foot of the zone's ramp, with the depth the gauge would show
	local gs = s0 + ramps[index] + 40
	local gate = pathFrame(gs)
	local half = shapeAt(gs).Lane / 2
	for side = -1, 1, 2 do
		part(f, "GatePost", Vector3.new(8, 70, 8), gate * CFrame.new(side * (half - 6), 35, 0), rgb(240, 240, 240))
	end
	part(f, "GateBar", Vector3.new(half * 2, 8, 8), gate * CFrame.new(0, 70, 0), rgb(240, 240, 240))
	sign(
		f,
		string.format("%s  %s m", zone.Name, comma(zone.Metres)),
		gate * CFrame.new(0, 57, 0), -- the front (-Z) faces the rider coming down the lane
		math.min(half * 2 - 20, 90),
		14,
		zone.Rock
	)

	local props = folder("Props", f)
	dressProps(props, index)
	local set = folder("SetPieces", f)
	dress(set, index)
	silhouettes(set, index)

	-- light shafts from the surface, only where it's still shallow
	if zone.Metres < 40 then
		local anchor = part(
			set,
			"ShaftAnchor",
			Vector3.new(1, 1, 1),
			CFrame.new(centre((s0 + s1) / 2)),
			rgb(255, 255, 255),
			{ Transparency = 1, CanCollide = false }
		)
		for _ = 1, 8 do
			local bs = randomS(index, 0)
			local bottom = ground(bs, rng:NextNumber(-half, half))
			lightShaft(anchor, bottom + Vector3.new(-40, -bottom.Y, -90), bottom, rng:NextNumber(20, 45))
		end
	end

	if index == 1 then -- the rider at the start of the dive, on a starter creature, to show scale
		local start = pathFrame(60) * CFrame.new(0, 20, 0)
		part(f, "StarterCreature", Vector3.new(4, 3, 9), start, rgb(250, 150, 80))
		figure(f, start * CFrame.new(0, 1.5, 0))
	end
	f.Parent = dive
	return f
end

---------------------------------------------------------------- build
local old = workspace:FindFirstChild("ClaudeBlockout")
if old then
	old:Destroy()
end
root.Parent = workspace
buildSurface().Parent = root
task.wait()
buildLagoon().Parent = root
buildDock().Parent = root
task.wait()

local dive = folder("Dive", root)
local info = {}
for index, zone in ZONES do
	buildZone(index, dive)
	local s0, s1 = starts[index], starts[index] + zone.Length
	local a, b = centre(s0), centre(s1)
	table.insert(info, {
		Name = zone.Name,
		Metres = zone.Metres,
		Z0 = LANE_START + s0, -- along the lane from the island (v2: along +Z), for tools/art/depth_profile.py
		Z1 = LANE_START + s1,
		Y0 = a.Y,
		Y1 = b.Y,
		Start = { a.X, a.Z },
		End = { b.X, b.Z },
		Heading = zone.Heading,
		Ramp = ramps[index],
	})
	task.wait()
end

local path = {}
for s = 0, TOTAL, PATH_SAMPLE do
	local p = (ORIGIN * CFrame.new(centre(s))).Position
	local function r1(v: number): number
		return math.floor(v * 10 + 0.5) / 10
	end
	table.insert(path, { r1(s), r1(p.X), r1(p.Y), r1(p.Z), r1(shapeAt(s).Lane) })
end
dive:SetAttribute("Path", HttpService:JSONEncode(path))

local count, models = 0, 0
local byFolder = {}
for _, child in root:GetChildren() do
	local n = 0
	for _, d in child:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	byFolder[child.Name] = n
	count += n
end
for _, d in root:GetDescendants() do
	if d:IsA("Model") and d:GetAttribute("PropName") then
		models += 1
	end
end
return HttpService:JSONEncode({
	Version = 3,
	Parts = count,
	PartsByFolder = byFolder,
	PropModels = models,
	BottomMetres = BOTTOM_METRES,
	Origin = { 3000, 0, 0 },
	LaneStart = LANE_START,
	Zones = info,
	Path = path,
})
