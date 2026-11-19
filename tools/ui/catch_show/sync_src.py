"""Pushes the repo's Luau sources into the open Studio place (Edit) where they differ, as Rojo would, for when Studio's
Rojo link is down. Only .luau files (the JSON modules are left as they are); new modules are made.
    python tools/ui/catch_show/sync_src.py [--dry]
"""
import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
MAP = {"src/shared": "ReplicatedStorage.Shared", "src/server": "ServerScriptService.Server",
       "src/client": "StarterPlayer.StarterPlayerScripts.Client"}


def run(code):
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(code)
    r = subprocess.run(["node", RUN, f.name], capture_output=True, text=True, timeout=180)
    return (r.stdout + r.stderr).strip()


def lua(s):
    eq = "=" * 6
    while f"]{eq}]" in s:
        eq += "="
    return f"[{eq}[" + s + f"]{eq}]"


def entries():
    out = []
    for base, inst in MAP.items():
        for p in sorted((ROOT / base).rglob("*.luau")):
            rel = p.relative_to(ROOT / base)
            parts = list(rel.parts)
            name = parts[-1][:-5]
            cls = "ModuleScript"
            if name.endswith(".server"):
                name, cls = name[:-7], "Script"
            elif name.endswith(".client"):
                name, cls = name[:-7], "LocalScript"
            if name == "init":
                parts = parts[:-1]
                name = None
            path = inst.split(".") + parts[:-1] + ([name] if name else [])
            if name is None:
                path = inst.split(".") + parts
            out.append((path, cls, p.read_text()))
    return out


FIND = """local function find(path, make, cls)
	local at = game:GetService(path[1])
	for i = 2, #path do
		local nxt = at:FindFirstChild(path[i])
		if not nxt then
			if not make then return nil end
			nxt = Instance.new(if i == #path then cls else "Folder")
			nxt.Name = path[i]
			nxt.Parent = at
		end
		at = nxt
	end
	return at
end
"""


def main():
    dry = "--dry" in sys.argv
    es = entries()
    # Studio's lengths and a hash would need loadstring-side hashing; compare by full text in batches instead
    changed = []
    for i in range(0, len(es), 8):
        chunk = es[i:i + 8]
        code = FIND + "local out = {}\n"
        for path, cls, src in chunk:
            pl = "{" + ",".join(lua(x) for x in path) + "}"
            code += f"do local s = find({pl}, false) out[#out+1] = (s and s.Source == {lua(src)}) and '1' or '0' end\n"
        code += "return table.concat(out)"
        res = run(code).strip().splitlines()[-1]
        for (path, cls, src), flag in zip(chunk, res):
            if flag != "1":
                changed.append((path, cls, src))
    print("changed:", [".".join(p[2:]) for p, _, _ in changed])
    if dry:
        return
    for path, cls, src in changed:
        pl = "{" + ",".join(lua(x) for x in path) + "}"
        code = FIND + f"local s = find({pl}, true, {lua(cls)}) s.Source = {lua(src)} return s:GetFullName()"
        print(run(code).splitlines()[-1])


if __name__ == "__main__":
    main()
