-- The Fuse machine's window, its ring and its show, built and pressed offline (NULLROOM task u1): the real UI.FusePanel,
-- UI.Shop, UI.Kit, StallController and HubSigns on one side and the real FuseService, AquariumService and RideService on
-- the other (tools/fuse/world.luau), joined by a stand-in for the remotes, with stand-ins for Roblox's GUI, the
-- animations, the fish pictures and the other windows.
-- It cannot see the window: a second argument writes each state's tree out for tools/fuse/picture.py.
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/fuse/panel_test.luau /tmp/place.rbxl [dump folder]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Gui = require("../index/gui")
local Harness = require("../index/harness")
local World = require("./world")

local Vector2 = (roblox :: any).Vector2
local Vector3 = (roblox :: any).Vector3
local Color3 = (roblox :: any).Color3
local UDim2 = (roblox :: any).UDim2
local Enum = (roblox :: any).Enum

local dumpTo: string? = process.args[2]
local ok, done = Harness.tally()
local CLIENT = "StarterPlayer.StarterPlayerScripts.Client."
local KIND, OTHER = "Clownfish", "Pufferfish"
local AT, OFF = Vector3.new(102, 3, 101), Vector3.new(160, 3, 101)

-- One machine and the server
local function open(): any
	local w = World.new(process.args[1] or "/tmp/place.rbxl")
	w.plot(1)
	local world = w.world
	local g: any = { w = w, bursts = 0, rings = 0, lost = false, asks = 0 }
	local Config = w.require("ReplicatedStorage.Shared.Config")
	g.Config = Config
	Config.Aquarium.AutoEquip = 0
	for key, value in
		{ On = 1, Price = 0, SameSize = 0, Earning = 0, SureSize = "Giant", SwirlTime = 1.1, HoldTime = 1.5 }
	do
		Config.Fuse[key] = value -- (the checks' own numbers: a change in the file for the tuning is no failure here)
	end
	g.Ride, g.Tank, g.Service = w.service("RideService"), w.service("AquariumService"), w.service("FuseService")
	for _, s in { g.Ride, g.Tank, g.Service } do
		if s.Init then
			s.Init()
		end
	end
	for _, s in { g.Ride, g.Tank, g.Service } do
		if s.Start then
			coroutine.wrap(s.Start)()
		end
	end
	local p = w.join("Ann")
	g.player = p
	local root = p.Character:FindFirstChild("HumanoidRootPart")
	rawget(p.Character, "_own").PrimaryPart = root
	w.stand(p, OFF)
	local make = world.globals.Instance.new
	local playerGui = make("PlayerGui", p)
	g.playerGui = playerGui
	local space = w.space
	world.services.Players = {
		LocalPlayer = p,
		PlayerAdded = Gui.signal(),
		PlayerRemoving = Gui.signal(),
		GetPlayers = function()
			return { p }
		end,
	}
	g.beat = world.services.RunService.Heartbeat

	-- the remotes' other ends
	local net = world.stubs["ReplicatedStorage.Shared.Net"]
	local toClient = Gui.signal()
	net.Ride.OnClientEvent = toClient
	net.Index.OnClientEvent = Gui.signal()
	local tell = net.Ride.FireClient
	net.Ride.FireClient = function(self: any, player: any, ...: any)
		tell(self, player, ...)
		if not g.lost then
			toClient:Fire(...)
		end
	end
	net.Action.FireServer = function(_self: any, ...: any)
		g.asks += 1
		g.last = { ... }
		w.ask(p, ...)
	end

	-- the client's pieces that are not under test
	local State =
		{ Player = p, Mode = "Dock", Fade = 0, FadeText = "", Caught = nil, ModeChanged = { Event = Gui.signal() } }
	g.State = State
	world.stubs[CLIENT .. "Lib.State"] = State
	world.stubs[CLIENT .. "Lib.Fx"] = {
		burst = function(at: any)
			g.bursts += 1
			g.burstAt = at
		end,
		ring = function()
			g.rings += 1
		end,
	}
	local scales = {}
	world.stubs[CLIENT .. "UI.Anim"] = {
		Windows = 0,
		open = function() end,
		close = function(_gui: any, after: (() -> ())?)
			if after then
				after()
			end
		end,
		dim = function() end,
		punch = function() end,
		button = function() end,
		shine = function() end,
		stagger = function() end,
		toast = function(frame: any, on: boolean)
			frame.Visible = on
		end,
		scaleOf = function(object: any)
			if not scales[object] then
				scales[object] = make("UIScale", object)
			end
			return scales[object]
		end,
	}
	world.stubs[CLIENT .. "UI.Portrait"] = {
		new = function(parent: any, props: { [string]: any })
			props.BackgroundTransparency = 1
			local holder = make("Frame", nil)
			for key, value in props do
				holder[key] = value
			end
			holder.Parent = parent
			local image = make("ImageLabel", holder)
			image.Size = UDim2.fromScale(1, 1)
			image.BackgroundTransparency = 1
			image.ScaleType = Enum.ScaleType.Fit
			image.ImageColor3 = Color3.new(1, 1, 1)
			image.ZIndex = 2
			return {
				Frame = holder,
				show = function(id: string?): boolean
					image.Image = if id then "fish:" .. id else ""
					return id ~= nil
				end,
			}
		end,
	}
	local function nothing()
		return {
			Pressed = Gui.signal(),
			showing = function()
				return false
			end,
			isOpen = function()
				return false
			end,
			carrying = function() end,
		}
	end
	for _, name in
		{
			"CatchShow",
			"DockNotes",
			"HubButtons",
			"ShopScreen",
			"StatRows",
			"TankPanel",
			"AuraShop",
			"IndexPanel",
			"SellFish",
			"SubPanel",
			"UpgradeSign",
		}
	do
		world.stubs[CLIENT .. "UI." .. name] = nothing()
	end
	g.Shop = world.require(world.find(CLIENT .. "UI.Shop"))
	g.Panel = world.require(world.find(CLIENT .. "UI.FusePanel"))
	g.others = { Sell = 0 }
	g.Shop.page("Sell", function(on: boolean)
		g.others.Sell += if on then 1 else 0
	end)
	g.Stalls = world.require(world.find(CLIENT .. "Controllers.StallController"))
	g.Stalls.Start()

	function g.screen(wide: number, high: number, touch: boolean)
		space.CurrentCamera.ViewportSize = Vector2.new(wide, high)
		local input = world.services.UserInputService
		input.TouchEnabled = touch
		input.KeyboardEnabled = not touch
		input.MouseEnabled = not touch
		input.Last = if touch then Enum.UserInputType.Touch else Enum.UserInputType.MouseMovement
	end
	g.screen(1280, 720, false)
	-- what the server's own loop writes each second (parked here): what is carried, by its own layout
	function g.sync()
		local rows = {}
		for _, c in g.Ride.carried(p) do
			table.insert(rows, { c.Id, c.Size, c.Variant, c.Key or 0 } :: { any })
		end
		p:SetAttribute("Hands", serde.encode("json", rows))
	end
	-- time goes by (the server and the client share a clock here)
	function g.pass(seconds: number)
		g.sync()
		local n = math.max(1, math.ceil(seconds / 0.05 - 1e-6))
		for _ = 1, n do
			w.clock += seconds / n
			g.beat:Fire(seconds / n)
		end
	end
	-- equipped at its own tank, and back at the machine (no beat in between: the window stays)
	function g.equip(key: string, verb: string?)
		w.clock += 5
		w.stand(p, Vector3.new(300, 3, 12))
		w.ask(p, "Tank", verb or "Equip", string.sub(key, 2))
		w.stand(p, AT)
	end
	function g.tank(size: string, variant: string?, id: string?, on: boolean?): string
		local had = {}
		for _, f in g.Tank.tankOf(p) do
			had[f] = true
		end
		assert(g.Tank.give(p, 0, { { id or KIND, size, variant or "" } }), "no tank")
		for _, f in g.Tank.tankOf(p) do
			if not had[f] then
				if on then
					g.equip("T" .. f.Key)
				end
				return "T" .. f.Key
			end
		end
		error("not given")
	end
	function g.hand(size: string, variant: string?, id: string?): string
		assert(g.Ride.giveCarried(p, { Id = id or KIND, Size = size, Variant = variant or "" }), "hands full")
		g.sync()
		local list = g.Ride.carried(p)
		return "H" .. list[#list].Key
	end
	function g.count(): number
		return #g.Tank.tankOf(p) + #g.Ride.carried(p)
	end
	function g.sizes(): string
		local out = {}
		for _, list in { g.Tank.tankOf(p), g.Ride.carried(p) } do
			for _, f in list do
				table.insert(out, if f.Variant ~= "" then f.Size .. " " .. f.Variant else f.Size)
			end
		end
		table.sort(out)
		return table.concat(out, ", ")
	end
	function g.window(): any
		return playerGui:FindFirstChild("FusePanel")
	end
	function g.find(...: string): any
		local at = g.window()
		for _, name in { ... } do
			at = at and at:FindFirstChild(name, true)
		end
		return at
	end
	function g.shown(...: string): boolean
		local at = g.find(...)
		while at and at:IsA("GuiObject") do
			if not at.Visible then
				return false
			end
			at = at.Parent
		end
		return at ~= nil
	end
	function g.text(...: string): string
		local label = g.find(...)
		return if label then label.Text else "(none)"
	end
	-- the grid, in its order: "Huge Gold" and, when it can't go in, "(Equipped)"
	function g.cards(): { any }
		local out = {}
		for _, card in g.find("List"):GetChildren() do
			if card.Name == "Item" and card.Visible then
				table.insert(out, card)
			end
		end
		table.sort(out, function(a: any, b: any)
			return a.LayoutOrder < b.LayoutOrder
		end)
		return out
	end
	function g.words(card: any): string
		local row = card:FindFirstChild("Words")
		local variant = row:FindFirstChild("Variant")
		local veil = card:FindFirstChild("Veil")
		local text = row:FindFirstChild("Size").Text
		if variant.Visible then
			text ..= " " .. variant.Text
		end
		if veil.Visible then
			text ..= " (" .. veil:FindFirstChild("Word", true).Text .. ")"
		end
		return text
	end
	function g.grid(): string
		local out = {}
		for _, card in g.cards() do
			table.insert(out, g.words(card))
		end
		return table.concat(out, ", ")
	end
	-- a finger on the first free card with those words (and not in a pod yet)
	function g.pick(words: string): boolean
		for _, card in g.cards() do
			if g.words(card) == words and not card:FindFirstChild("Tick").Visible then
				g.pass(0.2)
				card:FindFirstChild("Press").Activated:Fire()
				return true
			end
		end
		return false
	end
	function g.press(...: string): boolean
		g.pass(0.2)
		local button = g.find(...)
		if not button or not button.Active then
			return false
		end
		button.Activated:Fire()
		return true
	end
	function g.fuse(): boolean
		return g.press("Machine", "Fuse")
	end
	function g.fuseWord(): string
		return g.text("Machine", "Fuse", "Label")
	end
	function g.toast(): string
		g.pass(0.05)
		return if g.shown("Toast") then g.text("Toast", "Word") else ""
	end
	function g.pods(): string
		local out = {}
		for i = 1, 3 do
			local pod = "Pod" .. i
			local text = if g.shown(pod, "Size") then g.text(pod, "Size", "Word") else "-"
			if g.shown(pod, "Tag") then
				text ..= " " .. g.text(pod, "Tag", "Word")
			end
			table.insert(out, text)
		end
		return table.concat(out, ", ")
	end
	function g.dump(name: string)
		if dumpTo then
			fs.writeFile(
				`{dumpTo}/{name}.json`,
				serde.encode("json", {
					View = { space.CurrentCamera.ViewportSize.X, space.CurrentCamera.ViewportSize.Y },
					Tree = Gui.dump(g.window()),
				})
			)
		end
	end
	g.pass(0.1) -- (seen on the dock, off the ring)
	function g.walkOn()
		w.stand(p, AT)
		g.pass(0.3)
	end
	function g.walkOff()
		w.stand(p, OFF)
		g.pass(0.3)
	end
	return g
end

----------------------------------------------------------------------------------------------------------------------
print("the ring")
do
	local g = open()
	for _ = 1, 3 do
		g.hand("Normal")
	end
	ok("nothing off the ring", g.window() == nil and g.Shop.Page == nil)
	g.walkOn()
	ok("standing on it opens the window, no key", g.Panel.isOpen() and g.Shop.Page == "Fuse" and g.window().Enabled)
	g.walkOff()
	ok("walking off closes it", not g.Panel.isOpen() and g.Shop.Page == nil and not g.window().Enabled)
	g.walkOn()
	g.press("Header", "Close")
	g.pass(1)
	ok("the X keeps it shut while standing there", not g.Panel.isOpen())
	g.walkOff()
	g.walkOn()
	ok("off and on again opens it", g.Panel.isOpen())
	g.Shop.go("Sell")
	ok("one dock window at a time", not g.Panel.isOpen() and g.others.Sell == 1)
	g.walkOff()
	g.Config.Fuse.On = 0
	g.walkOn()
	ok("Fuse.On 0: the ring opens nothing", not g.Panel.isOpen())
	g.Config.Fuse.On = 1
	g.pass(0.2)
	ok("and on again while standing there opens it", g.Panel.isOpen())
	g.Config.Fuse.On = 0
	g.pass(0.2)
	ok("switched off while open closes it", not g.Panel.isOpen())
	g.Config.Fuse.On = 1
	g.walkOff()
	g.State.Mode = "Riding"
	g.walkOn()
	ok("not on a dive", not g.Panel.isOpen())
	g.State.Mode = "Dock"
	g.walkOff()
	g.player:SetAttribute("TankRide", "x")
	g.walkOn()
	ok("nor riding in the tank", not g.Panel.isOpen())
	g.player:SetAttribute("TankRide", nil)
	g.walkOff()
	g.State.Mode = "Riding"
	g.pass(0.2)
	g.w.stand(g.player, AT)
	g.State.Mode = "Dock"
	g.pass(1)
	ok("put down on the ring (the spawn, after a dive): not opened", not g.Panel.isOpen())
	g.walkOff()
	g.walkOn()
	ok("off and on again opens it", g.Panel.isOpen())
	g.walkOff()
	g.w.ring.Name = "Other"
	g.walkOn()
	ok("no ring in the place: nothing, and no error", not g.Panel.isOpen())
end

----------------------------------------------------------------------------------------------------------------------
print("the stall's line")
do
	local g = open()
	local world = g.w.world
	local dock = g.w.stations.Parent
	local sub = world.globals.Instance.new("TextLabel", g.w.machine)
	sub.Name = "Sub"
	sub.Text = "two fish into one"
	world.stubs[CLIENT .. "UI.UpgradeSign"].start = function() end
	local Signs = world.require(world.find(CLIENT .. "UI.HubSigns"))
	ok("the dock is there", dock ~= nil)
	Signs.start()
	ok("it says what it does", sub.Text == "three fish into one", sub.Text)
	g.Config.Fuse.On = 0
	Signs.start()
	ok("and COMING SOON when fusing is off", sub.Text == "COMING SOON", sub.Text)
end

----------------------------------------------------------------------------------------------------------------------
print("the list")
do
	local g = open()
	g.walkOn()
	ok("no fish: it says what is needed", g.shown("Empty") and string.find(g.text("Empty"), "3 fish", 1, true) ~= nil)
	ok("no Fuse to press", g.fuseWord() == "Pick 3 fish" and not g.find("Machine", "Fuse").Active)
	g.dump("pc-empty")
	local a = g.tank("Normal")
	g.hand("Tiny", "Gold")
	ok("two of a kind: still nothing", #g.cards() == 0)
	g.hand("Huge")
	ok("three: they are listed, the biggest first, at once", g.grid() == "HUGE, NORMAL, TINY GOLD", g.grid())
	ok("and the empty line goes", not g.shown("Empty"))
	g.tank("Big", "", OTHER)
	g.tank("Big", "", OTHER)
	ok("two of another kind are not", #g.cards() == 3)
	g.tank("Colossal")
	ok("the top size: shown last, marked", g.grid() == "HUGE, NORMAL, TINY GOLD, COLOSSAL (Max size)", g.grid())
	g.equip(a)
	ok("one equipped leaves two: none listed", #g.cards() == 0, g.grid())
	ok("and it says to unequip", string.find(g.text("Empty"), "Unequip", 1, true) ~= nil, g.text("Empty"))
	g.hand("Normal")
	ok(
		"with three more the equipped one is shown, marked",
		g.grid() == "HUGE, NORMAL, TINY GOLD, COLOSSAL (Max size), NORMAL (Equipped)",
		g.grid()
	)
	ok("pressing it says why", g.pick("NORMAL (Equipped)") and g.toast() == "UNEQUIP IT FIRST", g.toast())
	ok("and the top one", g.pick("COLOSSAL (Max size)") and g.toast() == "IT CAN'T GROW ANY MORE", g.toast())
	ok("neither went in", g.pods() == "-, -, -", g.pods())
	g.hand("Big")
	g.player:SetAttribute("EquippedIndex", 1)
	ok(
		"the ride fish is marked too",
		g.grid() == "HUGE, BIG, NORMAL, COLOSSAL (Max size), NORMAL (Equipped), TINY GOLD (Riding)",
		g.grid()
	)
	ok("pressing it says why", g.pick("TINY GOLD (Riding)") and g.toast() == "YOU ARE RIDING THAT ONE", g.toast())
end

----------------------------------------------------------------------------------------------------------------------
print("picking, and what is shown before")
do
	local g = open()
	for _, row in { { "Huge", "" }, { "Normal", "Gold" }, { "Tiny", "" }, { "Tiny", "" } } do
		g.tank(row[1], row[2])
	end
	for _ = 1, 3 do
		g.hand("Big", "", OTHER)
	end
	g.walkOn()
	ok("both kinds are listed", #g.cards() == 7, g.grid())
	g.pick("TINY")
	ok("after the first only its kind", g.grid() == "HUGE, NORMAL GOLD, TINY, TINY", g.grid())
	ok("it is in the first pod", g.pods() == "TINY, -, -" and g.fuseWord() == "2 more", g.pods())
	ok("nothing comes out yet", g.shown("Question") and not g.shown("Grow"))
	g.pick("HUGE")
	g.pick("TINY")
	ok("three in: what stays is said", g.pods() == "TINY USED UP, HUGE STAYS, TINY USED UP", g.pods())
	ok(
		"its size before and after",
		g.text("Grow", "From") == "HUGE"
			and g.text("Grow", "To") == "COLOSSAL"
			and g.text("Core", "Size", "Word") == "COLOSSAL"
	)
	local kind = g.Config.FishById[KIND]
	local Kit = g.w.world.require(g.w.world.find(CLIENT .. "UI.Kit"))
	ok(
		"what it earns, by the tank's own sum",
		g.text("Earn", "From") == Kit.rate(g.Config.incomeOf(kind, "Huge", ""))
			and g.text("Earn", "To") == Kit.rate(g.Config.incomeOf(kind, "Colossal", ""))
	)
	ok("nothing special goes: no warning", not g.shown("Warn"))
	ok("Fuse is live", g.fuseWord() == "Fuse!" and g.find("Machine", "Fuse").Active, g.fuseWord())
	ok("a fourth is refused", g.pick("NORMAL GOLD") and g.toast() == "THE MACHINE IS FULL", g.toast())
	g.press("Pod1", "Press")
	ok("a press on a pod takes it out, the others stay put", g.pods() == "-, HUGE, TINY", g.pods())
	g.pick("NORMAL GOLD")
	ok("the next goes in the free pod", g.pods() == "NORMAL USED UP, HUGE STAYS, TINY USED UP", g.pods())
	ok(
		"a special one is warned of",
		g.shown("Warn") and g.text("Warn", "Word") == "USES UP NORMAL GOLD",
		g.text("Warn", "Word")
	)
	g.pass(3)
	g.dump("pc-warn")
	g.screen(812, 375, true)
	g.walkOff()
	g.walkOn()
	ok("closed and opened again: empty pods", g.pods() == "-, -, -", g.pods())
	g.pick("NORMAL GOLD")
	g.pick("HUGE")
	g.pick("TINY")
	g.dump("phone-warn")
	g.screen(375, 812, true)
	g.walkOff()
	g.walkOn()
	g.pick("HUGE")
	g.dump("phone-tall")
	ok(
		"pressing a picked card takes it out",
		(function()
			g.cards()[1]:FindFirstChild("Press").Activated:Fire()
			return g.pods() == "-, -, -"
		end)(),
		g.pods()
	)
	ok("nothing was asked of the server in all this", g.asks == 0)
end

----------------------------------------------------------------------------------------------------------------------
print("a fuller tank")
do
	local g = open()
	for _, row in
		{
			{ "Tiny", "" },
			{ "Normal", "Silver" },
			{ "Normal", "" },
			{ "Giant", "Gold" },
			{ "Tiny", "Rainbow" },
			{ "Big", "" },
			{ "Colossal", "" },
		}
	do
		g.tank(row[1], row[2])
	end
	for _ = 1, 4 do
		g.tank("Normal", "", OTHER)
	end
	g.tank("Huge", "", OTHER, true)
	g.hand("Big", "Gold", OTHER)
	g.walkOn()
	ok(
		"both kinds, what can't go in last",
		#g.cards() == 13 and string.match(g.grid(), "%((%a+ ?%a*)%)$") ~= nil,
		g.grid()
	)
	g.dump("pc-list")
	g.pick("GIANT GOLD")
	g.pick("TINY")
	g.dump("pc-picking")
	ok("then one kind", #g.cards() == 7, g.grid())
end

----------------------------------------------------------------------------------------------------------------------
print("the same size, the first stays; the top size refused")
do
	local g = open()
	g.tank("Big", "Rainbow")
	g.tank("Big", "")
	g.tank("Tiny", "")
	g.walkOn()
	g.pick("BIG")
	g.pick("BIG RAINBOW")
	g.pick("TINY")
	ok("equally big: the one put in first, shown before", g.pods() == "BIG STAYS, BIG USED UP, TINY USED UP", g.pods())
	ok("and the Rainbow lost is named", g.text("Warn", "Word") == "USES UP BIG RAINBOW", g.text("Warn", "Word"))
	ok(
		"the one that comes out is plain",
		g.text("Machine", "Fish") == g.Config.FishById[KIND].Name,
		g.text("Machine", "Fish")
	)
	g.press("Pod1", "Press")
	g.press("Pod2", "Press")
	g.pick("BIG RAINBOW")
	g.pick("BIG")
	ok("the other way round the Rainbow stays", g.pods() == "BIG STAYS, BIG USED UP, TINY USED UP", g.pods())
	ok("and is named so", string.find(g.text("Machine", "Fish"), "Rainbow", 1, true) ~= nil and not g.shown("Warn"))
	g.Config.Fuse.SameSize = 1
	g.walkOff()
	g.walkOn()
	ok("SameSize 1: no three of one size, none listed", #g.cards() == 0, g.grid())
	g.tank("Big", "")
	ok("three of one size are", g.grid() == "BIG RAINBOW, BIG, BIG", g.grid())
end

----------------------------------------------------------------------------------------------------------------------
print("fusing, and the show")
do
	local g = open()
	g.tank("Huge", "Gold")
	g.hand("Tiny")
	g.hand("Tiny")
	g.hand("Tiny")
	g.walkOn()
	g.pick("HUGE GOLD")
	g.pick("TINY")
	g.pick("TINY")
	ok("the gold one stays: no Sure?", not g.shown("Warn") and g.fuseWord() == "Fuse!")
	ok("pressed: the server does it at once", g.fuse() and g.sizes() == "Colossal Gold, Tiny", g.sizes())
	ok(
		"one ask, three names, nothing else",
		g.asks == 1 and g.last[1] == "Fuse" and #g.last[2] == 3 and g.last[3] == nil
	)
	ok(
		"the show is on, the button off",
		g.shown("Skip") and g.fuseWord() == "Fusing..." and not g.find("Machine", "Fuse").Active
	)
	ok("three fly", g.shown("Flyer1") and g.shown("Flyer2") and g.shown("Flyer3"))
	local before = g.find("Flyer1").Position
	g.pass(0.5)
	local after = g.find("Flyer1").Position
	ok("they move", before.X.Offset ~= after.X.Offset or before.Y.Offset ~= after.Y.Offset)
	ok("what comes out is not shown yet", not g.shown("Grow"))
	g.dump("pc-swirl")
	ok("no second ask during it", not g.fuse() or g.asks == 1)
	g.pass(0.5)
	ok("out it comes", g.text("Core", "Size", "Word") == "COLOSSAL" and g.shown("Grow") and not g.shown("Flyer1"))
	ok("with the words", g.toast() == string.upper(`your {g.Config.FishById[KIND].Name} is colossal now!`), g.toast())
	ok("and bubbles at the machine, once", g.bursts == 1 and g.rings == 1 and g.burstAt.X == 100)
	g.pass(0.3)
	g.dump("pc-result")
	g.pass(1.5)
	ok(
		"then it is ready again",
		not g.shown("Skip") and g.pods() == "-, -, -" and g.fuseWord() == "Pick 3 fish",
		g.fuseWord()
	)
	ok("nothing was lost or doubled", g.count() == 2 and g.bursts == 1)
end

----------------------------------------------------------------------------------------------------------------------
print("skipping it")
do
	local g = open()
	for _ = 1, 9 do
		g.tank("Normal")
	end
	g.walkOn()
	for _ = 1, 3 do
		g.pick("NORMAL")
	end
	g.fuse()
	g.pass(0.1)
	g.press("Skip")
	ok(
		"a press jumps to the end of the swirl",
		g.text("Core", "Size", "Word") == "BIG" and g.bursts == 1 and g.shown("Skip")
	)
	g.press("Skip")
	ok("another ends it", not g.shown("Skip") and g.pods() == "-, -, -" and g.bursts == 1)
	for _ = 1, 3 do
		g.pick("NORMAL")
	end
	g.fuse()
	ok("again: fused", g.asks == 2 and g.count() == 5, g.count())
	g.walkOff()
	ok("walking off in the middle closes it", not g.Panel.isOpen())
	g.pass(2)
	g.walkOn()
	ok("and it opens clean", not g.shown("Skip") and g.pods() == "-, -, -" and not g.shown("Flyer1"))
	ok("with what is left", g.grid() == "BIG, BIG, NORMAL, NORMAL, NORMAL", g.grid())
end

----------------------------------------------------------------------------------------------------------------------
print("Sure?")
do
	local g = open()
	g.tank("Huge")
	g.tank("Tiny", "Rainbow")
	g.tank("Giant")
	g.walkOn()
	g.pick("HUGE")
	g.pick("TINY RAINBOW")
	g.pick("GIANT")
	ok("both special ones are named", g.text("Warn", "Word") == "USES UP TINY RAINBOW + GIANT", g.text("Warn", "Word"))
	g.fuse()
	ok("the first press asks", g.fuseWord() == "Sure?" and g.asks == 0)
	g.dump("pc-sure")
	g.find("Machine", "Fuse").Activated:Fire() -- (the same click, 0.0 s later)
	ok("a double click is not a yes", g.asks == 0)
	g.pass(3)
	ok("it runs out", g.fuseWord() == "Fuse!")
	g.fuse()
	g.press("Pod3", "Press")
	g.pick("GIANT")
	ok("taking one out takes the question back", g.fuseWord() == "Fuse!" and g.asks == 0, g.fuseWord())
	g.fuse()
	g.pass(0.5)
	g.fuse()
	ok("yes: fused", g.asks == 1 and g.sizes() == "Colossal", g.sizes())
end

----------------------------------------------------------------------------------------------------------------------
print("refused, lost, changed under the hand")
do
	local g = open()
	local keys = {}
	for _ = 1, 5 do
		table.insert(keys, g.tank("Normal"))
	end
	g.walkOn()
	for _ = 1, 3 do
		g.pick("NORMAL")
	end
	-- one of them is sold from elsewhere
	g.w.clock += 5
	g.w.ask(g.player, "Sell", "Tank", string.sub(keys[1], 2))
	ok("one sold while in a pod: it leaves the pod", g.pods() == "-, NORMAL, NORMAL", g.pods())
	for _, key in { keys[2], keys[3], keys[4], keys[5] } do
		g.equip(key)
	end
	ok("equipped from elsewhere: they leave too", g.pods() == "-, -, -", g.pods())
	for _, key in { keys[2], keys[3], keys[4], keys[5] } do
		g.equip(key, "Unequip")
	end
	g.pick("NORMAL")
	g.pick("NORMAL")
	g.pick("NORMAL")
	g.w.clock += 5
	-- the server says no: standing too far
	g.w.stand(g.player, Vector3.new(100, 3, 135))
	local n = g.count()
	g.find("Machine", "Fuse").Activated:Fire()
	local said = g.text("Toast", "Word")
	ok("refused: said why, nothing taken", said == "STAND AT THE MACHINE" and g.count() == n, said)
	ok("  no show", g.bursts == 0 and not g.find("Skip").Visible)
	g.walkOff()
	g.walkOn()
	for _ = 1, 3 do
		g.pick("NORMAL")
	end
	g.Config.Fuse.Price = 1000000
	g.fuse()
	ok("too dear: said so", g.toast() == "NOT ENOUGH COINS" and g.count() == n, g.toast())
	ok("the price is on the button", string.find(g.fuseWord(), "$1M", 1, true) ~= nil, g.fuseWord())
	g.Config.Fuse.Price = 0
	g.lost = true
	g.fuse()
	ok("no answer: it waits", g.fuseWord() == "Fusing...")
	g.pass(3.2)
	ok("then lets go", g.toast() == "TRY AGAIN" and g.fuseWord() ~= "Fusing...", g.fuseWord())
	ok(
		"the list is the server's: fused, not asked twice",
		g.sizes() == "Big, Normal" and g.pods() == "BIG, -, -",
		g.sizes()
	)
	ok("no fault on the server in all of it", #g.w.faults == 0, g.w.faults[1])
end

----------------------------------------------------------------------------------------------------------------------
print("the sizes on a phone")
do
	local g = open()
	for _ = 1, 3 do
		g.tank("Normal")
	end
	for _, view in
		{ { 1280, 720, false }, { 1920, 1080, false }, { 812, 375, true }, { 667, 375, true }, { 375, 812, true } }
	do
		g.screen(view[1], view[2], view[3])
		g.walkOff()
		g.walkOn()
		local s = g.find("Root"):FindFirstChildOfClass("UIScale").Scale
		ok(
			`{view[1]} x {view[2]}: inside the screen ({string.format("%.2f", s)})`,
			860 * s <= view[1] and 540 * s <= view[2]
		)
	end
end
done()
