"""Turns the grey-box (tools/map/greybox.py: art/map/greybox/parts.json and path.json) into Luau scripts that build it
in Roblox Studio, in pieces small enough for the Studio connector.

usage: python tools/map/greybox_luau.py      writes tools/studio/greybox/00_start.luau, 01_parts.luau ... and 99_check.luau
Then, by whichever chat has Studio (Edit mode), in order:
    for f in tools/studio/greybox/*.luau; do node tools/studio/run_luau.js <studio_id> "$f"; done

What it builds (the names the game code looks for are kept from blockout v4):
  Workspace.ClaudeBlockout                 rebuilt from nothing by 00_start; nothing else in the place is touched
    Surface/SeaTile                        the water's surface (the riding rays skip this folder)
    Dive                                   attributes Path (JSON rows { s, x, y, z, w, c }, world space) and Looks;
      01_SHALLOWS ... /Floor               one invisible marker per land that is built, with ZoneName and Metres
    Lane/Seabed, Ground, Walls, Far, Trim  the lane (the floor's boxes are named Seabed, in the Seabed folder)
    Lane/Props/<asset>                     one Model per asset, its bricks loose inside it (attribute PropName)
    Dock                                   the hub: floor, walls, stalls, tanks, and DockSpawn (facing the start)
  Workspace.FallenPartsDestroyHeight = -20000 (the dive goes far below Roblox's default)
The whole map sits 3,000 studs along X, off the baseplate, as v4 did. Solid things collide; flags, the start strip and
the water don't. Nothing here uploads anything."""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BOX = os.path.join(ROOT, "art", "map", "greybox")
OUT = os.path.join(ROOT, "tools", "studio", "greybox")
ORIGIN = (3000.0, 0.0, 0.0)
PER_FILE = 600
FOLDERS = ["Surface", "Lane/Seabed", "Lane/Ground", "Lane/Walls", "Lane/Far", "Lane/Props", "Lane/Trim", "Dock"]
# each built land: the name the game shows, the depth its gauge starts at, and v4's look for it (not read by code yet)
LANDS = [("SHALLOWS", 0, {"Fog": [64, 200, 205], "FogEnd": 1000, "Ambient": [110, 170, 170], "Outdoor": [130, 195, 195], "Brightness": 2, "Tint": [235, 255, 250]}),
         ("CORAL REEF", 10, {"Fog": [40, 170, 200], "FogEnd": 900, "Ambient": [90, 150, 165], "Outdoor": [110, 175, 190], "Brightness": 1.8, "Tint": [230, 250, 255]}),
         ("KELP FOREST", 40, {"Fog": [50, 140, 110], "FogEnd": 550, "Ambient": [70, 120, 90], "Outdoor": [90, 140, 105], "Brightness": 1.4, "Tint": [225, 255, 215]})]

parts = json.load(open(os.path.join(BOX, "parts.json")))["parts"]
info = json.load(open(os.path.join(BOX, "path.json")))


def where(p):
    """the folder a part goes in, and its Model's name if it is a brick of an asset"""
    n, k = p["n"], p["k"]
    if k == "water":
        return 0, None
    if k == "figure":
        return None, None  # the scale figures stay out of Studio
    if n.startswith("Hub") or k == "station" or n in ("DockSpawn", "StartStrip"):
        return 7, None
    if k == "prop":
        asset, number, _brick = n.rsplit("_", 2) if n.count("_") >= 2 else (n, "0", "")
        head = n.split("_")
        # names are "<asset>_<count>_<brick>", and an asset's own name may hold underscores
        for cut in range(len(head) - 1, 0, -1):
            if head[cut].isdigit():
                return 5, "_".join(head[:cut]) + "_" + head[cut]
        return 5, asset + "_" + number
    if n == "Seabed":
        return 1, None
    if k == "ground":
        return 2, None
    if k == "face":
        return 3, None
    if k == "far":
        return 4, None
    return 6, None


rows, names, models = [], {}, {}
for p in parts:
    folder, model = where(p)
    if folder is None:
        continue
    name = "SeaTile" if folder == 0 else (p["n"].rsplit("_", 1)[-1] if model else p["n"])
    ax, ay = p["x"], p["y"]
    if p["n"] == "DockSpawn":
        ax, ay = [-1, 0, 0], [0, 1, 0]  # so the spawn looks down the lane, at the start
    flags = (1 if p["solid"] else 0) + (0 if p["k"] in ("trim", "water") else 2) + (4 if p["k"] == "water" else 0)
    colour = p["c"][0] * 65536 + p["c"][1] * 256 + p["c"][2]
    rows.append([folder, names.setdefault(name, len(names)), models.setdefault(model, len(models)) if model else -1, colour, flags]
                + [round(p["p"][i] + ORIGIN[i], 2) for i in range(3)] + [max(0.05, v) for v in p["s"]] + [round(v, 4) for v in ax + ay])
rows.sort(key=lambda r: (r[0], r[2]))  # an asset's bricks together

path = [[r[0], round(r[1] + ORIGIN[0], 1), r[2], round(r[3] + ORIGIN[2], 1), r[4], r[5]] for r in info["Path"]]
built_to = info["BuiltTo"]
zones, looks = [], []
for i, (land, (name, metres, look)) in enumerate(zip(info["Lands"], LANDS)):
    s0 = land["S0"]
    s1 = min(built_to, info["Lands"][i + 1]["S0"]) if i + 1 < len(info["Lands"]) else built_to
    if s0 >= built_to:
        break
    inside = [r for r in path if s0 <= r[0] <= s1]
    a, b = inside[0], inside[-1]
    zones.append({"Folder": f"{i + 1:02d}_{name}", "ZoneName": name, "Metres": metres, "A": a[1:4], "B": b[1:4], "Width": round(sum(r[4] for r in inside) / len(inside), 1)})
    looks.append(dict(look, S=s0))

HEAD = '''--!nocheck
-- Generated by tools/map/greybox_luau.py from art/map/greybox: do not edit by hand. Grey-box 3 of the map
-- (docs/design/map-method.md). {what}
'''
START = HEAD + '''local HttpService = game:GetService("HttpService")
local old = workspace:FindFirstChild("ClaudeBlockout")
if old then
	old:Destroy()
end
workspace.FallenPartsDestroyHeight = -20000 -- the dive goes far below Roblox's default; only Studio can set this
local root = Instance.new("Folder")
root.Name = "ClaudeBlockout"
root:SetAttribute("Build", "greybox 3")
for _, path in {FOLDERS} do
	local at = root
	for name in string.gmatch(path, "[^/]+") do
		local nxt = at:FindFirstChild(name)
		if not nxt then
			nxt = Instance.new("Folder")
			nxt.Name = name
			nxt.Parent = at
		end
		at = nxt
	end
end
local dive = Instance.new("Folder")
dive.Name = "Dive"
dive:SetAttribute("Path", [==[{PATH}]==])
dive:SetAttribute("Looks", [==[{LOOKS}]==])
dive:SetAttribute("BigAssets", [==[{BIG}]==]) -- every big thing in the lane: world x, z and radius, for the herd
for _, zone in HttpService:JSONDecode([==[{ZONES}]==]) do
	local f = Instance.new("Folder")
	f.Name = zone.Folder
	f:SetAttribute("ZoneName", zone.ZoneName)
	f:SetAttribute("Metres", zone.Metres)
	local a, b = Vector3.new(zone.A[1], zone.A[2], zone.A[3]), Vector3.new(zone.B[1], zone.B[2], zone.B[3])
	local mid = (a + b) / 2
	local floor = Instance.new("Part") -- the marker the game reads: the straight line from the land's start to its end
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Transparency = 1
	floor.CanCollide = false
	floor.CanQuery = false
	floor.CanTouch = false
	floor.CastShadow = false
	floor.Size = Vector3.new(zone.Width, 1, (b - a).Magnitude)
	floor.CFrame = CFrame.lookAt(mid, mid - (b - a).Unit) * CFrame.new(0, -0.5, 0)
	floor.Parent = f
	f.Parent = dive
end
dive.Parent = root
root.Parent = workspace
return "ClaudeBlockout started: now run the parts files in order"
'''
PARTS = HEAD + '''local HttpService = game:GetService("HttpService")
local root = workspace:FindFirstChild("ClaudeBlockout")
assert(root and root:GetAttribute("Build") == "greybox 3", "run 00_start.luau first")
local FOLDERS = {FOLDERS}
local NAMES = {NAMES}
local MODELS = {MODELS}
local function folderAt(path)
	local at = root
	for name in string.gmatch(path, "[^/]+") do
		at = at:FindFirstChild(name)
	end
	return at
end
local props = folderAt("Lane/Props")
local made = 0
-- a row: folder, name, model, colour, flags (1 solid, 2 casts a shadow, 4 water), position, size, the box's X and Y axes
for _, r in HttpService:JSONDecode([==[{ROWS}]==]) do
	local parent = folderAt(FOLDERS[r[1] + 1])
	if r[3] >= 0 then
		local key = MODELS[r[3] + 1]
		local model = props:FindFirstChild(key)
		if not model then
			model = Instance.new("Model")
			model.Name = key
			model:SetAttribute("PropName", (string.gsub(key, "_%d+$", "")))
			model.Parent = props
		end
		parent = model
	end
	local p = Instance.new("Part")
	p.Name = NAMES[r[2] + 1]
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = Color3.fromRGB(bit32.rshift(r[4], 16), bit32.band(bit32.rshift(r[4], 8), 255), bit32.band(r[4], 255))
	p.CanCollide = bit32.band(r[5], 1) ~= 0
	p.CastShadow = bit32.band(r[5], 2) ~= 0
	if bit32.band(r[5], 4) ~= 0 then
		p.Transparency = 0.35
	end
	p.Size = Vector3.new(r[9], r[10], r[11])
	p.CFrame = CFrame.fromMatrix(Vector3.new(r[6], r[7], r[8]), Vector3.new(r[12], r[13], r[14]), Vector3.new(r[15], r[16], r[17]))
	p.Parent = parent
	made += 1
end
return string.format("{LABEL}: %d parts made", made)
'''
CHECK = HEAD + '''local root = workspace:FindFirstChild("ClaudeBlockout")
assert(root, "nothing built")
local count, solid, byFolder = 0, 0, {{}}
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
		if d.CanCollide then
			solid += 1
		end
		local top = d
		while top.Parent ~= root do
			top = top.Parent
		end
		byFolder[top.Name] = (byFolder[top.Name] or 0) + 1
	end
end
local lines = {{}}
for name, n in byFolder do
	table.insert(lines, name .. " " .. n)
end
table.sort(lines)
local seabed = root.Lane.Seabed:GetChildren()
local spawn = root.Dock:FindFirstChild("DockSpawn")
return string.format(
	"greybox 3 in Studio: %d parts (expected {EXPECT}), %d solid; %s; %d Seabed boxes; %d asset models; DockSpawn %s; Path %s; fallen-parts height %d",
	count, solid, table.concat(lines, ", "), #seabed, #root.Lane.Props:GetChildren(), if spawn then "present" else "MISSING",
	if root.Dive:GetAttribute("Path") then "present" else "MISSING", workspace.FallenPartsDestroyHeight
)
'''


def lua_list(items):
    return "{ " + ", ".join(json.dumps(v) for v in items) + " }"


os.makedirs(OUT, exist_ok=True)
for old in os.listdir(OUT):
    if old.endswith(".luau"):
        os.remove(os.path.join(OUT, old))
compact = {"separators": (",", ":")}
big = [[round(x + ORIGIN[0], 1), round(z + ORIGIN[2], 1), r] for x, z, r in info["BigWorld"]]
open(os.path.join(OUT, "00_start.luau"), "w", encoding="utf-8", newline="\n").write(
    START.replace("{what}", "Part 1: clears the old map and sets up the folders, the path and the land markers.")
    .replace("{FOLDERS}", lua_list(FOLDERS)).replace("{PATH}", json.dumps(path, **compact)).replace("{LOOKS}", json.dumps(looks, **compact))
    .replace("{BIG}", json.dumps(big, **compact)).replace("{ZONES}", json.dumps(zones, **compact)))
files = math.ceil(len(rows) / PER_FILE)
name_list = [n for n, _ in sorted(names.items(), key=lambda kv: kv[1])]
model_list = [m for m, _ in sorted(models.items(), key=lambda kv: kv[1])]
for k in range(files):
    chunk = rows[k * PER_FILE:(k + 1) * PER_FILE]
    used_models = sorted({r[2] for r in chunk if r[2] >= 0})
    remap = {m: i for i, m in enumerate(used_models)}
    chunk = [r[:2] + [remap.get(r[2], -1)] + r[3:] for r in chunk]
    open(os.path.join(OUT, f"{k + 1:02d}_parts.luau"), "w", encoding="utf-8", newline="\n").write(
        PARTS.replace("{what}", f"Parts, file {k + 1} of {files}.").replace("{FOLDERS}", lua_list(FOLDERS)).replace("{NAMES}", lua_list(name_list))
        .replace("{MODELS}", lua_list([model_list[m] for m in used_models])).replace("{ROWS}", json.dumps(chunk, **compact))
        .replace("{LABEL}", f"parts file {k + 1} of {files}"))
open(os.path.join(OUT, "99_check.luau"), "w", encoding="utf-8", newline="\n").write(
    CHECK.replace("{what}", "Last: counts what was built.").replace("{EXPECT}", str(len(rows) + len(zones))).replace("{{}}", "{}"))
sizes = [os.path.getsize(os.path.join(OUT, f)) for f in sorted(os.listdir(OUT))]
print(len(rows), "parts in", files, "files;", len(model_list), "asset models;", len(zones), "lands;", "largest file", max(sizes) // 1024, "KB; all", sum(sizes) // 1024, "KB")
