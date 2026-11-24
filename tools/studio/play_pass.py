"""A critical play pass: the real game in a Studio playtest, played with real keys and the mouse, one capture at a time.
On Windows, through the direct client, kept open (a new one costs about 5 s).
    python tools/studio/play_pass.py SCRIPT.txt OUTNAME      (runs the steps; frames and log.txt in work/play_pass/OUTNAME/)
    python tools/studio/play_pass.py sheet OUTNAME [cols]    (every frame of it on one sheet, with its time)
Steps, one a line ('#' comments):
    play | stop                 start or stop the playtest (stop gives the mouse and the camera back)
    mode                        prints Studio's mode
    sandbox on|off              the movement sandbox, by the server
    down KEY | up KEY | key KEY (W A S D Space Q E ...)
    click PATH | move X Y | clickat X Y
    wait SECONDS
    shot NAME                   one capture
    shots N GAP NAME            N captures, at least GAP seconds apart
    cam NAME x,y,z x,y,z        a capture from a place (camera at, look at)
    camrel NAME x,y,z x,y,z     the same, from the player's own spot
    client LUA | server LUA     one line of Luau, its answer logged
    state                       the player's state, fish, Oxygen, spot (a fixed probe)
"""
import base64
import json
import os
import subprocess
import sys
import threading
import queue
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/play_pass"
ID = os.environ.get("STUDIO_ID", "3b999aa2-7b9c-4390-8231-1c7119b5cc57")

PROBE = r'''
local p = game:GetService("Players").LocalPlayer
local c = p.Character
local r = c and c:FindFirstChild("HumanoidRootPart")
local cam = workspace.CurrentCamera
local words = {}
for _, g in p.PlayerGui:GetDescendants() do
	if (g:IsA("TextLabel") or g:IsA("TextButton")) and g.Text ~= "" and g.TextTransparency < 0.9 and #g.Text < 80 then
		local ok, seen = pcall(function()
			local a = g
			while a and a:IsA("GuiObject") do
				if not a.Visible then return false end
				a = a.Parent
			end
			local top = g:FindFirstAncestorWhichIsA("LayerCollector")
			return top and top:IsA("ScreenGui") and top.Enabled
		end)
		if ok and seen then
			local at, size = g.AbsolutePosition, g.AbsoluteSize
			if size.X > 2 and at.X < cam.ViewportSize.X and at.Y < cam.ViewportSize.Y and at.X + size.X > 0 and at.Y + size.Y > 0 then
				table.insert(words, g.Text)
			end
		end
	end
end
local attrs = {}
for k, v in p:GetAttributes() do
	if type(v) ~= "userdata" then table.insert(attrs, k .. "=" .. tostring(v)) end
end
table.sort(attrs)
return string.format("t=%.2f fps=%d at=%s cam=%s view=%s | %s | words: %s", os.clock(),
	math.floor(1 / math.max(game:GetService("RunService").RenderStepped:Wait(), 0.001)), r and tostring(r.Position) or "none",
	tostring(cam.CFrame.Position), tostring(cam.ViewportSize), table.concat(attrs, " "), table.concat(words, " / "))
'''


class Client:
    def __init__(self):
        exe = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\mcp.bat")
        self.p = subprocess.Popen(["cmd.exe", "/c", exe], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, text=True, encoding="utf-8", bufsize=1)
        self.q = queue.Queue()
        threading.Thread(target=lambda: [self.q.put(x) for x in self.p.stdout], daemon=True).start()
        self.n = 0
        self.ask("initialize", {"protocolVersion": "2026-07-28", "capabilities": {},
                                "clientInfo": {"name": "local-studio-client", "version": "1"}}, 30)
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        time.sleep(4)

    def send(self, o):
        self.p.stdin.write(json.dumps(o) + "\n")
        self.p.stdin.flush()

    def ask(self, method, params, timeout):
        self.n += 1
        self.send({"jsonrpc": "2.0", "id": self.n, "method": method, "params": params})
        end = time.time() + timeout
        while time.time() < end:
            try:
                m = json.loads(self.q.get(timeout=max(0.1, end - time.time())))
            except queue.Empty:
                break
            except ValueError:
                continue
            if m.get("id") == self.n:
                return m.get("result", m)
        raise TimeoutError(method)

    def call(self, name, timeout=60, **args):
        args["studio_id"] = ID
        res = {}
        for _ in range(8):
            res = self.ask("tools/call", {"name": name, "arguments": args}, timeout)
            if "No Roblox Studio instances" not in json.dumps(res)[:400]:
                break
            time.sleep(1.5)
        return res

    def text(self, res):
        return " ".join(c.get("text", "") for c in res.get("content", []) if c.get("type") == "text")

    def lua(self, where, code, timeout=30):
        return self.text(self.call("execute_luau", timeout, code=code, datamodel_type=where))

    def close(self):
        self.p.kill()


def mode(c):
    return c.text(c.call("get_studio_state"))


def run(script, name):
    out = OUT / name
    out.mkdir(parents=True, exist_ok=True)
    log = open(out / "log.txt", "a", encoding="utf-8")
    c = Client()
    t0 = time.time()
    held = set()
    count = len(list(out.glob("*.jpeg"))) + len(list(out.glob("*.png")))

    def say(*a):
        line = f"{time.time() - t0:7.2f}  " + " ".join(str(x) for x in a)
        print(line[:1600])
        log.write(line + "\n")
        log.flush()

    def keys(kind, key):
        c.call("user_keyboard_input", datamodel_type="Client", actions=[{"action": kind, "key_code": key}])

    def shot(label, extra=None):
        nonlocal count
        count += 1
        began = time.time() - t0
        res = c.call("screen_capture", 90, capture_id=f"ScreenCapture_{count}", **(extra or {}))
        for part in res.get("content", []):
            if part.get("type") == "image":
                ext = part.get("mimeType", "image/png").split("/")[-1]
                f = out / f"{count:03d}_{label}_{began:06.1f}s.{ext}"
                f.write_bytes(base64.b64decode(part["data"]))
                say("shot", f.name)
                return
        say("shot FAILED", json.dumps(res)[:300])

    try:
        for raw in script.splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            verb, _, rest = line.partition(" ")
            rest = rest.strip()
            if verb == "mode":
                say(mode(c))
            elif verb == "play":
                m = mode(c)
                if "Mode: Edit" not in m:
                    say("NOT IN EDIT, stopping here:", m)
                    break
                say("play", c.text(c.call("start_stop_play", 120, is_start=True))[:200])
                t0 = time.time()
            elif verb == "stop":
                say("stop", c.text(c.call("start_stop_play", 120, is_start=False))[:200])
                time.sleep(4)
                c.lua("Edit", "task.delay(0.3, function() game:GetService('UserInputService').MouseBehavior = Enum.MouseBehavior.Default "
                              "workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed end) return 'ok'")
                time.sleep(1.5)
                say(c.lua("Edit", "return tostring(game:GetService('UserInputService').MouseBehavior) .. ' ' .. tostring(workspace.CurrentCamera.CameraType)"))
            elif verb == "sandbox":
                say(c.lua("Server", f"workspace:SetAttribute('Sandbox', {'true' if rest == 'on' else 'false'}) return 'sandbox {rest}'"))
            elif verb == "down":
                held.add(rest)
                keys("keyDown", rest)
                say("down", rest)
            elif verb == "up":
                held.discard(rest)
                keys("keyUp", rest)
                say("up", rest)
            elif verb == "key":
                keys("keyPress", rest)
                say("key", rest)
            elif verb == "click":
                say("click", c.text(c.call("user_mouse_input", datamodel_type="Client", actions=[
                    {"action": "moveTo", "instance_path": rest}, {"action": "wait", "wait_time_ms": 120},
                    {"action": "mouseButtonClick", "mouse_button": "left"}]))[:200])
            elif verb in ("move", "clickat"):
                x, y = (float(v) for v in rest.split())
                acts = [{"action": "moveTo", "x": x, "y": y}]
                if verb == "clickat":
                    acts += [{"action": "wait", "wait_time_ms": 120}, {"action": "mouseButtonClick", "mouse_button": "left"}]
                say(verb, c.text(c.call("user_mouse_input", datamodel_type="Client", actions=acts))[:200])
            elif verb == "wait":
                time.sleep(float(rest))
            elif verb == "shot":
                shot(rest or "shot")
            elif verb == "shots":
                n, gap, label = rest.split()
                for _ in range(int(n)):
                    began = time.time()
                    shot(label)
                    time.sleep(max(0, float(gap) - (time.time() - began)))
            elif verb == "cam":
                label, a, b = rest.split()
                shot(label, {"camera_position": [float(v) for v in a.split(",")], "look_at_position": [float(v) for v in b.split(",")]})
            elif verb == "camrel":
                label, a, b = rest.split()
                at = c.lua("Client", "local p = game.Players.LocalPlayer.Character.HumanoidRootPart.Position "
                                     "return string.format('%.1f,%.1f,%.1f', p.X, p.Y, p.Z)")
                base = [float(v) for v in at.strip().strip('"').split(",")]
                rel = lambda t: [x + float(v) for x, v in zip(base, t.split(","))]
                shot(label, {"camera_position": rel(a), "look_at_position": rel(b)})
            elif verb in ("client", "server", "edit"):
                say(verb, c.lua(verb.capitalize(), rest))
            elif verb == "state":
                say(c.lua("Client", PROBE))
            elif verb == "console":
                say(c.text(c.call("get_console_output"))[-int(rest or 3000):])
            else:
                say("??", line)
    finally:
        for k in held:
            try:
                keys("keyUp", k)
            except Exception:
                pass
        c.close()
        log.close()


def sheet(name, cols=4):
    from PIL import Image, ImageDraw
    files = sorted(p for p in (OUT / name).iterdir() if p.suffix in (".png", ".jpeg", ".jpg") and p.stem[:3].isdigit())
    tiles = []
    for f in files:
        im = Image.open(f).convert("RGB")
        im.thumbnail((640, 640))
        ImageDraw.Draw(im).text((6, 4), f.stem, fill=(255, 255, 0), stroke_width=2, stroke_fill=(0, 0, 0))
        tiles.append(im)
    w, h = tiles[0].size
    rows = (len(tiles) + cols - 1) // cols
    big = Image.new("RGB", (w * cols, h * rows))
    for i, im in enumerate(tiles):
        big.paste(im, ((i % cols) * w, (i // cols) * h))
    path = OUT / name / "sheet.jpg"
    big.save(path, quality=85)
    print(path, big.size, len(tiles))


if __name__ == "__main__":
    if sys.argv[1] == "sheet":
        sheet(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 4)
    else:
        run(Path(sys.argv[1]).read_text(encoding="utf-8"), sys.argv[2])
