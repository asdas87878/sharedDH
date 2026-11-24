--!strict
-- The auras bought and worn (Hugo, 2026-11-24: "make sure you can buy them"; docs/design/auras.md, "Buying"). The
-- client only says which card it pressed (Action "AuraBuy", tier); everything is decided here:
--   the tier is a whole number the game has, exactly the one after the player's own (bought one after another); they are
--   alive, on the dock and at the Auras stall (within Aura.Near of its ring); one ask at a time (Aura.BuyAgain); and
--   they have the coins, which AquariumService.spend takes once or not at all.
-- A bought aura is worn at once and replaces the one before (the player's "Aura" attribute, 0 to 12, which every machine
-- draws and AuraShop reads: the one worn is EQUIPPED, those under it OWNED). It multiplies what the seahorse gives
-- (TrainService, AuraService.multOf): the server's own number is used, never the attribute.
-- Answers on Ride: "AuraBought", tier | "AuraDenied", why ("Off", "Order", "Dock", "Coins", "Busy"). A press on an aura
-- already owned (a late second click) is dropped quietly, as the sub's stand does.
-- Saved by SaveParts (part "Aura": tierOf, setTier).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Auras = require(ReplicatedStorage.Shared.Auras)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local AquariumService = require(script.Parent.AquariumService)
local RideService = require(script.Parent.RideService)

local AuraService = {}

local owned: { [Player]: number } = {}
local asked: { [Player]: number } = {} -- when each last bought

local function wear(player: Player, tier: number)
	owned[player] = tier
	player:SetAttribute("Aura", tier)
end

local function deny(player: Player, why: string)
	Net.Ride:FireClient(player, "AuraDenied", why)
end

-- Alive, on the dock and at the stall (no stall in the place: anywhere on the dock)
local function atStall(player: Player): boolean
	if RideService.stateOf(player) ~= "Dock" then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local stations = dock and dock:FindFirstChild("Stations")
	local stall = stations and stations:FindFirstChild("Auras")
	local ring = stall and (stall:FindFirstChild("Ring") or (stall:IsA("Model") and stall.PrimaryPart))
	if not ring or not ring:IsA("BasePart") then
		return true
	end
	local gap = root.Position - ring.Position
	return Vector3.new(gap.X, 0, gap.Z).Magnitude <= Config.Aura.Near
end

local function buy(player: Player, tier: any)
	local have = owned[player]
	if have == nil or type(tier) ~= "number" or tier ~= tier or tier % 1 ~= 0 then
		return
	end
	if tier < 1 or tier > #Auras.Tiers or tier <= have then
		return
	end
	local c = Config.Aura
	if c.On == 0 then
		return deny(player, "Off")
	end
	if tier ~= have + 1 then
		return deny(player, "Order")
	end
	local price = c.Prices[tier]
	if type(price) ~= "number" or price ~= price or price <= 0 then
		return deny(player, "Off")
	end
	local now = os.clock()
	if now - (asked[player] or -math.huge) < c.BuyAgain then
		return deny(player, "Busy")
	end
	if not atStall(player) then
		return deny(player, "Dock")
	end
	if not AquariumService.spend(player, price) then
		return deny(player, "Coins")
	end
	asked[player] = now
	wear(player, tier)
	Net.Ride:FireClient(player, "AuraBought", tier)
end

-- The aura a player owns and wears (0: none), nil while we don't have the player. For saving. Doesn't yield.
function AuraService.tierOf(player: Player): number?
	return owned[player]
end

-- For saving (SaveParts, part "Aura", which only calls it with a higher tier): put a player at a tier (whole, clamped to
-- the ones there are), no coins taken and nothing said. False for a player we don't have or a tier that is not a number.
-- Doesn't yield.
function AuraService.setTier(player: Player, tier: number): boolean
	if owned[player] == nil or type(tier) ~= "number" or tier ~= tier then
		return false
	end
	wear(player, math.clamp(math.floor(tier), 0, #Auras.Tiers))
	return true
end

-- What a player's aura multiplies the seahorse's Oxygen by (1: none)
function AuraService.multOf(player: Player): number
	local tier = Auras.Tiers[owned[player] or 0]
	return if tier then tier.Mult else 1
end

local function join(player: Player)
	if owned[player] == nil then
		wear(player, 0)
	end
end

function AuraService.Init()
	Players.PlayerAdded:Connect(join)
	Net.Action.OnServerEvent:Connect(function(player: Player, action: any, tier: any)
		if action == "AuraBuy" then
			buy(player, tier)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		asked[player] = nil
	end)
end

function AuraService.Start()
	for _, player in Players:GetPlayers() do
		join(player)
	end
end

return AuraService
