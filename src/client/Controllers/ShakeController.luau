--!strict
-- The camera shakes that nothing else asks for (Lib/Shake does the shaking; Config.Shake has the numbers):
--   Strain  the rumble on a fish too strong for you, growing through the second you have on it
--   Speed   a fine tremble at top speed
--   Pass    a hunter or a giant going by close: the water shakes, low and slow
--   Tame    the fish under you becomes yours
-- The landing, the hop, a crash and a throw-off ask for theirs where they happen (JumpController, RideController,
-- DeathController); a prop and the archetypes' moments go through RideController.shake as before.
-- For phones: the fish are looked through six times a second, not every frame, and nothing is made as they are.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Shake = require(script.Parent.Parent.Lib.Shake)
local State = require(script.Parent.Parent.Lib.State)

local ShakeController = {}

local haptic: any = nil -- the catch's buzz (phones and pads; made at the first)

local LOOK_EVERY = 1 / 6

-- what a fish is to the shakes: 0 nothing, else how hard its passing shakes (kept: a model's attributes don't change)
local weight: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local passedAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local lookedAt = 0

local function weigh(model: Model): number
	local known = weight[model]
	if known then
		return known
	end
	local kind = Config.FishById[model:GetAttribute("FishType") :: string]
	local worth = 0
	if kind then
		local length = Config.bodyOf(model, kind).Z
		local grand = Config.isGrand(Config.sizeTierOf(model))
		if model:GetAttribute("Pace") == "Hunt" or grand then
			worth = math.clamp(length / math.max(Config.Shake.GrandLength, 1), 0.5, 1.6)
		end
	end
	weight[model] = worth
	return worth
end

-- The big things going by: a hunter or a giant, close, and a good deal faster or slower than we are
local function passes(now: number)
	local s = Config.Shake
	local folder = workspace:FindFirstChild("Fish")
	local _, root = State.character()
	if not folder or not root or not State.inWater() or State.dying() then
		return
	end
	local here = root.Position
	local mine = root.AssemblyLinearVelocity
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model ~= State.Fish then
			local worth = weigh(model)
			local body = model.PrimaryPart
			if worth > 0 and body and now - (passedAt[model] or -math.huge) > s.PassEvery then
				local away = (body.Position - here).Magnitude
				if
					away < s.PassRange
					and (body.AssemblyLinearVelocity - mine).Magnitude > s.PassSpeed
					and model:GetAttribute("Rider") == 0
				then
					passedAt[model] = now
					local near = 1 - away / math.max(s.PassRange, 1)
					Shake.play("Pass", worth * (0.35 + 0.65 * near))
				end
			end
		end
	end
end

local function step()
	local s = Config.Shake
	local now = os.clock()
	local riding = State.Mode == "Riding" and State.Fish ~= nil
	-- a fish too strong for us: it grows as the meter empties
	local strain = 0
	if riding and State.Strained then
		-- (this fish's own strain time: shorter for each red fish in a row, Oxygen.RedShrink)
		local seconds = State.Player:GetAttribute("StrainSeconds")
		local time = if type(seconds) == "number" then seconds else Config.Oxygen.StrainTime
		local through = math.clamp((now - State.MountedAt) / math.max(time, 0.05), 0, 1)
		strain = s.StrainFrom + (1 - s.StrainFrom) * through
	end
	Shake.rumble("Strain", "Strain", strain)
	-- top speed
	local fast = 0
	local fish = State.Fish
	local body = fish and fish.PrimaryPart
	if riding and body then
		local speed = body.AssemblyLinearVelocity.Magnitude
		fast = math.clamp((speed - s.SpeedFrom) / math.max(s.SpeedFull - s.SpeedFrom, 1), 0, 1)
	end
	Shake.rumble("Speed", "Speed", fast)
	if now - lookedAt >= LOOK_EVERY then
		lookedAt = now
		passes(now)
	end
end

function ShakeController.Start()
	-- the tame: harder for a great catch, and a buzz in the hand where there is one
	State.Tamed.Event:Connect(function(id: string, size: any, variant: any)
		local great = Config.greatCatch(id, size, variant)
		Shake.play("Tame", if great then 1.6 else 1)
		pcall(function()
			local buzz = haptic
			if not buzz then
				local made: any = Instance.new("HapticEffect" :: any)
				made.Parent = workspace
				haptic, buzz = made, made
			end
			buzz.Type = if great
				then Enum.HapticEffectType.GameplayExplosion
				else Enum.HapticEffectType.GameplayCollision
			buzz:Play()
		end)
	end)
	RunService.Heartbeat:Connect(step)
end

return ShakeController
