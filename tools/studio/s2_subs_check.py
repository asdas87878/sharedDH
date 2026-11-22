"""The nine submarine models in the game (task s2), checked and pictured in a playtest.
    python tools/studio/s2_subs_check.py push               (in Edit: SubModels and SubController into the open place)
    python tools/studio/s2_subs_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/s2_subs_check.py run                (in the playtest: the checks and the stills)
How: the LocalScript opens the stand's shop (SubPanel.toggle), builds all nine subs beside the stand with
SubModels.build (the game's own builder) and reports what each is made of; the server Script buys, equips and picks
through SubService's own test door (ServerStorage.SubTest) and drops the player in the water so a real trip runs.
Log: work/s2/check.log; shots docs/attachments/s2-*.png.
"""
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work/s2"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
RUN = str(Path.home() / "Projects/studio-runner/studio-run.mjs")
OFFSET = (0, 125)  # the game view in the shot (as b1_inventory_check.py)
VIEW = [1985, 1085]
MINE = {
    "src/shared/SubModels.luau": "ReplicatedStorage.Shared.SubModels",
    "src/client/Controllers/SubController.luau": "StarterPlayer.StarterPlayerScripts.Client.Controllers.SubController",
}

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local report = Instance.new("RemoteEvent")
report.Name = "ZZS2Report"
report.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	RS:SetAttribute("S2Client", tostring(text))
end)
RS:GetAttributeChangedSignal("S2Cmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("S2Cmd") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local player = Players:GetPlayers()[1]
	local ok, said = pcall(function()
		local t = SS:WaitForChild("SubTest")
		if verb == "sub" then -- tier, land
			local tier, land = string.match(arg, "(%d+),(%d+)")
			t:Invoke("give", player.UserId, 1e13)
			for _ = 1, 9 do
				t:Invoke("buy", player.UserId)
			end
			t:Invoke("equip", player.UserId, tonumber(tier))
			return t:Invoke("pick", player.UserId, tonumber(land), "")
		elseif verb == "dive" then
			player.Character:PivotTo(CFrame.new(RideService.sandboxStart()))
			return "dived"
		elseif verb == "home" then
			RideService.sendHome(player)
			t:Invoke("equip", player.UserId, 0)
			return t:Invoke("pick", player.UserId, 0, "")
		elseif verb == "st" then
			return string.format("state=%s phase=%s equip=%s", tostring(RideService.stateOf(player)),
				tostring(player:GetAttribute("SubPhase")), tostring(player:GetAttribute("SubEquip")))
		end
		return "?"
	end)
	RS:SetAttribute("S2Said", tostring(said) .. " " .. tostring(ok))
end)
'''

CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local report = RS:WaitForChild("ZZS2Report")
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local SubModels = require(RS:WaitForChild("Shared"):WaitForChild("SubModels"))
local SubPanel = require(Client:WaitForChild("UI"):WaitForChild("SubPanel"))
local line = nil
local function stand()
	local dock = workspace:FindFirstChild("Dock", true)
	local stations = dock and dock:FindFirstChild("Stations")
	local sub = stations and stations:FindFirstChild("Sub")
	return sub and sub:GetPivot().Position
end
workspace:GetAttributeChangedSignal("S2Do"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("S2Do") or "")
	local verb, arg = string.match(cmd, "^(%w+)|?([^|]*)")
	local ok, said = pcall(function()
		if verb == "shop" then
			SubPanel.toggle(arg == "on")
			return "shop " .. arg
		elseif verb == "line" then
			-- all nine beside the stand, three rows of three, turned three-quarters to the camera
			if line then line:Destroy() end
			line = Instance.new("Folder")
			line.Name = "S2Line"
			line.Parent = workspace
			local at = stand() or Vector3.new(0, 20, 0)
			local out = {}
			local only = tonumber(arg)
			if only == 0 then only = nil end
			for n = 1, 9 do
				if not only or only == n then
					local model, parts, prop = SubModels.build(n)
					local col, row = (n - 1) % 3, (n - 1) // 3
					local where = if only then CFrame.new(at + Vector3.new(0, 30, 0))
						else CFrame.new(at + Vector3.new((col - 1) * 58, 34 + (1 - row) * 30, 0))
					local turn = where * CFrame.Angles(0, math.rad(-125), 0)
					local neon, meshes = 0, 0
					for _, p in parts do
						p.CFrame = turn * p.CFrame
						if p.Material == Enum.Material.Neon then neon += 1 end
						if p:IsA("MeshPart") then meshes += 1 end
					end
					model.Parent = line
					table.insert(out, string.format("%d:%s parts=%d mesh=%d neon=%d prop=%s seat=%s", n, SubModels.style(n).Id,
						#parts, meshes, neon, prop.Name, tostring(model:FindFirstChild("Seat") ~= nil)))
				end
			end
			local cam = workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Scriptable
			local mid = at + Vector3.new(0, if only then 31 else 34, 0)
			cam.CFrame = CFrame.lookAt(mid + (if only then Vector3.new(-30, 14, -52) else Vector3.new(-40, 22, -175)), mid)
			cam.FieldOfView = 50
			return table.concat(out, "; ")
		elseif verb == "unline" then
			if line then line:Destroy() line = nil end
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			workspace.CurrentCamera.FieldOfView = 70
			return "unlined"
		elseif verb == "mine" then
			-- the sub of our own trip, as SubController built it: how its parts sit against the hull
			local found = nil
			for _, m in workspace.CurrentCamera:GetChildren() do
				if m.Name == "Submarine" and m:GetAttribute("For") == player.UserId then found = m end
			end
			if not found then return "no sub" end
			local hull, seat, prop = found.PrimaryPart, found:FindFirstChild("Seat"), found:FindFirstChild("Prop")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local s = hull.CFrame:ToObjectSpace(seat.CFrame).Position
			local p = hull.CFrame:ToObjectSpace(prop.CFrame).Position
			local r = root and seat.CFrame:ToObjectSpace(root.CFrame).Position or Vector3.zero
			local look = hull.CFrame.LookVector
			local move = root and root.AssemblyLinearVelocity or Vector3.zero
			return string.format("tier=%s mesh=%s seatFromHull=%.1f,%.1f,%.1f propFromHull=%.1f,%.1f,%.1f riderFromSeat=%.1f,%.1f,%.1f noseDotMove=%.2f",
				tostring(found:GetAttribute("Tier")), tostring(hull:IsA("MeshPart")), s.X, s.Y, s.Z, p.X, p.Y, p.Z, r.X, r.Y, r.Z,
				if move.Magnitude > 1 then look:Dot(move.Unit) else 0)
		end
		return "?"
	end)
	report:FireServer(tostring(said) .. " " .. tostring(ok))
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


def job(source):
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(source)
    return run([f.name])


def push():
    out = Path(tempfile.gettempdir()) / "s2_push.luau"
    pairs = [f"{k}={v}" for k, v in MINE.items()]
    subprocess.run([sys.executable, str(ROOT / "tools/studio/push_scripts.py"), str(ROOT), str(out), *pairs], check=True)
    return run([str(out)])


def install(remove=False):
    return job(f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZS2Check")
	if old then old:Destroy() end
end
workspace:SetAttribute("S2Do", nil)
if {lua(remove)} then
	return "removed"
end
local s = Instance.new("Script")
s.Name = "ZZS2Check"
s.Source = {lua(SERVER)}
s.Parent = sss
local c = Instance.new("LocalScript")
c.Name = "ZZS2Check"
c.Source = {lua(CLIENT)}
c.Parent = sps
return "installed"
""")


def cmd(c, wait=0.8):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('S2Cmd', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('S2Said')"
    )


def do(c, wait=1.4):
    return server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('S2Client', '') "
        f"workspace:SetAttribute('S2Do', {lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('S2Client')"
    )


def shot(name):
    path = OUT / (name + "-full.png")
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
    im = im.crop((OFFSET[0], OFFSET[1], OFFSET[0] + VIEW[0], OFFSET[1] + VIEW[1]))
    im.save(ATTACH / f"s2-{name}.png")
    return ATTACH / f"s2-{name}.png"


LOG = []


def note(text):
    print(text, flush=True)
    LOG.append(text)


def checks():
    time.sleep(6)
    said = do("line|0", 3)
    note("line: " + said)
    time.sleep(1.5)
    note("shot: %s" % shot("stand-all-nine"))
    for n in (1, 6, 9):
        note("one: " + do(f"line|{n}", 2))
        time.sleep(1)
        note("shot: %s" % shot(f"sub-{n}"))
    note(do("unline", 1))
    note(do("shop|on", 2.5))
    note("shot: %s" % shot("stand-shop"))
    note(do("shop|off", 1))
    for tier, land in ((1, 2), (9, 3)):
        note(f"sub {tier}: " + cmd(f"sub|{tier},{land}", 1.5))
        note("dive: " + cmd("dive", 1))
        for i in range(14):
            time.sleep(1.5)
            st = cmd("st", 0.3)
            mine = do("mine", 0.6)
            note(f"  t+{(i + 1) * 2.4:.0f}s {st} | {mine}")
            if "phase=Ride" in st and "tier=" in mine and not (OUT / f"rode{tier}").exists():
                (OUT / f"rode{tier}").write_text("1")
                time.sleep(1.2)
                note("shot: %s" % shot(f"ride-tier{tier}"))
                note("  " + do("mine", 0.6))
                break
        (OUT / f"rode{tier}").unlink(missing_ok=True)
        note("home: " + cmd("home", 3))
    (OUT / "check.log").write_text("\n".join(LOG) + "\n")


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "push":
        print(push())
    elif what == "install":
        print(install())
    elif what == "remove":
        print(install(True))
    elif what == "run":
        checks()
