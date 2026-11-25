"""The auras' draft sheet (task a1, Shared/Auras, Controllers/AuraController): stills from the real game in a playtest.
    python tools/studio/aura_capture.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    python tools/studio/aura_capture.py rigs               (in a playtest: 15 copies of the player on a stage, high up)
    python tools/studio/aura_capture.py auras [tier ...]   (one still a tier, clock held)
    python tools/studio/aura_capture.py spawns             (three moments of each spawn-in)
    python tools/studio/aura_capture.py sheet              (lays the stills out: docs/attachments/auras-draft-1.png)
    python tools/studio/aura_capture.py sheet2             (draft 2: before | after for each tier, the spawn-ins)
    python tools/studio/aura_capture.py gif 9 12           (a GIF of a tier, clock and particles slowed while shot)
    python tools/studio/aura_capture.py clean              (the stage away, clock and camera let go)
How: AuraController draws any Model tagged "AuraRig" by its "Aura" attribute (Studio only), on workspace "AuraClock"
when it is a number; a rig's "SpawnAt" plays its "SpawnStyle" from then. The server Script builds the rigs (copies of
the player's character, anchored, scripts out) in a row on a dark stage 400 studs over the player; the LocalScript holds
the camera on workspace "A1Cam". Frames go to work/aura_capture/. Needs Studio with the studio-runner plugin and Rojo.
"""
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/aura_capture"
OUT.mkdir(parents=True, exist_ok=True)
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
# the game view inside the Studio window's shot (2400 x 1280, panels on the right)
CROP = (4, 142, 1984, 1205)

TIERS = [
    (1.5, "Bubble"), (2, "Shell"), (2.5, "Tide"), (3, "Current"), (3.5, "Reef"), (4, "Storm"),
    (5, "Moon"), (6, "Lantern"), (7, "Ember"), (8, "Urchin"), (10, "Abyss"), (12, "Leviathan"),
]
SPAWNS = [
    ("Splash", [0.18, 0.4, 0.8]),
    ("Whirlpool", [0.4, 0.9, 1.3]),
    ("Drop", [0.43, 0.56, 1.0]),
]
# the clock each tier is shot at (a moment where its motion reads: the storm's bolts on, the wave's crest in front)
CLOCK = {i: 100.0 for i in range(1, 13)}
CLOCK.update({3: 100.5, 6: 100.05, 11: 100.12})

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CS = game:GetService("CollectionService")
local stage
RS:GetAttributeChangedSignal("A1Cmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("A1Cmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local ok, said = pcall(function()
		local player = Players:GetPlayers()[1]
		if verb == "rigs" then
			if stage then stage:Destroy() end
			stage = Instance.new("Folder")
			stage.Name = "A1Stage"
			stage.Parent = workspace
			local char = player.Character
			local root = char.HumanoidRootPart
			local origin = root.Position + Vector3.new(0, 400, 0)
			char.Archivable = true
			for i = 1, 15 do
				local at = origin + Vector3.new((i - 8) * 40, 0, 0)
				local floor = Instance.new("Part")
				floor.Anchored = true
				floor.Size = Vector3.new(40, 1, 40)
				floor.Color = Color3.fromRGB(28, 40, 70)
				floor.Material = Enum.Material.SmoothPlastic
				floor.Position = at - Vector3.new(0, root.Size.Y / 2 + char.Humanoid.HipHeight + 0.5, 0)
				floor.Parent = stage
				local wall = Instance.new("Part")
				wall.Anchored = true
				wall.Size = Vector3.new(40, 60, 1)
				wall.Color = Color3.fromRGB(16, 24, 46)
				wall.Material = Enum.Material.SmoothPlastic
				wall.Position = at + Vector3.new(0, 10, 16)
				wall.Parent = stage
				local rig = char:Clone()
				for _, d in rig:GetDescendants() do
					if d:IsA("BaseScript") or d:IsA("ForceField") then
						d:Destroy()
					elseif d:IsA("BasePart") then
						d.Anchored = true
					end
				end
				rig.Name = "A1Rig" .. i
				rig:PivotTo(CFrame.lookAt(at, at + Vector3.new(0.35, 0, -1)))
				if i <= 12 then
					rig:SetAttribute("Aura", i)
				end
				CS:AddTag(rig, "AuraRig")
				rig.Parent = stage
			end
			-- the player under the stage, out of the way
			root.Anchored = true
			root.CFrame = CFrame.new(origin - Vector3.new(0, 30, 0))
			return "rigs at " .. tostring(origin)
		elseif verb == "cam" then
			local i = tonumber(arg)
			local rig = stage:FindFirstChild("A1Rig" .. i)
			local p = rig.HumanoidRootPart.Position
			local look = p + Vector3.new(0, 1, 0)
			workspace:SetAttribute("A1Cam", CFrame.lookAt(p + Vector3.new(4.6, 2.6, -9.6), look))
			return "cam " .. i
		elseif verb == "spawn" then
			local i, style, at = string.match(arg, "(%d+),(%d+),([%d%.]+)")
			local rig = stage:FindFirstChild("A1Rig" .. i)
			rig:SetAttribute("SpawnStyle", tonumber(style))
			rig:SetAttribute("SpawnAt", tonumber(at))
			return "spawn " .. i
		elseif verb == "clean" then
			if stage then stage:Destroy() stage = nil end
			workspace:SetAttribute("A1Cam", nil)
			workspace:SetAttribute("AuraClock", nil)
			if player and player.Character then player.Character.HumanoidRootPart.Anchored = false end
			return "clean"
		end
		return "?"
	end)
	RS:SetAttribute("A1Said", tostring(said) .. " " .. tostring(ok) .. " " .. tostring(os.clock()))
end)
'''

CLIENT = r'''
local RunService = game:GetService("RunService")
RunService:BindToRenderStep("A1Cam", Enum.RenderPriority.Camera.Value + 1, function()
	local cam = workspace:GetAttribute("A1Cam")
	local camera = workspace.CurrentCamera
	local gui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if gui and typeof(cam) == "CFrame" then
		for _, g in gui:GetChildren() do
			if g:IsA("ScreenGui") then
				g.Enabled = typeof(cam) ~= "CFrame"
			end
		end
	end
	if typeof(cam) == "CFrame" then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 70
		camera.CFrame = cam
	elseif camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
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
    job = f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZAuraCapture")
	if old then old:Destroy() end
end
if {lua(remove)} then return "removed" end
local s = Instance.new("Script")
s.Name = "ZZAuraCapture"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZAuraCapture"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def clock(t):
    return server(f"workspace:SetAttribute('AuraClock', {lua(t)}) return 'ok'")


def cmd(c):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('A1Cmd', {lua(c + '|' + str(time.time()))}) "
        "task.wait(0.3) return RS:GetAttribute('A1Said')"
    )


def shot(path):
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
    # the middle square of the game view
    w, h = im.size
    s = h
    return im.crop(((w - s) // 2, 0, (w + s) // 2, s))


def auras(which):
    for i in which:
        print(cmd(f"cam|{i}"))
        clock(None)  # real time, so trails and particles have moved
        time.sleep(1.5)
        im = shot(OUT / f"raw_{i:02d}.png")
        im.save(OUT / f"aura_{i:02d}.png")
        print("aura", i)


def spawns():
    for s, (name, moments) in enumerate(SPAWNS, start=1):
        rig = 12 + s
        print(cmd(f"cam|{rig}"))
        start = 500.0 + s * 10 + round(time.time() % 1000)
        clock(start - 1)
        print(cmd(f"spawn|{rig},{s},{start}"))
        time.sleep(1.2)
        # played at a tenth of real time (the clock and every emitter), each moment shot as the game reaches it
        slow, lead = 0.1, 0.15
        server(f"workspace:SetAttribute('AuraSlow', {slow}) workspace:SetAttribute('AuraClock', {start - lead}) return 1")
        t0 = time.time()
        for k, m in enumerate(moments):
            wait = t0 + (m + lead) / slow - 0.25 - time.time()
            if wait > 0:
                time.sleep(wait)
            im = shot(OUT / f"raw_s{s}{k}.png")
            im.save(OUT / f"spawn_{s}_{k}.png")
            print("spawn", name, m, "at", round((time.time() - t0) * slow - lead, 2))
        server("workspace:SetAttribute('AuraSlow', nil) return 1")


def font(size):
    for f in ("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
        if Path(f).exists():
            return ImageFont.truetype(f, size)
    return ImageFont.load_default(size=size)


def sheet():
    T = 300  # a tile
    pad, head = 10, 70
    cols = 6
    rows = 2
    W = cols * T + (cols + 1) * pad
    spawn_h = 40 + T
    H = head + rows * (T + pad) + pad + 50 + spawn_h + pad
    sh = Image.new("RGB", (W, H), (12, 16, 28))
    d = ImageDraw.Draw(sh)
    d.text((pad, 14), "Auras, draft 1: the twelve tiers (x multiplier, stand-in name), one frame each",
           fill="white", font=font(26))
    d.text((pad, 46), "From a Studio playtest (stand-in names from the economy draft). Everything moves in the game; these are single frames.",
           fill=(170, 180, 200), font=font(16))
    for n, (mult, name) in enumerate(TIERS):
        i = n + 1
        p = OUT / f"aura_{i:02d}.png"
        x = pad + (n % cols) * (T + pad)
        y = head + (n // cols) * (T + pad)
        if p.exists():
            sh.paste(Image.open(p).resize((T, T), Image.LANCZOS), (x, y))
        lab = f"x{mult:g}"
        d.text((x + 10, y + 8), lab, fill="white", font=font(34), stroke_width=3, stroke_fill="black")
        d.text((x + 10, y + T - 34), f"{i}. {name}", fill="white", font=font(22), stroke_width=3, stroke_fill="black")
    y0 = head + rows * (T + pad) + pad
    d.text((pad, y0 + 8), "Spawn-in, three versions (pick one): three moments each, left to right",
           fill="white", font=font(24))
    y = y0 + 50
    small = (W - pad * 4) // 3
    st = (small - pad * 2) // 3
    for s, (name, moments) in enumerate(SPAWNS, start=1):
        x0 = pad + (s - 1) * (small + pad)
        for k, m in enumerate(moments):
            p = OUT / f"spawn_{s}_{k}.png"
            x = x0 + k * (st + pad)
            if p.exists():
                sh.paste(Image.open(p).resize((st, st), Image.LANCZOS), (x, y + 30))
            d.text((x + 6, y + 34), f"{m:g} s", fill="white", font=font(16), stroke_width=2, stroke_fill="black")
        d.text((x0, y + 2), f"{s}. {name}", fill="white", font=font(22))
    sh = sh.crop((0, 0, W, y + 30 + st + pad))
    dest = ROOT / "docs/attachments/auras-draft-1.png"
    sh.save(dest)
    print(dest)


def sheet2():
    """Draft 2 (Hugo: particles round the body only): every tier before (draft 1) and after, and the new spawn-ins."""
    T = 228
    pad, head = 10, 78
    cols = 4  # pairs a row
    pair = 2 * T + 4
    W = cols * pair + (cols + 1) * pad
    rows = 3
    H = head + rows * (T + 34 + pad) + 60 + T + 40
    sh = Image.new("RGB", (W, H), (12, 16, 28))
    d = ImageDraw.Draw(sh)
    d.text((pad, 12), "Auras, draft 2: particles round the body only (nothing on the ground). Before | after",
           fill="white", font=font(26))
    d.text((pad, 46), "Left of each pair: draft 1. Right: draft 2. Stills from a Studio playtest; everything moves in the "
           "game. Names are the economy draft's stand-ins.", fill=(170, 180, 200), font=font(16))
    for n, (mult, name) in enumerate(TIERS):
        i = n + 1
        x = pad + (n % cols) * (pair + pad)
        y = head + (n // cols) * (T + 34 + pad)
        d.text((x, y + 2), f"x{mult:g}  {i}. {name}", fill="white", font=font(22))
        for k, pre in enumerate(("before", "aura")):
            p = OUT / f"{pre}_{i:02d}.png"
            if p.exists():
                im = Image.open(p).resize((T, T), Image.LANCZOS)
                if pre == "before":
                    im = Image.blend(im, Image.new("RGB", im.size, (12, 16, 28)), 0.35)
                sh.paste(im, (x + k * (T + 4), y + 30))
        d.text((x + 6, y + 34), "before", fill=(200, 200, 200), font=font(14), stroke_width=2, stroke_fill="black")
        d.text((x + T + 10, y + 34), "after", fill="white", font=font(16), stroke_width=2, stroke_fill="black")
    y0 = head + rows * (T + 34 + pad) + 6
    d.text((pad, y0), "Spawn-in, three versions (pick one), now particles only: three moments each, left to right",
           fill="white", font=font(22))
    y = y0 + 34
    small = (W - pad * 4) // 3
    st = (small - pad * 2) // 3
    for s, (name, moments) in enumerate(SPAWNS, start=1):
        x0 = pad + (s - 1) * (small + pad)
        d.text((x0, y), f"{s}. {name}", fill="white", font=font(20))
        for k, m in enumerate(moments):
            p = OUT / f"spawn_{s}_{k}.png"
            x = x0 + k * (st + pad)
            if p.exists():
                sh.paste(Image.open(p).resize((st, st), Image.LANCZOS), (x, y + 28))
            d.text((x + 6, y + 32), f"{m:g} s", fill="white", font=font(15), stroke_width=2, stroke_fill="black")
    sh = sh.crop((0, 0, W, y + 28 + st + pad))
    dest = ROOT / "docs/attachments/auras-draft-2.png"
    sh.save(dest)
    print(dest)


def gif(tier, seconds=1.6, slow=0.018, size=440):
    """A tier in motion: the game's clock and every emitter run at `slow` of real time, frames shot as fast as Studio
    gives them, each frame's length the game time that passed."""
    print(cmd(f"cam|{tier}"))
    server("workspace:SetAttribute('AuraSlow', nil) workspace:SetAttribute('AuraClock', nil) return 1")
    time.sleep(1.5)  # (the emitters fill at full speed first)
    server(f"workspace:SetAttribute('AuraSlow', {slow}) workspace:SetAttribute('AuraClock', 200) return 1")
    time.sleep(0.5)
    t0 = time.time()
    frames, stamps = [], []
    while (time.time() - t0) * slow < seconds:
        stamps.append(time.time())
        frames.append(shot(OUT / f"gif_{tier}_{len(frames):03d}.png").resize((size, size), Image.LANCZOS))
        print(f"\rframe {len(frames)}", end="", flush=True)
    print()
    server("workspace:SetAttribute('AuraSlow', nil) workspace:SetAttribute('AuraClock', nil) return 1")
    stamps.append(time.time())
    durations = [max(20, int((stamps[i + 1] - stamps[i]) * slow * 1000)) for i in range(len(frames))]
    mult, name = TIERS[tier - 1]
    for f in frames:
        ImageDraw.Draw(f).text((10, 8), f"x{mult:g} {name}", fill="white", font=font(24), stroke_width=3,
                               stroke_fill="black")
    pal = [f.quantize(colors=200, method=Image.MEDIANCUT, dither=Image.NONE) for f in frames]
    dest = ROOT / f"docs/attachments/auras-draft-2-{name.lower()}.gif"
    pal[0].save(dest, save_all=True, append_images=pal[1:], duration=durations, loop=0, optimize=True)
    print(dest, len(frames), "frames", sum(durations), "ms")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "sheet2":
        sheet2()
    elif a[0] == "gif":
        for t in a[1:]:
            gif(int(t))
    elif a[0] == "install":
        print(install())
    elif a[0] == "remove":
        print(install(True))
    elif a[0] == "rigs":
        print(cmd("rigs"))
    elif a[0] == "auras":
        auras([int(x) for x in a[1:]] or range(1, 13))
    elif a[0] == "spawns":
        spawns()
    elif a[0] == "sheet":
        sheet()
    elif a[0] == "clean":
        print(cmd("clean"))
