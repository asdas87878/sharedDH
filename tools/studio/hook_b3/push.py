"""Pushes only this task's files into the open Studio place (Edit), for when Rojo isn't serving and another chat has
half-made changes in the tree. Config goes as the committed one plus this task's own hunk (git diff of the Jump lines).
    python tools/studio/hook_b3/push.py
"""
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
FILES = {
    "src/client/Controllers/GroundFxController.luau": "StarterPlayer.StarterPlayerScripts.Client.Controllers.GroundFxController",
    "src/client/UI/Banners.luau": "StarterPlayer.StarterPlayerScripts.Client.UI.Banners",
    "src/client/UI/DiveScreen.luau": "StarterPlayer.StarterPlayerScripts.Client.UI.DiveScreen",
    "src/server/Services/FishService.luau": "ServerScriptService.Server.Services.FishService",
    "src/server/Services/RideService.luau": "ServerScriptService.Server.Services.RideService",
    "src/client/Controllers/JumpController.luau": "StarterPlayer.StarterPlayerScripts.Client.Controllers.JumpController",
}
MARK = "\tLandSlack = 20,"


def config():
    # the committed Config with this task's lines (from LandSlack to the end of the FastEase rows) put in
    head = subprocess.run(["git", "show", "HEAD:src/shared/Config.luau"], cwd=ROOT, capture_output=True, text=True).stdout
    mine = (ROOT / "src/shared/Config.luau").read_text()
    a = mine.index(MARK)
    b = mine.index("\n", mine.index("\tFastEaseRate =")) + 1
    line = head.index(MARK)
    return head[:line] + mine[a:b] + head[head.index("\n", line) + 1:]


code = ""
sources = {where: (ROOT / file).read_text() for file, where in FILES.items()}
sources["ReplicatedStorage.Shared.Config"] = config()
for where, source in sources.items():
    assert "]======]" not in source
    parts = where.split(".")
    code += 'do local at = game:GetService("%s")' % parts[0]
    for part in parts[1:]:
        code += ' at = at:FindFirstChild("%s")' % part
    # (ScriptEditorService takes a source over Source's 200,000-character cap: Config is past it)
    code += " local text = [======[%s]======] game:GetService('ScriptEditorService'):UpdateSourceAsync(at, function() return text end) end\n" % source
code += 'return "pushed %d"' % len(sources)
with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
    f.write(code)
r = subprocess.run(["node", RUN, f.name], capture_output=True, text=True, timeout=200)
print((r.stdout + r.stderr).strip())
