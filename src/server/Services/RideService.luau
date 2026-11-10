--!strict
-- Riding, Oxygen, moving fish to fish and dying, all decided here (docs/design/riding-feel.md, round 2); clients only
-- steer and animate. Per player: a state (Dock, Free, Riding, Hooking, Dashing, Grappling, Eaten, Drowning, mirrored in
-- the player's State attribute), the Oxygen meter, and the fish they're on.
--   Riding drains the fish's Drain a second. At zero the fish throws you off and you drown (Drowning, DeathAt).
--   Jumping off (or the hook from Free) opens the hook window (Hooking, HookEnds): Grapple.AimTime real seconds, no drain,
--   one shot. A shot on a fish reels you onto it; a shot at nothing, a shot the server can't allow, or the window running
--   out (plus Grapple.Slack for lag) is a miss, and the eater gets you (Eaten, DeathAt).
--   Free (in the water off a fish: diving in off the dock, or a lost landing) drains Oxygen.FreeDrain; at zero you drown,
--   without the throw.
--   Dash and Grapple are checked here (state, range with lag slack, the fish not taken), the fish reserved for the move,
--   and the landing (a mount plus the refill) happens on the server's clock when the move's time is up.
--   Both deaths take no input and end at the dock.
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
	HookEnds: number?, -- server time the hook window shuts
	Token: number, -- bumps on every move and death, so a stale landing or respawn does nothing
	DashReadyAt: number,
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
	if state ~= "Hooking" and r.HookEnds then
		r.HookEnds = nil
		r.Player:SetAttribute("HookEnds", nil)
	end
	if state ~= "Eaten" and state ~= "Drowning" then
		r.Player:SetAttribute("DeathAt", nil)
		r.Player:SetAttribute("DeathThrown", nil)
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

-- Off the fish. A switch or a jump-off lets our client coast the old fish a while (no hitch in front of us).
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
		r.Oxygen = math.min(r.Max, r.Oxygen + r.Max * Config.Oxygen.Refill)
		r.DashReadyAt = os.clock() + Config.Dash.Cooldown
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

-- Both deaths: no input for their length, then the dock. Clients play them from DeathAt (everyone sees them).
local function die(r: Rider, state: string, length: number, thrown: boolean)
	r.Token += 1
	local token = r.Token
	-- the timing first, so clients have it when the State changes
	r.Player:SetAttribute("DeathAt", now())
	r.Player:SetAttribute("DeathThrown", thrown)
	setState(r, state)
	task.delay(length, function()
		if r.Token == token and r.State == state and riders[r.Player] == r then
			toDock(r)
		end
	end)
end

local function eaten(r: Rider)
	if r.Fish then
		dismount(r, "Eaten")
	end
	die(r, "Eaten", Config.Death.EatenTime, false)
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

local function openHook(r: Rider)
	if r.Fish then
		dismount(r, "Jump", true)
	end
	r.Token += 1
	setState(r, "Hooking")
	r.HookEnds = now() + Config.Grapple.AimTime
	r.Player:SetAttribute("HookEnds", r.HookEnds)
end

local function land(r: Rider, token: number, w: Wild)
	if r.Token ~= token or (r.State ~= "Dashing" and r.State ~= "Grappling") then
		FishService.unreserve(w, r.Player)
		return
	end
	if not mount(r, w, true) then
		-- the fish went away under us (not the player's fault): back to Free, not a miss
		FishService.unreserve(w, r.Player)
		setState(r, "Free")
		Net.Ride:FireClient(r.Player, "Dismounted", "Lost")
	end
end

-- The fish a move is aimed at, if it's a free wild fish within range (plus lag slack and half the fish's length)
local function checkTarget(r: Rider, action: string, target: any, range: number): Wild?
	local root = parts(r.Player)
	local w = FishService.get(if typeof(target) == "Instance" then target else nil)
	if not root or not w or w == r.Fish or not FishService.isFree(w, r.Player) then
		deny(r, action, "Target")
		return nil
	end
	local reach = range * Config.Net.RangeSlack + w.Type.Size.Z / 2
	if (w.Root.Position - root.Position).Magnitude > reach then
		deny(r, action, "Range")
		return nil
	end
	return w
end

local function startMove(r: Rider, w: Wild, state: string, time: number)
	FishService.reserve(w, r.Player)
	if r.Fish then
		dismount(r, state, true)
	end
	r.Token += 1
	local token = r.Token
	setState(r, state)
	task.delay(time, land, r, token, w)
end

local function dash(r: Rider, target: any)
	if r.State ~= "Riding" and r.State ~= "Free" then
		return deny(r, "Dash", "State")
	end
	if os.clock() < r.DashReadyAt then
		return deny(r, "Dash", "Cooldown")
	end
	local w = checkTarget(r, "Dash", target, Config.Dash.Range)
	if not w then
		return
	end
	local d = Config.Dash
	startMove(r, w, "Dashing", d.Duration)
	Net.Ride:FireClient(r.Player, "DashStart", w.Model, d.Duration)
	Net.Fx:FireAllClients("Dash", r.Player, w.Model, d.Duration)
end

-- The one shot of the hook window. Anything but a good shot on a free fish in range is a miss.
local function grapple(r: Rider, target: any)
	if r.State ~= "Hooking" then
		return deny(r, "Grapple", "State")
	end
	local w = checkTarget(r, "Grapple", target, Config.Grapple.Range)
	if not w then
		return eaten(r)
	end
	local g = Config.Grapple
	startMove(r, w, "Grappling", g.FlyTime + g.ReelTime)
	Net.Ride:FireClient(r.Player, "GrappleStart", w.Model, g.FlyTime, g.ReelTime)
	Net.Fx:FireAllClients("Grapple", r.Player, w.Model, g.FlyTime, g.ReelTime)
end

local function drain(r: Rider, amount: number)
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
	elseif r.State == "Hooking" then
		-- no drain in the window; past its end (and the lag slack) it's a miss
		local ends = r.HookEnds
		if not ends or now() > ends + Config.Grapple.Slack then
			eaten(r)
		end
	elseif r.State == "Free" then
		drain(r, o.FreeDrain * dt)
		if r.Oxygen <= 0 then
			drown(r)
		else
			local flat = if dockSpawn then (root.Position - dockSpawn.Position) * Vector3.new(1, 0, 1) else nil
			if flat and flat.Magnitude < o.DockRadius and root.Position.Y > o.SurfaceY - 2 then
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
	r.Fish = nil
	r.Weld = nil
	r.Oxygen = r.Max
	sendOxygen(r, true)
	setState(r, "Dock")
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
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
		HookEnds = nil,
		Token = 0,
		DashReadyAt = 0,
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

function RideService.Init()
	Net.Action.OnServerEvent:Connect(function(player, action, target)
		local r = riders[player]
		if not r or type(action) ~= "string" then
			return
		end
		if action == "JumpOff" then
			if r.State == "Riding" or r.State == "Free" then
				openHook(r)
			end
		elseif action == "Dash" then
			dash(r, target)
		elseif action == "Grapple" then
			grapple(r, target)
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
