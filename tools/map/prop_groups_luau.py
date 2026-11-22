"""Writes each prop brick's break group into the loaded map (2026-11-19), so the game can break a prop into one
simple chunk per group (docs/design/props-and-landmarks.md, 3b; the break itself is the game-code chat's).

On every brick of Workspace.ClaudeBlockout.Lane.Props.<model>: attribute Group (the tier, branch or blade it breaks
with; "dressing" for small things that never break) and Studs (true where it wears the stud material). The bricks are
matched to parts.json by their order inside each model: the loader (tools/map/greybox_luau.py) makes them in that
order. A model whose brick count differs is skipped and counted.

usage: python tools/map/prop_groups_luau.py     writes tools/studio/prop_groups/NN.luau; run them in Edit with
       python tools/studio/load_greybox.py <studio_id> prop_groups"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "map"))
OUT = os.path.join(ROOT, "tools", "studio", "prop_groups")


def model_key(n):
    head = n.split("_")
    for cut in range(len(head) - 1, 0, -1):
        if head[cut].isdigit():
            return "_".join(head[:cut]) + "_" + head[cut]
    asset, number, _ = n.rsplit("_", 2)
    return asset + "_" + number


parts = json.load(open(os.path.join(ROOT, "art", "map", "greybox", "parts.json")))["parts"]
models = {}
order = []
for p in parts:
    if p["k"] != "prop" or "g" not in p:
        continue
    key = model_key(p["n"])
    if key not in models:
        models[key] = []
        order.append(key)
    models[key].append([p["g"], 1 if p.get("st") else 0])

os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    os.remove(os.path.join(OUT, f))
CHUNK = 600
files = 0
for i in range(0, len(order), CHUNK):
    data = {k: models[k] for k in order[i:i + CHUNK]}
    code = '''-- prop break groups, file %d (tools/map/prop_groups_luau.py)
local HttpService = game:GetService("HttpService")
local props = workspace.ClaudeBlockout.Lane.Props
local data = HttpService:JSONDecode([==[%s]==])
local done, skipped = 0, 0
for key, rows in data do
	local m = props:FindFirstChild(key)
	if m then
		local bricks = {}
		for _, c in m:GetChildren() do
			if c:IsA("BasePart") then
				table.insert(bricks, c)
			end
		end
		if #bricks == #rows then
			for j, b in bricks do
				b:SetAttribute("Group", rows[j][1])
				b:SetAttribute("Studs", rows[j][2] == 1)
			end
			done += 1
		else
			skipped += 1
		end
	else
		skipped += 1
	end
end
return string.format("prop groups: %%d models done, %%d skipped", done, skipped)
''' % (files + 1, json.dumps(data, separators=(",", ":")))
    files += 1
    open(os.path.join(OUT, "%02d.luau" % files), "w", encoding="utf-8").write(code)
print(len(order), "prop models in", files, "files")
