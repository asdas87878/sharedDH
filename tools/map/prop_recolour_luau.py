"""Recolours the loaded map's prop bricks in place, with no reload (2026-11-23, docs/design/colour.md, "A bit less
random"): the bricks whose colour differs between two builds of parts.json that are otherwise the same, matched by model
and by where each brick stands (Studio does not keep the bricks of a model in the order they were made). A model with a
brick that is not where the build has it, or that wears a colour neither build gives that model (somebody moved or
painted it by hand), is left alone and named.

usage: python tools/map/prop_recolour_luau.py <old parts.json> [<a build in between> ...] <new parts.json>
       writes tools/studio/prop_recolour/NN.luau; run each in Edit with tools/studio/run_luau.js. The other way round
       (new, old) puts the colours back."""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "tools", "studio", "prop_recolour")
LANE_X = 3000  # greybox_luau.py's ORIGIN


def model_key(n):
    head = n.split("_")
    for cut in range(len(head) - 1, 0, -1):
        if head[cut].isdigit():
            return "_".join(head[:cut]) + "_" + head[cut]
    return n


builds = [json.load(open(f))["parts"] for f in sys.argv[1:]]
assert len({len(b) for b in builds}) == 1
models, order = {}, []
for row in zip(*builds):
    a = row[0]
    for b in row[1:]:
        assert {k: v for k, v in a.items() if k != "c"} == {k: v for k, v in b.items() if k != "c"}, a["n"]
    if a["k"] != "prop":
        assert len({tuple(p["c"]) for p in row}) == 1, a["n"]
        continue
    key = model_key(a["n"])
    if key not in models:
        models[key] = []
        order.append(key)
    models[key].append((a["p"], ["%02x%02x%02x" % tuple(p["c"]) for p in row]))
order = [k for k in order if any(len(set(c)) > 1 for _, c in models[k])]
os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    os.remove(os.path.join(OUT, f))
CHUNK = 350
files = 0
for i in range(0, len(order), CHUNK):
    data = {}
    for k in order[i:i + CHUNK]:
        data[k] = [" ".join(sorted({c for _, cs in models[k] for c in cs})),
                   [[round(p[0] + LANE_X, 2), round(p[1], 2), round(p[2], 2), cs[-1]] for p, cs in models[k]]]
    code = '''-- prop colours, file %d (tools/map/prop_recolour_luau.py)
local HttpService = game:GetService("HttpService")
local props = workspace.ClaudeBlockout.Lane.Props
local data = HttpService:JSONDecode([==[%s]==])
local done, painted, already, left, names = 0, 0, 0, 0, {}
for key, row in data do
	local m = props:FindFirstChild(key)
	local worn, want = row[1], row[2]
	local bricks, why = {}, nil
	if m then
		for _, c in m:GetChildren() do
			if c:IsA("BasePart") then
				table.insert(bricks, c)
			end
		end
	end
	if not m then
		why = "is not there"
	elseif #bricks ~= #want then
		why = `has {#bricks} bricks, not {#want}`
	end
	local takes, used = {}, {}
	if not why then
		for _, b in bricks do
			local p, best, near = b.Position, nil, 0.1
			for j, w in want do
				local d = math.max(math.abs(p.X - w[1]), math.abs(p.Y - w[2]), math.abs(p.Z - w[3]))
				if d < near and not used[j] then
					best, near = j, d
				end
			end
			if not best then
				why = "has moved"
				break
			elseif not string.find(worn, b.Color:ToHex(), 1, true) then
				why = "was painted " .. b.Color:ToHex()
				break
			end
			used[best] = true
			takes[b] = want[best][4]
		end
	end
	if why then
		left += 1
		table.insert(names, key .. " " .. why)
	else
		done += 1
		for b, c in takes do
			if b.Color:ToHex() == c then
				already += 1
			else
				b.Color = Color3.fromHex(c)
				painted += 1
			end
		end
	end
end
return string.format("%%d models, %%d bricks painted, %%d already right; left alone %%d: %%s", done, painted, already, left, table.concat(names, "; ", 1, math.min(5, #names)))
''' % (files + 1, json.dumps(data, separators=(",", ":")))
    files += 1
    open(os.path.join(OUT, "%02d.luau" % files), "w", encoding="utf-8", newline="\n").write(code)
print(len(order), "models in", files, "files")
