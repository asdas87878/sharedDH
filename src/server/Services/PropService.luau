--!strict
-- Props that break (Config.Props; Hugo, 2026-11-11). The map's props are Models of loose boxes in
-- Workspace.ClaudeBlockout.Lane.Props (tools/map/greybox_luau.py: every box anchored, the solid ones CanCollide). A
-- fish that swims into one (RideService for a ridden fish, FishService for a wild one inside a big thing's circle)
-- calls PropService.hit: the boxes it touches are knocked loose, and so are the boxes of the same prop resting on them.
-- A loose box stops being solid, is thrown along the fish's way and hangs in the water; Props.Rebuild seconds after the
-- prop was last hit its boxes fly home and are solid again.
-- All of it is here on the server, moving the real parts (tweened), so every player sees the same prop and a player who
-- joins late sees it as it is. Breaking a prop gives nothing.
-- Players' characters don't collide with props (collision groups "Riders" and "Props"): a rider's body would otherwise
-- knock against the boxes in the moment before the server takes them out of the fish's way. What a prop stops is
-- decided by the riding code's rays (Lib/Course), which still see props.
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

type Loose = { Part: BasePart, Home: CFrame }
type Broken = { Loose: { Loose }, Token: number }

local PropService = {}

local rng = Random.new()
local folder: Instance? = nil
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.RespectCanCollide = true -- a loose box isn't solid, so it isn't found again
local broken: { [Instance]: Broken } = {}

-- The map's props folder, looked for when needed: the map can be rebuilt in Studio while the game runs
local function props(): Instance?
	if folder and folder.Parent then
		return folder
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local lane = blockout and blockout:FindFirstChild("Lane")
	folder = lane and lane:FindFirstChild("Props")
	if folder then
		overlap.FilterDescendantsInstances = { folder }
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = "Props"
			end
		end
	end
	return folder
end

-- A player's character passes through props (see the top of this file)
function PropService.passThrough(character: Model)
	local function mark(d: Instance)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Riders"
		end
	end
	for _, d in character:GetDescendants() do
		mark(d)
	end
	character.DescendantAdded:Connect(mark)
end

local function knock(b: Broken, part: BasePart, at: Vector3, way: Vector3)
	local p = Config.Props
	local home = part.CFrame
	table.insert(b.Loose, { Part = part, Home = home })
	part.CanCollide = false
	local out = home.Position - at
	out = if out.Magnitude > 0.1 then out.Unit else Vector3.yAxis
	local spin = math.rad(p.Spin)
	local goal = CFrame.new(
		home.Position
			+ way * (p.Push * rng:NextNumber(0.5, 1))
			+ out * (p.Scatter * rng:NextNumber(0.3, 1))
			- Vector3.new(0, p.Sink * rng:NextNumber(), 0)
	) * home.Rotation * CFrame.Angles(
		rng:NextNumber(-spin, spin),
		rng:NextNumber(-spin, spin),
		rng:NextNumber(-spin, spin)
	)
	local info = TweenInfo.new(math.max(p.KnockTime, 0.05), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(part, info, { CFrame = goal }):Play()
end

-- The prop builds itself back: its loose boxes fly home, a few at a time, and are solid again when they get there
local function rebuild(model: Instance, b: Broken)
	local p = Config.Props
	local batch = b.Loose
	b.Loose = {}
	if broken[model] == b then
		broken[model] = nil
	end
	local time = math.max(p.RebuildTime, 0.05)
	for _, loose in batch do
		if loose.Part.Parent then
			local info = TweenInfo.new(
				time,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out,
				0,
				false,
				rng:NextNumber(0, math.max(p.RebuildStagger, 0))
			)
			TweenService:Create(loose.Part, info, { CFrame = loose.Home }):Play()
		end
	end
	task.delay(time + math.max(p.RebuildStagger, 0) + 0.05, function()
		for _, loose in batch do
			if loose.Part.Parent then
				loose.Part.CFrame = loose.Home
				loose.Part.CanCollide = true
			end
		end
	end)
end

-- Something swam into the props at `at`, going `velocity`: the solid boxes within `reach` are knocked loose, with what
-- rests on them. Returns how many boxes came loose (0: no prop there).
function PropService.hit(at: Vector3, velocity: Vector3, reach: number): number
	local root = props()
	if not root then
		return 0
	end
	local p = Config.Props
	local touched = workspace:GetPartBoundsInRadius(at, reach, overlap)
	if #touched == 0 then
		return 0
	end
	local way = if velocity.Magnitude > 0.1 then velocity.Unit else Vector3.zero
	-- the lowest box touched of each prop: what is above it has lost its footing
	local lowest: { [Instance]: number } = {}
	local hit: { [Instance]: boolean } = {}
	for _, part in touched do
		local model = part.Parent
		if model and model.Parent == root then
			hit[part] = true
			lowest[model] = math.min(lowest[model] or math.huge, part.Position.Y)
		end
	end
	local count = 0
	for model, y in lowest do
		local b = broken[model]
		if not b then
			b = { Loose = {}, Token = 0 }
			broken[model] = b
		end
		local state = b :: Broken
		for _, part in model:GetChildren() do
			if count >= p.MaxLoose then
				break
			end
			if part:IsA("BasePart") and part.CanCollide then
				local off = part.Position - at
				local above = part.Position.Y > y and Vector3.new(off.X, 0, off.Z).Magnitude <= p.Topple
				if hit[part] or above then
					knock(state, part, at, way)
					count += 1
				end
			end
		end
		if #state.Loose == 0 then
			broken[model] = nil
		else
			-- the wait starts again with every hit
			state.Token += 1
			local token = state.Token
			task.delay(p.Rebuild, function()
				if broken[model] == state and state.Token == token then
					rebuild(model, state)
				end
			end)
		end
	end
	return count
end

-- The props folder (nil with no map), for rays that must tell a prop from the rest of the map
function PropService.folder(): Instance?
	return props()
end

function PropService.Init()
	for _, group in { "Props", "Riders" } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable("Props", "Riders", false)
end

function PropService.Start()
	props()
end

return PropService
