-- Fusing, checked offline (NULLROOM task u1; docs/design/fusing.md): the rules, the server's one step with the game's
-- own RideService and AquariumService (tools/fuse/world.luau), and the races: two asks at once, a sale, an equip, a
-- take-out or a put-in between the picking and the press, an ask that breaks half way through its telling, leaving.
-- After every ask, refused or not, the fish are counted: none lost, none doubled.
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/fuse/fuse_test.luau /tmp/place.rbxl [economy]
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Harness = require("../index/harness")
local World = require("./world")

local Vector3 = (roblox :: any).Vector3
local place = process.args[1] or "/tmp/place.rbxl"
local ok, done = Harness.tally()

local w = World.new(place)
w.plot(1)
w.plot(2)
local Config = w.require("ReplicatedStorage.Shared.Config")
local Fuse = w.require("ReplicatedStorage.Shared.Fuse")
local Ride = w.service("RideService")
local Tank = w.service("AquariumService")
local Service = w.service("FuseService")
local Index = w.service("IndexService")
for _, s in { Ride, Tank, Index, Service } do
	if s.Init then
		s.Init()
	end
end
for _, s in { Ride, Tank, Index, Service } do
	if s.Start then
		coroutine.wrap(s.Start)()
	end
end
Config.Aquarium.AutoEquip = 0 -- (a fish put in is stored, unless a check equips it)

local KIND, OTHER = "Clownfish", "Pufferfish"
for _, id in { KIND, OTHER } do
	assert(Config.FishById[id], "no " .. id)
end

----------------------------------------------------------------------------------------------------------------------
-- Helpers: give, name and count fish

local AT = Vector3.new(102, 3, 101)
local made = 0
-- (the ones before leave, unless `with` them: the map has two tanks)
local function newcomer(with: boolean?): any
	made += 1
	if not with then
		for _, old in table.clone(w.players) do
			w.leave(old)
		end
	end
	local p = w.join("P" .. made)
	w.stand(p, AT)
	return p
end

-- A stored fish in the tank: its key as an ask names it ("T" and the entry's Key)
local function tank(p: any, size: string, variant: string?, id: string?): string
	local had = {}
	for _, f in Tank.tankOf(p) do
		had[f] = true
	end
	assert(Tank.give(p, 0, { { id or KIND, size, variant or "" } }), "no tank")
	for _, f in Tank.tankOf(p) do
		if not had[f] then
			return "T" .. f.Key
		end
	end
	error("not given")
end

local function hand(p: any, size: string, variant: string?, id: string?): string
	assert(Ride.giveCarried(p, { Id = id or KIND, Size = size, Variant = variant or "" }), "hands full")
	local list = Ride.carried(p)
	return "H" .. list[#list].Key
end

-- Every fish a player has, as text, in the same order whatever order they are kept in
local function all(p: any): string
	local rows = {}
	for _, f in Tank.tankOf(p) or {} do
		table.insert(rows, `T{f.Key} {f.Id} {f.Size} {f.Variant}{if f.On then " on" else ""}`)
	end
	for _, f in Ride.carried(p) do
		table.insert(rows, `H{f.Key} {f.Id} {f.Size} {f.Variant}`)
	end
	table.sort(rows)
	return table.concat(rows, "; ")
end

local function count(p: any): number
	return #(Tank.tankOf(p) or {}) + #Ride.carried(p)
end

local function at(p: any, key: string): any
	local from, name = string.sub(key, 1, 1), string.sub(key, 2)
	for _, f in if from == "T" then Tank.tankOf(p) else Ride.carried(p) do
		if tostring(f.Key) == name then
			return f
		end
	end
	return nil
end

-- One ask as a client sends it: what the server answered ("Fused", info | "FuseDenied", why | nil)
local function ask(p: any, picks: any, soon: boolean?): (string?, any)
	if not soon then
		w.clock += 5
	end
	local n = #w.sent
	w.ask(p, "Fuse", picks)
	for i = #w.sent, n + 1, -1 do
		local row = w.sent[i]
		if row.Player == p and (row[1] == "Fused" or row[1] == "FuseDenied") then
			return row[1], row[2]
		end
	end
	return nil, nil
end

-- A refusal: the reason, and nothing at all changed
local function refused(what: string, p: any, picks: any, why: string?)
	local before, coins = all(p), Tank.coinsOf(p)
	local kind, reason = ask(p, picks)
	ok(what, (if why then kind == "FuseDenied" and reason == why else kind == nil), `{kind} {reason}`)
	ok("  and nothing changed", all(p) == before and Tank.coinsOf(p) == coins, all(p))
end

----------------------------------------------------------------------------------------------------------------------
print("The rules (Shared/Fuse)")
local function fish(size: string, variant: string?, id: string?): any
	return { Id = id or KIND, Size = size, Variant = variant or "" }
end
local out, why = Fuse.outcome({ fish("Normal"), fish("Huge"), fish("Tiny") })
ok("the biggest stays, wherever it was put", out and out.Keep == 2 and out.From == "Huge" and out.To == "Colossal")
ok("the other two are used up", out and out.Used[1] == 1 and out.Used[2] == 3 and #out.Used == 2)
for i, size in Config.SizeOrder do
	local o, no = Fuse.outcome({ fish(size), fish(size), fish(size) })
	if i < #Config.SizeOrder then
		ok(`three {size}: one {Config.SizeOrder[i + 1]}`, o and o.To == Config.SizeOrder[i + 1] and o.Keep == 1)
	else
		ok(`three {size}: refused, it can't grow`, o == nil and no == "Top")
	end
end
out = Fuse.outcome({ fish("Tiny", "Rainbow"), fish("Big", ""), fish("Normal", "Gold") })
ok("the biggest is by size, never by colour", out and out.Keep == 2)
out = Fuse.outcome({ fish("Big", ""), fish("Big", "Rainbow"), fish("Tiny") })
ok("equally big: the first put in stays, its colour or not", out and out.Keep == 1)
out, why = Fuse.outcome({ fish("Big"), fish("Big") })
ok("two are not three", out == nil and why == "Three", why)
out, why = Fuse.outcome({ fish("Big"), fish("Big"), fish("Big"), fish("Big") })
ok("four are not three", out == nil and why == "Three", why)
out, why = Fuse.outcome({ fish("Big"), fish("Big"), fish("Big", "", OTHER) })
ok("not the same kind", out == nil and why == "Kind", why)
out, why = Fuse.outcome({ fish("Big"), fish("Colossal"), fish("Big") })
ok("a Colossal among them", out == nil and why == "Top", why)
out, why = Fuse.outcome({ fish("Big"), fish("Enormous"), fish("Big") })
ok("not a size", out == nil and why == "Gone", why)
out, why = Fuse.outcome({ fish("Big", "", "Nofish"), fish("Big", "", "Nofish"), fish("Big", "", "Nofish") })
ok("not a fish", out == nil and why == "Gone", why)
Config.Fuse.SameSize = 1
out, why = Fuse.outcome({ fish("Big"), fish("Tiny"), fish("Big") })
ok("SameSize 1: not the same size", out == nil and why == "Size", why)
out = Fuse.outcome({ fish("Big"), fish("Big", "Gold"), fish("Big") })
ok("SameSize 1: the colours may differ", out and out.To == "Giant")
Config.Fuse.SameSize = 0
ok("special: any colour", Fuse.special(fish("Tiny", "Silver")) and Fuse.special(fish("Normal", "Rainbow")))
ok("special: big, plain", Fuse.special(fish("Giant")) and Fuse.special(fish("Colossal")))
ok("not special: small, plain", not Fuse.special(fish("Tiny")) and not Fuse.special(fish("Big")))

----------------------------------------------------------------------------------------------------------------------
print("The step: three stored in the tank")
local p = newcomer()
local a, b, c = tank(p, "Normal"), tank(p, "Big", "Gold"), tank(p, "Tiny", "Rainbow")
local extra = tank(p, "Giant", "Silver")
local kind, info = ask(p, { a, b, c })
ok("fused", kind == "Fused", `{kind} {info}`)
ok("two fish fewer", count(p) == 2, all(p))
ok("the biggest is there still, the same fish, a size bigger", at(p, b) and at(p, b).Size == "Giant", all(p))
ok("its own colour kept, nothing inherited (Gold, not Rainbow)", at(p, b) and at(p, b).Variant == "Gold")
ok("the other two are gone", at(p, a) == nil and at(p, c) == nil)
ok(
	"a fish that was not picked is as it was",
	at(p, extra) and at(p, extra).Size == "Giant" and at(p, extra).Variant == "Silver"
)
ok(
	"the answer says which, from what to what, and what was used",
	type(info) == "table"
		and info.Id == KIND
		and info.From == "Big"
		and info.To == "Giant"
		and info.Variant == "Gold"
		and info.Pick == b
		and #info.Used == 2
)
ok(
	"the list on the player's machine follows",
	string.find(p:GetAttribute("TankList"), '"Giant","Gold"', 1, true) ~= nil
)
ok("the count follows", p:GetAttribute("TankFish") == 2)

print("A plain biggest with a Rainbow used up")
p = newcomer()
a, b, c = tank(p, "Big"), tank(p, "Normal", "Rainbow"), tank(p, "Normal", "Gold")
ask(p, { c, b, a })
ok("stays plain", count(p) == 1 and at(p, a).Size == "Giant" and at(p, a).Variant == "", all(p))

print("Equally big: the first slot")
p = newcomer()
a, b, c = tank(p, "Normal", "Gold"), tank(p, "Normal"), tank(p, "Normal", "Rainbow")
ask(p, { c, a, b })
ok(
	"the first put in stayed",
	count(p) == 1 and at(p, c) and at(p, c).Variant == "Rainbow" and at(p, c).Size == "Big",
	all(p)
)

----------------------------------------------------------------------------------------------------------------------
print("From the hands, and from both")
p = newcomer()
a, b, c = hand(p, "Tiny"), hand(p, "Big", "Silver"), hand(p, "Normal")
extra = hand(p, "Normal", "", OTHER)
local grown = at(p, b)
kind = ask(p, { a, b, c })
ok("fused in the hands", kind == "Fused" and #Ride.carried(p) == 2, all(p))
ok(
	"the very same fish (its table and its slot's key)",
	at(p, b) == grown and grown.Size == "Giant" and grown.Variant == "Silver"
)
ok("the one not picked is as it was", at(p, extra) ~= nil and at(p, extra).Id == OTHER)
local told: any = nil
for _, row in w.sent do
	if row.Player == p and row[1] == "Caught" then
		told = row[2]
	end
end
ok(
	"the bar is told: two fish, the grown one Giant",
	told and #told == 2 and told[1][2] == "Giant" and told[1][4] == grown.Key
)
ok(
	"what they carry, for the windows, has each fish's key",
	p:GetAttribute("Hands") == `[["{KIND}","Giant","Silver",{grown.Key}],["{OTHER}","Normal","",{at(p, extra).Key}]]`,
	p:GetAttribute("Hands")
)
ok("the bar still takes one more and puts it at the end", hand(p, "Tiny") ~= nil and #Ride.carried(p) == 3)
ok("the ids and the fish stay side by side (a take-out takes the right one)", Ride.takeCarried(p, 2).Id == OTHER)

p = newcomer()
a, b, c = tank(p, "Huge"), hand(p, "Tiny"), hand(p, "Tiny")
kind = ask(p, { b, a, c })
ok(
	"biggest in the tank, two from the hands",
	kind == "Fused" and at(p, a).Size == "Colossal" and #Ride.carried(p) == 0,
	all(p)
)
p = newcomer()
a, b, c = hand(p, "Huge", "Gold"), tank(p, "Tiny"), tank(p, "Tiny")
kind = ask(p, { b, a, c })
ok(
	"biggest in the hands, two from the tank",
	kind == "Fused" and at(p, a).Size == "Colossal" and at(p, a).Variant == "Gold" and #Tank.tankOf(p) == 0,
	all(p)
)

print("Held over the head")
p = newcomer()
a, b, c = hand(p, "Normal"), hand(p, "Big"), hand(p, "Tiny")
w.clock += 5
w.ask(p, "Hold", 2, KIND)
ok("holding it", p:GetAttribute("HeldFish") == KIND and p:GetAttribute("HeldSize") == "Big")
local model = w.built[#w.built]
ask(p, { a, b, c })
ok(
	"grown in the hands: still held, its new size told",
	Tank.heldOf(p) == at(p, b) and p:GetAttribute("HeldSize") == "Giant" and p:GetAttribute("HeldIndex") == 1
)
ok(
	"and its model made again, bigger",
	model.Gone == true and w.built[#w.built] ~= model and w.built[#w.built].Attributes.SizeTier == "Giant"
)
a, b = hand(p, "Tiny"), hand(p, "Tiny")
c = "H" .. Ride.carried(p)[1].Key
w.clock += 5
w.ask(p, "Hold", 2, KIND)
ok("holding a small one", p:GetAttribute("HeldIndex") == 2)
ask(p, { a, b, c })
ok("used up: put away", Tank.heldOf(p) == nil and p:GetAttribute("HeldFish") == nil and count(p) == 1)

----------------------------------------------------------------------------------------------------------------------
print("Refused, and nothing changed")
p = newcomer()
local other = newcomer(true)
a, b, c = tank(p, "Normal"), tank(p, "Big", "Gold"), hand(p, "Tiny", "Rainbow")
local d = tank(p, "Colossal")
local e = tank(p, "Big", "", OTHER)
local theirs = tank(other, "Normal")
local theirHand = hand(other, "Normal")
refused("two fish", p, { a, b }, nil)
refused("four fish", p, { a, b, c, e }, nil)
refused("the same fish three times", p, { a, a, a }, nil)
refused("the same fish twice", p, { a, b, b }, nil)
refused("nothing", p, nil, nil)
refused("not a list", p, "all", nil)
refused("not names", p, { 1, 2, 3 }, nil)
refused("odd names", p, { "X1", "T", "H-1" }, nil)
refused("a name far too long", p, { a, b, "T" .. string.rep("1", 5000) }, nil)
refused("the same fish by two spellings", p, { a, "T0" .. string.sub(a, 2), b }, "Gone")
refused("a map, not a list", p, { x = a, y = b, z = c }, nil)
refused("three and more under other names", p, { [1] = a, [2] = b, [3] = c, more = true }, nil)
refused("a fish that isn't there", p, { a, b, "T9999" }, "Gone")
refused("a carried fish that isn't there", p, { a, b, "H9999" }, "Gone")
refused("another player's tank fish", p, { a, b, "T77" }, "Gone")
do
	-- (two tanks count their own keys: the other player's key may be a key of ours, so give it one that is not)
	for _ = 1, 8 do
		theirs = tank(other, "Normal")
	end
	refused("another player's stored fish", p, { a, b, theirs }, "Gone")
end
refused("another player's carried fish", p, { a, b, theirHand }, "Gone")
refused("another kind", p, { a, b, e }, "Kind")
refused("a Colossal among them", p, { a, b, d }, "Top")
Config.Fuse.SameSize = 1
refused("SameSize 1: sizes mixed", p, { a, b, c }, "Size")
Config.Fuse.SameSize = 0
Config.Fuse.On = 0
refused("switched off", p, { a, b, c }, "Off")
Config.Fuse.On = 1

print("Where the player stands")
w.stand(p, Vector3.new(100 + Config.Fuse.Near + 1, 3, 100))
refused("too far from the machine", p, { a, b, c }, "Far")
w.stand(p, Vector3.new(100, 400, 100))
refused("over it, high up", p, { a, b, c }, "Far")
w.stand(p, AT)
p.Character:FindFirstChildOfClass("Humanoid").Health = 0
refused("dead", p, { a, b, c }, "Dead")
p.Character:FindFirstChildOfClass("Humanoid").Health = 100
w.ring.Parent = nil
refused("no ring in the place", p, { a, b, c }, "Far")
w.ring.Name = "Base"
w.ring.Parent = w.machine
w.machine.PrimaryPart = w.ring
kind = Service.atMachine(p)
ok("no part named Ring, but the station's PrimaryPart is one", kind == nil, kind)
w.ring.Name = "Ring"
p:SetAttribute("TankRide", "x")
refused("riding a fish in the tank", p, { a, b, c }, "Busy")
p:SetAttribute("TankRide", nil)
p:SetAttribute("TrainerRide", true)
refused("on the seahorse", p, { a, b, c }, "Busy")
p:SetAttribute("TrainerRide", nil)
do
	local was = Ride.stateOf
	Ride.stateOf = function()
		return "Riding"
	end
	refused("in the water", p, { a, b, c }, "Dock")
	Ride.stateOf = was
end
ok("and then it works", (ask(p, { a, b, c })) == "Fused" and at(p, b).Size == "Giant", all(p))

print("The ride fish, and one that earns")
p = newcomer()
a, b, c = hand(p, "Normal"), hand(p, "Big"), hand(p, "Tiny")
w.clock += 5
w.ask(p, "Hold", 2, KIND)
Config.Equip.Again = 0
pcall(w.ask, p, "RideEquip") -- (the fish on land is not built offline)
ok("the Big one is the ride fish", Ride.equippedOf(p) == at(p, b))
refused("the ride fish as the biggest", p, { a, b, c }, "Ride")
d = hand(p, "Giant")
refused("the ride fish as one used up", p, { a, b, d }, "Ride")
w.ask(p, "RideUnequip")
ok("unequipped, it may", (ask(p, { a, b, c })) == "Fused" and at(p, b).Size == "Giant", all(p))
a = hand(p, "Tiny")
c = hand(p, "Tiny")
w.clock += 5
w.ask(p, "Hold", 1, KIND)
pcall(w.ask, p, "RideEquip") -- (the fish on land is not built offline)
local mount = Ride.equippedOf(p)
e = hand(p, "Tiny")
kind = ask(p, { a, c, e })
ok(
	"the others fused: the ride fish is the ride fish still",
	kind == "Fused" and mount ~= nil and Ride.equippedOf(p) == mount and p:GetAttribute("EquippedIndex") == 1,
	all(p)
)

p = newcomer()
Config.Aquarium.AutoEquip = 1
a = tank(p, "Big", "Gold")
Config.Aquarium.AutoEquip = 0
b, c = tank(p, "Normal"), tank(p, "Normal")
ok("one earns", at(p, a).On == true and p:GetAttribute("Income") > 0)
refused("a fish that earns", p, { a, b, c }, "Equipped")
Config.Fuse.Earning = 1
local income = p:GetAttribute("Income")
local shown = w.built[#w.built]
kind = ask(p, { b, a, c })
local now = Config.incomeOf(Config.FishById[KIND], "Giant", "Gold")
ok(
	"Earning 1: it may, and earns still, more",
	kind == "Fused" and at(p, a).On and p:GetAttribute("Income") == now and now > income,
	p:GetAttribute("Income")
)
ok(
	"  and it is shown bigger in the water",
	w.built[#w.built] ~= shown and w.built[#w.built].Attributes.SizeTier == "Giant"
)
b, c = tank(p, "Huge"), tank(p, "Tiny")
kind = ask(p, { b, a, c })
ok(
	"  used up, its income is gone with it",
	kind == "Fused" and p:GetAttribute("Income") == 0 and count(p) == 1 and not at(p, b).On
)
Config.Fuse.Earning = 0

print("The price")
p = newcomer()
a, b, c = tank(p, "Normal"), tank(p, "Big"), tank(p, "Tiny")
Config.Fuse.Price = 100
refused("too few coins", p, { a, b, c }, "Coins")
Tank.give(p, 99)
refused("one short", p, { a, b, c }, "Coins")
Tank.give(p, 51)
kind = ask(p, { a, b, c })
ok("paid once", kind == "Fused" and Tank.coinsOf(p) == 50 and p:GetAttribute("Coins") == 50, Tank.coinsOf(p))
Config.Fuse.Price = 0 / 0
b, c = tank(p, "Tiny"), tank(p, "Tiny")
a = "T" .. Tank.tankOf(p)[1].Key
refused("a price that is no number", p, { a, b, c }, "Off")
Config.Fuse.Price = -5
refused("a price under nothing", p, { a, b, c }, "Off")
Config.Fuse.Price = 0

----------------------------------------------------------------------------------------------------------------------
print("Races")
p = newcomer()
a, b, c = tank(p, "Normal"), tank(p, "Big"), tank(p, "Tiny")
kind = ask(p, { a, b, c })
local again = ask(p, { a, b, c }, true)
ok(
	"a double click: one fusing, the second not even answered",
	kind == "Fused" and again == nil and count(p) == 1 and at(p, b).Size == "Giant",
	all(p)
)
kind, info = ask(p, { a, b, c })
ok("the same ask later: gone", kind == "FuseDenied" and info == "Gone" and at(p, b).Size == "Giant")
local x, y = tank(p, "Tiny"), tank(p, "Tiny")
w.clock += 5
local n = #w.sent
for _ = 1, 20 do
	w.ask(p, "Fuse", { b, x, y })
end
local answers = 0
for i = n + 1, #w.sent do
	if w.sent[i][1] == "Fused" then
		answers += 1
	end
end
ok("twenty at once: one", answers == 1 and count(p) == 1 and at(p, b).Size == "Huge", all(p))
x, y = tank(p, "Tiny"), tank(p, "Tiny")
Config.Fuse.AskGap = 0
w.clock += 5
n = #w.sent
for _ = 1, 20 do
	w.ask(p, "Fuse", { b, x, y })
end
answers = 0
for i = n + 1, #w.sent do
	if w.sent[i][1] == "Fused" then
		answers += 1
	end
end
ok("and with no wait between asks: one still", answers == 1 and count(p) == 1 and at(p, b).Size == "Colossal", all(p))
Config.Fuse.AskGap = 0.5

p = newcomer()
a, b, c = tank(p, "Normal"), tank(p, "Big"), tank(p, "Tiny")
w.clock += 5
w.ask(p, "Sell", "Tank", string.sub(c, 2))
refused("one sold just before", p, { a, b, c }, "Gone")
ok("  (it was sold)", count(p) == 2 and Tank.coinsOf(p) > 0)
c = tank(p, "Tiny")
ask(p, { a, b, c })
local coins = Tank.coinsOf(p)
w.clock += 5
w.ask(p, "Sell", "Tank", string.sub(a, 2))
ok(
	"one sold just after: not sold, not paid",
	w.last(p)[1] == "TankDenied" and Tank.coinsOf(p) == coins and count(p) == 1
)

p = newcomer()
a, b, c = tank(p, "Normal"), tank(p, "Big"), tank(p, "Tiny")
w.stand(p, p.Character:FindFirstChild("HumanoidRootPart").Position)
local function nearTank(of: any)
	local plot = w.space:FindFirstChild("ClaudeBlockout").Dock.Plots:FindFirstChild(of:GetAttribute("Plot"))
	w.stand(of, plot:FindFirstChild("Pad").Position)
end
nearTank(p)
w.clock += 5
w.ask(p, "Tank", "TakeOut", string.sub(c, 2))
w.stand(p, AT)
ok("(taken out into the hands)", #Ride.carried(p) == 1)
refused("one taken out just before", p, { a, b, c }, "Gone")
nearTank(p)
w.clock += 5
w.ask(p, "Tank", "Equip", string.sub(b, 2))
w.stand(p, AT)
refused("one equipped just before", p, { a, b, "H" .. Ride.carried(p)[1].Key }, "Equipped")
p = newcomer()
a, b = tank(p, "Normal"), tank(p, "Normal")
refused("another way to write one's name", p, { a, "T0" .. string.sub(a, 2), b }, "Gone")
do
	local before = all(p)
	local got, reason = Tank.fuse(p, { a, a, b })
	ok("the step itself refuses one fish twice", got == nil and reason == "Gone" and all(p) == before, reason)
end
p = newcomer()
a, b, c = hand(p, "Normal"), hand(p, "Big"), hand(p, "Tiny")
nearTank(p)
w.clock += 5
w.ask(p, "Tank", "PutIn", 1, KIND)
w.stand(p, AT)
refused("one put in the tank just before", p, { a, b, c }, "Gone")
d = "T" .. Tank.tankOf(p)[1].Key
ok(
	"its place in the hands moved: the keys still name the right ones",
	(ask(p, { d, b, c })) == "Fused" and at(p, b).Size == "Giant" and count(p) == 1,
	all(p)
)

print("Errors while telling")
p = newcomer()
a, b, c = hand(p, "Normal"), tank(p, "Big"), hand(p, "Tiny")
d = tank(p, "Tiny")
w.clock += 5
w.fail = true
pcall(w.ask, p, "Fuse", { a, b, c })
w.fail = false
ok(
	"the remote broke: fused whole all the same",
	count(p) == 2 and at(p, b).Size == "Giant" and at(p, d) ~= nil and #Ride.carried(p) == 0,
	all(p)
)
a, c = hand(p, "Tiny"), hand(p, "Tiny")
w.clock += 5
w.ask(p, "Hold", 2, KIND)
w.noModels = true
Config.Fuse.Earning = 1
Config.Aquarium.AutoEquip = 1
pcall(tank, p, "Tiny", "", OTHER)
Config.Aquarium.AutoEquip = 0
kind = ask(p, { a, b, c })
w.noModels = false
ok(
	"a model could not be built: fused whole, and answered",
	kind == "Fused" and at(p, b).Size == "Huge" and #Ride.carried(p) == 0,
	`{kind} {all(p)}`
)
ok("  and the held one, used up, is put away", Tank.heldOf(p) == nil)
Config.Fuse.Earning = 0

print("Leaving")
p = newcomer()
a, b, c = tank(p, "Normal"), tank(p, "Big"), hand(p, "Tiny")
w.leave(p)
kind = ask(p, { a, b, c })
ok("an ask from a player who has left does nothing", kind ~= "Fused")
p = newcomer()
a, b, c = tank(p, "Normal"), tank(p, "Big", "Gold"), hand(p, "Tiny")
ask(p, { a, b, c })
local dump = Tank.dump(p)
ok(
	"what is saved right after: one fish, grown",
	#dump.Fish == 1 and dump.Fish[1].Size == "Giant" and dump.Fish[1].Variant == "Gold" and #Ride.carried(p) == 0
)
a, c = tank(p, "Tiny"), tank(p, "Tiny")
local first = Tank.dump(p)
ok("(three saved before)", #first.Fish == 3)
ask(p, { a, b, c })
local second = Tank.dump(p)
ok(
	"the kept list is not a stale one",
	#second.Fish == 1 and second.Fish[1].Size == "Huge" and second.Fish ~= first.Fish
)
w.leave(p)
p = newcomer()
ok(
	"given back on the next visit",
	Tank.restore(p, dump)
		and count(p) == 1
		and Tank.tankOf(p)[1].Size == "Giant"
		and Tank.tankOf(p)[1].Variant == "Gold"
)

print("More players than tanks")
do
	newcomer()
	local crowd = {}
	repeat
		local q = newcomer(true)
		table.insert(crowd, q)
	until Tank.tankOf(q) == nil or #crowd > 6
	local q = crowd[#crowd]
	ok("one has no tank", Tank.tankOf(q) == nil)
	a, b, c = hand(q, "Normal"), hand(q, "Big"), hand(q, "Tiny")
	kind = ask(q, { a, b, c })
	ok("their hands can be fused all the same", kind == "Fused" and #Ride.carried(q) == 1 and at(q, b).Size == "Giant")
	a, c = hand(q, "Tiny"), hand(q, "Tiny")
	Config.Fuse.Price = 1
	refused("but with a price, they have no coins", q, { a, b, c }, "Coins")
	Config.Fuse.Price = 0
end

print("The Index")
p = newcomer()
a, b, c = hand(p, "Normal"), hand(p, "Big", "Silver"), hand(p, "Tiny")
Index.look(p)
ask(p, { a, b, c })
Index.look(p)
w.ask(p, "nothing")
local looks = nil
for i = #w.sent, 1, -1 do
	local row = w.sent[i]
	if row.Remote == "Index" and row.Player == p and row[1] == "State" then
		looks = row[2][KIND]
		break
	end
end
ok("the grown look is one more of its kind (three caught, four looks)", looks == 4, looks)

print("Three thousand at random: never a fish lost or doubled")
do
	local random = Random and Random.new(7) or nil
	math.randomseed(7)
	p = newcomer()
	local bad = 0
	local fused = 0
	local function roll(list: { any }): any
		return list[if random then random:NextInteger(1, #list) else math.random(1, #list)]
	end
	local keys = {}
	for _ = 1, 3000 do
		if count(p) >= 25 then
			p = newcomer() -- (full of those that can't be fused: the next player)
			table.clear(keys)
		end
		if math.random() < 0.6 then
			local size = roll({ "Tiny", "Tiny", "Normal", "Normal", "Big", "Giant", "Huge", "Colossal" })
			local colour = roll({ "", "", "Silver", "Gold", "Rainbow" })
			local id = roll({ KIND, KIND, KIND, KIND, OTHER })
			table.insert(keys, if math.random() < 0.5 then tank(p, size, colour, id) else hand(p, size, colour, id))
		end
		for i = #keys, 1, -1 do
			-- (some of the dead names stay in, for the asks that must be refused)
			if not at(p, keys[i]) and math.random() < 0.9 then
				table.remove(keys, i)
			end
		end
		if #keys >= 3 then
			local picks = { roll(keys), roll(keys), roll(keys) }
			local before = count(p)
			local list = {}
			for i, key in picks do
				local f = at(p, key)
				list[i] = if f then { Id = f.Id, Size = f.Size, Variant = f.Variant } else nil
			end
			local distinct = picks[1] ~= picks[2] and picks[2] ~= picks[3] and picks[1] ~= picks[3]
			local want = if distinct and list[1] and list[2] and list[3] then (Fuse.outcome(list)) else nil
			local said = ask(p, picks)
			if (said == "Fused") ~= (want ~= nil) then
				bad += 1
			elseif want then
				fused += 1
				local kept = at(p, picks[want.Keep])
				local good = kept
					and kept.Size == want.To
					and kept.Variant == list[want.Keep].Variant
					and at(p, picks[want.Used[1]]) == nil
					and at(p, picks[want.Used[2]]) == nil
					and count(p) == before - 2
				if not good then
					bad += 1
				end
			elseif count(p) ~= before then
				bad += 1
			end
		end
	end
	ok(`as the rules say every time ({fused} fused)`, bad == 0 and fused > 50, bad)
	for _, f in Ride.carried(p) do
		if type(f.Key) ~= "number" or not Config.FishById[f.Id] then
			bad += 1
		end
	end
	ok("and every fish left is whole", bad == 0)
end
ok("no thread failed on the way", #w.faults == 0, w.faults[1])

----------------------------------------------------------------------------------------------------------------------
-- What fusing does to the economy, in numbers, from Config's own sums
print("The economy (a Normal plain one earns 1; income and need of the one left against the three put in)")
do
	-- (a kind with a big need, so its whole-number rounding does not show)
	local big = nil
	for _, f in Config.Fish do
		if not big or Config.requiredOf(f, "Normal", "") > Config.requiredOf(big, "Normal", "") then
			big = f
		end
	end
	local unit = Config.incomeOf(big, "Normal", "")
	local need = Config.requiredOf(big, "Normal", "")
	local function earn(size: string, variant: string): number
		return Config.incomeOf(big, size, variant) / unit
	end
	local rows = {}
	local function row(size: string, colour: string, with: string)
		local to = Fuse.grown(size)
		local into, gets = earn(size, colour) + 2 * earn(with, ""), earn(to, colour)
		table.insert(rows, {
			name = `{if colour == "" then "plain" else colour} {size} + 2 plain {with} -> {to}`,
			into = into,
			gets = gets,
			change = gets / into - 1,
		})
		print(
			string.format(
				"  %-40s in %6.2f  out %6.2f  %+4.0f%%  best alone %+4.0f%%   Oxygen needed x%.2f -> x%.2f",
				rows[#rows].name,
				into,
				gets,
				(gets / into - 1) * 100,
				(gets / earn(size, colour) - 1) * 100,
				Config.requiredOf(big, size, colour) / need,
				Config.requiredOf(big, to, colour) / need
			)
		)
		return rows[#rows]
	end
	local worst = -math.huge
	for i = 1, #Config.SizeOrder - 1 do
		worst = math.max(worst, row(Config.SizeOrder[i], "", Config.SizeOrder[i]).change)
	end
	ok("three alike, plain: always earns less than the three did, all equipped", worst < 0)
	for _, size in { "Normal", "Giant", "Huge" } do
		for _, colour in { "", "Silver", "Gold", "Rainbow" } do
			row(size, colour, "Tiny")
		end
	end
	local all5 = earn("Colossal", "") / earn("Tiny", "")
	print(
		string.format(
			"  Tiny to Colossal: x%.2f income and need, 10 more Tinies with sizes mixed, 242 more with SameSize 1",
			all5
		)
	)
	print(
		string.format(
			"  Normal to Colossal: x%.2f, 8 more Tinies with sizes mixed, 80 more Normals with SameSize 1",
			earn("Colossal", "")
		)
	)
	ok(
		"the most one place in the tank can gain is bounded (x3.75 from a Tiny, x3 from a Normal)",
		math.abs(all5 - 3.75) < 0.01 and math.abs(earn("Colossal", "") - 3) < 0.01
	)
	local sell = Config.sellOf(big, "Colossal", "")
		/ (Config.sellOf(big, "Huge", "") + 2 * Config.sellOf(big, "Tiny", ""))
	print(string.format("  sold after: a Huge and two Tinies sell for 1, the Colossal for x%.2f", sell))
	ok("plain fish can't be fused and sold at a gain", sell < 1)
	local rainbow = Config.sellOf(big, "Colossal", "Rainbow")
		/ (Config.sellOf(big, "Huge", "Rainbow") + 2 * Config.sellOf(big, "Tiny", ""))
	print(string.format("  the same with a Rainbow Huge: x%.2f", rainbow))
	for _, colour in { "", "Silver", "Gold", "Rainbow" } do
		local into, gets = earn("Tiny", colour) + 10 * earn("Tiny", ""), earn("Colossal", colour)
		local chain = `the whole way, a {if colour == "" then "plain" else colour} Tiny and 10 plain Tinies`
		print(string.format("  %-50s in %6.2f  out %6.2f  %+4.0f%%", chain, into, gets, (gets / into - 1) * 100))
	end
end

done()
