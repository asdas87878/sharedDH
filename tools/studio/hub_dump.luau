--!nocheck
-- Reads the hub out of the place for the plan (docs/design/hub-layout.md; tools/map/hub_plan.py reads the CSV).
-- MODE=parts: one CSV row per part in the hub's box: x, z, size x, size z, turn, top, bottom, colour, path.
-- MODE=models: one row per model in Workspace.Dock (two levels down): path, centre x, y, z, size x, y, z, turn.
-- usage: node tools/studio/run_luau.js <studio_id> tools/studio/hub_dump.luau ['MODE="parts"' or '"models"']
local MODE = "models"
local X0, X1, Z0, Z1 = 2740, 3260, -420, 120
local out = {}
local function path(inst)
	local bits = {}
	local p = inst
	while p and p ~= workspace do
		table.insert(bits, 1, p.Name)
		p = p.Parent
	end
	return table.concat(bits, ".")
end
if MODE == "parts" then
	for _, rootName in { "ClaudeBlockout" } do
		local root = workspace:FindFirstChild(rootName)
		if root then
			for _, p in root:GetDescendants() do
				if p:IsA("BasePart") and p.Transparency < 1 then
					local c = p.Position
					if c.X > X0 and c.X < X1 and c.Z > Z0 and c.Z < Z1 then
						local _, ry = p.CFrame:ToOrientation()
						local h = p.Size.Y / 2
						table.insert(
							out,
							string.format(
								"%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%s,%s",
								c.X,
								c.Z,
								p.Size.X,
								p.Size.Z,
								math.deg(ry),
								c.Y + h,
								c.Y - h,
								p.Color:ToHex(),
								path(p)
							)
						)
					end
				end
			end
		end
	end
else
	local dock = workspace.ClaudeBlockout:FindFirstChild("Dock")
	local function row(m)
		local cf, size = m:GetBoundingBox()
		local _, ry = cf:ToOrientation()
		table.insert(
			out,
			string.format(
				"%s,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.0f",
				path(m),
				cf.X,
				cf.Y,
				cf.Z,
				size.X,
				size.Y,
				size.Z,
				math.deg(ry)
			)
		)
	end
	if dock then
		for _, a in dock:GetChildren() do
			if a:IsA("Model") or a:IsA("Folder") then
				local kids = a:GetChildren()
				local sub = 0
				for _, b in kids do
					if b:IsA("Model") then
						sub += 1
					end
				end
				if a:IsA("Folder") or (a.Name == "Plots") then
					for _, b in kids do
						if b:IsA("Model") then
							row(b)
						end
					end
				else
					row(a)
				end
			elseif a:IsA("BasePart") then
				table.insert(
					out,
					string.format(
						"%s,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,part",
						path(a),
						a.Position.X,
						a.Position.Y,
						a.Position.Z,
						a.Size.X,
						a.Size.Y,
						a.Size.Z
					)
				)
			end
		end
	end
	local hum = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if hum then
		table.insert(out, string.format("spawn %s,%.1f,%.1f,%.1f", path(hum), hum.Position.X, hum.Position.Y, hum.Position.Z))
	end
end
return table.concat(out, "\n")
