--!strict
-- The look of the light: putting Config.Look's numbers onto Lighting and its effects. One function for the two places it
-- is done from: the client while playing (Controllers/LookController, so the N panel changes it live) and Studio's Edit
-- mode (tools/studio/look_install.luau, so the place looks the same while building).
-- The numbers are from the user's lighting tutorial (2026-11-11; docs/design/lighting.md). Its outline script is left out.
local Look = {}

export type Values = { [string]: number }

local BLOOM = "LookBloom"
local COLOUR = "LookColour"

local function rgb(v: Values, name: string): Color3
	return Color3.fromRGB(
		math.clamp(v[name .. "R"], 0, 255),
		math.clamp(v[name .. "G"], 0, 255),
		math.clamp(v[name .. "B"], 0, 255)
	)
end

-- Roblox's own plain lighting, as a new place has it: what Look.On 0 shows, to compare against
local PLAIN = {
	Ambient = Color3.fromRGB(70, 70, 70),
	OutdoorAmbient = Color3.fromRGB(70, 70, 70),
	Brightness = 3,
	ShadowSoftness = 0.2,
	ClockTime = 14.5,
	GeographicLatitude = 0,
	ExposureCompensation = 0,
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
}

-- Our own two effects, made once and then only changed. The place's other effects are left as they are, except its own
-- Bloom, which is switched off while ours is on (two blooms add up).
local function effects(lighting: Lighting): (BloomEffect, ColorCorrectionEffect)
	local bloom = lighting:FindFirstChild(BLOOM)
	if not (bloom and bloom:IsA("BloomEffect")) then
		local made = Instance.new("BloomEffect")
		made.Name = BLOOM
		made.Parent = lighting
		bloom = made
	end
	local colour = lighting:FindFirstChild(COLOUR)
	if not (colour and colour:IsA("ColorCorrectionEffect")) then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = COLOUR
		made.Parent = lighting
		colour = made
	end
	return bloom :: BloomEffect, colour :: ColorCorrectionEffect
end

-- Puts the numbers on. With Look.On at 0: Roblox's plain lighting, our two effects off and the place's own bloom on.
function Look.apply(lighting: Lighting, v: Values)
	local bloom, colour = effects(lighting)
	local on = v.On > 0
	bloom.Enabled = on
	colour.Enabled = on
	for _, effect in lighting:GetChildren() do
		if effect:IsA("BloomEffect") and effect ~= bloom then
			effect.Enabled = not on
		end
	end
	if not on then
		for name, value in PLAIN do
			(lighting :: any)[name] = value
		end
		return
	end
	lighting.Ambient = rgb(v, "Ambient")
	lighting.OutdoorAmbient = rgb(v, "Outdoor")
	lighting.Brightness = v.Brightness
	lighting.ShadowSoftness = math.clamp(v.ShadowSoftness, 0, 1)
	lighting.ClockTime = v.ClockTime % 24
	lighting.GeographicLatitude = v.Latitude
	lighting.ExposureCompensation = v.Exposure
	lighting.EnvironmentDiffuseScale = math.clamp(v.EnvDiffuse, 0, 1)
	lighting.EnvironmentSpecularScale = math.clamp(v.EnvSpecular, 0, 1)
	bloom.Intensity = v.BloomIntensity
	bloom.Size = v.BloomSize
	bloom.Threshold = v.BloomThreshold
	colour.Brightness = v.ColourBrightness
	colour.Contrast = v.Contrast
	colour.Saturation = v.Saturation
	colour.TintColor = rgb(v, "Tint")
end

return Look
