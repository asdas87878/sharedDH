"""The saving and payout check (SaveService, PurchaseService, Lib/SaveParts; docs/design/money.md, "Selling"), with made-up
receipts and ProfileStore's stand-in store (nothing is bought, nothing reaches Roblox's store). One Studio session, about a
minute. It puts no script in: the place must already hold the working tree's (sync_src.py first, by the chat that has
Studio). It changes two workspace attributes, SaveOn on and LessonTest off, and puts both back, then the mouse and camera.
Refuses, touching nothing, if another chat has Studio (docs/Sessions.md), if Studio is not in Edit, or if a script the
check leans on is not the one on disk. Prints pass or FAIL for each check; exits 1 if any failed.
usage: python tools/studio/save_check.py <studio_id>     (from the repo's root; only the chat that has Studio)
       python tools/studio/save_check.py <studio_id> restore     (after a crash: only puts the attributes back)
"""
import json
import os
import queue
import re
import subprocess
import sys
import threading
import time

ID = sys.argv[1]
ONLY_RESTORE = len(sys.argv) > 2 and sys.argv[2] == "restore"
ROW = sys.argv[3] if len(sys.argv) > 3 else "Ride a Fish UI"  # the row of the chat that runs it
NEEDS = {
    "src/server/Services/SaveService.luau": "ServerScriptService.Server.Services.SaveService",
    "src/server/Services/PurchaseService.luau": "ServerScriptService.Server.Services.PurchaseService",
    "src/server/Services/AquariumService.luau": "ServerScriptService.Server.Services.AquariumService",
    "src/server/Services/RideService.luau": "ServerScriptService.Server.Services.RideService",
    "src/server/Services/TrainService.luau": "ServerScriptService.Server.Services.TrainService",
    "src/server/Services/SubService.luau": "ServerScriptService.Server.Services.SubService",
    "src/server/Lib/SaveParts.luau": "ServerScriptService.Server.Lib.SaveParts",
    "src/server/Lib/ProfileStore.luau": "ServerScriptService.Server.Lib.ProfileStore",
    "src/shared/Products.luau": "ReplicatedStorage.Shared.Products",
    "src/shared/Config.luau": "ReplicatedStorage.Shared.Config",
    "src/shared/Net.luau": "ReplicatedStorage.Shared.Net",
}


def holder():
    """Another chat's row in Sessions whose Studio column says it has Studio."""
    for line in open("docs/Sessions.md", encoding="utf-8").read().splitlines()[:40]:
        cells = line.split("|")
        if len(cells) > 4 and re.match(r"\W*has it", cells[-2].strip(), re.I) and ROW not in cells[1]:
            return cells[1].strip()[:60]
    return None


def mine():
    for line in open("docs/Sessions.md", encoding="utf-8").read().splitlines()[:40]:
        cells = line.split("|")
        if len(cells) > 4 and ROW in cells[1]:
            return bool(re.match(r"\W*has it", cells[-2].strip(), re.I))
    return False


if holder():
    sys.exit("another chat has Studio: " + holder())
if not ONLY_RESTORE and not mine():
    sys.exit('write "has it" in the row of "%s" in docs/Sessions.md first' % ROW)

EXE = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\mcp.bat")
proc = subprocess.Popen(["cmd.exe", "/c", EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                        text=True, encoding="utf-8", bufsize=1)
out = queue.Queue()
threading.Thread(target=lambda: [out.put(line) for line in proc.stdout], daemon=True).start()
n = [0]


def req(method, params, timeout=90):
    n[0] += 1
    proc.stdin.write(json.dumps({"jsonrpc": "2.0", "id": n[0], "method": method, "params": params}) + "\n")
    proc.stdin.flush()
    end = time.time() + timeout
    while time.time() < end:
        try:
            m = json.loads(out.get(timeout=max(0.1, end - time.time())))
        except (queue.Empty, ValueError):
            continue
        if m.get("id") == n[0]:
            return m
    raise TimeoutError(method)


def call(tool, **args):
    args["studio_id"] = ID
    m = req("tools/call", {"name": tool, "arguments": args})
    r = m.get("result") or m
    return "\n".join(c.get("text", "") for c in r.get("content", [])) or json.dumps(r)


def lua(code, dm="Server"):
    return call("execute_luau", code=code, datamodel_type=dm)


def data(code, dm="Server"):
    """The JSON the code returns."""
    text = lua('local H = game:GetService("HttpService")\nlocal function f()\n' + code + "\nend\nreturn \"<<\" .. H:JSONEncode(f()) .. \">>\"", dm)
    a, b = text.find("<<"), text.rfind(">>")
    if a < 0 or b < 0:
        raise RuntimeError(text[:600])
    body = text[a + 2:b]
    try:
        return json.loads(body)
    except ValueError:
        return json.loads(json.loads('"' + body + '"'))


SAME = r"""
local out = {}
for path, length in H:JSONDecode([==[%s]==]) do
	local at = game
	for i, name in string.split(path, ".") do
		at = if i == 1 then game:GetService(name) else at and at:FindFirstChild(name)
	end
	if not at or #at.Source ~= length[1] or string.sub(at.Source, -400) ~= length[2] then
		table.insert(out, path)
	end
end
return out
"""

BEFORE = r"""
workspace:SetAttribute("SaveCheckLesson", workspace:GetAttribute("LessonTest") == true)
workspace:SetAttribute("LessonTest", nil)
workspace:SetAttribute("SaveOn", true)
return "set"
"""

RESTORE = r"""
if workspace:GetAttribute("SaveCheckLesson") == nil then return "nothing to put back" end
workspace:SetAttribute("LessonTest", if workspace:GetAttribute("SaveCheckLesson") then true else nil)
workspace:SetAttribute("SaveCheckLesson", nil)
workspace:SetAttribute("SaveOn", nil)
task.delay(0.2, function()
	game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.Default
	workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
end)
task.wait(0.6)
return string.format("put back: LessonTest %s, SaveOn %s, %s, %s", tostring(workspace:GetAttribute("LessonTest")),
	tostring(workspace:GetAttribute("SaveOn")), tostring(game:GetService("UserInputService").MouseBehavior), tostring(workspace.CurrentCamera.CameraType))
"""

HEAD = r"""
local S = game:GetService("ServerStorage")
local p = game:GetService("Players"):GetPlayers()[1]
local function look() return S.TestSave:Invoke(p, "look") end
local function buy(gives, amount, id) return S.TestReceipt:Invoke(p, { Key = "Check", Gives = gives, Amount = amount, Kind = "Product", Id = 1 }, id) end
local function now()
	local l = look()
	local t = l and l.Data.Parts
	return { Coins = p:GetAttribute("Coins"), Max = p:GetAttribute("MaxOxygen"), Oxygen = p:GetAttribute("Oxygen"), State = p:GetAttribute("State"),
		KeptCoins = t and t.Tank and t.Tank.Coins, KeptOxygen = t and t.Oxygen, KeptTrainer = t and t.Trainer, KeptSub = t and t.Sub and t.Sub.Tier,
		Fish = t and t.Tank and #t.Tank.Fish, Hands = t and t.Tank and (if t.Tank.Hands then #t.Tank.Hands else 0), Receipts = l and #l.Data.Receipts, SavedReceipts = l and l.Saved.Receipts and #l.Saved.Receipts,
		SavedTank = p:GetAttribute("SavedTank"), SavedOxygen = p:GetAttribute("SavedOxygen"), SavedTrainer = p:GetAttribute("SavedTrainer"),
		SavedSub = p:GetAttribute("SavedSub"), SavedBest = p:GetAttribute("SavedBest") }
end
"""

failed = []


def check(name, ok, detail=""):
    print(("pass  " if ok else "FAIL  ") + name + ("  " + str(detail) if detail != "" else ""), flush=True)
    if not ok:
        failed.append(name)


def near(a, b):
    return a is not None and b is not None and abs(a - b) < 0.6


def state():
    return call("get_studio_state")


req("initialize", {"protocolVersion": "2026-07-28", "capabilities": {}, "clientInfo": {"name": "c", "version": "1"}})
proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}) + "\n")
proc.stdin.flush()

if "Mode: Edit" not in state():
    proc.kill()
    sys.exit("Studio is not in Edit: not touched")
if ONLY_RESTORE:
    print(lua(RESTORE, "Edit"))
    proc.kill()
    sys.exit()

wanted = {}
for path, where in NEEDS.items():
    source = open(path, encoding="utf-8", newline="").read().replace("\r\n", "\n").encode("utf-8")
    wanted[where] = [len(source), source[-400:].decode("utf-8", "ignore")]
other = data(SAME % json.dumps(wanted), "Edit")
if other:
    proc.kill()
    sys.exit("not the scripts on disk (sync first): " + ", ".join(other))
if holder() or "Mode: Edit" not in state():
    proc.kill()
    sys.exit("Studio was taken meanwhile: not touched")
print(lua(BEFORE, "Edit"))
playing = False
try:
    print(call("start_stop_play", is_start=True)[:100])
    playing = True
    a = None
    for _ in range(20):
        time.sleep(2)
        try:
            a = data(HEAD + "if not p or not S:FindFirstChild('TestSave') or not look() then return {} end return now()")
        except Exception:  # (the game is still starting)
            continue
        if a.get("SavedTank") and a.get("SavedOxygen"):
            break
    a = a or {}
    check("every part is on", all(a.get("Saved" + k) for k in ("Tank", "Oxygen", "Trainer", "Sub", "Best")), a)
    time.sleep(2)
    a = data(HEAD + "return now()")

    d = data(HEAD + "local r = buy('Coins', 1000, 'r1') local o = now() o.R = r return o")
    check("coins given once", d["R"] == "PurchaseGranted" and near(d["Coins"], a["Coins"] + 1000), (a["Coins"], d["Coins"], d["R"]))
    check("the receipt and the coins are in the save", d["SavedReceipts"] == 1 and near(d["KeptCoins"], d["Coins"]), (d["SavedReceipts"], d["KeptCoins"]))
    e = data(HEAD + "local r = buy('Coins', 1000, 'r1') local o = now() o.R = r return o")
    check("the same receipt gives nothing again", e["R"] == "PurchaseGranted" and near(e["Coins"], d["Coins"]) and e["Receipts"] == 1, (e["Coins"], e["R"]))

    e = data(HEAD + """
local got = {}
for i = 1, 2 do task.spawn(function() got[i] = buy('Coins', 500, 'r2') end) end
local from = os.clock()
while not (got[1] and got[2]) and os.clock() - from < 50 do task.wait(0.1) end
local o = now() o.A = got[1] or "?" o.B = got[2] or "?" return o""")
    check("asked twice at once, given once", near(e["Coins"], d["Coins"] + 500) and sorted([e["A"], e["B"]]) == ["NotProcessedYet", "PurchaseGranted"], (e["Coins"], e["A"], e["B"]))

    f = data(HEAD + "local o = { buy('Coins', 0, 'x1'), buy('Nothing', 10, 'x2') } local m = now() m.R = o return m")
    check("no amount or nothing to give: not yet", f["R"] == ["NotProcessedYet", "NotProcessedYet"] and near(f["Coins"], e["Coins"]) and f["Receipts"] == 2, f["R"])

    g = data(HEAD + "local r = buy('Oxygen', 5000, 'r3') local o = now() o.R = r return o")
    check("Oxygen on the dock: max and meter up", g["R"] == "PurchaseGranted" and near(g["Max"], f["Max"] + 5000) and near(g["Oxygen"], g["Max"]), (f["Max"], g["Max"], g["Oxygen"], g["State"]))

    # into the water: the owner's panel sends them to land 1, and later fails the dive
    admin = 'game:GetService("ReplicatedStorage"):FindFirstChild("Admin", true):FireServer(%s)'
    lua(admin % '"Land", 1', "Client")
    for _ in range(10):
        time.sleep(0.5)
        if data(HEAD + "return now()")["State"] != "Dock":
            break
    h = data(HEAD + """
local before = now()
local r = buy('Oxygen', 7000, 'r4')
local o = now() o.R = r o.Before = before return o""")
    b = h["Before"]
    if b["State"] == "Dock":
        check("Oxygen in the water: waits for the dock", False, "never left the dock: not tried")
    else:
        check("Oxygen in the water: the max waits", h["R"] == "PurchaseGranted" and near(h["Max"], b["Max"]) and h["Oxygen"] <= b["Oxygen"] + 0.6, (b["State"], h["State"], b["Max"], h["Max"], b["Oxygen"], h["Oxygen"]))
        check("and is saved at once", near(h["KeptOxygen"], b["KeptOxygen"] + 7000), (b["KeptOxygen"], h["KeptOxygen"]))
        i = h
        lua(admin % '"Fail"', "Client")
        for _ in range(20):
            if i["State"] == "Dock":
                break
            time.sleep(2)
            i = data(HEAD + "return now()")
        check("and joins the max at the dock", i["State"] == "Dock" and near(i["Max"], b["Max"] + 7000), (i["State"], i["Max"]))

    for _ in range(10):
        time.sleep(1)
        j = data(HEAD + "return now()")
        if j["State"] == "Dock":
            break
    # the real packs, as Products has them; then the top ones six times more (Oxygen past 50B)
    packs = [(g, int(n.replace("_", ""))) for g, n in re.findall(r'Gives = "(\w+)",\s*Amount = ([\d_]+)', open("src/shared/Products.luau", encoding="utf-8").read())]
    for _ in range(6):
        packs += [max(x for x in packs if x[0] == g) for g in ("Coins", "Oxygen")]
    before = data(HEAD + "return now()")
    after = data(HEAD + "local no = 0 for i, x in H:JSONDecode([==[%s]==]) do if buy(x[1], x[2], 'p' .. i) ~= 'PurchaseGranted' then no += 1 end end local o = now() o.No = no return o" % json.dumps(packs))
    coins, oxygen = (sum(n for g, n in packs if g == k) for k in ("Coins", "Oxygen"))
    check("the %d real packs, all given and kept to the last one" % len(packs), after["No"] == 0 and near(after["Coins"], before["Coins"] + coins)
          and near(after["KeptCoins"], after["Coins"]) and near(after["KeptOxygen"], before["KeptOxygen"] + oxygen) and near(after["Max"], before["Max"] + oxygen)
          and after["Receipts"] == before["Receipts"] + len(packs), (after["No"], after["Coins"], after["KeptOxygen"], after["Max"], after["Receipts"]))
    # a fish in the hands (the owner's panel gives it): kept, and back stored in the tank
    lua(admin % '"Fish", "Clownfish", "Normal", ""', "Client")
    time.sleep(2)
    j = data(HEAD + "return now()")
    check("a fish in the hands is kept", j["Hands"] == 1, (j["Hands"], j["Fish"]))
    k = data(HEAD + "local r = S.TestSave:Invoke(p, 'reopen') task.wait(2.5) local o = now() o.R = r return o")
    check("closed and opened again: what was kept is given back (twice what there was)", k["R"] is True and near(k["Coins"], 2 * j["Coins"]) and near(k["KeptOxygen"], 2 * j["KeptOxygen"]), (j["Coins"], k["Coins"], j["KeptOxygen"], k["KeptOxygen"]))
    check("every part is on again", all(k.get("Saved" + x) for x in ("Tank", "Oxygen", "Trainer", "Sub", "Best")))
    check("the carried fish comes back in the tank, once", k["Fish"] == 2 * j["Fish"] + j["Hands"] and k["Hands"] == j["Hands"], (j["Fish"], k["Fish"], k["Hands"]))
    check("trainer, subs, receipts as they were", k["KeptTrainer"] == j["KeptTrainer"] and k["KeptSub"] == j["KeptSub"] and k["Receipts"] == j["Receipts"], (k["KeptTrainer"], k["KeptSub"], k["Receipts"]))
    m = data(HEAD + "local r = buy('Coins', 1000, 'r1') local o = now() o.R = r return o")
    check("the first receipt gives nothing after coming back", m["R"] == "PurchaseGranted" and near(m["Coins"], k["Coins"]), (m["Coins"], m["R"]))
    console = call("get_console_output")
    ours = [line for line in console.splitlines() if any(w in line for w in ("SaveService", "SaveParts", "PurchaseService", "ProfileStore", "[Main]"))]
    print("console, ours:", *ours[-12:], sep="\n  ")
except Exception as problem:  # (whatever went wrong, the place is put back)
    check("the run", False, repr(problem)[:700])
finally:
    if playing:
        print(call("start_stop_play", is_start=False)[:100])
        time.sleep(5)
    for _ in range(10):
        if "Mode: Edit" in state():
            break
        time.sleep(2)
    print(lua(RESTORE, "Edit"))
    proc.kill()
print("all passed" if not failed else "FAILED: " + ", ".join(failed))
sys.exit(1 if failed else 0)
