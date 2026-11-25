-- The offline rewards' rules, checked offline (NULLROOM task o1): Config.offlinePay, and OfflineService saved and given
-- back by the game's own SaveService, SaveParts and ProfileStore on a fake Roblox (tools/offline/servers.luau).
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/offline/offline_test.luau /tmp/place.rbxl
local process = require("@lune/process")
local Harness = require("../index/harness")
local Servers = require("./servers")

local place = process.args[1] or "/tmp/place.rbxl"
local ok, done = Harness.tally()

local HOUR = 3600
local roblox: any
local function fresh()
	roblox = Servers.new(place)
	return roblox
end
local function noFaults(what: string)
	ok(`{what}: no script error`, #roblox.faults == 0, roblox.faults[1])
end

-- A visit on a server of its own, two clownfish earning and one stored, and gone
local RATE = 0
local function firstVisit(name: string, opts: any?): any
	local a = roblox.server(opts or {})
	local p = a.join(name)
	roblox.pass(2)
	a.putIn(p, "Clownfish", true)
	a.putIn(p, "Clownfish", true)
	a.putIn(p, "Clownfish", false)
	RATE = 2 * a.Config.incomeOf(a.Config.FishById.Clownfish, "Normal", "")
	roblox.pass(2)
	a.stop()
	return a
end
local function back(name: string, opts: any?): (any, any)
	local s = roblox.server(opts or {})
	local p = s.join(name)
	roblox.pass(3)
	return s, p
end
local function owed(p: any): number
	return p:GetAttribute("OfflineOwed") or 0
end
local function near(a: number, b: number, slack: number): boolean
	return math.abs(a - b) <= slack
end
local function whole(n: number): boolean
	return n == math.floor(n)
end

----------------------------------------------------------------------------------------------------------------------
print("the sum")
fresh()
do
	local s = roblox.server({})
	local C = s.Config
	local O = C.Offline
	local c, t = C.offlinePay(10, HOUR)
	ok("an hour at $10 a second pays half", c == 18000 and t == HOUR, c)
	ok("a second short of 5 min pays nothing", (C.offlinePay(10, 299)) == 0)
	ok("5 min pays", (C.offlinePay(10, 300)) == 1500)
	c, t = C.offlinePay(10, 30 * 24 * HOUR)
	ok("30 days pay for 8 h", c == 10 * 8 * HOUR * 0.5 and t == 8 * HOUR, c)
	ok("8 h and a second pay the same as 8 h", (C.offlinePay(10, 8 * HOUR + 1)) == (C.offlinePay(10, 8 * HOUR)))
	ok("no fish pay nothing", (C.offlinePay(0, HOUR)) == 0)
	ok("time going backwards pays nothing", (C.offlinePay(10, -HOUR)) == 0 and (C.offlinePay(10, -math.huge)) == 0)
	ok("less than a coin is nothing", (C.offlinePay(0.001, 300)) == 0)
	c = C.offlinePay(1.37, 1234.7)
	ok("whole coins for whole seconds", c == math.floor(1.37 * 1234 * 0.5) and whole(c), c)
	c = C.offlinePay(0.1, 600)
	ok("a float's last digit doesn't cost a coin", c == 30, c)
	local nan = 0 / 0
	ok(
		"nonsense pays nothing",
		(C.offlinePay(nan, HOUR)) == 0
			and (C.offlinePay(10, nan)) == 0
			and (C.offlinePay(math.huge, HOUR)) == 0
			and (C.offlinePay(-5, HOUR)) == 0
	)
	ok("endless time is 8 h", (C.offlinePay(10, math.huge)) == 144000)
	O.On = 0
	ok("switched off pays nothing", (C.offlinePay(10, HOUR)) == 0)
	O.On = 1
end

----------------------------------------------------------------------------------------------------------------------
print("saving on in the live game")
fresh()
do
	local live = roblox.server({ NoStudio = true })
	local p = live.join("ann")
	roblox.pass(3)
	live.putIn(p, "Clownfish", true)
	roblox.pass(3)
	ok("the tank and Index load with the live defaults", p:GetAttribute("SavedTank") and p:GetAttribute("SavedIndex"))
	ok("nothing is owed", owed(p) == 0)
	live.ask(p, "Claim")
	ok("a claim pays nothing", live.coins(p) == 0 and live.answer(p) == "Denied")
	live.set("OfflineAway", 2 * HOUR)
	roblox.pass(1)
	ok("the Studio test does nothing in a live game", owed(p) == 0)
	live.stop()
	noFaults("off")
end

----------------------------------------------------------------------------------------------------------------------
print("away an hour, claimed once")
fresh()
do
	firstVisit("ann")
	local kept = roblox.kept("ann")
	ok(
		"the last save says when and what the tank earned",
		kept.Offline and near(kept.Offline.Rate, RATE, 1e-9),
		kept.Offline
	)
	ok("nothing was owed on a first visit", kept.Offline.Owed == 0)
	roblox.skip(HOUR)
	local s, p = back("ann")
	local due = owed(p)
	ok(
		"half of an hour of its equipped fish, whole",
		near(due, RATE * HOUR * 0.5, RATE * 8) and whole(due) and due > 0,
		`{due} for {RATE}/s`
	)
	ok("the seconds too", near(p:GetAttribute("OfflineSecs"), HOUR, 12), p:GetAttribute("OfflineSecs"))
	ok("no coins before the claim", s.coins(p) == 0)
	roblox.pass(30)
	ok("it doesn't grow while they stand there", owed(p) == due)
	s.ask(p, "Claim")
	local what, amount = s.answer(p)
	ok("the claim pays it", s.coins(p) == due and what == "Paid" and amount == due)
	ok("nothing is owed after", owed(p) == 0 and p:GetAttribute("OfflineSecs") == nil)
	s.ask(p, "Claim")
	ok("a double click pays once", s.coins(p) == due)
	roblox.pass(1)
	s.ask(p, "Claim")
	ok("nor does a later one", s.coins(p) == due and select(2, s.answer(p)) == "Nothing")
	s.ask(p, "Claim", 1e12)
	s.ask(p, 5)
	s.ask(p, { "Claim" })
	ok("a made-up ask pays nothing", s.coins(p) == due)
	s.stop()
	s, p = back("ann")
	ok("a rejoin has the coins once and nothing to claim", s.coins(p) == due and owed(p) == 0, s.coins(p))
	s.stop()
	noFaults("claim")
end

----------------------------------------------------------------------------------------------------------------------
print("a short absence, none claimed, and adding up")
fresh()
do
	firstVisit("bo")
	roblox.skip(200)
	local s, p = back("bo")
	ok("away 200 s pays nothing", owed(p) == 0)
	s.stop()
	roblox.skip(HOUR)
	s, p = back("bo")
	local first = owed(p)
	ok("an hour after that visit pays the hour", near(first, RATE * HOUR * 0.5, RATE * 8), first)
	s.stop()
	ok("not claimed: the save holds it", roblox.kept("bo").Offline.Owed == first)
	s, p = back("bo")
	ok("the next join has it still, no more and no less", owed(p) == first, owed(p))
	s.stop()
	roblox.skip(2 * HOUR)
	s, p = back("bo")
	ok("a second absence is added to it", near(owed(p), first + RATE * 2 * HOUR * 0.5, RATE * 8), owed(p))
	ok("and its seconds", near(p:GetAttribute("OfflineSecs"), 3 * HOUR, 24))
	local all = owed(p)
	s.ask(p, "Claim")
	ok("claimed all at once", s.coins(p) == all)
	roblox.pass(1)
	s.stop()
	roblox.skip(60 * 24 * HOUR)
	s, p = back("bo")
	ok("60 days pay for 8 h", near(owed(p), RATE * 8 * HOUR * 0.5, 1), owed(p))
	ok("and the coins are still there", s.coins(p) == all)
	s.stop()
	noFaults("adding up")
end

----------------------------------------------------------------------------------------------------------------------
print("no fish, and only stored fish")
fresh()
do
	local a = roblox.server({})
	local p = a.join("cy")
	roblox.pass(3)
	a.stop()
	roblox.skip(HOUR)
	local s
	s, p = back("cy")
	ok("an empty tank pays nothing and shows nothing", owed(p) == 0 and p:GetAttribute("OfflineSecs") == nil)
	s.putIn(p, "Clownfish", false)
	s.stop()
	roblox.skip(HOUR)
	s, p = back("cy")
	ok("nor do stored fish", owed(p) == 0)
	s.putIn(p, "Clownfish", true)
	roblox.pass(1)
	s.putIn(p, "Clownfish", true)
	s.stop()
	ok("the fish there at the very end count", roblox.kept("cy").Offline.Rate > 0)
	noFaults("no fish")
end

----------------------------------------------------------------------------------------------------------------------
print("a server whose clock is wrong")
fresh()
do
	firstVisit("di")
	roblox.skip(HOUR)
	local s, p = back("di", { Skew = -24 * HOUR })
	ok("a clock a day behind pays nothing", owed(p) == 0 and s.Offline.dump(p).Owed == 0)
	s.stop()
	roblox.skip(HOUR)
	s, p = back("di")
	ok("the next right clock pays no more than the most", owed(p) <= RATE * 8 * HOUR * 0.5 + 1, owed(p))
	local held = owed(p)
	s.stop()
	s, p = back("di", { Skew = -24 * HOUR })
	ok("what was owed is not lost to a wrong clock", owed(p) == held and held > 0)
	s.stop()
	fresh()
	firstVisit("di", { Skew = 30 * 24 * HOUR })
	roblox.skip(HOUR)
	s, p = back("di")
	ok("left on a server a month ahead: nothing, no error", owed(p) == 0)
	s.stop()
	noFaults("clock")
end

----------------------------------------------------------------------------------------------------------------------
print("two servers at once (ProfileStore's session lock)")
for _, deaf in { false, true } do
	fresh()
	roblox.deaf = deaf
	local how = if deaf then "messages lost" else "by message"
	firstVisit("ed")
	roblox.skip(2 * HOUR)
	local a, pa = back("ed")
	local due = owed(pa)
	ok(`{how}: the first server has it`, due > 0)
	local b = roblox.server({})
	local pb = b.join("ed")
	a.ask(pa, "Claim") -- (claimed on the first while the second waits)
	ok(`{how}: claimed on the first`, a.coins(pa) == due)
	ok(`{how}: the second has nothing while it waits`, owed(pb) == 0 and b.coins(pb) == 0)
	b.ask(pb, "Claim")
	ok(`{how}: nor can it be claimed there`, b.coins(pb) == 0)
	roblox.pass(130)
	-- By message the first saves the claim and lets go at once. With its messages lost the second takes the session from
	-- what was saved last, and the first hears of it at its next save: what it paid is in no save.
	ok(`{how}: the first is sent off at once only when it hears`, (pa.Kicked ~= nil) == not deaf, pa.Kicked)
	local total = b.coins(pb) + owed(pb)
	ok(
		`{how}: the second has it once, paid or owed`,
		if deaf then b.coins(pb) == 0 and near(total, due, RATE * 100) else b.coins(pb) == due and owed(pb) == 0,
		`{b.coins(pb)} + {owed(pb)} for {due}`
	)
	roblox.pass(1)
	b.ask(pb, "Claim")
	ok(`{how}: one claim at most there`, b.coins(pb) == total and owed(pb) == 0)
	roblox.pass(700)
	ok(`{how}: the first is sent off in the end`, pa.Kicked ~= nil)
	a.stop()
	b.stop()
	ok(
		`{how}: the save has it once`,
		roblox.kept("ed").Tank.Coins == total and roblox.kept("ed").Offline.Owed == 0,
		roblox.kept("ed").Tank.Coins
	)
	noFaults(how)
end
do
	-- not claimed on the first: it moves over, and is claimed on one only
	fresh()
	firstVisit("flo")
	roblox.skip(2 * HOUR)
	local a, pa = back("flo", { AquariumFirst = false })
	local due = owed(pa)
	local b = roblox.server({})
	local pb = b.join("flo")
	roblox.pass(130)
	ok("unclaimed: it moves to the second server", owed(pb) == due and b.coins(pb) == 0, owed(pb))
	a.ask(pa, "Claim")
	ok("the first can't pay it any more", a.coins(pa) == 0)
	b.ask(pb, "Claim")
	ok("the second pays it once", b.coins(pb) == due and owed(pb) == 0)
	roblox.pass(1)
	b.stop()
	ok("and it is kept so", roblox.kept("flo").Tank.Coins == due and roblox.kept("flo").Offline.Owed == 0)
	noFaults("moved")
end
do
	-- the session is taken while the player is still on the first: a claim there is refused
	fresh()
	firstVisit("gus")
	roblox.skip(2 * HOUR)
	local a, pa = back("gus")
	pa.Kick = function() end -- (a client that hangs on)
	local b = roblox.server({})
	local pb = b.join("gus")
	roblox.pass(130)
	local due = owed(pb)
	roblox.pass(1)
	a.ask(pa, "Claim")
	ok("a server that lost the session refuses a claim", a.coins(pa) == 0 and select(2, a.answer(pa)) == "Save")
	b.ask(pb, "Claim")
	ok("the one that has it pays", b.coins(pb) == due and due > 0)
	noFaults("lost session")
end

----------------------------------------------------------------------------------------------------------------------
print("a lost reply, a lost connection, a crash")
for _, aquariumFirst in { true, false } do
	fresh()
	local order = if aquariumFirst then "tank let go first" else "saved first"
	local opts = { AquariumFirst = aquariumFirst }
	firstVisit("hal", opts)
	roblox.skip(HOUR)
	local s, p = back("hal", opts)
	local due = owed(p)
	s.lose = true
	s.ask(p, "Claim")
	ok(`{order}: the answer is lost, the coins are there`, s.coins(p) == due and s.answer(p) == nil)
	s.lose = false
	roblox.pass(1)
	s.ask(p, "Claim")
	ok(`{order}: asked again, nothing more`, s.coins(p) == due and select(2, s.answer(p)) == "Nothing")
	s.stop()
	roblox.skip(HOUR)
	s, p = back("hal", opts)
	local second = owed(p)
	s.ask(p, "Claim")
	s.leave(p) -- (the connection goes in the very moment of the claim)
	roblox.pass(5)
	s.stop()
	s, p = back("hal", opts)
	if not aquariumFirst then
		ok(`{order}: the last snapshot has the claim of that very moment`, s.coins(p) == due + second and owed(p) == 0)
	end
	local total = s.coins(p) + owed(p)
	ok(`{order}: gone as they claimed: paid or still owed, once`, total == due + second, `{s.coins(p)} + {owed(p)}`)
	s.ask(p, "Claim")
	ok(`{order}: in the end they have it once`, s.coins(p) == due + second and owed(p) == 0)
	roblox.pass(1)
	s.stop()
	ok(
		`{order}: and it is kept`,
		roblox.kept("hal").Tank.Coins == due + second and roblox.kept("hal").Offline.Owed == 0
	)
	noFaults(order)
end
do
	fresh()
	firstVisit("ivy")
	roblox.skip(HOUR)
	local s, p = back("ivy")
	local due = owed(p)
	s.ask(p, "Claim")
	ok("claimed, then the server dies before any save", s.coins(p) == due)
	s.crash()
	local b = roblox.server({})
	local pb = b.join("ivy")
	roblox.pass(200)
	ok(
		"the next server has neither the coins nor the claim",
		b.coins(pb) == 0 and owed(pb) >= due,
		`{b.coins(pb)} + {owed(pb)}`
	)
	ok("and no more than the same absence, to the minute", near(owed(pb), due, RATE * 260), `{owed(pb)} for {due}`)
	local again = owed(pb)
	b.ask(pb, "Claim")
	roblox.pass(1)
	b.stop()
	ok("claimed there, kept once", roblox.kept("ivy").Tank.Coins == again)
	noFaults("crash")
end
do
	fresh()
	firstVisit("jo")
	roblox.skip(HOUR)
	local s, p = back("jo")
	local due = owed(p)
	roblox.down = true
	s.ask(p, "Claim")
	s.leave(p)
	roblox.pass(20)
	ok("the store is down as they leave: nothing written yet", roblox.kept("jo").Tank.Coins == 0)
	roblox.down = false
	roblox.pass(60)
	s.stop()
	s, p = back("jo")
	ok("it comes back, and they have it once", s.coins(p) + owed(p) == due, `{s.coins(p)} + {owed(p)}`)
	s.stop()
	noFaults("store down")
end

----------------------------------------------------------------------------------------------------------------------
print("the order things come in")
fresh()
do
	firstVisit("kim")
	roblox.skip(HOUR)
	local s = roblox.server({ RideLate = 6 }) -- (RideService has them six seconds after the tank does)
	local p = s.join("kim")
	roblox.pass(3)
	ok(
		"before the tank's own part is in, nothing is owed or written",
		owed(p) == 0 and p:GetAttribute("SavedOffline") == nil
	)
	s.ask(p, "Claim")
	ok("nor paid", s.coins(p) == 0)
	roblox.pass(6)
	ok("then both", p:GetAttribute("SavedTank") == true and owed(p) > 0)
	s.stop()
	ok("and the rate kept is the tank's, not an empty one's", near(roblox.kept("kim").Offline.Rate, RATE, 1e-9))

	roblox.skip(HOUR)
	s = roblox.server({})
	s.noTank["kim"] = true
	local before = roblox.kept("kim").Offline.Left
	p = s.join("kim")
	roblox.pass(5)
	s.ask(p, "Claim")
	ok("no tank: nothing shown or paid", owed(p) == 0 and select(2, s.answer(p)) == "Nothing")
	ok("and nothing written over", roblox.kept("kim").Offline.Left == before)
	s.claimPlot(p)
	roblox.pass(2)
	ok("a tank comes free: it is owed then", owed(p) > 0)
	s.stop()
	noFaults("order")
end

----------------------------------------------------------------------------------------------------------------------
print("odd saves, and the switch")
fresh()
do
	firstVisit("lou")
	for i, odd in
		{
			{ Left = "x", Rate = 5, Owed = 10 },
			{ Rate = 5, Owed = 10 },
			{ Left = 0 / 0, Rate = 5, Owed = 10 },
			{ Left = -5, Rate = math.huge, Owed = 10.9 },
			"a text",
			{},
		} :: { any }
	do
		roblox.keep("lou", "Offline", odd)
		local s, p = back("lou")
		local want = if type(odd) == "table" and odd.Owed then 10 else 0
		ok(`odd save {i}: nobody is sent off, {want} owed`, p.Kicked == nil and owed(p) == want, owed(p))
		s.stop()
	end
	roblox.keep("lou", "Offline", nil)
	local s, p = back("lou")
	ok(
		"a save from before this part: nothing owed, and it starts",
		owed(p) == 0 and p:GetAttribute("SavedOffline") == true
	)
	s.stop()
	roblox.skip(HOUR)
	s, p = back("lou")
	local due = owed(p)
	s.stop()
	local off = roblox.server({})
	off.Config.Offline.On = 0
	p = off.join("lou")
	roblox.pass(3)
	off.ask(p, "Claim")
	ok("switched off: nothing shows or pays", owed(p) == 0 and off.coins(p) == 0)
	off.stop()
	s, p = back("lou")
	ok("switched on again: what was owed is still there", owed(p) == due and due > 0, owed(p))
	s.stop()
	noFaults("odd")
end

----------------------------------------------------------------------------------------------------------------------
print("Studio's test attribute, with no save")
fresh()
do
	local s = roblox.server({ SaveOn = false, Workspace = { SaveReal = false, OfflineAway = 2 * HOUR } })
	local p = s.join("mo")
	roblox.pass(2)
	ok("an empty tank is pretended at $100 a second", owed(p) == 100 * 2 * HOUR * 0.5, owed(p))
	s.ask(p, "Claim")
	ok("it can be claimed with no save, once", s.coins(p) == 360000 and owed(p) == 0)
	s.putIn(p, "Clownfish", true)
	s.set("OfflineAway", 20 * HOUR)
	roblox.pass(1)
	local rate = s.Config.incomeOf(s.Config.FishById.Clownfish, "Normal", "")
	ok(
		"changed while it runs: the tank's own rate, 8 h at most",
		owed(p) == math.floor(rate * 8 * HOUR * 0.5 + 1e-6),
		owed(p)
	)
	s.set("OfflineRate", 0)
	local had = owed(p)
	s.set("OfflineAway", 5 * HOUR)
	s.set("OfflineAway", -HOUR)
	s.set("OfflineAway", 10)
	roblox.pass(1)
	ok("no fish, time backwards and too short add nothing", owed(p) == had)
	s.stop()
	local real = roblox.server({ SaveOn = false, Workspace = { OfflineAway = 2 * HOUR } })
	p = real.join("mo")
	roblox.pass(2)
	ok("with Roblox's own store on it does nothing", owed(p) == 0)
	real.stop()
	noFaults("test")
end

print("a profile from before saddles, across servers")
fresh()
do
	firstVisit("old")
	local parts = roblox.kept("old")
	local coins = parts.Tank.Coins
	roblox.keep("old", "Index", {
		Lands = { ["1"] = true, ["99"] = true },
		Kinds = { RetiredFish = true },
		Looks = { RetiredFish = { "OldSize|" } },
	})
	local s = roblox.server({})
	local p = s.join("old")
	for _, fish in s.Config.indexSet(1) do
		s.putIn(p, fish.Id, false)
	end
	s.Index.look(p)
	s.Index.ask(p, "ClaimLand", 1)
	ok("an old claim cannot pay while its profile loads", s.coins(p) == 0 and p:GetAttribute("IndexPaid") == false)
	roblox.pass(3)
	ok("legacy profile loads with no worn saddle", p:GetAttribute("SavedIndex") and p:GetAttribute("Saddle") == 0)
	s.Index.ask(p, "ClaimLand", 1)
	ok("the restored land cannot pay again", s.coins(p) == coins)
	roblox.pass(1)
	s.Index.ask(p, "Saddle", 1)
	ok("a legacy land claim already owns its saddle", p:GetAttribute("Saddle") == 1)
	roblox.pass(1)
	s.stop()
	local saved = roblox.kept("old").Index
	ok(
		"claimed lands, retired looks and the worn land survive saving",
		saved.Saddle == 1 and saved.Lands["99"] and saved.Kinds.RetiredFish and saved.Looks.RetiredFish[1] == "OldSize|"
	)
	s, p = back("old")
	ok("another server restores the worn saddle", p:GetAttribute("Saddle") == 1 and s.coins(p) == coins)
	s.Index.ask(p, "Saddle", 0)
	roblox.pass(1)
	s.stop()
	s, p = back("old")
	ok(
		"taking it off persists and keeps ownership",
		p:GetAttribute("Saddle") == 0 and roblox.kept("old").Index.Lands["1"]
	)
	s.stop()
	noFaults("legacy Index")
end

done()
