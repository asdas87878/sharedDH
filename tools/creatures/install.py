"""Puts uploaded creatures into the open Studio place as templates the game uses: ReplicatedStorage.FishModels.<Id>.
usage: python tools/creatures/install.py <studio_id> [Id ...]     (no Ids: every creature in assets.json)
       python tools/creatures/install.py runner [Id ...]          (Hugo's PC: through ~/Projects/studio-runner)
       python tools/creatures/install.py runner --local [Id ...]  (no assets: mesh files on this PC; see below)

--local (2026-11-12) is for a PC whose account can't load the assets and has no way to upload its own (Hugo's: the
assets are private to the other account, Studio's connector hangs under Wine, there is no Open Cloud key, and a
plugin's CreateAssetAsync is "not available yet"). Nothing is uploaded: local_meshes.py writes each part as a mesh file
into Studio's content folder and the templates are MeshParts that show those files (rbxasset://ridefish/<Id>/...).
It also makes ReplicatedStorage.FishVariants.Gold.<Id> and .Rainbow.<Id>, the same parts with the variant's colours
in the mesh (Shared/Variants swaps them in). Such a place only shows its fish on this PC, and only while the files
are there: after Studio updates itself run `python tools/creatures/local_meshes.py` again. A published game needs
real assets (owned by the publishing account, or a Roblox group both accounts are in): then run the plain install.

The assets are private to the account that uploaded them (the user's, 165352993). Another account's Studio gets
"Requester does not have permission for Asset" for every one until the owner shares them with it (Creator Hub, the
asset's permissions); the creature then says FAILED here and the game shows its block stand-in.

tools/creatures/assets.json holds each creature's Roblox asset id (the Model made by uploading its GLB; uploads are done
by Claude through Studio's connector, with the user's word, and written there by hand). This writes a Luau script and
runs it in Studio's Edit mode (tools/studio/run_luau.js). For each creature the script:
  - loads the asset (or takes Workspace.<Id>Import if it is already inserted);
  - turns it half round: Roblox's GLB import turns a model 180 degrees about up, so the head arrives toward +Z and the
    game's loader (FishModel.fromRig) wants it toward -Z, as exported;
  - lifts every MeshPart out of the importer's nested "<part>_Node" models into one flat Model, anchored, in white
    SmoothPlastic so the vertex colours show as they are;
  - drops the PackageLink (an inserted upload is a package; a template shouldn't update itself);
  - replaces ReplicatedStorage.FishModels.<Id> (a block stand-in included), and notes the asset id on it.
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS = os.path.join(ROOT, "tools", "creatures", "assets.json")

LUAU = r"""
local InsertService = game:GetService("InsertService")
local rs = game:GetService("ReplicatedStorage")
local folder = rs:FindFirstChild("FishModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "FishModels"
	folder.Parent = rs
end
local report = {}
for _, row in __ROWS__ do
	local id, assetId = row[1], row[2]
	local ok, err = pcall(function()
		local source = workspace:FindFirstChild(id .. "Import")
		if not source then
			-- LoadAsset refuses some assets in a place that isn't published; GetObjects takes them
			local loaded, objects = pcall(function()
				return InsertService:LoadAsset(assetId)
			end)
			if loaded then
				source = objects:FindFirstChildWhichIsA("Model") or objects
			else
				source = game:GetObjects("rbxassetid://" .. assetId)[1]
			end
		end
		local parts = {}
		for _, d in source:GetDescendants() do
			if d:IsA("MeshPart") then
				table.insert(parts, d)
			end
		end
		assert(#parts > 0, "no MeshParts in the asset")
		local model = Instance.new("Model")
		model.Name = id
		for _, p in parts do
			p.Anchored = true
			p.CanCollide = false
			p.Color = Color3.new(1, 1, 1)
			p.Material = Enum.Material.SmoothPlastic
			p.Parent = model
		end
		-- half round about the middle, and squared up (the insert can leave a degree of turn on it)
		local first = parts[1]
		local _, yaw = first.CFrame:ToOrientation()
		local box = model:GetBoundingBox()
		local middle = CFrame.new(box.Position)
		local turn = middle * CFrame.Angles(0, math.pi - yaw, 0) * middle:Inverse()
		for _, p in parts do
			p.CFrame = turn * p.CFrame
		end
		model:SetAttribute("AssetId", assetId)
		local old = folder:FindFirstChild(id)
		if old then
			old:Destroy()
		end
		model.Parent = folder
		if source.Parent then
			source:Destroy()
		end
		local _, size = model:GetBoundingBox()
		table.insert(report, string.format("%s: %d parts, %.1f x %.1f x %.1f", id, #parts, size.X, size.Y, size.Z))
	end)
	if not ok then
		table.insert(report, id .. ": FAILED " .. tostring(err))
	end
end
return table.concat(report, "\n")
"""

LOCAL = r"""
local AssetService = game:GetService("AssetService")
local rs = game:GetService("ReplicatedStorage")
local function folderOf(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end
local models = folderOf(rs, "FishModels")
local variants = folderOf(rs, "FishVariants")
local stale = rs:FindFirstChild("FishMeshes")
if stale then
	stale:Destroy()
end
local report = {}
for _, row in __ROWS__ do
	local id, boxes = row[1], row[2]
	local ok, err = pcall(function()
		local made = {}
		for _, variant in { "", "Gold", "Rainbow" } do
			local model = Instance.new("Model")
			model.Name = id
			for _, b in boxes do
				local file = "rbxasset://__FOLDER__/" .. id .. "/" .. b[1] .. (if variant == "" then "" else "." .. string.lower(variant)) .. ".mesh"
				local p = AssetService:CreateMeshPartAsync(Content.fromUri(file), { CollisionFidelity = Enum.CollisionFidelity.Box })
				assert((p.Size - Vector3.new(b[5], b[6], b[7])).Magnitude < 0.05, b[1] .. " came in at the wrong size")
				p.Name = b[1]
				p.CFrame = CFrame.new(b[2], b[3], b[4])
				p.Anchored = true
				p.CanCollide = false
				p.Color = Color3.new(1, 1, 1)
				p.Material = Enum.Material.SmoothPlastic
				p.Parent = model
			end
			model:SetAttribute("Local", true)
			made[variant] = model
		end
		for variant, model in made do
			local folder = if variant == "" then models else folderOf(variants, variant)
			local old = folder:FindFirstChild(id)
			if old then
				old:Destroy()
			end
			model.Parent = folder
		end
		local _, size = made[""]:GetBoundingBox()
		table.insert(report, string.format("%s: %d parts, %.1f x %.1f x %.1f", id, #boxes, size.X, size.Y, size.Z))
	end)
	if not ok then
		table.insert(report, id .. ": FAILED " .. tostring(err))
	end
	task.wait()
end
return table.concat(report, "\n")
"""


def run(studio, source):
    path = os.path.join(tempfile.gettempdir(), "install_creatures.luau")
    open(path, "w", encoding="utf-8").write(source)
    if studio == "runner":
        command = ["node", os.path.expanduser("~/Projects/studio-runner/studio-run.mjs"), path]
    else:
        command = ["node", os.path.join(ROOT, "tools", "studio", "run_luau.js"), studio, path]
    out = subprocess.run(command, capture_output=True, text=True)
    text = (out.stdout[-3000:] or out.stderr[-2000:]).strip()
    return text, out.returncode == 0 and "FAILED" not in text and "ERROR" not in text


def local(studio, ids):
    """Mesh files in Studio's content folder, and templates that show them (no assets)."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import local_meshes

    boxes = local_meshes.write(ids or None)
    ids = sorted(boxes)
    failed = 0
    for n in range(0, len(ids), 6):
        batch = ids[n : n + 6]
        rows = []
        for i in batch:
            parts = ", ".join(
                '{ "%s", %s }' % (b["name"], ", ".join("%g" % round(v, 4) for v in b["centre"] + b["size"]))
                for b in boxes[i]
            )
            rows.append('{ "%s", { %s } }' % (i, parts))
        source = LOCAL.replace("__ROWS__", "{ " + ", ".join(rows) + " }").replace("__FOLDER__", local_meshes.FOLDER)
        text, ok = run(studio, source)
        print("%d to %d of %d:" % (n + 1, n + len(batch), len(ids)), text[-900:], flush=True)
        failed += 0 if ok else 1
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    studio = sys.argv[1]
    if "--local" in sys.argv:
        local(studio, [a for a in sys.argv[2:] if a != "--local"])
    assets = json.load(open(ASSETS, encoding="utf-8"))
    ids = sys.argv[2:] or sorted(assets)
    # in batches of 12: loading 82 assets in one run is longer than Studio's connector waits
    failed = 0
    for n in range(0, len(ids), 12):
        batch = ids[n : n + 12]
        rows = ", ".join('{ "%s", %d }' % (i, int(assets[i])) for i in batch)
        path = os.path.join(tempfile.gettempdir(), "install_creatures.luau")
        open(path, "w", encoding="utf-8").write(LUAU.replace("__ROWS__", "{ " + rows + " }"))
        if studio == "runner":
            command = ["node", os.path.expanduser("~/Projects/studio-runner/studio-run.mjs"), path]
        else:
            command = ["node", os.path.join(ROOT, "tools", "studio", "run_luau.js"), studio, path]
        out = subprocess.run(command, capture_output=True, text=True)
        text = (out.stdout[-3000:] or out.stderr[-2000:]).strip()
        print("%d to %d of %d:" % (n + 1, n + len(batch), len(ids)), text[-900:], flush=True)
        if out.returncode != 0 or "FAILED" in text:
            failed += 1
    sys.exit(1 if failed else 0)
