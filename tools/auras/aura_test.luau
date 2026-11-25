-- The auras, checked offline (NULLROOM task a1): the prices' ladder, the flame's numbers against the note's
-- (docs/design/auras.md), and AuraService's rules: the order, the price, the place, coins taken once, nothing trusted,
-- worn and saved, and what it does to the seahorse's Oxygen. Stand-ins for the players, RideService and the coins.
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/auras/aura_test.luau /tmp/place.rbxl
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Harness = require("../index/harness")

local world = Harness.open(process.args[1] or "/tmp/place.rbxl")
local ok, done = Harness.tally()

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

-- the stall's ring, in a stand-in workspace
local ring = { Position = roblox.Vector3.new(10, 5, 10) }
function ring.IsA(_self: any, class: string): boolean
	return class == "BasePart"
end
local function holder(children: { [string]: any }): any
	return {
		FindFirstChild = function(_self: any, name: string): any
			return children[name]
		end,
		IsA = function(_self: any, class: string): boolean
			return class == "Model"
		end,
	}
end
world.globals.workspace = holder({
	ClaudeBlockout = holder({ Dock = holder({ Stations = holder({ Auras = holder({ Ring = ring }) }) }) }),
})

local function newPlayer(name: string)
	local attributes = {}
	local root = { Position = roblox.Vector3.new(12, 8, 11) }
	function root.IsA(_self: any, class: string): boolean
		return class == "BasePart"
	end
	local humanoid = { Health = 100 }
	local player = {
		Name = name,
		Root = root,
		Humanoid = humanoid,
		Character = {
			FindFirstChild = function(_self: any, child: string): any
				return if child == "HumanoidRootPart" then root else nil
			end,
			FindFirstChildOfClass = function(_self: any, class: string): any
				return if class == "Humanoid" then humanoid else nil
			end,
		} :: any,
		SetAttribute = function(_self: any, key: string, value: any)
			attributes[key] = value
		end,
		GetAttribute = function(_self: any, key: string): any
			return attributes[key]
		end,
	}
	return player
end

local joined, left = signal(), signal()
local players = {}
world.services.Players = {
	PlayerAdded = joined,
	PlayerRemoving = left,
	GetPlayers = function()
		return players
	end,
}
local sent: { { any } } = {}
local remote = signal()
world.stubs["ReplicatedStorage.Shared.Net"] = {
	Action = { OnServerEvent = remote },
	Ride = {
		FireClient = function(_self: any, player: any, ...: any)
			table.insert(sent, { player, ... })
		end,
	},
}
local state: { [any]: string } = {}
world.stubs["ServerScriptService.Server.Services.RideService"] = {
	stateOf = function(player: any): string
		return state[player] or "Dock"
	end,
}
local coins: { [any]: number } = {}
local spends = 0
world.stubs["ServerScriptService.Server.Services.AquariumService"] = {
	spend = function(player: any, amount: number): boolean
		spends += 1
		if not coins[player] or amount ~= amount or amount < 0 or coins[player] < amount then
			return false
		end
		coins[player] -= amount
		return true
	end,
}

local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
local Auras = world.require(world.find("ReplicatedStorage.Shared.Auras"))
local Flame = world.require(world.find("ReplicatedStorage.Shared.AuraFlame"))
local AuraService = world.require(world.find("ServerScriptService.Server.Services.AuraService"))
local prices: { number } = Config.Aura.Prices

print("The prices")
ok("twelve auras, twelve prices", #Auras.Tiers == 12 and #prices == 12, #prices)
ok("the first is 100 (the user's)", prices[1] == 100, prices[1])
local least, most = math.huge, 0
for i = 2, #prices do
	least = math.min(least, prices[i] / prices[i - 1])
	most = math.max(most, prices[i] / prices[i - 1])
end
ok("a smooth ladder: every step x18 to x21", least >= 18 and most <= 21, `{least} to {most}`)
local under, whole = true, true
for i, p in prices do
	under = under and (i == 1 or p < Config.Train.Levels[i].Price)
	whole = whole and p % 1 == 0
end
ok("every aura costs less than the seahorse level of its number", under)
ok("whole coins", whole)
local falls, last = 0, 1
for i = 4, 12 do
	local share = prices[i] / Config.Train.Levels[i].Price
	if i > 4 and share > last * 1.1 then
		falls += 1
	end
	last = share
end
ok("from tier 4 its share of the seahorse's price never jumps up", falls == 0)
local climbing = true
for i = 2, 12 do
	climbing = climbing and Auras.Tiers[i].Mult > Auras.Tiers[i - 1].Mult
end
ok("every aura multiplies by more than the one before", climbing)

print("The flame (draft 4's numbers)")
local BEAMS = { 10, 10, 18, 23, 23, 25, 25, 25, 25, 25, 32, 42 }
local ALIVE = { 0, 5, 5, 5, 5, 6, 16, 19, 33, 38, 40, 43 }
for tier = 1, 12 do
	local spec = Flame.spec(tier)
	local beams, alive = Flame.beams(spec), Flame.alive(spec)
	ok(
		`tier {tier}: {beams} Beams, {math.floor(alive + 0.5)} particles`,
		beams == BEAMS[tier] and math.abs(alive - ALIVE[tier]) < 1,
		`{BEAMS[tier]}, {ALIVE[tier]}`
	)
end
local one, twelve = Flame.spec(1), Flame.spec(12)
ok(
	"tier 1: one layer, 7.45 tall, 6.6 wide, no extras",
	#one.Layers == 1 and one.Layers[1].Height == 7.45 and one.Layers[1].Width == 6.6 and #one.Extras == 0
)
ok(
	"tier 12: back to front Crown, Flame, Inner, Streaks, Core",
	twelve.Layers[1].Name == "Crown" and twelve.Layers[2].Name == "Flame" and twelve.Layers[5].Name == "Core"
)
ok("tier 12 is 1.24 the size", math.abs(twelve.Scale - 1.24) < 1e-9)
ok(
	"a pulse every 1.7 s at tier 5, 1.25 at 12",
	math.abs(Flame.spec(5).Pulse.Every - 1.7) < 1e-9 and math.abs(twelve.Pulse.Every - 1.25) < 1e-9
)
local low, odd = math.huge, 0
for tier = 1, 12 do
	local spec = Flame.spec(tier)
	for _, e in spec.Extras do
		low = math.min(low, e.At - e.Height / 2)
	end
	for _, l in spec.Layers do
		for step = 0, 200 do
			local t = step * 0.037
			for _, on in { -1, 0, 0.05, 0.14, 0.5, 2 } do
				local m = Flame.moment(spec, t, on, on)
				local a, b = Flame.strength(spec, l, m, t)
				local h = Flame.height(l, m, 1, t)
				if a < 0 or a > 1 or b < 0 or b > 1 or h < 0 or h ~= h or h > 25 then
					odd += 1
				end
			end
			for i = 1, #l.Tips do
				local from, to, w = Flame.tongue(l, i, l.Width, l.Height, t)
				if to.Y <= from.Y or w <= 0 then
					odd += 1
				end
			end
		end
		for q = 0, 70 do
			local f = Flame.fade(l, q / 100, spec.Scale)
			if f < 0 or f > 1 then
				odd += 1
			end
		end
		if Flame.fade(l, 0, spec.Scale) ~= 0 or Flame.fade(l, 0.7, spec.Scale) > 1e-9 then
			odd += 1
		end
	end
	local waves = 0
	for step = 0, 400 do
		local any = false
		for i = 1, 2 do
			local foot, middle, top = Flame.waveAt(spec, i, step * 0.01)
			if foot then
				any = true
				if foot < 0 or top > 1 or Flame.waveFade(spec, spec.Layers[1], middle, (foot + top) / 2) > 1 then
					odd += 1
				end
			end
		end
		waves += if any then 1 else 0
	end
	if (tier >= 6) ~= (waves > 300) then
		odd += 1
	end
end
ok("no particle is let out under the knee (2.3 studs)", low >= 2.3, low)
ok(
	"every moment of every tier: strengths 0 to 1, heights and tongues upright, waves in sight from tier 6",
	odd == 0,
	odd
)
local h, w = Flame.burstAt(0.14)
ok(
	"the burst's top: 1.42 tall, 1.5 wide; over after 0.84 s",
	math.abs(h - 1.42) < 1e-9 and math.abs(w - 1.5) < 1e-9 and Flame.burstAt(0.85) == 1
)
ok("the flare's top is at 0.08 s, over by 0.6", Flame.flareAt(0.08) == 1 and Flame.flareAt(0.6) == 0)
ok(
	"flares: a landing from 7, a hop from 8, a boost and the faster ride from 9, the burst from 10",
	not Flame.spec(6).FlareLand
		and Flame.spec(7).FlareLand
		and not Flame.spec(7).FlareHop
		and Flame.spec(8).FlareHop
		and not Flame.spec(8).FlareBoost
		and Flame.spec(9).FlareBoost
		and Flame.spec(9).RideFast == 1.4
		and Flame.spec(8).RideFast == 1
		and not Flame.spec(9).Burst
		and Flame.spec(10).Burst
)

print("Buying (AuraService)")
AuraService.Init()
local ann = newPlayer("Ann")
table.insert(players, ann)
coins[ann] = 0
AuraService.Start()
local function press(player: any, ...: any): (string?, any)
	local before = #sent
	remote.fire(player, "AuraBuy", ...)
	if #sent == before then
		return nil, nil
	end
	local s = sent[#sent]
	assert(s[1] == player and #sent == before + 1, "one answer, to the one who asked")
	return s[2], s[3]
end
local function wears(player: any): (any, any)
	return AuraService.tierOf(player), player:GetAttribute("Aura")
end
local function is(player: any, tier: number): boolean
	local a, b = wears(player)
	return a == tier and b == tier
end
ok("joins with none", is(ann, 0) and AuraService.multOf(ann) == 1)
local kind, why = press(ann, 1)
ok("no coins: refused, Coins", kind == "AuraDenied" and why == "Coins" and is(ann, 0))
coins[ann] = 99
kind, why = press(ann, 1)
ok("99 of 100: refused, nothing taken", why == "Coins" and coins[ann] == 99 and is(ann, 0))
coins[ann] = 1e16
kind, why = press(ann, 2)
ok("the second before the first: refused, Order, nothing taken", why == "Order" and coins[ann] == 1e16 and is(ann, 0))
kind, why = press(ann, 12)
ok("the twelfth: refused, Order", why == "Order" and is(ann, 0))
local quiet = true
spends = 0
for _, odd_ in { 0, -1, 13, 1.5, 0 / 0, math.huge, -math.huge, "1", true, {}, 1e300 } :: { any } do
	if press(ann, odd_) ~= nil then
		quiet = false
	end
end
if press(ann) ~= nil or press(ann, nil, 1) ~= nil then
	quiet = false
end
ok(
	"junk from the client (wrong types, NaN, endless, none, half, below and past): dropped, no coins asked",
	quiet and spends == 0 and is(ann, 0)
)
coins[ann] = 1e6
kind, why = press(ann, 1, 1, "free", 0)
ok(
	"the first: bought, its 100 taken once, worn, the extra arguments ignored",
	kind == "AuraBought" and why == 1 and coins[ann] == 1e6 - 100 and is(ann, 1)
)
ok("it multiplies the seahorse by 1.5", AuraService.multOf(ann) == 1.5)
kind = press(ann, 1)
ok("pressed again (a late second click): quiet, no coins taken", kind == nil and coins[ann] == 1e6 - 100)
kind, why = press(ann, 2)
ok("the next within half a second: refused, Busy", why == "Busy" and is(ann, 1))
clock += 0.6
ring.Position = roblox.Vector3.new(500, 5, 10)
kind, why = press(ann, 2)
ok("far from the stall: refused, Dock", why == "Dock" and is(ann, 1))
ring.Position = roblox.Vector3.new(12 + 29, 400, 11)
kind = press(ann, 2)
ok("29 studs off, flat: bought", kind == "AuraBought" and is(ann, 2) and coins[ann] == 1e6 - 100 - 2000)
ring.Position = roblox.Vector3.new(10, 5, 10)
clock += 1
local spot = ann.Character
for _, where in { "Free", "Riding", "Jumping", "Drowning", "Carried" } do
	state[ann] = where
	kind, why = press(ann, 3)
	ok(`while {where}: refused, Dock`, why == "Dock" and is(ann, 2))
end
state[ann] = "Dock"
ann.Humanoid.Health = 0
kind, why = press(ann, 3)
ok("dead: refused", why == "Dock" and is(ann, 2))
ann.Humanoid.Health = 100
ann.Character = nil
kind, why = press(ann, 3)
ok("no character: refused", why == "Dock" and is(ann, 2))
ann.Character = spot
ann:SetAttribute("Aura", 11)
ok(
	"the attribute is only shown: the server's own tier counts",
	AuraService.multOf(ann) == 2 and AuraService.tierOf(ann) == 2
)
kind, why = press(ann, 12)
ok("and buying goes by it too", why == "Order")
Config.Aura.On = 0
kind, why = press(ann, 3)
ok("Aura.On 0: refused, Off", why == "Off")
Config.Aura.On = 1
local paid = 2100
coins[ann] = 3e16
for tier = 3, 12 do
	clock += 1
	local had = coins[ann]
	kind, why = press(ann, tier)
	paid += prices[tier]
	if kind ~= "AuraBought" or not is(ann, tier) or had - coins[ann] ~= prices[tier] then
		ok(`tier {tier} bought for its price`, false, `{kind} {why}`)
	end
end
ok("all twelve in order, each for its own price", is(ann, 12) and AuraService.multOf(ann) == 12)
clock += 1
kind = press(ann, 13)
ok("nothing after the twelfth", kind == nil and is(ann, 12))
local bob = newPlayer("Bob")
kind = press(bob, 1)
ok("a player it doesn't have: dropped", kind == nil and bob:GetAttribute("Aura") == nil)
joined.fire(bob)
ok("another player has their own", is(bob, 0) and is(ann, 12))
remote.fire(bob, "SubBuy", 1)
remote.fire(bob, 5, 1)
ok("other actions are not its own", is(bob, 0))

print("Saving (tierOf, setTier)")
ok("given back, worn, no coins taken", AuraService.setTier(bob, 7) and is(bob, 7) and AuraService.multOf(bob) == 5)
ok("clamped and whole", AuraService.setTier(bob, 99.9) and is(bob, 12) and AuraService.setTier(bob, -3) and is(bob, 0))
ok(
	"a number that is none, or not a number: refused",
	not AuraService.setTier(bob, 0 / 0) and not AuraService.setTier(bob, "3" :: any) and is(bob, 0)
)
left.fire(ann)
ok(
	"gone: nothing kept, nothing given back",
	AuraService.tierOf(ann) == nil and AuraService.multOf(ann) == 1 and not AuraService.setTier(ann, 3)
)

print("The seahorse")
for _, level in { 1, 6, 12 } do
	local base = Config.Train.Levels[level].Oxygen
	for tier = 1, 12 do
		local gain = math.floor(base * Auras.Tiers[tier].Mult + 0.5)
		if gain <= base or gain % 1 ~= 0 then
			ok(`level {level} with aura {tier} gives more, whole`, false, gain)
		end
	end
end
local train: string = world.find("ServerScriptService.Server.Services.TrainService").Source
ok(
	"TrainService.gain multiplies by the server's own aura",
	string.find(train, "levelRow%(level%).Oxygen else t%.Rate%)%s*%*%s*AuraService%.multOf%(player%)") ~= nil
)
local shop: string = world.find("StarterPlayer.StarterPlayerScripts.Client.UI.AuraShop").Source
ok(
	"no bubbles are left in the aura cards",
	string.find(shop, "Kit.bubble", 1, true) == nil and string.find(shop, 'Shop.icon(well, "Bubble"', 1, true) == nil
)

done()
