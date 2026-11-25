--!strict
-- Offline rewards (Hugo, 2026-11-25: "Add offline rewards"; NULLROOM task o1; docs/design/offline-rewards.md): what a
-- player's tank earned while they were away, theirs to claim when they come back. The numbers are Config.Offline (each a
-- DRAFT), the sum is Config.offlinePay; the window is Client.UI.OfflinePanel, shown by OfflineController.
--   Kept: the save's part "Offline" (Lib/SaveParts): { Left, Rate, Owed, Secs }. Every snapshot writes the server's own
--   clock (os.time, Left) and what the tank earns a second by its equipped fish (Rate), so the last snapshot of a visit,
--   taken as the player leaves, holds when they left and what the tank had then. Owed is what is not claimed yet, Secs
--   the seconds it was earned in.
--   Coming back: restore() adds the pay for the time since Left to what was still owed. Time that runs backwards (a
--   server whose clock is behind) pays nothing; a longer absence than Offline.Most pays for Offline.Most. The save gives
--   each part back once a session, and one server at a time holds a profile (ProfileStore's session lock).
--   Claiming: the remote "Offline" ("Claim"), no arguments: the amount is the server's own. The whole of it goes into the
--   tank (AquariumService.give) and Owed goes to nothing in the same moment, with no yield between. Both are in the same
--   snapshot (SaveService writes all parts together, or none), so whatever is lost, a connection, a reply or a server,
--   the coins and the claim are kept together or lost together: it can't pay twice, and it can't vanish unpaid. For the
--   same reason nothing is claimed unless the save has both parts on (the attributes SavedTank and SavedOffline, which
--   only the server can set). Not claimed (the X, or they left): it stays owed and is saved as it is.
--   Claim x3 for Robux (Products.Triple; Hugo, 2026-11-25): the remote's "Triple" holds what is owed (no free claim) and
--   the client opens Roblox's prompt. A closed prompt lets it go; a purchase is paid by PurchaseService's receipt through
--   triple(): what is owed here, times the product's own number, into the tank, in the same snapshot as the receipt. The
--   hold is kept in the save (Held), so it outlives a rejoin for Offline.HoldJoin. An answer that never comes lets it go
--   after Offline.Hold; a free claim made then is remembered (Took), and a receipt that comes after all pays the rest of it.
--   With saving off (SaveParts' ON, as now) nothing is ever given back, so nothing is owed and nothing shows.
--   No tank (more players than plots): nothing is paid or lost; it waits until they have one, as their coins do.
-- Told to the client by player attributes (nil: nothing is owed): OfflineOwed (whole coins) and OfflineSecs (the seconds
-- they were earned in). The remote answers "Paid", coins | "Buy", product (open Roblox's prompt) | "Denied", why
-- ("Nothing", "Save": the save isn't in yet or is another server's, "Tank": no tank to pay into, "Buying": held for a
-- purchase, "Sale": Claim x3 is not on sale).
-- Studio's test: the workspace attribute "OfflineAway" (seconds; before Play, or changed while it runs) makes every player
-- come back from that long away, with no save needed. "OfflineRate" is the coins a second to pretend; without it, what the
-- tank earns then, or 100 for a tank that earns nothing. It does nothing with "SaveReal" on (Roblox's own store), nor in a
-- live game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Shared.Products)
local AquariumService = require(script.Parent.AquariumService)

local OfflineService = {}

local TEST_RATE = 100 -- the test's coins a second for a tank that earns nothing
local TEST_WAIT = 30 -- seconds the test waits for a player's tank

type Away = {
	Owed: number, -- whole coins, not claimed yet
	Secs: number, -- the seconds they were earned in
	Test: boolean, -- some of it is the Studio test's: claimed with no save
	AskedAt: number, -- os.clock() of the last ask we listened to
	Held: boolean, -- a purchase of Claim x3 was begun and not seen refused or paid
	HeldUntil: number, -- os.clock(): no free claim before it
	Took: number, -- coins claimed freely while Held, its time run out: a late receipt pays the rest of them
}

local aways: { [Player]: Away } = {}
local remote: RemoteEvent

-- A number that can be kept and paid by: not NaN, not endless, not under nothing; anything else is nothing
local function sane(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return value
end

-- What the player's tank earns a second now: its equipped fish. nil with no tank
local function rateOf(player: Player): number?
	local fish = AquariumService.tankOf(player)
	if not fish then
		return nil
	end
	local rate = 0
	for _, f in fish do
		if f.On then
			rate += sane(f.Income)
		end
	end
	return sane(rate)
end

local function tell(player: Player, away: Away)
	local on = Config.Offline.On ~= 0 and away.Owed >= 1
	player:SetAttribute("OfflineSecs", if on then away.Secs else nil)
	player:SetAttribute("OfflineOwed", if on then away.Owed else nil)
end

-- So long away at that many coins a second, added to what is owed
local function earn(player: Player, away: Away, rate: number, gone: number)
	local coins, secs = Config.offlinePay(rate, gone)
	away.Owed = sane(away.Owed + coins)
	away.Secs = sane(away.Secs + secs)
	tell(player, away)
end

-- For saving (SaveParts, part "Offline"): nil for a player who is not here, or has no tank (as the part "Tank")
function OfflineService.dump(player: Player): { [string]: any }?
	local away = aways[player]
	local rate = rateOf(player)
	if not away or not rate then
		return nil
	end
	return {
		Left = os.time(),
		Rate = rate,
		Owed = away.Owed,
		Secs = away.Secs,
		Held = if away.Held then true else nil,
		Took = if away.Took > 0 then away.Took else nil,
	}
end

-- For saving: what was kept, given back. Called once a session, when the tank's own part is in (ready). A field that is
-- not a number counts as nothing: a save is never refused for this
function OfflineService.restore(player: Player, kept: any): boolean
	local away = aways[player]
	if not away then
		return false
	end
	if type(kept) ~= "table" then
		return true
	end
	away.Owed = sane(away.Owed + math.floor(sane(kept.Owed)))
	away.Secs = sane(away.Secs + sane(kept.Secs))
	away.Took = math.floor(sane(kept.Took))
	if kept.Held == true then
		away.Held = true
		away.HeldUntil = os.clock() + Config.Offline.HoldJoin
	end
	local left = sane(kept.Left)
	earn(player, away, sane(kept.Rate), if left > 0 then os.time() - left else 0)
	return true
end

-- Whether what is owed may be turned into coins now: the coins and the claim are both kept (above), or it is a test
local function safe(player: Player, away: Away): boolean
	return away.Test or (player:GetAttribute("SavedTank") == true and player:GetAttribute("SavedOffline") == true)
end

local function letGo(away: Away)
	away.Held, away.HeldUntil = false, -math.huge
end

-- Claim x3 asked for: what is owed is held, and the client may open Roblox's prompt
local function hold(player: Player, away: Away, now: number)
	if away.Owed < 1 then
		remote:FireClient(player, "Denied", "Nothing")
	elseif not Products.onSale(Products.Triple) then
		remote:FireClient(player, "Denied", "Sale")
	elseif player:GetAttribute("SavedTank") ~= true or player:GetAttribute("SavedOffline") ~= true then
		remote:FireClient(player, "Denied", "Save")
	elseif away.Held and now < away.HeldUntil then
		remote:FireClient(player, "Denied", "Buying")
	else
		away.Held, away.HeldUntil = true, now + Config.Offline.Hold
		remote:FireClient(player, "Buy", Products.Triple.Id)
	end
end

-- For PurchaseService: Roblox's prompt for Claim x3 has closed. Bought: the hold stays until the receipt
function OfflineService.prompted(player: Player, bought: boolean)
	local away = aways[player]
	if not away or not away.Held then
		return
	elseif bought then
		away.HeldUntil = math.huge
	else
		letGo(away)
	end
end

-- For PurchaseService: a receipt of Claim x3, `times` what is owed into the tank, all of it or nothing (false). Doesn't
-- yield
function OfflineService.triple(player: Player, times: number): boolean
	local away = aways[player]
	if not away then
		return false
	end
	local owed, secs, took = away.Owed, away.Secs, away.Took
	local coins = sane(owed * times + took * math.max(times - 1, 0))
	if coins < 1 then
		warn(`[OfflineService] Claim x3 of {player.Name} waits: nothing is owed`)
		return false
	end
	away.Owed, away.Secs, away.Took = 0, 0, 0
	if not AquariumService.give(player, coins) then
		away.Owed, away.Secs, away.Took = owed, secs, took
		return false
	end
	letGo(away)
	away.Test = false
	tell(player, away)
	remote:FireClient(player, "Paid", coins)
	return true
end

-- One ask from a player's client. An ask sooner than Offline.AskGap after the last is dropped
local function ask(player: Player, what: any)
	local away = aways[player]
	if not away or Config.Offline.On == 0 or (what ~= "Claim" and what ~= "Triple") then
		return
	end
	local now = os.clock()
	if now - away.AskedAt < Config.Offline.AskGap then
		return
	end
	away.AskedAt = now
	if what == "Triple" then
		hold(player, away, now)
		return
	elseif away.Held and now < away.HeldUntil then
		remote:FireClient(player, "Denied", "Buying")
		return
	end
	local coins, secs = away.Owed, away.Secs
	if coins < 1 then
		remote:FireClient(player, "Denied", "Nothing")
		return
	elseif not safe(player, away) then
		remote:FireClient(player, "Denied", "Save")
		return
	end
	-- (no yield from here to the end: the coins and the claim are one moment)
	away.Owed, away.Secs = 0, 0
	if not AquariumService.give(player, coins) then
		away.Owed, away.Secs = coins, secs
		remote:FireClient(player, "Denied", "Tank")
		return
	end
	if away.Held then
		away.Took = coins
	end
	away.Test = false
	tell(player, away)
	remote:FireClient(player, "Paid", coins)
end

-- Studio's test (above): the player comes back from workspace's "OfflineAway" seconds
local function pretend(player: Player)
	local gone = workspace:GetAttribute("OfflineAway")
	if type(gone) ~= "number" or workspace:GetAttribute("SaveReal") == true then
		return
	end
	local from = os.clock()
	local rate = rateOf(player)
	while not rate and aways[player] and os.clock() - from < TEST_WAIT do
		task.wait(0.25)
		rate = rateOf(player)
	end
	local away = aways[player]
	if not away or not rate then
		return
	end
	local asked = workspace:GetAttribute("OfflineRate")
	if type(asked) == "number" then
		rate = sane(asked)
	elseif rate == 0 then
		rate = TEST_RATE
	end
	away.Test = true
	earn(player, away, rate :: number, gone)
end

local function join(player: Player)
	if aways[player] then
		return
	end
	aways[player] = {
		Owed = 0,
		Secs = 0,
		Test = false,
		AskedAt = -math.huge,
		Held = false,
		HeldUntil = -math.huge,
		Took = 0,
	}
	if RunService:IsStudio() then
		task.spawn(pretend, player)
	end
end

-- Test hooks: only the offline check (tools/offline/offline_test.luau) and Studio's checks call these. `join` and `leave`
-- are what PlayerAdded and PlayerRemoving do, `ask` one ask as the client would send it.
OfflineService.join = join
OfflineService.ask = ask
function OfflineService.leave(player: Player)
	aways[player] = nil
end

function OfflineService.Init()
	local existing = Net.Folder:FindFirstChild("Offline")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
	else
		remote = Instance.new("RemoteEvent")
		remote.Name = "Offline"
		remote.Parent = Net.Folder
	end
end

function OfflineService.Start()
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(function(player: Player)
		-- (after the others': SaveService takes its last snapshot of them in its own)
		task.defer(OfflineService.leave, player)
	end)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	remote.OnServerEvent:Connect(ask)
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("OfflineAway"):Connect(function()
			for player in aways do
				task.spawn(pretend, player)
			end
		end)
	end
end

return OfflineService
