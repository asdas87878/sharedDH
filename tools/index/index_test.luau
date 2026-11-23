-- The Index's rules, checked offline (NULLROOM task h2): Config.Index's sums and IndexService's found, claim-once,
-- land, claim-all, rate and no-trust rules, with stand-ins for the players, RideService and AquariumService.
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/index/index_test.luau /tmp/place.rbxl
local process = require("@lune/process")
local Harness = require("./harness")

local world = Harness.open(process.args[1] or "/tmp/place.rbxl")
local ok, done = Harness.tally()

----------------------------------------------------------------------------------------------------------------------
-- Stand-ins: a clock we move by hand, players, the remote, and the two services the Index reads and pays through

local clock = 100
world.globals.os = setmetatable({
	clock = function()
		return clock
	end,
}, { __index = os })

local function signal()
	local handlers = {}
	return {
		Connect = function(_self: any, handler: any)
			table.insert(handlers, handler)
		end,
		fire = function(...: any)
			for _, handler in handlers do
				handler(...)
			end
		end,
	}
end

local function newPlayer(name: string)
	local attributes = {}
	return {
		Name = name,
		SetAttribute = function(_self: any, key: string, value: any)
			attributes[key] = value
		end,
		GetAttribute = function(_self: any, key: string): any
			return attributes[key]
		end,
	}
end

local players = {}
world.services.Players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function()
		return players
	end,
}
local heartbeat = signal()
world.services.RunService = {
	Heartbeat = heartbeat,
	IsServer = function()
		return true
	end,
	IsStudio = function()
		return false
	end,
}

-- what the server sent, newest last: { player, name, ... }
local sent: { { any } } = {}
local remote = signal()
world.stubs["ReplicatedStorage.Shared.Net"] = {
	Index = {
		OnServerEvent = remote,
		FireClient = function(_self: any, player: any, ...: any)
			table.insert(sent, { player, ... })
		end,
	},
}
local function last(player: any, name: string): { any }?
	for i = #sent, 1, -1 do
		if sent[i][1] == player and sent[i][2] == name then
			return sent[i]
		end
	end
	return nil
end

local state: { [any]: string } = {}
local carried: { [any]: { any } } = {}
local trained: { [any]: number } = {}
local trainCalls = 0
world.stubs["ServerScriptService.Server.Services.RideService"] = {
	carried = function(player: any)
		return carried[player] or {}
	end,
	stateOf = function(player: any)
		return state[player]
	end,
	train = function(player: any, amount: number): boolean
		if state[player] ~= "Dock" or amount <= 0 then
			return false
		end
		trainCalls += 1
		trained[player] = (trained[player] or 0) + amount
		return true
	end,
}
local tanks: { [any]: { any } } = {}
local coins: { [any]: number } = {}
local giveCalls = 0
world.stubs["ServerScriptService.Server.Services.AquariumService"] = {
	tankOf = function(player: any)
		return tanks[player]
	end,
	give = function(player: any, amount: number)
		if tanks[player] then
			giveCalls += 1
			coins[player] = (coins[player] or 0) + amount
		end
	end,
}

local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
local Auras = world.require(world.find("ReplicatedStorage.Shared.Auras"))
local IndexService = world.require(world.find("ServerScriptService.Server.Services.IndexService"))

----------------------------------------------------------------------------------------------------------------------
print("Config: the roster and the rewards")

local lands = Config.indexLands()
ok("ten lands", lands == 10, lands)
local total, inSets = 0, 0
local shown = {}
for land = 1, lands do
	local kinds, set = Config.indexKinds(land), Config.indexSet(land)
	total += #kinds
	inSets += #set
	ok(
		`land {land} has kinds and a set no bigger`,
		#kinds > 0 and #set > 0 and #set <= #kinds,
		`{#kinds} kinds, {#set} in the set`
	)
	for _, fish in kinds do
		shown[fish.Id] = true
	end
end
ok("every kind of the Index sits in one land's list", total == Config.indexCount(), `{total} of {Config.indexCount()}`)
print(`    {#Config.Fish} kinds in the roster, {total} in the Index, {inSets} in the sets`)
local outside = {}
for _, fish in Config.Fish do
	if not Config.inIndexSet(fish) then
		table.insert(outside, `{fish.Id} ({fish.Tier}, land {fish.Home})`)
	end
end
print("    outside the sets: " .. table.concat(outside, ", "))
for _, fish in Config.Fish do
	if fish.Tier == "Secret" then
		ok(`the Secret {fish.Id} is outside its land's set`, not Config.inIndexSet(fish))
	end
end

-- the draft's own table (docs/design/progression.md, "The short of it", 1): each land's commonest fish needs
local DRAFT = { 82, 588, 4250, 35e3, 225e3, 1.7e6, 12e6, 89e6, 645e6, 4.65e9 }
local goals = {}
for land = 1, lands do
	local goal = Config.indexGoal(land)
	table.insert(goals, Config.shortNumber(goal))
	ok(
		`land {land}'s commonest need is the draft's ({DRAFT[land]})`,
		math.abs(goal - DRAFT[land]) <= DRAFT[land] * 0.03,
		goal
	)
end
print("    goals: " .. table.concat(goals, ", "))

local clown = Config.FishById.Clownfish
local o, c = Config.indexFirst(clown)
ok("a first Clownfish pays 100 Oxygen (the least) and $200 (100 s of $2)", o == 100 and c == 200, `{o}, {c}`)
local deep = Config.FishById.TheDevourer
if deep then
	local need = Config.requiredOf(deep, "Normal", "")
	local od, cd = Config.indexFirst(deep)
	ok(
		"a first Devourer pays a fifth of its need, whole",
		od == math.floor(need * 0.2 + 0.5) and od % 1 == 0 and cd % 1 == 0,
		`{od}, {cd}`
	)
end
local lo, lc = Config.indexLand(1)
ok(
	"the Shallows' set pays half its commonest need (41) and 600 s of its coins ($1,230)",
	lo == 41 and lc == 1230,
	`{lo}, {lc}`
)
ok("a kind has 24 looks", Config.indexLooks() == 24, Config.indexLooks())
ok("the aura switch is off", Config.Index.AuraMult == 0)

----------------------------------------------------------------------------------------------------------------------
print("IndexService: found")

local ann = newPlayer("Ann")
table.insert(players, ann)
IndexService.Start()
ok(
	"a player in the game at the start has an empty Index",
	ann:GetAttribute("IndexFound") == 0 and ann:GetAttribute("IndexClaims") == 0
)
state[ann] = "Riding"
tanks[ann] = {}
heartbeat.fire(1)
ok("nothing carried: nothing told", #sent == 0)

carried[ann] = { { Id = "Clownfish", Size = "Normal", Variant = "" } }
heartbeat.fire(0.1)
ok("a look comes only every Index.Watch seconds", ann:GetAttribute("IndexFound") == 0)
heartbeat.fire(0.2)
ok("a carried fish is found", ann:GetAttribute("IndexFound") == 1 and ann:GetAttribute("IndexClaims") == 1)
local told = last(ann, "State")
ok("and its client is told the whole Index", told ~= nil and told[3].Clownfish == 1 and next(told[4]) == nil)
local before = #sent
heartbeat.fire(1)
ok("the same fish again tells nothing", #sent == before)

carried[ann] = {
	{ Id = "Clownfish", Size = "Normal", Variant = "" },
	{ Id = "Clownfish", Size = "Big", Variant = "Gold" },
	{ Id = "NoSuchFish", Size = "Normal", Variant = "" },
}
heartbeat.fire(1)
ok(
	"another look of a kind counts as a look, not a kind",
	IndexService.foundOf(ann).Clownfish == 2 and ann:GetAttribute("IndexFound") == 1
)
ok("a fish that is no kind is not found", IndexService.foundOf(ann).NoSuchFish == nil)
for _, fish in Config.Fish do
	if fish.Reach < 0 then
		table.insert(carried[ann], { Id = fish.Id, Size = "Normal", Variant = "" })
		heartbeat.fire(1)
		ok(
			`{fish.Id}, kept out of the herd, is not in the Index and is not found`,
			not shown[fish.Id] and IndexService.foundOf(ann)[fish.Id] == nil
		)
	end
end
Config.Index.Secrets = 0
ok("with Index.Secrets off the Secrets are left out", Config.indexCount() == inSets, Config.indexCount())
Config.Index.Secrets = 1

----------------------------------------------------------------------------------------------------------------------
print("IndexService: claims")

local function ask(player: any, ...: any)
	clock += 1
	remote.fire(player, ...)
end

ask(ann, "Claim", "Clownfish")
ok("off the dock a claim is refused", last(ann, "Denied")[3] == "Dock" and trained[ann] == nil and coins[ann] == nil)
ok("and still waits", ann:GetAttribute("IndexClaims") == 1)

state[ann] = "Dock"
ask(ann, "Claim", "Clownfish")
local paid = last(ann, "Paid")
ok(
	"on the dock it pays 100 Oxygen and $200, once",
	paid and paid[3] == 100 and paid[4] == 200 and paid[5] == 1 and trained[ann] == 100 and coins[ann] == 200
)
ok("and nothing waits", ann:GetAttribute("IndexClaims") == 0 and last(ann, "State")[4].Clownfish == true)
ask(ann, "Claim", "Clownfish")
ok(
	"a second claim of it pays nothing",
	sent[#sent][2] == "Denied" and sent[#sent][3] == "Nothing" and trained[ann] == 100 and coins[ann] == 200
)
ask(ann, "ClaimAll")
ok("nor does claim all", sent[#sent][3] == "Nothing" and trained[ann] == 100 and coins[ann] == 200)

for _, bad in { "Pufferfish", "NoSuchFish", 5, true, {}, "" } do
	ask(ann, "Claim", bad)
end
ask(ann, "Claim")
ok("a kind not found, or no kind at all, pays nothing", trained[ann] == 100 and coins[ann] == 200)
for _, bad in { 1, 0, 11, 1.5, -1, 0 / 0, math.huge, "1", {} } do
	ask(ann, "ClaimLand", bad)
end
ok("a land not finished, or no land at all, pays nothing", trained[ann] == 100 and coins[ann] == 200)
for _, bad in { "Pay", "State", 7, {} } do
	ask(ann, bad, "Clownfish")
end
ok("an ask that is none of ours does nothing", trained[ann] == 100 and coins[ann] == 200)

-- two more kinds, asked for at the same moment: the second ask is dropped
tanks[ann] =
	{ { Id = "Pufferfish", Size = "Tiny", Variant = "" }, { Id = "YellowTang", Size = "Normal", Variant = "Silver" } }
heartbeat.fire(1)
ok("fish in the tank are found too", ann:GetAttribute("IndexFound") == 3 and ann:GetAttribute("IndexClaims") == 2)
clock += 1
local calls = trainCalls
remote.fire(ann, "Claim", "Pufferfish")
remote.fire(ann, "Claim", "YellowTang")
remote.fire(ann, "ClaimAll")
ok("asks at the same moment: only the first is heard", trainCalls == calls + 1 and ann:GetAttribute("IndexClaims") == 1)
clock += Config.Index.AskGap / 2
remote.fire(ann, "Claim", "YellowTang")
ok("and one sooner than Index.AskGap is dropped", trainCalls == calls + 1)
clock += Config.Index.AskGap
remote.fire(ann, "Claim", "YellowTang")
ok("one after it is heard", trainCalls == calls + 2 and ann:GetAttribute("IndexClaims") == 0)

----------------------------------------------------------------------------------------------------------------------
print("IndexService: a land's set, and claim all")

local set = Config.indexSet(1)
local list = {}
for i, fish in set do
	if i < #set then
		table.insert(list, { Id = fish.Id, Size = "Normal", Variant = "" })
	end
end
tanks[ann] = list
heartbeat.fire(1)
local trainedBefore, coinsBefore = trained[ann], coins[ann]
ask(ann, "ClaimLand", 1)
ok("a set one kind short pays nothing", sent[#sent][3] == "Nothing" and trained[ann] == trainedBefore)
table.insert(list, { Id = set[#set].Id, Size = "Normal", Variant = "" })
heartbeat.fire(1)
local waiting = ann:GetAttribute("IndexClaims")
ok("the whole set found: its reward waits with the new kinds'", waiting == #set - 3 + 1, waiting)
ask(ann, "ClaimLand", 1)
paid = last(ann, "Paid")
ok(
	"the Shallows' set pays 41 Oxygen and $1,230",
	paid[3] == 41 and paid[4] == 1230 and trained[ann] == trainedBefore + 41 and coins[ann] == coinsBefore + 1230
)
ask(ann, "ClaimLand", 1)
ok("and only once", sent[#sent][3] == "Nothing" and trained[ann] == trainedBefore + 41)

local owedOxygen, owedCoins, owedCount = 0, 0, 0
for _, fish in set do
	if not last(ann, "State")[4][fish.Id] then
		local fo, fc = Config.indexFirst(fish)
		owedOxygen += fo
		owedCoins += fc
		owedCount += 1
	end
end
trainedBefore, coinsBefore = trained[ann], coins[ann]
ask(ann, "ClaimAll")
paid = last(ann, "Paid")
ok(
	`claim all pays the {owedCount} kinds left, in one`,
	paid[3] == owedOxygen
		and paid[4] == owedCoins
		and paid[5] == owedCount
		and trained[ann] == trainedBefore + owedOxygen
		and coins[ann] == coinsBefore + owedCoins,
	`{paid[3]}, {paid[4]}, {paid[5]}`
)
ok("and nothing waits after it", ann:GetAttribute("IndexClaims") == 0)
ask(ann, "ClaimAll")
ok("claim all again pays nothing", sent[#sent][3] == "Nothing" and trained[ann] == trainedBefore + owedOxygen)
ok("every Oxygen paid was a whole number", trained[ann] % 1 == 0)

----------------------------------------------------------------------------------------------------------------------
print("IndexService: no tank, the aura switch, leaving")

local bob = newPlayer("Bob")
table.insert(players, bob)
world.services.Players.PlayerAdded.fire(bob)
state[bob] = "Dock"
carried[bob] = { { Id = "Clownfish", Size = "Normal", Variant = "" } }
heartbeat.fire(1)
ask(bob, "Claim", "Clownfish")
paid = last(bob, "Paid")
ok(
	"a player with no tank is paid the Oxygen and no coins",
	paid[3] == 100 and paid[4] == 0 and trained[bob] == 100 and coins[bob] == nil
)
ok(
	"one player's Index is not another's",
	ann:GetAttribute("IndexFound") == #set and bob:GetAttribute("IndexFound") == 1
)

carried[bob] = { { Id = "Pufferfish", Size = "Normal", Variant = "" } }
heartbeat.fire(1)
bob:SetAttribute("Aura", 2)
ask(bob, "Claim", "Pufferfish")
ok("an aura does not multiply the Index's Oxygen", trained[bob] == 200)
Config.Index.AuraMult = 1
carried[bob] = { { Id = "YellowTang", Size = "Normal", Variant = "" } }
heartbeat.fire(1)
ask(bob, "Claim", "YellowTang")
local mult = Auras.Tiers[2].Mult
ok(`with the switch on it does (x{mult})`, trained[bob] == 200 + 100 * mult, trained[bob])
Config.Index.AuraMult = 0

world.services.Players.PlayerRemoving.fire(bob)
carried[bob] = { { Id = "Stingray", Size = "Normal", Variant = "" } }
heartbeat.fire(1)
before = trained[bob]
ask(bob, "ClaimAll")
ok("a player who left is not looked at or paid", IndexService.foundOf(bob) == nil and trained[bob] == before)

if #world.warnings > 0 then
	print("warnings while loading:")
	for _, warning in world.warnings do
		print("  " .. warning)
	end
end
done()
