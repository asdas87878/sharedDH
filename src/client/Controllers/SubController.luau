--!strict
-- The submarine on every machine (docs/design/submarine.md). The server writes a trip on the player it carries
-- ("SubTrip", Shared/SubTrip) and its phase ("SubPhase"); each machine builds its own placeholder sub for each trip and
-- moves it by the clock, so it costs no traffic. For our own trip we also move ourselves (the server has us "Carried":
-- our machine owns the character) and the camera:
--   Approach: we swim on just under the surface while the sub comes up from behind and below, its light on us. The
--     camera sits ahead and to the side, looking back at us and at it coming.
--   Pickup: it rises under us; we are scooped up in a tumble and set on the seat behind its tower. A splash, a bump.
--   Ride: it noses down and runs the herd's line at up to Sub.Speed. The camera is behind it, wider with speed, with
--     speed lines and a rumble. A banner names the land.
--   Arrive: "NOW ARRIVING", at the drop speed; the camera swings out to the side.
--   Drop: on the server's word, flung forward into an ordinary hop (JumpController.fling), or, with our fish swum up
--     beside the sub ("SubFish", driven here), kicked off in an arc onto its saddle; we tell the server ("SubLand").
--   Then the sub peels away, up and to the side, and fades.
-- Placeholders only: the sub is plain parts (buildSub) and the motion is by code (the *Pose functions); the partner's
-- model and animations replace them (the note's "Animation hooks").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local SubTrip = require(ReplicatedStorage.Shared.SubTrip)
local Feel = require(script.Parent.Parent.Lib.Feel)
local Fx = require(script.Parent.Parent.Lib.Fx)
local Shake = require(script.Parent.Parent.Lib.Shake)
local State = require(script.Parent.Parent.Lib.State)
local SubPanel = require(script.Parent.Parent.UI.SubPanel)
local JumpController = require(script.Parent.JumpController)

local SubController = {}

-- The rider's seat against the sub's middle, and how far its middle sits under the seat
local SEAT = CFrame.new(0, 7.4, 5)
local UP = Vector3.yAxis
local HULL = Color3.fromRGB(255, 196, 38)
local TRIM = Color3.fromRGB(40, 54, 78)

type Visual = {
	Player: Player,
	Trip: SubTrip.Trip,
	Model: Model,
	Parts: { BasePart },
	Prop: BasePart,
	Bubbles: ParticleEmitter,
	Spin: number,
	Last: CFrame?,
	Faded: boolean,
	-- our own trip only
	Entry: CFrame?, -- where we were as it began
	Cue: string?, -- the server's word at the drop: "Fling" or "Kick"
	CuedAt: number,
	Fish: Model?, -- our fish, beside the sub
	FishFrom: Vector3?,
	FishGot: number,
	Told: boolean, -- "SubLand" sent
	Said: { [string]: boolean }, -- the moments already played (sounds, bursts, banners)
	RiderLast: Vector3?,
}

local visuals: { [Player]: Visual } = {}
local mine: Visual? = nil
local camPos: Vector3? = nil
local camFocus: Vector3? = nil
local camKind = "" -- what the camera's offsets are from: "rider" or "sub"
local camParams: RaycastParams? = nil
local camAnchor = Vector3.zero -- and where that was last frame (zero: the offsets are places in the world)
local fov = 70
local gui: ScreenGui

local function now(): number
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

local function yawOf(look: Vector3): number
	return math.atan2(-look.X, -look.Z)
end

local function landName(index: number): string
	local zone = State.Zones[index]
	return if zone then string.upper(zone.Name) else ("LAND " .. index)
end

-- The placeholder sub: a yellow hull, a tower with a window, fins, a propeller, a light at the nose, the seat. It faces
-- -Z. Every part is anchored and touches nothing; the whole model is moved by PivotTo.
local function buildSub(): (Model, { BasePart }, BasePart, ParticleEmitter)
	local model = Instance.new("Model")
	model.Name = "Submarine"
	local parts: { BasePart } = {}
	local function part(
		name: string,
		shape: Enum.PartType,
		size: Vector3,
		at: CFrame,
		colour: Color3,
		material: Enum.Material?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.CFrame = at
		p.Color = colour
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		table.insert(parts, p)
		return p
	end
	local along = CFrame.Angles(0, math.rad(90), 0) -- a cylinder's axis is its X: turned to lie along Z
	local hull = part("Hull", Enum.PartType.Cylinder, Vector3.new(26, 10, 10), along, HULL)
	model.PrimaryPart = hull
	part("Nose", Enum.PartType.Ball, Vector3.new(10, 10, 10), CFrame.new(0, 0, -13), HULL)
	part("Tail", Enum.PartType.Ball, Vector3.new(8, 8, 8), CFrame.new(0, 0, 13), HULL)
	part("Tower", Enum.PartType.Block, Vector3.new(5, 6, 9), CFrame.new(0, 6.5, -2), HULL)
	part("TowerCap", Enum.PartType.Block, Vector3.new(5.6, 1, 9.6), CFrame.new(0, 9.8, -2), TRIM)
	part(
		"Window",
		Enum.PartType.Block,
		Vector3.new(4, 2, 0.4),
		CFrame.new(0, 7.4, -6.6),
		Color3.fromRGB(120, 220, 255),
		Enum.Material.Neon
	)
	part("Seat", Enum.PartType.Block, Vector3.new(3.4, 1, 3.4), CFrame.new(0, 5.2, 5), TRIM)
	part("Bar", Enum.PartType.Block, Vector3.new(4.4, 0.6, 0.6), CFrame.new(0, 6.8, 2.6), TRIM)
	for _, side in { -1, 1 } do
		part(
			"Port",
			Enum.PartType.Cylinder,
			Vector3.new(0.6, 2.6, 2.6),
			CFrame.new(side * 5, 0.5, -6),
			Color3.fromRGB(120, 220, 255),
			Enum.Material.Neon
		)
		part(
			"Port",
			Enum.PartType.Cylinder,
			Vector3.new(0.6, 2.6, 2.6),
			CFrame.new(side * 5, 0.5, 0),
			Color3.fromRGB(120, 220, 255),
			Enum.Material.Neon
		)
		part("Wing", Enum.PartType.Block, Vector3.new(6, 0.8, 3.4), CFrame.new(side * 7, -1, -7), TRIM)
	end
	part("FinFlat", Enum.PartType.Block, Vector3.new(14, 0.8, 3.4), CFrame.new(0, 0, 14), TRIM)
	part("FinTall", Enum.PartType.Block, Vector3.new(0.8, 9, 3.4), CFrame.new(0, 0, 14), TRIM)
	part("PropHub", Enum.PartType.Ball, Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, 0, 17), TRIM)
	local prop = part("Prop", Enum.PartType.Block, Vector3.new(0.6, 7, 1.4), CFrame.new(0, 0, 17.6), TRIM)
	local lamp = part(
		"Light",
		Enum.PartType.Ball,
		Vector3.new(3, 3, 3),
		CFrame.new(0, -1.5, -17.4),
		Color3.fromRGB(255, 250, 210),
		Enum.Material.Neon
	)
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Range = 60
	beam.Angle = 50
	beam.Brightness = 4
	beam.Color = Color3.fromRGB(255, 244, 200)
	beam.Parent = lamp
	local glow = Instance.new("PointLight")
	glow.Range = 22
	glow.Brightness = 1.5
	glow.Color = Color3.fromRGB(255, 220, 140)
	glow.Parent = hull
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Wake"
	bubbles.Color = ColorSequence.new(Color3.new(1, 1, 1))
	bubbles.LightEmission = 0.4
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.4) })
	bubbles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	bubbles.Lifetime = NumberRange.new(0.8, 1.6)
	bubbles.Speed = NumberRange.new(4, 10)
	bubbles.SpreadAngle = Vector2.new(35, 35)
	bubbles.Acceleration = Vector3.new(0, 6, 0)
	bubbles.Rate = 0
	bubbles.EmissionDirection = Enum.NormalId.Back
	bubbles.Parent = prop
	model.WorldPivot = CFrame.identity
	return model, parts, prop, bubbles
end

-- The sub's place at `t` seconds into the trip, and how fast it goes (studs a second)
local function subAt(trip: SubTrip.Trip, t: number): (CFrame, number)
	local pickupAt, rideAt, _, dropAt, endAt = SubTrip.times(trip)
	local pick = trip.Points[1]
	local way0 = flat(SubTrip.way(trip, 30, 30))
	local right = way0:Cross(UP)
	local rest = pick - UP * 8
	if t < pickupAt then
		-- (approachPose) up from behind, below and to the side, slowing as it comes under us
		local u = math.clamp(t / math.max(pickupAt, 0.01), 0, 1)
		local e = 1 - (1 - u) ^ 2
		-- (kept over the floor at the gate: the water there is about 46 deep, and we take the sub 17 under)
		local p0 = pick - way0 * 170 - UP * 18 + right * 30
		local p1 = pick - way0 * 50 - UP * 16 + right * 6
		local a, b = p0:Lerp(p1, e), p1:Lerp(rest, e)
		local at = a:Lerp(b, e)
		local dir = b - a
		dir = if dir.Magnitude > 0.1 then dir.Unit else way0
		return CFrame.lookAt(at, at + dir), 40 * (1 - e) + 10
	elseif t < rideAt then
		-- (pickupPose) rising under us to bring its seat to us, then dipping its nose to go
		local u = (t - pickupAt) / math.max(rideAt - pickupAt, 0.01)
		local at = rest:Lerp(pick, Ease.smoothstep(0, 0.55, u))
		local dip = math.rad(-12) * Ease.smoothstep(0.75, 1, u)
		local bob = math.sin(u * math.pi) * math.rad(4)
		return CFrame.lookAt(at, at + way0) * CFrame.Angles(dip + bob, 0, 0), 4
	end
	-- (ridePose, dropPose) along the path
	local d, v = SubTrip.distance(trip, t)
	local at = SubTrip.at(trip, d)
	local way = SubTrip.way(trip, d, 10 + v * 0.04)
	-- banked into the bends, by how the way turns over the next half second
	local ahead = flat(SubTrip.way(trip, d + math.max(v * 0.5, 20), 10 + v * 0.04))
	local turn = flat(way):Cross(ahead).Y
	local cf = CFrame.lookAt(at, at + way) * CFrame.Angles(0, 0, math.clamp(-turn * 3, -0.7, 0.7))
	if t >= dropAt then
		local since = t - dropAt
		if not trip.Fish then
			-- the fling: the nose comes up and drops again
			cf *= CFrame.Angles(math.rad(26) * math.sin(math.clamp(since / 0.7, 0, 1) * math.pi), 0, 0)
		end
		if t >= endAt then
			-- (peeling away) up and to the side
			local k = t - endAt
			local side = flat(way):Cross(UP)
			cf = cf + side * (k * k * 14) + UP * (k * k * 10)
			cf *= CFrame.Angles(math.rad(12) * math.min(k, 1), 0, math.rad(-25) * math.min(k, 1))
		end
	end
	return cf, v
end

local function makeVisual(player: Player, trip: SubTrip.Trip): Visual
	local model, parts, prop, bubbles = buildSub()
	-- every part's place against the hull's own frame
	local hull = model.PrimaryPart :: BasePart
	local offsets: { [BasePart]: CFrame } = {}
	for _, p in parts do
		offsets[p] = hull.CFrame:ToObjectSpace(p.CFrame)
	end
	model:SetAttribute("For", player.UserId)
	model.Parent = workspace.CurrentCamera
	local v: Visual = {
		Player = player,
		Trip = trip,
		Model = model,
		Parts = parts,
		Prop = prop,
		Bubbles = bubbles,
		Spin = 0,
		Last = nil,
		Faded = false,
		Entry = nil,
		Cue = nil,
		CuedAt = 0,
		Fish = nil,
		FishFrom = nil,
		FishGot = 0,
		Told = false,
		Said = {},
		RiderLast = nil,
	}
	(v :: any).Offsets = offsets
	return v
end

local function place(v: Visual, cf: CFrame, speed: number, dt: number)
	local offsets = (v :: any).Offsets :: { [BasePart]: CFrame }
	v.Spin += dt * (4 + speed * 0.12)
	local spun = CFrame.Angles(0, 0, v.Spin)
	-- the hull's own turn (a cylinder lies along X)
	local hull = v.Model.PrimaryPart :: BasePart
	local hullFrame = cf * CFrame.Angles(0, math.rad(90), 0)
	for p, offset in offsets do
		if p == hull then
			p.CFrame = hullFrame
		elseif p == v.Prop then
			p.CFrame = hullFrame * offset * spun
		else
			p.CFrame = hullFrame * offset
		end
	end
	v.Bubbles.Rate = math.clamp(speed * 0.6, 8, 260)
	v.Last = cf
end

local function remove(player: Player)
	local v = visuals[player]
	if v then
		v.Model:Destroy()
		visuals[player] = nil
	end
	if v and v == mine then
		mine = nil
		Shake.rumble("Sub", "Speed", 0)
	end
end

-- A banner over the middle of the screen, for a moment
local function banner(top: string, big: string, colour: Color3, time: number)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.24)
	frame.Size = UDim2.fromOffset(560, 110)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local function line(text: string, y: number, h: number, c: Color3)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, y)
		label.Size = UDim2.new(1, 0, 0, h)
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = c
		label.Parent = frame
		local edge = Instance.new("UIStroke")
		edge.Thickness = 3
		edge.Color = Color3.fromRGB(16, 36, 63)
		edge.Parent = label
		return label
	end
	line(top, 0, 34, Color3.new(1, 1, 1))
	line(big, 36, 64, colour)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = frame
	local born = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local age = os.clock() - born
		if age > time or not frame.Parent then
			conn:Disconnect()
			frame:Destroy()
			return
		end
		-- a pop in with an overshoot, a fade out
		scale.Scale = if age < 0.25
			then Ease.lerp(0.4, 1.12, age / 0.25)
			elseif age < 0.4 then Ease.lerp(1.12, 1, (age - 0.25) / 0.15)
			else 1
		local fade = math.clamp((age - (time - 0.4)) / 0.4, 0, 1)
		for _, label in frame:GetChildren() do
			if label:IsA("TextLabel") then
				label.TextTransparency = fade
				local stroke = label:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Transparency = fade
				end
			end
		end
	end)
end

local function once(v: Visual, key: string): boolean
	if v.Said[key] then
		return false
	end
	v.Said[key] = true
	return true
end

-- Our fish beside the sub: from where it was made, up alongside on the right, matching the sub
local function driveFish(v: Visual, sub: CFrame, speed: number, t: number)
	local fish = v.Fish
	local root = fish and fish.PrimaryPart
	if not fish or not root or not fish.Parent then
		return
	end
	if fish:GetAttribute("Rider") ~= 0 and fish:GetAttribute("Rider") ~= nil then
		-- (we are on it: RideController drives it now)
		v.Fish = nil
		return
	end
	local _, _, _, dropAt = SubTrip.times(v.Trip)
	local c = Config.Sub
	local way = sub.LookVector
	local side = flat(way):Cross(UP)
	local beside = sub.Position + side * c.FishSide - UP * 2
	local from = (v.FishFrom or root.Position) + way * speed * math.max(0, os.clock() - v.FishGot)
	local e = Ease.smoothstep(dropAt - c.FishIn, dropAt - c.FishIn * 0.1, t)
	local at = from:Lerp(beside, e)
	local wiggle = math.sin(os.clock() * 9) * 0.12
	root.CFrame = CFrame.lookAt(at, at + way) * CFrame.Angles(0, wiggle, 0)
	root.AssemblyLinearVelocity = way * speed
	root.AssemblyAngularVelocity = Vector3.zero
	local swim = root:FindFirstChild("Swim")
	if swim and swim:IsA("LinearVelocity") then
		swim.VectorVelocity = way * speed
	end
	local turn = root:FindFirstChild("Turn")
	if turn and turn:IsA("AlignOrientation") then
		turn.CFrame = CFrame.lookAt(Vector3.zero, way)
	end
end

-- Where we are on our own trip: swimming, scooped up, on the seat, kicked onto our fish
local function riderAt(v: Visual, sub: CFrame, t: number): CFrame?
	local trip = v.Trip
	local pickupAt, rideAt = SubTrip.times(trip)
	local seat = sub * SEAT
	local way0 = flat(SubTrip.way(trip, 30, 30))
	local swimTo = trip.Points[1] + SEAT.Position + Vector3.new(0, 0.5, 0)
	local entry = v.Entry
	if t < pickupAt and entry then
		-- (approachPose) swimming on toward the pick-up, bobbing
		local u = math.clamp(t / math.max(pickupAt, 0.01), 0, 1)
		local at = entry.Position:Lerp(swimTo, Ease.smoothstep(0, 1, u)) + UP * math.sin(t * 5) * 0.4
		return CFrame.lookAt(at, at + way0) * CFrame.Angles(math.rad(-70), 0, 0)
	elseif t < rideAt then
		-- (pickupPose) held until the sub is under us, then tumbled up and over onto the seat
		local u = (t - pickupAt) / math.max(rideAt - pickupAt, 0.01)
		local from = CFrame.lookAt(swimTo, swimTo + way0) * CFrame.Angles(math.rad(-70), 0, 0)
		if u < 0.3 then
			return from
		end
		local k = Ease.smoothstep(0.3, 0.82, u)
		local at = from.Position:Lerp(seat.Position, k) + UP * (6 * math.sin(k * math.pi))
		local flip = CFrame.Angles(-math.pi * 2 * Ease.inOutSine(k), 0, 0)
		local turned = from.Rotation:Lerp(seat.Rotation, k)
		return CFrame.new(at) * turned * flip
	elseif v.Cue == "Kick" then
		-- (kickPose) off the seat in an arc onto our fish's saddle, rolling over
		local fish = v.Fish
		local root = fish and fish.PrimaryPart
		local saddle = root and root:FindFirstChild("Saddle")
		if not saddle or not saddle:IsA("Attachment") then
			return seat
		end
		local k = math.clamp((os.clock() - v.CuedAt) / math.max(Config.Sub.Kick, 0.05), 0, 1)
		local e = Ease.inOutSine(k)
		local target = saddle.WorldCFrame
		local at = seat.Position:Lerp(target.Position, e) + UP * (9 * math.sin(k * math.pi))
		local roll = CFrame.Angles(0, 0, -math.pi * 2 * e)
		return CFrame.new(at) * seat.Rotation:Lerp(target.Rotation, e) * roll
	end
	return seat
end

-- The camera on our own trip
local function cameraFor(v: Visual, sub: CFrame, speed: number, rider: Vector3, t: number, dt: number)
	local camera = workspace.CurrentCamera
	local trip = v.Trip
	local c = Config.Sub
	local pickupAt, rideAt, arriveAt = SubTrip.times(trip)
	local way0 = flat(SubTrip.way(trip, 30, 30))
	local right = way0:Cross(UP)
	local goal: Vector3
	local focus: Vector3
	local rate = 4
	local wide = 70
	if t < pickupAt then
		-- ahead and to the side, looking back at us and at it coming
		-- (the gate's posts stand close on both sides: the camera keeps in line with the lane)
		goal = rider + way0 * 15 + right * 5 + UP * 1
		focus = rider:Lerp(sub.Position, 0.35)
	elseif t < rideAt then
		-- round behind, to see us thrown onto the seat
		local u = (t - pickupAt) / math.max(rideAt - pickupAt, 0.01)
		goal = rider
			+ way0 * (15 - 33 * Ease.smoothstep(0, 1, u))
			+ right * (5 + 4 * math.sin(u * math.pi))
			+ UP * (1 + 8 * u)
		focus = rider
		rate = 5
	elseif t < arriveAt then
		-- behind it, wider with speed
		local way = sub.LookVector
		local share = math.clamp(speed / math.max(c.Speed, 1), 0, 1)
		goal = sub.Position - way * (c.Distance + 8 * share) + UP * (10 - 3 * share)
		focus = sub.Position + way * (25 + 20 * share)
		rate = 7
		wide = 70 + c.Fov * share
	else
		-- out to the side for the drop
		local way = flat(sub.LookVector)
		local side = way:Cross(UP)
		goal = sub.Position + side * (c.FishSide * 0.4) - way * 30 + UP * 9
		focus = sub.Position + way * 10 + side * (if trip.Fish then c.FishSide * 0.5 else 0)
		rate = 4
		wide = 74
	end
	-- Eased as offsets from what it follows (us, then the sub), never as places in the world: eased in the world, a
	-- camera falls far behind a sub doing a thousand studs a second. Switching what it follows keeps where it is.
	local anchor = if t < rideAt then rider else sub.Position
	local kind = if t < rideAt then "rider" else "sub"
	if kind ~= camKind or not camPos or not camFocus then
		-- (the trip's first frame cuts to its first framing, under the splash: eased from the dock's view, the camera
		-- went down through the hub's floor and the gate's posts)
		local first = camKind == "" or not camPos or not camFocus
		camPos = if first then goal - anchor else camAnchor + (camPos :: Vector3) - anchor
		camFocus = if first then focus - anchor else camAnchor + (camFocus :: Vector3) - anchor
		camKind = kind
		if first then
			fov = 70
		end
	end
	camAnchor = anchor
	local a = Ease.alpha(rate, dt)
	camPos = (camPos :: Vector3):Lerp(goal - anchor, a)
	camFocus = (camFocus :: Vector3):Lerp(focus - anchor, Ease.alpha(rate * 1.4, dt))
	local look = anchor + (camFocus :: Vector3)
	local at = anchor + (camPos :: Vector3)
	-- kept out of the walls and the floor: pulled in toward what it follows (not for the lane's props, which go
	-- see-through, PropController)
	if not camParams then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		camParams = params
	end
	local params = camParams :: RaycastParams
	local map = workspace:FindFirstChild("ClaudeBlockout")
	local lane = map and map:FindFirstChild("Lane")
	local props = lane and lane:FindFirstChild("Props")
	local surface = map and map:FindFirstChild("Surface")
	local skip: { Instance } = { camera, v.Model }
	if State.Player.Character then
		table.insert(skip, State.Player.Character)
	end
	if props then
		table.insert(skip, props)
	end
	if surface then
		table.insert(skip, surface)
	end
	if v.Fish then
		table.insert(skip, v.Fish)
	end
	params.FilterDescendantsInstances = skip
	local from = anchor + UP * 2
	local hit = workspace:Raycast(from, at - from, params)
	if hit then
		at = from + (at - from).Unit * math.max(0, (hit.Position - from).Magnitude - 2)
	end
	-- (never up in the water's surface layers)
	local top = Config.Oxygen.SurfaceY - 7
	if at.Y > top then
		at = Vector3.new(at.X, top, at.Z)
	end
	fov = Ease.lerp(fov, wide, Ease.alpha(3, dt))
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(at, look) * Shake.update(dt)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

-- Our own trip, each frame: the moments (sounds, bursts, banners), where we are, our fish, the camera
local function ours(v: Visual, sub: CFrame, speed: number, t: number, dt: number)
	local trip = v.Trip
	local c = Config.Sub
	local pickupAt, rideAt, arriveAt, dropAt = SubTrip.times(trip)
	local _, root, humanoid = State.character()
	if not root or not humanoid then
		return
	end
	if not v.Entry then
		v.Entry = root.CFrame
		Fx.burst(root.Position + UP * 2, 30, 0, 9)
		Feel.sound("Splash", 0.7, 0.9, 0.9)
	end
	-- the moments
	if t >= pickupAt + 0.3 * trip.Pickup and once(v, "scoop") then
		Fx.burst(root.Position, 40, 0, 10)
		Feel.sound("Splash", 0.8, 1.15, 0.8)
		Shake.play("Land", c.Shake)
	end
	if t >= rideAt - 0.15 and once(v, "seat") then
		Shake.play("LandBig", c.Shake * 0.8)
	end
	if t >= rideAt and once(v, "go") then
		Feel.sound("Whoosh", 0.9, 0.55, 2.5)
		Fx.burst(sub.Position - sub.LookVector * 14, 50, 0, 12)
		banner("SUBMARINE", landName(trip.Land), Color3.fromRGB(255, 210, 60), 2.4)
	end
	if t >= arriveAt and once(v, "arrive") then
		banner("NOW ARRIVING", landName(trip.Land), Color3.fromRGB(120, 230, 255), 2.2)
		Feel.sound("Swish", 0.6, 0.7, 0.6)
	end
	if t >= arriveAt and t < dropAt then
		if trip.Fish then
			SubPanel.hint("Here comes your fish!")
		else
			SubPanel.hint("Get ready to hook a fish!")
		end
	end
	-- the run's feel: speed lines and a rumble
	local share = math.clamp(speed / math.max(c.Speed, 1), 0, 1)
	if t >= rideAt and t < arriveAt then
		Feel.rush(share)
	end
	Shake.rumble("Sub", "Speed", if t >= rideAt and t < arriveAt then share * 1.4 else 0)
	-- our fish beside it
	driveFish(v, sub, speed, t)
	-- the fling: as soon as the server says
	if v.Cue == "Fling" then
		if State.Mode == "Carried" and once(v, "fling") then
			local seat = (sub * SEAT).Position
			root.CFrame = CFrame.lookAt(seat, seat + flat(sub.LookVector))
			root.AssemblyLinearVelocity = flat(sub.LookVector) * speed
			JumpController.fling(yawOf(flat(sub.LookVector)))
		end
		return
	end
	if State.Mode ~= "Carried" then
		return
	end
	humanoid.PlatformStand = true
	local cf = riderAt(v, sub, t)
	if cf then
		local was = v.RiderLast or cf.Position
		root.CFrame = cf
		root.AssemblyLinearVelocity = (cf.Position - was) / math.max(dt, 1e-3)
		root.AssemblyAngularVelocity = Vector3.zero
		v.RiderLast = cf.Position
		State.Heading = yawOf(flat(sub.LookVector))
		State.Speed = speed
		-- the kick's end: on the saddle, and the server is told
		if v.Cue == "Kick" and not v.Told and os.clock() - v.CuedAt >= c.Kick then
			v.Told = true
			Shake.play("Land", c.Shake)
			Net.Action:FireServer("SubLand", v.Fish)
		end
	end
	cameraFor(v, sub, speed, root.Position, t, dt)
end

local function step(dt: number)
	local clock = now()
	for player, v in visuals do
		local trip = v.Trip
		local t = clock - trip.Start
		local _, _, _, _, endAt = SubTrip.times(trip)
		if t > endAt + 4 then
			remove(player)
		else
			local cf, speed = subAt(trip, t)
			place(v, cf, speed, dt)
			if t > endAt and not v.Faded then
				v.Faded = true
			end
			if v.Faded then
				local fade = math.clamp((t - endAt) / 3, 0, 1)
				for _, p in v.Parts do
					p.Transparency = if p.Name == "Window"
							or p.Name == "Port"
							or p.Name == "Light"
						then math.max(fade, 0)
						else fade
				end
			end
			if v == mine then
				ours(v, cf, speed, t, dt)
			end
		end
	end
end

local function watch(player: Player)
	local function read()
		local json = player:GetAttribute("SubTrip")
		local trip = if type(json) == "string" then SubTrip.decode(json) else nil
		local had = visuals[player]
		if not trip then
			-- cleared: kept on to its end if the drop is done, gone at once if it was given up before it
			if had then
				local _, _, _, dropAt = SubTrip.times(had.Trip)
				if now() - had.Trip.Start < dropAt then
					remove(player)
				end
			end
			return
		end
		if had and had.Trip.Start == trip.Start then
			return
		end
		remove(player)
		local v = makeVisual(player, trip)
		visuals[player] = v
		if player == State.Player then
			mine = v
			camPos, camFocus = workspace.CurrentCamera.CFrame.Position, nil
			camKind = ""
			camAnchor = Vector3.zero
			fov = workspace.CurrentCamera.FieldOfView
		end
	end
	player:GetAttributeChangedSignal("SubTrip"):Connect(read)
	read()
end

function SubController.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "SubBanners"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.Parent = State.Player:WaitForChild("PlayerGui")
	SubPanel.init()
	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any, b: any)
		local v = mine
		if kind == "SubFish" and v and typeof(a) == "Instance" and a:IsA("Model") then
			v.Fish = a
			v.FishFrom = if a.PrimaryPart then a.PrimaryPart.Position else nil
			v.FishGot = os.clock()
		elseif kind == "SubDrop" and v then
			v.Cue = a
			v.CuedAt = os.clock()
			if a == "Kick" and typeof(b) == "Instance" and b:IsA("Model") then
				v.Fish = b
			end
		end
	end)
end

function SubController.Start()
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(remove)
	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end
	-- after the ride camera (RideFish, Camera + 1): ours wins while we are carried
	RunService:BindToRenderStep("SubTrip", Enum.RenderPriority.Camera.Value + 3, step)
end

return SubController
