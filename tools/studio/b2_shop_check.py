"""The shop's two pages (task b2): the Sell Fish window and the Auras window, checked and pictured in a playtest.
    python tools/studio/b2_shop_check.py push               (in Edit: this task's four files into the open place)
    python tools/studio/b2_shop_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/b2_shop_check.py run                (in the playtest: the checks and the stills)
How: the server Script gives coins and fish (AquariumService.give, RideService.giveCarried) and reports the server's
side (the tank's entries, the coins, the hands). The LocalScript opens the pages (AuraController.shop), presses the
Sell Fish window's own buttons (SellFish.press: a script can't click) and reads what the windows show.
Log: work/b2/check.log; shots docs/attachments/b2-*.png.
"""
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/b2"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
OFFSET = (0, 125)  # the game view in the shot (as b1_inventory_check.py)
VIEW = [1985, 1085]
MINE = [
    "src/server/Services/AquariumService.luau",
    "src/client/UI/TankPanel.luau",
    "src/client/UI/Shop.luau",
    "src/client/UI/AuraShop.luau",
    "src/client/UI/SellFish.luau",
    "src/client/Controllers/AuraController.luau",
]

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local AquariumService = require(Services:WaitForChild("AquariumService"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZB2Report"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("B2Client", tostring(text))
end)
RS:GetAttributeChangedSignal("B2Cmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("B2Cmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local ok, said = pcall(function()
		if verb == "hands" then
			for _, f in Http:JSONDecode(arg) do
				RideService.giveCarried(player, { Id = f[1], Size = f[2], Variant = f[3] })
			end
			return "hands " .. #RideService.carried(player)
		elseif verb == "give" then
			local a = Http:JSONDecode(arg)
			AquariumService.give(player, a[1], a[2])
			return "given"
		elseif verb == "zero" then
			AquariumService.spend(player, AquariumService.coinsOf(player))
			return "coins " .. AquariumService.coinsOf(player)
		elseif verb == "state" then
			local fish = AquariumService.tankOf(player) or {}
			local on = 0
			for _, f in fish do
				if f.On then
					on += 1
				end
			end
			return string.format("state=%s hands=%d tank=%d on=%d coins=%s", tostring(RideService.stateOf(player)),
				#RideService.carried(player), #fish, on, tostring(AquariumService.coinsOf(player)))
		end
		return "?"
	end)
	RS:SetAttribute("B2Said", tostring(said) .. " " .. tostring(ok))
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local player = Players.LocalPlayer
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local AuraController = require(Client:WaitForChild("Controllers"):WaitForChild("AuraController"))
local SellFish = require(Client:WaitForChild("UI"):WaitForChild("SellFish"))
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local Config = require(RS.Shared:WaitForChild("Config"))
local report = RS:WaitForChild("ZZB2Report", 60)
local answers = {}
Net.Ride.OnClientEvent:Connect(function(what, a, b)
	if what == "TankDenied" or what == "Sold" then
		table.insert(answers, what .. ":" .. tostring(a) .. (if b ~= nil then ":" .. tostring(b) else ""))
	end
end)
local function word(gui, name)
	local found = gui:FindFirstChild(name, true)
	local label = found and (if found:IsA("TextLabel") then found else found:FindFirstChildWhichIsA("TextLabel", true))
	return label and string.gsub(label.Text, " ", "_") or "?"
end
workspace:GetAttributeChangedSignal("B2Do"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("B2Do") or "")
	local verb, a = string.match(cmd, "^(%w+)|?([^|]*)")
	local said = ""
	local gui = player.PlayerGui
	if verb == "open" then
		AuraController.shop(if a == "" then nil else a)
		task.wait(0.6)
		said = "open=" .. tostring(AuraController.shopOpen())
	elseif verb == "press" then
		local args = Http:JSONDecode(a)
		table.clear(answers)
		SellFish.press(args[1], args[2])
		task.wait(args[3] or 0.3)
		said = "answers=" .. #answers
	elseif verb == "sell" then
		-- Sell pressed twice (SURE?, then the sale), and what the server answered: how many sold, for how much
		table.clear(answers)
		SellFish.press("Sell")
		task.wait(0.3)
		local asked = string.gsub(gui.SellFish:FindFirstChild("Sell", true):FindFirstChild("Label", true).Text, " ", "_")
		SellFish.press("Sell")
		task.wait(tonumber(a) or 1.5)
		local sold, coins, denied = 0, 0, 0
		for _, line in answers do
			local c = string.match(line, "^Sold:[^:]*:(%d+)")
			if c then
				sold += 1
				coins += tonumber(c)
			else
				denied += 1
			end
		end
		local toast = gui.SellFish:FindFirstChild("Toast", true)
		said = string.format("asked=%s sold=%d paid=%d denied=%d toast=%s", asked, sold, coins, denied,
			if toast.Visible then word(gui.SellFish, "Toast") else "none")
	elseif verb == "force" then
		-- the remote itself, past the window: sell a fish that is equipped in the tank
		local key = nil
		for _, row in Http:JSONDecode(player:GetAttribute("TankList") or "[]") do
			if row[5] == 1 then
				key = row[1]
				break
			end
		end
		table.clear(answers)
		Net.Action:FireServer("Sell", "Tank", key)
		task.wait(1.0)
		said = "key=" .. tostring(key) .. " answers=[" .. table.concat(answers, ",") .. "]"
	elseif verb == "scroll" then
		local list = gui.SellFish:FindFirstChild("List", true)
		list.CanvasPosition = Vector2.new(0, if a == "end" then 99999 else 0)
		task.wait(0.3)
		said = "scrolled"
	elseif verb == "sort" then
		SellFish.sort(a)
		task.wait(0.2)
		said = "sorted"
	elseif verb == "read" then
		-- what the Sell Fish window shows
		local w = gui:FindFirstChild("SellFish")
		local cards, ticks, veils, first, firstPrice, value = 0, 0, 0, "?", "?", 0
		local shown = {}
		for _, d in w:GetDescendants() do
			if d.Name == "Item" and d.Visible then
				cards += 1
				table.insert(shown, d)
				if d.Tick.Visible then ticks += 1 end
				if d.Equipped.Visible then veils += 1 end
			end
		end
		table.sort(shown, function(x, y) return x.LayoutOrder < y.LayoutOrder end)
		if shown[1] then
			first = string.gsub(shown[1]:FindFirstChild("Name").Text, " ", "_")
			firstPrice = word(shown[1], "PriceStrip")
		end
		local names = {}
		for i = 1, math.min(4, #shown) do
			table.insert(names, (string.gsub(shown[i]:FindFirstChild("Name").Text, " ", "_")))
		end
		said = string.format("enabled=%s cards=%d ticks=%d veils=%d first=%s firstPrice=%s names=%s total=%s sell=%s all=%s tabs=%d toast=%s",
			tostring(w.Enabled), cards, ticks, veils, first, firstPrice, table.concat(names, ","), word(w, "Total"),
			word(w, "Sell"), word(w, "SelectAll"), #w:FindFirstChild("Tabs", true):GetChildren() - 1,
			if w:FindFirstChild("Toast", true).Visible then word(w, "Toast") else "none")
	elseif verb == "auras" then
		local w = gui:FindFirstChild("AuraShop")
		local cards, soon, equipped, owned = 0, 0, 0, 0
		for _, d in w:GetDescendants() do
			if d:IsA("Frame") and string.match(d.Name, "^Aura%d+$") then
				cards += 1
				local t = d:FindFirstChild("Cash", true):FindFirstChild("Label", true).Text
				if t == "SOON" then soon += 1 elseif t == "EQUIPPED" then equipped += 1 elseif t == "OWNED" then owned += 1 end
			end
		end
		said = string.format("enabled=%s cards=%d soon=%d equipped=%d owned=%d tabs=%d title=%s", tostring(w.Enabled), cards,
			soon, equipped, owned, #w:FindFirstChild("Tabs", true):GetChildren() - 1, word(w, "Title"))
	elseif verb == "wear" then
		player:SetAttribute("Aura", tonumber(a))
		task.wait(0.4)
		said = "worn " .. a
	elseif verb == "cam" then
		-- a calm view of the hub behind the window
		local camera = workspace.CurrentCamera
		local spawn = workspace.ClaudeBlockout.Dock.DockSpawn
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(spawn.Position + Vector3.new(0, 26, 60), spawn.Position + Vector3.new(0, 8, 0))
		said = "cam"
	elseif verb == "free" then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		said = "free"
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
    eq = "=" * 6
    return f"[{eq}[" + str(v) + f"]{eq}]"


def job(code):
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(code)
    return run([f.name])


def server(code):
    return run(["--ctx", "server", "--code", code])


def push():
    """This task's four files into the open place (Edit), and read back."""
    for rel in MINE:
        src = (ROOT / rel).read_text()
        if rel.startswith("src/server/"):
            path = ["ServerScriptService", "Server", *rel[len("src/server/") : -len(".luau")].split("/")]
        else:
            parts = rel[len("src/client/") : -len(".luau")].split("/")
            path = ["StarterPlayer", "StarterPlayerScripts", "Client", *parts]
        code = f"""local at = game:GetService({lua(path[0])})
local path = {{ {", ".join(lua(x) for x in path[1:])} }}
for i, name in path do
	local nxt = at:FindFirstChild(name)
	if not nxt then
		nxt = Instance.new(if i == #path then "ModuleScript" else "Folder")
		nxt.Name = name
		nxt.Parent = at
	end
	at = nxt
end
local text = {lua(src)}
game:GetService("ScriptEditorService"):UpdateSourceAsync(at, function() return text end)
return at:GetFullName() .. " same=" .. tostring(at.Source == text)
"""
        print(job(code).splitlines()[-1])


def install(remove=False):
    return job(f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZB2Check")
	if old then old:Destroy() end
end
workspace:SetAttribute("B2Do", nil)
if {lua(remove)} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZB2Check"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZB2Check"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
""")


def cmd(c, wait=0.8):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('B2Cmd', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('B2Said')"
    )


def do(c, wait=1.6):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('B2Client', '') "
        f"workspace:SetAttribute('B2Do', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('B2Client')"
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


def scene(name):
    im = shot(OUT / f"raw_{name}.png")
    im.crop((OFFSET[0], OFFSET[1], OFFSET[0] + VIEW[0], OFFSET[1] + VIEW[1])).resize((1280, 700)).save(
        ATTACH / f"b2-{name}.png"
    )


TANK = [
    ["Kraken", "Giant", "Gold"], ["Megalodon", "Colossal", ""], ["Hellmaw", "Big", "Rainbow"],
    ["Mosasaurus", "Huge", ""], ["Orca", "Normal", "Silver"], ["GreatWhite", "Big", ""],
    ["MantaRay", "Tiny", ""], ["Anglerfish", "Normal", "Gold"], ["SeaTurtle", "Giant", ""],
    ["Clownfish", "Normal", ""], ["YellowTang", "Big", "Rainbow"], ["Pufferfish", "Tiny", ""],
    ["Lionfish", "Normal", ""], ["Dolphin", "Normal", ""], ["Octopus", "Big", "Silver"],
    ["BlueChromis", "Normal", ""], ["Seahorse", "Normal", ""], ["ReefShark", "Giant", ""],
]
HANDS = [["Swordfish", "Big", ""], ["Boxfish", "Normal", "Gold"], ["Clownfish", "Tiny", ""]]


def check():
    log, results = [], []

    def note(text):
        print(text, flush=True)
        log.append(text)

    def expect(name, ok, detail=""):
        results.append((name, ok))
        note(("PASS " if ok else "FAIL ") + name + (("  [" + detail + "]") if detail else ""))

    def kv(text, key):
        for part in text.replace("@", " ").split(" "):
            if part.startswith(key + "="):
                return part[len(key) + 1 :]
        return None

    def money(text):
        """ "$1.4K" as coins, to the precision shown """
        t = text.lstrip("$")
        units = {"K": 1e3, "M": 1e6, "B": 1e9, "T": 1e12}
        return float(t[:-1]) * units[t[-1]] if t[-1] in units else float(t)

    note("give: " + cmd("give|" + json.dumps([0, TANK]), 1.5))
    note("zero: " + cmd("zero"))
    note("hands: " + cmd("hands|" + json.dumps(HANDS)))
    s = cmd("state")
    note("start: " + s)
    tank0, on0, hands0 = int(kv(s, "tank")), int(kv(s, "on")), int(kv(s, "hands"))
    expect("the server holds the fish given (18 in the tank, 7 equipped, 3 carried)",
           tank0 == 18 and on0 == 7 and hands0 == 3, s)
    note(do("cam"))

    # --- the Auras page
    a = do("open|Auras", 2.2)
    note("open auras: " + a)
    r = do("auras")
    note("auras: " + r)
    expect("the shop opens at the Auras page: 12 cards, two tabs, every aura priced (2026-11-24: on sale)",
           kv(a, "open") == "Auras" and kv(r, "enabled") == "true" and kv(r, "cards") == "12"
           and kv(r, "soon") == "0" and kv(r, "tabs") == "2", r)
    time.sleep(0.5)
    scene("auras")
    note(do("wear|3"))
    r = do("auras")
    note("auras worn 3: " + r)
    expect("with aura 3 worn: it reads EQUIPPED, 1 and 2 OWNED", kv(r, "equipped") == "1" and kv(r, "owned") == "2", r)
    scene("auras-worn")
    note(do("wear|0"))

    # --- the Sell Fish page
    a = do("open|Sell", 2.2)
    note("open sell: " + a)
    r = do("read")
    note("sell: " + r)
    expect("the Sell page replaces the Auras page", kv(a, "open") == "Sell" and kv(do("auras"), "enabled") == "false", a)
    expect("it lists every fish (21 cards), the 7 equipped marked, nothing picked, Sell (0), $0",
           kv(r, "cards") == "21" and kv(r, "veils") == "7" and kv(r, "ticks") == "0"
           and kv(r, "sell") == "Sell_(0)" and kv(r, "total") == "$0" and kv(r, "tabs") == "2", r)
    time.sleep(0.4)
    scene("sell")
    note(do("scroll|end"))
    scene("sell-equipped")
    note(do("scroll|top"))
    by_value = kv(r, "names")
    note(do("sort|Rarity"))
    r2 = do("read")
    note("by rarity: " + r2)
    expect("Sort By Rarity changes the order", kv(r2, "names") != by_value, by_value + " / " + kv(r2, "names"))
    note(do("sort|Value"))

    # --- pick two, sell them
    r = do("read")
    first_price = money(kv(r, "firstPrice"))
    note(do("press|" + json.dumps(["Card", 1])))
    note(do("press|" + json.dumps(["Card", 2])))
    r = do("read")
    note("two picked: " + r)
    expect("two cards picked: two ticks, Sell (2), a total", kv(r, "ticks") == "2" and kv(r, "sell") == "Sell_(2)"
           and money(kv(r, "total")) >= first_price, r)
    scene("sell-picked")
    # an equipped card can't be picked
    note(do("press|" + json.dumps(["Card", 21])))
    r = do("read")
    expect("a press on an equipped fish picks nothing and says why", kv(r, "ticks") == "2" and "EQUIPPED" in r, r)
    shown = money(kv(r, "total"))
    sale = do("sell|1.2", 2.4)
    s = cmd("state")
    r = do("read", 1.0)
    note("the sale: " + sale + " / " + s + " / " + r)
    expect("the first press on Sell asks SURE?", kv(sale, "asked") == "SURE?_(2)", sale)
    paid = float(kv(sale, "paid"))
    expect("the second press sells both: 2 fewer on the server, the coins paid match the total shown",
           kv(sale, "sold") == "2" and int(kv(s, "tank")) + int(kv(s, "hands")) == tank0 + hands0 - 2
           and abs(paid - shown) <= shown * 0.06 and float(kv(s, "coins")) >= paid, f"paid={paid} shown={shown}")
    expect("the window follows: 19 cards, nothing picked, the toast says what it paid",
           kv(r, "cards") == "19" and kv(r, "ticks") == "0" and "SOLD_2_FISH" in sale, sale + " " + r)
    scene("sell-sold")

    # --- Select All, sell everything that can be sold (the tank's stored ones and all three carried)
    time.sleep(2.2)
    note(do("press|" + json.dumps(["All"])))
    r = do("read")
    note("all picked: " + r)
    free = 19 - 7
    expect("Select All picks every fish that can be sold and none equipped",
           kv(r, "ticks") == str(free) and kv(r, "sell") == f"Sell_({free})" and kv(r, "all") == "Select_None", r)
    scene("sell-all")
    shown = money(kv(r, "total"))
    sale = do("sell|4.5", 6.0)
    s = cmd("state")
    r = do("read")
    note("selling all: " + sale + " / " + s + " / " + r)
    expect("all of them sold: only the 7 equipped are left, the hands are empty",
           kv(sale, "sold") == str(free) and kv(sale, "denied") == "0" and kv(s, "tank") == "7" and kv(s, "on") == "7"
           and kv(s, "hands") == "0", sale + " " + s)
    expect("the coins paid match what the window showed", abs(float(kv(sale, "paid")) - shown) <= shown * 0.06,
           f"paid={kv(sale, 'paid')} shown={shown}")
    expect("the window shows the 7 equipped and Sell (0)", kv(r, "cards") == "7" and kv(r, "veils") == "7"
           and kv(r, "sell") == "Sell_(0)", r)

    # --- the server itself refuses an equipped fish, whatever the client sends
    before = cmd("state")
    f = do("force", 2.0)
    time.sleep(0.3)
    after = cmd("state")
    note("forced sale of an equipped fish: " + f + " / " + before + " / " + after)
    expect("a forced Sell of an equipped fish is refused by the server: TankDenied Equipped, the tank unchanged",
           "TankDenied:Equipped" in f and "Sold" not in f and kv(after, "tank") == kv(before, "tank") == "7"
           and kv(after, "on") == "7", f + " " + after)

    # --- closing
    c = do("open|")
    expect("the shop closes", kv(c, "open") == "nil", c)
    note(do("free"))
    note(do("log", 2.0))
    good = sum(1 for _, ok in results if ok)
    note(f"{good} of {len(results)} passed")
    (OUT / "check.log").write_text("\n".join(log) + "\n")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else ""
    if what == "push":
        push()
    elif what == "install":
        print(install())
    elif what == "remove":
        print(install(True))
    elif what == "run":
        check()
    elif what == "do":
        print(do(sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 1.6))
    elif what == "cmd":
        print(cmd(sys.argv[2]))
    elif what == "shot":
        scene(sys.argv[2])
    else:
        print(__doc__)
