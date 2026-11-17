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
	-- how it swims (Config.Pace; steer and its helpers)
	Pace: string, -- its kind's character: "Cruise", "Plod", "Zoom", "Dart" or "Hunt"
	Own: number, -- its own pace, times its kind's (a little either side of 1), and its size's (Config.SizePace)
	Land: number, -- the ride pace of the land where it is (Config.LandPace), read again every SYNC seconds
	Gait: number, -- the share of that pace it swims at now (a Hunt: of its own ridden speed). It changes over a moment, never at once
	Lead: number, -- a Dart's: how far ahead of its place in the herd its burst has carried it, studs
	Phase: number, -- where it is in its lurch (a Plod), radians
	Mode: number, -- a Hunt's: 0 cruising high, 1 stooping, 2 running through the herd, 3 climbing back
	NextAt: number, -- os.clock() of its next burst (a Dart) or the next time it may stoop (a Hunt)
	Until: number, -- os.clock() its burst, or its run through the herd, ends
	Rise: number, -- how far above its place in the herd it is now, studs (a Hunt),
	RiseWant: number, -- and where that is going
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
	Swift: number, -- how much faster than its kind it is ridden (1; Config.Pace.FastRide for a fish born fast, BoltRide for a bolt)
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
-- the hunters that are in the herd now (stooping, or running through it): one at a time in any one place (Config.Pace)
local stooping: { [Wild]: boolean } = {}
local SYNC = 0.5 -- seconds between reads of a fish's place along the stream off where it really is
-- where each land starts, studs down the stream (Init)
local zoneFrom: { number } = {}
-- each land's first slice (newSlices)
local zoneSlice: { [number]: number } = {}

FishService.Tag = FishModel.Tag

function FishService.zones(): { Zones.Zone }
	return zones
end

-- A fish's own ridden speed (its species, rarity, home land and variant), as Config has it now
function FishService.ridden(w: Wild): number
	return Config.speedOf(w.Type, w.Variant) * w.Swift
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

-- The roll for a new fish's size, by its rarity (Config.SizeLarge), for a place with `grandNear` grand fish near it
-- already (Config.Grand): with too few, the fish is made grand (a Common seldom: the stretch waits for a rarer fish);
-- with enough, a fish that rolls grand is a Big. Studio only: the workspace's "TestSize" attribute (a name of
-- Config.SizeOrder) makes every new fish that size, for looking at them.
local function rollSize(grandNear: number, fishType: Config.FishType): string
	local g = Config.Grand
	local tier = Config.rollSize(rng:NextNumber(), fishType.Tier)
	if grandNear < g.Least and (fishType.Tier ~= "Common" or rng:NextNumber() < g.Common) then
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
			-- how full each slice is to be, by how wide the herd's band is there (Spawn.FullBand, Spawn.ThinLeast)
			local full: { number } = table.create(n, 1)
			local sum = 0
			for k = 1, n do
				local middle = s0 + length * (k - 0.5) / n
				local band = Stream.width(stream, middle)
				full[k] = math.clamp(band / math.max(sp.FullBand, 1), math.clamp(sp.ThinLeast, 0.05, 1), 1)
				sum += full[k]
			end
			local want = math.max(n, math.clamp(math.floor(length / 1000 * sp.PerThousand * sum / n), sp.Min, sp.Max))
			local dealt = 0
			for k = 1, n do
				-- the zone's fish shared out by that, as evenly as whole numbers allow
				local before = dealt
				dealt += full[k] / sum
				local share = math.floor(want * dealt + 1e-6) - math.floor(want * before + 1e-6)
				if k == 1 then
					zoneSlice[z] = #list + 1
				end
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

-- The layer a fish of this character swims in, studs above the floor, from and to (Config.Layer)
local function layerOf(pace: string): (number, number)
	local layer = Config.Layer[pace] or Config.Layer.Cruise
	local a, b = layer[1] or Config.Spawn.HeightMin, layer[2] or Config.Spawn.HeightMax
	return math.min(a, b), math.max(a, b)
end

-- How far over its layer a big fish of this character may swim (a plodder: not at all, the herd is over it)
local function riseOf(body: Vector3, pace: string): number
	return if pace == "Plod" then 0 else Config.Spawn.BigRise * bigShare(body)
end

-- The lowest and the highest the middle of a fish with this body and character is above the floor in open water: its
-- whole body inside its layer (Config.Layer), belly on the layer's floor at the lowest
local function liftRange(body: Vector3, pace: string): (number, number)
	local sp = Config.Spawn
	local from, to = layerOf(pace)
	local low = math.max(from, sp.Belly) + body.Y / 2
	return low, math.max(low, to - body.Y / 2 + riseOf(body, pace))
end

-- A new fish's lift: somewhere in its character's layer, and above it by its size (a big fish is seen over the others)
local function rollLift(body: Vector3, s: number, pace: string): number
	local sp = Config.Spawn
	local low, high = liftRange(body, pace)
	local lift = rng:NextNumber(low, math.max(low, high - riseOf(body, pace)))
		+ riseOf(body, pace) * rng:NextNumber(0.4, 1)
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
				local dl = (o.Lift - lift) * Config.Spawn.LiftRoom
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
	local low, high = liftRange(w.Body, w.Pace)
	w.S = s
	w.Lead = 0
	w.U = Stream.share(stream, s, across)
	w.A = across
	w.Give = 0
	w.GiveWant = 0
	w.Lift = math.clamp(position.Y - Stream.floor(stream, s, across), low, high)
	-- (a hunter let go low in the herd climbs back to where it cruises)
	w.Rise = 0
	w.RiseWant = 0
	w.Mode = if w.Pace == "Hunt" then 3 else 0
	stooping[w] = nil
end

-- Where the players are, read at most five times a second and kept: the top-up asks "is a player near?" once or twice
-- for each of 800 fish, and looking every player's root part up each time was most of its cost
local playerAt: { Vector3 } = {}
local playersReadAt = -1
-- a place that counts as having a player near, whoever is there (FishService.keepNear): the fish round it stay in the
-- Workspace, so they are never new to anyone's machine. The sandbox's start is one (Studio only).
local keptPlace: Vector3? = nil
-- and one more such place for each player the submarine is carrying (FishService.keepFor): where they will be dropped
local keptFor: { [Player]: Vector3 } = {}
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
	for _, place in keptFor do
		table.insert(playerAt, place)
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

-- The highest a fish's middle may be: under the surface by half its height and a little
local function ceilingFor(body: Vector3): number
	return Config.Oxygen.SurfaceY - body.Y / 2 - 4
end

-- How far over its place in the herd a hunter cruises
local function huntHigh(w: Wild): number
	return Config.Pace.HuntHigh + w.Body.Y / 2
end

-- The dive-in (Config.Dive; docs/design/dive-in.md): how much of the gate's gathering a place along the stream has,
-- 1 at the lane's start easing to 0 at Dive.RampTo. The sea is slower by it (landPace) and higher (gateRise).
local function gateEase(s: number): number
	local to = Config.Dive.RampTo
	if to <= 0 then
		return 0
	end
	local u = math.clamp(s / to, 0, 1)
	return 1 - u * u * (3 - 2 * u)
end

-- How far over its place in the herd a fish swims because of the gate: up toward the surface where the dive begins
local function gateRise(s: number): number
	return Config.Dive.Rise * gateEase(s)
end

-- The ride pace of the land at a place along the stream (Config.LandPace), eased across each border so the herd
-- never changes speed at a line
local function landPace(s: number): number
	local list = Config.LandPace
	local z = 1
	for i = #zoneFrom, 1, -1 do
		if s >= zoneFrom[i] then
			z = i
			break
		end
	end
	local here = list[z] or list[#list] or Config.Speed.Base
	local blend = Config.Pace.LandBlend
	if blend > 0 then
		local nextFrom = zoneFrom[z + 1]
		if nextFrom and nextFrom - s < blend / 2 then
			local after = list[z + 1] or here
			here += (after - here) * (0.5 - (nextFrom - s) / blend)
		elseif z > 1 and s - zoneFrom[z] < blend / 2 then
			local before = list[z - 1] or here
			here = before + (here - before) * (0.5 + (s - zoneFrom[z]) / blend)
		end
	end
	-- (and slower at the gate, where the sea gathers for the dive-in)
	return here * Config.Pace.Land * (1 - (1 - Config.Dive.GateShare) * gateEase(s))
end

-- How fast a fish swims on average, studs a second: what it does out of sight, where it is only a number. A darter's
-- bursts and a plodder's lurches come to nothing over time, so they are not in it.
local function meanSpeed(w: Wild): number
	local p = Config.Pace
	if w.Pace == "Hunt" then
		return landPace(w.S) * p.Hunt * w.Own
	end
	local share = if w.Pace == "Plod" then p.Plod elseif w.Pace == "Zoom" then p.Zoom else Config.Herd.SpeedShare
	return landPace(w.S) * share * w.Own
end

-- The share of the land's pace a wild fish wants to swim at now, by its character (Config.Pace); a Hunt's was of its
-- own ridden speed until 2026-11-17. For a Dart this starts and ends its bursts and brings it back to its place; for a Hunt it is the
-- whole of its round: cruising high, the stoop when a player is near, the run through the herd, the climb back (it
-- sets where its Rise is going).
local function paceShare(w: Wild, now: number, position: Vector3): number
	local p = Config.Pace
	local pace = w.Pace
	local share = Config.Herd.SpeedShare
	if pace == "Cruise" and p.CruiseSurge ~= 0 then
		-- each fish of the herd a little faster and slower in its own slow beat (its Phase gives the beat and where
		-- it is in it): mean nothing, so it keeps its place
		local beat = math.max(p.CruiseBeat, 0.5) * (0.7 + 0.6 * ((w.Phase * 7.31) % 1))
		share *= 1 + p.CruiseSurge * math.sin(now * math.pi * 2 / beat + w.Phase)
	end
	if pace == "Plod" then
		share = p.Plod * (1 + p.PlodLurch * math.sin(now * math.pi * 2 / math.max(p.PlodBeat, 0.1) + w.Phase))
	elseif pace == "Zoom" then
		share = p.Zoom
	elseif pace == "Dart" then
		if now < w.Until then
			share = p.DartBurst
		elseif w.Lead > 0 then
			-- ahead of its place: it drifts back, slower than the herd
			share = math.min(p.Dart, share)
		elseif w.NextAt <= 0 then
			-- back in its place: with the herd until the next burst
			w.NextAt = now + rng:NextNumber(p.DartEveryMin, math.max(p.DartEveryMin, p.DartEveryMax))
		elseif now >= w.NextAt then
			w.Until = now + p.DartTime
			w.NextAt = 0
			share = p.DartBurst
		end
		-- (over the fish ahead of it while it is out of its place, and down again as it comes back)
		w.RiseWant = if now < w.Until or w.Lead > 6 then p.DartRise else 0
	elseif pace == "Hunt" then
		local high = huntHigh(w)
		if w.Mode == 0 then
			w.RiseWant = high
			share = p.Hunt
			if now >= w.NextAt then
				w.NextAt = now + 1
				if nearAPlayer(position, p.HuntRange) then
					-- (not while another is at it nearby: one hunter coming through is a thing to see, five at once
					-- is the herd)
					local alone = true
					for other in stooping do
						if (other.Root.Position - position).Magnitude < p.HuntApart then
							alone = false
							break
						end
					end
					if alone then
						w.Mode = 1
						stooping[w] = true
					end
				end
			end
		elseif w.Mode == 1 then
			w.RiseWant = 0
			share = p.HuntRun
			if w.Rise <= 1 then
				w.Mode = 2
				w.Until = now + p.HuntRunTime
				w.NextAt = now + p.HuntRunMost
			end
		elseif w.Mode == 2 then
			w.RiseWant = 0
			share = p.HuntRun
			if now >= w.Until then
				-- not before it has gone past: with a player still just ahead of it, it runs on (to HuntRunMost)
				local chasing = false
				if now < w.NextAt then
					readPlayers()
					for _, at in playerAt do
						local to = at - position
						local ahead = to:Dot(w.Dir)
						if ahead > -p.HuntPast and ahead < 300 and to.Magnitude < 320 then
							chasing = true
							break
						end
					end
				end
				if chasing then
					w.Until = now + 0.3
				else
					w.Mode = 3
					stooping[w] = nil
				end
			end
		else
			-- (climbing back: at its own pace too. It was left at the herd's share here, so a hunter that had gone
			-- past a player dropped from its pace to the herd's: found 2026-11-17, 89 studs a second to 60)
			share = p.Hunt
			w.RiseWant = high
			if w.Rise >= high - 2 then
				w.Mode = 0
				w.NextAt = now + rng:NextNumber(p.HuntEveryMin, math.max(p.HuntEveryMin, p.HuntEveryMax))
			end
		end
	end
	return share * w.Own
end

local function park(w: Wild, parked: boolean)
	if w.Parked == parked then
		return
	end
	w.Parked = parked
	w.Model.Parent = if parked then parkedFolder else folder
	if parked then
		-- out of sight it swims on as a number (the top-up): a darter in its place, a hunter cruising high
		w.Lead = 0
		w.Until = 0
		w.Give, w.GiveWant = 0, 0
		w.ReleasedAt = nil
		if w.Pace == "Hunt" then
			w.Mode = 0
			stooping[w] = nil
			w.RiseWant = huntHigh(w)
			w.Rise = w.RiseWant
		else
			w.Rise, w.RiseWant = 0, 0
		end
	else
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
	sizeTier: string?,
	pace: string?,
	own: number?,
	swift: number?
): Wild
	local model = FishModel.build(fishType)
	local tier = sizeTier or "Normal"
	local scale = Config.sizeScale(tier, fishType)
	local body = fishType.Size * scale
	resize(model, tier, scale)
	model:SetAttribute("Variant", variant)
	model:SetAttribute("Pace", pace or Config.paceOf(fishType))
	model:SetAttribute("Swift", swift or 1)
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
		Lift = lift or (layerOf(pace or Config.paceOf(fishType))),
		A = 0,
		Give = 0,
		GiveWant = 0,
		Dodge = dodge or rollDodge(body),
		Space = spaceOf(body),
		SyncAt = os.clock() + rng:NextNumber(0, SYNC),
		Pace = pace or Config.paceOf(fishType),
		Own = (own or 1) * (1 + rng:NextNumber(-1, 1) * Config.Pace.Own) * (Config.SizePace[tier] or 1),
		Swift = swift or 1,
		Land = landPace(home),
		Gait = 0,
		Lead = 0,
		Phase = rng:NextNumber(0, math.pi * 2),
		Mode = 0,
		NextAt = os.clock() + rng:NextNumber(0, Config.Pace.DartEveryMax),
		Until = 0,
		Rise = 0,
		RiseWant = 0,
		Slice = slice,
		Parked = true,
		UnparkedAt = 0,
		Dir = dir,
		Speed = landPace(home) * Config.Herd.SpeedShare,
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
		if w.Pace == "Hunt" then
			-- a hunter starts where it cruises: high over its place in the herd
			local high = math.max(0, math.min(huntHigh(w), ceilingFor(body) - at.Y))
			w.Rise, w.RiseWant = high, high
			model:PivotTo(model:GetPivot() + Vector3.new(0, high, 0))
		end
	else
		placeInStream(w)
	end
	w.Gait = paceShare(w, os.clock(), at)
	addToStock(w)
	model.Destroying:Connect(function()
		wild[model] = nil
		stooping[w] = nil
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
-- player the place should be; `dodge`: the fish's way with the big things (rollDodge); `pace`: its character, for
-- its layer; `within`: only this far into the slice from its start (the lane's entry, Spawn.EntryAt).
-- Returns how far along it is, the place itself, and the fish's share of the band and its lift there.
local function placeFor(
	index: number,
	size: Vector3,
	clearOf: number,
	dodge: number,
	pace: string,
	within: number?
): (number, Vector3, number, number)
	local slice = slices[index]
	local sp = Config.Spawn
	local space, body = spaceOf(size), size.X / 2
	local count = placed[index] or 0
	placed[index] = count + 1
	local bestScore = -1
	local home, at, bestU, bestLift = slice.Start, Vector3.zero, 0, sp.HeightMin
	local last = if within then math.min(slice.End, slice.Start + math.max(within, 1)) else slice.End
	for try = 1, math.max(1, sp.Tries) do
		local s = rng:NextNumber(slice.Start, last)
		local u = if try % 2 == 1
			then ((count * 0.618034 + try * 0.381966 + index * 0.271) % 1) * 2 - 1
			else rng:NextNumber(-1, 1)
		local lift = rollLift(size, s, pace)
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

-- A new fish in a slice. `entry`: the lane's start with a player looking on: it comes in at the gate.
local function spawnFish(index: number, entry: boolean?): Wild?
	local slice = slices[index]
	if not slice then
		return nil
	end
	local grandNear, kinds = census((slice.Start + slice.End) / 2)
	local fishType = pick(slice.Zone, kinds)
	if not fishType then
		return nil
	end
	-- Studio only: the workspace's "TestKind" attribute (a fish's Id) makes every new fish that kind, for looking at
	-- one kind's way of swimming
	if RunService:IsStudio() then
		local testKind = workspace:GetAttribute("TestKind")
		fishType = (if type(testKind) == "string" then Config.FishById[testKind] else nil) or fishType
	end
	local tier = rollSize(grandNear, fishType)
	local body = fishType.Size * Config.sizeScale(tier, fishType)
	local dodge = rollDodge(body)
	-- Its pace: its kind's, but a fish of the herd may be born swift (Config.Pace.FastShare, BoltShare): up in the
	-- fast layer at the fast ones' pace, a bolt far faster, and each ridden faster than its kind
	local p = Config.Pace
	local pace = Config.paceOf(fishType)
	local own, swift = 1, 1
	local bolt = false
	if pace == "Cruise" then
		local roll = rng:NextNumber()
		if roll < p.BoltShare then
			pace, own, swift = "Zoom", p.Bolt / math.max(p.Zoom, 0.01), p.BoltRide
			bolt = true
		elseif roll < p.BoltShare + p.FastShare then
			pace, swift = "Zoom", p.FastRide
		end
	end
	if pace == "Zoom" then
		own *= 1 + rng:NextNumber(-1, 1) * (if bolt then p.BoltVary else p.FastVary)
	end
	local home, at, u, lift = placeFor(
		index,
		body,
		if entry then 0 else Config.Spawn.AppearClear,
		dodge,
		pace,
		if entry then Config.Spawn.EntryAt else nil
	)
	-- (at the gate it comes in already as high as the fish there swim: Config.Dive.Rise)
	local up = gateRise(home)
	if up > 0 then
		at = Vector3.new(at.X, math.max(at.Y, math.min(at.Y + up, ceilingFor(body))), at.Z)
	end
	local along = Stream.along(stream, home)
	local w = make(fishType, rollVariant(), home, at, along, slice.Zone, index, u, lift, dodge, tier, pace, own, swift)
	park(w, not nearAPlayer(at, Config.Spawn.StreamRadius))
	return w
end

-- Where a fish is in the water by its numbers: its place along the stream, its line across it, its lift (and a hunter's
-- rise). For a fish that has been swimming out of sight (the top-up carries its S on) and is coming back into it.
local function streamPoint(w: Wild): Vector3
	local s = math.clamp(w.S, 0, stream.Length)
	local across = Stream.across(stream, s, w.U, 0, w.Dodge, w.Body.X / 2)
	w.A = across
	local at = Stream.point(stream, s, across, w.Lift)
	local rise = w.Rise + gateRise(s)
	if rise > 0 then
		at = Vector3.new(at.X, math.max(at.Y, math.min(at.Y + rise, ceilingFor(w.Body))), at.Z)
	end
	return at
end

-- A parked fish comes back into the water where its numbers say it has swum to, already at its pace. (Until
-- 2026-11-16 a fish out of sight stood still, and one that had just swum out of sight was given a new place in its
-- slice: the sea round a rider was always being made of fish placed for a sea at rest.)
local function wake(w: Wild, at: Vector3)
	local dir = Stream.along(stream, math.clamp(w.S, 0, stream.Length))
	w.Dir = dir
	w.Land = landPace(w.S)
	w.Gait = paceShare(w, os.clock(), at)
	w.Speed = w.Land * w.Gait
	w.Model:PivotTo(CFrame.lookAt(at, at + dir))
	w.Root.AssemblyLinearVelocity = dir * w.Speed
	w.Root.AssemblyAngularVelocity = Vector3.zero
	w.Swim.VectorVelocity = dir * w.Speed
	w.Turn.CFrame = CFrame.lookAt(Vector3.zero, dir)
	w.SentAt, w.SentDir, w.SentSpeed = os.clock(), dir, w.Speed
	w.SyncAt = os.clock() + rng:NextNumber(0, SYNC)
	park(w, false)
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

-- Where the players are along the stream (read at each top-up), for what must not happen in anyone's sight
local playerS: { number } = {}
local function readPlayerS()
	readPlayers()
	table.clear(playerS)
	for _, at in playerAt do
		table.insert(playerS, (Stream.project(stream, at)))
	end
end

-- Whether no player is within `clear` studs along the stream of the stretch from s0 to s1
local function alongClear(s0: number, s1: number, clear: number): boolean
	for _, s in playerS do
		if s > s0 - clear and s < s1 + clear then
			return false
		end
	end
	return true
end

-- How many free fish a slice and its neighbours hold (Spawn.Window each side), and how many they should. The stock
-- is judged over that stretch, not slice by slice: the herd swims through the slices, so any one slice's count goes
-- up and down by a fish or two all the time, and answering each of those made and unmade fish for nothing.
local function windowOf(per: { [number]: number }, index: number): (number, number)
	local reach = math.max(0, math.floor(Config.Spawn.Window))
	local have, want = 0, 0
	for i = math.max(1, index - reach), math.min(#slices, index + reach) do
		have += per[i] or 0
		want += slices[i].Want
	end
	return have, want
end

-- The slice to make a fish in: the one whose stretch is furthest under its share, among those no player can see
-- (Spawn.SightClear). The lane's first slice is the one that may be filled in sight: the herd has to start somewhere,
-- and its fish come in at the gate (the second result says so). `anywhere`: sight doesn't count (the first filling).
local function emptiest(per: { [number]: number }, anywhere: boolean?): (number?, boolean)
	local sp = Config.Spawn
	local best: number? = nil
	local bestScore = 0
	local bestEntry = false
	for i, slice in slices do
		local have = per[i] or 0
		if have < slice.Want then
			local around, wanted = windowOf(per, i)
			if around < wanted then
				local hidden = anywhere or alongClear(slice.Start, slice.End, sp.SightClear)
				if hidden or i <= math.max(1, sp.EntrySlices) then
					local score = (wanted - around) / wanted
						+ 0.1 * (slice.Want - have) / slice.Want
						+ rng:NextNumber() * 0.01
					if score > bestScore then
						best, bestScore, bestEntry = i, score, not hidden
					end
				end
			end
		end
	end
	return best, bestEntry
end

-- Every Spawn.TopUpEvery seconds: the fish out of sight swim on (as numbers), fish come back into the water near a
-- player and leave it far from everyone, the strays and the surplus are taken away where nobody can see, and new fish
-- are made where nobody can see.
-- The lands with a player in them or near them (within Spawn.LiveReach along the stream). Only their fish swim on
-- out of sight. A land nobody is near stands still, whole, and starts again whole when someone comes: all its fish at
-- once, so it is as evenly spread when the player gets there as when it stopped. (Letting the whole sea flow all the
-- time meant every land was losing fish at one end and wanting them at the other for nobody: 25 fish a second to make
-- across ten lands, measured as a stock that could not keep up.)
local live: { [number]: boolean } = {}
local function readLive()
	table.clear(live)
	local reach = Config.Spawn.LiveReach
	for z = 1, #zoneFrom do
		if not alongClear(zoneFrom[z], zoneFrom[z + 1] or stream.Length, reach) then
			live[z] = true
		end
	end
end

local flowedAt = 0
-- (for measuring: FishService.stats)
local madeCount, goneCount, wokenCount, wrappedCount, topUpTook, makeTook = 0, 0, 0, 0, 0, 0

-- A plain fish that has swum out of the lands its kind lives in, out of sight, comes in again at the start of its own
-- land: the same fish, with a new place there. The whole sea flows, so every land's fish leave at one end all the time
-- and new ones are wanted at the other; making each of those from nothing was six or seven fish built a second.
-- Only the plain ones (an ordinary size and colour, of a rarity that is common in its own land): anything rarer goes,
-- and comes again only by the roll of the dice. true if it was given a place.
local WRAP_SLICES = 3
local function wrapHome(w: Wild, per: { [number]: number }): boolean
	local sp = Config.Spawn
	if sp.WrapHome == 0 or not w.Parked or w.Grand or w.Variant ~= "" then
		return false
	end
	-- (plain for its own land: a rarity that is a good share of what that land holds, Config.ZoneMix)
	local mix = Config.ZoneMix[w.Type.Home]
	if not mix or (mix[w.Type.Tier] or 0) < sp.WrapShare then
		return false
	end
	local first = zoneSlice[w.Type.Home]
	if not first then
		return false
	end
	for index = first, math.min(first + WRAP_SLICES - 1, #slices) do
		local slice = slices[index]
		-- (where nobody can see; or, at the lane's very start with someone looking on, in at the gate like a new one)
		local hidden = alongClear(slice.Start, slice.End, sp.SightClear)
		if
			slice.Zone == w.Type.Home
			and (per[index] or 0) < slice.Want
			and (hidden or index <= math.max(1, sp.EntrySlices))
		then
			local around, wanted = windowOf(per, index)
			if around < wanted then
				local home, _, u, lift = placeFor(index, w.Body, 0, w.Dodge, w.Pace, if hidden then nil else sp.EntryAt)
				local old = w.Slice
				if old then
					per[old] = (per[old] or 0) - 1
				end
				per[index] = (per[index] or 0) + 1
				w.S, w.Home, w.U, w.Lift = home, home, u, lift
				w.A = Stream.across(stream, home, u, 0, w.Dodge, w.Body.X / 2)
				w.Slice = index
				w.Zone = w.Type.Home
				wrappedCount += 1
				return true
			end
		end
	end
	return false
end
-- the free fish in each slice and in all, as the last top-up counted them and as the making since has added to them
local stocked: { [number]: number } = {}
local stockedTotal = 0
-- how many fish the last top-up still wants made. They are made one a frame (the Heartbeat), not all at once:
-- building a fish and finding its place takes a millisecond or two, and the whole sea flowing means six or seven are
-- wanted every second, where the still sea wanted one now and then.
local owed = 0

local function makeSome(most: number, anywhere: boolean?)
	local began = os.clock()
	local made = 0
	while made < most and owed > 0 do
		owed -= 1
		if stockedTotal >= Config.Spawn.MaxTotal then
			owed = 0
			break
		end
		local index, entry = emptiest(stocked, anywhere)
		if not index or not spawnFish(index, entry) then
			owed = 0
			break
		end
		stocked[index] = (stocked[index] or 0) + 1
		stockedTotal += 1
		made += 1
	end
	madeCount += made
	makeTook = math.max(makeTook * 0.98, os.clock() - began)
end

local function topUp(limit: number, anywhere: boolean?)
	local sp = Config.Spawn
	local now = os.clock()
	local elapsed = if flowedAt > 0 then math.min(now - flowedAt, 10) else 0
	flowedAt = now
	readPlayerS()
	readLive()
	for _, w in wild do
		if not w.Rider and not w.Reserved and not w.CoastToken then
			if w.Parked and live[w.Zone] then
				w.S += meanSpeed(w) * elapsed
			end
			-- the herd swims on: the fish counts for the slice it has reached
			local slice = sliceAt(w.S)
			if slice ~= w.Slice then
				w.Slice = slice
				w.Home = w.S
				w.Zone = Lane.zoneAt(lane, Stream.laneS(stream, math.clamp(w.S, 0, stream.Length)))
			end
		end
	end
	local per, total = count()
	for _, w in wild do
		if not w.Rider and not w.Reserved and not w.CoastToken then
			local slice = w.Slice
			-- past the stocked zones, past the zones its kind lives in, or one too many where it is
			local gone = not slice or w.Zone > w.Type.Home + w.Type.Reach
			if slice and not gone and (per[slice] or 0) > slices[slice].Want then
				local around, wanted = windowOf(per, slice)
				gone = around > wanted + math.max(2, wanted * sp.OverBy)
			end
			if gone then
				-- only where nobody sees it go (past the lane's end there is nothing to swim on into: sooner)
				local clear = if slice then sp.SightClear else 250
				gone = alongClear(w.S, w.S, if slice then clear else 0)
					and (w.Parked or not nearAPlayer(w.Root.Position, clear))
			end
			if gone and slice and w.Zone > w.Type.Home + w.Type.Reach and wrapHome(w, per) then
				gone = false
			end
			if gone then
				if slice then
					per[slice] = (per[slice] or 0) - 1
				end
				total -= 1
				goneCount += 1
				wild[w.Model] = nil
				stooping[w] = nil
				w.Model:Destroy()
			elseif w.Parked then
				-- (the nearest player along the stream first: working out where it is in the water costs more)
				if not alongClear(w.S, w.S, sp.StreamRadius * 1.5) then
					local at = streamPoint(w)
					if nearAPlayer(at, sp.StreamRadius) then
						wokenCount += 1
						wake(w, at)
					end
				end
			elseif not nearAPlayer(w.Root.Position, sp.StreamRadius) then
				park(w, true)
			end
		end
	end
	table.clear(stock)
	for _, w in wild do
		addToStock(w)
	end
	stocked, stockedTotal = per, total
	owed = limit
	topUpTook = os.clock() - now
	if anywhere then
		-- (the first filling: all at once, before anyone is in the game)
		makeSome(math.huge, true)
	end
end

-- The stock's numbers, for measuring it (the notes' tables come from here): how many fish, how many made, taken away
-- and woken since the server started, how long the last top-up took, and every free fish's place.
function FishService.stats(): { [string]: any }
	local fish = {}
	local parked = 0
	for _, w in wild do
		if w.Parked then
			parked += 1
		end
		table.insert(
			fish,
			{ S = w.S, A = w.A, Lift = w.Lift + w.Rise, Pace = w.Pace, Parked = w.Parked, Length = w.Body.Z }
		)
	end
	local want = {}
	for i, slice in slices do
		want[i] = { Start = slice.Start, End = slice.End, Want = slice.Want, Zone = slice.Zone }
	end
	return {
		Total = #fish,
		Parked = parked,
		Made = madeCount,
		Gone = goneCount,
		Woken = wokenCount,
		Wrapped = wrappedCount,
		TopUp = topUpTook,
		Make = makeTook,
		Fish = fish,
		Slices = want,
		Players = table.clone(playerS),
	}
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
	w.Model:SetAttribute("SubFor", nil)
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
				if
					short > 0
					and math.abs(a.Lift + a.Rise - b.Lift - b.Rise) < (a.Body.Y + b.Body.Y) / 2 + h.GiveHeight
				then
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
	local now = os.clock()
	-- its speed: the land's pace times the share its character wants now (a hunter's too, since 2026-11-17: it went
	-- by its own ridden speed, which the speed pass had more than doubled), come to
	-- over a moment
	local ease = math.max(Config.Pace.Ease, 0.1) * dt
	w.Gait += math.clamp(paceShare(w, now, position) - w.Gait, -ease, ease)
	local speed = w.Land * w.Gait
	if w.Rise ~= w.RiseWant then
		-- (a hunter stoops fast and climbs slow; a darter's little lift comes and goes gently)
		local step = (
			if w.Pace ~= "Hunt" then 10 elseif w.RiseWant < w.Rise then Config.Pace.HuntFall else Config.Pace.HuntClimb
		) * dt
		w.Rise += math.clamp(w.RiseWant - w.Rise, -step, step)
	end
	if w.ReleasedAt then
		local t = (os.clock() - w.ReleasedAt) / Config.Ride.SlowDownTime
		if t >= 1 then
			w.ReleasedAt = nil
		else
			speed = w.ReleaseSpeed + (speed - w.ReleaseSpeed) * t
		end
	end
	-- its place along the stream: carried forward by its speed, and every SYNC seconds read off where it really is
	if now - w.SyncAt >= SYNC then
		w.SyncAt = now
		w.S = (Stream.project(stream, position, w.S))
		w.Land = landPace(w.S)
	else
		w.S = math.min(w.S + speed * dt, stream.Length)
	end
	if w.Pace == "Dart" then
		-- how far ahead of its place in the herd it is: a burst adds to it, the drift back takes it away
		w.Lead = math.max(0, w.Lead + (speed - w.Land * Config.Herd.SpeedShare * w.Own) * dt)
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
		local target = Stream.point(stream, aheadS, across, w.Lift)
		-- (a hunter over the herd: up by its rise, never out of the water. And every fish near the gate, by the
		-- gate's own rise there: it sinks to its place in the herd as it swims on)
		local rise = w.Rise + gateRise(aheadS)
		if rise > 0 then
			local up = math.max(target.Y, math.min(target.Y + rise, ceilingFor(w.Body)))
			target = Vector3.new(target.X, up, target.Z)
		end
		local to = target - position
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
	if
		now - w.SentAt > 0.5
		or math.abs(speed - w.SentSpeed) > Config.Pace.Send
		or (w.Dir - w.SentDir).Magnitude > 0.017
	then
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

-- The visit (Config.Pace.Visit*): a player in the water who has no hunter in sight is now and then sent one, from
-- behind and above. Looked at with every top-up.
local visitAt: { [Player]: number } = {}

-- The hunters that live in a land (its own, or ones that swim on into it); with none, the nearest land's
local function huntersOf(zone: number): { Config.FishType }
	local list: { Config.FishType } = {}
	local nearest: Config.FishType? = nil
	for _, fish in Config.Fish do
		if Config.paceOf(fish) == "Hunt" and fish.Reach >= 0 then
			if zone >= fish.Home and zone <= fish.Home + fish.Reach then
				table.insert(list, fish)
			end
			if not nearest or math.abs(fish.Home - zone) < math.abs(nearest.Home - zone) then
				nearest = fish
			end
		end
	end
	if #list == 0 and nearest then
		table.insert(list, nearest)
	end
	return list
end

local function visit(player: Player, now: number)
	local p = Config.Pace
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local due = visitAt[player]
	if not due then
		visitAt[player] = now + rng:NextNumber(p.VisitEveryMin, math.max(p.VisitEveryMin, p.VisitEveryMax))
		return
	elseif now < due and not (RunService:IsStudio() and workspace:GetAttribute("TestVisit")) then
		-- (Studio only: the workspace's "TestVisit" attribute makes a visit due now, for looking at one)
		return
	end
	visitAt[player] = now + p.VisitRetry
	-- only to a player who is in the water and far enough down the lane to have room behind them
	local here = root.Position
	local s, across = Stream.project(stream, here)
	if here.Y > Config.Oxygen.SurfaceY or s < p.VisitBehind + 40 or s > stream.Length - 200 then
		return
	end
	-- and has no hunter in sight already
	for _, w in wild do
		if w.Pace == "Hunt" and not w.Parked and (w.Root.Position - here).Magnitude < Config.Spawn.StreamRadius then
			return
		end
	end
	-- which hunter: by the land's own share of each one's rarity (Config.ZoneMix), so the commoner hunter is the
	-- usual visitor and a Legendary one the odd time
	local land = Lane.zoneAt(lane, Stream.laneS(stream, s))
	local kinds = huntersOf(land)
	local mix = Config.ZoneMix[land] or {}
	local total = 0
	for _, fish in kinds do
		total += mix[fish.Tier] or 0.05
	end
	local roll = rng:NextNumber() * total
	local fishType: Config.FishType? = kinds[#kinds]
	for _, fish in kinds do
		roll -= mix[fish.Tier] or 0.05
		if roll <= 0 then
			fishType = fish
			break
		end
	end
	if not fishType then
		return
	end
	local from = s - p.VisitBehind
	local grandNear = census(from)
	local tier = rollSize(grandNear, fishType)
	local body = fishType.Size * Config.sizeScale(tier, fishType)
	-- on a line that passes a little to one side of the player
	local u = Stream.share(stream, s, across + rng:NextNumber(-1, 1) * p.VisitAside)
	local lift = rollLift(body, from, "Hunt")
	local at = Stream.point(stream, from, Stream.across(stream, from, u, 0, 0, body.X / 2), lift)
	local zone = Lane.zoneAt(lane, Stream.laneS(stream, from))
	local w = make(fishType, rollVariant(), from, at, Stream.along(stream, from), zone, sliceAt(from), u, lift, 0, tier)
	w.Model:SetAttribute("Visitor", true)
	if RunService:IsStudio() then
		workspace:SetAttribute("TestVisit", nil)
	end
	-- it comes down at once
	w.Mode = 1
	stooping[w] = true
	w.Gait = p.HuntRun * w.Own
	park(w, false)
	visitAt[player] = now + rng:NextNumber(p.VisitEveryMin, math.max(p.VisitEveryMin, p.VisitEveryMax))
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
-- The submarine (SubService; docs/design/submarine.md): the fish round the place a player is being carried to are kept
-- in the water before they get there, as if they were there already (nil: no longer)
function FishService.keepFor(player: Player, place: Vector3?)
	if place then
		keptFor[player] = place
	else
		keptFor[player] = nil
	end
	playersReadAt = -1
end

-- Where a place is along the herd's stream, studs; where each land begins along it; and how long it is
function FishService.streamS(position: Vector3): number
	return (Stream.project(stream, position))
end

function FishService.landStart(index: number): number?
	return zoneFrom[index]
end

function FishService.streamLength(): number
	return stream.Length
end

-- A point on the herd's own line through the open water (its middle, round the big things), `lift` over the floor, kept under the surface
-- by `under` studs
function FishService.streamPoint(s: number, lift: number, under: number): Vector3
	s = math.clamp(s, 0, stream.Length)
	-- (bent round the big things as the herd is, with room for a body 8 studs wide either side)
	local across = Stream.across(stream, s, 0, 0, 1, 8)
	local at, floorY = Stream.point(stream, s, across, 0)
	return Vector3.new(at.X, math.min(floorY + lift, Config.Oxygen.SurfaceY - under), at.Z)
end

-- The fish a player rides with off the submarine: one of their tank's, made in the water for them, its kind, colour
-- and size. Kept for them (no one else can take it), driven by their machine (it swims up beside the sub) and not by
-- the herd, until they are on it.
function FishService.spawnFor(
	id: string,
	variant: string,
	size: string,
	at: Vector3,
	dir: Vector3,
	player: Player
): Wild?
	local fishType = Config.FishById[id]
	if not fishType then
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
		sliceAt(home),
		nil,
		nil,
		nil,
		if Config.SizeScale[size] then size else "Normal"
	)
	park(w, false)
	w.Model:SetAttribute("SubFor", player.UserId)
	FishService.reserve(w, player)
	-- (not steered by the herd while this is set: the player's machine moves it beside the sub)
	w.CoastToken = {}
	pcall(function()
		w.Root:SetNetworkOwner(player)
	end)
	return w
end

-- A few fish of the herd put in the water ahead of a place along the stream, between `from` and `to` studs on, for a
-- player about to arrive there (the submarine's drop point): the kinds, sizes and colours the herd has there, each at
-- its own place across the band and height over the floor. Kept in the water; the top-up thins them out later if the
-- stretch has too many.
function FishService.stockNear(s: number, from: number, to: number, count: number)
	for i = 1, count do
		local at = math.clamp(s + from + (to - from) * (i - 0.5) / count + rng:NextNumber(-15, 15), 0, stream.Length)
		local zone = Lane.zoneAt(lane, Stream.laneS(stream, at))
		local grandNear, kinds = census(at)
		local fishType = pick(zone, kinds)
		if fishType then
			local tier = rollSize(grandNear, fishType)
			local half = Stream.width(stream, at) / 2
			local across = rng:NextNumber(-0.55, 0.55) * half
			local point = Stream.point(stream, at, across, rng:NextNumber(12, 24))
			local w = make(
				fishType,
				rollVariant(),
				at,
				point,
				Stream.along(stream, at),
				zone,
				sliceAt(at),
				nil,
				nil,
				nil,
				tier
			)
			park(w, false)
		end
	end
end

-- That fish, given back to the herd (the drop went wrong) or taken out of the water (the trip was given up)
function FishService.discard(w: Wild)
	if w.Model.Parent then
		w.Model:Destroy()
	end
end

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
	for z = 1, #zones do
		zoneFrom[z] = Stream.fromLane(stream, lane.ZoneStart[z])
	end
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
	topUp(math.huge, true)
	if RunService:IsStudio() then
		-- (Studio only: the stock's numbers for a script run from outside the game's own, which can't require this)
		local ask = Instance.new("BindableFunction")
		ask.Name = "FishStats"
		ask.OnInvoke = FishService.stats
		ask.Parent = ServerStorage
	end
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
		if owed > 0 then
			makeSome(1)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		visitAt[player] = nil
		keptFor[player] = nil
	end)
	while true do
		task.wait(Config.Spawn.TopUpEvery)
		topUp(Config.Spawn.PerTopUp)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			visit(player, now)
		end
	end
end

return FishService
