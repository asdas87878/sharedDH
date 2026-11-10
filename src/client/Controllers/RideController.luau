--!strict
-- Riding on the client: steering the fish we own (the server hands us its network ownership on mount), the speed-up,
-- coasting the fish we just left (it stays ours for Switch.HandBack seconds, so it swims off without a hitch), floating
-- while off a fish, and the camera for everything underwater: a smooth chase camera on our own character (so a jump
-- never cuts), whose field of view widens with speed, lifting to look down on a jump's flight, settling behind a new
-- fish over Switch.CameraSettle, with the landing kick, and easing to the drowning's shot.
-- Steering: the fish turns to where the camera looks; A/D or the stick's sideways turn the camera, and so does a right
-- mouse drag or a touch drag. W dives, S climbs; nothing held follows the lane down at the herd's height above the
-- floor. Right mouse drag or a touch
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
local driveParams = RaycastParams.new()
driveParams.FilterType = Enum.RaycastFilterType.Exclude
local startSpeed = 0
local rideType: Config.FishType? = nil

-- the fish we just left, coasting on its heading to idle until the server takes it back
type Coast = { Fish: Model, At: number, Speed: number, Look: Vector3, Idle: number }
local coasting: Coast? = nil

-- floating
local floatVelocity: LinearVelocity? = nil
local floatTurn: AlignOrientation? = nil

-- the fish a jump has just left, and its weld (switched off here at once; the server takes it away a moment later)
local leftFish: Model? = nil
local leftWeld: Weld? = nil

-- camera
local camYaw, camPitch = 0, math.rad(-12)
local camPosition: Vector3? = nil
local camFocus: Vector3? = nil
local zoom = Config.Camera.Distance
local zoomScale = 1 -- the jump pulls the camera back
local lookedAt = -math.huge -- os.clock() the player last looked round themselves
local rightHeld = false
local wasScripted = false
local deathBlend = 0 -- 0 to 1, how far the camera has turned to look at a death shot's focus

-- The move stick or keys: X is right, Z is back (W is -Z)
function RideController.moveVector(): Vector3
	if controls then
		local ok, v = pcall(controls.GetMoveVector, controls)
		if ok and typeof(v) == "Vector3" and v.Magnitude > 0.05 then
			return v
		end
	end
	-- the keys themselves: the player module gives nothing while we hold the character still (found in play, 2026-11-10)
	if UserInputService:GetFocusedTextBox() then
		return Vector3.zero
	end
	local x, z = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		x += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		x -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		z += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		z -= 1
	end
	return Vector3.new(x, 0, z)
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
		-- carry on exactly as it swam: no turn, no drop in speed, then the speed-up
		yaw, pitch = anglesOf(root.CFrame.LookVector)
		startSpeed = root.AssemblyLinearVelocity.Magnitude
	end
	if coasting and coasting.Fish == fish then
		coasting = nil
	end
	leftFish = nil
	leftWeld = nil
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
	local mv = RideController.moveVector()
	-- the fish turns with the camera, as the reference's dinos do (A and D turn the camera): once the camera has come
	-- round behind a fish we just got on
	local settled = Config.Switch.CameraSettle
	local follow = Ease.smoothstep(settled, settled * 1.5, os.clock() - State.MountedAt)
	local before = yaw
	yaw = Ease.lerpAngle(yaw, camYaw, Ease.alpha(r.TurnFollow, dt) * follow)
	local turning = ((yaw - before + math.pi) % (2 * math.pi) - math.pi) / math.max(dt, 1 / 240)
	driveParams.FilterDescendantsInstances =
		{ fish, State.Player.Character :: Instance, workspace:FindFirstChild("Fish") :: Instance }
	local floor = workspace:Raycast(root.Position, Vector3.new(0, -160, 0), driveParams)
	local height = if floor then root.Position.Y - floor.Position.Y else nil
	if math.abs(mv.Z) > 0.05 then
		pitch += mv.Z * math.rad(r.PitchRate) * dt -- W is -Z: nose down
	elseif height then
		-- nothing held: it follows the lane down, settling at the herd's height above the floor
		local h = Config.Herd
		-- (lower in the shallows, to stay under the surface)
		local room = Config.Oxygen.SurfaceY - 9 - (root.Position.Y - height)
		local level = math.min(h.RideHeight, math.max(room, r.FloorClearance + 6))
		local want = math.clamp((level - height) * h.RideHeightGain, -h.RideHeightPitch, h.RideHeightPitch)
		pitch = Ease.lerp(pitch, math.rad(want), Ease.alpha(2.5, dt))
	else
		pitch = Ease.lerp(pitch, math.rad(-3), Ease.alpha(r.LevelRate * 3, dt))
	end
	-- keep off the floor and under the surface
	if height and height < r.FloorClearance + 4 and pitch < math.rad(6) then
		pitch = Ease.lerp(pitch, math.rad(10), Ease.alpha(6, dt))
	end
	if root.Position.Y > Config.Oxygen.SurfaceY - 4 and pitch > 0 then
		pitch = Ease.lerp(pitch, math.rad(-6), Ease.alpha(6, dt))
	end
	pitch = math.clamp(pitch, -math.rad(r.MaxPitch), math.rad(r.MaxPitch))
	-- banking into the turn
	local lean = math.clamp(turning / math.rad(r.YawRate), -1, 1)
	roll = Ease.lerp(roll, lean * math.rad(r.Bank), Ease.alpha(5, dt))

	local speed =
		Ease.rideSpeed(startSpeed, rideType.RiddenSpeed, os.clock() - State.MountedAt, r.RampTime, r.Surge, r.SurgeTime)
	local heading = CFrame.fromOrientation(pitch, yaw, 0)
	swim.VectorVelocity = heading.LookVector * speed
	turn.CFrame = heading * CFrame.Angles(0, 0, roll)
	State.Speed = speed
end

-- Leaving a fish (a jump, the throw-off): it carries on along its heading, slowing to idle
function RideController.coast(fish: Model?)
	local root = fish and fish.PrimaryPart
	if not fish or not root then
		return
	end
	local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
	coasting = {
		Fish = fish,
		At = os.clock(),
		Speed = root.AssemblyLinearVelocity.Magnitude,
		Look = root.CFrame.LookVector,
		Idle = if kind then kind.IdleSpeed else 14,
	}
end

local function coast()
	local c = coasting
	if not c then
		return
	end
	local root = c.Fish.PrimaryPart
	local t = os.clock() - c.At
	local rider = c.Fish:GetAttribute("Rider")
	local taken = rider ~= 0 and rider ~= State.Player.UserId -- someone else is on it now
	if not root or not c.Fish.Parent or t > Config.Switch.HandBack or taken then
		coasting = nil
		return
	end
	local swim = root:FindFirstChild("Swim") :: LinearVelocity?
	local turn = root:FindFirstChild("Turn") :: AlignOrientation?
	if swim and turn then
		local level = Vector3.new(c.Look.X, c.Look.Y * (1 - Ease.smoothstep(0, 1.2, t)), c.Look.Z)
		local look = if level.Magnitude > 0.01 then level.Unit else c.Look
		local speed = Ease.lerp(c.Speed, c.Idle, Ease.smoothstep(0, Config.Ride.SlowDownTime, t))
		swim.VectorVelocity = look * speed
		turn.CFrame = CFrame.lookAt(Vector3.zero, look)
	end
end

-- A jump leaves the fish at once on our side: it coasts, and its weld to us is switched off here, ahead of the server
function RideController.leave()
	local fish = State.Fish
	local root = fish and fish.PrimaryPart
	local weld = root and root:FindFirstChild("RideWeld")
	RideController.coast(fish)
	leftFish = fish
	leftWeld = nil
	if weld and weld:IsA("Weld") then
		weld.Enabled = false
		leftWeld = weld
	end
	State.Fish = nil
end

-- The server refused the jump: back on the fish we left, if it is still ours
function RideController.rejoin(): boolean
	local fish, weld = leftFish, leftWeld
	leftFish = nil
	leftWeld = nil
	if fish and weld and weld.Parent and fish.Parent and fish:GetAttribute("Rider") == State.Player.UserId then
		weld.Enabled = true
		coasting = nil
		State.Fish = fish
		State.setMode("Riding")
		return true
	end
	return false
end

local function float(root: BasePart)
	ensureFloat(root)
	local o = Config.Oxygen
	local rise = o.FloatSpeed
	if root.Position.Y > o.SurfaceY then
		rise = math.min(rise, (o.SurfaceY - root.Position.Y) * 4)
	end
	local swim = Vector3.zero
	if State.Mode == "Free" then
		local mv = RideController.moveVector()
		local flat = CFrame.fromOrientation(0, camYaw, 0)
		swim = (flat.RightVector * mv.X - flat.LookVector * mv.Z) * o.SwimSpeed
	end
	local v = floatVelocity :: LinearVelocity
	v.VectorVelocity = Vector3.new(0, rise, 0) + swim
	local t = floatTurn :: AlignOrientation
	t.CFrame = CFrame.fromOrientation(0, camYaw, 0)
	State.Speed = root.AssemblyLinearVelocity.Magnitude
end

-- The camera shake (the landing kick), dying away
local function shakeOffset(): CFrame
	local left = State.ShakeUntil - os.clock()
	if left <= 0 then
		return CFrame.identity
	end
	local amount = State.ShakeStrength * (left / State.ShakeTime) ^ 2
	local t = os.clock() * 40
	return CFrame.new(math.noise(t, 0.3) * amount, math.noise(0.7, t) * amount, 0)
		* CFrame.Angles(0, 0, math.noise(t, 2.1) * amount * 0.03)
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
	local mode = State.Mode
	-- the camera always follows our own character (it sits on the saddle while riding), so a jump never cuts

	-- the drowning's shot: ease there, no cut, turning to look at the shot's focus
	local shot = State.DeathCam
	if shot then
		deathBlend = math.min(1, deathBlend + dt / 0.5)
		camFocus = (camFocus or shot.Focus):Lerp(shot.Focus, Ease.alpha(5, dt))
		camPosition = (camPosition or shot.Position):Lerp(shot.Position, Ease.alpha(3, dt))
		local at = camPosition :: Vector3
		local towards = (camFocus :: Vector3) - at
		local free = CFrame.fromOrientation(camPitch, camYaw, 0).LookVector
		local look = if towards.Magnitude > 0.1
			then free:Lerp(towards.Unit, Ease.smoothstep(0, 1, deathBlend))
			else free
		camera.CFrame = CFrame.lookAt(at, at + look) * shakeOffset()
		camera.FieldOfView = Ease.lerp(camera.FieldOfView, c.Fov, Ease.alpha(3, dt))
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		return
	end
	if deathBlend > 0 then
		deathBlend = 0
		camYaw, camPitch = anglesOf(camera.CFrame.LookVector)
	end

	-- The camera's turn is the player's: a drag turns it, and so do A and D. The fish, and the flight, turn to where it
	-- looks. Just after a mount it comes round behind the new fish first (Switch.CameraSettle). Its tilt looks after
	-- itself unless the player has just dragged it.
	local recentLook = os.clock() - lookedAt < 1.2
	local turn = RideController.moveVector().X
	if mode == "Riding" then
		if os.clock() - State.MountedAt < Config.Switch.CameraSettle and not recentLook then
			camYaw = Ease.lerpAngle(camYaw, yaw, Ease.alpha(3 / Config.Switch.CameraSettle, dt))
		else
			camYaw -= turn * math.rad(Config.Ride.YawRate) * dt
		end
		if not recentLook then
			camPitch = Ease.lerp(camPitch, pitch * 0.5 + math.rad(-12), Ease.alpha(3, dt))
		end
	elseif mode == "Jumping" then
		camYaw -= turn * math.rad(Config.Jump.YawRate) * dt
		-- lifted to look down on the ring and the fish under it (as the reference does)
		if not recentLook then
			camPitch = Ease.lerp(camPitch, math.rad(Config.Jump.CameraPitch), Ease.alpha(4, dt))
		end
	end
	State.CamYaw = camYaw
	camPitch = math.clamp(camPitch, math.rad(-75), math.rad(65))

	UserInputService.MouseBehavior = if rightHeld
		then Enum.MouseBehavior.LockCurrentPosition
		else Enum.MouseBehavior.Default
	zoomScale = Ease.lerp(zoomScale, if mode == "Jumping" then Config.Jump.CameraZoom else 1, Ease.alpha(4, dt))
	local distance = zoom * zoomScale
	local rotation = CFrame.fromOrientation(camPitch, camYaw, 0)
	if State.SideCam then
		-- the sandbox's side view: square on to the way we are headed, far enough to see a whole jump
		distance = math.max(distance, 70)
		rotation = CFrame.fromOrientation(math.rad(-4), camYaw + math.pi / 2, 0)
	end
	local focusGoal = root.Position + Vector3.new(0, c.Height * 0.5, 0)
	camFocus = if camFocus then camFocus:Lerp(focusGoal, Ease.alpha(c.Follow * 2, dt)) else focusGoal
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
	camPosition = if camPosition then camPosition:Lerp(goal, Ease.alpha(c.Follow, dt)) else goal
	local position = camPosition :: Vector3
	camera.CFrame = CFrame.lookAt(position, position + rotation.LookVector) * shakeOffset()

	-- field of view: wider with speed, plus the jump's kick (decaying)
	State.FovKick = Ease.lerp(State.FovKick, 0, Ease.alpha(4, dt))
	local speedT = Ease.smoothstep(c.SpeedFovFrom, c.SpeedFovTo, State.Speed)
	local fovGoal = c.Fov + c.SpeedFov * speedT + State.FovKick
	camera.FieldOfView = Ease.lerp(camera.FieldOfView, fovGoal, Ease.alpha(6, dt))
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
			elseif State.Mode == "Free" then
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
	coast()
	cameraStep(dt)
end

-- The server's State, where our own prediction doesn't already cover it
local function fromServerState()
	local state = State.Player:GetAttribute("State")
	if state == "Dock" or state == "Drowning" then
		State.Fish = nil
		State.setMode(state)
	elseif state == "Free" then
		-- also the end of a jump that missed from floating, or lost its fish
		State.Fish = nil
		State.setMode("Free")
	end
end

function RideController.Init()
	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any)
		if kind == "Mounted" then
			onMounted(a)
		elseif kind == "Dismounted" then
			if a == "Jump" or a == "OutOfOxygen" then
				-- the jump or the throw-off takes over; the fish swims on without us
				if State.Fish then
					RideController.coast(State.Fish)
				end
				State.Fish = nil
				return
			end
			State.Fish = nil
			if a == "Lost" then
				State.setMode("Free")
			end
		end
	end)
	State.Player:GetAttributeChangedSignal("State"):Connect(fromServerState)
	State.Player.CharacterAdded:Connect(function()
		State.Fish = nil
		coasting = nil
		clearFloat()
		camFocus = nil
		fromServerState()
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if not State.inWater() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if rightHeld then
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
