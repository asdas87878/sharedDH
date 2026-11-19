--!strict
-- The trainer on every plot (TrainService; Hugo, 2026-11-19, task h1, docs/design/trainer.md): the toy Seahorse on a
-- grey coil over a small red pad. On every machine: a ride with a rider rocks (nose down and up about the pad, a little
-- dip at each end), the coil bending with it, and the rider goes with it (the server welds them to the toy's body, and
-- the toy is moved here, so the rider's rock is the toy's exactly); a rider who has just been seated is carried up onto
-- the seat in a hop (the weld's C0, here only); a hop's landing makes the spring give and bounce back. For our own
-- player: jump, or walk, and we ask to get off (Remotes.Trainer "Off"), then hop off along an arc (ours to move: the
-- character is ours, so everyone sees it); and every half second the server
-- tells us the Oxygen we gained ("Gain"), shown as a "+n" with the HUD's Oxygen picture near us on screen.
-- Only rides near the camera move. Numbers in RideStyles.Trainer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local RideStyles = require(ReplicatedStorage.Shared.RideStyles)
local Kit = require(script.Parent.Parent.UI.Kit)

local TrainerController = {}

local SEE = 260 -- studs: rides further than this from the camera are left alone
local LOOK_EVERY = 0.5
local T = RideStyles.Trainer

type Hop = { Weld: Weld, From: CFrame, To: CFrame, At: number }
type Ride = {
	Model: Model,
	Body: BasePart,
	Rest: CFrame,
	Base: CFrame,
	Top: CFrame,
	Side: Vector3,
	Coil: { BasePart },
	Lengths: { number },
	CapTop: BasePart?,
	Amp: number,
	Phase: number,
	BounceAt: number,
	BounceBy: number,
	Had: boolean,
	Moved: boolean,
	Hop: Hop?,
	Seen: { [Weld]: boolean },
}

local rides: { Ride } = {}

-- The clock everything here runs on. In Studio the workspace's "TrainerClock" (a number) holds it, so a capture can
-- step it frame by frame (tools/studio/trainer_capture.py); otherwise os.clock().
local function clock(): number
	if RunService:IsStudio() then
		local held = workspace:GetAttribute("TrainerClock")
		if type(held) == "number" then
			return held
		end
	end
	return os.clock()
end

local function held(): boolean
	return RunService:IsStudio() and type(workspace:GetAttribute("TrainerClock")) == "number"
end
local lookedAt = -math.huge
local complete = false
local lastRoot: { [BasePart]: CFrame } = {}

local function gather()
	table.clear(rides)
	complete = true
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local plots = dock and dock:FindFirstChild("Plots")
	if not plots then
		complete = false
		return
	end
	for _, plot in plots:GetChildren() do
		local model = plot:FindFirstChild("TrainerRide")
		local spring = plot:FindFirstChild("TrainerSpring")
		local toy = model and model:FindFirstChild("Toy")
		local body = toy and toy:FindFirstChild("Body")
		if not (model and model:IsA("Model")) then
			continue
		end
		local base, top = model:GetAttribute("SpringBase"), model:GetAttribute("SpringTop")
		if
			typeof(base) ~= "CFrame"
			or typeof(top) ~= "CFrame"
			or not (spring and spring:IsA("Model"))
			or not (body and body:IsA("BasePart"))
		then
			-- (the server hasn't made this one over yet, or it hasn't reached us)
			complete = false
			continue
		end
		local coil: { BasePart } = {}
		local k = 1
		while true do
			local piece = spring:FindFirstChild("Coil" .. k)
			if not (piece and piece:IsA("BasePart")) then
				break
			end
			coil[k] = piece
			k += 1
		end
		local lengths = table.create(#coil)
		for i, piece in coil do
			lengths[i] = piece.Size.Z
		end
		local cap = spring:FindFirstChild("CapTop")
		table.insert(rides, {
			Model = model,
			Body = body,
			Rest = model:GetPivot(),
			Base = base,
			Top = top,
			Side = base.RightVector,
			Coil = coil,
			Lengths = lengths,
			CapTop = if cap and cap:IsA("BasePart") then cap else nil,
			Amp = 0,
			Phase = 0,
			BounceAt = -math.huge,
			BounceBy = 0,
			Had = false,
			Moved = false,
			Hop = nil,
			Seen = {},
		})
	end
end

local function bounce(ride: Ride, by: number)
	ride.BounceAt = clock()
	ride.BounceBy = by
end

-- A newly seated rider: carried from where they stood (last frame, before the weld pulled them) up onto the seat
local function watchWelds(ride: Ride, now: number)
	for _, child in ride.Body:GetChildren() do
		if child:IsA("Weld") and child.Name == "TrainerWeld" and not ride.Seen[child] then
			ride.Seen[child] = true
			local root = child.Part1
			local before = if root then lastRoot[root] else nil
			if before then
				ride.Hop = { Weld = child, From = ride.Body.CFrame:ToObjectSpace(before), To = child.C0, At = now }
			end
		end
	end
	for weld in ride.Seen do
		if weld.Parent == nil then
			ride.Seen[weld] = nil
		end
	end
end

local function hopStep(ride: Ride, now: number)
	local hop = ride.Hop
	if not hop then
		return
	end
	if hop.Weld.Parent == nil then
		ride.Hop = nil
		return
	end
	local s = math.clamp((now - hop.At) / T.HopOn, 0, 1)
	if s >= 1 then
		hop.Weld.C0 = hop.To
		ride.Hop = nil
		bounce(ride, T.Bounce)
		return
	end
	-- quick off the ground, eased into the seat, over an arc
	local e = 1 - (1 - s) * (1 - s)
	local lift = math.sin(s * math.pi) * T.HopArc
	hop.Weld.C0 = CFrame.new(0, lift, 0) * hop.From:Lerp(hop.To, e)
end

local function place(ride: Ride, rock: CFrame)
	ride.Model:PivotTo(rock * ride.Rest)
	local top = rock * ride.Top
	for i, piece in RideStyles.coil(ride.Base, top) do
		local part = ride.Coil[i]
		if part then
			part.CFrame = piece.At
			if math.abs(piece.Length - ride.Lengths[i]) > 0.02 then
				ride.Lengths[i] = piece.Length
				part.Size = Vector3.new(T.Wire, T.Wire, piece.Length)
			end
		end
	end
	if ride.CapTop then
		ride.CapTop.CFrame = top * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
	end
end

local lastNow = clock()
local stepPops: (now: number) -> () = function() end
local stepOwn: (now: number, dt: number) -> () = function() end

local function step()
	local now = clock()
	local dt = math.clamp(now - lastNow, 0, 0.1)
	lastNow = now
	stepPops(now)
	stepOwn(now, dt)
	if not complete and now - lookedAt >= LOOK_EVERY then
		-- (the map's parts, and the server's making over of them, may arrive after we start)
		lookedAt = now
		gather()
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	for _, ride in rides do
		if not ride.Model.Parent then
			complete = false
			continue
		end
		local seated = ride.Model:GetAttribute("Rider") ~= nil
		watchWelds(ride, now)
		hopStep(ride, now)
		if seated ~= ride.Had then
			ride.Had = seated
			if not seated then
				-- (the rider's weight is off: it springs up)
				bounce(ride, -T.Bounce * 0.6)
			end
		end
		if (ride.Base.Position - eye).Magnitude > SEE then
			continue
		end
		ride.Amp += ((if seated then 1 else 0) - ride.Amp) * math.min(1, dt * T.Ease)
		local since = now - ride.BounceAt
		local give = 0
		if since < 3 then
			give = ride.BounceBy * math.exp(-T.BounceDamp * since) * math.cos(since * T.BounceRate * math.pi * 2)
		end
		if ride.Amp > 0.002 or math.abs(give) > 0.002 then
			ride.Phase = (ride.Phase + dt * T.Beat * math.pi * 2) % (math.pi * 2)
			local swing = math.sin(ride.Phase)
			local tilt = math.rad(T.Swing) * swing * ride.Amp
			local dip = T.Dip * swing * swing * ride.Amp + give
			local foot = ride.Base.Position
			local rock = CFrame.new(0, -dip, 0)
				* CFrame.new(foot)
				* CFrame.fromAxisAngle(ride.Side, tilt)
				* CFrame.new(-foot)
			place(ride, rock)
			ride.Moved = true
		elseif ride.Moved then
			ride.Phase = 0
			place(ride, CFrame.new())
			ride.Moved = false
		end
	end
	-- where every character's root was this frame, for the next seat's hop
	table.clear(lastRoot)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			lastRoot[root] = root.CFrame
		end
	end
end

-- ---------------------------------------------------------------- the "+n" pops
-- Each pop springs up at a random spot round us, drifts up and fades: moved here frame by frame on the clock (not
-- tweened), so a held clock holds them too.
type Pop = { Group: CanvasGroup, Grow: UIScale, X: number, Y: number, Rise: number, Tilt: number, Born: number }

local POP_LIFE = 1.15
local POP_FADE = 0.5 -- the fade starts this long in
local AIR = Kit.palOf(Kit.Aqua)

local gui: ScreenGui? = nil
local live: { Pop } = {}

local function popsGui(): ScreenGui
	if gui and gui.Parent then
		return gui
	end
	local made = Instance.new("ScreenGui")
	made.Name = "TrainerPops"
	made.ResetOnSpawn = false
	made.IgnoreGuiInset = true
	made.DisplayOrder = 4
	made.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = made
	return made
end

local function amountText(n: number): string
	if n < 10 then
		local text = string.format("%.1f", n)
		return (string.gsub(text, "%.0$", ""))
	end
	return Kit.short(n)
end

local function pop(amount: number)
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	local camera = workspace.CurrentCamera
	if not (head and head:IsA("BasePart") and camera) then
		return
	end
	local at, visible = camera:WorldToViewportPoint(head.Position)
	if not visible then
		return
	end
	local scale = math.clamp(camera.ViewportSize.Y / 720, 0.75, 1.6)
	local size = math.floor(30 * scale)
	local icon = math.floor(size * 1.35)
	local group = Instance.new("CanvasGroup")
	group.Name = "Pop"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	local word = Kit.word(group, {
		Text = "+" .. amountText(amount),
		TextSize = size,
		Pal = AIR,
		Glow = true,
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 2,
	})
	local pad = 8
	group.Size = UDim2.fromOffset(pad + icon + 2 + word.wide + pad, math.max(icon, word.high) + pad * 2)
	word.root.Position = UDim2.new(0, pad + icon + 2, 0.5, 0)
	local picture = Instance.new("ImageLabel")
	picture.Name = "Oxygen"
	picture.BackgroundTransparency = 1
	picture.Image = Kit.Textures.Oxygen
	picture.ScaleType = Enum.ScaleType.Fit
	picture.AnchorPoint = Vector2.new(0, 0.5)
	picture.Position = UDim2.new(0, pad, 0.5, 0)
	picture.Size = UDim2.fromOffset(icon, icon)
	picture.Parent = group
	local grow = Instance.new("UIScale")
	grow.Scale = 0.35
	grow.Parent = group
	-- a random spot round the player, mostly above and to either side
	local p: Pop = {
		Group = group,
		Grow = grow,
		X = at.X + (math.random() * 2 - 1) * 150 * scale,
		Y = at.Y - (40 + math.random() * 110) * scale,
		Rise = 80 * scale,
		Tilt = (math.random() * 2 - 1) * 8,
		Born = clock(),
	}
	group.Position = UDim2.fromOffset(p.X, p.Y)
	group.Rotation = p.Tilt
	group.Parent = popsGui()
	table.insert(live, p)
end

-- an overshoot, as Enum.EasingStyle.Back out
local function backOut(s: number): number
	local c = 1.70158
	local u = s - 1
	return 1 + (c + 1) * u * u * u + c * u * u
end

stepPops = function(now: number)
	for i = #live, 1, -1 do
		local p = live[i]
		local age = now - p.Born
		if age >= POP_LIFE or age < 0 then
			p.Group:Destroy()
			table.remove(live, i)
			continue
		end
		local s = age / POP_LIFE
		p.Grow.Scale = 0.35 + 0.65 * backOut(math.min(1, age / 0.16))
		p.Group.Position = UDim2.fromOffset(p.X, p.Y - p.Rise * (1 - (1 - s) * (1 - s)))
		p.Group.Rotation = p.Tilt * (1 - 0.7 * s)
		local f = math.clamp((age - POP_FADE) / (POP_LIFE - POP_FADE), 0, 1)
		p.Group.GroupTransparency = f * f
	end
end

-- ---------------------------------------------------------------- our own seat
type Off = { From: Vector3, To: Vector3, Away: Vector3, At: number }

local function listen()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:WaitForChild("Trainer", 30)
	if not (remote and remote:IsA("RemoteEvent")) then
		return
	end
	local player = Players.LocalPlayer
	local onAt = -math.huge
	local seated: Model? = nil
	local asked = false
	local movedFor = 0
	local hopOff: Off? = nil
	local lastGain = 0
	local popAt = 0

	local function humanoidOf(): Humanoid?
		local character = player.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end

	local function rootOf(): BasePart?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end

	local function ask()
		if seated and not asked and clock() - onAt > T.HopOn * 0.8 then
			asked = true
			remote:FireServer("Off")
		end
	end

	remote.OnClientEvent:Connect(function(what: string, a: any, b: any)
		if what == "On" then
			seated = a
			onAt = clock()
			popAt = onAt + T.Every
			asked = false
			movedFor = 0
			hopOff = nil
			local humanoid = humanoidOf()
			if humanoid then
				humanoid.Sit = true
			end
		elseif what == "Off" then
			local was = seated
			seated = nil
			asked = false
			local humanoid = humanoidOf()
			local root = rootOf()
			if b == "Gone" or not humanoid or not root then
				return
			end
			humanoid.Sit = false
			-- the hop off: up and away, the way we steer, or else off the toy's side; landing where the floor is
			local away = humanoid.MoveDirection * Vector3.new(1, 0, 1)
			if away.Magnitude < 0.2 then
				local base = if was then was:GetAttribute("SpringBase") else nil
				away = if typeof(base) == "CFrame" then base.RightVector else root.CFrame.RightVector
			end
			away = away.Unit
			local reach = T.OffReach
			local to = root.Position + away * reach
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { player.Character :: Model, was :: any }
			local hit = workspace:Raycast(to + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
			local stand = humanoid.HipHeight + root.Size.Y / 2
			if hit then
				to = Vector3.new(to.X, hit.Position.Y + stand, to.Z)
			end
			hopOff = { From = root.Position, To = to, Away = away, At = clock() }
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		elseif what == "Gain" and type(a) == "number" then
			lastGain = a
			if not held() then
				pop(a)
			end
		end
	end)

	UserInputService.JumpRequest:Connect(ask)
	stepOwn = function(now: number, dt: number)
		local humanoid = humanoidOf()
		local root = rootOf()
		if hopOff and humanoid and root then
			-- the hop off, carried along its arc here (so a held clock holds it), then let go onto the floor
			local s = math.clamp((now - hopOff.At) / T.OffTime, 0, 1)
			local at = hopOff.From:Lerp(hopOff.To, s) + Vector3.new(0, math.sin(s * math.pi) * T.OffRise, 0)
			root.CFrame = CFrame.lookAt(at, at + hopOff.Away)
			root.AssemblyLinearVelocity = Vector3.zero
			if s >= 1 then
				hopOff = nil
				humanoid:ChangeState(Enum.HumanoidStateType.Landed)
			end
		end
		if not seated or not humanoid then
			return
		end
		-- in a held clock the server's gains come in real time: shown on the clock's own beat instead
		if held() and now >= popAt then
			popAt = now + T.Every
			if lastGain > 0 then
				pop(lastGain)
			end
		end
		-- (a seated humanoid still says where we steer)
		if humanoid.MoveDirection.Magnitude > 0.3 then
			movedFor += dt
			if movedFor > 0.12 then
				ask()
			end
		else
			movedFor = 0
		end
		-- (the Sit is ours to keep while seated: a jump press takes it, before the server hears)
		if not asked and not humanoid.Sit then
			humanoid.Sit = true
		end
	end
end

function TrainerController.Start()
	RunService.Heartbeat:Connect(step)
	task.spawn(listen)
end

return TrainerController
