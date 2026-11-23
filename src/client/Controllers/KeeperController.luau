--!strict
-- The shopkeepers behind the hub's stands and the few props round each (Hugo, 2026-11-23: "Add specialised characters
-- behind every stand ... a looping idle animation where they stand while bobbing up and down a little smoothly then
-- doing something for a second, they should also follow the player when the player gets close, smoothly starting to
-- look and follow him ... add small same styled fitting props around the stands"). What they are is Shared/Keepers:
-- tables of plain parts, and the sums that pose them. This builds them on this machine only, so nothing is added to
-- the place and nothing is uploaded, and they touch nothing (no collision, no query, no touch, no shadow).
--   Where: measured from each stand as it is in the place (Dock.Stations.<name>: its floor Ring and its CounterTop,
--     or the Fuse machine's Core), never from the hub kit's numbers: the Fuse machine was moved by hand. A keeper
--     faces its ring, and stands on the highest solid piece of its station under its feet (the machine's base).
--     They are kept in their own folder in the workspace, NOT in the stations (other code measures those).
--   The idle: the upper body bobs, a few joints sway, and every few seconds (each keeper on its own timer) it does
--     its one-second action (Keepers: Bob, Sway, Action).
--   The look ("follow the player"): the head and the upper body turn to the nearest player's head inside Look.Near,
--     eased in and out (a spring), held to Look.Body, Head, Up and Down so no neck breaks, and go back to the idle
--     when the player leaves (Look.Far) or goes round behind (Look.RearOut). A keeper never leaves its counter.
--   The stands are looked at once a second: a keeper is made when its stand is there (it may stream in late, piece
--     by piece), made again when the stand's measure changes, and taken away with the stand.
--   Cost: 222 plain parts for all four (131 of them move, with one BulkMoveTo a keeper a frame). Past Look.Animate
--     from the camera a keeper is left still, past Look.Hide it is taken out of the world.
--   Off: SHOW false here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Keepers = require(ReplicatedStorage.Shared.Keepers)

local KeeperController = {}

local SHOW = true -- false: no keepers and no props
local FOLDER = "Keepers" -- their folder in the workspace
local MATERIAL = Enum.Material.Plastic -- the hub's
local STEP = 0.1 -- seconds: a frame longer than this (a hitch) counts as this, so no spring jumps
local BACK = 0.95 -- a hidden keeper comes back inside this share of Look.Hide (so it does not flicker at the edge)

local Look = Keepers.Look

type Stand = {
	Station: Instance,
	Space: CFrame, -- the stand's own space in the world
	Scale: number,
	Lift: number, -- the keeper's feet over the floor, studs
	Stud: string, -- the stud picture: the stand's own, or the map's
	Key: string, -- all of the above as one word: a keeper is made again when it changes
}

type Shown = {
	Keeper: Keepers.Keeper,
	Stand: Stand,
	Model: Model,
	Root: CFrame, -- the keeper's own space in the world
	Neck: Vector3, -- where its head turns, in its own space
	Parts: { BasePart }, -- the parts that move
	JointOf: { string }, -- each one's joint
	Offsets: { CFrame }, -- each one against its joint
	CFrames: { CFrame }, -- where each goes this frame
	Anim: Keepers.Anim,
	Joints: { [string]: CFrame },
	World: { [string]: CFrame },
	Clock: number, -- seconds of idle
	Next: number, -- the Clock at which its next action starts
	Target: Player?, -- who it looks at
	Yaw: number, -- the look now, degrees
	Pitch: number,
	YawSpeed: number,
	PitchSpeed: number,
	Awake: boolean, -- near enough to move
	Hidden: boolean, -- out of the world
}

local shown: { [string]: Shown } = {} -- by the keeper's Id
local folder: Folder? = nil
local random = Random.new()
local since = 0 -- seconds since the stands were last looked at

-- The stand (nil: not in the place, or not streamed in yet)
local function stationOf(name: string): Instance?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local stations = dock and dock:FindFirstChild("Stations")
	return stations and stations:FindFirstChild(name)
end

-- Half of a part's height along the world's up
local function tall(part: BasePart): number
	local cf, size = part.CFrame, part.Size
	return (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z)
		/ 2
end

-- A keeper's stand as it is now. Nil while the pieces it is measured from are not there.
local function measure(keeper: Keepers.Keeper): Stand?
	local station = stationOf(keeper.Station)
	if not station then
		return nil
	end
	local ring: Instance? = station:FindFirstChild("Ring")
	if not ring and station:IsA("Model") then
		ring = station.PrimaryPart
	end
	local anchor = station:FindFirstChild(keeper.Stand, true)
	if not (ring and ring:IsA("BasePart") and anchor and anchor:IsA("BasePart")) then
		return nil
	end
	local floor = ring.Position.Y - tall(ring)
	local space = Keepers.standSpace(anchor.Position, ring.Position, floor)
	if not space then
		return nil
	end
	-- its size: drawn for a counter Look.CounterTall high, or for the machine's ring Look.CoreAhead from its core
	local scale: number
	if keeper.Stand == "Core" then
		local ahead = ring.Position - anchor.Position
		scale = Vector3.new(ahead.X, 0, ahead.Z).Magnitude / Look.CoreAhead
	else
		scale = (anchor.Position.Y + tall(anchor) - floor) / Look.CounterTall
	end
	scale = math.clamp(scale, Look.Least, Look.Most)
	-- what it stands on: the highest solid, level piece of the station under its feet (the floor: 0), and the
	-- stand's own stud picture
	local spot = space * Vector3.new(keeper.At[1] * scale, 0, keeper.At[2] * scale)
	local lift = 0
	local stud = Look.Stud
	for _, d in station:GetDescendants() do
		if d:IsA("BasePart") then
			if d.CanCollide and d.Transparency < 1 and math.abs(d.CFrame.UpVector.Y) >= 0.99 then
				local at = d.CFrame:PointToObjectSpace(spot)
				if math.abs(at.X) <= d.Size.X / 2 and math.abs(at.Z) <= d.Size.Z / 2 then
					local top = d.Position.Y + d.Size.Y / 2 - floor
					if top > lift and top <= Look.Reach * scale then
						lift = top
					end
				end
			end
		elseif d:IsA("Texture") and d.Name == "Studs" and d.Texture ~= "" then
			stud = d.Texture
		end
	end
	local at, ahead = space.Position, space.ZVector
	return {
		Station = station,
		Space = space,
		Scale = scale,
		Lift = lift,
		Stud = stud,
		Key = string.format(
			"%.2f %.2f %.2f %.3f %.3f %.3f %.2f %s",
			at.X,
			at.Y,
			at.Z,
			ahead.X,
			ahead.Z,
			scale,
			lift,
			stud
		),
	}
end

-- One plain part of a keeper or a prop: its shape, size (studs), colour (a name in Keepers.Colours) and options
local function make(name: string, shape: string, size: Vector3, colour: string, options: any, stud: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = if shape == "Ball"
		then Enum.PartType.Ball
		elseif shape == "Cylinder" then Enum.PartType.Cylinder
		else Enum.PartType.Block
	part.Size = size
	local rgb = Keepers.Colours[colour]
	part.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	part.Material = if options and options.Mat == "Neon" then Enum.Material.Neon else MATERIAL
	part.Transparency = if options and options.See then options.See else 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	if options and options.Stud and stud ~= "" then -- on its top only, as the hub's small blocks have it
		local texture = Instance.new("Texture")
		texture.Name = "Studs"
		texture.Texture = stud
		texture.Face = Enum.NormalId.Top
		texture.StudsPerTileU, texture.StudsPerTileV = 16, 16
		texture.OffsetStudsU = 8
		texture.Parent = part
	end
	if options and options.Light then
		local light = Instance.new("PointLight")
		light.Range = options.Light[1]
		light.Brightness = options.Light[2]
		light.Color = part.Color
		light.Shadows = false
		light.Parent = part
	end
	return part
end

-- When its next action starts, from now
local function nextAction(keeper: Keepers.Keeper, clock: number): number
	local every = keeper.Action.Every
	return clock + random:NextNumber(every[1], every[2])
end

-- Makes a keeper and its props at its stand, at rest. It is whole before it is put in the world.
local function build(keeper: Keepers.Keeper, stand: Stand): Shown
	local scale = stand.Scale
	local root = stand.Space * CFrame.new(keeper.At[1] * scale, stand.Lift, keeper.At[2] * scale)
	local model = Instance.new("Model")
	model.Name = keeper.Id
	local joints = Keepers.joints(keeper, scale, nil, 0, 0, 0)
	local parts: { BasePart }, jointOf: { string }, offsets: { CFrame }, cframes: { CFrame } = {}, {}, {}, {}
	for _, row in keeper.Parts do
		local joint: string = row[1]
		local part = make(joint, row[2], Vector3.new(row[3], row[4], row[5]) * scale, row[12], row[13], stand.Stud)
		local offset = Keepers.offset(keeper, row, scale)
		part.CFrame = root * joints[joint] * offset
		part.Parent = model
		if joint ~= "Root" then -- the rest never move
			table.insert(parts, part)
			table.insert(jointOf, joint)
			table.insert(offsets, offset)
			table.insert(cframes, part.CFrame)
		end
	end
	for _, row in keeper.Props do
		local part = make("Prop", row[1], Vector3.new(row[2], row[3], row[4]) * scale, row[11], row[12], stand.Stud)
		part.CFrame = stand.Space * Keepers.propAt(row, scale)
		part.Parent = model
	end
	local clock = random:NextNumber(0, 10) -- so the four do not bob as one
	model.Parent = folder
	return {
		Keeper = keeper,
		Stand = stand,
		Model = model,
		Root = root,
		Neck = Keepers.pivots(keeper).Head * scale,
		Parts = parts,
		JointOf = jointOf,
		Offsets = offsets,
		CFrames = cframes,
		Anim = {},
		Joints = joints,
		World = {},
		Clock = clock,
		Next = nextAction(keeper, clock),
		Target = nil,
		Yaw = 0,
		Pitch = 0,
		YawSpeed = 0,
		PitchSpeed = 0,
		Awake = false,
		Hidden = false,
	}
end

-- Looks at every stand: makes, makes again or takes away its keeper
local function look()
	for _, keeper in Keepers.List do
		local now = shown[keeper.Id]
		local stand = measure(keeper)
		if not stand then
			if now then
				now.Model:Destroy()
				shown[keeper.Id] = nil
			end
		elseif not now or now.Stand.Station ~= stand.Station or now.Stand.Key ~= stand.Key then
			if now then
				now.Model:Destroy()
			end
			shown[keeper.Id] = build(keeper, stand)
		end
	end
end

-- A value eased towards its goal, in and out (a critically damped spring): the value and its speed after dt
local function damp(now: number, goal: number, speed: number, time: number, dt: number): (number, number)
	local omega = 2 / time
	local x = omega * dt
	local decay = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
	local change = now - goal
	local temp = (speed + omega * change) * dt
	return goal + (change + temp) * decay, (speed - omega * temp) * decay
end

-- Where a player's head is from the keeper's neck, in the keeper's own space at rest (so the keeper's own turn and
-- bob never feed back into what it aims at). Nil: no character
local function headFrom(s: Shown, player: Player): Vector3?
	local character = player.Character
	local head = character and (character:FindFirstChild("Head") or character.PrimaryPart)
	if not (head and head:IsA("BasePart")) then
		return nil
	end
	return s.Root:PointToObjectSpace(head.Position) - s.Neck
end

-- Who the keeper looks at now, and where their head is from its neck. The one it looks at is kept until they are
-- past Look.Far or round behind it (Look.RearOut), or another player is nearer by Look.Switch; a new one has to be
-- inside Look.Near and in front (Look.RearIn)
local function target(s: Shown): Vector3?
	local kept: Vector3?, keptFar = nil, math.huge
	local best: Player?, bestAt: Vector3?, bestFar = nil, nil, math.huge
	for _, player in Players:GetPlayers() do
		local at = headFrom(s, player)
		if at then
			local far = at.Magnitude
			local round = math.abs(math.deg(math.atan2(at.X, at.Z)))
			if player == s.Target and far <= Look.Far and round <= Look.RearOut then
				kept, keptFar = at, far
			end
			if far <= Look.Near and round <= Look.RearIn and far < bestFar then
				best, bestAt, bestFar = player, at, far
			end
		end
	end
	if kept and not (best and bestFar + Look.Switch < keptFar) then
		return kept
	end
	s.Target = best
	return bestAt
end

-- One frame of a keeper that is near enough to move: its idle, its action, its look
local function animate(s: Shown, dt: number)
	local keeper = s.Keeper
	s.Clock += dt
	local action: number? = nil
	if s.Clock >= s.Next then
		local through = (s.Clock - s.Next) / keeper.Action.Time
		if through < 1 then
			action = through
		else
			s.Next = nextAction(keeper, s.Clock)
		end
	end
	local yaw, pitch = 0, 0
	local at = target(s)
	if at then
		yaw, pitch = Keepers.aim(at)
		yaw = math.clamp(yaw, -(Look.Body + Look.Head), Look.Body + Look.Head)
		pitch = math.clamp(pitch, -Look.Up, Look.Down)
	end
	s.Yaw, s.YawSpeed = damp(s.Yaw, yaw, s.YawSpeed, Look.Time, dt)
	s.Pitch, s.PitchSpeed = damp(s.Pitch, pitch, s.PitchSpeed, Look.Time, dt)
	local body, head, tip = Keepers.lookSplit(s.Yaw, s.Pitch)
	local anim = Keepers.anim(keeper, s.Clock, action, s.Anim)
	local joints = Keepers.joints(keeper, s.Stand.Scale, anim, body, head, tip, s.Joints)
	local world = s.World
	for name, cf in joints do
		world[name] = s.Root * cf
	end
	local cframes, jointOf, offsets = s.CFrames, s.JointOf, s.Offsets
	for i = 1, #cframes do
		cframes[i] = world[jointOf[i]] * offsets[i]
	end
	workspace:BulkMoveTo(s.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function step(dt: number)
	dt = math.min(dt, STEP)
	since += dt
	if since >= Look.Every then
		since = 0
		look()
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	for _, s in shown do
		local far = (eye - s.Root.Position).Magnitude
		if s.Hidden then
			if far < Look.Hide * BACK then
				s.Hidden = false
				s.Model.Parent = folder
			end
		elseif far > Look.Hide then
			s.Hidden = true
			s.Awake = false
			s.Model.Parent = nil
		end
		if not s.Hidden and far <= Look.Animate then
			if not s.Awake then -- back in sight: a fresh look and a fresh wait, nothing carried over
				s.Awake = true
				s.Target = nil
				s.YawSpeed, s.PitchSpeed = 0, 0
				s.Next = nextAction(s.Keeper, s.Clock)
			end
			animate(s, dt)
		else
			s.Awake = false
		end
	end
end

function KeeperController.Start()
	if not SHOW then
		return
	end
	local made = Instance.new("Folder")
	made.Name = FOLDER
	made.Parent = workspace
	folder = made
	since = Look.Every -- the stands are looked at on the first frame
	RunService.RenderStepped:Connect(step)
end

return KeeperController
