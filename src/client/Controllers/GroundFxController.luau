--!strict
-- The little effects on land (Hugo, 2026-11-20, task v1; numbers in Config.GroundFx):
--   the hop off the seahorse trainer: a puff of round bubbles and little gold diamonds from the seat (TrainerController
--   calls GroundFxController.hopOff on every machine when a ride's rider leaves; the spring's boing is its bounce);
--   a landing on the ground: a few round dust puffs rolling out over the ground, bigger and more after a bigger
--   drop (the flat white ring with the dark outline that ran out with them is gone: Hugo, 2026-11-22, task b3; he
--   keeps the dust). Every machine watches every
--   character near its camera (where each root is, frame to frame, and the ground under it), so everyone sees
--   everyone's. Nothing when the drop is under MinDrop (a curb, a stair), on the trainer, or under the sea.
-- Local parts only, under the camera (nothing replicates or collides), taken from a pool and put back. They move on
-- the trainer's clock (the workspace's "TrainerClock" in Studio, for captures; else os.clock()).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.UI.Kit)

local GroundFxController = {}

local AWAY = CFrame.new(0, -1e5, 0)
local PUFF_COLOUR = Color3.fromRGB(246, 250, 255)
local BUBBLE_COLOUR = Color3.fromRGB(190, 242, 255)

local function clock(): number
	if RunService:IsStudio() then
		local held = workspace:GetAttribute("TrainerClock")
		if type(held) == "number" then
			return held
		end
	end
	return os.clock()
end

-- ---------------------------------------------------------------- the pool
local folder: Folder? = nil
local function holder(): Folder
	local camera = workspace.CurrentCamera
	local f = folder
	if f and f.Parent == camera then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "GroundFx"
	made.Parent = camera
	folder = made
	return made
end

local free: { [string]: { Part } } = { Block = {}, Ball = {} }

local function take(shape: string): Part
	local list = free[shape]
	local p = table.remove(list)
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
		made.Shape = if shape == "Ball" then Enum.PartType.Ball else Enum.PartType.Block
		made.Parent = holder()
		p = made
	end
	local part = p :: Part
	part.Transparency = 0
	part.Material = Enum.Material.SmoothPlastic
	return part
end

local function give(part: Part, shape: string)
	part.CFrame = AWAY
	part.Transparency = 1
	if #free[shape] < 160 then
		table.insert(free[shape], part)
	else
		part:Destroy()
	end
end

-- ---------------------------------------------------------------- what is playing
type Bit = { Part: Part, Shape: string }
type Play = { At: number, Life: number, Bits: { Bit }, Step: (s: number) -> () }
local playing: { Play } = {}

local function start(life: number, bits: { Bit }, stepFn: (s: number) -> ())
	local play = { At = clock(), Life = life, Bits = bits, Step = stepFn }
	stepFn(0)
	table.insert(playing, play)
end

local function stepPlays()
	local now = clock()
	for i = #playing, 1, -1 do
		local play = playing[i]
		local s = (now - play.At) / play.Life
		if s >= 1 or s < -0.05 then
			for _, bit in play.Bits do
				give(bit.Part, bit.Shape)
			end
			table.remove(playing, i)
		else
			play.Step(math.max(s, 0))
		end
	end
end

local function easeOut(s: number): number
	return 1 - (1 - s) ^ 3
end

-- a size that pops up quickly, holds, and shrinks away at the end
local function popSize(s: number): number
	if s < 0.2 then
		return easeOut(s / 0.2)
	end
	return 1 - ((s - 0.2) / 0.8) ^ 2
end

-- ---------------------------------------------------------------- the hop off the trainer
-- A puff of bubbles and gold diamonds from `at` (the seat), short and small
function GroundFxController.hopOff(at: Vector3)
	local g = Config.GroundFx
	if g.On ~= 1 then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - at).Magnitude > g.Range then
		return
	end
	local bits: { Bit } = {}
	type Fly = { Part: Part, Dir: Vector3, Size: number, Rise: number, Spin: number, Star: boolean }
	local flies: { Fly } = {}
	local rng = Random.new()
	local function add(star: boolean)
		local shape = if star then "Block" else "Ball"
		local part = take(shape)
		part.Color = if star then Kit.Sun else BUBBLE_COLOUR
		part.Material = if star then Enum.Material.Neon else Enum.Material.SmoothPlastic
		table.insert(bits, { Part = part, Shape = shape })
		local turn = rng:NextNumber(0, math.pi * 2)
		local up = rng:NextNumber(0.15, 0.7)
		local dir = Vector3.new(math.cos(turn), up, math.sin(turn)).Unit * g.OffReach * rng:NextNumber(0.6, 1.15)
		table.insert(flies, {
			Part = part,
			Dir = dir,
			Size = if star then rng:NextNumber(0.3, 0.45) else rng:NextNumber(0.3, 0.6),
			Rise = if star then 0.4 else rng:NextNumber(0.8, 1.6),
			Spin = rng:NextNumber(-8, 8),
			Star = star,
		})
	end
	for _ = 1, math.max(0, math.floor(g.OffBubbles)) do
		add(false)
	end
	for _ = 1, math.max(0, math.floor(g.OffSparkles)) do
		add(true)
	end
	start(math.max(g.OffTime, 0.05), bits, function(s: number)
		local out = easeOut(s)
		local size = popSize(s)
		for _, f in flies do
			local p = at + f.Dir * out + Vector3.new(0, f.Rise * s, 0)
			local d = math.max(f.Size * size, 0.05)
			if f.Star then
				f.Part.Size = Vector3.new(d, d, d)
				f.Part.CFrame = CFrame.new(p) * CFrame.Angles(math.rad(45), f.Spin * s, math.rad(45))
			else
				f.Part.Size = Vector3.new(d, d, d)
				f.Part.CFrame = CFrame.new(p)
				f.Part.Transparency = 0.15 + 0.5 * s
			end
		end
	end)
end

-- ---------------------------------------------------------------- the landing dust
local function basisOn(at: Vector3, normal: Vector3): CFrame
	local up = if normal.Magnitude > 0.1 then normal.Unit else Vector3.yAxis
	local side = up:Cross(Vector3.zAxis)
	if side.Magnitude < 0.1 then
		side = up:Cross(Vector3.xAxis)
	end
	side = side.Unit
	return CFrame.fromMatrix(at, side, up)
end

-- Dust on the ground at `at` (its face `normal`), sized by the drop (studs). The name is from the ring it once drew
function GroundFxController.ring(at: Vector3, normal: Vector3, drop: number)
	local g = Config.GroundFx
	if g.On ~= 1 then
		return
	end
	local big = math.clamp((drop - g.MinDrop) / math.max(g.FullDrop - g.MinDrop, 0.1), 0, 1)
	local radius = g.Radius + (g.RadiusMax - g.Radius) * big
	local base = basisOn(at, normal)
	local bits: { Bit } = {}
	-- the puffs: round, white, rolling out over the ground, popping up and shrinking away
	type Puff = { Part: Part, Turn: number, Size: number, Reach: number }
	local puffs: { Puff } = {}
	local rng = Random.new()
	local count = math.max(0, math.floor(g.Puffs * (1 + big) + 0.5))
	for i = 1, count do
		local part = take("Ball")
		part.Color = PUFF_COLOUR
		table.insert(bits, { Part = part, Shape = "Ball" })
		table.insert(puffs, {
			Part = part,
			Turn = (i / math.max(count, 1)) * math.pi * 2 + rng:NextNumber(-0.4, 0.4),
			Size = g.PuffSize * (1 + 0.8 * big) * rng:NextNumber(0.75, 1.15),
			Reach = rng:NextNumber(0.55, 0.85),
		})
	end
	local life = math.max(g.Time, 0.05)
	-- (the same length and pace as when the ring ran with them: Time is the ring's old life, the puffs a little longer)
	start(life * 1.25, bits, function(t: number)
		local u = math.min(t * 1.05, 1)
		for _, p in puffs do
			local d = math.max(p.Size * popSize(u), 0.05)
			local out = radius * p.Reach * (0.3 + 0.7 * easeOut(u))
			p.Part.Size = Vector3.new(d, d, d)
			p.Part.CFrame = base * CFrame.Angles(0, p.Turn, 0) * CFrame.new(0, d * 0.4 + 0.4 * u, -out)
		end
	end)
end

-- ---------------------------------------------------------------- watching the landings
type Watch = { Air: boolean, Top: number, Last: Vector3, At: number }
local watches: { [BasePart]: Watch } = setmetatable({}, { __mode = "k" }) :: any
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
params.IgnoreWater = true

local function underTrainer(hit: Instance): boolean
	return hit:FindFirstAncestor("TrainerRide") ~= nil or hit:FindFirstAncestor("TrainerSpring") ~= nil
end

local function watchAll()
	local g = Config.GroundFx
	local camera = workspace.CurrentCamera
	if g.On ~= 1 or not camera then
		return
	end
	local eye = camera.CFrame.Position
	local skip: { Instance } = { camera }
	local fish = workspace:FindFirstChild("Fish")
	if fish then
		table.insert(skip, fish)
	end
	local roots: { { Root: BasePart, Humanoid: Humanoid } } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(skip, character)
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				table.insert(roots, { Root = root, Humanoid = humanoid })
			end
		end
	end
	params.FilterDescendantsInstances = skip
	local surface = Config.Depth.SurfaceY
	local now = os.clock()
	for _, it in roots do
		local root = it.Root
		local at = root.Position
		if (at - eye).Magnitude > g.Range then
			watches[root] = nil
			continue
		end
		local w = watches[root]
		if not w or (at - w.Last).Magnitude > 40 then
			-- (new, or put somewhere else at once: a respawn, sent home)
			watches[root] = { Air = false, Top = at.Y, Last = at, At = -math.huge }
			continue
		end
		w.Last = at
		local stand = it.Humanoid.HipHeight + root.Size.Y / 2
		local hit = workspace:Raycast(at, Vector3.new(0, -(stand + 0.8), 0), params)
		if not hit then
			if not w.Air then
				w.Air = true
				w.Top = at.Y
			else
				w.Top = math.max(w.Top, at.Y)
			end
			continue
		end
		if w.Air then
			w.Air = false
			local drop = w.Top - at.Y
			if
				drop >= g.MinDrop
				and hit.Position.Y > surface - 0.5
				and not underTrainer(hit.Instance)
				and now - w.At > 0.25
			then
				w.At = now
				GroundFxController.ring(hit.Position, hit.Normal, drop)
			end
		end
		w.Top = at.Y
	end
end

function GroundFxController.Start()
	RunService.Heartbeat:Connect(function()
		watchAll()
		stepPlays()
	end)
end

return GroundFxController
