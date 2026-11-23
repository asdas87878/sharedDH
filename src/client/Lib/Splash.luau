--!strict
-- The leap's splash (2026-11-23; Config.Dive.Leap, DiveController plays it): blocks of white water, with no assets.
-- In this file, in order:
--   the pool: local anchored parts under the camera (nothing replicates, collides, is hit by a ray or casts a
--     shadow), taken and put back;
--   one splash's pieces, each a pure function of the splash's age (where it went in, the way it was going, how hard,
--     and its seed say all of it, so a held moment is the same every time):
--       the crown: cubes thrown up and out in a ring, more of them forward, spinning, falling back and shrinking;
--       the column: a short spout of stretched cubes in the middle, gone in 0.4 s;
--       the foam: a ring of flat slabs on the water spreading out and fading, and a second, slower one;
--   play / hold / release / step / stats.
-- The bubbles under the water are Lib/Fx's bursts (Config.Dive.Splash), made by whoever plays this.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)

local Splash = {}

local AWAY = CFrame.new(0, -1e5, 0)
local WHITE = Color3.fromRGB(255, 255, 255)
local AQUA = Color3.fromRGB(206, 242, 250)
local FOAM = Color3.fromRGB(236, 250, 255)
local GRAVITY = 90 -- the crown's, studs a second a second (heavier than the world's: it reads as quick and snappy)
local COLUMN_TIME = 0.4
local RING_TIME = { 1.0, 1.4 } -- the first foam ring's life, and the slower second one's
local RING_SLABS = 14
local LAST = 1.5 -- a splash is over by then, seconds, whatever its numbers

----------------------------------------------------------------------------------------------------------------------
-- The pool

local folder: Folder? = nil
local function holder(): Folder
	local camera = workspace.CurrentCamera
	local f = folder
	if f and f.Parent == camera then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "LeapSplash"
	made.Parent = camera
	folder = made
	return made
end

local free: { Part } = {}
local inUse = 0

local function take(): Part
	local p = table.remove(free)
	if not p or not p.Parent then
		local made = Instance.new("Part")
		made.Anchored = true
		made.CanCollide = false
		made.CanQuery = false
		made.CanTouch = false
		made.CastShadow = false
		made.Material = Enum.Material.SmoothPlastic
		made.TopSurface = Enum.SurfaceType.Smooth
		made.BottomSurface = Enum.SurfaceType.Smooth
		made.CFrame = AWAY
		made.Parent = holder()
		p = made
	end
	inUse += 1
	return p :: Part
end

local function give(part: Part)
	inUse -= 1
	part.CFrame = AWAY
	part.Transparency = 1
	if #free < 240 then
		table.insert(free, part)
	else
		part:Destroy()
	end
end

----------------------------------------------------------------------------------------------------------------------
-- One splash

type Piece = {
	part: Part,
	kind: string, -- "Crown", "Column", "Ring"
	-- the crown's: out along `dir` at `out` studs a second, up at `up`, this big, spinning at `spin` (radians a second)
	dir: Vector3,
	out: number,
	up: number,
	size: number,
	spin: Vector3,
	-- the column's segment (1 to 4) and the ring's (which ring, which slab)
	index: number,
	ring: number,
}

type Shot = {
	id: number,
	at: Vector3, -- where they went in, on the surface
	way: Vector3, -- the way they were going, flat and of length 1
	side: Vector3,
	power: number, -- 0 to 1: how hard
	started: number,
	held: number?, -- held at this age (the test hook), or nil
	pieces: { Piece },
	-- the sizes, worked out once
	column: number,
	rings: { number },
}

local shots: { Shot } = {}
local nextId = 0
local played = 0

local function crownPieces(shot: Shot, random: Random)
	local d = Config.Dive
	local power = shot.power
	local count = math.floor(math.max(d.LeapCrown, 0) * (0.55 + 0.45 * power) + 0.5)
	for i = 1, count do
		-- round the ring, bunched forward: the warp a - 0.5 sin a puts twice as many ahead as behind
		local even = (i - 1 + random:NextNumber(-0.3, 0.3)) / count * math.pi * 2
		local a = even - 0.5 * math.sin(even)
		local forward = math.cos(a)
		local dir = shot.way * forward + shot.side * math.sin(a)
		local high = math.max(d.LeapCrownHigh, 0) * random:NextNumber(0.65, 1.3) * (0.35 + 0.65 * power)
		table.insert(shot.pieces, {
			part = take(),
			kind = "Crown",
			dir = dir,
			out = random:NextNumber(6, 12) * (1 + 0.5 * forward) * (0.5 + 0.5 * power),
			up = math.sqrt(2 * GRAVITY * high),
			size = random:NextNumber(0.8, 1.6) * (0.7 + 0.3 * power),
			spin = Vector3.new(random:NextNumber(-9, 9), random:NextNumber(-6, 6), random:NextNumber(-9, 9)),
			index = i,
			ring = 0,
		})
	end
end

local function play(at: Vector3, way: Vector3, power: number, seed: number): Shot
	local flat = way * Vector3.new(1, 0, 1)
	local w = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local d = Config.Dive
	nextId += 1
	played += 1
	local shot: Shot = {
		id = nextId,
		at = at,
		way = w,
		side = Vector3.new(-w.Z, 0, w.X),
		power = math.clamp(power, 0, 1),
		started = os.clock(),
		held = nil,
		pieces = {},
		column = math.max(d.LeapColumn, 0) * (0.5 + 0.5 * math.clamp(power, 0, 1)),
		rings = {},
	}
	local random = Random.new(seed)
	crownPieces(shot, random)
	if shot.column > 0 then
		for k = 1, 4 do
			table.insert(shot.pieces, {
				part = take(),
				kind = "Column",
				dir = w,
				out = 0,
				up = 0,
				size = 1.9 - 0.3 * k,
				spin = Vector3.new(0, random:NextNumber(-3, 3), 0),
				index = k,
				ring = 0,
			})
		end
	end
	local ring = math.max(d.LeapRing, 0) * (0.5 + 0.5 * shot.power)
	if ring > 0 then
		shot.rings = { ring, ring * 0.6 }
		for r = 1, 2 do
			for k = 1, RING_SLABS do
				table.insert(shot.pieces, {
					part = take(),
					kind = "Ring",
					dir = w,
					out = 0,
					up = 0,
					size = 0,
					spin = Vector3.zero,
					index = k,
					ring = r,
				})
			end
		end
	end
	for _, piece in shot.pieces do
		local part = piece.part
		part.Color = if piece.kind == "Ring"
			then FOAM
			elseif piece.kind == "Crown" and piece.index % 3 == 0 then AQUA
			else WHITE
		part.Transparency = 1
		part.CFrame = AWAY
	end
	return shot
end

-- Where each piece is at `age` seconds: nothing but the shot and the age go in
local function draw(shot: Shot, age: number)
	local at = shot.at
	local up = Vector3.yAxis
	for _, piece in shot.pieces do
		local part = piece.part
		local shown = false
		if piece.kind == "Crown" then
			local landing = 2 * piece.up / GRAVITY -- when it is back down at the surface
			if age < landing then
				local height = piece.up * age - 0.5 * GRAVITY * age * age
				local shrink = 1 - Ease.smoothstep(landing * 0.5, landing, age)
				local size = piece.size * math.max(shrink, 0.05)
				local position = at + piece.dir * (1.2 + piece.out * age) + up * (height + 0.3)
				part.Size = Vector3.one * size
				part.CFrame = CFrame.new(position)
					* CFrame.Angles(piece.spin.X * age, piece.spin.Y * age, piece.spin.Z * age)
				part.Transparency = 0.05 + 0.5 * Ease.smoothstep(landing * 0.7, landing, age)
				shown = true
			end
		elseif piece.kind == "Column" then
			if age < COLUMN_TIME and shot.column > 0 then
				-- up fast, held a moment, and down into itself
				local u = age / COLUMN_TIME
				local extent = shot.column * math.sin(math.pi * u) ^ 0.6
				local segment = extent / 4
				if segment > 0.05 then
					local width = piece.size * (1 - 0.45 * u) * (0.6 + 0.4 * shot.power)
					local centre = segment * (piece.index - 0.5)
					-- (leaning a little the way they went)
					local lean = CFrame.fromMatrix(Vector3.zero, shot.side, up, -shot.way)
						* CFrame.Angles(math.rad(-10), 0, 0)
					part.Size = Vector3.new(width, segment * 1.15, width)
					part.CFrame = CFrame.new(at)
						* lean
						* CFrame.new(0, centre, 0)
						* CFrame.Angles(0, piece.spin.Y * age, 0)
					part.Transparency = 0.05 + 0.6 * Ease.smoothstep(0.6, 1, u)
					shown = true
				end
			end
		else
			local life = RING_TIME[piece.ring]
			local widest = shot.rings[piece.ring]
			if age < life and widest then
				local u = age / life
				local from = if piece.ring == 1 then 2 else 1
				local radius = from + (widest - from) * Ease.outQuad(u)
				local a = (piece.index - 1 + (if piece.ring == 2 then 0.5 else 0)) / RING_SLABS * math.pi * 2
				local across = 2 * math.pi * radius / RING_SLABS * 1.08
				local thick = (if piece.ring == 1 then 1.2 else 0.9) * (1 - 0.4 * u)
				part.Size = Vector3.new(across, 0.25, thick)
				part.CFrame = CFrame.new(at + Vector3.new(0, 0.12 + 0.02 * piece.ring, 0))
					* CFrame.Angles(0, a, 0)
					* CFrame.new(0, 0, -radius)
				part.Transparency = 0.15 + 0.85 * Ease.smoothstep(0.35, 1, u)
				shown = true
			end
		end
		if not shown and part.Transparency < 1 then
			part.Transparency = 1
			part.CFrame = AWAY
		end
	end
end

local function finish(index: number)
	local shot = table.remove(shots, index)
	if shot then
		for _, piece in shot.pieces do
			give(piece.part)
		end
		table.clear(shot.pieces)
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Play, hold, release, step

-- A splash where someone went in at `at` (on the surface), going `way`, `power` 0 to 1 by how fast. Its seed makes
-- it the same each time. The id, or nil with Config.Dive.LeapSplashMost already running.
function Splash.play(at: Vector3, way: Vector3, power: number, seed: number?): number?
	if #shots >= math.max(Config.Dive.LeapSplashMost, 1) then
		return nil
	end
	local shot = play(at, way, power, seed or math.random(1, 1e6))
	table.insert(shots, shot)
	draw(shot, 0)
	return shot.id
end

-- Test hook: only the Studio checks call this (tools/studio/dive_leap_check.py). Holds that splash at `age` seconds
-- (nil: lets it run on from there).
function Splash.hold(id: number, age: number?)
	for _, shot in shots do
		if shot.id == id then
			if age then
				shot.held = age
			else
				shot.started = os.clock() - (shot.held or 0)
				shot.held = nil
			end
			draw(shot, age or 0)
		end
	end
end

-- Takes that splash away at once
function Splash.release(id: number)
	for i = #shots, 1, -1 do
		if shots[i].id == id then
			finish(i)
		end
	end
end

-- Every frame (DiveController): each splash drawn at its age, and the finished ones put back
function Splash.step()
	local now = os.clock()
	for i = #shots, 1, -1 do
		local shot = shots[i]
		local age = shot.held or (now - shot.started)
		if age >= LAST then
			finish(i)
		else
			draw(shot, age)
		end
	end
end

-- Test hook: only the Studio checks call this (tools/studio/dive_leap_check.py). How many splashes are running, how
-- many parts they hold, and how many were played since the start.
function Splash.stats(): { running: number, parts: number, played: number }
	return { running = #shots, parts = inUse, played = played }
end

return Splash
