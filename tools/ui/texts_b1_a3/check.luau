-- Hugo's picks of 2026-11-25 (the dock's lines as stickers, once each respawn; "Required" on no plate) checked offline on
-- the game's own modules, and their trees written out for picture.py:
--   1  Lib/RespawnLine: waits for a clear screen, 2.5 s and the fade, once, again after the next respawn, cut short
--   2  UI/DockNotes with Controllers/GoalController over a made-up clock: nothing brings the line back on the dock
--   3  the trees (after: this branch's place; before: a place built from the commit before it, if given)
-- usage: python tools/ui/texts_b1_a3/picture.py   (it builds the places, runs this and draws the sheet)
--   lune run tools/ui/texts_b1_a3/check.luau <place.rbxl> <widths.json> <dump folder> <after|before>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Gui = require("../../index/gui")
local Harness = require("../../index/harness")

local PLACE, WIDTHS, OUT, WHICH = process.args[1], process.args[2], process.args[3], process.args[4] or "after"
local after = WHICH == "after"
local widths = serde.decode("json", fs.readFile(WIDTHS))
local ok, done = Harness.tally()
local CLIENT = "StarterPlayer.StarterPlayerScripts.Client."
local Vector2 = (roblox :: any).Vector2

-- A world with a made-up clock, the letters' real widths, and only the modules under test real
local function open(wide: number, high: number)
	local world = Harness.open(PLACE)
	local gui = Gui.install(world)
	gui.camera.ViewportSize = Vector2.new(wide, high)
	local clock = { Now = 100 }
	world.globals.os = setmetatable({
		clock = function()
			return clock.Now
		end,
	}, { __index = os })
	local threads: { { Thread: thread, At: number } } = {}
	world.globals.task = {
		wait = function(t: number?)
			coroutine.yield(t or 0)
		end,
		spawn = function(fn: any, ...: any)
			local thread = coroutine.create(fn)
			local good, t = coroutine.resume(thread, ...)
			assert(good, t)
			if coroutine.status(thread) ~= "dead" then
				table.insert(threads, { Thread = thread, At = clock.Now + (t or 0) })
			end
			return thread
		end,
		delay = function(t: number, fn: any)
			table.insert(threads, { Thread = coroutine.create(fn), At = clock.Now + t })
		end,
		cancel = function() end,
		defer = function(fn: any)
			fn()
		end,
	}
	world.services.TextService = {
		GetTextSize = function(_self: any, text: string, size: number, font: any)
			local f = widths[font.Name] or widths.FredokaOne
			local sum = 0
			for i = 1, #text do
				sum += f.Wide[string.sub(text, i, i)] or 0.5
			end
			return Vector2.new(math.ceil(sum * size * f.Em), size)
		end,
	}
	local State = { Player = gui.player, Mode = "Dock", FadeText = "", Fade = 0, Caught = {} :: { any } }
	gui.player.Character = gui.make("Model")
	rawget(gui.player, "_own").CharacterAdded = Gui.signal()
	local ride = { OnClientEvent = Gui.signal() }
	local catch = { Up = false }
	world.stubs[CLIENT .. "Lib.State"] = State
	world.stubs["ReplicatedStorage.Shared.Net"] = { Ride = ride }
	world.stubs[CLIENT .. "UI.CatchShow"] = {
		showing = function()
			return catch.Up
		end,
	}
	world.stubs[CLIENT .. "UI.TankPanel"] = {
		isOpen = function()
			return false
		end,
	}
	world.stubs[CLIENT .. "UI.Anim"] = {
		toast = function(thing: any, on: boolean)
			thing.Visible = on
		end,
		punch = function() end,
		scaleOf = function(thing: any)
			return thing:FindFirstChildOfClass("UIScale") or gui.make("UIScale", thing)
		end,
	}
	local run = world.services.RunService
	local function pass(seconds: number, each: (() -> ())?)
		local stop = clock.Now + seconds - 1e-6
		while clock.Now < stop do
			clock.Now += 1 / 60
			for i = #threads, 1, -1 do
				local t = threads[i]
				if t.At <= clock.Now then
					local good, wait = coroutine.resume(t.Thread)
					assert(good, wait)
					if coroutine.status(t.Thread) == "dead" then
						table.remove(threads, i)
					else
						t.At = clock.Now + (wait or 0)
					end
				end
			end
			run.RenderStepped:Fire(1 / 60)
			if each then
				each()
			end
		end
	end
	local function module(path: string)
		return world.require(world.find(CLIENT .. path))
	end
	return {
		World = world,
		Gui = gui,
		State = State,
		Ride = ride,
		Catch = catch,
		Clock = clock,
		pass = pass,
		module = module,
		spawn = world.globals.task.spawn,
	}
end

local function write(name: string, tree: any, wide: number, high: number)
	fs.writeFile(OUT .. "/" .. name .. ".json", serde.encode("json", { View = { wide, high }, Tree = Gui.dump(tree) }))
end

-- The screen's line now: its words (nil: none up), and how much of it is seen
local function up(w: any): (string?, number)
	local notes = w.Gui.playerGui:FindFirstChild("DockNotes")
	local root = notes and notes.Root
	for _, name in { "Carry", "Goal" } do
		local line = root and root:FindFirstChild(name)
		if line and line.Visible then
			local label
			for _, d in line:GetDescendants() do
				if d.ClassName == "TextLabel" then
					label = d -- (the last is a face, on top)
				end
			end
			return name, 1 - label.TextTransparency
		end
	end
	return nil, 0
end

----------------------------------------------------------------------------------------------------------------------
if after then
	print("the window (Lib/RespawnLine)")
	local w = open(1920, 1080)
	local Config = w.World.require(w.World.find("ReplicatedStorage.Shared.Config"))
	local R = w.module("Lib.RespawnLine")
	local d = Config.DockLine
	local now = 0
	-- runs for `t` s; gives the time anything was seen, and the most seen
	local function run(line: any, t: number, docked: boolean, clear: boolean, words: boolean): (number, number)
		local seen, most = 0, 0
		local stop = now + t - 1e-6
		while now < stop do
			now += 1 / 60
			local _, through = R.step(line, now, docked, clear, words, d)
			if through < 1 then
				seen += 1 / 60
				most = math.max(most, 1 - through)
			end
		end
		return seen, most
	end
	local line = R.new()
	ok("not while the screen is black", run(line, 4, true, false, true) == 0)
	local seen, most = run(line, 10, true, true, true)
	ok(
		string.format("up %.2f s: %.1f held and %.1f fading, and once in 10 s", seen, d.Hold, d.Fade),
		math.abs(seen - d.Hold - d.Fade) < 0.1 and most == 1,
		seen
	)
	ok("not again by standing on the dock", run(line, 60, true, true, true) == 0)
	run(line, 1, false, true, true)
	ok("nor after leaving the dock and coming back without a respawn", run(line, 10, true, true, true) == 0)
	R.respawned(line)
	ok("once more after a respawn", run(line, 10, true, true, true) > 2.5)
	R.respawned(line)
	ok("its word before our state says Dock: waits", run(line, 0.4, false, true, true) == 0 and line.Stage == "Wait")
	ok("and comes then", run(line, 10, true, true, true) > 2.5)
	R.respawned(line)
	run(line, 1.2, true, true, true)
	seen = run(line, 5, false, true, true)
	ok(string.format("a dive while it is up cuts it in %.2f s", seen), seen > 0 and seen <= d.Cut + 0.05, seen)
	ok("which was its showing", run(line, 10, true, true, true) == 0)
	R.respawned(line)
	run(line, d.Give + 0.2, true, true, false)
	ok("nothing to say at the respawn: none that time", run(line, 10, true, true, true) == 0)

	print("the dock (DockNotes, GoalController)")
	w = open(1920, 1080)
	local player = w.Gui.player
	for name, value in { Coins = 26500, TrainerLevel = 0, PlotStage = 0, SubTier = 0, MaxOxygen = 1e6, IndexClaims = 0 } do
		player:SetAttribute(name, value)
	end
	local Notes = w.module("UI.DockNotes")
	local Goals = w.module("Controllers.GoalController")
	w.spawn(Goals.Start)
	local which, at, most2, total, first
	local function watch()
		local name, see = up(w)
		if name and see > 0 then
			which, total = name, total + 1 / 60
			first = first or w.Clock.Now
			most2 = math.max(most2, see)
		end
	end
	local function look(t: number)
		which, total, most2, first, at = nil, 0, 0, nil, w.Clock.Now
		w.pass(t, watch)
	end
	look(20)
	ok(
		string.format("first spawn: the money line %.2f s after, for %.2f s", (first or 0) - at, total),
		which == "Goal" and math.abs(total - 3) < 0.15 and most2 > 0.99,
		total
	)
	look(60)
	ok("a minute on the dock: not again", which == nil)
	player:SetAttribute("Coins", 90000)
	look(10)
	ok("nor as the coins reach it", which == nil)
	w.State.Mode = "Riding"
	look(5)
	ok("nor out on a dive", which == nil)
	w.State.Mode, w.State.Fade = "Dock", 1
	w.Ride.OnClientEvent:Fire("Respawned")
	look(2)
	ok("home from it: not while the screen is black", which == nil)
	w.State.Fade = 0
	look(20)
	ok(string.format("then %.2f s of it", total), which == "Goal" and math.abs(total - 3) < 0.15, total)
	player.CharacterAdded:Fire(player.Character)
	Notes.lesson("*DIVE IN* AND CATCH A FISH")
	player:SetAttribute("Lesson", 1)
	look(20)
	ok(string.format("a new body with the lesson on: its line, %.2f s", total), which == "Carry" and math.abs(total - 3) < 0.15, total)
	Notes.lesson("RIDE YOUR *SEAHORSE* TO TRAIN")
	look(20)
	ok("the next step's words wait for a respawn", which == nil)
	Notes.lesson(nil)
	player:SetAttribute("Lesson", nil)
	look(5)
	ok("the lesson over: the money line does not jump in", which == nil)
	w.Ride.OnClientEvent:Fire("Respawned")
	Notes.carrying(true)
	w.Catch.Up = true
	look(4)
	ok("a catch home: not while it is shown", which == nil)
	w.Catch.Up = false
	look(20)
	ok("then GO TO YOUR TANK TO DEPOSIT, once", which == "Carry" and math.abs(total - 3) < 0.15, total)
	Notes.carrying(false)
	w.Ride.OnClientEvent:Fire("Respawned")
	w.pass(1.2)
	Notes.note("TANK FULL!", "x", false)
	look(20)
	ok("a note while it is up has the place: the line goes", total <= 0.3, total)
	ok("nothing warned", #w.World.warnings == 0, table.concat(w.World.warnings, "; "))
end

----------------------------------------------------------------------------------------------------------------------
print("the trees, " .. WHICH)
local SAYS = {
	lesson = "*DIVE IN* AND CATCH A FISH",
	long = "*CLAIM 12* REWARDS IN THE INDEX",
	carry = if after then "GO TO YOUR *TANK* TO DEPOSIT" else "GO TO YOUR TANK TO DEPOSIT",
	goal = "THE SUB TO LAND 2  *$26.5K / $75K*",
	gold = "*UPGRADE* YOUR SEAHORSE  *$1.2K*",
}
for _, screen in { { "pc", 1920, 1080 }, { "phone", 812, 375 } } do
	for name, words in SAYS do
		local w = open(screen[2], screen[3])
		local Notes = w.module("UI.DockNotes")
		if after then
			Notes.Start()
		end
		if name == "lesson" or name == "carry" then
			Notes.lesson(words)
		else
			Notes.goal(words)
		end
		w.pass(2)
		local root = w.Gui.playerGui.DockNotes
		write(`{WHICH}-{screen[1]}-{name}`, root, screen[2], screen[3])
		if after then
			local line = if name == "lesson" or name == "carry" then root.Root.Carry else root.Root.Goal
			local s = root.Root:FindFirstChildOfClass("UIScale").Scale
			ok(
				string.format("%s %s: %d x %d px, fits", screen[1], name, line.Size.X.Offset * s, line.Size.Y.Offset * s),
				line.Size.X.Offset * s <= screen[2] - 24
			)
		end
	end
end

-- A fish's whole tag, as Tags' own makeStack builds it
local w = open(1920, 1080)
local tagsModule = w.World.find(CLIENT .. "UI.Tags")
local source = tagsModule.Source
local opened, count = string.gsub(source, "return Tags%s*$", "Tags._make, Tags._put = makeStack, putStack\nreturn Tags\n")
assert(count == 1)
tagsModule.Source = opened
local Tags = w.module("UI.Tags")
local Kit = w.module("UI.Kit")
local lk = Tags.Looks[7]
local FISH = {
	{ "hold", "Common", "Clownfish", "80", 1 },
	{ "strong", "Uncommon", "Stingray", "104", 3 },
	{ "shark", "Epic", "Reef Shark", "540", 3 },
	{ "manta", "Epic", "Manta Ray", "184,500", 3 },
	{ "far", "Epic", "", "540", 3 },
	{ "farhold", "Common", "", "80", 1 },
	{ "locked", "Epic", "Reef Shark", "540", 3 },
}
local DANGER, HOLD = Kit.Danger, (roblox :: any).Color3.fromRGB(255, 100, 104) -- (Tags' NEED[3])
for _, f in FISH do
	local name, tier, says, number, state = f[1], f[2], f[3], f[4], f[5]
	local layer = w.Gui.make("Frame")
	layer.Size = (roblox :: any).UDim2.fromOffset(400, 140)
	layer.BackgroundTransparency = 1
	local tag = Tags._make(layer)
	tag.Frame.Visible = true
	tag.Frame.Position = (roblox :: any).UDim2.fromOffset(200, 136)
	Tags._put(tag.Stk, 1, tier, "", lk, "Normal")
	local far = says == ""
	tag.Name.Text = says
	tag.Name.Visible = not far
	if name == "locked" then
		tag.Hold.Text = "TOO STRONG!"
		tag.Hold.TextColor3 = HOLD
		tag.Hold.Visible = true
	end
	if after then
		tag.Stk.Req.set(number)
		tag.Stk.Req.state(state)
		tag.Stk.Req.word(not far)
	else
		-- (as updateAlt set them before)
		tag.Need.Text = number
		tag.Need.TextColor3 = if state == 3 then Kit.White else Kit.Good
		tag.Chip.BackgroundColor3 = if state == 3 then DANGER else Kit.Deep
		tag.Chip.BackgroundTransparency = if state == 3 then 0.04 else 1
		tag.Stk.ChipEdge.Enabled = state == 3
		tag.Stk.Req.Visible = not far
	end
	write(`{WHICH}-tag-{name}`, layer, 400, 140)
end
if after then
	-- the same at A3's full outline, to see what was taken off
	local Config = w.World.require(w.World.find("ReplicatedStorage.Shared.Config"))
	Config.ReqLine.Stroke = 1
	local layer = w.Gui.make("Frame")
	layer.Size = (roblox :: any).UDim2.fromOffset(400, 140)
	layer.BackgroundTransparency = 1
	local tag = Tags._make(layer)
	tag.Frame.Visible = true
	tag.Frame.Position = (roblox :: any).UDim2.fromOffset(200, 136)
	Tags._put(tag.Stk, 1, "Epic", "", lk, "Normal")
	tag.Name.Text = "Reef Shark"
	tag.Stk.Req.set("540")
	tag.Stk.Req.state(3)
	write("full-tag-shark", layer, 400, 140)
end
done()
