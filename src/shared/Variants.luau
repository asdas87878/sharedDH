--!strict
-- The look of a Gold or a Rainbow fish (a fish model's "Variant" attribute: "", "Gold" or "Rainbow"; Config.Variant).
-- Placeholders until the creature chat exports real variant meshes; the rules are theirs (docs/style/06-textures.md,
-- tools/blender/voxel_kit.py): gold is yellow gold, never brown, and its light is violet; the rainbow is one smooth,
-- straight gradient from nose to tail, vivid and a little pastel, and its light is white.
--
--   Variants.apply(model, variant)   dress any creature model (a fish, a tank's copy, a block stand-in); "" undoes it.
--                                    On the server it reaches every player; FishService calls it at the spawn.
--   Variants.clear(model)            the same as apply(model, "")
--   Variants.gold / rainbow / lit    the colour rules (tools/creatures/local_meshes.py bakes the same into meshes)
--
-- Two ways, by what the place has:
--   - variant meshes: ReplicatedStorage.FishVariants.<Gold|Rainbow>.<Id>, a copy of the creature's template whose
--     meshes carry the variant's colours (tools/creatures/install.py --local makes them). Each MeshPart of the model
--     takes the mesh of the part of the same name ("Baked" attribute); gold is also given a metal sheen;
--   - none (uploaded MeshParts without variants, block stand-ins): each part is tinted. Gold: a tone of gold by how
--     light the part was. Rainbow: a hue by where the part is along the body, turning slowly on each client that
--     calls apply itself. Neon parts take the accent.
-- Both add sparkles. What a part was is kept in attributes, so "" puts it back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Variants = {}

Variants.Gold = "Gold"
Variants.Rainbow = "Rainbow"

Variants.Accent = {
	Gold = Color3.fromRGB(178, 92, 255),
	Rainbow = Color3.fromRGB(255, 255, 255),
}

local GOLD = { Color3.fromRGB(232, 174, 22), Color3.fromRGB(255, 206, 43), Color3.fromRGB(255, 241, 168) }
local STOPS = {
	Color3.fromRGB(255, 47, 74),
	Color3.fromRGB(255, 122, 20),
	Color3.fromRGB(255, 214, 10),
	Color3.fromRGB(47, 212, 82),
	Color3.fromRGB(18, 198, 240),
	Color3.fromRGB(50, 102, 255),
	Color3.fromRGB(154, 61, 255),
	Color3.fromRGB(255, 61, 203),
}
local WHITE = Color3.new(1, 1, 1)
local PASTEL = 0.1 -- how much white is in every hue
local DARK = 0.1 -- colours darker than this (pupils, a mouth's inside) stay as they are
local TURN = 0.04 -- tinted parts: rainbows a second passing along the body
-- gold stays plain: Metal went ochre in the hub's light and Reflectance greyed it; the sparkles are its shine
local GOLD_MATERIAL = Enum.Material.SmoothPlastic
local GOLD_REFLECTANCE = 0

Variants.Folder = "FishVariants"
Variants.Templates = "FishModels"

function Variants.light(colour: Color3): number
	return 0.2126 * colour.R + 0.7152 * colour.G + 0.0722 * colour.B
end

function Variants.is(variant: any): boolean
	return variant == Variants.Gold or variant == Variants.Rainbow
end

-- A colour as gold: the darkest colour of the creature (`low`) deep gold, the lightest (`high`) pale gold
function Variants.gold(colour: Color3, low: number?, high: number?): Color3
	local light = Variants.light(colour)
	if light < DARK then
		return colour
	end
	local lo, hi = math.max(low or 0, DARK), high or 1
	local t = if hi - lo < 1e-3 then 0.5 else math.clamp((light - lo) / (hi - lo), 0, 1)
	if t <= 0.5 then
		return GOLD[1]:Lerp(GOLD[2], t * 2)
	end
	return GOLD[2]:Lerp(GOLD[3], t * 2 - 1)
end

-- The rainbow's hue at a place along the body (0 the nose, 1 the tail; it carries on round past either end)
function Variants.hue(along: number): Color3
	local at = (along % 1) * (#STOPS - 1)
	local i = math.floor(at)
	return STOPS[i + 1]:Lerp(STOPS[math.min(i + 2, #STOPS)], at - i):Lerp(WHITE, PASTEL)
end

-- A colour as rainbow: the hue at its place; pale colours (a belly) take it paler, dark tones a little darker
function Variants.rainbow(colour: Color3, along: number): Color3
	local light = Variants.light(colour)
	if light < DARK then
		return colour
	end
	local hue = Variants.hue(along)
	if light > 0.8 then
		return hue:Lerp(WHITE, 0.45)
	elseif light < 0.3 then
		return hue:Lerp(Color3.new(0, 0, 0), 0.22)
	end
	return hue
end

-- A glowing colour on a variant: the accent, as bright as the colour was
function Variants.lit(variant: string, colour: Color3): Color3
	local accent = (Variants.Accent :: any)[variant] :: Color3?
	if not accent then
		return colour
	end
	return Color3.new(0, 0, 0):Lerp(accent, math.clamp(0.55 + Variants.light(colour) * 0.6, 0.55, 1))
end

------------------------------------------------------------------------------------------------------------------------
-- dressing a model

local SPARKLE = "VariantSparkle"
local turning: { [Model]: { { part: BasePart, along: number, was: Color3 } } } = {}
local beat: RBXScriptConnection? = nil

local function visible(part: BasePart): boolean
	return part.Transparency < 1 and part.Name ~= "Root"
end

-- The creature's template in a folder of ReplicatedStorage ("FishVariants/Gold", "FishModels"), if the place has it
local function templateOf(model: Model, ...: string): Model?
	local id = model:GetAttribute("Rig") or model:GetAttribute("FishType")
	local at: Instance? = ReplicatedStorage
	for _, name in { ... } do
		at = at and at:FindFirstChild(name)
	end
	local found = at and type(id) == "string" and at:FindFirstChild(id)
	return if found and found:IsA("Model") then found else nil
end

-- Every MeshPart of the model takes the mesh of the template's part of the same name (its size stays its own)
local function remesh(model: Model, template: Model, baked: boolean?)
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			local from = template:FindFirstChild(d.Name)
			if from and from:IsA("MeshPart") and (baked or d:GetAttribute("Baked")) then
				local size = d.Size
				d:ApplyMesh(from)
				d.Size = size
				d:SetAttribute("Baked", baked)
			end
		end
	end
end

local function restore(model: Model)
	turning[model] = nil
	local own = templateOf(model, Variants.Templates)
	if own then
		remesh(model, own, nil)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local was = d:GetAttribute("VariantWasColor")
			if typeof(was) == "Color3" then
				d.Color = was
				local material = d:GetAttribute("VariantWasMaterial")
				if type(material) == "string" then
					d.Material = (Enum.Material :: any)[material]
				end
				d:SetAttribute("VariantWasColor", nil)
				d:SetAttribute("VariantWasMaterial", nil)
				d.Reflectance = 0
			end
		elseif d:IsA("ParticleEmitter") and d.Name == SPARKLE then
			d:Destroy()
		end
	end
end

local function sparkle(model: Model, variant: string)
	local biggest: BasePart? = nil
	local volume = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > volume then
				biggest, volume = d, v
			end
		end
	end
	if not biggest then
		return
	end
	local _, size = model:GetBoundingBox()
	local length = math.max(size.X, size.Y, size.Z)
	local grain = math.clamp(length * 0.09, 0.8, 4)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = SPARKLE
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = math.clamp(length * 0.8, 8, 24)
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.LightEmission = 0.9
	emitter.Brightness = 2
	emitter.Shape = Enum.ParticleEmitterShape.Box
	-- off the skin and outward: inside the body they would be hidden
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.ZOffset = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, grain),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	if variant == Variants.Gold then
		emitter.Color = ColorSequence.new(GOLD[3], GOLD[2])
	else
		local keys = {}
		for i, stop in STOPS do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#STOPS - 1), stop:Lerp(WHITE, 0.4)))
		end
		emitter.Color = ColorSequence.new(keys)
	end
	emitter.Parent = biggest
end

local function turn()
	local now = os.clock() * TURN
	for model, rows in turning do
		if not model.Parent then
			turning[model] = nil
			continue
		end
		for _, row in rows do
			row.part.Color = Variants.rainbow(row.was, row.along + now)
		end
	end
	if not next(turning) and beat then
		beat:Disconnect()
		beat = nil
	end
end

function Variants.apply(model: Model, variant: string)
	restore(model)
	if not Variants.is(variant) then
		return
	end
	local meshes = templateOf(model, Variants.Folder, variant)
	if meshes then
		remesh(model, meshes, true)
	end
	local tinted: { BasePart } = {}
	local low, high = 1, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Baked") then
			-- its colours are in its mesh: gold only takes the sheen
			if variant == Variants.Gold and d.Material ~= Enum.Material.Neon then
				d:SetAttribute("VariantWasColor", d.Color)
				d:SetAttribute("VariantWasMaterial", d.Material.Name)
				d.Material = GOLD_MATERIAL
				d.Reflectance = GOLD_REFLECTANCE
			end
		elseif d:IsA("BasePart") and visible(d) then
			table.insert(tinted, d)
			if d.Material ~= Enum.Material.Neon then
				local light = Variants.light(d.Color)
				low, high = math.min(low, light), math.max(high, light)
			end
		end
	end
	if #tinted > 0 then
		local pivot = model:GetPivot()
		local _, size = model:GetBoundingBox()
		local length = math.max(size.Z, 0.01)
		local rows = {}
		for _, part in tinted do
			part:SetAttribute("VariantWasColor", part.Color)
			part:SetAttribute("VariantWasMaterial", part.Material.Name)
			if part.Material == Enum.Material.Neon then
				part.Color = Variants.lit(variant, part.Color)
			elseif variant == Variants.Gold then
				part.Color = Variants.gold(part.Color, low, high)
				part.Material = GOLD_MATERIAL
			else
				local along = pivot:PointToObjectSpace(part.Position).Z / length + 0.5
				part.Color = Variants.rainbow(part.Color, along)
				table.insert(rows, { part = part, along = along, was = part:GetAttribute("VariantWasColor") :: Color3 })
			end
		end
		-- the slow turn of a tinted rainbow is a thing to see, so only where there is a screen
		if #rows > 0 and RunService:IsClient() then
			turning[model] = rows
			if not beat then
				beat = RunService.Heartbeat:Connect(turn)
			end
		end
	end
	sparkle(model, variant)
end

function Variants.clear(model: Model)
	restore(model)
end

return Variants
