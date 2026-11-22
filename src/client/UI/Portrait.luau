--!strict
-- A creature's picture, as the reference has in its slots and on its catch banner. Ours is the creature's own model
-- drawn in a small window (a ViewportFrame), so no picture is uploaded and a new creature needs nothing made: the model
-- comes from ReplicatedStorage.FishModels (or .Creatures) when it is there, else from a fish of that kind swimming in
-- the world (the one just tamed always is). A kind's model is copied, cleaned and posed once and kept; a window gets
-- copies of that when its creature changes, never per frame. A window that is not changing costs nothing to draw.
--
-- How a creature is shown, after the reference's slots (read off the user's recording, 2026-11-18): a big creature is a
-- bust, its head at the top facing left and toward the viewer, a little from above, and its body running down behind
-- the head and out through the bottom of the picture, where the name covers the cut (the reference's dinosaurs: head
-- and neck, never cut at the side). A fish swims level, so a bust's fish is tipped nose up, as if rising, to send its
-- body down. A small creature is shown whole, from the front quarter; a thin tall one (an angelfish) nearly side on; a
-- flat wide one (a ray, a turtle) from the front and above, its tail left to run out of the picture.
-- The light comes from over the viewer's left shoulder, the same for every creature whichever way it is seen, with
-- plenty of fill so the colours stay bright, as the reference's. The black outline is the creature drawn eight more
-- times in black in a window behind, each a few pixels off in one of eight directions: a window can't outline what it
-- draws.
--
-- The partner's renders (task r1, Hugo 2026-11-19: "wasnt there other icons of the fishes that my partner made? check
-- and replace if there is, just the renders though"): a fish with a render in UI.FishIcons (the Three-quarter view of
-- its sheet, cut by tools/ui/fish_icons/cut.py) is shown by that picture instead of its model, in the same windows with
-- the same black outline. Until the icon pages are uploaded (FishIcons.Pages) a live game keeps the model; Studio reads
-- the local copies. In Studio the workspace's "FishIcons" attribute, "Model", shows the models again (to compare).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local FishIcons = require(script.Parent.FishIcons)
local Kit = require(script.Parent.Kit)

local Portrait = {}

export type Portrait = {
	Frame: Frame,
	show: (id: string?) -> boolean, -- false when that creature has no model to draw yet
}

-- Tip (nose up), Yaw (turned from side on toward the front) and Pitch (seen from above), in degrees
type Pose = { Tip: number, Yaw: number, Pitch: number }
-- Where what is measured sits in the window, in shares of it: X and Y its middle, Wide and High the most room it takes
type Place = { X: number, Y: number, Wide: number, High: number }
export type Settings = {
	Fov: number,
	Outline: number, -- the outline's thickness, a share of the window's height, rounded to whole pixels (at least 1)
	Small: number, -- a creature this long or shorter is shown whole
	Compact: number, -- and so is one this many times longer than it is tall, with no head of its own
	Cut: number, -- a bust keeps the body parts that reach within this many head lengths behind the head
	ArmPieces: number, -- and a squid this many pieces of each arm (A1a, A1b...)
	TailPieces: number, -- and a ray this many pieces of its tail (Tail1, Tail2...)
	-- what a bust is sized and placed by: "Shape", everything left after the cut (so every bust fills its picture alike),
	-- or "Head", its head alone (so every head is the same size, however long or wide the rest)
	Measure: string,
	-- and a squid: "Shape", its mantle and head whole (an octopus's mantle is what reads as its head); "Head", its head
	-- and eyes alone, the mantle running out of the top; "Auto", the head for a squid too long and thin to read whole
	SquidBy: string,
	MostlyHead: number, -- and so is one whose head is this much of it
	Poses: { [string]: Pose },
	Places: { [string]: Place },
	Ambient: Color3,
	LightColor: Color3,
	Light: Vector3, -- the way the light travels, in the camera's own space (+X right, +Y up, -Z ahead)
}

-- Every number that shapes a picture, in one table so the test sheet can try others (then Portrait.reset())
local Settings: Settings = {
	Fov = 20,
	-- the user, 2026-11-18: "we also need a slightly thicker outline" (the reference's is 2 pixels on a 70-pixel
	-- picture at 720p; ours was 1); then 2026-11-19: "Could we slightly shrink the black border too": 2.8% to 2.2%,
	-- so 2 pixels at both 720p and 1080p where it was 2 and 3
	Outline = 0.022,
	Small = 14,
	Compact = 2.2,
	-- the user, 2026-11-18: "is there no way you can cut off the geometry like they do aswell?" The reference's busts
	-- end in a clean cut through the neck, outlined (seen on its catch banner). A mesh can't be cut in the game, but
	-- our creatures are built of pieces (head, S1, S2...), so a bust drops the pieces behind its neck and ends at a joint
	Cut = 1,
	-- the user, 2026-11-19: "the geometry should cut off on the model for the ss, the ss shouldnt crop the model. may
	-- need to cut the tentacles to fit": what a picture cuts is cut from the model (pieces left out), and everything
	-- left fits inside the picture; nothing runs off its edge
	ArmPieces = 2,
	TailPieces = 1,
	Measure = "Shape",
	-- the user, 2026-11-19: "giant squid, octopus and kraken need to be more head focused with some face"; then "the
	-- octopi and kraken stuffs are cut off the wrong way, should be cut off liek the head": a squid is now a bust like
	-- the others, its mantle and eyes up at the left and its arms cut off at the bottom right
	SquidBy = "Shape",
	MostlyHead = 0.6,
	Poses = {
		-- (one angle for all, the user, 2026-11-19: "the crops are still too irregular in angularity, silhouette general
		-- size and placement"; a thin tall fish turns less, or it would be seen edge on)
		Bust = { Tip = 26, Yaw = 50, Pitch = 10 },
		Whole = { Tip = 14, Yaw = 46, Pitch = 12 },
		Thin = { Tip = 12, Yaw = 30, Pitch = 10 },
		Flat = { Tip = 8, Yaw = 40, Pitch = 34 },
		-- (a squid's front is its mantle: tipped up more than a fish, so the arms trail down to the bottom right)
		Squid = { Tip = 40, Yaw = 50, Pitch = 10 },
		SquidHead = { Tip = 40, Yaw = 50, Pitch = 10 },
	},
	Places = {
		-- (a bust's whole shape fills the picture, its cut end low at the right, under the name)
		Bust = { X = 0.5, Y = 0.5, Wide = 0.94, High = 0.9 },
		Whole = { X = 0.5, Y = 0.5, Wide = 0.94, High = 0.84 },
		Thin = { X = 0.5, Y = 0.5, Wide = 0.92, High = 0.92 },
		Flat = { X = 0.5, Y = 0.52, Wide = 0.96, High = 0.8 },
		Squid = { X = 0.48, Y = 0.48, Wide = 0.9, High = 0.88 }, -- (the mantle and head whole, as a bust's shape)
		SquidHead = { X = 0.44, Y = 0.4, Wide = 0.58, High = 0.46 }, -- (its head alone, if SquidBy asks for it)
	},
	Ambient = Color3.fromRGB(200, 200, 204),
	LightColor = Color3.fromRGB(140, 136, 128),
	Light = Vector3.new(0.55, -0.7, -0.45),
}
Portrait.Settings = Settings

-- Which parts are the head: a creature has a bust only if it has a part named Head; these then count with it.
-- A creature's head is toward +Z
local HEAD = { "Head", "Jaw", "Crown", "Brow", "Eye" }

-- Cut: the parts a bust leaves out (the body behind its neck, a squid's arms past their first piece)
type View = { Kind: string, Pose: CFrame, From: Vector3, Points: { Vector3 }, Cut: { BasePart } }

-- Where a render sits in its window, in shares of it (ScaleType Fit keeps its shape inside): a bust's front end fills
-- the width, as the model busts run off the window's edge; a whole creature as the models' Whole
local RENDER_PLACE = {
	Bust = { Wide = 1, High = 0.88 },
	Whole = { Wide = 0.94, High = 0.86 },
}

-- A fish's render picture: the page's image and the icon, or nil when it has none (or its page is not uploaded and
-- this is not Studio)
local function render(id: string): (string?, FishIcons.Icon?)
	local icon = FishIcons.Icons[id]
	if not icon then
		return nil, nil
	end
	local studio = RunService:IsStudio()
	if studio and workspace:GetAttribute("FishIcons") == "Model" then
		return nil, nil
	end
	local page = FishIcons.Pages[icon.Page]
	if page and page ~= "" then
		return page, icon
	end
	if studio then
		return FishIcons.Studio[icon.Page], icon
	end
	return nil, nil
end

-- Whether a fish is shown by its render (else by its model)
function Portrait.rendered(id: string): boolean
	return (render(id)) ~= nil
end

local masters: { [string]: Model } = {}
local views: { [string]: View } = {}

-- Forgets every kept creature, so the next pictures are posed and measured again (after Settings change)
function Portrait.reset()
	for _, model in masters do
		model:Destroy()
	end
	table.clear(masters)
	table.clear(views)
end

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

-- The way to the viewer from the creature, for a pose
local function from(pose: Pose): Vector3
	local yaw, pitch = math.rad(pose.Yaw), math.rad(pose.Pitch)
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

-- The eight corners of a part's box
local function corners(part: BasePart, into: { Vector3 })
	local cf, half = part.CFrame, part.Size / 2
	for i = 0, 7 do
		table.insert(
			into,
			cf
				* Vector3.new(
					if bit32.band(i, 1) == 0 then -half.X else half.X,
					if bit32.band(i, 2) == 0 then -half.Y else half.Y,
					if bit32.band(i, 4) == 0 then -half.Z else half.Z
				)
		)
	end
end

-- How a creature set at the middle, unturned, is shown: which kind of picture, its pose, from where, and the points its
-- picture is measured by (the corners of its parts' boxes, posed: for a bust only its head and the body just behind)
local function frame(model: Model): View
	local _, size = model:GetBoundingBox()
	local all: { Vector3 } = {}
	local head: { Vector3 } = {}
	local hasHead, hasMantle = false, false
	local headBack, headFront = math.huge, -math.huge
	local front = -math.huge
	local pieces: { { Part: BasePart, Front: number, Arm: boolean, Tail: boolean, Corners: { Vector3 } } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 then
			local own: { Vector3 } = {}
			corners(d, own)
			local reach = -math.huge
			for _, at in own do
				reach = math.max(reach, at.Z)
			end
			local named = isHead(d.Name)
			hasHead = hasHead or string.sub(d.Name, 1, 4) == "Head"
			hasMantle = hasMantle or string.sub(d.Name, 1, 6) == "Mantle"
			-- (a ray's tail past its first pieces is left out: Tail2, Tail3...)
			local tailPiece = tonumber(string.match(d.Name, "^Tail(%d+)$"))
			local longTail = tailPiece ~= nil and tailPiece > Settings.TailPieces
			local arm = string.match(d.Name, "^A%d") ~= nil or string.sub(d.Name, 1, 8) == "Tentacle"
			-- (an arm's first pieces stay on a squid: A1a, A2a... and A1b... for two)
			local piece = string.match(d.Name, "^A%d+(%l)")
			local kept = piece ~= nil and string.byte(piece) - 96 <= Settings.ArmPieces
			table.insert(pieces, { Part = d, Front = reach, Arm = arm and not kept, Tail = longTail, Corners = own })
			for _, at in own do
				table.insert(all, at)
				front = math.max(front, at.Z)
				if named then
					table.insert(head, at)
					headBack = math.min(headBack, at.Z)
					headFront = math.max(headFront, at.Z)
				end
			end
		end
	end
	-- everything from `back` forward
	local function frontOf(back: number): { Vector3 }
		local kept: { Vector3 } = {}
		for _, at in all do
			if at.Z >= back then
				table.insert(kept, at)
			end
		end
		return kept
	end
	local kind, points = nil :: string?, all
	local cut: { BasePart } = {}
	-- the pieces wholly behind `back`, left out of a bust
	local function behind(back: number)
		for _, piece in pieces do
			if piece.Front < back then
				table.insert(cut, piece.Part)
			end
		end
	end
	-- the corners of every piece a bust keeps
	local function left(): { Vector3 }
		local gone: { [BasePart]: boolean } = {}
		for _, part in cut do
			gone[part] = true
		end
		local kept: { Vector3 } = {}
		for _, piece in pieces do
			if not gone[piece.Part] then
				for _, at in piece.Corners do
					table.insert(kept, at)
				end
			end
		end
		return kept
	end
	local tall = math.max(size.Y, size.X * 0.7)
	if hasMantle and hasHead and size.Z > Settings.Small then
		-- a squid, an octopus, the kraken: its head (the mantle and the eyes), the arms left hanging out of the bottom
		for _, piece in pieces do
			if piece.Arm then
				table.insert(cut, piece.Part)
			end
		end
		local thin = size.Z > math.max(size.X, size.Y) * 3.5
		if #head > 0 and (Settings.SquidBy == "Head" or (Settings.SquidBy == "Auto" and thin)) then
			kind, points = "SquidHead", head
		else
			-- everything it keeps, the arms' first pieces too, so nothing runs off the picture's edge
			kind, points = "Squid", left()
		end
	elseif size.X > size.Y * 2.2 and (not hasHead or size.Z <= size.X * 1.3) then
		for _, piece in pieces do
			if piece.Tail then
				table.insert(cut, piece.Part)
			end
		end
		kind, points = "Flat", left()
	elseif size.Z > Settings.Small then
		if hasHead and headFront - headBack < size.Z * Settings.MostlyHead then
			-- (by the head's own parts: the body part behind is as wide as the fins on it, and made every head small)
			kind, points = "Bust", head
			behind(headBack - (headFront - headBack) * Settings.Cut)
			if Settings.Measure == "Shape" then
				points = left()
			end
		elseif not hasHead and size.Z > tall * Settings.Compact then
			-- long, with no head of its own to go by: its front end, as long as it is tall and a quarter more
			local back = front - math.clamp(tall * 1.25, size.Z * 0.28, size.Z * 0.6)
			kind, points = "Bust", frontOf(back)
			behind(back - (front - back) * Settings.Cut)
			if Settings.Measure == "Shape" then
				points = left()
			end
		end
	end
	if not kind then
		kind = if size.X < size.Y * 0.6 then "Thin" else "Whole"
	end
	local chosen: string = kind :: string
	local pose = Settings.Poses[chosen]
	local turn = CFrame.Angles(-math.rad(pose.Tip), 0, 0)
	local posed: { Vector3 } = {}
	for i, at in points do
		posed[i] = turn * at
	end
	return { Kind = chosen, Pose = turn, From = from(pose), Points = posed, Cut = cut }
end

-- Where the camera stands so what is measured sits where its kind's does (Settings.Places), for a window `aspect` times
-- wider than tall; and how far ahead of the camera that is. Found by stepping: back or forward until it is the right
-- size, then sideways and up until it is in the right place, a few times over (a step changes the other a little)
local function stand(view: View, aspect: number): (CFrame, number)
	local place = Settings.Places[view.Kind]
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
	local tanV = math.tan(math.rad(Settings.Fov / 2))
	local tanH = tanV * aspect
	local distance = reach / tanV + reach
	local across, upward = 0, 0
	local function eye(): Vector3
		return centre + view.From * distance + right * across + up * upward
	end
	-- the edges of what is measured, on the window: -1 to 1 across (left to right) and up
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
		across += ((x0 + x1) / 2 - (2 * place.X - 1)) * distance * tanH
		upward += ((y0 + y1) / 2 - (1 - 2 * place.Y)) * distance * tanV
	end
	local at = eye()
	return CFrame.fromMatrix(at, right, up), (centre - at):Dot(ahead)
end

-- The kept copy of a kind: only what draws (parts, their meshes and textures), set at the middle in its pose
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
	-- (the pivot kept at the middle, whatever piece is cut away)
	copy.PrimaryPart = nil
	copy.WorldPivot = CFrame.new()
	-- turned round if its head is clearly at the back end (a template installed the other way: CosmicHollow's,
	-- 2026-11-18; a squid's head is near its middle and stays)
	local headZ, heads = 0, 0
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") and isHead(d.Name) then
			headZ += d.Position.Z
			heads += 1
		end
	end
	local _, length = copy:GetBoundingBox()
	if heads > 0 and headZ / heads < -length.Z * 0.25 then
		copy:PivotTo(CFrame.Angles(0, math.pi, 0))
		copy.WorldPivot = CFrame.new()
	end
	local view = frame(copy)
	for _, part in view.Cut do
		part:Destroy()
	end
	copy:PivotTo(view.Pose)
	views[id] = view
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

local OUTLINE_WAYS = 8

-- props: where the picture sits (a Frame's own properties), Outline: its outline's thickness as a share of the
-- picture's height (0 for none; Settings.Outline when left out), and Aspect: the window's width over its height to frame
-- by (else measured when shown). Two windows of one Aspect show a creature as the same picture, whatever their size:
-- the catch screen's tiles use the slots' (Slots.Aspect)
function Portrait.new(parent: Instance, props: { [string]: any }): Portrait
	local share: number? = props.Outline
	local aspect: number? = props.Aspect
	props.Outline = nil
	props.Aspect = nil
	props.BackgroundTransparency = 1
	local holder: Frame = Kit.new("Frame", props, parent)

	local function window(black: boolean): (ViewportFrame, Camera)
		local view: ViewportFrame = Kit.new("ViewportFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Ambient = Settings.Ambient,
			LightColor = Settings.LightColor,
			ImageColor3 = if black then Color3.new(0, 0, 0) else Kit.White,
			ZIndex = if black then 1 else 2,
		}, holder)
		local camera: Camera = Kit.new("Camera", { FieldOfView = Settings.Fov }, view)
		view.CurrentCamera = camera
		return view, camera
	end
	local ink, inkCamera = window(true)
	local colour, camera = window(false)

	-- A fish with a render (Hugo's task r1, render above): its picture in colour over OUTLINE_WAYS black copies, each a
	-- whole number of pixels off in its own direction, the same outline as a model's. Made the first time one shows.
	local images: { ImageLabel } = {}
	local ways: { Vector2 } = {}
	local function pictures(): { ImageLabel }
		if #images == 0 then
			for k = 0, OUTLINE_WAYS do
				local black = k > 0
				local turn = (k - 1) / OUTLINE_WAYS * 2 * math.pi
				table.insert(ways, if black then Vector2.new(math.cos(turn), math.sin(turn)) else Vector2.zero)
				table.insert(
					images,
					Kit.new("ImageLabel", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						BackgroundTransparency = 1,
						ScaleType = Enum.ScaleType.Fit,
						ImageColor3 = if black then Color3.new(0, 0, 0) else Kit.White,
						ZIndex = if black then 1 else 2,
						Visible = false,
					}, holder)
				)
			end
		end
		return images
	end
	-- (how many screen pixels an offset unit is here: every UIScale above multiplied, the HUD's own, a slot's grow)
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
		for _, image in images do
			image.Visible = false
		end
		colour.Visible, ink.Visible = true, true
		if not id then
			return true
		end
		local across = holder.AbsoluteSize
		-- the outline's thickness, as a share of the picture's height
		local thick = share or Settings.Outline
		local page, icon = render(id)
		if page and icon then
			-- the render instead of the model, in the same place with the same outline
			local place = if icon.Bust then RENDER_PLACE.Bust else RENDER_PLACE.Whole
			local step = if thick > 0 and across.Y > 0
				then math.max(1, math.floor(thick * across.Y + 0.5)) / pixels()
				else 0
			for i, image in pictures() do
				local way = ways[i]
				image.Image = page
				image.ImageRectOffset = Vector2.new(icon.X, icon.Y)
				image.ImageRectSize = Vector2.new(icon.W, icon.H)
				image.Size = UDim2.fromScale(place.Wide, place.High)
				image.Position = UDim2.new(0.5, way.X * step, 0.5, way.Y * step)
				image.Visible = i == 1 or step > 0
			end
			colour.Visible, ink.Visible = false, false
			shownId = id
			return true
		end
		local source = master(id)
		if not source then
			return false -- (not remembered: the next call looks again)
		end
		local at, depth = stand(views[id], aspect or (if across.Y > 0 then across.X / across.Y else 1))
		camera.CFrame, inkCamera.CFrame = at, at
		-- the light from over the viewer's shoulder, whichever way this creature is seen
		local light = at:VectorToWorldSpace(Settings.Light).Unit
		colour.LightDirection, ink.LightDirection = light, light
		local copy = source:Clone()
		copy.Parent = colour
		table.insert(shown, copy)
		-- the outline: the same thickness in whole pixels all round (a pixel's width in the world, at the creature)
		if thick > 0 then
			local high = across.Y
			local pixel = 2 * depth * math.tan(math.rad(Settings.Fov / 2)) / math.max(high, 1)
			local reach = if high > 0 then math.max(1, math.floor(thick * high + 0.5)) * pixel else thick * pixel
			local pivot = source:GetPivot()
			for i = 1, OUTLINE_WAYS do
				local turn = (i - 1) / OUTLINE_WAYS * 2 * math.pi
				local offset = (at.RightVector * math.cos(turn) + at.UpVector * math.sin(turn)) * reach
				local black = source:Clone()
				black:PivotTo(CFrame.new(offset) * pivot)
				black.Parent = ink
				table.insert(shown, black)
			end
		end
		shownId = id
		return true
	end
	return { Frame = holder, show = show }
end

return Portrait
