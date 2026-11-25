--!strict
-- The Index (Hugo, 2026-11-23: "Import index system"; NULLROOM task h2): every kind of fish a player has caught, land
-- by land, and a reward to claim for each new kind and for each land's whole set. The window is Client.UI.IndexPanel;
-- the hub's Index button opens it. What it pays is Config.Index (every number a DRAFT of the economy draft 2,
-- docs/design/progression.md) through Config.indexFirst and Config.indexLand.
--   Found: a kind is found once the player really has one: a fish they carry (tamed on a dive: it comes home, death
--   or not) or one in their tank. Nothing is taken on the client's word, and no other service is changed for it:
--   every Index.Watch seconds the server looks at what each player carries (RideService.carried) and keeps
--   (AquariumService.tankOf) and notes each fish's kind, size and colour. The tank is looked at on purpose: it only
--   ever holds fish that were carried first, or given by the owner's admin panel and Studio's tests, so a given fish
--   counts as found too (handy for a check).
--   Looks: a kind has Config.indexLooks() looks (every size in every colour); the server counts which of them the
--   player has caught, truly, fish by fish.
--   Claims: the client asks over the Index remote ("Claim", fishId | "ClaimLand", land | "ClaimAll" | "Sync"). The
--   server checks every ask: the kind is found, or the land's whole set (Config.indexSet) is, it has not been paid
--   before, and the player stands on the dock (max Oxygen is only given there: RideService.train). Each reward is
--   paid once: the max Oxygen through RideService.train, the coins into the player's tank (AquariumService.give). A
--   player with no tank (more players than plots) has no coins at all in this game, so they are paid the Oxygen only.
--   An ask sooner than Index.AskGap after the player's last is dropped.
--   Auras: an aura does NOT multiply the Index's Oxygen (Config.Index.AuraMult 0, the draft's answer to an open
--   question); with the switch on, every claim's Oxygen is multiplied by the player's aura (Shared/Auras).
--   Saddles (NULLROOM s2; Shared/Saddles, Config.Saddles): a claimed land IS the owning of its saddle (Book.Lands), so
--   it is given once, with the claim, and a player who claimed the land before has it too. Worn: one at most, put on or
--   off over the same remote ("Saddle", land | "Saddle", 0), only one that is owned; any time, not only on the dock.
--   The player's attribute Saddle is the worn one's land (0: none): every machine dresses their fish by it
--   (SaddleController).
--   Told to the client: its whole Index after every change (Index "State": Net.luau), and three player attributes for
--   the hub button's red mark and for checks: IndexFound (kinds caught), IndexClaims (rewards waiting) and IndexPaid
--   (they have claimed one before: the game stops showing them how).
-- Saved (SaveParts, part "Index": dump, restore): a player's Book, the looks caught, rewards paid and optional worn land.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Auras = require(ReplicatedStorage.Shared.Auras)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Saddles = require(ReplicatedStorage.Shared.Saddles)
local AquariumService = require(script.Parent.AquariumService)
local RideService = require(script.Parent.RideService)

local IndexService = { SavesClaims = false } -- set when SaveParts registers the Index

type Book = {
	Looks: { [string]: { [string]: boolean } }, -- fish id -> "size|colour" -> true: every look of it they have caught
	Count: { [string]: number }, -- fish id -> how many looks: a kind is found when it is here
	Kinds: { [string]: boolean }, -- fish id -> true: its first-catch reward has been paid
	Lands: { [string]: boolean }, -- the land as a string -> true: its set's reward has been paid
	Saddle: number, -- the land whose saddle is worn, 0 for none
	AskedAt: number, -- os.clock() of the last ask we listened to
}

local books: { [Player]: Book } = {}

-- Whether every kind of a land's set is found (a land with no set is never done)
local function landDone(book: Book, land: number): boolean
	local set = Config.indexSet(land)
	if #set == 0 then
		return false
	end
	for _, fish in set do
		if not book.Count[fish.Id] then
			return false
		end
	end
	return true
end

-- What the player may claim now: the found kinds not yet paid, and the finished lands not yet paid
local function owed(book: Book): ({ string }, { number })
	local kinds: { string } = {}
	for id in book.Count do
		if not book.Kinds[id] then
			table.insert(kinds, id)
		end
	end
	table.sort(kinds)
	local lands: { number } = {}
	for land = 1, Config.indexLands() do
		if not book.Lands[tostring(land)] and landDone(book, land) then
			table.insert(lands, land)
		end
	end
	return kinds, lands
end

-- Whether they own a land's saddle: the land's set is claimed, and it gives one
local function ownsSaddle(book: Book, land: number): boolean
	return book.Lands[tostring(land)] == true and Saddles.ofLand(land) ~= nil
end

-- The worn saddle, for every machine to see: 0 while saddles are off
local function showSaddle(player: Player, book: Book)
	player:SetAttribute("Saddle", if ownsSaddle(book, book.Saddle) then book.Saddle else 0)
end

-- The player's whole Index, to their client and onto their attributes
local function tell(player: Player, book: Book)
	local found = 0
	for _ in book.Count do
		found += 1
	end
	local kinds, lands = owed(book)
	player:SetAttribute("IndexFound", found)
	player:SetAttribute("IndexClaims", #kinds + #lands)
	player:SetAttribute("IndexPaid", next(book.Kinds) ~= nil or next(book.Lands) ~= nil)
	Net.Index:FireClient(player, "State", book.Count, book.Kinds, book.Lands)
end

-- One fish the player really has: its kind is found, and this look of it. True when that was new. (A kind that is
-- not in the Index, Config.inIndex, is never found: nothing shows it, so nothing could be claimed for it.)
local function note(book: Book, id: string, size: string, variant: string): boolean
	local kind = Config.FishById[id]
	if not kind or not Config.inIndex(kind) then
		return false
	end
	local looks = book.Looks[id]
	if not looks then
		looks = {}
		book.Looks[id] = looks
	end
	local look = size .. "|" .. variant
	if looks[look] then
		return false
	end
	looks[look] = true
	book.Count[id] = (book.Count[id] or 0) + 1
	return true
end

-- Looks at what the player carries and keeps, and tells them when something new is in their Index
local function look(player: Player)
	local book = books[player]
	if not book then
		return
	end
	local new = false
	for _, fish in RideService.carried(player) do
		new = note(book, fish.Id, fish.Size, fish.Variant) or new
	end
	local tank = AquariumService.tankOf(player)
	if tank then
		for _, fish in tank do
			new = note(book, fish.Id, fish.Size, fish.Variant) or new
		end
	end
	if new then
		tell(player, book)
	end
end

-- How many times the player's aura multiplies a claim's Oxygen: 1 unless Config.Index.AuraMult is switched on
local function auraOf(player: Player): number
	if Config.Index.AuraMult == 0 then
		return 1
	end
	local id = player:GetAttribute("Aura")
	for _, tier in Auras.Tiers do
		if tier.Id == id then
			return math.max(tier.Mult, 1)
		end
	end
	return 1
end

-- Pays these rewards, all or none: only on the dock. Each is marked paid before the coins go out, so nothing here
-- can pay one twice.
local function pay(player: Player, book: Book, kinds: { string }, lands: { number })
	local oxygen, coins = 0, 0
	for _, id in kinds do
		local o, c = Config.indexFirst(Config.FishById[id])
		oxygen += o
		coins += c
	end
	for _, land in lands do
		local o, c = Config.indexLand(land)
		oxygen += o
		coins += c
	end
	-- (whole numbers only, as every Oxygen gain: task e1)
	oxygen = math.floor(oxygen * auraOf(player) + 0.5)
	if RideService.stateOf(player) ~= "Dock" or (oxygen > 0 and not RideService.train(player, oxygen)) then
		Net.Index:FireClient(player, "Denied", "Dock")
		return
	end
	for _, id in kinds do
		book.Kinds[id] = true
	end
	local saddles: { number } = {} -- the lands whose saddle comes with this claim
	for _, land in lands do
		book.Lands[tostring(land)] = true
		if ownsSaddle(book, land) then
			table.insert(saddles, land)
		end
	end
	-- (no tank, no coins: such a player has none in this game)
	if coins > 0 and AquariumService.tankOf(player) then
		AquariumService.give(player, coins)
	else
		coins = 0
	end
	tell(player, book)
	Net.Index:FireClient(player, "Paid", oxygen, coins, #kinds + #lands, saddles)
end

-- Puts a land's saddle on (0: takes the worn one off). One they don't own changes nothing.
local function wear(player: Player, book: Book, land: any)
	if type(land) ~= "number" or land ~= land or land % 1 ~= 0 or Config.Saddles.On == 0 then
		return
	end
	if land ~= 0 and (land < 1 or land > Config.indexLands() or not ownsSaddle(book, land)) then
		Net.Index:FireClient(player, "Denied", "Saddle")
		return
	end
	book.Saddle = land
	showSaddle(player, book)
end

-- One ask from a player's client. Nothing in it is believed: the kind must be found and unpaid, the land's set whole
-- and unpaid. Asks closer together than Index.AskGap are dropped.
local function ask(player: Player, what: any, arg: any)
	local book = books[player]
	if not book or Config.Index.On == 0 or type(what) ~= "string" then
		return
	end
	if what ~= "Sync" and IndexService.SavesClaims and player:GetAttribute("SavedIndex") ~= true then
		return -- the old claims and worn saddle are still loading
	end
	local now = os.clock()
	if now - book.AskedAt < Config.Index.AskGap then
		return
	end
	book.AskedAt = now
	local kinds: { string } = {}
	local lands: { number } = {}
	if what == "Sync" then
		tell(player, book)
		return
	elseif what == "Claim" then
		if type(arg) == "string" and book.Count[arg] and not book.Kinds[arg] and Config.FishById[arg] then
			kinds = { arg }
		end
	elseif what == "ClaimLand" then
		if type(arg) == "number" and arg == arg and arg % 1 == 0 and arg >= 1 and arg <= Config.indexLands() then
			if not book.Lands[tostring(arg)] and landDone(book, arg) then
				lands = { arg }
			end
		end
	elseif what == "ClaimAll" then
		kinds, lands = owed(book)
	elseif what == "Saddle" then
		wear(player, book, arg)
		return
	else
		return
	end
	if #kinds + #lands == 0 then
		Net.Index:FireClient(player, "Denied", "Nothing")
		return
	end
	pay(player, book, kinds, lands)
end

local function join(player: Player)
	if not books[player] then
		books[player] = { Looks = {}, Count = {}, Kinds = {}, Lands = {}, Saddle = 0, AskedAt = -math.huge }
		player:SetAttribute("IndexFound", 0)
		player:SetAttribute("IndexClaims", 0)
		player:SetAttribute("IndexPaid", false)
		player:SetAttribute("Saddle", 0)
	end
end

-- For other services and Studio's checks: how many looks of each kind a player has caught (fish id -> count; not to
-- be changed), nil for a player who is not in the game
function IndexService.foundOf(player: Player): { [string]: number }?
	local book = books[player]
	return if book then book.Count else nil
end

-- For saving (SaveParts, part "Index"): the looks caught and what has been paid, a fresh table; nil for a player who is
-- not here. Doesn't yield.
function IndexService.dump(player: Player): { [string]: any }?
	local book = books[player]
	if not book then
		return nil
	end
	local looks: { [string]: { string } } = {}
	for id, set in book.Looks do
		local list = {}
		for name in set do
			table.insert(list, name)
		end
		looks[id] = list
	end
	return {
		Looks = looks,
		Kinds = table.clone(book.Kinds),
		Lands = table.clone(book.Lands),
		Saddle = if book.Saddle > 0 then book.Saddle else nil,
	}
end

-- What was kept, added to what they have found since they joined. A kind the game no longer has is kept as it is (it
-- counts for nothing until it is back). False for a player who is not here.
function IndexService.restore(player: Player, kept: any): boolean
	local book = books[player]
	if not book then
		return false
	end
	if type(kept) ~= "table" then
		return true
	end
	for id, list in (kept.Looks or {}) :: any do
		local looks = book.Looks[id] or {}
		for _, name in list do
			if not looks[name] then
				looks[name] = true
				if Config.FishById[id] then
					book.Count[id] = (book.Count[id] or 0) + 1
				end
			end
		end
		book.Looks[id] = looks
	end
	for id in (kept.Kinds or {}) :: any do
		book.Kinds[id] = true
	end
	for land in (kept.Lands or {}) :: any do
		book.Lands[land] = true
	end
	-- Keep the preference while saddles are disabled. Only a claimed, configured land can be shown.
	local worn = kept.Saddle
	book.Saddle = if type(worn) == "number"
			and worn >= 1
			and worn <= Config.indexLands()
			and worn % 1 == 0
			and book.Lands[tostring(worn)] == true
		then worn
		else 0
	showSaddle(player, book)
	tell(player, book)
	return true
end

-- Test hooks: only the offline check (tools/index/index_test.luau) and Studio's checks call these. `join` and `leave`
-- are what PlayerAdded and PlayerRemoving do, `look` one look at a player, `ask` one ask as their client would send it.
IndexService.join = join
IndexService.look = look
IndexService.ask = ask
function IndexService.leave(player: Player)
	books[player] = nil
end

function IndexService.Start()
	if Config.Index.On == 0 then
		return
	end
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(IndexService.leave)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	Net.Index.OnServerEvent:Connect(ask)
	local since = 0
	RunService.Heartbeat:Connect(function(dt: number)
		since += dt
		if since < Config.Index.Watch then
			return
		end
		since = 0
		for player in books do
			look(player)
		end
	end)
end

return IndexService
