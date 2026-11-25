--!strict
-- The worn saddles, on every player's own machine (NULLROOM task s2; docs/design/saddles.md; Config.Saddles). A player's
-- attribute Saddle (the land whose saddle they wear, IndexService's; 0: none) is all that is sent; what it looks like and
-- how it fits is Shared/Saddles. It is on whatever they ride: a wild fish (its Rider attribute), the ride fish on land
-- (workspace.LandFish, LandRider), a fish in the tank (TankRider), a submarine's fish (a wild one).
--   Where: the parts are welded to the fish's part the fit names, at the fish's BACK (the model's own seat point, not the
--   Saddle attachment, which stands higher over a tank fish's back). They are in workspace.Saddles, never in the fish, so
--   nothing that goes over a fish's parts (fades, colliders, the angry pulse, variants, portraits) finds them. They weigh
--   nothing and nothing can touch, hit or find them; the seat, the rider and the hit boxes are as without one.
--   When: made a few parts a frame (PartsAFrame), hidden, from the moment the server grants the fish (Reserved, the
--   pull-in), and shown as the rider lands; off as they leave it. The parts are kept for the next one (Spare).
--   A fish faded or hidden on this machine (arriving, dying, under the submarine's hull) has its saddle fade with it.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Saddles = require(ReplicatedStorage.Shared.Saddles)

local SaddleController = {}

type Held = { Part: Part, Weld: Weld, Shape: string }
type Worn = {
	Fish: Model,
	Key: string,
	Kind: string,
	Size: string,
	List: { Saddles.Part },
	Joint: BasePart,
	Offset: CFrame, -- the back point, from the joint's part
	Made: { Held },
	Riding: boolean, -- the rider is on it (else it is only promised to them)
	Player: Player,
	See: number, -- what its parts' LocalTransparencyModifier is now
}

local SHAPES = {
	box = Enum.PartType.Block,
	wedge = Enum.PartType.Wedge,
	cylinder = Enum.PartType.Cylinder,
	ball = Enum.PartType.Ball,
}
local LOOK = 0.25 -- seconds between looks at the ridden fish (how far they are, a part that had not streamed in yet)

local folder: Folder? = nil
local spare: { [string]: { Held } } = { box = {}, wedge = {}, cylinder = {}, ball = {} }
local spares = 0
local worn: { [Model]: Worn } = {}
local watched: { [Model]: { RBXScriptConnection } } = {}
local ridden: { [Model]: boolean } = {} -- the fish that have or are promised a rider

----------------------------------------------------------------------------------------------------------------------
-- The parts, kept and used again

local function take(shape: string): Held
	local held = table.remove(spare[shape])
	if held then
		spares -= 1
		return held
	end
	local part = Instance.new("Part")
	part.Name = "Saddle"
	part.Shape = SHAPES[shape]
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.RootPriority = -127
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local weld = Instance.new("Weld")
	weld.Part1 = part
	weld.Parent = part
	return { Part = part, Weld = weld, Shape = shape }
end

local function give(held: Held)
	local lost = held.Part.Parent ~= folder -- (fell out of the world with its fish: never used again)
	if lost or spares >= Config.Saddles.Spare then
		held.Part:Destroy()
		return
	end
	held.Part.Parent = nil
	held.Weld.Part0 = nil
	table.insert(spare[held.Shape], held)
	spares += 1
end

local function make(w: Worn)
	local entry = w.List[#w.Made + 1]
	local held = take(entry.Shape)
	local part = held.Part
	part.Size = entry.Size
	part.Color = entry.Colour
	part.Material = if entry.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.LocalTransparencyModifier = w.See
	local offset = w.Offset * entry.At
	part.CFrame = w.Joint.CFrame * offset
	held.Weld.C0 = offset
	held.Weld.Part0 = w.Joint
	part.Parent = folder
	table.insert(w.Made, held)
end

----------------------------------------------------------------------------------------------------------------------
-- On a fish and off it

local function undress(fish: Model)
	local w = worn[fish]
	if w then
		worn[fish] = nil
		for _, held in w.Made do
			give(held)
		end
	end
end

-- The fish's part a fit hangs on, and the back point from it; nil while it has not streamed in. The part's place at
-- rest is its hinge (the creature's file) less its own offset (the joint's C1, which nothing moves: the fails move C0).
local function placeOf(fish: Model, kind: string, size: string, joint: string): (BasePart?, CFrame)
	local rig = Creatures.get(kind)
	local entry = Config.FishById[kind]
	if not rig or not entry then
		return nil, CFrame.identity
	end
	local motor = fish:FindFirstChild("Rig_" .. joint, true)
	if not motor or not motor:IsA("Motor6D") or not motor.Part1 then
		return nil, CFrame.identity
	end
	local k = entry.Size.Z / rig.Size[3] * Config.sizeScale(size, entry)
	for _, row in rig.Parts do
		if row[1] == joint then
			local rest = CFrame.new(Vector3.new(row[3], row[4], row[5]) * k) * motor.C1:Inverse()
			local back = Vector3.new(rig.Seat[1], rig.Seat[2], rig.Seat[3]) * k
			return motor.Part1, rest:Inverse() * CFrame.new(back)
		end
	end
	return nil, CFrame.identity
end

local function dress(fish: Model, player: Player, key: string, riding: boolean)
	local kind, size = fish:GetAttribute("Rig"), fish:GetAttribute("SizeTier")
	if type(kind) ~= "string" or type(size) ~= "string" then
		return -- (a stand-in with no model: no fit)
	end
	local fit, list = Saddles.fit(kind, size), Saddles.build(kind, size, key)
	if not fit or not list then
		return
	end
	local joint, offset = placeOf(fish, kind, size, fit.Joint)
	if not joint then
		return -- (looked at again: LOOK)
	end
	worn[fish] = {
		Fish = fish,
		Key = key,
		Kind = kind,
		Size = size,
		List = list,
		Joint = joint,
		Offset = offset,
		Made = {},
		Riding = riding,
		Player = player,
		See = 1,
	}
end

-- Who a fish is under, or promised to: their UserId (0: nobody), and whether they are on it
local function riderOf(fish: Model): (number, boolean)
	for _, name in { "Rider", "LandRider", "TankRider", "Reserved" } do
		local id = fish:GetAttribute(name)
		if type(id) == "number" and id ~= 0 then
			return id, name ~= "Reserved"
		end
	end
	return 0, false
end

-- Puts on a fish what its rider wears now, or takes it off
local function refresh(fish: Model)
	local id, riding = riderOf(fish)
	ridden[fish] = if id ~= 0 then true else nil :: any
	local player = if id ~= 0 then Players:GetPlayerByUserId(id) else nil
	local land = if player then player:GetAttribute("Saddle") else nil
	local design = if type(land) == "number" and land > 0 then Saddles.ofLand(land) else nil
	local had = worn[fish]
	local camera = workspace.CurrentCamera
	if design and camera then
		-- (one far away is not made; one that is on stays on a little further, so it can't blink at the edge)
		local far = Config.Saddles.Far * (if had then 1.2 else 1)
		if (fish:GetPivot().Position - camera.CFrame.Position).Magnitude > far then
			design = nil
		end
	end
	if had then
		local same = design and player and had.Key == design.Key and had.Size == fish:GetAttribute("SizeTier")
		if same and had.Joint:IsDescendantOf(fish) then
			had.Riding, had.Player = riding, player :: Player
			return
		end
		undress(fish)
	end
	if design and player then
		dress(fish, player, design.Key, riding)
	end
end

local function forget(fish: any)
	local links = watched[fish]
	if links then
		watched[fish] = nil
		for _, link in links do
			link:Disconnect()
		end
	end
	ridden[fish] = nil
	undress(fish)
end

local function watch(fish: Instance)
	if not fish:IsA("Model") or watched[fish] then
		return
	end
	local links: { RBXScriptConnection } = {}
	for _, name in { "Rider", "LandRider", "TankRider", "Reserved" } do
		table.insert(
			links,
			fish:GetAttributeChangedSignal(name):Connect(function()
				refresh(fish)
			end)
		)
	end
	table.insert(
		links,
		fish.AncestryChanged:Connect(function()
			if not fish:IsDescendantOf(workspace) then
				forget(fish)
			end
		end)
	)
	watched[fish] = links
	refresh(fish)
end

----------------------------------------------------------------------------------------------------------------------
-- Every frame

-- What a saddle's parts are hidden by: wholly until its rider lands (our own: until we are RevealNear its seat), then
-- as much as the fish's part under it is
local function seeOf(w: Worn): number
	local on = w.Riding
	if not on and w.Player == Players.LocalPlayer then
		local character = w.Player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local fishRoot = w.Fish.PrimaryPart
		local seat = fishRoot and fishRoot:FindFirstChild("Saddle")
		if root and root:IsA("BasePart") and seat and seat:IsA("Attachment") then
			on = (root.Position - seat.WorldPosition).Magnitude <= Config.Saddles.RevealNear
		end
	end
	if not on or w.Joint.Transparency >= 0.99 then
		return 1
	end
	return w.Joint.LocalTransparencyModifier
end

local since = 0
local function step(dt: number)
	since += dt
	if since >= LOOK then
		since = 0
		for fish in table.clone(ridden) do
			refresh(fish)
		end
	end
	local left = Config.Saddles.PartsAFrame
	for fish, w in worn do
		if not w.Joint:IsDescendantOf(workspace) then
			undress(fish) -- (its part has streamed out: what hung on it would fall)
			continue
		end
		local see = seeOf(w)
		if math.abs(see - w.See) > 0.01 or (see ~= w.See and (see == 0 or see == 1)) then
			w.See = see
			for _, held in w.Made do
				held.Part.LocalTransparencyModifier = see
			end
		end
		while left > 0 and #w.Made < #w.List do
			make(w)
			left -= 1
		end
	end
end

-- A player's saddle was put on, changed or taken off: what they ride shows it
local function follow(player: Player)
	player:GetAttributeChangedSignal("Saddle"):Connect(function()
		for fish in table.clone(ridden) do
			if riderOf(fish) == player.UserId then
				refresh(fish)
			end
		end
	end)
end

-- For checks (tools/saddles/saddle_test.luau, Studio's): the saddle on a fish: its design, how many parts are made of
-- how many, how much they are hidden; nil with none
function SaddleController.on(fish: Model): (string?, number?, number?, number?)
	local w = worn[fish]
	if not w then
		return nil
	end
	return w.Key, #w.Made, #w.List, w.See
end

function SaddleController.Start()
	local made = Instance.new("Folder")
	made.Name = "Saddles"
	made.Parent = workspace
	folder = made
	for _, tag in { "Fish", "TankFish" } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(forget)
		for _, fish in CollectionService:GetTagged(tag) do
			watch(fish)
		end
	end
	Players.PlayerAdded:Connect(follow)
	for _, player in Players:GetPlayers() do
		follow(player)
	end
	RunService.Heartbeat:Connect(step)
	-- (the land fish's folder is made by the first ride)
	local function land(child: Instance)
		if child.Name == "LandFish" then
			child.ChildAdded:Connect(watch)
			child.ChildRemoved:Connect(forget)
			for _, fish in child:GetChildren() do
				watch(fish)
			end
		end
	end
	workspace.ChildAdded:Connect(land)
	for _, child in workspace:GetChildren() do
		land(child)
	end
end

return SaddleController
