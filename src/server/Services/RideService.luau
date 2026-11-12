--!strict
-- Riding, Oxygen, the jump fish to fish and drowning, all decided here (docs/design/riding-feel.md); clients only steer
-- and animate. Per player: a state (Dock, Free, Riding, Jumping, Drowning, mirrored in the player's State attribute),
-- the Oxygen meter (the design notes' stamina), and the fish they're on.
--   Riding drains Oxygen by the land the rider is in and the fish's rarity (Config.drain: steep, land by land; this is
--   the progression). At zero the fish throws you off and you drown (Drowning, DeathAt). A hop is never refused for
--   Oxygen and costs none, so at almost nothing you can still go fish to fish, and every landing refills.
--   Running the fish into something solid never kills (Config.Crash): it costs Oxygen and the client is told to slow.
--   A prop breaks instead (PropService), for less.
--   Going fish to fish (Config.Jump): from a fish or from floating, the player leaves into a hop their own client
--   moves (the pop, the glide, the drop; A and D). That is the window, Jump.Window seconds, with no drain. To take a fish
--   the client says which it is going for ("Grab"): the server checks it is free and within Jump.GrabRange of the
--   player (the same hard cap the client uses) and keeps it for them, so two players
--   can't be pulled onto one fish. When the pull-in ends the client says so ("Land"): it must be the fish that was
--   granted, with the player now at it, and the server mounts them, with the refill. A refused grab costs nothing but
--   time: the window runs on. The window running out with no landing ("Miss", or the server's own clock) ends the run,
--   from a fish or from floating: you have sunk and drown (a short drown), until there is a revive.
--   Free (in the water off a fish: diving in off the dock, or a lost landing) drains Oxygen.FreeDrain; at zero you drown,
--   without the throw.
--   Drowning takes no input and ends at the dock.
--   Angry mode (Config.Angry): while a rider's meter is in its red part (Oxygen.AngryAt), or on a fish too strong from
--   the touch, the fish under them is angry. Decided here and written on the fish (its "Angry" and "AngryStyle"
--   attributes, and the "AngryFish" tag): every client pulses it red, and the rider's own slows it in its style's way
--   (Shared/AngryStyles), which the speed check here then holds it to.
--   The passive archetypes (Config.Archetype; docs/design/archetypes.md), all decided here: a Predator eats the
--   smaller wild fish its nose reaches (checkEat: the fish is gone, the rider gets a burst of speed and Oxygen; a
--   Frenzy chains them), a Breaker goes through props for nothing and is paid for it (checkCrash), a Tank drains
--   slower and turns angry later (Config.drainOf, Config.low), a Leaper's hop has a longer window (jump), a Fast
--   fish's bigger burst is allowed by the speed check (Config.surgeOf). The rider's client is told of a burst
--   ("Boost"), every client of the bite or the smash (Fx "Eat", "Smash"), and the fish carries "Bite", "Smash" and
--   "Frenzy" attributes for the animations to come.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AngryStyles = require(ReplicatedStorage.Shared.AngryStyles)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Zones = require(ReplicatedStorage.Shared.Zones)
local FishService = require(script.Parent.FishService)
local PropService = require(script.Parent.PropService)

type Wild = FishService.Wild
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
	AngryFish: Wild?, -- the fish we have marked angry (its attributes and tag are ours to take off again)
	AngryAt: number, -- os.clock() it turned angry
	Tame: number, -- seconds ridden toward taming the fish under us
	SentTame: number, -- the Tame attribute as last told (-1: none)
	Tamed: { [Wild]: boolean }, -- the fish made ours on this dive (so one fish is not tamed twice)
	Caught: { string }, -- what we carry on this dive: fish ids, oldest first
	Owned: number, -- creatures brought home this session
	Trained: number, -- max Oxygen gained on the training spot this session (TrainService), on top of the start
	Landings: number, -- landings so far this session: sent with each "Land", so every client picks the same reaction
	SandboxRetries: number, -- times the sandbox's reset has been done again by itself after a seat that went wrong
	SandboxSeat: FishService.Wild?, -- the fish the sandbox's reset is seating us on (kept for us until we say we sit)
	CheckAt: number,
	CheckFrom: Vector3?,
	Flagged: boolean,
	SurfacedAt: number?, -- os.clock() a Free rider came up near the dock
	CrashCheckAt: number, -- os.clock() of the next look for something in the fish's way
	CrashReadyAt: number, -- and before this a crash or a smashed prop costs nothing
	Nosed: boolean, -- the fish's nose is up against something solid (so it is counted once)
	FastAt: number, -- os.clock() the fish was last seen going fast enough to crash
	-- the passive archetypes (Config.Archetype)
	JumpExtra: number, -- seconds this hop's window is longer by (off a Leaper)
	BoostUntil: number, -- os.clock() the last burst of speed we were given ends (an eat's, a smash's),
	BoostMost: number, -- and how many times its speed the fish may go until then (the speed check)
	EatCheckAt: number, -- os.clock() of the next look for something to eat
	EatReadyAt: number, -- and before this the fish under us doesn't bite again (Predator.Cooldown)
	AteAt: number, -- os.clock() of its last bite,
	Frenzy: number, -- and the Frenzy's stacks so far (0: none)
	BreakReadyAt: number, -- before this a broken prop pays a Breaker nothing more (Breaker.Cooldown)
}

local RideService = {}

-- The sandbox's reset seats a rider only on a fish that has been in the Workspace this long, so the player's machine
-- has the fish too (it is told to sit on it).
local SEAT_SETTLED = 1

local riders: { [Player]: Rider } = {}
local dockSpawn: BasePart? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

-- The movement sandbox's switches (Studio only; SandboxService sets the attributes)
local function sandbox(flag: string): boolean
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
	if state ~= "Free" then
		r.SurfacedAt = nil
	end
	if state ~= "Jumping" and r.Grab then
		-- the pull-in is over, one way or another: the fish it was granted is let go (nothing to do once we ride it)
		FishService.unreserve(r.Grab, r.Player)
		r.Grab = nil
	end
	if state ~= "Drowning" then
		r.Player:SetAttribute("DeathAt", nil)
		r.Player:SetAttribute("DeathThrown", nil)
		r.Player:SetAttribute("DeathQuick", nil)
	end
	if state ~= "Riding" then
		if r.SentDrain ~= 0 then
			r.SentDrain = 0
			r.Player:SetAttribute("Drain", 0)
		end
		if r.Strained then
			r.Strained = false
			r.Player:SetAttribute("Strained", nil)
		end
		if r.SentTame ~= -1 then
			r.SentTame = -1
			r.Player:SetAttribute("Tame", nil)
		end
		setAngry(r, nil)
	end
	r.State = state
	r.Player:SetAttribute("State", state)
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
		r.Player:SetAttribute("MaxOxygen", math.floor(r.Max * 10 + 0.5) / 10)
	end
end

-- The land a rider is in, for the drain (before the first land, the lagoon: the first)
local function zoneOf(position: Vector3): number
	local zone = Zones.locate(FishService.zones(), position)
	return if zone then zone.Index else 1
end

-- What the rider carries on this dive, told to their client
local function sendCaught(r: Rider)
	Net.Ride:FireClient(r.Player, "Caught", r.Caught)
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
	if (root.Position - w.Saddle.WorldPosition).Magnitude > 30 then
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
	r.Nosed = false
	-- (a new fish: no burst carried over, and its first bite is a first bite)
	r.BoostUntil = 0
	r.BoostMost = 1
	r.Frenzy = 0
	r.AteAt = -math.huge
	-- Too strong for us? Decided here, at the mount, by the land the fish is in: a landing is never refused, the meter
	-- just empties at once (Oxygen.StrainTime). Riding a fish we can hold on into a deeper land only costs that land's
	-- drain.
	r.Strained = Config.strained(zoneOf(w.Root.Position), w.Type.Tier, r.Max) and not sandbox("EndlessAir")
	r.Player:SetAttribute("Strained", if r.Strained then true else nil)
	r.Tame = if r.Tamed[w] then Config.Tame.Time else 0
	if landing then
		-- the refill is for reaching another fish: not for hopping off and back onto the same one, nor for a landing
		-- sooner than a flight can be
		local flown = os.clock() - r.JumpAt >= Config.Jump.MinFlight
		if w ~= r.JumpFrom and flown then
			r.Oxygen = math.min(r.Max, r.Oxygen + r.Max * Config.Oxygen.Refill)
		end
		r.JumpFrom = nil
		r.JumpReadyAt = os.clock() + Config.Jump.Cooldown
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
	r.Token += 1
	local root, humanoid = parts(r.Player)
	if root and humanoid then
		humanoid.PlatformStand = false
		local character = r.Player.Character :: Model
		if dockSpawn then
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
	r.Oxygen = r.Max
	sendOxygen(r, true)
	setState(r, "Dock")
	-- the dive's catch comes home (death or not, as the reference's): counted, and the hands are empty again
	if #r.Caught > 0 then
		r.Owned += #r.Caught
		r.Player:SetAttribute("Owned", r.Owned)
	end
	table.clear(r.Caught)
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

-- Out of Oxygen: on a fish it bucks and throws you off first (everyone's clients animate both), then you drown
local function drown(r: Rider)
	local d = Config.Death
	local w = r.Fish
	if w then
		local model = w.Model
		dismount(r, "OutOfOxygen", true)
		Net.Fx:FireAllClients("ThrowOff", r.Player, model)
		die(r, "Drowning", d.DrownTime, true)
	else
		die(r, "Drowning", d.DrownTime - d.Throw, false)
	end
end

-- The jump: off the fish (or from floating) into the hop. Never refused for Oxygen, and it costs none: however little
-- is left you can still go fish to fish (Hugo, 2026-11-11).
local function jump(r: Rider)
	if r.State ~= "Riding" and r.State ~= "Free" then
		return deny(r, "Jump", "State")
	end
	if os.clock() < r.JumpReadyAt then
		return deny(r, "Jump", "Cooldown")
	end
	r.JumpFrom = r.Fish
	-- (off a Leaper the glide and the window are longer: Config.hopOf, the same number the client flies by)
	local _, _, extra = Config.hopOf(if r.Fish then r.Fish.Type else nil)
	r.JumpExtra = extra
	if r.Fish then
		dismount(r, "Jump", true)
	end
	r.Token += 1
	r.JumpAt = os.clock()
	setState(r, "Jumping")
end

-- A flight that came down on nothing: sunk, and a short drown
local function miss(r: Rider)
	if sandbox("NoFail") then
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
	local elapsed = os.clock() - r.JumpAt
	if r.Grab or elapsed > j.Window + r.JumpExtra + j.Slack then
		return deny(r, "Grab", "Window", target)
	end
	-- The client's hard cap, and a little for lag (we see the player and the fish a moment apart, both moving): without
	-- it a grab near the edge of the range is refused though the client was inside it. Landing slack never widens this.
	local reach = j.GrabRange * Config.Net.RangeSlack
	if not ((w.Root.Position - root.Position).Magnitude <= reach) then
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
local function landOn(r: Rider, target: any)
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
	-- the server sees the player a moment late, and a pull-in arrives fast
	local reach = w.Body.Z / 2 + j.LandSlack * 2
	if not ((w.Root.Position - root.Position).Magnitude <= reach) then
		-- (a refused grab, not a miss: the hop goes on with what is left of its window. It was a drown, "MISSED THE
		-- FISH" while sitting on the fish, which a slow connection on a fast fish could reach)
		FishService.unreserve(w, r.Player)
		r.Grab = nil
		return deny(r, "Grab", "Range", target)
	end
	if not mount(r, w, true) then
		FishService.unreserve(w, r.Player)
		r.Grab = nil
		deny(r, "Grab", "Target", target)
	end
end

local function drain(r: Rider, amount: number)
	if sandbox("EndlessAir") then
		r.Oxygen = r.Max
		return
	end
	r.Oxygen = math.max(0, r.Oxygen - amount)
end

-- The fish ran into something: Oxygen is taken here, and the rider's client is told to slow (`slow`: the share of its
-- speed it keeps). Never the last of the Oxygen: a crash can't be what drowns you.
local function bump(r: Rider, cost: number, slow: number)
	local c = Config.Crash
	r.CrashReadyAt = os.clock() + c.Cooldown
	if not sandbox("EndlessAir") then
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
	if not sandbox("EndlessAir") then
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
	-- a prop: its boxes are knocked loose and the fish swims on through (reaching as far as it swims between two looks)
	-- A Breaker (Config.Archetype.Breaker) knocks a wider hole, loses nothing by it, and is paid: a push and a little
	-- Oxygen, at most once every Breaker.Cooldown.
	local breaker = Config.hasArchetype(w.Type, "Breaker")
	local b = Config.Archetype.Breaker
	if speed >= c.MinSpeed and Config.smashes(w.Type) then
		local reach = math.max(w.Body.X, w.Body.Y) / 2
			+ Config.Props.Reach
			+ (if breaker then b.Reach else 0)
			+ speed * c.Every / 2
		local nose = root.Position + look * half
		local loose = PropService.hit(nose, velocity, reach)
		if loose > 0 then
			if breaker then
				if t >= r.BreakReadyAt then
					r.BreakReadyAt = t + b.Cooldown
					reward(r, w, "Smash", b.Burst, b.BurstTime, b.Oxygen, nose, loose)
				end
			elseif t >= r.CrashReadyAt then
				bump(r, Config.Props.Cost, Config.Props.Slow)
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
	if props and Config.smashes(w.Type) then
		-- (this fish breaks props: they were looked at above)
		table.insert(skip, props)
	end
	crashParams.FilterDescendantsInstances = skip
	local ahead = half + 1 + FishService.ridden(w) * Config.Ride.Surge * 0.12 + c.Reach
	local hit = workspace:Raycast(root.Position, look * ahead, crashParams)
	local nosed = hit ~= nil and hit.Normal.Y < 0.5 and -look:Dot(hit.Normal) >= c.HeadOn
	if nosed and not r.Nosed and t - r.FastAt <= 0.5 and t >= r.CrashReadyAt then
		-- (a Breaker loses only Breaker.Crash of what a wall costs: of the Oxygen, and of the speed it drops by)
		local share = if breaker then math.clamp(b.Crash, 0, 1) else 1
		bump(r, c.Cost * share, 1 - (1 - c.Slow) * share)
	end
	r.Nosed = nosed
end

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
		if (position - from).Magnitude > allowed and not r.Flagged then
			r.Flagged = true
			warn(string.format("[RideService] %s's fish moved too fast", r.Player.Name))
		end
	end
	r.CheckAt = t + 1
	r.CheckFrom = position
end

-- Riding a fish we can hold makes it ours after Tame.Time seconds on it (one fish once a dive)
local function tame(r: Rider, w: Wild, dt: number)
	local c = Config.Tame
	if c.On == 0 or r.Strained then
		return
	end
	local length = math.max(c.Time, 0.05)
	if not r.Tamed[w] then
		r.Tame += dt
		if r.Tame >= length then
			r.Tamed[w] = true
			if #r.Caught < c.Carry then
				table.insert(r.Caught, w.Type.Id)
				sendCaught(r)
				Net.Ride:FireClient(r.Player, "Tamed", w.Model, w.Type.Id)
			end
		end
	end
	-- (told in fortieths: twenty updates over a tame of two seconds, and none once it is full)
	local share = math.floor(math.clamp(r.Tame / length, 0, 1) * 40 + 0.5) / 40
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
		if root.Position.Y < o.WaterY then
			setState(r, "Free")
		end
	elseif r.State == "Riding" then
		local w = r.Fish
		if not w or not w.Model.Parent or not r.Weld or not r.Weld.Parent then
			dismount(r, "Lost")
			setState(r, "Free")
		else
			-- the deeper the land, the more the fish takes a second: this is the progression
			-- (told to the client when it changes, for the HUD's seconds left on this fish: the Drain attribute)
			-- (and less on a Tank: Config.drainOf)
			local rate = Config.drainOf(zoneOf(root.Position), w.Type)
			if r.Strained and o.StrainTime > 0 then
				-- a fish too strong for us: the whole meter in StrainTime, whatever the fish
				rate = r.Max / o.StrainTime
			end
			if rate ~= r.SentDrain then
				r.SentDrain = rate
				r.Player:SetAttribute("Drain", rate)
			end
			drain(r, rate * dt)
			tame(r, w, dt)
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
		drain(r, o.FreeDrain * dt)
		if r.Oxygen <= 0 then
			drown(r)
		else
			local flat = if dockSpawn then (root.Position - dockSpawn.Position) * Vector3.new(1, 0, 1) else nil
			if
				flat
				and flat.Magnitude < o.DockRadius
				and root.Position.Y > o.SurfaceY - 2
				and not sandbox("NoFail")
			then
				r.SurfacedAt = r.SurfacedAt or os.clock()
				if os.clock() - (r.SurfacedAt :: number) >= o.DockWait then
					toDock(r)
				end
			else
				r.SurfacedAt = nil
			end
		end
	end
	sendOxygen(r)
end

local function onCharacter(r: Rider, character: Model)
	r.Token += 1
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
			character:PivotTo(dockSpawn.CFrame + Vector3.new(0, 4, 0))
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
		AngryFish = nil,
		AngryAt = 0,
		Tame = 0,
		SentTame = -1,
		Tamed = setmetatable({}, { __mode = "k" }) :: any,
		Caught = {},
		Owned = 0,
		CheckAt = 0,
		CheckFrom = nil,
		Flagged = false,
		SurfacedAt = nil,
		CrashCheckAt = 0,
		CrashReadyAt = 0,
		Nosed = false,
		FastAt = 0,
		JumpExtra = 0,
		BoostUntil = 0,
		BoostMost = 1,
		EatCheckAt = 0,
		EatReadyAt = 0,
		AteAt = -math.huge,
		Frenzy = 0,
		BreakReadyAt = 0,
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
function RideService.sandboxReset(player: Player, again: number?, fishId: string?, variant: string?)
	local r = riders[player]
	local root, humanoid = parts(player)
	if not r or not root or not humanoid or not RunService:IsStudio() then
		return
	end
	if r.Fish then
		dismount(r, "Lost")
	end
	r.Token += 1
	r.Oxygen = r.Max
	sendOxygen(r, true)
	local at, along = RideService.sandboxStart()
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
			if w and RunService:IsStudio() then
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
		elseif action == "Land" then
			landOn(r, target)
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
		riders[player] = nil
	end)
end

-- Training (TrainService): a player standing on the dock gains max Oxygen. Returns whether it was given (only on the
-- dock: not in the water, on a fish or drowning). Kept for the session; there are no saves yet.
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

function RideService.Start()
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
