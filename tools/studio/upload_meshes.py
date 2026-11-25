"""Uploads the place's local-only meshes (rbxasset://ridefish/...: the seahorse rockers, the submarines) as Model assets, one
GLB a group, and points the place's MeshParts at them. UPLOADS ARE PERMANENT: only on the user's word (given 2026-11-25 for
Trainer1 to 12 and the nine submarines: "Yes, upload them").

usage: python tools/studio/upload_meshes.py <studio_id> make [Group ...]    GLBs into art/uploads/meshes/ (from the local files)
       ... upload [Group ...]   the groups not in uploaded_meshes.json yet
       ... ids [Group ...]      reads each asset's mesh ids (Edit)
       ... check [Group ...]    each mesh against its local file (Edit)
       ... apply [Group ...]    the MeshParts get them (Edit; sizes and places kept)
The importer turns each mesh half round about its upright axis, so each GLB is written turned and the mesh comes out as the
local file was ("check" compares corners, colours and face counts).
"""
import json
import os
import struct
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CLIENT = r"C:\Users\blast\RpgGame\tools\studio\studio_mcp.py"
USER_ID = "165352993"
OUT = os.path.join(ROOT, "art", "uploads", "meshes")
BOOK = os.path.join(ROOT, "tools", "studio", "uploaded_meshes.json")
sys.path.insert(0, os.path.join(ROOT, "tools", "studio"))
import trainer_models  # noqa: E402

LIST = r"""
local s, o = {}, {}
for _, d in game.ReplicatedStorage:GetDescendants() do
	if d:IsA("MeshPart") then
		local g = d.MeshId:match("rbxasset://ridefish/(.+)%.mesh$")
		if g and (g:find("^Trainer%d+/") or g:find("^submarines/")) and not s[g] then
			s[g] = true
			table.insert(o, g)
		end
	end
end
return table.concat(o, " ")
"""


def call(tool, args, timeout=110):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump(args, f)
    try:
        out = subprocess.run([sys.executable, CLIENT, "call", tool, "@" + f.name, str(timeout)], capture_output=True, text=True,
                             encoding="utf-8", errors="replace").stdout
    finally:
        os.unlink(f.name)
    line = next((x for x in out.splitlines() if x.startswith('{"content"')), None)
    assert line, out[-300:]
    return json.loads(line)["content"][0]["text"]


def lua(code):
    return call("execute_luau", {"studio_id": STUDIO, "datamodel_type": "Edit", "code": code})


def book():
    return json.load(open(BOOK, encoding="utf-8")) if os.path.exists(BOOK) else {}


def keep(b):
    with open(BOOK, "w", encoding="utf-8", newline="\n") as f:
        json.dump(b, f, indent=1, sort_keys=True)


def mesh(path):
    d = open(path, "rb").read()
    assert d.startswith(b"version 2.00\n"), path
    at = 13
    _, vs, fs, nv, nf = struct.unpack_from("<HBBII", d, at)
    at += 12
    pos, nor, col = [], [], []
    for i in range(nv):
        r = struct.unpack_from("<3f3f2f4b4B", d, at + i * vs)
        pos.append(r[0:3])
        nor.append(r[3:6])
        col.append(r[12:16])
    at += nv * vs
    return pos, nor, col, [struct.unpack_from("<3I", d, at + i * fs) for i in range(nf)]


def groups():
    p = os.path.join(OUT, "list.json")
    if os.path.exists(p):
        return json.load(open(p))
    g = {}
    for m in lua(LIST).split():
        a, n = m.rsplit("/", 1)
        g.setdefault(a, []).append(n)
    os.makedirs(OUT, exist_ok=True)
    with open(p, "w") as f:
        json.dump(g, f, indent=1, sort_keys=True)
    return g


def content():
    c = trainer_models.studio_content()
    return os.path.join(c[0] if isinstance(c, tuple) else c, "ridefish")


def glb(group, names):
    blob, views, accs, nodes, meshes = bytearray(), [], [], [], []

    def add(data, count, kind, comp, **more):
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)})
        accs.append(dict(bufferView=len(views) - 1, componentType=comp, count=count, type=kind, **more))
        blob.extend(data + b"\0" * (-len(data) % 4))
        return len(accs) - 1

    for n in sorted(names):
        pos, nor, col, tri = mesh(os.path.join(content(), group.replace("/", os.sep), n + ".mesh"))
        pos = [(-x, y, -z) for x, y, z in pos]
        nor = [(-x, y, -z) for x, y, z in nor]
        lo = [min(p[i] for p in pos) for i in range(3)]
        hi = [max(p[i] for p in pos) for i in range(3)]
        attrs = {
            "POSITION": add(b"".join(struct.pack("<3f", *p) for p in pos), len(pos), "VEC3", 5126, min=lo, max=hi),
            "NORMAL": add(b"".join(struct.pack("<3f", *p) for p in nor), len(nor), "VEC3", 5126),
            "COLOR_0": add(b"".join(struct.pack("<4H", *(v * 257 for v in c)) for c in col), len(col), "VEC4", 5123,
                           normalized=True),
        }
        idx = add(b"".join(struct.pack("<3I", *t) for t in tri), len(tri) * 3, "SCALAR", 5125)
        meshes.append({"name": n, "primitives": [{"attributes": attrs, "indices": idx}]})
        nodes.append({"mesh": len(meshes) - 1, "name": n})
    doc = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": list(range(len(nodes)))}], "nodes": nodes,
           "meshes": meshes, "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(blob)}]}
    j = json.dumps(doc).encode()
    j += b" " * (-len(j) % 4)
    path = os.path.join(OUT, group.replace("/", "_") + ".glb")
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 28 + len(j) + len(blob)) + struct.pack("<II", len(j), 0x4E4F534A) + j
                + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))
    return path


def cloud(args):
    text = call("open_cloud_invoke", dict(args, studio_id=STUDIO))
    head, _, body = text.partition("\n\n")
    try:
        return head, json.loads(body)
    except ValueError:
        return head, text


def upload(which):
    b = book()
    for group in which:
        if b.get(group, {}).get("asset"):
            continue
        path = os.path.join(OUT, group.replace("/", "_") + ".glb")
        req = {"assetType": "Model", "displayName": "RideAFish " + group.split("/")[-1],
               "description": "Ride a Fish: " + group, "creationContext": {"creator": {"userId": USER_ID}}}
        head, body = cloud({"method": "POST", "endpoint": "/assets/v1/assets", "body": json.dumps({"request": req}),
                            "files": [{"name": "fileContent", "path": path}], "scopes": ["asset:read", "asset:write"]})
        if not isinstance(body, dict) or "path" not in body:
            sys.exit("%s refused: %s %s" % (group, head, str(body)[:300]))
        op = body.get("operationId") or body["path"].split("/")[-1]
        for _ in range(40):
            if body.get("done"):
                break
            time.sleep(3)
            _, body = cloud({"method": "GET", "endpoint": "/assets/v1/operations/" + op, "scopes": ["asset:read"]})
            body = body if isinstance(body, dict) else {}
        aid = (body.get("response") or {}).get("assetId")
        if not aid:
            sys.exit("%s: no asset (%s) %s" % (group, op, str(body)[:200]))
        b[group] = {"asset": int(aid)}
        keep(b)
        print(group, aid, flush=True)


IDS = r"""
local aid = __ID__
local ok, src = pcall(function()
	return game:GetService("InsertService"):LoadAsset(aid)
end)
if not ok then
	src = game:GetObjects("rbxassetid://" .. aid)[1]
end
local o = {}
for _, d in src:GetDescendants() do
	if d:IsA("MeshPart") then
		table.insert(o, d.Name .. "=" .. d.MeshId:match("%d+") .. "=" .. d.TextureID)
	end
end
src:Destroy()
return table.concat(o, " ")
"""


def ids(which):
    b, g = book(), groups()
    for group in which:
        if group not in b or b[group].get("meshes"):
            continue
        text = lua(IDS.replace("__ID__", str(b[group]["asset"])))
        found = {p.split("=")[0]: p.split("=")[1] for p in text.split() if p.count("=") >= 2}
        if sorted(found) != sorted(g[group]):
            print(group, "NAMES DIFFER", sorted(found), sorted(g[group]), text[:200])
            continue
        b[group]["meshes"] = found
        keep(b)
        print(group, len(found), "ids", flush=True)


CHECK = r"""
local AS = game:GetService("AssetService")
local out, worst, n = {}, 0, 0
local function read(uri)
	local m = AS:CreateEditableMeshAsync(Content.fromUri(uri))
	local lo, hi = Vector3.one * math.huge, Vector3.one * -math.huge
	local set = {}
	for _, v in m:GetVertices() do
		local p = m:GetPosition(v)
		lo, hi = lo:Min(p), hi:Max(p)
		table.insert(set, p)
	end
	local mid = (lo + hi) / 2
	for i, p in set do
		set[i] = p - mid
	end
	local c = Vector3.zero
	local f = m:GetFaces()
	for _, face in f do
		for _, id in m:GetFaceColors(face) do
			local k = m:GetColor(id)
			if k then
				c += Vector3.new(k.R, k.G, k.B) / 3
			end
		end
	end
	m:Destroy()
	return set, c / math.max(#f, 1), hi - lo, #f
end
for _, r in __ROWS__ do
	local ok, err = pcall(function()
		local s1, c1, z1, f1 = read("rbxasset://ridefish/" .. r[1] .. ".mesh")
		local s2, c2, z2, f2 = read("rbxassetid://" .. r[2])
		local far = 0
		for i = 1, #s1, math.max(1, math.floor(#s1 / 60)) do
			local near = math.huge
			for _, q in s2 do
				near = math.min(near, (q - s1[i]).Magnitude)
			end
			far = math.max(far, near)
		end
		n += 1
		local d = math.max(far, (z1 - z2).Magnitude, (c1 - c2).Magnitude)
		worst = math.max(worst, d)
		if d > 0.03 or f1 ~= f2 then
			table.insert(out, string.format("%s far %.3f size %.3f col %.3f faces %d/%d", r[1], far, (z1 - z2).Magnitude, (c1 - c2).Magnitude, f1, f2))
		end
	end)
	if not ok then
		table.insert(out, r[1] .. " ERR " .. tostring(err))
	end
end
return n .. " compared, worst " .. string.format("%.4f", worst) .. " " .. table.concat(out, "; ")
"""


def rows(which):
    b = book()
    return ["{%s, %s}" % (json.dumps(g + "/" + n), json.dumps(i))
            for g in which if g in b for n, i in sorted(b[g].get("meshes", {}).items())]


def check(which):
    for group in which:
        r = rows([group])
        if r:
            print(group, lua(CHECK.replace("__ROWS__", "{" + ", ".join(r) + "}"))[:500], flush=True)


APPLY = r"""
local AS = game:GetService("AssetService")
local map, made, n, bad = {}, {}, 0, {}
for _, r in __ROWS__ do
	map["rbxasset://ridefish/" .. r[1] .. ".mesh"] = r[2]
end
for _, d in game.ReplicatedStorage:GetDescendants() do
	if d:IsA("MeshPart") and map[d.MeshId] then
		local ok, err = pcall(function()
			local id = map[d.MeshId]
			local from = made[id]
			if not from then
				from = AS:CreateMeshPartAsync(
					Content.fromUri("rbxassetid://" .. id),
					{ CollisionFidelity = d.CollisionFidelity, RenderFidelity = d.RenderFidelity }
				)
				made[id] = from
			end
			local size, cf, pivot, colour, mat = d.Size, d.CFrame, d.PivotOffset, d.Color, d.Material
			d:ApplyMesh(from)
			d.Size, d.CFrame, d.PivotOffset, d.Color, d.Material = size, cf, pivot, colour, mat
			n += 1
		end)
		if not ok then
			table.insert(bad, d.Name .. ": " .. tostring(err))
		end
	end
end
return n .. " parts set; " .. table.concat(bad, "; ")
"""

STUDIO = sys.argv[1]
what = sys.argv[2]
every = groups()
which = sys.argv[3:] or sorted(every)
if what == "make":
    for g in which:
        print(g, len(every[g]), os.path.getsize(glb(g, every[g])) // 1024, "KB")
elif what == "upload":
    upload(which)
elif what == "ids":
    ids(which)
elif what == "check":
    check(which)
elif what == "apply":
    for g in which:
        print(g, lua(APPLY.replace("__ROWS__", "{" + ", ".join(rows([g])) + "}"))[:400], flush=True)
