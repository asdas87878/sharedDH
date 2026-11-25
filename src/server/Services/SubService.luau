--!strict
-- The submarine (Hugo, 2026-11-17; docs/design/submarine.md): bought tier by tier at the hub, it picks a player up as
-- they go into the water and carries them fast down the lane to a land they have chosen, then lets them go: flung into
-- a hop, or kicked onto a fish of their own that swims up beside it. All of it decided here; every machine moves its
-- own copy of the sub from the trip written on the player (Shared/SubTrip, Client SubController).
--   Per player, for the session (nothing is saved yet; kept beside the tank's coins, AquariumService, to be saved
--   with them): Tier (0 to 9: the subs bought, one a tier, Shared/SubModels; sub N carries to land N + 1 or any land
--   before it), Equip (the sub equipped, 0: none, so the dive is the ordinary dive-in), Dest (the land picked, up to
--   Equip + 1; 0: none) and Fish (the tank fish to ride with, "id|size|variant", "": none). Mirrored in the attributes
--   SubTier, SubEquip, SubDest and SubFish. Bought, equipped and picked only on the dock at the stand,
--   Dock.Stations.Sub, within Sub.Near of its ring ("SubBuy", "SubEquip", n, "SubPick", land, fish; Hugo,
--   2026-11-18: the shop is at the stand, the HUD's SUB button is gone). Free while Sub.Free is 1.
--   The trip: as a player with a land picked goes into the water, RideService asks us (RideService.Diving) and they are
--   "Carried". We write the trip ("SubTrip": its start, phases and path, Shared/SubTrip) and its phase ("SubPhase").
--   The fish round the drop point are kept in the water from the start (FishService.keepFor). At the drop:
--     no fish: RideService.fling, and the player's machine is told ("SubDrop", "Fling") and flies the hop;
--     a fish: it was made beside the sub FishIn seconds before (FishService.spawnFor, "SubFish"), driven there by the
--     player's machine; we say "SubDrop", "Kick", and the machine kicks the rider onto it and says "SubLand".
--   The fish ridden after the drop (task f2, Hugo 2026-11-20: "jumping into the gameplay loop with the fish should let
--   you ride it after submarine"): the fish the player has EQUIPPED (Q, task e3: RideService.equippedOf, one of
--   the fish in their hands; holding it over the head alone no longer counts), else the tank fish picked at the stand ("SubFish"), else none (the fling). Its
--   kind, size and colour are fixed as the trip is made (Sub.Ride). It is borrowed, never taken: the hands (and the
--   tank) keep it whatever happens, a ride, a miss or a drown, and riding it tames nothing new.
--   The plain dive-in with an equipped fish (no sub equipped, no land picked, or Sub.On 0): RideService asks us
--   (RideService.DiveFish) and the equipped fish is made where the player goes in, and they are put straight on it.
--   The escort (Hugo, 2026-11-24; Sub.Escort): a player who goes in riding their ride fish on land has that fish made in
--   the water as the trip is made (the same one for the whole trip: Held), and the trip says where it swims
--   (SubTrip.escort). It carries them out to the sub, they hop onto its seat, it sweeps left and right with the sub and
--   is back beside it for the kick. It is anchored here and every machine moves its own by the trip until Arrive, when
--   it is given to the player's machine for the kick as any drop-off fish is. Their hands are watched the whole way: the
--   fish unequipped or gone from them, and the copy swims off and is taken away (the fling instead).
--   The air hop (Hugo, 2026-11-25; Sub.AirHop, Shared/SubAir): the leap of the ride fish off the lip is told to us by its
--   rider's machine as it begins ("SubLeap": its arc), checked here, and the trip is made then and there, its start the
--   leap's: the rider jumps off in the air onto the sub. They stay on the land fish ("Dock") until HopAt by our own clock,
--   and are "Carried" from there; off the fish, unequipped, dead or gone before that, and there is no trip: the leap goes
--   on as the plain dive. A leap not told, told too late or refused: nothing happens here, and the hop under water comes
--   as they go in (diving), as before.
--   If the player's machine says nothing for Sub.Late seconds, we let them go ourselves. A death, a reset or leaving
--   in the middle gives the trip up and takes the fish away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local SubAir = require(ReplicatedStorage.Shared.SubAir)
local SubTrip = require(ReplicatedStorage.Shared.SubTrip)
local AquariumService = require(script.Parent.AquariumService)
local FishService = require(script.Parent.FishService)
local RideService = require(script.Parent.RideService)

type Wild = FishService.Wild
type Sub = {
	Tier: number,
	Equip: number,
	Dest: number,
	Fish: string,
	Ride: RideService.Carry?, -- the fish this trip's drop-off rides (held or from the tank), fixed as the trip is made
	Own: RideService.Carry?, -- and which of the fish in their hands it is, when it is the equipped one (that very entry)
	Moved: boolean, -- the escort has been sent ahead to the drop point (our copy of it, which nobody sees)
	Loose: boolean, -- and been given to the player's machine for the kick
	Trip: SubTrip.Trip?,
	Phase: string?,
	Held: Wild?, -- the player's fish, made for the drop-off
	Cued: boolean, -- the drop has been said
	Done: boolean, -- and it is over (they are flung, on their fish, or let go)
	Asked: number, -- os.clock() a leap was last told
	Aloft: boolean, -- the air hop: still on their leaping land fish (not "Carried" yet)
	DropPoint: Vector3?,
	DropS: number, -- the drop point, along the herd's stream
	Stocked: boolean,
}

local SubService = {}

local subs: { [Player]: Sub } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function lands(): number
	return #FishService.zones()
end

local function tell(player: Player, sub: Sub)
	player:SetAttribute("SubTier", sub.Tier)
	player:SetAttribute("SubEquip", sub.Equip)
	player:SetAttribute("SubDest", sub.Dest)
	player:SetAttribute("SubFish", sub.Fish)
end

local function keyOf(id: string, size: string, variant: string): string
	return id .. "|" .. size .. "|" .. variant
end

-- The tank fish a key names (nil: not in the tank any more)
local function tankFish(player: Player, key: string): (string?, string?, string?)
	if key == "" then
		return nil, nil, nil
	end
	local tank = AquariumService.tankOf(player)
	if not tank then
		return nil, nil, nil
	end
	for _, entry in tank do
		if keyOf(entry.Id, entry.Size, entry.Variant) == key then
			return entry.Id, entry.Size, entry.Variant
		end
	end
	return nil, nil, nil
end

-- The fish a dive rides: the equipped one first (Q, task e3: never merely the one held over the head), else the tank
-- fish picked at the stand (nil: none). A copy, made as the trip is made
local function rideWith(player: Player, sub: Sub): RideService.Carry?
	local h = RideService.equippedOf(player)
	if h and Config.FishById[h.Id] then
		return { Id = h.Id, Size = h.Size, Variant = h.Variant }
	end
	local id, size, variant = tankFish(player, sub.Fish)
	if id then
		return { Id = id, Size = size or "Normal", Variant = variant or "" }
	end
	return nil
end

-- The lane's way at a place (along the herd's stream, flat)
local function laneWay(at: Vector3): Vector3
	local s = FishService.streamS(at)
	local ahead = FishService.streamPoint(s + 60, 0, 0) - FishService.streamPoint(s, 0, 0)
	ahead = Vector3.new(ahead.X, 0, ahead.Z)
	return if ahead.Magnitude > 0.1 then ahead.Unit else Vector3.new(0, 0, -1)
end

local function deny(player: Player, reason: string)
	Net.Ride:FireClient(player, "SubDenied", reason)
end

-- On the dock and at the stand (no stand in the place: anywhere on the dock)
local function atStand(player: Player): boolean
	if RideService.stateOf(player) ~= "Dock" then
		return false
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local stations = dock and dock:FindFirstChild("Stations")
	local stand = stations and stations:FindFirstChild("Sub")
	local ring = stand and (stand:FindFirstChild("Ring") or (stand:IsA("Model") and stand.PrimaryPart))
	if not ring or not ring:IsA("BasePart") then
		return true
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local gap = root.Position - ring.Position
	return Vector3.new(gap.X, 0, gap.Z).Magnitude <= Config.Sub.Near
end

-- (tier: the sub the player pressed; a second press that arrives once it is theirs buys nothing)
local function buy(player: Player, sub: Sub, tier: any, checked: boolean?)
	local c = Config.Sub
	local next = sub.Tier + 1
	if tier ~= nil and tier ~= next then
		return
	end
	local price = c.Prices[next]
	if not price or next + 1 > lands() then
		return deny(player, "Top")
	end
	if not checked and not atStand(player) then
		return deny(player, "Dock")
	end
	if c.Free ~= 1 and not AquariumService.spend(player, price) then
		return deny(player, "Coins")
	end
	sub.Tier = next
	-- (the sub just bought is equipped and its furthest land picked: the reference's "Your boarding pass is ready!")
	sub.Equip = next
	sub.Dest = next + 1
	tell(player, sub)
	Net.Ride:FireClient(player, "SubBought", next)
end

local function equip(player: Player, sub: Sub, n: any, checked: boolean?)
	if not checked and not atStand(player) then
		return deny(player, "Dock")
	end
	if type(n) ~= "number" or n ~= n then
		return deny(player, "Land")
	end
	n = math.floor(n)
	if n < 0 or n > sub.Tier then
		return deny(player, "Land")
	end
	sub.Equip = n
	-- (the furthest land this sub reaches, as on buying; a nearer one is picked after)
	sub.Dest = if n == 0 then 0 else n + 1
	tell(player, sub)
end

local function pick(player: Player, sub: Sub, land: any, fish: any, checked: boolean?)
	if not checked and not atStand(player) then
		return deny(player, "Dock")
	end
	if type(land) ~= "number" or land ~= land then
		return deny(player, "Land")
	end
	land = math.floor(land)
	if land ~= 0 and (land < 2 or land > sub.Equip + 1 or land > lands()) then
		return deny(player, "Land")
	end
	sub.Dest = land
	if type(fish) == "string" and #fish <= 80 then
		sub.Fish = if tankFish(player, fish) then fish else ""
	end
	tell(player, sub)
end

-- Clean up a trip: the fish is taken away if nobody rides it, the drop point no longer kept, the attributes gone
local function finish(player: Player, sub: Sub)
	local held = sub.Held
	if held and held.Rider ~= player then
		FishService.discard(held)
	end
	sub.Held = nil
	sub.Ride = nil
	sub.Own = nil
	sub.Moved = false
	sub.Loose = false
	sub.Trip = nil
	sub.Phase = nil
	sub.Cued = false
	sub.Done = false
	sub.Aloft = false
	sub.DropPoint = nil
	FishService.keepFor(player, nil)
	player:SetAttribute("SubTrip", nil)
	player:SetAttribute("SubPhase", nil)
end

-- The fish the player went in on, made in the water where they are for the whole trip (nil: not on it, or it could not
-- be made): every machine moves it by the trip, so it stays in everyone's game however far from us it swims
local function escortFor(player: Player, ride: RideService.Carry?, at: Vector3, way: Vector3): Wild?
	local own = RideService.equippedOf(player)
	if Config.Sub.Escort == 0 or not ride or not own then
		return nil
	end
	local ok, w = pcall(FishService.spawnFor, ride.Id, ride.Variant, ride.Size, at, way, player)
	if not ok or not w then
		warn("[SubService] the escort could not be made: " .. tostring(w))
		return nil
	end
	-- (where they sit is where they went in)
	local root = CFrame.lookAt(at, at + way) * CFrame.new(-w.Saddle.Position)
	w.Model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	w.Root.Anchored = true
	w.Root.CFrame = root
	return w
end

-- The escort is anchored no more: an ordinary drop-off fish, which the player's machine drives (as spawnFor leaves one)
local function looseEscort(player: Player, sub: Sub, trip: SubTrip.Trip, t: number)
	local w = sub.Held
	if sub.Loose or not w or not trip.Escort then
		return
	end
	sub.Loose = true
	local cf = SubTrip.escort(trip, t)
	local _, speed = SubTrip.distance(trip, t)
	if cf then
		w.Root.CFrame = cf
	end
	w.Root.Anchored = false
	w.Root.AssemblyLinearVelocity = SubTrip.way(trip, (SubTrip.distance(trip, t))) * speed
	pcall(function()
		w.Root:SetNetworkOwner(player)
	end)
	w.Model.ModelStreamingMode = Enum.ModelStreamingMode.Default
end

-- The drop-off is the fling after all: told to every machine, which has read the trip already (the attribute again, with
-- the same start). Not once the kick is under way: the sub's nose would go up in one frame, in the middle of the drop
local function noFish(player: Player, trip: SubTrip.Trip)
	trip.Fish = false
	trip.DropTime = Config.Sub.Drop
	player:SetAttribute("SubTrip", SubTrip.encode(trip))
end

-- The escort's fish is theirs no more (unequipped, put in the tank) or the game has lost it: the copy swims off and
-- fades on every machine (SubController) and is taken away; the drop-off is the fling (at once, if they were in the
-- middle of the kick onto it)
local function dropEscort(player: Player, sub: Sub, trip: SubTrip.Trip)
	local w = sub.Held
	sub.Held = nil
	sub.Ride = nil
	if not sub.Cued then
		noFish(player, trip)
	end
	if w and w.Model.Parent then
		w.Model:SetAttribute("SubLeave", now())
		task.delay(Config.Sub.EscortFade + 0.2, function()
			if not w.Rider then
				FishService.discard(w)
			end
		end)
	end
	if sub.Cued and not sub.Done then
		sub.Done = true
		if RideService.fling(player) then
			Net.Ride:FireClient(player, "SubDrop", "Fling")
		end
	end
end

-- The lip's middle, looking out (the map's lip is straight in front of the dock's spawn)
local function lipFrame(): CFrame?
	local dock = Net.Folder:GetAttribute("Dock")
	if typeof(dock) ~= "CFrame" then
		return nil
	end
	local look = Vector3.new(dock.LookVector.X, 0, dock.LookVector.Z)
	if look.Magnitude < 0.5 then
		return nil
	end
	local at = Vector3.new(dock.X, Config.Depth.SurfaceY, dock.Z) + look.Unit * Config.Sub.AirArch
	return CFrame.lookAt(at, at + look.Unit)
end

local NECK = 330 -- studs past the pick-up the lane's first neck is behind a long fish's tail
local DRIFT = 190 -- studs past the pick-up by when the sub is about on its line through the lane's first neck (with a fish). Not before
-- the path's second point: the line it comes in on is the way of the first stretch, straight through the gate

-- The trip, made as the player goes in: they swim on from where they went in, down the lane, to the pick-up; from
-- there the herd's own line, Sub.Lift over the floor, to Sub.Into studs into the land, and on past it.
-- `leap`, `since`: the air hop's, the ride fish's leap and when it began (server time)
local function begin(
	player: Player,
	sub: Sub,
	root: BasePart,
	mounted: boolean,
	leap: SubAir.Leap?,
	since: number?
): boolean
	local c = Config.Sub
	local first = FishService.landStart(sub.Dest)
	if not first then
		warn("[SubService] no start for land " .. sub.Dest)
		return false
	end
	local entry = root.Position
	local ahead = laneWay(entry)
	local pickup = Vector3.new(entry.X, Config.Oxygen.SurfaceY - c.Under, entry.Z) + ahead * c.SwimOut
	local ride = rideWith(player, sub)
	local held = if mounted then escortFor(player, ride, entry, ahead) else nil
	sub.Held = held -- (ours from here: whatever goes wrong below, diving takes it away)
	local air: SubAir.Air? = nil
	if leap then
		local lip = lipFrame()
		if not held or not lip then
			return false
		end
		-- (under its rider as it leaps, as every machine is about to put it, and out of sight until they jump: Lib/AirHop)
		held.Model:SetAttribute("SubAir", true)
		held.Root.CFrame = root.CFrame * CFrame.new(-held.Saddle.Position)
		local row = SubTrip.Hulls[math.clamp(sub.Equip, 1, #SubTrip.Hulls)]
		air = SubAir.plan(leap, held.Body / 2, held.Saddle.Position, row, lip)
		if not air then
			return false
		end
	end
	local sDrop = math.min(first + c.Into, FishService.streamLength() - 50)
	local half, saddleAt, side = Vector3.zero, Vector3.zero, 0
	-- (with a fish: where the pick-up is along the stream, how far to its right, how far along the sub keeps that line, and
	-- the room to the right of it the fish takes)
	local sPick, off, far, open, need = 0, 0, 0, 0, 0
	if held then
		half = held.Body / 2
		saddleAt = held.Saddle.Position
		side = SubTrip.escortSide(half, sub.Equip)
		need = side + half.X + c.EscortGap
		-- the sub takes them off it beside its own line: the fish goes as straight out as the lane's sides let the two of
		-- them lie side by side
		pickup = Vector3.new(entry.X, Config.Oxygen.SurfaceY - c.EscortUnder, entry.Z)
			+ ahead * SubTrip.escortOut(half, saddleAt)
		if air then
			pickup = air.Pick
		end
		sPick = FishService.streamS(pickup)
		local middle = FishService.streamPoint(sPick, 0, 0)
		local across = laneWay(pickup):Cross(Vector3.yAxis)
		-- (the air hop: the fish is not beside it there, it comes up to its side after)
		off = (pickup - middle):Dot(across) - (if air then 0 else side)
		-- the sub's line is straight, from the gate until the fish is ahead of it: the sub in the gate and in the lane, and
		-- the fish between it and the lane's right side (one too wide for that leaves the sub its room)
		local run = sDrop - sPick
		open = sPick + math.max(math.min(c.EscortOpen, run * 0.15), math.min(NECK, run * 0.4))
		local hull = SubTrip.Hulls[math.clamp(sub.Equip, 1, #SubTrip.Hulls)][1] + c.EscortGap
		local low, high = hull - c.EscortGate, c.EscortGate - hull
		-- (after the air hop the fish is still on its way here: the sub has the water to itself)
		local by = if air then hull else need
		local swing = if air then 0 else SubTrip.escortSwing(half)
		local lowFar, highFar = -math.huge, math.huge
		for on = 0, open, 30 do
			local left, right = FishService.streamRoom(on)
			if on < sPick + DRIFT then
				low = math.max(low, hull - left)
				-- (abreast of the fish from where its tail is as it takes them)
				if on >= sPick - half.Z then
					high = math.min(high, right - by)
				end
			else
				lowFar = math.max(lowFar, hull - left)
				-- (and it swings off its place along here)
				highFar = math.min(highFar, right - by - swing)
			end
		end
		off = math.max(math.min(off, high), low)
		-- (past the gate there is more water to the left: over there by the lane's first neck, if the fish needs it)
		far = math.clamp(math.min(off, highFar), math.min(off, lowFar), off)
		pickup = Vector3.new(middle.X, pickup.Y, middle.Z) + across * off
	end
	local sFrom = FishService.streamS(pickup) + 90
	if sDrop <= sFrom + 200 then
		warn(
			string.format(
				"[SubService] land %d is too near: from %.0f to %.0f along the stream",
				sub.Dest,
				sFrom,
				sDrop
			)
		)
		return false
	end
	-- (with a fish beside it the sub keeps as far to the left as that takes, from a way before the drop)
	local aside, ease = 0, 600
	if held then
		local hull = SubTrip.Hulls[math.clamp(sub.Equip, 1, #SubTrip.Hulls)][1]
		local left, right = FishService.streamRoom(sDrop)
		aside = math.clamp(need - right, 0, math.max(left - hull - c.EscortGap, 0))
		ease = math.min(600, (sDrop - sPick) * 0.35)
	end
	local points = { pickup }
	local dropAt = 0
	local length = 0
	local beyond = sDrop + c.DropSpeed * (c.Arrive + c.Drop + c.Kick + 6) + 200
	local s = sFrom
	while true do
		local p = FishService.streamPoint(math.min(s, beyond), c.Lift, 8)
		if held then
			local on = math.min(s, beyond)
			-- to the right of the stream: as far as the pick-up is, easing onto the stream's own line (no bend while the
			-- fish is beside it), and `aside` to the left for the drop
			local over = Ease.lerp(off, far, Ease.smoothstep(sPick + 90, sPick + DRIFT + 40, on))
					* (1 - Ease.smoothstep(open, open + ease, on))
				- aside * Ease.smoothstep(sDrop - 900, sDrop - 200, on)
			if over ~= 0 then
				local ahead2 = FishService.streamPoint(on + 30, 0, 0) - FishService.streamPoint(on - 30, 0, 0)
				local level = Vector3.new(ahead2.X, 0, ahead2.Z)
				if level.Magnitude > 0.1 then
					p += level.Unit:Cross(Vector3.yAxis) * over
				end
			end
		end
		length += (p - points[#points]).Magnitude
		table.insert(points, p)
		if dropAt == 0 and s >= sDrop then
			dropAt = length
		end
		if s >= beyond then
			break
		end
		-- (exactly at the drop point once)
		local nextS = s + c.Sample
		if s < sDrop and nextS > sDrop then
			nextS = sDrop
		end
		s = nextS
	end
	if air then
		local lead = SubTrip.leadIn(points[1], points[2])
		dropAt += (points[1] - lead).Magnitude
		table.insert(points, 1, lead)
		SubAir.aim(air, points[2], (points[3] - points[2]).Unit)
	end
	local trip = SubTrip.new(since or now(), sub.Dest, ride ~= nil, points, dropAt, air)
	if held then
		local near: { [number]: number } = {}
		local roomLeft, roomRight = SubTrip.escortRooms(trip, sub.Equip, half, function(at, way, i)
			local on = FishService.streamS(at, near[i])
			near[i] = on
			local left, right = FishService.streamRoom(on)
			local over = (at - FishService.streamPoint(on, 0, 0)):Dot(way:Cross(Vector3.yAxis))
			return left + over, right - over
		end)
		SubTrip.escorted(trip, sub.Equip, half, saddleAt, held.Root.Position, ahead, roomLeft, roomRight)
	end
	sub.Trip = trip
	sub.Ride = ride
	sub.Own = if held then RideService.equippedOf(player) else nil
	sub.Phase = nil
	sub.Cued = false
	sub.Done = false
	sub.Aloft = air ~= nil
	sub.Held = held
	sub.Moved = false
	sub.Loose = false
	sub.DropPoint = SubTrip.at(trip, SubTrip.dropDistance(trip))
	sub.DropS = sDrop
	sub.Stocked = false
	FishService.keepFor(player, sub.DropPoint)
	player:SetAttribute("SubTrip", SubTrip.encode(trip))
	-- (on the fish's back, not swimming: no phase the rider's swimming pose goes by, AnimController)
	player:SetAttribute("SubPhase", if air then "Leap" elseif held then "Saddle" else "Approach")
	-- (the player's machine is moved thousands of studs in seconds: the map at the drop point is sent ahead)
	local drop = sub.DropPoint :: Vector3
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(drop, 8)
		end)
	end)
	return true
end

local function ready(sub: Sub): boolean
	return Config.Sub.On ~= 0 and not sub.Trip and sub.Equip >= 1 and sub.Dest >= 2 and sub.Dest <= sub.Equip + 1
end

local function finite(x: any, low: number, high: number): boolean
	return type(x) == "number" and x == x and x >= low and x <= high
end

-- The leap a player's machine says it has begun, if we believe it: theirs to say (it moves the body), but off the lip,
-- from about where we have them, out from the dock, at a land fish's pace
local function leapOf(root: BasePart, said: any): (SubAir.Leap?, number)
	local c, d = Config.Sub, Config.Dive
	local lip = lipFrame()
	if type(said) ~= "table" or not lip or typeof(said.Take) ~= "Vector3" or typeof(said.Heading) ~= "Vector3" then
		return nil, 0
	end
	local at, since = now(), said.Start
	local take, heading = said.Take :: Vector3, said.Heading :: Vector3
	if
		not finite(since, at - c.AirSlack, at + 0.15)
		or not finite(said.Far, 5, 900)
		or not finite(said.Rise, 0.1, 600)
		or not finite(said.Fall, 0.1, 1500)
		or not finite(said.Time, 0.4, 6)
		or not finite(said.Crouch, 0, 0.6)
		or not finite(take.X + take.Y + take.Z, -1e6, 1e6)
		or not finite(heading.X + heading.Y + heading.Z, -3, 3)
		or type(said.Tilts) ~= "table"
		or #said.Tilts < 2
		or #said.Tilts > 25
	then
		return nil, 0
	end
	for _, tilt in said.Tilts do
		if not finite(tilt, -89, 89) then
			return nil, 0
		end
	end
	heading *= Vector3.new(1, 0, 1)
	if heading.Magnitude < 0.5 then
		return nil, 0
	end
	heading = heading.Unit
	local from = lip:PointToObjectSpace(take)
	local e = Config.Equip
	if
		(take - root.Position).Magnitude > c.AirReach
		or math.abs(from.X) > c.AirReach + 20
		or math.abs(from.Z) > c.AirReach
		or take.Y < lip.Y
		or heading:Dot(lip.LookVector) < math.cos(math.rad(math.min(d.LeapCone, 85) + 3))
		or said.Far / said.Time > e.LandSpeed * e.PaceRoom * 1.6
	then
		return nil, 0
	end
	return {
		Take = take,
		Heading = heading,
		Far = said.Far,
		Rise = said.Rise,
		Fall = said.Fall,
		Crouch = said.Crouch,
		Time = said.Time,
		Tilts = table.clone(said.Tilts),
	},
		since
end

-- A player on their ride fish has leapt off the lip with a trip set: the air hop (Config.Sub.AirHop). Nothing here, and
-- the hop under water comes as they go in
local function leaps(player: Player, sub: Sub, said: any)
	local asked = os.clock()
	if asked - sub.Asked < 1 then
		return -- (one leap a second: each costs a plan)
	end
	sub.Asked = asked
	if Config.Sub.AirHop == 0 or Config.Sub.Escort == 0 or not ready(sub) or not RideService.onLandFish(player) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	local leap, since = leapOf(root, said)
	if not leap then
		return
	end
	local ok, began = pcall(begin, player, sub, root, true, leap, since)
	if ok and began then
		local trip = sub.Trip
		-- (too late to jump by now: the dive goes on, and the hop is under water)
		if trip and now() - trip.Start < trip.Approach - 0.03 then
			return
		end
		finish(player, sub)
		return
	end
	if not ok then
		warn("[SubService] the air hop could not be made: " .. tostring(began))
	end
	local held = sub.Held
	if held then
		sub.Held = nil
		FishService.discard(held)
	end
end

-- The air hop before the jump: the rider is on their leaping land fish. True: still there (or just off it)
local function aloft(player: Player, sub: Sub, trip: SubTrip.Trip, t: number): boolean
	local held, own = sub.Held, sub.Own
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not RideService.onLandFish(player)
		or not humanoid
		or humanoid.Health <= 0
		or not held
		or not held.Model.Parent
		or not own
		or RideService.equippedOf(player) ~= own
	then
		return false
	end
	if t < trip.Approach then
		return true
	end
	if not RideService.carryOff(player) then
		return false
	end
	sub.Aloft = false
	return true
end

-- Asked by RideService as a player on the dock goes into the water (`mounted`: on their ride fish): does the sub take them?
local function diving(player: Player, mounted: boolean): boolean
	local sub = subs[player]
	if not sub or not ready(sub) then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local ok, began = pcall(begin, player, sub, root, mounted == true)
	if not ok then
		warn("[SubService] the trip could not be made: " .. tostring(began))
	end
	if not ok or not began then
		local held = sub.Held
		if held then
			sub.Held = nil
			FishService.discard(held)
		end
		return false
	end
	return true
end

-- Asked by RideService as a player on the dock goes into the water and the sub doesn't take them: with a fish
-- equipped (Q, task e3), that fish, made where they go in and kept for them (RideService puts them on it)
local function diveFish(player: Player): FishService.Wild?
	local sub = subs[player]
	local h = RideService.equippedOf(player)
	if not sub or sub.Trip or not h then
		return nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local way = laneWay(root.Position)
	local at = root.Position + way * 4 - Vector3.yAxis * 3
	local ok, w = pcall(FishService.spawnFor, h.Id, h.Variant, h.Size, at, way, player)
	if not ok then
		warn("[SubService] the held fish could not be made: " .. tostring(w))
		return nil
	end
	-- (its saddle where they are, as the land fish's was: made at its root, it jumped by its whole saddle as it took the
	-- land fish's place, up to 50 studs for a tall one; task d1)
	if w then
		w.Root.CFrame = CFrame.lookAt(root.Position, root.Position + way) * CFrame.new(-w.Saddle.Position)
	end
	return w
end

-- The kick's end: the player's machine has put them on their fish's saddle
local function landed(player: Player, sub: Sub, target: any)
	local held = sub.Held
	if not sub.Cued or sub.Done or not held or typeof(target) ~= "Instance" or target ~= held.Model then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local near = root
		and root:IsA("BasePart")
		and (held.Root.Position - root.Position).Magnitude <= held.Body.Z / 2 + Config.Sub.LandSlack
	sub.Done = true
	if near and RideService.seatOn(player, held) then
		sub.Held = nil
	else
		RideService.letGo(player)
	end
end

local function step(player: Player, sub: Sub, trip: SubTrip.Trip)
	local c = Config.Sub
	local t = now() - trip.Start
	local state = RideService.stateOf(player)
	local _, _, _, dropAt, endAt = SubTrip.times(trip)
	if sub.Aloft then
		if not aloft(player, sub, trip, t) then
			finish(player, sub)
			return
		end
		state = "Carried"
	end
	if not sub.Done and state ~= "Carried" then
		-- given up in the middle: a death, a reset
		finish(player, sub)
		return
	end
	local phase = SubTrip.phase(trip, t)
	if phase ~= sub.Phase then
		sub.Phase = phase
		player:SetAttribute(
			"SubPhase",
			if phase == "Done" then nil elseif phase == "Approach" and trip.Escort then "Saddle" else phase
		)
	end
	-- the escort: the player's own fish the whole way, for as long as it is in their hands and equipped
	if trip.Escort and trip.Fish and not sub.Done then
		local held = sub.Held
		local own = sub.Own
		if not held or not held.Model.Parent or not own or RideService.equippedOf(player) ~= own then
			dropEscort(player, sub, trip)
		else
			local _, rideAt, arriveAt = SubTrip.times(trip)
			if not sub.Moved and t >= rideAt then
				-- (our own copy, which every machine moves itself, waits where the trip ends: once, and no traffic else)
				sub.Moved = true
				held.Root.CFrame = CFrame.new(sub.DropPoint or held.Root.Position)
			end
			if t >= arriveAt then
				looseEscort(player, sub, trip, t)
			end
		end
	end
	_, _, _, dropAt, endAt = SubTrip.times(trip)
	-- fish to hook, just ahead of the drop point, before we get there
	if not sub.Stocked and t >= dropAt - c.StockAt then
		sub.Stocked = true
		FishService.stockNear(sub.DropS, 50, 260, c.Stock)
	end
	-- the player's fish swims up beside the sub
	if trip.Fish and not sub.Held and not sub.Cued and t >= dropAt - c.FishIn then
		local ride = sub.Ride
		local d = SubTrip.distance(trip, t)
		local way = SubTrip.way(trip, d)
		local flat = Vector3.new(way.X, 0, way.Z)
		local right = if flat.Magnitude > 0.1 then flat.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
		local at = SubTrip.at(trip, d) - way * 40 + right * c.FishSide
		local w = if ride then FishService.spawnFor(ride.Id, ride.Variant, ride.Size, at, way, player) else nil
		if w then
			sub.Held = w
			Net.Ride:FireClient(player, "SubFish", w.Model)
		else
			-- (it could not be made: the fling instead)
			noFish(player, trip)
		end
	end
	if not sub.Cued and t >= dropAt then
		sub.Cued = true
		local held = sub.Held
		if trip.Fish and held and held.Model.Parent then
			Net.Ride:FireClient(player, "SubDrop", "Kick", held.Model)
		else
			sub.Done = true
			if RideService.fling(player) then
				Net.Ride:FireClient(player, "SubDrop", "Fling")
			end
		end
	end
	if sub.Cued and not sub.Done and t >= dropAt + trip.DropTime + c.Late then
		-- no word from the player's machine: on their fish anyway, or let go
		sub.Done = true
		local held = sub.Held
		if held and held.Model.Parent and RideService.seatOn(player, held) then
			sub.Held = nil
		else
			RideService.letGo(player)
		end
	end
	if sub.Done and t >= endAt + 4 then
		finish(player, sub)
	end
end

local function join(player: Player)
	local sub: Sub = {
		Tier = 0,
		Equip = 0,
		Dest = 0,
		Fish = "",
		Ride = nil,
		Own = nil,
		Moved = false,
		Loose = false,
		Trip = nil,
		Phase = nil,
		Held = nil,
		Cued = false,
		Done = false,
		Asked = 0,
		Aloft = false,
		DropPoint = nil,
		DropS = 0,
		Stocked = false,
	}
	subs[player] = sub
	tell(player, sub)
end

-- Studio's tests only (a script can't send the player's remotes): ServerStorage.SubTest:Invoke(op, userId, ...),
--   "give", coins, { {id, size, variant} } | "home" (back on the dock) | "buy" | "equip", n | "pick", land, fishKey |
--   "near" (is the player at the stand?); each returns the state as JSON. buy, equip and pick skip the stand check
local function test(op: string, userId: number, a: any, b: any): any
	local player = Players:GetPlayerByUserId(userId)
	local sub = player and subs[player]
	if not player or not sub then
		return "no player"
	end
	if op == "give" then
		AquariumService.give(player, a or 0, b)
	elseif op == "home" then
		RideService.sendHome(player)
	elseif op == "buy" then
		buy(player, sub, nil, true)
	elseif op == "equip" then
		equip(player, sub, a, true)
	elseif op == "pick" then
		pick(player, sub, a, b or "", true)
	end
	return HttpService:JSONEncode({
		Tier = sub.Tier,
		Equip = sub.Equip,
		Near = atStand(player),
		Dest = sub.Dest,
		Fish = sub.Fish,
		Coins = AquariumService.coinsOf(player),
		Phase = sub.Phase,
		State = RideService.stateOf(player),
		Tank = player:GetAttribute("Tank"),
	})
end

-- The admin panel (AdminService, which has checked the player is allowed): every sub bought, for nothing, and the
-- best one equipped
function SubService.unlockAll(player: Player)
	local sub = subs[player]
	if not sub then
		return
	end
	local top = math.min(#Config.Sub.Prices, lands() - 1)
	if top <= sub.Tier then
		return
	end
	sub.Tier = top
	sub.Equip = top
	sub.Dest = top + 1
	tell(player, sub)
	Net.Ride:FireClient(player, "SubBought", top)
end

-- For saving (src/server/Lib/SaveParts.luau, the UI chat's saving, part "Sub"): the subs bought (the tier, 0: none)
-- and the one equipped (0: none). nil while we don't have the player (not joined yet, or gone), never a default 0.
-- Neither yields.
function SubService.tierOf(player: Player): number?
	local sub = subs[player]
	return if sub then sub.Tier else nil
end

function SubService.equipOf(player: Player): number?
	local sub = subs[player]
	return if sub then sub.Equip else nil
end

-- For saving (SaveParts, part "Sub", which only calls it with a higher tier): the subs bought up to `tier` (a whole tier
-- that exists, clamped to 0 .. #Sub.Prices) and `equipped` equipped (clamped to 0 .. tier; not a number: the one
-- equipped now), its furthest land picked as equipping does, no coins taken; the attributes the stand and the HUD read
-- are told at once, without the "bought" banner. A trip under way is not touched (it has its land already). False for
-- a player we don't have or a tier that is not a number. Doesn't yield.
function SubService.setSub(player: Player, tier: number, equipped: number?): boolean
	local sub = subs[player]
	if not sub or type(tier) ~= "number" or tier ~= tier then
		return false
	end
	local top = math.clamp(math.floor(tier), 0, #Config.Sub.Prices)
	local on = if type(equipped) == "number" and equipped == equipped then math.floor(equipped) else sub.Equip
	on = math.clamp(on, 0, top)
	sub.Tier = top
	sub.Equip = on
	sub.Dest = if on == 0 then 0 else on + 1
	tell(player, sub)
	return true
end

function SubService.Init()
	RideService.Diving = diving
	RideService.DiveFish = diveFish
	Net.Action.OnServerEvent:Connect(function(player, action, a, b)
		local sub = subs[player]
		if not sub or type(action) ~= "string" then
			return
		end
		if action == "SubBuy" then
			buy(player, sub, a)
		elseif action == "SubEquip" then
			equip(player, sub, a)
		elseif action == "SubPick" then
			pick(player, sub, a, b)
		elseif action == "SubLand" then
			landed(player, sub, a)
		elseif action == "SubLeap" then
			leaps(player, sub, a)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local sub = subs[player]
		if sub then
			finish(player, sub)
		end
		subs[player] = nil
	end)
end

function SubService.Start()
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		if not subs[player] then
			join(player)
		end
	end
	if RunService:IsStudio() then
		local ask = Instance.new("BindableFunction")
		ask.Name = "SubTest"
		ask.OnInvoke = test
		ask.Parent = ServerStorage
	end
	RunService.Heartbeat:Connect(function()
		for player, sub in subs do
			local trip = sub.Trip
			if trip then
				step(player, sub, trip)
			end
		end
	end)
end

return SubService
