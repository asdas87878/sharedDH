"""Recolours the loaded map's prop bricks in place, with no reload (2026-11-23, docs/design/colour.md, "A bit less
random"): the bricks whose colour differs between two builds of parts.json that are otherwise the same, matched by model
and by their order inside it, as prop_groups_luau.py does. A model whose brick count differs, or whose bricks don't wear
the old colours (somebody painted it by hand), is left alone and named.

usage: python tools/map/prop_recolour_luau.py <old parts.json> <new parts.json>
       writes tools/studio/prop_recolour/NN.luau; run each in Edit with tools/studio/run_luau.js. The other way round
       (new, old) puts the colours back."""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "tools", "studio", "prop_recolour")


def model_key(n):
    head = n.split("_")
    for cut in range(len(head) - 1, 0, -1):
        if head[cut].isdigit():
            return "_".join(head[:cut]) + "_" + head[cut]
    return n


old, new = (json.load(open(f))["parts"] for f in sys.argv[1:3])
assert len(old) == len(new)
models, order = {}, []
for a, b in zip(old, new):
    assert {k: v for k, v in a.items() if k != "c"} == {k: v for k, v in b.items() if k != "c"}, a["n"]
    if a["k"] != "prop":
        assert a["c"] == b["c"], a["n"]
        continue
    key = model_key(a["n"])
    if key not in models:
        models[key] = []
        order.append(key)
    models[key].append(["%02x%02x%02x" % tuple(a["c"]), "%02x%02x%02x" % tuple(b["c"])])
order = [k for k in order if any(o != n for o, n in models[k])]
os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    os.remove(os.path.join(OUT, f))
CHUNK = 700
files = 0
for i in range(0, len(order), CHUNK):
    data = {k: "".join(o + n for o, n in models[k]) for k in order[i:i + CHUNK]}
    code = '''-- prop colours, file %d (tools/map/prop_recolour_luau.py)
local HttpService = game:GetService("HttpService")
local props = workspace.ClaudeBlockout.Lane.Props
local data = HttpService:JSONDecode([==[%s]==])
local done, painted, left, names = 0, 0, 0, {}
for key, row in data do
	local m = props:FindFirstChild(key)
	local bricks = {}
	if m then
		for _, c in m:GetChildren() do
			if c:IsA("BasePart") then
				table.insert(bricks, c)
			end
		end
	end
	local ok = #bricks * 12 == #row
	if ok then
		for j, b in bricks do
			local was = string.sub(row, j * 12 - 11, j * 12 - 6)
			if b.Color:ToHex() ~= was then
				ok = false
				table.insert(names, key .. " " .. b.Name .. " is " .. b.Color:ToHex() .. " not " .. was)
				break
			end
		end
	else
		table.insert(names, key .. (if m then " has " .. #bricks .. " bricks" else " is not there"))
	end
	if ok then
		for j, b in bricks do
			b.Color = Color3.fromHex(string.sub(row, j * 12 - 5, j * 12))
			painted += 1
		end
		done += 1
	else
		left += 1
	end
end
return string.format("%%d models, %%d bricks; left alone %%d: %%s", done, painted, left, table.concat(names, "; ", 1, math.min(5, #names)))
''' % (files + 1, json.dumps(data, separators=(",", ":")))
    files += 1
    open(os.path.join(OUT, "%02d.luau" % files), "w", encoding="utf-8", newline="\n").write(code)
print(len(order), "models in", files, "files")
