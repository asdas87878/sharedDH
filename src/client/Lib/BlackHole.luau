--!strict
-- A voxel black hole whose light bends by where the viewer stands (docs/design/cosmic.md, "The black hole in Roblox").
-- Local only: every piece is a small Neon cube made on this client, nothing replicates, collides or casts a shadow.
-- Controllers/BlackHoleDisplayController requires it. To try it on its own, see tools/studio/black_hole_demo.luau.
--
-- Roblox cannot bend light, so the cubes are MOVED to where bent light would show them. Each frame, for every cube that
-- lies behind the hole as this camera sees it, the point-lens equation gives where its image appears: pushed outward
-- round the hole (the first image), and for some of them a second, fainter image flipped to the other side. That is
-- what lifts the far side of the disc into an arc over the ball and tucks a thin arc under it, and it changes with the
-- viewer's angle AND distance. Only things made here are bent: the game's own scenery behind the hole is not.
--
-- Units inside: one Schwarzschild radius (the horizon's radius) is 1; `Scale` is how many studs that is. The hole is at
-- the origin of its own frame, the disc in its XZ plane, the jets up its Y axis.
--   the shadow (the ball) is 2.6 across its radius: the photon capture radius, which is what a viewer sees as black;
--   the disc's inner edge is at 3 (the last stable orbit); each cube orbits at its own Kepler speed, the inside faster;
--   Doppler: the side turning toward the viewer is brighter and whiter, the side turning away dimmer and redder;
--   the photon ring: a thin bright ring hugging the ball, always face on to the viewer;
--   motes: loose specks round the hole, there to be bent, so space itself seems to warp as the viewer moves.
-- Every cube sits on one grid (`Voxel` studs), so the pieces line up, and a cube is only moved on the frames it changes
-- cell: one BulkMoveTo a frame. A cube's colour comes from a small table made once, and is set only when it changes.
-- Each cube is worked out once in `Every` frames (2), which the eye cannot tell, since a cube only hops from cell to
-- cell. A cube that is not showing is made invisible, not moved.
-- COST (measured in Studio, 2026-11-17): placing a part costs about 3.6 millionths of a second, by BulkMoveTo, by
-- Model:PivotTo or as a welded assembly alike. A hole that stays put places only the cubes that change cell: about
-- 2 ms a frame at Medium. A hole whose origin moves must place every showing cube every frame: about 14 ms at Medium,
-- so a hole that rides a creature wants Quality "Tiny" and a bigger Voxel (about 3 ms).
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAU = math.pi * 2
local SHADOW = 2.6 -- the ball's radius
local RING_AT = 2.66 -- the photon ring's radius
local HEAT_STEPS, BRIGHT_STEPS = 16, 6 -- the colour table: how hot by how bright
local KIND_DISC, KIND_MOTE, KIND_JET, KIND_SPARK, KIND_DEBRIS, KIND_RING = 0, 1, 2, 3, 4, 5
local FEED_TIME = 15 -- seconds a feeding lasts
local JET_LENGTH = 13

export type Options = {
	Scale: number?, -- studs to one horizon radius (0.635: a ball 3.3 studs across, a disc 11.5)
	Voxel: number?, -- the cube's size in studs (0.15)
	Quality: string?, -- "Tiny" | "Low" | "Medium" | "High": how many cubes
	Speed: number?, -- how fast the disc turns (1: the inner edge goes round in about 10 seconds)
	Lensing: number?, -- how strongly light bends (1: as the equation says; 0: none)
	Jets: boolean?, -- the two jets (true)
	Motes: boolean?, -- the loose specks that show space bending (true)
	Every: number?, -- work each cube out once in this many frames (2); 1 is smoothest and costs twice as much
	AutoFeed: number?, -- seconds between feedings by itself (0: only when Feed is called)
	Light: boolean?, -- a warm light at the middle (true)
	Parent: Instance?, -- where the cubes go (the camera, so they are never part of the game's world)
}

type Counts = { Disc: number, Echo: number, Ring: number, Motes: number, Jets: number, Sparks: number, Debris: number }
local QUALITY: { [string]: Counts } = {
	Tiny = { Disc = 500, Echo = 100, Ring = 48, Motes = 0, Jets = 0, Sparks = 12, Debris = 60 }, -- for a hole that travels
	Low = { Disc = 1200, Echo = 220, Ring = 90, Motes = 60, Jets = 120, Sparks = 24, Debris = 90 },
	Medium = { Disc = 2400, Echo = 440, Ring = 140, Motes = 120, Jets = 240, Sparks = 40, Debris = 140 },
	High = { Disc = 4000, Echo = 720, Ring = 180, Motes = 180, Jets = 360, Sparks = 60, Debris = 200 },
}

local function smooth(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- How hot it looks, 0 to about 1.6: ember, orange, yellow, white, then blue-white when shifted toward the viewer
local function ramp(x: number): (number, number, number)
	local a = smooth(0, 0.36, x)
	local r, g, b = 0.30 + 0.70 * a, 0.015 + 0.245 * a, 0.02 * a
	a = smooth(0.30, 0.62, x)
	r, g, b = r + (1.0 - r) * a, g + (0.68 - g) * a, b + (0.22 - b) * a
	a = smooth(0.56, 0.92, x)
	r, g, b = r + (1.0 - r) * a, g + (0.94 - g) * a, b + (0.84 - b) * a
	a = smooth(0.98, 1.55, x)
	return r + (0.70 - r) * a, g + (0.83 - g) * a, b + (1.0 - b) * a
end

local PALETTE: { Color3 } = table.create(HEAT_STEPS * BRIGHT_STEPS)
for h = 1, HEAT_STEPS do
	local r, g, b = ramp((h - 0.5) / HEAT_STEPS * 1.6)
	for k = 1, BRIGHT_STEPS do
		local lit = 0.2 + 0.8 * (k - 1) / (BRIGHT_STEPS - 1) -- never black: the dim side still shows as embers
		PALETTE[(h - 1) * BRIGHT_STEPS + k] = Color3.new(r * lit, g * lit, b * lit)
	end
end

-- Which colour in the table: how hot (0 to 1.6) and how bright (0 up, 1 is full)
local function tone(heat: number, bright: number): number
	local h = math.clamp(math.floor(heat / 1.6 * HEAT_STEPS) + 1, 1, HEAT_STEPS)
	local k = math.clamp(math.floor(math.sqrt(math.max(bright, 0)) * BRIGHT_STEPS) + 1, 1, BRIGHT_STEPS)
	return (h - 1) * BRIGHT_STEPS + k
end

local BlackHole = {}
BlackHole.__index = BlackHole

export type BlackHole = typeof(setmetatable(
	{} :: {
		_folder: Folder,
		_origin: CFrame,
		_follow: BasePart?,
		_scale: number,
		_grid: number, -- the cube's size, in horizon radii
		_speed: number,
		_lens: number,
		_jets: boolean,
		_autoFeed: number,
		_now: number,
		_frame: number,
		_feedAt: number,
		_lastFeed: number,
		_moved: boolean, -- the origin changed
		_placed: boolean, -- every piece has been put in its place once
		_every: number, -- a cube is worked out once in this many frames
		_step: RBXScriptConnection?,
		_light: PointLight?,
		_count: number,
		-- one entry to a cube
		_part: { BasePart },
		_kind: { number },
		_image: { number }, -- 0: the first image; 1: the second, flipped one
		_a: { number },
		_b: { number },
		_c: { number },
		_d: { number },
		_seed: { number },
		_tone: { number }, -- the colour it has now
		_ix: { number }, -- the cell it is in now
		_iy: { number },
		_iz: { number },
		_at: { CFrame }, -- where it is in the hole's own frame, in studs
		_shown: { boolean },
		-- the ball's boxes, which only move with the origin
		_ballParts: { BasePart },
		_ballAt: { CFrame },
		-- lists filled and emptied each frame
		_moveParts: { BasePart },
		_moveTo: { CFrame },
	},
	BlackHole
))

-- A black hole at `origin` (its disc lies in the origin's XZ plane). Call Start, or Step every frame yourself
function BlackHole.new(origin: CFrame, options: Options?): BlackHole
	local opt: Options = options or {}
	local scale = opt.Scale or 0.635
	local grid = (opt.Voxel or 0.15) / scale
	local counts = QUALITY[opt.Quality or "Medium"] or QUALITY.Medium
	local random = Random.new(20261117)

	local folder = Instance.new("Folder")
	folder.Name = "BlackHole"

	local template = Instance.new("Part")
	template.Anchored = true
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	template.CastShadow = false
	template.Locked = true
	template.Material = Enum.Material.Neon
	template.TopSurface = Enum.SurfaceType.Smooth
	template.BottomSurface = Enum.SurfaceType.Smooth
	template.Color = PALETTE[1]

	local self: BlackHole = setmetatable(
		{
			_folder = folder,
			_origin = origin,
			_follow = nil,
			_scale = scale,
			_grid = grid,
			_speed = opt.Speed or 1,
			_lens = opt.Lensing or 1,
			_jets = opt.Jets ~= false,
			_autoFeed = opt.AutoFeed or 0,
			_now = 0,
			_frame = 0,
			_feedAt = -1e9,
			_lastFeed = 0,
			_moved = true,
			_placed = false,
			_every = math.max(1, math.floor(opt.Every or 2)),
			_step = nil,
			_light = nil,
			_count = 0,
			_part = {},
			_kind = {},
			_image = {},
			_a = {},
			_b = {},
			_c = {},
			_d = {},
			_seed = {},
			_tone = {},
			_ix = {},
			_iy = {},
			_iz = {},
			_at = {},
			_shown = {},
			_ballParts = {},
			_ballAt = {},
			_moveParts = {},
			_moveTo = {},
		} :: any,
		BlackHole
	)

	local function add(
		kind: number,
		image: number,
		a: number,
		b: number,
		c: number,
		d: number,
		seed: number,
		size: number,
		colour: Color3?
	)
		local part = template:Clone()
		local side = grid * scale * size
		part.Size = Vector3.new(side, side, side)
		if colour then
			part.Color = colour
		end
		part.Parent = folder
		local n = self._count + 1
		self._count = n
		self._part[n], self._kind[n], self._image[n] = part, kind, image
		self._a[n], self._b[n], self._c[n], self._d[n], self._seed[n] = a, b, c, d, seed
		self._tone[n], self._ix[n], self._iy[n], self._iz[n] = 0, 1e9, 1e9, 1e9
		self._at[n], self._shown[n] = CFrame.new(), true
	end

	-- the disc: (radius, where on its orbit it starts, how far off the plane, unused). The first `Echo` of them also
	-- get a second image
	for i = 1, counts.Disc do
		local r = 3.0 + 6.2 * random:NextNumber() ^ 1.25
		local phase, off, seed =
			random:NextNumber() * TAU,
			(random:NextNumber() + random:NextNumber() + random:NextNumber()) / 1.5 - 1,
			random:NextNumber()
		add(KIND_DISC, 0, r, phase, off, 0, seed, 1)
		if i <= counts.Echo then
			add(KIND_DISC, 1, r, phase, off, 0, seed, 0.8)
		end
	end
	-- the photon ring: (unused, its angle round the ring, a little in or out, unused)
	for i = 1, counts.Ring do
		add(KIND_RING, 0, 0, i / counts.Ring * TAU, random:NextNumber() * 2 - 1, 0, random:NextNumber(), 0.6)
	end
	-- motes: a fixed place on a shell round the hole (x, y, z in horizon radii), each with both its images
	if opt.Motes ~= false then
		for _ = 1, counts.Motes do
			local dir = random:NextUnitVector() * (9 + 16 * random:NextNumber())
			local seed = random:NextNumber()
			local colour = Color3.new(0.22 + 0.12 * seed, 0.42 + 0.14 * seed, 0.7)
			add(KIND_MOTE, 0, dir.X, dir.Y, dir.Z, 0, seed, 0.45, colour)
			add(KIND_MOTE, 1, dir.X, dir.Y, dir.Z, 0, seed, 0.35, colour)
		end
	end
	-- the jets: (up or down, where along the jet it starts, how far out from the axis, unused)
	if self._jets then
		for i = 1, counts.Jets do
			local seed = random:NextNumber()
			local pale = random:NextNumber() < 0.3
			add(
				KIND_JET,
				0,
				if i % 2 == 0 then 1 else -1,
				random:NextNumber(),
				random:NextNumber(),
				0,
				seed,
				0.8,
				if pale then Color3.new(0.92, 0.96, 1) else Color3.new(0.5, 0.7, 1)
			)
		end
	end
	-- sparks that leave the inner edge and fall in: (unused, where on its fall it starts, how far off the plane, unused)
	for _ = 1, counts.Sparks do
		add(KIND_SPARK, 0, 0, random:NextNumber(), random:NextNumber() * 2 - 1, 0, random:NextNumber(), 0.6)
	end
	-- the star that is fed to it: (its place inside the star's ball x, y, z, how far behind the front of the stream it is)
	for _ = 1, counts.Debris do
		local inside = random:NextUnitVector() * random:NextNumber() ^ (1 / 3)
		add(KIND_DEBRIS, 0, inside.X, inside.Y, inside.Z, random:NextNumber(), random:NextNumber(), 0.9)
	end

	-- the ball: black cubes on the same grid, joined into boxes row by row so it is a few hundred parts, not thousands
	-- (a cube's middle sits on a whole step of the grid, so the ball's cells do too: everything lines up)
	local reach = math.floor(SHADOW / grid)
	local black = Color3.new(0, 0, 0)
	for k = -reach, reach do
		local zAt = k * grid
		local runFrom, runWide = -reach, -1
		for j = -reach, reach + 1 do -- one row past the end, to close the last box
			local yAt = j * grid
			local inside = SHADOW * SHADOW - zAt * zAt - yAt * yAt
			local wide = if j <= reach and inside >= 0 then math.floor(math.sqrt(inside) / grid) else -1
			if wide ~= runWide then
				if runWide >= 0 then
					local rows = j - runFrom
					local box = template:Clone()
					box.Color = black -- black Neon: no light falls on it, so it stays black
					box.Size = Vector3.new((2 * runWide + 1) * grid, rows * grid, grid) * scale
					box.Parent = folder
					table.insert(self._ballParts, box)
					table.insert(self._ballAt, CFrame.new(0, (runFrom + j - 1) / 2 * grid * scale, zAt * scale))
				end
				runFrom, runWide = j, wide
			end
		end
	end

	if opt.Light ~= false then
		local anchor = template:Clone()
		anchor.Name = "Light"
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Parent = folder
		table.insert(self._ballParts, anchor)
		table.insert(self._ballAt, CFrame.new())
		local light = Instance.new("PointLight")
		light.Color = Color3.new(1, 0.62, 0.3)
		light.Range = 26 * scale
		light.Brightness = 1.5
		light.Shadows = false
		light.Parent = anchor
		self._light = light
	end

	template:Destroy()
	folder.Parent = opt.Parent or Workspace.CurrentCamera
	return self
end

-- Move the hole (and turn it: the disc lies in the new frame's XZ plane)
function BlackHole.SetOrigin(self: BlackHole, origin: CFrame)
	if origin ~= self._origin then
		self._origin = origin
		self._moved = true
	end
end

-- Keep the hole on a part (a creature's joint), or pass nil to let go
function BlackHole.Follow(self: BlackHole, part: BasePart?)
	self._follow = part
end

-- Feed it a star: a clump is drawn into a stream, wound in, and the disc flares. Does nothing while one is still going
function BlackHole.Feed(self: BlackHole)
	if self._now - self._feedAt > FEED_TIME then
		self._feedAt = self._now
		self._lastFeed = self._now
	end
end

-- One frame. `eye` is where the viewer is, in the world
function BlackHole.Step(self: BlackHole, dt: number, eye: Vector3)
	local follow = self._follow
	if follow then
		self:SetOrigin(follow.CFrame)
	end
	local now = self._now + dt
	self._now = now
	local frame = self._frame + 1
	self._frame = frame
	if self._autoFeed > 0 and now - self._lastFeed > self._autoFeed then
		self:Feed()
	end

	local origin, scale, grid = self._origin, self._scale, self._grid
	local moved = self._moved
	self._moved = false
	local first = not self._placed -- the first frame works every cube out
	local moveParts, moveTo = self._moveParts, self._moveTo
	table.clear(moveParts)
	table.clear(moveTo)
	local moves = 0

	-- the viewer in the hole's own frame, and the two directions across the line of sight
	local at = origin:PointToObjectSpace(eye) / scale
	local cx, cy, cz = at.X, at.Y, at.Z
	local far = math.max(math.sqrt(cx * cx + cy * cy + cz * cz), 0.001)
	local nx, ny, nz = -cx / far, -cy / far, -cz / far
	local ux, uy, uz = -nz, 0, nx -- n cross up
	if math.abs(ny) > 0.98 then
		ux, uy, uz = 0, nz, -ny -- looking straight down the axis: n cross X instead
	end
	local ul = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / ul, uy / ul, uz / ul
	local vx, vy, vz = uy * nz - uz * ny, uz * nx - ux * nz, ux * ny - uy * nx
	local lens = if far > SHADOW + 0.5 then self._lens else 0 -- no bending for a viewer inside the ball

	local speed = self._speed * 0.6
	local feed = now - self._feedAt
	local feeding = feed < FEED_TIME
	local flare = if feeding then math.exp(-((feed - 7.4) / 1.5) ^ 2) else 0
	local wave = if feeding and feed > 7 then (feed - 7) * 2.6 else -1
	local stretch = 0.15 + 1.8 * smooth(1, 6, feed)
	local light = self._light
	if light then
		light.Brightness = 1.5 + 3 * flare
	end

	local parts, kinds, images = self._part, self._kind, self._image
	local pa, pb, pc, pd, seeds = self._a, self._b, self._c, self._d, self._seed
	local tones, ixs, iys, izs = self._tone, self._ix, self._iy, self._iz
	local ats, showns = self._at, self._shown
	local sin, cos, sqrt, exp, floor, log = math.sin, math.cos, math.sqrt, math.exp, math.floor, math.log

	local every = if first then 1 elseif far > 70 then self._every * 2 else self._every
	local paint = every * 3
	for i = 1, self._count do
		if (i + frame) % every ~= 0 then
			continue
		end
		local kind, seed = kinds[i], seeds[i]
		local x, y, z = 0, 0, 0
		local heat, bright = 0, 0
		local show, bends, paints = true, true, false

		if kind == KIND_DISC then
			local r = pa[i]
			local turn = 5.196 * r ^ -1.5 * speed
			local ph = pb[i] + turn * now
			local s, c = sin(ph), cos(ph)
			x, y, z = r * c, pc[i] * (0.05 + 0.03 * r) + 0.05 * sin(ph * 3 + seed * TAU), r * s
			if (i + frame) % paint == 0 then
				paints = true
				local tx, ty, tz = cx - x, cy - y, cz - z
				local tl = sqrt(tx * tx + ty * ty + tz * tz)
				local beta = 0.42 * sqrt(3 / r)
				local doppler = sqrt(1 - beta * beta) / (1 - beta * (-s * tx + c * tz) / tl)
				local temp = (3 / r) ^ 0.75
				local streaks = 0.60
					+ 0.30 * sin(2 * (ph - 0.35 * now * speed) + 4.5 * log(r))
					+ 0.13 * sin(5 * (ph - 0.2 * now * speed) - 7 * log(r) + 1.7)
					+ 0.3 * (seed - 0.5)
				heat = 0.9 * temp * doppler * sqrt(1 - 1 / r) / 0.8165
				bright = temp ^ 1.5 * doppler ^ 3 * math.max(streaks, 0.07) * (1 - 0.7 * smooth(7.5, 9.4, r))
				bright *= 1 + 1.5 * flare * exp(-(r - 3) * 0.45)
				if wave > 0 then
					bright *= 1 + 3 * exp(-((r - 3 - wave) / 0.7) ^ 2) * exp(-wave * 0.16)
				end
			end
		elseif kind == KIND_RING then
			local angle = pb[i]
			local s, c = sin(angle), cos(angle)
			local wx, wy, wz = c * ux + s * vx, c * uy + s * vy, c * uz + s * vz
			local rr = RING_AT + 0.07 * pc[i]
			x, y, z = wx * rr, wy * rr, wz * rr
			bends, show = false, lens > 0.01
			if (i + frame) % paint == 0 then
				paints = true
				-- the disc's matter on that side of the picture is moving along up cross w, reversed
				local dx, dz = -wz, wx
				local doppler = 0.866 / (1 - 0.5 * -(dx * nx + dz * nz))
				heat = 1.05 * doppler
				bright = 0.8 * doppler ^ 3 * (0.7 + 0.3 * sin(angle * 9 + now * 3 + seed * 6)) * (1 + flare)
			end
		elseif kind == KIND_MOTE then
			x, y, z = pa[i], pb[i], pc[i]
		elseif kind == KIND_JET then
			local h = (pb[i] + now * (0.05 + 0.04 * seed)) % 1 * JET_LENGTH
			local out = (0.14 + 0.04 * h) * sqrt(pc[i])
			local angle = seed * TAU + h * 0.9 - now * 1.5
			x, y, z = out * cos(angle), pa[i] * (2.75 + h), out * sin(angle)
		elseif kind == KIND_SPARK then
			local u = (pb[i] + now * 0.09 * (0.6 + seed)) % 1
			local r = 3.15 + (1.0 - 3.15) * u * u
			local ph = seed * TAU + 7 * u ^ 1.4 + now * 0.9
			x, y, z = r * cos(ph), pc[i] * 0.05, r * sin(ph)
			if (i + frame) % paint == 0 then
				paints = true
				local sink = sqrt(math.max(1 - 1 / r, 0)) -- light from deeper in is redder and dimmer
				heat, bright = 1.1 * sink, sink * sink * (1 - 0.5 * u)
			end
		elseif kind == KIND_DEBRIS then
			if not feeding then
				show = false
			else
				local q = (feed - pd[i] * stretch) / 6.5
				local qc = math.clamp(q, 0, 1)
				local r = 17 + (3.5 + 1.5 * seed - 17) * qc ^ 0.8
				local ph = 2.4
					+ 9 * qc ^ 2.4
					- 4.6 * pd[i] * smooth(0.25, 1, qc)
					+ math.max(q - 1, 0) * 6.5 * 5.196 * r ^ -1.5 * speed
				local loose = 1.15 * (1 - 0.75 * qc)
				x = r * cos(ph) + pa[i] * loose
				y = 3.5 * (1 - qc) * (1 - qc) + pb[i] * loose
				z = r * sin(ph) + pc[i] * loose
				bright = 0.6 * (1 + 0.9 * qc) * (1 - smooth(1, 1.9, q)) * smooth(0, 0.6, feed)
				heat = 0.5 + 0.62 * qc
				paints = true
				show = bright > 0.02
			end
		end

		-- the lens: only what lies behind the hole, as this viewer sees it, is bent
		local image = images[i]
		if show and bends and lens > 0.001 then
			local dx, dy, dz = x - cx, y - cy, z - cz
			local depth = dx * nx + dy * ny + dz * nz
			local behind = depth - far
			if behind > 0 then
				local ex, ey, ez = dx - depth * nx, dy - depth * ny, dz - depth * nz
				local el = sqrt(ex * ex + ey * ey + ez * ez)
				local across = el * far / depth -- how far off the line of sight, measured at the hole
				if el < 1e-4 then
					ex, ey, ez, el = ux, uy, uz, 1 -- dead behind the hole: any direction will do
				end
				local ring2 = 2 * lens * far * behind / depth -- the Einstein ring's radius, squared
				local root = sqrt(across * across + 4 * ring2)
				local shown = if image == 0 then 0.5 * (across + root) else 0.5 * (root - across)
				if shown < SHADOW then
					show = false -- that light fell in
				else
					local k = shown * depth / far / el * (if image == 0 then 1 else -1)
					x, y, z = cx + depth * nx + ex * k, cy + depth * ny + ey * k, cz + depth * nz + ez * k
				end
			elseif image == 1 then
				show = false
			end
		elseif image == 1 then
			show = false
		end

		-- a cube that is not showing is made invisible where it is, and placed afresh when it shows again
		if show ~= showns[i] then
			showns[i] = show
			parts[i].Transparency = if show then 0 else 1
			ixs[i] = 1e9
		end
		if show then -- onto the grid
			local ix, iy, iz = floor(x / grid + 0.5), floor(y / grid + 0.5), floor(z / grid + 0.5)
			if ix ~= ixs[i] or iy ~= iys[i] or iz ~= izs[i] then
				ixs[i], iys[i], izs[i] = ix, iy, iz
				local here = CFrame.new(ix * grid * scale, iy * grid * scale, iz * grid * scale)
				ats[i] = here
				if not moved then
					moves += 1
					moveParts[moves] = parts[i]
					moveTo[moves] = origin * here
				end
			end
		end
		if paints and show then
			local index = tone(heat, if image == 1 then bright * 0.7 else bright)
			if index ~= tones[i] then
				tones[i] = index
				parts[i].Color = PALETTE[index]
			end
		end
	end

	if moved then -- the hole itself moved: every showing cube and the ball are placed again
		for i = 1, self._count do
			if showns[i] then
				moves += 1
				moveParts[moves] = parts[i]
				moveTo[moves] = origin * ats[i]
			end
		end
		for i, part in self._ballParts do
			moves += 1
			moveParts[moves] = part
			moveTo[moves] = origin * self._ballAt[i]
		end
	end
	if moves > 0 then
		Workspace:BulkMoveTo(moveParts, moveTo, Enum.BulkMoveMode.FireCFrameChanged)
	end
	self._placed = true
end

-- Run by itself every frame, from the camera
function BlackHole.Start(self: BlackHole)
	if self._step then
		return
	end
	self._step = RunService.RenderStepped:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		if camera then
			self:Step(math.min(dt, 0.1), camera.CFrame.Position)
		end
	end)
end

function BlackHole.Stop(self: BlackHole)
	local step = self._step
	if step then
		step:Disconnect()
		self._step = nil
	end
end

function BlackHole.Destroy(self: BlackHole)
	self:Stop()
	self._folder:Destroy()
	table.clear(self._part)
	table.clear(self._ballParts)
	table.clear(self._moveParts)
	table.clear(self._moveTo)
	self._count = 0
end

return BlackHole
