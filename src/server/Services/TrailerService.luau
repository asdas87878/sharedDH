--!strict
-- The trailer mode, server side (Studio only; Config.Trailer.On; docs/design/trailer.md): what a shot of the game-page
-- video needs of the server, asked for by TrailerController through the RemoteFunction Remotes.Trailer. Everything here
-- ends with Play, and in Studio saving is the stand-in store, so nothing of it is ever kept.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local AquariumService = require(script.Parent.AquariumService)
local FishService = require(script.Parent.FishService)
local RideService = require(script.Parent.RideService)
local SubService = require(script.Parent.SubService)
local TrainService = require(script.Parent.TrainService)

local TrailerService = {}

local PATH_STEP, PATH_POINTS = 15, 120

local function pivot(player: Player, at: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(at)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local asks: { [string]: (Player, any) -> any } = {}

function asks.Setup(player: Player, a: any): any
	player:SetAttribute("AdminEndlessAir", true)
	player:SetAttribute("AdminNoFail", true)
	RideService.setMax(player, a.Max or 5000)
	SubService.unlockAll(player)
	if a.Coins and a.Coins > 0 then
		AquariumService.give(player, a.Coins)
	end
	return true
end

-- onto a fish of the kind asked for, some way into a land, with others ahead of it: the way ahead comes back
function asks.Ride(player: Player, a: any): any
	local start = FishService.landStart(a.Land)
	if not start then
		return nil
	end
	local s = start + (a.Along or 250)
	local kind = Config.FishById[a.Fish]
	if not kind then
		return nil
	end
	-- (a giant swims as much higher as its belly needs: RideController, State.RideLift, keeps it there)
	local tall = kind.Size.Y * (Config.BaseScale[a.Fish] or 1) * (Config.SizeScale[a.Size or "Normal"] or 1)
	local lift = Config.Herd.RideHeight + 6 + math.max(0, tall / 2 + 4) + (a.Lift or 0)
	local at = FishService.streamPoint(s, lift, 8)
	local flat = (FishService.streamPoint(s + 30, lift, 8) - at) * Vector3.new(1, 0, 1)
	workspace:SetAttribute("TestSize", a.Size or "Normal")
	RideService.sandboxReset(player, nil, a.Fish, a.Variant or "", { At = at, Along = flat.Unit })
	for _, h in a.Herd or {} do
		local kind = Config.FishById[h.Id]
		if kind then
			local w = FishService.put(kind, s + h.Ahead, h.Share or 0, h.Lift or Config.Herd.RideHeight)
			if h.Target then
				w.Model:AddTag("TrailerTarget")
			end
		end
	end
	local path = {}
	for i = 0, PATH_POINTS do
		table.insert(path, FishService.streamPoint(s + i * PATH_STEP, lift, 8))
	end
	return path
end

function asks.Home(player: Player, a: any): any
	if RideService.stateOf(player) ~= "Dock" then
		RideService.sendHome(player)
	end
	return true
end

function asks.Pivot(player: Player, a: any): any
	pivot(player, a)
	return true
end

function asks.Give(player: Player, a: any): any
	return AquariumService.give(player, 0, a)
end

function asks.Level(player: Player, a: any): any
	local test = ServerStorage:FindFirstChild("TrainerTest")
	if test and test:IsA("BindableFunction") then
		return test:Invoke("level", player.UserId, a)
	end
	return TrainService.setLevel(player, a)
end

function asks.Trainer(player: Player, a: any): any
	local test = ServerStorage:FindFirstChild("TrainerTest")
	return if test and test:IsA("BindableFunction") then test:Invoke("info", player.UserId) else nil
end

function TrailerService.Init()
	if not RunService:IsStudio() or Config.Trailer.On == 0 then
		return
	end
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Trailer"
	remote.OnServerInvoke = function(player, kind, a)
		local ask = if type(kind) == "string" then asks[kind] else nil
		return if ask then ask(player, a) else nil
	end
	remote.Parent = Net.Folder
end

return TrailerService
