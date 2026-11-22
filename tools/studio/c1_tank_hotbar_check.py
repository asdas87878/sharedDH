"""The tank's hover outline and click, and the hotbar back to seven slots (task c1): checked and pictured in a playtest.
    python tools/studio/c1_tank_hotbar_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/c1_tank_hotbar_check.py run                (in the playtest: the checks and the stills)
How: the server Script puts fish in the player's hands (RideService.giveCarried), stands the player in front of their
tank (AquariumService.frontOf) and reports the server's side. The LocalScript points the camera at the tank, puts a
pretend mouse on the tank (Client.UI.TankPanel.pretendMouse: the very hover path, Studio only), clicks it through
TankPanel.click (the path a real click takes), presses keys through EquipController.press and reads the hotbar's
frames. Log: work/c1/check.log; shots docs/attachments/c1-*.png, each beside the one it replaces.
Needs Studio open with the studio-runner plugin and Rojo serving this repo.
"""
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/c1"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
OFFSET = (0, 125)  # the game view in the shot (as e3_equip_check.py)
VIEW = [1985, 1085]

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local AquariumService = require(Services:WaitForChild("AquariumService"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZC1Report"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("C1Client", tostring(text))
end)
RS:GetAttributeChangedSignal("C1Cmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("C1Cmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local ok, said = pcall(function()
		if verb == "setup" then
			for _, f in game:GetService("HttpService"):JSONDecode(arg) do
				RideService.giveCarried(player, { Id = f[1], Size = f[2], Variant = f[3] })
			end
			return "hands " .. #RideService.carried(player)
		elseif verb == "clear" then
			while #RideService.carried(player) > 0 do
				RideService.takeCarried(player, 1)
			end
			return "hands 0"
		elseif verb == "front" then
			local plot = AquariumService.plotOf(player)
			local spot = plot and AquariumService.frontOf(plot)
			if not spot then
				return "no plot"
			end
			player.Character:PivotTo(spot + Vector3.new(0, 3, 0))
			return "front of " .. plot.Name
		elseif verb == "spawn" then
			local spawn = workspace.ClaudeBlockout.Dock.DockSpawn
			player.Character:PivotTo(CFrame.new(spawn.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.rad(180), 0))
			return "at spawn"
		elseif verb == "state" then
			local list = player:GetAttribute("TankList") or "[]"
			return string.format("state=%s hands=%d tank=%d held=%s eq=%s",
				tostring(RideService.stateOf(player)), #RideService.carried(player),
				#game:GetService("HttpService"):JSONDecode(list), tostring(player:GetAttribute("HeldFish")),
				tostring(player:GetAttribute("EquippedFish")))
		end
		return "?"
	end)
	RS:SetAttribute("C1Said", tostring(said) .. " " .. tostring(ok))
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local TankPanel = require(Client:WaitForChild("UI"):WaitForChild("TankPanel"))
local Slots = require(Client.UI:WaitForChild("Slots"))
local EquipController = require(Client:WaitForChild("Controllers"):WaitForChild("EquipController"))
local report = RS:WaitForChild("ZZC1Report", 60)
local function water()
	local name = player:GetAttribute("Plot")
	local plot = workspace.ClaudeBlockout.Dock.Plots:FindFirstChild(tostring(name))
	return plot and plot:FindFirstChild("TankWater")
end
local function hotbar()
	local gui = player.PlayerGui:FindFirstChild("Slots", true)
	if not gui then
		return "no slots"
	end
	local view = workspace.CurrentCamera.ViewportSize
	local eq = gui:FindFirstChild("Equipped", true)
	local hint = gui:FindFirstChild("Hint")
	local keys, numbered = {}, 0
	for _, d in gui:GetDescendants() do
		if d.Name == "Key" and d:IsA("TextLabel") and d.Visible then
			table.insert(keys, d.Text)
		end
	end
	table.sort(keys)
	for _, d in gui:GetChildren() do
		if d:IsA("GuiObject") and d ~= eq and d.Name ~= "Hint" and d.AbsoluteSize.X > 30 and d.AbsoluteSize.X == d.AbsoluteSize.Y then
			numbered += 1
		end
	end
	local mid = gui.AbsolutePosition.X + gui.AbsoluteSize.X / 2
	return string.format(
		"numbered=%d keys=%s rowW=%d rowMidOff=%.1f eqRight=%d rowLeft=%d hintLeft=%d hintFits=%s hint=%q",
		numbered, table.concat(keys, ""), gui.AbsoluteSize.X, mid - view.X / 2,
		if eq then eq.AbsolutePosition.X + eq.AbsoluteSize.X else -1, gui.AbsolutePosition.X,
		if hint then hint.AbsolutePosition.X else -1, tostring(hint ~= nil and hint.TextFits),
		hint and hint.Text or "?")
end
workspace:GetAttributeChangedSignal("C1Do"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("C1Do") or "")
	local verb, a = string.match(cmd, "^(%w+)|?([^|]*)")
	local said = ""
	local camera = workspace.CurrentCamera
	if verb == "cam" then
		-- behind the player, up a little, looking at the tank's middle
		local w = water()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if w and root then
			local way = (root.Position - w.Position) * Vector3.new(1, 0, 1)
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(root.Position + way.Unit * 55 + Vector3.new(0, 26, 0), w.Position)
			said = "cam set"
		end
	elseif verb == "free" then
		camera.CameraType = Enum.CameraType.Custom
		TankPanel.pretendMouse(nil)
		said = "free"
	elseif verb == "hover" then
		local w = water()
		local p = camera:WorldToViewportPoint(w.Position)
		TankPanel.pretendMouse(Vector2.new(p.X, p.Y))
		task.wait(0.5)
		local on, parts = TankPanel.outlined()
		local hl = player.PlayerGui:FindFirstChild("TankHover")
		said = string.format("outlined=%s parts=%d fill=%s colour=%s", tostring(on), parts,
			tostring(hl and hl.SurfaceTransparency), tostring(hl and hl.Color3))
	elseif verb == "off" then
		TankPanel.pretendMouse(Vector2.new(20, camera.ViewportSize.Y / 2))
		task.wait(0.4)
		local on = TankPanel.outlined()
		said = "outlined=" .. tostring(on)
	elseif verb == "other" then
		-- another plot's water: hovering it outlines nothing, clicking it opens nothing
		local mine = water()
		local other
		for _, plot in workspace.ClaudeBlockout.Dock.Plots:GetChildren() do
			local w = plot:FindFirstChild("TankWater")
			if w and w ~= mine then
				other = w
				break
			end
		end
		if other then
			camera.CFrame = CFrame.lookAt(other.Position + other.CFrame.LookVector * 70 + Vector3.new(0, 20, 0), other.Position)
			local p = camera:WorldToViewportPoint(other.Position)
			TankPanel.pretendMouse(Vector2.new(p.X, p.Y))
			task.wait(0.4)
			local on = TankPanel.outlined()
			local s = camera:WorldToScreenPoint(other.Position)
			local clicked = TankPanel.click(s.X, s.Y)
			said = string.format("otherOutlined=%s otherClick=%s open=%s", tostring(on), tostring(clicked), tostring(TankPanel.isOpen()))
		end
	elseif verb == "click" then
		local w = water()
		local s = camera:WorldToScreenPoint(w.Position)
		local hit = TankPanel.click(s.X, s.Y)
		task.wait(0.6)
		said = string.format("hit=%s open=%s", tostring(hit), tostring(TankPanel.isOpen()))
	elseif verb == "putin" then
		-- the popup's PUT IN on the first carried fish (its card's button sends just this)
		local Net = require(RS.Shared.Net)
		local hands = game:GetService("HttpService"):JSONDecode(player:GetAttribute("Hands") or "[]")
		if hands[1] then
			Net.Action:FireServer("Tank", "PutIn", 1, hands[1][1])
		end
		task.wait(1.5)
		said = "put in " .. tostring(hands[1] and hands[1][1])
	elseif verb == "close" then
		TankPanel.toggle(false)
		said = "open=" .. tostring(TankPanel.isOpen())
	elseif verb == "prompts" then
		local found = {}
		for _, d in player.PlayerGui:GetDescendants() do
			if d.Name == "TankPrompt" or d.Name == "TankHint" then
				table.insert(found, d.Name)
			end
		end
		said = "prompts=[" .. table.concat(found, ",") .. "]"
	elseif verb == "key" then
		EquipController.press(Enum.KeyCode[a])
		task.wait(0.7)
		said = "key " .. a
	elseif verb == "ui" then
		said = hotbar()
	elseif verb == "log" then
		-- the client's errors and warnings so far (a client error never reaches the server's log)
		local out = {}
		for _, e in game:GetService("LogService"):GetLogHistory() do
			if e.messageType == Enum.MessageType.MessageError or e.messageType == Enum.MessageType.MessageWarning then
				table.insert(out, (string.gsub(e.message, "%s+", " ")))
			end
		end
		said = "view=" .. tostring(workspace.CurrentCamera.ViewportSize) .. " caught=" .. tostring(#(require(Client.Lib.State).Caught or {})) .. " log: " .. table.concat(out, " || ", math.max(1, #out - 12))
	elseif verb == "phone" then
		Slots.place(a == "on")
		task.wait(0.2)
		said = hotbar()
	end
	report:FireServer(said .. " @" .. cmd)
end)
'''


def run(args, timeout=120):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    return "[==[" + str(v) + "]==]"


def server(code):
    return run(["--ctx", "server", "--code", code])


def install(remove=False):
    job = f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZC1Check")
	if old then old:Destroy() end
end
workspace:SetAttribute("C1Do", nil)
if {lua(remove)} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZC1Check"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZC1Check"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def cmd(c, wait=0.8):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('C1Cmd', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('C1Said')"
    )


def do(c, wait=1.4):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('C1Client', '') "
        f"workspace:SetAttribute('C1Do', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('C1Client')"
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
    return Image.open(path).convert("RGB")


def hotbar(name):
    im = shot(OUT / f"raw_hotbar_{name}.png")
    cx = OFFSET[0] + VIEW[0] // 2
    bottom = OFFSET[1] + VIEW[1]
    im.crop((cx - 560, bottom - 190, cx + 560, bottom)).save(ATTACH / f"c1-hotbar-{name}.png")


def scene(name):
    im = shot(OUT / f"raw_scene_{name}.png")
    im.crop((OFFSET[0], OFFSET[1], OFFSET[0] + VIEW[0], OFFSET[1] + VIEW[1])).resize((1280, 700)).save(
        ATTACH / f"c1-{name}.png"
    )


def beside(old, new, out, labels=("before (e3)", "now (c1)")):
    """two pictures stacked, each labelled"""
    a, b = Image.open(old).convert("RGB"), Image.open(new).convert("RGB")
    w = max(a.width, b.width)
    sheet = Image.new("RGB", (w, a.height + b.height + 60), (24, 26, 34))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 20)
    except OSError:
        font = ImageFont.load_default()
    draw.text((8, 4), labels[0], fill=(255, 255, 255), font=font)
    sheet.paste(a, (0, 30))
    draw.text((8, a.height + 34), labels[1], fill=(255, 255, 255), font=font)
    sheet.paste(b, (0, a.height + 60))
    sheet.save(out)


RESULTS = []


def check():
    log = []

    def note(text):
        print(text)
        log.append(text)

    def expect(name, ok, detail=""):
        RESULTS.append((name, ok))
        note(("PASS " if ok else "FAIL ") + name + (("  [" + detail + "]") if detail else ""))

    def kv(text, key):
        for part in text.replace("@", " ").split(" "):
            if part.startswith(key + "="):
                return part[len(key) + 1 :]
        return None

    # --- the hotbar
    note("clear: " + cmd("clear"))
    note("spawn: " + cmd("spawn", 1.2))
    u = do("ui")
    note("ui: " + u)
    expect("seven numbered slots, keys 1-7", kv(u, "numbered") == "7" and kv(u, "keys") == "1234567", u)
    # (the HUD is scaled to the screen: widths are compared with the slot's own, 7 x 46 + 6 x 10 = 382 points)
    expect("the row is centred on the screen", abs(float(kv(u, "rowMidOff"))) <= 1, u)
    desk_w = int(kv(u, "rowW"))
    expect("the Q slot stands left of the row, outside it", int(kv(u, "eqRight")) < int(kv(u, "rowLeft")), u)
    expect("the Q slot's hint fits and is on screen", kv(u, "hintFits") == "true" and int(kv(u, "hintLeft")) >= 0, u)
    hotbar("empty")
    hands = [["Clownfish", "Normal", ""], ["ReefShark", "Normal", ""], ["YellowTang", "Normal", ""], ["Pufferfish", "Big", "Silver"]]
    note("setup: " + cmd("setup|" + json.dumps(hands), 1.2))
    do("key|One")
    s = cmd("state")
    expect("key 1 holds the first catch", "held=Clownfish" in s, s)
    do("key|Eight")
    s = cmd("state")
    expect("key 8 (no slot now) does nothing", "held=Clownfish" in s, s)
    hotbar("holding")
    do("key|Q", 2.0)
    s = cmd("state")
    expect("Q equips the held fish", "eq=Clownfish" in s, s)
    hotbar("equipped")
    u = do("phone|on")
    note("phone: " + u)
    expect("phone: row 286 points wide against the keyboard's 382 (as before e3), centred; Q left of it; hint fits",
           abs(int(kv(u, "rowW")) / desk_w - 286 / 382) < 0.01 and abs(float(kv(u, "rowMidOff"))) <= 1 and int(kv(u, "eqRight")) < int(kv(u, "rowLeft")) and kv(u, "hintFits") == "true", u)
    hotbar("phone")
    do("phone|off")
    do("key|Q", 2.0)  # (off the land fish again)
    note("unequip state: " + cmd("state"))

    # --- the tank
    note("clear: " + cmd("clear"))
    note("setup: " + cmd("setup|" + json.dumps(hands[:3]), 1.2))
    note("front: " + cmd("front", 1.2))
    note("cam: " + do("cam"))
    p = do("prompts")
    expect("no prompt on the glass, no sign over the tank", kv(p, "prompts") == "[]", p)
    o = do("off")
    expect("not hovered: no outline", kv(o, "outlined") == "false", o)
    scene("tank-idle")
    h = do("hover")
    note("hover: " + h)
    expect("hovered: the whole tank outlined, no fill", kv(h, "outlined") == "true" and int(kv(h, "parts")) > 5 and kv(h, "fill") == "1", h)
    scene("tank-hover")
    note("putin: " + do("putin", 2.5))
    s = cmd("state")
    expect("the popup's PUT IN puts a carried fish in (server)", kv(s, "tank") == "1" and kv(s, "hands") == "2", s)
    note("front: " + cmd("front", 1.2))
    do("cam")
    s0 = cmd("state")
    c = do("click", 1.6)
    s1 = cmd("state")
    expect("a click opens the tank's popup", kv(c, "hit") == "true" and kv(c, "open") == "true", c)
    expect("a click puts no fish in by itself", kv(s0, "hands") == kv(s1, "hands") and kv(s0, "tank") == kv(s1, "tank"), s0 + " / " + s1)
    h = do("hover")
    expect("no outline while the popup is open", kv(h, "outlined") == "false", h)
    scene("tank-gui")
    do("close")
    other = do("other", 2.0)
    note("other: " + other)
    expect("another player's tank: no outline, no click", kv(other, "otherOutlined") == "false" and kv(other, "otherClick") == "false" and kv(other, "open") == "false", other)
    note("free: " + do("free"))
    note("clear: " + cmd("clear"))

    ok = all(r for _, r in RESULTS)
    note(f"{sum(1 for _, r in RESULTS if r)}/{len(RESULTS)} passed")
    (OUT / "check.log").write_text("\n".join(log) + "\n")
    for name in ("empty", "holding", "equipped"):
        old = ATTACH / f"e3-hotbar-{name}.png"
        if old.exists():
            beside(old, ATTACH / f"c1-hotbar-{name}.png", ATTACH / f"c1-hotbar-{name}-beside.png")
    beside(ATTACH / "e2-tank-click.png", ATTACH / "c1-tank-hover.png", ATTACH / "c1-tank-beside.png", ("before (e2)", "now (c1): hovered"))
    return ok


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "run"
    if what == "log":
        print(do("log", 2.0))
    elif what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
    else:
        sys.exit(0 if check() else 1)
