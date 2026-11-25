"""What the user changed in the map BY HAND in their place, put into the open place (docs/Handoff.md, 2026-11-25).

The generator does not know of these, so a place built from the repo lacks them and a full map load wipes them:
  art/place/HandProps.rbxm   9 early-land props moved, 5 copied (the copies have their original's name)
  the Fuse station           moved 20.4 studs along the dock
  the Index station          taken away
  one seabed tile            recoloured (land 2)

usage: python tools/studio/hand_map.py [runner|<studio_id>] [--check]
  Studio in Edit. Safe to run again: what already stands right is left. What it takes out is kept in
  ServerStorage.HandMapBackup. A station somebody else has moved by hand is left, and said. Not saved: Ctrl+S after.
  --check  only says what would change
load_greybox.py runs it at the end of a full load."""
import base64
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

LUAU = r"""
local CHECK = __CHECK__
local DATA = "__DATA__"
if game:GetService("RunService"):IsRunning() then return "HANDMAP stop Play first" end
local map = workspace:FindFirstChild("ClaudeBlockout")
local lane = map and map:FindFirstChild("Lane")
local props = lane and lane:FindFirstChild("Props")
if not props then return "HANDMAP no ClaudeBlockout.Lane.Props in this place: load the map first" end
local said = {}
local function say(text: string) table.insert(said, text) end
local function away(m: Instance)
	local storage = game:GetService("ServerStorage")
	local f = storage:FindFirstChild("HandMapBackup") or Instance.new("Folder")
	f.Name = "HandMapBackup"
	f.Parent = storage
	m.Parent = f
end

local ok, got = pcall(function()
	local buf = game:GetService("EncodingService"):Base64Decode(buffer.fromstring(DATA))
	return game:GetService("SerializationService"):DeserializeInstancesAsync(buf)
end)
if ok then
	local folder = got[1]
	local right = 0
	for _, m in folder:GetChildren() do
		local at, stands, old = m:GetAttribute("HandAt"), false, {}
		for _, other in props:GetChildren() do
			if other.Name == m.Name and other:IsA("Model") then
				if (other:GetBoundingBox().Position - at).Magnitude < 1 then stands = true else table.insert(old, other) end
			end
		end
		if stands then
			right += 1
		else
			say(m:GetAttribute("HandKind") .. " " .. m.Name .. " to " .. string.format("%d, %d, %d", at.X, at.Y, at.Z))
			if not CHECK then
				if m:GetAttribute("HandKind") == "moved" then
					for _, other in old do away(other) end
				end
				local c = m:Clone()
				c:SetAttribute("HandKind", nil)
				c:SetAttribute("HandAt", nil)
				c.Parent = props
			end
		end
	end
	say(right .. " of " .. #folder:GetChildren() .. " props already right")
	folder:Destroy()
else
	say("PROPS NOT PUT IN (" .. tostring(got):sub(1, 120) .. "): drag art/place/HandProps.rbxm into Studio and say so")
end

local dock = map:FindFirstChild("Dock")
local stations = dock and dock:FindFirstChild("Stations")
local FUSE = CFrame.new(2999.74609, 0.5, -119.628998)
local function kits(m: Model): boolean -- where the kit built it, so nobody's hand has been on it
	local was = m:GetAttribute("KitPivot")
	return typeof(was) ~= "CFrame" or (was.Position - m:GetPivot().Position).Magnitude < 0.1
end
local fuse = stations and stations:FindFirstChild("Fuse")
if not fuse then
	say("no Fuse station here")
elseif (fuse:GetPivot().Position - FUSE.Position).Magnitude < 0.1 then
	say("Fuse already right")
elseif not kits(fuse) then
	say("Fuse was moved by hand in this place to " .. tostring(fuse:GetPivot().Position) .. ": left there")
else
	say("Fuse moved")
	if not CHECK then
		fuse:PivotTo(FUSE)
	end
end
local index = stations and stations:FindFirstChild("Index")
if not index then
	say("Index already gone")
elseif not kits(index) then
	say("Index was moved by hand in this place: left there")
else
	say("Index taken away")
	if not CHECK then
		away(index)
	end
end

local seabed = lane:FindFirstChild("Seabed")
for _, p in if seabed then seabed:GetChildren() else {} do
	if p:IsA("BasePart") and (p.Position - Vector3.new(2984.047, -113.32, 1071.32)).Magnitude < 0.5 then
		local pink = Color3.fromRGB(239, 138, 154)
		if p.Color:ToHex() ~= pink:ToHex() then
			say("one seabed tile recoloured")
			if not CHECK then
				p.Color = pink
			end
		end
	end
end
return "HANDMAP " .. (if CHECK then "(check only) " else "") .. table.concat(said, "; ")
"""


def main():
    args = sys.argv[1:]
    studio = next((a for a in args if not a.startswith("--")), "runner")
    data = base64.b64encode(open(os.path.join(ROOT, "art", "place", "HandProps.rbxm"), "rb").read()).decode()
    path = os.path.join(tempfile.gettempdir(), "hand_map.luau")
    code = LUAU.replace("__CHECK__", str("--check" in args).lower()).replace("__DATA__", data)
    open(path, "w", encoding="utf-8", newline="\n").write(code)
    out = subprocess.run(["node", os.path.join(ROOT, "tools", "studio", "run_luau.js"), studio, path],
                         capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=ROOT, timeout=300)
    text = out.stdout + out.stderr
    at = text.rfind("HANDMAP")
    print(text[at:].strip() if at >= 0 else "HAND MAP: no answer from Studio: " + text[-400:])
    return 0 if at >= 0 and "NOT PUT IN" not in text else 1


if __name__ == "__main__":
    sys.exit(main())
