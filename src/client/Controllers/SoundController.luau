--!strict
-- The game's sound (the play passes, 2026-11-24: the hub was silent and the sea had only Roblox's own character
-- sounds; the user: "Fix the others"). Every sound is from Roblox's own licensed catalogue (APM's music, Pro Sound
-- Effects), so nothing was uploaded; each id and its loudness is a line of Config.Sounds (0: that one is off).
--   Music   one steel-drum tune, all the time; under the water it is quieter and its highs are cut, as heard from below
--   Sea     the waves on the hub; Under: the low underwater sound, only in the water
--   the moments: a hop leaving, a catch (higher for a rarer fish and for each more in the dive; twice for a great one),
--     a fish put in the tank or sold, a level, stage or sub bought, an Index reward, a refusal, the air nearly out, a
--     fish left nearly tamed, a button pressed on the dock
--   the small button under the hub's two turns it all off and on (for the visit)
-- Only this machine's: nothing here is the server's.
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local HubButtons = require(script.Parent.Parent.UI.HubButtons)

local SoundController = {}

-- what the server says, and the moment heard for it
local HEARD: { [string]: string } = {
	Deposited = "Deposit",
	Sold = "Sold",
	PlotUp = "Up",
	PlotNo = "No",
	SubBought = "Up",
	SubDenied = "No",
	AuraBought = "Up",
	AuraDenied = "No",
}

local group: SoundGroup
local cut: EqualizerSoundEffect
local all: SoundGroup -- everything here, so one number is the whole of it
local muted = false
local runOf = 0 -- catches this dive
local loops: { [string]: Sound } = {}
local lastAt: { [string]: number } = {}
local AGAIN = 0.12 -- the same moment isn't heard twice inside this, seconds
local wet = 0 -- how far under we are heard to be, 0 to 1 (eased)

local function idOf(id: number): string
	return "rbxassetid://" .. id
end

local function loop(name: string, id: number, parent: Instance?): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = idOf(id)
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = if parent and parent:IsA("SoundGroup") then parent else all
	s.Parent = SoundService
	s:Play()
	loops[name] = s
	return s
end

-- One of the moments (Config.Sounds.Moments), heard once
function SoundController.play(name: string, speed: number?)
	local m = Config.Sounds.Moments[name]
	if Config.Sounds.On == 0 or not m or m.Volume <= 0 or muted or not all then
		return
	end
	local now = os.clock()
	if now - (lastAt[name] or -math.huge) < AGAIN then
		return
	end
	lastAt[name] = now
	local s = Instance.new("Sound")
	s.SoundGroup = all
	s.Name = name
	s.SoundId = idOf(m.Id)
	s.Volume = m.Volume
	s.PlaybackSpeed = m.Speed * (speed or 1)
	s.Parent = SoundService
	s:Play()
	-- (its length from when it plays, not from when it began to load)
	Debris:AddItem(s, m.Length + 3)
end

-- All of it off, or on again
function SoundController.mute(on: boolean)
	muted = on
	if all then
		all.Volume = if on then 0 else 1
	end
end

function SoundController.muted(): boolean
	return muted
end

-- The chime of a catch
local function caught(id: string, size: any, variant: any)
	local c = Config.Sounds
	local kind = Config.FishById[id]
	local tier = if kind then table.find(Config.TierOrder, kind.Tier) or 1 else 1
	local steps = (tier - 1 + math.min(runOf, c.CatchRun)) * c.CatchStep
	runOf += 1
	SoundController.play("Catch", 2 ^ (steps / 12))
	if Config.greatCatch(id, size, variant) then
		for i = 1, 2 do
			task.delay(0.16 * i, SoundController.play, "Catch", 2 ^ ((steps + 4 * i) / 12))
		end
	end
end

local function update(dt: number)
	local c = Config.Sounds
	local want = if State.inWater() or (State.Mode == "Carried" and not State.SubAloft) then 1 else 0 -- (in a sub's hold we are under too)
	wet += (want - wet) * (1 - math.exp(-dt * c.Ease))
	loops.Music.Volume = c.MusicVolume * (1 + (c.MusicUnder - 1) * wet)
	loops.Sea.Volume = c.SeaVolume * (1 - wet)
	loops.Under.Volume = c.UnderVolume * wet
	cut.HighGain = c.CutHigh * wet
	cut.MidGain = c.CutMid * wet
end

-- The buttons on the dock: any press of one ticks (not Roblox's own stick and jump on a phone)
local function watchButton(d: Instance)
	if d:IsA("GuiButton") then
		local screen = d:FindFirstAncestorOfClass("ScreenGui")
		if screen and (screen.Name == "TouchGui" or screen.Name == "ContextActionGui") then
			return
		end
		d.Activated:Connect(function()
			if State.Mode == "Dock" then
				SoundController.play("Click")
			end
		end)
	end
end

function SoundController.Start()
	local c = Config.Sounds
	HubButtons.Pressed:Connect(function(name: string)
		if name == "Sound" then
			SoundController.mute(not muted)
			HubButtons.sound(not muted)
		end
	end)
	if c.On == 0 then
		return
	end
	all = Instance.new("SoundGroup")
	all.Name = "Game"
	all.Volume = if muted then 0 else 1
	all.Parent = SoundService
	group = Instance.new("SoundGroup")
	group.Name = "Music"
	group.Volume = 1
	group.Parent = all
	cut = Instance.new("EqualizerSoundEffect")
	cut.LowGain, cut.MidGain, cut.HighGain = 0, 0, 0
	cut.Parent = group
	loop("Music", c.Music, group)
	loop("Sea", c.Sea)
	loop("Under", c.Under)
	RunService.RenderStepped:Connect(update)

	State.ModeChanged.Event:Connect(function(mode: string, old: string)
		if mode == "Jumping" and old == "Riding" then -- (going in has its own splash: Feel.sound)
			SoundController.play("Hop")
		elseif old == "Dock" then
			runOf = 0
		end
	end)
	State.Tamed.Event:Connect(caught)
	Net.Ride.OnClientEvent:Connect(function(what: string, action: any)
		local name = HEARD[what]
		if name then
			SoundController.play(name)
		elseif
			what == "Denied" and (action == "Tame" or action == "Equip" or action == "Hold" or action == "Place")
		then
			SoundController.play("No")
		end
	end)
	Net.Index.OnClientEvent:Connect(function(what: string)
		if what == "Paid" then
			SoundController.play("Claim")
		end
	end)
	task.spawn(function()
		local trainer: any = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Trainer", 30)
		if trainer and trainer:IsA("RemoteEvent") then
			trainer.OnClientEvent:Connect(function(what: string)
				if what == "Up" then
					SoundController.play("Up")
				elseif what == "UpNo" then
					SoundController.play("No")
				end
			end)
		end
	end)
	-- (so the first of each is heard as it happens, not once it has loaded)
	task.spawn(function()
		local load: { Instance } = {}
		for _, m in c.Moments do
			local s = Instance.new("Sound")
			s.SoundId = idOf(m.Id)
			table.insert(load, s)
		end
		ContentProvider:PreloadAsync(load)
	end)
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, d in gui:GetDescendants() do
		watchButton(d)
	end
	gui.DescendantAdded:Connect(watchButton)
end

return SoundController
