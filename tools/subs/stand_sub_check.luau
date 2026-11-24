-- The little submarine over the submarine stand, checked without Studio: runs the real
-- src/client/Controllers/SubStandController.luau and src/shared/SubModels.luau (its placeholder subs: no meshes
-- here) against a made-up stand of the hub kit's sizes, on a mock Instance tree with Lune's Roblox datatypes for the
-- maths. It checks the numbers (where it floats, how big, what is taken off it, when it is made and taken away), not
-- the look: that is Studio's.
-- Usage: lune run tools/subs/stand_sub_check.luau <the repo's folder>   (Lune 0.11; it is not in rokit.toml: on
-- Hugo's PC, ~/.rokit/tool-storage/lune-org/lune/0.11.1/lune)
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOT = process.args[1]
local V3, CF = roblox.Vector3, roblox.CFrame

local BASE = { Part = true, MeshPart = true }
local LIGHT = { SpotLight = true, PointLight = true }
local function mock(class: string)
	local props: { [string]: any } = { Name = class, ClassName = class }
	local kids = {}
	local attrs = {}
	local parent = nil
	local self
	local methods = {}
	function methods.IsA(_, name)
		return class == name
			or (name == "BasePart" and BASE[class] == true)
			or (name == "Light" and LIGHT[class] == true)
			or name == "Instance"
	end
	function methods.GetChildren(_)
		return table.clone(kids)
	end
	function methods.GetDescendants(_)
		local out = {}
		local function walk(n)
			for _, k in n:GetChildren() do
				table.insert(out, k)
				walk(k)
			end
		end
		walk(self)
		return out
	end
	function methods.FindFirstChild(_, name, deep)
		for _, k in kids do
			if k.Name == name then
				return k
			end
		end
		if deep then
			for _, k in kids do
				local f = k:FindFirstChild(name, true)
				if f then
					return f
				end
			end
		end
		return nil
	end
	function methods.FindFirstChildWhichIsA(_, name)
		for _, k in kids do
			if k:IsA(name) then
				return k
			end
		end
		return nil
	end
	function methods.Destroy(_)
		self.Parent = nil
		for _, k in table.clone(kids) do
			k:Destroy()
		end
	end
	function methods.SetAttribute(_, k, v)
		attrs[k] = v
	end
	function methods.GetAttribute(_, k)
		return attrs[k]
	end
	methods._kids = function()
		return kids
	end
	self = setmetatable({}, {
		__index = function(_, k)
			if methods[k] then
				return methods[k]
			elseif k == "Parent" then
				return parent
			elseif k == "Position" then
				return props.CFrame.Position
			end
			local v = props[k]
			if v == nil then
				local kid = methods.FindFirstChild(nil, k)
				if kid then
					return kid
				end
			end
			return v
		end,
		__newindex = function(_, k, v)
			if k == "Parent" then
				if parent then
					local list = parent._kids()
					table.remove(list, table.find(list, self))
				end
				parent = v
				if v then
					table.insert(v._kids(), self)
				end
			else
				props[k] = v
			end
		end,
	})
	if BASE[class] then
		props.Size = V3.new(4, 1, 2)
		props.CFrame = CF.new()
		props.Transparency = 0
	elseif class == "BillboardGui" then
		props.StudsOffset = V3.zero
		props.StudsOffsetWorldSpace = V3.zero
	end
	return self
end

local workspace = mock("Workspace")
local camera = mock("Camera")
camera.CFrame = CF.new(0, 0, 0)
workspace.CurrentCamera = camera

local now = 100
local stepped, equipChanged
local equip: any = nil
local Config = { Sub = { On = 1 } }
local modules = {}
local replicated = {
	Shared = { Config = "Config", SubModels = "SubModels" },
	FindFirstChild = function()
		return nil
	end,
}
local services = {
	ReplicatedStorage = replicated,
	RunService = { RenderStepped = {
		Connect = function(_, f)
			stepped = f
		end,
	} },
	Players = {
		LocalPlayer = {
			GetAttribute = function(_, name)
				return if name == "SubEquip" then equip else nil
			end,
			GetAttributeChangedSignal = function()
				return {
					Connect = function(_, f)
						equipChanged = f
					end,
				}
			end,
		},
	},
}
local env = {
	game = {
		GetService = function(_, name)
			return services[name]
		end,
		IsLoaded = function()
			return true
		end,
	},
	workspace = workspace,
	Instance = { new = mock },
	Vector3 = V3,
	CFrame = CF,
	Color3 = roblox.Color3,
	UDim2 = roblox.UDim2,
	Vector2 = roblox.Vector2,
	Enum = roblox.Enum,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	ColorSequence = roblox.ColorSequence,
	os = { clock = function()
		return now
	end },
	require = function(key)
		return modules[key]
	end,
}
local function load(path: string)
	return luau.load(fs.readFile(ROOT .. "/" .. path), { debugName = path, environment = env })()
end
modules.Config = Config
modules.SubModels = load("src/shared/SubModels.luau")
local Controller = load("src/client/Controllers/SubStandController.luau")
Controller.Start()
assert(stepped and equipChanged, "not connected")

-- A stall as the hub kit sizes it (FIT 0.5, 0.7, 0.64): roof 8.82 over the floor, name's middle 23.1 over it
local FLOOR = 100
local function stall(at)
	local blockout = workspace:FindFirstChild("ClaudeBlockout") or mock("Folder")
	blockout.Name = "ClaudeBlockout"
	blockout.Parent = workspace
	local dock = blockout:FindFirstChild("Dock") or mock("Folder")
	dock.Name = "Dock"
	dock.Parent = blockout
	local stations = dock:FindFirstChild("Stations") or mock("Folder")
	stations.Name = "Stations"
	stations.Parent = dock
	local stand = mock("Model")
	stand.Name = "Sub"
	local function box(name, x, y, z, sx, sy, sz, pitch, t)
		local p = mock("Part")
		p.Name = name
		p.Size = V3.new(sx, sy, sz)
		p.CFrame = CF.new(at + V3.new(x, y + sy / 2, z)) * CF.Angles(math.rad(pitch or 0), 0, 0)
		p.Transparency = t or 0
		p.Parent = stand
		return p
	end
	for _, sx in { -4, 4 } do
		box("Post", sx, 0, 2.24, 1, 6.3, 1.28)
		box("Post", sx, 0, -2.24, 1, 8.4, 1.28)
	end
	box("Counter", 0, 0, 2.24, 7, 2.38, 1.92)
	box("Awning", 0, 8.12, -2, 10, 0.7, 2.56, 0) -- top at 8.82
	box("Awning", 0, 6.6, 1, 10, 0.7, 2.56, 22)
	box("Ring", 0, 0.02, 10.2, 11.5, 0.1, 11.5, 0, 1)
	local title = box("Title", 0, 23.1 - 0.35, 0, 0.5, 0.7, 0.64, 0, 1)
	local bill = mock("BillboardGui")
	bill.Name = "Name"
	bill.Size = roblox.UDim2.fromScale(13.5, 4.95)
	bill.Parent = title
	stand.Parent = stations
	return stand, title, bill
end

local function frame(dt, times)
	for _ = 1, times or 1 do
		now += dt
		stepped(dt)
	end
end
local function sub()
	return camera:FindFirstChild("StandSub")
end
-- the sub's box now (world axes), and what is left on it
local function box(model)
	local lo, hi = V3.one * math.huge, V3.one * -math.huge
	local n, bad, spins = 0, 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			local cf, s = d.CFrame, d.Size
			local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
			local half = V3.new(
				math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z,
				math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z,
				math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z
			) / 2
			lo, hi = lo:Min(d.Position - half), hi:Max(d.Position + half)
			if d.CanCollide or d.CanQuery or d.CanTouch or d.CastShadow or not d.Anchored then
				bad += 1
			end
			if d.Name == "Prop" or d.Name == "Prop_Glow" then
				spins += 1
			end
		elseif d:IsA("BillboardGui") or d:IsA("Light") then
			bad += 100
		end
	end
	return lo, hi, n, bad, spins
end
local fails = 0
local function expect(what, ok, got)
	if not ok then
		fails += 1
	end
	print((if ok then "ok   " else "FAIL ") .. what .. (if got then "  [" .. tostring(got) .. "]" else ""))
end

-- 1. no stand: nothing
frame(1 / 60, 90)
expect("no stand, no sub", sub() == nil)

-- 2. the stand is there: the sub is made over it
local at = V3.new(500, FLOOR, -300)
local stand, title, bill = stall(at)
camera.CFrame = CF.new(at + V3.new(0, 10, 40))
frame(1 / 60, 61)
local m = sub()
expect("sub made when the stand is there", m ~= nil)
local roofY, edgeY = FLOOR + 8.82, FLOOR + 23.1 - 4.95 / 2
local lowest, highest, widest = math.huge, -math.huge, 0
local function watch(seconds)
	lowest, highest, widest = math.huge, -math.huge, 0
	for _ = 1, seconds * 60 do
		frame(1 / 60)
		local lo, hi = box(sub())
		lowest, highest = math.min(lowest, lo.Y), math.max(highest, hi.Y)
		widest = math.max(widest, hi.X - lo.X, hi.Z - lo.Z)
	end
end
watch(20)
local lo, hi, n, bad, spins = box(m)
print(string.format(
	"     tier 1 placeholder: %d parts, floats %.2f to %.2f over the floor (roof %.2f, name's edge %.2f), widest %.2f studs",
	n,
	lowest - FLOOR,
	highest - FLOOR,
	roofY - FLOOR,
	edgeY - FLOOR,
	widest
))
expect("clear of the roof by 2.5 at its lowest", math.abs((lowest - roofY) - 2.5) < 0.05, lowest - roofY)
expect("under the name's lower edge by 1 or more", edgeY - highest >= 1, edgeY - highest)
expect("about 8 studs long (7 to 8.1 across at its widest)", widest > 7 and widest <= 8.1, widest)
expect("no sign, no light, no collision, no query, no touch, no shadow, anchored", bad == 0, bad)
expect("a propeller part to spin", spins >= 1, spins)
expect("named StandSub, tier 1", m.Name == "StandSub" and m:GetAttribute("Tier") == 1)
local mid = (lo + hi) / 2
expect("over the stall's middle (the Title)", math.abs(mid.X - at.X) < 1.2 and math.abs(mid.Z - at.Z) < 1.2, mid - at)

-- 3. it bobs, turns and the propeller spins about the sub's long axis
local prop, hull = m:FindFirstChild("Prop"), m:FindFirstChild("Hull")
local function axis()
	-- the sub's long axis is the hull cylinder's X; the propeller's own Z should stay along it
	return prop.CFrame.LookVector:Dot(hull.CFrame.RightVector)
end
local y0, look0, up0 = hull.Position.Y, hull.CFrame.RightVector, prop.CFrame.UpVector
local rel0 = hull.CFrame:ToObjectSpace(prop.CFrame).Position
frame(1 / 60, 30)
local rel1 = hull.CFrame:ToObjectSpace(prop.CFrame).Position
expect("bobs", math.abs(hull.Position.Y - y0) > 0.02, hull.Position.Y - y0)
expect("turns slowly (10 degrees in half a second)", math.abs(math.deg(math.acos(math.clamp(look0:Dot(hull.CFrame.RightVector), -1, 1))) - 10) < 0.5)
expect("propeller spins about the long axis", math.abs(math.abs(axis()) - 1) < 1e-3 and (rel1 - rel0).Magnitude < 1e-3, axis())
expect("propeller has turned", up0:Dot(prop.CFrame.UpVector) < 0.999)

-- 4. another sub equipped: the display changes at once
equip = 9
equipChanged()
frame(1 / 60)
local m9 = sub()
expect("tier 9 shown after equipping it, the old one gone", m9 ~= nil and m9 ~= m and m9:GetAttribute("Tier") == 9 and m.Parent == nil)
expect("only one sub", #camera:GetChildren() == 1, #camera:GetChildren())
watch(20)
local _, _, n9, bad9 = box(m9)
print(string.format("     tier 9 placeholder: %d parts, floats %.2f to %.2f over the floor, widest %.2f", n9, lowest - FLOOR, highest - FLOOR, widest))
expect("tier 9 clear of roof and name", math.abs((lowest - roofY) - 2.5) < 0.05 and edgeY - highest >= 1 and bad9 == 0)

-- 5. the stand is taken away, then rebuilt somewhere else
stand:Destroy()
frame(1 / 60, 61)
expect("gone with the stand", sub() == nil)
local at2 = V3.new(-200, FLOOR + 30, 80)
local stand2, _, bill2 = stall(at2)
camera.CFrame = CF.new(at2 + V3.new(0, 10, 40))
frame(1 / 60, 61)
local lo2, hi2 = box(sub())
local mid2 = (lo2 + hi2) / 2
expect("made again over the rebuilt stand", math.abs(mid2.X - at2.X) < 1.2 and math.abs(mid2.Z - at2.Z) < 1.2 and lo2.Y > at2.Y + 8.82 + 2.4, mid2 - at2)

-- 6. a part streams in above the roof: the sub moves up, the same model
local was = sub()
local pole = mock("Part")
pole.Name = "Flag"
pole.Size = V3.new(0.5, 3, 0.5)
pole.CFrame = CF.new(at2 + V3.new(0, 8.82 + 1.5, 0))
pole.Parent = stand2
frame(1 / 60, 61)
watch(4)
expect("moves up when the stall grows taller", math.abs(lowest - (at2.Y + 11.82 + 2.5)) < 0.05, lowest - at2.Y)
expect("still under the name (by 1, the least)", (at2.Y + 23.1 - 4.95 / 2) - highest >= 0.999, (at2.Y + 23.1 - 4.95 / 2) - highest)

-- 7. a low name: the sub is made smaller, never under half size
bill2.Size = roblox.UDim2.fromScale(13.5, 16) -- its lower edge now 15.1 over the floor: 3.28 of room over the pole
frame(1 / 60, 61)
watch(20)
expect("made again for the smaller room", sub() ~= was)
print(string.format("     low name: floats %.2f to %.2f over the floor (name's edge %.2f), widest %.2f", lowest - at2.Y, highest - at2.Y, 23.1 - 8, widest))
expect("smaller, at least half size", widest >= 3.5 and widest < 7, widest)

-- 8. far from the camera: left still
camera.CFrame = CF.new(at2 + V3.new(0, 0, 1000))
frame(1 / 60, 61)
local h = sub():FindFirstChild("Hull").CFrame
frame(1 / 60, 30)
expect("still when far away", sub():FindFirstChild("Hull").CFrame == h)
camera.CFrame = CF.new(at2 + V3.new(0, 10, 40))

-- 9. no Title on the stand: still made, over the stall's box
local t2 = stand2:FindFirstChild("Title")
t2:Destroy()
frame(1 / 60, 61)
local lo3, hi3 = box(sub())
expect("made without a Title, over the stall", sub() ~= nil and math.abs((lo3.X + hi3.X) / 2 - at2.X) < 1.2 and math.abs((lo3.Z + hi3.Z) / 2 - at2.Z) < 5, (lo3 + hi3) / 2 - at2)

-- 10. submarines switched off in Config
Config.Sub.On = 0
frame(1 / 60, 61)
expect("off with Config.Sub.On 0", sub() == nil and #camera:GetChildren() == 0)

print(if fails == 0 then "ALL OK" else fails .. " FAILED")
process.exit(if fails == 0 then 0 else 1)
