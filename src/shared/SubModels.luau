--!strict
-- The submarines you can buy at the stand (Hugo, 2026-11-18: "add placeholder models for upgrades"): one a tier, tier N
-- carries you to land N + 1 (Config.Sub.Prices). Placeholders only, plain parts with a floating name, each tier a new
-- colour and one more piece than the last, so an upgrade reads at a glance. The partner's models replace `build`.
--   SubModels.List[n]   { Name, Hull, Trim, Light }
--   SubModels.build(n)  the model, its parts, its propeller and the wake's emitter. It faces -Z, its middle at the
--     origin; the seat is the same on every tier (SubController's SEAT), so the ride doesn't change with the look.
local SubModels = {}

export type Style = { Name: string, Hull: Color3, Trim: Color3, Light: Color3 }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

SubModels.List = {
	{ Name = "Bathtub", Hull = rgb(255, 196, 38), Trim = rgb(40, 54, 78), Light = rgb(120, 220, 255) },
	{ Name = "Reef Runner", Hull = rgb(255, 128, 40), Trim = rgb(60, 40, 30), Light = rgb(255, 240, 160) },
	{ Name = "Kelp Cruiser", Hull = rgb(70, 200, 90), Trim = rgb(24, 70, 40), Light = rgb(200, 255, 140) },
	{ Name = "Wreck Diver", Hull = rgb(176, 96, 52), Trim = rgb(54, 44, 40), Light = rgb(255, 200, 120) },
	{ Name = "Blue Streak", Hull = rgb(40, 140, 255), Trim = rgb(230, 240, 255), Light = rgb(140, 255, 255) },
	{ Name = "Twilight Ray", Hull = rgb(150, 80, 230), Trim = rgb(40, 24, 70), Light = rgb(255, 140, 255) },
	{ Name = "Midnight Hunter", Hull = rgb(30, 40, 70), Trim = rgb(10, 14, 24), Light = rgb(60, 255, 230) },
	{ Name = "Vent Crawler", Hull = rgb(220, 50, 40), Trim = rgb(30, 20, 20), Light = rgb(255, 170, 40) },
	{ Name = "Abyss King", Hull = rgb(255, 214, 70), Trim = rgb(20, 16, 30), Light = rgb(255, 80, 120) },
} :: { Style }

function SubModels.style(tier: number): Style
	return SubModels.List[math.clamp(math.floor(tier), 1, #SubModels.List)]
end

-- Every part is anchored and touches nothing; the whole model is moved by PivotTo (or part by part, SubController)
function SubModels.build(tier: number): (Model, { BasePart }, BasePart, ParticleEmitter)
	local s = SubModels.style(tier)
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
	-- the label: the sub's name over its tower
	local sign = Instance.new("BillboardGui")
	sign.Name = "Label"
	sign.Size = UDim2.fromScale(14, 3)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	sign.MaxDistance = 140
	sign.LightInfluence = 0
	sign.Parent = tower
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.LuckiestGuy
	text.TextScaled = true
	text.Text = string.upper(s.Name)
	text.TextColor3 = HULL
	text.TextStrokeColor3 = Color3.fromRGB(16, 36, 63)
	text.TextStrokeTransparency = 0
	text.Parent = sign
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Wake"
	bubbles.Color = ColorSequence.new(Color3.new(1, 1, 1))
	bubbles.LightEmission = 0.4
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.4) })
	bubbles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	bubbles.Lifetime = NumberRange.new(0.8, 1.6)
	bubbles.Speed = NumberRange.new(4, 10)
	bubbles.SpreadAngle = Vector2.new(35, 35)
	bubbles.Acceleration = Vector3.new(0, 6, 0)
	bubbles.Rate = 0
	bubbles.EmissionDirection = Enum.NormalId.Back
	bubbles.Parent = prop
	model.WorldPivot = CFrame.identity
	return model, parts, prop, bubbles
end

return SubModels
