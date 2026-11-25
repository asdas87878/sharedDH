--!strict
-- The endless Underworld (Config.Endless; Hugo, 2026-11-25: "i only want the last part to loop"; docs/design/endless.md).
-- The last stretch of the map, from the line z = From to the line z = To, goes on again and again, each time further by
-- one SHIFT: lap 0 is the map as it is built, lap 1 the same stretch one SHIFT on, and so on. Nothing is teleported and
-- nothing is built: a rider really is that far on (so the depth, the best, the camera, the hop, the hook and two riders
-- on different laps need nothing), and each player's own machine shows the parts it has anyway at the lap nearest its
-- camera (client/Controllers/EndlessController). The server never moves a part. Where it asks its own map something
-- about a place further on, it asks about the same place in lap 0 (Endless.fold).
-- Only sums here, the same for the server and the clients. Off (Config.Endless.On = 0) laps() is 0, and then fold gives
-- every place back as it is and lane changes nothing: today's game.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lane = require(ReplicatedStorage.Shared.Lane)

local Endless = {}

local most = 0 -- how many laps there are past lap 0 (0: off)

-- How many laps there are. The server works it out (Endless.count) and puts it on Net.Folder ("EndlessLaps"); the
-- clients read it there.
function Endless.begin(laps: number)
	most = math.max(0, math.floor(laps))
end

function Endless.laps(): number
	return most
end

-- What a place moves by from one lap to the next
function Endless.shift(): Vector3
	local e = Config.Endless
	return Vector3.new(e.ShiftX, e.ShiftY, e.To - e.From)
end

-- The lap a place is in, by how far down the map it is
function Endless.lapOf(z: number): number
	if most == 0 then
		return 0
	end
	local e = Config.Endless
	return math.clamp(math.floor((z - e.From) / (e.To - e.From)), 0, most)
end

-- A thing's place in the map (x and z) in each of the laps from 1 to `upTo`: rows like the one given, moved
function Endless.copies(row: { number }, upTo: number): { { number } }
	local e = Config.Endless
	local out = {}
	if row[2] >= e.From and row[2] < e.To then
		for lap = 1, math.min(most, upTo) do
			local copy = table.clone(row)
			copy[1] += e.ShiftX * lap
			copy[2] += (e.To - e.From) * lap
			table.insert(out, copy)
		end
	end
	return out
end

-- The same place in lap 0, where the server's own map stands, and what to add to come back from there
function Endless.fold(position: Vector3): (Vector3, Vector3)
	local lap = Endless.lapOf(position.Z)
	if lap == 0 then
		return position, Vector3.zero
	end
	local off = Endless.shift() * lap
	return position - off, off
end

-- A place in lap 0, in whichever lap puts it nearest `near` down the map
function Endless.beside(position: Vector3, near: Vector3): Vector3
	local e = Config.Endless
	if most == 0 then
		return position
	end
	local lap = math.clamp(math.floor((near.Z - position.Z) / (e.To - e.From) + 0.5), 0, most)
	return if lap == 0 then position else position + Endless.shift() * lap
end

-- The lap something standing at z in the built map is shown in, for a camera at `eye` down the map: the lap that puts it
-- nearest. `phase` and `step`: only the laps phase, phase + step, phase + 2 step and so on (a long part is shown twice,
-- by itself in the even laps and by a copy in the odd ones, so neither end of it changes near the camera).
function Endless.nearest(eye: number, z: number, phase: number, step: number): number
	local e = Config.Endless
	local length = (e.To - e.From) * step
	local last = (most - phase) // step -- (how many of those laps there are, past the first)
	if last < 0 then
		return 0
	end
	local at = math.floor((eye - z - phase * (e.To - e.From)) / length + 0.5)
	return phase + step * math.clamp(at, 0, last)
end

-- How much better than in the map itself the sizes' and the colours' odds are, for a fish `past` studs beyond where the
-- built map ends (1: the same). A hair: OddsMinute for each minute of riding at OddsPace, OddsMost in all.
function Endless.odds(past: number): number
	local e = Config.Endless
	if past <= 0 or e.OddsPace <= 0 then
		return 1
	end
	return 1 + math.min(e.OddsMinute * past / (e.OddsPace * 60), e.OddsMost)
end

-- Where the lane crosses the line z (the last time it does): the point, its width, its room and its s
local function crossing(lane: Lane.Lane, z: number): (Vector3?, number, number, number, number)
	local points = lane.Points
	for i = #points - 1, 1, -1 do
		local a, b = points[i], points[i + 1]
		if a.Z <= z and b.Z > z then
			local t = (z - a.Z) / (b.Z - a.Z)
			return a:Lerp(b, t),
				lane.Widths[i] + (lane.Widths[i + 1] - lane.Widths[i]) * t,
				lane.Clearance[i] or 0,
				lane.S[i] + (lane.S[i + 1] - lane.S[i]) * t,
				i
		end
	end
	return nil, 0, 0, 0, 0
end

-- How many laps this lane can have: none unless its end is the one the numbers were made for, and no more than end
-- `Spare` studs above `floor` (Workspace.FallenPartsDestroyHeight: whatever goes under it is gone). The second result
-- says why, when there are none.
function Endless.count(lane: Lane.Lane, floor: number): (number, string?)
	local e = Config.Endless
	if e.On == 0 then
		return 0, nil
	end
	local a, wa = crossing(lane, e.From)
	local b, wb = crossing(lane, e.To)
	if not a or not b then
		return 0, "the lane does not cross the loop's two lines"
	end
	local off = b - (a + Endless.shift())
	if math.abs(off.X) > e.Near or math.abs(off.Y) > e.Near or math.abs(wb - wa) > e.Near * 2 then
		return 0, string.format("the loop's end is %.0f, %.0f studs off its start (Near %d)", off.X, off.Y, e.Near)
	end
	local lowest = math.huge
	for _, point in lane.Points do
		if point.Z >= e.From then
			lowest = math.min(lowest, point.Y)
		end
	end
	local room = lowest - (floor + e.Spare)
	local laps = if e.ShiftY < 0 then math.floor(room / -e.ShiftY) else e.Laps
	laps = math.clamp(math.min(laps, e.Laps), 0, math.huge)
	return laps, if laps == 0 then "there is no room above the height things are destroyed at" else nil
end

-- The lane with its laps: cut off at To and carried on, the stretch again for each lap. Where a lap's start stands beside
-- the end it follows, its middle (and its width) comes over from one to the other along `Blend` studs; its floor is the
-- built one, as it is. Every zone still ends where it did, the last one at the cut. Without laps the lane comes back as
-- it was. (The server's and the clients' are the same: both make it from the same LanePath with the same laps.)
-- `upTo`: no more than this many of them (what the herd's stream is built on).
function Endless.lane(lane: Lane.Lane, upTo: number?): Lane.Lane
	local laps = math.min(most, upTo or most)
	if laps == 0 then
		return lane
	end
	local e = Config.Endless
	local a, wa, ca, sa, ia = crossing(lane, e.From)
	local b, wb, cb, sb, ib = crossing(lane, e.To)
	if not a or not b then
		return lane
	end
	local points, widths, clearance = {}, {}, {}
	for i = 1, ib do
		points[i], widths[i], clearance[i] = lane.Points[i], lane.Widths[i], lane.Clearance[i] or 0
	end
	table.insert(points, b)
	table.insert(widths, wb)
	table.insert(clearance, cb)
	-- one lap: from just after From to To, and how far its start has to come over
	local lapPoints: { Vector3 }, lapWidths: { number }, lapClear: { number } = { a }, { wa }, { ca }
	for i = ia + 1, ib do
		table.insert(lapPoints, lane.Points[i])
		table.insert(lapWidths, lane.Widths[i])
		table.insert(lapClear, lane.Clearance[i] or 0)
	end
	table.insert(lapPoints, b)
	table.insert(lapWidths, wb)
	table.insert(lapClear, cb)
	local shift = Endless.shift()
	local over = b - (a + shift)
	local wider = wb - wa
	local S = table.clone(lane.S)
	for i = ib + 1, #S do
		S[i] = nil
	end
	table.insert(S, sb)
	local n = #points
	for lap = 1, laps do
		for k = 2, #lapPoints do
			local p = lapPoints[k]
			local u = math.clamp((p.Z - e.From) / math.max(e.Blend, 1), 0, 1)
			local share = 1 - u * u * (3 - 2 * u)
			local at = p + shift * lap + Vector3.new(over.X * share, 0, over.Z * share)
			n += 1
			points[n] = at
			widths[n] = lapWidths[k] + wider * share
			clearance[n] = lapClear[k]
			S[n] = S[n - 1] + (at - points[n - 1]).Magnitude
		end
	end
	local zoneEnd = table.clone(lane.ZoneEnd)
	zoneEnd[#zoneEnd] = math.min(zoneEnd[#zoneEnd], sb)
	return {
		Points = points,
		Widths = widths,
		Clearance = clearance,
		S = S,
		Length = S[n],
		ZoneStart = lane.ZoneStart,
		ZoneEnd = zoneEnd,
	}
end

-- Whether a thing of the map standing at z (its middle down the map) belongs to the stretch that is shown again, by its
-- folder under ClaudeBlockout.Lane and its name; and whether it is past it, the map's tail, put away while the loop is
-- on. (tools/endless/loop.py says the same of the saved place's parts, and counts them.)
function Endless.belongs(folder: string, name: string, z: number): boolean
	local e = Config.Endless
	local before, after = 0, 0
	local over = e.Over[folder]
	if name == "Flag" or name == "FlagLine" or name == "FlagPost" then
		before = -e.Gate
	elseif over then
		before, after = over[1], over[2]
	end
	return z >= e.From - before and z < e.To + after
end

function Endless.tail(folder: string, name: string, z: number): boolean
	return z >= Config.Endless.To and not Endless.belongs(folder, name, z)
end

-- A part's reach down the map either side of its middle
function Endless.reach(part: BasePart): number
	local _, _, _, _, _, _, _, _, _, x, y, z = part.CFrame:GetComponents()
	local size = part.Size
	return (math.abs(x) * size.X + math.abs(y) * size.Y + math.abs(z) * size.Z) / 2
end

-- The map's things in one folder of ClaudeBlockout.Lane, as they go together: a part by itself, a model whole; with
-- each one's middle down the map and its reach either side of that. Those our own machine made (Skip) are left out.
export type Unit = { Instance: Instance, Parts: { BasePart }, Z: number, Reach: number }
Endless.Skip = "EndlessCopy"

function Endless.unit(child: Instance): Unit?
	if child:GetAttribute(Endless.Skip) then
		return nil
	end
	local parts: { BasePart } = {}
	if child:IsA("BasePart") then
		table.insert(parts, child)
	end
	for _, d in child:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		return nil
	end
	local low, high = math.huge, -math.huge
	for _, part in parts do
		local z, reach = part.Position.Z, Endless.reach(part)
		low, high = math.min(low, z - reach), math.max(high, z + reach)
	end
	return { Instance = child, Parts = parts, Z = (low + high) / 2, Reach = (high - low) / 2 }
end

return Endless
