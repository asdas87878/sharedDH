-- The Index's window, built and pressed offline (NULLROOM task h2): the real UI.HubButtons, UI.IndexPanel, UI.Shop,
-- UI.Kit and Config on one side and the real IndexService on the other, joined by a stand-in for the Index remote, with
-- stand-ins for Roblox's GUI (tools/index/gui.luau), the animations, the fish pictures, RideService and
-- AquariumService. It checks that the window builds with no error (every property name and type is Roblox's own),
-- that the hub button opens and closes it, that a catch shows, that a press on CLAIM is paid once by the server and
-- shown, the land's set, CLAIM ALL, one dock window at a time, the "!" rule, and the sizes on a phone (844 x 390).
-- Both windows are checked by the same list: today's (UI.IndexWindow, Config.Index.Look 1) and, with a third argument
-- 0, the one before it (UI.IndexOld); what only one of them has is checked for that one. Today's also on its three
-- layouts (a PC, a phone sideways at 375 and 390 high, a phone upright 375 wide) and through the switch between looks.
-- It cannot see the window: a second argument writes each state's tree out for tools/index/look_picture.py (the old
-- look's: tools/index/panel_picture.py), "-" for none.
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/index/panel_test.luau /tmp/place.rbxl [dump folder or -] [0]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Gui = require("./gui")
local Harness = require("./harness")

local Vector2 = (roblox :: any).Vector2
local Enum = (roblox :: any).Enum

local world = Harness.open(process.args[1] or "/tmp/place.rbxl")
local dumpTo: string? = if process.args[2] ~= "-" then process.args[2] else nil
local new = process.args[3] ~= "0" -- today's window; false: the old look
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
Config.Index.Look = if new then 1 else 0
local IndexService = world.require(world.find("ServerScriptService.Server.Services.IndexService"))
IndexService.Start()
local HubButtons = world.require(world.find(CLIENT .. "UI.HubButtons"))
local IndexPanel = world.require(world.find(CLIENT .. "UI.IndexPanel"))
local Shop = world.require(world.find(CLIENT .. "UI.Shop"))
local LandBanners = world.require(world.find(CLIENT .. "UI.LandBanners"))
if dumpTo and process.args[4] ~= "plain" then
	-- (the pictures the picture tool puts in: as if uploaded)
	for land in LandBanners.Ids do
		LandBanners.Ids[land] = "land:" .. land
	end
end

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
-- The words that differ between the two looks
local function unlocked(count: number): string
	return if new then `Unlocked {count}/{total}` else `{count} of {total} found`
end
local function claimAll(count: number): string
	return if new then `CLAIM ALL ({count})` else `Claim All ({count})`
end
local CLAIM = if new then "CLAIM!" else "Claim"
local CLAIMED = if new then "CLAIMED" else "Claimed"
local CATCH = if new then "CATCH IT FIRST" else "Catch it first"
local function landTitle(name: string): string
	return if new then (string.gsub(name, " ", "\n")) else name .. " set"
end

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
local claim = find(side, "Claim")
ok("the kind with a reward is the chosen one", find(side, "Name").Text == "Clownfish")
ok("its rarity is shown", find(side, "Tier").Text == string.upper(Config.FishById.Clownfish.Tier))
ok("and what it earns a second", string.find(find(side, "Rate").Text, "/s", 1, true) ~= nil)
ok(
	"and its looks caught, of all there are",
	find(side, "Variants"):FindFirstChildOfClass("TextLabel").Text == `Variants 1 / {Config.indexLooks()}`,
	find(side, "Variants"):FindFirstChildOfClass("TextLabel").Text
)
local firstOxygen, firstCoins = Config.indexFirst(Config.FishById.Clownfish)
ok("its reward is Config's", find(side, "Oxygen", "Amount").Text == "+" .. Config.wholeNumber(firstOxygen))
ok("CLAIM is live", words(claim) == CLAIM and claim.Active)
local foot = find(window, "Found")
ok("1 of all found", foot:FindFirstChild("Count").Text == unlocked(1), foot:FindFirstChild("Count").Text)
local all = find(window, "ClaimAll")
ok("CLAIM ALL (1)", words(all) == claimAll(1) and all.Active, words(all))
local landBox = find(window, "LandSet")
ok("the land's set is counted", find(landBox, "Count").Text == `1 / {#set}`, find(landBox, "Count").Text)
ok("named", find(landBox, "Land").Text == landTitle("Shallows"), find(landBox, "Land").Text)
ok("its claim is off until the set is whole", not find(landBox, "ClaimLand").Active)
dump("1_open")

----------------------------------------------------------------------------------------------------------------------
print("choosing and claiming")
press(unfound:FindFirstChild("Press"))
ok("a press on a card chooses it", find(side, "Name").Text == "???" and words(claim) == CATCH)
ok("a kind not caught cannot be claimed", not press(claim) and oxygen == 0)
press(clown:FindFirstChild("Press"))
ok("back on the caught kind", find(side, "Name").Text == "Clownfish" and claim.Active)

state = "Free"
press(claim)
local toast = find(window, "Toast")
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
ok("the button says Claimed and is off", words(claim) == CLAIMED and not claim.Active)
ok(
	"the card's mark and the tab's are down",
	not clown:FindFirstChild("Waiting").Visible and not find(lands, "Land1", "Waiting").Visible
)
ok("CLAIM ALL (0), off", words(all) == claimAll(0) and not all.Active)
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
ok("the land's set follows", find(landBox, "Land").Text == landTitle("Coral Reef"), find(landBox, "Land").Text)
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
local claimLand = find(landBox, "ClaimLand")
ok("the whole set caught: n / n", find(landBox, "Count").Text == `{#set} / {#set}`)
ok("the land's claim is live", claimLand.Active and words(claimLand) == CLAIM)
local waiting = #set - 1 + 1 + 1 -- the set's other kinds, the set itself, the Reef's one
ok("CLAIM ALL counts every reward", words(all) == claimAll(waiting) and all.Active, words(all))
dump("4_set")
local before = oxygen
local landOxygen, landCoins = Config.indexLand(1)
press(claimLand)
ok("the land's reward is paid once", oxygen == before + landOxygen, `{oxygen - before} of {landOxygen}`)
ok("and says Claimed", words(claimLand) == CLAIMED and not claimLand.Active)
press(claimLand)
IndexPanel.press("ClaimLand")
ok("not twice", oxygen == before + landOxygen)
local paidCoins = coins
press(all)
ok("CLAIM ALL pays the rest", words(all) == claimAll(0) and oxygen > before + landOxygen and coins > paidCoins)
ok(
	"nothing waits after it",
	player:GetAttribute("IndexClaims") == 0 and IndexPanel.waiting() == 0 and not indexMark.Visible
)
local after = oxygen
press(all)
IndexPanel.press("ClaimAll")
ok("and nothing more is paid", oxygen == after)
ok("the count is of all the Index", foot:FindFirstChild("Count").Text == unlocked(#set + 1))
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
ok("and the caught kind chosen, to claim", find(side, "Name").Text == kelp[1].Name and claim.Active)
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
print("the layouts")
-- The window as it stands now: a screen that turned built it again
local function grab()
	window = gui.playerGui:FindFirstChild("IndexPanel")
	lands = find(window, "Lands")
	list = find(window, "Tray", "List")
	side = find(window, "Kind")
	claim = find(side, "Claim")
	foot = find(window, "Found")
	all = find(window, "ClaimAll")
	landBox = find(window, "LandSet")
	claimLand = find(landBox, "ClaimLand")
end
local function screen(wide: number, high: number, touch: boolean)
	if IndexPanel.isOpen() then
		press(indexButton)
	end
	gui.camera.ViewportSize = Vector2.new(wide, high)
	gui.input.TouchEnabled = touch
	gui.input.KeyboardEnabled = not touch
	gui.input.Last = if touch then Enum.UserInputType.Touch else Enum.UserInputType.MouseMovement
	press(indexButton)
	grab()
end
local function scaleNow(): number
	return find(window, "Root"):FindFirstChildOfClass("UIScale").Scale
end
-- The smallest letters on the window, in the screen's pixels (words on show only)
local function smallest(at: any): (number, string)
	local least, whose = math.huge, ""
	local function look(node: any)
		if node:IsA("GuiObject") and not node.Visible then
			return
		end
		if node:IsA("TextLabel") and node.Text ~= "" and node.TextSize < least then
			least, whose = node.TextSize, `{node.Name} "{node.Text}"`
		end
		for _, child in node:GetChildren() do
			look(child)
		end
	end
	look(at)
	return least * scaleNow(), whose
end
local LEAST = 32 -- px: the least a finger's target is tall here (the kit's own buttons come out 31 to 34 on a phone)
local function phone(wide: number, high: number)
	print(`on a phone ({wide} x {high})`)
	screen(wide, high, true)
	local scale = scaleNow()
	local face = find(window, "Root", "Window")
	local faceWide, faceHigh = face.Size.X.Offset, face.Size.Y.Offset
	ok(
		"the window fits the screen",
		faceWide * scale <= wide and faceHigh * scale <= high,
		`{faceWide * scale} x {faceHigh * scale}`
	)
	print(string.format("        scale %.3f: the window is %.0f x %.0f px", scale, faceWide * scale, faceHigh * scale))
	-- (sizes in the window's points: a size's offset, plus its scale of the room it sits in)
	local bodyWide = faceWide + find(window, "Body").Size.X.Offset
	local function px(button: any, room: number): (number, number)
		return (button.Size.X.Scale * room + button.Size.X.Offset) * scale, button.Size.Y.Offset * scale
	end
	local tabWide, tabHigh = px(find(lands, "Land2"), bodyWide)
	tabHigh = if tabHigh > 0 then tabHigh else lands.Size.Y.Offset * scale
	ok(`a land's tab is at least {if new then 30 else LEAST} px tall`, tabHigh >= (if new then 30 else LEAST), tabHigh)
	ok("and 55 px wide", tabWide >= 55, tabWide)
	local _, claimHigh = px(claim, 0)
	ok(`CLAIM is at least {LEAST} px tall`, claimHigh >= LEAST, claimHigh)
	local _, allHigh = px(all, 0)
	ok(`CLAIM ALL is at least {LEAST} px tall`, allHigh >= LEAST, allHigh)
	local _, landHigh = px(claimLand, 0)
	ok(`the land's CLAIM is at least 30 px tall`, landHigh >= 30, landHigh)
	local card = list:FindFirstChildOfClass("Frame")
	local cardWide, cardHigh = card.Size.X.Offset * scale, card.Size.Y.Offset * scale
	ok("a card is at least 80 x 80 px", cardWide >= 80 and cardHigh >= 80, `{cardWide} x {cardHigh}`)
	local letters, whose = smallest(face)
	if new then
		ok("no word is under 9.5 px", letters >= 9.5, `{letters} {whose}`)
	end
	print(
		string.format(
			"        tab %.0f x %.0f, claim %.0f, claim all %.0f, land claim %.0f, card %.0f x %.0f px, smallest word %.1f px (%s)",
			tabWide,
			tabHigh,
			claimHigh,
			allHigh,
			landHigh,
			cardWide,
			cardHigh,
			letters,
			whose
		)
	)
end
phone(844, 390)
dump("5_phone")
if new then
	phone(667, 375)
	dump("5_phone_375_high")
	phone(375, 812)
	dump("5_phone_375_wide")
	phone(375, 667)
	ok("upright, the kind sits under the tray", side.Position.Y.Offset > find(window, "Tray").Position.Y.Offset)
	print("a screen that turns while the window is open")
	local before375 = window
	press(find(lands, "Land2"))
	press(find(list, reef[2].Id, "Press"))
	gui.camera.ViewportSize = Vector2.new(667, 375)
	gui.camera:GetPropertyChangedSignal("ViewportSize"):Fire()
	grab()
	ok(
		"the window is built again for it, still open",
		IndexPanel.isOpen() and window ~= nil and not rawequal(window, before375) and window.Enabled
	)
	ok("and there is only one", #gui.playerGui:GetChildren() >= 1 and before375.Parent == nil)
	local turnedCard = list:FindFirstChild(reef[2].Id)
	ok(
		"it still shows the land and the kind it did",
		turnedCard ~= nil and turnedCard:FindFirstChildOfClass("UIStroke").Thickness > 4
	)
	press(find(lands, "Land1"))
	press(find(lands, "Land2"))
	ok("its tabs work", list:FindFirstChild(reef[1].Id) ~= nil)

	print("the old look and back")
	press(indexButton)
	Config.Index.Look = 0
	press(indexButton)
	grab()
	ok("Look 0 opens the old window", IndexPanel.isOpen() and find(window, "LandSet", "Land").Text == "Shallows set")
	local windows = 0
	for _, child in gui.playerGui:GetChildren() do
		if child.Name == "IndexPanel" then
			windows += 1
		end
	end
	ok("and it is the only one", windows == 1, windows)
	Config.Index.Look = 1
	press(find(lands, "Land2"))
	ok(
		"switched while open, it stays the old one until it closes",
		IndexPanel.isOpen() and find(list, reef[1].Id) ~= nil
	)
	press(indexButton)
	press(indexButton)
	grab()
	ok("then today's again", IndexPanel.isOpen() and find(window, "Complete") ~= nil)

	print("pictures not uploaded")
	local id = LandBanners.Ids[1]
	LandBanners.Ids[1] = ""
	press(find(lands, "Land2"))
	press(find(lands, "Land1"))
	ok(
		"a land with no picture shows its plain colours",
		find(landBox, "Painting").Image == "" and find(landBox, "Plain").Visible
	)
	ok("not darkened at the top", not find(landBox, "Shade").Visible)
	LandBanners.Ids[1] = "rbxassetid://1"
	press(find(lands, "Land2"))
	press(find(lands, "Land1"))
	ok("and its picture once it has an id", find(landBox, "Painting").Image == "rbxassetid://1")
	ok("with the dark behind its name", find(landBox, "Shade").Visible)
	LandBanners.Ids[1] = id
end

----------------------------------------------------------------------------------------------------------------------
print("every land, everything caught (the biggest numbers and the longest names)")
screen(1920, 1080, false)
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
ok("all found", foot:FindFirstChild("Count").Text == unlocked(total), foot:FindFirstChild("Count").Text)
print(`        the land with the most kinds: {mostLand}, {most}`)
dump("7_under")
press(all)
ok("CLAIM ALL pays everything left, once", player:GetAttribute("IndexClaims") == 0 and words(all) == claimAll(0))

-- The book begun again
local function begin()
	IndexService.leave(player)
	IndexService.join(player)
	table.clear(carried)
	tank = {}
	clock += 1
	toServer:Fire(player, "Sync")
end
if new then
	print("claimed, closed, another caught, opened again")
	local function kind(): string
		return find(side, "Panel", "Name").Text
	end
	screen(1920, 1080, false)
	begin()
	press(find(lands, "Land2"))
	press(find(lands, "Land1"))
	catch("Pufferfish")
	tick()
	press(find(list, "Pufferfish", "Press"))
	press(claim)
	ok("the Pufferfish is claimed", kind() == "Pufferfish" and words(claim) == CLAIMED and IndexPanel.waiting() == 0)
	press(indexButton)
	catch("ReefShark")
	tick()
	press(indexButton)
	grab()
	ok("it opens on the kind that waits", kind() == "Reef Shark" and words(claim) == CLAIM, kind())
	local function inSight(id: string): boolean
		local card = list:FindFirstChild(id)
		local grid = list:FindFirstChildOfClass("UIGridLayout")
		local gap = grid.CellPadding.Y.Offset
		local row = math.ceil(card.LayoutOrder / grid.FillDirectionMaxCells)
		local top = list:FindFirstChildOfClass("UIPadding").PaddingTop.Offset + (row - 1) * (card.Size.Y.Offset + gap)
		local at = list.CanvasPosition.Y / scaleNow()
		return top >= at and top + card.Size.Y.Offset <= at + list.Size.Y.Offset + 0.01
	end
	ok("its card is in sight", inSight("ReefShark") and list.CanvasPosition.Y > 0, list.CanvasPosition.Y)
	press(indexButton)
	catch("Clownfish")
	tick()
	press(indexButton)
	ok("a kind that waits stays chosen when another is caught", kind() == "Reef Shark" and inSight("ReefShark"))
	press(claim)
	press(indexButton)
	press(indexButton)
	ok("claimed, it opens on the other, scrolled back up", kind() == "Clownfish" and inSight("Clownfish"), kind())
	press(claim)
	press(indexButton)
	press(indexButton)
	ok("with none waiting it opens as it was left", kind() == "Clownfish" and words(claim) == CLAIMED)
end

-- The saddles (NULLROOM task s2): the land's saddle on its banner, the Saddles page, against the real IndexService
if new then
	print("the saddles")
	local function landSet(land: number, but: number?)
		for i, fish in Config.indexSet(land) do
			if i ~= but then
				catch(fish.Id)
			end
		end
		tick()
	end
	local function worn(): any
		return player:GetAttribute("Saddle")
	end
	local function saddle(): any
		return find(landBox, "Saddle")
	end
	local function plateState(): string
		return saddle():FindFirstChild("State").Text
	end
	local function page(): any
		return find(window, "SaddlesPage")
	end
	local function pageCard(land: number): any
		return find(page(), "Saddle" .. land)
	end
	local function shownKey(at: any): any
		for _, node in at:GetDescendants() do
			if node:IsA("ViewportFrame") then
				return node:GetAttribute("Saddle")
			end
		end
		return nil
	end
	local function toastText(): string
		local toast = find(window, "Toast")
		return if toast.Visible then toast:FindFirstChildOfClass("TextLabel").Text else ""
	end
	screen(1920, 1080, false)
	begin()
	press(find(lands, "Land1"))
	ok(
		"the banner has the land's saddle, its picture and name",
		saddle().Visible
			and saddle():FindFirstChild("SaddleName").Text == "Giant Clam"
			and shownKey(saddle()) == Config.Saddles.Land[1],
		tostring(shownKey(saddle()))
	)
	ok(
		"locked",
		saddle():FindFirstChild("Lock").Visible
			and not saddle():FindFirstChild("Tick").Visible
			and plateState() == "Saddle"
	)
	ok(
		"the land's coins and Oxygen are still shown",
		find(landBox, "Oxygen").Visible and find(landBox, "Coins").Visible
	)
	press(find(lands, "Land2"))
	ok("another land has its own", shownKey(saddle()) == Config.Saddles.Land[2])
	press(find(lands, "Land1"))
	landSet(1, 1)
	ok("one kind short: no claim", not claimLand.Active)
	landSet(1)
	press(claimLand)
	ok("the claim names the saddle", string.find(toastText(), "Giant Clam Saddle", 1, true) ~= nil, toastText())
	ok("OWNED on the banner, the padlock gone", plateState() == "OWNED" and not saddle():FindFirstChild("Lock").Visible)
	ok("not put on by itself", worn() == 0)
	ok("the Saddles page is closed until a press", not page() or not page().Visible)

	press(saddle())
	ok("a press on the banner's saddle opens the page", page() ~= nil and page().Visible)
	ok("what is under it is not drawn", not lands.Visible and not side.Visible and not find(window, "Tray").Visible)
	local cards = 0
	for land = 1, Config.indexLands() do
		local card = pageCard(land)
		if card and shownKey(card) == Config.Saddles.Land[land] then
			cards += 1
		end
	end
	ok("a card with its picture for every land", cards == Config.indexLands(), cards)
	ok("1 of 10", find(page(), "Count").Text == "1 / 10", find(page(), "Count").Text)
	ok(
		"theirs says WEAR",
		words(find(pageCard(1), "Wear")) == "WEAR" and not pageCard(1):FindFirstChild("Lock").Visible
	)
	local reefSet = #Config.indexSet(2)
	ok(
		"another's says how far its set is",
		words(find(pageCard(2), "Wear")) == `0 / {reefSet}` and pageCard(2):FindFirstChild("Lock").Visible,
		words(find(pageCard(2), "Wear"))
	)
	press(find(pageCard(1), "Wear"))
	ok(
		"WEAR puts it on (the server's answer)",
		worn() == 1 and words(find(pageCard(1), "Wear")) == "TAKE OFF" and pageCard(1):FindFirstChild("Tick").Visible
	)
	press(find(pageCard(1), "Wear"))
	ok(
		"TAKE OFF takes it off",
		worn() == 0 and words(find(pageCard(1), "Wear")) == "WEAR" and not pageCard(1):FindFirstChild("Tick").Visible
	)
	press(find(pageCard(1), "Wear"))
	landSet(2)
	ok("a whole set says CLAIM!", words(find(pageCard(2), "Wear")) == "CLAIM!", words(find(pageCard(2), "Wear")))
	local had = oxygen
	press(find(pageCard(2), "Wear"))
	ok(
		"a press claims the land there",
		oxygen == had + (Config.indexLand(2)) and words(find(pageCard(2), "Wear")) == "WEAR"
	)
	ok(
		"the toast is seen over the page",
		toastText() ~= "" and find(window, "Toast").ZIndex > page().ZIndex,
		toastText()
	)
	ok("2 of 10", find(page(), "Count").Text == "2 / 10")
	press(find(pageCard(2), "Wear"))
	ok(
		"the other one on: the first is off",
		worn() == 2 and words(find(pageCard(1), "Wear")) == "WEAR" and words(find(pageCard(2), "Wear")) == "TAKE OFF"
	)
	IndexPanel.press("Saddle", 9)
	ok("a press on one that isn't theirs wears nothing", worn() == 2)
	ok(
		"it goes to that land",
		not page().Visible and find(landBox, "Land").Text == landTitle("Bone Graveyard"),
		find(landBox, "Land").Text
	)
	toServer:Fire(player, "Saddle", 9)
	clock += 1
	toServer:Fire(player, "Saddle", 9)
	ok("a made-up ask is refused and said", worn() == 2 and toastText() == "Claim that land's set first", toastText())
	press(find(foot, "Saddles"))
	ok("the Saddles button opens the page", page().Visible)
	press(find(page(), "Back"))
	ok("BACK closes it", not page().Visible)
	ok("and the Index is there again", lands.Visible and side.Visible and find(window, "Tray").Visible)
	press(find(lands, "Land2"))
	ok("WORN on its land's banner", plateState() == "WORN")
	press(find(foot, "Saddles"))
	gui.camera.ViewportSize = Vector2.new(667, 375)
	gui.camera:GetPropertyChangedSignal("ViewportSize"):Fire()
	grab()
	ok("it stays open when the screen turns", page() ~= nil and page().Visible)
	screen(1920, 1080, false)
	ok("closed and opened, the Index is on its lands", not page() or not page().Visible)

	print("the saddles on a phone")
	for _, size in { { 667, 375 }, { 844, 390 }, { 375, 812 }, { 375, 667 } } do
		screen(size[1], size[2], true)
		press(find(lands, "Land1"))
		local scale = scaleNow()
		local plate = saddle()
		local plateWide, plateHigh = plate.Size.X.Offset * scale, plate.Size.Y.Offset * scale
		local door = find(foot, "Saddles")
		local doorHigh = door.Size.Y.Offset * scale
		press(door)
		local card = pageCard(1)
		local root = page()
		local rack = find(root, "Rack")
		local last = pageCard(10)
		local fits = last.Position.X.Offset + last.Size.X.Offset <= rack.Size.X.Offset
			and last.Position.Y.Offset + last.Size.Y.Offset <= rack.Size.Y.Offset
		local wear = find(card, "Wear")
		local wearHigh = wear.Size.Y.Offset * scale
		local backHigh = find(root, "Back").Size.Y.Offset * scale
		local picture = find(card, "Picture")
		local letters, whose = smallest(root)
		print(
			string.format(
				"        %d x %d: plate %.0f x %.0f, door %.0f, card %.0f x %.0f, its picture %.0f x %.0f, wear %.0f, back %.0f, smallest word %.1f px (%s)",
				size[1],
				size[2],
				plateWide,
				plateHigh,
				doorHigh,
				card.Size.X.Offset * scale,
				card.Size.Y.Offset * scale,
				picture.Size.X.Offset * scale,
				picture.Size.Y.Offset * scale,
				wearHigh,
				backHigh,
				letters,
				whose
			)
		)
		ok("the plate is a finger's target", plateWide >= 44 and plateHigh >= 30, `{plateWide} x {plateHigh}`)
		ok(
			"so are the door, WEAR and BACK",
			doorHigh >= 30 and wearHigh >= 30 and backHigh >= 30,
			`{doorHigh} {wearHigh} {backHigh}`
		)
		ok("every card is inside the page", fits)
		ok(
			"a picture is at least 48 x 36 px",
			picture.Size.X.Offset * scale >= 48 and picture.Size.Y.Offset * scale >= 36
		)
		ok("no word is under 9.5 px", letters >= 9.5, `{letters} {whose}`)
		press(find(root, "Back"))
	end

	if dumpTo then
		for _, fn in later do
			fn()
		end
		table.clear(later)
		begin()
		for land = 1, 4 do
			landSet(land)
			if land ~= 4 then
				press(find(lands, "Land" .. land))
				press(claimLand)
			end
		end
		for land = 5, 8 do
			landSet(land, 1)
		end
		press(find(foot, "Saddles"))
		press(find(pageCard(2), "Wear"))
		local function clear()
			for _, fn in later do
				fn()
			end
			table.clear(later)
		end
		local function both(name: string)
			if page().Visible then
				press(find(page(), "Back"))
			end
			press(find(lands, "Land2"))
			dump(name .. "_worn")
			press(find(lands, "Land4"))
			dump(name .. "_locked")
			press(find(foot, "Saddles"))
			dump(name .. "_page")
		end
		screen(1920, 1080, false)
		press(find(lands, "Land3"))
		press(find(lands, "Land4"))
		press(claimLand)
		dump("look_saddle_pc_claimed")
		clear()
		begin()
		for land = 1, 4 do
			landSet(land)
			if land ~= 4 then
				press(find(lands, "Land" .. land))
				press(claimLand)
			end
		end
		for land = 5, 8 do
			landSet(land, 1)
		end
		press(find(foot, "Saddles"))
		press(find(pageCard(2), "Wear"))
		clear()
		both("look_saddle_pc")
		screen(667, 375, true)
		both("look_saddle_wide")
		screen(375, 812, true)
		both("look_saddle_tall")
	end

	print("the saddles switched off")
	screen(1920, 1080, false)
	Config.Saddles.On = 0
	press(indexButton)
	press(indexButton)
	screen(667, 375, true)
	press(find(lands, "Land1"))
	ok(
		"no plate, no button, no page",
		(saddle() == nil or not saddle().Visible)
			and (find(foot, "Saddles") == nil or not find(foot, "Saddles").Visible)
			and (page() == nil or not page().Visible)
	)
	Config.Saddles.On = 1
	screen(1920, 1080, false)
	begin()
else
	ok("the old look has no saddles", find(window, "SaddlesPage") == nil and find(window, "Saddle") == nil)
end

-- The states tools/index/look_picture.py draws: a game some way in
if new and dumpTo then
	local function land(n: number, count: number, paid: number)
		for i, fish in Config.indexKinds(n) do
			if i <= count then
				catch(fish.Id)
			end
		end
		tick()
		press(find(lands, "Land" .. n))
		for i, fish in Config.indexKinds(n) do
			if i <= paid then
				press(find(list, fish.Id, "Press"))
				press(claim)
			end
		end
	end
	screen(1920, 1080, false)
	begin()
	catch("Clownfish", "Big", "Gold")
	catch("Clownfish", "Giant", "")
	catch("SeaTurtle", "Big", "")
	land(1, 9, 5)
	land(2, 5, 4)
	land(4, 3, 3)
	land(6, 99, 2)
	for _, fn in later do
		fn()
	end
	table.clear(later)
	press(find(lands, "Land1"))
	press(find(list, "SeaTurtle", "Press"))
	dump("look_pc")
	press(find(lands, "Land6"))
	dump("look_pc_whole")
	press(find(lands, "Land2"))
	press(find(list, "CoralDragon", "Press"))
	dump("look_pc_secret")
	local ids = table.clone(LandBanners.Ids)
	for n in ids do
		LandBanners.Ids[n] = ""
	end
	-- (another shape and back: a window is built with its tabs' pictures)
	screen(667, 375, true)
	screen(1920, 1080, false)
	press(find(lands, "Land1"))
	press(find(list, "SeaTurtle", "Press"))
	local bare = true
	for n = 1, 10 do
		bare = bare and find(lands, "Land" .. n, "Painting").Image == ""
	end
	ok("a game with nothing uploaded has no picture on any tab", bare)
	ok("nor on the banner", find(landBox, "Painting").Image == "")
	dump("look_pc_plain")
	for n, id in ids do
		LandBanners.Ids[n] = id
	end
	screen(667, 375, true)
	press(find(lands, "Land1"))
	press(find(list, "SeaTurtle", "Press"))
	dump("look_phone_wide")
	press(find(lands, "Land6"))
	dump("look_phone_whole")
	press(find(lands, "Land3"))
	dump("look_phone_dark")
	screen(375, 812, true)
	press(find(lands, "Land1"))
	press(find(list, "SeaTurtle", "Press"))
	dump("look_phone_tall")
	press(find(lands, "Land4"))
	state = "Free"
	press(all)
	dump("look_phone_refused")
	state = "Dock"
	-- a land opens on its first reward waiting, scrolled to when it is rows down
	screen(1920, 1080, false)
	press(find(lands, "Land1"))
	ok("the first reward waiting is in sight: the list stays at its top", list.CanvasPosition.Y == 0)
	press(find(list, "SeaTurtle", "Press"))
	press(claim)
	press(find(lands, "Land2"))
	press(find(lands, "Land1"))
	ok("the next is a row further down: the list is scrolled to it", list.CanvasPosition.Y > 0, list.CanvasPosition.Y)
	press(find(lands, "Land3"))
	ok("a land with none waiting opens at its top", list.CanvasPosition.Y == 0)
end

for _, line in world.warnings do
	print("  warning: " .. line)
end
ok("no warnings", #world.warnings == 0)
done()
