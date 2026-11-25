-- The leaderboards' server, offline (NULLROOM task l1): the real LeaderboardService and Lib/BoardSums with stand-ins for
-- Roblox's store, names, players and clock. The order, ties, the rounding past 2^53, the hidden list, what is stored and
-- how often, the write budget, a store that fails, no API at all, saving off (as the game is now), and the remote.
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/boards/board_test.luau /tmp/place.rbxl
local process = require("@lune/process")
local Harness = require("../index/harness")

local world = Harness.open(process.args[1] or "/tmp/place.rbxl")
local ok, done = Harness.tally()

----------------------------------------------------------------------------------------------------------------------
-- Stand-ins

local clock = 1000
local onWait: (() -> ())? = nil -- what happens while the service waits
world.globals.os = setmetatable({
	clock = function()
		return clock
	end,
}, { __index = os })
world.globals.task = {
	wait = function(seconds: number?)
		clock += seconds or 0
		if onWait then
			onWait()
		end
		return seconds
	end,
	spawn = function(fn: (...any) -> (), ...: any)
		fn(...)
	end,
}
local serverFolder = {
	FindFirstChild = function()
		return nil
	end,
}
local studio, real = false, nil :: any
world.globals.workspace = {
	GetServerTimeNow = function()
		return 5000 + clock
	end,
	GetAttribute = function(_self: any, name: string)
		return if name == "SaveReal" then real else nil
	end,
	FindFirstChild = function()
		return nil
	end,
}
world.services.RunService = {
	IsStudio = function()
		return studio
	end,
}
world.services.ServerStorage = {}
local players: { any } = {}
world.services.Players = {
	GetPlayers = function()
		return players
	end,
	GetPlayerByUserId = function(_self: any, id: number)
		for _, player in players do
			if player.UserId == id then
				return player
			end
		end
		return nil
	end,
}
local nameAsks: { { number } } = {}
local namesFail = false
world.services.UserService = {
	GetUserInfosByUserIdsAsync = function(_self: any, ids: { number })
		table.insert(nameAsks, ids)
		if namesFail then
			error("HTTP 429")
		end
		local out = {}
		for _, id in ids do
			table.insert(out, { Id = id, DisplayName = "name" .. id, Username = "user" .. id })
		end
		return out
	end,
}
local stored: { [string]: { [string]: number } } = {}
local api, broken, budgets = true, false, 100
local slow = false -- a write is not answered until its coroutine is resumed (with true: it fails)
local calls = { open = 0, read = 0, write = 0, remove = 0 }
local writesAt: { number } = {}
world.services.DataStoreService = {
	GetRequestBudgetForRequestType = function()
		if not api then
			error("no API")
		end
		return budgets
	end,
	GetOrderedDataStore = function(_self: any, name: string)
		calls.open += 1
		if not api then
			error("You must publish this place to the web to access DataStore.")
		end
		local box = stored[name] or {}
		stored[name] = box
		return {
			GetSortedAsync = function(_me: any, up: boolean, most: number)
				calls.read += 1
				if broken then
					error("502: API Services rejected request")
				end
				assert(not up and most <= 100 and most >= 1)
				local page = {}
				for key, value in box do
					table.insert(page, { key = key, value = value })
				end
				table.sort(page, function(a, b)
					return a.value > b.value
				end)
				for i = #page, most + 1, -1 do
					page[i] = nil
				end
				return {
					GetCurrentPage = function()
						return page
					end,
				}
			end,
			SetAsync = function(_me: any, key: string, value: any)
				calls.write += 1
				if slow and coroutine.yield() or broken then
					error("502: API Services rejected request")
				end
				assert(type(key) == "string" and value % 1 == 0 and value >= 0 and value < 2 ^ 53, "not a whole number")
				box[key] = value
				table.insert(writesAt, clock)
			end,
			RemoveAsync = function(_me: any, key: string)
				calls.remove += 1
				box[key] = nil
			end,
		}
	end,
}
world.stubs["ReplicatedStorage.Shared.Net"] = { Folder = serverFolder }
local found: { [any]: { [string]: number } } = {}
world.stubs["ServerScriptService.Server.Services.IndexService"] = {
	foundOf = function(player: any)
		return found[player]
	end,
}
local keeps: { [string]: boolean } = {}
world.stubs["ServerScriptService.Server.Services.SaveService"] = {
	keeps = function(name: string)
		return keeps[name] == true
	end,
}

local function newPlayer(id: number, name: string, attributes: { [string]: any }): any
	local player = {
		UserId = id,
		Name = name,
		DisplayName = name,
		SetAttribute = function(_self: any, key: string, value: any)
			attributes[key] = value
		end,
		GetAttribute = function(_self: any, key: string): any
			return attributes[key]
		end,
		a = attributes,
	}
	table.insert(players, player)
	return player
end

local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
local Sums = world.require(world.find("ServerScriptService.Server.Lib.BoardSums"))
local Service = world.require(world.find("ServerScriptService.Server.Services.LeaderboardService"))
local T = Service.Test
local fired: { any } = {}
T.remote({
	FireAllClients = function(_self: any, what: string, state: any)
		table.insert(fired, { "all", what, state })
	end,
	FireClient = function(_self: any, player: any, what: string, state: any)
		table.insert(fired, { player, what, state })
	end,
})
local function board(id: string): any
	for _, b in T.state().Boards do
		if b.Id == id then
			return b
		end
	end
	return nil
end
local function line(b: any): string
	local out = {}
	for _, row in b.Rows do
		table.insert(out, `{row.Rank}:{row.Name}={row.Value}`)
	end
	return table.concat(out, " ")
end
local function turn(seconds: number)
	clock += seconds
	T.step()
end
-- every waiting write, and how many went out
local function drain(): number
	local n = 0
	while T.waiting() > 0 and n < 500 do
		local before = calls.write + calls.remove
		clock += Config.Boards.WriteGap
		if not T.pump(clock) then
			break
		end
		n += calls.write + calls.remove - before
	end
	return n
end

----------------------------------------------------------------------------------------------------------------------
print("the sums: rounding")

ok("a whole number is stored as it is", Sums.mark(1234, 1) == 1234 and Sums.value(1234, 1) == 1234)
ok("a part of a step is cut off, never up", Sums.mark(1234.99, 1) == 1234 and Sums.mark(12.39, 10) == 123)
ok("tenths are kept", Sums.value(Sums.mark(12.3, 10), 10) == 12.3)
ok("and 0.3 is three tenths, for all its 0.29999", Sums.mark(0.1 + 0.2, 10) == 3 and Sums.mark(0.3, 10) == 3)
ok(
	"nothing for 0, below it, or under a step",
	Sums.mark(0, 1) == nil and Sums.mark(-5, 1) == nil and Sums.mark(0.5, 1) == nil
)
ok(
	"nothing for what is no number",
	Sums.mark(0 / 0, 1) == nil
		and Sums.mark(math.huge, 1) == nil
		and Sums.mark("9", 1) == nil
		and Sums.mark(nil, 1) == nil
)
ok("exact to 1e15 - 1", Sums.value(Sums.mark(1e15 - 1, 1), 1) == 1e15 - 1)
local fits, rising, close, last, worst = true, true, true, 0, 0
for power = 0, 307, 0.05 do
	local value = 10 ^ power
	for _, scale in { 1, 10 } do
		local mark = Sums.mark(value, scale) :: number
		fits = fits and mark % 1 == 0 and mark >= 1 and mark < 2 ^ 53
		if value * scale >= 1e15 and value * scale < 1e307 then
			local off = math.abs(Sums.value(mark, scale) / value - 1)
			worst = math.max(worst, off)
			close = close and off < 1e-12
		end
	end
	local mark = Sums.mark(value, 1) :: number
	rising = rising and mark >= last
	last = mark
end
ok("every mark up to 1e307 is whole and under 2^53", fits)
ok("in the same order as the numbers", rising)
ok(string.format("read back within 1e-12 (worst %.1e)", worst), close)
ok("the largest number there is fits too", (Sums.mark(1.79e308, 10) :: number) < 2 ^ 53)
ok("the join at 1e15 does not step back", (Sums.mark(1e15 - 1, 1) :: number) < (Sums.mark(1e15, 1) :: number) + 1)
ok(
	"past 2^53 near ones are still told apart (1 in 1e12)",
	(Sums.mark(9.1e15, 1) :: number) < (Sums.mark(9.1e15 * (1 + 1e-12), 1) :: number)
)
ok("2^53 and 2^53 + 2 to four figures", math.abs(Sums.value(Sums.mark(2 ^ 53 + 2, 1), 1) / 2 ^ 53 - 1) < 1e-12)
ok(
	"the waits double to their most",
	Sums.backoff(1, 30, 600) == 30 and Sums.backoff(3, 30, 600) == 120 and Sums.backoff(20, 30, 600) == 600
)

----------------------------------------------------------------------------------------------------------------------
print("the sums: order and ties")

local function ranks(list: { any }): string
	local out = {}
	for _, p in list do
		table.insert(out, p.Rank .. ":" .. p.Id)
	end
	return table.concat(out, " ")
end
ok("the biggest first", ranks(Sums.places({}, { [7] = 5, [8] = 50, [9] = 20 }, {}, 50)) == "1:8 2:9 3:7")
ok(
	"a tie shares its rank, the older account first, the next is after them",
	ranks(Sums.places({}, { [30] = 20, [10] = 20, [20] = 50, [5] = 1 }, {}, 50)) == "1:20 2:10 2:30 4:5"
)
ok(
	"the same each time",
	(function()
		local first = ranks(Sums.places({}, { [3] = 1, [2] = 1, [1] = 1 }, {}, 50))
		for _ = 1, 20 do
			if ranks(Sums.places({}, { [1] = 1, [3] = 1, [2] = 1 }, {}, 50)) ~= first then
				return false
			end
		end
		return first == "1:1 1:2 1:3"
	end)()
)
ok(
	"this server's players are ahead of what is stored",
	ranks(Sums.places({ { Id = 1, Mark = 10 }, { Id = 2, Mark = 30 } }, { [1] = 40 }, {}, 50)) == "1:1 2:2"
)
ok(
	"also when they have less now",
	ranks(Sums.places({ { Id = 1, Mark = 100 }, { Id = 2, Mark = 30 } }, { [1] = 4 }, {}, 50)) == "1:2 2:1"
)
ok(
	"someone here with nothing is off it",
	ranks(Sums.places({ { Id = 1, Mark = 100 }, { Id = 2, Mark = 30 } }, { [1] = 0 }, {}, 50)) == "1:2"
)
ok(
	"the hidden are left out of both, and no rank is missing",
	ranks(Sums.places({ { Id = 1, Mark = 100 }, { Id = 2, Mark = 30 } }, { [3] = 60, [4] = 5 }, { 1, 3 }, 50))
		== "1:2 2:4"
)
ok("only so many", #Sums.places({ { Id = 1, Mark = 3 }, { Id = 2, Mark = 2 }, { Id = 3, Mark = 1 } }, {}, {}, 2) == 2)
ok("what the store holds that is not ours is passed over", #Sums.read({
	{ key = "12", value = 5 },
	{ key = "abc", value = 5 },
	{ key = "13", value = "x" },
	{ key = "14", value = 0 },
	{ key = "1.5", value = 3 },
} :: { any }) == 1)

----------------------------------------------------------------------------------------------------------------------
print("saving off, as the game is now: this server's players, and nothing is stored")

local ann = newPlayer(11, "Ann", { MaxOxygen = 500, Income = 12.3, BestMetres = 900 })
local bo = newPlayer(12, "Bo", { MaxOxygen = 800, Income = 0 })
local cy = newPlayer(13, "Cy", { MaxOxygen = 500, Income = 2.5e16 })
found[ann] = { Clownfish = 3, Crab = 1 }
found[cy] = { Clownfish = 24 }
T.setUp()
for _, p in players do
	T.join(p)
end
turn(0)
ok("three boards (Deepest is off)", #T.state().Boards == 3)
ok("no store is opened", calls.open == 0)
ok(
	"each says this server",
	not board("Oxygen").Global and not board("Collectors").Global and not board("Earners").Global
)
ok("oxygen, a tie for second", line(board("Oxygen")) == "1:Bo=800 2:Ann=500 2:Cy=500", line(board("Oxygen")))
ok("looks found in the Index", line(board("Collectors")) == "1:Cy=24 2:Ann=4", line(board("Collectors")))
ok(
	"coins a second: tenths, past 2^53, and no line for 0",
	board("Earners").Rows[1].Name == "Cy"
		and board("Earners").Rows[1].User == "Cy"
		and math.abs(board("Earners").Rows[1].Value / 2.5e16 - 1) < 1e-12
		and board("Earners").Rows[2].Value == 12.3
		and #board("Earners").Rows == 2,
	line(board("Earners"))
)
ok("your own numbers are on you", ann.a.BoardOxygen == 500 and ann.a.BoardCollectors == 4 and bo.a.BoardEarners == 0)
ok("the fourth board has no attribute while it is off", ann.a.BoardDeepest == nil)
ok("when the next look is, in server time", math.abs(T.state().Next - (5000 + clock + Config.Boards.Refresh)) < 0.01)
local sends = #fired
turn(5)
turn(5)
ok("nothing changed, nothing is sent", #fired == sends)
ann.a.MaxOxygen = 900
turn(5)
ok("a change is sent", #fired == sends + 1 and board("Oxygen").Rows[1].Name == "Ann")
ann.a.MaxOxygen = 0 / 0
turn(5)
ok("a number that is none counts for nothing", #board("Oxygen").Rows == 2 and ann.a.BoardOxygen == 0)
ann.a.MaxOxygen = 900
turn(5)
for _, p in players do
	p.a.SavedOxygen, p.a.SavedTank = true, true
end
turn(200)
ok("nothing is queued to store", T.waiting() == 0)
ok("no warnings", #world.warnings == 0, world.warnings[1])
ok("no names were asked for: everyone is here", #nameAsks == 0)

----------------------------------------------------------------------------------------------------------------------
print("saving on: every player of the game")

keeps = { Oxygen = true, Tank = true }
for _, p in players do
	p.a.SavedOxygen, p.a.SavedTank = nil, nil
end
stored["Boards1_Oxygen"] = { ["501"] = 700, ["502"] = 700, ["503"] = 100000, ["11"] = 50 }
T.setUp()
clock += 100
T.step()
ok("two boards have a store, the Index has none yet", calls.open == 2)
ok(
	"they say all players; the Index's still this server",
	board("Oxygen").Global and board("Earners").Global and not board("Collectors").Global
)
ok(
	"not yet given back: what they had stored stands",
	line(board("Oxygen")) == "1:name503=100000 2:name501=700 2:name502=700 4:Ann=50",
	line(board("Oxygen"))
)
ok("nothing stored before a save is given back", T.waiting() == 0)
ok("names asked for in one go", #nameAsks == 1 and #nameAsks[1] == 3, #nameAsks)
for _, p in players do
	p.a.SavedOxygen, p.a.SavedTank = true, true
end
turn(5)
ok("then each number waits to be stored (Bo earns nothing)", T.waiting() == 5, T.waiting())
ok("one write a turn of the pump", T.pump(clock) and T.waiting() == 4 and calls.write == 1)
drain()
ok(
	"stored as marks, under ids",
	stored["Boards1_Oxygen"]["11"] == 900
		and stored["Boards1_Earners"]["11"] == 123
		and stored["Boards1_Earners"]["12"] == nil
)
ok(
	"a number past 2^53 is stored whole and safe",
	stored["Boards1_Earners"]["13"] % 1 == 0 and stored["Boards1_Earners"]["13"] < 2 ^ 53
)
turn(60)
ok(
	"the next look has them all",
	line(board("Oxygen")) == "1:name503=100000 2:Ann=900 3:Bo=800 4:name501=700 4:name502=700 6:Cy=500",
	line(board("Oxygen"))
)
ok("names are asked for once only", #nameAsks == 1)
local away, right = 0, 0
for _, b in T.state().Boards do
	for _, row in b.Rows do
		if string.find(row.Name, "^name") then
			away += 1
			right += if row.User == "user" .. row.Id then 1 else 0
		end
	end
end
ok("and user names come with them", away > 0 and right == away, `{right} of {away}`)
local reads = calls.read
turn(5)
turn(5)
ok("and not read again before Refresh", calls.read == reads)
local writes = calls.write
for i = 1, 20 do
	ann.a.MaxOxygen = 900 + i
	turn(5)
	drain()
end
ok("twenty changes in 100 s: one write at most", calls.write - writes <= 1, calls.write - writes)
turn(120)
drain()
ok("and the newest is stored in the end", stored["Boards1_Oxygen"]["11"] == 920)
ok("a price of reads: one a board a minute", calls.read <= 2 * math.ceil((clock - 1000) / Config.Boards.Refresh))

bo.a.Income = 40
turn(125)
drain()
ok("a new earner is stored", stored["Boards1_Earners"]["12"] == 400)
bo.a.Income = 0
turn(125)
drain()
ok("their tank sold off: their line is taken off", stored["Boards1_Earners"]["12"] == nil and calls.remove == 1)

----------------------------------------------------------------------------------------------------------------------
print("the write budget")

budgets = Config.Boards.Reserve
ann.a.MaxOxygen = 5000
turn(130)
local before = calls.write
ok(
	"nothing is written while the budget is down to the reserve",
	not T.pump(clock) and calls.write == before and T.waiting() > 0
)
budgets = 100
drain()
ok("it is, when there is budget again", stored["Boards1_Oxygen"]["11"] == 5000)
budgets = 0
reads = calls.read
turn(61)
ok("no read without budget either, and the old list stays", calls.read == reads and board("Oxygen").Global)
budgets = 100

print("leaving")
ann.a.MaxOxygen = 6000
turn(5)
ok("changed, and too soon to store", T.waiting() == 0)
T.leave(ann)
table.remove(players, table.find(players, ann) :: number)
ok("leaving stores it at once", T.waiting() == 1 and drain() == 1 and stored["Boards1_Oxygen"]["11"] == 6000)
turn(65)
ok("they stay on the list of everyone", string.find(line(board("Oxygen")), "Ann=6000") ~= nil, line(board("Oxygen")))
ok("off this server's", line(board("Collectors")) == "1:Cy=24")

print("the hidden")
Config.Boards.HideUsers = { 503, 12 }
bo.a.MaxOxygen = 999999
turn(130)
drain()
ok(
	"not listed",
	string.find(line(board("Oxygen")), "name503") == nil and string.find(line(board("Oxygen")), "Bo=") == nil,
	line(board("Oxygen"))
)
ok("not stored", stored["Boards1_Oxygen"]["12"] ~= 999999)
ok("still see their own", bo.a.BoardOxygen == 999999)
Config.Boards.HideUsers = {}

----------------------------------------------------------------------------------------------------------------------
print("a store that fails")

broken = true
local warned = #world.warnings
reads = calls.read
turn(61)
ok(
	"the list it had stays, and it says so once a board",
	board("Oxygen").Global and #world.warnings == warned + 2,
	#world.warnings - warned
)
for _ = 1, 8 do
	turn(61)
end
ok("asked less and less often", calls.read - reads < 14, calls.read - reads)
ok("no more lines in the output", #world.warnings == warned + 2, #world.warnings - warned)
turn(300)
ok(
	"too old: this server's players, labelled",
	not board("Oxygen").Global and line(board("Oxygen")) == "1:Bo=999999 2:Cy=500",
	line(board("Oxygen"))
)
cy.a.MaxOxygen = 777
turn(130)
for _ = 1, 10 do
	T.pump(clock)
end
ok("a write that fails is kept", T.waiting() > 0 and stored["Boards1_Oxygen"]["13"] ~= 777)
broken = false
turn(700)
ok("the store answers again: everyone again", board("Oxygen").Global)
clock += 700
drain()
ok("and the kept write goes out", stored["Boards1_Oxygen"]["13"] == 777, stored["Boards1_Oxygen"]["13"])

print("names that can't be had")
namesFail = true
stored["Boards1_Oxygen"]["900"] = 123456789
turn(700)
ok("a stand-in, and no error", string.find(line(board("Oxygen")), "1:Player=123456789") ~= nil, line(board("Oxygen")))
namesFail = false
turn(61)
ok("the name as soon as it can be", string.find(line(board("Oxygen")), "1:name900") ~= nil)

print("no API at all (Studio without access)")
api = false
warned = #world.warnings
T.setUp()
turn(61)
ok(
	"this server's players, no error",
	not board("Oxygen").Global and #board("Oxygen").Rows == 2 and #world.warnings == warned,
	line(board("Oxygen"))
)
api = true
studio = true
local opened = calls.open
T.setUp()
turn(61)
ok("in Studio no store is opened", calls.open == opened and not board("Oxygen").Global)
real = true
T.setUp()
turn(61)
ok("unless SaveReal is set", calls.open == opened + 2 and board("Oxygen").Global)
studio, real = false, nil
Config.Boards.Global = 0
T.setUp()
turn(61)
ok("Global 0: this server only", not board("Oxygen").Global)
Config.Boards.Global = 1

print("the fourth board")
Config.Boards.List[4].On = 1
cy.a.BestMetres = 321
T.setUp()
turn(61)
ok("on, it is listed", #T.state().Boards == 4 and line(board("Deepest")) == "1:Cy=321")
Config.Boards.List[4].On = 0

print("the remote")
T.setUp()
turn(61)
fired = {}
T.remote({
	FireClient = function(_self: any, player: any, what: string)
		table.insert(fired, { player, what })
	end,
	FireAllClients = function() end,
})
T.ask(cy, "Sync")
T.ask(cy, "Sync")
ok("an ask is answered, a second too soon is not", #fired == 1 and fired[1][1] == cy and fired[1][2] == "State")
clock += 3
T.ask(cy, "Give")
T.ask(cy, { 1 })
T.ask(ann, "Sync")
ok("nor is anything else, nor one who has left", #fired == 1)

print("a server closing")
cy.a.MaxOxygen = 888
turn(5)
turn(125)
cy.a.MaxOxygen = 889
turn(5)
T.close()
ok(
	"the last numbers go out",
	stored["Boards1_Oxygen"]["13"] == 889 and T.waiting() == 0,
	stored["Boards1_Oxygen"]["13"]
)
-- (a write that Roblox has not answered as the server closes: started by the service's own loop, answered later)
local function inFlight(value: number, answers: { [number]: boolean }, after: number): number
	T.setUp()
	turn(121)
	drain()
	cy.a.MaxOxygen = value
	turn(125)
	slow = true
	local loop = coroutine.create(function()
		T.pump(clock)
	end)
	coroutine.resume(loop)
	slow = false
	assert(coroutine.status(loop) == "suspended" and T.waiting() == 0, "no write is under way")
	local closed = clock
	onWait = function()
		if coroutine.status(loop) == "suspended" and clock - closed >= after then
			coroutine.resume(loop, answers[1])
		end
	end
	T.close()
	onWait = nil
	if coroutine.status(loop) == "suspended" then
		coroutine.resume(loop, true)
	end
	return clock - closed
end
local took = inFlight(895, { false }, 3)
ok("a write on its way is waited for", stored["Boards1_Oxygen"]["13"] == 895 and took >= 3 and took < 4, took)
took = inFlight(896, { true }, 3)
ok("one that then fails is tried again", stored["Boards1_Oxygen"]["13"] == 896 and took >= 5 and took < 7, took)
took = inFlight(897, { true }, 1000)
ok("one that is never answered is not waited for past CLOSE", took >= 20 and took <= 21, took)
T.setUp()
turn(121)
drain()
broken = true
cy.a.MaxOxygen = 898
turn(125)
T.pump(clock)
broken = false
T.close()
ok("a write that failed before the closing does not wait out its backoff", stored["Boards1_Oxygen"]["13"] == 898)
budgets = 0
cy.a.MaxOxygen = 890
turn(5)
local from = clock
T.close()
ok("and it does not wait for ever", clock - from <= 21, clock - from)

done()
