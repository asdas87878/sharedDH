"""The hub's new pieces, checked in a Studio playtest on Hugo's PC (NULLROOM h4, 2026-11-24): the three stall rings
(Sell, Auras, Sub) and the windows they open, the little sub over the submarine stand, the Index, and the keepers and
their props.
    python tools/studio/h4_hub_check.py install | remove   (in Edit, before Play: a server Script and a LocalScript)
    python tools/studio/h4_hub_check.py mine               (in a playtest: is the helper in it the one just installed?)
    python tools/studio/h4_hub_check.py run [rings] [sub] [index] [keepers] [props] [phone]   (all by default)
    python tools/studio/h4_hub_check.py gate               (are the window's pictures live? finds the game view)
    python tools/studio/h4_hub_check.py stills             (the record stills, to docs/attachments/hub-h4-*.jpg)
    python tools/studio/h4_hub_check.py do <verb|args>     (one command to the client helper, e.g. `do where`)
    python tools/studio/h4_hub_check.py log                (the client's errors and warnings so far)
How: the LocalScript walks the player with Humanoid:MoveTo, and reads the game's own modules (UI.Shop, UI.IndexPanel,
Shared.Keepers) and what is in the world on this machine: the keepers and the stand's sub exist on the client only and
answer no spatial query, so their clearances are sums over boxes. The server Script puts fish in the player's hands
(RideService.giveCarried: the Index sees a catch there) and reads what a claim paid. Answers go back through a
RemoteEvent into ServerStorage's "ZZH4Out".
What a script can not do on Hugo's PC is a real click, so two presses are made as the button's own listener makes them:
a window's X is its OnClose (Shop.go(nil)), and the hub's Index button is HubButtons' rule (Shop.go("Index"), or nil
when it is the one open).
The stills use the game's own dock camera (Roblox's, CameraType Custom): it is only turned, as a drag of the mouse
turns it, by one write of its CFrame; it is never replaced, and never put at a submarine's side.
Logs and raw shots go to work/h4/. Needs Studio open with the studio-runner plugin.
"""
import json
import math
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageChops

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fail_capture as fc  # noqa: E402

ROOT = fc.ROOT
OUT = ROOT / "work/h4"
OUT.mkdir(parents=True, exist_ok=True)
ATTACH = ROOT / "docs/attachments"
VIEW_FILE = OUT / "view.json"
PHONE = (844, 390)

SERVER = r'''
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ev = Instance.new("RemoteEvent")
ev.Name = "ZZH4Report"
ev.Parent = RS
local out = Instance.new("StringValue")
out.Name = "ZZH4Out"
out.Parent = SS
ev.OnServerEvent:Connect(function(_, kind, text)
	out.Value = string.sub(out.Value .. tostring(kind) .. "|" .. tostring(text) .. "\n", -90000)
end)
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local RideService = require(Services:WaitForChild("RideService"))
local AquariumService = require(Services:WaitForChild("AquariumService"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local IndexService = nil
pcall(function()
	IndexService = require(Services:WaitForChild("IndexService", 5))
end)
RS:SetAttribute("H4Ready", true)
local function read(player)
	local tank = AquariumService.tankOf(player)
	return string.format("state=%s max=%s coins=%s found=%s claims=%s carried=%d tank=%d subtier=%s subequip=%s",
		tostring(player:GetAttribute("State")), tostring(player:GetAttribute("MaxOxygen")),
		tostring(AquariumService.coinsOf(player)), tostring(player:GetAttribute("IndexFound")),
		tostring(player:GetAttribute("IndexClaims")), #RideService.carried(player), if tank then #tank else -1,
		tostring(player:GetAttribute("SubTier")), tostring(player:GetAttribute("SubEquip")))
end
RS:GetAttributeChangedSignal("H4Cmd"):Connect(function()
	local cmd = tostring(RS:GetAttribute("H4Cmd") or "")
	local a = string.split(cmd, "|")
	local verb = a[1]
	local player = Players:GetPlayers()[1]
	if not player then
		RS:SetAttribute("H4Said", "no player")
		return
	end
	local ok, said = pcall(function()
		if verb == "carry" then
			return "carry " .. tostring(RideService.giveCarried(player, { Id = a[2], Size = if a[3] ~= "" then a[3] else "Normal", Variant = a[4] or "" }))
		elseif verb == "take" then
			local fish = RideService.takeCarried(player, 1)
			return "take " .. tostring(fish and fish.Id)
		elseif verb == "home" then
			RideService.sendHome(player)
			return "home"
		elseif verb == "ride" then
			local at, along = RideService.sandboxStart()
			RideService.sandboxReset(player, nil, a[2], nil, { At = at + along * 160, Along = along })
			return "ride " .. a[2]
		elseif verb == "read" then
			return read(player)
		elseif verb == "first" then
			local o, c = Config.indexFirst(Config.FishById[a[2]])
			return o .. "," .. c
		elseif verb == "land" then
			local o, c = Config.indexLand(tonumber(a[2]))
			return o .. "," .. c
		elseif verb == "roster" then
			local rows = {}
			for land = 1, Config.indexLands() do
				local ids = {}
				for _, fish in Config.indexSet(land) do
					table.insert(ids, fish.Id)
				end
				table.insert(rows, { Land = land, Kinds = #Config.indexKinds(land), Set = ids })
			end
			return HttpService:JSONEncode({ Count = Config.indexCount(), Lands = rows, Index = Config.Index, Tank = AquariumService.tankOf(player) ~= nil })
		elseif verb == "found" then
			return HttpService:JSONEncode(IndexService and IndexService.foundOf(player) or "no IndexService")
		elseif verb == "sub" then
			local t = SS:FindFirstChild("SubTest")
			-- the last word is the stamp, never an argument
			local x = if #a > 3 then tonumber(a[3]) or a[3] else nil
			local y = if #a > 4 then a[4] else nil
			return tostring(t and t:Invoke(a[2], player.UserId, x, y))
		end
		return "?"
	end)
	RS:SetAttribute("H4Said", tostring(said) .. "|" .. tostring(ok) .. "|" .. tostring(a[#a]))
end)
'''

CLIENT = r'''
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local ev = RS:WaitForChild("ZZH4Report")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local seen = {}
LogService.MessageOut:Connect(function(msg, kind)
	if kind == Enum.MessageType.MessageError or kind == Enum.MessageType.MessageWarning then
		local key = string.sub(msg, 1, 120)
		if not seen[key] then
			seen[key] = true
			ev:FireServer("log", string.gsub(string.sub(msg, 1, 300), "\n", " "))
		end
	end
end)
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Shared = RS:WaitForChild("Shared")
local function need(at, ...)
	local names = { ... }
	local ok, got = pcall(function()
		local o = at
		for _, n in names do
			o = o:WaitForChild(n, 10)
		end
		return require(o)
	end)
	if not ok then
		ev:FireServer("log", "H4 helper: no " .. table.concat(names, ".") .. ": " .. tostring(got))
		return nil
	end
	return got
end
local State = need(Client, "Lib", "State")
local Shop = need(Client, "UI", "Shop")
local IndexPanel = need(Client, "UI", "IndexPanel")
local Config = need(Shared, "Config")
local Net = need(Shared, "Net")
local Keepers = need(Shared, "Keepers")
-- what the server said about the Index since the last ask ("Denied:Dock", "Paid:number", ...)
local heard = {}
if Net and Net.Index then
	Net.Index.OnClientEvent:Connect(function(what, a)
		table.insert(heard, tostring(what) .. ":" .. (if type(a) == "string" then a else type(a)))
	end)
end

local function f(n)
	return string.format("%.2f", n)
end
local function v3(v)
	return string.format("%.2f,%.2f,%.2f", v.X, v.Y, v.Z)
end
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local function stations()
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	return dock and dock:FindFirstChild("Stations")
end
local function ringOf(name)
	local st = stations()
	local stall = st and st:FindFirstChild(name)
	local ring = stall and (stall:FindFirstChild("Ring") or (stall:IsA("Model") and stall.PrimaryPart))
	return if ring and ring:IsA("BasePart") then ring else nil
end
local function rootPart()
	local c = player.Character
	return c and c.PrimaryPart
end
-- half of a part's box along the world's axes
local function reach(cf, size)
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return Vector3.new(
		math.abs(r.X) * size.X + math.abs(u.X) * size.Y + math.abs(l.X) * size.Z,
		math.abs(r.Y) * size.X + math.abs(u.Y) * size.Y + math.abs(l.Y) * size.Z,
		math.abs(r.Z) * size.X + math.abs(u.Z) * size.Y + math.abs(l.Z) * size.Z
	) / 2
end
local function boxOf(part)
	local h = reach(part.CFrame, part.Size)
	return part.Position - h, part.Position + h
end
-- a station's floating name: where it stands, its lower edge, its width (nil: none)
local function nameOf(station)
	local title = station:FindFirstChild("Title", true)
	if not (title and title:IsA("BasePart")) then
		return nil
	end
	local board = title:FindFirstChildWhichIsA("BillboardGui")
	local mid, high, wide = title.Position.Y, 0, 0
	if board then
		mid += board.StudsOffset.Y + board.StudsOffsetWorldSpace.Y
		high, wide = board.Size.Y.Scale, board.Size.X.Scale
	end
	return title.Position, mid - high / 2, mid + high / 2, wide
end
local function shownAll(o, top)
	while o and o ~= top do
		if o:IsA("GuiObject") and not o.Visible then
			return false
		end
		if o:IsA("ScreenGui") and not o.Enabled then
			return false
		end
		o = o.Parent
	end
	return true
end

local V = {}

V.ping = function()
	return "pong mode=" .. tostring(State and State.Mode) .. " shop=" .. tostring(Shop ~= nil) .. " index=" .. tostring(IndexPanel ~= nil) .. " keepers=" .. tostring(Keepers ~= nil)
end

V.where = function()
	local o = {}
	local root = rootPart()
	table.insert(o, "me " .. (if root then v3(root.Position) else "none") .. " mode " .. tostring(State.Mode))
	local st = stations()
	if st then
		for _, s in st:GetChildren() do
			local ring = ringOf(s.Name)
			local counter = s:FindFirstChild("CounterTop", true) or s:FindFirstChild("Core", true) or s:FindFirstChild("Lamp", true)
			local at, lower, upper, wide = nameOf(s)
			table.insert(o, string.format("%s ring %s size %s %s shape %s counter %s name %s lower %s upper %s wide %s",
				s.Name, if ring then v3(ring.Position) else "none", if ring then v3(ring.Size) else "-",
				if ring then ring.ClassName else "-", if ring and ring:IsA("Part") then ring.Shape.Name else "-",
				if counter and counter:IsA("BasePart") then counter.Name .. " " .. v3(counter.Position) else "none",
				if at then v3(at) else "none", if lower then f(lower) else "-", if upper then f(upper) else "-", if wide then f(wide) else "-"))
		end
	end
	local remotes = RS:FindFirstChild("Remotes")
	local dock = remotes and remotes:GetAttribute("Dock")
	table.insert(o, "dock " .. (if typeof(dock) == "CFrame" then v3(dock.Position) else tostring(dock)))
	table.insert(o, "subnear " .. tostring(Config.Sub.Near))
	return table.concat(o, "; ")
end

-- walk|x|z|seconds: walks there as a player does, and says each change of the dock's window with how far the player
-- was from each ring's middle when it changed
V.walk = function(a)
	local x, z, limit = tonumber(a[1]), tonumber(a[2]), tonumber(a[3]) or 12
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootPart()
	if not hum or not root then
		return "no character"
	end
	local t0 = os.clock()
	local last = Shop.Page
	local events = {}
	local goal = Vector3.new(x, root.Position.Y, z)
	hum:MoveTo(goal)
	local asked = os.clock()
	while os.clock() - t0 < limit do
		local p = root.Position
		if Shop.Page ~= last then
			last = Shop.Page
			local d = {}
			for _, n in { "Sell", "Auras", "Sub", "Index" } do
				local ring = ringOf(n)
				if ring then
					table.insert(d, n .. "=" .. f((flat(p) - flat(ring.Position)).Magnitude))
				end
			end
			table.insert(events, string.format("[%.2fs page %s %s]", os.clock() - t0, tostring(last), table.concat(d, " ")))
		end
		if (flat(p) - Vector3.new(x, 0, z)).Magnitude < 0.7 then
			break
		end
		if os.clock() - asked > 5 then
			hum:MoveTo(goal)
			asked = os.clock()
		end
		RunService.Heartbeat:Wait()
	end
	return string.format("at %s after %.1fs page %s speed %s %s", v3(root.Position), os.clock() - t0, tostring(Shop.Page), f(hum.WalkSpeed), table.concat(events, " "))
end

-- tp|x|y|z[|fx|fz]: put there (facing fx, fz)
V.tp = function(a)
	local character = player.Character
	if not character then
		return "no character"
	end
	local at = Vector3.new(tonumber(a[1]), tonumber(a[2]), tonumber(a[3]))
	local cf = CFrame.new(at)
	if a[4] and a[5] then
		cf = CFrame.lookAt(at, Vector3.new(tonumber(a[4]), at.Y, tonumber(a[5])))
	end
	character:PivotTo(cf)
	local root = rootPart()
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	task.wait(0.3)
	return "at " .. v3(rootPart().Position)
end

V.ui = function()
	local o = {}
	table.insert(o, "mode=" .. tostring(State.Mode))
	table.insert(o, "page=" .. tostring(Shop.Page))
	for _, n in { "SellFish", "AuraShop", "SubShop", "ShopScreen", "IndexPanel" } do
		local s = gui:FindFirstChild(n)
		local open = "none"
		if s then
			open = "shut"
			for _, d in s:GetChildren() do
				if d:IsA("GuiObject") and d.Visible and s.Enabled and d.AbsoluteSize.X > 200 then
					open = "open"
				end
			end
		end
		table.insert(o, n .. "=" .. open)
	end
	table.insert(o, "indexOpen=" .. tostring(IndexPanel and IndexPanel.isOpen()))
	table.insert(o, "waiting=" .. tostring(IndexPanel and IndexPanel.waiting()))
	local prompts, near = 0, {}
	local root = rootPart()
	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			prompts += 1
			local part = d.Parent
			if d.Enabled and root and part and part:IsA("BasePart") and (part.Position - root.Position).Magnitude < 60 then
				table.insert(near, d:GetFullName())
			end
		end
	end
	table.insert(o, "prompts=" .. prompts .. " near=" .. #near .. " " .. table.concat(near, ","))
	local hud = gui:FindFirstChild("RideHud")
	local buttons = hud and hud:FindFirstChild("HubButtons", true)
	if buttons then
		for _, d in buttons:GetDescendants() do
			if d.Name == "Mark" and d:IsA("GuiObject") then
				table.insert(o, "mark:" .. d.Parent.Name .. "=" .. tostring(d.Visible) .. "/" .. tostring(shownAll(d, hud)))
			end
		end
	else
		table.insert(o, "mark:none")
	end
	for _, n in { "IndexFound", "IndexClaims", "MaxOxygen", "SubEquip", "SubTier", "TankRide" } do
		table.insert(o, n .. "=" .. tostring(player:GetAttribute(n)))
	end
	return table.concat(o, " ")
end

-- the older Studio checks' door into the sub shop (SubPanel.toggle), as they call it
V.subtoggle = function(a)
	local SubPanel = need(Client, "UI", "SubPanel")
	SubPanel.toggle(a[1] == "on")
	task.wait(0.7)
	return V.ui()
end
V.heard = function()
	local text = table.concat(heard, ",")
	table.clear(heard)
	return "heard=" .. text
end
V.go = function(a)
	Shop.go(if a[1] and a[1] ~= "" then a[1] else nil)
	task.wait(0.6)
	return V.ui()
end
-- the hub's Index button, as HubButtons' own listener does it
V.indexbutton = function()
	if Config.Index.On ~= 0 then
		Shop.go(if Shop.Page == "Index" then nil else "Index")
	end
	task.wait(0.7)
	return V.ui()
end
V.index = function(a)
	IndexPanel.press(a[1], tonumber(a[2]) or a[2])
	task.wait(tonumber(a[3]) or 0.6)
	return V.ui()
end
V.net = function(a)
	Net.Index:FireServer(a[1], tonumber(a[2]) or a[2])
	task.wait(0.5)
	return V.ui()
end
V.action = function(a)
	Net.Action:FireServer(a[1], tonumber(a[2]) or a[2])
	task.wait(0.6)
	return V.ui()
end

-- the ring's look (the place's HubLife fills it in while stood on)
V.ring = function(a)
	local ring = ringOf(a[1])
	if not ring then
		return "no ring"
	end
	local o = { string.format("ring see-through %.2f colour %d,%d,%d %s", ring.Transparency, ring.Color.R * 255, ring.Color.G * 255, ring.Color.B * 255, ring.Material.Name) }
	local circle = ring:FindFirstChild("Circle")
	local fill = circle and circle:FindFirstChild("Fill")
	table.insert(o, "fill=" .. (if fill then string.format("%.2f", fill.BackgroundTransparency) else "none"))
	table.insert(o, "tagged=" .. tostring(game:GetService("CollectionService"):HasTag(ring, "HubRing")))
	for _, d in ring.Parent:GetChildren() do
		if d:IsA("BasePart") and d ~= ring and (flat(d.Position) - flat(ring.Position)).Magnitude < 1 and math.abs(d.Position.Y - ring.Position.Y) < 2 then
			table.insert(o, string.format("%s see-through %.2f colour %d,%d,%d size %s", d.Name, d.Transparency, d.Color.R * 255, d.Color.G * 255, d.Color.B * 255, v3(d.Size)))
		end
	end
	return table.concat(o, "; ")
end

-- the Index window: its cards, its bars and words
V.indexui = function()
	local s = gui:FindFirstChild("IndexPanel")
	if not s then
		return "no IndexPanel gui"
	end
	local o = { "open=" .. tostring(IndexPanel.isOpen()) }
	local list = s:FindFirstChild("List", true)
	if list then
		local cards, found, dark = 0, {}, 0
		for _, c in list:GetChildren() do
			if c:IsA("Frame") then
				cards += 1
				local name = c:FindFirstChild("Name", true)
				if name and name:IsA("TextLabel") and name.Text ~= "???" then
					table.insert(found, c.Name)
				else
					dark += 1
				end
			end
		end
		table.insert(o, string.format("cards=%d dark=%d found=%s", cards, dark, table.concat(found, ",")))
		if list:IsA("ScrollingFrame") then
			table.insert(o, string.format("canvas=%.0f window=%.0f bar=%d scrolls=%s", list.AbsoluteCanvasSize.Y, list.AbsoluteWindowSize.Y, list.ScrollBarThickness, tostring(list.AbsoluteCanvasSize.Y > list.AbsoluteWindowSize.Y + 1)))
		else
			local sf = list:FindFirstAncestorWhichIsA("ScrollingFrame")
			if sf then
				table.insert(o, string.format("canvas=%.0f window=%.0f bar=%d scrolls=%s", sf.AbsoluteCanvasSize.Y, sf.AbsoluteWindowSize.Y, sf.ScrollBarThickness, tostring(sf.AbsoluteCanvasSize.Y > sf.AbsoluteWindowSize.Y + 1)))
			end
		end
	end
	local toast = s:FindFirstChild("Toast", true)
	if toast then
		local word = toast:FindFirstChildWhichIsA("TextLabel", true)
		local fill = toast:FindFirstChildWhichIsA("UIGradient", true)
		local c = fill and fill.Color.Keypoints[1].Value
		table.insert(o, string.format("toast=%s '%s' colour %s", tostring(toast.Visible), if word then word.Text else "", if c then string.format("%d,%d,%d", c.R * 255, c.G * 255, c.B * 255) else "-"))
	end
	for _, n in { "LandSet", "Found", "Kind" } do
		local at = s:FindFirstChild(n, true)
		if at then
			local words = {}
			for _, d in at:GetDescendants() do
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and shownAll(d, s) then
					table.insert(words, d.Name .. ":" .. string.gsub(d.Text, "[\n;]", " "))
				end
			end
			table.insert(o, n .. "{" .. table.concat(words, ", ") .. "}")
		end
	end
	local all = s:FindFirstChild("ClaimAll", true)
	if all then
		local t = all:FindFirstChildWhichIsA("TextLabel", true)
		table.insert(o, "claimAll='" .. (if all:IsA("TextButton") then all.Text else if t then t.Text else "") .. "'")
	end
	return table.concat(o, " ; ")
end

-- card|FishId: what one card's picture is made of
V.card = function(a)
	local s = gui:FindFirstChild("IndexPanel")
	local list = s and s:FindFirstChild("List", true)
	local card = list and list:FindFirstChild(a[1])
	if not card then
		return "no card " .. tostring(a[1])
	end
	local name = card:FindFirstChild("Name", true)
	local o = { string.format("card %s name '%s' back %d,%d,%d", a[1], if name then name.Text else "?", card.BackgroundColor3.R * 255, card.BackgroundColor3.G * 255, card.BackgroundColor3.B * 255) }
	local stroke = card:FindFirstChildWhichIsA("UIStroke")
	if stroke then
		table.insert(o, string.format("edge %d,%d,%d thick %.1f", stroke.Color.R * 255, stroke.Color.G * 255, stroke.Color.B * 255, stroke.Thickness))
	end
	local images, black, loaded, views, models = 0, 0, 0, 0, 0
	local sample = {}
	for _, d in card:GetDescendants() do
		if d:IsA("ImageLabel") and d.Image ~= "" then
			images += 1
			local c = d.ImageColor3
			if c.R + c.G + c.B < 0.2 then
				black += 1
			end
			if d.IsLoaded then
				loaded += 1
			end
			if #sample < 3 then
				table.insert(sample, string.format("%s z%d %s col %d,%d,%d see %.2f", d.Name, d.ZIndex, string.sub(d.Image, -14), c.R * 255, c.G * 255, c.B * 255, d.ImageTransparency))
			end
		elseif d:IsA("ViewportFrame") then
			views += 1
			local c = d.ImageColor3
			if c.R + c.G + c.B < 0.2 then
				black += 1
			end
			for _, m in d:GetDescendants() do
				if m:IsA("Model") then
					models += 1
				end
			end
		end
	end
	table.insert(o, string.format("images %d (dark-tinted %d, loaded %d) viewports %d models %d", images, black, loaded, views, models))
	table.insert(o, table.concat(sample, " / "))
	return table.concat(o, "; ")
end

-- sub|seconds: the little sub over the stand, measured for that long
V.sub = function(a)
	local seconds = tonumber(a[1]) or 3.4
	local cam = workspace.CurrentCamera
	local m = cam and cam:FindFirstChild("StandSub")
	if not m then
		return "no StandSub"
	end
	local st = stations()
	local stand = st and st:FindFirstChild("Sub")
	if not stand then
		return "no stand"
	end
	local parts, meshes, bad, spins = {}, 0, {}, {}
	local boards, lights = 0, 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			if d:IsA("MeshPart") then
				meshes += 1
			end
			if d.CanCollide or d.CanQuery or d.CanTouch or d.CastShadow or not d.Anchored then
				table.insert(bad, d.Name)
			end
			if d.Name == "Prop" or d.Name == "Prop_Glow" then
				table.insert(spins, d)
			end
		elseif d:IsA("BillboardGui") then
			boards += 1
		elseif d:IsA("Light") then
			lights += 1
		end
	end
	-- the stand, as SubStandController measures it
	local roof = -math.huge
	for _, d in stand:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Ring" and d.Name ~= "Title" and d.Transparency < 0.95 then
			local _, hi = boxOf(d)
			roof = math.max(roof, hi.Y)
		end
	end
	local at, lower = nameOf(stand)
	local hull = nil
	for _, p in parts do
		if p.Name ~= "Prop" and p.Name ~= "Prop_Glow" and (not hull or p.Size.Magnitude > hull.Size.Magnitude) then
			hull = p
		end
	end
	local low, high = math.huge, -math.huge
	local midLow, midHigh = math.huge, -math.huge
	local round = 0
	local centre = Vector3.zero
	local n = 0
	local turned, last = 0, nil
	local spun, lastSpin = 0, nil
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		local lo, hi = Vector3.one * math.huge, Vector3.one * -math.huge
		for _, p in parts do
			local a1, b1 = boxOf(p)
			lo, hi = lo:Min(a1), hi:Max(b1)
		end
		local mid = (lo + hi) / 2
		low, high = math.min(low, lo.Y), math.max(high, hi.Y)
		midLow, midHigh = math.min(midLow, mid.Y), math.max(midHigh, mid.Y)
		centre += mid
		n += 1
		if at then
			for _, p in parts do
				-- its real corners (a turned part's upright box reaches further than the part does)
				local h = p.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local corner = p.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
							round = math.max(round, (flat(corner) - flat(at)).Magnitude)
						end
					end
				end
			end
		end
		if hull then
			local look = hull.CFrame.LookVector
			local yaw = math.atan2(look.X, look.Z)
			if last then
				local d = (yaw - last + math.pi) % (2 * math.pi) - math.pi
				turned += d
			end
			last = yaw
			if spins[1] then
				local rel = hull.CFrame:ToObjectSpace(spins[1].CFrame)
				local up = rel.UpVector
				local ang = math.atan2(up.X, up.Y)
				if lastSpin then
					spun += math.abs((ang - lastSpin + math.pi) % (2 * math.pi) - math.pi)
				end
				lastSpin = ang
			end
		end
		RunService.RenderStepped:Wait()
	end
	local took = os.clock() - t0
	centre /= math.max(n, 1)
	local eye = cam.CFrame.Position
	return string.format(
		"tier=%s parts=%d meshes=%d props=%d boards=%d lights=%d touching=%d(%s) roof=%.2f low=%.2f high=%.2f nameLower=%s clearOverRoof=%.2f underName=%s bob=%.2f round=%.2f offCentre=%.2f turn=%.1f spin=%.2f frames=%d fromCamera=%.0f hull=%s",
		tostring(player:GetAttribute("SubEquip")), #parts, meshes, #spins, boards, lights, #bad, table.concat(bad, ","), roof, low, high,
		if lower then f(lower) else "none", low - roof, if lower then f(lower - high) else "-", (midHigh - midLow) / 2, round,
		if at then (flat(centre) - flat(at)).Magnitude else -1, math.deg(turned) / took, spun / took, n, (eye - centre).Magnitude, if hull then hull.Name else "none")
end

-- every keeper: is it there, how many parts, its size, where it stands
local function keeperFrame(keeper, model)
	local rootRow, headRow
	for _, row in keeper.Parts do
		if row[1] == "Root" and not rootRow then
			rootRow = row
		elseif row[1] == "Head" and not headRow then
			headRow = row
		end
	end
	local kids = model:GetChildren()
	local scale = kids[1].Size.X / keeper.Parts[1][3]
	local rootPart1, headPart
	for i, row in keeper.Parts do
		if row == rootRow then
			rootPart1 = kids[i]
		elseif row == headRow then
			headPart = kids[i]
		end
	end
	local joints = Keepers.joints(keeper, scale, nil, 0, 0, 0)
	local root = rootPart1.CFrame * (joints.Root * Keepers.offset(keeper, rootRow, scale)):Inverse()
	local rest = (joints.Head * Keepers.offset(keeper, headRow, scale)).Rotation
	return root, headPart, rest, scale, Keepers.pivots(keeper).Head * scale
end

V.klist = function()
	local folder = workspace:FindFirstChild("Keepers")
	if not folder then
		return "no Keepers folder"
	end
	local o = {}
	local total, moving = 0, 0
	for _, keeper in Keepers.List do
		local model = folder:FindFirstChild(keeper.Id)
		if not model then
			table.insert(o, keeper.Id .. " MISSING at " .. keeper.Station)
			continue
		end
		local kids = model:GetChildren()
		local props, bad, lights = 0, 0, 0
		local lo, hi = Vector3.one * math.huge, Vector3.one * -math.huge
		local propHigh = -math.huge
		for _, p in kids do
			if p:IsA("BasePart") then
				total += 1
				local a1, b1 = boxOf(p)
				if p.Name == "Prop" then
					props += 1
					propHigh = math.max(propHigh, b1.Y)
				else
					lo, hi = lo:Min(a1), hi:Max(b1)
					if p.Name ~= "Root" then
						moving += 1
					end
				end
				if p.CanCollide or p.CanQuery or p.CanTouch or p.CastShadow or not p.Anchored then
					bad += 1
				end
				if p:FindFirstChildWhichIsA("Light") then
					lights += 1
				end
			end
		end
		local root, _, _, scale = keeperFrame(keeper, model)
		local ring = ringOf(keeper.Station)
		local floor = if ring then ring.Position.Y - reach(ring.CFrame, ring.Size).Y else 0
		local ahead = if ring then flat(ring.Position) - flat(root.Position) else Vector3.zAxis
		-- the stand's own front: from its counter (or the Fuse machine's core) to its ring. A keeper is square to
		-- that; the Fuse keeper stands beside the machine, so its ring is off to one side of straight ahead
		local st = stations()
		local stall = st and st:FindFirstChild(keeper.Station)
		local anchor = stall and stall:FindFirstChild(keeper.Stand, true)
		local front = if ring and anchor and anchor:IsA("BasePart") then flat(ring.Position) - flat(anchor.Position) else ahead
		local face = flat(root.ZVector).Unit
		local facing = math.deg(math.acos(math.clamp(face:Dot(front.Unit), -1, 1)))
		local toRing = math.deg(math.acos(math.clamp(face:Dot(ahead.Unit), -1, 1)))
		local headAct = 0
		for _, track in keeper.Action.Tracks do
			if track[1] == "Head" then
				for i = 2, #track do
					headAct = math.max(headAct, math.abs(track[i][2]), math.abs(track[i][3]), math.abs(track[i][4]))
				end
			end
		end
		table.insert(o, string.format("%s at %s: parts %d (data %d) props %d (data %d) scale %.2f feet %.2f over the floor, top %.2f over it, props' top %.2f, square to its stand within %.1f deg, its ring %.1f deg off straight ahead and %.1f studs off, touching %d, lights %d, root %s face %.3f,%.3f headact %.1f",
			keeper.Id, keeper.Station, #kids - props, #keeper.Parts, props, #keeper.Props, scale, lo.Y - floor, hi.Y - floor, propHigh - floor, facing, toRing, ahead.Magnitude, bad, lights, v3(root.Position), face.X, face.Z, headAct))
	end
	table.insert(o, string.format("all %d parts, %d moving", total, moving))
	return table.concat(o, " ; ")
end

-- ksample|Id|seconds: one keeper, every frame for that long: where its head points against where the player is,
-- its bob and its action. A row is t, the head's yaw, the yaw asked (held to the limit), the head's pitch, the pitch
-- asked, how far the player's head is from its neck, how far round, the body's height, the action joints' move.
V.ksample = function(a)
	local folder = workspace:FindFirstChild("Keepers")
	local keeper
	for _, k in Keepers.List do
		if k.Id == a[1] then
			keeper = k
		end
	end
	local model = folder and keeper and folder:FindFirstChild(keeper.Id)
	if not model then
		return "no keeper " .. tostring(a[1])
	end
	local seconds = tonumber(a[2]) or 6
	local root, headPart, rest, scale, neck = keeperFrame(keeper, model)
	local L = Keepers.Look
	local limit = L.Body + L.Head
	local body
	local acts = {}
	local names = {}
	for _, track in keeper.Action.Tracks do
		names[track[1]] = true
	end
	for _, p in model:GetChildren() do
		if p.Name == "Body" and not body then
			body = p
		end
		if names[p.Name] then
			table.insert(acts, p)
		end
	end
	local rows = {}
	local t0 = os.clock()
	local lastYaw, lastT = nil, t0
	local maxStep, maxRate, frames, longest = 0, 0, 0, 0
	local body0 = body and body.Position.Y or 0
	local bodyLow, bodyHigh = math.huge, -math.huge
	local act0 = {}
	for i, p in acts do
		act0[i] = body.CFrame:PointToObjectSpace(p.Position)
	end
	local nextRow = 0
	while os.clock() - t0 < seconds do
		local now = os.clock()
		local look = root.Rotation:Inverse() * headPart.CFrame.Rotation * rest:Inverse()
		local dir = look * Vector3.zAxis
		local yaw = math.deg(math.atan2(dir.X, dir.Z))
		local pitch = math.deg(math.asin(math.clamp(-dir.Y, -1, 1)))
		local ch = player.Character
		local head = ch and (ch:FindFirstChild("Head") or ch.PrimaryPart)
		local far, round, askYaw, askPitch = -1, -1, 0, 0
		if head then
			local at = root:PointToObjectSpace(head.Position) - neck
			far = at.Magnitude
			round = math.abs(math.deg(math.atan2(at.X, at.Z)))
			local y, p = Keepers.aim(at)
			askYaw = math.clamp(y, -limit, limit)
			askPitch = math.clamp(p, -L.Up, L.Down)
		end
		if lastYaw then
			local step = math.abs(yaw - lastYaw)
			maxStep = math.max(maxStep, step)
			if now > lastT then
				maxRate = math.max(maxRate, step / (now - lastT))
			end
			longest = math.max(longest, now - lastT)
		end
		lastYaw, lastT = yaw, now
		frames += 1
		local by = body and body.Position.Y - body0 or 0
		bodyLow, bodyHigh = math.min(bodyLow, by), math.max(bodyHigh, by)
		local moved = 0
		for i, p in acts do
			moved = math.max(moved, (body.CFrame:PointToObjectSpace(p.Position) - act0[i]).Magnitude)
		end
		if now - t0 >= nextRow then
			nextRow += 0.05
			table.insert(rows, string.format("%.2f,%.1f,%.1f,%.1f,%.1f,%.1f,%.0f,%.2f,%.2f", now - t0, yaw, askYaw, pitch, askPitch, far, round, by, moved))
		end
		RunService.RenderStepped:Wait()
	end
	return string.format("frames=%d longest=%.3f maxStep=%.2f maxRate=%.0f bob=%.3f scale=%.2f near=%s far=%s limit=%s time=%s every=%s-%s act=%s rows=%s",
		frames, longest, maxStep, maxRate, (bodyHigh - bodyLow) / 2, scale, tostring(L.Near), tostring(L.Far), tostring(limit), tostring(L.Time),
		tostring(keeper.Action.Every[1]), tostring(keeper.Action.Every[2]), tostring(keeper.Action.Time), table.concat(rows, " "))
end

-- props: every keeper's and prop's box against the rings, the names, the walking lines, the place's own parts and the
-- stand's sub
V.props = function()
	local folder = workspace:FindFirstChild("Keepers")
	local st = stations()
	if not folder or not st then
		return "no keepers or no stations"
	end
	local remotes = RS:FindFirstChild("Remotes")
	local dock = remotes and remotes:GetAttribute("Dock")
	local spawnAt = if typeof(dock) == "CFrame" then dock.Position else nil
	local rings = {}
	for _, s in st:GetChildren() do
		local ring = ringOf(s.Name)
		if ring then
			local h = reach(ring.CFrame, ring.Size)
			local at, lower, upper, wide = nameOf(s)
			table.insert(rings, { Name = s.Name, At = ring.Position, Radius = math.max(h.X, h.Z), Floor = ring.Position.Y - h.Y, Title = at, Lower = lower, Upper = upper, Wide = wide })
		end
	end
	-- every part of the place a player can see within 60 studs of a stand (whether or not it answers a query)
	local place = {}
	local unseen = 0
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and not d:IsA("Terrain") and not d:IsDescendantOf(folder)
			and not (player.Character and d:IsDescendantOf(player.Character))
			and not (workspace.CurrentCamera and d:IsDescendantOf(workspace.CurrentCamera)) then
			local close = false
			for _, r in rings do
				if (d.Position - r.At).Magnitude < 60 + d.Size.Magnitude / 2 then
					close = true
				end
			end
			if close then
				if d.Transparency >= 1 then
					unseen += 1
				else
					table.insert(place, d)
				end
			end
		end
	end
	-- how deep two turned boxes are in each other (the least push that parts them), nil when they are apart
	local function inside(ca, ha, cb, hb)
		local A = { ca.RightVector, ca.UpVector, ca.LookVector }
		local B = { cb.RightVector, cb.UpVector, cb.LookVector }
		local HA, HB = { ha.X, ha.Y, ha.Z }, { hb.X, hb.Y, hb.Z }
		local t = cb.Position - ca.Position
		local least = math.huge
		local function try(L)
			if L.Magnitude < 1e-4 then
				return true
			end
			L = L.Unit
			local ra, rb = 0, 0
			for i = 1, 3 do
				ra += math.abs(A[i]:Dot(L)) * HA[i]
				rb += math.abs(B[i]:Dot(L)) * HB[i]
			end
			local over = ra + rb - math.abs(t:Dot(L))
			if over <= 0 then
				return false
			end
			least = math.min(least, over)
			return true
		end
		for i = 1, 3 do
			if not try(A[i]) or not try(B[i]) then
				return nil
			end
		end
		for i = 1, 3 do
			for k = 1, 3 do
				if not try(A[i]:Cross(B[k])) then
					return nil
				end
			end
		end
		return least
	end
	local cam = workspace.CurrentCamera
	local sub = cam and cam:FindFirstChild("StandSub")
	local o = {}
	for _, keeper in Keepers.List do
		local model = folder:FindFirstChild(keeper.Id)
		if not model then
			table.insert(o, keeper.Id .. " MISSING")
			continue
		end
		local ringGap, ringWho = math.huge, ""
		local nameGap, nameWho = math.huge, ""
		local pathGap, pathWho = math.huge, ""
		local hits = {}
		local hitCount = 0
		for _, p in model:GetChildren() do
			if not p:IsA("BasePart") then
				continue
			end
			local lo, hi = boxOf(p)
			local mid = (lo + hi) / 2
			local half = (hi - lo) / 2
			for _, r in rings do
				-- the ring's circle on the floor: the nearest point of the part's box to the ring's middle
				if lo.Y < r.Floor + 7 then
					local nx = math.clamp(r.At.X, lo.X, hi.X)
					local nz = math.clamp(r.At.Z, lo.Z, hi.Z)
					local gap = math.sqrt((nx - r.At.X) ^ 2 + (nz - r.At.Z) ^ 2) - r.Radius
					if gap < ringGap then
						ringGap, ringWho = gap, p.Name .. " at " .. r.Name
					end
				end
				-- the floating name: under its lower edge, or outside its width
				if r.Title and r.Lower then
					local nx = math.clamp(r.Title.X, lo.X, hi.X)
					local nz = math.clamp(r.Title.Z, lo.Z, hi.Z)
					local side = math.sqrt((nx - r.Title.X) ^ 2 + (nz - r.Title.Z) ^ 2)
					if side < r.Wide / 2 then
						local gap = r.Lower - hi.Y
						if gap < nameGap then
							nameGap, nameWho = gap, p.Name .. " under " .. r.Name
						end
					end
				end
				-- the walking line from the dock's spawn to the ring's middle
				if spawnAt and lo.Y < r.Floor + 6 then
					local a1, b1 = flat(spawnAt), flat(r.At)
					local ab = b1 - a1
					local t = math.clamp((flat(mid) - a1):Dot(ab) / ab:Dot(ab), 0, 1)
					local gap = (flat(mid) - (a1 + ab * t)).Magnitude - math.sqrt(half.X ^ 2 + half.Z ^ 2)
					if gap < pathGap then
						pathGap, pathWho = gap, p.Name .. " on the way to " .. r.Name
					end
				end
			end
			-- the place's own parts this one is inside of: how deep the two boxes are in each other (0.1 or less is
			-- touching). Sums over the boxes as they are turned, not a query: most of a stall answers none
			local reachP = p.Size.Magnitude / 2
			for _, hit in place do
				if (hit.Position - p.Position).Magnitude > reachP + hit.Size.Magnitude / 2 then
					continue
				end
				local deep = inside(p.CFrame, p.Size / 2, hit.CFrame, hit.Size / 2)
				if not deep or deep <= 0.1 then
					continue
				end
				local where = hit.Name
				local up = hit.Parent
				local steps = 0
				while up and up ~= workspace and steps < 3 do
					where = up.Name .. "." .. where
					up = up.Parent
					steps += 1
				end
				hitCount += 1
				local key = p.Name .. " in " .. where
				if not hits[key] or deep > hits[key] then
					hits[key] = deep
				end
			end
		end
		local list = {}
		for key, deep in hits do
			table.insert(list, { key, deep })
		end
		table.sort(list, function(x, y)
			return x[2] > y[2]
		end)
		local worst = {}
		for i = 1, math.min(#list, 8) do
			table.insert(worst, string.format("%s %.2f", list[i][1], list[i][2]))
		end
		table.insert(o, string.format("%s: ring gap %.2f (%s); under name %.2f (%s); walking line %.2f (%s); against %d parts of the place (%d unseen ones left out); inside place parts %d kinds %d: %s",
			keeper.Id, ringGap, ringWho, nameGap, nameWho, pathGap, pathWho, #place, unseen, hitCount, #list, table.concat(worst, " | ")))
	end
	if sub then
		local low, mid = math.huge, Vector3.zero
		local n = 0
		for _, p in sub:GetDescendants() do
			if p:IsA("BasePart") then
				local lo = boxOf(p)
				low = math.min(low, lo.Y)
				mid += p.Position
				n += 1
			end
		end
		mid /= math.max(n, 1)
		local top, who = -math.huge, ""
		for _, model in folder:GetChildren() do
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and (flat(p.Position) - flat(mid)).Magnitude < 8 then
					local _, hi = boxOf(p)
					if hi.Y > top then
						top, who = hi.Y, model.Name .. "." .. p.Name
					end
				end
			end
		end
		table.insert(o, string.format("stand sub: lowest %.2f, the highest keeper piece within 8 studs of it %.2f (%s), gap %.2f", low, top, who, low - top))
	end
	return table.concat(o, " ; ")
end

-- cam|x|y|z[|down]: turns the dock's own camera (Roblox's, never replaced) to look past the player toward that point,
-- tipped `down` degrees; one write of its CFrame, as a drag of the mouse leaves it
V.cam = function(a)
	local cam = workspace.CurrentCamera
	if cam.CameraType ~= Enum.CameraType.Custom then
		return "camera is " .. cam.CameraType.Name .. ": left alone"
	end
	local target = Vector3.new(tonumber(a[1]), tonumber(a[2]), tonumber(a[3]))
	local focus = cam.Focus.Position
	local dist = (cam.CFrame.Position - focus).Magnitude
	local dir = flat(target - focus)
	if dir.Magnitude < 0.01 then
		return "too close"
	end
	dir = dir.Unit
	local down = math.rad(tonumber(a[4]) or 20)
	local look = (dir * math.cos(down) - Vector3.yAxis * math.sin(down)).Unit
	cam.CFrame = CFrame.lookAt(focus - look * dist, focus)
	task.wait(0.4)
	local l = cam.CFrame.LookVector
	return string.format("type %s at %s look %s back %.1f fov %.0f view %dx%d", cam.CameraType.Name, v3(cam.CFrame.Position), v3(l), (cam.CFrame.Position - cam.Focus.Position).Magnitude, cam.FieldOfView, cam.ViewportSize.X, cam.ViewportSize.Y)
end
-- screen|x|y|z: where that point of the world is in the game's view, in pixels (and whether it is in front)
V.screen = function(a)
	local cam = workspace.CurrentCamera
	local at, on = cam:WorldToViewportPoint(Vector3.new(tonumber(a[1]), tonumber(a[2]), tonumber(a[3])))
	return string.format("%d,%d %s view %dx%d", at.X, at.Y, tostring(on), cam.ViewportSize.X, cam.ViewportSize.Y)
end
V.camread = function()
	local cam = workspace.CurrentCamera
	return string.format("type %s at %s look %s back %.1f fov %.0f view %dx%d", cam.CameraType.Name, v3(cam.CFrame.Position), v3(cam.CFrame.LookVector), (cam.CFrame.Position - cam.Focus.Position).Magnitude, cam.FieldOfView, cam.ViewportSize.X, cam.ViewportSize.Y)
end

V.flash = function(a)
	local old = gui:FindFirstChild("ZZH4Flash")
	if old then
		old:Destroy()
	end
	if a[1] == "on" then
		local s = Instance.new("ScreenGui")
		s.Name = "ZZH4Flash"
		s.DisplayOrder = 9999
		s.IgnoreGuiInset = true
		s.ResetOnSpawn = false
		local fr = Instance.new("Frame")
		fr.Size = UDim2.fromScale(1, 1)
		fr.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
		fr.BorderSizePixel = 0
		fr.Parent = s
		s.Parent = gui
	end
	return "flash " .. tostring(a[1])
end

V.phone = function(a)
	local w, h = tonumber(a[1]), tonumber(a[2])
	workspace:SetAttribute("PanelPhone", if w and h then Vector2.new(w, h) else nil)
	workspace:SetAttribute("HudTouch", if w and h then true else nil)
	task.wait(0.8)
	return "phone " .. tostring(workspace:GetAttribute("PanelPhone"))
end

-- box|GuiName: where a window is on the screen, and how small and how cut its words are
V.box = function(a)
	local s = gui:FindFirstChild(a[1])
	if not s then
		return "no gui " .. tostring(a[1])
	end
	local cam = workspace.CurrentCamera
	local o = { string.format("view %dx%d", cam.ViewportSize.X, cam.ViewportSize.Y) }
	-- the screen the window is laid out for: the top frame that holds the X (the whole view, or the phone's box);
	-- the window: everything shown in it that draws something, but for what a scrolling list clips
	local screen
	for _, d in s:GetDescendants() do
		if d:IsA("GuiObject") and d.Name == "Close" and shownAll(d, s) then
			local w = d
			while w.Parent and w.Parent ~= s do
				w = w.Parent
			end
			screen = w
			table.insert(o, string.format("x at %d,%d size %dx%d", d.AbsolutePosition.X, d.AbsolutePosition.Y, d.AbsoluteSize.X, d.AbsoluteSize.Y))
		end
	end
	if not screen then
		return table.concat(o, "; ") .. "; no window"
	end
	local lo, hi = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
	local out = {}
	local slo, shi = screen.AbsolutePosition, screen.AbsolutePosition + screen.AbsoluteSize
	for _, d in screen:GetDescendants() do
		if d:IsA("GuiObject") and shownAll(d, s) and d.AbsoluteSize.X > 0 and d.AbsoluteSize.Y > 0 then
			local draws = d.BackgroundTransparency < 1
				or ((d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.TextTransparency < 1)
				or ((d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" and d.ImageTransparency < 1)
			local clipped = false
			local up = d.Parent
			while up and up ~= screen do
				if up:IsA("ScrollingFrame") or (up:IsA("GuiObject") and up.ClipsDescendants) then
					clipped = true
				end
				up = up.Parent
			end
			if draws and not clipped then
				local a1, b1 = d.AbsolutePosition, d.AbsolutePosition + d.AbsoluteSize
				lo, hi = lo:Min(a1), hi:Max(b1)
				if (a1.X < slo.X - 1 or a1.Y < slo.Y - 1 or b1.X > shi.X + 1 or b1.Y > shi.Y + 1) and #out < 6 then
					table.insert(out, d.Name)
				end
			end
		end
	end
	table.insert(o, string.format("screen %d,%d to %d,%d", slo.X, slo.Y, shi.X, shi.Y))
	table.insert(o, string.format("window %d,%d to %d,%d outside %d: %s", lo.X, lo.Y, hi.X, hi.Y, #out, table.concat(out, ",")))
	local least, leastWho = math.huge, ""
	local cut = {}
	local words = 0
	for _, d in s:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and shownAll(d, s) and d.TextTransparency < 1 then
			words += 1
			local high = d.TextBounds.Y
			if high > 0 and high < least then
				least, leastWho = high, d.Name .. " '" .. string.sub(d.Text, 1, 18) .. "'"
			end
			if not d.TextFits and #cut < 8 then
				table.insert(cut, d.Name .. " '" .. string.sub(d.Text, 1, 18) .. "'")
			end
		end
	end
	table.insert(o, string.format("words %d smallest %.1f px (%s) not fitting %d: %s", words, least, leastWho, #cut, table.concat(cut, ", ")))
	local hud = gui:FindFirstChild("RideHud")
	local buttons = hud and hud:FindFirstChild("HubButtons", true)
	if buttons and buttons:IsA("GuiObject") then
		table.insert(o, string.format("hub buttons %d,%d to %d,%d", buttons.AbsolutePosition.X, buttons.AbsolutePosition.Y, buttons.AbsolutePosition.X + buttons.AbsoluteSize.X, buttons.AbsolutePosition.Y + buttons.AbsoluteSize.Y))
	end
	return table.concat(o, "; ")
end

workspace:GetAttributeChangedSignal("H4Do"):Connect(function()
	local cmd = workspace:GetAttribute("H4Do")
	if type(cmd) ~= "string" then
		return
	end
	local a = string.split(cmd, "|")
	local stamp = table.remove(a)
	local verb = table.remove(a, 1)
	local fn = V[verb]
	local ok, said = pcall(function()
		return if fn then fn(a) else "no verb " .. tostring(verb)
	end)
	ev:FireServer("ans", stamp .. "|" .. (if ok then "" else "ERROR ") .. string.gsub(tostring(said), "\n", " "))
end)
ev:FireServer("log", "H4 helper up")
'''


def edit(code, timeout=120):
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(code)
    return fc.run([f.name], timeout=timeout)


def install(remove=False):
    return edit(f"""local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer").StarterPlayerScripts
for _, at in {{ sss, sps }} do
	local old = at:FindFirstChild("ZZH4Helper")
	if old then old:Destroy() end
end
for _, k in {{ "H4Do", "PanelPhone", "HudTouch" }} do
	workspace:SetAttribute(k, nil)
end
if {fc.lua(remove)} then return "removed" end
local s = Instance.new("Script")
s.Name = "ZZH4Helper"
s.Source = {fc.lua(SERVER)}
s.Parent = sss
local l = Instance.new("LocalScript")
l.Name = "ZZH4Helper"
l.Source = {fc.lua(CLIENT)}
l.Parent = sps
return "installed " .. #s.Source .. " " .. #l.Source
""")


def mine():
    """Whether the playtest that is running holds the helper as it is in this file (a Play somebody else started
    holds an older one, or none: then it is theirs, and not to be driven)."""
    got = fc.server("local a = game:GetService('ServerScriptService'):FindFirstChild('ZZH4Helper') "
                    "local b = game:GetService('StarterPlayer').StarterPlayerScripts:FindFirstChild('ZZH4Helper') "
                    "return (a and #a.Source or -1) .. ' ' .. (b and #b.Source or -1)")
    want = f"{len(SERVER)} {len(CLIENT)}"
    try:
        have = [int(n) for n in got.strip().splitlines()[-1].split()]
    except ValueError:
        return False, got, want
    # Studio keeps the source one character shorter than it was given (the first line break), so one either way passes
    same = len(have) == 2 and abs(have[0] - len(SERVER)) <= 1 and abs(have[1] - len(CLIENT)) <= 1
    return same, got, want


LOG = []


def note(text):
    LOG.append(str(text))
    print(text, flush=True)


def save_log(name="log"):
    with open(OUT / f"{name}.txt", "a") as f:
        f.write("\n".join(LOG) + "\n")
    LOG.clear()


def start(c):
    stamp = f"{time.time():.3f}"
    fc.server(f"workspace:SetAttribute('H4Do', {fc.lua(c + '|' + stamp)}) return 1")
    return stamp


def collect(stamp, timeout=15):
    return fc.server(f"""local out = game:GetService('ServerStorage'):FindFirstChild('ZZH4Out')
if not out then return 'no helper' end
local key = 'ans|{stamp}|'
local t0 = os.clock()
while os.clock() - t0 < {timeout} do
	local a = string.find(out.Value, key, 1, true)
	if a then
		local b = string.find(out.Value, '\\n', a, true)
		return string.sub(out.Value, a + #key, (b or 0) - 1)
	end
	task.wait(0.05)
end
return 'no answer'""")


def do(c, timeout=15):
    stamp = f"{time.time():.3f}"
    return fc.server(f"""local out = game:GetService('ServerStorage'):FindFirstChild('ZZH4Out')
if not out then return 'no helper' end
workspace:SetAttribute('H4Do', {fc.lua(c + '|' + stamp)})
local key = 'ans|{stamp}|'
local t0 = os.clock()
while os.clock() - t0 < {timeout} do
	local a = string.find(out.Value, key, 1, true)
	if a then
		local b = string.find(out.Value, '\\n', a, true)
		return string.sub(out.Value, a + #key, (b or 0) - 1)
	end
	task.wait(0.05)
end
return 'no answer'""")


def cmd(c, wait=0.4):
    stamp = f"{time.time():.3f}"
    got = fc.server(
        f"local RS = game:GetService('ReplicatedStorage') RS:SetAttribute('H4Cmd', {fc.lua(c + '|' + stamp)}) "
        f"local t0 = os.clock() while os.clock() - t0 < 5 do local s = RS:GetAttribute('H4Said') "
        f"if type(s) == 'string' and string.sub(s, -{len(stamp)}) == '{stamp}' then task.wait({wait}) return s end task.wait(0.05) end "
        "return 'no answer'")
    return got.rsplit("|", 2)[0] if got.endswith(stamp) else got


def said():
    return fc.server("local v = game:GetService('ServerStorage'):FindFirstChild('ZZH4Out') local o = {} "
                     "for line in string.gmatch(v and v.Value or 'no helper', '[^\\n]+') do "
                     "if string.sub(line, 1, 4) == 'log|' then table.insert(o, line) end end return table.concat(o, '\\n')")


PASS, FAIL = [], []
TAMED = "Clownfish"  # the kind the Index check tames by a real ride (a Shallows Common: 2 s on it)
# How far the player gets between the stall's looks: it walks at 28 studs a second, the stall looks every 0.05 s and
# this check reads once a frame, so a window's change is seen up to about 2.4 studs after the line it belongs to.
STEP = 2.4


def expect(what, ok, got=""):
    (PASS if ok else FAIL).append(what)
    note(("ok    " if ok else "FAIL  ") + what + (f"   [{got}]" if got != "" else ""))
    return ok


def fields(text):
    """'a=1 b=two' -> {'a': '1', 'b': 'two'}"""
    out = {}
    for word in text.replace(";", " ").split():
        if "=" in word:
            k, v = word.split("=", 1)
            out[k] = v
    return out


def where():
    """The stands as they are in the place: {name: {ring: (x, y, z), size: (x, y, z), counter: (x, y, z) or None}},
    the player's place, the dock's spawn."""
    text = do("where")
    note("where: " + text)
    stands, me, dock = {}, None, None
    for row in text.split("; "):
        w = row.split()
        if w[0] == "me" and w[1] != "none":
            me = tuple(float(v) for v in w[1].split(","))
        elif w[0] == "dock" and "," in w[1]:
            dock = tuple(float(v) for v in w[1].split(","))
        elif len(w) > 4 and w[1] == "ring" and w[2] != "none":
            s = {"ring": tuple(float(v) for v in w[2].split(",")), "size": tuple(float(v) for v in w[4].split(",")),
                 "counter": None}
            if "counter" in w and w[w.index("counter") + 1] != "none":
                s["counter"] = tuple(float(v) for v in w[w.index("counter") + 2].split(","))
            stands[w[0]] = s
    return stands, me, dock


def out_of(stand):
    """The unit step, flat, from the stand's counter out through its ring's middle (the side the player comes from)."""
    r, c = stand["ring"], stand["counter"]
    dx, dz = r[0] - c[0], r[2] - c[2]
    n = math.hypot(dx, dz) or 1
    return dx / n, dz / n


def spot(stand, ahead=0.0, side=0.0):
    """A point `ahead` studs out from the ring's middle (away from the counter) and `side` studs to its right."""
    ox, oz = out_of(stand)
    r = stand["ring"]
    return r[0] + ox * ahead - oz * side, r[2] + oz * ahead + ox * side


def walk(x, z, limit=14):
    got = do(f"walk|{x:.2f}|{z:.2f}|{limit}", timeout=limit + 6)
    note(f"  walk to {x:.1f}, {z:.1f}: {got}")
    return got


def pages(text):
    """the window changes a walk said: [(page, {ring: distance})]"""
    out = []
    for part in text.split("[")[1:]:
        w = part.rstrip("] ").split()
        out.append((w[2], {k: float(v) for k, v in (p.split("=") for p in w[3:])}))
    return out


# ---------------------------------------------------------------------------------------------------------------------
# The checks


def rings():
    note("== the stall rings: Sell, Auras, Sub, Index (the lighthouse; added 2026-11-25, k1, not yet run)")
    stands, _me, _dock = where()
    ui = fields(do("ui"))
    expect("on the dock", ui.get("mode") == "Dock", ui.get("mode"))
    expect("no ProximityPrompt near the stands (no E prompt)", ui.get("near") == "0", f"prompts in the world {ui.get('prompts')}, near {ui.get('near')}")
    near = None
    for row in do("where").split("; "):
        if row.startswith("subnear"):
            near = float(row.split()[1])
    for name in ("Sell", "Auras", "Sub", "Index"):
        if name not in stands or not stands[name]["counter"]:
            expect(f"{name}: the stand and its ring are in the place", False)
            continue
        s = stands[name]
        radius = s["size"][0] / 2
        note(f"-- {name}: ring {s['ring']}, size {s['size']}, radius by Size.X {radius:.2f}")
        off = spot(s, radius + 9)
        mid = spot(s, 0)
        walk(*off)
        ui = fields(do("ui"))
        expect(f"{name}: shut while off the ring", ui.get("page") == "nil", ui.get("page"))
        before = do("ring|" + name)
        got = pages(walk(*mid))
        ui = fields(do("ui"))
        opened = [g for g in got if g[0] == name]
        expect(f"{name}: opens when walked onto the ring", ui.get("page") == name and bool(opened), ui.get("page"))
        if opened:
            d = opened[0][1][name]
            expect(f"{name}: opened at the ring's edge ({radius:.1f} studs from its middle, within a step)", radius - STEP <= d <= radius + 0.1, f"{d:.2f}")
        window = {"Sell": "SellFish", "Auras": "AuraShop", "Sub": "SubShop", "Index": "IndexPanel"}[name]
        time.sleep(0.6)
        ui = fields(do("ui"))
        expect(f"{name}: its window {window} is the one showing", ui.get(window) == "open", {k: ui.get(k) for k in ("SellFish", "AuraShop", "SubShop", "IndexPanel", "ShopScreen")})
        on = do("ring|" + name)
        note(f"  ring before: {before}")
        note(f"  ring stood on: {on}")
        fb, fo = fields(before.replace(";", " ")).get("fill"), fields(on.replace(";", " ")).get("fill")
        lit = fb not in (None, "none") and fo not in (None, "none") and float(fb) > 0.7 and float(fo) < 0.45
        expect(f"{name}: the ring's middle fills in while stood on (the place's HubLife: 0.8 off it, 0.35 on it)", lit, f"{fb} -> {fo}")
        # the X: stays shut while still on the ring
        ui = fields(do("go|"))
        time.sleep(1.5)
        ui = fields(do("ui"))
        expect(f"{name}: after its X it stays shut while still on the ring", ui.get("page") == "nil" and ui.get(window) != "open", ui.get("page"))
        # a few steps inside the ring: still shut
        walk(*spot(s, radius * 0.5))
        ui = fields(do("ui"))
        expect(f"{name}: still shut after a step inside the ring", ui.get("page") == "nil", ui.get("page"))
        # off and on again: it opens
        got = pages(walk(*off))
        got = pages(walk(*mid))
        ui = fields(do("ui"))
        expect(f"{name}: off and on again opens it", ui.get("page") == name, ui.get("page"))
        # the Shop button while on the ring: the Shop takes over, one window at a time
        ui = fields(do("go|Shop"))
        expect(f"{name}: the Shop button on the ring closes it and opens the Shop", ui.get("page") == "Shop" and ui.get(window) != "open" and ui.get("ShopScreen") == "open", ui.get("page"))
        do("go|")
        # walking off closes it, a little past the edge
        walk(*off, limit=6)
        got = pages(walk(*mid))
        got = pages(walk(*off))
        closed = [g for g in got if g[0] == "nil"]
        ui = fields(do("ui"))
        expect(f"{name}: closes when walked off", ui.get("page") == "nil" and bool(closed), ui.get("page"))
        if closed:
            d = closed[0][1][name]
            expect(f"{name}: closed about 2.5 studs past the edge ({radius + 2.5:.1f} from the middle, within a step)", radius + 2.4 <= d <= radius + 2.5 + STEP, f"{d:.2f}")
        if name == "Sub" and near is not None:
            expect(f"Sub: the server's reach (Config.Sub.Near {near}) covers the ring and the 2.5 past it ({radius + 2.5:.1f})", near >= radius + 2.5)
    # the older checks' door (s2_subs_check.py, m4_subs_shots.py, tools/ui/shop_kit): SubPanel.toggle, off the ring
    if "Sub" in stands and stands["Sub"]["counter"]:
        ui = fields(do("subtoggle|on"))
        expect("Sub: SubPanel.toggle(true), the older checks' door, still opens the shop", ui.get("page") == "Sub" and ui.get("SubShop") == "open", f"{ui.get('page')} {ui.get('SubShop')}")
        ui = fields(do("subtoggle|off"))
        expect("Sub: SubPanel.toggle(false) closes it", ui.get("page") == "nil" and ui.get("SubShop") != "open", f"{ui.get('page')} {ui.get('SubShop')}")
    # the sub shop's buttons work from the ring's far edge (the server's own stand check)
    if "Sub" in stands and stands["Sub"]["counter"]:
        s = stands["Sub"]
        radius = s["size"][0] / 2
        note("-- Sub: a buy and an equip from the ring's far edge")
        note("  " + cmd("sub|give|10000000000000"))
        walk(*spot(s, 0))
        walk(*spot(s, radius - 0.6))
        before = fields(cmd("read"))
        do("action|SubBuy")
        do("action|SubBuy")
        after = fields(cmd("read"))
        expect("Sub: a buy from the ring's far edge is taken by the server", after.get("subtier") != before.get("subtier"), f"tier {before.get('subtier')} -> {after.get('subtier')}")
        do("action|SubEquip|1")
        time.sleep(0.4)
        do("action|SubEquip|2")
        after = fields(cmd("read"))
        expect("Sub: an equip from the ring's far edge is taken by the server", after.get("subequip") == "2", after.get("subequip"))
        walk(*spot(s, radius + 9))
    save_log()


def sub():
    note("== the little sub over the submarine stand")
    stands, _me, _dock = where()
    if "Sub" not in stands:
        expect("the Sub stand is in the place", False)
        return
    s = stands["Sub"]
    walk(*spot(s, s["size"][0] / 2 + 12))
    note("  " + cmd("sub|give|10000000000000"))
    for _ in range(9):
        cmd("sub|buy", 0.1)
    rows = {}
    for tier in range(1, 10):
        got = cmd(f"sub|equip|{tier}", 0.2)
        time.sleep(1.6)
        text = do("sub|3.4", timeout=12)
        note(f"  tier {tier}: {text}")
        f = fields(text)
        rows[tier] = f
        if "tier" not in f:
            expect(f"tier {tier}: a sub floats over the stand", False, text)
            continue
        expect(f"tier {tier}: the sub shown is the equipped one", f["tier"] == str(tier), f["tier"])
        expect(f"tier {tier}: it is the place's mesh sub (not the placeholder)", int(f["meshes"]) > 0, f"meshes {f['meshes']} of {f['parts']} parts")
        expect(f"tier {tier}: no name sign, no light, touches nothing", f["boards"] == "0" and f["lights"] == "0" and f["touching"].startswith("0"), f"{f['boards']} {f['lights']} {f['touching']}")
        expect(f"tier {tier}: clear over the stall's highest piece (2.5 wanted)", float(f["clearOverRoof"]) >= 2.4, f["clearOverRoof"])
        if f["underName"] != "-":
            expect(f"tier {tier}: at least 1 stud under the floating name", float(f["underName"]) >= 0.95, f["underName"])
        expect(f"tier {tier}: about 8 studs across its turning circle, centred on the stall", 3.0 <= float(f["round"]) <= 4.1 and float(f["offCentre"]) < 0.6, f"round {f['round']} off centre {f['offCentre']}")
        expect(f"tier {tier}: bobs about 0.35 studs", 0.2 <= float(f["bob"]) <= 0.4, f["bob"])
        expect(f"tier {tier}: turns once in about 18 s (20 degrees a second)", 15 <= abs(float(f["turn"])) <= 25, f["turn"])
        if int(f["props"]) > 0:
            expect(f"tier {tier}: its propeller spins", float(f["spin"]) > 2.0, f["spin"])
        else:
            note(f"  tier {tier}: no part named Prop: nothing to spin")
    # back to the first: the swap is at once
    cmd("sub|equip|1", 0.1)
    time.sleep(0.25)
    f = fields(do("sub|0.2"))
    expect("an equip shows over the stand at once (within a quarter of a second)", f.get("tier") == "1", f.get("tier"))
    save_log()
    return rows


def index():
    note("== the Index")
    roster = json.loads(cmd("roster"))
    note(f"  {roster['Count']} kinds; the player has a tank: {roster['Tank']}; Config.Index {roster['Index']}")
    sets = {row["Land"]: row["Set"] for row in roster["Lands"]}
    kinds = {row["Land"]: row["Kinds"] for row in roster["Lands"]}
    note("  lands: " + ", ".join(f"{k}: {kinds[k]} kinds, {len(v)} in the set" for k, v in sets.items()))
    # a land to finish: the smallest set that fits the hands in two goes
    land = min((k for k in sets if len(sets[k]) > 0), key=lambda k: (len(sets[k]), k))
    ids = sets[land]
    note(f"  the land finished in this check: {land} ({len(ids)} kinds: {', '.join(ids)})")
    stands, _me, dock = where()
    cmd("home", 1.0)
    start_read = fields(cmd("read"))
    note("  at the start: " + str(start_read))
    ui = fields(do("ui"))
    expect("Index: shut at the start, no '!' on its button", ui.get("indexOpen") == "false" and ui.get("mark:Index", "false/false").startswith("false"), {k: v for k, v in ui.items() if k.startswith("mark") or k.startswith("index")})
    # the button opens and closes it
    ui = fields(do("indexbutton"))
    expect("Index: its button opens it", ui.get("indexOpen") == "true" and ui.get("page") == "Index" and ui.get("IndexPanel") == "open", ui.get("page"))
    first_open = do("indexui")
    note("  first open: " + first_open)
    ui = fields(do("indexbutton"))
    expect("Index: its button closes it again", ui.get("indexOpen") == "false" and ui.get("page") == "nil", ui.get("page"))
    do("indexbutton")
    ui = fields(do("go|"))
    expect("Index: its X closes it", ui.get("indexOpen") == "false", ui.get("page"))
    do("indexbutton")
    ui = fields(do("go|Shop"))
    expect("Index: opening the Shop closes it (one dock window at a time)", ui.get("indexOpen") == "false" and ui.get("page") == "Shop", ui.get("page"))
    do("go|")
    # a catch made while the window is closed
    fish = ids[0]
    found0 = int(start_read.get("found", "0") or 0)
    note("  " + cmd(f"carry|{fish}|Normal|", 0.9))
    r = fields(cmd("read"))
    expect(f"Index: a catch in the hands ({fish}) marks its kind found on the server", int(r.get("found", -1)) == found0 + 1 and int(r.get("claims", 0)) >= 1, f"found {r.get('found')} claims {r.get('claims')}")
    ui = fields(do("ui"))
    expect("Index: the '!' is up on the hub's Index button", ui.get("mark:Index", "").startswith("true/true"), ui.get("mark:Index"))
    ui = fields(do("indexbutton"))
    do(f"index|Land|{land}")
    after = do("indexui")
    note("  after the catch: " + after)
    expect(f"Index: the card of {fish} shows as found when the window is opened after the catch", fish in after.split("found=")[1].split()[0].split(","))
    card = do(f"card|{fish}")
    note("  the found card: " + card)
    dark = do(f"card|{ids[1]}") if len(ids) > 1 else ""
    note("  a card not found: " + dark)
    # claim: pays once
    want_o, want_c = (float(v) for v in cmd(f"first|{fish}").split(","))
    r0 = fields(cmd("read"))
    do(f"index|Kind|{fish}")
    do("index|Claim", timeout=8)
    time.sleep(0.5)
    r1 = fields(cmd("read"))
    paid_o = float(r1["max"]) - float(r0["max"])
    paid_c = float(r1["coins"]) - float(r0["coins"])
    toast = do("indexui")
    note("  after the claim: " + toast)
    has_tank = roster["Tank"]
    expect(f"Index: CLAIM pays the kind's reward ({want_o:g} max Oxygen" + (f", {want_c:g} coins and the tank's own earning)" if has_tank else ")"),
           abs(paid_o - want_o) < 1 and (not has_tank or want_c <= paid_c <= want_c + max(50, want_c * 0.5)), f"Oxygen +{paid_o:g}, coins +{paid_c:g}")
    time.sleep(0.4)
    do("index|Claim", timeout=8)
    do(f"net|Claim|{fish}")
    time.sleep(0.5)
    r2 = fields(cmd("read"))
    expect("Index: a second CLAIM of the same kind pays nothing", abs(float(r2["max"]) - float(r1["max"])) < 1, f"Oxygen {r1['max']} -> {r2['max']}")
    ui = fields(do("ui"))
    expect("Index: the '!' is down once nothing waits", ui.get("mark:Index", "").startswith("false") and ui.get("IndexClaims") == "0", f"{ui.get('mark:Index')} claims {ui.get('IndexClaims')}")
    # off the dock: refused
    cmd("take", 0.2)
    if len(ids) > 1:
        cmd(f"carry|{ids[1]}|Normal|", 0.9)
        r = fields(cmd("read"))
        expect("Index: the second kind is found too", int(r.get("claims", 0)) == 1, r.get("claims"))
        fc.setw(TestMaxOxygen=10000000)
        # a real ride: the game's own taming (Config.Tame.Time 2 s on a Shallows Common) puts the fish in the hands
        was = json.loads(cmd("found"))
        note("  " + cmd(f"ride|{TAMED}", 0.3))
        time.sleep(4.0)
        state = fields(cmd("read")).get("state")
        b = fields(cmd("read"))
        now = json.loads(cmd("found"))
        tamed = TAMED not in was and TAMED in now
        expect(f"Index: a fish tamed by riding it (the game's own taming, no test hook) marks its kind found ({TAMED})",
               tamed and int(b.get("carried", 0)) >= 2, f"found before {sorted(was)}, after {sorted(now)}, carried {b.get('carried')}, state {state}")
        do("heard")
        ui = fields(do(f"net|Claim|{ids[1]}"))
        a = fields(cmd("read"))
        heard = do("heard")
        expect(f"Index: off the dock (state {state}) a claim is refused and pays nothing", state != "Dock" and abs(float(a["max"]) - float(b["max"])) < 1 and a.get("claims") == b.get("claims") and "Denied:Dock" in heard,
               f"Oxygen {b['max']} -> {a['max']}, claims {b.get('claims')} -> {a.get('claims')}, the server said {heard}")
        expect("Index: leaving the dock closed the window", ui.get("indexOpen") == "false", ui.get("indexOpen"))
        # the refusal's red line shows in the window only, and the window is shut off the dock (the hub's buttons are
        # hidden there), so it is opened here as no player can, to see the line the server's word draws
        hub = fields(do("ui")).get("mark:Index", "")
        expect("Index: off the dock the hub's Index button is hidden (so the window can't be opened there)", hub.endswith("/false") or hub == "", hub)
        do("go|Index")
        do(f"net|Claim|{ids[1]}")
        line = do("indexui")
        toast = line[line.find("toast"):line.find("LandSet")]
        colour = [int(v) for v in toast.split("colour")[-1].replace(";", "").strip().split(",")] if "colour" in toast else [0, 0, 0]
        expect("Index: the refusal's line is 'Stand on the dock to claim', in red", "toast=true 'Stand on the dock to claim'" in toast and colour[0] > 200 and colour[1] < 160, toast)
        do("go|")
        cmd("home", 1.5)
        fc.setw(TestMaxOxygen=None)
        time.sleep(1.0)
    # the rest of the land's set, through the hands (7 at a time)
    for fid in ids[1:]:
        got = cmd(f"carry|{fid}|Normal|", 0.6)
        if "true" not in got:
            cmd("take", 0.1)
            got = cmd(f"carry|{fid}|Normal|", 0.6)
        cmd("take", 0.1)
    time.sleep(0.6)
    r3 = fields(cmd("read"))
    extra = [k for k in json.loads(cmd("found")) if k not in ids]
    want = len(ids) - 1 + 1 + len(extra)
    expect(f"Index: the whole set of land {land} found: {len(ids) - 1} kinds, the land's reward and the tamed {extra} wait ({want})", r3.get("claims") == str(want), f"claims {r3.get('claims')}, found {r3.get('found')}")
    sum_o, sum_c = 0.0, 0.0
    for fid in ids[1:] + extra:
        o, c = (float(v) for v in cmd(f"first|{fid}", 0.05).split(","))
        sum_o += o
        sum_c += c
    land_o, land_c = (float(v) for v in cmd(f"land|{land}").split(","))
    ui = fields(do("indexbutton"))
    if ui.get("indexOpen") != "true":
        ui = fields(do("indexbutton"))
    do(f"index|Land|{land}")
    full = do("indexui")
    note("  the land full, before CLAIM ALL: " + full)
    expect("Index: the '!' is up again with rewards waiting", fields(do("ui")).get("mark:Index", "").startswith("true/true"))
    # the land's own reward first, by its own button: once
    do("index|ClaimLand", timeout=8)
    time.sleep(0.6)
    r4 = fields(cmd("read"))
    expect(f"Index: the land's CLAIM pays its reward ({land_o:g} max Oxygen)", abs(float(r4["max"]) - float(r3["max"]) - land_o) < 1, f"Oxygen +{float(r4['max']) - float(r3['max']):g}, coins +{float(r4['coins']) - float(r3['coins']):g} (reward {land_c:g})")
    do("index|ClaimLand", timeout=8)
    do(f"net|ClaimLand|{land}")
    time.sleep(0.5)
    r5 = fields(cmd("read"))
    expect("Index: the land's reward is paid once only", abs(float(r5["max"]) - float(r4["max"])) < 1, f"{r4['max']} -> {r5['max']}")
    do("index|ClaimAll", timeout=8)
    time.sleep(0.6)
    r6 = fields(cmd("read"))
    expect(f"Index: CLAIM ALL pays every kind that waited ({sum_o:g} max Oxygen for {len(ids) - 1 + len(extra)} kinds)", abs(float(r6["max"]) - float(r5["max"]) - sum_o) < 1 and r6.get("claims") == "0", f"Oxygen +{float(r6['max']) - float(r5['max']):g}, coins +{float(r6['coins']) - float(r5['coins']):g} (rewards {sum_c:g}), claims {r6.get('claims')}")
    done = do("indexui")
    note("  after CLAIM ALL: " + done)
    time.sleep(0.4)
    do("index|ClaimAll", timeout=8)
    do("net|ClaimAll")
    time.sleep(0.5)
    r7 = fields(cmd("read"))
    expect("Index: CLAIM ALL again pays nothing", abs(float(r7["max"]) - float(r6["max"])) < 1, f"{r6['max']} -> {r7['max']}")
    ui = fields(do("ui"))
    expect("Index: the '!' is down after everything is claimed", ui.get("mark:Index", "").startswith("false"), ui.get("mark:Index"))
    # scrolling: this land, and the Shallows
    for l in sorted(set([land, 1])):
        do(f"index|Land|{l}")
        text = do("indexui")
        f = fields(text.replace(" ; ", " "))
        rows = math.ceil(kinds[l] / 5)
        note(f"  land {l}: {kinds[l]} kinds, {rows} rows: canvas {f.get('canvas')} window {f.get('window')} scrolls {f.get('scrolls')}")
        if rows <= 2:
            expect(f"Index: land {l} ({rows} rows) does not scroll", f.get("scrolls") == "false", f"canvas {f.get('canvas')} window {f.get('window')}")
        else:
            expect(f"Index: land {l} ({rows} rows) scrolls to its last row", f.get("scrolls") == "true", f"canvas {f.get('canvas')} window {f.get('window')}")
    # leaving the dock closes it
    fc.setw(TestMaxOxygen=10000000)
    cmd("ride|Clownfish", 2.5)
    ui = fields(do("ui"))
    expect("Index: leaving the dock closes the window", ui.get("indexOpen") == "false", f"mode {ui.get('mode')} open {ui.get('indexOpen')}")
    cmd("home", 1.5)
    fc.setw(TestMaxOxygen=None)
    save_log()


def series(text):
    f = fields(text.split(" rows=")[0])
    rows = [tuple(float(v) for v in r.split(",")) for r in text.split(" rows=")[1].split()] if " rows=" in text else []
    return f, rows


def keepers():
    note("== the keepers")
    stands, _me, _dock = where()
    text = do("klist")
    for row in text.split(" ; "):
        note("  " + row)
    expect("all four keepers are in the world", "MISSING" not in text and text.count(" at ") >= 4)
    at = {}  # keeper -> (its root, the way it faces, the most its own action turns its head)
    for row in text.split(" ; "):
        if ": parts " not in row:
            continue
        name = row.split()[0]
        w = row.replace(",", " ").replace("(", " ").replace(")", " ").split()
        parts, data = int(w[w.index("parts") + 1]), int(w[w.index("parts") + 3])
        props, pdata = int(w[w.index("props") + 1]), int(w[w.index("props") + 3])
        scale = float(w[w.index("scale") + 1])
        feet = float(w[w.index("feet") + 1])
        expect(f"{name}: every part and prop of its table is built", parts == data and props == pdata, f"{parts}/{data} parts, {props}/{pdata} props")
        expect(f"{name}: its size is the stand's own, not held at a limit (0.7 or 1.5)", 0.72 < scale < 1.48, f"{scale}")
        expect(f"{name}: stands on something (feet at or over the floor, under 4.5)", -0.05 <= feet <= 4.6, f"{feet}")
        expect(f"{name}: stands square to its stand's front (its ring {w[w.index('ring') + 1]} degrees off straight ahead)", float(w[w.index("within") + 1]) < 2, w[w.index("within") + 1])
        at[name] = (tuple(float(v) for v in w[w.index("root") + 1:w.index("root") + 4]), tuple(float(v) for v in w[w.index("face") + 1:w.index("face") + 3]), float(w[w.index("headact") + 1]))
        expect(f"{name}: touches nothing", w[w.index("touching") + 1] == "0")
    ids = {"Sell": "Fishmonger", "Auras": "Mystic", "Sub": "Diver", "Fuse": "Tinkerer"}
    listed = [row.split()[0] for row in text.split(" ; ") if ": parts " in row]
    by_station = {row.split()[2].rstrip(":"): row.split()[0] for row in text.split(" ; ") if ": parts " in row}
    note(f"  keepers by stand: {by_station}")
    results = {}
    for station, kid in by_station.items():
        if station not in stands or not stands[station]["counter"]:
            continue
        s = stands[station]
        radius = s["size"][0] / 2
        note(f"-- {kid} at {station}")
        (kx, _ky, kz), (fx, fz), head_act = at[kid]
        own = head_act + 2  # a keeper's action turns its head a little by itself, on top of the look
        # idle, from far (past Look.Far, inside Look.Animate): the bob and the action, the head at rest
        far = spot(s, radius + 34)
        walk(*far, limit=16)
        text = do(f"ksample|{kid}|11", timeout=20)
        f, rows = series(text)
        if not rows:
            expect(f"{kid}: sampled", False, text[:200])
            continue
        every = [float(v) for v in f["every"].split("-")]
        yaws = [r[1] for r in rows]
        moved = [r[8] for r in rows]
        note(f"  idle from {rows[0][5]:.0f} studs: frames {f['frames']}, bob {f['bob']}, head yaw {min(yaws):.1f} to {max(yaws):.1f}, action joints moved up to {max(moved):.2f}, wait between actions {every}")
        expect(f"{kid}: bobs while idle (its body rises and falls)", float(f["bob"]) > 0.02, f["bob"])
        expect(f"{kid}: does its action within {every[1] + float(f['act']):.0f} s (its acting hand moves well past the idle's sway)", max(moved) > 0.25, f"{max(moved):.2f} studs")
        still = sum(1 for v in yaws if abs(v) < 1) / len(yaws)
        expect(f"{kid}: looks straight ahead with nobody near (but for its action's own glance, {head_act:g} degrees)", still > 0.3 and max(abs(v) for v in yaws) <= own, f"{min(yaws):.1f} to {max(yaws):.1f}, straight for {still * 100:.0f}% of the time")
        # walk in to the side of the ring: the head eases round to the player
        # (18.75 studs in front of the keeper and 9.75 to a side: 21 studs off, 27 degrees round)
        side = (kx + fx * 18.75 + fz * 9.75, kz + fz * 18.75 - fx * 9.75)
        stamp = start(f"ksample|{kid}|9")
        time.sleep(0.3)
        walk(*side, limit=7)
        f, rows = series(collect(stamp, timeout=15))
        if rows:
            last = rows[-1]
            near_rows = [r for r in rows if 0 <= r[5] <= float(f["near"])]
            # (from the first frame the player is inside Near: how long until the head is within 5 degrees of them)
            took = None
            if near_rows:
                t_in = near_rows[0][0]
                for r in near_rows:
                    if abs(r[1] - r[2]) < 5 and abs(r[2]) > 3:
                        took = r[0] - t_in
                        break
            note(f"  walked in to the side: at the end the head is at {last[1]:.1f} deg, asked {last[2]:.1f}, the player {last[5]:.1f} studs off and {last[6]:.0f} deg round; biggest step in one frame {f['maxStep']} deg, fastest {f['maxRate']} deg/s over {f['frames']} frames (longest frame {f['longest']} s); caught up {took if took is None else round(took, 2)} s after the player came inside {f['near']}")
            settled = [abs(r[1] - r[2]) for r in rows if r[0] > rows[-1][0] - 4]
            on = sum(1 for v in settled if v < 2) / len(settled)
            expect(f"{kid}: looks at the player who has come near (on them within 2 degrees, but for its action's glance)", on > 0.3 and max(settled) <= own and abs(last[2]) > 8,
                   f"over the last 4 s: on the player {on * 100:.0f}% of the time, furthest off {max(settled):.1f}; the player at {last[2]:.1f}")
            expect(f"{kid}: turns with easing, no jump (under 8 degrees in any one frame)", float(f["maxStep"]) < 8, f["maxStep"])
            expect(f"{kid}: the turn takes a moment, not a frame (it trails the player while they walk in)", took is not None and took > 0.1, took)
            expect(f"{kid}: the head keeps inside its limit ({f['limit']} degrees)", max(abs(r[1]) for r in rows) <= float(f["limit"]) + 4, f"{max(abs(r[1]) for r in rows):.1f}")
            results[kid + "_in"] = rows
        # walk across in front of the stand: the head follows
        other = (kx + fx * 18.75 - fz * 9.75, kz + fz * 18.75 + fx * 9.75)
        stamp = start(f"ksample|{kid}|7")
        time.sleep(0.3)
        walk(*other, limit=6)
        f, rows = series(collect(stamp, timeout=14))
        if rows:
            yaws = [r[1] for r in rows]
            asks = [r[2] for r in rows]
            lag = max(abs(r[1] - r[2]) for r in rows[len(rows) // 4:])
            note(f"  walked across: head from {yaws[0]:.1f} to {yaws[-1]:.1f}, asked from {asks[0]:.1f} to {asks[-1]:.1f}; biggest step {f['maxStep']} deg, most behind the player {lag:.1f} deg")
            ends = [abs(r[1] - r[2]) for r in rows if r[0] > rows[-1][0] - 2]
            expect(f"{kid}: follows the player across (the head swings to the other side)", yaws[0] * yaws[-1] < 0 and min(ends) < 3 and max(ends) <= own + 4, f"{yaws[0]:.1f} -> {yaws[-1]:.1f}, asked {asks[-1]:.1f}; in the last 2 s between {min(ends):.1f} and {max(ends):.1f} off")
            expect(f"{kid}: follows with easing (under 8 degrees in any one frame)", float(f["maxStep"]) < 8, f["maxStep"])
            results[kid + "_across"] = rows
        # walk away past Look.Far: back to the idle
        stamp = start(f"ksample|{kid}|9")
        time.sleep(0.3)
        walk(*far, limit=8)
        f, rows = series(collect(stamp, timeout=16))
        if rows:
            last = rows[-1]
            note(f"  walked away to {last[5]:.0f} studs: head from {rows[0][1]:.1f} to {last[1]:.1f}; biggest step {f['maxStep']} deg")
            ends = [abs(r[1]) for r in rows if r[0] > rows[-1][0] - 4]
            back = sum(1 for v in ends if v < 1) / len(ends)
            expect(f"{kid}: returns to straight ahead once the player has gone (past {f['far']} studs)", last[5] > float(f["far"]) and back > 0.3 and max(ends) <= own, f"over the last 4 s straight {back * 100:.0f}% of the time, furthest {max(ends):.1f}; the player {last[5]:.0f} studs off")
            expect(f"{kid}: returns with easing (under 8 degrees in any one frame)", float(f["maxStep"]) < 8, f["maxStep"])
            results[kid + "_away"] = rows
    (OUT / "keeper_series.json").write_text(json.dumps(results))
    save_log()


def props():
    note("== the props and the keepers against the place")
    text = do("props", timeout=30)
    for row in text.split(" ; "):
        note("  " + row)
        if row.startswith("stand sub"):
            gap = float(row.rsplit("gap", 1)[1])
            expect("the stand's sub floats clear of every keeper piece under it", gap > 0.5, f"{gap:.2f}")
            continue
        if "MISSING" in row or ": ring gap" not in row:
            continue
        name = row.split(":")[0]
        w = row.replace(";", " ").split()
        ring = float(w[w.index("gap") + 1])
        under = float(w[w.index("name") + 1])
        line = float(w[w.index("line") + 1])
        expect(f"{name}: keeper and props are off every ring's circle", ring > 0, f"nearest {ring:.2f} studs outside ({row.split('(')[1].split(')')[0]})")
        expect(f"{name}: keeper and props are under the floating name", under > 0.5, f"{under:.2f} studs under")
        expect(f"{name}: nothing within 2 studs of the straight walk from the spawn to a ring", line > 2, f"{line:.2f}")
        deep = [float(p.rsplit(" ", 1)[1]) for p in row.split("kinds ", 1)[1].split(": ", 1)[1].split(" | ") if p.strip()] if "kinds 0" not in row else []
        expect(f"{name}: no piece is sunk more than 0.3 studs into one of the place's parts", not deep or max(deep) <= 0.3, f"deepest {max(deep) if deep else 0:.2f}")
    save_log()


def phone():
    note("== the windows at a phone's size (844 x 390)")
    stands, _me, _dock = where()
    cmd("home", 1.0)
    for size in (None, PHONE):
        label = "phone" if size else "desktop"
        note("  " + do("phone|%d|%d" % size if size else "phone|off"))
        for page, gui in (("Index", "IndexPanel"), ("Sub", "SubShop"), ("Sell", "SellFish"), ("Auras", "AuraShop")):
            do("go|" + page)
            time.sleep(0.6)
            text = do("box|" + gui)
            note(f"  {label} {page}: {text}")
            f = {}
            for part in text.split("; "):
                w = part.split()
                if w[0] == "screen":
                    f["screen"] = tuple(int(v) for v in (w[1] + "," + w[3]).split(","))
                elif w[0] == "window":
                    f["window"] = tuple(int(v) for v in (w[1] + "," + w[3]).split(","))
                    f["outside"] = part.split("outside ")[1]
                elif w[0] == "words":
                    f["least"] = float(w[3])
                    f["cut"] = int(part.split("not fitting ")[1].split(":")[0])
            if "window" in f and "screen" in f:
                box = f["screen"]
                x0, y0, x1, y1 = f["window"]
                if size:
                    expect(f"{label}: the {page} window is laid out for a screen of {size[0]} x {size[1]}", abs(box[2] - box[0] - size[0]) <= 2 and abs(box[3] - box[1] - size[1]) <= 2, f"{box[2] - box[0]} x {box[3] - box[1]}")
                expect(f"{label}: the {page} window is whole on the screen", x0 >= box[0] - 1 and y0 >= box[1] - 1 and x1 <= box[2] + 1 and y1 <= box[3] + 1 and f["outside"].startswith("0"), f"window {f['window']} in {box}, outside it {f['outside']}")
                expect(f"{label}: the {page} window's words all fit their boxes", f.get("cut", 0) == 0, text.split("not fitting ")[1].split(";")[0])
                note(f"    smallest words {f.get('least')} px, the window {x1 - x0} x {y1 - y0} of {box[2] - box[0]} x {box[3] - box[1]}")
            else:
                expect(f"{label}: the {page} window is up", False, text)
            do("go|")
    note("  " + do("phone|off"))
    save_log()


# ---------------------------------------------------------------------------------------------------------------------
# Stills


def raw(name):
    full = OUT / (name + "-full.png")
    full.unlink(missing_ok=True)
    out = fc.run(["shot", str(full)], timeout=60)
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


def gate():
    """Are the window's pictures live, and where is the game view in them? The client paints the view one colour and
    takes it off again: the first picture must show it, the second must not."""
    note(do("ping"))
    box = None
    note(do("flash|on"))
    for _ in range(6):
        time.sleep(1.3)
        im = Image.open(raw("gate")).convert("RGB")
        r, g, b = im.split()
        mask = ImageChops.multiply(ImageChops.multiply(r.point(lambda v: 255 if v > 230 else 0), g.point(lambda v: 255 if v < 40 else 0)), b.point(lambda v: 255 if v > 230 else 0))
        box = mask.getbbox()
        if box and box[2] - box[0] > 400 and box[3] - box[1] > 300:
            break
        box = None
    note(do("flash|off"))
    if not box:
        save_log()
        raise SystemExit("FROZEN: the game view never showed the gate's colour (Studio's window is not redrawing)")
    for _ in range(6):
        time.sleep(1.3)
        im2 = Image.open(raw("gate")).convert("RGB").crop(box)
        r, g, b = im2.resize((64, 64)).split()
        pink = sum(1 for x, y, z in zip(r.getdata(), g.getdata(), b.getdata()) if x > 230 and y < 40 and z > 230)
        if pink < 64 * 64 * 0.5:
            break
    else:
        save_log()
        raise SystemExit("FROZEN: the gate's colour never left the game view (Studio's window stopped redrawing)")
    VIEW_FILE.write_text(json.dumps(list(box)))
    note(f"live: the window's picture is {im.size}, the game view in it {box}")
    save_log()
    return box


def still(name, wait=1.6):
    """One picture of the game view, cut from the window's own picture."""
    box = tuple(json.loads(VIEW_FILE.read_text()))
    time.sleep(wait)
    full = raw(name)
    path = OUT / (name + ".png")
    Image.open(full).convert("RGB").crop(box).save(path)
    full.unlink(missing_ok=True)
    return path


def keep(path, name, crop=None):
    """A still for the record: docs/attachments/hub-h4-<name>.jpg, 1600 wide at most."""
    im = Image.open(path).convert("RGB")
    if crop:
        im = im.crop(crop)
    if im.width > 1600:
        im = im.resize((1600, round(im.height * 1600 / im.width)), Image.LANCZOS)
    dest = ATTACH / f"hub-h4-{name}.jpg"
    im.save(dest, quality=88)
    note(f"  kept {dest}")
    return dest


def stills(only=None):
    note("== the stills (the dock's own camera, turned only)")
    if not VIEW_FILE.exists():
        gate()
    stands, _me, _dock = where()
    kept = []
    do("phone|off")
    do("go|")
    for _ in range(8):  # empty hands (one fish a go): no "go to your tank" line across the picture
        if fields(cmd("read")).get("carried") == "0":
            break
        cmd("take", 0.2)
    at = {}  # stand -> (its keeper's root, the way the keeper faces)
    by_stand = {}
    for row in do("klist").split(" ; "):
        if ": parts " in row:
            w = row.replace(",", " ").split()
            at[w[2].rstrip(":")] = (tuple(float(v) for v in w[w.index("root") + 1:w.index("root") + 4]), tuple(float(v) for v in w[w.index("face") + 1:w.index("face") + 3]))
            by_stand[w[2].rstrip(":")] = w[0]
    want = only or ["Sell", "Auras", "Sub", "Fuse", "sub", "index"]

    def here():
        return tuple(float(v) for v in do("where").split(";")[0].split()[1].split(","))

    def aim(target, down, round_by):
        """Turns the dock's camera to look past the player toward `target`, swung `round_by` degrees to a side so the
        player's own avatar is not in front of what is looked at."""
        px, _py, pz = here()
        dx, dz = target[0] - px, target[2] - pz
        a = math.radians(round_by)
        tx = px + dx * math.cos(a) - dz * math.sin(a)
        tz = pz + dx * math.sin(a) + dz * math.cos(a)
        note("  " + do(f"cam|{tx:.2f}|{target[1]:.2f}|{tz:.2f}|{down}"))

    def reach(x, z, limit=16):
        """A walk that has to arrive: a picture taken from against a stall's back is not the picture asked for."""
        walk(x, z, limit=limit)
        px, _py, pz = here()
        if math.hypot(px - x, pz - z) > 3:
            raise SystemExit(f"the walk to {x:.1f}, {z:.1f} stopped at {px:.1f}, {pz:.1f}: no still taken")

    leave = None
    if all(k in stands and stands[k]["ring"] for k in ("Sell", "Auras", "Fuse")):
        # the open middle of the hub first, by a line that passes behind no stall (from the Sub stand the straight
        # walk to Sell runs into the back of the Auras stall)
        mx = (stands["Sell"]["ring"][0] + stands["Auras"]["ring"][0]) / 2
        mz = (stands["Sell"]["ring"][2] + stands["Fuse"]["ring"][2]) / 2
        reach(mx, mz - 2, limit=20)
    for name in ("Sell", "Auras", "Sub", "Fuse"):
        if name not in want or name not in stands or not stands[name]["counter"]:
            continue
        s = stands[name]
        radius = s["size"][0] / 2
        c = s["counter"]
        # the stand whole, from outside its ring: the keeper, the props, the name
        # (first straight out in front of the stall last stood at: a straight walk on from there meets no stall)
        if leave:
            reach(*leave, limit=8)
        if name in at:
            (kx, ky, kz), (fx, fz) = at[name]
            reach(kx + fx * 30, kz + fz * 30, limit=16)
            leave = (kx + fx * 30, kz + fz * 30)
        x, z = spot(s, radius + 7, 0)
        reach(x, z, limit=16)
        do("go|")
        aim(c, 6, 16)
        kept.append(keep(still(f"stand-{name.lower()}"), f"stand-{name.lower()}"))
        # close, in front of the keeper and to one side (off the ring: no window): the keeper looking at the player
        if name in at:
            (kx, ky, kz), (fx, fz) = at[name]
            side = 1
            x, z = kx + fx * 8.5 + side * fz * 6.6, kz + fz * 8.5 - side * fx * 6.6
            reach(x, z, limit=10)
            do("go|")
            aim((kx, ky + 3.5, kz), 12, -30 * side)
        else:
            x, z = spot(s, radius * 0.2, radius + 2.5)
            walk(x, z, limit=10)
            aim(c, 12, 30)
        time.sleep(1.6)
        note("  " + do("ui"))
        note("  " + do(f"ksample|{by_stand[name]}|0.3")[:400] if name in by_stand else "")
        shot = still(f"keeper-{name.lower()}")
        kept.append(keep(shot, f"keeper-{name.lower()}"))
        if name in at:
            # the same picture cut to the keeper (nothing moved: a cut of the game's own view)
            (kx, ky, kz), _face = at[name]
            w = do(f"screen|{kx:.2f}|{ky + 3.2:.2f}|{kz:.2f}").replace(",", " ").split()
            im = Image.open(shot)
            sx, sy = int(w[0]) * im.width / int(w[4].split("x")[0]), int(w[1]) * im.height / int(w[4].split("x")[1])
            cw, ch = 800, 500
            x0 = int(min(max(sx - cw / 2, 0), im.width - cw))
            y0 = int(min(max(sy - ch / 2, 0), im.height - ch))
            kept.append(keep(shot, f"keeper-{name.lower()}-close", crop=(x0, y0, x0 + cw, y0 + ch)))
    if "sub" in want and "Sub" in stands:
        s = stands["Sub"]
        radius = s["size"][0] / 2
        c = s["counter"]
        if leave:
            walk(*leave, limit=8)
        if "Sub" in at:
            (kx, ky, kz), (fx, fz) = at["Sub"]
            walk(kx + fx * 30, kz + fz * 30, limit=16)
        x, z = spot(s, radius + 6, 0)
        walk(x, z, limit=16)
        do("go|")
        aim((c[0], c[1] + 9, c[2]), -14, 26)

        def cut(shot, name):
            # the same picture cut to the little sub (its middle from the helper's own reading of the stall)
            w = do(f"screen|{c[0]:.2f}|{c[1] + 10.5:.2f}|{c[2]:.2f}").replace(",", " ").split()
            im = Image.open(shot)
            sx, sy = int(w[0]) * im.width / int(w[4].split("x")[0]), int(w[1]) * im.height / int(w[4].split("x")[1])
            cw, ch = 900, 700
            x0 = int(min(max(sx - cw / 2, 0), im.width - cw))
            y0 = int(min(max(sy - ch * 0.42, 0), im.height - ch))
            return keep(shot, name, crop=(x0, y0, x0 + cw, y0 + ch))

        note("  " + do("sub|0.3"))
        shot = still("stand-sub-little")
        kept.append(keep(shot, "little-sub"))
        kept.append(cut(shot, "little-sub-close"))
        # and with a later sub equipped (the test hook buys five and equips the fifth)
        cmd("sub|give|10000000000000", 0.2)
        for _ in range(5):
            cmd("sub|buy", 0.15)
        cmd("sub|equip|5", 0.2)
        time.sleep(1.6)
        note("  " + do("sub|0.3"))
        shot = still("stand-sub-little-5")
        kept.append(keep(shot, "little-sub-tier5"))
        kept.append(cut(shot, "little-sub-tier5-close"))
        cmd("sub|equip|0", 0.2)
    if "index" in want:
        cmd("home", 1.0)
        do("go|")
        # a fresh player has found nothing: three kinds of the first land through the hands, one of them claimed
        if fields(cmd("read")).get("found") == "0":
            roster = json.loads(cmd("roster"))
            first = [row["Set"] for row in roster["Lands"] if row["Land"] == 1][0][:3]
            for fid in first:
                cmd(f"carry|{fid}|Normal|", 0.6)
            for _ in first:
                cmd("take", 0.2)
            do(f"net|Claim|{first[0]}")
            time.sleep(0.5)
            note("  " + cmd("read"))
        do("indexbutton")
        time.sleep(1.5)
        do("index|Land|1")
        time.sleep(0.8)
        note("  " + do("indexui"))
        kept.append(keep(still("index-grid"), "index-grid"))
        text = do("indexui")
        found = text.split("found=")[1].split()[0].split(",") if "found=" in text else []
        if found and found[0]:
            # the last kind found: its reward is still waiting, so the detail shows CLAIM (the first is claimed above)
            do(f"index|Kind|{found[-1]}")
            time.sleep(1.0)
            kept.append(keep(still("index-detail"), "index-detail"))
        note("  " + do("phone|%d|%d" % PHONE))
        time.sleep(1.2)
        kept.append(keep(still("index-phone"), "index-phone"))
        note("  " + do("phone|off"))
        do("go|")
    save_log()
    return kept


RUNS = {"rings": rings, "sub": sub, "index": index, "keepers": keepers, "props": props, "phone": phone}

if __name__ == "__main__":
    what = sys.argv[1]
    if what == "install":
        print(install())
    elif what == "remove":
        print(install(remove=True))
    elif what == "mine":
        print(mine())
    elif what == "gate":
        gate()
    elif what == "stills":
        for p in stills(sys.argv[2:] or None):
            print(p)
    elif what == "do":
        print(do(sys.argv[2], timeout=float(sys.argv[3]) if len(sys.argv) > 3 else 20))
    elif what == "cmd":
        print(cmd(sys.argv[2]))
    elif what == "log":
        print(said())
    elif what == "run":
        ok, got, want = mine()
        if not ok:
            raise SystemExit(f"the playtest's helper is not this file's ({got} against {want}): not our Play, nothing driven")
        try:
            for name in sys.argv[2:] or list(RUNS):
                RUNS[name]()
        finally:
            note(f"passed {len(PASS)}, failed {len(FAIL)}")
            for line in FAIL:
                note("FAILED: " + line)
            note("client log:\n" + said())
            save_log()
