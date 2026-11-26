--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxBadges = game:GetService("BadgeService")

local Badges = require(ReplicatedStorage.Shared.Badges)
local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)

local BadgeService = {}

type Badge = { Key: string, Id: number }
type Session = { Requested: { [number]: boolean }, Trainer: RBXScriptConnection? }

local sessions: { [Player]: Session } = {}
local zoneBadges = {
	["TWILIGHT"] = Badges.Twilight,
	["MIDNIGHT"] = Badges.Midnight,
	["THE UNDERWORLD"] = Badges.Underworld,
}
local inWater = { Free = true, Riding = true, Jumping = true }

local function award(player: Player, badge: Badge)
	local session = sessions[player]
	local id = badge.Id
	if Config.Badges.On ~= 1 or id <= 0 or not session or session.Requested[id] then
		return
	end
	-- Claim the slot before any API yields. Keep it after success or confirmed ownership.
	session.Requested[id] = true
	task.defer(function()
		for attempt = 1, 3 do
			if sessions[player] ~= session or Config.Badges.On ~= 1 then
				return
			end
			local ok, owned = pcall(RobloxBadges.UserHasBadgeAsync, RobloxBadges, player.UserId, id)
			if ok and owned then
				return
			end
			if ok and sessions[player] == session and Config.Badges.On == 1 then
				local awarded, result = pcall(RobloxBadges.AwardBadgeAsync, RobloxBadges, player.UserId, id)
				if awarded and result then
					return
				end
			end
			if attempt < 3 then
				task.wait(5)
			end
		end
		if sessions[player] == session then
			warn(`[BadgeService] Could not confirm {badge.Key} for user {player.UserId}`)
		end
	end)
end

local function watch(player: Player)
	if sessions[player] then
		return
	end
	local session: Session = { Requested = {}, Trainer = nil }
	sessions[player] = session
	local function checkTrainer()
		if player:GetAttribute("TrainerLevel") == 12 then
			award(player, Badges.MaxSeahorse)
		end
	end
	session.Trainer = player:GetAttributeChangedSignal("TrainerLevel"):Connect(checkTrainer)
	checkTrainer()
end

function BadgeService.Start()
	if Config.Badges.On ~= 1 then
		return
	end
	local AquariumService = require(script.Parent.AquariumService)
	local FishService = require(script.Parent.FishService)
	local RideService = require(script.Parent.RideService)

	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session and session.Trainer then
			session.Trainer:Disconnect()
		end
		sessions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	-- All Init methods have run, so preserve the lesson's callback if it set one.
	local onTamed = RideService.OnTamed
	RideService.OnTamed = function(player, fish)
		award(player, Badges.FirstCatch)
		if onTamed then
			onTamed(player, fish)
		end
	end

	-- FuseService calls this function on the module. Schedule the award after the transaction returns success.
	local fuse = AquariumService.fuse
	AquariumService.fuse = function(player, picks)
		local result, reason = fuse(player, picks)
		if result then
			award(player, Badges.FirstFuse)
		end
		return result, reason
	end

	while true do
		task.wait(Config.Badges.ZoneEvery)
		local zones = FishService.zones()
		for player in sessions do
			if inWater[RideService.stateOf(player)] then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local zone = Zones.locate(zones, root.Position)
					local badge = zone and zoneBadges[zone.Name]
					if badge then
						award(player, badge)
					end
				end
			end
		end
	end
end

return BadgeService
