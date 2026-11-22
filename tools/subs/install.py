"""Puts the nine submarines into the open Studio place as templates the game uses: ReplicatedStorage.SubMeshes.<Id>
(Shared/SubModels.build clones them; without a template it builds the old placeholder of plain parts).

usage: python tools/subs/install.py runner [Id ...]             (Hugo's PC, through ~/Projects/studio-runner)
       python tools/subs/install.py <studio_id> [Id ...]        (the other PC, through tools/studio/run_luau.js)

As the creatures' `install.py --local` (tools/creatures/install.py has the why): nothing is uploaded. Each part of
art/subs/<Id>/<Id>.glb (tools/blender/sub_stages.py --export) is written as a Roblox mesh file into Studio's own content
folder and the templates are MeshParts that show those files (rbxasset://ridefish/submarines/<Id>/<Part>.mesh). Such a place
shows its subs only on this PC and only while the files are there: after Studio updates itself run this again.
A published game needs real assets: upload each GLB as the creatures' were (tools/creatures/upload.py on the PC that
can), write the ids to tools/subs/assets.json ({Id: asset id}) and install from them the way the creatures' plain
install does. tools/subs/assets.json is empty until then.
"""
import glob
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "creatures"))
import glb_meshes  # noqa: E402
import local_meshes  # noqa: E402
import rbxmesh  # noqa: E402

FOLDER = local_meshes.FOLDER + "/submarines"

LUAU = r"""
local AssetService = game:GetService("AssetService")
local rs = game:GetService("ReplicatedStorage")
local folder = rs:FindFirstChild("SubMeshes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "SubMeshes"
	folder.Parent = rs
end
local report = {}
for _, row in __ROWS__ do
	local id, tier, boxes = row[1], row[2], row[3]
	local ok, err = pcall(function()
		local model = Instance.new("Model")
		model.Name = id
		for _, b in boxes do
			local file = "rbxasset://__FOLDER__/" .. id .. "/" .. b[1] .. ".mesh"
			local p = AssetService:CreateMeshPartAsync(Content.fromUri(file), { CollisionFidelity = Enum.CollisionFidelity.Box })
			assert((p.Size - Vector3.new(b[5], b[6], b[7])).Magnitude < 0.05, b[1] .. " came in at the wrong size")
			p.Name = b[1]
			p.CFrame = CFrame.new(b[2], b[3], b[4])
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Color = Color3.new(1, 1, 1)
			p.Material = if b[1] == "Light" or string.match(b[1], "_Glow$") then Enum.Material.Neon else Enum.Material.SmoothPlastic
			p.Parent = model
		end
		model.PrimaryPart = model:FindFirstChild("Hull")
		model:SetAttribute("Local", true)
		model:SetAttribute("Tier", tier)
		local old = folder:FindFirstChild(id)
		if old then
			old:Destroy()
		end
		model.Parent = folder
		local _, size = model:GetBoundingBox()
		table.insert(report, string.format("%s: %d parts, %.1f x %.1f x %.1f", id, #boxes, size.X, size.Y, size.Z))
	end)
	if not ok then
		table.insert(report, id .. ": FAILED " .. tostring(err))
	end
	task.wait()
end
return table.concat(report, "\n")
"""


def content_folder():
    """the content folder of the Studio that is running (Vinegar keeps several versions and the newest on disk isn't
    always the one open), else the creatures' own guess"""
    if not os.environ.get("STUDIO_CONTENT"):
        for cmd in glob.glob("/proc/[0-9]*/cmdline"):
            try:
                line = open(cmd, "rb").read().decode("utf-8", "replace")
            except OSError:
                continue
            at = line.find("RobloxStudioBeta.exe")
            if at > 0 and "/versions/version-" in line[:at]:
                found = os.path.join(line[:at].split("\0")[-1], "content")
                if os.path.isdir(found):
                    return found
    return local_meshes.content_folder()


def write(ids=None):
    """the mesh files; returns {Id: (tier, [{"name", "centre", "size"}])}"""
    out_root = os.path.join(content_folder(), *FOLDER.split("/"))
    found = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "art", "subs", "*", "*.glb"))):
        cid = os.path.basename(os.path.dirname(path))
        if ids and cid not in ids:
            continue
        tier = json.load(open(path[:-4] + ".mesh.json", encoding="utf-8"))["tier"]
        folder = os.path.join(out_root, cid)
        os.makedirs(folder, exist_ok=True)
        rows = []
        for p in glb_meshes.parts(path):
            if not p["triangles"]:
                continue
            pos = p["positions"]
            lo = [min(v[i] for v in pos) for i in range(3)]
            hi = [max(v[i] for v in pos) for i in range(3)]
            mid = [(lo[i] + hi[i]) / 2 for i in range(3)]
            rbxmesh.write(os.path.join(folder, p["name"] + ".mesh"), [[v[i] - mid[i] for i in range(3)] for v in pos],
                          p["normals"], p["colours"], p["triangles"])
            rows.append({"name": p["name"], "centre": [p["origin"][i] + mid[i] for i in range(3)],
                         "size": [max(hi[i] - lo[i], 0.01) for i in range(3)]})
        found[cid] = (tier, rows)
    print("%d subs' meshes written to %s" % (len(found), out_root))
    return found


def run(studio, source):
    path = os.path.join(tempfile.gettempdir(), "install_subs.luau")
    open(path, "w", encoding="utf-8").write(source)
    if studio == "runner":
        command = ["node", os.path.expanduser("~/Projects/studio-runner/studio-run.mjs"), path]
    else:
        command = ["node", os.path.join(ROOT, "tools", "studio", "run_luau.js"), studio, path]
    out = subprocess.run(command, capture_output=True, text=True)
    text = (out.stdout[-3000:] or out.stderr[-2000:]).strip()
    return text, out.returncode == 0 and "FAILED" not in text and "ERROR" not in text


if __name__ == "__main__":
    studio = sys.argv[1]
    subs = write(sys.argv[2:] or None)
    rows = []
    for cid, (tier, boxes) in sorted(subs.items(), key=lambda kv: kv[1][0]):
        parts = ", ".join('{ "%s", %s }' % (b["name"], ", ".join("%g" % round(v, 4) for v in b["centre"] + b["size"]))
                          for b in boxes)
        rows.append('{ "%s", %d, { %s } }' % (cid, tier, parts))
    text, ok = run(studio, LUAU.replace("__ROWS__", "{ " + ", ".join(rows) + " }").replace("__FOLDER__", FOLDER))
    print(text)
    sys.exit(0 if ok else 1)
