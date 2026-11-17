--!strict
-- Each player's furthest distance down the lane (task l1, the land strip's best line). The server keeps it: every
-- quarter second, for a player in the water (State "Free", "Riding" or "Jumping": not on the dock, not drowning), it
-- finds their land and how far along it from their character, as the HUD does (Zones.locate), and raises their best
-- when they are further than ever. Two player attributes carry it to the clients:
--   BestMetres  the furthest depth on the gauge, whole metres (0 until the first dive)
--   BestLands   the same as lands: 2.6 is six tenths through the third land (for the strip's best line)
-- It lasts the session: there are no saves yet. When saves come, these two are what to keep.
-- A client moves its own character, so this is as sure as the rest of the riding; a jump of more than one land in
-- one check is not counted (no fish swims that fast).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Zones = require(ReplicatedStorage.Shared.Zones)

local BestService = {}

local EVERY = 0.25
local IN_WATER = { Free = true, Riding = true, Jumping = true }

local zones: { Zones.Zone } = {}
local last: { [Player]: number } = {} -- the lands at the last check, to refuse a jump of more than a land

local function check(player: Player)
	if not IN_WATER[player:GetAttribute("State") :: string?] then
		last[player] = nil
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local zone, along, metres = Zones.locate(zones, root.Position)
	if not zone then
		return
	end
	local lands = zone.Index - 1 + along
	local before = last[player]
	last[player] = lands
	if before and lands - before > 1 then
		return
	end
	local best = (player:GetAttribute("BestMetres") :: number?) or 0
	local whole = math.floor(metres)
	if whole > best then
		player:SetAttribute("BestMetres", whole)
		player:SetAttribute("BestLands", math.floor(lands * 1000 + 0.5) / 1000)
	end
end

function BestService.Start()
	local json = Net.Folder:GetAttribute("Zones")
	while typeof(json) ~= "string" or json == "" do
		Net.Folder:GetAttributeChangedSignal("Zones"):Wait()
		json = Net.Folder:GetAttribute("Zones")
	end
	zones = Zones.decode(json :: string)
	Net.Folder:GetAttributeChangedSignal("Zones"):Connect(function()
		local fresh = Net.Folder:GetAttribute("Zones")
		if typeof(fresh) == "string" and fresh ~= "" then
			zones = Zones.decode(fresh)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
	while true do
		for _, player in Players:GetPlayers() do
			check(player)
		end
		task.wait(EVERY)
	end
end

return BestService
