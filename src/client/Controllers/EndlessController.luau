--!strict
-- The endless Underworld on our own screen (Config.Endless, Shared/Endless; docs/design/endless.md). The map's last
-- stretch goes on lap after lap, and this is what makes it stand there: the parts of that stretch, which our machine has
-- anyway, are each put at the lap that brings them nearest our camera. A part so changes laps when the camera is half a
-- lap (1,220 studs) from it, behind us and ahead of us at once, and at that distance the Underworld's water hides it
-- whole. Nothing near us ever moves; the parts are still the same parts (props keep their boxes out, walls are the same
-- walls to every ray). What we do here no one else sees: the server's map, and every other player's, stays theirs.
--   A unit is a part, or a whole prop or set piece (Endless.unit). They move in slices of the map Endless.Slab thick, only
--   when a slice's lap changes: at 175 studs a second that is some 800 parts a second.
--   A long unit (it reaches further than Endless.Long down the map) is shown twice: itself in the even laps and a copy of
--   it, made here, in the odd ones, so that no end of it is near when it changes.
-- With no laps (Config.Endless.On 0: the attribute EndlessLaps is 0 or not there) nothing here runs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Endless = require(ReplicatedStorage.Shared.Endless)
local Net = require(ReplicatedStorage.Shared.Net)

local EndlessController = {}

-- parts that change laps together: where the slice stands down the map, the laps it can be in (Phase, Phase + Step ...),
-- the one it is in, and each part with its place in lap 0
type Slab = { Z: number, Phase: number, Step: number, Lap: number, Parts: { BasePart }, Home: { CFrame } }

local FAR = 600 -- a thing of the map whose middle is further than this before From is not of the stretch

local laneFolder: Instance? = nil
local queue: { Instance } = {} -- things of the map not looked at yet
local asked = false -- whether they have been listed
local slabs: { [number]: Slab } = {}
local list: { Slab } = {}
local copies: { Instance } = {}

-- For tests and the Studio check: units and parts taken in, copies made, parts moved since the start, and the furthest
-- and nearest a part has been from the camera down the map when it changed laps
EndlessController.Stats = { Units = 0, Parts = 0, Copies = 0, Moved = 0, Nearest = math.huge, Lap = 0 }

local function forget()
	for _, copy in copies do
		copy:Destroy()
	end
	table.clear(copies)
	table.clear(slabs)
	table.clear(list)
	table.clear(queue)
	asked = false
	local stats = EndlessController.Stats
	stats.Units, stats.Parts, stats.Copies = 0, 0, 0
end

local function add(parts: { BasePart }, z: number, phase: number, step: number)
	local size = math.max(Config.Endless.Slab, 1)
	local n = math.floor(z / size)
	local key = n * 4 + (if step == 1 then 0 else 1 + phase)
	local slab = slabs[key]
	if not slab then
		local new: Slab = { Z = (n + 0.5) * size, Phase = phase, Step = step, Lap = 0, Parts = {}, Home = {} }
		slab = new
		slabs[key] = new
		table.insert(list, new)
	end
	-- (a slice that has moved already is put back first, so that every part of it is in the same lap: it is one frame's
	-- work of getting ready, before the first lap is in sight)
	for _, part in parts do
		local home = part.CFrame
		table.insert(slab.Parts, part)
		table.insert(slab.Home, home)
		if slab.Lap ~= 0 then
			part.CFrame = home + Endless.shift() * slab.Lap
		end
	end
end

-- One thing of the map taken in
local function take(child: Instance)
	local group = child.Parent
	local unit = if group then Endless.unit(child) else nil
	if not unit or not group or not Endless.belongs(group.Name, child.Name, unit.Z) then
		return
	end
	local stats = EndlessController.Stats
	stats.Units += 1
	stats.Parts += #unit.Parts
	if unit.Reach <= Config.Endless.Long then
		add(unit.Parts, unit.Z, 0, 1)
		return
	end
	add(unit.Parts, unit.Z, 0, 2)
	local copy = child:Clone()
	copy:SetAttribute(Endless.Skip, true)
	local parts: { BasePart } = {}
	if copy:IsA("BasePart") then
		table.insert(parts, copy)
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	add(parts, unit.Z, 1, 2)
	table.insert(copies, copy)
	stats.Copies += #parts
	copy.Parent = group
end

-- Everything in the lane's folders, listed once
local function ask(lane: Instance)
	asked = true
	for _, group in lane:GetChildren() do
		for _, child in group:GetChildren() do
			table.insert(queue, child)
		end
	end
end

-- The folder the map's lane is in, found again if the map is built again under us (Studio)
local function find(): Instance?
	if laneFolder and laneFolder.Parent and laneFolder:IsDescendantOf(workspace) then
		return laneFolder
	end
	if laneFolder then
		forget()
	end
	local map = workspace:FindFirstChild("ClaudeBlockout")
	laneFolder = map and map:FindFirstChild("Lane")
	return laneFolder
end

local moving: { BasePart } = {}
local goals: { CFrame } = {}
-- Every slice at the lap nearest the camera (`eye`: how far down the map it is). A copy stands at lap 1 as soon as it is
-- made, whatever the camera does: its first lap is 1.
local function place(eye: number)
	table.clear(moving)
	table.clear(goals)
	local stats = EndlessController.Stats
	local shift = Endless.shift()
	for _, slab in list do
		local lap = Endless.nearest(eye, slab.Z, slab.Phase, slab.Step)
		if lap ~= slab.Lap then
			if stats.Units > 0 and #queue == 0 and slab.Lap >= slab.Phase then
				local z = slab.Z + shift.Z * lap
				stats.Nearest = math.min(stats.Nearest, math.abs(eye - z), math.abs(eye - slab.Z - shift.Z * slab.Lap))
			end
			slab.Lap = lap
			local off = shift * lap
			for i, part in slab.Parts do
				table.insert(moving, part)
				table.insert(goals, slab.Home[i] + off)
			end
		end
	end
	if #moving > 0 then
		stats.Moved += #moving
		workspace:BulkMoveTo(moving, goals, Enum.BulkMoveMode.FireCFrameChanged)
	end
	stats.Lap = Endless.lapOf(eye)
end

-- (`eye`: for checks; the camera's own otherwise)
function EndlessController.step(eye: number?)
	local laps = Net.Folder:GetAttribute("EndlessLaps")
	local e = Config.Endless
	if type(laps) ~= "number" or laps < 1 then
		return
	end
	local z = eye or workspace.CurrentCamera.CFrame.Position.Z
	if not asked and z < e.From - e.Ready then
		return
	end
	local lane = find()
	if not lane then
		return
	end
	Endless.begin(laps)
	if not asked then
		ask(lane)
	end
	-- (the parts are read while the camera is still up the lane, some each frame; all at once for someone put down past
	-- the first place a lap could be seen from)
	local most = if z > e.From + (e.To - e.From) / 2 - e.Ready / 2 then math.huge else math.max(e.Batch, 1)
	local n = 0
	while #queue > 0 and n < most do
		local child = table.remove(queue) :: Instance
		-- (the rest of the map, nine tenths of it, is passed over by one look at where it stands)
		local at = if child:IsA("PVInstance") then child:GetPivot().Position.Z else math.huge
		if at > e.From - FAR then
			take(child)
			n += 1
		else
			n += 0.05
		end
	end
	place(z)
end

function EndlessController.Start()
	-- (before the camera is set would be a frame late: the camera is where it was a frame ago, 3 studs, and a lap
	-- changes 1,220 away)
	RunService.PreRender:Connect(function()
		EndlessController.step()
	end)
end

return EndlessController
