--!strict
-- The Fuse machine (Hugo, 2026-11-25: "add integration to the fuse machine as well, same standing on circle mechanic";
-- docs/design/fusing.md). Three fish of one kind become one: the biggest stays, as it is, and grows one size; the other
-- two are used up. The client only says which three it put in (Action "Fuse", { pick, pick, pick }; a pick is "T" and
-- a tank fish's key or "H" and a carried fish's, both from the server's own lists); everything is decided here:
--   the ask is three different names and nothing else; one ask at a time (Fuse.AskGap: the one that follows a fusing
--   that soon is the same click and is not answered); the player is alive, on the dock, on neither the seahorse nor a
--   fish in the tank, and within Fuse.Near of the machine's ring (Dock.Stations.Fuse: a part named Ring, or the station
--   Model's PrimaryPart; no ring in the place: no fusing); and the rules, the fish and the price, checked and done in
--   one step by AquariumService.fuse, so it can't be done by halves or twice.
-- Answers on Ride: "Fused", what came of it (AquariumService.Fused) | "FuseDenied", why ("Off", "Dock", "Dead", "Busy",
-- "Far", and the step's own: "Gone", "Equipped", "Ride", "Kind", "Size", "Top", "Coins").
-- Nothing of its own to save: the fish are in the save's tank part, the hands with them, in one snapshot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Fuse = require(ReplicatedStorage.Shared.Fuse)
local Net = require(ReplicatedStorage.Shared.Net)
local AquariumService = require(script.Parent.AquariumService)
local RideService = require(script.Parent.RideService)

local FuseService = {}

local LONGEST = 24 -- letters in a pick's name
local HIGH = 60 -- studs over or under the ring that still count as at the machine
local fusedAt: { [Player]: number } = {} -- when each last fused
local askedAt: { [Player]: number } = {} -- and last asked
local REFUSED_GAP = 0.1 -- asks are looked at no more often than this, seconds

local function ringOf(): BasePart?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local stations = dock and dock:FindFirstChild("Stations")
	local machine = stations and stations:FindFirstChild("Fuse")
	local ring = machine and (machine:FindFirstChild("Ring") or (machine:IsA("Model") and machine.PrimaryPart))
	return if ring and ring:IsA("BasePart") then ring else nil
end

-- Why this player is not at the machine, ready to use it, or nil
function FuseService.atMachine(player: Player): string?
	if RideService.stateOf(player) ~= "Dock" then
		return "Dock"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return "Dead"
	end
	if player:GetAttribute("TankRide") ~= nil or player:GetAttribute("TrainerRide") ~= nil then
		return "Busy"
	end
	local ring = ringOf()
	if not ring then
		return "Far"
	end
	local gap = root.Position - ring.Position
	if Vector3.new(gap.X, 0, gap.Z).Magnitude > Config.Fuse.Near or math.abs(gap.Y) > HIGH then
		return "Far"
	end
	return nil
end

-- The three names of an ask, or nil when it is anything else
local function read(picks: any): { string }?
	if type(picks) ~= "table" then
		return nil
	end
	local n = 0
	for _ in picks do
		n += 1
		if n > Fuse.Count then
			return nil
		end
	end
	if n ~= Fuse.Count then
		return nil
	end
	local out: { string } = {}
	for i = 1, Fuse.Count do
		local pick = picks[i]
		if
			type(pick) ~= "string"
			or #pick > LONGEST
			or not string.match(pick, "^[TH]%d+$")
			or table.find(out, pick)
		then
			return nil
		end
		table.insert(out, pick)
	end
	return out
end

local function ask(player: Player, asked: any)
	local picks = read(asked)
	local now = os.clock()
	if
		not picks
		or now - (fusedAt[player] or -math.huge) < Config.Fuse.AskGap
		or now - (askedAt[player] or -math.huge) < REFUSED_GAP
	then
		return
	end
	askedAt[player] = now
	local why = if Config.Fuse.On == 0 then "Off" else FuseService.atMachine(player)
	local fused: AquariumService.Fused? = nil
	if not why then
		fused, why = AquariumService.fuse(player, picks)
	end
	if fused then
		fusedAt[player] = now
		Net.Ride:FireClient(player, "Fused", fused)
	else
		Net.Ride:FireClient(player, "FuseDenied", why)
	end
end

function FuseService.Init()
	Net.Action.OnServerEvent:Connect(function(player: Player, action: any, picks: any)
		if action == "Fuse" then
			ask(player, picks)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		fusedAt[player] = nil
		askedAt[player] = nil
	end)
end

return FuseService
