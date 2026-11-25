--!strict
-- The leap's splash (2026-11-23; Config.Dive.Leap, DiveController plays it): blocks of white water, with no assets.
-- In this file, in order:
--   the pool: local anchored parts under the camera (nothing replicates, collides, is hit by a ray or casts a
--     shadow), Neon so a block reads white from every side, lit or shaded (SmoothPlastic went grey-blue on its
--     shaded side), made ahead (Splash.prewarm) and taken and put back, never re-parented;
--   one splash's pieces, each a pure function of the splash's age (where it went in, the way it was going, how hard,
--     and its seed say all of it, so a held moment is the same every time):
--       the crown: big cubes (1.5 to 3 studs) thrown up and out in a wide ring round the hole, more of them
--         forward, open by 0.15 s and at its widest at CROWN_OPEN, tumbling, falling back and shrinking into the water;
--       the mound: three wide stacked cubes in the middle that heave up and drop back, gone in 0.55 s;
--       the foam: a ring of flat white slabs standing clear over the water's top, from RING_FROM out, spreading and
--         fading, and a second, slower one;
--     and any of them near the camera fades out (Config.Dive.LeapSplashNear): the view never goes white inside one;
--   play / hold / release / step / stats.
-- (A thin 14 stud column with 16 small cubes round it until 2026-11-23: it read as a stick with specks.)
-- A splash may be scaled (the fish leaping in the hub's sea, HubLeapController, 2026-11-25): a small one is smaller in
-- every way, has fewer pieces and is over sooner. Those count apart (Config.HubLeap.Splashes), so they never use up the
-- players' own.
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
local MOUND_TIME = 0.55
local MOUND_RISE = 0.3 -- the share of that it heaves up over, then drops
local MOUND_WIDTH = { 5.5, 4.2, 2.8 } -- its three cubes, bottom to top, studs across at the full splash
local RING_TIME = { 1.0, 1.4 } -- the first foam ring's life, and the slower second one's
local RING_FROM = { 4, 1 } -- their radius as they begin, studs (the first shows at once, round the mound)
local CROWN_OPEN = 0.3 -- the crown's blocks are thrown out to their widest by then, seconds (then fall straight)
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

local function make(): Part
	local made = Instance.new("Part")
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Material = Enum.Material.Neon
	made.TopSurface = Enum.SurfaceType.Smooth
	made.BottomSurface = Enum.SurfaceType.Smooth
	made.Transparency = 1
	made.CFrame = AWAY
	made.Parent = holder()
	return made
end

local function take(): Part
	local p = table.remove(free)
	if not p or not p.Parent then
		p = make()
	end
	inUse += 1
	return p :: Part
end

-- Parts made ahead (DiveController, once the leap is on), `step` more a call: true once the pool holds enough for
-- Config.Dive.LeapSplashMost whole splashes
function Splash.prewarm(step: number): boolean
	local d = Config.Dive
	local most = (math.max(d.LeapCrown, 0) + #MOUND_WIDTH + 2 * RING_SLABS) * math.max(d.LeapSplashMost, 1)
	local made = 0
	while #free + inUse < most and made < step do
		table.insert(free, make())
		made += 1
	end
	return #free + inUse >= most
end

local function give(part: Part)
	inUse -= 1
	part.CFrame = AWAY
	part.Transparency = 1
	if #free < 320 then
		table.insert(free, part)
	else
		part:Destroy()
	end
end

----------------------------------------------------------------------------------------------------------------------
-- One splash

type Piece = {
	part: Part,
	kind: string, -- "Crown", "Mound", "Ring"
	-- the crown's: out along `dir` at `out` studs a second, up at `up`, this big, spinning at `spin` (radians a second)
	dir: Vector3,
	out: number,
	up: number,
	size: number,
	spin: Vector3,
	-- the mound's cube (1 to 3, from the bottom) and the ring's (which ring, which slab)
	index: number,
	ring: number,
}

type Shot = {
	id: number,
	at: Vector3, -- where they went in, on the surface
	way: Vector3, -- the way they were going, flat and of length 1
	side: Vector3,
	power: number, -- 0 to 1: how hard
	scale: number, -- 1: a player's own
	quick: number, -- its times, as a share of a player's own splash's
	slabs: number, -- in a foam ring
	scenery: boolean,
	started: number,
	held: number?, -- held at this age (the test hook), or nil
	pieces: { Piece },
	-- the sizes, worked out once
	mound: number,
	rings: { number },
}

local shots: { Shot } = {}
local nextId = 0
local played = 0
local sceneries = 0 -- of `shots`, the scenery's

local function crownPieces(shot: Shot, random: Random)
	local d = Config.Dive
	local power = shot.power
	local scale = shot.scale
	local few = math.clamp(0.4 + 0.6 * scale, 0.4, 1.3)
	local count = math.floor(math.max(d.LeapCrown, 0) * (0.55 + 0.45 * power) * few + 0.5)
	for i = 1, count do
		-- round the ring, bunched forward: the warp a - 0.5 sin a puts twice as many ahead as behind
		local even = (i - 1 + random:NextNumber(-0.3, 0.3)) / count * math.pi * 2
		local a = even - 0.5 * math.sin(even)
		local forward = math.cos(a)
		local dir = shot.way * forward + shot.side * math.sin(a)
		local high = math.max(d.LeapCrownHigh, 0) * scale * random:NextNumber(0.7, 1.25) * (0.35 + 0.65 * power)
		table.insert(shot.pieces, {
			part = take(),
			kind = "Crown",
			dir = dir,
			-- (how far out it is thrown, studs, by CROWN_OPEN)
			out = random:NextNumber(6, 10) * (1 + 0.4 * forward) * (0.5 + 0.5 * power) * scale,
			up = math.sqrt(2 * GRAVITY * high),
			size = random:NextNumber(1.5, 3) * (0.75 + 0.25 * power) * scale ^ 0.8,
			-- (big blocks tumble slower than small ones)
			spin = Vector3.new(random:NextNumber(-5, 5), random:NextNumber(-4, 4), random:NextNumber(-5, 5)),
			index = i,
			ring = 0,
		})
	end
end

local function play(at: Vector3, way: Vector3, power: number, seed: number, scale: number, scenery: boolean): Shot
	local flat = way * Vector3.new(1, 0, 1)
	local w = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local d = Config.Dive
	nextId += 1
	if scenery then
		sceneries += 1
	else
		played += 1
	end
	local shot: Shot = {
		id = nextId,
		at = at,
		way = w,
		side = Vector3.new(-w.Z, 0, w.X),
		power = math.clamp(power, 0, 1),
		scale = scale,
		quick = math.clamp(math.sqrt(scale), 0.5, 1.25),
		slabs = math.floor(RING_SLABS * math.clamp(scale, 0.5, 1) + 0.5),
		scenery = scenery,
		started = os.clock(),
		held = nil,
		pieces = {},
		mound = math.max(d.LeapColumn, 0) * (0.5 + 0.5 * math.clamp(power, 0, 1)) * scale,
		rings = {},
	}
	local random = Random.new(seed)
	crownPieces(shot, random)
	if shot.mound > 0 then
		for k = 1, #MOUND_WIDTH do
			table.insert(shot.pieces, {
				part = take(),
				kind = "Mound",
				dir = w,
				out = 0,
				up = 0,
				size = MOUND_WIDTH[k] * (0.6 + 0.4 * shot.power) * scale,
				spin = Vector3.new(0, 0.45 * k + random:NextNumber(-0.2, 0.2), 0),
				index = k,
				ring = 0,
			})
		end
	end
	local ring = math.max(d.LeapRing, 0) * (0.5 + 0.5 * shot.power) * scale
	if ring > 0 then
		shot.rings = { ring, ring * 0.6 }
		-- (a small one has no second ring)
		for r = 1, if scale < 0.6 then 1 else 2 do
			for k = 1, shot.slabs do
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
			then WHITE
			elseif piece.kind == "Mound" and piece.index == 1 then FOAM
			elseif piece.kind == "Crown" and piece.index % 3 == 0 then AQUA
			else WHITE
		part.Transparency = 1
		part.CFrame = AWAY
	end
	return shot
end

-- Where each piece is at `age` seconds: nothing but the shot and the age go in (and the camera, for the fade near it)
local function draw(shot: Shot, age: number)
	local at = shot.at
	local up = Vector3.yAxis
	local eye = workspace.CurrentCamera.CFrame.Position
	local near = math.max(Config.Dive.LeapSplashNear, 0)
	local scale, quick = shot.scale, shot.quick
	for _, piece in shot.pieces do
		local part = piece.part
		local shown = false
		if piece.kind == "Crown" then
			local landing = 2 * piece.up / GRAVITY -- when it is back down at the surface
			if age < landing then
				local height = piece.up * age - 0.5 * GRAVITY * age * age
				local shrink = 1 - Ease.smoothstep(landing * 0.5, landing, age)
				local size = piece.size * math.max(shrink, 0.05)
				local position = at
					+ piece.dir * (2.5 * scale + piece.out * Ease.outQuad(math.min(age / (CROWN_OPEN * quick), 1)))
					+ up * (height + 0.5 * math.min(scale, 1))
				part.Size = Vector3.one * size
				part.CFrame = CFrame.new(position)
					* CFrame.Angles(piece.spin.X * age, piece.spin.Y * age, piece.spin.Z * age)
				part.Transparency = 0.5 * Ease.smoothstep(landing * 0.75, landing, age)
				shown = true
			end
		elseif piece.kind == "Mound" then
			if age < MOUND_TIME * quick and shot.mound > 0 then
				-- heaved up fast, then dropping back as if it were thrown, spreading as it goes
				local u = age / (MOUND_TIME * quick)
				local lift = if u < MOUND_RISE
					then Ease.outQuad(u / MOUND_RISE)
					else 1 - ((u - MOUND_RISE) / (1 - MOUND_RISE)) ^ 2
				local layer = shot.mound * lift / #MOUND_WIDTH
				if layer > 0.05 then
					local width = piece.size * (1 + 0.35 * u)
					-- (stacked from a little under the surface, each cube turned a little more than the one under it)
					local centre = layer * (piece.index - 0.5) - 0.3
					part.Size = Vector3.new(width, math.max(layer * 1.15, 0.2), width)
					part.CFrame = CFrame.new(at + up * centre) * CFrame.Angles(0, piece.spin.Y, 0)
					part.Transparency = 0.6 * Ease.smoothstep(0.7, 1, u)
					shown = true
				end
			end
		else
			local life = RING_TIME[piece.ring] * quick
			local widest = shot.rings[piece.ring]
			if age < life and widest then
				local u = age / life
				local from = RING_FROM[piece.ring] * scale
				local radius = from + (widest - from) * Ease.outQuad(u)
				local a = (piece.index - 1 + (if piece.ring == 2 then 0.5 else 0)) / shot.slabs * math.pi * 2
				local across = 2 * math.pi * radius / shot.slabs * 1.08
				local thick = (if piece.ring == 1 then 1.6 else 1.2) * (1 - 0.4 * u) * scale
				-- (standing clear over the water's top: its glass layer is near white itself, and a ring laid in it
				-- was lost)
				part.Size = Vector3.new(across, 0.5, thick)
				part.CFrame = CFrame.new(at + Vector3.new(0, 0.5 + 0.06 * piece.ring, 0))
					* CFrame.Angles(0, a, 0)
					* CFrame.new(0, 0, -radius)
				part.Transparency = Ease.smoothstep(0.45, 1, u)
				shown = true
			end
		end
		if shown and near > 0 and part.Transparency < 1 then
			-- near the camera: faded out, gone at a third of LeapSplashNear
			local gap = (part.Position - eye).Magnitude - part.Size.Magnitude / 2
			local fade = 1 - Ease.smoothstep(near / 3, near, gap)
			if fade > 0 then
				part.Transparency += (1 - part.Transparency) * fade
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
		if shot.scenery then
			sceneries -= 1
		end
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
	if #shots - sceneries >= math.max(Config.Dive.LeapSplashMost, 1) then
		return nil
	end
	local shot = play(at, way, power, seed or math.random(1, 1e6), 1, false)
	table.insert(shots, shot)
	draw(shot, 0)
	return shot.id
end

-- The scenery's (HubLeapController): `scale` times a player's whole splash, in every way. Nothing with
-- Config.HubLeap.Splashes of them already running.
function Splash.scenery(at: Vector3, way: Vector3, scale: number)
	if sceneries >= Config.HubLeap.Splashes then
		return
	end
	local shot = play(at, way, 1, math.random(1, 1e6), math.clamp(scale, 0.15, 4), true)
	table.insert(shots, shot)
	draw(shot, 0)
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
		if age >= LAST * shot.quick then
			finish(i)
		else
			draw(shot, age)
		end
	end
end

-- Test hook: only the Studio checks call this (tools/studio/dive_leap_check.py). How many splashes are running, how
-- many parts they hold, and how many were played since the start.
function Splash.stats(): { running: number, parts: number, played: number }
	return { running = #shots - sceneries, parts = inUse, played = played }
end

return Splash
