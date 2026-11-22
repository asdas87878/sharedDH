"""The later lands' far view as real models in the hub, inside its fog (2026-11-19; the user: "could we find a way to
use the models whilst the fog doesnt fully obscure the cool stuff especailly the black hole").

The far view (tools/map/vista.py) stands 1,300 to 10,000 studs out. The hub's fog ends at 1,100 studs
(Config.Look.AirFogEnd) and the lowest graphics level draws only about 500, so none of it would show at its real
distance. Forced perspective: each part slides along its line from the spawn's eye to a distance between NEAR and
FAR, and shrinks by as much, so from the spawn it covers exactly the same piece of the view. The order front to back
is kept (the depth is squeezed, not shuffled), so what hides what is unchanged. Each colour is brightened ahead of
the fog it gets at its new distance (the hub's fog is linear from AirFogStart to AirFogEnd), so it reads as drawn.

usage: SKY=1 python tools/map/vista.py blackhole     (the far view's parts, art/map/landmark_drafts/vista/blackhole_sky)
       python tools/map/farview.py                   writes tools/studio/farview/NN.luau
       node tools/studio/run_luau.js <studio_id> tools/studio/farview/NN.luau   (each, in order: 01 clears and starts)
"""
import colorsys
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "art", "map", "landmark_drafts", "vista", "blackhole_sky", "parts.json")
OUT = os.path.join(ROOT, "tools", "studio", "farview")
ORIGIN = (3000.0, 0.0, 0.0)  # the map's coordinates -> Studio's (tools/map/greybox_luau.py)
EYE = (1.0, 10.0, -99.2)  # the spawn (-115 until the W32 hub, 2026-11-22), at a third-person camera's height (map coordinates)
NEAR, FAR = 300.0, 470.0  # where the nearest and farthest parts land: inside the fog, and inside ~500 for low graphics
FOG_START, FOG_END = 180.0, 1100.0  # Config.Look.AirFogStart/End
FOG = (205, 232, 255)  # Config.Look.AirFogR/G/B
HOLE_NEAR, HOLE_FAR = 200.0, 216.0  # the black hole, its jets and beam: nearer still, where the fog is about 3%, so its
# middle stays black (fog can't be taken off a colour darker than the fog makes it). It hangs above everything else
# in the view, so it hides nothing it shouldn't, and from the spawn it covers the same piece of the sky either way.
CHUNK = 900
# TRUE=1 (2026-11-19, after the squeezed copy sat in the first lagoon; the user: "could we just add it in so the player
# sees the silhouette and it matches up as an actual model"): every part at its real place and size, no colour lift.
# Past the fog's end Roblox draws a part as a flat shape in the fog's colour against the (unfogged) sky, so from the hub
# the far view is a silhouette that turns into the real model as you come near. Streamed as Persistent.
REAL = os.environ.get("TRUE") == "1"


def hole(p):
    """the black hole: everything high in the sky at its depth (voxels, jets, the black bars of its middle) and the
    beam (one tall, thin part)"""
    s3 = p["s"]
    flat = s3[1] < 20 and s3[2] < 20  # voxels and the middle's bars are at most 17 high and deep; the towers are tall
    return (p["p"][1] > 900 and 6500 < p["p"][2] < 7400 and flat) or (s3[1] > 3000 and s3[0] < 30)


def neon(p):
    """the far view's lights: the black hole's voxels and its jets, the beams, rifts and glowing tips (flat and bright
    in the renders, so Neon: unlit, so its black stays black); the land shapes stay lit plastic"""
    if hole(p):
        return True
    r, g, b = (c / 255 for c in p["c"])
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    s3 = p["s"]
    cube = abs(s3[0] - s3[1]) < 0.01 and abs(s3[1] - s3[2]) < 0.01
    return (cube and p["p"][1] > 900) or (s > 0.3 and v > 0.85) or (v > 0.9 and s > 0.15)


def main():
    parts = json.load(open(SOURCE))["parts"]
    dist = [math.dist(p["p"], EYE) for p in parts]
    d0, d1 = min(dist), max(dist)
    hd = [d for p, d in zip(parts, dist) if hole(p)]
    h0, h1 = min(hd), max(hd)
    rows = []
    for p, d in zip(parts, dist):
        if REAL:
            nd = d
        elif hole(p):
            nd = HOLE_NEAR + (d - h0) / (h1 - h0) * (HOLE_FAR - HOLE_NEAR)
        else:
            nd = NEAR + (d - d0) / (d1 - d0) * (FAR - NEAR)
        k = nd / d
        pos = [EYE[i] + (p["p"][i] - EYE[i]) * k + ORIGIN[i] for i in range(3)]
        size = [max(0.05, v * k) for v in p["s"]]
        glow = neon(p)
        f = min(1.0, max(0.0, (nd - FOG_START) / (FOG_END - FOG_START)))
        # Neon isn't fogged less, but it is unlit; plastic is lit by the sun, so it is lifted a little less
        lift = 0.0 if REAL else (f if glow else f * 0.8)
        c = [round(min(255, max(0, (p["c"][i] - lift * FOG[i]) / (1 - lift)))) for i in range(3)]
        rows.append([round(v, 3) for v in pos] + [round(v, 3) for v in size] + [round(v, 4) for v in p["x"] + p["y"]] + c + [1 if glow else 0])
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        os.remove(os.path.join(OUT, f))
    for n, i in enumerate(range(0, len(rows), CHUNK), 1):
        start = '''local root = workspace:FindFirstChild("FarView")
if root then root:Destroy() end
root = Instance.new("Model")
root.Name = "FarView"
root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
root:SetAttribute("Source", "tools/map/farview.py: the later lands' far view (TRUE=1: at its real place and size, a silhouette through the hub's fog; else shrunk into the fog)")
root.Parent = workspace
''' if n == 1 else 'local root = workspace:WaitForChild("FarView")\n'
        code = '''-- the far view, file %d (tools/map/farview.py)
local HttpService = game:GetService("HttpService")
%slocal rows = HttpService:JSONDecode([==[%s]==])
local holder = Instance.new("Folder")
holder.Name = "Part%d"
for _, r in rows do
	local p = Instance.new("Part")
	p.Name = if r[16] == 1 then "Glow" else "Block"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = if r[16] == 1 then Enum.Material.Neon else Enum.Material.Plastic -- Plastic, not SmoothPlastic: no sun shine (2026-11-22)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(r[4], r[5], r[6])
	p.CFrame = CFrame.fromMatrix(Vector3.new(r[1], r[2], r[3]), Vector3.new(r[7], r[8], r[9]), Vector3.new(r[10], r[11], r[12]))
	p.Color = Color3.fromRGB(r[13], r[14], r[15])
	p.Parent = holder
end
holder.Parent = root
return string.format("far view file %d: %%d parts", #rows)
''' % (n, start, json.dumps(rows[i:i + CHUNK], separators=(",", ":")), n, n)
        open(os.path.join(OUT, "%02d.luau" % n), "w", encoding="utf-8").write(code)
    print(len(rows), "parts;", sum(r[15] for r in rows), "Neon;", len(hd), "in the black hole; distance %.0f-%.0f -> %.0f-%.0f" % (d0, d1, NEAR, FAR))


if __name__ == "__main__":
    main()
