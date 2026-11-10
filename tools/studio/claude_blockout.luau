--!strict
-- Claude's blockout of Ride a Fish (docs/blockout.md). v4, 2026-11-09, from the user's feedback on v3:
-- * The island is a half circle with its flat side to the dive. The spawn is near that edge, a short walk from the dive
--   board, and the shops and stations stand on the dock's wings to either side. The dock is wider than v3's pier, not
--   longer. The big plots and tanks are kept from v3, in an arc round the curved side.
-- * Each zone has its own signature formation the lane runs past or through: the reef gate, coral arches, a kelp
--   cathedral of pillars, a hull you ride through, sea stacks, a glowing canyon with overhangs, a long cave, a chimney
--   field, a leviathan's ribcage and the throat at the bottom.
-- * The lane is lined with the prop kit's matching cluster presets (art/props/props.json "clusters"), composed in a rhythm
--   rather than scattered: huge ones flank the formations, medium and small ones alternate sides in between.
-- * The look (after Subnautica's): each zone carries a fog colour, a view distance, ambient light and a glow colour, for a
--   client controller to blend by depth with classic fog (tools/studio/depth_look_test.luau, workout 1); light shafts in
--   the sunlit zones; glowing plants and lights deeper down.
-- Props are placeholder Models (attributes PropName, PropScale, PropSize, PropBase) and clusters are Models of them
-- (ClusterName, ClusterScale, ClusterBase), so the imported meshes swap in 1:1. Formations are Models with a "Formation"
-- attribute. v3 and v2 are in git history.
--
-- Run in Edit mode through the Studio connector, or offline in Lune (docs/blockout.md, "Building offline").
-- Rebuilds Workspace.ClaudeBlockout; touches nothing else. Returns the zones, the looks and the lane's path as JSON
-- (tools/art/map_plot.py draws the top and side views from it).
-- Axes: the sea surface is y = 0; the island's flat edge is on z = 0, its curved side toward -Z; the dive leaves along +Z,
-- then bends toward +X.
-- For the game code (src/shared/Zones.luau, Lane.luau): Dive.<NN_NAME>.Floor is an invisible marker per zone, the straight
-- chord from the zone's start to its end; the Dive folder's "Path" attribute is the exact centreline as JSON,
-- { s, x, y, z, w, c } every PATH_SAMPLE studs in world space, where c is the clearance above the floor under a formation
-- (an arch, a cave roof, a ribcage; 0 where the water is open), and "Looks" holds each zone's look from where it starts.

local HttpService = game:GetService("HttpService")

local ORIGIN = CFrame.new(3000, 0, 0) -- off the baseplate, which would hide everything under the sea
local PLAYER = 5 -- a player is about 5 studs tall
local TILE = 2048 -- the largest a part can be

-- the island: a half circle, its flat edge on z = 0 facing the dive
local DECK_Y = 4 -- top of the dock, the boardwalks and the plot pads
local ISLAND_RADIUS = 410 -- the sandy top
local ISLAND_SHELF = 460 -- the mound under it, just under the water
local ISLAND_TOP = 3
local SPAWN = Vector3.new(0, DECK_Y, -40) -- near the flat edge, facing the dive
local PLAZA = Vector2.new(240, 90) -- the boardwalk round the spawn: width, depth (from the dock back)
local PLOT_RADIUS = 345 -- from the island's centre to the middle of a plot
local PLOT_ANGLES = { 110, 130, 150, 170, 190, 210, 230, 250 } -- degrees from +Z, round the curved side
local PLOT_SIZE = Vector2.new(100, 84) -- width, depth (v3's)
local TANK_SIZE = Vector3.new(76, 30, 40) -- room for several big fish (the Reef Shark is 12 x 9 x 23)
local DOCK = { HalfWidth = 300, Back = -20, Front = 50 } -- the dock along the flat edge: wide, not long
local GATE_Z = 40
local BOARD_Z = 60 -- the dive board's middle; it reaches out to about z = 71
-- (2026-11-10: -30 to -39. The Shallows' floor is a stud above this; at -29 a jump off a fish had only 13 studs to rise
-- before the surface, and it wants 21: src/shared/Config.luau, Jump.Apex and Config.herdTop)
local LAGOON_Y = -39 -- the lagoon's sandy floor round the island
local LAGOON_RADIUS = 950 -- the ring reef round the lagoon
local RING_GAP = 25 -- degrees either side of +Z left open where the dive leaves the lagoon
local DEEP_PLANE_Y = -300 -- under the open sea near the island, so it reads deep blue from above

-- the dive
local LANE_START = 85 -- along +Z, where the lane begins, just past the dive board
local BEND = 900 -- the bend between two zones' headings, centred on the border
local BLEND = 600 -- widths, heights and colours blend over this much either side of a border
local RAMP_DEGREES = 35 -- a zone's drop-off is a ramp this steep on average
local SEG = 300 -- the seabed's segment length on the straights
local SEG_FINE = 150 -- and in the bends and on the ramps
local SLAB = 40 -- the banks' thickness
local PATH_SAMPLE = 100
local PAD_TIER = 60 -- a flat shelf added when blending into a zone with more terraces
local LINE_SPACING = 190 -- the lane's lining: a cluster about this often, alternating sides

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function hex(h: string): Color3
	return Color3.fromRGB(
		tonumber(h:sub(2, 3), 16) or 0,
		tonumber(h:sub(4, 5), 16) or 0,
		tonumber(h:sub(6, 7), 16) or 0
	)
end

-- A zone's look under water (classic fog, no Atmosphere): what everything fades to and how far, the light, a tint for a
-- ColorCorrection, and the colour of its glowing life (nil where nothing glows)
type Look = {
	Fog: Color3,
	FogEnd: number,
	Ambient: Color3,
	Outdoor: Color3,
	Brightness: number,
	Tint: Color3,
	Glow: Color3?,
}

type Zone = {
	Name: string,
	Label: string, -- the name props.json uses
	Family: string, -- the cluster family (props.json zonePalette)
	Metres: number, -- the real-ocean depth the gauge shows where the zone begins
	Length: number, -- along the lane
	Heading: number, -- degrees from +Z toward +X, on the zone's straight
	Slope: number, -- degrees down inside the zone
	Flat: number?, -- studs at the zone's start that stay level (the lagoon)
	Drop: number, -- the ramp down at the zone's start
	Lane: number, -- the lane's width
	Floor: Color3,
	Rock: Color3,
	Tiers: { { number } }, -- banks stepping out from the lane: { width, height above the floor at its outer edge }
	Signature: string, -- the zone's own formation (see SIGNATURES)
	Look: Look,
}

-- stylua: ignore
local ZONES: { Zone } = {
	{ Name = "SHALLOWS", Label = "Shallows", Family = "lagoon", Metres = 0, Length = 1000, Heading = 0, Slope = 1.5, Flat = 860, Drop = 0, Lane = 260, Floor = rgb(236, 222, 172), Rock = rgb(214, 196, 150), Tiers = { { 120, 8 }, { 200, 20 } }, Signature = "ReefGate",
		Look = { Fog = rgb(64, 200, 205), FogEnd = 1000, Ambient = rgb(110, 170, 170), Outdoor = rgb(130, 195, 195), Brightness = 2, Tint = rgb(235, 255, 250) } },
	{ Name = "CORAL REEF", Label = "Coral Reef", Family = "reef", Metres = 10, Length = 2500, Heading = 20, Slope = 2, Drop = 45, Lane = 220, Floor = rgb(226, 205, 150), Rock = rgb(235, 140, 150), Tiers = { { 80, 30 }, { 140, 50 }, { 220, 68 } }, Signature = "CoralArches",
		Look = { Fog = rgb(40, 170, 200), FogEnd = 900, Ambient = rgb(90, 150, 165), Outdoor = rgb(110, 175, 190), Brightness = 1.8, Tint = rgb(230, 250, 255) } },
	{ Name = "KELP FOREST", Label = "Kelp Forest", Family = "kelp", Metres = 40, Length = 2500, Heading = 40, Slope = 2, Drop = 40, Lane = 240, Floor = rgb(110, 115, 80), Rock = rgb(90, 120, 100), Tiers = { { 100, 60 }, { 160, 140 }, { 240, 240 } }, Signature = "KelpCathedral",
		Look = { Fog = rgb(50, 140, 110), FogEnd = 550, Ambient = rgb(70, 120, 90), Outdoor = rgb(90, 140, 105), Brightness = 1.4, Tint = rgb(225, 255, 215), Glow = hex("#FFE66B") } },
	{ Name = "SHIPWRECKS", Label = "Shipwrecks", Family = "wreck", Metres = 80, Length = 2500, Heading = 55, Slope = 2, Drop = 40, Lane = 260, Floor = rgb(150, 140, 120), Rock = rgb(120, 110, 100), Tiers = { { 120, 50 }, { 180, 120 } }, Signature = "BrokenHull",
		Look = { Fog = rgb(35, 105, 120), FogEnd = 500, Ambient = rgb(55, 95, 105), Outdoor = rgb(70, 110, 120), Brightness = 1.1, Tint = rgb(215, 240, 240) } },
	{ Name = "OPEN BLUE", Label = "Open Blue", Family = "wreck", Metres = 150, Length = 2500, Heading = 40, Slope = 2, Drop = 150, Lane = 400, Floor = rgb(80, 110, 150), Rock = rgb(70, 100, 140), Tiers = { { 200, 25 } }, Signature = "SeaStacks",
		Look = { Fog = rgb(20, 85, 170), FogEnd = 750, Ambient = rgb(45, 80, 140), Outdoor = rgb(55, 95, 160), Brightness = 1, Tint = rgb(210, 230, 255) } },
	{ Name = "TWILIGHT", Label = "Twilight", Family = "twilight", Metres = 200, Length = 2500, Heading = 55, Slope = 2, Drop = 80, Lane = 200, Floor = rgb(60, 60, 100), Rock = rgb(55, 50, 95), Tiers = { { 60, 150 }, { 140, 260 }, { 240, 380 } }, Signature = "GlowCanyon",
		Look = { Fog = rgb(20, 30, 95), FogEnd = 420, Ambient = rgb(35, 40, 100), Outdoor = rgb(40, 45, 110), Brightness = 0.5, Tint = rgb(200, 210, 255), Glow = hex("#5FF0E0") } },
	{ Name = "MIDNIGHT", Label = "Midnight", Family = "twilight", Metres = 1000, Length = 2500, Heading = 40, Slope = 2, Drop = 80, Lane = 240, Floor = rgb(35, 35, 60), Rock = rgb(30, 30, 55), Tiers = { { 120, 70 }, { 200, 160 } }, Signature = "LongCave",
		Look = { Fog = rgb(6, 10, 35), FogEnd = 300, Ambient = rgb(20, 25, 60), Outdoor = rgb(20, 25, 60), Brightness = 0.15, Tint = rgb(180, 200, 255), Glow = hex("#5FF0E0") } },
	{ Name = "VENTS", Label = "Vents", Family = "vents", Metres = 2000, Length = 2500, Heading = 25, Slope = 2, Drop = 80, Lane = 220, Floor = rgb(40, 32, 32), Rock = rgb(30, 25, 25), Tiers = { { 90, 80 }, { 150, 180 }, { 240, 300 } }, Signature = "ChimneyField",
		Look = { Fog = rgb(30, 14, 18), FogEnd = 300, Ambient = rgb(60, 30, 30), Outdoor = rgb(50, 25, 25), Brightness = 0.1, Tint = rgb(255, 215, 195), Glow = hex("#FF8A3D") } },
	{ Name = "BONE GRAVEYARD", Label = "Bone Graveyard", Family = "bones", Metres = 4000, Length = 2500, Heading = 40, Slope = 2, Drop = 80, Lane = 320, Floor = rgb(70, 70, 80), Rock = rgb(60, 60, 70), Tiers = { { 160, 40 }, { 260, 90 } }, Signature = "Leviathan",
		Look = { Fog = rgb(14, 22, 36), FogEnd = 320, Ambient = rgb(40, 45, 70), Outdoor = rgb(35, 40, 60), Brightness = 0.1, Tint = rgb(225, 215, 255), Glow = hex("#FF6FD8") } },
	{ Name = "THE UNDERWORLD", Label = "The Underworld", Family = "vents", Metres = 6000, Length = 2500, Heading = 55, Slope = 2, Drop = 200, Lane = 140, Floor = rgb(30, 20, 30), Rock = rgb(25, 15, 25), Tiers = { { 60, 260 }, { 120, 520 } }, Signature = "Throat",
		Look = { Fog = rgb(28, 4, 8), FogEnd = 250, Ambient = rgb(60, 15, 20), Outdoor = rgb(50, 10, 15), Brightness = 0.05, Tint = rgb(255, 200, 200), Glow = hex("#FF3A2A") } },
}
local BOTTOM_METRES = 10935 -- the Challenger Deep, shown at the bottom of the Underworld

-- The prop kit's props and cluster presets, copied from art/props/props.json (tools/blender/prop_kit.py rebuilds that;
-- copy these again when it changes). PROPS: name = { category, size x, y (up), z in studs at scale 1, and for a glowing
-- prop its glow colour and the glow part's size and centre from the base }. CLUSTERS: name = pieces { prop, x, y, z from
-- the cluster's origin on the floor, yaw in degrees, scale }; a cluster's front (-Z) faces the lane.

-- stylua: ignore
local PROPS: { [string]: { any } } = {
	rock_boulder_a_reef = { "rock", 8.35, 7.09, 10.55 },
	rock_boulder_b_reef = { "rock", 13.27, 5.43, 12.18 },
	rock_cluster_reef = { "rock", 6.8, 2.69, 5.43 },
	rock_arch_reef = { "rock", 30.69, 19.18, 9.18 },
	rock_slab_stack_reef = { "rock", 12.88, 7.69, 10.67 },
	rock_spire_reef = { "rock", 9.17, 23.81, 9.8 },
	rock_boulder_a_deep = { "rock", 8.35, 7.09, 10.55 },
	rock_boulder_b_deep = { "rock", 13.27, 5.43, 12.18 },
	rock_cluster_deep = { "rock", 6.8, 2.69, 5.43 },
	rock_arch_deep = { "rock", 30.69, 19.18, 9.18 },
	rock_slab_stack_deep = { "rock", 12.88, 7.69, 10.67 },
	rock_spire_deep = { "rock", 9.17, 23.81, 9.8 },
	coral_branch_pink = { "coral", 4.07, 6.09, 5.2 },
	coral_brain_pink = { "coral", 6.04, 3.46, 5.03 },
	coral_fan_pink = { "coral", 8.9, 7.88, 3.5 },
	coral_tube_pink = { "coral", 4.3, 5.47, 3.74 },
	coral_table_pink = { "coral", 11.16, 4.1, 12.09 },
	coral_branch_orange = { "coral", 4.07, 6.09, 5.2 },
	coral_brain_orange = { "coral", 6.04, 3.46, 5.03 },
	coral_fan_orange = { "coral", 8.9, 7.88, 3.5 },
	coral_tube_orange = { "coral", 4.3, 5.47, 3.74 },
	coral_table_orange = { "coral", 11.16, 4.1, 12.09 },
	coral_branch_purple = { "coral", 4.07, 6.09, 5.2 },
	coral_brain_purple = { "coral", 6.04, 3.46, 5.03 },
	coral_fan_purple = { "coral", 8.9, 7.88, 3.5 },
	coral_tube_purple = { "coral", 4.3, 5.47, 3.74 },
	coral_table_purple = { "coral", 11.16, 4.1, 12.09 },
	kelp_tall = { "kelp", 9.09, 41.46, 8.96 },
	kelp_short = { "kelp", 6.3, 20.4, 7.2 },
	sea_grass_clump = { "kelp", 4.03, 3.39, 4.1 },
	sea_grass_patch = { "kelp", 4.8, 2.86, 6.89 },
	shell_scallop = { "shell", 2.03, 0.54, 1.31 },
	shell_conch = { "shell", 3.43, 2.07, 2.31 },
	starfish = { "shell", 2.48, 0.42, 2.46 },
	sea_urchin = { "shell", 3.43, 2.61, 3.12 },
	crate = { "dock", 4, 4, 4 },
	crate_stack = { "dock", 8.39, 7.2, 4.49 },
	dock_post = { "dock", 2.04, 10, 2.04 },
	buoy = { "dock", 3.6, 4.95, 3.6 },
	rope_coil = { "dock", 3.82, 1.36, 2.63 },
	barrel = { "dock", 2.86, 3.5, 2.86 },
	lifebuoy = { "dock", 3.64, 3.64, 0.73 },
	rock_mesa_reef = { "rock", 25.43, 10.92, 17.98 },
	rock_pillar_reef = { "rock", 14.38, 22.19, 13.55 },
	rock_wall_reef = { "rock", 35.88, 18.44, 12.18 },
	rock_mesa_deep = { "rock", 25.43, 10.92, 17.98 },
	rock_pillar_deep = { "rock", 14.38, 22.19, 13.55 },
	rock_wall_deep = { "rock", 35.88, 18.44, 12.18 },
	rock_mesa_vent = { "rock", 25.43, 10.92, 17.98 },
	rock_pillar_vent = { "rock", 14.38, 22.19, 13.55 },
	rock_wall_vent = { "rock", 35.88, 18.44, 12.18 },
	coral_pillar_pink = { "coral", 7.02, 18.92, 5.3 },
	coral_mushroom_pink = { "coral", 19.57, 13.66, 17.88 },
	coral_pillar_orange = { "coral", 7.02, 18.92, 5.3 },
	coral_mushroom_orange = { "coral", 19.57, 13.66, 17.88 },
	coral_pillar_purple = { "coral", 7.02, 18.92, 5.3 },
	coral_mushroom_purple = { "coral", 19.57, 13.66, 17.88 },
	coral_pillar_teal = { "coral", 7.02, 18.92, 5.3, "#5FF0E0", 6.41, 14.09, 4.46, -0.22, 11.88, -0.08 },
	coral_mushroom_teal = { "coral", 19.57, 13.66, 17.88, "#5FF0E0", 19.57, 10.75, 17.88, -2.66, 7.84, 2.14 },
	plant_fan_green = { "plant", 9.42, 7.17, 9.87 },
	plant_fan_red = { "plant", 9.42, 7.17, 9.87 },
	plant_fan_teal = { "plant", 8.13, 7.17, 8.5, "#5FF0E0", 9.42, 3.21, 9.87, 0.16, 5.56, 0.51 },
	kelp_vine_tall = { "kelp", 10.36, 48.16, 10.48, "#FFE66B", 4.18, 9.77, 3.42, 0.65, 35.27, 0.41 },
	kelp_vine_short = { "kelp", 10.53, 25.19, 9.68, "#FFE66B", 3.09, 5.22, 2.14, 0.22, 14.99, 1.57 },
	plant_bulb_glow_cyan = { "glow", 4.16, 8.7, 4.35, "#5FF0E0", 3.98, 5.07, 4.03, -0.62, 7.43, 0.24 },
	plant_bulb_glow_pink = { "glow", 4.17, 8.7, 4.94, "#FF6FD8", 3.83, 6.43, 4.77, -0.19, 6.83, 0.17 },
	plant_glow_shroom_cyan = { "glow", 4.64, 3.96, 4.16, "#5FF0E0", 5.33, 2.56, 4.67, 0.1, 2.68, -0.09 },
	plant_glow_shroom_yellow = { "glow", 5.26, 4.46, 3.75, "#FFE66B", 5.96, 3.24, 4.42, 0.09, 2.84, 0.05 },
	vent_chimney = { "landmark", 9.87, 13.2, 6.9, "#FF8A3D", 8.26, 12, 5.63, -0.01, 7.2, 0.15 },
	bone_ribs = { "landmark", 29.1, 20.48, 17.14 },
	floor_sand_grass = { "floor", 19.14, 3.79, 15.71 },
	floor_glow_grass = { "floor", 18.9, 2.87, 13.74, "#5FF0E0", 11.95, 2.25, 7.52, 1.3, 2.56, 1.06 },
	floor_vent_ash = { "floor", 22.44, 2.92, 15.36, "#FF8A3D", 15.54, 2.04, 7.06, 0.58, 2.73, -0.11 },
}

-- stylua: ignore
local CLUSTERS: { [string]: { { any } } } = {
	cluster_lagoon_small = { { "floor_sand_grass", -0.83, -0.11, -0.49, 352, 1.07 }, { "rock_mesa_reef", 4.45, -0.41, 1.9, 176, 0.83 }, { "coral_brain_orange", -7.77, -0.15, -3.71, 193, 1.01 }, { "coral_branch_pink", -10.59, -0.13, 2.6, 6, 0.85 }, { "shell_scallop", -5.41, -0.13, 2.53, 237, 0.88 }, { "sea_grass_patch", -0.37, -0.14, -6.98, 43, 0.94 }, { "starfish", -5.4, -0.14, -3.72, 172, 0.94 }, { "sea_grass_patch", -2.63, -0.17, 5.97, 81, 1.16 }, { "sea_grass_patch", -5.2, -0.14, -6.01, 288, 0.92 }, },
	cluster_lagoon_medium = { { "floor_sand_grass", -5.55, -0.15, -2.16, 219, 1.49 }, { "floor_sand_grass", 13.28, -0.13, -6.25, 332, 1.32 }, { "rock_mesa_reef", -5.23, -0.68, 11.11, 311, 1.35 }, { "rock_boulder_a_reef", -23, -0.71, 4.54, 144, 1.42 }, { "coral_brain_orange", 14.92, -0.18, 8.98, 335, 1.23 }, { "coral_brain_orange", 22.41, -0.16, 8.27, 42, 1.04 }, { "coral_brain_orange", -10.71, -0.16, -0.1, 26, 1.04 }, { "coral_brain_orange", 1.65, -0.18, -2.28, 44, 1.19 }, { "coral_brain_pink", -16.64, -0.18, -7.48, 236, 1.18 }, { "sea_grass_patch", -2.91, -0.19, -3.99, 333, 1.25 }, { "starfish", -11.88, -0.16, 2.67, 260, 1.05 }, { "sea_grass_clump", 23.62, -0.18, -5.68, 77, 1.21 }, { "sea_grass_clump", 24.27, -0.2, -0.46, 132, 1.35 }, { "shell_conch", 2.37, -0.16, 6.61, 324, 1.06 }, { "starfish", 10.03, -0.19, 1.42, 331, 1.25 }, { "shell_scallop", 3.44, -0.17, -11.65, 182, 1.15 }, { "rock_cluster_reef", -17.73, -0.68, 6.39, 61, 1.37 }, { "sea_grass_clump", 21.88, -0.18, -7.11, 127, 1.21 }, { "sea_grass_clump", 6.76, -0.19, -13.77, 298, 1.25 }, },
	cluster_lagoon_huge = { { "floor_sand_grass", -9.23, -0.2, -5.86, 36, 2.01 }, { "floor_sand_grass", 39.15, -0.22, -5.3, 109, 2.23 }, { "floor_sand_grass", 9.1, -0.18, -27.27, 347, 1.82 }, { "floor_sand_grass", 30.75, -0.2, -14.21, 241, 1.95 }, { "rock_mesa_reef", 16.6, -1.26, 11.21, 193, 2.52 }, { "rock_boulder_a_reef", 48.98, -1.22, 4.93, 207, 2.44 }, { "rock_boulder_a_reef", -11.26, -1.27, 28.86, 304, 2.53 }, { "coral_mushroom_pink", -56.33, -0.33, 3.05, 19, 2.2 }, { "coral_branch_pink", -29.29, -0.21, 17.9, 212, 1.42 }, { "rock_boulder_b_reef", 37.7, -0.75, -10.15, 283, 1.5 }, { "coral_brain_orange", 20.62, -0.26, -13.85, 288, 1.71 }, { "coral_brain_orange", -30.21, -0.25, -9.5, 98, 1.69 }, { "rock_boulder_b_reef", -35.33, -0.66, 3.23, 109, 1.32 }, { "plant_fan_red", -3.51, -0.24, -7.27, 323, 1.6 }, { "coral_branch_pink", -8.59, -0.2, 13.14, 176, 1.34 }, { "coral_brain_orange", -38.04, -0.23, -16.3, 112, 1.54 }, { "coral_branch_pink", -45.65, -0.29, -8.88, 277, 1.93 }, { "plant_fan_red", -19.39, -0.23, 7.42, 256, 1.54 }, { "shell_scallop", 33.54, -0.22, 13.89, 111, 1.5 }, { "shell_conch", -5.92, -0.22, 21.25, 70, 1.5 }, { "sea_grass_patch", -25.31, -0.21, 18.88, 341, 1.4 }, { "sea_grass_patch", 9.21, -0.2, -20.34, 90, 1.31 }, { "shell_scallop", -26.64, -0.22, -15.29, 195, 1.5 }, { "starfish", 26.34, -0.22, -10.59, 101, 1.5 }, { "sea_grass_patch", -16.2, -0.21, -14.02, 279, 1.4 }, { "rock_cluster_reef", -38.95, -0.68, -10.34, 310, 1.37 }, { "shell_scallop", 31.72, -0.22, 24.62, 226, 1.5 }, { "shell_scallop", -4.2, -0.19, -29.56, 125, 1.28 }, { "rock_cluster_reef", 38.94, -0.64, 13.3, 221, 1.29 }, { "starfish", -12.98, -0.2, -14.09, 140, 1.36 }, { "shell_scallop", -4.57, -0.22, 2.05, 272, 1.44 }, { "starfish", -8.42, -0.22, -0.78, 239, 1.5 }, { "rock_cluster_reef", 51.94, -0.78, -10.21, 295, 1.56 }, { "sea_grass_patch", -51.81, -0.21, -14.15, 285, 1.4 }, { "rock_cluster_reef", 27.03, -0.73, -23.77, 168, 1.47 }, { "sea_grass_patch", 3.62, -0.21, -5.54, 244, 1.4 }, },
	cluster_reef_small = { { "floor_sand_grass", 3.18, -0.12, 0.21, 323, 1.15 }, { "coral_mushroom_pink", -2.42, -0.15, 2.56, 96, 0.97 }, { "coral_fan_purple", -11.03, -0.15, -2.17, 338, 1.02 }, { "coral_brain_orange", 6.4, -0.16, 4.04, 47, 1.04 }, { "sea_grass_clump", 2.42, -0.13, -4.15, 154, 0.85 }, { "sea_urchin", -7.97, -0.14, -0.11, 255, 0.95 }, { "coral_branch_pink", -1.48, -0.15, -4.11, 100, 0.97 }, { "sea_grass_clump", 3.85, -0.17, -0.2, 195, 1.12 }, { "sea_urchin", -5.05, -0.13, -5.3, 203, 0.89 }, },
	cluster_reef_medium = { { "floor_sand_grass", -2.35, -0.14, 0.94, 53, 1.45 }, { "floor_sand_grass", 24.1, -0.13, 7.02, 33, 1.31 }, { "coral_mushroom_pink", 7.22, -0.2, 5.22, 266, 1.31 }, { "coral_pillar_orange", -10.7, -0.21, 11.84, 214, 1.37 }, { "coral_fan_purple", 21.55, -0.21, -7.7, 87, 1.37 }, { "plant_fan_red", -5.47, -0.21, 5.39, 134, 1.37 }, { "coral_brain_orange", -16.34, -0.19, 0, 181, 1.26 }, { "plant_fan_red", 16.34, -0.15, -3.11, 275, 1 }, { "coral_fan_pink", 26.18, -0.16, 2.58, 242, 1.05 }, { "coral_brain_pink", -4.69, -0.19, -6.26, 197, 1.28 }, { "sea_urchin", 14.82, -0.18, 4.39, 338, 1.17 }, { "sea_urchin", -8, -0.16, 0.7, 229, 1.08 }, { "sea_grass_clump", 1.39, -0.15, -0.48, 214, 1.01 }, { "rock_cluster_reef", -1.43, -0.65, 9.93, 275, 1.3 }, { "rock_cluster_reef", -10.57, -0.57, 6.34, 160, 1.14 }, { "coral_brain_pink", 12.51, -0.19, -11.41, 172, 1.24 }, { "rock_cluster_reef", -8.12, -0.52, -3.74, 311, 1.04 }, { "coral_branch_pink", -21.36, -0.18, -3.14, 347, 1.23 }, { "rock_cluster_reef", -13.87, -0.55, -12.76, 212, 1.09 }, },
	cluster_reef_huge = { { "floor_sand_grass", -4.38, -0.22, 6.13, 53, 2.2 }, { "floor_sand_grass", 15.34, -0.19, 12.69, 229, 1.86 }, { "floor_sand_grass", -53.91, -0.19, -12.76, 29, 1.88 }, { "floor_sand_grass", 12.15, -0.22, -24.78, 357, 2.17 }, { "coral_mushroom_pink", -1, -0.33, 13.08, 269, 2.2 }, { "rock_mesa_reef", 46.37, -1.34, 15.99, 4, 2.67 }, { "coral_mushroom_purple", -40.81, -0.33, 17.26, 114, 2.2 }, { "coral_fan_pink", -1.68, -0.29, -5.57, 338, 1.91 }, { "coral_tube_pink", -9.48, -0.23, -4.15, 123, 1.56 }, { "coral_branch_orange", 48.89, -0.25, -15.35, 232, 1.65 }, { "coral_fan_purple", 1.47, -0.29, -15.57, 190, 1.94 }, { "coral_tube_pink", -42.58, -0.22, -9.14, 55, 1.46 }, { "coral_brain_orange", -28.55, -0.25, -7.5, 270, 1.68 }, { "plant_fan_red", -48.7, -0.24, -15.39, 203, 1.6 }, { "coral_brain_orange", -19.03, -0.2, 21.36, 336, 1.33 }, { "coral_fan_purple", 19.06, -0.24, -3.27, 106, 1.61 }, { "plant_fan_red", 10.41, -0.24, 28.61, 39, 1.6 }, { "starfish", 3.19, -0.22, 1.77, 55, 1.5 }, { "coral_branch_pink", -23, -0.25, -26.82, 1, 1.67 }, { "rock_cluster_reef", -12.19, -0.68, 20.15, 161, 1.35 }, { "sea_grass_clump", 10.8, -0.2, 5.62, 36, 1.34 }, { "rock_cluster_reef", 12.73, -0.87, -28.13, 35, 1.73 }, { "sea_grass_clump", -44.94, -0.21, 5.77, 211, 1.4 }, { "coral_brain_pink", -34.46, -0.26, -13.47, 238, 1.75 }, { "rock_cluster_reef", -20.87, -0.87, -14.2, 292, 1.74 }, { "sea_grass_clump", -28.28, -0.21, 5.6, 136, 1.4 }, { "sea_grass_clump", 38.36, -0.21, -22.9, 55, 1.4 }, { "coral_brain_pink", -30.95, -0.21, -19.73, 142, 1.39 }, { "sea_urchin", -46.47, -0.22, -8.9, 237, 1.5 }, { "coral_brain_pink", -15.87, -0.26, 27.74, 147, 1.71 }, { "coral_branch_pink", -6.56, -0.23, -29.68, 215, 1.53 }, { "coral_brain_pink", 4.04, -0.18, -2.5, 317, 1.21 }, { "coral_brain_pink", -1.87, -0.2, 25.63, 237, 1.31 }, { "starfish", -22.64, -0.22, 24.18, 18, 1.5 }, { "coral_brain_pink", -20.2, -0.25, 5.45, 346, 1.65 }, },
	cluster_kelp_small = { { "floor_sand_grass", -2.85, -0.1, 0.82, 265, 1 }, { "kelp_vine_tall", -0.57, -0.13, 5.65, 2, 0.86 }, { "rock_mesa_reef", 9.49, -0.52, -1.44, 151, 1.03 }, { "plant_fan_green", -8.62, -0.13, 3.78, 30, 0.88 }, { "plant_fan_green", 0.37, -0.14, -5.69, 22, 0.94 }, { "rock_cluster_reef", 1.48, -0.43, 1.98, 13, 0.85 }, { "sea_grass_clump", 3.15, -0.13, 6.25, 126, 0.85 }, { "rock_cluster_reef", -9.25, -0.54, -0.53, 215, 1.07 }, { "sea_grass_patch", -4.97, -0.16, 1.74, 336, 1.05 }, },
	cluster_kelp_medium = { { "floor_sand_grass", -3.2, -0.13, -0.23, 222, 1.33 }, { "floor_sand_grass", 3.53, -0.13, 12.1, 0, 1.34 }, { "kelp_vine_tall", 0.92, -0.19, 5.28, 111, 1.29 }, { "kelp_vine_tall", 6.57, -0.2, 13.99, 171, 1.36 }, { "kelp_short", -6.85, -0.18, 8.94, 32, 1.19 }, { "kelp_short", 26.22, -0.17, 1.95, 86, 1.16 }, { "rock_mesa_reef", -18.15, -0.59, -2.05, 206, 1.18 }, { "kelp_short", 18.12, -0.18, -3.77, 98, 1.2 }, { "kelp_vine_short", -5.66, -0.16, -1, 336, 1.08 }, { "sea_urchin", -13.65, -0.16, -8.44, 325, 1.05 }, { "sea_urchin", 11.42, -0.16, 11.61, 328, 1.1 }, { "plant_fan_green", 1.98, -0.16, -10.78, 334, 1.04 }, { "sea_grass_clump", 12.68, -0.19, -0.76, 53, 1.28 }, { "sea_grass_patch", -3.92, -0.18, -7.54, 338, 1.17 }, { "sea_grass_patch", 12.8, -0.18, -8.44, 118, 1.2 }, { "rock_cluster_reef", -15.54, -0.53, 5.8, 242, 1.07 }, { "sea_grass_clump", 9.15, -0.19, -2.12, 68, 1.28 }, { "plant_fan_green", 10.44, -0.16, 8.39, 344, 1.04 }, { "plant_fan_green", 17.47, -0.18, -10.41, 133, 1.18 }, },
	cluster_kelp_huge = { { "floor_sand_grass", -13.58, -0.2, 7.27, 34, 1.98 }, { "floor_sand_grass", -45.41, -0.19, 17.77, 308, 1.95 }, { "floor_sand_grass", 33.94, -0.19, 21.97, 343, 1.93 }, { "floor_sand_grass", 7.81, -0.22, -24.88, 78, 2.24 }, { "kelp_vine_tall", 11.43, -0.21, 18.56, 82, 1.4 }, { "rock_pillar_reef", -47.58, -0.92, 17.76, 197, 1.84 }, { "kelp_vine_tall", -13.27, -0.21, 20.04, 116, 1.4 }, { "kelp_vine_tall", -16.94, -0.21, 6.9, 318, 1.4 }, { "rock_boulder_a_reef", 6.46, -0.82, -1.62, 274, 1.63 }, { "plant_fan_green", 37.5, -0.24, 20.61, 8, 1.6 }, { "kelp_vine_short", 8.44, -0.2, -15.78, 215, 1.31 }, { "rock_mesa_reef", -35.66, -0.91, -4.58, 99, 1.83 }, { "kelp_short", -11.82, -0.21, 28.01, 107, 1.4 }, { "kelp_vine_short", 17.94, -0.21, 1.46, 121, 1.4 }, { "rock_mesa_reef", 39.2, -0.76, -2.11, 226, 1.51 }, { "kelp_vine_short", 25.82, -0.21, -10.99, 302, 1.4 }, { "kelp_short", 29.13, -0.21, 20.9, 141, 1.4 }, { "plant_fan_green", -22.37, -0.24, 24.88, 229, 1.6 }, { "plant_fan_green", -51.65, -0.22, -9.81, 52, 1.46 }, { "rock_cluster_reef", 25.51, -0.67, -26.73, 205, 1.35 }, { "sea_urchin", -3.68, -0.19, -23.93, 360, 1.25 }, { "sea_grass_patch", -57.83, -0.21, 4.36, 334, 1.4 }, { "sea_grass_clump", -17.34, -0.21, -8.86, 349, 1.4 }, { "plant_fan_green", 21, -0.22, 7.44, 260, 1.46 }, { "plant_fan_green", -28.13, -0.24, 8.61, 356, 1.6 }, { "plant_fan_green", -37.05, -0.22, -21.69, 144, 1.45 }, { "sea_urchin", -49.21, -0.22, 8.66, 133, 1.5 }, { "plant_fan_green", -47.82, -0.21, -17.1, 11, 1.39 }, { "rock_cluster_reef", 5.47, -0.82, 13.62, 167, 1.65 }, { "plant_fan_green", -24.99, -0.24, -21.49, 59, 1.59 }, { "sea_urchin", -5.83, -0.22, 2.2, 287, 1.5 }, { "sea_grass_patch", -11.75, -0.2, -26.34, 118, 1.35 }, { "rock_cluster_reef", -52.88, -0.62, 9.21, 229, 1.23 }, { "plant_fan_green", 24.72, -0.24, 0.84, 318, 1.6 }, { "rock_cluster_reef", 51.92, -0.76, 4.23, 68, 1.51 }, { "sea_grass_clump", -22.15, -0.2, -27.71, 351, 1.35 }, },
	cluster_wreck_small = { { "floor_sand_grass", -0.39, -0.11, 0.58, 149, 1.06 }, { "rock_wall_reef", 3.51, -0.5, 5.85, 1, 1 }, { "barrel", -8.25, -0.13, 3.99, 205, 0.88 }, { "crate_stack", -11.19, -0.15, -2.3, 30, 1 }, { "crate", 8.48, -0.15, -4.41, 344, 1 }, { "rock_cluster_reef", 12.35, -0.48, -0.48, 100, 0.97 }, { "crate", 8.36, -0.15, -2.31, 78, 1 }, { "crate", 3.1, -0.12, -6.5, 304, 0.82 }, { "crate", -9.89, -0.15, 0.9, 243, 1 }, },
	cluster_wreck_medium = { { "floor_sand_grass", 4.42, -0.14, 2.9, 321, 1.42 }, { "floor_sand_grass", 19.54, -0.15, 8.68, 327, 1.55 }, { "rock_wall_reef", 6.47, -0.68, 5.3, -4, 1.35 }, { "rock_spire_reef", -22.95, -0.66, 4.41, 247, 1.31 }, { "coral_pillar_purple", -15.32, -0.21, 0.4, 2, 1.39 }, { "coral_pillar_purple", -19.2, -0.2, -8.01, 243, 1.32 }, { "rock_slab_stack_reef", -14.95, -0.52, 7.67, 71, 1.05 }, { "kelp_vine_short", 25.86, -0.19, -2.11, 42, 1.28 }, { "barrel", -26.1, -0.15, 0.36, 46, 1 }, { "shell_conch", -5.02, -0.18, -4.28, 322, 1.23 }, { "coral_tube_purple", 21.47, -0.18, -2.67, 72, 1.23 }, { "shell_conch", -5.65, -0.2, 10.58, 357, 1.33 }, { "sea_grass_clump", -17, -0.18, -10.69, 249, 1.2 }, { "crate", -2.83, -0.15, -11.02, 332, 1 }, { "coral_tube_purple", 20.46, -0.19, 2.5, 340, 1.24 }, { "sea_grass_clump", -8.58, -0.15, -11.62, 288, 1.02 }, { "rock_cluster_reef", 24.68, -0.52, 4.04, 19, 1.05 }, { "coral_tube_purple", -3.1, -0.2, -8.57, 150, 1.32 }, { "rock_cluster_reef", 11.91, -0.51, -9.3, 181, 1.02 }, },
	cluster_wreck_huge = { { "floor_sand_grass", -13.79, -0.2, -3.4, 97, 2.02 }, { "floor_sand_grass", -17.61, -0.22, 18.81, 14, 2.24 }, { "floor_sand_grass", 40.72, -0.2, 4.41, 341, 1.99 }, { "floor_sand_grass", -15.11, -0.22, 1.99, 338, 2.18 }, { "rock_wall_reef", 14.49, -1.11, 10.63, -15, 2.22 }, { "rock_wall_reef", -57.42, -1.27, 7.34, -12, 2.55 }, { "rock_spire_reef", -20.46, -0.85, 25.83, 101, 1.7 }, { "kelp_vine_short", -13.89, -0.2, 14.41, 200, 1.34 }, { "plant_fan_red", -23.56, -0.24, -7.75, 124, 1.6 }, { "barrel", -13.63, -0.15, -12.66, 142, 1 }, { "coral_fan_orange", -21.69, -0.21, 5.52, 182, 1.38 }, { "plant_fan_red", 44.87, -0.24, -2.04, 285, 1.6 }, { "rock_slab_stack_reef", 45.58, -0.82, 16.34, 54, 1.65 }, { "plant_fan_red", 56, -0.24, -0.88, 286, 1.6 }, { "coral_pillar_purple", 28.14, -0.27, -14.55, 104, 1.77 }, { "plant_fan_red", -8.33, -0.24, 29.17, 126, 1.6 }, { "barrel", 17.42, -0.15, -14.12, 50, 1 }, { "coral_tube_purple", 38.77, -0.2, 14.7, 266, 1.34 }, { "sea_grass_clump", 45.16, -0.21, -18.74, 342, 1.4 }, { "shell_conch", 0.98, -0.22, -21.85, 56, 1.5 }, { "rock_cluster_reef", -18.59, -0.6, -5.62, 255, 1.21 }, { "rock_cluster_reef", -3.76, -0.61, 0.9, 141, 1.22 }, { "shell_conch", -20.14, -0.22, -16.47, 211, 1.5 }, { "shell_conch", 51.55, -0.22, 13.56, 260, 1.5 }, { "coral_tube_purple", -12.71, -0.25, -26.95, 66, 1.68 }, { "rock_cluster_reef", -1.63, -0.8, -19.17, 197, 1.6 }, { "crate", -31.01, -0.15, -9.02, 97, 1 }, { "coral_tube_purple", -1.42, -0.21, -7.2, 281, 1.43 }, { "sea_grass_clump", -10.04, -0.21, 4.7, 191, 1.4 }, { "coral_tube_purple", -14.05, -0.24, -0.65, 146, 1.6 }, { "rock_cluster_reef", 57.61, -0.83, 6.96, 325, 1.67 }, { "rock_cluster_reef", 41.2, -0.87, -14.89, 298, 1.73 }, { "shell_conch", -27.01, -0.22, -26.1, 336, 1.5 }, { "sea_grass_clump", 37.36, -0.21, -8.31, 104, 1.4 }, { "coral_tube_purple", -15.12, -0.21, 8.31, 232, 1.39 }, },
	cluster_twilight_small = { { "floor_glow_grass", 2.28, -0.1, -1.62, 304, 1.03 }, { "coral_pillar_teal", -1, -0.12, 5.42, 22, 0.83 }, { "rock_slab_stack_deep", -3.29, -0.5, -2.12, 134, 1 }, { "rock_slab_stack_deep", 5.5, -0.46, 6.25, 22, 0.91 }, { "plant_glow_shroom_cyan", -0.35, -0.14, 2.58, 77, 0.91 }, { "plant_bulb_glow_pink", -7.75, -0.12, 0.68, 112, 0.82 }, { "rock_cluster_deep", 9.11, -0.49, 1.67, 90, 0.98 }, { "sea_urchin", -9.2, -0.13, 3.37, 347, 0.85 }, { "plant_bulb_glow_pink", -3.18, -0.13, 4.69, 206, 0.86 }, },
	cluster_twilight_medium = { { "floor_glow_grass", -4.79, -0.13, 0.59, 8, 1.34 }, { "floor_glow_grass", -0.86, -0.15, -8.77, 161, 1.48 }, { "coral_pillar_teal", 1.36, -0.21, 5.06, 358, 1.42 }, { "coral_pillar_teal", 23.01, -0.18, 2.67, 29, 1.22 }, { "plant_glow_shroom_cyan", -6.81, -0.2, -0.88, 260, 1.34 }, { "plant_fan_teal", 20.96, -0.18, -3.55, 16, 1.22 }, { "plant_glow_shroom_cyan", 9.61, -0.17, -5.37, 298, 1.16 }, { "rock_boulder_a_deep", -15.16, -0.6, -3.79, 357, 1.2 }, { "plant_glow_shroom_cyan", -21.25, -0.21, 8.67, 31, 1.38 }, { "plant_glow_shroom_cyan", 12.24, -0.19, 10.41, 159, 1.28 }, { "plant_bulb_glow_pink", -17.38, -0.18, 8.59, 196, 1.22 }, { "sea_urchin", 16.36, -0.16, -3.06, 125, 1.05 }, { "plant_glow_shroom_cyan", -0.88, -0.2, 10.31, 180, 1.33 }, { "plant_glow_shroom_cyan", -15.61, -0.2, 4.62, 274, 1.35 }, { "sea_urchin", -6.75, -0.15, -10.19, 191, 1.01 }, { "rock_cluster_deep", -12.89, -0.54, 2.29, 111, 1.08 }, { "plant_glow_shroom_cyan", -15.85, -0.16, -11.95, 313, 1.1 }, { "plant_bulb_glow_pink", 7.02, -0.16, 9.39, 69, 1.05 }, { "rock_cluster_deep", 14.23, -0.61, -9.62, 102, 1.22 }, },
	cluster_twilight_huge = { { "floor_glow_grass", 10.38, -0.21, 3.51, 307, 2.07 }, { "floor_glow_grass", -17.43, -0.22, 12.05, 92, 2.16 }, { "floor_glow_grass", 4.08, -0.22, -13.97, 262, 2.24 }, { "floor_glow_grass", 34.01, -0.2, -9.33, 86, 2.02 }, { "coral_pillar_teal", -18.34, -0.33, 12.83, 279, 2.2 }, { "coral_mushroom_teal", 27.57, -0.31, 25.03, 178, 2.1 }, { "rock_mesa_deep", -57.36, -1.1, 4.53, 61, 2.2 }, { "coral_mushroom_teal", 3.45, -0.33, 4.67, 120, 2.2 }, { "plant_fan_teal", 34.37, -0.24, 4.28, 168, 1.58 }, { "plant_bulb_glow_cyan", 12.49, -0.24, -7.52, 58, 1.6 }, { "plant_glow_shroom_cyan", 32.48, -0.24, -5.92, 227, 1.6 }, { "rock_boulder_a_deep", 53.21, -0.75, -8.61, 240, 1.5 }, { "plant_bulb_glow_cyan", 29.86, -0.24, -14.37, 299, 1.58 }, { "rock_slab_stack_deep", 18.19, -0.69, -16.23, 232, 1.38 }, { "plant_glow_shroom_cyan", -36.95, -0.24, -7.13, 307, 1.6 }, { "coral_pillar_teal", 18.78, -0.2, 12.28, 147, 1.35 }, { "plant_bulb_glow_cyan", -44.07, -0.24, -11.38, 180, 1.6 }, { "rock_slab_stack_deep", -22.96, -0.96, -8.85, 341, 1.91 }, { "sea_urchin", 8.21, -0.22, -17.2, 11, 1.5 }, { "plant_glow_shroom_cyan", 6.96, -0.19, -14.95, 119, 1.3 }, { "sea_urchin", 41.72, -0.22, -1.17, 353, 1.5 }, { "plant_glow_shroom_cyan", -31.56, -0.24, -8.48, 98, 1.57 }, { "sea_urchin", 40.65, -0.2, -15.93, 27, 1.31 }, { "rock_cluster_deep", -31.39, -0.81, 7.48, 228, 1.62 }, { "sea_urchin", 41.93, -0.22, -12.01, 350, 1.5 }, { "plant_bulb_glow_pink", -31.2, -0.24, 17.02, 352, 1.6 }, { "sea_urchin", 13.02, -0.2, 0.1, 308, 1.34 }, { "rock_cluster_deep", 46.58, -0.73, 9.82, 83, 1.45 }, { "rock_cluster_deep", -42.42, -0.64, 19.31, 192, 1.29 }, { "plant_bulb_glow_pink", 49.54, -0.23, -16.88, 25, 1.54 }, { "rock_cluster_deep", -40.59, -0.67, -19.7, 149, 1.35 }, { "sea_urchin", 44.25, -0.22, -12.26, 14, 1.5 }, { "rock_cluster_deep", 9.11, -0.75, 22.64, 139, 1.5 }, { "plant_glow_shroom_cyan", 10.27, -0.21, 27.12, 304, 1.43 }, { "rock_cluster_deep", 44.12, -0.84, 1.7, 315, 1.69 }, { "plant_bulb_glow_pink", 16.26, -0.2, -25.75, 213, 1.36 }, },
	cluster_vents_small = { { "floor_vent_ash", -0.91, -0.12, 0.6, 291, 1.2 }, { "vent_chimney", -3.22, -0.13, 2.88, 288, 0.87 }, { "plant_glow_shroom_yellow", 7.68, -0.13, 3.3, 186, 0.87 }, { "vent_chimney", 11.77, -0.14, 0, 278, 0.91 }, { "rock_cluster_deep", -5.81, -0.52, -1.22, 30, 1.03 }, { "rock_cluster_deep", -7.48, -0.44, 4.31, 149, 0.88 }, { "rock_cluster_deep", -1.78, -0.57, -2.31, 34, 1.13 }, { "rock_cluster_deep", 4.67, -0.49, -0.94, 256, 0.98 }, { "rock_cluster_deep", 7.53, -0.47, -3.26, 273, 0.94 }, },
	cluster_vents_medium = { { "floor_vent_ash", -3.69, -0.13, -2.26, 346, 1.33 }, { "floor_vent_ash", 18.05, -0.15, 1.06, 72, 1.45 }, { "vent_chimney", -7.74, -0.2, 3.11, 9, 1.32 }, { "rock_wall_vent", 19.47, -0.72, 6.51, 19, 1.44 }, { "vent_chimney", -1.94, -0.17, 14.33, 233, 1.11 }, { "plant_glow_shroom_yellow", -15.26, -0.18, 9.56, 181, 1.23 }, { "rock_mesa_vent", -26.63, -0.56, -3.29, 343, 1.11 }, { "rock_boulder_a_deep", 0.37, -0.56, -5.22, 309, 1.13 }, { "plant_glow_shroom_yellow", -17.65, -0.19, 3.9, 296, 1.27 }, { "plant_glow_shroom_yellow", -10.49, -0.19, 8.34, 172, 1.25 }, { "plant_glow_shroom_yellow", -4.3, -0.17, -3.21, 220, 1.15 }, { "sea_urchin", 0.5, -0.21, 10.12, 156, 1.38 }, { "plant_bulb_glow_pink", -1.15, -0.21, -13.63, 277, 1.4 }, { "rock_cluster_deep", -17.49, -0.56, -2.9, 287, 1.11 }, { "rock_cluster_deep", -19.74, -0.7, -8.35, 143, 1.39 }, { "sea_urchin", -2.61, -0.18, 6.59, 67, 1.2 }, { "sea_urchin", 23.21, -0.19, -7.55, 67, 1.29 }, { "rock_cluster_deep", 13.6, -0.5, -8.82, 223, 1.01 }, },
	cluster_vents_huge = { { "floor_vent_ash", 8.72, -0.19, -0.97, 261, 1.85 }, { "floor_vent_ash", 3.38, -0.22, 20.24, 202, 2.23 }, { "floor_vent_ash", -14.04, -0.21, -12.29, 52, 2.09 }, { "floor_vent_ash", -9.41, -0.21, 10.17, 96, 2.12 }, { "vent_chimney", 18.2, -0.33, 11.11, 63, 2.22 }, { "vent_chimney", -5.82, -0.39, 20.47, 290, 2.63 }, { "vent_chimney", 59.11, -0.41, 5.07, 23, 2.76 }, { "rock_wall_vent", -43.51, -0.97, 19.17, -14, 1.94 }, { "plant_glow_shroom_yellow", -28.87, -0.23, -4.76, 260, 1.52 }, { "rock_boulder_a_deep", 35.52, -0.9, -6.22, 315, 1.8 }, { "rock_boulder_a_deep", 2.19, -0.93, -5.02, 207, 1.85 }, { "rock_mesa_vent", 34.94, -0.81, 21.9, 307, 1.63 }, { "rock_mesa_vent", -50.07, -0.88, -14.43, 211, 1.75 }, { "vent_chimney", 15.51, -0.22, -4.92, 87, 1.49 }, { "vent_chimney", 7.06, -0.25, 23.79, 122, 1.64 }, { "rock_mesa_vent", -15.03, -0.9, -16.28, 153, 1.8 }, { "rock_boulder_a_deep", 48.93, -0.96, -11.86, 86, 1.92 }, { "rock_boulder_a_deep", 45.01, -0.81, 7.43, 30, 1.63 }, { "plant_bulb_glow_pink", 54.27, -0.22, -5.21, 38, 1.48 }, { "rock_cluster_deep", 4.61, -0.63, 1.91, 213, 1.27 }, { "rock_cluster_deep", 19.94, -0.74, -18.25, 134, 1.48 }, { "rock_cluster_deep", 9.3, -0.65, -26.52, 138, 1.3 }, { "rock_cluster_deep", -41.78, -0.62, -4.33, 92, 1.25 }, { "plant_bulb_glow_pink", -58.93, -0.24, -2.17, 181, 1.6 }, { "plant_glow_shroom_yellow", -48.34, -0.24, 0.51, 40, 1.6 }, { "plant_bulb_glow_pink", 11.64, -0.19, 20.74, 308, 1.25 }, { "rock_cluster_deep", -33.22, -0.85, -10.46, 31, 1.69 }, { "plant_bulb_glow_pink", -30.74, -0.19, 3.12, 39, 1.29 }, { "plant_bulb_glow_pink", -3.93, -0.19, 5.15, 308, 1.3 }, { "plant_bulb_glow_pink", 22.56, -0.24, 22.09, 214, 1.6 }, { "plant_bulb_glow_pink", -22.01, -0.18, 0.95, 167, 1.21 }, { "sea_urchin", -19.75, -0.19, -1.61, 174, 1.26 }, { "sea_urchin", 25.85, -0.22, -8.97, 13, 1.5 }, { "plant_bulb_glow_pink", 24.43, -0.23, 13.44, 317, 1.53 }, { "plant_glow_shroom_yellow", -39.05, -0.19, 1.94, 309, 1.24 }, { "plant_bulb_glow_pink", 10.49, -0.21, 6.06, 10, 1.37 }, },
	cluster_bones_small = { { "floor_glow_grass", -2.34, -0.11, -1.17, 4, 1.11 }, { "bone_ribs", -0.25, -0.14, 3.02, 86, 0.95 }, { "plant_fan_teal", 10.71, -0.13, 3.38, 86, 0.85 }, { "coral_pillar_teal", -11.18, -0.12, 2.35, 245, 0.82 }, { "rock_boulder_a_deep", 9.01, -0.48, -2.09, 179, 0.96 }, { "plant_glow_shroom_cyan", -8.22, -0.13, -1.84, 202, 0.85 }, { "plant_glow_shroom_cyan", -1, -0.15, -5.22, 44, 1.03 }, { "rock_cluster_deep", 4.89, -0.59, -3.91, 301, 1.19 }, { "plant_bulb_glow_pink", 12.85, -0.13, -0.91, 255, 0.85 }, },
	cluster_bones_medium = { { "floor_glow_grass", 4.99, -0.15, -1.58, 337, 1.5 }, { "floor_glow_grass", -18.55, -0.15, 4.54, 18, 1.5 }, { "bone_ribs", -5.4, -0.22, 6.49, 125, 1.5 }, { "bone_ribs", 25.8, -0.19, 5.71, 42, 1.25 }, { "rock_boulder_b_deep", 10.42, -0.56, -1.01, 82, 1.11 }, { "rock_mesa_deep", -25.92, -0.52, -1.8, 25, 1.05 }, { "rock_boulder_b_deep", 10.4, -0.46, 12.35, 295, 0.92 }, { "plant_bulb_glow_pink", 19.94, -0.18, -6.38, 147, 1.19 }, { "plant_bulb_glow_pink", -3.89, -0.18, -6.83, 267, 1.2 }, { "rock_boulder_a_deep", 0.31, -0.64, -10.65, 240, 1.29 }, { "rock_cluster_deep", 16.75, -0.64, -1.14, 61, 1.27 }, { "plant_glow_shroom_cyan", -7.14, -0.18, -4.57, 246, 1.2 }, { "plant_glow_shroom_cyan", -21.32, -0.19, -7.32, 83, 1.26 }, { "rock_boulder_a_deep", -12.42, -0.6, -9.82, 6, 1.21 }, { "plant_glow_shroom_cyan", -17.37, -0.15, -1.53, 184, 1.02 }, { "plant_bulb_glow_pink", 10.21, -0.16, -8.58, 14, 1.08 }, { "rock_cluster_deep", 15.29, -0.56, -12.44, 98, 1.13 }, { "rock_cluster_deep", 6.22, -0.67, 3.1, 56, 1.35 }, },
	cluster_bones_huge = { { "floor_glow_grass", -1.1, -0.2, 3.23, 18, 2.05 }, { "floor_glow_grass", -12.55, -0.19, -22.73, 356, 1.92 }, { "floor_glow_grass", -27.83, -0.23, -17.82, 149, 2.26 }, { "floor_glow_grass", 19.4, -0.22, 8.25, 73, 2.2 }, { "bone_ribs", 0.59, -0.36, 18.98, 318, 2.4 }, { "rock_wall_deep", 58.49, -1.05, 4.76, 11, 2.11 }, { "rock_pillar_deep", -50.61, -1.28, 11.29, 47, 2.57 }, { "rock_mesa_deep", -16.44, -0.7, -11.18, 281, 1.4 }, { "plant_bulb_glow_pink", -29.48, -0.24, 19.96, 28, 1.6 }, { "rock_mesa_deep", -51.98, -0.97, -14.91, 30, 1.94 }, { "rock_mesa_deep", 22.96, -0.67, -11.39, 158, 1.34 }, { "coral_pillar_teal", 35.08, -0.29, 19.33, 277, 1.94 }, { "plant_fan_teal", -33.66, -0.21, -3.4, 230, 1.39 }, { "rock_boulder_b_deep", 0.13, -0.69, -8.62, 233, 1.38 }, { "plant_bulb_glow_pink", 4.97, -0.24, -15.32, 164, 1.6 }, { "coral_pillar_teal", 29.94, -0.21, 9.41, 125, 1.4 }, { "rock_boulder_a_deep", -2.84, -0.67, 0.19, 282, 1.33 }, { "rock_boulder_a_deep", -36.75, -0.87, 14.76, 324, 1.75 }, { "rock_boulder_a_deep", -24.22, -0.8, -22.78, 355, 1.6 }, { "rock_cluster_deep", -18, -0.77, 2.52, 12, 1.55 }, { "rock_cluster_deep", -21.86, -0.62, 11.31, 89, 1.25 }, { "plant_glow_shroom_cyan", 14.2, -0.21, -8.14, 113, 1.39 }, { "plant_glow_shroom_cyan", 30.04, -0.18, 3.67, 112, 1.2 }, { "plant_bulb_glow_pink", 33.99, -0.24, -9.3, 230, 1.6 }, { "rock_cluster_deep", -34.4, -0.87, -18.87, 285, 1.74 }, { "plant_bulb_glow_pink", -29.08, -0.19, 1.06, 63, 1.28 }, { "rock_cluster_deep", -10.28, -0.78, -22.6, 8, 1.56 }, { "rock_cluster_deep", 40.16, -0.81, -18.1, 221, 1.63 }, { "rock_boulder_a_deep", 8.87, -0.77, -21.29, 330, 1.54 }, { "rock_boulder_a_deep", 9.19, -0.75, -0.61, 238, 1.5 }, { "plant_bulb_glow_pink", -14.49, -0.22, -22.17, 2, 1.46 }, { "plant_bulb_glow_pink", -9.88, -0.24, 4.12, 78, 1.6 }, { "rock_boulder_a_deep", -31.29, -0.61, -24.16, 220, 1.22 }, { "rock_boulder_a_deep", 22.93, -0.9, 4.75, 285, 1.79 }, },
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

local function light(parent: BasePart, colour: Color3, range: number)
	local l = Instance.new("PointLight")
	l.Color = colour
	l.Range = range
	l.Brightness = 1
	l.Shadows = false
	l.Parent = parent
end

local SUN_SHAFT = { rgb(255, 255, 240), rgb(180, 240, 255) }

-- A light shaft from the surface down to a floor point, leaning with the sun
local function lightShaft(anchor: BasePart, top: Vector3, bottom: Vector3, width: number, colours: { Color3 }?)
	local c = colours or SUN_SHAFT
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
	beam.Color = ColorSequence.new(c[1], c[2])
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.82),
		NumberSequenceKeypoint.new(0.7, 0.92),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Parent = anchor
end

---------------------------------------------------------------- props: placeholder Models for the prop kit's meshes
local function propColour(name: string): Color3
	if string.find(name, "_reef$") then
		return hex("#8A97AB")
	elseif string.find(name, "_deep$") then
		return hex("#55517E")
	elseif string.find(name, "_vent$") then
		return hex("#4A3A4C")
	elseif string.find(name, "pink") then
		return hex("#FF7DA6")
	elseif string.find(name, "orange") then
		return hex("#FF9A4A")
	elseif string.find(name, "purple") then
		return hex("#A77BFF")
	elseif string.find(name, "teal") then
		return hex("#3FB8B0")
	elseif string.find(name, "_green$") then
		return hex("#5FCF7E")
	elseif string.find(name, "_red$") then
		return hex("#F0645A")
	elseif string.find(name, "^kelp") then
		return rgb(78, 154, 82)
	elseif string.find(name, "^sea_grass") then
		return rgb(110, 190, 90)
	elseif string.find(name, "^plant_bulb") or string.find(name, "^plant_glow") then
		return rgb(45, 60, 90)
	elseif name == "vent_chimney" then
		return rgb(40, 30, 35)
	elseif name == "bone_ribs" then
		return hex("#EDE3CC")
	elseif name == "floor_sand_grass" then
		return hex("#F2DFA7")
	elseif name == "floor_glow_grass" then
		return hex("#7A74AC")
	elseif name == "floor_vent_ash" then
		return hex("#6E5468")
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

local NO_SHADOW = { CastShadow = false }

-- A placeholder Model for one prop: pivot at its base (as the kit's meshes), chunky stand-in parts inside, and for a
-- glowing prop a Neon part where its _glow mesh goes (lit with a PointLight when withLight)
local function prop(parent: Instance, name: string, base: CFrame, scale: number, withLight: boolean?): Model
	local row = PROPS[name]
	local size = Vector3.new(row[2], row[3], row[4]) * scale
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("PropName", name)
	m:SetAttribute("PropScale", math.floor(scale * 100 + 0.5) / 100)
	m:SetAttribute("PropSize", size)
	local c = propColour(name)
	local x, y, z = size.X, size.Y, size.Z
	local function block(n: string, s: Vector3, at: CFrame, colour: Color3?)
		part(m, n, s, base * at, colour or c, NO_SHADOW)
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
	elseif string.find(name, "^rock_mesa") then -- a table rock with an overhanging ledge
		block("Base", Vector3.new(x * 0.8, y * 0.65, z * 0.75), CFrame.new(0, y * 0.325, z * 0.05))
		block("Ledge", Vector3.new(x, y * 0.35, z), CFrame.new(0, y * 0.825, 0) * CFrame.Angles(0, 0.08, 0))
	elseif string.find(name, "^rock_pillar") then -- a leaning column with a flat cap
		block(
			"Column",
			Vector3.new(x * 0.6, y * 0.88, z * 0.6),
			CFrame.new(0, y * 0.44, 0) * CFrame.Angles(0, 0.3, 0.06)
		)
		block("Cap", Vector3.new(x, y * 0.14, z), CFrame.new(x * 0.03, y * 0.93, 0))
	elseif string.find(name, "^rock_wall") then -- a stepped cliff wall
		block("Wall", Vector3.new(x, y * 0.7, z * 0.85), CFrame.new(0, y * 0.35, z * 0.07))
		block("Step", Vector3.new(x * 0.75, y * 0.3, z * 0.6), CFrame.new(-x * 0.06, y * 0.85, z * 0.15))
	elseif string.find(name, "^rock") then
		block("Rock", Vector3.new(x, y, z), CFrame.new(0, y / 2, 0) * CFrame.Angles(0.08, 0.3, -0.06))
	elseif string.find(name, "^coral_mushroom") then -- a tiered mushroom coral you can ride under
		cylinder(m, "Stem", y * 0.75, x * 0.22, base * CFrame.new(0, y * 0.375, 0), c, NO_SHADOW)
		cylinder(m, "Cap", y * 0.25, x, base * CFrame.new(0, y * 0.85, 0), c, NO_SHADOW)
	elseif string.find(name, "^coral_pillar") then
		block("Pillar", Vector3.new(x * 0.6, y, z * 0.7), CFrame.new(0, y / 2, 0))
	elseif string.find(name, "^coral_table") then
		cylinder(m, "Stem", y * 0.7, x * 0.2, base * CFrame.new(0, y * 0.35, 0), c, NO_SHADOW)
		cylinder(m, "Top", y * 0.3, x, base * CFrame.new(0, y * 0.85, 0), c, NO_SHADOW)
	elseif string.find(name, "^coral_fan") then
		block("Fan", Vector3.new(x, y, z * 0.3), CFrame.new(0, y / 2, 0))
	elseif string.find(name, "^coral_brain") then
		block("Brain", Vector3.new(x, y, z), CFrame.new(0, y / 2, 0) * CFrame.Angles(0, 0.6, 0))
	elseif string.find(name, "^coral") then -- branch, tube: two stalks
		block("Stalk", Vector3.new(x * 0.4, y, z * 0.4), CFrame.new(-x * 0.2, y / 2, 0))
		block("Stalk", Vector3.new(x * 0.35, y * 0.7, z * 0.35), CFrame.new(x * 0.25, y * 0.35, z * 0.15))
	elseif string.find(name, "^plant_fan") then
		block("Fan", Vector3.new(x * 0.8, y, z * 0.8), CFrame.new(0, y / 2, 0) * CFrame.Angles(0, 0.7, 0))
	elseif string.find(name, "^kelp") or string.find(name, "^plant_bulb") then
		block("Stalk", Vector3.new(x * 0.3, y * 0.9, z * 0.3), CFrame.new(0, y * 0.45, 0) * CFrame.Angles(0, 0, 0.04))
	elseif string.find(name, "^plant_glow_shroom") then
		block("Shrooms", Vector3.new(x, y * 0.5, z), CFrame.new(0, y * 0.25, 0))
	elseif name == "vent_chimney" then
		block("Chimney", Vector3.new(x * 0.55, y, z * 0.7), CFrame.new(0, y / 2, 0))
	elseif name == "bone_ribs" then
		block("Spine", Vector3.new(x, y * 0.12, z * 0.15), CFrame.new(0, y * 0.06, 0))
		for k = -1, 1 do
			block(
				"Rib",
				Vector3.new(x * 0.07, y, z * 0.1),
				CFrame.new(k * x * 0.3, y / 2, 0) * CFrame.Angles(0.35, 0, 0)
			)
		end
	elseif string.find(name, "^floor_") then
		block("Patch", Vector3.new(x, math.max(0.4, y * 0.3), z), CFrame.new(0, math.max(0.2, y * 0.15), 0))
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
	if row[5] then -- the glowing faces: a Neon core inside the glow mesh's box
		local glowColour = hex(row[5])
		local core = Vector3.new(
			math.max(0.4, row[6] * 0.45),
			math.max(0.4, row[7] * 0.45),
			math.max(0.4, row[8] * 0.45)
		) * scale
		local g = part(
			m,
			"Glow",
			core,
			base * CFrame.new(Vector3.new(row[9], row[10], row[11]) * scale),
			glowColour,
			{ Material = Enum.Material.Neon, CastShadow = false, CanCollide = false }
		)
		m:SetAttribute("PropGlow", row[5])
		if withLight then
			light(g, glowColour, 18)
		end
	end
	m.WorldPivot = ORIGIN * base
	m:SetAttribute("PropBase", ORIGIN * base) -- the same, kept where a saved file won't drop it
	m.Parent = parent
	return m
end

local clusterCount = 0

-- A cluster preset as a Model of prop placeholders. place(x, z) gives the floor's height and how steep it is under a
-- piece at (x, z) from the cluster's origin, so the pieces sit on slopes; withLight lights the first glowing piece.
local function cluster(
	parent: Instance,
	name: string,
	base: CFrame,
	scale: number,
	floorAt: (Vector3) -> (number, number),
	withLight: boolean?
): Model
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("ClusterName", name)
	m:SetAttribute("ClusterScale", math.floor(scale * 100 + 0.5) / 100)
	local lit = not withLight
	for _, piece in CLUSTERS[name] do
		local row = PROPS[piece[1]]
		local s = piece[6] * scale
		local offset = Vector3.new(piece[2], 0, piece[4]) * scale
		local world = base * offset -- the piece's point, at the cluster's floor height
		local y, steep = floorAt(world)
		local sink = steep * math.max(row[2], row[4]) * s * 0.5 - piece[3] * scale + row[3] * s * 0.04
		local rot = base - base.Position
		local at = CFrame.new(world.X, y - sink, world.Z) * rot * CFrame.Angles(0, math.rad(piece[5]), 0)
		local lightIt = not lit and row[5] ~= nil
		if lightIt then
			lit = true
		end
		prop(m, piece[1], at, s, lightIt)
	end
	m.WorldPivot = ORIGIN * base
	m:SetAttribute("ClusterBase", ORIGIN * base)
	m.Parent = parent
	clusterCount += 1
	return m
end

local function flatFloor(y: number): (Vector3) -> (number, number)
	return function(_: Vector3): (number, number)
		return y, 0
	end
end

---------------------------------------------------------------- the lane's path: where it runs, how deep, how wide
local starts: { number } = {} -- each zone's start along the lane (s = 0 at LANE_START)
local ramps: { number } = {} -- each zone's ramp length
local tops: { number } = {} -- the floor's height where each zone begins (the top of its ramp)
local TOTAL = 0
do
	local y = LAGOON_Y + 1 -- a stud above the lagoon's floor, so the lane's sand doesn't flicker against it
	for i, zone in ZONES do
		starts[i] = TOTAL
		ramps[i] = if i > 1 then zone.Drop / math.tan(math.rad(RAMP_DEGREES)) else 0
		tops[i] = y
		TOTAL += zone.Length
		y -= (zone.Length - (zone.Flat or 0)) * math.tan(math.rad(zone.Slope)) + (if i > 1 then zone.Drop else 0)
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
	return tops[i] - math.max(0, t - (zone.Flat or 0)) * math.tan(math.rad(zone.Slope)) - drop
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

-- The same frame's turn alone
local function laneTurn(s: number): CFrame
	local f = pathFrame(s)
	return f - f.Position
end

-- A frame pitched along the lane from sa to sb, at the middle, and the length between
local function segFrame(sa: number, sb: number): (CFrame, number)
	local pa, pb = centre(sa), centre(sb)
	return CFrame.lookAt((pa + pb) / 2, pb) * CFrame.Angles(0, math.pi, 0), (pb - pa).Magnitude
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

-- The seabed under a world point near the lane at s = hint: its height and how steep it is there (rise over run)
local function seabedNear(hint: number): (Vector3) -> (number, number)
	return function(p: Vector3): (number, number)
		local s = hint
		for _ = 1, 4 do -- step s by how far along the lane the point is (the lane bends gently, so this settles fast)
			s = math.clamp(s + (p - centre(s)):Dot(direction(s)), 0, TOTAL)
		end
		local x = (p - centre(s)):Dot(across(s))
		local steep = math.abs(ground(s, x + 3).Y - ground(s, x - 3).Y) / 6
		return ground(s, x).Y, steep
	end
end

-- A cluster beside the lane at (s, x), its front turned to face the lane (side: which bank, -1 or 1)
local function laneCluster(
	parent: Instance,
	name: string,
	s: number,
	x: number,
	scale: number,
	withLight: boolean?
): Model
	local side = if x < 0 then -1 else 1
	local base = CFrame.new(ground(s, x))
		* laneTurn(s)
		* CFrame.Angles(0, side * math.pi / 2 + rng:NextNumber(-0.25, 0.25), 0)
	return cluster(parent, name, base, scale, seabedNear(s), withLight)
end

-- Spans of the lane with a roof over it: { s0, s1, clearance above the floor }, for the Path's c
local ceilings: { { number } } = {}
local function ceiling(s0: number, s1: number, clearance: number)
	table.insert(ceilings, { s0, s1, math.floor(clearance) })
end

local formations: { { any } } = {}
local function formation(parent: Instance, kind: string, s: number): Model
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Formation", kind)
	m:SetAttribute("LaneS", math.floor(s))
	m.Parent = parent
	table.insert(formations, { kind, math.floor(s) })
	return m
end

-- A chunk of rock, turned a little off square so stacks of them read as faceted rock
local function chunk(
	parent: Instance,
	name: string,
	size: Vector3,
	at: Vector3,
	s: number,
	colour: Color3,
	tilt: number?
)
	local t = tilt or 0.12
	return part(
		parent,
		name,
		size,
		CFrame.new(at)
			* laneTurn(s)
			* CFrame.Angles(rng:NextNumber(-t, t), rng:NextNumber(-0.4, 0.4), rng:NextNumber(-t, t)),
		colour
	)
end

local root = folder("ClaudeBlockout")

---------------------------------------------------------------- formations: the shapes the lane passes through
-- An arch over the lane at s: two legs from the banks, a span with chunky shoulders, its underside `height` above the floor
local function arch(
	parent: Instance,
	s: number,
	span: number,
	height: number,
	thick: number,
	colour: Color3,
	name: string?
): Model
	local m = formation(parent, name or "Arch", s)
	local c = centre(s)
	local ax = across(s)
	local turn = laneTurn(s)
	local topY = c.Y + height + thick
	for side = -1, 1, 2 do
		local p = c + ax * (side * span / 2)
		local g = ground(s, side * span / 2).Y
		local h = topY - g + 12
		part(
			m,
			"Leg",
			Vector3.new(thick * 1.4, h, thick * 1.15),
			CFrame.new(p.X, g - 12 + h / 2, p.Z) * turn * CFrame.Angles(0, 0, side * 0.05),
			colour
		)
		local shoulder = c + ax * (side * (span / 2 - thick * 0.3)) + Vector3.new(0, height - thick * 0.05, 0)
		part(
			m,
			"Shoulder",
			Vector3.new(thick * 1.2, thick * 1.2, thick * 1.2),
			CFrame.new(shoulder) * turn * CFrame.Angles(0, 0, math.pi / 4),
			colour
		)
	end
	part(
		m,
		"Span",
		Vector3.new(span + thick * 1.4, thick, thick * 1.15),
		CFrame.new(c + Vector3.new(0, height + thick / 2, 0)) * turn,
		colour
	)
	chunk(
		m,
		"Crown",
		Vector3.new(thick * 1.6, thick * 0.6, thick * 1.25),
		c + Vector3.new(rng:NextNumber(-span / 6, span / 6), height + thick * 1.15, 0),
		s,
		colour
	)
	ceiling(s - thick, s + thick, height)
	return m
end

-- A rock pillar standing on the seabed at (s, x): three tapering chunks, sometimes a ledge on top. Returns its top.
local function pillar(
	parent: Instance,
	s: number,
	x: number,
	height: number,
	width: number,
	colour: Color3,
	name: string?
): Vector3
	local m = formation(parent, name or "Pillar", s)
	local g = ground(s, x)
	local y = g.Y - 12
	local share = { 0.42, 0.34, 0.24 }
	local wide = { 1, 0.78, 0.58 }
	local at = g
	for k = 1, 3 do
		local h = (height + 12) * share[k] + 4
		at = Vector3.new(g.X + rng:NextNumber(-3, 3), y + h / 2, g.Z + rng:NextNumber(-3, 3))
		chunk(
			m,
			"Rock",
			Vector3.new(width * wide[k], h, width * wide[k] * rng:NextNumber(0.8, 1.1)),
			at,
			s,
			colour,
			0.06
		)
		y += h - 4
	end
	if rng:NextNumber() < 0.5 then
		chunk(m, "Ledge", Vector3.new(width * 0.95, 8, width * 0.8), Vector3.new(at.X, y, at.Z), s, colour, 0.05)
	end
	return Vector3.new(at.X, y, at.Z)
end

-- A ledge reaching out over the lane from one bank, `height` above the floor, held up by a buttress in the bank
local function overhang(
	parent: Instance,
	s: number,
	side: number,
	length: number,
	reach: number,
	height: number,
	colour: Color3
)
	local m = formation(parent, "Overhang", s)
	local half = shapeAt(s).Lane / 2
	local inner, outer = half - reach, half + 80
	local c = centre(s)
	local ax = across(s)
	local turn = laneTurn(s)
	local mid = c + ax * (side * (inner + outer) / 2) + Vector3.new(0, height + 12, 0)
	part(
		m,
		"Ledge",
		Vector3.new(outer - inner, 24, length),
		CFrame.new(mid) * turn * CFrame.Angles(0, 0, side * 0.06),
		colour
	)
	local bx = side * (half + 50)
	local g = ground(s, bx).Y
	local top = c.Y + height + 12
	if top - g > 6 then
		local b = c + ax * bx
		part(
			m,
			"Buttress",
			Vector3.new(60, top - g + 12, length * 0.8),
			CFrame.new(b.X, (top + g - 12) / 2, b.Z) * turn,
			colour
		)
	end
	for _ = 1, 2 do
		local drip = c + ax * (side * (inner + 14)) + direction(s) * rng:NextNumber(-length / 3, length / 3)
		chunk(m, "Drip", Vector3.new(9, 16, 9), drip + Vector3.new(0, height - 5, 0), s, colour, 0.15)
	end
	ceiling(s - length / 2, s + length / 2, height - 14)
end

-- A cave the lane runs through from s0 to s1: a roof `height` above the floor with walls down to the banks, stalactites,
-- an open skylight every fourth stretch, and a jagged mouth at each end
local function cave(
	parent: Instance,
	s0: number,
	s1: number,
	height: number,
	colour: Color3,
	name: string,
	glow: Color3?
)
	local m = formation(parent, name, s0)
	local s = s0
	local k = 0
	while s < s1 - 1 do
		local sb = math.min(s + 100, s1)
		local frame, length = segFrame(s, sb)
		local sm = (s + sb) / 2
		local half = shapeAt(sm).Lane / 2
		k += 1
		if k % 4 ~= 0 then
			part(m, "Roof", Vector3.new(half * 2 + 100, 36, length + 6), frame * CFrame.new(0, height + 18, 0), colour)
			for _ = 1, 2 do
				local x = rng:NextNumber(-half * 0.95, half * 0.95)
				local p = (frame * CFrame.new(x, height - 4, rng:NextNumber(-length / 3, length / 3))).Position
				chunk(
					m,
					"Stalactite",
					Vector3.new(rng:NextNumber(6, 12), rng:NextNumber(16, 28), rng:NextNumber(6, 12)),
					p,
					sm,
					colour,
					0.15
				)
			end
		end
		for side = -1, 1, 2 do
			local x = side * (half + 30)
			local g = ground(sm, x).Y
			local top = frame.Position.Y + height + 36
			if top - g > 4 then
				local p = (frame * CFrame.new(x, 0, 0)).Position
				part(
					m,
					"Wall",
					Vector3.new(44, top - g + 10, length + 6),
					CFrame.new(p.X, (top + g - 10) / 2, p.Z) * laneTurn(sm),
					colour
				)
			end
			if glow and k % 2 == 1 then -- glowing growth along the walls
				local q = (frame * CFrame.new(side * (half + 8), height * rng:NextNumber(0.2, 0.7), 0)).Position
				local g2 = part(
					m,
					"WallGlow",
					Vector3.new(2, rng:NextNumber(4, 9), rng:NextNumber(20, 50)),
					CFrame.new(q) * laneTurn(sm),
					glow,
					{ Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }
				)
				if k % 4 == 1 then
					light(g2, glow, 24)
				end
			end
		end
		s = sb
	end
	for _, at in { s0, s1 } do
		arch(m, at, shapeAt(at).Lane + 40, height - 6, 34, colour, "Mouth")
	end
	ceiling(s0, s1, height - 20)
	return m
end

-- A vent chimney on the seabed at (s, x), glowing at its mouth, with a smoke column
local function chimney(parent: Instance, s: number, x: number, height: number, width: number, withLight: boolean)
	local at = ground(s, x)
	part(
		parent,
		"Chimney",
		Vector3.new(width, height + 10, width * 0.9),
		CFrame.new(at + Vector3.new(0, height / 2 - 5, 0)) * laneTurn(s) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
		rgb(25, 20, 20)
	)
	local glow = part(
		parent,
		"Glow",
		Vector3.new(width * 0.7, 2, width * 0.7),
		CFrame.new(at + Vector3.new(0, height + 1, 0)),
		rgb(255, 120, 30),
		{ Material = Enum.Material.Neon, CastShadow = false }
	)
	if withLight then
		light(glow, rgb(255, 140, 60), 40)
	end
	part(
		parent,
		"Smoke",
		Vector3.new(width * 0.8, 90, width * 0.8),
		CFrame.new(at + Vector3.new(0, height + 46, 0)),
		rgb(20, 20, 20),
		{ Transparency = 0.6, CanCollide = false, CastShadow = false }
	)
end

-- Glowing cracks or growth on the banks of a stretch: thin Neon strips lying on the slopes
local function bankGlow(parent: Instance, s0: number, s1: number, count: number, colour: Color3, name: string)
	for _ = 1, count do
		local s = rng:NextNumber(s0, s1)
		local shape = shapeAt(s)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local w1, h1 = shape.Tiers[1][1], shape.Tiers[1][2]
		local at = ground(s, side * (shape.Lane / 2 + w1 * rng:NextNumber(0.15, 0.85)))
		part(
			parent,
			name,
			Vector3.new(rng:NextNumber(20, 60), 1, rng:NextNumber(2, 5)),
			CFrame.new(at)
				* laneTurn(s)
				* CFrame.Angles(0, 0, side * math.atan2(h1, w1))
				* CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0),
			colour,
			{ Material = Enum.Material.Neon, CastShadow = false }
		)
	end
end

local function jellies(parent: Instance, s0: number, s1: number, count: number, colour: Color3)
	for _ = 1, count do
		local s = rng:NextNumber(s0, s1)
		local half = shapeAt(s).Lane / 2
		local size = rng:NextNumber(4, 10)
		part(
			parent,
			"Jelly",
			Vector3.new(size, size, size),
			CFrame.new(ground(s, rng:NextNumber(-half * 1.4, half * 1.4)) + Vector3.new(0, rng:NextNumber(70, 170), 0)),
			colour,
			{
				Shape = Enum.PartType.Ball,
				Material = Enum.Material.Neon,
				Transparency = 0.25,
				CanCollide = false,
				CastShadow = false,
			}
		)
	end
end

-- Each zone's signature: builds its formations into f and returns the s of its landmarks, where huge clusters flank the
-- lane. at(u) is the s that far through the zone (0 to 1).
type Signature = (f: Instance, i: number, at: (number) -> number) -> { number }
local SIGNATURES: { [string]: Signature } = {}

-- Where the lane leaves the lagoon: two sea stacks with a span on top, breaking the surface (seen from the dock)
SIGNATURES.ReefGate = function(f, _i, at)
	local s = LAGOON_RADIUS - LANE_START - 10
	local c = centre(s)
	local half = shapeAt(s).Lane / 2
	local rock = rgb(150, 140, 120)
	for side = -1, 1, 2 do
		local m = formation(f, "SeaStack", s)
		local p = c + across(s) * (side * (half + 30))
		local h = 22 - c.Y
		chunk(m, "Stack", Vector3.new(58, h + 10, 50), Vector3.new(p.X, c.Y - 5 + (h + 10) / 2, p.Z), s, rock, 0.05)
		chunk(m, "Top", Vector3.new(40, 16, 36), Vector3.new(p.X, 26, p.Z), s, rock, 0.1)
		part(
			m,
			"Surf",
			Vector3.new(70, 1, 66),
			CFrame.new(p.X, 0.6, p.Z),
			rgb(255, 255, 255),
			{ Transparency = 0.3, CanCollide = false }
		)
	end
	arch(f, s, half * 2 + 60, 2 - c.Y, 14, rock, "ReefGate")
	return { s, at(0.35) }
end

-- Three coral arches you ride through, with reef clusters on top, and two coral shelves overhanging the lane
SIGNATURES.CoralArches = function(f, i, at)
	local zone = ZONES[i]
	local marks = {}
	for k, u in { 0.22, 0.5, 0.78 } do
		local s = at(u)
		local height = if k == 2 then 95 else 82
		arch(f, s, shapeAt(s).Lane + 30, height, 22, rgb(250, 180, 150), "CoralArch")
		local top = centre(s) + Vector3.new(0, height + 22, 0)
		cluster(f, "cluster_reef_small", CFrame.new(top) * laneTurn(s), 1.3, flatFloor(top.Y))
		table.insert(marks, s)
	end
	overhang(f, at(0.36), 1, 90, 0.4 * zone.Lane / 2, 70, zone.Rock:Lerp(rgb(255, 160, 120), 0.3))
	overhang(f, at(0.64), -1, 90, 0.4 * zone.Lane / 2, 70, zone.Rock:Lerp(rgb(255, 160, 120), 0.3))
	return marks
end

-- Tall rock pillars flanking the lane like a nave, kelp at their feet, and a natural bridge high over the middle
SIGNATURES.KelpCathedral = function(f, i, at)
	local zone = ZONES[i]
	local side = 1
	for u = 0.14, 0.86, 0.08 do
		local s = at(u) + rng:NextNumber(-30, 30)
		local half = shapeAt(s).Lane / 2
		pillar(
			f,
			s,
			side * (half + rng:NextNumber(10, 40)),
			rng:NextNumber(140, 220),
			rng:NextNumber(38, 55),
			zone.Rock,
			"KelpPillar"
		)
		side = -side
	end
	arch(f, at(0.5), zone.Lane + 60, 150, 30, zone.Rock, "KelpBridge")
	return { at(0.5), at(0.22), at(0.78) }
end

-- A giant hull lying along the lane that you ride through, broken open, and smaller wrecks on the banks
SIGNATURES.BrokenHull = function(f, _i, at)
	local wood, dark = rgb(110, 80, 60), rgb(80, 58, 45)
	local s0 = at(0.42)
	local s1 = s0 + 240
	local m = formation(f, "BrokenHull", s0)
	local height = 90
	local k = 0
	local s = s0
	while s < s1 - 1 do
		local sb = math.min(s + 60, s1)
		local frame, length = segFrame(s, sb)
		local half = shapeAt((s + sb) / 2).Lane / 2 * 0.95
		k += 1
		for side = -1, 1, 2 do -- the hull's sides, leaning in
			part(
				m,
				"HullSide",
				Vector3.new(8, height + 20, length + 2),
				frame * CFrame.new(side * half, height / 2 - 4, 0) * CFrame.Angles(0, 0, side * 0.18),
				wood
			)
		end
		if k % 3 ~= 2 then -- the deck overhead, broken open every third stretch
			part(
				m,
				"Deck",
				Vector3.new(half * 2 - 20, 6, length + 2),
				frame
					* CFrame.new(rng:NextNumber(-8, 8), height + 3, 0)
					* CFrame.Angles(0, 0, rng:NextNumber(-0.06, 0.06)),
				dark
			)
		end
		s = sb
	end
	for u = 0, 1, 0.25 do -- the frames: dark ribs round the inside
		local sr = s0 + 240 * u
		local frame = segFrame(sr - 1, sr + 1)
		local half = shapeAt(sr).Lane / 2 * 0.95
		part(m, "Frame", Vector3.new(half * 2 + 10, 6, 6), frame * CFrame.new(0, height + 8, 0), dark)
	end
	local mast = segFrame(s0 + 110, s0 + 112)
	part(m, "Mast", Vector3.new(4, 4, 200), mast * CFrame.new(40, height + 12, 0) * CFrame.Angles(0, 0.9, 0.1), dark)
	ceiling(s0, s1, height - 6)
	-- the smaller wrecks on the banks, as v3's
	for _, u in { 0.18, 0.8 } do
		local ws = at(u)
		local shape = shapeAt(ws)
		local side = if u < 0.5 then -1 else 1
		local p = ground(ws, side * (shape.Lane / 2 + 40))
		local w = formation(f, "Wreck", ws)
		local hull = CFrame.new(p + Vector3.new(0, 8, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-25, 25)))
		part(w, "Hull", Vector3.new(36, 26, 110), hull, wood)
		part(
			w,
			"Mast",
			Vector3.new(3, 70, 3),
			hull * CFrame.new(0, 45, -15) * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), 0, 0),
			dark
		)
	end
	return { s0, s1, at(0.18), at(0.8) }
end

-- Sea stacks rising out of the blue in pairs either side of the lane, one pair bridged by a sky arch
SIGNATURES.SeaStacks = function(f, i, at)
	local zone = ZONES[i]
	local marks = {}
	for _, u in { 0.2, 0.46, 0.72 } do
		local s = at(u)
		local half = shapeAt(s).Lane / 2
		for side = -1, 1, 2 do
			pillar(
				f,
				s + side * 40,
				side * (half + rng:NextNumber(60, 110)),
				rng:NextNumber(260, 380),
				rng:NextNumber(70, 110),
				zone.Rock,
				"SeaStack"
			)
		end
		table.insert(marks, s)
	end
	arch(f, at(0.46), zone.Lane + 180, 200, 40, zone.Rock, "SkyArch")
	-- two stacks framing the shelf break at the zone's start
	local edge = starts[i] + 30
	for side = -1, 1, 2 do
		pillar(f, edge, side * (shapeAt(edge).Lane / 2 + 40), 140, 60, zone.Rock, "BreakStack")
	end
	return marks
end

-- A narrow canyon with ledges overhanging from alternate sides, glowing growth on its walls and two arches
SIGNATURES.GlowCanyon = function(f, i, at)
	local zone = ZONES[i]
	local glow = zone.Look.Glow :: Color3
	local side = 1
	for u = 0.12, 0.9, 0.12 do
		overhang(f, at(u), side, 110, 0.45 * zone.Lane / 2, 100, zone.Rock)
		side = -side
	end
	arch(f, at(0.3), zone.Lane + 20, 120, 26, zone.Rock, "CanyonArch")
	arch(f, at(0.7), zone.Lane + 20, 120, 26, zone.Rock, "CanyonArch")
	bankGlow(f, starts[i], starts[i] + zone.Length, 40, glow, "WallGlow")
	jellies(f, starts[i], starts[i] + zone.Length, 10, hex("#FF6FD8"))
	return { at(0.3), at(0.7) }
end

-- A long cave the lane runs through, lit by glowing growth, with jellies drifting outside
SIGNATURES.LongCave = function(f, i, at)
	local zone = ZONES[i]
	cave(f, at(0.35), at(0.65), 110, zone.Rock, "LongCave", zone.Look.Glow)
	jellies(f, starts[i], at(0.33), 15, rgb(80, 240, 255))
	jellies(f, at(0.67), starts[i] + zone.Length, 15, rgb(80, 240, 255))
	return { at(0.35), at(0.65) }
end

-- Chimneys in composed groups, a big one with two small ones, and an arch of black rock with ember cracks
SIGNATURES.ChimneyField = function(f, i, at)
	local zone = ZONES[i]
	local side = 1
	for _, u in { 0.16, 0.32, 0.5, 0.66, 0.84 } do
		local s = at(u)
		local half = shapeAt(s).Lane / 2
		local m = formation(f, "ChimneyGroup", s)
		chimney(m, s, side * half * rng:NextNumber(0.85, 1), rng:NextNumber(110, 160), rng:NextNumber(26, 34), true)
		chimney(m, s + 40, side * (half + 30), rng:NextNumber(40, 70), rng:NextNumber(14, 20), false)
		chimney(m, s - 35, side * (half + 55), rng:NextNumber(30, 60), rng:NextNumber(12, 18), false)
		side = -side
	end
	local a = arch(f, at(0.42), zone.Lane + 30, 100, 28, zone.Rock, "EmberArch")
	for _ = 1, 4 do
		local s = at(0.42)
		local p = centre(s)
			+ across(s) * rng:NextNumber(-zone.Lane / 2, zone.Lane / 2)
			+ Vector3.new(0, 100 + 28 * rng:NextNumber(0.2, 0.9), 0)
		part(
			a,
			"Ember",
			Vector3.new(rng:NextNumber(10, 30), 2, 30),
			CFrame.new(p - direction(s) * 16) * laneTurn(s),
			zone.Look.Glow :: Color3,
			{ Material = Enum.Material.Neon, CastShadow = false }
		)
	end
	bankGlow(f, starts[i], starts[i] + zone.Length, 16, rgb(255, 110, 40), "EmberCrack")
	return { at(0.42), at(0.84) }
end

-- A leviathan's skeleton lying along the lane: you ride under its spine, between its ribs, and out through its jaws
SIGNATURES.Leviathan = function(f, i, at)
	local bone = rgb(235, 230, 215)
	local glow = ZONES[i].Look.Glow :: Color3
	local s0 = at(0.38)
	local s1 = s0 + 420
	local height = 130
	local m = formation(f, "Leviathan", s0)
	local s = s0
	while s < s1 - 1 do
		local sb = math.min(s + 105, s1)
		local frame, length = segFrame(s, sb)
		part(m, "Spine", Vector3.new(12, 12, length + 4), frame * CFrame.new(0, height, 0), bone)
		s = sb
	end
	for sr = s0 + 18, s1 - 18, 36 do
		local c = centre(sr)
		local ax = across(sr)
		local w = shapeAt(sr).Lane / 2 + 25
		for side = -1, 1, 2 do
			local pts = {
				Vector2.new(0, height),
				Vector2.new(0.55 * w, height - 18),
				Vector2.new(0.92 * w, height * 0.55),
				Vector2.new(w, ground(sr, side * w).Y - c.Y - 6),
			}
			for k = 1, 3 do
				local pa = c + ax * (side * pts[k].X) + Vector3.new(0, pts[k].Y, 0)
				local pb = c + ax * (side * pts[k + 1].X) + Vector3.new(0, pts[k + 1].Y, 0)
				part(m, "Rib", Vector3.new(7, 7, (pb - pa).Magnitude + 5), CFrame.lookAt((pa + pb) / 2, pb), bone)
			end
		end
	end
	ceiling(s0, s1, height - 30)
	-- the skull at the far end: cranium overhead, the jaws either side, teeth at the edges and glowing eyes
	local ks = s1 + 70
	local skull = formation(f, "Skull", ks)
	local frame = segFrame(ks - 1, ks + 1)
	local half = shapeAt(ks).Lane / 2
	part(skull, "Cranium", Vector3.new(half * 2 + 40, 50, 130), frame * CFrame.new(0, 100, 0), bone)
	part(
		skull,
		"Snout",
		Vector3.new(half * 1.4, 30, 60),
		frame * CFrame.new(0, 92, -85) * CFrame.Angles(-0.2, 0, 0),
		bone
	)
	for side = -1, 1, 2 do
		part(
			skull,
			"Jaw",
			Vector3.new(26, 40, 170),
			frame * CFrame.new(side * (half + 6), 14, -10) * CFrame.Angles(0, side * 0.15, 0),
			bone
		)
		for t = -2, 2 do
			part(skull, "Tooth", Vector3.new(6, 26, 6), frame * CFrame.new(side * half * 0.85, 68, t * 22 - 40), bone)
		end
		local eye = part(
			skull,
			"Eye",
			Vector3.new(14, 14, 14),
			frame * CFrame.new(side * (half * 0.6), 110, 40),
			glow,
			{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, CastShadow = false }
		)
		light(eye, glow, 40)
	end
	ceiling(ks - 65, ks + 65, 70)
	-- two smaller skeletons on the banks, as v3's
	for _, u in { 0.14, 0.86 } do
		local bs = at(u)
		local spine = CFrame.new(
			ground(bs, (if u < 0.5 then -1 else 1) * (shapeAt(bs).Lane / 2 + 60)) + Vector3.new(0, 3, 0)
		) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local b = formation(f, "Skeleton", bs)
		part(b, "Spine", Vector3.new(6, 6, 140), spine, bone)
		part(b, "Skull", Vector3.new(26, 14, 34), spine * CFrame.new(0, 4, -82), bone)
		for k = -4, 4, 2 do
			for side = -1, 1, 2 do
				part(
					b,
					"Rib",
					Vector3.new(3, 40, 3),
					spine * CFrame.new(side * 10, 16, k * 11) * CFrame.Angles(0, 0, math.rad(side * -30)),
					bone
				)
			end
		end
	end
	jellies(f, starts[i], starts[i] + ZONES[i].Length, 8, glow)
	return { s0, ks, at(0.14), at(0.86) }
end

-- The trench narrows into a throat: red cracks, a fanged cave near the end, and the Megalodon in its lair
SIGNATURES.Throat = function(f, i, at)
	local zone = ZONES[i]
	local endS = starts[i] + zone.Length
	local glow = zone.Look.Glow :: Color3
	bankGlow(f, starts[i], endS, 30, rgb(255, 50, 40), "Crack")
	local throat = cave(f, endS - 900, endS - 260, 100, zone.Rock, "Throat", glow)
	for s = endS - 880, endS - 280, 60 do -- fangs up from the floor at the edges
		local half = shapeAt(s).Lane / 2
		for side = -1, 1, 2 do
			local p = ground(s, side * half * rng:NextNumber(0.8, 0.95))
			chunk(
				throat,
				"Fang",
				Vector3.new(8, rng:NextNumber(26, 46), 8),
				p + Vector3.new(0, 10, 0),
				s,
				zone.Rock,
				0.2
			)
		end
	end
	-- the Megalodon at the end, coming up the trench toward the rider
	local meg = pathFrame(endS - 140) * CFrame.new(0, 45, 0) -- its front (-Z) up the lane
	local m = formation(f, "Megalodon", endS - 140)
	part(m, "Megalodon", Vector3.new(18, 16, 64), meg, rgb(70, 75, 90))
	part(m, "Fin", Vector3.new(2, 16, 14), meg * CFrame.new(0, 15, 4), rgb(70, 75, 90))
	part(m, "Tail", Vector3.new(2, 24, 10), meg * CFrame.new(0, 0, 36), rgb(70, 75, 90))
	-- the end of the dive: the trench closes in a wall, the Megalodon's lair
	local width = zone.Lane
	for _, tier in zone.Tiers do
		width += tier[1] * 2
	end
	part(m, "EndWall", Vector3.new(width + 200, 900, 20), pathFrame(endS) * CFrame.new(0, 400, 10), zone.Rock)
	return { endS - 900, at(0.3) }
end

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
	for s = 0, TOTAL, 250 do
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
	cylinder(f, "Floor", 4, LAGOON_RADIUS * 2, CFrame.new(0, LAGOON_Y - 2, 0), sand)
	-- the ring reef: rocks round the lagoon, some breaking the surface, open toward the dive
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
	-- set pieces round the island's curved side, facing it, so the plots look out over them
	local clusters = folder("Clusters", f)
	local sizes = { "huge", "small", "medium", "small", "medium" }
	local n = 0
	for degrees = 100, 260, 16 do
		n += 1
		local a = math.rad(degrees + rng:NextNumber(-4, 4))
		local r = if n % 2 == 0 then rng:NextNumber(560, 640) else rng:NextNumber(700, 820)
		local at = Vector3.new(math.sin(a) * r, LAGOON_Y, math.cos(a) * r)
		local size = sizes[(n - 1) % #sizes + 1]
		cluster(
			clusters,
			"cluster_lagoon_" .. size,
			CFrame.lookAt(at, Vector3.new(0, LAGOON_Y, 0)),
			rng:NextNumber(1.4, 1.7),
			flatFloor(LAGOON_Y)
		)
	end
	-- and either side of the channel, beyond its sandbanks
	for _, spec in { { -620, 330, "medium" }, { 640, 420, "huge" }, { -600, 720, "huge" }, { 610, 800, "medium" } } do
		local at = Vector3.new(spec[1], LAGOON_Y, spec[2])
		cluster(
			clusters,
			"cluster_lagoon_" .. spec[3],
			CFrame.lookAt(at, Vector3.new(0, LAGOON_Y, spec[2])),
			1.6,
			flatFloor(LAGOON_Y)
		)
	end
	-- light shafts over the lagoon
	local anchor = part(
		f,
		"ShaftAnchor",
		Vector3.new(1, 1, 1),
		CFrame.new(0, -10, 0),
		rgb(255, 255, 255),
		{ Transparency = 1, CanCollide = false }
	)
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(470, 900)
		local bottom = Vector3.new(math.sin(a) * r, LAGOON_Y, math.cos(a) * r)
		lightShaft(anchor, bottom + Vector3.new(-25, -LAGOON_Y, -55), bottom, rng:NextNumber(20, 40))
	end
	return f
end

---------------------------------------------------------------- the island: half circle, dock with wings, plots
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

-- A half disc, its flat edge on z = 0 and its round side toward -Z: a block over the middle and a fan of slices round it
local function halfDisc(parent: Instance, name: string, radius: number, top: number, thickness: number, colour: Color3)
	local inner = radius * 0.7
	part(parent, name, Vector3.new(inner * 2, thickness, inner), CFrame.new(0, top - thickness / 2, -inner / 2), colour)
	local slices = 18
	local step = math.pi / slices
	local r0 = radius * 0.6
	for k = 0, slices - 1 do
		local a = math.pi / 2 + step * (k + 0.5)
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		local r1 = radius * math.cos(step / 2)
		local mid = dir * (r0 + r1) / 2 + Vector3.new(0, top - thickness / 2, 0)
		part(
			parent,
			name,
			Vector3.new(2 * radius * math.sin(step / 2) + 1, thickness, r1 - r0),
			CFrame.lookAt(mid, mid + dir),
			colour
		)
	end
end

local function buildPlot(parent: Instance, index: number, degrees: number)
	local a = math.rad(degrees)
	local at = Vector3.new(math.sin(a) * PLOT_RADIUS, DECK_Y, math.cos(a) * PLOT_RADIUS)
	local face = CFrame.lookAt(at, SPAWN) -- local -Z toward the spawn: the plot's front
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
	for side = -1, 1, 2 do
		part(
			f,
			"SignPost",
			Vector3.new(2, 10, 2),
			face * CFrame.new(side * 22, 2 + TANK_SIZE.Y + 5, tz - TANK_SIZE.Z / 2),
			rgb(90, 70, 55)
		)
	end
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
	-- the boardwalk from the plot's front to the plaza (it ends under the plaza's deck)
	local front = (face * CFrame.new(0, 0, -d / 2)).Position
	local toSpawn = (SPAWN - front) * Vector3.new(1, 0, 1)
	local walk = toSpawn.Magnitude - 70
	local mid = front + toSpawn.Unit * (walk / 2 - 1)
	part(
		f,
		"Walk",
		Vector3.new(18, 1, walk + 2),
		CFrame.lookAt(mid, mid + toSpawn) * CFrame.new(0, -0.7, 0),
		rgb(160, 120, 80)
	)
end

local function buildDock(): Folder
	local dock = folder("Dock")
	dock:SetAttribute("Shape", "half circle, flat edge to the dive")
	-- the island: a sandy half disc on a mound that runs out just under the water
	halfDisc(dock, "Shelf", ISLAND_SHELF, -2, -2 - LAGOON_Y + 2, rgb(220, 200, 150))
	halfDisc(dock, "Island", ISLAND_RADIUS, ISLAND_TOP, 6, rgb(240, 226, 178))
	-- the plaza round the spawn and the dock along the flat edge, its wings holding the shops
	part(
		dock,
		"Plaza",
		Vector3.new(PLAZA.X, 1, PLAZA.Y),
		CFrame.new(0, DECK_Y - 0.5, DOCK.Back - PLAZA.Y / 2),
		rgb(160, 120, 80)
	)
	local dockDepth = DOCK.Front - DOCK.Back
	part(
		dock,
		"DockDeck",
		Vector3.new(DOCK.HalfWidth * 2, 2, dockDepth),
		CFrame.new(0, DECK_Y - 1, (DOCK.Front + DOCK.Back) / 2),
		rgb(170, 128, 85)
	)
	for x = -DOCK.HalfWidth + 10, DOCK.HalfWidth - 10, 58 do
		for _, z in { 18, DOCK.Front - 3 } do
			part(
				dock,
				"Stilt",
				Vector3.new(3, DECK_Y - LAGOON_Y, 3),
				CFrame.new(x, (DECK_Y + LAGOON_Y) / 2, z),
				rgb(110, 80, 55)
			)
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = ORIGIN * CFrame.lookAt(SPAWN + Vector3.new(0, 0.5, 0), SPAWN + Vector3.new(0, 0.5, 1)) -- facing the dive
	spawn.Enabled = false -- a marker only: the game puts characters on it (RideService)
	spawn.Color = rgb(255, 255, 255)
	spawn.Parent = dock
	figure(dock, CFrame.new(SPAWN + Vector3.new(10, 0, 0)))

	local plots = folder("Plots", dock)
	for index, degrees in PLOT_ANGLES do
		buildPlot(plots, index, degrees)
	end

	local function station(name: string, at: Vector3, size: Vector3, colour: Color3, lookAt: Vector3)
		local face = CFrame.lookAt(at, lookAt)
		local f = folder(name, dock)
		f:SetAttribute("Station", name)
		part(f, "Stall", size, face * CFrame.new(0, size.Y / 2, 0), colour)
		part(
			f,
			"Awning",
			Vector3.new(size.X + 4, 1.5, size.Z * 0.7),
			face * CFrame.new(0, size.Y + 3, -size.Z * 0.55) * CFrame.Angles(math.rad(-12), 0, 0),
			colour:Lerp(rgb(255, 255, 255), 0.5)
		)
		sign(f, name, face * CFrame.new(0, size.Y + 8, -size.Z / 2), math.max(size.X, 16), 5, colour)
	end
	-- the shops on the wings, facing the walk from the spawn to the board
	local stallSize = Vector3.new(22, 10, 12)
	station("SELL", Vector3.new(-160, DECK_Y, 15), stallSize, rgb(230, 170, 50), Vector3.new(0, DECK_Y, 15))
	station("AURAS", Vector3.new(-235, DECK_Y, 15), stallSize, rgb(150, 90, 220), Vector3.new(0, DECK_Y, 15))
	station("INDEX", Vector3.new(160, DECK_Y, 15), stallSize, rgb(60, 160, 230), Vector3.new(0, DECK_Y, 15))
	station("FUSE", Vector3.new(235, DECK_Y, 15), stallSize, rgb(90, 200, 120), Vector3.new(0, DECK_Y, 15))
	station("TOP EARNERS", Vector3.new(0, DECK_Y, SPAWN.Z - 55), Vector3.new(30, 18, 2), rgb(30, 30, 40), SPAWN)

	-- palms round the rim between the plots, at the dock's ends and the plaza's corners
	local palms = {}
	for degrees = 120, 240, 20 do
		table.insert(
			palms,
			Vector3.new(math.sin(math.rad(degrees)) * 395, ISLAND_TOP, math.cos(math.rad(degrees)) * 395)
		)
	end
	for _, at in
		{
			Vector3.new(-335, ISLAND_TOP, -25),
			Vector3.new(335, ISLAND_TOP, -25),
			Vector3.new(-370, ISLAND_TOP, -70),
			Vector3.new(370, ISLAND_TOP, -70),
			Vector3.new(-130, ISLAND_TOP, -115),
			Vector3.new(130, ISLAND_TOP, -115),
		}
	do
		table.insert(palms, at)
	end
	for _, at in palms do
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

	-- the DIVE gate at the dock's front edge, and the board out over the lagoon
	for side = -1, 1, 2 do
		part(dock, "GatePost", Vector3.new(3, 20, 3), CFrame.new(side * 13, DECK_Y + 10, GATE_Z), rgb(240, 240, 240))
	end
	sign(dock, "DIVE", CFrame.new(0, DECK_Y + 22, GATE_Z), 30, 6, rgb(230, 60, 60))
	part(
		dock,
		"DiveBoard",
		Vector3.new(6, 1, 22),
		CFrame.new(0, DECK_Y + 1.5, BOARD_Z) * CFrame.Angles(math.rad(-6), 0, 0),
		rgb(240, 240, 240)
	)
	figure(dock, CFrame.new(0, DECK_Y + 2.5, BOARD_Z + 6))
	-- the sub, moored off the dock's east end
	part(dock, "Sub", Vector3.new(10, 8, 22), CFrame.new(DOCK.HalfWidth + 16, 1, 30), rgb(250, 210, 40))
	sign(dock, "SUB", CFrame.new(DOCK.HalfWidth - 6, DECK_Y + 6, DOCK.Front - 4), 10, 3, rgb(250, 210, 40))

	-- dock props: posts along the front edge, buoys along the channel, crates and barrels by the shops
	local props = folder("Props", dock)
	for x = -DOCK.HalfWidth + 20, DOCK.HalfWidth - 20, 40 do
		if math.abs(x) > 30 then
			prop(props, "dock_post", CFrame.new(x, DECK_Y, DOCK.Front - 1), 1)
		end
	end
	for k = 1, 6 do
		local side = if k % 2 == 0 then -1 else 1
		prop(props, "buoy", CFrame.new(side * rng:NextNumber(150, 200), 0, 120 + k * 90), 1.6)
	end
	prop(props, "lifebuoy", CFrame.new(-12.5, DECK_Y + 2, GATE_Z + 3) * CFrame.Angles(0, math.pi / 2, 0), 1.5)
	prop(props, "lifebuoy", CFrame.new(12.5, DECK_Y + 2, GATE_Z + 3) * CFrame.Angles(0, math.pi / 2, 0), 1.5)
	local stacks = {
		{ "crate_stack", Vector3.new(-200, DECK_Y, 35) },
		{ "barrel", Vector3.new(-190, DECK_Y, -5) },
		{ "crate", Vector3.new(-268, DECK_Y, 30) },
		{ "rope_coil", Vector3.new(-120, DECK_Y, 40) },
		{ "crate_stack", Vector3.new(200, DECK_Y, 35) },
		{ "barrel", Vector3.new(190, DECK_Y, -5) },
		{ "crate", Vector3.new(268, DECK_Y, 30) },
		{ "rope_coil", Vector3.new(282, DECK_Y, 42) },
	}
	for _, spec in stacks do
		prop(props, spec[1], CFrame.new(spec[2]) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), 1.4)
	end
	local beach = { "starfish", "shell_scallop", "shell_conch", "sea_grass_clump" }
	for _ = 1, 14 do -- starfish and shells on the beach round the curved side
		local a = rng:NextNumber(math.pi * 0.55, math.pi * 1.45)
		local r = rng:NextNumber(ISLAND_RADIUS - 25, ISLAND_RADIUS - 4)
		prop(
			props,
			beach[rng:NextInteger(1, 4)],
			CFrame.new(math.sin(a) * r, ISLAND_TOP, math.cos(a) * r) * CFrame.Angles(0, a, 0),
			1.6
		)
	end
	cluster(
		props,
		"cluster_lagoon_small",
		CFrame.lookAt(Vector3.new(-330, ISLAND_TOP, -150), Vector3.new(0, ISLAND_TOP, -40)),
		1.2,
		flatFloor(ISLAND_TOP)
	)
	cluster(
		props,
		"cluster_lagoon_small",
		CFrame.lookAt(Vector3.new(330, ISLAND_TOP, -150), Vector3.new(0, ISLAND_TOP, -40)),
		1.2,
		flatFloor(ISLAND_TOP)
	)
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

-- The lane's lining: huge clusters either side of each landmark, then medium and small ones alternating sides between,
-- with a small one higher up the bank behind every third
local function lineLane(f: Instance, i: number, landmarks: { number })
	local zone = ZONES[i]
	local family = zone.Family
	local s0, s1 = starts[i], starts[i] + zone.Length
	local gateS = s0 + ramps[i] + 40
	local deep = zone.Look.Glow ~= nil
	for _, s in landmarks do
		if s > s0 + 40 and s < s1 - 40 then
			for side = -1, 1, 2 do
				local ls = s + side * 35
				laneCluster(
					f,
					"cluster_" .. family .. "_huge",
					ls,
					side * (shapeAt(ls).Lane / 2 + 45),
					rng:NextNumber(1.6, 2.0),
					deep
				)
			end
		end
	end
	local side = if i % 2 == 0 then 1 else -1
	local k = 0
	local s = s0 + 70
	while s < s1 - 70 do
		local clear = math.abs(s - gateS) > 60
		for _, mark in landmarks do
			if math.abs(s - mark) < 120 then
				clear = false
			end
		end
		if clear then
			k += 1
			local size = if k % 2 == 1 then "medium" else "small"
			local shape = shapeAt(s)
			local half = shape.Lane / 2
			local scale = rng:NextNumber(1.5, 1.9)
			laneCluster(
				f,
				"cluster_" .. family .. "_" .. size,
				s,
				side * (half + (if size == "medium" then 22 else 12) * scale),
				scale
			)
			if k % 3 == 0 then
				local up = s + rng:NextNumber(30, 60)
				laneCluster(
					f,
					"cluster_" .. family .. "_small",
					up,
					side * (half + shapeAt(up).Tiers[1][1] * 0.85),
					scale * 1.15
				)
			end
			side = -side
		end
		s += LINE_SPACING + rng:NextNumber(-30, 30)
	end
end

-- Huge shapes far off in the open water either side: what makes the ocean feel big, seen through the haze
local function silhouettes(f: Folder, i: number)
	local zone = ZONES[i]
	local count = if i == 1 then 2 else 4
	for n = 1, count do
		local side = if n % 2 == 0 then -1 else 1
		local s = rng:NextNumber(starts[i], starts[i] + zone.Length)
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

local SHAFTS: { [string]: { any } } = { -- zone = { count, colours }
	SHALLOWS = { 16, SUN_SHAFT },
	["CORAL REEF"] = { 14, SUN_SHAFT },
	["KELP FOREST"] = { 12, { rgb(235, 255, 200), rgb(150, 230, 160) } },
	SHIPWRECKS = { 5, { rgb(210, 240, 240), rgb(120, 190, 200) } },
}

local function lookAttributes(f: Instance, look: Look)
	f:SetAttribute("LookFog", look.Fog)
	f:SetAttribute("LookFogEnd", look.FogEnd)
	f:SetAttribute("LookAmbient", look.Ambient)
	f:SetAttribute("LookOutdoor", look.Outdoor)
	f:SetAttribute("LookBrightness", look.Brightness)
	f:SetAttribute("LookTint", look.Tint)
	if look.Glow then
		f:SetAttribute("LookGlow", look.Glow)
	end
end

local function buildZone(index: number, dive: Folder): Folder
	local zone = ZONES[index]
	local s0, s1 = starts[index], starts[index] + zone.Length
	local f = folder(string.format("%02d_%s", index, zone.Name))
	f:SetAttribute("ZoneName", zone.Name)
	f:SetAttribute("Metres", zone.Metres)
	f:SetAttribute("Signature", zone.Signature)
	lookAttributes(f, zone.Look)

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
		gate * CFrame.new(0, 57, 0),
		math.min(half * 2 - 20, 90),
		14,
		zone.Rock
	)
	ceiling(gs - 4, gs + 4, 50)

	-- the zone's signature formation, then the clusters lining the lane round it
	local formationsFolder = folder("Formations", f)
	local landmarks = SIGNATURES[zone.Signature](formationsFolder, index, function(u: number): number
		return s0 + zone.Length * u
	end)
	lineLane(folder("Clusters", f), index, landmarks)
	local set = folder("SetPieces", f)
	silhouettes(set, index)

	-- light shafts from the surface where the sun still reaches
	local shafts = SHAFTS[zone.Name]
	if shafts then
		local anchor = part(
			set,
			"ShaftAnchor",
			Vector3.new(1, 1, 1),
			CFrame.new(centre((s0 + s1) / 2)),
			rgb(255, 255, 255),
			{ Transparency = 1, CanCollide = false }
		)
		for _ = 1, shafts[1] do
			local bs = rng:NextNumber(s0, s1)
			local w = shapeAt(bs).Lane / 2
			local bottom = ground(bs, rng:NextNumber(-w * 1.3, w * 1.3))
			lightShaft(anchor, bottom + Vector3.new(-40, -bottom.Y, -90), bottom, rng:NextNumber(20, 45), shafts[2])
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
local looks = {}
for index, zone in ZONES do
	buildZone(index, dive)
	local s0, s1 = starts[index], starts[index] + zone.Length
	local a, b = centre(s0), centre(s1)
	local function c3(c: Color3): { number }
		return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
	end
	local look = zone.Look
	local lookJson = {
		S = s0,
		Fog = c3(look.Fog),
		FogEnd = look.FogEnd,
		Ambient = c3(look.Ambient),
		Outdoor = c3(look.Outdoor),
		Brightness = look.Brightness,
		Tint = c3(look.Tint),
		Glow = if look.Glow then c3(look.Glow) else nil,
	}
	table.insert(looks, lookJson)
	table.insert(info, {
		Name = zone.Name,
		Metres = zone.Metres,
		Z0 = LANE_START + s0, -- along the lane from the island, for tools/art/depth_profile.py
		Z1 = LANE_START + s1,
		S0 = s0,
		S1 = s1,
		Y0 = a.Y,
		Y1 = b.Y,
		Start = { a.X, a.Z },
		End = { b.X, b.Z },
		Heading = zone.Heading,
		Ramp = ramps[index],
		Signature = zone.Signature,
		Look = lookJson,
	})
	task.wait()
end

local function r1(v: number): number
	return math.floor(v * 10 + 0.5) / 10
end
local path = {}
for s = 0, TOTAL, PATH_SAMPLE do
	local p = (ORIGIN * CFrame.new(centre(s))).Position
	local clear = 0
	for _, span in ceilings do
		if span[2] >= s - PATH_SAMPLE / 2 and span[1] <= s + PATH_SAMPLE / 2 then
			clear = if clear == 0 then span[3] else math.min(clear, span[3])
		end
	end
	table.insert(path, { r1(s), r1(p.X), r1(p.Y), r1(p.Z), r1(shapeAt(s).Lane), clear })
end
dive:SetAttribute("Path", HttpService:JSONEncode(path))
dive:SetAttribute("Looks", HttpService:JSONEncode(looks))

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
local lights, beams = 0, 0
for _, d in root:GetDescendants() do
	if d:IsA("Model") and d:GetAttribute("PropName") then
		models += 1
	elseif d:IsA("PointLight") then
		lights += 1
	elseif d:IsA("Beam") then
		beams += 1
	end
end
local spawnWorld = ORIGIN * CFrame.new(SPAWN)
return HttpService:JSONEncode({
	Version = 4,
	Parts = count,
	PartsByFolder = byFolder,
	PropModels = models,
	ClusterModels = clusterCount,
	PointLights = lights,
	Beams = beams,
	BottomMetres = BOTTOM_METRES,
	Origin = { 3000, 0, 0 },
	LaneStart = LANE_START,
	LagoonY = LAGOON_Y, -- the lagoon floor; the Shallows' lane is a stud above it (map_plot.py draws it)
	Spawn = { spawnWorld.X, spawnWorld.Y, spawnWorld.Z },
	DiveBoard = { 3000, DECK_Y, BOARD_Z + 11 },
	Zones = info,
	Formations = formations,
	Ceilings = ceilings,
	PathFields = "s, x, y, z, w (lane width), c (clearance above the floor under a formation, 0 = open)",
	Path = path,
})
