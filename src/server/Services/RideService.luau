--!strict
-- Riding, Oxygen, the jump fish to fish and drowning, all decided here (docs/design/riding-feel.md); clients only steer
-- and animate. Per player: a state (Dock, Free, Riding, Jumping, Drowning, mirrored in the player's State attribute),
-- the Oxygen meter (the design notes' stamina), and the fish they're on.
--   Riding drains Oxygen in ticks (Oxygen.Ticks: every piece 1 / Ticks of the max, each told to the client, Ride
--   "OxygenTick"), the whole meter in Config.secondsOn: longer on a fish that needs more (by the land the rider is in
--   and the fish's rarity, Config.required), a little longer with more max Oxygen (up to Oxygen.Cap, then only very
--   marginally), and longer means the ticks further apart (Config.tickOf). A fish too strong for you breaks off
--   Oxygen.BreakOff of the meter at once as one piece and empties what is left in StrainTime, less for each such
--   fish landed on in a row (Oxygen.RedShrink, RedRun: the user's rule of 2026-11-22). At
--   zero the fish throws you off and you drown (Drowning, DeathAt): the fail, which fades out and ends at the dock
--   with the dive's catch kept. A hop is never refused for Oxygen and costs none, so at almost nothing you can still
--   go fish to fish, and every landing refills.
--   Running the fish into something solid never kills (Config.Crash): it costs Oxygen and the client is told to slow.
--   A prop never stops a fish: one big enough for it breaks it (PropService, Config.propBreak), the rest go through.
--   Going fish to fish (Config.Jump): from a fish or from floating, the player leaves into a hop their own client
--   moves (the pop, the glide, the drop; A and D). That is the window, Jump.Window seconds, with no drain. To take a fish
--   the client says which it is going for ("Grab"): the server checks it is free and within the hook's reach (by the
--   hop's speed then, which the server works out itself: Config.reachOf, Config.hopSpeed) of the
--   player (the same hard cap the client uses) and keeps it for them, so two players
--   can't be pulled onto one fish. When the pull-in ends the client says so ("Land"): it must be the fish that was
--   granted, with the player now at it, and the server mounts them, with the refill. A refused grab costs nothing but
--   time: the window runs on. The window running out with no landing ("Miss", or the server's own clock) ends the run,
--   from a fish or from floating: you have sunk and drown (a short drown), until there is a revive.
--   Free (in the water off a fish: diving in off the dock, or a lost landing) drains Oxygen.FreeDrain; at zero you drown,
--   without the throw.
--   Drowning takes no input and ends at the dock.
--   Failing (Config.Fail, task e1): at 0 Oxygen on a fish (Rare and up) the rider is held on it a moment while it
--   does its own thing (eats you, rolls you off, drags you down: Config.failOf); no input, no drain. Then it throws
--   you into the drown, or (taken) it is the fail itself and ends at the dock.
--   Angry mode (Config.Angry): while a rider's meter is in its red part (Oxygen.AngryAt), or on a fish too strong from
--   the touch, the fish under them is angry. Decided here and written on the fish (its "Angry" and "AngryStyle"
--   attributes, and the "AngryFish" tag): every client pulses it red, and the rider's own slows it in its style's way
--   (Shared/AngryStyles), which the speed check here then holds it to.
--   The passive archetypes (Config.Archetype; docs/design/archetypes.md), all decided here: a Predator eats the
--   smaller wild fish its nose reaches (checkEat: the fish is gone, the rider gets a burst of speed and Oxygen; a
--   Frenzy chains them), a Breaker goes through props for nothing and is paid for it (checkCrash), a Tank drains
--   slower and turns angry later (Config.drainFor, Config.low), a Leaper's hop has a longer window (jump), a Fast
--   fish's bigger burst is allowed by the speed check (Config.surgeOf). The rider's client is told of a burst
--   ("Boost"), every client of the bite or the smash (Fx "Eat", "Smash"), and the fish carries "Bite", "Smash" and
--   "Frenzy" attributes for the animations to come.

-- In this file, in order:
--   Setup: services, modules, the rider record, the hooks other services fill in, and small helpers
--   The ride fish on land: building, welding, equipping and unequipping the fish a player walks on
--   Rider state and messages: angry mode, state changes, Oxygen and catch updates, refusals, reach checks
--   The ragdoll: swapping a thrown rider's joints for loose ones and putting them back
--   Mounting, going home and failing: getting on a fish, back to the dock, drowning and being thrown off
--   The hop: jumping off, missing, grabbing a fish in the air and landing on it
--   Oxygen, eating and crashes: the drain, the red part, archetype rewards, bites and hitting the map
--   Every frame: the speed check, taming, and each rider's tick by state
--   Players and characters: setting up a rider when a player joins or gets a new body
--   Sandbox and admin reset: where a reset puts a player, and putting them there
--   Remotes: the ride fish's asks, then Init with the Action handler and players leaving
--   For other services, and Start: carried fish, seating, sending home, max Oxygen, forced fails

----------------------------------------------------------------------------------------------------------------------
-- Setup: services, modules, the rider record, the hooks other services fill in, and small helpers

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AngryStyles = require(ReplicatedStorage.Shared.AngryStyles)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RideStyles = require(ReplicatedStorage.Shared.RideStyles)
local Variants = require(ReplicatedStorage.Shared.Variants)
local FishModel = require(script.Parent.Parent.Lib.FishModel)
local FishService = require(script.Parent.FishService)
local PropService = require(script.Parent.PropService)

type Wild = FishService.Wild
export type Carry = { Id: string, Size: string, Variant: string }
type Rider = {
	Player: Player,
	State: string,
	Oxygen: number,
	Max: number,
	Fish: Wild?,
	Weld: Weld?,
	JumpAt: number, -- os.clock() the jump began
	JumpFrom: Wild?, -- the fish it left
	GrabAt: number, -- server time of the accepted grab; bounds the pull separately from the hop
	Grab: Wild?, -- the fish granted to this jump's pull-in (kept for us until the landing)
	Token: number, -- bumps on every move and death, so a stale landing or respawn does nothing
	JumpReadyAt: number,
	SentOxygen: number,
	SentAt: number,
	SentDrain: number, -- the Oxygen a second last told to the client (the Drain attribute): 0 off a fish
	Strained: boolean, -- the fish under us is too strong for us (decided at the mount): the meter empties at once
	RedRun: number, -- fish too strong for us landed on in a row (Oxygen.RedShrink): 0 after a fish we hold, or at the Dock state
	AngryFish: Wild?, -- the fish we have marked angry (its attributes and tag are ours to take off again)
	AngryAt: number, -- os.clock() it turned angry
	Tame: number, -- how far the fish under us is from being ours, 0 to 1 (Config.tameTime)
	TickAt: number, -- os.clock() the next Oxygen tick is due (Config.tickOf); -1: a new stretch, not yet counted
	TickPiece: number, -- the piece the next tick takes when its gap was made longer in the red part (redGap); 0: none
	StrainPiece: number, -- on a fish too strong: each tick's piece of what the break-off left (Config.strainTicks)
	StrainEvery: number, -- and the seconds between them
	RedPiece: number, -- in the red part (Oxygen.RedTime): each tick's piece of what was left at the line; 0: not in it
	RedEvery: number, -- and the seconds between them (Config.redTicks)
	SentTame: number, -- the Tame attribute as last told (-1: none)
	Tamed: { [Wild]: boolean }, -- the fish made ours on this dive (so one fish is not tamed twice)
	Caught: { string }, -- what we carry: fish ids, oldest first (with an aquarium: until it is put in the tank)
	Carried: { Carry }, -- the same fish, each with its size and colour (what the aquarium needs to know)
	Owned: number, -- creatures brought home this session
	Trained: number, -- max Oxygen gained on the training spot this session (TrainService), on top of the start
	Banked: number, -- Oxygen bought off the dock: it joins Trained (and the max) on reaching the dock (grantOxygen)
	Landings: number, -- landings so far this session: sent with each "Land", so every client picks the same reaction
	SandboxRetries: number, -- times the sandbox's reset has been done again by itself after a seat that went wrong
	SandboxSeat: FishService.Wild?, -- the fish the sandbox's reset is seating us on (kept for us until we say we sit)
	CheckAt: number,
	CheckFrom: Vector3?,
	Flagged: boolean,
	SurfacedAt: number?, -- os.clock() a Free rider came up near the dock
	Rode: boolean, -- we have sat on a fish since we last left the dock (the dive-in, Config.Dive: until then no send-back to the dock and no drowning for a miss)
	DiveHop: boolean, -- this hop is one from floating before the first ride of the dive: forgiven if it lands on nothing
	CrashCheckAt: number, -- os.clock() of the next look for something in the fish's way
	CrashReadyAt: number, -- and before this a crash or a smashed prop costs nothing
	Nosed: boolean, -- the fish's nose is up against something solid (so it is counted once)
	FastAt: number, -- os.clock() the fish was last seen going fast enough to crash
	-- the passive archetypes (Config.Archetype)
	JumpExtra: number, -- seconds this hop's glide and window are longer by (off a Leaper; airtime by speed)
	MountSpeed: number, -- how fast the fish was going as we mounted it (the first speed check allows it)
	RideSpeed: number, -- how fast the fish under us is going, as WE see it move (its place from frame to frame, eased): a hop's numbers are from it
	RideFrom: Vector3?, -- where that fish was last frame
	JumpLaunch: number, -- this hop's speed as it left (Config.hopFrom, from the speed we saw the fish leave at): the hook's reach is counted from it
	BoostUntil: number, -- os.clock() the last burst of speed we were given ends (an eat's, a smash's),
	BoostMost: number, -- and how many times its speed the fish may go until then (the speed check)
	EatCheckAt: number, -- os.clock() of the next look for something to eat
	EatReadyAt: number, -- and before this the fish under us doesn't bite again (Predator.Cooldown)
	AteAt: number, -- os.clock() of its last bite,
	Frenzy: number, -- and the Frenzy's stacks so far (0: none)
	BreakReadyAt: number, -- before this a broken prop pays a Breaker nothing more (Breaker.Cooldown)
	-- the ride fish (task e3, Config.Equip): one entry of Carried, that very table (not a copy, and not counted again)
	Equipped: Carry?,
	EquipAt: number, -- os.clock() of the last equip ask taken
	Land: Land?, -- while riding it on land in the hub
}
-- The equipped fish under the rider on land: its model, welded under the root, and what the humanoid had before
-- (Good, GoodAt: where the rider last stood when their pace was checked and found fair, and when: grade issue 7)
type Land = {
	Model: Model,
	Body: Model,
	Humanoid: Humanoid,
	Hip: number,
	Walk: number,
	Good: Vector3,
	GoodAt: number,
}

local RideService = {}

-- Set by AquariumService when the map has tanks: whether this player's catch is kept in hand at the dock (they have a
-- tank to put it in), and where they come home to (nil: the dock's spawn)
RideService.Keeps = nil :: ((player: Player) -> boolean)?
RideService.Home = nil :: ((player: Player) -> CFrame?)?
-- Set by SubService: asked as a player on the dock goes into the water. true: the submarine takes them (state
-- "Carried": no drain, no hop, no send-back, until SubService lets them go with RideService.fling, seatOn or letGo)
RideService.Diving = nil :: ((player: Player) -> boolean)?
-- Set by SubService: asked next, when the sub doesn't take them. A fish (the one held over the head, task f2): made
-- where they go in and kept for them; they are put straight on it, as a landing, instead of the dive-in's hop
RideService.DiveFish = nil :: ((player: Player) -> Wild?)?
-- Set by AquariumService (the hold, task f1): the fish held over the head (one of Carried, the very table), and putting
-- it away. Q equips the held fish (task e3)
RideService.HeldOf = nil :: ((player: Player) -> Carry?)?
RideService.PutAway = nil :: ((player: Player) -> ())?
-- Set by LessonService (docs/design/first-minutes.md; only with Config.Lesson.On): whether this player is still to make
-- their first fish theirs (it must be one they can hold, its meter doesn't run and they can't hop off it); and told of
-- each tame
RideService.FirstFish = nil :: ((player: Player) -> boolean)?
RideService.OnTamed = nil :: ((player: Player, w: Wild) -> ())?

-- The sandbox's reset seats a rider only on a fish that has been in the Workspace this long, so the player's machine
-- has the fish too (it is told to sit on it).
local SEAT_SETTLED = 1

local riders: { [Player]: Rider } = {}
-- the ragdolls (ragdoll, below): who is loose, and what to put back
type Loose = {
	Character: Model,
	Joints: { Instance }, -- the joints switched off
	Made: { Instance }, -- what we made (the ball sockets and their attachments)
	Collide: { [BasePart]: boolean }, -- each part's own CanCollide
	Friction: { [BallSocketConstraint]: number }, -- an avatar's own ball sockets' friction, as it was
	Neck: boolean, -- the Humanoid's RequiresNeck
	Token: number,
}
local looseOf: { [Player]: Loose } = {}
local looseToken = 0
local dockSpawn: BasePart? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

-- The first-fish rule is on for this rider (RideService.FirstFish)
local function firstFish(r: Rider): boolean
	return RideService.FirstFish ~= nil and RideService.FirstFish(r.Player)
end

-- The movement sandbox's switches (Studio only; SandboxService sets the attributes), or the same switch from the admin
-- panel for this rider alone (AdminService: the player attributes AdminNoFail and AdminEndlessAir, server-set)
local function sandbox(flag: string, r: Rider?): boolean
	if r and r.Player:GetAttribute("Admin" .. flag) == true then
		return true
	end
	return RunService:IsStudio()
		and workspace:GetAttribute("Sandbox") == true
		and workspace:GetAttribute("Sandbox" .. flag) == true
end

local function parts(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

local function findDockSpawn(): BasePart?
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and (d:GetAttribute("DockSpawn") or d.Name == "DockSpawn") then
			return d
		end
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local spawn = dock and dock:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn
	end
	return nil
end

-- Max Oxygen: the start value, or in Studio the test override (workspace attribute, else Config)
local function maxOxygen(): number
	if RunService:IsStudio() then
		local live = workspace:GetAttribute("TestMaxOxygen")
		local test = if type(live) == "number" then live else Config.Oxygen.StudioMax
		if test > 0 then
			return test
		end
	end
	return Config.Oxygen.StartMax
end

-- Oxygen bought in the water (Banked, grantOxygen) joins the training and the max, for a rider who is reaching the
-- dock: the caller fills the meter and tells the HUD, as it does anyway
local function unbank(r: Rider)
	if r.Banked > 0 then
		r.Trained += r.Banked
		r.Banked = 0
		r.Max = maxOxygen() + r.Trained
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The ride fish on land: building, welding, equipping and unequipping the fish a player walks on

-- The ride fish on land (task e3, Config.Equip; docs/design/equip.md). The equipped fish is built at its own size and
-- colour, weightless and touching nothing, and welded under the player's root by its saddle, as on a dive's fish; the
-- humanoid stands taller by the fish's depth below the saddle, so it walks on the floor and carries the rider. The
-- humanoid still does the walking (E4, land movement by body type, moves the fish's own joints over it). In
-- Workspace.LandFish, not Workspace.Fish: nothing locks on to it, tags it or tames it. Shown only on the dock.
local landFolder: Folder? = nil
local equipAsk: (r: Rider, action: string) -> ()

local function landFolderOf(): Folder
	if landFolder and landFolder.Parent then
		return landFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = "LandFish"
	folder.Parent = workspace
	landFolder = folder
	return folder
end

-- Off the land fish: its model goes and the humanoid is as it was (the equipped choice is kept)
local function landOff(r: Rider)
	local land = r.Land
	if not land then
		return
	end
	r.Land = nil
	land.Model:Destroy()
	if land.Humanoid.Parent and r.Player.Character == land.Body then
		land.Humanoid.HipHeight = land.Hip
		land.Humanoid.WalkSpeed = land.Walk
	end
	r.Player:SetAttribute("LandMounted", nil)
end

-- Seated somewhere else (the seahorse trainer, a tank ride) or dead: no land fish, no Q
local function busy(r: Rider): boolean
	local player = r.Player
	if player:GetAttribute("TrainerRide") ~= nil or player:GetAttribute("TankRide") ~= nil then
		return true
	end
	local _, humanoid = parts(player)
	return humanoid == nil or humanoid.Sit
end

-- On the equipped fish, on land: only on the dock, with a body, not seated elsewhere
local function landOn(r: Rider): boolean
	local carry = r.Equipped
	local root, humanoid = parts(r.Player)
	local kind = carry and Config.FishById[carry.Id]
	if r.Land or not carry or not kind or not root or not humanoid or r.State ~= "Dock" or busy(r) then
		return r.Land ~= nil
	end
	-- (nothing over the head while riding: one pose at a time)
	if RideService.PutAway then
		RideService.PutAway(r.Player)
	end
	local model = FishModel.build(kind)
	CollectionService:RemoveTag(model, FishModel.Tag)
	Variants.apply(model, carry.Variant)
	local scale = Config.sizeScale(carry.Size, kind)
	local most = Config.Equip.LandMost
	if most > 0 then
		scale = math.min(scale, most / math.max(kind.Size.Z, 0.1))
	end
	model:ScaleTo(model:GetScale() * scale)
	local fishRoot = model.PrimaryPart
	local saddle = fishRoot and fishRoot:FindFirstChild("Saddle")
	if not fishRoot or not saddle or not saddle:IsA("Attachment") then
		model:Destroy()
		return false
	end
	-- (the seat's own height above the back is not scaled, as FishService's resize)
	saddle.Position -= Vector3.new(0, Config.Ride.SeatHeight * (scale - 1), 0)
	for _, d in model:GetDescendants() do
		if d:IsA("Constraint") or d:IsA("Trail") then
			d:Destroy() -- (its movers and its wake)
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
		end
	end
	-- how far its belly is under the saddle, upright: the humanoid's root stands that high
	model:PivotTo(CFrame.new())
	local box, size = model:GetBoundingBox()
	local depth = saddle.WorldPosition.Y - (box.Position.Y - size.Y / 2)
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else 0
	local hip = math.max(humanoid.HipHeight, depth - root.Size.Y / 2 - legs)
	local land: Land = {
		Model = model,
		Body = r.Player.Character :: Model,
		Humanoid = humanoid,
		Hip = humanoid.HipHeight,
		Walk = humanoid.WalkSpeed,
		Good = root.Position,
		GoodAt = os.clock(),
	}
	-- facing the way the player faces, the saddle at the root
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local lift = Vector3.new(0, hip - humanoid.HipHeight, 0)
	local seat = root.Position + lift
	local want = CFrame.lookAt(seat, seat + look) * saddle.CFrame:Inverse() -- (the fish's root there)
	model:PivotTo(want * (model:GetPivot():Inverse() * fishRoot.CFrame):Inverse())
	local weld = Instance.new("Weld")
	weld.Name = "LandWeld"
	weld.Part0 = fishRoot
	weld.Part1 = root
	weld.C0 = saddle.CFrame
	weld.Parent = fishRoot
	model.Name = r.Player.Name
	model:SetAttribute("LandRider", r.Player.UserId)
	-- (the moment it was mounted, on the server's clock: every machine's stride starts from it, grade issue 10)
	model:SetAttribute("LandEpoch", workspace:GetServerTimeNow())
	model:SetAttribute("FishType", carry.Id)
	model:SetAttribute("SizeTier", carry.Size)
	model:SetAttribute("Variant", carry.Variant)
	model.Parent = landFolderOf()
	root.CFrame += lift
	land.Good = root.Position
	humanoid.HipHeight = hip
	humanoid.WalkSpeed = Config.Equip.LandSpeed
	r.Land = land
	r.Player:SetAttribute("LandMounted", true)
	return true
end

-- What the player's machine is told of the ride fish: its kind, size, colour and its place in the hands now
local function tellEquip(r: Rider)
	local carry = r.Equipped
	local index = if carry then table.find(r.Carried, carry) else nil
	local player = r.Player
	player:SetAttribute("EquippedFish", if carry and index then carry.Id else nil)
	player:SetAttribute("EquippedSize", if carry and index then carry.Size else nil)
	player:SetAttribute("EquippedVariant", if carry and index then carry.Variant else nil)
	if player:GetAttribute("EquippedIndex") ~= index then
		player:SetAttribute("EquippedIndex", index)
	end
end

local function unequip(r: Rider)
	landOff(r)
	r.Equipped = nil
	tellEquip(r)
end

-- After any change to the hands: the ride fish is still that very entry, at its new place, or it has gone (put in the
-- tank, or any other way) and is unequipped
local function checkEquip(r: Rider)
	if r.Equipped and not table.find(r.Carried, r.Equipped) then
		unequip(r)
	elseif r.Equipped then
		tellEquip(r)
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Rider state and messages: angry mode, state changes, Oxygen and catch updates, refusals, reach checks

-- Angry mode: the fish under a rider is marked angry, or calm again. Its attributes are how every client knows
-- ("Angry": true; "AngryStyle": its style's name, for the animations to come), its tag is how they find it.
local function setAngry(r: Rider, w: Wild?)
	local was = r.AngryFish
	if was == w then
		return
	end
	if was then
		was.Model:SetAttribute("Angry", nil)
		was.Model:SetAttribute("AngryStyle", nil)
		CollectionService:RemoveTag(was.Model, Config.Angry.Tag)
	end
	r.AngryFish = w
	if w then
		r.AngryAt = os.clock()
		w.Model:SetAttribute("AngryStyle", AngryStyles.of(w.Type).Name)
		w.Model:SetAttribute("Angry", true)
		CollectionService:AddTag(w.Model, Config.Angry.Tag)
	end
end

-- Whether the fish under this rider is angry now: the meter in its red part, or a fish too strong (from the touch)
local function isAngry(r: Rider, w: Wild): boolean
	local a = Config.Angry
	if a.On == 0 then
		return false
	end
	if a.Tamed == 0 and r.Tamed[w] then
		return false
	end
	if RunService:IsStudio() and a.Test > 0 then
		return true
	end
	-- (a Tank's red part starts lower: Config.angryAt)
	return r.Strained or Config.low(r.Oxygen, r.Max, w.Type)
end

local function setState(r: Rider, state: string)
	if state ~= "Dock" then
		-- (off the dock: the land fish goes, the equipped choice stays for the dive: task e3)
		landOff(r)
	else
		-- (the surface, by whichever way: the next red fish is a first one again, Oxygen.RedShrink)
		r.RedRun = 0
	end
	if state ~= "Free" then
		r.SurfacedAt = nil
	end
	if state == "Dock" then
		-- back on the dock: the next time into the water is a new dive (Config.Dive)
		r.Rode = false
		r.DiveHop = false
	elseif state == "Riding" then
		r.Rode = true
	end
	-- (the fast fish ease a little past a player in the hop: Config.Jump.FastEase)
	FishService.setHopping(r.Player, state == "Jumping")
	if state ~= "Jumping" and r.Grab then
		-- the pull-in is over, one way or another: the fish it was granted is let go (nothing to do once we ride it)
		FishService.unreserve(r.Grab, r.Player)
		r.Grab = nil
	end
	if state ~= "Failing" then
		r.Player:SetAttribute("FailKind", nil)
		r.Player:SetAttribute("FailAt", nil)
	end
	if state ~= "Drowning" then
		r.Player:SetAttribute("DeathAt", nil)
		r.Player:SetAttribute("DeathThrown", nil)
		r.Player:SetAttribute("DeathQuick", nil)
		r.Player:SetAttribute("DeathLoose", nil)
	end
	if state ~= "Riding" then
		if r.SentDrain ~= 0 then
			r.SentDrain = 0
			r.Player:SetAttribute("Drain", 0)
		end
		if r.Strained then
			r.Strained = false
			r.Player:SetAttribute("Strained", nil)
			r.Player:SetAttribute("StrainSeconds", nil)
		end
		if r.SentTame ~= -1 then
			r.SentTame = -1
			r.Player:SetAttribute("Tame", nil)
		end
		setAngry(r, nil)
	end
	if state ~= r.State and (state == "Riding" or state == "Free") then
		-- a new stretch of drain: its first tick is a whole gap away (counted at its first frame: tickDrain)
		r.TickAt = -1
	end
	r.State = state
	r.Player:SetAttribute("State", state)
	-- (on a fish the rider's body is solid to nothing: the fish's own steering keeps both in open water)
	local character = r.Player.Character
	if character then
		PropService.riding(character, state == "Riding" or state == "Failing")
		if looseOf[r.Player] then
			-- (a ragdoll stays solid to the map, the props and the fish whatever the state: ragdoll, below)
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") then
					d.CollisionGroup = "Ragdoll"
				end
			end
		end
	end
end

local function sendOxygen(r: Rider, force: boolean?)
	local t = os.clock()
	-- (ten times a second while it changes, or at once when it has moved a twentieth of the meter. It was "by half a
	-- point", which at 40 a second and more is every frame, to every client: the HUD counts down between updates)
	if
		force
		or math.abs(r.Oxygen - r.SentOxygen) >= r.Max * 0.05
		or (t - r.SentAt > 0.1 and r.Oxygen ~= r.SentOxygen)
	then
		r.SentOxygen = r.Oxygen
		r.SentAt = t
		r.Player:SetAttribute("Oxygen", math.floor(r.Oxygen * 10 + 0.5) / 10)
		-- (a whole number: training gives whole numbers only, task e1)
		r.Player:SetAttribute("MaxOxygen", math.floor(r.Max + 0.5))
	end
end

-- What this fish needs (task e1): its own whole number, by its kind, rarity, size and colour (Config.requiredOf),
-- never by the land it is in. The tag, the strain, the drain, the tame and the tank's coins all read this one number.
local function needOf(w: Wild): number
	return Config.requiredOf(w.Type, w.SizeTier, w.Variant)
end

-- What the rider carries on this dive, told to their client
local function sendCaught(r: Rider)
	Net.Ride:FireClient(r.Player, "Caught", r.Caught)
	checkEquip(r)
end

-- (`target`: the fish a refused grab or landing was for, so the client can tell an old refusal from one for the fish
-- it is being pulled to now)
local function deny(r: Rider, action: string, reason: string, target: any?)
	Net.Ride:FireClient(r.Player, "Denied", action, reason, if typeof(target) == "Instance" then target else nil)
end

-- Off the fish. A jump lets our client coast the old fish a while (no hitch in front of us).
local function dismount(r: Rider, reason: string, handBack: boolean?)
	local w = r.Fish
	setAngry(r, nil) -- (off the fish: it is calm again at once, whoever lands on it next)
	if w and r.Frenzy > 0 then
		r.Frenzy = 0
		w.Model:SetAttribute("Frenzy", nil)
	end
	if r.Weld then
		r.Weld:Destroy()
		r.Weld = nil
	end
	r.Fish = nil
	if w then
		FishService.release(w, if handBack then Config.Switch.HandBack else nil)
	end
	local root = parts(r.Player)
	if root then
		pcall(function()
			root:SetNetworkOwner(r.Player)
		end)
	end
	Net.Ride:FireClient(r.Player, "Dismounted", reason)
end

-- How far the player is from a fish, allowing for the delay (Config.Net.Lag): the rider's machine saw the fish a
-- moment late and we see the rider a moment late, so a fish going fast is ahead of where the rider was by its speed
-- times both moments. The fish is put back along its own velocity by up to Lag (and the player's ping) and the player
-- on along theirs by up to PlayerLag, and the nearest of those is the distance. Also the plain distance, for the log.
local function nearness(r: Rider, w: Wild, root: BasePart): (number, number)
	local n = Config.Net
	local gap = w.Root.Position - root.Position
	local plain = gap.Magnitude
	local ping = 0
	pcall(function()
		ping = r.Player:GetNetworkPing()
	end)
	local lag = math.max(n.Lag, 0) + math.clamp(ping, 0, math.max(n.PingMost, 0))
	if lag <= 0 then
		return plain, plain
	end
	local fishVelocity = w.Root.AssemblyLinearVelocity
	local ownVelocity = root.AssemblyLinearVelocity
	local best = plain
	for i = 1, 12 do
		local t = lag * i / 12
		best = math.min(best, (gap - fishVelocity * t - ownVelocity * math.min(t, n.PlayerLag)).Magnitude)
	end
	return best, plain
end

-- The same for the hook's reach, to the fish's whole body (Lock.WholeBody, Config.bodyGap: the box of its length,
-- height and width round its middle, turned as it swims), not its middle: the client's lock and grab measure it so
-- (the user, 2026-11-18: "so that large fish dont feel further than they are"). With the same allowance for the delay.
local function reachNearness(r: Rider, w: Wild, root: BasePart): (number, number)
	local n = Config.Net
	local at = w.Root.CFrame
	local plain = Config.bodyGap(at, w.Body, root.Position)
	local ping = 0
	pcall(function()
		ping = r.Player:GetNetworkPing()
	end)
	local lag = math.max(n.Lag, 0) + math.clamp(ping, 0, math.max(n.PingMost, 0))
	if lag <= 0 then
		return plain, plain
	end
	local fishVelocity = w.Root.AssemblyLinearVelocity
	local ownVelocity = root.AssemblyLinearVelocity
	local best = plain
	for i = 1, 12 do
		local t = lag * i / 12
		local fishThen = at - fishVelocity * t
		best = math.min(best, Config.bodyGap(fishThen, w.Body, root.Position + ownVelocity * math.min(t, n.PlayerLag)))
	end
	return best, plain
end

-- (Studio only: each grab and landing judged, in the Output, to see what the delay costs)
-- (`middle`: for a grab, how far the fish's middle was as seen: the reach used to be measured to it)
local function judged(r: Rider, what: string, w: Wild, near: number, plain: number, reach: number, middle: number?)
	if RunService:IsStudio() then
		print(
			string.format(
				"[RideCheck] %s %s: %.1f studs (%.1f as seen%s), reach %.1f, fish %.0f studs a second, %.0f long: %s",
				r.Player.Name,
				what,
				near,
				plain,
				if middle then string.format(", %.1f to its middle", middle) else "",
				reach,
				w.Root.AssemblyLinearVelocity.Magnitude,
				w.Body.Z,
				if near <= reach then "in" else "OUT"
			)
		)
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The ragdoll: swapping a thrown rider's joints for loose ones and putting them back

-- The ragdoll (Config.Fail.Ragdoll; Hugo, 2026-11-19, task f3: "enable a real Roblox ragdoll (BallSocketConstraints
-- replacing Motor6Ds on the character) with an impulse, colliding with the map, props and the fish"). The joints are
-- the server's to change, so the swap is made here; the body stays the rider's own machine's to move (its network
-- owner), which throws it, holds it up in the water and lets the fish grab it (FailController). The character's
-- "Ragdoll" attribute says it is loose (the server time it began). Every joint but the root's is swapped (an avatar's
-- Motor6Ds, or the newer AnimationConstraints), the limbs made solid ("Ragdoll" group: the map, the props and the
-- fish, never another player), and it is all put back as it was by unragdoll.
local ROOT_JOINTS = { Root = true, RootJoint = true }
-- how far each joint may swing (by the R15 joint names; an R6 one by its own)
local function limitsOf(name: string): (number, number)
	if string.find(name, "Neck") then
		return 35, 25
	elseif string.find(name, "Knee") or string.find(name, "Elbow") then
		return 60, 5
	elseif string.find(name, "Ankle") or string.find(name, "Wrist") then
		return 25, 10
	elseif string.find(name, "Waist") then
		return 25, 20
	end
	return 75, 40 -- shoulders and hips
end

local function unragdoll(player: Player)
	local l = looseOf[player]
	if not l then
		return
	end
	looseOf[player] = nil
	for _, made in l.Made do
		made:Destroy()
	end
	for _, j in l.Joints do
		if j.Parent then
			(j :: any).Enabled = true
		end
	end
	for part, was in l.Collide do
		if part.Parent then
			part.CanCollide = was
		end
	end
	for socket, was in l.Friction do
		if socket.Parent then
			socket.MaxFrictionTorque = was
		end
	end
	local humanoid = l.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.RequiresNeck = l.Neck
	end
	-- (back to the group the body had: solid to the map off a fish, PropService)
	local group = if l.Character:GetAttribute("Riding") then "Riding" else "Riders"
	for _, d in l.Character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
	l.Character:SetAttribute("Ragdoll", nil)
end

-- `seconds`: how long it stays loose (nil: until the dock, toDock)
local function ragdoll(r: Rider, seconds: number?): boolean
	local character = r.Player.Character
	local root, humanoid = parts(r.Player)
	if not character or not root or not humanoid or Config.Fail.Ragdoll.On == 0 then
		return false
	end
	if looseOf[r.Player] then
		unragdoll(r.Player)
	end
	looseToken += 1
	local l: Loose = {
		Character = character,
		Joints = {},
		Made = {},
		Collide = {},
		Friction = {},
		Neck = humanoid.RequiresNeck,
		Token = looseToken,
	}
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	local friction = Config.Fail.Ragdoll.Friction
	local function socket(name: string, a0: Attachment, a1: Attachment, parent: Instance)
		local swing, twist = limitsOf(name)
		local b = Instance.new("BallSocketConstraint")
		b.Name = "Ragdoll_" .. name
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.LimitsEnabled = true
		b.UpperAngle = swing
		b.TwistLimitsEnabled = true
		b.TwistLowerAngle = -twist
		b.TwistUpperAngle = twist
		b.MaxFrictionTorque = friction
		b.Restitution = 0
		b.Parent = parent
		table.insert(l.Made, b)
	end
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and not ROOT_JOINTS[d.Name] and d.Enabled and d.Part0 and d.Part1 then
			local p0, p1 = d.Part0 :: BasePart, d.Part1 :: BasePart
			local a0 = Instance.new("Attachment")
			a0.Name = "RagdollA0_" .. d.Name
			a0.CFrame = d.C0
			a0.Parent = p0
			local a1 = Instance.new("Attachment")
			a1.Name = "RagdollA1_" .. d.Name
			a1.CFrame = d.C1
			a1.Parent = p1
			table.insert(l.Made, a0)
			table.insert(l.Made, a1)
			socket(d.Name, a0, a1, p1)
			d.Enabled = false
			table.insert(l.Joints, d)
		elseif d:IsA("AnimationConstraint") and not ROOT_JOINTS[d.Name] and d.Enabled then
			-- (an avatar with the newer joints already has a ball socket beside each, with its own limits: it takes
			-- over as the joint is switched off, made a little stiffer; else one is made)
			local own = d.Parent and d.Parent:FindFirstChild(d.Name .. "BallSocket")
			local a0, a1 = d.Attachment0, d.Attachment1
			if own and own:IsA("BallSocketConstraint") then
				l.Friction[own] = own.MaxFrictionTorque
				own.MaxFrictionTorque = math.max(own.MaxFrictionTorque, friction)
				own.Enabled = true
				d.Enabled = false
				table.insert(l.Joints, d)
			elseif a0 and a1 and a1.Parent then
				socket(d.Name, a0, a1, a1.Parent)
				d.Enabled = false
				table.insert(l.Joints, d)
			end
		end
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			local accessory = d:FindFirstAncestorOfClass("Accessory") ~= nil
			l.Collide[d] = d.CanCollide
			-- (the root part rides along with the lower body; hats and hair stay out of it)
			d.CanCollide = not accessory and d ~= root
			d.CollisionGroup = "Ragdoll"
		end
	end
	looseOf[r.Player] = l
	character:SetAttribute("Ragdoll", now())
	pcall(function()
		root:SetNetworkOwner(r.Player)
	end)
	if seconds then
		local token = l.Token
		task.delay(seconds, function()
			local still = looseOf[r.Player]
			if still and still.Token == token then
				unragdoll(r.Player)
			end
		end)
	end
	return true
end

-- Off the fish's back as a ragdoll, mid-outcome (Config.Fail's Loose): the weld goes, the fish stays ours for the rest
-- of the outcome (its owner's machine still moves it), and every client is told (Fx "Ragdoll": player, fish, kind)
local function letLoose(r: Rider, kind: string, seconds: number?)
	if r.Weld then
		r.Weld:Destroy()
		r.Weld = nil
	end
	local fish = r.Fish
	if fish then
		-- (the fish was ours through the rider's weld: still ours to move for the rest of the outcome, or the server
		-- takes it back and it jumps between the two)
		pcall(function()
			fish.Root:SetNetworkOwner(r.Player)
		end)
	end
	if ragdoll(r, seconds) then
		Net.Fx:FireAllClients("Ragdoll", r.Player, if fish then fish.Model else nil, kind)
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Mounting, going home and failing: getting on a fish, back to the dock, drowning and being thrown off

local function mount(r: Rider, w: Wild, landing: boolean): boolean
	local root, humanoid = parts(r.Player)
	if not root or not humanoid or not FishService.isFree(w, r.Player) then
		return false
	end
	humanoid.PlatformStand = true
	-- The rider's own machine has already put them on the saddle (the pull-in, or the sandbox's seat), and it owns the
	-- character, so the server leaves the character where it is: moving it here put it on the saddle as the SERVER
	-- sees the fish, some 5 to 12 studs ahead of where the rider's machine sees it. Only a rider who is somehow far
	-- from the saddle is moved, so the weld can't drag the fish to them.
	-- (allowing for the delay, Net.Lag: on a fast fish the rider is seen well behind the saddle, and moving them put
	-- them where the server has the fish, ahead of where their own machine has it)
	if (nearness(r, w, root)) > 30 + w.Body.Z / 2 then
		root.CFrame = w.Saddle.WorldCFrame
	end
	local weld = Instance.new("Weld")
	weld.Name = "RideWeld"
	weld.Part0 = w.Root
	weld.Part1 = root
	weld.C0 = w.Saddle.CFrame
	weld.Parent = w.Root
	FishService.setRider(w, r.Player)
	r.Fish = w
	r.Weld = weld
	r.CheckAt = os.clock() + 1
	r.CheckFrom = w.Root.Position
	-- (a wild fish is ours to move, so the speed it has now is true)
	r.RideSpeed = w.Root.AssemblyLinearVelocity.Magnitude
	r.MountSpeed = r.RideSpeed
	r.RideFrom = w.Root.Position
	r.Nosed = false
	-- (a new fish: no burst carried over, and its first bite is a first bite)
	r.BoostUntil = 0
	r.BoostMost = 1
	r.Frenzy = 0
	r.AteAt = -math.huge
	-- Too strong for us? Decided here, at the mount, by what this fish needs (task e1: never by the land it is in): a
	-- landing is never refused, the meter just empties at once (Oxygen.StrainTime).
	r.Strained = Config.strained(needOf(w), r.Max) and not sandbox("EndlessAir", r)
	-- red fish in a row (the user, 2026-11-22, Oxygen.RedShrink): each one after the first empties the meter sooner;
	-- a fish we can hold starts the count again. The client is told the seconds (StrainSeconds) before Strained.
	r.RedRun = if r.Strained then r.RedRun + 1 else 0
	local strainSeconds = Config.strainSeconds(r.RedRun)
	r.Player:SetAttribute("StrainSeconds", if r.Strained then strainSeconds else nil)
	r.Player:SetAttribute("Strained", if r.Strained then true else nil)
	r.Tame = if r.Tamed[w] then 1 else 0
	if landing then
		-- the refill is for reaching another fish: not for hopping off and back onto the same one, nor for a landing
		-- sooner than a flight can be
		local flown = os.clock() - r.JumpAt >= Config.Jump.MinFlight
		if w ~= r.JumpFrom and flown then
			r.Oxygen = math.min(r.Max, r.Oxygen + r.Max * Config.Oxygen.Refill)
		end
		r.JumpFrom = nil
		-- (the wait between fish is the client's, counted from its touch: Jump.Cooldown. We mount a moment after
		-- that touch and hear the next hop a moment after it was pressed, so half of it here never refuses an honest
		-- hop and still keeps one message from landing and leaving at once)
		-- (a fish too strong for us is no stepping stone: the old wait, longer than the meter takes to empty)
		r.JumpReadyAt = os.clock() + (if r.Strained then Config.Jump.StrainLock else Config.Jump.Cooldown / 2)
	end
	-- the break-off (Hugo, 2026-11-18, task o1: "when hopping on a dino that doesnt have the right amount of stamina
	-- make sure it just instantly breaks off 2/3rds of the stamina with the same fade out animation"): on a fish too
	-- strong, Oxygen.BreakOff of what we land with goes at once, told as one big tick ("Break"), and the rest empties
	-- in StrainTime, in ticks (Config.strainTicks)
	local o = Config.Oxygen
	if r.Strained then
		if o.BreakOff > 0 and r.Oxygen > 0 then
			local lost = r.Oxygen * math.clamp(o.BreakOff, 0, 1)
			r.Oxygen -= lost
			r.StrainPiece, r.StrainEvery = Config.strainTicks(r.Max, r.Oxygen, strainSeconds)
			-- (the gap told is the one to the first strain tick, so the struggle locks to it: until task r1 it was
			-- StrainTime, and the struggle ran out of step with the strain's ticks)
			Net.Ride:FireClient(r.Player, "OxygenTick", lost, r.Oxygen, r.StrainEvery, "Break")
		end
		r.StrainPiece, r.StrainEvery = Config.strainTicks(r.Max, r.Oxygen, strainSeconds)
		-- (the first of the rest a whole gap after the break-off)
		r.TickAt = os.clock() + r.StrainEvery
	end
	if landing then
		sendOxygen(r, true)
		r.Landings += 1
		Net.Fx:FireAllClients("Land", r.Player, w.Model, r.Landings)
	end
	setState(r, "Riding")
	-- (a fish too strong is angry from the touch: marked before the client is told it is mounted)
	setAngry(r, if isAngry(r, w) then w else nil)
	Net.Ride:FireClient(r.Player, "Mounted", w.Model, landing)
	return true
end

local function toDock(r: Rider)
	if r.Fish then
		dismount(r, "Dock")
	end
	-- (a ragdoll gets its joints back before the move home)
	unragdoll(r.Player)
	r.Token += 1
	local root, humanoid = parts(r.Player)
	if root and humanoid then
		humanoid.PlatformStand = false
		local character = r.Player.Character :: Model
		-- (with fish in hand and a tank of their own: in front of the tank, AquariumService)
		local home = if RideService.Home then RideService.Home(r.Player) else nil
		if home then
			character:PivotTo(home + Vector3.new(0, 3, 0))
		elseif dockSpawn then
			character:PivotTo(dockSpawn.CFrame + Vector3.new(0, 4, 0))
		else
			-- (the state first: loading a character yields, and a rider still Free or Drowning was sent to the dock
			-- again every frame until it had loaded)
			setState(r, "Dock")
			local player: any = r.Player
			if not pcall(function()
				player:LoadCharacterAsync()
			end) then
				player:LoadCharacter()
			end
		end
		root.AssemblyLinearVelocity = Vector3.zero
	end
	unbank(r)
	r.Oxygen = r.Max
	sendOxygen(r, true)
	setState(r, "Dock")
	-- the dive's catch comes home (death or not, as the reference's). With a tank of their own the player still
	-- carries it, until they put it in (AquariumService: RideService.takeCarried). With none it is counted here and the
	-- hands are empty again.
	if not (RideService.Keeps and RideService.Keeps(r.Player)) then
		if #r.Caught > 0 then
			r.Owned += #r.Caught
		end
		table.clear(r.Caught)
		table.clear(r.Carried)
	end
	table.clear(r.Tamed)
	sendCaught(r)
	Net.Ride:FireClient(r.Player, "Respawned")
end

-- A death: no input for its length, then the dock. Clients play it from DeathAt (everyone sees it).
local function die(r: Rider, state: string, length: number, thrown: boolean, quick: boolean?)
	r.Token += 1
	local token = r.Token
	-- the timing first, so clients have it when the State changes
	r.Player:SetAttribute("DeathAt", now())
	r.Player:SetAttribute("DeathThrown", thrown)
	r.Player:SetAttribute("DeathQuick", quick == true)
	setState(r, state)
	task.delay(length, function()
		if r.Token == token and r.State == state and riders[r.Player] == r then
			toDock(r)
		end
	end)
end

-- No failing (Config.Death.On 0, or the sandbox's NoFail): nothing ends the dive
local function noFail(r: Rider): boolean
	return Config.Death.On == 0 or sandbox("NoFail", r)
end

-- Thrown off the fish into the drown (everyone's clients animate the buck and the throw)
local function throwOff(r: Rider)
	local w = r.Fish
	if not w then
		return
	end
	local model = w.Model
	dismount(r, "OutOfOxygen", true)
	Net.Fx:FireAllClients("ThrowOff", r.Player, model)
end

-- Out of Oxygen: on a fish it does what that fish does (Config.Fail: Config.failOf) and then, for most, throws you off;
-- you drown: the fail (Config.Death), which fades out and ends at the dock with the dive's catch kept (toDock). Taken
-- (eaten, dragged down, pinned) is the fail at once, without the drown. `forced`: the admin's fail, whatever the
-- no-fail switches say. `kind`: an outcome to play instead of the fish's own (the admin's, for trying them).
local function drown(r: Rider, forced: boolean?, kind: string?)
	local d = Config.Death
	local w = r.Fish
	local soft = noFail(r) and not forced
	if not w then
		if soft then
			r.Oxygen = r.Max
			sendOxygen(r, true)
			setState(r, "Free")
			Net.Ride:FireClient(r.Player, "Dismounted", "Lost")
		else
			die(r, "Drowning", d.DrownTime - d.Throw, false)
		end
		return
	end
	local f = Config.Fail
	-- (Studio only, for capturing it frame by frame: workspace's FailSlow makes every wait here that many times longer)
	local slowed = if RunService:IsStudio() then workspace:GetAttribute("FailSlow") else nil
	local slow = if type(slowed) == "number" and slowed > 1 then slowed else 1
	local name = if kind and f.Outcomes[kind]
		then kind
		else Config.failOf(w.Type, RideStyles.nameOf(w.Type.Id), w.Body.Z)
	local outcome = f.Outcomes[name]
	local rag = f.Ragdoll
	local ragdolls = rag.On ~= 0 and not soft
	-- the end of it: off the fish into the drown, or (taken) at the dock; with no failing, left floating with a
	-- whole meter, to go on
	local function finish()
		if soft then
			if r.Fish then
				throwOff(r)
			end
			r.Oxygen = r.Max
			sendOxygen(r, true)
			setState(r, "Free")
			Net.Ride:FireClient(r.Player, "Dismounted", "Lost")
		elseif outcome.End == "Taken" then
			-- (nothing: the fish keeps us, out of sight, until the dock, and toDock lets it go)
			return
		else
			-- thrown: still flying loose (the ragdoll, from the outcome's Loose, or from now for the plain throw), the
			-- drown's struggle begins when it has had its Ragdoll.Time (DeathLoose: the seconds of it left)
			local left = 0
			if ragdolls then
				if r.Weld then
					letLoose(r, name, rag.Time * slow)
					left = rag.Time
				else
					left = rag.Time -- (let loose at Loose for Time - Loose + Ragdoll.Time)
				end
			end
			throwOff(r)
			r.Player:SetAttribute("DeathLoose", if ragdolls then left else nil)
			die(r, "Drowning", (if ragdolls then d.DrownTime - d.Throw + left else d.DrownTime) * slow, true)
		end
	end
	if outcome.Time <= 0 then
		finish()
		return
	end
	-- held on the fish for the outcome: its kind and start first, so clients have them when the State changes
	r.Player:SetAttribute("FailKind", name)
	r.Player:SetAttribute("FailAt", now())
	Net.Fx:FireAllClients("Fail", r.Player, w.Model, name)
	if outcome.End == "Taken" and not soft then
		-- the fail itself: the outcome, the fade, the black, then the dock (die's own timer)
		die(r, "Failing", (outcome.Time + f.TakenFade + f.TakenTail) * slow, false)
	else
		r.Token += 1
		setState(r, "Failing")
	end
	local token = r.Token
	-- off its back, loose, partway through (a taken one stays loose until the dock; a thrown one flies on into the drown)
	if ragdolls and outcome.Loose < outcome.Time then
		task.delay(outcome.Loose * slow, function()
			if r.Token == token and r.State == "Failing" and riders[r.Player] == r then
				letLoose(
					r,
					name,
					if outcome.End == "Taken" then nil else (outcome.Time - outcome.Loose + rag.Time) * slow
				)
			end
		end)
	end
	if outcome.End == "Taken" and not soft then
		return
	end
	task.delay(outcome.Time * slow, function()
		if r.Token == token and r.State == "Failing" and riders[r.Player] == r then
			finish()
		end
	end)
end

----------------------------------------------------------------------------------------------------------------------
-- The hop: jumping off, missing, grabbing a fish in the air and landing on it

-- The jump: off the fish (or from floating) into the hop. Never refused for Oxygen, and it costs none: however little
-- is left you can still go fish to fish (Hugo, 2026-11-11).
local function jump(r: Rider)
	if r.State ~= "Riding" and r.State ~= "Free" then
		return deny(r, "Jump", "State")
	end
	if os.clock() < r.JumpReadyAt then
		return deny(r, "Jump", "Cooldown")
	end
	local first = firstFish(r)
	if first and r.State == "Riding" then
		return deny(r, "Jump", "First") -- (the client has no hop then: LessonController)
	end
	r.JumpFrom = r.Fish
	r.DiveHop = r.Fish == nil and (not r.Rode or first)
	-- The hop's numbers, as the client flies them (Config.hopFrom): off a Leaper the glide and the window are longer,
	-- and both go by the speed the fish had as we left it, as the server sees it (airtime by speed). The hook's reach
	-- is counted from these and our own clock (grab), never from what the client says: so the speed is held to what
	-- this fish may do (its surge or a burst we gave it, with the speed check's slack).
	local w = r.Fish
	if w then
		local most = (Config.surgeOf(w.Type))
		if os.clock() < r.BoostUntil then
			most *= r.BoostMost
		end
		-- (the speed is r.RideSpeed, from where we saw the fish go: by the time the hop's word is here the rider's
		-- machine is already flying, and the velocity it reports for the fish it left is the hop's, not the fish's)
		local had = math.min(r.RideSpeed, FishService.ridden(w) * most * Config.Ride.SpeedSlack)
		r.JumpLaunch, r.JumpExtra = Config.hopFrom(had, w.Type, FishService.ridden(w))
	else
		r.JumpLaunch, r.JumpExtra = Config.hopFrom(nil, nil, nil)
	end
	if r.Fish then
		dismount(r, "Jump", true)
	end
	r.Token += 1
	r.JumpAt = os.clock()
	setState(r, "Jumping")
end

-- A flight that came down on nothing: sunk, and a short drown
local function miss(r: Rider)
	-- (the dive-in, Config.Dive.ForgiveMiss: the hop into the water, and any other from floating before the first
	-- ride of the dive, costs nothing when it lands on nothing)
	local forgiven = r.DiveHop and Config.Dive.ForgiveMiss > 0
	r.DiveHop = false
	if noFail(r) or forgiven then
		-- the sandbox: left floating, to jump again
		setState(r, "Free")
		Net.Ride:FireClient(r.Player, "Dismounted", "Lost")
		return
	end
	die(r, "Drowning", Config.Death.MissTime, false, true)
end

-- The grab the client asks for: the fish must be free and within the hard max range of the player (plus slack for lag).
-- Granted, it is kept for them until the landing. Refused, the hop goes on: the window is still running.
local function grab(r: Rider, target: any)
	if r.State ~= "Jumping" then
		return deny(r, "Grab", "State", target)
	end
	local j = Config.Jump
	local root = parts(r.Player)
	local w = FishService.get(if typeof(target) == "Instance" then target else nil)
	if not root or not w or not FishService.isFree(w, r.Player) then
		return deny(r, "Grab", "Target", target)
	end
	-- (a player's first fish is one they can hold: RideService.FirstFish)
	if firstFish(r) and not Config.firstFish(w.Type, w.SizeTier, w.Variant, r.Max) then
		return deny(r, "Grab", "First", target)
	end
	local elapsed = os.clock() - r.JumpAt
	if r.Grab or elapsed > j.Window + r.JumpExtra + j.Slack then
		return deny(r, "Grab", "Window", target)
	end
	-- The hook's reach is by the hop's speed across the water (Config.reachOf): longest as the hop leaves, shrinking as it
	-- slows to its stop. The speed is ours: the hop's own curve (Config.hopSpeed) from the speed we saw the fish leave at,
	-- at our own clock, read Net.ReachLag earlier (the grab's word arrives late and the reach is shrinking). And a
	-- little for lag (we see the player and the fish a moment apart, both moving): without it a grab near the edge
	-- of the range is refused though the client was inside it. Landing slack never widens this.
	local speed = Config.hopSpeed(math.max(0, elapsed - Config.Net.ReachLag), r.JumpLaunch, r.JumpExtra)
	local reach = Config.reachOf(speed, r.JumpLaunch) * Config.Net.RangeSlack
	if r.DiveHop then
		-- (the dive's own hop reaches further: Config.Dive.Reach)
		reach = math.max(reach, Config.Dive.Reach * Config.Net.RangeSlack)
	end
	-- (and straight in front further early in the hop, Jump.AheadReach: the client says which way is in front, by the
	-- camera, which we can't see, so we allow it all round, from the same moment as the speed)
	reach *= Config.aheadOf(math.max(0, elapsed - Config.Net.ReachLag))
	-- (a moving fish is further on for us than for the rider's machine, by its speed times the moment between the two:
	-- Jump.LandLag, as at the landing. Measured, task b3: a 150 fish locked 81 studs off was 115 off here, and refused)
	reach += w.Speed * math.max(Config.Jump.LandLag, 0)
	-- (allowing for the delay, Net.Lag: a fish swimming away fast was refused here though the client had it in reach;
	-- and to the fish's whole body, as the client's lock measures it. The two PCs fixed the same refusals apart, this
	-- rewind on 2026-11-18 and LandLag above on 2026-11-22; both are kept, so the allowance is generous. To choose one:
	-- docs/Handoff.md, 2026-11-22)
	local near, plain = reachNearness(r, w, root)
	judged(r, "grab", w, near, plain, reach, (w.Root.Position - root.Position).Magnitude)
	if not (near <= reach) then
		return deny(r, "Grab", "Range", target)
	end
	-- Match the client's obstruction rule. Aim is local camera intent; range and solids are authoritative.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local excluded: { Instance } = { w.Model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local surface = blockout and blockout:FindFirstChild("Surface")
	if surface then
		table.insert(excluded, surface)
	end
	params.FilterDescendantsInstances = excluded
	if workspace:Raycast(root.Position, w.Root.Position - root.Position, params) then
		return deny(r, "Grab", "Blocked", target)
	end
	if not FishService.reserve(w, r.Player) then
		return deny(r, "Grab", "Target", target)
	end
	r.Grab = w
	r.GrabAt = os.clock()
end

-- The landing the client asks for, at the end of its pull-in: on the fish it was granted, free still, and the player
-- at it (plus slack for lag)
local function landing(r: Rider, target: any)
	if r.State ~= "Jumping" then
		return deny(r, "Land", "State")
	end
	local j = Config.Jump
	if r.Grab and os.clock() > r.GrabAt + j.ReelMax + j.AckTime + j.Slack then
		return miss(r)
	end
	local root = parts(r.Player)
	local w = FishService.get(if typeof(target) == "Instance" then target else nil)
	if not root or not w or w ~= r.Grab or not FishService.isFree(w, r.Player) then
		-- Losing a target at arrival is the same as a refused grab: release it and resume the original window.
		if r.Grab then
			FishService.unreserve(r.Grab, r.Player)
			r.Grab = nil
		end
		return deny(r, "Grab", "Target", target)
	end
	-- the server sees the player a moment late, and a pull-in arrives fast (and the delay, Net.Lag: held on the saddle
	-- of a fast fish as their machine saw it, the rider was further behind the fish than this the whole half second
	-- of LandWait, and fell off the saddle when it ran out)
	-- (and it sees them BEHIND a moving fish by the fish's speed times that moment: their machine sits them on the
	-- fish where it sees it, which is where the fish was a moment ago, and their place takes another moment to reach
	-- us. Measured in Studio, task b3: 0.2 to 0.3 s in all, so a rider held on the saddle of a fish at 220 studs a
	-- second was seen 55 to 65 studs behind it for as long as they sat there, never inside the 45 allowed, and the
	-- landing was refused after LandWait: "it kicks you off". Jump.LandLag allows for it, by the fish's own speed
	-- as we have it. The fish was granted inside the hook's reach already, so this lets no one land from further.)
	-- (Both fixes are kept, as at the grab: the nearness rewind and LandLag.)
	local reach = w.Body.Z / 2 + j.LandSlack * 2 + w.Speed * math.max(j.LandLag, 0)
	local near, plain = nearness(r, w, root)
	judged(r, "landing", w, near, plain, reach)
	if not (near <= reach) then
		-- Not seen at the fish yet. The rider's machine is holding them on the saddle and waiting for our word, and we
		-- see them a moment late, most of all after a fast pull-in (its last tenth of a second covers most of the
		-- distance): so the landing is given Jump.LandWait to be seen arriving before it is refused. Refusing it at
		-- once sent the rider back into the hop from the saddle, where the hands-off pull-in took the next fish it
		-- saw: "landed on a fish, instantly hooked onto another" (Hugo, 2026-11-12).
		local token = r.Token
		local waitUntil = os.clock() + j.LandWait
		task.spawn(function()
			while os.clock() < waitUntil do
				task.wait()
				if riders[r.Player] ~= r or r.Token ~= token or r.State ~= "Jumping" or r.Grab ~= w then
					return
				end
				local here = parts(r.Player)
				if here and (nearness(r, w, here)) <= reach then
					if not mount(r, w, true) then
						FishService.unreserve(w, r.Player)
						r.Grab = nil
						deny(r, "Grab", "Target", target)
					end
					return
				end
			end
			if riders[r.Player] ~= r or r.Token ~= token or r.State ~= "Jumping" or r.Grab ~= w then
				return
			end
			-- (a refused grab, not a miss: the hop goes on with what is left of its window. It was a drown, "MISSED
			-- THE FISH" while sitting on the fish, which a slow connection on a fast fish could reach)
			FishService.unreserve(w, r.Player)
			r.Grab = nil
			deny(r, "Grab", "Range", target)
		end)
		return
	end
	if not mount(r, w, true) then
		FishService.unreserve(w, r.Player)
		r.Grab = nil
		deny(r, "Grab", "Target", target)
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Oxygen, eating and crashes: the drain, the red part, archetype rewards, bites and hitting the map

local function drain(r: Rider, amount: number)
	if sandbox("EndlessAir", r) then
		r.Oxygen = r.Max
		return
	end
	r.Oxygen = math.max(0, r.Oxygen - amount)
end

-- The drain in ticks (Oxygen.Ticks): nothing between ticks, then one piece at once, told to the rider's client
-- (Ride "OxygenTick", lost, oxygen now, seconds to the next, "Tick") for the HUD to show it go. Every piece is
-- 1 / Ticks of the max (Config.tickOf: `rate` only sets the gap), or on a fish too strong the strain's own (`piece`,
-- `every`: Config.strainTicks). Oxygen.Tick 0: smooth.
-- The red part's gap (task r1): while the fish under us is angry, a gap is at least Oxygen.RedTick, then lengthened to a
-- whole number of the struggle's thrashes if that is only a little longer (AngryStyles.snapGap: never shorter). A gap
-- made longer here takes a bigger piece, the drain a second x the gap (r.TickPiece, for the tick at its end), so the
-- seconds on the fish hold as they do under Oxygen.Tick. The client locks the struggle to the ticks the rest of the way.
local function redGap(r: Rider, rate: number, gap: number): number
	r.TickPiece = 0
	local w = r.Fish
	if not w or r.State ~= "Riding" or not isAngry(r, w) then
		return gap
	end
	local red = math.max(gap, Config.Oxygen.RedTick)
	red = AngryStyles.snapGap(AngryStyles.of(w.Type), red, Config.Oxygen.Tick)
	if red > gap then
		r.TickPiece = rate * red
		return red
	end
	return gap
end

-- The red part in even ticks (Oxygen.RedTime, task o1 of 2026-11-19): `redLine` (Oxygen) and `redSeconds` given, the
-- tick that takes the meter under the line starts it: what is left goes in Config.redTicks, and the gap told with
-- that tick is already the red one (the struggle locks to it). The caller then passes RedPiece and RedEvery.
local function startRed(r: Rider, redSeconds: number)
	r.RedPiece, r.RedEvery = Config.redTicks(r.Oxygen, redSeconds)
end

local function tickDrain(
	r: Rider,
	rate: number,
	dt: number,
	piece: number?,
	every: number?,
	redLine: number?,
	redSeconds: number?
)
	if Config.Oxygen.Tick <= 0 then
		drain(r, rate * dt)
		return
	end
	local size, gap = Config.tickOf(r.Max, rate)
	if piece and every then
		size, gap = piece, every
	end
	local t = os.clock()
	if r.TickAt < 0 then
		-- (a new stretch: its first tick a whole gap away)
		r.TickAt = t + (if piece then gap else redGap(r, rate, gap))
		return
	end
	if t < r.TickAt then
		return
	end
	-- (the gap just waited was a red one: its piece is what the drain takes in it, redGap)
	if not piece and r.TickPiece > 0 then
		size = r.TickPiece
	end
	-- (a crumb left by rounding is taken with this piece: a fish too strong's last tick empties the meter, task r1)
	if r.Oxygen - size < r.Max * 1e-6 then
		size = r.Oxygen
	end
	local before = r.Oxygen
	drain(r, size)
	-- (the next gap: in the red part (angry after this tick) calmer, redGap. Not on a fish too strong: its own gap is
	-- at least RedTick already, Config.strainTicks, and its StrainTime holds.)
	if piece then
		r.TickPiece = 0
	elseif redLine and redSeconds and r.Oxygen > 0 and r.Oxygen <= redLine then
		-- (this tick crossed the red line: the red part's even ticks from here)
		r.TickPiece = 0
		startRed(r, redSeconds)
		gap = r.RedEvery
	else
		gap = redGap(r, rate, gap)
	end
	-- (one tick a frame at most; a long hitch doesn't take several at once)
	r.TickAt = math.max(r.TickAt + gap, t + gap * 0.5)
	local lost = before - r.Oxygen
	if lost > 0 then
		sendOxygen(r, true)
		Net.Ride:FireClient(r.Player, "OxygenTick", lost, r.Oxygen, gap, "Tick")
	end
end

-- The fish ran into something: Oxygen is taken here, and the rider's client is told to slow (`slow`: the share of its
-- speed it keeps). Never the last of the Oxygen: a crash can't be what drowns you.
local function bump(r: Rider, cost: number, slow: number)
	local c = Config.Crash
	r.CrashReadyAt = os.clock() + c.Cooldown
	if not sandbox("EndlessAir", r) then
		r.Oxygen = math.max(math.min(r.Oxygen, c.Floor), r.Oxygen - r.Max * cost)
	end
	sendOxygen(r, true)
	Net.Ride:FireClient(r.Player, "Crashed", slow)
end

-- An archetype's reward (a Predator's bite, a Breaker's prop): a burst of speed for `time` seconds, which the rider's
-- client plays and the speed check here allows, and `oxygen` of the max meter back. `kind` is "Eat" or "Smash";
-- `at` is where it happened, `count` the Frenzy's stacks or the boxes knocked loose. Everyone is told, for the
-- bubbles and the sound (Fx), and the fish's own attribute counts up, for the animations to come.
local function reward(
	r: Rider,
	w: Wild,
	kind: string,
	burst: number,
	time: number,
	oxygen: number,
	at: Vector3,
	count: number
)
	r.BoostUntil = os.clock() + time
	r.BoostMost = math.max(burst, 1)
	if not sandbox("EndlessAir", r) then
		r.Oxygen = math.min(r.Max, r.Oxygen + r.Max * oxygen)
	end
	sendOxygen(r, true)
	local attribute = if kind == "Eat" then "Bite" else "Smash"
	local before = w.Model:GetAttribute(attribute)
	w.Model:SetAttribute(attribute, (if type(before) == "number" then before else 0) + 1)
	Net.Ride:FireClient(r.Player, "Boost", kind, burst, time, oxygen, count)
	Net.Fx:FireAllClients(kind, r.Player, w.Model, at, count)
end

-- A Predator eats (Config.Archetype.Predator, Frenzy): while we ride it, a wild fish no longer than Prey of its own
-- length that its nose reaches is gone, and we get a burst of speed and some Oxygen. Never a fish with a rider or
-- one kept for a player's hop (FishService.prey). A Frenzy's bites chain: each inside Window of the last is a stack.
local function checkEat(r: Rider, w: Wild)
	local t = os.clock()
	if t < r.EatCheckAt then
		return
	end
	r.EatCheckAt = t + Config.Crash.Every
	if r.Strained or not Config.hasArchetype(w.Type, "Predator") then
		return
	end
	local p = Config.Archetype.Predator
	local f = Config.Archetype.Frenzy
	local frenzy = Config.hasArchetype(w.Type, "Frenzy")
	if frenzy and r.Frenzy > 0 and t - r.AteAt > f.Window then
		-- the chain is broken: back to one
		r.Frenzy = 0
		w.Model:SetAttribute("Frenzy", nil)
	end
	if t < r.EatReadyAt then
		return
	end
	local root = w.Root
	local speed = root.AssemblyLinearVelocity.Magnitude
	local nose = root.Position + root.CFrame.LookVector * (w.Body.Z / 2)
	-- (as far as its nose and half its width, and as far as it swims between two looks)
	local reach = math.max(w.Body.X, w.Body.Y) / 2 + p.Reach + speed * Config.Crash.Every / 2
	local prey = FishService.prey(w, nose, reach, w.Body.Z * p.Prey)
	if not prey then
		return
	end
	local at = prey.Root.Position
	FishService.eat(prey)
	local stacks = 0
	if frenzy then
		stacks = if t - r.AteAt <= f.Window then math.min(r.Frenzy + 1, math.floor(f.Stacks)) else 0
		r.Frenzy = stacks
		w.Model:SetAttribute("Frenzy", if stacks > 0 then stacks else nil)
	end
	r.AteAt = t
	r.EatReadyAt = t + (if frenzy then f.Cooldown else p.Cooldown)
	reward(r, w, "Eat", p.Burst + stacks * f.BurstPer, p.BurstTime + stacks * f.TimePer, p.Oxygen, at, stacks)
end

local crashParams = RaycastParams.new()
crashParams.FilterType = Enum.RaycastFilterType.Exclude
crashParams.RespectCanCollide = true
crashParams.IgnoreWater = true

-- What is in the ridden fish's way (Config.Crash, Config.Props). The client steers the fish and keeps it out of solid
-- things itself; what running into one costs is decided here, from where the server sees the fish.
-- Whether a part is one of the map's own boundary boxes: a wall of the lane, the ground on top of it or the unseen
-- barrier behind (the loader's Lane/Walls, Lane/Ground and Lane/Barrier). Not the seabed, and not a prop.
local function boundary(part: Instance): boolean
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local laneFolder = blockout and blockout:FindFirstChild("Lane")
	if not laneFolder then
		return false
	end
	for _, name in { "Walls", "Ground", "Barrier" } do
		local folder = laneFolder:FindFirstChild(name)
		if folder and part:IsDescendantOf(folder) then
			return true
		end
	end
	return false
end

local function checkCrash(r: Rider, w: Wild)
	local t = os.clock()
	if t < r.CrashCheckAt then
		return
	end
	local c = Config.Crash
	r.CrashCheckAt = t + c.Every
	local root = w.Root
	local look = root.CFrame.LookVector
	local velocity = root.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	local half = w.Body.Z / 2
	if speed >= c.MinSpeed then
		r.FastAt = t
	end
	-- a prop (Config.Props; Hugo, 2026-11-18): by size (Config.propBreak, prop by prop in PropService.hit). Small
	-- things break for any fish for nothing; a bigger prop breaks for a fish bigger than it, its boxes go and the fish
	-- swims on through (reaching as far as it swims between two looks), slowed the more the nearer the two sizes are;
	-- a fish no bigger goes straight through (its rider's screen stuns it first: PropController). Props are left out
	-- of the look below for every fish.
	-- A Breaker (Config.Archetype.Breaker) breaks every prop, knocks a wider hole, loses nothing by it, and is paid:
	-- Oxygen for each prop broken, and a push at most once every Breaker.Cooldown.
	local breaker = Config.hasArchetype(w.Type, "Breaker")
	local b = Config.Archetype.Breaker
	if speed >= c.MinSpeed then
		local reach = math.max(w.Body.X, w.Body.Y) / 2
			+ Config.Props.Reach
			+ (if breaker then b.Reach else 0)
			+ speed * c.Every / 2
		local nose = root.Position + look * half
		local loose, broke = PropService.hit(nose, velocity, reach, w.Type, Config.boxSize(w.Body))
		if loose > 0 then
			if breaker then
				local oxygen = b.Oxygen * broke.Big + b.SmallOxygen * broke.Small
				if t >= r.BreakReadyAt then
					r.BreakReadyAt = t + b.Cooldown
					reward(r, w, "Smash", b.Burst, b.BurstTime, oxygen, nose, loose)
				elseif oxygen > 0 and not sandbox("EndlessAir", r) then
					r.Oxygen = math.min(r.Max, r.Oxygen + r.Max * oxygen)
					sendOxygen(r, true)
				end
			elseif broke.Keep < 1 and t >= r.CrashReadyAt then
				-- (the Oxygen it costs shrinks with the slow-down: all of Props.Cost at Props.Slow, none at no slow)
				local p = Config.Props
				local share = (1 - broke.Keep) / math.max(1 - p.Slow, 0.01)
				bump(r, p.Cost * math.clamp(share, 0, 1), broke.Keep)
			end
		end
	end
	-- anything else solid, square enough on: as far ahead as the client's own steering stops the fish (Lib/Course
	-- looks 0.12 s ahead of the nose), and a little more. The client has slowed the fish by the time we see it there,
	-- so what counts is that it was going fast a moment ago.
	local skip: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local surface = blockout and blockout:FindFirstChild("Surface")
	if surface then
		table.insert(skip, surface)
	end
	local props = PropService.folder()
	if props then
		-- (no fish is stopped by a prop: one that breaks them was looked at above, the rest go through)
		table.insert(skip, props)
	end
	crashParams.FilterDescendantsInstances = skip
	local ahead = half + 1 + FishService.ridden(w) * Config.Ride.Surge * 0.12 + c.Reach
	local hit = workspace:Raycast(root.Position, look * ahead, crashParams)
	local nosed = hit ~= nil and hit.Normal.Y < 0.5 and -look:Dot(hit.Normal) >= c.HeadOn
	-- The lane's own edge is a wall ride (Config.Wall: the rider's machine turns the fish along it), not a crash:
	-- nothing is taken and the fish isn't slowed here, unless Wall.EdgeCost says so. What stands IN the lane still is.
	-- The edge is the map's own boundary boxes (Lane/Walls, Lane/Ground, Lane/Barrier: since grey-box 14 the canyon's
	-- walls wave in and out, in places a hundred studs inside the lane's surveyed width), or anything within EdgeBand
	-- of that width.
	local wall = Config.Wall
	if
		nosed
		and hit
		and wall.On ~= 0
		and (boundary(hit.Instance) or FishService.inside(hit.Position) <= wall.EdgeBand)
	then
		if not r.Nosed and wall.EdgeCost > 0 and t - r.FastAt <= 0.5 and t >= r.CrashReadyAt then
			bump(r, wall.EdgeCost, 1)
		end
	elseif nosed and not r.Nosed and t - r.FastAt <= 0.5 and t >= r.CrashReadyAt then
		-- (a Breaker loses only Breaker.Crash of what a wall costs: of the Oxygen, and of the speed it drops by)
		local share = if breaker then math.clamp(b.Crash, 0, 1) else 1
		bump(r, c.Cost * share, 1 - (1 - c.Slow) * share)
	end
	r.Nosed = nosed
end

----------------------------------------------------------------------------------------------------------------------
-- Every frame: the speed check, taming, and each rider's tick by state

-- A light check on the client driving its fish: flag one moving far faster than its surge speed
local function checkSpeed(r: Rider, w: Wild)
	local t = os.clock()
	if t < r.CheckAt then
		return
	end
	local from = r.CheckFrom
	local position = w.Root.Position
	if from then
		-- (this fish's own speed: its species, rarity and variant; and an angry fish, once its slow-down is in, is
		-- held to the most its style gives: a Surge's top, or no more than its speed)
		local most = (Config.surgeOf(w.Type)) -- (Ride.Surge; a Fast fish's bigger one)
		if r.AngryFish == w and t - r.AngryAt >= 1.1 + Config.Angry.EaseIn then
			most = AngryStyles.most(AngryStyles.of(w.Type))
		end
		-- (a burst we gave it, an eat's or a smash's, and the second after, which this look still covers)
		if t < r.BoostUntil + 1 then
			most *= r.BoostMost
		end
		local allowed = FishService.ridden(w) * most * Config.Ride.SpeedSlack + 10
		-- (the first second after the mount: a wild fish caught going fast still has that speed while the rider's machine
		-- eases it to its ridden pace; landing on one going 115 studs a second was flagged, 2026-11-18)
		allowed = math.max(allowed, r.MountSpeed * Config.Ride.SpeedSlack + 10)
		r.MountSpeed = 0
		if (position - from).Magnitude > allowed and not r.Flagged then
			r.Flagged = true
			warn(string.format("[RideService] %s's fish moved too fast", r.Player.Name))
		end
	end
	r.CheckAt = t + 1
	r.CheckFrom = position
end

-- Riding a fish we can hold makes it ours after Config.tameTime seconds on it (Tame.Time, longer for a fish that
-- needs more; one fish once a dive). `need`: what the fish needs (needOf).
local function tame(r: Rider, w: Wild, dt: number, need: number)
	local c = Config.Tame
	if c.On == 0 or r.Strained then
		return
	end
	local length = Config.tameTime(need, r.Max)
	if not r.Tamed[w] then
		r.Tame += dt / length
		-- (a frame's leeway: the tame counts frames, the ticks the clock, and at exactly what a fish needs both end
		-- together)
		if r.Tame >= 0.98 then
			r.Tame = 1
			r.Tamed[w] = true
			if RideService.OnTamed then
				task.defer(RideService.OnTamed, r.Player, w)
			end
			if #r.Caught < c.Carry then
				table.insert(r.Caught, w.Type.Id)
				table.insert(r.Carried, { Id = w.Type.Id, Size = w.SizeTier, Variant = w.Variant })
				sendCaught(r)
				Net.Ride:FireClient(r.Player, "Tamed", w.Model, w.Type.Id)
			end
		end
	end
	-- (told in fortieths: twenty updates over a tame of two seconds, and none once it is full)
	local share = math.floor(math.clamp(r.Tame, 0, 1) * 40 + 0.5) / 40
	if share ~= r.SentTame then
		r.SentTame = share
		r.Player:SetAttribute("Tame", share)
	end
end

local function tick(r: Rider, dt: number)
	local root = parts(r.Player)
	if not root then
		return
	end
	local o = Config.Oxygen
	if r.State == "Dock" then
		local land = r.Land
		if land and (not land.Model.Parent or r.Player.Character ~= land.Body or busy(r)) then
			-- (the land fish was lost, the body changed, or they sat down somewhere else: off it)
			landOff(r)
		elseif land then
			-- (the walker is the player's own machine: on the land fish it may cover the ground at Equip.LandSpeed, with
			-- room for lag, and no faster; past that it is put back where it last stood fairly: grade issue 7. A fall
			-- is not counted, only the ground covered)
			local e = Config.Equip
			local checked = os.clock()
			local span = checked - land.GoodAt
			if span >= e.CheckEvery then
				local moved = ((root.Position - land.Good) * Vector3.new(1, 0, 1)).Magnitude
				if moved > e.LandSpeed * e.PaceRoom * span + e.PaceSlack then
					root.AssemblyLinearVelocity = Vector3.zero
					root.CFrame = CFrame.new(land.Good) * root.CFrame.Rotation
				else
					land.Good = root.Position
				end
				land.GoodAt = checked
			end
		end
		if root.Position.Y < o.WaterY then
			-- (into the water: the land fish goes before anything else owns the body)
			landOff(r)
			-- (the submarine, when one has been picked at the hub: docs/design/submarine.md)
			if RideService.Diving and RideService.Diving(r.Player) then
				r.Token += 1
				r.Oxygen = r.Max
				setState(r, "Carried")
				sendOxygen(r, true)
			else
				local w = if RideService.DiveFish then RideService.DiveFish(r.Player) else nil
				local seated = false
				if w then
					-- their own fish: it is theirs already (nothing to tame), and the landing's refill
					r.Token += 1
					r.Oxygen = r.Max
					r.Tamed[w] = true
					r.JumpFrom = nil
					r.JumpAt = os.clock() - 60
					seated = mount(r, w, true)
					if not seated then
						FishService.discard(w)
					end
				end
				if not seated then
					setState(r, "Free")
				end
			end
		end
	elseif r.State == "Carried" then
		-- carried by the submarine: nothing drains, nothing is checked; SubService moves the trip on
		r.Oxygen = r.Max
	elseif r.State == "Riding" then
		local w = r.Fish
		if not w or not w.Model.Parent or not r.Weld or not r.Weld.Parent then
			dismount(r, "Lost")
			setState(r, "Free")
		else
			-- the more the fish needs, the more it takes a second: this is the progression (task e1: what THIS fish
			-- needs, wherever it swims; it was the land we were in)
			-- (told to the client when it changes, for the HUD's seconds left on this fish: the Drain attribute)
			-- (and less on a Tank; 2026-11-18: in ticks, and by our max Oxygen too: Config.drainFor)
			local need = needOf(w)
			local rate = Config.drainFor(need, w.Type, r.Max)
			local strained = r.Strained and o.StrainTime > 0
			local first = not strained and firstFish(r) -- (asked before the tame, which ends it)
			-- the red part in even ticks (Oxygen.RedTime): RedTicks pieces of what was left at the line
			local redLine: number?, redSeconds: number? = nil, nil
			if not strained and o.RedTime > 0 then
				local line = Config.redLine(r.Max, w.Type) -- (a third of the big ring: task x2)
				local seconds = Config.redSeconds(Config.secondsOn(need, r.Max, w.Type))
				redLine, redSeconds = line, seconds
				if r.Oxygen > line then
					r.RedPiece = 0 -- (above it again: a landing's refill)
				elseif r.RedPiece <= 0 and r.Oxygen > 0 then
					startRed(r, seconds) -- (got under it between ticks: a crash)
				end
			else
				r.RedPiece = 0
			end
			if strained then
				-- a fish too strong for us: what the break-off left (Oxygen.BreakOff) in StrainTime, whatever the fish
				rate = r.StrainPiece / math.max(r.StrainEvery, 0.01)
			elseif r.RedPiece > 0 then
				rate = r.RedPiece / math.max(r.RedEvery, 0.01)
			end
			if rate ~= r.SentDrain then
				r.SentDrain = rate
				r.Player:SetAttribute("Drain", rate)
			end
			-- (the tame first: a rider with exactly what the fish needs tames it as the last tick goes)
			tame(r, w, dt, need)
			if first then
				r.TickAt = -1 -- (the first fish of all: its meter waits for the tame)
			elseif strained then
				tickDrain(r, rate, dt, r.StrainPiece, r.StrainEvery)
			elseif r.RedPiece > 0 then
				tickDrain(r, rate, dt, r.RedPiece, r.RedEvery)
			else
				tickDrain(r, rate, dt, nil, nil, redLine, redSeconds)
			end
			-- how fast the fish is going, from where we see it (eased over about 0.15 s: its place comes in steps)
			local at = w.Root.Position
			if r.RideFrom and dt > 0 then
				local seen = (at - r.RideFrom).Magnitude / dt
				r.RideSpeed += (seen - r.RideSpeed) * (1 - math.exp(-dt / 0.15))
			end
			r.RideFrom = at
			setAngry(r, if isAngry(r, w) then w else nil)
			checkSpeed(r, w)
			checkCrash(r, w)
			checkEat(r, w)
			if r.Oxygen <= 0 then
				drown(r)
			end
		end
	elseif r.State == "Jumping" then
		-- No drain in the window. Only a granted grab earns time to finish the pull and acknowledge landing.
		local j = Config.Jump
		local deadline = if r.Grab
			then r.GrabAt + j.ReelMax + j.AckTime + j.Slack
			else r.JumpAt + j.Window + r.JumpExtra + j.Slack
		if os.clock() > deadline then
			miss(r)
		end
	elseif r.State == "Free" then
		tickDrain(r, Config.freeDrain(r.Max), dt)
		if r.Oxygen <= 0 and firstFish(r) then
			toDock(r) -- (nobody drowns before their first fish)
		elseif r.Oxygen <= 0 then
			drown(r)
		else
			local flat = if dockSpawn then (root.Position - dockSpawn.Position) * Vector3.new(1, 0, 1) else nil
			if
				flat
				and flat.Magnitude < o.DockRadius
				and root.Position.Y > o.SurfaceY - 2
				and not sandbox("NoFail", r)
			then
				r.SurfacedAt = r.SurfacedAt or os.clock()
				-- (a player who has not ridden yet this dive is given far longer: Config.Dive.FirstDockWait)
				local wait = if r.Rode then o.DockWait else math.max(o.DockWait, Config.Dive.FirstDockWait)
				if os.clock() - (r.SurfacedAt :: number) >= wait then
					toDock(r)
				end
			else
				r.SurfacedAt = nil
			end
		end
	end
	sendOxygen(r)
end

----------------------------------------------------------------------------------------------------------------------
-- Players and characters: setting up a rider when a player joins or gets a new body

local function onCharacter(r: Rider, character: Model)
	r.Token += 1
	-- a new body (a respawn, a reset) unequips the ride fish, as it puts the held one away (task e3)
	unequip(r)
	looseOf[r.Player] = nil
	-- a fish still marked as ours (the old character went without dying first) is let go
	if r.Weld then
		r.Weld:Destroy()
	end
	setAngry(r, nil)
	if r.Fish then
		FishService.release(r.Fish)
	end
	r.Fish = nil
	r.Weld = nil
	r.JumpFrom = nil
	unbank(r)
	r.Oxygen = r.Max
	sendOxygen(r, true)
	setState(r, "Dock")
	PropService.passThrough(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.WalkSpeed = Config.Dock.WalkSpeed
		humanoid.Died:Connect(function()
			if riders[r.Player] == r and r.Fish then
				dismount(r, "Died")
			end
		end)
	end
	if Config.Spawn.SpawnAtDock and dockSpawn then
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root then
			task.wait()
			-- (with fish in hand and a tank of their own: in front of the tank, as after a dive)
			local home = if RideService.Home then RideService.Home(r.Player) else nil
			character:PivotTo(if home then home + Vector3.new(0, 3, 0) else dockSpawn.CFrame + Vector3.new(0, 4, 0))
		end
	end
end

local function onPlayer(player: Player)
	local r: Rider = {
		Player = player,
		State = "Dock",
		Oxygen = maxOxygen(),
		Max = maxOxygen(),
		Trained = 0,
		Banked = 0,
		Landings = 0,
		SandboxRetries = 0,
		SandboxSeat = nil,
		Fish = nil,
		Weld = nil,
		JumpAt = 0,
		JumpFrom = nil,
		GrabAt = 0,
		Grab = nil,
		Token = 0,
		JumpReadyAt = 0,
		SentOxygen = -1,
		SentAt = 0,
		SentDrain = 0,
		Strained = false,
		RedRun = 0,
		AngryFish = nil,
		AngryAt = 0,
		Tame = 0,
		TickAt = -1,
		TickPiece = 0,
		StrainPiece = 0,
		StrainEvery = 1,
		RedPiece = 0,
		RedEvery = 1,
		SentTame = -1,
		Tamed = setmetatable({}, { __mode = "k" }) :: any,
		Caught = {},
		Carried = {},
		Owned = 0,
		CheckAt = 0,
		CheckFrom = nil,
		Flagged = false,
		SurfacedAt = nil,
		Rode = false,
		DiveHop = false,
		CrashCheckAt = 0,
		CrashReadyAt = 0,
		Nosed = false,
		FastAt = 0,
		JumpExtra = 0,
		MountSpeed = 0,
		RideSpeed = 0,
		RideFrom = nil,
		JumpLaunch = 0,
		BoostUntil = 0,
		BoostMost = 1,
		EatCheckAt = 0,
		EatReadyAt = 0,
		AteAt = -math.huge,
		Frenzy = 0,
		BreakReadyAt = 0,
		Equipped = nil,
		EquipAt = 0,
		Land = nil,
	}
	riders[player] = r
	sendOxygen(r, true)
	setState(r, "Dock")
	player.CharacterAdded:Connect(function(character)
		onCharacter(r, character)
	end)
	if player.Character then
		task.spawn(onCharacter, r, player.Character)
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Sandbox and admin reset: where a reset puts a player, and putting them there

-- Where the sandbox's reset puts a player: the lane's start (Sandbox.StartS), or the first place past it with room
-- above the herd for a whole jump; and the way down the lane there
function RideService.sandboxStart(): (Vector3, Vector3)
	-- the first place down the lane with room above the herd for a whole jump
	local startS = Config.Sandbox.StartS
	local at, along = FishService.lanePoint(startS)
	while at.Y > -Config.Sandbox.StartRoom and startS < Config.Sandbox.StartS + 6000 do
		startS += 40
		at, along = FishService.lanePoint(startS)
	end
	-- and a little past it: the first such place is the foot of a drop-off, where the herd is still coming down
	if startS > Config.Sandbox.StartS then
		at, along = FishService.lanePoint(startS + 160)
	end
	return at, along
end

-- The sandbox's reset: into the water at the lane's start, onto the nearest fish there if there is one
-- (`fishId`, `variant`: the sandbox's "Ride": a fish of that kind is put at the start and it is the one we are seated on)
-- (`place`: somewhere else than the lane's start, with the way down there: the admin panel's land jump. An admin
-- (the player attribute Admin, AdminService) may use it outside Studio too.)
function RideService.sandboxReset(
	player: Player,
	again: number?,
	fishId: string?,
	variant: string?,
	place: { At: Vector3, Along: Vector3 }?
)
	local r = riders[player]
	local root, humanoid = parts(player)
	if not r or not root or not humanoid or not (RunService:IsStudio() or player:GetAttribute("Admin") == true) then
		return
	end
	if r.Fish then
		dismount(r, "Lost")
	end
	r.Token += 1
	r.Oxygen = r.Max
	sendOxygen(r, true)
	local at, along = RideService.sandboxStart()
	if place then
		at, along = place.At, place.Along
	end
	-- the fish round the start stay in the Workspace from now on (see SEAT_SETTLED): the first reset to a new start
	-- waits for them, the next ones don't
	FishService.keepNear(at)
	r.SandboxRetries = again or 0
	local chosen = if fishId then FishService.spawnTest(fishId, variant or "", at + along * 30, along) else nil
	humanoid.PlatformStand = true
	(player.Character :: Model):PivotTo(CFrame.lookAt(at, at + along))
	root.AssemblyLinearVelocity = Vector3.zero
	setState(r, "Free")
	Net.Ride:FireClient(player, "Dismounted", "Lost")
	-- Seating the rider, the way a landing does it: the player's own machine puts the character on the saddle first
	-- ("SandboxMount"), says so ("SandboxSit"), and only then is the weld made. (The reset used to weld a floating
	-- character to a fish up to 250 studs away. That was not what threw riders about, as it turned out: the fish's
	-- forces had no limit, see Lib/FishModel. But a mount now has one shape, the landing's.)
	local token = r.Token
	local function trySeat(): boolean
		if r.Token ~= token or r.State ~= "Free" or r.SandboxSeat then
			return true
		end
		local here = parts(player)
		local w: Wild? = nil
		if chosen then
			-- the fish we asked for, once every machine has it (SEAT_SETTLED)
			local ready = chosen.Model.Parent ~= nil and os.clock() - chosen.UnparkedAt >= SEAT_SETTLED
			w = if ready and here and FishService.isFree(chosen, player) then chosen else nil
		elseif here and (here.Position - at).Magnitude < 60 then
			w = FishService.nearest(at, 250, player, SEAT_SETTLED)
		end
		if not w or not FishService.reserve(w, player) then
			return false
		end
		r.SandboxSeat = w
		Net.Ride:FireClient(player, "SandboxMount", w.Model)
		-- if its machine never answers, the fish is let go again
		task.delay(2, function()
			if r.SandboxSeat == w then
				r.SandboxSeat = nil
				FishService.unreserve(w, player)
			end
		end)
		return true
	end
	-- tried a few times a second for eight seconds, until we ride: the fish here may only just have come back into the
	-- Workspace (they are put back by the top-up, every couple of seconds), and a seat the player's machine could not
	-- take is given up and tried again
	task.spawn(function()
		task.wait(0.35)
		for _ = 1, 30 do
			if r.Token ~= token or r.State ~= "Free" then
				return
			end
			trySeat()
			task.wait(0.4)
		end
	end)
end

----------------------------------------------------------------------------------------------------------------------
-- Remotes: the ride fish's asks, then Init with the Action handler and players leaving

-- The ride fish's asks (task e3; docs/design/equip.md), each only on the dock and not seated elsewhere:
--   "RideEquip" (Q): the fish held over the head becomes the ride fish (that very entry of the hands) and is ridden on
--     land; with nothing held, the equipped one is ridden again; with nothing equipped either, nothing.
--   "RideMount" (a click on the equipped slot): on or off the equipped fish on land; it stays equipped.
--   "RideUnequip" (the slot's little cross): no ride fish.
-- Refused with Ride "Denied", "Equip", reason ("Dock", "Busy", "None", "Gone"), changing nothing.
function equipAsk(r: Rider, action: string)
	local t = os.clock()
	if Config.Equip.On == 0 or t - r.EquipAt < Config.Equip.Again then
		return
	end
	r.EquipAt = t
	if action == "RideUnequip" then
		unequip(r)
		return
	end
	if r.State ~= "Dock" then
		deny(r, "Equip", "Dock")
		return
	end
	if busy(r) then
		deny(r, "Equip", "Busy")
		return
	end
	if action == "RideMount" then
		if r.Land then
			landOff(r)
		elseif r.Equipped then
			landOn(r)
		else
			deny(r, "Equip", "None")
		end
		return
	end
	local held = if RideService.HeldOf then RideService.HeldOf(r.Player) else nil
	if held then
		if not table.find(r.Carried, held) then
			deny(r, "Equip", "Gone")
			return
		end
		if r.Equipped ~= held then
			landOff(r) -- (another fish: the old one's model goes)
			r.Equipped = held
		end
		tellEquip(r)
		landOn(r)
	elseif r.Equipped then
		landOn(r)
	else
		deny(r, "Equip", "None")
	end
end

function RideService.Init()
	Net.Action.OnServerEvent:Connect(function(player, action, target)
		local r = riders[player]
		if not r or type(action) ~= "string" then
			return
		end
		if action == "Jump" then
			jump(r)
		elseif action == "Grab" then
			grab(r, target)
		elseif action == "CancelGrab" then
			if r.State == "Jumping" and r.Grab then
				FishService.unreserve(r.Grab, r.Player)
				r.Grab = nil
			end
		elseif action == "SandboxSit" then
			-- the sandbox's reset: the player's machine has put the character on the saddle of the fish we kept
			local w = r.SandboxSeat
			r.SandboxSeat = nil
			if w and (RunService:IsStudio() or player:GetAttribute("Admin") == true) then
				local root = parts(player)
				local near = root and (w.Root.Position - root.Position).Magnitude <= w.Body.Z / 2 + 40
				local seated = r.State == "Free" and FishService.get(target) == w and near and mount(r, w, false)
				if seated and root then
					-- Looked at again a moment later: if the pair is somewhere else entirely, the reset is done again by
					-- itself, twice at most. (A guard: with the fish's forces limited it has not been needed.)
					local from = root.Position
					local token = r.Token
					task.delay(0.6, function()
						local here = parts(player)
						local thrown = here and (here.Position - from).Magnitude > 400
						if thrown and r.Token == token and r.State == "Riding" and r.SandboxRetries < 2 then
							RideService.sandboxReset(player, r.SandboxRetries + 1)
						end
					end)
				end
				if not seated then
					FishService.unreserve(w, player)
					if root then
						warn(
							string.format(
								"[RideService] sandbox seat not taken: state %s, %.0f studs from the fish",
								r.State,
								(w.Root.Position - root.Position).Magnitude
							)
						)
					end
				end
			end
		elseif action == "RideEquip" or action == "RideMount" or action == "RideUnequip" then
			equipAsk(r, action)
		elseif action == "Land" then
			landing(r, target)
		elseif action == "Miss" then
			if r.State == "Jumping" then
				miss(r)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local r = riders[player]
		if r then
			setAngry(r, nil)
		end
		if r and r.Fish then
			dismount(r, "Left")
		end
		if r and r.Grab then
			FishService.unreserve(r.Grab, player)
		end
		if r then
			landOff(r)
		end
		riders[player] = nil
		looseOf[player] = nil
	end)
end

----------------------------------------------------------------------------------------------------------------------
-- For other services, and Start: carried fish, seating, sending home, max Oxygen, forced fails

-- The aquarium (AquariumService): what a player carries, each fish with its size and colour (not to be changed);
local NOTHING: { Carry } = {}
function RideService.carried(player: Player): { Carry }
	local r = riders[player]
	return if r then r.Carried else NOTHING
end

-- and that one of them, the index-th carried (oldest first), has gone in: counted, and taken out of the hands. Gives
-- that fish back, or nil when there is none at that place.
function RideService.takeCarried(player: Player, index: number): Carry?
	local r = riders[player]
	if not r or index ~= index or index < 1 or index > #r.Carried or index % 1 ~= 0 then
		return nil
	end
	local fish = table.remove(r.Carried, index)
	table.remove(r.Caught, index)
	r.Owned += 1
	sendCaught(r)
	return fish
end

-- The submarine's drop-off (SubService; docs/design/submarine.md). Each only from "Carried".
-- (a) No fish: flung forward into an ordinary hop at the sub's drop speed, as the player's machine flies it
-- (JumpController.fling: Config.hopFrom of Sub.DropSpeed). It is the dive's first hop: a miss leaves them floating.
function RideService.fling(player: Player): boolean
	local r = riders[player]
	if not r or r.State ~= "Carried" then
		return false
	end
	r.JumpFrom = nil
	r.DiveHop = true
	r.JumpLaunch, r.JumpExtra = Config.hopFrom(Config.Sub.DropSpeed, nil, nil)
	r.Token += 1
	r.JumpAt = os.clock()
	setState(r, "Jumping")
	return true
end

-- (b) Their own fish beside the sub: on it, as a landing (the refill, every client's landing). It is theirs already,
-- so riding it tames nothing new.
function RideService.seatOn(player: Player, w: Wild): boolean
	local r = riders[player]
	if not r or r.State ~= "Carried" then
		return false
	end
	r.Tamed[w] = true
	r.JumpFrom = nil
	r.JumpAt = os.clock() - 60 -- (a landing that earns the refill)
	r.Token += 1
	return mount(r, w, true)
end

-- Home to the dock now, as after a dive (Studio's tests: SubService's "home")
function RideService.sendHome(player: Player)
	local r = riders[player]
	if r then
		toDock(r)
	end
end

-- Or let go into the water where they are (a drop that went wrong, or a fish that was gone)
function RideService.letGo(player: Player)
	local r = riders[player]
	if not r or r.State ~= "Carried" then
		return
	end
	r.Token += 1
	r.DiveHop = false
	setState(r, "Free")
	Net.Ride:FireClient(r.Player, "Dismounted", "Lost")
end

-- and a player's state ("Dock", "Free", "Riding", "Jumping", "Drowning", "Carried"; nil for a player we don't know)
function RideService.stateOf(player: Player): string?
	local r = riders[player]
	return if r then r.State else nil
end

-- Training (TrainService): a player standing on the dock gains max Oxygen. Returns whether it was given (only on the
-- dock: not in the water, on a fish or drowning). Kept for the session; saved by the save's "Oxygen" part
-- (trainedOxygen, below) once saving is switched on.
function RideService.train(player: Player, amount: number): boolean
	local r = riders[player]
	if not r or r.State ~= "Dock" or amount <= 0 then
		return false
	end
	r.Trained += amount
	r.Max = maxOxygen() + r.Trained
	r.Oxygen = r.Max
	sendOxygen(r, true)
	return true
end

-- Everyone's max Oxygen, read again (Studio: the TestMaxOxygen attribute or the sandbox panel's Oxygen.StartMax changed)
function RideService.readMax()
	for _, r in riders do
		r.Max = maxOxygen() + r.Trained
		r.Oxygen = math.min(r.Oxygen, r.Max)
		if r.State == "Dock" then
			r.Oxygen = r.Max
		end
		sendOxygen(r, true)
	end
end

-- The admin panel (AdminService, docs/sandbox.md; it has checked the player is allowed): a max Oxygen of exactly
-- `max` (by the training on top of the start), the meter full
function RideService.setMax(player: Player, max: number)
	local r = riders[player]
	if not r or max ~= max or max < 1 then
		return
	end
	r.Trained = max - maxOxygen()
	r.Max = max
	r.Oxygen = r.Max
	sendOxygen(r, true)
end

-- The max Oxygen again from the training (saving and bought Oxygen, below): on the dock the meter follows it, as after
-- training (and anything banked in the water joins it); anywhere else the meter is left as it is, only kept under the
-- max
local function retrain(r: Rider)
	if r.State == "Dock" then
		unbank(r)
	end
	r.Max = maxOxygen() + r.Trained
	r.Oxygen = math.min(r.Oxygen, r.Max)
	if r.State == "Dock" then
		r.Oxygen = r.Max
	end
	sendOxygen(r, true)
end

-- For saving (src/server/Lib/SaveParts.luau, the UI chat's saving, part "Oxygen"): the trained Oxygen, on top of what
-- everyone starts with, 0 or more, WITH any Oxygen bought in the water and not yet in the max (Banked), so a bought
-- pack is saved the moment it is given. nil while we don't have the player (not joined yet, or gone), never a default,
-- and nil if it is not a number (the last good save is kept). Doesn't yield.
function RideService.trainedOxygen(player: Player): number?
	local r = riders[player]
	local all = if r then r.Trained + r.Banked else 0
	if not r or all ~= all or math.abs(all) == math.huge then
		return nil
	end
	return math.max(all, 0)
end

-- For saving (SaveParts, part "Oxygen", which adds the kept amount to trainedOxygen itself): the trained Oxygen set to
-- `n`, never under 0 (the start training grows from) and not capped, as training is not (Oxygen.Cap is where the
-- ticks stop quickening, not a limit on the max), the HUD told at once (the meter full on the dock, as after
-- training; left as it is in the water). False for a player we don't have, a NaN or an endless number.
-- Doesn't yield.
function RideService.setTrainedOxygen(player: Player, n: number): boolean
	local r = riders[player]
	if not r or type(n) ~= "number" or n ~= n or math.abs(n) == math.huge then
		return false
	end
	-- (`n` is the whole of it, as trainedOxygen gives it: what is banked in the water stays banked)
	r.Trained = math.max(n - r.Banked, 0)
	retrain(r)
	return true
end

-- For bought Oxygen (PurchaseService, the UI chat's Robux purchases; it lives in the save's "Oxygen" part): `amount`
-- more trained Oxygen, given in any state (train() is only on the dock). On the dock the max goes up at once and the
-- meter follows it, as after training. Off the dock it is BANKED: counted by trainedOxygen at once (so it is saved),
-- and it joins the max when the rider next reaches the dock (the user, 2026-11-23: "At the dock"). Nothing changes
-- mid-dive, because the red line, the ticks and the drain are shares of the max: a max raised under a half-empty meter
-- put it in the red and ended the ride sooner. Not capped, as training is not. False for a player we don't have, or
-- an amount that is not a number above 0. Doesn't yield.
function RideService.grantOxygen(player: Player, amount: number): boolean
	local r = riders[player]
	if not r or type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then
		return false
	end
	if r.State == "Dock" then
		r.Trained += amount
		retrain(r)
	else
		r.Banked += amount
	end
	return true
end

-- a fail now, from the water, whatever the no-fail switches say (on a fish: thrown off first, as out of Oxygen)
function RideService.forceFail(player: Player, kind: string?): boolean
	local r = riders[player]
	if not r or (r.State ~= "Riding" and r.State ~= "Free" and r.State ~= "Jumping") then
		return false
	end
	if r.State == "Jumping" then
		local d = Config.Death
		die(r, "Drowning", d.DrownTime - d.Throw, false)
		return true
	end
	drown(r, true, kind)
	return true
end

-- and a fish put in the hands, as if caught on this dive (to be put in the tank like any catch)
-- (false with no rider, or with the slots full: Tame.Carry, as a catch)
function RideService.giveCarried(player: Player, fish: Carry): boolean
	local r = riders[player]
	if not r or #r.Caught >= Config.Tame.Carry then
		return false
	end
	table.insert(r.Caught, fish.Id)
	table.insert(r.Carried, { Id = fish.Id, Size = fish.Size, Variant = fish.Variant })
	sendCaught(r)
	return true
end

-- The ride fish (task e3): the player's equipped entry of the hands (the very table: read it, never change it), or
-- nil. What a dive in and the sub ride (SubService), copied as the dive leaves
function RideService.equippedOf(player: Player): Carry?
	local r = riders[player]
	local carry = r and r.Equipped
	return if r and carry and table.find(r.Carried, carry) then carry else nil
end

-- Off the land fish now, keeping it equipped (AquariumService: holding a fish over the head is a pose of its own)
function RideService.landOff(player: Player)
	local r = riders[player]
	if r then
		landOff(r)
	end
end

-- Riding a fish out of the tank (Config.TankRide.Out; TankRideService): why the land ride could not start now, by the
-- rules Q keeps ("Equip" off, "Dock", "Again" inside Equip.Again of the last ask, "Hands" full, "Dead", "Busy" on the
-- trainer or seated), or nil. The tank ride itself is not counted: it is ended first. Changes nothing
function RideService.outRefusal(player: Player): string?
	local r = riders[player]
	local root, humanoid = parts(player)
	if not r or not root or not humanoid then
		return "Dead"
	end
	if Config.Equip.On == 0 then
		return "Equip"
	end
	if r.State ~= "Dock" then
		return "Dock"
	end
	if os.clock() - r.EquipAt < Config.Equip.Again then
		return "Again"
	end
	if #r.Caught >= Config.Tame.Carry or #r.Carried >= Config.Tame.Carry then
		return "Hands"
	end
	if player:GetAttribute("TrainerRide") ~= nil or humanoid.Sit then
		return "Busy"
	end
	return nil
end

-- and on it: `carry` (the very entry of the hands just taken out of the tank) becomes the ride fish and is ridden on
-- land, as Q does with a held fish. true when on it
function RideService.rideOut(player: Player, carry: Carry): boolean
	local r = riders[player]
	if not r or not table.find(r.Carried, carry) then
		return false
	end
	r.EquipAt = os.clock()
	landOff(r) -- (landOn starts from on foot)
	r.Equipped = carry
	tellEquip(r)
	return landOn(r)
end

function RideService.Start()
	-- the ragdoll's group (ragdoll): solid to the map, the props and the fish, never to another player or itself
	-- (PropService.Init has made the others)
	if not PhysicsService:IsCollisionGroupRegistered("Ragdoll") then
		PhysicsService:RegisterCollisionGroup("Ragdoll")
	end
	for _, group in { "Riders", "Riding", "Ragdoll" } do
		if PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:CollisionGroupSetCollidable("Ragdoll", group, false)
		end
	end
	dockSpawn = findDockSpawn()
	if not dockSpawn then
		warn("[RideService] no dock Spawn found: respawning reloads the character instead")
	else
		-- for the client: where a player is stood on the dock and which way they face (it turns the view to match)
		Net.Folder:SetAttribute("Dock", dockSpawn.CFrame)
		-- Roblox puts a new character on a SpawnLocation first, and the place's own one (Studio's default) sits on a
		-- grey baseplate thousands of studs from the map. For this run only it is moved onto the dock's spawn and
		-- made unseen, so a character appears on the dock from its first frame. The place itself is not changed.
		for _, child in workspace:GetChildren() do
			if child:IsA("SpawnLocation") then
				child.Anchored = true
				child.CanCollide = false
				child.CanQuery = false
				child.Transparency = 1
				for _, face in child:GetChildren() do
					if face:IsA("Decal") or face:IsA("Texture") then
						face.Transparency = 1
					end
				end
				child.CFrame = dockSpawn.CFrame
			end
		end
	end
	workspace:GetAttributeChangedSignal("TestMaxOxygen"):Connect(RideService.readMax)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	RunService.Heartbeat:Connect(function(dt)
		for _, r in riders do
			tick(r, dt)
		end
	end)
end

return RideService
