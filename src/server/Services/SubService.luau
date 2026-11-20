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
--   you ride it after submarine"): the fish the player HOLDS over their head as they go in (AquariumService.heldOf,
--   one of the fish in their hands), else the tank fish picked at the stand ("SubFish"), else none (the fling). Its
--   kind, size and colour are fixed as the trip is made (Sub.Ride). It is borrowed, never taken: the hands (and the
--   tank) keep it whatever happens, a ride, a miss or a drown, and riding it tames nothing new.
--   The plain dive-in with a held fish (no sub equipped, no land picked, or Sub.On 0): RideService asks us
--   (RideService.DiveFish) and the held fish is made where the player goes in, and they are put straight on it.
--   If the player's machine says nothing for Sub.Late seconds, we let them go ourselves. A death, a reset or leaving
--   in the middle gives the trip up and takes the fish away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
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
	Trip: SubTrip.Trip?,
	Phase: string?,
	Held: Wild?, -- the player's fish, made for the drop-off
	Cued: boolean, -- the drop has been said
	Done: boolean, -- and it is over (they are flung, on their fish, or let go)
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

-- The fish a dive rides: the one held over the head first, else the tank fish picked at the stand (nil: none)
local function rideWith(player: Player, sub: Sub): RideService.Carry?
	local h = AquariumService.heldOf(player)
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

local function buy(player: Player, sub: Sub, checked: boolean?)
	local c = Config.Sub
	local next = sub.Tier + 1
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
	sub.Trip = nil
	sub.Phase = nil
	sub.Cued = false
	sub.Done = false
	sub.DropPoint = nil
	FishService.keepFor(player, nil)
	player:SetAttribute("SubTrip", nil)
	player:SetAttribute("SubPhase", nil)
end

-- The trip, made as the player goes in: they swim on from where they went in, down the lane, to the pick-up; from
-- there the herd's own line, Sub.Lift over the floor, to Sub.Into studs into the land, and on past it
local function begin(player: Player, sub: Sub, root: BasePart): boolean
	local c = Config.Sub
	local first = FishService.landStart(sub.Dest)
	if not first then
		warn("[SubService] no start for land " .. sub.Dest)
		return false
	end
	local entry = root.Position
	local swim = Config.Oxygen.SwimSpeed * c.Approach
	local ahead = laneWay(entry)
	local pickup = Vector3.new(entry.X, Config.Oxygen.SurfaceY - c.Under, entry.Z) + ahead * swim
	local sDrop = math.min(first + c.Into, FishService.streamLength() - 50)
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
	local points = { pickup }
	local dropAt = 0
	local length = 0
	local beyond = sDrop + c.DropSpeed * (c.Arrive + c.Drop + c.Kick + 6) + 200
	local s = sFrom
	while true do
		local p = FishService.streamPoint(math.min(s, beyond), c.Lift, 8)
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
	local ride = rideWith(player, sub)
	local trip = SubTrip.new(now(), sub.Dest, ride ~= nil, points, dropAt)
	sub.Trip = trip
	sub.Ride = ride
	sub.Phase = nil
	sub.Cued = false
	sub.Done = false
	sub.Held = nil
	sub.DropPoint = SubTrip.at(trip, SubTrip.dropDistance(trip))
	sub.DropS = sDrop
	sub.Stocked = false
	FishService.keepFor(player, sub.DropPoint)
	player:SetAttribute("SubTrip", SubTrip.encode(trip))
	player:SetAttribute("SubPhase", "Approach")
	-- (the player's machine is moved thousands of studs in seconds: the map at the drop point is sent ahead)
	local drop = sub.DropPoint :: Vector3
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(drop, 8)
		end)
	end)
	return true
end

-- Asked by RideService as a player on the dock goes into the water: does the sub take them?
local function diving(player: Player): boolean
	local sub = subs[player]
	if Config.Sub.On == 0 or not sub or sub.Trip or sub.Equip < 1 or sub.Dest < 2 or sub.Dest > sub.Equip + 1 then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local ok, began = pcall(begin, player, sub, root)
	if not ok then
		warn("[SubService] the trip could not be made: " .. tostring(began))
		return false
	end
	return began
end

-- Asked by RideService as a player on the dock goes into the water and the sub doesn't take them: with a fish held
-- over the head, that fish, made where they go in and kept for them (RideService puts them on it)
local function diveFish(player: Player): FishService.Wild?
	local sub = subs[player]
	local h = AquariumService.heldOf(player)
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
	if not sub.Done and state ~= "Carried" then
		-- given up in the middle: a death, a reset
		finish(player, sub)
		return
	end
	local phase = SubTrip.phase(trip, t)
	if phase ~= sub.Phase then
		sub.Phase = phase
		player:SetAttribute("SubPhase", if phase == "Done" then nil else phase)
	end
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
			trip.Fish = false
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
		Trip = nil,
		Phase = nil,
		Held = nil,
		Cued = false,
		Done = false,
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
		buy(player, sub, true)
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

function SubService.Init()
	RideService.Diving = diving
	RideService.DiveFish = diveFish
	Net.Action.OnServerEvent:Connect(function(player, action, a, b)
		local sub = subs[player]
		if not sub or type(action) ~= "string" then
			return
		end
		if action == "SubBuy" then
			buy(player, sub)
		elseif action == "SubEquip" then
			equip(player, sub, a)
		elseif action == "SubPick" then
			pick(player, sub, a, b)
		elseif action == "SubLand" then
			landed(player, sub, a)
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
