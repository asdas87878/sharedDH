--!strict
-- Style workout 1 (docs/style/01-going-down.md): underwater looks tried at chosen depths in Edit mode, for captures.
-- Set LOOK ("A", "B" or "Restore") and STOP, then run through the Studio connector. The first run saves the place's own
-- lighting as attributes on Lighting; "Restore" puts it all back, removes the test effects and dries the sea tiles.
-- Underwater uses Lighting's classic fog, not Atmosphere: Atmosphere's haze stays sky-blue in daylight whatever its
-- Color, while fog takes an exact colour and covers the sky too. So the place's Atmosphere is held in ReplicatedStorage
-- while a look is on (classic fog only works without one) and put back by "Restore".
-- In the game this becomes a client controller blending these stops by the camera's depth.
local LOOK = "A"
local STOP = "Reef"

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

type Stop = {
	Fog: Color3, -- the water's colour: everything fades to it
	FogEnd: number, -- how far you can see
	Ambient: Color3,
	Outdoor: Color3,
	Brightness: number, -- the sun through the water
	Tint: Color3,
	Saturation: number,
	Contrast: number,
	Exposure: number,
	Ceiling: Color3, -- the surface seen from below
	Bloom: number,
}

-- stylua: ignore
local LOOKS: { [string]: { [string]: Stop } } = {
	-- A, "Toy ocean": bright and saturated all the way down; you see far; the deep turns violet instead of black
	A = {
		Reef = { Fog = rgb(60, 190, 210), FogEnd = 1100, Ambient = rgb(70, 130, 140), Outdoor = rgb(90, 160, 175), Brightness = 1.8, Tint = rgb(235, 252, 255), Saturation = 0.2, Contrast = 0.1, Exposure = 0, Ceiling = rgb(50, 135, 150), Bloom = 0.15 },
		OpenBlue = { Fog = rgb(35, 120, 215), FogEnd = 1000, Ambient = rgb(55, 100, 155), Outdoor = rgb(75, 130, 190), Brightness = 1.5, Tint = rgb(220, 235, 255), Saturation = 0.15, Contrast = 0.1, Exposure = 0, Ceiling = rgb(35, 95, 140), Bloom = 0.2 },
		Twilight = { Fog = rgb(70, 65, 190), FogEnd = 850, Ambient = rgb(80, 75, 160), Outdoor = rgb(90, 85, 175), Brightness = 1.1, Tint = rgb(220, 210, 255), Saturation = 0.15, Contrast = 0.1, Exposure = 0, Ceiling = rgb(90, 85, 200), Bloom = 0.3 },
		Trench = { Fog = rgb(95, 40, 130), FogEnd = 700, Ambient = rgb(105, 65, 140), Outdoor = rgb(110, 65, 150), Brightness = 0.8, Tint = rgb(240, 210, 255), Saturation = 0.2, Contrast = 0.12, Exposure = 0, Ceiling = rgb(95, 40, 130), Bloom = 0.4 },
	},
	-- B, "Deep dive": the light really goes and you see less; past the twilight the glowing things carry the scene
	B = {
		Reef = { Fog = rgb(40, 165, 170), FogEnd = 800, Ambient = rgb(55, 110, 115), Outdoor = rgb(75, 140, 145), Brightness = 1.6, Tint = rgb(225, 248, 245), Saturation = 0.05, Contrast = 0.15, Exposure = 0, Ceiling = rgb(45, 120, 118), Bloom = 0.2 },
		OpenBlue = { Fog = rgb(12, 60, 120), FogEnd = 650, Ambient = rgb(25, 50, 85), Outdoor = rgb(35, 70, 110), Brightness = 0.9, Tint = rgb(185, 210, 240), Saturation = 0, Contrast = 0.15, Exposure = -0.2, Ceiling = rgb(12, 60, 120), Bloom = 0.4 },
		Twilight = { Fog = rgb(6, 18, 48), FogEnd = 420, Ambient = rgb(16, 24, 50), Outdoor = rgb(18, 28, 58), Brightness = 0.35, Tint = rgb(160, 180, 230), Saturation = -0.05, Contrast = 0.18, Exposure = -0.3, Ceiling = rgb(6, 18, 48), Bloom = 0.7 },
		Trench = { Fog = rgb(3, 3, 10), FogEnd = 260, Ambient = rgb(22, 15, 34), Outdoor = rgb(18, 12, 28), Brightness = 0.1, Tint = rgb(180, 160, 215), Saturation = 0.05, Contrast = 0.2, Exposure = -0.4, Ceiling = rgb(3, 3, 10), Bloom = 1 },
	},
}

local LIGHTING_PROPS = {
	"Ambient",
	"OutdoorAmbient",
	"Brightness",
	"ExposureCompensation",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ClockTime",
	"FogColor",
	"FogStart",
	"FogEnd",
}
local HELD = "DepthTest_HeldAtmosphere"

local blockout = workspace:FindFirstChild("ClaudeBlockout")
local surface = if blockout then blockout:FindFirstChild("Surface") else nil

local function save()
	for _, name in LIGHTING_PROPS do -- per property, so a property added to the list later is still saved
		if Lighting:GetAttribute("DT_" .. name) == nil then
			Lighting:SetAttribute("DT_" .. name, (Lighting :: any)[name])
		end
	end
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("SunRaysEffect") and effect:GetAttribute("DT_Enabled") == nil then
			effect:SetAttribute("DT_Enabled", effect.Enabled)
		end
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then -- classic fog only works without an Atmosphere
		atmosphere:SetAttribute("DT_HeldName", atmosphere.Name)
		atmosphere.Name = HELD
		atmosphere.Parent = ReplicatedStorage
	end
	Lighting:SetAttribute("DT_Saved", true)
end

local function seaTiles(fn: (BasePart) -> ())
	if not surface then
		return
	end
	for _, tile in surface:GetChildren() do
		if tile:IsA("BasePart") and tile.Name == "SeaTile" then
			fn(tile)
		end
	end
end

local function restore(): string
	if not Lighting:GetAttribute("DT_Saved") then
		return "nothing to restore"
	end
	for _, name in LIGHTING_PROPS do
		local value = Lighting:GetAttribute("DT_" .. name)
		if value ~= nil then
			(Lighting :: any)[name] = value
			Lighting:SetAttribute("DT_" .. name, nil)
		end
	end
	local held = ReplicatedStorage:FindFirstChild(HELD)
	if held then
		held.Name = held:GetAttribute("DT_HeldName") or "Atmosphere"
		held:SetAttribute("DT_HeldName", nil)
		held.Parent = Lighting
	end
	-- an older run of this script may have changed the Atmosphere in place
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		for _, name in { "Density", "Offset", "Color", "Decay", "Glare", "Haze" } do
			local value = atmosphere:GetAttribute("DT_" .. name)
			if value ~= nil then
				(atmosphere :: any)[name] = value
				atmosphere:SetAttribute("DT_" .. name, nil)
			end
		end
	end
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("SunRaysEffect") and effect:GetAttribute("DT_Enabled") ~= nil then
			effect.Enabled = effect:GetAttribute("DT_Enabled") :: boolean
			effect:SetAttribute("DT_Enabled", nil)
		elseif string.sub(effect.Name, 1, 10) == "DepthTest_" then
			effect:Destroy()
		end
	end
	Lighting:SetAttribute("DT_Saved", nil)
	seaTiles(function(tile)
		tile.Material = Enum.Material.SmoothPlastic
		tile.Color = rgb(40, 140, 200)
		tile.Transparency = 0.35
	end)
	return "restored"
end

local function apply(look: string, stopName: string): string
	local stop = LOOKS[look] and LOOKS[look][stopName]
	if not stop then
		return "no such look or stop: " .. look .. " " .. stopName
	end
	save()
	Lighting.Ambient = stop.Ambient
	Lighting.OutdoorAmbient = stop.Outdoor
	Lighting.Brightness = stop.Brightness
	Lighting.ExposureCompensation = stop.Exposure
	-- the sky must not light anything down here: it tints every surface sky-blue
	Lighting.EnvironmentDiffuseScale = 0.15
	Lighting.EnvironmentSpecularScale = 0
	Lighting.ClockTime = 14
	Lighting.FogColor = stop.Fog
	Lighting.FogStart = 0
	Lighting.FogEnd = stop.FogEnd
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("SunRaysEffect") then
			effect.Enabled = false
		end
	end
	local cc = Lighting:FindFirstChild("DepthTest_Colour") :: ColorCorrectionEffect?
	if not cc then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "DepthTest_Colour"
		made.Parent = Lighting
		cc = made
	end
	assert(cc, "colour correction missing")
	cc.TintColor = stop.Tint
	cc.Saturation = stop.Saturation
	cc.Contrast = stop.Contrast
	local bloom = Lighting:FindFirstChild("DepthTest_Bloom") :: BloomEffect?
	if not bloom then
		local made = Instance.new("BloomEffect")
		made.Name = "DepthTest_Bloom"
		made.Size = 30
		made.Threshold = 0.9
		made.Parent = Lighting
		bloom = made
	end
	assert(bloom, "bloom missing")
	bloom.Intensity = stop.Bloom
	-- the surface from below: opaque, so no daylight sky shows through; deeper, the fog swallows it
	seaTiles(function(tile)
		tile.Material = Enum.Material.Neon
		tile.Color = stop.Ceiling
		tile.Transparency = 0
	end)
	return string.format("look %s at %s", look, stopName)
end

if LOOK == "Restore" then
	return restore()
end
return apply(LOOK, STOP)
