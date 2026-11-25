-- The stalls' floor rings, walked offline (NULLROOM task k1, Hugo 2026-11-25: "add the same circle integration as before
-- for the index lighthouse stand"): the real StallController, UI.Shop, UI.HubButtons and UI.IndexPanel, with the rings
-- where the saved place has them, and stand-ins for the other windows (each gives Shop.page its opener, as the real
-- ones do). It checks that all the rings (Sell, Auras, Sub, Index, Fuse) look the same and stand clear of every other, and
-- that each opens its window at its edge, closes it past its edge, stays shut after its X until stepped off and on, gives
-- way to another window, and does nothing off the dock; for the Index also its hub button, Config.Index.On 0, that
-- whatever window calls Shop.page("Index", ...) last is the one the ring opens (a redesigned panel needs nothing here),
-- and that a place without the station does nothing.
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/index/ring_test.luau /tmp/place.rbxl [a COPY of the map place]
-- With no map place the rings are stood in at the numbers of the place saved 2026-11-25 00:11 (MAP below).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Gui = require("./gui")
local Harness = require("./harness")

local Vector3 = (roblox :: any).Vector3

local world = Harness.open(process.args[1] or "/tmp/place.rbxl")
local mapFile: string? = process.args[2]
local ok, done = Harness.tally()
local gui = Gui.install(world)
local player = gui.player
local CLIENT = "StarterPlayer.StarterPlayerScripts.Client."

local NAMES = { "Sell", "Auras", "Sub", "Index", "Fuse" }
local OUT = 2.5 -- StallController's
local SPEED, EVERY = 28, 0.05 -- studs a second the player walks, seconds between the controller's looks

----------------------------------------------------------------------------------------------------------------------
-- The rings

local MAP: { [string]: { any } } = { -- station: its ring's middle, its size
	Sell = { Vector3.new(2983.24, 0.55, -59), Vector3.new(11.5, 0.07, 11.5) },
	Auras = { Vector3.new(3016.76, 0.55, -59), Vector3.new(11.5, 0.07, 11.5) },
	Fuse = { Vector3.new(3019.17, 0.55, -98.92), Vector3.new(11.5, 0.066, 11.5) },
	Sub = { Vector3.new(3066, 0.55, -54.24), Vector3.new(11.5, 0.07, 11.5) },
	Index = { Vector3.new(2985.5, 0.53, -108), Vector3.new(11.5, 0.05, 11.5) },
}

-- A plain Instance for what StallController reads of the map
local function node(name: string, class: string, children: { any }?, props: { [string]: any }?): any
	local self: any = { Name = name, ClassName = class, Children = children or {} }
	for key, value in props or {} do
		self[key] = value
	end
	function self.FindFirstChild(me: any, child: string): any
		for _, c in me.Children do
			if c.Name == child then
				return c
			end
		end
		return nil
	end
	function self.IsA(me: any, what: string): boolean
		return me.ClassName == what or (what == "BasePart" and me.ClassName == "Part")
	end
	return self
end

local stations = node("Stations", "Folder")
if mapFile then
	print("the rings of " .. mapFile)
	local place = roblox.deserializePlace(fs.readFile(mapFile))
	local dock = (place:GetService("Workspace") :: any).ClaudeBlockout.Dock
	local looks: { [string]: string } = {}
	local boxes: { { any } } = {}
	for _, name in { "Sell", "Auras", "Fuse", "Sub", "Index" } do
		local station = dock.Stations:FindFirstChild(name)
		ok(
			name .. ": its station is in the place, its PrimaryPart the ring",
			station and station.PrimaryPart == station:FindFirstChild("Ring")
		)
		if not station then
			continue
		end
		local ring = station.Ring
		MAP[name] = { ring.CFrame.Position, ring.Size }
		local circle = ring.Circle
		looks[name] = table.concat({
			tostring(ring.Size.X),
			tostring(ring.Size.Z),
			tostring(ring.Shape),
			tostring(ring.Transparency),
			tostring(ring.CanCollide),
			tostring(ring:HasTag("HubRing")),
			tostring(circle.Face),
			tostring(circle.PixelsPerStud),
			tostring(circle.Fill.Size),
			tostring(circle.Fill.BackgroundTransparency),
			tostring(circle.Fill.UIStroke.Thickness),
			tostring(circle.Fill.BackgroundColor3 == circle.Fill.UIStroke.Color),
		}, " ")
		for _, part in place:GetService("Workspace"):GetDescendants() do
			if part:IsA("BasePart") and part.ClassName ~= "Terrain" and part ~= ring then
				local cf, size = part.CFrame, part.Size
				local x, y, z = cf.XVector, cf.YVector, cf.ZVector
				local hx = (math.abs(x.X) * size.X + math.abs(y.X) * size.Y + math.abs(z.X) * size.Z) / 2
				local hy = (math.abs(x.Y) * size.X + math.abs(y.Y) * size.Y + math.abs(z.Y) * size.Z) / 2
				local hz = (math.abs(x.Z) * size.X + math.abs(y.Z) * size.Y + math.abs(z.Z) * size.Z) / 2
				local dx = math.max(math.abs(cf.X - ring.CFrame.X) - hx, 0)
				local dz = math.max(math.abs(cf.Z - ring.CFrame.Z) - hz, 0)
				-- (solid up to a head's height, or seen on the floor itself; the hub floor's top is at 0.5)
				local solid = part.CanCollide and cf.Y - hy < 6
				local lying = part.Transparency < 1 and cf.Y - hy < 1
				if dx * dx + dz * dz < (ring.Size.X / 2) ^ 2 and cf.Y + hy > 0.52 and (solid or lying) then
					table.insert(boxes, { name, part:GetFullName() })
				end
			end
		end
	end
	for _, name in { "Auras", "Sub", "Index" } do
		ok(
			name .. ": its ring looks like Sell's (size, shape, circle, see-through, tag)",
			looks[name] == looks.Sell,
			looks[name]
		)
	end
	for _, name in NAMES do
		local found = {}
		for _, b in boxes do
			if b[1] == name then
				table.insert(found, b[2])
			end
		end
		ok(name .. ": nothing stands on its ring", #found == 0, table.concat(found, ", "))
	end
end
for name, ring in MAP do
	table.insert(
		stations.Children,
		node(name, "Model", { node("Ring", "Part", nil, { Position = ring[1], Size = ring[2] }) })
	)
end
for _, a in NAMES do
	for b, ring in MAP do
		if a < b then
			local flat = (MAP[a][1] - ring[1]) * Vector3.new(1, 0, 1)
			local least = MAP[a][2].X / 2 + ring[2].X / 2 + 2 * OUT
			ok(
				`{a} and {b}: the rings never overlap, their closing edges neither`,
				flat.Magnitude > least,
				flat.Magnitude
			)
		end
	end
end
local blockout = node("ClaudeBlockout", "Folder", { node("Dock", "Folder", { stations }) })
world.globals.workspace = setmetatable({
	FindFirstChild = function(_self: any, name: string): any
		return if name == "ClaudeBlockout" then blockout else nil
	end,
}, {
	__index = function(_self: any, key: string): any
		return (gui.workspace :: any)[key]
	end,
})

----------------------------------------------------------------------------------------------------------------------
-- Stand-ins

local clock = 100
world.globals.os = setmetatable({
	clock = function()
		return clock
	end,
}, { __index = os })
world.globals.task = {
	delay = function() end,
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
world.services.Players.GetPlayers = function()
	return { player }
end
world.stubs["ReplicatedStorage.Shared.Net"] = {
	Index = { OnClientEvent = Gui.signal(), FireServer = function() end },
}

local root = { Position = Vector3.new(3000, 3.5, -88) } -- the spawn
local character: any = { PrimaryPart = root }
world.services.Players.LocalPlayer = setmetatable({}, {
	__index = function(_self: any, key: string): any
		if key == "Character" then
			return character
		end
		local value = (player :: any)[key]
		if type(value) == "function" then
			return function(_me: any, ...: any)
				return value(player, ...)
			end
		end
		return value
	end,
})

local State: any = {
	Player = player,
	Mode = "Dock",
	ModeChanged = { Event = Gui.signal() },
	FadeText = "",
	Fade = 0,
	Caught = nil,
	Zones = {},
}
for _, name in
	{
		"SHALLOWS",
		"CORAL REEF",
		"KELP FOREST",
		"SHIPWRECKS",
		"OPEN BLUE",
		"TWILIGHT",
		"MIDNIGHT",
		"VENTS",
		"BONE GRAVEYARD",
		"THE UNDERWORLD",
	}
do
	table.insert(State.Zones, { Name = name })
end
world.stubs[CLIENT .. "Lib.State"] = State
world.stubs[CLIENT .. "UI.Anim"] = {
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
world.stubs[CLIENT .. "UI.Portrait"] = {
	new = function(parent: any)
		return {
			Frame = gui.make("Frame", parent),
			show = function(): boolean
				return false
			end,
		}
	end,
}
world.stubs[CLIENT .. "UI.CatchShow"] = {
	showing = function()
		return false
	end,
}
world.stubs[CLIENT .. "UI.DockNotes"] = { carrying = function() end }
world.stubs[CLIENT .. "UI.StatRows"] = { Pressed = Gui.signal() }
world.stubs[CLIENT .. "UI.TankPanel"] = {
	isOpen = function()
		return false
	end,
}

local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
local Shop = world.require(world.find(CLIENT .. "UI.Shop"))
-- the other windows: open or shut, by Shop.page's opener
local shown: { [string]: boolean } = {}
for name, module in { Sell = "SellFish", Auras = "AuraShop", Sub = "SubPanel", Fuse = "FusePanel", Shop = "ShopScreen" } do
	Shop.page(name, function(on: boolean)
		shown[name] = on
	end)
	world.stubs[CLIENT .. "UI." .. module] = { goTo = function() end }
end

local HubButtons = world.require(world.find(CLIENT .. "UI.HubButtons"))
local IndexPanel = world.require(world.find(CLIENT .. "UI.IndexPanel"))
local StallController = world.require(world.find(CLIENT .. "Controllers.StallController"))
StallController.Start()
local hud = gui.make("ScreenGui", gui.playerGui)
HubButtons.build(hud)
HubButtons.place(false)
HubButtons.update(true)

local function isOpen(name: string): boolean
	if name == "Index" then
		return IndexPanel.isOpen()
	end
	return shown[name] == true
end
-- every window open, for "one at a time"
local function openNow(): string
	local all = {}
	for _, name in { "Auras", "Fuse", "Index", "Sell", "Shop", "Sub" } do
		if isOpen(name) then
			table.insert(all, name)
		end
	end
	return table.concat(all, " ")
end

local function look()
	clock += EVERY + 0.001
	world.services.RunService.Heartbeat:Fire(EVERY)
end
local function put(x: number, z: number, y: number?)
	root.Position = Vector3.new(x, y or 3.5, z)
	look()
end
-- Walk in a straight line as a player does; returns how far from `from` the window was when it opened or closed
local function walk(x: number, z: number, from: any?): number?
	local start = root.Position
	local way = Vector3.new(x - start.X, 0, z - start.Z)
	local changed: number? = nil
	local before = Shop.Page
	local steps = math.max(1, math.ceil(way.Magnitude / (SPEED * EVERY)))
	for n = 1, steps do
		root.Position = start + way * (n / steps)
		look()
		if from and Shop.Page ~= before and not changed then
			changed = ((root.Position - from) * Vector3.new(1, 0, 1)).Magnitude
			before = Shop.Page
		end
	end
	return changed
end
local function press(name: string)
	clock += 1
	for _, d in hud:GetDescendants() do
		if d.Name == name and (d.ClassName == "TextButton" or d.ClassName == "ImageButton") then
			d.Activated:Fire()
			return
		end
	end
	error("no hub button " .. name)
end

----------------------------------------------------------------------------------------------------------------------
-- The checks

local STEP = SPEED * EVERY + 0.01
look()
ok("at the spawn no window is open", openNow() == "" and Shop.Page == nil, openNow())

for _, name in NAMES do
	print(name)
	local at, size = MAP[name][1], MAP[name][2]
	local radius = size.X / 2
	local away = Vector3.new(3000 - at.X, 0, -88 - at.Z).Unit -- off it toward the spawn
	local off = at + away * (radius + 8)
	put(off.X, off.Z)
	ok("shut while off the ring", Shop.Page == nil and openNow() == "", openNow())
	local d = walk(at.X, at.Z, at)
	ok(
		"walking on opens its window and only it, at the edge",
		Shop.Page == name and openNow() == name and d ~= nil and d <= radius and d > radius - STEP,
		`{d} {openNow()}`
	)
	-- (the circle's line: between the edge to come in and the edge to leave)
	put(at.X + away.X * (radius + OUT - 0.2), at.Z + away.Z * (radius + OUT - 0.2))
	ok("a step over the line keeps it open", openNow() == name, openNow())
	put(at.X, at.Z, 3.5 + 8)
	ok("a jump on the ring keeps it open", openNow() == name, openNow())
	put(at.X, at.Z)
	d = walk(off.X, off.Z, at)
	ok(
		"walking off closes it, 2.5 past the edge",
		Shop.Page == nil and openNow() == "" and d ~= nil and d >= radius + OUT and d < radius + OUT + STEP,
		`{d} {openNow()}`
	)
	put(at.X + away.X * (radius + OUT - 0.2), at.Z + away.Z * (radius + OUT - 0.2))
	ok("coming back only to the outer edge doesn't open it", openNow() == "", openNow())
	walk(at.X, at.Z)
	ok("on again opens it again", openNow() == name, openNow())
	-- the X
	Shop.go(nil)
	for _ = 1, 20 do
		look()
	end
	ok("after its X it stays shut while stood on", openNow() == "", openNow())
	walk(at.X + 1, at.Z + 1)
	ok("and after a step inside the ring", openNow() == "", openNow())
	walk(off.X, off.Z)
	walk(at.X, at.Z)
	ok("off and on again opens it", openNow() == name, openNow())
	-- another window
	press("Shop")
	ok("the hub's Shop button takes over: one window at a time", openNow() == "Shop" and Shop.Page == "Shop", openNow())
	walk(off.X, off.Z)
	ok("walking off leaves that other window open", openNow() == "Shop", openNow())
	walk(at.X, at.Z)
	ok("walking on closes it and opens the ring's own", openNow() == name, openNow())
	-- leaving the dock
	State.Mode = "Free"
	State.ModeChanged.Event:Fire("Free")
	look()
	ok("leaving the dock closes it", openNow() == "" and Shop.Page == nil, openNow())
	walk(off.X, off.Z)
	walk(at.X, at.Z)
	ok("off the dock the ring opens nothing", openNow() == "", openNow())
	State.Mode = "Dock"
	player:SetAttribute("TankRide", true)
	look()
	ok("nor while riding in a tank", openNow() == "", openNow())
	player:SetAttribute("TankRide", nil)
	look()
	ok("put back on the dock on it: shut (fusing's rule, every ring's)", openNow() == "", openNow())
	walk(off.X, off.Z)
	walk(at.X, at.Z)
	ok("off and on again opens it", openNow() == name, openNow())
	-- a teleport away, the character gone
	character = nil
	look()
	ok("with the character gone it closes", openNow() == "", openNow())
	character = { PrimaryPart = root }
	put(off.X, off.Z)
end

print("from one ring to the next")
for n, name in NAMES do
	local to = NAMES[n % #NAMES + 1]
	put(MAP[name][1].X, MAP[name][1].Z)
	put(MAP[to][1].X, MAP[to][1].Z) -- (in one look, as a teleport)
	ok(`{name} to {to}: the new one is open, alone`, openNow() == to and Shop.Page == to, openNow())
end
put(3000, -88)
Config.Fuse.On = 0
put(MAP.Fuse[1].X, MAP.Fuse[1].Z)
ok("Config.Fuse.On 0: the Fuse's ring opens nothing", openNow() == "", openNow())
Config.Fuse.On = 1
put(3000, -88)

print("the Index and its hub button")
local at = MAP.Index[1]
press("Index")
ok("the button opens it away from the ring", openNow() == "Index", openNow())
walk(2990, -80)
ok("walking about away from the ring leaves it open", openNow() == "Index", openNow())
walk(at.X, at.Z)
ok("walking onto the ring leaves it open", openNow() == "Index", openNow())
walk(3000, -88)
ok("walking off the ring closes it", openNow() == "", openNow())
walk(at.X, at.Z)
press("Index")
ok("on the ring the button closes it", openNow() == "", openNow())
for _ = 1, 20 do
	look()
end
ok("and it stays shut while stood on", openNow() == "", openNow())
press("Index")
ok("and the button opens it again", openNow() == "Index", openNow())
walk(3000, -88)
ok("off the ring it closes", openNow() == "", openNow())
Config.Index.On = 0
walk(at.X, at.Z)
ok("Config.Index.On 0: the ring opens nothing", openNow() == "", openNow())
Config.Index.On = 1
look()
ok("back to 1 while stood on: it opens", openNow() == "Index", openNow())
walk(3000, -88)

print("a new Index panel")
local newPanel = false
Shop.page("Index", function(on: boolean)
	newPanel = on
end)
walk(at.X, at.Z)
ok(
	'the ring opens whatever gave Shop.page("Index") its opener',
	newPanel and not IndexPanel.isOpen() and Shop.Page == "Index"
)
walk(3000, -88)
ok("and closes it", not newPanel and Shop.Page == nil)
Shop.page("Index", IndexPanel.open)

print("a place without the Index station (the partner's, where it was deleted by hand on 2026-11-23)")
for n, station in stations.Children do
	if station.Name == "Index" then
		table.remove(stations.Children, n)
		break
	end
end
walk(at.X, at.Z)
ok("no ring: nothing opens, nothing breaks", openNow() == "", openNow())
press("Index")
ok("the hub's button still opens it", openNow() == "Index", openNow())
Shop.go(nil)
walk(3000, -88)
blockout = nil
look()
ok("no map at all (streaming in): nothing breaks", openNow() == "", openNow())

ok("no warnings", #world.warnings == 0, table.concat(world.warnings, "; "))
done()
