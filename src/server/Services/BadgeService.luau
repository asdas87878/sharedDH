--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxBadges = game:GetService("BadgeService")

local Badges = require(ReplicatedStorage.Shared.Badges)
local Config = require(ReplicatedStorage.Shared.Config)
local SubTrip = require(ReplicatedStorage.Shared.SubTrip)
local Zones = require(ReplicatedStorage.Shared.Zones)

local BadgeService = {}

type Badge = { Key: string, Id: number }
type DiveSample = { Position: Vector3, Progress: number, At: number }
type Drop = { Land: number, Position: Vector3, StartsAt: number, EndsAt: number }
type Session = {
	Requested: { [number]: boolean },
	Trainer: RBXScriptConnection?,
	LastDive: DiveSample?,
	WasCarried: boolean,
	Drop: Drop?,
}

local sessions: { [Player]: Session } = {}
local zoneBadges = {
	["TWILIGHT"] = Badges.Twilight,
	["MIDNIGHT"] = Badges.Midnight,
	["THE UNDERWORLD"] = Badges.Underworld,
}
local inWater = { Free = true, Riding = true, Jumping = true }
local horizontal = Vector3.new(1, 0, 1)

local function award(player: Player, badge: Badge)
	local session = sessions[player]
	local id = badge.Id
	if Config.Badges.On ~= 1 or id <= 0 or not session or session.Requested[id] then
		return
	end
	-- One worker per badge. It keeps the slot between retries and after confirmed ownership.
	session.Requested[id] = true
	task.defer(function()
		local attempt = 0
		while sessions[player] == session and Config.Badges.On == 1 do
			attempt += 1
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
			if sessions[player] ~= session or Config.Badges.On ~= 1 then
				break
			end
			if attempt == 3 then
				warn(`[BadgeService] Could not confirm {badge.Key} for user {player.UserId}. Retrying after cooldown.`)
				attempt = 0
				task.wait(Config.Badges.RetryCooldown)
			else
				task.wait(5)
			end
		end
		session.Requested[id] = nil
	end)
end

local function watch(player: Player)
	if sessions[player] then
		return
	end
	local session: Session = { Requested = {}, WasCarried = false }
	sessions[player] = session
	local function checkTrainer()
		if player:GetAttribute("TrainerLevel") == 12 then
			award(player, Badges.MaxSeahorse)
		end
	end
	session.Trainer = player:GetAttributeChangedSignal("TrainerLevel"):Connect(checkTrainer)
	checkTrainer()
end

-- SubService publishes the trip it planned. Only an observed exit from RideService's Carried state can use it.
local function dropOf(player: Player): Drop?
	local encoded = player:GetAttribute("SubTrip")
	local trip = if type(encoded) == "string" then SubTrip.decode(encoded) else nil
	if not trip then
		return nil
	end
	local _, _, _, starts, ends = SubTrip.times(trip)
	return {
		Land = trip.Land,
		Position = SubTrip.at(trip, SubTrip.dropDistance(trip)),
		StartsAt = trip.Start + starts,
		EndsAt = trip.Start + ends + Config.Sub.Late + Config.Badges.ZoneEvery * 4,
	}
end

local function checkDive(
	player: Player,
	session: Session,
	zones: { Zones.Zone },
	state: string?,
	inside: (Vector3) -> number
)
	if not inWater[state] then
		session.LastDive = nil
		session.Drop = nil
		session.WasCarried = state == "Carried"
		return
	end
	if session.WasCarried then
		session.WasCarried = false
		session.Drop = dropOf(player)
	end
	local now = workspace:GetServerTimeNow()
	local drop = session.Drop
	if drop and now > drop.EndsAt then
		session.Drop = nil
		drop = nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local position = root.Position
	local zone, along = Zones.locate(zones, position)
	if not zone or inside(position) < 0 then
		return
	end
	local progress = zone.Index - 1 + along
	local inZone = math.abs(zone.Frame:PointToObjectSpace(position).Z) <= zone.Length / 2
	local atDrop = drop
		and zone.Index == drop.Land
		and inZone
		and now >= drop.StartsAt
		and (position - drop.Position).Magnitude <= Config.Badges.SubDropRadius
	local last = session.LastDive
	if atDrop then
		session.Drop = nil
	elseif last then
		-- In the gap, keep tracking movement but only count a badge once inside its zone. A rejected
		-- sample never becomes the next baseline, even if the player waits at the new position.
		local elapsed = math.min(now - last.At, Config.Badges.ZoneEvery * 2)
		local limit = Config.Badges.ZoneSpeed * elapsed + Config.Jump.GrabRange
		if math.abs(progress - last.Progress) > 1 or ((position - last.Position) * horizontal).Magnitude > limit then
			return
		end
	elseif zone.Index ~= 1 then
		return
	end
	session.LastDive = { Position = position, Progress = progress, At = now }
	local badge = zoneBadges[zone.Name]
	if badge and inZone and position.Y <= Config.Oxygen.SurfaceY then
		award(player, badge)
	end
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
		for player, session in sessions do
			checkDive(player, session, zones, RideService.stateOf(player), FishService.inside)
		end
	end
end

return BadgeService
