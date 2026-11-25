--!strict
-- The lesson's one pointer (docs/design/first-minutes.md): a chunky yellow arrow, in the world, bobbing over a place, and
-- a trail of yellow chevrons on the dock's floor, along a way that can be walked (round the stalls and the statue, never
-- through them), running towards it. The trail starts at our feet every frame and goes straight to the place; only what
-- is in the way bends it, at a corner it can't cut (the user, 2026-11-25: "they need to not curve when they dont need
-- to, they need to update in real time with the player"). On our own screen only, on the dock only, and no picture is
-- uploaded: both are
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
local OVER, UNDER = 2.2, 2.6 -- a floor this much over the way's own, or under it, is not it (a bench, a rail, the sea)
local SEEN = 0.5 -- a part more see-through than this is no floor (it is looked under)
local SETTLE = 16 -- a chevron goes down off a step at this share of the way a second (up onto one at once)
-- The way
local SEE_EVERY = 0.08 -- what is in our way is looked at this often, seconds,
local SEE_WIDE, SEE_LOW, SEE_TALL = 5.5, 1.3, 3.2 -- by a box this wide, from this far over the floor, this tall
local BEND_WIDE = 7 -- (wider between two corners, so the trail keeps off them)
local REPATH = 0.5 -- a way round is looked for at most this often, seconds
local AGAIN = 4 -- and only when we have gone this far since, or have lost it, studs
local MOVED = 3 -- the place has moved this far: its trail is another's
local TURN = 2 -- a chevron turns with the trail over this much each side of a corner, studs
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
type Head = { Pieces: { Piece }, Scale: number, Number: number, Y: number }

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

local way: { Vector3 } = {} -- this frame's: our feet, the corners still ahead, the place
local wayLong: { number } = {} -- how far along it each point is
local wayFor: Vector3? = nil -- the place it is for
local corners: { Vector3 } = {} -- of the way round that was found, the place last ({ the place }: straight there)
local nextCorner = 1 -- the one we are walking to
local pathAt = -math.huge
local pathFrom = Vector3.zero -- where we were
local seenAt = -math.huge
local looking = false
local trailClock = 0
local solid = RaycastParams.new() -- what can't be walked through
solid.FilterType = Enum.RaycastFilterType.Include
solid.IgnoreWater = true
solid.RespectCanCollide = true
local floorParams = RaycastParams.new() -- what the chevrons lie on: what is seen, walked on or not (the strip)
floorParams.FilterType = Enum.RaycastFilterType.Exclude
floorParams.IgnoreWater = true
local passed = math.huge -- how many parts found to be no floor are kept in floorParams (none yet: made anew)
local body: Instance? = nil -- our character, kept in it too

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
		heads[i] = { Pieces = list, Scale = 0, Number = -1, Y = 0 }
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

local FLAT = Vector3.new(1, 0, 1)

-- Whether the floor between these two can be walked straight
local function open(a: Vector3, b: Vector3, wide: number): boolean
	local go = b - a
	local flat = go * FLAT
	if flat.Magnitude < 2 then
		return true
	end
	-- (to a little short of `b`: a corner, or the place, may stand by a wall)
	local box = CFrame.lookAt(Vector3.zero, flat) + a + Vector3.new(0, SEE_LOW + SEE_TALL / 2, 0)
	local size = Vector3.new(wide, SEE_TALL, 0.4)
	if workspace:Blockcast(box, size, go * (1 - 1 / flat.Magnitude), solid) then
		return false
	end
	local steps = math.floor(flat.Magnitude / 8)
	for i = 1, steps do
		local at = a + go * (i / (steps + 1))
		if not workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -7, 0), solid) then
			return false
		end
	end
	return true
end

-- A way round, found by the engine's paths and pulled straight between the corners it needs
local function look(from: Vector3, to: Vector3)
	looking = true
	pathAt = os.clock()
	pathFrom = from
	local points: { Vector3 } = {}
	local path = PathfindingService:CreatePath({
		AgentRadius = 4.5,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 5,
	})
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		for _, w in path:GetWaypoints() do
			table.insert(points, w.Position)
		end
	end
	looking = false
	local was = wayFor
	if not was or (was - to).Magnitude > MOVED then
		return
	end
	local bends: { Vector3 } = {}
	local i = 1
	while i < #points do
		local far = i + 1
		for j = #points, i + 2, -1 do
			if open(points[i], points[j], BEND_WIDE) then
				far = j
				break
			end
		end
		i = far
		if i < #points then
			table.insert(bends, points[i])
		end
	end
	table.insert(bends, to) -- (no way found: straight there)
	corners, nextCorner, seenAt = bends, 1, -math.huge
end

-- This frame's way: from our feet straight to the furthest corner nothing hides, and on from there
local function route(feet: Vector3, to: Vector3)
	local now = os.clock()
	if now - seenAt > SEE_EVERY then
		seenAt = now
		if open(feet, to, SEE_WIDE) then
			corners, nextCorner = { to }, 1
		else
			local found: number? = nil
			for i = #corners - 1, 1, -1 do
				if open(feet, corners[i], SEE_WIDE) then
					found = i
					break
				end
			end
			if found then
				nextCorner = found
			end
			-- (looked for again as we go: the way that was the shortest from back there may not be from here)
			local lost = not found or (pathFrom - feet).Magnitude > AGAIN
			if lost and not looking and now - pathAt > REPATH then
				task.spawn(look, feet, to)
			end
		end
	end
	table.clear(way)
	table.clear(wayLong)
	way[1], wayLong[1] = feet, 0
	for i = math.min(nextCorner, #corners), #corners do
		local at = if i == #corners then to else corners[i]
		table.insert(wayLong, wayLong[#way] + ((at - way[#way]) * FLAT).Magnitude)
		table.insert(way, at)
	end
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

local blockout: Instance? = nil

-- The floor under a chevron: the whole of its foot, so none of it is under a step's edge
local function floorAt(at: Vector3, turn: CFrame): number?
	local size = Vector3.new(HALF * 2, 0.2, THICK + DROP)
	local narrow = false
	for _ = 1, 7 do
		local hit = workspace:Blockcast(turn + at + Vector3.new(0, 4, 0), size, Vector3.new(0, -8, 0), floorParams)
		if not hit then
			return nil
		end
		local part = hit.Instance :: BasePart
		local y = hit.Position.Y
		local ours = blockout ~= nil and part:IsDescendantOf(blockout) and part.Transparency < SEEN
		if ours and y < at.Y + OVER then
			return if y > at.Y - UNDER then y else nil
		elseif ours and part.CanCollide then
			if narrow then
				return nil -- (a bench, a wall's foot: no floor here)
			end
			narrow = true -- (a post its tip only grazes doesn't take it away)
			size *= Vector3.new(0.4, 1, 0.4)
		else
			-- (nothing seen there, or nothing that stays: looked under, now and from now on)
			passed += 1
			floorParams:AddToFilter(part)
		end
	end
	return nil
end

-- The floor we stand on, or are over
local function underFeet(feet: Vector3): Vector3
	local hit = workspace:Raycast(feet + Vector3.new(0, 1.5, 0), Vector3.new(0, -16, 0), solid)
	return if hit then Vector3.new(feet.X, hit.Position.Y, feet.Z) else feet
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
	local map = workspace:FindFirstChild("ClaudeBlockout")
	local dock = map and map:FindFirstChild("Dock")
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
	local found = workspace:FindFirstChild("ClaudeBlockout")
	if found ~= blockout then
		blockout = found
		solid.FilterDescendantsInstances = if found then { found } else {}
	end
	local character: Instance? = Players.LocalPlayer.Character
	if passed > 200 or body ~= character then
		passed, body = 0, character
		floorParams.FilterDescendantsInstances = { workspace.CurrentCamera, character :: any }
	end
	local was = wayFor
	if not was or (was - to).Magnitude > MOVED then
		-- (another place: never its old trail)
		corners, nextCorner = { to }, 1
		pathAt, seenAt = -math.huge, -math.huge
	end
	wayFor = to
	route(underFeet(feet), to)
	local dt = math.clamp(clock - trailClock, 0, 0.1)
	trailClock = clock
	-- (the chevrons are counted from the place, so we walk past them and don't drag them along; each keeps its own number,
	-- and its own head, from when it grows at our feet until it shrinks)
	local total = wayLong[#wayLong]
	local near = total - FROM
	local far = math.max(near - (HEADS - 1) * GAP, 0)
	local ending = math.clamp((near - GAP) / GAP, 0, 1) -- (all gone by the time there is room for only one)
	local run = clock * PACE
	local top = math.floor((near + run) / GAP)
	for number = top - HEADS + 1, top do
		local head = heads[number % HEADS + 1]
		local left = number * GAP - run -- (how far from the place)
		local s = total - left
		local share = math.clamp(math.min(near - left, left - far) / GROW, 0, ending)
		local scale = 1 - (1 - share) * (1 - share)
		local floor: number? = nil
		local at, turn = pointAt(s), CFrame.identity
		scale *= if scale > 0.08 then clearOf(at) else 1
		if scale > 0.08 then
			local dir = (pointAt(s + TURN) - pointAt(s - TURN)) * FLAT
			if dir.Magnitude > 0.1 then
				turn = CFrame.lookAt(Vector3.zero, dir)
				floor = floorAt(at, turn)
			end
		end
		if floor then
			local fresh = head.Scale <= 0 or head.Number ~= number
			-- (up onto a step at once, so it never sinks in; down off one eased)
			head.Y = if fresh or floor > head.Y then floor else head.Y + (floor - head.Y) * (1 - math.exp(-SETTLE * dt))
			head.Number = number
			local resize = fresh or math.abs(scale - head.Scale) > 0.004
			lay(head.Pieces, turn + Vector3.new(at.X, head.Y + LIFT, at.Z), scale, resize)
			if resize then
				head.Scale = scale
			end
		else
			hideHead(head)
		end
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
