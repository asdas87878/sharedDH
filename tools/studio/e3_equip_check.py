"""Number keys, Q equip and the ride fish (task e3, docs/design/equip.md): checked and pictured in a Studio playtest.
    python tools/studio/e3_equip_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/e3_equip_check.py run                (in the playtest: the checks and the stills)
How: the server Script puts fish in the player's hands (RideService.giveCarried) and reports the server's side (the
player's attributes, Workspace.LandFish and Workspace.HeldFish, the humanoid, the hands). The LocalScript presses keys
through the game's own path (Client.Controllers.EquipController.press: what a real key press does after its
processed / text box gate) and fires the equipped slot's asks as its button does ("RideMount", "RideUnequip"), plus
raw asks a cheat could send. Each step reports back through ReplicatedStorage. Log: work/e3/check.log; hotbar shots
docs/attachments/e3-hotbar-*.png, the land ride docs/attachments/e3-land-*.png.
Needs Studio open with the studio-runner plugin and Rojo serving this repo.
"""
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/e3"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
# the game view in the shot (as hold_check.py: the game view from the left edge, the Explorer right)
OFFSET = (0, 125)
VIEW = [1985, 1085]
SHOT = (2400, 1280)

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZE3Report"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("E3Client", tostring(text))
end)
local function ridden(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, d in workspace:GetDescendants() do
		if d:IsA("Weld") and d.Name == "RideWeld" and d.Part1 == root then
			local m = d.Parent and d.Parent:FindFirstAncestorOfClass("Model")
			if m then
				return string.format("%s/%s/%s", tostring(m:GetAttribute("FishType")), tostring(m:GetAttribute("SizeTier")), tostring(m:GetAttribute("Variant")))
			end
		end
	end
	return "none"
end
RS:GetAttributeChangedSignal("E3Cmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("E3Cmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local ok, said = pcall(function()
		if verb == "setup" then
			local spec = game:GetService("HttpService"):JSONDecode(arg)
			for _, f in spec do
				RideService.giveCarried(player, { Id = f[1], Size = f[2], Variant = f[3] })
			end
			return "hands " .. #RideService.carried(player)
		elseif verb == "clear" then
			while #RideService.carried(player) > 0 do
				RideService.takeCarried(player, 1)
			end
			return "hands 0"
		elseif verb == "stand" then
			local spawn = workspace.ClaudeBlockout.Dock.DockSpawn
			local yaw = tonumber(arg) or 0
			player.Character:PivotTo(CFrame.new(spawn.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.rad(yaw), 0))
			return "stood"
		elseif verb == "state" then
			local hands = {}
			for _, c in RideService.carried(player) do
				table.insert(hands, c.Id .. "/" .. c.Size .. "/" .. c.Variant)
			end
			local landF = workspace:FindFirstChild("LandFish")
			local lands = if landF then #landF:GetChildren() else 0
			local land = landF and landF:FindFirstChildWhichIsA("Model")
			local heldF = workspace:FindFirstChild("HeldFish")
			local helds = if heldF then #heldF:GetChildren() else 0
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local gap = "n/a"
			if land then
				-- the land fish's belly against the floor under it
				local cf, size = land:GetBoundingBox()
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { player.Character, landF }
				local hit = workspace:Raycast(cf.Position, Vector3.new(0, -60, 0), params)
				if hit then
					gap = string.format("%.2f", (cf.Position.Y - size.Y / 2) - hit.Position.Y)
				end
			end
			local eq = RideService.equippedOf(player)
			return string.format(
				"state=%s held=%s heldIdx=%s eq=%s/%s/%s eqIdx=%s mounted=%s eqOf=%s landModels=%d land=%s/%s/%s gap=%s heldModels=%d hip=%.2f walk=%s hands=[%s] ridden=%s",
				tostring(RideService.stateOf(player)), tostring(player:GetAttribute("HeldFish")),
				tostring(player:GetAttribute("HeldIndex")), tostring(player:GetAttribute("EquippedFish")),
				tostring(player:GetAttribute("EquippedSize")), tostring(player:GetAttribute("EquippedVariant")),
				tostring(player:GetAttribute("EquippedIndex")), tostring(player:GetAttribute("LandMounted")),
				if eq then eq.Id else "nil", lands,
				tostring(land and land:GetAttribute("FishType")), tostring(land and land:GetAttribute("SizeTier")),
				tostring(land and land:GetAttribute("Variant")), gap, helds,
				if hum then hum.HipHeight else -1, tostring(hum and hum.WalkSpeed), table.concat(hands, ","), ridden(player))
		elseif verb == "take" then
			RideService.takeCarried(player, tonumber(arg) or 1)
			return "took " .. arg
		elseif verb == "respawn" then
			player:LoadCharacter()
			return "respawned"
		elseif verb == "dive" then
			-- into the water at the lane's start, as walking off the dock does (RideService's dock tick)
			local at = RideService.sandboxStart()
			player.Character:PivotTo(CFrame.new(at))
			return "dived"
		elseif verb == "home" then
			RideService.sendHome(player)
			return "home"
		elseif verb == "sub" then
			local t = SS:WaitForChild("SubTest")
			t:Invoke("buy", player.UserId)
			t:Invoke("equip", player.UserId, 1)
			return t:Invoke("pick", player.UserId, tonumber(arg) or 2, "")
		elseif verb == "subOff" then
			local t = SS:WaitForChild("SubTest")
			t:Invoke("equip", player.UserId, 0)
			return t:Invoke("pick", player.UserId, 0, "")
		elseif verb == "trainer" then
			player:SetAttribute("TrainerRide", if arg == "on" then "Test" else nil)
			return "trainer " .. arg
		end
		return "?"
	end)
	RS:SetAttribute("E3Said", tostring(said) .. " " .. tostring(ok))
end)
'''

CLIENT = r'''
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local EquipController = require(Client:WaitForChild("Controllers"):WaitForChild("EquipController"))
local report = RS:WaitForChild("ZZE3Report", 60)
local denied = ""
Net.Ride.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Denied" and (a == "Equip" or a == "Hold") then
		denied = tostring(a) .. ":" .. tostring(b)
	end
end)
local function ui()
	local gui = player.PlayerGui:FindFirstChild("Slots", true)
	if not gui then
		return "no slots"
	end
	local eq = gui:FindFirstChild("Equipped", true)
	local hint = gui:FindFirstChild("Hint")
	local q = eq and eq:FindFirstChild("QKey", true)
	local cross = eq and eq:FindFirstChild("Unequip", true)
	local keys = {}
	for _, d in gui:GetDescendants() do
		if d.Name == "Key" and d:IsA("TextLabel") and d.Visible then
			table.insert(keys, d.Text)
		end
	end
	table.sort(keys)
	local firstX = math.huge
	local eqX = if eq then eq.AbsolutePosition.X else -1
	for _, d in gui:GetChildren() do
		if d:IsA("GuiObject") and d ~= eq and d.Name ~= "Hint" and d.AbsoluteSize.X > 30 then
			firstX = math.min(firstX, d.AbsolutePosition.X)
		end
	end
	return string.format("hint=%q q=%s cross=%s keys=%s eqLeftOfAll=%s eqVisible=%s",
		hint and hint.Text or "?", tostring(q and q.Visible), tostring(cross and cross.Visible),
		table.concat(keys, ""), tostring(eqX < firstX), tostring(eq and eq.Visible))
end
workspace:GetAttributeChangedSignal("E3Do"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("E3Do") or "")
	local verb, a, b, c = string.match(cmd, "^(%w+)|?([^|]*)|?([^|]*)|?([^|]*)")
	local said = ""
	denied = ""
	if verb == "key" then
		EquipController.press(Enum.KeyCode[a])
		task.wait(0.7)
	elseif verb == "raw" then
		-- a raw ask, as a cheat could send it
		local args = {}
		for _, x in { b, c } do
			if x ~= "" then
				table.insert(args, tonumber(x) or x)
			end
		end
		Net.Action:FireServer(a, table.unpack(args))
		task.wait(0.7)
	elseif verb == "ui" then
		said = ui()
	end
	report:FireServer(said .. " denied=" .. denied .. " @" .. cmd)
end)
workspace:GetAttributeChangedSignal("E3View"):Connect(function()
	local view = workspace:GetAttribute("E3View")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if type(view) ~= "string" or view == "" or not root then
		player.CameraMaxZoomDistance = 128
		player.CameraMinZoomDistance = 0.5
		return
	end
	local dist = tonumber(workspace:GetAttribute("E3Dist")) or 16
	player.CameraMinZoomDistance = dist
	player.CameraMaxZoomDistance = dist
	local look = workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		return
	end
	look = look.Unit
	local face = if view == "side" then Vector3.new(look.Z, 0, -look.X) else -look
	local at = root.Position
	character:PivotTo(CFrame.lookAt(at, at + face))
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
	local old = at:FindFirstChild("ZZE3Check")
	if old then old:Destroy() end
end
for _, k in {{ "E3Do", "E3View", "E3Dist" }} do
	workspace:SetAttribute(k, nil)
end
if {lua(remove)} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZE3Check"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZE3Check"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
"""
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(job)
    return run([f.name])


def cmd(c, wait=0.8):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('E3Cmd', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('E3Said')"
    )


def do(c, wait=1.4):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('E3Client', '') "
        f"workspace:SetAttribute('E3Do', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('E3Client')"
    )


def setw(**kw):
    code = ""
    for k, v in kw.items():
        code += f"workspace:SetAttribute({lua(k)}, {lua(v)}) "
    return server(code + "return 'ok'")


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
    im = Image.open(path).convert("RGB")
    return im


def hotbar(name):
    im = shot(OUT / f"raw_hotbar_{name}.png")
    cx = OFFSET[0] + VIEW[0] // 2
    bottom = OFFSET[1] + VIEW[1]
    crop = im.crop((cx - 560, bottom - 190, cx + 560, bottom))
    crop.save(ATTACH / f"e3-hotbar-{name}.png")
    im.close()


def scene(name):
    im = shot(OUT / f"raw_scene_{name}.png")
    crop = im.crop((OFFSET[0], OFFSET[1], OFFSET[0] + VIEW[0], OFFSET[1] + VIEW[1])).resize((1280, 700))
    crop.save(ATTACH / f"e3-land-{name}.png")
    im.close()


RESULTS = []


def field(state, key):
    for part in state.split(" "):
        if part.startswith(key + "="):
            return part[len(key) + 1 :]
    return None


def check():
    log = []

    def note(text):
        print(text)
        log.append(text)

    def expect(name, ok, detail=""):
        RESULTS.append((name, ok))
        note(("PASS " if ok else "FAIL ") + name + (("  [" + detail + "]") if detail else ""))

    def st():
        s = cmd("state")
        note("    " + s)
        return s

    note("clear: " + cmd("clear"))
    note("stand: " + cmd("stand|180", 1.2))
    s = st()
    note("ui: " + do("ui"))
    hotbar("empty")
    u = do("ui")
    expect("empty equipped slot shows the hint, Q cap, no cross", 'HOLD A FISH, THEN Q' in u and "q=true" in u and "cross=false" in u, u)
    expect("equipped slot is left of every numbered slot", "eqLeftOfAll=true" in u, u)
    expect("keys 1-9 labelled", "keys=123456789" in u, u)

    hands = [["Clownfish", "Normal", ""], ["Clownfish", "Normal", ""], ["ReefShark", "Colossal", "Gold"], ["Pufferfish", "Big", "Silver"]]
    note("setup: " + cmd("setup|" + json.dumps(hands), 1.2))
    # 1. number keys
    do("key|One")
    s = st()
    expect("key 1 holds the first catch", field(s, "held") == "Clownfish" and field(s, "heldIdx") == "1", s)
    do("key|One")
    s = st()
    expect("key 1 again puts it away", field(s, "held") == "nil", s)
    do("key|Four")
    s = st()
    expect("key 4 holds the fourth (Pufferfish)", field(s, "held") == "Pufferfish" and field(s, "heldIdx") == "4", s)
    do("key|Eight")
    s = st()
    expect("key 8 (an empty slot) puts it away", field(s, "held") == "nil", s)
    do("key|KeypadThree")
    s = st()
    expect("keypad 3 holds the third (Reef Shark)", field(s, "held") == "ReefShark", s)
    hotbar("holding")
    expect("holding alone equips nothing", field(s, "eq") == "nil/nil/nil", s)

    # 2. Q equips the held fish and rides it on land
    do("key|Q")
    time.sleep(0.5)
    s = st()
    expect(
        "Q equips the held Colossal Gold Reef Shark and rides it",
        field(s, "eq") == "ReefShark/Colossal/Gold" and field(s, "mounted") == "true" and field(s, "landModels") == "1"
        and field(s, "land") == "ReefShark/Colossal/Gold",
        s,
    )
    expect("no overhead copy remains", field(s, "held") == "nil" and field(s, "heldModels") == "0", s)
    expect("hands unchanged (an alias, not a copy)", field(s, "hands").count("/") == 8, s)
    gap = field(s, "gap")
    expect("the Colossal land fish stands near the floor (gap at most 1 stud)", gap not in (None, "n/a") and abs(float(gap)) <= 1.01, s)
    expect("walk speed is Equip.LandSpeed (32)", field(s, "walk") == "32", s)
    u = do("ui")
    expect("equipped slot shows RIDING with the cross", '"RIDING"' in u and "cross=true" in u, u)
    hotbar("equipped")
    setw(E3View="side", E3Dist=90)
    time.sleep(1.5)
    scene("colossal-side")
    setw(E3View="")

    # hold B without Q: the ride stays A
    do("key|One")
    s = st()
    expect("holding another fish keeps the equipped one, off the land fish", field(s, "eq") == "ReefShark/Colossal/Gold" and field(s, "mounted") == "nil" and field(s, "held") == "Clownfish" and field(s, "landModels") == "0", s)
    hip_free = field(s, "hip")
    # Q on B replaces
    do("key|Two")
    do("key|Q")
    s = st()
    expect("Q on the second Clownfish replaces the equipped fish", field(s, "eq") == "Clownfish/Normal/" and field(s, "eqIdx") == "2" and field(s, "mounted") == "true", s)
    gap = field(s, "gap")
    expect("the Clownfish stands on the floor (gap under 1 stud)", gap not in (None, "n/a") and abs(float(gap)) < 1.0, s)
    for view in ("side", "front"):
        setw(E3View=view, E3Dist=18)
        time.sleep(1.5)
        scene("clownfish-" + view)
    setw(E3View="")

    # 3. duplicates: the second of two identical catches is equipped; take the first, it survives at index 1
    note("take 1: " + cmd("take|1"))
    s = st()
    expect("taking the other twin keeps the equipped one, now at 1", field(s, "eq") == "Clownfish/Normal/" and field(s, "eqIdx") == "1" and field(s, "mounted") == "true", s)
    note("take 1 (the equipped one): " + cmd("take|1"))
    time.sleep(0.3)
    s = st()
    expect("taking the equipped one clears it and its land fish", field(s, "eq") == "nil/nil/nil" and field(s, "landModels") == "0" and field(s, "mounted") == "nil", s)
    expect("hip height back to on foot", field(s, "hip") == hip_free, s)

    # stale and malicious asks
    note("hands: " + field(s, "hands"))
    r = do("raw|RideEquip")
    s2 = st()
    expect("Q with nothing held or equipped is refused, nothing changes", "Equip:None" in r and field(s2, "eq") == "nil/nil/nil", r)
    r = do("raw|Hold|9|ReefShark")
    s2 = st()
    expect("a hold of a stale index is refused", field(s2, "held") == "nil" and "Hold:Gone" in r, r)
    r = do("raw|Hold|1|Kraken")
    s2 = st()
    expect("a hold with the wrong id is refused", field(s2, "held") == "nil", r)
    do("raw|RideEquip|1|Kraken")
    s2 = st()
    expect("RideEquip ignores what the client says (nothing held: nothing)", field(s2, "eq") == "nil/nil/nil", s2)

    # mount toggle, unequip, trainer, reset
    do("key|One")  # the Reef Shark (now first)
    do("key|Q")
    s = st()
    expect("re-equip the Reef Shark", field(s, "eq") == "ReefShark/Colossal/Gold" and field(s, "mounted") == "true", s)
    do("raw|RideMount")
    s = st()
    expect("the slot's press gets off (still equipped)", field(s, "mounted") == "nil" and field(s, "eq") == "ReefShark/Colossal/Gold" and field(s, "landModels") == "0", s)
    u = do("ui")
    expect("the slot then says CLICK TO RIDE", '"CLICK TO RIDE"' in u, u)
    do("raw|RideMount")
    s = st()
    expect("the slot's press gets back on", field(s, "mounted") == "true" and field(s, "landModels") == "1", s)
    do("key|Q")
    s = st()
    expect("Q with nothing held while riding changes nothing", field(s, "mounted") == "true" and field(s, "landModels") == "1", s)
    note(cmd("trainer|on"))
    time.sleep(0.4)
    s = st()
    expect("seated on the trainer: off the land fish", field(s, "mounted") == "nil" and field(s, "landModels") == "0", s)
    r = do("raw|RideMount")
    s = st()
    expect("no mounting while trainer-seated", "Equip:Busy" in r and field(s, "mounted") == "nil", r)
    note(cmd("trainer|off"))
    do("raw|RideUnequip")
    s = st()
    expect("the cross unequips", field(s, "eq") == "nil/nil/nil", s)
    do("key|One")
    do("key|Q")
    s = st()
    note("respawn: " + cmd("respawn", 4))
    s = st()
    expect("a respawn clears equipment, mount and hold", field(s, "eq") == "nil/nil/nil" and field(s, "landModels") == "0" and field(s, "held") == "nil" and field(s, "mounted") == "nil", s)

    # 5. dive with the equipped fish, the held one can't override (a big max Oxygen, so the giant isn't too strong and
    # the ride lasts long enough to be read)
    setw(TestMaxOxygen=1000000)
    note("stand: " + cmd("stand|180", 1.2))
    do("key|One")  # Reef Shark
    do("key|Q")
    do("key|Two")  # Pufferfish held, Reef Shark equipped
    s = st()
    count_before = field(s, "hands")
    note("dive: " + cmd("dive", 3))
    s = st()
    expect("dive in rides the EQUIPPED Colossal Gold Reef Shark, not the held Pufferfish", field(s, "ridden") == "ReefShark/Colossal/Gold" and field(s, "state") == "Riding", s)
    expect("no land fish in the water", field(s, "landModels") == "0", s)
    expect("hands unchanged by the ride", field(s, "hands") == count_before, s)
    note("home: " + cmd("home", 2))
    s = st()
    expect("back on the dock the equipment persists (not mounted)", field(s, "eq") == "ReefShark/Colossal/Gold" and field(s, "mounted") == "nil" and field(s, "state") == "Dock", s)

    # no equipment: a dive in with only a held fish rides nothing (Free)
    do("raw|RideUnequip")
    do("key|One")
    note("dive (held only): " + cmd("dive", 3))
    s = st()
    expect("a merely held fish no longer supplies a dive-in ride", field(s, "ridden") == "none" and field(s, "state") == "Free", s)
    note("home: " + cmd("home", 2))

    # the sub to land 2 with the equipped fish
    note("stand: " + cmd("stand|180", 1.2))
    do("key|Eight")  # (nothing held)
    do("key|One")
    do("key|Q")
    s = st()
    expect("equipped again for the sub", field(s, "eq") == "ReefShark/Colossal/Gold", s)
    note("sub: " + cmd("sub|2", 1.5))
    note("dive (sub): " + cmd("dive", 2))
    s = st()
    note("  carried: " + str(field(s, "state")))
    ridden = "none"
    for _ in range(30):
        time.sleep(1.5)
        s = cmd("state")
        ridden = field(s, "ridden")
        if ridden != "none" or field(s, "state") not in ("Carried",):
            break
    note("    " + s)
    expect("the sub to land 2 drops the rider on the equipped Colossal Gold Reef Shark", ridden == "ReefShark/Colossal/Gold", s)
    note("home: " + cmd("home", 2))
    note("subOff: " + cmd("subOff", 1))
    setw(TestMaxOxygen=None)

    passed = sum(1 for _, ok in RESULTS if ok)
    note(f"\n{passed}/{len(RESULTS)} PASS")
    (OUT / "check.log").write_text("\n".join(log) + "\n")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "run"
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
    else:
        check()
