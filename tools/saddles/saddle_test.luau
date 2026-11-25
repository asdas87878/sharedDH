-- The saddles in the game, checked offline (NULLROOM task s2): the data (a fit and a joint for every kind), the server's
-- rules (IndexService: given once with the land's claim, lands claimed before, what may be worn, leaving and a kept Book),
-- and SaddleController with stand-in fish (where it sits, when it is made, shown and taken off, the parts kept).
-- What each saddle looks like on each fish is tools/saddles/saddle_parity.luau's.
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/saddles/saddle_test.luau /tmp/place.rbxl
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Gui = require("../index/gui")
local Harness = require("../index/harness")

local CFrame, Vector3 = (roblox :: any).CFrame, (roblox :: any).Vector3
local place = process.args[1] or "/tmp/place.rbxl"
local ok, done = Harness.tally()

----------------------------------------------------------------------------------------------------------------------
print("the data")

local world = Harness.open(place)
local gui = Gui.install(world)
local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
local Creatures = world.require(world.find("ReplicatedStorage.Shared.Creatures"))
local Saddles = world.require(world.find("ReplicatedStorage.Shared.Saddles"))
local Data = world.require(world.find("ReplicatedStorage.Shared.Saddles.Fits"))
local Designs = world.require(world.find("ReplicatedStorage.Shared.Saddles.Designs"))

local SIZES = { "Tiny", "Normal", "Big", "Giant", "Huge", "Colossal" }
local lands = Config.indexLands()
-- (Hugo's picks, 2026-11-25)
local PICKS = { "1A", "2B", "3B", "4B", "5A", "6B", "7B", "8B", "9B", "10B" }
local FIRST = PICKS[1]
ok("the ten are Hugo's picks", table.concat(Config.Saddles.Land, " ") == table.concat(PICKS, " "))
ok("a design for each of the ten lands", #Config.Saddles.Land == lands and lands == 10)
for land, key in Config.Saddles.Land do
	local design = Saddles.design(key)
	ok(`land {land} gives {key}, its own`, design ~= nil and design.Land == land, design and design.Land)
end
ok("a key that is no design gives none", Saddles.design("11A") == nil and Saddles.design("") == nil)
Config.Saddles.On = 0
ok("switched off, no land gives one", Saddles.ofLand(1) == nil and Saddles.nameOf(1) == "")
Config.Saddles.On = 1
ok("switched on, it has a name", Saddles.nameOf(1) == "Scallop Saddle", Saddles.nameOf(1))

local kinds, none, badJoint, most, least, far = 0, {}, {}, 0, math.huge, 0
for _, fish in Config.Fish do
	local rig = Creatures.get(fish.Id)
	if not Saddles.fit(fish.Id, "Normal") then
		table.insert(none, fish.Id)
		continue
	end
	kinds += 1
	for _, size in SIZES do
		local fit = Saddles.fit(fish.Id, size)
		local found = false
		for _, row in if rig then rig.Parts else {} do
			found = found or (fit ~= nil and row[1] == fit.Joint)
		end
		if not found then
			table.insert(badJoint, fish.Id .. " " .. size)
		end
		for _, key in Config.Saddles.Land do
			local list = Saddles.build(fish.Id, size, key)
			most, least = math.max(most, #list), math.min(least, #list)
			for _, part in list do
				far = math.max(far, part.At.Position.Magnitude)
			end
		end
	end
end
print(`        {kinds} kinds with a fit; {#none} without: {table.concat(none, ", ")}`)
print(
	`        {least} to {most} parts a saddle; the furthest part is {string.format("%.1f", far)} studs from the back point`
)
ok(
	"every kind of the Index has a fit",
	(function(): boolean
		for _, fish in Config.Fish do
			if Config.inIndex(fish) and not Saddles.fit(fish.Id, "Normal") then
				return false
			end
		end
		return true
	end)()
)
ok("83 kinds, six sizes each", kinds == 83, kinds)
ok("every fit's joint is one of its creature's parts", #badJoint == 0, table.concat(badJoint, ", "))
ok("no saddle is bigger than a dozen studs from its seat", far < 12, far)
ok("a list is made once and kept", Saddles.build("Clownfish", "Big", FIRST) == Saddles.build("Clownfish", "Big", FIRST))
ok("a kind with no fit has none", Saddles.build("NoSuchFish", "Big", "1B") == nil)
local strays = {}
for kind, text in Data.Adjust do
	for row in string.gmatch(text, "[^;]+") do
		local size, key = string.match(row, "^(%a+) (%w+) %a+=[%d%.]+")
		if not Data.Fits[kind] or not table.find(SIZES, size or "") or not Designs[key or ""] then
			table.insert(strays, kind .. " " .. row)
		end
	end
end
ok("every change is for a kind, a size and a design there are", #strays == 0, strays[1])

----------------------------------------------------------------------------------------------------------------------
print("the server: given once, worn only if theirs")

local clock = 100
world.globals.os = setmetatable({
	clock = function()
		return clock
	end,
}, { __index = os })
local sent: { { any } } = {}
world.stubs["ReplicatedStorage.Shared.Net"] = {
	Index = {
		OnServerEvent = Gui.signal(),
		FireClient = function(_self: any, player: any, ...: any)
			table.insert(sent, { player, ... })
		end,
	},
}
local oxygen, coins, state = 0, 0, "Dock"
local carried: { any } = {}
world.stubs["ServerScriptService.Server.Services.RideService"] = {
	carried = function()
		return carried
	end,
	stateOf = function()
		return state
	end,
	train = function(_player: any, amount: number): boolean
		oxygen += amount
		return true
	end,
}
world.stubs["ServerScriptService.Server.Services.AquariumService"] = {
	tankOf = function()
		return {}
	end,
	give = function(_player: any, amount: number)
		coins += amount
	end,
}
local Index = world.require(world.find("ServerScriptService.Server.Services.IndexService"))
local player = gui.player
local function ask(what: string, arg: any?)
	clock += 1
	Index.ask(player, what, arg)
end
local function last(name: string): { any }?
	for i = #sent, 1, -1 do
		if sent[i][2] == name then
			return sent[i]
		end
	end
	return nil
end
local function worn(): any
	return player:GetAttribute("Saddle")
end
local function catchLand(land: number, all: boolean)
	for i, fish in Config.indexSet(land) do
		if all or i > 1 then
			table.insert(carried, { Id = fish.Id, Size = "Normal", Variant = "" })
		end
	end
	Index.look(player)
end

Index.join(player)
ok("a new player wears none", worn() == 0)
ask("Saddle", 1)
ok("and can't wear a land's they have not finished", worn() == 0 and (last("Denied") :: any)[3] == "Saddle")
catchLand(1, false)
ask("Saddle", 1)
ok("nor one fish short", worn() == 0)
catchLand(1, true)
ask("Saddle", 1)
ok("nor the whole set caught but not claimed", worn() == 0)
state = "Free"
ask("ClaimLand", 1)
ask("Saddle", 1)
ok("a claim off the dock is refused, and gives none", worn() == 0 and oxygen == 0)
state = "Dock"
ask("ClaimLand", 1)
local o1, c1 = Config.indexLand(1)
local paid = last("Paid") :: any
ok("the claim pays the land's Oxygen and coins as before", oxygen == o1 and coins == c1, `{oxygen} {coins}`)
ok("and says whose saddle came", paid[5] == 1 and #paid[6] == 1 and paid[6][1] == 1)
ok("it is not put on by itself", worn() == 0)
ask("Saddle", 1)
ok("it can be worn now", worn() == 1)
local before = #sent
ask("ClaimLand", 1)
ok(
	"a second claim pays nothing and gives nothing",
	oxygen == o1 and coins == c1 and sent[#sent][2] == "Denied" and #sent == before + 1
)
catchLand(2, true)
oxygen, coins = 0, 0
ask("ClaimAll")
paid = last("Paid") :: any
ok("claim all gives the other finished land's, and only that", #paid[6] == 1 and paid[6][1] == 2)
ok("the one worn stays on", worn() == 1)
ask("Saddle", 2)
ok("another one takes its place: one is worn", worn() == 2)
for _, bad in { 3, 11, -1, 1.5, 0 / 0, math.huge, "1", true, {} } do
	ask("Saddle", bad)
end
ask("Saddle")
ok("nothing else in the ask changes it", worn() == 2)
Index.ask(player, "Saddle", 1)
ok("an ask too soon after the last is dropped", worn() == 2)
state = "Riding"
ask("Saddle", 1)
ok("it can be changed on a dive too", worn() == 1)
state = "Dock"
Config.Saddles.On = 0
ask("Saddle", 2)
ok("switched off, nothing is put on", worn() == 1)
Config.Saddles.On = 1
local was = Config.Saddles.Land[1]
Config.Saddles.Land[1] = ""
ask("Saddle", 2)
ask("Saddle", 1)
ok("a land whose entry is empty gives none to wear", worn() == 2)
Config.Saddles.Land[1] = "1B"
ask("Saddle", 1)
ok("another design in a land's entry is worn by the same owners", worn() == 1)
Config.Saddles.Land[1] = was
ask("Saddle", 0)
ok("0 takes it off", worn() == 0)
ask("Saddle", 2)

print("leaving, coming back, and a kept Book")
local kept = Index.dump(player)
Index.leave(player)
Index.join(player)
table.clear(carried)
ok("before restore, coming back starts empty", worn() == 0)
ask("Saddle", 2)
ok("and owns no saddle", worn() == 0)
Index.restore(player, kept)
ok("a kept Book brings the saddles and the worn one back", worn() == 2)
oxygen, coins = 0, 0
ask("ClaimLand", 2)
ok("and nothing can be claimed twice", oxygen == 0 and coins == 0)
ask("ClaimAll")
ok("nor any kind", oxygen == 0 and coins == 0, oxygen)
Index.leave(player)
Index.join(player)
local legacy = {
	Lands = { ["1"] = true, ["99"] = true },
	Kinds = { RetiredFish = true, Clownfish = true },
	Looks = { Clownfish = { "Normal|" }, RetiredFish = { "FormerSize|" } },
}
ok("a pre-saddle profile restores", Index.restore(player, legacy))
ok("an old profile starts with nothing worn", worn() == 0)
Index.restore(player, { Saddle = 2 })
ok("a worn saddle that is not owned comes off", worn() == 0)
local book = Index.dump(player) :: any
ok(
	"retired fish, looks and claimed lands survive a round trip",
	book.Lands["1"]
		and book.Lands["99"]
		and book.Kinds.RetiredFish
		and book.Looks.RetiredFish[1] == "FormerSize|"
		and #book.Looks.Clownfish == 1
)
ok("an unknown fish gives no active count", Index.foundOf(player).RetiredFish == nil)
ask("Saddle", 1)
ok("a land claimed before saddles came has its saddle", worn() == 1)
Index.restore(player, "nonsense" :: any)
ok("a Book that is no table changes nothing", worn() == 1)
local dumped = Index.dump(player) :: any
ok("the worn land is in the Book", dumped.Saddle == 1)
Index.leave(player)
ok("someone who left has no Book", Index.dump(player) == nil)

----------------------------------------------------------------------------------------------------------------------
print("on the fish")

local space = gui.workspace
gui.camera.CFrame = CFrame.new(0, 0, 0)
local tags: { [string]: any } = {}
local function tag(name: string): any
	tags[name] = tags[name] or { Added = Gui.signal(), Removed = Gui.signal() }
	return tags[name]
end
world.services.CollectionService = {
	GetInstanceAddedSignal = function(_self: any, name: string)
		return tag(name).Added
	end,
	GetInstanceRemovedSignal = function(_self: any, name: string)
		return tag(name).Removed
	end,
	GetTagged = function()
		return {}
	end,
}
local other = gui.make("Player")
other.Name = "Other"
world.services.Players.GetPlayers = function()
	return { player, other }
end
local ids = { [7] = player, [8] = other }
rawget(player, "_own").UserId = 7
rawget(other, "_own").UserId = 8
world.services.Players.GetPlayerByUserId = function(_self: any, id: number)
	return ids[id]
end
local beat = world.services.RunService.Heartbeat
local Controller = world.require(world.find("StarterPlayer.StarterPlayerScripts.Client.Controllers.SaddleController"))
Controller.Start()
local folder = space:FindFirstChild("Saddles")
ok("its folder is in the workspace", folder ~= nil)
local function frame(dt: number?)
	beat:Fire(dt or 1 / 60)
end

-- A fish as FishModel builds one: the Root, each part on its hinge, the saddle's attachment; at a size
math.randomseed(5)
local function jitter(): number
	return math.random() * 2 - 1
end
local function fishOf(kind: string, size: string, where: any): any
	local rig, entry = Creatures.get(kind), Config.FishById[kind]
	local k = entry.Size.Z / rig.Size[3] * Config.sizeScale(size, entry)
	local model = gui.make("Model")
	model.Name = kind
	local root = gui.make("Part", model)
	root.Name = "Root"
	root.CFrame = where
	model.PrimaryPart = root
	rawget(model, "_own").GetPivot = function()
		return root.CFrame
	end
	local parts = {}
	for _, row in rig.Parts do
		local part = gui.make("MeshPart", model)
		part.Name = row[1]
		part.LocalTransparencyModifier, part.Transparency = 0, 0
		local pivot = where * CFrame.new(Vector3.new(row[3], row[4], row[5]) * k)
		part.CFrame = pivot * CFrame.new(jitter(), jitter(), jitter())
		local parent = if row[2] == "" then root else parts[row[2]]
		local motor = gui.make("Motor6D", parent)
		motor.Name = "Rig_" .. row[1]
		motor.Part0, motor.Part1 = parent, part
		motor.C0 = parent.CFrame:Inverse() * pivot
		motor.C1 = part.CFrame:Inverse() * pivot
		parts[row[1]] = part
	end
	local seat = gui.make("Attachment", root)
	seat.Name = "Saddle"
	rawget(seat, "_own").WorldPosition = (where * CFrame.new(
		Vector3.new(rig.Seat[1], rig.Seat[2], rig.Seat[3]) * k + Vector3.new(0, 1.4, 0)
	)).Position
	model:SetAttribute("Rig", kind)
	model:SetAttribute("FishType", kind)
	model:SetAttribute("SizeTier", size)
	model:SetAttribute("Rider", 0)
	model:SetAttribute("Reserved", 0)
	return model, where * CFrame.new(Vector3.new(rig.Seat[1], rig.Seat[2], rig.Seat[3]) * k), parts
end
local wild = space:FindFirstChild("Fish") or gui.make("Folder", space)
wild.Name = "Fish"
local function spawnWild(kind: string, size: string, where: any): any
	local model, back, parts = fishOf(kind, size, where)
	model.Parent = wild
	tag("Fish").Added:Fire(model)
	return model, back, parts
end
local function gone(model: any)
	model.Parent = nil
	model.AncestryChanged:Fire()
end
local function count(): number
	return #folder:GetChildren()
end
local function settle()
	for _ = 1, 12 do
		frame()
	end
end
-- How far the parts stand from where they should be, with the fish at rest
local function off(back: any, kind: string, size: string, key: string): number
	local list = Saddles.build(kind, size, key)
	local out = 0
	local here = folder:GetChildren()
	if #here ~= #list then
		return math.huge
	end
	for i, part in here do
		local want = back * list[i].At
		local weld = part:FindFirstChildOfClass("Weld")
		local at = weld.Part0.CFrame * weld.C0
		out = math.max(out, (at.Position - want.Position).Magnitude, (at.LookVector - want.LookVector).Magnitude)
	end
	return out
end

local at = CFrame.new(20, -30, 10) * CFrame.Angles(0.3, 1.1, -0.2)
player:SetAttribute("Saddle", 1)
other:SetAttribute("Saddle", 0)
local clown, back, clownParts = spawnWild("Clownfish", "Big", at)
frame(0.3)
ok("a free fish has none", Controller.on(clown) == nil and count() == 0)
clown:SetAttribute("Reserved", 7)
frame()
local key, made, of, see = Controller.on(clown)
ok("promised to us, it is begun, hidden", key == FIRST and see == 1 and made > 0)
ok(`never more than {Config.Saddles.PartsAFrame} parts a frame`, made <= Config.Saddles.PartsAFrame, made)
settle()
key, made, of, see = Controller.on(clown)
ok("it is whole before we land, and still hidden", made == of and see == 1 and count() == of, `{made} of {of}`)
local hidden = true
for _, part in folder:GetChildren() do
	hidden = hidden and part.LocalTransparencyModifier == 1
end
ok("every part of it", hidden)
ok(
	"each part stands where the fit says, on the back",
	off(back, "Clownfish", "Big", FIRST) < 1e-3,
	off(back, "Clownfish", "Big", FIRST)
)
local safe = true
for _, part in folder:GetChildren() do
	safe = safe
		and part.Massless
		and not (part.CanCollide or part.CanTouch or part.CanQuery or part.CastShadow or part.Anchored)
end
ok("no weight, no touch, no hits, no shadow", safe)
ok(
	"nothing is put into the fish itself",
	clown:FindFirstChild("Saddle", true):IsA("Attachment")
		and #clown:GetChildren() == 1 + #Creatures.get("Clownfish").Parts
)

local character = gui.make("Model")
rawget(player, "_own").Character = character
local body = gui.make("Part", character)
body.Name = "HumanoidRootPart"
body.Position = clown.PrimaryPart:FindFirstChild("Saddle").WorldPosition + Vector3.new(0, 1, 0)
frame()
ok("shown as we come within reach of the seat", select(4, Controller.on(clown)) == 0)
body.Position += Vector3.new(0, 40, 0)
clown:SetAttribute("Rider", 7)
clown:SetAttribute("Reserved", 0)
frame()
ok("and once we ride it", select(4, Controller.on(clown)) == 0)
clownParts.S1.LocalTransparencyModifier = 0.6
frame()
ok("a faded fish fades its saddle", math.abs(select(4, Controller.on(clown)) - 0.6) < 1e-6)
clownParts.S1.LocalTransparencyModifier = 0
clownParts.S1.Transparency = 1
frame()
ok("a hidden one hides it", select(4, Controller.on(clown)) == 1)
clownParts.S1.Transparency = 0
frame()
ok("and back", select(4, Controller.on(clown)) == 0)
clown:SetAttribute("Failing", true)
clown:SetAttribute("Angry", true)
frame(0.3)
ok("it stays on through angry mode and a fail", Controller.on(clown) == FIRST)

player:SetAttribute("Saddle", 2)
settle()
ok(
	"changed while riding: the new one is on",
	Controller.on(clown) == PICKS[2] and off(back, "Clownfish", "Big", PICKS[2]) < 1e-3
)
player:SetAttribute("Saddle", 0)
ok("taken off while riding: gone at once", Controller.on(clown) == nil and count() == 0)
player:SetAttribute("Saddle", 1)
settle()
ok("put on while riding: on", Controller.on(clown) == FIRST and select(4, Controller.on(clown)) == 0)
clown:SetAttribute("Rider", 0)
ok("left: gone at once", Controller.on(clown) == nil and count() == 0)

print("fish to fish, other players, fails")
local shark, sharkBack = spawnWild("ReefShark", "Normal", CFrame.new(60, -30, 10))
clown:SetAttribute("Rider", 7)
settle()
shark:SetAttribute("Reserved", 7)
settle()
ok(
	"a hop: the next one's is made while this one's is on",
	Controller.on(clown) == FIRST and select(2, Controller.on(shark)) == select(3, Controller.on(shark))
)
clown:SetAttribute("Rider", 0)
shark:SetAttribute("Rider", 7)
shark:SetAttribute("Reserved", 0)
frame()
ok(
	"and off the one left, shown on the one landed on",
	Controller.on(clown) == nil and select(4, Controller.on(shark)) == 0
)
ok("it sits on the shark", off(sharkBack, "ReefShark", "Normal", FIRST) < 1e-3)
clown:SetAttribute("Reserved", 7)
settle()
clown:SetAttribute("Reserved", 0)
ok("a grab that came to nothing leaves nothing", Controller.on(clown) == nil)
clown:SetAttribute("Rider", 8)
settle()
ok("a rider who wears none has none", Controller.on(clown) == nil)
other:SetAttribute("Saddle", 7)
settle()
ok(
	"another player's shows too, as they put it on",
	Controller.on(clown) == PICKS[7] and select(4, Controller.on(clown)) == 0
)
other:SetAttribute("Saddle", 99)
frame()
ok("a land there isn't gives none", Controller.on(clown) == nil)
other:SetAttribute("Saddle", "7")
frame()
ok("nor does what is no number", Controller.on(clown) == nil)
other:SetAttribute("Saddle", 7)
settle()
gone(clown)
ok("a fish that goes takes none of the parts along", Controller.on(clown) == nil)
for _, held in folder:GetChildren() do
	assert(held:FindFirstChildOfClass("Weld").Part0:IsDescendantOf(shark))
end
ok("and leaves the others'", Controller.on(shark) == FIRST)
local joint = folder:GetChildren()[1]:FindFirstChildOfClass("Weld").Part0
local jointParent = joint.Parent
joint.Parent = nil
frame()
ok("its part streamed out: off, so nothing falls", Controller.on(shark) == nil and count() == 0)
joint.Parent = jointParent
frame(0.3)
settle()
ok("streamed back: on again", Controller.on(shark) == FIRST)
gui.camera.CFrame = CFrame.new(60, -30, 10 + Config.Saddles.Far * 1.1)
frame(0.3)
ok("a little past the edge it stays", Controller.on(shark) == FIRST)
gui.camera.CFrame = CFrame.new(60, -30, 10 + Config.Saddles.Far * 1.3)
frame(0.3)
ok("far away it is off", Controller.on(shark) == nil)
gui.camera.CFrame = CFrame.new(60, -30, 10 + Config.Saddles.Far * 1.1)
frame(0.3)
ok("and not on again till it is near", Controller.on(shark) == nil)
gui.camera.CFrame = CFrame.new(0, 0, 0)
frame(0.3)
settle()
ok("near: on", Controller.on(shark) == FIRST)
Config.Saddles.On = 0
frame(0.3)
ok("switched off: off", Controller.on(shark) == nil and count() == 0)
Config.Saddles.On = 1
gone(shark)

print("on land, in the tank, a part mid-swing, stand-ins")
local land = gui.make("Folder", space)
land.Name = "LandFish"
space.ChildAdded:Fire(land)
local turtle, turtleBack = fishOf("SeaTurtle", "Colossal", CFrame.new(5, 8, 5))
turtle:SetAttribute("LandRider", 7)
turtle.Parent = land
land.ChildAdded:Fire(turtle)
settle()
ok(
	"the ride fish on land wears it",
	Controller.on(turtle) == FIRST and off(turtleBack, "SeaTurtle", "Colossal", FIRST) < 1e-3
)
gone(turtle)
ok("and not once it is put away", Controller.on(turtle) == nil and count() == 0)
local plot = gui.make("Folder", space)
local manta, mantaBack = fishOf("MantaRay", "Colossal", CFrame.new(-40, 12, 5))
-- (a tank fish's seat stands higher: the server does not take the size out of it)
manta.Parent = plot
manta:SetAttribute("Rider", 0)
tag("TankFish").Added:Fire(manta)
frame(0.3)
ok("a tank's fish with no rider has none", Controller.on(manta) == nil)
manta:SetAttribute("TankRider", 7)
settle()
ok(
	"ridden in the tank, it is on its back",
	Controller.on(manta) == FIRST and off(mantaBack, "MantaRay", "Colossal", FIRST) < 1e-3
)
gone(manta)

local eel, eelBack, eelParts = spawnWild("MorayEel", "Giant", CFrame.new(0, -20, 0))
for _, part in eelParts do
	for _, child in part:GetChildren() do
		if child:IsA("Motor6D") then
			child.C0 = child.C0 * CFrame.Angles(0.5, 0.4, 0.2) -- (a fail poses the fish by these)
		end
	end
end
eel:SetAttribute("Rider", 7)
settle()
ok(
	"put on in the middle of a swing, it is on the same spot of the fish",
	off(eelBack, "MorayEel", "Giant", FIRST) < 1e-3
)
gone(eel)
local block = fishOf("Clownfish", "Normal", CFrame.new(0, -20, 0))
block:SetAttribute("Rig", nil)
block.Parent = wild
tag("Fish").Added:Fire(block)
block:SetAttribute("Rider", 7)
settle()
ok("a block stand-in has none, and no error", Controller.on(block) == nil)
gone(block)

print("the parts are kept")
local seen: { [any]: boolean } = {}
local total = 0
for i = 1, 40 do
	local model = spawnWild(if i % 2 == 0 then "Clownfish" else "ReefShark", "Normal", CFrame.new(0, -20, i))
	model:SetAttribute("Rider", 7)
	settle()
	for _, part in folder:GetChildren() do
		if not seen[part] then
			seen[part] = true
			total += 1
		end
	end
	gone(model)
end
ok(`forty rides make no more than {Config.Saddles.Spare} parts`, total <= Config.Saddles.Spare, total)
print(`        {total} parts in all`)
-- (the same with the biggest one, the last land's: what is kept must not grow, and a hop has two of them at once)
local wornBefore = player:GetAttribute("Saddle")
player:SetAttribute("Saddle", #PICKS)
local big, biggest = {} :: { [any]: boolean }, 0
for i = 1, 40 do
	local from = spawnWild("Clownfish", "Normal", CFrame.new(0, -20, i))
	from:SetAttribute("Rider", 7)
	settle()
	local to = spawnWild("ReefShark", "Normal", CFrame.new(4, -20, i))
	to:SetAttribute("Reserved", 7)
	settle()
	local now = 0
	for _, part in folder:GetChildren() do
		now += 1
		big[part] = true
	end
	biggest = math.max(biggest, now)
	gone(from)
	to:SetAttribute("Reserved", nil)
	gone(to)
end
local made40 = 0
for _ in big do
	made40 += 1
end
print(`        land 10's: {biggest} parts at once in a hop, {made40} parts made in forty hops`)
ok("forty hops with it: no part made anew after the first", made40 <= biggest, made40)
player:SetAttribute("Saddle", wornBefore)
local crowd = {}
for i = 1, 6 do
	ids[10 + i] = gui.make("Player")
	ids[10 + i]:SetAttribute("Saddle", i)
	crowd[i] = spawnWild("ReefShark", "Normal", CFrame.new(0, -20, i * 10))
	crowd[i]:SetAttribute("Rider", 10 + i)
end
local worst = 0
for _ = 1, 40 do
	local had = count()
	frame()
	worst = math.max(worst, count() - had)
end
local whole = true
for _, model in crowd do
	local _, m, n, s = Controller.on(model)
	whole = whole and m == n and s == 0
end
ok("six riders at once: every saddle whole", whole)
ok("still few parts a frame", worst <= Config.Saddles.PartsAFrame, worst)
print(`        {count()} parts on screen with six riders`)
for _, model in crowd do
	gone(model)
end
ok("all off", count() == 0)

for _, line in world.warnings do
	print("  warning: " .. line)
end
ok("no warnings", #world.warnings == 0)
done()
