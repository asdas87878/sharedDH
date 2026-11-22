--!strict
-- Riding a fish in our own tank (Hugo, 2026-11-20, task k1; Config.TankRide; the server's side, TankRideService), and
-- since task b4 (Hugo, 2026-11-22: "use same floating animation when swimming in aquarium, make player be able to swim
-- on the fish in the aquarium without oxygen limit while being in full control. This should be done by holding E for a
-- little second while looking at desired fish"):
--   Getting on: on the dock, near our tank, the fish of OUR tank that the look passes over (the mouse; the middle of
--   the screen on a pad or a phone) is outlined and carries a small ring with the key on it. Holding E (a pad's X, the
--   RIDE button on a phone) fills the ring over TankRide.Hold seconds, then asks the server: Action "TankRide", "On",
--   that fish. Letting go, or looking away, empties it.
--   Riding: the server puts us on the fish and gives it to us to move ("TankMounted", fish, box, half); here we move
--   its movers' targets before every physics step. Full control: W (the stick forward) swims, S backs, nothing held
--   floats on the spot, rising and sinking a little; A and D turn, and the view turns with us; the fish comes round to
--   the way the camera looks, up and down too. The fish keeps its real size, so it is our SEAT (its Saddle) that is
--   kept inside the box (the water, less a margin): a big fish goes through the glass, we never do. Roblox's own
--   camera is kept (we are on the dock), held far enough back to be outside a giant.
--   Getting off: E again (X, the OFF button): Action "TankRide", "Off".
--   The swim: every tank's fish near the camera, in its lap or ridden, moves its joints through the sea's own keyed
--   swim (AnimController's base cycle, the beat by its speed and length; a stand-in's tail beat, sway and fin flaps).
--   AnimController itself only animates Workspace.Fish and LandFish, so a tank's fish swam stiff until now.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local RideStyles = require(ReplicatedStorage.Shared.RideStyles)
local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Parent.UI.Kit)
local TankPanel = require(script.Parent.Parent.UI.TankPanel)
local RideController = require(script.Parent.RideController)

local TankRideController = {}

local TAG = "TankFish"
local ON_ACTION = "TankRideOn"
local OFF_ACTION = "TankRideOff"
local TAU = math.pi * 2

type Riding = {
	Fish: Model,
	Root: BasePart,
	Align: AlignPosition,
	Turn: AlignOrientation,
	Box: CFrame,
	Half: Vector3,
	Centre: CFrame, -- the fish's middle (what the mover moves) in its Root,
	Seat: Vector3, -- from the fish's middle (what the mover moves) to the seat, in the fish's own directions
	At: Vector3, -- where the fish's middle is going: moved each frame, the seat kept in the box
	Yaw: number,
	Pitch: number,
	Speed: number,
	Zoom: { number }?, -- our own zoom limits, to give back
}

local riding: Riding? = nil
local hint: ScreenGui? = nil

function TankRideController.riding(): boolean
	return riding ~= nil
end

local function anglesOf(look: Vector3): (number, number)
	return math.atan2(-look.X, -look.Z), math.asin(math.clamp(look.Y, -1, 1))
end

------------------------------------------------------------------------------------------------------------------
-- The swim of every tank's fish
------------------------------------------------------------------------------------------------------------------
type Joint = { motor: Motor6D, frames: { CFrame }, jaw: boolean }
type Swim = {
	root: BasePart,
	rig: { Joint }?,
	sway: Motor6D?,
	tail: Motor6D?,
	finL: Motor6D?,
	finR: Motor6D?,
	phase: number,
	seed: number,
	beat: number, -- a long fish beats slower
	cadence: number,
	rate: number,
	speed: number,
	was: Vector3,
	at: number,
}

local swims: { [Model]: Swim } = {}
local waiting: { [Model]: number } = {} -- a model whose joints have not all come yet: when it was first tried
local retryAt: { [Model]: number } = {}

local function joint(model: Model, name: string): Motor6D?
	local found = model:FindFirstChild(name, true)
	if found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) then
		return (found :: any) :: Motor6D
	end
	return nil
end

local function swimOf(model: Model, root: BasePart, now: number): Swim?
	local again = retryAt[model]
	if again and now < again then
		return nil
	end
	local id = model:GetAttribute("Rig")
	local rig = if type(id) == "string" then Creatures.get(id) else nil
	local keys = if rig and type(id) == "string" then Creatures.swim(id) else nil
	local list: { Joint }? = nil
	local cadence = 1
	if rig and keys then
		local made: { Joint } = {}
		local keyed = 0
		for part, frames in keys do
			keyed += 1
			local motor = joint(model, "Rig_" .. part)
			if motor then
				table.insert(made, { motor = motor, frames = frames, jaw = string.find(part, "Jaw") ~= nil })
			end
		end
		if #made < keyed then
			-- (still arriving: its parts can come over more than one frame; after five seconds, make do)
			local since = waiting[model] or now
			waiting[model] = since
			if now - since < 5 then
				retryAt[model] = now + 0.2
				return nil
			end
		end
		list = made
		local style = RideStyles.of(id :: string)
		cadence = if style then Ease.lerp(1, style.Cadence, math.clamp(Config.Animation.Cadence, 0, 1)) else 1
	end
	waiting[model] = nil
	retryAt[model] = nil
	local kind = Config.FishById[tostring(model:GetAttribute("FishType"))]
	local length = if kind then kind.Size.Z * Config.sizeScale(Config.sizeTierOf(model), kind) else 14
	return {
		root = root,
		rig = list,
		sway = if list then nil else joint(model, "SwayJoint"),
		tail = if list then nil else joint(model, "TailJoint"),
		finL = if list then nil else joint(model, "FinL"),
		finR = if list then nil else joint(model, "FinR"),
		phase = math.random() * 10,
		seed = math.random() * 100,
		beat = math.clamp(14 / math.max(length, 1), 0.4, 1.1),
		cadence = cadence,
		rate = 0,
		speed = 0,
		was = root.Position,
		at = now,
	}
end

local tracked: { [Model]: boolean } = {}

local function animate()
	if Config.TankRide.Swim == 0 or not next(tracked) then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local a = Config.Animation
	local eye = camera.CFrame.Position
	local far = Config.Aquarium.SeeFrom
	local now = os.clock()
	local ridden = if riding then riding.Fish else nil
	for model in tracked do
		local root = model.PrimaryPart
		if not model.Parent or not model:IsDescendantOf(workspace) then
			tracked[model] = nil
			swims[model] = nil
			waiting[model] = nil
			retryAt[model] = nil
			continue
		end
		if not root or (root.Position - eye).Magnitude > far then
			continue
		end
		local s = swims[model]
		if not s then
			local made = swimOf(model, root, now)
			if not made then
				continue
			end
			s = made
			swims[model] = made
		end
		local gap = now - s.at
		s.at = now
		local dt = math.min(gap, 0.1)
		if dt <= 0 then
			continue
		end
		-- how fast it goes: off its Root's own movement (a lap's fish is anchored and placed each frame, so it has no
		-- speed of its own to read). One that was out of view starts afresh
		local at = root.Position
		local speed = if gap > 0.3 then s.speed else math.min((at - s.was).Magnitude / dt, 200)
		s.was = at
		s.speed = Ease.lerp(s.speed, speed, Ease.alpha(6, dt))
		speed = s.speed
		local rig = s.rig
		if rig then
			-- the beat: by speed and length and the style's cadence, never changing at once (AnimController's)
			local rate = (0.5 + speed * 0.03) * s.beat * a.Beat * s.cadence
			s.rate = if s.rate > 0 then Ease.lerp(s.rate, rate, Ease.alpha(4, dt)) else rate
			s.phase += dt * TAU * s.rate
			local u = (s.phase / TAU) % 1
			-- a jaw hangs nearly shut and opens now and then
			local jawOpen = if a.Jaw > 0 then 0.15 + 0.85 * math.max(0, math.sin(now * 0.8 + s.seed)) ^ 4 else 1
			for _, r in rig do
				local count = #r.frames
				local turn = r.frames[1]
				if count > 1 then
					local f = u * count
					local i = math.floor(f)
					turn = r.frames[i % count + 1]:Lerp(r.frames[(i + 1) % count + 1], f - i)
					if r.jaw and jawOpen < 0.97 then
						local axis, angle = turn:ToAxisAngle()
						turn = CFrame.fromAxisAngle(axis, angle * jawOpen)
					end
				end
				r.motor.Transform = turn
			end
		else
			-- a stand-in: the tail beat, the sway and the fin flaps
			s.phase += dt * TAU * (0.7 + speed * 0.045)
			local beat = math.sin(s.phase)
			local amount = math.rad(18 + math.min(speed, 80) * 0.12)
			if s.tail then
				s.tail.Transform = CFrame.Angles(0, beat * amount, 0)
			end
			if s.sway then
				s.sway.Transform = CFrame.Angles(0, math.sin(s.phase - 1.2) * amount * 0.22, 0)
			end
			local flap = math.sin(s.phase * 0.5) * math.rad(18)
			if s.finL then
				s.finL.Transform = CFrame.Angles(0, 0, -flap)
			end
			if s.finR then
				s.finR.Transform = CFrame.Angles(0, 0, flap)
			end
		end
	end
	-- (the fish we ride has lost its tag, and is kept while it is in the world)
	if ridden and not tracked[ridden] then
		tracked[ridden] = true
	end
end

------------------------------------------------------------------------------------------------------------------
-- Getting on: look at a fish of our own tank, hold E
------------------------------------------------------------------------------------------------------------------
type Mark = { Gui: BillboardGui, Sweep: Kit.Sweep, Key: TextLabel, Light: Highlight }

local aimed: Model? = nil -- the fish of our tank the look is on
local bound = false
local holding: Model? = nil
local heldSince = 0
local askedAt = -math.huge
local mark: Mark? = nil
local aimAt = 0
-- (Studio's tests: a look given by hand, as a screen point; and E held by hand)
local pretendLook: Vector2? = nil

local function ownShown(): (Instance?, BasePart?)
	local name = State.Player:GetAttribute("Plot")
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local plots = dock and dock:FindFirstChild("Plots")
	local plot = plots and type(name) == "string" and plots:FindFirstChild(name)
	local water = plot and plot:FindFirstChild("TankWater")
	return if plot then plot:FindFirstChild(TAG) else nil, if water and water:IsA("BasePart") then water else nil
end

local function keyName(): string
	local last = UserInputService:GetLastInputType()
	if Kit.touch() then
		return "RIDE"
	elseif string.match(last.Name, "^Gamepad") then
		return "X"
	end
	return "E"
end

local function markOn(model: Model?, fraction: number)
	if not model or not model.PrimaryPart then
		if mark then
			mark.Gui.Enabled = false
			mark.Gui.Adornee = nil
			mark.Light.Adornee = nil
			mark.Light.Enabled = false
		end
		return
	end
	local m = mark
	if not m then
		local gui = Instance.new("BillboardGui")
		gui.Name = "TankRideMark"
		gui.AlwaysOnTop = true
		gui.ResetOnSpawn = false
		gui.Size = UDim2.fromOffset(150, 96)
		gui.LightInfluence = 0
		local disc: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(54, 54),
			BackgroundColor3 = Kit.Ink,
			BackgroundTransparency = 0.25,
		}, gui)
		Kit.corner(disc, 999)
		local track = Kit.sweep(disc, 54, 6, Color3.new(1, 1, 1))
		track.fade(0.75)
		local sweep = Kit.sweep(disc, 54, 6, Color3.fromRGB(110, 235, 255))
		local key = Kit.text({
			Size = UDim2.fromScale(1, 1),
			TextSize = 26,
			ZIndex = 3,
		}, disc)
		Kit.text({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 64),
			Size = UDim2.fromOffset(150, 24),
			TextSize = 18,
			Text = "HOLD TO RIDE",
		}, gui)
		local light = Instance.new("Highlight")
		light.Name = "TankRideLight"
		light.FillTransparency = 1
		light.OutlineColor = Color3.new(1, 1, 1)
		light.OutlineTransparency = 0
		light.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		local into = State.Player:WaitForChild("PlayerGui")
		gui.Parent = into
		light.Parent = workspace
		m = { Gui = gui, Sweep = sweep, Key = key, Light = light }
		mark = m
	end
	local name = keyName()
	m.Key.Text = name
	m.Key.TextSize = if #name > 1 then 15 else 26
	m.Gui.Adornee = model.PrimaryPart
	m.Gui.Enabled = true
	m.Light.Adornee = model
	m.Light.Enabled = true
	m.Sweep.set(fraction)
end

-- The fish of our tank the look passes over: of those whose body (its box, Aim studs fatter) the ray meets, the one whose middle it passes nearest
local function lookedAt(): Model?
	local c = Config.TankRide
	local camera = workspace.CurrentCamera
	local shown, water = ownShown()
	local _, root = State.character()
	if not camera or not shown or not water or not root then
		return nil
	end
	-- (near our tank, as the server asks)
	local offset = water.CFrame:PointToObjectSpace(root.Position)
	local half = water.Size / 2
	local dx = math.max(math.abs(offset.X) - half.X, 0)
	local dz = math.max(math.abs(offset.Z) - half.Z, 0)
	if math.sqrt(dx * dx + dz * dz) > c.Reach then
		return nil
	end
	local point = pretendLook
	if not point then
		local last = UserInputService:GetLastInputType()
		if Kit.touch() or string.match(last.Name, "^Gamepad") then
			point = camera.ViewportSize / 2
		else
			point = UserInputService:GetMouseLocation()
		end
	end
	local ray = camera:ViewportPointToRay((point :: Vector2).X, (point :: Vector2).Y)
	local best, found = math.huge, nil
	for _, model in shown:GetChildren() do
		if not model:IsA("Model") or not model.PrimaryPart or not CollectionService:HasTag(model, TAG) then
			continue
		end
		local kind = Config.FishById[tostring(model:GetAttribute("FishType"))]
		if not kind then
			continue
		end
		local size = kind.Size * Config.sizeScale(Config.sizeTierOf(model), kind) / 2 + Vector3.one * c.Aim
		local frame = model.PrimaryPart.CFrame
		local o = frame:PointToObjectSpace(ray.Origin)
		local d = frame:VectorToObjectSpace(ray.Direction)
		-- the ray against the box, side by side
		local near, away = 0, math.huge
		for _, axis in { "X", "Y", "Z" } do
			local oa, da, ha = (o :: any)[axis], (d :: any)[axis], (size :: any)[axis]
			if math.abs(da) < 1e-6 then
				if math.abs(oa) > ha then
					near = math.huge
					break
				end
			else
				local t1, t2 = (-ha - oa) / da, (ha - oa) / da
				near = math.max(near, math.min(t1, t2))
				away = math.min(away, math.max(t1, t2))
			end
		end
		-- (of those the look passes through, the one whose middle it passes nearest: a giant fills the tank and
		-- more, and a fish in front of it or inside it must still be picked; the giant itself by looking at its middle)
		local along = math.max(-o:Dot(d), 0)
		local miss = (o + d * along).Magnitude
		if near <= away and miss < best then
			best, found = miss, model
		end
	end
	return found
end

local function onKey(_name: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		if aimed and not riding then
			holding = aimed
			heldSince = os.clock()
			return Enum.ContextActionResult.Sink
		end
	else
		holding = nil
	end
	return Enum.ContextActionResult.Pass
end

local function bind(on: boolean)
	if on == bound then
		return
	end
	bound = on
	if on then
		ContextActionService:BindAction(ON_ACTION, onKey, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle(ON_ACTION, "Ride")
	else
		ContextActionService:UnbindAction(ON_ACTION)
		holding = nil
	end
end

local function aim()
	local now = os.clock()
	local can = riding == nil
		and Config.TankRide.On ~= 0
		and State.Mode == "Dock"
		and State.Player:GetAttribute("TankRide") == nil
		and State.Player:GetAttribute("TrainerRide") == nil
		and now - askedAt > 0.8
		and not TankPanel.isOpen()
		and not UserInputService:GetFocusedTextBox()
	if not can then
		aimed = nil
	elseif now - aimAt >= 0.05 then
		-- (looked for twenty times a second; while E is held on a fish it is kept as long as the look stays on it)
		aimAt = now
		aimed = lookedAt()
	end
	if holding and holding ~= aimed then
		holding = nil
	end
	bind(aimed ~= nil)
	local fraction = 0
	if holding then
		fraction = math.clamp((now - heldSince) / math.max(Config.TankRide.Hold, 0.05), 0, 1)
		if fraction >= 1 then
			Net.Action:FireServer("TankRide", "On", holding)
			askedAt = now
			holding = nil
			aimed = nil
			bind(false)
		end
	end
	markOn(aimed, fraction)
end

------------------------------------------------------------------------------------------------------------------
-- Riding
------------------------------------------------------------------------------------------------------------------
local controls: any = nil

-- Forward and back: W and S (the arrows), or the stick: 1 forward, -1 back
local function forward(): number
	if UserInputService:GetFocusedTextBox() then
		return 0
	end
	if UserInputService.KeyboardEnabled then
		local z = (
			if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then 1 else 0
		)
			- (
				if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)
					then 1
					else 0
			)
		if z ~= 0 or UserInputService:GetLastInputType() == Enum.UserInputType.Keyboard then
			return z
		end
	end
	if controls then
		local ok, v = pcall(controls.GetMoveVector, controls)
		if ok and typeof(v) == "Vector3" then
			return math.clamp(-v.Z, -1, 1)
		end
	end
	return 0
end
-- (Studio's tests: the keys held by hand; nil: the real ones)
local pretendForward: number? = nil

local function showHint(on: boolean)
	if not on then
		if hint then
			hint:Destroy()
			hint = nil
		end
		return
	end
	if hint then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TankRideHint"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -110)
	label.Size = UDim2.fromOffset(420, 34)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextSize = 28
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(10, 12, 22)
	label.TextStrokeTransparency = 0
	local name = keyName()
	label.Text = if name == "RIDE" then "" else name .. " TO GET OFF"
	label.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	hint = gui
end

local function off(_name: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and riding then
		Net.Action:FireServer("TankRide", "Off")
	end
	return Enum.ContextActionResult.Sink
end

local function stop()
	local r = riding
	riding = nil
	ContextActionService:UnbindAction(OFF_ACTION)
	showHint(false)
	if r and r.Zoom then
		local player = Players.LocalPlayer
		player.CameraMaxZoomDistance = r.Zoom[2]
		player.CameraMinZoomDistance = r.Zoom[1]
	end
end

local function mounted(fish: Model, box: CFrame, half: Vector3)
	local root = fish.PrimaryPart
	local align = root and root:WaitForChild("TankAlign", 3)
	local turn = root and root:WaitForChild("TankTurn", 3)
	local saddle = root and root:FindFirstChild("Saddle")
	local center = root and root:FindFirstChild("Center")
	if not root or not align or not align:IsA("AlignPosition") or not turn or not turn:IsA("AlignOrientation") then
		return
	end
	if riding then
		stop()
	end
	local c = Config.TankRide
	local yaw = anglesOf(root.CFrame.LookVector)
	local seat = if saddle
			and saddle:IsA("Attachment")
			and center
			and center:IsA("Attachment")
		then saddle.Position - center.Position
		else Vector3.zero
	-- the view behind the fish, far enough back to be outside it: our zoom may not come in closer while we ride
	local kind = Config.FishById[tostring(fish:GetAttribute("FishType"))]
	local long = if kind then kind.Size.Z * Config.sizeScale(Config.sizeTierOf(fish), kind) else 14
	local back = math.clamp(long * c.View, 14, c.ViewMost)
	local player = Players.LocalPlayer
	local zoom = { player.CameraMinZoomDistance, player.CameraMaxZoomDistance }
	player.CameraMaxZoomDistance = math.max(zoom[2], back + 40)
	player.CameraMinZoomDistance = math.max(zoom[1], back)
	riding = {
		Fish = fish,
		Root = root,
		Align = align,
		Turn = turn,
		Box = box,
		Half = half,
		Centre = if center and center:IsA("Attachment") then center.CFrame else CFrame.identity,
		Seat = seat,
		At = if center and center:IsA("Attachment") then center.WorldPosition else root.Position,
		Yaw = yaw,
		Pitch = 0,
		Speed = 0,
		Zoom = zoom,
	}
	tracked[fish] = true
	markOn(nil, 0)
	bind(false)
	-- (above everything else, while we ride)
	ContextActionService:BindActionAtPriority(
		OFF_ACTION,
		off,
		true,
		Enum.ContextActionPriority.High.Value + 10,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonX
	)
	ContextActionService:SetTitle(OFF_ACTION, "Off")
	showHint(true)
	local camera = workspace.CurrentCamera
	if camera then
		local look = root.CFrame.LookVector
		local focus = root.CFrame:PointToWorldSpace(seat)
		camera.CFrame = CFrame.lookAt(focus - look * back + Vector3.new(0, back * 0.4, 0), focus)
	end
end

local function step(dt: number)
	local r = riding
	if not r then
		return
	end
	if not r.Fish.Parent or not r.Align.Parent then
		stop()
		return
	end
	local c = Config.TankRide
	local camera = workspace.CurrentCamera
	-- A and D turn the view, and so the fish (it follows the view)
	local key = RideController.moveVector().X
	local turned = -key * math.rad(c.Turn) * dt
	if camera and turned ~= 0 then
		local focus = camera.Focus.Position
		camera.CFrame = CFrame.new(focus) * CFrame.Angles(0, turned, 0) * CFrame.new(-focus) * camera.CFrame
	end
	-- round to the way the camera looks; the camera's usual look down is level
	local look = if camera then camera.CFrame.LookVector else r.Root.CFrame.LookVector
	local wantYaw, wantPitch = anglesOf(look)
	wantPitch = math.clamp(wantPitch + math.rad(c.Level), -math.rad(c.Climb), math.rad(c.Climb))
	local k = Ease.alpha(c.Follow, dt)
	local dy = (wantYaw - r.Yaw + math.pi) % (2 * math.pi) - math.pi
	r.Yaw += dy * k
	r.Pitch += (wantPitch - r.Pitch) * k
	local way = CFrame.Angles(0, r.Yaw, 0) * CFrame.Angles(r.Pitch, 0, 0)
	-- W swims, S backs, nothing held floats on the spot: the speed comes in and stops over a moment
	local push = pretendForward or forward()
	local want = if push >= 0 then push * c.Speed else push * c.Speed * c.Back
	r.Speed += (want - r.Speed) * Ease.alpha(c.Ease, dt)
	-- our seat kept in the box: against the glass we slide along it (the fish's own body may go through)
	local seat = r.At + way.LookVector * r.Speed * dt + way:VectorToWorldSpace(r.Seat)
	local p = r.Box:PointToObjectSpace(seat)
	local h = r.Half
	p = Vector3.new(math.clamp(p.X, -h.X, h.X), math.clamp(p.Y, -h.Y, h.Y), math.clamp(p.Z, -h.Z, h.Z))
	r.At = r.Box:PointToWorldSpace(p) - way:VectorToWorldSpace(r.Seat)
	-- floating: it rises and sinks a little, less the faster it goes
	local still = 1 - math.clamp(math.abs(r.Speed) / math.max(c.Speed, 1), 0, 1)
	local target = r.At + Vector3.new(0, math.sin(os.clock() * 1.7) * c.Bob * still, 0)
	r.Align.Position = target
	-- (and its speed toward there, set as well: a still assembly sleeps, and a mover's new target alone does not
	-- always wake it; seen in Studio, the fish sat 32 studs from its target)
	local gap = target - (r.Root.CFrame * r.Centre).Position
	local most = c.Speed * 3
	local v = gap * 8
	r.Root.AssemblyLinearVelocity = if v.Magnitude > most then v.Unit * most else v
	-- (nose level when held at the surface or the sand)
	local pitch = r.Pitch
	if (p.Y >= h.Y and pitch > 0) or (p.Y <= -h.Y and pitch < 0) then
		pitch *= 0.3
	end
	r.Turn.CFrame = CFrame.Angles(0, r.Yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

-- Studio's tests (tools/studio/b4_tank_ride_check.py): what the look is on and how full the ring is; a look and a
-- held key given by hand
function TankRideController.aimed(): (Model?, number)
	local fraction = if holding
		then math.clamp((os.clock() - heldSince) / math.max(Config.TankRide.Hold, 0.05), 0, 1)
		else 0
	return aimed, fraction
end

function TankRideController.pretend(look: Vector2?, hold: boolean?, push: number?)
	pretendLook = look
	pretendForward = push
	if hold ~= nil then
		if hold then
			onKey(ON_ACTION, Enum.UserInputState.Begin)
		else
			onKey(ON_ACTION, Enum.UserInputState.End)
		end
	end
end

function TankRideController.pressOff()
	off(OFF_ACTION, Enum.UserInputState.Begin)
end

function TankRideController.speeds(): { [Model]: number }
	local out = {}
	for model, s in swims do
		out[model] = s.rate
	end
	return out
end

function TankRideController.Start()
	task.spawn(function()
		local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
		local module = scripts:WaitForChild("PlayerModule", 30)
		if module and module:IsA("ModuleScript") then
			local ok, made = pcall(function()
				return (require :: any)(module):GetControls()
			end)
			if ok then
				controls = made
			end
		end
	end)
	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any)
		if
			kind == "TankMounted"
			and typeof(a) == "Instance"
			and a:IsA("Model")
			and typeof(b) == "CFrame"
			and typeof(c) == "Vector3"
		then
			mounted(a, b, c)
		elseif kind == "TankDismounted" then
			stop()
		end
	end)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		if model:IsA("Model") then
			tracked[model] = true
		end
	end)
	for _, model in CollectionService:GetTagged(TAG) do
		if model:IsA("Model") then
			tracked[model] = true
		end
	end
	-- (before each physics step, not on the frame drawn: the fish keeps its speed however often the screen is drawn.
	-- Roblox's camera reads its own CFrame at the next frame, so the turn set here carries over)
	RunService.PreSimulation:Connect(function(dt: number)
		step(dt)
		animate()
	end)
	RunService.RenderStepped:Connect(aim)
	Players.LocalPlayer.CharacterAdded:Connect(stop)
end

return TankRideController
