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
--   Told to the client: its whole Index after every change (Index "State": Net.luau), and two player attributes for
--   the hub button's red mark and for checks: IndexFound (kinds caught), IndexClaims (rewards waiting) and IndexOxygen
--   (the max Oxygen they pay together).
-- For the session only: the game has no saves yet. When saves come, a player's Book (below) is what to keep.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Auras = require(ReplicatedStorage.Shared.Auras)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local AquariumService = require(script.Parent.AquariumService)
local RideService = require(script.Parent.RideService)

local IndexService = {}

type Book = {
	Looks: { [string]: { [string]: boolean } }, -- fish id -> "size|colour" -> true: every look of it they have caught
	Count: { [string]: number }, -- fish id -> how many looks: a kind is found when it is here
	Kinds: { [string]: boolean }, -- fish id -> true: its first-catch reward has been paid
	Lands: { [string]: boolean }, -- the land as a string -> true: its set's reward has been paid
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

-- The max Oxygen these rewards pay, aura and all (whole numbers only, as every Oxygen gain: task e1)
local function oxygenOf(player: Player, kinds: { string }, lands: { number }): number
	local oxygen = 0
	for _, id in kinds do
		oxygen += (Config.indexFirst(Config.FishById[id]))
	end
	for _, land in lands do
		oxygen += (Config.indexLand(land))
	end
	return math.floor(oxygen * auraOf(player) + 0.5)
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
	player:SetAttribute("IndexOxygen", oxygenOf(player, kinds, lands))
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

-- Pays these rewards, all or none: only on the dock. Each is marked paid before the coins go out, so nothing here
-- can pay one twice.
local function pay(player: Player, book: Book, kinds: { string }, lands: { number })
	local coins = 0
	for _, id in kinds do
		coins += (select(2, Config.indexFirst(Config.FishById[id])))
	end
	for _, land in lands do
		coins += (select(2, Config.indexLand(land)))
	end
	local oxygen = oxygenOf(player, kinds, lands)
	if RideService.stateOf(player) ~= "Dock" or (oxygen > 0 and not RideService.train(player, oxygen)) then
		Net.Index:FireClient(player, "Denied", "Dock")
		return
	end
	for _, id in kinds do
		book.Kinds[id] = true
	end
	for _, land in lands do
		book.Lands[tostring(land)] = true
	end
	-- (no tank, no coins: such a player has none in this game)
	if coins > 0 and AquariumService.tankOf(player) then
		AquariumService.give(player, coins)
	else
		coins = 0
	end
	tell(player, book)
	Net.Index:FireClient(player, "Paid", oxygen, coins, #kinds + #lands)
end

-- One ask from a player's client. Nothing in it is believed: the kind must be found and unpaid, the land's set whole
-- and unpaid. Asks closer together than Index.AskGap are dropped.
local function ask(player: Player, what: any, arg: any)
	local book = books[player]
	if not book or Config.Index.On == 0 or type(what) ~= "string" then
		return
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
		books[player] = { Looks = {}, Count = {}, Kinds = {}, Lands = {}, AskedAt = -math.huge }
		player:SetAttribute("IndexFound", 0)
		player:SetAttribute("IndexClaims", 0)
		player:SetAttribute("IndexOxygen", 0)
	end
end

-- For other services and Studio's checks: how many looks of each kind a player has caught (fish id -> count; not to
-- be changed), nil for a player who is not in the game
function IndexService.foundOf(player: Player): { [string]: number }?
	local book = books[player]
	return if book then book.Count else nil
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
