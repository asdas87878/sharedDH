--!strict
-- Props that break (Config.Props; Hugo, 2026-11-13, in place of 2026-11-11's). The map's props are Models of loose
-- boxes in Workspace.ClaudeBlockout.Lane.Props (tools/map/greybox_luau.py: every box anchored). Only some fish break
-- them (Config.breaks: a Tank, a Breaker, a giant); every other fish and every rider in the hop goes straight through,
-- which costs this file nothing: nothing of the game's is stopped by a prop any more.
-- A fish that breaks props and swims into one (RideService for a ridden fish, FishService for a wild one inside a big
-- thing's circle) calls PropService.hit: the boxes it touches are out, and so are the boxes of the same prop resting
-- on them. The boxes still in place stay.
-- WHAT THE SERVER KEEPS is only which boxes are out and when the prop is back:
--   a box that is out carries the CollectionService tag "PropOut" (PropService.Tag) and isn't solid;
--   its prop (the Model) carries BreakAt (where it was hit), BreakVel (the fish's velocity) and BreakT (the server's
--   clock, workspace:GetServerTimeNow()), written before the tags of that hit;
--   a prop that builds itself back loses the tags and gets RebuildT (the server's clock).
-- The boxes themselves never move here. Every player's own machine hides the tagged boxes, throws copies of them
-- from BreakAt along BreakVel, fades those out, and fades the real ones back in when the tag goes
-- (client/Controllers/PropController). A player who joins late, or whose machine loads that part of the map later,
-- finds the tags and sees the prop as it is. Nothing flying is solid or seen by any ray, so it can't block, trap or
-- slow anyone.
-- A broken prop builds itself back once no player has been within Props.RegenRadius of it for Props.RegenDelay
-- seconds: never in front of a rider.
-- Players' characters don't collide with props (collision groups "Riders" and "Props"), and a character that is
-- riding a fish collides with nothing (group "Riding", PropService.riding below).
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

-- a prop with boxes out: the boxes, its middle, and since when no player has been near it (nil: one is)
type Broken = { Out: { BasePart }, Centre: Vector3, ClearSince: number? }

local PropService = {}

PropService.Tag = "PropOut"

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
			d.CollisionGroup = if character:GetAttribute("Riding") then "Riding" else "Riders"
		end
	end
	for _, d in character:GetDescendants() do
		mark(d)
	end
	character.DescendantAdded:Connect(mark)
end

-- On a fish, a rider's body touches nothing at all (group "Riding"); off it, it is solid to the map again. The fish
-- is kept in open water by its own steering's rays, from the fish's middle (Lib/Course). The rider sits above that,
-- and their body caught on what those rays pass under, the lip of the ground on top of a low wall and the end of the
-- next slab along it: the fish was held still there with nothing in its way (grey-box 15, 2026-11-13: measured at
-- 1 stud a second, 30 degrees into a terrace wall 2,750 studs down; docs/playtests/2026-11-13-wall-hop.md).
function PropService.riding(character: Model, on: boolean)
	if (character:GetAttribute("Riding") == true) == on then
		return
	end
	character:SetAttribute("Riding", if on then true else nil)
	local group = if on then "Riding" else "Riders"
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end

-- The prop builds itself back: its boxes are solid again and lose their tag (each machine fades them in)
local function rebuild(model: Instance, b: Broken)
	broken[model] = nil
	if not model.Parent then
		return
	end
	for _, part in b.Out do
		if part.Parent then
			part.CanCollide = true
			CollectionService:RemoveTag(part, PropService.Tag)
		end
	end
	model:SetAttribute("RebuildT", workspace:GetServerTimeNow())
end

-- Something that breaks props swam into them at `at`, going `velocity`: the solid boxes within `reach` are out, with
-- what rests on them. Returns how many boxes went (0: no prop there).
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
		local out: { BasePart } = {}
		for _, part in model:GetChildren() do
			if count + #out >= p.MaxLoose then
				break
			end
			if part:IsA("BasePart") and part.CanCollide then
				local off = part.Position - at
				local above = part.Position.Y > y and Vector3.new(off.X, 0, off.Z).Magnitude <= p.Topple
				if hit[part] or above then
					table.insert(out, part)
				end
			end
		end
		if #out > 0 then
			local b = broken[model]
			if not b then
				local centre = if model:IsA("Model") then model:GetBoundingBox().Position else at
				b = { Out = {}, Centre = centre, ClearSince = nil }
				broken[model] = b
			end
			local state = b :: Broken
			state.ClearSince = nil -- (whoever broke it is here: the wait starts again)
			-- the push first, then the tags: a machine that sees a box tagged reads how to throw it from its prop
			model:SetAttribute("BreakAt", at)
			model:SetAttribute("BreakVel", velocity)
			model:SetAttribute("BreakT", workspace:GetServerTimeNow())
			for _, part in out do
				part.CanCollide = false -- (so it isn't found, and broken, again)
				CollectionService:AddTag(part, PropService.Tag)
				table.insert(state.Out, part)
			end
			count += #out
		end
	end
	return count
end

-- The broken props, looked at a couple of times a second: one that no player has been near for long enough builds
-- itself back
local function regenerate()
	local p = Config.Props
	local now = os.clock()
	local where: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(where, root.Position)
		end
	end
	for model, b in broken do
		if not model.Parent then
			broken[model] = nil -- (the map was built again under us)
			continue
		end
		local near = false
		for _, at in where do
			if (at - b.Centre).Magnitude <= p.RegenRadius then
				near = true
				break
			end
		end
		if near then
			b.ClearSince = nil
		elseif not b.ClearSince then
			b.ClearSince = now
		elseif now - b.ClearSince >= p.RegenDelay then
			rebuild(model, b)
		end
	end
end

-- How many props are broken now (for tests)
function PropService.brokenCount(): number
	local n = 0
	for _ in broken do
		n += 1
	end
	return n
end

-- The props folder (nil with no map), for rays that must tell a prop from the rest of the map
function PropService.folder(): Instance?
	return props()
end

function PropService.Init()
	for _, group in { "Props", "Riders", "Riding" } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable("Props", "Riders", false)
	for _, group in { "Default", "Props", "Riders", "Riding" } do
		PhysicsService:CollisionGroupSetCollidable("Riding", group, false)
	end
end

function PropService.Start()
	props()
	while true do
		task.wait(math.max(Config.Props.RegenEvery, 0.1))
		regenerate()
	end
end

return PropService
