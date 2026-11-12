--!strict
-- The passive archetypes' moments, as the player sees, hears and feels them (Config.ArchetypeFeel; Hugo, 2026-11-12:
-- "make sure it feels good"; docs/design/archetypes.md). The server decides every one of them (RideService); this
-- only plays them, from what the game already has:
--   a bite (a Predator ate a fish; Fx "Eat", for everyone): bubbles where the fish was, a ring in the hunter's rarity
--     colour, a chomp. For the rider (Ride "Boost"): the view kicks wider, the camera is knocked, "CHOMP!" by the
--     rider with the air it gave, "FRENZY x2" on a chain, and the burst of speed (RideController.boost);
--   a smash (a Breaker was paid for a prop; Fx "Smash"): bubbles at its nose, a rumble; for the rider the view kicks
--     wider, the camera shakes, "SMASH!", and the burst;
--   a launch (we landed on a Fast fish and it takes off: State.Launched) and a big hop (we left a Leaper:
--     State.Leapt): a word; their kick, lines and bubbles are played where they happen (RideController, JumpController).
-- A Tank has no moment: it is told by the ring that barely moves, the line under it and the fish's tag.
-- The words are frames on one screen of our own, over the rider, made once and used again; no text changes size.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Archetypes = require(ReplicatedStorage.Shared.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Fx = require(script.Parent.Parent.Lib.Fx)
local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Parent.UI.Kit)
local RideController = require(script.Parent.RideController)

local ArchetypeController = {}

type Word = {
	Frame: Frame,
	Title: TextLabel,
	Sub: TextLabel,
	At: number, -- os.clock() it came up (-math.huge: free)
	Side: number, -- pixels to the side of the rider, so two at once don't sit on each other
}

local WORDS = 4
local words: { Word } = {}
local live = 0
local nextSide = 1

local function makeWord(parent: Instance): Word
	local frame: Frame = Kit.new("Frame", {
		Name = "ArchetypeWord",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(240, 44),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	local title = Kit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(240, 26),
		TextSize = 24,
		Rotation = -3,
	}, frame, 3)
	local sub = Kit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 27),
		Size = UDim2.fromOffset(240, 15),
		TextSize = 12.5,
	}, frame)
	return { Frame = frame, Title = title, Sub = sub, At = -math.huge, Side = 0 }
end

-- A word by the rider: `title` in `colour`, a smaller line under it ("" for none). It floats up and fades.
local function say(title: string, colour: Color3, sub: string)
	if Config.ArchetypeFeel.Words <= 0 or #words == 0 then
		return
	end
	-- the oldest one is used again
	local word = words[1]
	for _, other in words do
		if other.At < word.At then
			word = other
		end
	end
	if word.At == -math.huge then
		live += 1
	end
	word.At = os.clock()
	nextSide = -nextSide
	word.Side = nextSide * 70
	word.Title.Text = title
	word.Title.TextColor3 = colour
	word.Sub.Text = sub
	word.Frame.Visible = true
end

local function step()
	if live == 0 then
		return
	end
	local f = Config.ArchetypeFeel
	local camera = workspace.CurrentCamera
	local _, root = State.character()
	local point = if camera and root then camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3.5, 0)) else nil
	local now = os.clock()
	for _, word in words do
		if word.At ~= -math.huge then
			local u = (now - word.At) / math.max(f.WordTime, 0.05)
			if u >= 1 or not point or point.Z <= 0 then
				word.At = -math.huge
				word.Frame.Visible = false
				live -= 1
			else
				-- up quickly, then drifting; solid, then gone over the last third
				local rise = f.WordRise * (1 - (1 - u) ^ 3)
				local gone = math.clamp((u - 0.66) / 0.34, 0, 1)
				word.Frame.Position = UDim2.fromOffset(point.X + word.Side, point.Y - 30 - rise)
				word.Title.TextTransparency = gone
				word.Sub.TextTransparency = gone
				for _, label in { word.Title, word.Sub } do
					local stroke = label:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke.Transparency = gone
					end
				end
			end
		end
	end
end

local function percent(share: number): string
	return string.format("+%d%% air", math.floor(share * 100 + 0.5))
end

-- Our own reward (the server's word): the burst of speed, and how it feels
local function onBoost(kind: string, by: number, time: number, oxygen: number, count: number)
	local f = Config.ArchetypeFeel
	local info = Archetypes.Info
	RideController.boost(kind, by, time)
	if kind == "Eat" then
		State.FovPunch = math.max(State.FovPunch, f.EatFov + f.FrenzyFov * count)
		State.KickVelocity = f.EatKick * 2 * math.pi * Config.Jump.LandKickRate
		if count > 0 then
			say(string.format("FRENZY x%d", count + 1), info.Frenzy.Colour, percent(oxygen))
		else
			say("CHOMP!", info.Predator.Colour, percent(oxygen))
		end
	elseif kind == "Smash" then
		State.FovPunch = math.max(State.FovPunch, f.SmashFov)
		if f.SmashShake > 0 then
			RideController.shake(f.SmashShake)
		end
		say("SMASH!", info.Breaker.Colour, percent(oxygen))
	end
end

-- A bite or a smash anywhere, for everyone: the bubbles and the sound, at the place
local function onFx(kind: string, player: Player, fish: Model, at: Vector3, count: number)
	if typeof(at) ~= "Vector3" then
		return
	end
	local f = Config.ArchetypeFeel
	local root = if typeof(fish) == "Instance" and fish:IsA("Model") then fish.PrimaryPart else nil
	local mine = player == Players.LocalPlayer
	if kind == "Eat" then
		if f.EatBubbles > 0 then
			Fx.burst(at, f.EatBubbles, 0, f.EatReach)
		end
		local tier = if root then Config.Tiers[fish:GetAttribute("Tier") :: string] else nil
		Fx.ring(CFrame.new(at), if tier then tier.Colour else Archetypes.Info.Predator.Colour)
		if f.EatSound > 0 then
			local sound = Fx.sound("Chomp", if mine then nil else root)
			if sound then
				-- (a chain bites higher and higher)
				sound.Volume *= f.EatSound
				sound.PlaybackSpeed *= 1 + 0.12 * (if type(count) == "number" then count else 0)
			end
		end
	elseif kind == "Smash" then
		if f.SmashBubbles > 0 then
			Fx.burst(at, f.SmashBubbles, 0, f.SmashReach)
		end
		if f.SmashSound > 0 then
			local sound = Fx.sound("Rumble", if mine then nil else root)
			if sound then
				sound.Volume *= f.SmashSound
				sound.PlaybackSpeed = 0.6
			end
		end
	end
end

function ArchetypeController.Init()
	local gui = Kit.new("ScreenGui", {
		Name = "ArchetypeWords",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	for i = 1, WORDS do
		words[i] = makeWord(gui)
	end
	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any, d: any, e: any)
		if kind == "Boost" and type(a) == "string" and type(b) == "number" and type(c) == "number" then
			onBoost(a, b, c, if type(d) == "number" then d else 0, if type(e) == "number" then e else 0)
		end
	end)
	Net.Fx.OnClientEvent:Connect(function(kind: string, player: Player, fish: Model, at: Vector3, count: number)
		if kind == "Eat" or kind == "Smash" then
			onFx(kind, player, fish, at, count)
		end
	end)
	State.Launched.Event:Connect(function()
		say("LAUNCH!", Archetypes.Info.Fast.Colour, "")
	end)
	State.Leapt.Event:Connect(function()
		say("BIG HOP!", Archetypes.Info.Leaper.Colour, "")
	end)
end

function ArchetypeController.Start()
	RunService:BindToRenderStep("ArchetypeWords", Enum.RenderPriority.Last.Value, step)
end

return ArchetypeController
