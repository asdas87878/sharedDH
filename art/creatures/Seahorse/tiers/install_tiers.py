"""Puts the seahorse trainer's 12 levels into the open Studio place, as the creatures' --local install does (no upload):
each part is written as a mesh file into Studio's content folder (rbxasset://ridefish/Trainer<n>/<Part>.mesh)
and ReplicatedStorage.TrainerModels.T<n> is a Model of MeshParts that show them, in two models:
  Toy    the seahorse and what rides with it (Body, Head, Fin, the tail T1..T6, Plate, Wings, Crown and their _Glow)
  Stand  what stays on the floor (Stand, Stand_Glow, Orbit)
The model's own space is the export's (studs, +Y up, the head toward -Z, the middle of the box at the origin; its
WorldPivot is the origin). Attributes on T<n>, in that space: Level, Title (the level's name), Foot (the middle of the
pad's underside, on the coil's axis), StandTop (y of the stand's top, where the coil starts), PlateBottom (y of the
plate's underside, where it ends), SeatAt (the seat's top, from the model's SEAT). Body carries PivotOffset at its joint.
Glowing parts are Neon. Level 12 (the rainbow) gets the creatures' rainbow rule in its vertex colours (as
tools/creatures/local_meshes.py does for a Rainbow fish), the stand and the KEEP colours left as they are; level 9's
gold is in the export already. PointLights from the model's LIGHTS.

usage: python art/creatures/Seahorse/tiers/install_tiers.py [runner|<studio_id>] [--files-only] [--only 1,12]
  (build_tiers.py --export first). The files belong to one Studio version: after Studio updates itself, run with
  --files-only again. A published game needs real uploads (asset ids) instead: not done without Hugo's word.
"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(HERE))))
sys.path.insert(0, os.path.join(ROOT, "tools", "creatures"))
import glb_meshes  # noqa: E402
import local_meshes  # noqa: E402
import rbxmesh  # noqa: E402

U = 0.4
STAND_PARTS = ("Stand", "Stand_Glow", "Orbit", "Orbit_Glow")


def content_folder():
    """STUDIO_CONTENT, else the content folder of the Studio that is running (the newest folder by date is not always
    it: 2026-11-19 the files went to an older version's folder and Studio could not fetch them), else local_meshes'"""
    if os.environ.get("STUDIO_CONTENT"):
        return os.environ["STUDIO_CONTENT"]
    try:
        ps = subprocess.run(["ps", "-eo", "args"], capture_output=True, text=True).stdout
        for line in ps.splitlines():
            first = line.split(" ")[0]
            if first.endswith("/RobloxStudioBeta.exe") and os.path.isdir(os.path.join(os.path.dirname(first), "content")):
                return os.path.join(os.path.dirname(first), "content")
    except OSError:
        pass
    return local_meshes.content_folder()


def hexrgb(h):
    return tuple(int(h.lstrip("#")[i : i + 2], 16) / 255 for i in (0, 2, 4))


def tier_rows(t, tiers):
    stem = os.path.join(HERE, "game", f"T{t}", f"SeahorseTrainer{t}")
    info = json.load(open(stem + ".mesh.json", encoding="utf-8"))
    parts = [p for p in glb_meshes.parts(stem + ".glb") if p["triangles"]]
    glow = set(info["glowParts"])
    pivots = {p["name"]: p["pivot"] for p in info["parts"]}
    row = tiers[str(t)]
    # the colours kept on the rainbow: KEEP's and their tones
    keep = {tuple(round(v * 255) for v in hexrgb(c)) for n, c in info["paletteCells"].items() if n.rstrip("+-") in row["keep"]}
    toy = [p for p in parts if p["name"] not in STAND_PARTS]
    zlo = min(p["origin"][2] + v[2] for p in toy for v in p["positions"])
    zhi = max(p["origin"][2] + v[2] for p in toy for v in p["positions"])
    length = max(zhi - zlo, 0.01)
    folder = os.path.join(content_folder(), local_meshes.FOLDER, f"Trainer{t}")
    os.makedirs(folder, exist_ok=True)
    out = []
    for p in parts:
        pos = p["positions"]
        lo = [min(v[i] for v in pos) for i in range(3)]
        hi = [max(v[i] for v in pos) for i in range(3)]
        mid = [(lo[i] + hi[i]) / 2 for i in range(3)]
        centred = [[v[i] - mid[i] for i in range(3)] for v in pos]
        path = os.path.join(folder, p["name"] + ".mesh")
        if row["rainbow"] and p["name"] not in STAND_PARTS and p["name"] not in glow:
            z0 = p["origin"][2] + mid[2]
            vs, ns, cs, ts = [], [], [], []
            for a, b, c in p["triangles"]:
                base, normal = p["colours"][a], p["normals"][a]
                kept = tuple(round(v * 255) for v in base) in keep
                for poly in local_meshes.cut([centred[a], centred[b], centred[c]], zlo - z0, length / local_meshes.SLICES):
                    start = len(vs)
                    for v in poly:
                        vs.append(v)
                        ns.append(normal)
                        cs.append(base if kept else local_meshes.rainbow(base, (z0 + v[2] - zlo) / length))
                    for k in range(1, len(poly) - 1):
                        ts.append([start, start + k, start + k + 1])
            rbxmesh.write(path, vs, ns, cs, ts)
        else:
            rbxmesh.write(path, centred, p["normals"], p["colours"], p["triangles"])
        out.append({"name": p["name"], "centre": [p["origin"][i] + mid[i] for i in range(3)],
                    "size": [max(hi[i] - lo[i], 0.01) for i in range(3)], "glow": p["name"] in glow,
                    "stand": p["name"] in STAND_PARTS, "pivot": pivots.get(p["name"])})
    # the stand's heights, from the model (trainer.py): pad z -27, base top -23 (-22 from level 4), plate z -14..-12;
    # Stand's pivot is at z -20 and Plate's at -14 (cubes)
    stand = pivots["Stand"]
    top = -22 if t >= 4 else -23
    body = pivots["Body"]  # Body's pivot is the kit's (0, 0, 3): so the kit's origin, in this space
    origin = [body[0], body[1] - 3 * U, body[2]]

    def at(x, y, z):  # the kit's (x head-ward, y right, z up) in cubes, to this space
        return [round(y * U + origin[0], 4), round(z * U + origin[1], 4), round(x * U + origin[2], 4)]

    # (part, (x, y, z) cubes, colour, watts, radius): y not 0 is a pair, as the kit makes it. Roblox's PointLight: a
    # range from the watts, soft
    lights = []
    for n, (x, y, z), c, watts, _ in row["lights"]:
        for side in ((1, -1) if y else (1,)):
            lights.append({"on": n, "at": at(x, y * side, z), "colour": c, "range": round(min(16, max(4, watts * 0.3)), 2), "bright": 1.2})
    return {
        "level": t, "title": row["name"], "parts": out,
        "foot": [stand[0], round(stand[1] - 7 * U, 4), stand[2]],
        "standTop": round(stand[1] + (top + 20) * U, 4), "plateBottom": pivots["Plate"][1],
        "seat": info["seat"], "lights": lights,
    }


LUAU = r"""
local AssetService = game:GetService("AssetService")
local rs = game:GetService("ReplicatedStorage")
local folder = rs:FindFirstChild("TrainerModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "TrainerModels"
	folder.Parent = rs
end
local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end
local report = {}
for _, tier in game:GetService("HttpService"):JSONDecode([==[__ROWS__]==]) do
	local ok, err = pcall(function()
		local model = Instance.new("Model")
		model.Name = "T" .. tier.level
		local toy = Instance.new("Model")
		toy.Name = "Toy"
		toy.Parent = model
		local stand = Instance.new("Model")
		stand.Name = "Stand"
		stand.Parent = model
		local byName = {}
		for _, b in tier.parts do
			local file = "rbxasset://__FOLDER__/Trainer" .. tier.level .. "/" .. b.name .. ".mesh"
			local p = AssetService:CreateMeshPartAsync(Content.fromUri(file), { CollisionFidelity = Enum.CollisionFidelity.Box })
			assert((p.Size - v3(b.size)).Magnitude < 0.05, b.name .. " came in at the wrong size")
			p.Name = b.name
			p.CFrame = CFrame.new(v3(b.centre))
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Color = Color3.new(1, 1, 1)
			p.Material = if b.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
			if b.pivot then
				p.PivotOffset = CFrame.new(v3(b.pivot) - v3(b.centre))
			end
			p.Parent = if b.stand then stand else toy
			byName[b.name] = p
		end
		for _, l in tier.lights do
			local on = byName[l.on] or byName.Body
			local a = Instance.new("Attachment")
			a.Name = "Light"
			a.WorldPosition = v3(l.at)
			a.Parent = on
			local light = Instance.new("PointLight")
			light.Color = Color3.fromHex(l.colour)
			light.Range = l.range
			light.Brightness = l.bright
			light.Shadows = false
			light.Parent = a
		end
		model.WorldPivot = CFrame.identity
		toy.WorldPivot = CFrame.identity
		stand.WorldPivot = CFrame.identity
		model:SetAttribute("Level", tier.level)
		model:SetAttribute("Title", tier.title)
		model:SetAttribute("Foot", v3(tier.foot))
		model:SetAttribute("StandTop", tier.standTop)
		model:SetAttribute("PlateBottom", tier.plateBottom)
		model:SetAttribute("SeatAt", v3(tier.seat))
		model:SetAttribute("Local", true)
		local old = folder:FindFirstChild(model.Name)
		if old then
			old:Destroy()
		end
		model.Parent = folder
		local _, size = model:GetBoundingBox()
		table.insert(report, string.format("T%d %s: %d parts, %.1f x %.1f x %.1f", tier.level, tier.title, #tier.parts, size.X, size.Y, size.Z))
	end)
	if not ok then
		table.insert(report, "T" .. tostring(tier.level) .. ": FAILED " .. tostring(err))
	end
	task.wait()
end
return table.concat(report, "\n")
"""


def main():
    args = sys.argv[1:]
    studio = args[0] if args and not args[0].startswith("--") else "runner"
    only = [int(v) for v in args[args.index("--only") + 1].split(",")] if "--only" in args else list(range(1, 13))
    tiers = json.load(open(os.path.join(HERE, "game", "tiers.json"), encoding="utf-8"))
    rows = [tier_rows(t, tiers) for t in only]
    print("mesh files written to", os.path.join(content_folder(), local_meshes.FOLDER), flush=True)
    if "--files-only" in args:
        return 0
    failed = 0
    for n in range(0, len(rows), 4):
        source = LUAU.replace("__ROWS__", json.dumps(rows[n : n + 4])).replace("__FOLDER__", local_meshes.FOLDER)
        path = os.path.join(tempfile.gettempdir(), "install_trainer_tiers.luau")
        open(path, "w", encoding="utf-8").write(source)
        if studio == "runner":
            command = ["node", os.path.expanduser("~/Projects/studio-runner/studio-run.mjs"), path]
        else:
            command = ["node", os.path.join(ROOT, "tools", "studio", "run_luau.js"), studio, path]
        done = subprocess.run(command, capture_output=True, text=True)
        text = (done.stdout[-3000:] or done.stderr[-2000:]).strip()
        print(text, flush=True)
        failed += 0 if done.returncode == 0 and "FAILED" not in text and "ERROR" not in text else 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
