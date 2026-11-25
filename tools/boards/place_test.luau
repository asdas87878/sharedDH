-- Whether the leaderboards' spot (Config.Boards) is free in a saved place, offline (NULLROOM task l1): every piece of
-- every style, as Shared/Boards draws it and BoardController puts it, against the place's own parts. Touching a part is
-- a fail, the floor and what the boards stand in place of (Boards.Replaces) apart; and how far it is to the stalls'
-- rings, the strip, the gate's lamp, the pens and the spawn is printed.
-- usage: rojo build -o /tmp/place.rbxl && lune run tools/boards/place_test.luau /tmp/place.rbxl <saved place.rbxl>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Harness = require("../index/harness")

local CFrame = (roblox :: any).CFrame
local Vector3 = (roblox :: any).Vector3

local world = Harness.open(process.args[1])
local ok, done = Harness.tally()
local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
local Boards = world.require(world.find("ReplicatedStorage.Shared.Boards"))
local saved = roblox.deserializePlace(fs.readFile(process.args[2]))
local dock = saved:GetService("Workspace").ClaudeBlockout.Dock
local floor = dock:FindFirstChild("HubFloor", true)
local c = Config.Boards

type Box = { Name: string, At: any, Half: any, X: number?, Y: number?, Z: number?, R: number? }
-- a box with its middle and reach as plain numbers (most pairs are told apart by those alone)
local function ball(box: Box): Box
	local p = box.At.Position
	box.X, box.Y, box.Z, box.R = p.X, p.Y, p.Z, box.Half.Magnitude
	return box
end
local function axes(cf: any): { any }
	return { cf.RightVector, cf.UpVector, -cf.LookVector }
end
local function half(box: Box, along: any): number
	local a = axes(box.At)
	return box.Half.X * math.abs(a[1]:Dot(along))
		+ box.Half.Y * math.abs(a[2]:Dot(along))
		+ box.Half.Z * math.abs(a[3]:Dot(along))
end
-- how deep two boxes are in each other (separating axes); below 0: apart by at least that
local function depth(a: Box, b: Box): number
	local to = b.At.Position - a.At.Position
	local least = math.huge
	local function try(axis: any)
		if axis.Magnitude > 1e-4 then
			local u = axis.Unit
			least = math.min(least, half(a, u) + half(b, u) - math.abs(to:Dot(u)))
		end
	end
	local x, y = axes(a.At), axes(b.At)
	for i = 1, 3 do
		try(x[i])
		try(y[i])
		for j = 1, 3 do
			try(x[i]:Cross(y[j]))
		end
	end
	return least
end

local row = Boards.row(floor.CFrame, floor.Size, c.X, c.Z, c.Face)
local near: { Box } = {}
local replaced: { Box } = {}
for _, part in saved:GetService("Workspace").ClaudeBlockout:GetDescendants() do
	if part:IsA("BasePart") and part ~= floor then
		local far = (part.CFrame.Position - row.Position).Magnitude
		-- (an unseen part is a barrier or a trigger: it counts when it is solid)
		if far - part.Size.Magnitude / 2 < 60 and (part.Transparency < 1 or part.CanCollide) then
			local name = string.gsub(part:GetFullName(), "^Workspace%.ClaudeBlockout%.", "")
			local box = ball({ Name = name, At = part.CFrame, Half = part.Size / 2 })
			local old = false
			for _, station in c.Replaces do
				old = old or string.find(name, "Dock.Stations." .. station, 1, true) == 1
			end
			table.insert(if old then replaced else near, box)
		end
	end
end
ok("the old slate is there to be replaced: " .. #replaced .. " parts", #replaced > 0)

local defs = {}
for _, def in c.List do
	if def.On ~= 0 then
		table.insert(defs, def)
	end
end
local function boxes(style: number): { Box }
	local out = {}
	for _, piece in Boards.bed(style, (#defs - 1) * c.Pitch) do
		table.insert(out, { Name = "bed", At = row * piece.At, Half = piece.Size / 2 })
	end
	for i, at in Boards.places(#defs, c.Pitch, c.Turn) do
		for _, piece in Boards.board(style, defs[i].Emblem, i, i == #defs) do
			table.insert(out, { Name = defs[i].Id .. " " .. piece.Shape, At = row * at * piece.At, Half = piece.Size / 2 })
		end
	end
	return out
end
local low, high = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
for style = 1, 3 do
	local hits = {}
	for _, mine in boxes(style) do
		ball(mine)
		local corner = Vector3.new(half(mine, Vector3.xAxis), half(mine, Vector3.yAxis), half(mine, Vector3.zAxis))
		low, high = low:Min(mine.At.Position - corner), high:Max(mine.At.Position + corner)
		for _, theirs in near do
			local dx, dy, dz = mine.X - theirs.X, mine.Y - theirs.Y, mine.Z - theirs.Z
			local reach = mine.R + theirs.R
			if dx * dx + dy * dy + dz * dz > reach * reach then
				continue
			end
			local deep = depth(mine, theirs)
			-- (what stands on the floor's own top only touches it)
			if deep > 0.02 then
				hits[theirs.Name] = math.max(hits[theirs.Name] or 0, deep)
			end
		end
	end
	local said = {}
	for name, deep in hits do
		table.insert(said, string.format("%s %.2f", name, deep))
	end
	ok("style " .. style .. " touches nothing in the place", #said == 0, table.concat(said, ", "))
end
print(string.format("  the row: x %.1f..%.1f, y %.1f..%.1f, z %.1f..%.1f", low.X, high.X, low.Y, high.Y, low.Z, high.Z))

-- on the ground: how far from the row's solid pieces to what players use
local solids = {}
for _, piece in Boards.bed(1, (#defs - 1) * c.Pitch) do
	table.insert(solids, { Name = "bed", At = row * piece.At, Half = piece.Size / 2 })
end
local function apart(part: any): number
	local box = { Name = "", At = part.CFrame, Half = part.Size / 2 }
	local best = math.huge
	for _, mine in solids do
		-- (flat on the ground: both made tall, so only the plan counts)
		local a = { Name = "", At = mine.At, Half = Vector3.new(mine.Half.X, 500, mine.Half.Z) }
		if math.abs(mine.At.UpVector.Y) < 0.5 then -- (a cylinder on its end)
			a = { Name = "", At = mine.At, Half = Vector3.new(500, mine.Half.Y, mine.Half.Z) }
		end
		best = math.min(best, -depth(a, box))
	end
	return best
end
local wanted: { { any } } = {
	{ "DockSpawn", 40 },
	{ "Stations.Sell.Ring", 30 },
	{ "Stations.Auras.Ring", 30 },
	{ "Stations.Index.Ring", 30 },
	{ "Stations.Fuse.Ring", 30 },
	{ "Stations.Sub.Ring", 30 },
}
for _, want in wanted do
	local at: any = dock
	for part in string.gmatch(want[1], "[^%.]+") do
		at = at and at:FindFirstChild(part)
	end
	if at and at:IsA("BasePart") then
		local d = apart(at)
		ok(string.format("%s is at least %.1f studs off", want[1], d), d >= want[2])
	else
		print("  --    " .. want[1] .. " is not in this place")
	end
end
-- the pens' own pieces: a walkway is left, or there was none to leave
for _, plot in dock.Plots:GetChildren() do
	local best, name = math.huge, ""
	for _, part in plot:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide and part.Transparency < 1 and (part.CFrame.Position - row.Position).Magnitude < 70 then
			local d = apart(part)
			if d < best then
				best, name = d, part.Name
			end
		end
	end
	if best < 40 then
		ok(string.format("%s: its nearest solid piece (%s) is %.1f studs off", plot.Name, name, best), best >= 0.8)
	end
end
done()
