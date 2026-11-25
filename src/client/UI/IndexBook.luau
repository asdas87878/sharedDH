--!strict
-- The player's Index as the server last sent it, and every sum the window draws from it (NULLROOM task h2; its own
-- file since i1, 2026-11-25, so the two windows, UI.IndexWindow and the old UI.IndexOld, count the same).
-- Nothing here decides anything: what is found and what is claimed is the server's (IndexService, the Index remote:
-- Net.luau), sent whole after every change; `ask` only asks. For the session only: the game has no saves yet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Saddles = require(ReplicatedStorage.Shared.Saddles)
local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Kit)

local IndexBook = {}

local found: { [string]: number } = {} -- fish id -> how many of its looks they have caught
local claimedKinds: { [string]: boolean } = {} -- fish id -> its reward is paid
local claimedLands: { [string]: boolean } = {} -- the land as a string -> its set's reward is paid

-- Kinds: every kind shown for a land; Set: the ones that count toward its whole set
export type Land = { Kinds: { Config.FishType }, Set: { Config.FishType } }
IndexBook.Lands = {} :: { Land }
local lands = IndexBook.Lands
local total = 0 -- every kind of the Index, all lands together

-- Reads the lands and their kinds from Config (again: the switches in Config.Index are read live)
function IndexBook.roster()
	table.clear(lands)
	for land = 1, Config.indexLands() do
		table.insert(lands, { Kinds = Config.indexKinds(land), Set = Config.indexSet(land) })
	end
	total = Config.indexCount()
end

-- The server's word: the whole Index
function IndexBook.read(looks: { [string]: number }, kinds: { [string]: boolean }, whole: { [string]: boolean })
	found, claimedKinds, claimedLands = looks, kinds, whole
end

function IndexBook.has(id: string): boolean
	return found[id] ~= nil
end

-- How many of a kind's looks (size and colour) are caught
function IndexBook.looks(id: string): number
	return found[id] or 0
end

function IndexBook.paid(id: string): boolean
	return claimedKinds[id] == true
end

function IndexBook.landPaid(land: number): boolean
	return claimedLands[tostring(land)] == true
end

function IndexBook.total(): number
	return total
end

function IndexBook.owedKind(id: string): boolean
	return found[id] ~= nil and not claimedKinds[id]
end

-- How many kinds of a land's set are found, and how many it has
function IndexBook.setOf(land: number): (number, number)
	local entry = lands[land]
	if not entry then
		return 0, 0
	end
	local have = 0
	for _, fish in entry.Set do
		if found[fish.Id] then
			have += 1
		end
	end
	return have, #entry.Set
end

function IndexBook.owedLand(land: number): boolean
	local have, of = IndexBook.setOf(land)
	return of > 0 and have == of and not claimedLands[tostring(land)]
end

-- How many rewards wait in one land (its kinds' and its set's), and in all of them
function IndexBook.owedIn(land: number): number
	local entry = lands[land]
	if not entry then
		return 0
	end
	local count = if IndexBook.owedLand(land) then 1 else 0
	for _, fish in entry.Kinds do
		if IndexBook.owedKind(fish.Id) then
			count += 1
		end
	end
	return count
end

function IndexBook.owedAll(): number
	local count = 0
	for land = 1, #lands do
		count += IndexBook.owedIn(land)
	end
	return count
end

function IndexBook.foundAll(): number
	local count = 0
	for _, entry in lands do
		for _, fish in entry.Kinds do
			if found[fish.Id] then
				count += 1
			end
		end
	end
	return count
end

-- A land's saddle (Shared/Saddles), nil where it gives none or saddles are off
function IndexBook.saddle(land: number): Saddles.Design?
	return Saddles.ofLand(land)
end

-- Is a land's saddle theirs: its set is claimed (the server's rule)
function IndexBook.ownsSaddle(land: number): boolean
	return claimedLands[tostring(land)] == true and Saddles.ofLand(land) ~= nil
end

-- The land whose saddle is worn, 0 for none
function IndexBook.worn(): number
	local land = State.Player:GetAttribute("Saddle")
	return if type(land) == "number" then land else 0
end

-- How many saddles are theirs, and how many there are
function IndexBook.saddles(): (number, number)
	local have, of = 0, 0
	for land = 1, #lands do
		if Saddles.ofLand(land) then
			of += 1
			have += if IndexBook.ownsSaddle(land) then 1 else 0
		end
	end
	return have, of
end

-- A land's name as the map has it ("Coral Reef"), else its short one
function IndexBook.landName(land: number): string
	local zone = State.Zones[land]
	if zone and zone.Name ~= "" then
		local words: { string } = {}
		for word in string.gmatch(string.lower(zone.Name), "%S+") do
			table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
		end
		return table.concat(words, " ")
	end
	return Kit.LandShort[land] or ("Land " .. land)
end

-- Max Oxygen as a reward: whole while it fits (Config.wholeNumber), short past that
function IndexBook.oxygenText(value: number): string
	return "+" .. (if value < 100000 then Config.wholeNumber(value) else Kit.short(value))
end

-- One ask to the server, no sooner after the last than it would listen (Index.AskGap); false when it is too soon
local askedAt = -math.huge
function IndexBook.ask(what: string, arg: any?): boolean
	local now = os.clock()
	if now - askedAt < Config.Index.AskGap + 0.05 then
		return false
	end
	askedAt = now
	Net.Index:FireServer(what, arg)
	return true
end

return IndexBook
