--!nocheck
-- The seahorse trainer in Edit: Hugo's level-1 seahorse on its stand and coil on every plot, where the game will
-- build it at Play (docs/design/trainer.md). The map's kit draws nothing of the trainer (tools/map/hub_kit.py
-- `trainer_marks`: unseen marks only), so without this a plot's trainer corner is empty in Edit.
--   node tools/studio/run_luau.js <studio_id> tools/studio/trainer_edit.luau      (or: python tools/studio/trainer_models.py <studio_id>)
-- Run it after the hub's files (94 to 97) or a whole map load: both clear the plots. Running it again replaces its own.
-- What it makes, in each plot: one Model named TrainerStand, marked EditPreview, holding Stand (the level's stand),
-- Seahorse (its toy) and Coil; every part locked, so a click in Studio takes the plot, not a piece of the seahorse. It
-- is a picture only: the game takes it away when it starts and builds its own from the same marks (TrainService
-- makeRide and build, whose placing this copies line for line; a playtest checks the two stand in the same place).
-- To move a trainer, move its plot, or change the kit. LEVEL: which level to show (1 is what a plot with no owner shows).
local LEVEL = 1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = workspace:FindFirstChild("ClaudeBlockout")
local dock = root and root:FindFirstChild("Dock")
local plots = dock and dock:FindFirstChild("Plots")
if not plots then
	return "trainer preview: NONE, this place has no ClaudeBlockout.Dock.Plots (load the map first)"
end
local cleared = 0
for _, plot in plots:GetChildren() do
	for _, child in plot:GetChildren() do
		if child:GetAttribute("EditPreview") == true then
			child:Destroy()
			cleared += 1
		end
	end
end
local templates = ReplicatedStorage:FindFirstChild("TrainerModels")
local template = templates and templates:FindFirstChild("T" .. LEVEL)
if not (template and template:IsA("Model")) then
	return "trainer preview: NONE, ReplicatedStorage.TrainerModels has no T"
		.. LEVEL
		.. " (python tools/studio/trainer_models.py <studio_id> installs the 12 levels)"
end
local shared = ReplicatedStorage:FindFirstChild("Shared")
local module = shared and shared:FindFirstChild("RideStyles")
if not (module and module:IsA("ModuleScript")) then
	return "trainer preview: NONE, no ReplicatedStorage.Shared.RideStyles (sync src/ into the place first: Rojo, or tools/studio/sync_src.py)"
end
-- (a copy, so the numbers are the file's as it is now: Studio keeps a module it has run)
local fresh = module:Clone()
local ok, RideStyles = pcall(require, fresh)
fresh:Destroy()
if not ok then
	return "trainer preview: NONE, RideStyles did not run: " .. tostring(RideStyles)
end
local t = RideStyles.Trainer

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local ON_END = CFrame.Angles(0, 0, math.rad(90))
local function part(name, size, at, colour, parent, round)
	local p = Instance.new("Part")
	p.Name = name
	if round then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Size = size
	p.CFrame = at
	p.Material = Enum.Material.SmoothPlastic
	p.Color = colour
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local made, old, skipped = 0, {}, {}
for _, plot in plots:GetChildren() do
	local spot = plot:FindFirstChild("TrainerSpot")
	local model = plot:FindFirstChild("TrainerRide")
	local toy = model and model:FindFirstChild("Toy")
	local body = toy and toy:FindFirstChild("Body")
	if not (spot and spot:IsA("BasePart") and body and body:IsA("BasePart")) then
		table.insert(skipped, plot.Name)
		continue
	end
	-- (a map from the older kit: its machine is drawn here, and ours would stand in it. The hub's files replace it)
	if plot:FindFirstChild("TrainerBase") or plot:FindFirstChild("SpringCoil") or body.Transparency < 1 then
		table.insert(old, plot.Name)
		continue
	end
	-- where and which way, as TrainService.makeRide reads it
	local floor = spot.Position.Y - spot.Size.Y / 2
	local under = Vector3.new(body.Position.X, floor, body.Position.Z)
	for _, child in plot:GetChildren() do
		if child:IsA("BasePart") and child ~= spot and child.Transparency < 1 then
			local top = child.Position.Y + child.Size.Y / 2
			local at = child.CFrame:PointToObjectSpace(Vector3.new(under.X, child.Position.Y, under.Z))
			local half = child.Size / 2
			if math.abs(at.X) <= half.X and math.abs(at.Z) <= half.Z and top > floor and top < floor + 1 then
				floor = top
			end
		end
	end
	local head = toy:FindFirstChild("Head")
	local ahead = if head and head:IsA("BasePart") then flat(head.Position - body.Position) else Vector3.zero
	if ahead.Magnitude < 0.1 then
		ahead = flat(spot.CFrame.ZVector)
	end
	ahead = ahead.Unit
	local foot = Vector3.new(body.Position.X, floor, body.Position.Z)
	-- the level's model, as TrainService.build stands it
	local k = t.Scale
	local footAt = template:GetAttribute("Foot")
	local standTop = template:GetAttribute("StandTop")
	local springAt = template:GetAttribute("SpringAt")
	local copy = template:Clone()
	copy:ScaleTo(k)
	local seahorse = copy:FindFirstChild("Toy")
	local stand = copy:FindFirstChild("Stand")
	seahorse.WorldPivot = CFrame.identity
	stand.WorldPivot = CFrame.identity
	local high = (standTop - footAt.Y) * k
	local axis = foot + Vector3.new(0, high, 0)
	local meet = axis + Vector3.new(0, t.SpringLength, 0)
	stand:PivotTo(CFrame.lookAt(foot, foot + ahead) * CFrame.new(-footAt * k))
	seahorse:PivotTo(CFrame.lookAt(meet, meet + ahead) * CFrame.new(-springAt * k))
	local holder = Instance.new("Model")
	holder.Name = "TrainerStand"
	holder:SetAttribute("EditPreview", true)
	holder:SetAttribute("Level", LEVEL)
	seahorse.Name = "Seahorse"
	seahorse.Parent = holder
	stand.Parent = holder
	copy:Destroy()
	-- the coil, as TrainService.buildSpring makes it
	local turn = CFrame.lookAt(Vector3.zero, ahead)
	local base, top = CFrame.new(axis) * turn, CFrame.new(meet) * turn
	local colours = RideStyles.CoilColours[LEVEL]
	local wire = Color3.fromHex(colours[1])
	local glow = if colours[2] then Color3.fromHex(colours[2]) else nil
	local caps = Color3.fromHex(colours[3])
	local coil = Instance.new("Model")
	coil.Name = "Coil"
	local capAcross = (t.Radius + t.Wire / 2 + 0.15) * 2
	part("CapBottom", Vector3.new(0.3, capAcross, capAcross), base * CFrame.new(0, 0.15, 0) * ON_END, caps, coil, true)
	part("CapTop", Vector3.new(0.4, capAcross, capAcross), top * CFrame.new(0, 0.1, 0) * ON_END, caps, coil, true)
	local halfTurn = t.PerTurn / 2
	for n, piece in RideStyles.coil(base, top) do
		local lit = glow ~= nil and math.floor((n - 1) / halfTurn) % 2 == 1
		local p =
			part("Coil" .. n, Vector3.new(t.Wire, t.Wire, piece.Length), piece.At, if lit then glow else wire, coil)
		if lit then
			p.Material = Enum.Material.Neon
		end
	end
	coil.Parent = holder
	for _, d in holder:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Locked = true
		end
	end
	holder.WorldPivot = CFrame.lookAt(foot, foot + ahead)
	holder.Parent = plot
	made += 1
end
local text = string.format("trainer preview: level %d on %d plots (%d old ones cleared)", LEVEL, made, cleared)
if #old > 0 then
	text ..= "; NOT on " .. table.concat(old, ", ") .. ": the old kit's machine still stands there (run the hub's files, tools/studio/greybox/94 to 97, then this again)"
end
if #skipped > 0 then
	text ..= "; no trainer marks in " .. table.concat(skipped, ", ")
end
return text
