"""The new Index window (docs/design/ui.md, "The Index, richer"), its ring and the offline rewards
(docs/design/offline-rewards.md), checked in one Studio playtest on Hugo's PC (studio-runner). NULLROOM m2, 2026-11-25.
IT MOVES THE PLAYER AND GIVES THEM FISH: only in a playtest you started, with nobody playing in it.
    python tools/index/land_banners.py studio ; python tools/offline/picture.py studio    (the pictures, into Studio's own folder)
    python tools/studio/index_offline_check.py install [away]   (in Edit, before Play; away: OfflineAway set, 3 h 12 min)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/index_offline_check.py gate             (are the window's pictures live? needed before stills)
    python tools/studio/index_offline_check.py offline | banners | arrow | frames | rings | index | phone | seen | before
    python tools/studio/index_offline_check.py do "verb|args" | cmd "verb|args"
    node ~/Projects/studio-runner/studio-run.mjs stop
    python tools/studio/index_offline_check.py remove           (in Edit, after the stop; the attributes put back)
It is tools/studio/h4_hub_check.py (its rings, index and phone run as they are) with verbs and pieces of its own.
A press a script can not make is made as the button's own listener makes it (Claim: the remote's "Claim").
Logs and stills: work/index_offline/.
"""
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import h4_hub_check as h  # noqa: E402

h.OUT = h.ROOT / "work/index_offline"
h.OUT.mkdir(parents=True, exist_ok=True)
h.VIEW_FILE = h.OUT / "view.json"
fc = h.fc
AWAY, RATE = 11520, 40  # 3 h 12 min, at a pretend 40 coins a second: 40 * 11520 / 2
OWED = RATE * AWAY // 2
SIZES = {"pc": None, "side": (844, 390), "tall": (390, 844), "small": (667, 375), "narrow": (375, 812)}

MORE = r'''
local function words(top, s)
	local o = {}
	for _, d in top:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and shownAll(d, s) and d.TextTransparency < 1 then
			table.insert(o, d.Name .. ":" .. string.gsub(d.Text, "[\n;|]", " ") .. (if d.TextFits then "" else "(CUT)"))
		end
	end
	return table.concat(o, ", ")
end
-- words|Gui: every word shown in it
V.words = function(a)
	local s = gui:FindFirstChild(a[1], true)
	return if s then words(s, s:FindFirstAncestorWhichIsA("ScreenGui") or s) else "no " .. tostring(a[1])
end
-- banner|land: the banner's painting and its tab's
V.banner = function(a)
	local land = tonumber(a[1])
	IndexPanel.press("Land", land)
	task.wait(0.9)
	local s = gui:FindFirstChild("IndexPanel")
	local o = {}
	for _, n in { "LandSet", "Land" .. land } do
		local at = s and s:FindFirstChild(n, true)
		local p = at and at:FindFirstChild("Painting", true)
		if p and p:IsA("ImageLabel") then
			table.insert(o, string.format("%s image=%s loaded=%s see=%.2f size=%dx%d shown=%s", n, string.match(p.Image, "[^/]+$") or "none",
				tostring(p.IsLoaded), p.ImageTransparency, p.AbsoluteSize.X, p.AbsoluteSize.Y, tostring(shownAll(p, s))))
		else
			table.insert(o, n .. " image=NONE")
		end
	end
	local set = s and s:FindFirstChild("LandSet", true)
	table.insert(o, "words {" .. (if set then words(set, s) else "") .. "}")
	return table.concat(o, " ; ")
end
-- the arrow at CLAIM ALL
V.arrow = function()
	local s = gui:FindFirstChild("IndexPanel")
	local all = s and s:FindFirstChild("ClaimAll", true)
	if not all then
		return "no ClaimAll"
	end
	for _, d in all:GetChildren() do
		if d:IsA("GuiObject") and d.Rotation == -90 then
			local title = s:FindFirstChild("Title", true)
			return string.format("arrow=%s at=%d,%d to=%d,%d all=%d,%d title='%s' ends=%d paid=%s", tostring(shownAll(d, s)), d.AbsolutePosition.X, d.AbsolutePosition.Y,
				d.AbsolutePosition.X + d.AbsoluteSize.X, d.AbsolutePosition.Y + d.AbsoluteSize.Y, all.AbsolutePosition.X, all.AbsolutePosition.Y,
				if title and title:IsA("TextLabel") then title.Text else "?", if title and title:IsA("TextLabel") then title.AbsolutePosition.X + title.TextBounds.X else 0,
				tostring(player:GetAttribute("IndexPaid")))
		end
	end
	return "arrow=none paid=" .. tostring(player:GetAttribute("IndexPaid"))
end
-- the offline window, its chip and the coins
V.off = function()
	local o = { "page=" .. tostring(Shop.Page), "owed=" .. tostring(player:GetAttribute("OfflineOwed")), "secs=" .. tostring(player:GetAttribute("OfflineSecs")), "coins=" .. tostring(player:GetAttribute("Coins")) }
	local s = gui:FindFirstChild("OfflinePanel")
	if s then
		local c = s:FindFirstChild("Close", true)
		table.insert(o, "open=" .. tostring(c ~= nil and shownAll(c, s)))
		for _, d in s:GetDescendants() do
			if d:IsA("ImageLabel") and d.Name == "Chest" then
				table.insert(o, "chest=" .. (string.match(d.Image, "[^/]+$") or "none") .. "/" .. tostring(d.IsLoaded))
			end
		end
	else
		table.insert(o, "open=none")
	end
	local chip = gui:FindFirstChild("OfflineClaim", true)
	if chip then
		local hud = chip:FindFirstAncestorWhichIsA("ScreenGui")
		table.insert(o, string.format("chip=%s chipat=%d,%d,%d,%d", tostring(shownAll(chip, hud)), chip.AbsolutePosition.X, chip.AbsolutePosition.Y, chip.AbsolutePosition.X + chip.AbsoluteSize.X, chip.AbsolutePosition.Y + chip.AbsoluteSize.Y))
		local buttons = hud:FindFirstChild("HubButtons", true)
		if buttons then
			table.insert(o, string.format("hub=%d,%d,%d,%d", buttons.AbsolutePosition.X, buttons.AbsolutePosition.Y, buttons.AbsolutePosition.X + buttons.AbsoluteSize.X, buttons.AbsolutePosition.Y + buttons.AbsoluteSize.Y))
		end
	else
		table.insert(o, "chip=none")
	end
	return table.concat(o, " ") .. " ; words {" .. (if s then words(s, s) else "") .. "}" .. (if chip then " chip {" .. words(chip, chip:FindFirstAncestorWhichIsA("ScreenGui")) .. "}" else "")
end
-- offclaim|n: CLAIM, n times in one frame (the press's own line: the remote's "Claim")
V.offclaim = function(a)
	local r = Net.Folder:FindFirstChild("Offline")
	for _ = 1, tonumber(a[1]) or 1 do
		r:FireServer("Claim")
	end
	task.wait(0.8)
	return V.off()
end
-- the dock's goal line and lesson words, if any
V.lines = function()
	local o = {}
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiObject") and type(d:GetAttribute("Words")) == "string" then
			table.insert(o, d.Name .. "=" .. tostring(d.Visible) .. ":" .. d:GetAttribute("Words"))
		end
	end
	return table.concat(o, " ; ")
end
-- live: as a live game shows it before the uploads (no land paintings, no chest); before the windows are first opened
V.live = function()
	need(Client, "UI", "LandBanners").image = function()
		return ""
	end
	need(Client, "UI", "OfflinePanel").Chest = need(Client, "UI", "Kit").Textures.Cash
	return "live"
end
-- set|Group|Key|number: a Config number on this machine only
V.set = function(a)
	(Config :: any)[a[1]][a[2]] = tonumber(a[3])
	return a[1] .. "." .. a[2] .. "=" .. tostring((Config :: any)[a[1]][a[2]])
end
-- frames|seconds: the frame's time
V.frames = function(a)
	local all, t0 = {}, os.clock()
	while os.clock() - t0 < (tonumber(a[1]) or 3) do
		table.insert(all, RunService.RenderStepped:Wait())
	end
	table.sort(all)
	local sum = 0
	for _, d in all do
		sum += d
	end
	return string.format("n=%d mean=%.2f mid=%.2f p95=%.2f worst=%.2f", #all, sum / #all * 1000, all[#all // 2 + 1] * 1000, all[math.max(1, math.floor(#all * 0.95))] * 1000, all[#all] * 1000)
end
'''
MARK = 'workspace:GetAttributeChangedSignal("H4Do")'
assert h.CLIENT.count(MARK) == 1
h.CLIENT = h.CLIENT.replace(MARK, MORE + MARK)


def attributes(away):
    values = {"OfflineAway": AWAY if away else None, "OfflineRate": RATE if away else None}
    return h.edit("\n".join(f"workspace:SetAttribute('{k}', {fc.lua(v)})" for k, v in values.items()) + "\nreturn 'attributes'")


def errors():
    """Every error and warning line in the server's and the client's log of this playtest."""
    server = fc.server("local o = {} for _, m in game:GetService('LogService'):GetLogHistory() do "
                       "if m.messageType == Enum.MessageType.MessageError or m.messageType == Enum.MessageType.MessageWarning then "
                       "table.insert(o, (string.gsub(string.sub(m.message, 1, 250), '\\n', ' '))) end end return table.concat(o, '\\n')")
    h.note("server log:\n" + server)
    h.note("client log:\n" + h.said())


def put(size):
    return h.do("phone|%d|%d" % size if size else "phone|off")


def boxed(gui, label, size):
    """The window is whole on the screen and none of its words are cut."""
    text = h.do("box|" + gui)
    h.note(f"  {label}: {text}")
    if "window " not in text or "no window" in text:
        return h.expect(f"{label}: the window is up", False, text[:200])
    out = text.split("outside ")[1].split(":")[0]
    cut = text.split("not fitting ")[1].split(";")[0]
    h.expect(f"{label}: whole on the screen", out == "0", text.split("outside ")[1].split(";")[0])
    h.expect(f"{label}: no word is cut", cut.startswith("0"), cut)


def offline():
    h.note("== offline rewards")
    end = time.time() + 12
    while time.time() < end and "page=Offline" not in h.do("off"):
        time.sleep(0.3)
    text = h.do("off")
    h.note("  " + text)
    f = h.fields(text.split(" ; words")[0])
    h.expect("the window comes up by itself on the dock", f.get("page") == "Offline" and f.get("open") == "true", f.get("page"))
    h.expect(f"it owes {OWED}", f.get("owed") == str(OWED), f.get("owed"))
    h.expect("the words: the time away and Claim", "3 h 12 min" in text and "Claim!" in text and "OFFLINE EARNINGS" in text.upper())
    h.expect("the chest picture is loaded", "chest=offline_chest_o1.png/true" in text)
    for name, size in SIZES.items():
        put(size)
        time.sleep(0.5)
        boxed("OfflinePanel", f"offline {name}", size)
        if h.VIEW_FILE.exists():
            h.still(f"offline-{name}", 0.8)
    put(None)
    before = float(f.get("coins", 0) or 0)
    h.do("go|")  # the X
    time.sleep(0.8)
    text = h.do("off")
    f = h.fields(text.split(" ; words")[0])
    h.expect("the X keeps it: shut, the small Claim up, still owed, nothing paid",
             f.get("page") == "nil" and f.get("chip") == "true" and f.get("owed") == str(OWED) and float(f.get("coins", 0)) == before, text)
    for name, size in SIZES.items():
        put(size)
        time.sleep(0.8)
        t = h.do("off")
        g = h.fields(t.split(" ; words")[0])
        h.note(f"  chip {name}: {t}")
        if "chipat" in g and "hub" in g:
            a, b = [[int(v) for v in g[k].split(",")] for k in ("chipat", "hub")]
            over = a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]
            h.expect(f"chip {name}: clear of the dock's buttons", not over, f"{a} against {b}")
        if h.VIEW_FILE.exists():
            h.still(f"chip-{name}", 0.8)
    put(None)
    time.sleep(0.4)
    time.sleep(2)
    h.expect("it does not come up again by itself", "page=nil" in h.do("off"))
    h.do("go|Offline")
    h.expect("the small Claim's page opens it again", "page=Offline" in h.do("off"))
    f0 = h.fields(h.do("off").split(" ; words")[0])
    text = h.do("offclaim|3")
    f = h.fields(text.split(" ; words")[0])
    paid = float(f.get("coins", 0)) - float(f0.get("coins", 0))
    h.expect("CLAIM three times in one frame pays once", paid == OWED, f"+{paid:g}, owed {f.get('owed')}")
    h.expect("claimed: the window and the small Claim are gone", f.get("page") == "nil" and f.get("chip") == "false" and f.get("owed") == "nil", text)
    if h.VIEW_FILE.exists():
        h.still("offline-claimed", 0.0)
    time.sleep(1.0)
    f1 = h.fields(h.do("offclaim|1").split(" ; words")[0])
    h.expect("CLAIM with nothing owed pays nothing", f1.get("coins") == f.get("coins"), f"{f.get('coins')} -> {f1.get('coins')}")
    h.save_log()


def banners():
    h.note("== every land's banner")
    for name, size in SIZES.items():
        if name == "small" or name == "narrow":
            continue
        put(size)
        h.do("go|Index")
        time.sleep(0.6)
        for land in range(1, 11):
            t = h.do(f"banner|{land}")
            want = f"land_banner_{land:02d}.png loaded=true"
            h.expect(f"{name} land {land}: banner and tab show its own painting", t.count(want) == 2 and t.count("shown=true") == 2 and "(CUT)" not in t, t)
            if h.VIEW_FILE.exists() and (name == "pc" or land in (1, 10)):
                h.still(f"banner-{name}-{land:02d}", 0.4)
        h.do("go|")
    put(None)
    h.save_log()


def arrow():
    h.note("== the arrow at CLAIM ALL, until the first claim")
    roster = json.loads(h.cmd("roster"))
    ids = [row for row in roster["Lands"] if row["Land"] == 1][0]["Set"]
    h.do("go|Index")
    h.expect("nothing waits: no arrow", "arrow=true" not in h.do("arrow"), h.do("arrow"))
    h.do("go|")
    for fid in ids[:3]:
        h.cmd(f"carry|{fid}|Normal|", 0.6)
        h.cmd("take", 0.1)
    for name, size in SIZES.items():
        put(size)
        h.do("go|Index")
        time.sleep(0.6)
        t = h.do("arrow")
        f = h.fields(t)
        h.expect(f"{name}: the arrow is up, its end before the button, clear of the title",
                 f.get("arrow") == "true" and int(f["at"].split(",")[0]) >= int(f.get("ends", "0")) - 1, t)
        boxed("IndexPanel", f"index {name}", size)
        if h.VIEW_FILE.exists():
            h.still(f"arrow-{name}", 0.6)
        h.do("go|")
    put(None)
    h.do("go|Index")
    h.do("index|ClaimAll", timeout=8)
    time.sleep(0.8)
    t = h.do("arrow")
    h.expect("after the first claim: no arrow", "arrow=true" not in t, t)
    if h.VIEW_FILE.exists():
        h.still("claimed-pc", 0.2)
    h.do("go|")
    h.cmd(f"carry|{ids[3]}|Normal|", 0.6)
    h.cmd("take", 0.1)
    h.do("go|Index")
    t = h.do("arrow")
    h.expect("a new reward after it: still no arrow", "arrow=true" not in t and "claims=1" in h.cmd("read"), t)
    h.do("go|")
    h.save_log()


def frames():
    h.note("== frame time, ms")
    for name, page in (("nothing open", ""), ("the Index", "Index"), ("nothing open again", "")):
        h.do("go|" + page)
        time.sleep(1)
        h.note(f"  {name}: " + h.do("frames|5", timeout=12))
    for _ in range(2):
        h.note("  opening the Index: " + h.do("frames|1", timeout=8))
        h.start("go|Index")
        h.note("  while it opens: " + h.do("frames|1.5", timeout=8))
        h.do("go|")
    h.save_log()


def before():
    """What a live game shows before the uploads, the dive with coins waiting, and the switches. In a fresh playtest,
    installed without `away`."""
    h.note("== before the uploads, the dive, the switches")
    h.do("live")
    fc.server(f"workspace:SetAttribute('OfflineRate', {RATE}) workspace:SetAttribute('OfflineAway', {AWAY}) return 1")
    time.sleep(3.5)
    t = h.do("off")
    h.expect("away: the window comes up by itself, with the cash picture", "page=Offline" in t and "offline_chest" not in t and "/true" in t, t)
    h.still("live-offline-pc", 0.6)
    h.do("go|")
    h.cmd("ride|Clownfish", 2.5)
    t = h.do("off")
    h.expect("on a dive: no window and no small Claim", "page=nil" in t and "chip=false" in t, t[:200])
    h.cmd("home", 2.5)
    time.sleep(2)
    t = h.do("off")
    h.expect("back on the dock: the small Claim, not the window, still owed", "page=nil" in t and "chip=true" in t and f"owed={OWED}" in t, t[:200])
    h.still("chip-home", 0.5)
    h.do("set|Offline|On|0")
    time.sleep(0.8)
    t = h.do("off")
    h.expect("Config.Offline.On 0: the small Claim is gone", "chip=false" in t, t[:200])
    h.do("set|Offline|On|1")
    time.sleep(0.8)
    t = h.do("offclaim|1")
    h.expect("claimed after the dive", f"coins={OWED}" in t and "owed=nil" in t, t[:200])
    roster = json.loads(h.cmd("roster"))
    ids = [row for row in roster["Lands"] if row["Land"] == 1][0]["Set"]
    for fid in ids[:2]:
        h.cmd(f"carry|{fid}|Normal|", 0.6)
        h.cmd("take", 0.1)
    for name in ("pc", "side", "tall"):
        put(SIZES[name])
        h.do("go|Index")
        boxed("IndexPanel", f"no paintings, {name}", SIZES[name])
        h.still(f"live-index-{name}", 0.8)
        h.do("go|")
    put(None)
    h.do("set|Index|Look|0")
    h.do("go|Index")
    t = h.do("arrow")
    h.expect("Config.Index.Look 0: the old window, with its arrow", "arrow=true" in t and "Painting" not in h.do("words|IndexPanel"), t)
    h.still("look0-pc", 0.6)
    h.do("go|")
    for _ in range(2):
        h.start("go|Index")
        h.note("  the old window, while it opens: " + h.do("frames|1.5", timeout=8))
        h.do("go|")
    h.do("set|Index|Look|1")
    for _ in range(3):
        h.start("go|Index")
        h.note("  the new window, while it opens: " + h.do("frames|1.5", timeout=8))
        h.do("go|")
    h.save_log()


def seen():
    """A still of the Index on each screen as it is now."""
    for name, size in SIZES.items():
        put(size)
        h.do("go|Index")
        h.still(f"index-{name}", 1.2)
        h.do("go|")
    put(None)


RUNS = {"offline": offline, "banners": banners, "arrow": arrow, "frames": frames, "seen": seen, "before": before,
        "rings": h.rings, "index": h.index, "phone": h.phone}

if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        print(h.install())
        print(attributes("away" in sys.argv[2:]))
    elif what == "remove":
        print(h.install(remove=True))
        print(attributes(False))
    elif what == "do":
        print(h.do(sys.argv[2], timeout=20))
    elif what == "cmd":
        print(h.cmd(sys.argv[2]))
    elif what == "errors":
        errors()
    elif what == "gate":
        h.gate()
    elif what == "still":
        print(h.still(sys.argv[2]))
    else:
        ok, got, want = h.mine()
        if not ok:
            raise SystemExit(f"the playtest's helper is not this file's ({got} against {want}): not our Play, nothing driven")
        try:
            for name in sys.argv[1:]:
                RUNS[name]()
        finally:
            h.note(f"passed {len(h.PASS)}, failed {len(h.FAIL)}")
            for line in h.FAIL:
                h.note("FAILED: " + line)
            errors()
            h.save_log()
