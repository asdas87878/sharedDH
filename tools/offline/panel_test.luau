-- The offline rewards' window, built and pressed offline (NULLROOM task o1): the real UI.OfflinePanel, OfflineController,
-- UI.HubButtons, UI.StatRows, UI.Shop, UI.Kit and Config on one side and the real OfflineService on the other, joined by a
-- stand-in for the remote, with stand-ins for Roblox's GUI (tools/index/gui.luau), the animations, the tank and the client's
-- other pieces. It checks when the window shows and when it waits, the X and the small Claim, the claim (paid once, its
-- answer, a lost answer, a refusal), that there is no second button, and the sizes on a PC and phones.
-- It cannot see the window: a second argument writes each state's tree out for tools/offline/picture.py.
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/offline/panel_test.luau /tmp/place.rbxl [dump folder]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Gui = require("../index/gui")
local Harness = require("../index/harness")

local Vector2 = (roblox :: any).Vector2
local UDim2 = (roblox :: any).UDim2
local Enum = (roblox :: any).Enum

local dumpTo: string? = process.args[2]
local ok, done = Harness.tally()

local CLIENT = "StarterPlayer.StarterPlayerScripts.Client."
local SERVER = "ServerScriptService.Server.Services."

-- One player's machine and the server: opts.Chest (the picture's upload id)
local function open(opts: any): any
	local world = Harness.open(process.args[1] or "/tmp/place.rbxl")
	local gui = Gui.install(world)
	local player = gui.player
	local g = {
		gui = gui,
		player = player,
		clock = 100,
		lost = false, -- answers to the client are lost
		coins = 0,
		asks = 0,
		notes = {} :: { { any } },
		sounds = {} :: { string },
		catch = false,
		tankPanel = false,
		hasTank = true,
		alive = true,
		dims = {} :: { boolean },
	}
	world.globals.os = setmetatable({
		clock = function()
			return g.clock
		end,
		time = function()
			return 1_800_000_000 + math.floor(g.clock)
		end,
	}, { __index = os })
	world.globals.task = {
		delay = function() end,
		defer = function(fn: any, ...: any)
			fn(...)
		end,
		spawn = function(fn: any, ...: any)
			fn(...)
		end,
		-- (only the controller's own loop waits: it is stopped there and stepped by hand)
		wait = function()
			coroutine.yield()
		end,
	}
	local toClient, toServer = Gui.signal(), Gui.signal()
	local remote = {
		IsA = function()
			return true
		end,
		OnClientEvent = toClient,
		OnServerEvent = toServer,
		FireServer = function(_self: any, ...: any)
			g.asks += 1
			toServer:Fire(player, ...)
		end,
		FireClient = function(_self: any, _to: any, ...: any)
			if not g.lost then
				toClient:Fire(...)
			end
		end,
	}
	local function theRemote()
		return remote
	end
	world.stubs["ReplicatedStorage.Shared.Net"] = { Folder = { FindFirstChild = theRemote, WaitForChild = theRemote } }
	world.stubs[SERVER .. "AquariumService"] = {
		tankOf = function()
			return if g.hasTank then { { On = true, Income = 10 } } else nil
		end,
		give = function(_player: any, coins: number)
			if g.hasTank then
				g.coins += coins
			end
			return g.hasTank
		end,
	}
	world.services.Players.GetPlayers = function()
		return { player }
	end
	local State = {
		Player = player,
		Mode = "Dock",
		Fade = 0,
		FadeText = "",
		character = function()
			if not g.alive then
				return nil, nil, nil
			end
			return {}, {}, { Health = 100 }
		end,
	}
	g.State = State
	world.stubs[CLIENT .. "Lib.State"] = State
	local Anim = {
		Windows = 0,
		open = function() end,
		close = function(_gui: any, after: (() -> ())?)
			if after then
				after()
			end
		end,
		dim = function(on: boolean)
			table.insert(g.dims, on)
		end,
		punch = function() end,
		button = function() end,
		shine = function() end,
		bounce = function() end,
		stagger = function() end,
		toast = function() end,
		spin = function() end,
		pulse = function() end,
	}
	g.Anim = Anim
	world.stubs[CLIENT .. "UI.Anim"] = Anim
	world.stubs[CLIENT .. "UI.IndexPanel"] = {
		isOpen = function()
			return false
		end,
		waiting = function()
			return 0
		end,
	}
	world.stubs[CLIENT .. "UI.CatchShow"] = {
		showing = function()
			return g.catch
		end,
	}
	world.stubs[CLIENT .. "UI.TankPanel"] = {
		isOpen = function()
			return g.tankPanel
		end,
	}
	world.stubs[CLIENT .. "UI.DockNotes"] = {
		note = function(...: any)
			table.insert(g.notes, { ... })
		end,
	}
	world.stubs[CLIENT .. "Controllers.SoundController"] = {
		play = function(name: string)
			table.insert(g.sounds, name)
		end,
	}

	g.Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
	-- (the checks' own numbers: a change in the file for the tuning is not a failure here)
	for key, value in { Least = 300, Share = 0.5, Most = 28800, AskGap = 0.3, Settle = 0.8, On = 1 } do
		g.Config.Offline[key] = value
	end
	g.Service = world.require(world.find(SERVER .. "OfflineService"))
	g.Service.Init()
	g.Service.Start()
	g.HubButtons = world.require(world.find(CLIENT .. "UI.HubButtons"))
	local StatRows = world.require(world.find(CLIENT .. "UI.StatRows"))
	g.Shop = world.require(world.find(CLIENT .. "UI.Shop"))
	g.Panel = world.require(world.find(CLIENT .. "UI.OfflinePanel"))
	if opts.Chest then
		g.Panel.Chest = opts.Chest
	end
	g.Controller = world.require(world.find(CLIENT .. "Controllers.OfflineController"))

	-- HudController's root, as it scales it
	local hud = gui.make("ScreenGui", gui.playerGui)
	hud.Name = "RideHud"
	local root = gui.make("Frame", hud)
	root.Name = "Root"
	root.BackgroundTransparency = 1
	local scale = gui.make("UIScale", root)
	StatRows.build(root)
	g.HubButtons.build(root)
	function g.screen(wide: number, high: number, touch: boolean)
		gui.camera.ViewportSize = Vector2.new(wide, high)
		gui.input.TouchEnabled = touch
		gui.input.KeyboardEnabled = not touch
		gui.input.Last = if touch then Enum.UserInputType.Touch else Enum.UserInputType.MouseMovement
		local source = fs.readFile("src/client/Controllers/HudController.luau")
		local function of(name: string): number
			return tonumber(string.match(source, "local " .. name .. " = ([%d%.]+)")) :: number
		end
		local s = math.clamp(math.min(high / of("SCALE_HEIGHT"), wide / of("SCALE_WIDTH")), 1, of("SCALE_MAX"))
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
		g.hudScale = s
		StatRows.place(touch)
		g.HubButtons.place(touch)
	end
	g.screen(1920, 1080, false)
	g.HubButtons.update(true)
	StatRows.update(100, 1250, false, false, true, 4)
	coroutine.resume(coroutine.create(function()
		g.Controller.Start()
	end))

	-- time goes by on the client
	function g.pass(seconds: number)
		for _ = 1, math.ceil(seconds / 0.25) do
			g.clock += 0.25
			g.Controller.look(g.clock)
		end
	end
	-- the save is in, with these coins a second and this long away
	function g.back(rate: number, away: number, owed: number?)
		player:SetAttribute("SavedTank", true)
		player:SetAttribute("SavedOffline", true)
		g.Service.restore(player, {
			Left = 1_800_000_000 + math.floor(g.clock) - away,
			Rate = rate,
			Owed = owed or 0,
			Secs = 0,
		})
	end
	function g.window(): any
		return gui.playerGui:FindFirstChild("OfflinePanel")
	end
	function g.find(...: string): any
		local at = g.window()
		for _, name in { ... } do
			at = at and at:FindFirstChild(name, true)
		end
		return at
	end
	function g.text(...: string): string
		local label = g.find(...)
		return if label then label.Text else "(none)"
	end
	function g.chip(): any
		return root:FindFirstChild("OfflineClaim")
	end
	function g.chipOn(): boolean
		local chip = g.chip()
		return chip ~= nil and chip.Visible
	end
	function g.press(button: any): boolean
		g.clock += 1
		if not button or not button.Active then
			return false
		end
		button.Activated:Fire()
		return true
	end
	function g.claim()
		return g.press(g.find("Body", "Claim"))
	end
	function g.close()
		return g.press(g.find("Header", "Close"))
	end
	function g.dump(name: string)
		if dumpTo then
			local tree = { Class = "Folder", Props = {}, Attributes = {}, Children = { Gui.dump(hud) } }
			if g.window() and g.Panel.isOpen() then
				table.insert(tree.Children, Gui.dump(g.window()))
			end
			fs.writeFile(
				`{dumpTo}/{name}.json`,
				serde.encode("json", {
					View = { gui.camera.ViewportSize.X, gui.camera.ViewportSize.Y },
					Dim = g.Panel.isOpen(),
					Tree = tree,
				})
			)
		end
	end
	return g
end

-- The buttons that can be pressed in the window, by name
local function buttons(g: any): { string }
	local names = {}
	for _, d in g.window():GetDescendants() do
		if d.ClassName == "TextButton" or d.ClassName == "ImageButton" then
			table.insert(names, d.Name)
		end
	end
	table.sort(names)
	return names
end

----------------------------------------------------------------------------------------------------------------------
print("nothing owed")
do
	local g = open({})
	g.pass(5)
	ok("no window and no small Claim", g.window() == nil and not g.chipOn())
	g.back(10, 200)
	g.pass(5)
	ok("200 s away: nor then", g.window() == nil and not g.chipOn())
end

----------------------------------------------------------------------------------------------------------------------
print("it shows once the player is there and nothing else is up")
do
	local g = open({})
	g.alive = false
	g.back(10, 3 * 3600 + 12 * 60)
	g.pass(5)
	ok("not before they have spawned", g.window() == nil and not g.chipOn())
	g.alive = true
	g.State.Fade = 0.5
	g.pass(2)
	ok("not behind a fade", g.window() == nil)
	g.State.Fade = 0
	g.State.Mode = "Riding"
	g.pass(2)
	ok("not on a ride", g.window() == nil and not g.chipOn())
	g.State.Mode = "Dock"
	g.Shop.Page = "Sell"
	g.pass(2)
	ok("not over another dock window", g.window() == nil)
	g.Shop.Page = nil
	g.Anim.Windows = 1
	g.pass(2)
	ok("nor over any other window", g.window() == nil)
	g.Anim.Windows = 0
	g.tankPanel = true
	g.pass(2)
	g.tankPanel = false
	g.catch = true
	g.pass(2)
	ok("nor over the tank's, nor the catch show", g.window() == nil)
	g.catch = false
	g.player:SetAttribute("TrainerRide", true)
	g.pass(2)
	ok("nor on the trainer", g.window() == nil)
	g.player:SetAttribute("TrainerRide", nil)
	g.pass(g.Config.Offline.Settle - 0.3)
	ok("not the very moment it is clear", g.window() == nil)
	g.pass(1)
	ok("then it opens by itself", g.Panel.isOpen() and g.Shop.Page == "Offline" and g.dims[1] == true)
	ok("no small Claim while it is open", not g.chipOn())
	ok("the title", g.text("Header", "Title") == "Welcome back!", g.text("Header", "Title"))
	ok("what it is", g.text("Body", "Offline") == "OFFLINE EARNINGS")
	ok("how long", g.text("Hours") == "Your tank worked 3 h 12 min without you", g.text("Hours"))
	ok("how much: the server's own", g.text("Well", "Amount") == g.Shop.cash(57600), g.text("Well", "Amount"))
	local names = buttons(g)
	ok(
		"two buttons and no more: Claim and the X",
		#names == 2 and names[1] == "Claim" and names[2] == "Close",
		table.concat(names, ", ")
	)
	ok(
		"live, the chest not uploaded: the cash picture",
		string.find(g.find("Well", "Chest").Image, "119031387165673") ~= nil
	)

	print("claimed")
	ok("CLAIM can be pressed", g.claim())
	ok("the server paid", g.coins == 57600 and g.asks == 1)
	g.pass(0.25)
	ok("the window is closed, nothing is left", not g.Panel.isOpen() and not g.chipOn() and g.Panel.owed() == 0)
	ok("a line and a sound", #g.notes == 1 and g.notes[1][1] == "+" .. g.Shop.cash(57600) and g.sounds[1] == "Claim")
	g.pass(60)
	ok("it doesn't come back", not g.Panel.isOpen() and not g.chipOn())
end

----------------------------------------------------------------------------------------------------------------------
print("closed with the X")
do
	local g = open({})
	g.back(10, 3600)
	g.pass(3)
	ok("the X closes it", g.close() and not g.Panel.isOpen() and g.Shop.Page == nil)
	g.pass(0.25)
	ok(
		"the small Claim stays, with the amount",
		g.chipOn() and g.chip():FindFirstChild("Amount").Text == g.Shop.cash(18000)
	)
	ok("nothing was paid or asked", g.coins == 0 and g.asks == 0 and g.Panel.owed() == 18000)
	g.pass(120)
	ok("it doesn't open by itself again", not g.Panel.isOpen() and g.chipOn())
	g.State.Mode = "Riding"
	g.pass(1)
	ok("no small Claim on a dive", not g.chipOn())
	g.State.Mode = "Dock"
	g.pass(1)
	ok("there again at the dock", g.chipOn())
	ok("what would be saved still owes it", g.Service.dump(g.player).Owed == 18000)
	ok("a press opens it", g.press(g.chip()) and g.Panel.isOpen())
	g.pass(0.25)
	ok("and hides the small one", not g.chipOn())
	g.Shop.go(nil)
	g.Shop.page("Sell", function() end)
	g.Shop.go("Sell")
	g.pass(0.5)
	ok("another dock window: it stays shut, the small one is there", not g.Panel.isOpen() and g.chipOn())
	g.press(g.chip())
	ok("a press changes to it, one window at a time", g.Panel.isOpen() and g.Shop.Page == "Offline")
	g.tankPanel = true
	g.pass(0.25)
	ok("the tank's window closes it", not g.Panel.isOpen() and g.Panel.owed() == 18000)
	g.tankPanel = false
	g.pass(0.25)
	g.press(g.chip())
	ok("still claimed for all of it", g.claim() and g.coins == 18000)
end

----------------------------------------------------------------------------------------------------------------------
print("a lost answer, a double press, a refusal")
do
	local g = open({})
	g.back(10, 3600)
	g.pass(3)
	local service = g.Service
	-- the ask never gets there
	local away = g.player:GetAttribute("SavedOffline")
	g.player:SetAttribute("SavedOffline", nil)
	g.lost = true
	ok("pressed, no answer", g.claim())
	ok("CLAIM waits, the window stays", g.Panel.isOpen() and not g.find("Body", "Claim").Active)
	local before = g.asks
	g.press(g.find("Body", "Claim"))
	ok("a second press asks nothing", g.asks == before)
	g.pass(5)
	ok("after a while it can be pressed again", g.find("Body", "Claim").Active and g.Panel.owed() == 18000)
	g.lost = false
	g.claim()
	ok(
		"a refusal is said, nothing is lost",
		g.text("Hours") == "Your save is still loading, try again" and g.Panel.owed() == 18000 and g.coins == 0,
		g.text("Hours")
	)
	g.player:SetAttribute("SavedOffline", away)
	g.hasTank = false
	g.claim()
	ok(
		"no tank: said, kept",
		g.text("Hours") == "You need a tank first. It is kept for you" and g.Panel.owed() == 18000
	)
	g.hasTank = true
	g.lost = true -- (paid, and the answer is lost)
	g.claim()
	ok("paid, the answer lost: the attribute closes the window", g.coins == 18000 and not g.Panel.isOpen())
	g.pass(6)
	ok("nothing to claim again", not g.chipOn() and g.Panel.owed() == 0)
	g.clock += 1
	service.ask(g.player, "Claim")
	ok("nor by a made-up ask", g.coins == 18000)
end

----------------------------------------------------------------------------------------------------------------------
print("words")
do
	local g = open({})
	local t = g.Panel.time
	ok(
		"times",
		t(300) == "5 min" and t(3600) == "1 h" and t(28800) == "8 h" and t(11520) == "3 h 12 min" and t(3) == "1 min",
		`{t(300)} {t(3600)} {t(28800)} {t(11520)}`
	)
	g.back(1, 3600, 9.99e17)
	g.pass(3)
	local amount = g.find("Well", "Amount")
	ok(
		"a huge amount fits its line",
		#amount.Text * amount.TextSize * 0.62 <= 450,
		`{amount.Text} at {amount.TextSize}`
	)
end

----------------------------------------------------------------------------------------------------------------------
print("sizes")
for _, s in
	{
		{ Name = "pc1080", W = 1920, H = 1080, Touch = false, Deals = 57600 },
		{ Name = "pc720", W = 1280, H = 720, Touch = false, Deals = 57600 },
		{ Name = "phone", W = 375, H = 812, Touch = true, Deals = 57600 },
		{ Name = "phone-side", W = 812, H = 375, Touch = true, Deals = 57600 },
	} :: { any }
do
	local g = open({ Chest = "rbxassetid://777000777" })
	g.screen(s.W, s.H, s.Touch)
	g.back(10, 3 * 3600 + 12 * 60)
	g.pass(3)
	local k = g.find("Root"):FindFirstChildOfClass("UIScale").Scale
	local frame = g.find("Root", "Window")
	local wide, high = frame.Size.X.Offset * k, frame.Size.Y.Offset * k
	ok(`{s.Name}: the window is on the screen`, wide <= s.W and high <= s.H, `{wide} x {high}`)
	local claim = g.find("Body", "Claim").Size.Y.Offset * k
	local close = g.find("Header", "Close").Size.Y.Offset * k
	ok(`{s.Name}: CLAIM is at least 44 px high`, claim >= 44, claim)
	print(string.format("        %s: window %.0f x %.0f, CLAIM %.1f high, X %.1f", s.Name, wide, high, claim, close))
	g.dump(s.Name)
	g.close()
	g.pass(0.5)
	local chip = g.chip()
	ok(`{s.Name}: the small Claim is up`, g.chipOn())
	local right = (chip.Position.X.Offset + chip.Size.X.Offset) * g.hudScale
	ok(`{s.Name}: and on the screen`, right <= s.W, right)
	-- (on a PC it sits over the Shop button: its foot clear of the top of that button's "!")
	local holder = g.HubButtons and chip.Parent:FindFirstChild("HubButtons")
	local mark = holder:FindFirstChild("Mark", true)
	local markTop = holder.Position.Y.Offset
		- holder.Size.Y.Offset / 2
		+ mark.Position.Y.Offset
		- mark.Size.Y.Offset / 2
	ok(
		`{s.Name}: clear of the Shop's "!"`,
		s.Touch or chip.Position.Y.Offset + 4 <= markTop,
		`{chip.Position.Y.Offset} {markTop}`
	)
	g.dump(s.Name .. "-chip")
end

done()
