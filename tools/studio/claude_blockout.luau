--!strict
-- Claude's blockout of Ride a Fish (docs/blockout.md). v2, 2026-11-09: the user found v1's 30-degree dive dropped far too
-- fast, using up the depth early. The dive is now long and gradual, sized after the reference's measured run (zone 1 about
-- 1,000, later zones about 2,500, ridden at about 55 a second): 10 zones, 23,500 studs, 2 degrees inside each zone plus a
-- drop-off at most borders. Also the world round it: the dock in a lagoon ringed by reef, open ocean beyond, stepped
-- terraces either side of the lane, big silhouettes far off in the water, light shafts near the top.
-- Run in Edit mode through the Studio connector. Rebuilds Workspace.ClaudeBlockout; touches nothing else.
-- Returns the zones' start and end points as JSON (tools/art/depth_profile.py draws the side view from it).
-- Axes: the sea surface is y = 0, the dock is centred on the origin, and the dive heads away along +Z, going down.

local HttpService = game:GetService("HttpService")

local ORIGIN = CFrame.new(3000, 0, 0) -- off the baseplate, which would hide everything under the sea
local PLAYER = 5 -- a player is about 5 studs tall
local DECK_Y = 4 -- top of the dock's boards
local PLAZA_RADIUS = 130
local TANK_RADIUS = 105
local TANK_ANGLES = { 60, 90, 120, 150, -60, -90, -120, -150 } -- degrees from +Z; the open side (0) faces the pier
local PIER_END = 240
local LAGOON_Y = -30 -- the lagoon's sandy floor round the dock
local LAGOON_RADIUS = 560 -- the ring reef round the lagoon
local RING_GAP = 30 -- degrees either side of +Z left open where the dive leaves the lagoon
local LANE_START_Z = 260
local DEEP_PLANE_Y = -300 -- under the open sea near the dock, so it reads deep blue from above
local TILE = 2048 -- the largest a part can be

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

type Zone = {
	Name: string,
	Metres: number, -- the real-ocean depth the gauge shows where the zone begins
	Length: number, -- along Z
	Slope: number, -- degrees down inside the zone
	Drop: number, -- the drop-off before the zone
	Lane: number, -- the lane's width
	Floor: Color3,
	Rock: Color3,
	Tiers: { { number } }, -- terraces stepping out from the lane: { width, height above the floor }
	Dress: string,
	Fish: Vector3,
	FishColour: Color3,
}

-- stylua: ignore
local ZONES: { Zone } = {
	{ Name = "SHALLOWS", Metres = 0, Length = 1000, Slope = 1.5, Drop = 0, Lane = 260, Floor = rgb(236, 222, 172), Rock = rgb(214, 196, 150), Tiers = { { 120, 8 }, { 200, 20 } }, Dress = "Seagrass", Fish = Vector3.new(2, 1.5, 4), FishColour = rgb(255, 220, 90) },
	{ Name = "CORAL REEF", Metres = 10, Length = 2500, Slope = 2, Drop = 20, Lane = 220, Floor = rgb(226, 205, 150), Rock = rgb(235, 140, 150), Tiers = { { 80, 30 }, { 140, 50 }, { 220, 68 } }, Dress = "Coral", Fish = Vector3.new(3, 2.5, 6), FishColour = rgb(255, 140, 80) },
	{ Name = "KELP FOREST", Metres = 40, Length = 2500, Slope = 2, Drop = 40, Lane = 240, Floor = rgb(110, 115, 80), Rock = rgb(90, 120, 100), Tiers = { { 100, 60 }, { 160, 140 }, { 240, 240 } }, Dress = "Kelp", Fish = Vector3.new(4, 3, 8), FishColour = rgb(140, 220, 120) },
	{ Name = "SHIPWRECKS", Metres = 80, Length = 2500, Slope = 2, Drop = 40, Lane = 260, Floor = rgb(150, 140, 120), Rock = rgb(120, 110, 100), Tiers = { { 120, 50 }, { 180, 120 } }, Dress = "Wrecks", Fish = Vector3.new(5, 4, 10), FishColour = rgb(200, 200, 210) },
	{ Name = "OPEN BLUE", Metres = 150, Length = 2500, Slope = 2, Drop = 150, Lane = 400, Floor = rgb(80, 110, 150), Rock = rgb(70, 100, 140), Tiers = { { 200, 25 } }, Dress = "Open", Fish = Vector3.new(7, 5, 16), FishColour = rgb(90, 150, 255) },
	{ Name = "TWILIGHT", Metres = 200, Length = 2500, Slope = 2, Drop = 80, Lane = 200, Floor = rgb(60, 60, 100), Rock = rgb(55, 50, 95), Tiers = { { 80, 90 }, { 160, 200 }, { 260, 340 } }, Dress = "Arches", Fish = Vector3.new(9, 6, 20), FishColour = rgb(150, 110, 255) },
	{ Name = "MIDNIGHT", Metres = 1000, Length = 2500, Slope = 2, Drop = 80, Lane = 240, Floor = rgb(35, 35, 60), Rock = rgb(30, 30, 55), Tiers = { { 120, 70 }, { 200, 160 } }, Dress = "Jellies", Fish = Vector3.new(10, 7, 22), FishColour = rgb(60, 230, 255) },
	{ Name = "VENTS", Metres = 2000, Length = 2500, Slope = 2, Drop = 80, Lane = 220, Floor = rgb(40, 32, 32), Rock = rgb(30, 25, 25), Tiers = { { 90, 80 }, { 150, 180 }, { 240, 300 } }, Dress = "Chimneys", Fish = Vector3.new(11, 8, 24), FishColour = rgb(255, 120, 40) },
	{ Name = "BONE GRAVEYARD", Metres = 4000, Length = 2500, Slope = 2, Drop = 80, Lane = 320, Floor = rgb(70, 70, 80), Rock = rgb(60, 60, 70), Tiers = { { 160, 40 }, { 260, 90 } }, Dress = "Bones", Fish = Vector3.new(12, 9, 28), FishColour = rgb(230, 230, 240) },
	{ Name = "THE UNDERWORLD", Metres = 6000, Length = 2500, Slope = 2, Drop = 200, Lane = 140, Floor = rgb(30, 20, 30), Rock = rgb(25, 15, 25), Tiers = { { 60, 260 }, { 120, 520 } }, Dress = "Cracks", Fish = Vector3.new(14, 10, 32), FishColour = rgb(255, 60, 60) },
}
local BOTTOM_METRES = 10935 -- the Challenger Deep, shown at the bottom of the Underworld

local rng = Random.new(20261109)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	props: { [string]: any }?
): Part
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
local function sign(parent: Instance, text: string, cf: CFrame, width: number, height: number, colour: Color3)
	local board = part(parent, "Sign", Vector3.new(width, height, 1), cf, colour)
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

local root = folder("ClaudeBlockout")

---------------------------------------------------------------- the surface: sea tiles and the deep plane
local function buildSurface(): Folder
	local f = folder("Surface") -- tools/studio/depth_look_test.luau restyles the sea tiles for the underwater looks
	for x = -1, 1 do
		for z = -1, 12 do
			part(
				f,
				"SeaTile",
				Vector3.new(TILE, 1, TILE),
				CFrame.new(x * TILE, -0.5, z * TILE + TILE / 2),
				rgb(40, 140, 200),
				{ Transparency = 0.35, CanCollide = false, CastShadow = false }
			)
		end
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
	-- the sandy floor, leaving the dive's channel open where the lane runs out of the lagoon
	part(
		f,
		"Floor",
		Vector3.new(LAGOON_RADIUS * 2, 4, LAGOON_RADIUS + LANE_START_Z),
		CFrame.new(0, LAGOON_Y - 2, (LANE_START_Z - LAGOON_RADIUS) / 2),
		sand
	)
	local sideWidth = LAGOON_RADIUS - laneHalf
	for side = -1, 1, 2 do
		part(
			f,
			"Floor",
			Vector3.new(sideWidth, 4, LAGOON_RADIUS - LANE_START_Z),
			CFrame.new(side * (laneHalf + sideWidth / 2), LAGOON_Y - 2, (LANE_START_Z + LAGOON_RADIUS) / 2),
			sand
		)
	end
	-- the ring reef: rocks and coral heads round the lagoon, some breaking the surface, open toward the dive
	for degrees = -174, 180, 12 do
		if math.abs(degrees) > RING_GAP then
			local a = math.rad(degrees + rng:NextNumber(-3, 3))
			local r = LAGOON_RADIUS + rng:NextNumber(-30, 30)
			local top = if rng:NextNumber() < 0.6 then rng:NextNumber(4, 40) else rng:NextNumber(-12, -3)
			local width = rng:NextNumber(80, 140)
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
	return f
end

---------------------------------------------------------------- the dock (as in v1)
local function buildDock(): Folder
	local dock = folder("Dock")
	part(
		dock,
		"Plaza",
		Vector3.new(4, PLAZA_RADIUS * 2, PLAZA_RADIUS * 2),
		CFrame.new(0, DECK_Y - 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(160, 120, 80),
		{ Shape = Enum.PartType.Cylinder }
	)
	for i = 0, 7 do
		local a = math.rad(i * 45)
		part(
			dock,
			"Stilt",
			Vector3.new(4, DECK_Y - LAGOON_Y, 4),
			CFrame.new(math.sin(a) * 110, (DECK_Y + LAGOON_Y) / 2, math.cos(a) * 110),
			rgb(110, 80, 55)
		)
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = ORIGIN * CFrame.new(0, DECK_Y + 0.5, 0)
	spawn.Enabled = false -- a marker only: players keep spawning on the place's own spawn
	spawn.Color = rgb(255, 255, 255)
	spawn.Parent = dock
	figure(dock, CFrame.new(10, DECK_Y, 0))

	for index, degrees in TANK_ANGLES do
		local a = math.rad(degrees)
		local at = Vector3.new(math.sin(a) * TANK_RADIUS, DECK_Y, math.cos(a) * TANK_RADIUS)
		local face = CFrame.lookAt(at, Vector3.new(0, DECK_Y, 0))
		local tank = folder("Tank" .. index, dock)
		part(tank, "Base", Vector3.new(36, 2, 26), face * CFrame.new(0, 1, 0), rgb(70, 70, 80))
		part(
			tank,
			"Glass",
			Vector3.new(34, 22, 24),
			face * CFrame.new(0, 13, 0),
			rgb(190, 230, 255),
			{ Material = Enum.Material.Glass, Transparency = 0.7, CanCollide = false }
		)
		part(
			tank,
			"Water",
			Vector3.new(33, 18, 23),
			face * CFrame.new(0, 11, 0),
			rgb(40, 140, 220),
			{ Transparency = 0.5, CanCollide = false }
		)
		for k = 1, 3 do
			part(
				tank,
				"Creature",
				Vector3.new(3, 2.5, 7),
				face * CFrame.new(-10 + k * 5, 6 + k * 3, rng:NextNumber(-6, 6)) * CFrame.Angles(0, math.rad(90), 0),
				rgb(250, 150, 80)
			)
		end
		sign(tank, "PLAYER " .. index, face * CFrame.new(0, 27, -12), 20, 4, rgb(40, 60, 90))
	end

	local function station(
		name: string,
		degrees: number,
		radius: number,
		size: Vector3,
		colour: Color3
	): (CFrame, Folder)
		local a = math.rad(degrees)
		local at = Vector3.new(math.sin(a) * radius, DECK_Y, math.cos(a) * radius)
		local face = CFrame.lookAt(at, Vector3.new(0, DECK_Y, 0))
		local f = folder(name, dock)
		part(f, "Stall", size, face * CFrame.new(0, size.Y / 2, 0), colour)
		sign(f, name, face * CFrame.new(0, size.Y + 4, -size.Z / 2), math.max(size.X, 14), 4, colour)
		return face, f
	end
	for i = 0, 3 do
		local face, f = station(
			if i == 0 then "TRAINING" else "Ride" .. i,
			-60 + i * 10,
			70,
			Vector3.new(5, 4, 5),
			rgb(230, 90, 90)
		)
		part(f, "Toy", Vector3.new(3, 3, 6), face * CFrame.new(0, 5.5, 0), rgb(90, 200, 230))
	end
	station("AURAS", 25, 70, Vector3.new(14, 8, 8), rgb(150, 90, 220))
	station("SELL", 45, 72, Vector3.new(14, 8, 8), rgb(230, 170, 50))
	station("TOP EARNERS", 180, 55, Vector3.new(24, 16, 2), rgb(30, 30, 40))

	local pierLength = PIER_END - (PLAZA_RADIUS - 6)
	part(
		dock,
		"Pier",
		Vector3.new(22, 2, pierLength),
		CFrame.new(0, DECK_Y - 1, PLAZA_RADIUS - 6 + pierLength / 2),
		rgb(160, 120, 80)
	)
	for z = PLAZA_RADIUS + 10, PIER_END, 30 do
		for side = -1, 1, 2 do
			part(
				dock,
				"Stilt",
				Vector3.new(3, DECK_Y - LAGOON_Y, 3),
				CFrame.new(side * 10, (DECK_Y + LAGOON_Y) / 2, z),
				rgb(110, 80, 55)
			)
		end
	end
	local gateZ = 190
	for side = -1, 1, 2 do
		part(dock, "GatePost", Vector3.new(3, 20, 3), CFrame.new(side * 12, DECK_Y + 10, gateZ), rgb(240, 240, 240))
	end
	sign(dock, "DIVE", CFrame.new(0, DECK_Y + 22, gateZ), 28, 6, rgb(230, 60, 60))
	part(
		dock,
		"DiveBoard",
		Vector3.new(6, 1, 20),
		CFrame.new(0, DECK_Y + 3, PIER_END + 8) * CFrame.Angles(math.rad(-8), 0, 0),
		rgb(240, 240, 240)
	)
	figure(dock, CFrame.new(0, DECK_Y + 4, PIER_END + 14))
	part(dock, "SubJetty", Vector3.new(14, 2, 50), CFrame.new(26, DECK_Y - 1, 175), rgb(160, 120, 80))
	part(dock, "Sub", Vector3.new(10, 8, 22), CFrame.new(42, 1, 175), rgb(250, 210, 40))
	sign(dock, "SUB", CFrame.new(26, DECK_Y + 6, 152), 10, 3, rgb(250, 210, 40))
	return dock
end

---------------------------------------------------------------- the dive
-- The floor's frame for a zone: at its middle, local +Z down the slope, local +Y up off the floor
local function frameFor(z0: number, y0: number, length: number, slope: number): (CFrame, number)
	local a = math.rad(slope)
	local mid = Vector3.new(0, y0 - length / 2 * math.tan(a), z0 + length / 2)
	return CFrame.new(mid) * CFrame.Angles(a, 0, 0), length / math.cos(a)
end

-- A point on the floor: x across, s along the slope from the zone's middle
local function floorPoint(frame: CFrame, x: number, s: number): Vector3
	return (frame * CFrame.new(x, 0, s)).Position
end

local function totalWidth(zone: Zone): number
	local w = zone.Lane
	for _, tier in zone.Tiers do
		w += tier[1] * 2
	end
	return w
end

local function dress(f: Folder, zone: Zone, frame: CFrame, slopeLength: number)
	local half = zone.Lane / 2
	local function anywhere(margin: number): Vector3
		return floorPoint(
			frame,
			rng:NextNumber(-half + margin, half - margin),
			rng:NextNumber(-slopeLength / 2, slopeLength / 2)
		)
	end
	-- a point on top of the first terrace, either side
	local function onTerrace(): Vector3
		local tier = zone.Tiers[1]
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		return floorPoint(
			frame,
			side * (half + rng:NextNumber(10, tier[1] - 10)),
			rng:NextNumber(-slopeLength / 2, slopeLength / 2)
		) + Vector3.new(0, tier[2], 0)
	end
	local kind = zone.Dress
	if kind == "Seagrass" then
		for _ = 1, 40 do
			local at = if rng:NextNumber() < 0.6 then anywhere(10) else onTerrace()
			local h = rng:NextNumber(4, 10)
			part(f, "Seagrass", Vector3.new(1.5, h, 1.5), CFrame.new(at + Vector3.new(0, h / 2, 0)), rgb(110, 190, 90))
		end
	elseif kind == "Coral" then
		local colours = { rgb(255, 120, 140), rgb(255, 170, 80), rgb(180, 110, 230), rgb(90, 220, 200) }
		for n = 1, 50 do
			local at = if n <= 30 then anywhere(10) else onTerrace()
			local s = rng:NextNumber(6, 18)
			part(
				f,
				"Coral",
				Vector3.new(s, s, s),
				CFrame.new(at + Vector3.new(0, s * 0.3, 0)),
				colours[rng:NextInteger(1, 4)],
				{ Shape = Enum.PartType.Ball }
			)
		end
		for _ = 1, 12 do
			local h = rng:NextNumber(14, 26)
			part(
				f,
				"Fan",
				Vector3.new(1, h, h * 0.7),
				CFrame.new(anywhere(15) + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				colours[rng:NextInteger(1, 4)]
			)
		end
	elseif kind == "Kelp" then
		for n = 1, 80 do
			local at = if n <= 40 then anywhere(8) else onTerrace()
			local h = rng:NextNumber(60, 140)
			part(f, "Kelp", Vector3.new(3, h, 3), CFrame.new(at + Vector3.new(0, h / 2, 0)), rgb(70, 150, 70))
		end
	elseif kind == "Wrecks" then
		for n = 1, 4 do
			local at = if n <= 3 then anywhere(50) else onTerrace()
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
			local s = -slopeLength / 2 + k * slopeLength / 5
			for side = -1, 1, 2 do
				part(
					f,
					"ArchLeg",
					Vector3.new(18, 110, 18),
					CFrame.new(floorPoint(frame, side * (half - 12), s) + Vector3.new(0, 55, 0)),
					zone.Rock
				)
			end
			part(
				f,
				"ArchTop",
				Vector3.new(zone.Lane, 20, 18),
				CFrame.new(floorPoint(frame, 0, s) + Vector3.new(0, 115, 0)),
				zone.Rock
			)
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
			local at = if n <= 9 then anywhere(20) else onTerrace()
			local h = rng:NextNumber(30, 90)
			local w = rng:NextNumber(12, 20)
			part(f, "Chimney", Vector3.new(w, h, w), CFrame.new(at + Vector3.new(0, h / 2, 0)), rgb(25, 20, 20))
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
		for _ = 1, 20 do
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local h = rng:NextNumber(20, 60)
			local at = floorPoint(frame, side * (half - 0.4), rng:NextNumber(-slopeLength / 2, slopeLength / 2))
				+ Vector3.new(0, rng:NextNumber(20, 200), 0)
			part(
				f,
				"Crack",
				Vector3.new(1, h, rng:NextNumber(2, 5)),
				CFrame.new(at) * CFrame.Angles(math.rad(rng:NextNumber(-30, 30)), 0, 0),
				rgb(255, 50, 40),
				{ Material = Enum.Material.Neon }
			)
		end
		-- the Megalodon at the end, coming up the trench toward the rider
		local meg = frame * CFrame.new(0, 45, slopeLength / 2 - 140) * CFrame.Angles(0, math.pi, 0)
		part(f, "Megalodon", Vector3.new(18, 16, 64), meg, rgb(70, 75, 90))
		part(f, "Fin", Vector3.new(2, 16, 14), meg * CFrame.new(0, 15, 4), rgb(70, 75, 90))
		part(f, "Tail", Vector3.new(2, 24, 10), meg * CFrame.new(0, 0, 36), rgb(70, 75, 90))
		-- the end of the dive: the trench closes in a wall, the Megalodon's lair
		part(
			f,
			"EndWall",
			Vector3.new(totalWidth(zone) + 200, 900, 20),
			frame * CFrame.new(0, 400, slopeLength / 2 + 10),
			zone.Rock
		)
	end
end

-- Huge shapes far off in the open water either side: what makes the ocean feel big, seen through the haze
local function silhouettes(f: Folder, zone: Zone, frame: CFrame, slopeLength: number)
	local count = if zone.Name == "SHALLOWS" then 2 else 4
	for n = 1, count do
		local side = if n % 2 == 0 then -1 else 1
		local distance = rng:NextNumber(700, 1400)
		local s = rng:NextNumber(-slopeLength / 2, slopeLength / 2)
		local base = floorPoint(frame, side * distance, s)
		if zone.Dress == "Open" then -- whales cruising far off
			local body = CFrame.new(base + Vector3.new(0, rng:NextNumber(120, 300), 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			part(f, "Whale", Vector3.new(50, 44, 190), body, rgb(60, 80, 110))
			part(f, "Fluke", Vector3.new(70, 6, 26), body * CFrame.new(0, 0, 110), rgb(60, 80, 110))
		elseif zone.Dress == "Kelp" then -- giant kelp towers
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

local function buildZone(index: number, zone: Zone, z0: number, y0: number, previous: Zone?): (Folder, number)
	local f = folder(string.format("%02d_%s", index, zone.Name))
	local frame, slopeLength = frameFor(z0, y0, zone.Length, zone.Slope)
	local half = zone.Lane / 2

	if previous and zone.Drop > 0 then -- the drop-off: the previous zone's floor ends in a cliff
		local width = math.max(totalWidth(previous), totalWidth(zone))
		local height = zone.Drop + 30
		part(
			f,
			"DropOff",
			Vector3.new(width, height, 6),
			CFrame.new(0, y0 + zone.Drop - height / 2, z0 - 3),
			previous.Rock
		)
	end
	part(f, "Floor", Vector3.new(zone.Lane, 4, slopeLength), frame * CFrame.new(0, -2, 0), zone.Floor)
	local out = half
	for k, tier in zone.Tiers do
		local w, h = tier[1], tier[2]
		for side = -1, 1, 2 do
			part(
				f,
				"Terrace" .. k,
				Vector3.new(w, h + 30, slopeLength),
				frame * CFrame.new(side * (out + w / 2), (h + 30) / 2 - 30, 0),
				zone.Rock:Lerp(Color3.new(1, 1, 1), (k - 1) * 0.08)
			)
		end
		out += w
	end

	-- the gate and sign where the zone begins, with the depth the gauge would show
	local s0 = -slopeLength / 2 + 25
	for side = -1, 1, 2 do
		part(
			f,
			"GatePost",
			Vector3.new(8, 70, 8),
			CFrame.new(floorPoint(frame, side * (half - 6), s0) + Vector3.new(0, 35, 0)),
			rgb(240, 240, 240)
		)
	end
	local bar = floorPoint(frame, 0, s0) + Vector3.new(0, 70, 0)
	part(f, "GateBar", Vector3.new(zone.Lane, 8, 8), CFrame.new(bar), rgb(240, 240, 240))
	sign(
		f,
		string.format("%s  %s m", zone.Name, comma(zone.Metres)),
		CFrame.new(bar - Vector3.new(0, 13, 0)),
		math.min(zone.Lane - 20, 90),
		14,
		zone.Rock
	)

	dress(f, zone, frame, slopeLength)
	silhouettes(f, zone, frame, slopeLength)

	-- schools of stand-in creatures at different heights down the lane
	for school = 1, 4 do
		local centre = frame
			* CFrame.new(
				rng:NextNumber(-half * 0.5, half * 0.5),
				rng:NextNumber(12, 70),
				-slopeLength / 2 + school * slopeLength / 5
			)
		for _ = 1, rng:NextInteger(4, 6) do
			part(
				f,
				"Creature",
				zone.Fish,
				centre * CFrame.new(rng:NextNumber(-16, 16), rng:NextNumber(-6, 6), rng:NextNumber(-16, 16)),
				zone.FishColour
			)
		end
	end

	-- light shafts from the surface, only where it's still shallow
	if zone.Metres < 40 then
		local anchor = part(
			f,
			"ShaftAnchor",
			Vector3.new(1, 1, 1),
			CFrame.new(floorPoint(frame, 0, 0)),
			rgb(255, 255, 255),
			{ Transparency = 1, CanCollide = false }
		)
		for _ = 1, 8 do
			local bottom =
				floorPoint(frame, rng:NextNumber(-half, half), rng:NextNumber(-slopeLength / 2, slopeLength / 2))
			lightShaft(anchor, bottom + Vector3.new(-40, -bottom.Y, -90), bottom, rng:NextNumber(20, 45))
		end
	end

	if index == 1 then -- the rider at the start of the dive, on a starter creature, to show scale
		local start = frame * CFrame.new(0, 20, -slopeLength / 2 + 60)
		part(f, "StarterCreature", Vector3.new(4, 3, 9), start, rgb(250, 150, 80))
		figure(f, start * CFrame.new(0, 1.5, 0))
	end
	return f, y0 - zone.Length * math.tan(math.rad(zone.Slope))
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

local info = {}
local z, y = LANE_START_Z, LAGOON_Y
local previous: Zone? = nil
local dive = folder("Dive", root)
for index, zone in ZONES do
	if previous then
		y -= zone.Drop
	end
	local f, yEnd = buildZone(index, zone, z, y, previous)
	table.insert(info, { Name = zone.Name, Metres = zone.Metres, Z0 = z, Y0 = y, Z1 = z + zone.Length, Y1 = yEnd })
	f.Parent = dive
	task.wait()
	z += zone.Length
	y = yEnd
	previous = zone
end

local count = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
return HttpService:JSONEncode({ Parts = count, BottomMetres = BOTTOM_METRES, Origin = { 3000, 0, 0 }, Zones = info })
