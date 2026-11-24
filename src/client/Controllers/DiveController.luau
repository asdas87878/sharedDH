--!strict
-- The leap off the dock (2026-11-23, the user: "make a sick dive animation for when the player jumps into the water
-- initially from the dive stand. We need nice camera angles, a splash and stuff. leave sound fx for now. We will need
-- to make sure it looks good and natural and dynamic"). Config.Dive.Leap, off (0) until it is played.
-- There is no stand: running off the flat lip of the start strip, under the DIVE IN arch, is the dive. A crouch at
-- the edge, a high arc out over the water, turning from upright to face down just after the top and head first at
-- the water, a splash, on under the surface along the same line, and the dive's hop (JumpController) takes over from
-- there as it always has. Our own machine moves our own body, as it does in a hop; the server is told nothing new (it
-- sees us go under and does what it always does). Every machine sees the arc, poses anyone leaping by the tilt of
-- their body (AnimController asks `poseOf`) and splashes anyone who goes in fast (Lib/Splash).
-- All we see of our own dive is worked out from the dive's time alone and what was frozen as it began (where, which
-- way, the camera's side): the body, its tilt, the pose, the camera and the splash. So any moment can be held and
-- looked at (the test hooks at the end).
-- In this file, in order:
--   looking for the water: rays down, under us, ahead of us and along the arc;
--   the plan: one dive, frozen as it begins, and where the body is and how it is tilted at any time in it;
--   the pose's phase: ours from the plan, anyone else's from the tilt of their body;
--   the camera's moves: its keys and the curve through them, the chase under the water, the hand-over;
--   the splash watcher: anyone crossing the surface fast, on every machine;
--   beginning a dive, and letting it go (the body, the pose and the camera each let go on their own);
--   the steps: the body's (just after the hop's, before the riding step) and the camera's (after the riding camera);
--   test hooks (tools/studio/dive_leap_check.py);
--   Init / Start.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local Feel = require(script.Parent.Parent.Lib.Feel)
local Fx = require(script.Parent.Parent.Lib.Fx)
local Shake = require(script.Parent.Parent.Lib.Shake)
local Splash = require(script.Parent.Parent.Lib.Splash)
local State = require(script.Parent.Parent.Lib.State)
local RideController = require(script.Parent.RideController)

local DiveController = {}

local UP = Vector3.yAxis
local FLAT = Vector3.new(1, 0, 1)
local camera = workspace.CurrentCamera
local smooth = Ease.smoothstep
local lerp = Ease.lerp

----------------------------------------------------------------------------------------------------------------------
-- Looking for the water

-- Rays for the ground and walls: only what we could stand on or hit (CanCollide), never the water, never a character
-- (anyone's) or the camera's own effects
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
rayParams.IgnoreWater = true
local filteredAt = -math.huge
local function rays(): RaycastParams
	local now = os.clock()
	if now - filteredAt > 0.5 then
		filteredAt = now
		local skip: { Instance } = { camera }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(skip, player.Character)
			end
		end
		rayParams.FilterDescendantsInstances = skip
	end
	return rayParams
end
-- the ground under our own feet: only our own character left out (another player we stand on is ground)
local ownParams = RaycastParams.new()
ownParams.FilterType = Enum.RaycastFilterType.Exclude
ownParams.RespectCanCollide = true
ownParams.IgnoreWater = true
local function ownRays(): RaycastParams
	local skip: { Instance } = { camera }
	local character = State.Player.Character
	if character then
		table.insert(skip, character)
	end
	ownParams.FilterDescendantsInstances = skip
	return ownParams
end

-- the camera's: as the riding camera's (the lane's props are left out: fish break them and swim through)
local cameraParams = RaycastParams.new()
cameraParams.FilterType = Enum.RaycastFilterType.Exclude
cameraParams.RespectCanCollide = true
cameraParams.IgnoreWater = true

local function surfaceY(): number
	return Config.Depth.SurfaceY
end

-- The top of what we could stand on under `from`, down to the water (nil: open water under it). `own`: under our own
-- feet (other characters count as ground there)
local function groundUnder(from: Vector3, own: boolean?): number?
	local drop = from.Y - surfaceY()
	if drop <= 0 then
		return nil
	end
	local hit = workspace:Raycast(from, Vector3.new(0, -(drop + 0.05), 0), if own then ownRays() else rays())
	return if hit then hit.Position.Y else nil
end

-- The dock's spawn (RideService sets it): where it stands and the way into the water
local function dockFrame(): CFrame?
	local dock = Net.Folder:GetAttribute("Dock")
	return if typeof(dock) == "CFrame" then dock else nil
end

local function yawOf(look: Vector3): number
	return math.atan2(-look.X, -look.Z)
end

----------------------------------------------------------------------------------------------------------------------
-- The plan: one dive, frozen as it begins

type Key = { t: number, at: Vector3, slope: Vector3 }

type Plan = {
	start: Vector3, -- the root as it began
	ground: number, -- the floor's top under it
	heading: Vector3, -- the way out, flat, length 1
	right: Vector3,
	yaw: number, -- the heading as a yaw
	fromYaw: number, -- the way the character faced as it began
	side: number, -- the camera's side: 1 right of the heading, -1 left
	crouch: number, -- seconds of crouch (0: begun over the water already)
	takeoff: Vector3, -- where the arc begins
	far: number, -- the arc: out this far, and up a * u - c * u * u at u of the way (y at u = 1 is the surface)
	a: number,
	c: number,
	air: number, -- seconds in the air
	top: number, -- u at the arc's top
	surface: number,
	entry: Vector3,
	entryVelocity: Vector3,
	entryTilt: number,
	line: Vector3, -- on under the water along this, length 1,
	sinkLength: number, -- this far,
	sink: number, -- over this long,
	sinkPower: number, -- easing out as 1 - (1 - s) ^ this (it leaves the surface at the speed it came in)
	lean: number,
	flip: boolean,
	camFrom: CFrame, -- the view as it began
	camFov: number,
	waterLine: number, -- the riding camera's line under the surface (RideController.waterLine)
	keys: { Key },
	tEntry: number,
	tTop: number,
	tFollow: number,
	-- on the ride fish (Config.Dive.LeapMounted): the fish's own dive. For a diver: false, 1, 1, 0.9, 0.6, 0
	mounted: boolean,
	scale: number, -- the fish's length over LeapMountedSize, held to LeapMountedLeast..Most
	camScale: number, -- the camera's distances times this
	dip: number, -- the crouch sinks this far, studs
	centreUp: number, -- the camera looks at the root plus this, up
	level: number, -- under the water the fish levels to this tilt, degrees
}

-- The ride fish under us, as the leap sees it: its box (and the rider's head over it) in the root's own space as it
-- stood, its length and how far its lowest point is under the root
type Fish = { rel: CFrame, size: Vector3, length: number, depth: number }

-- The arc at u (0 at the takeoff, 1 at the surface)
local function arcAt(p: Plan, u: number): Vector3
	return p.takeoff + p.heading * (p.far * u) + UP * (p.a * u - p.c * u * u)
end

-- The angle of the arc's line below level at u, degrees
local function pathAngle(p: Plan, u: number): number
	return math.deg(math.atan2(-(p.a - 2 * p.c * u), p.far))
end

-- Where the root is at dive time t
local function posAt(p: Plan, t: number): Vector3
	if t < p.crouch then
		-- the crouch: on a step or two to the edge, sinking into the knees and coming back up as the push begins
		local u = t / p.crouch
		local dip = if u < 0.7 then smooth(0, 0.7, u) else 1 - smooth(0.7, 1, u)
		return p.start:Lerp(p.takeoff, u) - UP * (p.dip * dip)
	elseif t < p.tEntry then
		return arcAt(p, (t - p.crouch) / p.air)
	end
	local s = math.clamp((t - p.tEntry) / math.max(p.sink, 0.01), 0, 1)
	return p.entry + p.line * (p.sinkLength * (1 - (1 - s) ^ p.sinkPower))
end

local function velocityAt(p: Plan, t: number): Vector3
	local h = 1 / 240
	return (posAt(p, t + h) - posAt(p, math.max(t - h, 0))) / (h + math.min(t, h))
end

-- How far the body is tipped forward from upright at dive time t, degrees (90: face down; 180: head down)
local function tiltAt(p: Plan, t: number): number
	if t < p.crouch then
		return p.lean * smooth(0, p.crouch, t)
	elseif p.mounted then
		-- the fish: its nose along the arc (up off the edge, over, down into the water), a moment behind it, from
		-- level at the push; under the water it levels out (the water fish it is swapped for is level)
		if t < p.tEntry then
			local u = (t - p.crouch) / p.air
			local lag = 0.05 * (1 - smooth(0.55, 1, u))
			return lerp(p.lean, pathAngle(p, u - lag), smooth(0, 0.3, u))
		end
		return lerp(p.entryTilt, p.level, smooth(0, math.max(p.sink, 0.01), t - p.tEntry))
	elseif t < p.tEntry then
		local u = (t - p.crouch) / p.air
		-- along the arc, a moment behind it (face down just after the top), and on it exactly at the water
		local lag = 0.07 * (1 - smooth(0.55, 1, u))
		local path = 90 + pathAngle(p, u - lag)
		local tilt = lerp(p.lean, path, smooth(0, 0.3, u))
		if p.flip then
			tilt += 360 * smooth(0.15, 0.8, u)
		end
		return tilt
	end
	return p.entryTilt
end

local function yawAt(p: Plan, t: number): number
	local turn = if p.crouch > 0 then smooth(0, p.crouch, t) else smooth(0, 0.12, t)
	return Ease.lerpAngle(p.fromYaw, p.yaw, turn)
end

local function frameAt(p: Plan, t: number): CFrame
	return CFrame.new(posAt(p, t))
		* CFrame.fromOrientation(0, yawAt(p, t), 0)
		* CFrame.Angles(-math.rad(tiltAt(p, t)), 0, 0)
end

-- The tuck of a somersault at dive time t: 0 to 1
local function tuckAt(p: Plan, t: number): number
	if not p.flip or t < p.crouch or t >= p.tEntry then
		return 0
	end
	local u = (t - p.crouch) / p.air
	return smooth(0.12, 0.28, u) * (1 - smooth(0.62, 0.8, u))
end

-- The pose's phase at dive time t: 0 to 1 the crouch, 1 to 2 the air, 2 to 3 under the water
local function phaseAt(p: Plan, t: number): number
	if t < p.crouch then
		return t / p.crouch
	elseif t < p.tEntry then
		return 1 + (t - p.crouch) / p.air
	end
	return 2 + math.clamp((t - p.tEntry) / math.max(p.sink, 0.01), 0, 1)
end

-- The camera under the water, following: straight back from the diver the way they went (not up their line, which
-- held it 4 to 6 studs off and put it through the surface inside the splash) and a little over, never above the riding
-- camera's line. `diver`: where the body is (the root)
local function chaseAt(p: Plan, diver: Vector3): Vector3
	local d = Config.Dive
	local at = diver - p.heading * (d.LeapCamFollow * p.camScale) + UP * (d.LeapCamFollowUp * p.camScale)
	return Vector3.new(at.X, math.min(at.Y, p.waterLine - 1), at.Z)
end

-- The camera's keys, each at a dive time: the view as it began; low beside the edge looking up; craned up and over
-- through the top; high behind where they go in; just over the water behind the splash; through the surface after
-- them (quickly: between the surface and the riding camera's line it is inside the water's lit layers, all white)
local function cameraKeys(p: Plan): { Key }
	local d = Config.Dive
	local k = p.camScale -- (1 for a diver; further back for a big fish)
	local keys: { Key } = {}
	local function add(t: number, at: Vector3)
		table.insert(keys, { t = t, at = at, slope = Vector3.zero })
	end
	add(0, p.camFrom.Position)
	-- (the key times always rise: off a high ledge the top comes early, and the keys either side are kept off it)
	local gap = 0.05
	local low = p.takeoff + p.right * (p.side * d.LeapCamSide * k) - p.heading * (d.LeapCamBack * k)
	local lowAt = math.min(p.crouch + 0.28 * p.air, math.max(p.tTop - gap, p.tTop * 0.5))
	add(lowAt, Vector3.new(low.X, p.ground + d.LeapCamLow, low.Z))
	add(
		p.tTop,
		arcAt(p, p.top)
			+ p.right * (p.side * d.LeapCamCraneSide * k)
			- p.heading * (d.LeapCamCraneBack * k)
			+ UP * (d.LeapCamCraneUp * k)
	)
	local high = p.entry - p.heading * (d.LeapCamHighBack * k) + p.right * (p.side * 3 * k)
	local highAt = math.max(p.crouch + 0.85 * p.air, math.min(p.tTop + gap, (p.tTop + p.tFollow) / 2))
	add(highAt, Vector3.new(high.X, p.surface + d.LeapCamHigh * k, high.Z))
	local overAt = p.tEntry + d.LeapCamOver
	if d.LeapCamOver > 0 and overAt > keys[#keys].t + 0.05 and overAt < p.tFollow - 0.05 then
		local over = p.entry - p.heading * (d.LeapCamFollow * k) + p.right * (p.side * 3 * k)
		add(overAt, Vector3.new(over.X, p.surface + d.LeapCamOverHigh * k, over.Z))
	end
	add(p.tFollow, chaseAt(p, posAt(p, p.tFollow)))
	-- the slopes (a curve through the keys by time): still at the first, the chase's own pace at the last
	for i = 2, #keys - 1 do
		keys[i].slope = (keys[i + 1].at - keys[i - 1].at) / math.max(keys[i + 1].t - keys[i - 1].t, 0.01)
	end
	local h = 1 / 60
	keys[#keys].slope = (chaseAt(p, posAt(p, p.tFollow + h)) - keys[#keys].at) / h
	return keys
end

-- Where the camera's curve is at dive time t (before the chase)
local function curveAt(p: Plan, t: number): Vector3
	local keys = p.keys
	if t <= keys[1].t then
		return keys[1].at
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.t then
			local h = b.t - a.t
			local s = (t - a.t) / math.max(h, 1e-3)
			local s2, s3 = s * s, s * s * s
			return a.at * (2 * s3 - 3 * s2 + 1)
				+ a.slope * (h * (s3 - 2 * s2 + s))
				+ b.at * (-2 * s3 + 3 * s2)
				+ b.slope * (h * (s3 - s2))
		end
	end
	return keys[#keys].at
end

-- Whether the fish's box (and the rider over it) meets anything along the arc: swept from pose to pose, and looked for
-- at each pose too (a sweep does not see what it begins inside). Not the water, nor any character
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.RespectCanCollide = true
local function fishClear(p: Plan, fish: Fish, params: RaycastParams): (boolean, string?)
	local size = fish.size * 0.85
	local skip = table.clone(params.FilterDescendantsInstances)
	table.insert(skip, workspace.Terrain) -- (its water: the sweeps see the terrain's ground)
	overlap.FilterDescendantsInstances = skip
	local last = frameAt(p, p.crouch) * fish.rel
	for i = 1, 10 do
		local at = frameAt(p, p.crouch + p.air * i / 10) * fish.rel
		local move = at.Position - last.Position
		local hit = if move.Magnitude > 0.01 then workspace:Blockcast(last, size, move, params) else nil
		if hit then
			return false, `its box meets {hit.Instance.Name} (swept, step {i} of 10)`
		end
		if i < 10 then
			local inside = workspace:GetPartBoundsInBox(at, size, overlap)
			if #inside > 0 then
				return false, `its box is in {inside[1].Name} (step {i} of 10)`
			end
		end
		last = at
	end
	return true, nil
end

-- One dive from `start` (the root), facing `fromYaw`, out along `heading` (flat, length 1) at `speed`, with a crouch
-- or not. Nil when the arc would meet anything, or come down anywhere but open water. `fish`: on the ride fish (its
-- own dive: Config.Dive.LeapMounted), nil for a diver. `whyNot` is what the last call passed over, try by try (the test
-- hooks and the log read it)
local whyNot: { string } = {}
local function makePlan(
	start: Vector3,
	ground: number,
	heading: Vector3,
	fromYaw: number,
	speed: number,
	crouch: boolean,
	camFrom: CFrame,
	camFov: number,
	fish: Fish?
): Plan?
	local d = Config.Dive
	local surface = surfaceY()
	local right = Vector3.new(-heading.Z, 0, heading.X)
	local crouchTime = if crouch then math.max(d.LeapCrouch, 0) else 0
	local takeoff = start + heading * (math.min(speed, 20) * crouchTime * 0.6)
	-- the fish's size: the arc's height and length go as its square root, the time as its 0.35th power; and the arc
	-- ends with the root over the water by half the fish's depth (the fish noses in, its middle meets the water)
	local scale = 1
	local baseHigh, baseFar, baseTime = d.LeapHigh, d.LeapFar, d.LeapTime
	local endY = surface
	if fish then
		scale = math.clamp(
			fish.length / math.max(d.LeapMountedSize, 1),
			math.max(d.LeapMountedLeast, 0.1),
			math.max(d.LeapMountedMost, d.LeapMountedLeast, 0.1)
		)
		baseHigh = d.LeapMountedHigh * math.sqrt(scale)
		baseFar = d.LeapMountedFar * math.sqrt(scale)
		baseTime = d.LeapMountedTime * scale ^ 0.35
		endY = surface + 0.5 * fish.depth
	end
	local drop = takeoff.Y - endY
	table.clear(whyNot)
	if drop < 0.5 then
		table.insert(whyNot, "no drop to the water from here")
		return nil
	end
	local params = rays()
	-- the arc that fits: as asked; lower; lower and shorter
	for n, try in { { 1, 1 }, { 0.6, 1 }, { 0.6, 0.7 }, { 0.3, 0.5 } } do
		local high = math.max(baseHigh, 0.5) * try[1]
		local far = math.max(baseFar, 2) * try[2]
		local air = math.max(baseTime, 0.2) * (0.7 + 0.3 * try[1])
		if fish then
			-- (never faster across the ground than the server's land pace check lets the land fish go: Equip)
			local e = Config.Equip
			far = math.min(far, e.LandSpeed * e.PaceRoom * 0.8 * air)
		end
		local a = 2 * high + 2 * math.sqrt(high * high + high * drop)
		local c = a + drop
		local clear = true
		if not fish then
			local last = takeoff
			for i = 1, 10 do
				local u = i / 10
				local at = takeoff + heading * (far * u) + UP * (a * u - c * u * u)
				local hit = workspace:Spherecast(last, 1.2, at - last, params)
				if hit then
					clear = false
					table.insert(whyNot, `arc {n}: {hit.Instance.Name} in the way`)
					break
				end
				last = at
			end
		end
		local entry = takeoff + heading * far + UP * (a - c)
		local open = clear and groundUnder(Vector3.new(entry.X, takeoff.Y, entry.Z)) == nil
		if clear and not open then
			table.insert(whyNot, `arc {n}: no open water where it comes down`)
		end
		if open and fish then
			-- (and open water under the fish's nose and tail as it goes in)
			for i, z in { fish.rel.Z - fish.size.Z / 2, fish.rel.Z + fish.size.Z / 2 } do
				local at = entry - heading * z
				if groundUnder(Vector3.new(at.X, takeoff.Y, at.Z)) ~= nil then
					open = false
					table.insert(whyNot, `arc {n}: its {if i == 1 then "nose" else "tail"} comes down over the floor`)
				end
			end
		end
		if open then
			local entryVelocity = (heading * far + UP * (a - 2 * c)) / air
			local line = entryVelocity.Unit
			-- on under the water along that line: LeapDepth down, never nearer the seabed than 8, nor into a wall
			local bedHit = workspace:Raycast(entry, Vector3.new(0, -400, 0), params)
			local bed = if bedHit then bedHit.Position.Y else surface - 46
			local depth = math.max(math.min(d.LeapDepth, entry.Y - (bed + 8)), 1)
			local length = depth / math.max(-line.Y, 0.2)
			local wall = workspace:Raycast(entry, line * (length + 3), params)
			if wall then
				length = math.max((wall.Position - entry).Magnitude - 3, 1)
			end
			local sink = math.max(d.LeapSink, 0.05)
			local through = if fish then d.LeapMountedThrough else d.LeapCamThrough
			local p: Plan = {
				start = start,
				ground = ground,
				heading = heading,
				right = right,
				yaw = yawOf(heading),
				fromYaw = fromYaw,
				side = 1,
				crouch = crouchTime,
				takeoff = takeoff,
				far = far,
				a = a,
				c = c,
				air = air,
				top = a / (2 * c),
				surface = surface,
				entry = entry,
				entryVelocity = entryVelocity,
				entryTilt = 0,
				line = line,
				sinkLength = length,
				sink = sink,
				sinkPower = math.clamp(entryVelocity.Magnitude * sink / length, 1.2, 4),
				lean = if fish then -4 else d.LeapLean,
				flip = d.Flip > 0 and not fish,
				camFrom = camFrom,
				camFov = camFov,
				waterLine = RideController.waterLine(),
				keys = {},
				tEntry = crouchTime + air,
				tTop = crouchTime + air * a / (2 * c),
				tFollow = crouchTime + air + math.max(through, 0.05),
				mounted = fish ~= nil,
				scale = scale,
				camScale = if fish then math.max(d.LeapMountedCam, 0.5) * scale ^ 0.7 else 1,
				dip = if fish then 0.4 else 0.9,
				centreUp = if fish then (2 - fish.depth) / 2 else 0.6,
				level = d.LeapMountedLevel,
			}
			p.entryTilt = if fish then pathAngle(p, 1) else 90 + pathAngle(p, 1)
			local fits, met = true, nil :: string?
			if fish then
				fits, met = fishClear(p, fish, params)
			end
			if not fits then
				table.insert(whyNot, `arc {n}: {met}`)
			end
			if fits then
				-- the camera's side: the side it is on already, unless the low spot beside the edge is in a wall
				local onRight = (camFrom.Position - start):Dot(right)
				p.side = if onRight < 0 then -1 else 1
				local low = takeoff
					+ right * (p.side * d.LeapCamSide * p.camScale)
					- heading * (d.LeapCamBack * p.camScale)
				low = Vector3.new(low.X, ground + d.LeapCamLow, low.Z)
				if workspace:Raycast(takeoff + UP * 2, low - (takeoff + UP * 2), params) then
					p.side = -p.side
				end
				p.keys = cameraKeys(p)
				return p
			end
		end
	end
	return nil
end

----------------------------------------------------------------------------------------------------------------------
-- The dive as it runs (one at a time: ours)

local plan: Plan? = nil
local startedAt = 0 -- os.clock() it began
local heldAt: number? = nil -- the test hook's held dive time
local leapCharacter: Model? = nil
local body = false -- we move the body
local lastWritten: Vector3? = nil
local lastRotation = CFrame.identity
local carryFrom: CFrame? = nil -- the body's turn as the hop took over, and when
local carryAt = 0
local freeAt: number? = nil -- the server said we are in the water (Free), and when
local bodyGoneAt = 0
local posing = false -- the pose is the dive's
local popHold = false -- held on through the hop's push
local seatHoldAt: number? = nil -- (on the ride fish) held seated after the water fish has us, until we are Riding
local ownPhase, ownTuck = 3, 0
local entered = false -- the water's moment (the splash, its shake) is past
local topped = false
local splashId: number? = nil
local ownSplashAt = -math.huge
local armed = true -- a dive may begin: not again until we have stood on something
local broken = false -- an error: off until the next join, with one warning
local warmed = false -- (the splash's pool and the bubbles' emitters made ahead)
local splashBroken = false -- (the splashes' own step failed too, once broken: no more tries)
-- the camera
local filming = false
local handAt: number? = nil -- the hand-over to the riding camera began
local handTime = 0.5
local took = false -- the player took the view
local orbit = false -- (on the dock, after the player took it: following us round, turned by them)
local orbitYaw, orbitPitch, orbitDistance = 0, 0, 0
local orbitFrom: CFrame? = nil
local orbitAt = 0
local lookMoved = 0
local turnBy = Vector2.zero -- the look input since the last frame, radians
local stick = Vector2.zero
local reach, camY = 1, math.huge
-- where the film takes the diver to be: the root, but a cut in it (put on a fish's saddle) is eased across
local diverLast: Vector3? = nil
local diverOffset = Vector3.zero
-- the log (test hook): `live` is the riding camera's view that frame (nil: none yet), `blend` how far the hand-over to
-- it has gone (0 to 1)
type Frame = {
	t: number,
	pos: Vector3,
	tilt: number,
	state: string,
	cam: Vector3,
	fov: number,
	body: boolean,
	live: Vector3?,
	blend: number,
}
local liveSeen: Vector3? = nil
local blendSeen = 0
local frames: { Frame } = {}
local events: { { [string]: any } } = {}
local lastFrameT = -1

local function event(kind: string, data: { [string]: any }?)
	local e: { [string]: any } = data or {}
	e.kind = kind
	e.t = if plan then (heldAt or (os.clock() - startedAt)) else 0
	e.clock = os.clock()
	if #events < 100 then
		table.insert(events, e)
	end
end

local function welded(root: BasePart): boolean
	for _, joint in root:GetJoints() do
		if joint.Name == "RideWeld" then
			return true
		end
	end
	return false
end

-- The ride fish a player rides on land (RideService's land fish: workspace.LandFish, its LandRider), nil if none
local function landFishOf(player: Player): Model?
	local folder = workspace:FindFirstChild("LandFish")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("LandRider") == player.UserId then
			return model
		end
	end
	return nil
end

-- A fish as the leap sees it, from its box's corners in the root's own space (`low`, `high`)
local function fishFrom(low: Vector3, high: Vector3): Fish
	local length = high.Z - low.Z
	-- (the rider's head over the saddle is in the box too: the arch over the strip is looked for with it)
	high = Vector3.new(high.X, math.max(high.Y, 2.5), high.Z)
	return {
		rel = CFrame.new((low + high) / 2),
		size = high - low,
		length = length,
		depth = math.max(-low.Y, 0),
	}
end

-- That fish as the leap sees it, from its box as it stands under `root` (nil: no fish, or none yet)
local function fishOf(player: Player, root: BasePart): Fish?
	local model = landFishOf(player)
	if not model or not model.PrimaryPart then
		return nil
	end
	local box, size = model:GetBoundingBox()
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, corner in
		{
			Vector3.new(-1, -1, -1),
			Vector3.new(-1, -1, 1),
			Vector3.new(-1, 1, -1),
			Vector3.new(-1, 1, 1),
			Vector3.new(1, -1, -1),
			Vector3.new(1, -1, 1),
			Vector3.new(1, 1, -1),
			Vector3.new(1, 1, 1),
		}
	do
		local at = root.CFrame:PointToObjectSpace(box:PointToWorldSpace(size / 2 * corner))
		low, high = low:Min(at), high:Max(at)
	end
	return fishFrom(low, high)
end

----------------------------------------------------------------------------------------------------------------------
-- The pose's phase

-- (each other player's pose as last worked out, and when they were last seen leaping on their ride fish)
local seen: { [Player]: { at: number, phase: number?, tuck: number, mounted: boolean, leapAt: number } } = {}
local otherParams = RaycastParams.new()
otherParams.FilterType = Enum.RaycastFilterType.Exclude
otherParams.RespectCanCollide = true
otherParams.IgnoreWater = true

local function otherPhase(player: Player): (number?, number, boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return nil, 0, false
	end
	-- (only asked while they are on the dock: AnimController poses anyone else's leap by Dock alone, or Land)
	if player:GetAttribute("State") ~= "Dock" then
		return nil, 0, false
	end
	local mounted = player:GetAttribute("LandMounted") == true
	if player:GetAttribute("TankRide") or (mounted and Config.Dive.LeapMounted <= 0) then
		return nil, 0, false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and (humanoid.Sit or humanoid.SeatPart) then
		return nil, 0, false
	end
	local dock = dockFrame()
	if dock and ((root.Position - dock.Position) * FLAT).Magnitude > Config.Oxygen.DockRadius + 90 then
		return nil, 0, false
	end
	local cf = root.CFrame
	local tilt = math.deg(math.atan2(-cf.LookVector.Y, cf.UpVector.Y))
	if mounted then
		-- on their ride fish: its nose up off the edge, over, and down (a gentler tilt than a diver's, through level
		-- at the top: held on through it for a moment), in the air over the fish's height
		local was = seen[player]
		local lately = was ~= nil and os.clock() - was.leapAt < 0.4
		if math.abs(tilt) < 6 and not lately then
			return nil, 0, false
		end
		local below = (if humanoid then humanoid.HipHeight else 0) + root.Size.Y / 2 + 3
		otherParams.FilterDescendantsInstances = { character }
		if workspace:Raycast(root.Position, Vector3.new(0, -below, 0), otherParams) then
			return nil, 0, false
		end
		if root.Position.Y < surfaceY() - 0.5 then
			return 2.5, 0, true
		end
		-- (the arc's way through, from the nose's tilt: about 30 degrees up off the edge, 37 down into the water)
		local u = (1 + 1.8 * math.tan(math.rad(math.clamp(tilt, -60, 60)))) / 2.35
		return 1 + 0.98 * math.clamp(u, 0, 1), 0, true
	end
	if math.abs(tilt) < 25 then
		return nil, 0, false
	end
	-- (in the air: nothing to stand on within 5 studs under them)
	otherParams.FilterDescendantsInstances = { character }
	if workspace:Raycast(root.Position, Vector3.new(0, -5, 0), otherParams) then
		return nil, 0, false
	end
	if root.Position.Y < surfaceY() - 0.5 then
		return 2.5, 0, false
	elseif tilt < -15 and tilt > -170 then
		-- past head down and on round: the somersault (Config.Dive.Flip)
		return 1.5, 1, false
	end
	return 1.15 + 0.85 * math.clamp((tilt - 20) / 130, 0, 1), 0, false
end

----------------------------------------------------------------------------------------------------------------------
-- The splash watcher: anyone going in fast, on every machine

local everyone: { Player } = {}
local lastY: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function powerOf(speed: number): number
	local d = Config.Dive
	return 0.25 + 0.75 * math.clamp((speed - d.LeapSplashFrom) / math.max(d.LeapSplashFull - d.LeapSplashFrom, 1), 0, 1)
end

local function watch(dt: number)
	local d = Config.Dive
	local surface = surfaceY()
	local eye = camera.CFrame.Position
	for _, player in everyone do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			local y = root.Position.Y
			local was = lastY[character]
			lastY[character] = y
			if was and was > surface and y <= surface and dt > 0 then
				local speed = (was - y) / dt
				local mine = player == State.Player
				-- (our own dive's splash is the dive's, at its own moment)
				local ours = mine and (State.Leaping or os.clock() - ownSplashAt < 2)
				-- someone on their ride fish (its leap, Config.Dive.LeapMounted, goes in less steeply): by their whole
				-- speed, and as big as the fish
				local size = 1
				if d.LeapMounted > 0 and not ours and player:GetAttribute("LandMounted") == true then
					speed = math.max(speed, root.AssemblyLinearVelocity.Magnitude)
					local fish = landFishOf(player)
					if fish then
						local length = fish:GetExtentsSize().Z
						size =
							math.clamp(length / math.max(d.LeapMountedSize, 1), d.LeapMountedLeast, d.LeapMountedMost)
					end
				end
				if not ours and speed >= d.LeapSplashFrom and (root.Position - eye).Magnitude <= d.LeapSplashFar then
					local at = Vector3.new(root.Position.X, surface, root.Position.Z)
					Splash.play(at, root.AssemblyLinearVelocity, math.min(powerOf(speed) * size, 1), player.UserId)
					if d.Splash > 0 then
						Fx.burstKept(at - UP, math.ceil(d.Splash * (if mine then 1 else 0.5)), d.SplashReach)
					end
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Beginning, and letting go

local function releaseCamera(why: string)
	if not filming then
		return
	end
	filming = false
	orbit = false
	if not State.inWater() then
		-- back on the dock (or the dive let go before the water): the ordinary camera takes up from this view
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = Config.Camera.Fov
	end
	event("camera", { why = why })
end

local function releaseBody(why: string)
	if not body then
		return
	end
	body = false
	bodyGoneAt = os.clock()
	State.Leaping = false
	State.LeapHeading = nil
	if why ~= "hop" then
		-- (the dive's hop clears it itself, as it reads it)
		State.LeapSplashed = false
	end
	local _, root, humanoid = State.character()
	if humanoid and State.Mode == "Dock" then
		-- back to the humanoid as it was (in the water RideController holds it out of the way itself)
		humanoid.PlatformStand = false
	end
	-- (the pose is held on through the hop's push; on the ride fish, seated until the water fish's ride is ours:
	-- the weld can come a moment before the word that we are Riding)
	local seated = why == "riding" and plan ~= nil and plan.mounted
	posing = (why == "hop" or seated) and posing
	popHold = posing and not seated
	seatHoldAt = if posing and seated then os.clock() else nil
	event("release", { why = why, depth = if root then surfaceY() - root.Position.Y else 0 })
end

local function releaseAll(why: string)
	releaseBody(why)
	State.Leaping = false
	State.LeapHeading = nil
	State.LeapSplashed = false
	releaseCamera(why)
	posing, popHold, seatHoldAt = false, false, nil
	if splashId and heldAt then
		Splash.release(splashId)
	end
	splashId = nil
	heldAt = nil
	plan = nil
	carryFrom = nil
end

local function begin(p: Plan, character: Model, held: number?, leaveCamera: boolean?)
	local _, root, humanoid = State.character()
	plan = p
	startedAt = os.clock()
	heldAt = held
	leapCharacter = character
	body = true
	posing = true
	popHold = false
	seatHoldAt = nil
	ownPhase, ownTuck = phaseAt(p, held or 0), 0
	carryFrom = nil
	freeAt = nil
	entered = false
	topped = false
	splashId = nil
	armed = false
	lastWritten = nil
	handAt, took, orbit, orbitFrom = nil, false, false, nil
	lookMoved, turnBy = 0, Vector2.zero
	reach, camY = 1, math.huge
	diverLast, diverOffset = nil, Vector3.zero
	State.Leaping = true
	State.LeapHeading = p.yaw
	State.LeapSplashed = false
	if humanoid then
		humanoid.PlatformStand = true
	end
	filming = Config.Dive.LeapCam > 0 and not leaveCamera
	if filming then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	handTime = math.max(Config.Dive.LeapCamHandBack, 0.05)
	table.clear(frames)
	table.clear(events)
	lastFrameT = -1
	event("start", {
		pos = if root then root.Position else p.start,
		speed = if root then (root.AssemblyLinearVelocity * FLAT).Magnitude else 0,
		crouch = p.crouch,
		held = held ~= nil,
		high = p.a * p.a / (4 * p.c),
		far = p.far,
		mounted = p.mounted,
		scale = p.scale,
	})
end

-- Whether a dive begins now, and its plan: on the dock (ours and the server's word), near it, running at the water or
-- gone over the edge already
local function tryStart(force: boolean?)
	local character, root, humanoid = State.character()
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if State.Mode ~= "Dock" or State.Player:GetAttribute("State") ~= "Dock" then
		return
	end
	-- (on the ride fish on land: its own dive, Config.Dive.LeapMounted)
	local landMounted = State.Player:GetAttribute("LandMounted") == true
	if
		State.Player:GetAttribute("TankRide")
		or (landMounted and Config.Dive.LeapMounted <= 0)
		or humanoid.Sit
		or humanoid.SeatPart
		or humanoid.PlatformStand
	then
		return
	end
	local dock = dockFrame()
	if not dock then
		return
	end
	local position = root.Position
	if ((position - dock.Position) * FLAT).Magnitude > Config.Oxygen.DockRadius + 90 then
		return
	end
	local d = Config.Dive
	local out = (dock.LookVector * FLAT).Unit
	local under = groundUnder(position, true)
	if under then
		armed = true
	end
	if not armed and not force then
		return
	end
	local going = root.AssemblyLinearVelocity * FLAT
	local speed = going.Magnitude
	local way = if speed > 4 then going.Unit else out
	-- (running along the edge, or away from the water: no dive)
	local off = math.deg(math.acos(math.clamp(way:Dot(out), -1, 1)))
	if off > d.LeapRefuse and not force then
		return
	end
	local crouch: boolean
	if force then
		crouch = under ~= nil
		way = out
		off = 0
	elseif under then
		-- on the strip: running at the edge with open water just ahead (and further out than the dock's spawn)
		if speed < d.LeapMinSpeed then
			return
		end
		local ahead = position + way * d.LeapAhead
		if (ahead - dock.Position):Dot(out) <= 0 or groundUnder(ahead) ~= nil then
			return
		end
		crouch = true
	else
		-- over the edge already (walked off slowly, jumped): no crouch, out from here
		if position.Y < surfaceY() + 1 or (position - dock.Position):Dot(out) <= 0 then
			return
		end
		crouch = false
	end
	-- the way out: the way we ran, within LeapCone of straight out
	local cone = math.rad(math.clamp(d.LeapCone, 0, 89))
	local heading = way
	if off > math.deg(cone) then
		local turn = if out:Cross(way).Y > 0 then cone else -cone
		heading = (CFrame.fromAxisAngle(UP, turn) * out).Unit
	end
	local fish: Fish? = nil
	if landMounted then
		fish = fishOf(State.Player, root)
		if not fish then
			return -- (its model not here yet)
		end
	end
	local ground = under or (position.Y - (if fish then fish.depth else 3))
	local p = makePlan(
		position,
		ground,
		heading,
		yawOf(root.CFrame.LookVector),
		speed,
		crouch,
		camera.CFrame,
		camera.FieldOfView,
		fish
	)
	if not p then
		armed = false -- (in the way of something: an ordinary drop, and no second try on the way down)
		return
	end
	begin(p, character, nil, nil)
end

-- The water's moment: the splash where we went in, its bubbles, the existing splash sound, shake and wider view (the
-- dive's hop then makes none of its own: State.LeapSplashed)
local function enterWater(p: Plan)
	local d = Config.Dive
	local at = Vector3.new(p.entry.X, p.surface, p.entry.Z)
	-- (on the ride fish: as big as the fish, never past the whole splash)
	splashId = Splash.play(at, p.heading, math.min(powerOf(p.entryVelocity.Magnitude) * p.scale, 1), 7)
	ownSplashAt = os.clock()
	if heldAt then
		return
	end
	event("entry", {
		pos = p.entry,
		speed = p.entryVelocity.Magnitude,
		angle = -pathAngle(p, 1),
	})
	if d.Splash > 0 then
		local more = math.min(p.scale, 1.5)
		Fx.burstKept(at - UP, math.ceil(d.Splash * more), d.SplashReach * more)
		Fx.burstKept(p.entry + p.line * 3, math.ceil(d.Splash / 2 * more), d.SplashReach / 2 * more)
	end
	if d.SplashSound > 0 then
		Feel.sound("Splash", d.SplashSound, 0.95, 2)
	end
	if d.Shake > 0 then
		Shake.play("Land", d.Shake)
	end
	State.FovPunch = math.max(State.FovPunch, d.Fov)
	State.LeapSplashed = true
end

----------------------------------------------------------------------------------------------------------------------
-- The body's step: just after the hop's (it may take the hop's turn), before the riding step

local function bodyFrame(dt: number)
	local d = Config.Dive
	-- (the dive's hop reads the water's moment within a second; one it never read is not left for the next drop-in)
	if State.LeapSplashed and os.clock() - ownSplashAt > 2 then
		State.LeapSplashed = false
	end
	if d.Leap > 0 and not warmed then
		-- the splash's parts and the bubbles' emitters made ahead, a few a frame, once the leap is on: no dive makes
		-- or puts away an Instance (the first dive made them all at once)
		warmed = Splash.prewarm(24)
		if warmed then
			Fx.prewarmBursts()
		end
	end
	local p = plan
	if not p then
		if d.Leap > 0 then
			watch(dt)
			tryStart(false)
		elseif next(lastY) then
			table.clear(lastY)
		end
		Splash.step()
		return
	end
	if d.Leap > 0 then
		watch(dt)
	end
	Splash.step()
	local now = os.clock()
	local t = heldAt or (now - startedAt)
	local character, root, humanoid = State.character()
	if character ~= leapCharacter or not root or not humanoid or humanoid.Health <= 0 then
		releaseAll("gone")
		return
	end
	local mode = State.Mode
	if mode == "Free" and not freeAt then
		freeAt = now
	end
	if not heldAt then
		if mode == "Carried" or mode == "Drowning" or mode == "Failing" then
			releaseAll(mode)
			return
		end
		local written = lastWritten
		if body and not carryFrom and written and (root.Position - written).Magnitude > 20 then
			-- put somewhere else (back on the dock, a respawn): the dive is over
			releaseAll("moved")
			return
		end
	end
	-- the water's moment, and the top
	if t >= p.tEntry and not entered then
		entered = true
		enterWater(p)
	end
	if heldAt then
		local id = splashId
		if t >= p.tEntry and id then
			Splash.hold(id, t - p.tEntry)
		elseif t < p.tEntry and id then
			Splash.release(id)
			splashId = nil
			entered = false
		end
	end
	if not topped and t >= p.tTop then
		topped = true
		event("top", { height = root.Position.Y - p.start.Y, pos = root.Position })
	end
	if body then
		if not heldAt and (mode == "Riding" or welded(root)) then
			-- on our own fish (the server seats the equipped fish as we go under): it has us now
			releaseBody("riding")
		elseif not heldAt and mode == "Jumping" then
			-- the dive's hop has begun: it moves us now, and our body turns from the dive's angle to its own
			if not carryFrom then
				carryFrom = lastRotation
				carryAt = now
				event("hop", { depth = surfaceY() - root.Position.Y, pos = root.Position })
			end
			local w = smooth(0, math.max(d.LeapBlend, 0.01), now - carryAt)
			local hop = root.CFrame
			root.CFrame = CFrame.new(hop.Position) * (carryFrom :: CFrame):Lerp(hop.Rotation, w)
			lastWritten = hop.Position
			if w >= 1 then
				releaseBody("hop")
			end
		elseif
			not heldAt
			and mode == "Free"
			and (Config.Dive.AutoHop <= 0 or now - (freeAt :: number) > math.max(d.HopDelay, 0) + 0.5)
		then
			-- no hop coming (it is off, or it could not begin): floating, as before
			releaseBody("no hop")
		elseif not heldAt and mode == "Dock" and t > p.tEntry + math.max(d.LeapHold, 0.1) then
			-- under the water and the server never said so: let go
			releaseBody("timeout")
		elseif
			not heldAt
			and p.mounted
			and State.Player:GetAttribute("LandMounted") ~= true
			and root.Position.Y > Config.Oxygen.WaterY
		then
			-- (on the ride fish, and it went before the water: the server took it, or it was lost. Not its swap for
			-- the water fish under the water, which the server makes once we are under WaterY). The whole leap ends,
			-- as the other early exits: the camera handed back at once, the splashes left to finish
			releaseAll("fish lost")
			return
		elseif not heldAt and (carryFrom or (mode ~= "Dock" and mode ~= "Free")) then
			-- (and once the hop had begun, its end before the turn was, at once or sent home, lets go too: never back
			-- to the dive's own path)
			releaseBody(mode)
		else
			local frame = frameAt(p, t)
			root.CFrame = frame
			root.AssemblyLinearVelocity = if heldAt then Vector3.zero else velocityAt(p, t)
			root.AssemblyAngularVelocity = Vector3.zero
			if not humanoid.PlatformStand then
				humanoid.PlatformStand = true
			end
			lastWritten = frame.Position
			lastRotation = frame.Rotation
		end
	end
	if posing then
		if body or heldAt then
			ownPhase, ownTuck = phaseAt(p, t), tuckAt(p, t)
		elseif popHold then
			-- held in the dive's last pose until the hop's push is over (no crouch flashing in between)
			ownPhase, ownTuck = 3, 0
			if State.Mode ~= "Jumping" or State.JumpPhase ~= "Pop" or State.Reeling then
				posing, popHold = false, false
			end
		elseif seatHoldAt then
			-- (on the ride fish: seated, tucked, until our mode says Riding and the ride's own pose has us; a second
			-- at most)
			ownPhase, ownTuck = 3, 0
			if State.Mode == "Riding" or now - seatHoldAt > 1 then
				posing, seatHoldAt = false, nil
			end
		else
			posing = false
		end
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The camera's step: after the riding camera (it may hand over to its view), before the submarine's

-- The film's own view at dive time t: on the curve through the keys, then chasing; looking at where the diver will
-- be a moment ahead; banked a little through the top; wider at the top
local function filmAt(p: Plan, t: number, diver: Vector3, planned: Vector3): (CFrame, number)
	local d = Config.Dive
	local at: Vector3
	if t >= p.tFollow then
		at = chaseAt(p, diver)
	else
		-- (the diver let go early, onto a fish: the last stretch bends to follow where they really are)
		local drift = chaseAt(p, diver) - chaseAt(p, planned)
		at = curveAt(p, t) + drift * smooth(p.keys[4].t, p.tFollow, t)
	end
	-- (the look ahead is held to LeapCamLeadMost studs: at 72 studs a second into the water it was 9 studs ahead, and
	-- put the diver at the top edge of the view)
	local lead = velocityAt(p, math.min(t, p.tEntry + p.sink)) * d.LeapCamLead
	local most = math.max(d.LeapCamLeadMost, 0)
	if lead.Magnitude > most then
		lead = if most > 0 then lead.Unit * most else Vector3.zero
	end
	local centre = diver + UP * p.centreUp
	local toward = centre + lead - at
	local look = if toward.Magnitude > 0.05 then toward.Unit else p.camFrom.LookVector
	if t < 0.25 then
		look = p.camFrom.LookVector:Lerp(look, smooth(0, 0.25, t))
		look = if look.Magnitude > 0.01 then look.Unit else p.camFrom.LookVector
	end
	local peak = Config.Camera.Fov + d.LeapCamWide
	local fov = if t < p.tTop
		then lerp(p.camFov, peak, smooth(0, p.tTop, t))
		else lerp(peak, Config.Camera.Fov, smooth(p.tTop, p.tFollow, t))
	fov += State.FovPunch + State.FovLong
	-- the diver kept within the middle LeapCamKeep of the view (by height): turned toward them as far as that needs
	local toDiver = centre - at
	local keep = math.clamp(d.LeapCamKeep, 0.05, 1)
	if toDiver.Magnitude > 0.5 and keep < 1 then
		local limit = math.atan(math.tan(math.rad(fov) / 2) * keep)
		local aim = toDiver.Unit
		local off = math.acos(math.clamp(look:Dot(aim), -1, 1))
		if off > limit then
			-- (a turn about the axis between the two, by the part of the angle over the limit)
			local axis = look:Cross(aim)
			if axis.Magnitude > 1e-4 then
				look = CFrame.fromAxisAngle(axis.Unit, off - limit) * look
			end
		end
	end
	if math.abs(look.Y) > 0.995 then
		look = (look + p.heading * 0.1).Unit
	end
	local k1, k3 = p.keys[2].t, p.keys[4].t
	local bank = math.rad(d.LeapCamBank) * p.side * math.sin(math.pi * math.clamp((t - k1) / (k3 - k1), 0, 1))
	local view = CFrame.lookAt(at, at + look) * CFrame.Angles(0, 0, bank)
	return view, fov
end

local function cameraFrame(dt: number)
	local p = plan
	if not p then
		return
	end
	local now = os.clock()
	local t = heldAt or (now - startedAt)
	local _, root = State.character()
	if filming and root then
		-- the riding camera's view this frame (it has the camera in the water, and has just put its view there)
		local live: CFrame? = nil
		local liveFov = 0
		if not heldAt and State.inWater() and camera.CameraType == Enum.CameraType.Scriptable then
			live, liveFov = camera.CFrame, camera.FieldOfView
		end
		if State.DeathCam or State.Mode == "Carried" then
			releaseCamera("taken")
		else
			-- where the diver is: the root itself, whoever moves it (the dive, the hop as it carries on, the riding
			-- step). Filming the plan's point instead held the camera still while the hop moved the body on, and then cut
			-- 30 studs to the root as the hop let go (2026-11-23, the tester: 6 of 8 dives). A cut in the root itself
			-- (put on the fish's saddle) is eased across, never followed at once.
			local planned = posAt(p, t)
			local diver = planned
			if not heldAt then
				local here = root.Position
				local was = diverLast
				if p.mounted then
					-- (on the ride fish the swap onto the water fish is a few studs: a cut is a jump past where the
					-- body was going this frame, by more than 2.5 studs. A diver's test below is plain 6 studs)
					local going = if was then was + root.AssemblyLinearVelocity * dt else here
					if was and (here - going).Magnitude > 2.5 then
						diverOffset += going - here
						event("cut", { studs = (here - going).Magnitude })
					end
				elseif was and (here - was).Magnitude > 6 then
					diverOffset += was - here
				end
				diverLast = here
				diverOffset *= 1 - Ease.alpha(8, dt)
				diver = here + diverOffset
			end
			local view, fov = filmAt(p, t, diver, planned)
			-- the player took the view on the dock: it follows us round, turned by them, from where the film was
			if orbit then
				orbitYaw += turnBy.X
				orbitPitch = math.clamp(orbitPitch + turnBy.Y, math.rad(-75), math.rad(60))
				orbitDistance = lerp(orbitDistance, Config.Camera.Distance, Ease.alpha(4, dt))
				local focus = root.Position + UP * (Config.Camera.Height * Config.Camera.FocusHeight)
				local turn = CFrame.fromOrientation(orbitPitch, orbitYaw, 0)
				local follow = CFrame.lookAt(focus - turn.LookVector * orbitDistance, focus)
				view = (orbitFrom :: CFrame):Lerp(follow, smooth(0, handTime, now - orbitAt))
				fov = lerp(fov, Config.Camera.Fov, smooth(0, handTime, now - orbitAt))
			end
			turnBy = Vector2.zero
			-- out of the floor and walls: in at once, easing back out
			local anchor = diver + UP * p.centreUp
			local arm = view.Position - anchor
			local hit = if arm.Magnitude > 0.1 then workspace:Raycast(anchor, arm, cameraParams) else nil
			local free = if hit
				then math.max(0, (hit.Position - anchor).Magnitude - Config.Camera.WallGap) / arm.Magnitude
				else 1
			if heldAt or free < reach then
				reach = free
			else
				reach = lerp(reach, free, Ease.alpha(6, dt))
			end
			if reach < 0.999 then
				view = CFrame.new(anchor + arm * reach) * view.Rotation
			end
			-- the shakes (on the dock they are ours to play; in the water the riding camera's view has them already,
			-- and theirs is the clock: nothing is run on twice)
			view *= Shake.update(if State.inWater() then 0 else dt)
			-- the hand-over: once under the water and the riding camera's view is under its line too (or the player
			-- took the view, or there will be no hop to wait for). (When that is varies by about 0.6 s: the riding
			-- camera takes up our view as the server says Free, and its own height then lands within a stud of its
			-- line, under it at once or ridden down by its ceiling over Camera.SurfaceTime. Following the root, the
			-- film no longer shows the wait.)
			if live and not handAt and not heldAt then
				local ready = took
					or (
						t >= p.tFollow
						and (
							live.Position.Y <= RideController.waterLine() + 0.05
							or (not body and now - bodyGoneAt > 0.6)
							or t > p.tEntry + p.sink + 1.5
						)
					)
				if ready then
					handAt = now
					event("handover", { live = live.Position.Y })
				end
			end
			local handed = false
			blendSeen = 0
			if handAt and live then
				local w = smooth(0, if took then handTime * 0.6 else handTime, now - handAt)
				view = view:Lerp(live, w)
				fov = lerp(fov, liveFov, w)
				handed = w >= 1
				blendSeen = w
			end
			liveSeen = if live then live.Position else nil
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = view
			camera.FieldOfView = fov
			-- through the surface: a few bubbles by the lens
			local y = view.Position.Y
			if camY > p.surface and y <= p.surface and not heldAt then
				Fx.burstKept(view.Position + view.LookVector * 1.5, 14, 2.5)
			end
			camY = y
			if handed then
				releaseCamera("handed")
			elseif not heldAt and t > p.tEntry + math.max(Config.Dive.LeapHold, 0.1) + 3 and not State.inWater() then
				releaseCamera("timeout")
			end
		end
	end
	-- the log (test hook)
	if root and t ~= lastFrameT and #frames < 900 then
		lastFrameT = t
		local cf = root.CFrame
		table.insert(frames, {
			t = t,
			pos = root.Position,
			tilt = math.deg(math.atan2(-cf.LookVector.Y, cf.UpVector.Y)),
			state = State.Mode,
			cam = camera.CFrame.Position,
			fov = camera.FieldOfView,
			body = body,
			live = if filming then liveSeen else nil,
			blend = if filming then blendSeen else 1,
		})
	end
	-- over: the body, the pose and the camera all let go
	if not body and not filming and not posing and not heldAt then
		plan = nil
		carryFrom = nil
	end
end

-- Each step, guarded: an error lets everything go cleanly and turns the leap off until the next join
local function guarded(what: string, f: (number) -> (), dt: number)
	if broken then
		return
	end
	local ok, problem = pcall(f, dt)
	if not ok then
		broken = true
		warn(`[DiveController] {what} failed, the leap is off until you rejoin: {problem}`)
		pcall(releaseAll, "error")
	end
end

-- The camera's rays leave out every character, the camera and the lane's props, as the riding camera's do (looked
-- up again now and then while a film runs)
local cameraFilteredAt = -math.huge
local function cameraRays()
	local now = os.clock()
	if now - cameraFilteredAt < 1 then
		return
	end
	cameraFilteredAt = now
	local skip: { Instance } = { camera }
	for _, player in everyone do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	local map = workspace:FindFirstChild("ClaudeBlockout")
	local lane = map and map:FindFirstChild("Lane")
	local props = lane and lane:FindFirstChild("Props")
	if props then
		table.insert(skip, props)
	end
	cameraParams.FilterDescendantsInstances = skip
end

local function cameraStep(dt: number)
	if filming then
		cameraRays()
		-- the stick counts as looking too (400 a second, pushed right over)
		if stick.Magnitude > 0 then
			lookMoved += 400 * stick.Magnitude * dt
			turnBy += Vector2.new(-stick.X, stick.Y) * (Config.Camera.StickSensitivity * dt)
			local now = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
			for _, input in now do
				-- (its letting go can come while nothing here listens)
				if input.KeyCode == Enum.KeyCode.Thumbstick2 and input.Position.Magnitude < 0.2 then
					stick = Vector2.zero
				end
			end
		end
		if not took and not heldAt and lookMoved >= Config.Dive.LeapLookOff then
			-- the player looks round: the view is theirs. In the water the riding camera has it at once (eased); on the
			-- dock the film turns into a camera following us round, turned by them, until the water
			took = true
			event("took", {})
			if State.inWater() then
				handAt = os.clock()
			else
				orbit = true
				orbitFrom = camera.CFrame
				orbitAt = os.clock()
				local look = camera.CFrame.LookVector
				orbitYaw, orbitPitch = yawOf(look), math.asin(math.clamp(look.Y, -1, 1))
				local _, root = State.character()
				orbitDistance = if root then (camera.CFrame.Position - root.Position).Magnitude else 12
			end
		end
	end
	cameraFrame(dt)
end

----------------------------------------------------------------------------------------------------------------------
-- Hooks for other controllers

local function poseNow(player: Player): (number?, number, boolean)
	if player == State.Player then
		local p = plan
		if posing and p then
			return ownPhase, ownTuck, p.mounted
		end
		return nil, 0, false
	end
	if Config.Dive.Leap <= 0 or broken then
		return nil, 0, false
	end
	local now = os.clock()
	local cached = seen[player]
	if cached and now - cached.at < 0.004 then
		return cached.phase, cached.tuck, cached.mounted
	end
	local phase, tuck, mounted = otherPhase(player)
	local leapAt = if phase and mounted then now elseif cached then cached.leapAt else -math.huge
	seen[player] = { at = now, phase = phase, tuck = tuck, mounted = mounted, leapAt = leapAt }
	return phase, tuck, mounted
end

-- The dive's pose for that player now (AnimController, through State.LeapPose): its phase (0 to 1 the crouch, 1 to 2
-- the air, 2 to 3 under the water), the somersault's tuck (0 to 1), and whether it is the leap on the ride fish (the
-- rider seated on it: Config.Dive.LeapMounted); nil when they are not leaping. Guarded as the steps are: an error turns
-- the leap off, and every pose goes on as it was
function DiveController.poseOf(player: Player): (number?, number, boolean)
	if broken then
		return nil, 0, false
	end
	local ok, phase, tuck, mounted = pcall(poseNow, player)
	if not ok then
		broken = true
		warn(`[DiveController] the pose failed, the leap is off until you rejoin: {phase}`)
		pcall(releaseAll, "error")
		return nil, 0, false
	end
	return phase, tuck, mounted
end

----------------------------------------------------------------------------------------------------------------------
-- Test hooks

-- Where a dive from the lip begins, the same every time: walked out from the dock's spawn along its look until there
-- is open water under us, and back from that edge a little; at a standing root's height
local function lipStart(): (Vector3?, number, Vector3)
	local dock = dockFrame()
	local _, root, humanoid = State.character()
	if not dock then
		return nil, 0, Vector3.zero
	end
	local out = (dock.LookVector * FLAT).Unit
	local height = 3
	if humanoid and root and humanoid.RigType == Enum.HumanoidRigType.R15 then
		height = humanoid.HipHeight + root.Size.Y / 2
	elseif humanoid and root and State.Player:GetAttribute("LandMounted") == true then
		-- (an R6 rider on the ride fish: its hip height is raised by the fish's depth, over the legs)
		height = humanoid.HipHeight + root.Size.Y / 2 + 2
	end
	local from = dock.Position + UP * 4
	local floor: number? = nil
	for step = 0, 400 do
		local at = from + out * step
		local top = groundUnder(at)
		if not top then
			if not floor then
				return nil, 0, out
			end
			local lip = from + out * math.max(step - 3, 0)
			return Vector3.new(lip.X, floor + height, lip.Z), floor, out
		end
		floor = top
	end
	return nil, 0, out
end

-- Test hook: only the Studio checks call this (tools/studio/dive_leap_check.py). Begins a dive from where the
-- character stands, straight out from the dock (as if run at the water). True if it began.
function DiveController.start(): boolean
	if plan then
		releaseAll("restart")
	end
	broken, splashBroken = false, false
	armed = true
	tryStart(true)
	return plan ~= nil
end

-- Test hook: only the Studio checks call this (tools/studio/dive_leap_check.py). Holds the whole dive at dive time
-- `t` (the arc, the tilt, the pose, the camera and the splash as they are then), begun at the lip, the same every
-- time; `leaveCamera` leaves the camera alone (for a director's camera). Again with another t to move it; nil to let
-- go. True if it is held. On the ride fish on land, the fish's own dive (Config.Dive.LeapMounted); held under WaterY
-- the server takes the land fish away, as it would for a real dive.
function DiveController.hold(t: number?, leaveCamera: boolean?): boolean
	if t == nil then
		if plan then
			releaseAll("held off")
		end
		return false
	end
	if plan and heldAt then
		heldAt = t
		if leaveCamera and filming then
			releaseCamera("held off")
		end
		return true
	end
	if plan then
		releaseAll("restart")
	end
	broken, splashBroken = false, false
	local character, root = State.character()
	local start, floor, out = lipStart()
	if not character or not root or not start then
		return false
	end
	local fish: Fish? = nil
	if State.Player:GetAttribute("LandMounted") == true and Config.Dive.LeapMounted > 0 then
		fish = fishOf(State.Player, root)
		if not fish then
			return false
		end
	end
	local behind = start - out * Config.Camera.Distance + UP * Config.Camera.Height
	local p = makePlan(start, floor, out, yawOf(out), 16, true, CFrame.lookAt(behind, start), Config.Camera.Fov, fish)
	if not p then
		return false
	end
	-- (the same side every time)
	if p.side ~= 1 then
		p.side = 1
		p.keys = cameraKeys(p)
	end
	begin(p, character, t, leaveCamera)
	return true
end

-- Test hook: only the Studio checks call this (tools/studio/dive_leap_check.py). The last dive's log: a frame each
-- render frame (dive time, root, tilt, our mode, camera, view width, whether the dive moved the body, the riding
-- camera's view that frame as the film read it and how far the hand-over had gone, 1 once the film is not the view)
-- and its moments (start, top, entry, hop, release, handover, camera, took), with the plan's numbers and the splashes'.
function DiveController.log(): { [string]: any }
	local p = plan
	return {
		frames = frames,
		events = events,
		active = p ~= nil,
		held = heldAt,
		body = body,
		filming = filming,
		broken = broken,
		splash = Splash.stats(),
		plan = if p
			then {
				start = p.start,
				takeoff = p.takeoff,
				entry = p.entry,
				tEntry = p.tEntry,
				tTop = p.tTop,
				tFollow = p.tFollow,
				side = p.side,
				speed = p.entryVelocity.Magnitude,
				angle = -pathAngle(p, 1),
				sinkLength = p.sinkLength,
				mounted = p.mounted,
				scale = p.scale,
				camScale = p.camScale,
				high = p.a * p.a / (4 * p.c),
				far = p.far,
				air = p.air,
				entryTilt = p.entryTilt,
			}
			else nil,
	}
end

-- Test hook: only the checks call this (tools/dive/fish_dive_check.luau, offline in Lune). The plan a dive from
-- `start` would get, without beginning it: nil and why not, or the plan, why each arc before it was passed over, and
-- the dive's own sums at any dive time (`frameAt`: the root; `viewAt`: the film's view and its width, with the body
-- on the plan's path). `box`: the ride fish's box in the root's own space, its low and high corners (nil: a diver)
function DiveController.planOf(
	start: Vector3,
	ground: number,
	heading: Vector3,
	speed: number,
	crouch: boolean,
	camFrom: CFrame,
	camFov: number,
	box: { low: Vector3, high: Vector3 }?
): ({ [string]: any }?, { string }, { [string]: any }?)
	local fish = if box then fishFrom(box.low, box.high) else nil
	local p = makePlan(start, ground, heading, yawOf(heading), speed, crouch, camFrom, camFov, fish)
	local why = table.clone(whyNot)
	if not p then
		return nil, why, nil
	end
	local made: Plan = p
	return made :: any,
		why,
		{
			fish = fish,
			frameAt = function(t: number): CFrame
				return frameAt(made, t)
			end,
			tiltAt = function(t: number): number
				return tiltAt(made, t)
			end,
			viewAt = function(t: number): (CFrame, number)
				local at = posAt(made, t)
				if t >= made.tFollow then
					return filmAt(made, t, at, at)
				end
				return filmAt(made, t, at, at)
			end,
		}
end

-- Test hook: only the Studio checks call this (tools/studio/dive_leap_check.py). Empties the last dive's log (not a
-- running dive's), so a run without a dive does not report the one before.
function DiveController.clearLog()
	if not plan then
		table.clear(frames)
		table.clear(events)
		lastFrameT = -1
	end
end

-- Test hook: only the Studio checks call this (tools/studio/dive_leap_check.py). As if the player moved the mouse
-- (looking round) by `moved` pixels while the film runs: what InputChanged adds up.
function DiveController.pretendLook(moved: Vector2)
	if not filming or heldAt then
		return
	end
	lookMoved += moved.Magnitude
	turnBy += Vector2.new(-moved.X, -moved.Y) * Config.Camera.MouseSensitivity
end

----------------------------------------------------------------------------------------------------------------------
-- Setup

function DiveController.Init()
	everyone = Players:GetPlayers()
	State.LeapPose = DiveController.poseOf
end

function DiveController.Start()
	Players.PlayerAdded:Connect(function()
		everyone = Players:GetPlayers()
	end)
	Players.PlayerRemoving:Connect(function(player)
		seen[player] = nil
		task.defer(function()
			everyone = Players:GetPlayers()
		end)
	end)
	State.Player.CharacterAdded:Connect(function()
		if plan then
			releaseAll("respawn")
		end
		armed = true
	end)
	-- the player looking round while the film runs: once it adds up to LeapLookOff, the view is theirs
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if not filming or heldAt then
			return
		end
		local c = Config.Camera
		local moved = Vector2.zero
		local sensitivity = c.MouseSensitivity
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local looking = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
				or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
				or (State.Mode == "Jumping" and c.AirMouseLook > 0)
			if looking then
				moved = Vector2.new(input.Delta.X, input.Delta.Y)
			end
		elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
			moved = Vector2.new(input.Delta.X, input.Delta.Y)
			sensitivity = c.TouchSensitivity
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local v = Vector2.new(input.Position.X, input.Position.Y)
			stick = if v.Magnitude > 0.2 then v else Vector2.zero
		end
		if moved.Magnitude > 0 then
			lookMoved += moved.Magnitude
			turnBy += Vector2.new(-moved.X, -moved.Y) * sensitivity
		end
	end)
	RunService:BindToRenderStep("DiveBody", Enum.RenderPriority.Camera.Value - 4, function(dt: number)
		if broken then
			-- (the leap is off, but the splashes on screen as it broke still play out and go)
			if not splashBroken then
				local ok, problem = pcall(Splash.step)
				if not ok then
					splashBroken = true
					warn(`[DiveController] the splashes' step failed: {problem}`)
				end
			end
		else
			guarded("the body's step", bodyFrame, dt)
		end
	end)
	RunService:BindToRenderStep("DiveCamera", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		if plan then
			guarded("the camera's step", cameraStep, dt)
		end
	end)
end

return DiveController
