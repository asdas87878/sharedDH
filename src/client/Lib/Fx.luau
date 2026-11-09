--!strict
-- Local-only effects (parented under the camera, so nothing replicates or collides): the dash's trail and bubbles, the
-- landing ring, the grapple rope. Built-in textures only, no uploaded assets.
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fx = {}

local function holder(): Instance
	local camera = workspace.CurrentCamera
	local folder = camera:FindFirstChild("RideFx")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RideFx"
		folder.Parent = camera
	end
	return folder :: Instance
end

local function anchoredPart(size: Vector3, cf: CFrame, colour: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = colour
	p.Size = size
	p.CFrame = cf
	p.Parent = holder()
	return p
end

-- A bubble trail and a ribbon behind a character for a while
function Fx.trail(character: Model, duration: number, colour: Color3?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.2, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(colour or Color3.fromRGB(190, 240, 255))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Parent = root
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Rate = 90
	bubbles.Lifetime = NumberRange.new(0.5, 1.1)
	bubbles.Speed = NumberRange.new(1, 4)
	bubbles.SpreadAngle = Vector2.new(180, 180)
	bubbles.Acceleration = Vector3.new(0, 8, 0)
	bubbles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	bubbles.Transparency = NumberSequence.new(0.2, 1)
	bubbles.LightEmission = 0.4
	bubbles.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	bubbles.Parent = a1
	task.delay(duration, function()
		bubbles.Enabled = false
		trail.Enabled = false
	end)
	Debris:AddItem(a0, duration + 1.2)
	Debris:AddItem(a1, duration + 1.2)
	Debris:AddItem(trail, duration + 1.2)
end

-- A burst of bubbles at a point
function Fx.burst(position: Vector3, amount: number)
	local p = anchoredPart(Vector3.one, CFrame.new(position), Color3.new(1, 1, 1))
	p.Transparency = 1
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Rate = 0
	bubbles.Lifetime = NumberRange.new(0.6, 1.2)
	bubbles.Speed = NumberRange.new(4, 10)
	bubbles.SpreadAngle = Vector2.new(180, 180)
	bubbles.Acceleration = Vector3.new(0, 10, 0)
	bubbles.Drag = 3
	bubbles.Size = NumberSequence.new(0.35, 0.6)
	bubbles.Transparency = NumberSequence.new(0.1, 1)
	bubbles.Parent = p
	bubbles:Emit(amount)
	Debris:AddItem(p, 1.5)
end

-- The landing ring: a flat neon disc that grows and fades
function Fx.ring(cf: CFrame, colour: Color3)
	local ring = anchoredPart(Vector3.new(0.3, 2, 2), cf * CFrame.Angles(0, 0, math.pi / 2), colour)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.2
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = Vector3.new(0.1, 14, 14), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.4)
end

export type Rope = {
	Stop: (Rope) -> (),
}

-- A rope from a character's hand to a fish: the hook flies out over flyTime (bowing a little), then holds on until
-- stopped. Real time, so it reads crisp even in slow-mo.
function Fx.rope(character: Model, fish: Model, flyTime: number): Rope
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local from = if hand and hand:IsA("BasePart") then hand else character:FindFirstChild("HumanoidRootPart")
	local fishRoot = fish.PrimaryPart
	local a0 = Instance.new("Attachment")
	a0.Parent = from
	local hook = anchoredPart(Vector3.new(0.8, 0.8, 0.8), CFrame.new(a0.WorldPosition), Color3.fromRGB(255, 230, 120))
	local a1 = Instance.new("Attachment")
	a1.Parent = hook
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.25
	beam.Width1 = 0.25
	beam.Segments = 12
	beam.FaceCamera = true
	beam.LightEmission = 0.3
	beam.Color = ColorSequence.new(Color3.fromRGB(240, 225, 190))
	beam.Transparency = NumberSequence.new(0)
	beam.Parent = hook
	local started = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		if not fishRoot or not fishRoot.Parent or not a0.Parent then
			return
		end
		local t = math.clamp((os.clock() - started) / flyTime, 0, 1)
		local start = a0.WorldPosition
		local goal = fishRoot.Position
		hook.CFrame = CFrame.new(start:Lerp(goal, t))
		beam.CurveSize0 = (1 - t) * 2
		beam.CurveSize1 = -(1 - t) * 2
	end)
	local rope = {} :: Rope
	function rope.Stop(_self: Rope)
		connection:Disconnect()
		hook:Destroy()
		a0:Destroy()
	end
	return rope
end

-- The landing for anyone: a ring at the saddle, a puff of bubbles, and a squash the rider pose plays
function Fx.landing(character: Model?, fish: Model, squash: { [Model]: number }, colour: Color3)
	local root = fish.PrimaryPart
	if not root then
		return
	end
	local saddle = root:FindFirstChild("Saddle")
	local at = if saddle and saddle:IsA("Attachment") then saddle.WorldCFrame else root.CFrame
	Fx.ring(at, colour)
	Fx.burst(at.Position, 18)
	if character then
		squash[character] = os.clock()
	end
end

return Fx
