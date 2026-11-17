--!strict
-- The hook (Config.Hook; the user, 2026-11-17: "we have the hook mechanic, you can hook onto the next fish, but
-- there's nothing actually doing that ... a harpoon gun or a grappling hook ... something that flails about in the air,
-- something that has very dynamic movements, just like it does in Ride a Dino for the lasso").
-- A small anchor on a rope, in the rider's right hand. It is a picture only: nothing here decides anything, the hop,
-- the lock and the grab are JumpController's and the server's. What it does, by what the rider is doing (Lib/State):
--   RIDING   whirled lazily over the head, as a rodeo rider swings a lasso (Hook.Ride; 0 hides it on a fish);
--   THE HOP  whirled hard and wide. With a fish locked it winds up faster and wider, leaning toward that fish;
--   THE GRAB thrown at the fish as the pull-in begins (it flies out in the first part of the pull-in, while the
--            rider still creeps: Jump.ReelCurve), bites with a burst of bubbles, and the rope pulls taut: the rider
--            is hauled in along it;
--   LANDED, or the grab refused: it comes back to the hand and is whirled again. Off a fish and out of a hop
--            (floating, the dock, drowning) it is put away.
-- The rope is real in the one way that matters for the look: it is a chain of points with their own momentum
-- (Verlet), dragged by the water and sinking a little, held at the hand and at the anchor. Nothing in it is keyed:
-- the whipping and lagging is what a rope does when its ends are thrown about.
-- How it stays cheap: one rope, Hook.Segments cylinders and a dozen boxes for the anchor, made once and moved with a
-- single BulkMoveTo a frame. Not solid, seen by no ray, no shadows. Nothing is created per frame or per throw (the
-- bite's bubbles are Fx's, as a landing's are). Ours alone, on our own screen: other players' hooks aren't drawn yet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Fx = require(script.Parent.Parent.Lib.Fx)
local State = require(script.Parent.Parent.Lib.State)
local JumpController = require(script.Parent.JumpController)

local HookController = {}

local TAU = math.pi * 2
local UP = Vector3.yAxis
local TURN = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder lies along its X: this lays it along the way it looks
local FAR = 80 -- the rider moved further than this in one frame: a teleport, the rope starts again

local container: Model
local anchor: Model -- the anchor's pieces, inside it (the outline is theirs alone unless Hook.RopeOutline)
local parts: { BasePart } = {} -- the rope's cylinders, hand to anchor, then the anchor's pieces: one BulkMoveTo
local cframes: { CFrame } = {}
local lengths: { number } = {} -- each cylinder's length as last written
local headOffsets: { CFrame } = {} -- the anchor's pieces, from where the rope ends (it points along -Z)
local points: { Vector3 } = {} -- the rope: [1] the hand ... [count + 1] the anchor
local before: { Vector3 } = {} -- where each was a frame ago (its momentum)
local count = 0 -- cylinders built
local builtThick, builtHead = 0, 0
local swish: Sound

-- "Off" (put away), "Whirl", "Throw" (flying at the fish), "Taut" (bitten: the pull-in), "Back" (coming back)
local phase = "Off"
local phaseAt = 0
local backTo = "Off" -- where a "Back" ends: "Whirl" or "Off"
local backFrom = Vector3.zero
local throwFrom = Vector3.zero
local throwTime = 0
local target: Model? = nil -- the fish it is thrown at
-- the whirl, each eased to what the moment asks for
local angle = 0
local precess = 0
local breath = 0 -- the ring's breathing: its own count, never wound back (wound back with `angle`, the ring jumped once a turn)
local rate = 0 -- turns a second
local radius = 0
local lift = 0
local rope = 0 -- the rope's length
local lean = Vector3.zero -- how the whirl's plane leans toward a locked fish
local lastRoot: Vector3? = nil
local handPart: BasePart? = nil
local handOf: Model? = nil

-- Counts for tests (what it is doing, how long the rope is drawn, how far the anchor is from the hand)
HookController.Stats = { Phase = "Off", Rope = 0, Out = 0, Throws = 0, Bites = 0 }

local function piece(shape: Enum.PartType, size: Vector3, colour: Color3, into: Instance): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = into
	return part
end

-- The rope and the anchor, made once (and again if the sandbox changes how many pieces, or how big)
local function build()
	local h = Config.Hook
	container:ClearAllChildren()
	anchor = Instance.new("Model")
	anchor.Name = "Anchor"
	anchor.Parent = container
	table.clear(parts)
	table.clear(cframes)
	table.clear(lengths)
	table.clear(headOffsets)
	count = math.clamp(math.floor(h.Segments), 2, 40)
	builtThick, builtHead = h.Thick, h.HeadSize
	for i = 1, count do
		parts[i] = piece(Enum.PartType.Cylinder, Vector3.new(1, h.Thick, h.Thick), h.RopeColor, container)
		cframes[i] = CFrame.identity
		lengths[i] = 1
	end
	-- the anchor: a knot where the rope ends, a shaft, a crown, and three flukes that sweep out and back
	local s = h.HeadSize
	local function add(shape: Enum.PartType, size: Vector3, colour: Color3, offset: CFrame)
		table.insert(parts, piece(shape, size * s, colour, anchor))
		table.insert(cframes, CFrame.identity)
		table.insert(headOffsets, offset)
	end
	add(Enum.PartType.Ball, Vector3.one * 0.6, h.HeadDark, CFrame.identity)
	add(Enum.PartType.Cylinder, Vector3.new(2.4, 0.34, 0.34), h.HeadColor, CFrame.new(0, 0, -1.2 * s) * TURN)
	add(Enum.PartType.Ball, Vector3.one * 0.56, h.HeadColor, CFrame.new(0, 0, -2.4 * s))
	local tip = Vector3.new(0, 0, -2.4 * s)
	for k = 0, 2 do
		local a = k * TAU / 3
		local out = Vector3.new(math.cos(a), math.sin(a), 0)
		local side = Vector3.new(-math.sin(a), math.cos(a), 0)
		local arm = (out * 0.8 + Vector3.zAxis * 0.6).Unit
		local armEnd = tip + arm * (1.5 * s)
		add(
			Enum.PartType.Block,
			Vector3.new(0.3, 0.3, 1.6),
			h.HeadColor,
			CFrame.lookAt(tip + arm * (0.75 * s), armEnd, side)
		)
		local point = (out * 0.25 + Vector3.zAxis * 0.97).Unit
		add(
			Enum.PartType.Block,
			Vector3.new(0.24, 0.24, 1),
			h.HeadDark,
			CFrame.lookAt(armEnd + point * (0.4 * s), armEnd + point * s, side)
		)
	end
	if h.Outline > 0 then
		local outline = Instance.new("Highlight")
		outline.FillTransparency = 1
		outline.OutlineColor = Color3.new(0, 0, 0)
		outline.OutlineTransparency = 0
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = if h.RopeOutline > 0 then container else anchor
	end
	for i = 1, count + 1 do
		points[i] = points[i] or Vector3.zero
		before[i] = before[i] or Vector3.zero
	end
end

-- The right hand (R15), or the end of the right arm (R6)
local function hand(character: Model): Vector3?
	if handOf ~= character or not handPart or handPart.Parent ~= character then
		handOf = character
		local found = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		handPart = if found and found:IsA("BasePart") then found else nil
	end
	local part = handPart
	if not part then
		return nil
	end
	if part.Name == "Right Arm" then
		return part.CFrame * Vector3.new(0, -part.Size.Y / 2, 0)
	end
	return part.Position
end

local function hide()
	if phase ~= "Off" then
		phase = "Off"
		container.Parent = nil
	end
	target = nil
	lastRoot = nil
	HookController.Stats.Phase = "Off"
end

-- Out of the hand: the whole rope starts there and unfurls
local function show(at: Vector3)
	for i = 1, count + 1 do
		points[i] = at
		before[i] = at
	end
	rate, radius, lift, rope = 0, 0, 0, 0
	lean = Vector3.zero
	phase = "Whirl"
	container.Parent = workspace.CurrentCamera
end

-- Where the hook bites: the top of the fish's back, a little ahead of its middle (nil: the fish is gone)
local function bite(fish: Model?): Vector3?
	local root = fish and fish.PrimaryPart
	if not fish or not root or not fish.Parent then
		return nil
	end
	local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
	if not kind then
		return root.Position
	end
	local body = Config.bodyOf(fish, kind)
	return root.CFrame * Vector3.new(0, body.Y * 0.5, -body.Z * 0.2)
end

-- Where the whirl has the anchor now: round a ring over the rider's head, the ring breathing a little and its plane tipping
-- round slowly, leaning toward a locked fish. Never further from the hand than the rope reaches.
local function whirl(root: Vector3, from: Vector3): Vector3
	local h = Config.Hook
	local tip = math.tan(math.rad(h.Tilt))
	local normal = (UP + Vector3.new(math.cos(precess), 0, math.sin(precess)) * tip + lean).Unit
	local u = normal:Cross(Vector3.zAxis)
	if u.Magnitude < 0.1 then
		u = normal:Cross(Vector3.xAxis)
	end
	u = u.Unit
	local v = normal:Cross(u)
	local r = radius * (1 + h.Wobble * math.sin(breath))
	local goal = root + UP * lift + (u * math.cos(angle) + v * math.sin(angle)) * r
	local off = goal - from
	local most = rope * 0.96
	if off.Magnitude > most then
		goal = from + off.Unit * most
	end
	return goal
end

local function back(to: string, now: number)
	phase = "Back"
	backTo = to
	phaseAt = now
	backFrom = points[count + 1]
	target = nil
end

local function step(dt: number)
	local h = Config.Hook
	local character, root = State.character()
	local from = if character then hand(character) else nil
	local mode = State.Mode
	local want = "Off"
	if h.On > 0 and root and from then
		if mode == "Jumping" then
			want = if State.Reeling and State.JumpTarget then "Grab" else "Whirl"
		elseif mode == "Riding" and h.Ride > 0 then
			want = "Whirl"
		end
	end
	if not root or not from or (phase == "Off" and want == "Off") then
		hide()
		return
	end
	if count ~= math.clamp(math.floor(h.Segments), 2, 40) or builtThick ~= h.Thick or builtHead ~= h.HeadSize then
		build()
		phase = "Off"
	end
	local now = os.clock()
	dt = math.min(dt, 0.05)
	if phase == "Off" then
		show(from)
	end
	-- what the rider is doing, to what the hook does
	if want == "Grab" then
		if phase == "Whirl" or phase == "Back" then
			local _, reelTime = JumpController.reel()
			phase = "Throw"
			phaseAt = now
			throwFrom = points[count + 1]
			throwTime = math.clamp(reelTime * h.ThrowShare, h.ThrowMin, h.ThrowMost)
			target = State.JumpTarget
			HookController.Stats.Throws += 1
		end
	elseif want == "Whirl" then
		if phase == "Throw" or phase == "Taut" then
			back("Whirl", now)
		elseif phase == "Back" and backTo == "Off" then
			backTo = "Whirl"
		end
	elseif phase ~= "Back" or backTo ~= "Off" then
		back("Off", now)
	end

	-- the whirl's numbers, eased to what the moment asks for (kept going through a throw, so it comes back to them)
	local riding = mode == "Riding"
	local locked = if mode == "Jumping" then State.JumpTarget else nil
	local lockedAt = bite(locked)
	local wound = if lockedAt then 1 else 0
	local ease = Ease.alpha(h.SpinEase, dt)
	rate += ((if riding then h.RideRate else h.HopRate * (1 + (h.LockRate - 1) * wound)) - rate) * ease
	radius += ((if riding then h.RideRadius else h.HopRadius * (1 + (h.LockRadius - 1) * wound)) - radius) * ease
	lift += ((if riding then h.RideLift else h.HopLift) - lift) * ease
	rope += ((if riding then h.RideLength else h.HopLength) - rope) * ease
	local leanTo = Vector3.zero
	if lockedAt then
		local flat = Vector3.new(lockedAt.X - root.Position.X, 0, lockedAt.Z - root.Position.Z)
		if flat.Magnitude > 1 then
			leanTo = flat.Unit * math.tan(math.rad(h.LockLean))
		end
	end
	lean = lean:Lerp(leanTo, ease)
	precess += dt * 0.35
	angle += rate * TAU * dt
	breath = (breath + rate * TAU * dt * 0.63) % (TAU * 100)
	if angle >= TAU then
		angle -= TAU
		if phase == "Whirl" and mode == "Jumping" and h.Swish > 0 then
			-- one swish a turn, in the hop
			swish.Volume = h.Swish
			swish.PlaybackSpeed = 1.5 + 0.25 * math.sin(precess * 3)
			swish.TimePosition = 0
			swish:Play()
		end
	end

	-- where the anchor is, and how long the rope is, by what it is doing
	local goal: Vector3
	local length = rope
	local heading: Vector3? = nil -- the way the anchor points (nil: along the rope's end)
	local spin = angle * h.HeadSpin
	if phase == "Throw" or phase == "Taut" then
		local at = bite(target)
		if not at then
			back(if want == "Off" then "Off" else "Whirl", now)
			goal = points[count + 1]
		elseif phase == "Throw" then
			local u = math.clamp((now - phaseAt) / math.max(throwTime, 0.01), 0, 1)
			local way = at - throwFrom
			goal = throwFrom:Lerp(at, Ease.outQuad(u)) + UP * (math.sin(math.pi * u) * way.Magnitude * h.ThrowArc)
			length = (goal - from).Magnitude * Ease.lerp(h.ThrowSlack, h.TautSlack, u)
			heading = if way.Magnitude > 0.1 then way.Unit else nil
			if u >= 1 then
				phase = "Taut"
				HookController.Stats.Bites += 1
				if h.BiteBubbles > 0 then
					Fx.burst(at, h.BiteBubbles, 0, 4)
				end
				if h.BiteSound > 0 then
					local sound = Fx.sound("Tick")
					if sound then
						sound.Volume *= h.BiteSound
					end
				end
			end
		else
			goal = at
			length = (goal - from).Magnitude * h.TautSlack
			spin = 0
		end
	else
		goal = whirl(root.Position, from)
	end
	if phase == "Back" then
		local u = math.clamp((now - phaseAt) / math.max(h.Retract, 0.01), 0, 1)
		local home = if backTo == "Whirl" then whirl(root.Position, from) else from
		goal = backFrom:Lerp(home, u * u * (3 - 2 * u))
		length = math.max((goal - from).Magnitude * 1.05, rope * u)
		if u >= 1 then
			if backTo == "Off" then
				hide()
				return
			end
			phase = "Whirl"
		end
	end

	-- the rope: carried with the rider (but for a share, the water it is dragged through), each point keeping its
	-- momentum, dragged and sinking, then pulled back inside the rope's length from both ends
	local n = count
	local last = lastRoot
	lastRoot = root.Position
	if last then
		local moved = root.Position - last
		if moved.Magnitude > FAR then
			for i = 1, n + 1 do
				points[i] = from
				before[i] = from
			end
		else
			local carry = moved * math.clamp(h.Carry, 0, 1)
			for i = 2, n do
				points[i] += carry
				before[i] += carry
			end
		end
	end
	local keep = math.exp(-math.max(h.Drag, 0) * dt)
	local fall = Vector3.new(0, -h.Sink * dt * dt, 0)
	for i = 2, n do
		local p = points[i]
		points[i] = p + (p - before[i]) * keep + fall
		before[i] = p
	end
	points[1] = from
	before[n + 1] = points[n + 1]
	points[n + 1] = goal
	local rest = math.max(length, 0.2) / n
	for _ = 1, math.clamp(math.floor(h.Stiff), 1, 12) do
		for i = 1, n do
			local a, b = points[i], points[i + 1]
			local d = b - a
			local m = d.Magnitude
			-- (a rope: it pulls when stretched, and only nudges apart when bunched)
			if m > 1e-4 then
				local fix = d * ((m - rest) / m * (if m > rest then 1 else 0.15))
				if i == 1 then
					points[2] = b - fix
				elseif i == n then
					points[n] = a + fix
				else
					points[i] = a + fix / 2
					points[i + 1] = b - fix / 2
				end
			end
		end
	end

	-- drawn: a cylinder from each point to the next, and the anchor at the end
	local drawn = 0
	for i = 1, n do
		local a, b = points[i], points[i + 1]
		local d = b - a
		local m = d.Magnitude
		drawn += m
		local long = m + h.Thick * 0.5
		if math.abs(long - lengths[i]) > 0.03 then
			lengths[i] = long
			parts[i].Size = Vector3.new(long, h.Thick, h.Thick)
		end
		cframes[i] = if m > 1e-3
			then CFrame.lookAt((a + b) / 2, b, if math.abs(d.Y) > m * 0.95 then Vector3.xAxis else UP) * TURN
			else CFrame.new(a)
	end
	local along = heading
	if not along then
		local d = points[n + 1] - points[n]
		along = if d.Magnitude > 1e-3 then d.Unit else -UP
	end
	local way = along :: Vector3
	local headAt = CFrame.lookAt(goal, goal + way, if math.abs(way.Y) > 0.95 then Vector3.xAxis else UP)
		* CFrame.Angles(0, 0, spin)
	for k, offset in headOffsets do
		cframes[n + k] = headAt * offset
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	local stats = HookController.Stats
	stats.Phase = phase
	stats.Rope = drawn
	stats.Out = (goal - from).Magnitude
end

function HookController.Init()
	container = Instance.new("Model")
	container.Name = "Hook"
	swish = Instance.new("Sound")
	swish.Name = "HookSwish"
	swish.SoundId = "rbxasset://sounds/action_swim.mp3"
	swish.Parent = SoundService
	build()
end

function HookController.Start()
	-- (after the fish, the rider and the camera have all moved this frame)
	RunService:BindToRenderStep("RideHook", Enum.RenderPriority.Last.Value, step)
end

return HookController
