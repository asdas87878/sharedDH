"""Stills of the seahorse trainer's 12 levels in the real game (task sh1), from a Studio playtest on Hugo's PC.
    python art/creatures/Seahorse/tiers/tier_stills.py install | remove   (in Edit: a LocalScript that holds the camera)
    python art/creatures/Seahorse/tiers/tier_stills.py sheet              (in a playtest: each level on the player's plot)
    python art/creatures/Seahorse/tiers/tier_stills.py rider [level]      (in a playtest: seated on a level, 12 by default)
    python art/creatures/Seahorse/tiers/tier_stills.py upgrade            (in a playtest: frames of an upgrade, 11 to 12)
    python art/creatures/Seahorse/tiers/tier_stills.py joints             (in a playtest: each level's spring joint, side on)
    python art/creatures/Seahorse/tiers/tier_stills.py rock [level]       (in a playtest: ridden, five frames of the rock)
How: the server's Studio hook ServerStorage.TrainerTest ("level", userId, n) sets the player's level, so their plot's
ride is built at it (TrainService); "info" says where its coil and seat are. The camera is put at the ride's front
right through the workspace attribute SH1Cam, which the LocalScript holds. Shots by studio-run.mjs shot (written after
it returns: waited for). Frames to work/voxel/seahorse_tiers/stills/, results to docs/attachments/ and
~/Pictures/ride-a-fish/sheets/. Needs Studio with the studio-runner plugin, Rojo serving this repo, and the models
installed (install_tiers.py).
"""
import json
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "work/voxel/seahorse_tiers/stills"
OUT.mkdir(parents=True, exist_ok=True)
SHEETS = Path.home() / "Pictures/ride-a-fish/sheets"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
CROP = (4, 142, 1984, 1205)  # the game view inside the Studio window's shot
NAMES = {1: "Toy", 2: "Painted", 3: "Saddled", 4: "Racer", 5: "Iron", 6: "Spiked", 7: "Knight", 8: "Royal",
         9: "Golden", 10: "Abyssal", 11: "Starfire", 12: "Prismatic"}

CLIENT = r'''
local RunService = game:GetService("RunService")
-- (the workspace attribute SH1Off asks to get off, as a jump does)
workspace:GetAttributeChangedSignal("SH1Off"):Connect(function()
	game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Trainer"):FireServer("Off")
end)
RunService.RenderStepped:Connect(function()
	local cam = workspace:GetAttribute("SH1Cam")
	local camera = workspace.CurrentCamera
	if typeof(cam) == "CFrame" then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cam
		camera.FieldOfView = 50
	elseif camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
end)
'''


def run(args, timeout=120):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if v is None:
        return "nil"
    return "[==[" + str(v) + "]==]"


def server(code):
    return run(["--ctx", "server", "--code", code])


def install(remove=False):
    job = f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZTierStills")
if old then old:Destroy() end
if {lua(remove)} then return "removed" end
local c = Instance.new("LocalScript")
c.Name = "ZZTierStills"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


HELPERS = """
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
local test = game:GetService("ServerStorage"):FindFirstChild("TrainerTest")
local function info(op, a)
	local r = test:Invoke(op, player.UserId, a)
	if type(r) ~= "table" then return tostring(r) end
	return r
end
local function enc(r)
	if type(r) ~= "table" then return r end
	local s = r.Seat
	return game:GetService("HttpService"):JSONEncode({ plot = r.Plot, level = r.Level, rider = r.Rider,
		axis = { r.Axis.X, r.Axis.Y, r.Axis.Z }, look = { s.LookVector.X, s.LookVector.Z }, seat = { s.X, s.Y, s.Z } })
end
"""


def ask(op, a=None, extra=""):
    out = server(HELPERS + f"local r = info({lua(op)}, {lua(a)}) {extra} return enc(r)")
    try:
        return json.loads(out[out.index("{"): out.rindex("}") + 1])
    except ValueError:
        raise SystemExit("TrainerTest: " + out)


def camera(r, side=19.0, ahead=17.0, up=3.0, at=8.0):
    """the ride's front right, looking at the middle of the seahorse"""
    ax = r["axis"]
    lx, lz = r["look"]
    rx, rz = -lz, lx  # its right, flat
    look = (ax[0], ax[1] + at, ax[2])
    eye = (look[0] + lx * ahead + rx * side, look[1] + up, look[2] + lz * ahead + rz * side)
    server(f"workspace:SetAttribute('SH1Cam', CFrame.lookAt(Vector3.new({eye[0]}, {eye[1]}, {eye[2]}), "
           f"Vector3.new({look[0]}, {look[1]}, {look[2]}))) return 'ok'")


def away(r):
    """the player well off the ride, behind the camera (a walk-up within 5.5 studs would seat them)"""
    ax = r["axis"]
    lx, lz = r["look"]
    server(f"local p = game:GetService('Players'):GetPlayers()[1] "
           f"p.Character:PivotTo(CFrame.new({ax[0] + lx * 40}, {ax[1] + 4}, {ax[2] + lz * 40})) return 'ok'")


def shot(path, width=720):
    path = Path(path)
    path.unlink(missing_ok=True)
    out = run(["shot", str(path)], timeout=60)
    size, end = -1, time.time() + 10
    while time.time() < end:
        now = path.stat().st_size if path.exists() else -1
        if now > 0 and now == size:
            break
        size = now
        time.sleep(0.15)
    else:
        raise SystemExit("no shot: " + out)
    im = Image.open(path).convert("RGB").crop(CROP)
    return im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)


def font(size):
    for p in ("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    return ImageFont.load_default(size=size)


def label(im, text, size=26):
    d = ImageDraw.Draw(im)
    d.text((12, 8), text, fill="white", font=font(size), stroke_width=3, stroke_fill=(16, 36, 63))
    return im


def keep(im, name):
    dest = ROOT / "docs/attachments" / name
    im.save(dest, optimize=True)
    SHEETS.mkdir(parents=True, exist_ok=True)
    shutil.copy(dest, SHEETS / name)
    print(dest, im.size)


def sheet():
    cells = []
    for n in range(1, 13):
        r = ask("level", n)
        away(r)
        camera(r)
        time.sleep(2.2)  # (the upgrade's flash and spring are over, the parts streamed in)
        im = shot(OUT / f"level{n}.png", 560)
        cells.append(label(im, f"{n}  {NAMES[n]}"))
        print("level", n, r["plot"], r["level"], flush=True)
    w, h = cells[0].size
    gap = 8
    out = Image.new("RGB", (6 * w + 7 * gap, 2 * h + 3 * gap + 64), (255, 255, 255))
    d = ImageDraw.Draw(out)
    d.text((14, 14), "The seahorse trainer, levels 1 to 12, in the game (a Studio playtest, the hub)", font=font(34),
           fill=(40, 40, 40))
    for i, im in enumerate(cells):
        out.paste(im, (gap + (i % 6) * (w + gap), 64 + gap + (i // 6) * (h + gap)))
    keep(out, "seahorse-tiers-game-1.png")
    server("workspace:SetAttribute('SH1Cam', nil) return 'ok'")


def rider(level=12):
    r = ask("level", level)
    time.sleep(2.2)
    ax = r["axis"]
    lx, lz = r["look"]
    # walk-up: stand by its side, inside the reach, and the server seats us
    server(f"local p = game:GetService('Players'):GetPlayers()[1] "
           f"p.Character:PivotTo(CFrame.new({ax[0] - lz * 4}, {ax[1] + 3}, {ax[2] + lx * 4})) return 'ok'")
    time.sleep(2.5)
    r = ask("info")
    print("rider:", r.get("rider"), flush=True)
    camera(r, side=17, ahead=14, up=4.0, at=9.5)
    time.sleep(1.2)
    keep(label(shot(OUT / "rider.png", 1280), f"Level {level}: {NAMES[level]}, ridden", 34),
         f"seahorse-tier{level}-rider-1.png")
    server("workspace:SetAttribute('SH1Cam', nil) return 'ok'")


def side_camera(r, far=17.0, up=1.0, at=4.2):
    """from the ride's right side, level with where the coil meets the body (the stand's top + SpringLength)"""
    ax = r["axis"]
    lx, lz = r["look"]
    rx, rz = -lz, lx
    look = (ax[0], ax[1] + at - 1.2, ax[2])
    eye = (look[0] + rx * far + lx * 2.0, look[1] + up, look[2] + rz * far + lz * 2.0)
    server(f"workspace:SetAttribute('SH1Cam', CFrame.lookAt(Vector3.new({eye[0]}, {eye[1]}, {eye[2]}), "
           f"Vector3.new({look[0]}, {look[1]}, {look[2]}))) return 'ok'")


def joints():
    """each level from the side, close on the spring: the stand, the coil and where it goes into the body"""
    cells = []
    for n in range(1, 13):
        r = ask("level", n)
        away(r)
        side_camera(r)
        time.sleep(2.2)
        cells.append(label(shot(OUT / f"joint{n}.png", 560), f"{n}  {NAMES[n]}"))
        print("joint", n, flush=True)
    w, h = cells[0].size
    gap = 8
    out = Image.new("RGB", (6 * w + 7 * gap, 2 * h + 3 * gap + 64), (255, 255, 255))
    d = ImageDraw.Draw(out)
    d.text((14, 14), "No plate: the spring goes straight into the seahorse, every level (side view, the game)",
           font=font(34), fill=(40, 40, 40))
    for i, im in enumerate(cells):
        out.paste(im, (gap + (i % 6) * (w + gap), 64 + gap + (i // 6) * (h + gap)))
    keep(out, "seahorse-tiers-joint-1.png")
    server("workspace:SetAttribute('SH1Cam', nil) return 'ok'")


def rock(level=12):
    """ridden, from the side: frames across one swing, the coil bending and still in the body"""
    r = ask("level", level)
    time.sleep(2.2)
    ax = r["axis"]
    lx, lz = r["look"]
    server(f"local p = game:GetService('Players'):GetPlayers()[1] "
           f"p.Character:PivotTo(CFrame.new({ax[0] - lz * 4}, {ax[1] + 3}, {ax[2] + lx * 4})) return 'ok'")
    time.sleep(3.5)
    r = ask("info")
    print("rider:", r.get("rider"), flush=True)
    side_camera(r, far=21, up=2.0, at=6.0)
    time.sleep(1)
    frames = [label(shot(OUT / f"rock{k}.png", 640), f"{level} {NAMES[level]}, ridden") for k in range(5)]
    w, h = frames[0].size
    out = Image.new("RGB", (len(frames) * (w + 6) + 6, h + 12), (255, 255, 255))
    for i, im in enumerate(frames):
        out.paste(im, (6 + i * (w + 6), 6))
    keep(out, f"seahorse-tier{level}-rock-1.png")
    server("workspace:SetAttribute('SH1Off', os.clock()) workspace:SetAttribute('SH1Cam', nil) return 'ok'")


def upgrade():
    r = ask("level", 11)
    away(r)
    camera(r)
    time.sleep(2.2)
    frames = [label(shot(OUT / "up0.png", 640), "11 Starfire")]
    server(HELPERS + "info('level', 12) return 'ok'")
    for k in range(1, 4):
        frames.append(label(shot(OUT / f"up{k}.png", 640), "upgrade to 12"))
    time.sleep(1)
    frames.append(label(shot(OUT / "up4.png", 640), "12 Prismatic"))
    w, h = frames[0].size
    out = Image.new("RGB", (len(frames) * (w + 6) + 6, h + 12), (255, 255, 255))
    for i, im in enumerate(frames):
        out.paste(im, (6 + i * (w + 6), 6))
    keep(out, "seahorse-tier-upgrade-1.png")
    server("workspace:SetAttribute('SH1Cam', nil) return 'ok'")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "sheet"
    if what in ("install", "remove"):
        print(install(what == "remove"))
    elif what == "sheet":
        sheet()
    elif what == "rider":
        rider(int(sys.argv[2]) if len(sys.argv) > 2 else 12)
    elif what == "upgrade":
        upgrade()
    elif what == "joints":
        joints()
    elif what == "rock":
        rock(int(sys.argv[2]) if len(sys.argv) > 2 else 12)
