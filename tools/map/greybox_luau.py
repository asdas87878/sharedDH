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
    Lane/Barrier                           unseen solid panels just behind every wall's face, from under the floor to
                                           over the surface: they keep swimmers and fish in the lane
    Dock                                   the hub: floor, walls, stalls, and DockSpawn (facing the start)
    Dock/Plots/Plot1 ... Plot8             a Model per player's plot: TankWater, TankBase, SignBoard, TrainerSpot,
                                           TrainerRide, CollectPad, Pad
  The pictures: the floor's tiles take art/map/textures.json's "floor" on top (squares and studs), every other piece of
  ground takes "stud" on top, and wall faces take "stud" on the side that faces the lane. With no ids in that file
  (nothing uploaded yet) the map is built plain.
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
FOLDERS = ["Surface", "Lane/Seabed", "Lane/Ground", "Lane/Walls", "Lane/Far", "Lane/Props", "Lane/Trim", "Dock", "Dock/Plots", "Lane/Barrier"]
TEXTURES = {"stud": "", "floor": "", "tile": ""}  # asset ids, once uploaded: "rbxassetid://..."
if os.path.exists(os.path.join(ROOT, "art", "map", "textures.json")):
    TEXTURES.update(json.load(open(os.path.join(ROOT, "art", "map", "textures.json"))))
# where the one picture ("tile": squares of 8 with 8 round studs across each, 16 studs to a tile) goes on a part:
# 1 on top; 3 on the side that faces the lane; 4 on both (a grass slab: its top and its front edge)
PICTURE = {"ground": 1, "plain": 1, "hub": 1, "face": 3, "grass": 4}
# each built land: the name the game shows, the depth its gauge starts at, and v4's look for it (not read by code yet)
def look(fog, far, ambient, outdoor, bright, tint, glow=None):
    out = {"Fog": fog, "FogEnd": far, "Ambient": ambient, "Outdoor": outdoor, "Brightness": bright, "Tint": tint}
    if glow:
        out["Glow"] = glow
    return out


LANDS = [("SHALLOWS", 0, look([64, 200, 205], 1000, [110, 170, 170], [130, 195, 195], 2, [235, 255, 250])),
         ("CORAL REEF", 10, look([40, 170, 200], 900, [90, 150, 165], [110, 175, 190], 1.8, [230, 250, 255])),
         ("KELP FOREST", 40, look([50, 140, 110], 550, [70, 120, 90], [90, 140, 105], 1.4, [225, 255, 215], [255, 230, 107])),
         ("SHIPWRECKS", 80, look([35, 105, 120], 500, [55, 95, 105], [70, 110, 120], 1.1, [215, 240, 240])),
         ("OPEN BLUE", 150, look([20, 85, 170], 750, [45, 80, 140], [55, 95, 160], 1, [210, 230, 255])),
         ("TWILIGHT", 200, look([20, 30, 95], 420, [35, 40, 100], [40, 45, 110], 0.5, [200, 210, 255], [95, 240, 224])),
         ("MIDNIGHT", 1000, look([6, 10, 35], 300, [20, 25, 60], [20, 25, 60], 0.15, [180, 200, 255], [95, 240, 224])),
         ("VENTS", 2000, look([30, 14, 18], 300, [60, 30, 30], [50, 25, 25], 0.1, [255, 215, 195], [255, 138, 61])),
         ("BONE GRAVEYARD", 4000, look([14, 22, 36], 320, [40, 45, 70], [35, 40, 60], 0.1, [225, 215, 255], [255, 111, 216])),
         ("THE UNDERWORLD", 6000, look([28, 4, 8], 250, [60, 15, 20], [50, 10, 15], 0.05, [255, 200, 200], [255, 58, 42]))]

parts = json.load(open(os.path.join(BOX, "parts.json")))["parts"]
info = json.load(open(os.path.join(BOX, "path.json")))


def where(p):
    """the folder a part goes in, and its Model's name if it is a brick of an asset"""
    n, k = p["n"], p["k"]
    if k == "water":
        return 0, None
    if k == "barrier":
        return 9, None  # unseen and solid: what keeps swimmers and fish in the lane
    if k == "figure":
        return None, None  # the scale figures stay out of Studio
    if n.startswith("Plot"):
        return 8, n.split("_", 1)[0]
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
    if k in ("ground", "plain", "grass"):
        return 2, None
    if k in ("face", "core"):
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
    model = (folder, model) if model else None
    ax, ay = p["x"], p["y"]
    if p["n"] == "DockSpawn":
        ax, ay = [-1, 0, 0], [0, 1, 0]  # so the spawn looks down the lane, at the start
    flags = (1 if p["solid"] else 0) + (0 if p["k"] in ("trim", "water", "barrier", "ground", "hub", "core") else 2) + (4 if p["k"] == "water" else 0)
    colour = p["c"][0] * 65536 + p["c"][1] * 256 + p["c"][2]
    rows.append([folder, names.setdefault(name, len(names)), models.setdefault(model, len(models)) if model else -1, colour, flags]
                + [round(p["p"][i] + ORIGIN[i], 2) for i in range(3)] + [max(0.05, v) for v in p["s"]] + [round(v, 4) for v in ax + ay]
                + [PICTURE.get(p["k"], 0), p.get("t", 0), p.get("v", 0)])
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
-- Generated by tools/map/greybox_luau.py from art/map/greybox: do not edit by hand. Grey-box 9 of the map
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
root:SetAttribute("Build", "greybox 9")
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
assert(root and root:GetAttribute("Build") == "greybox 9", "run 00_start.luau first")
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
local TILE = "{TILE}" -- the one picture: squares of 8 with round studs, 16 studs to a tile; "" builds without it
local function picture(part, face, slide)
	if TILE ~= "" then
		local t = Instance.new("Texture")
		t.Texture = TILE
		t.Face = face
		t.StudsPerTileU = 16
		t.StudsPerTileV = 16
		t.OffsetStudsV = slide or 0 -- slid so rows of squares sit on the same heights all along a wall
		t.Parent = part
	end
end
local made = 0
-- a row: folder, name, model, colour, flags (1 solid, 2 casts a shadow, 4 water), position, size, the box's X and Y axes
for _, r in HttpService:JSONDecode([==[{ROWS}]==]) do
	local parent = folderAt(FOLDERS[r[1] + 1])
	if r[3] >= 0 then
		local key = MODELS[r[3] + 1]
		local model = parent:FindFirstChild(key)
		if not model then
			model = Instance.new("Model")
			model.Name = key
			if r[1] == 5 then
				model:SetAttribute("PropName", (string.gsub(key, "_%d+$", "")))
			end
			model.Parent = parent
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
	elseif r[19] > 0 then
		p.Transparency = r[19]
	end
	p.Size = Vector3.new(r[9], r[10], r[11])
	p.CFrame = CFrame.fromMatrix(Vector3.new(r[6], r[7], r[8]), Vector3.new(r[12], r[13], r[14]), Vector3.new(r[15], r[16], r[17]))
	if r[18] == 1 or r[18] == 4 then
		picture(p, Enum.NormalId.Top)
	end
	if r[18] == 3 or r[18] == 4 then
		picture(p, Enum.NormalId.Left, r[20]) -- a wall's X axis points away from the lane, so Left faces it
	end
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
local pictures = 0
for _, d in root:GetDescendants() do
	if d:IsA("Texture") then
		pictures += 1
	end
end
local spawn = root.Dock:FindFirstChild("DockSpawn")
return string.format(
	"greybox 9 in Studio: %d parts (expected {EXPECT}), %d solid; %s; %d Seabed boxes; %d asset models; %d plots; %d pictures; DockSpawn %s; Path %s; fallen-parts height %d",
	count, solid, table.concat(lines, ", "), #seabed, #root.Lane.Props:GetChildren(), #root.Dock.Plots:GetChildren(), pictures, if spawn then "present" else "MISSING",
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
model_list = [m[1] for m, _ in sorted(models.items(), key=lambda kv: kv[1])]
for k in range(files):
    chunk = rows[k * PER_FILE:(k + 1) * PER_FILE]
    used_models = sorted({r[2] for r in chunk if r[2] >= 0})
    remap = {m: i for i, m in enumerate(used_models)}
    chunk = [r[:2] + [remap.get(r[2], -1)] + r[3:] for r in chunk]
    open(os.path.join(OUT, f"{k + 1:02d}_parts.luau"), "w", encoding="utf-8", newline="\n").write(
        PARTS.replace("{what}", f"Parts, file {k + 1} of {files}.").replace("{FOLDERS}", lua_list(FOLDERS)).replace("{NAMES}", lua_list(name_list))
        .replace("{MODELS}", lua_list([model_list[m] for m in used_models])).replace("{ROWS}", json.dumps(chunk, **compact))
        .replace("{TILE}", TEXTURES["tile"])
        .replace("{LABEL}", f"parts file {k + 1} of {files}"))
open(os.path.join(OUT, "99_check.luau"), "w", encoding="utf-8", newline="\n").write(
    CHECK.replace("{what}", "Last: counts what was built.").replace("{EXPECT}", str(len(rows) + len(zones))).replace("{{}}", "{}"))
sizes = [os.path.getsize(os.path.join(OUT, f)) for f in sorted(os.listdir(OUT))]
print(len(rows), "parts in", files, "files;", len(model_list), "asset models;", len(zones), "lands;", "largest file", max(sizes) // 1024, "KB; all", sum(sizes) // 1024, "KB")
