"""The inventory, take out, sell, the equip limit and the plot's five stages (task b1): checked and pictured in a playtest.
    python tools/studio/b1_inventory_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/b1_inventory_check.py run                (in the playtest: the checks and the stills)
How: the server Script gives coins and fish (AquariumService.give, RideService.giveCarried), stands the player at the
tank or at the plot's sign and reports the server's side (the tank's entries, the coins, the stage, the tank's parts).
The LocalScript fires the very remotes the popup's buttons and the sign's cash block fire (Action "Tank", "Sell",
"Plot"), presses the sign through UI.UpgradeSign.press (a click's own path), reads what the sign says, keeps the
server's answers (Ride "TankDenied", "Sold", "PlotUp", "PlotNo") and points the camera.
Log: work/b1/check.log; shots docs/attachments/b1-*.png.
Needs Studio open with the studio-runner plugin and this repo's code in the place (Rojo, or tools/ui/catch_show/sync_src.py).
"""
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/b1"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
OFFSET = (0, 125)  # the game view in the shot (as c1_tank_hotbar_check.py)
VIEW = [1985, 1085]

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local AquariumService = require(Services:WaitForChild("AquariumService"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZB1Report"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("B1Client", tostring(text))
end)
local function stand(player, cf)
	player.Character:PivotTo(cf)
	workspace:SetAttribute("B1Stand", cf) -- (the client owns its body: it moves it too)
end
RS:GetAttributeChangedSignal("B1Cmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("B1Cmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local ok, said = pcall(function()
		local plot = AquariumService.plotOf(player)
		if verb == "hands" then
			for _, f in Http:JSONDecode(arg) do
				RideService.giveCarried(player, { Id = f[1], Size = f[2], Variant = f[3] })
			end
			return "hands " .. #RideService.carried(player)
		elseif verb == "clear" then
			while #RideService.carried(player) > 0 do
				RideService.takeCarried(player, 1)
			end
			return "hands 0"
		elseif verb == "give" then
			local a = Http:JSONDecode(arg)
			AquariumService.give(player, a[1], a[2])
			return "given"
		elseif verb == "zero" then
			-- (the coins to nothing, so a price is checked to the coin)
			AquariumService.spend(player, AquariumService.coinsOf(player))
			return "coins " .. AquariumService.coinsOf(player)
		elseif verb == "front" then
			local spot = AquariumService.frontOf(plot)
			stand(player, spot + Vector3.new(0, 3, 0))
			return "front of " .. plot.Name
		elseif verb == "sign" then
			local board = plot.PlotBoard
			local at = board.Position + board.CFrame.LookVector * 6
			stand(player, CFrame.lookAt(Vector3.new(at.X, board.Position.Y, at.Z), board.Position))
			return "at the sign"
		elseif verb == "spawn" then
			local spawn = workspace.ClaudeBlockout.Dock.DockSpawn
			stand(player, CFrame.new(spawn.Position + Vector3.new(0, 4, 0)))
			return "at spawn"
		elseif verb == "state" then
			local fish = AquariumService.tankOf(player) or {}
			local on, firstOn, firstOff = 0, "", ""
			for _, f in fish do
				if f.On then
					on += 1
					if firstOn == "" then firstOn = f.Key end
				elseif firstOff == "" then
					firstOff = f.Key
				end
			end
			local water = plot.TankWater
			local rim = plot:FindFirstChild("RimEnd")
			local signBoard = plot:FindFirstChild("SignBoard")
			local shown = AquariumService.shownOf(player)
			local held = RideService.carried(player)
			return string.format(
				"state=%s hands=%d tank=%d on=%d coins=%s income=%s stage=%s most=%s firstOn=%s firstOff=%s waterH=%.2f waterBottom=%.2f rimY=%.2f signY=%.2f shown=%d hand1=%s",
				tostring(RideService.stateOf(player)), #held, #fish, on,
				tostring(AquariumService.coinsOf(player)), tostring(player:GetAttribute("Income")),
				tostring(player:GetAttribute("PlotStage")), tostring(player:GetAttribute("TankEarning")),
				firstOn, firstOff, water.Size.Y, water.Position.Y - water.Size.Y / 2,
				rim and rim.Position.Y or -1, signBoard and signBoard.Position.Y or -1,
				shown and #shown:GetChildren() or 0, held[1] and held[1].Id or "")
		elseif verb == "board" then
			-- where the plot's sign stands, in the tank's own frame as one faces it (x: minus is left; z: in front)
			local water, board, pad = plot.TankWater, plot:FindFirstChild("PlotBoard"), plot.Pad
			if not board then
				return "board=none"
			end
			local way = ((pad.Position - water.Position) * Vector3.new(1, 0, 1)).Unit
			local left = way:Cross(Vector3.yAxis)
			local off = board.Position - water.Position
			local seahorse = plot:FindFirstChild("UpgradeBoard")
			return string.format(
				"board=yes left=%.1f ahead=%.1f halfWide=%.1f halfDeep=%.1f faces=%.2f size=%s seahorseSize=%s post=%s",
				off:Dot(left), off:Dot(way), water.Size.X / 2, water.Size.Z / 2, board.CFrame.LookVector:Dot(way),
				tostring(board.Size), tostring(seahorse and seahorse.Size), tostring(plot:FindFirstChild("PlotPost") ~= nil))
		elseif verb == "price" then
			local a = Http:JSONDecode(arg)
			return "price=" .. Config.sellOf(Config.FishById[a[1]], a[2], a[3])
		end
		return "?"
	end)
	RS:SetAttribute("B1Said", tostring(said) .. " " .. tostring(ok))
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local player = Players.LocalPlayer
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local TankPanel = require(Client:WaitForChild("UI"):WaitForChild("TankPanel"))
local UpgradeSign = require(Client.UI:WaitForChild("UpgradeSign"))
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local report = RS:WaitForChild("ZZB1Report", 60)
local answers = {}
Net.Ride.OnClientEvent:Connect(function(what, a, b)
	if what == "TankDenied" or what == "Sold" or what == "PlotUp" or what == "PlotNo" then
		table.insert(answers, what .. ":" .. tostring(a) .. (if b ~= nil then ":" .. tostring(b) else ""))
	end
end)
workspace:GetAttributeChangedSignal("B1Stand"):Connect(function()
	local cf = workspace:GetAttribute("B1Stand")
	local character = player.Character
	if typeof(cf) == "CFrame" and character then
		character:PivotTo(cf)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end)
local function plot()
	return workspace.ClaudeBlockout.Dock.Plots:FindFirstChild(tostring(player:GetAttribute("Plot")))
end
local function signGui()
	return player.PlayerGui:FindFirstChild("PlotSign_" .. tostring(player:GetAttribute("Plot")))
end
local function took()
	local out = table.concat(answers, ",")
	table.clear(answers)
	return "answers=[" .. out .. "]"
end
workspace:GetAttributeChangedSignal("B1Do"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("B1Do") or "")
	local verb, a = string.match(cmd, "^(%w+)|?([^|]*)")
	local said = ""
	local camera = workspace.CurrentCamera
	local p = plot()
	local water = p and p:FindFirstChild("TankWater")
	local pad = p and p:FindFirstChild("Pad")
	local way = water and pad and ((pad.Position - water.Position) * Vector3.new(1, 0, 1)).Unit
	local left = way and way:Cross(Vector3.yAxis)
	if verb == "fire" then
		-- the very remote a button fires, once or (twice|...) twice back to back
		local args = Http:JSONDecode(a)
		table.clear(answers)
		Net.Action:FireServer(table.unpack(args))
		task.wait(1.4)
		said = took()
	elseif verb == "twice" then
		local args = Http:JSONDecode(a)
		table.clear(answers)
		Net.Action:FireServer(table.unpack(args))
		Net.Action:FireServer(table.unpack(args))
		task.wait(1.6)
		said = took()
	elseif verb == "press" then
		table.clear(answers)
		local found = UpgradeSign.press(nil, "Plot")
		task.wait(0.25)
		local gui = signGui()
		local cash = gui and gui:FindFirstChild("Cash", true)
		local label = cash and cash:FindFirstChild("Label", true)
		local word = label and label.Text or "?"
		task.wait(1.3)
		said = "pressed=" .. tostring(found) .. " word=" .. string.gsub(word, " ", "_") .. " " .. took()
	elseif verb == "signtext" then
		local gui = signGui()
		if gui then
			local function text(name)
				local l = gui:FindFirstChild(name, true)
				return l and string.gsub(l.Text, " ", "_") or "?"
			end
			local cash = gui:FindFirstChild("Cash", true)
			local robux = gui:FindFirstChild("Robux", true)
			local seahorse = player.PlayerGui:FindFirstChild("UpgradeSign_" .. tostring(player:GetAttribute("Plot")))
			said = string.format("title=%s name=%s stat=%s cash=%s robux=%s size=%s seahorseSize=%s", text("Title"), text("Next"),
				text("Stat"), string.gsub(cash:FindFirstChild("Label", true).Text, " ", "_"), tostring(robux.Visible),
				tostring(gui.AbsoluteSize), tostring(seahorse and seahorse.AbsoluteSize))
		else
			said = "nosign"
		end
	elseif verb == "cam" then
		camera.CameraType = Enum.CameraType.Scriptable
		if a == "sign" then
			local board = p.PlotBoard
			camera.CFrame = CFrame.lookAt(board.Position + way * 13 + Vector3.new(0, 1.5, 0), board.Position)
		elseif a == "both" then
			-- the plot's sign and the seahorse's in one view
			local b1, b2 = p.PlotBoard, p.UpgradeBoard
			local mid = (b1.Position + b2.Position) / 2
			camera.CFrame = CFrame.lookAt(mid + way * 30 + Vector3.new(0, 6, 0), mid)
		else
			-- the whole tank and its sign, from the front left
			local aim = water.Position - Vector3.new(0, water.Size.Y / 2, 0) + Vector3.new(0, 12, 0) + left * 4
			camera.CFrame = CFrame.lookAt(aim + way * 92 + left * 26 + Vector3.new(0, 16, 0), aim)
		end
		said = "cam " .. a
	elseif verb == "free" then
		camera.CameraType = Enum.CameraType.Custom
		TankPanel.pretendMouse(nil)
		said = "free"
	elseif verb == "hover" then
		local at = camera:WorldToViewportPoint(water.Position)
		TankPanel.pretendMouse(Vector2.new(at.X, at.Y))
		task.wait(0.6)
		local on, parts = TankPanel.outlined()
		local box = camera:FindFirstChild("TankOutlineBox")
		said = string.format("outlined=%s parts=%d boxH=%.1f", tostring(on), parts, box and box.Size.Y or -1)
	elseif verb == "click" then
		local s = camera:WorldToScreenPoint(water.Position)
		local hit = TankPanel.click(s.X, s.Y)
		task.wait(0.6)
		said = string.format("hit=%s open=%s", tostring(hit), tostring(TankPanel.isOpen()))
	elseif verb == "panel" then
		-- what the open popup shows: its cards, and the small buttons on the first tank card and the first hand card
		local gui = player.PlayerGui:FindFirstChild("TankPanel")
		local cards, take, sell, worth = 0, 0, 0, "?"
		for _, d in gui:GetDescendants() do
			if d.Name == "Card" then
				cards += 1
			elseif d.Name == "Take" and d:IsA("TextButton") and d.Visible then
				take += 1
			elseif d.Name == "Sell" and d:IsA("TextButton") and d.Visible then
				sell += 1
			elseif d.Name == "Worth" and worth == "?" then
				worth = string.gsub(d.Text, " ", "_")
			end
		end
		local count = gui:FindFirstChild("Count", true)
		local word = count and count:FindFirstChildWhichIsA("TextLabel")
		said = string.format("cards=%d take=%d sell=%d worth=%s count=%s", cards, take, sell, worth,
			word and string.gsub(word.Text, " ", "_") or "?")
	elseif verb == "close" then
		TankPanel.toggle(false)
		said = "open=" .. tostring(TankPanel.isOpen())
	elseif verb == "log" then
		local out = {}
		for _, e in game:GetService("LogService"):GetLogHistory() do
			if e.messageType == Enum.MessageType.MessageError or e.messageType == Enum.MessageType.MessageWarning then
				table.insert(out, (string.gsub(e.message, "%s+", " ")))
			end
		end
		said = "log: " .. table.concat(out, " || ", math.max(1, #out - 12))
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
	local old = at:FindFirstChild("ZZB1Check")
	if old then old:Destroy() end
end
workspace:SetAttribute("B1Do", nil)
workspace:SetAttribute("B1Stand", nil)
if {lua(remove)} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZB1Check"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZB1Check"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def cmd(c, wait=0.8):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('B1Cmd', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('B1Said')"
    )


def do(c, wait=2.2):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('B1Client', '') "
        f"workspace:SetAttribute('B1Do', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('B1Client')"
    )


def fire(*args, twice=False):
    return do(("twice|" if twice else "fire|") + json.dumps(list(args)), 2.4)


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


def scene(name):
    im = shot(OUT / f"raw_{name}.png")
    im.crop((OFFSET[0], OFFSET[1], OFFSET[0] + VIEW[0], OFFSET[1] + VIEW[1])).resize((1280, 700)).save(
        ATTACH / f"b1-{name}.png"
    )


RESULTS = []


def check():
    log = []

    def note(text):
        print(text, flush=True)
        log.append(text)

    def expect(name, ok, detail=""):
        RESULTS.append((name, ok))
        note(("PASS " if ok else "FAIL ") + name + (("  [" + detail + "]") if detail else ""))

    def kv(text, key):
        for part in text.replace("@", " ").split(" "):
            if part.startswith(key + "="):
                return part[len(key) + 1 :]
        return None

    def num(text, key):
        return float(kv(text, key))

    def state():
        return cmd("state")

    prices = [500, 5000, 50000, 500000, 5000000]

    # --- the start: stage 0, the sign in its place
    note("clear: " + cmd("clear"))
    s = state()
    note("start: " + s)
    expect("a new plot is stage 0 and may equip 7", kv(s, "stage") == "0" and kv(s, "most") == "7", s)
    h0, rim0, sign0, bottom0 = num(s, "waterH"), num(s, "rimY"), num(s, "signY"), num(s, "waterBottom")
    b = cmd("board")
    note("board: " + b)
    left_edge = num(b, "left") + 5.4
    expect(
        "the plot's sign stands in front of the far-left end of the tank's front, facing the hub",
        kv(b, "board") == "yes" and kv(b, "post") == "true" and 0 <= num(b, "halfWide") - left_edge <= 2
        and 3 <= num(b, "ahead") - num(b, "halfDeep") <= 10 and num(b, "faces") > 0.99, b)
    expect("its board is the seahorse sign's size", kv(b, "size") == kv(b, "seahorseSize"), b)
    note("sign: " + cmd("sign", 1.5))
    t = do("signtext")
    note("signtext: " + t)
    expect("the sign offers stage 1: UPGRADE TANK, STAGE 1/5, 7 > 9, $500",
           kv(t, "title") == "UPGRADE_TANK" and kv(t, "name") == "STAGE_1/5" and kv(t, "stat") == "7_>_9_Earning_fish"
           and kv(t, "cash") == "$500", t)
    expect("the sign's writing is the seahorse sign's size", kv(t, "size") == kv(t, "seahorseSize"), t)
    do("cam|sign")
    scene("sign-stage0")
    do("cam|both")
    scene("signs-both")
    do("cam|tank")
    scene("tank-stage0")

    # --- the price, to the coin (an empty tank earns nothing meanwhile)
    cmd("zero")
    r = do("press")
    s = state()
    expect("no coins: the sign's click is refused (Coins) and says so", "PlotNo:Coins" in r and kv(s, "stage") == "0", r + " / " + s)
    cmd("give|" + json.dumps([499, []]))
    r = do("press")
    s = state()
    expect("499 coins: still refused, nothing taken", "PlotNo:Coins" in r and kv(s, "stage") == "0" and num(s, "coins") == 499, r + " / " + s)
    cmd("give|" + json.dumps([1, []]))
    note("spawn: " + cmd("spawn", 1.5))
    r = fire("Plot", "Up")
    s = state()
    expect("500 coins but away from the sign: refused (Near), nothing taken", "PlotNo:Near" in r and kv(s, "stage") == "0" and num(s, "coins") == 500, r + " / " + s)
    note("sign: " + cmd("sign", 1.5))
    r = do("press", 3.0)
    s = state()
    expect("stage 1 bought at the sign for exactly 500", "PlotUp:1" in r and kv(s, "stage") == "1" and num(s, "coins") == 0, r + " / " + s)
    expect("stage 1: 9 may be equipped, the tank 3 studs taller from the same floor",
           kv(s, "most") == "9" and abs(num(s, "waterH") - h0 - 3) < 0.01 and abs(num(s, "rimY") - rim0 - 3) < 0.01
           and abs(num(s, "signY") - sign0 - 3) < 0.01 and abs(num(s, "waterBottom") - bottom0) < 0.01, s)
    t = do("signtext")
    expect("the sign now offers stage 2: 9 > 11, $5K", kv(t, "name") == "STAGE_2/5" and kv(t, "stat") == "9_>_11_Earning_fish", t)
    do("cam|sign")
    scene("sign-stage1")

    # --- deposit, the inventory past the old 60, the equip limit, take out, sell
    fishes = [["Clownfish", "Normal", ""], ["ReefShark", "Normal", ""], ["YellowTang", "Big", "Gold"]]
    note("hands: " + cmd("hands|" + json.dumps(fishes), 1.2))
    note("front: " + cmd("front", 1.5))
    r = fire("Tank", "PutIn", 1, "Clownfish")
    s = state()
    expect("PUT IN deposits one carried fish", kv(s, "tank") == "1" and kv(s, "hands") == "2", r + " / " + s)
    r = fire("Tank", "PutAll")
    s = state()
    expect("PUT ALL IN deposits the rest", kv(s, "tank") == "3" and kv(s, "hands") == "0", r + " / " + s)
    many = [["BlueChromis", "Normal", ""]] * 60 + [["Pufferfish", "Big", ""]] * 40
    cmd("give|" + json.dumps([0, many]), 2.0)
    s = state()
    expect("the inventory has no limit: 103 fish kept (the old limit was 60)", kv(s, "tank") == "103", s)
    expect("only 9 of them are equipped at stage 1", kv(s, "on") == "9" and kv(s, "shown") == "9", s)
    r = fire("Tank", "Equip", kv(s, "firstOff"))
    s2 = state()
    expect("a tenth equip is refused (Full)", "TankDenied:Full" in r and kv(s2, "on") == "9", r + " / " + s2)
    r = fire("Tank", "Unequip", kv(s2, "firstOn"))
    s3 = state()
    expect("unequip frees a place; the fish stays in the tank", kv(s3, "on") == "8" and kv(s3, "tank") == "103", r + " / " + s3)
    r = fire("Tank", "Best")
    s3 = state()
    expect("EQUIP BEST fills the places again", kv(s3, "on") == "9", s3)
    # take out
    r = fire("Tank", "TakeOut", kv(s3, "firstOff"))
    s4 = state()
    expect("TAKE OUT moves a stored fish into the hands", kv(s4, "tank") == "102" and kv(s4, "hands") == "1" and kv(s4, "on") == "9", r + " / " + s4)
    r = fire("Tank", "TakeOut", kv(s4, "firstOn"))
    s5 = state()
    expect("TAKE OUT of an equipped fish frees its place", kv(s5, "tank") == "101" and kv(s5, "hands") == "2" and kv(s5, "on") == "8", r + " / " + s5)
    r = fire("Tank", "PutIn", 1, kv(s5, "hand1"))
    s6 = state()
    expect("and it can be put back in", kv(s6, "tank") == "102" and kv(s6, "hands") == "1", r + " / " + s6)
    cmd("hands|" + json.dumps([["Clownfish", "Normal", ""]] * 6), 1.2)
    s6 = state()
    r = fire("Tank", "TakeOut", kv(s6, "firstOff"))
    s7 = state()
    expect("with seven in the hands TAKE OUT is refused (Hands)", kv(s6, "hands") == "7" and "TankDenied:Hands" in r and kv(s7, "tank") == kv(s6, "tank") and kv(s7, "hands") == "7", r + " / " + s7)
    # the popup
    do("cam|tank")
    c = do("click")
    pnl = do("panel")
    note("panel: " + pnl)
    expect("the popup opens on a click and every card has SELL, every tank card TAKE OUT",
           kv(c, "open") == "true" and int(kv(pnl, "cards")) == 109 and int(kv(pnl, "take")) == 102 and int(kv(pnl, "sell")) == 109
           and kv(pnl, "count") == "Equipped_9/9", c + " / " + pnl)
    scene("popup")
    do("close")
    # sell
    cmd("zero")
    s = state()
    income = num(s, "income")
    price = int(kv(cmd("price|" + json.dumps(["Clownfish", "Normal", ""])), "price"))
    r = fire("Sell", "Hand", 7, "Clownfish")
    s8 = state()
    gained = num(s8, "coins")
    expect(f"SELL from the hands pays the server's price ({price}) and the fish is gone",
           f"Sold:Clownfish:{price}" in r and kv(s8, "hands") == "6" and price <= gained <= price + income * 8, r + " / " + s8)
    r = fire("Sell", "Hand", 1, "Kraken")
    s9 = state()
    expect("SELL of a fish that is not there (a made-up id) pays nothing", "TankDenied:Gone" in r and kv(s9, "hands") == "6", r + " / " + s9)
    r = fire("Sell", "Tank", kv(s9, "firstOff"))
    s10 = state()
    expect("SELL of a stored fish takes it out of the tank and pays", "Sold:" in r and kv(s10, "tank") == "101", r + " / " + s10)
    r = fire("Sell", "Tank", kv(s10, "firstOn"))
    s11 = state()
    expect("SELL of an equipped fish frees its place", "Sold:" in r and kv(s11, "tank") == "100" and kv(s11, "on") == "8", r + " / " + s11)
    r = fire("Sell", "Tank", "99999")
    s12 = state()
    expect("SELL of a key that is not in the tank pays nothing", "TankDenied:Gone" in r and kv(s12, "tank") == "100", r + " / " + s12)
    r = fire("Sell", "Tank", kv(s12, "firstOff"), 1e9)
    s13 = state()
    expect("a price sent by the client is ignored", num(s13, "coins") < num(s12, "coins") + 1e6, r + " / " + s13)
    cmd("clear")

    # --- stages 2 to 5
    note("sign: " + cmd("sign", 1.5))
    cmd("zero")
    cmd("give|" + json.dumps([prices[1] * 2, []]))
    before = num(state(), "coins")
    r = fire("Plot", "Up", twice=True)
    s = state()
    spent = before - num(s, "coins")
    expect("a double click buys one stage (2) and charges once",
           kv(s, "stage") == "2" and r.count("PlotUp") == 1 and prices[1] - num(s, "income") * 8 <= spent <= prices[1], r + " / " + s)
    for stage in (3, 4, 5):
        cmd("give|" + json.dumps([prices[stage - 1], []]))
        r = do("press", 3.0)
        s = state()
        expect(f"stage {stage}: bought; {7 + 2 * stage} may be equipped; the tank {3 * stage} studs taller",
               f"PlotUp:{stage}" in r and kv(s, "stage") == str(stage) and kv(s, "most") == str(7 + 2 * stage)
               and abs(num(s, "waterH") - h0 - 3 * stage) < 0.01 and abs(num(s, "rimY") - rim0 - 3 * stage) < 0.01
               and abs(num(s, "waterBottom") - bottom0) < 0.01, r + " / " + s)
        note("front: " + cmd("front", 1.2))
        fire("Tank", "Best")
        s = state()
        expect(f"stage {stage}: EQUIP BEST equips {7 + 2 * stage}, all swimming in the tank",
               kv(s, "on") == str(7 + 2 * stage) and kv(s, "shown") == str(7 + 2 * stage), s)
        r = fire("Tank", "Equip", kv(s, "firstOff"))
        s = state()
        expect(f"stage {stage}: one more is refused (Full)", "TankDenied:Full" in r and kv(s, "on") == str(7 + 2 * stage), r + " / " + s)
        note("sign: " + cmd("sign", 1.2))
    cmd("give|" + json.dumps([10000000, []]))
    before = num(state(), "coins")
    r = fire("Plot", "Up")
    s = state()
    expect("at stage 5 a sixth is refused (Top), nothing taken", "PlotNo:Top" in r and kv(s, "stage") == "5" and num(s, "coins") >= before, r + " / " + s)
    t = do("signtext")
    note("signtext: " + t)
    expect("the sign says TANK MAXED!, STAGE 5/5, 17 earning, MAX STAGE",
           kv(t, "title") == "TANK_MAXED!" and kv(t, "name") == "STAGE_5/5" and kv(t, "stat") == "17_Earning_fish"
           and kv(t, "cash") == "MAX_STAGE" and kv(t, "robux") == "false", t)
    do("cam|sign")
    scene("sign-stage5")
    do("cam|tank")
    time.sleep(1.0)
    scene("tank-stage5")

    # --- c1's hover outline and click still work, round the taller tank
    note("front: " + cmd("front", 1.5))
    do("cam|tank")
    h = do("hover")
    note("hover: " + h)
    expect("hovered: the whole (taller) tank is outlined", kv(h, "outlined") == "true" and int(kv(h, "parts")) > 5 and num(h, "boxH") > 16 + 15 - 0.5, h)
    scene("tank-stage5-hover")
    c = do("click")
    expect("a click still opens the popup", kv(c, "hit") == "true" and kv(c, "open") == "true", c)
    pnl = do("panel")
    expect("the popup counts 17 places", kv(pnl, "count") == "Equipped_17/17", pnl)
    scene("popup-stage5")
    do("close")
    note("free: " + do("free"))
    note(do("log", 2.5))

    ok = all(r for _, r in RESULTS)
    note(f"{sum(1 for _, r in RESULTS if r)}/{len(RESULTS)} passed")
    (OUT / "check.log").write_text("\n".join(log) + "\n")
    return ok


def shots():
    """the stills with nobody standing in the way: the sign at stage 0, 1 and 5, the tank at each, the popup's cards"""
    prices = [500, 5000, 50000, 500000, 5000000]
    fish = [["Clownfish", "Normal", ""], ["ReefShark", "Normal", ""], ["YellowTang", "Big", "Gold"],
            ["Pufferfish", "Big", ""], ["SeaTurtle", "Giant", ""], ["Stingray", "Big", "Silver"],
            ["Octopus", "Normal", ""], ["Seahorse", "Normal", "Rainbow"], ["BlueChromis", "Normal", ""]]
    cmd("give|" + json.dumps([0, fish + fish]), 1.5)

    def stills(stage):
        print(cmd("front", 1.5))
        do("cam|sign")
        time.sleep(0.8)
        scene(f"sign-stage{stage}")
        do("cam|tank")
        time.sleep(0.8)
        scene(f"tank-stage{stage}")

    stills(0)
    for stage in range(1, 6):
        cmd("sign", 1.5)
        cmd("zero")
        cmd("give|" + json.dumps([prices[stage - 1], []]))
        print(stage, do("press", 3.0))
        cmd("front", 1.2)
        fire("Tank", "Best")
        if stage in (1, 5):
            stills(stage)
    do("cam|tank")
    print(do("click"))
    time.sleep(1.0)
    scene("popup-stage5")
    do("close")
    print(do("free"))


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "run"
    if what == "log":
        print(do("log", 2.5))
    elif what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
    elif what == "shots":
        shots()
    else:
        sys.exit(0 if check() else 1)
