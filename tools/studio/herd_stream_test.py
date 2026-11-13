"""Checks the herd's stream against the map in the open Studio: builds src/server/Lib/Stream.luau there (the repo's file,
with the repo's Config numbers laid over the place's own, so nothing has to be synced first) and measures the lines it
makes. Run it after a new map is loaded, or after changing Stream or the Herd numbers.
It prints: how long the stream is; the band's width; how much five lines of it turn, on the flat and up and down, with
the old line (the lane's own middle) beside them; whether any line leaves the open water, comes near the real floor, or
passes through a big thing; and where one line (DIAG_U, DIAG_DODGE in the Luau below) turns most.
Good on grey-box 15 (2026-11-13): 4 to 5 degrees per 100 studs straight, 6 to 9 round the big things, worst 100 studs
under 40 degrees; 0 places over the edge, none under 4 studs above the floor.
usage: python tools/studio/herd_stream_test.py <studio_id> <Edit|Server> [Herd.Smooth=300 Spawn.BandMax=260 ...]
(Edit when Studio is not playing, Server when it is. Windows only: it uses the direct client, as run_luau.js does.)"""
import json, os, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace("\\", "/")
studio, model = sys.argv[1], sys.argv[2]
over = dict(a.split("=") for a in sys.argv[3:])
src = open(ROOT + "/src/server/Lib/Stream.luau", encoding="utf-8").read()
cfg = open(ROOT + "/src/shared/Config.luau", encoding="utf-8").read()


def numbers(block, names):
    out = {}
    body = cfg[cfg.index("Config.%s = {" % block):]
    body = body[: body.index("\n}\n")]
    for n in names:
        m = re.search(r"^\t%s = ([-0-9.]+)," % n, body, re.M)
        out[n] = m.group(1)
    return out


herd = numbers("Herd", ["SpineRoom", "Smooth", "EdgeGap", "NeckAhead", "BandSmooth", "FloorAhead", "FloorSmooth", "DodgeShare", "DodgeGap", "DodgeLength", "SmashLength", "Ahead"])
spawn = numbers("Spawn", ["LaneFill", "BandMax", "HeightMin", "HeightMax", "BigRise", "HeightFloor"])
for k, v in over.items():
    block, name = k.split(".")
    (herd if block == "Herd" else spawn)[name] = v

proxy = """
local RealConfig = require(ReplicatedStorage.Shared.Config)
local HerdOver = { %s }
local SpawnOver = { %s }
local Config = setmetatable({
	Herd = setmetatable(HerdOver, { __index = RealConfig.Herd }),
	Spawn = setmetatable(SpawnOver, { __index = RealConfig.Spawn }),
}, { __index = RealConfig })
function Config.herdHeight(own, floorY)
	local sp = Config.Spawn
	local top = RealConfig.herdTop(floorY)
	local most = sp.HeightMax + sp.BigRise
	if top >= most then return own end
	local share = math.clamp((own - sp.HeightMin) / math.max(most - sp.HeightMin, 1), 0, 1)
	return math.min(own, top * (0.8 + 0.2 * share))
end
""" % (", ".join("%s = %s" % kv for kv in herd.items()), ", ".join("%s = %s" % kv for kv in spawn.items()))

src = src.replace("--!strict\n", "")
src = src.replace("local Config = require(ReplicatedStorage.Shared.Config)\n", proxy)
src = re.sub(r"\nexport type .*?\n}\n", "\n", src, flags=re.S)
src = re.sub(r"\nexport type [^\n]*\n", "\n", src)
src = src[: src.rindex("return Stream")]

test = r"""
local Zones = require(ReplicatedStorage.Shared.Zones)
local HttpService = game:GetService("HttpService")
local zones = Zones.discover()
local pathJson
for _, d in ReplicatedStorage:GetDescendants() do
	if d:GetAttribute("LanePath") then pathJson = d:GetAttribute("LanePath") break end
end
local surveyed = pathJson ~= nil
if not pathJson then pathJson = Zones.pathJson() end
local lane = Lane.build(zones, pathJson)
local stream = Stream.build(lane, Zones.bigAssets())
local out = { (surveyed and "surveyed lane; " or "UNSURVEYED lane (the map's own Path); ") .. stream.Report }

local function stats(list)
	local lo, hi, sum = math.huge, -math.huge, 0
	for _, v in list do lo = math.min(lo, v); hi = math.max(hi, v); sum += v end
	return string.format("%.0f to %.0f, mean %.0f", lo, hi, sum / #list)
end
table.insert(out, "band, left of the middle: " .. stats(stream.HalfLeft) .. "; right: " .. stats(stream.HalfRight))
local open = {}
for k = 1, stream.Count do open[k] = stream.Right[k] - stream.Left[k] end
table.insert(out, "open water found: " .. stats(open))

-- one line of the stream walked end to end: how much it turns, on the flat and up and down
local D = 8
local function walk(point)
	local turn, worst, pitchTurn, n = 0, 0, 0, 0
	local window = {}
	local prev, prevFlat, prevPitch
	local length = 0
	local s = 0
	while s <= stream.Length do
		local p = point(s)
		if prev then
			local d = p - prev
			local flat = Vector3.new(d.X, 0, d.Z)
			if flat.Magnitude > 0.01 then
				length += flat.Magnitude
				local pitch = math.deg(math.atan2(d.Y, flat.Magnitude))
				if prevFlat then
					local a = math.deg(math.acos(math.clamp(prevFlat:Dot(flat.Unit), -1, 1)))
					turn += a
					table.insert(window, a)
					if #window > 12 then table.remove(window, 1) end
					local w = 0
					for _, v in window do w += v end
					worst = math.max(worst, w)
					pitchTurn += math.abs(pitch - prevPitch)
				end
				prevFlat, prevPitch = flat.Unit, pitch
			end
		end
		prev = p
		s += D
	end
	return turn / length * 100, worst, pitchTurn / length * 100
end
local function band(width) return math.min(width / 2 * RealConfig.Spawn.LaneFill, RealConfig.Spawn.BandMax / 2) end
table.insert(out, "turning per 100 studs on the flat (and the worst 100 studs), and up and down:")
for _, u in { -1, -0.5, 0, 0.5, 1 } do
	local oldT, oldW, oldP = walk(function(s)
		local _, _, width = Lane.at(lane, s)
		local p = Lane.point(lane, s, u * band(width), 0)
		return p + Vector3.new(0, 12, 0)
	end)
	local newT, newW, newP = walk(function(s)
		return (Stream.point(stream, s, Stream.across(stream, s, u, 0, 0, 2), 12))
	end)
	local dodT, dodW = walk(function(s)
		return (Stream.point(stream, s, Stream.across(stream, s, u, 0, 1, 2), 12))
	end)
	table.insert(out, string.format("  U %+.1f  old line %.1f (worst %.0f) pitch %.1f | stream %.2f (worst %.1f) pitch %.2f | stream round the big things %.2f (worst %.1f)", u, oldT, oldW, oldP, newT, newW, newP, dodT, dodW))
end

-- is the stream in the water? every 24 studs, on five lines: over open seabed, how far above the real floor, and
-- whether inside a big thing's circle
local params = RaycastParams.new()
params.RespectCanCollide = true
local props = workspace.ClaudeBlockout.Lane:FindFirstChild("Props")
local checked, offFloor, low, lowest, inThing, inThingStraight, overEdge = 0, 0, 0, math.huge, 0, 0, 0
local worstAt = ""
for s = 0, stream.Length, 24 do
	for _, u in { -1, -0.5, 0, 0.5, 1 } do
		local across = Stream.across(stream, s, u, 0, 1, 2)
		local p, floorY = Stream.point(stream, s, across, 8)
		checked += 1
		local from = Vector3.new(p.X, math.min(p.Y + 150, -4), p.Z)
		local real
		local reach = 400
		for _ = 1, 6 do
			local hit = workspace:Raycast(from, Vector3.new(0, -reach, 0), params)
			if not hit then break end
			if props and hit.Instance:IsDescendantOf(props) then
				reach -= (from.Y - hit.Position.Y) + 0.1
				from = hit.Position - Vector3.new(0, 0.1, 0)
			else
				real = hit
				break
			end
		end
		if not real then
			offFloor += 1
		else
			if not (real.Instance.Name == "Seabed" or real.Instance:FindFirstAncestor("Seabed")) and real.Position.Y > floorY + 6 then
				overEdge += 1
				if overEdge <= 6 then worstAt ..= string.format(" [edge s%d u%+.1f %s +%.0f]", s, u, real.Instance.Parent.Name, real.Position.Y - floorY) end
			end
			local clear = p.Y - real.Position.Y
			if clear < lowest then lowest = clear end
			if clear < 4 then
				low += 1
				if low <= 6 then worstAt ..= string.format(" [low s%d u%+.1f %.1f]", s, u, clear) end
			end
		end
		if Stream.inside(stream, s, p.X, p.Z) then inThing += 1 end
		local straight = Stream.point(stream, s, Stream.across(stream, s, u, 0, 0, 2), 8)
		if Stream.inside(stream, s, straight.X, straight.Z) then inThingStraight += 1 end
	end
end
table.insert(out, string.format("%d places checked (a fish 8 above the stream's floor): %d with no floor under them, %d over the lane's edge, %d under 4 studs above the real floor (lowest %.1f); inside a big thing's circle: %d going round, %d going straight%s", checked, offFloor, overEdge, low, lowest, inThing, inThingStraight, worstAt))
local DIAG_U, DIAG_DODGE = -1, 1
do
	local per, spots = {}, {}
	local prev, prevFlat
	for s = 0, stream.Length, 8 do
		local p = Stream.point(stream, s, Stream.across(stream, s, DIAG_U, 0, DIAG_DODGE, 2), 12)
		if prev then
			local flat = Vector3.new(p.X - prev.X, 0, p.Z - prev.Z)
			if flat.Magnitude > 0.01 then
				if prevFlat then
					local a = math.deg(math.acos(math.clamp(prevFlat:Dot(flat.Unit), -1, 1)))
					local b = math.floor(s / 3000)
					per[b] = (per[b] or 0) + a
					if a > 6 then table.insert(spots, string.format("s%d %.0fdeg", s, a)) end
				end
				prevFlat = flat.Unit
			end
		end
		prev = p
	end
	local l = {}
	for b = 0, math.floor(stream.Length / 3000) do table.insert(l, string.format("%d:%.0f", b * 3000, per[b] or 0)) end
	table.insert(out, "middle line, degrees turned per 3000 studs of lane s: " .. table.concat(l, " "))
	table.insert(out, #spots .. " corners over 6 degrees: " .. table.concat(spots, " ", 1, math.min(#spots, 40)))
	local rows = {}
	for k = 1, stream.Count, 40 do
		table.insert(rows, string.format("%d L%.0f R%.0f band -%.0f +%.0f", (k - 1) * 24, stream.Left[k], stream.Right[k], stream.HalfLeft[k], stream.HalfRight[k]))
	end
	table.insert(out, table.concat(rows, " | "))
end
return table.concat(out, "\n")
"""
code = src + test
args = os.path.join(tempfile.gettempdir(), "herd_stream_test_args.json")
json.dump({"studio_id": studio, "datamodel_type": model, "code": code}, open(args, "w"))
out = subprocess.run(["python", "C:/Users/blast/RpgGame/tools/studio/studio_mcp.py", "call", "execute_luau", "@" + args, "180"], capture_output=True, text=True, encoding="utf-8")
line = next((l for l in out.stdout.split("\n") if l.startswith('{"content"')), None)
if not line:
    print(out.stdout[-3000:], out.stderr[-2000:])
else:
    print("\n".join(c["text"] for c in json.loads(line)["content"]))
