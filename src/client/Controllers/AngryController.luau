--!strict
-- Angry mode's red pulse (Config.Angry; Hugo, 2026-11-12): every fish the server has marked angry (its "AngryFish"
-- tag and "Angry" attribute, RideService) pulses red, on every player's screen, faster as its rider's Oxygen runs out.
-- A Highlight over the whole model: one object a fish, nothing written to its parts, so a creature's own colours, a
-- block stand-in's and a Gold's or a Rainbow's look (Shared/Variants) are never touched and there is nothing to put
-- back; when the mode ends the red fades and the Highlight is switched off. Kept and used again, never more than
-- there are angry fish (one a rider), and only moved while one is.
-- How fast it pulses comes from the rider's own Oxygen and MaxOxygen attributes (the server's, seen by everyone), so no
-- extra word is sent for it.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Ease = require(game:GetService("ReplicatedStorage").Shared.Ease)

local AngryController = {}

type Pulse = {
	Glow: Highlight,
	Shown: number, -- how much of the red is in, 0 to 1 (it fades in and out)
	Phase: number, -- where in a pulse it is, in turns
	Rate: number, -- pulses a second now (eased, so it quickens smoothly)
}

local pulses: { [Model]: Pulse } = {}
local spare: { Highlight } = {}
local count = 0

-- How far through its red part the rider's meter is, 0 to 1 (1 with no rider to ask, and on a fish too strong)
local function heatOf(fish: Model): number
	local a = Config.Angry
	if RunService:IsStudio() and a.Test > 0 then
		return a.Test
	end
	local id = fish:GetAttribute("Rider")
	local rider = if type(id) == "number" and id ~= 0 then Players:GetPlayerByUserId(id) else nil
	if not rider or rider:GetAttribute("Strained") == true then
		return 1
	end
	local oxygen = rider:GetAttribute("Oxygen")
	local max = rider:GetAttribute("MaxOxygen")
	if type(oxygen) == "number" and type(max) == "number" then
		-- (a Tank's red part starts lower: Config.angryAt)
		return Config.heat(oxygen, max, Config.FishById[fish:GetAttribute("FishType") :: string])
	end
	return 1
end

local function begin(fish: Instance)
	if not fish:IsA("Model") or pulses[fish] then
		return
	end
	local glow = table.remove(spare)
	if not glow then
		glow = Instance.new("Highlight")
		glow.Name = "AngryPulse"
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = workspace.CurrentCamera
	end
	glow.FillColor = Config.Angry.Colour
	glow.OutlineColor = Config.Angry.Colour
	glow.FillTransparency = 1
	glow.OutlineTransparency = 1
	glow.Adornee = fish
	glow.Enabled = true
	pulses[fish] = { Glow = glow, Shown = 0, Phase = 0, Rate = Config.Angry.PulseSlow }
	count += 1
end

local function finish(fish: Model, p: Pulse)
	pulses[fish] = nil
	count -= 1
	p.Glow.Enabled = false
	p.Glow.Adornee = nil
	table.insert(spare, p.Glow)
end

local function step(dt: number)
	if count == 0 then
		return
	end
	local a = Config.Angry
	local fade = dt / math.max(a.PulseFade, 0.01)
	for fish, p in pulses do
		local on = a.On ~= 0 and fish.Parent ~= nil and fish:GetAttribute("Angry") == true
		p.Shown = math.clamp(p.Shown + (if on then fade else -fade), 0, 1)
		if p.Shown <= 0 and not on then
			finish(fish, p)
			continue
		end
		if on then
			p.Rate = Ease.lerp(p.Rate, Ease.lerp(a.PulseSlow, a.PulseFast, heatOf(fish)), Ease.alpha(6, dt))
		end
		p.Phase = (p.Phase + p.Rate * dt) % 1
		-- a pulse: up quickly, down slowly (a heartbeat more than a sine)
		local beat = (0.5 - 0.5 * math.cos(2 * math.pi * p.Phase)) ^ 1.6
		local red = Ease.lerp(a.PulseLow, a.PulseHigh, beat) * p.Shown
		p.Glow.FillTransparency = 1 - math.clamp(red, 0, 1)
		p.Glow.OutlineTransparency = 1 - math.clamp(a.PulseEdge * beat * p.Shown, 0, 1)
	end
end

function AngryController.Start()
	local tag = Config.Angry.Tag
	CollectionService:GetInstanceAddedSignal(tag):Connect(begin)
	for _, fish in CollectionService:GetTagged(tag) do
		begin(fish)
	end
	RunService.RenderStepped:Connect(step)
end

return AngryController
