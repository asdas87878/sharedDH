-- The leaderboards' panels and frames, built offline (NULLROOM task l1): the real UI.BoardPanel, UI.Kit, UI.Shop,
-- Shared.Boards, Controllers.BoardController and Config, with the stand-ins of tools/index (a wrong property name or
-- type is an error, as in Roblox). It checks the words, the rows as they are scrolled, the "this server" label, your
-- own line, that a list is only scrolled from near, and that the row of boards is built, moved, rebuilt and taken away.
-- It cannot see them: a second argument writes the panels' trees and every style's parts for tools/boards/picture.py.
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/boards/panel_test.luau /tmp/place.rbxl [dump folder]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Gui = require("../index/gui")
local Harness = require("../index/harness")

local Vector2 = (roblox :: any).Vector2
local Vector3 = (roblox :: any).Vector3
local CFrame = (roblox :: any).CFrame

local world = Harness.open(process.args[1] or "/tmp/place.rbxl")
local dumpTo: string? = process.args[2]
local ok, done = Harness.tally()
local gui = Gui.install(world)
local player = gui.player
player.UserId = 5005
local studio = false
world.services.RunService.IsStudio = function()
	return studio
end
local serverNow = 1000
local own = rawget(gui.workspace, "_own") -- (what only a running workspace does)
own.GetServerTimeNow = function()
	return serverNow
end
own.BulkMoveTo = function(_self: any, parts: { any }, cframes: { any })
	for i, part in parts do
		part.CFrame = cframes[i]
	end
end
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
local CLIENT = "StarterPlayer.StarterPlayerScripts.Client."
world.stubs[CLIENT .. "UI.Anim"] = setmetatable({}, {
	__index = function()
		return function() end
	end,
})
local toClient = Gui.signal()
local asked = {}
local remote = {
	OnClientEvent = toClient,
	FireServer = function(_self: any, what: string)
		table.insert(asked, what)
	end,
}
world.stubs["ReplicatedStorage.Shared.Net"] = {
	Folder = {
		WaitForChild = function()
			return remote
		end,
	},
}

local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
local Boards = world.require(world.find("ReplicatedStorage.Shared.Boards"))
local Panel = world.require(world.find(CLIENT .. "UI.BoardPanel"))
local List = Config.Boards.List

----------------------------------------------------------------------------------------------------------------------
-- The parts

local counts = {}
for style = 1, 3 do
	for i, def in List do
		local parts = Boards.board(style, def.Emblem, i, i == 3)
		local low, high, back, front, left, right = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
		local bad = 0
		for _, piece in parts do
			local cf, s = piece.At, piece.Size
			if s.X <= 0 or s.Y <= 0 or s.Z <= 0 or cf ~= cf then
				bad += 1
			end
			local function reach(v: any): number
				return (math.abs(v.X) * s.X + math.abs(v.Y) * s.Y + math.abs(v.Z) * s.Z) / 2
			end
			local rx = Vector3.new(cf.RightVector.X, cf.UpVector.X, cf.LookVector.X)
			local ry = Vector3.new(cf.RightVector.Y, cf.UpVector.Y, cf.LookVector.Y)
			local rz = Vector3.new(cf.RightVector.Z, cf.UpVector.Z, cf.LookVector.Z)
			low, high = math.min(low, cf.Y - reach(ry)), math.max(high, cf.Y + reach(ry))
			if not piece.Move then
				left, right = math.min(left, cf.X - reach(rx)), math.max(right, cf.X + reach(rx))
				back, front = math.min(back, cf.Z - reach(rz)), math.max(front, cf.Z + reach(rz))
			end
		end
		counts[style .. def.Id] = #parts
		ok(
			string.format(
				"style %d %s: %d parts, x %.1f..%.1f, y %.1f..%.1f, z %.1f..%.1f",
				style,
				def.Id,
				#parts,
				left,
				right,
				low,
				high,
				back,
				front
			),
			bad == 0
				and #parts <= 145
				and low >= -0.2
				and left >= -8.6
				and right <= 8.6
				and back >= -3.2
				and front <= 3.2
		)
	end
end
ok("a style that is none is the first", Boards.style(9) == 1 and Boards.style(nil) == 1 and Boards.style(2) == 2)

----------------------------------------------------------------------------------------------------------------------
-- The words

local oxygen, collectors, earners = List[1], List[2], List[3]
ok("oxygen whole", Panel.number(oxygen, 12345) == Config.wholeNumber(12345), Panel.number(oxygen, 12345))
ok("oxygen in four figures past a million", Panel.number(oxygen, 3285999) == "3.285M", Panel.number(oxygen, 3285999))
ok("coins a second keep their tenths", Panel.number(earners, 12.3) == "$12.3", Panel.number(earners, 12.3))
ok("coins in short", Panel.number(earners, 48250) == "$48.25K", Panel.number(earners, 48250))
ok("a number past 2^53", Panel.number(earners, 2.5e16) == "$25Qa", Panel.number(earners, 2.5e16))
-- a row's number has been through the server's sums, the foot's has not: they must read the same
local Sums = world.require(world.find("ServerScriptService.Server.Lib.BoardSums"))
local function asRow(def: any, value: number): number
	return Sums.value(Sums.mark(value, def.Scale) or 0, def.Scale)
end
for value, want in
	{ [0.55] = "$0.5", [1.05] = "$1", [12.39] = "$12.3", [99.97] = "$99.9", [0.3] = "$0.3", [0.05] = "$0" }
do
	local row, foot = Panel.number(earners, asRow(earners, value)), Panel.number(earners, value)
	ok(`{value} a second is {want} in the row and at the foot`, row == want and foot == want, `{row}, {foot}`)
end
ok(
	"part of an Oxygen is cut off at the foot too",
	Panel.number(oxygen, 1234.6) == "1,234",
	Panel.number(oxygen, 1234.6)
)
ok("and does not make a million", Panel.number(oxygen, 999999.7) == "999,999", Panel.number(oxygen, 999999.7))
-- (ten tenths added up are a hair under one)
local tenths = 0
for _ = 1, 10 do
	tenths += 0.1
end
ok("a sum that is a hair under a step is that step", tenths < 1 and Panel.number(earners, tenths) == "$1", tenths)
local tried, unlike, first = 0, 0, ""
local random = 7
local function same(def: any, value: number)
	tried += 1
	local row, foot = Panel.number(def, asRow(def, value)), Panel.number(def, value)
	if row ~= foot then
		unlike += 1
		first = if first == "" then `{def.Id} {value}: {row}, {foot}` else first
	end
end
for _, def in { oxygen, collectors, earners } do
	for i = 1, 20000 do
		random = (random * 16807) % 2147483647
		same(def, i * 0.0125) -- (incomes are made of such steps)
		same(def, 10 ^ (random / 2147483647 * 20 - 1))
	end
end
ok(`row and foot read the same for {tried} numbers`, unlike == 0, `{unlike}: {first}`)

local NAMES = {
	"CoralQueen77",
	"finn_dives",
	"Bubbles",
	"NightTideRider",
	"You",
	"SaltySam",
	"Pearl_Hunter",
	"kelpy",
	"DeepBlueDani",
	"Reefer_Kid",
	"MantaMax",
	"Tidepool",
}
local function sample(values: { number }, mine: number): { any }
	local rows = {}
	for i, value in values do
		rows[i] = { Id = if i == mine then 5005 else 100 + i, Name = NAMES[i], Value = value, Rank = i }
	end
	if mine > 0 then
		rows[mine].Name = "You"
	end
	return rows
end
local SAMPLES = {
	Oxygen = sample({ 8412000, 5260000, 3285000, 940120, 612300, 455000, 210480, 98700, 64200, 41000, 22000, 9000 }, 5),
	Collectors = sample({ 412, 388, 301, 297, 240, 188, 151, 120, 96, 60, 31, 12 }, 5),
	Earners = sample({ 1250000, 968400, 512750, 301000, 188200, 97450, 48250, 21900, 8800, 2400, 512, 41.5 }, 5),
}
-- (a tie: two on the second place, and the next is fourth)
SAMPLES.Collectors[3].Value = 388
SAMPLES.Collectors[3].Rank = 2
-- names mixed, so the three boards are not the same people
for i, row in SAMPLES.Collectors do
	if row.Id ~= 5005 then
		row.Name = NAMES[(i * 5) % 12 + 1] == "You" and "Octo_Ollie" or NAMES[(i * 5) % 12 + 1]
	end
end
for i, row in SAMPLES.Earners do
	if row.Id ~= 5005 then
		row.Name = NAMES[(i * 7 + 2) % 12 + 1] == "You" and "Clam_Digger" or NAMES[(i * 7 + 2) % 12 + 1]
	end
end

local glass = gui.make("Part", gui.workspace)
local built, p = pcall(Panel.make, oxygen, glass)
ok("a panel builds", built, p)
ok("before the server has answered it waits", p.Empty.Visible and p.Empty.Text == "...")
Panel.show(p, { Global = false, Rows = {} }, 1040, 100)
ok("an empty list says so", p.Empty.Visible and string.find(p.Empty.Text, "Nobody") ~= nil)
ok("this server's list is labelled", p.PillWords.Text == "THIS SERVER")
Panel.show(p, { Global = true, Rows = SAMPLES.Oxygen }, 1040, 612300)
ok("a list of everyone is labelled", p.PillWords.Text == "ALL PLAYERS")
local function visible(): { string }
	local out = {}
	for _, l in p.Lines do
		if l.Frame.Visible then
			table.insert(out, l.Frame.Position.Y.Offset .. " " .. l.Rank.Text .. " " .. l.Name.Text)
		end
	end
	return out
end
ok("ten lines for twelve rows", #p.Lines == 10 and #visible() == 10, #visible())
ok("the canvas holds all twelve", p.List.CanvasSize.Y.Offset == 12 * 74 - 6 + 8, p.List.CanvasSize.Y.Offset)
ok("your line is ringed, and only yours", p.Lines[5].Ring.Enabled and not p.Lines[4].Ring.Enabled)
ok("your place and number are at the foot", p.OwnRank.Text == "YOU  #5" and p.OwnValue.Text == "612,300")
ok("far off it cannot be scrolled", not p.List.ScrollingEnabled and not p.Gui.Active)
Panel.near(p, true)
ok("near, it can", p.List.ScrollingEnabled and p.Gui.Active)
local faces = 0
for _, l in p.Lines do
	if string.find(l.Face.Image, "rbxthumb://type=AvatarHeadShot") then
		faces += 1
	end
end
ok("each row has a head picture", faces == 10, faces)
p.List.CanvasPosition = Vector2.new(0, 4 * 74 + 10)
local seen = {}
for _, l in p.Lines do
	if l.Frame.Visible then
		seen[l.Rank.Text] = l.Name.Text
	end
end
ok("scrolled, the last rows show", seen["12"] == "Tidepool" and seen["5"] == "You" and seen["4"] == nil)
Panel.near(p, false)
ok("walking off, it is back at its top", p.List.CanvasPosition.Y == 0)
Panel.tick(p, 1003.2)
ok("the next numbers are counted down", p.Next.Text == "new numbers in 37s", p.Next.Text)
Panel.tick(p, 1100)
ok("and late ones do not go below nothing", p.Next.Text == "new numbers on the way")
Panel.show(p, { Global = false, Rows = { SAMPLES.Oxygen[5] } }, 1040, 612300)
ok(
	"a short list is not scrolled from near either",
	(function()
		Panel.near(p, true)
		return not p.List.ScrollingEnabled
	end)()
)
p.Gui:Destroy()
local money = Panel.make(earners, glass)
Panel.show(
	money,
	{ Global = false, Rows = { { Id = 5005, Name = "You", Value = asRow(earners, 12.39), Rank = 1 } } },
	1040,
	12.39
)
ok(
	"your own row and the foot say the same on a panel",
	money.Lines[1].Value.Text == "$12.3" and money.OwnValue.Text == "$12.3",
	`{money.Lines[1].Value.Text}, {money.OwnValue.Text}`
)
money.Gui:Destroy()

----------------------------------------------------------------------------------------------------------------------
-- The row in the world

local Controller = world.require(world.find(CLIENT .. "Controllers.BoardController"))
Controller.Start()
ok("the client asks for the boards", asked[1] == "Sync")
gui.camera.CFrame = CFrame.new(3000, 8, -88)
local step = Controller.Test.step
step(1.1)
ok("no hub floor, no boards", #Controller.Test.shown() == 0)
local blockout = gui.make("Folder", gui.workspace)
blockout.Name = "ClaudeBlockout"
local dock = gui.make("Folder", blockout)
dock.Name = "Dock"
local floor = gui.make("Part", dock)
floor.Name = "HubFloor"
floor.Size = Vector3.new(344, 1, 244)
floor.CFrame = CFrame.new(3000, 0, -122)
step(1.1)
local shown = Controller.Test.shown()
ok("three boards are built (the fourth is off)", #shown == 3, #shown)
for i, want in { { 2936.26, -37.0, "Oxygen" }, { 2922, -39, "Collectors" }, { 2907.74, -41, "Earners" } } do
	local at = shown[i].Foot.Position
	ok(
		string.format("%s stands at %.2f, %.2f, %.2f", shown[i].Def.Id, at.X, at.Y, at.Z),
		shown[i].Def.Id == want[3]
			and math.abs(at.X - want[1]) < 0.02
			and at.Y == 0.5
			and math.abs(at.Z - want[2]) < 0.02
	)
	-- (the sea is +Z; the middle of the hub is +X from here)
	local face = shown[i].Foot.ZVector
	ok("and faces into the hub, a little to its middle", face.Z < -0.95 and face.X > 0.2, face)
end
ok("nothing is heard yet: this server, waiting", shown[1].Panel.Empty.Text == "...")
player:SetAttribute("BoardOxygen", 612300)
toClient:Fire("State", {
	Next = 1040,
	Boards = { { Id = "Oxygen", Global = false, Rows = SAMPLES.Oxygen } },
})
ok("what the server sent shows", shown[1].Panel.Rows == SAMPLES.Oxygen and shown[1].Panel.OwnValue.Text == "612,300")
local folder = gui.workspace:FindFirstChild("Boards")
local row = folder:FindFirstChild("Row")
local total, solids, query = 0, 0, 0
for _, d in row:GetDescendants() do
	if d:IsA("BasePart") then
		total += 1
		solids += if d.CanCollide then 1 else 0
		query += if d.CanQuery then 1 else 0
	end
end
ok("parts in the row: " .. total, total < 400)
ok("only the bed (6) and a block a board are solid", solids == 9, solids)
ok("only the three glasses answer a ray", query == 3, query)
local before = shown[1].Parts[1].CFrame
step(0.5)
ok("the emblem moves near", shown[1].Parts[1].CFrame ~= before)
gui.camera.CFrame = CFrame.new(3000, 8, 400)
step(0.5)
ok("past Hide the row is out of the world", row.Parent == nil)
gui.camera.CFrame = CFrame.new(3000, 8, -88)
step(0.5)
ok("and back", row.Parent == folder)
studio = true
gui.workspace:SetAttribute("BoardStyle", 1)
step(1.1)
ok("in Studio the style is turned live", Controller.Test.shown()[1] ~= nil and row.Parent == nil)
ok("one row only", #folder:GetChildren() == 1)
Config.Boards.On = 0
step(1.1)
ok("turned off it goes", #Controller.Test.shown() == 0 and #folder:GetChildren() == 0)
Config.Boards.On = 1
local left = 0
for _, child in gui.playerGui:GetChildren() do
	if child.ClassName == "SurfaceGui" then
		left += 1
	end
end
ok("no panel is left behind", left == 0, left)

----------------------------------------------------------------------------------------------------------------------
-- For the picture

if dumpTo then
	fs.writeDir(dumpTo)
	local function with(object: any, dump: any)
		-- (what the index's dump does not read)
		if object.ClassName == "TextLabel" then
			dump.Props.TextScaled = object.TextScaled
			local limit = object:FindFirstChildOfClass("UITextSizeConstraint")
			dump.Props.MaxTextSize = if limit then limit.MaxTextSize else 100
			dump.Props.MinTextSize = if limit then limit.MinTextSize else 1
		elseif object.ClassName == "UIStroke" then
			dump.Props.Enabled = object.Enabled
		end
		for i, child in object:GetChildren() do
			with(child, dump.Children[i])
		end
	end
	local size = Panel.canvas()
	for _, def in { oxygen, collectors, earners } do
		for _, global in { true, false } do
			local one = Panel.make(def, glass)
			local rows = SAMPLES[def.Id]
			if not global then
				rows = {}
				for i = 1, 4 do
					local from = SAMPLES[def.Id][i + 3]
					rows[i] = { Id = from.Id, Name = from.Name, Value = from.Value, Rank = i }
				end
			end
			Panel.show(one, { Global = global, Rows = rows }, 1037, SAMPLES[def.Id][5].Value)
			Panel.tick(one, 1000)
			local face = one.Gui:FindFirstChild("Face")
			local dump = Gui.dump(face)
			with(face, dump)
			fs.writeFile(
				`{dumpTo}/panel-{def.Id}-{if global then "all" else "here"}.json`,
				serde.encode("json", { View = { size.X, size.Y }, Tree = { Children = { dump } } })
			)
			one.Gui:Destroy()
		end
	end
	local out: any = { Panel = Boards.Panel, Rows = {}, Counts = counts }
	local c = Config.Boards
	local function plain(piece: any, at: any)
		return {
			shape = piece.Shape,
			size = { piece.Size.X, piece.Size.Y, piece.Size.Z },
			m = { at:GetComponents() },
			color = { piece.Color.R, piece.Color.G, piece.Color.B },
			glow = piece.Glow == true,
			clear = piece.Clear or 0,
		}
	end
	local space2 = Boards.row(floor.CFrame, floor.Size, c.X, c.Z, c.Face)
	for style = 1, 3 do
		local parts, glasses = {}, {}
		for _, piece in Boards.bed(style, 2 * c.Pitch) do
			table.insert(parts, plain(piece, space2 * piece.At))
		end
		for i, at in Boards.places(3, c.Pitch, c.Turn) do
			for _, piece in Boards.board(style, List[i].Emblem, i, i == 3) do
				table.insert(parts, plain(piece, space2 * at * piece.At))
			end
			local q = Boards.Panel
			local face = space2 * at * CFrame.new(0, q.Bottom + q.Height / 2, q.Front)
			table.insert(glasses, { id = List[i].Id, m = { face:GetComponents() } })
		end
		out.Rows[style] = { parts = parts, glasses = glasses }
	end
	local anchor = {}
	for _, piece in Boards.board(1, "Anchor", 4, true) do
		table.insert(anchor, plain(piece, piece.At))
	end
	out.Anchor = anchor
	fs.writeFile(dumpTo .. "/parts.json", serde.encode("json", out))
end

for _, line in world.warnings do
	print("  warn  " .. line)
end
done()
