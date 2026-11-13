--!strict
-- The map's props on our own screen (Config.Props; Hugo, 2026-11-13). Nothing here decides anything: the server says
-- which boxes of a prop are out and when it is back (PropService: the tag "PropOut" on each box that is out; BreakAt,
-- BreakVel, BreakT and RebuildT on the prop's Model). This file is what that looks like, three things:
--   THE APPROACH FADE. Props near us turn see-through, smoothly with distance, down to Props.FadeTo at FadeNear, and
--   come back as smoothly when we leave. Only when we would go straight through them: on a fish that breaks props
--   they stay solid-looking, something to smash (Props.FadeForBreakers = 1 fades them for it too). It is by OUR
--   distance and on our screen only, so another player sees the same prop by their own.
--   THE BREAK. A box the server takes out is hidden, and a copy of it is thrown from where the fish hit, along the
--   fish's way and with its speed, turning, slowing in the water, sinking, then fading away. The copies are ours
--   alone (under the camera), not solid and not seen by any ray: they can't block, trap or slow anyone.
--   THE REBUILD. When the server puts the boxes back (no player near for a while), they fade in, a few at a time.
-- How it stays cheap: the props near us are found by one spatial query every Props.FadeEvery seconds (the engine's,
-- over the props folder only), never by walking all the props; each frame touches only the props that are fading,
-- the boxes coming back and the flying copies (Props.MaxDebris at most). A box is shown or hidden with
-- LocalTransparencyModifier, on it and on its pictures (Textures and Decals), so its own Transparency, its glow
-- (Neon) and what the server replicates are never written.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Fx = require(script.Parent.Parent.Lib.Fx)
local State = require(script.Parent.Parent.Lib.State)

local PropController = {}

local TAG = "PropOut"
local WAIT = 0.25 -- a tagged box waits this long for its prop's push to arrive before it is given up as an old break
local FRESH = 1.5 -- a break this many seconds old or less is thrown; an older one (we joined, or loaded it, later) is just gone
local SHOWN = 0.004 -- a fade nearer to where it is going than this is there

-- a prop that is fading for us: how see-through it is now, where that is going, and its boxes
type Fade = { Now: number, Goal: number, Parts: { BasePart }, Seen: number, Shown: number }
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

-- Counts for tests and the sandbox (how many props are fading, boxes are out, copies are flying)
PropController.Stats = { Fading = 0, Out = 0, Flying = 0, Nearest = math.huge, Faded = 0 }

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

-- Whether props should fade for us now: when we would go straight through them. Not on a fish that breaks them
-- (unless Props.FadeForBreakers), and not at the dock.
local function fading(): boolean
	local p = Config.Props
	if p.FadeTo <= 0 or not State.inWater() then
		return false
	end
	local fish = State.Fish
	if State.Mode == "Riding" and fish and p.FadeForBreakers == 0 then
		local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
		if kind and Config.breaks(kind) then
			return false
		end
	end
	return true
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

local function boxesOf(model: Instance): { BasePart }
	local list: { BasePart } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(list, child)
		end
	end
	return list
end

-- The props near us, and how see-through each should be: one spatial query, a few times a second
local function look()
	local p = Config.Props
	stamp += 1
	local root = props()
	local _, body = State.character()
	local nearestOfAll = math.huge
	if root and body and fading() then
		local at = body.Position
		local velocity = body.AssemblyLinearVelocity
		-- (where we will be in FadeLead seconds counts as well, so the props ahead of a fast fish fade in time)
		local ahead = at + velocity * math.max(p.FadeLead, 0)
		local far = math.max(p.FadeFar, 1)
		local near = math.clamp(p.FadeNear, 0, far - 0.5)
		local nearest: { [Instance]: number } = {}
		for _, part in workspace:GetPartBoundsInRadius(at:Lerp(ahead, 0.5), far + (ahead - at).Magnitude / 2, overlap) do
			local model = part.Parent
			if model and model.Parent == root then
				local d = math.min(gap(part, at), gap(part, ahead))
				if d < (nearest[model] or far) then
					nearest[model] = d
				end
			end
		end
		for model, d in nearest do
			nearestOfAll = math.min(nearestOfAll, d)
			local fade = fades[model]
			if not fade then
				fade = { Now = 0, Goal = 0, Parts = {}, Seen = 0, Shown = -1 }
				fades[model] = fade
			end
			local f = fade :: Fade
			f.Goal = math.clamp(p.FadeTo, 0, 1) * Ease.smoothstep(0, 1, 1 - (d - near) / (far - near))
			f.Seen = stamp
			f.Parts = boxesOf(model) -- (again each look: a prop's boxes can load in one after another)
			f.Shown = -1
		end
	end
	for _, fade in fades do
		if fade.Seen ~= stamp then
			fade.Goal = 0
		end
	end
	PropController.Stats.Nearest = nearestOfAll
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
	if now >= lookAt then
		lookAt = now + math.max(p.FadeEvery, 0.03)
		look()
	end
	-- the props fading for us
	local alpha = Ease.alpha(math.max(p.FadeEase, 0.5), dt)
	local count, most = 0, 0
	for model, fade in fades do
		local to = fade.Now + (fade.Goal - fade.Now) * alpha
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
			fades[model] = nil
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
	-- the flying copies: slowed by the water, sinking, turning, then fading away
	local keep = math.exp(-math.max(p.Drag, 0) * dt)
	local life = p.Hang + math.max(p.FadeOut, 0.03)
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
		if piece.Age > p.Hang then
			show(piece.Part, Ease.smoothstep(0, 1, (piece.Age - p.Hang) / math.max(p.FadeOut, 0.03)))
		end
	end
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
