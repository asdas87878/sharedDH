--!strict
-- Wild fish: spawns them per zone (the roster's rarity mix, each fish one or two zones past its home at most), and swims
-- them idly along the dive lane from waypoint to waypoint. A ridden fish belongs to its rider's client (network owner),
-- which drives it; once let go it slows back to idle over Ride.SlowDownTime and swims on wherever it ended up.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Zones = require(ReplicatedStorage.Shared.Zones)
local FishModel = require(script.Parent.Parent.Lib.FishModel)

export type Wild = {
	Model: Model,
	Root: BasePart,
	Type: Config.FishType,
	Zone: number,
	Waypoint: Vector3,
	Dir: Vector3,
	Speed: number,
	Rider: Player?,
	Reserved: Player?,
	ReleasedAt: number?,
	ReleaseSpeed: number,
	Swim: LinearVelocity,
	Turn: AlignOrientation,
	Saddle: Attachment,
}

local FishService = {}

local rng = Random.new()
local folder: Folder
local zones: { Zones.Zone } = {}
local wild: { [Model]: Wild } = {}

FishService.Tag = FishModel.Tag

function FishService.zones(): { Zones.Zone }
	return zones
end

function FishService.get(instance: Instance?): Wild?
	if instance and instance:IsA("Model") then
		return wild[instance]
	end
	return nil
end

-- The fish types that can turn up in a zone, with their weights, by tier
local function pool(zoneIndex: number): { [string]: { { fish: Config.FishType, weight: number } } }
	local byTier = {}
	for _, fish in Config.Fish do
		local away = zoneIndex - fish.Home
		if away >= 0 and away <= fish.Reach then
			local weight = Config.ReachWeight[away + 1] or 0
			if weight > 0 then
				byTier[fish.Tier] = byTier[fish.Tier] or {}
				table.insert(byTier[fish.Tier], { fish = fish, weight = weight })
			end
		end
	end
	return byTier
end

local pools: { { [string]: { { fish: Config.FishType, weight: number } } } } = {}

local function pick(zoneIndex: number): Config.FishType?
	local byTier = pools[zoneIndex]
	local mix = Config.ZoneMix[zoneIndex]
	if not byTier or not mix then
		return nil
	end
	local total = 0
	for tier, share in mix do
		if byTier[tier] then
			total += share
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, tier in Config.TierOrder do
		local share = mix[tier]
		if share and byTier[tier] then
			roll -= share
			if roll <= 0 then
				local options = byTier[tier]
				local sum = 0
				for _, option in options do
					sum += option.weight
				end
				local r = rng:NextNumber() * sum
				for _, option in options do
					r -= option.weight
					if r <= 0 then
						return option.fish
					end
				end
				return options[#options].fish
			end
		end
	end
	return nil
end

local function randomPoint(zone: Zones.Zone, near: number?): Vector3
	local half = zone.Length / 2 * 0.95
	local s = if near then math.clamp(near + rng:NextNumber(-60, 160), -half, half) else rng:NextNumber(-half, half)
	local x = rng:NextNumber(-1, 1) * zone.Width / 2 * Config.Spawn.LaneFill
	-- stay under the surface where the water is shallow
	local floorY = Zones.point(zone, x, 0, s).Y
	local room = Config.Oxygen.SurfaceY - 6 - floorY
	local top = math.min(Config.Spawn.HeightMax, room)
	local h = if top > Config.Spawn.HeightMin
		then rng:NextNumber(Config.Spawn.HeightMin, top)
		else math.max(room * 0.5, 2)
	return Zones.point(zone, x, h, s)
end

local function newWaypoint(w: Wild)
	local zone = zones[w.Zone]
	if not zone then
		return
	end
	local s = zone.Frame:PointToObjectSpace(w.Root.Position).Z
	w.Waypoint = randomPoint(zone, s)
end

local function spawnFish(zoneIndex: number, near: number?): Wild?
	local zone = zones[zoneIndex]
	local fishType = pick(zoneIndex)
	if not zone or not fishType then
		return nil
	end
	local model = FishModel.build(fishType)
	local at = randomPoint(zone, near)
	local dir = zone.Frame.ZVector
	model:PivotTo(CFrame.lookAt(at, at + dir))
	model.Parent = folder
	local root = model.PrimaryPart :: BasePart
	root:SetNetworkOwner(nil)
	local w: Wild = {
		Model = model,
		Root = root,
		Type = fishType,
		Zone = zoneIndex,
		Waypoint = at,
		Dir = dir,
		Speed = fishType.IdleSpeed,
		Rider = nil,
		Reserved = nil,
		ReleasedAt = nil,
		ReleaseSpeed = 0,
		Swim = root:FindFirstChild("Swim") :: LinearVelocity,
		Turn = root:FindFirstChild("Turn") :: AlignOrientation,
		Saddle = root:FindFirstChild("Saddle") :: Attachment,
	}
	wild[model] = w
	newWaypoint(w)
	model.Destroying:Connect(function()
		wild[model] = nil
	end)
	return w
end

local function count(): ({ number }, number)
	local per = {}
	local total = 0
	for _, w in wild do
		if not w.Rider then
			per[w.Zone] = (per[w.Zone] or 0) + 1
		end
		total += 1
	end
	return per, total
end

local function target(zone: Zones.Zone): number
	return math.clamp(math.floor(zone.Length / 1000 * Config.Spawn.PerThousand), Config.Spawn.Min, Config.Spawn.Max)
end

local function nearAPlayer(position: Vector3, radius: number): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - position).Magnitude < radius then
			return true
		end
	end
	return false
end

-- Free fish in the first zone's opening stretch, where you dive in from the board
local function atStart(): number
	local zone = zones[1]
	if not zone then
		return 0
	end
	local n = 0
	for _, w in wild do
		if not w.Rider and not w.Reserved and w.Zone == 1 then
			local s = zone.Frame:PointToObjectSpace(w.Root.Position).Z
			if s < -zone.Length / 2 + Config.Spawn.StartLength then
				n += 1
			end
		end
	end
	return n
end

local function topUp(limit: number)
	local per, total = count()
	local made = 0
	if zones[1] then
		local missing = Config.Spawn.StartCluster - atStart()
		while missing > 0 and total < Config.Spawn.MaxTotal and made < limit do
			-- randomPoint scatters from 60 before to 160 past `near`, clamped into the zone
			if not spawnFish(1, -zones[1].Length / 2) then
				break
			end
			per[1] = (per[1] or 0) + 1
			total += 1
			made += 1
			missing -= 1
		end
	end
	for i = 1, math.min(#zones, Config.Spawn.ActiveZones) do
		local want = target(zones[i]) + (if i == 1 then Config.Spawn.StartCluster else 0)
		while (per[i] or 0) < want and total < Config.Spawn.MaxTotal and made < limit do
			if spawnFish(i) then
				per[i] = (per[i] or 0) + 1
				total += 1
				made += 1
			else
				break
			end
		end
	end
	-- thin out zones that ridden fish have crowded, and fish carried past the active zones, out of sight
	for _, w in wild do
		if not w.Rider and not w.Reserved then
			local extra = if w.Zone == 1 then Config.Spawn.StartCluster else 0
			local over = w.Zone > Config.Spawn.ActiveZones
				or (per[w.Zone] or 0) > (if zones[w.Zone] then target(zones[w.Zone]) + extra + 6 else 0)
			if over and not nearAPlayer(w.Root.Position, 250) then
				per[w.Zone] = (per[w.Zone] or 0) - 1
				w.Model:Destroy()
			end
		end
	end
end

-- Claim a fish for a dash or grapple in flight, so nobody else takes it mid-move
function FishService.reserve(w: Wild, player: Player): boolean
	if w.Rider or (w.Reserved and w.Reserved ~= player) or not w.Model.Parent then
		return false
	end
	w.Reserved = player
	w.Model:SetAttribute("Reserved", player.UserId)
	return true
end

function FishService.unreserve(w: Wild, player: Player)
	if w.Reserved == player then
		w.Reserved = nil
		w.Model:SetAttribute("Reserved", 0)
	end
end

function FishService.isFree(w: Wild, player: Player): boolean
	return w.Model.Parent ~= nil and not w.Rider and (not w.Reserved or w.Reserved == player)
end

-- After the rider's weld is in place: the rider's client owns and drives the fish
function FishService.setRider(w: Wild, player: Player)
	w.Rider = player
	w.Reserved = nil
	w.ReleasedAt = nil
	w.Model:SetAttribute("Rider", player.UserId)
	w.Model:SetAttribute("Reserved", 0)
	pcall(function()
		w.Root:SetNetworkOwner(player)
	end)
end

-- After the rider's weld is gone: back to the server, slowing to idle
function FishService.release(w: Wild)
	w.Rider = nil
	w.Model:SetAttribute("Rider", 0)
	if not w.Model.Parent then
		return
	end
	pcall(function()
		w.Root:SetNetworkOwner(nil)
	end)
	local velocity = w.Root.AssemblyLinearVelocity
	w.ReleaseSpeed = velocity.Magnitude
	w.ReleasedAt = os.clock()
	w.Dir = if velocity.Magnitude > 1 then velocity.Unit else w.Root.CFrame.LookVector
	local zone = Zones.locate(zones, w.Root.Position)
	w.Zone = if zone then zone.Index else 1
	newWaypoint(w)
end

local function steer(w: Wild, dt: number)
	local position = w.Root.Position
	local speed = w.Type.IdleSpeed
	if w.ReleasedAt then
		local t = (os.clock() - w.ReleasedAt) / Config.Ride.SlowDownTime
		if t >= 1 then
			w.ReleasedAt = nil
		else
			speed = w.ReleaseSpeed + (speed - w.ReleaseSpeed) * t
		end
	end
	local to = w.Waypoint - position
	if to.Magnitude < 10 then
		newWaypoint(w)
		to = w.Waypoint - position
	end
	local want = to.Unit
	want = Vector3.new(want.X, math.clamp(want.Y, -0.45, 0.45), want.Z).Unit
	local turn = 1 - math.exp(-1.4 * dt)
	w.Dir = w.Dir:Lerp(want, turn).Unit
	w.Speed = speed
	w.Swim.VectorVelocity = w.Dir * speed
	w.Turn.CFrame = CFrame.lookAt(Vector3.zero, w.Dir)
end

function FishService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Fish"
	folder.Parent = workspace
	zones = Zones.discover()
	Net.Folder:SetAttribute("Zones", Zones.encode(zones))
	for i = 1, #zones do
		pools[i] = pool(i)
	end
end

function FishService.Start()
	topUp(math.huge)
	RunService.Heartbeat:Connect(function(dt)
		for _, w in wild do
			if not w.Rider then
				steer(w, dt)
			end
		end
	end)
	while true do
		task.wait(Config.Spawn.TopUpEvery)
		topUp(Config.Spawn.PerTopUp)
	end
end

return FishService
