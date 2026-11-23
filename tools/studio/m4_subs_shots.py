"""The nine toy subs seen in the game (task m4): each over the stand with its name sign, each on a real trip (the
game's own riding view), and the stand's shop at PC and phone size, with a read-out of how each card's picture frames
its model. IT TAKES THE CAMERA AND SENDS THE PLAYER ON TRIPS: run it only in a playtest you started yourself, and
make sure nobody is playing in it.
    python tools/studio/m4_subs_shots.py install            (in Edit, before Play)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/m4_subs_shots.py gate               (in the playtest: are the stills live?)
    python tools/studio/m4_subs_shots.py closes [tier ...]  (each over the stand, with its sign)
    python tools/studio/m4_subs_shots.py shop <tag>         (the shop's cards, PC and phone: read-out and stills)
    python tools/studio/m4_subs_shots.py rides [tier ...]   (a real trip a tier, a still in the game's own view)
    python tools/studio/m4_subs_shots.py probes [tier ...] [sets=a,b]   (test stills of the name sign on a trip: as the
                                                            game has it, always on top, with no far limit; or the sets
                                                            given, words joined by +: top far quiet nowater nounder notitle)
    python tools/studio/m4_subs_shots.py numbers [tier ...] [up=N]  (the read-out with no still; up=N: that SignUp, this client only)
    python tools/studio/m4_subs_shots.py sheets [ride]      (the sheets in docs/attachments, from the stills)
    python tools/studio/m4_subs_shots.py remove             (in Edit, after the stop)
It rides on s2_subs_check's server door and t3_toy_subs_check's client (the trip's numbers) and adds its own
LocalScript. Studio's window may be hidden (it redraws about once a second then, or not at all): every still must
differ from the one before it, or the run stops. Log: work/m4/shots.log; stills work/m4/*.png.
"""
import json
import math
import re
import sys
import time
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import s2_subs_check as s2  # noqa: E402
import t3_toy_subs_check as t3  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/creatures"))
OUT = ROOT / "work/m4"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
NAMES = t3.NAMES
PHONE = (844, 390)
# the game view inside the picture of Studio's window (left, top, right, bottom): set by `gate` from the first still
VIEW_FILE = OUT / "view.json"

CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local report = RS:WaitForChild("ZZS2Report")
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local SubModels = require(RS:WaitForChild("Shared"):WaitForChild("SubModels"))
local SubPanel = require(Client:WaitForChild("UI"):WaitForChild("SubPanel"))
local State = require(Client:WaitForChild("Lib"):WaitForChild("State"))
local POINTS = __POINTS__
local line = nil
local function stand()
	local dock = workspace:FindFirstChild("Dock", true)
	local stations = dock and dock:FindFirstChild("Stations")
	return stations and stations:FindFirstChild("Sub")
end
local function shopGui()
	return player.PlayerGui:FindFirstChild("SubShop")
end
local function listOf(gui)
	local carousel = gui:FindFirstChild("Carousel", true)
	return carousel and carousel:FindFirstChild("List")
end
local function scaleOf(gui)
	local sc = gui.Root:FindFirstChildOfClass("UIScale")
	return sc and sc.Scale or 1
end
local function ourSub()
	for _, m in workspace.CurrentCamera:GetChildren() do
		if m.Name == "Submarine" and m:GetAttribute("For") == player.UserId then return m end
	end
	return nil
end
local RunService = game:GetService("RunService")
local probeRows, probeSet, marker, marker2, lastPos = {}, "", nil, nil, nil
local function ball(colour)
	local m = Instance.new("Part")
	m.Name = "M4Marker"
	m.Shape = Enum.PartType.Ball
	m.Size = Vector3.one * 1.6
	m.Material = Enum.Material.Neon
	m.Color = colour
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.Parent = workspace
	return m
end
-- how far up into the sign's box (14 x 3 studs, facing the camera, its middle at `at`) the model's own points reach,
-- seen from the camera: 0 when nothing nearer than the sign stands in front of it, 3 when a piece crosses all of it
local function covered(cam, at, sub, pts)
	local s = cam.CFrame:PointToObjectSpace(at)
	local worst = 0
	if s.Z >= 0 then return 0 end
	for i = 1, #pts, 3 do
		local p = cam.CFrame:PointToObjectSpace(sub:PointToWorldSpace(Vector3.new(pts[i], pts[i + 1], pts[i + 2])))
		if p.Z < 0 and p.Z > s.Z + 0.5 then
			local k = s.Z / p.Z
			local x, y = p.X * k, p.Y * k
			if math.abs(x - s.X) <= 7 and y > s.Y - 1.5 then
				worst = math.max(worst, math.min(y - (s.Y - 1.5), 3))
			end
		end
	end
	return worst
end
local between, over, rideFor = {}, {}, 0
local snapSaid = "none"
local lastUp = "?"
-- the probe's set is words joined by "+": top, far, quiet (no balls), nowater (the water script's drawings out for the
-- trip), nounder (only its nine sheets overhead out), notitle (a screen that lays a text over the name is put off)
local function has(word) return string.find("+" .. probeSet .. "+", "+" .. word .. "+", 1, true) ~= nil end
local outParts, outGuis, sheet = {}, {}, nil
local function waterOut()
	local layers = workspace:FindFirstChild("WaterLayers", true)
	sheet = layers and layers:FindFirstChild("Under") or sheet
	if not layers then return "no WaterLayers" end
	local n = 0
	if has("nowater") then
		table.insert(outParts, { layers, layers.Parent })
		layers.Parent = nil
		n = 1
	elseif has("nounder") then
		for _, c in layers:GetChildren() do
			if c.Name == "Under" then
				table.insert(outParts, { c, layers })
				c.Parent = nil
				n += 1
			end
		end
	end
	return "out=" .. n
end
local function putBack()
	for _, item in outParts do item[1].Parent = item[2] end
	for _, g in outGuis do g.Enabled = true end
	local n = #outParts + #outGuis
	outParts, outGuis = {}, {}
	return n
end
local function probeStep(dt)
	if player:GetAttribute("SubPhase") ~= "Ride" then return end
	local found = ourSub()
	local hull = found and found.PrimaryPart
	local sign = found and found:FindFirstChild("Label", true)
	if not (hull and sign) then return end
	if has("top") then sign.AlwaysOnTop = true end
	if has("far") then sign.MaxDistance = 100000 end
	local cam = workspace.CurrentCamera
	-- where the engine draws the sign: StudsOffsetWorldSpace keeps to the world's axes (the engine reference, "relative
	-- to the global axes"), counted from the Adornee (an Attachment's place) or, with none, from the part it is in
	local ad = sign.Adornee
	local base = if ad and ad:IsA("Attachment") then ad.WorldPosition else hull.Position
	local world = base + sign.StudsOffsetWorldSpace
	local folder = RS:FindFirstChild(SubModels.Templates)
	local tier = found:GetAttribute("Tier")
	local t = folder and folder:FindFirstChild(SubModels.style(tier).Id)
	local cover, meant, eye = -1, world, Vector3.zero
	lastUp = SubModels.style(tier).SignUp or 0
	if t and POINTS[tier] then
		local sub = hull.CFrame * t.Hull.CFrame:Inverse()
		-- where it is meant: the same offset, turned with the sub (over the tower however the sub dips and banks)
		meant = base + sub:VectorToWorldSpace(sign.StudsOffsetWorldSpace)
		cover = covered(cam, world, sub, POINTS[tier])
		eye = sub:PointToObjectSpace(cam.CFrame.Position)
	end
	-- a pink ball 3 studs over where the sign is meant, a green one 3 studs over where the engine draws it
	-- ("quiet": no balls, for a still that is the record of how the game looks)
	if not has("quiet") then
		marker = marker or ball(Color3.fromRGB(255, 0, 200))
		marker2 = marker2 or ball(Color3.fromRGB(0, 255, 60))
		marker.Position = meant + Vector3.new(0, 3, 0)
		marker2.Position = world + Vector3.new(0, 3, 0)
	end
	local speed = if lastPos then (hull.Position - lastPos).Magnitude / math.max(dt, 1e-4) else 0
	lastPos = hull.Position
	local sp, on = cam:WorldToViewportPoint(world)
	-- what else stands between the camera and the sign's middle and its two ends (any part, see-through or not)
	local right = cam.CFrame.RightVector
	local ok, parts = pcall(function()
		return cam:GetPartsObscuringTarget({ world, world - right * 6, world + right * 6 }, { marker, marker2 })
	end)
	local count = 0
	if ok then
		for _, part in parts do
			count += 1
			local key = string.format("%s%s(%.1f)", if part:IsDescendantOf(found) then "sub." else "", part.Name, part.Transparency)
			between[key] = (between[key] or 0) + 1
		end
	end
	-- and what the screen's own layer (the HUD, drawn over every sign in the world) shows at those three points
	local guiHits, lettersOver = 0, 0
	local pg = player:FindFirstChildOfClass("PlayerGui")
	-- the sign's own box on the screen (it faces the camera: 14 x 3 studs about `world`)
	local up = cam.CFrame.UpVector
	local c1 = cam:WorldToScreenPoint(world - right * 7 + up * 1.5)
	local c2 = cam:WorldToScreenPoint(world + right * 7 - up * 1.5)
	local sx0, sx1 = math.min(c1.X, c2.X), math.max(c1.X, c2.X)
	local sy0, sy1 = math.min(c1.Y, c2.Y), math.max(c1.Y, c2.Y)
	if pg then
		local seen = {}
		for _, point in { world, world - right * 5, world + right * 5 } do
			local at2 = cam:WorldToScreenPoint(point)
			local okGui, hits = pcall(function() return pg:GetGuiObjectsAtPosition(math.round(at2.X), math.round(at2.Y)) end)
			for _, g in if okGui then hits else {} do
				local key = nil
				if g:IsA("TextLabel") and g.Text ~= "" and g.TextTransparency < 0.9 then
					key = "gui." .. g.Name .. ":" .. string.gsub(string.sub(g.Text, 1, 16), "%s", "_")
					if has("notitle") then
						local screen = g:FindFirstAncestorWhichIsA("LayerCollector")
						if screen and screen.Enabled then
							screen.Enabled = false
							table.insert(outGuis, screen)
						end
					end
					-- its letters, not its box: TextBounds placed by the label's alignment; counted while the text
					-- is more than half there. The share of the sign's box they lie over
					if g.TextTransparency < 0.5 and not seen[key] then
						local ax = if g.TextXAlignment == Enum.TextXAlignment.Left then 0 elseif g.TextXAlignment == Enum.TextXAlignment.Right then 1 else 0.5
						local ay = if g.TextYAlignment == Enum.TextYAlignment.Top then 0 elseif g.TextYAlignment == Enum.TextYAlignment.Bottom then 1 else 0.5
						local tx0 = g.AbsolutePosition.X + (g.AbsoluteSize.X - g.TextBounds.X) * ax
						local ty0 = g.AbsolutePosition.Y + (g.AbsoluteSize.Y - g.TextBounds.Y) * ay
						local w = math.max(0, math.min(sx1, tx0 + g.TextBounds.X) - math.max(sx0, tx0))
						local h = math.max(0, math.min(sy1, ty0 + g.TextBounds.Y) - math.max(sy0, ty0))
						lettersOver = math.max(lettersOver, w * h / math.max((sx1 - sx0) * (sy1 - sy0), 1))
					end
				elseif g:IsA("ImageLabel") and g.Image ~= "" and g.ImageTransparency < 0.9 then
					key = "gui." .. g.Name .. ":image"
				elseif g.BackgroundTransparency < 0.9 then
					key = "gui." .. g.Name .. ":fill"
				end
				if key and not seen[key] then
					seen[key] = true
					guiHits += 1
					over[key] = (over[key] or 0) + 1
				end
			end
		end
	end
	rideFor += dt
	table.insert(probeRows, { dt, speed, (cam.CFrame.Position - world).Magnitude, if sign.Enabled then 1 else 0, if on then 1 else 0, sp.X, sp.Y,
		(meant - world).Magnitude, cover, rideFor, eye.X, eye.Y, eye.Z,
		math.deg(math.asin(math.clamp(hull.CFrame.LookVector.Y, -1, 1))), count, guiHits, lettersOver,
		world.Y, cam.CFrame.Position.Y, if sheet then sheet.Position.Y else 1e9, if sheet then sheet.Transparency else -1 })
end
workspace:GetAttributeChangedSignal("M4Do"):Connect(function()
	local cmd = tostring(workspace:GetAttribute("M4Do") or "")
	local words = string.split(cmd, "|")
	local verb = words[1]
	local ok, said = pcall(function()
		if verb == "signup" then
			-- signup|<tier>|<studs>: this client's copy of a tier's SignUp, for the next trip's model (a test only)
			local row = SubModels.style(tonumber(words[2]))
			local was = row.SignUp or 0
			row.SignUp = tonumber(words[3])
			return string.format("signup tier=%s was=%s now=%s", words[2], tostring(was), tostring(row.SignUp))
		end
		if verb == "snap" then
			-- can the engine's own screenshot be read back as pixels? (a try: Studio's window was not redrawing)
			if words[2] == "read" then return "snap " .. snapSaid end
			snapSaid = "asked"
			game:GetService("CaptureService"):CaptureScreenshot(function(id)
				local ok2, why = pcall(function()
					local img = game:GetService("AssetService"):CreateEditableImageAsync(Content.fromUri(id))
					local size = img.Size
					local pix = img:ReadPixelsBuffer(Vector2.zero, size)
					local n, pink = size.X * size.Y, 0
					for i = 0, n - 1, 97 do
						local r, g, b = buffer.readu8(pix, i * 4), buffer.readu8(pix, i * 4 + 1), buffer.readu8(pix, i * 4 + 2)
						if r > 200 and g < 60 and b > 200 then pink += 1 end
					end
					snapSaid = string.format("ok id=%s size=%dx%d pinkShare=%.3f", tostring(id), size.X, size.Y, pink / math.ceil(n / 97))
				end)
				if not ok2 then snapSaid = "failed id=" .. tostring(id) .. " why=" .. tostring(why) end
			end)
			return "snap asked"
		end
		if verb == "ping" then
			return "pong mode=" .. tostring(State.Mode)
		elseif verb == "close" then
			-- one sub over the stand, turned three-quarters to the camera, with its name sign; the stand under it
			if line then line:Destroy() end
			line = Instance.new("Folder")
			line.Name = "M4Line"
			line.Parent = workspace
			local n = tonumber(words[2])
			local at = stand():GetPivot().Position
			local model, parts = SubModels.build(n)
			local top, low = -math.huge, math.huge
			for _, p in parts do
				top = math.max(top, p.Position.Y + p.Size.Y / 2)
				low = math.min(low, p.Position.Y - p.Size.Y / 2)
			end
			local sign = model:FindFirstChild("Label", true)
			local signAt = sign.Adornee
			local signFrom = if signAt and signAt:IsA("Attachment") then signAt.WorldPosition.Y else sign.Parent.Position.Y
			local signLow = signFrom + sign.StudsOffsetWorldSpace.Y - sign.Size.Y.Scale / 2
			local text = sign:FindFirstChildOfClass("TextLabel").Text
			-- words: tier, the sub's turn, where it floats, where the camera stands, what it looks at (all from the stand), fov
			local function v(i)
				return Vector3.new(tonumber(words[i]), tonumber(words[i + 1]), tonumber(words[i + 2]))
			end
			local turn = CFrame.new(at + v(4)) * CFrame.Angles(0, math.rad(tonumber(words[3])), 0)
			for _, p in parts do
				p.CFrame = turn * p.CFrame
			end
			model.Parent = line
			local cam = workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.lookAt(at + v(7), at + v(10))
			cam.FieldOfView = tonumber(words[13])
			return string.format("close %d sign=%q hullMesh=%s parts=%d top=%.1f low=%.1f signLow=%.1f gap=%.1f", n, text,
				tostring(model.PrimaryPart:IsA("MeshPart")), #parts, top, low, signLow, signLow - top)
		elseif verb == "flash" then
			-- the whole game view in one colour for a moment: the gate finds the view in the window's picture by it
			local old = player.PlayerGui:FindFirstChild("M4Flash")
			if old then old:Destroy() end
			if words[2] == "on" then
				local g = Instance.new("ScreenGui")
				g.Name = "M4Flash"
				g.IgnoreGuiInset = true
				g.DisplayOrder = 10000
				local f = Instance.new("Frame")
				f.Size = UDim2.fromScale(1, 1)
				f.BorderSizePixel = 0
				f.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
				f.Parent = g
				g.Parent = player.PlayerGui
			end
			local v = workspace.CurrentCamera.ViewportSize
			return string.format("flash %s view=%dx%d", tostring(words[2]), v.X, v.Y)
		elseif verb == "unclose" then
			if line then line:Destroy() line = nil end
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			workspace.CurrentCamera.FieldOfView = 70
			return "unclosed"
		elseif verb == "hud" then
			-- the screens out of the picture, and back
			local on = words[2] == "on"
			for _, g in player.PlayerGui:GetChildren() do
				if g:IsA("ScreenGui") then
					if not on and g.Enabled then
						g:SetAttribute("M4Hid", true)
						g.Enabled = false
					elseif on and g:GetAttribute("M4Hid") then
						g:SetAttribute("M4Hid", nil)
						g.Enabled = true
					end
				end
			end
			pcall(function()
				game:GetService("StarterGui"):SetCore("TopbarEnabled", on)
			end)
			return "hud " .. words[2]
		elseif verb == "near" then
			-- onto the stand's ring: the shop closes itself further than Config.Sub.Near from it
			local ring = stand():FindFirstChild("Ring")
			local character = player.Character
			character:PivotTo(CFrame.new(ring.Position + Vector3.new(0, 4, 0)))
			task.wait(0.5)
			local root = character:FindFirstChild("HumanoidRootPart")
			return string.format("near %.1f studs from the ring, mode=%s", (root.Position - ring.Position).Magnitude, tostring(State.Mode))
		elseif verb == "shop" then
			SubPanel.toggle(words[2] == "on")
			task.wait(0.9)
			local gui = shopGui()
			return "shop " .. words[2] .. " enabled=" .. tostring(gui and gui.Enabled)
		elseif verb == "scroll" then
			-- card `index` (0: NO SUB) at the list's left
			local gui = shopGui()
			local list = listOf(gui)
			local most = math.max(0, list.AbsoluteCanvasSize.X - list.AbsoluteWindowSize.X)
			list.CanvasPosition = Vector2.new(math.clamp(tonumber(words[2]) * 200 * scaleOf(gui), 0, most), 0)
			task.wait(0.3)
			return string.format("scroll %s canvasX=%d of %d enabled=%s", words[2], list.CanvasPosition.X, most, tostring(gui.Enabled))
		elseif verb == "phone" then
			local w, h = tonumber(words[2]), tonumber(words[3])
			workspace:SetAttribute("PanelPhone", if w and h then Vector2.new(w, h) else nil)
			task.wait(0.4)
			return "phone " .. tostring(workspace:GetAttribute("PanelPhone"))
		elseif verb == "cards" then
			-- how each card's picture frames its model: the model's own points through the card's camera, as shares of
			-- the picture's half width and half height (inside when all are within -1..1)
			local gui = shopGui()
			local list = listOf(gui)
			local window = gui.Root.Window
			local view = workspace.CurrentCamera.ViewportSize
			local out = { string.format("enabled=%s scale=%.3f window=%dx%d at %d,%d screen=%dx%d", tostring(gui.Enabled), scaleOf(gui),
				window.AbsoluteSize.X, window.AbsoluteSize.Y, window.AbsolutePosition.X, window.AbsolutePosition.Y, view.X, view.Y) }
			for n = 1, 9 do
				local card = list:FindFirstChild("Sub" .. n)
				local frame = card and card:FindFirstChildWhichIsA("ViewportFrame", true)
				local model = frame and frame:FindFirstChildOfClass("Model")
				local pts = POINTS[n]
				if not (frame and model and pts) then
					table.insert(out, n .. ": no picture")
					continue
				end
				local cam = frame.CurrentCamera
				local size = frame.AbsoluteSize
				local ty = math.tan(math.rad(cam.FieldOfView / 2))
				local tx = ty * size.X / size.Y
				local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
				local plo, phi = Vector3.one * math.huge, Vector3.one * -math.huge
				for i = 1, #pts, 3 do
					local world = Vector3.new(pts[i], pts[i + 1], pts[i + 2])
					plo, phi = plo:Min(world), phi:Max(world)
					local p = cam.CFrame:PointToObjectSpace(world)
					local x, y = p.X / -p.Z / tx, p.Y / -p.Z / ty
					x0, x1, y0, y1 = math.min(x0, x), math.max(x1, x), math.min(y0, y), math.max(y1, y)
				end
				-- the model in the picture against those points: the same place, the same way round
				local mlo, mhi = Vector3.one * math.huge, Vector3.one * -math.huge
				local mesh = false
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						mlo, mhi = mlo:Min(d.Position - d.Size / 2), mhi:Max(d.Position + d.Size / 2)
						mesh = mesh or d:IsA("MeshPart")
					end
				end
				local a, b = (mlo - plo):Abs(), (mhi - phi):Abs()
				local off = math.max(a.X, a.Y, a.Z, b.X, b.Y, b.Z)
				local worst = math.max(-x0, x1, -y0, y1)
				local eye = cam.CFrame.Position
				table.insert(out, string.format("%d: %s box=%dx%d x=%.2f..%.2f y=%.2f..%.2f worst=%.2f %s eye=%.1f,%.1f,%.1f mesh=%s boxOff=%.2f", n,
					SubModels.style(n).Id, size.X, size.Y, x0, x1, y0, y1, worst, if worst <= 1 then "inside" else "CUT", eye.X, eye.Y, eye.Z,
					tostring(mesh), off))
			end
			return table.concat(out, "\n")
		elseif verb == "oldcam" then
			-- the cards' pictures from where the camera stood before task m4 (one spot for all nine), and back
			local list = listOf(shopGui())
			local count = 0
			for n = 1, 9 do
				local card = list:FindFirstChild("Sub" .. n)
				local frame = card and card:FindFirstChildWhichIsA("ViewportFrame", true)
				local cam = frame and frame.CurrentCamera
				if cam then
					if words[2] == "on" then
						if not cam:GetAttribute("M4Was") then cam:SetAttribute("M4Was", cam.CFrame) end
						cam.CFrame = CFrame.lookAt(Vector3.new(-44, 18, -36), Vector3.new(0, 2, 0))
					elseif cam:GetAttribute("M4Was") then
						cam.CFrame = cam:GetAttribute("M4Was")
						cam:SetAttribute("M4Was", nil)
					end
					count += 1
				end
			end
			return "oldcam " .. tostring(words[2]) .. " cards=" .. count
		elseif verb == "probe" then
			-- the name sign on a trip, frame by frame after the game's own step: is it on, how far, where on the screen;
			-- a pink ball rides 3 studs over where the sign's middle should be. words[3]: "top" (AlwaysOnTop), "far"
			-- (no MaxDistance) or "" (as the game has it)
			if words[2] == "on" then
				probeRows = {}
				between, over, rideFor = {}, {}, 0
				probeSet = words[3] or ""
				lastPos = nil
				local said = waterOut()
				pcall(function() RunService:UnbindFromRenderStep("M4Probe") end)
				RunService:BindToRenderStep("M4Probe", Enum.RenderPriority.Camera.Value + 6, probeStep)
				return "probe on " .. probeSet .. " " .. said
			elseif words[2] == "now" then
				local r = probeRows[#probeRows]
				if not r then return "probe now: no frames" end
				return string.format("probe now frame=%d dt=%.4f speed=%.0f camToSign=%.1f enabled=%d onScreen=%d screen=%.0f,%.0f modelUpSign=%.2f hudBoxes=%d titleLettersOver=%.2f", #probeRows,
					r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[9], r[16], r[17])
			else
				pcall(function() RunService:UnbindFromRenderStep("M4Probe") end)
				local back = putBack()
				if marker then marker:Destroy() marker = nil end
				if marker2 then marker2:Destroy() marker2 = nil end
				local n = #probeRows
				if n == 0 then return "probe read: no frames" end
				-- least, middle and most of one column, over the frames at least `from` seconds into the Ride
				local function col(i, from)
					local c = {}
					for _, r in probeRows do
						if r[10] >= (from or 0) then table.insert(c, r[i]) end
					end
					table.sort(c)
					if #c == 0 then return 0, 0, 0 end
					return c[1], c[math.ceil(#c / 2)], c[#c]
				end
				local d0, d1, d2 = col(1)
				local s0, s1, s2 = col(2)
				local c0, c1, c2 = col(3)
				local e0 = col(4)
				local o0, _, o2 = col(5)
				local _, w1, w2 = col(8)
				local _, k1, k2 = col(9)
				local _, _, ks = col(9, 1)
				local _, ex = col(11, 1)
				local _, ey = col(12, 1)
				local _, ez = col(13, 1)
				local p0, _, p2 = col(14)
				local _, _, bn = col(15)
				local hid = 0
				for _, r in probeRows do
					if r[9] > 0.25 then hid += 1 end
				end
				local names = {}
				for key, frames in between do table.insert(names, { key, frames }) end
				table.sort(names, function(x, y) return x[2] > y[2] end)
				local list = {}
				for i = 1, math.min(#names, 8) do table.insert(list, names[i][1] .. "=" .. names[i][2]) end
				local hud, hudNames, hudList = 0, {}, {}
				local letters, lettersMost = 0, 0
				for _, r in probeRows do
					if r[16] > 0 then hud += 1 end
					if r[17] > 0.1 then letters += 1 end
					lettersMost = math.max(lettersMost, r[17])
				end
				for key, frames in over do table.insert(hudNames, { key, frames }) end
				table.sort(hudNames, function(x, y) return x[2] > y[2] end)
				for i = 1, math.min(#hudNames, 8) do table.insert(hudList, hudNames[i][1] .. "=" .. hudNames[i][2]) end
				local view = workspace.CurrentCamera.ViewportSize
				local y0, _, y2 = col(18)
				local q0, _, q2 = col(19)
				local h0, _, h2 = col(20)
				local t0, _, t2 = col(21)
				local above, camAbove = 0, 0
				for _, r in probeRows do
					if r[18] > r[20] then above += 1 end
					if r[19] > r[20] then camAbove += 1 end
				end
				local heights = string.format(" signY=%.0f..%.0f camY=%.0f..%.0f sheetY=%.0f..%.0f sheetSee=%.2f..%.2f signAboveSheet=%.2f camAboveSheet=%.2f putBack=%d",
					y0, y2, q0, q2, h0, h2, t0, t2, above / n, camAbove / n, back)
				return string.format("probe read set=%q frames=%d dt=%.4f/%.4f/%.4f speed=%.0f/%.0f/%.0f camToSign=%.1f/%.1f/%.1f enabledMin=%d onScreen=%d..%d offBy=%.2f/%.2f cover=%.2f/%.2f steadyMax=%.2f coveredShare=%.2f eye=%.1f,%.1f,%.1f pitch=%.0f..%.0f betweenMost=%d between=[%s] hudOverShare=%.2f lettersOverShare=%.2f lettersOverMost=%.2f signUp=%s hud=[%s] view=%dx%d",
					probeSet, n, d0, d1, d2, s0, s1, s2, c0, c1, c2, e0, o0, o2, w1, w2, k1, k2, ks, hid / n, ex, ey, ez, p0, p2, bn,
					table.concat(list, " "), hud / n, letters / n, lettersMost, tostring(lastUp), table.concat(hudList, " "), view.X, view.Y) .. heights
			end
		end
		return "?"
	end)
	report:FireServer(tostring(said) .. " " .. tostring(ok))
end)
'''

LOG = []


def note(text):
    print(text, flush=True)
    LOG.append(text)


def save_log():
    with open(OUT / "shots.log", "a", encoding="utf-8") as f:
        f.write("\n".join(LOG) + "\n")
    LOG.clear()


def hull_points(directions=500):
    """each tier's own outline: the model's points that are furthest out in `directions` ways (its convex corners)"""
    import glob

    import glb_meshes

    out = {}
    ways = []
    for i in range(directions):
        z = 1 - 2 * (i + 0.5) / directions
        r = math.sqrt(1 - z * z)
        a = i * math.pi * (3 - math.sqrt(5))
        ways.append((r * math.cos(a), r * math.sin(a), z))
    for path in glob.glob(str(ROOT / "art/subs/*/*.glb")):
        tier = json.load(open(path[:-4] + ".mesh.json", encoding="utf-8"))["tier"]
        pts = []
        for p in glb_meshes.parts(path):
            if p["triangles"]:
                pts += [tuple(v[i] + p["origin"][i] for i in range(3)) for v in p["positions"]]
        keep = set()
        for w in ways:
            keep.add(max(pts, key=lambda v: v[0] * w[0] + v[1] * w[1] + v[2] * w[2]))
        out[tier] = sorted(keep)
    return out


def install(remove=False):
    out = t3.install(remove)
    points = "nil"
    if not remove:
        rows = []
        for tier, pts in sorted(hull_points().items()):
            rows.append("[%d] = { %s }" % (tier, ", ".join("%.2f" % c for p in pts for c in p)))
        points = "{ " + ", ".join(rows) + " }"
    return out + " / " + s2.job(f"""local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZM4Check")
if old then old:Destroy() end
workspace:SetAttribute("M4Do", nil)
workspace:SetAttribute("PanelPhone", nil)
if {s2.lua(remove)} then
	return "removed m4"
end
local c = Instance.new("LocalScript")
c.Name = "ZZM4Check"
c.Source = {s2.lua(CLIENT.replace("__POINTS__", points))}
c.Parent = sps
return "installed m4 " .. #c.Source
""")


def do(c, wait=1.4):
    return s2.server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('S2Client', '') "
        f"workspace:SetAttribute('M4Do', {s2.lua(c + '|' + str(time.time()))}) "
        f"task.wait({wait}) return RS:GetAttribute('S2Client')"
    )


def view():
    return tuple(json.loads(VIEW_FILE.read_text())) if VIEW_FILE.exists() else (s2.OFFSET[0], s2.OFFSET[1],
                                                                              s2.OFFSET[0] + s2.VIEW[0],
                                                                              s2.OFFSET[1] + s2.VIEW[1])


def raw(name):
    """one picture of Studio's whole window (the runner's `shot` returns before the file is written).

    It is the window's own picture, whole and at full size wherever the window stands, on screen or off. When Studio
    stops redrawing its window (Hugo's PC, 2026-11-23, evening) this returns the last picture it drew: the gate below
    is what tells."""
    full = OUT / (name + "-full.png")
    full.unlink(missing_ok=True)
    out = s2.run(["shot", str(full)], timeout=60)
    size, end = -1, time.time() + 12
    while time.time() < end:
        now = full.stat().st_size if full.exists() else -1
        if now > 0 and now == size:
            break
        size = now
        time.sleep(0.15)
    else:
        raise SystemExit("no shot: " + out)
    return full


def changed(a, b):
    """the share of the game view that differs between two stills"""
    d = ImageChops.difference(Image.open(a).convert("RGB"), Image.open(b).convert("RGB")).convert("L")
    d = d.point(lambda v: 255 if v > 24 else 0)
    return d.histogram()[255] / (d.size[0] * d.size[1])


LAST = OUT / "last.txt"


def shot(name, tries=5, least=0.004):
    """a still of the game view that differs from the still before it (a hidden Studio redraws late, or never)"""
    before = Path(LAST.read_text()) if LAST.exists() else None
    path = OUT / (name + ".png")
    for i in range(tries):
        full = raw(name)
        Image.open(full).convert("RGB").crop(view()).save(path)
        full.unlink(missing_ok=True)
        share = changed(before, path) if before and before.exists() and before != path else 1.0
        if share >= least:
            LAST.write_text(str(path))
            note(f"  still {path.name}: {share:.3f} of the view differs from the one before")
            return path
        time.sleep(1.0)
    save_log()
    raise SystemExit(f"FROZEN: {path.name} is the same picture as {before.name} after {tries} tries")


def gate():
    """Are the stills live? One still, a sub over the stand, another: they must differ. Also finds the game view."""
    end = time.time() + 60
    while time.time() < end:
        said = do("ping", 0.8)
        if "pong" in said:
            break
        time.sleep(1)
    note("client: " + said)
    # where the game view is in the window's picture: the client paints it one colour, and that box is looked for
    # (Studio's panels move it: a view.json from another day cuts the stills wrong)
    said = do("flash|on", 1.2)
    note(said)
    box = None
    for _ in range(6):
        time.sleep(1.2)
        full = raw("gate")
        im = Image.open(full).convert("RGB")
        r, g, b = im.split()
        mask = ImageChops.multiply(ImageChops.multiply(r.point(lambda v: 255 if v > 230 else 0),
                                                       g.point(lambda v: 255 if v < 40 else 0)),
                                   b.point(lambda v: 255 if v > 230 else 0))
        box = mask.getbbox()
        if box and (box[2] - box[0]) > 400 and (box[3] - box[1]) > 300:
            break
        box = None
    note(do("flash|off", 0.8))
    if not box:
        save_log()
        raise SystemExit("FROZEN: the game view never showed the gate's colour (Studio's window is not redrawing)")
    VIEW_FILE.write_text(json.dumps(list(box)))
    note(f"window picture {im.size}, the game view in it {box}")
    time.sleep(1.2)
    LAST.unlink(missing_ok=True)
    a = shot("gate-a")
    note(do("close|1|" + "|".join(str(v) for v in CLOSE), 2.5))
    time.sleep(1.5)
    b = shot("gate-b")
    note(do("unclose", 1))
    note(f"live: {a.name} and {b.name} differ")
    save_log()


# a sub over the stand: its turn, where it floats, where the camera stands, what it looks at (from the stand), fov
CLOSE = [55, 0, 40, -6, -22, 30, -74, 0, 30, -6, 50]


def closes(tiers, close=None):
    """each sub beside the stand with its name sign, the screens out of the picture; the same camera for all nine"""
    close = close or CLOSE
    note(do("hud|off", 1))
    for n in tiers or range(1, 10):
        said = do(f"close|{n}|" + "|".join(str(v) for v in close), 2.5)
        note(said)
        if f'sign="{NAMES[n - 1].upper()}"' not in said:
            note(f"  ! tier {n}'s sign does not read {NAMES[n - 1].upper()}")
        time.sleep(1.6)
        shot(f"stand-{n}")
    note(do("unclose", 1))
    note(do("hud|on", 1))
    save_log()


def shop(tag, old=False):
    """the stand's shop: the cards' read-out and stills, at PC size and at a phone's (`old`: from the one spot the
    cards' camera stood at before task m4)"""
    note("equip: " + s2.cmd("sub|5,6", 1.5))
    note(do("near", 1.5))
    for size, phone in (("pc", None), ("phone", PHONE)):
        note(do("phone|%d|%d" % phone if phone else "phone|off", 1))
        said = do("shop|on", 2)
        note(said)
        if "enabled=true" not in said:
            save_log()
            raise SystemExit("the shop did not open")
        if old:
            note(do("oldcam|on", 1))
        cards = do("cards", 1.5)
        note(f"cards, {size}, {tag}:\n" + cards)
        box = re.search(r"window=(\d+)x(\d+) at (-?\d+),(-?\d+)", cards)
        if box:
            (OUT / f"window-{size}.json").write_text(json.dumps([int(v) for v in box.groups()]))
        for first in (0, 3, 6, 9):
            said = do(f"scroll|{first}", 1)
            note(said)
            if "enabled=true" not in said:
                save_log()
                raise SystemExit("the shop closed itself")
            time.sleep(1.4)
            shot(f"shop-{tag}-{size}-{first}")
        if old:
            note(do("oldcam|off", 1))
        note(do("shop|off", 1.5))
    note(do("phone|off", 1))
    note("home: " + s2.cmd("home", 2))
    save_log()


def trip(tier, probe=None, picture=True):
    """a real trip on one tier to its own land; a still about 1.3 s into the Ride, in the game's own view.
    `probe` ("plain", "top", "far"): the name sign is watched frame by frame, a pink ball rides over its place.
    (Until 2026-11-23 a second trip was pictured from a test camera at the sub's side, work/m4/close-*.png. Hugo saw
    it in a playtest: "make sure it doesnt implement the camera on the side ever". It is gone from here; don't add one.)"""
    land = tier + 1
    kind = "ride"
    if probe:
        kind = f"probe-{probe}-{kind}"
    watch = probe or "quiet"  # a plain riding still is watched too, with no balls in the picture
    for attempt in range(2):
        note(f"tier {tier} to land {land} ({kind}): " + s2.cmd(f"sub|{tier},{land}", 1.5))
        note("  " + t3.do("watch", 0.4))
        note("  " + do("probe|on|" + ("" if watch == "plain" else watch), 0.4))
        note("  dive: " + s2.cmd("dive", 0.3))
        still, st = None, ""
        end = time.time() + 30
        while time.time() < end:
            st = s2.cmd("st", 0.15)
            if "phase=Ride" in st:
                # (the shortest Ride is 3.2 s: the phase is read again just before the still, not after it)
                time.sleep(0.7)
                st = s2.cmd("st", 0.1)
                # (`numbers` takes no still: the frame-by-frame read-out needs no picture of Studio's window)
                still = shot(f"{kind}-{tier}", tries=1, least=0.02) if picture else True
                st += " / after the still: " + do("probe|now", 0.1)
                break
        note("  just before the still: " + st)
        time.sleep(6)
        note("  numbers: " + t3.do("read", 0.5))
        note("  " + do("probe|read", 0.5))
        note("  home: " + s2.cmd("home", 3))
        time.sleep(1.5)
        if still and "phase=Ride" in st:
            return still
        note(f"  ! tier {tier}'s still was not in the Ride ({st}); once more")
    return None


def rides(tiers):
    for tier in tiers or range(1, 10):
        trip(tier)
    save_log()


def font(size):
    try:
        return ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", size)
    except OSError:
        return ImageFont.load_default()


def sheet(paths, labels, out, cols=3, width=880, crop=None, title=None):
    """stills tiled into one picture, each under its label"""
    tiles = []
    for p in paths:
        im = Image.open(p).convert("RGB")
        if crop:
            w, h = im.size
            im = im.crop((round(crop[0] * w), round(crop[1] * h), round(crop[2] * w), round(crop[3] * h)))
        tiles.append(im.resize((width, round(im.height * width / im.width)), Image.LANCZOS))
    h = max(t.height for t in tiles)
    rows = -(-len(tiles) // cols)
    head = 64 if title else 0
    page = Image.new("RGB", (cols * width, head + rows * (h + 44)), (16, 24, 40))
    d = ImageDraw.Draw(page)
    if title:
        d.text((14, 12), title, font=font(38), fill=(255, 214, 70))
    for i, t in enumerate(tiles):
        x, y = (i % cols) * width, head + (i // cols) * (h + 44)
        d.text((x + 12, y + 5), labels[i], font=font(30), fill=(255, 255, 255))
        page.paste(t, (x, y + 44))
    page.save(out, quality=88)
    return out


def window_crop(path, size, out, pad=14):
    """a shop still cut to the shop's window (the read-out's box; the top bar's 58 points are not in it)"""
    w, h, x, y = json.loads((OUT / f"window-{size}.json").read_text())
    im = Image.open(path).convert("RGB")
    box = (max(0, x - pad), max(0, y + 58 - pad), min(im.width, x + w + pad), min(im.height, y + 58 + h + pad))
    im.crop(box).save(out)
    return out


def ride_sheets():
    """the riding sheet (the game as it is) and, when its stills exist, the sheet of the tests on why the name is missing"""
    labels = [f"{n} {NAMES[n - 1]}" for n in range(1, 10)]
    made = [sheet([OUT / f"ride-{n}.png" for n in range(1, 10)], labels, ATTACH / "m4-subs-ride.jpg", width=760,
                  title="On a trip, the game's own view, 2026-11-24. The water's drawing hides most names (sub-models.md)")]
    tests = [("ride-2", "2, as the game is: no name"),
             ("probe-quiet+top-ride-2", "2, TEST: the name set always on top"),
             ("probe-quiet+nounder+notitle-ride-2", "2, TEST: the water's nine overhead sheets out, HUD off"),
             ("probe-quiet+nowater+notitle-ride-2", "2, TEST: all the water's drawing out, HUD off"),
             ("ride-5", "5, as the game is: only REAK shows (a cliff behind it)"),
             ("probe-quiet+nowater+notitle-ride-5", "5, TEST: all the water's drawing out, HUD off")]
    if all((OUT / f"{name}.png").exists() for name, _ in tests):
        made.append(sheet([OUT / f"{name}.png" for name, _ in tests], [label for _, label in tests],
                          ATTACH / "m4-subs-name-cause.jpg", cols=2, width=1000, crop=(0.2, 0.0, 0.8, 0.62),
                          title="Why a sub's name is missing on a trip: tests in the game, 2026-11-24 (task m4)"))
    return made


def sheets(only=None):
    """the record pictures in docs/attachments, from the stills in work/m4 (`sheets ride`: the riding sheets alone)"""
    made = []
    labels = [f"{n} {NAMES[n - 1]}" for n in range(1, 10)]
    if only == "ride":
        for p in ride_sheets():
            im = Image.open(p)
            im.resize((1500, round(im.height * 1500 / im.width)), Image.LANCZOS).save(OUT / (Path(p).stem + "-s.jpg"), quality=82)
            print(p)
        return
    made.append(sheet([OUT / f"stand-{n}.png" for n in range(1, 10)], labels, ATTACH / "m4-subs-stand.jpg", width=760,
                      crop=(0.16, 0.0, 0.86, 1.0), title="The nine toy subs over the stand, in the game (task m4)"))
    if all((OUT / f"close-{n}.png").exists() for n in range(1, 10)):
        # (stills of 2026-11-23 from the test camera that is gone: kept as the record of the rider on the seat)
        made.append(sheet([OUT / f"close-{n}.png" for n in range(1, 10)], labels, ATTACH / "m4-subs-seat.jpg", width=760,
                          title="On a trip, from a TEST camera (not the game's): the rider on the seat (task m4)"))
    made += ride_sheets()
    # the shop: the cards before the fix (two cuts kept from the first playtest, old code: work/m4/shop-old-pc-*.jpg,
    # the window at 94,41 in them) beside the same cards after it, then the list's end at PC size and on a phone
    tiles, names = [], []
    for first, which in ((3, "tiers 3 to 6"), (6, "tiers 6 to 9")):
        old = Image.open(OUT / f"shop-old-pc-{first}.jpg").convert("RGB")
        w, h, _, _ = json.loads((OUT / "window-pc.json").read_text())
        cut = OUT / f"shopcut-old-pc-{first}.png"
        old.crop((94 - 14, 41 - 14, min(old.width, 94 + w + 14), min(old.height, 41 + h + 14))).save(cut)
        tiles += [cut, window_crop(OUT / f"shop-after-pc-{first}.png", "pc", OUT / f"shopcut-after-pc-{first}.png")]
        names += [f"PC, BEFORE: {which}", f"PC, AFTER: {which}"]
    tiles += [window_crop(OUT / "shop-after-pc-9.png", "pc", OUT / "shopcut-after-pc-9.png"),
              window_crop(OUT / "shop-after-phone-9.png", "phone", OUT / "shopcut-after-phone-9.png")]
    names += ["PC, AFTER: the list's end, tiers 7 to 9", "Phone (844x390), AFTER: the list's end"]
    made.append(sheet(tiles, names, ATTACH / "m4-sub-shop.jpg", cols=2, width=900,
                      title="The sub shop's cards in the game, before and after the fix (task m4)"))
    for p in made:
        im = Image.open(p)
        im.resize((1500, round(im.height * 1500 / im.width)), Image.LANCZOS).save(OUT / (Path(p).stem + "-s.jpg"), quality=82)
        print(p)


if __name__ == "__main__":
    what = sys.argv[1]
    rest = sys.argv[2:]
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(True))
    elif what == "gate":
        gate()
    elif what == "closes":
        # closes [tier ...] [-- turn sx sy sz cx cy cz ax ay az fov]: the numbers after -- try another view
        cut = rest.index("--") if "--" in rest else len(rest)
        closes([int(a) for a in rest[:cut]], [float(a) for a in rest[cut + 1:]] or None)
    elif what == "shop":
        # shop before: the cards from the old camera spot; shop after (or any other tag): as the game has them
        shop(rest[0], old=rest[0] == "before")
    elif what == "numbers":
        # numbers [tier ...]: one probed trip a tier, no still: what the sign and the model do frame by frame
        # numbers 5 up=4.7: tier 5's trip with its SignUp set to 4.7 on this client, put back after
        ups = [float(a[3:]) for a in rest if a.startswith("up=")]
        for tier in [int(a) for a in rest if a.isdigit()] or list(range(1, 10)):
            was = None
            if ups:
                said = do(f"signup|{tier}|{ups[0]}", 0.4)
                note("  " + said)
                was = re.search(r"was=([\d.]+)", said)
            trip(tier, probe="plain", picture=False)
            if was:
                note("  " + do(f"signup|{tier}|{was.group(1)}", 0.4))
        save_log()
    elif what == "probes":
        # probes [tier ...]: the name sign on a trip, as the game has it, always on top, and with no far limit
        # probes 5 2 sets=nowater+notitle,nounder: those sets instead (words joined by +, see the client's `has`)
        sets = [a[5:].split(",") for a in rest if a.startswith("sets=")]
        for tier in [int(a) for a in rest if a.isdigit()] or [2, 6]:
            for variant in (sets[0] if sets else ("plain", "top", "far")):
                trip(tier, variant)
        save_log()
    elif what == "sheets":
        sheets(only=rest[0] if rest else None)
    elif what == "rides":
        rides([int(a) for a in rest if a.isdigit()])
    elif what == "do":
        print(do(rest[0], float(rest[1]) if len(rest) > 1 else 1.4))
