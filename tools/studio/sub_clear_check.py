"""How near the submarine comes to the gate, the dock and the rest of the map as it picks the player up, measured in a
playtest (task c1, 2026-11-25; "the gate's posts and the pick-up", docs/design/sub-creature-options.md). Numbers only: it
never sets the camera. IT WALKS THE PLAYER OFF THE DOCK AND SENDS THEM ON TRIPS: run it only in a playtest you started
yourself, with nobody playing in it. It stands on fish_sub_check (its helpers, its walk, its readings).
    (needs numpy: on Hugo's PC ~/.cache/sharedDH-venv/bin/python)
    python tools/studio/sub_clear_check.py install            (in Edit, before Play; fish_sub_check's helpers too)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/sub_clear_check.py run [tier,fish,size,side ...]   (in the playtest; no list: LIST below)
    node ~/Projects/studio-runner/studio-run.mjs stop
    python tools/studio/sub_clear_check.py remove             (in Edit, after the stop)
    python tools/studio/sub_clear_check.py sums               (the numbers again, from work/subclear/*.json)
How: a LocalScript writes down our own sub's frame, the camera and the rider on every render frame from the trip's start
to 1.5 s into the run, and every part of the map (workspace.ClaudeBlockout) that can be seen and stands within 60 studs of
that way. The sums are made here: the sub's own mesh (art/subs/<Id>/<Id>.glb, sampled every stud or closer) against each
part's box. A wedge's or a mesh part's box is bigger than the part, so for those the number is a floor. Under 0: inside,
but a thin part (a wall, a post) can't read deeper than half its thickness, so for those `past` is given too: how far past
the face on the sub's own side the sub reaches. Also how much of the rider the sub hides from the camera: six points of the
body, through the sub's real triangles.
The kelp (soft, nobody touches it) and the water's layers are counted apart. Log: work/subclear/check.log.
"""
import json
import math
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fish_sub_check as fs  # noqa: E402

sc, s2 = fs.sc, fs.sc.s2
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/subs"))
import card_fit  # noqa: E402
import escort_hulls  # noqa: E402

OUT = ROOT / "work/subclear"
OUT.mkdir(parents=True, exist_ok=True)
# tier, fish ("-": none, on foot), size, studs right of the lip's middle the player goes in at
LIST = [(t, f, "Normal", s) for f in ("-", "GreatWhite") for t, s in ((1, 0), (8, 0), (8, -40), (8, 40), (9, 0), (9, -40), (9, 40))]
SOFT = ("Kelp", "Seaweed", "Grass", "Bubble")

CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local report = RS:WaitForChild("ZZSubCamReport")
local Shared = RS:WaitForChild("Shared")
local SubModels = require(Shared:WaitForChild("SubModels"))
local SubTrip = require(Shared:WaitForChild("SubTrip"))
local Config = require(Shared:WaitForChild("Config"))
local rec = nil
local rest = {}
local function hullRest(tier)
	if not rest[tier] then
		local model = SubModels.build(tier)
		rest[tier] = model.PrimaryPart.CFrame
		model:Destroy()
	end
	return rest[tier]
end
local function nums(cf)
	local out = { cf:GetComponents() }
	for i, v in out do out[i] = math.floor(v * 1e4 + 0.5) / 1e4 end
	return out
end
RunService:BindToRenderStep("ZZSubClear", Enum.RenderPriority.Last.Value + 1, function()
	local r = rec
	if not r or r.done then return end
	local json = player:GetAttribute("SubTrip")
	if type(json) == "string" and not r.trip then
		r.trip, r.tier = SubTrip.decode(json), player:GetAttribute("SubEquip")
	end
	if not r.trip then return end
	local t = workspace:GetServerTimeNow() - r.trip.Start
	local _, b = SubTrip.times(r.trip)
	if t > b + 1.5 then r.done = true return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for _, m in workspace.CurrentCamera:GetChildren() do
		if m.Name == "Submarine" and m:GetAttribute("For") == player.UserId and m.PrimaryPart and root then
			local sub = m.PrimaryPart.CFrame * hullRest(r.tier):Inverse()
			local cam = workspace.CurrentCamera.CFrame.Position
			local p = root.Position
			table.insert(r.rows, { t, SubTrip.phase(r.trip, t), nums(sub), { p.X, p.Y, p.Z }, { cam.X, cam.Y, cam.Z }, m.PrimaryPart.Transparency })
		end
	end
end)
workspace:GetAttributeChangedSignal("SubClearDo"):Connect(function()
	local verb, label = string.match(tostring(workspace:GetAttribute("SubClearDo") or ""), "^(%w+)|?([^|]*)")
	local ok, said = pcall(function()
		if verb == "rec" then
			rec = { rows = {} }
			return "rec"
		elseif verb == "flush" then
			local r = rec
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			for _, row in r.rows do
				local at = Vector3.new(row[3][1], row[3][2], row[3][3])
				lo, hi = lo:Min(at), hi:Max(at)
			end
			lo -= Vector3.one * 60
			hi += Vector3.one * 60
			local parts = {}
			for _, p in workspace.ClaudeBlockout:GetDescendants() do
				if p:IsA("BasePart") and p.Transparency < 1 then
					local c, half = p.Position, Vector3.one * (p.Size.Magnitude / 2)
					local a, b = c - half, c + half
					if a.X < hi.X and b.X > lo.X and a.Y < hi.Y and b.Y > lo.Y and a.Z < hi.Z and b.Z > lo.Z then
						local shape = if p:IsA("Part") then p.Shape.Name else p.ClassName
						local s = p.Size
						table.insert(parts, { p:GetFullName(), nums(p.CFrame), { s.X, s.Y, s.Z }, shape, p.Transparency, if p.CanCollide then 1 else 0 })
					end
				end
			end
			local times = { SubTrip.times(r.trip) }
			local text = HttpService:JSONEncode({ tier = r.tier, rows = r.rows, parts = parts, times = times, surface = Config.Oxygen.SurfaceY, done = r.done == true })
			local n = 0
			for i = 1, #text, 120000 do
				n += 1
				report:FireServer("data", label .. ":clear" .. n, string.sub(text, i, i + 119999))
			end
			report:FireServer("data", label .. ":clears", tostring(n))
			return string.format("clear rows=%d parts=%d chunks=%d", #r.rows, #parts, n)
		end
		return "?"
	end)
	report:FireServer("said", tostring(said) .. " " .. tostring(ok))
end)
'''


def install(remove=False):
    out = sc.install(remove)
    return out + " / " + s2.job(f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZSubClear")
if old then old:Destroy() end
workspace:SetAttribute("SubClearDo", nil)
if {s2.lua(remove)} then return "removed" end
local c = Instance.new("LocalScript")
c.Name = "ZZSubClear"
c.Source = {s2.lua(CLIENT)}
c.Parent = sps
return "installed clear " .. #c.Source
""")


def do(c, wait):
    return s2.server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('SCClient', '') "
        f"workspace:SetAttribute('SubClearDo', {s2.lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('SCClient')")


def model_points(tier):
    """points on the sub's own surface, a stud apart or less, in the sub's frame (nose -Z)"""
    pts = set()
    for p in card_fit.glb_meshes.parts(str(ROOT / f"art/subs/{escort_hulls.IDS[tier - 1]}/{escort_hulls.IDS[tier - 1]}.glb")):
        at = [[v[i] + p["origin"][i] for i in range(3)] for v in p["positions"]]
        for tri in p["triangles"]:
            a, b, c = (at[i] for i in tri)
            n = max(1, math.ceil(max(math.dist(a, b), math.dist(a, c), math.dist(b, c))))
            for i in range(n + 1):
                for k in range(n + 1 - i):
                    u, v = i / n, k / n
                    pts.add(tuple(round(a[q] + (b[q] - a[q]) * u + (c[q] - a[q]) * v, 2) for q in range(3)))
    return np.array(sorted(pts))


def triangles(tier):
    out = []
    for p in card_fit.glb_meshes.parts(str(ROOT / f"art/subs/{escort_hulls.IDS[tier - 1]}/{escort_hulls.IDS[tier - 1]}.glb")):
        at = np.array([[v[i] + p["origin"][i] for i in range(3)] for v in p["positions"]])
        out.append(at[np.array(p["triangles"])])
    return np.concatenate(out)


def hides(a, b, tris):
    """does any triangle stand between the two points?"""
    way, e1, e2, s = b - a, tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0], a - tris[:, 0]
    h = np.cross(np.broadcast_to(way, e2.shape), e2)
    det = (e1 * h).sum(1)
    flat = np.abs(det) < 1e-9
    f = 1 / np.where(flat, 1, det)
    q = np.cross(s, e1)
    u, v, t = f * (s * h).sum(1), f * (q @ way), f * (e2 * q).sum(1)
    return bool((~flat & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0.001) & (t < 0.97)).any())


BODY = np.array([(0, 0, 0), (0, 2, 0), (0, 1, 0), (0, -1.5, 0), (-1.2, 0, 0), (1.2, 0, 0)])


def deep(d, pts):
    """the thin solid parts the sub goes into (phase, name): most past the face on its own side, from, to; and the rider
    hidden: (points, seconds) while in the swim and the pick-up"""
    tris, rows, dark, through = triangles(d["tier"]), {}, [], []
    parts = [(p[0], *frame(p[1]), np.array(p[2]) / 2) for p in d["parts"] if min(p[2]) < 4 and any(w in p[0] for w in ("Walls.Wall", "FlagPost"))]
    for t, phase, sub, root, eye, _ in d["rows"]:
        if phase not in ("Approach", "Pickup", "Ride"):
            continue
        at, turn = frame(sub)
        world = pts @ turn.T + at
        for name, c, r, half in parts:
            if np.linalg.norm(c - at) > np.linalg.norm(half) + 60:
                continue
            q = (world - c) @ r
            if not (np.abs(q) <= half).all(axis=1).any():
                continue
            k = int(np.argmin(half))
            over = [i for i in range(3) if i != k]
            side = np.sign(((at - c) @ r)[k]) or 1
            past = float((half[k] - side * q[(np.abs(q[:, over]) <= half[over]).all(axis=1), k]).max())
            row = rows.setdefault((phase, name.split(".")[-1]), [0.0, t, t])
            row[0], row[2] = max(row[0], past), t
        if phase != "Ride":
            if np.linalg.norm(world - np.array(root), axis=1).min() < 1:
                through.append(t)
            if t > 0.8:
                dark.append((sum(hides((np.array(eye) - at) @ turn, (np.array(root) + o - at) @ turn, tris) for o in BODY), t))
    said = [f"    {k[0]}: {v[0]:.1f} past the near face of {k[1]}, {v[1]:.2f} to {v[2]:.2f} s" for k, v in rows.items()]
    for least, what in ((6, "all of the rider"), (3, "half of the rider or more")):
        hid = [t for n, t in dark if n >= least]
        said.append(f"    {what} hidden by the sub, swim and pick-up: {len(hid)} frames" + (f", {hid[0]:.2f} to {hid[-1]:.2f} s" if hid else ""))
    said.append(f"    the sub within a stud of the rider's middle: {len(through)} frames" + (f", {through[0]:.2f} to {through[-1]:.2f} s" if through else ""))
    return said


def frame(n):
    return np.array(n[:3]), np.array(n[3:]).reshape(3, 3)


def sums(label):
    d = json.loads((OUT / f"{label}.json").read_text())
    pts = model_points(d["tier"])
    reach = np.abs(pts).max(axis=0)
    lines = [f"[{label}] tier {d['tier']}, {len(d['rows'])} frames, {len(d['parts'])} map parts near, pick-up {d['times'][0]:.2f} to "
             f"{d['times'][1]:.2f} s" + ("" if d["done"] else "  ! NOT DONE")]
    parts = [(p[0].replace("Workspace.ClaudeBlockout.", ""), *frame(p[1]), np.array(p[2]) / 2, p[3], p[4], p[5]) for p in d["parts"]]
    best = {}  # (phase, kind) -> part name -> (distance, t, shape, see-through, collides)
    top, cam, body = {}, {}, {}
    for t, phase, sub, root, eye, faded in d["rows"]:
        if phase not in ("Approach", "Pickup", "Ride"):
            continue
        at, turn = frame(sub)
        world = pts @ turn.T + at
        top[phase] = max(top.get(phase, -1e9), world[:, 1].max() - d["surface"])
        cam[phase] = min(cam.get(phase, (1e9, 0)), (float(np.linalg.norm(world - np.array(eye), axis=1).min()), t))
        body[phase] = min(body.get(phase, (1e9, 0)), (float(np.linalg.norm(world - np.array(root), axis=1).min()), t))
        for name, c, r, half, shape, see, solid in parts:
            # (quick: the sub's ball against the part's)
            if np.linalg.norm(c - at) > np.linalg.norm(half) + np.linalg.norm(reach) + 8:
                continue
            q = np.abs((world - c) @ r) - half
            out = np.linalg.norm(np.maximum(q, 0), axis=1) + np.minimum(q.max(axis=1), 0)
            m = float(out.min())
            last = name.split(".")[-1]
            kind = ("water" if "Surface" in name else "soft" if any(s in last for s in SOFT) else "gate" if ".Gate." in "." + name
                    else "solid" if solid else "other")
            row = best.setdefault((phase, kind), {})
            if m < row.get(name, (1e9,))[0]:
                row[name] = (m, t, shape, see, [round(float(v), 1) for v in c])
    for phase in ("Approach", "Pickup", "Ride"):
        if phase not in top:
            lines.append(f"  {phase}: no frame with our sub")
            continue
        lines.append(f"  {phase}: the sub's top {top[phase]:+.1f} over the surface; nearest to the camera {cam[phase][0]:.1f} (at {cam[phase][1]:.2f} s),"
                     f" to the rider's middle {body[phase][0]:.1f} (at {body[phase][1]:.2f} s)")
        for kind in ("gate", "solid", "other", "soft"):
            row = best.get((phase, kind), {})
            near = sorted(row.items(), key=lambda kv: kv[1][0])[:2]
            lines.append(f"    {kind}: " + ("; ".join(f"{v[0]:.1f} {n} ({v[2]}, see-through {v[3]:.2f}, at {v[4]}, {v[1]:.2f} s)" for n, v in near)
                                             or "nothing within reach"))
    return "\n".join(lines + deep(d, pts))


def note(text):
    print(text, flush=True)
    with open(OUT / "check.log", "a", encoding="utf-8") as f:
        f.write(text + "\n")


def run(rows):
    ours, said = sc.mine()
    if not ours:
        raise SystemExit("NOT OURS: " + said)
    for tier, fish, size, side in rows:
        label = f"{tier}-{fish if fish != '-' else 'foot'}-{side}"
        note(f"== {label}")
        note(do("rec", 0.3))
        good = fs.trip(tier, tier + 1, fish, size, label, side)
        note(f"{label}: fish_sub_check {'PASS' if good else 'FAIL'}")
        said = do(f"flush|{label}", 2.0)
        note(said)
        if "chunks=" not in said:
            continue
        n = int(sc.value(label + ":clears").strip().splitlines()[-1])
        text = "".join(sc.value(f"{label}:clear{i}").rstrip("\n") for i in range(1, n + 1))
        (OUT / f"{label}.json").write_text(text)
        note(sums(label))


if __name__ == "__main__":
    what, rest = sys.argv[1], sys.argv[2:]
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(True))
    elif what == "run":
        rows = [(int(a), f, z, float(s)) for a, f, z, s in (r.split(",") for r in rest)] or LIST
        run(rows)
    elif what == "sums":
        for p in sorted(OUT.glob("*.json")):
            print(sums(p.stem))
