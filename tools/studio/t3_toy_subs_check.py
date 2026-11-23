"""The nine toy submarines in the game (task t3), every tier: the stand's line-up, the shop, and a real trip on each.
    python tools/subs/install.py runner                      (in Edit: the templates)
    python tools/studio/s2_subs_check.py push                (in Edit: SubModels and SubController into the open place)
    python tools/studio/t3_toy_subs_check.py install         (in Edit, before Play)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/t3_toy_subs_check.py run [tier ...]  (in the playtest: the numbers and the stills)
    python tools/studio/t3_toy_subs_check.py remove          (in Edit, after the stop; `run` can't: it is in the playtest)
It rides on s2_subs_check's server door (buy, equip, pick, dive, home) and adds its own LocalScript, which builds the
nine with the game's own SubModels.build and, on a trip, reads our own sub every frame of the Ride phase: the rider
against the seat, the propeller's turn, the wake, the lamp, the name sign.
Log: work/t3/check.log; stills work/t3/*.png, sheets docs/attachments/subs-toy-game-*.png (the s2-*.png voxel record
is left alone).
"""
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import s2_subs_check as s2  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/t3"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
NAMES = ["Bathtub", "Reef Runner", "Kelp Cruiser", "Wreck Diver", "Blue Streak", "Twilight Ray", "Midnight Hunter",
         "Vent Crawler", "Abyss King"]

CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local report = RS:WaitForChild("ZZS2Report")
local SubModels = require(RS:WaitForChild("Shared"):WaitForChild("SubModels"))
local line = nil
local function stand()
	local dock = workspace:FindFirstChild("Dock", true)
	local stations = dock and dock:FindFirstChild("Stations")
	local sub = stations and stations:FindFirstChild("Sub")
	return sub and sub:GetPivot().Position
end
local function template(tier)
	local folder = RS:FindFirstChild(SubModels.Templates)
	return folder and folder:FindFirstChild(SubModels.style(tier).Id)
end
-- what one built sub is made of (built at the origin, facing -Z)
local function made(n)
	local model, parts, prop, bubbles = SubModels.build(n)
	local hull, lamp, seat = model.PrimaryPart, model:FindFirstChild("Light"), model:FindFirstChild("Seat")
	local top, meshes, neon = -math.huge, 0, 0
	for _, p in parts do
		top = math.max(top, p.Position.Y + p.Size.Y / 2)
		if p:IsA("MeshPart") then meshes += 1 end
		if p.Material == Enum.Material.Neon then neon += 1 end
	end
	local sign = model:FindFirstChild("Label", true)
	local signLow = sign.Parent.Position.Y + sign.StudsOffsetWorldSpace.Y - sign.Size.Y.Scale / 2
	local beam = lamp:FindFirstChildOfClass("SpotLight")
	local text = string.format(
		"%d:%s hullMesh=%s parts=%d mesh=%d neon=%d top=%.1f signLow=%.1f gap=%.1f seatTopBox=%.1f lampZ=%.1f beam=%s wakeOn=%s propGlow=%s",
		n, SubModels.style(n).Id, tostring(hull:IsA("MeshPart")), #parts, meshes, neon, top, signLow, signLow - top,
		seat.Position.Y + seat.Size.Y / 2, lamp.Position.Z, tostring(beam ~= nil and beam.Enabled),
		tostring(bubbles.Parent == prop and bubbles.Enabled), tostring(model:FindFirstChild("Prop_Glow") ~= nil))
	return model, parts, text
end
-- our own trip's sub, read every frame of the Ride phase
local watch = nil
RunService.RenderStepped:Connect(function(dt)
	local w = watch
	if not w or player:GetAttribute("SubPhase") ~= "Ride" then return end
	local found = nil
	for _, m in workspace.CurrentCamera:GetChildren() do
		if m.Name == "Submarine" and m:GetAttribute("For") == player.UserId then found = m end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not found or not root then return end
	local tier = found:GetAttribute("Tier")
	local t = template(tier)
	local hull, seat, prop, lamp = found.PrimaryPart, found:FindFirstChild("Seat"), found:FindFirstChild("Prop"), found:FindFirstChild("Light")
	if not (t and hull and seat and prop and lamp) then
		w.bad = "tier " .. tostring(tier) .. " template=" .. tostring(t ~= nil) .. " hullMesh=" .. tostring(hull and hull:IsA("MeshPart"))
		return
	end
	-- the sub's own frame (its middle): the hull part sits in it where the template's does
	local sub = hull.CFrame * t.Hull.CFrame:Inverse()
	local rider = sub:PointToObjectSpace(root.Position)
	local seatAt = sub:PointToObjectSpace(seat.Position) - t.Seat.Position
	local propIn = sub:ToObjectSpace(prop.CFrame)
	local propOff = (propIn.Position - t.Prop.Position).Magnitude
	local angle = math.atan2(propIn.RightVector.Y, propIn.RightVector.X)
	local axis = math.abs(propIn.LookVector.Z) -- 1: still turning about the sub's own long axis
	w.n += 1
	w.tier, w.mesh = tier, hull:IsA("MeshPart")
	w.rider = rider
	w.riderMax = math.max(w.riderMax, (rider - Vector3.new(0, 7.4, 5)).Magnitude)
	w.seatMax = math.max(w.seatMax, seatAt.Magnitude)
	w.propMax = math.max(w.propMax, propOff)
	w.axisMin = math.min(w.axisMin, axis)
	if w.angle then
		local d = (angle - w.angle + math.pi) % (2 * math.pi) - math.pi
		w.turned += math.abs(d)
		w.time += dt
		if math.abs(d) < 0.02 then w.still += 1 end -- a frame on which the propeller did not turn
	end
	w.angle = angle
	local glow = found:FindFirstChild("Prop_Glow")
	if glow then
		w.glowMax = math.max(w.glowMax, (sub:PointToObjectSpace(glow.Position) - t.Prop_Glow.Position).Magnitude)
	end
	local wake = prop:FindFirstChild("Wake")
	if wake then
		w.wakeMin, w.wakeMax = math.min(w.wakeMin, wake.Rate), math.max(w.wakeMax, wake.Rate)
	end
	-- the frames on which each of these was wrong (0: right on every frame of the run)
	if not (wake and wake.Enabled and wake.Parent == prop) then w.wakeOff += 1 end
	local beam = lamp:FindFirstChildOfClass("SpotLight")
	if not (beam and beam.Enabled and lamp.Material == Enum.Material.Neon and lamp.Transparency < 0.5) then w.beamOff += 1 end
	w.beamDot = math.min(w.beamDot, lamp.CFrame.LookVector:Dot(sub.LookVector))
	w.lampAhead = -sub:PointToObjectSpace(lamp.Position).Z
	local sign = found:FindFirstChild("Label", true)
	if not (sign and sign.Enabled) then w.signOff += 1 end
	local move = root.AssemblyLinearVelocity
	if move.Magnitude > 1 then w.nose = math.min(w.nose, sub.LookVector:Dot(move.Unit)) end
	w.speed = math.max(w.speed, move.Magnitude)
end)
workspace:GetAttributeChangedSignal("T3Do"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("T3Do") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local ok, said = pcall(function()
		if verb == "made" then
			-- every tier's make-up, by the numbers (nothing left in the world)
			local out = {}
			for n = 1, 9 do
				local model, _, text = made(n)
				model:Destroy()
				table.insert(out, text)
			end
			return table.concat(out, "\n")
		elseif verb == "line" then
			-- beside the stand: all nine in three rows of three, or one close, each with its name sign
			if line then line:Destroy() end
			line = Instance.new("Folder")
			line.Name = "T3Line"
			line.Parent = workspace
			local at = stand() or Vector3.new(0, 20, 0)
			local only = tonumber(arg)
			if only == 0 then only = nil end
			for n = 1, 9 do
				if not only or only == n then
					local model, parts = made(n)
					local col, row = (n - 1) % 3, (n - 1) // 3
					local where = if only then CFrame.new(at + Vector3.new(0, 30, 0))
						else CFrame.new(at + Vector3.new((col - 1) * 62, 34 + (1 - row) * 36, 0))
					local turn = where * CFrame.Angles(0, math.rad(-125), 0)
					for _, p in parts do
						p.CFrame = turn * p.CFrame
					end
					model.Parent = line
				end
			end
			local cam = workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Scriptable
			local mid = at + Vector3.new(0, if only then 32 else 36, 0)
			cam.CFrame = CFrame.lookAt(mid + (if only then Vector3.new(-34, 16, -60) else Vector3.new(-40, 22, -205)), mid)
			cam.FieldOfView = 50
			return "lined " .. tostring(only or "all")
		elseif verb == "unline" then
			if line then line:Destroy() line = nil end
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			workspace.CurrentCamera.FieldOfView = 70
			return "unlined"
		elseif verb == "watch" then
			watch = { n = 0, riderMax = 0, seatMax = 0, propMax = 0, glowMax = 0, axisMin = 1, turned = 0, time = 0,
				still = 0, wakeMin = math.huge, wakeMax = 0, wakeOff = 0, beamOff = 0, signOff = 0, beamDot = 1, nose = 1,
				speed = 0 }
			return "watching"
		elseif verb == "read" then
			local w = watch
			if not w then return "no watch" end
			if w.bad then return "BAD " .. w.bad end
			if w.n == 0 then return "frames=0" end
			return string.format(
				"frames=%d tier=%s hullMesh=%s rider=%.2f,%.2f,%.2f riderOffMax=%.2f seatOffMax=%.2f propOffMax=%.3f glowOffMax=%.3f propAxisMin=%.3f propStillFrames=%d wake=%.0f..%.0f wakeOffFrames=%d beamOffFrames=%d beamDotMin=%.2f lampAhead=%.1f signOffFrames=%d noseMin=%.2f topSpeed=%.0f",
				w.n, tostring(w.tier), tostring(w.mesh), w.rider.X, w.rider.Y, w.rider.Z, w.riderMax, w.seatMax, w.propMax,
				w.glowMax, w.axisMin, w.still, w.wakeMin, w.wakeMax, w.wakeOff, w.beamOff, w.beamDot, w.lampAhead or 0,
				w.signOff, w.nose, w.speed)
		end
		return "?"
	end)
	report:FireServer(tostring(said) .. " " .. tostring(ok))
end)
'''


def install(remove=False):
    out = s2.install(remove)
    return out + " / " + s2.job(f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZT3Check")
if old then old:Destroy() end
workspace:SetAttribute("T3Do", nil)
workspace:SetAttribute("S2Do", nil)
game:GetService("ReplicatedStorage"):SetAttribute("S2Cmd", nil)
if {s2.lua(remove)} then
	return "removed"
end
local c = Instance.new("LocalScript")
c.Name = "ZZT3Check"
c.Source = {s2.lua(CLIENT)}
c.Parent = sps
return "installed"
""")


def do(c, wait=1.4):
    return s2.server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('S2Client', '') "
        f"workspace:SetAttribute('T3Do', {s2.lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('S2Client')"
    )


STILLS = True  # off once the window's pictures are found frozen


def shot(name):
    """one still of the game view, into work/t3 (the runner's `shot` returns before the file is written)"""
    if not STILLS:
        return None
    full = OUT / (name + "-full.png")
    full.unlink(missing_ok=True)
    out = s2.run(["shot", str(full)], timeout=60)
    size, end = -1, time.time() + 10
    while time.time() < end:
        now = full.stat().st_size if full.exists() else -1
        if now > 0 and now == size:
            break
        size = now
        time.sleep(0.15)
    else:
        raise SystemExit("no shot: " + out)
    im = Image.open(full).convert("RGB")
    im = im.crop((s2.OFFSET[0], s2.OFFSET[1], s2.OFFSET[0] + s2.VIEW[0], s2.OFFSET[1] + s2.VIEW[1]))
    path = OUT / (name + ".png")
    im.save(path)
    full.unlink(missing_ok=True)
    return path


def sheet(paths, labels, out, cols=3, width=880):
    """stills tiled into one picture, each under its label"""
    try:
        font = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 30)
    except OSError:
        font = ImageFont.load_default()
    tiles = []
    for p in paths:
        im = Image.open(p).convert("RGB")
        tiles.append(im.resize((width, round(im.height * width / im.width)), Image.LANCZOS))
    h = max(t.height for t in tiles)
    rows = -(-len(tiles) // cols)
    page = Image.new("RGB", (cols * width, rows * (h + 44)), (16, 24, 40))
    d = ImageDraw.Draw(page)
    for i, t in enumerate(tiles):
        x, y = (i % cols) * width, (i // cols) * (h + 44)
        d.text((x + 12, y + 5), labels[i], font=font, fill=(255, 255, 255))
        page.paste(t, (x, y + 44))
    page.save(out)
    return out


LOG = []


def note(text):
    print(text, flush=True)
    LOG.append(text)


def ride(tier):
    """a real trip on one tier, to its own land: the numbers of every frame of the run, and one still of it"""
    land = tier + 1
    note(f"tier {tier} to land {land}: " + s2.cmd(f"sub|{tier},{land}", 1.5))
    note("  " + do("watch", 0.4))
    note("  dive: " + s2.cmd("dive", 0.3))
    still = None
    end = time.time() + 30
    while time.time() < end:
        st = s2.cmd("st", 0.15)
        if "phase=Ride" in st:
            time.sleep(0.5)
            still = shot(f"ride-{tier}")
            break
    if not still and STILLS:
        note("  NO RIDE: " + st)
    time.sleep(6)
    note("  ride: " + do("read", 0.5))
    note("  home: " + s2.cmd("home", 3))
    time.sleep(1)
    return still


def checks(tiers):
    global STILLS
    time.sleep(6)
    if not tiers:
        note("made:\n" + do("made", 3))
        # Studio's window off the screen or covered gives the same old picture every time: the camera is moved
        # between two stills, and if they come out alike no still is kept (the numbers still run)
        before = shot("before")
        note(do("line|0", 3))
        time.sleep(2)
        lineup = shot("lineup")
        if list(Image.open(before).getdata()) == list(Image.open(lineup).getdata()):
            STILLS = False
            note("  ! Studio's window is frozen (off the screen or covered): no stills this run")
        else:
            Image.open(lineup).save(ATTACH / "subs-toy-game-lineup.png")
            note(f"shot: {ATTACH / 'subs-toy-game-lineup.png'}")
        closes = []
        for n in range(1, 10):
            note(do(f"line|{n}", 2))
            time.sleep(1)
            closes.append(shot(f"close-{n}"))
        note(do("unline", 1))
        if STILLS:
            labels = [f"{n} {NAMES[n - 1]}" for n in range(1, 10)]
            note("sheet: %s" % sheet(closes, labels, ATTACH / "subs-toy-game-close.png"))
        note(s2.do("shop|on", 2.5))
        shop = shot("shop")
        if shop:
            Image.open(shop).save(ATTACH / "subs-toy-game-shop.png")
            note(f"shot: {ATTACH / 'subs-toy-game-shop.png'}")
        note(s2.do("shop|off", 1))
    else:
        # a run of chosen tiers: the same guard, by a turn of the camera
        before = shot("before")
        note(do("line|1", 2))
        time.sleep(1)
        after = shot("after")
        note(do("unline", 1))
        if list(Image.open(before).getdata()) == list(Image.open(after).getdata()):
            STILLS = False
            note("  ! Studio's window is frozen (off the screen or covered): no stills this run")
    stills = {}
    for tier in tiers or range(1, 10):
        stills[tier] = ride(tier)
    have = [t for t in sorted(stills) if stills[t]]
    if len(have) == 9:
        note("sheet: %s" % sheet([stills[t] for t in have], [f"{t} {NAMES[t - 1]}, on the run" for t in have],
                                 ATTACH / "subs-toy-game-rides.png"))
    with open(OUT / "check.log", "a", encoding="utf-8") as f:
        f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(True))
    elif what == "run":
        checks([int(a) for a in sys.argv[2:]])
