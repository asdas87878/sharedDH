"""The fish trails in a playtest (docs/design/fish-trails.md): six fish, Tiny to Colossal, swimming side by side on a loop, a
camera that goes with them, and the numbers. Nothing is left in the place: it is all made while playing.
    python tools/studio/fish_trail_check.py ID push                 (Edit: the five scripts into the place, then read one back)
    python tools/studio/fish_trail_check.py ID play | stop          (stop resets the mouse and the camera in Edit)
    python tools/studio/fish_trail_check.py ID stage [z] [y]        (the six fish, made on the server)
    python tools/studio/fish_trail_check.py ID drive VIEW           (VIEW: all; or 1 to 6: our own fish, from behind it as a rider is)
    python tools/studio/fish_trail_check.py ID set FishTrails 0     (an attribute on the client's workspace: FishTrails, FishTrailsLevel ...)
    python tools/studio/fish_trail_check.py ID numbers [seconds]    (fps, script ms, rigs, particles and things drawn, worked out; our errors)
    python tools/studio/fish_trail_check.py ID shot NAME            (one picture, to work/trails/NAME.png)
    python tools/studio/fish_trail_check.py ID run Client FILE      (any Luau file)
"""
import base64
import json
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/trails"
OUT.mkdir(parents=True, exist_ok=True)
MCP = "C:/Users/blast/RpgGame/tools/studio/studio_mcp.py"
FILES = {
    "src/shared/FishTrails.luau": "ReplicatedStorage.Shared.FishTrails",
    "src/shared/FishTrailColours.luau": "ReplicatedStorage.Shared.FishTrailColours",
    "src/client/Lib/FishTrailRig.luau": "StarterPlayer.StarterPlayerScripts.Client.Lib.FishTrailRig",
    "src/client/Controllers/FishTrailController.luau": "StarterPlayer.StarterPlayerScripts.Client.Controllers.FishTrailController",
}
# the size, the rarity, and what they make: steps 1 to 6
STAGE = [("Tiny", "Common"), ("Normal", "Rare"), ("Big", "Rare"), ("Giant", "Rare"), ("Huge", "Rare"), ("Colossal", "Legendary")]

SERVER = r"""
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local FishModel = require(game:GetService("ServerScriptService").Server.Lib.FishModel)
local old = workspace:FindFirstChild("Fish")
for _, m in old:GetChildren() do if m:GetAttribute("TrailStage") then m:Destroy() end end
local want = { %s }
local used, line, x = {}, {}, 0
for i, row in want do
    local best, gap = nil, math.huge
    for _, fish in Config.Fish do
        local g = math.abs(fish.Size.Z - 13)
        if fish.Tier == row[2] and not used[fish.Id] and fish.Archetype == "" and g < gap then best, gap = fish, g end
    end
    if not best then
        for _, fish in Config.Fish do
            local g = math.abs(fish.Size.Z - 13)
            if fish.Tier == row[2] and not used[fish.Id] and g < gap then best, gap = fish, g end
        end
    end
    used[best.Id] = true
    local scale = Config.sizeScale(row[1], best)
    local model = FishModel.build(best)
    model:ScaleTo(model:GetScale() * scale)
    model:SetAttribute("SizeTier", row[1]) model:SetAttribute("Size", scale) model:SetAttribute("Variant", "")
    model:SetAttribute("Pace", "Cruise") model:SetAttribute("Swift", 1) model:SetAttribute("Archetype", best.Archetype)
    model:SetAttribute("TrailStage", i)
    local body = best.Size * scale
    x += body.X / 2 + 5
    model.PrimaryPart.Anchored = true
    model:PivotTo(CFrame.new(3000 + x, Y, Z) * CFrame.Angles(0, math.pi, 0))
    model:SetAttribute("StageX", x)
    x += body.X / 2 + 5
    model.Parent = old
    table.insert(line, i .. " " .. best.Id .. " " .. row[1] .. " " .. row[2] .. (" %%.0f x %%.0f x %%.0f"):format(body.X, body.Y, body.Z))
end
workspace:SetAttribute("StageWide", x)
return table.concat(line, "\n")
"""

CLIENT = r"""
local RunService = game:GetService("RunService")
local CS = game:GetService("CollectionService")
local me = game:GetService("Players").LocalPlayer
local view, Z, Y, SPEED, LONG = VIEW, STAGEZ, STAGEY, 66, 520
pcall(function() RunService:UnbindFromRenderStep("TrailStage") RunService:UnbindFromRenderStep("TrailStageCam") end)
local fish = {}
for _, m in workspace.Fish:GetChildren() do
    local i = m:GetAttribute("TrailStage")
    if i then
        fish[i] = m
        m:SetAttribute("Rider", if view == i then me.UserId else 0)
    end
end
local function others()
    for _, m in CS:GetTagged("Fish") do
        if not m:GetAttribute("TrailStage") then CS:RemoveTag(m, "Fish") end
    end
end
local wide = workspace:GetAttribute("StageWide")
workspace:SetAttribute("FishTrailsMeasure", true)
local t0, nextClear, offset = os.clock(), 0, 0
local count = 0
RunService:BindToRenderStep("TrailStage", Enum.RenderPriority.Camera.Value - 6, function()
    local now = os.clock()
    if now > nextClear then nextClear = now + 0.5 others() end
    offset = ((now - t0) * SPEED) % LONG
    for i, m in fish do
        local at = CFrame.new(3000 - wide / 2 + m:GetAttribute("StageX"), Y, Z + offset) * CFrame.Angles(0, math.pi, 0)
        if m.PrimaryPart then m:PivotTo(at) end
    end
end)
local function cam()
    local c = workspace.CurrentCamera
    c.CameraType = Enum.CameraType.Scriptable
    if view == 0 then
        c.CFrame = CFrame.lookAt(Vector3.new(3000 + wide * 0.62, Y + wide * 0.24, Z + offset - wide * 0.62), Vector3.new(3000 + wide * 0.04, Y - 2, Z + offset - 6))
    else
        local m = fish[view]
        local at = m.PrimaryPart.Position
        local top = at + Vector3.new(0, m:GetExtentsSize().Y * 0.3 + 5, 0)
        c.CFrame = CFrame.lookAt(top + Vector3.new(0, 3.5, -17), top + Vector3.new(0, 0, 0))
    end
    c.FieldOfView = 70
end
RunService:BindToRenderStep("TrailStageCam", Enum.RenderPriority.Camera.Value + 3, cam)
RunService:BindToRenderStep("TrailStageCam2", Enum.RenderPriority.Last.Value, cam)
for _, g in me.PlayerGui:GetChildren() do if g:IsA("ScreenGui") and HIDE then g.Enabled = false end end
return "driving view " .. view
"""

NUMBERS = r"""
local RunService = game:GetService("RunService")
local n, t = 0, os.clock()
local worst, ms, msTop = 0, 0, 0
while os.clock() - t < SECONDS do
    local dt = RunService.RenderStepped:Wait()
    n += 1
    worst = math.max(worst, dt)
    local now = workspace:GetAttribute("FishTrailsMs") or 0
    ms = now msTop = math.max(msTop, now)
end
local took = os.clock() - t
local count, on = 0, 0
for _, d in workspace.FishTrails:GetDescendants() do
    count += 1
    if (d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")) and d.Enabled then on += 1 end
end
local s = game:GetService("Stats")
local draws = "?"
pcall(function() draws = s.SceneDrawcallCount .. " scene draws, " .. s.SceneTriangleCount .. " tris" end)
return ("fps %.0f (worst frame %.0f ms) | script %.3f ms (top %.3f) | rigs %s, alive %s, drawn %s, level %s | enabled now %d, instances %d | %s | quality %s"):format(
    n / took, worst * 1000, ms, msTop, tostring(workspace:GetAttribute("FishTrailsRigs")), tostring(workspace:GetAttribute("FishTrailsAlive")),
    tostring(workspace:GetAttribute("FishTrailsDraws")), tostring(workspace:GetAttribute("FishTrailsLevelNow")), on, count, draws,
    tostring(UserSettings().GameSettings.SavedQualityLevel))
"""

RESET = r"""
task.delay(0.5, function()
    game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.Default
    workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
end)
task.wait(1)
return tostring(game:GetService("UserInputService").MouseBehavior) .. " " .. tostring(workspace.CurrentCamera.CameraType)
"""


def call(tool, args, wait=120):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf8") as f:
        json.dump(args, f)
    out = subprocess.run([sys.executable, MCP, "call", tool, "@" + f.name, str(wait)], capture_output=True, text=True, encoding="utf8", errors="replace")
    Path(f.name).unlink()
    for line in out.stdout.splitlines():
        if line.startswith('{"content"'):
            return json.loads(line)["content"]
    return [{"type": "text", "text": out.stdout[-1500:] + out.stderr[-800:]}]


def text(content):
    return "\n".join(c.get("text", "[%s]" % c["type"]) for c in content)


def luau(sid, dm, code, wait=120):
    return text(call("execute_luau", {"studio_id": sid, "datamodel_type": dm, "code": code}, wait))


def main():
    sid, what, rest = sys.argv[1], sys.argv[2], sys.argv[3:]
    if what == "push":
        pairs = ["%s=%s" % p for p in FILES.items()]
        subprocess.run([sys.executable, str(ROOT / "tools/studio/push_scripts.py"), str(ROOT), str(OUT / "push.luau"), *pairs], check=True)
        print(luau(sid, "Edit", (OUT / "push.luau").read_text(encoding="utf8")))
        print(luau(sid, "Edit", "local s = game.ReplicatedStorage.Shared.FishTrails.Source return #s .. ' characters of FishTrails'"))
    elif what == "play":
        print(text(call("start_stop_play", {"studio_id": sid, "is_start": True})))
    elif what == "stop":
        print(text(call("start_stop_play", {"studio_id": sid, "is_start": False})))
        time.sleep(4)
        print(luau(sid, "Edit", RESET))
    elif what == "stage":
        z, y = (rest + ["200", "-30"])[:2] if len(rest) >= 2 else (rest[0] if rest else "200", "-30")
        rows = ", ".join('{ "%s", "%s" }' % r for r in STAGE)
        print(luau(sid, "Server", "local Z, Y = %s, %s\n" % (z, y) + SERVER % rows))
        (OUT / "stage.txt").write_text("%s %s" % (z, y))
    elif what == "drive":
        z, y = (OUT / "stage.txt").read_text().split()
        view = "0" if rest[0] == "all" else rest[0]
        hide = "false" if "hud" in rest else "true"
        print(luau(sid, "Client", "local VIEW, STAGEZ, STAGEY, HIDE = %s, %s, %s, %s\n" % (view, z, y, hide) + CLIENT))
    elif what == "set":
        value = rest[1] if re.fullmatch(r"-?[\d.]+|true|false|nil", rest[1]) else '"%s"' % rest[1]
        print(luau(sid, "Client", 'workspace:SetAttribute("%s", %s) return "set"' % (rest[0], value)))
    elif what == "numbers":
        print(luau(sid, "Client", "local SECONDS = %s\n" % (rest[0] if rest else "6") + NUMBERS))
        console = text(call("get_console_output", {"studio_id": sid}))
        print("\n".join([ln for ln in console.splitlines() if "FishTrail" in ln][:8]) or "no console line names FishTrail")
    elif what == "shot":
        content = call("screen_capture", {"studio_id": sid, "capture_id": rest[0]})
        for c in content:
            if c["type"] == "image":
                (OUT / (rest[0] + ".png")).write_bytes(base64.b64decode(c["data"]))
                print("work/trails/%s.png" % rest[0], c.get("mimeType"))
            else:
                print(c.get("text", "")[:300])
    elif what == "run":
        print(luau(sid, rest[0], Path(rest[1]).read_text(encoding="utf8")))


main()
