"""Puts uploaded creatures into the open Studio place as templates the game uses: ReplicatedStorage.FishModels.<Id>.
usage: python tools/creatures/install.py <studio_id> [Id ...]     (no Ids: every creature in assets.json)
       python tools/creatures/install.py runner [Id ...]          (Hugo's PC: through ~/Projects/studio-runner)

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

if __name__ == "__main__":
    studio = sys.argv[1]
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
