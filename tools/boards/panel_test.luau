-- The leaderboards' panels and frames, built offline (NULLROOM task l1): the real UI.BoardPanel, UI.Kit, UI.Shop,
-- Shared.Boards, Controllers.BoardController and Config, with the stand-ins of tools/index (a wrong property name or
-- type is an error, as in Roblox). It checks the words, the rows as they are scrolled, the "this server" label, your
-- own line, that a list is only scrolled from near, that the row of boards is built, moved, rebuilt and taken away, and
-- that it is one straight wall: one plane, one post at a joint, no slit, no two faces in one plane.
-- It cannot see them: a second argument writes the panels' trees and the boards' parts for tools/boards/picture.py.
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
for _, def in List do
	local parts = Boards.board(def.Emblem)
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
		left, right = math.min(left, cf.X - reach(rx)), math.max(right, cf.X + reach(rx))
		back, front = math.min(back, cf.Z - reach(rz)), math.max(front, cf.Z + reach(rz))
	end
	counts[def.Id] = #parts
	ok(
		string.format(
			"%s: %d parts, x %.1f..%.1f, y %.1f..%.1f, z %.1f..%.1f",
			def.Id,
			#parts,
			left,
			right,
			low,
			high,
			back,
			front
		),
		-- (inside its own posts)
		bad == 0 and #parts <= 50 and low >= -0.2 and left >= -5.86 and right <= 5.86 and back >= -1.6 and front <= 1.6
	)
end
ok("an emblem that is none is a board with no sign", #Boards.board("None") < #Boards.board("Book"))

----------------------------------------------------------------------------------------------------------------------
-- One straight wall

local PITCH, WIDE = Config.Boards.Pitch, Boards.Post
-- every piece of a row of `count`, in the row's own space, the glasses too
local function wall(count: number, asked: number): { any }
	local out = {}
	for _, piece in Boards.bed(count, asked) do
		table.insert(
			out,
			{ Shape = piece.Shape, Size = piece.Size, At = piece.At, Of = "kerb", Skin = `{piece.Color} {piece.Shape}` }
		)
	end
	for _, piece in Boards.frame(count, asked) do
		table.insert(out, {
			Shape = piece.Shape,
			Size = piece.Size,
			At = piece.At,
			Of = "frame",
			Light = piece.Light,
			Skin = tostring(piece.Color),
		})
	end
	for i, at in Boards.places(count, asked) do
		for _, piece in Boards.board(List[i].Emblem) do
			table.insert(out, {
				Shape = piece.Shape,
				Size = piece.Size,
				At = at * piece.At,
				Of = "board " .. i,
				Skin = tostring(piece.Color),
			})
		end
		local q = Boards.Panel
		local glassAt = at * CFrame.new(0, q.Bottom + q.Height / 2, q.Front - 0.05)
		table.insert(out, {
			Shape = "Block",
			Size = Vector3.new(q.Width, q.Height, 0.1),
			At = glassAt,
			Of = "glass " .. i,
			Skin = "glass",
		})
	end
	return out
end
-- whether a point is inside a piece
local function inside(piece: any, point: any): boolean
	local at, s = piece.At:PointToObjectSpace(point), piece.Size
	if piece.Shape == "Ball" then
		return at.Magnitude < s.X / 2
	elseif math.abs(at.X) >= s.X / 2 then
		return false
	elseif piece.Shape == "Cylinder" then
		return at.Y * at.Y + at.Z * at.Z < s.Y * s.Y / 4
	end
	return math.abs(at.Y) < s.Y / 2 and math.abs(at.Z) < s.Z / 2
end
-- the flat faces of a piece: its middle, the way it looks, and its two other directions with their reach
local function faces(piece: any): { any }
	local s, cf = piece.Size, piece.At
	local a = { cf.RightVector, cf.UpVector, -cf.LookVector }
	local h = { s.X / 2, s.Y / 2, s.Z / 2 }
	local out = {}
	for i = 1, if piece.Shape == "Ball" then 0 elseif piece.Shape == "Cylinder" then 1 else 3 do
		local j, k = i % 3 + 1, (i + 1) % 3 + 1
		for _, side in { -1, 1 } do
			table.insert(out, {
				At = cf.Position + a[i] * h[i] * side,
				Look = a[i] * side,
				U = a[j],
				V = a[k],
				Hu = h[j],
				Hv = h[k],
				Round = piece.Shape == "Cylinder",
				Of = piece,
			})
		end
	end
	return out
end
local function onFace(face: any, point: any): boolean
	local to = point - face.At
	local u, v = to:Dot(face.U), to:Dot(face.V)
	if face.Round then
		return u * u + v * v < face.Hu * face.Hu
	end
	return math.abs(u) < face.Hu and math.abs(v) < face.Hv
end
-- how many pairs of faces of two looks (colours; the kerb's straight part has studs, its round ends none) lie in one
-- plane, look the same way and are both seen somewhere: those flicker. Two of one look are one face to the eye
local function flicker(pieces: { any }): (number, string)
	local all = {}
	for _, piece in pieces do
		for _, face in faces(piece) do
			-- (what lies on the ground is not seen from under it)
			if face.At.Y > 0.05 or face.Look.Y > -0.9 then
				table.insert(all, face)
			end
		end
	end
	local found, first = 0, ""
	for i = 1, #all do
		for j = i + 1, #all do
			local a, b = all[i], all[j]
			if
				a.Of ~= b.Of
				and a.Of.Skin ~= b.Of.Skin
				and a.Look:Dot(b.Look) > 0.9999
				and math.abs((b.At - a.At):Dot(a.Look)) < 0.004
				and (b.At - a.At).Magnitude < a.Hu + a.Hv + b.Hu + b.Hv
			then
				local small, other = a, b
				if a.Hu * a.Hv > b.Hu * b.Hv then
					small, other = b, a
				end
				local seen = false
				for u = -9, 9 do
					for v = -9, 9 do
						local point = small.At + small.U * small.Hu * u / 9.5 + small.V * small.Hv * v / 9.5
						if not seen and onFace(small, point) and onFace(other, point) then
							local out = point + a.Look * 0.006
							local hidden = false
							for _, piece in pieces do
								hidden = hidden or inside(piece, out)
							end
							seen = not hidden
						end
					end
				end
				if seen then
					found += 1
					first ..= string.format(
						" %s, %s at %.2f %.2f %.2f;",
						a.Of.Of,
						b.Of.Of,
						small.At.X,
						small.At.Y,
						small.At.Z
					)
				end
			end
		end
	end
	return found, first
end
-- how many lines straight through a row, from the front, hit nothing at all
local function slits(pieces: { any }, half: number): (number, string)
	local none, where = 0, ""
	for x = -half, half, 0.03 do
		for _, y in { 0.83, 1.2, 2.5, 2.57, 2.9, 5, 9, 14, 20, 23.9, 24.1, 24.2, 24.3, 25, 25.5, 25.6, 25.8 } do
			local hit = false
			for _, piece in pieces do
				if piece.Shape == "Block" and piece.At.UpVector.Y > 0.999 then
					local s, at = piece.Size, piece.At.Position
					hit = hit or (math.abs(x - at.X) <= s.X / 2 and math.abs(y - at.Y) <= s.Y / 2)
				end
			end
			if not hit then
				none += 1
				where = string.format("x %.2f y %.2f", x, y)
			end
		end
	end
	return none, where
end
for _, try in { { 3, PITCH }, { 3, PITCH + 1 }, { 4, PITCH } } do
	local count, asked = try[1], try[2]
	local name = `a row of {count}, {asked} apart: `
	local pieces = wall(count, asked)
	local half = (count * Boards.pitch(asked) + WIDE) / 2
	local turned, planes = 0, {}
	for _, at in Boards.places(count, asked) do
		turned += if (at.ZVector - Vector3.zAxis).Magnitude > 1e-6 or at.Y ~= 0 or at.Z ~= 0 then 1 else 0
	end
	ok(name .. "no board is turned, out of line or off the floor", turned == 0, turned)
	for _, piece in pieces do
		if string.find(piece.Of, "glass") then
			planes[string.format("%.4f", piece.At.Z)] = true
		end
	end
	local n = 0
	for _ in planes do
		n += 1
	end
	ok(name .. "the glasses lie in one plane", n == 1, n)
	local pillars, pipes, lamps, long = {}, 0, 0, 0
	for _, piece in pieces do
		local s = piece.Size
		if piece.Of == "frame" then
			lamps += if piece.Light then 1 else 0
			pipes += if piece.Shape == "Cylinder" and s.X > 15 then 1 else 0
			long += if piece.Shape == "Block" and s.X > half then 1 else 0
			if piece.Shape == "Block" and s.Y > 20 and s.X < 5 then
				table.insert(pillars, piece)
			end
		elseif string.find(piece.Of, "board") and piece.Shape == "Block" then
			-- (no board has an edge of its own out past its posts' inner sides, so none is seen)
			local at = Boards.places(count, asked)[tonumber(string.sub(piece.Of, 7)) :: number]
			local out = math.abs(piece.At.X - at.X)
				+ (math.abs(piece.At.RightVector.X) * s.X + math.abs(piece.At.UpVector.X) * s.Y) / 2
			if out > Boards.Panel.Width / 2 + 0.26 then
				turned += 1
			end
		end
	end
	ok(name .. "no board reaches past the middle of its posts", turned == 0, turned)
	ok(
		name .. "one post, one pipe and one lamp at each end and each joint",
		#pillars == count + 1 and pipes == count + 1 and lamps == count + 1,
		`{#pillars} {pipes} {lamps}`
	)
	ok(name .. "five pieces run its whole length (foot, head, their edges, the back)", long == 5, long)
	local places = Boards.places(count, asked)
	local least = math.huge
	for _, at in places do
		for _, side in { -1, 1 } do
			local x = at.X + side * (Boards.Panel.Width / 2 + 0.25)
			for _, pillar in pillars do
				if math.abs(pillar.At.X - x) < 3 then
					least = math.min(least, pillar.Size.X / 2 - math.abs(pillar.At.X - x))
				end
			end
		end
	end
	ok(
		string.format("%severy glass's brass edge ends %.2f studs in behind a post", name, least),
		least > 0.05 and least < 0.3
	)
	local bulbs = {}
	for _, piece in pieces do
		if piece.Of == "frame" and piece.Shape == "Ball" and piece.At.Y > 24 then
			table.insert(bulbs, piece.At.X)
		end
	end
	table.sort(bulbs)
	local across = {}
	for i = 2, #bulbs do
		if (i - 1) % 3 ~= 0 or (i - 1) % 6 == 0 then
			across[string.format("%.2f", bulbs[i] - bulbs[i - 1])] = true
		end
	end
	n = 0
	for _ in across do
		n += 1
	end
	ok(name .. "its small lamps stand evenly, across the joints too", n == 1 and #bulbs == count * 6, n)
	local none, where = slits(pieces, half - 0.15)
	ok(name .. "no slit anywhere along it", none == 0, `{none}: {where}`)
	if count == 3 and asked == PITCH then
		local found, first = flicker(pieces)
		ok(name .. "no two seen faces lie in one plane", found == 0, `{found}: {first}`)
		-- (the checks see what they are for: a post taken out, a bar cut in two, two faces made one)
		local cut = {}
		for _, piece in pieces do
			if not (piece.Of == "frame" and piece.Shape == "Block" and (piece.Size.Y > 20 or piece.Size.X > half)) then
				table.insert(cut, piece)
			end
		end
		ok("  (without its posts and bars there are slits)", slits(cut, half - 0.15) > 0)
		local twice = table.clone(pieces)
		table.insert(twice, {
			Shape = "Block",
			Size = Vector3.new(1, 1.3, 1.8),
			At = CFrame.new(3, 24.9, -0.1),
			Of = "odd",
			Skin = "odd",
		})
		ok("  (a piece in the head bar's plane is seen to flicker)", flicker(twice) > 0)
	end
end
ok(
	"boards cannot be set closer than one post",
	Boards.pitch(5) == Boards.least() and math.abs(Boards.least() - 12.9) < 1e-6
)

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
		rows[i] = {
			Id = if i == mine then 5005 else 100 + i,
			Name = NAMES[i],
			User = "",
			Value = value,
			Rank = i,
		}
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

for _, rows in SAMPLES do
	for _, row in rows do
		row.User = string.lower(row.Name) .. "_" .. row.Id % 100
	end
end

local glass = gui.make("Part", gui.workspace)
local built, p = pcall(Panel.make, oxygen, glass)
ok("a panel builds", built, p)
ok("before the server has answered it waits", p.Empty.Visible and p.Empty.Text == "...")
Panel.show(p, { Global = false, Rows = {} }, 1040, 100)
ok("an empty list says so", p.Empty.Visible and string.find(p.Empty.Text, "Nobody") ~= nil)
local words = {}
for _, d in p.Gui:GetDescendants() do
	if d.ClassName == "TextLabel" then
		words[d.Name] = d.Text
	end
end
ok(
	"the title is TOP over the rest, each on its own dark copy",
	words.Small == "TOP" and words.SmallDrop == "TOP" and words.Title == "OXYGEN" and words.TitleDrop == "OXYGEN"
)
ok("what it counts is under it", words.What == oxygen.Line, words.What)
local odd =
	Panel.make({ Id = "Odd", Title = "DIVERS", Line = "", Unit = "", Scale = 1, Money = 0, Emblem = "None" }, glass)
local oddWords = {}
for _, d in odd.Gui:GetDescendants() do
	oddWords[d.Name] = if d.ClassName == "TextLabel" then d.Text else d.ClassName
end
ok("a title of one word is all big, with no lines", oddWords.Title == "DIVERS" and oddWords["Line1"] == nil)
odd.Gui:Destroy()
ok("this server's list is labelled", p.Who.Text == "THIS SERVER")
Panel.show(p, { Global = true, Rows = SAMPLES.Oxygen }, 1040, 612300)
ok("a list of everyone is labelled", p.Who.Text == "ALL PLAYERS")
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
ok("the canvas holds all twelve", p.List.CanvasSize.Y.Offset == 12 * 68 - 6 + 6, p.List.CanvasSize.Y.Offset)
ok("your line is edged apart from the others", p.Lines[5].Edge.Color ~= p.Lines[4].Edge.Color)
ok("and no other one is", p.Lines[4].Edge.Color == p.Lines[6].Edge.Color)
ok("only the first place is gold", p.Lines[1].Value.TextColor3 ~= p.Lines[2].Value.TextColor3)
ok("the user name is under the name", p.Lines[1].User.Text == "@" .. SAMPLES.Oxygen[1].User, p.Lines[1].User.Text)
ok("and what is counted under the number", p.Lines[1].Unit.Text == "OXYGEN")
ok("your place and number are at the foot", p.Own.Text == "YOU  #5   612,300", p.Own.Text)
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
p.List.CanvasPosition = Vector2.new(0, 4 * 68 + 10)
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
	{ Global = false, Rows = { { Id = 5005, Name = "You", User = "you", Value = asRow(earners, 12.39), Rank = 1 } } },
	1040,
	12.39
)
ok(
	"your own row and the foot say the same on a panel",
	money.Lines[1].Value.Text == "$12.3" and money.Own.Text == "YOU  #1   $12.3",
	`{money.Lines[1].Value.Text}, {money.Own.Text}`
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
local facing = math.rad(Config.Boards.Face)
for i, name in { "Oxygen", "Collectors", "Earners" } do
	local at = shown[i].Foot.Position
	local along = (i - 2) * PITCH
	local want = {
		3000 + Config.Boards.X + along * math.cos(facing),
		-Config.Boards.Z - along * math.sin(facing),
		name,
	}
	ok(
		string.format("%s stands at %.2f, %.2f, %.2f", shown[i].Def.Id, at.X, at.Y, at.Z),
		shown[i].Def.Id == want[3]
			and math.abs(at.X - want[1]) < 0.02
			and at.Y == 0.5
			and math.abs(at.Z - want[2]) < 0.02
	)
	-- (the sea is +Z; the middle of the hub is +X from here)
	local face = shown[i].Foot.ZVector
	local want2 = Vector3.new(math.sin(facing), 0, math.cos(facing))
	ok("and faces into the hub, exactly the way the row does", face.Z < -0.95 and (face - want2).Magnitude < 1e-5, face)
	ok("and as every other board does", (face - shown[1].Foot.ZVector).Magnitude < 1e-5)
end
ok("nothing is heard yet: this server, waiting", shown[1].Panel.Empty.Text == "...")
player:SetAttribute("BoardOxygen", 612300)
toClient:Fire("State", {
	Next = 1040,
	Boards = { { Id = "Oxygen", Global = false, Rows = SAMPLES.Oxygen } },
})
ok(
	"what the server sent shows",
	shown[1].Panel.Rows == SAMPLES.Oxygen and shown[1].Panel.Own.Text == "YOU  #5   612,300"
)
local folder = gui.workspace:FindFirstChild("Boards")
local row = folder:FindFirstChild("Row")
local total, solids, query = 0, 0, 0
local balls, drawn, lights = 0, 0, 0
for _, def in List do
	for _, piece in if def.On ~= 0 then Boards.board(def.Emblem) else {} do
		drawn += if piece.Shape == "Ball" then 1 else 0
	end
end
for _, piece in Boards.frame(3, PITCH) do
	drawn += if piece.Shape == "Ball" then 1 else 0
end
for _, d in row:GetDescendants() do
	if d:IsA("BasePart") then
		total += 1
		solids += if d.CanCollide then 1 else 0
		query += if d.CanQuery then 1 else 0
		balls += if string.find(tostring(d.Shape), "Ball") then 1 else 0
	elseif d:IsA("PointLight") then
		lights += 1
	end
end
ok("parts in the row: " .. total, total < 270)
ok(`its {drawn} round pieces are built round`, balls == drawn and drawn > 0, balls)
ok("a light on each of the four posts", lights == 4, lights)
ok("only the bed (6) and a block a board are solid", solids == 9, solids)
ok("only the three glasses answer a ray", query == 3, query)
gui.camera.CFrame = CFrame.new(3000, 8, 400)
step(0.5)
ok("past Hide the row is out of the world", row.Parent == nil)
gui.camera.CFrame = CFrame.new(3000, 8, -88)
step(0.5)
ok("and back", row.Parent == folder)
Config.Boards.Pitch += 1
step(1.1)
ok("a number changed while playing makes the row again", Controller.Test.shown()[1] ~= nil and row.Parent == nil)
Config.Boards.Pitch -= 1
step(1.1)
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
					rows[i] = { Id = from.Id, Name = from.Name, User = from.User, Value = from.Value, Rank = i }
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
			clear = 0,
		}
	end
	local space2 = Boards.row(floor.CFrame, floor.Size, c.X, c.Z, c.Face)
	local parts, glasses = {}, {}
	out.Face = c.Face
	for _, piece in Boards.bed(3, c.Pitch) do
		table.insert(parts, plain(piece, space2 * piece.At))
	end
	for _, piece in Boards.frame(3, c.Pitch) do
		table.insert(parts, plain(piece, space2 * piece.At))
	end
	for i, at in Boards.places(3, c.Pitch) do
		for _, piece in Boards.board(List[i].Emblem) do
			table.insert(parts, plain(piece, space2 * at * piece.At))
		end
		local q = Boards.Panel
		local face = space2 * at * CFrame.new(0, q.Bottom + q.Height / 2, q.Front)
		table.insert(glasses, { id = List[i].Id, m = { face:GetComponents() } })
	end
	out.Rows[1] = { parts = parts, glasses = glasses }
	fs.writeFile(dumpTo .. "/parts.json", serde.encode("json", out))
end

for _, line in world.warnings do
	print("  warn  " .. line)
end
done()
