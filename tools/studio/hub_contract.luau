-- What the game needs of the hub, checked in the place (Edit or Play): run after the hub or the whole map is loaded.
-- node tools/studio/run_luau.js <studio_id> tools/studio/hub_contract.luau
local out, bad = {}, {}
local root = workspace.ClaudeBlockout
local dock = root.Dock
local function say(ok, text)
	if not ok then
		table.insert(bad, text)
	end
end
local spawnPart = dock:FindFirstChild("DockSpawn")
say(spawnPart, "no DockSpawn")
local floor = dock.HubFloor
local top = floor.Position.Y + floor.Size.Y / 2
local count = 0
for i = 1, 8 do
	local plot = dock.Plots:FindFirstChild("Plot" .. i)
	say(plot and plot:IsA("Model"), "no Plot" .. i)
	if plot then
		count += 1
		for _, n in { "TankWater", "Pad", "SignBoard", "TrainerSpot", "UpgradeBoard", "UpgradePost", "PlotBoard", "PlotPost", "PenPlate" } do
			local c = plot:FindFirstChild(n)
			say(c and c:IsA("BasePart"), plot.Name .. " has no " .. n)
		end
		local posts, foam = 0, 0
		for _, c in plot:GetChildren() do
			posts += if c.Name == "Post" then 1 else 0
			foam += if c.Name == "TankSurface" then 1 else 0
		end
		say(posts == 4 and foam == 4, plot.Name .. " posts " .. posts .. " foam " .. foam)
		local water, pad, spot = plot.TankWater, plot.Pad, plot.TrainerSpot
		local way = (pad.Position - water.Position) * Vector3.new(1, 0, 1)
		local toMiddle = (Vector3.new(3000, 0, -100) - water.Position) * Vector3.new(1, 0, 1)
		say(way.Magnitude > 1 and way.Unit:Dot(toMiddle.Unit) > 0.5, plot.Name .. "'s front does not face the hub")
		for _, n in { "UpgradeBoard", "PlotBoard" } do
			say(plot[n].CFrame.LookVector:Dot(way.Unit) > 0.99, plot.Name .. "'s " .. n .. " does not face the hub")
		end
		say(math.abs(spot.Position.Y - spot.Size.Y / 2 - top) < 0.1, plot.Name .. "'s trainer is off the floor")
		local ride = plot:FindFirstChild("TrainerRide")
		local toy = ride and ride:FindFirstChild("Toy")
		say(ride and ride.PrimaryPart and ride.PrimaryPart.Name == "TrainerRide" and toy and toy:FindFirstChild("Body"), plot.Name .. "'s TrainerRide")
		local at = spawnPart and (plot:GetPivot().Position - spawnPart.Position).Magnitude or 0
		table.insert(out, string.format("%s water %.1f x %.1f x %.1f, %.0f from the spawn", plot.Name, water.Size.X, water.Size.Y, water.Size.Z, at))
	end
end
for _, n in { "Sell", "Auras", "Fuse", "Index", "Sub", "Earners" } do
	local s = dock.Stations:FindFirstChild(n)
	say(s, "no station " .. n)
	if s and n ~= "Earners" then
		local ring = s:FindFirstChild("Ring")
		say(ring and s.PrimaryPart == ring and ring:HasTag("HubRing") and ring:FindFirstChild("Circle"), n .. "'s ring")
	elseif s then
		local rows = s:FindFirstChild("Rows", true)
		say(rows and rows:FindFirstChild("Row5"), "the earners board's rows")
	end
end
say(dock:FindFirstChild("HubLife"), "no HubLife")
say(dock:FindFirstChild("Gate"), "no Gate")
-- nobody can walk out: rays at chest and at 20 studs, from the middle, all round but the gate, must meet something solid
local open = {}
for a = 0, 359, 2 do
	local dir = Vector3.new(math.sin(math.rad(a)), 0, math.cos(math.rad(a)))
	local from = Vector3.new(3000, top + 45, -138)
	local hit = workspace:Raycast(from, dir * 600)
	if not hit then
		table.insert(open, a)
	end
end
table.insert(out, "directions open at 45 studs up (0 is the gate): " .. table.concat(open, " "))
return string.format("plots %d; %s\n%s", count, if #bad == 0 then "ALL GOOD" else "BAD: " .. table.concat(bad, "; "), table.concat(out, "\n"))
