--!nocheck
-- The water from the hub, tried live (2026-11-25, docs/design/water-ideas.md). Run on the CLIENT while playing. Two rows of
-- buttons: how see-through the water is (one at a time), and add-ons (any of them together). Everything is made on this
-- machine only and is gone when Play stops. Scripts can press the buttons too: workspace.WaterTrial's attributes
-- (See = 1 to 7, and one true or false for each add-on).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local X = 3000 -- the lane's middle; the water begins at z 0, the hub's strip is z -32 to 0 at y 1

local old = workspace:FindFirstChild("WaterTrial")
if old then
	old:Destroy()
	task.wait(0.3)
end
for _, d in workspace.ClaudeBlockout:GetDescendants() do -- the floor's light, left by an earlier run
	if d.Name == "WaterTrialLight" then
		d:Destroy()
	end
end
local root = Instance.new("Folder")
root.Name = "WaterTrial"
root.Parent = workspace

local layers = workspace.ClaudeBlockout.Surface:WaitForChild("WaterLayers")
local NAMES = { "Foam", "Water1", "Water2", "Water3" }
-- name, the four layers' see-through, the picture's
local SEE = {
	{ "Now", { 0.35, 0.76, 0.78, 0.85 }, 0.6 },
	{ "A", { 0.55, 0.82, 0.86, 0.88 }, 0.6 },
	{ "B", { 0.7, 0.88, 0.9, 0.9 }, 0.65 },
	{ "C", { 0.82, 0.92, 0.93, 0.93 }, 0.7 },
	{ "No glass", { 1, 0.7, 0.85, 0.85 }, 0.6 },
	{ "Blue behind", { 0.72, 0.9, 1, 1 }, 0.65 }, -- and the blue laid under the fish (BACK)
	{ "Clears near", nil, nil }, -- Now from the spawn, C at the edge
	{ "Thin picture", { 0.82, 0.92, 0.93, 0.93 }, 0.88 }, -- C, the drifting picture fainter: its cells are solid blue, so it tints too
	{ "Best of", nil, nil }, -- Now from the spawn; clear with a thin picture at the edge (goes with FarBlue, Caustics, Shoal)
	{ "Clear + blue", { 0.85, 0.94, 1, 1 }, 0.85 }, -- nearly nothing over the fish, all the blue behind them (BACK)
}
local ADDS = { "Shoal", "Shapes", "Fins", "Caustics", "Rings", "Glints", "Waves", "Shelf", "Buoys", "Glow", "Lap", "Outline", "Test", "FarBlue" }

local function part(props, class)
	local p = Instance.new(class or "Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	if p:IsA("Part") then
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	end
	for k, v in props do
		p[k] = v
	end
	p.Parent = p.Parent or root
	return p
end

local models = ReplicatedStorage:FindFirstChild("FishModels")
local function fish(id, long, flat)
	local made = models:FindFirstChild(id):Clone()
	for _, d in made:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery, d.CastShadow = true, false, false, false, false
		elseif d:IsA("Script") or d:IsA("Motor6D") or d:IsA("Trail") then
			d:Destroy()
		end
	end
	made:ScaleTo(long / math.max(select(2, made:GetBoundingBox()).Z, 1))
	if flat then -- its shape pressed flat and painted dark
		local mid = made:GetBoundingBox().Position.Y
		for _, d in made:GetDescendants() do
			if d:IsA("BasePart") then
				local p = d.Position
				d.Size = Vector3.new(d.Size.X, d.Size.Y * 0.03, d.Size.Z)
				d.CFrame = CFrame.new(p.X, mid + (p.Y - mid) * 0.03, p.Z) * d.CFrame.Rotation
				d.Color = Color3.fromRGB(8, 40, 84)
				d.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	made.Parent = root
	return made
end

local KINDS = { { "YellowTang", 9 }, { "Clownfish", 9 }, { "SergeantMajor", 9 }, { "Parrotfish", 12 }, { "Pufferfish", 10 }, { "Stingray", 14 }, { "Barracuda", 18 }, { "LeopardShark", 22 } }
local function ring(i) -- where the i-th swims: its middle, how wide its loop is, how fast, where it starts
	local h = (math.sin(i * 12.9898) * 43758.5453) % 1
	local h2 = (math.sin(i * 78.233) * 24634.6345) % 1
	return X - 46 + 92 * h, 30 + 130 * h2, 14 + 22 * ((h * 7.3) % 1), 7 + 5 * h2, h * 6.28
end
local function loop(i, t)
	local cx, cz, r, v, a = ring(i)
	local w = a + t * v / r
	local p = Vector3.new(cx + math.cos(w) * r, 0, cz + math.sin(w) * r * 0.6)
	local ahead = Vector3.new(cx + math.cos(w + 0.05) * r, 0, cz + math.sin(w + 0.05) * r * 0.6)
	return p, ahead
end

-- each add-on: made once, then stepped each frame while on
local made, steps = {}, {}
local function put(name, inst)
	made[name] = made[name] or {}
	table.insert(made[name], inst)
	return inst
end
local build = {}

function build.Shoal() -- fish near the top, past the edge (stands for: the herd swims up to the mouth)
	local all = {}
	for i = 1, 22 do
		local k = KINDS[(i - 1) % #KINDS + 1]
		all[i] = put("Shoal", fish(k[1], k[2] * 1.15))
	end
	steps.Shoal = function(t)
		for i, m in all do
			local p, a = loop(i, t)
			local y = Vector3.new(0, -5.5 - (i % 5) * 1.6, 0)
			m:PivotTo(CFrame.lookAt(p + y, a + y))
		end
	end
end
function build.Shapes() -- dark shapes pressed flat just under the top, in place of seeing the fish
	local all = {}
	for i = 1, 14 do
		local k = KINDS[(i + 4) % #KINDS + 1]
		all[i] = put("Shapes", fish(k[1], k[2] * 1.5, true))
	end
	steps.Shapes = function(t)
		for i, m in all do
			local p, a = loop(i + 40, t)
			m:PivotTo(CFrame.lookAt(p + Vector3.new(0, -4.2, 0), a + Vector3.new(0, -4.2, 0)))
		end
	end
end
function build.Fins() -- fins cutting the top, each with a foam V
	local all = {}
	for i = 1, 6 do
		local fin = put("Fins", part({ Size = Vector3.new(0.8, 4.2, 4.6), Color = Color3.fromRGB(62, 84, 112) }, "WedgePart"))
		local foam = {}
		for s = -1, 1, 2 do
			table.insert(foam, put("Fins", part({ Size = Vector3.new(0.7, 0.25, 7), Color = Color3.fromRGB(245, 252, 255), Material = Enum.Material.Neon })))
		end
		all[i] = { fin, foam }
	end
	steps.Fins = function(t)
		for i, f in all do
			local p, a = loop(i + 70, t * 1.4)
			local cf = CFrame.lookAt(p, a)
			f[1].CFrame = cf * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.pi, 0)
			f[2][1].CFrame = cf * CFrame.new(-1.6, 0.16, 3.6) * CFrame.Angles(0, math.rad(-16), 0)
			f[2][2].CFrame = cf * CFrame.new(1.6, 0.16, 3.6) * CFrame.Angles(0, math.rad(16), 0)
		end
	end
end
function build.Caustics() -- moving light on the sea's floor: the water's own picture on the floor's own (opaque) tiles
	local box = OverlapParams.new()
	box.MaxParts = 4000
	local all = {}
	for _, p in workspace:GetPartBoundsInBox(CFrame.new(X, -52, 130), Vector3.new(320, 18, 300), box) do
		if p.Position.Z - p.Size.Z / 2 > -6 and p.Position.Y + p.Size.Y / 2 < -40 and p.Transparency < 0.2 and p.Size.X >= 12 and p.Size.Z >= 12 and not p:FindFirstAncestor("Props") and not p:IsDescendantOf(root) then
			local tx = put("Caustics", Instance.new("Texture"))
			tx.Name = "WaterTrialLight"
			tx.Texture, tx.Face = "rbxassetid://6126332496", Enum.NormalId.Top
			tx.StudsPerTileU, tx.StudsPerTileV = 40, 40
			tx.Color3 = Color3.fromRGB(255, 255, 255)
			tx.Transparency = 0.25
			tx.ZIndex = 5
			tx.Parent = p
			table.insert(all, tx)
		end
	end
	root:SetAttribute("CausticTiles", #all)
	steps.Caustics = function(t)
		for _, tx in all do
			tx.OffsetStudsU, tx.OffsetStudsV = (t * 3) % 40, (t * 1.6 + math.sin(t * 0.9) * 2) % 40
		end
	end
end
function build.Rings() -- a spreading ring on the top over a fish near it
	local all = {}
	for i = 1, 10 do
		local slabs = {}
		for k = 1, 10 do
			slabs[k] = put("Rings", part({ Size = Vector3.new(0.45, 0.2, 2), Color = Color3.fromRGB(245, 252, 255), Material = Enum.Material.Neon }))
		end
		all[i] = slabs
	end
	steps.Rings = function(t)
		for i, slabs in all do
			local age = (t / 2.6 + i * 0.37) % 1
			local p = loop(i, math.floor(t / 2.6 + i * 0.37) * 2.6)
			local r = 1 + 7 * age ^ 0.6
			for k, s in slabs do
				local w = k / #slabs * 2 * math.pi
				s.Size = Vector3.new(0.5 * (1 - age) + 0.05, 0.16, r * 0.46)
				s.CFrame = CFrame.new(p + Vector3.new(math.cos(w) * r, 0.12, math.sin(w) * r)) * CFrame.Angles(0, -w, 0)
				s.Transparency = age
			end
		end
	end
end
function build.Glints() -- twinkles on the top
	local pad = put("Glints", part({ Size = Vector3.new(260, 0.2, 320), CFrame = CFrame.new(X, 0.6, 170), Transparency = 1 }))
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate, e.Lifetime, e.Speed = 70, NumberRange.new(0.5, 1), NumberRange.new(0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1.6), NumberSequenceKeypoint.new(1, 0) })
	e.LightEmission, e.LightInfluence = 1, 0
	e.Parent = pad
	pad:SetAttribute("Emits", true)
end
function build.Waves() -- soft white bands rolling in to the hub
	local all = {}
	for i = 1, 5 do
		local row = {}
		for k = 1, 9 do
			row[k] = put("Waves", part({ Size = Vector3.new(16, 0.16, 1.4), Color = Color3.fromRGB(240, 250, 255), Material = Enum.Material.Neon }))
		end
		all[i] = row
	end
	steps.Waves = function(t)
		for i, row in all do
			local age = (t / 14 + i / #all) % 1
			local z = 120 - 119 * age
			for k, s in row do
				local x = -64 + (k - 1) * 16 + math.sin(i * 5) * 8
				local bend = math.sin(k * 0.9 + i * 2 + t * 0.3) * 2.4
				local long = 10 + 6 * math.sin(k * 2.3 + i * 1.7)
				s.Size = Vector3.new(math.max(4, long), 0.16, 0.5 + 1.3 * age)
				s.CFrame = CFrame.new(X + x, 0.12, z + bend)
				s.Transparency = 1 - 0.75 * math.sin(math.pi * math.min(1, age * 1.02)) * (0.45 + 0.55 * age)
			end
		end
	end
end
function build.Shelf() -- steps of sand going down from the edge under clear water
	for j, s in { { 0, 14, -5 }, { 14, 28, -12 }, { 28, 42, -21 }, { 42, 56, -32 } } do
		put("Shelf", part({ Size = Vector3.new(110, 47 + s[3], s[2] - s[1]), CFrame = CFrame.new(X, (s[3] - 47) / 2, (s[1] + s[2]) / 2), Color = j % 2 == 1 and Color3.fromRGB(232, 222, 176) or Color3.fromRGB(222, 211, 164) }))
	end
end
function build.Buoys() -- a float line and a few buoys: something on the top, with foam round it and a size you know
	for i = 0, 10 do
		put("Buoys", part({ Shape = Enum.PartType.Block, Size = Vector3.new(2.2, 2.2, 2.2), Color = i % 2 == 0 and Color3.fromRGB(236, 72, 60) or Color3.fromRGB(250, 248, 240) }))
	end
	local set = made.Buoys
	steps.Buoys = function(t)
		for i, b in set do
			local x = X - 45 + (i - 1) * 9
			b.CFrame = CFrame.new(x, 0.2 + math.sin(t * 1.2 + i * 0.8) * 0.35, 58 + math.sin(i * 0.63) * 7) * CFrame.Angles(math.sin(t + i) * 0.12, 0, math.cos(t * 0.9 + i) * 0.12)
		end
	end
end
function build.Glow() -- a soft column of light standing over the rarer fish
	for i = 1, 4 do
		put("Glow", part({ Size = Vector3.new(2.4, 18, 2.4), Color = ({ Color3.fromRGB(80, 170, 255), Color3.fromRGB(190, 90, 255), Color3.fromRGB(255, 190, 50), Color3.fromRGB(80, 170, 255) })[i], Material = Enum.Material.Neon, Transparency = 0.7 }))
	end
	local set = made.Glow
	steps.Glow = function(t)
		for i, b in set do
			local p = loop(i * 3, t)
			b.CFrame = CFrame.new(p + Vector3.new(0, 4, 0))
		end
	end
end
function build.Lap() -- foam lapping along the strip's edge
	for k = 1, 24 do
		put("Lap", part({ Size = Vector3.new(4.4, 0.2, 2), Color = Color3.fromRGB(246, 252, 255), Material = Enum.Material.Neon, Transparency = 0.15 }))
	end
	local set = made.Lap
	steps.Lap = function(t)
		for k, s in set do
			local w = 1.2 + 1.1 * (0.5 + 0.5 * math.sin(t * 1.1 + k * 0.9)) + 0.6 * math.sin(k * 2.7)
			s.Size = Vector3.new(4.4, 0.16, math.max(0.5, w))
			s.CFrame = CFrame.new(X - 50.6 + k * 4.2 - 2, 0.12, math.max(0.5, w) / 2)
		end
	end
end

function build.Outline() -- Roblox's own outline on a few fish near the top, in the rarity's colour
	local all = {}
	for i = 1, 5 do
		local k = KINDS[(i * 2) % #KINDS + 1]
		local m = put("Outline", fish(k[1], k[2] * 1.2))
		local h = Instance.new("Highlight")
		h.FillTransparency, h.OutlineTransparency = 1, 0
		h.OutlineColor = ({ Color3.fromRGB(80, 200, 255), Color3.fromRGB(200, 90, 255), Color3.fromRGB(255, 200, 40) })[i % 3 + 1]
		h.DepthMode = i % 2 == 0 and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
		h.Parent = m
		all[i] = m
	end
	steps.Outline = function(t)
		for i, m in all do
			local p, a = loop(i + 20, t)
			local y = Vector3.new(0, -7, 0)
			m:PivotTo(CFrame.lookAt(p + y, a + y))
		end
	end
end
function build.Test() -- does glass hide what is see-through under it? From the left: solid, half see-through, Neon, half see-through Neon, particles, a lamp board
	local mats = { { "SmoothPlastic", 0 }, { "SmoothPlastic", 0.5 }, { "Neon", 0 }, { "Neon", 0.5 } }
	for i, m in mats do
		put("Test", part({ Size = Vector3.new(5, 5, 5), CFrame = CFrame.new(X - 25 + i * 9, -8, 40), Color = Color3.fromRGB(255, 60, 160), Material = Enum.Material[m[1]], Transparency = m[2] }))
	end
	local e = put("Test", part({ Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(X + 20, -8, 40), Transparency = 1 }))
	local pe = Instance.new("ParticleEmitter")
	pe.Texture, pe.Rate, pe.Lifetime, pe.Speed = "rbxasset://textures/particles/explosion01_implosion_main.dds", 14, NumberRange.new(1), NumberRange.new(0)
	pe.Size, pe.Color, pe.LightEmission, pe.LightInfluence = NumberSequence.new(6), ColorSequence.new(Color3.fromRGB(255, 220, 60)), 0, 0
	pe.Parent = e
	local b = put("Test", part({ Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(X + 30, -8, 40), Transparency = 1 }))
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromScale(8, 4)
	local tl = Instance.new("TextLabel")
	tl.Size, tl.Text, tl.TextScaled, tl.BackgroundColor3 = UDim2.fromScale(1, 1), "RARE", true, Color3.fromRGB(255, 220, 60)
	tl.Parent = g
	g.Parent = b
end

build["FarBlue"] = function() -- one soft sheet just under the layers: nothing near the edge, the sea's blue further out (no joins)
	local a = put("FarBlue", part({ Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(X, -9.2, 70), Transparency = 1 }))
	local e = put("FarBlue", part({ Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(X, -9.2, 900), Transparency = 1 }))
	-- a Beam lies in the plane of its attachments' X (along) and Z; Y up makes it lie flat
	local at0, at1 = Instance.new("Attachment"), Instance.new("Attachment")
	at0.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, -Vector3.xAxis)
	at1.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, -Vector3.xAxis)
	at0.Parent, at1.Parent = a, e
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1, b.FaceCamera, b.Segments = at0, at1, false, 40
	b.Width0, b.Width1 = 1200, 1200
	b.LightEmission, b.LightInfluence, b.ZOffset = 0, 0, 0
	b.Color = ColorSequence.new(Color3.fromRGB(24, 132, 222))
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.8), NumberSequenceKeypoint.new(0.22, 0.4), NumberSequenceKeypoint.new(0.4, 0.2), NumberSequenceKeypoint.new(1, 0.15) })
	b.Parent = a
	root:SetAttribute("FarSpan", 830)
end

-- the blue laid under the fish: only for an eye above the water
local BACK = {}
for i, z in { 0, 80, 160, 260, 400 } do
	local z2 = ({ 80, 160, 260, 400, 1000 })[i]
	local y = ({ -43.5, -45.5, -48, -51, -55 })[i]
	BACK[i] = part({ Name = "Back", Size = Vector3.new(900, 0.2, z2 - z), CFrame = CFrame.new(X, y, (z + z2) / 2), Transparency = 1,
		Color = Color3.fromRGB(40, 150, 205):Lerp(Color3.fromRGB(18, 72, 150), (i - 1) / 4) })
end

local function setSee(v, pic, back)
	for k, name in NAMES do
		local p = layers:FindFirstChild(name)
		if p then
			p.Transparency = v[k]
		end
	end
	local w = layers:FindFirstChild("Water1")
	local tx = w and w:FindFirstChildOfClass("Texture")
	if tx then
		tx.Transparency = pic
	end
	for _, b in BACK do
		b.Transparency = back and 0 or 1
	end
end

root:SetAttribute("See", 1)
for _, n in ADDS do
	root:SetAttribute(n, false)
end

local gui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("WaterTrialGui") or Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "WaterTrialGui", false, 500
gui:ClearAllChildren()
local refresh = {}
local function row(y, names, press, lit)
	local f = Instance.new("Frame")
	f.Size, f.Position, f.BackgroundTransparency = UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 1, y), 1
	f.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection, list.Padding, list.HorizontalAlignment = Enum.FillDirection.Horizontal, UDim.new(0, 4), Enum.HorizontalAlignment.Center
	list.Parent = f
	for i, n in names do
		local b = Instance.new("TextButton")
		b.Size, b.Text, b.Font, b.TextSize = UDim2.fromOffset(98, 30), n, Enum.Font.GothamBold, 13
		b.Parent = f
		b.Activated:Connect(function()
			press(i, n)
		end)
		table.insert(refresh, function()
			local on = lit(i, n)
			b.BackgroundColor3 = on and Color3.fromRGB(255, 210, 60) or Color3.fromRGB(30, 40, 60)
			b.TextColor3 = on and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
		end)
	end
end
local seeNames = {}
for i, s in SEE do
	seeNames[i] = s[1]
end
row(-196, seeNames, function(i)
	root:SetAttribute("See", i)
end, function(i)
	return root:GetAttribute("See") == i
end)
row(-162, ADDS, function(_, n)
	root:SetAttribute(n, not root:GetAttribute(n))
end, function(_, n)
	return root:GetAttribute(n)
end)
gui.Parent = game.Players.LocalPlayer.PlayerGui

local shown = {}
local began = os.clock()
local con
con = RunService.Heartbeat:Connect(function()
	if not root.Parent then
		con:Disconnect()
		return
	end
	local t = os.clock() - began
	local eye = workspace.CurrentCamera.CFrame.Position
	local i = root:GetAttribute("See")
	local s = SEE[i] or SEE[1]
	if s[2] then
		setSee(s[2], s[3], (i == 6 or i == 10) and eye.Y > 0)
	else
		local k = math.clamp((-eye.Z - 20) / 65, 0, 1) -- 1 at the spawn, 0 at the edge
		local a, b, v = i == 9 and { 0.78, 0.9, 0.93, 0.93 } or SEE[4][2], SEE[1][2], {}
		for j = 1, 4 do
			v[j] = a[j] + (b[j] - a[j]) * k
		end
		setSee(v, (i == 9 and 0.82 or 0.7) * (1 - k) + 0.6 * k, false)
	end
	for _, n in ADDS do
		local on = root:GetAttribute(n) == true and (eye.Y > 0 or (n ~= "Caustics" and n ~= "FarBlue")) -- those two: from above only
		if on and not made[n] then
			made[n] = {}
			build[n]()
			shown[n] = true
		end
		if made[n] and shown[n] ~= on then
			shown[n] = on
			for _, m in made[n] do
				if m:IsA("Texture") then
					m.Transparency = on and 0.25 or 1
				else
					m.Parent = on and root or nil
				end
			end
		end
		if on and steps[n] then
			steps[n](t)
		end
	end
	for _, f in refresh do
		f()
	end
end)
return "water trial up: " .. #SEE .. " see-throughs, " .. #ADDS .. " add-ons"
