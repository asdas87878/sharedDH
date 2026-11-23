"""The nine toy subs seen in the game (task m4): each over the stand with its name sign, each on a real trip (the
game's own riding view and a close one of the rider on the seat), and the stand's shop at PC and phone size, with a
read-out of how each card's picture frames its model.
    python tools/studio/m4_subs_shots.py install            (in Edit, before Play)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/m4_subs_shots.py gate               (in the playtest: are the stills live?)
    python tools/studio/m4_subs_shots.py closes [tier ...]  (each over the stand, with its sign)
    python tools/studio/m4_subs_shots.py shop <tag>         (the shop's cards, PC and phone: read-out and stills)
    python tools/studio/m4_subs_shots.py rides [tier ...]   (a real trip a tier, twice: the game's view, a close one)
    python tools/studio/m4_subs_shots.py sheets             (the sheets in docs/attachments, from the stills)
    python tools/studio/m4_subs_shots.py remove             (in Edit, after the stop)
It rides on s2_subs_check's server door and t3_toy_subs_check's client (the trip's numbers) and adds its own
LocalScript. Studio's window may be hidden (it redraws about once a second then, or not at all): every still must
differ from the one before it, or the run stops. Log: work/m4/shots.log; stills work/m4/*.png.
"""
import json
import math
import sys
import time
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import s2_subs_check as s2  # noqa: E402
import t3_toy_subs_check as t3  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/creatures"))
OUT = ROOT / "work/m4"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
NAMES = t3.NAMES
PHONE = (844, 390)
# the game view inside the picture of Studio's window (left, top, right, bottom): set by `gate` from the first still
VIEW_FILE = OUT / "view.json"

CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local report = RS:WaitForChild("ZZS2Report")
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local SubModels = require(RS:WaitForChild("Shared"):WaitForChild("SubModels"))
local SubPanel = require(Client:WaitForChild("UI"):WaitForChild("SubPanel"))
local State = require(Client:WaitForChild("Lib"):WaitForChild("State"))
local POINTS = __POINTS__
local line = nil
local function stand()
	local dock = workspace:FindFirstChild("Dock", true)
	local stations = dock and dock:FindFirstChild("Stations")
	return stations and stations:FindFirstChild("Sub")
end
local function shopGui()
	return player.PlayerGui:FindFirstChild("SubShop")
end
local function listOf(gui)
	local carousel = gui:FindFirstChild("Carousel", true)
	return carousel and carousel:FindFirstChild("List")
end
local function scaleOf(gui)
	local sc = gui.Root:FindFirstChildOfClass("UIScale")
	return sc and sc.Scale or 1
end
-- the close riding camera: ours wins whenever the game moves the camera
local rcam = nil
local rcamEye, rcamAt, rcamFov = Vector3.new(-30, 20, 54), Vector3.new(0, 6, -4), 55
local setting = false
local function ourSub()
	for _, m in workspace.CurrentCamera:GetChildren() do
		if m.Name == "Submarine" and m:GetAttribute("For") == player.UserId then return m end
	end
	return nil
end
local function closeCam()
	if setting or player:GetAttribute("SubPhase") ~= "Ride" then return end
	local found = ourSub()
	local hull = found and found.PrimaryPart
	local folder = RS:FindFirstChild(SubModels.Templates)
	local t = found and folder and folder:FindFirstChild(SubModels.style(found:GetAttribute("Tier")).Id)
	if not (hull and t) then return end
	local sub = hull.CFrame * t.Hull.CFrame:Inverse()
	setting = true
	local cam = workspace.CurrentCamera
	cam.CFrame = CFrame.lookAt(sub:PointToWorldSpace(rcamEye), sub:PointToWorldSpace(rcamAt), sub.UpVector)
	cam.FieldOfView = rcamFov
	setting = false
end
workspace:GetAttributeChangedSignal("M4Do"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("M4Do") or "")
	local words = string.split(cmd, "|")
	local verb = words[1]
	local ok, said = pcall(function()
		if verb == "ping" then
			return "pong mode=" .. tostring(State.Mode)
		elseif verb == "close" then
			-- one sub over the stand, turned three-quarters to the camera, with its name sign; the stand under it
			if line then line:Destroy() end
			line = Instance.new("Folder")
			line.Name = "M4Line"
			line.Parent = workspace
			local n = tonumber(words[2])
			local at = stand():GetPivot().Position
			local model, parts = SubModels.build(n)
			local top, low = -math.huge, math.huge
			for _, p in parts do
				top = math.max(top, p.Position.Y + p.Size.Y / 2)
				low = math.min(low, p.Position.Y - p.Size.Y / 2)
			end
			local sign = model:FindFirstChild("Label", true)
			local signLow = sign.Parent.Position.Y + sign.StudsOffsetWorldSpace.Y - sign.Size.Y.Scale / 2
			local text = sign:FindFirstChildOfClass("TextLabel").Text
			-- words: tier, the sub's turn, where it floats, where the camera stands, what it looks at (all from the stand), fov
			local function v(i)
				return Vector3.new(tonumber(words[i]), tonumber(words[i + 1]), tonumber(words[i + 2]))
			end
			local turn = CFrame.new(at + v(4)) * CFrame.Angles(0, math.rad(tonumber(words[3])), 0)
			for _, p in parts do
				p.CFrame = turn * p.CFrame
			end
			model.Parent = line
			local cam = workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.lookAt(at + v(7), at + v(10))
			cam.FieldOfView = tonumber(words[13])
			return string.format("close %d sign=%q hullMesh=%s parts=%d top=%.1f low=%.1f signLow=%.1f gap=%.1f", n, text,
				tostring(model.PrimaryPart:IsA("MeshPart")), #parts, top, low, signLow, signLow - top)
		elseif verb == "unclose" then
			if line then line:Destroy() line = nil end
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			workspace.CurrentCamera.FieldOfView = 70
			return "unclosed"
		elseif verb == "hud" then
			-- the screens out of the picture, and back
			local on = words[2] == "on"
			for _, g in player.PlayerGui:GetChildren() do
				if g:IsA("ScreenGui") then
					if not on and g.Enabled then
						g:SetAttribute("M4Hid", true)
						g.Enabled = false
					elseif on and g:GetAttribute("M4Hid") then
						g:SetAttribute("M4Hid", nil)
						g.Enabled = true
					end
				end
			end
			pcall(function()
				game:GetService("StarterGui"):SetCore("TopbarEnabled", on)
			end)
			return "hud " .. words[2]
		elseif verb == "near" then
			-- onto the stand's ring: the shop closes itself further than Config.Sub.Near from it
			local ring = stand():FindFirstChild("Ring")
			local character = player.Character
			character:PivotTo(CFrame.new(ring.Position + Vector3.new(0, 4, 0)))
			task.wait(0.5)
			local root = character:FindFirstChild("HumanoidRootPart")
			return string.format("near %.1f studs from the ring, mode=%s", (root.Position - ring.Position).Magnitude, tostring(State.Mode))
		elseif verb == "shop" then
			SubPanel.toggle(words[2] == "on")
			task.wait(0.9)
			local gui = shopGui()
			return "shop " .. words[2] .. " enabled=" .. tostring(gui and gui.Enabled)
		elseif verb == "scroll" then
			-- card `index` (0: NO SUB) at the list's left
			local gui = shopGui()
			local list = listOf(gui)
			local most = math.max(0, list.AbsoluteCanvasSize.X - list.AbsoluteWindowSize.X)
			list.CanvasPosition = Vector2.new(math.clamp(tonumber(words[2]) * 200 * scaleOf(gui), 0, most), 0)
			task.wait(0.3)
			return string.format("scroll %s canvasX=%d of %d enabled=%s", words[2], list.CanvasPosition.X, most, tostring(gui.Enabled))
		elseif verb == "phone" then
			local w, h = tonumber(words[2]), tonumber(words[3])
			workspace:SetAttribute("PanelPhone", if w and h then Vector2.new(w, h) else nil)
			task.wait(0.4)
			return "phone " .. tostring(workspace:GetAttribute("PanelPhone"))
		elseif verb == "cards" then
			-- how each card's picture frames its model: the model's own points through the card's camera, as shares of
			-- the picture's half width and half height (inside when all are within -1..1)
			local gui = shopGui()
			local list = listOf(gui)
			local window = gui.Root.Window
			local view = workspace.CurrentCamera.ViewportSize
			local out = { string.format("enabled=%s scale=%.3f window=%dx%d at %d,%d screen=%dx%d", tostring(gui.Enabled), scaleOf(gui),
				window.AbsoluteSize.X, window.AbsoluteSize.Y, window.AbsolutePosition.X, window.AbsolutePosition.Y, view.X, view.Y) }
			for n = 1, 9 do
				local card = list:FindFirstChild("Sub" .. n)
				local frame = card and card:FindFirstChildWhichIsA("ViewportFrame", true)
				local model = frame and frame:FindFirstChildOfClass("Model")
				local pts = POINTS[n]
				if not (frame and model and pts) then
					table.insert(out, n .. ": no picture")
					continue
				end
				local cam = frame.CurrentCamera
				local size = frame.AbsoluteSize
				local ty = math.tan(math.rad(cam.FieldOfView / 2))
				local tx = ty * size.X / size.Y
				local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
				local plo, phi = Vector3.one * math.huge, Vector3.one * -math.huge
				for i = 1, #pts, 3 do
					local world = Vector3.new(pts[i], pts[i + 1], pts[i + 2])
					plo, phi = plo:Min(world), phi:Max(world)
					local p = cam.CFrame:PointToObjectSpace(world)
					local x, y = p.X / -p.Z / tx, p.Y / -p.Z / ty
					x0, x1, y0, y1 = math.min(x0, x), math.max(x1, x), math.min(y0, y), math.max(y1, y)
				end
				-- the model in the picture against those points: the same place, the same way round
				local mlo, mhi = Vector3.one * math.huge, Vector3.one * -math.huge
				local mesh = false
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						mlo, mhi = mlo:Min(d.Position - d.Size / 2), mhi:Max(d.Position + d.Size / 2)
						mesh = mesh or d:IsA("MeshPart")
					end
				end
				local a, b = (mlo - plo):Abs(), (mhi - phi):Abs()
				local off = math.max(a.X, a.Y, a.Z, b.X, b.Y, b.Z)
				local worst = math.max(-x0, x1, -y0, y1)
				local eye = cam.CFrame.Position
				table.insert(out, string.format("%d: %s box=%dx%d x=%.2f..%.2f y=%.2f..%.2f worst=%.2f %s eye=%.1f,%.1f,%.1f mesh=%s boxOff=%.2f", n,
					SubModels.style(n).Id, size.X, size.Y, x0, x1, y0, y1, worst, if worst <= 1 then "inside" else "CUT", eye.X, eye.Y, eye.Z,
					tostring(mesh), off))
			end
			return table.concat(out, "\n")
		elseif verb == "rcam" then
			if rcam then rcam:Disconnect() rcam = nil end
			if words[2] == "on" then
				if tonumber(words[9]) then
					rcamEye = Vector3.new(tonumber(words[3]), tonumber(words[4]), tonumber(words[5]))
					rcamAt = Vector3.new(tonumber(words[6]), tonumber(words[7]), tonumber(words[8]))
					rcamFov = tonumber(words[9])
				end
				rcam = workspace.CurrentCamera:GetPropertyChangedSignal("CFrame"):Connect(closeCam)
			end
			return "rcam " .. tostring(words[2])
		end
		return "?"
	end)
	report:FireServer(tostring(said) .. " " .. tostring(ok))
end)
'''

LOG = []


def note(text):
    print(text, flush=True)
    LOG.append(text)


def save_log():
    with open(OUT / "shots.log", "a", encoding="utf-8") as f:
        f.write("\n".join(LOG) + "\n")
    LOG.clear()


def hull_points(directions=500):
    """each tier's own outline: the model's points that are furthest out in `directions` ways (its convex corners)"""
    import glob

    import glb_meshes

    out = {}
    ways = []
    for i in range(directions):
        z = 1 - 2 * (i + 0.5) / directions
        r = math.sqrt(1 - z * z)
        a = i * math.pi * (3 - math.sqrt(5))
        ways.append((r * math.cos(a), r * math.sin(a), z))
    for path in glob.glob(str(ROOT / "art/subs/*/*.glb")):
        tier = json.load(open(path[:-4] + ".mesh.json", encoding="utf-8"))["tier"]
        pts = []
        for p in glb_meshes.parts(path):
            if p["triangles"]:
                pts += [tuple(v[i] + p["origin"][i] for i in range(3)) for v in p["positions"]]
        keep = set()
        for w in ways:
            keep.add(max(pts, key=lambda v: v[0] * w[0] + v[1] * w[1] + v[2] * w[2]))
        out[tier] = sorted(keep)
    return out


def install(remove=False):
    out = t3.install(remove)
    points = "nil"
    if not remove:
        rows = []
        for tier, pts in sorted(hull_points().items()):
            rows.append("[%d] = { %s }" % (tier, ", ".join("%.2f" % c for p in pts for c in p)))
        points = "{ " + ", ".join(rows) + " }"
    return out + " / " + s2.job(f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZM4Check")
if old then old:Destroy() end
workspace:SetAttribute("M4Do", nil)
workspace:SetAttribute("PanelPhone", nil)
if {s2.lua(remove)} then
	return "removed m4"
end
local c = Instance.new("LocalScript")
c.Name = "ZZM4Check"
c.Source = {s2.lua(CLIENT.replace("__POINTS__", points))}
c.Parent = sps
return "installed m4 " .. #c.Source
""")


def do(c, wait=1.4):
    return s2.server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('S2Client', '') "
        f"workspace:SetAttribute('M4Do', {s2.lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('S2Client')"
    )


def view():
    return tuple(json.loads(VIEW_FILE.read_text())) if VIEW_FILE.exists() else (s2.OFFSET[0], s2.OFFSET[1],
                                                                              s2.OFFSET[0] + s2.VIEW[0],
                                                                              s2.OFFSET[1] + s2.VIEW[1])


def raw(name):
    """one picture of Studio's whole window (the runner's `shot` returns before the file is written)"""
    full = OUT / (name + "-full.png")
    full.unlink(missing_ok=True)
    out = s2.run(["shot", str(full)], timeout=60)
    size, end = -1, time.time() + 12
    while time.time() < end:
        now = full.stat().st_size if full.exists() else -1
        if now > 0 and now == size:
            break
        size = now
        time.sleep(0.15)
    else:
        raise SystemExit("no shot: " + out)
    return full


def changed(a, b):
    """the share of the game view that differs between two stills"""
    d = ImageChops.difference(Image.open(a).convert("RGB"), Image.open(b).convert("RGB")).convert("L")
    d = d.point(lambda v: 255 if v > 24 else 0)
    return d.histogram()[255] / (d.size[0] * d.size[1])


LAST = OUT / "last.txt"


def shot(name, tries=5, least=0.004):
    """a still of the game view that differs from the still before it (a hidden Studio redraws late, or never)"""
    before = Path(LAST.read_text()) if LAST.exists() else None
    path = OUT / (name + ".png")
    for i in range(tries):
        full = raw(name)
        Image.open(full).convert("RGB").crop(view()).save(path)
        full.unlink(missing_ok=True)
        share = changed(before, path) if before and before.exists() and before != path else 1.0
        if share >= least:
            LAST.write_text(str(path))
            note(f"  still {path.name}: {share:.3f} of the view differs from the one before")
            return path
        time.sleep(1.0)
    save_log()
    raise SystemExit(f"FROZEN: {path.name} is the same picture as {before.name} after {tries} tries")


def gate():
    """Are the stills live? One still, a sub over the stand, another: they must differ. Also finds the game view."""
    end = time.time() + 60
    while time.time() < end:
        said = do("ping", 0.8)
        if "pong" in said:
            break
        time.sleep(1)
    note("client: " + said)
    full = raw("gate")
    im = Image.open(full).convert("RGB")
    note(f"window picture {im.size}")
    im.save(OUT / "gate-window.png")
    LAST.unlink(missing_ok=True)
    a = shot("gate-a")
    note(do("close|1|" + "|".join(str(v) for v in CLOSE), 2.5))
    time.sleep(1.5)
    b = shot("gate-b")
    note(do("unclose", 1))
    note(f"live: {a.name} and {b.name} differ")
    save_log()


# a sub over the stand: its turn, where it floats, where the camera stands, what it looks at (from the stand), fov
CLOSE = [55, 0, 40, -6, -22, 30, -74, 0, 30, -6, 50]


def closes(tiers, close=None):
    """each sub beside the stand with its name sign, the screens out of the picture; the same camera for all nine"""
    close = close or CLOSE
    note(do("hud|off", 1))
    for n in tiers or range(1, 10):
        said = do(f"close|{n}|" + "|".join(str(v) for v in close), 2.5)
        note(said)
        if f'sign="{NAMES[n - 1].upper()}"' not in said:
            note(f"  ! tier {n}'s sign does not read {NAMES[n - 1].upper()}")
        time.sleep(1.6)
        shot(f"stand-{n}")
    note(do("unclose", 1))
    note(do("hud|on", 1))
    save_log()


def shop(tag):
    """the stand's shop: the cards' read-out and stills, at PC size and at a phone's"""
    note("equip: " + s2.cmd("sub|5,6", 1.5))
    note(do("near", 1.5))
    for size, phone in (("pc", None), ("phone", PHONE)):
        note(do("phone|%d|%d" % phone if phone else "phone|off", 1))
        said = do("shop|on", 2)
        note(said)
        if "enabled=true" not in said:
            save_log()
            raise SystemExit("the shop did not open")
        note(f"cards, {size}, {tag}:\n" + do("cards", 1.5))
        for first in (0, 3, 6, 9):
            said = do(f"scroll|{first}", 1)
            note(said)
            if "enabled=true" not in said:
                save_log()
                raise SystemExit("the shop closed itself")
            time.sleep(1.4)
            shot(f"shop-{tag}-{size}-{first}")
        note(do("shop|off", 1.5))
    note(do("phone|off", 1))
    note("home: " + s2.cmd("home", 2))
    save_log()


def trip(tier, close):
    """a real trip on one tier to its own land; a still about 1.3 s into the Ride (the game's own view, or ours)"""
    land = tier + 1
    kind = "close" if close else "ride"
    for attempt in range(2):
        note(f"tier {tier} to land {land} ({kind}): " + s2.cmd(f"sub|{tier},{land}", 1.5))
        note("  " + do("rcam|on" if close else "rcam|off", 0.5))
        note("  " + t3.do("watch", 0.4))
        note("  dive: " + s2.cmd("dive", 0.3))
        still, st = None, ""
        end = time.time() + 30
        while time.time() < end:
            st = s2.cmd("st", 0.15)
            if "phase=Ride" in st:
                # (the shortest Ride is 3.2 s: the phase is read again just before the still, not after it)
                time.sleep(0.7)
                st = s2.cmd("st", 0.1)
                still = shot(f"{kind}-{tier}", tries=1, least=0.0)
                break
        note("  just before the still: " + st)
        time.sleep(6)
        note("  numbers: " + t3.do("read", 0.5))
        note("  " + do("rcam|off", 0.5))
        note("  home: " + s2.cmd("home", 3))
        time.sleep(1.5)
        if still and "phase=Ride" in st:
            return still
        note(f"  ! tier {tier}'s still was not in the Ride ({st}); once more")
    return None


def rides(tiers, kinds=("ride", "close")):
    for tier in tiers or range(1, 10):
        for kind in kinds:
            trip(tier, kind == "close")
    save_log()


def font(size):
    try:
        return ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", size)
    except OSError:
        return ImageFont.load_default()


def sheet(paths, labels, out, cols=3, width=880, crop=None, title=None):
    """stills tiled into one picture, each under its label"""
    tiles = []
    for p in paths:
        im = Image.open(p).convert("RGB")
        if crop:
            w, h = im.size
            im = im.crop((round(crop[0] * w), round(crop[1] * h), round(crop[2] * w), round(crop[3] * h)))
        tiles.append(im.resize((width, round(im.height * width / im.width)), Image.LANCZOS))
    h = max(t.height for t in tiles)
    rows = -(-len(tiles) // cols)
    head = 64 if title else 0
    page = Image.new("RGB", (cols * width, head + rows * (h + 44)), (16, 24, 40))
    d = ImageDraw.Draw(page)
    if title:
        d.text((14, 12), title, font=font(38), fill=(255, 214, 70))
    for i, t in enumerate(tiles):
        x, y = (i % cols) * width, head + (i // cols) * (h + 44)
        d.text((x + 12, y + 5), labels[i], font=font(30), fill=(255, 255, 255))
        page.paste(t, (x, y + 44))
    page.save(out)
    return out


if __name__ == "__main__":
    what = sys.argv[1]
    rest = sys.argv[2:]
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(True))
    elif what == "gate":
        gate()
    elif what == "closes":
        # closes [tier ...] [-- turn sx sy sz cx cy cz ax ay az fov]: the numbers after -- try another view
        cut = rest.index("--") if "--" in rest else len(rest)
        closes([int(a) for a in rest[:cut]], [float(a) for a in rest[cut + 1:]] or None)
    elif what == "shop":
        shop(rest[0])
    elif what == "rides":
        kinds = tuple(a for a in rest if not a.isdigit()) or ("ride", "close")
        rides([int(a) for a in rest if a.isdigit()], kinds)
    elif what == "do":
        print(do(rest[0], float(rest[1]) if len(rest) > 1 else 1.4))
