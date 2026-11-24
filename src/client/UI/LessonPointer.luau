--!strict
-- The lesson's one pointer (docs/design/first-minutes.md): a chunky yellow arrow, in the world, bobbing over a place, and
-- a trail of yellow chevrons on the dock's floor, along a way that can be walked (round the stalls and the statue, never
-- through them), running towards it. On our own screen only, on the dock only, and no picture is uploaded: both are
-- built of blocks and wedges whose faces meet exactly (nothing overlaps, nothing is see-through), each on a dark plate a
-- little larger than itself, its outline. At the trail's two ends the chevrons grow and shrink: they never fade.
-- Being in the world, it is under every screen's words and buttons and can't cover one; and where the view would put the
-- arrow behind the HUD it shrinks away until the view turns.
local GuiService = game:GetService("GuiService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local Kit = require(script.Parent.Kit)

local LessonPointer = {}

-- A chevron: half as wide as this (wider than we are, or the camera behind us never sees one), its arms falling back this
-- far, this thick along the way (more than they fall back: a bar lies between); the plate this much larger
local HALF, DROP, THICK = 3.2, 2.8, 3
local PLATE = 0.36
local HIGH, PLATE_HIGH = 0.3, 0.16
local HEADS = 9 -- the most chevrons at once
local GAP = 7.4 -- studs between them
local FROM = 1.5 -- the first this far along from our feet, studs
local GROW = 5 -- they grow and shrink over this many studs at each end
local PACE = 8 -- they run this fast, studs a second
local LIFT = 0.04 -- over the floor
local OVER, UNDER = 1.3, 2.2 -- a floor this much over the way's own, or under it, is not it (a bench, a rail, the sea)
-- The way
local REPATH = 0.6 -- looked for again at most this often, seconds,
local OFF = 7 -- when we are this far off it, studs,
local MOVED = 3 -- or the place has moved this far
-- The arrow: half its head's width, its head's height, half the stem's width, the stem's height, all its depth
local A_HALF, A_HEAD, A_STEM, A_TALL, A_DEEP = 1.7, 1.9, 0.75, 1.7, 0.9
local A_PLATE = 0.3
local STAND, WIDE = 1.5, 2.5 -- a chevron closes up this near a stand, from this much further (it never meets one), studs
local FILL = 0.2
local POP = 8 -- it shrinks away from the HUD, and comes back, at this much of its size a second
local CLEAR, BACK = 4, 14 -- when this near it, points, and back when this far
local HUD = { "LandStrip", "StatRows", "HubButtons", "Slots" } -- (the HUD's corners and edges, with what hangs from them)
local BOB, BOB_PACE = 0.45, 4.5
local NEAR = 34 -- past this far it grows, so it stays as big on the screen; nearer it shrinks, to
local LEAST = 0.5 -- this

type Piece = { Part: BasePart, Size: Vector3, At: CFrame } -- its size and place in the whole, at full size
type Head = { Pieces: { Piece }, Scale: number }

local folder: Folder? = nil
local arrow: { Piece } = {}
local arrowScale = 0
local arrowShown = false
local arrowIn = 1 -- 0: shrunk away from the HUD
local arrowClock = 0
local hudRects: { { number } } = {} -- what of the HUD is drawn where: x0, y0, x1, y1
local hudAt = -math.huge
local heads: { Head } = {}
local away = CFrame.new(0, -10000, 0)
local moveParts: { BasePart } = {}
local moveTo: { CFrame } = {}

local way: { Vector3 } = {} -- the way to the place, on the floor, our end first
local wayLong: { number } = {} -- how far along it each point is
local wayFor: Vector3? = nil -- the place it was found for
local wayAt = -math.huge
local looking = false
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.IgnoreWater = true
floorParams.RespectCanCollide = true

----------------------------------------------------------------------------------------------------------------------
-- The shapes

local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local function piece(parent: Instance, class: string, size: Vector3, at: CFrame, colour: Color3, list: { Piece })
	local p: BasePart = Instance.new(class :: any)
	p.Name = if colour == Kit.Ink then "Plate" else "Yellow"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = colour
	p.Size = size
	p.CFrame = away
	p.Parent = parent
	table.insert(list, { Part = p, Size = size, At = at })
end

-- A chevron, flat, its point ahead (-Z), its middle `back` behind the origin, its foot at `foot`: a bar across, two wedges
-- before it (the point) and two behind (the arms' ends). A wedge's right angle is at its -Y, +Z edge.
local function chevron(
	parent: Instance,
	half: number,
	drop: number,
	thick: number,
	high: number,
	foot: number,
	back: number,
	colour: Color3,
	list: { Piece }
)
	local tip = (thick + drop) / 2 - back
	local y = foot + high / 2
	local bar = thick - drop
	piece(parent, "Part", Vector3.new(half * 2, high, bar), CFrame.new(0, y, -(tip - drop - bar / 2)), colour, list)
	local wedge = Vector3.new(high, half, drop)
	for _, side in { 1, -1 } do
		local before = Vector3.new(side * half / 2, y, -(tip - drop / 2))
		piece(parent, "WedgePart", wedge, CFrame.fromMatrix(before, Y * -side, X * side, Z), colour, list)
		local behind = Vector3.new(side * half / 2, y, -(tip - thick - drop / 2))
		piece(parent, "WedgePart", wedge, CFrame.fromMatrix(behind, Y * -side, X * -side, -Z), colour, list)
	end
end

-- An arrow standing up, pointing down, the yellow's point at the origin; grow: its outline's plate, this much larger
local function standing(parent: Instance, grow: number, deep: number, colour: Color3, list: { Piece })
	local slope = A_HALF / A_HEAD -- (how much wider for each stud up)
	local low = grow * math.sqrt(1 + slope * slope) / slope -- (the point this much lower moves the sides out by `grow`)
	local top = A_HEAD + grow
	local head = top + low
	local half = head * slope
	local wedge = Vector3.new(deep, half, head)
	for _, side in { 1, -1 } do
		local at = Vector3.new(side * half / 2, top - head / 2, 0)
		piece(parent, "WedgePart", wedge, CFrame.fromMatrix(at, Z * side, X * side, Y), colour, list)
	end
	local stem = Vector3.new((A_STEM + grow) * 2, A_TALL, deep)
	piece(parent, "Part", stem, CFrame.new(0, top + A_TALL / 2, 0), colour, list)
end

local function build()
	local f = Instance.new("Folder")
	f.Name = "LessonPointer"
	local slope = DROP / HALF
	local long = math.sqrt(1 + slope * slope)
	for i = 1, HEADS do
		local list: { Piece } = {}
		-- (the plate's sides are PLATE out from the yellow's all round)
		local half = HALF + PLATE
		chevron(f, half, half * slope, THICK + 2 * PLATE * long, PLATE_HIGH, 0, PLATE * slope / 2, Kit.Ink, list)
		chevron(f, HALF, DROP, THICK, HIGH, PLATE_HIGH, 0, Kit.Sun, list)
		heads[i] = { Pieces = list, Scale = 0 }
	end
	standing(f, A_PLATE, A_DEEP * 0.5, Kit.Ink, arrow)
	-- (its yellow filled flat, so it isn't mud where its face is in the shade; Neon glows here)
	local face = Instance.new("Model")
	face.Name = "Face"
	standing(face, 0, A_DEEP, Kit.Sun, arrow)
	local fill = Instance.new("Highlight")
	fill.FillColor = Kit.Sun
	fill.FillTransparency = FILL
	fill.OutlineTransparency = 1
	fill.DepthMode = Enum.HighlightDepthMode.Occluded
	fill.Parent = face
	face.Parent = f
	f.Parent = workspace
	folder = f
end

-- The pieces of a whole, at this scale about its origin
local function lay(list: { Piece }, at: CFrame, scale: number, resize: boolean)
	for _, p in list do
		if resize then
			p.Part.Size = p.Size * scale
		end
		table.insert(moveParts, p.Part)
		table.insert(moveTo, at * (p.At.Rotation + p.At.Position * scale))
	end
end

local function hide(list: { Piece })
	for _, p in list do
		p.Part.CFrame = away
	end
end

local function hideHead(head: Head)
	if head.Scale > 0 then
		head.Scale = 0
		hide(head.Pieces)
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The way

local function keep(points: { Vector3 })
	-- (the path's points sit on a grid: a few rounds of smoothing take its kinks out, its ends kept)
	for _ = 1, 3 do
		local smooth = table.clone(points)
		for i = 2, #points - 1 do
			smooth[i] = points[i] * 0.5 + (points[i - 1] + points[i + 1]) * 0.25
		end
		points = smooth
	end
	local long = { 0 }
	for i = 2, #points do
		long[i] = long[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	way, wayLong = points, long
end

local function look(from: Vector3, to: Vector3)
	looking = true
	wayAt = os.clock()
	local points: { Vector3 } = {}
	local path = PathfindingService:CreatePath({
		AgentRadius = 4.5,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 6,
	})
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		for _, w in path:GetWaypoints() do
			table.insert(points, w.Position)
		end
	end
	if #points < 2 then
		points = { from, to } -- (no way found: straight there)
	end
	looking = false
	wayFor = to
	keep(points)
end

-- Where we are along the way, and how far off it
local function along(from: Vector3): (number, number)
	local best, off = 0, math.huge
	for i = 2, #way do
		local a, b = way[i - 1], way[i]
		local ab = (b - a) * Vector3.new(1, 0, 1)
		local ap = (from - a) * Vector3.new(1, 0, 1)
		local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 0.01), 0, 1)
		local d = (ap - ab * t).Magnitude
		if d < off then
			off = d
			best = wayLong[i - 1] + (wayLong[i] - wayLong[i - 1]) * t
		end
	end
	return best, off
end

local function pointAt(s: number): Vector3
	for i = 2, #way do
		if s <= wayLong[i] or i == #way then
			local span = math.max(wayLong[i] - wayLong[i - 1], 0.01)
			return way[i - 1]:Lerp(way[i], math.clamp((s - wayLong[i - 1]) / span, 0, 1))
		end
	end
	return way[1]
end

-- The floor under a chevron: the whole of its foot, so none of it is under a step's edge
local function floorAt(at: Vector3, turn: CFrame): number?
	local size = Vector3.new(HALF * 2, 0.2, THICK + DROP)
	local hit = workspace:Blockcast(turn + at + Vector3.new(0, 3.5, 0), size, Vector3.new(0, -7, 0), floorParams)
	if hit and hit.Position.Y < at.Y + OVER and hit.Position.Y > at.Y - UNDER then
		return hit.Position.Y
	end
	return nil
end

local function hideTrail()
	for _, head in heads do
		hideHead(head)
	end
end

-- What stands on the hub's floor and is nothing to walk into (the seahorses' stands): the path goes through them, so the
-- chevrons close up before they reach one
local stands: { BasePart } = {}
local standsAt = -math.huge

local function lookStands()
	if os.clock() - standsAt < 1 then
		return
	end
	standsAt = os.clock()
	table.clear(stands)
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local plots = dock and dock:FindFirstChild("Plots")
	for _, plot in if plots then plots:GetChildren() else {} do
		local model = plot:FindFirstChild("TrainerStand")
		local part = model and model:FindFirstChild("Stand")
		if part and part:IsA("BasePart") then
			table.insert(stands, part)
		end
	end
end

-- 1 clear of every stand, 0 at one's edge
local function clearOf(at: Vector3): number
	local share = 1
	for _, part in stands do
		local offset = part.CFrame:PointToObjectSpace(at)
		local dx = math.max(math.abs(offset.X) - part.Size.X / 2, 0)
		local dz = math.max(math.abs(offset.Z) - part.Size.Z / 2, 0)
		share = math.min(share, math.clamp((math.sqrt(dx * dx + dz * dz) - STAND) / WIDE, 0, 1))
	end
	return share
end

local function drawTrail(to: Vector3, feet: Vector3, clock: number)
	lookStands()
	local was = wayFor
	if was and (was - to).Magnitude > MOVED then
		wayFor = nil -- (another place: never its old trail)
		table.clear(way)
		wayAt = -math.huge
	end
	local here, off = 0, math.huge
	if #way > 1 then
		here, off = along(feet)
	end
	if not looking and off > OFF and os.clock() - wayAt > REPATH then
		task.spawn(look, feet, to)
	end
	if #way < 2 or off > OFF * 2 then
		hideTrail()
		return
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	floorParams.FilterDescendantsInstances = if blockout then { blockout } else {}
	-- (the chevrons' places are counted from the place, so we walk past them and don't drag them along)
	local total = wayLong[#wayLong]
	local first = here + FROM
	local last = math.min(first + (HEADS - 1) * GAP, total)
	local ending = math.clamp((total - first - GAP) / GAP, 0, 1) -- (all gone by the time there is room for only one)
	local s = first + (total + clock * PACE - first) % GAP
	for _, head in heads do
		local share = math.clamp(math.min(s - first, last - s) / GROW, 0, ending)
		local scale = 1 - (1 - share) * (1 - share)
		local dir = (pointAt(s + 2.5) - pointAt(s - 2.5)) * Vector3.new(1, 0, 1)
		local floor: number? = nil
		local at, turn = pointAt(s), CFrame.identity
		scale *= if scale > 0.08 then clearOf(at) else 1
		if scale > 0.08 and dir.Magnitude > 0.1 then
			turn = CFrame.lookAt(Vector3.zero, dir)
			floor = floorAt(at, turn)
		end
		if floor then
			local resize = head.Scale <= 0 or math.abs(scale - head.Scale) > 0.004
			lay(head.Pieces, turn + Vector3.new(at.X, floor + LIFT, at.Z), scale, resize)
			if resize then
				head.Scale = scale
			end
		else
			hideHead(head)
		end
		s += GAP
	end
end

-- The HUD's pieces, looked up again now and then (they come and go, and are elsewhere on a phone)
local function lookHud()
	if os.clock() - hudAt < 0.5 then
		return
	end
	hudAt = os.clock()
	table.clear(hudRects)
	local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = gui and gui:FindFirstChild("RideHud")
	local root = hud and hud:FindFirstChild("Root")
	if not root then
		return
	end
	local function add(o: Instance?)
		if o and o:IsA("GuiObject") and o.Visible and o.AbsoluteSize.X > 0 then
			local p, s = o.AbsolutePosition, o.AbsoluteSize
			table.insert(hudRects, { p.X, p.Y, p.X + s.X, p.Y + s.Y })
		end
	end
	for _, name in HUD do
		local part = root:FindFirstChild(name)
		if part and part:IsA("GuiObject") and part.Visible then
			for _, child in part:GetChildren() do
				add(child)
			end
		end
	end
end

-- Whether the arrow, at this scale and wherever in its bob, would be within `gap` points of the HUD
local function behindHud(over: Vector3, scale: number, gap: number): boolean
	local camera = workspace.CurrentCamera
	local inset = GuiService:GetGuiInset()
	local tall = (A_HEAD + A_TALL + A_PLATE + BOB * 2) * scale
	local side = camera.CFrame.RightVector * (A_HALF + A_PLATE * 2) * scale
	local top, foot = over + Vector3.new(0, tall, 0), over - Vector3.new(0, A_PLATE * 2 * scale, 0)
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, at in { top - side, top + side, foot - side, foot + side } do
		local p = camera:WorldToViewportPoint(at)
		if p.Z <= 0 then
			return false
		end
		x0, x1 = math.min(x0, p.X), math.max(x1, p.X)
		y0, y1 = math.min(y0, p.Y - inset.Y), math.max(y1, p.Y - inset.Y)
	end
	for _, r in hudRects do
		if x0 < r[3] + gap and x1 > r[1] - gap and y0 < r[4] + gap and y1 > r[2] - gap then
			return true
		end
	end
	return false
end

local function drawArrow(over: Vector3, most: number, clock: number)
	local eye = workspace.CurrentCamera.CFrame.Position
	local flat = (eye - over) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.5 then
		return
	end
	local scale = math.clamp((eye - over).Magnitude / NEAR, math.min(LEAST, most), most)
	lookHud()
	local blocked = behindHud(over, scale, if arrowIn > 0.5 then CLEAR else BACK)
	local step = math.clamp(clock - arrowClock, 0, 0.1) * POP
	arrowClock = clock
	arrowIn = math.clamp(arrowIn + (if blocked then -step else step), 0, 1)
	if arrowIn <= 0.02 then
		if arrowShown then
			arrowShown = false
			hide(arrow)
		end
		return
	end
	scale = math.max(math.floor(scale * arrowIn * 50 + 0.5) / 50, 0.02)
	local bob = BOB * scale * (1 + math.sin(clock * BOB_PACE))
	lay(arrow, CFrame.lookAt(over, over + flat) + Vector3.new(0, bob, 0), scale, scale ~= arrowScale)
	arrowScale = scale
	arrowShown = true
end

-- The pointer this frame. to: the place on the floor to walk to (nil: no trail); over: what the arrow's point is over
-- (nil: no arrow); most: the most times larger the arrow grows with the distance; feet: ours, on the floor
function LessonPointer.update(to: Vector3?, over: Vector3?, most: number, feet: Vector3?, clock: number)
	if not folder then
		if not to and not over then
			return
		end
		build()
	end
	table.clear(moveParts)
	table.clear(moveTo)
	if over then
		drawArrow(over, most, clock)
	elseif arrowShown then
		arrowShown = false
		hide(arrow)
	end
	if to and feet then
		drawTrail(to, feet, clock)
	else
		wayFor = nil
		table.clear(way)
		wayAt = -math.huge
		hideTrail()
	end
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveTo, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Off, and taken away (the lesson is over)
function LessonPointer.clear()
	if folder then
		folder:Destroy()
		folder = nil
		table.clear(heads)
		table.clear(arrow)
		table.clear(way)
		wayFor = nil
		arrowShown = false
		arrowScale = 0
	end
end

return LessonPointer
