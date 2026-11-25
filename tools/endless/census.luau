-- What the saved place holds, for the endless study (NULLROOM task e1): every instance of the lane with its box, its
-- colour and its kind, and the place's streaming and kill-height settings. Offline; the place is only read.
-- usage: lune run tools/endless/census.luau <place.rbxl> <out folder>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local slim = require("./slim")

local place, out = process.args[1], process.args[2]
assert(place and out, "usage: census.luau <place.rbxl> <out folder>")
local keep = {
	"Name",
	"CFrame",
	"Size",
	"size",
	"Color3uint8",
	"CanCollide",
	"Transparency",
	"AttributesSerialize",
	"Anchored",
	"FallenPartsDestroyHeight",
	"StreamingEnabled",
	"StreamingTargetRadius",
	"StreamingMinRadius",
	"ModelStreamingMode",
	"StreamingIntegrityMode",
	"StreamOutBehavior",
	"shape",
	"Material",
	"Tags",
}
local game_ = roblox.deserializePlace(slim(fs.readFile(place), keep))
local ws = game_:GetService("Workspace")
local settings: { [string]: any } = {}
for _, name in
	{
		"FallenPartsDestroyHeight",
		"StreamingEnabled",
		"StreamingTargetRadius",
		"StreamingMinRadius",
		"StreamingIntegrityMode",
		"StreamOutBehavior",
	}
do
	local ok, v = pcall(function()
		return (ws :: any)[name]
	end)
	settings[name] = if ok then tostring(v) else "?"
end
local rows: { string } = {}
local byFolder: { [string]: { [string]: number } } = {}
local function add(folder: string, class: string)
	byFolder[folder] = byFolder[folder] or {}
	byFolder[folder][class] = (byFolder[folder][class] or 0) + 1
end
local root = ws:FindFirstChild("ClaudeBlockout")
assert(root, "no ClaudeBlockout in the place")
local function walk(inst: any, folder: string, model: string)
	local class = inst.ClassName
	add(folder, class)
	if
		class == "Part"
		or class == "WedgePart"
		or class == "MeshPart"
		or class == "CornerWedgePart"
		or class == "UnionOperation"
	then
		local cf, s = inst.CFrame, inst.Size
		local c = inst.Color
		local tex = 0
		for _, ch in inst:GetChildren() do
			if ch.ClassName == "Texture" or ch.ClassName == "Decal" then
				tex += 1
			end
		end
		local p, x, y, z = cf.Position, cf.XVector, cf.YVector, cf.ZVector
		table.insert(
			rows,
			string.format(
				"%s\t%s\t%s\t%s\t%.3f,%.3f,%.3f\t%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f\t%.3f,%.3f,%.3f\t%d,%d,%d\t%d\t%.2f\t%d",
				folder,
				model,
				inst.Name,
				class,
				p.X,
				p.Y,
				p.Z,
				x.X,
				x.Y,
				x.Z,
				y.X,
				y.Y,
				y.Z,
				z.X,
				z.Y,
				z.Z,
				s.X,
				s.Y,
				s.Z,
				math.round(c.R * 255),
				math.round(c.G * 255),
				math.round(c.B * 255),
				if inst.CanCollide then 1 else 0,
				inst.Transparency,
				tex
			)
		)
	end
	for _, ch in inst:GetChildren() do
		local sub, m = folder, model
		if ch.ClassName == "Folder" then
			sub = folder .. "/" .. ch.Name
		elseif ch.ClassName == "Model" then
			m = if model == "" then ch.Name else model
		end
		walk(ch, sub, m)
	end
end
walk(root, "CB", "")
fs.writeFile(out .. "/parts.tsv", table.concat(rows, "\n"))
local dive = root:FindFirstChild("Dive")
local attrs: { [string]: any } = {}
if dive then
	for k, v in dive:GetAttributes() do
		attrs[k] = if type(v) == "string" then v else tostring(v)
	end
end
local total: { [string]: number } = {}
for _, d in game_:GetDescendants() do
	total[d.ClassName] = (total[d.ClassName] or 0) + 1
end
fs.writeFile(
	out .. "/census.json",
	serde.encode("json", { Settings = settings, Folders = byFolder, Place = total, Dive = attrs, Parts = #rows })
)
print("parts", #rows)
