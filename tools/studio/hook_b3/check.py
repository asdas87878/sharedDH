"""The hook onto a fast fish (task b3): a scripted Studio playtest.
    python tools/studio/hook_b3/check.py install | remove     (in Edit: a server Script and a LocalScript, ZZB3*)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/hook_b3/check.py cmd "sweep 10 1 4 BlueChromis 150 200 250 300"
        (land, press 1 = grab pressed as the lock comes on / 0 = hands off, times each, the kind, the speeds)
    python tools/studio/hook_b3/check.py cmd "set Jump LandLag 0"    (a Config number on both machines)
    python tools/studio/hook_b3/check.py log                    (ServerStorage.B3Log)
The driver hops off a fish in that land, the server sends a fish of exactly that speed past from behind, the view is
turned onto it, and the line says whether the rider ended up on it and stayed, with what the server saw at the grab
and at the landing.
"""
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
ITEMS = [
    ("Script", "ZZB3Server", 'game:GetService("ServerScriptService")', "server.luau"),
    ("LocalScript", "ZZB3Client", 'game:GetService("StarterPlayer").StarterPlayerScripts', "client.luau"),
]


def run(code, ctx=None):
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(code)
    args = ["node", RUN] + (["--ctx", ctx] if ctx else []) + [f.name]
    r = subprocess.run(args, capture_output=True, text=True, timeout=200)
    return (r.stdout + r.stderr).strip()


def install(remove_only=False):
    code = ""
    for cls, name, parent, file in ITEMS:
        code += f'do local old = {parent}:FindFirstChild("{name}") if old then old:Destroy() end end\n'
        if not remove_only:
            source = (HERE / file).read_text()
            assert "]==]" not in source
            code += f'do local s = Instance.new("{cls}") s.Name = "{name}" s.Source = [==[{source}]==] s.Parent = {parent} end\n'
    return run(code + 'return "ok"')


what = sys.argv[1]
if what == "install":
    print(install())
elif what == "remove":
    print(install(True))
elif what == "cmd":
    print(run(f'workspace:SetAttribute("B3Cmd", {sys.argv[2]!r} .. " #" .. tostring(os.clock()))\nreturn "sent"'.replace("'", '"'), "server"))
elif what == "log":
    print(run('return game:GetService("ServerStorage").B3Log.Value', "server"))
elif what == "wait":
    # until the log has this text (or the seconds run out)
    until = time.time() + float(sys.argv[3]) if len(sys.argv) > 3 else time.time() + 300
    while time.time() < until:
        text = run('return game:GetService("ServerStorage").B3Log.Value', "server")
        if sys.argv[2] in text:
            break
        time.sleep(5)
    print(text)
elif what == "shot":
    out = Path(sys.argv[2]).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()
    subprocess.run(["node", RUN, "shot", str(out)], capture_output=True, text=True, timeout=60)
    size = -1
    for _ in range(40):
        time.sleep(0.25)
        now = out.stat().st_size if out.exists() else 0
        if now > 0 and now == size:
            break
        size = now
    print(out, size)
elif what == "server":
    print(run(sys.argv[2], "server"))
elif what == "edit":
    print(run(sys.argv[2]))
