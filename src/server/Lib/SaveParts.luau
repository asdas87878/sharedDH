--!strict
-- What saving keeps of a player, and the services' own functions it uses for it (SaveService's parts; the user,
-- 2026-11-23). The services know nothing of saving: they only say what a player has and take it back.
--   Tank     the coins, the plot's stage and the tank's fish (AquariumService.dump, restore)
--   Oxygen   the trained Oxygen, on top of what everyone starts with (RideService.trainedOxygen, setTrainedOxygen)
--   Trainer  the seahorse's level (TrainService.levelOf, setLevel)
--   Sub      the subs bought and the one equipped (SubService.tierOf, equipOf, setSub)
--   Best     the furthest they have been (BestService's two attributes, which are where it keeps them)
-- ON is the switch, off until it has been checked: off, nothing is saved and nothing can be bought (PurchaseService
-- gives nothing without a save). In Studio the workspace's "SaveOn" attribute, set before Play, turns it on.
-- All of them or none: coins kept without what they bought would be lost coins, and the other way round free things.
local RunService = game:GetService("RunService")

local Services = script.Parent.Parent.Services
local AquariumService = require(Services.AquariumService) :: any
local RideService = require(Services.RideService) :: any
local SubService = require(Services.SubService) :: any
local TrainService = require(Services.TrainService) :: any

local SaveParts = {}

local ON = false

type Join = (name: string, dump: (player: Player) -> any?, restore: (player: Player, kept: any) -> ()) -> ()

-- The functions it needs, as service and name: not there, nothing is joined
local NEEDS = {
	{ "AquariumService", AquariumService, { "dump", "restore", "give" } },
	{ "RideService", RideService, { "trainedOxygen", "setTrainedOxygen", "grantOxygen" } },
	{ "TrainService", TrainService, { "levelOf", "setLevel" } },
	{ "SubService", SubService, { "tierOf", "equipOf", "setSub" } },
} :: { { any } }

local function missing(): string?
	for _, need in NEEDS do
		for _, name in need[3] do
			if type(need[2][name]) ~= "function" then
				return `{need[1]}.{name}`
			end
		end
	end
	return nil
end

function SaveParts.join(part: Join)
	if not (ON or (RunService:IsStudio() and workspace:GetAttribute("SaveOn") == true)) then
		return
	end
	local lacking = missing()
	if lacking then
		warn(`[SaveParts] nothing is saved: {lacking} is not there`)
		return
	end
	part("Tank", AquariumService.dump, function(player, kept)
		assert(AquariumService.restore(player, kept) == true, "the tank was not given back")
	end)
	part("Oxygen", RideService.trainedOxygen, function(player, kept)
		RideService.setTrainedOxygen(player, (RideService.trainedOxygen(player) or 0) + kept)
	end)
	part("Trainer", TrainService.levelOf, function(player, kept)
		TrainService.setLevel(player, math.max(TrainService.levelOf(player) or 1, kept))
	end)
	part("Sub", function(player)
		local tier = SubService.tierOf(player)
		return if tier then { Tier = tier, Equip = SubService.equipOf(player) } else nil
	end, function(player, kept)
		if kept.Tier > (SubService.tierOf(player) or 0) then
			SubService.setSub(player, kept.Tier, kept.Equip)
		end
	end)
	part("Best", function(player)
		return {
			Metres = player:GetAttribute("BestMetres") or 0,
			Lands = player:GetAttribute("BestLands") or 0,
		}
	end, function(player, kept)
		if kept.Metres > ((player:GetAttribute("BestMetres") :: number?) or 0) then
			player:SetAttribute("BestMetres", kept.Metres)
			player:SetAttribute("BestLands", kept.Lands)
		end
	end)
end

return SaveParts
