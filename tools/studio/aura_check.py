"""The auras in a playtest (task a1, 2026-11-24; the 3D look 2026-11-25): buying through the real remote, the stall's cards,
what is drawn, and the fade.
    python tools/auras/volume_sheets.py --local ; python tools/auras/flame_pics.py    (once, then reopen Studio: the pictures)
    python tools/studio/s2_subs_check.py install ; python tools/studio/aura_check.py install      (in Edit, before Play)
    node ~/Projects/studio-runner/studio-run.mjs play                (a fresh play: the run starts with no aura)
    python tools/studio/aura_check.py run                            (in the playtest: the numbers; its faults are listed)
    python tools/studio/aura_check.py look 6                         (your own player shows tier 6; 0: what you own)
    python tools/studio/aura_check.py dial Turn 1                    (Config.Aura's dials: Look 2, 1, 0; Turn, Scroll, Behind for Look 1; the rest)
    python tools/studio/aura_check.py flare Land | Eat | Jumping     (one flare on your own player, as the server would say)
    python tools/studio/aura_check.py ask bare 1; ask land 6 14; ask ride GreatWhite 6; ask frames 12; ask free; ask scroll 1 ; ask fade 12  (the stills, the cost, the fade)
    python tools/studio/aura_check.py remove ; python tools/studio/s2_subs_check.py remove        (in Edit, after)
By eye, with `look` 1, 6, 12 beside docs/attachments/auras-3d.png: docs/design/auras.md, "To see in Studio" (the spray goes
out and not in, what lies flat stays flat while the fish pitches, the ribbons wind round both sides, nothing turns with
the camera); riding; and the burst: buy tier 10. With `dial Look 1`: the old flame, and its own list further down there.
The real click on a card, and its sounds, are by hand. Log: work/auras/check.log.
"""
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import s2_subs_check as s2  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "work/auras"
OUT.mkdir(parents=True, exist_ok=True)
# the flame's (Config.Aura.Look 1); the 3D look's are asked of Shared/AuraVolume (the verb `want`)
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
local AuraAround = require(Client:WaitForChild("Lib"):WaitForChild("AuraAround"))
local AuraVolume = require(Shared:WaitForChild("AuraVolume"))
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
function verbs.scroll(x)
	local f = gui:FindFirstChild("AuraShop", true):FindFirstChildWhichIsA("ScrollingFrame", true)
	f.CanvasPosition = Vector2.new((tonumber(x) or 0) * f.AbsoluteCanvasSize.X, 0)
	task.wait(2)
	return "scrolled"
end
-- what the 3D look should draw of a tier close by on a PC: its Beams and its emitters (those with a picture)
function verbs.want(n)
	local spec = AuraVolume.spec(tonumber(n))
	local beams, emitters = 0, 0
	for _, s in spec.Strands do beams += s.Beams end
	for _, l in spec.Layers do
		if (AuraAround.picture(l.Picture)) ~= "" then emitters += 1 end
	end
	return string.format("beams=%d emitters=%d", beams, emitters)
end
-- standing, then pushed along the dock, then standing: what is drawn at each, and how long the fade took
function verbs.fade(n)
	Auras.Test = tonumber(n) or 0
	task.wait(1.4)
	local root = player.Character.HumanoidRootPart
	local function draws()
		local _, _, b, e = AuraController.drawn(player.Character)
		return b + e
	end
	local before, away, back = draws(), nil, nil
	local start = os.clock()
	while os.clock() - start < 0.7 do
		root.AssemblyLinearVelocity = Vector3.new(if os.clock() - start < 0.35 then 14 else -14, root.AssemblyLinearVelocity.Y, 0)
		task.wait()
		if not away and draws() == 0 then away = os.clock() - start end
	end
	local moving = draws()
	root.AssemblyLinearVelocity = Vector3.zero
	start = os.clock()
	while os.clock() - start < 1.5 do
		task.wait()
		if not back and draws() > 0 then back = os.clock() - start end
	end
	return string.format("stood=%d moving=%d after=%d gone in %.2f s, starts back in %.2f s", before, moving, draws(), away or -1, back or -1)
end
function verbs.drawn(n)
	Auras.Test = tonumber(n) or 0
	-- (the 3D look fades in: StillFor, then FadeIn)
	task.wait(1.4)
	local tier, style, beams, emitters = AuraController.drawn(player.Character)
	return string.format("tier=%d style=%s beams=%d emitters=%d", tier, style, beams, emitters)
end
function verbs.pictures()
	local out = {}
	for name in Auras.Sheets do
		ContentProvider:PreloadAsync({ (AuraAround.picture(name)) }, function(_, status: Enum.AssetFetchStatus)
			table.insert(out, "3D" .. name .. "=" .. status.Name)
		end)
	end
	for name in Auras.Pictures do
		-- (GetAssetFetchStatus says None for a Beam's or an emitter's picture, drawn or not)
		ContentProvider:PreloadAsync({ AuraBeams.picture(name) }, function(_, status: Enum.AssetFetchStatus)
			table.insert(out, name .. "=" .. status.Name)
		end)
	end
	return table.concat(out, " ")
end
function verbs.dial(key, n)
	local t: any = if (Config.Aura :: any)[key] ~= nil then Config.Aura else require(Shared:WaitForChild("AuraFlame"))
	t[key] = tonumber(n)
	task.wait(0.5)
	return key .. "=" .. tostring(t[key])
end
-- the stills: no windows over the view; a second player (a copy, its name over its head) beside you; a held camera
local rig: Model? = nil
function verbs.bare(on)
	for _, g in gui:GetChildren() do
		if g:IsA("ScreenGui") then g.Enabled = on ~= "1" end
	end
	return "bare " .. tostring(on)
end
function verbs.land(tier, pitch, fov)
	if rig then rig:Destroy() rig = nil end
	Auras.Test = tonumber(tier) or 0
	local char = player.Character
	local root = char.HumanoidRootPart
	char.Archivable = true
	local c = char:Clone()
	for _, d in c:GetDescendants() do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end
	c.Name = "ZZRig"
	local hum = c:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = "Player Two"
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	local at = CFrame.new(root.Position)
	c.HumanoidRootPart.Anchored = true
	c:PivotTo(at * CFrame.new(9, 0, 0) * CFrame.Angles(0, math.pi, 0))
	c:SetAttribute("Aura", Auras.Test)
	c.Parent = workspace
	game:GetService("CollectionService"):AddTag(c, "AuraRig")
	rig = c
	root.CFrame = at
	local cam = workspace.CurrentCamera
	local down = math.rad(tonumber(pitch) or 14)
	local mid = root.Position + Vector3.new(4.5, 1, 0)
	game:GetService("RunService"):BindToRenderStep("ZZAuraCam", 3000, function()
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = tonumber(fov) or 70
		cam.CFrame = CFrame.lookAt(mid + Vector3.new(0, math.sin(down), math.cos(down)) * 15, mid)
	end)
	task.wait(1.5)
	return "land " .. tostring(tier)
end
function verbs.free()
	game:GetService("RunService"):UnbindFromRenderStep("ZZAuraCam")
	if rig then rig:Destroy() rig = nil end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	return "free"
end
function verbs.ride(kind, tier)
	if rig then verbs.free() end
	Auras.Test = tonumber(tier) or 0
	Net.Sandbox:FireServer("Ride", kind)
	task.wait(0.6)
	local stop = os.clock() + 4
	while player:GetAttribute("State") ~= "Riding" and os.clock() < stop do task.wait() end
	task.wait(0.8)
	return "state " .. tostring(player:GetAttribute("State"))
end
-- the mean and the worst tenth of the frame's time over two seconds, and the beams and particles of the aura
function verbs.frames(tier)
	Auras.Test = tonumber(tier) or 0
	task.wait(0.8)
	local list = {}
	local RunService = game:GetService("RunService")
	local stop = os.clock() + 2
	while os.clock() < stop do table.insert(list, RunService.RenderStepped:Wait() * 1000) end
	table.sort(list)
	local sum = 0
	for _, x in list do sum += x end
	local st = game:GetService("Stats")
	local _, _, beams, emitters = AuraController.drawn(player.Character)
	return string.format("tier=%s frame=%.2f ms worst tenth=%.2f render=%.2f ms draws=%d tris=%d beams=%d emitters=%d", tostring(tier), sum / #list,
		list[math.ceil(#list * 0.9)], st.RenderCPUFrameTime, st.SceneDrawcallCount, st.SceneTriangleCount, beams, emitters)
end
workspace:GetAttributeChangedSignal("AuraDo"):Connect(function()
	local p = string.split(tostring(workspace:GetAttribute("AuraDo") or ""), "|")
	if not verbs[p[1]] then return end
	local ok, said = pcall(verbs[p[1]], p[2], p[3], p[4])
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
    sheets = [f"3D{n}=Success" for n in ("Wisp", "Flame", "Ring", "Sweep", "Shock", "Jet", "Haze", "Shaft", "Mote", "Arc", "Ribbon", "Glow")]
    check("the pictures", do("pictures", 6), *sheets, *[f"{n}=Success" for n in ("Tip", "Streaks", "Lick", "Bubble")])
    for tier in range(1, 13):
        want = re.search(r"beams=\d+ emitters=\d+", str(do(f"want|{tier}"))).group(0)
        check(f"drawn {tier} (want {want})", do(f"drawn|{tier}", 3.5) + " ", f"tier={tier} ", "style=Around", want + " ")
    for tier in (1, 12):
        got = str(do(f"fade|{tier}", 6))
        check(f"the fade, tier {tier}", got, "moving=0 ")
        n = re.search(r"stood=(\d+) .*after=(\d+)", got)
        check(f"... and back, tier {tier}", got, f"after={n.group(1)} " if n and int(n.group(1)) else "it was not drawn standing")
    for tier in range(1, 13):
        check(f"the flame {tier}", do("dial|Look|1") + do(f"drawn|{tier}", 3.5) + " ", f"tier={tier} ", "style=Flame",
              f"beams={BEAMS[tier - 1]} ", f"emitters={EMITTERS[tier - 1]} ")
    check("draft 2 behind its switch", do("dial|Look|0") + do("drawn|9", 3.5), "style=Old")
    check("and back", do("dial|Look|2") + do("drawn|9", 3.5), "style=Around")
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
    elif what == "ask":
        print(do("|".join(rest), 6))
    elif what == "flare":
        print(flare(rest[0]))
