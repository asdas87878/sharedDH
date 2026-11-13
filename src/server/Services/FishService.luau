--!strict
-- Wild fish: spawned per zone by the roster's rarity mix (each fish one or two zones past its home at most), spread
-- evenly over the whole dive lane, and swimming as a herd: all the same way, down the lane, each at its own place across
-- it and above the floor, at Herd.SpeedShare of the speed it is ridden at (as the reference's herds run along its track).
-- The herd's water is the stream (Lib/Stream, 2026-11-13): the lane's middle evened out, a band of open seabed measured
-- off the built map, and a floor with its steps rounded. A fish keeps three numbers for as long as it swims: its share
-- of the band's width (U), its lift above the floor, and how far along it is. Its path is the stream's line for those
-- numbers, so it is straight wherever the lane is, bends once and gently round a big thing in its way, and is decided
-- before it gets there. New fish go where there is the most room (bigger fish want more), and a big fish swims higher.
-- The lane's path (Shared.Lane) is cut into Spawn.Slice-stud slices, each zone's share of fish spread over its slices,
-- every slice keeping at least one (the dive board's keeps Spawn.BoardSlice). The herd drains downstream, so the top-up
-- keeps putting new fish into the emptiest slices, and takes away fish that have swum past the zones their kind lives
-- in, or into a crowded slice, once nobody is near.
-- Fish further than Spawn.StreamRadius from every player are parked in ServerStorage (not simulated, not sent to
-- clients) and come back when someone nears. A ridden fish belongs to its rider's client (network owner), which drives
-- it; once let go it stays with that client for Switch.HandBack seconds, coasting, so it doesn't hitch in front of them,
-- then the server takes it back and it joins the herd from where it is.
-- Every fish is its own (Hugo, 2026-11-12): now and then a variant (Config.Variant, Shared/Variants; the "Variant"
-- attribute), and its own speed (Config.speedOf: its species' own number in Config.FishStats, and its variant), which the herd, the
-- rider's client and the server's checks all use. There is no size roll for now (Hugo, the same day): every fish is
-- its species' size.
-- (2026-11-13, the user: sizes are back, as the reference has them. Every spawned fish is one of six sizes,
-- Config.SizeChance, rolled apart from its variant: its model, seat and body are its species' times Config.SizeScale,
-- its "Size" and "SizeTier" attributes say so. Size changes neither speed nor what a fish needs (Config.SizeWorth
-- is there for when it does). The herd's rules that go by a fish's length, Config.Herd and Config.Spawn, go by its own.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lane = require(ReplicatedStorage.Shared.Lane)
local Net = require(ReplicatedStorage.Shared.Net)
local Variants = require(ReplicatedStorage.Shared.Variants)
local Zones = require(ReplicatedStorage.Shared.Zones)
local FishModel = require(script.Parent.Parent.Lib.FishModel)
local LaneSurvey = require(script.Parent.Parent.Lib.LaneSurvey)
local Stream = require(script.Parent.Parent.Lib.Stream)
local PropService = require(script.Parent.PropService)

export type Wild = {
	Model: Model,
	Root: BasePart,
	Type: Config.FishType,
	Variant: string, -- "", "Silver", "Gold" or "Rainbow"
	SizeTier: string, -- its size's name (Config.SizeOrder)
	Grand: boolean, -- a Giant, a Huge or a Colossal (Config.Grand: the stocking keeps one or two in every stretch)
	Body: Vector3, -- its own width, height and length: Type.Size times its size's (Config.SizeScale)
	Zone: number,
	-- (2026-11-13: "along" is studs down the herd's stream, Lib/Stream, for fish and slices alike. The lane's own s is
	-- measured along its wandering middle, 28% longer on grey-box 15 and unevenly so; Stream.laneS gives it when the
	-- lane is asked something, such as which zone a place is in.)
	Home: number, -- how far along it is, as far as the stocking knows (kept up by the top-up)
	S: number, -- how far along it is now, carried forward as it swims
	U: number, -- its place across the herd's band, as a share of the band's half width (-1 to 1): kept for good
	Lift: number, -- and above the floor, in open water: kept for good
	A: number, -- where that puts it across the band just now, studs from the band's middle
	Give: number, -- how far it has moved aside for a fish it is passing, studs,
	GiveWant: number, -- and how far it should have
	Dodge: number, -- 1: its line bends round the big things in the lane; 0: straight through them (Herd.SmashLength)
	Space: number, -- the room it wants round it (Spawn.Space and its length)
	SyncAt: number, -- os.clock() its place along the stream was last read off where it really is
	Slice: number?, -- the slice it counts for (nil past the stocked zones)
	Parked: boolean,
	UnparkedAt: number, -- os.clock() it last came back into the Workspace (0: never parked)
	Dir: Vector3,
	Speed: number,
	Rider: Player?,
	Reserved: Player?,
	ReleasedAt: number?,
	ReleaseSpeed: number,
	CoastToken: {}?, -- set while the last rider's client still drives it after a dismount
	PropAt: number, -- os.clock() it last looked for a prop to break (only while inside a big thing's circle)
	SentAt: number, -- os.clock() its Swim and Turn were last written,
	SentDir: Vector3, -- and the way and the speed written then: they replicate to every client, so they are
	SentSpeed: number, -- written only when they have changed enough to see
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
local stream: Stream.Stream
local wild: { [Model]: Wild } = {}
-- every fish by where it is along the lane, in stretches of STOCK studs: what a new fish's place is weighed against
-- (made again at each top-up; a new fish is added as it is made)
local STOCK = 240
local stock: { [number]: { Wild } } = {}
local NO_FISH: { Wild } = {}
local SYNC = 0.5 -- seconds between reads of a fish's place along the stream off where it really is

FishService.Tag = FishModel.Tag

function FishService.zones(): { Zones.Zone }
	return zones
end

-- A fish's own ridden speed (its species, rarity, home land and variant), as Config has it now
function FishService.ridden(w: Wild): number
	return Config.speedOf(w.Type, w.Variant)
end

-- The roll for a new fish's variant. Studio only: the workspace's "TestVariant" attribute ("Gold" or "Rainbow") makes
-- every new fish that one, for looking at them.
local function rollVariant(): string
	local variant = Config.rollVariant(rng:NextNumber())
	if RunService:IsStudio() then
		local testVariant = workspace:GetAttribute("TestVariant")
		if testVariant == "Silver" or testVariant == "Gold" or testVariant == "Rainbow" then
			variant = testVariant
		end
	end
	return variant
end

-- The roll for a new fish's size, for a place with `grandNear` grand fish near it already (Config.Grand): with too
-- few, the fish is made grand; with enough, a fish that rolls grand is a Big. Studio only: the workspace's "TestSize"
-- attribute (a name of Config.SizeOrder) makes every new fish that size, for looking at them.
local function rollSize(grandNear: number): string
	local g = Config.Grand
	local tier = Config.rollSize(rng:NextNumber())
	if grandNear < g.Least then
		local roll = rng:NextNumber() * (g.Giant + g.Huge + g.Colossal)
		tier = if roll < g.Colossal then "Colossal" elseif roll < g.Colossal + g.Huge then "Huge" else "Giant"
	elseif grandNear >= g.Most and Config.isGrand(tier) then
		tier = "Big"
	end
	if RunService:IsStudio() then
		local testSize = workspace:GetAttribute("TestSize")
		if type(testSize) == "string" and Config.SizeScale[testSize] then
			tier = testSize
		end
	end
	return tier
end

-- A fish model made its size: the whole model and its seat (the seat's own height above the back is not scaled)
local function resize(model: Model, tier: string, scale: number)
	model:SetAttribute("SizeTier", tier)
	model:SetAttribute("Size", scale)
	if scale == 1 then
		return
	end
	model:ScaleTo(model:GetScale() * scale)
	local root = model.PrimaryPart
	local saddle = root and root:FindFirstChild("Saddle")
	if saddle and saddle:IsA("Attachment") then
		saddle.Position -= Vector3.new(0, Config.Ride.SeatHeight * (scale - 1), 0)
	end
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

-- (`near`: how many of each kind swim nearby, FishService's census. The rarity is rolled as ever; the kind is the
-- least seen nearby of Spawn.KindTries draws from that rarity's kinds, so the same fish doesn't come three in a row
-- where there are others to be had.)
local function pick(zoneIndex: number, near: { [string]: number }): Config.FishType?
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
				local best: Config.FishType? = nil
				for _ = 1, math.max(1, Config.Spawn.KindTries) do
					local drawn = options[#options].fish
					local r = rng:NextNumber() * sum
					for _, option in options do
						r -= option.weight
						if r <= 0 then
							drawn = option.fish
							break
						end
					end
					if not best or (near[drawn.Id] or 0) < (near[best.Id] or 0) then
						best = drawn
					end
				end
				return best
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
		local s0 = Stream.fromLane(stream, lane.ZoneStart[z])
		local s1 = Stream.fromLane(stream, lane.ZoneEnd[z])
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

-- (the slices run end to end down the lane, so the one that holds s is found by halving: this is asked for every
-- fish at every top-up, and walking all 250 slices each time was 100,000 steps)
local function sliceAt(s: number): number?
	local low, high = 1, #slices
	while low <= high do
		local mid = (low + high) // 2
		local slice = slices[mid]
		if s < slice.Start then
			high = mid - 1
		elseif s >= slice.End then
			low = mid + 1
		else
			return mid
		end
	end
	return nil
end

-- The room a fish with this body wants round it in the herd
local function spaceOf(body: Vector3): number
	return Config.Spawn.Space + body.Z * Config.Spawn.SpaceByLength
end

-- A new fish's way with the big things in the lane: 1, its line bends round them; 0, straight through them. The
-- longest always go straight through (Herd.SmashLength); of the rest, Herd.StraightShare do (the user, 2026-11-13:
-- "some gentle bends, some straight through").
local function rollDodge(body: Vector3): number
	local h = Config.Herd
	if body.Z >= h.SmashLength or rng:NextNumber() < h.StraightShare then
		return 0
	end
	return 1
end

-- How far above the herd's layer a fish with this body may swim, as a share of Spawn.BigRise: by its length
local function bigShare(body: Vector3): number
	local sp = Config.Spawn
	return math.clamp((body.Z - sp.BigLength) / math.max(sp.BigFull - sp.BigLength, 1), 0, 1)
end

-- The lowest and the highest a fish with this body swims above the floor in open water
local function liftRange(body: Vector3): (number, number)
	local sp = Config.Spawn
	local low = math.max(math.min(sp.HeightMin, sp.HeightMax), body.Y / 2 + sp.Belly)
	return low, math.max(low, sp.HeightMax + sp.BigRise * bigShare(body))
end

-- A new fish's lift: somewhere in the herd's layer, and above it by its size (a big fish is seen over the others)
local function rollLift(body: Vector3, s: number): number
	local sp = Config.Spawn
	local low, high = liftRange(body)
	local lift = rng:NextNumber(math.min(sp.HeightMin, sp.HeightMax), math.max(sp.HeightMin, sp.HeightMax))
		+ sp.BigRise * bigShare(body) * rng:NextNumber(0.4, 1)
	-- under an arch, a shelf or a sign, keep clear of the roof (the map's Path c)
	local roof = Lane.clearanceAt(lane, Stream.laneS(stream, s))
	if roof then
		high = math.min(high, roof - sp.RoofGap - body.Y / 2)
	end
	return math.clamp(lift, low, math.max(low, high))
end

-- How much room a place has: the nearest fish to it, in shares of the room the two of them want (1: just enough;
-- less: too near). Height counts double, so two fish one above the other are not "apart".
local function roomAt(s: number, across: number, lift: number, space: number): number
	local best = math.huge
	local bucket = math.floor(s / STOCK)
	for b = bucket - 1, bucket + 1 do
		for _, o in stock[b] or NO_FISH do
			local ds = o.S - s
			if ds > -STOCK and ds < STOCK then
				local da = o.A - across
				local dl = (o.Lift - lift) * 2
				local d = math.sqrt(ds * ds + da * da + dl * dl) / (space + o.Space)
				if d < best then
					best = d
				end
			end
		end
	end
	return best
end

local function addToStock(w: Wild)
	local bucket = math.floor(w.S / STOCK)
	stock[bucket] = stock[bucket] or {}
	table.insert(stock[bucket], w)
end

-- Where a fish is in the stream, from its position: s along it, its share of the band and its lift (kept inside what
-- a fish of its kind uses). For a fish that didn't get its place from the stocking: one just let go, or put in by hand.
local function placeInStream(w: Wild)
	local position = w.Root.Position
	local s, across = Stream.project(stream, position)
	local low, high = liftRange(w.Body)
	w.S = s
	w.U = Stream.share(stream, s, across)
	w.A = across
	w.Give = 0
	w.GiveWant = 0
	w.Lift = math.clamp(position.Y - Stream.floor(stream, s, across), low, high)
end

-- Where the players are, read at most five times a second and kept: the top-up asks "is a player near?" once or twice
-- for each of 800 fish, and looking every player's root part up each time was most of its cost
local playerAt: { Vector3 } = {}
local playersReadAt = -1
-- a place that counts as having a player near, whoever is there (FishService.keepNear): the fish round it stay in the
-- Workspace, so they are never new to anyone's machine. The sandbox's start is one (Studio only).
local keptPlace: Vector3? = nil
local function readPlayers()
	if os.clock() - playersReadAt < 0.2 then
		return
	end
	playersReadAt = os.clock()
	table.clear(playerAt)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(playerAt, root.Position)
		end
	end
	if keptPlace then
		table.insert(playerAt, keptPlace)
	end
end

local function nearAPlayer(position: Vector3, radius: number): boolean
	readPlayers()
	for _, at in playerAt do
		if (at - position).Magnitude < radius then
			return true
		end
	end
	return false
end

-- How far the nearest player is from a point (math.huge with nobody in the game)
local function nearestPlayer(position: Vector3): number
	readPlayers()
	local best = math.huge
	for _, at in playerAt do
		best = math.min(best, (at - position).Magnitude)
	end
	return best
end

local function park(w: Wild, parked: boolean)
	if w.Parked == parked then
		return
	end
	w.Parked = parked
	w.Model.Parent = if parked then parkedFolder else folder
	if not parked then
		w.UnparkedAt = os.clock()
		pcall(function()
			w.Root:SetNetworkOwner(nil)
		end)
	end
end

-- A new fish of this kind and variant at a place in the lane, parked (the caller decides whether it is in the water)
local function make(
	fishType: Config.FishType,
	variant: string,
	home: number,
	at: Vector3,
	dir: Vector3,
	zone: number,
	slice: number?,
	u: number?,
	lift: number?,
	dodge: number?,
	sizeTier: string?
): Wild
	local model = FishModel.build(fishType)
	local tier = sizeTier or "Normal"
	local scale = Config.sizeScale(tier, fishType)
	local body = fishType.Size * scale
	resize(model, tier, scale)
	model:SetAttribute("Variant", variant)
	-- its passive archetypes (Config.FishStats; docs/design/archetypes.md): "" for none, more than one comma-separated.
	-- The hook for the passives and for the partner's animations
	model:SetAttribute("Archetype", fishType.Archetype)
	Variants.apply(model, variant)
	model:PivotTo(CFrame.lookAt(at, at + dir))
	local root = model.PrimaryPart :: BasePart
	local w: Wild = {
		Model = model,
		Root = root,
		Type = fishType,
		Variant = variant,
		SizeTier = tier,
		Grand = Config.isGrand(tier),
		Body = body,
		Zone = zone,
		Home = home,
		S = home,
		U = u or 0,
		Lift = lift or Config.Spawn.HeightMin,
		A = 0,
		Give = 0,
		GiveWant = 0,
		Dodge = dodge or rollDodge(body),
		Space = spaceOf(body),
		SyncAt = os.clock() + rng:NextNumber(0, SYNC),
		Slice = slice,
		Parked = true,
		UnparkedAt = 0,
		Dir = dir,
		Speed = Config.speedOf(fishType, variant) * Config.Herd.SpeedShare,
		Rider = nil,
		Reserved = nil,
		ReleasedAt = nil,
		ReleaseSpeed = 0,
		CoastToken = nil,
		PropAt = 0,
		SentAt = 0,
		SentDir = Vector3.zAxis,
		SentSpeed = -1,
		Swim = root:FindFirstChild("Swim") :: LinearVelocity,
		Turn = root:FindFirstChild("Turn") :: AlignOrientation,
		Saddle = root:FindFirstChild("Saddle") :: Attachment,
	}
	model.Parent = parkedFolder
	wild[model] = w
	if u and lift then
		w.A = Stream.across(stream, home, u, 0, w.Dodge, body.X / 2)
	else
		placeInStream(w)
	end
	addToStock(w)
	model.Destroying:Connect(function()
		wild[model] = nil
	end)
	return w
end

-- How many fish each slice has been given a place for, for spreading them across the band (placeFor)
local placed: { [number]: number } = {}

-- A place in a slice for a fish of this kind: of Spawn.Tries places, the one with the most room round it (roomAt). Half
-- the tries walk evenly across the band from where the slice's last fish went, so the band is filled from side to
-- side; the rest are anywhere. A place near a player counts for much less (a new fish appeared out of nothing 0 to 120
-- studs from a player standing at the lane's start, about one a second), and one inside a big thing, for a fish that
-- doesn't go round them, for nothing. `size`: the fish's own width, height and length; `clearOf`: how far from every
-- player the place should be; `dodge`: the fish's way with the big things (rollDodge).
-- Returns how far along it is, the place itself, and the fish's share of the band and its lift there.
local function placeFor(index: number, size: Vector3, clearOf: number, dodge: number): (number, Vector3, number, number)
	local slice = slices[index]
	local sp = Config.Spawn
	local space, body = spaceOf(size), size.X / 2
	local count = placed[index] or 0
	placed[index] = count + 1
	local bestScore = -1
	local home, at, bestU, bestLift = slice.Start, Vector3.zero, 0, sp.HeightMin
	for try = 1, math.max(1, sp.Tries) do
		local s = rng:NextNumber(slice.Start, slice.End)
		local u = if try % 2 == 1
			then ((count * 0.618034 + try * 0.381966 + index * 0.271) % 1) * 2 - 1
			else rng:NextNumber(-1, 1)
		local lift = rollLift(size, s)
		local across = Stream.across(stream, s, u, 0, dodge, body)
		local point = Stream.point(stream, s, across, lift)
		local score = math.min(roomAt(s, across, lift, space), 4)
		local clear = nearestPlayer(point)
		if clear < clearOf then
			score *= 0.2 * clear / clearOf
		end
		if dodge == 0 and Stream.inside(stream, s, point.X, point.Z) then
			score *= 0.05
		end
		if score > bestScore then
			bestScore, home, at, bestU, bestLift = score, s, point, u, lift
		end
	end
	return home, at, bestU, bestLift
end

-- Who swims near a place: how many grand fish, and how many of each kind, within half of Grand.Span either way
local function census(s: number): (number, { [string]: number })
	local reach = Config.Grand.Span / 2
	local grand = 0
	local kinds: { [string]: number } = {}
	local bucket = math.floor(s / STOCK)
	for b = bucket - 2, bucket + 2 do
		for _, o in stock[b] or NO_FISH do
			if math.abs(o.S - s) <= reach then
				if o.Grand then
					grand += 1
				end
				kinds[o.Type.Id] = (kinds[o.Type.Id] or 0) + 1
			end
		end
	end
	return grand, kinds
end

local function spawnFish(index: number): Wild?
	local slice = slices[index]
	if not slice then
		return nil
	end
	local grandNear, kinds = census((slice.Start + slice.End) / 2)
	local fishType = pick(slice.Zone, kinds)
	if not fishType then
		return nil
	end
	local tier = rollSize(grandNear)
	local body = fishType.Size * Config.sizeScale(tier, fishType)
	local dodge = rollDodge(body)
	local home, at, u, lift = placeFor(index, body, Config.Spawn.AppearClear, dodge)
	local along = Stream.along(stream, home)
	local w = make(fishType, rollVariant(), home, at, along, slice.Zone, index, u, lift, dodge, tier)
	park(w, not nearAPlayer(at, Config.Spawn.StreamRadius))
	return w
end

-- A fish that has just swum out of everyone's sight is given a new place in the slice it has reached, where there is
-- the most room, and waits there (parked). Left where they stopped, such fish piled up in a row at the edge of
-- Spawn.StreamRadius: every fish stops at the same distance from a player who is standing still, or leaving them behind.
local function reseat(w: Wild, index: number)
	local home, at, u, lift = placeFor(index, w.Body, Config.Spawn.StreamRadius + 30, w.Dodge)
	local dir = Stream.along(stream, home)
	w.S, w.Home, w.U, w.Lift = home, home, u, lift
	w.Give, w.GiveWant = 0, 0
	w.A = Stream.across(stream, home, u, 0, w.Dodge, w.Body.X / 2)
	w.Dir = dir
	w.ReleasedAt = nil
	w.Model:PivotTo(CFrame.lookAt(at, at + dir))
	w.Root.AssemblyLinearVelocity = Vector3.zero
	w.Root.AssemblyAngularVelocity = Vector3.zero
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
	table.clear(stock)
	for _, w in wild do
		addToStock(w)
	end
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
			-- (its place along the lane is kept true as it swims: steer reads it off where the fish really is every
			-- SYNC seconds)
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
				w.Zone = Lane.zoneAt(lane, Stream.laneS(stream, w.S))
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
			elseif not near and not w.Parked and slice then
				-- (parked first: the move is then not sent to anyone)
				park(w, true)
				reseat(w, slice)
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
	placeInStream(w)
	w.SyncAt = os.clock()
end

-- After the rider's weld is gone. With a hand-back time, the last rider's client keeps it that long, coasting.
function FishService.release(w: Wild, handBack: number?)
	w.Rider = nil
	w.Model:SetAttribute("Rider", 0)
	if not w.Model.Parent then
		return
	end
	w.Home = (Stream.project(stream, w.Root.Position))
	w.Slice = sliceAt(w.Home)
	w.Zone = Lane.zoneAt(lane, Stream.laneS(stream, w.Home))
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

-- Passing (Herd.Give*): fish swim at their own speeds, so one catches another up on the same line. Each pair that is
-- about to overlap gives way, half each, to the side each is already on, by how much they would overlap and how near
-- they are nose to tail; steer moves a fish toward that slowly, and back once the other has gone by.
local passing: { Wild } = {}
local function giveWay()
	local h = Config.Herd
	table.clear(passing)
	for _, w in wild do
		if not w.Parked and not w.Rider and not w.CoastToken then
			w.GiveWant = 0
			table.insert(passing, w)
		end
	end
	for i = 1, #passing - 1 do
		local a = passing[i]
		for j = i + 1, #passing do
			local b = passing[j]
			local along = (a.Body.Z + b.Body.Z) / 2 + h.GiveAlong
			local ds = math.abs(a.S - b.S)
			if ds < along then
				local side = (a.Body.X + b.Body.X) / 2 + h.GiveSide
				local across = a.A - b.A
				local short = side - math.abs(across)
				if short > 0 and math.abs(a.Lift - b.Lift) < (a.Body.Y + b.Body.Y) / 2 + 2 then
					local push = short / 2 * (1 - ds / along)
					local way = if across > 0 then 1 elseif across < 0 then -1 elseif a.U >= b.U then 1 else -1
					a.GiveWant += way * push
					b.GiveWant -= way * push
				end
			end
		end
	end
end

local function steer(w: Wild, dt: number)
	local h = Config.Herd
	local position = w.Root.Position
	local speed = FishService.ridden(w) * h.SpeedShare
	if w.ReleasedAt then
		local t = (os.clock() - w.ReleasedAt) / Config.Ride.SlowDownTime
		if t >= 1 then
			w.ReleasedAt = nil
		else
			speed = w.ReleaseSpeed + (speed - w.ReleaseSpeed) * t
		end
	end
	-- its place along the stream: carried forward by its speed, and every SYNC seconds read off where it really is
	local now = os.clock()
	if now - w.SyncAt >= SYNC then
		w.SyncAt = now
		w.S = (Stream.project(stream, position, w.S))
	else
		w.S = math.min(w.S + speed * dt, stream.Length)
	end
	if w.Give ~= w.GiveWant then
		local step = h.GiveRate * dt
		w.Give += math.clamp(w.GiveWant - w.Give, -step, step)
	end
	-- down its own line of the stream: toward the point of that line Herd.Ahead further on. The line is smooth, so the
	-- fish swims straight where the lane is straight; nothing here looks at what is round it. Past the lane's end it
	-- carries on level until the top-up takes it away.
	local aheadS = math.min(w.S + h.Ahead, stream.Length)
	local across = Stream.across(stream, aheadS, w.U, w.Give, w.Dodge, w.Body.X / 2)
	w.A = across
	local want: Vector3
	if aheadS >= stream.Length - 1 then
		want = Stream.along(stream, aheadS)
	else
		local to = Stream.point(stream, aheadS, across, w.Lift) - position
		want = if to.Magnitude < 5 then Stream.along(stream, aheadS) else to.Unit
		want = Vector3.new(want.X, math.clamp(want.Y, -0.45, 0.45), want.Z).Unit
	end
	w.Dir = w.Dir:Lerp(want, 1 - math.exp(-h.Turn * dt)).Unit
	w.Speed = speed
	-- inside one of the big things (a fish that goes round nothing, or one pressed against the band's edge): a fish
	-- whose kind breaks props (Hugo's rule, Config.breaks: a Tank, a Breaker or a giant; Props.WildBreaks 0 turns it
	-- off) and that is itself at least Herd.BreakLength long breaks the boxes it touches, as a ridden fish does
	-- (PropService), looked for a few times a second. Any other fish swims through and leaves the thing whole, as the
	-- reference's small dinos do.
	if now - w.PropAt >= Config.Props.WildEvery then
		w.PropAt = now
		if
			Config.Props.WildBreaks ~= 0
			and w.Body.Z >= h.BreakLength
			and Config.breaks(w.Type)
			and Stream.inside(stream, w.S, position.X, position.Z)
		then
			local size = w.Body
			PropService.hit(
				position + w.Dir * (size.Z / 2),
				w.Dir * speed,
				math.max(size.X, size.Y) / 2 + Config.Props.Reach
			)
		end
	end
	-- (both replicate to every client: written when the way has turned about a degree or the speed has changed half a
	-- stud a second, and twice a second whatever, in case a rider's machine left them at something else)
	if now - w.SentAt > 0.5 or math.abs(speed - w.SentSpeed) > 0.5 or (w.Dir - w.SentDir).Magnitude > 0.017 then
		w.SentAt = now
		w.SentDir = w.Dir
		w.SentSpeed = speed
		w.Swim.VectorVelocity = w.Dir * speed
		w.Turn.CFrame = CFrame.lookAt(Vector3.zero, w.Dir)
	end
end

-- How far inside the lane's edge a place is, studs across (negative: beyond it). For telling the lane's own walls
-- from what stands in it (RideService.checkCrash: the edge is a wall ride, Config.Wall)
function FishService.inside(position: Vector3): number
	local s = Lane.project(lane, position)
	local centre, along, width = Lane.at(lane, s)
	local right = along:Cross(Vector3.yAxis)
	return width / 2 - math.abs((position - centre):Dot(right))
end

-- A point in the middle of the lane at the herd's height (kept under the surface), and the way down the lane there
function FishService.lanePoint(s: number): (Vector3, Vector3)
	local _, along = Lane.at(lane, s)
	local at = Lane.point(lane, s, 0, Config.Herd.RideHeight)
	return Vector3.new(at.X, math.min(at.Y, Config.Oxygen.SurfaceY - 8), at.Z), along
end

-- The nearest fish in the water a player could get on
-- Fish round this place are kept in the Workspace (nil: none). One place at a time.
function FishService.keepNear(place: Vector3?)
	keptPlace = place
	playersReadAt = -1
end

-- (`settled`: only a fish that has been in the Workspace this many seconds. One that has just come back is, for a
-- moment, still somewhere else on the players' machines.)
function FishService.nearest(position: Vector3, radius: number, player: Player, settled: number?): Wild?
	local best: Wild? = nil
	local bestDistance = radius
	local since = os.clock() - (settled or 0)
	for _, w in wild do
		-- (and with `settled`, not one a rider's machine is still driving or has only just given back)
		local calm = settled == nil
			or (w.UnparkedAt <= since and not w.CoastToken and (not w.ReleasedAt or w.ReleasedAt <= since - 2))
		if not w.Parked and calm and FishService.isFree(w, player) then
			local distance = (w.Root.Position - position).Magnitude
			if distance < bestDistance then
				best = w
				bestDistance = distance
			end
		end
	end
	return best
end

-- A Predator's bite (RideService; Config.Archetype.Predator): the wild fish, no longer than `longest`, whose body
-- comes within `reach` of the point `nose`; the nearest, or nil. Never a fish with a rider, one kept for a player's
-- hop, one a player's machine is still driving after a hop off it, or a parked one.
function FishService.prey(hunter: Wild, nose: Vector3, reach: number, longest: number): Wild?
	local best: Wild? = nil
	local bestGap = math.huge
	for _, w in wild do
		if
			w ~= hunter
			and not w.Parked
			and not w.Rider
			and not w.Reserved
			and not w.CoastToken
			and w.Body.Z <= longest
		then
			local at = w.Root.Position
			local to = nose - at
			-- (a quick no for nearly every fish in the sea, before anything is measured)
			local far = reach + w.Body.Z
			if math.abs(to.X) < far and math.abs(to.Y) < far and math.abs(to.Z) < far then
				-- from the nose to the nearest point of its spine, less its own half width
				local look = w.Root.CFrame.LookVector
				local half = w.Body.Z / 2
				local along = math.clamp(to:Dot(look), -half, half)
				local gap = (to - look * along).Magnitude - math.max(w.Body.X, w.Body.Y) / 2
				if gap <= reach and gap < bestGap then
					best = w
					bestGap = gap
				end
			end
		end
	end
	return best
end

-- Eaten: gone from the sea at once. Its slice of the lane is now a fish short, so the herd's top-up puts a new one in
-- (Spawn.TopUpEvery, away from every player: Spawn.AppearClear).
function FishService.eat(w: Wild)
	w.Model:Destroy()
end

-- Studio only (the sandbox's "Ride": a chosen fish to try): a fish of this kind and variant put in the water at a
-- place, swimming `dir`. nil for a kind there is none of. Its size is Normal, or the workspace's "TestSize".
function FishService.spawnTest(id: string, variant: string, at: Vector3, dir: Vector3): Wild?
	local fishType = Config.FishById[id]
	if not fishType or not RunService:IsStudio() then
		return nil
	end
	local home = (Stream.project(stream, at))
	local w = make(
		fishType,
		if variant == "Silver" or variant == "Gold" or variant == "Rainbow" then variant else "",
		home,
		at,
		dir,
		Lane.zoneAt(lane, Stream.laneS(stream, home)),
		sliceAt(home)
	)
	park(w, false)
	return w
end

-- After the sandbox changes how many fish there should be: the slices' shares again; the top-up does the rest
function FishService.restock()
	local fresh = newSlices()
	for i, slice in fresh do
		if slices[i] then
			slices[i].Want = slice.Want
		end
	end
end

function FishService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Fish"
	folder.Parent = workspace
	parkedFolder = Instance.new("Folder")
	parkedFolder.Name = "ParkedFish"
	parkedFolder.Parent = ServerStorage
	zones = Zones.discover()
	-- the lane's floor is read off the built map, not taken from the design's curve (Lib/LaneSurvey says why)
	local pathJson = LaneSurvey.run(Zones.pathJson())
	lane = Lane.build(zones, pathJson)
	-- Roblox destroys whatever falls below this, fish and players alike, and only Studio can change it (not a script)
	local lowest = 0
	for _, point in lane.Points do
		lowest = math.min(lowest, point.Y)
	end
	if lowest < workspace.FallenPartsDestroyHeight + 200 then
		warn(
			string.format(
				"[FishService] the lane goes down to y = %d but Workspace.FallenPartsDestroyHeight is %d: fish and players are destroyed below it. Set it lower in Studio (the map script should).",
				lowest,
				workspace.FallenPartsDestroyHeight
			)
		)
	end
	Net.Folder:SetAttribute("Zones", Zones.encode(zones))
	-- the clients build the same lane, to keep what they move themselves inside it (src/client/Lib/Course.luau)
	Net.Folder:SetAttribute("LanePath", pathJson or "")
	-- the herd's own water, worked out from the lane and the built map (Lib/Stream says why and how)
	stream = Stream.build(lane, Zones.bigAssets())
	print("[FishService] the herd's stream: " .. stream.Report)
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
	local gaveAt = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		if now - gaveAt >= Config.Herd.GiveEvery then
			gaveAt = now
			giveWay()
		end
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
