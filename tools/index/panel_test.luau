-- The Index's window, built and pressed offline (NULLROOM task h2): the real UI.HubButtons, UI.IndexPanel, UI.Shop,
-- UI.Kit and Config on one side and the real IndexService on the other, joined by a stand-in for the Index remote, with
-- stand-ins for Roblox's GUI (tools/index/gui.luau), the animations, the fish pictures, RideService and
-- AquariumService. It checks that the window builds with no error (every property name and type is Roblox's own),
-- that the hub button opens and closes it, that a catch shows, that a press on CLAIM is paid once by the server and
-- shown, the land's set, CLAIM ALL, one dock window at a time, the "!" rule, and the sizes on a phone (844 x 390).
-- It cannot see the window: a second argument writes each state's tree out for tools/index/panel_picture.py.
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/index/panel_test.luau /tmp/place.rbxl [dump folder]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Gui = require("./gui")
local Harness = require("./harness")

local Vector2 = (roblox :: any).Vector2
local Enum = (roblox :: any).Enum

local world = Harness.open(process.args[1] or "/tmp/place.rbxl")
local dumpTo: string? = process.args[2]
local ok, done = Harness.tally()
local gui = Gui.install(world)
local player = gui.player

----------------------------------------------------------------------------------------------------------------------
-- Stand-ins

local clock = 100
world.globals.os = setmetatable({
	clock = function()
		return clock
	end,
}, { __index = os })
-- (nothing waits: a delayed call is kept, to run by hand)
local later: { () -> () } = {}
world.globals.task = {
	delay = function(_time: number, fn: () -> ())
		table.insert(later, fn)
	end,
	defer = function(fn: (...any) -> (), ...: any)
		fn(...)
	end,
	spawn = function(fn: (...any) -> (), ...: any)
		fn(...)
	end,
	wait = function()
		return 0
	end,
}

local CLIENT = "StarterPlayer.StarterPlayerScripts.Client."
local SERVER = "ServerScriptService.Server.Services."

-- The Index remote, both ends in one place
local toClient = Gui.signal()
local toServer = Gui.signal()
local sent: { { any } } = {} -- what the client asked
local told: { { any } } = {} -- what the server answered
world.stubs["ReplicatedStorage.Shared.Net"] = {
	Index = {
		OnClientEvent = toClient,
		OnServerEvent = toServer,
		FireServer = function(_self: any, ...: any)
			table.insert(sent, { ... })
			toServer:Fire(player, ...)
		end,
		FireClient = function(_self: any, _to: any, ...: any)
			table.insert(told, { ... })
			toClient:Fire(...)
		end,
	},
}

-- The player's dive and tank, as the two services would tell it
local carried: { any } = {}
local tank: { any }? = {}
local state = "Dock"
local oxygen, coins = 0, 0
world.stubs[SERVER .. "RideService"] = {
	carried = function()
		return carried
	end,
	stateOf = function()
		return state
	end,
	train = function(_player: any, amount: number): boolean
		if state ~= "Dock" or amount <= 0 then
			return false
		end
		oxygen += amount
		return true
	end,
}
world.stubs[SERVER .. "AquariumService"] = {
	tankOf = function()
		return tank
	end,
	give = function(_player: any, amount: number)
		if tank then
			coins += amount
		end
	end,
}
world.services.Players.GetPlayers = function()
	return { player }
end

-- The client's own pieces that are not under test
world.stubs[CLIENT .. "Lib.State"] = {
	Player = player,
	Mode = "Dock",
	Zones = {
		{ Name = "SHALLOWS" },
		{ Name = "CORAL REEF" },
		{ Name = "KELP FOREST" },
		{ Name = "SHIPWRECKS" },
		{ Name = "OPEN BLUE" },
		{ Name = "TWILIGHT" },
		{ Name = "MIDNIGHT" },
		{ Name = "VENTS" },
		{ Name = "BONE GRAVEYARD" },
		{ Name = "THE UNDERWORLD" },
	},
}
local Anim = {
	Windows = 0,
	open = function() end,
	close = function(_gui: any, after: (() -> ())?)
		if after then
			after()
		end
	end,
	punch = function() end,
	button = function() end,
	shine = function() end,
	bounce = function() end,
	dim = function() end,
	stagger = function() end,
	toast = function(frame: any, on: boolean)
		frame.Visible = on
	end,
}
world.stubs[CLIENT .. "UI.Anim"] = Anim
-- A fish's picture: a frame with one colour layer at ZIndex 2 over one black one at 1, as UI.Portrait's. "fish:<id>"
-- is for the picture tool. NoPicture has none (a creature with no model yet): only in a plain run, to check the "?"
-- that stands in for it. A run that writes the trees out for the pictures gives every kind its picture, as the game.
local noPicture: { [string]: boolean } = if dumpTo then {} else { Stingray = true }
world.stubs[CLIENT .. "UI.Portrait"] = {
	new = function(parent: any, props: { [string]: any })
		local outline = props.Outline
		props.Outline = nil
		props.Aspect = nil
		props.BackgroundTransparency = 1
		local holder = gui.make("Frame", nil)
		for key, value in props do
			holder[key] = value
		end
		holder.Parent = parent
		local function layer(z: number, colour: any)
			local image = gui.make("ImageLabel", holder)
			image.Size = (roblox :: any).UDim2.fromScale(1, 1)
			image.BackgroundTransparency = 1
			image.ScaleType = Enum.ScaleType.Fit
			image.ImageColor3 = colour
			image.ZIndex = z
			image.Visible = false
			return image
		end
		local ink = layer(1, (roblox :: any).Color3.new(0, 0, 0))
		local colour = layer(2, (roblox :: any).Color3.new(1, 1, 1))
		return {
			Frame = holder,
			show = function(id: string?): boolean
				local on = id ~= nil and not noPicture[id]
				ink.Visible = on and outline ~= 0
				colour.Visible = on
				ink.Image = if on then "fish:" .. (id :: string) else ""
				colour.Image = ink.Image
				return on
			end,
		}
	end,
}

----------------------------------------------------------------------------------------------------------------------
-- The game's own modules

local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
local IndexService = world.require(world.find("ServerScriptService.Server.Services.IndexService"))
IndexService.Start()
local HubButtons = world.require(world.find(CLIENT .. "UI.HubButtons"))
local IndexPanel = world.require(world.find(CLIENT .. "UI.IndexPanel"))
local Shop = world.require(world.find(CLIENT .. "UI.Shop"))

local hud = gui.make("ScreenGui", gui.playerGui)
hud.Name = "Hud"
local built, why = pcall(HubButtons.build, hud)
ok("the hub's buttons build", built, why)
HubButtons.place(false)
HubButtons.update(true)

local function tick()
	clock += 1
	world.services.RunService.Heartbeat:Fire(1)
end
local function find(root: any, ...: string): any
	local at = root
	for _, name in { ... } do
		at = at and at:FindFirstChild(name, true)
	end
	return at
end
local function words(button: any): string
	local label = button and button:FindFirstChild("Label", true)
	return if label then label.Text else "(none)"
end
-- A press as a finger's: nothing when the button is switched off
local function press(button: any): boolean
	clock += 1
	if not button or not button.Active then
		return false
	end
	button.Activated:Fire()
	return true
end
local function catch(id: string, size: string?, variant: string?)
	table.insert(carried, { Id = id, Size = size or "Normal", Variant = variant or "" })
end
local function dump(name: string)
	if dumpTo then
		local window = gui.playerGui:FindFirstChild("IndexPanel")
		fs.writeFile(
			`{dumpTo}/{name}.json`,
			serde.encode("json", {
				View = { gui.camera.ViewportSize.X, gui.camera.ViewportSize.Y },
				Tree = Gui.dump(window),
			})
		)
	end
end

local indexButton = find(hud, "HubButtons", "Index")
local indexMark = indexButton:FindFirstChild("Mark")
local shallows = Config.indexKinds(1)
local set = Config.indexSet(1)
local total = Config.indexCount()

----------------------------------------------------------------------------------------------------------------------
print("the hub button and its mark")
ok("the Index button is there, with its mark down", indexButton ~= nil and indexMark ~= nil and not indexMark.Visible)
ok("the client asked for its Index as it loaded", #sent >= 1 and sent[1][1] == "Sync")
ok("no window before a press", gui.playerGui:FindFirstChild("IndexPanel") == nil and not IndexPanel.isOpen())

catch("Clownfish")
tick()
ok("a catch puts the mark up (the server's count)", indexMark.Visible and player:GetAttribute("IndexClaims") == 1)
ok("the panel counts the same", IndexPanel.waiting() == 1)
HubButtons.mark(true)
ok("the old hint changes nothing with the Index on", indexMark.Visible)

----------------------------------------------------------------------------------------------------------------------
print("opening")
local opened, openWhy = pcall(press, indexButton)
ok("a press on the Index button builds and opens the window", opened and IndexPanel.isOpen(), openWhy)
if not IndexPanel.isOpen() then
	done()
	return
end
local window = gui.playerGui:FindFirstChild("IndexPanel")
ok("it is the dock's open page", Shop.Page == "Index" and window ~= nil and window.Enabled)
ok("the mark stays up while a reward waits", indexMark.Visible)

local lands = find(window, "Lands")
local tabs = 0
for _, child in lands:GetChildren() do
	if child:IsA("TextButton") then
		tabs += 1
	end
end
ok("a tab for each of the ten lands", tabs == 10 and Config.indexLands() == 10, tabs)
ok("the first tab says Shallows", words(find(lands, "Land1")) == "Shallows", words(find(lands, "Land1")))
ok("the Shallows' tab has a reward's mark", find(lands, "Land1", "Waiting").Visible)
ok("and the Reef's has none", not find(lands, "Land2", "Waiting").Visible)

local list = find(window, "Tray", "List")
local function cardCount(): number
	local count = 0
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			count += 1
		end
	end
	return count
end
ok("a card for every kind of the Shallows", cardCount() == #shallows, `{cardCount()} of {#shallows}`)
local clown = list:FindFirstChild("Clownfish")
ok("the caught kind's card has its name", clown and clown:FindFirstChild("Name").Text == "Clownfish")
ok("and its picture in its own colours", find(clown, "Picture"):GetChildren()[2].ImageColor3.R == 1)
ok("and a reward's mark", clown:FindFirstChild("Waiting").Visible)
local unfound: any = nil
for _, fish in shallows do
	if fish.Id ~= "Clownfish" and not noPicture[fish.Id] then
		unfound = list:FindFirstChild(fish.Id)
		break
	end
end
ok("a kind not caught says ???", unfound and unfound:FindFirstChild("Name").Text == "???")
local shade = find(unfound, "Picture"):GetChildren()[2].ImageColor3
ok("its picture is a dark shape", shade.R < 0.1 and shade.G < 0.1 and shade.B < 0.2, tostring(shade))
ok("with no outline", not find(unfound, "Picture"):GetChildren()[1].Visible)
ok("and no reward's mark", not unfound:FindFirstChild("Waiting").Visible)
if noPicture.Stingray and list:FindFirstChild("Stingray") then
	ok("a kind with no picture shows a ?", find(list, "Stingray", "Picture"):FindFirstChildOfClass("TextLabel") ~= nil)
end

local side = find(window, "Kind")
local claim = side:FindFirstChild("Claim")
ok("the kind with a reward is the chosen one", side:FindFirstChild("Name").Text == "Clownfish")
ok("its rarity is shown", side:FindFirstChild("Tier").Text == string.upper(Config.FishById.Clownfish.Tier))
ok("and what it earns a second", string.find(side:FindFirstChild("Rate").Text, "/s", 1, true) ~= nil)
ok(
	"and its looks caught, of all there are",
	find(side, "Variants"):FindFirstChildOfClass("TextLabel").Text == `Variants 1 / {Config.indexLooks()}`,
	find(side, "Variants"):FindFirstChildOfClass("TextLabel").Text
)
local firstOxygen, firstCoins = Config.indexFirst(Config.FishById.Clownfish)
ok("its reward is Config's", find(side, "Oxygen", "Amount").Text == "+" .. Config.wholeNumber(firstOxygen))
ok("CLAIM is live", words(claim) == "Claim" and claim.Active)
local foot = find(window, "Found")
ok("1 of all found", foot:FindFirstChild("Count").Text == `1 of {total} found`, foot:FindFirstChild("Count").Text)
local all = find(window, "ClaimAll")
ok("CLAIM ALL (1)", words(all) == "Claim All (1)" and all.Active, words(all))
local landBox = find(window, "LandSet")
ok(
	"the land's set is counted",
	landBox:FindFirstChild("Count").Text == `1 / {#set}`,
	landBox:FindFirstChild("Count").Text
)
ok("named", landBox:FindFirstChild("Land").Text == "Shallows set", landBox:FindFirstChild("Land").Text)
ok("its claim is off until the set is whole", not landBox:FindFirstChild("ClaimLand").Active)
dump("1_open")

----------------------------------------------------------------------------------------------------------------------
print("choosing and claiming")
press(unfound:FindFirstChild("Press"))
ok("a press on a card chooses it", side:FindFirstChild("Name").Text == "???" and words(claim) == "Catch it first")
ok("a kind not caught cannot be claimed", not press(claim) and oxygen == 0)
press(clown:FindFirstChild("Press"))
ok("back on the caught kind", side:FindFirstChild("Name").Text == "Clownfish" and claim.Active)

state = "Free"
press(claim)
local toast = find(window, "Tray", "Toast")
ok("off the dock the server refuses", oxygen == 0 and coins == 0 and claim.Active)
ok(
	"and the window says why",
	toast.Visible and toast:FindFirstChildOfClass("TextLabel").Text == "Stand on the dock to claim"
)
state = "Dock"

press(claim)
ok("on the dock CLAIM is paid by the server", oxygen == firstOxygen and coins == firstCoins, `{oxygen} {coins}`)
ok(
	"the window says what it paid",
	toast.Visible
		and toast:FindFirstChildOfClass("TextLabel").Text == `+{firstOxygen} Oxygen   +{Shop.cash(firstCoins)}`,
	toast:FindFirstChildOfClass("TextLabel").Text
)
ok("the button says Claimed and is off", words(claim) == "Claimed" and not claim.Active)
ok(
	"the card's mark and the tab's are down",
	not clown:FindFirstChild("Waiting").Visible and not find(lands, "Land1", "Waiting").Visible
)
ok("CLAIM ALL (0), off", words(all) == "Claim All (0)" and not all.Active)
ok("the hub button's mark is down", not indexMark.Visible)
press(claim)
IndexPanel.press("Claim")
ok("a second press pays nothing", oxygen == firstOxygen and coins == firstCoins)
dump("2_claimed")
for _, fn in later do
	fn()
end
table.clear(later)
ok("the toast goes", not toast.Visible)

----------------------------------------------------------------------------------------------------------------------
print("another land")
press(find(lands, "Land2"))
local reef = Config.indexKinds(2)
ok(
	"a press on a tab shows that land's kinds",
	cardCount() == #reef and list:FindFirstChild(reef[1].Id) ~= nil,
	cardCount()
)
ok("none of them caught", list:FindFirstChild(reef[1].Id):FindFirstChild("Name").Text == "???")
ok(
	"the land's set follows",
	landBox:FindFirstChild("Land").Text == "Coral Reef set",
	landBox:FindFirstChild("Land").Text
)
catch(reef[1].Id, "Big", "Gold")
catch(reef[1].Id, "Huge", "")
tick()
ok(
	"a catch while it is open shows at once",
	list:FindFirstChild(reef[1].Id):FindFirstChild("Name").Text == reef[1].Name
)
ok("the hub button's mark is up again", indexMark.Visible)
press(list:FindFirstChild(reef[1].Id):FindFirstChild("Press"))
ok(
	"two looks of it are counted",
	find(side, "Variants"):FindFirstChildOfClass("TextLabel").Text == `Variants 2 / {Config.indexLooks()}`
)
dump("3_reef")

----------------------------------------------------------------------------------------------------------------------
print("the land's set and claim all")
for _, fish in set do
	catch(fish.Id)
end
tick()
press(find(lands, "Land1"))
local claimLand = landBox:FindFirstChild("ClaimLand")
ok("the whole set caught: n / n", landBox:FindFirstChild("Count").Text == `{#set} / {#set}`)
ok("the land's claim is live", claimLand.Active and words(claimLand) == "Claim")
local waiting = #set - 1 + 1 + 1 -- the set's other kinds, the set itself, the Reef's one
ok("CLAIM ALL counts every reward", words(all) == `Claim All ({waiting})` and all.Active, words(all))
dump("4_set")
local before = oxygen
local landOxygen, landCoins = Config.indexLand(1)
press(claimLand)
ok("the land's reward is paid once", oxygen == before + landOxygen, `{oxygen - before} of {landOxygen}`)
ok("and says Claimed", words(claimLand) == "Claimed" and not claimLand.Active)
press(claimLand)
IndexPanel.press("ClaimLand")
ok("not twice", oxygen == before + landOxygen)
local paidCoins = coins
press(all)
ok("CLAIM ALL pays the rest", words(all) == "Claim All (0)" and oxygen > before + landOxygen and coins > paidCoins)
ok(
	"nothing waits after it",
	player:GetAttribute("IndexClaims") == 0 and IndexPanel.waiting() == 0 and not indexMark.Visible
)
local after = oxygen
press(all)
IndexPanel.press("ClaimAll")
ok("and nothing more is paid", oxygen == after)
ok("the count is of all the Index", foot:FindFirstChild("Count").Text == `{#set + 1} of {total} found`)
ok("the land's coins were in it", landCoins > 0 and coins >= landCoins)

----------------------------------------------------------------------------------------------------------------------
print("closing, and one window at a time")
press(indexButton)
ok("a second press on the Index button closes it", not IndexPanel.isOpen() and Shop.Page == nil and not window.Enabled)
press(indexButton)
ok("a third opens it again", IndexPanel.isOpen() and Shop.Page == "Index")
press(find(window, "Close") or find(window, "X"))
ok("the X closes it", not IndexPanel.isOpen() and Shop.Page == nil)
local other = false
Shop.page("Other", function(on: boolean)
	other = on
end)
press(indexButton)
Shop.go("Other")
ok("another dock window opening closes it", other and not IndexPanel.isOpen() and Shop.Page == "Other")
press(indexButton)
ok("and it closes the other", not other and IndexPanel.isOpen())
Shop.go(nil)
ok("leaving the dock (Shop.go(nil)) closes it", not IndexPanel.isOpen())

----------------------------------------------------------------------------------------------------------------------
print("a catch while the window is closed")
press(indexButton)
press(find(lands, "Land3"))
local kelp = Config.indexKinds(3)
local kelpCard = list:FindFirstChild(kelp[1].Id)
ok("the Kelp's cards are up, none caught", kelpCard ~= nil and kelpCard:FindFirstChild("Name").Text == "???")
press(indexButton)
ok("closed", not IndexPanel.isOpen())
catch(kelp[1].Id)
tick()
ok("the catch is counted", player:GetAttribute("IndexClaims") == 1 and IndexPanel.waiting() == 1 and indexMark.Visible)
ok(
	"but nothing is built behind the closed window",
	rawequal(list:FindFirstChild(kelp[1].Id), kelpCard) and kelpCard.Parent == list and cardCount() == #kelp
)
ok("the old card still says ???", kelpCard:FindFirstChild("Name").Text == "???")
press(indexButton)
ok("opening paints it", list:FindFirstChild(kelp[1].Id):FindFirstChild("Name").Text == kelp[1].Name)
ok("with new cards", not rawequal(list:FindFirstChild(kelp[1].Id), kelpCard) and kelpCard.Parent == nil)
ok("and the caught kind chosen, to claim", side:FindFirstChild("Name").Text == kelp[1].Name and claim.Active)
press(claim)
press(find(lands, "Land1"))
press(indexButton)
ok("claimed, and closed again", player:GetAttribute("IndexClaims") == 0 and not IndexPanel.isOpen())

----------------------------------------------------------------------------------------------------------------------
print("the bars")
local foundFill = find(foot, "Bar", "Fill")
local landFill = find(landBox, "Bar", "Fill")
ok(
	"a bar's fill is never thinner than the bar is tall",
	foundFill.Size.X.Offset + foundFill.Size.X.Scale * 100 >= find(foot, "Bar").Size.Y.Offset
		and landFill.Size.X.Offset + landFill.Size.X.Scale * 100 >= find(landBox, "Bar").Size.Y.Offset,
	tostring(foundFill.Size)
)

----------------------------------------------------------------------------------------------------------------------
print("on a phone (844 x 390)")
gui.camera.ViewportSize = Vector2.new(844, 390)
gui.input.TouchEnabled = true
gui.input.KeyboardEnabled = false
gui.input.Last = Enum.UserInputType.Touch
press(indexButton)
local scale = find(window, "Root"):FindFirstChildOfClass("UIScale").Scale
local face = find(window, "Root", "Window")
local wide, high = face.Size.X.Offset, face.Size.Y.Offset
ok("the window fits the screen", wide * scale <= 844 and high * scale <= 390, `{wide * scale} x {high * scale}`)
print(string.format("        scale %.3f: the window is %.0f x %.0f px", scale, wide * scale, high * scale))
-- (sizes in the window's points: a size's offset, plus its scale of the room it sits in)
local body = find(window, "Body")
local bodyWide = wide + body.Size.X.Offset
local function px(button: any, room: number): (number, number)
	return (button.Size.X.Scale * room + button.Size.X.Offset) * scale, button.Size.Y.Offset * scale
end
local LEAST = 32 -- px: the least a finger's target is tall here (the kit's own buttons come out 31 to 34 on a phone)
local tabWide = px(find(lands, "Land2"), bodyWide)
local tabHigh = lands.Size.Y.Offset * scale
ok(`a land's tab is at least {LEAST} px tall`, tabHigh >= LEAST, tabHigh)
ok("and 55 px wide", tabWide >= 55, tabWide)
local _, claimHigh = px(claim, 0)
ok(`CLAIM is at least {LEAST} px tall`, claimHigh >= LEAST, claimHigh)
local _, allHigh = px(all, 0)
ok(`CLAIM ALL is at least {LEAST} px tall`, allHigh >= LEAST, allHigh)
local _, landHigh = px(claimLand, 0)
ok(`the land's CLAIM is at least 30 px tall`, landHigh >= 30, landHigh)
local card = list:FindFirstChildOfClass("Frame")
ok("a card is at least 80 x 80 px", card.Size.X.Offset * scale >= 80 and card.Size.Y.Offset * scale >= 80)
print(
	string.format(
		"        tab %.0f x %.0f, claim %.0f, claim all %.0f, land claim %.0f, card %.0f x %.0f px",
		tabWide,
		tabHigh,
		claimHigh,
		allHigh,
		landHigh,
		card.Size.X.Offset * scale,
		card.Size.Y.Offset * scale
	)
)
dump("5_phone")

----------------------------------------------------------------------------------------------------------------------
print("every land, everything caught (the biggest numbers and the longest names)")
gui.camera.ViewportSize = Vector2.new(1920, 1080)
gui.input.TouchEnabled = false
gui.input.KeyboardEnabled = true
gui.input.Last = Enum.UserInputType.MouseMovement
press(indexButton)
press(indexButton)
local most, mostLand = 0, 1
for land = 1, Config.indexLands() do
	local kinds = Config.indexKinds(land)
	if #kinds > most then
		most, mostLand = #kinds, land
	end
	for _, fish in kinds do
		catch(fish.Id)
	end
end
tick()
local every = true
for land = 1, Config.indexLands() do
	press(find(lands, "Land" .. land))
	every = every and cardCount() == #Config.indexKinds(land)
	if land == mostLand then
		dump("6_most")
	end
end
ok("every land's tab shows its own kinds", every)
ok("all found", foot:FindFirstChild("Count").Text == `{total} of {total} found`, foot:FindFirstChild("Count").Text)
print(`        the land with the most kinds: {mostLand}, {most}`)
dump("7_under")
press(all)
ok("CLAIM ALL pays everything left, once", player:GetAttribute("IndexClaims") == 0 and words(all) == "Claim All (0)")

for _, line in world.warnings do
	print("  warning: " .. line)
end
ok("no warnings", #world.warnings == 0)
done()
