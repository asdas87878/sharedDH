--!strict
-- Wild fish: spawned per zone by the roster's rarity mix (each fish one or two zones past its home at most), spread
-- evenly over the whole dive lane, and swimming as a herd: all the same way, down the lane, each at its own place across
-- it and above the floor, at Herd.SpeedShare of the speed it is ridden at (as the reference's herds run along its track).
-- The lane's path (Shared.Lane) is cut into Spawn.Slice-stud slices, each zone's share of fish spread over its slices,
-- every slice keeping at least one (the dive board's keeps Spawn.BoardSlice). The herd drains downstream, so the top-up
-- keeps putting new fish into the emptiest slices, and takes away fish that have swum past the zones their kind lives
-- in, or into a crowded slice, once nobody is near.
-- Fish further than Spawn.StreamRadius from every player are parked in ServerStorage (not simulated, not sent to
-- clients) and come back when someone nears. A ridden fish belongs to its rider's client (network owner), which drives
-- it; once let go it stays with that client for Switch.HandBack seconds, coasting, so it doesn't hitch in front of them,
-- then the server takes it back and it joins the herd from where it is.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lane = require(ReplicatedStorage.Shared.Lane)
local Net = require(ReplicatedStorage.Shared.Net)
local Zones = require(ReplicatedStorage.Shared.Zones)
local FishModel = require(script.Parent.Parent.Lib.FishModel)

export type Wild = {
	Model: Model,
	Root: BasePart,
	Type: Config.FishType,
	Zone: number,
	Home: number, -- s along the lane: where it is, as far as the stocking knows (kept up by the top-up)
	S: number, -- s along the lane now, carried forward as it swims
	Across: number, -- its place across the lane, from the centre
	Height: number, -- and above the lane's floor
	Slice: number?, -- the slice it counts for (nil past the stocked zones)
	Parked: boolean,
	Dir: Vector3,
	Speed: number,
	Rider: Player?,
	Reserved: Player?,
	ReleasedAt: number?,
	ReleaseSpeed: number,
	CoastToken: {}?, -- set while the last rider's client still drives it after a dismount
	Swim: LinearVelocity,
	Turn: AlignOrientation,
	Saddle: Attachment,
}

type Slice = { Start: number, End: number, Zone: number, Want: number }

local FishService = {}

local rng = Random.new()
local folder: Folder
local parkedFolder: Folder
local zones: { Zones.Zone } = {}
local lane: Lane.Lane
local slices: { Slice } = {}
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

-- Whether any fish type can turn up in a zone (its roster: a tier in the zone's mix with a fish in reach)
local function hasRoster(zoneIndex: number): boolean
	local byTier = pools[zoneIndex]
	local mix = Config.ZoneMix[zoneIndex]
	if not byTier or not mix then
		return false
	end
	for tier in mix do
		if byTier[tier] then
			return true
		end
	end
	return false
end

-- The slices over every zone with a roster, the whole lane long
local function newSlices(): { Slice }
	local list: { Slice } = {}
	local sp = Config.Spawn
	local total = 0
	for z = 1, #zones do
		local s0, s1 = lane.ZoneStart[z], lane.ZoneEnd[z]
		local length = s1 - s0
		if length > 1 and hasRoster(z) then
			local n = math.max(1, math.floor(length / sp.Slice + 0.5))
			local want = math.max(n, math.clamp(math.floor(length / 1000 * sp.PerThousand), sp.Min, sp.Max))
			for k = 1, n do
				-- the zone's fish shared out as evenly as whole numbers allow
				local share = math.floor(want * k / n) - math.floor(want * (k - 1) / n)
				table.insert(list, {
					Start = s0 + length * (k - 1) / n,
					End = s0 + length * k / n,
					Zone = z,
					Want = math.max(1, share),
				})
				total += math.max(1, share)
			end
		end
	end
	if list[1] then
		list[1].Want = math.max(list[1].Want, sp.BoardSlice)
	end
	-- over the cap: trim the fullest slices first, never below one
	while total > sp.MaxTotal do
		local fullest: Slice? = nil
		for _, slice in list do
			if slice.Want > 1 and (not fullest or slice.Want > fullest.Want) then
				fullest = slice
			end
		end
		if not fullest then
			break
		end
		fullest.Want -= 1
		total -= 1
	end
	return list
end

local function sliceAt(s: number): number?
	for i, slice in slices do
		if s >= slice.Start and s < slice.End then
			return i
		end
	end
	return nil
end

-- A spot in the lane at s: across 0.7 of its width, a random height above the floor, under the surface and any roof
local function pointAt(s: number): Vector3
	local _, _, width = Lane.at(lane, s)
	local x = rng:NextNumber(-1, 1) * width / 2 * Config.Spawn.LaneFill
	local floorY = Lane.point(lane, s, x, 0).Y
	local room = Config.Oxygen.SurfaceY - 6 - floorY
	-- under an arch, a shelf or a sign, keep clear of the roof (the map's Path c)
	local roof = Lane.clearanceAt(lane, s)
	if roof then
		room = math.min(room, roof - Config.Spawn.RoofGap)
	end
	local top = math.min(Config.Spawn.HeightMax, room)
	local h = if top > Config.Spawn.HeightMin
		then rng:NextNumber(Config.Spawn.HeightMin, top)
		else math.max(room * 0.5, 2)
	return Lane.point(lane, s, x, h)
end

-- Where a fish is in the lane, from its position: s along it, its place across and its height above the floor (kept
-- inside the part of the lane fish use)
local function placeInLane(w: Wild)
	local position = w.Root.Position
	local s = Lane.project(lane, position)
	local centre, along, width = Lane.at(lane, s)
	local right = along:Cross(Vector3.yAxis)
	local half = width / 2 * Config.Spawn.LaneFill
	w.S = s
	w.Across = math.clamp((position - centre):Dot(right), -half, half)
	w.Height = math.clamp(position.Y - centre.Y, Config.Spawn.HeightMin, Config.Spawn.HeightMax)
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

local function park(w: Wild, parked: boolean)
	if w.Parked == parked then
		return
	end
	w.Parked = parked
	w.Model.Parent = if parked then parkedFolder else folder
	if not parked then
		pcall(function()
			w.Root:SetNetworkOwner(nil)
		end)
	end
end

local function spawnFish(index: number): Wild?
	local slice = slices[index]
	local fishType = slice and pick(slice.Zone)
	if not slice or not fishType then
		return nil
	end
	local home = rng:NextNumber(slice.Start, slice.End)
	local at = pointAt(home)
	local _, dir = Lane.at(lane, home)
	local model = FishModel.build(fishType)
	model:PivotTo(CFrame.lookAt(at, at + dir))
	local root = model.PrimaryPart :: BasePart
	local w: Wild = {
		Model = model,
		Root = root,
		Type = fishType,
		Zone = slice.Zone,
		Home = home,
		S = home,
		Across = 0,
		Height = Config.Spawn.HeightMin,
		Slice = index,
		Parked = true,
		Dir = dir,
		Speed = fishType.IdleSpeed,
		Rider = nil,
		Reserved = nil,
		ReleasedAt = nil,
		ReleaseSpeed = 0,
		CoastToken = nil,
		Swim = root:FindFirstChild("Swim") :: LinearVelocity,
		Turn = root:FindFirstChild("Turn") :: AlignOrientation,
		Saddle = root:FindFirstChild("Saddle") :: Attachment,
	}
	model.Parent = parkedFolder
	wild[model] = w
	placeInLane(w)
	model.Destroying:Connect(function()
		wild[model] = nil
	end)
	park(w, not nearAPlayer(at, Config.Spawn.StreamRadius))
	return w
end

-- Free fish per slice (parked ones count; ridden, reserved and coasting ones don't), and every fish in all
local function count(): ({ [number]: number }, number)
	local per = {}
	local total = 0
	for _, w in wild do
		local slice = w.Slice
		if slice and not w.Rider and not w.Reserved and not w.CoastToken then
			per[slice] = (per[slice] or 0) + 1
		end
		total += 1
	end
	return per, total
end

-- The slice furthest under its share, ties broken at random
local function emptiest(per: { [number]: number }): number?
	local best: number? = nil
	local bestScore = 0
	for i, slice in slices do
		local have = per[i] or 0
		if have < slice.Want then
			local score = (slice.Want - have) / slice.Want + rng:NextNumber() * 0.01
			if score > bestScore then
				best = i
				bestScore = score
			end
		end
	end
	return best
end

local function topUp(limit: number)
	local per, total = count()
	local made = 0
	while made < limit and total < Config.Spawn.MaxTotal do
		local index = emptiest(per)
		if not index or not spawnFish(index) then
			break
		end
		per[index] = (per[index] or 0) + 1
		total += 1
		made += 1
	end
	for _, w in wild do
		if not w.Rider and not w.Reserved and not w.CoastToken then
			local near = nearAPlayer(w.Root.Position, Config.Spawn.StreamRadius)
			-- the herd swims on: the fish counts for the slice it has reached
			local old = w.Slice
			local slice = sliceAt(w.S)
			if slice ~= old then
				if old then
					per[old] = (per[old] or 0) - 1
				end
				if slice then
					per[slice] = (per[slice] or 0) + 1
				end
				w.Home = w.S
				w.Slice = slice
				w.Zone = Lane.zoneAt(lane, w.S)
			end
			-- out of sight, take away fish in a crowded slice, past the stocked zones, or past the zones their kind
			-- lives in
			local strayed = w.Zone > w.Type.Home + w.Type.Reach
			local over = not slice or strayed or (per[slice] or 0) > slices[slice].Want + 1
			if over and not nearAPlayer(w.Root.Position, 250) then
				if slice then
					per[slice] -= 1
				end
				w.Model:Destroy()
			else
				park(w, not near)
			end
		end
	end
end

-- Claim a fish for a dash or grapple in flight, so nobody else takes it mid-move
function FishService.reserve(w: Wild, player: Player): boolean
	if w.Rider or (w.Reserved and w.Reserved ~= player) or w.Model.Parent ~= folder then
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
	return w.Model.Parent == folder and not w.Rider and (not w.Reserved or w.Reserved == player)
end

-- After the rider's weld is in place: the rider's client owns and drives the fish
function FishService.setRider(w: Wild, player: Player)
	w.Rider = player
	w.Reserved = nil
	w.ReleasedAt = nil
	w.CoastToken = nil
	w.Model:SetAttribute("Rider", player.UserId)
	w.Model:SetAttribute("Reserved", 0)
	pcall(function()
		w.Root:SetNetworkOwner(player)
	end)
end

-- The server drives it again: it eases from the speed it has to the herd's and swims on down the lane from where it is
local function takeBack(w: Wild)
	w.CoastToken = nil
	if not w.Model.Parent or w.Rider then
		return
	end
	pcall(function()
		w.Root:SetNetworkOwner(nil)
	end)
	local velocity = w.Root.AssemblyLinearVelocity
	w.ReleaseSpeed = velocity.Magnitude
	w.ReleasedAt = os.clock()
	w.Dir = if velocity.Magnitude > 1 then velocity.Unit else w.Root.CFrame.LookVector
	placeInLane(w)
end

-- After the rider's weld is gone. With a hand-back time, the last rider's client keeps it that long, coasting.
function FishService.release(w: Wild, handBack: number?)
	w.Rider = nil
	w.Model:SetAttribute("Rider", 0)
	if not w.Model.Parent then
		return
	end
	w.Home = (Lane.project(lane, w.Root.Position))
	w.Slice = sliceAt(w.Home)
	w.Zone = Lane.zoneAt(lane, w.Home)
	if handBack and handBack > 0 then
		local token = {}
		w.CoastToken = token
		task.delay(handBack, function()
			if w.CoastToken == token then
				takeBack(w)
			end
		end)
	else
		takeBack(w)
	end
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
	-- straight down the lane: toward a point ahead, at its own place across the lane and above the floor. Past the
	-- last stocked zone it carries on level until the top-up takes it away.
	w.S += speed * dt
	local aheadS = math.min(w.S + Config.Herd.Ahead, lane.Length)
	local to = Lane.point(lane, aheadS, w.Across, w.Height) - position
	if to.Magnitude < 5 then
		local _, along = Lane.at(lane, aheadS)
		to = along
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
	parkedFolder = Instance.new("Folder")
	parkedFolder.Name = "ParkedFish"
	parkedFolder.Parent = ServerStorage
	zones = Zones.discover()
	lane = Lane.build(zones, Zones.pathJson())
	Net.Folder:SetAttribute("Zones", Zones.encode(zones))
	for i = 1, #zones do
		pools[i] = pool(i)
	end
	slices = newSlices()
	local empty = {}
	for i, zone in zones do
		if not hasRoster(i) then
			table.insert(empty, zone.Name)
		end
	end
	if #empty > 0 then
		print("[FishService] no fish types yet for " .. table.concat(empty, ", ") .. ": those zones stay empty")
	end
end

function FishService.Start()
	topUp(math.huge)
	RunService.Heartbeat:Connect(function(dt)
		for _, w in wild do
			if not w.Rider and not w.CoastToken and not w.Parked then
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
