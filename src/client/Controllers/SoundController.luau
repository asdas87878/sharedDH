--!strict
-- The game's sound (the play passes, 2026-11-24: the hub was silent and the sea had only Roblox's own character
-- sounds; the user: "Fix the others"). Every sound is from Roblox's own licensed catalogue (APM's music, Pro Sound
-- Effects), so nothing was uploaded; each id and its loudness is a line of Config.Sounds (0: that one is off).
--   Music   one steel-drum tune, all the time; under the water it is quieter and its highs are cut, as heard from below
--   Sea     the waves on the hub; Under: the low underwater sound, only in the water
--   the moments: a hop leaving, a catch, a fish put in the tank, a button pressed on the dock
-- Only this machine's: nothing here is the server's.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)

local SoundController = {}

local group: SoundGroup
local cut: EqualizerSoundEffect
local loops: { [string]: Sound } = {}
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
	if parent and parent:IsA("SoundGroup") then
		s.SoundGroup = parent
	end
	s.Parent = SoundService
	s:Play()
	loops[name] = s
	return s
end

-- One of the moments (Config.Sounds.Moments), heard once
function SoundController.play(name: string, speed: number?)
	local m = Config.Sounds.Moments[name]
	if Config.Sounds.On == 0 or not m or m.Volume <= 0 then
		return
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = idOf(m.Id)
	s.Volume = m.Volume
	s.PlaybackSpeed = m.Speed * (speed or 1)
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, m.Length)
end

local function update(dt: number)
	local c = Config.Sounds
	local want = if State.inWater() then 1 else 0
	wet += (want - wet) * (1 - math.exp(-dt * c.Ease))
	loops.Music.Volume = c.MusicVolume * (1 + (c.MusicUnder - 1) * wet)
	loops.Sea.Volume = c.SeaVolume * (1 - wet)
	loops.Under.Volume = c.UnderVolume * wet
	cut.HighGain = c.CutHigh * wet
	cut.MidGain = c.CutMid * wet
end

-- The buttons on the dock: any press of one ticks (not the whole-screen one the catch screen lies under)
local function watchButton(d: Instance)
	if d:IsA("GuiButton") and d.Name ~= "Hit" then
		d.Activated:Connect(function()
			if State.Mode == "Dock" then
				SoundController.play("Click")
			end
		end)
	end
end

function SoundController.Start()
	local c = Config.Sounds
	if c.On == 0 then
		return
	end
	group = Instance.new("SoundGroup")
	group.Name = "Music"
	group.Parent = SoundService
	cut = Instance.new("EqualizerSoundEffect")
	cut.LowGain, cut.MidGain, cut.HighGain = 0, 0, 0
	cut.Parent = group
	loop("Music", c.Music, group)
	loop("Sea", c.Sea)
	loop("Under", c.Under)
	RunService.RenderStepped:Connect(update)

	State.ModeChanged.Event:Connect(function(mode: string, old: string)
		if mode == "Jumping" and old ~= "Dock" then -- (going in has its own splash: Feel.sound)
			SoundController.play("Hop")
		end
	end)
	State.Tamed.Event:Connect(function()
		SoundController.play("Catch")
	end)
	Net.Ride.OnClientEvent:Connect(function(what: string)
		if what == "Deposited" then
			SoundController.play("Deposit")
		end
	end)
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, d in gui:GetDescendants() do
		watchButton(d)
	end
	gui.DescendantAdded:Connect(watchButton)
end

return SoundController
