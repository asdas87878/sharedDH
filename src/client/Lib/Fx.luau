--!strict
-- Local-only effects (parented under the camera, so nothing replicates or collides): the landing's ring and bubble
-- burst, mouth bubbles, and placeholder sounds. Built-in textures and the client's own built-in sounds only
-- (rbxasset://), no uploaded assets.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Fx = {}

-- Placeholders from the client's built-in character sounds, pitched; swap for chosen sounds later
type SoundSpec = { Id: string, Speed: number, Volume: number }
local SOUNDS: { [string]: SoundSpec } = {
	Pop = { Id = "rbxasset://sounds/action_jump_land.mp3", Speed = 1.7, Volume = 0.35 },
	Tick = { Id = "rbxasset://sounds/action_jump_land.mp3", Speed = 2.6, Volume = 0.25 },
	Rumble = { Id = "rbxasset://sounds/action_falling.mp3", Speed = 0.25, Volume = 0.9 },
	Chomp = { Id = "rbxasset://sounds/action_jump_land.mp3", Speed = 0.45, Volume = 1 },
	Splash = { Id = "rbxasset://sounds/impact_water.mp3", Speed = 0.8, Volume = 0.5 },
}

-- A placeholder sound, at a part (3D) or flat (no part)
function Fx.sound(name: string, at: BasePart?): Sound?
	local spec = SOUNDS[name]
	if not spec then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = spec.Id
	sound.PlaybackSpeed = spec.Speed
	sound.Volume = spec.Volume
	sound.RollOffMaxDistance = 200
	sound.Parent = at or SoundService
	sound:Play()
	Debris:AddItem(sound, 6)
	return sound
end

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

local function bubbleEmitter(parent: Instance): ParticleEmitter
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Rate = 0
	bubbles.Lifetime = NumberRange.new(0.8, 1.4)
	bubbles.SpreadAngle = Vector2.new(180, 180)
	bubbles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	bubbles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.75, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	bubbles.LightEmission = 0.3
	bubbles.Color = ColorSequence.new(Color3.fromRGB(225, 248, 255))
	bubbles.Parent = parent
	return bubbles
end

-- `amount` bubbles over `time` seconds (all at once with no time) from a part or attachment, flying out about `reach`
-- studs (drag stops them) and rising; they stay in the world as the parent moves on
local function burstFrom(parent: Instance, amount: number, time: number?, reach: number?)
	local bubbles = bubbleEmitter(parent)
	local drag = 3
	local speed = (reach or 3) * drag -- with drag d, a bubble launched at v travels about v / d
	bubbles.Drag = drag
	bubbles.Speed = NumberRange.new(speed * 0.7, speed * 1.2)
	bubbles.Acceleration = Vector3.new(0, 7, 0)
	if time and time > 0 then
		bubbles.Rate = amount / time
		task.delay(time, function()
			bubbles.Enabled = false
		end)
	else
		bubbles:Emit(amount)
	end
	Debris:AddItem(parent, (time or 0) + 1.6)
end

-- A burst of bubbles at a point
function Fx.burst(position: Vector3, amount: number, time: number?, reach: number?)
	local p = anchoredPart(Vector3.one, CFrame.new(position), Color3.new(1, 1, 1))
	p.Transparency = 1
	burstFrom(p, amount, time, reach)
end

-- Bubbles from a character's mouth; the caller sets Rate (and emits the last one). Nil without a head.
function Fx.mouthBubbles(character: Model): ParticleEmitter?
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local mouth = Instance.new("Attachment")
	mouth.Name = "MouthBubbles"
	mouth.Position = Vector3.new(0, -0.25, -head.Size.Z / 2)
	mouth.Parent = head
	local bubbles = bubbleEmitter(mouth)
	bubbles.Lifetime = NumberRange.new(1.4, 2.2)
	bubbles.Speed = NumberRange.new(1.5, 3)
	bubbles.SpreadAngle = Vector2.new(25, 25)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Acceleration = Vector3.new(0, 6, 0)
	bubbles.Drag = 1
	bubbles.Size = NumberSequence.new(0.18, 0.4)
	return bubbles
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

-- The landing for anyone: a ring at the saddle, the bubble burst (Config.Burst), a soft pop, and a squash the rider
-- pose plays
function Fx.landing(character: Model?, fish: Model, squash: { [Model]: number }, colour: Color3)
	local root = fish.PrimaryPart
	if not root then
		return
	end
	local saddle = root:FindFirstChild("Saddle")
	local at = if saddle and saddle:IsA("Attachment") then saddle.WorldCFrame else root.CFrame
	local b = Config.Burst
	Fx.ring(at, colour)
	-- from the saddle as the fish swims on (an attachment of our own, local only)
	local from = Instance.new("Attachment")
	from.Name = "LandingBurst"
	from.WorldCFrame = at
	from.Parent = root
	burstFrom(from, b.Count, b.Time, b.Reach)
	Fx.sound("Pop", root)
	if character then
		squash[character] = os.clock()
	end
end

return Fx
