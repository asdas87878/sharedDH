-- The hub's parts out of a saved place, offline, for tools/boards/picture.py and place_test.luau (NULLROOM task l1).
-- usage: lune run tools/boards/hub_parts.luau <place.rbxl> <out.json>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local place = roblox.deserializePlace(fs.readFile(process.args[1]))
local out = {}
for _, part in place:GetService("Workspace").ClaudeBlockout:GetDescendants() do
	if part:IsA("BasePart") then
		local at, size, color = part.CFrame.Position, part.Size, part.Color
		if math.abs(at.X - 3000) < 230 and at.Z > -290 and at.Z < 40 and at.Y > -120 and at.Y < 130 then
			local name = string.gsub(part:GetFullName(), "^Workspace%.ClaudeBlockout%.", "")
			table.insert(out, {
				n = name,
				sh = if part.ClassName == "Part" then part.Shape.Name else part.ClassName,
				mat = part.Material.Name,
				t = part.Transparency,
				cc = part.CanCollide,
				col = { color.R, color.G, color.B },
				s = { size.X, size.Y, size.Z },
				m = { part.CFrame:GetComponents() },
			})
		end
	end
end
fs.writeFile(process.args[2], serde.encode("json", out))
print(#out)
