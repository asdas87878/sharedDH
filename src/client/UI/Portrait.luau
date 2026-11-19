--!strict
-- A creature's picture, as the reference has in its slots and on its catch banner. Ours is the creature's own model
-- drawn in a small window (a ViewportFrame), so no picture is uploaded and a new creature needs nothing made: the model
-- comes from ReplicatedStorage.FishModels (or .Creatures) when it is there, else from a fish of that kind swimming in
-- the world (the one just tamed always is). A kind's model is copied and cleaned once and kept; a window gets copies of
-- that when its creature changes, never per frame. A window that is not changing costs nothing to draw.
--
-- How a creature is framed (the user, 2026-11-17: "rendered nicely at an angle which shows the most interesting facial
-- part + neck area or the whole model if its small enough. With black outlines, good lighting and easy readability"):
--   a bust: a big creature with a head of its own is shown by its head, from the front quarter, at the window's left,
--     and the neck and the rest of it run off the window's right edge;
--   the whole of it: a small creature, one that is mostly face, a flat wide one (a ray, a turtle: seen from above), a
--     thin tall one (an angelfish: nearly side on, where its shape is).
-- The light comes from over the viewer's shoulder onto the face. The black outline is the same creature drawn four more
-- times in black behind it, a hair up-left, up-right, down-left and down-right: a window can't outline what it draws.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)

local Portrait = {}

export type Portrait = {
	Frame: Frame,
	show: (id: string?) -> boolean, -- false when that creature has no model to draw yet
}

local FOV = 20
-- The outline's thickness, in the HUD's units, rounded to whole pixels when drawn (the user, 2026-11-17: "thicker on
-- one end than the other, and it generally looks too thick all over and especially too thick at the top"). Each black
-- copy sat a fraction of a pixel off, so one side snapped to 2 pixels and the other to 1; now every copy is the same
-- whole number of pixels off, and the outline is 1 pixel on a 720-high screen, 2 on a 1440-high one
local OUTLINE = 0.8
local SMALL = 14 -- a creature this long or shorter is shown whole
local COMPACT = 2.2 -- and so is one this many times longer than it is tall, with no head of its own
local MOSTLY_HEAD = 0.6 -- a head this much of the creature: shown whole
-- Which parts are the head: a creature has a bust only if it has a part named Head; these then count with it.
-- A creature's head is toward +Z
local HEAD = { "Head", "Jaw", "Crown", "Brow", "Eye" }
-- Where the viewer stands: turned from side on toward the front, and raised, in degrees
local ANGLES = {
	Bust = { 42, 12 },
	Whole = { 34, 14 },
	Thin = { 22, 8 },
	Flat = { 38, 36 },
}
-- Where a creature's outline sits in its window, by how it is shown, so that every bust is the same size in the same
-- place, every small fish is, and so on (the user, 2026-11-17: "stay at the same size and silhouette placement depending
-- on the icon archetype"). In shares of the window: X and Y are its middle (a bust goes by its Left edge instead), Wide
-- and High the most room it takes. What is measured is a bust's head alone, and the whole of the others
type Place = { X: number?, Left: number?, Y: number, Wide: number, High: number }
local PLACE: { [string]: Place } = {
	Bust = { X = 0.47, Y = 0.5, Wide = 0.74, High = 0.84 }, -- (the user, 2026-11-17: "center the fish more")
	Whole = { X = 0.5, Y = 0.5, Wide = 0.94, High = 0.84 },
	Thin = { X = 0.5, Y = 0.5, Wide = 0.9, High = 0.94 },
	Flat = { X = 0.5, Y = 0.52, Wide = 0.96, High = 0.8 },
}

type View = { Kind: string, From: Vector3, Points: { Vector3 } }

local masters: { [string]: Model } = {}
local views: { [string]: View } = {}

local function find(id: string): Model?
	local kind = Config.FishById[id]
	for _, folderName in { "FishModels", "Creatures" } do
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		if folder then
			local found = folder:FindFirstChild(id) or (kind and folder:FindFirstChild(kind.Name))
			if found and found:IsA("Model") then
				return found
			end
		end
	end
	local wild = workspace:FindFirstChild("Fish")
	if wild then
		for _, fish in wild:GetChildren() do
			if fish:IsA("Model") and fish:GetAttribute("FishType") == id then
				return fish
			end
		end
	end
	return nil
end

local function from(angles: { number }): Vector3
	local yaw, pitch = math.rad(angles[1]), math.rad(angles[2])
	-- side on is from +X, which puts the head (toward +Z) at the left, as the reference's creatures face
	return Vector3.new(math.cos(yaw) * math.cos(pitch), math.sin(pitch), math.sin(yaw) * math.cos(pitch))
end

local function isHead(name: string): boolean
	for _, word in HEAD do
		if string.sub(name, 1, #word) == word then
			return true
		end
	end
	return false
end

-- The eight corners of a box from low to high
local function corners(low: Vector3, high: Vector3, into: { Vector3 })
	for i = 0, 7 do
		table.insert(
			into,
			Vector3.new(
				if bit32.band(i, 1) == 0 then low.X else high.X,
				if bit32.band(i, 2) == 0 then low.Y else high.Y,
				if bit32.band(i, 4) == 0 then low.Z else high.Z
			)
		)
	end
end

-- How a creature set at the middle, unturned, is shown: which kind of picture, from where, and the points its outline is
-- measured by (the corners of its parts' boxes: of its head's parts for a bust)
local function frame(model: Model): View
	local box, size = model:GetBoundingBox()
	local low, high = box.Position - size / 2, box.Position + size / 2
	local all: { Vector3 } = {}
	local head: { Vector3 } = {}
	local hasHead = false
	local headBack, headFront = math.huge, -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local named = isHead(d.Name)
			hasHead = hasHead or string.sub(d.Name, 1, 4) == "Head"
			local cf, half = d.CFrame, d.Size / 2
			local own: { Vector3 } = {}
			corners(-half, half, own)
			for _, corner in own do
				local at = cf * corner
				table.insert(all, at)
				if named then
					table.insert(head, at)
					headBack = math.min(headBack, at.Z)
					headFront = math.max(headFront, at.Z)
				end
			end
		end
	end
	local tall = math.max(size.Y, size.X * 0.7)
	if size.X > size.Y * 2.2 and (not hasHead or size.Z <= size.X * 1.3) then
		return { Kind = "Flat", From = from(ANGLES.Flat), Points = all }
	end
	local small = size.Z <= SMALL
	if hasHead and not small then
		if headFront - headBack < size.Z * MOSTLY_HEAD then
			return { Kind = "Bust", From = from(ANGLES.Bust), Points = head }
		end
	elseif not small and size.Z > tall * COMPACT then
		-- long, with no head of its own to go by: its front end, as long as it is tall and a quarter more
		local back = high.Z - math.clamp(tall * 1.25, size.Z * 0.28, size.Z * 0.6)
		local front: { Vector3 } = {}
		corners(Vector3.new(low.X, low.Y, back), high, front)
		return { Kind = "Bust", From = from(ANGLES.Bust), Points = front }
	end
	local thin = size.X < size.Y * 0.6
	return {
		Kind = if thin then "Thin" else "Whole",
		From = from(if thin then ANGLES.Thin else ANGLES.Whole),
		Points = all,
	}
end

-- Where the camera stands so the creature's outline sits where its kind's does (PLACE), for a window `aspect` times
-- wider than tall. Found by stepping: back or forward until the outline is the right size, then sideways and up until
-- it is in the right place, a few times over (a step changes the other a little)
local function stand(view: View, aspect: number): CFrame
	local place = PLACE[view.Kind]
	local points = view.Points
	local centre = Vector3.zero
	for _, point in points do
		centre += point
	end
	centre /= #points
	local reach = 0
	for _, point in points do
		reach = math.max(reach, (point - centre).Magnitude)
	end
	local look = CFrame.lookAt(centre + view.From, centre)
	local right, up, ahead = look.RightVector, look.UpVector, look.LookVector
	local tanV = math.tan(math.rad(FOV / 2))
	local tanH = tanV * aspect
	local distance = reach / tanV + reach
	local across, upward = 0, 0
	local function eye(): Vector3
		return centre + view.From * distance + right * across + up * upward
	end
	-- the outline's edges on the window: -1 to 1 across (left to right) and up
	local function seen(): (number, number, number, number)
		local at = eye()
		local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
		for _, point in points do
			local to = point - at
			local deep = math.max(to:Dot(ahead), 0.05)
			local x, y = to:Dot(right) / (deep * tanH), to:Dot(up) / (deep * tanV)
			x0, x1 = math.min(x0, x), math.max(x1, x)
			y0, y1 = math.min(y0, y), math.max(y1, y)
		end
		return x0, x1, y0, y1
	end
	for _ = 1, 6 do
		local x0, x1, y0, y1 = seen()
		distance =
			math.max(distance * math.max((x1 - x0) / (2 * place.Wide), (y1 - y0) / (2 * place.High)), reach * 1.2)
		x0, x1, y0, y1 = seen()
		local wantX = if place.Left then 2 * place.Left - 1 + (x1 - x0) / 2 else 2 * (place.X or 0.5) - 1
		local wantY = 1 - 2 * place.Y
		across += ((x0 + x1) / 2 - wantX) * distance * tanH
		upward += ((y0 + y1) / 2 - wantY) * distance * tanV
	end
	return CFrame.fromMatrix(eye(), right, up)
end

-- The kept copy of a kind: only what draws (parts, their meshes and textures), set at the middle, unturned
local function master(id: string): Model?
	local kept = masters[id]
	if kept then
		return kept
	end
	local source = find(id)
	if not source then
		return nil
	end
	local was = source.Archivable
	source.Archivable = true
	local copy = source:Clone()
	source.Archivable = was
	if not copy then
		return nil
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif
			not (
				d:IsA("DataModelMesh")
				or d:IsA("Decal")
				or d:IsA("SurfaceAppearance")
				or d:IsA("Model")
				or d:IsA("Folder")
			)
		then
			d:Destroy()
		end
	end
	copy:PivotTo(CFrame.new())
	views[id] = frame(copy)
	masters[id] = copy
	return copy
end

-- How a kind is shown: "Bust", "Whole", "Thin" or "Flat" (nil while it has no model to draw yet)
function Portrait.kindOf(id: string): string?
	if not master(id) then
		return nil
	end
	local view = views[id]
	return if view then view.Kind else nil
end

-- props: where the picture sits (a Frame's own properties), Outline: its outline's thickness (0 for none), and Aspect:
-- the window's width over its height to frame by (else measured when shown). Two windows of one Aspect show a creature
-- as the same picture, whatever their size: the catch screen's tiles use the slots' (Slots.Aspect)
function Portrait.new(parent: Instance, props: { [string]: any }): Portrait
	local thick: number = if props.Outline ~= nil then props.Outline else OUTLINE
	local aspect: number? = props.Aspect
	props.Outline = nil
	props.Aspect = nil
	props.BackgroundTransparency = 1
	local holder: Frame = Kit.new("Frame", props, parent)

	local windows: { ViewportFrame } = {}
	local cameras: { Camera } = {}
	local offsets: { Vector2 } = {}
	local function window(x: number, y: number, black: boolean)
		table.insert(offsets, Vector2.new(x, y))
		local view: ViewportFrame = Kit.new("ViewportFrame", {
			Position = UDim2.fromOffset(x * thick, y * thick),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(150, 156, 170),
			LightColor = Color3.fromRGB(255, 250, 240),
			-- from over the viewer's shoulder, down onto the face
			LightDirection = Vector3.new(-0.5, -0.9, -0.6),
			ImageColor3 = if black then Color3.new(0, 0, 0) else Kit.White,
			ZIndex = if black then 1 else 2,
		}, holder)
		local camera: Camera = Kit.new("Camera", { FieldOfView = FOV }, view)
		view.CurrentCamera = camera
		table.insert(windows, view)
		table.insert(cameras, camera)
	end
	if thick > 0 then
		window(-1, -1, true)
		window(1, -1, true)
		window(-1, 1, true)
		window(1, 1, true)
	end
	window(0, 0, false)

	-- How many pixels a HUD unit is here: every UIScale above multiplied (the HUD's own, a slot's grow)
	local function pixels(): number
		local scale = 1
		local at: Instance? = holder
		while at do
			local size = at:FindFirstChildOfClass("UIScale")
			if size then
				scale *= size.Scale
			end
			at = at.Parent
		end
		return scale
	end
	-- the black copies a whole number of pixels off, the same on every side
	local function settle()
		if thick <= 0 then
			return
		end
		local scale = pixels()
		local step = math.max(1, math.floor(thick * scale + 0.5)) / scale
		for i, view in windows do
			local offset = offsets[i]
			view.Position = UDim2.fromOffset(offset.X * step, offset.Y * step)
		end
	end

	local shownId: string? = nil
	local shown: { Model } = {}
	local function show(id: string?): boolean
		if id == shownId then
			return true
		end
		for _, model in shown do
			model:Destroy()
		end
		table.clear(shown)
		shownId = nil
		if not id then
			return true
		end
		local source = master(id)
		if not source then
			return false -- (not remembered: the next call looks again)
		end
		settle()
		local across = holder.AbsoluteSize
		local at = stand(views[id], aspect or (if across.Y > 0 then across.X / across.Y else 1))
		for i, view in windows do
			local copy = source:Clone()
			copy.Parent = view
			cameras[i].CFrame = at
			shown[i] = copy
		end
		shownId = id
		return true
	end
	return { Frame = holder, show = show }
end

return Portrait
