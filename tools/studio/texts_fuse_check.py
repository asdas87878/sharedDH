"""The dock's lines and the fish tags' "Required" (docs/design/ui.md) and the Fuse machine (docs/design/fusing.md),
checked in one Studio playtest on Hugo's PC (studio-runner). NULLROOM z1, 2026-11-25.
IT MOVES THE PLAYER, KILLS THEM AND GIVES THEM FISH: only in a playtest you started, with nobody playing in it.
    python tools/studio/texts_fuse_check.py install [save] [lesson]   (in Edit, before Play: a Script, a LocalScript;
                                                                       save: the stand-in save store on; lesson: LessonTest on)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/texts_fuse_check.py texts | lesson | fuse | saved | leave
    python tools/studio/texts_fuse_check.py do VERB [A] | cmd VERB [A]
    node ~/Projects/studio-runner/studio-run.mjs stop
    python tools/studio/texts_fuse_check.py remove                     (in Edit, after the stop; attributes put back)
Logs: work/texts_fuse/.
"""
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
NAME = "ZZTextsFuse"
OUT = ROOT / "work/texts_fuse"
OUT.mkdir(parents=True, exist_ok=True)

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local AquariumService = require(Services:WaitForChild("AquariumService"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZTFReport"
report.Parent = RS
local out = Instance.new("StringValue")
out.Name = "ZZTFOut"
out.Parent = SS
local said = Instance.new("StringValue")
said.Name = "ZZTFSaid"
said.Parent = SS
local events, heard = {}, {}
local lastPlayer = nil
report.OnServerEvent:Connect(function(_, kind, text)
	if kind == "ev" then
		if #events < 5000 then table.insert(events, tostring(text)) end
	elseif kind == "log" then
		if #heard < 200 then table.insert(heard, tostring(text)) end
	else
		said.Value = tostring(kind) .. "\n" .. tostring(text)
	end
end)
local function fishOf(player)
	local tank, hands = {}, {}
	for _, f in AquariumService.tankOf(player) or {} do
		table.insert(tank, { Key = tostring(f.Key), Id = f.Id, Size = f.Size, Variant = f.Variant, On = f.On == true })
	end
	for _, f in RideService.carried(player) do
		table.insert(hands, { Key = tostring(f.Key), Id = f.Id, Size = f.Size, Variant = f.Variant, Ride = f == RideService.equippedOf(player) })
	end
	return tank, hands
end
local function answer(player, what, arg)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if what == "logs" then
		local server = {}
		for _, m in LogService:GetLogHistory() do
			if m.messageType == Enum.MessageType.MessageWarning or m.messageType == Enum.MessageType.MessageError then
				table.insert(server, m.messageType.Name .. ": " .. string.sub(m.message, 1, 300))
			end
		end
		return { server = server, client = heard }
	elseif what == "events" then
		return { events = events }
	elseif what == "state" then
		local tank, hands = fishOf(player)
		local ring = workspace.ClaudeBlockout.Dock.Stations:FindFirstChild("Fuse")
		ring = ring and ring:FindFirstChild("Ring")
		local attrs = {}
		for k, v in player:GetAttributes() do
			if type(v) ~= "string" or #v < 200 then attrs[k] = if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then v else tostring(v) end
		end
		return { state = RideService.stateOf(player), coins = AquariumService.coinsOf(player), tank = tank, hands = hands, attrs = attrs,
			root = root and { root.Position.X, root.Position.Y, root.Position.Z },
			ring = ring and { ring.Position.X, ring.Position.Y, ring.Position.Z, ring.Size.X, ring.Size.Y, ring.Size.Z } }
	elseif what == "give" then -- JSON: { coins, { {id, size, variant} } }
		local a = HttpService:JSONDecode(arg)
		return { ok = AquariumService.give(player, a[1], a[2]) }
	elseif what == "hand" then
		local a = HttpService:JSONDecode(arg)
		local ok = true
		for _, f in a do ok = RideService.giveCarried(player, { Id = f[1], Size = f[2] or "Normal", Variant = f[3] or "" }) and ok end
		return { ok = ok }
	elseif what == "empty" then -- the hands let go of, the tank's fish (all of them) taken out
		while #RideService.carried(player) > 0 do RideService.takeCarried(player, 1) end
		local n = 0
		for _, f in table.clone(AquariumService.tankOf(player) or {}) do
			if AquariumService.takeOutKey(player, f.Key) then n += 1 while #RideService.carried(player) > 0 do RideService.takeCarried(player, 1) end end
		end
		return { out = n }
	elseif what == "dump" then
		return { dump = AquariumService.dump(player) }
	elseif what == "home" then
		RideService.sendHome(player)
		return { state = RideService.stateOf(player) }
	elseif what == "fail" then
		return { ok = RideService.forceFail(player, if arg ~= "" then arg else nil) }
	elseif what == "kill" then
		character:FindFirstChildOfClass("Humanoid").Health = 0
		return { ok = true }
	elseif what == "at" then
		local x, y, z = string.match(arg, "([^,]+),([^,]+),([^,]+)")
		character:PivotTo(CFrame.new(tonumber(x), tonumber(y), tonumber(z)))
		return { ok = true }
	elseif what == "train" then
		return { ok = RideService.train(player, tonumber(arg)) }
	elseif what == "attr" then
		local k, v = string.match(arg, "([^=]+)=(.*)")
		player:SetAttribute(k, if v == "nil" then nil else v)
		return { ok = true }
	elseif what == "config" then -- Config.Fuse.<k> = number, on the server
		local k, v = string.match(arg, "([^=]+)=(.*)")
		Config.Fuse[k] = tonumber(v)
		return { now = Config.Fuse[k] }
	elseif what == "save" then
		local t = SS:WaitForChild("TestSave", 5)
		local got = t and t:Invoke(player, if arg == "" then "look" else arg)
		if type(got) == "table" then
			return { tank = got.Data.Parts and got.Data.Parts.Tank, saved = got.Saved and got.Saved.Parts and got.Saved.Parts.Tank }
		end
		return { got = tostring(got) }
	elseif what == "fuse" then -- the step itself, on the server, no click
		local done, why = AquariumService.fuse(player, HttpService:JSONDecode(arg))
		return { done = done, why = why }
	elseif what == "leave" then -- fuses these in the very frame the player is thrown out, and says what the save keeps of it
		local picks = HttpService:JSONDecode(arg)
		local done, why = AquariumService.fuse(player, picks)
		local tank, hands = fishOf(player)
		local answerAt = { done = done, why = why, tank = tank, hands = hands }
		player:Kick("check")
		return answerAt
	elseif what == "gone" then
		return { players = #Players:GetPlayers() }
	end
	return { error = "no such command" }
end
RS:GetAttributeChangedSignal("TFCmd"):Connect(function()
	local cmd = RS:GetAttribute("TFCmd")
	if type(cmd) ~= "string" then return end
	local what, arg = string.match(cmd, "^([^|]*)|([^|]*)|")
	local player = Players:GetPlayers()[1]
	local ok, got = pcall(answer, player, what, arg)
	out.Value = cmd .. "\n" .. HttpService:JSONEncode(if ok then got else { error = tostring(got) })
end)
'''

CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")
local report = RS:WaitForChild("ZZTFReport")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local t0 = os.clock()
local sent = 0
local function log(message, kind)
	if (kind == Enum.MessageType.MessageWarning or kind == Enum.MessageType.MessageError) and sent < 150 then
		sent += 1
		report:FireServer("log", kind.Name .. ": " .. string.sub(message, 1, 300))
	end
end
for _, m in LogService:GetLogHistory() do log(m.message, m.messageType) end
LogService.MessageOut:Connect(log)
local function ev(text)
	report:FireServer("ev", string.format("%.2f|%s", os.clock() - t0, text))
end
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local State = require(Client:WaitForChild("Lib"):WaitForChild("State"))
local CatchShow = require(Client:WaitForChild("UI"):WaitForChild("CatchShow"))
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local fuseModule = Client.UI:FindFirstChild("FusePanel")
local FusePanel = fuseModule and require(fuseModule)

-- what comes back on Ride
Net.Ride.OnClientEvent:Connect(function(what, a)
	if what == "Fused" or what == "FuseDenied" or what == "Respawned" then
		ev("ride|" .. what .. "|" .. (if type(a) == "table" then HttpService:JSONEncode(a) else tostring(a)))
	end
end)
player.CharacterAdded:Connect(function() ev("body") end)

-- the dock's line: when it is up, how see-through, what it says
local up, stage, mode, words, fadeText, great, win = nil, "off", State.Mode, "", "", false, false
local function line()
	local g = gui:FindFirstChild("DockNotes")
	local root = g and g:FindFirstChild("Root")
	for _, n in { "Carry", "Goal" } do
		local f = root and root:FindFirstChild(n)
		if f and f.Visible then
			local best, any = 1, false
			for _, d in f:GetDescendants() do
				if d:IsA("TextLabel") and d.Text ~= "" then
					best = math.min(best, d.TextTransparency)
					any = true
				end
			end
			if any then
				return n, tostring(f:GetAttribute("Words")), best, f
			end
		end
	end
	return nil, "", 1, nil
end
RunService.RenderStepped:Connect(function()
	local n, w, clear, f = line()
	local now = if not n then "off" elseif clear > 0.995 then "off" elseif clear > 0.02 then "fading" else "on"
	if now ~= stage or (now ~= "off" and w ~= words) then
		local at = if f then string.format(" y=%.0f..%.0f x=%.0f..%.0f", f.AbsolutePosition.Y, f.AbsolutePosition.Y + f.AbsoluteSize.Y,
			f.AbsolutePosition.X, f.AbsolutePosition.X + f.AbsoluteSize.X) else ""
		ev(string.format("line|%s|%s|%s|clear=%.2f fade=%.2f last=%s great=%s mode=%s%s", now, tostring(n), w, clear, State.Fade, State.FadeText,
			tostring(CatchShow.showing()), State.Mode, at))
		stage, words = now, w
	end
	if State.Mode ~= mode then
		ev("mode|" .. mode .. ">" .. State.Mode)
		mode = State.Mode
	end
	if State.FadeText ~= fadeText then
		fadeText = State.FadeText
		ev("words|" .. fadeText)
	end
	if CatchShow.showing() ~= great then
		great = CatchShow.showing()
		ev("great|" .. tostring(great))
	end
	local o = FusePanel ~= nil and FusePanel.isOpen()
	if o ~= win then
		win = o
		ev("window|" .. tostring(o))
	end
end)

local function controls(on)
	local ok, module = pcall(function()
		return require(player.PlayerScripts:WaitForChild("PlayerModule", 5)):GetControls()
	end)
	if ok and module then
		if on then module:Enable() else module:Disable() end
	end
end
local function walk(x, z, most)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return "no body" end
	controls(false)
	local from = os.clock()
	local d = Vector3.new(x - root.Position.X, 0, z - root.Position.Z)
	while os.clock() - from < most and d.Magnitude > 1 and root.Parent do
		humanoid:Move(d.Unit)
		RunService.RenderStepped:Wait()
		d = Vector3.new(x - root.Position.X, 0, z - root.Position.Z)
	end
	humanoid:Move(Vector3.zero)
	controls(true)
	return string.format("%.1f s, %.1f left", os.clock() - from, d.Magnitude)
end
local function rect(o)
	return string.format("%.0f,%.0f,%.0f,%.0f", o.AbsolutePosition.X, o.AbsolutePosition.Y, o.AbsoluteSize.X, o.AbsoluteSize.Y)
end
local function seen(o)
	while o and not o:IsA("ScreenGui") do
		if o:IsA("GuiObject") and not o.Visible then return false end
		o = o.Parent
	end
	return o ~= nil and o.Enabled
end
local function texts(g)
	local list = {}
	for _, d in g:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and seen(d) and d.TextTransparency < 0.9 then
			table.insert(list, d.Name .. "=" .. d.Text .. "@" .. rect(d))
		end
	end
	return list
end
local verbs = {}
function verbs.ping() return "pong " .. State.Mode end
function verbs.walk(a)
	local x, z, most = string.match(a, "([^,]+),([^,]+),?(.*)")
	return walk(tonumber(x), tonumber(z), tonumber(most) or 10)
end
function verbs.fire(a) Net.Action:FireServer("Fuse", HttpService:JSONDecode(a)) return "sent" end
function verbs.burst(a) -- the same ask n times in one frame
	local ask = HttpService:JSONDecode(a)
	for _ = 1, ask[1] do Net.Action:FireServer("Fuse", ask[2]) end
	return "sent"
end
function verbs.odd() -- asks that are nothing like one
	for _, x in { 1, "T1", {}, { "T1", "T2" }, { "T1", "T2", "T3", "T4" }, { "T1", "T1", "T2" }, { "x", "y", "z" }, { 1, 2, 3 }, { "T1", "T2", string.rep("9", 60) },
		{ a = "T1", b = "T2", c = "T3" }, true } do
		Net.Action:FireServer("Fuse", x)
		task.wait(0.15)
	end
	Net.Action:FireServer("Fuse")
	return "sent"
end
function verbs.open(a) FusePanel.open(a == "on") return tostring(FusePanel.isOpen()) end
function verbs.press(a)
	local what, i = string.match(a, "(%a+),?(%d*)")
	FusePanel.press(what, tonumber(i))
	return "pressed"
end
function verbs.texts(a)
	local g = gui:FindFirstChild(a)
	return if g then HttpService:JSONEncode(texts(g)) else "none"
end
function verbs.hopwords()
	for _, d in gui:GetDescendants() do
		if d.Name == "LessonWords" and d:IsA("GuiObject") and seen(d) then
			return tostring(d:GetAttribute("Words"))
		end
	end
	return ""
end
function verbs.hop() return tostring(require(Client:WaitForChild("Lib"):WaitForChild("Actions")).jump()) end
function verbs.putin()
	local root = player.Character.HumanoidRootPart
	local plot = workspace.ClaudeBlockout.Dock.Plots[player:GetAttribute("Plot")]
	local water = plot.TankWater.Position
	player.Character:PivotTo(CFrame.new(water.X, root.Position.Y, water.Z + 30))
	task.wait(0.6)
	local caught = State.Caught or {}
	Net.Action:FireServer("Tank", "PutAll")
	return "put " .. #caught
end
function verbs.mouse() return tostring(game:GetService("UserInputService").MouseBehavior) end
function verbs.fps(a)
	local n, from, worst = 0, os.clock(), 0
	local last = from
	while os.clock() - from < (tonumber(a) or 3) do
		RunService.RenderStepped:Wait()
		local now = os.clock()
		worst = math.max(worst, now - last)
		last = now
		n += 1
	end
	return string.format("%.1f a second, worst frame %.0f ms", n / (os.clock() - from), worst * 1000)
end
function verbs.phone(a) -- the window drawn as on a screen this big: its scale as Shop's own rule gives it
	local cam = workspace.CurrentCamera
	return string.format("%d,%d", cam.ViewportSize.X, cam.ViewportSize.Y)
end
function verbs.required()
	local list = {}
	for _, root in { gui, workspace } do
		for _, d in root:GetDescendants() do
			if d.Name == "Required" and d:IsA("Frame") then
				local t = {}
				for _, l in d:GetDescendants() do
					if l:IsA("TextLabel") then
						local s = l:FindFirstChildOfClass("UIStroke")
						table.insert(t, l.Text .. "/" .. l.TextSize .. "/" .. (if s then string.format("%.2f", s.Thickness) else "-"))
					end
				end
				table.insert(list, table.concat(t, " "))
				if #list >= 6 then return table.concat(list, "\n") end
			end
		end
	end
	return table.concat(list, "\n")
end
function verbs.tell(a)
	local hud = {}
	for _, g in gui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			for _, t in texts(g) do
				if string.find(string.lower(t), string.lower(a), 1, true) then table.insert(hud, g.Name .. ":" .. t) end
			end
		end
	end
	return table.concat(hud, "\n")
end
workspace:GetAttributeChangedSignal("TFDo"):Connect(function()
	local stamp = tostring(workspace:GetAttribute("TFDo"))
	local what, arg = string.match(stamp, "^([^|]*)|([^|]*)|")
	if not what then return end
	task.spawn(function()
		local f = verbs[what]
		local ok, got = pcall(f or function() return "no such verb" end, arg)
		report:FireServer(stamp, tostring(got))
	end)
end)
ev("ready|" .. State.Mode)
'''

RESET = r'''
local U = game:GetService("UserInputService")
task.delay(0.2, function()
	U.MouseBehavior = Enum.MouseBehavior.Default
	if workspace.CurrentCamera then workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed end
end)
task.wait(0.6)
return tostring(U.MouseBehavior) .. " " .. tostring(workspace.CurrentCamera.CameraType)
'''


def run(args, timeout=180):
    r = subprocess.run(["node", RUN, *args], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def edit(code):
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(code)
    try:
        return run([f.name])
    finally:
        os.unlink(f.name)


def lua(v):
    return "[==[" + str(v) + "]==]"


def install(remove=False, save=False, lesson=False):
    return edit(f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("{NAME}")
	if old then old:Destroy() end
end
workspace:SetAttribute("TFDo", nil)
game:GetService("ReplicatedStorage"):SetAttribute("TFCmd", nil)
workspace:SetAttribute("SaveOn", {"true" if save else "nil"})
workspace:SetAttribute("LessonTest", {"true" if lesson else "nil"})
if {"true" if remove else "false"} then return "removed" end
local s = Instance.new("Script")
s.Name = "{NAME}"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "{NAME}"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed " .. #s.Source .. " " .. #c.Source
""")


def cmd(what, arg="", wait=8.0):
    """a command to our own server Script; its answer"""
    if not isinstance(arg, str):
        arg = json.dumps(arg)
    stamp = f"{what}|{arg}|{time.time()}"
    out = run(["--ctx", "server", "--code",
               f"local RS = game:GetService('ReplicatedStorage') local o = game:GetService('ServerStorage'):WaitForChild('ZZTFOut', 5) "
               f"if not o then return 'no helper' end RS:SetAttribute('TFCmd', {lua(stamp)}) local t = os.clock() "
               f"repeat task.wait(0.05) until string.sub(o.Value, 1, #{lua(stamp)}) == {lua(stamp)} or os.clock() - t > {wait} return o.Value"])
    at = out.find(stamp + "\n")
    if at < 0:
        raise SystemExit(f"no answer to {what}: {out[-400:]}")
    return json.JSONDecoder().raw_decode(out[at + len(stamp) + 1:])[0]


def do(what, arg="", wait=8.0):
    """a verb on the player's own machine; what it said"""
    if not isinstance(arg, str):
        arg = json.dumps(arg)
    stamp = f"{what}|{arg}|{time.time()}"
    out = run(["--ctx", "server", "--code",
               f"local o = game:GetService('ServerStorage'):WaitForChild('ZZTFSaid', 5) if not o then return 'no helper' end "
               f"workspace:SetAttribute('TFDo', {lua(stamp)}) local t = os.clock() "
               f"repeat task.wait(0.05) until string.sub(o.Value, 1, #{lua(stamp)}) == {lua(stamp)} or os.clock() - t > {wait} return o.Value"])
    at = out.find(stamp + "\n")
    if at < 0:
        return "no answer: " + out[-300:]
    return out[at + len(stamp) + 1:].strip()


def events(since=0):
    got = []
    for row in cmd("events").get("events", [])[since:]:
        p = row.split("|", 2)
        got.append((float(p[0]), p[1], p[2] if len(p) > 2 else ""))
    return got


class Log:
    def __init__(self, name):
        self.lines, self.fails, self.file = [], [], OUT / f"{name}.log"
        self.say(f"{name}, {time.strftime('%Y-%m-%d %H:%M:%S')}")

    def say(self, text):
        self.lines.append(text)
        print(text, flush=True)

    def expect(self, name, ok, detail=""):
        self.say(("ok    " if ok else "FAIL  ") + name + (f"   [{detail}]" if detail != "" else ""))
        if not ok:
            self.fails.append(name)

    def errors(self):
        logs = cmd("logs")
        for side in ("server", "client"):
            bad = [r for r in logs[side] if r.startswith("MessageError")]
            self.expect(f"no errors on the {side}", not bad, " || ".join(bad[:4]))

    def end(self):
        self.say(f"{len(self.fails)} failed" if self.fails else "all good")
        self.file.write_text("\n".join(self.lines) + "\n")
        print(self.file)
        return len(self.fails)


def lines(got):
    """the dock's line, as showings: (seconds it came, seconds it began to fade, seconds it was gone, words, the rest)"""
    out, now = [], None
    for t, kind, rest in got:
        if kind != "line":
            continue
        stage, which, words, more = (rest.split("|") + ["", "", ""])[:4]
        if stage == "off":
            if now:
                now["off"] = t
                out.append(now)
                now = None
        else:
            if not now:
                now = {"on": t, "fade": None, "off": None, "which": which, "words": words, "more": more, "all": [words], "full": None}
            if stage == "on" and now["full"] is None:
                now["full"] = t
            if stage == "fading" and now["full"] is not None and now["fade"] is None:
                now["fade"] = t
            if words not in now["all"]:
                now["all"].append(words)
    if now:
        out.append(now)
    return out


def tell(s):
    f = lambda a, b: "-" if a is None or b is None else f"{b - a:.2f}"  # noqa: E731
    return f"{s['which']} {s['all']} up {f(s['on'], s['off'])} s (to the fade {f(s['on'], s['fade'])}, fade {f(s['fade'], s['off'])}) {s['more']}"


def right(s):
    """as long as Hugo asked: held 2.5 s, half a second to fade"""
    return s["off"] is not None and 2.7 <= s["off"] - s["on"] <= 3.3 and s["fade"] is not None and 2.2 <= s["fade"] - s["on"] <= 2.9


def texts():
    log = Log("texts")
    got = events()
    shown = lines(got)
    log.expect("the first spawn: one line", len(shown) == 1, "; ".join(map(tell, shown)))
    log.expect("held 2.5 s and faded over 0.5 s", len(shown) >= 1 and right(shown[0]), tell(shown[0]) if shown else "")
    # it stays gone on the dock, whatever happens there
    n = len(events())
    cmd("give", [123456, [["Clownfish", "Normal", ""]]])
    time.sleep(1)
    do("walk", "2990,-70,4")
    cmd("hand", [["Clownfish", "Normal", ""]])
    time.sleep(4)
    log.expect("gone on the dock till the next respawn: coins, a fish in the hands, walking bring nothing", not lines(events(n)),
               "; ".join(map(tell, lines(events(n)))))
    # home from a dive
    for what in ("a carried catch", "hands empty"):
        if what == "hands empty":
            cmd("empty")
        else:
            pass
        n = len(events())
        cmd("at", "3000,-8,60")
        time.sleep(3)
        st = cmd("state")["state"]
        cmd("fail") if st != "Dock" else None
        end = time.time() + 25
        while time.time() < end:
            s = cmd("state")
            e = events(n)
            if s["state"] == "Dock" and any(k == "ride" and r.startswith("Respawned") for _, k, r in e) and lines(e) and lines(e)[-1]["off"]:
                break
            time.sleep(0.7)
        time.sleep(4)
        e = events(n)
        shown = lines(e)
        log.say("      " + "; ".join(f"{t:.1f} {k} {r[:60]}" for t, k, r in e if k in ("mode", "words", "great", "ride", "body")))
        log.expect(f"home from a dive ({what}; was {st}): one line, once", len(shown) == 1, "; ".join(map(tell, shown)))
        log.expect("  held and faded as asked, after the black and the end of dive screen",
                   len(shown) == 1 and right(shown[0]) and "great=false" in shown[0]["more"] and "last= " in shown[0]["more"], "")
    # a death on the dock
    n = len(events())
    cmd("kill")
    time.sleep(14)
    e = events(n)
    shown = lines(e)
    log.expect("a death: one line after the new body", len(shown) == 1 and any(k == "body" for _, k, _ in e), "; ".join(map(tell, shown)))
    if shown:
        log.expect("  held and faded as asked", right(shown[0]))
    log.errors()
    return log.end()


def lesson():
    """With LessonTest on before Play: the dock's line through the lesson's steps, and that it can be finished"""
    log = Log("lesson")

    def step(want, most=30):
        end = time.time() + most
        while time.time() < end:
            s = cmd("state")
            if s["attrs"].get("Lesson") == want:
                return True, s
            time.sleep(0.5)
        return False, s

    good, s = step("Dive", 20)
    log.expect("on the dock: the step Dive", good, s["attrs"].get("Lesson"))
    time.sleep(6)
    shown = lines(events())
    log.expect("the first spawn's line: dive in and catch a fish, held and faded", len(shown) == 1 and "DIVE" in shown[0]["words"] and right(shown[0]),
               "; ".join(map(tell, shown)))
    time.sleep(6)
    log.expect("  and gone till the next respawn", len(lines(events())) == 1, "")
    n = len(events())
    cmd("at", "3000,-8,60")
    said = []
    tamed, end = False, time.time() + 60
    while time.time() < end and not tamed:
        s = cmd("state")
        w = do("hopwords")
        if w and (not said or said[-1] != w):
            said.append(w)
        tamed = s["attrs"].get("Lesson") in ("Hop", "Run")
        if s["state"] == "Free":
            do("hop")
        if s["state"] == "Dock" and time.time() - end > -50:
            cmd("at", "3000,-8,60")
        time.sleep(0.3)
    w = do("hopwords")
    said.append(w)
    log.expect("in the water, a first fish theirs: the step Hop", tamed, s["attrs"].get("Lesson"))
    log.expect("  the hop button's words", any("FISH" in x.upper() for x in said), said)
    n = len(events())
    cmd("fail")
    good, s = step("Deposit", 25)
    log.expect("home with the catch: the step Deposit", good, s["attrs"].get("Lesson"))
    time.sleep(12)
    shown = lines(events(n))
    log.expect("  its line once: go to your tank", len(shown) == 1 and "TANK" in shown[0]["words"] and right(shown[0]), "; ".join(map(tell, shown)))
    n = len(events())
    log.say("      " + do("putin"))
    good, s = step("Train", 12)
    log.expect("the catch in the tank: the step Train", good or s["attrs"].get("Lesson") == "Again", s["attrs"].get("Lesson"))
    time.sleep(5)
    log.expect("  no line between two respawns", not lines(events(n)), "; ".join(map(tell, lines(events(n)))))
    cmd("train", "2000")
    good, s = step("Again", 12)
    log.expect("ridden (the Oxygen given): the step Again", good, s["attrs"].get("Lesson"))
    n = len(events())
    cmd("kill")
    time.sleep(14)
    shown = lines(events(n))
    # (Again says nothing while the first Index reward waits: LessonController)
    log.expect("  a respawn then: its line once, or none", len(shown) == 0 or len(shown) == 1 and right(shown[0]), "; ".join(map(tell, shown)))
    cmd("at", "3000,-8,60")
    good, s = step(None, 20)
    log.expect("down again: the lesson is over", good, s["attrs"].get("Lesson"))
    log.errors()
    return log.end()


def pick(state, where, kind, size=None, variant=None, on=None, n=None):
    """the names of the fish like that"""
    out = []
    for f in state["tank" if where == "T" else "hands"]:
        if f["Id"] == kind and (size is None or f["Size"] == size) and (variant is None or f["Variant"] == variant) and (on is None or f.get("On") == on):
            out.append(where + f["Key"])
    return out[:n] if n else out


def ask(picks, wait=0.9):
    """an ask as the window sends it; the answer ("Fused", {...} | "FuseDenied", why | None)"""
    time.sleep(0.6)
    n = len(events())
    do("fire", picks)
    time.sleep(wait)
    for _, k, r in events(n):
        if k == "ride" and r.startswith(("Fused|", "FuseDenied|")):
            what, rest = r.split("|", 1)
            return what, (json.loads(rest) if what == "Fused" else rest)
    return None, None


def total(s):
    return len(s["tank"]) + len(s["hands"])


def fuse():
    log = Log("fuse")
    s = cmd("state")
    ring = s["ring"]
    root = s["root"]
    gap = ((ring[0] - root[0]) ** 2 + (ring[2] - root[2]) ** 2) ** 0.5
    log.say(f"      ring at ({ring[0]:.1f}, {ring[2]:.1f}), {ring[3]:.1f} across; the player at ({root[0]:.1f}, {root[2]:.1f}), {gap:.1f} away")
    log.expect("not open at the spawn", do("open", "x") == "false")
    cmd("empty")
    s = cmd("state")
    log.expect("tank and hands empty to begin with", total(s) == 0, total(s))
    cmd("give", [0, [["Clownfish", "Normal", ""]] * 3 + [["Clownfish", "Tiny", "Gold"], ["Clownfish", "Big", "Rainbow"], ["GreatWhite", "Normal", ""]]
                 + [["Clownfish", "Colossal", ""]]])
    cmd("hand", [["Clownfish", "Normal", ""]])
    s = cmd("state")
    log.say("      tank " + "; ".join(f"{f['Id']} {f['Size']} {f['Variant']}{' ON' if f['On'] else ''}" for f in s["tank"]) + " | hands "
            + "; ".join(f"{f['Id']} {f['Size']}" for f in s["hands"]))
    # the ring
    n = len(events())
    do("walk", f"{ring[0] - 20},{ring[2]},6", 10)
    time.sleep(0.5)
    did = do("walk", f"{ring[0]},{ring[2]},8", 12)
    time.sleep(0.6)
    log.expect("walking onto the ring opens the window", any(k == "window" and r == "true" for _, k, r in events(n)), did)
    words = do("texts", "FusePanel")
    (OUT / "window.json").write_text(words)
    log.say("      " + do("fps", "3", 10) + " with the window open")
    n = len(events())
    do("walk", f"{ring[0] - 16},{ring[2]},6", 10)
    time.sleep(0.5)
    log.expect("walking off closes it", any(k == "window" and r == "false" for _, k, r in events(n)))
    n = len(events())
    cmd("at", f"{ring[0]},{ring[1] + 4},{ring[2]}")
    time.sleep(1.2)
    log.say("      put down on the ring by script: window " + str([r for _, k, r in events(n) if k == "window"]))
    do("walk", f"{ring[0] - 16},{ring[2]},6", 10)
    do("walk", f"{ring[0]},{ring[2]},8", 12)
    time.sleep(0.5)
    log.expect("off and on again: open", do("open", "x") in ("true", "false") and True)
    # refusals
    s = cmd("state")
    off = [p for p in pick(s, "T", "Clownfish", "Normal", on=False)]
    on = pick(s, "T", "Clownfish", on=True)
    hand = pick(s, "H", "Clownfish")
    top = pick(s, "T", "Clownfish", "Colossal")
    shark = pick(s, "T", "GreatWhite")
    log.say(f"      normal stored {off}, equipped {on}, hand {hand}, colossal {top}, shark {shark}")
    stored = pick(s, "T", "Clownfish", on=False)
    three = [p for p in stored + hand if p not in top]
    before = cmd("state")
    if on and len(three) >= 2:
        a = ask([on[0], three[0], three[1]])
        log.expect("equipped in the tank: let through or refused as Config.Fuse.Earning says (0: refused)", a == ("FuseDenied", "Equipped"), a)
    if top and len(three) >= 2:
        f = [x for x in before["tank"] if "T" + x["Key"] == top[0]][0]
        a = ask([top[0], three[0], three[1]])
        log.expect("a Colossal can't grow", a[0] == "FuseDenied" and a[1] in ("Top", "Equipped"), f"{a} on={f['On']}")
    if shark and len(three) >= 2:
        a = ask([shark[0], three[0], three[1]])
        log.expect("two kinds", a[0] == "FuseDenied" and a[1] in ("Kind", "Equipped"), a)
    a = ask([three[0], three[1], "T999999"])
    log.expect("a fish that isn't there", a == ("FuseDenied", "Gone"), a)
    a = ask([three[0], three[0], three[1]])
    log.expect("the same one twice: no answer at all", a == (None, None), a)
    n = len(events())
    do("odd", "", 12)
    time.sleep(0.5)
    odd = [r for _, k, r in events(n) if k == "ride"]
    log.expect("asks that aren't asks: nothing fused", not any(r.startswith("Fused") for r in odd), odd[:4])
    cmd("at", f"{ring[0] - 45},{ring[1] + 4},{ring[2] + 25}")
    a = ask([three[0], three[1], hand[0]] if hand else three[:3])
    log.expect("from far off", a == ("FuseDenied", "Far"), a)
    cmd("at", f"{ring[0]},{ring[1] + 4},{ring[2]}")
    time.sleep(0.5)
    cmd("config", "On=0")
    a = ask(three[:3])
    log.expect("switched off", a == ("FuseDenied", "Off"), a)
    cmd("config", "On=1")
    cmd("config", "Price=1000000000000")
    a = ask(three[:3])
    log.expect("not enough coins", a == ("FuseDenied", "Coins"), a)
    cmd("config", "Price=0")
    after = cmd("state")
    log.expect("after all the refusals nothing has changed", [f for f in after["tank"]] == before["tank"] and after["hands"] == before["hands"] and after["coins"] >= before["coins"])
    # the riding one, and off the dock
    # fusing three
    cmd("empty")
    cmd("give", [0, [["Clownfish", "Colossal", ""]] * 0 + [["BlueWhale", "Normal", ""]] * 12])  # (the best earners fill the equipped places)
    cmd("give", [0, [["Clownfish", "Normal", ""], ["Clownfish", "Big", ""], ["Clownfish", "Normal", "Gold"]]])
    cmd("hand", [["Clownfish", "Normal", "Rainbow"], ["Clownfish", "Giant", ""]])
    s = cmd("state")
    t = [p for p in pick(s, "T", "Clownfish", on=False)]
    h = pick(s, "H", "Clownfish")
    log.say(f"      stored {t} hands {h}; tank {len(s['tank'])} equipped {sum(f['On'] for f in s['tank'])}; attrs "
            + json.dumps({k: v for k, v in s["attrs"].items() if k.startswith("Tank")})[:200])
    log.expect("three stored Clownfish and two in the hands", len(t) == 3 and len(h) == 2, f"{t} {h}")
    if len(t) == 3:
        big = [x for x in s["tank"] if x["Id"] == "Clownfish" and x["Size"] == "Big"][0]
        a = ask(t, 1.4)
        e = cmd("state")
        left = [f for f in e["tank"] if f["Id"] == "Clownfish"]
        log.expect("three of the tank: fused, the biggest (plain) stays a size bigger, the gold one's colour gone with it",
                   a[0] == "Fused" and a[1]["To"] == "Giant" and a[1]["Variant"] == "" and len(left) == 1 and left[0]["Size"] == "Giant"
                   and left[0]["Variant"] == "" and left[0]["Key"] == big["Key"], f"{a} left {left}")
        log.expect("  two fewer in all, the hands as they were", total(e) == total(s) - 2 and e["hands"] == s["hands"], f"{total(s)} to {total(e)}")
        log.say("      tank's numbers " + json.dumps({k: (s["attrs"].get(k), v) for k, v in e["attrs"].items() if k.startswith(("Tank", "Income", "Earn")) and s["attrs"].get(k) != v})[:300])
        # one of the tank, two of the hands
        s = e
        a = ask(["T" + left[0]["Key"], h[0], h[1]], 1.4)
        e = cmd("state")
        left = [f for f in e["tank"] + e["hands"] if f["Id"] == "Clownfish"]
        log.expect("one of the tank and two of the hands: the first of the equally big stays, plain; the rainbow one's colour is not inherited",
                   a[0] == "Fused" and len(left) == 1 and left[0]["Size"] == "Huge" and left[0]["Variant"] == "" and not e["hands"], f"{a} left {left}")
    # a rainbow that stays keeps its colour
    cmd("hand", [["Clownfish", "Normal", ""], ["Clownfish", "Giant", "Rainbow"], ["Clownfish", "Tiny", "Gold"]])
    s = cmd("state")
    a = ask(pick(s, "H", "Clownfish"), 1.4)
    e = cmd("state")
    log.expect("three of the hands: the rainbow one is the biggest, stays rainbow and grows", a[0] == "Fused" and len(e["hands"]) == 1
               and e["hands"][0]["Size"] == "Huge" and e["hands"][0]["Variant"] == "Rainbow", f"{a} {e['hands']}")
    # twice at once
    cmd("empty")
    cmd("hand", [["Clownfish", "Normal", ""]] * 4)
    s = cmd("state")
    h = pick(s, "H", "Clownfish")
    n = len(events())
    time.sleep(0.6)
    do("burst", [5, h[:3]])
    time.sleep(1.2)
    said = [r[:40] for _, k, r in events(n) if k == "ride"]
    e = cmd("state")
    log.expect("the same ask five times in one frame: fused once", len(e["hands"]) == 2 and sum(r.startswith("Fused") for r in said) == 1, f"{said} {len(e['hands'])} in hand")
    # dying and diving with it open
    cmd("hand", [["Clownfish", "Normal", ""]] * 3)
    s = cmd("state")
    h = pick(s, "H", "Clownfish", "Normal")
    cmd("kill")
    a = ask(h[:3], 0.6)
    log.expect("dead: refused", a == ("FuseDenied", "Dead") or a[1] in ("Dead", "Dock"), a)
    time.sleep(9)
    e = cmd("state")
    log.expect("  the fish are still in the hands", len(e["hands"]) == len(s["hands"]), f"{len(s['hands'])} {len(e['hands'])}")
    cmd("at", "3000,-8,60")
    time.sleep(2.5)
    st = cmd("state")["state"]
    a = ask(h[:3], 0.6)
    log.expect(f"in the water ({st}): refused", a == ("FuseDenied", "Dock"), a)
    cmd("home")
    time.sleep(6)
    log.say("      " + do("fps", "3", 10) + " on the dock, window shut")
    log.errors()
    return log.end()


def saved():
    """With `install save` before Play: what the save keeps after a fusing, and what comes back from it"""
    log = Log("saved")
    s = cmd("state")
    ring = s["ring"]
    log.say("      saved parts: " + str({k: v for k, v in s["attrs"].items() if k.startswith("Saved")}))
    log.expect("the tank is kept", s["attrs"].get("SavedTank") is True)
    cmd("empty")
    cmd("give", [5000, [["Clownfish", "Normal", ""], ["Clownfish", "Big", "Gold"]]])
    cmd("hand", [["Clownfish", "Normal", ""], ["Clownfish", "Tiny", "Rainbow"]])
    cmd("at", f"{ring[0]},{ring[1] + 4},{ring[2]}")
    time.sleep(1.5)
    s = cmd("state")
    stored = pick(s, "T", "Clownfish", on=False)
    on = pick(s, "T", "Clownfish", on=True)
    log.say(f"      stored {stored} equipped {on}")
    if on:  # (two best are equipped: fuse the hands' with one more)
        cmd("hand", [["Clownfish", "Normal", ""]])
        s = cmd("state")
    a = ask(pick(s, "H", "Clownfish")[:3], 1.0)
    log.expect("fused", a[0] == "Fused", a)
    time.sleep(1.5)
    e = cmd("state")
    kept = cmd("save")["tank"]
    mine = sorted([f["Id"], f["Size"], f["Variant"]] for f in e["tank"] + e["hands"])
    its = sorted([f["Id"], f["Size"], f["Variant"]] for f in (kept.get("Fish") or []) + (kept.get("Hands") or []))
    log.expect("the save holds just what there is now", mine == its, f"{mine} / {its}")
    got = cmd("save", "reopen", 20)
    time.sleep(3)
    b = cmd("state")
    back = sorted([f["Id"], f["Size"], f["Variant"]] for f in b["tank"] + b["hands"])
    log.expect("closed and opened again: what was kept comes back on top of what is held, the fused one as it is",
               back == sorted(mine + its), f"{got} {back}")
    log.errors()
    return log.end()


def leave():
    """With `install save`: fused in the very frame the player leaves"""
    log = Log("leave")
    cmd("hand", [["Clownfish", "Normal", ""]] * 3)
    s = cmd("state")
    got = cmd("leave", pick(s, "H", "Clownfish")[:3])
    log.say("      " + json.dumps(got)[:400])
    log.expect("fused, two used up, as they left", got.get("done") is not None)
    time.sleep(3)
    logs = cmd("logs")
    bad = [r for r in logs["server"] if r.startswith("MessageError")]
    log.expect("no errors on the server after it", not bad, " || ".join(bad[:4]))
    return log.end()


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else ""
    a = sys.argv[2:]
    if what == "install":
        print(install(save="save" in a, lesson="lesson" in a))
    elif what == "remove":
        print(install(remove=True))
        print("mouse and camera:", edit(RESET).splitlines()[-1:])
    elif what in ("texts", "lesson", "fuse", "saved", "leave"):
        sys.exit(1 if globals()[what]() else 0)
    elif what == "do":
        print(do(a[0], a[1] if len(a) > 1 else ""))
    elif what == "cmd":
        print(json.dumps(cmd(a[0], a[1] if len(a) > 1 else ""), indent=None))
    elif what == "events":
        for e in events(int(a[0]) if a else 0):
            print(*e)
    else:
        print(__doc__)
