--!strict
-- The submarines you can buy at the stand: one a tier, tier N carries you to land N + 1 (Config.Sub.Prices).
-- Each is its own model, since 2026-11-23 in the chunky toy style Hugo picked (docs/design/sub-models.md:
-- tools/blender/sub_stages.py builds them, tools/subs/install.py puts them in the place as
-- ReplicatedStorage.SubMeshes.<Id>, one MeshPart to a part: Hull, Hull_Glow, Seat, Prop, Prop_Glow, Light). A place
-- without a tier's template gets the old placeholder of plain parts (Hugo, 2026-11-18), each tier a new colour and one
-- more piece than the last.
--   SubModels.List[n]   { Id, Name, Hull, Trim, Light }   (the colours are baked into the meshes: keep TIERS, and
--     CREATURES for tiers 8 and 9, in tools/blender/sub_stages.py alike)
--   SubModels.build(n)  the model, its parts, its propeller and the bubble trail's emitter. It faces -Z, its middle
--     at the origin; the seat is the same on every tier (SubController's SEAT), so the ride doesn't change with the look.
--     The emitter is named "Wake", on the attachment "WakeAt" on the hull at the screw's end; it makes nothing until
--     its Rate is set (SubController, by Config.Sub's Wake numbers): the shop's cards and the stand's sub have none.
--     Parts named "Prop" and "Prop_Glow" spin about their own Z (SubController). The part named "Blur" is the blur
--     disc in the blades (made here by code, not in the mesh): it doesn't turn, and it is unseen until the sub is fast
--     (SubController). Not "..._Glow", or it would be Neon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)

local SubModels = {}

-- SignUp: extra studs for the name sign, for a model with a tall piece far behind the sign (see SIGN_GAP)
-- Blade: the propeller's own colour (the blur disc's), where it isn't white (sub_stages.py's `blades`)
export type Style = {
	Id: string,
	Name: string,
	Hull: Color3,
	Trim: Color3,
	Light: Color3,
	SignUp: number?,
	Blade: Color3?,
}

SubModels.Templates = "SubMeshes"

-- The name sign over a sub: how tall it is, and how far its lower edge stays over a model's tallest piece (studs)
local SIGN_TALL = 3
-- (0.6 until task m4: seen in the game, a snorkel, a kelp leaf, a periscope, a fin and the crown ran into the letters)
local SIGN_GAP = 2
-- That is enough for a piece under the sign. A tall piece far BEHIND the sign stands between it and the run's camera
-- (behind and above the sub), so in the picture it reaches higher than its own height: Blue Streak's tail fin, 20
-- studs back, covered the middle of its name. Such a model has `SignUp` in its row, from
-- `python tools/subs/sign_fit.py` (run its --check after a model is rebuilt or the run camera moves). That sum has
-- the sub level. On a real trip it dips and banks and the camera eases after it, which brought the fin about 1 stud
-- further up the sign: `python tools/studio/m4_subs_shots.py numbers`, in a playtest, measures the trip itself.
-- a hull darker than this (Color3's own 0 to 1, by eye's weights) gives a name nobody can read on the sign's dark
-- outline: Midnight Hunter's navy. Its name is written in its light's colour instead
local SIGN_DARK = 0.25
-- The name's look: option D of docs/attachments/sub-name-text-options-1.png, "today's font, dressed" (Hugo, 2026-11-24:
-- "use text D"): Luckiest Guy in the land title's metal shading, a thick ink edge and a darker copy a step down, and
-- no glow. Every measure is a share of the letters, the edge too: an edge that stays 3 pixels thick closes the gaps
-- between the letters when the sign is far off (the sheet's "far away" row). So a label is exactly as tall as its line.
local SIGN_WIDE = 14
local SIGN_FONT = Enum.Font.LuckiestGuy
local SIGN_EDGE = 0.085 -- the ink edge
local SIGN_DROP = 0.1 -- how far down the darker copy stands
local SIGN_SHIFT = 0.144 -- the shading is moved up this far: Luckiest Guy's letters sit high in their line
local SIGN_INK = Color3.fromRGB(16, 36, 63)

-- The blur disc (docs/design/sub-props.md, "The blur disc"): in studs behind the propeller box's front end, and the
-- blades' reach against half the box's width (a turned screw reaches further than its box's side)
local BLUR_BACK, BLUR_REACH, BLUR_THICK = 1.11, 1.18, 0.04
local BLADE_WHITE = Color3.fromRGB(244, 241, 230)

-- The bubble trail's look: the aura shop's bubble (AuraController's `bubbles`: a ring, so the screw shows through it),
-- in the pale blue of the game's other bubbles (Lib/Fx). A picture Roblox ships: nothing uploaded
local WAKE_PICTURE = "rbxasset://textures/particles/explosion01_shockwave_main.dds"
local WAKE_COLOUR = Color3.fromRGB(225, 248, 255)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

SubModels.List = {
	{ Id = "Bathtub", Name = "Bathtub", Hull = rgb(255, 196, 38), Trim = rgb(40, 54, 78), Light = rgb(120, 220, 255) },
	{
		Id = "ReefRunner",
		Name = "Reef Runner",
		Hull = rgb(255, 128, 40),
		Trim = rgb(60, 40, 30),
		Light = rgb(255, 240, 160),
	},
	{
		Id = "KelpCruiser",
		Name = "Kelp Cruiser",
		Hull = rgb(70, 200, 90),
		Trim = rgb(24, 70, 40),
		Light = rgb(200, 255, 140),
	},
	{
		Id = "WreckDiver",
		Name = "Wreck Diver",
		Hull = rgb(176, 96, 52),
		Trim = rgb(54, 44, 40),
		Light = rgb(255, 200, 120),
	},
	{
		Id = "BlueStreak",
		Name = "Blue Streak",
		Hull = rgb(40, 140, 255),
		Trim = rgb(230, 240, 255),
		Light = rgb(140, 255, 255),
		SignUp = 5.7, -- the tail fin: 4.7 by sign_fit (the sub level), 1 more for the dips of a real trip (measured)
	},
	{
		Id = "TwilightRay",
		Name = "Twilight Ray",
		Hull = rgb(150, 80, 230),
		Trim = rgb(40, 24, 70),
		Light = rgb(255, 140, 255),
		Blade = rgb(255, 200, 90),
	},
	{
		Id = "MidnightHunter",
		Name = "Midnight Hunter",
		Hull = rgb(30, 40, 70),
		Trim = rgb(10, 14, 24),
		Light = rgb(60, 255, 230),
		Blade = rgb(240, 240, 235),
	},
	{
		Id = "VentCrawler",
		Name = "Vent Crawler",
		-- (since 2026-11-24 the model is our Sea Scorpion, option 8A: rust, not red)
		Hull = rgb(206, 98, 48),
		Trim = rgb(52, 28, 24),
		Light = rgb(255, 150, 30),
	},
	{
		Id = "AbyssKing",
		Name = "Abyss King",
		-- (since 2026-11-24 the gold hull is held by a kraken, option 9A: its lights are the suckers' cyan)
		Hull = rgb(255, 206, 56),
		Trim = rgb(30, 22, 44),
		Light = rgb(96, 244, 226),
		Blade = rgb(150, 70, 220),
	},
} :: { Style }

function SubModels.style(tier: number): Style
	return SubModels.List[math.clamp(math.floor(tier), 1, #SubModels.List)]
end

-- A name sign's four tones and its fill from one colour: the land title's (UI/Kit's palOf and wordFill, which only a
-- client can read: keep them alike)
local function signTones(colour: Color3): (ColorSequence, Color3)
	local white, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
	local h, s, v = colour:ToHSV()
	local full = Color3.fromHSV(h, math.min(1, s * 1.35 + 0.08), math.max(v, 0.9))
	local light, mid = full:Lerp(white, 0.66), full:Lerp(white, 0.2)
	local dark = Color3.fromHSV(h, math.min(1, s * 1.35 + 0.15), math.max(v, 0.9) * 0.66)
	local deep = Color3.fromHSV(h, math.min(1, s * 1.2 + 0.2), 0.3)
	local fill = ColorSequence.new({
		ColorSequenceKeypoint.new(0, light:Lerp(white, 0.5)),
		ColorSequenceKeypoint.new(0.48, light:Lerp(mid, 0.35)),
		ColorSequenceKeypoint.new(0.52, mid),
		ColorSequenceKeypoint.new(1, mid:Lerp(dark, 0.55)),
	})
	return fill, deep:Lerp(black, 0.2)
end

-- The name's letters on its sign, back to front: the darker copy a step down, the shaded word with its ink edge, the
-- thin shine across its upper part
local function signWord(sign: BillboardGui, name: string, colour: Color3)
	local word = string.upper(name)
	-- the line as tall as the sign, or less where the word is too wide for it
	local wide = TextService:GetTextSize(word, 100, SIGN_FONT, Vector2.new(5000, 200)).X / 100
	local tall = math.min(SIGN_TALL, SIGN_WIDE / math.max(wide, 0.1))
	local fill, under = signTones(colour)
	local function layer(at: number, name_: string, down: number, edge: boolean): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = name_
		text.BackgroundTransparency = 1
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.Position = UDim2.fromScale(0.5, 0.5 + down * tall / SIGN_TALL)
		-- (a little wider than the letters, so it is the line's height that sets their size)
		text.Size = UDim2.fromScale(1.1, tall / SIGN_TALL)
		text.Font = SIGN_FONT
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Text = word
		text.ZIndex = at
		if edge then
			local ink = Instance.new("UIStroke")
			ink.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
			ink.Thickness = SIGN_EDGE
			ink.Color = SIGN_INK
			ink.LineJoinMode = Enum.LineJoinMode.Round
			ink.Parent = text
		end
		text.Parent = sign
		return text
	end
	local function shade(text: TextLabel): UIGradient
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Offset = Vector2.new(0, -SIGN_SHIFT)
		g.Parent = text
		return g
	end
	shade(layer(2, "Word", 0, true)).Color = fill
	layer(1, "Drop", SIGN_DROP, true).TextColor3 = under
	shade(layer(3, "Shine", 0, false)).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.3, 0.15),
		NumberSequenceKeypoint.new(0.35, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- What every sub carries, model or placeholder: the lamp's beam, the hull's glow, the name over the tower (`over`: from
-- `tower`'s middle to where the name's middle goes) and the bubble trail behind the propeller
local function dress(
	s: Style,
	hull: BasePart,
	tower: BasePart,
	over: Vector3,
	prop: BasePart,
	lamp: BasePart
): ParticleEmitter
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Range = 60
	beam.Angle = 50
	beam.Brightness = 4
	beam.Color = Color3.fromRGB(255, 244, 200)
	beam.Parent = lamp
	local glow = Instance.new("PointLight")
	glow.Range = 22
	glow.Brightness = 1.5
	glow.Color = s.Light
	glow.Parent = hull
	-- the label: the sub's name over its tower. StudsOffsetWorldSpace keeps to the world's axes whichever way the part
	-- is turned, and that is wanted: the name stays straight over the sub while it dips and banks, so in the run's
	-- picture it stays the topmost thing. (Tried 2026-11-23: the place as an Attachment, turning with the sub. On a
	-- real trip the tail then came in front of the name on up to 39% of the frames (tier 9; 24% on tier 8). This way
	-- it is 2% at most: Twilight Ray's tail in one bend, and Blue Streak's fin before its SignUp.
	-- tools/studio/m4_subs_shots.py numbers.)
	local sign = Instance.new("BillboardGui")
	sign.Name = "Label"
	sign.Size = UDim2.fromScale(SIGN_WIDE, SIGN_TALL)
	sign.ClipsDescendants = false
	sign.StudsOffsetWorldSpace = over
	sign.MaxDistance = 140
	sign.LightInfluence = 0
	sign.Parent = tower
	local bright = 0.2126 * s.Hull.R + 0.7152 * s.Hull.G + 0.0722 * s.Hull.B
	signWord(sign, s.Name, if bright < SIGN_DARK then s.Light else s.Hull)
	-- The bubble trail (Hugo, 2026-11-24: "add a bubble trail right behind the propeller"; docs/design/sub-props.md,
	-- "The bubble trail"). The bubbles travel WITH the sub (LockedToPart) and stream back from the screw's end at
	-- Sub.WakeSpeed, so the trail is a jet about WakeSpeed x WakeLife studs long that stays behind the screw at any
	-- speed. (Until then they were left where they were made: at 464 studs a second and more the sub and the camera
	-- behind it had passed each one within two frames, and none was ever seen.) It hangs on the hull, on a point at
	-- the screw's end, not on the propeller: locked to a part that spins, the bubbles would whirl round with it.
	-- Placed by the world, as the placeholder's hull lies turned.
	local c = Config.Sub
	local wakeAt = Instance.new("Attachment")
	wakeAt.Name = "WakeAt"
	wakeAt.Parent = hull
	wakeAt.WorldCFrame = CFrame.new(prop.Position + Vector3.new(0, 0, prop.Size.Z / 2))
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Wake"
	bubbles.Texture = WAKE_PICTURE
	bubbles.Color = ColorSequence.new(WAKE_COLOUR)
	bubbles.LightEmission = 1
	bubbles.LightInfluence = 0
	bubbles.Brightness = c.WakeBright
	-- a bubble swells as it leaves the screw, then shrinks and fades toward the stream's end (which is the end nearer
	-- the camera: nothing grows on its way to the screen)
	bubbles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, c.WakeSize * 0.4),
		NumberSequenceKeypoint.new(0.12, c.WakeSize, c.WakeSize * 0.25),
		NumberSequenceKeypoint.new(1, c.WakeSizeEnd, c.WakeSizeEnd * 0.25),
	})
	-- (it comes in faint: the newest bubbles lie over one another on the hub, and would be one white blob there)
	bubbles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.15, c.WakeSee),
		-- (still clear well down the trail: seen from behind, the rings are told apart only once they have fanned out;
		-- halfway to gone here, as it was until task s2, they had faded before that. Seen in Studio, 2026-11-24)
		NumberSequenceKeypoint.new(0.6, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	bubbles.Lifetime = NumberRange.new(c.WakeLife * 0.8, c.WakeLife * 1.15)
	bubbles.Speed = NumberRange.new(c.WakeSpeed * 0.85, c.WakeSpeed * 1.15)
	bubbles.SpreadAngle = Vector2.new(c.WakeSpread, c.WakeSpread)
	bubbles.Acceleration = Vector3.new(0, c.WakeRise, 0)
	bubbles.Rotation = NumberRange.new(0, 360)
	bubbles.LockedToPart = true
	bubbles.Rate = 0
	bubbles.EmissionDirection = Enum.NormalId.Back
	bubbles.Parent = wakeAt
	return bubbles
end

-- The tier's own model, from the place's template (built at the origin, facing -Z), or nil when the place has none
local function fromTemplate(s: Style, n: number): (Model?, { BasePart }, BasePart?, ParticleEmitter?)
	local folder = ReplicatedStorage:FindFirstChild(SubModels.Templates)
	local template = folder and folder:FindFirstChild(s.Id)
	if not (template and template:IsA("Model")) then
		return nil, {}, nil, nil
	end
	local model = template:Clone()
	local hull, prop, lamp = model:FindFirstChild("Hull"), model:FindFirstChild("Prop"), model:FindFirstChild("Light")
	if
		not (hull and hull:IsA("BasePart") and prop and prop:IsA("BasePart") and lamp and lamp:IsA("BasePart"))
		or not model:FindFirstChild("Seat")
	then
		model:Destroy()
		return nil, {}, nil, nil
	end
	model.Name = "Submarine"
	model:SetAttribute("Tier", n)
	local parts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Name == "Light" or string.match(d.Name, "_Glow$") then
				d.Material = Enum.Material.Neon
			end
			table.insert(parts, d)
		end
	end
	model.PrimaryPart = hull
	-- the blur disc, low in the blades (a cylinder's axis is its X: turned to lie along the hub)
	local blur = Instance.new("Part")
	blur.Name = "Blur"
	blur.Shape = Enum.PartType.Cylinder
	local across = math.max(prop.Size.X, prop.Size.Y) * BLUR_REACH
	blur.Size = Vector3.new(BLUR_THICK, across, across)
	blur.CFrame = prop.CFrame * CFrame.new(0, 0, BLUR_BACK - prop.Size.Z / 2) * CFrame.Angles(0, math.rad(90), 0)
	blur.Color = s.Blade or BLADE_WHITE
	blur.Material = Enum.Material.SmoothPlastic
	blur.Transparency = 1
	blur.Anchored = true
	blur.CanCollide = false
	blur.CanQuery = false
	blur.CanTouch = false
	blur.CastShadow = false
	blur.TopSurface = Enum.SurfaceType.Smooth
	blur.BottomSurface = Enum.SurfaceType.Smooth
	blur.Parent = model
	table.insert(parts, blur)
	-- the name clears the tier's tallest piece (a snorkel, a periscope, a fin, a crown): the sign is SIGN_TALL studs
	-- tall, and its lower edge stays SIGN_GAP over the model's top, never lower than the placeholder's 12.5
	local top = -math.huge
	for _, p in parts do
		top = math.max(top, p.Position.Y + p.Size.Y / 2)
	end
	local signY = math.max(12.5, top + SIGN_GAP + SIGN_TALL / 2) + (s.SignUp or 0)
	local bubbles = dress(s, hull, hull, Vector3.new(0, signY, -2) - hull.Position, prop, lamp)
	return model, parts, prop, bubbles
end

-- Every part is anchored and touches nothing; the whole model is moved part by part (SubController)
function SubModels.build(tier: number): (Model, { BasePart }, BasePart, ParticleEmitter)
	local s = SubModels.style(tier)
	do
		local made, madeParts, madeProp, madeBubbles = fromTemplate(s, math.clamp(math.floor(tier), 1, #SubModels.List))
		if made and madeProp and madeBubbles then
			return made, madeParts, madeProp, madeBubbles
		end
	end
	local n = math.clamp(math.floor(tier), 1, #SubModels.List)
	local HULL, TRIM, GLASS = s.Hull, s.Trim, s.Light
	local model = Instance.new("Model")
	model.Name = "Submarine"
	model:SetAttribute("Tier", n)
	local parts: { BasePart } = {}
	local function part(
		name: string,
		shape: Enum.PartType,
		size: Vector3,
		at: CFrame,
		colour: Color3,
		material: Enum.Material?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.CFrame = at
		p.Color = colour
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		table.insert(parts, p)
		return p
	end
	local along = CFrame.Angles(0, math.rad(90), 0) -- a cylinder's axis is its X: turned to lie along Z
	local hull = part("Hull", Enum.PartType.Cylinder, Vector3.new(26, 10, 10), along, HULL)
	model.PrimaryPart = hull
	part("Nose", Enum.PartType.Ball, Vector3.new(10, 10, 10), CFrame.new(0, 0, -13), HULL)
	part("Tail", Enum.PartType.Ball, Vector3.new(8, 8, 8), CFrame.new(0, 0, 13), HULL)
	local tower = part("Tower", Enum.PartType.Block, Vector3.new(5, 6, 9), CFrame.new(0, 6.5, -2), HULL)
	part("TowerCap", Enum.PartType.Block, Vector3.new(5.6, 1, 9.6), CFrame.new(0, 9.8, -2), TRIM)
	part("Window", Enum.PartType.Block, Vector3.new(4, 2, 0.4), CFrame.new(0, 7.4, -6.6), GLASS, Enum.Material.Neon)
	part("Seat", Enum.PartType.Block, Vector3.new(3.4, 1, 3.4), CFrame.new(0, 5.2, 5), TRIM)
	part("Bar", Enum.PartType.Block, Vector3.new(4.4, 0.6, 0.6), CFrame.new(0, 6.8, 2.6), TRIM)
	for _, side in { -1, 1 } do
		for _, z in { -6, 0 } do
			part(
				"Port",
				Enum.PartType.Cylinder,
				Vector3.new(0.6, 2.6, 2.6),
				CFrame.new(side * 5, 0.5, z),
				GLASS,
				Enum.Material.Neon
			)
		end
		part("Wing", Enum.PartType.Block, Vector3.new(6, 0.8, 3.4), CFrame.new(side * 7, -1, -7), TRIM)
		-- one more piece a tier
		if n >= 2 then -- a stripe along each side
			part("Stripe", Enum.PartType.Block, Vector3.new(0.4, 1.2, 20), CFrame.new(side * 5, -2.4, 0), TRIM)
		end
		if n >= 3 then -- a second, longer pair of fins at the back
			part("BackWing", Enum.PartType.Block, Vector3.new(7, 0.8, 3), CFrame.new(side * 7.5, -1, 8), TRIM)
		end
		if n >= 5 then -- a pod on each side, with a light at its nose
			part("Pod", Enum.PartType.Cylinder, Vector3.new(12, 3.4, 3.4), CFrame.new(side * 9.5, -1, 0) * along, HULL)
			part(
				"PodLight",
				Enum.PartType.Ball,
				Vector3.new(2, 2, 2),
				CFrame.new(side * 9.5, -1, -6.2),
				GLASS,
				Enum.Material.Neon
			)
		end
		if n >= 7 then -- claws under the nose
			part(
				"Claw",
				Enum.PartType.Block,
				Vector3.new(1, 1, 6),
				CFrame.new(side * 2.4, -4.6, -15) * CFrame.Angles(math.rad(-20), side * math.rad(12), 0),
				TRIM
			)
		end
	end
	if n >= 4 then -- a periscope
		part("Periscope", Enum.PartType.Block, Vector3.new(0.8, 4, 0.8), CFrame.new(0, 12, -4), TRIM)
		part("PeriscopeEye", Enum.PartType.Block, Vector3.new(0.8, 0.8, 2), CFrame.new(0, 14, -4.6), TRIM)
	end
	if n >= 6 then -- a fin along the back of the tower
		part("Crest", Enum.PartType.Block, Vector3.new(0.8, 3, 8), CFrame.new(0, 7, 9), TRIM)
	end
	if n >= 8 then -- spikes along the belly
		for i = -1, 1 do
			part(
				"Spike",
				Enum.PartType.Block,
				Vector3.new(1.2, 3, 1.2),
				CFrame.new(0, -6, i * 7) * CFrame.Angles(math.rad(45), 0, 0),
				TRIM
			)
		end
	end
	if n >= 9 then -- a crown on the tower
		for i = -1, 1 do
			part(
				"Crown",
				Enum.PartType.Block,
				Vector3.new(1, 2.4, 1),
				CFrame.new(i * 1.8, 11.4, -2),
				GLASS,
				Enum.Material.Neon
			)
		end
	end
	part("FinFlat", Enum.PartType.Block, Vector3.new(14, 0.8, 3.4), CFrame.new(0, 0, 14), TRIM)
	part("FinTall", Enum.PartType.Block, Vector3.new(0.8, 9, 3.4), CFrame.new(0, 0, 14), TRIM)
	part("PropHub", Enum.PartType.Ball, Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, 0, 17), TRIM)
	local prop = part("Prop", Enum.PartType.Block, Vector3.new(0.6, 7, 1.4), CFrame.new(0, 0, 17.6), TRIM)
	local lamp = part(
		"Light",
		Enum.PartType.Ball,
		Vector3.new(3, 3, 3),
		CFrame.new(0, -1.5, -17.4),
		Color3.fromRGB(255, 250, 210),
		Enum.Material.Neon
	)
	local bubbles = dress(s, hull, tower, Vector3.new(0, 6, 0), prop, lamp)
	model.WorldPivot = CFrame.identity
	return model, parts, prop, bubbles
end

return SubModels
