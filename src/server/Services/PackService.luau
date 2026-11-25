--!strict
-- What packs and passes leave with a player, and the server's boost (the user, 2026-11-25: the Great White pack, "1 hour
-- x2 oxygen, cash and luck for the whole server"; luck is later; docs/design/starter-packs.md). PurchaseService calls in
-- here; nothing is asked of the client.
--   Once: packs sold once an account (Products' Once): kept in the save's part "Packs", the player's "Pack" .. key
--   attribute says so and the Shop says OWNED. A receipt for one already had is still given: they paid.
--   The boost: Config.Boost's shares on what the seahorse trains and the tank earns, for everyone in this server until
--   the workspace's "BoostEnds" (os.time, seconds; nil: none), "BoostBy" who bought it. Two bought add their time, never
--   their shares, up to Boost.Most from now. The buyer's own end is saved: a server they join before it is boosted until
--   then (rejoining never adds time).
--   Passes: PurchaseService asks Roblox which are owned and says so here (the player's "Pass" .. what it gives).
-- Nothing here requires another service (the trainer, the tank and the save ask it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config) :: any

local PackService = {}

type Record = { Once: { [string]: boolean }, Ends: number }

local records: { [Player]: Record } = setmetatable({}, { __mode = "k" }) :: any
local ends = 0 -- os.time() the server's boost ends

local function record(player: Player): Record
	local r = records[player]
	if not r then
		r = { Once = {}, Ends = 0 }
		records[player] = r
	end
	return r
end

local function running(): boolean
	return Config.Boost.On ~= 0 and os.time() < ends
end

local function setEnds(at: number, by: string)
	if at <= ends then
		return
	end
	ends = at
	workspace:SetAttribute("BoostBy", by)
	workspace:SetAttribute("BoostEnds", at)
end

-- A bought boost, so many seconds more for the server; the buyer keeps its end
function PackService.boost(player: Player, seconds: number)
	local now = os.time()
	setEnds(math.min(math.max(ends, now) + seconds, now + Config.Boost.Most), player.DisplayName)
	record(player).Ends = ends
end

function PackService.once(player: Player, key: string)
	record(player).Once[key] = true
	player:SetAttribute("Pack" .. key, true)
end

function PackService.pass(player: Player, gives: string)
	player:SetAttribute("Pass" .. gives, true)
end

-- What trained Oxygen and the tank's coins are multiplied by now
function PackService.oxygenMult(player: Player): number
	local mult = if running() then Config.Boost.Oxygen else 1
	return if player:GetAttribute("PassDoubleOxygen") == true then mult * 2 else mult
end

function PackService.cashMult(): number
	return if running() then Config.Boost.Cash else 1
end

-- For saving (SaveParts, part "Packs"); there is nothing to wait for
function PackService.dump(player: Player): { [string]: any }?
	if player.Parent ~= Players then
		return nil
	end
	local r = record(player)
	return { Once = table.clone(r.Once), Ends = r.Ends }
end

function PackService.restore(player: Player, kept: any): boolean
	if type(kept) ~= "table" then
		return true
	end
	if type(kept.Once) == "table" then
		for key, had in kept.Once do
			if type(key) == "string" and had == true then
				PackService.once(player, key)
			end
		end
	end
	local at = kept.Ends
	if type(at) == "number" and at == at and at > os.time() then
		at = math.min(at, os.time() + Config.Boost.Most)
		record(player).Ends = math.max(record(player).Ends, at)
		setEnds(at, player.DisplayName)
	end
	return true
end

return PackService
