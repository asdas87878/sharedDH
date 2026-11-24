"""The auras in a playtest (task a1, 2026-11-24): buying through the real remote, the stall's cards, and what is drawn.
    python tools/auras/flame_pics.py                                 (once, then reopen Studio: the flame's pictures)
    python tools/studio/s2_subs_check.py install ; python tools/studio/aura_check.py install      (in Edit, before Play)
    node ~/Projects/studio-runner/studio-run.mjs play                (a fresh play: the run starts with no aura)
    python tools/studio/aura_check.py run                            (in the playtest: the numbers; its faults are listed)
    python tools/studio/aura_check.py look 6                         (your own player shows tier 6; 0: what you own)
    python tools/studio/aura_check.py dial Turn 1                    (Config.Aura's look dials: Turn, Scroll, Behind, Flame)
    python tools/studio/aura_check.py flare Land | Eat | Jumping     (one flare on your own player, as the server would say)
    python tools/studio/aura_check.py remove ; python tools/studio/s2_subs_check.py remove        (in Edit, after)
By eye, with `look` 1, 6, 12 beside docs/attachments/auras-draft-4.png (docs/design/auras.md, "Check in Studio first"):
the flame stands up (Turn), its picture runs UP (Scroll), it is behind the body (Behind), no seam at the joints, no line
at the foot; then riding (it starts at the hips and grows over a hop) and the burst: buy tier 10.
The real click on a card, and its sounds, are by hand. Log: work/auras/check.log.
"""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import s2_subs_check as s2  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "work/auras"
OUT.mkdir(parents=True, exist_ok=True)
BEAMS = [10, 10, 18, 23, 23, 25, 25, 25, 25, 25, 32, 42]
EMITTERS = [0, 1, 1, 1, 1, 1, 2, 3, 4, 5, 5, 5]

CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local player = game:GetService("Players").LocalPlayer
local report = RS:WaitForChild("ZZS2Report")
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Shared = RS:WaitForChild("Shared")
local Auras = require(Shared:WaitForChild("Auras"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Shop = require(Client:WaitForChild("UI"):WaitForChild("Shop"))
local AuraController = require(Client:WaitForChild("Controllers"):WaitForChild("AuraController"))
local AuraBeams = require(Client:WaitForChild("Lib"):WaitForChild("AuraBeams"))
local gui = player:WaitForChild("PlayerGui")
local answer = nil
Net.Ride.OnClientEvent:Connect(function(kind, a)
	if kind == "AuraBought" or kind == "AuraDenied" then answer = kind .. " " .. tostring(a) end
end)
local verbs = {}
function verbs.buy(n)
	answer = nil
	Net.Action:FireServer("AuraBuy", if n == "nan" then 0 / 0 else (tonumber(n) or n))
	local stop = os.clock() + 1.2
	while not answer and os.clock() < stop do task.wait() end
	task.wait(0.2)
	return string.format("%s|aura=%s", answer or "quiet", tostring(player:GetAttribute("Aura")))
end
function verbs.stall(where)
	local ring = workspace.ClaudeBlockout.Dock.Stations.Auras:FindFirstChild("Ring")
	local root = player.Character.HumanoidRootPart
	root.CFrame = CFrame.new(ring.Position + Vector3.new(if where == "off" then Config.Aura.Near + 8 else 0, 5, 0))
	task.wait(0.8)
	local gap = (root.Position - ring.Position) * Vector3.new(1, 0, 1)
	return string.format("gap=%.1f state=%s", gap.Magnitude, tostring(player:GetAttribute("State")))
end
function verbs.shop()
	Shop.go("Auras")
	task.wait(2.5)
	local w = gui:FindFirstChild("AuraShop", true)
	local cards, icons, loaded, glows, bubbles, words = 0, 0, 0, 0, 0, {}
	for _, d in w:GetDescendants() do
		if string.match(d.Name, "^Aura%d+$") then cards += 1 end
		if d.Name == "Icon" and d:IsA("ImageLabel") and string.find(d.Image, "aura_icons", 1, true) then
			icons += 1
			if d.IsLoaded then loaded += 1 end
		elseif d.Name == "Glow" then
			glows += 1
		elseif (d.Name == "Swatch" or d.Name == "Bubble") and string.find(d:GetFullName(), "%.Aura%d+%.") then
			bubbles += 1
		elseif d.Name == "Cash" and d:IsA("TextButton") then
			local l = d:FindFirstChildWhichIsA("TextLabel", true)
			table.insert(words, if l then l.Text else "?")
		end
	end
	return string.format("cards=%d icons=%d loaded=%d glows=%d bubbles=%d %s", cards, icons, loaded, glows, bubbles, table.concat(words, " "))
end
function verbs.drawn(n)
	Auras.Test = tonumber(n) or 0
	task.wait(0.8)
	local tier, style, beams, emitters = AuraController.drawn(player.Character)
	return string.format("tier=%d style=%s beams=%d emitters=%d", tier, style, beams, emitters)
end
function verbs.pictures()
	local out = {}
	for name in Auras.Pictures do
		local id = AuraBeams.picture(name)
		table.insert(out, name .. "=" .. ContentProvider:GetAssetFetchStatus(id).Name)
	end
	return table.concat(out, " ")
end
function verbs.dial(key, n)
	(Config.Aura :: any)[key] = tonumber(n)
	task.wait(0.5)
	return key .. "=" .. tostring((Config.Aura :: any)[key])
end
workspace:GetAttributeChangedSignal("AuraDo"):Connect(function()
	local p = string.split(tostring(workspace:GetAttribute("AuraDo") or ""), "|")
	if not verbs[p[1]] then return end
	local ok, said = pcall(verbs[p[1]], p[2], p[3])
	report:FireServer((if ok then "" else "ERROR ") .. tostring(said))
end)
'''


def install(remove=False):
    return s2.job(f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZAuraCheck")
if old then old:Destroy() end
workspace:SetAttribute("AuraDo", nil)
if {s2.lua(remove)} then return "removed" end
local c = Instance.new("LocalScript")
c.Name = "ZZAuraCheck"
c.Source = {s2.lua(CLIENT)}
c.Parent = sps
return "installed " .. #c.Source
""")


def do(c, wait=2.5):
    return s2.server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('S2Client', '') "
        f"workspace:SetAttribute('AuraDo', {s2.lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('S2Client')")


def coins(n=0):
    """The server's coins, after giving n more."""
    return s2.server("local p = game:GetService('Players'):GetPlayers()[1] local s = game:GetService('ServerStorage').SubTest:Invoke("
                     f"'give', p.UserId, {n}) return string.format('coins=%.0f', game:GetService('HttpService'):JSONDecode(s).Coins)")


def flare(kind):
    if kind == "Jumping":
        return s2.server("local p = game:GetService('Players'):GetPlayers()[1] local was = p:GetAttribute('State') "
                         "p:SetAttribute('State', 'Jumping') task.wait(0.3) p:SetAttribute('State', was) return was")
    return s2.server("local RS = game:GetService('ReplicatedStorage') local N = require(RS.Shared.Net) "
                     f"N.Fx:FireAllClients('{kind}', game:GetService('Players'):GetPlayers()[1], nil, 1) return 'sent'")


def run():
    lines, faults = [], []

    def check(what, got, *need):
        miss = [n for n in need if n not in str(got)]
        lines.append(f"{'FAIL' if miss else 'ok  '} {what}: {str(got).strip()}" + (f"  (missing {miss})" if miss else ""))
        print(lines[-1])
        if miss:
            faults.append(what)

    time.sleep(4)
    check("at the stall", do("stall|on"), "gap=0", "state=Dock")
    check("the cards: 12 (only those in view load), no bubbles and no glow, the prices", do("shop", 5), "cards=12", "icons=12",
          "glows=0", "bubbles=0", "$100", "$2K", "$20Qa")
    check("no coins", coins(), "coins=")
    check("the second before the first", do("buy|2"), "AuraDenied Order", "aura=0")
    for junk in ("0", "13", "1.5", "nan", "x"):
        check(f"junk {junk}", do(f"buy|{junk}"), "quiet", "aura=0")
    print(coins(5000))
    check("far off", do("stall|off"), "state=Dock")
    check("the first, from far off", do("buy|1"), "AuraDenied Dock", "aura=0")
    check("back", do("stall|on"), "gap=0")
    before = coins()
    check("the first", do("buy|1"), "AuraBought 1", "aura=1")
    lines.append(f"     coins {before.strip()} then {coins().strip()} (100 less, plus what the tank earned)")
    check("again", do("buy|1"), "quiet", "aura=1")
    check("the third, not next", do("buy|3"), "AuraDenied Order", "aura=1")
    check("the second", do("buy|2"), "AuraBought 2", "aura=2")
    check("the third without its 40K", do("buy|3"), "AuraDenied Coins", "aura=2")
    check("the cards after: equipped, owned", do("shop", 5).upper(), "EQUIPPED", "OWNED")
    print(coins(60_000_000_000_000))
    for tier in range(3, 11):
        check(f"tier {tier}", do(f"buy|{tier}"), f"AuraBought {tier}", f"aura={tier}")
    check("the flame's pictures", do("pictures"), "Flame=Success", "Tip=Success", "Streaks=Success", "Lick=Success")
    for tier in range(1, 13):
        check(f"drawn {tier}", do(f"drawn|{tier}"), f"tier={tier} ", "style=Flame", f"beams={BEAMS[tier - 1]} ",
              f"emitters={EMITTERS[tier - 1]}")
    check("the old look behind its switch", do("dial|Flame|0") + do("drawn|9"), "style=Old")
    check("and back", do("dial|Flame|1") + do("drawn|9"), "style=Flame")
    do("drawn|0")
    lines.append(f"{len(faults)} faults: {faults}")
    print(lines[-1])
    with open(OUT / "check.log", "a", encoding="utf-8") as f:
        f.write(time.strftime("%Y-%m-%d %H:%M\n") + "\n".join(lines) + "\n")


if __name__ == "__main__":
    what, rest = sys.argv[1], sys.argv[2:]
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(True))
    elif what == "run":
        run()
    elif what == "look":
        print(do(f"drawn|{rest[0]}"))
    elif what == "dial":
        print(do(f"dial|{rest[0]}|{rest[1]}"))
    elif what == "flare":
        print(flare(rest[0]))
