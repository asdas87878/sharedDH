--!strict
-- The juice round the movement (Config.Feel; Hugo, 2026-11-12: more satisfying movement). Local only, like Lib/Fx:
--   speed lines: thin white streaks round the edge of the screen, pointing at its middle, reshuffled many times a
--     second. Feel.rush(amount) shows them at that strength; they die away by themselves (Feel.LinesFade);
--   the bubble trail left behind our own character through the pop's extra speed and the pull-in;
--   the sounds: the pop's swish, the pull-in's whoosh, the landing's splash (the client's own built-in sounds, pitched;
--     no uploaded assets);
-- Feel.step runs once a frame (JumpController's render step). Everything is made once and reused, but the sounds,
-- which are one Sound each.
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
end

return Feel
