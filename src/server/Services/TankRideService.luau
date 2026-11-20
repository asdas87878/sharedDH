--!strict
-- Riding a fish in your own tank (Hugo, 2026-11-20, task k1: "make fishes in the tank rideable (in the tank)";
-- Config.TankRide, docs/design/aquarium.md "Riding in the tank"). Practice with nothing at stake: the player stays
-- "Dock" to RideService the whole time, so there is no Oxygen, no fail or throw-off, no taming and no catch.
--   Getting on: Action "TankRide", "On", fish (the tank's E prompt with empty hands: AquariumController). Only the
--   tank's owner, on the dock, at their own tank, onto one of the fish swimming in it now. The fish stops its lap (its
--   "TankFish" tag comes off, so no machine moves it round any more), is shown at least TankRide.Least long, is made
--   loose and given two movers (TankAlign, TankTurn), the rider is welded to its Saddle, and the rider's machine is
--   given the fish to move (its network owner), so everyone sees it go where the rider takes it. The rider is told
--   ("TankMounted", fish, box CFrame, box half size: the inside of the water the fish's middle must stay in) and the
--   player's "TankRide" attribute is true (every machine poses them astride: AnimController).
--   Riding: TankRideController moves the movers' targets, kept inside the box. Here, a few times a second, a fish
--   further out than TankRide.Slack is put back (so it can never leave the tank, whatever a machine says).
--   Getting off: Action "TankRide", "Off" (SPACE), or anything that ends it (the fish rebuilt by a change to the tank,
--   a new body, leaving the dock, leaving the game). The rider is put on the floor in front of the tank, facing it,
--   and the tank's fish are put back in their laps (AquariumService.reshow).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local AquariumService = require(script.Parent.AquariumService)
local PropService = require(script.Parent.PropService)
local RideService = require(script.Parent.RideService)

type Ride = {
	Fish: Model,
	Root: BasePart,
	Weld: Weld,
	Box: CFrame, -- the middle of the space the fish's middle stays in,
	Half: Vector3, -- and its half size
	Gone: RBXScriptConnection,
}

local TankRideService = {}

local rides: { [Player]: Ride } = {}

local function parts(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if root and root:IsA("BasePart") then root else nil, humanoid
end

-- The space the fish's middle may be in: the water, less the margin and the fish's own reach (half its length
-- across, as it can face any way; half its height up and down)
local function boxOf(water: BasePart, fish: Model): (CFrame, Vector3)
	local c = Config.TankRide
	local _, size = fish:GetBoundingBox()
	local across = math.max(size.X, size.Z) / 2 + c.Margin
	local up = size.Y / 2 + c.Margin
	local half = water.Size / 2
	return CFrame.new(water.Position) * water.CFrame.Rotation,
		Vector3.new(math.max(half.X - across, 0.5), math.max(half.Y - up, 0.5), math.max(half.Z - across, 0.5))
end

local function clampInto(box: CFrame, half: Vector3, at: Vector3): Vector3
	local p = box:PointToObjectSpace(at)
	return box:PointToWorldSpace(
		Vector3.new(
			math.clamp(p.X, -half.X, half.X),
			math.clamp(p.Y, -half.Y, half.Y),
			math.clamp(p.Z, -half.Z, half.Z)
		)
	)
end

local function finish(player: Player, putBack: boolean)
	local ride = rides[player]
	if not ride then
		return
	end
	rides[player] = nil
	ride.Gone:Disconnect()
	if ride.Weld.Parent then
		ride.Weld:Destroy()
	end
	player:SetAttribute("TankRide", nil)
	local root, humanoid = parts(player)
	local character = player.Character
	if root and humanoid and character then
		humanoid.PlatformStand = false
		PropService.riding(character, false)
		pcall(function()
			root:SetNetworkOwner(player)
		end)
		local plot = AquariumService.plotOf(player)
		local spot = plot and AquariumService.frontOf(plot)
		if spot and RideService.stateOf(player) == "Dock" then
			character:PivotTo(spot + Vector3.new(0, 3, 0))
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
	-- (the ridden fish is one of the tank's shown ones: building them again puts it back in its lap, its size and its
	-- tag as before)
	if putBack then
		AquariumService.reshow(player)
	elseif ride.Fish.Parent then
		ride.Fish:Destroy()
	end
	Net.Ride:FireClient(player, "TankDismounted")
end

local function start(player: Player, fish: any)
	local c = Config.TankRide
	if c.On == 0 or rides[player] or RideService.stateOf(player) ~= "Dock" then
		return
	end
	local plot = AquariumService.plotOf(player)
	local shown = AquariumService.shownOf(player)
	local water = plot and plot:FindFirstChild("TankWater")
	if not plot or not shown or not water or not water:IsA("BasePart") then
		Net.Ride:FireClient(player, "Denied", "TankRide", "Empty")
		return
	end
	if not AquariumService.atTank(player) then
		Net.Ride:FireClient(player, "Denied", "TankRide", "Far")
		return
	end
	-- only one of the fish in our own tank now (anything else sent: the one nearest us)
	local root, humanoid = parts(player)
	local character = player.Character
	if not root or not humanoid or not character then
		return
	end
	local model: Model? = nil
	if typeof(fish) == "Instance" and fish:IsA("Model") and fish.Parent == shown then
		model = fish
	else
		local best = math.huge
		for _, m in shown:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart then
				local d = (m.PrimaryPart.Position - root.Position).Magnitude
				if d < best then
					best, model = d, m
				end
			end
		end
	end
	local fishRoot = model and model.PrimaryPart
	local saddle = fishRoot and fishRoot:FindFirstChild("Saddle")
	local center = fishRoot and fishRoot:FindFirstChild("Center")
	if
		not model
		or not fishRoot
		or not saddle
		or not saddle:IsA("Attachment")
		or not center
		or not center:IsA("Attachment")
	then
		Net.Ride:FireClient(player, "Denied", "TankRide", "Empty")
		return
	end
	AquariumService.putAway(player) -- (no fish held over the head while riding one)
	-- out of its lap: no machine moves it round any more
	CollectionService:RemoveTag(model, AquariumService.Tag)
	model:SetAttribute("TankRider", player.UserId)
	-- big enough to sit on, small enough to turn in the tank
	local _, size = model:GetBoundingBox()
	local long = math.max(size.X, size.Y, size.Z)
	local want = math.clamp(long, c.Least, c.Most)
	if math.abs(want - long) > 0.1 and long > 0.1 then
		model:ScaleTo(model:GetScale() * want / long)
	end
	local box, half = boxOf(water, model)
	-- level, where it swims now (inside the box), facing the way it was going
	local look = fishRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	local at = clampInto(box, half, fishRoot.Position)
	fishRoot.CFrame = CFrame.lookAt(at, at + look.Unit)
	fishRoot.Anchored = false
	local align = Instance.new("AlignPosition")
	align.Name = "TankAlign"
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = center
	align.Position = at
	-- (limited, as the wild fish's movers are: a weld joined to an unlimited mover now and then threw the pair far)
	align.MaxForce = 1e5
	align.MaxVelocity = c.Speed * 4
	align.Responsiveness = 30
	align.Parent = fishRoot
	local turn = Instance.new("AlignOrientation")
	turn.Name = "TankTurn"
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = center
	turn.MaxTorque = 4e5
	turn.MaxAngularVelocity = 8
	turn.Responsiveness = 20
	turn.CFrame = fishRoot.CFrame.Rotation
	turn.Parent = fishRoot
	-- the rider on the saddle, touching nothing (the posts and the rim can't catch them)
	humanoid.PlatformStand = true
	PropService.riding(character, true)
	root.CFrame = saddle.WorldCFrame
	local weld = Instance.new("Weld")
	weld.Name = "TankRideWeld"
	weld.Part0 = fishRoot
	weld.Part1 = root
	weld.C0 = saddle.CFrame
	weld.Parent = fishRoot
	pcall(function()
		fishRoot:SetNetworkOwner(player)
	end)
	local ride: Ride = {
		Fish = model,
		Root = fishRoot,
		Weld = weld,
		Box = box,
		Half = half,
		Gone = model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then
				-- (rebuilt by a change to the tank: the new ones are already in their laps)
				task.defer(finish, player, false)
			end
		end),
	}
	rides[player] = ride
	player:SetAttribute("TankRide", true)
	Net.Ride:FireClient(player, "TankMounted", model, box, half)
end

-- Is everyone still riding, and inside their tank
local function check()
	local slack = Config.TankRide.Slack
	for player, ride in rides do
		local root = parts(player)
		if
			not root
			or not ride.Weld.Parent
			or ride.Weld.Part1 ~= root
			or RideService.stateOf(player) ~= "Dock"
			or Config.TankRide.On == 0
		then
			finish(player, true)
		else
			local p = ride.Box:PointToObjectSpace(ride.Root.Position)
			local h = ride.Half
			if math.abs(p.X) > h.X + slack or math.abs(p.Y) > h.Y + slack or math.abs(p.Z) > h.Z + slack then
				local at = clampInto(ride.Box, h, ride.Root.Position)
				ride.Root.CFrame = CFrame.new(at) * ride.Root.CFrame.Rotation
				ride.Root.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end
end

function TankRideService.riding(player: Player): boolean
	return rides[player] ~= nil
end

function TankRideService.Start()
	local last: { [Player]: number } = {}
	Net.Action.OnServerEvent:Connect(function(player: Player, action: any, verb: any, fish: any)
		if action ~= "TankRide" then
			return
		end
		local now = os.clock()
		if now - (last[player] or 0) < 0.3 then
			return
		end
		last[player] = now
		if verb == "On" then
			start(player, fish)
		elseif verb == "Off" then
			finish(player, true)
		end
	end)
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			finish(player, true)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		last[player] = nil
		local ride = rides[player]
		if ride then
			rides[player] = nil
			ride.Gone:Disconnect()
		end
	end)
	while true do
		task.wait(0.25)
		check()
	end
end

return TankRideService
