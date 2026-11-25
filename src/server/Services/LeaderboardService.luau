--!strict
-- The hub's leaderboards (Hugo, 2026-11-25; NULLROOM task l1; docs/design/leaderboards.md): the biggest max Oxygen, the
-- most fish looks in the Index, the most coins a second from a tank (Config.Boards.List; a fourth, the deepest, is
-- off). The boards themselves are BoardController's; this says who is on them.
--   Whose numbers: the server's own, nothing a client sends. Every Boards.Watch seconds it reads each player's and puts
--     it on the player's attribute "Board" .. Id (their own line at a board's foot).
--   Every player of the game, or this server's: a board lists everyone (Roblox's OrderedDataStore "Boards1_" .. Id, its
--     first Boards.Keep) only while its number is really saved between visits: Boards.Global 1, its Saved part joined
--     in SaveParts (SaveService.keeps), and the store answering. Otherwise, and in Studio (unless the workspace's
--     "SaveReal" attribute is set before Play, as for SaveService), it lists the players of this server, and says so
--     (Global false). A store that is down or not allowed is one line in the output and nothing else: a board that had
--     a list keeps it for Boards.Stale, then shows this server's players, and goes back by itself.
--   What is stored: a player's mark (Lib/BoardSums: how a number past 2^53 is kept) under their user id, no name, the
--     newest one (a tank that is sold off falls). Only once their save has been given back (their "Saved" .. part
--     attribute), so a joining player's first moments never take the place of what they have; at most once in
--     Boards.WriteEvery and as they leave; one write in Boards.WriteGap for the whole server, the newest mark only,
--     and only while Roblox's own budget has more than Boards.Reserve left.
--   Names: Roblox's own (display names, asked for in one request for all that are new and kept for this server's life),
--     which Roblox filters itself. No word of a player's is ever stored or sent by this game.
--   Hidden: Boards.HideUsers (ids) are never stored and never listed; they still see their own number.
-- The remote is our own, ReplicatedStorage.Remotes.Boards (Net.luau lists its messages).
-- The station the boards stand in place of (Boards.Replaces) is taken out of the running game; the place keeps it.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local UserService = game:GetService("UserService")

local BoardSums = require(script.Parent.Parent.Lib.BoardSums)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local IndexService = require(script.Parent.IndexService)
local SaveService = require(script.Parent.SaveService)

local LeaderboardService = {}

local NAMES_AT_ONCE = 50 -- user ids in one request for names
local CLOSE = 20 -- seconds a closing server spends on what is still to be stored
local CLOSE_AGAIN = 2 -- and waits after a failed write, in place of Boards.Backoff

type Def = typeof(Config.Boards.List[1])
type Board = {
	Def: Def,
	Store: any, -- the OrderedDataStore; nil: this board is this server's only
	Rows: { BoardSums.Entry }?, -- what the store last handed over
	RowsAt: number,
	ReadFails: number,
	ReadFrom: number, -- no read before this
	WriteFails: number,
	WriteFrom: number, -- no write before this
	Warned: boolean,
}
type Here = {
	Value: { [string]: number }, -- board id -> the number as it is
	Mark: { [string]: number }, -- and as it is stored; 0: none
	Ready: { [string]: boolean }, -- whether it may be stored (the player's save has been given back)
	Sent: { [string]: number }, -- the mark last stored
	SentAt: { [string]: number },
	AskedAt: number,
}
type Write = { Board: Board, User: number, Mark: number }

local boards: { Board } = {}
local here: { [Player]: Here } = {}
local writes: { [string]: Write } = {} -- the newest to store, by board and user
local order: { string } = {} -- the same, first asked first
local names: { [number]: string } = {}
local remote: any = nil
local state: any = nil -- what the clients were last sent
local nextRead = 0
local dirty = true
local publishing = false
local sending: { [string]: boolean } = {} -- the writes Roblox has not answered yet
local closing = false

local function isHidden(user: number): boolean
	return table.find(Config.Boards.HideUsers, user) ~= nil
end

-- A player's number on a board, as the server has it
local function valueOf(player: Player, def: Def): number
	local value: any = nil
	if def.Id == "Collectors" then
		-- every look of every kind they have caught (size and colour): what the Index records
		local found = IndexService.foundOf(player)
		local looks = 0
		if found then
			for _, count in found do
				looks += count
			end
		end
		value = looks
	elseif def.Attribute ~= "" then
		value = player:GetAttribute(def.Attribute)
	end
	return if type(value) == "number" and value == value then value else 0
end

-- The store of a board, if it lists every player of the game
local function open(def: Def): any
	if Config.Boards.Global == 0 or not SaveService.keeps(def.Saved) then
		return nil
	end
	if RunService:IsStudio() and workspace:GetAttribute("SaveReal") ~= true then
		return nil
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.Boards.Store .. def.Id)
	end)
	return if ok then store else nil
end

local function failed(board: Board, what: string, problem: any)
	if not board.Warned then
		board.Warned = true
		warn(`[LeaderboardService] {board.Def.Title}: {what} did not work, it will be tried again: {tostring(problem)}`)
	end
end

local function budget(kind: Enum.DataStoreRequestType): number
	local ok, left = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(kind)
	end)
	return if ok and type(left) == "number" then left else 0
end

-- The stored list of a board, asked for again (yields)
local function read(board: Board, now: number)
	local store = board.Store
	if not store or now < board.ReadFrom or budget(Enum.DataStoreRequestType.GetSortedAsync) < 1 then
		return
	end
	local most = math.clamp(Config.Boards.Keep + #Config.Boards.HideUsers, 1, 100)
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, most):GetCurrentPage()
	end)
	if ok and type(page) == "table" then
		board.Rows = BoardSums.read(page)
		board.RowsAt = os.clock()
		board.ReadFails = 0
		board.Warned = false
	else
		board.ReadFails += 1
		board.ReadFrom = os.clock()
			+ BoardSums.backoff(board.ReadFails, Config.Boards.Backoff, Config.Boards.BackoffMost)
		failed(board, "reading the list", page)
	end
end

local function isGlobal(board: Board, now: number): boolean
	return board.Store ~= nil and board.Rows ~= nil and now - board.RowsAt <= Config.Boards.Stale
end

-- A mark to store: it takes the place of an older one still waiting
local function queue(board: Board, user: number, mark: number)
	local key = board.Def.Id .. ":" .. user
	if not writes[key] then
		table.insert(order, key)
	end
	writes[key] = { Board = board, User = user, Mark = mark }
end

-- One look at a player: their numbers, their attributes, and what is to be stored. `last`: they are leaving
local function look(player: Player, now: number, last: boolean?)
	local h = here[player]
	if not h then
		return
	end
	for _, board in boards do
		local def = board.Def
		if not last then
			local value = valueOf(player, def)
			if h.Value[def.Id] ~= value then
				h.Value[def.Id] = value
				player:SetAttribute("Board" .. def.Id, value)
			end
			local mark = BoardSums.mark(value, def.Scale) or 0
			if h.Mark[def.Id] ~= mark then
				h.Mark[def.Id] = mark
				dirty = dirty or not isGlobal(board, now)
			end
			h.Ready[def.Id] = player:GetAttribute("Saved" .. def.Saved) == true
		end
		-- (a user id under 1 is a Studio test player)
		if board.Store and h.Ready[def.Id] and player.UserId > 0 and not isHidden(player.UserId) then
			local mark = h.Mark[def.Id]
			local before = h.Sent[def.Id]
			-- (nothing left to show, after something was stored: their line is taken off the stored list)
			if mark and mark ~= (before or 0) then
				if last or not before or now - h.SentAt[def.Id] >= Config.Boards.WriteEvery then
					queue(board, player.UserId, mark)
					h.Sent[def.Id] = mark
					h.SentAt[def.Id] = now
				end
			end
		end
	end
end

-- Stores one waiting mark, the longest waiting whose board may be asked (yields). True: one was tried
local function pump(now: number): boolean
	for i, key in order do
		local write = writes[key]
		if not write then
			table.remove(order, i)
			return true
		end
		local board = write.Board
		if now >= board.WriteFrom and not sending[key] then
			if budget(Enum.DataStoreRequestType.SetIncrementSortedAsync) <= Config.Boards.Reserve then
				return false
			end
			table.remove(order, i)
			writes[key] = nil
			sending[key] = true
			local ok, problem = pcall(function()
				if write.Mark > 0 then
					board.Store:SetAsync(tostring(write.User), write.Mark)
				else
					board.Store:RemoveAsync(tostring(write.User))
				end
			end)
			sending[key] = nil
			if ok then
				board.WriteFails = 0
			else
				board.WriteFails += 1
				board.WriteFrom = os.clock()
					+ if closing
						then CLOSE_AGAIN
						else BoardSums.backoff(board.WriteFails, Config.Boards.Backoff, Config.Boards.BackoffMost)
				failed(board, "storing a number", problem)
				-- (unless a newer one has come in while this one was being tried)
				if not writes[key] then
					queue(board, write.User, write.Mark)
				end
			end
			return true
		end
	end
	return false
end

-- The names of these users, asked for once (yields). One that can't be had is asked for again next time.
local function learn(ids: { number })
	local wanted: { number } = {}
	for _, id in ids do
		if not names[id] then
			local player = Players:GetPlayerByUserId(id)
			if player then
				names[id] = player.DisplayName
			elseif id > 0 then
				table.insert(wanted, id)
			end
		end
	end
	for from = 1, #wanted, NAMES_AT_ONCE do
		local some = table.move(wanted, from, math.min(from + NAMES_AT_ONCE - 1, #wanted), 1, {})
		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(some)
		end)
		if ok and type(infos) == "table" then
			for _, info in infos do
				names[info.Id] = info.DisplayName
			end
		end
	end
end

-- The boards as they are now, for the clients (yields while names are asked for)
local function build(): any
	local now = os.clock()
	local out = {}
	local ids: { number } = {}
	local asked: { [number]: boolean } = {}
	for _, board in boards do
		local global = isGlobal(board, now)
		local mine: { [number]: number } = {}
		for player, h in here do
			-- (on a list of everyone, a player whose save is not back yet keeps the place they had)
			if not global or h.Ready[board.Def.Id] then
				mine[player.UserId] = h.Mark[board.Def.Id] or 0
			end
		end
		local places = BoardSums.places(
			if global then board.Rows :: { BoardSums.Entry } else {},
			mine,
			Config.Boards.HideUsers,
			Config.Boards.Keep
		)
		for _, place in places do
			if not asked[place.Id] then
				asked[place.Id] = true
				table.insert(ids, place.Id)
			end
		end
		table.insert(out, { Id = board.Def.Id, Global = global, Rows = places })
	end
	learn(ids)
	local sent = {}
	for i, board in boards do
		local rows = {}
		for _, place in out[i].Rows do
			table.insert(rows, {
				Id = place.Id,
				Name = names[place.Id] or "Player",
				Value = BoardSums.value(place.Mark, board.Def.Scale),
				Rank = place.Rank,
			})
		end
		table.insert(sent, { Id = out[i].Id, Global = out[i].Global, Rows = rows })
	end
	return { Next = workspace:GetServerTimeNow() + math.max(nextRead - os.clock(), 0), Boards = sent }
end

local function publish()
	if publishing then
		return
	end
	publishing = true
	dirty = false
	local ok, made = pcall(build)
	publishing = false
	if ok then
		state = made
		remote:FireAllClients("State", state)
	else
		dirty = true
		warn(`[LeaderboardService] the boards could not be put together: {made}`)
	end
end

-- One turn: everyone looked at, the stored lists asked for when it is time, and the boards sent when they changed
local function step()
	local now = os.clock()
	for player in here do
		local ok, problem = pcall(look :: any, player, now)
		if not ok then
			warn(`[LeaderboardService] {player.Name} was passed over: {problem}`)
		end
	end
	if now >= nextRead then
		nextRead = now + Config.Boards.Refresh
		for _, board in boards do
			read(board, now)
		end
		dirty = true
	end
	if dirty then
		publish()
	end
end

local function join(player: Player)
	if not here[player] then
		here[player] = { Value = {}, Mark = {}, Ready = {}, Sent = {}, SentAt = {}, AskedAt = -math.huge }
		dirty = true
	end
end

-- (the last look's numbers are what is stored: the other services may have let them go already)
local function leave(player: Player)
	look(player, os.clock(), true)
	here[player] = nil
	dirty = true
end

local function ask(player: Player, what: any)
	local h = here[player]
	local now = os.clock()
	if not h or what ~= "Sync" or now - h.AskedAt < Config.Boards.AskGap then
		return
	end
	h.AskedAt = now
	if state then
		remote:FireClient(player, "State", state)
	end
end

-- The server is closing: what is still to be stored goes out. A write that Roblox has not answered yet counts as one
-- (it is in `sending` and not in `order`, and comes back to `order` if it fails)
local function close()
	closing = true
	local from = os.clock()
	for player in here do
		look(player, from, true)
	end
	for _, board in boards do
		board.WriteFrom = math.min(board.WriteFrom, from)
	end
	while (#order > 0 or next(sending) ~= nil) and os.clock() - from < CLOSE do
		if not pump(os.clock()) then
			task.wait(0.2)
		end
	end
end

-- The old station out of the running game, so the boards can stand there
local function clear()
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local stations = dock and dock:FindFirstChild("Stations")
	for _, name in Config.Boards.Replaces do
		local old = stations and stations:FindFirstChild(name)
		if old then
			old.Parent = ServerStorage
		end
	end
end

-- The boards that are on, each with its store if it lists everyone
local function setUp()
	closing = false
	table.clear(boards)
	for _, def in Config.Boards.List do
		if def.On ~= 0 then
			table.insert(boards, {
				Def = def,
				Store = open(def),
				Rows = nil,
				RowsAt = -math.huge,
				ReadFails = 0,
				ReadFrom = -math.huge,
				WriteFails = 0,
				WriteFrom = -math.huge,
				Warned = false,
			})
		end
	end
end

function LeaderboardService.Init()
	local existing = Net.Folder:FindFirstChild("Boards")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
	else
		remote = Instance.new("RemoteEvent")
		remote.Name = "Boards"
		remote.Parent = Net.Folder
	end
end

-- Test hooks: only tools/boards/board_test.luau calls these
LeaderboardService.Test = {
	setUp = setUp,
	step = step,
	pump = pump,
	join = join,
	leave = leave,
	ask = ask,
	close = close,
	clear = clear,
	waiting = function(): number
		return #order
	end,
	state = function(): any
		return state
	end,
	remote = function(to: any)
		remote = to
	end,
}

function LeaderboardService.Start()
	if Config.Boards.On == 0 then
		return
	end
	clear()
	setUp()
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(leave)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	remote.OnServerEvent:Connect(ask)
	game:BindToClose(close)
	task.spawn(function()
		while true do
			task.wait(Config.Boards.WriteGap)
			pump(os.clock())
		end
	end)
	while true do
		step()
		task.wait(Config.Boards.Watch)
	end
end

return LeaderboardService
