--!strict
-- Riding a fish in our own tank (Hugo, 2026-11-20, task k1; Config.TankRide; the server's side, TankRideService). The
-- server puts us on the fish and gives it to us to move ("TankMounted", fish, box, half); here we move its movers'
-- targets every frame, kept inside the box (the water, less the fish's reach), so it never leaves the tank or goes
-- through the glass.
-- The steering is the dive's: always forward; A and D (or the stick's sideways) turn, and the view turns with us; the
-- fish comes round to the way the camera looks, up and down too (a right drag or a stick looks round). Roblox's own
-- camera is kept (we are on the dock). Against the glass the fish slides along it. SPACE (or the pad's A, or the
-- button on a phone) gets us off: Action "TankRide", "Off".
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local RideController = require(script.Parent.RideController)

local TankRideController = {}

local OFF_ACTION = "TankRideOff"

type Riding = {
	Fish: Model,
	Root: BasePart,
	Align: AlignPosition,
	Turn: AlignOrientation,
	Box: CFrame,
	Half: Vector3,
	At: Vector3, -- where the fish's middle is going: moved forward each frame, kept in the box
	Yaw: number,
	Pitch: number,
}

local riding: Riding? = nil
local hint: ScreenGui? = nil

function TankRideController.riding(): boolean
	return riding ~= nil
end

local function anglesOf(look: Vector3): (number, number)
	return math.atan2(-look.X, -look.Z), math.asin(math.clamp(look.Y, -1, 1))
end

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
	label.Text = "SPACE TO GET OFF"
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
	riding = nil
	ContextActionService:UnbindAction(OFF_ACTION)
	showHint(false)
end

local function mounted(fish: Model, box: CFrame, half: Vector3)
	local root = fish.PrimaryPart
	local align = root and root:WaitForChild("TankAlign", 3)
	local turn = root and root:WaitForChild("TankTurn", 3)
	if not root or not align or not align:IsA("AlignPosition") or not turn or not turn:IsA("AlignOrientation") then
		return
	end
	local yaw = anglesOf(root.CFrame.LookVector)
	riding = {
		Fish = fish,
		Root = root,
		Align = align,
		Turn = turn,
		Box = box,
		Half = half,
		At = root.Position,
		Yaw = yaw,
		Pitch = 0,
	}
	-- (above the jump and everything else, while we ride)
	ContextActionService:BindActionAtPriority(
		OFF_ACTION,
		off,
		true,
		Enum.ContextActionPriority.High.Value + 10,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA
	)
	ContextActionService:SetTitle(OFF_ACTION, "Off")
	showHint(true)
	-- the view behind the fish
	local camera = workspace.CurrentCamera
	if camera then
		local look = root.CFrame.LookVector
		camera.CFrame = CFrame.lookAt(root.Position - look * 22 + Vector3.new(0, 9, 0), root.Position)
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
	-- forward, kept in the box: against the glass it slides along it
	local ahead = r.At + way.LookVector * c.Speed * dt
	local p = r.Box:PointToObjectSpace(ahead)
	local h = r.Half
	p = Vector3.new(math.clamp(p.X, -h.X, h.X), math.clamp(p.Y, -h.Y, h.Y), math.clamp(p.Z, -h.Z, h.Z))
	r.At = r.Box:PointToWorldSpace(p)
	r.Align.Position = r.At
	-- (and its speed toward there, set as well: a still assembly sleeps, and a mover's new target alone does not
	-- always wake it; seen in Studio, the fish sat 32 studs from its target)
	local gap = r.At - r.Root.Position
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

function TankRideController.Start()
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
	-- (before each physics step, not on the frame drawn: the fish keeps its speed however often the screen is drawn.
	-- Roblox's camera reads its own CFrame at the next frame, so the turn set here carries over)
	RunService.PreSimulation:Connect(step)
	Players.LocalPlayer.CharacterAdded:Connect(stop)
end

return TankRideController
