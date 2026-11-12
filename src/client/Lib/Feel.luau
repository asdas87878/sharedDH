--!strict
-- The juice round the movement (Config.Feel; Hugo, 2026-11-12: more satisfying movement). Local only, like Lib/Fx:
--   speed lines: thin white streaks round the edge of the screen, pointing at its middle, reshuffled many times a
--     second. Feel.rush(amount) shows them at that strength; they die away by themselves (Feel.LinesFade);
--   the bubble trail left behind our own character through the pop's extra speed and the pull-in;
--   the sounds: the pop's swish, the pull-in's whoosh, the landing's splash (the client's own built-in sounds, pitched;
--     no uploaded assets);
--   the "!" over a startled fish (Config.Ride.Startle): two blocks that pop up over its head, turned to the camera.
-- Feel.step runs once a frame (JumpController's render step). Everything is made once and reused, but the "!" and the
-- sounds, which are a few parts or one Sound a landing.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Feel = {}

local LINES = 30
local SHUFFLE = 0.045 -- seconds between two sets of lines
local WHITE = Color3.new(1, 1, 1)

local gui: ScreenGui? = nil
local lines: { Frame } = {}
local strength = 0
local shuffledAt = 0
local shown = false

local SOUNDS: { [string]: string } = {
	Whoosh = "rbxasset://sounds/action_falling.ogg",
	Swish = "rbxasset://sounds/action_swim.mp3",
	Splash = "rbxasset://sounds/impact_water.mp3",
}

type Mark = { fish: Model, bar: Part, dot: Part, at: number, size: number, lift: number, ahead: number }
local marks: { Mark } = {}

local trail: ParticleEmitter? = nil

-- Speed lines at this strength (0 to 1) from now: the strongest asked for wins, and they fade by themselves
function Feel.rush(amount: number)
	strength = math.max(strength, math.clamp(amount, 0, 1))
end

-- One of the built-in sounds, flat (not placed in the world): `volume`, `pitch`, and how long before it is faded out
function Feel.sound(name: string, volume: number, pitch: number, life: number)
	local id = SOUNDS[name]
	if not id or volume <= 0 then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.Parent = SoundService
	sound:Play()
	task.delay(life, function()
		TweenService:Create(sound, TweenInfo.new(0.18), { Volume = 0 }):Play()
	end)
	Debris:AddItem(sound, life + 0.3)
end

-- The bubbles left behind our character while it dashes: on or off
function Feel.trail(root: BasePart?, on: boolean)
	local emitter = trail
	if not on or not root or Config.Feel.Trail <= 0 then
		if emitter then
			emitter.Enabled = false
		end
		return
	end
	if not emitter or not emitter:IsDescendantOf(root) then
		local from = Instance.new("Attachment")
		from.Name = "DashTrail"
		from.Parent = root
		local made = Instance.new("ParticleEmitter")
		made.Lifetime = NumberRange.new(0.5, 0.9)
		made.Speed = NumberRange.new(1, 4)
		made.SpreadAngle = Vector2.new(180, 180)
		made.Acceleration = Vector3.new(0, 5, 0)
		made.Drag = 2
		made.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.4, 0.55),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		made.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.7, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		made.LightEmission = 0.3
		made.Color = ColorSequence.new(Color3.fromRGB(225, 248, 255))
		made.Parent = from
		emitter = made
		trail = made
	end
	emitter.Rate = Config.Feel.Trail
	emitter.Enabled = true
end

-- The "!" over a fish that has just been landed on
function Feel.mark(fish: Model)
	local root = fish.PrimaryPart
	if Config.Feel.Mark <= 0 or not root then
		return
	end
	local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
	local body = if kind then Config.bodyOf(fish, kind) else Vector3.new(5, 5, 10)
	local length = body.Z
	local height = body.Y
	local function block(): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Config.Jump.Glow
		p.Parent = workspace.CurrentCamera
		return p
	end
	table.insert(marks, {
		fish = fish,
		bar = block(),
		dot = block(),
		at = os.clock(),
		size = math.clamp(length / 12, 0.9, 2.6),
		lift = height / 2 + 4.5,
		ahead = length * 0.3,
	})
end

local function stepMarks()
	local now = os.clock()
	local life = math.max(Config.Feel.MarkTime, 0.05)
	local eye = workspace.CurrentCamera.CFrame.Position
	for i = #marks, 1, -1 do
		local m = marks[i]
		local root = m.fish.PrimaryPart
		local u = (now - m.at) / life
		if u >= 1 or not root or not m.fish.Parent then
			m.bar:Destroy()
			m.dot:Destroy()
			table.remove(marks, i)
			continue
		end
		-- it pops up past its size and settles, then shrinks away
		local grow = math.min(u / 0.18, 1)
		local scale = m.size
			* (grow * (1 + 0.45 * math.sin(grow * math.pi)))
			* (1 - math.clamp((u - 0.75) / 0.25, 0, 1))
		local at = (root.CFrame * CFrame.new(0, m.lift + 1.6 * m.size * grow, -m.ahead)).Position
		local face = CFrame.lookAt(at, eye) * CFrame.Angles(0, 0, math.rad(-10))
		m.bar.Size = Vector3.new(0.7, 2, 0.4) * math.max(scale, 0.01)
		m.dot.Size = Vector3.new(0.7, 0.7, 0.4) * math.max(scale, 0.01)
		m.bar.CFrame = face * CFrame.new(0, 0.9 * scale, 0)
		m.dot.CFrame = face * CFrame.new(0, -0.9 * scale, 0)
	end
end

local function makeLines()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local made = Instance.new("ScreenGui")
	made.Name = "RideFeel"
	made.IgnoreGuiInset = true
	made.ResetOnSpawn = false
	made.DisplayOrder = -5
	made.Enabled = false
	for _ = 1, LINES do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = WHITE
		line.BorderSizePixel = 0
		-- faint toward the middle of the screen, solid at its edge
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new(1, 0.1)
		fade.Parent = line
		line.Parent = made
		table.insert(lines, line)
	end
	made.Parent = playerGui
	gui = made
end

local function stepLines(dt: number)
	if strength <= 0 then
		if shown and gui then
			gui.Enabled = false
			shown = false
		end
		return
	end
	if not gui then
		makeLines()
	end
	local screen = gui
	if not screen then
		strength = 0
		return
	end
	local now = os.clock()
	if now - shuffledAt >= SHUFFLE then
		shuffledAt = now
		local view = workspace.CurrentCamera.ViewportSize
		local half = view / 2
		local reach = half.Magnitude
		local inner = math.clamp(Config.Feel.LinesInner, 0.1, 1)
		for i, line in lines do
			-- (the stronger, the more of them)
			if i > LINES * (0.35 + 0.65 * strength) then
				line.Visible = false
				continue
			end
			local angle = math.random() * math.pi * 2
			local from = reach * (inner + 0.25 * math.random())
			local length = reach * (0.2 + 0.35 * math.random()) * (0.5 + 0.5 * strength)
			local mid = from + length / 2
			line.Visible = true
			line.Size = UDim2.fromOffset(length, 1.5 + 3 * math.random())
			line.Position = UDim2.fromOffset(half.X + math.cos(angle) * mid, half.Y + math.sin(angle) * mid)
			line.Rotation = math.deg(angle)
			line.BackgroundTransparency = 1 - strength * (0.3 + 0.5 * math.random())
		end
	end
	if not shown then
		screen.Enabled = true
		shown = true
	end
	strength = math.max(0, strength - dt / math.max(Config.Feel.LinesFade, 0.01))
end

function Feel.step(dt: number)
	stepLines(dt)
	stepMarks()
end

return Feel
