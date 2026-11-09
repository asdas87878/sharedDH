-- Runs tools/studio/claude_blockout.luau offline in Lune on a place (a rojo build), saves the place with the map in
-- it, then reloads the saved file and counts what's in it. Also dumps every part (for tools/art/map_plot.py's top view).
-- usage (Lune 0.11, any folder where rokit finds lune): lune run <this> <in.rbxl> <script.luau> <out.rbxl> <out.json>
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local process = require("@lune/process")

local inPath, scriptPath, outPath, jsonPath = process.args[1], process.args[2], process.args[3], process.args[4]
local game = roblox.deserializePlace(fs.readFile(inPath))
local workspace = game:GetService("Workspace")

-- Random shim (Lune has no Random datatype); deterministic per seed, not Studio's exact sequence
local Random = {}
Random.__index = Random
function Random.new(seed)
	local s = math.floor((seed or os.time()) % 2147483647)
	if s <= 0 then s = s + 2147483646 end
	return setmetatable({ s = s }, Random)
end
function Random:_next()
	self.s = (self.s * 16807) % 2147483647
	return (self.s - 1) / 2147483646
end
function Random:NextNumber(a, b)
	local r = self:_next()
	if a == nil then return r end
	return a + (b - a) * r
end
function Random:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_next())
end

local HttpService = { JSONEncode = function(_, v) return serde.encode("json", v) end }
local fakeGame = setmetatable({
	GetService = function(_, name)
		if name == "HttpService" then return HttpService end
		return game:GetService(name)
	end,
}, { __index = function(_, k) return (game :: any)[k] end })

local env = setmetatable({
	game = fakeGame, workspace = workspace, Workspace = workspace,
	Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
	BrickColor = roblox.BrickColor, Enum = roblox.Enum, UDim2 = roblox.UDim2, UDim = roblox.UDim,
	Vector2 = roblox.Vector2, NumberSequence = roblox.NumberSequence, ColorSequence = roblox.ColorSequence,
	NumberRange = roblox.NumberRange, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, Font = roblox.Font, Random = Random,
	task = { wait = function() end, defer = function(f, ...) f(...) end, spawn = function(f, ...) f(...) end },
}, { __index = _G })

local fn = luau.load(fs.readFile(scriptPath), { debugName = scriptPath, environment = env })
local result = fn()
for _, d in workspace:GetDescendants() do
	if d:IsA("TextLabel") then
		(d :: any).FontFace = roblox.Font.fromEnum(roblox.Enum.Font.FredokaOne)
	end
end
fs.writeFile(outPath, roblox.serializePlace(game))
print("wrote", outPath)

-- reload and verify
local check = roblox.deserializePlace(fs.readFile(outPath))
local map = check:GetService("Workspace"):FindFirstChild("ClaudeBlockout")
local parts, models, scripts = 0, 0, 0
local dump = {}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		local cf = d.CFrame
		local p = cf.Position
		local c = d.Color
		local rx, ry, rz = cf:ToEulerAnglesYXZ()
		table.insert(dump, {
			n = d.Name, x = p.X, y = p.Y, z = p.Z, sx = d.Size.X, sy = d.Size.Y, sz = d.Size.Z,
			r = { cf.XVector.X, cf.XVector.Z, cf.YVector.X, cf.YVector.Z, cf.ZVector.X, cf.ZVector.Z },
			top = p.Y + (math.abs(cf.XVector.Y) * d.Size.X + math.abs(cf.YVector.Y) * d.Size.Y + math.abs(cf.ZVector.Y) * d.Size.Z) / 2,
			shape = if d:IsA("Part") then (d :: any).Shape.Name else "Block", c = { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) }, t = d.Transparency,
		})
	elseif d:IsA("Model") and d:GetAttribute("PropName") then
		models += 1
	end
end
for _, d in check:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		scripts += 1
	end
end
local dive = map:FindFirstChild("Dive")
print(string.format("reloaded: %d parts in ClaudeBlockout, %d prop Models, %d scripts in the place, Path attribute %s",
	parts, models, scripts, if dive and dive:GetAttribute("Path") then "present" else "MISSING"))
local zones = if type(result) == "string" then serde.decode("json", result) else {}
zones.Parts = parts
zones.PropModels = models
zones.PartDump = dump
fs.writeFile(jsonPath, serde.encode("json", zones))
print("result:", if type(result) == "string" then string.sub(result, 1, 400) else tostring(result))
