--!strict
-- Riding on the client: steering the fish we own (the server hands us its network ownership on mount), the speed-up,
-- floating while off a fish, and the camera for everything underwater (a smooth chase camera whose field of view widens
-- with speed, slowed by the local time scale during the grapple's aim).
-- Steering: A/D or the stick's sideways turn, W dives, S climbs; nothing held levels off. Right mouse drag or a touch
-- drag looks round; the camera swings back behind the fish on its own.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local Zones = require(ReplicatedStorage.Shared.Zones)
local State = require(script.Parent.Parent.Lib.State)

local RideController = {}

local controls: any = nil
local camera = workspace.CurrentCamera

-- riding
local yaw, pitch, roll = 0, 0, 0
local startSpeed = 0
local rideType: Config.FishType? = nil

-- floating
local floatVelocity: LinearVelocity? = nil
local floatTurn: AlignOrientation? = nil
local poppedAt = -math.huge

-- camera
local camYaw, camPitch = 0, math.rad(-12)
local camPosition: Vector3? = nil
local camFocus: Vector3? = nil
local zoom = Config.Camera.Distance
local lookedAt = -math.huge -- os.clock() the player last looked round themselves
local rightHeld = false
local wasScripted = false

local function moveVector(): Vector3
	if controls then
		local ok, v = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok and typeof(v) == "Vector3" then
			return v
		end
	end
	return Vector3.zero
end

local function clearFloat()
	if floatVelocity then
		floatVelocity:Destroy()
		floatVelocity = nil
	end
	if floatTurn then
		floatTurn:Destroy()
		floatTurn = nil
	end
end

local function ensureFloat(root: BasePart)
	if floatVelocity and floatVelocity.Parent == root then
		return
	end
	clearFloat()
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChild("RootRigAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		local a = Instance.new("Attachment")
		a.Name = "FloatAttachment"
		a.Parent = root
		attachment = a
	end
	local v = Instance.new("LinearVelocity")
	v.Name = "Float"
	v.Attachment0 = attachment :: Attachment
	v.RelativeTo = Enum.ActuatorRelativeTo.World
	v.MaxForce = 1e6
	v.Parent = root
	local t = Instance.new("AlignOrientation")
	t.Name = "FloatTurn"
	t.Mode = Enum.OrientationAlignmentMode.OneAttachment
	t.Attachment0 = attachment :: Attachment
	t.MaxTorque = 1e6
	t.Responsiveness = 12
	t.Parent = root
	floatVelocity = v
	floatTurn = t
end

-- the yaw and pitch of a look vector, for CFrame.fromOrientation(pitch, yaw, 0)
local function anglesOf(look: Vector3): (number, number)
	return math.atan2(-look.X, -look.Z), math.asin(math.clamp(look.Y, -1, 1))
end

local function onMounted(fish: Model)
	State.Fish = fish
	State.MountedAt = os.clock()
	local root = fish.PrimaryPart
	rideType = Config.FishById[fish:GetAttribute("FishType") :: string]
	if root then
		yaw, pitch = anglesOf(root.CFrame.LookVector)
		startSpeed = math.min(root.AssemblyLinearVelocity.Magnitude, if rideType then rideType.IdleSpeed else 14)
	end
	roll = 0
	clearFloat()
	State.setMode("Riding")
end

local function drive(dt: number)
	local fish = State.Fish
	local root = fish and fish.PrimaryPart
	if not fish or not root or not rideType then
		return
	end
	local swim = root:FindFirstChild("Swim") :: LinearVelocity?
	local turn = root:FindFirstChild("Turn") :: AlignOrientation?
	if not swim or not turn then
		return
	end
	local r = Config.Ride
	local mv = moveVector()
	yaw -= mv.X * math.rad(r.YawRate) * dt
	if math.abs(mv.Z) > 0.05 then
		pitch += mv.Z * math.rad(r.PitchRate) * dt -- W is -Z: nose down
	else
		pitch = Ease.lerp(pitch, math.rad(-3), Ease.alpha(r.LevelRate * 3, dt))
	end
	-- keep off the floor and under the surface
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances =
		{ fish, State.Player.Character :: Instance, workspace:FindFirstChild("Fish") :: Instance }
	local down = workspace:Raycast(root.Position, Vector3.new(0, -r.FloorClearance - 4, 0), params)
	if down and pitch < math.rad(6) then
		pitch = Ease.lerp(pitch, math.rad(10), Ease.alpha(6, dt))
	end
	if root.Position.Y > Config.Oxygen.SurfaceY - 4 and pitch > 0 then
		pitch = Ease.lerp(pitch, math.rad(-6), Ease.alpha(6, dt))
	end
	pitch = math.clamp(pitch, -math.rad(r.MaxPitch), math.rad(r.MaxPitch))
	roll = Ease.lerp(roll, -mv.X * math.rad(r.Bank), Ease.alpha(5, dt))

	local speed =
		Ease.rideSpeed(startSpeed, rideType.RiddenSpeed, os.clock() - State.MountedAt, r.RampTime, r.Surge, r.SurgeTime)
	local heading = CFrame.fromOrientation(pitch, yaw, 0)
	swim.VectorVelocity = heading.LookVector * speed
	turn.CFrame = heading * CFrame.Angles(0, 0, roll)
	State.Speed = speed
end

local function float(root: BasePart)
	ensureFloat(root)
	local o = Config.Oxygen
	local scale = State.TimeScale
	local rise = o.FloatSpeed
	if root.Position.Y > o.SurfaceY then
		rise = math.min(rise, (o.SurfaceY - root.Position.Y) * 4)
	end
	local pop = Config.Grapple.Pop * math.max(0, 1 - (os.clock() - poppedAt) / 0.4)
	local swim = Vector3.zero
	if State.Mode == "Free" then
		local mv = moveVector()
		local flat = CFrame.fromOrientation(0, camYaw, 0)
		swim = (flat.RightVector * mv.X - flat.LookVector * mv.Z) * o.SwimSpeed
	end
	local v = floatVelocity :: LinearVelocity
	v.VectorVelocity = (Vector3.new(0, rise + pop, 0) + swim) * scale
	local t = floatTurn :: AlignOrientation
	t.CFrame = CFrame.fromOrientation(0, camYaw, 0)
	State.Speed = root.AssemblyLinearVelocity.Magnitude
end

local function cameraStep(dt: number)
	local character, root = State.character()
	if not State.inWater() or not character or not root then
		if wasScripted then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = Config.Camera.Fov
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			wasScripted = false
		end
		camPosition = nil
		return
	end
	if not wasScripted then
		camYaw, camPitch = anglesOf(camera.CFrame.LookVector)
		camPosition = camera.CFrame.Position
		wasScripted = true
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local c = Config.Camera
	local sdt = dt * State.TimeScale
	local mode = State.Mode
	local fish = State.Fish
	local subject: BasePart = root
	if mode == "Riding" and fish and fish.PrimaryPart then
		subject = fish.PrimaryPart
	end

	-- swing back behind the travel direction unless the player is looking round
	local velocity = subject.AssemblyLinearVelocity
	local recentLook = os.clock() - lookedAt < 1.2
	if mode == "Riding" then
		if not recentLook then
			camYaw = Ease.lerpAngle(camYaw, yaw, Ease.alpha(3, sdt))
			camPitch = Ease.lerp(camPitch, pitch * 0.5 + math.rad(-12), Ease.alpha(3, sdt))
		end
	elseif (mode == "Dashing" or mode == "Grappling") and velocity.Magnitude > 5 then
		local y, p = anglesOf(velocity.Unit)
		camYaw = Ease.lerpAngle(camYaw, y, Ease.alpha(5, sdt))
		camPitch = Ease.lerp(camPitch, p * 0.4 + math.rad(-10), Ease.alpha(5, sdt))
	elseif mode == "Aiming" then
		local mv = moveVector()
		camYaw -= mv.X * math.rad(90) * dt
		camPitch -= mv.Z * math.rad(60) * dt
	end
	camPitch = math.clamp(camPitch, math.rad(-75), math.rad(65))

	local aiming = mode == "Aiming"
	UserInputService.MouseBehavior = if aiming
		then Enum.MouseBehavior.LockCenter
		elseif rightHeld then Enum.MouseBehavior.LockCurrentPosition
		else Enum.MouseBehavior.Default
	local distance = if aiming then c.AimDistance else zoom
	local rotation = CFrame.fromOrientation(camPitch, camYaw, 0)
	local focusGoal = subject.Position + Vector3.new(0, if aiming then 2.5 else c.Height * 0.5, 0)
	if aiming then
		focusGoal += rotation.RightVector * 2.5
	end
	camFocus = if camFocus then camFocus:Lerp(focusGoal, Ease.alpha(c.Follow * 2, sdt)) else focusGoal
	local focus = camFocus :: Vector3
	local goal = focus - rotation.LookVector * distance + Vector3.new(0, c.Height * 0.3, 0)

	-- keep the camera out of the floor and walls
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("Fish") :: Instance, camera }
	local hit = workspace:Raycast(focus, goal - focus, params)
	if hit then
		goal = hit.Position + (focus - goal).Unit * 0.8
	end
	camPosition = if camPosition then camPosition:Lerp(goal, Ease.alpha(c.Follow, sdt)) else goal
	local position = camPosition :: Vector3
	camera.CFrame = CFrame.lookAt(position, position + rotation.LookVector)

	-- field of view: wider with speed, plus the dash's kick (decaying)
	State.FovKick = Ease.lerp(State.FovKick, 0, Ease.alpha(4, sdt))
	local speedT = Ease.smoothstep(c.SpeedFovFrom, c.SpeedFovTo, State.Speed)
	local fovGoal = c.Fov + c.SpeedFov * speedT + State.FovKick + (if aiming then -6 else 0)
	camera.FieldOfView = Ease.lerp(camera.FieldOfView, fovGoal, Ease.alpha(6, sdt))
end

local function step(dt: number)
	local _, root, humanoid = State.character()
	if root and humanoid then
		if State.inWater() then
			if not humanoid.PlatformStand then
				humanoid.PlatformStand = true
			end
			if State.Mode == "Riding" then
				drive(dt)
			elseif State.Mode == "Free" or State.Mode == "Aiming" then
				float(root)
			else
				clearFloat()
			end
		else
			clearFloat()
			if State.Mode == "Dock" and humanoid.PlatformStand then
				humanoid.PlatformStand = false
			end
			State.Speed = root.AssemblyLinearVelocity.Magnitude
		end
	end
	cameraStep(dt)
end

-- the hop up when you jump off a fish
function RideController.pop()
	poppedAt = os.clock()
end

local function fromServerState()
	local state = State.Player:GetAttribute("State")
	if state == "Dock" or state == "PassedOut" then
		State.Fish = nil
		State.setMode(state)
	elseif state == "Free" and State.Mode ~= "Aiming" and State.Mode ~= "Grappling" and State.Mode ~= "Dashing" then
		State.Fish = nil
		State.setMode("Free")
	end
end

function RideController.Init()
	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any)
		if kind == "Mounted" then
			onMounted(a)
		elseif kind == "Dismounted" then
			State.Fish = nil
			if a == "Jump" or a == "Dashing" or a == "Grappling" then
				return -- the move or the aim window takes over
			end
			if State.Mode ~= "Aiming" then
				State.setMode(if State.Player:GetAttribute("State") == "Dock" then "Dock" else "Free")
			end
		end
	end)
	State.Player:GetAttributeChangedSignal("State"):Connect(fromServerState)
	State.Player.CharacterAdded:Connect(function()
		State.Fish = nil
		clearFloat()
		camFocus = nil
		fromServerState()
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if not State.inWater() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if rightHeld or State.Mode == "Aiming" then
				camYaw -= input.Delta.X * 0.004
				camPitch -= input.Delta.Y * 0.004
				lookedAt = os.clock()
			end
		elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
			camYaw -= input.Delta.X * 0.006
			camPitch -= input.Delta.Y * 0.006
			lookedAt = os.clock()
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom = math.clamp(zoom - input.Position.Z * 2, 8, 40)
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rightHeld = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rightHeld = false
		end
	end)
end

function RideController.Start()
	local playerModule = State.Player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
	if playerModule and playerModule:IsA("ModuleScript") then
		local ok, module = pcall(require, playerModule)
		if ok then
			controls = (module :: any):GetControls()
		end
	end
	local zonesJson = Net.Folder:GetAttribute("Zones")
	if type(zonesJson) == "string" then
		State.Zones = Zones.decode(zonesJson)
	end
	Net.Folder:GetAttributeChangedSignal("Zones"):Connect(function()
		local json = Net.Folder:GetAttribute("Zones")
		if type(json) == "string" then
			State.Zones = Zones.decode(json)
		end
	end)
	fromServerState()
	RunService:BindToRenderStep("RideFish", Enum.RenderPriority.Camera.Value + 1, step)
end

return RideController
