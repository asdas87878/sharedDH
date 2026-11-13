--!strict
-- The map's props on our own screen (Config.Props; Hugo, 2026-11-13). Nothing here decides anything: the server says
-- which boxes of a prop are out and when it is back (PropService: the tag "PropOut" on each box that is out; BreakAt,
-- BreakVel, BreakT and RebuildT on the prop's Model). This file is what that looks like, three things:
--   SEEING THROUGH (Hugo, 2026-11-13, after playing the fade from 80 studs off). On a fish that goes through props,
--   and for the rider in the hop:
--     a prop IN OUR WAY (ahead of us, inside the corridor our body sweeps: Props.PathWidth) looks solid until our
--     body touches it. At the touch the camera shakes once (Props.Shake, a little harder when faster; bubbles and
--     a thud), and the prop turns see-through quickly (Props.TouchEase, to Props.FadeTo) for as long as we are in
--     it. No slow-down and nothing taken: it is feedback only;
--     a prop BESIDE us (within Props.SideNear of our body and not in our way), or between the camera and us
--     (Props.ViewNear), is see-through while it is that close, so it never blocks the view.
--   Once see-through, a prop stays so until we are clear of it (SideSlack): turning into one we were passing does
--   not make it solid again, and nothing flickers at an edge. On a fish that breaks props they stay solid-looking,
--   something to smash (Props.FadeForBreakers = 1: the same rules for it too, without the shake). It is by OUR
--   body and on our screen only, so another player sees the same prop by their own.
--   THE BREAK. A box the server takes out is hidden, and a copy of it is thrown from where the fish hit, along the
--   fish's way and with its speed, turning, slowing in the water, sinking, then fading away. The copies are ours
--   alone (under the camera), not solid and not seen by any ray: they can't block, trap or slow anyone.
--   A copy that is close to us, or between the camera and us, is see-through as well (Props.DebrisNear to
--   DebrisFar), so a flying box never blocks the view either; then it fades away as before.
--   THE REBUILD. When the server puts the boxes back (no player near for a while), they fade in, a few at a time.
-- How it stays cheap: the props round us are found by spatial queries every Props.FadeEvery seconds (the engine's,
-- over the props folder only), never by walking all the props; each frame looks only at those few (a prop whose
-- whole bulk is clear of us is passed over with three distances, its boxes not read), the boxes coming back and
-- the flying copies (Props.MaxDebris at most). A box is shown or hidden with
-- LocalTransparencyModifier, on it and on its pictures (Textures and Decals), so its own Transparency, its glow
-- (Neon) and what the server replicates are never written.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Fx = require(script.Parent.Parent.Lib.Fx)
local RideController = require(script.Parent.RideController)
local State = require(script.Parent.Parent.Lib.State)

local PropController = {}

local TAG = "PropOut"
local WAIT = 0.25 -- a tagged box waits this long for its prop's push to arrive before it is given up as an old break
local FRESH = 1.5 -- a break this many seconds old or less is thrown; an older one (we joined, or loaded it, later) is just gone
local SHOWN = 0.004 -- a fade nearer to where it is going than this is there
local RIDER = 2.5 -- a rider off a fish (the hop, floating): their body's half width, studs
local MOVING = 3 -- slower than this, studs a second, we are going nowhere: nothing is "in our way"

-- a prop round us: how see-through it is now, where that is going, its boxes, and what we know of it
type Fade = {
	Now: number,
	Goal: number,
	Parts: { BasePart },
	Seen: number,
	Shown: number,
	Through: boolean, -- see-through for us (held until we are clear of it)
	Path: boolean, -- in our way: solid until touched
	In: boolean, -- our body is in it
	Centre: Vector3, -- the ball all its boxes are in,
	Radius: number,
	Span: number, -- and its biggest side, studs
}
-- us: the body that touches props (a fish: from its tail to its nose; a rider off one: a point), and the camera
type Body = {
	At: Vector3,
	Tail: Vector3,
	Nose: Vector3,
	Radius: number,
	Way: Vector3?, -- where we are going (nil: nowhere)
	Speed: number,
	Eye: Vector3,
	Breaker: boolean, -- on a fish that breaks props
}
-- a box fading back in: when it starts (os.clock())
type Rise = { At: number }
-- a box the server just tagged: when we saw the tag (os.clock())
type Arrival = { Part: BasePart, At: number }
-- a flying copy of a box
type Piece = {
	Part: BasePart,
	At: Vector3,
	Turn: CFrame,
	Velocity: Vector3,
	Axis: Vector3,
	Rate: number, -- radians a second
	Age: number,
	Half: number, -- half its biggest side
	See: number, -- how see-through it is for being close to us, 0 to FadeTo
}

local rng = Random.new()
local folder: Instance? = nil
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local fades: { [Instance]: Fade } = {}
local out: { [BasePart]: boolean } = {} -- the boxes the server has taken out (hidden here)
local rising: { [BasePart]: Rise } = {}
local pieces: { Piece } = {}
local arrived: { Arrival } = {} -- boxes tagged and not yet thrown (their prop's push is read a frame later, or a few)
local pictures: { [BasePart]: { Decal } } = setmetatable({}, { __mode = "k" }) :: any
local bubbled: { [Instance]: number } = {} -- prop -> the BreakT we last made bubbles for
local lookAt = 0
local stamp = 0
local lastAt: Vector3? = nil -- where our body was a frame ago, and what it was (a fish, or us)
local lastOn: Instance? = nil
local velocity = Vector3.zero
local shookAt = -math.huge -- os.clock() of the last touch's shake

-- Counts for tests and the sandbox (how many props are fading, boxes are out, copies are flying)
-- Round = props being watched; Through, Inside, Path = how many are see-through for us, have us in them, are in our
-- way; Touches = touches so far, Shakes = those that shook the camera, Shook = the last shake's size; DebrisSeen =
-- how see-through the most see-through flying copy is for being close
PropController.Stats = {
	Fading = 0,
	Out = 0,
	Flying = 0,
	Faded = 0,
	Round = 0,
	Through = 0,
	Inside = 0,
	Path = 0,
	Touches = 0,
	Shakes = 0,
	Shook = 0,
	DebrisSeen = 0,
}

local function props(): Instance?
	if folder and folder.Parent then
		return folder
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local lane = blockout and blockout:FindFirstChild("Lane")
	folder = lane and lane:FindFirstChild("Props")
	if folder then
		overlap.FilterDescendantsInstances = { folder }
	end
	return folder
end

-- A box's pictures (kept: a box's pictures don't change)
local function picturesOf(part: BasePart): { Decal }
	local known = pictures[part]
	if known then
		return known
	end
	local list: { Decal } = {}
	for _, child in part:GetChildren() do
		if child:IsA("Decal") then -- (a Texture is one too)
			table.insert(list, child)
		end
	end
	pictures[part] = list
	return list
end

-- How see-through a box is on our screen, 0 (as the map made it) to 1 (gone), on top of its own Transparency
local function show(part: BasePart, by: number)
	local was = part.LocalTransparencyModifier
	if was == by or (math.abs(was - by) < 0.002 and by ~= 0 and by ~= 1) then
		return
	end
	part.LocalTransparencyModifier = by
	for _, picture in picturesOf(part) do
		picture.LocalTransparencyModifier = by
	end
end

-- How see-through its prop's fade makes a box now
local function fadeOf(part: BasePart): number
	local fade = part.Parent and fades[part.Parent]
	return if fade then fade.Now else 0
end

-- How far a point is from a box (0 inside it)
local function gap(part: BasePart, at: Vector3): number
	local own = part.CFrame:PointToObjectSpace(at)
	local half = part.Size / 2
	local nearest = Vector3.new(
		math.clamp(own.X, -half.X, half.X),
		math.clamp(own.Y, -half.Y, half.Y),
		math.clamp(own.Z, -half.Z, half.Z)
	)
	return (own - nearest).Magnitude
end

-- The point of the line from a to b nearest to p
local function nearOn(a: Vector3, b: Vector3, p: Vector3): Vector3
	local ab = b - a
	local length = ab:Dot(ab)
	if length < 1e-6 then
		return a
	end
	return a + ab * math.clamp((p - a):Dot(ab) / length, 0, 1)
end

-- Us, this frame: nil with no character. On a fish the body is the fish's (Config.bodyOf: a rod from tail to nose,
-- as thick as the fish is wide or tall), off one it is the rider. Where we are going is read from where we were.
local function where(dt: number): Body?
	local _, root = State.character()
	if not root then
		lastAt = nil
		return nil
	end
	local at = root.Position
	local tail, nose = at, at
	local radius = RIDER
	local breaker = false
	local on: Instance = root
	local fish = State.Fish
	local fishRoot = fish and fish.PrimaryPart
	if State.Mode == "Riding" and fish and fishRoot then
		local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
		if kind then
			local size = Config.bodyOf(fish, kind)
			local cf = fishRoot.CFrame
			radius = math.min(math.max(size.X, size.Y), size.Z) / 2
			local half = math.max(size.Z / 2 - radius, 0)
			at = cf.Position
			nose = at + cf.LookVector * half
			tail = at - cf.LookVector * half
			breaker = Config.breaks(kind)
			on = fishRoot
		end
	end
	if lastAt and lastOn == on and dt > 0 then
		local now = (at - lastAt) / dt
		if now.Magnitude < 2000 then -- (a jump across the map is not a speed)
			velocity = velocity:Lerp(now, 0.5)
		end
	else
		velocity = Vector3.zero -- (onto a fish or off one: the body is another, so no speed is read across the change)
	end
	lastAt, lastOn = at, on
	local speed = velocity.Magnitude
	return {
		At = at,
		Tail = tail,
		Nose = nose,
		Radius = radius,
		Way = if speed >= MOVING then velocity / speed else nil,
		Speed = speed,
		Eye = workspace.CurrentCamera.CFrame.Position,
		Breaker = breaker,
	}
end

-- Whether whole props turn see-through for us now: in the water, and not on a fish that breaks them (unless
-- Props.FadeForBreakers)
local function passing(body: Body?): boolean
	local p = Config.Props
	if not body or p.FadeTo <= 0 or not State.inWater() then
		return false
	end
	return not body.Breaker or p.FadeForBreakers ~= 0
end

-- A prop's boxes, and the ball they are all in (read again when a box has loaded in or gone)
local function measure(model: Instance, fade: Fade)
	local list: { BasePart } = {}
	local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(list, child)
			local reach = Vector3.one * (child.Size.Magnitude / 2)
			low = low:Min(child.Position - reach)
			high = high:Max(child.Position + reach)
		end
	end
	fade.Parts = list
	if #list > 0 then
		local size = high - low
		fade.Centre = (low + high) / 2
		fade.Radius = size.Magnitude / 2
		fade.Span = math.max(size.X, size.Y, size.Z)
	end
end

-- The props round us: a spatial query round our body, and one along the line from the camera to us, a few times a
-- second. It only says which props to watch; what each looks like is judged every frame (judge), so a touch is seen
-- the frame it happens however fast we go.
local function look(body: Body?)
	local p = Config.Props
	stamp += 1
	local root = props()
	if not root or not body or not passing(body) then
		return
	end
	local every = math.max(p.FadeEvery, 0.03)
	local side = math.max(p.SideNear, 0) + math.max(p.SideSlack, 0)
	local seen: { [Instance]: boolean } = {}
	local function find(at: Vector3, radius: number)
		for _, part in workspace:GetPartBoundsInRadius(at, radius, overlap) do
			local model = part.Parent
			if model and model.Parent == root and not seen[model] then
				seen[model] = true
				local fade = fades[model]
				if not fade then
					local new: Fade = {
						Now = 0,
						Goal = 0,
						Parts = {},
						Seen = 0,
						Shown = -1,
						Through = false,
						Path = false,
						In = false,
						Centre = part.Position,
						Radius = 0,
						Span = 0,
					}
					fade = new
					fades[model] = new
				end
				local f = fade :: Fade
				f.Seen = stamp
				if #f.Parts ~= #model:GetChildren() then -- (a prop's boxes can load in one after another)
					measure(model, f)
					f.Shown = -1
				end
			end
		end
	end
	-- (as far as we swim before the next two looks, so a prop is being watched before we can reach it)
	find(body.At, (body.Nose - body.At).Magnitude + body.Radius + side + body.Speed * every * 2 + 4)
	if p.ViewNear > 0 then
		local line = body.Eye - body.At
		find(body.At + line / 2, line.Magnitude / 2 + p.ViewNear + math.max(p.SideSlack, 0))
	end
end

-- Our body has just touched a prop that it goes through: the shake, the bubbles and the thud. Not more often than
-- Props.ShakeGap, not for a small thing, not on a fish that breaks it (the break has its own), and never while a
-- bigger shake (a landing's) is still going.
local function touched(fade: Fade, body: Body)
	local p = Config.Props
	local stats = PropController.Stats
	stats.Touches += 1
	local now = os.clock()
	if body.Breaker or State.dying() or now - shookAt < p.ShakeGap or fade.Span < p.ShakeMin then
		return
	end
	shookAt = now
	local by = 1 + p.ShakeBySpeed * (body.Speed - p.ShakeAt) / math.max(p.ShakeAt, 1)
	local size = p.Shake * math.clamp(by, 0.5, 1.6)
	if size > 0 and RideController.shaking() < size then
		RideController.shake(size, math.max(p.ShakeTime, 0.01))
		stats.Shakes += 1
		stats.Shook = size
	end
	local front = body.Nose + (body.Way or Vector3.zero) * body.Radius
	if p.TouchBubbles > 0 then
		Fx.burst(front, p.TouchBubbles, 0, 5)
	end
	if p.TouchSound > 0 then
		local sound = Fx.sound("Pop")
		if sound then
			sound.Volume *= p.TouchSound
			sound.PlaybackSpeed = 0.55
		end
	end
end

-- What each prop round us should look like, every frame: solid while it is in our way, see-through once we touch it
-- or while it is close beside us or between the camera and us. Each rule has a nearer line to start and a further
-- one to stop, so nothing flickers at an edge.
local function judge(body: Body?)
	local p = Config.Props
	local on = passing(body)
	local to = math.clamp(p.FadeTo, 0, 1)
	local slack = math.max(p.SideSlack, 0)
	local sideIn = math.max(p.SideNear, 0)
	local viewIn = if p.ViewNear > 0 then p.ViewNear else -math.huge
	local round, through, inside, inWay = 0, 0, 0, 0
	for model, fade in fades do
		if not (on and body) or fade.Seen ~= stamp or not model.Parent then
			fade.Through, fade.Path, fade.In = false, false, false
			fade.Goal = 0
			continue
		end
		round += 1
		local way = body.Way
		local pathIn = body.Radius + math.max(p.PathWidth, 0)
		local pathOut = pathIn + math.max(p.PathSlack, 0)
		-- the prop's whole bulk first: clear of all three rules, its boxes aren't read
		local centre = fade.Centre
		local close = (centre - nearOn(body.Tail, body.Nose, centre)).Magnitude - body.Radius - fade.Radius
				<= sideIn + slack
			or (centre - nearOn(body.At, body.Eye, centre)).Magnitude - fade.Radius <= viewIn + slack
		if not close and way then
			local off = centre - body.At
			local along = off:Dot(way)
			close = along + fade.Radius > 0 and (off - way * along).Magnitude - fade.Radius < pathOut
		end
		local bodyGap, viewGap, pathGap = math.huge, math.huge, math.huge
		if close then
			for _, part in fade.Parts do
				if part.Parent == model and not out[part] then
					local c = part.Position
					bodyGap = math.min(bodyGap, gap(part, nearOn(body.Tail, body.Nose, c)) - body.Radius)
					viewGap = math.min(viewGap, gap(part, nearOn(body.At, body.Eye, c)))
					if way then
						local along = (c - body.At):Dot(way)
						if along > 0 then
							pathGap = math.min(pathGap, gap(part, body.At + way * along))
						end
					end
				end
			end
		end
		local touching = bodyGap <= (if fade.In then math.max(p.TouchSlack, 0) else 0)
		if touching and not fade.In then
			touched(fade, body)
		end
		fade.In = touching
		fade.Path = pathGap < (if fade.Path then pathOut else pathIn)
		if fade.Through then
			if not touching and bodyGap > sideIn + slack and viewGap > viewIn + slack then
				fade.Through = false
			end
		elseif touching or (not fade.Path and (bodyGap <= sideIn or viewGap <= viewIn)) then
			fade.Through = true
		end
		fade.Goal = if fade.Through then to else 0
		through += if fade.Through then 1 else 0
		inside += if fade.In then 1 else 0
		inWay += if fade.Path then 1 else 0
	end
	local stats = PropController.Stats
	stats.Round, stats.Through, stats.Inside, stats.Path = round, through, inside, inWay
end

-- A flying copy of a box the server took out, thrown from where the fish hit
local function throw(part: BasePart, at: Vector3, velocity: Vector3)
	local p = Config.Props
	local copy = part:Clone()
	CollectionService:RemoveTag(copy, TAG)
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.CastShadow = false
	copy.LocalTransparencyModifier = 0
	for _, child in copy:GetChildren() do
		if child:IsA("Decal") then
			child.LocalTransparencyModifier = 0
		end
	end
	local home = part.CFrame
	local outward = home.Position - at
	outward = if outward.Magnitude > 0.1 then outward.Unit else rng:NextUnitVector()
	local speed = velocity.Magnitude
	local way = if speed > 0.1 then velocity / speed else Vector3.zero
	table.insert(pieces, {
		Part = copy,
		At = home.Position,
		Turn = home.Rotation,
		Velocity = way * (speed * p.Throw * rng:NextNumber(0.5, 1))
			+ outward * (p.Scatter * rng:NextNumber(0.33, 1))
			+ Vector3.new(0, p.Pop * rng:NextNumber(), 0),
		Axis = rng:NextUnitVector(),
		Rate = math.rad(p.Spin) * rng:NextNumber(0.3, 1),
		Age = 0,
		Half = math.max(part.Size.X, part.Size.Y, part.Size.Z) / 2,
		See = 0,
	})
	local camera = workspace.CurrentCamera
	local holder = camera:FindFirstChild("PropDebris")
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = "PropDebris"
		holder.Parent = camera
	end
	copy.Parent = holder
	return copy
end

-- The boxes the server tagged: hidden at once, and thrown if the break is fresh and near enough to see. The push
-- (BreakAt, BreakVel, BreakT) is on the box's prop and is written before the tag, but it is another instance: a box
-- whose prop doesn't show a fresh break yet waits a few frames for it before it is taken for an old one.
local function takeOut()
	if #arrived == 0 then
		return
	end
	local p = Config.Props
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	local eye = workspace.CurrentCamera.CFrame.Position
	for i = #arrived, 1, -1 do
		local part = arrived[i].Part
		local model = part.Parent
		local done = true
		if model and CollectionService:HasTag(part, TAG) then
			if not out[part] then
				out[part] = true
				PropController.Stats.Out += 1
			end
			rising[part] = nil
			show(part, 1)
			local at = model:GetAttribute("BreakAt")
			local velocity = model:GetAttribute("BreakVel")
			local t = model:GetAttribute("BreakT")
			if
				typeof(at) == "Vector3"
				and typeof(velocity) == "Vector3"
				and type(t) == "number"
				and now - t <= FRESH
			then
				if #pieces < p.MaxDebris and (part.Position - eye).Magnitude <= p.DebrisRange then
					local copy = throw(part, at, velocity)
					if bubbled[model] ~= t then
						-- once for each hit of a prop: the bubbles and the crunch
						bubbled[model] = t
						if p.BreakBubbles > 0 then
							Fx.burst(at, p.BreakBubbles, 0, 8)
						end
						if p.BreakSound > 0 then
							local sound = Fx.sound("Rumble", copy)
							if sound then
								sound.Volume *= p.BreakSound
								sound.PlaybackSpeed = 0.75
							end
						end
					end
				end
			elseif clock - arrived[i].At < WAIT then
				done = false
			end
		end
		if done then
			arrived[i] = arrived[#arrived]
			arrived[#arrived] = nil
		end
	end
end

local function step(dt: number)
	local p = Config.Props
	local now = os.clock()
	takeOut()
	local body = where(dt)
	if now >= lookAt then
		lookAt = now + math.max(p.FadeEvery, 0.03)
		look(body)
	end
	judge(body)
	-- the props turning see-through and coming back: quickly for the one we are in
	local slow = Ease.alpha(math.max(p.FadeEase, 0.5), dt)
	local quick = Ease.alpha(math.max(p.TouchEase, p.FadeEase, 0.5), dt)
	local count, most = 0, 0
	for model, fade in fades do
		local to = fade.Now + (fade.Goal - fade.Now) * (if fade.In then quick else slow)
		if math.abs(fade.Goal - to) < SHOWN then
			to = fade.Goal
		end
		fade.Now = to
		if to ~= fade.Shown then
			fade.Shown = to
			for _, part in fade.Parts do
				if part.Parent == model and not out[part] and not rising[part] then
					show(part, to)
				end
			end
		end
		if to == 0 and fade.Goal == 0 then
			if fade.Seen ~= stamp then
				fades[model] = nil
			end
		else
			count += 1
			most = math.max(most, to)
		end
	end
	-- the boxes coming back
	local time = math.max(p.RebuildTime, 0.03)
	for part, rise in rising do
		if not part.Parent then
			rising[part] = nil
			continue
		end
		local u = math.clamp((now - rise.At) / time, 0, 1)
		show(part, math.max(1 - Ease.smoothstep(0, 1, u), fadeOf(part)))
		if u >= 1 then
			rising[part] = nil
		end
	end
	-- the flying copies: slowed by the water, sinking, turning, see-through while they are close to us or between
	-- the camera and us, then fading away
	local keep = math.exp(-math.max(p.Drag, 0) * dt)
	local life = p.Hang + math.max(p.FadeOut, 0.03)
	local eye = workspace.CurrentCamera.CFrame.Position
	local me = if body then body.At else eye
	local seeTo = if p.DebrisFar > 0 then math.clamp(p.FadeTo, 0, 1) else 0
	local seeNear = math.max(p.DebrisNear, 0)
	local seeFar = math.max(p.DebrisFar, seeNear + 0.5)
	local seen = 0
	for i = #pieces, 1, -1 do
		local piece = pieces[i]
		piece.Age += dt
		if piece.Age >= life or not piece.Part.Parent then
			piece.Part:Destroy()
			pieces[i] = pieces[#pieces]
			pieces[#pieces] = nil
			continue
		end
		piece.Velocity = piece.Velocity * keep - Vector3.new(0, p.Sink * dt, 0)
		piece.At += piece.Velocity * dt
		piece.Rate *= math.sqrt(keep)
		piece.Turn = CFrame.fromAxisAngle(piece.Axis, piece.Rate * dt) * piece.Turn
		piece.Part.CFrame = CFrame.new(piece.At) * piece.Turn
		local far = (piece.At - nearOn(eye, me, piece.At)).Magnitude - piece.Half
		local see = seeTo * Ease.smoothstep(seeFar, seeNear, far)
		piece.See += (see - piece.See) * quick
		seen = math.max(seen, piece.See)
		local gone = if piece.Age > p.Hang
			then Ease.smoothstep(0, 1, (piece.Age - p.Hang) / math.max(p.FadeOut, 0.03))
			else 0
		show(piece.Part, 1 - (1 - piece.See) * (1 - gone))
	end
	PropController.Stats.DebrisSeen = seen
	local stats = PropController.Stats
	stats.Fading = count
	stats.Faded = most
	stats.Flying = #pieces
end

-- A box of a prop, and not one of our own flying copies
local function ofProp(part: Instance): boolean
	local root = props()
	return root ~= nil and part:IsA("BasePart") and part.Parent ~= nil and part.Parent.Parent == root
end

local function tagged(part: Instance)
	if ofProp(part) then
		table.insert(arrived, { Part = part :: BasePart, At = os.clock() })
	end
end

-- The tag is gone: the server put the box back (it fades in), or the box itself left (this part of the map unloaded)
local function untagged(part: Instance)
	if not part:IsA("BasePart") or not out[part] then
		return
	end
	out[part] = nil
	PropController.Stats.Out -= 1
	if not ofProp(part) then
		return
	end
	local p = Config.Props
	local eye = workspace.CurrentCamera.CFrame.Position
	if (part.Position - eye).Magnitude > p.DebrisRange * 2 then
		show(part, fadeOf(part)) -- (too far to see it come back)
	else
		rising[part] = { At = os.clock() + rng:NextNumber(0, math.max(p.RebuildStagger, 0)) }
	end
end

function PropController.Init()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(tagged)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(untagged)
end

function PropController.Start()
	for _, part in CollectionService:GetTagged(TAG) do
		tagged(part)
	end
	RunService.RenderStepped:Connect(step)
end

return PropController
