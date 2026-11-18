--!strict
-- The admin panel for playtesting, server side (Hugo, 2026-11-18; docs/sandbox.md, "The admin panel"). The panel is the
-- client's (AdminController, key P); every action is done here, and only for a player who is allowed: anyone in Studio,
-- and in a live server the place's owner (Config.Admin.Owner) and the user ids in Config.Admin.Users. An allowed
-- player carries the attribute Admin (true), so their machine shows the panel; the check below is asked again on every
-- action, never taken from the client.
-- The remote is our own, ReplicatedStorage.Remotes.Admin (client -> server):
--   "EndlessAir", on | "NoFail", on (this player only: the attributes AdminEndlessAir, AdminNoFail, read by RideService)
--   "Max", n (max Oxygen n, the meter full) | "Land", index (into the water at that land's start, onto a fish there)
--   "Fish", id, size, variant (a fish in the hands, as if caught: put it in the tank like any catch)
--   "Fail" (a fail now, from the water) | "Coins", n | "Subs" (every sub bought, the best equipped)
-- and back (server -> that client): "Done", text | "Refused", text, for the panel's status line.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local AquariumService = require(script.Parent.AquariumService)
local FishService = require(script.Parent.FishService)
local RideService = require(script.Parent.RideService)
local SubService = require(script.Parent.SubService)

local AdminService = {}

local VARIANTS = { [""] = true, Silver = true, Gold = true, Rainbow = true }
local MOST_OXYGEN = 100000
local MOST_COINS = 1e12
-- how often one player may act (a held key or a script can't flood the server)
local GAP = 0.1

local remote: RemoteEvent
local owners: { [Player]: boolean } = {} -- the place's owner, found as they join (a group's owner needs a web call)
local lastAt: { [Player]: number } = {}

local function allowed(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.Admin.Users, player.UserId) then
		return true
	end
	return Config.Admin.Owner == 1 and owners[player] == true
end

local function findOwner(player: Player)
	if game.CreatorType == Enum.CreatorType.User then
		owners[player] = player.UserId == game.CreatorId
	elseif game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		owners[player] = ok and rank == 255
	end
end

local function join(player: Player)
	if not RunService:IsStudio() then
		findOwner(player)
	end
	player:SetAttribute("Admin", if allowed(player) then true else nil)
end

local function done(player: Player, text: string)
	remote:FireClient(player, "Done", text)
end

local function refuse(player: Player, text: string)
	remote:FireClient(player, "Refused", text)
end

local function number(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

-- Where a land begins, a little way in along the herd's line, and the way down there
local function landPlace(index: number): { At: Vector3, Along: Vector3 }?
	local first = FishService.landStart(index)
	if not first then
		return nil
	end
	local s = first + 150
	local lift, under = Config.Herd.RideHeight + 6, 8
	local at = FishService.streamPoint(s, lift, under)
	local ahead = FishService.streamPoint(s + 30, lift, under)
	local flat = (ahead - at) * Vector3.new(1, 0, 1)
	return { At = at, Along = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, 1) }
end

-- The fish to seat a player on at a land's start: the commonest kind living there (put there for them, as the
-- sandbox's F does; without it the herd near the spot was often still out of the water and the seat found none)
local function landFish(index: number): string?
	local best: Config.FishType? = nil
	local bestRank = math.huge
	for _, fish in Config.Fish do
		local rank = table.find(Config.TierOrder, fish.Tier) or 99
		if fish.Home == index and (rank < bestRank or (rank == bestRank and best and fish.Id < best.Id)) then
			best, bestRank = fish, rank
		end
	end
	return if best then best.Id else nil
end

local function act(player: Player, kind: any, a: any, b: any, c: any)
	if type(kind) ~= "string" then
		return
	end
	if not allowed(player) then
		return refuse(player, "not an admin")
	end
	local t = os.clock()
	if t - (lastAt[player] or 0) < GAP then
		return
	end
	lastAt[player] = t
	local state = RideService.stateOf(player)
	if kind == "EndlessAir" or kind == "NoFail" then
		if type(a) ~= "boolean" then
			return
		end
		player:SetAttribute("Admin" .. kind, if a then true else nil)
		done(player, (if kind == "NoFail" then "no fail " else "endless air ") .. (if a then "on" else "off"))
	elseif kind == "Max" then
		local n = number(a)
		if not n then
			return
		end
		n = math.clamp(math.floor(n), 1, MOST_OXYGEN)
		RideService.setMax(player, n)
		done(player, "max Oxygen " .. n)
	elseif kind == "Land" then
		local index = number(a)
		if not index or index % 1 ~= 0 or index < 1 or index > #FishService.zones() then
			return refuse(player, "no such land")
		end
		if state == "Carried" or state == "Drowning" or state == nil then
			return refuse(player, "not now (" .. tostring(state) .. ")")
		end
		local place = landPlace(index)
		if not place then
			return refuse(player, "no start for land " .. index)
		end
		RideService.sandboxReset(player, nil, landFish(index), "", place)
		local zone = FishService.zones()[index]
		done(player, "to land " .. index .. (if zone then " (" .. zone.Name .. ")" else ""))
	elseif kind == "Fish" then
		local fish = if type(a) == "string" then Config.FishById[a] else nil
		local size = if type(b) == "string" and Config.SizeScale[b] then b else nil
		local variant = if type(c) == "string" and VARIANTS[c] then c else nil
		if not fish or not size or not variant then
			return refuse(player, "no such fish, size or variant")
		end
		if not RideService.giveCarried(player, { Id = fish.Id, Size = size, Variant = variant }) then
			return refuse(player, "slots full (" .. Config.Tame.Carry .. "): put some in the tank")
		end
		done(
			player,
			string.format("%s %s%s in your hands", size, if variant ~= "" then variant .. " " else "", fish.Name)
		)
	elseif kind == "Fail" then
		if not RideService.forceFail(player) then
			return refuse(player, "only in the water (now " .. tostring(state) .. ")")
		end
		done(player, "failed")
	elseif kind == "Coins" then
		local n = number(a)
		if not n or n <= 0 then
			return
		end
		n = math.min(math.floor(n), MOST_COINS)
		if not player:GetAttribute("Plot") then
			return refuse(player, "no tank (coins live with the tank)")
		end
		AquariumService.give(player, n)
		done(player, "+" .. n .. " coins")
	elseif kind == "Subs" then
		SubService.unlockAll(player)
		done(player, "every sub unlocked")
	end
end

function AdminService.Init()
	local existing = Net.Folder:FindFirstChild("Admin")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
	else
		remote = Instance.new("RemoteEvent")
		remote.Name = "Admin"
		remote.Parent = Net.Folder
	end
	remote.OnServerEvent:Connect(act)
	Players.PlayerRemoving:Connect(function(player)
		owners[player] = nil
		lastAt[player] = nil
	end)
end

function AdminService.Start()
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		task.spawn(join, player)
	end
end

return AdminService
