--!strict
-- Riding a fish in your own tank (Hugo, 2026-11-20, task k1: "make fishes in the tank rideable (in the tank)";
-- Config.TankRide, docs/design/aquarium.md "Riding in the tank"). Practice with nothing at stake: the player stays
-- "Dock" to RideService the whole time, so there is no Oxygen, no fail or throw-off, no taming and no catch.
-- Since task b4 (Hugo, 2026-11-22): got on by looking at a fish and holding E (TankRideController), ridden with full
-- control, and the fish keeps its real size, so it is the RIDER (the fish's Saddle) who is kept in the water.
--   TankRide.Direct 1 (the user, 2026-11-25): E on a tank fish takes it out of the tank, equips it and rides it on land
--   where the player stands; nothing under here about riding inside the water then happens.
--   Getting on: Action "TankRide", "On", fish. Only the tank's owner, on the dock, at their own tank, onto one of
--   the fish swimming in THEIR tank now (a fish of another tank is refused: "NotYours"). The fish stops its lap where
--   everyone sees it (its "TankFish" tag comes off, so no machine moves it round any more), is made loose and given
--   two movers (TankAlign, TankTurn), the rider is welded to its Saddle, and the rider's machine is given the fish to
--   move (its network owner), so everyone sees it go where the rider takes it. The rider is told ("TankMounted",
--   fish, box CFrame, box half size: the inside of the water the Saddle must stay in) and the player's "TankRide"
--   attribute is true (every machine poses them astride: AnimController).
--   Riding: TankRideController moves the movers' targets, the Saddle kept inside the box. Here, a few times a
--   second, a Saddle further out than TankRide.Slack is put back (so the rider never leaves the tank, whatever a
--   machine says).
--   Getting off: Action "TankRide", "Off" (E again), or anything that ends it (the fish rebuilt by a change to the
--   tank, a new body, leaving the dock, leaving the game). The rider is put on the floor in front of the tank, facing
--   it, and the tank's fish are put back in their laps (AquariumService.reshow).
--   Riding out (the user, 2026-11-23: "you should be able to ride a fish out of your tank as if you took it out";
--   Config.TankRide.Out, 0 in the file: written, not played): Action "TankRide", "Out", sent by the rider's machine
--   once they have pushed against the gate's span of the water's front face, outward, for TankRide.OutHold seconds.
--   Everything is checked first (the dial, a tank ride, its fish's entry still in the tank, room in the hands, the
--   land ride's own rules); a refusal leaves the tank ride as it was and says why (Ride "Denied", "TankRide", why:
--   "Off", "Gone", "Hands", "Equip", "Dock", "Again", "Dead", "Busy", "Empty"). Then, in one step: the tank ride ends
--   with no trip to the front and the fish not put back, the entry is taken out of the tank as "TakeOut" does
--   (AquariumService.takeOutKey), the rider stands just outside the gate facing out, and that fish is equipped and
--   ridden on land as Q does (RideService.rideOut). The rider's machine is told "TankDismounted", "Out".
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
	Saddle: Attachment,
	Water: BasePart,
	Gone: RBXScriptConnection,
	Key: string?, -- the ridden fish's entry in the tank (AquariumService.keyOfShown), for riding out
}

local TankRideService = {}

local rides: { [Player]: Ride } = {}

local function parts(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if root and root:IsA("BasePart") then root else nil, humanoid
end

-- The space the rider's seat may be in: the water, less the margin on every side
local function boxOf(water: BasePart): (CFrame, Vector3)
	local m = Config.TankRide.Margin
	local half = water.Size / 2
	return CFrame.new(water.Position) * water.CFrame.Rotation,
		Vector3.new(math.max(half.X - m, 0.5), math.max(half.Y - m, 0.5), math.max(half.Z - m, 0.5))
end

-- Where a tank's fish is in its lap now, and the way it goes: what every machine shows (AquariumController moves the
-- anchored fish itself, by these same numbers and the server's clock; here its Root is still where it was built)
local function lapOf(model: Model, root: BasePart): (Vector3, Vector3)
	local centre, reach = model:GetAttribute("TankCentre"), model:GetAttribute("TankReach")
	local phase, pace = model:GetAttribute("TankPhase"), model:GetAttribute("TankPace")
	local look = root.CFrame.LookVector
	if
		typeof(centre) ~= "Vector3"
		or typeof(reach) ~= "Vector3"
		or type(phase) ~= "number"
		or type(pace) ~= "number"
	then
		return root.Position, look
	end
	local kind = Config.FishById[tostring(model:GetAttribute("FishType"))]
	local long = if kind then kind.Size.Z * Config.sizeScale(Config.sizeTierOf(model), kind) else 0
	pace *= math.min(1, math.max((reach.X + reach.Z) / 2, 1) / math.max(long / 2, 1))
	local now = workspace:GetServerTimeNow()
	local angle = phase + now * pace
	local cos, sin = math.cos(angle), math.sin(angle)
	local at = centre + Vector3.new(cos * reach.X, math.sin(now * 0.6 + phase) * reach.Y, sin * reach.Z)
	local way = Vector3.new(-sin * reach.X, 0, cos * reach.Z) * (if pace < 0 then -1 else 1)
	return at, if way.Magnitude > 0.01 then way.Unit else look
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
	local root, humanoid = parts(player)
	local character = player.Character
	if not root or not humanoid or not character then
		return
	end
	-- only one of the fish in our OWN tank now: a fish of another tank is refused; nothing sent (the popup's RIDE A
	-- FISH): the one nearest us
	local model: Model? = nil
	if typeof(fish) == "Instance" then
		if not fish:IsA("Model") or fish.Parent ~= shown or not CollectionService:HasTag(fish, AquariumService.Tag) then
			Net.Ride:FireClient(player, "Denied", "TankRide", "NotYours")
			return
		end
		model = fish
	else
		local best = math.huge
		for _, m in shown:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart then
				local d = (lapOf(m, m.PrimaryPart) - root.Position).Magnitude
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
	local key = AquariumService.keyOfShown(player, model)
	if c.Direct == 1 then
		-- the fish comes to the player and is ridden on land, as "TakeOut" and then Q (the user, 2026-11-25: not stuck
		-- in the tank). Everything is checked before anything changes
		local why = if key then AquariumService.outRefusal(player, key) else "Gone"
		why = why or RideService.outRefusal(player)
		if why then
			Net.Ride:FireClient(player, "Denied", "TankRide", why)
			return
		end
		AquariumService.putAway(player)
		local carry = AquariumService.takeOutKey(player, key :: any)
		if carry then
			RideService.rideOut(player, carry)
		end
		return
	end
	AquariumService.putAway(player) -- (no fish held over the head while riding one)
	-- out of its lap, where every machine shows it now: no machine moves it round any more. It keeps its size
	local at, look = lapOf(model, fishRoot)
	CollectionService:RemoveTag(model, AquariumService.Tag)
	model:SetAttribute("TankRider", player.UserId)
	local box, half = boxOf(water)
	-- level, facing the way it was going, and moved so the seat is in the water
	fishRoot.CFrame = CFrame.lookAt(at, at + look)
	local seat = saddle.WorldPosition
	fishRoot.CFrame += clampInto(box, half, seat) - seat
	at = center.WorldPosition
	fishRoot.Anchored = false
	-- (limited, as the wild fish's movers are: a weld joined to an unlimited mover now and then threw the pair far;
	-- more for a heavy Root, so a giant is held up and comes round too)
	local heavy = math.max(fishRoot.AssemblyMass / 40, 1)
	local align = Instance.new("AlignPosition")
	align.Name = "TankAlign"
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = center
	align.Position = at
	align.MaxForce = 1e5 * heavy
	align.MaxVelocity = c.Speed * 4
	align.Responsiveness = 30
	align.Parent = fishRoot
	local turn = Instance.new("AlignOrientation")
	turn.Name = "TankTurn"
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = center
	turn.MaxTorque = 4e5 * heavy
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
		Saddle = saddle,
		Water = water,
		Gone = model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then
				-- (rebuilt by a change to the tank: the new ones are already in their laps)
				task.defer(finish, player, false)
			end
		end),
		Key = key,
	}
	rides[player] = ride
	AquariumService.putAway(player) -- (no fish over the head while astride one: grade issue 6)
	player:SetAttribute("TankRide", true)
	-- (and, for riding out, the gate: the floor just outside it, and the way out)
	local spot, way = AquariumService.frontOf(plot)
	Net.Ride:FireClient(player, "TankMounted", model, box, half, if spot then spot.Position else nil, way)
end

-- Riding the fish out of the tank through the gate (Config.TankRide.Out), as if it had been taken out and got on
local function out(player: Player)
	local ride = rides[player]
	if not ride then
		return -- (no tank ride, or this one has already gone out: nothing to do)
	end
	local function deny(why: string)
		Net.Ride:FireClient(player, "Denied", "TankRide", why)
	end
	if Config.TankRide.Out == 0 then
		deny("Off")
		return
	end
	-- everything checked before anything changes
	local key = ride.Key
	local why = if key then AquariumService.outRefusal(player, key) else "Gone"
	if not why then
		why = RideService.outRefusal(player)
	end
	if why then
		deny(why)
		return
	end
	local root, humanoid = parts(player)
	local character = player.Character
	local plot = AquariumService.plotOf(player)
	local spot: CFrame?, way: Vector3? = nil, nil
	if plot then
		spot, way = AquariumService.frontOf(plot)
	end
	if not key or not root or not humanoid or not character or not spot or not way then
		deny("Empty")
		return
	end
	-- (from here on, one step with no yield: the tank one fish fewer and the hands one more, never both or neither)
	rides[player] = nil
	ride.Gone:Disconnect()
	if ride.Weld.Parent then
		ride.Weld:Destroy()
	end
	player:SetAttribute("TankRide", nil)
	humanoid.PlatformStand = false
	PropService.riding(character, false)
	pcall(function()
		root:SetNetworkOwner(player)
	end)
	-- (told first: its camera and keys let go before the land ride's camera reads the zoom)
	Net.Ride:FireClient(player, "TankDismounted", "Out")
	-- out of the tank as "TakeOut" does: the fish in the water are shown again without it (the ridden model goes with
	-- the old ones)
	local carry = AquariumService.takeOutKey(player, key)
	-- just outside the gate, on the floor, facing out (frontOf's spot: 8 studs past the water's front face, so past
	-- the fence that stands 1.6 in front of it)
	local at = spot.Position + Vector3.new(0, 3, 0)
	character:PivotTo(CFrame.lookAt(at, at + way))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	if carry then
		RideService.rideOut(player, carry)
	else
		AquariumService.reshow(player) -- (checked above, so never: but no fish is left loose)
	end
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
			-- (the water as it is now: a plot stage bought makes it taller)
			local box, h = boxOf(ride.Water)
			local seat = ride.Saddle.WorldPosition
			local p = box:PointToObjectSpace(seat)
			if math.abs(p.X) > h.X + slack or math.abs(p.Y) > h.Y + slack or math.abs(p.Z) > h.Z + slack then
				ride.Root.CFrame += clampInto(box, h, seat) - seat
				ride.Root.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end
end

-- Test hook: only the Studio checks call this (tools/studio/b4_tank_ride_check.py).
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
		elseif verb == "Out" then
			out(player)
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
