"""The three picks of 2026-11-24 in a playtest, by numbers: the twelve aura pictures, the shop's turning propellers, and
each sub's name sign and blur disc as built. It opens two shop windows and touches no camera.
    python tools/studio/s2_subs_check.py install ; python tools/studio/picks_check.py install      (in Edit, before Play)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/picks_check.py run                                                        (in the playtest)
    python tools/studio/picks_check.py remove ; python tools/studio/s2_subs_check.py remove        (in Edit, after)
The trips (the turn's rule, the disc on a run) are t3_toy_subs_check's `run numbers`. Log: work/picks/check.log.
"""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import s2_subs_check as s2  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "work/picks"
OUT.mkdir(parents=True, exist_ok=True)

CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local report = RS:WaitForChild("ZZS2Report")
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local SubModels = require(RS:WaitForChild("Shared"):WaitForChild("SubModels"))
local Shop = require(Client:WaitForChild("UI"):WaitForChild("Shop"))
local gui = player:WaitForChild("PlayerGui")
local verbs = {}
function verbs.auras()
	Shop.go("Auras")
	task.wait(3)
	local n, loaded, cells, shown = 0, 0, {}, 0
	for _, d in gui:GetDescendants() do
		if d:IsA("ImageLabel") and string.find(d.Image, "aura_icons", 1, true) then
			n += 1
			if d.IsLoaded then loaded += 1 end
			cells[tostring(d.ImageRectOffset)] = true
			local up, all = d, true
			while up and up:IsA("GuiObject") do
				if not up.Visible then all = false end
				up = up.Parent
			end
			if all then shown += 1 end
		end
	end
	local different = 0
	for _ in cells do different += 1 end
	Shop.go(nil)
	return string.format("pictures=%d loaded=%d cells=%d shownWhileOpen=%d", n, loaded, different, shown)
end
function verbs.cards()
	Shop.go("Sub")
	task.wait(2)
	local last, turned, seen = {}, {}, 0
	local stop = os.clock() + 2
	local began = os.clock()
	local blurs, blurShown = 0, 0
	while os.clock() < stop do
		RunService.RenderStepped:Wait()
		for _, d in gui:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "Prop" or d.Name == "Prop_Glow") then
				local f = d.CFrame
				if last[d] then
					local rel = last[d]:ToObjectSpace(f)
					turned[d] = (turned[d] or 0) + math.atan2(rel.RightVector.Y, rel.RightVector.X)
				end
				last[d] = f
			end
		end
	end
	local took = os.clock() - began
	local out, all, still = {}, 0, 0
	for d in last do
		all += 1
		if d.Name == "Prop" then
			local rate = (turned[d] or 0) / took
			if math.abs(rate) < 0.01 then still += 1 else table.insert(out, string.format("%.2f", rate)) end
		end
	end
	for _, d in gui:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Blur" then
			blurs += 1
			if d.Transparency < 1 then blurShown += 1 end
		end
	end
	Shop.go(nil)
	task.wait(0.5)
	local a = {}
	for d in last do a[d] = d.CFrame end
	task.wait(0.5)
	local after = 0
	for d, f in a do if d.CFrame ~= f then after += 1 end end
	return string.format("props=%d turning(rad/s)=%s still=%d turningAfterClose=%d discs=%d discsShown=%d", all, table.concat(out, ","), still, after, blurs, blurShown)
end
function verbs.signs()
	local out = {}
	for n = 1, 9 do
		local model, parts, prop = SubModels.build(n)
		local sign = model:FindFirstChild("Label", true)
		local word, drop, shine = sign:FindFirstChild("Word"), sign:FindFirstChild("Drop"), sign:FindFirstChild("Shine")
		local ink = word:FindFirstChildOfClass("UIStroke")
		local blur = model:FindFirstChild("Blur")
		table.insert(out, string.format("%d %s word=%s line=%.2f edge=%.3f/%s drop=%s shine=%s clips=%s blur=%s rot across=%.2f (prop %.2f) inParts=%s tr=%.2f",
			n, SubModels.style(n).Id, word.Text, word.Size.Y.Scale * sign.Size.Y.Scale, ink.Thickness, ink.StrokeSizingMode.Name,
			tostring(drop ~= nil), tostring(shine ~= nil), tostring(sign.ClipsDescendants), tostring(blur ~= nil), blur.Size.Y,
			math.max(prop.Size.X, prop.Size.Y), tostring(table.find(parts, blur) ~= nil), blur.Transparency))
		model:Destroy()
	end
	return table.concat(out, "\n")
end
workspace:GetAttributeChangedSignal("PicksDo"):Connect(function()
	local verb = string.match(tostring(workspace:GetAttribute("PicksDo") or ""), "^(%w+)")
	if not verb then return end
	local ok, said = pcall(verbs[verb])
	report:FireServer(tostring(said) .. " " .. tostring(ok))
end)
'''


def install(remove=False):
    return s2.job(f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZPicksCheck")
if old then old:Destroy() end
workspace:SetAttribute("PicksDo", nil)
if {s2.lua(remove)} then return "removed" end
local c = Instance.new("LocalScript")
c.Name = "ZZPicksCheck"
c.Source = {s2.lua(CLIENT)}
c.Parent = sps
return "installed " .. #c.Source
""")


def do(c, wait):
    return s2.server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('S2Client', '') "
        f"workspace:SetAttribute('PicksDo', {s2.lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('S2Client')")


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(True))
    elif what == "run":
        time.sleep(4)
        lines = [f"{v}: " + do(v, w) for v, w in (("signs", 2), ("auras", 5), ("cards", 7))]
        print("\n".join(lines))
        with open(OUT / "check.log", "a", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
