--!strict
-- Riding, Oxygen, the jump fish to fish and drowning, all decided here (docs/design/riding-feel.md); clients only steer
-- and animate. Per player: a state (Dock, Free, Riding, Jumping, Drowning, mirrored in the player's State attribute),
-- the Oxygen meter, and the fish they're on.
--   Riding drains the fish's Drain a second. At zero the fish throws you off and you drown (Drowning, DeathAt).
--   The jump (Config.Jump, the reference's): from a fish or from floating, the player leaves into a flight their own
--   client steers. No drain in the flight. The client says which fish it came down on ("Land"), and the server checks it
--   (the fish free, the player over it, give or take lag) and mounts them, with the refill. Coming down on nothing
--   ("Miss", or the flight's time running out) ends the run, from a fish or from floating: you sink and drown (a
--   short drown), until there is a revive.
--   Free (in the water off a fish: diving in off the dock, or a lost landing) drains Oxygen.FreeDrain; at zero you drown,
--   without the throw.
--   Drowning takes no input and ends at the dock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local FishService = require(script.Parent.FishService)

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
	Token: number, -- bumps on every move and death, so a stale landing or respawn does nothing
	JumpReadyAt: number,
	SentOxygen: number,
	SentAt: number,
	CheckAt: number,
	CheckFrom: Vector3?,
	Flagged: boolean,
	SurfacedAt: number?, -- os.clock() a Free rider came up near the dock
}

local RideService = {}

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

local function setState(r: Rider, state: string)
	if state ~= "Free" then
		r.SurfacedAt = nil
	end
	if state ~= "Drowning" then
		r.Player:SetAttribute("DeathAt", nil)
		r.Player:SetAttribute("DeathThrown", nil)
		r.Player:SetAttribute("DeathQuick", nil)
	end
	r.State = state
	r.Player:SetAttribute("State", state)
end

local function sendOxygen(r: Rider, force: boolean?)
	local t = os.clock()
	if force or math.abs(r.Oxygen - r.SentOxygen) >= 0.5 or (t - r.SentAt > 0.1 and r.Oxygen ~= r.SentOxygen) then
		r.SentOxygen = r.Oxygen
		r.SentAt = t
		r.Player:SetAttribute("Oxygen", math.floor(r.Oxygen * 10 + 0.5) / 10)
		r.Player:SetAttribute("MaxOxygen", r.Max)
	end
end

local function deny(r: Rider, action: string, reason: string)
	Net.Ride:FireClient(r.Player, "Denied", action, reason)
end

-- Off the fish. A jump lets our client coast the old fish a while (no hitch in front of us).
local function dismount(r: Rider, reason: string, handBack: boolean?)
	local w = r.Fish
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
	-- the client has already blended the rider onto the saddle, so this only lines the server's copy up (left out, the
	-- weld could move the fish to the rider instead)
	root.CFrame = w.Saddle.WorldCFrame
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
		Net.Fx:FireAllClients("Land", r.Player, w.Model)
	end
	setState(r, "Riding")
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

-- The jump: off the fish (or from floating) into the flight
local function jump(r: Rider)
	if r.State ~= "Riding" and r.State ~= "Free" then
		return deny(r, "Jump", "State")
	end
	if os.clock() < r.JumpReadyAt then
		return deny(r, "Jump", "Cooldown")
	end
	r.JumpFrom = r.Fish
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

-- The landing the client asks for: the fish must be free and the player over it (the ring, plus slack for lag)
local function landOn(r: Rider, target: any)
	if r.State ~= "Jumping" then
		return deny(r, "Land", "State")
	end
	local j = Config.Jump
	local root = parts(r.Player)
	local w = FishService.get(if typeof(target) == "Instance" then target else nil)
	if not root or not w or not FishService.isFree(w, r.Player) then
		-- the fish went away or was taken under us (not the player's fault): back to floating, not a miss
		setState(r, "Free")
		Net.Ride:FireClient(r.Player, "Dismounted", "Lost")
		return
	end
	-- the server sees the player a moment late, and a dropped flight comes down fast: wide across, and anywhere in the
	-- band of heights a flight can reach
	local offset = w.Root.Position - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local reach = j.RingRadius * Config.Net.RangeSlack + w.Type.Size.Z / 2 + j.LandSlack
	if flat > reach or math.abs(offset.Y) > j.ReachDown + j.Apex + j.LandSlack then
		deny(r, "Land", "Range")
		return miss(r)
	end
	if not mount(r, w, true) then
		setState(r, "Free")
		Net.Ride:FireClient(r.Player, "Dismounted", "Lost")
	end
end

local function drain(r: Rider, amount: number)
	if sandbox("EndlessAir") then
		r.Oxygen = r.Max
		return
	end
	r.Oxygen = math.max(0, r.Oxygen - amount)
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
		local allowed = w.Type.RiddenSpeed * Config.Ride.Surge * Config.Ride.SpeedSlack + 10
		if (position - from).Magnitude > allowed and not r.Flagged then
			r.Flagged = true
			warn(string.format("[RideService] %s's fish moved too fast", r.Player.Name))
		end
	end
	r.CheckAt = t + 1
	r.CheckFrom = position
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
			drain(r, w.Type.Drain * dt)
			checkSpeed(r, w)
			if r.Oxygen <= 0 then
				drown(r)
			end
		end
	elseif r.State == "Jumping" then
		-- no drain in the flight; past its time (and the lag slack) with no landing, it's a miss
		if os.clock() - r.JumpAt > Config.Jump.FlightTime + Config.Jump.Slack then
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
	if r.Fish then
		FishService.release(r.Fish)
	end
	r.Fish = nil
	r.Weld = nil
	r.JumpFrom = nil
	r.Oxygen = r.Max
	sendOxygen(r, true)
	setState(r, "Dock")
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
		Fish = nil,
		Weld = nil,
		JumpAt = 0,
		JumpFrom = nil,
		Token = 0,
		JumpReadyAt = 0,
		SentOxygen = -1,
		SentAt = 0,
		CheckAt = 0,
		CheckFrom = nil,
		Flagged = false,
		SurfacedAt = nil,
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

-- The sandbox's reset: into the water at the lane's start, onto the nearest fish there if there is one
function RideService.sandboxReset(player: Player)
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
	humanoid.PlatformStand = true
	(player.Character :: Model):PivotTo(CFrame.lookAt(at, at + along))
	root.AssemblyLinearVelocity = Vector3.zero
	setState(r, "Free")
	Net.Ride:FireClient(player, "Dismounted", "Lost")
	local w = FishService.nearest(at, 250, player)
	if w then
		mount(r, w, false)
		return
	end
	-- the fish there were put away while nobody was near: they are back by the next top-up
	local token = r.Token
	task.delay(Config.Spawn.TopUpEvery + 0.5, function()
		local late = if r.Token == token and r.State == "Free" then FishService.nearest(at, 250, player) else nil
		if late then
			mount(r, late, false)
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
		if r and r.Fish then
			dismount(r, "Left")
		end
		riders[player] = nil
	end)
end

function RideService.Start()
	dockSpawn = findDockSpawn()
	if not dockSpawn then
		warn("[RideService] no dock Spawn found: respawning reloads the character instead")
	end
	workspace:GetAttributeChangedSignal("TestMaxOxygen"):Connect(function()
		for _, r in riders do
			r.Max = maxOxygen()
			r.Oxygen = math.min(r.Oxygen, r.Max)
			if r.State == "Dock" then
				r.Oxygen = r.Max
			end
			sendOxygen(r, true)
		end
	end)
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
