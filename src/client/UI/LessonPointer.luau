--!strict
-- The lesson's one pointer (docs/design/first-minutes.md): a yellow arrow bobbing over a place with the metres to it, and a
-- trail of flat yellow arrow heads on the floor from our feet, moving towards it. On our own screen only, on the dock
-- only, and no picture is uploaded: the marker is drawn on the screen where the place is (at its edge, pointing that way,
-- when the place is out of view), the trail a small pool of parts laid on the floor found under each.
local Players = game:GetService("Players")

local Kit = require(script.Parent.Kit)
local LessonLine = require(script.Parent.LessonLine)
local Shop = require(script.Parent.Shop)

local LessonPointer = {}

local HEADS = 9 -- the most arrow heads at once
local GAP = 5 -- studs between them
local FROM = 4 -- the first this far from our feet, studs
local PACE = 7 -- they move this fast, studs a second
local UP = 0.12 -- over the floor, studs
local ARM = Vector3.new(0.8, 0.12, 2.9) -- one arm of a head
local TURN = math.rad(42)
local EDGE = 64 -- nearer a side of the screen than this is out of view, points,
local SIDE = 270 -- and then the marker waits this far in from that side (clear of the HUD's buttons)
local FADE = 0.12 -- the share of the way at each end over which they fade

type Head = { Left: Part, Right: Part, Shown: boolean }

local folder: Folder? = nil
local heads: { Head } = {}
local gui: ScreenGui
local marker: Frame
local markerScale: UIScale
local arrow: Frame
local metres: TextLabel
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
params.RespectCanCollide = true
local shownMetres = -1
local leftOut: Model? = nil -- the character the floor's rays pass
local away = CFrame.new(0, -10000, 0)

local function arm(parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = "Arm"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Kit.Sun
	p.Size = ARM
	p.CFrame = away
	p.Parent = parent
	return p
end

local function build()
	local f = Instance.new("Folder")
	f.Name = "LessonPointer"
	for i = 1, HEADS do
		heads[i] = { Left = arm(f), Right = arm(f), Shown = false }
	end
	-- (under the HUD)
	gui = Kit.new("ScreenGui", {
		Name = "LessonMarker",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	-- (placed by the arrow's point, when it points down)
	marker = Kit.new("Frame", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.92),
		Size = UDim2.fromOffset(90, 88),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	markerScale = Kit.new("UIScale", {}, marker)
	metres = Shop.text(marker, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 22,
		Text = "",
	})
	arrow = LessonLine.shape(marker, 52)
	arrow.AnchorPoint = Vector2.new(0.5, 0)
	arrow.Position = UDim2.new(0.5, 0, 0, 32)
	f.Parent = workspace
	folder = f
end

-- The marker on the screen, over `at`; at the side it is on when it is out of view
local function drawMarker(at: Vector3, clock: number)
	local camera = workspace.CurrentCamera
	local view = camera.ViewportSize
	local scale = math.clamp(view.Y / 720, 0.6, 1.5)
	markerScale.Scale = scale
	local point = camera:WorldToViewportPoint(at)
	local edge = EDGE * scale
	local x, y, turn = point.X, point.Y, 0
	if point.Z <= 0 or x < edge or x > view.X - edge then
		local right = camera.CFrame:PointToObjectSpace(at).X > 0
		local side = math.min(SIDE * scale, view.X * 0.3)
		x = if right then view.X - side else side
		y = view.Y * 0.45
		turn = if right then -90 else 90
	end
	local bob = 7 * scale * math.sin(clock * 5)
	-- (below the top strips and the line)
	local top = math.max(LessonLine.foot() + 100 * scale, view.Y * 0.3)
	y = math.clamp(y, top, math.max(view.Y * 0.95, top))
	marker.Position = UDim2.fromOffset(x + (if turn == 0 then 0 else bob), y + (if turn == 0 then bob else 0))
	arrow.Rotation = turn
	marker.Visible = true
end

local function hideHead(head: Head)
	if head.Shown then
		head.Shown = false
		head.Left.CFrame = away
		head.Right.CFrame = away
	end
end

-- The pointer this frame. at: the place (nil: none); high: the marker's height over it, studs; root and character: ours;
-- near: all of it is off when this near; trail: the arrow heads too, not only the marker
function LessonPointer.update(
	at: Vector3?,
	high: number,
	root: BasePart?,
	character: Model?,
	near: number,
	trail: boolean,
	clock: number
)
	if not folder then
		if not at then
			return
		end
		build()
	end
	local gap = if at and root then ((at - root.Position) * Vector3.new(1, 0, 1)) else nil
	local far = if gap then gap.Magnitude else 0
	if not at or not root or far <= near then
		marker.Visible = false
		for _, head in heads do
			hideHead(head)
		end
		return
	end
	drawMarker(at + Vector3.new(0, high, 0), clock)
	local shown = math.floor(far + 0.5)
	if shown ~= shownMetres then
		shownMetres = shown
		metres.Text = shown .. " m"
	end
	if not trail then
		for _, head in heads do
			hideHead(head)
		end
		return
	end
	local dir = (gap :: Vector3).Unit
	local last = math.min(FROM + HEADS * GAP, far - 3)
	local shift = (clock * PACE) % GAP
	if character ~= leftOut then
		leftOut = character
		params.FilterDescendantsInstances = if character then { character } else {}
	end
	for i, head in heads do
		local out = FROM + (i - 1) * GAP + shift
		local placed = false
		if out < last then
			local over = root.Position + dir * out
			local hit = workspace:Raycast(over + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), params)
			-- (a floor, not a wall's side or a bench's edge high over our feet)
			if hit and hit.Normal.Y > 0.8 and hit.Position.Y < root.Position.Y + 0.5 then
				local share = (out - FROM) / math.max(last - FROM, 1)
				local edge = math.min(share, 1 - share) / FADE
				local see = 1 - math.clamp(edge, 0, 1) * 0.9
				local at3 = hit.Position + Vector3.new(0, UP, 0)
				local frame = CFrame.lookAt(at3, at3 + dir)
				head.Left.CFrame = frame * CFrame.new(-0.88, 0, 0) * CFrame.Angles(0, -TURN, 0)
				head.Right.CFrame = frame * CFrame.new(0.88, 0, 0) * CFrame.Angles(0, TURN, 0)
				head.Left.Transparency = see
				head.Right.Transparency = see
				head.Shown = true
				placed = true
			end
		end
		if not placed then
			hideHead(head)
		end
	end
end

-- Off, and taken away (the lesson is over)
function LessonPointer.clear()
	if folder then
		folder:Destroy()
		gui:Destroy()
		folder = nil
		table.clear(heads)
		shownMetres = -1
	end
end

return LessonPointer
